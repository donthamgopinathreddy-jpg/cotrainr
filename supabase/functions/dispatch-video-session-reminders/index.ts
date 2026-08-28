// Polls due video-session reminder/start jobs and inserts notifications.
// Invoke every minute (Supabase scheduled function / trusted scheduler).
//
// verify_jwt = false because the scheduler cannot present a Supabase user JWT.
// Authentication is therefore enforced here with a mandatory shared secret:
//   VIDEO_SESSION_CRON_SECRET  (fails closed if absent)
// The scheduled trigger must send:
//   x-cron-secret: <VIDEO_SESSION_CRON_SECRET>
//
// Never log Authorization headers or the secret.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import { secretsMatch } from "../_shared/secret_compare.ts"
// Sole reminder poller. Inserts notifications; FCM via notifications INSERT webhook only.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
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

  // 1. Fail closed when the cron secret is not configured. No service-role
  //    client is created and no reminders are dispatched in this state.
  const cronSecret = Deno.env.get("VIDEO_SESSION_CRON_SECRET")?.trim()
  if (!cronSecret) {
    console.error(
      JSON.stringify({
        event: "dispatch-video-session-reminders",
        error: "missing_video_session_cron_secret",
      }),
    )
    return json({ error: "configuration_error" }, 503)
  }

  // 2. Authenticate the caller before doing any privileged work.
  if (!secretsMatch(cronSecret, req.headers.get("x-cron-secret"))) {
    console.warn(
      JSON.stringify({
        event: "dispatch-video-session-reminders",
        error: "unauthorized_cron_caller",
      }),
    )
    return json({ error: "Unauthorized" }, 401)
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )
    const { data, error } = await supabase.rpc(
      "dispatch_video_session_notification_jobs",
    )
    if (error) {
      console.error("[dispatch-video-session-reminders]", error.message)
      return json({ error: "dispatch_failed" }, 500)
    }
    const rows = Array.isArray(data) ? data : []
    console.log(JSON.stringify({
      event: "reminder_dispatch",
      notifications_inserted: rows.length,
      push_via: "notifications_insert_webhook",
    }))
    return json({ sent: rows.length }, 200)
  } catch (err) {
    console.error("[dispatch-video-session-reminders]", String(err))
    return json({ error: "internal" }, 500)
  }
})
