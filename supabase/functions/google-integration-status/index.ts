// Safe Google Meet integration status for Flutter (no tokens).
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import { corsHeaders, jsonError, jsonResponse } from "../_shared/google_meet.ts"

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) return jsonError("Missing Authorization header", 401)

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const anon = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error } = await anon.auth.getUser()
    if (error || !user) return jsonError("Unauthorized", 401)

    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    const { data: row } = await admin
      .from("user_integrations_google")
      .select(
        "google_email, connected_at, reconnect_required, disconnected_at, scopes",
      )
      .eq("user_id", user.id)
      .maybeSingle()

    if (!row || row.disconnected_at) {
      return jsonResponse({
        connected: false,
        reconnect_required: false,
        google_email: null,
        connected_at: null,
      })
    }

    return jsonResponse({
      connected: !row.reconnect_required,
      reconnect_required: !!row.reconnect_required,
      google_email: row.google_email,
      connected_at: row.connected_at,
    })
  } catch (err) {
    console.error("[google-integration-status]", err)
    return jsonError("Could not load Google Meet status", 500)
  }
})
