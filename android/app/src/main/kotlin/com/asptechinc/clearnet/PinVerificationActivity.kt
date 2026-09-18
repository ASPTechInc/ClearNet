package com.asptechinc.clearnet

import android.app.Activity
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * PinVerificationActivity acts as a transition point that dynamically mounts a new
 * Flutter instance configured to display the custom secure PIN entry screen route.
 * This prevents users from deactivating admin tools or uninstalling without authentication.
 */
class PinVerificationActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Spin up an isolated Flutter engine initialized directly to the PIN verification route
        val intent = FlutterActivity
            .withNewEngine()
            .initialRoute("/verify_uninstall_pin")
            .build(this)
        startActivity(intent)

        // Immediately close this launcher helper activity container
        finish()
    }
}
