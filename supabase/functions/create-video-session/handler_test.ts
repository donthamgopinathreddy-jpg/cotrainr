/**
 * HTTP handler tests for create-video-session.
 * Run: deno test supabase/functions/create-video-session/handler_test.ts
 *
 * No Google Meet, Supabase, or network calls.
 */

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts"
import {
  beginMeetAttempt,
  claimFailedRetry,
  claimNew,
  markAmbiguousOutcome,
  markCompleted,
  markConfirmedMeetRejection,
  markFailedBeforeCall,
  reserveSessionInsert,
  saveMeetSpace,
  takeoverStaleClaim,
  type LedgerRow,
  type MemoryLedger,
} from "./idempotency.ts"
import {
  CREATION_UNCERTAIN_MESSAGE,
  handleCreateVideoSession,
  type CreateVideoSessionDeps,
  type MeetCreateResult,
  type SessionRecord,
  type VideoSessionLedger,
} from "./handler.ts"

const NOW = Date.parse("2026-10-18T10:00:00.000Z")
const START = "2026-10-18T11:00:00.000Z"
const HOST = "host-1"
const CLIENT = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
const REQUEST_ID = "vs-1760780000000000-12345"

function memoryLedger(): VideoSessionLedger & { rows: MemoryLedger } {
  const rows: MemoryLedger = new Map()
  return {
    rows,
    claim: (userId, key, fingerprint, nowMs) => {
      void userId
      const result = claimNew(rows, key, fingerprint, nowMs)
      if (result.inserted) {
        return Promise.resolve({ ok: true, inserted: true, generation: result.claimGeneration })
      }
      const row = rows.get(key)
      if (!row) return Promise.resolve({ ok: false, schemaUnavailable: true })
      return Promise.resolve({ ok: true, inserted: false, row })
    },
    beginMeetAttempt: (_userId, key, generation, nowMs) =>
      Promise.resolve(beginMeetAttempt(rows, key, generation, nowMs)),
    saveMeetSpace: (_userId, key, generation, spaceId, joinUrl, nowMs) =>
      Promise.resolve(saveMeetSpace(rows, key, generation, spaceId, joinUrl, nowMs)),
    markAmbiguous: (_userId, key, generation, nowMs) =>
      Promise.resolve(markAmbiguousOutcome(rows, key, generation, nowMs)),
    markConfirmedRejection: (_userId, key, generation, nowMs) =>
      Promise.resolve(markConfirmedMeetRejection(rows, key, generation, nowMs)),
    markFailedBeforeCall: (_userId, key, generation, nowMs) =>
      Promise.resolve(markFailedBeforeCall(rows, key, generation, nowMs)),
    retryFailed: (_userId, key, seenGeneration, nowMs) =>
      Promise.resolve(claimFailedRetry(rows, key, seenGeneration, nowMs)),
    takeoverStale: (_userId, key, seenGeneration, nowMs) =>
      Promise.resolve(takeoverStaleClaim(rows, key, seenGeneration, nowMs)),
    reserveSessionInsert: (_userId, key, seenGeneration, nowMs, requireSpace) =>
      Promise.resolve(reserveSessionInsert(rows, key, seenGeneration, nowMs, requireSpace)),
    markCompleted: (_userId, key, generation, sessionId, nowMs) =>
      Promise.resolve(markCompleted(rows, key, generation, sessionId, nowMs)),
  }
}

function seed(rows: MemoryLedger, key: string, row: LedgerRow) {
  rows.set(key, row)
}

type Harness = {
  deps: CreateVideoSessionDeps
  ledger: ReturnType<typeof memoryLedger>
  meetCalls: () => number
  notifyCalls: () => number
  sessions: Map<string, SessionRecord>
  setMeet: (meet: () => Promise<MeetCreateResult>) => void
  setParticipants: (fn: () => Promise<string | null>) => void
  setComplete: (fn: VideoSessionLedger["markCompleted"]) => void
}

