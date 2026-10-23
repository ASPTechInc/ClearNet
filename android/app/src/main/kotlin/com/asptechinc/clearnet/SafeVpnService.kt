// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

/**
 * Local VPN that filters DNS.
 *
 * The VPN gives the device a virtual DNS server, so every DNS query arrives on
 * the VPN interface. Queries for blocked domains get NXDOMAIN, Google, Bing and
 * YouTube get their SafeSearch addresses, and everything else is forwarded to
 * the upstream DNS server over a socket that bypasses the VPN.
 *
 * Plain DNS sent straight to well-known public resolvers is filtered the same
 * way. Encrypted DNS (DoT/DoH) to those resolvers is dropped, so Private DNS
 * and browser "secure DNS" fail closed instead of bypassing the filter.
 */
class SafeVpnService : VpnService(), Runnable {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var output: FileOutputStream? = null
    private var readerThread: Thread? = null
    private var forwarders: ExecutorService? = null
    private val blockedSites = ConcurrentHashMap.newKeySet<String>()
    private val blockedKeywords = ConcurrentHashMap.newKeySet<String>()
    private val whitelistedSites = ConcurrentHashMap.newKeySet<String>()
    @Volatile private var upstreamServers: List<InetAddress> = emptyList()
    @Volatile private var running = false

    private var startTime: Long = 0
    private val totalPacketsProcessed = AtomicLong()
    private val packetsBlocked = AtomicLong()

