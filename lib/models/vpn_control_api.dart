import 'dart:convert';

/// Request model for the /connect endpoint.
class ConnectRequest {
  final String host;
  final int port;
  final String? username;
  final String? password;

  const ConnectRequest({
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  bool get hasAuthentication =>
      username != null &&
      username!.isNotEmpty &&
      password != null &&
      password!.isNotEmpty;

  factory ConnectRequest.fromJson(Map<String, dynamic> json) {
    final host = json['host'];
    final port = json['port'];

    if (host == null || host is! String || host.isEmpty) {
      throw FormatException('Missing or invalid "host" field');
    }
    if (port == null || port is! int || port < 1 || port > 65535) {
      throw FormatException('Missing or invalid "port" field (must be 1-65535)');
    }

    return ConnectRequest(
      host: host,
      port: port,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
      };

  @override
  String toString() => 'ConnectRequest(host: $host, port: $port, auth: $hasAuthentication)';
}

/// Response model for API operations.
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        if (data != null) ...data!,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ApiResponse.success(String message, {Map<String, dynamic>? data}) =>
      ApiResponse(success: true, message: message, data: data);

  factory ApiResponse.error(String message) =>
      ApiResponse(success: false, message: message);
}

/// Status response model for the /status endpoint.
class StatusResponse {
  final bool connected;
  final String state;
  final String? host;
  final int? port;

  const StatusResponse({
    required this.connected,
    required this.state,
    this.host,
    this.port,
  });

  Map<String, dynamic> toJson() => {
        'connected': connected,
        'state': state,
        if (host != null) 'host': host,
        if (port != null) 'port': port,
      };

  String toJsonString() => jsonEncode(toJson());
}
