package io.fluxzy.mobile.connect.vpn

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import io.fluxzy.mobile.connect.vpn.models.ProxyHostData
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

class NsdDiscoveryManager(private val context: Context) {

    companion object {
        private const val TAG = "NsdDiscoveryManager"
        private const val SERVICE_TYPE = "_fluxzyproxy._tcp."
    }

    private val nsdManager: NsdManager by lazy {
        context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }

    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val discoveredHosts = mutableMapOf<String, ProxyHostData>()
    private val pendingResolutions = mutableSetOf<String>()

    fun discoverHosts(): Flow<List<ProxyHostData>> = callbackFlow {
        discoveredHosts.clear()
        pendingResolutions.clear()

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {
                Log.d(TAG, "Discovery started for $regType")
            }

            override fun onServiceFound(service: NsdServiceInfo) {
                Log.d(TAG, "Service found: ${service.serviceName}")
                val serviceKey = "${service.serviceName}:${service.serviceType}"

                if (!pendingResolutions.contains(serviceKey)) {
                    pendingResolutions.add(serviceKey)
                    resolveService(service) { proxyHost ->
                        pendingResolutions.remove(serviceKey)
                        proxyHost?.let {
                            val key = "${it.hostname}:${it.port}"
                            discoveredHosts[key] = it
                            trySend(discoveredHosts.values.toList())
                        }
                    }
                }
            }

            override fun onServiceLost(service: NsdServiceInfo) {
                Log.d(TAG, "Service lost: ${service.serviceName}")
                // Try to find and remove the lost service
                val keysToRemove = discoveredHosts.entries
                    .filter { it.value.hostName == service.serviceName }
                    .map { it.key }
                keysToRemove.forEach { discoveredHosts.remove(it) }

                if (keysToRemove.isNotEmpty()) {
                    trySend(discoveredHosts.values.toList())
                }
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "Discovery stopped for $serviceType")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
                close(Exception("Discovery start failed with error code: $errorCode"))
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery stop failed: $errorCode")
            }
        }

        try {
            nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start discovery", e)
            close(e)
        }

        awaitClose {
            stopDiscovery()
        }
    }

    private fun resolveService(service: NsdServiceInfo, callback: (ProxyHostData?) -> Unit) {
        val resolveListener = object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                Log.e(TAG, "Resolve failed for ${serviceInfo.serviceName}: $errorCode")
                callback(null)
            }

            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service resolved: ${serviceInfo.serviceName} at ${serviceInfo.host?.hostAddress}:${serviceInfo.port}")
                val proxyHost = parseServiceInfo(serviceInfo)
                callback(proxyHost)
            }
        }

        try {
            nsdManager.resolveService(service, resolveListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve service", e)
            callback(null)
        }
    }

    private fun parseServiceInfo(serviceInfo: NsdServiceInfo): ProxyHostData? {
        return try {
            val host = serviceInfo.host?.hostAddress ?: return null
            val port = serviceInfo.port

            // Parse TXT record attributes
            var txtData: String? = null

            // The TXT record should contain JSON data
            // Try different common attribute keys
            val attributes = serviceInfo.attributes
            for ((key, value) in attributes) {
                val valueStr = value?.toString(Charsets.UTF_8)
                Log.d(TAG, "TXT attribute: $key = $valueStr")

                // The entire JSON might be stored as a single attribute value
                // or under a specific key like "data", "json", or empty key
                if (key.isEmpty() || key == "data" || key == "json" || key == "txt") {
                    txtData = valueStr
                    break
                }

                // If the value looks like JSON, use it
                if (valueStr?.startsWith("{") == true) {
                    txtData = valueStr
                    break
                }
            }

            // If no specific key found, try to concatenate all values
            if (txtData == null && attributes.isNotEmpty()) {
                // Some mDNS implementations put the entire payload as a single attribute
                val firstEntry = attributes.entries.firstOrNull()
                if (firstEntry != null) {
                    val combinedValue = firstEntry.value?.toString(Charsets.UTF_8)
                    if (combinedValue?.contains("host") == true) {
                        txtData = combinedValue
                    }
                }
            }

            ProxyHostData.fromServiceInfo(
                resolvedHost = host,
                resolvedPort = port,
                serviceName = serviceInfo.serviceName,
                txtData = txtData
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse service info", e)
            null
        }
    }

    fun stopDiscovery() {
        discoveryListener?.let { listener ->
            try {
                nsdManager.stopServiceDiscovery(listener)
                Log.d(TAG, "Discovery stopped")
            } catch (e: IllegalArgumentException) {
                // Listener was not registered or already stopped
                Log.w(TAG, "Discovery already stopped or not started")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping discovery", e)
            }
            discoveryListener = null
        }
        discoveredHosts.clear()
        pendingResolutions.clear()
    }
}
