package io.fluxzy.mobile.connect.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import io.fluxzy.mobile.connect.MainActivity
import io.fluxzy.mobile.connect.vpn.models.VpnState
import kotlinx.coroutines.*

class FluxzyVpnService : VpnService() {

    companion object {
        private const val TAG = "FluxzyVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "fluxzy_vpn_channel"
        private const val NOTIFICATION_ID = 1
        private const val MTU = 1500  // Standard Ethernet MTU

        // VPN configuration for MapDNS (Fake-IP)
        private const val VPN_ADDRESS = "198.18.0.1"
        private const val VPN_PREFIX_LENGTH = 24
        private const val VPN_ROUTE = "0.0.0.0"
        // DNS server points to MapDNS for hostname preservation

        // Intent actions and extras
        const val ACTION_CONNECT = "io.fluxzy.mobile.connect.vpn.CONNECT"
        const val ACTION_DISCONNECT = "io.fluxzy.mobile.connect.vpn.DISCONNECT"
        const val EXTRA_HOST = "host"
        const val EXTRA_PORT = "port"
        const val EXTRA_USERNAME = "username"
        const val EXTRA_PASSWORD = "password"
        const val EXTRA_ALLOWED_APPS = "allowed_apps"
        const val EXTRA_BLOCK_HTTP3 = "block_http3"

        // Singleton for communication with Flutter plugin
        @Volatile
        var instance: FluxzyVpnService? = null
            private set

        var stateListener: ((VpnState) -> Unit)? = null
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var tun2SocksManager: Tun2SocksManager? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var currentHost: String? = null
    private var currentPort: Int = 0
    private var currentUsername: String? = null
    private var currentPassword: String? = null
    private var allowedApps: List<String>? = null
    private var blockHttp3: Boolean = false

    @Volatile
    private var currentState: VpnState = VpnState.DISCONNECTED

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        Log.d(TAG, "FluxzyVpnService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")

        when (intent?.action) {
            ACTION_CONNECT -> {
                currentHost = intent.getStringExtra(EXTRA_HOST)
                currentPort = intent.getIntExtra(EXTRA_PORT, 0)
                currentUsername = intent.getStringExtra(EXTRA_USERNAME)
                currentPassword = intent.getStringExtra(EXTRA_PASSWORD)
                allowedApps = intent.getStringArrayListExtra(EXTRA_ALLOWED_APPS)
                blockHttp3 = intent.getBooleanExtra(EXTRA_BLOCK_HTTP3, false)

                if (!currentHost.isNullOrBlank() && currentPort > 0) {
                    connect()
                } else {
                    Log.e(TAG, "Invalid connection parameters: host=$currentHost, port=$currentPort")
                    updateState(VpnState.ERROR)
                }
            }
            ACTION_DISCONNECT -> {
                disconnect()
            }
            else -> {
                Log.w(TAG, "Unknown action: ${intent?.action}")
            }
        }

        return START_STICKY
    }

    private fun connect() {
        serviceScope.launch {
            try {
                updateState(VpnState.CONNECTING)

                // Start foreground service with notification
                val notification = createNotification("Connecting...")
                startForeground(NOTIFICATION_ID, notification)

                // Establish VPN interface
                val vpnFd = establishVpn()
                if (vpnFd == null) {
                    Log.e(TAG, "Failed to establish VPN interface")
                    throw Exception("Failed to establish VPN interface")
                }
                vpnInterface = vpnFd

                // Initialize and start tun2socks
                tun2SocksManager = Tun2SocksManager()

                val success = tun2SocksManager!!.start(
                    vpnInterface = vpnFd,
                    mtu = MTU,
                    socksHost = currentHost!!,
                    socksPort = currentPort,
                    username = currentUsername,
                    password = currentPassword,
                    enableDebugLogging = true,
                    blockHttp3 = blockHttp3
                )

                if (!success) {
                    throw Exception("Failed to start tun2socks")
                }

                updateState(VpnState.CONNECTED)
                updateNotification("Connected to $currentHost:$currentPort")
                Log.d(TAG, "VPN connected successfully to $currentHost:$currentPort")

            } catch (e: Exception) {
                Log.e(TAG, "Connection failed", e)
                updateState(VpnState.ERROR)
                cleanup()
            }
        }
    }

    /**
     * Adds routes that cover all IP addresses EXCEPT the given proxy IP.
     * This prevents a routing loop where tun2socks traffic to the proxy
     * would be tunneled back through the VPN.
     *
     * Algorithm: Recursively divide the IP space into halves, excluding
     * the half containing the proxy IP at each level until we have
     * routes that surround but don't include the proxy's /32.
     */
    private fun addRoutesExcludingProxy(builder: Builder, proxyHost: String) {
        try {
            val proxyIp = ipToLong(proxyHost)
            if (proxyIp == null) {
                // If it's not an IP address (hostname), just route everything
                // The hostname will be resolved to an IP that hopefully works
                Log.w(TAG, "Proxy host is not an IP address, using default route: $proxyHost")
                builder.addRoute(VPN_ROUTE, 0)
                return
            }

            // Generate routes that cover 0.0.0.0/0 except the proxy IP
            val routes = calculateExclusionRoutes(0L, 0, proxyIp)
            for ((address, prefix) in routes) {
                val ipStr = longToIp(address)
                Log.d(TAG, "Adding route: $ipStr/$prefix (excluding proxy $proxyHost)")
                builder.addRoute(ipStr, prefix)
            }
            Log.d(TAG, "Added ${routes.size} routes excluding proxy $proxyHost")
        } catch (e: Exception) {
            Log.e(TAG, "Error adding exclusion routes, falling back to default", e)
            builder.addRoute(VPN_ROUTE, 0)
        }
    }

