/**
 * Decision logic for create-video-session idempotency.
 *
 * index.ts calls these decisions. Production rows do not have the new
 * columns until 20261018110000_video_session_create_request_states.sql
 * is applied. Do not deploy the handler before that migration.
 *
 * Google Meet spaces.create accepts an empty Space and returns a new server
 * id. It has no client idempotency key and no lookup by our request id.
 * A timeout therefore cannot be retried as if Meet did nothing.
 */

export const CLIENT_REQUEST_ID_MIN = 8
export const CLIENT_REQUEST_ID_MAX = 128
/** Only a pending claim that has not called Meet may be taken over after this. */
export const CLAIM_LEASE_MS = 120_000

const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]+$/

export type LedgerStatus = "pending" | "completed" | "failed" | "uncertain"
export type MeetAttempt = "none" | "ambiguous" | "confirmed_absent"

export type LedgerRow = {
  status: LedgerStatus
  sessionId: string | null
  externalSpaceId: string | null
  joinUrl: string | null
  updatedAtMs: number
  /** Null only for rows that existed before fingerprints were stored. */
  requestFingerprint: string | null
  claimGeneration: number
  meetAttempt: MeetAttempt
}

export type RequestFingerprintInput = {
  hostId: string
  participantIds: string[]
  scheduledStart: string
  durationMinutes: number
  title: string
  provider: string
}

export type RequestIdResult =
  | { ok: true; key: string }
  | { ok: false; code: "VALIDATION"; message: string }

export type AuthResult =
  | { ok: true }
  | { ok: false; status: 401 | 403 | 400; code: string; message: string }

export type LedgerDecision =
  | { kind: "create_meet" }
  | { kind: "finish_saved_meet" }
  | { kind: "replay" }
  | { kind: "replay_deleted" }
  | { kind: "uncertain_prior" }
  | { kind: "payload_conflict" }
  | { kind: "in_progress" }
  | { kind: "ambiguous_hold" }
  | { kind: "retry_failed" }
  | { kind: "takeover_stale" }

export type MeetFailureClass = "before_call" | "confirmed_failure" | "ambiguous"

export type NotificationRetry = "send" | "skip" | "retry_incomplete_log"

export function normalizeClientRequestId(value: unknown): RequestIdResult {
  if (typeof value !== "string") {
    return {
      ok: false,
      code: "VALIDATION",
      message: "client_request_id is required",
    }
  }
  const key = value.trim()
  if (key.length < CLIENT_REQUEST_ID_MIN || key.length > CLIENT_REQUEST_ID_MAX) {
    return {
      ok: false,
      code: "VALIDATION",
      message: "client_request_id must be 8 to 128 characters",
    }
  }
  if (!REQUEST_ID_PATTERN.test(key)) {
    return {
      ok: false,
      code: "VALIDATION",
      message: "client_request_id has an invalid character",
    }
  }
  return { ok: true, key }
}

/**
 * Server-side identity of one create. The handler must pass the duration and
 * title it will actually store, not the raw client body.
 */
export async function requestFingerprint(
  input: RequestFingerprintInput,
): Promise<string> {
  const startMs = Date.parse(input.scheduledStart)
  const start = Number.isNaN(startMs)
    ? input.scheduledStart.trim()
    : new Date(startMs).toISOString()
  const participants = [...input.participantIds]
    .map((id) => id.trim())
    .filter((id) => id.length > 0)
    .sort()
    .join(",")
  const canonical = [
    input.hostId.trim(),
    participants,
    start,
    String(Math.trunc(input.durationMinutes)),
    input.title.trim(),
    input.provider.trim().toLowerCase(),
  ].join("\n")
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  )
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
}

/**
 * Historical rows are not proof of success when session_id is null.
 * ON DELETE SET NULL also clears session_id, and the old writer never stored
 * a status, so those rows stay uncertain instead of completed.
 */
export function backfillHistoricalStatus(
  sessionId: string | null,
): "completed" | "uncertain" {
  return sessionId ? "completed" : "uncertain"
}

/**
 * Checks that run before any ledger claim or Google call.
 * Duration clamping stays in the handler; this rejects an unusable schedule
 * and invitees who are not accepted leads.
 */
