import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_preferences.dart';
import '../models/subscription.dart';
import '../providers/preferences_providers.dart';
import '../theme/app_tokens.dart';
import 'common/app_bottom_sheet.dart';

/// Offers renewal reminders once, right after the user's first subscription
/// is saved — and only if they say yes do we fire the Android 13+ system
/// permission dialog.
///
/// Why this exists: the request used to run inside `main()` before
/// `runApp()`, so the OS asked "Allow Recurly to send notifications?" over a
/// blank screen, before the user had seen anything or entered any data. On
/// Android 13+ two dismissals deny POST_NOTIFICATIONS permanently, and
/// reminders are the only thing that brings anyone back to a subscription
/// tracker — so a cold ask quietly burned the app's one route back to the
/// user, at the worst possible moment. Asking against a subscription they
/// just typed in ("Netflix bills on Jul 22") makes the question answer
/// itself, and keeps the system dialog in reserve for users who'll accept.
///
/// Runs at most once — see [AppPreferences.notificationPrimerShown].
Future<void> maybeShowNotificationPrimer(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final prefs = ref.read(preferencesProvider);
  final preferencesNotifier = ref.read(preferencesProvider.notifier);
  final notificationService = ref.read(notificationServiceProvider);

  // Performance-only short-circuit. [primerDecision] below is the sole
  // authority and returns `skip` for these prefs regardless of permission
  // state; this line just avoids the platform-channel read on every add
  // once the primer is settled. Deleting it changes nothing but cost.
  if (prefs.notificationPrimerShown || !prefs.notificationsEnabled) return;

  // The permission plugin talks over a platform channel, and this whole
  // flow runs un-awaited from a button handler — a throw here would surface
  // as an unhandled async error and, with the flag not yet set, re-fire the
  // primer on every add. (Old main.dart had these calls inside a try/catch;
  // keep that guarantee.) Skip quietly and leave the primer pending.
  final bool hasPermission;
  try {
    hasPermission = await notificationService.hasPermission();
  } catch (e) {
    debugPrint('Notification primer: permission check failed: $e');
    return;
  }
  switch (primerDecision(prefs, hasPermission: hasPermission)) {
    case PrimerDecision.skip:
      return;
    case PrimerDecision.retire:
      await preferencesNotifier.markNotificationPrimerShown();
      return;
    case PrimerDecision.offer:
      break;
  }

  if (!context.mounted) return;
  final wantsReminders = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => NotificationPrimerSheet(
      subscription: subscription,
      leadDescription: leadDescriptionFor(prefs),
    ),
  );

  // Asked once, however they answered — including a swipe-away.
  await preferencesNotifier.markNotificationPrimerShown();
  if (wantsReminders != true) return;

  // The reminders for this subscription were already scheduled by
  // `addSubscription`; POST_NOTIFICATIONS gates display when the alarm
  // fires, not scheduling, so a grant now is enough to make them land.
  try {
    await notificationService.requestPermission();
  } catch (e) {
    // The primer is already spent; losing the grant beats crashing the add
    // flow. Settings > Notifications remains the recovery path.
    debugPrint('Notification primer: permission request failed: $e');
  }
}

/// What to do about the primer right now.
///
/// - [skip]: do nothing AND leave the flag alone. Covers both "already
///   offered" and "reminders switched off" — the latter must stay pending
///   so re-enabling reminders still earns a primer later.
/// - [retire]: permission is already granted (or the platform doesn't gate
///   it), so there is nothing to ask — spend the primer without a sheet.
/// - [offer]: show the sheet.
enum PrimerDecision { skip, retire, offer }

/// The primer rule set, in one pure function so the whole behavior —
/// including the skip-vs-retire distinction that decides whether the flag
/// gets spent — can be pinned without a platform channel or a widget tree.
/// Returning a decision rather than a bool is deliberate: a bool forced
/// the caller to re-derive WHY it was false to choose between retiring
/// and leaving the primer pending, and that duplicated logic is where a
/// notifications-off user could get their pending primer silently spent.
@visibleForTesting
PrimerDecision primerDecision(
  AppPreferences prefs, {
  required bool hasPermission,
}) {
  // Offered once; that's the whole budget.
  if (prefs.notificationPrimerShown) return PrimerDecision.skip;
  // Never ask the OS to back a feature the user has switched off — and
  // never spend the primer here, whatever the permission state says.
  if (!prefs.notificationsEnabled) return PrimerDecision.skip;
  // Nothing left to ask for.
  if (hasPermission) return PrimerDecision.retire;
  return PrimerDecision.offer;
}

/// How the primer describes the reminder the user would actually get,
/// read from their current lead-time preferences rather than hardcoded.
/// Names the earliest enabled reminder — that's the one that arrives first.
@visibleForTesting
String leadDescriptionFor(AppPreferences prefs) {
  if (prefs.reminder7DaysEnabled) return '7 days before';
  if (prefs.reminder3DaysEnabled) return '3 days before';
  if (prefs.reminder1DayEnabled) return 'the day before';
  if (prefs.reminderOnDayEnabled) return 'on the day';
  return 'before it bills';
}

/// The primer's contents: a real date from a real subscription, and two
/// plain choices. Pops `true` only on an explicit yes.
class NotificationPrimerSheet extends StatelessWidget {
  const NotificationPrimerSheet({
    super.key,
    required this.subscription,
    required this.leadDescription,
  });

  final Subscription subscription;
  final String leadDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final billDate = DateFormat('MMM d').format(subscription.nextBillDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Want a heads-up before it bills?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${subscription.name} bills on $billDate. Recurly can remind you '
            '$leadDescription, so a renewal never catches you out.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Not now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: const Text(
                    'Remind me',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
