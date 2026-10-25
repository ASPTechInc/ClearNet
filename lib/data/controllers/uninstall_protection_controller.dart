// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/app_lock_service.dart';
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

  /// Whether ClearNet is an active device admin. Without it Android lets the
  /// app be uninstalled freely, whatever the uninstall PIN.
  static Future<bool> isDeviceAdminActive() async {
    try {
      return await platform.invokeMethod<bool>('isDeviceAdminActive') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens Android's screen for allowing ClearNet as a device admin.
  static Future<void> requestDeviceAdmin() async {
    AppLockService.expectExternalActivity();
    await platform.invokeMethod('requestDeviceAdmin');
  }

  /// True if an uninstall PIN is set but device admin is off, so the app
  /// is not actually protected.
  static Future<bool> needsDeviceAdmin() async =>
      await PinService.hasPin(Constants.uninstallPinKey) &&
      !await isDeviceAdminActive();

  /// Lets the user open the protected system screens for a short time, after
  /// entering the uninstall PIN.
  static Future<void> allowProtectedScreens() =>
      platform.invokeMethod('allowProtectedScreens');
}
