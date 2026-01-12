# Project Overview

Recurly is a minimal, world-class subscription tracking app for Android. Users manually track recurring subscriptions (Netflix, Spotify, etc.) with a beautiful Material You design that adapts to their wallpaper. The app is offline-first with optional sharing and freemium monetization (Free: 5 subs, Pro: $39.99/year unlimited).

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
- Flutter 3.27.1 / Dart 3.6.0
- Material 3 with static purple theme (fallback colors)
- Custom minimal design inspired by Things 3, Linear, Arc

**Backend:**
- None currently (Phase 1)
- Firebase planned for Phase 5 (sharing)

**Storage:**
- Hive 2.2.3 (offline-first local database)
- Type adapters for Subscription, BillingCycle, SubscriptionCategory, AppPreferences, TimeOfDayPreference

**State Management:**
- Riverpod 2.4.9 (StateNotifier pattern)

**Notifications:**
- flutter_local_notifications 17.2.4 (local notification scheduling)
- timezone 0.9.4 (timezone-aware notification scheduling)
- flutter_timezone 4.1.1 (device timezone detection)
- permission_handler 11.4.0 (runtime permission requests for Android 13+)

**Assets:**
- cached_network_image 3.3.0 (for future network images, currently using local assets)
- 18 subscription logos stored locally in assets/images/logos/

**Build/Tooling:**
- Android Gradle Plugin 8.7.3
- Gradle 8.9
- Kotlin 2.0.21
- Java 17
- Android NDK 27.0.12077973
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

---

# Current Features

**Implemented (Phase 1 - Complete):**
- ✅ Add subscription (name, price, billing cycle, category, first bill date)
- ✅ View subscriptions in clean Material 3 list
- ✅ Calculate total monthly spend
- ✅ Swipe RIGHT to edit subscription
- ✅ Swipe LEFT to delete (moves to recently deleted)
- ✅ Tap card to view details sheet
- ✅ Sort by date/price/name
- ✅ Archive subscriptions
- ✅ Recently Deleted screen (30-day retention, restore/permanent delete)
- ✅ Archived screen (view/restore/permanently delete)
- ✅ Settings screen (placeholder for future features)
- ✅ Empty states for all screens
- ✅ Form validation (required fields, numeric validation, ranges)
- ✅ Undo delete with snackbar action
- ✅ Renewal urgency color coding (< 7 days red, 7-14 days yellow, > 14 days blue)
- ✅ Days until renewal countdown
- ✅ Monthly equivalent calculation for yearly/weekly subscriptions

**Implemented (Phase 2 - Enhanced UX - Complete):**
- ✅ Text search by subscription name (real-time filtering)
- ✅ Subscription templates for 18 popular services
- ✅ Local logo assets (no CDN dependency)
- ✅ Template picker with categories in add subscription flow
- ✅ Pull-to-refresh to reload subscriptions
- ✅ Restore from Recently Deleted

**Implemented (Phase 3 - Notifications - Complete):**
- ✅ AppPreferences model with Hive storage
- ✅ PreferencesService for managing notification preferences
- ✅ NotificationService with flutter_local_notifications integration
- ✅ Android notification permissions (POST_NOTIFICATIONS + SCHEDULE_EXACT_ALARM)
- ✅ Core library desugaring enabled for Android compatibility
- ✅ Notification settings UI with full customization
- ✅ Notification time picker (default 9:00 AM)
- ✅ Integration with subscription CRUD operations (auto-schedule/cancel)
- ✅ Dynamic timezone detection via flutter_timezone
- ✅ Inexact fallback mechanism if exact alarms fail
- ✅ Debug UI to view pending notifications and send test alerts
- ✅ Fixed calendar math to align UI "Days until renewal" with system alarms

**Implemented (Phase 4 - Analytics & Polish - Complete):**
- ✅ Analytics screen with spending insights
- ✅ Category pie chart with vibrant gradients (red, blue, purple, mint, amber, pink)
- ✅ Smooth 2-second fill animation with staggered segments
- ✅ Monthly spending trend bar chart (6-month projection)
- ✅ Accurate billing calculations for monthly/yearly/weekly cycles
- ✅ Bottom navigation bar (Home, Analytics, Settings)
- ✅ Fade transitions between tabs
- ✅ Modern warm theme inspired by expense tracking apps
- ✅ Warm color palette (peach primary, sage secondary, warm dark backgrounds)
- ✅ Chart animations with cascading effects
- ✅ Fixed NotificationService instantiation efficiency
- ✅ Analytics providers with proper date-based projection logic

---

# Current Blockers

**None**

---

# Bugs Fixed (Phase 3 Session)

**Timezone Hardcoding:**
- Fixed bug where all notifications were scheduled for America/New_York
- **Solution:** Added flutter_timezone package to detect device location on startup

**Exact Alarm Permission (Android 13+):**
- Fixed issue where exact alarms might be blocked by system
- **Solution:** Explicitly request Permission.scheduleExactAlarm in NotificationService

**UI vs Notification Mismatch:**
- Fixed bug where "Tomorrow" was showing as "Today" (0 days) due to time-of-day math.
- **Solution:** Refactored `daysUntilRenewal` and `nextBillDate` to use calendar dates (midnight).

**Notification Skipping "Today":**
- Fixed logic that skipped today's renewal if the current time was past midnight.
- **Solution:** Updated `nextBillDate` to include today as a valid renewal date for active notifications.

---

# Bugs Fixed (Phase 4 Session - Claude Code)

**Analytics Projection Inaccuracy:**
- Fixed bug where yearly subscriptions showed cost every month instead of once per year
- Fixed bug where weekly subscriptions showed 1x cost instead of 4-5x per month
- **Solution:** Implemented date-based `_willBillInMonth()` and `_calculateMonthlyAmount()` functions

**NotificationService Inefficiency:**
- Fixed double instantiation of NotificationService in main.dart
- **Solution:** Reused single instance throughout initialization

**Theme Issues:**
- Reverted overly vibrant theme from Gemini edits to warm, professional palette
- **Solution:** Created warm color scheme (peach, sage, brown) inspired by modern expense trackers

**Pie Chart Overflow:**
- Fixed pie chart segments clipping outside container boundaries
- **Solution:** Used fixed 240x240px container with proper radius constraints (60-65px)

**Missing Animations:**
- Chart animations were too fast or imperceptible
- **Solution:** Increased pie chart animation to 2 seconds with staggered segments (80ms delay each)

**Hardcoded Chart Colors:**
- Charts used hardcoded colors instead of theme system
- **Solution:** Migrated all chart colors to AppTheme.getCategoryColor() and gradients

---

# How to Resume This Project

1. **Read PROJECT_STATE.md**
2. **Run the app:** `flutter run`
3. **Verify notifications:** Go to Settings -> Notifications -> View Pending Notifications
4. **Next Step:** Begin Phase 4: Analytics

---

# Version History

**v1.3.0 (Current - Phase 4 Complete)**
- Date: January 12, 2026
- Status: Analytics and UI polish complete with smooth animations
- Bottom navigation with 3 main tabs (Home, Analytics, Settings)
- Beautiful analytics charts with vibrant gradients and 2-second animations
- Warm modern theme (peach/coral/sage palette)
- Accurate spending projections for all billing cycles
- Fixed multiple Gemini implementation issues
- Professional polish with smooth transitions throughout

**v1.2.0 (Phase 3 Complete)**
- Date: January 12, 2026
- Status: Notification system fully functional and verified
- Fixed critical billing cycle and calendar math bugs
- Resolved delivery issues via dynamic timezone detection
- Added comprehensive notification debugging tools
