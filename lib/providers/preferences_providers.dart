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

  /// Toggle 1-day trial-end reminder
  Future<void> toggleTrialReminder1Day(bool enabled) async {
    final updated = state.copyWith(trialReminder1DayEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Toggle 3-day trial-end reminder
  Future<void> toggleTrialReminder3Days(bool enabled) async {
    final updated = state.copyWith(trialReminder3DaysEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Toggle 7-day trial-end reminder
  Future<void> toggleTrialReminder7Days(bool enabled) async {
    final updated = state.copyWith(trialReminder7DaysEnabled: enabled);
    await updatePreferences(updated);
  }

  /// Mark the first-run onboarding as complete so the app boots straight
  /// into the main navigation on subsequent launches.
  Future<void> completeOnboarding() async {
    if (state.onboardingComplete) return;
    await updatePreferences(state.copyWith(onboardingComplete: true));
  }

  // NOTE: sessionCount is incremented directly through PreferencesService
  // in main(), before the provider container exists — there is deliberately
  // no notifier method for it, so nothing can double-count a session.

  /// Record that Play's review sheet has been requested — once is all we
  /// get, so never spend a second attempt.
  Future<void> markReviewRequested() async {
    if (state.reviewRequested) return;
    await updatePreferences(state.copyWith(reviewRequested: true));
  }

  /// Record that the notification primer has been offered, so it never
  /// runs twice regardless of how the user answered.
  Future<void> markNotificationPrimerShown() async {
    if (state.notificationPrimerShown) return;
    await updatePreferences(state.copyWith(notificationPrimerShown: true));
  }

  /// Persist the Home-screen sort mode (stored as the `HomeSortMode` enum
  /// index) so the user's choice survives app restarts.
  Future<void> setHomeSortModeIndex(int index) async {
    final updated = state.copyWith(homeSortModeIndex: index);
    await updatePreferences(updated);
  }

  /// Set the label this user uses for the other household member. Blank
  /// input falls back to the default so the UI never shows an empty name.
  Future<void> setPartnerLabel(String label) async {
    final trimmed = label.trim();
    final updated = state.copyWith(
      partnerLabel: trimmed.isEmpty ? 'Partner' : trimmed,
    );
    await updatePreferences(updated);
  }
}

/// Provider for preferences state
final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>((ref) {
  final preferencesService = ref.watch(preferencesServiceProvider);
  return PreferencesNotifier(preferencesService);
});

/// This user's label for the other household member (default "Partner").
final partnerLabelProvider = Provider<String>((ref) {
  return ref.watch(preferencesProvider).partnerLabel;
});
