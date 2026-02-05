# HevSocks5Tunnel Android Library

A high-performance SOCKS5 tunnel (tun2socks) library for Android, packaged as an AAR with Kotlin API bindings. Designed for Flutter Android VPN applications.

## Overview

This library wraps the native [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) implementation, providing a clean Kotlin API for Android VPN services. It handles all traffic routing through a SOCKS5 proxy using a TUN interface.

### Key Features

- **IPv4/IPv6 dual-stack** support
- **TCP connection redirection** through SOCKS5
- **UDP packet redirection** (Fullcone NAT, UDP-in-UDP, UDP-in-TCP)
- **MapDNS (Fake-IP)** for hostname preservation
- **High performance** with low memory footprint
- **Simple Kotlin API** with thread-safe singleton

## Installation

### In Flutter Android Project

1. Copy `hev-socks5-tunnel-forked.aar` to `android/app/libs/`

2. Add to `android/app/build.gradle`:

```groovy
dependencies {
    implementation files('libs/hev-socks5-tunnel-forked.aar')
}
```

3. Ensure your `minSdkVersion` is at least 21.

## API Reference

### Package: `com.hev.socks5tunnel`

---

### `TunnelConfig`

Configuration data class for the tunnel. Passed to `HevSocks5Tunnel.start()`.

```kotlin
data class TunnelConfig(
    // Required: TUN interface file descriptor from VpnService.Builder.establish()
    val tunFd: Int,

    // TUN interface MTU (default: 8500)
    val mtu: Int = 8500,

    // Required: SOCKS5 proxy server address
    val socksAddress: String,

    // SOCKS5 proxy server port (default: 1080)
    val socksPort: Int = 1080,

    // Optional SOCKS5 authentication
    val socksUsername: String? = null,
    val socksPassword: String? = null,

    // UDP relay mode (default: UDP)
    val socksUdpMode: UdpMode = UdpMode.UDP,

    // MapDNS (Fake-IP) configuration
    val mapDnsEnabled: Boolean = true,
    val mapDnsAddress: String = "198.18.0.2",
    val mapDnsPort: Int = 53,
    val mapDnsNetwork: String = "240.0.0.0",
    val mapDnsNetmask: String = "240.0.0.0",
    val mapDnsCacheSize: Int = 10000,

    // Timeouts and logging
    val logLevel: LogLevel = LogLevel.WARN,
    val connectTimeoutMs: Int = 10000,
    val tcpReadWriteTimeoutMs: Int = 300000,
    val udpReadWriteTimeoutMs: Int = 60000
)
```

#### Enums

```kotlin
enum class UdpMode {
    TCP,  // UDP packets relayed over TCP connection
    UDP   // UDP packets relayed over native UDP (requires SOCKS5 UDP ASSOCIATE)
}

enum class LogLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR
}
```

---

### `TunnelStats`

Traffic statistics returned by `HevSocks5Tunnel.getStats()`.

```kotlin
data class TunnelStats(
    val uploadBytes: Long,      // Total bytes uploaded
    val downloadBytes: Long,    // Total bytes downloaded
    val activeConnections: Int  // Currently active connections
)
```

---

### `HevSocks5Tunnel`

Main tunnel controller singleton. Thread-safe.

```kotlin
object HevSocks5Tunnel {
    /**
     * Start the tunnel with given configuration.
     * Runs in a background thread.
     *
     * @param config Complete tunnel configuration
     * @throws TunnelException on failure
     */
    fun start(config: TunnelConfig)

    /**
     * Stop the running tunnel.
     * Safe to call multiple times or when not running.
     */
    fun stop()

    /**
     * @return true if tunnel is currently active
     */
    fun isRunning(): Boolean

    /**
     * @return Current traffic stats, or null if not running
     */
    fun getStats(): TunnelStats?

    /**
     * @return Library version string
     */
    fun getVersion(): String
}
```

---

### `TunnelException`

Exception thrown when tunnel operations fail.

```kotlin
class TunnelException(
    message: String,
    cause: Throwable? = null
) : Exception(message, cause)
```

---

## Usage Example

### Android VpnService Implementation

```kotlin
class MyVpnService : VpnService() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startVpn()
        return START_STICKY
    }

    private fun startVpn() {
        // 1. Build the VPN interface
        val builder = Builder()
            .setSession("My VPN")
            .setMtu(8500)
            .addAddress("198.18.0.1", 24)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("198.18.0.2")  // MapDNS address

        // Exclude the SOCKS5 proxy from the VPN
        builder.addDisallowedApplication("com.example.socksserver")

        val vpnInterface = builder.establish()
            ?: throw Exception("Failed to establish VPN")

        // 2. Configure the tunnel
        val config = TunnelConfig(
            tunFd = vpnInterface.fd,
            mtu = 8500,
            socksAddress = "127.0.0.1",
            socksPort = 1080,
            mapDnsEnabled = true,
            mapDnsAddress = "198.18.0.2",
            logLevel = TunnelConfig.LogLevel.WARN
        )

        // 3. Start the tunnel
        try {
            HevSocks5Tunnel.start(config)
        } catch (e: TunnelException) {
            Log.e("VPN", "Failed to start tunnel", e)
            stopSelf()
        }
    }

    override fun onDestroy() {
        HevSocks5Tunnel.stop()
        super.onDestroy()
    }
}
```

