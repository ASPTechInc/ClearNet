package com.asptechinc.clearnet

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.content.Intent

/**
 * BlockedActivity displays an overlay or full-screen warning when access to an
 * application or a website is restricted. It provides a simple button to safely
 * redirect the user back to their main device launcher home.
 */
class BlockedActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_blocked)
        
        // Find and set up the button to return back to the main device home screen
        findViewById<Button>(R.id.btn_back_home).setOnClickListener {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            finish()
        }
    }
}
