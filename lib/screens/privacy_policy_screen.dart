import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Last updated: March 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _section(theme, 'Your Data, Your Device',
              'Recurly is built offline-first. Your subscription data lives on your device and never leaves it unless you choose to sign in and enable cloud sync.'),
          _section(theme, 'Cloud Sync',
              'If you sign in, your data is securely stored in Google Firebase to enable sync across devices and household sharing. Only you and your household partner can access your data.'),
          _section(theme, 'No Ads, No Tracking',
              'We don\'t run ads, we don\'t track you, and we don\'t sell or share your data with anyone. Period.'),
          _section(theme, 'You\'re in Control',
              'You can delete all your data anytime from Settings. Deleting your account removes everything from our servers permanently.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
