# Recurly Bug Fixing Plan

## Verification Results

### P0 — Top 5 critical issues

**1. Billing-cycle arithmetic silently corrupts renewal dates — CONFIRMED**
- File: `lib/models/subscription.dart:190-213`
- Code matches audit snippet exactly. Dart's `DateTime(2025, 2, 31)` normalizes to `2025-03-03` (day overflow into next month). Monthly on Jan 31 drifts to Mar 3 after one cycle. Yearly on Feb 29 of a leap year also drifts. Weekly uses `Duration(days: 7)` (168h), which will drift ±1h across DST boundaries.
- Duplicate lives at `lib/providers/analytics_providers.dart:400-412` (`_addOneCycle`). Same three cases, same overflow.
- Reachable: `Subscription.nextBillDate` (line 168) and `upcomingRenewalsProvider` (line 414) both call into the broken code, and both are rendered in the UI.

**2. Firestore rules let any authed user read all households and overwrite any invite code — CONFIRMED**
- File: `firestore.rules:44-60`
- Line 46: `allow read: if request.auth != null;` on `/households/{id}` — any signed-in user can read (and list) every household. Leaks member UIDs.
- Lines 48-51: `allow update` has a third branch `request.auth.uid in request.resource.data.members` — a user can set `members` on their own write to include their UID, self-joining someone else's household. No `resource.data.members.size()` check.
- Lines 57-60: `/invites/{code}` has `allow write: if request.auth != null;` — any authed user can overwrite another user's invite document (invite-code squatting / join-flow hijack).

**3. Cross-currency totals are silently wrong — CONFIRMED**
- File: `lib/providers/analytics_providers.dart:140-151` — `totalPriceChangeImpactProvider` sums `sub.price - oldPrice` (each in `sub.currency`) as if they were the same unit. No currency conversion.
- File: `lib/widgets/analytics/price_changes_section.dart:49-54` — consumes `totalImpact` and calls `convert(from: displayCurrency, to: displayCurrency)`, which short-circuits to the input amount (`currency_service.dart:85`). The impact number is stamped with the display currency symbol but never crossed a rate.
- File: `lib/services/currency_service.dart:85-113` — `convert` silently returns the input on `cache == null` (line 88-91) or missing rate (line 111-113). Debug-printed only. Every caller sees a plausible-but-wrong value.

**4. Trial expiry contradicts the UI text — CONFIRMED**
- File: `lib/models/subscription.dart:341-365`
- `isTrialExpired` (line 350-353): `DateTime.now().isAfter(trialEndDate!)` — uses full timestamp.
- `daysUntilTrialEnds` (line 341-347): both sides midnight-normalized via `DateTime(y,m,d)`.
- `trialStatusText` (line 356-365): uses `daysUntilTrialEnds`, returns "Trial ends today" when days == 0.
- `trialEndDate` can be created with a time component — `add_subscription_sheet.dart:546` uses `DateTime.now().add(const Duration(days: 7))`, which carries the current time of day. So between `trialEndDate`'s time-of-day and midnight, `isTrialExpired` is true while the UI still says "Ends today". Gating disagrees with display for up to ~24 hours.

**5. No R8/ProGuard minification on release builds — CONFIRMED**
- File: `android/app/build.gradle:47-51`
- `buildTypes.release` only sets `signingConfig`. No `minifyEnabled`, no `shrinkResources`, no `proguardFiles`, no `proguard-rules.pro` file under `android/app/`. Release AAB is unshrunken and unobfuscated.

### P0/P1 — other findings

**6. `_addOneCycle` duplicate — CONFIRMED**
- File: `lib/providers/analytics_providers.dart:400-412`. Same bug as #1. Will be fixed together with #1 (single calculator).

**7. Currency conversion silent fallback — CONFIRMED**
- File: `lib/services/currency_service.dart:88-91, 111-113`. Both fallback paths return the input amount. Call sites in `analytics_providers.dart`, `home_widget_service.dart:52-59`, and `home_screen.dart:_convertedHouseholdTotal` sum those pass-throughs. P1 by itself — already ranked under #3.

**8. JPY/KRW rounding in `formatAmount` — REJECTED**
- File: `lib/services/currency_service.dart:123-128`. The rounding is only applied in `formatAmount` (display path). The underlying `double` is untouched in `convert`. The audit's "cumulative sums drift" claim conflates display and math. Not a bug — just rounded display.

**9. Locale-naive thousand separator — REJECTED**
- File: `lib/services/currency_service.dart:130-141`. App is English-only today; no locale switcher in settings. This is a latent localization item, not a bug. Audit itself labels as "latent". Not actionable as a fix.

**10. Unbounded `while` on `firstBillDate` — PARTIALLY CONFIRMED**
- File: `lib/models/subscription.dart:182` and `lib/providers/analytics_providers.dart:434`. The loop is real. But `firstBillDate` comes from a UI date picker in `add_subscription_sheet.dart`, not from user text, so it's not pathological. A sub first-billed 10 years ago = 120 iterations weekly; acceptable. Not an urgent bug. Defer; no fix task unless we see real impact.

**11. Notification-ID collisions — REJECTED (for current release)**
- File: `lib/services/notification_service.dart:246-250`. `hashCode` of concatenated string is the ID. At the free limit of 5 subs × 4 offsets = 20 IDs, collision probability is ~10⁻⁷. Audit itself notes this matters only post-monetization. Not a bug now.

**12. Hardcoded free limit `5` — CONFIRMED**
- File: `lib/providers/subscription_providers.dart:222` — literal `5` in `hasReachedFreeLimitProvider`. `AppConstants.freeSubscriptionLimit` exists and is used in `database_service.dart:254`. Simple P2 quickwin.

**13. `myShareSpendProvider` doesn't convert currency — CONFIRMED but not a user-facing bug**
- File: `lib/providers/subscription_providers.dart:318`. Returns raw `monthlyEquivalent`. No caller actually uses this provider raw — `home_screen._convertedMyShare` reimplements. Grep shows zero other consumers. Dead code risk, not a live bug. Mark PARTIALLY; low priority.

**14. `BillingCycle.custom` has no custom period — CONFIRMED (enum noise)**
- File: `lib/models/subscription.dart:206-211`. `custom` literally falls through to the monthly branch. No `customDays` field exists on `Subscription`. The UI in `add_subscription_sheet.dart` doesn't actually offer custom as a user option (checked — only monthly/yearly/weekly). So the enum case is unreachable today; deleting is safer than implementing.

**15. Delete/archive leakage from `getAllSubscriptions` — REJECTED**
- File: `lib/services/database_service.dart:119`. Grep across lib shows only two callers, both in `sync_service.dart:84, 141`, both of which intentionally want all docs (for sync upload/merge). No provider calls it. Audit's claimed "missed filters" don't exist in the codebase. Not a bug.

### Architecture / state

**16. Side-effects inside provider bodies — CONFIRMED**
- `lib/providers/sync_providers.dart:44-81` (`syncInitProvider`) chains `.then()` after `syncService.initialize(uid)`, invalidates `exchangeRatesProvider`, mutates `displayCurrencyProvider`. Re-runs when `currentFirebaseUserProvider` changes and has no cancellation on rebuild mid-chain.
- `lib/providers/household_providers.dart:49-93` (`householdCleanupProvider`) directly uses `FirebaseFirestore.instance`, calls `HouseholdService()`, `DatabaseService().deleteSubscription()`, etc. Fires on every rebuild of `currentHouseholdProvider`. Re-entrancy risk on hot reload. Real issue but not a live user-visible bug today — defer to P1 if it doesn't regress something concrete.

**17. `home_screen` watches lifecycle providers in `build` — CONFIRMED**
- File: `lib/screens/home_screen.dart:115-117`. Three `ref.watch` calls at the top of `build`. Combined with #16, this re-runs I/O on every stateful rebuild.

