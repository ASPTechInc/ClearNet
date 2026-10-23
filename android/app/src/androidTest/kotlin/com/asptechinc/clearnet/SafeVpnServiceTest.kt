// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SafeVpnServiceTest {

    private lateinit var service: SafeVpnService

    @Before
    fun setUp() {
        service = SafeVpnService()
    }

    @Test
    fun serviceInstantiation_initializesStatsToZero() {
        assertNotNull(service)
        assertEquals(0L, service.getUptimeMinutes())
        assertEquals(0L, service.getPacketsProcessed())
        assertEquals(0L, service.getPacketsBlocked())
    }

    @Test
    fun dynamicFilterManagement_addsAndRemovesEntriesWithoutErrors() {
        service.addBlockedSite("gambling.com")
        service.removeBlockedSite("gambling.com")

        service.addBlockedKeyword("casino")
        service.removeBlockedKeyword("casino")

        service.addWhitelistedSite("safe-gambling.com")
        service.removeWhitelistedSite("safe-gambling.com")
    }

    @Test
    fun shouldBlockDomain_blocksListedSitesAndKeywords() {
        service.addBlockedSite("blocked.com")
        service.addBlockedKeyword("casino")

        assertTrue(service.shouldBlockDomain("blocked.com"))
        assertTrue("subdomains", service.shouldBlockDomain("www.blocked.com"))
        assertTrue("any case", service.shouldBlockDomain("WWW.Blocked.COM"))
        assertTrue("keyword in the name", service.shouldBlockDomain("bestcasino.net"))
        assertFalse(service.shouldBlockDomain("example.com"))
    }

    @Test
    fun shouldBlockDomain_whitelistWins() {
        service.addBlockedKeyword("casino")
        service.addWhitelistedSite("safe-casino.com")

        assertFalse(service.shouldBlockDomain("safe-casino.com"))
        assertTrue(service.shouldBlockDomain("casino.com"))
    }

    @Test
    fun shouldBlockDomain_removedEntriesStopBlocking() {
        service.addBlockedSite("blocked.com")
        service.removeBlockedSite("blocked.com")
        assertFalse(service.shouldBlockDomain("blocked.com"))
    }
}
