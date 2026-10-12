// Dart imports:
import 'dart:async';

// Package imports:
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

// Project imports:
import 'package:clearnet/data/services/app_tour_service.dart';

class AppNavigationService {
  static final PersistentTabController controller = PersistentTabController(
    initialIndex: 0,
  );

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
