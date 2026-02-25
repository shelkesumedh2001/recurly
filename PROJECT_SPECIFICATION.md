# Recurly - Project Specification v2.0

## 📋 Executive Summary

**Product**: Recurly - Subscription tracking app with Material You design
**Platform**: Android (Primary), iOS (Future)
**Framework**: Flutter 3.19+ with Dart 3.3+
**Monetization**: Freemium (Free: 5 subs, Pro: $39.99/year for unlimited)
**Status**: Phase 4 Complete ✅ | Phase 4.5 Complete ✅ | Phase 5 Complete ✅ | Phase 5.5 Complete ✅

---

## 🎯 Core Value Proposition

Help users:
1. Never miss a renewal date (via notifications)
2. See total monthly spending at a glance
3. Share subscription info with family/partner
4. Make informed decisions about which subscriptions to keep

---

## 🏗️ Technical Architecture

### Tech Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Framework | Flutter | 3.27+ | Cross-platform UI |
| Language | Dart | 3.6+ | Type-safe development |
| State Management | Riverpod | 2.4+ | Reactive state |
| Local Database | Hive | 2.2+ | Offline-first storage |
| Backend | Firebase | Latest | Auth, Firestore sync & households |
| Monetization | RevenueCat | 6.20+ | IAP management |
| Theming | dynamic_color | Disabled | Material You (Compatibility issues) |
| Charts | fl_chart | 0.66+ | Analytics visualization |
| Notifications | flutter_local_notifications | 17.2+ | Renewal reminders |

### Architecture Pattern

**Clean Architecture / MVVM**

```
Presentation Layer (UI)
    ↓
Business Logic Layer (Providers/Services)
    ↓
Data Layer (Models/Database)
```

**Benefits:**
- Testable: Each layer can be tested independently
- Maintainable: Changes in one layer don't affect others
- Scalable: Easy to add new features

### Folder Structure

```
lib/
├── models/           # Data entities (Subscription, Category, Household, UserProfile, SplitProposal)
├── providers/        # State management (Riverpod) - subscriptions, auth, household, sync, split
├── screens/          # Full-page UI components (home, auth, household, profile, analytics, settings)
├── widgets/          # Reusable UI components (cards, sheets, indicators)
├── services/         # Business logic (Database, Notifications, Auth, Sync, Household, Split)
├── theme/            # Theming and styling
├── utils/            # Helpers, constants, extensions
└── main.dart         # App entry point with Firebase initialization
```

---

## 📊 Data Model

### Subscription Entity

```dart
class Subscription {
  // Identity
  String id;              // UUID

  // Core fields
  String name;            // e.g., "Netflix"
  double price;           // e.g., 15.99
  String currency;        // USD, EUR, GBP, INR
  BillingCycle cycle;     // monthly, yearly, weekly, custom
  DateTime firstBillDate; // When subscription started

  // Organization
  SubscriptionCategory category;

  // Customization (optional)
  String? logoUrl;        // Path to logo asset
  String? color;          // Hex color for branding
  String? notes;          // User notes

  // State
  bool isArchived;        // Soft delete
  DateTime createdAt;

  // Sharing
  List<String>? sharedWith; // UIDs of family members

  // Computed properties (not stored)
  DateTime nextBillDate;
  int daysUntilRenewal;
  double monthlyEquivalent;
  RenewalUrgency urgency;
}
```

### Enums

```dart
enum BillingCycle { monthly, yearly, weekly, custom }
enum SubscriptionCategory {
  entertainment, utilities, health, finance, productivity, other
}
enum RenewalUrgency { urgent, warning, normal } // <7, 7-14, >14 days
```

### Database Schema (Hive)

**Box**: `subscriptions` (typeId: 0)
- Stores all Subscription objects
- Indexed by UUID
- Auto-backup enabled

**Box**: `settings` (typeId: 3)
- User preferences
- Pro status
- Notification settings

---

## 🎨 Design System (Material You)

### Color System

**Dynamic Colors** (Android 12+):
- Extract colors from wallpaper using `dynamic_color` package
- Automatically generates full color scheme
- Supports light and dark themes
- *Note: Temporarily disabled in v2.0 due to Flutter compatibility issues*
**Fallback Colors** (Android <12):
- Primary: `#6750A4` (Purple)
- Secondary: `#625B71` (Gray)
- Tertiary: `#7D5260` (Rose)

**Semantic Colors**:
- Urgent (< 7 days): `colorScheme.error` (Red)
- Warning (7-14 days): `colorScheme.tertiary` (Yellow)
- Normal (> 14 days): `colorScheme.primary` (Blue/Dynamic)

