// Sends FCM push when a notification is inserted.
// AUTHORITATIVE PATH: notifications INSERT → this webhook → deliverNotificationPush → FCM.
// Do NOT call deliverNotificationPush/deliverNotificationRows from other Edge Functions.
// Requires secrets: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY

import { deliverNotificationPush } from "../_shared/push_deliver.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE"
  table: string
  record: {
    id: string
    user_id: string
    type: string
    title: string
    body: string
    data?: Record<string, unknown>
  }
  schema: string
  old_record: unknown
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const payload: WebhookPayload = await req.json()

    if (payload.type !== "INSERT" || payload.table !== "notifications") {
      return new Response(JSON.stringify({ received: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const result = await deliverNotificationPush(payload.record)
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "send-push-notification error",
        errorCode: String(error).slice(0, 200),
      }),
    )
    return new Response(JSON.stringify({ error: "push_failed" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
