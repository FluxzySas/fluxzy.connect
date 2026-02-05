import 'dart:async';
import '../models/app_info.dart';
import '../models/proxy_host.dart';
import 'vpn_service.dart';

class MockVpnService implements VpnService {
  final _stateController = StreamController<VpnConnectionState>.broadcast();
  VpnConnectionState _currentState = VpnConnectionState.disconnected;

  @override
  VpnConnectionState get currentState => _currentState;

  @override
  Stream<VpnConnectionState> get connectionStateStream => _stateController.stream;

  void _setState(VpnConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Stream<List<ProxyHost>> discoverHosts() async* {
    final mockHosts = [
      const ProxyHost(
        hostname: '192.168.1.100',
        port: 9852,
        isDiscovered: true,
        hostName: 'DESKTOP-HOME',
        osName: 'Windows 11',
        fluxzyVersion: '1.2.3',
        fluxzyStartupSetting: 'Listen on 0.0.0.0:9852\nSystem proxy: enabled\nCapture mode: full\nSSL decryption: enabled',
        certEndpoint: '/cert',
      ),
      const ProxyHost(
        hostname: 'proxy.office.local',
        port: 9852,
        isDiscovered: true,
        hostName: 'OFFICE-SERVER',
        osName: 'Windows Server 2022',
        fluxzyVersion: '1.2.1',
        fluxzyStartupSetting: 'Listen on 0.0.0.0:9852\nSystem proxy: disabled\nCapture mode: headers-only\nSSL decryption: disabled\nMax connections: 500\nLog level: verbose',
        certEndpoint: '/cert',
      ),
      const ProxyHost(
        hostname: '10.0.0.50',
        port: 8080,
        isDiscovered: true,
        hostName: 'DEV-MACBOOK',
        osName: 'macOS Sonoma 14.2',
        fluxzyVersion: '1.3.0-beta',
        fluxzyStartupSetting: 'Listen on 127.0.0.1:8080\nSystem proxy: enabled\nCapture mode: full\nSSL decryption: enabled\nCertificate: custom CA',
        certEndpoint: '/cert',
      ),
      const ProxyHost(
        hostname: '192.168.1.42',
        port: 9852,
        isDiscovered: true,
        hostName: 'LINUX-BOX',
        osName: 'Ubuntu 22.04 LTS',
        fluxzyVersion: '1.2.3',
        fluxzyStartupSetting: 'Listen on 0.0.0.0:9852\nSystem proxy: disabled\nCapture mode: full\nSSL decryption: enabled\nFilter: *.example.com\nUpstream proxy: http://corporate:3128',
        certEndpoint: '/cert',
      ),
    ];

    // Initial empty state
    yield [];

    // Simulate discovery delay
    await Future.delayed(const Duration(seconds: 2));

    // Emit first batch
    yield mockHosts.take(2).toList();

    // Continue discovering
    await Future.delayed(const Duration(seconds: 2));

    // Emit all hosts
    yield mockHosts;
  }

  @override
  Future<void> connect(
    ProxyHost host, {
    String? username,
    String? password,
    List<String>? allowedApps,
    bool blockHttp3 = false,
  }) async {
    if (_currentState == VpnConnectionState.connecting ||
        _currentState == VpnConnectionState.connected) {
      return;
    }

    _setState(VpnConnectionState.connecting);

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 1500));

    _setState(VpnConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    if (_currentState == VpnConnectionState.disconnected ||
        _currentState == VpnConnectionState.disconnecting) {
      return;
    }

    _setState(VpnConnectionState.disconnecting);

    // Simulate disconnect delay
    await Future.delayed(const Duration(milliseconds: 500));

    _setState(VpnConnectionState.disconnected);
  }

  @override
  Future<List<AppInfo>> getInstalledApps({bool includeSystemApps = false}) async {
    // Return mock apps for testing
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      AppInfo(packageName: 'com.android.chrome', appName: 'Chrome'),
      AppInfo(packageName: 'org.mozilla.firefox', appName: 'Firefox'),
      AppInfo(packageName: 'com.slack', appName: 'Slack'),
      AppInfo(packageName: 'com.spotify.music', appName: 'Spotify'),
      AppInfo(packageName: 'com.whatsapp', appName: 'WhatsApp'),
    ];
  }

  void dispose() {
    _stateController.close();
  }
}
