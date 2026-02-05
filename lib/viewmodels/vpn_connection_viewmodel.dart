import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/app_info.dart';
import '../models/proxy_host.dart';
import '../models/certificate_info.dart';
import '../services/vpn_service.dart' as svc;
import '../services/mock_vpn_service.dart';
import '../services/android_vpn_service.dart';
import '../services/connection_storage_service.dart';
import '../services/app_filter_storage_service.dart';
import '../services/certificate_service.dart';
import '../services/certificate_native_bridge.dart';
import '../services/vpn_control_api_service.dart';
import '../services/vpn_control_server.dart';
import '../services/web_server_settings_service.dart';
import '../models/web_server_settings.dart';

// VPN Service provider - platform-aware
final vpnServiceProvider = Provider<svc.VpnService>((ref) {
  if (Platform.isAndroid) {
    final service = AndroidVpnService();
    ref.onDispose(() => service.dispose());
    return service;
  } else {
    // Fallback to mock for other platforms (iOS will need its own implementation)
    final service = MockVpnService();
    ref.onDispose(() => service.dispose());
    return service;
  }
});

// Storage service provider
final connectionStorageProvider = Provider<ConnectionStorageService>((ref) {
  return ConnectionStorageService();
});

// App filter storage service provider
final appFilterStorageProvider = Provider<AppFilterStorageService>((ref) {
  return AppFilterStorageService();
});

// Installed apps provider - fetches list from native side
// Include system apps since many useful apps (Chrome, etc.) are pre-installed
final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final vpnService = ref.watch(vpnServiceProvider);
  return vpnService.getInstalledApps(includeSystemApps: true);
});

// Certificate service provider
final certificateServiceProvider = Provider<CertificateService>((ref) {
  return CertificateService();
});

// Certificate native bridge provider
final certificateNativeBridgeProvider =
    Provider<CertificateNativeBridge>((ref) {
  return CertificateNativeBridge();
});

// VPN Control API Service provider
final vpnControlApiServiceProvider = Provider<VpnControlApiService>((ref) {
  final vpnService = ref.watch(vpnServiceProvider);
  return VpnControlApiService(vpnService);
});

// Web Server Settings Service provider
final webServerSettingsServiceProvider = Provider<WebServerSettingsService>((ref) {
  return WebServerSettingsService();
});

// Web Server Settings state provider (async)
final webServerSettingsProvider = FutureProvider<WebServerSettings>((ref) async {
  final service = ref.watch(webServerSettingsServiceProvider);
  return service.load();
});

// VPN Control Server provider - creates server but doesn't start it
// The server is started by VpnControlServerInitializer based on settings
final vpnControlServerProvider = Provider<VpnControlServer>((ref) {
  final apiService = ref.watch(vpnControlApiServiceProvider);
  // Use default port here; actual port is set when starting based on settings
  final server = VpnControlServer(
    apiService: apiService,
    port: WebServerSettings.defaultPort,
  );
  ref.onDispose(() => server.stop());
  return server;
});

/// Certificate trust status
enum CertificateTrustStatus {
  unknown, // Trust status not yet checked
  checking, // Currently checking trust status
  trusted, // Certificate is trusted
  notTrusted, // Certificate is not trusted
  error, // Error checking trust status
}

/// Tunnel test status
enum TunnelTestStatus {
  idle, // No test running
  testing, // Test in progress
  success, // Test passed
  failed, // Test failed
}

// ViewModel state
class VpnConnectionState {
  final bool isAutodiscoverMode;
  final List<ProxyHost> discoveredHosts;
  final ProxyHost? selectedHost;
  final String manualHostname;
  final int? manualPort;
  final bool useAuthentication;
  final String username;
  final String password;
  final VpnConnectionState2 connectionState;
  final String? errorMessage;
  final bool isDiscovering;
  final CertificateInfo? certificateInfo;
  final bool isCertificateLoading;
  final String? certificateError;
  final CertificateTrustStatus certificateTrustStatus;
  final bool isInstallingCertificate;
  final TunnelTestStatus tunnelTestStatus;
  final String? tunnelTestError;
  final int? tunnelTestResponseTime; // in milliseconds
  // Per-app VPN filtering
  final bool isAppFilterEnabled;
  final List<String> selectedApps; // Package names of apps allowed to use VPN
  final String appSearchQuery;
  // HTTP/3 (QUIC) blocking
  final bool blockHttp3;

