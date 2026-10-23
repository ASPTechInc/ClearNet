// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_nav_service.dart';

/// A central manager for handling app-wide feature showcase tours
/// using [ShowcaseView].
class AppTourManager {
  AppTourManager._();

  static const String _appTourCompletedKey = 'has_seen_app_tour';
  static const String _protectionTourKey = 'has_seen_protection_tour';
  static const String _contentTourKey = 'has_seen_content_tour';
  static const String _settingsTourKey = 'has_seen_settings_tour';
  static const String _blockedAppsTourKey = 'has_seen_blocked_apps_tour';
  static const String _guideTourKey = 'has_seen_guide_tour';

  static String get protectionTourKey => _protectionTourKey;
  static String get contentTourKey => _contentTourKey;
  static String get settingsTourKey => _settingsTourKey;
  static String get blockedAppsTourKey => _blockedAppsTourKey;
  static String get guideTourKey => _guideTourKey;

  /// A notifier triggered when permissions check completes or updates.
  static final ValueNotifier<int> permissionsCheckNotifier = ValueNotifier(0);

  /// Triggers a notification so listening screens re-evaluate if the app tour
  /// can start.
  static void notifyPermissionsUpdated() {
    permissionsCheckNotifier.value++;
    debugPrint('AppTourManager: permissions updated');
  }

  static bool _isRegistered = false;

  /// The finish callback of the tour currently running. Only one tour runs at
  /// a time, so it is invoked once when that tour finishes and then cleared.
  /// Registering it via [ShowcaseView.addOnFinishCallback] would keep it
  /// around, so it would fire again when a later tour (e.g. on Settings)
  /// finishes.
  static VoidCallback? _activeOnFinish;

  /// Steps whose tooltip would sit under the floating "Skip tour" button.
  static final Set<GlobalKey> _hideSkipButtonKeys = {};

  static void _handleFinish() {
    final callback = _activeOnFinish;
    _activeOnFinish = null;
    callback?.call();
  }

  static void _startShowcase(List<GlobalKey> keys, VoidCallback? onFinish) {
    _activeOnFinish = onFinish;
    ShowcaseView.get().startShowCase(keys);
  }

  static TooltipActionButton _previousAction() => TooltipActionButton(
    type: TooltipDefaultActionType.previous,
    name: 'Previous',
    backgroundColor: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
  );

  static TooltipActionButton _nextAction({String name = 'Next'}) =>
      TooltipActionButton(
        type: TooltipDefaultActionType.next,
        name: name,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      );

  /// Ensures ShowcaseView is registered.  Safe to call multiple times.
  static void ensureRegistration() {
    if (_isRegistered) return;
    try {
      ShowcaseView.get();
      _isRegistered = true;
    } catch (_) {
      initialiseAppTour();
    }
  }

