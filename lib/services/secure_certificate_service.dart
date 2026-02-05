import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Service for generating and securely storing self-signed certificates
/// for HTTPS web server functionality.
class SecureCertificateService {
  static const String _keyPrivateKey = 'web_server_private_key';
  static const String _keyCertificate = 'web_server_certificate';

  final FlutterSecureStorage _secureStorage;

  SecureCertificateService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  /// Checks if a certificate already exists in secure storage.
  Future<bool> hasCertificate() async {
    final privateKey = await _secureStorage.read(key: _keyPrivateKey);
    final certificate = await _secureStorage.read(key: _keyCertificate);
    return privateKey != null && certificate != null;
  }

  /// Generates a new self-signed certificate if one doesn't exist.
  /// Returns true if a new certificate was generated, false if one already exists.
  Future<bool> generateCertificateIfNeeded() async {
    if (await hasCertificate()) {
      debugPrint('[SecureCertificateService] Certificate already exists');
      return false;
    }

    debugPrint('[SecureCertificateService] Generating new certificate...');
    await _generateAndStoreCertificate();
    debugPrint('[SecureCertificateService] Certificate generated and stored');
    return true;
  }

  /// Forces generation of a new certificate, replacing any existing one.
  Future<void> regenerateCertificate() async {
    debugPrint('[SecureCertificateService] Regenerating certificate...');
    await _generateAndStoreCertificate();
    debugPrint('[SecureCertificateService] Certificate regenerated');
  }

  /// Deletes the stored certificate and private key.
  Future<void> deleteCertificate() async {
    await _secureStorage.delete(key: _keyPrivateKey);
    await _secureStorage.delete(key: _keyCertificate);
    debugPrint('[SecureCertificateService] Certificate deleted');
  }

  /// Gets a SecurityContext configured with the stored certificate.
  /// Throws if no certificate exists.
  Future<SecurityContext> getSecurityContext() async {
    final privateKeyPem = await _secureStorage.read(key: _keyPrivateKey);
    final certificatePem = await _secureStorage.read(key: _keyCertificate);

    if (privateKeyPem == null || certificatePem == null) {
      throw StateError('No certificate found. Call generateCertificateIfNeeded() first.');
    }

    debugPrint('[SecureCertificateService] Loading certificate into SecurityContext...');
    debugPrint('[SecureCertificateService] Certificate length: ${certificatePem.length} chars');
    debugPrint('[SecureCertificateService] Private key length: ${privateKeyPem.length} chars');

    try {
      final context = SecurityContext();
      // Use utf8.encode for proper byte conversion
      context.useCertificateChainBytes(utf8.encode(certificatePem));
      context.usePrivateKeyBytes(utf8.encode(privateKeyPem));
      debugPrint('[SecureCertificateService] SecurityContext configured successfully');
      return context;
    } catch (e, stack) {
      debugPrint('[SecureCertificateService] Failed to configure SecurityContext: $e');
      debugPrint('[SecureCertificateService] Stack: $stack');
      rethrow;
    }
  }

  /// Gets the certificate fingerprint (SHA-256) for display/verification.
  Future<String?> getCertificateFingerprint() async {
    final certificatePem = await _secureStorage.read(key: _keyCertificate);
    if (certificatePem == null) return null;

    // Extract DER from PEM
    final derBytes = _pemToDer(certificatePem);
    if (derBytes == null) return null;

    // Calculate SHA-256 fingerprint
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(derBytes));

    // Format as colon-separated hex
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  /// Gets the certificate PEM for export/display.
  Future<String?> getCertificatePem() async {
    return await _secureStorage.read(key: _keyCertificate);
  }

  /// Gets the private key PEM for debugging (use with caution).
  Future<String?> getPrivateKeyPem() async {
    return await _secureStorage.read(key: _keyPrivateKey);
  }

  /// Dumps certificate and key info for debugging.
  Future<void> debugDumpCertificateInfo() async {
    final cert = await _secureStorage.read(key: _keyCertificate);
    final key = await _secureStorage.read(key: _keyPrivateKey);

    debugPrint('[SecureCertificateService] === Certificate Debug Info ===');
    debugPrint('[SecureCertificateService] Certificate exists: ${cert != null}');
    debugPrint('[SecureCertificateService] Private key exists: ${key != null}');

    if (cert != null) {
      debugPrint('[SecureCertificateService] Certificate length: ${cert.length}');
      debugPrint('[SecureCertificateService] Certificate starts with: ${cert.substring(0, min(50, cert.length))}...');
      debugPrint('[SecureCertificateService] Certificate ends with: ...${cert.substring(max(0, cert.length - 50))}');
    }

    if (key != null) {
      debugPrint('[SecureCertificateService] Private key length: ${key.length}');
      debugPrint('[SecureCertificateService] Private key starts with: ${key.substring(0, min(50, key.length))}...');
    }

    final fingerprint = await getCertificateFingerprint();
    debugPrint('[SecureCertificateService] Fingerprint: $fingerprint');
    debugPrint('[SecureCertificateService] === End Debug Info ===');
  }

