/// Settings for the VPN control web server.
class WebServerSettings {
  /// Whether the web server should start automatically with the app.
  final bool autoStart;

  /// The port on which the web server listens.
  final int port;

  /// Whether HTTPS is enabled for the web server.
  final bool httpsEnabled;

  /// Whether bearer token authentication is enabled.
  /// Note: Can only be true when httpsEnabled is true.
  final bool authEnabled;

  /// Default port for the web server.
  static const int defaultPort = 18080;

  /// Default settings.
  static const WebServerSettings defaults = WebServerSettings(
    autoStart: true,
    port: defaultPort,
    httpsEnabled: false,
    authEnabled: false,
  );

  const WebServerSettings({
    required this.autoStart,
    required this.port,
    this.httpsEnabled = false,
    this.authEnabled = false,
  });

  /// Creates a copy with the given fields replaced.
  /// Enforces that authEnabled can only be true when httpsEnabled is true.
  WebServerSettings copyWith({
    bool? autoStart,
    int? port,
    bool? httpsEnabled,
    bool? authEnabled,
  }) {
    final newHttpsEnabled = httpsEnabled ?? this.httpsEnabled;
    // If HTTPS is being disabled, also disable auth
    final newAuthEnabled = newHttpsEnabled ? (authEnabled ?? this.authEnabled) : false;

    return WebServerSettings(
      autoStart: autoStart ?? this.autoStart,
      port: port ?? this.port,
      httpsEnabled: newHttpsEnabled,
      authEnabled: newAuthEnabled,
    );
  }

  /// Validates the port number.
  static bool isValidPort(int port) => port >= 1 && port <= 65535;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebServerSettings &&
        other.autoStart == autoStart &&
        other.port == port &&
        other.httpsEnabled == httpsEnabled &&
        other.authEnabled == authEnabled;
  }

  @override
  int get hashCode =>
      autoStart.hashCode ^ port.hashCode ^ httpsEnabled.hashCode ^ authEnabled.hashCode;

  @override
  String toString() =>
      'WebServerSettings(autoStart: $autoStart, port: $port, httpsEnabled: $httpsEnabled, authEnabled: $authEnabled)';
}
