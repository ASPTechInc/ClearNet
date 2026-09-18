// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/presentation/screens/biometric_lock_screen.dart';
import 'package:clearnet/presentation/screens/blocked_access_screen.dart';
import 'package:clearnet/presentation/screens/blocked_apps_screen.dart';
import 'package:clearnet/presentation/screens/blocked_sites.dart';
import 'package:clearnet/presentation/screens/home_screen.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/presentation/screens/settings_screen.dart';

class AppRoutes {
  static const String root = '/';
  static const String verifyUninstallPin = '/verify_uninstall_pin';
  static const String setupPin = '/setup_pin';
  static const String settingsPath = '/settings';
  static const String home = '/home';
  static const String blocked = '/blocked';
  static const String blockedApps = '/blocked_apps';
  static const String blockedSites = '/blocked_sites';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return MaterialPageRoute(builder: (_) => const AppLockScreen());

      case verifyUninstallPin:
        return MaterialPageRoute(
          builder: (context) => PinLockScreen(
            onSuccess: () async {
              SystemNavigator.pop();
            },
          ),
        );

      case setupPin:
        return MaterialPageRoute(builder: (_) => const PinLockScreen(confirmMode: true));

      case settingsPath:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case blocked:
        return MaterialPageRoute(builder: (_) => const BlockedAccessScreen());

      case blockedApps:
        return MaterialPageRoute(builder: (_) => const BlockedAppsScreen());

      case blockedSites:
        return MaterialPageRoute(builder: (_) => const BlockedSitesScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
