// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.Manifest
import android.content.Intent
import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.os.Build
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
 * Hosts the Flutter UI and handles method-channel calls from Dart, such as
 * starting the VPN, listing installed apps and opening system settings.
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        const val EXTRA_VERIFY_UNINSTALL_PIN = "verifyUninstallPin"
    }

    private val CHANNEL = "app_control/channel"
    // Set when an intent arrives before Flutter is ready, until Flutter asks
    private var pendingAction: String? = null
    private val VPN_PERMISSION_REQUEST_CODE = 1002
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1003

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    // Ask for VPN permission first if it has not been granted. The
                    // VPN then starts in onActivityResult once it's allowed.
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
                    } else {
                        startService(Intent(this, SafeVpnService::class.java))
                        requestNotificationPermission()
                    }
                    result.success(true)
                }
                "stopVpn" -> {
                    startService(Intent(this, SafeVpnService::class.java).setAction(SafeVpnService.ACTION_STOP))
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
                  "addWhitelist" -> {
                    val whitelist = call.argument<String>("whitelist")
                    if (whitelist != null) {
                        SafeVpnService.instance?.addWhitelistedSite(whitelist)
                    }
                    result.success(true)
                }
                "removeWhitelist" -> {
                    val whitelist = call.argument<String>("whitelist")
                    if (whitelist != null) {
                        SafeVpnService.instance?.removeWhitelistedSite(whitelist)
                    }
                    result.success(true)
                }
                "checkInitialAction" -> {
                    // Flutter asks on startup whether the app was opened by a block
                    // event or a request to remove device admin access
                    result.success(pendingAction)
                    pendingAction = null
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "getInstalledApps" -> {
                    // Installed apps for the app-blocking screen
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
                "setUninstallProtection" -> {
                    UninstallGuard.setEnabled(this, call.argument<Boolean>("enabled") ?: false)
                    result.success(true)
                }
                "isDeviceAdminActive" -> {
                    result.success(UninstallGuard.isAdminActive(this))
                }
                "requestDeviceAdmin" -> {
                    // Android wo not uninstall an active device admin, so
                    // uninstall protection only works once this is allowed
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, UninstallGuard.adminComponent(this))
                        .putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, getString(R.string.device_admin_explanation))
                    startActivity(intent)
                    result.success(true)
                }
                "allowProtectedScreens" -> {
                    UninstallGuard.allowProtectedScreens()
                    result.success(true)
                }
                "closeApp" -> {
                    // Ends the activity and removes it from recents, so the next
                    // launch starts fresh (and asks for the app PIN if set)
                    finishAndRemoveTask()
                    result.success(true)
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
        
        handleIntent(intent)
    }

    /**
     * Returns installed non-system apps with a launcher icon, sorted by name.
     * On Android 11+ this relies on the <queries> element in the manifest.
     */
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        val apps = pm.queryIntentActivities(mainIntent, 0)
        val appList = mutableListOf<Map<String, String>>()

        for (info in apps) {
            val app = info.activityInfo.applicationInfo
            val name = pm.getApplicationLabel(app).toString()
            val packageName = app.packageName
            val isSystem = (app.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

            // Chrome is preinstalled on many devices, so allow it to be blocked too
            if (!isSystem || packageName == "com.android.chrome") {
                appList.add(mapOf(
                    "name" to name,
                    "packageName" to packageName
                ))
            }
        }
        return appList.distinctBy { it["packageName"] }.sortedBy { it["name"] }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST_CODE && resultCode == RESULT_OK) {
            startService(Intent(this, SafeVpnService::class.java))
            requestNotificationPermission()
        }
    }

    /**
     * Android 13+ needs permission for the warning shown when another VPN
     * turns off filtering. Asked after the VPN dialogue so the two do not overlap.
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST_CODE)
        }
    }

    /**
     * Shows the Flutter blocked page if the intent came from a block event.
     */
    private fun handleIntent(intent: Intent) {
        val (action, method) = when {
            intent.getBooleanExtra("showBlocked", false) -> "showBlocked" to "showBlockedPage"
            intent.getBooleanExtra(EXTRA_VERIFY_UNINSTALL_PIN, false) -> "verifyUninstallPin" to "showUninstallPin"
            else -> return
        }
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod(method, null)
        } ?: run {
            // Flutter is not ready yet, so remember this until it asks
            pendingAction = action
        }
    }

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

    private fun setAppDisguise(disguise: String) = AppDisguise.apply(this, disguise)

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
