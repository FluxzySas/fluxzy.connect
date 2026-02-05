import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme.dart';
import 'theme/util.dart';
import 'views/vpn_connection_page.dart';
import 'viewmodels/vpn_connection_viewmodel.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FluxzyApp(),
    ),
  );
}

/// Widget that initializes the VPN control server on app start based on settings.
class VpnControlServerInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const VpnControlServerInitializer({super.key, required this.child});

  @override
  ConsumerState<VpnControlServerInitializer> createState() =>
      _VpnControlServerInitializerState();
}

class _VpnControlServerInitializerState
    extends ConsumerState<VpnControlServerInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeServer();
  }

  Future<void> _initializeServer() async {
    final settingsService = ref.read(webServerSettingsServiceProvider);
    final settings = await settingsService.load();

    if (!settings.autoStart) {
      debugPrint('[Main] Web server auto-start is disabled');
      return;
    }

    // Get auth token if auth is enabled
    String? authToken;
    if (settings.authEnabled) {
      authToken = await settingsService.getAuthToken();
    }

    final server = ref.read(vpnControlServerProvider);
    try {
      await server.start(
        port: settings.port,
        https: settings.httpsEnabled,
        authToken: authToken,
      );
    } catch (e) {
      debugPrint('[Main] Failed to start VPN control server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class FluxzyApp extends StatelessWidget {
  const FluxzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluxzy Connect',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Rebuild themes with proper text theme once context is available
        final textTheme = createTextTheme(context, "Roboto", "Roboto");
        final materialTheme = MaterialTheme(textTheme);

        return Theme(
          data: Theme.of(context).brightness == Brightness.dark
              ? materialTheme.dark().copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                )
              : materialTheme.light().copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
          child: child!,
        );
      },
      home: const VpnControlServerInitializer(
        child: VpnConnectionPage(),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme = MaterialTheme.lightScheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = MaterialTheme.darkScheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(),
      ),
    );
  }
}
