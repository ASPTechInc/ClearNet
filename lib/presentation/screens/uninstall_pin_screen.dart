// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/controllers/uninstall_protection_controller.dart';
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/presentation/screens/pin_pad_screen.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// Shown when someone tries to remove ClearNet's protection, such as its device
/// admin access. Asks for the uninstall PIN, or closes straight away if none
/// has been set. A correct PIN allows the protected system screens for a short
/// time, then closing returns the user to where they were.
class UninstallPinScreen extends StatefulWidget {
  const UninstallPinScreen({super.key});

  @override
  State<UninstallPinScreen> createState() => _UninstallPinScreenState();
}

class _UninstallPinScreenState extends State<UninstallPinScreen> {
  static const platform = MethodChannel(Constants.methodChannelName);
  bool? _hasPin;

  @override
  void initState() {
    super.initState();
    unawaited(_checkPin());
  }

  Future<void> _checkPin() async {
    final hasPin = await PinService.hasPin(Constants.uninstallPinKey);
    if (!mounted) return;
    if (!hasPin) {
      await _close();
      return;
    }
    setState(() => _hasPin = true);
  }

  Future<void> _close() => platform.invokeMethod('closeApp');

  Future<void> _allowAndClose() async {
    await UninstallProtectionController.allowProtectedScreens();
    await _close();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPin != true) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Back is blocked, so this screen can only be left with the PIN or Home
    return PopScope(
      canPop: false,
      child: PinPadScreen(
        pinKey: Constants.uninstallPinKey,
        title: 'Enter Uninstall PIN',
        onSuccess: () => unawaited(_allowAndClose()),
      ),
    );
  }
}
