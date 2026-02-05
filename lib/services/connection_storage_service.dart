import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting the last used connection configuration.
class ConnectionStorageService {
  static const String _keyHostname = 'last_hostname';
  static const String _keyPort = 'last_port';
  static const String _keyUseAuth = 'last_use_auth';
  static const String _keyUsername = 'last_username';
  static const String _keyPassword = 'last_password';

  /// Saves the connection configuration to local storage.
  Future<void> saveConnectionConfig({
    required String hostname,
    required int port,
    required bool useAuthentication,
    String? username,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHostname, hostname);
    await prefs.setInt(_keyPort, port);
    await prefs.setBool(_keyUseAuth, useAuthentication);
    if (useAuthentication && username != null) {
      await prefs.setString(_keyUsername, username);
    }
    if (useAuthentication && password != null) {
      await prefs.setString(_keyPassword, password);
    }
  }

  /// Loads the last saved connection configuration.
  /// Returns null if no configuration was previously saved.
  Future<SavedConnectionConfig?> loadConnectionConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final hostname = prefs.getString(_keyHostname);
    final port = prefs.getInt(_keyPort);

    if (hostname == null || port == null) {
      return null;
    }

    return SavedConnectionConfig(
      hostname: hostname,
      port: port,
      useAuthentication: prefs.getBool(_keyUseAuth) ?? false,
      username: prefs.getString(_keyUsername),
      password: prefs.getString(_keyPassword),
    );
  }

  /// Clears the saved connection configuration.
  Future<void> clearConnectionConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHostname);
    await prefs.remove(_keyPort);
    await prefs.remove(_keyUseAuth);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
  }
}

/// Data class representing a saved connection configuration.
class SavedConnectionConfig {
  final String hostname;
  final int port;
  final bool useAuthentication;
  final String? username;
  final String? password;

  const SavedConnectionConfig({
    required this.hostname,
    required this.port,
    required this.useAuthentication,
    this.username,
    this.password,
  });
}
