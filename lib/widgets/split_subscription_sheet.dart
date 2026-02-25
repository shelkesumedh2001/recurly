import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';
import '../providers/auth_providers.dart';
import '../providers/household_providers.dart';
import '../providers/subscription_providers.dart';
import '../services/split_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = widget.subscription;
    final partnerShare = sub.price * (_sharePercent / 100);
    final myShare = sub.price - partnerShare;

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
                'Split Subscription',
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
                "Partner's Share: ${_sharePercent.round()}%",
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
                    label: 'Your Share',
                    amount: '${sub.currencySymbol}${myShare.toStringAsFixed(2)}',
                    percent: '${(100 - _sharePercent).round()}%',
                  ),
                  _buildShareInfo(
                    theme,
                    label: "Partner's Share",
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
                      : const Text(
                          'Propose Split',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
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

  Future<void> _proposeSplit() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    // Get partner UID from household
    final members = ref.read(householdMembersProvider);
    final partnerUid = members.firstWhere(
      (m) => m != user.uid,
      orElse: () => '',
    );

    if (partnerUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No household partner found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SplitService().proposeSplit(
        ownerUid: user.uid,
        subId: widget.subscription.id,
        partnerUid: partnerUid,
        sharePercent: _sharePercent,
      );
      // Reload subscriptions so split icon shows immediately
      ref.read(subscriptionProvider.notifier).loadSubscriptions();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split proposed!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
