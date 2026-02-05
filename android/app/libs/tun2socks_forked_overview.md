# tun2socks Android AAR Library

This document provides API documentation for the tun2socks Android AAR library, which enables redirecting Android VPN traffic through a SOCKS5 proxy.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [API Reference](#api-reference)
- [Android VpnService Integration](#android-vpnservice-integration)
- [Kotlin Example](#kotlin-example)
- [Java Example](#java-example)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## Overview

The tun2socks mobile library provides a simple API for:
- Redirecting all VPN traffic through a SOCKS5 proxy
- Optional SOCKS5 authentication support
- Traffic statistics monitoring
- Configurable MTU, timeouts, and logging

## Installation

### Building the AAR

```powershell
# Run the build script
.\build_aar.ps1

# Or with custom options
.\build_aar.ps1 -OutputDir "build" -OutputName "mytun2socks" -Architectures "arm64,arm"
```

### Adding to Android Project

1. Copy `tun2socks_forked.aar` to your `app/libs/` directory

2. Add to `app/build.gradle`:

```groovy
dependencies {
    implementation files('libs/tun2socks_forked.aar')
}
```

3. Add Internet permission to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## API Reference

### Package: `mobile`

When imported in Android, the package is available as `mobile.Mobile` (Kotlin) or `mobile.Mobile` (Java).

---

### Functions

#### `startTunnel(tunFd: Long, socksAddr: String): Unit`

Starts the tun2socks tunnel with minimal configuration.

| Parameter | Type | Description |
|-----------|------|-------------|
| `tunFd` | `Long` | TUN file descriptor from `VpnService.Builder.establish()` |
| `socksAddr` | `String` | SOCKS5 proxy address in format `"host:port"` |

**Throws:** `Exception` if tunnel fails to start

```kotlin
val fd = vpnInterface.fileDescriptor.int.toLong()
Mobile.startTunnel(fd, "127.0.0.1:1080")
```

---

#### `startTunnelWithAuth(tunFd: Long, socksAddr: String, user: String, pass: String): Unit`

Starts the tunnel with SOCKS5 authentication.

| Parameter | Type | Description |
|-----------|------|-------------|
| `tunFd` | `Long` | TUN file descriptor |
| `socksAddr` | `String` | SOCKS5 proxy address `"host:port"` |
| `user` | `String` | SOCKS5 username |
| `pass` | `String` | SOCKS5 password |

```kotlin
Mobile.startTunnelWithAuth(fd, "proxy.example.com:1080", "myuser", "mypassword")
```

---

#### `startTunnelWithConfig(config: TunnelConfig): Unit`

Starts the tunnel with full configuration options.

| Parameter | Type | Description |
|-----------|------|-------------|
| `config` | `TunnelConfig` | Configuration object |

```kotlin
val config = Mobile.newTunnelConfig()
config.setTunFd(fd)
config.setSocksAddr("proxy.example.com:1080")
config.setMtu(1400)
config.setLogLevel("debug")
Mobile.startTunnelWithConfig(config)
```

---

#### `stopTunnel(): Unit`

Stops the running tunnel. Safe to call multiple times.

```kotlin
Mobile.stopTunnel()
```

---

#### `isRunning(): Boolean`

Returns `true` if the tunnel is currently running.

```kotlin
if (Mobile.isRunning()) {
    // Tunnel is active
}
```

---

#### `getStats(): Stats?`

Returns current traffic statistics, or `null` if tunnel is not running.

```kotlin
val stats = Mobile.getStats()
if (stats != null) {
    Log.d("Stats", "Upload: ${stats.uploadBytes} bytes")
    Log.d("Stats", "Download: ${stats.downloadBytes} bytes")
    Log.d("Stats", "Speed: ${stats.uploadSpeed}/${stats.downloadSpeed} B/s")
    Log.d("Stats", "Active connections: ${stats.activeConnections}")
}
```

---

#### `resetStats(): Unit`

Resets traffic statistics to zero.

```kotlin
Mobile.resetStats()
```

---

#### `setLogLevel(level: String): Unit`

Changes the log level at runtime.

| Level | Description |
|-------|-------------|
| `"debug"` | Verbose debugging output |
| `"info"` | Informational messages |
| `"warn"` | Warnings only |
| `"error"` | Errors only |
| `"silent"` | No logging |

```kotlin
Mobile.setLogLevel("debug")
```

---

#### `getVersion(): String`

Returns the library version string.

```kotlin
val version = Mobile.getVersion() // "2.0.0-mobile"
```

---

#### `getGoVersion(): String`

Returns the Go runtime version used to build the library.

```kotlin
val goVersion = Mobile.getGoVersion() // "go1.21.5"
```

---

#### `getPlatform(): String`

Returns the platform string.

```kotlin
val platform = Mobile.getPlatform() // "android/arm64"
```

---

### Types

#### `TunnelConfig`

Configuration object for advanced tunnel setup. Properties can be set directly or via auto-generated setters.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `tunFd` | `Long` | `0` | TUN file descriptor |
| `socksAddr` | `String` | `""` | SOCKS5 proxy address |
| `socksUser` | `String` | `""` | SOCKS5 username |
| `socksPass` | `String` | `""` | SOCKS5 password |
| `mtu` | `Long` | `1500` | Maximum transmission unit |
| `logLevel` | `String` | `"info"` | Log level |
| `udpTimeoutSec` | `Long` | `30` | UDP session timeout (seconds) |
| `restAPIAddr` | `String` | `""` | REST API address for stats (optional) |

**Auto-generated setters/getters for each property:**
- `setTunFd(v: Long)` / `getTunFd(): Long`
- `setSocksAddr(v: String)` / `getSocksAddr(): String`
- `setSocksUser(v: String)` / `getSocksUser(): String`
- `setSocksPass(v: String)` / `getSocksPass(): String`
- `setMtu(v: Long)` / `getMtu(): Long`
- `setLogLevel(v: String)` / `getLogLevel(): String`
- `setUdpTimeoutSec(v: Long)` / `getUdpTimeoutSec(): Long`
- `setRestAPIAddr(v: String)` / `getRestAPIAddr(): String`

**Convenience method:**
- `configureSocksAuth(user: String, pass: String)` - Set both username and password

---

#### `Stats`

Traffic statistics object.

| Property | Type | Description |
|----------|------|-------------|
| `uploadBytes` | `Long` | Total bytes uploaded |
| `downloadBytes` | `Long` | Total bytes downloaded |
| `uploadSpeed` | `Long` | Current upload speed (bytes/sec) |
| `downloadSpeed` | `Long` | Current download speed (bytes/sec) |
| `activeConnections` | `Long` | Number of active connections |

---

## Android VpnService Integration

### Initialization Sequence

```
1. User triggers VPN connection
2. VpnService.onStartCommand() called
3. Configure VPN with VpnService.Builder
4. Call builder.establish() to get ParcelFileDescriptor
5. Extract file descriptor: vpnInterface.fileDescriptor.int
6. Call Mobile.startTunnel(fd, socksAddr)
7. VPN traffic now routes through SOCKS5 proxy
```

### Required Permissions

```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

    <application>
        <service
            android:name=".MyVpnService"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

---

## Kotlin Example

Complete VpnService implementation:

```kotlin
package com.example.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import mobile.Mobile

class MyVpnService : VpnService() {

    companion object {
        private const val TAG = "MyVpnService"
        private const val CHANNEL_ID = "vpn_channel"
        private const val NOTIFICATION_ID = 1

        const val ACTION_START = "com.example.vpn.START"
        const val ACTION_STOP = "com.example.vpn.STOP"
        const val EXTRA_SOCKS_ADDR = "socks_addr"
        const val EXTRA_SOCKS_USER = "socks_user"
        const val EXTRA_SOCKS_PASS = "socks_pass"
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val socksAddr = intent.getStringExtra(EXTRA_SOCKS_ADDR) ?: "127.0.0.1:1080"
                val socksUser = intent.getStringExtra(EXTRA_SOCKS_USER)
                val socksPass = intent.getStringExtra(EXTRA_SOCKS_PASS)
                startVpn(socksAddr, socksUser, socksPass)
            }
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    private fun startVpn(socksAddr: String, user: String?, pass: String?) {
        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification())

        try {
            // Configure VPN
            val builder = Builder()
                .setSession("tun2socks")
                .setMtu(1500)
                .addAddress("10.0.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                // Exclude the proxy server from VPN to prevent loops
                .addDisallowedApplication(packageName)

            // Establish VPN
            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface")
                stopSelf()
                return
            }

            val fd = vpnInterface!!.fileDescriptor.int.toLong()
            Log.i(TAG, "VPN interface established with fd=$fd")

            // Configure tun2socks
            val config = Mobile.newTunnelConfig()
            config.setTunFd(fd)
            config.setSocksAddr(socksAddr)
            config.setMtu(1500)
            config.setLogLevel("info")
            config.setUdpTimeoutSec(60)

            if (!user.isNullOrEmpty() && !pass.isNullOrEmpty()) {
                config.configureSocksAuth(user, pass)
            }

            // Start tunnel
            Mobile.startTunnelWithConfig(config)
            Log.i(TAG, "tun2socks tunnel started")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN: ${e.message}", e)
            stopVpn()
        }
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN...")

        // Stop tun2socks
        Mobile.stopTunnel()

        // Close VPN interface
        vpnInterface?.close()
        vpnInterface = null

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val stopIntent = Intent(this, MyVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("VPN Connected")
            .setContentText("Routing traffic through SOCKS5 proxy")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()
    }
}
```

### Starting the VPN from an Activity:

```kotlin
class MainActivity : AppCompatActivity() {

    private val vpnPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            startVpnService()
        }
    }

    fun connectVpn() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            vpnPermissionLauncher.launch(intent)
        } else {
            startVpnService()
        }
    }

    private fun startVpnService() {
        val intent = Intent(this, MyVpnService::class.java).apply {
            action = MyVpnService.ACTION_START
            putExtra(MyVpnService.EXTRA_SOCKS_ADDR, "proxy.example.com:1080")
            putExtra(MyVpnService.EXTRA_SOCKS_USER, "username")
            putExtra(MyVpnService.EXTRA_SOCKS_PASS, "password")
        }
        startForegroundService(intent)
    }

    fun disconnectVpn() {
        val intent = Intent(this, MyVpnService::class.java).apply {
            action = MyVpnService.ACTION_STOP
        }
        startService(intent)
    }
}
```

---

## Java Example

```java
package com.example.vpn;

