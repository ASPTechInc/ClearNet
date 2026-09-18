package com.asptechinc.appcontrol

import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

class SafeVpnService : VpnService(), Runnable {

    private var vpnInterface: ParcelFileDescriptor? = null
    private val blockedSites = ConcurrentHashMap.newKeySet<String>()
    private var running = false

    companion object {
        const val TAG = "SafeVpnService"
    }

    /** Add or update a blocked site dynamically */
    fun addBlockedSite(site: String) {
        blockedSites.add(site.lowercase())
        Log.i(TAG, "Added blocked site: $site")
    }

    /** Remove a site dynamically if needed */
    fun removeBlockedSite(site: String) {
        blockedSites.remove(site.lowercase())
        Log.i(TAG, "Removed blocked site: $site")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (vpnInterface == null) {
            val builder = Builder()
            builder.addAddress("10.0.0.2", 32)
            builder.addRoute("0.0.0.0", 0)
            vpnInterface = builder.establish()
        }
        running = true
        thread(start = true) { run() }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        vpnInterface?.close()
        super.onDestroy()
    }

    override fun run() {
        val fd = vpnInterface?.fileDescriptor ?: return
        val input = FileInputStream(fd)
        val output = FileOutputStream(fd)
        val buffer = ByteArray(32767)

        try {
            while (running) {
                val length = input.read(buffer)
                if (length > 0) {
                    // For demo: check DNS packet
                    val domain = parseDnsQuery(buffer, length)
                    if (domain != null && shouldBlockDomain(domain)) {
                        Log.i(TAG, "Blocked DNS: $domain")
                        continue // drop packet
                    }
                    // Forwarding logic would go here
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /** Minimal DNS query parser */
    private fun parseDnsQuery(packet: ByteArray, length: Int): String? {
        try {
            var index = 12 // skip DNS header
            val parts = mutableListOf<String>()
            while (index < length) {
                val len = packet[index].toInt()
                if (len == 0) break
                if (index + 1 + len > length) break
                parts.add(String(packet, index + 1, len))
                index += len + 1
            }
            return if (parts.isNotEmpty()) parts.joinToString(".").lowercase() else null
        } catch (e: Exception) {
            return null
        }
    }

    /** Check domain against blockedSites + keywords */
    private fun shouldBlockDomain(domain: String): Boolean {
        val lowerDomain = domain.lowercase()
        if (blockedSites.any { lowerDomain.contains(it) }) return true
        val keywords = listOf("porn", "sex", "xxx", "adult")
        if (keywords.any { lowerDomain.contains(it) }) return true
        return false
    }
}
