package com.asptechinc.clearnet

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

/**
 * MyDeviceAdminReceiver receives and logs activation/deactivation broadcast callbacks
 * for the application's Device Administrator component configuration.
 */
class MyDeviceAdminReceiver : DeviceAdminReceiver() {

    /**
     * Triggered when the user grants device administrator capabilities to ClearNet.
     */
    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Device Admin Enabled", Toast.LENGTH_SHORT).show()
    }

    /**
     * Triggered when the user revokes device administrator capabilities from ClearNet.
     */
    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Device Admin Disabled", Toast.LENGTH_SHORT).show()
    }
}