import android.net.VpnService;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import mobile.Mobile;
import mobile.TunnelConfig;
import mobile.Stats;

public class MyVpnService extends VpnService {

    private static final String TAG = "MyVpnService";
    private ParcelFileDescriptor vpnInterface;

    public void startVpn(String socksAddr, String user, String pass) {
        try {
            // Configure and establish VPN
            Builder builder = new Builder()
                .setSession("tun2socks")
                .setMtu(1500)
                .addAddress("10.0.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8");

            vpnInterface = builder.establish();
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN");
                return;
            }

            int fd = vpnInterface.getFd();

            // Configure tun2socks
            TunnelConfig config = Mobile.newTunnelConfig();
            config.setTunFd(fd);
            config.setSocksAddr(socksAddr);
            config.setMTU(1500);
            config.setLogLevel("info");

            if (user != null && pass != null) {
                config.setSocksAuth(user, pass);
            }

            // Start tunnel
            Mobile.startTunnelWithConfig(config);
            Log.i(TAG, "VPN started successfully");

        } catch (Exception e) {
            Log.e(TAG, "Failed to start VPN", e);
        }
    }

    public void stopVpn() {
        Mobile.stopTunnel();

        if (vpnInterface != null) {
            try {
                vpnInterface.close();
            } catch (Exception e) {
                Log.e(TAG, "Error closing VPN interface", e);
            }
            vpnInterface = null;
        }
    }

    public void logStats() {
        Stats stats = Mobile.getStats();
        if (stats != null) {
            Log.d(TAG, String.format(
                "Upload: %d bytes, Download: %d bytes, Connections: %d",
                stats.getUploadBytes(),
                stats.getDownloadBytes(),
                stats.getActiveConnections()
            ));
        }
    }
}
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "tunnel is already running" | `startTunnel` called twice | Call `stopTunnel` first |
| "invalid TUN file descriptor" | Invalid fd value | Ensure `establish()` succeeded |
| "SOCKS5 address is required" | Empty socksAddr | Provide valid proxy address |
| "invalid configuration" | Missing required fields | Check all required config fields |
| Connection refused | Proxy server not running | Verify proxy server is accessible |

