/**
 * HTTP flow for create-video-session.
 *
 * The ledger claim is taken after authorization and before any Google Meet
 * call. Fenced updates must observe a changed row. Ambiguous Meet results
 * stay on the same client_request_id.
 */

import {
  authorizeCreate,
  classifyMeetFailure,
  decideExistingLedger,
  normalizeClientRequestId,
  requestFingerprint,
  shouldNotifyParticipants,
  type LedgerRow,
} from "./idempotency.ts"

export const CREATION_UNCERTAIN_MESSAGE =
  "Video session creation is uncertain. Retry this same request; do not start a new one."

export type SessionRecord = {
  id: string
  join_url: string
  title: string
  scheduled_start: string
  created_at: string
  duration_minutes: number
  status: string
  description: string | null
  host_id: string
  provider: string
}

export type ClaimResult =
  | { ok: true; inserted: true; generation: number }
  | { ok: true; inserted: false; row: LedgerRow }
  | { ok: false; schemaUnavailable: boolean }

export type MeetCreateResult =
  | {
    ok: true
    space: { name: string; meetingUri: string; meetingCode?: string }
  }
  | {
    ok: false
    code: string
    message: string
    httpStatus?: number
    timedOut?: boolean
    responseUnreadable?: boolean
  }

export interface VideoSessionLedger {
  claim(
    userId: string,
    clientRequestId: string,
    fingerprint: string,
    nowMs: number,
  ): Promise<ClaimResult>
  beginMeetAttempt(
    userId: string,
    clientRequestId: string,
    generation: number,
    nowMs: number,
  ): Promise<boolean>
  saveMeetSpace(
    userId: string,
    clientRequestId: string,
    generation: number,
    spaceId: string,
    joinUrl: string,
    nowMs: number,
  ): Promise<boolean>
  markAmbiguous(
    userId: string,
    clientRequestId: string,
    generation: number,
    nowMs: number,
    failureCode: string,
  ): Promise<boolean>
  markConfirmedRejection(
    userId: string,
    clientRequestId: string,
    generation: number,
    nowMs: number,
    failureCode: string,
  ): Promise<boolean>
  markFailedBeforeCall(
    userId: string,
    clientRequestId: string,
    generation: number,
    nowMs: number,
    failureCode: string,
  ): Promise<boolean>
  retryFailed(
    userId: string,
    clientRequestId: string,
    seenGeneration: number,
    nowMs: number,
  ): Promise<number | null>
  takeoverStale(
    userId: string,
    clientRequestId: string,
    seenGeneration: number,
    nowMs: number,
  ): Promise<number | null>
  reserveSessionInsert(
    userId: string,
    clientRequestId: string,
    seenGeneration: number,
    nowMs: number,
    requireSpace: boolean,
  ): Promise<number | null>
  markCompleted(
    userId: string,
    clientRequestId: string,
    generation: number,
    sessionId: string,
    nowMs: number,
  ): Promise<boolean>
}

export type CreateVideoSessionDeps = {
  now(): number
  authenticate(
    authHeader: string | null,
  ): Promise<{ ok: true; userId: string } | { ok: false; response: Response }>
  accountRestricted(userId: string): Promise<Response | null>
  loadProvider(userId: string): Promise<{
    verified: boolean
    providerType: string | null
  }>
  loadAcceptedClientIds(
    userId: string,
    participantIds: string[],
  ): Promise<{ ok: true; ids: string[] } | { ok: false }>
  googleAccessToken(userId: string): Promise<
    | { ok: true; accessToken: string }
    | { ok: false; code: string; message: string }
  >
  markGoogleReconnect(userId: string): Promise<void>
  createMeetSpace(accessToken: string): Promise<MeetCreateResult>
  ledger: VideoSessionLedger
  loadSession(sessionId: string): Promise<SessionRecord | null>
  insertSession(input: {
    hostId: string
    provider: string
    title: string
    description: string | null
    scheduledStart: string
    durationMinutes: number
    maxParticipants: number
    joinUrl: string
    providerMeetingId: string | null
  }): Promise<SessionRecord | null>
  upsertProviderMeta(input: {
    sessionId: string
    externalSpaceId: string
    meetingCode: string | null
  }): Promise<void>
  upsertParticipants(
    sessionId: string,
    hostId: string,
    participantIds: string[],
  ): Promise<string | null>
  deleteSession(sessionId: string): Promise<void>
  notifySessionCreated(sessionId: string): Promise<void>
  log(event: string, fields: Record<string, unknown>): void
}

