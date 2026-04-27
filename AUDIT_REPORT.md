# Recurly — End-to-End Audit Report

Audit date: 2026-04-17
App version: 1.0.0+3 (currently in Google Play closed-testing review)
Flutter: 3.41.2 / Dart 3.11.0

This report covers correctness, architecture, security, performance, code quality, and release readiness. Every finding cites a file path and line range. A prioritized P0/P1/P2 action list is at the end.

---

## Executive Summary

### Top 5 critical issues (fix before scaling users)

1. **Billing-cycle arithmetic silently corrupts renewal dates** — `lib/models/subscription.dart:190-213`. `DateTime(year, month+1, 31)` overflows: Jan 31 → Mar 3, not Feb 28. Every yearly sub created on Feb 29 of a leap year will drift to Mar 1 permanently. A duplicate copy of the broken logic lives at `lib/providers/analytics_providers.dart:401-412`, so forecasts drift too.
2. **Firestore rules let any authed user read all households and overwrite any invite code** — `firestore.rules:45-60`. `/households/{id}` allows global read; `/invites/{code}` allows any authed write — invite-code squatting is possible. `/households` update allows `request.auth.uid in request.resource.data.members`, meaning a user can add themselves to someone else's household.
3. **Cross-currency totals are silently wrong** — `lib/providers/analytics_providers.dart:140-151` sums USD + EUR + JPY price deltas as if they were the same unit; `lib/widgets/analytics/price_changes_section.dart:49-54` then calls `convert(from: displayCurrency, to: displayCurrency)` which is a no-op. `CurrencyService.convert` (`lib/services/currency_service.dart:89, 113`) also silently returns the original amount on any failure — users see plausible but wrong numbers.
4. **Trial expiry contradicts the UI text** — `lib/models/subscription.dart:341-365`. `isTrialExpired` uses a live timestamp (`DateTime.now().isAfter(trialEndDate!)`), but `daysUntilTrialEnds` and `trialStatusText` use midnight-normalized dates. On the expiry day, the card reads "Ends today" for hours after `isTrialExpired == true` — gating logic and UI disagree all day.
5. **No R8/ProGuard minification on release builds** — `android/app/build.gradle` has no `minifyEnabled`, no `shrinkResources`, no `proguard-rules.pro`. APK is larger, easier to reverse, and Play's production track will flag the absence of shrinking.

### Top 5 quick wins (<1 day each)

1. Replace the hardcoded `5` at `lib/providers/subscription_providers.dart:223` with `AppConstants.freeSubscriptionLimit`.
2. Add `android:allowBackup="false"` to `<application>` in `android/app/src/main/AndroidManifest.xml` — stops Android from auto-backing up the Hive DB to the user's Google Drive in plaintext. Sync already handles cross-device recovery.
3. Stop re-running lifecycle I/O on every home-screen rebuild: move the three `ref.watch(syncInitProvider / householdSyncProvider / householdCleanupProvider)` calls in `lib/screens/home_screen.dart` into a `ref.listen` in `initState`, or use `ref.read` with one-shot triggers.
4. Deduplicate `_addOneCycle` — once billing math is fixed, delete the copy in `analytics_providers.dart:401-412` and import the model's implementation.
5. Add `.where('householdVisible', isEqualTo: true)` clauses (or document why not) and tighten the `invites` write rule to `create: if request.auth != null && !exists(/databases/$(database)/documents/invites/$(code))` — blocks invite takeover in one line.

---

## Phase 1 — Project Structure & Dependencies

### Architecture pattern

Layer-first Flutter app: `lib/{models, providers, services, screens, widgets, theme, utils}`. State via Riverpod 2.4.9. Hive 2.2.3 is the source of truth, Firestore syncs. No `features/` folders; every screen reaches across layers. This is fine at current size (~20 screens), but the provider/service fan-out in `home_screen.dart` (744 lines) signals the ceiling is close.

### Dependencies (`pubspec.yaml`)

- **Outdated**: `flutter_lints: ^3.0.0` (current stable is 5.x), `flutter_local_notifications: ^17.0.0` (18+ available). Neither is urgent but the lint version misses modern rules.
- **`dynamic_color` disabled** (line 33 comment) — Material You color extraction is off; users on Android 12+ don't get dynamic theming.
- **`purchases_flutter` commented out** (line 30) — expected, matches the "launch free, monetize later" strategy in memory.
- **Two PDF/export deps plus `share_plus`** — fine, but bundle-size cost is real; check if `pdf` is actually used.
- **No `logger` / `talker` / `sentry_flutter`** — all diagnostics flow through `debugPrint`, invisible in production.

