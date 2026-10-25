// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * Keeps the blocked website and app counts in a JSON file. The VPN and the
 * accessibility service update them from native threads, so they cannot use the
 * Flutter preferences. The Flutter app reads them through the 'getStats' method
 * channel call, which also resets the daily, weekly and monthly counts when
 * those periods have passed.
 */
object NativeStatsManager {
    private const val TAG = "NativeStatsManager"
    private const val FILE_NAME = "native_stats.json"

    // The un-prefixed keys are the daily counts
    /**
     * Identifies the week containing [date] by the date of the Sunday it
     * starts on (such as "2025-10-12"). Weeks always start on Sunday, whatever
     * the phone's locale and the key needs no week numbering, so there's
     * nothing odd around New Year.
     */
    internal fun weekKey(date: Date): String {
        val calendar = GregorianCalendar(Locale.ROOT).apply {
            time = date
            set(Calendar.HOUR_OF_DAY, 12)
        }
        val daysSinceSunday = calendar.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY
        calendar.add(Calendar.DAY_OF_MONTH, -daysSinceSunday)
        return SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(calendar.time)
    }

    fun incrementBlockedWebsite(context: Context) {
        increment(context, "blocked_websites_count", "weekly_websites_count", "monthly_websites_count")
    }

    fun incrementBlockedApp(context: Context) {
        increment(context, "blocked_apps_count", "weekly_apps_count", "monthly_apps_count")
    }

    @Synchronized
    fun getStats(context: Context): JSONObject {
        val file = File(context.filesDir, FILE_NAME)
        val json = if (file.exists()) {
            JSONObject(file.readText())
        } else {
            JSONObject()
        }
        
        val now = Calendar.getInstance()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
        val currentWeek = weekKey(now.time)
        val currentMonth = (now.get(Calendar.MONTH) + 1).toString() + "-" + now.get(Calendar.YEAR)
        
        var modified = false
        if (json.optString("last_daily_reset") != todayStr) {
            json.put("blocked_websites_count", 0)
            json.put("blocked_apps_count", 0)
            json.put("last_daily_reset", todayStr)
            modified = true
        }
        
        if (json.optString("last_weekly_reset") != currentWeek) {
            json.put("weekly_websites_count", 0)
            json.put("weekly_apps_count", 0)
            json.put("last_weekly_reset", currentWeek)
            modified = true
        }
        
        if (json.optString("last_monthly_reset") != currentMonth) {
            json.put("monthly_websites_count", 0)
            json.put("monthly_apps_count", 0)
            json.put("last_monthly_reset", currentMonth)
            modified = true
        }
        
        if (modified) {
            file.writeText(json.toString())
        }
        return json
    }

    @Synchronized
    private fun increment(context: Context, dailyKey: String, weeklyKey: String, monthlyKey: String) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            val json = if (file.exists()) {
                JSONObject(file.readText())
            } else {
                JSONObject()
            }

            val now = Calendar.getInstance()
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
            val currentWeek = weekKey(now.time)
            val currentMonth = (now.get(Calendar.MONTH) + 1).toString() + "-" + now.get(Calendar.YEAR)

            // Reset logic
            if (json.optString("last_daily_reset") != todayStr) {
                json.put("blocked_websites_count", 0)
                json.put("blocked_apps_count", 0)
                json.put("last_daily_reset", todayStr)
            }

            if (json.optString("last_weekly_reset") != currentWeek) {
                json.put("weekly_websites_count", 0)
                json.put("weekly_apps_count", 0)
                json.put("last_weekly_reset", currentWeek)
            }

            if (json.optString("last_monthly_reset") != currentMonth) {
                json.put("monthly_websites_count", 0)
                json.put("monthly_apps_count", 0)
                json.put("last_monthly_reset", currentMonth)
            }

            // Increment
            json.put(dailyKey, json.optInt(dailyKey, 0) + 1)
            json.put(weeklyKey, json.optInt(weeklyKey, 0) + 1)
            json.put(monthlyKey, json.optInt(monthlyKey, 0) + 1)

            file.writeText(json.toString())
            Log.d(TAG, "Incremented $dailyKey. New value: ${json.getInt(dailyKey)}")
        } catch (e: Exception) {
            Log.e(TAG, "Error updating native stats", e)
        }
    }
}
