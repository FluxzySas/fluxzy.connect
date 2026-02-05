package io.fluxzy.mobile.connect.vpn.models

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName

data class ProxyHostData(
    val hostname: String,
    val port: Int,
    val hostName: String?,
    val osName: String?,
    val fluxzyVersion: String?,
    val fluxzyStartupSetting: String?,
    val certEndpoint: String?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "hostname" to hostname,
        "port" to port,
        "hostName" to hostName,
        "osName" to osName,
        "fluxzyVersion" to fluxzyVersion,
        "fluxzyStartupSetting" to fluxzyStartupSetting,
        "certEndpoint" to certEndpoint,
        "isDiscovered" to true
    )

    companion object {
        private val gson = Gson()

        fun fromJson(jsonStr: String): ProxyHostData? {
            return try {
                val payload = gson.fromJson(jsonStr, TxtRecordPayload::class.java)
                ProxyHostData(
                    hostname = payload.host,
                    port = payload.port,
                    hostName = payload.hostName,
                    osName = payload.osName,
                    fluxzyVersion = payload.fluxzyVersion,
                    fluxzyStartupSetting = payload.fluxzyStartupSetting,
                    certEndpoint = payload.certEndpoint
                )
            } catch (e: Exception) {
                null
            }
        }

        fun fromServiceInfo(
            resolvedHost: String,
            resolvedPort: Int,
            serviceName: String,
            txtData: String?
        ): ProxyHostData {
            // Try to parse JSON from TXT data
            if (!txtData.isNullOrBlank()) {
                try {
                    val payload = gson.fromJson(txtData, TxtRecordPayload::class.java)
                    return ProxyHostData(
                        hostname = payload.host,
                        port = payload.port,
                        hostName = payload.hostName,
                        osName = payload.osName,
                        fluxzyVersion = payload.fluxzyVersion,
                        fluxzyStartupSetting = payload.fluxzyStartupSetting,
                        certEndpoint = payload.certEndpoint
                    )
                } catch (e: Exception) {
                    // Fall through to use resolved values
                }
            }

            // Fallback: use resolved host/port and service name
            return ProxyHostData(
                hostname = resolvedHost,
                port = resolvedPort,
                hostName = serviceName,
                osName = null,
                fluxzyVersion = null,
                fluxzyStartupSetting = null,
                certEndpoint = null
            )
        }
    }
}

/**
 * Internal data class for parsing the mDNS TXT record JSON payload.
 * Matches the server's JSON structure:
 * {
 *   "host": "192.168.1.100",
 *   "port": 9852,
 *   "hostName": "DESKTOP-HOME",
 *   "osName": "Windows 11",
 *   "fluxzyVersion": "1.0.0",
 *   "fluxzyStartupSetting": "...",
 *   "certEndpoint": "/cert"
 * }
 */
data class TxtRecordPayload(
    @SerializedName("host")
    val host: String,
    @SerializedName("port")
    val port: Int,
    @SerializedName("hostName")
    val hostName: String?,
    @SerializedName("osName")
    val osName: String?,
    @SerializedName("fluxzyVersion")
    val fluxzyVersion: String?,
    @SerializedName("fluxzyStartupSetting")
    val fluxzyStartupSetting: String?,
    @SerializedName("certEndpoint")
    val certEndpoint: String?
)
