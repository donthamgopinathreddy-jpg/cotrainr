# Referral System Test Checklist

## Prerequisites
- Run migration: `supabase/migrations/20250213_referral_system.sql`
- Ensure `calculate_level_from_xp` exists (from `20250127_dynamic_quest_system.sql`)
- Domain: https://www.cotrainr.com

## Manual Test Steps

### 0. Signup username + full_name
- [ ] Signup passes `username` and `full_name` in auth.signUp(data: {...})
- [ ] handle_new_user trigger does not fail (username required in metadata)

### 1. Self-referral blocked
- [ ] User A creates account, gets referral code from Refer a Friend
- [ ] User A signs out (or use incognito)
- [ ] User A tries to sign up with own code → "Cannot use your own referral code" (status: self_referral)

### 2. Duplicate use blocked
- [ ] User B signs up with User A's code → success
- [ ] User B tries to apply another code (or same code again) → "Referral already applied" (status: already_used)
- [ ] Verify no duplicate referral rows in DB

### 3. Rewards granted once (idempotent)
- [ ] User B reaches 500 XP → trigger fires exactly once when crossing 500
- [ ] Referrer gets +500 XP, 2x multiplier 24h; referred gets +250 XP
- [ ] Verify referral_rewards has 3 rows (referrer xp, referrer multiplier, referred xp)
- [ ] Verify referrals.rewarded=true, rewarded_at set
- [ ] If grant_referral_rewards called again for same user → no duplicate rewards (ON CONFLICT DO NOTHING)

### 4. Deep link flow works
- [ ] **Custom scheme:** Open `cotrainr://invite?code=ABC123` → app opens, navigates to Create Account with code pre-filled (when not logged in)
- [ ] **HTTPS:** Open `https://www.cotrainr.com/invite?code=ABC123` → same (requires assetlinks.json + apple-app-site-association on domain)

### 5. App link + scheme works
- [ ] Android: cotrainr://invite and https://www.cotrainr.com/invite both open app
- [ ] iOS: cotrainr://invite opens app; Universal Links require Associated Domains

### 6. RLS blocks direct inserts
- [ ] As authenticated user, try INSERT into referrals → denied
- [ ] As authenticated user, try INSERT into referral_rewards → denied
- [ ] SELECT on own referral_codes, referrals, referral_rewards → allowed

### 7. RPC idempotency
- [ ] apply_referral_code with same referred_id twice → second returns already_used, no duplicate row
- [ ] grant_referral_rewards for already-rewarded referral → returns no_pending, no duplicate rewards

### 8. Signup with referral code (no immediate rewards)
- [ ] User B signs up with User A's code in Step 1
- [ ] Success: "Referral applied. Rewards unlock when you reach 500 XP!"
- [ ] User B does NOT get +250 XP yet; User A does NOT get +500 XP yet

### 9. Milestone triggers rewards (Option A: Postgres trigger)
- [ ] User B completes quests until total_xp >= 500
- [ ] Verify both users get rewards; Refer a Friend page shows correct counts

### 10. Option B: Flutter grant_referral_rewards
- [ ] If XP comes from non-triggered source, call `referralRepo.grantReferralRewards()` when total_xp >= 500 detected client-side

### 11. Deep link → signup → reward end-to-end
- [ ] Open cotrainr://invite?code=XXX (or https://www.cotrainr.com/invite?code=XXX)
- [ ] App opens, navigates to Create Account with code pre-filled
- [ ] Complete signup
- [ ] Referral applied; PendingReferralService cleared
- [ ] Reach 500 XP (complete quests)
- [ ] Both users receive rewards

### 12. No double apply (manual + deep link)
- [ ] Deep link stores code; user also manually enters same code → only one apply
- [ ] _referralApplied guard prevents double apply
