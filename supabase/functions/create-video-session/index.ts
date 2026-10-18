// Creates a video session with an auto-generated Google Meet space.
// Manual/external paste remains supported for admin/legacy callers only.
// Verified trainer/nutritionist + accepted lead required.
// Idempotency columns come from 20261018110000. Do not deploy this handler
// until that migration is applied.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"
import {
  createMeetSpace,
  getValidGoogleAccessToken,
  jsonError,
  corsHeaders,
} from "../_shared/google_meet.ts"
import { handleCreateVideoSession } from "./handler.ts"

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

function mapLedgerRow(data) {
  return {
    status: data.status,
    sessionId: data.session_id ?? null,
    externalSpaceId: data.external_space_id ?? null,
    joinUrl: data.join_url ?? null,
    updatedAtMs: Date.parse(data.updated_at),
    requestFingerprint: data.request_fingerprint ?? null,
    claimGeneration: Number(data.claim_generation),
    meetAttempt: data.meet_attempt,
  }
}

function schemaMissing(error): boolean {
  const message = String(error?.message ?? "")
  return error?.code === "42703" || /column .* does not exist/i.test(message)
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseAnon = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" },
      },
    },
  )
  const supabase = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  return await handleCreateVideoSession(req, {
    now: () => Date.now(),
    authenticate: async (authHeader) => {
      if (!authHeader) {
        return {
          ok: false,
          response: jsonError("Missing Authorization header", 401),
        }
      }
      const { data: { user }, error } = await supabaseAnon.auth.getUser()
      if (error || !user) {
        return { ok: false, response: jsonError("Unauthorized", 401) }
      }
      return { ok: true, userId: user.id }
    },
    accountRestricted: async (userId) => {
      const { data, error } = await supabase
        .from("profiles")
        .select("account_status, suspended_until")
        .eq("id", userId)
        .maybeSingle()
      if (error || !data) {
        return jsonError("Account restricted", 403, "ACCOUNT_RESTRICTED")
      }
      if (accountStatusIsRestricted(data.account_status, data.suspended_until)) {
        return jsonError("Account restricted", 403, "ACCOUNT_RESTRICTED")
      }
      return null
    },
    loadProvider: async (userId) => {
      const { data } = await supabase
        .from("providers")
        .select("provider_type, verified")
        .eq("user_id", userId)
        .maybeSingle()
      return {
        verified: data?.verified === true,
        providerType: (data?.provider_type as string | undefined) ?? null,
      }
    },
    loadAcceptedClientIds: async (userId, participantIds) => {
      const { data, error } = await supabase
        .from("leads")
        .select("client_id")
        .eq("provider_id", userId)
        .eq("status", "accepted")
        .in("client_id", participantIds)
      if (error) {
        console.error("create-video-session leads check:", error.message)
        return { ok: false }
      }
      return {
        ok: true,
        ids: (data ?? []).map((row) => row.client_id),
      }
    },
    googleAccessToken: async (userId) => {
      const token = await getValidGoogleAccessToken(supabase, userId)
      if (!token.ok) return { ok: false, code: token.code, message: token.message }
      return { ok: true, accessToken: token.accessToken }
    },
    markGoogleReconnect: async (userId) => {
      await supabase
        .from("user_integrations_google")
        .update({
          reconnect_required: true,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId)
    },
    createMeetSpace: (accessToken) => createMeetSpace(accessToken),
    ledger: supabaseLedger(supabase),
    loadSession: async (sessionId) => {
      const { data } = await supabase
        .from("video_sessions")
        .select(
          "id, join_url, title, scheduled_start, created_at, duration_minutes, status, description, host_id, provider",
        )
        .eq("id", sessionId)
        .maybeSingle()
      return data
    },
    insertSession: async (input) => {
      const { data, error } = await supabase
        .from("video_sessions")
        .insert({
          host_id: input.hostId,
          provider: input.provider,
          title: input.title,
          description: input.description,
          scheduled_start: input.scheduledStart,
          duration_minutes: input.durationMinutes,
          max_participants: input.maxParticipants,
          status: "scheduled",
          join_url: input.joinUrl,
          provider_meeting_id: input.providerMeetingId,
        })
        .select(
          "id, join_url, title, scheduled_start, created_at, duration_minutes, status, description, host_id, provider",
        )
        .single()
      if (error || !data) {
        console.error("Insert video_sessions error:", error)
        return null
      }
      return data
    },
    upsertProviderMeta: async (input) => {
      await supabase.from("video_session_provider_meta").upsert({
        session_id: input.sessionId,
        provider: "google_meet",
        external_space_id: input.externalSpaceId,
        meeting_code: input.meetingCode,
      })
    },
    upsertParticipants: (sessionId, hostId, participantIds) =>
      upsertParticipants(supabase, sessionId, hostId, participantIds),
    deleteSession: async (sessionId) => {
      await supabase.from("video_sessions").delete().eq("id", sessionId)
    },
    notifySessionCreated: (sessionId) => notifySessionCreated(supabase, sessionId),
    log: (event, fields) => {
      console.log(JSON.stringify({ event, ...fields }))
    },
  })
})