### Exception Handling

```kotlin
try {
    Mobile.startTunnel(fd, socksAddr)
} catch (e: Exception) {
    when {
        e.message?.contains("already running") == true -> {
            // Tunnel already active, stop first
            Mobile.stopTunnel()
            Mobile.startTunnel(fd, socksAddr)
        }
        e.message?.contains("invalid") == true -> {
            // Configuration error
            Log.e(TAG, "Invalid configuration: ${e.message}")
        }
        else -> {
            Log.e(TAG, "Failed to start tunnel: ${e.message}")
        }
    }
}
```

---

## Best Practices

1. **Always call `stopTunnel()` in `onDestroy()`** to ensure proper cleanup

2. **Close the VPN interface after stopping the tunnel**, not before

3. **Exclude your app from VPN routing** to prevent loops if your app needs to connect to the proxy directly:
   ```kotlin
   builder.addDisallowedApplication(packageName)
   ```

4. **Use foreground service** for reliable VPN operation on Android 8+

5. **Handle VPN revocation** by overriding `onRevoke()`:
   ```kotlin
   override fun onRevoke() {
       stopVpn()
       super.onRevoke()
   }
   ```

6. **Monitor statistics** periodically for debugging:
   ```kotlin
   val handler = Handler(Looper.getMainLooper())
   handler.postDelayed(object : Runnable {
       override fun run() {
           Mobile.getStats()?.let { stats ->
               Log.d(TAG, "Speed: ${stats.uploadSpeed}/${stats.downloadSpeed} B/s")
           }
           handler.postDelayed(this, 1000)
       }
   }, 1000)
   ```

7. **Set appropriate log level** in production:
   ```kotlin
   Mobile.setLogLevel("warn") // Reduce log verbosity in release builds
   ```