  /// Generates a new RSA key pair and self-signed certificate.
  Future<void> _generateAndStoreCertificate() async {
    // Generate RSA 2048-bit key pair
    final keyPair = _generateRsaKeyPair();
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;

    // Generate self-signed certificate
    final certificate = _generateSelfSignedCertificate(
      privateKey: privateKey,
      publicKey: publicKey,
      commonName: 'Fluxzy Connect Local API',
      validityDays: 3650, // 10 years
    );

    // Convert to PEM format
    final privateKeyPem = _encodePrivateKeyToPem(privateKey);
    final certificatePem = _encodeCertificateToPem(certificate);

    // Store securely
    await _secureStorage.write(key: _keyPrivateKey, value: privateKeyPem);
    await _secureStorage.write(key: _keyCertificate, value: certificatePem);
  }

  /// Generates an RSA key pair using PointyCastle.
  AsymmetricKeyPair<PublicKey, PrivateKey> _generateRsaKeyPair() {
    final secureRandom = _getSecureRandom();
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));
    return keyGen.generateKeyPair();
  }

  /// Gets a secure random number generator.
  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Generates a self-signed X.509 certificate.
  Uint8List _generateSelfSignedCertificate({
    required RSAPrivateKey privateKey,
    required RSAPublicKey publicKey,
    required String commonName,
    required int validityDays,
  }) {
    final now = DateTime.now().toUtc();
    final notBefore = now;
    final notAfter = now.add(Duration(days: validityDays));

    // Build certificate structure using ASN.1 DER encoding
    final tbsCertificate = _buildTbsCertificate(
      publicKey: publicKey,
      commonName: commonName,
      notBefore: notBefore,
      notAfter: notAfter,
    );

    // Sign the TBS certificate
    final signature = _signData(tbsCertificate, privateKey);

    // Build the complete certificate
    return _buildCertificate(tbsCertificate, signature);
  }

  /// Builds the TBS (To Be Signed) certificate structure.
  Uint8List _buildTbsCertificate({
    required RSAPublicKey publicKey,
    required String commonName,
    required DateTime notBefore,
    required DateTime notAfter,
  }) {
    final builder = <int>[];

    // Version (v3)
    builder.addAll(_asn1ContextTag(0, _asn1Integer(BigInt.from(2))));

    // Serial number (random)
    final serial = BigInt.from(Random.secure().nextInt(0x7FFFFFFF));
    builder.addAll(_asn1Integer(serial));

    // Signature algorithm (SHA256withRSA)
    builder.addAll(_asn1Sequence([
      ..._asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11]), // sha256WithRSAEncryption
      ..._asn1Null(),
    ]));

    // Issuer (same as subject for self-signed)
    final name = _buildName(commonName);
    builder.addAll(name);

    // Validity
    builder.addAll(_asn1Sequence([
      ..._asn1UtcTime(notBefore),
      ..._asn1UtcTime(notAfter),
    ]));

    // Subject
    builder.addAll(name);

    // Subject public key info
    builder.addAll(_buildSubjectPublicKeyInfo(publicKey));

    // Extensions (v3) - Subject Alternative Names
    builder.addAll(_asn1ContextTag(3, _asn1Sequence([
      ..._buildSanExtension(),
    ])));

    return Uint8List.fromList(_asn1Sequence(builder));
  }

  /// Builds the Subject Alternative Name extension.
  List<int> _buildSanExtension() {
    // OID for subjectAltName: 2.5.29.17
    final oid = _asn1ObjectIdentifier([2, 5, 29, 17]);

    // DNS names and IP addresses
    final sans = <int>[];
    // DNS: localhost
    sans.addAll(_asn1ContextTagPrimitive(2, 'localhost'.codeUnits));
    // IP: 127.0.0.1
    sans.addAll(_asn1ContextTagPrimitive(7, [127, 0, 0, 1]));
    // IP: 10.0.0.1
    sans.addAll(_asn1ContextTagPrimitive(7, [10, 0, 0, 1]));

    final sanValue = _asn1OctetString(_asn1Sequence(sans));

    return _asn1Sequence([...oid, ...sanValue]);
  }

  /// Builds the complete certificate from TBS and signature.
  Uint8List _buildCertificate(Uint8List tbsCertificate, Uint8List signature) {
    final certificate = <int>[];

    // TBS Certificate
    certificate.addAll(tbsCertificate);

    // Signature algorithm
    certificate.addAll(_asn1Sequence([
      ..._asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11]),
      ..._asn1Null(),
    ]));

    // Signature value
    certificate.addAll(_asn1BitString(signature));

    return Uint8List.fromList(_asn1Sequence(certificate));
  }

  /// Signs data with RSA private key using SHA-256.
  Uint8List _signData(Uint8List data, RSAPrivateKey privateKey) {
    // DigestInfo prefix for SHA-256 in PKCS#1 v1.5 signature:
    // 30 31 - SEQUENCE (49 bytes)
    //   30 0d - SEQUENCE (AlgorithmIdentifier)
    //     06 09 60 86 48 01 65 03 04 02 01 - OID sha256
    //     05 00 - NULL
    //   04 20 - OCTET STRING (32 bytes hash follows)
    const sha256DigestInfoPrefix = '3031300d060960864801650304020105000420';
    final signer = RSASigner(SHA256Digest(), sha256DigestInfoPrefix);
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(data);
    return sig.bytes;
  }

  /// Builds the subject public key info structure.
  List<int> _buildSubjectPublicKeyInfo(RSAPublicKey publicKey) {
    final algorithmId = _asn1Sequence([
      ..._asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]), // rsaEncryption
      ..._asn1Null(),
    ]);

    final publicKeyBytes = _asn1Sequence([
      ..._asn1Integer(publicKey.modulus!),
      ..._asn1Integer(publicKey.exponent!),
    ]);

    return _asn1Sequence([
      ...algorithmId,
      ..._asn1BitString(Uint8List.fromList(publicKeyBytes)),
    ]);
  }

  /// Builds an X.500 name structure.
  List<int> _buildName(String commonName) {
    final cn = _asn1Set([
      ..._asn1Sequence([
        ..._asn1ObjectIdentifier([2, 5, 4, 3]), // commonName
        ..._asn1PrintableString(commonName),
      ]),
    ]);
    return _asn1Sequence([...cn]);
  }

  // ASN.1 DER encoding helpers

  List<int> _asn1Sequence(List<int> content) => _asn1Tag(0x30, content);
  List<int> _asn1Set(List<int> content) => _asn1Tag(0x31, content);
  List<int> _asn1OctetString(List<int> content) => _asn1Tag(0x04, content);
  List<int> _asn1Null() => [0x05, 0x00];

  List<int> _asn1Tag(int tag, List<int> content) {
    final length = _asn1Length(content.length);
    return [tag, ...length, ...content];
  }

  List<int> _asn1ContextTag(int tag, List<int> content) {
    return _asn1Tag(0xA0 + tag, content);
  }

  List<int> _asn1ContextTagPrimitive(int tag, List<int> content) {
    return _asn1Tag(0x80 + tag, content);
  }

  List<int> _asn1Length(int length) {
    if (length < 128) {
      return [length];
    }
    final bytes = <int>[];
    var temp = length;
    while (temp > 0) {
      bytes.insert(0, temp & 0xFF);
      temp >>= 8;
    }
    return [0x80 | bytes.length, ...bytes];
  }

  List<int> _asn1Integer(BigInt value) {
    var bytes = _bigIntToBytes(value);
    // Ensure positive numbers don't get interpreted as negative
    if (bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
      bytes = [0, ...bytes];
    }
    return _asn1Tag(0x02, bytes);
  }

  List<int> _asn1BitString(Uint8List data) {
    return _asn1Tag(0x03, [0, ...data]); // 0 unused bits
  }

  List<int> _asn1ObjectIdentifier(List<int> components) {
    final bytes = <int>[];
    if (components.length >= 2) {
      bytes.add(components[0] * 40 + components[1]);
      for (var i = 2; i < components.length; i++) {
        bytes.addAll(_encodeOidComponent(components[i]));
      }
    }
    return _asn1Tag(0x06, bytes);
  }

  List<int> _encodeOidComponent(int value) {
    if (value < 128) {
      return [value];
    }
    final bytes = <int>[];
    var temp = value;
    bytes.add(temp & 0x7F);
    temp >>= 7;
    while (temp > 0) {
      bytes.insert(0, (temp & 0x7F) | 0x80);
      temp >>= 7;
    }
    return bytes;
  }

  List<int> _asn1PrintableString(String s) {
    return _asn1Tag(0x13, s.codeUnits);
  }

  List<int> _asn1UtcTime(DateTime dt) {
    final s = '${_twoDigit(dt.year % 100)}'
        '${_twoDigit(dt.month)}'
        '${_twoDigit(dt.day)}'
        '${_twoDigit(dt.hour)}'
        '${_twoDigit(dt.minute)}'
        '${_twoDigit(dt.second)}Z';
    return _asn1Tag(0x17, s.codeUnits);
  }

  String _twoDigit(int n) => n.toString().padLeft(2, '0');

  List<int> _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) return [0];
    final bytes = <int>[];
    var temp = value;
    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & BigInt.from(0xFF)).toInt());
      temp >>= 8;
    }
    return bytes;
  }

  /// Encodes private key to PEM format.
  String _encodePrivateKeyToPem(RSAPrivateKey key) {
    final keyBytes = _buildPrivateKeyInfo(key);
    final base64 = _base64Encode(keyBytes);
    return '-----BEGIN PRIVATE KEY-----\n$base64\n-----END PRIVATE KEY-----';
  }

  /// Builds PKCS#8 private key info structure.
  List<int> _buildPrivateKeyInfo(RSAPrivateKey key) {
    // RSA private key structure
    final rsaPrivateKey = _asn1Sequence([
      ..._asn1Integer(BigInt.zero), // version
      ..._asn1Integer(key.modulus!),
      ..._asn1Integer(key.publicExponent!),
      ..._asn1Integer(key.privateExponent!),
      ..._asn1Integer(key.p!),
      ..._asn1Integer(key.q!),
      ..._asn1Integer(key.privateExponent! % (key.p! - BigInt.one)), // d mod (p-1)
      ..._asn1Integer(key.privateExponent! % (key.q! - BigInt.one)), // d mod (q-1)
      ..._asn1Integer(key.q!.modInverse(key.p!)), // q^-1 mod p
    ]);

    // PKCS#8 structure
    return _asn1Sequence([
      ..._asn1Integer(BigInt.zero), // version
      ..._asn1Sequence([
        ..._asn1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]), // rsaEncryption
        ..._asn1Null(),
      ]),
      ..._asn1OctetString(rsaPrivateKey),
    ]);
  }

  /// Encodes certificate to PEM format.
  String _encodeCertificateToPem(Uint8List certBytes) {
    final base64 = _base64Encode(certBytes);
    return '-----BEGIN CERTIFICATE-----\n$base64\n-----END CERTIFICATE-----';
  }

  /// Base64 encodes with line breaks every 64 characters.
  String _base64Encode(List<int> bytes) {
    final encoded = _toBase64(Uint8List.fromList(bytes));
    final lines = <String>[];
    for (var i = 0; i < encoded.length; i += 64) {
      lines.add(encoded.substring(i, i + 64 > encoded.length ? encoded.length : i + 64));
    }
    return lines.join('\n');
  }

  String _toBase64(Uint8List bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b1 = bytes[i];
      final b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;

      result.write(alphabet[(b1 >> 2) & 0x3F]);
      result.write(alphabet[((b1 << 4) | (b2 >> 4)) & 0x3F]);
      result.write(i + 1 < bytes.length ? alphabet[((b2 << 2) | (b3 >> 6)) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? alphabet[b3 & 0x3F] : '=');
    }
    return result.toString();
  }

  /// Extracts DER bytes from PEM string.
  List<int>? _pemToDer(String pem) {
    final lines = pem.split('\n');
    final base64Lines = lines.where((line) => !line.startsWith('-----')).join();
    if (base64Lines.isEmpty) return null;
    return _fromBase64(base64Lines);
  }

  List<int> _fromBase64(String encoded) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = <int>[];
    var buffer = 0;
    var bits = 0;

    for (final char in encoded.runes) {
      if (char == 61) break; // '='
      final value = alphabet.indexOf(String.fromCharCode(char));
      if (value < 0) continue;
      buffer = (buffer << 6) | value;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        result.add((buffer >> bits) & 0xFF);
      }
    }
    return result;
  }
}
