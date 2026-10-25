// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Keeps ClearNet's protection from being removed without the uninstall PIN.
 *
 * While an uninstall PIN is set and device admin is active, the system screens
 * that could remove ClearNet are protected: its device admin page, the
 * deactivate dialogue and its accessibility page. They are recognised by text
 * ClearNet supplies to them, so this works in any language. Entering the
 * uninstall PIN allows them for a short time.
 */
object UninstallGuard {
    private const val PREFS = "clearnet_guard"
    private const val KEY_ENABLED = "uninstall_protection"
    private const val ALLOW_FOR_MS = 2 * 60 * 1000L

    // In memory only, so a restarted process is protected again
    @Volatile private var allowedUntil = 0L

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    /** True if an uninstall PIN is set and ClearNet is an active device admin. */
    fun isEnabled(context: Context): Boolean {
        val enabled = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
        return enabled && isAdminActive(context)
    }

    fun adminComponent(context: Context) = ComponentName(context, AdminReceiver::class.java)

    /** True if the user has allowed ClearNet as a device admin. */
    fun isAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(adminComponent(context))
    }

    /** Called after the uninstall PIN is entered correctly. */
    fun allowProtectedScreens() {
        allowedUntil = SystemClock.elapsedRealtime() + ALLOW_FOR_MS
    }

    fun isAllowed(): Boolean = SystemClock.elapsedRealtime() < allowedUntil

    /** For tests: ends the window opened by [allowProtectedScreens]. */
    internal fun resetAllowance() {
        allowedUntil = 0L
    }

    fun shouldProtect(context: Context): Boolean = isEnabled(context) && !isAllowed()

    /** True if [root] is one of the protected screens. */
    fun isProtectedScreen(context: Context, root: AccessibilityNodeInfo): Boolean {
        val markers = listOf(
            context.getString(R.string.device_admin_description),
            context.getString(R.string.uninstall_dialog_message),
            context.getString(R.string.accessibility_service_description),
        )
        return markers.any { root.findAccessibilityNodeInfosByText(it).isNotEmpty() }
    }
}