### Domain model

- `Subscription` (HiveType 0, 374 lines) — well-structured. Splits into subscription + priceHistory list (JSON-encoded in Hive).
- `AppPreferences` (HiveType 3), `TimeOfDayPreference` (HiveType 4).
- `BillingCycle` enum: `monthly | yearly | weekly | custom`. **Custom is identical to monthly** in `_addBillingCycle` (`subscription.dart:206-211`) — there is no actual custom-period support despite the enum.
- Hive typeIds 0-8 are in use, no collision risk on add.

---

## Phase 2 — Correctness & Miscalculations (highest priority)

### P0 Billing-cycle overflow (critical)

**File**: `lib/models/subscription.dart:190-213`

```dart
case BillingCycle.monthly:
  return DateTime(date.year, date.month + 1, date.day);  // Jan 31 → Mar 3!
case BillingCycle.yearly:
  return DateTime(date.year + 1, date.month, date.day);  // Feb 29 → Mar 1
case BillingCycle.weekly:
  return date.add(const Duration(days: 7));              // DST shift
case BillingCycle.custom:
  return DateTime(date.year, date.month + 1, date.day);  // same as monthly
```

**Why it's broken**: `DateTime(2025, 2, 31)` silently normalizes to `2025-03-03`. From then on, every subsequent monthly roll-over drifts the renewal one day later until the next 31-day month. An iPhone user who signed up Jan 31 now sees their monthly renewals on Mar 3, Apr 3, May 3 — not the 31st of each month.

**Also bad**: yearly on Feb 29 loses its leap-year anchor permanently. `BillingCycle.custom` has no actual custom period — the enum promises support it doesn't deliver. Weekly uses `Duration(days: 7)`, which is 7×24h, not 7 calendar days — DST transitions shift the local time by one hour.

**Fix**:
```dart
case BillingCycle.monthly:
  final newMonth = date.month + 1;
  final daysInNewMonth = DateUtils.getDaysInMonth(
    date.year + (newMonth > 12 ? 1 : 0),
    ((newMonth - 1) % 12) + 1,
  );
  return DateTime(
    date.year + (newMonth > 12 ? 1 : 0),
    ((newMonth - 1) % 12) + 1,
    date.day.clamp(1, daysInNewMonth),
  );
case BillingCycle.yearly:
  final targetDay = (date.month == 2 && date.day == 29)
      ? (_isLeapYear(date.year + 1) ? 29 : 28)
      : date.day;
  return DateTime(date.year + 1, date.month, targetDay);
```

For weekly, use `DateTime(date.year, date.month, date.day + 7)` to preserve calendar-day semantics across DST.

**Duplicate of this bug**: `lib/providers/analytics_providers.dart:401-412` has its own `_addOneCycle` with the same three cases and the same overflow. Forecasts in the Analytics screen therefore also drift.

### P0 Trial expiry / "ends today" inconsistency

**File**: `lib/models/subscription.dart:341-365`

- `isTrialExpired`: `DateTime.now().isAfter(trialEndDate!)` — compares to a full timestamp.
- `daysUntilTrialEnds`: computes `DateTime(year, month, day)` for both today and `trialEndDate`, so "days" uses midnight boundaries.
- `trialStatusText` uses `daysUntilTrialEnds`, so on the expiry day (days==0) the UI says "Ends today" — but `isTrialExpired` turns true the instant `trialEndDate`'s time-of-day passes. If `trialEndDate` was stored with the creation time (e.g. 09:17), then at 09:18 the trial is expired-by-code but "ends today" on screen.

**Fix**: normalize both sides to midnight. `isTrialExpired` should be `DateUtils.dateOnly(DateTime.now()).isAfter(DateUtils.dateOnly(trialEndDate!))`.

### P1 Price-change impact across currencies

**File**: `lib/providers/analytics_providers.dart:140-151`

```dart
for (final sub in subs) {
  final oldPrice = (sub.lastPriceChange!['price'] as num).toDouble();
  final diff = sub.price - oldPrice;
  totalImpact += diff * sub.billingCycle.getMonthlyMultiplier();
}
```

