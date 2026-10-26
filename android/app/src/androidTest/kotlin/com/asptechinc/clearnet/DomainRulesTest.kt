// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DomainRulesTest {
    private val sites = setOf("x.com", "pornhub.com", "notgoogle.com")
    private val keywords = setOf("casino")
    private val whitelist = setOf("google.com", "safe-casino.com")

    private fun blocksDomain(domain: String) =
        DomainRules.shouldBlockDomain(domain, sites, keywords, whitelist)

    private fun blocksText(text: String) =
        DomainRules.shouldBlockText(text, sites, keywords, whitelist)

    @Test
    fun matchesDomain_coversTheDomainAndSubdomainsOnly() {
        assertTrue(DomainRules.matchesDomain("x.com", "x.com"))
        assertTrue(DomainRules.matchesDomain("www.x.com", "x.com"))
        assertTrue(DomainRules.matchesDomain("WWW.X.COM.", "x.com"))
        assertFalse(DomainRules.matchesDomain("box.com", "x.com"))
        assertFalse(DomainRules.matchesDomain("x.com.au", "x.com"))
        assertFalse(DomainRules.matchesDomain("x.com", " "))
    }

    @Test
    fun blockedSites_doNotCatchLookalikes() {
        assertTrue(blocksDomain("x.com"))
        assertTrue(blocksDomain("www.pornhub.com"))
        assertFalse(blocksDomain("box.com"))
        assertFalse(blocksDomain("example.com"))
    }

    @Test
    fun whitelist_doesNotAllowLookalikes() {
        assertFalse(blocksDomain("www.google.com"))
        assertTrue("blocked site that only contains a whitelisted name", blocksDomain("notgoogle.com"))
    }

    @Test
    fun keywords_matchAnywhereUnlessWhitelisted() {
        assertTrue(blocksDomain("bestcasino.net"))
        assertFalse(blocksDomain("safe-casino.com"))
    }

    @Test
    fun text_findsBlockedDomainsInAddressBars() {
        assertTrue(blocksText("https://www.pornhub.com/video"))
        assertTrue(blocksText("pornhub.com"))
        assertFalse(blocksText("Read more on box.com"))
    }

    @Test
    fun text_matchesKeywordsAnywhere() {
        assertTrue(blocksText("Play at the CASINO tonight"))
        assertFalse(blocksText("Weather forecast"))
    }

    @Test
    fun text_mentioningAWhitelistedSiteIsLeftAlone() {
        assertFalse(blocksText("safe-casino.com - responsible gambling help"))
        assertFalse(blocksText("google.com search results"))
    }

    @Test
    fun inSites_checksTheHostAndItsParentDomains() {
        assertTrue(DomainRules.inSites("x.com", sites))
        assertTrue(DomainRules.inSites("a.b.WWW.X.COM.", sites))
        assertFalse(DomainRules.inSites("box.com", sites))
        assertFalse(DomainRules.inSites("x.com.au", sites))
        assertFalse(DomainRules.inSites("com", sites))
        assertFalse(DomainRules.inSites("", sites))
        assertFalse(DomainRules.inSites("x.com", emptySet()))
    }

    @Test
    fun normalise_matchesHowSitesAreLookedUp() {
        assertTrue(DomainRules.inSites("www.x.com", setOf(DomainRules.normalise(" X.com. "))))
    }

    @Test
    fun address_onAWhitelistedSiteIsRecognised() {
        assertTrue(DomainRules.isWhitelistedAddress("google.com", whitelist))
        assertTrue(DomainRules.isWhitelistedAddress("https://www.google.com/search?q=casino", whitelist))
        assertTrue(DomainRules.isWhitelistedAddress(" safe-casino.com/help ", whitelist))
    }

    @Test
    fun address_onlyCountsWhenTheTextIsJustAnAddress() {
        assertFalse(DomainRules.isWhitelistedAddress("notgoogle.com", whitelist))
        assertFalse(DomainRules.isWhitelistedAddress("google.com.evil.net/page", whitelist))
        assertFalse(DomainRules.isWhitelistedAddress("as seen on google.com", whitelist))
        assertFalse(DomainRules.isWhitelistedAddress("", whitelist))
    }
}
