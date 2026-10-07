// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/app_tour_service.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/navigation/bottom_nav_bar.dart';
import 'package:clearnet/presentation/theme/app_theme.dart';
import 'package:clearnet/presentation/widgets/permission_requirement_dialogue.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService().init();
  await BlocklistManager.init();
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
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannel();
    unawaited(_checkInitialAction());
    AppTourManager.initialiseAppTour();
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
      }
    });
  }

  Future<void> _checkInitialAction() async {
    try {
      final String? action = await platform.invokeMethod('checkInitialAction');
      if (action == 'showBlocked') {
        // Delay slightly to ensure navigator is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToBlocked();
        });
      }
    } catch (e) {
      debugPrint('Error checking initial action: $e');
    }
  }

  void _navigateToBlocked() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.blocked,
      (route) => false,
    );
  }

  Future<void> _checkRequiredPermissions() async {
    if (_isDialogShowing) return;

    final bool isAccessibilityEnabled =
        await VpnController.isAccessibilityServiceEnabled();
    if (!isAccessibilityEnabled) {
      final bool granted = await _showAccessibilityDialog();
      if (!granted) return;
    }

    final bool isBatteryOptimised =
        await VpnController.isIgnoringBatteryOptimizations();
    if (!isBatteryOptimised) {
      final bool granted = await _showBatteryOptimisationDialog();
      if (!granted) return;
    }

    AppTourManager.notifyPermissionsUpdated();
  }

  Future<bool> _showAccessibilityDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    _isDialogShowing = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRequirementDialogue(
        title: 'Action required',
        description:
            'ClearNet requires the Safe Browsing Service to be enabled to ensure your safety while browsing. '
            'Please enable it in the Accessibility settings to continue using the app.',
        initialButtonText: 'Enable service',
        clickedButtonText: 'Confirm enabling',
        exitButtonText: 'Exit app',
        onActionPressed: () async {
          await VpnController.openAccessibilitySettings();
        },
        onCheckPermission: () async {
          return VpnController.isAccessibilityServiceEnabled();
        },
        onExitPressed: () => SystemNavigator.pop(),
        notEnabledMessage:
            'Safe Browsing Service is not enabled yet. Please locate "ClearNet" under "Installed apps" in Accessibility settings and turn it on.',
      ),
    );
    _isDialogShowing = false;
    return result ?? false;
  }

  Future<bool> _showBatteryOptimisationDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    _isDialogShowing = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionRequirementDialogue(
        title: 'Battery performance',
        description:
            'For the VPN and Website Blocking to work reliably, battery optimisation has to be disabled for ClearNet.',
        initialButtonText: 'Disable optimisation',
        clickedButtonText: 'Confirm disabling',
        exitButtonText: 'Exit app',
        onActionPressed: () async {
          await VpnController.requestIgnoreBatteryOptimisations();
        },
        onCheckPermission: () async {
          return VpnController.isIgnoringBatteryOptimizations();
        },
        onExitPressed: () => SystemNavigator.pop(),
        notEnabledMessage:
            'Battery optimisation is still active for ClearNet. Please allow ignoring battery optimisation.',
      ),
    );
    _isDialogShowing = false;
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
          home: const BottomNavBar(),
          // initialRoute: AppRoutes.root,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}
