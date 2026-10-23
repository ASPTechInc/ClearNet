// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class StatsManager {
  static const platform = MethodChannel(Constants.methodChannelName);

  static Future<Map<String, dynamic>> _getNativeStats() async {
    try {
      final Map<dynamic, dynamic>? stats = await platform.invokeMethod(
        'getStats',
      );
      if (stats != null) {
        return Map<String, dynamic>.from(stats);
      }
    } catch (e) {
      // Ignore errors
    }
    return {};
  }

  static Future<int> getBlockedWebsitesCount() async {
    final stats = await _getNativeStats();
    return stats[Constants.blockedWebsitesCountKey] ?? 0;
  }

  static Future<int> getBlockedAppsCount() async {
    final stats = await _getNativeStats();
    return stats[Constants.blockedAppsCountKey] ?? 0;
  }

  static Future<int> getWeeklyWebsitesCount() async {
    final stats = await _getNativeStats();
    return stats[Constants.weeklyWebsitesCountKey] ?? 0;
  }

  static Future<int> getWeeklyAppsCount() async {
    final stats = await _getNativeStats();
    return stats[Constants.weeklyAppsCountKey] ?? 0;
  }

  static Future<int> getMonthlyWebsitesCount() async {
    final stats = await _getNativeStats();
    return stats[Constants.monthlyWebsitesCountKey] ?? 0;
  }

  static Future<int> getMonthlyAppsCount() async {
    final stats = await _getNativeStats();
    return stats[Constants.monthlyAppsCountKey] ?? 0;
  }
}
