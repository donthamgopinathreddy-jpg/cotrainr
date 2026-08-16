// Returns Google OAuth URL for Meet space creation scope.
// Stores CSRF state + PKCE verifier server-side.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import {
  GOOGLE_AUTH_URL,
  MEET_SCOPE,
  corsHeaders,
  jsonError,
  jsonResponse,
  randomUrlSafe,
  requireEnv,
  sha256Base64Url,
} from "../_shared/google_meet.ts"

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

    // Providers only
    const { data: providerRow } = await admin
      .from("providers")
      .select("provider_type")
      .eq("user_id", user.id)
      .maybeSingle()
    const { data: profile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle()
    const role = (
      (providerRow?.provider_type as string) ||
      (profile?.role as string) ||
      ""
    ).toLowerCase()
    if (role !== "trainer" && role !== "nutritionist") {
      return jsonError("Only trainers and nutritionists can connect Google Meet", 403)
    }

    const clientId = requireEnv("GOOGLE_OAUTH_CLIENT_ID")
    const redirectUri = requireEnv("GOOGLE_OAUTH_REDIRECT_URI")
    if (!redirectUri.startsWith("https://")) {
      return jsonError("Invalid GOOGLE_OAUTH_REDIRECT_URI", 500, "CONFIG_ERROR")
    }

    const state = randomUrlSafe(24)
    const codeVerifier = randomUrlSafe(48)
    const codeChallenge = await sha256Base64Url(codeVerifier)
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString()

    // Cleanup expired states opportunistically
    await admin
      .from("oauth_pending_states")
      .delete()
      .lt("expires_at", new Date().toISOString())

    const { error: stateErr } = await admin.from("oauth_pending_states").insert({
      state,
      user_id: user.id,
      provider: "google_meet",
      code_verifier: codeVerifier,
      expires_at: expiresAt,
    })
    if (stateErr) {
      console.error("[google-oauth-start] state insert:", stateErr.message)
      return jsonError("Could not start Google connection", 500)
    }

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: "code",
      scope: MEET_SCOPE,
      access_type: "offline",
      include_granted_scopes: "false",
      prompt: "consent",
      state,
      code_challenge: codeChallenge,
      code_challenge_method: "S256",
    })

    const authUrl = `${GOOGLE_AUTH_URL}?${params.toString()}`
    return jsonResponse({ auth_url: authUrl })
  } catch (err) {
    console.error("[google-oauth-start]", err)
    return jsonError("Could not start Google connection", 500)
  }
})