  const VpnConnectionState({
    this.isAutodiscoverMode = true,
    this.discoveredHosts = const [],
    this.selectedHost,
    this.manualHostname = '',
    this.manualPort,
    this.useAuthentication = false,
    this.username = '',
    this.password = '',
    this.connectionState = VpnConnectionState2.disconnected,
    this.errorMessage,
    this.isDiscovering = false,
    this.certificateInfo,
    this.isCertificateLoading = false,
    this.certificateError,
    this.certificateTrustStatus = CertificateTrustStatus.unknown,
    this.isInstallingCertificate = false,
    this.tunnelTestStatus = TunnelTestStatus.idle,
    this.tunnelTestError,
    this.tunnelTestResponseTime,
    this.isAppFilterEnabled = false,
    this.selectedApps = const [],
    this.appSearchQuery = '',
    this.blockHttp3 = true,
  });

  bool get canConnect {
    // Allow connecting from disconnected or error state (to retry)
    if (connectionState != VpnConnectionState2.disconnected &&
        connectionState != VpnConnectionState2.error) {
      return false;
    }
    return isConfigValid;
  }

  bool get canDisconnect {
    return connectionState == VpnConnectionState2.connected ||
        connectionState == VpnConnectionState2.connecting;
  }

  bool get isConfigValid {
    if (isAutodiscoverMode) {
      return selectedHost != null;
    } else {
      if (manualHostname.isEmpty) return false;
      if (manualPort == null || manualPort! < 1 || manualPort! > 65535) {
        return false;
      }
      if (useAuthentication) {
        if (username.isEmpty || password.isEmpty) return false;
      }
      return _isValidHostname(manualHostname);
    }
  }

  bool _isValidHostname(String hostname) {
    if (hostname.isEmpty) return false;

    // Check for valid IP address
    final ipRegex = RegExp(
      r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$',
    );
    if (ipRegex.hasMatch(hostname)) return true;

    // Check for valid hostname
    final hostnameRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$',
    );
    return hostnameRegex.hasMatch(hostname);
  }

  /// Count of selected apps for display
  int get selectedAppCount => selectedApps.length;

  VpnConnectionState copyWith({
    bool? isAutodiscoverMode,
    List<ProxyHost>? discoveredHosts,
    ProxyHost? selectedHost,
    bool clearSelectedHost = false,
    String? manualHostname,
    int? manualPort,
    bool clearManualPort = false,
    bool? useAuthentication,
    String? username,
    String? password,
    VpnConnectionState2? connectionState,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isDiscovering,
    CertificateInfo? certificateInfo,
    bool clearCertificateInfo = false,
    bool? isCertificateLoading,
    String? certificateError,
    bool clearCertificateError = false,
    CertificateTrustStatus? certificateTrustStatus,
    bool? isInstallingCertificate,
    TunnelTestStatus? tunnelTestStatus,
    String? tunnelTestError,
    bool clearTunnelTestError = false,
    int? tunnelTestResponseTime,
    bool clearTunnelTestResponseTime = false,
    bool? isAppFilterEnabled,
    List<String>? selectedApps,
    String? appSearchQuery,
    bool? blockHttp3,
  }) {
    return VpnConnectionState(
      isAutodiscoverMode: isAutodiscoverMode ?? this.isAutodiscoverMode,
      discoveredHosts: discoveredHosts ?? this.discoveredHosts,
      selectedHost:
          clearSelectedHost ? null : (selectedHost ?? this.selectedHost),
      manualHostname: manualHostname ?? this.manualHostname,
      manualPort: clearManualPort ? null : (manualPort ?? this.manualPort),
      useAuthentication: useAuthentication ?? this.useAuthentication,
      username: username ?? this.username,
      password: password ?? this.password,
      connectionState: connectionState ?? this.connectionState,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isDiscovering: isDiscovering ?? this.isDiscovering,
      certificateInfo: clearCertificateInfo
          ? null
          : (certificateInfo ?? this.certificateInfo),
      isCertificateLoading: isCertificateLoading ?? this.isCertificateLoading,
      certificateError: clearCertificateError
          ? null
          : (certificateError ?? this.certificateError),
      certificateTrustStatus:
          certificateTrustStatus ?? this.certificateTrustStatus,
      isInstallingCertificate:
          isInstallingCertificate ?? this.isInstallingCertificate,
      tunnelTestStatus: tunnelTestStatus ?? this.tunnelTestStatus,
      tunnelTestError: clearTunnelTestError
          ? null
          : (tunnelTestError ?? this.tunnelTestError),
      tunnelTestResponseTime: clearTunnelTestResponseTime
          ? null
          : (tunnelTestResponseTime ?? this.tunnelTestResponseTime),
      isAppFilterEnabled: isAppFilterEnabled ?? this.isAppFilterEnabled,
      selectedApps: selectedApps ?? this.selectedApps,
      appSearchQuery: appSearchQuery ?? this.appSearchQuery,
      blockHttp3: blockHttp3 ?? this.blockHttp3,
    );
  }
}

