import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/split_proposal.dart';
import '../services/split_service.dart';
import 'auth_providers.dart';

/// Provider for the split service singleton
final splitServiceProvider = Provider<SplitService>((ref) {
  return SplitService();
});

/// Stream provider for pending split proposals
final pendingSplitProposalsProvider =
    StreamProvider<List<SplitProposal>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);
  final splitService = ref.watch(splitServiceProvider);
  return splitService.listenToSplitProposals(user.uid);
});

/// Provider for pending proposal count (for badge)
final pendingSplitCountProvider = Provider<int>((ref) {
  final proposals = ref.watch(pendingSplitProposalsProvider).value;
  return proposals?.length ?? 0;
});
