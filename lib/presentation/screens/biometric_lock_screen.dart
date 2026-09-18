// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

// Project imports:
import 'package:clearnet/presentation/screens/pin_screen.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final storage = const FlutterSecureStorage();

  bool _authFailed = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkLockMode();
  }

  Future<void> _checkLockMode() async {
    final biometrics = await storage.read(key: 'biometrics_enabled');
    final pin = await storage.read(key: 'uninstall_pin');

    final bool hasPin = pin != null && pin.isNotEmpty;
    final bool hasBiometrics = biometrics == 'true';

    if (!hasPin && !hasBiometrics) {
      _goToApp();
      return;
    }

    setState(() {
      _biometricsEnabled = hasBiometrics;
    });

    if (_biometricsEnabled) {
      _authenticate();
    } else {
      // If biometrics disabled but PIN is set, go straight to PIN
      setState(() => _authFailed = true);
    }
  }

  Future<void> _authenticate() async {
    try {
      final available = await auth.canCheckBiometrics;
      if (available) {
        final didAuth = await auth.authenticate(
          localizedReason: 'Authenticate to access ClearNet',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
        if (didAuth) {
          _goToApp();
          return;
        }
      }
      setState(() => _authFailed = true); // fallback to PIN
    } catch (e) {
      setState(() => _authFailed = true); // fallback to PIN
    }
  }

  void _goToApp() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    if (!_authFailed && _biometricsEnabled) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // fallback to PIN (or direct PIN if biometrics disabled)
    return PinLockScreen(onSuccess: _goToApp);
  }
}
