# Recurly - Development Status

**Last Updated**: 2026-02-25
**Current Phase**: 5.5 - Advanced Analytics (Complete)

---

## Current State Summary

Phases 1-5.5 are complete. The app now has:
- Firebase Authentication (Google, Email/Password, Apple Sign-In)
- Cloud Firestore sync (bidirectional, offline-first, all signed-in users)
- Household sharing (create/join with invite codes, max 2 members)
- Per-subscription splitting with custom percentages
- Spend view toggling (My Share vs Household Total)
- Clear All Data feature in settings
- Currency auto-detection and conversion for household spend views
- 8 advanced analytics features (see Phase 5.5 section below)

**Firestore rules need to be redeployed after changes. All code uncommitted.**

---

## Phase 5.5 — Advanced Analytics (2026-02-25)

### New Files Created

| File | Feature |
|------|---------|
| `lib/widgets/analytics/subscription_count_chart.dart` | F1 — 12-month line chart of active sub count |
| `lib/widgets/analytics/price_changes_section.dart` | F2 — Summary banner + individual price change cards |
| `lib/widgets/analytics/cancel_simulator_sheet.dart` | F3 — Bottom sheet showing savings if cancelled |
| `lib/widgets/analytics/monthly_comparison_chip.dart` | F4 — Delta badge in hero stats |
| `lib/widgets/analytics/renewal_forecast_timeline.dart` | F5 — Horizontal 30-day timeline |
| `lib/widgets/analytics/budget_gauge.dart` | F6 — Circular arc gauge with animated fill |
| `lib/widgets/analytics/split_savings_card.dart` | F7 — Split savings insight card |
| `lib/widgets/analytics/who_pays_more_bar.dart` | F8 — Comparison bar (you vs partner) |

### Modified Files

| File | Changes |
|------|---------|
| `lib/providers/analytics_providers.dart` | Added 6 providers + 4 data classes (MonthlyComparison, UpcomingRenewal, SplitSavings, HouseholdSpendComparison, SubscriptionCountData) |
| `lib/screens/analytics_screen.dart` | Added 8 imports, inserted all 8 widgets into overview tab |
| `lib/models/subscription.dart` | Added `priceHistory` (HiveField 21) with computed helpers |
| `lib/widgets/add_subscription_sheet.dart` | Fixed edit flow (was dropping fields), added price change detection |
| `lib/widgets/analytics/category_detail_sheet.dart` | Added cancel simulator tap handler |
| `lib/services/export_service.dart` | Added price history to CSV column and PDF section |
| `lib/theme/app_theme.dart` | Balanced chart colors, sleeker pie chart (thinner segments, larger center) |

### Analytics Overview Tab Layout (Final)

1. Hero Stats (with Monthly Comparison Chip inside) — F4
2. Budget Gauge — F6 (self-hides if no budget)
3. Projected Spending (bar chart)
4. Subscription Growth (line chart) — F1
5. Spending by Category (pie chart)
6. Price Changes (cards) — F2
7. Upcoming Renewals — F5
8. Household Spending / Who Pays More — F8 (self-hides if no household)
9. Insights (most expensive, top category, Split Savings — F7)
10. Cancel Simulator — F3 (triggered via tap on subscriptions in category detail)

### Self-Hiding Widgets
- Budget Gauge: hidden when `budgetUsageProvider` returns null (no budget set)
- Split Savings Card: hidden when `splitSavingsProvider` returns null (no household or no splits)
- Who Pays More Bar: hidden when `householdSpendComparisonProvider` returns null (no household)

---

## Bug Fix Session 3 (2026-02-25)

### Overview
Continued end-to-end testing on two physical Android devices. Fixed critical bugs in disband, sync, currency, and household total calculation.

### Bugs Found & Fixed

