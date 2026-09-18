// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/blocklist_manager.dart';
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/theme/app_theme.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService().init();
  await BlocklistManager.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel(Constants.methodChannelName);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    unawaited(_checkInitialAction());
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