// Renaming to avoid conflict with service enum
enum VpnConnectionState2 {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

// ViewModel
class VpnConnectionViewModel extends StateNotifier<VpnConnectionState> {
  final svc.VpnService _vpnService;
  final ConnectionStorageService _storageService;
  final AppFilterStorageService _appFilterStorage;
  final CertificateService _certificateService;
  final CertificateNativeBridge _certificateNativeBridge;
  StreamSubscription<svc.VpnConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<ProxyHost>>? _discoverySubscription;

  VpnConnectionViewModel(
    this._vpnService,
    this._storageService,
    this._appFilterStorage,
    this._certificateService,
    this._certificateNativeBridge,
  ) : super(const VpnConnectionState()) {
    _listenToConnectionState();
    _loadSavedConfig();
    _loadAppFilterSettings();
  }

  Future<void> _loadSavedConfig() async {
    final savedConfig = await _storageService.loadConnectionConfig();
    if (savedConfig != null) {
      state = state.copyWith(
        manualHostname: savedConfig.hostname,
        manualPort: savedConfig.port,
        useAuthentication: savedConfig.useAuthentication,
        username: savedConfig.username ?? '',
        password: savedConfig.password ?? '',
      );
    }
  }

  Future<void> _loadAppFilterSettings() async {
    final enabled = await _appFilterStorage.loadFilterEnabled();
    final selectedApps = await _appFilterStorage.loadSelectedApps();
    state = state.copyWith(
      isAppFilterEnabled: enabled,
      selectedApps: selectedApps,
    );
  }

  void _listenToConnectionState() {
    _connectionStateSubscription = _vpnService.connectionStateStream.listen(
      (serviceState) {
        // Defer state update to avoid modifying provider during widget build
        Future.microtask(() {
          if (!mounted) return;

          final mappedState = _mapServiceState(serviceState);
          state = state.copyWith(connectionState: mappedState);

          // Auto-fetch certificate when connected
          if (mappedState == VpnConnectionState2.connected) {
            fetchCertificate();
          }
          // Clear certificate and reset tunnel test when disconnected
          else if (mappedState == VpnConnectionState2.disconnected) {
            clearCertificate();
            resetTunnelTest();
          }
        });
      },
    );
  }

  VpnConnectionState2 _mapServiceState(svc.VpnConnectionState serviceState) {
    switch (serviceState) {
      case svc.VpnConnectionState.disconnected:
        return VpnConnectionState2.disconnected;
      case svc.VpnConnectionState.connecting:
        return VpnConnectionState2.connecting;
      case svc.VpnConnectionState.connected:
        return VpnConnectionState2.connected;
      case svc.VpnConnectionState.disconnecting:
        return VpnConnectionState2.disconnecting;
      case svc.VpnConnectionState.error:
        return VpnConnectionState2.error;
    }
  }

  void startDiscovery() {
    _discoverySubscription?.cancel();
    state = state.copyWith(isDiscovering: true, discoveredHosts: []);

    _discoverySubscription = _vpnService.discoverHosts().listen(
      (hosts) {
        // Defer state update to avoid modifying provider during widget build
        Future.microtask(() {
          if (!mounted) return;
          state = state.copyWith(
            discoveredHosts: hosts,
            isDiscovering: hosts.isEmpty,
          );
        });
      },
      onDone: () {
        Future.microtask(() {
          if (!mounted) return;
          state = state.copyWith(isDiscovering: false);
        });
      },
      onError: (error) {
        Future.microtask(() {
          if (!mounted) return;
          state = state.copyWith(
            isDiscovering: false,
            errorMessage: 'Discovery failed: $error',
          );
        });
      },
    );
  }

  void setAutodiscoverMode(bool value) {
    state = state.copyWith(isAutodiscoverMode: value);
  }

  void selectHost(ProxyHost? host) {
    if (host == null) {
      state = state.copyWith(clearSelectedHost: true);
    } else {
      state = state.copyWith(selectedHost: host);
    }
  }