### Typography

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Display Large | 57sp | Bold | Hero monthly total |
| Headline Medium | 28sp | SemiBold | Screen titles |
| Title Large | 22sp | Medium | Subscription names |
| Body Large | 16sp | Regular | Descriptive text |
| Label Medium | 12sp | Medium | Helper text |

### Spacing (8dp Grid)

- 4dp: Tight spacing (icon + text)
- 8dp: Card separation
- 16dp: Content padding
- 24dp: Section separation
- 32dp: Screen margins

### Components

**Cards**:
- Corner radius: 16dp
- Elevation: 0 (use surface tint)
- Min height: 88dp
- Ripple effect on tap

**Bottom Sheets**:
- Corner radius: 28dp (top only)
- Drag handle: Always visible
- Max height: 90% screen

**Buttons**:
- FAB: 16dp corner radius
- Filled button: Default Material 3 shape
- Text button: No background

### Motion

- Standard duration: 350ms
- Curve: `easeOutCubic`
- Page transitions: `PredictiveBackPageTransitionsBuilder`

---

## 🚀 Feature Roadmap

### Phase 1: MVP ✅

- [x] Add/view subscriptions
- [x] Calculate total monthly spend
- [x] Material You theming (Fallback)
- [x] Offline-first storage (Hive)
- [x] Sort by date/price/name
- [x] Form validation
- [x] Empty states

### Phase 2: Enhanced UX ✅

- [x] Subscription details sheet
- [x] Edit subscription
- [x] Delete/archive functionality
- [x] Search by name
- [x] Undo delete (snackbar)
- [x] Pull to refresh
- [x] Popular service templates (18)

### Phase 3: Notifications ✅

- [x] Local notifications for renewals
- [x] Notification settings (1/3/7 days before)
- [x] Custom notification times
- [x] Dynamic timezone support
- [x] Exact alarm permission handling

### Phase 4: Analytics ✅

- [x] Spending trends chart (fl_chart)
- [x] Category breakdown pie chart
- [x] Most expensive subscriptions insight
- [x] Category drill-down (tap to see subscriptions)
- [x] Renewal calendar with heatmap
- [x] Export to CSV
- [x] Export to PDF with detailed analytics
- [x] Dark warm brown theme

### Phase 4.5: Multi-Currency & Polish 🔄

- [x] Multi-currency support (20 currencies)
- [x] Exchange rate fetching & caching
- [x] Display currency preference (persisted)
- [x] Budget tracking system
- [x] Custom categories
- [x] Theme customization (presets & custom colors)
- [x] Trial/free subscription tracking
- [x] Export in display currency (CSV & PDF)
- [x] PDF-safe currency symbols
- [x] Android home screen widget (basic styling)

### Phase 5: Sharing & Sync ✅

- [x] Firebase Authentication (Google, Email/Password, Apple Sign-In)
- [x] Cloud Firestore sync (bidirectional Hive ↔ Firestore)
- [x] Household creation & join via 6-character invite codes
- [x] Partner subscription visibility with spend view toggle (My Share vs Household Total)
- [x] Per-subscription splitting with custom percentages
- [x] Split proposals (request/accept/reject flow)
- [x] Offline-first data migration on first sign-in
- [x] Sync status indicator
- [x] Conflict resolution (last-write-wins with local merge)
- [x] Clear All Data feature in settings
- [x] Currency auto-detection and conversion for household spend views

### Phase 5.5: Advanced Analytics ✅

- [x] Subscription count line chart (12-month active sub history)
- [x] Price change tracking (priceHistory field, detection on edit, cards with % change)
- [x] Cancel simulator (monthly/yearly/5-year savings projection)
- [x] Monthly comparison chip (delta badge vs last month in hero stats)
- [x] Renewal forecast timeline (30-day horizontal scrollable view)
- [x] Budget vs actual gauge (animated arc, color-coded, self-hiding)
- [x] Split savings card (shows savings from splitting, self-hiding)
- [x] Who pays more bar (animated you vs partner comparison, self-hiding)
- [x] Refined chart color palette and sleeker pie chart design
- [x] Price history in CSV and PDF exports

### Phase 6: Monetization

- [ ] RevenueCat integration
- [ ] Free tier: 5 subscriptions
- [ ] Pro features:
  - Unlimited subscriptions
  - Advanced analytics
  - Custom categories
  - Priority support

### Phase 7: iOS Launch

- [ ] iOS-specific adaptations
- [ ] App Store submission
- [ ] Cross-platform testing

---

## 🧪 Testing Strategy

### Unit Tests

Test business logic in isolation:
- Subscription model calculations
- Database CRUD operations
- Provider state changes
- Date/currency utilities

### Widget Tests

Test UI components:
- SubscriptionCard renders correctly
- Form validation works
- Empty states display
- Error states handle gracefully

### Integration Tests

