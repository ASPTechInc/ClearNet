// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

/**
 * Reads DNS queries and builds the answers that SafeVpnService writes back to
 * the VPN interface. Kept separate from the service so it can be tested
 * without a running VPN.
 */
internal object DnsPacket {
    const val TYPE_A = 1
    const val TYPE_AAAA = 28
    const val RCODE_NOERROR = 0
    const val RCODE_SERVFAIL = 2
    const val RCODE_NXDOMAIN = 3

    // DNS-over-HTTPS server names. Answering these with NXDOMAIN makes browsers
    // fall back to the system DNS. use-application-dns.net tells Firefox to
    // turn its own DoH off.
    val DOH_HOSTS = setOf(
        "dns.google", "dns.google.com", "cloudflare-dns.com", "one.one.one.one",
        "dns.quad9.net", "doh.opendns.com", "dns.adguard-dns.com", "dns.adguard.com",
        "dns.nextdns.io", "doh.cleanbrowsing.org", "dns.mullvad.net", "dns.controld.com",
        "doh.dns.sb", "use-application-dns.net"
    )

    // Only the search sites themselves, so other Google services such as
    // Gmail and the Play Store keep their real addresses
    private val GOOGLE_SEARCH = Regex("^(www\\.)?google\\.[a-z]{2,3}(\\.[a-z]{2})?$")
    private val YOUTUBE_HOSTS = setOf(
        "www.youtube.com", "m.youtube.com", "youtube.com", "youtubei.googleapis.com",
        "youtube.googleapis.com", "www.youtube-nocookie.com"
    )
    private val BING_HOSTS = setOf("www.bing.com", "bing.com")

    // forcesafesearch.google.com and restrict.youtube.com
    val SAFE_SEARCH_GOOGLE = byteArrayOf(216.toByte(), 239.toByte(), 38, 120)
    // strict.bing.com
    val SAFE_SEARCH_BING = byteArrayOf(204.toByte(), 79, 197.toByte(), 220.toByte())

    /** The first question in a query. [end] is the offset just after it. */
    class Question(val name: String, val type: Int, val end: Int)

    /** The SafeSearch address for [domain], or null if it isn't a search site. */
    fun safeSearchIp(domain: String): ByteArray? = when {
        GOOGLE_SEARCH.matches(domain) -> SAFE_SEARCH_GOOGLE
        domain in YOUTUBE_HOSTS -> SAFE_SEARCH_GOOGLE
        domain in BING_HOSTS -> SAFE_SEARCH_BING
        else -> null
    }

    /**
     * Reads the first question from a DNS query (the UDP payload, starting
     * with the 12-byte DNS header). Returns null if it's malformed.
     */
    fun parseQuestion(query: ByteArray): Question? {
        var index = 12
        val parts = mutableListOf<String>()
        while (index < query.size) {
            val len = query[index].toInt() and 0xFF
            if (len == 0) break
            // Labels are at most 63 bytes; anything larger is a compression
            // pointer, which a query's question never uses
            if (len > 63 || index + 1 + len > query.size) return null
            parts.add(String(query, index + 1, len, Charsets.US_ASCII))
            index += len + 1
        }
        // Skip the terminating zero, then QTYPE and QCLASS
        val end = index + 5
        if (parts.isEmpty() || end > query.size) return null
        val type = ((query[index + 1].toInt() and 0xFF) shl 8) or (query[index + 2].toInt() and 0xFF)
        return Question(parts.joinToString(".").lowercase(), type, end)
    }

    /**
     * Builds a DNS response to [query] with the given response code and, if
     * [ipv4] is set, a single A record. Anything after the question, such as
     * an EDNS record, is dropped so the answer is well formed.
     */
    fun buildResponse(query: ByteArray, question: Question, rcode: Int, ipv4: ByteArray?): ByteArray {
        val answerLength = if (ipv4 != null) 16 else 0
        val response = ByteArray(question.end + answerLength)
        System.arraycopy(query, 0, response, 0, question.end)

        // Header: keep the ID, opcode and RD flag; set QR and RA
        response[2] = ((query[2].toInt() and 0x79) or 0x80).toByte()
        response[3] = (0x80 or rcode).toByte()
        response[4] = 0; response[5] = 1 // QDCOUNT
        response[6] = 0; response[7] = if (ipv4 != null) 1 else 0 // ANCOUNT
        response[8] = 0; response[9] = 0 // NSCOUNT
        response[10] = 0; response[11] = 0 // ARCOUNT

        if (ipv4 != null) {
            var offset = question.end
            response[offset++] = 0xC0.toByte() // Name: pointer to the question at offset 12
            response[offset++] = 0x0C
            response[offset++] = 0; response[offset++] = 1 // Type A
            response[offset++] = 0; response[offset++] = 1 // Class IN
            response[offset++] = 0; response[offset++] = 0 // TTL 60 seconds
            response[offset++] = 0; response[offset++] = 60
            response[offset++] = 0; response[offset++] = 4 // RDLENGTH
            System.arraycopy(ipv4, 0, response, offset, 4)
        }
        return response
    }

    /**
     * Wraps [dnsPayload] in an IPv4/UDP packet addressed back to the sender of
     * [request], whose UDP header starts at offset [udp].
     */
    fun buildReplyPacket(request: ByteArray, udp: Int, dnsPayload: ByteArray): ByteArray {
        val totalLength = 20 + 8 + dnsPayload.size
        val packet = ByteArray(totalLength)

        // IPv4 header (20 bytes, no options)
        packet[0] = 0x45
        packet[2] = (totalLength shr 8).toByte()
        packet[3] = (totalLength and 0xFF).toByte()
        packet[6] = 0x40 // Don't fragment
        packet[8] = 64 // TTL
        packet[9] = 17 // UDP
        System.arraycopy(request, 16, packet, 12, 4) // Source = original destination
        System.arraycopy(request, 12, packet, 16, 4) // Destination = original source
        val checksum = checksum(packet, 0, 20)
        packet[10] = (checksum shr 8).toByte()
        packet[11] = (checksum and 0xFF).toByte()

        // UDP header (8 bytes). A zero checksum is allowed over IPv4.
        System.arraycopy(request, udp + 2, packet, 20, 2) // Source port = original destination port
        System.arraycopy(request, udp, packet, 22, 2) // Destination port = original source port
        val udpLength = 8 + dnsPayload.size
        packet[24] = (udpLength shr 8).toByte()
        packet[25] = (udpLength and 0xFF).toByte()

        System.arraycopy(dnsPayload, 0, packet, 28, dnsPayload.size)
        return packet
    }

    /**
     * Internet checksum (RFC 1071).
     */
    fun checksum(buffer: ByteArray, offset: Int, length: Int): Int {
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
}
