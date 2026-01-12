import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_preferences.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';

/// Provider for preferences service singleton
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

/// Provider for notification service singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// State notifier for managing preferences
class PreferencesNotifier extends StateNotifier<AppPreferences> {
  PreferencesNotifier(this._preferencesService)
      : super(_preferencesService.getPreferences());

  final PreferencesService _preferencesService;

  /// Update preferences and persist
  Future<void> updatePreferences(AppPreferences preferences) async {
    await _preferencesService.updatePreferences(preferences);
    state = preferences;
  }

  /// Toggle master notifications switch
  Future<void> toggleNotifications(bool enabled) async {
    final updated = state.copyWith(notificationsEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Toggle 7-day reminder
  Future<void> toggleReminder7Days(bool enabled) async {
    final updated = state.copyWith(reminder7DaysEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Toggle 3-day reminder
  Future<void> toggleReminder3Days(bool enabled) async {
    final updated = state.copyWith(reminder3DaysEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Toggle 1-day reminder
  Future<void> toggleReminder1Day(bool enabled) async {
    final updated = state.copyWith(reminder1DayEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Toggle renewal day reminder
  Future<void> toggleReminderOnDay(bool enabled) async {
    final updated = state.copyWith(reminderOnDayEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Update notification time
  Future<void> updateNotificationTime(TimeOfDayPreference time) async {
    final updated = state.copyWith(notificationTime: time);
    await updatePreferences(updated);
  }
}

/// Provider for preferences state
final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return PreferencesNotifier(preferencesService);
});
