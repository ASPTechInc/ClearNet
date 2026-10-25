// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BrowserPackagesSanityTest {

    private val packageNameRegex = Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")

    @Test
    fun browserPackages_hasNoDuplicateEntries() {
        val packages = AppBlockService.BROWSER_PACKAGE_LIST
        assertEquals(
            "BROWSER_PACKAGE_LIST contains duplicate package IDs.",
            packages.size,
            packages.toSet().size
        )
    }

    @Test
    fun browserPackages_allEntriesAreWellFormedPackageNames() {
        val malformed = AppBlockService.BROWSER_PACKAGE_LIST.filterNot {
            packageNameRegex.matches(it)
        }
        assertTrue(
            "Malformed package IDs in BROWSER_PACKAGE_LIST: ${malformed.joinToString()}",
            malformed.isEmpty()
        )
    }
}