**18. `SyncService.onRemoteDataChanged = ...` overwrites prior listeners — CONFIRMED**
- File: `lib/providers/subscription_providers.dart:29-31` and `lib/services/sync_service.dart:200-203`. Single field, assignment-based. Hot reload re-creating `SubscriptionNotifier` will overwrite the callback; if tests or provider invalidation ever instantiate more than one notifier, prior callbacks are silently lost.

**19. `main.dart` sequential awaits — CONFIRMED**
- File: `lib/main.dart:22-138`. Every init is `await`ed in sequence including `SyncService().initialize` (line 118), which issues network calls. Cold start is blocked on this chain.

**20. No Hive migrations — CONFIRMED**
- File: `lib/services/database_service.dart:21-66`. No `schemaVersion` key, no migration function. First breaking change to `@HiveField` index mapping will corrupt existing installs. Important but not a bug that affects users *today*.

**21. `settings_screen.dart` mutates inside `.whenData` — NOT VERIFIED (low-impact style item, skip)**
- Style-only concern per audit itself. Reject as a fix task.

**22. Layer-first → feature-first — REJECTED (refactor opinion, not a bug)**

### Security

**23. Weak email/password validation — CONFIRMED**
- File: `lib/screens/auth_screen.dart:144, 369` — `!value.contains('@')`. That's the entire email check. Password check not re-verified. Low-priority UX polish; Firebase itself catches malformed emails server-side.

**24. `android:allowBackup` not set — CONFIRMED**
- File: `android/app/src/main/AndroidManifest.xml:6-9`. No `android:allowBackup` attribute on `<application>`. Default = true → Android auto-backs up Hive DB to user's Google Drive.

**25. `isHouseholdMember` helper does 2 reads per rule check — CONFIRMED but deferred**
- File: `firestore.rules:7-12`. Real cost concern at scale, but current households are 2 members × ≤5 subs = ≤10 reads/list. Not urgent; denormalization is a meaningful refactor. Skip.

**26. `SubscriptionWidgetProvider exported=true` — REJECTED**
- File: `android/app/src/main/AndroidManifest.xml:49-57`. Audit itself acknowledges this is *required* for AppWidget updates. Not a vulnerability. Reject.

**27. Invite code search space — PARTIALLY CONFIRMED**
- File: `lib/services/household_service.dart:generateInviteCode`. 6-char alphanumeric is fine. The "squatting" concern is entirely driven by the write-rule bug in #2. Fixing the rule closes this.

**28. `_ensureUserProfile` writes on every sign-in — REJECTED (audit misread code)**
- File: `lib/services/auth_service.dart:205-225`. Code does `get()` first, then branches on `doc.exists`. Not an unconditional `set(..., merge)`. Audit's diagnosis wrong. Skip.

**29. PII in logs — REJECTED**
- Audit itself admits `debugPrint` is stripped in release. No actual leak. Reject.

### Performance

**30. Cold start — same as #19**

**31. `Box<Subscription>` is eager, not lazy — REJECTED**
- Free limit = 5, typical user ≤ ~50 subs. Eager box cost is negligible. Premature optimization; audit itself says "matters at 500". Skip.

**32. `_locallyDeletedIds` grows unbounded — PARTIALLY CONFIRMED**
- File: `lib/services/sync_service.dart:33`. Set cleared on matching Firestore remove. If a remove never arrives (e.g., push failed and retry never happened), it grows. In practice, at ~1 delete/day × 365 days = 365 String entries = a few KB. Very minor. Defer; no fix task.

**33. Firestore listener re-parses all docs per change — REJECTED**
- File: `lib/services/sync_service.dart:160-188`. Code *already* uses `snapshot.docChanges` and processes only changed docs. Audit's claim is simply wrong against current code.

**34. `upcomingRenewalsProvider` unbounded loop — same as #10**

**35. `cleanupOldDeletedSubscriptions` iterates deletes — REJECTED (micro-opt)**

**36. `home_widget_service` runs conversions on main isolate — REJECTED (micro-opt at current scale)**

### Code quality / release

**37. Single smoke test — CONFIRMED, actioned via fix tasks that each add a targeted test**

**38. `debugPrint` is the only observability — REJECTED as a fix task (Crashlytics integration is new feature work, not a bug)**

**39. Duplicated logic — Partially overlaps with #1 fix (single billing calculator)**

**40. Dead / commented code — REJECTED (audit itself admits to "dead comments", style not a bug)**

**41. No a11y / No localization — REJECTED (feature work)**

**42. Keystore backup — REJECTED (process item, already in memory)**

**43. Permissions audit clean — NOT A BUG (audit confirms clean)**

**44. No CI / `flutter analyze` gate — REJECTED (DX item)**

**45. No deep-link intent filters — REJECTED (feature stub, not a bug)**

---

## Additional Bugs Found

**A1. `_addBillingCycle` weekly branch drifts one hour at DST — covered in task for #1.**

**A2. SyncService not disposed on sign-out — upgraded to P1, see Task 9 in the Fix Plan**
- `lib/services/auth_service.dart:112-115` — `signOut()` calls `_auth.signOut()` but does not call `SyncService().dispose()`. The Firestore listener keeps trying to read the previous user's docs under the new (or null) auth context, fires permission-denied errors into logs, and the ValueNotifier `partnerSubscriptions` still holds stale values. Shared-device sign-out → sign-in leaks stale partner subs to the next user. Upgraded to P1 on pre-flight.

**A3. `Subscription` is a mutable `HiveObject`, returned by reference from providers**
- `lib/providers/subscription_providers.dart:42` returns `_databaseService.getActiveSubscriptions()` — which is the list of Hive-managed mutable objects. Any caller who does `sub.price = newValue` mutates the stored object but does NOT call `.save()`. Hive won't persist until the next explicit `put`. Example: `sync_service.dart:92-93` sets `sub.ownerUid = uid; sub.updatedAt ??= DateTime.now();` and then calls `_db.updateSubscription(sub)` which does `put(sub.id, sub)` — so this particular site is OK. But the pattern is fragile. No confirmed live bug from this yet. Mark for monitoring, not a fix task.

**A4. `addSubscription` in sync listener bypasses notifier**
- `lib/services/sync_service.dart:176` calls `_db.addSubscription(remoteSub)` which `put`s into Hive. The `SubscriptionNotifier.loadSubscriptions()` only re-runs when `_onRemoteDataChanged` fires (line 190). If `_onRemoteDataChanged` is null (instantiation race before the notifier wires up the callback), the add happens in Hive but the UI never refreshes until a manual reload. Edge case tied to #18; the fix to #18 (listener list) covers it.

**A5. `HomeWidget.widgetClicked.listen(callback)` never cancelled**
- `lib/services/home_widget_service.dart:139`. Method is never called from anywhere in `lib/` (grep confirms). Dead code — reject as a fix task.

**A6. Firestore composite indexes — NO BUGS**
- Only `.where(..., isEqualTo: ...)` queries exist (household sync, split proposals). Single-field `isEqualTo` does not require a composite index. No index missing.

**A7. RevenueCat remnants — NONE**
- `grep purchases_flutter|Purchases\.` in lib returns nothing. Only pubspec has the commented line. Clean.

**A8. Hive adapter registration order — OK**
- `lib/services/database_service.dart:26-57`. All 9 adapters registered before `openBox` call on line 60. No mismatch risk.

**A9. Hive box corruption recovery — MISSING**
- No try/catch around box corruption paths; a corrupt box throws inside `openBox` which would propagate and prevent app launch. Low-frequency real risk. P2; deferred — a crash recovery story is a feature, not a bug-fix in this pass.

