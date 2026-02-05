import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';

class ManualConfigSection extends ConsumerStatefulWidget {
  const ManualConfigSection({super.key});

  @override
  ConsumerState<ManualConfigSection> createState() => _ManualConfigSectionState();
}

class _ManualConfigSectionState extends ConsumerState<ManualConfigSection> {
  late TextEditingController _hostnameController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  String? _lastHostname;
  int? _lastPort;

  @override
  void initState() {
    super.initState();
    final state = ref.read(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);

    _lastHostname = state.manualHostname;
    _lastPort = state.manualPort;

    _hostnameController = TextEditingController(text: state.manualHostname);

    // Default port to 44344 if no saved port
    final defaultPort = state.manualPort?.toString() ?? '44344';
    _portController = TextEditingController(text: defaultPort);

    // Sync default port with viewmodel if not already set
    // Delay to avoid modifying provider during widget tree build
    if (state.manualPort == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        viewModel.setManualPort(defaultPort);
      });
    }

    _usernameController = TextEditingController(text: state.username);
    _passwordController = TextEditingController(text: state.password);
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _syncControllersWithState(VpnConnectionState state) {
    // Update hostname controller if state changed externally
    if (state.manualHostname != _lastHostname) {
      _lastHostname = state.manualHostname;
      if (_hostnameController.text != state.manualHostname) {
        _hostnameController.text = state.manualHostname;
      }
    }

    // Update port controller if state changed externally
    if (state.manualPort != _lastPort) {
      _lastPort = state.manualPort;
      final portText = state.manualPort?.toString() ?? '';
      if (_portController.text != portText) {
        _portController.text = portText;
      }
    }
  }

  String? _validateHostname(String? value) {
    if (value == null || value.isEmpty) {
      return 'Hostname is required';
    }

    final ipRegex = RegExp(
      r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$',
    );
    final hostnameRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$',
    );

    if (!ipRegex.hasMatch(value) && !hostnameRegex.hasMatch(value)) {
      return 'Invalid hostname or IP address';
    }

    return null;
  }

  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Port is required';
    }

    final port = int.tryParse(value);
    if (port == null) {
      return 'Invalid port number';
    }

    if (port < 1 || port > 65535) {
      return 'Port must be 1-65535';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);
    final theme = Theme.of(context);

    // Sync text controllers when state changes externally (e.g., from autodiscover)
    _syncControllersWithState(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.link,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Direct Connection',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildConnectionFields(context, viewModel),
        const SizedBox(height: 20),
        _buildAuthenticationSection(context, state, viewModel),
      ],
    );
  }

  Widget _buildConnectionFields(
    BuildContext context,
    VpnConnectionViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 400;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildHostnameField(viewModel),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildPortField(viewModel),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildHostnameField(viewModel),
            const SizedBox(height: 12),
            _buildPortField(viewModel),
          ],
        );
      },
    );
  }

  Widget _buildHostnameField(VpnConnectionViewModel viewModel) {
    return TextFormField(
      controller: _hostnameController,
      decoration: const InputDecoration(
        labelText: 'Hostname / IP Address',
        hintText: 'proxy.example.com',
        prefixIcon: Icon(Icons.dns_outlined),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validateHostname,
      onChanged: viewModel.setManualHostname,
    );
  }

  Widget _buildPortField(VpnConnectionViewModel viewModel) {
    return TextFormField(
      controller: _portController,
      decoration: const InputDecoration(
        labelText: 'Port',
        hintText: '44344',
        prefixIcon: Icon(Icons.numbers),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validatePort,
      onChanged: viewModel.setManualPort,
    );
  }

  Widget _buildAuthenticationSection(
    BuildContext context,
    VpnConnectionState state,
    VpnConnectionViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Authentication',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Switch(
                value: state.useAuthentication,
                onChanged: viewModel.setUseAuthentication,
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildAuthFields(viewModel, state.useAuthentication),
            ),
            crossFadeState: state.useAuthentication
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthFields(VpnConnectionViewModel viewModel, bool enabled) {
    return Column(
      children: [
        TextFormField(
          controller: _usernameController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          onChanged: viewModel.setUsername,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          enabled: enabled,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.key_outlined),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onChanged: viewModel.setPassword,
        ),
      ],
    );
  }
}
