// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

void main() {
  const presets = Constants.dnsPresets;

  test('starts with the default servers and ends with a custom option', () {
    expect(presets.first.id, 'default');
    expect(presets.first.ip, isEmpty);
    expect(presets.first.label, contains('UncensoredDNS'));
    expect(presets.last.id, 'custom');
  });

  test('every other option has a valid IP address that matches its id', () {
    for (final preset in presets.sublist(1, presets.length - 1)) {
      expect(InternetAddress.tryParse(preset.ip), isNotNull, reason: preset.ip);
      expect(preset.id, preset.ip);
      expect(preset.label, contains(preset.ip));
    }
  });

  test('ids are unique', () {
    final ids = presets.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('does not offer Mullvad, which only answers encrypted DNS', () {
    for (final preset in presets) {
      expect(preset.label.toLowerCase(), isNot(contains('mullvad')));
      expect(preset.ip, isNot(startsWith('194.242.2.')));
    }
  });
}
