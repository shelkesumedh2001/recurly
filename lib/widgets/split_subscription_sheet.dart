import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';
import '../providers/auth_providers.dart';
import '../providers/household_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/subscription_providers.dart';
import '../services/split_service.dart';
import '../utils/money.dart';
import 'app_toast.dart';

/// Shares (percent) for a split with [members]: the slider value for a
/// single member, equal parts with the owner for several.
Map<String, double> splitShares(List<String> members, double singleShare) {
  if (members.isEmpty) return const {};
  if (members.length == 1) return {members.single: singleShare};
  final each = 100 / (members.length + 1);
  return {for (final m in members) m: each};
}

class SplitSubscriptionSheet extends ConsumerStatefulWidget {
  const SplitSubscriptionSheet({
    super.key,
    required this.subscription,
  });

  final Subscription subscription;

  @override
  ConsumerState<SplitSubscriptionSheet> createState() =>
      _SplitSubscriptionSheetState();
}

class _SplitSubscriptionSheetState
    extends ConsumerState<SplitSubscriptionSheet> {
  double _sharePercent = 50;
  bool _isLoading = false;

  /// Members picked for the split, in household order.
  final Set<String> _selected = {};

  List<Map<String, dynamic>> get _existing =>
      widget.subscription.splitWith ?? const [];

  @override
  void initState() {
    super.initState();
    // Changing a split starts from the current one, not 50% / nobody.
    for (final e in _existing) {
      if (e['uid'] is String) _selected.add(e['uid'] as String);
    }
    if (_existing.length == 1) {
      final pct = _existing.single['sharePercent'];
      if (pct is num) _sharePercent = pct.toDouble().clamp(10, 90);
    }
  }

  List<String> _others() {
    final me = ref.read(currentFirebaseUserProvider)?.uid;
    return ref.watch(householdMembersProvider).where((m) => m != me).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.subscription;
    final nameOf = ref.watch(memberNameProvider);
    final others = _others();
    // With one other member, they're the obvious pick.
    if (_selected.isEmpty && _existing.isEmpty && others.length == 1) {
      _selected.add(others.single);
    }
    final picked = others.where(_selected.contains).toList();
    final shares = splitShares(picked, _sharePercent);

    // A running trial is split at its post-trial price (chargePerRenewal);
    // splitting $0 showed "$0.00 / $0.00".
    final inTrial = sub.isFreeTrial && !sub.isTrialExpired;
    final base = sub.chargePerRenewal;
    // Members' shares rounded to the cent (what their copies show); mine
    // is the rest, so it all adds up to the price (BUG-14).
    final memberAmounts = {
      for (final e in shares.entries) e.key: roundCents(base * e.value / 100),
    };
    final myShare = roundCents(base) -
        memberAmounts.values.fold<double>(0, (a, b) => a + b);
    final myPercent =
        100 - shares.values.fold<double>(0, (a, b) => a + b);
    final hasSplit = _existing.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                hasSplit ? 'Change split' : 'Split Subscription',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Sub info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        sub.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      inTrial
                          ? '${sub.formatAmount(base)} after trial'
                          : sub.formatAmount(base),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (inTrial) ...[
                const SizedBox(height: 8),
                Text(
                  'Free until the trial ends — shares apply from the first paid bill.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              if (others.length > 1) ...[
                Text(
                  'Split with',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in others)
                      FilterChip(
                        label: Text(nameOf(m)),
                        selected: _selected.contains(m),
                        onSelected: (on) => setState(() {
                          on ? _selected.add(m) : _selected.remove(m);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (others.isEmpty)
                Text(
                  'Nobody else is in your household yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (picked.length == 1) ...[
                Text(
                  "${nameOf(picked.single)}'s share: ${_sharePercent.round()}%",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _sharePercent,
                  min: 10,
                  max: 90,
                  divisions: 16,
                  label: '${_sharePercent.round()}%',
                  onChanged: (value) => setState(() => _sharePercent = value),
                ),
              ] else if (picked.length > 1)
                Text(
                  'Split equally between you and ${picked.length} others.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

              // Share breakdown
              if (picked.isNotEmpty) ...[
                const SizedBox(height: 8),
                _shareRow(theme, 'You', sub.formatAmount(myShare), myPercent),
                for (final m in picked)
                  _shareRow(
                    theme,
                    nameOf(m),
                    sub.formatAmount(memberAmounts[m]!),
                    shares[m]!,
                  ),
              ],
              const SizedBox(height: 24),

              // Propose button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading || picked.isEmpty
                      ? null
                      : () => _proposeSplit(shares),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          hasSplit ? 'Propose new split' : 'Propose Split',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (hasSplit) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isLoading ? null : _stopSplitting,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Stop splitting'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareRow(ThemeData theme, String label, String amount, double pct) {
    final percent = (pct - pct.roundToDouble()).abs() < 0.05
        ? '${pct.round()}%'
        : '${pct.toStringAsFixed(1)}%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            percent,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _proposeSplit(Map<String, double> shares) async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    final nameOf = ref.read(memberNameProvider);
    final waitingOn = shares.length == 1
        ? nameOf(shares.keys.single)
        : 'everyone';

    await _run(
      () => SplitService().proposeSplit(
        ownerUid: user.uid,
        subId: widget.subscription.id,
        shares: shares,
      ),
      done: _existing.isNotEmpty
          ? 'New split sent — $waitingOn needs to accept it'
          : 'Split proposed',
    );
  }

  /// Ends the split for everyone: the owner's splitWith goes, and each
  /// member's copy + proposal are deleted (BUG-7).
  Future<void> _stopSplitting() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    await _run(
      () async {
        await SplitService().removeSplit(
          ownerUid: user.uid,
          subId: widget.subscription.id,
        );
        // "Only what I split": an unsplit sub goes private again.
        if (!ref.read(preferencesProvider).householdShareAll) {
          await ref
              .read(subscriptionProvider.notifier)
              .applyHouseholdVisibility(shareAll: false);
        }
      },
      done: 'Stopped splitting ${widget.subscription.name}',
    );
  }

  /// Runs a split write. Feedback goes through [showAppToast] (root
  /// overlay): a SnackBar lands on the Scaffold *behind* this sheet, which
  /// is how failures used to vanish silently (BUG-7).
  Future<void> _run(Future<void> Function() action, {required String done}) async {
    setState(() => _isLoading = true);
    try {
      await action();
      // Reload subscriptions so the split icon updates immediately
      unawaited(ref.read(subscriptionProvider.notifier).loadSubscriptions());
      if (mounted) Navigator.pop(context);
      showAppToast(done);
    } catch (e) {
      debugPrint('Split change failed: $e');
      showAppToast(
        e is TimeoutException
            ? "Couldn't reach the server. Check your connection and try again."
            : "Couldn't update the split. Try again.",
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
