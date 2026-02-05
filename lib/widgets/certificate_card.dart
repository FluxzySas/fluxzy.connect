import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/certificate_info.dart';
import '../viewmodels/vpn_connection_viewmodel.dart';
import 'certificate_details_dialog.dart';

/// Card displaying certificate summary with actions.
class CertificateCard extends ConsumerWidget {
  const CertificateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnConnectionViewModelProvider);
    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);

    // Don't show if not connected
    if (state.connectionState != VpnConnectionState2.connected) {
      return const SizedBox.shrink();
    }

    // Show loading state
    if (state.isCertificateLoading) {
      return _buildLoadingCard(context);
    }

    // Show error state
    if (state.certificateError != null) {
      return _buildErrorCard(context, state.certificateError!, viewModel);
    }

    // Show certificate info
    if (state.certificateInfo != null) {
      return _buildCertificateCard(
        context,
        ref,
        state.certificateInfo!,
        state.certificateTrustStatus,
        state.isInstallingCertificate,
      );
    }

    // No certificate available
    return const SizedBox.shrink();
  }

  Widget _buildLoadingCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading certificate...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    String error,
    VpnConnectionViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Certificate Error',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: viewModel.fetchCertificate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(
    BuildContext context,
    WidgetRef ref,
    CertificateInfo cert,
    CertificateTrustStatus trustStatus,
    bool isInstalling,
  ) {
    final theme = Theme.of(context);
    final isTrusted = trustStatus == CertificateTrustStatus.trusted;

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
          // Header row
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showCertificateScopeInfo(context),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'User space CA certificate',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.help_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              _buildTrustStatusChip(context, trustStatus),
            ],
          ),
          const SizedBox(height: 12),

          // Certificate CN
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cert.commonName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Expiration warning if applicable
          if (cert.isExpired || cert.daysUntilExpiration <= 30) ...[
            const SizedBox(height: 8),
            _buildExpirationWarning(context, cert),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDetails(context, cert),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isTrusted || isInstalling
                      ? null
                      : () => _installCertificate(context, ref, trustStatus),
                  icon: isInstalling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isTrusted
                              ? Icons.check_circle
                              : Icons.verified_outlined,
                          size: 18,
                        ),
                  label: Text(isTrusted ? 'Trusted' : 'Trust'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustStatusChip(
    BuildContext context,
    CertificateTrustStatus status,
  ) {
    final theme = Theme.of(context);

    final (label, icon, bgColor, fgColor) = switch (status) {
      CertificateTrustStatus.trusted => (
          'Trusted',
          Icons.check_circle,
          Colors.green.withValues(alpha: 0.15),
          Colors.green,
        ),
      CertificateTrustStatus.notTrusted => (
          'Not Trusted',
          Icons.cancel_outlined,
          theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          theme.colorScheme.error,
        ),
      CertificateTrustStatus.checking => (
          'Checking...',
          Icons.sync,
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
      CertificateTrustStatus.error => (
          'Error',
          Icons.warning_amber,
          theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          theme.colorScheme.error,
        ),
      CertificateTrustStatus.unknown => (
          'Unknown',
          Icons.help_outline,
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status == CertificateTrustStatus.checking
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
                )
              : Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: fgColor),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationWarning(BuildContext context, CertificateInfo cert) {
    final theme = Theme.of(context);
    final isExpired = cert.isExpired;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
            : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.error : Icons.warning_amber,
            size: 14,
            color: isExpired
                ? theme.colorScheme.error
                : theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
          Text(
            isExpired
                ? 'Certificate has expired'
                : 'Expires in ${cert.daysUntilExpiration} days',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isExpired
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, CertificateInfo cert) {
    showDialog(
      context: context,
      builder: (context) => CertificateDetailsDialog(certificate: cert),
    );
  }

  void _showCertificateScopeInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Expanded(child: Text('User space certificate')),
          ],
        ),
        content: const Text(
          'This certificate is installed in the user certificate store and '
          'only applies to browsers and applications that explicitly opt-in '
          'to trust user-installed certificates.\n\n'
          'Most browsers (Chrome, Firefox, Edge) and some apps will trust '
          'this certificate, but system apps and apps with certificate '
          'pinning will not.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Shows a comprehensive warning dialog about certificate installation risks.
  /// Returns true if user confirms they understand and want to proceed.
  Future<bool> _showCertificateRiskWarning(BuildContext context) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: theme.colorScheme.error,
        ),
        title: const Text('Security Warning'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Installing a CA certificate grants it the ability to intercept '
                  'and decrypt your encrypted (HTTPS) traffic.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Risks section
              Text(
                'Potential Risks:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              _buildRiskItem(
                context,
                Icons.visibility,
                'Traffic Interception',
                'All HTTPS traffic can be read in plain text by whoever controls the proxy.',
              ),
              _buildRiskItem(
                context,
                Icons.security,
                'Sensitive Data Exposure',
                'Passwords, banking details, and personal information could be captured.',
              ),
              _buildRiskItem(
                context,
                Icons.swap_horiz,
                'Man-in-the-Middle',
                'A malicious proxy could modify data in transit without your knowledge.',
              ),

              const SizedBox(height: 16),

              // Legitimate use cases
              Text(
                'Legitimate Use Cases:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              _buildLegitimateUseItem(
                context,
                Icons.bug_report,
                'Debugging your own apps or websites',
              ),
              _buildLegitimateUseItem(
                context,
                Icons.developer_mode,
                'Inspecting API traffic during development',
              ),
              _buildLegitimateUseItem(
                context,
                Icons.school,
                'Learning about network protocols and security',
              ),
              _buildLegitimateUseItem(
                context,
                Icons.shield,
                'Security testing on systems you own or have permission to test',
              ),

              const SizedBox(height: 16),

              // Final warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only proceed if you trust the proxy server and understand '
                        'why you need to intercept your own traffic. '
                        'Remove this certificate when no longer needed.',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('I Understand, Proceed'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceBetween,
      ),
    );

    return result ?? false;
  }

  Widget _buildRiskItem(
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
            size: 18,
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

  Widget _buildLegitimateUseItem(
    BuildContext context,
    IconData icon,
    String text,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _installCertificate(
    BuildContext context,
    WidgetRef ref,
    CertificateTrustStatus previousStatus,
  ) async {
    // Show risk warning dialog first
    final confirmed = await _showCertificateRiskWarning(context);
    if (!confirmed || !context.mounted) return;

    final viewModel = ref.read(vpnConnectionViewModelProvider.notifier);

    await viewModel.installCertificate();

    if (!context.mounted) return;

    final newStatus = ref.read(vpnConnectionViewModelProvider).certificateTrustStatus;

    // If certificate is now trusted, show success message
    if (newStatus == CertificateTrustStatus.trusted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificate installed successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    // If still not trusted after installation attempt, show guidance
    else if (previousStatus == CertificateTrustStatus.notTrusted &&
        newStatus == CertificateTrustStatus.notTrusted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Certificate must be installed manually.\n'
            'Go to Settings > Security > Encryption & credentials > Install a certificate > CA certificate',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }
}
