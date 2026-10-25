// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import androidx.core.net.toUri

/**
 * Accessibility service that closes blocked apps and, in supported browsers,
 * checks the text on screen against the blocked domains and keywords.
 */
class AppBlockService : AccessibilityService() {

    // Used until the first window change loads the saved lists
    private var blockedKeywords = mutableSetOf("porn", "sex", "xxx", "adult")
    private var blockedSites = mutableSetOf<String>()
    private var whitelistedSites = mutableSetOf<String>()

    companion object {
        const val TAG = "AppBlockService"

        // Keep this as a list first so tests can detect duplicates before
        // converting it to a set.
        internal val BROWSER_PACKAGE_LIST = listOf(
            // Chrome
            "com.android.chrome", "com.chrome.beta", "com.chrome.dev", "com.chrome.canary",
            // Firefox and its forks
            "org.mozilla.firefox", "org.mozilla.firefox_beta", "org.mozilla.fenix",
            "org.mozilla.focus", "org.mozilla.focus.beta", "org.mozilla.focus.nightly",
            "org.mozilla.klar", "org.mozilla.rocket", "org.mozilla.fennec_fdroid",
            "us.spotco.fennec_dos",                       // Mull
            "io.github.forkmaintainers.iceraven",
            "org.torproject.torbrowser", "org.torproject.torbrowser_alpha",
            // Edge
            "com.microsoft.emmx", "com.microsoft.emmx.beta",
            "com.microsoft.emmx.dev", "com.microsoft.emmx.canary",
            // Samsung Internet
            "com.sec.android.app.sbrowser", "com.sec.android.app.sbrowser.beta",
            // Opera
            "com.opera.browser", "com.opera.browser.beta", "com.opera.mini.native",
            "com.opera.mini.native.beta", "com.opera.gx", "com.opera.touch",
            // Brave
            "com.brave.browser", "com.brave.browser_beta", "com.brave.browser_nightly",
            // Other Chromium-based browsers
            "com.vivaldi.browser", "com.vivaldi.browser.snapshot",
            "com.kiwibrowser.browser",
            "org.bromite.bromite", "org.cromite.cromite",
            "com.yandex.browser", "com.yandex.browser.lite",
            "com.naver.whale",
            "com.ecosia.android",
            "com.avast.android.secure.browser",
            "company.thebrowser.arc",                     // Arc Search
            // Privacy and lightweight browsers
            "com.duckduckgo.mobile.android",
            "mark.via.gp",                                // Via
            "acr.browser.lightning",
            "com.aloha.browser",
            "com.stoutner.privacybrowser.free", "com.stoutner.privacybrowser.standard",
            // Phone makers' browsers
            "com.android.browser",                        // AOSP and Xiaomi in China
            "com.mi.globalbrowser",                       // Xiaomi
            "com.huawei.browser",
            "com.heytap.browser",                         // Oppo, Realme, OnePlus
            "com.vivo.browser",
            "com.transsion.phoenix",                      // Tecno, Infinix, itel
            "com.amazon.cloud9",                          // Amazon Silk
            // Older and other popular browsers
            "com.UCMobile.intl", "com.uc.browser.en",     // UC Browser, UC Mini
            "com.cloudmosa.puffin", "com.cloudmosa.puffinFree",
            "mobi.mgeek.TunnyBrowser", "com.dolphin.browser.zero",     // Dolphin
            "com.mx.browser",                             // Maxthon
            "com.ksmobile.cb",                            // CM Browser
            // Google app, which opens search results in its own browser
            "com.google.android.googlequicksearchbox",
            "org.lineageos.jelly",
            "com.ghostery.android.ghostery",
        )

        // Browsers whose on-screen text is always checked. Other apps that can
        // open web links are found by isBrowser().
        val BROWSER_PACKAGES = BROWSER_PACKAGE_LIST.toSet()
    }

    // When the user was last sent away from a protected screen
    private var lastGuardRedirect = 0L

    // Whether each package seen so far is a browser, so the package manager is
    // asked once per app rather than on every event
    private val browserCache = HashMap<String, Boolean>()

    /**
     * True for any app that can open ordinary web links, so every browser is
     * checked (Brave, Firefox Focus, Opera Mini, Tor and so on), not just the
     * listed ones. This check works whichever VPN is running, unlike the DNS
     * filter, which stops when another VPN takes over.
     */
    private fun isBrowser(packageName: String): Boolean {
        if (packageName.isEmpty() || isSystemPackage(packageName)) return false
        if (packageName in BROWSER_PACKAGES) return true
        return browserCache.getOrPut(packageName) {
            val intent = Intent(Intent.ACTION_VIEW, "https://example.com".toUri())
                .addCategory(Intent.CATEGORY_BROWSABLE)
                .setPackage(packageName)
            try {
                packageManager.queryIntentActivities(intent, 0).isNotEmpty()
            } catch (e: Exception) {
                Log.w(TAG, "Could not check whether $packageName is a browser", e)
                false
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        val packageName = event.packageName?.toString() ?: ""

        // Runs even while blocking is paused, so pausing cannot be used to remove ClearNet
        if (guardProtectedScreens(eventType, packageName)) return

        // Settings saved by the Flutter app. Checking them on every event is
        // how changes made in the app are picked up; the file is only read
        // again after it changes.
        val data = DataStoreReader.readDataCached(this)
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
            
            if (isBrowser(packageName)) {
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
        // does not land on it. If Back reaches the PIN screen instead, that
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
     * being opened. blockAccess() sends the user Home and opens ClearNet and
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
