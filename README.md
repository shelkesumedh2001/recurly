# Recurly

> Subscription tracker with Material You design for Android.

Track every subscription you pay for — renewals, costs, budgets, and shared expenses — all in one place, with or without an account.

---

## Features

- **Dashboard** — total monthly spend, upcoming renewals, per-subscription breakdown
- **Multi-currency** — live exchange rates, auto-detects your primary currency
- **Analytics** — spending trends, price history, renewal forecast, cancel simulator
- **Budgets** — set a monthly limit and track against it
- **Household sharing** — sync with a partner and split subscription costs
- **Notifications** — renewal reminders 1, 3, and 7 days before billing
- **Free trial tracking** — countdown before a trial converts to paid
- **Offline-first** — everything works without an account; optional cloud sync via Google Sign-In

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.41 · Material 3 |
| State | Riverpod |
| Local DB | Hive |
| Cloud | Firebase Auth · Firestore |

## Getting Started

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

Requires Flutter 3.41+ and an Android device or emulator (Android 8+). For cloud sync, add your `google-services.json` to `android/app/`.

## License

[CC BY-NC 4.0](LICENSE) — free for personal and non-commercial use.
