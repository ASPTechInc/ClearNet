// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class UninstallGuardTest {
    private lateinit var context: Context
    private var isDeviceAdmin = false

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        isDeviceAdmin = dpm.isAdminActive(ComponentName(context, AdminReceiver::class.java))
        UninstallGuard.resetAllowance()
    }

    @After
    fun tearDown() {
        UninstallGuard.setEnabled(context, false)
        UninstallGuard.resetAllowance()
    }

    @Test
    fun isOff_whenNoUninstallPinIsSet() {
        UninstallGuard.setEnabled(context, false)
        assertFalse(UninstallGuard.isEnabled(context))
        assertFalse(UninstallGuard.shouldProtect(context))
    }

    @Test
    fun needsBothAPinAndActiveDeviceAdmin() {
        UninstallGuard.setEnabled(context, true)
        // Device admin cannot be turned on from a test, so this follows its state
        assertEquals(isDeviceAdmin, UninstallGuard.isEnabled(context))
    }

    @Test
    fun theUninstallPinOpensAWindow() {
        assertFalse(UninstallGuard.isAllowed())

        UninstallGuard.allowProtectedScreens()

        assertTrue(UninstallGuard.isAllowed())
        UninstallGuard.setEnabled(context, true)
        assertFalse("allowed screens are not protected", UninstallGuard.shouldProtect(context))
    }

    @Test
    fun theWindowCanBeClosed() {
        UninstallGuard.allowProtectedScreens()
        UninstallGuard.resetAllowance()
        assertFalse(UninstallGuard.isAllowed())
    }

    @Test
    fun recognisedTextIsUniqueToEachScreen() {
        val markers = listOf(
            context.getString(R.string.device_admin_description),
            context.getString(R.string.uninstall_dialog_message),
            context.getString(R.string.accessibility_service_description),
        )
        assertEquals(markers.size, markers.toSet().size)
        markers.forEach { assertNotEquals("", it.trim()) }
    }

    @Test
    fun adminReceiverShowsTheRecognisedMessage() {
        val message = AdminReceiver().onDisableRequested(context android.content.Intent())
        assertEquals(context.getString(R.string.uninstall_dialog_message), message.toString())
    }
}
