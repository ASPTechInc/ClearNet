// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart' show rootBundle;

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class BlocklistManager {
  // Internal keys for user-added items to keep them separate from assets
  static const _userDomainsKey = 'user_blocked_domains';
  static const _userKeywordsKey = 'user_blocked_keywords';

  // Final keys synced for native services (SafeVpnService, AppBlockService)
  static const _finalDomainsKey = Constants.blocklistKey;
  static const _finalKeywordsKey = Constants.keywordsKey;

  /// Load baseline data from bundled JSON asset
  static Future<Map<String, List<String>>> _loadAssetData() async {
    try {
      final jsonString = await rootBundle.loadString(Constants.blocklistAsset);
      final dynamic data = json.decode(jsonString);
      return {
        'domains': List<String>.from(data['domains'] ?? []),
        'keywords': List<String>.from(data['keywords'] ?? []),
      };
    } catch (e) {
      return {'domains': [], 'keywords': []};
    }
  }

  /// Load user-added domains
  static Future<List<String>> loadUserDomains() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_userDomainsKey) ?? [])
        .map((s) => s.toLowerCase())
        .toList();
  }

  /// Load user-added keywords
  static Future<List<String>> loadUserKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_userKeywordsKey) ?? [])
        .map((s) => s.toLowerCase())
        .toList();
  }

  /// Add a new user domain
  static Future<void> addUserDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userDomainsKey) ?? [];
    final cleaned = domain.trim().toLowerCase();
    if (cleaned.isNotEmpty && !current.contains(cleaned)) {
      current.add(cleaned);
      await prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist(); // Sync to native
    }
  }

  /// Add a new user keyword
  static Future<void> addUserKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userKeywordsKey) ?? [];
    final cleaned = keyword.trim().toLowerCase();
    if (cleaned.isNotEmpty && !current.contains(cleaned)) {
      current.add(cleaned);
      await prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist(); // Sync to native
    }
  }

  /// Remove a user domain
  static Future<void> removeUserDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userDomainsKey) ?? [];
    if (current.remove(domain.toLowerCase())) {
      await prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist();
    }
  }

  /// Remove a user keyword
  static Future<void> removeUserKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userKeywordsKey) ?? [];
    if (current.remove(keyword.toLowerCase())) {
      await prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist();
    }
  }

  /// Merge all sources and sync to SharedPreferences for Android access
  static Future<void> buildFinalBlocklist() async {
    final assetData = await _loadAssetData();
    final userDomains = await loadUserDomains();
    final userKeywords = await loadUserKeywords();

    final allDomains = <String>{...assetData['domains']!, ...userDomains};
    final allKeywords = <String>{...assetData['keywords']!, ...userKeywords};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_finalDomainsKey, allDomains.toList());
    await prefs.setStringList(_finalKeywordsKey, allKeywords.toList());
  }

  /// Check domain against merged blocklist + keywords
  static Future<bool> shouldBlock(String domain) async {
    final lowerDomain = domain.toLowerCase();

    final prefs = await SharedPreferences.getInstance();
    final domains = prefs.getStringList(_finalDomainsKey) ?? [];
    final keywords = prefs.getStringList(_finalKeywordsKey) ?? [];

    if (domains.any((s) => lowerDomain.contains(s))) return true;
    if (keywords.any((k) => lowerDomain.contains(k))) return true;

    return false;
  }

  /// Export user settings to JSON string
  static Future<String> exportToJson() async {
    final userDomains = await loadUserDomains();
    final userKeywords = await loadUserKeywords();
    return json.encode({
      'domains': userDomains,
      'keywords': userKeywords,
    });
  }

  /// Import user settings from JSON string
  static Future<void> importFromJson(String jsonString) async {
    try {
      final dynamic data = json.decode(jsonString);
      final List<String> domains = List<String>.from(data['domains'] ?? []);
      final List<String> keywords = List<String>.from(data['keywords'] ?? []);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_userDomainsKey, domains.map((s) => s.toLowerCase()).toList());
      await prefs.setStringList(_userKeywordsKey, keywords.map((s) => s.toLowerCase()).toList());
      
      await buildFinalBlocklist();
    } catch (e) {
      throw Exception('Invalid JSON format for blocklist import');
    }
  }
}
