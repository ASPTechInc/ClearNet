// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/services/stats_manager.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatsManager Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('checkAndResetDailyStats resets stats when date changes', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Set stats and a past date
      await prefs.setInt(Constants.blockedWebsitesCountKey, 10);
      await prefs.setInt(Constants.blockedAppsCountKey, 5);
      await prefs.setString(Constants.lastStatsDateKey, '2020-01-01');

      await StatsManager.checkAndResetDailyStats();

      expect(prefs.getInt(Constants.blockedWebsitesCountKey), 0);
      expect(prefs.getInt(Constants.blockedAppsCountKey), 0);
      expect(prefs.getString(Constants.lastStatsDateKey), 
             DateTime.now().toIso8601String().split('T')[0]);
    });

    test('checkAndResetDailyStats does not reset stats when date is the same', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      await prefs.setInt(Constants.blockedWebsitesCountKey, 10);
      await prefs.setInt(Constants.blockedAppsCountKey, 5);
      await prefs.setString(Constants.lastStatsDateKey, today);

      await StatsManager.checkAndResetDailyStats();

      expect(prefs.getInt(Constants.blockedWebsitesCountKey), 10);
      expect(prefs.getInt(Constants.blockedAppsCountKey), 5);
      expect(prefs.getString(Constants.lastStatsDateKey), today);
    });

    test('getBlockedWebsitesCount returns correct count and triggers reset', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(Constants.blockedWebsitesCountKey, 15);
      await prefs.setString(Constants.lastStatsDateKey, DateTime.now().toIso8601String().split('T')[0]);

      final count = await StatsManager.getBlockedWebsitesCount();
      expect(count, 15);
    });

    test('getBlockedAppsCount returns correct count and triggers reset', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(Constants.blockedAppsCountKey, 8);
      await prefs.setString(Constants.lastStatsDateKey, DateTime.now().toIso8601String().split('T')[0]);

      final count = await StatsManager.getBlockedAppsCount();
      expect(count, 8);
    });
  });
}
