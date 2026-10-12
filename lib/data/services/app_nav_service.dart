// Dart imports:
import 'dart:async';

// Package imports:
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

// Project imports:
import 'package:clearnet/data/services/app_tour_service.dart';

class AppNavigationService {
  // Tours only start on the selected tab, so re-check them whenever the tab
  // changes, including when the user taps the bottom navigation bar.
  static final PersistentTabController controller = PersistentTabController(
    initialIndex: 0,
  )..addListener(AppTourManager.notifyPermissionsUpdated);

  static void jumpToTab(int index) {
    controller.jumpToTab(index);
    AppTourManager.notifyPermissionsUpdated();
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 250),
        AppTourManager.notifyPermissionsUpdated,
      ),
    );
  }
}
