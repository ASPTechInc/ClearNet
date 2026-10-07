// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Project imports:
import 'package:clearnet/presentation/navigation/app_routes.dart';
import 'package:clearnet/presentation/screens/pin_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final storage = const FlutterSecureStorage();

  bool _appLockEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_checkLockMode());
  }

  Future<void> _checkLockMode() async {
    final appLock = await storage.read(key: Constants.appLockEnabledKey);
    final appPin = await storage.read(key: Constants.appPinKey);

    final bool hasAppPin = appPin != null && appPin.isNotEmpty;
    final bool isAppLockEnabled = appLock == 'true';

    if (!hasAppPin || !isAppLockEnabled) {
      _goToApp();
      return;
    }

    setState(() {
      _appLockEnabled = true;
      _isLoading = false;
    });
  }

  void _goToApp() {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_appLockEnabled) {
      return PinLockScreen(
        pinKey: Constants.appPinKey,
        title: 'Enter App PIN',
        onSuccess: _goToApp,
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
