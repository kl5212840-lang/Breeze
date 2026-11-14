package com.zephyr.breeze

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URI

/** Respect the active route rather than bypassing a VPN via an underlying Wi-Fi network. */
internal fun androidDownloadWifiNetwork(connectivity: ConnectivityManager?): Network? {
    val network = connectivity?.activeNetwork ?: return null
    val capabilities = connectivity.getNetworkCapabilities(network) ?: return null
    return network.takeIf {
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
            !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
            !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) &&
            !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }
}

/** TLS remains end-to-end to the media server through an unauthenticated HTTP CONNECT proxy. */
internal fun androidVideoProxy(raw: Any?): Proxy? {
    val value = (raw as? String)?.takeIf { it.length in 1..2048 } ?: return null
    val uri = try {
        URI(value)
    } catch (_: java.net.URISyntaxException) {
        return null
    }
    val host = uri.host?.removeSurrounding("[", "]")?.takeIf { it.isNotEmpty() && '%' !in it } ?: return null
    val port = if (uri.port == -1) 80 else uri.port
    if (uri.scheme != "http" || uri.rawUserInfo != null || uri.rawQuery != null || uri.rawFragment != null ||
        uri.rawPath !in setOf("", "/") || port !in 1..65535) return null
    // Defer proxy DNS to the actual connection, including the chosen Wi-Fi network.
    return Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved(host, port))
}

internal fun androidVideoDownloadConnection(
    connectivity: ConnectivityManager?,
    wifiOnly: Boolean,
    proxy: Proxy?,
    wifiLost: () -> Nothing,
): ((URI) -> HttpURLConnection)? {
    if (!wifiOnly) return { uri ->
        val url = uri.toURL()
        (if (proxy == null) url.openConnection() else url.openConnection(proxy)) as HttpURLConnection
    }
    val network = androidDownloadWifiNetwork(connectivity) ?: return null
    return { uri ->
        if (androidDownloadWifiNetwork(connectivity) != network) wifiLost()
        val url = uri.toURL()
        (if (proxy == null) network.openConnection(url) else network.openConnection(url, proxy)) as HttpURLConnection
    }
}
