import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyMinAttendanceEnabled = 'min_attendance_enabled';
  static const String _keyMinAttendancePercentage = 'min_attendance_percentage';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyNotificationTime = 'notification_time';

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.toString().split('.').last);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_keyThemeMode) ?? 'system';
    return ThemeMode.values.firstWhere(
      (e) => e.toString().split('.').last == modeStr,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMinAttendanceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMinAttendanceEnabled, enabled);
  }

  Future<bool> getMinAttendanceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMinAttendanceEnabled) ?? false;
  }

  Future<void> setMinAttendancePercentage(double percentage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMinAttendancePercentage, percentage);
  }

  Future<double> getMinAttendancePercentage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMinAttendancePercentage) ?? 75.0; // Default 75%
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? false;
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await prefs.setString(_keyNotificationTime, timeStr);
  }

  Future<TimeOfDay> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr =
        prefs.getString(_keyNotificationTime) ?? '17:00'; // Default 5 PM
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static const String _keyLastViewedSessionId = 'last_viewed_session_id';

  Future<int?> getLastViewedSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastViewedSessionId);
  }

  Future<void> setLastViewedSessionId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastViewedSessionId, id);
  }
}
