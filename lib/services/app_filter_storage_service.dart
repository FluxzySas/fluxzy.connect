import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting per-app VPN filter settings using SharedPreferences.
class AppFilterStorageService {
  static const String _keySelectedApps = 'selected_apps_whitelist';
  static const String _keyFilterEnabled = 'app_filter_enabled';

  /// Saves the selected apps whitelist.
  Future<void> saveSelectedApps(List<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySelectedApps, packageNames);
  }

  /// Loads the selected apps whitelist.
  Future<List<String>> loadSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySelectedApps) ?? [];
  }

  /// Saves whether app filtering is enabled.
  Future<void> saveFilterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFilterEnabled, enabled);
  }

  /// Loads whether app filtering is enabled.
  Future<bool> loadFilterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFilterEnabled) ?? false;
  }

  /// Clears all app filter settings.
  Future<void> clearAppFilterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedApps);
    await prefs.remove(_keyFilterEnabled);
  }
}