Test user flows:
- Add subscription → Appears in list
- Sort subscriptions → Order changes
- Delete subscription → Removed from list

### Test Coverage Goals

- Models/Services: 90%+
- Providers: 80%+
- Widgets: 70%+
- Overall: 75%+

---

## 🔒 Security & Privacy

### Data Security

- All data stored locally in Hive (encrypted)
- Firebase: Use security rules to restrict access
- No analytics without user consent
- GDPR compliant data export

### Permissions

**Required**:
- None initially (offline-first)

**Optional** (request only when needed):
- Notifications (for renewal reminders)
- Internet (for Firebase sync)

---

## 📈 Performance Targets

- App launch: < 2 seconds (cold start)
- Add subscription: < 500ms (save to DB)
- List render: 60 FPS with 100+ items
- Memory usage: < 100 MB
- APK size: < 20 MB (release)

### Optimization Techniques

1. **Lazy loading**: Use `ListView.builder`
2. **Const constructors**: Reduce rebuilds
3. **Riverpod**: Granular state updates
4. **Image caching**: Cache logos
5. **Code splitting**: Lazy load Firebase/RevenueCat

---

## 🐛 Error Handling

### Database Errors

```dart
try {
  await db.addSubscription(sub);
} catch (e) {
  showSnackBar('Failed to save subscription. Please try again.');
  logError(e); // Send to crash reporting
}
```

### Form Validation

- Real-time validation (on field change)
- Clear error messages
- Prevent submission if invalid

### Network Errors

- Retry with exponential backoff
- Offline mode with sync indicator
- Queue changes for sync when back online

---

## 🌐 Localization (Future)

Support for:
- English (US, UK)
- Spanish (ES, MX)
- French
- German
- Hindi

**Currency Support** (20 currencies):
- Americas: USD, CAD, MXN, BRL
- Europe: EUR, GBP, CHF, SEK, NOK, DKK, PLN
- Asia-Pacific: INR, JPY, CNY, KRW, SGD, HKD, THB, MYR, AUD

---

## 📝 Code Quality Standards

### Linting

- Use `flutter_lints` package
- Enforce with `analysis_options.yaml`
- No warnings in production code

### Naming Conventions

- Classes: `UpperCamelCase`
- Variables/functions: `lowerCamelCase`
- Constants: `lowerCamelCase` (not SCREAMING_CASE)
- Private: Prefix with `_`

### Documentation

- Public APIs: Always document
- Complex logic: Add comments
- TODOs: Include ticket number

### Git Workflow

- Branch naming: `feature/add-notifications`, `fix/subscription-sort`
- Commit messages: `feat: Add local notifications`, `fix: Sort by date bug`
- PR checklist:
  - [ ] Tests pass
  - [ ] No lint warnings
  - [ ] Documentation updated
  - [ ] Tested on Android 12+ and <12

---

## 🚀 Deployment

### Version Numbering

Semantic versioning: `MAJOR.MINOR.PATCH+BUILD`
- Example: `1.2.3+45`
- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes
- BUILD: Build number (auto-increment)

### Release Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Update changelog
- [ ] Run tests: `flutter test`
- [ ] Run build: `flutter build apk --release`
- [ ] Test release build on device
- [ ] Create Git tag: `v1.2.3`
- [ ] Upload to Play Store (internal testing → beta → production)

---

## 📚 Resources & References

- **Flutter**: https://docs.flutter.dev
- **Material 3**: https://m3.material.io
- **Riverpod**: https://riverpod.dev
- **Hive**: https://docs.hivedb.dev
- **Firebase**: https://firebase.google.com/docs/flutter
- **RevenueCat**: https://docs.revenuecat.com

---

## ✨ Improvements Over Original Spec

### What's Better in This Version

1. **Clearer Structure**: Organized into phases with priorities
2. **Testing Strategy**: Added comprehensive testing plan
3. **Performance Targets**: Defined measurable goals
4. **Security**: Added privacy and data security section
5. **Error Handling**: Defined strategies for common errors
6. **Deployment**: Added release process and versioning
7. **Code Quality**: Defined standards and conventions

### Recommendations for Future Updates

1. **User Research**: Conduct surveys to validate features
2. **A/B Testing**: Test different UI variations
3. **Analytics**: Add non-intrusive usage analytics (opt-in)
4. **Accessibility**: Ensure WCAG 2.1 AA compliance
5. **CI/CD**: Set up GitHub Actions for automated testing
6. **Crash Reporting**: Integrate Sentry or Firebase Crashlytics

---

**Last Updated**: 2026-02-25
**Version**: 3.1
**Status**: Phase 5.5 Complete (Advanced Analytics) — All phases 1-5.5 done, testing in progress

---

## 📋 See Also

- **DEV_STATUS.md** - Current development status, recent bug fixes, and next steps
