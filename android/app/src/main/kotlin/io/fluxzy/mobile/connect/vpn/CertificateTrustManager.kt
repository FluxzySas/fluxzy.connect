package io.fluxzy.mobile.connect.vpn

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.security.KeyChain
import android.util.Base64
import android.util.Log
import java.io.ByteArrayInputStream
import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate

/**
 * Manages certificate trust checking and installation on Android.
 */
class CertificateTrustManager(private val context: Context) {

    companion object {
        private const val TAG = "CertificateTrustManager"
        const val CERT_INSTALL_REQUEST_CODE = 2001
    }

    /**
     * Checks if a certificate with the given fingerprint is trusted as a CA.
     *
     * @param fingerprint The SHA-256 fingerprint of the certificate (colon-separated hex)
     * @return true if the certificate is trusted, false otherwise
     */
    fun isCertificateTrusted(fingerprint: String): Boolean {
        try {
            // Normalize fingerprint for comparison
            val normalizedFingerprint = fingerprint.replace(":", "").uppercase()

            // Check system CA store
            if (checkSystemCaStore(normalizedFingerprint)) {
                Log.d(TAG, "Certificate found in system CA store")
                return true
            }

            // Check user-installed CA store
            if (checkUserCaStore(normalizedFingerprint)) {
                Log.d(TAG, "Certificate found in user CA store")
                return true
            }

            Log.d(TAG, "Certificate not found in any trust store")
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking certificate trust", e)
            return false
        }
    }

    /**
     * Checks the system CA certificate store.
     */
    private fun checkSystemCaStore(normalizedFingerprint: String): Boolean {
        try {
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null)

            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val alias = aliases.nextElement()
                val cert = keyStore.getCertificate(alias) as? X509Certificate ?: continue

                val certFingerprint = calculateFingerprint(cert)
                if (certFingerprint == normalizedFingerprint) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking system CA store", e)
        }
        return false
    }

    /**
     * Checks the user-installed CA certificate store.
     */
    private fun checkUserCaStore(normalizedFingerprint: String): Boolean {
        try {
            // User CA certs are also accessible via AndroidCAStore
            // They have aliases starting with "user:"
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null)

            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val alias = aliases.nextElement()
                if (!alias.startsWith("user:")) continue

                val cert = keyStore.getCertificate(alias) as? X509Certificate ?: continue

                val certFingerprint = calculateFingerprint(cert)
                if (certFingerprint == normalizedFingerprint) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking user CA store", e)
        }
        return false
    }

    /**
     * Calculates the SHA-256 fingerprint of a certificate.
     */
    private fun calculateFingerprint(cert: X509Certificate): String {
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(cert.encoded)
        return digest.joinToString("") { "%02X".format(it) }
    }

    /**
     * Launches the system certificate installation Intent.
     *
     * @param activity The activity to use for launching the Intent
     * @param certPem The PEM-encoded certificate string
     * @param certName A friendly name for the certificate
     * @return true if the Intent was launched successfully
     */
    fun requestInstallCertificate(
        activity: Activity,
        certPem: String,
        certName: String
    ): Boolean {
        try {
            // Parse PEM to get DER bytes
            val derBytes = pemToDer(certPem)
            if (derBytes == null) {
                Log.e(TAG, "Failed to convert PEM to DER")
                return false
            }

            // Use KeyChain API to install the certificate
            val installIntent = KeyChain.createInstallIntent()
            installIntent.putExtra(KeyChain.EXTRA_CERTIFICATE, derBytes)
            installIntent.putExtra(KeyChain.EXTRA_NAME, certName)

            activity.startActivityForResult(installIntent, CERT_INSTALL_REQUEST_CODE)
            Log.d(TAG, "Certificate install Intent launched")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch certificate install Intent", e)
            return false
        }
    }

    /**
     * Alternative method using raw bytes directly.
     */
    fun requestInstallCertificateFromBytes(
        activity: Activity,
        certBytes: ByteArray,
        certName: String
    ): Boolean {
        try {
            val installIntent = KeyChain.createInstallIntent()
            installIntent.putExtra(KeyChain.EXTRA_CERTIFICATE, certBytes)
            installIntent.putExtra(KeyChain.EXTRA_NAME, certName)

            activity.startActivityForResult(installIntent, CERT_INSTALL_REQUEST_CODE)
            Log.d(TAG, "Certificate install Intent launched from bytes")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch certificate install Intent", e)
            return false
        }
    }

    /**
     * Converts a PEM-encoded certificate to DER format.
     */
    private fun pemToDer(pem: String): ByteArray? {
        try {
            // Remove PEM headers and whitespace
            val base64Content = pem
                .replace("-----BEGIN CERTIFICATE-----", "")
                .replace("-----END CERTIFICATE-----", "")
                .replace("\\s".toRegex(), "")

            return Base64.decode(base64Content, Base64.DEFAULT)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decode PEM", e)
            return null
        }
    }

    /**
     * Parses a PEM certificate and extracts its Common Name.
     */
    fun getCertificateCommonName(certPem: String): String? {
        try {
            val derBytes = pemToDer(certPem) ?: return null
            val certFactory = CertificateFactory.getInstance("X.509")
            val cert = certFactory.generateCertificate(
                ByteArrayInputStream(derBytes)
            ) as X509Certificate

            // Extract CN from subject
            val subject = cert.subjectX500Principal.name
            val cnPattern = Regex("CN=([^,]+)")
            val match = cnPattern.find(subject)
            return match?.groupValues?.get(1)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract CN from certificate", e)
            return null
        }
    }

    /**
     * Calculates fingerprint from PEM certificate.
     */
    fun getFingerprintFromPem(certPem: String): String? {
        try {
            val derBytes = pemToDer(certPem) ?: return null
            val certFactory = CertificateFactory.getInstance("X.509")
            val cert = certFactory.generateCertificate(
                ByteArrayInputStream(derBytes)
            ) as X509Certificate

            return calculateFingerprint(cert)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to calculate fingerprint", e)
            return null
        }
    }
}
