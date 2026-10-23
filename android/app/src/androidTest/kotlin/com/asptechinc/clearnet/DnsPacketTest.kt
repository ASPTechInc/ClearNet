// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream

@RunWith(AndroidJUnit4::class)
class DnsPacketTest {

    /** Builds a DNS query for [name], optionally with an EDNS record after it. */
    private fun query(name: String, type: Int, withEdns: Boolean = false): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(byteArrayOf(0x12, 0x34)) // ID
        out.write(byteArrayOf(0x01, 0x00)) // Flags: recursion desired
        out.write(byteArrayOf(0, 1, 0, 0, 0, 0, 0, if (withEdns) 1 else 0))
        for (label in name.split(".")) {
            out.write(label.length)
            out.write(label.toByteArray(Charsets.US_ASCII))
        }
        out.write(0)
        out.write(byteArrayOf((type shr 8).toByte(), type.toByte(), 0, 1))
        if (withEdns) {
            // OPT record: root name, type 41, UDP size 4096, no options
            out.write(byteArrayOf(0, 0, 41, 0x10, 0, 0, 0, 0, 0, 0, 0))
        }
        return out.toByteArray()
    }

    /** Wraps [dns] in an IPv4/UDP packet from 10.111.222.1:40000 to 10.111.222.2:53. */
    private fun ipPacket(dns: ByteArray): ByteArray {
        val packet = ByteArray(28 + dns.size)
        packet[0] = 0x45
        packet[9] = 17
        byteArrayOf(10, 111, 222.toByte(), 1).copyInto(packet, 12)
        byteArrayOf(10, 111, 222.toByte(), 2).copyInto(packet, 16)
        byteArrayOf(0x9C.toByte(), 0x40, 0, 53).copyInto(packet, 20) // Ports 40000 -> 53
        dns.copyInto(packet, 28)
        return packet
    }

    private fun u16(bytes: ByteArray, offset: Int) =
        ((bytes[offset].toInt() and 0xFF) shl 8) or (bytes[offset + 1].toInt() and 0xFF)

    @Test
    fun parseQuestion_readsNameAndType() {
        val question = DnsPacket.parseQuestion(query("WWW.Example.com", DnsPacket.TYPE_A))

        assertNotNull(question)
        assertEquals("www.example.com", question!!.name)
        assertEquals(DnsPacket.TYPE_A, question.type)
    }

    @Test
    fun parseQuestion_readsAaaaQueries() {
        val question = DnsPacket.parseQuestion(query("example.com", DnsPacket.TYPE_AAAA))
        assertEquals(DnsPacket.TYPE_AAAA, question!!.type)
    }

    @Test
    fun parseQuestion_rejectsMalformedQueries() {
        val full = query("example.com", DnsPacket.TYPE_A)
        assertNull("truncated", DnsPacket.parseQuestion(full.copyOf(full.size - 3)))
        assertNull("header only", DnsPacket.parseQuestion(full.copyOf(12)))

        val badLabel = full.copyOf()
        badLabel[12] = 0xC0.toByte() // A compression pointer, not a label length
        assertNull("bad label", DnsPacket.parseQuestion(badLabel))
    }

    @Test
    fun buildResponse_blockedDomainGetsNxdomain() {
        val request = query("blocked.com", DnsPacket.TYPE_A, withEdns = true)
        val question = DnsPacket.parseQuestion(request)!!

        val response = DnsPacket.buildResponse(request, question, DnsPacket.RCODE_NXDOMAIN, null)

        assertEquals("keeps the ID", 0x1234, u16(response, 0))
        assertEquals("is a response", 0x80, response[2].toInt() and 0x80)
        assertEquals("keeps recursion desired", 0x01, response[2].toInt() and 0x01)
        assertEquals("NXDOMAIN", DnsPacket.RCODE_NXDOMAIN, response[3].toInt() and 0x0F)
        assertEquals("one question", 1, u16(response, 4))
        assertEquals("no answers", 0, u16(response, 6))
        assertEquals("EDNS record dropped", 0, u16(response, 10))
        assertEquals(question.end, response.size)
    }

    @Test
    fun buildResponse_withAddressAddsOneARecord() {
        val request = query("www.google.com", DnsPacket.TYPE_A)
        val question = DnsPacket.parseQuestion(request)!!
        val ip = DnsPacket.SAFE_SEARCH_GOOGLE

        val response = DnsPacket.buildResponse(request, question, DnsPacket.RCODE_NOERROR, ip)

        assertEquals(DnsPacket.RCODE_NOERROR, response[3].toInt() and 0x0F)
        assertEquals("one answer", 1, u16(response, 6))
        val answer = question.end
        assertEquals("points to the question", 0xC00C, u16(response, answer))
        assertEquals("type A", DnsPacket.TYPE_A, u16(response, answer + 2))
        assertEquals("TTL 60", 60, u16(response, answer + 8))
        assertEquals("4-byte address", 4, u16(response, answer + 10))
        assertArrayEquals(ip, response.copyOfRange(response.size - 4, response.size))
    }

    @Test
    fun safeSearchIp_coversSearchSitesOnly() {
        for (host in listOf("google.com", "www.google.com", "www.google.co.uk", "google.com.au",
                "www.youtube.com", "m.youtube.com", "youtubei.googleapis.com")) {
            assertArrayEquals(host, DnsPacket.SAFE_SEARCH_GOOGLE, DnsPacket.safeSearchIp(host))
        }
        for (host in listOf("bing.com", "www.bing.com")) {
            assertArrayEquals(host, DnsPacket.SAFE_SEARCH_BING, DnsPacket.safeSearchIp(host))
        }
        // Other Google services must keep their real addresses
        for (host in listOf("play.google.com", "mail.google.com", "mtalk.google.com",
                "android.googleapis.com", "example.com", "notgoogle.com")) {
            assertNull(host, DnsPacket.safeSearchIp(host))
        }
    }

    @Test
    fun buildReplyPacket_swapsAddressesAndPortsWithAValidChecksum() {
        val dns = query("example.com", DnsPacket.TYPE_A)
        val request = ipPacket(dns)
        val payload = byteArrayOf(1, 2, 3, 4, 5)

        val reply = DnsPacket.buildReplyPacket(request, 20, payload)

        assertEquals("IPv4 with a 20-byte header", 0x45, reply[0].toInt())
        assertEquals("UDP", 17, reply[9].toInt())
        assertEquals("total length", 28 + payload.size, u16(reply, 2))
        assertArrayEquals("from the DNS address", request.copyOfRange(16, 20), reply.copyOfRange(12, 16))
        assertArrayEquals("to the sender", request.copyOfRange(12, 16), reply.copyOfRange(16, 20))
        assertEquals("from port 53", 53, u16(reply, 20))
        assertEquals("to the sender's port", 40000, u16(reply, 22))
        assertEquals("UDP length", 8 + payload.size, u16(reply, 24))
        assertArrayEquals(payload, reply.copyOfRange(28, reply.size))
        // A valid header checksums to zero
        assertEquals(0, DnsPacket.checksum(reply, 0, 20))
    }

    @Test
    fun checksum_matchesAKnownIpv4Header() {
        // Well-known example header (192.168.0.1 -> 192.168.0.199) with checksum 0xB861
        val header = byteArrayOf(
            0x45, 0x00, 0x00, 0x73, 0x00, 0x00, 0x40, 0x00, 0x40, 0x11, 0x00, 0x00,
            0xC0.toByte(), 0xA8.toByte(), 0x00, 0x01, 0xC0.toByte(), 0xA8.toByte(), 0x00, 0xC7.toByte()
        )
        assertEquals(0xB861, DnsPacket.checksum(header, 0, 20))
    }

    @Test
    fun dohHosts_includeTheFirefoxCanary() {
        // Answering this with NXDOMAIN turns Firefox's own DNS-over-HTTPS off
        assertTrue("use-application-dns.net" in DnsPacket.DOH_HOSTS)
    }
}
