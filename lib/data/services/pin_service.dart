// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores PINs as salted PBKDF2-HMAC-SHA256 hashes in secure storage, so the
/// PIN itself is never saved.
///
/// Each stored value has the form `pbkdf2-sha256$<iterations>$<salt>$<hash>`,
/// with the salt and hash in base64. Keeping the iteration count in the value
/// means it can be raised later without breaking existing PINs.
class PinService {
  static const int minLength = 8;
  static const int maxLength = 16;

  /// Lower this in tests only; hashing at full strength is slow in tests.
  @visibleForTesting
  static int iterations = 210000;

  static const int _saltLength = 16;
  static const String _prefix = 'pbkdf2-sha256';

  static const _storage = FlutterSecureStorage();

  /// Whether [pin] has the right length and only digits.
  static bool isValidPin(String pin) =>
      pin.length >= minLength &&
      pin.length <= maxLength &&
      RegExp(r'^\d+$').hasMatch(pin);

  static Future<bool> hasPin(String key) async {
    final stored = await _storage.read(key: key);
    return stored != null && stored.isNotEmpty;
  }

  /// Hashes [pin] with a new random salt and saves it under [key].
  static Future<void> savePin(String key, String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final hash = await _hash(pin, salt, iterations);
    final value = [
      _prefix,
      '$iterations',
      base64.encode(salt),
      base64.encode(hash),
    ].join(r'$');
    await _storage.write(key: key, value: value);
  }

  /// Checks [pin] against the PIN saved under [key].
  static Future<bool> verifyPin(String key, String pin) async {
    final stored = await _storage.read(key: key);
    if (stored == null) return false;

    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _prefix) return false;

    final storedIterations = int.tryParse(parts[1]);
    if (storedIterations == null || storedIterations < 1) return false;
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      // A damaged stored value counts as a wrong PIN rather than crashing
      return false;
    }
    final actual = await _hash(pin, salt, storedIterations);
    return _constantTimeEquals(actual, expected);
  }

  /// Runs PBKDF2 in a background isolate so the UI does not freeze.
  static Future<Uint8List> _hash(String pin, List<int> salt, int iterations) {
    final password = utf8.encode(pin);
    return Isolate.run(() => pbkdf2(password, salt, iterations));
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) producing one 32-byte block.
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  /// Compares without returning early, so timing does not reveal how much of
  /// the value matched.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
