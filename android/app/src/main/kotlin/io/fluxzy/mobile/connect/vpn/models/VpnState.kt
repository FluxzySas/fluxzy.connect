package io.fluxzy.mobile.connect.vpn.models

enum class VpnState(val value: String) {
    DISCONNECTED("disconnected"),
    CONNECTING("connecting"),
    CONNECTED("connected"),
    DISCONNECTING("disconnecting"),
    ERROR("error");

    companion object {
        fun fromString(value: String): VpnState {
            return entries.find { it.value == value } ?: DISCONNECTED
        }
    }
}