| # | Bug | Root Cause | Fix | Status |
|---|-----|-----------|-----|--------|
| 1 | Disband household silently fails | `_cleanupSplits()` tried to `.get()` (list) partner's Firestore collections, but rules only allow reading own data. The entire disband failed with permission denied. | Changed to `cleanupOwnSplitData(uid)` — each user only cleans their own data. Partner self-cleans via `householdCleanupProvider`. | **Fixed** |
| 2 | Partner subs never appear in Household Total view | `initializeHouseholdSync` listener queried entire `subscriptions` collection without `.where()`. Firestore rules only allow reading `householdVisible == true` docs, so the listener failed silently for any non-visible doc. | Added `.where('householdVisible', isEqualTo: true)` to the Firestore query so it matches the security rules. | **Fixed** |
| 3 | Household total would double-count split subscriptions | `_convertedHouseholdTotal` counted all own subs + all partner subs. Reference subs (created on split accept) would be counted alongside the original, inflating the total. | Skip reference subs in own list (`ownerUid != currentUid`), skip partner's references back to us (`ownerUid == currentUid`). | **Fixed** |
| 4 | Split updates not propagating between devices (5 sub-bugs) | (a) `_onRemoteDataChanged` callback never wired up, (b) `acceptSplit` missing `updatedAt`, (c) reference sub not saved to partner's Hive, (d/e) UI not refreshing after propose/accept | Wired up callback in SubscriptionNotifier; added `updatedAt` to Firestore update; save reference sub to Hive; added `loadSubscriptions()` calls after propose/accept | **Fixed** |
| 5 | Sync not initializing after sign-in (only on cold start) | Sync only ran in `main()`. If user signed in while app was running, sync never started. | Added reactive `syncInitProvider` that watches `currentFirebaseUserProvider` | **Fixed** |
| 6 | Sync gated behind Pro — free users got nothing from signing in | `isSyncEnabledProvider` checked `isSignedIn && isPro` | Changed to just `isSignedIn`. All signed-in users get sync. | **Fixed** |
| 7 | Currency shows USD when all subs are INR | Auto-detect only checked if saved currency was `'USD'`, user had EUR | Changed to check if display currency matches ANY subscription currency | **Fixed** |
| 8 | Currency conversion not applied, just symbol swap | `myShareSpendProvider` and `householdTotalSpendProvider` didn't convert currencies | Added `_convertedMyShare()` and `_convertedHouseholdTotal()` helpers with proper `CurrencyService.convert()` calls | **Fixed** |
| 9 | Exchange rates not fetched after sync | Rates only fetched during `CurrencyService.initialize()` at cold start | Added `CurrencyService().getRates()` in `syncInitProvider` after sync completes, with `ref.invalidate(exchangeRatesProvider)` | **Fixed** |

### Files Modified This Session (2026-02-25)

| File | Changes |
|------|---------|
| `lib/services/household_service.dart` | Replaced `_cleanupSplits(members)` with public `cleanupOwnSplitData(uid)` — only reads/cleans caller's own data |
| `lib/services/sync_service.dart` | Added `.where('householdVisible', isEqualTo: true)` to household listener query; wired up `_onRemoteDataChanged` |
| `lib/services/split_service.dart` | Added `updatedAt` to `acceptSplit` Firestore update; save reference sub to partner's local Hive |
| `lib/providers/household_providers.dart` | Enhanced `householdCleanupProvider` to also clean split data, local Hive, stop sync, and reload subs |
| `lib/providers/subscription_providers.dart` | Wired up `_onRemoteDataChanged` callback in SubscriptionNotifier constructor |
| `lib/providers/sync_providers.dart` | Added `syncInitProvider` (reactive sync init); changed `isSyncEnabledProvider` to all signed-in users |
| `lib/providers/currency_providers.dart` | Updated auto-detect to check if display currency matches any subscription currency |
| `lib/screens/home_screen.dart` | Added `_convertedMyShare()` and `_convertedHouseholdTotal()` with currency conversion and reference sub filtering; watches sync/cleanup providers |
| `lib/screens/settings_screen.dart` | Implemented "Clear All Data" feature with two-step confirmation dialog |
| `lib/screens/household_screen.dart` | Added `_clearLocalSplitData()` for Hive cleanup after disband/leave |
| `lib/widgets/split_subscription_sheet.dart` | Added `loadSubscriptions()` after `proposeSplit` |
| `lib/widgets/split_proposal_card.dart` | Added `loadSubscriptions()` after `acceptSplit` |
| `lib/main.dart` | Removed Pro gate from cold-start sync initialization |

### How Disband Works Now (Fixed)
1. Creator calls `disbandHousehold(uid)`:
   - Calls `cleanupOwnSplitData(uid)` — deletes own split_proposals, reference subs, clears splitWith
   - Clears OTHER members' `householdId` first (isHouseholdMember check still passes)
   - Clears creator's own `householdId` last
   - Deletes invite doc and household doc
2. Creator's UI calls `SyncService().disposeHouseholdSync()` + `_clearLocalSplitData()`
3. Partner's device: `householdCleanupProvider` detects household doc gone →
   - Clears stale `householdId` from Firestore profile
   - Calls `cleanupOwnSplitData(uid)` for own Firestore data
   - Clears local Hive splitWith data
   - Stops household sync listener
   - Reloads subscriptions

### How Household Total Works Now (Fixed)
- Own subs: count at full price, **skip reference subs** (ownerUid != currentUid)
- Partner subs: count at full price, **skip references back to us** (ownerUid == currentUid)
- Both devices show the same total (all original subscriptions combined)

---

## Test Checklist (Resume Here)

**IMPORTANT: Copy updated Firestore rules from `firestore.rules` into Firebase Console manually**

Current test setup: Pro device (Netflix 100 INR, Google 200 INR), Free device (Vercel 100 INR), Google split 50%.

