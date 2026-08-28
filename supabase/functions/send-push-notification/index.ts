// Sends FCM push when a notification is inserted.
// AUTHORITATIVE PATH: notifications INSERT → this webhook → deliverNotificationPush → FCM.
// Do NOT call deliverNotificationPush/deliverNotificationRows from other Edge Functions.
//
// Requires secrets:
//   NOTIFICATION_WEBHOOK_SECRET  (caller authentication — fails closed if absent)
//   FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
//
// The Supabase Database Webhook on public.notifications INSERT must send:
//   x-notification-webhook-secret: <NOTIFICATION_WEBHOOK_SECRET>
//
// Never log notification bodies, device tokens, credentials, or header values.

import { deliverNotificationPush } from "../_shared/push_deliver.ts"
import { secretsMatch } from "../_shared/secret_compare.ts"
import { validateWebhookPayload } from "./payload.ts"

const WEBHOOK_SECRET_HEADER = "x-notification-webhook-secret"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    `authorization, x-client-info, apikey, content-type, ${WEBHOOK_SECRET_HEADER}`,
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  // 1. Fail closed when the shared secret is not configured.
  const expectedSecret = Deno.env.get("NOTIFICATION_WEBHOOK_SECRET")?.trim()
  if (!expectedSecret) {
    console.error(
      JSON.stringify({
        event: "send-push-notification",
        error: "missing_notification_webhook_secret",
      }),
    )
    return json({ error: "configuration_error" }, 503)
  }

  // 2. Authenticate the caller before touching the payload.
  if (!secretsMatch(expectedSecret, req.headers.get(WEBHOOK_SECRET_HEADER))) {
    console.warn(
      JSON.stringify({
        event: "send-push-notification",
        error: "unauthorized_webhook_caller",
      }),
    )
    return json({ error: "unauthorized" }, 401)
  }

  try {
    let payload: unknown
    try {
      payload = await req.json()
    } catch {
      return json({ error: "invalid_json" }, 400)
    }

    const validated = validateWebhookPayload(payload)
    if (!validated.ok) {
      if (validated.ignore) {
        return json({ received: true }, 200)
      }
      console.warn(
        JSON.stringify({
          event: "send-push-notification",
          error: "invalid_payload",
          reason: validated.reason,
        }),
      )
      return json({ error: "invalid_payload" }, 400)
    }

    const result = await deliverNotificationPush(validated.record)
    return json(result, 200)
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "send-push-notification error",
        errorCode: String(error).slice(0, 200),
      }),
    )
    return json({ error: "push_failed" }, 500)
  }
})
