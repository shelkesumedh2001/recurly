import 'package:hive/hive.dart';
import '../models/app_preferences.dart';
import '../utils/constants.dart';

/// Service for managing app preferences with Hive storage
class PreferencesService {
  // Singleton pattern
  factory PreferencesService() => _instance;
  PreferencesService._internal();
  static final PreferencesService _instance = PreferencesService._internal();

  Box<AppPreferences>? _preferencesBox;
  static const String _preferencesKey = 'app_preferences';

  /// Initialize preferences box
  Future<void> initialize() async {
    try {
      _preferencesBox = await Hive.openBox<AppPreferences>(
        AppConstants.settingsBox,
      );
    } catch (e) {
      throw Exception('Failed to initialize preferences: $e');
    }
  }

  /// Get current preferences (with defaults if none exist)
  AppPreferences getPreferences() {
    if (_preferencesBox == null) {
      throw Exception('Preferences not initialized. Call initialize() first.');
    }

    final preferences = _preferencesBox!.get(_preferencesKey);

    // Return default preferences if none exist
    if (preferences == null) {
      final defaultPreferences = AppPreferences();
      _preferencesBox!.put(_preferencesKey, defaultPreferences);
      return defaultPreferences;
    }

    return preferences;
  }

  /// Update preferences
  Future<void> updatePreferences(AppPreferences preferences) async {
    if (_preferencesBox == null) {
      throw Exception('Preferences not initialized. Call initialize() first.');
    }

    try {
      await _preferencesBox!.put(_preferencesKey, preferences);
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }

  /// Watch preferences changes
  Stream<BoxEvent> watchPreferences() {
    if (_preferencesBox == null) {
      throw Exception('Preferences not initialized. Call initialize() first.');
    }

    return _preferencesBox!.watch(key: _preferencesKey);
  }

  /// Close the preferences box (for cleanup)
  Future<void> close() async {
    await _preferencesBox?.close();
    _preferencesBox = null;
  }
}
