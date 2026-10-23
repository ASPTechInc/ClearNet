// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.Context
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AdminReceiverTest {

    private lateinit var context: Context
    private lateinit var receiver: AdminReceiver

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        receiver = AdminReceiver()
    }

    @Test
    fun onDisableRequested_returnsWarningMessage() {
        val intent = Intent("android.app.action.DEVICE_ADMIN_DISABLE_REQUESTED")
        val warningMessage = receiver.onDisableRequested(context, intent)
        assertEquals("Enter your uninstall protection PIN to proceed.", warningMessage.toString())
    }

    @Test
    fun onEnabledAndOnDisabled_executeWithoutErrors() {
        val intent = Intent()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            receiver.onEnabled(context, intent)
            receiver.onDisabled(context, intent)
        }
    }
}
