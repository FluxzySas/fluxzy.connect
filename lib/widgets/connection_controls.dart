import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';

/// Provider that fetches device IP addresses
final deviceIpAddressesProvider = FutureProvider<List<String>>((ref) async {
  final addresses = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        addresses.add('${interface.name}: ${addr.address}');
      }
    }
  } catch (e) {
    // Ignore errors, return empty list
  }
  return addresses;
});

class ConnectionControls extends ConsumerWidget {
  const ConnectionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);
    final ipAddresses = ref.watch(deviceIpAddressesProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIpAddresses(context, ipAddresses, ref),
            const SizedBox(height: 8),
            _buildStatusIndicator(context, state),
            const SizedBox(height: 16),
            _buildButtons(context, state, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildIpAddresses(
    BuildContext context,
    AsyncValue<List<String>> ipAddresses,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    return ipAddresses.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          return Text(
            'No network',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return InkWell(
          onTap: () => ref.invalidate(deviceIpAddressesProvider),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lan_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    addresses.join('  •  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      error: (_, __) => Text(
        'Unable to get IP',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, VpnConnectionState state) {
    final theme = Theme.of(context);
    final (label, color) = _getStatusInfo(state.connectionState, theme);
    final isLoading = state.connectionState == VpnConnectionState2.connecting ||
        state.connectionState == VpnConnectionState2.disconnecting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Status:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        if (isLoading)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  (String, Color) _getStatusInfo(
    VpnConnectionState2 connectionState,
    ThemeData theme,
  ) {
    switch (connectionState) {
      case VpnConnectionState2.disconnected:
        return ('Disconnected', theme.colorScheme.onSurfaceVariant);
      case VpnConnectionState2.connecting:
        return ('Connecting...', theme.colorScheme.primary);
      case VpnConnectionState2.connected:
        return ('Connected', Colors.green);
      case VpnConnectionState2.disconnecting:
        return ('Disconnecting...', theme.colorScheme.tertiary);
      case VpnConnectionState2.error:
        return ('Error', theme.colorScheme.error);
    }
  }

  Widget _buildButtons(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 360;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _buildConnectButton(context, state, viewModel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDisconnectButton(context, state, viewModel),
              ),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: _buildConnectButton(context, state, viewModel),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _buildDisconnectButton(context, state, viewModel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectButton(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    final isConnecting = state.connectionState == VpnConnectionState2.connecting;

    return FilledButton.icon(
      onPressed: state.canConnect ? () => viewModel.connect() : null,
      icon: isConnecting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.power_settings_new),
      label: Text(isConnecting ? 'Connecting...' : 'Connect'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
      ),
    );
  }

  Widget _buildDisconnectButton(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    final isDisconnecting =
        state.connectionState == VpnConnectionState2.disconnecting;

    return OutlinedButton.icon(
      onPressed: state.canDisconnect ? () => viewModel.disconnect() : null,
      icon: isDisconnecting
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.error,
              ),
            )
          : Icon(
              Icons.stop_circle_outlined,
              color: state.canDisconnect
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
      label: Text(isDisconnecting ? 'Disconnecting...' : 'Disconnect'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: Theme.of(context).colorScheme.error,
        side: BorderSide(
          color: state.canDisconnect
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