function harness(overrides: {
  userId?: string | null
  restricted?: boolean
  verified?: boolean
  accepted?: string[]
  leadsOk?: boolean
  token?: { ok: true; accessToken: string } | { ok: false; code: string; message: string }
} = {}): Harness {
  const ledger = memoryLedger()
  const sessions = new Map<string, SessionRecord>()
  let sessionCount = 0
  let meetCalls = 0
  let notifyCalls = 0
  let meet: () => Promise<MeetCreateResult> = () => {
    meetCalls += 1
    return Promise.resolve({
      ok: true,
      space: {
        name: "spaces/one",
        meetingUri: "https://meet.google.com/abc-defg-hij",
        meetingCode: "abc-defg-hij",
      },
    })
  }
  let participants = () => Promise.resolve<string | null>(null)
  const recordedComplete = ledger.markCompleted.bind(ledger)
  let complete: VideoSessionLedger["markCompleted"] = recordedComplete

  const deps: CreateVideoSessionDeps = {
    now: () => NOW,
    authenticate: (authHeader) => {
      if (!authHeader) {
        return Promise.resolve({
          ok: false,
          response: Response.json({ error: "Missing Authorization header" }, { status: 401 }),
        })
      }
      if (overrides.userId === null) {
        return Promise.resolve({
          ok: false,
          response: Response.json({ error: "Unauthorized" }, { status: 401 }),
        })
      }
      return Promise.resolve({ ok: true, userId: overrides.userId ?? HOST })
    },
    accountRestricted: () =>
      Promise.resolve(
        overrides.restricted
          ? Response.json({ error: "Account restricted", code: "ACCOUNT_RESTRICTED" }, { status: 403 })
          : null,
      ),
    loadProvider: () =>
      Promise.resolve({
        verified: overrides.verified !== false,
        providerType: "trainer",
      }),
    loadAcceptedClientIds: () => {
      if (overrides.leadsOk === false) return Promise.resolve({ ok: false })
      return Promise.resolve({ ok: true, ids: overrides.accepted ?? [CLIENT] })
    },
    googleAccessToken: () =>
      Promise.resolve(overrides.token ?? { ok: true, accessToken: "token" }),
    markGoogleReconnect: () => Promise.resolve(),
    createMeetSpace: () => meet(),
    ledger: {
      claim: (...args) => ledger.claim(...args),
      beginMeetAttempt: (...args) => ledger.beginMeetAttempt(...args),
      saveMeetSpace: (...args) => ledger.saveMeetSpace(...args),
      markAmbiguous: (...args) => ledger.markAmbiguous(...args),
      markConfirmedRejection: (...args) => ledger.markConfirmedRejection(...args),
      markFailedBeforeCall: (...args) => ledger.markFailedBeforeCall(...args),
      retryFailed: (...args) => ledger.retryFailed(...args),
      takeoverStale: (...args) => ledger.takeoverStale(...args),
      reserveSessionInsert: (...args) => ledger.reserveSessionInsert(...args),
      markCompleted: (...args) => complete(...args),
    },
    loadSession: (sessionId) => Promise.resolve(sessions.get(sessionId) ?? null),
    insertSession: (input) => {
      sessionCount += 1
      const session: SessionRecord = {
        id: `session-${sessionCount}`,
        join_url: input.joinUrl,
        title: input.title,
        scheduled_start: input.scheduledStart,
        created_at: "2026-10-18T10:00:01.000Z",
        duration_minutes: input.durationMinutes,
        status: "scheduled",
        description: input.description,
        host_id: input.hostId,
        provider: input.provider,
      }
      sessions.set(session.id, session)
      return Promise.resolve(session)
    },
    upsertProviderMeta: () => Promise.resolve(),
    upsertParticipants: () => participants(),
    deleteSession: (sessionId) => {
      sessions.delete(sessionId)
      return Promise.resolve()
    },
    notifySessionCreated: () => {
      notifyCalls += 1
      return Promise.resolve()
    },
    log: () => {},
  }

  return {
    deps,
    ledger,
    sessions,
    meetCalls: () => meetCalls,
    notifyCalls: () => notifyCalls,
    setMeet: (next) => {
      meet = () => {
        meetCalls += 1
        return next()
      }
    },
    setParticipants: (fn) => {
      participants = fn
    },
    setComplete: (fn) => {
      complete = fn
    },
  }
}

function post(body: Record<string, unknown>, auth = "Bearer test"): Request {
  return new Request("http://localhost/functions/v1/create-video-session", {
    method: "POST",
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  })
}

function body(overrides: Record<string, unknown> = {}) {
  return {
    title: "Morning lift",
    scheduled_start: START,
    duration_minutes: 30,
    max_participants: 5,
    participant_ids: [CLIENT],
    provider: "google_meet",
    client_request_id: REQUEST_ID,
    ...overrides,
  }
}

async function read(res: Response): Promise<{ status: number; json: Record<string, unknown> }> {
  return { status: res.status, json: await res.json() }
}

