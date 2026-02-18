// Zoom OAuth callback. Exchanges code for tokens and stores in user_integrations_zoom.
// Redirects to app deep link: cotrainr://video/zoom-connected

import { createClient } from "jsr:@supabase/supabase-js@2"

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get("code")
  const state = url.searchParams.get("state")
  const error = url.searchParams.get("error")

  const appRedirect = Deno.env.get("APP_REDIRECT_URI") ?? "cotrainr://video/zoom-connected"

  if (error) {
    return Response.redirect(appRedirect + "?error=" + encodeURIComponent(error), 302)
  }

  if (!code || !state) {
    return Response.redirect(appRedirect + "?error=missing_code_or_state", 302)
  }

  try {
    const clientId = Deno.env.get("ZOOM_CLIENT_ID")
    const clientSecret = Deno.env.get("ZOOM_CLIENT_SECRET")
    const baseUrl = url.origin + url.pathname.replace(/\/$/, "")
    const redirectUri = Deno.env.get("ZOOM_REDIRECT_URI") ?? baseUrl

    if (!clientId || !clientSecret) {
      return Response.redirect(appRedirect + "?error=zoom_not_configured", 302)
    }

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
      console.error("Zoom token exchange failed:", errText)
      return Response.redirect(appRedirect + "?error=token_exchange_failed", 302)
    }

    const tokenData = await tokenRes.json()
    const accessToken = tokenData.access_token
    const refreshToken = tokenData.refresh_token
    const expiresIn = tokenData.expires_in ?? 3600
    const expiresAt = new Date(Date.now() + expiresIn * 1000).toISOString()

    let zoomAccountEmail = null
    const userRes = await fetch("https://api.zoom.us/v2/users/me", {
      headers: { Authorization: "Bearer " + accessToken },
    })
    if (userRes.ok) {
      const userData = await userRes.json()
      zoomAccountEmail = userData.email ?? null
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    await supabase.from("user_integrations_zoom").upsert(
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

    return Response.redirect(appRedirect + "?success=1", 302)
  } catch (err) {
    console.error("zoom-oauth-callback error:", err)
    return Response.redirect(appRedirect + "?error=" + encodeURIComponent(String(err)), 302)
  }
})
