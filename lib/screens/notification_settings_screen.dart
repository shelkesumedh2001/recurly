import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_preferences.dart';
import '../providers/preferences_providers.dart';
import '../providers/subscription_providers.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesProvider);
    final notificationService = ref.watch(notificationServiceProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Notifications',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Permission status card
          FutureBuilder<bool>(
            future: notificationService.hasPermission(),
            builder: (context, snapshot) {
              final hasPermission = snapshot.data ?? true;
              if (!hasPermission) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permission Required',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enable notification permission in system settings',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await notificationService.requestPermission();
                        },
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Renewal Reminders Section
          _buildSectionHeader(context, 'Renewal Reminders'),

          // Master switch
          _buildSwitchCard(
            context,
            theme,
            icon: Icons.notifications_active,
            title: 'Enable Notifications',
            subtitle: preferences.notificationsEnabled
                ? 'Get reminders before renewals'
                : 'Notifications are off',
            value: preferences.notificationsEnabled,
            onChanged: (value) async {
              await ref.read(preferencesProvider.notifier).toggleNotifications(value);
              if (context.mounted) {
                await _rescheduleAll(ref, context);
              }
            },
          ),

          const SizedBox(height: 24),

          // Reminder Schedule Section
          _buildSectionHeader(context, 'Reminder Schedule'),

          // 7 days reminder
          _buildSwitchCard(
            context,
            theme,
            icon: Icons.today_outlined,
            title: '7 days before',
            subtitle: 'Early warning',
            value: preferences.reminder7DaysEnabled,
            enabled: preferences.notificationsEnabled,
            onChanged: (value) async {
              await ref.read(preferencesProvider.notifier).toggleReminder7Days(value);
              if (context.mounted) {
                await _rescheduleAll(ref, context);
              }
            },
          ),

          // 3 days reminder
          _buildSwitchCard(
            context,
            theme,
            icon: Icons.event_outlined,
            title: '3 days before',
            subtitle: 'Mid-range reminder',
            value: preferences.reminder3DaysEnabled,
            enabled: preferences.notificationsEnabled,
            onChanged: (value) async {
              await ref.read(preferencesProvider.notifier).toggleReminder3Days(value);
              if (context.mounted) {
                await _rescheduleAll(ref, context);
              }
            },
          ),

          // 1 day reminder
          _buildSwitchCard(
            context,
            theme,
            icon: Icons.alarm_outlined,
            title: '1 day before',
            subtitle: 'Last-minute reminder',
            value: preferences.reminder1DayEnabled,
            enabled: preferences.notificationsEnabled,
            onChanged: (value) async {
              await ref.read(preferencesProvider.notifier).toggleReminder1Day(value);
              if (context.mounted) {
                await _rescheduleAll(ref, context);
              }
            },
          ),

          // Renewal day reminder
          _buildSwitchCard(
            context,
            theme,
            icon: Icons.notifications_outlined,
            title: 'On renewal day',
            subtitle: 'Day of billing',
            value: preferences.reminderOnDayEnabled,
            enabled: preferences.notificationsEnabled,
            onChanged: (value) async {
              await ref.read(preferencesProvider.notifier).toggleReminderOnDay(value);
              if (context.mounted) {
                await _rescheduleAll(ref, context);
              }
            },
          ),

          const SizedBox(height: 24),

          // Notification Time Section
          _buildSectionHeader(context, 'Notification Time'),
          _buildTimePickerCard(context, theme, preferences, ref),

          // Debug Section (Only in debug mode)
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Debug Info'),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () async {
                      await notificationService.showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test notification sent')),
                        );
                      }
                    },
                    leading: Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
                    title: const Text('Test Immediate Notification'),
                    subtitle: const Text('Check if notifications can display'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    onTap: () async {
                      final pending = await notificationService.getPendingNotifications();
                      if (context.mounted) {
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Pending Notifications (${pending.length})'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Note: The "Renews today" text is the message that will be shown on the future scheduled date.',
                                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                  Flexible(
                                    child: pending.isEmpty
                                        ? const Text('No pending notifications')
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: pending.length,
                                            itemBuilder: (context, index) {
                                              final request = pending[index];
                                              return ListTile(
                                                title: Text(request.title ?? 'No title'),
                                                subtitle: Text('ID: ${request.id}\n${request.body ?? ''}\nPayload: ${request.payload ?? 'None'}'),
                                                isThreeLine: true,
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    leading: Icon(Icons.bug_report_outlined, color: theme.colorScheme.tertiary),
                    title: const Text('View Pending Notifications'),
                    subtitle: const Text('Check scheduled reminders'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildSwitchCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: enabled
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? null : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? null : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildTimePickerCard(
    BuildContext context,
    ThemeData theme,
    AppPreferences preferences,
    WidgetRef ref,
  ) {
    final time = preferences.notificationTime;
    final timeString = TimeOfDay(hour: time.hour, minute: time.minute).format(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: preferences.notificationsEnabled
            ? () async {
                final newTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
                );

                if (newTime != null && context.mounted) {
                  final newPreference = TimeOfDayPreference(
                    hour: newTime.hour,
                    minute: newTime.minute,
                  );
                  await ref.read(preferencesProvider.notifier).updateNotificationTime(newPreference);
                  if (context.mounted) {
                    await _rescheduleAll(ref, context);
                  }
                }
              }
            : null,
        enabled: preferences.notificationsEnabled,
        leading: Icon(
          Icons.schedule_outlined,
          color: preferences.notificationsEnabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        title: Text(
          'Notification Time',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: preferences.notificationsEnabled
                ? null
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        subtitle: Text(
          'Receive reminders at $timeString',
          style: TextStyle(
            color: preferences.notificationsEnabled
                ? null
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _rescheduleAll(WidgetRef ref, BuildContext context) async {
    try {
      final subscriptionsAsync = ref.read(subscriptionProvider);
      final subscriptions = subscriptionsAsync.value ?? [];
      final preferences = ref.read(preferencesProvider);
      final notificationService = ref.read(notificationServiceProvider);

      if (preferences.notificationsEnabled) {
        await notificationService.rescheduleAllNotifications(subscriptions, preferences);
      } else {
        await notificationService.cancelAllNotifications();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notifications: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
