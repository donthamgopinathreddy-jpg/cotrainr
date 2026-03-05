# Quest Page End-to-End Audit Report

**Date:** 2025-02-15  
**Scope:** Quest page UI/UX, data flow, navigation, security, DB model  
**Constraint:** No code changes — report only

---

## Section A: What the Quest Page Currently Does

### Structure
- **Main page:** `lib/pages/quest/quest_page.dart` — `QuestPage` (ConsumerStatefulWidget)
- **Layout:** Column with header row, XP hero (level badge + progress bar), 5 icon tabs (Daily, Weekly, Challenges, Achievements, Leaderboard), `PageView` with 5 sections
- **Data sources:** Riverpod providers → `QuestRepository` → Supabase tables/RPCs

### Data Flow
| Data | Source | Provider | File:Line |
|------|--------|----------|-----------|
| Daily quests | `user_quests` + `quests` + RPC `allocate_daily_quests` | `dailyQuestsProvider` | quest_provider.dart:19, quest_repository.dart:20-188 |
| Weekly quests | `user_quests` + `quests` + RPC `allocate_weekly_quests` | `weeklyQuestsProvider` | quest_provider.dart:31, quest_repository.dart:196-345 |
| Challenges | `challenges` + `challenge_members` + `challenge_progress` | `activeChallengesProvider` | quest_provider.dart:43, quest_repository.dart:387-348 |
| Achievements | `achievements` + `user_achievements` | `achievementsProvider` | quest_provider.dart:55, quest_repository.dart:430-469 |
| Leaderboard | RPC `get_leaderboard` | `dailyLeaderboardProvider` | quest_provider.dart:67, quest_repository.dart:462-486 |
| User XP | `user_profiles.total_xp` (fallback `xp`) | `userXPProvider` | quest_provider.dart:84, quest_provider.dart:89-98 |
| User level | `user_profiles.level` | `userLevelProvider` | quest_provider.dart:105, quest_provider.dart:110-117 |
| XP for next level | RPC `get_xp_for_next_level` | `xpForNextLevelProvider` | quest_provider.dart:123, quest_provider.dart:134-145 |

### Level/XP Calculation
- **Level:** Stored in `user_profiles.level` (1–50). Not computed client-side.
- **XP:** Stored in `user_profiles.total_xp`. Updated server-side by `claim_quest_rewards` RPC.
- **Client level display:** Uses `buildQuestLevels()` from `shared_levels.dart` — 50 levels, XP formula `xp += step; step = (step * 1.12).clamp(100, 1200)` (lib/widgets/quest/shared_levels.dart:111-127).
- **Level title:** `_getLevelTitle(level)` in quest_page.dart returns Foundation/Rising/Advanced/Elite/Master (lines 82-88) — **mismatch** with shared_levels tier names (Rookie, Challenger, Pro, Elite, Legendary).

### Badges
- **Storage:** Bundled SVG assets under `assets/badges/` (badge_bronze.svg, badge_silver.svg, badge_gold.svg, badge_platinum.svg, badge_diamond.svg).
- **Mapping:** `getBadgePathFromLevel(level)` in shared_levels.dart:134-145 — tier index from level, no DB/URL.
- **Rendering:** `SvgPicture.asset()` — no caching layer; Flutter caches assets by default.

### Quest Completion
- **Progress:** Updated via RPC `update_quest_progress` (quest_repository.dart:356-365). Sync service (`QuestProgressSyncService`) pushes metrics → quest progress (quest_progress_sync_service.dart:42-136).
- **Claim:** RPC `claim_quest_rewards` (quest_repository.dart:369-376). **No Claim button in UI** — quest cards show "Completed" when `canClaim` is true but have no tap/CTA to call `claimQuestRewards` (quest_page.dart:916-935).

### Date/Time
- **Time left:** `_formatTimeLeft()` in quest_repository.dart:507-518 — uses `DateTime.now()` (device local).
- **Leaderboard period:** `periodStart` passed as `now` for daily (quest_provider.dart:69) — no explicit timezone.
- **Streak / "today" boundary:** Not found in Quest page; streak logic lives in streak_card_v2.dart / daily_streak_card.dart.

---

## Section B: UI/UX Issues

