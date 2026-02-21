# Video Sessions Edge Functions – Manual Setup

Create these 4 functions in Supabase Dashboard → Edge Functions.  
For each function, use the code below as the `index.ts` content.

**Required secrets** (Project Settings → Edge Functions → Secrets):
- `ZOOM_CLIENT_ID`
- `ZOOM_CLIENT_SECRET`
- `ZOOM_REDIRECT_URI` (e.g. `https://YOUR_PROJECT.supabase.co/functions/v1/zoom-oauth-callback`)
- `APP_REDIRECT_URI` (optional, defaults to `cotrainr://video/zoom-connected`)

---

## 1. zoom-oauth-start

**Path:** `zoom-oauth-start/index.ts`

```typescript
// Returns Zoom OAuth authorization URL for the host to connect their account.
// Client calls this, then opens the URL in browser. Zoom redirects to zoom-oauth-callback.

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const clientId = Deno.env.get("ZOOM_CLIENT_ID")
    const redirectUri = Deno.env.get("ZOOM_REDIRECT_URI") ?? `${Deno.env.get("SUPABASE_URL")!.replace(".supabase.co", "")}/functions/v1/zoom-oauth-callback`
    const state = user.id

    if (!clientId) {
      return new Response(
        JSON.stringify({ error: "Zoom OAuth not configured. Set ZOOM_CLIENT_ID, ZOOM_CLIENT_SECRET, ZOOM_REDIRECT_URI." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const authUrl = `https://zoom.us/oauth/authorize?response_type=code&client_id=${encodeURIComponent(clientId)}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}`

    return new Response(
      JSON.stringify({ auth_url: authUrl }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    console.error("zoom-oauth-start error:", err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
```

---

## 2. zoom-oauth-callback

**Path:** `zoom-oauth-callback/index.ts`

```typescript
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
```

---

## 3. zoom-disconnect

**Path:** `zoom-disconnect/index.ts`

```typescript
// Disconnects Zoom integration for the current user (deletes tokens).

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    await supabaseAdmin.from("user_integrations_zoom").delete().eq("user_id", user.id)

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    console.error("zoom-disconnect error:", err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
```

---

## 4. create-video-session

**Path:** `create-video-session/index.ts`

```typescript
// Creates a Zoom meeting OR stores external link. Stores session in Supabase.
// Trainer and nutritionist can create. Participants added to video_session_participants.

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

async function refreshZoomToken(supabase: ReturnType<typeof createClient>, userId: string): Promise<string | null> {
  const { data: row } = await supabase
    .from("user_integrations_zoom")
    .select("access_token, refresh_token, expires_at")
    .eq("user_id", userId)
    .single()

  if (!row) return null

  const expiresAt = new Date(row.expires_at)
  const now = new Date()
  if (expiresAt > new Date(now.getTime() + 5 * 60 * 1000)) {
    return row.access_token
  }

  const clientId = Deno.env.get("ZOOM_CLIENT_ID")
  const clientSecret = Deno.env.get("ZOOM_CLIENT_SECRET")
  if (!clientId || !clientSecret) return null

  const refreshRes = await fetch("https://zoom.us/oauth/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: row.refresh_token,
    }),
  })

  if (!refreshRes.ok) return null

  const tokenData = await refreshRes.json()
  const expiresAtNew = new Date(Date.now() + (tokenData.expires_in ?? 3600) * 1000).toISOString()

  await supabase.from("user_integrations_zoom").update({
    access_token: tokenData.access_token,
    refresh_token: tokenData.refresh_token ?? row.refresh_token,
    expires_at: expiresAtNew,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId)

  return tokenData.access_token
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabaseAnon = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error } = await supabaseAnon.auth.getUser()
    if (error || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // Host authorization: DB truth only. Do NOT trust client-provided role params.
    const { data: providerRow } = await supabase
      .from("providers")
      .select("provider_type")
      .eq("user_id", user.id)
      .maybeSingle()
    const providerType = (providerRow?.provider_type as string)?.toLowerCase()

    const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle()
    const profileRole = (profile?.role as string)?.toLowerCase()

    const isTrainer = providerType === "trainer" || profileRole === "trainer"
    const isNutritionist = providerType === "nutritionist" || profileRole === "nutritionist"
    if (!isTrainer && !isNutritionist) {
      return new Response(
        JSON.stringify({ error: "Only trainers and nutritionists can create video sessions" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const body = await req.json()
    const {
      title = "Video Session",
      description = null,
      scheduled_start,
      duration_minutes = 30,
      max_participants = 5,
      participant_ids = [],
      provider = "zoom",
      join_url: joinUrlParam = null,
    } = body as {
      title?: string
      description?: string | null
      scheduled_start: string
      duration_minutes?: number
      max_participants?: number
      participant_ids?: string[]
      provider?: string
      join_url?: string | null
    }

    if (!scheduled_start) {
      return new Response(
        JSON.stringify({ error: "scheduled_start is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const participantIds = Array.isArray(participant_ids) ? participant_ids : []
    const maxSlots = Math.min(5, Math.max(2, max_participants))
    if (participantIds.length > maxSlots - 1) {
      return new Response(
        JSON.stringify({ error: `Max ${maxSlots - 1} invitees (host occupies 1 slot)` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    let joinUrl: string
    let providerMeetingId: string | null = null
    let hostStartUrl: string | null = null

    if (provider === "external") {
      const trimmed = typeof joinUrlParam === "string" ? (joinUrlParam as string).trim() : ""
      if (!trimmed || (!trimmed.startsWith("http://") && !trimmed.startsWith("https://"))) {
        return new Response(
          JSON.stringify({ error: "provider='external' requires a non-empty join_url (valid http/https URL)" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }
      joinUrl = trimmed
    } else {
      const accessToken = await refreshZoomToken(supabase, user.id)
      if (!accessToken) {
        return new Response(
          JSON.stringify({ error: "Zoom not connected or token expired. Use external link or connect Zoom first." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }

      const startDate = new Date(scheduled_start)
      const zoomRes = await fetch("https://api.zoom.us/v2/users/me/meetings", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          topic: title,
          agenda: description ?? "",
          type: 2,
          start_time: startDate.toISOString(),
          duration: Math.min(120, Math.max(15, duration_minutes)),
          settings: {
            host_video: true,
            participant_video: true,
            join_before_host: false,
            mute_upon_entry: false,
            waiting_room: true,
            approval_type: 0,
            audio: "both",
            auto_recording: "none",
          },
        }),
      })

      if (!zoomRes.ok) {
        const errText = await zoomRes.text()
        console.error("Zoom API error:", errText)
        return new Response(
          JSON.stringify({ error: "Failed to create Zoom meeting" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }

      const zoomMeeting = await zoomRes.json()
      joinUrl = zoomMeeting.join_url
      hostStartUrl = zoomMeeting.start_url ?? null
      providerMeetingId = zoomMeeting.id?.toString() ?? null
    }

    const effectiveProvider = provider === "external" ? "external" : "zoom"

    const { data: session, error: insertError } = await supabase
      .from("video_sessions")
      .insert({
        host_id: user.id,
        provider: effectiveProvider,
        title,
        description,
        scheduled_start: scheduled_start,
        duration_minutes,
        max_participants: maxSlots,
        status: "scheduled",
        join_url: joinUrl,
        provider_meeting_id: providerMeetingId,
      })
      .select("id, join_url, title, scheduled_start, created_at")
      .single()

    if (insertError) {
      console.error("Insert video_sessions error:", insertError)
      return new Response(
        JSON.stringify({ error: "Failed to save session" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (hostStartUrl && effectiveProvider === "zoom") {
      await supabase.from("video_session_host_meta").insert({
        session_id: session.id,
        host_id: user.id,
        host_start_url: hostStartUrl,
      })
    }

    const participantsToInsert: { session_id: string; user_id: string; role: string }[] = [
      { session_id: session.id, user_id: user.id, role: "host" },
      ...participantIds.map((uid) => ({ session_id: session.id, user_id: uid, role: "participant" })),
    ]

    const { error: upsertErr } = await supabase.from("video_session_participants").upsert(participantsToInsert, {
      onConflict: "session_id,user_id",
      ignoreDuplicates: true,
    })
    if (upsertErr) console.error("video_session_participants upsert:", upsertErr)

    return new Response(
      JSON.stringify({
        id: session.id,
        join_url: session.join_url,
        title: session.title,
        scheduled_start: session.scheduled_start,
        created_at: session.created_at,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err) {
    console.error("create-video-session error:", err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
```

---

## Function names (exact)

| Function name           | Purpose                                      |
|------------------------|----------------------------------------------|
| `zoom-oauth-start`     | Returns Zoom OAuth URL for Connect Zoom      |
| `zoom-oauth-callback`  | Handles Zoom redirect, stores tokens         |
| `zoom-disconnect`      | Removes Zoom integration for user            |
| `create-video-session` | Creates Zoom meeting or external-link session|
