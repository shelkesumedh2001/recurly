# Recurly

A beautiful subscription tracking app with Material You design for Android.

## Features
- Track recurring subscriptions (Netflix, Spotify, etc.)
- Material You dynamic theming
- Share subscriptions with partner/family
- Analytics and insights
- Freemium model: Free (5 subs) → Pro ($39.99/year)

## Tech Stack
- Flutter 3.19+ with Dart 3.3+
- Riverpod for state management
- Hive for local database
- Firebase for authentication & sync
- Material 3 with dynamic colors
- RevenueCat for monetization

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Code (Hive adapters & Riverpod)
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
- Implement offline-first approach
- Test on Android 12+ for full Material You experience

## Future Enhancements
- iOS support
- Custom recurring intervals
- Budget alerts
- Export to CSV
- Family sharing groups
