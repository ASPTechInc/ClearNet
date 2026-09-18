// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart' show rootBundle;

// Package imports:
import 'package:path_provider/path_provider.dart';
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

  static Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/blocklist.json');
  }

  /// Ensures SharedPreferences is in sync with blocklist.json if it exists
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final file = await _getLocalFile();
    
    // Check if we have any user data in SharedPreferences
    final hasUserData = (prefs.getStringList(_userDomainsKey) ?? []).isNotEmpty ||
                        (prefs.getStringList(_userKeywordsKey) ?? []).isNotEmpty;

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
      
      if (domains.isNotEmpty || keywords.isNotEmpty) {
        await prefs.setStringList(_userDomainsKey, domains);
        await prefs.setStringList(_userKeywordsKey, keywords);
        await buildFinalBlocklist();
        await _saveToFile();
      }
    }
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
      await _saveToFile();
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
      await _saveToFile();
    }
  }

  /// Remove a user domain
  static Future<void> removeUserDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userDomainsKey) ?? [];
    if (current.remove(domain.toLowerCase())) {
      await prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist();
      await _saveToFile();
    }
  }

  /// Remove a user keyword
  static Future<void> removeUserKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userKeywordsKey) ?? [];
    if (current.remove(keyword.toLowerCase())) {
      await prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist();
      await _saveToFile();
    }
  }

  /// Update an existing user domain
  static Future<void> updateUserDomain(String oldDomain, String newDomain) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userDomainsKey) ?? [];
    final oldCleaned = oldDomain.toLowerCase();
    final newCleaned = newDomain.trim().toLowerCase();

    if (newCleaned.isEmpty) return;

    final index = current.indexOf(oldCleaned);
    if (index != -1) {
      current[index] = newCleaned;
      await prefs.setStringList(_userDomainsKey, current);
      await buildFinalBlocklist();
      await _saveToFile();
    }
  }

  /// Update an existing user keyword
  static Future<void> updateUserKeyword(String oldKeyword, String newKeyword) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_userKeywordsKey) ?? [];
    final oldCleaned = oldKeyword.toLowerCase();
    final newCleaned = newKeyword.trim().toLowerCase();

    if (newCleaned.isEmpty) return;

    final index = current.indexOf(oldCleaned);
    if (index != -1) {
      current[index] = newCleaned;
      await prefs.setStringList(_userKeywordsKey, current);
      await buildFinalBlocklist();
      await _saveToFile();
    }
  }

  static Future<void> _saveToFile() async {
    final domains = await loadUserDomains();
    final keywords = await loadUserKeywords();
    final file = await _getLocalFile();
    final jsonString = json.encode({
      'domains': domains,
      'keywords': keywords,
    });
    await file.writeAsString(jsonString);
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
  static Future<void> importFromJson(String jsonString, {bool syncToFile = true}) async {
    try {
      // Cast the decoded JSON to Map<String, dynamic>
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final List<String> domains = List<String>.from(data['domains'] ?? []);
      final List<String> keywords = List<String>.from(data['keywords'] ?? []);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_userDomainsKey, domains.map((s) => s.toLowerCase()).toList());
      await prefs.setStringList(_userKeywordsKey, keywords.map((s) => s.toLowerCase()).toList());
      
      await buildFinalBlocklist();
      if (syncToFile) {
        await _saveToFile();
      }
    } catch (e) {
      throw Exception('Invalid JSON format for blocklist import');
    }
  }
}
