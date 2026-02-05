class ProxyHost {
  final String hostname;
  final int port;
  final String? displayName;
  final bool isDiscovered;

  /// NetBIOS or friendly host name from discovery
  final String? hostName;

  /// Operating system name (e.g., "Windows 11")
  final String? osName;

  /// Fluxzy version running on the host
  final String? fluxzyVersion;

  /// Fluxzy startup settings (can be long, scrollable text)
  final String? fluxzyStartupSetting;

  /// Relative URL endpoint for downloading the CA certificate
  final String? certEndpoint;

  const ProxyHost({
    required this.hostname,
    required this.port,
    this.displayName,
    this.isDiscovered = false,
    this.hostName,
    this.osName,
    this.fluxzyVersion,
    this.fluxzyStartupSetting,
    this.certEndpoint,
  });

  String get address => '$hostname:$port';

  String get label => displayName ?? hostName ?? address;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProxyHost &&
        other.hostname == hostname &&
        other.port == port;
  }

  @override
  int get hashCode => hostname.hashCode ^ port.hashCode;

  ProxyHost copyWith({
    String? hostname,
    int? port,
    String? displayName,
    bool? isDiscovered,
    String? hostName,
    String? osName,
    String? fluxzyVersion,
    String? fluxzyStartupSetting,
    String? certEndpoint,
  }) {
    return ProxyHost(
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      displayName: displayName ?? this.displayName,
      isDiscovered: isDiscovered ?? this.isDiscovered,
      hostName: hostName ?? this.hostName,
      osName: osName ?? this.osName,
      fluxzyVersion: fluxzyVersion ?? this.fluxzyVersion,
      fluxzyStartupSetting: fluxzyStartupSetting ?? this.fluxzyStartupSetting,
      certEndpoint: certEndpoint ?? this.certEndpoint,
    );
  }
}
