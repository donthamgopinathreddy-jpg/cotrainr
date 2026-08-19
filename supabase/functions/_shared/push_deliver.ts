// FCM delivery for rows in public.notifications.
// Never log tokens, JWTs, or Firebase private keys.

import { createClient } from "jsr:@supabase/supabase-js@2"

export type NotificationPushRecord = {
  id: string
  user_id: string
  type: string
  title: string
  body: string
  data?: Record<string, unknown> | null
}

type DeliverResult = {
  attempted: boolean
  tokenCount: number
  sent: number
  skipped?: string
  errorCode?: string
}

async function getFirebaseAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n")
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID")

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error("missing_firebase_credentials")
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  }

  const toBase64Url = (s: string) =>
    btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  const header = toBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  const payloadB64 = toBase64Url(JSON.stringify(payload))
  const signatureInput = `${header}.${payloadB64}`

  const pemHeader = "-----BEGIN PRIVATE KEY-----"
  const pemFooter = "-----END PRIVATE KEY-----"
  const pemContents = privateKey
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "")
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  )

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signatureInput),
  )
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")

  const jwt = `${signatureInput}.${signatureB64}`

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })

  if (!tokenRes.ok) {
    throw new Error(`firebase_token_${tokenRes.status}`)
  }

  const tokenData = await tokenRes.json()
  return tokenData.access_token
}

function isActionableVideoReminder(type: string): boolean {
  return type === "video_session_reminder_5m" || type === "video_session_starting"
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<{ ok: boolean; status: number }> {
  const actionable = isActionableVideoReminder(data.type || "")
  // Data-only for JOIN/REJECT reminders so Android does not auto-render a
  // button-less system notification that would duplicate our local one.
  const message: Record<string, unknown> = {
    token,
    data: {
      ...data,
      title,
      body,
    },
    android: {
      priority: data.type?.startsWith("video_session_") ? "HIGH" : "NORMAL",
    },
  }
  if (!actionable) {
    message.notification = { title, body }
    message.android = {
      priority: data.type?.startsWith("video_session_") ? "HIGH" : "NORMAL",
      notification: {
        channel_id: data.type?.startsWith("video_session_")
          ? "cotrainr_video_sessions"
          : "cotrainr_notifications",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    }
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ message }),
    },
  )
  if (!res.ok) {
    const err = await res.text()
    console.error(
      JSON.stringify({
        event: "fcm_failure",
        status: res.status,
        body: err.slice(0, 300),
      }),
    )
  }
  return { ok: res.ok, status: res.status }
}

export async function deliverNotificationPush(
  record: NotificationPushRecord,
): Promise<DeliverResult> {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  const { data: profileRows } = await supabase.rpc("get_notification_push", {
    p_user_id: record.user_id,
  })
  const profile =
    Array.isArray(profileRows) && profileRows.length > 0 ? profileRows[0] : null
  if (profile?.notification_push === false) {
    console.log(JSON.stringify({
      event: "fcm_skipped",
      reason: "user_disabled_push",
      notification_id: record.id,
    }))
    return { attempted: false, tokenCount: 0, sent: 0, skipped: "user_disabled_push" }
  }

  const type = record.type || ""
  const remindersOff = profile?.notification_video_session_reminders === false
  const sessionsOff = profile?.notification_video_sessions === false
  if (
    (type === "video_session_reminder_5m" || type === "video_session_starting") &&
    remindersOff
  ) {
    console.log(JSON.stringify({
      event: "fcm_skipped",
      reason: "user_disabled_video_reminders",
      notification_id: record.id,
    }))
    return {
      attempted: false,
      tokenCount: 0,
      sent: 0,
      skipped: "user_disabled_video_reminders",
    }
  }
  if (type.startsWith("video_session_") && sessionsOff &&
      type !== "video_session_reminder_5m" &&
      type !== "video_session_starting") {
    console.log(JSON.stringify({
      event: "fcm_skipped",
      reason: "user_disabled_video_sessions",
      notification_id: record.id,
    }))
    return {
      attempted: false,
      tokenCount: 0,
      sent: 0,
      skipped: "user_disabled_video_sessions",
    }
  }

  const { data: tokens, error: tokenErr } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", record.user_id)

  if (tokenErr) {
    console.error(JSON.stringify({
      event: "device_tokens_query_failed",
      code: tokenErr.code,
      message: tokenErr.message,
    }))
    return {
      attempted: false,
      tokenCount: 0,
      sent: 0,
      skipped: "device_tokens_query_failed",
      errorCode: tokenErr.code,
    }
  }

  const tokenCount = tokens?.length ?? 0
  console.log(JSON.stringify({
    event: "device_tokens_found",
    notification_id: record.id,
    token_count: tokenCount,
  }))

  if (tokenCount === 0) {
    return { attempted: false, tokenCount: 0, sent: 0, skipped: "no_device_tokens" }
  }

  let accessToken: string
  try {
    accessToken = await getFirebaseAccessToken()
  } catch (e) {
    const code = String(e)
    console.error(JSON.stringify({ event: "fcm_auth_failed", errorCode: code }))
    return {
      attempted: true,
      tokenCount,
      sent: 0,
      skipped: "fcm_auth_failed",
      errorCode: code,
    }
  }

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!
  const dataPayload: Record<string, string> = {
    type: record.type || "",
    notification_id: record.id,
  }
  if (record.data && typeof record.data === "object") {
    for (const [k, v] of Object.entries(record.data)) {
      if (v != null && typeof v !== "object") dataPayload[k] = String(v)
      else if (v != null) dataPayload[k] = JSON.stringify(v)
    }
  }

  console.log(JSON.stringify({
    event: "fcm_send_attempted",
    notification_id: record.id,
    type: record.type,
    token_count: tokenCount,
  }))

  let sent = 0
  for (const row of tokens ?? []) {
    const result = await sendFcmMessage(
      accessToken,
      projectId,
      row.token,
      record.title,
      record.body,
      dataPayload,
    )
    if (result.ok) sent++
  }

  console.log(JSON.stringify({
    event: sent > 0 ? "fcm_success" : "fcm_failure",
    notification_id: record.id,
    sent,
    token_count: tokenCount,
  }))

  return { attempted: true, tokenCount, sent }
}

export async function deliverNotificationRows(
  rows: Array<{
    notification_id?: string
    recipient_user_id?: string
    push_title?: string
    push_body?: string
    payload?: Record<string, unknown> | null
  }>,
): Promise<void> {
  for (const row of rows) {
    if (!row.notification_id || !row.recipient_user_id) continue
    const type =
      (row.payload?.type as string | undefined) || "video_session_created"
    await deliverNotificationPush({
      id: row.notification_id,
      user_id: row.recipient_user_id,
      type,
      title: row.push_title || "Cotrainr",
      body: row.push_body || "",
      data: row.payload ?? {},
    })
  }
}
