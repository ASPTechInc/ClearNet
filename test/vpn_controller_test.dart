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
                return null;
              case 'blockSite':
                return null;
              case 'removeSite':
                return null;
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

    test('startVpn invokes method channel startVpn correctly', () async {
      await VpnController.startVpn();
      expect(log, hasLength(1));
      expect(log.first.method, 'startVpn');
      expect(log.first.arguments, isNull);
    });

    test(
      'addSite invokes method channel blockSite with appropriate payload',
      () async {
        await VpnController.addSite('pornsite.com');
        expect(log, hasLength(1));
        expect(log.first.method, 'blockSite');
        expect(log.first.arguments, {'site': 'pornsite.com'});
      },
    );

    test(
      'removeSite invokes method channel removeSite with appropriate payload',
      () async {
        await VpnController.removeSite('unblockme.org');
        expect(log, hasLength(1));
        expect(log.first.method, 'removeSite');
        expect(log.first.arguments, {'site': 'unblockme.org'});
      },
    );
  });
}
