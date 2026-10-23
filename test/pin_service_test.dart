// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'app_pin';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PinService.iterations = 1000;
  });

  Future<String?> stored() => const FlutterSecureStorage().read(key: key);

  test('hasPin is false until a PIN is saved', () async {
    expect(await PinService.hasPin(key), isFalse);
    await PinService.savePin(key, '123456789');
    expect(await PinService.hasPin(key), isTrue);
  });

  test('the same PIN gets a different salt each time it is saved', () async {
    await PinService.savePin(key, '123456789');
    final first = await stored();
    await PinService.savePin(key, '123456789');
    final second = await stored();

    expect(first, isNot(second));
    expect(await PinService.verifyPin(key, '123456789'), isTrue);
  });

  test('a PIN saved with a different iteration count still verifies', () async {
    PinService.iterations = 500;
    await PinService.savePin(key, '123456789');
    PinService.iterations = 1000;

    expect(await PinService.verifyPin(key, '123456789'), isTrue);
  });

  test('verifying with no saved PIN fails', () async {
    expect(await PinService.verifyPin(key, '123456789'), isFalse);
  });

  group('a damaged stored value counts as a wrong PIN', () {
    final damaged = {
      'bad base64': r'pbkdf2-sha256$1000$!!!$???',
      'non-numeric iterations': r'pbkdf2-sha256$lots$AAAA$AAAA',
      'zero iterations': r'pbkdf2-sha256$0$AAAA$AAAA',
      'wrong prefix': r'md5$1000$AAAA$AAAA',
      'too few parts': r'pbkdf2-sha256$1000$AAAA',
      'empty': '',
    };

    for (final entry in damaged.entries) {
      test(entry.key, () async {
        FlutterSecureStorage.setMockInitialValues({key: entry.value});
        expect(await PinService.verifyPin(key, '123456789'), isFalse);
      });
    }
  });
}
