package com.asptechinc.clearnet

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity serves as the main entrance point to the application, extending FlutterActivity.
 * It establishes a MethodChannel to facilitate communication between the Kotlin native layer
 * and the Dart/Flutter presentation layer, routing actions such as VPN lifecycle management,
 * package inventory collection and system settings navigation.
 */
class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "app_control/channel"
    private var pendingShowBlocked = false

    /**
     * Set up native method handlers to receive calls from Flutter Dart side.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    // Check if system VPN permissions are granted; if not, triggers the system permission dialog
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivity(intent)
                    } else {
                        startService(Intent(this, SafeVpnService::class.java))
                    }
                    result.success(true)
                }
                "stopVpn" -> {
                    // Stops the background SafeVpnService instance
                    stopService(Intent(this, SafeVpnService::class.java))
                    result.success(true)
                }
                "blockSite" -> {
                    val site = call.argument<String>("site")
                    if (site != null) {
                        SafeVpnService.instance?.addBlockedSite(site)
                    }
                    result.success(true)
                }
                "removeSite" -> {
                    val site = call.argument<String>("site")
                    if (site != null) {
                        SafeVpnService.instance?.removeBlockedSite(site)
                    }
                    result.success(true)
                }
                "blockKeyword" -> {
                    val keyword = call.argument<String>("keyword")
                    if (keyword != null) {
                        SafeVpnService.instance?.addBlockedKeyword(keyword)
                    }
                    result.success(true)
                }
                "removeKeyword" -> {
                    val keyword = call.argument<String>("keyword")
                    if (keyword != null) {
                        SafeVpnService.instance?.removeBlockedKeyword(keyword)
                    }
                    result.success(true)
                }
                "checkInitialAction" -> {
                    // Invoked by Flutter on startup to check if the app was launched due to a block event
                    if (pendingShowBlocked) {
                        pendingShowBlocked = false
                        result.success("showBlocked")
                    } else {
                        result.success(null)
                    }
                }
                "openAccessibilitySettings" -> {
                    // Redirects the user directly to system accessibility service parameters
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "getInstalledApps" -> {
                    // Fetches lists of user-installed packages to display in the block options
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                else -> result.notImplemented()
            }
        }
        
        // Check if the current incoming intent signals showing a blocked screen page
        handleIntent(intent)
    }

    /**
     * Scans and compiles a sorted list of non-system packages installed on the device.
     * Exposes app labels and package identifiers to the Flutter settings UI.
     */
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(0)
        val appList = mutableListOf<Map<String, String>>()

        for (app in apps) {
            val name = pm.getApplicationLabel(app).toString()
            val packageName = app.packageName
            val isSystem = (app.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

            // Include all user-installed applications, plus specific safe-browsing targets like Chrome
            if (!isSystem || packageName == "com.android.chrome") {
                appList.add(mapOf(
                    "name" to name,
                    "packageName" to packageName
                ))
            }
        }
        return appList.sortedBy { it["name"] }
    }

    /**
     * Intercepts intents delivered to an already active instance of the activity.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    /**
     * Evaluates incoming intent bundles to invoke corresponding view routes on the Flutter frontend.
     */
    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra("showBlocked", false)) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL).invokeMethod("showBlockedPage", null)
            } ?: run {
                // Cache the block flag if the engine is not fully attached or initialised yet
                pendingShowBlocked = true
            }
        }
    }
}
