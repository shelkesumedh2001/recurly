# Recurly - Development Status

**Last Updated**: 2026-07-03 (everything committed + pushed to branch)
**Current Phase**: 🚀 LIVE on Play Store — v1.0.0+4 on Production track

---

## ▶️ RESUME HERE — Next Session

Branch `fix/spend-accuracy-and-soft-delete-sync` — **5 commits, PUSHED to
GitHub, not merged**: `5f41d75` (9 bug fixes) → `2b373a8` (#6 cap) →
`25446b9` (quick wins) → `f16963d` (docs refresh) → `e1bed77` (S1 offline
queue, #3 credit cards, #7 goldens, P0+P1+P2 audit fixes, R8/Task 12).

State: **121/121 tests pass** (unit + goldens + fake-Firestore sync tests +
smoke), `flutter analyze` **0 issues**, release AAB builds clean with R8.
Working tree clean. Known non-blocking gap remaining: device B doesn't
cancel notifications on *remote* soft-delete until its next app launch
(startup `rescheduleAllNotifications` corrects it).

**To do, in order:**
1. **Run the 17-item manual device-test batch** (⏳ checklist below):
   5×S1 offline sync, 2×#3 credit cards, 4×P0 (creator account deletion is
   critical), 6×P1/P2 (R8 release-build smoke is critical — install the
   minified build via Play Internal track or `flutter install --release`).
2. Open a PR (or merge to main) → **first-ever CI run** (CI triggers only
   on PRs and pushes to main, so it hasn't run yet).
3. Release prep for v1.0.0+5: bump pubspec `version:` AND `kAppBuild` in
   `lib/utils/changelog.dart` (+ its `kChangelog` entry — a test enforces).
   Release-note material is drafted in the session logs below (credit-card
   tracking, offline sync, reminders that don't stop, notification taps).
4. Backlog (nothing urgent): **#6** budget rollover / daily-budget readout;
   staged major dep upgrades (firebase 4.x, cloud_firestore 6.x,
   riverpod 3.x, fl_chart 1.x — one at a time, each with a device pass);
   split the 4 oversized files; JSON backup/import (Task A1, needs a
   file-picker plugin); rename "Partner"; Phase 6 monetization.

---

## S1 Offline Write-Queue Session (2026-07-02, commit `e1bed77`)

Closes known gap (b): offline writes now persist and replay instead of only
reaching remote at the next full merge.

| Piece | What |
|---|---|
| `lib/services/sync_queue.dart` | Hive `sync_queue` box of pending ops. Keyed by sub id → ops coalesce (latest wins). uid-tagged so an account switch can't replay into the wrong collection. 500-op cap (oldest evicted), 30-day stale purge. Push ops carry no payload — current local sub is read at drain time, so replays can't push stale data. |
| `SyncService` | `pushSubscription`/`deleteRemoteSubscription` enqueue on failure. `drainPendingOps(uid)` replays oldest-first, stops at first failure. Triggers: `initialize()` and `forceSync` (**before** merge — a queued hard-delete must hit remote first or merge resurrects the sub locally), first server-confirmed snapshot after reconnect, after any successful push. |
| `constants.dart` / `database_service.dart` | `syncQueueBox` opened at init. Plain maps — no new TypeAdapter, no schema bump. |
| `test/sync_queue_test.dart` | 9 tests: coalescing both directions, per-uid isolation, ordering, stale purge, cap eviction, persistence across reopen. |
| `analysis_base.yaml` | Workaround: Dart 3.11 silently drops `analyzer.exclude` when it shares a file with a `package:` include, so the exclude for the untracked `backup_ui_v1/` snapshot lives in this intermediate local include. |

Verified: analyze 0 errors/warnings (84 pre-existing infos, same as main);
CI-style test run 81/81 pass. S1 manual cases added to the ⏳ checklist below.

---

## #7 Golden Tests Session (2026-07-02, commit `e1bed77`)

UI-regression safety net, done ahead of R8/Task 12 as planned.

| Piece | What |
|---|---|
| `test/goldens_test.dart` | 3 goldens in `test/goldens/`: SubscriptionCard states (normal/warning/urgent renewal, active trial, partner read-only) in light AND dark, + leaf widgets (BudgetProgressBar safe/warning/exceeded, TrialBadge active/urgent/expired/compact, ThemePreviewCard). Regenerate after intentional UI changes: `flutter test test/goldens_test.dart --update-goldens`. |
| Determinism | `Subscription` model now reads `clock.now()` (package:clock, added as direct dep) instead of `DateTime.now()` — identical in production, pinned in goldens via `withClock(Clock.fixed(2026-07-15))` so date-derived UI (countdowns, "Next:" labels, trial badges) never rots. |
| Firebase in tests | `setupFirebaseCoreMocks()` (firebase_core_platform_interface, now an explicit dev dep) satisfies SubscriptionCard's provider chain (SubscriptionNotifier → SyncService → FirebaseFirestore.instance) without real Firebase. |
| `test/flutter_test_config.dart` | Shared test bootstrap: loads FontManifest fonts (MaterialIcons) so golden icons render real glyphs; text stays deterministic Ahem. |
| CI | Test glob tightened to `*_test.dart` so the bootstrap file isn't loaded as a test. Goldens rendered on Linux == CI's ubuntu runner. |

Verified: analyze 0 errors/warnings (84 baseline infos); 84/84 tests pass
CI-style (81 prior + 3 goldens). Goldens visually inspected — urgency
colors, trial/partner badges, budget-bar states all render correctly.

---

## P1+P2 Audit-Fix Session (2026-07-02, commit `e1bed77`)

All remaining audit items done in one pass (deferred: major dep bumps, big-file splits, JSON import — see notes).

**P1:**
| Item | What |
|---|---|
| Household/split hardening | Every Firestore op in `household_service` + `split_service` wrapped in `_timed()` (10s cap, same policy as SyncService). `createHousehold` = one atomic batch (3 self-authorized writes). `cleanupOwnSplitData` = chunked batches. Rule-ordering-sensitive sequences (disband) untouched. |
| Notification look-ahead | Renewal + card-due reminders now schedule **3 future cycles** (`lookAheadCycles`), not just the next one — reminders no longer die if the app isn't opened for a while. Ids get a `#occurrence` discriminator (occurrence 0 keeps legacy shape); cancel loops cover all. |
| Sync tests (fake_cloud_firestore) | New dev dep + test seams: `SyncService.debugFirestoreOverride` (getter — constructing the singleton no longer touches Firebase), `DatabaseService.registerAdapters()` + `debugSetSubscriptionsBox`, `SyncQueue.debugSetInstance`. **11 new tests** in `sync_service_firestore_test.dart`: merge LWW both ways, soft-delete propagation, 30-day tombstone purge (remote+local), S1 drain (delete/push/ghost/uid-isolation), and drain-before-merge resurrection prevention. |
| Smoke test fixed | `widget_test.dart` boots the real RecurlyApp against mocked Firebase core, FakeFirestore, temp-Hive services, and an overridden signed-out auth stream. **CI now runs the FULL suite** (exclusion removed from ci.yml). |
| **R8/ProGuard (Task 12) ✅** | `minifyEnabled` + `shrinkResources` + `proguard-rules.pro` (keeps: flutter_local_notifications/Gson reflection, home_widget receiver; dontwarn gms.auth/play-core). Release AAB builds clean (52.8MB — size is AOT-snapshot-dominated; win is dead code + obfuscation). Runtime smoke = checklist item. |

**P2:**
| Item | What |
|---|---|
| Notification tap-nav | TODO resolved: `NotificationService.tappedPayload` (works for warm tap + cold start via `getNotificationAppLaunchDetails`); MainNavigation routes card payloads → Credit Cards screen, sub payloads → Home tab. |
| Heatmap currency | Calendar heatmap converts per-sub to display currency before intensity bucketing. |
| Context lints | household_screen: dialog callbacks used the popped dialog's context for snackbars → now use the screen's context; `_refreshInviteCode` guards on `context.mounted`. |
| clock.now() sweep | All remaining `DateTime.now()` in providers/screens/widgets → `clock.now()` (27 sites, 7 files). |
| A11y | Tooltips added to all icon-only IconButtons (back arrows, edit/delete category, password visibility, clear budget, dismiss alert). |
| Lint burn-down | **`flutter analyze`: 0 issues** (was 82+). `dart fix --apply` (89 fixes) + manual cascades/unawaited/setter-lint resolutions. |
| Dep refresh | `flutter pub upgrade` (minors/patches only). |

**Deliberately deferred:** major version bumps (firebase 4.x/cloud_firestore 6.x/riverpod 3.x/fl_chart 1.x — each needs its own migration+device pass), splitting the 4 oversized files (mechanical churn, regression risk pre-release), JSON import/Task A1 (needs a new file-picker native plugin → its own feature).

Verified: analyze **0 issues**, **121/121 tests** (incl. goldens unchanged + smoke test), release AAB builds with R8. 6 new manual cases appended to the checklist.

---

## P0 Audit-Fix Session (2026-07-02, commit `e1bed77`)

Full-app audit (see session transcript) surfaced 3 P0 issues; all fixed.

| Fix | What |
|---|---|
| **Account deletion (auth_service)** | Was broken for household creators: deleted the household doc BEFORE clearing members' `householdId`, so the `isHouseholdMember` rule (which reads that doc) denied the member updates and the method died mid-wipe (subs gone, profile+Auth account left). Now: (1) `_ensureRecentLogin` FIRST — silent Google reauth, or a clean `requires-recent-login` abort before anything is wiped (fixes the other failure mode: `user.delete()` rejecting stale sessions after data loss); (2) household teardown reuses `HouseholdService.disband/leaveHousehold` (proven member-first order + split/reference-sub cleanup the old inline copy skipped entirely); (3) batched sub deletes; (4) Google session cleared after deletion. Also deleted auth_service's local `FirebaseAuthException` shadow class (footgun) — real firebase_auth class used everywhere; auth_screen's string-matching unaffected. profile_screen maps `requires-recent-login` to a friendly message. |
| **Calendar custom cycles (renewal_calendar)** | `_getNextRenewal` projected custom-cycle subs as "+1 month", ignoring `customDays`. Replaced with new model method `Subscription.upcomingRenewals(end)` (chains `addOneCycle`). `addOneCycle` now guards non-positive `customDays` → 30 (a zero step would hang projection loops). Calendar golden passed UNCHANGED → monthly behavior identical. Note: chained month-adds have sticky clamping (Jan 31 → Feb 28 → Mar 28) — pre-existing `nextBillDate` semantics, documented in tests, anniversary-day drift left as backlog observation. |
| **Silent mixed-currency totals** | `convert()` falls back to the raw amount when rates are missing. New `conversionUnavailableProvider` (uses existing `convertOrNull`) → warning row under the home hero total + banner on analytics: "Exchange rates unavailable — totals mix currencies". |

Tests: +5 (custom-cycle projection every-14-days, monthly clamp chain, empty projection, non-positive customDays guard ×2). **109/109 pass**, analyze 0 errors/warnings. 4 new manual device cases added to checklist (creator account deletion is the critical one).

---

## #3 Credit-Card Due-Date Tracking Session (2026-07-02, commit `e1bed77`)

Multi-card tracking with per-statement totals and payment-due reminders
(scope confirmed with user: multi-card + assignment, reminders reuse the
existing notification system).

| Piece | What |
|---|---|
| `lib/models/credit_card.dart` | `CreditCardInfo` (HiveType **9**): name, statement `cutoffDay`, payment `dueDay`, optional color. Date getters use `clock.now()` (test-pinnable). Cards are **local-only, not synced**. |
| `lib/utils/card_dates.dart` | Pure next/previous day-of-month occurrence math; days past a short month clamp to its last day (31 → Feb 28/29, Apr 30…). |
| `Subscription.cardId` | HiveField **23**, additive (no migration bump), included in toJson/fromJson so it **syncs**; a device without that card id just shows nothing. |
| `CreditCardService` + providers | CRUD singleton (box `credit_cards`, adapter registered in DatabaseService, init in main.dart). Deleting a card clears `cardId` from affected subs (+updatedAt bump so it syncs). `cardStatementSubsProvider`/`cardStatementTotalProvider`: renewals landing in the current statement window (prev cutoff, next cutoff], converted to display currency. |
| UI | Settings → **Credit Cards** screen (list, add/edit sheet with day dropdowns, delete-with-confirm via `showAppToast`); each card shows statement-close date, payment-due date, and "N renewals this statement · $X". Add/edit sub sheet gets a "Payment card" dropdown (only when cards exist). Sub details sheet shows "Card: <name> · payment due <date>". |
| Notifications | `scheduleCardDueNotifications` — payment-due reminders gated by the existing 3-day/1-day/on-day toggles + notification time; id space `card:<id><offset>`. Scheduled on card add/update, cancelled on delete, included in startup + settings-screen `rescheduleAllNotifications` (new `cards:` param). |
| Tests | `test/card_dates_test.dart`: 14 cases — clamping (Feb leap/non-leap, 30-day months), year wrap, strict-after/on-or-before semantics, statement-window membership under a pinned clock. |

Also: removed two lints deleted in Dart 3 (`invariant_booleans`,
`prefer_equal_for_default_values`) from analysis_options.yaml — they began
warning once the include-chain fix made options parsing strict.

**Follow-up pass (same day, user feedback):**
- **Renewal calendar** (analytics) now shows card payment-due dates: tertiary-color dot on due days (+"Card due" legend entry), and selecting a due day lists "<card> payment due" tiles above renewals. Projection via new pure `occurrencesInRange` (month-clamped) over ±1 year.
- **Renewal reminders** now append " · Paid with <card>" when the sub is assigned to a tracked card. Suffix stays fresh: editing a sub reschedules its reminders (already did); card rename/delete now also reschedules assigned subs' reminders.
- **Statement due-date correctness**: new `currentStatementDueDate` getter — the accumulating statement's own due date (first dueDay AFTER the next cutoff), distinct from `nextDueDate` (imminent payment of the closed statement, the reminder target). Card tile now reads "N renewals this statement · $X — due <currentStatementDueDate>".
- 6 more tests (same-month due day, pre-cutoff window, calendar projection incl. Feb clamping).
- **Calendar layout regression fixed**: the first due-marker implementation swapped the day cell's `Center` for a shrink-wrapping `Stack`, collapsing the heatmap highlights to tiny boxes (user-reported). Now `Stack[Center(number), Align(bottomCenter, dot)]` keeps the cell full-size. Calendar switched to `clock.now()` and covered by a new golden (`renewal_calendar_light.png`) using stub notifier overrides, so this can't silently regress again.

Verified: analyze 0 errors/warnings; **104/104 tests pass** CI-style. Goldens
unchanged. Release note for v1.0.0+5 changelog: "Track credit-card
statement and payment due dates; assign subscriptions to cards".

---

## Quick-Wins Session (2026-07-01, commit `25446b9`)

Small items adopted from the Minus comparison:
| Item | What |
|---|---|
| Category picker | Most-used categories first via `categoriesByUsageProvider` (derived from sub data, no schema change) |
| CI | GitHub Actions: analyze (fail-on-warnings) + tests on push/PR; fixed the 3 old analyzer warnings |
| In-app changelog | "What's new" sheet once per upgrade; `lib/utils/changelog.dart` (`kAppBuild`, `kChangelog`, pure `decideChangelog`); last-seen stored in schema box |
| Bug report | Email pre-fills diagnostics (build, OS, sub count) |

Deferred (bigger): S1 offline write-queue, #3 credit-card dates, #6 budget
rollover, #7 golden tests, #8 quick-add numpad. Skipped: Wear OS, F-Droid.

---

## Spend-Accuracy & Soft-Delete Sync Fix Session (2026-07-01)

Audit-driven bug-fix pass (triggered by comparing against the open-source
**Minus** app). 9 issues found and fixed across budgets, analytics, and the
delete/sync path. On branch `fix/spend-accuracy-and-soft-delete-sync`
(commits `5f41d75`, `2b373a8`) — **not yet merged/pushed**.

### Fixed
| # | Area | Fix |
|---|------|-----|
| 1 | Currency | Budgets & analytics summed mixed-currency subs without conversion. Routed budget usage/status/remaining + yearly-projected through `convertedTotalSpendProvider`; convert per-sub in category spend, spending trend, most-expensive. Removed orphaned raw `totalMonthlySpendProvider`. |
| 3 | Notifications | Swipe/details-sheet soft-delete never cancelled scheduled notifications. Centralized soft-delete/restore in `SubscriptionNotifier` (cancel on delete, reschedule + re-push on restore); routed all 6 call sites through it. |
| 2 + N3 | Sync | Soft-delete pushed a **hard** remote delete → other devices lost the sub + it could resurrect. Now pushes the soft-deleted state (`deletedAt` set); bumps `updatedAt` on delete/restore for last-write-wins; filters partner soft-deletes out of household views; purges expired (>30d) soft-deletes from remote during merge. |
| 4 + N2 | Cleanup | Removed dead `myShareSpendProvider`, `householdTotalSpendProvider`, `recentlyDeletedProvider`. Renamed budget `categorySpendProvider` → `categorySpendByNameProvider` (disambiguate from analytics' enum-keyed one). |
| N1 | Data | `cleanupOldDeletedSubscriptions` was never called; now runs at startup so the "auto-deletes in X days" countdown is truthful. |
| 5 | Money | Added `roundMoney()` (`lib/utils/money.dart`), applied at aggregate money boundaries so budget over/under comparisons & displays aren't flipped by float drift. Storage stays `double` — no risky live migration. |
| 6 | Sync | `_locallyDeletedIds` could grow unbounded within a session. Added `_markLocallyDeleted()` with FIFO eviction at a 500-entry cap. |

### Verification
- `flutter analyze`: clean (no new issues).
- `flutter test`: **67/67 pass** (added `soft_delete_test.dart`, `money_test.dart`, +2 in `sync_service_listener_test.dart`).
- Pre-existing `widget_test.dart` "App smoke test" still fails (needs `Firebase.initializeApp()`) — unrelated, present before this session.

### Manual on-device tests — ✅ ALL 16 PASSED 2026-07-03 (on R8 release builds, both devices)
Firestore/notification/multi-device behavior can't be unit-tested.

**Original fix-session cases — ✅ ALL TESTED 2026-07-02 (merge gate for the 3 existing commits cleared):**

- [x] **#1 Currency** — Add subs in 2 currencies (e.g. Netflix ₹649, Spotify $9.99) + a budget. Budget used/remaining and all analytics should match the home hero total (all converted). No raw mixed sums.
- [x] **#2 Cross-device delete** (2 devices, same account) — Device A swipe-deletes → lands in A's Recently Deleted; Device B removes from active **and** shows it in B's Recently Deleted (not lost).
- [x] **#2 Restore** — A restores → active again on **both** devices.
- [x] **#2 No resurrection** — deleted sub stays deleted after re-sync/relaunch; doesn't return as active.
- [x] **#2 Permanent delete** — "Delete Forever" → gone from both devices, no return.
- [x] **#2 Household** — deleting a sub drops it from the partner's Household Total view.
- [x] **#3 Notifications** — sub with reminder due tomorrow, swipe-delete → no reminder fires; restore → reminder rescheduled.
- [x] **#5 Money** — 50% split on $9.99 shows My Share $5.00 (not 4.995); budget set to exactly current spend doesn't read "over budget".
- [x] **N1 Purge** — delete a sub, set device clock +31 days, relaunch → gone from Recently Deleted.

**⏳ S1 offline write-queue cases — deferred, run before shipping the S1 commit:**

- [x] **S1 Offline delete** — airplane mode on A → swipe-delete a sub → reconnect (stay in app) → sub leaves B's active list without a force sync.
- [x] **S1 Offline delete-forever + restart** — airplane mode on A → "Delete Forever" → kill app → reconnect → relaunch → sub is gone remotely and does NOT resurrect on A (drain runs before merge).
- [x] **S1 Offline add/edit** — airplane mode on A → add a sub and edit another → reconnect → both appear/update on B.
- [x] **S1 Coalescing** — airplane mode on A → soft-delete then "Delete Forever" the same sub → reconnect → gone from both devices, not soft-deleted remotely.
- [x] **S1 Sync status** — while offline, sync indicator shows offline after a queued write; after reconnect+drain it returns to synced.
- [x] **#3 Card CRUD** — Settings → Credit Cards → add a card (cutoff 15, due 5) → assign a sub renewing before the cutoff → card shows "1 renewal this statement" with converted total; delete card → sub loses assignment, no crash.
- [x] **#3 Card reminder** — card with due day = tomorrow → "payment due tomorrow" notification scheduled (check via Settings → Notifications debug list); delete card → notification gone.
- [x] **P0 Account deletion (creator)** — 2 devices in a household, creator deletes account → no error; partner's device drops the household (self-heals); creator's Auth account + Firestore data fully gone (check Firebase Console).
- [x] **P0 Account deletion (stale session)** — sign in, wait >5 min, delete account → Google users get silent reauth and deletion succeeds; nothing half-deleted.
- [x] **P0 Rates warning** — fresh install, airplane mode, add subs in 2 currencies → hero + analytics show the "Rates unavailable" warning. Reconnect → warning clears by itself within ~45s, or immediately when tapped (tap-to-retry). *(First test run 2026-07-03 found the fetch failure was cached until app restart — fixed: provider self-retries + warnings are tappable + stale-cache fallback.)*
- [x] **P0 Custom-cycle calendar** — add a 14-day custom sub → analytics calendar shows dots every 14 days (not monthly).
- [x] **P1 R8 release smoke** — install the minified release build (Play Internal track or `flutter install --release`) → app opens, sign-in works, notifications schedule (check debug list), sync works, no crash on any tab. THE critical R8 test — obfuscation bugs only appear in release builds.
- [x] **P1 Notification look-ahead** — sub renewing tomorrow → Settings → Notifications debug list shows reminders for ~3 future cycles, not just one.
- [x] **P1 Notification tap** — tap a renewal reminder → app opens on Home; tap a card-due reminder → Credit Cards screen opens. Test once from a killed app (cold start).
- [x] **P2 Household timeout UX** — airplane mode → try creating/joining a household → "No internet connection" error within ~10s; NOTHING gets created. *(First run 2026-07-03: offline create "succeeded" via Firestore's local write queue + cache readback — fixed with a server-reachability pre-flight (`_ensureOnline`) on create/join/refresh-invite.)*
- [x] **P2 Calendar heatmap currency** — ₹649 sub + USD display currency → its calendar cell intensity reflects the converted amount (light), not max-red.

---

## Production Launch (2026-06-29)

Recurly went live on the Play Store Production track as **v1.0.0+4** (`com.sumedh.recurly`).

### What shipped
- All 8 tester-session fixes from 2026-04-27 (see section below)
- **Bug 8 — Google Sign-In SHA-1 fix**: Play app-signing-key SHA-1 added to Firebase Console for `com.sumedh.recurly`; `google-services.json` refreshed; verified working post-launch on a Play install
- Version bump `1.0.0+3` → `1.0.0+4`

### Release notes (used on Play Console)
- Fixed Google Sign-In on Play-distributed builds
- Trial subscription UX overhaul (optional price, duration picker)
- New trial-end reminders (1/3/7 days before)
- Custom billing cycles (set your own day count)
- Tap-to-open in Recently Deleted
- Fixed archive button in details sheet
- Fixed undo toast persistence

### Process notes for future releases
- Promoted **straight to Production** (skipped Internal track verification). Trade-off accepted because no users had the link yet — practical risk was low.
- Play Console threw a "no countries selected" error on first Production rollout; needed to add countries via **Production → Countries / regions** before the release would publish.
- Build command unchanged: `flutter build appbundle --release --no-tree-shake-icons`
- AAB size: 52.6 MB (up from 51 MB pre-fixes)
- Git: shipped commit is `b96d85e` on `origin/main`

### Post-launch state
| Item | Status |
|---|---|
| Live on Play Store Production | ✅ |
| Google Sign-In verified via Play install | ✅ |
| Code committed and pushed to GitHub | ✅ (`b96d85e`) |
| Keystore backed up off-machine | ✅ |
| v1.0.0+5 — UI bugs (user-queued) | ⏳ Next session |
| Task 12 — R8/ProGuard minification | ✅ Done 2026-07-02, commit `e1bed77` — runtime smoke on device checklist |
| Task A1 — JSON export/import | ⏳ Backlog (P2) |
| Phase 6 — Monetization (RevenueCat) | ⏳ When user base established |
| Rename "Partner" in household | ⏳ Polish item |

---

## Tester Bug-Fix Session (2026-04-27)

Round of bug fixes from the first wave of beta testers. 8 reported issues + 2 follow-up rounds for a single stubborn snackbar bug.

### Fixed
| # | Area | Fix |
|---|------|-----|
| 1 | Trial UX | Trial price field now optional; "Price After Trial" required when trial is on; main price defaults to 0 → displays as "FREE" |
| 1b | Trial UX | New duration row (number + Days/Months/Years dropdown) drives `trialEndDate`; existing date picker kept as override |
| 2 | Notifications | New trial-end reminders (1d/3d/7d before, default 1d on). New `AppPreferences` HiveFields 7/8/9. UI section added to notification settings |
| 3 | Recently Deleted | Tap-to-open pill (mirrors home-screen pattern) in addition to swipe gestures |
| 4 | Archive | Two-part fix: (a) details-sheet button popped sheet *before* dialog, killing `context.mounted` so archive call never fired; (b) notifier didn't bump `updatedAt` or push, so signed-in users saw archives reverted on next remote tick. New `unarchiveSubscription` method on the notifier. |
| 5 | Trial billing | `nextBillDate` getter now anchors on `trialEndDate` for trial subs (was using `firstBillDate` regardless). Cascades correctly through PDF/CSV/upcoming-renewals/notifications. |
| 6 | Analytics | `upcomingRenewalsProvider` now uses `sub.nextBillDate` instead of duplicate firstBillDate-walking logic — automatically excludes today-added subs and respects trials |
| 7 | Custom cycle | New `Subscription.customDays` (HiveField 22). `addOneCycle` accepts `{int? customDays}`. UI input visible only when "Custom" picked. `monthlyEquivalent` computes `30.44 / customDays`. Updated `_calculateMonthlyAmount` and `totalTrialCostProvider`. |
| 8 | Google Sign-In | Diagnosed: `code 10` = DEVELOPER_ERROR. Play distributes the AAB resigned with Google's app-signing key, whose SHA-1 isn't in Firebase. Action: copy SHA-1 from Play Console → Setup → App integrity → "App signing key certificate", paste in Firebase Console for `com.sumedh.recurly`, re-download `google-services.json`. **Deferred to user's next Play Console session.** |

### Snackbar persistence — finally fixed (3 rounds)

The "moved to recently deleted — Undo" pill never auto-dismissed. Took three escalating attempts before nailing it:

1. **Round 1 (wrong)**: Capture `ScaffoldMessenger` before `await`. No effect.
2. **Round 2 (partial)**: Removed `state = AsyncValue.loading()` from `loadSubscriptions` (was flashing spinner over list on every refresh). Added `rootScaffoldMessengerKey` to MaterialApp. Reduced rebuilds, but snackbar still hung.
3. **Round 3 (partial)**: Found `SyncService._startRemoteListener` ticking the `remoteDataChangeTicker` after every snapshot — even when changes were skipped via `_locallyDeletedIds`. Firestore fires multiple snapshots per logical change → 4–5 spurious `loadSubscriptions` per delete. Added `didWriteHive` flag so ticker only fires on real changes. Logs went from 4–5 "Widget data updated" prints per delete to 1. **But snackbar still hung.**
4. **Round 4 (real fix)**: Replaced SnackBar entirely for delete/restore flows with a custom `OverlayEntry`-based toast (`lib/widgets/app_toast.dart`). Owns its own `AnimationController` + `Timer` — fully independent of `ScaffoldMessenger`, nested Scaffolds, FAB animations, or any rebuild thrash. Other snackbars in the app (auth errors, etc.) still use `ScaffoldMessenger`.

### Sub-bug: `ref` after dispose

Device logs revealed:
```
Bad state: Cannot use "ref" after the widget was disposed.
#2  SubscriptionCard._showDetailsSheet…  (subscription_card.dart:544:59)
#2  _DeletedCard._showActionsSheet…     (recently_deleted_screen.dart:401:55)
```

Both delete handlers called `ref.read(...)` *after* `await loadSubscriptions()` rebuilt the parent list out of existence. Fixed by capturing all ref-derived values upfront in both paths.

### Files added / modified

**New**: `lib/widgets/app_toast.dart`

**Modified**:
- `lib/models/subscription.dart` (HiveField 22, trial-aware `nextBillDate`, `monthlyEquivalent` for custom)
- `lib/models/app_preferences.dart` (HiveFields 7/8/9 for trial reminders)
- `lib/utils/billing_cycle.dart` (`addOneCycle` accepts `customDays`)
- `lib/services/notification_service.dart` (`_scheduleTrialReminders`, separate ID space)
- `lib/services/sync_service.dart` (`didWriteHive` flag in remote listener)
- `lib/providers/subscription_providers.dart` (`unarchiveSubscription`, archive sync, no loading flash)
- `lib/providers/analytics_providers.dart` (use `sub.nextBillDate`, custom-aware impact, `customDays` passed to `addOneCycle`)
- `lib/providers/trial_providers.dart` (custom-aware `monthlyEquivalent`)
- `lib/providers/preferences_providers.dart` (3 new toggle methods)
- `lib/screens/notification_settings_screen.dart` (Free-Trial Reminders section)
- `lib/screens/recently_deleted_screen.dart` (tap-pill + custom toast)
- `lib/screens/archived_screen.dart` (notifier-routed unarchive)
- `lib/widgets/add_subscription_sheet.dart` (custom-days input, trial duration row, optional trial price)
- `lib/widgets/subscription_card.dart` (archive ordering, custom toast, ref-capture)
- `lib/main.dart` (`rootScaffoldMessengerKey`, `rootNavigatorKey`)
- `test/billing_cycle_test.dart` (custom-days tests)

### Auto-regenerated
- `lib/models/subscription.g.dart`
- `lib/models/app_preferences.g.dart`

### Verification
- `flutter analyze`: 0 errors, info-level only
- `flutter test`: 58/58 passing (3 new custom-days tests added)

---

## Current State Summary

Phases 1-5.5 are complete. The app now has:
- Firebase Authentication (Google, Email/Password, Apple Sign-In)
- Cloud Firestore sync (bidirectional, offline-first, all signed-in users)
- Household sharing (create/join with invite codes, max 2 members)
- Per-subscription splitting with custom percentages
- Spend view toggling (My Share vs Household Total)
- Clear All Data feature in settings
- Currency auto-detection and conversion for household spend views
- 8 advanced analytics features (see Phase 5.5 section below)

**Preparing for Play Store launch. App is free for all users (Pro gates disabled).**

---

## Pre-Launch Bug-Fix Sprint (2026-04-19 → 2026-04-20)

Closed a 12-task audit-driven verification pass tracked in `bugFixing.md`. See that file's Execution Log and "Sprint summary" section for per-task detail.

**Outcome:** 11/12 in-plan tasks complete + 1 out-of-plan hotfix. Task 12 (R8/ProGuard) deferred until after beta exits. 7 new test files, 55 cases, 55/55 passing.

### Tasks landed
| # | Area | Fix |
|---|------|-----|
| 0 | Hive | Schema-migration scaffolding (`lib/utils/schema.dart`, dedicated `schemaBox`) |
| 1 | Billing | Single-source `addOneCycle` (monthly clamping, DST-stable weekly) |
| 2 | Trial | Midnight-normalized `isTrialExpiredAt(now)` — UI and state agree |
| 3 | Currency | `CurrencyService.convertOrNull` returns null instead of silent passthrough |
| 4 | Analytics | `totalPriceChangeImpactProvider` honors cross-currency; rates-unavailable UI |
| 5 | Firestore | Rules rewritten (Option A); disjoint-branch writes; verified live |
| 6 | Android | `android:allowBackup="false"` — Hive DB no longer auto-backed-up |
| 7 | Lifecycle | Three home-screen watches moved from `build` to `initState` via `ref.listenManual` |
| 8 | Sync | `SyncService.remoteDataChangeTicker` (ValueNotifier listener list) replaces single-callback overwrite |
| 9 | Auth | `SyncService().dispose()` called before `signOut()` AND `deleteAccount()` |
| 10 | Config | `hasReachedFreeLimitProvider` uses `AppConstants.freeSubscriptionLimit` |
| 11 | Validation | Structural email regex via `isValidEmail()` helper |
| — | Hotfix | Undo `SnackBarAction` on details-sheet delete path (matched swipe-delete behavior) |

### Deferred
- **Task 12 — R8/ProGuard minification + obfuscation**. Beta testers are on the current unshrunken release; keep-rule iteration risks shipping a release-only crash. **Revisit after beta exits and before first production-track promotion.**

### Post-sprint backlog
- **Task A1** — Manual JSON export/import of subscription data via `share_plus`. Fills the user-facing recovery gap opened by Task 6 (`allowBackup=false`). Post-launch minor.

### Files touched
- **New source:** `lib/utils/schema.dart`, `lib/utils/billing_cycle.dart`, `lib/utils/email_validator.dart`
- **Modified source:** `lib/utils/constants.dart`, `lib/services/database_service.dart`, `lib/models/subscription.dart`, `lib/providers/analytics_providers.dart`, `lib/services/currency_service.dart`, `lib/widgets/analytics/price_changes_section.dart`, `lib/widgets/subscription_card.dart`, `lib/screens/home_screen.dart`, `lib/services/sync_service.dart`, `lib/providers/subscription_providers.dart`, `lib/services/auth_service.dart`, `lib/screens/auth_screen.dart`
- **Non-source:** `firestore.rules`, `android/app/src/main/AndroidManifest.xml`
- **Tests (all new):** `test/schema_migration_test.dart` (3), `test/billing_cycle_test.dart` (12), `test/trial_expiry_test.dart` (6), `test/currency_service_test.dart` (7), `test/price_change_impact_test.dart` (7), `test/sync_service_listener_test.dart` (3), `test/email_validator_test.dart` (17)

### Sidebar (diagnosed during Task 5 device testing)
Google Sign-In broke on a fresh `flutter run` of `com.sumedh.recurly`. Root cause: debug keystore SHA-1 `74:E7:E3:FE:A7:53:31:5A:3D:B6:2E:BC:0C:3E:96:2D:7D:33:AA:67` had only been registered under the defunct `com.example.recurly` Firebase app. Added to `com.sumedh.recurly` and re-downloaded `google-services.json` — now both debug and upload SHA-1s are on the live app.

---

## Phase 5.5 — Advanced Analytics (2026-02-25)

### New Files Created

| File | Feature |
|------|---------|
| `lib/widgets/analytics/subscription_count_chart.dart` | F1 — 12-month line chart of active sub count |
| `lib/widgets/analytics/price_changes_section.dart` | F2 — Summary banner + individual price change cards |
| `lib/widgets/analytics/cancel_simulator_sheet.dart` | F3 — Bottom sheet showing savings if cancelled |
| `lib/widgets/analytics/monthly_comparison_chip.dart` | F4 — Delta badge in hero stats |
| `lib/widgets/analytics/renewal_forecast_timeline.dart` | F5 — Horizontal 30-day timeline |
| `lib/widgets/analytics/budget_gauge.dart` | F6 — Circular arc gauge with animated fill |
| `lib/widgets/analytics/split_savings_card.dart` | F7 — Split savings insight card |
| `lib/widgets/analytics/who_pays_more_bar.dart` | F8 — Comparison bar (you vs partner) |

### Modified Files

| File | Changes |
|------|---------|
| `lib/providers/analytics_providers.dart` | Added 6 providers + 4 data classes (MonthlyComparison, UpcomingRenewal, SplitSavings, HouseholdSpendComparison, SubscriptionCountData) |
| `lib/screens/analytics_screen.dart` | Added 8 imports, inserted all 8 widgets into overview tab |
| `lib/models/subscription.dart` | Added `priceHistory` (HiveField 21) with computed helpers |
| `lib/widgets/add_subscription_sheet.dart` | Fixed edit flow (was dropping fields), added price change detection |
| `lib/widgets/analytics/category_detail_sheet.dart` | Added cancel simulator tap handler |
| `lib/services/export_service.dart` | Added price history to CSV column and PDF section |
| `lib/theme/app_theme.dart` | Balanced chart colors, sleeker pie chart (thinner segments, larger center) |

### Analytics Overview Tab Layout (Final)

1. Hero Stats (with Monthly Comparison Chip inside) — F4
2. Budget Gauge — F6 (self-hides if no budget)
3. Projected Spending (bar chart)
4. Subscription Growth (line chart) — F1
5. Spending by Category (pie chart)
6. Price Changes (cards) — F2
7. Upcoming Renewals — F5
8. Household Spending / Who Pays More — F8 (self-hides if no household)
9. Insights (most expensive, top category, Split Savings — F7)
10. Cancel Simulator — F3 (triggered via tap on subscriptions in category detail)

### Self-Hiding Widgets
- Budget Gauge: hidden when `budgetUsageProvider` returns null (no budget set)
- Split Savings Card: hidden when `splitSavingsProvider` returns null (no household or no splits)
- Who Pays More Bar: hidden when `householdSpendComparisonProvider` returns null (no household)

---

## Pre-Launch Polish Session (2026-03-05)

### Changes Made

| Change | Details |
|--------|---------|
| **Pro gates disabled** | `isProFromProfileProvider` returns `true` for all users. Everyone gets full features for free launch. No Firestore rules changes needed (Pro was client-side only). |
| **Privacy Policy screen** | New in-app screen at `lib/screens/privacy_policy_screen.dart`. 4 concise trust-building sections. Linked from Settings. |
| **Report a Bug — email** | Settings button opens email compose to `shelkesumedh2001@gmail.com` with pre-filled subject + template. Uses `url_launcher` package. |
| **Details sheet — Edit & Delete buttons** | Tap a subscription card → bottom sheet now has Edit, Delete, Archive, Close (2 rows of 2 buttons). Delete styled in red. |
| **Swipe hint** | Thin bar below first subscription card: `← swipe to edit | swipe to delete →`. Fades out + collapses after 3s with smooth animation. Shows every session on first card. |
| **AGP & Gradle bump** | Android Gradle Plugin 8.7.3 → 8.9.3, Gradle 8.9 → 8.12.1 (required by `url_launcher` AndroidX dependencies). |
| **url_launcher added** | New dependency for bug report email compose. |

### Files Modified

| File | Changes |
|------|---------|
| `lib/providers/auth_providers.dart` | `isProFromProfileProvider` always returns `true` |
| `lib/screens/privacy_policy_screen.dart` | **New** — in-app privacy policy |
| `lib/screens/settings_screen.dart` | Privacy policy navigates to screen; bug report opens email; added `url_launcher` import |
| `lib/widgets/subscription_card.dart` | Added `showSwipeHint` param, `_SwipeHintBar` widget with fade+collapse animation, Edit/Delete buttons in details sheet, removed long-press context menu |
| `lib/screens/home_screen.dart` | Passes `showSwipeHint: index == 0` to first card |
| `android/settings.gradle` | AGP 8.7.3 → 8.9.3 |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 8.9 → 8.12.1 |
| `android/app/build.gradle` | Package name `com.example.recurly` → `com.sumedh.recurly`, added release signing config from `key.properties` |
| `android/app/src/main/AndroidManifest.xml` | App label `recurly` → `Recurly` |
| `android/app/src/main/kotlin/com/sumedh/recurly/` | Moved from `com/example/recurly/`, updated package declarations |
| `android/key.properties` | **New** — keystore config (gitignored) |
| `android/app/upload-keystore.jks` | **New** — release signing key (gitignored) |
| `android/app/src/main/res/values/colors.xml` | **New** — adaptive icon background color `#1A1514` |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | **New** — adaptive icon config |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Replaced with custom app logo (all densities) |
| `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` | **New** — adaptive icon foreground (all densities) |
| `assets/images/applogo.png` | **New** — 1024x1024 app icon (also used for Play Store listing) |
| `assets/images/screenshot_1-7_*.jpg` | **New** — 7 Play Store screenshots |
| `.gitignore` | Added keystore + key.properties exclusions |
| `google-services.json` | Updated with new `com.sumedh.recurly` app from Firebase |

### Release Build

- **AAB location**: `build/app/outputs/bundle/release/app-release.aab` (51MB)
- **Build command**: `flutter build appbundle --release --no-tree-shake-icons`
- **Note**: `--no-tree-shake-icons` required because custom category icon picker uses dynamic `IconData`

### Signing Key — CRITICAL

- **Keystore**: `android/app/upload-keystore.jks` (gitignored)
- **Config**: `android/key.properties` (gitignored)
- **Alias**: `upload`
- **Validity**: 10,000 days
- **SHA-1**: `54:A3:F9:91:FF:83:D8:AA:66:29:2B:10:59:F9:9C:54:55:8A:C7:57`
- **IMPORTANT**: Back up `upload-keystore.jks` and `key.properties` somewhere safe (USB drive, cloud storage). If you lose the keystore, you can NEVER push updates to the same Play Store listing.

### Firebase Setup for New Package Name

- Added `com.sumedh.recurly` as new Android app in Firebase Console
- Added upload key SHA-1 to Firebase for Google Sign-In
- `google-services.json` now contains both `com.example.recurly` (debug) and `com.sumedh.recurly` (release)
- Old `com.example.recurly` kept in Firebase for now (debug builds still use it)

---

## Bug Fix Session 3 (2026-02-25)

### Overview
Continued end-to-end testing on two physical Android devices. Fixed critical bugs in disband, sync, currency, and household total calculation.

### Bugs Found & Fixed

| # | Bug | Root Cause | Fix | Status |
|---|-----|-----------|-----|--------|
| 1 | Disband household silently fails | `_cleanupSplits()` tried to `.get()` (list) partner's Firestore collections, but rules only allow reading own data. The entire disband failed with permission denied. | Changed to `cleanupOwnSplitData(uid)` — each user only cleans their own data. Partner self-cleans via `householdCleanupProvider`. | **Fixed** |
| 2 | Partner subs never appear in Household Total view | `initializeHouseholdSync` listener queried entire `subscriptions` collection without `.where()`. Firestore rules only allow reading `householdVisible == true` docs, so the listener failed silently for any non-visible doc. | Added `.where('householdVisible', isEqualTo: true)` to the Firestore query so it matches the security rules. | **Fixed** |
| 3 | Household total would double-count split subscriptions | `_convertedHouseholdTotal` counted all own subs + all partner subs. Reference subs (created on split accept) would be counted alongside the original, inflating the total. | Skip reference subs in own list (`ownerUid != currentUid`), skip partner's references back to us (`ownerUid == currentUid`). | **Fixed** |
| 4 | Split updates not propagating between devices (5 sub-bugs) | (a) `_onRemoteDataChanged` callback never wired up, (b) `acceptSplit` missing `updatedAt`, (c) reference sub not saved to partner's Hive, (d/e) UI not refreshing after propose/accept | Wired up callback in SubscriptionNotifier; added `updatedAt` to Firestore update; save reference sub to Hive; added `loadSubscriptions()` calls after propose/accept | **Fixed** |
| 5 | Sync not initializing after sign-in (only on cold start) | Sync only ran in `main()`. If user signed in while app was running, sync never started. | Added reactive `syncInitProvider` that watches `currentFirebaseUserProvider` | **Fixed** |
| 6 | Sync gated behind Pro — free users got nothing from signing in | `isSyncEnabledProvider` checked `isSignedIn && isPro` | Changed to just `isSignedIn`. All signed-in users get sync. | **Fixed** |
| 7 | Currency shows USD when all subs are INR | Auto-detect only checked if saved currency was `'USD'`, user had EUR | Changed to check if display currency matches ANY subscription currency | **Fixed** |
| 8 | Currency conversion not applied, just symbol swap | `myShareSpendProvider` and `householdTotalSpendProvider` didn't convert currencies | Added `_convertedMyShare()` and `_convertedHouseholdTotal()` helpers with proper `CurrencyService.convert()` calls | **Fixed** |
| 9 | Exchange rates not fetched after sync | Rates only fetched during `CurrencyService.initialize()` at cold start | Added `CurrencyService().getRates()` in `syncInitProvider` after sync completes, with `ref.invalidate(exchangeRatesProvider)` | **Fixed** |

### Files Modified This Session (2026-02-25)

| File | Changes |
|------|---------|
| `lib/services/household_service.dart` | Replaced `_cleanupSplits(members)` with public `cleanupOwnSplitData(uid)` — only reads/cleans caller's own data |
| `lib/services/sync_service.dart` | Added `.where('householdVisible', isEqualTo: true)` to household listener query; wired up `_onRemoteDataChanged` |
| `lib/services/split_service.dart` | Added `updatedAt` to `acceptSplit` Firestore update; save reference sub to partner's local Hive |
| `lib/providers/household_providers.dart` | Enhanced `householdCleanupProvider` to also clean split data, local Hive, stop sync, and reload subs |
| `lib/providers/subscription_providers.dart` | Wired up `_onRemoteDataChanged` callback in SubscriptionNotifier constructor |
| `lib/providers/sync_providers.dart` | Added `syncInitProvider` (reactive sync init); changed `isSyncEnabledProvider` to all signed-in users |
| `lib/providers/currency_providers.dart` | Updated auto-detect to check if display currency matches any subscription currency |
| `lib/screens/home_screen.dart` | Added `_convertedMyShare()` and `_convertedHouseholdTotal()` with currency conversion and reference sub filtering; watches sync/cleanup providers |
| `lib/screens/settings_screen.dart` | Implemented "Clear All Data" feature with two-step confirmation dialog |
| `lib/screens/household_screen.dart` | Added `_clearLocalSplitData()` for Hive cleanup after disband/leave |
| `lib/widgets/split_subscription_sheet.dart` | Added `loadSubscriptions()` after `proposeSplit` |
| `lib/widgets/split_proposal_card.dart` | Added `loadSubscriptions()` after `acceptSplit` |
| `lib/main.dart` | Removed Pro gate from cold-start sync initialization |

### How Disband Works Now (Fixed)
1. Creator calls `disbandHousehold(uid)`:
   - Calls `cleanupOwnSplitData(uid)` — deletes own split_proposals, reference subs, clears splitWith
   - Clears OTHER members' `householdId` first (isHouseholdMember check still passes)
   - Clears creator's own `householdId` last
   - Deletes invite doc and household doc
2. Creator's UI calls `SyncService().disposeHouseholdSync()` + `_clearLocalSplitData()`
3. Partner's device: `householdCleanupProvider` detects household doc gone →
   - Clears stale `householdId` from Firestore profile
   - Calls `cleanupOwnSplitData(uid)` for own Firestore data
   - Clears local Hive splitWith data
   - Stops household sync listener
   - Reloads subscriptions

### How Household Total Works Now (Fixed)
- Own subs: count at full price, **skip reference subs** (ownerUid != currentUid)
- Partner subs: count at full price, **skip references back to us** (ownerUid == currentUid)
- Both devices show the same total (all original subscriptions combined)

---

## Test Checklist (Resume Here)

**IMPORTANT: Copy updated Firestore rules from `firestore.rules` into Firebase Console manually**

Current test setup: Pro device (Netflix 100 INR, Google 200 INR), Free device (Vercel 100 INR), Google split 50%.

- [x] **Test 1-3: Auth, Cloud Sync, Sync Indicator** — verified working
- [x] **Test 4: Household Creation** — Pro device creates household, gets invite code
- [x] **Test 5: Join Household** — Free device joins with code, both show 2 members
- [ ] **Test 6: Partner Sub Visibility** — Household Total tab should show partner's subs with "Partner's Subscriptions" header
- [ ] **Test 7: Spend View Toggle** — My Share: 200 on both. Household Total: 400 on both.
- [x] **Test 8: Propose Split** — Pro device sends split proposal for Google (50%)
- [x] **Test 9: Accept Split** — Free device accepts, reference sub appears, My Share correct on both
- [ ] **Test 10: Disband** — Pro disbands → both devices clean up:
  - No household shown
  - No partner subs
  - Spend view resets to "My Share"
  - Split badge disappears
  - No ghost reference subs
  - Local Hive splitWith cleared

### Expected Values After Split (for verification)

| View | Pro Device | Free Device |
|---|---|---|
| My Share | ₹200 (Netflix 100 + Google 50%) | ₹200 (Vercel 100 + Google 50%) |
| Household Total | ₹400 (all 3 subs combined) | ₹400 (same) |

---

## Bug Fix Session 2 (2026-02-24)

### Bugs Found & Fixed

| # | Bug | Root Cause | Fix | Status |
|---|-----|-----------|-----|--------|
| 1 | Partner subs never show in "Household Total" | Old docs lacked `householdVisible` field | Added `_backfillHouseholdVisible()`, client-side filter | **Fixed** |
| 2 | Disband doesn't propagate to partner device | Firestore rules blocked cross-user writes | Added `allow update` for `isHouseholdMember`; changed disband order; added `householdCleanupProvider` | **Fixed** |
| 3 | Keyboard overflow in Create Household dialog | Dialog TextField not wrapped | Wrapped in `SingleChildScrollView` | **Fixed** |
| 4 | Split proposals always show `$` | No currency field in SplitProposal model | Added `currency` field + `currencySymbol` getter | **Fixed** |
| 5 | Accept split does nothing | Firestore rules blocked partner updates | Added `allow update` for household members on subscriptions | **Fixed** |
| 6 | Spend view stuck on "Household Total" after disband | Provider not reset | Added auto-reset when `!isInHousehold` | **Fixed** |

---

## Previous Sessions Summary

### Phase 5 Implementation (2026-02-23)
- Implemented all 6 sub-phases in a single session (5.1-5.6)
- 22 new files, 12 modified files
- Firebase project configured, Firestore rules deployed

### Phase 4.5 Sessions (Jan 2025)
- Multi-currency, budgets, custom categories, themes, trial tracking, Android widget

### Phase 4 Session (Jan 2025)
- Analytics, bottom navigation, warm modern theme

### Phase 3 Session (Jan 2025)
- Local notifications with timezone support

### Phase 2 Session (Jan 2025)
- Search, templates, pull-to-refresh, local logos

### Phase 1 Session (Jan 2025)
- Core CRUD, Material 3 UI, Hive storage

---

## Play Store Launch — TODO

### Done
- [x] **Pro gates disabled** — All features free for launch
- [x] **Privacy policy screen** — In-app (4 sections, no email shown)
- [x] **Report a Bug** — Opens email compose via url_launcher
- [x] **Details sheet buttons** — Edit, Delete, Archive, Close
- [x] **Swipe hint** — Fade + collapse animation on first card
- [x] **App icon** — Custom logo (coral refresh arrows on dark bg), all mipmap sizes + adaptive icon
- [x] **Screenshots** — 7 screenshots taken and renamed
- [x] **Package name** — Changed to `com.sumedh.recurly`
- [x] **Signing key** — Upload keystore created, SHA-1 added to Firebase
- [x] **Firebase updated** — New app added with `com.sumedh.recurly` + new google-services.json
- [x] **Release AAB built** — 51MB at `build/app/outputs/bundle/release/app-release.aab`
- [x] **Play Store descriptions drafted** — App name, short desc, full desc ready
- [x] **Google Play Developer account** — $25 paid, account set up

### Still TODO (Resume Here Next Session)
- [ ] **Back up keystore** — Copy `upload-keystore.jks` + `key.properties` to safe location
- [ ] **Feature graphic** — Create 1024x500 banner in Canva (dark bg + icon + tagline)
- [ ] **Privacy policy URL** — Host a page on shelke.tech (Play Store requires public URL)
- [ ] **Upload to Play Console** — Create app, fill listing, upload AAB, screenshots, icon
- [ ] **Content rating** — Fill out Play Console questionnaire
- [ ] **Submit for review** — First review takes 3-7 days
- [ ] **Commit all code changes**

### Post-Launch
- [ ] **Monitor bug reports** — via email (shelkesumedh2001@gmail.com)
- [ ] **Gather user feedback** — reviews, ratings
- [ ] **Rename "Partner" in household** — Allow custom name for household member
- [ ] **Phase 6: Monetization** — RevenueCat integration, restore Pro/Free tiers when user base is established
- [ ] **Phase 7: iOS launch** — Apple Developer account, Apple Sign-In setup

---

## Quick Commands

```bash
# Run the app (debug)
flutter run

# Clean build
flutter clean && flutter pub get && flutter run

# Build release AAB (for Play Store)
flutter build appbundle --release --no-tree-shake-icons

# Build debug APK
flutter build apk --debug

# Analyze for errors
flutter analyze lib/

# Regenerate Hive adapters (if model changes)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Key Architecture Notes

### Sync Pipeline
- Hive is always source of truth
- Firestore sync for all signed-in users (not just Pro)
- Remote listener updates Hive on changes from other devices
- Conflict resolution: last-write-wins based on `updatedAt`
- Partner subs held in-memory only (ValueNotifier), not in Hive
- `syncInitProvider` reactively initializes sync when user signs in
- Exchange rates fetched after sync completes

### Household System
- Max 2 members per household
- Pro required to create, anyone can join
- 6-char invite code, 48-hour expiry
- Creator can disband, member can leave
- Each user cleans only their own data on disband/leave
- Partner self-cleans via `householdCleanupProvider` (detects household doc deletion)

### Split System
- Owner proposes split with custom percentage (10-90%)
- Partner receives proposal, can accept or reject
- On accept: reference sub created in partner's Firestore + local Hive
- Owner's "My Share" shows reduced amount
- Household Total skips reference subs to avoid double-counting
- `cleanupOwnSplitData()` removes proposals, reference subs, and splitWith on disband
