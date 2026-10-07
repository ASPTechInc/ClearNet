// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';

/// A central manager for handling app-wide feature showcase tours using [ShowcaseView].
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

  /// Triggers a notification so listening screens re-evaluate if the app tour can start.
  static void notifyPermissionsUpdated() {
    permissionsCheckNotifier.value++;
    debugPrint('AppTourManager: permissions updated');
  }

  /// Initialises and registers the global configuration for [ShowcaseView].
  /// Call this during app startup or before displaying the main UI (e.g. in [main.dart] on [BottomNavBar]).
  static void initialiseAppTour({
    List<GlobalKey>? hideFloatingActionForKeys,
    VoidCallback? onDismiss,
  }) {
    ShowcaseView.register(
      blurValue: 1.5,
      autoPlayDelay: const Duration(seconds: 4),
      globalFloatingActionWidget: (showcaseContext) {
        final theme = Theme.of(showcaseContext);
        final colorScheme = theme.colorScheme;

        return FloatingActionWidget(
          left: 16,
          bottom: 24,
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
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.previous,
          name: 'Previous',
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: 'Next',
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
      onDismiss: (key) {
        debugPrint('Showcase dismissed at key: $key');
        onDismiss?.call();
      },
    );
  }

  /// Wraps any given [child] widget with a [Showcase] spotlight.
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
  }) {
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
            color: textColor?.withValues(alpha: 0.8) ?? colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          tooltipBackgroundColor:
              tooltipBackgroundColor ?? colorScheme.surfaceContainerHigh,
          tooltipBorderRadius: BorderRadius.circular(20),
          tooltipPadding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          targetShapeBorder: targetShapeBorder ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
          targetPadding: targetPadding ?? const EdgeInsets.all(8),
          tooltipPosition: tooltipPosition,
          onTargetClick: onTargetClick,
          overlayColor: Colors.black,
          overlayOpacity: 0.65,
          blurValue: 1.5,
          child: child,
        );
      },
    );
  }

  /// Starts the showcase walkthrough for the provided list of [keys].
  static void startAppTour(List<GlobalKey> keys) {
    if (keys.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShowcaseView.get().startShowCase(keys);
    });
  }

  /// Starts the showcase walkthrough if:
  /// 1. The user hasn't completed/seen the tour yet (checked via [tourKey]).
  /// 2. Safe Browsing / Accessibility Service is enabled.
  /// 3. Battery Optimisation is disabled (ignored).
  /// 4. No modal dialog or overlay route is currently visible on top of [context].
  static Future<bool> startAppTourIfReady({
    required BuildContext context,
    required List<GlobalKey> keys,
    String? tourKey,
  }) async {
    final keyToUse = tourKey ?? _appTourCompletedKey;
    final prefs = SharedPreferencesAsync();
    final hasSeen = await prefs.getBool(keyToUse) ?? false;
    if (hasSeen || keys.isEmpty) return false;

    // Verify Safe Browsing / Accessibility service is enabled
    final isAccessibilityEnabled =
        await VpnController.isAccessibilityServiceEnabled();
    if (!isAccessibilityEnabled) return false;

    // Verify Battery Optimisation is disabled
    final isBatteryOptimised =
        await VpnController.isIgnoringBatteryOptimizations();
    if (!isBatteryOptimised) return false;

    // Verify no dialog or route is showing on top of the context route
    if (!context.mounted) return false;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrentRoute) return false;

    // All conditions satisfied: trigger app tour
    startAppTour(keys);
    await prefs.setBool(keyToUse, true);
    return true;
  }

  /// Starts the showcase walkthrough if the user hasn't seen it yet.
  static Future<void> startAppTourIfNeeded(
    List<GlobalKey> keys, {
    String? tourKey,
  }) async {
    final keyToUse = tourKey ?? _appTourCompletedKey;
    final prefs = SharedPreferencesAsync();
    final hasSeen = await prefs.getBool(keyToUse) ?? false;
    if (!hasSeen && keys.isNotEmpty) {
      startAppTour(keys);
      await prefs.setBool(keyToUse, true);
    }
  }

  /// Resets the showcase tour state so it can be played again from Settings/Help.
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
