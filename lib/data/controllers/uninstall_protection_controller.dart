// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// Talks to the Android side that stops ClearNet being removed without the
/// uninstall PIN.
class UninstallProtectionController {
  static const platform = MethodChannel(Constants.methodChannelName);

  /// Turns protection on if an uninstall PIN is set, otherwise off.
  static Future<void> sync() async {
    try {
      final enabled = await PinService.hasPin(Constants.uninstallPinKey);
      await platform.invokeMethod('setUninstallProtection', {
        'enabled': enabled,
      });
    } on Exception catch (e) {
      // Never stop the app starting because of this
      debugPrint('Could not update uninstall protection: $e');
    }
  }

  /// Lets the user open the protected system screens for a short time, after
  /// entering the uninstall PIN.
  static Future<void> allowProtectedScreens() =>
      platform.invokeMethod('allowProtectedScreens');
}
