import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/vpn_control_api.dart';
import 'secure_certificate_service.dart';
import 'vpn_control_api_service.dart';
import 'vpn_control_swagger.dart';

/// Information about an available API route.
class RouteInfo {
  final String method;
  final String path;
  final String description;
  final bool requiresAuth;

  const RouteInfo({
    required this.method,
    required this.path,
    required this.description,
    this.requiresAuth = true,
  });
}

/// HTTP server that exposes VPN control endpoints.
///
/// Listens on all network interfaces (0.0.0.0) and provides:
/// - POST /connect - Connect to VPN
/// - POST /disconnect - Disconnect from VPN
/// - GET /status - Get connection status
///
/// Supports HTTPS with self-signed certificates and optional bearer token authentication.
class VpnControlServer {
  /// List of all available routes.
  /// This list is the source of truth for available endpoints.
  static const List<RouteInfo> availableRoutes = [
    RouteInfo(
      method: 'GET',
      path: '/',
      description: 'Health check endpoint',
      requiresAuth: false,
    ),
    RouteInfo(
      method: 'GET',
      path: '/health',
      description: 'Health check endpoint',
      requiresAuth: false,
    ),
    RouteInfo(
      method: 'POST',
      path: '/connect',
      description: 'Connect to VPN with specified proxy host',
    ),
    RouteInfo(
      method: 'POST',
      path: '/disconnect',
      description: 'Disconnect from VPN',
    ),
    RouteInfo(
      method: 'GET',
      path: '/status',
      description: 'Get current VPN connection status',
    ),
    RouteInfo(
      method: 'GET',
      path: '/swagger',
      description: 'Swagger UI API documentation',
      requiresAuth: false,
    ),
  ];
  final VpnControlApiService _apiService;
  final SecureCertificateService _certificateService;
  final int _defaultPort;

  HttpServer? _server;
  bool _isRunning = false;
  int? _currentPort;
  bool _isHttps = false;
  bool _isAuthEnabled = false;

  VpnControlServer({
    required VpnControlApiService apiService,
    SecureCertificateService? certificateService,
    int port = 18080,
  })  : _apiService = apiService,
        _certificateService = certificateService ?? SecureCertificateService(),
        _defaultPort = port;

  /// Whether the server is currently running.
  bool get isRunning => _isRunning;

  /// The port the server is currently running on (or null if not running).
  int? get currentPort => _currentPort;

  /// Whether the server is running with HTTPS.
  bool get isHttps => _isHttps;

  /// Whether authentication is enabled.
  bool get isAuthEnabled => _isAuthEnabled;

  /// The server's address if running.
  String? get address {
    if (_currentPort == null) return null;
    final protocol = _isHttps ? 'https' : 'http';
    return '$protocol://0.0.0.0:$_currentPort';
  }

  /// Starts the HTTP/HTTPS server.
  ///
  /// Listens on all network interfaces (0.0.0.0).
  /// [port] - The port to listen on. If not specified, uses the default port.
  /// [https] - If true, enables HTTPS using a self-signed certificate.
  /// [authToken] - If provided, enables bearer token authentication.
  Future<void> start({
    int? port,
    bool https = false,
    String? authToken,
  }) async {
    final targetPort = port ?? _defaultPort;

    if (_isRunning) {
      debugPrint('[VpnControlServer] Server already running on port $_currentPort');
      return;
    }

    // Generate certificate if needed for HTTPS
    if (https) {
      await _certificateService.generateCertificateIfNeeded();
      await _certificateService.debugDumpCertificateInfo();
    }

    final router = _createRouter();
    final handler = Pipeline()
        .addMiddleware(_logRequests())
        .addMiddleware(_authMiddleware(authToken))
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_contentTypeMiddleware())
        .addHandler(router.call);

