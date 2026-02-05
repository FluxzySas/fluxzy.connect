import 'dart:async';

import '../models/proxy_host.dart';
import '../models/vpn_control_api.dart';
import 'vpn_service.dart';

/// Service that provides VPN control operations for the HTTP API.
///
/// This service abstracts the VPN operations and provides idempotent
/// connect/disconnect methods suitable for external API consumption.
class VpnControlApiService {
  final VpnService _vpnService;

  /// Currently connected host info (set when connect succeeds).
  ProxyHost? _currentHost;

  /// Lock to prevent concurrent connect/disconnect operations.
  bool _operationInProgress = false;

  VpnControlApiService(this._vpnService);

  /// Returns the current VPN connection state.
  VpnConnectionState get currentState => _vpnService.currentState;

  /// Returns true if VPN is connected.
  bool get isConnected => currentState == VpnConnectionState.connected;

  /// Returns the current host if connected.
  ProxyHost? get currentHost => _currentHost;

  /// Connects to the VPN with the specified configuration.
  ///
  /// This operation is idempotent:
  /// - If already connected to the same host, returns success immediately.
  /// - If connected to a different host, returns error (must disconnect first).
  /// - If already connecting/disconnecting, returns error.
  Future<ApiResponse> connect(ConnectRequest request) async {
    // Check if operation is in progress
    if (_operationInProgress) {
      return ApiResponse.error('Operation already in progress');
    }

    final state = currentState;

    // If already connected, check if it's the same host
    if (state == VpnConnectionState.connected) {
      if (_currentHost != null &&
          _currentHost!.hostname == request.host &&
          _currentHost!.port == request.port) {
        return ApiResponse.success('Already connected');
      }
      return ApiResponse.error(
        'Already connected to ${_currentHost?.address ?? "unknown"}. Disconnect first.',
      );
    }

    // If connecting or disconnecting, return error
    if (state == VpnConnectionState.connecting) {
      return ApiResponse.error('Connection already in progress');
    }
    if (state == VpnConnectionState.disconnecting) {
      return ApiResponse.error('Disconnect in progress');
    }

    _operationInProgress = true;

    try {
      final host = ProxyHost(
        hostname: request.host,
        port: request.port,
        isDiscovered: false,
      );

      await _vpnService.connect(
        host,
        username: request.username,
        password: request.password,
      );

      // Wait for connection to establish
      final result = await _waitForState(
        [VpnConnectionState.connected, VpnConnectionState.error],
        timeout: const Duration(seconds: 30),
      );

      if (result == VpnConnectionState.connected) {
        _currentHost = host;
        return ApiResponse.success('Connected');
      } else {
        return ApiResponse.error('Connection failed');
      }
    } catch (e) {
      return ApiResponse.error('Connection error: $e');
    } finally {
      _operationInProgress = false;
    }
  }

  /// Disconnects the VPN.
  ///
  /// This operation is idempotent:
  /// - If already disconnected, returns success immediately.
  /// - If connecting/disconnecting, waits for completion then disconnects if needed.
  Future<ApiResponse> disconnect() async {
    // Check if operation is in progress
    if (_operationInProgress) {
      return ApiResponse.error('Operation already in progress');
    }

    final state = currentState;

    // Already disconnected
    if (state == VpnConnectionState.disconnected) {
      _currentHost = null;
      return ApiResponse.success('Already disconnected');
    }

    // If in error state, we can consider it disconnected
    if (state == VpnConnectionState.error) {
      _currentHost = null;
      return ApiResponse.success('Disconnected (was in error state)');
    }

    _operationInProgress = true;

    try {
      await _vpnService.disconnect();

      // Wait for disconnection
      final result = await _waitForState(
        [VpnConnectionState.disconnected, VpnConnectionState.error],
        timeout: const Duration(seconds: 10),
      );

      _currentHost = null;

      if (result == VpnConnectionState.disconnected) {
        return ApiResponse.success('Disconnected');
      } else {
        return ApiResponse.success('Disconnected (with error state)');
      }
    } catch (e) {
      return ApiResponse.error('Disconnect error: $e');
    } finally {
      _operationInProgress = false;
    }
  }

  /// Returns the current VPN status.
  StatusResponse getStatus() {
    final state = currentState;
    return StatusResponse(
      connected: state == VpnConnectionState.connected,
      state: state.name,
      host: _currentHost?.hostname,
      port: _currentHost?.port,
    );
  }

  /// Waits for the VPN to reach one of the expected states.
  Future<VpnConnectionState> _waitForState(
    List<VpnConnectionState> expectedStates, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (expectedStates.contains(currentState)) {
      return currentState;
    }

    final completer = Completer<VpnConnectionState>();
    late final StreamSubscription<VpnConnectionState> subscription;

    subscription = _vpnService.connectionStateStream.listen((state) {
      if (expectedStates.contains(state) && !completer.isCompleted) {
        completer.complete(state);
        subscription.cancel();
      }
    });

    try {
      return await completer.future.timeout(timeout, onTimeout: () {
        subscription.cancel();
        return currentState;
      });
    } catch (e) {
      subscription.cancel();
      return currentState;
    }
  }
}
