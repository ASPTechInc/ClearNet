// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

/// Removes a forgotten app PIN after a waiting period. Used when no uninstall
/// PIN is set; otherwise the uninstall PIN resets the app PIN straight away.
///
/// The wait means a forgotten PIN can be recovered, but not on impulse to get
/// past the lock. Entering the right app PIN cancels the request.
class AppPinResetService {
  static const Duration waitPeriod = Duration(hours: 24);

  /// Replace in tests to move the clock forward.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static const _storage = FlutterSecureStorage();

  /// When the reset was requested or null if there's no request.
  static Future<DateTime?> requestedAt() async {
    final value = await _storage.read(key: Constants.appPinResetRequestedKey);
    final millis = value == null ? null : int.tryParse(value);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// When the app PIN will be removed or null if there's no request.
  static Future<DateTime?> resetsAt() async =>
      (await requestedAt())?.add(waitPeriod);

  /// Starts the wait, unless one is already running.
  static Future<void> request() async {
    if (await requestedAt() != null) return;
    await _storage.write(
      key: Constants.appPinResetRequestedKey,
      value: '${now().millisecondsSinceEpoch}',
    );
  }

  static Future<void> cancel() =>
      _storage.delete(key: Constants.appPinResetRequestedKey);

  /// Removes the app PIN if the wait is over, turning off app lock and the
  /// settings lock, which both rely on it. Returns true if it did.
  static Future<bool> completeIfDue() async {
    final due = await resetsAt();
    if (due == null || now().isBefore(due)) return false;
    await _storage.delete(key: Constants.appPinKey);
    await _storage.write(key: Constants.appLockEnabledKey, value: 'false');
    await SharedPreferencesAsync().setBool(Constants.lockSettingsKey, false);
    await cancel();
    return true;
  }
}
