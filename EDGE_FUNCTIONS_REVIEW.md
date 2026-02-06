# Edge Functions Review - Fixed Issues

## ✅ Fixed Critical Issues

### 1. Quota Bypass (FIXED)
- **Problem:** Race condition in create-lead allowed quota bypass
- **Solution:** Moved entire operation to `create_lead_tx()` RPC with:
  - `FOR UPDATE` lock on weekly_usage row
  - Atomic transaction (all-or-nothing)
  - Unique index prevents duplicate active leads

### 2. Duplicate Conversations (FIXED)
- **Problem:** Multiple accepts could create duplicate conversations
- **Solution:** 
  - Unique constraint on `conversations.lead_id`
  - `update_lead_status_tx()` uses `ON CONFLICT DO NOTHING`
  - Only allows status change from 'requested'

### 3. 500 Errors (FIXED)
- **Problem:** `.single()` throws when rows don't exist
- **Solution:** Changed to `.maybeSingle()` in get-entitlements

### 4. Nutritionist Logic (FIXED)
- **Problem:** Nutritionist requests didn't increment total counter
- **Solution:** RPC increments both `requests_used` AND `nutritionist_requests_used` for nutritionist requests

## SQL Migration Required

Run `supabase/migrations/20250127_fix_quota_race_conditions.sql` which includes:

1. **Unique index** on active leads (prevents duplicates)
2. **Unique constraint** on conversations.lead_id (prevents duplicate conversations)
3. **create_lead_tx()** RPC function (atomic transaction)
4. **update_lead_status_tx()** RPC function (atomic transaction with state validation)

## Edge Functions Now

All 3 functions are **thin wrappers** that:
- Validate auth
- Call RPC function
- Return result

No business logic in Edge Functions - all in database transactions.

## Testing Checklist

1. ✅ Run SQL migration
2. ⚠️ Deploy Edge Functions
3. ⚠️ Test concurrent create-lead (should not bypass quota)
4. ⚠️ Test duplicate accept (should not create duplicate conversation)
5. ⚠️ Test get-entitlements with no subscription (should return free plan)