type PreparedCreate = {
  userId: string
  title: string
  description: string | null
  scheduledStart: string
  duration: number
  maxSlots: number
  participantIds: string[]
  clientRequestId: string
  fingerprint: string
  useGoogleMeet: boolean
  externalJoinUrl: string | null
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Content-Type": "application/json",
    },
  })
}

function jsonError(message: string, status: number, code?: string): Response {
  return jsonResponse({ error: message, code: code ?? undefined }, status)
}

function creationUncertain(): Response {
  return jsonError(CREATION_UNCERTAIN_MESSAGE, 409, "CREATION_UNCERTAIN")
}

function lostOwnership(): Response {
  return jsonError(
    "This request is owned by another attempt. Retry the same request.",
    409,
    "LOST_OWNERSHIP",
  )
}

export async function handleCreateVideoSession(
  req: Request,
  deps: CreateVideoSessionDeps,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    })
  }

  try {
    const auth = await deps.authenticate(req.headers.get("Authorization"))
    if (!auth.ok) return auth.response

    const restricted = await deps.accountRestricted(auth.userId)
    if (restricted) return restricted

    const providerRow = await deps.loadProvider(auth.userId)
    const providerGate = authorizeCreate({
      userId: auth.userId,
      providerVerified: providerRow.verified,
      providerType: providerRow.providerType,
      scheduledStart: "2099-01-01T00:00:00.000Z",
      nowMs: deps.now(),
      participantIds: ["pending"],
      acceptedClientIds: ["pending"],
    })
    if (!providerGate.ok) {
      return jsonError(providerGate.message, providerGate.status, providerGate.code)
    }

    const body = await req.json() as Record<string, unknown>
    const prepared = await prepareCreate(auth.userId, providerRow, body, deps)
    if (prepared instanceof Response) return prepared

    const claim = await deps.ledger.claim(
      prepared.userId,
      prepared.clientRequestId,
      prepared.fingerprint,
      deps.now(),
    )
    if (!claim.ok) {
      return jsonError(
        "Video session creation is not ready",
        503,
        "LEDGER_SCHEMA_UNAVAILABLE",
      )
    }

    let generation = claim.inserted ? claim.generation : 0
    let savedSpaceId: string | null = null
    let savedJoinUrl: string | null = prepared.externalJoinUrl
    let meetingCode: string | null = null

    if (!claim.inserted) {
      const resumed = await resumeExisting(prepared, claim.row, deps)
      if (resumed instanceof Response) return resumed
      generation = resumed.generation
      savedSpaceId = resumed.spaceId
      savedJoinUrl = resumed.joinUrl
      meetingCode = resumed.meetingCode
    }

    if (prepared.useGoogleMeet && !savedSpaceId) {
      const opened = await openMeetSpace(prepared, generation, deps)
      if (opened instanceof Response) return opened
      generation = opened.generation
      savedSpaceId = opened.spaceId
      savedJoinUrl = opened.joinUrl
      meetingCode = opened.meetingCode
    }

    if (!savedJoinUrl) {
      return creationUncertain()
    }

    const reserved = await deps.ledger.reserveSessionInsert(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      deps.now(),
      prepared.useGoogleMeet,
    )
    if (reserved == null) return lostOwnership()
    generation = reserved

    const session = await deps.insertSession({
      hostId: prepared.userId,
      provider: prepared.useGoogleMeet ? "google_meet" : "external",
      title: prepared.title,
      description: prepared.description,
      scheduledStart: prepared.scheduledStart,
      durationMinutes: prepared.duration,
      maxParticipants: prepared.maxSlots,
      joinUrl: savedJoinUrl,
      providerMeetingId: meetingCode || savedSpaceId,
    })
    if (!session) {
      deps.log("session_insert_failed", { client_request_id: prepared.clientRequestId })
      return jsonError("Failed to save session", 500, "DB_INSERT_FAILED")
    }

    if (prepared.useGoogleMeet && savedSpaceId) {
      await deps.upsertProviderMeta({
        sessionId: session.id,
        externalSpaceId: savedSpaceId,
        meetingCode,
      })
    }

    const partErr = await deps.upsertParticipants(
      session.id,
      prepared.userId,
      prepared.participantIds,
    )
    if (partErr) {
      deps.log("participant_insert_failed", { session_id: session.id })
      await deps.deleteSession(session.id)
      return jsonError(
        "Failed to add session participants",
        500,
        "PARTICIPANTS_FAILED",
      )
    }
    deps.log("participant_inserted", {
      session_id: session.id,
      participant_count: prepared.participantIds.length,
    })

    const completed = await deps.ledger.markCompleted(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      session.id,
      deps.now(),
    )
    if (!completed) {
      await deps.deleteSession(session.id)
      return lostOwnership()
    }

    if (shouldNotifyParticipants(true)) {
      try {
        await deps.notifySessionCreated(session.id)
      } catch (notifyErr) {
        deps.log("notification_event_failed", {
          session_id: session.id,
          message: notifyErr instanceof Error ? notifyErr.message : "notify failed",
        })
      }
    }

    deps.log("session_created", {
      session_id: session.id,
      provider: session.provider,
    })
    return jsonResponse(session)
  } catch (err) {
    console.error("create-video-session error:", err)
    return jsonError("Something went wrong. Please try again.", 500, "INTERNAL")
  }
}

