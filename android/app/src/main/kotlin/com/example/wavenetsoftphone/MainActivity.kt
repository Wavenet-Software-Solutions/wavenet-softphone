// android/app/src/main/kotlin/<your pkg>/MainActivity.kt
package com.example.wavenetsoftphone

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.net.Inet4Address


class MainActivity : FlutterActivity() {
    private val CHANNEL = "wavenet/net"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindToWifi" -> {
                    val r = bindProcessToExistingWifi()
                    result.success(r) // returns string like "192.168.1.100" or ""
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindProcessToExistingWifi(): String {
        val cm = getSystemService(ConnectivityManager::class.java)

        // Find an already-available Wi-Fi network
        val wifi: Network? = cm.allNetworks.firstOrNull { n ->
            cm.getNetworkCapabilities(n)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        } ?: return ""

        // Bind the whole process to Wi-Fi
        val ok = if (Build.VERSION.SDK_INT >= 23) {
            cm.bindProcessToNetwork(wifi)
        } else {
            @Suppress("DEPRECATION")
            ConnectivityManager.setProcessDefaultNetwork(wifi)
        }
        if (!ok) return ""

        // Optional: verify the bound local IPv4 we’ll use for sockets
        // (iterate interfaces and pick a 192.168.* / 10.* address on an up interface)
        return try {
            val ips = mutableListOf<String>()
            NetworkInterface.getNetworkInterfaces().toList().forEach { nif ->
                if (!nif.isUp || nif.isLoopback) return@forEach
                nif.inetAddresses.toList().forEach { ia ->
                    if (ia is Inet4Address && !ia.isLoopbackAddress) ips.add(ia.hostAddress)
                }
            }
            // Prefer RFC1918 local addresses; you can refine this selector if needed
            ips.firstOrNull { it.startsWith("192.168.") || it.startsWith("10.") || it.startsWith("172.16.") } ?: ""
        } catch (_: Throwable) {
            ""
        }
    }
}
