// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';

/// Asks for a new PIN twice (PIN and Confirm PIN) and saves it under
/// [pinKey]. Closes with true once saved, or null if cancelled.
///
/// With [requireCurrentPin], it also asks for the PIN already saved under
/// [pinKey] and only saves the new one if that is correct.
class SetPinDialogue extends StatefulWidget {
  const SetPinDialogue({
    super.key,
    required this.pinKey,
    required this.title,
    this.requireCurrentPin = false,
  });

  final String pinKey;
  final String title;
  final bool requireCurrentPin;

  @override
  State<SetPinDialogue> createState() => _SetPinDialogueState();
}

class _SetPinDialogueState extends State<SetPinDialogue> {
  final _currentController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _currentError;
  String? _pinError;
  String? _confirmError;
  bool _isSaving = false;

  static const _lengthHint =
      '${PinService.minLength} to ${PinService.maxLength} digits';

  @override
  void dispose() {
    _currentController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final pin = _pinController.text;
    final confirm = _confirmController.text;

    setState(() {
      _pinError = !PinService.isValidPin(pin)
          ? 'PIN must be $_lengthHint'
          : widget.requireCurrentPin && pin == _currentController.text
          ? 'New PIN must be different from\nthe current PIN'
          : null;
      _confirmError = _pinError == null && pin != confirm
          ? 'PINs do not match'
          : null;
    });
    if (_pinError != null || _confirmError != null) return;

    setState(() {
      _isSaving = true;
      _currentError = null;
    });
    if (widget.requireCurrentPin &&
        !await PinService.verifyPin(widget.pinKey, _currentController.text)) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _currentError = 'Incorrect PIN';
      });
      return;
    }
    await PinService.savePin(widget.pinKey, pin);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _pinField({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? helperText,
    String? errorText,
    TextInputAction action = TextInputAction.next,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: PinService.maxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: action,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        // Hide the character counter so it doesn't show the PIN length
        counterText: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.requireCurrentPin) ...[
              _pinField(
                key: const Key('current_pin_field'),
                controller: _currentController,
                label: 'Current PIN',
                errorText: _currentError,
              ),
              const SizedBox(height: 8),
            ],
            _pinField(
              key: const Key('set_pin_field'),
              controller: _pinController,
              label: widget.requireCurrentPin ? 'New PIN' : 'PIN',
              helperText: _lengthHint,
              errorText: _pinError,
            ),
            const SizedBox(height: 8),
            _pinField(
              key: const Key('confirm_pin_field'),
              controller: _confirmController,
              label: widget.requireCurrentPin
                  ? 'Confirm New PIN'
                  : 'Confirm PIN',
              errorText: _confirmError,
              action: TextInputAction.done,
              onSubmitted: _save,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
