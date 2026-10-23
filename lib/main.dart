// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/controllers/uninstall_protection_controller.dart';
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_nav_service.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/navigation/bottom_nav_bar.dart';
import 'package:clearnet/presentation/screens/app_lock_screen.dart';
import 'package:clearnet/presentation/theme/app_theme.dart';
import 'package:clearnet/presentation/widgets/permission_requirement_dialogue.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // List ClearNet's own licence alongside the packages in showLicensePage()
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      Constants.appName,
    ], await rootBundle.loadString('LICENSE'));
  });
  await ThemeService().init();
  await BlocklistManager.init();
  // Keep the Android side's uninstall protection in step with the saved PIN
  await UninstallProtectionController.sync();
  runApp(const ClearNetApp());
}

class ClearNetApp extends StatefulWidget {
  const ClearNetApp({super.key});

  @override
  State<ClearNetApp> createState() => _ClearNetAppState();
}

class _ClearNetAppState extends State<ClearNetApp> with WidgetsBindingObserver {
  static const platform = MethodChannel(Constants.methodChannelName);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _isDialogueShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannel();
    unawaited(_checkInitialAction());
    AppTourManager.initialiseAppTour();

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () async {
        await _checkRequiredPermissions();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _checkRequiredPermissions();
    }
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'showBlockedPage') {
        _navigateToBlocked();
      } else if (call.method == 'showUninstallPin') {
        _navigateToUninstallPin();
      }
    });
  }

  Future<void> _checkInitialAction() async {
    try {
      final String? action = await platform.invokeMethod('checkInitialAction');
      if (action == 'showBlocked' || action == 'verifyUninstallPin') {
        // Delay slightly to ensure navigator is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          action == 'showBlocked'
              ? _navigateToBlocked()
              : _navigateToUninstallPin();
        });
      }
    } catch (e) {
      debugPrint('Error checking initial action: $e');
    }
  }

  void _navigateToUninstallPin() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.verifyUninstallPin,
      (route) => route.isFirst,
    );
  }

  void _navigateToBlocked() {
    // Keep the main screen underneath, so leaving the blocked page returns to
    // the app. Earlier blocked pages are removed so they don't stack up.
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.blocked,
      (route) => route.isFirst,
    );
  }

  Future<void> _checkRequiredPermissions() async {
    if (_isDialogueShowing) return;

    final bool isAccessibilityEnabled =
        await VpnController.isAccessibilityServiceEnabled();
    if (!isAccessibilityEnabled) {
      final bool granted = await _showAccessibilityDialogue();
      if (!granted) return;
    }

    final bool isBatteryOptimised =
        await VpnController.isIgnoringBatteryOptimisations();
    if (!isBatteryOptimised) {
      final bool granted = await _showBatteryOptimisationDialog();
      if (!granted) return;
    }

    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 250),
        AppTourManager.notifyPermissionsUpdated,
      ),
    );
  }

  Future<bool> _showAccessibilityDialogue() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    _isDialogueShowing = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRequirementDialogue(
        title: 'Action required',
        description:
            '${Constants.appName} requires the Safe browsing service to be '
            'enabled to ensure your safety while browsing.\n\n'
            'Please enable it in the Accessibility settings to continue '
            'using the app.',
        initialButtonText: 'Enable service',
        clickedButtonText: 'Confirm enabling',
        // 1200 means 1.2 seconds
        primaryActionTextChangeDelay: const Duration(milliseconds: 1200),
        exitButtonText: 'Exit app',
        onActionPressed: () async {
          await VpnController.openAccessibilitySettings();
        },
        onCheckPermission: () async {
          return VpnController.isAccessibilityServiceEnabled();
        },
        onExitPressed: () => SystemNavigator.pop(),
        notEnabledMessage:
            'Safe browsing service is not enabled yet. Please locate '
            '"${Constants.appName}" under "Installed apps" in Accessibility '
            'settings and turn it on.',
      ),
    );
    _isDialogueShowing = false;
    return result ?? false;
  }

  Future<bool> _showBatteryOptimisationDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    _isDialogueShowing = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRequirementDialogue(
        title: 'Battery performance',
        description:
            'Battery optimisation has to be disabled for '
            '${Constants.appName} in order for the VPN and website '
            'blocking to work reliably.',
        initialButtonText: 'Disable optimisation',
        clickedButtonText: 'Confirm disabling',
        exitButtonText: 'Exit app',
        onActionPressed: () async {
          await VpnController.requestIgnoreBatteryOptimisations();
        },
        onCheckPermission: () async {
          return VpnController.isIgnoringBatteryOptimisations();
        },
        onExitPressed: () => SystemNavigator.pop(),
        notEnabledMessage:
            'Battery optimisation is still active for ${Constants.appName}. '
            'Please allow ignoring battery optimisation.',
      ),
    );
    _isDialogueShowing = false;
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: Constants.appName,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: AppLockScreen(
            child: BottomNavBar(controller: AppNavigationService.controller),
          ),
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}
