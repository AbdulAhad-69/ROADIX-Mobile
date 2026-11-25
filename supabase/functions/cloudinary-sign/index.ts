import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function sha1Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-1", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return Response.json({ error: "Missing Authorization header." }, { status: 401, headers: corsHeaders });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const cloudName = Deno.env.get("CLOUDINARY_CLOUD_NAME") ?? "";
    const apiKey = Deno.env.get("CLOUDINARY_API_KEY") ?? "";
    const apiSecret = Deno.env.get("CLOUDINARY_API_SECRET") ?? "";

    if (!cloudName || !apiKey || !apiSecret || apiKey === "Root") {
      return Response.json(
        { error: "Valid Cloudinary credentials are not configured on Edge Function." },
        { status: 503, headers: corsHeaders },
      );
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return Response.json({ error: "Unauthorized session." }, { status: 401, headers: corsHeaders });
    }

    const body = await req.json().catch(() => ({}));
    const rawFolder = String(body.folder ?? "roadix/uploads").trim();
    const allowedFolders = ["roadix/avatars", "roadix/faults", "roadix/verifications", "roadix/uploads"];
    const folder = allowedFolders.includes(rawFolder) ? rawFolder : "roadix/uploads";

    const timestamp = Math.floor(Date.now() / 1000).toString();
    const paramsToSign = `folder=${folder}&timestamp=${timestamp}${apiSecret}`;
    const signature = await sha1Hex(paramsToSign);

    return Response.json(
      {
        signature,
        timestamp,
        api_key: apiKey,
        cloud_name: cloudName,
        folder,
      },
      { status: 200, headers: corsHeaders },
    );
  } catch (err) {
    return Response.json({ error: String(err) }, { status: 500, headers: corsHeaders });
  }
});
