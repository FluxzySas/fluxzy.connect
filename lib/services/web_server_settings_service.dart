import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/web_server_settings.dart';

/// Service for persisting and loading web server settings.
class WebServerSettingsService {
  static const String _keyAutoStart = 'web_server_auto_start';
  static const String _keyPort = 'web_server_port';
  static const String _keyHttpsEnabled = 'web_server_https_enabled';
  static const String _keyAuthEnabled = 'web_server_auth_enabled';
  static const String _keyAuthToken = 'web_server_auth_token';

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage;

  WebServerSettingsService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  /// Ensures SharedPreferences is initialized.
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Loads settings from persistent storage.
  /// Returns default settings if none are saved.
  Future<WebServerSettings> load() async {
    final prefs = await _getPrefs();

    final autoStart = prefs.getBool(_keyAutoStart) ??
        WebServerSettings.defaults.autoStart;
    final port = prefs.getInt(_keyPort) ??
        WebServerSettings.defaults.port;
    final httpsEnabled = prefs.getBool(_keyHttpsEnabled) ??
        WebServerSettings.defaults.httpsEnabled;
    final authEnabled = prefs.getBool(_keyAuthEnabled) ??
        WebServerSettings.defaults.authEnabled;

    return WebServerSettings(
      autoStart: autoStart,
      port: port,
      httpsEnabled: httpsEnabled,
      // Enforce auth requires HTTPS
      authEnabled: httpsEnabled ? authEnabled : false,
    );
  }

  /// Saves settings to persistent storage.
  Future<void> save(WebServerSettings settings) async {
    final prefs = await _getPrefs();

    await Future.wait([
      prefs.setBool(_keyAutoStart, settings.autoStart),
      prefs.setInt(_keyPort, settings.port),
      prefs.setBool(_keyHttpsEnabled, settings.httpsEnabled),
      prefs.setBool(_keyAuthEnabled, settings.authEnabled),
    ]);
  }

  /// Updates the auto-start setting.
  Future<WebServerSettings> setAutoStart(bool value) async {
    final current = await load();
    final updated = current.copyWith(autoStart: value);
    await save(updated);
    return updated;
  }

  /// Updates the port setting.
  /// Throws [ArgumentError] if port is invalid.
  Future<WebServerSettings> setPort(int port) async {
    if (!WebServerSettings.isValidPort(port)) {
      throw ArgumentError('Port must be between 1 and 65535');
    }

    final current = await load();
    final updated = current.copyWith(port: port);
    await save(updated);
    return updated;
  }

  /// Updates the HTTPS enabled setting.
  /// If disabling HTTPS, also disables authentication.
  Future<WebServerSettings> setHttpsEnabled(bool value) async {
    final current = await load();
    final updated = current.copyWith(httpsEnabled: value);
    await save(updated);
    return updated;
  }

  /// Updates the authentication enabled setting.
  /// Throws [StateError] if HTTPS is not enabled.
  /// Auto-generates a token if enabling auth for the first time.
  Future<WebServerSettings> setAuthEnabled(bool value) async {
    final current = await load();

    if (value && !current.httpsEnabled) {
      throw StateError('Authentication requires HTTPS to be enabled first');
    }

    // If enabling auth, ensure we have a token
    if (value) {
      final existingToken = await getAuthToken();
      if (existingToken == null) {
        await generateNewAuthToken();
      }
    }

    final updated = current.copyWith(authEnabled: value);
    await save(updated);
    return updated;
  }

  /// Gets the authentication token from secure storage.
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: _keyAuthToken);
  }

  /// Sets a custom authentication token.
  Future<void> setAuthToken(String token) async {
    await _secureStorage.write(key: _keyAuthToken, value: token);
  }

  /// Generates and stores a new random authentication token.
  /// Returns the generated token (32 hex characters).
  Future<String> generateNewAuthToken() async {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final token = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(key: _keyAuthToken, value: token);
    return token;
  }

  /// Clears the authentication token.
  Future<void> clearAuthToken() async {
    await _secureStorage.delete(key: _keyAuthToken);
  }

  /// Resets settings to defaults.
  /// Also clears the authentication token.
  Future<WebServerSettings> reset() async {
    await save(WebServerSettings.defaults);
    await clearAuthToken();
    return WebServerSettings.defaults;
  }
}
