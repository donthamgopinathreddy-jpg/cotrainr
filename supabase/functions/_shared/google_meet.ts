// Shared Google Meet OAuth + Meet API helpers for Edge Functions.
// @ts-nocheck

export const MEET_SCOPE = "https://www.googleapis.com/auth/meetings.space.created"
export const GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
export const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
export const GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
export const MEET_SPACES_URL = "https://meet.googleapis.com/v2/spaces"

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

export function jsonError(
  message: string,
  status: number,
  code?: string,
  extra?: Record<string, unknown>,
) {
  return new Response(
    JSON.stringify({ error: message, code: code ?? undefined, ...extra }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  )
}

export function requireEnv(name: string): string {
  const v = Deno.env.get(name)?.trim()
  if (!v) throw new Error(`Missing env ${name}`)
  return v
}

export function randomUrlSafe(bytes = 32): string {
  const buf = new Uint8Array(bytes)
  crypto.getRandomValues(buf)
  return btoa(String.fromCharCode(...buf))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")
}

export async function sha256Base64Url(input: string): Promise<string> {
  const data = new TextEncoder().encode(input)
  const hash = await crypto.subtle.digest("SHA-256", data)
  const bytes = new Uint8Array(hash)
  let binary = ""
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

export type GoogleTokenRow = {
  user_id: string
  google_account_id: string | null
  google_email: string | null
  access_token: string
  refresh_token: string | null
  access_token_expires_at: string
  scopes: string
  reconnect_required: boolean
  connected_at: string
  disconnected_at: string | null
}

export async function exchangeAuthorizationCode(opts: {
  code: string
  redirectUri: string
  codeVerifier?: string | null
}): Promise<{
  access_token: string
  refresh_token?: string
  expires_in: number
  scope?: string
  id_token?: string
}> {
  const clientId = requireEnv("GOOGLE_OAUTH_CLIENT_ID")
  const clientSecret = requireEnv("GOOGLE_OAUTH_CLIENT_SECRET")
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code: opts.code,
    redirect_uri: opts.redirectUri,
    client_id: clientId,
    client_secret: clientSecret,
  })
  if (opts.codeVerifier) {
    body.set("code_verifier", opts.codeVerifier)
  }
  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  })
  if (!res.ok) {
    const text = await res.text()
    console.error("[google] token exchange failed:", res.status, text.slice(0, 200))
    throw new Error("TOKEN_EXCHANGE_FAILED")
  }
  return await res.json()
}

export async function refreshAccessToken(refreshToken: string): Promise<{
  access_token: string
  expires_in: number
  scope?: string
  refresh_token?: string
}> {
  const clientId = requireEnv("GOOGLE_OAUTH_CLIENT_ID")
  const clientSecret = requireEnv("GOOGLE_OAUTH_CLIENT_SECRET")
  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: clientId,
      client_secret: clientSecret,
    }),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error("[google] refresh failed:", res.status, text.slice(0, 200))
    const err = new Error("REFRESH_FAILED")
    ;(err as { status?: number }).status = res.status
    throw err
  }
  return await res.json()
}

export async function fetchGoogleEmail(accessToken: string): Promise<{
  email?: string
  sub?: string
}> {
  try {
    const res = await fetch(GOOGLE_USERINFO_URL, {
      headers: { Authorization: `Bearer ${accessToken}` },
    })
    if (!res.ok) return {}
    const data = await res.json()
    return { email: data.email, sub: data.sub }
  } catch {
    return {}
  }
}

/** Returns a valid access token or marks reconnect_required. */
export async function getValidGoogleAccessToken(
  supabaseAdmin: { from: (t: string) => any },
  userId: string,
): Promise<
  | { ok: true; accessToken: string; row: GoogleTokenRow }
  | { ok: false; code: string; message: string }