export function authorizeCreate(input: {
  userId: string | null
  providerVerified: boolean
  providerType: string | null
  scheduledStart: string | null
  nowMs: number
  participantIds: string[]
  acceptedClientIds: string[]
}): AuthResult {
  if (!input.userId) {
    return { ok: false, status: 401, code: "UNAUTHORIZED", message: "Unauthorized" }
  }
  const providerType = (input.providerType ?? "").toLowerCase()
  const isVerifiedProvider = input.providerVerified &&
    (providerType === "trainer" || providerType === "nutritionist")
  if (!isVerifiedProvider) {
    return {
      ok: false,
      status: 403,
      code: "PROVIDER_VERIFICATION_REQUIRED",
      message: "Provider verification is required before creating video sessions",
    }
  }
  if (!input.scheduledStart) {
    return {
      ok: false,
      status: 400,
      code: "VALIDATION",
      message: "scheduled_start is required",
    }
  }
  const startMs = Date.parse(input.scheduledStart)
  if (Number.isNaN(startMs)) {
    return { ok: false, status: 400, code: "VALIDATION", message: "Invalid scheduled_start" }
  }
  if (startMs < input.nowMs - 60_000) {
    return {
      ok: false,
      status: 400,
      code: "VALIDATION",
      message: "Scheduled time must be in the future",
    }
  }
  if (input.participantIds.length === 0) {
    return {
      ok: false,
      status: 400,
      code: "VALIDATION",
      message: "Select at least one member to invite",
    }
  }
  const accepted = new Set(input.acceptedClientIds)
  if (input.participantIds.some((id) => !accepted.has(id))) {
    return {
      ok: false,
      status: 403,
      code: "RELATIONSHIP_REQUIRED",
      message: "You can only invite members with an accepted connection",
    }
  }
  return { ok: true }
}

export function decideExistingLedger(
  row: LedgerRow,
  nowMs: number,
  incomingFingerprint: string | null,
  leaseMs: number = CLAIM_LEASE_MS,
): LedgerDecision {
  if (
    row.requestFingerprint &&
    incomingFingerprint &&
    row.requestFingerprint !== incomingFingerprint
  ) {
    return { kind: "payload_conflict" }
  }
  if (row.status === "uncertain") return { kind: "uncertain_prior" }
  if (row.status === "completed") {
    return row.sessionId ? { kind: "replay" } : { kind: "replay_deleted" }
  }
  if (row.status === "failed") return { kind: "retry_failed" }
  if (row.externalSpaceId) return { kind: "finish_saved_meet" }
  if (row.meetAttempt === "ambiguous") return { kind: "ambiguous_hold" }
  if (nowMs - row.updatedAtMs >= leaseMs) return { kind: "takeover_stale" }
  return { kind: "in_progress" }
}

/**
 * Classify a Meet create outcome. spaces.create accepts only a space body
 * and returns a server-generated name. There is no request id, idempotency
 * key, or lookup by client_request_id. spaces.get requires that name or a
 * meeting code, so an unknown space cannot be found or deleted from here.
 *
 * 400, 401, 403, and 404 reject the call and do not allocate a space.
 * 408, 409, 429, other 4xx, 5xx, timeouts, and unreadable 2xx are ambiguous:
 * a space may already exist, so the attempt must not be retried.
 */
export function classifyMeetFailure(input: {
  called: boolean
  timedOut?: boolean
  httpStatus?: number | null
  responseUnreadable?: boolean
}): MeetFailureClass {
  if (!input.called) return "before_call"
  if (input.timedOut || input.responseUnreadable) return "ambiguous"
  const status = input.httpStatus
  if (status == null) return "ambiguous"
  if (status === 400 || status === 401 || status === 403 || status === 404) {
    return "confirmed_failure"
  }
  return "ambiguous"
}

/** Notify only after completion. A later delivery retry is a separate step. */
export function notificationRetry(input: {
  ledgerStatus: LedgerStatus
  log: { notificationId: string | null } | null
}): NotificationRetry {
  if (input.ledgerStatus !== "completed") return "skip"
  if (!input.log) return "send"
  if (input.log.notificationId) return "skip"
  return "retry_incomplete_log"
}

export function shouldNotifyParticipants(transitionedToCompleted: boolean): boolean {
  return transitionedToCompleted
}

export type MemoryLedger = Map<string, LedgerRow>

function blankClaim(
  fingerprint: string,
  nowMs: number,
): LedgerRow {
  return {
    status: "pending",
    sessionId: null,
    externalSpaceId: null,
    joinUrl: null,
    updatedAtMs: nowMs,
    requestFingerprint: fingerprint,
    claimGeneration: 1,
    meetAttempt: "none",
  }
}

export function claimNew(
  ledger: MemoryLedger,
  key: string,
  fingerprint: string,
  nowMs: number,
):
  | { inserted: true; claimGeneration: number }
  | { inserted: false; decision: LedgerDecision } {
  const existing = ledger.get(key)
  if (!existing) {
    ledger.set(key, blankClaim(fingerprint, nowMs))
    return { inserted: true, claimGeneration: 1 }
  }
  return {
    inserted: false,
    decision: decideExistingLedger(existing, nowMs, fingerprint),
  }
}

