// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.Context
import android.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File

@RunWith(AndroidJUnit4::class)
class DataStoreReaderTest {

    private lateinit var context: Context
    private lateinit var dataStoreDir: File
    private lateinit var dataStoreFile: File

    companion object {
        private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"

        // A settings file saved by the app on an emulator: the default lists
        // with blocking on. The user_* lists come before the merged ones.
        private const val REAL_FILE_BASE64 =
            "CocBChR1c2VyX2Jsb2NrZWRfZG9tYWlucxJvKm1WR2hwY3lCcGN5QjBhR1VnY0hKbFptbDRJR1p2Y2lC" +
            "aElHeHBjM1F1IVsicG9ybmh1Yi5jb20iLCJ4dmlkZW9zLmNvbSIsInhueHguY29tIiwicmVkdHViZS5j" +
            "b20iLCJ5b3Vwb3JuLmNvbSJdCl4KFXVzZXJfYmxvY2tlZF9rZXl3b3JkcxJFKkNWR2hwY3lCcGN5QjBh" +
            "R1VnY0hKbFptbDRJR1p2Y2lCaElHeHBjM1F1IVsicG9ybiIsInNleCIsInh4eCIsInpvbyJdCmkKFnVz" +
            "ZXJfd2hpdGVsaXN0ZWRfc2l0ZXMSTypNVkdocGN5QnBjeUIwYUdVZ2NISmxabWw0SUdadmNpQmhJR3hw" +
            "YzNRdSFbImV4YW1wbGUuY29tIiwiYW5vdGhlcmV4YW1wbGUuY29tIl0KgAEKDWJsb2NrZWRfc2l0ZXMS" +
            "byptVkdocGN5QnBjeUIwYUdVZ2NISmxabWw0SUdadmNpQmhJR3hwYzNRdSFbInBvcm5odWIuY29tIiwi" +
            "eHZpZGVvcy5jb20iLCJ4bnh4LmNvbSIsInJlZHR1YmUuY29tIiwieW91cG9ybi5jb20iXQpZChBibG9j" +
            "a2VkX2tleXdvcmRzEkUqQ1ZHaHBjeUJwY3lCMGFHVWdjSEpsWm1sNElHWnZjaUJoSUd4cGMzUXUhWyJw" +
            "b3JuIiwic2V4IiwieHh4Iiwiem9vIl0KZAoRd2hpdGVsaXN0ZWRfc2l0ZXMSTypNVkdocGN5QnBjeUIw" +
            "YUdVZ2NISmxabWw0SUdadmNpQmhJR3hwYzNRdSFbImV4YW1wbGUuY29tIiwiYW5vdGhlcmV4YW1wbGUu" +
            "Y29tIl0KHgoYaGFzX3NlZW5fcHJvdGVjdGlvbl90b3VyEgIIAQoZChNpc19ibG9ja2luZ19lbmFibGVk" +
            "EgIIAQ=="
    }

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        dataStoreDir = File(context.filesDir, "datastore")
        dataStoreFile = File(dataStoreDir, "FlutterSharedPreferences.preferences_pb")
        if (dataStoreFile.exists()) dataStoreFile.delete()
    }

    @After
    fun tearDown() {
        if (dataStoreFile.exists()) dataStoreFile.delete()
    }

    // --- Builds files in DataStore's protobuf format ---

    private fun varint(out: ByteArrayOutputStream, value: Int) {
        var v = value
        while (v >= 0x80) { out.write((v and 0x7F) or 0x80); v = v ushr 7 }
        out.write(v)
    }

    private fun lengthDelimited(field: Int, bytes: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        varint(out, (field shl 3) or 2)
        varint(out, bytes.size)
        out.write(bytes)
        return out.toByteArray()
    }

    private fun boolValue(value: Boolean) = byteArrayOf(0x08, if (value) 1 else 0)
    private fun stringValue(value: String) = lengthDelimited(5, value.toByteArray())
    private fun listValue(vararg items: String) =
        stringValue(LIST_PREFIX + JSONArray(items.toList()).toString())

    private fun entry(key: String, value: ByteArray) =
        lengthDelimited(1, lengthDelimited(1, key.toByteArray()) + lengthDelimited(2, value))

    private fun writeFile(vararg entries: ByteArray) {
        dataStoreDir.mkdirs()
        dataStoreFile.writeBytes(entries.fold(ByteArray(0)) { all, e -> all + e })
    }

    // --- Tests ---

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
    fun readData_readsAFileSavedByTheApp() {
        dataStoreDir.mkdirs()
        dataStoreFile.writeBytes(Base64.decode(REAL_FILE_BASE64, Base64.DEFAULT))

        val data = DataStoreReader.readData(context)

        assertTrue(data.isBlockingEnabled)
        assertEquals(
            setOf("pornhub.com", "xvideos.com", "xnxx.com", "redtube.com", "youporn.com"),
            data.blockedSites,
        )
        assertEquals(setOf("porn", "sex", "xxx", "zoo"), data.blockedKeywords)
        assertEquals(setOf("example.com", "anotherexample.com"), data.whitelistedSites)
    }

    @Test
    fun readData_readsEachSetting() {
        writeFile(
            entry("is_blocking_enabled", boolValue(true)),
            entry("blocked_sites", listValue("Example.com", "gambling.org")),
            entry("blocked_keywords", listValue("porn", "casino")),
            entry("whitelisted_sites", listValue("safe.com")),
            entry("blocked_apps", listValue("com.example.badapp")),
            entry("custom_dns", stringValue("1.1.1.1")),
        )

        val data = DataStoreReader.readData(context)

        assertTrue(data.isBlockingEnabled)
        assertEquals(setOf("example.com", "gambling.org"), data.blockedSites)
        assertEquals(setOf("porn", "casino"), data.blockedKeywords)
        assertEquals(setOf("safe.com"), data.whitelistedSites)
        assertEquals(setOf("com.example.badapp"), data.blockedApps)
        assertEquals("1.1.1.1", data.customDns)
    }

    @Test
    fun readData_matchesKeysExactly() {
        // Keys that contain the real names, saved before them, must be ignored
        writeFile(
            entry("user_blocked_keywords", listValue("userword")),
            entry("user_whitelisted_sites", listValue("user.com")),
            entry("has_seen_blocked_apps_tour", boolValue(true)),
            entry("some_list", listValue("com.wrong.app")),
            entry("blocked_keywords", listValue("finalword")),
            entry("whitelisted_sites", listValue("final.com")),
            entry("blocked_apps", listValue("com.right.app")),
        )

        val data = DataStoreReader.readData(context)

        assertEquals(setOf("finalword"), data.blockedKeywords)
        assertEquals(setOf("final.com"), data.whitelistedSites)
        assertEquals(setOf("com.right.app"), data.blockedApps)
    }

    @Test
    fun readData_blockingOffIsNotChangedByOtherTrueValues() {
        writeFile(
            entry("is_blocking_enabled", boolValue(false)),
            entry("has_seen_protection_tour", boolValue(true)),
            entry("lock_settings", boolValue(true)),
        )

        assertFalse(DataStoreReader.readData(context).isBlockingEnabled)
    }

    @Test
    fun readData_missingBlockingSettingMeansOff() {
        writeFile(entry("has_seen_protection_tour", boolValue(true)))
        assertFalse(DataStoreReader.readData(context).isBlockingEnabled)
    }

    @Test
    fun readData_readsStringSets() {
        val set = lengthDelimited(1, "a.com".toByteArray()) + lengthDelimited(1, "b.com".toByteArray())
        writeFile(entry("blocked_sites", lengthDelimited(6, set)))

        assertEquals(setOf("a.com", "b.com"), DataStoreReader.readData(context).blockedSites)
    }

    @Test
    fun readData_skipsOtherValueTypes() {
        writeFile(
            entry("blocked_websites_count", byteArrayOf(0x20, 42)), // long
            entry("is_blocking_enabled", boolValue(true)),
        )
        assertTrue(DataStoreReader.readData(context).isBlockingEnabled)
    }

    @Test
    fun readDataCached_returnsTheSameResultWhileTheFileIsUnchanged() {
        writeFile(entry("blocked_sites", listValue("a.com")))

        val first = DataStoreReader.readDataCached(context)
        val second = DataStoreReader.readDataCached(context)

        assertEquals(setOf("a.com"), first.blockedSites)
        assertSame(first, second)
    }

    @Test
    fun readDataCached_picksUpASaveMadeTheWayDataStoreDoesIt() {
        writeFile(entry("is_blocking_enabled", boolValue(false)))
        assertFalse(DataStoreReader.readDataCached(context).isBlockingEnabled)

        // DataStore writes a new file and renames it over the old one. Same
        // size as before, so only the new inode shows the change.
        val scratch = File(dataStoreDir, dataStoreFile.name + ".tmp")
        scratch.writeBytes(entry("is_blocking_enabled", boolValue(true)))
        assertTrue(scratch.renameTo(dataStoreFile))

        assertTrue(DataStoreReader.readDataCached(context).isBlockingEnabled)
    }

    @Test
    fun readDataCached_withoutAFileGivesDefaults() {
        writeFile(entry("is_blocking_enabled", boolValue(true)))
        assertTrue(DataStoreReader.readDataCached(context).isBlockingEnabled)

        dataStoreFile.delete()

        assertFalse(DataStoreReader.readDataCached(context).isBlockingEnabled)
    }

    @Test
    fun readData_aDamagedFileGivesDefaults() {
        dataStoreDir.mkdirs()
        dataStoreFile.writeBytes(byteArrayOf(0x0A, 0x7F, 0x01, 0x02))

        val data = DataStoreReader.readData(context)

        assertFalse(data.isBlockingEnabled)
        assertTrue(data.blockedSites.isEmpty())
    }
}
