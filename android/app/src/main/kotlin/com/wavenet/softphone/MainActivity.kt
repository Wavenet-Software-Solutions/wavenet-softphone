package com.wavenet.softphone

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
import android.content.BroadcastReceiver

class MainActivity : FlutterActivity() {

    private val CHANNEL = "wavenet/net"

    // --------------------------------------------------------
    // 🔥 FIX: Handle leaked DeviceOrientationManager receiver
    // --------------------------------------------------------
    private fun unregisterWebRtcOrientationReceiver() {
        val possibleClasses = listOf(
            "com.cloudwebrtc.webrtc.video.camera.DeviceOrientationManager",
            "com.cloudwebrtc.webrtc.video.camera.CameraUtils"
        )

        val possibleFields = listOf("receiver", "broadcastReceiver", "mReceiver")

        for (className in possibleClasses) {
            try {
                val clazz = Class.forName(className)
                for (fieldName in possibleFields) {
                    try {
                        val field = clazz.getDeclaredField(fieldName)
                        field.isAccessible = true

                        val receiver = field.get(null) as? BroadcastReceiver ?: continue
                        unregisterReceiver(receiver)
                        field.set(null, null)

                        println("💚 Unregistered WebRTC receiver from $className.$fieldName")
                        return
                    } catch (_: Exception) {}
                }
            } catch (_: Exception) {}
        }
    }


    override fun onPause() {
        super.onPause()
        unregisterWebRtcOrientationReceiver()
    }

    override fun onDestroy() {
        try {
            unregisterWebRtcOrientationReceiver()
        } catch (_: Exception) {}

        super.onDestroy()
        unregisterWebRtcOrientationReceiver()
    }



    private fun unregisterOrientationReceiverSafe() {
        try {
            val clazz = Class.forName("com.cloudwebrtc.webrtc.video.camera.DeviceOrientationManager")
            val field = clazz.getDeclaredField("receiver")
            field.isAccessible = true
            val receiver = field.get(null) as? BroadcastReceiver

            if (receiver != null) {
                try {
                    unregisterReceiver(receiver)
                } catch (_: Exception) {
                    // ignored: already unregistered
                }
            }
        } catch (_: Exception) {
            // ignored — field not found or plugin updated
        }
    }
    // --------------------------------------------------------


    // --------------------------------------------------------
    // 🌐 Your original Net Binding API stays untouched
    // --------------------------------------------------------
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindToWifi" -> {
                    val r = bindProcessToExistingWifi()
                    result.success(r)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindProcessToExistingWifi(): String {
        val cm = getSystemService(ConnectivityManager::class.java)

        val wifi: Network? = cm.allNetworks.firstOrNull { n ->
            cm.getNetworkCapabilities(n)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        } ?: return ""

        val ok = if (Build.VERSION.SDK_INT >= 23) {
            cm.bindProcessToNetwork(wifi)
        } else {
            @Suppress("DEPRECATION")
            ConnectivityManager.setProcessDefaultNetwork(wifi)
        }
        if (!ok) return ""

        return try {
            val ips = mutableListOf<String>()
            NetworkInterface.getNetworkInterfaces().toList().forEach { nif ->
                if (!nif.isUp || nif.isLoopback) return@forEach
                nif.inetAddresses.toList().forEach { ia ->
                    if (ia is Inet4Address && !ia.isLoopbackAddress) ips.add(ia.hostAddress)
                }
            }
            ips.firstOrNull {
                it.startsWith("192.168.") ||
                        it.startsWith("10.") ||
                        it.startsWith("172.16.")
            } ?: ""
        } catch (_: Throwable) { "" }
    }
}