function supabaseLedger(supabase) {
  const table = () => supabase.from("video_session_create_requests")

  async function changed(query): Promise<boolean> {
    const { data, error } = await query.select("claim_generation")
    if (error) {
      if (schemaMissing(error)) return false
      throw error
    }
    return Array.isArray(data) && data.length > 0
  }

  return {
    claim: async (userId, clientRequestId, fingerprint, nowMs) => {
      const inserted = await table().insert({
        user_id: userId,
        client_request_id: clientRequestId,
        status: "pending",
        claim_generation: 1,
        meet_attempt: "none",
        request_fingerprint: fingerprint,
        updated_at: new Date(nowMs).toISOString(),
      })
      if (!inserted.error) return { ok: true, inserted: true, generation: 1 }
      if (schemaMissing(inserted.error)) {
        return { ok: false, schemaUnavailable: true }
      }
      if (inserted.error.code !== "23505") throw inserted.error
      const existing = await table()
        .select(
          "session_id, status, external_space_id, join_url, updated_at, request_fingerprint, claim_generation, meet_attempt",
        )
        .eq("user_id", userId)
        .eq("client_request_id", clientRequestId)
        .maybeSingle()
      if (existing.error) {
        if (schemaMissing(existing.error)) {
          return { ok: false, schemaUnavailable: true }
        }
        throw existing.error
      }
      if (!existing.data?.status) {
        return { ok: false, schemaUnavailable: true }
      }
      return { ok: true, inserted: false, row: mapLedgerRow(existing.data) }
    },
    beginMeetAttempt: (userId, clientRequestId, generation, nowMs) =>
      changed(
        table()
          .update({
            meet_attempt: "ambiguous",
            updated_at: new Date(nowMs).toISOString(),
          })
          .eq("user_id", userId)
          .eq("client_request_id", clientRequestId)
          .eq("status", "pending")
          .eq("claim_generation", generation)
          .eq("meet_attempt", "none")
          .is("external_space_id", null),
      ),
    saveMeetSpace: (userId, clientRequestId, generation, spaceId, joinUrl, nowMs) =>
      changed(
        table()
          .update({
            external_space_id: spaceId,
            join_url: joinUrl,
            meet_attempt: "none",
            updated_at: new Date(nowMs).toISOString(),
          })
          .eq("user_id", userId)
          .eq("client_request_id", clientRequestId)
          .eq("status", "pending")
          .eq("claim_generation", generation)
          .eq("meet_attempt", "ambiguous")
          .is("external_space_id", null),
      ),
    markAmbiguous: (userId, clientRequestId, generation, nowMs, failureCode) =>
      changed(
        table()
          .update({
            status: "uncertain",
            failure_code: failureCode,
            updated_at: new Date(nowMs).toISOString(),
          })
          .eq("user_id", userId)
          .eq("client_request_id", clientRequestId)
          .eq("status", "pending")
          .eq("claim_generation", generation)
          .eq("meet_attempt", "ambiguous")
          .is("external_space_id", null),
      ),
    markConfirmedRejection: (
      userId,
      clientRequestId,
      generation,
      nowMs,
      failureCode,
    ) =>
      changed(
        table()
          .update({
            status: "failed",
            meet_attempt: "confirmed_absent",
            failure_code: failureCode,
            updated_at: new Date(nowMs).toISOString(),
          })
          .eq("user_id", userId)
          .eq("client_request_id", clientRequestId)
          .eq("status", "pending")
          .eq("claim_generation", generation)
          .eq("meet_attempt", "ambiguous")
          .is("external_space_id", null),
      ),
    markFailedBeforeCall: (
      userId,
      clientRequestId,
      generation,
      nowMs,
      failureCode,
    ) =>
      changed(
        table()
          .update({
            status: "failed",
            meet_attempt: "confirmed_absent",
            failure_code: failureCode,
            updated_at: new Date(nowMs).toISOString(),
          })
          .eq("user_id", userId)
          .eq("client_request_id", clientRequestId)
          .eq("status", "pending")
          .eq("claim_generation", generation)
          .eq("meet_attempt", "none")
          .is("external_space_id", null),
      ),
    retryFailed: async (userId, clientRequestId, seenGeneration, nowMs) => {
      const { data, error } = await table()
        .update({
          status: "pending",
          meet_attempt: "none",
          failure_code: null,
          claim_generation: seenGeneration + 1,
          updated_at: new Date(nowMs).toISOString(),
        })
        .eq("user_id", userId)
        .eq("client_request_id", clientRequestId)
        .eq("status", "failed")
        .eq("claim_generation", seenGeneration)
        .eq("meet_attempt", "confirmed_absent")
        .is("external_space_id", null)
        .select("claim_generation")
      if (error) throw error
      if (!Array.isArray(data) || data.length !== 1) return null
      return Number(data[0].claim_generation)
    },
    takeoverStale: async (userId, clientRequestId, seenGeneration, nowMs) => {
      const cutoff = new Date(nowMs - 120_000).toISOString()
      const { data, error } = await table()
        .update({
          claim_generation: seenGeneration + 1,
          updated_at: new Date(nowMs).toISOString(),
        })
        .eq("user_id", userId)
        .eq("client_request_id", clientRequestId)
        .eq("status", "pending")
        .eq("claim_generation", seenGeneration)
        .eq("meet_attempt", "none")
        .is("external_space_id", null)
        .lte("updated_at", cutoff)
        .select("claim_generation")
      if (error) throw error
      if (!Array.isArray(data) || data.length !== 1) return null
      return Number(data[0].claim_generation)
    },
    reserveSessionInsert: async (
      userId,
      clientRequestId,
      seenGeneration,
      nowMs,
      requireSpace,
    ) => {
      let query = table()
        .update({
          claim_generation: seenGeneration + 1,
          updated_at: new Date(nowMs).toISOString(),
        })
        .eq("user_id", userId)
        .eq("client_request_id", clientRequestId)
        .eq("status", "pending")
        .eq("claim_generation", seenGeneration)
        .neq("meet_attempt", "ambiguous")
      query = requireSpace
        ? query.not("external_space_id", "is", null)
        : query.is("external_space_id", null).eq("meet_attempt", "none")
      const { data, error } = await query.select("claim_generation")
      if (error) throw error
      if (!Array.isArray(data) || data.length !== 1) return null
      return Number(data[0].claim_generation)
    },
    markCompleted: (userId, clientRequestId, generation, sessionId, nowMs) =>
      changed(
        table()
          .update({
            status: "completed",
            session_id: sessionId,
            updated_at: new Date(nowMs).toISOString(),
          })
          .eq("user_id", userId)
          .eq("client_request_id", clientRequestId)
          .eq("status", "pending")
          .eq("claim_generation", generation),
      ),
  }
}

async function notifySessionCreated(supabase, sessionId: string): Promise<void> {
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
    push_via: "notifications_insert_webhook",
  }))
}

async function upsertParticipants(
  supabase,
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
