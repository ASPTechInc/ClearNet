package com.asptechinc.clearnet

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

/**
 * AdminReceiver handles the Device Administration lifecycle events.
 * This class provides uninstall and disable protection by intercepting requests
 * to deactivate Device Admin privileges and prompting the user for a verification PIN.
 */
class AdminReceiver : DeviceAdminReceiver() {

    /**
     * Intercepts requests to disable device admin privileges.
     * Launches the PIN verification activity to prevent unauthorized deactivation/uninstallation.
     *
     * @param context The application context.
     * @param intent The incoming disable request intent.
     * @return A warning message displayed to the user in the system dialog.
     */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // Trigger the PIN verification screen before allowing device admin to be deactivated
        val pinIntent = Intent(context, PinVerificationActivity::class.java)
        pinIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(pinIntent)

        // Return the warning message shown to the user while waiting for PIN entry
        return "Enter your uninstall protection PIN to proceed."
    }

    /**
     * Called when the device admin privileges have been successfully disabled.
     */
    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "ClearNet has been disabled", Toast.LENGTH_SHORT).show()
    }

    /**
     * Called when the device admin privileges have been successfully enabled.
     */
    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "ClearNet is now a device admin", Toast.LENGTH_SHORT).show()
    }
}
