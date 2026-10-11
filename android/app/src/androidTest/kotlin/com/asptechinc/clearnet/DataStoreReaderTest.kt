package com.asptechinc.clearnet

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class DataStoreReaderTest {

    private lateinit var context: Context
    private lateinit var dataStoreDir: File
    private lateinit var dataStoreFile: File

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        dataStoreDir = File(context.filesDir, "datastore")
        dataStoreFile = File(dataStoreDir, "FlutterSharedPreferences.preferences_pb")
        if (dataStoreFile.exists()) {
            dataStoreFile.delete()
        }
    }

    @After
    fun tearDown() {
        if (dataStoreFile.exists()) {
            dataStoreFile.delete()
        }
    }

    @Test
    fun readData_whenFileDoesNotExist_returnsDefaultData() {
        val data = DataStoreReader.readData(context)
        assertFalse(data.isBlockingEnabled)
        assertTrue(data.blockedSites.isEmpty())
        assertTrue(data.blockedKeywords.isEmpty())
        assertTrue(data.whitelistedSites.isEmpty())
        assertTrue(data.blockedApps.isEmpty())
        assertEquals("", data.customDns)
    }

    @Test
    fun readData_whenFileExists_parsesDataStoreCorrectly() {
        dataStoreDir.mkdirs()

        val content = """
            is_blocking_enabled${"\u0012\u0002\u0008\u0001"}
            blocked_sites["example.com", "gambling.org"]
            blocked_keywords["porn", "casino"]
            whitelisted_sites["safe.com"]
            blocked_apps["com.example.badapp"]
            custom_dns1.1.1.1
        """.trimIndent()

        dataStoreFile.writeText(content, Charsets.ISO_8859_1)

        val data = DataStoreReader.readData(context)
        assertTrue(data.isBlockingEnabled)
        assertEquals(setOf("example.com", "gambling.org"), data.blockedSites)
        assertEquals(setOf("porn", "casino"), data.blockedKeywords)
        assertEquals(setOf("safe.com"), data.whitelistedSites)
        assertEquals(setOf("com.example.badapp"), data.blockedApps)
        assertEquals("1.1.1.1", data.customDns)
    }

    @Test
    fun readData_whenBlockingDisabled_parsesIsBlockingEnabledAsFalse() {
        dataStoreDir.mkdirs()

        val content = """
            is_blocking_enabled${"\u0012\u0002\u0008\u0000"}
            blocked_sites[]
        """.trimIndent()

        dataStoreFile.writeText(content, Charsets.ISO_8859_1)

        val data = DataStoreReader.readData(context)
        assertFalse(data.isBlockingEnabled)
        assertTrue(data.blockedSites.isEmpty())
    }
}
