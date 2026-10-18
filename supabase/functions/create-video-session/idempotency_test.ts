/**
 * Idempotency decisions for create-video-session.
 * Run: deno test supabase/functions/create-video-session/idempotency_test.ts
 *
 * No Google Meet or database calls.
 */

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts"
import {
  CLAIM_LEASE_MS,
  authorizeCreate,
  backfillHistoricalStatus,
  beginMeetAttempt,
  claimFailedRetry,
  claimNew,
  classifyMeetFailure,
  decideExistingLedger,
  markCompleted,
  markConfirmedMeetRejection,
  markFailedBeforeCall,
  normalizeClientRequestId,
  notificationRetry,
  requestFingerprint,
  saveMeetSpace,
  shouldNotifyParticipants,
  takeoverStaleClaim,
  type LedgerRow,
  type MemoryLedger,
} from "./idempotency.ts"

const NOW = Date.parse("2026-10-18T10:00:00.000Z")
const FUTURE = "2026-10-18T11:00:00.000Z"
const CLIENT = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
const FP = "fp-session-a"

function authBase(overrides: Record<string, unknown> = {}) {
  return {
    userId: "host-1",
    providerVerified: true,
    providerType: "trainer",
    scheduledStart: FUTURE,
    nowMs: NOW,
    participantIds: [CLIENT],
    acceptedClientIds: [CLIENT],
    ...overrides,
  }
}

function authCode(overrides: Record<string, unknown>): string {
  const result = authorizeCreate(authBase(overrides))
  if (result.ok) throw new Error("expected authorization to fail")
  return result.code
}

function row(partial: Partial<LedgerRow> & Pick<LedgerRow, "status">): LedgerRow {
  return {
    sessionId: null,
    externalSpaceId: null,
    joinUrl: null,
    updatedAtMs: NOW,
    requestFingerprint: FP,
    claimGeneration: 1,
    meetAttempt: "none",
    ...partial,
  }
}

Deno.test("client_request_id accepts current Flutter ids and rejects bad ones", () => {
  const flutterId = "vs-1760780000000000-12345"
  const negativeHash = "vs-1760780000000000--42"
  const fallback = `1760780000000-${CLIENT}`
  assertEquals(normalizeClientRequestId(flutterId).ok, true)
  assertEquals(normalizeClientRequestId(negativeHash).ok, true)
  assertEquals(normalizeClientRequestId(fallback).ok, true)
  assertEquals(normalizeClientRequestId(null).ok, false)
  assertEquals(normalizeClientRequestId("   ").ok, false)
  assertEquals(normalizeClientRequestId("short").ok, false)
  assertEquals(normalizeClientRequestId("bad id spaces").ok, false)
  assertEquals(normalizeClientRequestId("a".repeat(129)).ok, false)
})

Deno.test("authorization stays ahead of any claim", () => {
  assertEquals(authorizeCreate(authBase({ userId: null })).ok, false)
  assertEquals(authCode({ providerVerified: false }), "PROVIDER_VERIFICATION_REQUIRED")
  assertEquals(authCode({ providerType: "client" }), "PROVIDER_VERIFICATION_REQUIRED")
  assertEquals(authCode({ acceptedClientIds: [] }), "RELATIONSHIP_REQUIRED")
  assertEquals(
    authCode({ scheduledStart: "2026-10-18T09:00:00.000Z" }),
    "VALIDATION",
  )
  assertEquals(authorizeCreate(authBase()).ok, true)
})

Deno.test("fingerprint binds host, participants, start, duration, title, provider", async () => {
  const base = {
    hostId: "host-1",
    participantIds: [CLIENT, "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"],
    scheduledStart: FUTURE,
    durationMinutes: 30,
    title: "Check-in",
    provider: "google_meet",
  }
  const same = await requestFingerprint({
    ...base,
    participantIds: ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", CLIENT],
    scheduledStart: "2026-10-18T11:00:00.000Z",
  })
  const otherStart = await requestFingerprint({
    ...base,
    scheduledStart: "2026-10-18T12:00:00.000Z",
  })
  assertEquals(await requestFingerprint(base), same)
  assertEquals(same === otherStart, false)
})

