// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart' show rootBundle;

// Package imports:
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

/// Keeps the blocked domains, keywords and whitelist.
///
/// What the user adds is kept under the `user_*` keys. buildFinalBlocklist()
/// merges those with the built-in blocklist asset into the final keys, which
/// the VPN and accessibility service read. A copy is also written to
/// blocklist.json in the app's documents folder.
class BlocklistManager {
  // Internal keys for user-added items to keep them separate from assets
  static const _userDomainsKey = 'user_blocked_domains';
  static const _userKeywordsKey = 'user_blocked_keywords';
  static const _userWhitelistKey = 'user_whitelisted_sites';

  // Final keys synced for native services (SafeVpnService, AppBlockService)
  static const _finalDomainsKey = Constants.blocklistKey;
  static const _finalKeywordsKey = Constants.keywordsKey;
  static const _finalWhitelistKey = Constants.whitelistKey;

  static final _prefs = SharedPreferencesAsync();

  static Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${Constants.blocklistFileName}');
  }

  /// Ensures SharedPreferences is in sync with blocklist.json if it exists
  static Future<void> init() async {
    final file = await _getLocalFile();

    final savedDomains = await _prefs.getStringList(_userDomainsKey);
    final savedKeywords = await _prefs.getStringList(_userKeywordsKey);
    final savedWhitelist = await _prefs.getStringList(_userWhitelistKey);

    final hasUserData =
        (savedDomains ?? []).isNotEmpty ||
        (savedKeywords ?? []).isNotEmpty ||
        (savedWhitelist ?? []).isNotEmpty;

    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        await importFromJson(jsonString, syncToFile: false);
      } catch (e) {
        // Handle error or ignore
      }
    } else if (!hasUserData) {
      // First run or no data: load from assets into user list by default
      final assetData = await _loadAssetData();
      final domains = assetData['domains'] ?? [];
      final keywords = assetData['keywords'] ?? [];
      final whitelist = assetData['whitelist'] ?? [];

      if (domains.isNotEmpty || keywords.isNotEmpty || whitelist.isNotEmpty) {
        await _prefs.setStringList(_userDomainsKey, domains);
        await _prefs.setStringList(_userKeywordsKey, keywords);
        await _prefs.setStringList(_userWhitelistKey, whitelist);
      }
    }

    await buildFinalBlocklist();
    unawaited(_saveToFile());
  }

  /// Load baseline data from bundled JSON asset
  static Future<Map<String, List<String>>> _loadAssetData() async {
    try {
      final jsonString = await rootBundle.loadString(Constants.blocklistAsset);

      // Cast the decoded JSON to Map<String, dynamic>
      final data = json.decode(jsonString) as Map<String, dynamic>;

      return {
        'domains': List<String>.from(data['domains'] ?? []),
        'keywords': List<String>.from(data['keywords'] ?? []),
        'whitelist': List<String>.from(data['whitelist'] ?? []),
      };
    } catch (e) {
      return {'domains': [], 'keywords': [], 'whitelist': []};
    }
  }

  /// Load user-added domains
  static Future<List<String>> loadUserDomains() async {
    return (await _prefs.getStringList(_userDomainsKey) ?? [])
        .map((s) => s.toLowerCase())
        .toList();
  }

  /// Load user-added keywords
  static Future<List<String>> loadUserKeywords() async {
    return (await _prefs.getStringList(_userKeywordsKey) ?? [])
        .map((s) => s.toLowerCase())
        .toList();
  }

  /// Load user-added whitelist
  static Future<List<String>> loadUserWhitelist() async {
    return (await _prefs.getStringList(_userWhitelistKey) ?? [])
        .map((s) => s.toLowerCase())
        .toList();
  }

  /// Check if item is in user blocked domains
  static Future<bool> isItemInDomains(String item) async {
    final domains = await loadUserDomains();
    return domains.contains(item.trim().toLowerCase());
  }

  /// Check if item is in user blocked keywords
  static Future<bool> isItemInKeywords(String item) async {
    final keywords = await loadUserKeywords();
    return keywords.contains(item.trim().toLowerCase());
  }

  /// Check if item is in user whitelist
  static Future<bool> isItemInWhitelist(String item) async {
    final whitelist = await loadUserWhitelist();
    return whitelist.contains(item.trim().toLowerCase());
  }

  /// Add a new user domain
  static Future<void> addUserDomain(String domain) async {
    final current = await _prefs.getStringList(_userDomainsKey) ?? [];
    final cleaned = domain.trim().toLowerCase();
    if (cleaned.isNotEmpty && !current.contains(cleaned)) {
      current.add(cleaned);
      await _prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist(); // Sync to native
      unawaited(_saveToFile());
    }
  }

  /// Add a new user keyword
  static Future<void> addUserKeyword(String keyword) async {
    final current = await _prefs.getStringList(_userKeywordsKey) ?? [];
    final cleaned = keyword.trim().toLowerCase();
    if (cleaned.isNotEmpty && !current.contains(cleaned)) {
      current.add(cleaned);
      await _prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist(); // Sync to native
      unawaited(_saveToFile());
    }
  }

  /// Add a new user whitelisted site
  static Future<void> addUserWhitelist(String whitelist) async {
    final current = await _prefs.getStringList(_userWhitelistKey) ?? [];
    final cleaned = whitelist.trim().toLowerCase();
    if (cleaned.isNotEmpty && !current.contains(cleaned)) {
      current.add(cleaned);
      await _prefs.setStringList(_userWhitelistKey, current);
      await buildFinalBlocklist(); // Sync to native
      unawaited(_saveToFile());
    }
  }

  /// Remove a user domain
  static Future<void> removeUserDomain(String domain) async {
    final current = await _prefs.getStringList(_userDomainsKey) ?? [];
    if (current.remove(domain.toLowerCase())) {
      await _prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist();
      unawaited(_saveToFile());
    }
  }

  /// Remove a user keyword
  static Future<void> removeUserKeyword(String keyword) async {
    final current = await _prefs.getStringList(_userKeywordsKey) ?? [];
    if (current.remove(keyword.toLowerCase())) {
      await _prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist();
      unawaited(_saveToFile());
    }
  }

  /// Remove a user whitelisted site
  static Future<void> removeUserWhitelist(String whitelist) async {
    final current = await _prefs.getStringList(_userWhitelistKey) ?? [];
    if (current.remove(whitelist.toLowerCase())) {
      await _prefs.setStringList(_userWhitelistKey, current);
      await buildFinalBlocklist();
      unawaited(_saveToFile());
    }
  }

  static Future<void> updateUserDomain(
    String oldDomain,
    String newDomain,
  ) async {
    final current = await _prefs.getStringList(_userDomainsKey) ?? [];
    final oldCleaned = oldDomain.toLowerCase();
    final newCleaned = newDomain.trim().toLowerCase();

    if (newCleaned.isEmpty) return;

    final index = current.indexOf(oldCleaned);
    if (index != -1) {
      current[index] = newCleaned;
      await _prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist();
      unawaited(_saveToFile());
    }
  }

  /// Update an existing user keyword
  static Future<void> updateUserKeyword(
    String oldKeyword,
    String newKeyword,
  ) async {
    final current = await _prefs.getStringList(_userKeywordsKey) ?? [];
    final oldCleaned = oldKeyword.toLowerCase();
    final newCleaned = newKeyword.trim().toLowerCase();

    if (newCleaned.isEmpty) return;

    final index = current.indexOf(oldCleaned);
    if (index != -1) {
      current[index] = newCleaned;
      await _prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist();
      unawaited(_saveToFile());
    }
  }

  /// Update an existing user whitelisted site
  static Future<void> updateUserWhitelist(
    String oldWhitelist,
    String newWhitelist,
  ) async {
    final current = await _prefs.getStringList(_userWhitelistKey) ?? [];
    final oldCleaned = oldWhitelist.toLowerCase();
    final newCleaned = newWhitelist.trim().toLowerCase();

    if (newCleaned.isEmpty) return;

    final index = current.indexOf(oldCleaned);
    if (index != -1) {
      current[index] = newCleaned;
      await _prefs.setStringList(_userWhitelistKey, current);
      await buildFinalBlocklist();
      unawaited(_saveToFile());
    }
  }

  static Future<void> _saveToFile() async {
    try {
      final domains = await loadUserDomains();
      final keywords = await loadUserKeywords();
      final whitelisted = await loadUserWhitelist();
      final file = await _getLocalFile();
      final jsonString = json.encode({
        'domains': domains,
        'keywords': keywords,
        'whitelist': whitelisted,
      });
      await file.writeAsString(jsonString);
    } catch (_) {
      // File I/O is a non-critical cache; errors are silently ignored.
    }
  }

  /// Merge all sources and sync to SharedPreferences for Android access
  static Future<void> buildFinalBlocklist() async {
    final userDomains = await loadUserDomains();
    final userKeywords = await loadUserKeywords();
    final userWhitelist = await loadUserWhitelist();

    final savedFinal = await _prefs.getStringList(_finalDomainsKey);
    // After "Clear content" all lists are empty. Keep them empty here,
    // otherwise the built-in blocklist would be merged back in
    if (userDomains.isEmpty &&
        userKeywords.isEmpty &&
        userWhitelist.isEmpty &&
        savedFinal != null &&
        savedFinal.isEmpty) {
      await _prefs.setStringList(_finalDomainsKey, []);
      await _prefs.setStringList(_finalKeywordsKey, []);
      await _prefs.setStringList(_finalWhitelistKey, []);
      return;
    }

    final assetData = await _loadAssetData();
    final allDomains = <String>{...assetData['domains']!, ...userDomains};
    final allKeywords = <String>{...assetData['keywords']!, ...userKeywords};
    final allWhitelist = <String>{...assetData['whitelist']!, ...userWhitelist};

    await _prefs.setStringList(_finalDomainsKey, allDomains.toList());
    await _prefs.setStringList(_finalKeywordsKey, allKeywords.toList());
    await _prefs.setStringList(_finalWhitelistKey, allWhitelist.toList());
  }

  /// Reset user domains, keywords and whitelist to default data from asset
  /// blocklist
  static Future<void> resetToDefault() async {
    final assetData = await _loadAssetData();
    final domains = assetData['domains'] ?? [];
    final keywords = assetData['keywords'] ?? [];
    final whitelist = assetData['whitelist'] ?? [];

    await _prefs.setStringList(
      _userDomainsKey,
      domains.map((s) => s.toLowerCase()).toList(),
    );
    await _prefs.setStringList(
      _userKeywordsKey,
      keywords.map((s) => s.toLowerCase()).toList(),
    );
    await _prefs.setStringList(
      _userWhitelistKey,
      whitelist.map((s) => s.toLowerCase()).toList(),
    );

    await buildFinalBlocklist();
    unawaited(_saveToFile());
  }

  /// Clear all user domains, keywords, whitelist and final blocklists
  static Future<void> clearAll() async {
    await _prefs.setStringList(_userDomainsKey, []);
    await _prefs.setStringList(_userKeywordsKey, []);
    await _prefs.setStringList(_userWhitelistKey, []);

    await _prefs.setStringList(_finalDomainsKey, []);
    await _prefs.setStringList(_finalKeywordsKey, []);
    await _prefs.setStringList(_finalWhitelistKey, []);

    unawaited(_saveToFile());
  }

  /// Whether [domain] should be blocked. Uses the same rules as the Android
  /// side (DomainRules.kt): a blocked or whitelisted site matches that domain
  /// and its subdomains only, while keywords match anywhere.
  static Future<bool> shouldBlock(String domain) async {
    final name = domain.toLowerCase();

    final domains = await _prefs.getStringList(_finalDomainsKey) ?? [];
    final keywords = await _prefs.getStringList(_finalKeywordsKey) ?? [];
    final whitelist = await _prefs.getStringList(_finalWhitelistKey) ?? [];

    if (whitelist.any((w) => matchesDomain(name, w))) return false;
    if (domains.any((s) => matchesDomain(name, s))) return true;
    return keywords.any((k) => k.isNotEmpty && name.contains(k.toLowerCase()));
  }

  /// True if [host] is [rule] or one of its subdomains, so "x.com" covers
  /// "www.x.com" but not "box.com".
  static bool matchesDomain(String host, String rule) {
    final site = rule.trim().toLowerCase();
    if (site.isEmpty) return false;
    final name = host.toLowerCase();
    return name == site || name.endsWith('.$site');
  }

  /// Export user settings to JSON string
  static Future<String> exportToJson() async {
    final userDomains = await loadUserDomains();
    final userKeywords = await loadUserKeywords();
    final userWhitelist = await loadUserWhitelist();

    return json.encode({
      'domains': userDomains,
      'keywords': userKeywords,
      'whitelist': userWhitelist,
    });
  }

  /// Name for an exported backup, e.g. clearnet-backup-20261024-143205.backup.
  /// The file holds the same JSON as exportToJson().
  static String backupFileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${t.year}${two(t.month)}${two(t.day)}';
    final time = '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '${Constants.appName.toLowerCase()}-backup-$date-$time'
        '.${Constants.backupFileExtension}';
  }

  /// Import user settings from JSON string
  static Future<void> importFromJson(
    String jsonString, {
    bool syncToFile = true,
  }) async {
    try {
      // Cast the decoded JSON to Map<String, dynamic>
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final List<String> domains = List<String>.from(data['domains'] ?? []);
      final List<String> keywords = List<String>.from(data['keywords'] ?? []);
      final List<String> whitelist = List<String>.from(data['whitelist'] ?? []);

      await _prefs.setStringList(
        _userDomainsKey,
        domains.map((s) => s.toLowerCase()).toList(),
      );
      await _prefs.setStringList(
        _userKeywordsKey,
        keywords.map((s) => s.toLowerCase()).toList(),
      );
      await _prefs.setStringList(
        _userWhitelistKey,
        whitelist.map((s) => s.toLowerCase()).toList(),
      );
      await buildFinalBlocklist();

      if (syncToFile) {
        unawaited(_saveToFile());
      }
    } catch (e) {
      throw Exception('Invalid JSON format for blocklist import');
    }
  }
}