    try {
      if (https) {
        debugPrint('[VpnControlServer] Getting security context for HTTPS...');
        final securityContext = await _certificateService.getSecurityContext();
        debugPrint('[VpnControlServer] Security context obtained, starting HTTPS server...');
        _server = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          targetPort,
          shared: true,
          securityContext: securityContext,
        );
        _isHttps = true;
        debugPrint('[VpnControlServer] HTTPS server started successfully');
      } else {
        _server = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          targetPort,
          shared: true,
        );
        _isHttps = false;
      }

      _isRunning = true;
      _currentPort = targetPort;
      _isAuthEnabled = authToken != null;

      final protocol = _isHttps ? 'https' : 'http';
      final authStatus = _isAuthEnabled ? ' (auth enabled)' : '';
      debugPrint('[VpnControlServer] Server started on $protocol://0.0.0.0:$targetPort$authStatus');
    } catch (e, stack) {
      debugPrint('[VpnControlServer] Failed to start server: $e');
      debugPrint('[VpnControlServer] Stack trace: $stack');
      rethrow;
    }
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    if (!_isRunning || _server == null) {
      debugPrint('[VpnControlServer] Server not running');
      return;
    }

    await _server!.close(force: true);
    _server = null;
    _isRunning = false;
    _currentPort = null;
    _isHttps = false;
    _isAuthEnabled = false;
    debugPrint('[VpnControlServer] Server stopped');
  }

  /// Creates the router with all endpoints.
  Router _createRouter() {
    final router = Router();

    // Health check
    router.get('/', _handleHealth);
    router.get('/health', _handleHealth);

    // VPN control endpoints
    router.post('/connect', _handleConnect);
    router.post('/disconnect', _handleDisconnect);
    router.get('/status', _handleStatus);

    // Documentation
    router.get('/swagger', _handleSwagger);

    // Catch-all for 404
    router.all('/<ignored|.*>', _handleNotFound);

    return router;
  }

  /// Health check endpoint.
  Response _handleHealth(Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'service': 'fluxzy-vpn-control'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /connect - Connect to VPN.
  Future<Response> _handleConnect(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _jsonResponse(
          ApiResponse.error('Request body is required'),
          status: 400,
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final connectRequest = ConnectRequest.fromJson(json);

      final result = await _apiService.connect(connectRequest);
      return _jsonResponse(result, status: result.success ? 200 : 400);
    } on FormatException catch (e) {
      return _jsonResponse(
        ApiResponse.error('Invalid request: ${e.message}'),
        status: 400,
      );
    } catch (e) {
      return _jsonResponse(
        ApiResponse.error('Server error: $e'),
        status: 500,
      );
    }
  }

  /// POST /disconnect - Disconnect from VPN.
  Future<Response> _handleDisconnect(Request request) async {
    try {
      final result = await _apiService.disconnect();
      return _jsonResponse(result, status: result.success ? 200 : 400);
    } catch (e) {
      return _jsonResponse(
        ApiResponse.error('Server error: $e'),
        status: 500,
      );
    }
  }

  /// GET /status - Get connection status.
  Response _handleStatus(Request request) {
    try {
      final status = _apiService.getStatus();
      return Response.ok(
        status.toJsonString(),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _jsonResponse(
        ApiResponse.error('Server error: $e'),
        status: 500,
      );
    }
  }

  /// GET /swagger - Swagger UI documentation.
  Response _handleSwagger(Request request) {
    return Response.ok(
      VpnControlSwagger.buildSwaggerHtml(),
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  /// 404 handler.
  Response _handleNotFound(Request request) {
    return _jsonResponse(
      ApiResponse.error('Not found: ${request.url.path}'),
      status: 404,
    );
  }

  /// Helper to create JSON responses.
  Response _jsonResponse(ApiResponse response, {int status = 200}) {
    return Response(
      status,
      body: response.toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Middleware for logging requests.
  Middleware _logRequests() {
    return (Handler handler) {
      return (Request request) async {
        final stopwatch = Stopwatch()..start();
        final response = await handler(request);
        stopwatch.stop();

        debugPrint(
          '[VpnControlServer] ${request.method} ${request.url.path} '
          '-> ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
        );

        return response;
      };
    };
  }

  /// CORS middleware for cross-origin requests.
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        // Handle preflight requests
        if (request.method == 'OPTIONS') {
          return Response.ok(
            '',
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
              'Access-Control-Allow-Headers': 'Content-Type, Authorization',
              'Access-Control-Max-Age': '86400',
            },
          );
        }

        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
        });
      };
    };
  }

  /// Middleware to ensure Content-Type header.
  Middleware _contentTypeMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final response = await handler(request);
        if (!response.headers.containsKey('Content-Type')) {
          return response.change(headers: {
            'Content-Type': 'application/json',
          });
        }
        return response;
      };
    };
  }

  /// Authentication middleware for bearer token validation.
  ///
  /// If [expectedToken] is null, no authentication is required.
  /// The /health and / endpoints are always exempt from authentication.
  Middleware _authMiddleware(String? expectedToken) {
    return (Handler handler) {
      return (Request request) async {
        // Skip auth for health check endpoints
        final path = request.url.path;
        if (path == '' || path == '/' || path == 'health' || path == 'swagger') {
          return handler(request);
        }

        // Skip auth for OPTIONS preflight requests
        if (request.method == 'OPTIONS') {
          return handler(request);
        }

        // If no token configured, skip auth
        if (expectedToken == null) {
          return handler(request);
        }

        // Check Authorization header
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.unauthorized(
            jsonEncode({
              'success': false,
              'error': 'Missing or invalid Authorization header. Expected: Bearer <token>',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final providedToken = authHeader.substring(7); // Remove 'Bearer ' prefix
        if (providedToken != expectedToken) {
          return Response.forbidden(
            jsonEncode({
              'success': false,
              'error': 'Invalid authentication token',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        return handler(request);
      };
    };
  }
}
