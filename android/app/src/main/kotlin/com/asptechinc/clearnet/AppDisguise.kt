// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Switches ClearNet's launcher icon between its normal one and the disguises.
 * Each is an <activity-alias> of MainActivity in AndroidManifest.xml and
 * exactly one is turned on. MainActivity itself is never turned off, because
 * ClearNet opens it directly.
 */
object AppDisguise {
    val ALIASES = mapOf(
        "none" to ".DefaultActivity",
        "calculator" to ".CalculatorActivity",
        "notes" to ".NotesActivity",
    )

    /** Turns on the icon for [disguise] (unknown values mean "none"). */
    fun apply(context: Context, disguise: String) {
        val chosen = if (disguise in ALIASES) disguise else "none"
        val pm = context.packageManager
        ALIASES.forEach { (name, alias) ->
            val state = if (name == chosen) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(component(context, alias), state, PackageManager.DONT_KILL_APP)
        }
    }

    fun component(context: Context, alias: String) =
        ComponentName(context.packageName, context.packageName + alias)
}
