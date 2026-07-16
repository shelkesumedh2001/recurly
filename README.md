# Recurly

> Subscription tracker with Material You design for Android.

![Platform](https://img.shields.io/badge/platform-Android-green)
![Flutter](https://img.shields.io/badge/Flutter-3.41-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)
![Version](https://img.shields.io/badge/version-1.0.0%2B5-orange)
![Status](https://img.shields.io/badge/status-live%20on%20Play%20Store-brightgreen)

**[Get it on Google Play](https://play.google.com/store/apps/details?id=com.sumedh.recurly)**

Track every subscription you pay for — renewals, costs, budgets, and shared expenses — all in one place, with or without an account.

---

## Screenshots

| Home | Add Subscription | Details |
|------|-----------------|---------|
| ![Home](assets/images/screenshot_1_home.jpg) | ![Add](assets/images/screenshot_2_add_subscription.jpg) | ![Details](assets/images/screenshot_3_details_sheet.jpg) |

| Calendar | Analytics | Themes |
|----------|-----------|--------|
| ![Calendar](assets/images/screenshot_4_calendar.jpg) | ![Analytics](assets/images/screenshot_5_analytics_overview.jpg) | ![Themes](assets/images/screenshot_7_themes.jpg) |

---

## Features

### Core
- Add and track subscriptions with automatic renewal dates
- Subscription logos, custom categories, and icon picker
- Archive subscriptions and restore recently deleted (30-day window)
- Calendar view of all upcoming renewals

### Credit cards
- Track statement cutoff and payment due days per card
- Assign subscriptions to cards and see what lands on each statement
- Payment-due reminders alongside renewal reminders

### Spending & Analytics
- Monthly and yearly spend totals on the dashboard
- Analytics screen — spending trends, category breakdown, renewal forecast
- Price history tracking — see how a subscription's cost has changed over time
- Cancel simulator — see how much you'd save cancelling any subscription
- Budget gauge — set a monthly limit and track against it

### Multi-currency
- Live exchange rates fetched automatically
- Per-subscription currency, displayed in your preferred currency
- Auto-detects primary currency from your subscriptions

### Household & Splitting
- Link with a partner and see each other's subscriptions
- Split any subscription with a configurable share percentage
- Household total that avoids double-counting shared costs

### Notifications & Widgets
- Renewal reminders 1, 3, and 7 days before billing
- Configurable notification time
- Home screen widget showing monthly spend and upcoming renewals

### Free Trial Tracking
- Mark subscriptions as free trials with an end date
- Countdown badge on card and details sheet
- Price-after-trial displayed so you know what's coming

### Theming
- 8 theme presets — warm dark, AMOLED, ocean, forest, and more
- Custom accent color; every preset themes charts and urgency colors
- Design tokens keep spacing, radii, and semantic colors consistent

### Sync & Privacy
- Offline-first — all features work without an account
- Offline writes queue up and replay when connectivity returns
- Optional Google Sign-In with Firestore cloud sync
- Data stays on-device by default; sync is opt-in

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.41 · Material 3 · preset-driven design tokens |
| State | Riverpod |
| Local DB | Hive (offline-first) |
| Cloud | Firebase Auth · Firestore |
| Notifications | flutter_local_notifications |

---

## Getting Started

### Prerequisites
- Flutter 3.41+
- Android device or emulator (Android 8.0+)
- For cloud sync: a Firebase project with `google-services.json`

### Run locally

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

### Build release AAB

```bash
flutter build appbundle --release --no-tree-shake-icons
```

---

## Project Structure

```
lib/
├── models/          # Hive data models
├── providers/       # Riverpod state providers
├── screens/         # Full-page screens
├── widgets/         # Reusable UI components
│   ├── common/      # Shared kit: sheets, tiles, empty states, dialogs
│   └── analytics/   # Analytics chart widgets
├── services/        # Business logic (sync, notifications, export…)
├── theme/           # Theme presets + AppTokens design tokens
└── main.dart
```

---

## Contributing

Pull requests are welcome. For significant changes, open an issue first to discuss what you'd like to change.

---

## License

[GPL-3.0](LICENSE) — free to use, study, modify, and share, commercially included; anything built from it must stay open source under the same license.

Copyright (c) 2026 Sumedh Shelke
