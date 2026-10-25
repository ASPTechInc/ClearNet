// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

/**
 * Asks for the PIN before device administrator access can be turned off, so
 * ClearNet cannot be uninstalled without it.
 */
class AdminReceiver : DeviceAdminReceiver() {

    /**
     * The returned text is shown in the system's confirmation dialogue.
     */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // Opens ClearNet on its uninstall PIN screen, on top of the system
        // dialogue, unless the PIN was just entered
        if (UninstallGuard.shouldProtect(context)) {
            val pinIntent = Intent(context, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_VERIFY_UNINSTALL_PIN, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            context.startActivity(pinIntent)
        }

        return context.getString(R.string.uninstall_dialog_message)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "ClearNet has been disabled", Toast.LENGTH_SHORT).show()
    }

    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "ClearNet is now a device admin", Toast.LENGTH_SHORT).show()
    }
}
