// Creates a video session with an auto-generated Google Meet space.
// Manual/external paste remains supported for admin/legacy callers only.
// Trainer/nutritionist + accepted lead required.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import {
  corsHeaders,
  createMeetSpace,
  getValidGoogleAccessToken,
  jsonError,
  jsonResponse,
} from "../_shared/google_meet.ts"
import { deliverNotificationRows } from "../_shared/push_deliver.ts"

function isHttpsUrl(value: string): boolean {
  try {
    const u = new URL(value)
    return u.protocol === "https:"
  } catch {
    return false
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  let createdMeetSpaceName: string | null = null

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) return jsonError("Missing Authorization header", 401)

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseAnon = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: { user }, error } = await supabaseAnon.auth.getUser()
    if (error || !user) return jsonError("Unauthorized", 401)

    const supabase = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    const { data: providerRow } = await supabase
      .from("providers")
      .select("provider_type")
      .eq("user_id", user.id)
      .maybeSingle()
    const providerType = (providerRow?.provider_type as string)?.toLowerCase()

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle()
    const profileRole = (profile?.role as string)?.toLowerCase()

    const isTrainer = providerType === "trainer" || profileRole === "trainer"
    const isNutritionist =
      providerType === "nutritionist" || profileRole === "nutritionist"
    if (!isTrainer && !isNutritionist) {
      return jsonError(
        "Only trainers and nutritionists can create video sessions",
        403,
        "FORBIDDEN_ROLE",
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
      provider = "google_meet",
      join_url: joinUrlParam = null,
      client_request_id = null,
    } = body as {
      title?: string
      description?: string | null
      scheduled_start: string
      duration_minutes?: number
      max_participants?: number
      participant_ids?: string[]
      provider?: string
      join_url?: string | null
      client_request_id?: string | null
    }

    // Idempotency: return existing session for the same client_request_id.
    if (
      typeof client_request_id === "string" &&
      client_request_id.trim().length >= 8
    ) {
      const key = client_request_id.trim().slice(0, 128)
      const { data: existingReq } = await supabase
        .from("video_session_create_requests")
        .select("session_id")
        .eq("user_id", user.id)
        .eq("client_request_id", key)
        .maybeSingle()
      if (existingReq?.session_id) {
        const { data: existingSession } = await supabase
          .from("video_sessions")
          .select(
            "id, join_url, title, scheduled_start, created_at, duration_minutes, status, description, host_id, provider",
          )
          .eq("id", existingReq.session_id)
          .maybeSingle()
        if (existingSession) {
          return jsonResponse(existingSession)
        }
      }
    }

    if (!scheduled_start) {
      return jsonError("scheduled_start is required", 400, "VALIDATION")
    }

    const startDate = new Date(scheduled_start)
    if (Number.isNaN(startDate.getTime())) {
      return jsonError("Invalid scheduled_start", 400, "VALIDATION")
    }
    if (startDate.getTime() < Date.now() - 60_000) {
      return jsonError(
        "Scheduled time must be in the future",
        400,
        "VALIDATION",
      )
    }

    const titleTrim = typeof title === "string" ? title.trim() : ""
    if (!titleTrim || titleTrim.length > 80) {
      return jsonError(
        "Title is required (max 80 characters)",
        400,
        "VALIDATION",
      )
    }

    const duration = Math.min(180, Math.max(15, Number(duration_minutes) || 30))
    const participantIds = Array.isArray(participant_ids)
      ? [
        ...new Set(
          participant_ids.filter(
            (id) => typeof id === "string" && id.length > 0,
          ),
        ),
      ]
      : []

    if (participantIds.length === 0) {
      return jsonError(
        "Select at least one member to invite",
        400,
        "VALIDATION",
      )
    }

    const maxSlots = Math.min(5, Math.max(2, Number(max_participants) || 5))
    if (participantIds.length > maxSlots - 1) {
      return jsonError(
        `Max ${maxSlots - 1} invitees (host occupies 1 slot)`,
        400,
        "VALIDATION",
      )
    }

    const { data: acceptedLeads, error: leadsError } = await supabase
      .from("leads")
      .select("client_id")
      .eq("provider_id", user.id)
      .eq("status", "accepted")
      .in("client_id", participantIds)

    if (leadsError) {
      console.error("create-video-session leads check:", leadsError.message)
      return jsonError(
        "Could not verify member relationships",
        500,
        "RELATIONSHIP_CHECK_FAILED",
      )
    }

    const allowed = new Set(
      (acceptedLeads ?? []).map((r: { client_id: string }) => r.client_id),
    )
    const unauthorized = participantIds.filter((id) => !allowed.has(id))
    if (unauthorized.length > 0) {
      return jsonError(
        "You can only invite members with an accepted connection",
        403,
        "RELATIONSHIP_REQUIRED",
      )
    }

    const useGoogleMeet =
      !provider ||
      provider === "google_meet" ||
      provider === "meet"

    let joinUrl: string
    let effectiveProvider: string
    let providerMeetingId: string | null = null
    let meetSpaceName: string | null = null
    let meetingCode: string | null = null

    if (useGoogleMeet) {
      const tokenResult = await getValidGoogleAccessToken(supabase, user.id)
      if (!tokenResult.ok) {
        return jsonError(tokenResult.message, 400, tokenResult.code)
      }

      const meetResult = await createMeetSpace(tokenResult.accessToken)
      if (!meetResult.ok) {
        if (
          meetResult.code === "GOOGLE_UNAUTHORIZED" ||
          meetResult.code === "GOOGLE_FORBIDDEN"
        ) {
          await supabase
            .from("user_integrations_google")
            .update({
              reconnect_required: true,
              updated_at: new Date().toISOString(),
            })
            .eq("user_id", user.id)
          return jsonError(
            "Reconnect Google Meet to continue.",
            400,
            "GOOGLE_RECONNECT_REQUIRED",
          )
        }
        return jsonError(
          meetResult.message,
          meetResult.httpStatus && meetResult.httpStatus >= 500 ? 502 : 400,
          meetResult.code,
        )
      }

      joinUrl = meetResult.space.meetingUri
      meetSpaceName = meetResult.space.name
      meetingCode = meetResult.space.meetingCode ?? null
      providerMeetingId = meetingCode || meetSpaceName
      effectiveProvider = "google_meet"
      createdMeetSpaceName = meetSpaceName
    } else if (provider === "external" || provider === "manual") {
      // Legacy/manual path kept for compatibility — not used by primary Flutter UI.
      const trimmed =
        typeof joinUrlParam === "string" ? joinUrlParam.trim() : ""
      if (!trimmed || !isHttpsUrl(trimmed)) {
        return jsonError(
          "A valid https meeting link is required",
          400,
          "VALIDATION",
        )
      }
      joinUrl = trimmed
      effectiveProvider = "external"
    } else {
      return jsonError(
        "Unsupported meeting provider",
        400,
        "UNSUPPORTED_PROVIDER",
      )
    }

    // Canonical model: membership lives in video_session_participants only.
    // Do not write obsolete video_sessions.client_id.
    const insertPayload: Record<string, unknown> = {
      host_id: user.id,
      provider: effectiveProvider,
      title: titleTrim,
      description:
        typeof description === "string" && description.trim().length > 0
          ? description.trim().slice(0, 500)
          : null,
      scheduled_start,
      duration_minutes: duration,
      max_participants: maxSlots,
      status: "scheduled",
      join_url: joinUrl,
      provider_meeting_id: providerMeetingId,
    }

    const { data: session, error: insertError } = await supabase
      .from("video_sessions")
      .insert(insertPayload)
      .select(
        "id, join_url, title, scheduled_start, created_at, duration_minutes, status, description, host_id, provider",
      )
      .single()

    if (insertError || !session) {
      console.error("Insert video_sessions error:", insertError)
      // Best-effort: cannot delete Meet spaces via API without endActiveConference;
      // orphan Meet URLs without Cotrainr rows are harmless (unused links).
      return jsonError("Failed to save session", 500, "DB_INSERT_FAILED")
    }

    if (effectiveProvider === "google_meet" && meetSpaceName) {
      await supabase.from("video_session_provider_meta").upsert({
        session_id: session.id,
        provider: "google_meet",
        external_space_id: meetSpaceName,
        meeting_code: meetingCode,
      })
    }

    const partErr = await upsertParticipants(
      supabase,
      session.id as string,
      user.id,
      participantIds,
    )
    if (partErr) {
      console.error("video_session_participants upsert:", partErr)
      await supabase.from("video_sessions").delete().eq("id", session.id)
      return jsonError(
        "Failed to add session participants",
        500,
        "PARTICIPANTS_FAILED",
      )
    }
    console.log(JSON.stringify({
      event: "participant_inserted",
      session_id: session.id,
      participant_count: participantIds.length,
    }))
    console.log(JSON.stringify({
      event: "session_created",
      session_id: session.id,
      provider: effectiveProvider,
    }))

    await notifySessionCreated(supabase, session.id as string)

    if (
      typeof client_request_id === "string" &&
      client_request_id.trim().length >= 8
    ) {
      await supabase.from("video_session_create_requests").upsert({
        user_id: user.id,
        client_request_id: client_request_id.trim().slice(0, 128),
        session_id: session.id,
      })
    }

    return jsonResponse(session)
  } catch (err) {
    console.error("create-video-session error:", err)
    return jsonError(
      "Something went wrong. Please try again.",
      500,
      "INTERNAL",
    )
  }
})

