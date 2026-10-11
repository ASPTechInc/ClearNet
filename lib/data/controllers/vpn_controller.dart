// Flutter imports:
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class VpnController {
  static const platform = MethodChannel(Constants.methodChannelName);

  /// Start VPN
  static Future<void> startVpn() async {
    await platform.invokeMethod('startVpn');
  }

  /// Stop VPN
  static Future<void> stopVpn() async {
    await platform.invokeMethod('stopVpn');
  }

  /// Add a site to block
  static Future<void> addSite(String domain) async {
    await platform.invokeMethod('blockSite', {'site': domain});
  }

  /// Remove a site
  static Future<void> removeSite(String domain) async {
    await platform.invokeMethod('removeSite', {'site': domain});
  }

  /// Add a keyword to block
  static Future<void> addKeyword(String keyword) async {
    await platform.invokeMethod('blockKeyword', {'keyword': keyword});
  }

  /// Remove a keyword
  static Future<void> removeKeyword(String keyword) async {
    await platform.invokeMethod('removeKeyword', {'keyword': keyword});
  }

  /// Add a site to the whitelist
  static Future<void> addWhitelist(String whitelist) async {
    await platform.invokeMethod('addWhitelist', {'whitelist': whitelist});
  }

  /// Remove a site from the whitelist
  static Future<void> removeWhitelist(String whitelist) async {
    await platform.invokeMethod('removeWhitelist', {'whitelist': whitelist});
  }

  /// Check if Accessibility Service is enabled
  static Future<bool> isAccessibilityServiceEnabled() async {
    return await platform.invokeMethod('isAccessibilityServiceEnabled') ??
        false;
  }

  /// Open Accessibility Settings
  static Future<void> openAccessibilitySettings() async {
    await platform.invokeMethod('openAccessibilitySettings');
  }

  /// Check if Ignoring Battery Optimisations
  static Future<bool> isIgnoringBatteryOptimisations() async {
    return await platform.invokeMethod('isIgnoringBatteryOptimizations') ??
        false;
  }

  /// Request Ignore Battery Optimisations
  static Future<void> requestIgnoreBatteryOptimisations() async {
    await platform.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  /// Show the native confirmation dialogue to disable blocking
  static Future<bool> showDisableConfirmation() async {
    return await platform.invokeMethod('showDisableConfirmation') ?? false;
  }

  /// Get Battery Stats
  static Future<Map<String, dynamic>> getBatteryStats() async {
    final stats = await platform.invokeMapMethod<String, dynamic>(
      'getBatteryStats',
    );
    return stats ?? {};
  }
}
