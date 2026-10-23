// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/shared/utilities/helpers.dart';

void main() {
  group('isNewerVersion', () {
    test('a higher release is newer', () {
      expect(isNewerVersion('v1.1.0', '1.0.0+1'), isTrue);
      expect(isNewerVersion('v2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
    });

    test('the same release is not newer, whatever the build number', () {
      expect(isNewerVersion('v1.0.0', '1.0.0+7'), isFalse);
      expect(isNewerVersion('V1.0.0', '1.0.0'), isFalse);
    });

    test('an older release is not newer than a local build', () {
      expect(isNewerVersion('v1.0.0', '1.1.0+1'), isFalse);
      expect(isNewerVersion('v1.9.9', '2.0.0'), isFalse);
    });

    test('missing parts count as zero', () {
      expect(isNewerVersion('v1.1', '1.0.5'), isTrue);
      expect(isNewerVersion('v1.0', '1.0.0'), isFalse);
    });

    test('pre-release tags are ignored', () {
      expect(isNewerVersion('v1.1.0-beta', '1.0.0'), isTrue);
      expect(isNewerVersion('v1.0.0-rc1', '1.0.0'), isFalse);
    });
  });
}