Each `sub.price` is in the sub's own `sub.currency`. The totals are added raw — $1 USD + €1 EUR counted as "2". `lib/widgets/analytics/price_changes_section.dart:49-54` then runs `convert(from: displayCurrency, to: displayCurrency)` which is a no-op (line 85 of `currency_service.dart` short-circuits on equal currencies). The banner reads "+$X/mo impact" in the display currency but the number never crossed a conversion.

**Fix**: accept `ExchangeRateCache?` + `displayCurrency` in the provider (or convert in the loop via `currencyServiceProvider`), convert each `diff * multiplier` before summing.

### P1 Currency conversion silently falls back

**File**: `lib/services/currency_service.dart:89, 113`

Both failure paths (`cache == null` and unknown rate) log via `debugPrint` and return the input amount. The call sites in `analytics_providers.dart`, `home_widget_service.dart:52-59`, `currency_providers.dart:116` sum those pass-throughs into totals without knowing a conversion failed. A user with stale rates silently sees wrong totals.

**Fix options**:
- Return `double?` and make callers decide (propagates `null` through totals).
- Track an `isStale` / `hasMissingRate` flag and surface a banner at the totals location.

### P1 JPY/KRW rounding in `formatAmount`

**File**: `lib/services/currency_service.dart:123-128`

`amount.round()` truncates fractional yen/won — fine for display. But the same `double` is still used for `convert` math elsewhere. Cumulative sums over many subs in JPY can drift by multiple yen once rounded at display time. Not a user-visible bug today but locks you out of precise reconciliation later.

### P1 Locale-naive thousand separator

**File**: `lib/services/currency_service.dart:130-141`

Hard-coded `,` as thousand separator. A German-locale device showing EUR expects `1.234,56 €`, not `€1,234.56`. Since the app is English-only today this is a latent issue, but `intl` is already in pubspec — use `NumberFormat.currency` instead.

### P1 Unbounded `while` on `firstBillDate`

**File**: `lib/providers/analytics_providers.dart` (`upcomingRenewalsProvider`) and `lib/models/subscription.dart:180-184`

If a sub was created years ago (`firstBillDate` set manually by user) and never received a rollover, `while (!nextDate.isAfter(today))` runs thousands of iterations on every provider rebuild. Unlikely but possible — add a ceiling or precompute during save.

### P2 Notification-ID collisions

**File**: `lib/services/notification_service.dart:246-250`

```dart
return (subscriptionId + daysOffset.toString()).hashCode;
```

Dart's `String.hashCode` is 30-bit (`SMI`) on 32-bit platforms and truncated on the notification plugin's 32-bit ID. With `N` subs × 4 offsets, collisions become non-negligible above a few hundred subs. Today the free limit is 5 so not exploitable; matters post-monetization. Consider a deterministic `(index * 4 + offset)` or an explicit counter in Hive.

### P2 Hardcoded free limit

**File**: `lib/providers/subscription_providers.dart:223`

Uses literal `5` instead of `AppConstants.freeSubscriptionLimit`. Easy to miss when monetization lands.

### P2 `myShareSpendProvider` doesn't convert currency

**File**: `lib/providers/subscription_providers.dart`

Returns raw `price * multiplier` without `CurrencyService.convert`. `home_screen.dart:_convertedMyShare` re-implements the conversion correctly, but any other caller of the provider will get unconverted totals. Pick one implementation and delete the other.

### P2 `BillingCycle.custom` has no custom period

The enum exists but `_addBillingCycle` treats `custom` identically to `monthly`. Either remove the case or add a `customDays` field to `Subscription`.

### P2 Delete/archive leakage

**File**: `lib/services/database_service.dart`

`getAllSubscriptions()` returns deleted+archived entries; only `getActiveSubscriptions()` filters. Several providers call `subscriptionProvider.value` directly and re-filter inline (`isArchived && deletedAt == null`). A missed filter silently inflates totals. Consider exposing only filtered lists from the provider.

---

## Phase 3 — Architecture & State Management

### P1 Side-effects inside provider bodies