Deno.test("reused key with a different payload conflicts and does not create", () => {
  const ledger: MemoryLedger = new Map()
  const first = claimNew(ledger, "req-1", FP, NOW)
  assertEquals(first.inserted, true)
  const second = claimNew(ledger, "req-1", "fp-other", NOW + 10)
  assertEquals(second.inserted, false)
  if (!second.inserted) assertEquals(second.decision.kind, "payload_conflict")
  assertEquals(ledger.get("req-1")?.status, "pending")
  assertEquals(ledger.get("req-1")?.claimGeneration, 1)
})

Deno.test("concurrent claims create one Meet ownership", () => {
  const ledger: MemoryLedger = new Map()
  const first = claimNew(ledger, "req-1", FP, NOW)
  const second = claimNew(ledger, "req-1", FP, NOW + 10)
  assertEquals(first.inserted, true)
  assertEquals(second.inserted, false)
  if (!second.inserted) assertEquals(second.decision.kind, "in_progress")
  assertEquals(ledger.size, 1)
})

Deno.test("stale worker cannot overwrite a newer claim generation", () => {
  const ledger: MemoryLedger = new Map()
  claimNew(ledger, "req-1", FP, NOW)
  const next = takeoverStaleClaim(ledger, "req-1", 1, NOW + CLAIM_LEASE_MS)
  assertEquals(next, 2)
  assertEquals(takeoverStaleClaim(ledger, "req-1", 1, NOW + CLAIM_LEASE_MS), null)
  assertEquals(
    beginMeetAttempt(ledger, "req-1", 1, NOW + CLAIM_LEASE_MS + 1),
    false,
  )
  assertEquals(
    saveMeetSpace(
      ledger,
      "req-1",
      1,
      "spaces/stale",
      "https://meet.google.com/stale",
      NOW + CLAIM_LEASE_MS + 2,
    ),
    false,
  )
  assertEquals(ledger.get("req-1")?.externalSpaceId, null)
  assertEquals(ledger.get("req-1")?.claimGeneration, 2)
  assertEquals(beginMeetAttempt(ledger, "req-1", 2, NOW + CLAIM_LEASE_MS + 3), true)
})

Deno.test("completed replay does not notify again", () => {
  const ledger: MemoryLedger = new Map()
  claimNew(ledger, "req-1", FP, NOW)
  beginMeetAttempt(ledger, "req-1", 1, NOW + 1)
  saveMeetSpace(ledger, "req-1", 1, "spaces/abc", "https://meet.google.com/abc", NOW + 2)
  const firstComplete = markCompleted(ledger, "req-1", 1, "session-1", NOW + 3)
  const replay = claimNew(ledger, "req-1", FP, NOW + 5_000)
  const secondComplete = markCompleted(ledger, "req-1", 1, "session-2", NOW + 6_000)
  assertEquals(firstComplete, true)
  assertEquals(shouldNotifyParticipants(firstComplete), true)
  assertEquals(replay.inserted, false)
  if (!replay.inserted) assertEquals(replay.decision.kind, "replay")
  assertEquals(secondComplete, false)
  assertEquals(shouldNotifyParticipants(secondComplete), false)
  assertEquals(ledger.get("req-1")?.sessionId, "session-1")
})

Deno.test("historical null session_id stays uncertain and a later delete does not recreate", () => {
  assertEquals(backfillHistoricalStatus(null), "uncertain")
  assertEquals(backfillHistoricalStatus("session-1"), "completed")
  const historical = row({
    status: "uncertain",
    sessionId: null,
    requestFingerprint: null,
    claimGeneration: 0,
  })
  assertEquals(decideExistingLedger(historical, NOW, FP).kind, "uncertain_prior")
  const deleted = row({
    status: "completed",
    sessionId: null,
    joinUrl: "https://meet.google.com/abc",
  })
  assertEquals(decideExistingLedger(deleted, NOW, FP).kind, "replay_deleted")
})

Deno.test("crash after Meet is saved resumes without a second space", () => {
  const ledger: MemoryLedger = new Map()
  claimNew(ledger, "req-1", FP, NOW)
  beginMeetAttempt(ledger, "req-1", 1, NOW + 1)
  assertEquals(
    saveMeetSpace(ledger, "req-1", 1, "spaces/abc", "https://meet.google.com/abc", NOW + 2),
    true,
  )
  const retry = claimNew(ledger, "req-1", FP, NOW + 5_000)
  assertEquals(retry.inserted, false)
  if (!retry.inserted) assertEquals(retry.decision.kind, "finish_saved_meet")
  assertEquals(
    saveMeetSpace(ledger, "req-1", 1, "spaces/other", "https://meet.google.com/other", NOW + 6),
    false,
  )
  assertEquals(ledger.get("req-1")?.externalSpaceId, "spaces/abc")
  const done = markCompleted(ledger, "req-1", 1, "session-1", NOW + 7)
  assertEquals(shouldNotifyParticipants(done), true)
})

