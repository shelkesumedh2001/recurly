# Project Overview

Recurly is a minimal, world-class subscription tracking app for Android. Users manually track recurring subscriptions (Netflix, Spotify, etc.) with a beautiful Material You design that adapts to their wallpaper. The app is offline-first with cloud sync, household sharing, and freemium monetization (Free: 5 subs, Pro: $39.99/year unlimited).

---

# Goals

**Primary Goal:**
- Help users track subscriptions, see total monthly spend, and never miss renewals

**Non-Goals:**
- NOT building automatic bank integration
- NOT a budgeting app or expense tracker
- NOT supporting web/desktop (Android-first, iOS later)
- NOT using third-party Material You libraries (removed dynamic_color due to compatibility issues)

---

# Tech Stack

**Frontend:**
- Flutter 3.41.2 / Dart 3.11.0
- Material 3 with dark warm brown theme + theme customization (presets & custom colors)
- Custom minimal design inspired by Things 3, Linear, Arc

**Backend:**
- Firebase Core 3.8.1 (app initialization)
- Firebase Auth 5.4.1 (Google, Email/Password, Apple sign-in)
- Cloud Firestore 5.6.2 (cloud sync, household data, split proposals)
- Google Sign-In 6.2.2 (Google OAuth)
- Sign In With Apple 6.1.4 (Apple OAuth, iOS)
- crypto 3.0.6 (Apple sign-in nonce hashing)

**Storage:**
- Hive 2.2.3 (offline-first local database, source of truth)
- Type adapters for Subscription, BillingCycle, SubscriptionCategory, AppPreferences, TimeOfDayPreference
- Additional models: Budget, CustomCategory, ExchangeRate, ThemePreferences
- Firestore for cloud backup, household data, split proposals (synced from Hive)

**State Management:**
- Riverpod 2.4.9 (StateNotifier pattern)

**Notifications:**
- flutter_local_notifications 17.2.4 (local notification scheduling)
- timezone 0.9.4 (timezone-aware notification scheduling)
- flutter_timezone 4.1.1 (device timezone detection)
- permission_handler 11.4.0 (runtime permission requests for Android 13+)

**Analytics & Charts:**
- fl_chart 0.71.0 (pie charts, bar charts, line charts with animations)
- table_calendar 3.1.2 (renewal calendar heatmap view)
- 8 analytics features: sub count chart, price tracking, cancel simulator, monthly comparison, renewal forecast, budget gauge, split savings, who-pays-more

**Export:**
- csv 6.0.0 (CSV file generation)
- pdf 3.11.0 (PDF report generation)
- share_plus 10.0.0 (native share sheet integration)
- path_provider 2.1.0 (temp file storage for exports)

**Assets:**
- cached_network_image 3.3.0 (for future network images, currently using local assets)
- 18 subscription logos stored locally in assets/images/logos/

**Multi-Currency:**
- 20 supported currencies (USD, EUR, GBP, INR, JPY, CNY, KRW, CAD, AUD, etc.)
- Exchange rate fetching & caching via CurrencyService
- Display currency persisted to AppPreferences (HiveField 6)
- CurrencyInfo class with symbols and country flag emojis

**Budget & Categories:**
- BudgetService for monthly/category budget tracking
- CustomCategoryService for user-defined categories
- Budget providers and category providers (Riverpod)

**Theming:**
- ThemeService with theme presets and custom color support
- ThemePreferences model for persisting user theme choices
- Theme presets defined in lib/theme/theme_presets.dart

**Trial Tracking:**
- Trial/free subscription tracking with badges
- Trial providers for state management

**Android Widget:**
- Home screen widget showing monthly spend, subscription count, next renewal
- SubscriptionWidgetProvider (Kotlin)
- Widget layout XML, drawable backgrounds, widget info XML

**Build/Tooling:**
- Android Gradle Plugin 8.9.3
- Gradle 8.12.1
- Kotlin 2.0.21
- Java 17
- Android NDK 27.0.12077973
- Android minSdkVersion 23 (required by Firebase Auth)
- build_runner for Hive code generation

---

# Architecture Decisions

