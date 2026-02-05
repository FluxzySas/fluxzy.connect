package io.fluxzy.mobile.connect.vpn

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class CertificateDownloader(private val context: Context) {

    companion object {
        private const val TAG = "CertificateDownloader"
        private const val CERT_FILENAME = "fluxzy_ca.crt"
        private const val TIMEOUT_MS = 10000
    }

    /**
     * Downloads certificate from the proxy host.
     * @param hostname The proxy host IP/hostname
     * @param port The proxy port
     * @param certEndpoint The relative cert endpoint (e.g., "/cert")
     * @return The local file path where the certificate was saved, or null on failure
     */
    suspend fun downloadCertificate(
        hostname: String,
        port: Int,
        certEndpoint: String
    ): String? = withContext(Dispatchers.IO) {
        try {
            // Ensure certEndpoint starts with /
            val endpoint = if (certEndpoint.startsWith("/")) certEndpoint else "/$certEndpoint"
            val url = URL("http://$hostname:$port$endpoint")
            Log.d(TAG, "Downloading certificate from: $url")

            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            connection.requestMethod = "GET"
            connection.setRequestProperty("Accept", "*/*")

            try {
                val responseCode = connection.responseCode
                if (responseCode != HttpURLConnection.HTTP_OK) {
                    Log.e(TAG, "HTTP error: $responseCode")
                    return@withContext null
                }

                val certData = connection.inputStream.bufferedReader().readText()

                if (certData.isBlank()) {
                    Log.e(TAG, "Empty certificate data received")
                    return@withContext null
                }

                // Store the certificate
                val certFile = File(context.filesDir, CERT_FILENAME)
                certFile.writeText(certData)

                Log.d(TAG, "Certificate saved to: ${certFile.absolutePath}")
                Log.d(TAG, "Certificate size: ${certData.length} bytes")

                certFile.absolutePath
            } finally {
                connection.disconnect()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to download certificate", e)
            null
        }
    }

    /**
     * Gets the path to the stored certificate, or null if not present.
     */
    fun getCertificatePath(): String? {
        val certFile = File(context.filesDir, CERT_FILENAME)
        return if (certFile.exists()) certFile.absolutePath else null
    }

    /**
     * Reads the stored certificate content, or null if not present.
     */
    fun getCertificateContent(): String? {
        val certFile = File(context.filesDir, CERT_FILENAME)
        return if (certFile.exists()) certFile.readText() else null
    }

    /**
     * Deletes the stored certificate.
     */
    fun deleteCertificate(): Boolean {
        val certFile = File(context.filesDir, CERT_FILENAME)
        return if (certFile.exists()) {
            val deleted = certFile.delete()
            if (deleted) {
                Log.d(TAG, "Certificate deleted")
            } else {
                Log.e(TAG, "Failed to delete certificate")
            }
            deleted
        } else {
            true // File doesn't exist, consider it deleted
        }
    }
}