Deno.test("confirmed Meet rejection can be retried once; ambiguous calls cannot", () => {
  assertEquals(classifyMeetFailure({ called: false }), "before_call")
  assertEquals(
    classifyMeetFailure({ called: true, httpStatus: 403 }),
    "confirmed_failure",
  )
  assertEquals(
    classifyMeetFailure({ called: true, timedOut: true }),
    "ambiguous",
  )
  assertEquals(
    classifyMeetFailure({ called: true, httpStatus: 200, responseUnreadable: true }),
    "ambiguous",
  )
  assertEquals(classifyMeetFailure({ called: true, httpStatus: 503 }), "ambiguous")
  assertEquals(classifyMeetFailure({ called: true, httpStatus: 429 }), "ambiguous")
  assertEquals(classifyMeetFailure({ called: true, httpStatus: 401 }), "confirmed_failure")

  const confirmed: MemoryLedger = new Map()
  claimNew(confirmed, "req-ok", FP, NOW)
  assertEquals(markFailedBeforeCall(confirmed, "req-ok", 1, NOW + 1), true)
  assertEquals(claimFailedRetry(confirmed, "req-ok", 1, NOW + 2), 2)
  assertEquals(claimFailedRetry(confirmed, "req-ok", 1, NOW + 3), null)

  const ambiguous: MemoryLedger = new Map()
  claimNew(ambiguous, "req-amb", FP, NOW)
  beginMeetAttempt(ambiguous, "req-amb", 1, NOW + 1)
  const held = decideExistingLedger(ambiguous.get("req-amb")!, NOW + CLAIM_LEASE_MS + 1, FP)
  assertEquals(held.kind, "ambiguous_hold")
  assertEquals(takeoverStaleClaim(ambiguous, "req-amb", 1, NOW + CLAIM_LEASE_MS + 1), null)
  assertEquals(ambiguous.get("req-amb")?.status, "pending")

  const rejected: MemoryLedger = new Map()
  claimNew(rejected, "req-4xx", FP, NOW)
  beginMeetAttempt(rejected, "req-4xx", 1, NOW + 1)
  assertEquals(markConfirmedMeetRejection(rejected, "req-4xx", 1, NOW + 2), true)
  assertEquals(rejected.get("req-4xx")?.status, "failed")
  assertEquals(rejected.get("req-4xx")?.meetAttempt, "confirmed_absent")
})

Deno.test("stale pending claim without a Meet call can be taken over", () => {
  const waiting = row({ status: "pending", meetAttempt: "none" })
  assertEquals(
    decideExistingLedger(waiting, NOW + CLAIM_LEASE_MS - 1, FP).kind,
    "in_progress",
  )
  assertEquals(
    decideExistingLedger(waiting, NOW + CLAIM_LEASE_MS, FP).kind,
    "takeover_stale",
  )
})

Deno.test("saved Meet space is resumed even after the lease", () => {
  const saved = row({
    status: "pending",
    externalSpaceId: "spaces/abc",
    joinUrl: "https://meet.google.com/abc",
    meetAttempt: "none",
  })
  assertEquals(
    decideExistingLedger(saved, NOW + CLAIM_LEASE_MS + 10_000, FP).kind,
    "finish_saved_meet",
  )
})

Deno.test("notifications wait for completion and an incomplete log can be retried", () => {
  assertEquals(notificationRetry({ ledgerStatus: "pending", log: null }), "skip")
  assertEquals(notificationRetry({ ledgerStatus: "uncertain", log: null }), "skip")
  assertEquals(notificationRetry({ ledgerStatus: "failed", log: null }), "skip")
  assertEquals(notificationRetry({ ledgerStatus: "completed", log: null }), "send")
  assertEquals(
    notificationRetry({
      ledgerStatus: "completed",
      log: { notificationId: "notice-1" },
    }),
    "skip",
  )
  assertEquals(
    notificationRetry({
      ledgerStatus: "completed",
      log: { notificationId: null },
    }),
    "retry_incomplete_log",
  )
})