Deno.test("authorization and validation stay ahead of Meet", async () => {
  const missing = harness()
  const noAuth = await read(await handleCreateVideoSession(post(body(), ""), missing.deps))
  assertEquals(noAuth.status, 401)
  assertEquals(missing.meetCalls(), 0)

  const banned = harness({ restricted: true })
  const restricted = await read(await handleCreateVideoSession(post(body()), banned.deps))
  assertEquals(restricted.status, 403)
  assertEquals(restricted.json.code, "ACCOUNT_RESTRICTED")

  const unverified = harness({ verified: false })
  const provider = await read(await handleCreateVideoSession(post(body()), unverified.deps))
  assertEquals(provider.status, 403)
  assertEquals(provider.json.code, "PROVIDER_VERIFICATION_REQUIRED")

  const stranger = harness({ accepted: [] })
  const lead = await read(await handleCreateVideoSession(post(body()), stranger.deps))
  assertEquals(lead.status, 403)
  assertEquals(lead.json.code, "RELATIONSHIP_REQUIRED")
  assertEquals(stranger.meetCalls(), 0)

  const schedule = harness()
  const past = await read(await handleCreateVideoSession(
    post(body({ scheduled_start: "2026-10-18T09:00:00.000Z" })),
    schedule.deps,
  ))
  assertEquals(past.status, 400)
  assertEquals(past.json.code, "VALIDATION")
  assertEquals(schedule.ledger.rows.size, 0)
})

Deno.test("a successful create claims once, saves the space, and notifies once", async () => {
  const h = harness()
  const res = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(res.status, 200)
  assertEquals(res.json.id, "session-1")
  assertEquals(res.json.join_url, "https://meet.google.com/abc-defg-hij")
  assertEquals(res.json.host_id, HOST)
  assertEquals(res.json.provider, "google_meet")
  assertEquals(res.json.status, "scheduled")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.notifyCalls(), 1)
  assertEquals(h.ledger.rows.get(REQUEST_ID)?.status, "completed")
  assertEquals(h.ledger.rows.get(REQUEST_ID)?.externalSpaceId, "spaces/one")
  assertEquals(h.ledger.rows.get(REQUEST_ID)?.sessionId, "session-1")
})

Deno.test("replay returns the same session and does not notify again", async () => {
  const h = harness()
  await handleCreateVideoSession(post(body()), h.deps)
  const again = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(again.status, 200)
  assertEquals(again.json.id, "session-1")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.notifyCalls(), 1)
  assertEquals(h.sessions.size, 1)
})

Deno.test("a reused key with a different payload conflicts", async () => {
  const h = harness()
  await handleCreateVideoSession(post(body()), h.deps)
  const conflict = await read(await handleCreateVideoSession(
    post(body({ title: "Different title" })),
    h.deps,
  ))
  assertEquals(conflict.status, 409)
  assertEquals(conflict.json.code, "PAYLOAD_CONFLICT")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.notifyCalls(), 1)
})

Deno.test("concurrent requests create one Meet space", async () => {
  const h = harness()
  let release: (result: MeetCreateResult) => void = () => {}
  let entered: () => void = () => {}
  const started = new Promise<void>((resolve) => {
    entered = resolve
  })
  const gate = new Promise<MeetCreateResult>((resolve) => {
    release = resolve
  })
  h.setMeet(() => {
    entered()
    return gate
  })

  const first = handleCreateVideoSession(post(body()), h.deps)
  await started
  const second = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(second.status, 409)
  assertEquals(second.json.code, "CREATION_UNCERTAIN")
  assertEquals(h.meetCalls(), 1)

  release({
    ok: true,
    space: {
      name: "spaces/one",
      meetingUri: "https://meet.google.com/abc-defg-hij",
    },
  })
  const created = await read(await first)
  assertEquals(created.status, 200)
  assertEquals(created.json.id, "session-1")

  const replay = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(replay.status, 200)
  assertEquals(replay.json.id, "session-1")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.notifyCalls(), 1)
})

Deno.test("lost ownership does not create a Meet space", async () => {
  const h = harness()
  h.deps.ledger.beginMeetAttempt = () => Promise.resolve(false)
  const res = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(res.status, 409)
  assertEquals(res.json.code, "LOST_OWNERSHIP")
  assertEquals(h.meetCalls(), 0)
  assertEquals(h.notifyCalls(), 0)
  assertEquals(h.sessions.size, 0)
})