**Decision:** Clean Architecture / MVVM pattern
- **Reason:** Separation of concerns, testability, scalability
- **Consequence:** Clear folder structure (models/providers/screens/widgets/services/theme/utils)

**Decision:** Hive instead of SQLite
- **Reason:** Faster, offline-first, no SQL boilerplate
- **Consequence:** Requires build_runner for type adapters, stores data as objects

**Decision:** Removed dynamic_color package
- **Reason:** Version 1.8.1 incompatible with Flutter 3.27.1 (toARGB32 method error)
- **Consequence:** Using static Material 3 theme with fallback colors, no wallpaper adaptation yet

**Decision:** Recently Deleted instead of immediate deletion
- **Reason:** Prevent accidental data loss (iOS-style safety)
- **Consequence:** Added deletedAt field, 30-day grace period, auto-cleanup logic

**Decision:** Swipe gestures for edit/delete
- **Reason:** Faster, more intuitive than menus
- **Consequence:** Dismissible widget with background indicators

**Decision:** Bottom sheets for forms and menus
- **Reason:** Modern, minimal, less intrusive than full screens
- **Consequence:** Consistent UI pattern across app

**Decision:** Local assets for subscription logos (Phase 2)
- **Reason:** CDN logos (logo.clearbit.com) unreliable, many services missing/broken
- **Consequence:** Added 18 PNG logos to assets, app bundle size increased by ~2MB, no network dependency

**Decision:** No hardcoded prices in templates (Phase 2)
- **Reason:** Prices vary by country, plan tier, and change over time
- **Consequence:** Users must enter their actual subscription price, templates only pre-fill name/logo/category

**Decision:** copyWith with clearDeletedAt flag (Phase 2)
- **Reason:** Dart's nullable parameter issue (deletedAt: null doesn't actually set null)
- **Consequence:** Added boolean flag pattern for explicitly clearing nullable fields

**Decision:** Core library desugaring for Android (Phase 3)
- **Reason:** flutter_local_notifications requires Java 8+ APIs not available on older Android versions
- **Consequence:** Enabled coreLibraryDesugaringEnabled in build.gradle, added desugar_jdk_libs dependency

**Decision:** Timezone-aware notification scheduling (Phase 3)
- **Reason:** Notifications must fire at consistent local times regardless of timezone changes
- **Consequence:** Using timezone package with tz.local, initialize timezone database in main() using flutter_timezone.

**Decision:** Exact alarms for notification reliability (Phase 3)
- **Reason:** Android may delay or batch inexact alarms, causing missed renewal reminders
- **Consequence:** Using exactAllowWhileIdle mode, requires SCHEDULE_EXACT_ALARM permission on Android 13+.

**Decision:** Calendar-based date math for UI and Notifications (Phase 3)
- **Reason:** Using exact timestamps caused confusion (e.g., Tomorrow appearing as Today) and skipped notifications.
- **Consequence:** All renewal math now uses normalized calendar dates (midnight-to-midnight) for consistency between UI and system alarms.

**Decision:** DisplayCurrencyNotifier with Hive persistence (Phase 4.5)
- **Reason:** Simple StateProvider didn't persist display currency after app restart
- **Consequence:** StateNotifierProvider that loads from and saves to AppPreferences automatically

**Decision:** PDF-safe currency symbols (Phase 4.5)
- **Reason:** Default PDF font doesn't support Unicode currency symbols (€, ₹, ₩ rendered as white boxes)
- **Consequence:** Added `_getPdfSafeSymbol()` method using ASCII-safe representations (EUR, INR, KRW, etc.)

**Decision:** Flat widget layout for Android home screen widget (Phase 4.5)
- **Reason:** Nested LinearLayouts caused RemoteViews inflation errors on some devices
- **Consequence:** Simplified to flat structure with only TextViews, basic styling (no rounded corners)

**Decision:** Generic payment icon in add subscription form (Phase 4.5)
- **Reason:** Hardcoded `Icons.attach_money` ($ icon) didn't match selected currency
- **Consequence:** Changed to `Icons.payments_outlined`, `prefixText` shows correct symbol dynamically

