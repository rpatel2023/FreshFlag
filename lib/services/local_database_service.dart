import 'package:shared_preferences/shared_preferences.dart';

/// Small local preference store.
///
/// Inventory and identity are never persisted here. Firestore/Firebase Auth are
/// authoritative; this service is limited to device-local UI preferences.
class LocalDatabaseService {
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _preferences {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalDatabaseService has not been initialized');
    }
    return prefs;
  }

  static bool get notificationsEnabled =>
      _preferences.getBool('notifications_enabled') ?? true;

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _preferences.setBool('notifications_enabled', enabled);
  }

  static int get reminderDays => _preferences.getInt('reminder_days') ?? 3;

  static Future<void> setReminderDays(int days) async {
    await _preferences.setInt('reminder_days', days);
  }

  static Future<void> clearPreferences() async {
    await _preferences.clear();
  }

  static Future<void> close() async {
    // SharedPreferences owns no explicit closeable resource.
  }
}