**Files**:
- `lib/providers/sync_providers.dart` — `syncInitProvider` auto-detects display currency after rates load, invalidates other providers, and chains `.then()` callbacks without cancellation on rebuild.
- `lib/providers/household_providers.dart` — `householdCleanupProvider` directly constructs `FirebaseFirestore.instance`, `HouseholdService()`, `DatabaseService()` and runs cleanup on every `currentHouseholdProvider` tick.

Riverpod providers should be pure, memoized derivations. Side-effects belong in `ref.listen`, `initState`, or a dedicated controller. Today these providers re-run on rebuild and fire Firestore/Hive I/O unpredictably.

**Fix**: move to `AsyncNotifier`s with explicit start/stop methods, or use `ref.listen` in a top-level initializer widget.

### P1 `home_screen.dart` watches lifecycle providers in `build`

**File**: `lib/screens/home_screen.dart`

Watches `syncInitProvider`, `householdSyncProvider`, `householdCleanupProvider` at the top of `build`. These providers have side-effects (see above); re-watching them on every rebuild triggers I/O at an unpredictable cadence. The typical Flutter pattern — `ref.listen` in `initState` inside a `ConsumerStatefulWidget` — is not used here.

### P1 `SyncService().onRemoteDataChanged = ...` overwrites prior listeners

**File**: `lib/providers/subscription_providers.dart` (SubscriptionNotifier constructor)

Assigns the singleton service's callback field. If `SubscriptionNotifier` is ever instantiated more than once (hot reload, tests, provider invalidation), the earlier callback is lost. Current hot-reload behavior already exhibits this — after a hot reload, remote changes don't refresh Hive until a manual restart.

**Fix**: use a `List<Function>` of listeners, or a `Stream`/`StreamController` the notifier subscribes to and unsubscribes from on dispose.

### P1 `main.dart` sequential awaits before `runApp`

**File**: `lib/main.dart`

```dart
await DatabaseService().initialize();        // required, fast
await PreferencesService().initialize();     // required, fast
// Optional with try/catch — but still awaited sequentially:
await NotificationService().initialize();
await NotificationService().rescheduleAllNotifications(...);
await SyncService().initialize(uid);         // NETWORK call
await initializeHouseholdSync(...);
runApp(ProviderScope(...));
```

Cold start blocks on notification scheduling and sync initialization, including a network RTT. Users on weak connections see a blank screen.

**Fix**: only `await` DatabaseService + PreferencesService (Hive reads); launch the rest in the background via `unawaited(...)` or trigger them from a post-first-frame `WidgetsBinding.instance.addPostFrameCallback`.

### P1 No Hive migrations

**File**: `lib/services/database_service.dart`

No `@HiveType` version tracking, no schema migration path. If you add/remove a `@HiveField` without keeping the old index reserved, existing users' boxes read garbage or throw. Today the app is 1.0.0+3; the first breaking change to `Subscription` without a migration strategy will corrupt every installed device.

**Fix**: add a `schemaVersion` key in `settingsBox` and write a `_migrate(oldVersion → newVersion)` function called from `DatabaseService.initialize()` before opening the subscriptions box.

### P2 `settings_screen.dart` mutates inside `.whenData`

**File**: `lib/screens/settings_screen.dart` (`_buildCurrencyCard`)

Assigns to a local `subtitle` variable inside `.whenData` in the build method. Harmless today because the variable is local, but the pattern invites worse misuse. Refactor to `whenData`-returning widgets.

### P2 Layer-first → feature-first cost looms

The layer-first structure is fine for ~20 screens. Future features (recurring invoices, shared bill splitting beyond households, multiple currencies per sub) will span 6-8 providers/services each. A feature folder (`features/subscriptions/`, `features/household/`) removes the cross-file navigation cost.

---

## Phase 4 — Security & Privacy

### P0 Firestore rules expose households and invites

**File**: `firestore.rules:45-60`

```
match /households/{householdId} {
  allow read: if request.auth != null;       // any signed-in user can list ALL
  allow update: if request.auth != null
    && (request.auth.uid == resource.data.createdBy
        || request.auth.uid in resource.data.members
        || request.auth.uid in request.resource.data.members);  // SELF-ADD!
}
match /invites/{code} {
  allow read: if request.auth != null;
  allow write: if request.auth != null;      // any signed-in user can overwrite
}
```

Three separate flaws:

