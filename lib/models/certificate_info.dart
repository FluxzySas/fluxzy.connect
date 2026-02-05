/// Represents parsed X509 certificate information for display.
class CertificateInfo {
  /// Common Name (CN) from the certificate subject
  final String commonName;

  /// Certificate serial number in hex format
  final String serialNumber;

  /// SHA-256 fingerprint of the certificate
  final String fingerprint;

  /// Certificate expiration date
  final DateTime expirationDate;

  /// Certificate validity start date
  final DateTime validFromDate;

  /// Public key information (e.g., "RSA 2048-bit")
  final String publicKeyInfo;

  /// Certificate issuer (typically same as subject for CA certs)
  final String issuer;

  /// Original PEM-encoded certificate data
  final String rawPem;

  const CertificateInfo({
    required this.commonName,
    required this.serialNumber,
    required this.fingerprint,
    required this.expirationDate,
    required this.validFromDate,
    required this.publicKeyInfo,
    required this.issuer,
    required this.rawPem,
  });

  /// Whether the certificate is currently valid (not expired)
  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(validFromDate) && now.isBefore(expirationDate);
  }

  /// Whether the certificate is expired
  bool get isExpired => DateTime.now().isAfter(expirationDate);

  /// Days until expiration (negative if already expired)
  int get daysUntilExpiration {
    return expirationDate.difference(DateTime.now()).inDays;
  }

  CertificateInfo copyWith({
    String? commonName,
    String? serialNumber,
    String? fingerprint,
    DateTime? expirationDate,
    DateTime? validFromDate,
    String? publicKeyInfo,
    String? issuer,
    String? rawPem,
  }) {
    return CertificateInfo(
      commonName: commonName ?? this.commonName,
      serialNumber: serialNumber ?? this.serialNumber,
      fingerprint: fingerprint ?? this.fingerprint,
      expirationDate: expirationDate ?? this.expirationDate,
      validFromDate: validFromDate ?? this.validFromDate,
      publicKeyInfo: publicKeyInfo ?? this.publicKeyInfo,
      issuer: issuer ?? this.issuer,
      rawPem: rawPem ?? this.rawPem,
    );
  }

  @override
  String toString() {
    return 'CertificateInfo(CN: $commonName, expires: $expirationDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CertificateInfo && other.fingerprint == fingerprint;
  }

  @override
  int get hashCode => fingerprint.hashCode;
}