| Issue | Severity | File:Line |
|-------|----------|-----------|
| No Claim button on completed quests — user cannot claim rewards | **High** | quest_page.dart:916-935 (_QuestCard) |
| Daily/Weekly sections: no empty state when quests list is empty | **Medium** | quest_page.dart:416-438 (_DailySection), 440-466 (_WeeklySection) |
| Challenges: has empty state; Daily/Weekly do not | **Low** | quest_page.dart:459-486 (_ChallengesSection) |
| Loading: blocking `CircularProgressIndicator` for all 5 tabs; no skeleton/shimmer | **Medium** | quest_page.dart:232-254 |
| Error state: providers catch errors and return `[]`; no error UI, retry, or snackbar | **High** | quest_provider.dart:24-27, 34-38, 46-50, 58-62, 76-79 |
| Help button (header) has no action — `onHelpTap` only triggers haptic | **Low** | quest_page.dart:191-192, 302-327 |
| Level title mismatch: `_getLevelTitle` (Foundation/Rising/Advanced/Elite/Master) vs shared_levels (Rookie/Challenger/Pro/Elite/Legendary) | **Medium** | quest_page.dart:82-88 vs shared_levels.dart:79, 118 |
| Tier color mismatch: quest_page `_tierColorForLevel` has tier4/tier5 swapped vs shared_levels | **Medium** | quest_page.dart:2561-2568 vs shared_levels.dart:76-77 |
| Leaderboard: `CircleAvatar` placeholder — avatarUrl not used | **Low** | quest_page.dart:1011 |
| No accessibility: no semantic labels, Semantics, or minimum touch target checks | **Medium** | quest_page.dart (throughout) |
| Background color hardcoded `0xFFFFF5EB` for light mode — not from design tokens | **Low** | quest_page.dart:184 |
| Typography: mix of GoogleFonts.poppins, montserrat; inconsistent with rest of app | **Low** | quest_page.dart:273-296, 294 |

---

## Section C: Technical Risks

| Risk | Impact | File:Line |
|------|--------|-----------|
| `Future.delayed` in build: every rebuild when `dailyQuestsAsync.hasValue` schedules a new 15s timer; no cleanup; can cause multiple syncs and memory leak | **High** | quest_page.dart:117-123 |
| `print()` for errors — no user feedback, errors swallowed | **Medium** | quest_provider.dart:25, 36, 48, 60, 77; quest_repository.dart:28, 32, 62-78; quest_progress_sync_service.dart:54, 64, 127, 132 |
| `quest_repository.dart` uses `print` for debug logs — should be removed or use proper logging | **Low** | quest_repository.dart:28, 62-78, 206, 239 |
| Quest sync: `triggerSync` called on every page load; no debounce on rapid navigations | **Medium** | quest_page.dart:53-73, 58-61 |
| `xpForNextLevelProvider` fallback: `(100 * (1.15 * (level - 1))).round()` may not match server RPC | **Low** | quest_provider.dart:144 |
| `user_profiles` column: `total_xp` vs `xp` — provider checks both; migration may leave some rows with only `xp` | **Low** | quest_provider.dart:96-97 |

---

## Section D: Performance Concerns

| Concern | File:Line |
|---------|-----------|
| `PageView` with 5 children — all built even when not visible; no `AutomaticKeepAliveClientMixin` or lazy loading | quest_page.dart:225-254 |
| `GridView.builder` with `shrinkWrap: true` + `NeverScrollableScrollPhysics` in WeeklySection — builds all items; acceptable for small lists | quest_page.dart:441-458 |
| `SingleChildScrollView` with `Column` in DailySection — no `ListView.builder`; all quest cards built at once | quest_page.dart:416-438 |
| `_ContinuousLevelBar` and `_MedalBadgePainter` — complex Canvas operations; no `RepaintBoundary` | quest_page.dart:932-1025, 1589-2095 |
| Level badge: `SvgPicture.asset` per card — asset loading; Flutter caches, but no explicit precaching | quest_page.dart:1151-1158 |
| Sync on page load + periodic 15s timer — can cause unnecessary rebuilds on low-RAM devices | quest_page.dart:53-73, 117-123 |

---

## Section E: DB & RLS Audit Summary

### Tables Used
| Table | RLS | Policies | Notes |
|-------|-----|----------|-------|
| `user_quests` | Yes (complete_safe_migration) | "Users can manage own quests" (auth.uid() = user_id) | quest_repository reads via .from().select().eq('user_id') |
| `quests` | Yes | "Anyone can view quests" (authenticated, is_active) | quest_repository joins via quest_definition_id |
| `user_profiles` | Yes | (implied from complete_safe_migration) | user_profiles read for XP/level |
| `achievements` | Yes | "Anyone can view achievements" | |
| `user_achievements` | Yes | "Users can manage own achievements" | |
| `challenges` | Yes | "Anyone can view active challenges" | |
| `challenge_members` | Yes | View + join policies | |
| `challenge_progress` | Yes | View + update own | |

### RPCs (SECURITY DEFINER)
| RPC | Enforces | File |
|-----|----------|------|
| `allocate_daily_quests` | p_user_id passed; no auth.uid() check in params — uses passed user_id | 20250127_complete_quest_system.sql |
| `allocate_weekly_quests` | Same | 20250127_complete_quest_system.sql |
| `update_quest_progress` | `user_id = auth.uid()` in WHERE | 20250127_complete_quest_system.sql:936 |
| `claim_quest_rewards` | `user_id = auth.uid()` in WHERE | 20250213_fix_claim_quest_rewards_xp.sql |

