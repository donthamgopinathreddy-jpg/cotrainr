// Zoom OAuth callback. Exchanges code for tokens and stores in user_integrations_zoom.
// Redirects to app deep link: cotrainr://video/zoom-connected
// @ts-nocheck - Deno/Supabase Edge Function

import { createClient } from "jsr:@supabase/supabase-js@2"

const APP_REDIRECT_DEFAULT = "cotrainr://video/zoom-connected"

function redirectWithError(appRedirect: string, errorCode: string) {
  const url = `${appRedirect}?error=${encodeURIComponent(errorCode)}`
  return Response.redirect(url, 302)
}

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get("code")
  const state = url.searchParams.get("state")
  const errorParam = url.searchParams.get("error")

  const appRedirect = Deno.env.get("APP_REDIRECT_URI")?.trim() || APP_REDIRECT_DEFAULT

  if (errorParam) {
    console.error("[zoom-oauth-callback] Zoom returned error:", errorParam)
    return redirectWithError(appRedirect, errorParam)
  }

  if (!code || !state) {
    console.error("[zoom-oauth-callback] Missing code or state in callback")
    return redirectWithError(appRedirect, "missing_code_or_state")
  }

  try {
    const clientId = Deno.env.get("ZOOM_CLIENT_ID")
    const clientSecret = Deno.env.get("ZOOM_CLIENT_SECRET")
    if (!clientId || !clientSecret || clientId.trim() === "" || clientSecret.trim() === "") {
      console.error("[zoom-oauth-callback] ZOOM_CLIENT_ID or ZOOM_CLIENT_SECRET not set")
      return redirectWithError(appRedirect, "zoom_not_configured")
    }

    const redirectUri = Deno.env.get("ZOOM_REDIRECT_URI")?.trim()
    if (!redirectUri || !redirectUri.startsWith("https://")) {
      console.error("[zoom-oauth-callback] ZOOM_REDIRECT_URI not set. Must match zoom-oauth-start and Zoom app config.")
      return redirectWithError(appRedirect, "redirect_uri_not_configured")
    }

    console.log("[zoom-oauth-callback] code received, redirect_uri=" + redirectUri.replace(/[a-z0-9]{20,}/g, "***"))

    const tokenRes = await fetch("https://zoom.us/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: "Basic " + btoa(clientId + ":" + clientSecret),
      },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
      }),
    })

    if (!tokenRes.ok) {
      const errText = await tokenRes.text()
      console.error("[zoom-oauth-callback] Token exchange failed:", tokenRes.status, errText)
      return redirectWithError(appRedirect, "token_exchange_failed")
    }

    const tokenData = await tokenRes.json()
    const accessToken = tokenData?.access_token
    const refreshToken = tokenData?.refresh_token

    if (!accessToken) {
      console.error("[zoom-oauth-callback] No access_token in Zoom response")
      return redirectWithError(appRedirect, "invalid_token_response")
    }
    if (!refreshToken) {
      console.error("[zoom-oauth-callback] No refresh_token in Zoom response")
      return redirectWithError(appRedirect, "invalid_token_response")
    }

    const expiresIn = tokenData?.expires_in ?? 3600
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString()

    let zoomAccountEmail: string | null = null
    try {
      const userRes = await fetch("https://api.zoom.us/v2/users/me", {
        headers: { Authorization: "Bearer " + accessToken },
      })
      if (userRes.ok) {
        const userData = await userRes.json()
        zoomAccountEmail = userData?.email ?? null
      }
    } catch (e) {
      console.warn("[zoom-oauth-callback] Could not fetch Zoom user email:", e)
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("[zoom-oauth-callback] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")
      return redirectWithError(appRedirect, "server_config_error")
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { error: upsertError } = await supabase.from("user_integrations_zoom").upsert(
      {
        user_id: state,
        zoom_account_email: zoomAccountEmail,
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_at: expiresAt,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    )

    if (upsertError) {
      console.error("[zoom-oauth-callback] DB upsert failed:", upsertError)
      return redirectWithError(appRedirect, "db_save_failed")
    }

    return Response.redirect(`${appRedirect}?success=1`, 302)
  } catch (err) {
    console.error("[zoom-oauth-callback] Unhandled error:", err)
    return redirectWithError(appRedirect, String(err))
  }
})
