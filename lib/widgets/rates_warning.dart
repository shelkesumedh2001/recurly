import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/currency_providers.dart';

/// "Exchange rates unavailable" warning with tap-to-retry.
///
/// Animates in/out with a size+fade (no abrupt pop when rates land), and
/// shows an inline spinner while a manual retry is in flight. [compact]
/// renders the borderless hero-card variant; the default is the padded
/// banner used on Analytics.
class RatesUnavailableWarning extends ConsumerStatefulWidget {
  const RatesUnavailableWarning({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<RatesUnavailableWarning> createState() =>
      _RatesUnavailableWarningState();
}

class _RatesUnavailableWarningState
    extends ConsumerState<RatesUnavailableWarning> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      // Hold the spinner for at least ~700ms: an offline fetch fails in
      // milliseconds (instant DNS error), and a sub-frame flash reads as
      // "the button did nothing".
      await Future.wait([
        ref.read(refreshRatesProvider)(),
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = ref.watch(conversionUnavailableProvider);

    // AnimatedSize collapses the slot smoothly when the warning resolves;
    // AnimatedSwitcher cross-fades the content in/out.
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: unavailable ? _buildWarning(context) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildWarning(BuildContext context) {
    final theme = Theme.of(context);
    final compact = widget.compact;
    final textColor =
        compact ? theme.colorScheme.error : theme.colorScheme.onErrorContainer;

    final row = Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _retrying
              ? SizedBox(
                  key: const ValueKey('spinner'),
                  width: compact ? 14 : 16,
                  height: compact ? 14 : 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.error,
                  ),
                )
              : Icon(
                  Icons.currency_exchange,
                  key: const ValueKey('icon'),
                  size: compact ? 14 : 16,
                  color: theme.colorScheme.error,
                ),
        ),
        SizedBox(width: compact ? 6 : 8),
        Expanded(
          child: Text(
            _retrying
                ? 'Updating exchange rates…'
                : 'Rates unavailable — totals mix currencies. Tap to retry.',
            style: theme.textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _retry,
          child: row,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Material(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _retry,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: row,
          ),
        ),
      ),
    );
  }
}
