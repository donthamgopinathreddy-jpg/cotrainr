# Retool — User Reports & Moderation

**Prerequisites:** Apply migration `supabase/migrations/20260808_chat_user_safety_moderation.sql`.

**Resource:** existing `supabase_admin` (service_role). Never expose service_role in Flutter.

## Nav addition

Add left-nav item: **Reports** → screen `user_reports`.

## Queries (REST RPC)

### List reports
`POST /rest/v1/rpc/admin_list_user_reports`
```json
{ "p_actor_id": "{{ admin_actor_uuid }}", "p_status": "pending", "p_limit": 100 }
```
Statuses filter: `pending` | `under_review` | `resolved` | `dismissed` | null (all).

### Update report status
`admin_update_user_report`
```json
{
  "p_actor_id": "{{ admin_actor_uuid }}",
  "p_report_id": "...",
  "p_status": "under_review",
  "p_moderation_notes": "...",
  "p_resolution": null
}
```

### Warn / Suspend / Ban
- `admin_warn_user` — `{ p_actor_id, p_target_user_id, p_reason, p_report_id? }`
- `admin_suspend_user` — `{ p_actor_id, p_target_user_id, p_reason, p_duration: "24h"|"7d"|"30d"|"indefinite", p_report_id? }`
- `admin_unsuspend_user`
- `admin_ban_user`
- `admin_unban_user`

All write to `admin_audit_log` with actions: `WARN`, `SUSPEND`, `UNSUSPEND`, `BAN`, `UNBAN`, `REPORT_UNDER_REVIEW`, `REPORT_DISMISSED`, `REPORT_RESOLVED`.

## Detail UI fields

From list row: reported user, reporter, role, reason, details, created_at, conversation_id, previous_report_count, reported_account_status, reporter_blocked_reported.

Admin notes → `p_moderation_notes`.

Conversation: open read-only message query filtered by `conversation_id` (service_role) — do not copy messages into the report row.

## Notes

- Temporary suspension expiry is automatic via `effective_account_status` / `account_may_use_messaging` (no manual Retool expiry required).
- Delete User is intentionally not provided; use Ban for persistent restriction.
- Flutter only calls: `submit_user_report`, `block_user_tx`, `unblock_user_tx`, `get_block_state`.
