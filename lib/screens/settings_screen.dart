import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Section
          _buildSectionHeader(context, 'App'),
          _buildSettingCard(
            context,
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'System default',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme selection coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage renewal reminders',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildSettingCard(
            context,
            icon: Icons.person_outline,
            title: 'Pro Subscription',
            subtitle: 'Unlock unlimited subscriptions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pro upgrade coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Free',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _buildSettingCard(
            context,
            icon: Icons.share_outlined,
            title: 'Share with Family',
            subtitle: 'Coming soon',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Family sharing coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader(context, 'Data'),
          _buildSettingCard(
            context,
            icon: Icons.cloud_download_outlined,
            title: 'Export Data',
            subtitle: 'Download your subscriptions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.delete_outline,
            title: 'Clear All Data',
            subtitle: 'Delete all subscriptions',
            onTap: () => _showClearDataDialog(context),
            isDestructive: true,
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildSettingCard(
            context,
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: AppConstants.appVersion,
            onTap: null,
          ),
          _buildSettingCard(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy policy coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help us improve',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bug reporting coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isDestructive ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? theme.colorScheme.error : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  )
                : null),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: const Text(
            'This will permanently delete all your subscriptions. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This feature will be implemented soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }
}
