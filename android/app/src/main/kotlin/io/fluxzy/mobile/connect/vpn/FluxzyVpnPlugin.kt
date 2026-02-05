package io.fluxzy.mobile.connect.vpn

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import io.fluxzy.mobile.connect.vpn.models.VpnState
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collectLatest

class FluxzyVpnPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "FluxzyVpnPlugin"
        private const val METHOD_CHANNEL = "io.fluxzy.mobile.connect/vpn"
        private const val DISCOVERY_EVENT_CHANNEL = "io.fluxzy.mobile.connect/vpn/discovery"
        private const val STATE_EVENT_CHANNEL = "io.fluxzy.mobile.connect/vpn/state"
        private const val VPN_PERMISSION_REQUEST_CODE = 1001
        private const val CERT_INSTALL_REQUEST_CODE = CertificateTrustManager.CERT_INSTALL_REQUEST_CODE
    }

    private var methodChannel: MethodChannel? = null
    private var discoveryEventChannel: EventChannel? = null
    private var stateEventChannel: EventChannel? = null

    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var nsdDiscoveryManager: NsdDiscoveryManager? = null
    private var certificateDownloader: CertificateDownloader? = null
    private var certificateTrustManager: CertificateTrustManager? = null
    private var installedAppsManager: InstalledAppsManager? = null

    private val pluginScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var discoveryJob: Job? = null

    private var currentState = VpnState.DISCONNECTED
    private var stateEventSink: EventChannel.EventSink? = null
    private var pendingConnection: PendingConnection? = null
    private var pendingCertInstall: MethodChannel.Result? = null

    private data class PendingConnection(
        val host: String,
        val port: Int,
        val username: String?,
        val password: String?,
        val allowedApps: List<String>?,
        val blockHttp3: Boolean,
        val result: MethodChannel.Result
    )

    // ========== FlutterPlugin Lifecycle ==========

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine")
        context = binding.applicationContext

        // Set up method channel
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)

        // Set up event channels
        discoveryEventChannel = EventChannel(binding.binaryMessenger, DISCOVERY_EVENT_CHANNEL)
        discoveryEventChannel?.setStreamHandler(DiscoveryStreamHandler())

        stateEventChannel = EventChannel(binding.binaryMessenger, STATE_EVENT_CHANNEL)
        stateEventChannel?.setStreamHandler(StateStreamHandler())

        // Initialize managers
        nsdDiscoveryManager = NsdDiscoveryManager(binding.applicationContext)
        certificateDownloader = CertificateDownloader(binding.applicationContext)
        certificateTrustManager = CertificateTrustManager(binding.applicationContext)
        installedAppsManager = InstalledAppsManager(binding.applicationContext)

        // Set up VPN state listener
        FluxzyVpnService.stateListener = { state ->
            currentState = state
            pluginScope.launch(Dispatchers.Main) {
                stateEventSink?.success(state.value)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine")

        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        discoveryEventChannel?.setStreamHandler(null)
        discoveryEventChannel = null

        stateEventChannel?.setStreamHandler(null)
        stateEventChannel = null

        pluginScope.cancel()
        nsdDiscoveryManager?.stopDiscovery()
        FluxzyVpnService.stateListener = null
        context = null
    }

    // ========== ActivityAware Lifecycle ==========

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity")
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    // ========== MethodChannel Handler ==========

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")

        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getState" -> result.success(currentState.value)
            "downloadCertificate" -> handleDownloadCertificate(call, result)
            "prepareVpn" -> handlePrepareVpn(result)
            "checkCertificateTrust" -> handleCheckCertificateTrust(call, result)
            "installCertificate" -> handleInstallCertificate(call, result)
            "saveCertificateToDownloads" -> handleSaveCertificateToDownloads(call, result)
            "getInstalledApps" -> handleGetInstalledApps(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("hostname")
        val port = call.argument<Int>("port")
        val username = call.argument<String>("username")
        val password = call.argument<String>("password")
        @Suppress("UNCHECKED_CAST")
        val allowedApps = call.argument<List<String>>("allowedApps")
        val blockHttp3 = call.argument<Boolean>("blockHttp3") ?: false

        if (host.isNullOrBlank() || port == null || port <= 0) {
            result.error("INVALID_ARGS", "hostname and port are required", null)
            return
        }

        // Check if VPN permission is needed
        val prepareIntent = VpnService.prepare(context)
        if (prepareIntent != null) {
            // Need to request permission
            pendingConnection = PendingConnection(host, port, username, password, allowedApps, blockHttp3, result)
            activity?.startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
        } else {
            // Permission already granted
            startVpnService(host, port, username, password, allowedApps, blockHttp3)
            result.success(true)
        }
    }

    private fun startVpnService(
        host: String,
        port: Int,
        username: String?,
        password: String?,
        allowedApps: List<String>? = null,
        blockHttp3: Boolean = false
    ) {
        val intent = Intent(context, FluxzyVpnService::class.java).apply {
            action = FluxzyVpnService.ACTION_CONNECT
            putExtra(FluxzyVpnService.EXTRA_HOST, host)
            putExtra(FluxzyVpnService.EXTRA_PORT, port)
            username?.let { putExtra(FluxzyVpnService.EXTRA_USERNAME, it) }
            password?.let { putExtra(FluxzyVpnService.EXTRA_PASSWORD, it) }
            allowedApps?.let { putStringArrayListExtra(FluxzyVpnService.EXTRA_ALLOWED_APPS, ArrayList(it)) }
            putExtra(FluxzyVpnService.EXTRA_BLOCK_HTTP3, blockHttp3)
        }
        context?.startService(intent)
        Log.d(TAG, "VPN service started with host=$host, port=$port, allowedApps=${allowedApps?.size ?: 0}, blockHttp3=$blockHttp3")
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        val intent = Intent(context, FluxzyVpnService::class.java).apply {
            action = FluxzyVpnService.ACTION_DISCONNECT
        }
        context?.startService(intent)
        result.success(true)
        Log.d(TAG, "Disconnect request sent")
    }

    private fun handlePrepareVpn(result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(context)
        if (prepareIntent != null) {
            activity?.startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
            result.success(false) // Permission not yet granted
        } else {
            result.success(true) // Permission already granted
        }
    }

    private fun handleDownloadCertificate(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("hostname")
        val port = call.argument<Int>("port")
        val certEndpoint = call.argument<String>("certEndpoint")

        if (host.isNullOrBlank() || port == null || certEndpoint.isNullOrBlank()) {
            result.error("INVALID_ARGS", "hostname, port, and certEndpoint are required", null)
            return
        }

        pluginScope.launch {
            try {
                val path = certificateDownloader?.downloadCertificate(host, port, certEndpoint)
                if (path != null) {
                    result.success(path)
                } else {
                    result.error("DOWNLOAD_FAILED", "Failed to download certificate", null)
                }
            } catch (e: Exception) {
                result.error("DOWNLOAD_ERROR", e.message, null)
            }
        }
    }

    private fun handleCheckCertificateTrust(call: MethodCall, result: MethodChannel.Result) {
        val fingerprint = call.argument<String>("fingerprint")

        if (fingerprint.isNullOrBlank()) {
            result.error("INVALID_ARGS", "fingerprint is required", null)
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val isTrusted = certificateTrustManager?.isCertificateTrusted(fingerprint) ?: false
                withContext(Dispatchers.Main) {
                    result.success(isTrusted)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("CHECK_TRUST_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleInstallCertificate(call: MethodCall, result: MethodChannel.Result) {
        val certPem = call.argument<String>("certPem")
        val certName = call.argument<String>("certName") ?: "Fluxzy CA"

        if (certPem.isNullOrBlank()) {
            result.error("INVALID_ARGS", "certPem is required", null)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available for certificate installation", null)
            return
        }

        val trustManager = certificateTrustManager
        if (trustManager == null) {
            result.error("NOT_INITIALIZED", "Certificate trust manager not initialized", null)
            return
        }

        // Store the pending result to return after activity result
        pendingCertInstall = result

        val launched = trustManager.requestInstallCertificate(currentActivity, certPem, certName)
        if (!launched) {
            pendingCertInstall = null
            result.error("INSTALL_FAILED", "Failed to launch certificate installation", null)
        }
        // Result will be returned in onActivityResult
    }

    private fun handleSaveCertificateToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val certPem = call.argument<String>("certPem")
        val fileName = call.argument<String>("fileName") ?: "certificate.crt"

        if (certPem.isNullOrBlank()) {
            result.error("INVALID_ARGS", "certPem is required", null)
            return
        }

        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        pluginScope.launch(Dispatchers.IO) {
            try {
                val savedPath = saveCertificateToDownloads(ctx, certPem, fileName)
                withContext(Dispatchers.Main) {
                    result.success(savedPath)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save certificate", e)
                withContext(Dispatchers.Main) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun saveCertificateToDownloads(context: Context, certPem: String, fileName: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ use MediaStore
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/x-x509-ca-cert")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create file in Downloads")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(certPem.toByteArray())
            } ?: throw Exception("Failed to open output stream")

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            "Downloads/$fileName"
        } else {
            // Android 9 and below - write directly to Downloads folder
            @Suppress("DEPRECATION")
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }

            val file = File(downloadsDir, fileName)
            FileOutputStream(file).use { outputStream ->
                outputStream.write(certPem.toByteArray())
            }

            file.absolutePath
        }
    }

    private fun handleGetInstalledApps(call: MethodCall, result: MethodChannel.Result) {
        val includeSystemApps = call.argument<Boolean>("includeSystemApps") ?: false

        pluginScope.launch {
            try {
                val apps = installedAppsManager?.getInstalledApps(includeSystemApps) ?: emptyList()
                val appMaps = apps.map { it.toMap() }
                withContext(Dispatchers.Main) {
                    result.success(appMaps)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get installed apps", e)
                withContext(Dispatchers.Main) {
                    result.error("GET_APPS_ERROR", e.message, null)
                }
            }
        }
    }

    // ========== Activity Result Handler ==========

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val pending = pendingConnection
            pendingConnection = null

            if (resultCode == Activity.RESULT_OK && pending != null) {
                startVpnService(pending.host, pending.port, pending.username, pending.password, pending.allowedApps, pending.blockHttp3)
                pending.result.success(true)
                Log.d(TAG, "VPN permission granted")
            } else {
                pending?.result?.error("PERMISSION_DENIED", "VPN permission denied", null)
                Log.d(TAG, "VPN permission denied")
            }
            return true
        }

        if (requestCode == CERT_INSTALL_REQUEST_CODE) {
            val pending = pendingCertInstall
            pendingCertInstall = null

            // Note: Android doesn't provide a definitive result for certificate installation.
            // RESULT_OK means the user went through the flow, but may have cancelled.
            // We return true to indicate the flow completed, and the caller should
            // re-check trust status to confirm installation.
            if (resultCode == Activity.RESULT_OK) {
                pending?.success(true)
                Log.d(TAG, "Certificate install flow completed")
            } else {
                pending?.success(false)
                Log.d(TAG, "Certificate install cancelled or failed")
            }
            return true
        }

        return false
    }

    // ========== Event Stream Handlers ==========

    inner class DiscoveryStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            Log.d(TAG, "Discovery stream: onListen")
            eventSink = events
            startDiscovery()
        }

        override fun onCancel(arguments: Any?) {
            Log.d(TAG, "Discovery stream: onCancel")
            stopDiscovery()
            eventSink = null
        }

        private fun startDiscovery() {
            discoveryJob?.cancel()
            discoveryJob = pluginScope.launch {
                try {
                    nsdDiscoveryManager?.discoverHosts()?.collectLatest { hosts ->
                        val hostMaps = hosts.map { it.toMap() }
                        withContext(Dispatchers.Main) {
                            eventSink?.success(hostMaps)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Discovery error", e)
                    withContext(Dispatchers.Main) {
                        eventSink?.error("DISCOVERY_ERROR", e.message, null)
                    }
                }
            }
        }

        private fun stopDiscovery() {
            discoveryJob?.cancel()
            discoveryJob = null
            nsdDiscoveryManager?.stopDiscovery()
        }
    }

    inner class StateStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            Log.d(TAG, "State stream: onListen")
            stateEventSink = events
            // Send current state immediately
            events?.success(currentState.value)

            // Also check if VPN service is running and get its state
            FluxzyVpnService.instance?.let {
                val serviceState = it.getCurrentState()
                if (serviceState != currentState) {
                    currentState = serviceState
                    events?.success(serviceState.value)
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            Log.d(TAG, "State stream: onCancel")
            stateEventSink = null
        }
    }
}
