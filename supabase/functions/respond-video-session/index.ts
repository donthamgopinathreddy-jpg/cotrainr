// Authenticated attendance response. Actor is JWT user; never trust body.user_id.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
// Push: notifications INSERT → webhook send-push-notification → FCM (single authority).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

function jsonError(message: string, status = 400, code = "ERROR") {
  return new Response(JSON.stringify({ error: message, code }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) return jsonError("Missing Authorization header", 401, "UNAUTHORIZED")

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const userClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error: authErr } = await userClient.auth.getUser()
  if (authErr || !user) return jsonError("Unauthorized", 401, "UNAUTHORIZED")

  let body: {
    session_id?: string
    response_status?: string
    reason_code?: string
    reason_text?: string
  }
  try {
    body = await req.json()
  } catch {
    return jsonError("Invalid JSON", 400, "VALIDATION")
  }

  const sessionId = typeof body.session_id === "string" ? body.session_id.trim() : ""
  if (!sessionId) return jsonError("session_id is required", 400, "VALIDATION")

  const { data, error } = await userClient.rpc("respond_to_video_session", {
    p_session_id: sessionId,
    p_response_status: body.response_status || "rejected",
    p_reason_code: body.reason_code || null,
    p_reason_text: body.reason_text || null,
  })

  if (error) {
    const msg = error.message || ""
    console.error(JSON.stringify({
      event: "respond_to_video_session_failed",
      code: error.code,
      message: msg.slice(0, 200),
    }))
    if (msg.includes("not_a_participant") || error.code === "42501") {
      return jsonError("You are not in this session", 403, "FORBIDDEN")
    }
    if (msg.includes("session_not_found") || error.code === "P0002") {
      return jsonError("Session not found", 404, "NOT_FOUND")
    }
    if (msg.includes("invalid_reason") || msg.includes("invalid_response")) {
      return jsonError("Invalid attendance response", 400, "VALIDATION")
    }
    if (msg.includes("session_not_scheduled")) {
      return jsonError("This session can no longer be updated", 409, "CONFLICT")
    }
    return jsonError("Could not save response", 500, "INTERNAL")
  }

  const rows = Array.isArray(data) ? data : []

  const snackbarRole =
    rows.find((r) => r?.snackbar_role)?.snackbar_role ||
    rows[0]?.snackbar_role ||
    "trainer"

  return new Response(
    JSON.stringify({
      ok: true,
      notified: rows.filter((r) => r?.notification_id).length,
      snackbar_role: snackbarRole,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  )
})
