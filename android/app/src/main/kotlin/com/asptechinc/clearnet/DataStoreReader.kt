package com.asptechinc.clearnet

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileInputStream

object DataStoreReader {
    private const val TAG = "DataStoreReader"

    class DataStoreData(
        val isBlockingEnabled: Boolean = false,
        val blockedSites: Set<String> = emptySet(),
        val blockedKeywords: Set<String> = emptySet(),
        val whitelistedSites: Set<String> = emptySet(),
        val blockedApps: Set<String> = emptySet(),
        val customDns: String = ""
    )

    fun readData(context: Context): DataStoreData {
        val dataStoreFile = File(context.filesDir, "datastore/FlutterSharedPreferences.preferences_pb")
        if (!dataStoreFile.exists()) {
            Log.w(TAG, "DataStore file does not exist: ${dataStoreFile.absolutePath}")
            return DataStoreData()
        }

        try {
            val bytes = FileInputStream(dataStoreFile).use { it.readBytes() }
            val content = String(bytes, Charsets.ISO_8859_1)

            // Extract is_blocking_enabled
            // Proto layout: key string 'is_blocking_enabled', followed by type/value info.
            // SharedPreferencesAsync places \u0012\u0002\u0008\u0001 for true, \u0012\u0002\u0008\u0000 for false.
            val isBlockingEnabledIdx = content.indexOf("is_blocking_enabled")
            var isBlockingEnabled = false
            if (isBlockingEnabledIdx != -1) {
                val sub = content.substring(isBlockingEnabledIdx)
                // Search for the boolean value flag or text check
                if (sub.contains("\u0008\u0001") || sub.contains("\u0012\u0002\u0008\u0001") || sub.contains("\u0012\u0001\u0001")) {
                    isBlockingEnabled = true
                } else {
                    // Fail-safe substring scan in the trailing 40 chars
                    val endBound = minOf(sub.length, 40)
                    val searchSegment = sub.substring(0, endBound)
                    if (searchSegment.contains("\u0001")) {
                        isBlockingEnabled = true
                    }
                }
            }

            // Extract Lists using the JSON array literal fallback string layout
            val blockedSites = extractList(content, "blocked_sites")
            val blockedKeywords = extractList(content, "blocked_keywords")
            val whitelistedSites = extractList(content, "whitelisted_sites")
            val blockedApps = extractList(content, "blocked_apps")
            val customDns = extractString(content, "custom_dns")

            Log.d(TAG, "Successfully parsed Jetpack DataStore: enabled=$isBlockingEnabled, sitesCount=${blockedSites.size}, keywordsCount=${blockedKeywords.size}, whitelistCount=${whitelistedSites.size}, blockedAppsCount=${blockedApps.size}, customDns=$customDns")
            return DataStoreData(isBlockingEnabled, blockedSites, blockedKeywords, whitelistedSites, blockedApps, customDns)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing Jetpack DataStore file", e)
            return DataStoreData()
        }
    }

    private fun extractString(content: String, key: String): String {
        val index = content.indexOf(key)
        if (index == -1) return ""

        val sub = content.substring(index + key.length)
        val maxWindow = minOf(sub.length, 100)
        val window = sub.substring(0, maxWindow)

        val sb = StringBuilder()
        var recording = false
        for (ch in window) {
            if (ch.isLetterOrDigit() || ch == '.' || ch == '-' || ch == ':') {
                recording = true
                sb.append(ch)
            } else if (recording) {
                if (sb.length >= 3) {
                    break
                } else {
                    sb.clear()
                    recording = false
                }
            }
        }
        val result = sb.toString().trim()
        return if (result.length >= 3) result else ""
    }

    private fun extractList(content: String, key: String): Set<String> {
        val index = content.indexOf(key)
        if (index == -1) return emptySet()

        val sub = content.substring(index)
        val startBracket = sub.indexOf("[")
        val endBracket = sub.indexOf("]")
        if (startBracket == -1 || endBracket == -1 || endBracket < startBracket) return emptySet()

        val jsonArrayStr = sub.substring(startBracket + 1, endBracket)
        if (jsonArrayStr.trim().isEmpty()) return emptySet()

        return jsonArrayStr.split(",")
            .map { it.trim().replace("\"", "").lowercase() }
            .filter { it.isNotEmpty() }
            .toSet()
    }
}
