# Recurly

A beautiful subscription tracking app with Material You design for Android.

## Features
- Track recurring subscriptions (Netflix, Spotify, etc.) with logos
- Material You dynamic theming + custom themes
- Multi-currency support with live exchange rates
- Analytics & insights — spending trends, price history, renewal forecast, cancel simulator
- Budget tracking with gauge
- Custom categories with icon picker
- Free trial tracking with countdown
- Local notifications — renewal reminders (1, 3, 7 days before)
- Home screen widget
- Household sharing — sync subscriptions with a partner
- Split subscriptions with configurable share percentages
- Archive & Recently Deleted (30-day recovery)
- Export to CSV/PDF
- Offline-first with optional Firebase cloud sync
- Google Sign-In

## Tech Stack
- Flutter 3.41 / Dart 3.11
- Riverpod for state management
- Hive for local database (offline-first)
- Firebase Auth + Firestore for cloud sync
- Material 3 with dynamic colors

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Code (Hive adapters)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run the App
```bash
flutter run
```

## Project Structure
```
lib/
├── models/          # Data models with Hive adapters
├── providers/       # Riverpod providers
├── screens/         # UI screens
├── widgets/         # Reusable widgets
├── services/        # Business logic
├── theme/           # Theme configuration
├── utils/           # Helpers & constants
└── main.dart        # Entry point
```

## Development Notes
- Follow Material Design 3 guidelines
- Use 8dp grid system for spacing
- Offline-first: all features work without an account
- Test on Android 12+ for full Material You experience
- Firebase rules: collection listeners require `.where()` clauses matching security rules

## Planned
- iOS support
- Monetization (RevenueCat)
- Custom recurring intervals