1. **Global household read**: every authed user can iterate all households. That leaks member UIDs. A motivated user can correlate UIDs with `users/{uid}` (which also allows other household members to update — requires a `get()` to bypass but not hard).
2. **Self-add to members**: the third branch of `allow update` lets any authed user set `request.resource.data.members` to include their own UID. They can't satisfy this if the existing doc's `members` already has the max of 2, but the rule does not check `resource.data.members.size() < 2`.
3. **Invite overwriting**: any authed user can write `/invites/{code}` — they can overwrite a pending invite with their own code, hijacking the join flow.

**Fix**:

```
match /households/{householdId} {
  allow read: if request.auth != null
    && request.auth.uid in resource.data.members;
  allow create: if request.auth != null
    && request.resource.data.createdBy == request.auth.uid
    && request.resource.data.members.hasOnly([request.auth.uid]);
  allow update: if request.auth != null
    && request.auth.uid in resource.data.members
    && request.resource.data.members.size() <= 2;
  allow delete: if request.auth != null
    && request.auth.uid == resource.data.createdBy;
}

match /invites/{code} {
  allow read: if request.auth != null;
  allow create: if request.auth != null
    && request.resource.data.createdBy == request.auth.uid;
  allow update, delete: if request.auth != null
    && request.auth.uid == resource.data.createdBy;
}
```

(Per memory, `/households read` being global was intentionally added for the join flow. It should be replaced with the `/invites` read as the entry point — reading the invite gives the household id, and the household read should then require membership. The join flow updates the household doc via the accept API, which should check invite validity server-side via a callable function or rule helpers.)

### P1 Email / password validation weak

**File**: `lib/screens/auth_screen.dart`

Email validator is `value.contains('@')`. No domain check, no RFC-light regex. Firebase's own validator catches malformed addresses but the UX is a 400 from Firebase instead of a field error.

Password minimum is 6 characters — Firebase default, below modern OWASP (8+ with class mix or length-based).

### P1 AndroidManifest `allowBackup` not set

**File**: `android/app/src/main/AndroidManifest.xml:6-9`

No `android:allowBackup="false"` and no `android:fullBackupContent` rules. Android's auto-backup will upload the Hive DB (subscriptions, prices, notes) to the user's Google Drive in plaintext, separate from your own Firestore sync. Two copies of the same data in two clouds is redundant at best and a compliance oddity at worst (Data Safety declarations may not mention this second path).

**Fix**: `android:allowBackup="false"` on `<application>`.

### P1 `isHouseholdMember` helper does 2 reads per rule check

**File**: `firestore.rules:7-12`

Every subscription read with the household-member branch triggers two `get()`s — one for target user profile, one for requester. For a household with 50 subs, a single list listener fires 100 extra reads. Scale cost is high.

**Fix**: denormalize `householdId` onto each subscription (store it at write time), check `resource.data.householdId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.householdId`. Still two gets, but only on user profile (one per request).

### P1 `SubscriptionWidgetProvider` exported=true

**File**: `android/app/src/main/AndroidManifest.xml:49-57`

Exporting the widget provider is required for `AppWidgetManager.ACTION_APPWIDGET_UPDATE`. Not a direct vulnerability, but any custom intent handlers you add later need explicit `android:permission` checks. Document this constraint in the file.

### P2 Invite code search space

**File**: `lib/services/household_service.dart` — `generateInviteCode`

6-character alphanumeric = 32^6 ≈ 1B. `Random.secure()` is correct. Collisions are rare but non-zero; production-scale abuse (automated brute-force) is feasible if rate-limiting isn't enforced at the Firestore-rules level. Combined with the current "anyone can overwrite" write rule, a squatter can pre-claim popular codes.

**Fix**: the `/invites` rule fix above eliminates the write-side problem. For read-side brute force, require the invite doc to be deleted on accept (already done per `split_service.dart`) and add a Firebase Cloud Function (or Firebase App Check) to rate-limit.

### P2 `_ensureUserProfile` writes on every sign-in

**File**: `lib/services/auth_service.dart` (~line 200)

Called on every `signInWith*` — does `set(..., SetOptions(merge: true))` unconditionally. Costs one Firestore write per app launch for signed-in users. Change to `get()`-then-conditional-write, or to a rules-checked `create` + no-op on existing.

### P2 PII in logs

Many services log `debugPrint('Scheduling notifications for ${subscription.name}')` etc. `debugPrint` is stripped in release-mode Flutter logging to the terminal but still writes to Android logcat until `kReleaseMode` short-circuits. Confirm release builds don't surface sub names / prices in logcat.

