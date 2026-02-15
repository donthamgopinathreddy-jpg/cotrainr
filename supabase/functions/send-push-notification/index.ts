// Sends FCM push when a notification is inserted.
// Triggered by Database Webhook on notifications INSERT.
// Requires secrets: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE"
  table: string
  record: {
    id: string
    user_id: string
    type: string
    title: string
    body: string
    data?: Record<string, unknown>
  }
  schema: string
  old_record: unknown
}

async function getFirebaseAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n")
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID")

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error("Missing Firebase credentials. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY secrets.")
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
    btoa(s)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "")
  const header = toBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  const payloadB64 = toBase64Url(JSON.stringify(payload))
  const signatureInput = `${header}.${payloadB64}`

  const pemHeader = "-----BEGIN PRIVATE KEY-----"
  const pemFooter = "-----END PRIVATE KEY-----"
  const pemContents = privateKey.replace(pemHeader, "").replace(pemFooter, "").replace(/\s/g, "")
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signatureInput)
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
    const err = await tokenRes.text()
    throw new Error(`Failed to get Firebase access token: ${err}`)
  }

  const tokenData = await tokenRes.json()
  return tokenData.access_token
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ),
        },
      }),
    }
  )

  if (!res.ok) {
    const err = await res.text()
    console.error(`FCM send failed for token: ${err}`)
    return false
  }
  return true
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const payload: WebhookPayload = await req.json()

    if (payload.type !== "INSERT" || payload.table !== "notifications") {
      return new Response(
        JSON.stringify({ received: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { user_id, title, body, type, data } = payload.record

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const { data: profileRows } = await supabase.rpc("get_notification_push", {
      p_user_id: user_id,
    })
    const profile = Array.isArray(profileRows) && profileRows.length > 0 ? profileRows[0] : null

    if (profile?.notification_push === false) {
      return new Response(
        JSON.stringify({ skipped: "user disabled push" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id)

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ skipped: "no device tokens" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const accessToken = await getFirebaseAccessToken()
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!

    const dataPayload: Record<string, string> = {
      type: type || "",
      notification_id: payload.record.id,
    }
    if (data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) {
        if (v != null) dataPayload[k] = String(v)
      }
    }

    let sent = 0
    for (const row of tokens) {
      const ok = await sendFcmMessage(
        accessToken,
        projectId,
        row.token,
        title,
        body,
        dataPayload
      )
      if (ok) sent++
    }

    return new Response(
      JSON.stringify({ sent, total: tokens.length }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    console.error("send-push-notification error:", error)
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
