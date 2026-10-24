// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BootReceiverTest {

    @Test
    fun startsAfterARestartOrUpdateWhenBlockingIsOn() {
        assertTrue(BootReceiver.shouldStartVpn(Intent.ACTION_BOOT_COMPLETED, true, true))
        assertTrue(BootReceiver.shouldStartVpn(Intent.ACTION_MY_PACKAGE_REPLACED, true, true))
    }

    @Test
    fun doesNotStartWhileBlockingIsPaused() {
        assertFalse(BootReceiver.shouldStartVpn(Intent.ACTION_BOOT_COMPLETED, false, true))
    }

    @Test
    fun doesNotStartWithoutTheVpnPermission() {
        assertFalse(BootReceiver.shouldStartVpn(Intent.ACTION_BOOT_COMPLETED, true, false))
    }

    @Test
    fun ignoresOtherBroadcasts() {
        assertFalse(BootReceiver.shouldStartVpn(Intent.ACTION_SCREEN_ON, true, true))
        assertFalse(BootReceiver.shouldStartVpn(null, true, true))
    }

    @Test
    fun isRegisteredForBothBroadcasts() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val receiver = ComponentName(context, BootReceiver::class.java)
        for (action in BootReceiver.START_ACTIONS) {
            val found = context.packageManager
                .queryBroadcastReceivers(Intent(action).setPackage(context.packageName), 0)
                .map { ComponentName(it.activityInfo.packageName, it.activityInfo.name) }
            assertTrue("Not registered for $action", receiver in found)
        }
        assertEquals(
            PackageManager.PERMISSION_GRANTED,
            context.checkSelfPermission(android.Manifest.permission.RECEIVE_BOOT_COMPLETED),
        )
    }
}
