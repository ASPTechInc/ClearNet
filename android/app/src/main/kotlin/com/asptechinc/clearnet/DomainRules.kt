// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

/**
 * The blocking rules shared by the VPN and the accessibility service.
 *
 * A blocked or whitelisted site matches that domain and its subdomains only,
 * so "x.com" covers "www.x.com" but not "box.com" and whitelisting
 * "google.com" does not allow "notgoogle.com". Keywords match anywhere.
 */
internal object DomainRules {
    // Domain names inside on-screen text, such as an address bar
    private val HOST = Regex("[a-z0-9-]+(\\.[a-z0-9-]+)+")

    /** True if [host] is [rule] or one of its subdomains. */
    fun matchesDomain(host: String, rule: String): Boolean {
        val site = rule.trim().lowercase().trimEnd('.')
        if (site.isEmpty()) return false
        val name = host.lowercase().trimEnd('.')
        return name == site || name.endsWith(".$site")
    }

    /** Whether a DNS lookup for [domain] should be blocked. */
    fun shouldBlockDomain(
        domain: String,
        blockedSites: Collection<String>,
        blockedKeywords: Collection<String>,
        whitelistedSites: Collection<String>,
    ): Boolean {
        val name = domain.lowercase()
        if (whitelistedSites.any { matchesDomain(name, it) }) return false
        if (blockedSites.any { matchesDomain(name, it) }) return true
        return blockedKeywords.any { it.isNotBlank() && name.contains(it.lowercase()) }
    }

    /** Whether text shown in a browser should be blocked. */
    fun shouldBlockText(
        text: String,
        blockedSites: Collection<String>,
        blockedKeywords: Collection<String>,
        whitelistedSites: Collection<String>,
    ): Boolean {
        val lower = text.lowercase()
        val hosts = HOST.findAll(lower).map { it.value }.toList()
        // Text that mentions a whitelisted site is left alone
        if (hosts.any { host -> whitelistedSites.any { matchesDomain(host, it) } }) return false
        if (hosts.any { host -> blockedSites.any { matchesDomain(host, it) } }) return true
        return blockedKeywords.any { it.isNotBlank() && lower.contains(it.lowercase()) }
    }
}
