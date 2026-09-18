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
}
