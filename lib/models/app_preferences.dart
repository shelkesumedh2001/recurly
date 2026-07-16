import 'package:hive/hive.dart';

part 'app_preferences.g.dart';

/// App-wide user preferences for notifications and settings
@HiveType(typeId: 3)
class AppPreferences extends HiveObject {
  AppPreferences({
    this.notificationsEnabled = true,
    this.reminder7DaysEnabled = false,
    this.reminder3DaysEnabled = true,  // Default: 3 days before (user preference)
    this.reminder1DayEnabled = false,
    this.reminderOnDayEnabled = false,
    this.notificationTime = const TimeOfDayPreference(hour: 9, minute: 0),
    this.displayCurrency = 'USD',
    this.trialReminder1DayEnabled = true,   // Default on: catch-the-charge reminder
    this.trialReminder3DaysEnabled = false,
    this.trialReminder7DaysEnabled = false,
    this.partnerLabel = 'Partner',
    this.homeSortModeIndex = 0,
    this.onboardingComplete = false,
    this.notificationPrimerShown = false,
  });

  /// Master switch for all notifications
  @HiveField(0)
  bool notificationsEnabled;

  /// Enable reminder 7 days before renewal
  @HiveField(1)
  bool reminder7DaysEnabled;

  /// Enable reminder 3 days before renewal
  @HiveField(2)
  bool reminder3DaysEnabled;

  /// Enable reminder 1 day before renewal
  @HiveField(3)
  bool reminder1DayEnabled;

  /// Enable reminder on renewal day
  @HiveField(4)
  bool reminderOnDayEnabled;

  /// Time of day to send notifications
  @HiveField(5)
  TimeOfDayPreference notificationTime;

  /// User's preferred display currency for showing totals
  @HiveField(6)
  String displayCurrency;

  /// Reminder 1 day before a free trial ends (so the user can cancel).
  @HiveField(7)
  bool trialReminder1DayEnabled;

  /// Reminder 3 days before a free trial ends.
  @HiveField(8)
  bool trialReminder3DaysEnabled;

  /// Reminder 7 days before a free trial ends.
  @HiveField(9)
  bool trialReminder7DaysEnabled;

  /// What this user calls the other household member (e.g. "Wife",
  /// "Alex", "Roommate"). Per-user and local — a display label only, so
  /// each member can name the other however they like. Defaults to
  /// "Partner". Additive HiveField — `defaultValue` makes the generated
  /// adapter null-safe so existing users (whose stored record predates
  /// field 10) don't crash on read. No schema bump needed.
  @HiveField(10, defaultValue: 'Partner')
  String partnerLabel;

  /// Persisted Home-screen sort mode, stored as the `HomeSortMode` enum
  /// index (0 = date, 1 = price, 2 = name) so the model stays free of the
  /// provider-layer enum. Additive HiveField — `defaultValue` keeps the
  /// generated adapter null-safe for records written before field 11.
  @HiveField(11, defaultValue: 0)
  int homeSortModeIndex;

  /// Whether the first-run onboarding (theme picker) has been completed.
  /// Constructor default is `false` so a fresh install shows onboarding,
  /// but the Hive `defaultValue: true` means users whose stored record
  /// predates this field are treated as already onboarded — so an app
  /// UPDATE never drops an existing user back into onboarding.
  @HiveField(12, defaultValue: true)
  bool onboardingComplete;

  /// Whether the in-app notification primer has been offered yet. The
  /// primer runs once, right after the first subscription is saved, and
  /// only then do we fire the Android 13+ system permission dialog — a
  /// denial there is effectively permanent, so it must never be spent on
  /// a user who hasn't seen what the app does.
  ///
  /// Constructor default is `false` so a fresh install gets the primer.
  /// The Hive `defaultValue: true` means users whose stored record
  /// predates this field are treated as already asked — they were, by the
  /// old cold-start prompt — so an app UPDATE never re-prompts them. If
  /// they denied back then, Settings > Notifications is their recovery
  /// path (it already surfaces a permission banner).
  @HiveField(13, defaultValue: true)
  bool notificationPrimerShown;

  /// Create copy with updated fields
  AppPreferences copyWith({
    bool? notificationsEnabled,
    bool? reminder7DaysEnabled,
    bool? reminder3DaysEnabled,
    bool? reminder1DayEnabled,
    bool? reminderOnDayEnabled,
    TimeOfDayPreference? notificationTime,
    String? displayCurrency,
    bool? trialReminder1DayEnabled,
    bool? trialReminder3DaysEnabled,
    bool? trialReminder7DaysEnabled,
    String? partnerLabel,
    int? homeSortModeIndex,
    bool? onboardingComplete,
    bool? notificationPrimerShown,
  }) {
    return AppPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminder7DaysEnabled: reminder7DaysEnabled ?? this.reminder7DaysEnabled,
      reminder3DaysEnabled: reminder3DaysEnabled ?? this.reminder3DaysEnabled,
      reminder1DayEnabled: reminder1DayEnabled ?? this.reminder1DayEnabled,
      reminderOnDayEnabled: reminderOnDayEnabled ?? this.reminderOnDayEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      trialReminder1DayEnabled:
          trialReminder1DayEnabled ?? this.trialReminder1DayEnabled,
      trialReminder3DaysEnabled:
          trialReminder3DaysEnabled ?? this.trialReminder3DaysEnabled,
      trialReminder7DaysEnabled:
          trialReminder7DaysEnabled ?? this.trialReminder7DaysEnabled,
      partnerLabel: partnerLabel ?? this.partnerLabel,
      homeSortModeIndex: homeSortModeIndex ?? this.homeSortModeIndex,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationPrimerShown:
          notificationPrimerShown ?? this.notificationPrimerShown,
    );
  }
}

/// Stores time of day for notifications
@HiveType(typeId: 4)
class TimeOfDayPreference {
  const TimeOfDayPreference({
    required this.hour,
    required this.minute,
  });

  @HiveField(0)
  final int hour;

  @HiveField(1)
  final int minute;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDayPreference &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}
