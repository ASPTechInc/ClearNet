package com.asptechinc.clearnet

import android.content.Intent
import android.net.VpnService
import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.text.TextUtils
import android.os.PowerManager
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.net.toUri

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
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "getInstalledApps" -> {
                    // Fetches lists of user-installed packages to display in the block options
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "isAccessibilityServiceEnabled" -> {
                    val enabled = isAccessibilityServiceEnabled(this, AppBlockService::class.java)
                    result.success(enabled)
                }
                "setAppDisguise" -> {
                    val disguise = call.argument<String>("disguise") ?: "none"
                    setAppDisguise(disguise)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "getBatteryStats" -> {
                    result.success(getBatteryStats())
                }
                "getStats" -> {
                    val stats = NativeStatsManager.getStats(this)
                    val map = mutableMapOf<String, Any>()
                    val keys = stats.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = stats.get(key)
                    }
                    result.success(map)
                }
                "goHome" -> {
                    val intent = Intent(Intent.ACTION_MAIN)
                    intent.addCategory(Intent.CATEGORY_HOME)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
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
     * 
     * Note: On Android 11+ (API 30+), this requires <queries> in the manifest
     * or the QUERY_ALL_PACKAGES permission to see apps other than the system ones.
     */
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        // Query for apps with a launcher activity, which respects the <queries> element in the manifest
        val apps = pm.queryIntentActivities(mainIntent, 0)
        val appList = mutableListOf<Map<String, String>>()

        for (info in apps) {
            val app = info.activityInfo.applicationInfo
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
        return appList.distinctBy { it["packageName"] }.sortedBy { it["name"] }
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

    /**
     * Checks if the specific Accessibility Service is currently enabled in system settings.
     */
    private fun isAccessibilityServiceEnabled(context: Context, service: Class<out AccessibilityService>): Boolean {
        val expectedComponentName = ComponentName(context, service)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)

        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }

    private fun setAppDisguise(disguise: String) {
        val pm = packageManager
        val pkgName = packageName
        
        val components = mapOf(
            "none" to ComponentName(pkgName, "$pkgName.MainActivity"),
            "calculator" to ComponentName(pkgName, "$pkgName.CalculatorActivity"),
            "notes" to ComponentName(pkgName, "$pkgName.NotesActivity")
        )

        components.forEach { (name, component) ->
            val state = if (name == disguise) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (!isIgnoringBatteryOptimizations()) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = "package:$packageName".toUri()
            }
            startActivity(intent)
        }
    }

    private fun getBatteryStats(): Map<String, Any> {
        val vpn = SafeVpnService.instance
        return mapOf(
            "isIgnoringOptimizations" to isIgnoringBatteryOptimizations(),
            "vpnActive" to (vpn != null),
            "uptimeMinutes" to (vpn?.getUptimeMinutes() ?: 0L),
            "packetsProcessed" to (vpn?.getPacketsProcessed() ?: 0L),
            "packetsBlocked" to (vpn?.getPacketsBlocked() ?: 0L)
        )
    }
}
