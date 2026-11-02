import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';
import '../providers/auth_providers.dart';
import '../providers/household_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/subscription_providers.dart';
import '../services/split_service.dart';
import 'app_toast.dart';

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

  /// The partner's entry in this sub's split, if it has one.
  Map<String, dynamic>? get _existing {
    final splits = widget.subscription.splitWith;
    return (splits == null || splits.isEmpty) ? null : splits.first;
  }

  @override
  void initState() {
    super.initState();
    // Changing a split starts from the current share, not 50%.
    final pct = _existing?['sharePercent'];
    if (pct is num) _sharePercent = pct.toDouble().clamp(10, 90);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.subscription;
    final partnerLabel = ref.watch(partnerLabelProvider);
    final partnerShare = sub.currentPrice * (_sharePercent / 100);
    final myShare = sub.currentPrice - partnerShare;
    final hasSplit = _existing != null;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        child: Padding(
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
                    Text(
                      sub.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sub.formattedPrice,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Slider
              Text(
                "$partnerLabel's share: ${_sharePercent.round()}%",
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

              // Share breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShareInfo(
                    theme,
                    label: 'Your share',
                    amount: '${sub.currencySymbol}${myShare.toStringAsFixed(2)}',
                    percent: '${(100 - _sharePercent).round()}%',
                  ),
                  _buildShareInfo(
                    theme,
                    label: "$partnerLabel's share",
                    amount:
                        '${sub.currencySymbol}${partnerShare.toStringAsFixed(2)}',
                    percent: '${_sharePercent.round()}%',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Propose button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _proposeSplit,
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

  Widget _buildShareInfo(
    ThemeData theme, {
    required String label,
    required String amount,
    required String percent,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          percent,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// The other household member, or null (shows why in a toast).
  String? _partnerUid(String myUid) {
    final members = ref.read(householdMembersProvider);
    final partnerUid =
        members.firstWhere((m) => m != myUid, orElse: () => '');
    if (partnerUid.isEmpty) {
      showAppToast('No ${ref.read(partnerLabelProvider)} found in the household');
      return null;
    }
    return partnerUid;
  }

  Future<void> _proposeSplit() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    final partnerUid = _partnerUid(user.uid);
    if (partnerUid == null) return;

    await _run(
      () => SplitService().proposeSplit(
        ownerUid: user.uid,
        subId: widget.subscription.id,
        partnerUid: partnerUid,
        sharePercent: _sharePercent,
      ),
      done: _existing != null
          ? 'New split sent — ${ref.read(partnerLabelProvider)} needs to accept it'
          : 'Split proposed',
    );
  }

  /// Ends the split for both people: the owner's splitWith goes, and the
  /// partner's copy + proposal are deleted (BUG-7).
  Future<void> _stopSplitting() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    final partnerUid =
        _existing?['uid'] as String? ?? _partnerUid(user.uid);
    if (partnerUid == null) return;

    await _run(
      () => SplitService().removeSplit(
        ownerUid: user.uid,
        subId: widget.subscription.id,
        partnerUid: partnerUid,
      ),
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
