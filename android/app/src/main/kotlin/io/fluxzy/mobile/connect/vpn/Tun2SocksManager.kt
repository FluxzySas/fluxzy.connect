package io.fluxzy.mobile.connect.vpn

import android.os.ParcelFileDescriptor
import android.util.Log
import com.hev.socks5tunnel.HevSocks5Tunnel
import com.hev.socks5tunnel.TunnelConfig
import com.hev.socks5tunnel.TunnelException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Wrapper for hev-socks5-tunnel library (HevSocks5Tunnel).
 *
 * This class interfaces with the hev-socks5-tunnel library to tunnel
 * traffic through a SOCKS5 proxy.
 *
 * Features:
 * - SOCKS5 authentication support
 * - MapDNS (Fake-IP) for hostname preservation
 * - Traffic statistics monitoring
 * - Configurable MTU and timeouts
 */
class Tun2SocksManager {

    companion object {
        private const val TAG = "Tun2SocksManager"

        // MapDNS configuration
        const val MAP_DNS_ADDRESS = "198.18.0.2"
        const val MAP_DNS_PORT = 53
        private const val MAP_DNS_NETWORK = "240.0.0.0"
        private const val MAP_DNS_NETMASK = "240.0.0.0"
        private const val MAP_DNS_CACHE_SIZE = 10000

        // Default timeouts
        private const val CONNECT_TIMEOUT_MS = 10000
        private const val TCP_TIMEOUT_MS = 300000
        private const val UDP_TIMEOUT_MS = 60000
    }

    /**
     * Starts the tunnel with the given configuration.
     *
     * @param vpnInterface ParcelFileDescriptor of the TUN interface
     * @param mtu MTU size for the TUN interface
     * @param socksHost SOCKS5 proxy hostname
     * @param socksPort SOCKS5 proxy port
     * @param username Optional SOCKS5 username for authentication
     * @param password Optional SOCKS5 password for authentication
     * @param enableMapDns Enable MapDNS (Fake-IP) feature
     * @param enableDebugLogging Enable verbose debug logging
     * @param blockHttp3 Block HTTP/3 (QUIC) by disabling UDP forwarding
     * @return true if started successfully, false otherwise
     */
    suspend fun start(
        vpnInterface: ParcelFileDescriptor,
        mtu: Int,
        socksHost: String,
        socksPort: Int,
        username: String? = null,
        password: String? = null,
        enableMapDns: Boolean = true,
        enableDebugLogging: Boolean = false,
        blockHttp3: Boolean = false
    ): Boolean = withContext(Dispatchers.IO) {
        if (HevSocks5Tunnel.isRunning()) {
            Log.w(TAG, "Tunnel is already running")
            return@withContext true
        }

        val fd = vpnInterface.fd
        Log.d(TAG, "Starting tunnel with proxy: $socksHost:$socksPort (fd=$fd, mtu=$mtu, mapDns=$enableMapDns, blockHttp3=$blockHttp3)")

        // Verify fd is valid
        try {
            val fdField = vpnInterface.fileDescriptor
            Log.d(TAG, "FileDescriptor valid: ${fdField.valid()}, fd=$fd")
        } catch (e: Exception) {
            Log.e(TAG, "FileDescriptor validation failed: ${e.message}")
        }

        return@withContext try {
            // When blockHttp3 is enabled, set UDP timeout to 1ms to effectively disable UDP/QUIC
            // This forces browsers to fall back to HTTP/2 over TCP
            val effectiveUdpTimeout = if (blockHttp3) 1 else UDP_TIMEOUT_MS

            if (blockHttp3) {
                Log.i(TAG, "HTTP/3 (QUIC) blocking enabled - UDP timeout set to 1ms")
            }

            val config = TunnelConfig(
                tunFd = vpnInterface.fd,
                mtu = mtu,
                socksAddress = socksHost,
                socksPort = socksPort,
                socksUsername = username,
                socksPassword = password,
                socksUdpMode = TunnelConfig.UdpMode.UDP,
                mapDnsEnabled = enableMapDns,
                mapDnsAddress = MAP_DNS_ADDRESS,
                mapDnsPort = MAP_DNS_PORT,
                mapDnsNetwork = MAP_DNS_NETWORK,
                mapDnsNetmask = MAP_DNS_NETMASK,
                mapDnsCacheSize = MAP_DNS_CACHE_SIZE,
                logLevel = if (enableDebugLogging) TunnelConfig.LogLevel.DEBUG else TunnelConfig.LogLevel.WARN,
                connectTimeoutMs = CONNECT_TIMEOUT_MS,
                tcpReadWriteTimeoutMs = TCP_TIMEOUT_MS,
                udpReadWriteTimeoutMs = effectiveUdpTimeout
            )

            Log.d(TAG, "Calling HevSocks5Tunnel.start() with config: tunFd=$fd, socks=$socksHost:$socksPort")
            HevSocks5Tunnel.start(config)

            // Verify tunnel is actually running
            val isRunning = HevSocks5Tunnel.isRunning()
            Log.d(TAG, "After start - isRunning: $isRunning")

            // Try to get version to verify library is loaded
            try {
                val version = HevSocks5Tunnel.getVersion()
                Log.d(TAG, "Library version: $version")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get library version: ${e.message}")
            }

            val authInfo = if (!username.isNullOrEmpty()) " with authentication for user: $username" else " without authentication"
            Log.d(TAG, "Tunnel started$authInfo (mapDns=$enableMapDns)")

            // Check stats after a delay to see if traffic is flowing
            kotlinx.coroutines.delay(2000)
            try {
                val stats = HevSocks5Tunnel.getStats()
                Log.d(TAG, "Initial stats - upload: ${stats?.uploadBytes ?: 0}, download: ${stats?.downloadBytes ?: 0}, connections: ${stats?.activeConnections ?: 0}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get stats: ${e.message}")
            }

            isRunning
        } catch (e: TunnelException) {
            Log.e(TAG, "Failed to start tunnel: ${e.message}", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error starting tunnel: ${e.message}", e)
            false
        }
    }

    /**
     * Stops the tunnel.
     */
    suspend fun stop() = withContext(Dispatchers.IO) {
        if (!HevSocks5Tunnel.isRunning()) {
            Log.d(TAG, "Tunnel is not running")
            return@withContext
        }

        try {
            HevSocks5Tunnel.stop()
            Log.d(TAG, "Tunnel stopped successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping tunnel: ${e.message}", e)
        }
    }

    /**
     * Returns whether the tunnel is currently running.
     */
    fun isRunning(): Boolean = HevSocks5Tunnel.isRunning()

    /**
     * Returns current traffic statistics, or null if tunnel is not running.
     */
    fun getStats(): TrafficStats? {
        return try {
            val stats = HevSocks5Tunnel.getStats() ?: return null
            TrafficStats(
                uploadBytes = stats.uploadBytes,
                downloadBytes = stats.downloadBytes,
                activeConnections = stats.activeConnections.toLong()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting stats: ${e.message}", e)
            null
        }
    }

    /**
     * Returns the library version string.
     */
    fun getVersion(): String = HevSocks5Tunnel.getVersion()

    /**
     * Traffic statistics data class.
     */
    data class TrafficStats(
        val uploadBytes: Long,
        val downloadBytes: Long,
        val activeConnections: Long
    )
}
