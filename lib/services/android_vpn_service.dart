import 'dart:async';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../models/proxy_host.dart';
import 'vpn_service.dart';

/// Android implementation of VpnService using platform channels.
class AndroidVpnService implements VpnService {
  static const _methodChannel = MethodChannel('io.fluxzy.mobile.connect/vpn');
  static const _discoveryChannel =
      EventChannel('io.fluxzy.mobile.connect/vpn/discovery');
  static const _stateChannel =
      EventChannel('io.fluxzy.mobile.connect/vpn/state');

  final _stateController = StreamController<VpnConnectionState>.broadcast();
  VpnConnectionState _currentState = VpnConnectionState.disconnected;
  StreamSubscription<dynamic>? _stateSubscription;

  AndroidVpnService() {
    _initStateListener();
  }

  void _initStateListener() {
    _stateSubscription = _stateChannel.receiveBroadcastStream().listen(
      (event) {
        final state = _parseState(event as String);
        _currentState = state;
        _stateController.add(state);
      },
      onError: (error) {
        _currentState = VpnConnectionState.error;
        _stateController.add(VpnConnectionState.error);
      },
    );
  }

  VpnConnectionState _parseState(String state) {
    switch (state) {
      case 'disconnected':
        return VpnConnectionState.disconnected;
      case 'connecting':
        return VpnConnectionState.connecting;
      case 'connected':
        return VpnConnectionState.connected;
      case 'disconnecting':
        return VpnConnectionState.disconnecting;
      case 'error':
        return VpnConnectionState.error;
      default:
        return VpnConnectionState.disconnected;
    }
  }

  @override
  VpnConnectionState get currentState => _currentState;

  @override
  Stream<VpnConnectionState> get connectionStateStream => _stateController.stream;

  @override
  Stream<List<ProxyHost>> discoverHosts() {
    return _discoveryChannel.receiveBroadcastStream().map((event) {
      if (event is List) {
        return _parseHosts(event);
      }
      return <ProxyHost>[];
    });
  }

  List<ProxyHost> _parseHosts(List<dynamic> hosts) {
    return hosts.map((host) {
      final map = Map<String, dynamic>.from(host as Map);
      return ProxyHost(
        hostname: map['hostname'] as String,
        port: map['port'] as int,
        isDiscovered: map['isDiscovered'] as bool? ?? true,
        hostName: map['hostName'] as String?,
        osName: map['osName'] as String?,
        fluxzyVersion: map['fluxzyVersion'] as String?,
        fluxzyStartupSetting: map['fluxzyStartupSetting'] as String?,
        certEndpoint: map['certEndpoint'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> connect(
    ProxyHost host, {
    String? username,
    String? password,
    List<String>? allowedApps,
    bool blockHttp3 = false,
  }) async {
    try {
      await _methodChannel.invokeMethod('connect', {
        'hostname': host.hostname,
        'port': host.port,
        'username': username,
        'password': password,
        'allowedApps': allowedApps,
        'blockHttp3': blockHttp3,
      });
    } on PlatformException catch (e) {
      _currentState = VpnConnectionState.error;
      _stateController.add(VpnConnectionState.error);
      throw Exception('Connection failed: ${e.message}');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      throw Exception('Disconnect failed: ${e.message}');
    }
  }

  /// Requests VPN permission from the user.
  /// Returns true if permission is already granted.
  Future<bool> prepareVpn() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('prepareVpn');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to prepare VPN: ${e.message}');
    }
  }

  /// Downloads the certificate from the proxy host.
  /// Returns the local file path where the certificate was saved.
  Future<String?> downloadCertificate(ProxyHost host) async {
    if (host.certEndpoint == null) {
      return null;
    }

    try {
      final path =
          await _methodChannel.invokeMethod<String>('downloadCertificate', {
        'hostname': host.hostname,
        'port': host.port,
        'certEndpoint': host.certEndpoint,
      });
      return path;
    } on PlatformException catch (e) {
      throw Exception('Certificate download failed: ${e.message}');
    }
  }

  /// Gets the current state from the native side.
  Future<VpnConnectionState> getStateFromNative() async {
    try {
      final stateStr = await _methodChannel.invokeMethod<String>('getState');
      return _parseState(stateStr ?? 'disconnected');
    } on PlatformException {
      return VpnConnectionState.disconnected;
    }
  }

  @override
  Future<List<AppInfo>> getInstalledApps({bool includeSystemApps = false}) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
        {'includeSystemApps': includeSystemApps},
      );

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return AppInfo.fromMap(map);
      }).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get installed apps: ${e.message}');
    }
  }

  void dispose() {
    _stateSubscription?.cancel();
    _stateController.close();
  }
}