---

## Phase 5 — Performance

### P1 Cold start

Sequential awaits (see Phase 3). Measure: launch time on a mid-range Android with airplane mode on — you'll see the Notification and Sync initialize steps block. Move everything non-critical off the boot path.

### P1 `Box<Subscription>` is eager, not lazy

**File**: `lib/services/database_service.dart`

`Hive.openBox<Subscription>` loads all records into memory at startup. Fine at 5 subs (free limit), costly at 500 (post-monetization or a power user).

**Fix**: `openLazyBox` for the subscriptions collection once the count exceeds ~50; wrap access in async getters.

### P1 `_locallyDeletedIds` grows unbounded

**File**: `lib/services/sync_service.dart`

A `Set<String>` of locally-deleted IDs, cleared only on Firestore remove events. If a remove never arrives (network partition, user offline), the set grows with every local delete for the lifetime of the app.

**Fix**: bound the set (LRU cache with TTL ~24h, or persist deletes to Hive with a tombstone timestamp and sweep on startup).

### P1 Firestore listener re-parses all docs per change

**File**: `lib/services/sync_service.dart:151-197`

`snapshots()` fires with every change but parses every doc in the snapshot into a `Subscription`. Firestore exposes per-doc change metadata (`docChanges`) — parse only what changed.

### P1 `upcomingRenewalsProvider` unbounded loop

See Phase 2. Same bug, performance impact.

### P2 `cleanupOldDeletedSubscriptions` iterates deletes

**File**: `lib/services/database_service.dart`

Deletes records one-by-one. Use `deleteAll(keys)` for batch deletion.

### P2 `home_widget_service.dart` runs conversions on main isolate

**File**: `lib/services/home_widget_service.dart:40-109`

Called on home-screen rebuild. All math is O(N) but runs synchronously on the UI thread. At 5 subs this is free; at 500 it's frame drops.

### P2 Three listeners watched in `home_screen.build`

See Phase 3. Performance cost is re-running Firestore I/O on every stateful rebuild.

---

## Phase 6 — Code Quality

### P1 Single smoke test

**File**: `test/widget_test.dart` (26 lines)

No tests for billing-cycle math, currency conversion, sync merge, household disband, or notification scheduling — exactly the logic most likely to contain the P0 bugs above. Minimum bar: one test file per service, starting with `subscription_test.dart` covering Jan 31 + Feb 29 + DST cases.

### P2 `debugPrint` is the only observability

Production builds emit nothing to Crashlytics / Sentry. Silent catches in `sync_service.dart`, `household_service.dart`, `currency_service.dart` hide errors from users and from you. Add `firebase_crashlytics` (already a FlutterFire dep) and wire catches to `FirebaseCrashlytics.instance.recordError`.

### P2 Duplicated logic

