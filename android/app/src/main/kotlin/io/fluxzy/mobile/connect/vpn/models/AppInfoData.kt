package io.fluxzy.mobile.connect.vpn.models

/**
 * Data class representing an installed Android application for VPN filtering.
 */
data class AppInfoData(
    val packageName: String,
    val appName: String,
    val iconBase64: String?
) {
    /**
     * Converts this data class to a Map for Flutter platform channel communication.
     */
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "iconBase64" to iconBase64
        )
    }
}
