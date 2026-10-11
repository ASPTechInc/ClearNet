package com.asptechinc.clearnet

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class NativeStatsManagerTest {

    private lateinit var context: Context
    private lateinit var statsFile: File

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        statsFile = File(context.filesDir, "native_stats.json")
        if (statsFile.exists()) {
            statsFile.delete()
        }
    }

    @After
    fun tearDown() {
        if (statsFile.exists()) {
            statsFile.delete()
        }
    }

    @Test
    fun getStats_whenFileDoesNotExist_returnsDefaultJsonObject() {
        val stats = NativeStatsManager.getStats(context)
        assertNotNull(stats)
        assertTrue(statsFile.exists())
        assertTrue(stats.has("last_daily_reset"))
        assertTrue(stats.has("last_weekly_reset"))
        assertTrue(stats.has("last_monthly_reset"))
        assertEquals(0, stats.optInt("blocked_websites_count", 0))
        assertEquals(0, stats.optInt("blocked_apps_count", 0))
    }

    @Test
    fun incrementBlockedWebsite_incrementsCounts() {
        NativeStatsManager.incrementBlockedWebsite(context)

        val stats = NativeStatsManager.getStats(context)
        assertEquals(1, stats.getInt("blocked_websites_count"))
        assertEquals(1, stats.getInt("weekly_websites_count"))
        assertEquals(1, stats.getInt("monthly_websites_count"))
        assertEquals(0, stats.optInt("blocked_apps_count", 0))

        NativeStatsManager.incrementBlockedWebsite(context)
        val stats2 = NativeStatsManager.getStats(context)
        assertEquals(2, stats2.getInt("blocked_websites_count"))
        assertEquals(2, stats2.getInt("weekly_websites_count"))
        assertEquals(2, stats2.getInt("monthly_websites_count"))
    }

    @Test
    fun incrementBlockedApp_incrementsCounts() {
        NativeStatsManager.incrementBlockedApp(context)

        val stats = NativeStatsManager.getStats(context)
        assertEquals(1, stats.getInt("blocked_apps_count"))
        assertEquals(1, stats.getInt("weekly_apps_count"))
        assertEquals(1, stats.getInt("monthly_apps_count"))
        assertEquals(0, stats.optInt("blocked_websites_count", 0))
    }

    @Test
    fun getStats_resetsDailyCounts_whenDateChanges() {
        val json = JSONObject().apply {
            put("blocked_websites_count", 10)
            put("blocked_apps_count", 5)
            put("weekly_websites_count", 10)
            put("weekly_apps_count", 5)
            put("monthly_websites_count", 10)
            put("monthly_apps_count", 5)
            put("last_daily_reset", "2000-01-01")
            put("last_weekly_reset", "52-2000")
            put("last_monthly_reset", "1-2000")
        }
        statsFile.writeText(json.toString())

        val stats = NativeStatsManager.getStats(context)
        assertEquals(0, stats.getInt("blocked_websites_count"))
        assertEquals(0, stats.getInt("blocked_apps_count"))
        assertEquals(0, stats.getInt("weekly_websites_count"))
        assertEquals(0, stats.getInt("monthly_websites_count"))
    }
}