    companion object {
        const val TAG = "SafeVpnService"
        const val ACTION_STOP = "com.asptechinc.clearnet.STOP_VPN"
        // Lets MainActivity pass list changes to the running VPN straight away.
        // Otherwise the lists are only read again when the service is started.
        var instance: SafeVpnService? = null

        // Private addresses unlikely to clash with a home or mobile network.
        // VIRTUAL_DNS isn't a real server: it's the DNS address the VPN gives
        // the device, and the reader thread answers everything sent to it.
        private const val VPN_ADDRESS = "10.111.222.1"
        private const val VIRTUAL_DNS = "10.111.222.2"
        // Android only allows IPv6 routes on a VPN that has an IPv6 address.
        // It's needed so the IPv6 public resolver routes below can be added.
        private const val VPN_ADDRESS_V6 = "fd00:111:222::1"
        private const val UPSTREAM_TIMEOUT_MS = 4000

        // Must accept plain DNS on port 53. Mullvad's public DNS only accepts DoH/DoT.
        private val DEFAULT_UPSTREAMS = listOf(
            "91.239.100.100", // UncensoredDNS
            "94.140.14.14",   // AdGuard DNS
            "9.9.9.9"         // Quad9
        )

        // Public resolvers routed into the VPN. Plain DNS to them is filtered and
        // forwarded; DoT and DoH to them is dropped.
        private val PUBLIC_RESOLVERS_V4 = listOf(
            "8.8.8.8", "8.8.4.4",                                    // Google
            "1.1.1.1", "1.0.0.1", "1.1.1.2", "1.0.0.2", "1.1.1.3", "1.0.0.3", // Cloudflare
            "9.9.9.9", "149.112.112.112", "9.9.9.10", "149.112.112.10",
            "9.9.9.11", "149.112.112.11",                            // Quad9
            "208.67.222.222", "208.67.220.220", "208.67.222.123", "208.67.220.123", // OpenDNS
            "94.140.14.14", "94.140.15.15", "94.140.14.15", "94.140.15.16",
            "94.140.14.140", "94.140.14.141",                        // AdGuard
            "185.228.168.9", "185.228.169.9", "185.228.168.10", "185.228.169.11",
            "185.228.168.168", "185.228.169.168",                    // CleanBrowsing
            "91.239.100.100", "89.233.43.71",                        // UncensoredDNS
            "76.76.2.0", "76.76.10.0",                               // Control D
            "45.90.28.0", "45.90.30.0"                               // NextDNS
        )
        // Mullvad serves DNS from several addresses in this /24, so the whole
        // range is routed. It only offers DoH/DoT, so this traffic is dropped.
        private const val MULLVAD_DNS_RANGE = "194.242.2.0"
        private val PUBLIC_RESOLVERS_V6 = listOf(
            "2001:4860:4860::8888", "2001:4860:4860::8844",
            "2606:4700:4700::1111", "2606:4700:4700::1001",
            "2606:4700:4700::1112", "2606:4700:4700::1002",
            "2606:4700:4700::1113", "2606:4700:4700::1003",
            "2620:fe::fe", "2620:fe::9", "2620:fe::10", "2620:fe::fe:10",
            "2620:fe::11", "2620:fe::fe:11",
            "2620:119:35::35", "2620:119:53::53",
            "2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff", "2a10:50c0::1:ff", "2a10:50c0::2:ff"
        )
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    fun addBlockedSite(site: String) {
        blockedSites.add(site.lowercase())
        Log.i(TAG, "Added blocked site: $site")
    }

    fun removeBlockedSite(site: String) {
        blockedSites.remove(site.lowercase())
        Log.i(TAG, "Removed blocked site: $site")
    }

    fun addBlockedKeyword(keyword: String) {
        blockedKeywords.add(keyword.lowercase())
        Log.i(TAG, "Added blocked keyword: $keyword")
    }

    fun removeBlockedKeyword(keyword: String) {
        blockedKeywords.remove(keyword.lowercase())
        Log.i(TAG, "Removed blocked keyword: $keyword")
    }

    fun addWhitelistedSite(whitelist: String) {
        whitelistedSites.add(whitelist.lowercase())
        Log.i(TAG, "Added whitelisted site: $whitelist")
    }

    fun removeWhitelistedSite(whitelist: String) {
        whitelistedSites.remove(whitelist.lowercase())
        Log.i(TAG, "Removed whitelisted site: $whitelist")
    }

    /**
     * Loads the lists and upstream servers, then builds the VPN interface and
     * starts the packet thread if they aren't running yet.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val data = DataStoreReader.readData(this)

        if (intent?.action == ACTION_STOP || !data.isBlockingEnabled) {
            stopVpn()
            return START_NOT_STICKY
        }

        blockedSites.clear()
        blockedKeywords.clear()
        whitelistedSites.clear()

        blockedSites.addAll(data.blockedSites.map { it.lowercase() })
        blockedKeywords.addAll(data.blockedKeywords.map { it.lowercase() })
        whitelistedSites.addAll(data.whitelistedSites.map { it.lowercase() })

        upstreamServers = resolveUpstreams(data.customDns)

        if (vpnInterface == null) {
            startTime = System.currentTimeMillis()
            val builder = Builder()
                .setSession("ClearNet")
                .addAddress(VPN_ADDRESS, 32)
                .addAddress(VPN_ADDRESS_V6, 128)
                .addDnsServer(VIRTUAL_DNS)
                .addRoute(VIRTUAL_DNS, 32)
                .addRoute(MULLVAD_DNS_RANGE, 24)
            PUBLIC_RESOLVERS_V4.forEach { builder.addRoute(it, 32) }
            PUBLIC_RESOLVERS_V6.forEach { builder.addRoute(it, 128) }

            vpnInterface = builder.establish()
            output = vpnInterface?.let { FileOutputStream(it.fileDescriptor) }
        }

        if (readerThread == null && vpnInterface != null) {
            running = true
            // Forwarded lookups wait on the network (up to 4 s per server), so
            // they run on their own threads and don't hold up the reader
            forwarders = Executors.newFixedThreadPool(8)
            readerThread = thread(start = true, name = "ClearNetVpnReader") { run() }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopVpn()
        instance = null
        super.onDestroy()
    }

    /**
     * Closes the VPN interface. stopService() alone doesn't do this, because the
     * system stays bound to a VPN service while its interface is open.
     */
    private fun stopVpn() {
        running = false
        forwarders?.shutdownNow()
        forwarders = null
        readerThread = null
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Could not close the VPN interface", e)
        }
        vpnInterface = null
        output = null
        stopSelf()
    }

    /**
     * Uses the custom DNS server if it's a valid IP address, otherwise the
     * default servers.
     */
    private fun resolveUpstreams(customDns: String): List<InetAddress> {
        val custom = customDns.trim()
        if (custom.isNotEmpty() && custom.matches(Regex("^[0-9a-fA-F:.]+$"))) {
            try {
                Log.i(TAG, "Using custom DNS server: $custom")
                return listOf(InetAddress.getByName(custom))
            } catch (e: Exception) {
                Log.w(TAG, "Invalid custom DNS server '$custom', falling back to default servers", e)
            }
        }
        Log.i(TAG, "Using default DNS servers")
        return DEFAULT_UPSTREAMS.map { InetAddress.getByName(it) }
    }

