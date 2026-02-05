import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:http/http.dart' as http;

import '../models/certificate_info.dart';

/// Service for fetching and parsing X509 certificates from the proxy server.
class CertificateService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches and parses the CA certificate from the proxy server.
  ///
  /// The certificate is fetched from `http://{hostname}:{port}/ca`.
  /// Returns the parsed certificate info or throws an exception on failure.
  Future<CertificateInfo> fetchCertificate({
    required String hostname,
    required int port,
  }) async {
    final url = Uri.parse('http://$hostname:$port/ca');

    try {
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode != 200) {
        throw CertificateException(
          'Failed to fetch certificate: HTTP ${response.statusCode}',
        );
      }

      final pemData = response.body;
      if (pemData.isEmpty) {
        throw CertificateException('Empty certificate data received');
      }

      return parseCertificate(pemData);
    } on http.ClientException catch (e) {
      throw CertificateException('Network error: ${e.message}');
    } catch (e) {
      if (e is CertificateException) rethrow;
      throw CertificateException('Failed to fetch certificate: $e');
    }
  }

  /// Parses a PEM-encoded X509 certificate and extracts relevant information.
  CertificateInfo parseCertificate(String pemData) {
    try {
      // Parse the X509 certificate
      final x509 = X509Utils.x509CertificateFromPem(pemData);

      // Extract Common Name from subject
      final commonName = _extractCommonName(x509.tbsCertificate?.subject);

      // Extract issuer CN
      final issuer = _extractCommonName(x509.tbsCertificate?.issuer);

      // Get serial number
      final serialNumber =
          x509.tbsCertificate?.serialNumber.toRadixString(16).toUpperCase() ??
          'Unknown';

      // Calculate SHA-256 fingerprint
      final fingerprint = _calculateFingerprint(pemData);

      // Get validity dates
      final validity = x509.tbsCertificate?.validity;
      final validFrom = validity?.notBefore ?? DateTime.now();
      final validTo =
          validity?.notAfter ?? DateTime.now().add(const Duration(days: 365));

      // Extract public key info
      final publicKeyInfo = _extractPublicKeyInfo(x509);

      return CertificateInfo(
        commonName: commonName,
        serialNumber: serialNumber,
        fingerprint: fingerprint,
        expirationDate: validTo,
        validFromDate: validFrom,
        publicKeyInfo: publicKeyInfo,
        issuer: issuer,
        rawPem: pemData,
      );
    } catch (e) {
      throw CertificateException('Failed to parse certificate: $e');
    }
  }

  /// Extracts the Common Name (CN) from a distinguished name map.
  String _extractCommonName(Map<String, String?>? distinguishedName) {
    if (distinguishedName == null) return 'Unknown';

    // Try different possible keys for CN
    return distinguishedName['CN'] ??
        distinguishedName['cn'] ??
        distinguishedName['2.5.4.3'] ?? // OID for Common Name
        'Unknown';
  }

  /// Extracts public key algorithm and size information.
  String _extractPublicKeyInfo(X509CertificateData x509) {
    final publicKeyData = x509.tbsCertificate?.subjectPublicKeyInfo;
    if (publicKeyData == null) return 'Unknown';

    final algorithm = publicKeyData.algorithm ?? 'Unknown';
    final keyLength = publicKeyData.length;

    if (keyLength != null && keyLength > 0) {
      return '$algorithm $keyLength-bit';
    }
    return algorithm;
  }

  /// Calculates the SHA-256 fingerprint of a PEM certificate.
  String _calculateFingerprint(String pemData) {
    try {
      // Remove PEM headers and decode base64
      final base64Content = pemData
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), '');

      final bytes = base64Decode(base64Content);

      // Calculate SHA-256 hash (returns hex string)
      final hexDigest = CryptoUtils.getHash(
        Uint8List.fromList(bytes),
        algorithmName: 'SHA-256',
      );

      // Format as colon-separated hex pairs (e.g., "AB:CD:EF:...")
      final buffer = StringBuffer();
      for (int i = 0; i < hexDigest.length; i += 2) {
        if (buffer.isNotEmpty) buffer.write(':');
        buffer.write(hexDigest.substring(i, i + 2).toUpperCase());
      }
      return buffer.toString();
    } catch (e) {
      return 'Unknown';
    }
  }
}

/// Exception thrown when certificate operations fail.
class CertificateException implements Exception {
  final String message;

  CertificateException(this.message);

  @override
  String toString() => message;
}
