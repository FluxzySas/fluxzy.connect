import '../models/app_info.dart';
import '../models/proxy_host.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

abstract class VpnService {
  Stream<List<ProxyHost>> discoverHosts();
  Future<void> connect(
    ProxyHost host, {
    String? username,
    String? password,
    List<String>? allowedApps,
    bool blockHttp3 = false,
  });
  Future<void> disconnect();
  Stream<VpnConnectionState> get connectionStateStream;
  VpnConnectionState get currentState;

  /// Retrieves list of installed applications for per-app VPN filtering.
  Future<List<AppInfo>> getInstalledApps({bool includeSystemApps = false});

  /// Opens the system VPN settings screen, where the user can enable
  /// Always-on VPN so the tunnel is restored automatically after a reboot.
  /// Returns false if the screen could not be opened on this platform.
  Future<bool> openVpnSettings();
}
