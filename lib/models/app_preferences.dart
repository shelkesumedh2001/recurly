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

  /// Create copy with updated fields
  AppPreferences copyWith({
    bool? notificationsEnabled,
    bool? reminder7DaysEnabled,
    bool? reminder3DaysEnabled,
    bool? reminder1DayEnabled,
    bool? reminderOnDayEnabled,
    TimeOfDayPreference? notificationTime,
  }) {
    return AppPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminder7DaysEnabled: reminder7DaysEnabled ?? this.reminder7DaysEnabled,
      reminder3DaysEnabled: reminder3DaysEnabled ?? this.reminder3DaysEnabled,
      reminder1DayEnabled: reminder1DayEnabled ?? this.reminder1DayEnabled,
      reminderOnDayEnabled: reminderOnDayEnabled ?? this.reminderOnDayEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
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