    /**
     * Reads packets from the VPN interface. DNS queries are answered or
     * forwarded; everything else (such as DoT and DoH to public resolvers) is
     * dropped.
     */
    override fun run() {
        val vpn = vpnInterface ?: return
        val fd = vpn.fileDescriptor
        val input = FileInputStream(fd)
        // Larger than any packet the VPN interface delivers
        val buffer = ByteArray(32767)
        val pollFd = StructPollfd().apply {
            this.fd = fd
            events = OsConstants.POLLIN.toShort()
        }

        try {
            // Stop when this interface is closed, even if a new one has been started
            while (running && vpnInterface === vpn) {
                // Wait up to a second for a packet, so the loop notices when the VPN stops
                pollFd.revents = 0
                if (Os.poll(arrayOf(pollFd), 1000) <= 0) continue
                val length = input.read(buffer)
                if (length <= 0) continue
                totalPacketsProcessed.incrementAndGet()

                // IPv4 only: byte 0 holds the version and header length
                if ((buffer[0].toInt() shr 4) != 4) continue
                val ipHeaderLength = (buffer[0].toInt() and 0x0F) * 4
                // Byte 9 is the protocol (17 = UDP)
                if (buffer[9].toInt() != 17) continue
                val udp = ipHeaderLength
                val destPort = ((buffer[udp + 2].toInt() and 0xFF) shl 8) or (buffer[udp + 3].toInt() and 0xFF)
                // Needs at least the 8-byte UDP header and the 12-byte DNS header
                if (destPort != 53 || length < udp + 8 + 12) continue

                handleDnsQuery(buffer.copyOf(length), udp)
            }
        } catch (e: Exception) {
            if (running && vpnInterface === vpn) Log.e(TAG, "VPN reader stopped", e)
        }
    }

    private fun handleDnsQuery(packet: ByteArray, udp: Int) {
        val query = packet.copyOfRange(udp + 8, packet.size)
        val question = DnsPacket.parseQuestion(query) ?: return
        val domain = question.name

        if (shouldBlockDomain(domain) || domain in DnsPacket.DOH_HOSTS) {
            Log.i(TAG, "Blocked DNS lookup: $domain")
            // Browsers look up A, AAAA and HTTPS records together; count the site once
            if (question.type == DnsPacket.TYPE_A) incrementBlockCount()
            reply(packet, udp, DnsPacket.buildResponse(query, question, DnsPacket.RCODE_NXDOMAIN, null))
            return
        }

        val safeIp = DnsPacket.safeSearchIp(domain)
        if (safeIp != null) {
            // A records get the SafeSearch address. Other types (AAAA, HTTPS)
            // get an empty answer so they can't route around SafeSearch.
            val answer = if (question.type == DnsPacket.TYPE_A) safeIp else null
            reply(packet, udp, DnsPacket.buildResponse(query, question, DnsPacket.RCODE_NOERROR, answer))
            return
        }

        forwarders?.execute { forward(packet, udp, query, question) }
    }

    /**
     * Sends the query to each upstream server in turn until one answers, then
     * writes the answer back to the VPN interface.
     */
    private fun forward(packet: ByteArray, udp: Int, query: ByteArray, question: DnsPacket.Question) {
        for (server in upstreamServers) {
            try {
                DatagramSocket().use { socket ->
                    if (!protect(socket)) {
                        Log.w(TAG, "Could not exclude the DNS socket from the VPN")
                        return
                    }
                    socket.soTimeout = UPSTREAM_TIMEOUT_MS
                    socket.send(DatagramPacket(query, query.size, server, 53))
                    val responseBuffer = ByteArray(4096)
                    val response = DatagramPacket(responseBuffer, responseBuffer.size)
                    socket.receive(response)
                    reply(packet, udp, responseBuffer.copyOf(response.length))
                    return
                }
            } catch (e: Exception) {
                Log.w(TAG, "DNS server ${server.hostAddress} failed for ${question.name}: ${e.message}")
            }
        }
        reply(packet, udp, DnsPacket.buildResponse(query, question, DnsPacket.RCODE_SERVFAIL, null))
    }

    /**
     * Wraps a DNS payload in an IPv4/UDP packet addressed back to the sender of
     * [request] and writes it to the VPN interface.
     */
    private fun reply(request: ByteArray, udp: Int, dnsPayload: ByteArray) {
        val packet = DnsPacket.buildReplyPacket(request, udp, dnsPayload)
        try {
            val out = output ?: return
            synchronized(out) { out.write(packet) }
        } catch (e: Exception) {
            if (running) Log.w(TAG, "Could not write DNS response", e)
        }
    }

    private fun incrementBlockCount() {
        packetsBlocked.incrementAndGet()
        try {
            NativeStatsManager.incrementBlockedWebsite(this)
        } catch (e: Exception) {
            Log.w(TAG, "Could not update block statistics", e)
        }
    }

    /**
     * Whitelisted domains are never blocked.
     */
    internal fun shouldBlockDomain(domain: String): Boolean =
        DomainRules.shouldBlockDomain(domain, blockedSites, blockedKeywords, whitelistedSites)

    fun getUptimeMinutes(): Long {
        if (startTime == 0L) return 0
        return (System.currentTimeMillis() - startTime) / 60000
    }

    fun getPacketsProcessed(): Long = totalPacketsProcessed.get()
    fun getPacketsBlocked(): Long = packetsBlocked.get()
}
