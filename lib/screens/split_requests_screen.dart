import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preferences_providers.dart';
import '../providers/split_providers.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/split_proposal_card.dart';

class SplitRequestsScreen extends ConsumerWidget {
  const SplitRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final proposalsAsync = ref.watch(pendingSplitProposalsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Split requests'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: proposalsAsync.when(
        data: (proposals) {
          if (proposals.isEmpty) {
            return AppEmptyState(
              icon: Icons.call_split,
              title: 'No pending requests',
              message:
                  'When ${ref.watch(partnerLabelProvider)} proposes splitting a '
                  'subscription, it appears here for you to accept or decline.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SplitProposalCard(proposal: proposals[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
