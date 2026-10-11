package com.asptechinc.clearnet

import android.content.Context
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MyDeviceAdminReceiverTest {

    private lateinit var context: Context
    private lateinit var receiver: MyDeviceAdminReceiver

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        receiver = MyDeviceAdminReceiver()
    }

    @Test
    fun callbacks_executeWithoutExceptions() {
        val intent = Intent()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            receiver.onEnabled(context, intent)
            receiver.onDisabled(context, intent)
        }
    }
}
