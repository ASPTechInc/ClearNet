// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.Context
import android.system.Os
import android.util.Log
import java.io.File
import org.json.JSONArray

/**
 * Reads the settings the Flutter app saves with SharedPreferencesAsync, so the
 * VPN and accessibility service can use them. Native code can't call the Flutter
 * plugin, so this reads the DataStore file directly. Values are looked up by
 * their exact Dart key names (such as 'blocked_sites' and 'is_blocking_enabled'),
 * so those names are shared with this file.
 */
object DataStoreReader {
    private const val TAG = "DataStoreReader"

    // The shared_preferences plugin saves a list as text: this prefix, then JSON
    private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"

    class DataStoreData(
        val isBlockingEnabled: Boolean = false,
        val blockedSites: Set<String> = emptySet(),
        val blockedKeywords: Set<String> = emptySet(),
        val whitelistedSites: Set<String> = emptySet(),
        val blockedApps: Set<String> = emptySet(),
        val customDns: String = ""
    )

    // The last result of readDataCached() and the file it was read from
    private var cachedVersion: List<Long>? = null
    private var cachedData: DataStoreData? = null

    private fun dataStoreFile(context: Context) =
        File(context.filesDir, "datastore/FlutterSharedPreferences.preferences_pb")

    /**
     * Like [readData], but only reads the file again after it has changed. For
     * callers that read on every event, such as the accessibility service.
     */
    @Synchronized
    fun readDataCached(context: Context): DataStoreData {
        val version = fileVersion(dataStoreFile(context))
        val cached = cachedData
        if (version != null && version == cachedVersion && cached != null) return cached

        val data = readData(context)
        cachedVersion = version
        cachedData = data
        return data
    }

    /**
     * Identifies one saved version of [file]. DataStore saves by writing a new
     * file and renaming it over the old one, so the inode changes on every
     * save; the time and size catch files rewritten in place.
     */
    private fun fileVersion(file: File): List<Long>? = try {
        val stat = Os.stat(file.path)
        listOf(stat.st_ino, file.lastModified(), stat.st_size)
    } catch (e: Exception) {
        null
    }

    fun readData(context: Context): DataStoreData {
        val dataStoreFile = dataStoreFile(context)
        if (!dataStoreFile.exists()) {
            Log.w(TAG, "DataStore file does not exist: ${dataStoreFile.absolutePath}")
            return DataStoreData()
        }

        return try {
            fromPreferences(parsePreferences(dataStoreFile.readBytes()))
        } catch (e: Exception) {
            Log.e(TAG, "Could not read the DataStore file", e)
            DataStoreData()
        }
    }

    internal fun fromPreferences(prefs: Map<String, Any>): DataStoreData = DataStoreData(
        isBlockingEnabled = prefs["is_blocking_enabled"] == true,
        blockedSites = readList(prefs["blocked_sites"]),
        blockedKeywords = readList(prefs["blocked_keywords"]),
        whitelistedSites = readList(prefs["whitelisted_sites"]),
        blockedApps = readList(prefs["blocked_apps"]),
        customDns = (prefs["custom_dns"] as? String)?.trim() ?: "",
    )

    /** Reads a list saved by the plugin, or a string set. Anything else is empty. */
    private fun readList(value: Any?): Set<String> {
        val items = when (value) {
            is String -> {
                if (!value.startsWith(LIST_PREFIX)) return emptySet()
                val json = JSONArray(value.substring(LIST_PREFIX.length))
                (0 until json.length()).map { json.getString(it) }
            }
            is Set<*> -> value.filterIsInstance<String>()
            else -> return emptySet()
        }
        return items.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.toSet()
    }

    /**
     * Decodes DataStore's PreferenceMap protobuf: a list of key and value
     * entries (field 1), each value holding one typed field. Returns booleans,
     * strings, numbers and string sets; other types are skipped.
     */
    internal fun parsePreferences(bytes: ByteArray): Map<String, Any> {
        val prefs = mutableMapOf<String, Any>()
        val map = ProtoReader(bytes)
        while (map.hasMore()) {
            val (field, wireType) = map.readTag()
            if (field != 1 || wireType != 2) { map.skip(wireType); continue }
            val entry = ProtoReader(map.readBytes())
            var key: String? = null
            var value: Any? = null
            while (entry.hasMore()) {
                val (entryField, entryWire) = entry.readTag()
                when {
                    entryField == 1 && entryWire == 2 -> key = String(entry.readBytes(), Charsets.UTF_8)
                    entryField == 2 && entryWire == 2 -> value = readValue(entry.readBytes())
                    else -> entry.skip(entryWire)
                }
            }
            if (key != null && value != null) prefs[key] = value
        }
        return prefs
    }

    // Value message fields: 1 boolean, 2 float, 3 int, 4 long, 5 string,
    // 6 string set, 7 double, 8 bytes
    private fun readValue(bytes: ByteArray): Any? {
        val value = ProtoReader(bytes)
        while (value.hasMore()) {
            val (field, wireType) = value.readTag()
            when (field) {
                1 -> return value.readVarint() != 0L
                2 -> return java.lang.Float.intBitsToFloat(value.readFixed32())
                3, 4 -> return value.readVarint()
                5 -> return String(value.readBytes(), Charsets.UTF_8)
                6 -> {
                    val set = mutableSetOf<String>()
                    val strings = ProtoReader(value.readBytes())
                    while (strings.hasMore()) {
                        val (stringField, stringWire) = strings.readTag()
                        if (stringField == 1 && stringWire == 2) {
                            set.add(String(strings.readBytes(), Charsets.UTF_8))
                        } else {
                            strings.skip(stringWire)
                        }
                    }
                    return set
                }
                7 -> return java.lang.Double.longBitsToDouble(value.readFixed64())
                else -> value.skip(wireType)
            }
        }
        return null
    }

    /** Reads the protobuf wire format, which is all this file needs. */
    private class ProtoReader(private val bytes: ByteArray) {
        private var pos = 0

        fun hasMore() = pos < bytes.size

        fun readVarint(): Long {
            var result = 0L
            var shift = 0
            while (true) {
                if (pos >= bytes.size || shift > 63) throw IllegalArgumentException("Bad varint")
                val b = bytes[pos++].toInt() and 0xFF
                result = result or ((b and 0x7F).toLong() shl shift)
                if (b < 0x80) return result
                shift += 7
            }
        }

        fun readTag(): Pair<Int, Int> {
            val tag = readVarint().toInt()
            return (tag ushr 3) to (tag and 7)
        }

        fun readBytes(): ByteArray {
            val length = readVarint().toInt()
            if (length < 0 || pos + length > bytes.size) throw IllegalArgumentException("Bad length")
            return bytes.copyOfRange(pos, pos + length).also { pos += length }
        }

        fun readFixed32(): Int {
            if (pos + 4 > bytes.size) throw IllegalArgumentException("Truncated")
            var result = 0
            for (i in 0 until 4) result = result or ((bytes[pos + i].toInt() and 0xFF) shl (8 * i))
            pos += 4
            return result
        }

        fun readFixed64(): Long {
            if (pos + 8 > bytes.size) throw IllegalArgumentException("Truncated")
            var result = 0L
            for (i in 0 until 8) result = result or ((bytes[pos + i].toLong() and 0xFF) shl (8 * i))
            pos += 8
            return result
        }

        fun skip(wireType: Int) {
            when (wireType) {
                0 -> readVarint()
                1 -> readFixed64()
                2 -> readBytes()
                5 -> readFixed32()
                else -> throw IllegalArgumentException("Unknown wire type $wireType")
            }
        }
    }
}
