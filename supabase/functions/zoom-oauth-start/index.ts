// Returns Zoom OAuth authorization URL for the host to connect their account.
// Client calls this, then opens the URL in browser. Zoom redirects to zoom-oauth-callback.
// @ts-nocheck - Deno/Supabase Edge Function

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      console.error("[zoom-oauth-start] Missing Authorization header")
      return jsonError("Missing Authorization header", 401)
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")
    if (!supabaseUrl || !supabaseAnonKey) {
      console.error("[zoom-oauth-start] Missing SUPABASE_URL or SUPABASE_ANON_KEY")
      return jsonError("Server configuration error", 500)
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error } = await supabase.auth.getUser()
    if (error) {
      console.error("[zoom-oauth-start] auth.getUser error:", error.message)
      return jsonError("Unauthorized", 401)
    }
    if (!user) {
      console.error("[zoom-oauth-start] No user in session")
      return jsonError("Unauthorized", 401)
    }

    const clientId = Deno.env.get("ZOOM_CLIENT_ID")
    if (!clientId || clientId.trim() === "") {
      console.error("[zoom-oauth-start] ZOOM_CLIENT_ID not set or empty")
      return jsonError(
        "Zoom OAuth not configured. Set ZOOM_CLIENT_ID, ZOOM_CLIENT_SECRET, ZOOM_REDIRECT_URI.",
        500
      )
    }

    const redirectUri = Deno.env.get("ZOOM_REDIRECT_URI")?.trim()
    if (!redirectUri || !redirectUri.startsWith("https://")) {
      console.error("[zoom-oauth-start] ZOOM_REDIRECT_URI not set or invalid. Required: https://<project>.supabase.co/functions/v1/zoom-oauth-callback")
      return jsonError(
        "ZOOM_REDIRECT_URI required. Set to: https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback",
        500
      )
    }

    const state = user.id
    const authUrl = `https://zoom.us/oauth/authorize?response_type=code&client_id=${encodeURIComponent(clientId)}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}`

    console.log("[zoom-oauth-start] redirect_uri=" + redirectUri.replace(/[a-z0-9]{20,}/g, "***") + " state=" + state.substring(0, 8) + "...")

    return new Response(JSON.stringify({ auth_url: authUrl }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (err) {
    console.error("[zoom-oauth-start] Unhandled error:", err)
    return jsonError(String(err), 500)
  }
})
