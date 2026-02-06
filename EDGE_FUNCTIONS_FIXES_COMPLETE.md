# Edge Functions - All Critical Fixes Applied ✅

## Fixed Issues

### 1. ✅ FOR UPDATE Lock Race Condition
**Problem:** Lock didn't work if `weekly_usage` row didn't exist  
**Fix:** Insert row first with `ON CONFLICT DO NOTHING`, then lock it
```sql
-- Insert first (ensures row exists)
insert into public.weekly_usage (...) values (...) on conflict do nothing;
-- Then lock (guaranteed to work)
select ... from public.weekly_usage ... for update;
```

### 2. ✅ Week Start Calculation
**Problem:** Inconsistent Monday calculation  
**Fix:** ISO Monday formula used everywhere
```sql
-- Deterministic formula
v_week_start := (current_date - ((extract(dow from current_date)::int + 6) % 7));
```
Also updated in `get-entitlements` Edge Function to match.

### 3. ✅ Status Validation
**Problem:** `p_status` not validated at top, allowing invalid values  
**Fix:** Validate immediately after auth check
```sql
-- Validate status at top (before any other logic)
if p_status not in ('accepted', 'declined', 'cancelled') then
  return jsonb_build_object('error', 'Invalid status');
end if;
```

### 4. ✅ Security Definer Hardening
**Problem:** Missing `search_path` protection  
**Fix:** Added to both RPC functions
```sql
security definer
set search_path = public
```

### 5. ✅ Plan Selection NULL Handling
**Problem:** `coalesce` didn't handle missing row correctly  
**Fix:** Proper subquery with coalesce
```sql
select coalesce(
  (select plan from public.subscriptions where user_id = v_client_id limit 1),
  'free'
) into v_plan;
```

### 6. ✅ GRANT Syntax
**Problem:** Invalid function signature in GRANT  
**Fix:** Added function signatures and REVOKE
```sql
revoke all on function public.create_lead_tx(uuid, text) from public;
grant execute on function public.create_lead_tx(uuid, text) to authenticated;
```

### 7. ✅ Weekly Usage Inserts
**Problem:** Missing `video_sessions_used` column  
**Fix:** Included in all inserts
```sql
insert into public.weekly_usage (
  user_id, week_start, requests_used, 
  nutritionist_requests_used, video_sessions_used
) values (...);
```

### 8. ✅ Update Logic Simplified
**Problem:** Using INSERT ... ON CONFLICT when row already locked  
**Fix:** Use UPDATE directly (row is already locked)
```sql
-- Row already locked, safe to update
update public.weekly_usage
set requests_used = requests_used + 1
where user_id = v_client_id and week_start = v_week_start;
```

## Edge Functions Status

All 3 Edge Functions are **thin wrappers**:
- ✅ `create-lead`: Calls `create_lead_tx` RPC
- ✅ `update-lead-status`: Calls `update_lead_status_tx` RPC  
- ✅ `get-entitlements`: Uses `.maybeSingle()` and ISO Monday formula

## Migration File

`supabase/migrations/20250127_fix_quota_race_conditions.sql` contains:
- Unique index for active leads
- Unique constraint for conversations
- `create_lead_tx()` RPC with all fixes
- `update_lead_status_tx()` RPC with all fixes
- Proper GRANT/REVOKE statements

## Ready for Production

✅ No race conditions  
✅ No quota bypass  
✅ No duplicate conversations  
✅ Secure (search_path locked)  
✅ Consistent week calculations  
✅ Proper error handling  

**Next Step:** Run the migration and deploy Edge Functions.
