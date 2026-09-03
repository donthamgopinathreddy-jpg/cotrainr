// Google OAuth callback for Meet. Exchanges code, stores tokens, redirects to app.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import {
  MEET_SCOPE,
  exchangeAuthorizationCode,
  fetchGoogleEmail,
  requireEnv,
} from "../_shared/google_meet.ts"

const APP_REDIRECT_DEFAULT = "cotrainr://video/google-connected"

function accountStatusIsRestricted(
  status: unknown,
  suspendedUntil: unknown,
): boolean {
  const raw = typeof status === "string" ? status.trim().toLowerCase() : ""
  if (raw === "banned") return true
  if (raw === "suspended") {
    if (suspendedUntil == null || String(suspendedUntil).trim() === "") {
      return true
    }
    const untilMs = Date.parse(String(suspendedUntil))
    if (Number.isNaN(untilMs)) return true
    return untilMs > Date.now()
  }
  if (raw === "active") return false
  return true
}

function buildAppUri(base: string, params: Record<string, string>) {
  // Avoid URL() for custom schemes — some runtimes normalize incorrectly.
  const u = new URL(base.includes("://") ? base : APP_REDIRECT_DEFAULT)
  for (const [k, v] of Object.entries(params)) {
    u.searchParams.set(k, v)
  }
  // Ensure we always emit the exact custom-scheme form Android expects.
  const path = u.pathname || "/google-connected"
  const qs = u.searchParams.toString()
  return `cotrainr://video${path.startsWith("/") ? path : `/${path}`}${
    qs ? `?${qs}` : ""
  }`
}

/**
 * Prefer HTTP 302 Location → custom scheme (opens Cotrainr on Android).
 * Include a properly typed HTML body so if a browser ignores Location it
 * still renders UI (never raw source via text/plain).
 */
