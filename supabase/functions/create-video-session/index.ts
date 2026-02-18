// Creates a Zoom meeting and stores session in Supabase.
// Client never touches Zoom secret. Host must be connected (user_integrations_zoom).

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
    const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).single()
    const role = (profile?.role as string)?.toLowerCase()
    if (role !== "trainer") {
      return new Response(
        JSON.stringify({ error: "Only trainers can create video sessions" }),
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
    } = body as {
      title?: string
      description?: string | null
      scheduled_start: string
      duration_minutes?: number
      max_participants?: number
    }

    if (!scheduled_start) {
      return new Response(
        JSON.stringify({ error: "scheduled_start is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const accessToken = await refreshZoomToken(supabase, user.id)
    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: "Zoom not connected or token expired. Please connect Zoom first." }),
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
    const joinUrl = zoomMeeting.join_url
    const hostStartUrl = zoomMeeting.start_url
    const providerMeetingId = zoomMeeting.id?.toString() ?? null

    const { data: session, error: insertError } = await supabase
      .from("video_sessions")
      .insert({
        host_id: user.id,
        provider: "zoom",
        title,
        description,
        scheduled_start: scheduled_start,
        duration_minutes,
        max_participants,
        status: "scheduled",
        join_url: joinUrl,
        provider_meeting_id: providerMeetingId,
      })
      .select("id, join_url, title, scheduled_start")
      .single()

    if (insertError) {
      console.error("Insert video_sessions error:", insertError)
      return new Response(
        JSON.stringify({ error: "Failed to save session" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    await supabase.from("video_session_host_meta").insert({
      session_id: session.id,
      host_id: user.id,
      host_start_url: hostStartUrl,
    })

    await supabase.from("video_session_participants").insert({
      session_id: session.id,
      user_id: user.id,
      role: "host",
    })

    return new Response(
      JSON.stringify({
        id: session.id,
        join_url: session.join_url,
        title: session.title,
        scheduled_start: session.scheduled_start,
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
