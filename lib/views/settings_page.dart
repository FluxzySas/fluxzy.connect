import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/web_server_settings.dart';
import '../services/secure_certificate_service.dart';
import '../services/vpn_control_server.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';

/// State for the settings form
class SettingsFormState {
  final bool autoStart;
  final int port;
  final bool httpsEnabled;
  final bool authEnabled;
  final String? authToken;
  final bool isLoading;
  final bool isSaving;
  final bool isRegeneratingToken;
  final String? errorMessage;
  final bool hasChanges;

  const SettingsFormState({
    this.autoStart = true,
    this.port = WebServerSettings.defaultPort,
    this.httpsEnabled = false,
    this.authEnabled = false,
    this.authToken,
    this.isLoading = true,
    this.isSaving = false,
    this.isRegeneratingToken = false,
    this.errorMessage,
    this.hasChanges = false,
  });

  SettingsFormState copyWith({
    bool? autoStart,
    int? port,
    bool? httpsEnabled,
    bool? authEnabled,
    String? authToken,
    bool clearAuthToken = false,
    bool? isLoading,
    bool? isSaving,
    bool? isRegeneratingToken,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? hasChanges,
  }) {
    final newHttpsEnabled = httpsEnabled ?? this.httpsEnabled;
    // If HTTPS is being disabled, also disable auth
    final newAuthEnabled = newHttpsEnabled ? (authEnabled ?? this.authEnabled) : false;

    return SettingsFormState(
      autoStart: autoStart ?? this.autoStart,
      port: port ?? this.port,
      httpsEnabled: newHttpsEnabled,
      authEnabled: newAuthEnabled,
      authToken: clearAuthToken ? null : (authToken ?? this.authToken),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isRegeneratingToken: isRegeneratingToken ?? this.isRegeneratingToken,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }

  bool get isValidPort => WebServerSettings.isValidPort(port);
}

/// ViewModel for settings page
class SettingsViewModel extends StateNotifier<SettingsFormState> {
  final Ref _ref;
  WebServerSettings? _originalSettings;
  String? _originalAuthToken;

  SettingsViewModel(this._ref) : super(const SettingsFormState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final service = _ref.read(webServerSettingsServiceProvider);
      final settings = await service.load();
      final authToken = await service.getAuthToken();
      _originalSettings = settings;
      _originalAuthToken = authToken;
      state = state.copyWith(
        autoStart: settings.autoStart,
        port: settings.port,
        httpsEnabled: settings.httpsEnabled,
        authEnabled: settings.authEnabled,
        authToken: authToken,
        isLoading: false,
        hasChanges: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load settings: $e',
      );
    }
  }

  void setAutoStart(bool value) {
    state = state.copyWith(autoStart: value);
    _updateHasChanges();
  }

  void setPort(int value) {
    state = state.copyWith(port: value);
    _updateHasChanges();
  }

  void setHttpsEnabled(bool value) {
    state = state.copyWith(httpsEnabled: value);
    _updateHasChanges();
  }

  Future<void> setAuthEnabled(bool value) async {
    if (value && !state.httpsEnabled) {
      state = state.copyWith(
        errorMessage: 'HTTPS must be enabled before enabling authentication',
      );
      return;
    }

    // If enabling auth for the first time, generate a token
    if (value && state.authToken == null) {
      final service = _ref.read(webServerSettingsServiceProvider);
      final token = await service.generateNewAuthToken();
      state = state.copyWith(authEnabled: true, authToken: token);
    } else {
      state = state.copyWith(authEnabled: value);
    }
    _updateHasChanges();
  }

  Future<void> regenerateToken() async {
    state = state.copyWith(isRegeneratingToken: true);
    try {
      final service = _ref.read(webServerSettingsServiceProvider);
      final token = await service.generateNewAuthToken();
      state = state.copyWith(
        authToken: token,
        isRegeneratingToken: false,
      );
      _updateHasChanges();
    } catch (e) {
      state = state.copyWith(
        isRegeneratingToken: false,
        errorMessage: 'Failed to regenerate token: $e',
      );
    }
  }

  void setAuthToken(String value) {
    state = state.copyWith(authToken: value);
    _updateHasChanges();
  }

