import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return Response.json({ error: "Missing Authorization header." }, { status: 401, headers: corsHeaders });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { action, request_id } = await req.json();
    if (!request_id) {
      return Response.json({ error: "request_id is required." }, { status: 400, headers: corsHeaders });
    }

    if (action === "expand") {
      const { data, error } = await supabase.rpc("expand_dispatch_radius", { p_request_id: request_id });
      if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders });
      return Response.json({ new_radius_km: data }, { headers: corsHeaders });
    }

    const { data, error } = await supabase.rpc("dispatch_next_candidate", { p_request_id: request_id });
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders });
    return Response.json(data, { headers: corsHeaders });
  } catch (err) {
    return Response.json({ error: String(err) }, { status: 500, headers: corsHeaders });
  }
});
