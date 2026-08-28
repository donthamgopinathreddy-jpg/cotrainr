/**
 * Unit tests for the notifications INSERT webhook payload contract (Deno).
 * Run: deno test supabase/functions/send-push-notification/payload_test.ts
 *
 * No real FCM delivery happens here; only the validation contract is checked.
 */

import {
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { validateWebhookPayload } from "./payload.ts";

function validPayload(overrides: Record<string, unknown> = {}) {
  return {
    type: "INSERT",
    table: "notifications",
    schema: "public",
    old_record: null,
    record: {
      id: "11111111-1111-1111-1111-111111111111",
      user_id: "22222222-2222-2222-2222-222222222222",
      type: "video_session_reminder",
      title: "Session starting soon",
      body: "Your session begins in 5 minutes.",
      data: { session_id: "33333333-3333-3333-3333-333333333333" },
    },
    ...overrides,
  };
}

Deno.test("valid notifications INSERT is accepted", () => {
  const result = validateWebhookPayload(validPayload());
  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.record.user_id, "22222222-2222-2222-2222-222222222222");
  }
});

Deno.test("null data is accepted", () => {
  const payload = validPayload();
  (payload.record as Record<string, unknown>).data = null;
  assertEquals(validateWebhookPayload(payload).ok, true);
});

Deno.test("non-INSERT events are acked, not processed", () => {
  const result = validateWebhookPayload(validPayload({ type: "UPDATE" }));
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.ignore, true);
});

Deno.test("other tables are acked, not processed", () => {
  const result = validateWebhookPayload(validPayload({ table: "messages" }));
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.ignore, true);
});

Deno.test("non-public schema is acked, not processed", () => {
  const result = validateWebhookPayload(validPayload({ schema: "auth" }));
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.ignore, true);
});

Deno.test("malformed payloads are rejected as errors", () => {
  const cases: unknown[] = [
    null,
    "not-an-object",
    validPayload({ record: null }),
    validPayload({ record: { user_id: "u", type: "t", title: "x", body: "y" } }),
    validPayload({
      record: { id: "i", type: "t", title: "x", body: "y" },
    }),
    validPayload({
      record: { id: "i", user_id: "u", type: 5, title: "x", body: "y" },
    }),
    validPayload({
      record: { id: "i", user_id: "u", type: "t", title: "", body: "y" },
    }),
    validPayload({
      record: {
        id: "i",
        user_id: "u",
        type: "t",
        title: "x",
        body: "y",
        data: ["not", "an", "object"],
      },
    }),
  ];

  for (const payload of cases) {
    const result = validateWebhookPayload(payload);
    assertEquals(result.ok, false, `expected rejection for ${JSON.stringify(payload)}`);
    if (!result.ok) {
      assertEquals(result.ignore ?? false, false);
    }
  }
});
