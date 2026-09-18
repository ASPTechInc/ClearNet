package com.asptechinc.appcontrol

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_control/channel"
    private var vpnService: SafeVpnService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) startActivity(intent)
                    else startService(Intent(this, SafeVpnService::class.java))
                    result.success(true)
                }
                "blockSite" -> {
                    val site = call.argument<String>("site")
                    if (site != null) {
                        vpnService?.addBlockedSite(site)
                    }
                    result.success(true)
                }
                "removeSite" -> {
                    val site = call.argument<String>("site")
                    if (site != null) {
                        vpnService?.removeBlockedSite(site)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