> {
  const { data: row, error } = await supabaseAdmin
    .from("user_integrations_google")
    .select("*")
    .eq("user_id", userId)
    .is("disconnected_at", null)
    .maybeSingle()

  if (error || !row) {
    return {
      ok: false,
      code: "GOOGLE_NOT_CONNECTED",
      message: "Connect Google Meet to create video sessions.",
    }
  }

  if (row.reconnect_required) {
    return {
      ok: false,
      code: "GOOGLE_RECONNECT_REQUIRED",
      message: "Reconnect Google Meet to continue.",
    }
  }

  const expiresAt = new Date(row.access_token_expires_at).getTime()
  const skewMs = 2 * 60 * 1000
  if (expiresAt > Date.now() + skewMs) {
    return { ok: true, accessToken: row.access_token, row }
  }

  if (!row.refresh_token) {
    await supabaseAdmin
      .from("user_integrations_google")
      .update({
        reconnect_required: true,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId)
    return {
      ok: false,
      code: "GOOGLE_RECONNECT_REQUIRED",
      message: "Reconnect Google Meet to continue.",
    }
  }

  try {
    const refreshed = await refreshAccessToken(row.refresh_token)
    const expiresAtNew = new Date(
      Date.now() + (refreshed.expires_in ?? 3600) * 1000,
    ).toISOString()
    const update: Record<string, unknown> = {
      access_token: refreshed.access_token,
      access_token_expires_at: expiresAtNew,
      updated_at: new Date().toISOString(),
      reconnect_required: false,
    }
    if (refreshed.refresh_token) {
      update.refresh_token = refreshed.refresh_token
    }
    if (refreshed.scope) update.scopes = refreshed.scope

    await supabaseAdmin
      .from("user_integrations_google")
      .update(update)
      .eq("user_id", userId)

    return {
      ok: true,
      accessToken: refreshed.access_token,
      row: { ...row, ...update } as GoogleTokenRow,
    }
  } catch (e) {
    const status = (e as { status?: number }).status
    if (status === 400 || status === 401) {
      await supabaseAdmin
        .from("user_integrations_google")
        .update({
          reconnect_required: true,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId)
      return {
        ok: false,
        code: "GOOGLE_RECONNECT_REQUIRED",
        message: "Reconnect Google Meet to continue.",
      }
    }
    return {
      ok: false,
      code: "GOOGLE_TOKEN_REFRESH_FAILED",
      message: "Could not refresh Google Meet access. Try again.",
    }
  }
}

export type MeetSpace = {
  name: string
  meetingUri: string
  meetingCode?: string
}

export async function createMeetSpace(accessToken: string): Promise<
  | { ok: true; space: MeetSpace }
  | { ok: false; code: string; message: string; httpStatus?: number }
> {
  const res = await fetch(MEET_SPACES_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    // Empty Space body is valid; Google applies defaults.
    body: JSON.stringify({}),
  })

  if (res.status === 401) {
    return {
      ok: false,
      code: "GOOGLE_UNAUTHORIZED",
      message: "Google Meet authorization expired. Reconnect Google Meet.",
      httpStatus: 401,
    }
  }
  if (res.status === 403) {
    return {
      ok: false,
      code: "GOOGLE_FORBIDDEN",
      message: "Google Meet permission denied. Reconnect Google Meet.",
      httpStatus: 403,
    }
  }
  if (res.status === 429) {
    return {
      ok: false,
      code: "GOOGLE_RATE_LIMITED",
      message: "Google Meet is rate-limited. Try again in a moment.",
      httpStatus: 429,
    }
  }
  if (!res.ok) {
    const text = await res.text()
    console.error("[google] spaces.create failed:", res.status, text.slice(0, 300))
    return {
      ok: false,
      code: "GOOGLE_MEET_CREATE_FAILED",
      message: "Could not create a Google Meet link. Try again.",
      httpStatus: res.status,
    }
  }

  const space = await res.json()
  const meetingUri = space?.meetingUri as string | undefined
  const name = space?.name as string | undefined
  if (!meetingUri || !name) {
    return {
      ok: false,
      code: "GOOGLE_MEET_INVALID_RESPONSE",
      message: "Google Meet returned an incomplete meeting. Try again.",
    }
  }

  return {
    ok: true,
    space: {
      name,
      meetingUri,
      meetingCode: space.meetingCode,
    },
  }
}
