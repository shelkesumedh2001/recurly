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

  // Cheap exits first: don't reach for the platform channel when the
  // answer is already no. Agrees with [shouldOfferPrimer], which holds the
  // full rule set.
  if (prefs.notificationPrimerShown || !prefs.notificationsEnabled) return;

  final hasPermission = await notificationService.hasPermission();
  if (!shouldOfferPrimer(prefs, hasPermission: hasPermission)) {
    // Only reachable when permission is already granted (or the platform
    // doesn't gate it) — nothing to ask, so spend the primer instead of
    // leaving it pending for later.
    await preferencesNotifier.markNotificationPrimerShown();
    return;
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
  await notificationService.requestPermission();
}

/// Whether the primer is due. Pure — the caller supplies the permission
/// state — so the rules that decide who gets asked can be pinned without a
/// platform channel or a widget tree.
@visibleForTesting
bool shouldOfferPrimer(
  AppPreferences prefs, {
  required bool hasPermission,
}) {
  // Offered once; that's the whole budget.
  if (prefs.notificationPrimerShown) return false;
  // Never ask the OS to back a feature the user has switched off. The flag
  // stays unset, so turning reminders back on still earns a primer.
  if (!prefs.notificationsEnabled) return false;
  // Nothing left to ask for.
  if (hasPermission) return false;
  return true;
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