**Decision:** Hive as source of truth with Firestore sync (Phase 5)
- **Reason:** Preserve offline-first experience; cloud is backup/sync, not primary store
- **Consequence:** All reads from Hive, writes push to Firestore. Remote listener updates Hive. Last-write-wins on `updatedAt`.

**Decision:** Partner subscriptions in-memory only (Phase 5)
- **Reason:** Partner's subs should not pollute local Hive store; they're read-only and ephemeral
- **Consequence:** SyncService exposes `partnerSubscriptions` as ValueNotifier<List<Subscription>>, not persisted to Hive

**Decision:** Singleton pattern for Firebase services (Phase 5)
- **Reason:** Single Firestore/Auth instance needed; services manage listeners and state
- **Consequence:** AuthService, SyncService, HouseholdService, SplitService all use factory singleton pattern

**Decision:** Pro required to create household, not to join (Phase 5)
- **Reason:** Lower barrier to entry for partners; only one person needs Pro
- **Consequence:** `isProFromProfileProvider` gates "Create Household" button; join is open to all signed-in users

**Decision:** minSdkVersion 23 for Android (Phase 5)
- **Reason:** Firebase Auth requires minimum API 23 (Android 6.0)
- **Consequence:** Changed from `flutter.minSdkVersion` (21) to hardcoded `23` in build.gradle

**Decision:** Firebase project with real google-services.json (Phase 5)
- **Reason:** Required for Firebase Auth, Firestore sync, and Google Sign-In to function
- **Consequence:** Real config with OAuth clients and SHA-1; Firestore security rules deployed; Auth providers enabled

---

# Current Features

**Implemented (Phase 1 - Complete):**
- Add subscription (name, price, billing cycle, category, first bill date)
- View subscriptions in clean Material 3 list
- Calculate total monthly spend
- Swipe RIGHT to edit subscription
- Swipe LEFT to delete (moves to recently deleted)
- Tap card to view details sheet
- Sort by date/price/name
- Archive subscriptions
- Recently Deleted screen (30-day retention, restore/permanent delete)
- Archived screen (view/restore/permanently delete)
- Settings screen
- Empty states for all screens
- Form validation (required fields, numeric validation, ranges)
- Undo delete with snackbar action
- Renewal urgency color coding (< 7 days red, 7-14 days yellow, > 14 days blue)
- Days until renewal countdown
- Monthly equivalent calculation for yearly/weekly subscriptions

**Implemented (Phase 2 - Enhanced UX - Complete):**
- Text search by subscription name (real-time filtering)
- Subscription templates for 18 popular services
- Local logo assets (no CDN dependency)
- Template picker with categories in add subscription flow
- Pull-to-refresh to reload subscriptions
- Restore from Recently Deleted

**Implemented (Phase 3 - Notifications - Complete):**
- AppPreferences model with Hive storage
- PreferencesService for managing notification preferences
- NotificationService with flutter_local_notifications integration
- Android notification permissions (POST_NOTIFICATIONS + SCHEDULE_EXACT_ALARM)
- Core library desugaring enabled for Android compatibility
- Notification settings UI with full customization
- Notification time picker (default 9:00 AM)
- Integration with subscription CRUD operations (auto-schedule/cancel)
- Dynamic timezone detection via flutter_timezone
- Inexact fallback mechanism if exact alarms fail
- Debug UI to view pending notifications and send test alerts
- Fixed calendar math to align UI "Days until renewal" with system alarms

**Implemented (Phase 4 - Analytics & Polish - Complete):**
- Analytics screen with spending insights
- Category pie chart with vibrant gradients (red, purple, cyan, pink, orange, green)
- Smooth 2-second fill animation with staggered segments
- Monthly spending trend bar chart (6-month projection)
- Accurate billing calculations for monthly/yearly/weekly cycles
- Bottom navigation bar (Home, Analytics, Settings)
- Fade transitions between tabs
- Modern warm theme inspired by expense tracking apps
- Chart animations with cascading effects
- Fixed NotificationService instantiation efficiency
- Analytics providers with proper date-based projection logic

