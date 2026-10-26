// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

/**
 * The blocking rules shared by the VPN and the accessibility service.
 *
 * A blocked or whitelisted site matches that domain and its subdomains only,
 * so "x.com" covers "www.x.com" but not "box.com" and whitelisting
 * "google.com" does not allow "notgoogle.com". Keywords match anywhere.
 *
 * Site lists are sets of [normalise]d entries, plus the bundled list
 * ([BundledBlocklist]). A lookup checks the host and each of its parent
 * domains, so it stays fast however long the lists are. The whitelist
 * overrides the bundled list too.
 */
internal object DomainRules {
    // Domain names inside on-screen text, such as an address bar
    private val HOST = Regex("[a-z0-9-]+(\\.[a-z0-9-]+)+")

    // Text that is a single web address, such as a browser's address bar
    private val ADDRESS =
        Regex("(?:[a-z][a-z0-9+.-]*://)?([a-z0-9-]+(?:\\.[a-z0-9-]+)+)(?::\\d+)?(?:[/?#]\\S*)?")

    /** The form a site is stored in: trimmed, lower case, no trailing dot. */
    fun normalise(rule: String): String = rule.trim().lowercase().trimEnd('.')

    /** True if [host] is [rule] or one of its subdomains. */
    fun matchesDomain(host: String, rule: String): Boolean {
        val site = normalise(rule)
        if (site.isEmpty()) return false
        val name = host.lowercase().trimEnd('.')
        return name == site || name.endsWith(".$site")
    }

    /**
     * True if [host] or one of its parent domains is in [sites], which must
     * hold [normalise]d entries. "a.b.x.com" checks "a.b.x.com", "b.x.com",
     * "x.com" and "com".
     */
    fun inSites(host: String, sites: Set<String>): Boolean =
        sites.isNotEmpty() && anyParent(host) { it in sites }

    /** As [inSites] for a set, for the bundled list. */
    fun inSites(host: String, sites: SortedDomainList): Boolean =
        sites.size > 0 && anyParent(host) { it in sites }

    private inline fun anyParent(host: String, test: (String) -> Boolean): Boolean {
        var name = host.lowercase().trimEnd('.')
        while (name.isNotEmpty()) {
            if (test(name)) return true
            val dot = name.indexOf('.')
            if (dot < 0) return false
            name = name.substring(dot + 1)
        }
        return false
    }

    /** Whether a DNS lookup for [domain] should be blocked. */
    fun shouldBlockDomain(
        domain: String,
        blockedSites: Set<String>,
        blockedKeywords: Collection<String>,
        whitelistedSites: Set<String>,
        bundledSites: SortedDomainList = SortedDomainList.EMPTY,
    ): Boolean {
        val name = domain.lowercase()
        if (inSites(name, whitelistedSites)) return false
        if (inSites(name, blockedSites) || inSites(name, bundledSites)) return true
        return blockedKeywords.any { it.isNotBlank() && name.contains(it.lowercase()) }
    }

    /**
     * Whether [text] is just a web address on a whitelisted site, as an
     * address bar shows it. The page it belongs to is left alone, since its
     * headlines and paragraphs don't name the site themselves.
     */
    fun isWhitelistedAddress(text: String, whitelistedSites: Set<String>): Boolean {
        if (whitelistedSites.isEmpty()) return false
        val match = ADDRESS.matchEntire(text.trim().lowercase()) ?: return false
        return inSites(match.groupValues[1], whitelistedSites)
    }

    /** Whether text shown in a browser should be blocked. */
    fun shouldBlockText(
        text: String,
        blockedSites: Set<String>,
        blockedKeywords: Collection<String>,
        whitelistedSites: Set<String>,
        bundledSites: SortedDomainList = SortedDomainList.EMPTY,
    ): Boolean {
        val lower = text.lowercase()
        val hosts = HOST.findAll(lower).map { it.value }.toList()
        // Text that mentions a whitelisted site is left alone
        if (hosts.any { inSites(it, whitelistedSites) }) return false
        if (hosts.any { inSites(it, blockedSites) || inSites(it, bundledSites) }) return true
        return blockedKeywords.any { it.isNotBlank() && lower.contains(it.lowercase()) }
    }
}
