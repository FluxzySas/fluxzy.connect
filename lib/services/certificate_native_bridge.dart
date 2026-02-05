import 'dart:io';

import 'package:flutter/services.dart';

/// Bridge to native certificate trust management functionality.
///
/// This service wraps platform channel calls to check certificate trust status
/// and trigger certificate installation on Android.
class CertificateNativeBridge {
  // Uses the same channel as the VPN service
  static const MethodChannel _channel =
      MethodChannel('io.fluxzy.mobile.connect/vpn');

  /// Checks if a certificate with the given fingerprint is trusted.
  ///
  /// [fingerprint] The SHA-256 fingerprint of the certificate (colon-separated hex)
  /// Returns true if the certificate is trusted as a CA, false otherwise.
  /// Returns false on non-Android platforms.
  Future<bool> isCertificateTrusted(String fingerprint) async {
    if (!Platform.isAndroid) {
      // Not implemented for other platforms yet
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'checkCertificateTrust',
        {'fingerprint': fingerprint},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw CertificateNativeException(
        'Failed to check certificate trust: ${e.message}',
      );
    }
  }

  /// Requests installation of a CA certificate.
  ///
  /// [certPem] The PEM-encoded certificate string
  /// [certName] A friendly name for the certificate (optional, defaults to "Fluxzy CA")
  ///
  /// Returns true if the installation flow completed (user may have accepted or declined).
  /// The caller should re-check trust status after this returns to confirm installation.
  ///
  /// Throws [CertificateNativeException] if the installation could not be initiated.
  Future<bool> requestInstallCertificate({
    required String certPem,
    String? certName,
  }) async {
    if (!Platform.isAndroid) {
      throw CertificateNativeException(
        'Certificate installation is only supported on Android',
      );
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'installCertificate',
        {
          'certPem': certPem,
          'certName': certName ?? 'Fluxzy CA',
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw CertificateNativeException(
        'Failed to install certificate: ${e.message}',
      );
    }
  }

  /// Saves a certificate to the device's Downloads folder.
  ///
  /// [certPem] The PEM-encoded certificate string
  /// [fileName] The name for the saved file (e.g., "certificate.crt")
  ///
  /// Returns the path where the certificate was saved.
  /// Throws [CertificateNativeException] if saving fails.
  Future<String> saveCertificateToDownloads({
    required String certPem,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) {
      throw CertificateNativeException(
        'Saving to Downloads is only supported on Android',
      );
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'saveCertificateToDownloads',
        {
          'certPem': certPem,
          'fileName': fileName,
        },
      );
      return result ?? 'Downloads/$fileName';
    } on PlatformException catch (e) {
      throw CertificateNativeException(
        'Failed to save certificate: ${e.message}',
      );
    }
  }

  /// Checks if native certificate operations are supported on this platform.
  bool get isSupported => Platform.isAndroid;
}

/// Exception thrown when native certificate operations fail.
class CertificateNativeException implements Exception {
  final String message;

  CertificateNativeException(this.message);

  @override
  String toString() => message;
}
