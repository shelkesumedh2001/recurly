import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standard confirmation dialog. Returns true when the user confirms.
///
/// [destructive] styles the confirm button with the error color — and gives
/// confirming a heavier haptic than an ordinary tap. Use it for
/// delete/remove/leave actions.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              // Confirming something irreversible should feel different
              // from confirming anything else.
              if (destructive) HapticFeedback.heavyImpact();
              Navigator.pop(dialogContext, true);
            },
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