async function prepareCreate(
  userId: string,
  providerRow: { verified: boolean; providerType: string | null },
  body: Record<string, unknown>,
  deps: CreateVideoSessionDeps,
): Promise<PreparedCreate | Response> {
  const titleRaw = typeof body.title === "string" ? body.title : "Video Session"
  const descriptionRaw = body.description
  const scheduledStart = typeof body.scheduled_start === "string"
    ? body.scheduled_start
    : null
  const participantIds = Array.isArray(body.participant_ids)
    ? [
      ...new Set(
        body.participant_ids.filter((id): id is string =>
          typeof id === "string" && id.length > 0
        ),
      ),
    ]
    : []

  const schedule = authorizeCreate({
    userId,
    providerVerified: true,
    providerType: "trainer",
    scheduledStart,
    nowMs: deps.now(),
    participantIds: ["pending"],
    acceptedClientIds: ["pending"],
  })
  if (!schedule.ok) {
    return jsonError(schedule.message, schedule.status, schedule.code)
  }

  const title = titleRaw.trim()
  if (!title || title.length > 80) {
    return jsonError("Title is required (max 80 characters)", 400, "VALIDATION")
  }

  const duration = Math.min(
    180,
    Math.max(15, Number(body.duration_minutes) || 30),
  )
  if (participantIds.length === 0) {
    return jsonError(
      "Select at least one member to invite",
      400,
      "VALIDATION",
    )
  }
  const maxSlots = Math.min(21, Math.max(2, Number(body.max_participants) || 21))
  if (participantIds.length > maxSlots - 1) {
    return jsonError(
      `Max ${maxSlots - 1} invitees (host occupies 1 slot)`,
      400,
      "VALIDATION",
    )
  }

  const leads = await deps.loadAcceptedClientIds(userId, participantIds)
  if (!leads.ok) {
    return jsonError(
      "Could not verify member relationships",
      500,
      "RELATIONSHIP_CHECK_FAILED",
    )
  }
  const relationship = authorizeCreate({
    userId,
    providerVerified: providerRow.verified,
    providerType: providerRow.providerType,
    scheduledStart,
    nowMs: deps.now(),
    participantIds,
    acceptedClientIds: leads.ids,
  })
  if (!relationship.ok) {
    return jsonError(relationship.message, relationship.status, relationship.code)
  }

  const requestId = normalizeClientRequestId(body.client_request_id)
  if (!requestId.ok) {
    return jsonError(requestId.message, 400, requestId.code)
  }

  const providerRaw = typeof body.provider === "string" ? body.provider : "google_meet"
  const useGoogleMeet = !providerRaw || providerRaw === "google_meet" ||
    providerRaw === "meet"
  let externalJoinUrl: string | null = null
  if (!useGoogleMeet && (providerRaw === "external" || providerRaw === "manual")) {
    const trimmed = typeof body.join_url === "string" ? body.join_url.trim() : ""
    if (!trimmed || !isHttpsUrl(trimmed)) {
      return jsonError("A valid https meeting link is required", 400, "VALIDATION")
    }
    externalJoinUrl = trimmed
  } else if (!useGoogleMeet) {
    return jsonError("Unsupported meeting provider", 400, "UNSUPPORTED_PROVIDER")
  }

  const description = typeof descriptionRaw === "string" &&
      descriptionRaw.trim().length > 0
    ? descriptionRaw.trim().slice(0, 500)
    : null
  const fingerprint = await requestFingerprint({
    hostId: userId,
    participantIds,
    scheduledStart: scheduledStart ?? "",
    durationMinutes: duration,
    title,
    provider: useGoogleMeet ? "google_meet" : "external",
  })

  return {
    userId,
    title,
    description,
    scheduledStart: scheduledStart ?? "",
    duration,
    maxSlots,
    participantIds,
    clientRequestId: requestId.key,
    fingerprint,
    useGoogleMeet,
    externalJoinUrl,
  }
}

type Resume =
  | Response
  | {
    generation: number
    spaceId: string | null
    joinUrl: string | null
    meetingCode: string | null
  }