**Implemented (Phase 4.5 - Analytics Expansion & Multi-Currency - Complete):**
- New dark warm brown theme - Deep brown background (#1A1514), coral FAB (#F4A089)
- Category drill-down - Tap any pie chart segment or legend to see subscriptions
- Renewal calendar heatmap - Calendar view with color intensity based on spend
- Export to CSV - All subscriptions with prices, cycles, categories in display currency
- Export to PDF - Formatted reports with summary stats, subscription table, category breakdown
- Analytics tab navigation - Overview and Calendar tabs
- Total in pie chart center - Shows total monthly spend in donut hole
- Multi-currency support - 20 currencies with exchange rate fetching & caching
- Display currency preference - Persisted to Hive via DisplayCurrencyNotifier
- Budget tracking system - Monthly and per-category budgets with BudgetService
- Custom categories - User-defined categories with CRUD via CustomCategoryService
- Theme customization - Theme presets and custom color picker via ThemeService
- Trial/free subscription tracking - Trial badges and notifications
- Android home screen widget - Shows monthly spend, subscription count, next renewal
- Currency-aware exports - CSV and PDF use display currency with correct symbols

**Implemented (Phase 5 - Firebase Auth, Cloud Sync, Household & Splitting - Complete):**
- Firebase Authentication (Google Sign-In, Email/Password, Apple Sign-In)
- Auth screen with multiple sign-in methods and "Continue without account" option
- Profile screen with avatar, name, email, Pro badge, sign out, delete account
- Cloud Firestore sync (Hive <-> Firestore, bidirectional, last-write-wins)
- SyncService with first sign-in migration (upload local data or merge)
- Sync status indicator in app bar (syncing/synced/error/offline)
- Force re-sync on tap
- Household system - Create household (Pro required), invite partner via 6-char code
- Join household with invite code (validates expiry, max 2 members)
- Household screen showing members, invite code, leave/disband actions
- Invite code card with copy, share, and refresh functionality
- Partner subscription visibility - See household partner's subscriptions (read-only)
- Spend view toggle - Switch between "My Share" and "Household Total" views
- Per-subscription splitting - Propose split with custom percentage (10-90%)
- Split proposal flow - Partner receives, accepts/rejects proposals
- Split request notification badge on home screen
- Split requests screen listing pending proposals
- Subscription card shows partner badge and split icon
- Details sheet has "Split with Partner" button when in household
- Data migration screen for first sign-in (upload local subs to cloud)
- Subscription model extended with ownerUid, householdVisible, splitWith fields
- Auth-aware settings screen (profile info when signed in, "Sign In" when not)
- Sync and household cards in settings
- Analytics respect spend view mode toggle
- Graceful degradation - App works identically when not signed in

---

# Firestore Data Model

```
users/{uid}
  displayName, email, photoUrl, isPro, householdId?, createdAt, updatedAt

users/{uid}/subscriptions/{subId}
  // mirrors Subscription.toJson() + these fields:
  ownerUid: string
  householdVisible: bool (default true)
  splitWith: [{ uid, sharePercent, accepted }]

users/{uid}/split_proposals/{subId}
  subId, ownerUid, partnerUid, subscriptionName, totalPrice,
  partnerSharePercent, accepted, createdAt

households/{householdId}
  name, createdBy (uid), members: [uid, uid], inviteCode, inviteExpiry, createdAt

invites/{inviteCode}
  householdId, createdBy, expiry
```

---

# Hive Field Allocations

| HiveField | Field | Type | Phase |
|-----------|-------|------|-------|
| 0 | id | String | 1 |
| 1 | name | String | 1 |
| 2 | price | double | 1 |
| 3 | currency | String | 1 |
| 4 | billingCycle | BillingCycle | 1 |
| 5 | firstBillDate | DateTime | 1 |
| 6 | category | SubscriptionCategory | 1 |
| 7 | logoUrl | String? | 2 |
| 8 | color | String? | 1 |
| 9 | notes | String? | 1 |
| 10 | isArchived | bool | 1 |
| 11 | createdAt | DateTime | 1 |
| 12 | deletedAt | DateTime? | 1 |
| 13 | updatedAt | DateTime? | 4.5 |
| 14 | isFreeTrial | bool | 4.5 |
| 15 | trialEndDate | DateTime? | 4.5 |
| 16 | priceAfterTrial | double? | 4.5 |
| 17 | customCategoryId | String? | 4.5 |
| 18 | ownerUid | String? | 5 |
| 19 | householdVisible | bool (default true) | 5 |
| 20 | splitWith | List<Map<String, dynamic>>? | 5 |
| 21 | priceHistory | List<Map<String, dynamic>>? | 5.5 |

---

# Current Status

**Pre-launch polish complete. Preparing for Play Store launch.**

**Strategy:** Launch free for all users (Pro gates disabled), build user base first, add monetization later via RevenueCat.

**Firebase Setup (Completed 2026-02-23):**
- ✅ Real `google-services.json` with OAuth clients and SHA-1 fingerprint
- ✅ Auth providers enabled (Google, Email/Password)
- ✅ Firestore database created
- ✅ Security rules — no Pro/Free conflicts (Pro was client-side only)
- ⚠️ Apple Sign-In requires Apple Developer account setup (not blocking Android)
- ⚠️ Firestore rules are deployed manually via Firebase Console (not CLI) — copy from `firestore.rules`

**Pre-Launch Polish (2026-03-05):**
- ✅ Pro gates disabled — all features free for all users
- ✅ Privacy policy screen added (in-app)
- ✅ Report a Bug opens email compose
- ✅ Details sheet has Edit, Delete, Archive, Close buttons
- ✅ Swipe gesture hint on first card (fades + collapses after 3s)
- ✅ AGP 8.9.3 + Gradle 8.12.1
- ✅ End-to-end testing complete (all tests pass)

**Remaining for Play Store:**
- Feature graphic (1024x500 banner — make in Canva)
- Privacy policy URL on shelke.tech
- Upload to Play Console (listing, AAB, screenshots, content rating)
- Back up keystore to safe location
- See DEV_STATUS.md for full TODO checklist

**Release Build Info:**
- Package: `com.sumedh.recurly`
- AAB: `build/app/outputs/bundle/release/app-release.aab` (51MB)
- Build cmd: `flutter build appbundle --release --no-tree-shake-icons`
- Signing: `android/app/upload-keystore.jks` (alias: `upload`)
- SHA-1: `54:A3:F9:91:FF:83:D8:AA:66:29:2B:10:59:F9:9C:54:55:8A:C7:57`

**Implemented (Phase 5.5 - Advanced Analytics - Complete):**
- Subscription count line chart — 12-month history of active sub count
- Price change tracking — detects edits, stores priceHistory (HiveField 21), shows cards with % change
- Cancel simulator — tap any sub to see monthly/yearly/5-year savings if cancelled
- Monthly comparison chip — delta badge in hero stats showing spend change vs last month
- Renewal forecast timeline — horizontal scrollable 30-day upcoming charges view
- Budget vs actual gauge — circular arc with animated fill, color-coded by budget status (self-hides if no budget)
- Split savings card — "Saving X/mo by splitting" insight (self-hides if no household)
- Who pays more bar — animated comparison bars for you vs partner spending (self-hides if no household)
- Balanced chart color palette — warm coral, rich violet, vibrant teal, berry pink, golden amber, emerald green
- Sleeker pie chart — thinner segments, larger center hole, no borders, simpler legend

---

# Currency System Architecture

```
displayCurrencyProvider (StateNotifierProvider<DisplayCurrencyNotifier, String>)
    ↓ (persisted to AppPreferences via Hive)
convertedTotalSpendProvider (converts all subs to display currency)
    ↓
formatCurrencyProvider (formats with correct symbol)
    ↓
CurrencyService.formatAmount() (handles decimals, thousands separators)
```

---

# Sync Architecture

```
User Action (add/edit/delete subscription)
    ↓
SubscriptionNotifier (updates Hive)
    ↓
_syncPush() / _syncDelete() (if signed in)
    ↓
SyncService.pushSubscription() → Firestore

Firestore Remote Change
    ↓
SyncService._startRemoteListener() (Firestore snapshots)
    ↓
Conflict resolution (last-write-wins on updatedAt)
    ↓
DatabaseService.updateSubscription() (Hive)
    ↓
onRemoteDataChanged callback → SubscriptionNotifier.loadSubscriptions()
```

---

# Household & Split Architecture

```
Household Creation (Pro user)
    ↓
HouseholdService.createHousehold() → Firestore households/{id}
    ↓
Generate 6-char invite code → Firestore invites/{code}

Partner Joins
    ↓
HouseholdService.joinHousehold(code) → validates, adds to members

Subscription Visibility
    ↓
SyncService.initializeHouseholdSync() → listens to partner's subs
    ↓
partnerSubscriptions (ValueNotifier, in-memory only)

Split Flow
    ↓
SplitService.proposeSplit() → Firestore split_proposals/{subId}
    ↓
Partner accepts → reference sub created in partner's Firestore + local Hive
    ↓
myShareSpendProvider factors in split percentages

Disband/Leave Flow
    ↓
cleanupOwnSplitData(uid) → deletes own proposals, reference subs, clears splitWith
    ↓
Partner device: householdCleanupProvider detects household gone → self-cleans
```

---

# How to Resume This Project

1. **Read PROJECT_STATE.md** (this file)
2. **Check DEV_STATUS.md** — has detailed bug fix notes and test checklist
3. **Deploy Firestore rules:** Copy `firestore.rules` content into Firebase Console → Firestore → Rules
4. **Run the app:** `flutter run`
5. **Next Steps:**
   - Complete end-to-end testing (Tests 6, 7, 10 in DEV_STATUS.md)
   - Verify all 8 analytics features on device
   - Commit all code (Phases 5 + 5.5, still uncommitted)
   - Phase 6: Monetization (RevenueCat, Free/Pro tiers)

---

# Version History

**v2.2.0 (Current - Pre-Launch Polish)**
- Date: March 5, 2026
- Status: Ready for Play Store submission
- Pro gates disabled (free for all users)
- Privacy policy screen (in-app)
- Report a Bug email integration (url_launcher)
- Subscription details sheet: Edit, Delete, Archive, Close buttons
- Swipe gesture hint bar with fade+collapse animation
- AGP 8.9.3, Gradle 8.12.1

**v2.1.0 (Phase 5.5 Advanced Analytics)**
- Date: February 25, 2026
- Status: 8 analytics features added to analytics screen
- Subscription count line chart (12-month history)
- Price change tracking with priceHistory field (HiveField 21)
- Cancel simulator bottom sheet
- Monthly comparison delta chip in hero stats
- Renewal forecast timeline (30-day horizontal scroll)
- Budget vs actual gauge (animated arc, self-hiding)
- Split savings card (self-hiding)
- Who pays more comparison bar (self-hiding)
- Refined chart colors and pie chart aesthetics
- New analytics widget files in lib/widgets/analytics/
- Extended analytics_providers.dart with 6 new providers + data classes

**v2.0.0 (Phase 5 Firebase & Sharing Complete)**
- Date: February 23, 2026
- Status: Firebase Auth, Cloud Sync, Household Sharing, Subscription Splitting
- Firebase Authentication (Google, Email/Password, Apple)
- Bidirectional Firestore <-> Hive sync for all signed-in users
- Household system with invite codes (max 2 members)
- Per-subscription splitting with custom percentages
- Spend view toggle (My Share / Household Total)
- Partner subscription visibility (read-only)
- Sync status indicator with force re-sync
- Data migration flow for first sign-in
- 22 new files, 12 modified files

**v1.5.0 (Phase 4.5 Multi-Currency & Polish Complete)**
- Date: January 17, 2026
- Multi-currency support with 20 currencies and exchange rate caching
- Budget tracking, custom categories, theme customization
- Trial/free subscription tracking
- Android home screen widget
- Currency-aware CSV & PDF exports

**v1.4.0 (Phase 4.5 Analytics Expansion)**
- Date: January 13, 2026
- New dark warm brown theme
- Category drill-down, renewal calendar heatmap
- Export to CSV and PDF

**v1.3.0 (Phase 4 Complete)**
- Date: January 12, 2026
- Analytics charts, bottom navigation, warm modern theme

**v1.2.0 (Phase 3 Complete)**
- Date: January 12, 2026
- Notification system fully functional
