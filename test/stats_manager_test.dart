// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/data/services/stats_manager.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatsManager Unit Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StatsManager.platform, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getStats') {
              return {
                Constants.blockedWebsitesCountKey: 15,
                Constants.blockedAppsCountKey: 8,
                Constants.weeklyWebsitesCountKey: 42,
                Constants.weeklyAppsCountKey: 20,
                Constants.monthlyWebsitesCountKey: 150,
                Constants.monthlyAppsCountKey: 75,
              };
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(StatsManager.platform, null);
    });

    test(
      'getBlockedWebsitesCount returns correct count from native stats',
      () async {
        final count = await StatsManager.getBlockedWebsitesCount();
        expect(count, 15);
      },
    );

    test(
      'getBlockedAppsCount returns correct count from native stats',
      () async {
        final count = await StatsManager.getBlockedAppsCount();
        expect(count, 8);
      },
    );

    test(
      'getWeeklyWebsitesCount returns correct count from native stats',
      () async {
        final count = await StatsManager.getWeeklyWebsitesCount();
        expect(count, 42);
      },
    );

    test(
      'getWeeklyAppsCount returns correct count from native stats',
      () async {
        final count = await StatsManager.getWeeklyAppsCount();
        expect(count, 20);
      },
    );

    test(
      'getMonthlyWebsitesCount returns correct count from native stats',
      () async {
        final count = await StatsManager.getMonthlyWebsitesCount();
        expect(count, 150);
      },
    );

    test(
      'getMonthlyAppsCount returns correct count from native stats',
      () async {
        final count = await StatsManager.getMonthlyAppsCount();
        expect(count, 75);
      },
    );
  });
}
