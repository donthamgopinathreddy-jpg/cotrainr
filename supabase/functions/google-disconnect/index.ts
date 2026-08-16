// Disconnects Google Meet integration for the current provider.
// Clears tokens locally; does not call Google revoke (best-effort optional).
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
      .select("access_token")
      .eq("user_id", user.id)
      .maybeSingle()

    // Best-effort Google token revoke (do not fail disconnect on revoke errors).
    if (row?.access_token) {
      try {
        await fetch("https://oauth2.googleapis.com/revoke", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ token: row.access_token }),
        })
      } catch (_) {
        /* ignore */
      }
    }

    await admin.from("user_integrations_google").delete().eq("user_id", user.id)

    return jsonResponse({ success: true })
  } catch (err) {
    console.error("[google-disconnect]", err)
    return jsonError("Could not disconnect Google Meet", 500)
  }
})