function redirectApp(base: string, params: Record<string, string>) {
  const target = buildAppUri(base, params)
  const safeHref = target
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
  const isError = Boolean(params.error)
  const heading = isError
    ? "Google Meet connection failed"
    : "Google Meet connected successfully"
  const message = isError
    ? "Return to Cotrainr and try again."
    : "Google Meet connected successfully. Return to Cotrainr."

  const html =
    "<!DOCTYPE html>\n" +
    '<html lang="en">\n' +
    "<head>\n" +
    '<meta charset="utf-8"/>\n' +
    '<meta name="viewport" content="width=device-width, initial-scale=1"/>\n' +
    `<meta http-equiv="refresh" content="0;url=${safeHref}"/>\n` +
    `<title>${heading}</title>\n` +
    "<style>body{font-family:system-ui,sans-serif;padding:2rem;text-align:center;" +
    "background:#111;color:#f5f5f5}a{display:inline-block;margin-top:1.25rem;" +
    "padding:.75rem 1.25rem;background:#ff7a1a;color:#fff;text-decoration:none;" +
    "border-radius:8px;font-weight:600}</style>\n" +
    "<script>\n" +
    "(function(){var u=" +
    JSON.stringify(target) +
    ";try{window.location.replace(u);}catch(e){}" +
    "setTimeout(function(){try{window.location.href=u;}catch(e2){}},200);" +
    "})();\n" +
    "</script>\n" +
    "</head>\n" +
    "<body>\n" +
    `<h1>${heading}</h1>\n` +
    `<p>${message}</p>\n` +
    `<p><a href="${safeHref}">Open Cotrainr</a></p>\n` +
    "</body>\n" +
    "</html>\n"

  // Manual 302 — Response.redirect() may reject non-http(s) schemes.
  return new Response(html, {
    status: 302,
    headers: {
      Location: target,
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  })
}

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get("code")
  const state = url.searchParams.get("state")
  const errorParam = url.searchParams.get("error")
  const appRedirect =
    Deno.env.get("GOOGLE_APP_REDIRECT_URI")?.trim() || APP_REDIRECT_DEFAULT

  if (errorParam) {
    console.log("[google-oauth-callback] google_error_param")
    return redirectApp(appRedirect, { error: errorParam })
  }
  if (!code || !state) {
    console.log("[google-oauth-callback] missing_code_or_state")
    return redirectApp(appRedirect, { error: "missing_code_or_state" })
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    const { data: pending, error: pendingErr } = await admin
      .from("oauth_pending_states")
      .select("*")
      .eq("state", state)
      .eq("provider", "google_meet")
      .maybeSingle()

    if (pendingErr || !pending) {
      console.log("[google-oauth-callback] invalid_state")
      return redirectApp(appRedirect, { error: "invalid_state" })
    }

    console.log(
      "[google-oauth-callback] state_ok user_prefix=" +
        String(pending.user_id || "").slice(0, 8),
    )

    // One-time use / replay protection
    await admin.from("oauth_pending_states").delete().eq("state", state)

    if (new Date(pending.expires_at).getTime() < Date.now()) {
      console.log("[google-oauth-callback] state_expired")
      return redirectApp(appRedirect, { error: "state_expired" })
    }

    const ownerId = pending.user_id
    if (typeof ownerId !== "string" || ownerId.length === 0) {
      console.log("[google-oauth-callback] account_restricted")
      return redirectApp(appRedirect, { error: "account_restricted" })
    }

    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("account_status, suspended_until")
      .eq("id", ownerId)
      .maybeSingle()
    if (
      profileErr ||
      !profile ||
      accountStatusIsRestricted(profile.account_status, profile.suspended_until)
    ) {
      console.log("[google-oauth-callback] account_restricted")
      return redirectApp(appRedirect, { error: "account_restricted" })
    }

    const redirectUri = requireEnv("GOOGLE_OAUTH_REDIRECT_URI")
    const tokenData = await exchangeAuthorizationCode({
      code,
      redirectUri,
      codeVerifier: pending.code_verifier,
    })

    if (!tokenData.access_token) {
      console.log("[google-oauth-callback] invalid_token_response")
      return redirectApp(appRedirect, { error: "invalid_token_response" })
    }

    console.log("[google-oauth-callback] token_exchange_ok")

    const expiresAt = new Date(
      Date.now() + (tokenData.expires_in ?? 3600) * 1000,
    ).toISOString()

    const info = await fetchGoogleEmail(tokenData.access_token)

    // Prefer new refresh token; keep existing if Google omits it on re-consent.
    const { data: existing } = await admin
      .from("user_integrations_google")
      .select("refresh_token")
      .eq("user_id", pending.user_id)
      .maybeSingle()

    const refreshToken =
      tokenData.refresh_token || existing?.refresh_token || null
    if (!refreshToken) {
      console.log("[google-oauth-callback] missing_refresh_token")
      return redirectApp(appRedirect, { error: "missing_refresh_token" })
    }

    const { error: upsertErr } = await admin
      .from("user_integrations_google")
      .upsert(
        {
          user_id: pending.user_id,
          google_account_id: info.sub ?? null,
          google_email: info.email ?? null,
          access_token: tokenData.access_token,
          refresh_token: refreshToken,
          access_token_expires_at: expiresAt,
          scopes: tokenData.scope || MEET_SCOPE,
          reconnect_required: false,
          connected_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          disconnected_at: null,
        },
        { onConflict: "user_id" },
      )

    if (upsertErr) {
      console.error("[google-oauth-callback] upsert_failed:", upsertErr.message)
      return redirectApp(appRedirect, { error: "db_save_failed" })
    }

    console.log("[google-oauth-callback] integration_upsert_ok")
    console.log("[google-oauth-callback] redirecting_to_app")
    return redirectApp(appRedirect, { success: "1" })
  } catch (err) {
    console.error(
      "[google-oauth-callback] failed:",
      String(err?.message || err),
    )
    const errCode =
      String(err?.message || "") === "TOKEN_EXCHANGE_FAILED"
        ? "token_exchange_failed"
        : "callback_failed"
    return redirectApp(appRedirect, { error: errCode })
  }
})