  Future<void> regenerateCertificate() async {
    try {
      final certService = SecureCertificateService();
      await certService.regenerateCertificate();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to regenerate certificate: $e',
      );
    }
  }

  void _updateHasChanges() {
    if (_originalSettings == null) return;
    final hasChanges = state.autoStart != _originalSettings!.autoStart ||
        state.port != _originalSettings!.port ||
        state.httpsEnabled != _originalSettings!.httpsEnabled ||
        state.authEnabled != _originalSettings!.authEnabled ||
        state.authToken != _originalAuthToken;
    state = state.copyWith(hasChanges: hasChanges);
  }

  Future<bool> save() async {
    if (!state.isValidPort) {
      state = state.copyWith(
        errorMessage: 'Port must be between 1 and 65535',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);
    try {
      final service = _ref.read(webServerSettingsServiceProvider);
      final newSettings = WebServerSettings(
        autoStart: state.autoStart,
        port: state.port,
        httpsEnabled: state.httpsEnabled,
        authEnabled: state.authEnabled,
      );
      await service.save(newSettings);

      // Save auth token if it changed
      if (state.authToken != null && state.authToken != _originalAuthToken) {
        await service.setAuthToken(state.authToken!);
      }

      _originalSettings = newSettings;
      _originalAuthToken = state.authToken;
      state = state.copyWith(
        isSaving: false,
        hasChanges: false,
      );
      // Invalidate the settings provider to trigger refresh
      _ref.invalidate(webServerSettingsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save settings: $e',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}

/// Provider for settings viewmodel
final settingsViewModelProvider =
    StateNotifierProvider.autoDispose<SettingsViewModel, SettingsFormState>(
        (ref) {
  return SettingsViewModel(ref);
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _portController;
  late TextEditingController _tokenController;
  bool _isTokenVisible = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    // Update port controller when state changes (but not during editing)
    if (!_portController.text.contains(state.port.toString()) ||
        _portController.text.isEmpty) {
      final newText = state.port.toString();
      if (_portController.text != newText && !state.isLoading) {
        _portController.text = newText;
        _portController.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
      }
    }

    // Update token controller when state changes
    if (state.authToken != null && _tokenController.text != state.authToken) {
      _tokenController.text = state.authToken!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null) ...[
                    _buildErrorBanner(context, state, viewModel),
                    const SizedBox(height: 16),
                  ],
                  _buildWebServerSection(context, state, viewModel),
                  const SizedBox(height: 24),
                  _buildSaveButton(context, state, viewModel),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    SettingsFormState state,
    SettingsViewModel viewModel,
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

  Widget _buildWebServerSection(
    BuildContext context,
    SettingsFormState state,
    SettingsViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Management Web Server',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'View available routes',
                  onPressed: () => _showRoutesDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure the embedded web server that allows remote control of the VPN connection.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // Security warning (dynamic based on enabled protections)
            _buildSecurityWarning(context, state),
            const SizedBox(height: 20),
            // Auto-start switch
            SwitchListTile(
              title: const Text('Auto-start'),
              subtitle: const Text(
                'Start the web server automatically when the app launches',
              ),
              value: state.autoStart,
              onChanged: viewModel.setAutoStart,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Port field
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Port',
                helperText: 'Default: ${WebServerSettings.defaultPort}',
                errorText: !state.isValidPort ? 'Port must be 1-65535' : null,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (value) {
                final port = int.tryParse(value);
                if (port != null) {
                  viewModel.setPort(port);
                }
              },
            ),
            const SizedBox(height: 16),
            // Security section
            _buildSecuritySection(context, state, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(
    BuildContext context,
    SettingsFormState state,
    SettingsViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.security,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Security',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // HTTPS toggle
        SwitchListTile(
          title: const Text('Enable HTTPS'),
          subtitle: const Text(
            'Encrypt traffic with a self-signed certificate',
          ),
          value: state.httpsEnabled,
          onChanged: viewModel.setHttpsEnabled,
          contentPadding: EdgeInsets.zero,
        ),
        // Regenerate certificate button (when HTTPS is enabled)
        if (state.httpsEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: TextButton.icon(
              onPressed: () => _confirmRegenerateCertificate(context, viewModel),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Regenerate Certificate'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        // Authentication toggle (only enabled when HTTPS is on)
        SwitchListTile(
          title: const Text('Enable Authentication'),
          subtitle: Text(
            state.httpsEnabled
                ? 'Require a bearer token for API access'
                : 'Requires HTTPS to be enabled first',
          ),
          value: state.authEnabled,
          onChanged: state.httpsEnabled
              ? (value) => viewModel.setAuthEnabled(value)
              : null,
          contentPadding: EdgeInsets.zero,
        ),
        // Auth token display (when auth is enabled)
        if (state.authEnabled && state.authToken != null)
          _buildAuthTokenSection(context, state, viewModel),
      ],
    );
  }

  Future<void> _confirmRegenerateCertificate(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Certificate?'),
        content: const Text(
          'This will create a new HTTPS certificate. Clients will need to accept the new certificate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.regenerateCertificate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate regenerated. Restart the server to apply changes.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildAuthTokenSection(
    BuildContext context,
    SettingsFormState state,
    SettingsViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final token = state.authToken!;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.key,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Authentication Token',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            obscureText: !_isTokenVisible,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isTokenVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    tooltip: _isTokenVisible ? 'Hide token' : 'Show token',
                    onPressed: () {
                      setState(() {
                        _isTokenVisible = !_isTokenVisible;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy token',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Token copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: state.isRegeneratingToken
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Regenerate token',
                    onPressed: state.isRegeneratingToken
                        ? null
                        : () => _confirmRegenerateToken(context, viewModel),
                  ),
                ],
              ),
            ),
            onChanged: (value) {
              viewModel.setAuthToken(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Use this token in the Authorization header: Bearer <token>',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showRoutesDialog(BuildContext context) {
    final theme = Theme.of(context);
    final routes = VpnControlServer.availableRoutes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.route,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Available Routes'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: routes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final route = routes[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMethodColor(route.method, theme),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        route.method,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.path,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            route.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!route.requiresAuth)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_open,
                                    size: 12,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'No authentication required',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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

  Color _getMethodColor(String method, ThemeData theme) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green.shade600;
      case 'POST':
        return Colors.blue.shade600;
      case 'PUT':
        return Colors.orange.shade600;
      case 'DELETE':
        return Colors.red.shade600;
      case 'PATCH':
        return Colors.purple.shade600;
      default:
        return theme.colorScheme.primary;
    }
  }

  Future<void> _confirmRegenerateToken(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Token?'),
        content: const Text(
          'This will invalidate the current token. Any devices using the old token will need to be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.regenerateToken();
    }
  }

  Widget _buildSaveButton(
    BuildContext context,
    SettingsFormState state,
    SettingsViewModel viewModel,
  ) {
    return FilledButton.icon(
      onPressed: state.hasChanges && !state.isSaving && state.isValidPort
          ? () async {
              final success = await viewModel.save();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings saved'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : null,
      icon: state.isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save),
      label: Text(state.isSaving ? 'Saving...' : 'Save'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Widget _buildSecurityWarning(BuildContext context, SettingsFormState state) {
    final theme = Theme.of(context);

    // Determine security status based on enabled protections
    final isSecured = state.httpsEnabled && state.authEnabled;
    final isPartiallySecured = state.httpsEnabled && !state.authEnabled;

    // Choose colors based on security level
    final Color containerColor;
    final Color borderColor;
    final Color iconColor;
    final Color titleColor;
    final IconData headerIcon;
    final String headerTitle;

    if (isSecured) {
      containerColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
      borderColor = theme.colorScheme.primary.withValues(alpha: 0.5);
      iconColor = theme.colorScheme.primary;
      titleColor = theme.colorScheme.primary;
      headerIcon = Icons.verified_user;
      headerTitle = 'Secured';
    } else if (isPartiallySecured) {
      containerColor = theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3);
      borderColor = theme.colorScheme.tertiary.withValues(alpha: 0.5);
      iconColor = theme.colorScheme.tertiary;
      titleColor = theme.colorScheme.tertiary;
      headerIcon = Icons.shield_outlined;
      headerTitle = 'Partially Secured';
    } else {
      containerColor = theme.colorScheme.errorContainer.withValues(alpha: 0.3);
      borderColor = theme.colorScheme.error.withValues(alpha: 0.5);
      iconColor = theme.colorScheme.error;
      titleColor = theme.colorScheme.error;
      headerIcon = Icons.warning_amber_rounded;
      headerTitle = 'Security Considerations';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSecured) ...[
            Text(
              'The web server is protected with HTTPS encryption and bearer token authentication.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildSecurityStatusItem(
              context,
              Icons.lock,
              'HTTPS Enabled',
              'Traffic is encrypted with TLS',
              isPositive: true,
            ),
            _buildSecurityStatusItem(
              context,
              Icons.key,
              'Authentication Enabled',
              'API access requires a bearer token',
              isPositive: true,
            ),
          ] else if (isPartiallySecured) ...[
            Text(
              'The web server has HTTPS enabled but no authentication.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildSecurityStatusItem(
              context,
              Icons.lock,
              'HTTPS Enabled',
              'Traffic is encrypted with TLS',
              isPositive: true,
            ),
            _buildSecurityStatusItem(
              context,
              Icons.lock_open,
              'No Authentication',
              'Anyone on your network can access the API',
              isPositive: false,
            ),
          ] else ...[
            Text(
              'Enabling this web server exposes remote control capabilities on your local network.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildWarningItem(
              context,
              Icons.wifi,
              'Network Exposure',
              'Any device on your Wi-Fi network can access and control the VPN connection.',
            ),
            _buildWarningItem(
              context,
              Icons.lock_open,
              'No Authentication',
              'The web server does not require a password. Anyone with network access can use it.',
            ),
            _buildWarningItem(
              context,
              Icons.public,
              'Public Networks',
              'Never enable on public Wi-Fi (cafes, airports, hotels). Only use on trusted home/office networks.',
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Intended for development use only, allowing Fluxzy Desktop '
                    'to control this device\'s VPN connection for traffic inspection.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusItem(
    BuildContext context,
    IconData icon,
    String title,
    String description, {
    required bool isPositive,
  }) {
    final theme = Theme.of(context);
    final color = isPositive ? theme.colorScheme.primary : theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
