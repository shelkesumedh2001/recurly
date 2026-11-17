import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preferences_providers.dart';
import '../providers/subscription_providers.dart';

/// Ask what the household should see of my subscriptions. Returns true for
/// "all of them", false for "only what I split", null if dismissed.
Future<bool?> askHouseholdSharing(BuildContext context, {required bool current}) {
  var shareAll = current;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('What should your household see?'),
        content: RadioGroup<bool>(
          groupValue: shareAll,
          onChanged: (v) => setState(() => shareAll = v ?? shareAll),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: true,
                title: Text('All my subscriptions'),
                subtitle: Text('Good for couples and families'),
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: false,
                title: Text('Only the ones I split'),
                subtitle: Text('Good for housemates — the rest stays private'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, shareAll),
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

/// Save the choice and apply it to my existing subscriptions. You can
/// still change any single sub in its edit sheet.
Future<void> applyHouseholdSharing(WidgetRef ref, {required bool shareAll}) async {
  await ref.read(preferencesProvider.notifier).setHouseholdShareAll(shareAll);
  await ref
      .read(subscriptionProvider.notifier)
      .applyHouseholdVisibility(shareAll: shareAll);
}
