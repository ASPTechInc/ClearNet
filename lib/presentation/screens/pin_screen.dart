// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';
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
  final _pinController = TextEditingController();
  String? _firstEntry;
  bool _isWorking = false;

  static const _lengthHint =
      '${PinService.minLength} to ${PinService.maxLength} digits';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSubmit() async {
    if (_isWorking) return;
    final enteredPin = _pinController.text;

    if (!PinService.isValidPin(enteredPin)) {
      _showMessage(
        widget.confirmMode ? 'PIN must be $_lengthHint' : 'Incorrect PIN',
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
        setState(() => _isWorking = true);
        await PinService.savePin(widget.pinKey, enteredPin);
        if (mounted) setState(() => _isWorking = false);
        widget.onSuccess?.call();
      } else {
        _showMessage('PINs do not match');
      }
    } else {
      // Verification
      setState(() => _isWorking = true);
      final isCorrect = await PinService.verifyPin(widget.pinKey, enteredPin);
      if (mounted) setState(() => _isWorking = false);
      if (isCorrect) {
        widget.onSuccess?.call();
      } else {
        _showMessage('Incorrect PIN');
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
              maxLength: PinService.maxLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'PIN',
                helperText: widget.confirmMode ? _lengthHint : null,
                // Hide the character counter so it doesn't show the PIN length
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isWorking ? null : _handleSubmit,
              child: _isWorking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
