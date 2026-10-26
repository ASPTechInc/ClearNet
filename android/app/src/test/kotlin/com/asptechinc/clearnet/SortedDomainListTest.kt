// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class SortedDomainListTest {

    private fun listOf(text: String) = SortedDomainList.parse(text.toByteArray())!!

    private val list = listOf("# header\n#\na.com\nb.co.uk\nb.com\nx.com\n")

    @Test
    fun contains_findsExactEntriesOnly() {
        assertTrue("a.com" in list)
        assertTrue("b.co.uk" in list)
        assertTrue("x.com" in list)
        assertFalse("www.x.com" in list)
        assertFalse("x.co" in list)
        assertFalse("x.com.au" in list)
        assertFalse("0.com" in list)
        assertFalse("z.com" in list)
        assertFalse("" in list)
    }

    @Test
    fun parse_skipsCommentsAndBlankLines() {
        assertTrue(list.size == 4)
        assertTrue(listOf("\n\na.com\n\n").size == 1)
        assertTrue(listOf("a.com").size == 1)
        assertTrue(listOf("").size == 0)
    }

    @Test
    fun parse_rejectsUnsortedLists() {
        assertNull(SortedDomainList.parse("b.com\na.com\n".toByteArray()))
        assertNull(SortedDomainList.parse("a.com.au\na.com\n".toByteArray()))
    }

    @Test
    fun domainRules_blockSubdomainsOfBundledSites() {
        assertTrue(DomainRules.shouldBlockDomain("cdn.www.x.com", emptySet(), emptySet(), emptySet(), list))
        assertFalse(DomainRules.shouldBlockDomain("box.com", emptySet(), emptySet(), emptySet(), list))
        assertTrue(DomainRules.shouldBlockText("visit x.com now", emptySet(), emptySet(), emptySet(), list))
    }

    @Test
    fun domainRules_whitelistOverridesBundledSites() {
        assertFalse(DomainRules.shouldBlockDomain("www.x.com", emptySet(), emptySet(), setOf("x.com"), list))
        assertFalse(DomainRules.shouldBlockText("x.com", emptySet(), emptySet(), setOf("x.com"), list))
    }

    @Test
    fun bundledAsset_isSortedAndLoads() {
        val asset = File("src/main/assets/blocklists/adult.txt")
        val bundled = SortedDomainList.parse(asset.readBytes())
        assertNotNull("adult.txt is not sorted; run scripts/update_adult_blocklist.sh", bundled)
        assertTrue(bundled!!.size > 100_000)
        assertTrue("pornhub.com" in bundled)
        assertTrue(DomainRules.inSites("www.pornhub.com", bundled))
        assertFalse(DomainRules.inSites("bbc.co.uk", bundled))
    }
}