export function claimFailedRetry(
  ledger: MemoryLedger,
  key: string,
  seenGeneration: number,
  nowMs: number,
): number | null {
  const row = ledger.get(key)
  if (!row || row.status !== "failed") return null
  if (row.claimGeneration !== seenGeneration) return null
  if (row.externalSpaceId) return null
  if (row.meetAttempt === "ambiguous") return null
  row.status = "pending"
  row.meetAttempt = "none"
  row.claimGeneration += 1
  row.updatedAtMs = nowMs
  return row.claimGeneration
}

/** Compare-and-swap. A stale generation cannot become the Meet caller. */
export function takeoverStaleClaim(
  ledger: MemoryLedger,
  key: string,
  seenGeneration: number,
  nowMs: number,
): number | null {
  const row = ledger.get(key)
  if (!row) return null
  if (decideExistingLedger(row, nowMs, row.requestFingerprint).kind !== "takeover_stale") {
    return null
  }
  if (row.claimGeneration !== seenGeneration) return null
  row.claimGeneration += 1
  row.updatedAtMs = nowMs
  return row.claimGeneration
}

/**
 * Mark the attempt ambiguous before the HTTP call. If this process dies,
 * the row stays ambiguous and must not be treated as "Meet was not called".
 */
export function beginMeetAttempt(
  ledger: MemoryLedger,
  key: string,
  claimGeneration: number,
  nowMs: number,
): boolean {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return false
  if (row.claimGeneration !== claimGeneration) return false
  if (row.externalSpaceId || row.meetAttempt === "ambiguous") return false
  row.meetAttempt = "ambiguous"
  row.updatedAtMs = nowMs
  return true
}

export function saveMeetSpace(
  ledger: MemoryLedger,
  key: string,
  claimGeneration: number,
  spaceId: string,
  joinUrl: string,
  nowMs: number,
): boolean {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return false
  if (row.claimGeneration !== claimGeneration) return false
  if (row.externalSpaceId && row.externalSpaceId !== spaceId) return false
  row.externalSpaceId = spaceId
  row.joinUrl = joinUrl
  row.meetAttempt = "none"
  row.updatedAtMs = nowMs
  return true
}

export function markConfirmedMeetRejection(
  ledger: MemoryLedger,
  key: string,
  claimGeneration: number,
  nowMs: number,
): boolean {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return false
  if (row.claimGeneration !== claimGeneration) return false
  if (row.externalSpaceId || row.meetAttempt !== "ambiguous") return false
  row.meetAttempt = "confirmed_absent"
  row.status = "failed"
  row.updatedAtMs = nowMs
  return true
}

/** Returns true only for the fenced pending -> completed transition. */
export function markCompleted(
  ledger: MemoryLedger,
  key: string,
  claimGeneration: number,
  sessionId: string,
  nowMs: number,
): boolean {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return false
  if (row.claimGeneration !== claimGeneration) return false
  row.status = "completed"
  row.sessionId = sessionId
  row.updatedAtMs = nowMs
  return true
}

/**
 * Persist an ambiguous Meet outcome. The request id stays bound to this row
 * and must not be used to create another space.
 */
export function markAmbiguousOutcome(
  ledger: MemoryLedger,
  key: string,
  claimGeneration: number,
  nowMs: number,
): boolean {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return false
  if (row.claimGeneration !== claimGeneration) return false
  if (row.externalSpaceId || row.meetAttempt !== "ambiguous") return false
  row.status = "uncertain"
  row.updatedAtMs = nowMs
  return true
}

/**
 * One owner may insert the video_sessions row. Zero means another worker
 * already advanced this generation.
 */
export function reserveSessionInsert(
  ledger: MemoryLedger,
  key: string,
  seenGeneration: number,
  nowMs: number,
  requireSpace: boolean,
): number | null {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return null
  if (row.claimGeneration !== seenGeneration) return null
  if (row.meetAttempt === "ambiguous") return null
  if (requireSpace) {
    if (!row.externalSpaceId) return null
  } else if (row.externalSpaceId || row.meetAttempt !== "none") {
    return null
  }
  row.claimGeneration += 1
  row.updatedAtMs = nowMs
  return row.claimGeneration
}

export function markFailedBeforeCall(
  ledger: MemoryLedger,
  key: string,
  claimGeneration: number,
  nowMs: number,
): boolean {
  const row = ledger.get(key)
  if (!row || row.status !== "pending") return false
  if (row.claimGeneration !== claimGeneration) return false
  if (row.externalSpaceId || row.meetAttempt !== "none") return false
  row.status = "failed"
  row.meetAttempt = "confirmed_absent"
  row.updatedAtMs = nowMs
  return true
}
