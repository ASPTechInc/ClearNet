// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/theme_service.dart';
import 'package:clearnet/presentation/screens/biometric_lock_screen.dart';
import 'package:clearnet/presentation/screens/blocked_access_screen.dart';
import 'package:clearnet/presentation/screens/blocked_apps_screen.dart';
import 'package:clearnet/presentation/screens/home_screen.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/presentation/screens/settings_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService().init();
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
    _checkInitialAction();
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
      '/blocked',
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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.red[900]!,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.red[900]!,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: mode,
          initialRoute: '/',
          routes: {
            '/': (_) => const BiometricLockScreen(),
            '/verify_uninstall_pin': (context) => PinLockScreen(
                  onSuccess: () {
                    SystemNavigator.pop();
                  },
                ),
            '/setup_pin': (_) => const PinLockScreen(confirmMode: true),
            '/settings': (_) => const SettingsScreen(),
            '/home': (_) => const HomeScreen(),
            '/blocked': (_) => const BlockedAccessScreen(),
            '/blocked_apps': (_) => const BlockedAppsScreen(),
          },
        );
      },
    );
  }
}
