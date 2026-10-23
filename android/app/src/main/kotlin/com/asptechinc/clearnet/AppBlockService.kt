// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * Accessibility service that closes blocked apps and, in supported browsers,
 * checks the text on screen against the blocked domains and keywords.
 */
class AppBlockService : AccessibilityService() {

    // Used until the first window change loads the saved lists
    private var blockedKeywords = mutableSetOf("porn", "sex", "xxx", "adult", "gamble", "casino")
    private var blockedSites = mutableSetOf<String>()
    private var whitelistedSites = mutableSetOf<String>()

    companion object {
        const val TAG = "AppBlockService"
        
        // Browsers whose on-screen text is checked
        val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
            "com.microsoft.emmx",
            "com.duckduckgo.mobile.android"
        )
    }

    // When the user was last sent away from a protected screen
    private var lastGuardRedirect = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        val packageName = event.packageName?.toString() ?: ""

        // Runs even while blocking is paused, so pausing can't be used to remove ClearNet
        if (guardProtectedScreens(eventType, packageName)) return

        // Settings saved by the Flutter app. Reading them on every event is
        // how changes made in the app are picked up.
        val data = DataStoreReader.readData(this)
        if (!data.isBlockingEnabled) return

        // Block apps
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (isSystemPackage(packageName)) return

            Log.d(TAG, "Foreground app changed to: $packageName")
            
            // Pick up any list changes made in the app
            this.blockedSites = data.blockedSites.toMutableSet()
            this.blockedKeywords = data.blockedKeywords.toMutableSet()
            this.whitelistedSites = data.whitelistedSites.toMutableSet()
            
            val blockedApps = data.blockedApps
            
            if (blockedApps.contains(packageName)) {
                blockAccess("App: $packageName")
                incrementAppBlockCount()
                return
            }
        }

        // Check browser content
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || 
            eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
            eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            
            if (BROWSER_PACKAGES.contains(packageName)) {
                val rootNode = rootInActiveWindow ?: return
                if (scanForBlockedContent(rootNode)) {
                    blockAccess("Restricted content detected in $packageName")
                    incrementWebsiteBlockCount()
                }
            }
        }
    }

    /**
     * Sends the user to the uninstall PIN screen if they open a system screen
     * that could remove ClearNet. Returns true if it did.
     */
    private fun guardProtectedScreens(eventType: Int, packageName: String): Boolean {
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return false
        // These screens all belong to the system Settings app
        if (!packageName.contains("settings")) return false
        if (!UninstallGuard.shouldProtect(this)) return false

        val root = rootInActiveWindow ?: return false
        if (!UninstallGuard.isProtectedScreen(this, root)) return false

        // Content changes arrive in bursts; redirect once
        val now = SystemClock.elapsedRealtime()
        if (now - lastGuardRedirect < 1500) return true
        lastGuardRedirect = now

        Log.i(TAG, "Protected screen opened in $packageName, asking for the uninstall PIN")
        // Back closes the protected page or dialogue, so returning to Settings
        // doesn't land on it. If Back reaches the PIN screen instead, that
        // screen ignores it.
        performGlobalAction(GLOBAL_ACTION_BACK)
        // Going home through an intent (not a global action) keeps the order, so
        // the PIN screen opens on top, as blockAccess() does
        startActivity(Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
        startActivity(Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_VERIFY_UNINSTALL_PIN, true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        })
        return true
    }

    /**
     * ClearNet, the system UI and the launcher are never treated as the app
     * being opened. blockAccess() sends the user Home and opens ClearNet, and
     * those windows must not count as switching to another app.
     */
    private fun isSystemPackage(packageName: String): Boolean {
        return packageName == "com.asptechinc.clearnet" || 
               packageName == "com.android.systemui" || 
               packageName == "android" || 
               packageName.contains("launcher")
    }

    private fun incrementAppBlockCount() {
        NativeStatsManager.incrementBlockedApp(this)
    }

    private fun incrementWebsiteBlockCount() {
        NativeStatsManager.incrementBlockedWebsite(this)
    }

    /**
     * Returns true if this node or any of its children contains blocked text.
     */
    private fun scanForBlockedContent(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false

        // Check text fields (such as address bars or visible page content)
        val text = node.text?.toString()?.lowercase() ?: ""
        if (text.isNotEmpty()) {
            if (shouldBlockText(text)) {
                return true
            }
        }

        // Check content descriptions (such as image alt texts or buttons)
        val contentDesc = node.contentDescription?.toString()?.lowercase() ?: ""
        if (contentDesc.isNotEmpty()) {
            if (shouldBlockText(contentDesc)) {
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (scanForBlockedContent(child)) return true
        }
        return false
    }

    private fun shouldBlockText(text: String): Boolean =
        DomainRules.shouldBlockText(text, blockedSites, blockedKeywords, whitelistedSites)

    /**
     * Sends the user to the home screen, then shows the blocked screen.
     */
    private fun blockAccess(reason: String) {
        Log.i(TAG, "Blocking access. Reason: $reason")
        
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        val blockIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("showBlocked", true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(blockIntent)
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility service interrupted.")
    }
}
