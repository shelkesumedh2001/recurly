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
- Type adapters for Subscription, BillingCycle, SubscriptionCategory

**State Management:**
- Riverpod 2.4.9 (StateNotifier pattern)

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

**In Progress:**
- None (Phase 1 complete)

**Planned (Future Phases):**
- Phase 2: Enhanced UX (search/filter, subscription templates, pull-to-refresh)
- Phase 3: Notifications (renewal reminders, custom timing)
- Phase 4: Analytics (spending trends, category breakdown, charts)
- Phase 5: Sharing & Sync (Firebase auth, Firestore, family sharing)
- Phase 6: Monetization (RevenueCat, Pro features, IAP)
- Phase 7: iOS Launch

---

# Known Constraints

**Platform:**
- Android 12+ for full Material You support (dynamic colors disabled for now)
- OnePlus 9 (LE2111) as primary test device
- No iOS support yet

**Technical:**
- dynamic_color package incompatible (using static theme)
- Hive requires build_runner after model changes
- Hot reload doesn't work for generated files (requires restart)

**Development:**
- Solo developer
- No backend yet (offline-first)
- Free tier limited to 5 subscriptions (not enforced yet)

---

# Current Blockers

**None** - Phase 1 is complete and app is fully functional

---

# File Structure

```
lib/
├── models/
│   ├── subscription.dart        # Main data model
│   ├── subscription.g.dart      # Generated Hive adapter
│   ├── enums.dart              # BillingCycle, SubscriptionCategory
│   └── enums.g.dart            # Generated Hive adapters
├── providers/
│   └── subscription_providers.dart  # Riverpod state management
├── screens/
│   ├── home_screen.dart        # Main screen
│   ├── archived_screen.dart    # Archived subscriptions
│   ├── recently_deleted_screen.dart  # 30-day deletion
│   └── settings_screen.dart    # Settings placeholder
├── widgets/
│   ├── subscription_card.dart  # Swipeable card
│   └── add_subscription_sheet.dart  # Add/edit form
├── services/
│   └── database_service.dart   # Hive CRUD operations
├── theme/
│   └── app_theme.dart          # Material 3 theme config
├── utils/
│   ├── constants.dart          # App constants, spacing
│   └── extensions.dart         # DateTime, BuildContext helpers
└── main.dart                   # Entry point
```

---

# Data Model

**Subscription (Hive typeId: 0):**
- `id` (String) - UUID
- `name` (String) - Service name
- `price` (double) - Cost per billing cycle
- `currency` (String) - USD/EUR/GBP/INR
- `billingCycle` (BillingCycle) - monthly/yearly/weekly/custom
- `firstBillDate` (DateTime) - Initial subscription date
- `category` (SubscriptionCategory) - entertainment/utilities/health/finance/productivity/other
- `logoUrl` (String?) - Optional logo path
- `color` (String?) - Optional hex color
- `notes` (String?) - Optional user notes
- `isArchived` (bool) - Soft delete flag
- `createdAt` (DateTime) - Creation timestamp
- `sharedWith` (List<String>?) - UIDs for sharing (Phase 5)
- `deletedAt` (DateTime?) - Recently deleted timestamp

**Computed Properties:**
- `nextBillDate` - Calculated from firstBillDate + billingCycle
- `daysUntilRenewal` - Days between now and nextBillDate
- `monthlyEquivalent` - Normalized monthly cost (yearly/12, weekly*52/12)
- `renewalUrgency` - urgent/warning/normal based on days

---

# Design System

**Colors:**
- Primary: #6750A4 (purple)
- No dynamic Material You (disabled due to package issues)
- Renewal urgency: Red (< 7 days), Yellow (7-14 days), Blue (> 14 days)

**Typography:**
- Display Large (48sp, bold) - Monthly total
- Headline Medium (28sp, bold) - Screen titles
- Title Medium (16sp, semibold) - Subscription names
- Body Medium (14sp, regular) - Descriptive text

**Spacing (8dp grid):**
- 4dp, 8dp, 12dp, 16dp, 24dp, 32dp, 48dp

**Components:**
- Cards: 20dp radius, subtle borders, minimal shadows
- Bottom sheets: 24dp radius, drag handle
- Buttons: FilledButton for primary, OutlinedButton for secondary
- FAB: Single + button for add subscription

---

# Key User Flows

**Add Subscription:**
1. Tap FAB → Bottom sheet appears
2. Fill form (name, price, cycle, category, date)
3. Validation runs on submit
4. Tap SAVE → Snackbar confirms → Returns to home
5. Card appears in list, monthly total updates

**Edit Subscription:**
1. Swipe RIGHT on card → Edit sheet appears (pre-filled)
2. Modify fields
3. Tap SAVE → Updates in Hive → Snackbar confirms

**Delete Subscription:**
1. Swipe LEFT on card → Confirmation dialog
2. Confirm → Moves to Recently Deleted → Snackbar with Undo
3. Tap Undo → Restores immediately
4. After 30 days → Auto-deletes permanently

**Archive/Restore:**
1. Tap card → Details sheet → Tap Archive
2. Confirm → Moves to Archived screen
3. Menu → Archived → Swipe RIGHT to restore

---

# Common Commands

**Development:**
```bash
# Run app (debug mode)
flutter run

# Hot reload (after UI changes)
# Press 'r' in terminal

# Hot restart (after state changes)
# Press 'R' in terminal

# Regenerate Hive adapters (after model changes)
dart run build_runner build --delete-conflicting-outputs

# Clean build
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run

# Check for issues
flutter analyze
```

**Testing Device:**
- OnePlus 9 (LE2111) - Android 14 (API 34)
- USB debugging enabled

---

# How to Resume This Project

**Start of New Session:**

1. **Read this file first** (`PROJECT_STATE.md`)

2. **Check app state:**
   ```bash
   cd /home/sumedh/app
   flutter devices  # Ensure OnePlus 9 connected
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

4. **If model changes were made:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter run
   ```

5. **Open these files to understand current state:**
   - `lib/screens/home_screen.dart` - Main UI
   - `lib/models/subscription.dart` - Data structure
   - `lib/services/database_service.dart` - Data operations
   - `lib/providers/subscription_providers.dart` - State management

6. **Key testing flows:**
   - Add subscription → Swipe to edit → Swipe to delete → Check recently deleted
   - Test menu → Sort/Archived/Recently Deleted/Settings
   - Verify monthly total calculations

**Next Priorities (if continuing development):**
- Phase 2: Add search/filter functionality
- Phase 2: Create subscription templates (Netflix, Spotify presets)
- Phase 3: Local notifications for renewals
- Phase 4: Basic analytics (spending trends)

**Before Making Changes:**
- Always run app first to verify current state
- Check if Hive adapters need regeneration
- Update this file if architecture decisions change
- Keep this file under 400 lines

---

# Version History

**v1.0.0 (Current - Phase 1 Complete)**
- Date: January 2026
- Status: Production-ready for Phase 1 features
- Core CRUD operations complete
- Recently Deleted safety feature implemented
- All screens designed and functional
- No known blockers