async function resumeExisting(
  prepared: PreparedCreate,
  row: LedgerRow,
  deps: CreateVideoSessionDeps,
): Promise<Resume> {
  const decision = decideExistingLedger(row, deps.now(), prepared.fingerprint)
  if (decision.kind === "payload_conflict") {
    return jsonError(
      "client_request_id was already used for a different session",
      409,
      "PAYLOAD_CONFLICT",
    )
  }
  if (decision.kind === "uncertain_prior" || decision.kind === "ambiguous_hold") {
    return creationUncertain()
  }
  if (decision.kind === "replay_deleted") {
    return jsonError(
      "The session for this request is no longer available",
      409,
      "REPLAY_DELETED",
    )
  }
  if (decision.kind === "in_progress") {
    return jsonError(
      "This request is already being created",
      409,
      "REQUEST_IN_PROGRESS",
    )
  }
  if (decision.kind === "replay") {
    const existing = row.sessionId ? await deps.loadSession(row.sessionId) : null
    if (!existing) {
      return jsonError(
        "The session for this request is no longer available",
        409,
        "REPLAY_DELETED",
      )
    }
    return jsonResponse(existing)
  }

  let generation = row.claimGeneration
  if (decision.kind === "retry_failed") {
    const next = await deps.ledger.retryFailed(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      deps.now(),
    )
    if (next == null) return lostOwnership()
    generation = next
  } else if (decision.kind === "takeover_stale") {
    const next = await deps.ledger.takeoverStale(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      deps.now(),
    )
    if (next == null) return lostOwnership()
    generation = next
  } else if (decision.kind === "finish_saved_meet") {
    if (!row.joinUrl) return creationUncertain()
    return {
      generation,
      spaceId: row.externalSpaceId,
      joinUrl: row.joinUrl,
      meetingCode: null,
    }
  }

  return {
    generation,
    spaceId: null,
    joinUrl: prepared.externalJoinUrl,
    meetingCode: null,
  }
}

type OpenedMeet =
  | Response
  | {
    generation: number
    spaceId: string
    joinUrl: string
    meetingCode: string | null
  }

async function openMeetSpace(
  prepared: PreparedCreate,
  generation: number,
  deps: CreateVideoSessionDeps,
): Promise<OpenedMeet> {
  const token = await deps.googleAccessToken(prepared.userId)
  if (!token.ok) {
    const released = await deps.ledger.markFailedBeforeCall(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      deps.now(),
      token.code,
    )
    if (!released) return lostOwnership()
    return jsonError(token.message, 400, token.code)
  }

  const started = await deps.ledger.beginMeetAttempt(
    prepared.userId,
    prepared.clientRequestId,
    generation,
    deps.now(),
  )
  if (!started) return lostOwnership()

  let meet: MeetCreateResult
  try {
    meet = await deps.createMeetSpace(token.accessToken)
  } catch {
    await deps.ledger.markAmbiguous(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      deps.now(),
      "MEET_AMBIGUOUS",
    )
    return creationUncertain()
  }

  if (!meet.ok) {
    const klass = classifyMeetFailure({
      called: true,
      timedOut: meet.timedOut,
      httpStatus: meet.httpStatus,
      responseUnreadable: meet.responseUnreadable,
    })
    if (klass === "confirmed_failure") {
      const marked = await deps.ledger.markConfirmedRejection(
        prepared.userId,
        prepared.clientRequestId,
        generation,
        deps.now(),
        meet.code,
      )
      if (!marked) return creationUncertain()
      if (meet.code === "GOOGLE_UNAUTHORIZED" || meet.code === "GOOGLE_FORBIDDEN") {
        await deps.markGoogleReconnect(prepared.userId)
        return jsonError(
          "Reconnect Google Meet to continue.",
          400,
          "GOOGLE_RECONNECT_REQUIRED",
        )
      }
      return jsonError(meet.message, 400, meet.code)
    }
    await deps.ledger.markAmbiguous(
      prepared.userId,
      prepared.clientRequestId,
      generation,
      deps.now(),
      meet.code || "MEET_AMBIGUOUS",
    )
    return creationUncertain()
  }

  const saved = await deps.ledger.saveMeetSpace(
    prepared.userId,
    prepared.clientRequestId,
    generation,
    meet.space.name,
    meet.space.meetingUri,
    deps.now(),
  )
  if (!saved) return creationUncertain()
  return {
    generation,
    spaceId: meet.space.name,
    joinUrl: meet.space.meetingUri,
    meetingCode: meet.space.meetingCode ?? null,
  }
}

function isHttpsUrl(value: string): boolean {
  try {
    const url = new URL(value)
    return url.protocol === "https:"
  } catch {
    return false
  }
}