async function notifySessionCreated(
  supabase: ReturnType<typeof createClient>,
  sessionId: string,
): Promise<void> {
  const { data, error } = await supabase.rpc("notify_video_session_created", {
    p_session_id: sessionId,
  })
  if (error) {
    console.error(JSON.stringify({
      event: "notification_event_failed",
      code: error.code,
      message: error.message,
    }))
    return
  }
  const rows = Array.isArray(data) ? data : []
  console.log(JSON.stringify({
    event: "notification_event_inserted",
    session_id: sessionId,
    count: rows.length,
  }))
  try {
    await deliverNotificationRows(rows)
  } catch (e) {
    console.error(JSON.stringify({
      event: "fcm_send_attempted",
      errorCode: String(e).slice(0, 200),
    }))
  }
}

async function upsertParticipants(
  supabase: ReturnType<typeof createClient>,
  sessionId: string,
  hostId: string,
  participantIds: string[],
): Promise<string | null> {
  const rows = [
    { session_id: sessionId, user_id: hostId, role: "host" },
    ...participantIds.map((uid) => ({
      session_id: sessionId,
      user_id: uid,
      role: "participant",
    })),
  ]
  const { error } = await supabase.from("video_session_participants").upsert(
    rows,
    {
      onConflict: "session_id,user_id",
      ignoreDuplicates: true,
    },
  )
  return error?.message ?? null
}
