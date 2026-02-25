import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/household_providers.dart';
import '../services/database_service.dart';
import '../services/household_service.dart';
import '../services/sync_service.dart';
import '../widgets/invite_code_card.dart';
import 'join_household_screen.dart';

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final householdAsync = ref.watch(currentHouseholdProvider);
    final isCreator = ref.watch(isHouseholdCreatorProvider);
    final isPro = ref.watch(isProFromProfileProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Household'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: householdAsync.when(
        data: (household) {
          if (household == null) {
            return _buildNoHousehold(context, isPro);
          }
          return _buildHouseholdView(context, household, isCreator);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildNoHousehold(BuildContext context, bool isPro) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Household Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a household to share subscriptions with your partner, '
              'or join one with an invite code.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Create household (Pro only)
            FilledButton.icon(
              onPressed: _isLoading
                  ? null
                  : isPro
                      ? () => _showCreateDialog(context)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pro subscription required to create a household'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
              icon: const Icon(Icons.add),
              label: Text(isPro ? 'Create Household' : 'Create (Pro Required)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Join household
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const JoinHouseholdScreen(),
                        ),
                      );
                    },
              icon: const Icon(Icons.link),
              label: const Text('Join with Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdView(
    BuildContext context,
    dynamic household,
    bool isCreator,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Household info card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                Icons.home_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                household.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${household.members.length} members',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Members
        Text(
          'Members',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...household.members.map<Widget>((String memberId) {
          final isMe =
              memberId == ref.read(currentFirebaseUserProvider)?.uid;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMe ? 'You' : 'Partner',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (memberId == household.createdBy)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Creator',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),

        // Invite code (creator only)
        if (isCreator) ...[
          Text(
            'Invite Code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          InviteCodeCard(
            code: household.inviteCode,
            expiry: household.inviteExpiry,
            onRefresh: () => _refreshInviteCode(context),
          ),
          const SizedBox(height: 32),
        ],

        // Actions
        if (isCreator)
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _confirmDisband(context),
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            label: Text(
              'Disband Household',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _confirmLeave(context),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Leave Household'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Household'),
        content: SingleChildScrollView(
          child: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Household Name',
              hintText: 'e.g., Our Home',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await _createHousehold(name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createHousehold(String name) async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentFirebaseUserProvider);
      if (user == null) return;
      final household = await HouseholdService().createHousehold(user.uid, name);

      // Start listening for partner subscriptions immediately
      await SyncService().initializeHouseholdSync(user.uid, household.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Household created!'),
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

  Future<void> _refreshInviteCode(BuildContext context) async {
    try {
      final user = ref.read(currentFirebaseUserProvider);
      if (user == null) return;
      await HouseholdService().refreshInviteCode(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite code refreshed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _confirmDisband(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disband Household?'),
        content: const Text(
          'This will remove all members and delete the household. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final user = ref.read(currentFirebaseUserProvider);
                if (user != null) {
                  await HouseholdService().disbandHousehold(user.uid);
                  SyncService().disposeHouseholdSync();
                  // Clear local Hive splitWith data
                  await _clearLocalSplitData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Disband'),
          ),
        ],
      ),
    );
  }

  /// Clear splitWith from all local Hive subscriptions
  Future<void> _clearLocalSplitData() async {
    final user = ref.read(currentFirebaseUserProvider);
    final uid = user?.uid;
    final db = DatabaseService();
    final subs = db.getActiveSubscriptions();
    for (final sub in subs) {
      if (uid != null && sub.ownerUid != null && sub.ownerUid != uid) {
        // Reference sub from a split — delete it entirely
        await db.deleteSubscription(sub.id);
      } else if (sub.splitWith != null && sub.splitWith!.isNotEmpty) {
        await db.updateSubscription(
          sub.copyWith(clearSplitWith: true, updatedAt: DateTime.now()),
        );
      }
    }
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Household?'),
        content: const Text('You can rejoin later with a new invite code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final user = ref.read(currentFirebaseUserProvider);
                if (user != null) {
                  await HouseholdService().leaveHousehold(user.uid);
                  SyncService().disposeHouseholdSync();
                  // Clear local Hive splitWith data
                  await _clearLocalSplitData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
