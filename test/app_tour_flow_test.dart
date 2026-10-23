// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:showcaseview/showcaseview.dart';

// Project imports:
import 'package:clearnet/data/services/app_nav_service.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/main.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// End-to-end tests of the feature tour across the bottom-nav tabs:
/// Protection → Content → Settings, both on first launch and when replayed
/// from Settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  const protectionSteps = ['Activate blocking', 'Daily blocking statistics'];
  const contentSteps = [
    'Import & Export',
    'Filter categories',
    'Add custom rule',
    'Save rule',
  ];
  const settingsSteps = [
    'App lock',
    'Disguise mode',
    'Uninstall protection',
    'Secure DNS Resolver',
    'Replay feature tour',
  ];

  // Every tab the app switches to, in order, so a flip-flop between tabs
  // fails the test.
  final tabHistory = <int>[];
  void recordTab() => tabHistory.add(AppNavigationService.controller.index);

  setUp(() async {
    await SharedPreferencesAsync().clear();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: Constants.appName,
      packageName: 'com.example.clearnet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '.',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(Constants.methodChannelName),
          (call) async => switch (call.method) {
            'isAccessibilityServiceEnabled' => true,
            'isIgnoringBatteryOptimizations' => true,
            _ => null,
          },
        );

    // The tab controller is a static singleton shared by every test.
    AppNavigationService.controller.jumpToTab(0);
    tabHistory.clear();
    AppNavigationService.controller.addListener(recordTab);
  });

  tearDown(() {
    AppNavigationService.controller.removeListener(recordTab);
    // The showcase state is global: don't let a test that fails mid-tour
    // leave a tour running for the next one.
    final showcase = ShowcaseView.get();
    if (showcase.isShowcaseRunning) showcase.dismiss();
  });

  double contentTabAnimation(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.animation!.value;

  /// Title of the step currently spotlighted, or null if no tour is running.
  String? activeStep(WidgetTester tester) {
    final key = ShowcaseView.get().getActiveShowcaseKey;
    if (key == null) return null;
    final showcase = find.byWidgetPredicate(
      (widget) => widget is Showcase && widget.showcaseKey == key,
    );
    return tester.widget<Showcase>(showcase).title;
  }

  /// Checks that must hold on every frame while a tour is running, so
  /// glitches that only last for a moment are still caught.
  void checkFrame(WidgetTester tester) {
    if (!ShowcaseView.get().isShowcaseRunning) return;
    // Moving between steps should only scroll, not show a loading spinner.
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsNothing,
      reason: 'spinner shown during step "${activeStep(tester)}"',
    );
    if (AppNavigationService.controller.index == 1) {
      // The Content tour only uses the Domains tab: the pager must not even
      // start sliding towards another tab.
      expect(
        contentTabAnimation(tester),
        0.0,
        reason: 'Content tabs moved during step "${activeStep(tester)}"',
      );
    }
  }

  /// Pumps frames for [duration], running [checkFrame] on each one.
  /// pumpAndSettle can't be used: the tooltip's bounce animation repeats
  /// forever, so it would never settle.
  Future<void> pumpFrames(WidgetTester tester, Duration duration) async {
    const frame = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < duration; t += frame) {
      await tester.pump(frame);
      checkFrame(tester);
    }
  }

  /// Lets the screens' debounced tour checks run and the tour animate in.
  Future<void> settle(WidgetTester tester, {int seconds = 2}) =>
      pumpFrames(tester, Duration(seconds: seconds));

  /// A tooltip button. The tour overlay is inserted outside the route's own
  /// subtree, so the default finder treats it as offstage.
  Finder tourButton(String label) => find.text(label, skipOffstage: false);

  /// Pumps until a step's tooltip is showing. Steps that auto-scroll their
  /// target into view show no tooltip until the scroll has settled.
  Future<void> waitForTooltip(WidgetTester tester) async {
    for (var i = 0; i < 100 && tourButton('Previous').evaluate().isEmpty; i++) {
      await pumpFrames(tester, const Duration(milliseconds: 100));
    }
  }

  int contentSubTab(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  /// Walks [steps] on [tab], checking each step is shown on the right tab and
  /// labelled 'Next', or 'Finish' when [endsTour] and it is the last one.
  Future<void> walkTour(
    WidgetTester tester, {
    required int tab,
    required List<String> steps,
    bool endsTour = false,
  }) async {
    for (var i = 0; i < steps.length; i++) {
      await waitForTooltip(tester);
      expect(activeStep(tester), steps[i]);
      expect(AppNavigationService.controller.index, tab);
      if (tab == 1) {
        // The Content tour only uses the Domains tab; it must not move.
        expect(contentSubTab(tester), 0, reason: 'on step "${steps[i]}"');
      }

      final isLast = i == steps.length - 1;
      final label = isLast && endsTour ? 'Finish' : 'Next';
      expect(tourButton(label), findsOneWidget, reason: 'on "${steps[i]}"');
      if (isLast && endsTour) expect(tourButton('Next'), findsNothing);

      await tester.tap(tourButton(label));
      await settle(tester);
    }
  }

  Future<void> walkWholeTour(WidgetTester tester) async {
    await walkTour(tester, tab: 0, steps: protectionSteps);
    await walkTour(tester, tab: 1, steps: contentSteps);
    await walkTour(tester, tab: 2, steps: settingsSteps, endsTour: true);
  }

  /// After the final 'Finish' the tour is over and the app stays on Settings.
  Future<void> expectTourEndedOnSettings(WidgetTester tester) async {
    // Give any stray finish callbacks time to fire.
    await settle(tester, seconds: 3);

    expect(ShowcaseView.get().isShowcaseRunning, isFalse);
    expect(AppNavigationService.controller.index, 2);
    expect(tabHistory.last, 2);

    final prefs = SharedPreferencesAsync();
    for (final key in [
      AppTourManager.protectionTourKey,
      AppTourManager.contentTourKey,
      AppTourManager.settingsTourKey,
    ]) {
      expect(await prefs.getBool(key), isTrue, reason: key);
    }
  }

  testWidgets('first launch tours Protection → Content → Settings', (
    tester,
  ) async {
    await tester.pumpWidget(const ClearNetApp());
    await settle(tester);

    await walkWholeTour(tester);
    await expectTourEndedOnSettings(tester);

    expect(tabHistory, [1, 2]);
  });

  testWidgets('replay from Settings tours Protection → Content → Settings', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    for (final key in [
      AppTourManager.protectionTourKey,
      AppTourManager.contentTourKey,
      AppTourManager.settingsTourKey,
      AppTourManager.guideTourKey,
    ]) {
      await prefs.setBool(key, true);
    }

    await tester.pumpWidget(const ClearNetApp());
    await settle(tester);
    expect(ShowcaseView.get().isShowcaseRunning, isFalse);

    // Open Settings and scroll down to the replay tile, as a user would.
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(ShowcaseView.get().isShowcaseRunning, isFalse);

    final replayTile = find.widgetWithText(ListTile, 'Replay app tour');
    await tester.scrollUntilVisible(
      replayTile,
      200,
      // The Settings page itself. The DNS text field inside it has its own
      // scrollable, but widgets are found parent first, so .first is the page.
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    tabHistory.clear();

    await tester.tap(replayTile);
    await settle(tester);

    // The replay must start on Protection, not with a step from another
    // tab.
    expect(AppNavigationService.controller.index, 0);
    await walkWholeTour(tester);
    await expectTourEndedOnSettings(tester);

    expect(tabHistory, [0, 1, 2]);
  });

  testWidgets('tapping the Settings tab starts its unseen tour', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(AppTourManager.protectionTourKey, true);
    await prefs.setBool(AppTourManager.contentTourKey, true);

    await tester.pumpWidget(const ClearNetApp());
    await settle(tester);
    expect(ShowcaseView.get().isShowcaseRunning, isFalse);

    // A tap on the nav bar, not a programmatic tab jump.
    await tester.tap(find.text('Settings'));
    await settle(tester);

    await walkTour(tester, tab: 2, steps: settingsSteps, endsTour: true);
    await expectTourEndedOnSettings(tester);
  });

  testWidgets(
    'after skipping a replayed tour, tapping the Content tab starts its tour',
    (tester) async {
      final prefs = SharedPreferencesAsync();
      for (final key in [
        AppTourManager.protectionTourKey,
        AppTourManager.contentTourKey,
        AppTourManager.settingsTourKey,
      ]) {
        await prefs.setBool(key, true);
      }

      await tester.pumpWidget(const ClearNetApp());
      await settle(tester);

      // Visit every tab first so their screens are already built and won't
      // re-check the tour from initState.
      await tester.tap(find.text('Content'));
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);

      final replayTile = find.widgetWithText(ListTile, 'Replay app tour');
      await tester.scrollUntilVisible(
        replayTile,
        200,
        // The Settings page itself (see the test above)
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(replayTile);
      await settle(tester);
      await waitForTooltip(tester);
      expect(activeStep(tester), protectionSteps.first);

      await tester.tap(tourButton('Skip tour'));
      await settle(tester);
      expect(AppNavigationService.controller.index, 0);

      await tester.tap(find.text('Content'));
      await settle(tester);
      await walkTour(tester, tab: 1, steps: contentSteps);
      await walkTour(tester, tab: 2, steps: settingsSteps, endsTour: true);
      await expectTourEndedOnSettings(tester);
    },
  );

  testWidgets('skipping the Protection tour does not jump to Content', (
    tester,
  ) async {
    await tester.pumpWidget(const ClearNetApp());
    await settle(tester);
    expect(activeStep(tester), protectionSteps.first);

    await tester.tap(tourButton('Skip tour'));
    await settle(tester, seconds: 3);

    expect(ShowcaseView.get().isShowcaseRunning, isFalse);
    expect(AppNavigationService.controller.index, 0);
    expect(tabHistory, isEmpty);
  });
}
