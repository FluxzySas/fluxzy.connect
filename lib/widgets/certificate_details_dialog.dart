import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/certificate_info.dart';
import '../services/certificate_native_bridge.dart';

/// Dialog displaying detailed certificate information.
class CertificateDetailsDialog extends StatelessWidget {
  final CertificateInfo certificate;

  const CertificateDetailsDialog({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Certificate Details',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Common Name',
                value: certificate.commonName,
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Issuer',
                value: certificate.issuer,
              ),
              _DetailRow(
                icon: Icons.tag,
                label: 'Serial Number',
                value: certificate.serialNumber,
              ),
              _DetailRow(
                icon: Icons.key_outlined,
                label: 'Public Key',
                value: certificate.publicKeyInfo,
              ),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Valid From',
                value: dateFormat.format(certificate.validFromDate),
              ),
              _buildExpirationRow(context, dateFormat),
              const SizedBox(height: 16),
              _buildFingerprintSection(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _downloadCertificate(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildExpirationRow(BuildContext context, DateFormat dateFormat) {
    final theme = Theme.of(context);
    final isExpired = certificate.isExpired;
    final daysRemaining = certificate.daysUntilExpiration;

    String expirationText = dateFormat.format(certificate.expirationDate);
    if (isExpired) {
      expirationText += ' (Expired)';
    } else if (daysRemaining <= 30) {
      expirationText += ' ($daysRemaining days)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_outlined,
            size: 18,
            color: isExpired
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expires',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expirationText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isExpired ? theme.colorScheme.error : null,
                    fontWeight: isExpired ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.fingerprint,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'SHA-256 Fingerprint',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copyFingerprint(context),
              tooltip: 'Copy fingerprint',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            certificate.fingerprint,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  void _copyFingerprint(BuildContext context) {
    Clipboard.setData(ClipboardData(text: certificate.fingerprint));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fingerprint copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadCertificate(BuildContext context) async {
    if (!Platform.isAndroid) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download is only supported on Android'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final fileName = '${_sanitizeFileName(certificate.commonName)}.crt';
      final bridge = CertificateNativeBridge();
      final savedPath = await bridge.saveCertificateToDownloads(
        certPem: certificate.rawPem,
        fileName: fileName,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Certificate saved to $savedPath'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on CertificateNativeException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save certificate: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download certificate: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
