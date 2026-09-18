package com.asptechinc.clearnet

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * AppBlockService implements an Android Accessibility Service to provide real-time
 * application blocking and content screening/filtering. It inspects window transitions,
 * scrolling events and content mutations to detect restricted content or blacklisted apps.
 */
class AppBlockService : AccessibilityService() {

    // Default set of blocked keywords if none are found in preferences
    private var blockedKeywords = mutableSetOf("porn", "sex", "xxx", "adult", "gamble", "casino")
    private var blockedSites = mutableSetOf<String>()

    companion object {
        const val TAG = "AppBlockService"
        
        // Supported browser package names for granular URL and text scanning
        val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
            "com.microsoft.emmx",
            "com.duckduckgo.mobile.android"
        )
    }

    /**
     * Intercepts accessibility events dispatched by the system.
     * Processes foreground window states and inspects screen hierarchies for safe browsing violations.
     */
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        val packageName = event.packageName?.toString() ?: ""

        // Fetch user preferences shared with the Flutter frontend
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isBlockingEnabled = prefs.getBoolean("flutter.is_blocking_enabled", false)
        if (!isBlockingEnabled) return

        // 1. App Blocking Logic
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (isSystemPackage(packageName)) return

            Log.d(TAG, "Foreground app changed to: $packageName")
            
            // Sync current lists of blacklisted sites and keywords from preferences
            loadBlockedData()
            
            val blockedApps = getBlockedApps(prefs)
            
            // Redirect the user if they attempt to launch a blocked application
            if (blockedApps.contains(packageName)) {
                blockAccess("App: $packageName")
                incrementAppBlockCount()
                return
            }
        }

        // 2. Safe Browsing Logic (URL + Content Scanning inside browser viewports)
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || 
            eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
            eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            
            if (BROWSER_PACKAGES.contains(packageName)) {
                val rootNode = rootInActiveWindow ?: return
                // Recursively inspect the view hierarchy nodes for violations
                if (scanForBlockedContent(rootNode)) {
                    blockAccess("Restricted content detected in $packageName")
                    incrementWebsiteBlockCount()
                }
            }
        }
    }

    /**
     * Helper to skip core Android system apps and components from blocking.
     */
    private fun isSystemPackage(packageName: String): Boolean {
        return packageName == "com.asptechinc.clearnet" || 
               packageName == "com.android.systemui" || 
               packageName == "android" || 
               packageName.contains("launcher")
    }

    /**
     * Updates the persistent statistics counter for blocked apps.
     */
    private fun incrementAppBlockCount() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = prefs.getInt("flutter.blocked_apps_count", 0)
        prefs.edit().putInt("flutter.blocked_apps_count", current + 1).apply()
    }

    /**
     * Updates the persistent statistics counter for blocked websites/content.
     */
    private fun incrementWebsiteBlockCount() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = prefs.getInt("flutter.blocked_websites_count", 0)
        prefs.edit().putInt("flutter.blocked_websites_count", current + 1).apply()
    }

    /**
     * Loads and parses the latest block lists (domains & keywords) from FlutterSharedPreferences.
     * Supports both standard string-set preferences and JSON string fallbacks.
     */
    private fun loadBlockedData() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Load Blocked Domains
        try {
            val savedSites = prefs.getStringSet("flutter.blocked_sites", null)
            if (savedSites != null) {
                blockedSites = savedSites.map { it.lowercase() }.toMutableSet()
            }
        } catch (e: Exception) {
            // Fallback parsing if saved as a stringified list JSON array
            val jsonStr = prefs.getString("flutter.blocked_sites", null)
            if (jsonStr != null) {
                val cleaned = jsonStr.replace("[", "").replace("]", "").replace("\"", "")
                val sites = cleaned.split(",")
                blockedSites = sites.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.toMutableSet()
            }
        }

        // Load Blocked Keywords
        try {
            val savedKeywords = prefs.getStringSet("flutter.blocked_keywords", null)
            if (savedKeywords != null) {
                blockedKeywords.addAll(savedKeywords.map { it.lowercase() })
            }
        } catch (e: Exception) {
            // Fallback parsing if saved as a stringified list JSON array
            val jsonStr = prefs.getString("flutter.blocked_keywords", null)
            if (jsonStr != null) {
                val cleaned = jsonStr.replace("[", "").replace("]", "").replace("\"", "")
                val words = cleaned.split(",")
                blockedKeywords.addAll(words.map { it.trim().lowercase() }.filter { it.isNotEmpty() })
            }
        }
    }

    /**
     * Retrieves the set of blacklisted applications from shared preferences.
     */
    private fun getBlockedApps(prefs: android.content.SharedPreferences): Set<String> {
        return try {
            prefs.getStringSet("flutter.blocked_apps", null) ?: emptySet<String>()
        } catch (e: Exception) {
            emptySet()
        }
    }

    /**
     * Recursively traverses an accessibility node and all its child elements to scan text
     * and content descriptions for blacklisted keywords or website patterns.
     *
     * @param node The accessibility node to analyse.
     * @return True if a block match is found, false otherwise.
     */
    private fun scanForBlockedContent(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false

        // Check text fields (such as address bars or visible page content)
        val text = node.text?.toString()?.lowercase() ?: ""
        if (text.isNotEmpty()) {
            if (shouldBlockText(text)) {
                Log.i(TAG, "Blocking based on text: $text")
                return true
            }
        }

        // Check content descriptions (such as image alt texts or buttons)
        val contentDesc = node.contentDescription?.toString()?.lowercase() ?: ""
        if (contentDesc.isNotEmpty()) {
            if (shouldBlockText(contentDesc)) {
                Log.i(TAG, "Blocking based on description: $contentDesc")
                return true
            }
        }

        // Perform depth-first recursive scan of all children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (scanForBlockedContent(child)) return true
        }
        return false
    }

    /**
     * Heuristic match against keywords and domain substrings.
     */
    private fun shouldBlockText(text: String): Boolean {
        // Match against blocked keywords
        if (blockedKeywords.any { text.contains(it) }) return true
        
        // Match against blocked website domains
        if (blockedSites.any { text.contains(it) }) return true
        
        return false
    }

    /**
     * Closes the current unauthorized viewport by bringing the user back to the home launcher
     * and displaying the explicit ClearNet blocked view.
     */
    private fun blockAccess(reason: String) {
        Log.i(TAG, "Blocking access. Reason: $reason")
        
        // Step 1: Force minimize current app context by sending user Home
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        // Step 2: Route directly to the ClearNet overlay / blocked screen notification
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