  /// Initialises and registers the global configuration for [ShowcaseView].
  /// Call this during app startup or before displaying the main UI
  /// (e.g. in [main.dart] on [BottomNavBar]).
  static void initialiseAppTour({
    List<GlobalKey>? hideFloatingActionForKeys,
    VoidCallback? onDismiss,
  }) {
    ShowcaseView.register(
      blurValue: 1.5,
      hideFloatingActionWidgetForShowcase: [
        ..._hideSkipButtonKeys,
        ...?hideFloatingActionForKeys,
      ],
      autoPlayDelay: const Duration(seconds: 4),
      globalFloatingActionWidget: (showcaseContext) {
        final theme = Theme.of(showcaseContext);
        final colorScheme = theme.colorScheme;
        final bottomInset = MediaQuery.viewPaddingOf(showcaseContext).bottom;

        return FloatingActionWidget(
          left: 16,
          bottom: bottomInset + kBottomNavigationBarHeight + 12,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: FilledButton.tonalIcon(
              onPressed: () => ShowcaseView.get().dismiss(),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text(
                'Skip tour',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHigh,
                foregroundColor: colorScheme.primary,
                elevation: 3,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.spaceBetween,
        actionGap: 16,
      ),
      globalTooltipActions: [_previousAction(), _nextAction()],
      onFinish: _handleFinish,
      onDismiss: (key) {
        debugPrint('Showcase dismissed at key: $key');
        // A skipped tour must not trigger its follow-up navigation later.
        _activeOnFinish = null;
        onDismiss?.call();
      },
    );
    _isRegistered = true;
  }

  /// Wraps any given [child] widget with a [Showcase] spotlight.
  /// Falls back to rendering [child] directly when ShowcaseView is not
  /// registered
  /// (e.g. in unit/widget tests that don't set up the showcase).
  ///
  /// Set [enableAutoScroll] for targets inside a vertically scrolling list
  /// that may be off-screen. Leave it off for targets inside horizontally
  /// paged views (e.g. a [TabBarView]): scrolling would nudge the pager.
  /// Set [isLastStep] on the final step of the whole tour to label its
  /// forward button "Finish" instead of "Next".
  /// Set [hideSkipButton] when the step's tooltip sits low enough on screen
  /// to be covered by the floating "Skip tour" button.
  static Widget appTourItem({
    required GlobalKey key,
    required Widget child,
    required String title,
    required String description,
    ShapeBorder? targetShapeBorder,
    EdgeInsets? targetPadding,
    TooltipPosition? tooltipPosition,
    VoidCallback? onTargetClick,
    Color? tooltipBackgroundColor,
    Color? textColor,
    Widget Function(BuildContext)? customTooltip,
    bool enableAutoScroll = false,
    bool isLastStep = false,
    bool hideSkipButton = false,
  }) {
    ensureRegistration();
    if (hideSkipButton && _hideSkipButtonKeys.add(key)) {
      ShowcaseView.get().hideFloatingActionWidgetForKeys(
        _hideSkipButtonKeys.toList(),
      );
    }
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Showcase(
          key: key,
          title: title,
          description: description,
          titleTextStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor ?? colorScheme.onSurface,
            letterSpacing: 0.15,
          ),
          descTextStyle: theme.textTheme.bodyMedium?.copyWith(
            color:
                textColor?.withValues(alpha: 0.8) ??
                colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          tooltipBackgroundColor:
              tooltipBackgroundColor ?? colorScheme.surfaceContainerHigh,
          tooltipBorderRadius: BorderRadius.circular(20),
          tooltipPadding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          targetShapeBorder:
              targetShapeBorder ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          targetPadding: targetPadding ?? const EdgeInsets.all(8),
          tooltipPosition: tooltipPosition,
          onTargetClick: onTargetClick,
          overlayColor: Colors.black,
          overlayOpacity: 0.65,
          blurValue: 1.5,
          enableAutoScroll: enableAutoScroll,
          scrollAlignment: 0.3,
          scrollLoadingWidget: const SizedBox.shrink(),
          tooltipActions: isLastStep
              ? [_previousAction(), _nextAction(name: 'Finish')]
              : null,
          child: child,
        );
      },
    );
  }

  /// Starts the showcase walkthrough for the provided list of [keys].
  static void startAppTour(
    List<GlobalKey> keys, {
    String? tourKey,
    VoidCallback? onFinish,
  }) {
    if (keys.isEmpty) return;
    ensureRegistration();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final showcase = ShowcaseView.get();
      if (showcase.isShowcaseRunning ||
          !keys.every(showcase.isTargetRendered)) {
        return;
      }
      _startShowcase(keys, onFinish);
      if (tourKey != null) {
        final prefs = SharedPreferencesAsync();
        await prefs.setBool(tourKey, true);
      }
    });
  }

  /// Starts the showcase walkthrough if:
  /// 1. The user hasn't completed/seen the tour yet (checked via [tourKey]).
  /// 2. The global app-tour flag has not been set (prevents re-showing after
  ///    a one-time global dismissal, e.g. during onboarding).
  /// 3. Safe browsing or Accessibility service is enabled.
  /// 4. Battery Optimisation is disabled (ignored).
  /// 5. No modal dialog or overlay route is currently visible on top of
  ///    [context].
  /// 6. When [tabIndex] is given, that bottom-nav tab is the one selected.
  ///    All tab screens stay mounted in the persistent tab layout, so without
  ///    this an off-screen tab could start its tour over the visible one.
  ///
  /// [beforeStart] runs once all conditions pass, just before the targets are
  /// checked, so a screen can bring them on-stage (e.g. scroll to the top or
  /// select the right tab).
  static Future<bool> startAppTourIfReady({
    required BuildContext context,
    required List<GlobalKey> keys,
    String? tourKey,
    VoidCallback? onFinish,
    int? tabIndex,
    VoidCallback? beforeStart,
  }) async {
    bool isOnTab() =>
        tabIndex == null || AppNavigationService.controller.index == tabIndex;
    if (!isOnTab()) return false;

    ensureRegistration();
    final keyToUse = tourKey ?? _appTourCompletedKey;
    final prefs = SharedPreferencesAsync();

    // Check both the screen-specific key and the global key so that setting
    // `has_seen_app_tour = true` suppresses every individual screen tour.
    final hasSeenGlobal = await prefs.getBool(_appTourCompletedKey) ?? false;
    final hasSeen = await prefs.getBool(keyToUse) ?? false;
    if (hasSeenGlobal || hasSeen || keys.isEmpty) return false;

    if (ShowcaseView.get().isShowcaseRunning) return false;

    // Verify Safe Browsing / Accessibility service is enabled
    final isAccessibilityEnabled =
        await VpnController.isAccessibilityServiceEnabled();
    if (!isAccessibilityEnabled) return false;

    // Verify Battery Optimisation is disabled
    final isBatteryOptimised =
        await VpnController.isIgnoringBatteryOptimisations();
    if (!isBatteryOptimised) return false;

    // In the persistent tab layout, a screen can be mounted and visible without
    // being the current route from the Navigator perspective. We only require
    // it to still be mounted and to have rendered targets before starting.
    if (!context.mounted || !isOnTab()) return false;

    if (beforeStart != null) {
      beforeStart();
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted || !isOnTab()) return false;
    }

    // Only the first target has to be on-stage: later targets in a lazily
    // built list are scrolled into view as the tour reaches them.
    final showcaseView = ShowcaseView.get();
    if (showcaseView.isShowcaseRunning ||
        !showcaseView.isTargetRendered(keys.first)) {
      return false;
    }

    // All conditions satisfied: trigger app tour
    _startShowcase(keys, onFinish);
    await prefs.setBool(keyToUse, true);
    return true;
  }

  /// Resets the showcase tour state so it can be played again from
  /// Settings screen.
  static Future<void> resetAppTourState() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_appTourCompletedKey);
    await prefs.remove(_protectionTourKey);
    await prefs.remove(_contentTourKey);
    await prefs.remove(_settingsTourKey);
    await prefs.remove(_blockedAppsTourKey);
    await prefs.remove(_guideTourKey);
  }
}