- [x] **Test 1-3: Auth, Cloud Sync, Sync Indicator** — verified working
- [x] **Test 4: Household Creation** — Pro device creates household, gets invite code
- [x] **Test 5: Join Household** — Free device joins with code, both show 2 members
- [ ] **Test 6: Partner Sub Visibility** — Household Total tab should show partner's subs with "Partner's Subscriptions" header
- [ ] **Test 7: Spend View Toggle** — My Share: 200 on both. Household Total: 400 on both.
- [x] **Test 8: Propose Split** — Pro device sends split proposal for Google (50%)
- [x] **Test 9: Accept Split** — Free device accepts, reference sub appears, My Share correct on both
- [ ] **Test 10: Disband** — Pro disbands → both devices clean up:
  - No household shown
  - No partner subs
  - Spend view resets to "My Share"
  - Split badge disappears
  - No ghost reference subs
  - Local Hive splitWith cleared

### Expected Values After Split (for verification)

| View | Pro Device | Free Device |
|---|---|---|
| My Share | ₹200 (Netflix 100 + Google 50%) | ₹200 (Vercel 100 + Google 50%) |
| Household Total | ₹400 (all 3 subs combined) | ₹400 (same) |

---

## Bug Fix Session 2 (2026-02-24)

### Bugs Found & Fixed

| # | Bug | Root Cause | Fix | Status |
|---|-----|-----------|-----|--------|
| 1 | Partner subs never show in "Household Total" | Old docs lacked `householdVisible` field | Added `_backfillHouseholdVisible()`, client-side filter | **Fixed** |
| 2 | Disband doesn't propagate to partner device | Firestore rules blocked cross-user writes | Added `allow update` for `isHouseholdMember`; changed disband order; added `householdCleanupProvider` | **Fixed** |
| 3 | Keyboard overflow in Create Household dialog | Dialog TextField not wrapped | Wrapped in `SingleChildScrollView` | **Fixed** |
| 4 | Split proposals always show `$` | No currency field in SplitProposal model | Added `currency` field + `currencySymbol` getter | **Fixed** |
| 5 | Accept split does nothing | Firestore rules blocked partner updates | Added `allow update` for household members on subscriptions | **Fixed** |
| 6 | Spend view stuck on "Household Total" after disband | Provider not reset | Added auto-reset when `!isInHousehold` | **Fixed** |

---

## Previous Sessions Summary

### Phase 5 Implementation (2026-02-23)
- Implemented all 6 sub-phases in a single session (5.1-5.6)
- 22 new files, 12 modified files
- Firebase project configured, Firestore rules deployed

### Phase 4.5 Sessions (Jan 2025)
- Multi-currency, budgets, custom categories, themes, trial tracking, Android widget

### Phase 4 Session (Jan 2025)
- Analytics, bottom navigation, warm modern theme

### Phase 3 Session (Jan 2025)
- Local notifications with timezone support

### Phase 2 Session (Jan 2025)
- Search, templates, pull-to-refresh, local logos

### Phase 1 Session (Jan 2025)
- Core CRUD, Material 3 UI, Hive storage

---

## Known Issues / Next Steps

### Immediate
1. **Complete end-to-end testing** — Tests 6, 7, 10 still need verification after rebuild
2. **Verify all 8 analytics features on device** — especially household-dependent ones (F7, F8)
3. **Deploy updated Firestore rules** — Copy `firestore.rules` into Firebase Console
4. **Commit all code** — Phases 5 + 5.5 still uncommitted
5. **Apple Sign-In setup**: Requires Apple Developer account (not blocking Android)

### Future Phases
- **Phase 6**: Monetization (RevenueCat, Free/Pro tiers)
- **Phase 7**: iOS launch

---

## Quick Commands

```bash
# Run the app
flutter run

# Clean build
flutter clean && flutter pub get && flutter run

# Build debug APK
flutter build apk --debug

# Analyze for errors
flutter analyze lib/

# Regenerate Hive adapters (if model changes)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Key Architecture Notes

### Sync Pipeline
- Hive is always source of truth
- Firestore sync for all signed-in users (not just Pro)
- Remote listener updates Hive on changes from other devices
- Conflict resolution: last-write-wins based on `updatedAt`
- Partner subs held in-memory only (ValueNotifier), not in Hive
- `syncInitProvider` reactively initializes sync when user signs in
- Exchange rates fetched after sync completes

### Household System
- Max 2 members per household
- Pro required to create, anyone can join
- 6-char invite code, 48-hour expiry
- Creator can disband, member can leave
- Each user cleans only their own data on disband/leave
- Partner self-cleans via `householdCleanupProvider` (detects household doc deletion)

### Split System
- Owner proposes split with custom percentage (10-90%)
- Partner receives proposal, can accept or reject
- On accept: reference sub created in partner's Firestore + local Hive
- Owner's "My Share" shows reduced amount
- Household Total skips reference subs to avoid double-counting
- `cleanupOwnSplitData()` removes proposals, reference subs, and splitWith on disband
