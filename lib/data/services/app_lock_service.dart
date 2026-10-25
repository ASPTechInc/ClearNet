// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// Decides how long ClearNet waits before closing itself after the user
/// leaves it, so the app PIN is asked for again.
class AppLockService {
  /// Delay options shown in Settings, in seconds.
  static const Map<int, String> timeoutOptions = {
    0: 'Immediately',
    60: '1 minute',
    300: '5 minutes',
  };
  static const int defaultTimeoutSeconds = 0;

  /// Extra time allowed when ClearNet itself opened another screen, such as
  /// system settings or the file picker, so those steps can be finished.
  static const Duration externalActivityGrace = Duration(minutes: 5);

  /// How soon after [expectExternalActivity] the app has to leave the
  /// foreground for it to count.
  static const Duration _expectWindow = Duration(seconds: 3);

  static const _storage = FlutterSecureStorage();
  static DateTime? _expectedAt;

  /// Call just before opening a screen outside ClearNet that the user will
  /// come back from.
  static void expectExternalActivity() => _expectedAt = DateTime.now();

  @visibleForTesting
  static void resetExpectation() => _expectedAt = null;

  static bool _takeExpectation() {
    final expectedAt = _expectedAt;
    _expectedAt = null;
    return expectedAt != null &&
        DateTime.now().difference(expectedAt) < _expectWindow;
  }

  static Future<bool> isLockEnabled() async {
    final enabled = await _storage.read(key: Constants.appLockEnabledKey);
    return enabled == 'true' && await PinService.hasPin(Constants.appPinKey);
  }

  static Future<int> getTimeoutSeconds() async {
    final seconds = await SharedPreferencesAsync().getInt(
      Constants.appLockTimeoutKey,
    );
    return timeoutOptions.containsKey(seconds)
        ? seconds!
        : defaultTimeoutSeconds;
  }

  static Future<void> setTimeoutSeconds(int seconds) =>
      SharedPreferencesAsync().setInt(Constants.appLockTimeoutKey, seconds);

  /// How long to wait before closing after the user leaves ClearNet or null
  /// if app lock is off.
  static Future<Duration?> delayAfterLeaving() async {
    // Read this first, before the awaits below can let the window pass
    final openedByApp = _takeExpectation();
    if (!await isLockEnabled()) return null;
    final delay = Duration(seconds: await getTimeoutSeconds());
    if (openedByApp && delay < externalActivityGrace) {
      return externalActivityGrace;
    }
    return delay;
  }
}
