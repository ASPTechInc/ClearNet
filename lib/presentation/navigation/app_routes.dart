// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/presentation/screens/app_lock_screen.dart';
import 'package:clearnet/presentation/screens/blocked_access_screen.dart';
import 'package:clearnet/presentation/screens/blocked_content.dart';
import 'package:clearnet/presentation/screens/guide_screen.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/presentation/screens/protection_screen.dart';
import 'package:clearnet/presentation/screens/settings_screen.dart';

class AppRoutes {
  static const String root = '/';
  static const String verifyUninstallPin = '/verify_uninstall_pin';
  static const String setupPin = '/setup_pin';
  static const String settingsPath = '/settings';
  static const String home = '/protection';
  static const String blocked = '/blocked';
  static const String blockedSites = '/blocked_sites';
  static const String guide = '/guide';

  /// Returns the screen widget corresponding to the given route name.
  /// This provides the reverse mapping of route name to widget screen.
  static Widget getScreen(String route) {
    switch (route) {
      case root:
        return const AppLockScreen();

      case home:
        return const ProtectionScreen();

      case blocked:
        return const BlockedAccessScreen();

      case blockedSites:
        return const BlockedContentScreen();

      case settingsPath:
        return const SettingsScreen();

      case guide:
        return const GuideScreen();

      case verifyUninstallPin:
        return PinLockScreen(
          onSuccess: () async {
            SystemNavigator.pop();
          },
        );

      case setupPin:
        return const PinLockScreen(confirmMode: true);

      default:
        return Scaffold(
          body: Center(child: Text('No route defined for $route')),
        );
    }
  }

  /// Alias for [getScreen] for explicit clarity if needed.
  static Widget getScreenForRoute(String route) => getScreen(route);

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? root;
    switch (routeName) {
      case guide:
        return PageRouteBuilder(
          settings: settings,
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GuideScreen(),
        );

      case verifyUninstallPin:
      case setupPin:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => getScreen(routeName),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => getScreen(routeName),
        );
    }
  }
}
