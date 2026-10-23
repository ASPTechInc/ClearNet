// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VpnController MethodChannel Unit Tests', () {
    final List<MethodCall> log = <MethodCall>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, (
            MethodCall methodCall,
          ) async {
            log.add(methodCall);
            switch (methodCall.method) {
              case 'startVpn':
              case 'stopVpn':
              case 'blockSite':
              case 'removeSite':
              case 'blockKeyword':
              case 'removeKeyword':
              case 'openAccessibilitySettings':
              case 'requestIgnoreBatteryOptimizations':
                return null;
              case 'isAccessibilityServiceEnabled':
              case 'isIgnoringBatteryOptimizations':
                return true;
              case 'getBatteryStats':
                return {'level': 100, 'isCharging': true};
              default:
                throw PlatformException(code: 'Unimplemented');
            }
          });
      log.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VpnController.platform, null);
    });

    test('startVpn invokes method channel correctly', () async {
      await VpnController.startVpn();
      expect(log, hasLength(1));
      expect(log.first.method, 'startVpn');
    });

    test('stopVpn invokes method channel correctly', () async {
      await VpnController.stopVpn();
      expect(log, hasLength(1));
      expect(log.first.method, 'stopVpn');
    });

    test('addSite invokes blockSite correctly', () async {
      await VpnController.addSite('example.com');
      expect(log, hasLength(1));
      expect(log.first.method, 'blockSite');
      expect(log.first.arguments, {'site': 'example.com'});
    });

    test('addKeyword invokes blockKeyword correctly', () async {
      await VpnController.addKeyword('badword');
      expect(log, hasLength(1));
      expect(log.first.method, 'blockKeyword');
      expect(log.first.arguments, {'keyword': 'badword'});
    });

    test('isAccessibilityServiceEnabled returns correct value', () async {
      final enabled = await VpnController.isAccessibilityServiceEnabled();
      expect(enabled, isTrue);
      expect(log.first.method, 'isAccessibilityServiceEnabled');
    });

    test('getBatteryStats returns correct map', () async {
      final stats = await VpnController.getBatteryStats();
      expect(stats, {'level': 100, 'isCharging': true});
    });
  });
}