**Risk:** `allocate_daily_quests` and `allocate_weekly_quests` accept `p_user_id` — if caller passes another user's ID, could allocate quests for that user. **Verify:** RPCs are invoked with `userId` from `auth.currentUser?.id` (quest_repository.dart:26, 204). Client-side only; a malicious client could bypass and call with different ID. **Mitigation:** RPCs should enforce `p_user_id = auth.uid()` in function body.

### Indexes
| Table | Index | Migration |
|-------|-------|-----------|
| user_quests | idx_user_quests_user_id, idx_user_quests_type, idx_user_quests_expires_at, idx_user_quests_assigned_at, idx_user_quests_status | complete_quest_system.sql:498-500, complete_safe_migration:518-519 |
| quests | idx_quests_type, idx_quests_active, idx_quests_category | complete_quest_system.sql:332-334 |
| achievements | idx_achievements_category | complete_quest_system.sql:389 |
| user_achievements | idx_user_achievements_unlocked | complete_quest_system.sql:349 |

**Missing:** `user_quests(user_id, status, completed_at)` composite for "my completed quests" — not critical for current queries.

---

## Section F: Must-Fix Before Shipping vs Can-Ship

### Must-Fix Before Shipping
1. **Add Claim button** — Completed quests must allow user to claim rewards (quest_page.dart:916-935).
2. **Fix Future.delayed in build** — Remove or move to initState with proper lifecycle; avoid scheduling in build (quest_page.dart:117-123).
3. **Error handling** — Show error UI or snackbar when providers fail; do not silently return `[]` (quest_provider.dart:24-79).
4. **Verify allocate RPCs** — Ensure `allocate_daily_quests` and `allocate_weekly_quests` enforce `p_user_id = auth.uid()` server-side.

### Can-Ship (Lower Priority)
1. Empty states for Daily/Weekly when no quests.
2. Skeleton/shimmer instead of blocking spinner.
3. Level title and tier color consistency (shared_levels vs quest_page).
4. Help button implementation.
5. Leaderboard avatar display.
6. Accessibility improvements.
7. Remove or gate debug `print` statements.

---

## Section G: Verification Checklist (Manual Test Cases)

### Happy Path
- [ ] Open Quest page from home shell (tab 3).
- [ ] Daily tab shows quests with progress bars.
- [ ] Weekly tab shows quests in grid.
- [ ] Level badge and XP bar reflect user_profiles data.
- [ ] Tapping level badge opens LevelsPage.
- [ ] Challenges tab shows empty state or active challenges.
- [ ] Achievements tab shows grid.
- [ ] Leaderboard tab shows entries.

### Claim Flow (Currently Broken)
- [ ] Complete a quest (progress >= max).
- [ ] Verify "Completed" appears.
- [ ] **Expected:** Claim button to appear; tap to claim. **Current:** No Claim button.

### Error Scenarios
- [ ] Turn off network; open Quest page — verify error UI or message (currently may show empty).
- [ ] Invalid/expired session — verify graceful handling.

### Edge Cases
- [ ] First-time user (no quests allocated) — verify allocate RPC runs and quests appear.
- [ ] User with 0 XP — verify level 1 and correct next XP.
- [ ] User at level 50 — verify no overflow in level display.

### Navigation
- [ ] Deep link to `/quest` — not found (route is `/home/quest` under shell).
- [ ] Back from Quest — returns to previous shell tab.
- [ ] Streak card "View Quests" → navigates to Quest (streak_card_v2.dart:44, daily_streak_card.dart:23).

### Consistency
- [ ] Level 1–10: badge bronze, tier "Rookie".
- [ ] Level 31–40: badge platinum, tier "Elite".
- [ ] Level 41–50: badge diamond, tier "Legendary".
- [ ] **Known bug:** quest_page tier colors for 31–40 vs 41–50 may be swapped.

---

## Appendix: File Reference Summary

| File | Purpose |
|------|---------|
| lib/pages/quest/quest_page.dart | Main Quest page UI |
| lib/providers/quest_provider.dart | Riverpod providers |
| lib/repositories/quest_repository.dart | Data layer |
| lib/services/quest_progress_sync_service.dart | Metrics → quest sync |
| lib/widgets/quest/shared_levels.dart | Level definitions, LevelsPage, badge paths |
| lib/pages/home/home_shell_page.dart | Shell with Quest tab |
| lib/router/app_router.dart | Route `/quest` (standalone) |
| supabase/migrations/20250127_complete_quest_system.sql | Schema, RLS, RPCs |
| supabase/migrations/20250127_complete_safe_migration.sql | user_quests RLS |
| supabase/migrations/20250213_fix_claim_quest_rewards_xp.sql | claim_quest_rewards fix |
