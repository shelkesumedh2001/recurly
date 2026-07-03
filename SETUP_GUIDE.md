# Recurly - Complete Setup Guide

> Recurly is live on the Google Play Store as v1.0.0+4 (2026-06-29). This guide covers everything needed to build, run, and release the app from source — local debug runs, Firebase wiring, and signed release AABs.

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | 3.41.2 (the version the app is pinned to) |
| Dart SDK | 3.11.0 (ships with Flutter 3.41.2) |
| Android Studio or VS Code | Latest stable with Flutter / Dart plugins |
| Android SDK | API 34 build tools; minSdkVersion 23 |
| Android NDK | 27.0.12077973 |
| Java | 17 |
| Gradle | 8.12.1 (managed by the project's wrapper) |
| Android Gradle Plugin | 8.9.3 |
| Kotlin | 2.0.21 |
| Git | Any recent version |

Verify your Flutter install:
```bash
flutter --version
flutter doctor
```

Resolve any red marks `flutter doctor` reports before continuing.

---

## Step-by-Step Setup

### 1. Install Dependencies

```bash
flutter pub get
```

This installs everything listed in `pubspec.yaml` — Riverpod, Hive, Firebase, fl_chart, flutter_local_notifications, share_plus, pdf, csv, url_launcher, sign_in_with_apple, and the rest of the stack.

### 2. Generate Hive Adapters

The app uses code generation for every `@HiveType` model. Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates `.g.dart` files alongside the models. The following will be regenerated:

- `lib/models/subscription.g.dart`
- `lib/models/app_preferences.g.dart`
- `lib/models/enums.g.dart`
- `lib/models/budget.g.dart`
- `lib/models/custom_category.g.dart`
- `lib/models/exchange_rate.g.dart`
- `lib/models/theme_preferences.g.dart`

To regenerate on save during model edits:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 3. Run the App (Debug)

```bash
# Pick a connected device
flutter devices

# Run on the default device
flutter run

# Or on a specific device
flutter run -d <device_id>
```

### 4. Run the App (Release)

```bash
flutter run --release
```

Use this when you want to verify the actual release code path locally (the build will use your local upload keystore if `android/key.properties` exists, otherwise it'll error). The Play app-signing path can only be verified through Play's Internal track — see "Verifying Google Sign-In" below.

---

## Project Structure

```
lib/
├── main.dart                # Entry point — Hive init, Firebase init, sync init
├── models/                  # @HiveType data models
├── providers/               # Riverpod state (StateNotifier pattern)
├── screens/                 # Full-page UIs
├── widgets/                 # Reusable UI components
│   └── analytics/           # Chart widgets used in the Analytics screen
├── services/                # Database, sync, notifications, currency, household, split, export
├── theme/                   # Theme presets + Material 3 color setup
└── utils/                   # billing_cycle, schema, email_validator, constants
```

For Hive field allocations (HiveField 0–22) and the full feature list, see `PROJECT_STATE.md`. For the current dev status and any in-flight bug-fix sprints, see `DEV_STATUS.md`.

---

## Firebase Setup

Recurly uses Firebase for Authentication (Google + Email/Password + Apple) and Cloud Firestore (sync, household, split).

### Required for cloud sync to work

1. Create or open a Firebase project at https://console.firebase.google.com
2. Add an Android app with package name **`com.sumedh.recurly`** (or your fork's package — also update `android/app/build.gradle`)
3. **Add SHA-1 fingerprints** under Project Settings → Your apps → Android app:
   - Your **debug** keystore SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1`
   - Your **upload** keystore SHA-1 (if you're building releases): `keytool -list -v -keystore android/app/upload-keystore.jks -alias upload | grep SHA1`
   - **Play app-signing-key SHA-1**: Only needed if releasing through Play Store. Copy it from Play Console → Setup → App integrity → "App signing key certificate", then add to Firebase. Without this, Google Sign-In returns `code 10 / DEVELOPER_ERROR` for users who install from Play.
4. Download `google-services.json` → place at `android/app/google-services.json`
5. Enable Authentication providers: **Google**, **Email/Password**, optionally **Apple** (iOS)
6. Create a Firestore database (Production mode)
7. Deploy security rules from `firestore.rules` via Firebase Console → Firestore → Rules → paste → Publish

### Verifying Firestore rules

The repo's `firestore.rules` is the canonical version. Key invariants:
- Reads/writes on `/users/{uid}/*` require `request.auth.uid == uid`, **plus** an `isHouseholdMember(uid)` allowance for partner updates to subscriptions and profile (used by household disband/leave flows)
- Open reads on `/households` and `/invites` (needed for invite-code lookup)
- Disjoint-branch writes on `/households` for create / join / leave / creator-refresh / delete
- Collection listeners filter on `householdVisible == true` to align with the read rule

---

## Release Build (Play Store AAB)

```bash
flutter build appbundle --release --no-tree-shake-icons
```

Output: `build/app/outputs/bundle/release/app-release.aab` (~52 MB).

**Why `--no-tree-shake-icons`:** the custom-category icon picker (`icon_picker_sheet.dart`) resolves `IconData` instances at runtime. The icon tree-shaker can't see those references and will strip used glyphs, crashing the icon grid in production.

### Release Signing

Release builds are signed with the upload keystore. The config lives at `android/key.properties` (gitignored):

```properties
storePassword=<...>
keyPassword=<...>
keyAlias=upload
storeFile=upload-keystore.jks
```

And the keystore itself at `android/app/upload-keystore.jks` (also gitignored). Both files must be backed up off-machine — losing the upload keystore means **never being able to publish another update** to the same Play Store listing.

### Uploading to Play Console

1. Open Play Console → your app → **Production** → **Releases**
2. **Create new release** → upload `app-release.aab`
3. If you're rolling out to Production for the very first time, also visit **Production → Countries / regions** and add at least one country before the release will publish
4. Add release notes (see `DEV_STATUS.md` → "Production Launch" for the format used on 2026-06-29)
5. **Review release** → **Start rollout to Production**

### Verifying Google Sign-In after a Play Release

Once the rollout completes, install from Play on a test device and exercise the Google Sign-In flow. This is the only path that uses Google's app-signing key — `flutter run` locally signs with debug or upload keystore and will not catch a missing Play app-signing SHA-1 in Firebase.

---

## Testing the App

### Unit / Widget Tests

```bash
flutter test
```

Existing test files (58 tests passing as of 2026-06-29):
- `test/schema_migration_test.dart`
- `test/billing_cycle_test.dart`
- `test/trial_expiry_test.dart`
- `test/currency_service_test.dart`
- `test/price_change_impact_test.dart`
- `test/sync_service_listener_test.dart`
- `test/email_validator_test.dart`

### Manual Smoke Test (covers all phases)

**Core CRUD**
- [ ] Add a subscription; verify it appears, monthly total updates, renewal countdown is correct
- [ ] Tap a card; verify details sheet shows Edit / Delete / Archive / Close
- [ ] Swipe right → edit; swipe left → delete with undo toast
- [ ] Recently Deleted: restore and permanently delete
- [ ] Archive and restore

**Notifications**
- [ ] Settings → Notifications: toggle renewal reminders (1d/3d/7d)
- [ ] Trial-end reminders (1d/3d/7d) configurable independently
- [ ] Send a test notification

**Analytics**
- [ ] Category pie chart renders with all categories
- [ ] Projected spending bar chart shows 6 months
- [ ] Calendar tab heatmap shows renewal density
- [ ] Cancel simulator (tap a sub in category detail)
- [ ] Renewal forecast (30-day timeline)
- [ ] Budget gauge (requires a budget to be set)

**Multi-currency**
- [ ] Add subs in different currencies; change display currency in settings
- [ ] Verify conversion is applied (not just symbol swap)

**Trial Subscriptions**
- [ ] Add a free-trial sub with duration row (days/months/years)
- [ ] Verify trial badge, countdown, and trial-end reminder scheduling

**Custom Billing Cycles**
- [ ] Add a sub with a custom day count (e.g. 45 days)
- [ ] Verify `monthlyEquivalent` is reasonable and renewal date advances correctly

**Sync (signed-in)**
- [ ] Sign in via Google → migration sheet appears if you had local subs
- [ ] Make a change on device A → it appears on device B within a few seconds
- [ ] Sign-in indicator in app bar shows sync state

**Household (two signed-in devices)**
- [ ] Device A creates household → invite code
- [ ] Device B joins with code → both show 2 members
- [ ] Household Total view shows both devices' subs combined
- [ ] Propose split from A → accept on B → My Share / Household Total update correctly
- [ ] Disband → both devices clean up correctly (no ghost reference subs)

**Export**
- [ ] CSV export downloads with correct currency / column order
- [ ] PDF export renders with category breakdown

**Android Widget**
- [ ] Add widget to home screen; verify monthly spend + next renewal display

---

## Common Issues

### Build runner fails or generates conflicting files

```bash
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### `HiveError: Cannot find the generated adapter`

You haven't run `build_runner`. See Step 2.

### Material You / dynamic color not picking up wallpaper

Recurly removed the `dynamic_color` package because v1.8.1 was incompatible with Flutter 3.27+. The app uses theme presets and a custom color picker instead — wallpaper adaptation is intentionally not in. See `PROJECT_STATE.md` → "Architecture Decisions".

### Hot reload not picking up `@HiveType` model changes

Hot reload doesn't refresh generated `.g.dart` files. Stop the app, regenerate, restart.

### Google Sign-In returns `code 10 / DEVELOPER_ERROR`

The relevant SHA-1 isn't registered in Firebase. See "Firebase Setup" → step 3. If it only fails on Play installs (debug works), it's the Play app-signing-key SHA-1 specifically.

### Notifications not firing on Android 14+

The app uses `inexactAllowWhileIdle` (no special permission needed). If they're still not firing, check the per-app notification permission in system settings; it's prompted on first launch via `permission_handler`.

---

## Development Workflow

### Editing a `@HiveType` Model

1. Edit the model (e.g., `lib/models/subscription.dart`)
2. **Choose a new `HiveField` index** if adding a field — see the table in `PROJECT_STATE.md`. Current highest: HiveField 22 (`customDays`)
3. If your change requires a migration (renaming or repurposing an existing field), bump `kCurrentSchemaVersion` in `lib/utils/schema.dart` and add the migration logic there
4. Regenerate: `dart run build_runner build --delete-conflicting-outputs`
5. Restart the app

Purely additive HiveFields with sensible defaults do **not** require a schema-version bump.

### Adding a Dependency

1. Add to `pubspec.yaml`
2. `flutter pub get`
3. Import and use

### Code Quality

```bash
flutter analyze
```

The project uses strict linting via `analysis_options.yaml`. Fix warnings before committing.

---

## Performance

```bash
flutter run --profile
```

Use Flutter DevTools to profile widget rebuilds, frame times, and Hive read/write hot spots.

The current architecture intentionally limits rebuild thrash:
- Lifecycle watches on `home_screen.dart` are kept-alive in `initState` via `ref.listenManual` (not in `build`)
- `SyncService.remoteDataChangeTicker` is a `ValueNotifier<int>` with a real listener list, so `SubscriptionNotifier` instances coexist across hot reload without overwriting each other's refresh callback
- `didWriteHive` flag in the remote listener prevents the ticker from firing on no-op Firestore snapshots

---

## Debugging

### Verbose logs
```bash
flutter run -v
```

### Inspect the Hive database path
```dart
print(Hive.box('subscriptions').path);
```

### View pending notifications
Settings → Notifications has a debug button that lists scheduled notifications.

### Firestore rule violations
Watch device logs for `permission-denied` while reproducing the action; rule-deny is the most common cause of "X silently doesn't work."

---

## Resources

- Flutter docs: https://docs.flutter.dev
- Riverpod docs: https://riverpod.dev
- Hive docs: https://docs.hivedb.dev
- Firebase Auth (Flutter): https://firebase.google.com/docs/auth/flutter/start
- Firestore (Flutter): https://firebase.google.com/docs/firestore/quickstart
- Material 3: https://m3.material.io

For project-internal context (architecture decisions, ongoing work, post-launch backlog), the canonical docs are `PROJECT_STATE.md` and `DEV_STATUS.md`.
