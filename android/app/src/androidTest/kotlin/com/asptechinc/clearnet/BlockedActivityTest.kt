package com.asptechinc.clearnet

import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BlockedActivityTest {

    @Test
    fun blockedActivity_displaysUiAndHandlesBackHomeClick() {
        val scenario = ActivityScenario.launch(BlockedActivity::class.java)

        scenario.onActivity { activity ->
            activity.window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )

            val imgBlocked = activity.findViewById<ImageView>(R.id.img_blocked)
            val btnBackHome = activity.findViewById<Button>(R.id.btn_back_home)

            assertNotNull("img_blocked view should be present", imgBlocked)
            assertNotNull("btn_back_home view should be present", btnBackHome)

            btnBackHome.performClick()
            assertTrue(activity.isFinishing || activity.isDestroyed)
        }

        scenario.close()
    }
}
