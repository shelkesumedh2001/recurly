# Recurly - Complete Setup Guide

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Flutter SDK** (3.19 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Verify installation: `flutter --version`

2. **Android Studio** or **VS Code** with Flutter extensions

3. **Android SDK** (for Android development)
   - API Level 33+ recommended

4. **Git** (for version control)

## Step-by-Step Setup

### 1. Verify Flutter Installation

```bash
flutter doctor
```

This command will check your Flutter installation and show any missing dependencies.

### 2. Install Dependencies

Navigate to the project directory and run:

```bash
flutter pub get
```

This will download all the packages specified in `pubspec.yaml`.

### 3. Generate Code

The project uses code generation for Hive adapters and Riverpod providers. Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This command will generate:
- `lib/models/enums.g.dart` - Hive type adapters for enums
- `lib/models/subscription.g.dart` - Hive type adapter for Subscription model

**IMPORTANT:** You must run this command before running the app for the first time!

If you need to watch for changes during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 4. Run the App

#### On Android Emulator/Device:

```bash
flutter run
```

#### For specific device:

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

#### For release build:

```bash
flutter run --release
```

## Project Structure Explained

```
lib/
├── models/              # Data models
│   ├── enums.dart      # Billing cycles and categories
│   ├── enums.g.dart    # Generated Hive adapters (after build_runner)
│   ├── subscription.dart
│   └── subscription.g.dart  # Generated (after build_runner)
│
├── providers/          # Riverpod state management
│   └── subscription_providers.dart
│
├── screens/            # App screens
│   └── home_screen.dart
│
├── widgets/            # Reusable UI components
│   ├── subscription_card.dart
│   └── add_subscription_sheet.dart
│
├── services/           # Business logic
│   └── database_service.dart
│
├── theme/              # Material 3 theming
│   └── app_theme.dart
│
├── utils/              # Helpers and constants
│   ├── constants.dart
│   └── extensions.dart
│
└── main.dart           # App entry point
```

## Key Features Implemented

### ✅ Core Functionality
- Add subscriptions with name, price, billing cycle, category, and first bill date
- View all active subscriptions on home screen
- Calculate total monthly spend
- Display days until renewal with color-coded urgency
- Sort subscriptions by date, price, or name
- Form validation for all inputs

### ✅ Material You Design
- Dynamic color theming that adapts to wallpaper (Android 12+)
- Fallback color scheme for older Android versions
- Material 3 typography scale
- Smooth animations (350ms easeOutCubic)
- 8dp grid system for spacing
- Proper elevation and surface tints

### ✅ Architecture
- Clean Architecture / MVVM pattern
- Riverpod for state management
- Hive for offline-first local storage
- Separation of concerns (models, services, UI)

## Testing the App

### Manual Testing Checklist

1. **Add Subscription**
   - [ ] Tap the "Add Subscription" FAB
   - [ ] Fill in all fields with valid data
   - [ ] Tap "SAVE"
   - [ ] Verify subscription appears in the list
   - [ ] Verify total monthly spend updates

2. **Form Validation**
   - [ ] Try submitting with empty name → Should show error
   - [ ] Try submitting with empty price → Should show error
   - [ ] Try entering negative price → Should show error
   - [ ] Try entering price > 9999.99 → Should show error
   - [ ] Try entering non-numeric price → Should show error

3. **Subscription Display**
   - [ ] Verify subscription name is displayed
   - [ ] Verify price is formatted correctly
   - [ ] Verify billing cycle is shown
   - [ ] Verify category is displayed
   - [ ] Verify renewal date/countdown is shown

4. **Sorting**
   - [ ] Tap sort icon in app bar
   - [ ] Select "Sort by Next Bill Date" → Verify order
   - [ ] Select "Sort by Price" → Verify highest to lowest
   - [ ] Select "Sort by Name" → Verify alphabetical order

5. **Material You Theming**
   - [ ] On Android 12+: Change wallpaper, verify app colors update
   - [ ] Toggle between light and dark mode
   - [ ] Verify smooth transitions and animations

## Common Issues and Solutions

### Issue: Build runner fails

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Issue: "HiveError: Cannot find the generated adapter"

**Solution:**
You forgot to run build_runner! Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Issue: Material You colors not showing

**Solution:**
- Ensure you're running on Android 12+ device/emulator
- The app falls back to default colors on Android <12

### Issue: Hot reload not working after model changes

**Solution:**
- After changing models with `@HiveType`, you need to:
  1. Stop the app
  2. Run `dart run build_runner build --delete-conflicting-outputs`
  3. Restart the app

## Development Workflow

### Making Changes to Models

1. Edit the model file (e.g., `lib/models/subscription.dart`)
2. Run build_runner:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
3. Restart the app (hot reload won't work for model changes)

### Adding New Dependencies

1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. Import in your Dart files

### Code Quality

The project uses `flutter_lints` for code quality. To check:

```bash
flutter analyze
```

Fix any warnings or errors before committing.

## Next Steps

### Immediate Enhancements
1. Add subscription details screen (tap on card)
2. Implement edit subscription functionality
3. Add delete/archive functionality
4. Implement search/filter

### Future Features (from spec)
1. Firebase integration for sharing
2. RevenueCat integration for Pro features
3. Local notifications for renewals
4. Analytics dashboard with fl_chart
5. Export data functionality
6. iOS support

## Firebase Setup (When Ready)

1. Create a Firebase project at https://console.firebase.google.com
2. Add Android app to Firebase project
3. Download `google-services.json` → Place in `android/app/`
4. Run FlutterFire CLI:
   ```bash
   flutter pub global activate flutterfire_cli
   flutterfire configure
   ```

## RevenueCat Setup (When Ready)

1. Create account at https://www.revenuecat.com
2. Add app and products
3. Get API key
4. Configure in app

## Performance Optimization Tips

1. **Use ListView.builder** (already implemented)
2. **Use const constructors** where possible
3. **Minimize rebuilds** with Riverpod's granular providers
4. **Profile performance**:
   ```bash
   flutter run --profile
   ```

## Debugging

### Enable verbose logging:
```bash
flutter run -v
```

### View Hive database:
The database is stored in the app's documents directory. You can inspect it using:
```dart
import 'package:hive_flutter/hive_flutter.dart';
print(Hive.box('subscriptions').path);
```

## Support & Resources

- **Flutter Docs**: https://docs.flutter.dev
- **Riverpod Docs**: https://riverpod.dev
- **Hive Docs**: https://docs.hivedb.dev
- **Material 3 Guidelines**: https://m3.material.io


---

**Happy Coding! 🚀**
