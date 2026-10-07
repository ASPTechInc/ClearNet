// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    this.confirmMode = false,
    this.onSuccess,
    this.pinKey = Constants.appPinKey,
    this.title = 'Enter PIN',
  });
  final bool confirmMode;
  final VoidCallback? onSuccess;
  final String pinKey;
  final String title;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final storage = const FlutterSecureStorage();
  final _prefs = SharedPreferencesAsync();
  final _pinController = TextEditingController();
  String? _firstEntry;

  Future<void> _handleSubmit() async {
    final enteredPin = _pinController.text;

    if (enteredPin.length < 4 || enteredPin.length > 16) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be between 4 and 16 digits')),
      );
      return;
    }

    if (widget.confirmMode) {
      // Confirm PIN setup
      if (_firstEntry == null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm PIN'),
            content: Text('Is your PIN correct?\n\n$enteredPin'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        setState(() => _firstEntry = enteredPin);
        _pinController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Re-enter PIN to confirm')),
        );
      } else if (_firstEntry == enteredPin) {
        await storage.write(key: widget.pinKey, value: enteredPin);
        await _prefs.setString(widget.pinKey, enteredPin);
        widget.onSuccess?.call();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PINs do not match')));
      }
    } else {
      // Verification
      final savedPin = await storage.read(key: widget.pinKey);
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
      appBar: AppBar(title: Text(widget.title)),
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
