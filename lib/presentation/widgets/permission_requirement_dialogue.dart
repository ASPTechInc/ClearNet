// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

/// Asks the user to turn on a permission in Android's settings, then closes by
/// itself once it's been granted.
class PermissionRequirementDialogue extends StatefulWidget {
  const PermissionRequirementDialogue({
    super.key,
    required this.title,
    required this.description,
    required this.initialButtonText,
    required this.clickedButtonText,
    required this.exitButtonText,
    required this.onActionPressed,
    required this.onCheckPermission,
    required this.onExitPressed,
    required this.notEnabledMessage,
    this.primaryActionTextChangeDelay = Duration.zero,
  });

  final String title;
  final String description;
  final String initialButtonText;
  final String clickedButtonText;
  final String exitButtonText;
  final Future<void> Function() onActionPressed;
  final Future<bool> Function() onCheckPermission;
  final VoidCallback onExitPressed;
  final String notEnabledMessage;
  final Duration primaryActionTextChangeDelay;

  @override
  State<PermissionRequirementDialogue> createState() =>
      _PermissionRequirementDialogueState();
}

class _PermissionRequirementDialogueState
    extends State<PermissionRequirementDialogue>
    with WidgetsBindingObserver {
  bool _hasClickedAction = false;
  bool _hasTriggeredAction = false;
  bool _isWaitingForTextChange = false;
  bool _isChecking = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  DateTime? _pollingStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _stopPollingTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionInternal(autoCloseOnSuccess: true);
    }
  }

  // Android doesn't notify the app when the user changes these settings, so
  // check regularly instead, and stop after 3 minutes
  void _startPollingTimer() {
    _stopPollingTimer();
    _pollingStartTime = DateTime.now();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 1, milliseconds: 500),
      (timer) async {
        if (_pollingStartTime != null &&
            DateTime.now().difference(_pollingStartTime!).inMinutes >= 3) {
          _stopPollingTimer();
          return;
        }
        await _checkPermissionInternal(autoCloseOnSuccess: true);
      },
    );
  }

  void _stopPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkPermissionInternal({
    required bool autoCloseOnSuccess,
    bool showUserFeedbackOnFailure = false,
  }) async {
    if (_isChecking || !mounted) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final isGranted = await widget.onCheckPermission();
      if (!mounted) return;

      if (isGranted) {
        _stopPollingTimer();
        Navigator.of(context).pop(true);
        return;
      }

      if (showUserFeedbackOnFailure) {
        setState(() {
          _errorMessage = widget.notEnabledMessage;
          _isChecking = false;
        });
      } else {
        setState(() {
          _isChecking = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_isChecking || _isWaitingForTextChange) return;

    if (!_hasTriggeredAction) {
      setState(() {
        _hasTriggeredAction = true;
        _isWaitingForTextChange = true;
        _errorMessage = null;
      });
      await widget.onActionPressed();
      _startPollingTimer();
      if (widget.primaryActionTextChangeDelay > Duration.zero) {
        await Future<void>.delayed(widget.primaryActionTextChangeDelay);
      }
      if (!mounted) return;
      setState(() {
        _hasClickedAction = true;
        _isWaitingForTextChange = false;
      });
    } else {
      await _checkPermissionInternal(
        autoCloseOnSuccess: true,
        showUserFeedbackOnFailure: true,
      );
    }
  }

  Future<void> _handleReopenSettings() async {
    setState(() {
      _errorMessage = null;
    });
    await widget.onActionPressed();
    _startPollingTimer();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            if (_hasClickedAction) ...[
              const SizedBox(height: 12),
              Text(
                'Once enabled in settings, return to this app or '
                'tap "${widget.clickedButtonText}" ',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.onExitPressed,
            child: Text(widget.exitButtonText),
          ),
          if (_hasClickedAction && _errorMessage != null)
            TextButton(
              onPressed: _handleReopenSettings,
              child: const Text('Open Settings'),
            ),
          ElevatedButton(
            onPressed: _isChecking || _isWaitingForTextChange
                ? null
                : _handlePrimaryAction,
            child: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _hasClickedAction
                        ? widget.clickedButtonText
                        : widget.initialButtonText,
                  ),
          ),
        ],
      ),
    );
  }
}
