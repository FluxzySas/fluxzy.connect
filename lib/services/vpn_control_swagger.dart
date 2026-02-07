import 'dart:convert';

/// Provides OpenAPI 3.0 spec and Swagger UI HTML for the VPN Control API.
class VpnControlSwagger {
  /// Builds the full OpenAPI 3.0.3 specification as a Map.
  static Map<String, dynamic> buildOpenApiSpec() {
    return {
      'openapi': '3.0.3',
      'info': {
        'title': 'Fluxzy Connect VPN Control API',
        'description':
            'HTTP API for controlling the Fluxzy Connect VPN connection programmatically. '
                'The server listens on all network interfaces (0.0.0.0) on port 18080.',
        'version': '1.0.0',
        'contact': {
          'name': 'Fluxzy',
        },
      },
      'servers': [
        {
          'url': '/',
          'description': 'Current server',
        },
      ],
      'tags': [
        {
          'name': 'Health',
          'description': 'Health check endpoints',
        },
        {
          'name': 'VPN Control',
          'description': 'VPN connection management endpoints',
        },
        {
          'name': 'Documentation',
          'description': 'API documentation endpoints',
        },
      ],
      'paths': {
        '/': {
          'get': {
            'tags': ['Health'],
            'summary': 'Health check',
            'description':
                'Health check endpoint to verify the API server is running. Alias for /health.',
            'operationId': 'healthCheckRoot',
            'security': <Map<String, dynamic>>[],
            'responses': {
              '200': {
                'description': 'Server is healthy',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/HealthResponse'},
                  },
                },
              },
            },
          },
        },
        '/health': {
          'get': {
            'tags': ['Health'],
            'summary': 'Health check',
            'description':
                'Health check endpoint to verify the API server is running.',
            'operationId': 'healthCheck',
            'security': <Map<String, dynamic>>[],
            'responses': {
              '200': {
                'description': 'Server is healthy',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/HealthResponse'},
                  },
                },
              },
            },
          },
        },
        '/connect': {
          'post': {
            'tags': ['VPN Control'],
            'summary': 'Connect to VPN',
            'description':
                'Connects to a SOCKS5 proxy through the VPN tunnel. '
                    'The endpoint is idempotent — calling connect when already connected '
                    'to the same host returns success.',
            'operationId': 'connect',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {r'$ref': '#/components/schemas/ConnectRequest'},
                },
              },
            },
            'responses': {
              '200': {
                'description': 'Connection successful or already connected',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ApiResponse'},
                  },
                },
              },
              '400': {
                'description': 'Invalid request or already connected to a different host',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '401': {
                'description': 'Missing or invalid Authorization header',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '403': {
                'description': 'Invalid authentication token',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '500': {
                'description': 'Internal server error',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
            },
          },
        },
        '/disconnect': {
          'post': {
            'tags': ['VPN Control'],
            'summary': 'Disconnect from VPN',
            'description':
                'Disconnects from the VPN. '
                    'The endpoint is idempotent — calling disconnect when already disconnected returns success.',
            'operationId': 'disconnect',
            'responses': {
              '200': {
                'description': 'Disconnection successful or already disconnected',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ApiResponse'},
                  },
                },
              },
              '401': {
                'description': 'Missing or invalid Authorization header',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '403': {
                'description': 'Invalid authentication token',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '500': {
                'description': 'Internal server error',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
            },
          },
        },
        '/status': {
          'get': {
            'tags': ['VPN Control'],
            'summary': 'Get VPN connection status',
            'description': 'Returns the current VPN connection status.',
            'operationId': 'getStatus',
            'responses': {
              '200': {
                'description': 'Current connection status',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/StatusResponse'},
                  },
                },
              },
              '401': {
                'description': 'Missing or invalid Authorization header',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '403': {
                'description': 'Invalid authentication token',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
              '500': {
                'description': 'Internal server error',
                'content': {
                  'application/json': {
                    'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
                  },
                },
              },
            },
          },
        },
        '/swagger': {
          'get': {
            'tags': ['Documentation'],
            'summary': 'Swagger UI',
            'description':
                'Serves the Swagger UI page with interactive API documentation.',
            'operationId': 'swagger',
            'security': <Map<String, dynamic>>[],
            'responses': {
              '200': {
                'description': 'Swagger UI HTML page',
                'content': {
                  'text/html': {
                    'schema': {
                      'type': 'string',
                    },
                  },
                },
              },
            },
          },
        },
      },
      'components': {
        'schemas': {
          'ConnectRequest': {
            'type': 'object',
            'required': ['host', 'port'],
            'properties': {
              'host': {
                'type': 'string',
                'description': 'Proxy server hostname or IP address',
                'example': '192.168.1.100',
              },
              'port': {
                'type': 'integer',
                'description': 'Proxy server port (1-65535)',
                'minimum': 1,
                'maximum': 65535,
                'example': 9852,
              },
              'username': {
                'type': 'string',
                'description': 'SOCKS5 authentication username',
                'nullable': true,
              },
              'password': {
                'type': 'string',
                'description': 'SOCKS5 authentication password',
                'nullable': true,
              },
            },
          },
          'ApiResponse': {
            'type': 'object',
            'required': ['success', 'message'],
            'properties': {
              'success': {
                'type': 'boolean',
                'description': 'Whether the operation succeeded',
                'example': true,
              },
              'message': {
                'type': 'string',
                'description': 'Human-readable result message',
                'example': 'Connected',
              },
            },
          },
          'ErrorResponse': {
            'type': 'object',
            'required': ['success', 'message'],
            'properties': {
              'success': {
                'type': 'boolean',
                'description': 'Always false for errors',
                'example': false,
              },
              'message': {
                'type': 'string',
                'description': 'Error description',
                'example': 'Invalid request: Missing or invalid "host" field',
              },
            },
          },
          'StatusResponse': {
            'type': 'object',
            'required': ['connected', 'state'],
            'properties': {
              'connected': {
                'type': 'boolean',
                'description': 'Whether the VPN is currently connected',
                'example': false,
              },
              'state': {
                'type': 'string',
                'description': 'Current connection state',
                'enum': [
                  'disconnected',
                  'connecting',
                  'connected',
                  'disconnecting',
                  'error',
                ],
                'example': 'disconnected',
              },
              'host': {
                'type': 'string',
                'description':
                    'Connected proxy host (present only when connected)',
                'nullable': true,
                'example': '192.168.1.100',
              },
              'port': {
                'type': 'integer',
                'description':
                    'Connected proxy port (present only when connected)',
                'nullable': true,
                'example': 9852,
              },
            },
          },
          'HealthResponse': {
            'type': 'object',
            'required': ['status', 'service'],
            'properties': {
              'status': {
                'type': 'string',
                'description': 'Health status',
                'example': 'ok',
              },
              'service': {
                'type': 'string',
                'description': 'Service name',
                'example': 'fluxzy-vpn-control',
              },
            },
          },
        },
        'securitySchemes': {
          'bearerAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'description':
                'Optional Bearer token authentication. When the server is started with an auth token, '
                    'all endpoints except /health, /, and /swagger require a valid Bearer token.',
          },
        },
      },
      'security': [
        {'bearerAuth': <String>[]},
      ],
    };
  }

  /// Builds a self-contained HTML page that renders Swagger UI
  /// with the OpenAPI spec embedded inline.
  static String buildSwaggerHtml() {
    final specJson = jsonEncode(buildOpenApiSpec());

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Fluxzy Connect - API Documentation</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
  <style>
    .swagger-ui .topbar { display: none; }
    body { margin: 0; padding: 0; }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({
      spec: $specJson,
      dom_id: '#swagger-ui',
      deepLinking: true,
      presets: [
        SwaggerUIBundle.presets.apis,
        SwaggerUIBundle.SwaggerUIStandalonePreset
      ],
      layout: "BaseLayout"
    });
  </script>
</body>
</html>''';
  }
}