  /// Fills manual configuration from a discovered host and switches to manual mode.
  void useDiscoveredHost(ProxyHost host) {
    state = state.copyWith(
      manualHostname: host.hostname,
      manualPort: host.port,
      isAutodiscoverMode: false,
    );
  }

  void setManualHostname(String hostname) {
    state = state.copyWith(manualHostname: hostname);
  }

  void setManualPort(String portString) {
    final port = int.tryParse(portString);
    if (port != null) {
      state = state.copyWith(manualPort: port);
    } else if (portString.isEmpty) {
      state = state.copyWith(clearManualPort: true);
    }
  }

  void setUseAuthentication(bool value) {
    state = state.copyWith(useAuthentication: value);
  }

  void setUsername(String username) {
    state = state.copyWith(username: username);
  }

  void setPassword(String password) {
    state = state.copyWith(password: password);
  }

  // ========== Per-App VPN Filter Methods ==========

  void setAppFilterEnabled(bool enabled) {
    state = state.copyWith(isAppFilterEnabled: enabled);
    _appFilterStorage.saveFilterEnabled(enabled);
  }

  void setSelectedApps(List<String> apps) {
    state = state.copyWith(selectedApps: apps);
    _appFilterStorage.saveSelectedApps(apps);
  }

  void toggleAppSelection(String packageName) {
    final current = List<String>.from(state.selectedApps);
    if (current.contains(packageName)) {
      current.remove(packageName);
    } else {
      current.add(packageName);
    }
    setSelectedApps(current);
  }

  void selectAllApps(List<AppInfo> apps) {
    final packageNames = apps.map((a) => a.packageName).toList();
    setSelectedApps(packageNames);
  }

  void clearAllApps() {
    setSelectedApps([]);
  }

  void setAppSearchQuery(String query) {
    state = state.copyWith(appSearchQuery: query);
  }

  // ========== HTTP/3 Blocking Methods ==========

  void setBlockHttp3(bool value) {
    state = state.copyWith(blockHttp3: value);
  }

  // ========== Connection Methods ==========

