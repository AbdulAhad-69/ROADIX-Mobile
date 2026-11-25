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

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const storeId = Deno.env.get("SSLCOMMERZ_STORE_ID") ?? "";
    const storePasswd = Deno.env.get("SSLCOMMERZ_STORE_PASSWD") ?? "";
    const isSandbox = (Deno.env.get("SSLCOMMERZ_IS_SANDBOX") ?? "true").toLowerCase() === "true";

    if (!storeId || !storePasswd) {
      return Response.json(
        { error: "SSLCommerz gateway secrets are not configured on Edge Function." },
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

    const body = await req.json();
    const requestId = String(body.request_id ?? "").trim();
    const quotationId = String(body.quotation_id ?? "").trim();
    const paymentMethod = String(body.payment_method ?? "SSLCommerz-Online").trim();
    if (!requestId) {
      return Response.json({ error: "request_id is required." }, { status: 400, headers: corsHeaders });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: sr, error: srErr } = await adminClient
      .from("service_requests")
      .select("id, motorist_id, status, request_code")
      .eq("id", requestId)
      .single();
    if (srErr || !sr || sr.motorist_id !== user.id) {
      return Response.json({ error: "Service request not found or forbidden." }, { status: 403, headers: corsHeaders });
    }
    if (sr.status !== "servicing" && sr.status !== "completed") {
      return Response.json({ error: "Request must be in servicing or completed state for payment." }, { status: 409, headers: corsHeaders });
    }

    const quoteQuery = adminClient
      .from("quotations")
      .select("id, total_amount, status")
      .eq("request_id", requestId)
      .eq("status", "accepted");
    const { data: quote, error: qErr } = quotationId
      ? await quoteQuery.eq("id", quotationId).single()
      : await quoteQuery.order("created_at", { ascending: false }).limit(1).single();
    if (qErr || !quote) {
      return Response.json({ error: "Accepted quotation not found." }, { status: 404, headers: corsHeaders });
    }

    const { data: profile } = await adminClient
      .from("profiles")
      .select("full_name, phone")
      .eq("id", user.id)
      .single();

    const tranId = `RDX-${isSandbox ? "SBX" : "LIVE"}-${crypto.randomUUID().replaceAll("-", "").slice(0, 16).toUpperCase()}`;
    const amount = Number(quote.total_amount);

    const { data: tx, error: txErr } = await adminClient
      .from("transactions")
      .insert({
        request_id: requestId,
        quotation_id: quote.id,
        amount,
        payment_method: paymentMethod,
        status: "pending",
        gateway_transaction_id: tranId,
        metadata: { gateway: "SSLCommerz", environment: isSandbox ? "sandbox" : "production" },
      })
      .select("id")
      .single();
    if (txErr || !tx) {
      return Response.json({ error: "Could not create pending transaction record." }, { status: 500, headers: corsHeaders });
    }

    const ipnUrl = `${supabaseUrl}/functions/v1/sslcommerz-ipn`;
    const sessionUrl = isSandbox
      ? "https://sandbox.sslcommerz.com/gwprocess/v4/api.php"
      : "https://securepay.sslcommerz.com/gwprocess/v4/api.php";

    const form = new URLSearchParams({
      store_id: storeId,
      store_passwd: storePasswd,
      total_amount: amount.toFixed(2),
      currency: "BDT",
      tran_id: tranId,
      success_url: "io.supabase.roadix://payment-callback?status=success&tran_id=" + encodeURIComponent(tranId),
      fail_url: "io.supabase.roadix://payment-callback?status=failed&tran_id=" + encodeURIComponent(tranId),
      cancel_url: "io.supabase.roadix://payment-callback?status=cancelled&tran_id=" + encodeURIComponent(tranId),
      ipn_url: ipnUrl,
      cus_name: profile?.full_name || "Roadside Motorist",
      cus_email: user.email || "motorist@roadix.app",
      cus_phone: profile?.phone || user.phone || "+8801700000000",
      cus_add1: "Dhaka, Bangladesh",
      cus_city: "Dhaka",
      cus_country: "Bangladesh",
      shipping_method: "NO",
      product_name: `ROADIX Rescue ${sr.request_code ?? requestId}`,
      product_category: "Automotive Rescue",
      product_profile: "general",
    });

    const gatewayResp = await fetch(sessionUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    });
    const gatewayJson = await gatewayResp.json();
    if (gatewayJson.status !== "SUCCESS" || !gatewayJson.GatewayPageURL) {
      await adminClient.from("transactions").update({ status: "failed" }).eq("id", tx.id);
      return Response.json(
        { error: gatewayJson.failedreason ?? "SSLCommerz gateway initiation failed." },
        { status: 502, headers: corsHeaders },
      );
    }

    return Response.json(
      {
        transaction_id: tx.id,
        gateway_transaction_id: tranId,
        session_key: gatewayJson.sessionkey ?? "",
        gateway_page_url: gatewayJson.GatewayPageURL,
        amount,
        currency: "BDT",
      },
      { status: 200, headers: corsHeaders },
    );
  } catch (err) {
    return Response.json({ error: String(err) }, { status: 500, headers: corsHeaders });
  }
});
