// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/services/pin_service.dart';
import 'package:clearnet/shared/utilities/constants.dart';

/// A lock screen with an on-screen number pad, like a phone's, for entering
/// the PIN saved under [pinKey]. Calls [onSuccess] once the PIN is correct.
///
/// C clears everything, the backspace key removes the last digit and the
/// tick checks the PIN. PINs vary in length, so it isn't checked
/// automatically when enough digits are entered.
class PinPadScreen extends StatefulWidget {
  const PinPadScreen({
    super.key,
    required this.onSuccess,
    this.pinKey = Constants.appPinKey,
    this.title = 'Enter PIN',
    this.showBackButton = false,
  });

  final VoidCallback onSuccess;
  final String pinKey;
  final String title;

  /// Shows a back button, for when the pad was opened on top of another
  /// screen the user can return to.
  final bool showBackButton;

  @override
  State<PinPadScreen> createState() => _PinPadScreenState();
}

class _PinPadScreenState extends State<PinPadScreen> {
  String _entered = '';
  String? _error;
  bool _isChecking = false;

  bool get _canSubmit =>
      !_isChecking && _entered.length >= PinService.minLength;

  void _addDigit(String digit) {
    if (_isChecking || _entered.length >= PinService.maxLength) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _entered += digit;
      _error = null;
    });
  }

  void _backspace() {
    if (_isChecking || _entered.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  // ignore: unused_element
  void _clear() {
    if (_isChecking || _entered.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _entered = '');
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isChecking = true);
    final isCorrect = await PinService.verifyPin(widget.pinKey, _entered);
    if (!mounted) return;
    if (isCorrect) {
      setState(() => _isChecking = false);
      widget.onSuccess();
      return;
    }
    unawaited(HapticFeedback.vibrate());
    setState(() {
      _isChecking = false;
      _entered = '';
      _error = 'Incorrect PIN';
    });
  }

  Widget _key({
    required Key key,
    required Widget child,
    required VoidCallback? onPressed,
    String? semanticsLabel,
    bool filled = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Semantics(
          label: semanticsLabel,
          button: true,
          excludeSemantics: semanticsLabel != null,
          child: FilledButton.tonal(
            key: key,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: filled ? scheme.primary : null,
              foregroundColor: filled ? scheme.onPrimary : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _digitKey(String digit) => _key(
    key: Key('pin_key_$digit'),
    onPressed: _isChecking ? null : () => _addDigit(digit),
    child: Text(digit, style: const TextStyle(fontSize: 28)),
  );

  Widget _dots() {
    final scheme = Theme.of(context).colorScheme;
    if (_entered.isEmpty) {
      return Text(
        'Enter ${PinService.minLength} to ${PinService.maxLength} digits',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(
        _entered.length,
        (_) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.showBackButton
          ? AppBar(backgroundColor: Colors.transparent)
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Balances the backspace button so the dots stay
                      // centred
                      const SizedBox(width: 48),
                      Flexible(child: Center(child: _dots())),
                      const SizedBox(width: 45),
                    ],
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: _error == null
                      ? null
                      : Text(_error!, style: TextStyle(color: scheme.error)),
                ),
                const SizedBox(height: 16),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final d in row) _digitKey(d)],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _key(
                      key: const Key('pin_key_backspace'),
                      semanticsLabel: 'Delete',
                      onPressed: _entered.isEmpty || _isChecking
                          ? null
                          : _backspace,
                      child: const Icon(Icons.backspace_outlined, size: 32),
                    ),
                    _digitKey('0'),
                    _key(
                      key: const Key('pin_key_enter'),
                      semanticsLabel: 'Unlock',
                      filled: true,
                      onPressed: _canSubmit ? _submit : null,
                      child: _isChecking
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check, size: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
