// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class StatsManager {
  static final _prefs = SharedPreferencesAsync();

  static Future<void> checkAndResetDailyStats() async {
    final lastDate = await _prefs.getString(Constants.lastStatsDateKey);
    final nowDate = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != nowDate) {
      await _prefs.setInt(Constants.blockedWebsitesCountKey, 0);
      await _prefs.setInt(Constants.blockedAppsCountKey, 0);
      await _prefs.setString(Constants.lastStatsDateKey, nowDate);
    }
  }

  static Future<int> getBlockedWebsitesCount() async {
    await checkAndResetDailyStats();
    return await _prefs.getInt(Constants.blockedWebsitesCountKey) ?? 0;
  }

  static Future<int> getBlockedAppsCount() async {
    await checkAndResetDailyStats();
    return await _prefs.getInt(Constants.blockedAppsCountKey) ?? 0;
  }
}
