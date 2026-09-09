// Permanently deletes the authenticated Cotrainr account and user-owned data.
// Actor is always derived from the JWT; no user_id is accepted from the body.
// @ts-nocheck

import { createClient } from "jsr:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

async function removeStoragePrefix(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<void> {
  const files: string[] = []

  async function walk(path: string): Promise<void> {
    let offset = 0
    const pageSize = 100
    while (true) {
      const { data, error } = await admin.storage.from(bucket).list(path, {
        limit: pageSize,
        offset,
        sortBy: { column: "name", order: "asc" },
      })
      if (error) throw new Error(`storage_list_${bucket}`)
      const entries = data ?? []
      if (entries.length === 0) break

      for (const entry of entries) {
        const child = path ? `${path}/${entry.name}` : entry.name
        // Supabase folders have no object id; files do.
        if (entry.id) files.push(child)
        else await walk(child)
      }

      if (entries.length < pageSize) break
      offset += pageSize
    }
  }

  await walk(prefix)
  for (let i = 0; i < files.length; i += 100) {
    const batch = files.slice(i, i + 100)
    const { error } = await admin.storage.from(bucket).remove(batch)
    if (error) throw new Error(`storage_remove_${bucket}`)
  }
}

async function requireOk(
  operation: string,
  promise: PromiseLike<{ error: { code?: string; message?: string } | null }>,
) {
  const { error } = await promise
  if (error) {
    console.error(JSON.stringify({
      event: "delete_account_cleanup_failed",
      operation,
      code: error.code ?? "unknown",
    }))
    throw new Error(`cleanup_${operation}`)
  }
}

async function revokeGoogleIntegration(
  admin: ReturnType<typeof createClient>,
  uid: string,
): Promise<void> {
  const { data: integration, error } = await admin
    .from("user_integrations_google")
    .select("access_token,refresh_token")
    .eq("user_id", uid)
    .maybeSingle()

  if (error) {
    console.error(JSON.stringify({
      event: "delete_account_google_lookup_failed",
      code: error.code ?? "unknown",
    }))
    return
  }

  const token = integration?.refresh_token ?? integration?.access_token
  if (!token) return

  try {
    const response = await fetch("https://oauth2.googleapis.com/revoke", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ token }),
    })
    if (!response.ok) {
      console.warn(JSON.stringify({
        event: "delete_account_google_revoke_failed",
        status: response.status,
      }))
    }
  } catch (_) {
    console.warn(JSON.stringify({ event: "delete_account_google_revoke_failed" }))
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405)

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) return json({ error: "unauthorized" }, 401)

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const userClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) return json({ error: "unauthorized" }, 401)

    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )
    const uid = user.id

    // Revoke the external Google integration before its DB row disappears via
    // auth.users CASCADE. Revocation is best-effort: an unavailable Google
    // endpoint must not make a user unable to delete their Cotrainr account.
    await revokeGoogleIntegration(admin, uid)

    // Storage objects are not deleted by auth.users cascades.
    for (const bucket of [
      "avatars",
      "chat-attachments",
      "posts",
      "verification-docs",
    ]) {
      await removeStoragePrefix(admin, bucket, uid)
    }

    // Rows that intentionally/legacy do not cascade from auth.users/profiles.
    await requireOk(
      "partner_member_claims",
      admin.from("partner_member_claims").delete().eq("user_id", uid),
    )
    await requireOk(
      "partner_offer_redemptions",
      admin.from("partner_offer_redemptions").delete().eq("user_id", uid),
    )

    await requireOk("ai_plans_owned", admin.from("ai_plans").delete().eq("user_id", uid))
    await requireOk(
      "ai_plans_shared",
      admin.from("ai_plans").update({ shared_with_trainer_id: null }).eq("shared_with_trainer_id", uid),
    )
    await requireOk(
      "client_trainer_links",
      admin.from("client_trainer_links").delete().or(`client_id.eq.${uid},trainer_id.eq.${uid}`),
    )
    await requireOk(
      "conversation_members",
      admin.from("conversation_members").delete().eq("user_id", uid),
    )
    await requireOk("goals", admin.from("goals").delete().eq("user_id", uid))
    await requireOk(
      "message_archive_owned",
      admin.from("message_content_archive").delete().eq("sender_id", uid),
    )
    await requireOk(
      "message_archive_deleted_by",
      admin.from("message_content_archive").update({ deleted_by: null }).eq("deleted_by", uid),
    )
    await requireOk(
      "post_reports_reviewed_by",
      admin.from("post_reports").update({ reviewed_by: null }).eq("reviewed_by", uid),
    )
    await requireOk("reward_events", admin.from("reward_events").delete().eq("user_id", uid))
    await requireOk(
      "trainer_meal_sharing",
      admin.from("trainer_meal_sharing").delete().or(`client_id.eq.${uid},trainer_id.eq.${uid}`),
    )
    await requireOk(
      "trainer_notes",
      admin.from("trainer_notes").delete().or(`client_id.eq.${uid},trainer_id.eq.${uid}`),
    )
    await requireOk(
      "user_achievements",
      admin.from("user_achievements").delete().eq("user_id", uid),
    )

    // Retain operational audit records without retaining the deleted account id.
    await requireOk(
      "verification_reviewer",
      admin.from("verification_submissions").update({ reviewer_id: null }).eq("reviewer_id", uid),
    )
    await requireOk(
      "admin_audit_actor",
      admin.from("admin_audit_log").update({ actor_id: null }).eq("actor_id", uid),
    )
    await requireOk(
      "admin_audit_target",
      admin.from("admin_audit_log").update({ target_id: null }).eq("target_id", uid),
    )

    // All normal Cotrainr user tables are FK CASCADE from auth.users.
    const { error: deleteError } = await admin.auth.admin.deleteUser(uid)
    if (deleteError) {
      console.error(JSON.stringify({
        event: "delete_account_auth_failed",
        status: deleteError.status ?? null,
      }))
      return json({ error: "account_delete_failed" }, 500)
    }

    return json({ ok: true }, 200)
  } catch (error) {
    console.error(JSON.stringify({
      event: "delete_account_failed",
      code: String(error).slice(0, 120),
    }))
    return json({ error: "account_delete_failed" }, 500)
  }
})
