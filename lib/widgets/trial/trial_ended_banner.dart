import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/trial_providers.dart';
import '../../theme/app_tokens.dart';
import '../app_toast.dart';

/// One card per ended trial the user hasn't confirmed yet (BUG-24, D1).
///
/// The trial is already counted at its post-trial price everywhere
/// ([Subscription.currentPrice]); this asks whether that's true. "Still
/// subscribed" turns it into a regular paid sub; "I cancelled" archives it.
class TrialEndedBanners extends ConsumerWidget {
  const TrialEndedBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = ref.watch(expiredTrialsProvider);
    if (expired.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final sub in expired)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TrialEndedCard(subscription: sub),
          ),
      ],
    );
  }
}

String _per(Subscription sub) => switch (sub.billingCycle) {
      BillingCycle.weekly => 'a week',
      BillingCycle.monthly => 'a month',
      BillingCycle.yearly => 'a year',
      BillingCycle.custom => 'every ${sub.customDays ?? '?'} days',
    };

class _TrialEndedCard extends ConsumerStatefulWidget {
  const _TrialEndedCard({required this.subscription});

  final Subscription subscription;

  @override
  ConsumerState<_TrialEndedCard> createState() => _TrialEndedCardState();
}

class _TrialEndedCardState extends ConsumerState<_TrialEndedCard> {
  bool _busy = false;

  Future<void> _keep() async {
    final sub = widget.subscription;
    await _run(() async {
      await ref
          .read(subscriptionProvider.notifier)
          .updateSubscription(sub.convertedFromTrial());
      showAppToast('${sub.name} is now a paid subscription');
    });
  }

  Future<void> _cancelled() async {
    final sub = widget.subscription;
    // Read the notifier now: archiving removes this card, so `ref` is
    // disposed by the time the toast's Undo runs.
    final notifier = ref.read(subscriptionProvider.notifier);
    await _run(() async {
      await notifier.archiveSubscription(sub.id);
      showAppToast(
        '${sub.name} archived',
        actionLabel: 'Undo',
        onAction: () => notifier.unarchiveSubscription(sub.id),
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      showAppToast("Couldn't update ${widget.subscription.name}. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.subscription;
    final ended = sub.trialEndDate != null
        ? DateFormat.MMMd().format(sub.trialEndDate!)
        : null;
    final price = sub.formatAmount(sub.chargePerRenewal);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ended == null
                ? '${sub.name} trial has ended'
                : '${sub.name} trial ended $ended',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Now counted at $price ${_per(sub)}. '
              'Still subscribed?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _cancelled,
                child: const Text('I cancelled'),
              ),
              TextButton(
                onPressed: _busy ? null : _keep,
                child: const Text('Yes, keep it'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