  Future<void> connect() async {
    if (!state.canConnect) return;

    final ProxyHost host;
    if (state.isAutodiscoverMode) {
      host = state.selectedHost!;
    } else {
      host = ProxyHost(
        hostname: state.manualHostname,
        port: state.manualPort!,
        isDiscovered: false,
      );
    }

    // Determine allowed apps for whitelist
    final List<String>? allowedApps;
    if (state.isAppFilterEnabled && state.selectedApps.isNotEmpty) {
      allowedApps = state.selectedApps;
    } else {
      allowedApps = null; // No filtering - all apps use VPN
    }

    try {
      state = state.copyWith(clearErrorMessage: true);
      await _vpnService.connect(
        host,
        username: state.useAuthentication ? state.username : null,
        password: state.useAuthentication ? state.password : null,
        allowedApps: allowedApps,
        blockHttp3: state.blockHttp3,
      );

      // Save manual configuration for next session
      if (!state.isAutodiscoverMode) {
        await _storageService.saveConnectionConfig(
          hostname: state.manualHostname,
          port: state.manualPort!,
          useAuthentication: state.useAuthentication,
          username: state.useAuthentication ? state.username : null,
          password: state.useAuthentication ? state.password : null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        connectionState: VpnConnectionState2.error,
        errorMessage: 'Connection failed: $e',
      );
    }
  }

  Future<void> disconnect() async {
    if (!state.canDisconnect) return;

    try {
      await _vpnService.disconnect();
    } catch (e) {
      state = state.copyWith(
        connectionState: VpnConnectionState2.error,
        errorMessage: 'Disconnect failed: $e',
      );
    }
  }

  /// Fetches the CA certificate from the connected proxy server.
  Future<void> fetchCertificate() async {
    // Determine the host to fetch certificate from
    final String hostname;
    final int port;

    if (state.isAutodiscoverMode && state.selectedHost != null) {
      hostname = state.selectedHost!.hostname;
      port = state.selectedHost!.port;
    } else if (!state.isAutodiscoverMode &&
        state.manualHostname.isNotEmpty &&
        state.manualPort != null) {
      hostname = state.manualHostname;
      port = state.manualPort!;
    } else {
      // No valid host information available
      return;
    }

    state = state.copyWith(
      isCertificateLoading: true,
      clearCertificateError: true,
      clearCertificateInfo: true,
    );

    try {
      final certInfo = await _certificateService.fetchCertificate(
        hostname: hostname,
        port: port,
      );
      state = state.copyWith(
        certificateInfo: certInfo,
        isCertificateLoading: false,
      );

      // Auto-check trust status after fetching
      await checkCertificateTrust();
    } catch (e) {
      state = state.copyWith(
        isCertificateLoading: false,
        certificateError: e.toString(),
      );
    }
  }

  /// Clears the certificate state.
  void clearCertificate() {
    state = state.copyWith(
      clearCertificateInfo: true,
      clearCertificateError: true,
      isCertificateLoading: false,
      certificateTrustStatus: CertificateTrustStatus.unknown,
      isInstallingCertificate: false,
    );
  }

  /// Checks if the current certificate is trusted.
  Future<void> checkCertificateTrust() async {
    final certInfo = state.certificateInfo;
    if (certInfo == null) return;

    if (!_certificateNativeBridge.isSupported) {
      // Not supported on this platform
      state = state.copyWith(
        certificateTrustStatus: CertificateTrustStatus.unknown,
      );
      return;
    }

    state = state.copyWith(
      certificateTrustStatus: CertificateTrustStatus.checking,
    );

    try {
      final isTrusted = await _certificateNativeBridge.isCertificateTrusted(
        certInfo.fingerprint,
      );
      state = state.copyWith(
        certificateTrustStatus: isTrusted
            ? CertificateTrustStatus.trusted
            : CertificateTrustStatus.notTrusted,
      );
    } catch (e) {
      state = state.copyWith(
        certificateTrustStatus: CertificateTrustStatus.error,
      );
    }
  }

  /// Requests installation of the current certificate.
  Future<void> installCertificate() async {
    final certInfo = state.certificateInfo;
    if (certInfo == null) return;

    if (!_certificateNativeBridge.isSupported) {
      return;
    }

    state = state.copyWith(isInstallingCertificate: true);

    try {
      final flowCompleted =
          await _certificateNativeBridge.requestInstallCertificate(
        certPem: certInfo.rawPem,
        certName: certInfo.commonName,
      );

      state = state.copyWith(isInstallingCertificate: false);

      // If the flow completed, re-check trust status
      if (flowCompleted) {
        await checkCertificateTrust();
      }
    } catch (e) {
      state = state.copyWith(
        isInstallingCertificate: false,
        certificateTrustStatus: CertificateTrustStatus.error,
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Tests the tunnel by fetching a test URL through the SOCKS5 proxy.
  Future<void> testTunnel() async {
    void log(String msg) => debugPrint('[TunnelTest] $msg');

    log('Starting tunnel test...');

    if (state.connectionState != VpnConnectionState2.connected) {
      log('Not connected, aborting test');
      return;
    }

    // Get proxy host/port from current connection
    final String proxyHost;
    final int proxyPort;

    if (state.isAutodiscoverMode && state.selectedHost != null) {
      proxyHost = state.selectedHost!.hostname;
      proxyPort = state.selectedHost!.port;
    } else if (!state.isAutodiscoverMode &&
        state.manualHostname.isNotEmpty &&
        state.manualPort != null) {
      proxyHost = state.manualHostname;
      proxyPort = state.manualPort!;
    } else {
      log('ERROR: No proxy configured');
      state = state.copyWith(
        tunnelTestStatus: TunnelTestStatus.failed,
        tunnelTestError: 'No proxy configured',
      );
      return;
    }

    log('Proxy: $proxyHost:$proxyPort');
    log('Auth enabled: ${state.useAuthentication}');

    state = state.copyWith(
      tunnelTestStatus: TunnelTestStatus.testing,
      clearTunnelTestError: true,
      clearTunnelTestResponseTime: true,
    );

    const testUrl = 'https://fluxzy.io/assets/images/logo-small.png';
    final uri = Uri.parse(testUrl);
    log('Test URL: $testUrl');
    log('Target host: ${uri.host}:${uri.port}');

    final stopwatch = Stopwatch()..start();

    HttpClient? client;
    try {
      // Create HTTP client with SOCKS5 connection factory
      client = HttpClient();

      // Configure SOCKS5 proxy with optional authentication
      final proxySettings = ProxySettings(
        InternetAddress(proxyHost),
        proxyPort,
        username: state.useAuthentication ? state.username : null,
        password: state.useAuthentication ? state.password : null,
      );

      // Use assignToHttpClientWithSecureOptions to accept proxy's TLS certificate
      // The proxy (Fluxzy) intercepts HTTPS and presents its own certificate
      SocksTCPClient.assignToHttpClientWithSecureOptions(
        client,
        [proxySettings],
        onBadCertificate: (X509Certificate cert) {
          log('Accepting proxy certificate: ${cert.subject}');
          return true; // Accept the proxy's certificate
        },
      );
      log('HttpClient configured with SOCKS5 proxy: $proxyHost:$proxyPort');

      // Set timeouts
      client.connectionTimeout = const Duration(seconds: 10);
      log('Connection timeout: 10s');

      log('Opening connection to $testUrl...');
      final request = await client.getUrl(uri);
      log('Request created, sending...');

      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      log('Response received: ${response.statusCode}');

      // Read response body
      log('Reading response body...');
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      log('Body size: ${bytes.length} bytes');

      stopwatch.stop();
      log('Total time: ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200 && bytes.isNotEmpty) {
        log('TEST PASSED!');
        state = state.copyWith(
          tunnelTestStatus: TunnelTestStatus.success,
          tunnelTestResponseTime: stopwatch.elapsedMilliseconds,
        );
      } else {
        log('TEST FAILED: HTTP ${response.statusCode}, body empty: ${bytes.isEmpty}');
        state = state.copyWith(
          tunnelTestStatus: TunnelTestStatus.failed,
          tunnelTestError: 'HTTP ${response.statusCode}',
          tunnelTestResponseTime: stopwatch.elapsedMilliseconds,
        );
      }
    } on TimeoutException catch (e, stack) {
      stopwatch.stop();
      log('TEST FAILED: Timeout - $e');
      debugPrintStack(stackTrace: stack, label: '[TunnelTest] Stack');
      state = state.copyWith(
        tunnelTestStatus: TunnelTestStatus.failed,
        tunnelTestError: 'Request timed out',
      );
    } on SocketException catch (e, stack) {
      stopwatch.stop();
      log('TEST FAILED: SocketException');
      log('  message: ${e.message}');
      log('  osError: ${e.osError}');
      log('  address: ${e.address}');
      log('  port: ${e.port}');
      debugPrintStack(stackTrace: stack, label: '[TunnelTest] Stack');
      state = state.copyWith(
        tunnelTestStatus: TunnelTestStatus.failed,
        tunnelTestError: 'Network error: ${e.message}',
      );
    } on HandshakeException catch (e, stack) {
      stopwatch.stop();
      log('TEST FAILED: TLS Handshake error - $e');
      debugPrintStack(stackTrace: stack, label: '[TunnelTest] Stack');
      state = state.copyWith(
        tunnelTestStatus: TunnelTestStatus.failed,
        tunnelTestError: 'TLS error: ${e.message}',
      );
    } on HttpException catch (e, stack) {
      stopwatch.stop();
      log('TEST FAILED: HttpException - $e');
      debugPrintStack(stackTrace: stack, label: '[TunnelTest] Stack');
      state = state.copyWith(
        tunnelTestStatus: TunnelTestStatus.failed,
        tunnelTestError: 'HTTP error: ${e.message}',
      );
    } catch (e, stack) {
      stopwatch.stop();
      log('TEST FAILED: ${e.runtimeType} - $e');
      debugPrintStack(stackTrace: stack, label: '[TunnelTest] Stack');
      state = state.copyWith(
        tunnelTestStatus: TunnelTestStatus.failed,
        tunnelTestError: '${e.runtimeType}: $e',
      );
    } finally {
      log('Closing HttpClient');
      client?.close();
    }
  }

  /// Resets the tunnel test state.
  void resetTunnelTest() {
    state = state.copyWith(
      tunnelTestStatus: TunnelTestStatus.idle,
      clearTunnelTestError: true,
      clearTunnelTestResponseTime: true,
    );
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _discoverySubscription?.cancel();
    super.dispose();
  }
}

// Provider
final vpnConnectionViewModelProvider =
    StateNotifierProvider<VpnConnectionViewModel, VpnConnectionState>((ref) {
  final vpnService = ref.watch(vpnServiceProvider);
  final storageService = ref.watch(connectionStorageProvider);
  final appFilterStorage = ref.watch(appFilterStorageProvider);
  final certificateService = ref.watch(certificateServiceProvider);
  final certificateNativeBridge = ref.watch(certificateNativeBridgeProvider);
  return VpnConnectionViewModel(
    vpnService,
    storageService,
    appFilterStorage,
    certificateService,
    certificateNativeBridge,
  );
});
