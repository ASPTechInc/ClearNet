// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Project imports:
import 'package:clearnet/data/services/app_lock_service.dart';
import 'package:clearnet/presentation/screens/pin_pad_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';
import 'package:clearnet/shared/utilities/helpers.dart';

/// Shows [child] (the main app) straight away if no app PIN is enabled.
/// Otherwise asks for the app PIN first.
///
/// While app lock is on, ClearNet closes itself once the user has been away
/// for the delay chosen in Settings, so the PIN is asked for again.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  static const platform = MethodChannel(Constants.methodChannelName);
  final storage = const FlutterSecureStorage();

  bool _isLoading = true;
  bool _isLocked = false;

  Timer? _closeTimer;
  DateTime? _leftAt;
  Duration? _lockDelay;
  // Increases each time the app comes back, so a slow check started when the
  // user left can tell the user has already returned
  int _visit = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkLockMode());
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_onLeftApp());
    } else if (state == AppLifecycleState.resumed) {
      _onReturned();
    }
  }

  Future<void> _onLeftApp() async {
    final visit = _visit;
    final leftAt = DateTime.now();
    final delay = await AppLockService.delayAfterLeaving();
    if (delay == null || visit != _visit) return;

    _leftAt = leftAt;
    _lockDelay = delay;
    _closeTimer?.cancel();
    if (delay == Duration.zero) {
      await _closeApp();
    } else {
      _closeTimer = Timer(delay, () => unawaited(_closeApp()));
    }
  }

  void _onReturned() {
    _visit++;
    _closeTimer?.cancel();
    final leftAt = _leftAt;
    final delay = _lockDelay;
    _leftAt = null;
    _lockDelay = null;

    // Android can pause timers while an app is in the background. If the
    // delay passed without the app closing, lock it now instead.
    if (leftAt != null &&
        delay != null &&
        DateTime.now().difference(leftAt) >= delay &&
        !_isLocked) {
      AppSession.isSettingsUnlocked = false;
      setState(() => _isLocked = true);
    }
  }

  Future<void> _closeApp() async {
    AppSession.isSettingsUnlocked = false;
    try {
      await platform.invokeMethod('closeApp');
    } on MissingPluginException {
      // Only happens in tests, where there's no Android side
    }
  }

  Future<void> _checkLockMode() async {
    final appLock = await storage.read(key: Constants.appLockEnabledKey);
    final appPin = await storage.read(key: Constants.appPinKey);

    final bool hasAppPin = appPin != null && appPin.isNotEmpty;
    final bool isAppLockEnabled = appLock == 'true';

    if (!mounted) return;
    setState(() {
      _isLocked = hasAppPin && isAppLockEnabled;
      _isLoading = false;
    });
  }

  void _unlock() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      return PinPadScreen(
        pinKey: Constants.appPinKey,
        title: 'Enter PIN',
        onSuccess: _unlock,
      );
    }

    return widget.child;
  }
}
