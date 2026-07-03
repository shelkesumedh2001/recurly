# Recurly - Quick Start Guide

> Recurly is live on the Google Play Store as of 2026-06-29 (v1.0.0+4). This guide is for running the app locally from source.

## Get Running in 3 Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Hive Adapters
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run the App
```bash
flutter run
```

For deeper setup (prerequisites, Firebase config, release builds), see [`SETUP_GUIDE.md`](SETUP_GUIDE.md).

---

## What the App Does

Recurly is an offline-first subscription tracker with optional cloud sync and household sharing. The full feature list lives in [`README.md`](README.md); for architecture and data-model detail see [`PROJECT_STATE.md`](PROJECT_STATE.md).

Headline capabilities:
- Add/edit/archive subscriptions; Recently Deleted with 30-day grace
- Monthly + yearly totals with multi-currency conversion (20 currencies)
- Renewal notifications (1/3/7 days) + trial-end reminders
- Budget gauge, category pie, renewal calendar heatmap, cancel simulator
- Optional Google Sign-In with bidirectional Firestore sync
- Household sharing with one partner + per-subscription splitting
- Android home-screen widget
- CSV / PDF export

---

## Local Project Layout

```
lib/
├── models/          # Hive @HiveType models (Subscription, AppPreferences, Budget, …)
├── providers/       # Riverpod state (subscription, sync, household, split, currency, …)
├── screens/         # Full-page UIs
├── widgets/         # Reusable components
│   └── analytics/   # Chart widgets used in the Analytics tab
├── services/        # Database, sync, notifications, currency, household, split, export
├── theme/           # Theme presets + dynamic color setup
└── utils/           # billing_cycle, schema, email_validator, constants
```

For the Hive field allocation table (HiveField 0 through 22), see `PROJECT_STATE.md`.

---

## Common Commands

```bash
# Run debug build on connected device
flutter run

# Run release build (closer to production, no hot reload)
flutter run --release

# Regenerate Hive adapters after editing a @HiveType model
dart run build_runner build --delete-conflicting-outputs

# Watch and regenerate on save during development
dart run build_runner watch --delete-conflicting-outputs

# Static analysis
flutter analyze

# Tests (Flutter test runner)
flutter test

# Clean build artifacts
flutter clean

# Build the Play Store AAB
flutter build appbundle --release --no-tree-shake-icons
```

The `--no-tree-shake-icons` flag is required because `category_management_screen` and `icon_picker_sheet` resolve `IconData` at runtime via the custom-category system.

---

## Verifying Your Build Locally

After `flutter run` starts, a quick smoke pass:

1. **Add a subscription** → confirm it appears, monthly total updates, renewal countdown is correct
2. **Tap a card** → details sheet opens with Edit / Delete / Archive / Close
3. **Swipe right** → edit sheet; **swipe left** → moves to Recently Deleted with an undo toast
4. **Analytics tab** → pie chart, projected spend, category drill-down all render
5. **Settings → Notifications** → renewal reminders + trial-end reminders configurable
6. **Settings → Sign In** (optional) → Google Sign-In + Firestore sync

For cloud sync to work you need a Firebase project with `google-services.json` in `android/app/`. See `SETUP_GUIDE.md` → "Firebase Setup" for the full procedure.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Cannot find the generated adapter" | `dart run build_runner build --delete-conflicting-outputs` |
| Build runner errors | `flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs` |
| Hot reload not picking up model change | Restart the app — hot reload doesn't refresh generated adapters |
| Google Sign-In returns `code 10 / DEVELOPER_ERROR` | Your debug-key SHA-1 isn't in Firebase. Add it under the `com.sumedh.recurly` Android app in Firebase Console and re-download `google-services.json`. |
| `dart:ui` / Flutter SDK mismatch | App is on Flutter 3.41.2 / Dart 3.11.0 — match those |

---

## Next Steps

- For internal architectural detail and outstanding work: `PROJECT_STATE.md` and `DEV_STATUS.md`
- For the full setup procedure (prerequisites, Firebase, release signing): `SETUP_GUIDE.md`
- Public-facing overview: `README.md`
- License: `LICENSE` (CC BY-NC 4.0 — personal and non-commercial use)