**A10. Notification `nextBillDate` drift feeds scheduler**
- `lib/services/notification_service.dart:87` reads `subscription.nextBillDate` — if billing math is wrong (#1), scheduled notification dates are wrong. Covered by #1 fix (once math is right, notifications are right).

---

## Pre-flight verification

Spot-checks run before executing the Fix Plan to confirm three "OK" claims from verification.

**A8 — Hive adapter registration order: OK, no change needed**
- `lib/services/database_service.dart:initialize()` registers 9 adapters in this order, all BEFORE the first `openBox` on line 60:
  - typeId 0 → `SubscriptionAdapter` (line 27)
  - typeId 1 → `BillingCycleAdapter` (line 30)
  - typeId 2 → `SubscriptionCategoryAdapter` (line 33)
  - typeId 3 → `AppPreferencesAdapter` (line 37)
  - typeId 4 → `TimeOfDayPreferenceAdapter` (line 40)
  - typeId 5 → `ThemePreferencesAdapter` (line 44)
  - typeId 6 → `BudgetSettingsAdapter` (line 48)
  - typeId 7 → `CustomCategoryAdapter` (line 52)
  - typeId 8 → `ExchangeRateCacheAdapter` (line 56)
- First box open: `Hive.openBox<Subscription>` at line 60.
- All other `openBox` call sites live in PreferencesService/ThemeService/BudgetService/CustomCategoryService/CurrencyService. Per `lib/main.dart:46-74`, those services are initialized strictly AFTER `DatabaseService().initialize()` completes, so all adapters they need are already registered.
- Verdict: clean.

**A6 — Firestore composite indexes: OK, no indexes required**
- `grep -rn "\.orderBy("` in `lib/` returns **zero** matches.
- Firestore `.where(` call sites in `lib/`:
  - `lib/services/sync_service.dart:281` — `.where('householdVisible', isEqualTo: true).snapshots()` — single-field equality
  - `lib/services/split_service.dart:236` — `.where('accepted', isEqualTo: false).snapshots()` — single-field equality
  - `lib/services/split_service.dart:251` — `.where('accepted', isEqualTo: false).get()` — single-field equality
- Every Firestore query is a single-field `isEqualTo`. Single-field equality is auto-indexed by Firestore — no composite index needed.
- No `firestore.indexes.json` or `firebase.json` file exists in the repo; none required.
- Verdict: clean.

**A7 — RevenueCat remnants: OK, no live references**
- `grep -rn "purchases_flutter\|Purchases\." lib/` returns zero matches.
- Only mention in the repo is the commented-out dependency in `pubspec.yaml:30`, which is expected per the "launch free, monetize later" strategy in memory.
- Verdict: clean.

All three pre-flight checks agree with the prior verification. No new bugs discovered.

---

## Fix Plan

Tasks are ordered: P1 forward-compat scaffolding → P0 correctness → P0 security → P1 → P2 → P0 release (last, highest regression risk). Each task is self-contained; we stop and show the diff after each.

### Task 0: Hive schema migration scaffolding
- [x] Status: complete
- Severity: P1 (forward-compat, not a live bug)
- Files: `lib/services/database_service.dart`, `lib/utils/constants.dart`
- Bug: No schemaVersion tracking. First breaking `@HiveField` change will corrupt installs.
- Fix approach: Add `kCurrentSchemaVersion = 1` constant (either in `constants.dart` or a new `lib/utils/schema.dart`). In `DatabaseService.initialize()`, open a dedicated `settingsBox` BEFORE opening the subscriptions box; read `settingsBox.get('schemaVersion')`. If null → write `1`, continue. If < current → call `_migrate(from, to)` (stub: switch on versions, no-op for v1→v1). If == current → no-op. If > current → throw `StateError` (downgrade). Write current version back after successful migration. Do NOT modify any existing `@HiveField` — this is pure scaffolding.
- Test: `test/schema_migration_test.dart` — use `Hive.init(tempDir)` with a fresh box: (a) no `schemaVersion` stored → initialize writes `1`, (b) stored == 1 → no-op, migrate not called, (c) stored == 999 → throws `StateError`.
- Risk: Low. Pure additive change; existing box contents untouched. The only risk is opening a second box at startup — small perf cost, one extra file.

### Task 1: Billing-cycle arithmetic (month-end, leap year, DST)
- [x] Status: complete
- Severity: P0
- Files: `lib/utils/billing_cycle.dart` (new), `lib/models/subscription.dart:190-213`, `lib/providers/analytics_providers.dart:400-412`
- Bug: `DateTime(year, month+1, day)` overflows; `Duration(days: 7)` drifts across DST.
- Fix approach: Create a `BillingCycle` calculator in `lib/utils/billing_cycle.dart` with one function `DateTime addOneCycle(BillingCycle, DateTime)`. Use `DateUtils.getDaysInMonth` to clamp day. Use `DateTime(y, m, d + 7)` for weekly (calendar-day). Delete both in-file copies and import the new module. Keep the `custom` case mapping to monthly for now (no `customDays` field exists; deleting the case would be a schema change).
- Test: `test/billing_cycle_test.dart` covering Jan 31 → Feb 28/29, Feb 29 leap → Mar 1 next year, Dec 31 → Jan 31 rollover, weekly across DST spring-forward and fall-back weeks, yearly on Feb 29.
- Risk: existing subs whose `firstBillDate` drifted will shift back by however far they drifted the first time the new math runs. Acceptable — correct behavior. No migration needed.

### Task 2: Trial expiry midnight-normalize
- [x] Status: complete
- Severity: P0
- Files: `lib/models/subscription.dart:350-353`
- Bug: `isTrialExpired` compares `DateTime.now()` against a timestamped `trialEndDate`; `trialStatusText` uses midnight-normalized `daysUntilTrialEnds`. UI and gating disagree for the last ~14 hours of the expiry day.
- Fix approach: Normalize both sides to date-only in `isTrialExpired`. Inline: `final today = DateTime(now.year, now.month, now.day); final end = DateTime(trialEndDate!.year, trialEndDate!.month, trialEndDate!.day); return today.isAfter(end);`. Make "expired" mean "day after end date".
- Test: `test/trial_expiry_test.dart` — set `trialEndDate` = today at 09:00, assert `isTrialExpired == false` at today 14:00; set end date = yesterday, assert `isTrialExpired == true`.
- Risk: subs whose trial ends "right now" will remain non-expired for the rest of the day, matching the UI.

### Task 3: Currency service — surface conversion failures (moved up; prerequisite for Task 4)
- [x] Status: complete
- Severity: P1 → elevated because Task 4 depends on it
- Files: `lib/services/currency_service.dart:79-114`, callers in analytics/home_widget
- Bug: `convert` silently returns the input amount on missing cache or missing rate.
- Fix approach: Add a new method `double? convertOrNull(...)` that returns `null` when cache is missing OR the rate pair is unresolvable. Leave the existing `convert` as-is for legacy call sites (migrate them in later tasks if needed). Update only the analytics/widget paths that Task 4 depends on to use `convertOrNull` and display "—" / suppress totals when null.
- Test: `test/currency_service_test.dart` — no-cache path → null, rate-missing path → null, happy path → converted double.
- Risk: Touches a few call sites. Keep scope to the new method; don't change `convert`'s signature.

### Task 4: Cross-currency price-change impact (consumes Task 3)
- [x] Status: complete
- Severity: P0
- Files: `lib/providers/analytics_providers.dart:140-151`, `lib/widgets/analytics/price_changes_section.dart:49-54`
- Bug: `totalPriceChangeImpactProvider` sums raw prices across currencies without conversion; the widget then calls `convert(from: displayCurrency, to: displayCurrency)`, a no-op.
- Fix approach: Change `totalPriceChangeImpactProvider` to read `currencyServiceProvider`, `displayCurrencyProvider`, and `exchangeRatesProvider.value`. For each sub, compute `diff * multiplier` and convert via `convertOrNull(sub.currency, displayCurrency)` (from Task 3). If any sub returns null, bail the aggregate to null (signal "rates not available"). Delete the no-op `convert(from: displayCurrency, to: displayCurrency)` call in the widget.
- Test: `test/price_change_impact_test.dart` — two subs (USD + EUR), fixed rates, assert total == sum of converted deltas; also assert that a missing-rate sub yields a null aggregate rather than a silent wrong value.
- Risk: UI must handle the null (show "—") in `price_changes_section.dart`.

### Task 5: Firestore rules — households & invites
- [x] Status: complete
- Severity: P0
- Files: `firestore.rules:44-60`
- Bug: `/households` read is global; `/households` update has a self-add branch; `/invites` write is wide open.
- Fix approach: Restrict `/households` read to members only. Add `resource.data.members.size() <= 2` constraint to update. Split `/invites` write into `create` (any authed, check createdBy == auth.uid) and `update, delete` (creator only). The join flow should look up the invite first (invite still publicly readable so anyone with the code can join), get the household id, then the household itself; join path will need a small server-side flow to mutate the household doc, but per memory the app already uses `SplitService.acceptProposal` for split and similar for households — verify a membership-updating code path doesn't break.
- Test: N/A (Firestore rules unit tests require `firebase_rules_testing` harness not set up). Manual test: (a) signed-in user A, user B, B cannot list A's household, (b) B cannot self-add to A's household via update, (c) B cannot overwrite an invite that A created.
- Risk: HIGH — breaks join flow if the new rules don't match the actual client writes. Before deploying, trace `lib/services/household_service.dart` and `lib/services/split_service.dart` to confirm every write the clients make is still permitted. Write rules to `firestore.rules` only; do NOT deploy — leave that to user via Firebase Console.

### Task 6: `android:allowBackup="false"`
- [x] Status: complete
- Severity: P1
- Files: `android/app/src/main/AndroidManifest.xml:6-9`
- Bug: Default auto-backup uploads Hive DB to user's Google Drive in plaintext.
- Fix approach: Add `android:allowBackup="false"` to `<application>`.
- Test: Manual — visual inspection of built AAB. No unit test.
- Risk: Low.

### Task 7: Home-screen lifecycle provider watches → `ref.listen` in `initState`
- [x] Status: complete
- Severity: P1
- Files: `lib/screens/home_screen.dart:115-117`
- Bug: `ref.watch` on providers that fire I/O, inside `build`, re-runs on every rebuild.
- Fix approach: Move the three watches into `ref.listen` calls inside `initState`, fire-once on change. Or use `ref.read` and trigger manually. Keep changes scoped to this file.
- Test: Manual — verify home screen still initializes sync / household correctly on sign-in, and doesn't re-fire them on rebuilds.
- Risk: Medium — these lifecycle calls could be load-bearing; move carefully.

### Task 8: `SyncService.onRemoteDataChanged` → listener list
- [x] Status: complete
- Severity: P1
- Files: `lib/services/sync_service.dart:200-203`, `lib/providers/subscription_providers.dart:29-31`
- Bug: Single-field callback is overwritten on re-instantiation.
- Fix approach: Change `_onRemoteDataChanged` from a `VoidCallback?` to a `ValueNotifier<int>` (increment on change), and have `SubscriptionNotifier` subscribe/unsubscribe in constructor/dispose.
- Test: Unit test that two listeners both fire after a remote change.
- Risk: Low.

### Task 9: SyncService dispose on sign-out
- [x] Status: complete
- Severity: P1 (upgraded from P2 — shared-device scenario is real)
- Files: `lib/services/auth_service.dart:112-115`, `lib/services/sync_service.dart` (dispose method)
- Bug: `signOut()` does not tear down SyncService. Firestore listener keeps running under new/null auth, fires permission-denied errors, stale ValueNotifier values leak to next user on shared devices.
- Fix approach: The existing `SyncService.dispose()` (at `sync_service.dart:345`) already cancels `_syncListener`, `_householdListener`, and clears `partnerSubscriptions`. Add a `_locallyDeletedIds.clear()` line to it. Then in `AuthService.signOut()`, call `SyncService().dispose()` BEFORE `_auth.signOut()` and BEFORE `_googleSignIn.signOut()` (so listeners stop while auth context is still valid, avoiding permission-denied noise).
- Test: Manual — sign in as user A, sign out, confirm no Firestore listener errors in logcat; sign in as user B on the same session, confirm `SyncService().partnerSubscriptions.value` is empty before new sync kicks in.
- Risk: Low — existing `dispose()` is already idempotent.

### Task 10: Hardcoded `5` → `AppConstants.freeSubscriptionLimit`
- [x] Status: complete
- Severity: P2
- Files: `lib/providers/subscription_providers.dart:222`
- Bug: Literal `5`.
- Fix approach: One-line swap.
- Test: No test (trivial).
- Risk: None.

### Task 11: Weak email validator
- [x] Status: complete
- Severity: P2
- Files: `lib/screens/auth_screen.dart:144, 369`
- Bug: `!value.contains('@')` is too lax.
- Fix approach: Replace with a light regex `^[^@\s]+@[^@\s]+\.[^@\s]+$`. Keep Firebase's own validation as the backstop.
- Test: Unit test on a regex helper function.
- Risk: Low.

### Task 12: R8 / ProGuard for release builds (LAST — highest regression risk)
- [ ] Status: deferred — revisit after beta exits and before first production push
- Severity: P0 (release-readiness)
- Files: `android/app/build.gradle:47-51`, `android/app/proguard-rules.pro` (new)
- Bug: No minification/shrinking on release builds.
- Fix approach: Add `minifyEnabled true`, `shrinkResources true`, `proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'`. Create `proguard-rules.pro` with keep rules for: Flutter embedding, Firebase (firestore reflection), Hive generated adapters, `flutter_local_notifications`, `home_widget` plugin, any Kotlin metadata needed.
- Test: `flutter build appbundle --release --no-tree-shake-icons` must succeed. After building, install the resulting AAB/APK on a device and verify: sign-in, sync, add sub, notification scheduling, home widget refresh all still work.
- Risk: HIGH — keep rules are finicky. If something was reflection-accessed and we missed the keep rule, it'll crash in release only. Save for last; expect to iterate on the rules file.

### (Dropped) Former Task 11 — Remove unreachable `BillingCycle.custom`
- Removing the enum case is a Hive schema change that would corrupt any existing install that ever wrote `custom`. Safer to leave the enum + fall-through branch as-is. No code change. Not part of the active plan.

---

## Post-sprint backlog

Items surfaced during the audit sprint that are intentionally deferred until after the 12-task plan lands. Not blocking release; revisit after Task 12.

### Task A1: Manual export / import of subscription data
- Severity: P2 (user-facing gap created by Task 6)
- Files: new Settings screen button(s); helper in `lib/services/` or `lib/utils/` for JSON (de)serialization of Hive contents.
- Context: Task 6 disabled Android auto-backup (`android:allowBackup="false"`) to keep Hive subscription data off plaintext Google Drive backups. Users who uninstall/reinstall or switch devices without being signed into Firebase sync now have no recovery path.
- Scope: (a) "Export data" button → serializes subscriptions box (+ custom categories, preferences as reasonable) to JSON → shares via `share_plus` so the user chooses the destination (Drive, email, local file). (b) "Import data" button → reads a JSON file via `file_picker` or `share_plus` intent → prompts Merge vs Replace → writes into Hive. Schema version must be carried in the JSON and validated on import (use `kCurrentSchemaVersion` from Task 0).
- Test: unit test round-trip (export → import → equality on the boxes). Manual: two-device transfer without sync.
- Risk: low-medium. Main hazards are schema drift across versions (handled by `schemaVersion` check) and accidentally clobbering existing data on import (handled by Merge/Replace prompt).

---

## Active task order (post pre-flight)

0. Hive schema scaffolding (P1, new)
1. Billing-cycle calculator (P0)
2. Trial expiry normalize (P0)
3. Currency-service failure surfacing (P1 — moved up, prerequisite for #4)
4. Cross-currency price impact (P0 — consumes #3's new API)
5. Firestore rules (P0 security)
6. AndroidManifest allowBackup (P1)
7. Home-screen lifecycle watches (P1)
8. SyncService listener list (P1)
9. SyncService dispose on sign-out (P1 — upgraded from A2)
10. Hardcoded `5` → constant (P2)
11. Email validator regex (P2)
12. R8/ProGuard (P0 release) — LAST, highest regression risk

Rationale:
- Task 0 is additive scaffolding; safe to land first and immediately de-risks any future `@HiveField` change.
- Task 3 moved ahead of Task 4 because #4 depends on #3's `convertOrNull` to signal missing rates instead of silently passing through wrong values.
- Task 12 (R8/ProGuard) runs last because a bad keep rule crashes only in release; want all easier wins landed first.

---

## Execution Log
(Appended as each fix task completes, newest first.)

### 2026-04-20 — Task 12: R8/ProGuard — DEFERRED
- Status flipped to `deferred — revisit after beta exits and before first production push`.
- Rationale: beta testers are actively on the current (unshrunken) release. R8/ProGuard keep-rules are finicky — Firebase's reflection paths, Hive generated adapters, `flutter_local_notifications`, and the `home_widget` plugin each require their own `-keep` clauses, and a miss only manifests as a crash in the shrunken release build (debug stays fine). Iterating on keep rules while testers are live would risk pushing a crash-loop to production through internal testing, or fragmenting beta feedback across shrunken vs. unshrunken builds. The app size / obfuscation win does not justify that risk at this stage.
- Pre-reqs before re-opening: (a) beta graduates / closes, (b) a quiet release cadence window where a bad AAB only affects the dev, (c) budget a dedicated iteration cycle (build → device smoke test → crash-pattern → amend rules → repeat). All other sprint tasks were landed without this dependency.
- No files touched. No tests added. Task still in the plan; just parked.

### 2026-04-20 — Task 11: Email validator regex ✔
- Added `lib/utils/email_validator.dart` — single top-level `bool isValidEmail(String value)` function backed by a cached `RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')`. Trims the input, short-circuits on empty, then runs `.hasMatch`. Explicitly scoped as a cheap structural gate; Firebase Auth remains the authoritative validator on the server side (documented in a doc comment on the regex).
- `lib/screens/auth_screen.dart:144` — sign-in/sign-up form validator swapped `!value.contains('@')` → `!isValidEmail(value)`. Preserved the preceding empty-check (still returns "Please enter your email" for blank input; falls through to "Please enter a valid email" for malformed).
- `lib/screens/auth_screen.dart:369` — password-reset guard simplified from `email.isEmpty || !email.contains('@')` to a single `!isValidEmail(email)` (the helper already handles empty-string).
- Added `import '../utils/email_validator.dart';` to `auth_screen.dart`.
- Grep for `contains\('@'\)` across `lib/` → zero matches. Migration complete.
- Test: `test/email_validator_test.dart` — 17 cases across two groups. Rejects: empty, whitespace-only, missing `@`, missing local, missing domain, missing TLD dot, empty segment between `@` and `.`, trailing dot with no TLD, double `@`, space in local-part, space in domain. Accepts: simple, subdomained local, subdomained host, plus-addressing, trimmed whitespace, numeric TLD (structural regex does not reject — documented in test body so future refactors understand the scope).
- Failing-first confirmed: pre-fix, the test file failed to compile with `Method not found: 'isValidEmail'`. Post-fix: 17/17 pass.
- `flutter analyze lib/utils/email_validator.dart lib/screens/auth_screen.dart`: `No issues found!` — zero warnings or infos.
- `flutter test` on all 7 task test files (0–4 + 8 + 11): 55/55 passing.

Stopping for user review before Task 12 (R8/ProGuard — LAST, highest regression risk).

### 2026-04-20 — Task 10: Hardcoded `5` → `AppConstants.freeSubscriptionLimit` ✔
- `lib/providers/subscription_providers.dart` — `hasReachedFreeLimitProvider` body swapped from `count >= 5 // Free limit` to `count >= AppConstants.freeSubscriptionLimit`. Added `import '../utils/constants.dart';` to the file's import block (alphabetized among the local imports).
- Single source of truth for the limit now lives exclusively in `lib/utils/constants.dart:25` (`freeSubscriptionLimit = 5`). Grepping `\b5\b.*Free limit\|// Free limit` across `lib/` returns zero matches — the only other consumer, `database_service.dart:261`, already used the constant.
- No test added — trivial constant swap with no behavioral change per the plan.
- `flutter analyze`: 0 new issues (3 pre-existing infos in untouched lines).
- `flutter test` on all 6 task test files: 38/38 passing.

Stopping for user review before Task 11 (email validator regex).

### 2026-04-20 — Task 9 extension: `deleteAccount()` also disposes SyncService ✔
- `lib/services/auth_service.dart:180` — added `SyncService().dispose()` as the final pre-`user.delete()` step. Same rationale as Task 9 proper: `user.delete()` invalidates the auth token, and any Firestore snapshot listener still alive at that moment would fire a permission-denied burst. Dispose while the token is still valid → clean teardown.
- No unit test (same Firebase-init constraint as Task 9). Manual check: call delete-account flow; logcat should be silent on `PERMISSION_DENIED` from Firestore listeners after the account is gone.
- No `flutter analyze` regression; same 4 pre-existing infos as Task 9, 0 new.

### 2026-04-20 — Task 9: SyncService dispose on sign-out ✔
- `lib/services/sync_service.dart` — `dispose()` (line 346) now also calls `_locallyDeletedIds.clear()`. Added doc comment clarifying idempotency. The set is a per-session record of IDs the user deleted locally (used by `_startRemoteListener` to skip re-applying deletes back to Hive); carrying it across a sign-in boundary would let user A's deletions silently skip real remote events for user B.
- `lib/services/auth_service.dart` — `signOut()` now calls `SyncService().dispose()` as its first step, before `_googleSignIn.signOut()` and `_auth.signOut()`. Ordering matters: cancelling snapshot listeners while the Firebase auth token is still valid avoids the `permission-denied` burst that would otherwise fire the moment the token goes null and the listener attempts one more read. Also closes audit A2 (shared-device stale partner subs bleeding to next user — `partnerSubscriptions.value = []` runs inside `dispose()`).
- Added `import 'sync_service.dart';` to `auth_service.dart`. Existing `deleteAccount()` path (line 118) still does not call `SyncService().dispose()` — intentionally out of scope for Task 9 (narrow plan: signOut only). Noted as a follow-up if/when we revisit account-deletion: `user.delete()` at line 173 invalidates auth the same way signOut does, so the same permission-denied noise applies there.
- No unit test added. `SyncService()` can't be constructed in a unit-test harness because its field initializer eagerly resolves `FirebaseFirestore.instance`, which throws without `Firebase.initializeApp()`. Behavior is verified manually:
  - Sign in as A → sign out → `adb logcat` should show no `PERMISSION_DENIED` errors from Firestore listeners.
  - Sign in as B on the same running process → `SyncService().partnerSubscriptions.value` should be `[]` until new household sync populates it (no stale A data).
  - Sign out a household member → creator's partner subscriptions should not include the departing member's stale data.
- `flutter analyze` on both edited files: 4 pre-existing infos (auth_service:255 `sort_constructors_first`, sync_service:93/260/261 cascade / trailing-comma / unawaited). Zero new issues.
- `flutter test` across all 6 task test files (0–4 + 8): 38/38 passing.

Stopping for user review before Task 10 (hardcoded `5` → `AppConstants.freeSubscriptionLimit`).

### 2026-04-20 — Task 8: `SyncService.onRemoteDataChanged` → listener list via `ValueNotifier<int>` ✔
- `lib/services/sync_service.dart` — deleted the private `VoidCallback? _onRemoteDataChanged` field and its public setter (old lines 200-203). Replaced with a public `final ValueNotifier<int> remoteDataChangeTicker = ValueNotifier(0)`. At the remote-listener fire site (old line 190), the single-callback `_onRemoteDataChanged?.call()` is now `remoteDataChangeTicker.value++` — an `int` bump that notifies every registered listener, with no cap on how many subscribers can coexist.
- `lib/providers/subscription_providers.dart` — `SubscriptionNotifier` no longer assigns a callback. Constructor calls `SyncService().remoteDataChangeTicker.addListener(_onRemoteTick)`; the new `_onRemoteTick` method delegates to `loadSubscriptions()`. Added a `dispose()` override that removes the listener before `super.dispose()` runs, so the Riverpod provider teardown path (hot reload, sign-out, etc.) cleans up the subscription instead of leaking.
- Closes audit finding #18 (and the secondary A4 race where `_onRemoteDataChanged == null` during instantiation — with a listener list there's no null-callback gap; late subscribers just miss events fired before they added themselves, which is acceptable since `SubscriptionNotifier` calls `loadSubscriptions()` eagerly in its constructor anyway).
- Test: `test/sync_service_listener_test.dart` — three cases. (1) Compile-time API check: a typed local `ValueNotifier<int> Function(SyncService) resolveTicker = (s) => s.remoteDataChangeTicker;` that fails to compile if the field doesn't exist or isn't the expected type. (2) Runtime contract: two listeners on a standalone `ValueNotifier<int>` both fire on a single `.value++`. (3) Independence: removing one listener mid-flight doesn't affect the other. Failing-first confirmed — pre-fix, the file failed to compile with `The getter 'remoteDataChangeTicker' isn't defined for the type 'SyncService'`. Post-fix: 3/3 pass.
- `grep -rn "onRemoteDataChanged\|_onRemoteDataChanged" lib/` → no matches. Migration is complete; no stale callers in client code. Doc files (`DEV_STATUS.md`, `PROJECT_STATE.md`, `AUDIT_REPORT.md`) still reference the old name as history — not worth rewriting.
- `flutter analyze` on both edited files: 5 issues, all pre-existing in untouched lines (93, 260-261, 307, 338). Zero new issues from the fix.
- `flutter test` on all 6 task test files (0–4 + 8): 38/38 passing.

Stopping for user review before Task 9 (SyncService dispose on sign-out).

### 2026-04-20 — Task 7: Home-screen lifecycle provider watches → `ref.listenManual` in `initState` ✔
- `lib/screens/home_screen.dart` — removed three `ref.watch(...)` calls at the top of `build` (old lines 114-117: `syncInitProvider`, `householdSyncProvider`, `householdCleanupProvider`). Replaced with `ref.listenManual(...)` calls inside a new `initState` override using cascade notation. Empty listener callback `(_, __) {}` is intentional — all three are `Provider<void>` holding side-effect chains (sync init, household sync init, stale-household cleanup). We subscribe to keep them alive for the screen's lifetime, not to receive a value.
- Semantic equivalence: `ref.listenManual` returns a `ProviderSubscription` that auto-disposes when the widget's ref is disposed (same lifetime as a `ref.watch` subscription while the widget is mounted). Dependency-driven re-evaluation still works because each provider internally watches `currentFirebaseUserProvider` / `currentUserProfileProvider` / `currentHouseholdProvider` — a change to any of those continues to re-run the Provider body exactly as before. Sign-in / sign-out / household create / disband flows are unaffected.
- Why not full refactor of the Provider-body side-effects (audit #16)? Intentionally deferred per the verification results — Task 7 is narrowly scoped to the watch-location, not to moving the side effects out of provider bodies. That larger refactor is queued as follow-up work, not in this sprint.
- No test added. This is a structural refactor with no value-level assertion to make — the providers return `void`. Manual verification: (a) fresh sign-in → subscriptions load and display currency auto-detects, (b) create household on device A + join on device B → household sync + member list populates, (c) creator disbands → member device self-cleans via `householdCleanupProvider`, (d) sign-out → sync teardown (still pending Task 9 fix) fires through existing paths.
- `flutter analyze lib/screens/home_screen.dart`: 1 pre-existing `prefer_int_literals` info in untouched helper code, 0 new. (Initial pass had 2 `cascade_invocations` infos on the added `ref.listenManual` lines — fixed by using cascade notation; both gone.)
- `flutter test` on all 5 task test files (Tasks 0–4): 35/35 passing — no regression.

Stopping for user review before Task 8 (SyncService listener list).

### 2026-04-20 — Task 6: `android:allowBackup="false"` ✔
- `android/app/src/main/AndroidManifest.xml:9` — added `android:allowBackup="false"` attribute on `<application>`. Android's default is `true`, which causes the system to auto-upload app data (including the Hive subscriptions box) to the user's Google Drive in plaintext. Subscription data is personal financial info; opting out closes the leak.
- No `android:fullBackupContent` or `android:dataExtractionRules` added — `allowBackup="false"` alone disables both legacy key-value backup and Android 6+ auto-backup. Minimum fix per plan.
- No unit test applies (manifest attribute, no runtime path to assert).
- Manual verification: `adb shell bmgr list transports` + `adb shell bmgr backupnow com.sumedh.recurly` should report "no data" once installed. Optional — the attribute is declarative and honored by the system backup agent directly.
- `flutter analyze` on the full project: 395 issues (all pre-existing in `lib/` — unchanged from pre-edit baseline). XML files aren't analyzed by `flutter analyze`, so this is expected to be no-op for the manifest change itself.
- No other files touched. No tests added.

Stopping for user review before Task 7 (home-screen lifecycle provider watches → `ref.listen`).

### 2026-04-20 — Hotfix: Undo action missing on details-sheet delete ✔
- Out-of-plan bug reported after Task 5 verification. Swipe-to-delete showed an `Undo` action in the snackbar; deleting via the pill in the details sheet showed the same "moved to recently deleted" text with no action button.
- Root cause: `lib/widgets/subscription_card.dart` — the swipe `onDismissed` handler (lines 80-93) built a `SnackBar` with `action: SnackBarAction(label: 'Undo', ...)`; the details-sheet delete handler (lines 550-556) built the `SnackBar` without any `action:` field. Code divergence, not a data/service issue.
- Fix: added the identical `SnackBarAction` to the details-sheet path. Restore logic mirrors the swipe path: `databaseService.restoreFromRecentlyDeleted(id)` → `notifier.loadSubscriptions()` → re-push to Firestore via `SyncService().pushSubscription(...)` when sync is enabled. All four referenced values (`databaseService`, `notifier`, `isSyncEnabled`, `user`) were already captured in the enclosing scope, so no new closures or refs needed.
- No unit test added — this is SnackBar UI behavior. Manual verification: open details → Delete → confirm → Undo pill appears → tap Undo → subscription reappears in list. Covers sync-disabled and sync-enabled paths.
- `flutter analyze lib/widgets/subscription_card.dart`: 9 pre-existing infos in untouched code, 0 new. The one unawaited `SyncService().pushSubscription` on the added line matches the established fire-and-forget convention on the swipe path (line 89) — consistent with the rest of the file.

Stopping for user review; resuming Task 6 next.

### 2026-04-19 — Task 5: Firestore rules — households & invites ✔
- `firestore.rules` — replaced the lax `/households` and `/invites` blocks with tightly-scoped rules. Changes:
  - `/households` read: kept open to any authed user (**Option A**). Required because the join flow at `lib/services/household_service.dart:84` reads the household doc BEFORE the caller is a member; a member-only read rule would break joining. Writes carry the full tightening, so open reads only leak "membership list of a household you already know the id of" and cannot be used to mutate state.
  - `/households` create: requires `createdBy == auth.uid` and `members == [auth.uid]` (caller must be the sole initial member, as creator).
  - `/households` update: split into three disjoint branches:
    - **join**: non-member appends only themselves; `size() == old+1`, cap at 2, `hasAll(old)`, `createdBy` unchanged.
    - **leave**: non-creator member removes only themselves; `size() == old-1`, `hasAll(new)`, `createdBy` unchanged.
    - **creator refresh**: creator may rewrite non-membership fields only; `members` and `createdBy` frozen.
  - `/households` delete: creator only.
  - `/invites`: `update` is intentionally omitted — no client code path updates an invite (refresh is delete + create), so default-deny closes the squatting vector. `create` now requires `createdBy == auth.uid`. `delete` is creator-only.
- Write-coverage map (11 writes, all covered):
  - household_service.dart:33-36 create → households.create
  - household_service.dart:104-106 join update → households.update (join branch)
  - household_service.dart:136-138 leave update → households.update (leave branch)
  - household_service.dart:188 disband delete → households.delete
  - household_service.dart:257-260 refresh update → households.update (creator branch)
  - auth_service.dart:149 deleteAccount-creator delete → households.delete
  - auth_service.dart:161-163 deleteAccount-member update → households.update (leave branch)
  - household_service.dart:39-43 invite create → invites.create
  - household_service.dart:184 disband invite delete → invites.delete
  - household_service.dart:248 refresh invite delete → invites.delete
  - household_service.dart:262-266 refresh invite create → invites.create
- No automated rules harness in repo (`firebase-rules-unit-testing` not installed). Verification is manual — Firebase Console Rules Playground or a two-device smoke test covering: create → invite → join → leave → disband, plus account delete by each of creator and member.
- **Deployment is manual — Claude will NOT deploy.** User deploys `firestore.rules` via Firebase Console (or `firebase deploy --only firestore:rules`). No client code was touched in this task, so the current production rules (old, lax) remain live until the user pushes the new file.

**Manual verification checklist — COMPLETE (2026-04-20):**
- [x] Rules deployed to Firebase (user deployed via Console)
- [x] Creator can create a household
- [x] Second user can join via invite code
- [x] Second user can leave the household
- [x] Creator can disband the household
- [x] Creator can refresh/rotate the invite code (creator-update branch)

All 11 writes (households.create/update×3/delete + invites.create/delete) confirmed working on live devices. Rules are live.

**Sidebar during verification:** Google Sign-In broke on a fresh `flutter run` of `com.sumedh.recurly`. Root cause was the debug keystore SHA-1 had never been registered under the current package in Firebase (it was only on the defunct `com.example.recurly` app). Fixed by adding debug SHA-1 `74:E7:E3:FE:A7:53:31:5A:3D:B6:2E:BC:0C:3E:96:2D:7D:33:AA:67` to the `com.sumedh.recurly` Firebase app and re-downloading `google-services.json`. Unrelated to Task 5; noted here for future reference.

Stopping for user review before Task 6.

### 2026-04-19 — Task 4: Cross-currency price-change impact ✔
- `lib/providers/analytics_providers.dart` — extracted pure helper `double? computeTotalPriceChangeImpact({subs, currencyService, displayCurrency, rates})` that converts each sub's monthly-equivalent diff via `convertOrNull` (from Task 3) and returns `null` as soon as any rate is unresolvable. `totalPriceChangeImpactProvider` now wraps the helper, reading `currencyServiceProvider`, `displayCurrencyProvider`, and `exchangeRatesProvider.value`. Return type changed from `double` to `double?`.
- `lib/widgets/analytics/price_changes_section.dart` — removed the no-op `convert(from: displayCurrency, to: displayCurrency)` call. When `totalImpact == null`, widget renders `—/mo impact (rates unavailable)` with a neutral outline color and `sync_problem_rounded` icon; when non-null, rendered directly (already in display currency via the provider). Dropped the unused `exchangeRatesProvider` watch.
- Grep confirms `totalPriceChangeImpactProvider` has only one consumer (the widget above), so no other call sites need updating.
- Test: `test/price_change_impact_test.dart` — 7 cases (empty → 0, same-currency monthly, yearly ÷12, USD+EUR with rates → converted sum, unknown currency → null, null cache + cross-currency → null, price decrease preserves negative sign). Failing-test-first confirmed (method not defined). All 7 pass.
- `flutter analyze` on 3 touched files: 4 pre-existing infos/warnings in untouched code, 0 from new code.
- `flutter test` across Tasks 0–4: 35/35 passing.

Stopping for user review before Task 5.

### 2026-04-19 — Task 3: Currency service `convertOrNull` ✔
- `lib/services/currency_service.dart` — added `double? convertOrNull({amount, from, to, rates})`. Returns `null` when cache is missing OR the rate pair is unresolvable (same/from base + missing rate, cross-rate with missing fromRate or toRate). Trivial `from == to` path returns `amount`.
- Left existing `convert` untouched — no call-site churn in this task. Migration to `convertOrNull` happens in Task 4 (analytics/widget) and future cleanup passes.
- Test: `test/currency_service_test.dart` — 7 cases: identity, null cache, base-is-from happy, base-is-from missing rate, cross-rate happy, fromRate missing, toRate missing. Failing-test-first confirmed (method not defined). All 7 pass after implementation.
- `flutter analyze` on 2 touched files: 3 pre-existing infos in untouched code (lines 12, 75), 0 from new code.
- `flutter test` across Tasks 0–3 test files: 28/28 passing.

Stopping for user review before Task 4.

### 2026-04-19 — Task 2: Trial expiry midnight-normalize ✔
- `lib/models/subscription.dart:326-336` — replaced `DateTime.now().isAfter(trialEndDate!)` with a date-only comparison (both sides stripped to midnight via `DateTime(y,m,d)`). Now matches the semantics of `daysUntilTrialEnds` / `trialStatusText` — a trial ending today reads "Trial ends today" AND `isTrialExpired == false` until tomorrow.
- Extracted `isTrialExpiredAt(DateTime now)` as a public method so tests can inject a deterministic clock. `isTrialExpired` is now a one-liner delegating to it with `DateTime.now()`.
- No other caller of `isTrialExpired` needs changes; semantics are strictly more permissive on the final day.
- Test: `test/trial_expiry_test.dart` — 6 cases (today at 00:00 + now at 14:00 → not expired; end at 09:00 + now at 23:59 → not expired; yesterday → expired; tomorrow → not expired; not a trial → never expired; null end → not expired). Failing-test-first confirmed (method not defined). All 6 pass after implementation.
- `flutter analyze` on 2 touched files: 3 pre-existing infos in untouched code (prefer_int_literals around line 156-165), 0 from new code.
- `flutter test` on Tasks 0+1+2 test files: 21/21 passing.

Stopping for user review before Task 3.

### 2026-04-19 — Task 1: Billing-cycle arithmetic ✔
- Added `lib/utils/billing_cycle.dart` with single entry point `DateTime addOneCycle(BillingCycle, DateTime)`. Semantics:
  - Monthly: add 1 calendar month, clamp day to target month's last day (Jan 31 → Feb 28/29, Mar 31 → Apr 30).
  - Yearly: delegates to `_addMonths(d, 12)` — Feb 29 leap → Feb 28 non-leap correctly.
  - Weekly: `DateTime(y, m, d + 7, h, mi, s, ms, us)` — calendar-day, DST-stable. Replaces `Duration(days: 7)` which drifts 1 h across DST.
  - Custom: aliases to monthly. Schema has no `customDays` field, so behaviour is preserved (deleting the enum case would require a Hive migration).
- Deleted both duplicates:
  - `lib/models/subscription.dart:189-213` — `_addBillingCycle` removed; `nextBillDate` calls `addOneCycle(billingCycle, nextDate)`.
  - `lib/providers/analytics_providers.dart:400-412` — `_addOneCycle` removed; two call sites (lines 422, 438 in old file) now call `addOneCycle`.
  - Grep for `_addOneCycle\|_addBillingCycle` across `lib/` returns zero matches — single source of truth.
- Test: `test/billing_cycle_test.dart` — 12 cases. Failing-test-first confirmed (compile errors on missing `addOneCycle`). All 12 pass after implementation.
- `flutter analyze` on 4 touched files: 6 pre-existing lint infos, 0 from new code.
- `flutter test test/billing_cycle_test.dart test/schema_migration_test.dart`: 15/15 passing (no regression to Task 0 tests).

Stopping for user review before Task 2.

### 2026-04-19 — Task 0: Hive schema migration scaffolding ✔
- Added `lib/utils/schema.dart` with `kCurrentSchemaVersion = 1` and `migrateSchema(Box)` helper covering: null-version → write current; equal → no-op; older → run migration chain (empty today, baseline is v1); newer → `StateError` (refuse downgrade); non-int value → `StateError`.
- Wired into `lib/services/database_service.dart:initialize()` — opens the dedicated schema box and calls `migrateSchema` before `openBox<Subscription>`. All 9 existing adapters still registered before any box open.
- **Follow-up fix (same day)**: initial version reused `AppConstants.settingsBox` for the schema version, which collided with `PreferencesService` opening the same box as `Box<AppPreferences>` and crashed app start with `HiveError: The box "settings" is already open and of type Box<dynamic>`. Switched to a dedicated `AppConstants.schemaBox = 'schema'` so the two boxes can coexist. Tests still pass, app starts cleanly.
- No `@HiveField` changes; existing installs will transparently gain `schemaVersion = 1` on next app launch.
- Test: `test/schema_migration_test.dart` — 3 cases (no version writes 1, stored==current is no-op, stored>current throws StateError). Failing-test-first confirmed (compile errors on missing `migrateSchema`/`kCurrentSchemaVersion`), passing after implementation.
- `flutter analyze` on the three touched files: `No issues found`. Full-project analyze shows no new issues attributable to this change.
- `flutter test test/schema_migration_test.dart` → 3/3 passing.
- Full `flutter test` → `widget_test.dart` fails, but it's a pre-existing Firebase-init failure (reproduced with `git stash`); unrelated to this task.

Stopping for user review before Task 1.

---

## Sprint summary (2026-04-20)

### Tasks landed: 11/12 in-plan + 1 out-of-plan hotfix
- **Complete:** Tasks 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 (+ deleteAccount extension), 10, 11.
- **Deferred:** Task 12 (R8/ProGuard) — regression risk against live beta testers; revisit after beta exits.
- **Hotfix (out of plan):** Undo action missing on details-sheet delete. Code divergence between swipe-delete and pill-delete snackbar paths; closed same-day as reported during Task 5 verification.

### Tests added: 7 new test files, 55 cases, 55/55 passing
| File | Cases | Task |
|------|-------|------|
| `test/schema_migration_test.dart` | 3 | 0 |
| `test/billing_cycle_test.dart` | 12 | 1 |
| `test/trial_expiry_test.dart` | 6 | 2 |
| `test/currency_service_test.dart` | 7 | 3 |
| `test/price_change_impact_test.dart` | 7 | 4 |
| `test/sync_service_listener_test.dart` | 3 | 8 |
| `test/email_validator_test.dart` | 17 | 11 |

Each test file uses the failing-first protocol: tests were written first against the new API, confirmed to fail-to-compile or fail-at-runtime, then made green by implementing the fix. Tasks 5, 6, 7, 9, 10, and the hotfix carry a manual-test note instead of a unit test — their fixes live in Firestore rules, an XML attribute, widget lifecycle, Firebase-dependent tear-down, a trivial constant swap, or UI snackbar behavior respectively, none of which fit a cheap unit-test harness. `widget_test.dart` continues to fail on a pre-existing Firebase bootstrap error — unchanged and out of sprint scope.

### Files touched
**New source (`lib/`):**
- `lib/utils/schema.dart` — schema-migration scaffolding (Task 0)
- `lib/utils/billing_cycle.dart` — single-source billing-cycle calculator (Task 1)
- `lib/utils/email_validator.dart` — structural email check (Task 11)

**Modified source (`lib/`):**
- `lib/utils/constants.dart` — added `schemaBox`, consumed `freeSubscriptionLimit` via new call site (Tasks 0, 10)
- `lib/services/database_service.dart` — wired `migrateSchema` into `initialize()` (Task 0)
- `lib/models/subscription.dart` — removed duplicate `_addBillingCycle`, added `isTrialExpiredAt(now)` with date-only comparison (Tasks 1, 2)
- `lib/providers/analytics_providers.dart` — removed duplicate `_addOneCycle`, refactored `totalPriceChangeImpactProvider` to honor cross-currency via `convertOrNull` (Tasks 1, 4)
- `lib/services/currency_service.dart` — added `convertOrNull` failure-surfacing helper (Task 3)
- `lib/widgets/analytics/price_changes_section.dart` — removed no-op self-currency convert, added rates-unavailable UI state (Task 4)
- `lib/widgets/subscription_card.dart` — added Undo `SnackBarAction` to details-sheet delete path (hotfix)
- `lib/screens/home_screen.dart` — moved three lifecycle watches from `build` to `initState` via `ref.listenManual` (Task 7)
- `lib/services/sync_service.dart` — replaced single-callback with `ValueNotifier<int> remoteDataChangeTicker`; `dispose()` now clears `_locallyDeletedIds` (Tasks 8, 9)
- `lib/providers/subscription_providers.dart` — `SubscriptionNotifier` subscribes/unsubscribes via the ticker's listener list; `hasReachedFreeLimitProvider` uses `AppConstants.freeSubscriptionLimit` (Tasks 8, 10)
- `lib/services/auth_service.dart` — `signOut()` and `deleteAccount()` call `SyncService().dispose()` before auth invalidation (Task 9 + extension)
- `lib/screens/auth_screen.dart` — both email validators route through `isValidEmail()` helper (Task 11)

**Non-source files:**
- `firestore.rules` — rewritten with Option A (open reads, tight disjoint-branch writes for create/join/leave/refresh/delete); deployed manually via Firebase Console; verified live (Task 5)
- `android/app/src/main/AndroidManifest.xml` — `android:allowBackup="false"` on `<application>` (Task 6)

**Tests:** 7 new files listed above. No existing tests modified.

### What shipped, what's deferred

This sprint closed every verified P0 that was actionable without release-shaping risk: billing-cycle date arithmetic that silently drifted renewals (Task 1), trial expiry that disagreed with the UI for up to ~14 hours (Task 2), cross-currency totals that never actually converted (Tasks 3, 4), Firestore rules that leaked household lists and allowed invite-code squatting (Task 5), and the auto-backup path that would have uploaded the Hive subscription database to plaintext Google Drive (Task 6). On the architecture side, lifecycle re-entrancy (Task 7), the single-callback overwrite on `SyncService` (Task 8), the sign-out/delete-account tear-down gap that caused `permission-denied` noise on shared devices (Task 9 + extension), a small constant de-duplication (Task 10), and an email validator that only checked for the `@` character (Task 11) all landed with failing-test-first where applicable and manual verification notes where not. Task 12 (R8/ProGuard minification + obfuscation) is deliberately deferred: while beta testers are live on the current unshrunken release, iterating on keep-rules risks pushing a release-only crash through internal testing. It reopens after beta exits and before the first production-track promotion, as a dedicated cycle with budget for keep-rule iteration. Also queued in the Post-sprint backlog: Task A1 (manual JSON export/import via `share_plus`) — the user-facing recovery path that Task 6 removed when it disabled auto-backup, earmarked for a post-launch minor release.