Deno.test("an ambiguous Meet failure is uncertain and is not retried", async () => {
  const h = harness()
  h.setMeet(() =>
    Promise.resolve({
      ok: false,
      code: "GOOGLE_RATE_LIMITED",
      message: "Google Meet is rate-limited. Try again in a moment.",
      httpStatus: 429,
    })
  )
  const first = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(first.status, 409)
  assertEquals(first.json.code, "CREATION_UNCERTAIN")
  assertEquals(first.json.error, CREATION_UNCERTAIN_MESSAGE)
  assertEquals(h.ledger.rows.get(REQUEST_ID)?.status, "uncertain")
  assertEquals(h.notifyCalls(), 0)

  const second = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(second.status, 409)
  assertEquals(second.json.code, "CREATION_UNCERTAIN")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.sessions.size, 0)
})

Deno.test("a thrown Meet call is ambiguous and does not notify", async () => {
  const h = harness()
  h.setMeet(() => Promise.reject(new Error("timeout")))
  const res = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(res.status, 409)
  assertEquals(res.json.code, "CREATION_UNCERTAIN")
  assertEquals(h.ledger.rows.get(REQUEST_ID)?.status, "uncertain")
  const again = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(again.json.code, "CREATION_UNCERTAIN")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.notifyCalls(), 0)
})

Deno.test("a confirmed Meet rejection can be retried with the same request id", async () => {
  const h = harness()
  let attempt = 0
  h.setMeet(() => {
    attempt += 1
    if (attempt === 1) {
      return Promise.resolve({
        ok: false,
        code: "GOOGLE_FORBIDDEN",
        message: "Google Meet permission denied. Reconnect Google Meet.",
        httpStatus: 403,
      })
    }
    return Promise.resolve({
      ok: true,
      space: {
        name: "spaces/two",
        meetingUri: "https://meet.google.com/retry-meet",
      },
    })
  })
  const rejected = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(rejected.status, 400)
  assertEquals(rejected.json.code, "GOOGLE_RECONNECT_REQUIRED")
  assertEquals(h.notifyCalls(), 0)

  const created = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(created.status, 200)
  assertEquals(created.json.join_url, "https://meet.google.com/retry-meet")
  assertEquals(h.meetCalls(), 2)
  assertEquals(h.notifyCalls(), 1)
})

Deno.test("a saved Meet space is resumed without a second create", async () => {
  const h = harness()
  let failParticipants = true
  h.setParticipants(() => Promise.resolve(failParticipants ? "insert failed" : null))
  const failed = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(failed.status, 500)
  assertEquals(failed.json.code, "PARTICIPANTS_FAILED")
  assertEquals(h.sessions.size, 0)
  assertEquals(h.ledger.rows.get(REQUEST_ID)?.externalSpaceId, "spaces/one")
  assertEquals(h.notifyCalls(), 0)

  failParticipants = false
  const resumed = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(resumed.status, 200)
  assertEquals(resumed.json.join_url, "https://meet.google.com/abc-defg-hij")
  assertEquals(h.meetCalls(), 1)
  assertEquals(h.notifyCalls(), 1)
})

Deno.test("historical null session_id stays uncertain", async () => {
  const h = harness()
  seed(h.ledger.rows, REQUEST_ID, {
    status: "uncertain",
    sessionId: null,
    externalSpaceId: null,
    joinUrl: null,
    updatedAtMs: NOW,
    requestFingerprint: null,
    claimGeneration: 0,
    meetAttempt: "none",
  })
  const res = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(res.status, 409)
  assertEquals(res.json.code, "CREATION_UNCERTAIN")
  assertEquals(h.meetCalls(), 0)
})

Deno.test("a zero-row completion does not notify", async () => {
  const h = harness()
  h.setComplete(() => Promise.resolve(false))
  const res = await read(await handleCreateVideoSession(post(body()), h.deps))
  assertEquals(res.status, 409)
  assertEquals(res.json.code, "LOST_OWNERSHIP")
  assertEquals(h.notifyCalls(), 0)
  assertEquals(h.sessions.size, 0)
  assertEquals(h.meetCalls(), 1)
})

Deno.test("client_request_id is required before a Meet call", async () => {
  const h = harness()
  const res = await read(await handleCreateVideoSession(
    post(body({ client_request_id: "" })),
    h.deps,
  ))
  assertEquals(res.status, 400)
  assertEquals(res.json.code, "VALIDATION")
  assertEquals(h.meetCalls(), 0)
  assertEquals(h.ledger.rows.size, 0)
})
