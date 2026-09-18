// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    this.confirmMode = false,
    this.onSuccess,
  });
  final bool confirmMode;
  final VoidCallback? onSuccess;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final storage = const FlutterSecureStorage();
  final _pinController = TextEditingController();
  String? _firstEntry;

  Future<void> _handleSubmit() async {
    final enteredPin = _pinController.text;

    if (widget.confirmMode) {
      // Confirm PIN setup
      if (_firstEntry == null) {
        setState(() => _firstEntry = enteredPin);
        _pinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Re-enter PIN to confirm')),
        );
      } else if (_firstEntry == enteredPin) {
        await storage.write(key: 'uninstall_pin', value: enteredPin);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uninstall_pin', enteredPin);
        widget.onSuccess?.call();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PINs do not match')));
      }
    } else {
      // Verification
      final savedPin = await storage.read(key: 'uninstall_pin');
      if (savedPin == enteredPin) {
        widget.onSuccess?.call();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleSubmit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
