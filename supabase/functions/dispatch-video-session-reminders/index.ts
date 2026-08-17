// Polls due video-session reminder/start jobs and inserts notifications.
// Invoke every minute (pg_cron or Supabase scheduled function).
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import { deliverNotificationRows } from "../_shared/push_deliver.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const cronSecret = Deno.env.get("VIDEO_SESSION_CRON_SECRET")?.trim()
  if (cronSecret) {
    const header = req.headers.get("x-cron-secret")?.trim()
    const auth = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "")
    if (header !== cronSecret && auth !== cronSecret) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
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
      return new Response(JSON.stringify({ error: "dispatch_failed" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
    const rows = Array.isArray(data) ? data : []
    console.log(JSON.stringify({
      event: "reminder_dispatch",
      sent: rows.length,
    }))
    await deliverNotificationRows(rows)
    return new Response(JSON.stringify({ sent: rows.length }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (err) {
    console.error("[dispatch-video-session-reminders]", String(err))
    return new Response(JSON.stringify({ error: "internal" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