- `_addBillingCycle` lives in both `subscription.dart` and `analytics_providers.dart` (fixing one doesn't fix the other — high bug-recidivism risk).
- `_convertedHouseholdTotal` and `_convertedMyShare` in `home_screen.dart` duplicate what should be provider logic.
- `home_widget_service.dart` re-implements the monthly-total loop that already lives in `convertedTotalSpendProvider`.

### P2 Dead / commented code

- `pubspec.yaml` has 4 commented-out packages with phase markers.
- `notification_service.dart:47` has `// TODO: Navigate to subscription details`.
- `backup_ui_v1/` directory is untracked but present.

### P2 No accessibility audit

No `Semantics` widgets, no `excludeSemantics`, no test for screen-reader labels. Visual-only cues (color badges for renewal urgency) are not accompanied by text alternatives.

### P2 No localization infrastructure

`intl` is used for `DateFormat`, but no `flutter_localizations`, no ARB files. Hard-coded English strings everywhere. Fine for v1; blocks a German/Spanish launch.

---

## Phase 7 — Play Store & Release Readiness

### P0 No R8/ProGuard minification

**File**: `android/app/build.gradle`

No `buildTypes.release { minifyEnabled true; shrinkResources true; proguardFiles ... }`. Ship-able today, but:

1. APK/AAB is larger than necessary.
2. Firebase, Hive, and `flutter_local_notifications` all need keep rules in production. Without them, R8 (when you do enable it) will strip reflection-accessed classes and break sync / notifications silently in release.
3. Google Play's pre-launch report will flag this as a missed optimization.

**Fix**:
```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        signingConfig signingConfigs.release
    }
}
```

Add `android/app/proguard-rules.pro`:
```
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class * extends com.google.firebase.firestore.PropertyName { *; }
# Hive uses reflection on generated adapters — keep them
-keep class * extends hive.TypeAdapter { *; }
```

### P1 Keystore backup

**File**: `android/app/upload-keystore.jks` — per memory, not backed up offsite. Losing it means no updates, ever. Copy to a password-protected vault (1Password, Bitwarden) and a second offline location (USB in safe).

### P1 Permissions audit clean

`AndroidManifest.xml:3-4` declares `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` — both necessary. `SCHEDULE_EXACT_ALARM` was correctly removed (per memory, 2026-04-09). No excess permissions.

### P1 `android:allowBackup` default-true

See Phase 4. Should be explicitly `false`.

### P2 No CI / `flutter analyze` gate

No `.github/workflows/`, no `analysis_options.yaml` lint config beyond `flutter_lints: ^3.0.0` defaults. Regressions in the fixes above will not be caught pre-merge.

**Fix**: GitHub Actions workflow running `flutter analyze` + `flutter test` on PR, plus a nightly `flutter build appbundle --release` to catch build regressions.

### P2 No deep-link intent filters

`AndroidManifest.xml` has only the launcher intent. The notification-tap handler (`_onNotificationTapped` in `notification_service.dart:45`) has a `// TODO: Navigate to subscription details` comment — the feature is stubbed. Either ship the deep link (add an intent filter, route via GoRouter) or delete the comment.

### P2 Closed-testing blockers

Per memory: need 7 more testers (have 5, need 12) before 14-day timer starts. This is a process item, not code.

---

## Phase 8 — High-ROI Feature & Code Improvements

Ranked by impact/effort. Everything in Phase 2-7 should be fixed first; these are on top.

1. **Feature-folder restructure** (medium effort, high future-return). Move `screens/` + `widgets/` + `providers/` into `features/{auth, subscriptions, household, analytics, settings}/`. Unblocks clean work on monetization + recurring-invoice features you'll add post-launch.
2. **Unified `CurrencyResult` type** (small effort, high safety). Replace `double convert(...)` with `ConversionResult(value, isFallback, missingRates)`. Surfaces conversion failures to UI — otherwise the silent pass-through will keep causing ghost bugs.
3. **Single `BillingCycleCalculator` module** (small effort, high safety). Extract `_addBillingCycle` + `_addOneCycle` into `lib/utils/billing_cycle.dart`, make it the only source. Write 20+ unit tests for month-end, leap-year, DST cases.
4. **Lazy Hive + paginated subscription list** (medium effort, future-proofs power users). Switch `Box<Subscription>` → `LazyBox<Subscription>`. Home screen already displays 1-screen worth; load on demand.
5. **Crashlytics + structured logger** (small effort, very high observability). 30 minutes of setup, answers "why did my sub disappear?" tickets in seconds.
6. **Callable Cloud Functions for household accept/disband** (medium effort, high security). The Firestore rules are forced to be lax because the join flow needs to write to other users' docs. Move the flow behind a callable function with custom validation — rules can then lock down to "member-only read/write own docs."
7. **Deep linking for notification taps** (small effort, high UX). `flutter_local_notifications` response → GoRouter → subscription details. Completes the notification loop.
8. **Home widget: lazy data + WorkManager refresh** (small effort, medium UX). Current implementation refreshes when the app is opened. Use WorkManager (already implied by `android.permission.RECEIVE_BOOT_COMPLETED`) to refresh the widget every 6 hours while the app is backgrounded.
9. **Dynamic color (Material You)** (trivial effort, high UX). Uncomment `dynamic_color: ^1.6.8` in pubspec, wire up in `theme/app_theme.dart`. Android 12+ users get themed widgets.
10. **Accessibility pass** (medium effort, compliance). `Semantics` labels on icon-only buttons, verify with TalkBack. Required for accessibility-declared data-safety form on Play.
11. **Splash-screen branded cold start** (small effort, perceived-perf). Combined with async init (Phase 3), the user sees the branded splash → instant home instead of a white flash → delayed home.
12. **Budget alerts surfaced as notifications** (small effort, feature completion). `BudgetService.shouldShowAlert` exists but is only polled in `home_screen`. Wire it into `NotificationService` so alerts fire even when the app is closed.

---

## Prioritized Action List

### P0 — ship-blockers (fix before production track)

1. **Billing-cycle overflow** — `lib/models/subscription.dart:190-213` + `lib/providers/analytics_providers.dart:401-412`. Two files, one fix, ~2h including tests.
2. **Firestore rules: households + invites** — `firestore.rules:45-60`. Three rule blocks to tighten, ~1h. Deploy via Firebase Console.
3. **Trial expiry time-of-day vs midnight** — `lib/models/subscription.dart:341-365`. ~30min.
4. **R8 + ProGuard for release** — `android/app/build.gradle` + new `proguard-rules.pro`. ~1h including a test release build. Required before Play production track.
5. **Cross-currency price-change impact** — `lib/providers/analytics_providers.dart:140-151` + `lib/widgets/analytics/price_changes_section.dart:49-54`. ~1h.

### P1 — this sprint

6. Currency conversion returns `ConversionResult` (or nullable) instead of silent fallback — `lib/services/currency_service.dart:89, 113`.
7. Async non-critical init in `main.dart` — ~2h, measurable cold-start win.
8. `android:allowBackup="false"` in `AndroidManifest.xml`.
9. Weak email validator in `auth_screen.dart` — swap for a real regex or use Firebase's own validation path properly.
10. `home_screen` side-effects: move lifecycle providers to `ref.listen` in `initState`.
11. `syncInitProvider` / `householdCleanupProvider` cleaned of side-effects (move to controllers).
12. `SyncService.onRemoteDataChanged` singleton → listener list.
13. Hive migration strategy + schemaVersion + stub `_migrate`.
14. `_locallyDeletedIds` bounded / persisted.
15. Firestore `snapshots().docChanges` parsing in sync.
16. Crashlytics wired up.

### P2 — backlog

17. Billing-cycle calculator module + 20+ unit tests.
18. `flutter_local_notifications` ID scheme (replace `hashCode` with counter).
19. Locale-aware `NumberFormat.currency` in `currency_service.dart`.
20. Lazy Hive box for subscriptions (when count trends up).
21. Remove hardcoded `5` — use `AppConstants.freeSubscriptionLimit`.
22. `BillingCycle.custom` either implement (add `customDays`) or remove.
23. `DatabaseService.getAllSubscriptions()` default-excludes deleted/archived; callers opt in.
24. Per-service test files (sync merge, household disband, notification scheduling).
25. GitHub Actions CI running `flutter analyze` + `flutter test`.
26. Deep link + `GoRouter` integration for notification taps.
27. `cleanupOldDeletedSubscriptions` uses `deleteAll(keys)`.
28. Semantics / a11y audit pass.
29. `dynamic_color` re-enabled.
30. `_ensureUserProfile` → conditional write on sign-in.
31. Localization scaffold (ARB + `flutter_localizations`) even if only English ships for v1.
32. Feature-folder restructure as the codebase grows past ~25 screens.
33. Home widget refresh via WorkManager.
34. Budget alerts → notifications.

---

## Appendix: Files reviewed

Models: `subscription.dart`, `app_preferences.dart`, `budget.dart`, `exchange_rate.dart`.
Services: `database_service.dart`, `sync_service.dart`, `auth_service.dart`, `notification_service.dart`, `currency_service.dart`, `household_service.dart`, `split_service.dart`, `budget_service.dart`, `export_service.dart`, `home_widget_service.dart`, `preferences_service.dart`.
Providers: `subscription_providers.dart`, `analytics_providers.dart`, `sync_providers.dart`, `household_providers.dart`, `auth_providers.dart`, `currency_providers.dart`, `trial_providers.dart`, `budget_providers.dart`.
Screens: `home_screen.dart`, `settings_screen.dart`, `auth_screen.dart`, `analytics_screen.dart`.
Widgets: `subscription_card.dart`, `add_subscription_sheet.dart`, `analytics/price_changes_section.dart`.
Android: `AndroidManifest.xml`, `build.gradle`.
Firebase: `firestore.rules`.
Root: `pubspec.yaml`, `test/widget_test.dart`.
Utils: `constants.dart`.
