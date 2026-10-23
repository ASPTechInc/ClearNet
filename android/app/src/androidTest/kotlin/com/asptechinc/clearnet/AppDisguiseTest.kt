// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppDisguiseTest {
    private lateinit var context: Context
    private lateinit var pm: PackageManager

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        pm = context.packageManager
    }

    @After
    fun tearDown() {
        AppDisguise.apply(context, "none")
    }

    private fun isOn(alias: String) =
        pm.getComponentEnabledSetting(AppDisguise.component(context, alias)) ==
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED

    private fun assertOnlyOn(disguise: String) {
        AppDisguise.ALIASES.forEach { (name, alias) ->
            assertEquals("$alias for $disguise", name == disguise, isOn(alias))
        }
    }

    private fun assertMainActivityStillOn() {
        val main = ComponentName(context, MainActivity::class.java)
        assertNotEquals(
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            pm.getComponentEnabledSetting(main),
        )
        // ClearNet opens MainActivity directly, so it must still resolve
        val intent = Intent(context, MainActivity::class.java)
        assertEquals(main.className, pm.resolveActivity(intent, 0)?.activityInfo?.name)
    }

    @Test
    fun eachDisguiseTurnsOnOnlyItsIcon() {
        for (disguise in listOf("calculator", "notes", "none")) {
            AppDisguise.apply(context, disguise)
            assertOnlyOn(disguise)
            assertMainActivityStillOn()
        }
    }

    @Test
    fun anUnknownDisguiseShowsTheNormalIcon() {
        AppDisguise.apply(context, "calculator")
        AppDisguise.apply(context, "something-else")
        assertOnlyOn("none")
    }

    @Test
    fun theLauncherShowsExactlyOneClearNetIcon() {
        AppDisguise.apply(context, "notes")
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage(context.packageName)
        val icons = pm.queryIntentActivities(launcher, 0)
        assertEquals(1, icons.size)
        assertEquals(context.packageName + ".NotesActivity", icons.single().activityInfo.name)
    }

    @Test
    fun eachDisguiseHasItsOwnIcon() {
        fun iconOf(alias: String) = pm.getActivityInfo(
            AppDisguise.component(context, alias),
            PackageManager.MATCH_DISABLED_COMPONENTS,
        ).iconResource

        assertEquals(R.mipmap.ic_launcher, iconOf(".DefaultActivity"))
        assertEquals(R.mipmap.ic_calculator, iconOf(".CalculatorActivity"))
        assertEquals(R.mipmap.ic_notes, iconOf(".NotesActivity"))
    }
}
