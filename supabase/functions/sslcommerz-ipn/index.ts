import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    const rawBody = await req.text();
    const params = new URLSearchParams(rawBody);
    const tranId = params.get("tran_id") ?? "";
    const valId = params.get("val_id") ?? "";
    const status = params.get("status") ?? "";

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const storeId = Deno.env.get("SSLCOMMERZ_STORE_ID") ?? "";
    const storePasswd = Deno.env.get("SSLCOMMERZ_STORE_PASSWD") ?? "";
    const isSandbox = (Deno.env.get("SSLCOMMERZ_IS_SANDBOX") ?? "true").toLowerCase() === "true";

    if (!tranId || !storeId || !storePasswd) {
      return Response.json({ error: "Missing IPN fields or server configuration." }, { status: 400 });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: tx } = await adminClient
      .from("transactions")
      .select("id, request_id, amount, status")
      .eq("gateway_transaction_id", tranId)
      .single();

    if (!tx) {
      return Response.json({ error: "Transaction not found." }, { status: 404 });
    }
    if (tx.status === "completed") {
      return Response.json({ ok: true, idempotent: true });
    }

    if (status !== "VALID" && status !== "VALIDATED") {
      await adminClient.from("transactions").update({ status: "failed" }).eq("id", tx.id);
      return Response.json({ ok: false, status: "failed" });
    }

    const validatorBase = isSandbox
      ? "https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php"
      : "https://securepay.sslcommerz.com/validator/api/validationserverAPI.php";
    const verifyUrl = `${validatorBase}?val_id=${encodeURIComponent(valId)}&store_id=${encodeURIComponent(storeId)}&store_passwd=${encodeURIComponent(storePasswd)}&format=json`;

    const verifyResp = await fetch(verifyUrl);
    const verifyJson = await verifyResp.json();
    const paidAmount = Number(verifyJson.amount ?? 0);

    if (
      (verifyJson.status !== "VALID" && verifyJson.status !== "VALIDATED") ||
      verifyJson.tran_id !== tranId ||
      Math.abs(paidAmount - Number(tx.amount)) > 0.5
    ) {
      await adminClient.from("transactions").update({ status: "failed" }).eq("id", tx.id);
      return Response.json({ error: "Validation mismatch." }, { status: 400 });
    }

    await adminClient
      .from("transactions")
      .update({
        status: "completed",
        metadata: {
          gateway: "SSLCommerz",
          val_id: valId,
          card_type: verifyJson.card_type ?? "",
          validated_on: verifyJson.tran_date ?? new Date().toISOString(),
        },
      })
      .eq("id", tx.id);

    await adminClient
      .from("service_requests")
      .update({ status: "completed", completed_at: new Date().toISOString() })
      .eq("id", tx.request_id)
      .eq("status", "servicing");

    return Response.json({ ok: true, transaction_id: tx.id });
  } catch (err) {
    return Response.json({ error: String(err) }, { status: 500 });
  }
});
