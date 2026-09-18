// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class StatsManager {
  static Future<void> checkAndResetDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(Constants.lastStatsDateKey);
    final nowDate = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != nowDate) {
      await prefs.setInt(Constants.blockedWebsitesCountKey, 0);
      await prefs.setInt(Constants.blockedAppsCountKey, 0);
      await prefs.setString(Constants.lastStatsDateKey, nowDate);
    }
  }

  static Future<int> getBlockedWebsitesCount() async {
    await checkAndResetDailyStats();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(Constants.blockedWebsitesCountKey) ?? 0;
  }

  static Future<int> getBlockedAppsCount() async {
    await checkAndResetDailyStats();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(Constants.blockedAppsCountKey) ?? 0;
  }
}
