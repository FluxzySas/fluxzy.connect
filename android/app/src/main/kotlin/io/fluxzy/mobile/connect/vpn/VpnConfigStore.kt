package io.fluxzy.mobile.connect.vpn

import android.content.Context

/**
 * Persists the last connection parameters so the VPN can be re-established
 * when the system starts the service without an intent, which is what happens
 * with Always-on VPN after a reboot (or a START_STICKY restart).
 */
class VpnConfigStore(context: Context) {

    data class VpnConfig(
        val host: String,
        val port: Int,
        val username: String?,
        val password: String?,
        val allowedApps: List<String>?,
        val blockHttp3: Boolean
    )

    companion object {
        private const val PREFS_NAME = "fluxzy_vpn_last_config"
        private const val KEY_HOST = "host"
        private const val KEY_PORT = "port"
        private const val KEY_USERNAME = "username"
        private const val KEY_PASSWORD = "password"
        private const val KEY_ALLOWED_APPS = "allowed_apps"
        private const val KEY_BLOCK_HTTP3 = "block_http3"
    }

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(config: VpnConfig) {
        val editor = prefs.edit()
            .putString(KEY_HOST, config.host)
            .putInt(KEY_PORT, config.port)
            .putString(KEY_USERNAME, config.username)
            .putString(KEY_PASSWORD, config.password)
            .putBoolean(KEY_BLOCK_HTTP3, config.blockHttp3)
        if (config.allowedApps != null) {
            editor.putStringSet(KEY_ALLOWED_APPS, config.allowedApps.toSet())
        } else {
            editor.remove(KEY_ALLOWED_APPS)
        }
        editor.apply()
    }

    fun load(): VpnConfig? {
        val host = prefs.getString(KEY_HOST, null) ?: return null
        val port = prefs.getInt(KEY_PORT, 0)
        if (host.isBlank() || port <= 0) return null

        return VpnConfig(
            host = host,
            port = port,
            username = prefs.getString(KEY_USERNAME, null),
            password = prefs.getString(KEY_PASSWORD, null),
            allowedApps = prefs.getStringSet(KEY_ALLOWED_APPS, null)?.toList(),
            blockHttp3 = prefs.getBoolean(KEY_BLOCK_HTTP3, false)
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
