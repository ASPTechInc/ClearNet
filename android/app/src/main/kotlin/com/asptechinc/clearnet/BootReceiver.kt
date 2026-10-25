// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log

/**
 * Starts the VPN again after the device restarts or ClearNet is updated, both
 * of which stop it. It only starts if blocking is on and the VPN permission
 * was already given, because the permission screen cannot be shown from here.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "BootReceiver"

        val START_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )

        internal fun shouldStartVpn(
            action: String?,
            isBlockingEnabled: Boolean,
            hasVpnPermission: Boolean,
        ): Boolean = action in START_ACTIONS && isBlockingEnabled && hasVpnPermission
    }

    override fun onReceive(context: Context, intent: Intent) {
        val start = shouldStartVpn(
            action = intent.action,
            isBlockingEnabled = DataStoreReader.readData(context).isBlockingEnabled,
            // prepare() returns null once the user has allowed the VPN
            hasVpnPermission = VpnService.prepare(context) == null,
        )
        if (!start) return

        try {
            context.startService(Intent(context, SafeVpnService::class.java))
            Log.i(TAG, "Started the VPN after ${intent.action}")
        } catch (e: Exception) {
            // Android can refuse to start services from the background
            Log.w(TAG, "Could not start the VPN after ${intent.action}", e)
        }
    }
}
