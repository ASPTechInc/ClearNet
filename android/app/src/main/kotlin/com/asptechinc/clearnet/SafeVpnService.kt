package com.asptechinc.clearnet

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/**
 * SafeVpnService acts as a local DNS sinkhole and content-filtering agent using Android's VpnService API.
 * It routes and intercepts local network traffic to parse and evaluate DNS requests against domain and keyword lists,
 * performing zero-latency dropping of adult/gambling packets or forcing SafeSearch VIP redirection for search engines.
 */
class SafeVpnService : VpnService(), Runnable {

    private var vpnInterface: ParcelFileDescriptor? = null
    private val blockedSites = ConcurrentHashMap.newKeySet<String>()
    private val blockedKeywords = ConcurrentHashMap.newKeySet<String>()
    private var running = false

    // Virtual IP mapping configurations for forcing Google and Bing SafeSearch VIP routes
    private val SAFE_SEARCH_VIP_GOOGLE = byteArrayOf(216.toByte(), 239.toByte(), 38.toByte(), 120.toByte())
    private val SAFE_SEARCH_VIP_BING = byteArrayOf(204.toByte(), 79.toByte(), 197.toByte(), 220.toByte())

    companion object {
        const val TAG = "SafeVpnService"
        var instance: SafeVpnService? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    /** 
     * Dynamically appends a new restricted domain pattern to the local filter. 
     */
    fun addBlockedSite(site: String) {
        blockedSites.add(site.lowercase())
        Log.i(TAG, "Added blocked site: $site")
    }

    /** 
     * Dynamically removes a restricted domain pattern from the local filter. 
     */
    fun removeBlockedSite(site: String) {
        blockedSites.remove(site.lowercase())
        Log.i(TAG, "Removed blocked site: $site")
    }

    /** 
     * Dynamically appends a new restricted keyword string pattern to the local filter. 
     */
    fun addBlockedKeyword(keyword: String) {
        blockedKeywords.add(keyword.lowercase())
        Log.i(TAG, "Added blocked keyword: $keyword")
    }

    /** 
     * Dynamically removes a restricted keyword string pattern from the local filter. 
     */
    fun removeBlockedKeyword(keyword: String) {
        blockedKeywords.remove(keyword.lowercase())
        Log.i(TAG, "Removed blocked keyword: $keyword")
    }

    /**
     * Initialises service parameters, reads preference data clusters, configurations,
     * builds the virtual TUN interface parameters, and spins up the worker reading thread.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isBlockingEnabled = prefs.getBoolean("flutter.is_blocking_enabled", false)
        
        if (!isBlockingEnabled) {
            stopSelf()
            return START_NOT_STICKY
        }

        blockedSites.clear()
        blockedKeywords.clear()

        // Load Blocked Domains from preferences
        try {
            val savedSites = prefs.getStringSet("flutter.blocked_sites", null)
            if (savedSites != null) {
                blockedSites.addAll(savedSites.map { it.lowercase() })
            }
        } catch (e: Exception) {
            val jsonStr = prefs.getString("flutter.blocked_sites", null)
            if (jsonStr != null) {
                val cleaned = jsonStr.replace("[", "").replace("]", "").replace("\"", "")
                val sites = cleaned.split(",")
                for (site in sites) {
                    val trimmed = site.trim().lowercase()
                    if (trimmed.isNotEmpty()) {
                        blockedSites.add(trimmed)
                    }
                }
            }
        }

        // Load Blocked Keywords from preferences
        try {
            val savedKeywords = prefs.getStringSet("flutter.blocked_keywords", null)
            if (savedKeywords != null) {
                blockedKeywords.addAll(savedKeywords.map { it.lowercase() })
            }
        } catch (e: Exception) {
            val jsonStr = prefs.getString("flutter.blocked_keywords", null)
            if (jsonStr != null) {
                val cleaned = jsonStr.replace("[", "").replace("]", "").replace("\"", "")
                val words = cleaned.split(",")
                for (word in words) {
                    val trimmed = word.trim().lowercase()
                    if (trimmed.isNotEmpty()) {
                        blockedKeywords.add(trimmed)
                    }
                }
            }
        }

        // Establish the VpnInterface connection descriptor if not yet created
        if (vpnInterface == null) {
            val builder = Builder()
            builder.addAddress("10.0.0.2", 32)
            
            val customDns = prefs.getString("flutter.custom_dns", "")?.trim() ?: ""
            if (customDns.isNotEmpty()) {
                builder.addDnsServer(customDns)
                builder.addRoute(customDns, 32)
                Log.i(TAG, "Configuring single custom DNS upstream: $customDns")
            } else {
                // FOSS pool strategy: Add multiple reliable FOSS alternative backbones
                // If any upstream drops or gets interrupted, the system automatically cycles through remaining operational ones.
                val fossPool = listOf(
                    "194.242.2.14",  // Mullvad DNS (Ad/Gamble blocking)
                    "91.239.100.100", // UncensoredDNS (Anycast)
                    "94.140.14.14"    // AdGuard DNS (Default Protection)
                )
                for (dns in fossPool) {
                    builder.addDnsServer(dns)
                    builder.addRoute(dns, 32)
                }
                Log.i(TAG, "Configuring reliable fallback FOSS DNS pool cluster")
            }
            
            vpnInterface = builder.establish()
        }
        running = true
        thread(start = true) { run() }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        vpnInterface?.close()
        instance = null
        super.onDestroy()
    }

    /**
     * Primary loop running in a background thread.
     * Reads raw IP packets from the TUN interface descriptor, processes UDP DNS queries,
     * and performs local spoofing or filtering responses directly.
     */
    override fun run() {
        val fd = vpnInterface?.fileDescriptor ?: return
        val input = FileInputStream(fd)
        val output = FileOutputStream(fd)
        val buffer = ByteArray(32767)

        try {
            while (running) {
                val length = input.read(buffer)
                if (length > 0) {
                    // Basic IPv4 + UDP packet header verification check
                    // Offset 9 contains the Protocol (17 = UDP)
                    // Offset 22-23 contains the Destination Port (53 = standard DNS)
                    if (length > 40 && buffer[9].toInt() == 17 && 
                        (buffer[22].toInt() and 0xFF) == 0 && (buffer[23].toInt() and 0xFF) == 53) {
                        
                        val domain = parseDnsQuery(buffer, length)
                        if (domain != null) {
                            val safeIp = getSafeSearchIp(domain)
                            
                            // If it's a search engine, rewrite the response payload to map to a SafeSearch VIP address
                            if (safeIp != null) {
                                Log.i(TAG, "Routing to SafeSearch: $domain -> ${safeIp.joinToString(".") { (it.toInt() and 0xFF).toString() }}")
                                val response = createDnsResponse(buffer, length, safeIp)
                                output.write(response)
                                continue
                            }

                            // Drop packet entirely if domain or text matches blacklisted targets
                            if (shouldBlockDomain(domain)) {
                                Log.i(TAG, "Blocked DNS resolution for: $domain")
                                incrementBlockCount()
                                continue // drop packet
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Increments persistent website restriction statistics counter.
     */
    private fun incrementBlockCount() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = prefs.getInt("flutter.blocked_websites_count", 0)
        prefs.edit().putInt("flutter.blocked_websites_count", current + 1).apply()
    }

    /**
     * Decodes standard QNAME label notations inside the UDP DNS packet body to look up text representation.
     */
    private fun parseDnsQuery(packet: ByteArray, length: Int): String? {
        try {
            // Skip IPv4 Header (20 bytes) + UDP Header (8 bytes) + DNS Fixed Header (12 bytes) = 40
            var index = 40 
            val parts = mutableListOf<String>()
            while (index < length) {
                val len = packet[index].toInt() and 0xFF
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

    /**
     * Determines whether a domain should enforce SafeSearch restrictions.
     */
    private fun getSafeSearchIp(domain: String): ByteArray? {
        val lower = domain.lowercase()
        return when {
            lower.contains("google.") || lower.contains("youtube.") -> SAFE_SEARCH_VIP_GOOGLE
            lower.contains("bing.com") -> SAFE_SEARCH_VIP_BING
            else -> null
        }
    }

    /**
     * Constructs a syntactically correct local DNS A-Record response packet.
     * Swaps source/destination fields and recalculates IPv4 header checksums.
     */
    private fun createDnsResponse(packet: ByteArray, length: Int, ip: ByteArray): ByteArray {
        val response = packet.copyOf(length + 16)
        
        // --- IP Header (20 bytes) ---
        System.arraycopy(packet, 16, response, 12, 4) // Source IP = Original Dest
        System.arraycopy(packet, 12, response, 16, 4) // Dest IP = Original Source
        val totalLen = length + 16
        response[2] = (totalLen shr 8).toByte()
        response[3] = (totalLen and 0xFF).toByte()
        response[10] = 0
        response[11] = 0
        val ipChecksum = calculateChecksum(response, 0, 20)
        response[10] = (ipChecksum shr 8).toByte()
        response[11] = (ipChecksum and 0xFF).toByte()

        // --- UDP Header (8 bytes) ---
        System.arraycopy(packet, 22, response, 20, 2) // Source Port = Original Dest Port
        System.arraycopy(packet, 20, response, 22, 2) // Dest Port = Original Source Port
        val udpLen = length - 20 + 16
        response[24] = (udpLen shr 8).toByte()
        response[25] = (udpLen and 0xFF).toByte()
        response[26] = 0
        response[27] = 0

        // --- DNS Header (12 bytes at offset 28) ---
        response[30] = 0x85.toByte() // Response flags: Authoritative, Recursion Available
        response[31] = 0x80.toByte()
        response[34] = 0 // ANCOUNT = 1
        response[35] = 1

        // --- DNS Answer (at original packet end) ---
        var offset = length
        response[offset++] = 0xc0.toByte() // Compression pointer
        response[offset++] = 0x0c.toByte() // to QNAME at offset 12 in DNS (28+12=40)
        response[offset++] = 0 // Type A
        response[offset++] = 1
        response[offset++] = 0 // Class IN
        response[offset++] = 1
        response[offset++] = 0 // TTL 60 seconds
        response[offset++] = 0
        response[offset++] = 0
        response[offset++] = 60
        response[offset++] = 0 // RDLength = 4 bytes
        response[offset++] = 4
        System.arraycopy(ip, 0, response, offset, 4)
        
        return response
    }

    /**
     * Standard Internet Checksum algorithm (RFC 1071) calculation helper.
     */
    private fun calculateChecksum(buffer: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        while (i < offset + length) {
            val upper = (buffer[i].toInt() and 0xff) shl 8
            val lower = if (i + 1 < offset + length) buffer[i + 1].toInt() and 0xff else 0
            sum += upper or lower
            i += 2
        }
        while (sum shr 16 != 0) {
            sum = (sum and 0xffff) + (sum shr 16)
        }
        return (sum.inv() and 0xffff)
    }

    /**
     * Checks if a domain string contains any of the blocked sites or blacklisted keywords.
     */
    private fun shouldBlockDomain(domain: String): Boolean {
        val lowerDomain = domain.lowercase()
        if (blockedSites.any { lowerDomain.contains(it) }) return true
        if (blockedKeywords.any { lowerDomain.contains(it) }) return true
        return false
    }
}
