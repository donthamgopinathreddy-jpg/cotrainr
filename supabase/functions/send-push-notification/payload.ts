// Payload contract for the public.notifications INSERT database webhook.
// Kept separate from index.ts so it can be unit-tested without Deno.serve.

export type NotificationPushRecord = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown> | null;
};

export type ValidationResult =
  | { ok: true; record: NotificationPushRecord }
  | { ok: false; reason: string; ignore?: boolean };

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

/// Validates a Supabase database-webhook payload.
///
/// `ignore: true` means the payload is well-formed but not a notifications
/// INSERT, so the caller should ack with 200 instead of 400.
export function validateWebhookPayload(payload: unknown): ValidationResult {
  if (typeof payload !== "object" || payload === null) {
    return { ok: false, reason: "payload_not_object" };
  }

  const p = payload as Record<string, unknown>;

  if (p.schema !== undefined && p.schema !== "public") {
    return { ok: false, reason: "unexpected_schema", ignore: true };
  }
  if (p.type !== "INSERT" || p.table !== "notifications") {
    return { ok: false, reason: "not_notification_insert", ignore: true };
  }

  const record = p.record;
  if (typeof record !== "object" || record === null) {
    return { ok: false, reason: "missing_record" };
  }

  const r = record as Record<string, unknown>;
  for (const field of ["id", "user_id", "type", "title", "body"]) {
    if (!isNonEmptyString(r[field])) {
      return { ok: false, reason: `invalid_${field}` };
    }
  }
  if (
    r.data !== undefined && r.data !== null &&
    (typeof r.data !== "object" || Array.isArray(r.data))
  ) {
    return { ok: false, reason: "invalid_data" };
  }

  return {
    ok: true,
    record: {
      id: r.id as string,
      user_id: r.user_id as string,
      type: r.type as string,
      title: r.title as string,
      body: r.body as string,
      data: (r.data ?? null) as Record<string, unknown> | null,
    },
  };
}
