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
}
