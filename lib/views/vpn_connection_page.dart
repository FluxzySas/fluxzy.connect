import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';
import '../widgets/autodiscover_section.dart';
import '../widgets/manual_config_section.dart';
import '../widgets/connection_controls.dart';
import '../widgets/certificate_card.dart';
import '../widgets/tunnel_test_card.dart';
import '../widgets/app_filter_card.dart';
import 'settings_page.dart';

class VpnConnectionPage extends ConsumerWidget {
  const VpnConnectionPage({super.key});

  Future<void> _showAboutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final packageInfo = await PackageInfo.fromPlatform();
    final version = 'v${packageInfo.version} (${packageInfo.buildNumber})';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('About Fluxzy Connect'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  version,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Route your Android device\'s HTTP/HTTPS traffic through a Fluxzy instance for debugging, inspection, and analysis — all from the comfort of your phone.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Whether you\'re testing APIs, troubleshooting network issues, or just curious about what your apps are sending over the wire, Fluxzy Connect bridges your mobile device to your Fluxzy Desktop or CLI setup via a secure VPN tunnel.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Beyond Fluxzy, the app also works as a standalone SOCKS5 VPN client — connect to any SOCKS5 proxy server to route your device\'s traffic however you need.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Completely free. No subscriptions, no premium tiers, no hidden limits. Just connect and go.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              _buildLinkTile(
                context,
                icon: Icons.menu_book_outlined,
                label: 'Learn more & get started',
                url: 'https://www.fluxzy.io/hello-fluxzy-connect',
              ),
              _buildLinkTile(
                context,
                icon: Icons.code,
                label: 'Fluxzy is open source',
                url: 'https://github.com/haga-rak/fluxzy.core',
              ),
              _buildLinkTile(
                context,
                icon: Icons.bug_report_outlined,
                label: 'Report a bug or suggestion',
                url: 'https://github.com/haga-rak/fluxzy.core/issues',
              ),
              const SizedBox(height: 8),
              Text(
                'Contact: project@fluxzy.io',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/icon.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 10),
            const Text(
              'FLUXZY CONNECT',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      drawer: NavigationDrawer(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/icon/icon.png',
                  height: 40,
                  width: 40,
                ),
                const SizedBox(width: 12),
                const Text(
                  'FLUXZY CONNECT',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          NavigationDrawerDestination(
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Settings'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.info_outline),
            label: const Text('About Fluxzy Connect'),
          ),
        ],
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          if (index == 0) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          } else if (index == 1) {
            _showAboutDialog(context);
          }
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildModeSelector(context, state, viewModel),
                  const SizedBox(height: 24),
                  if (state.errorMessage != null) ...[
                    _buildErrorBanner(context, state, viewModel),
                    const SizedBox(height: 16),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: state.isAutodiscoverMode
                        ? const AutodiscoverSection(
                            key: ValueKey('autodiscover'),
                          )
                        : const ManualConfigSection(key: ValueKey('manual')),
                  ),
                  // Per-app VPN filter card
                  const SizedBox(height: 16),
                  const AppFilterCard(),
                  // Show certificate and tunnel test cards when connected
                  if (state.connectionState == VpnConnectionState2.connected) ...[
                    const SizedBox(height: 24),
                    const CertificateCard(),
                    const SizedBox(height: 16),
                    const TunnelTestCard(),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          const ConnectionControls(),
        ],
      ),
    );
  }

  Widget _buildModeSelector(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    final isConnected = state.connectionState == VpnConnectionState2.connected;
    final isConnecting =
        state.connectionState == VpnConnectionState2.connecting;
    final isDisabled = isConnected || isConnecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: true,
            label: Text('Discover', softWrap: false),
            icon: Icon(Icons.wifi_find),
          ),
          ButtonSegment<bool>(
            value: false,
            label: Text('Direct', softWrap: false),
            icon: Icon(Icons.link),
          ),
        ],
        selected: {state.isAutodiscoverMode},
        showSelectedIcon: false,
        onSelectionChanged: isDisabled
            ? null
            : (Set<bool> selected) {
                viewModel.setAutodiscoverMode(selected.first);
              },
        style: ButtonStyle(visualDensity: VisualDensity.comfortable),
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onErrorContainer),
            onPressed: viewModel.clearError,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