### Flutter Platform Channel Integration

```kotlin
// In your MainActivity or a MethodChannel handler
class VpnMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> {
                val socksAddress = call.argument<String>("socksAddress") ?: "127.0.0.1"
                val socksPort = call.argument<Int>("socksPort") ?: 1080

                // Start VpnService with configuration
                val intent = Intent(context, MyVpnService::class.java).apply {
                    putExtra("socksAddress", socksAddress)
                    putExtra("socksPort", socksPort)
                }
                context.startService(intent)
                result.success(true)
            }
            "stopVpn" -> {
                HevSocks5Tunnel.stop()
                result.success(true)
            }
            "getStats" -> {
                val stats = HevSocks5Tunnel.getStats()
                result.success(stats?.let {
                    mapOf(
                        "uploadBytes" to it.uploadBytes,
                        "downloadBytes" to it.downloadBytes
                    )
                })
            }
            "isRunning" -> {
                result.success(HevSocks5Tunnel.isRunning())
            }
            else -> result.notImplemented()
        }
    }
}
```

---

## MapDNS (Fake-IP) Explained

MapDNS is a critical feature for proper VPN operation. Here's how it works:

1. **DNS Queries**: When an app queries a hostname (e.g., `example.com`), the MapDNS intercepts it.

2. **Fake IP Assignment**: MapDNS assigns a fake IP from the configured range (default: `240.0.0.0/4`) and caches the hostname mapping.

3. **Connection Routing**: When the app connects to the fake IP, the tunnel looks up the original hostname and sends a SOCKS5 CONNECT request with the **hostname** (not IP).

4. **Why It Matters**: This ensures the SOCKS5 proxy can resolve DNS independently, which is essential for:
   - Proper DNS-based access control
   - Geolocation-aware services
   - SNI-based routing

### Configuration

```kotlin
TunnelConfig(
    // ...
    mapDnsEnabled = true,           // Enable MapDNS
    mapDnsAddress = "198.18.0.2",   // DNS server address (use this in VPN config)
    mapDnsPort = 53,                // DNS port
    mapDnsNetwork = "240.0.0.0",    // Fake IP range start
    mapDnsNetmask = "240.0.0.0",    // Fake IP range mask
    mapDnsCacheSize = 10000         // Max hostname mappings
)
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App                                                 │
│   └── Platform Channel (MethodChannel)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│ Kotlin API (HevSocks5Tunnel.kt)                             │
│   - TunnelConfig → YAML generation                          │
│   - Thread management                                       │
│   - Statistics retrieval                                    │
└─────────────────────┬───────────────────────────────────────┘
                      │ JNI
┌─────────────────────▼───────────────────────────────────────┐
│ Native Library (libhev-socks5-tunnel.so)                    │
│   - High-performance tun2socks implementation               │
│   - lwIP TCP/IP stack                                       │
│   - Coroutine-based async I/O                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│ Android VpnService                                          │
│   - TUN interface creation                                  │
│   - Route configuration                                     │
│   - File descriptor management                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Supported ABIs

| ABI | Description |
|-----|-------------|
| `arm64-v8a` | 64-bit ARM (modern devices) |
| `armeabi-v7a` | 32-bit ARM (legacy devices) |
| `x86_64` | 64-bit x86 (emulators) |

---

## Thread Safety

- `HevSocks5Tunnel` is a thread-safe singleton
- `start()` and `stop()` are synchronized
- `getStats()` and `isRunning()` can be called from any thread
- The native tunnel runs in its own background thread

---

## Error Handling

```kotlin
try {
    HevSocks5Tunnel.start(config)
} catch (e: TunnelException) {
    when {
        e.message?.contains("already running") == true -> {
            // Tunnel is already active
        }
        e.message?.contains("invalid config") == true -> {
            // Configuration error
        }
        else -> {
            // Other error - check cause
            Log.e("VPN", "Tunnel error", e)
        }
    }
}
```

---

## Technical Notes

### JNI Binding

This library uses **explicit JNI naming** for the `com.hev.socks5tunnel` package. The native library's `JNI_OnLoad` has been modified to make legacy class registration (`hev.htproxy.TProxyService`) non-fatal, preventing `ClassNotFoundException` crashes when the legacy class is not present.

If you're migrating from the upstream library that used `RegisterNatives` with a different package name, no changes are needed - the library handles both binding approaches gracefully.

---

## Changelog

### 2026-01-05
- **Fixed**: JNI `ClassNotFoundException` crash when loading native library
  - Made legacy `RegisterNatives` binding optional (clears exception if class not found)
  - New explicit JNI methods for `com.hev.socks5tunnel.HevSocks5Tunnel` work independently

---

## License

MIT License

Based on [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) by [hev](https://hev.cc).
