// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/theme/app_theme.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () async{
        await _checkAccessibilityService();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async{
    if (state == AppLifecycleState.resumed) {
      await _checkAccessibilityService();
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

  Future<void> _checkAccessibilityService() async {
    final bool isEnabled = await VpnController.isAccessibilityServiceEnabled();
    if (isEnabled) {
      if (_isDialogShowing) {
        navigatorKey.currentState?.pop();
        _isDialogShowing = false;
      }
    } else {
      if (!_isDialogShowing) {
        await _showAccessibilityDialog();
      }
    }
  }

  Future<void> _showAccessibilityDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Action required'),
          content: const Text(
            'ClearNet requires the Safe Browsing Service to be enabled to ensure your safety while browsing. '
            'Please enable it in the Accessibility settings to continue using the app. '
            'Search for "ClearNet" in "Installed apps" section.',
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Exit app'),
            ),
            ElevatedButton(
              onPressed: () async {
                await VpnController.openAccessibilitySettings();
              },
              child: const Text('Enable service'),
            ),
          ],
        ),
      ),
    ).then((_) => _isDialogShowing = false);
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
          initialRoute: AppRoutes.root,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}