    /**
     * Calculate routes that cover the given range except for the excluded IP.
     */
    private fun calculateExclusionRoutes(
        rangeStart: Long,
        prefixLength: Int,
        excludeIp: Long
    ): List<Pair<Long, Int>> {
        // At /32, this is the exact IP to exclude - don't add it
        if (prefixLength == 32) {
            return emptyList()
        }

        val rangeSize = 1L shl (32 - prefixLength)
        val rangeEnd = rangeStart + rangeSize - 1

        // If excluded IP is not in this range, include the whole range
        if (excludeIp < rangeStart || excludeIp > rangeEnd) {
            return listOf(Pair(rangeStart, prefixLength))
        }

        // Split into two halves and recurse
        val halfSize = rangeSize / 2
        val midpoint = rangeStart + halfSize

        val leftHalf = calculateExclusionRoutes(rangeStart, prefixLength + 1, excludeIp)
        val rightHalf = calculateExclusionRoutes(midpoint, prefixLength + 1, excludeIp)

        return leftHalf + rightHalf
    }

    private fun ipToLong(ip: String): Long? {
        return try {
            val parts = ip.split(".")
            if (parts.size != 4) return null
            var result = 0L
            for (part in parts) {
                val octet = part.toIntOrNull() ?: return null
                if (octet < 0 || octet > 255) return null
                result = (result shl 8) or octet.toLong()
            }
            result
        } catch (e: Exception) {
            null
        }
    }

    private fun longToIp(value: Long): String {
        return "${(value shr 24) and 0xFF}.${(value shr 16) and 0xFF}.${(value shr 8) and 0xFF}.${value and 0xFF}"
    }

    private fun establishVpn(): ParcelFileDescriptor? {
        return try {
            val builder = Builder()
                .setSession("Fluxzy Connect")
                .setMtu(MTU)
                .addAddress(VPN_ADDRESS, VPN_PREFIX_LENGTH)
                .addDnsServer(Tun2SocksManager.MAP_DNS_ADDRESS)  // MapDNS for hostname preservation

            // Add routes that exclude the SOCKS proxy server to prevent routing loop
            // tun2socks needs direct access to the proxy, not through the VPN tunnel
            addRoutesExcludingProxy(builder, currentHost!!)

            // Apply per-app filtering
            val appsToAllow = allowedApps
            if (!appsToAllow.isNullOrEmpty()) {
                // Whitelist mode: only specified apps use VPN
                Log.d(TAG, "Per-app VPN whitelist mode: ${appsToAllow.size} apps allowed")
                for (pkg in appsToAllow) {
                    try {
                        builder.addAllowedApplication(pkg)
                        Log.d(TAG, "  Allowed app: $pkg")
                    } catch (e: PackageManager.NameNotFoundException) {
                        Log.w(TAG, "  Package not found, skipping: $pkg")
                    }
                }
            } else {
                // No whitelist - exclude only own app (default behavior)
                try {
                    builder.addDisallowedApplication(packageName)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not exclude own package from VPN", e)
                }
            }

            builder.setBlocking(true)

            val vpnFd = builder.establish()
            if (vpnFd != null) {
                Log.d(TAG, "VPN interface established with fd=${vpnFd.fd}")
            } else {
                Log.e(TAG, "VPN interface is null - permission may not be granted")
            }

            vpnFd
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN interface", e)
            null
        }
    }

    fun disconnect() {
        serviceScope.launch {
            updateState(VpnState.DISCONNECTING)
            cleanup()
            updateState(VpnState.DISCONNECTED)

            // Stop foreground and self
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()

            Log.d(TAG, "VPN disconnected")
        }
    }

    private suspend fun cleanup() {
        try {
            // Stop tun2socks
            tun2SocksManager?.stop()
            tun2SocksManager = null

            // Close VPN interface
            vpnInterface?.close()
            vpnInterface = null

            Log.d(TAG, "Cleanup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }

    private fun updateState(state: VpnState) {
        currentState = state
        Log.d(TAG, "State changed to: ${state.value}")
        stateListener?.invoke(state)
    }

    fun getCurrentState(): VpnState = currentState

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Fluxzy Connect",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Fluxzy Connect")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_secure)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Fluxzy Connect")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_secure)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }

    private fun updateNotification(text: String) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager?.notify(NOTIFICATION_ID, createNotification(text))
    }

    override fun onRevoke() {
        Log.d(TAG, "VPN permission revoked")
        serviceScope.launch {
            cleanup()
            updateState(VpnState.DISCONNECTED)
        }
        super.onRevoke()
    }

    override fun onDestroy() {
        Log.d(TAG, "FluxzyVpnService destroyed")
        instance = null
        serviceScope.cancel()
        super.onDestroy()
    }
}
