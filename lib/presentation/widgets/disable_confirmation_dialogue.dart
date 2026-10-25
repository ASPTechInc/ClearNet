// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:clearnet/shared/utilities/constants.dart';

/// The challenge shown before blocking can be turned off: three long
/// sentences of hard words that must be typed exactly. Any mistake starts it
/// again with new sentences. Closes with true if passed, false if given up.
class DisableConfirmationDialogue extends StatefulWidget {
  const DisableConfirmationDialogue({super.key});

  @override
  State<DisableConfirmationDialogue> createState() =>
      _DisableConfirmationDialogueState();
}

class _DisableConfirmationDialogueState
    extends State<DisableConfirmationDialogue> {
  final Random _random = Random();
  final List<String> _sentences = [];
  final List<String> _userInputs = [];
  final TextEditingController _inputController = TextEditingController();

  int _currentStep = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateSentences();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _generateSentences() {
    _sentences.clear();
    _userInputs.clear();
    _currentStep = 0;
    // Each sentence takes the next words from one shuffle, so no word is
    // shown twice. The pool needs at least 45 words (3 sentences of up to 15).
    final words = List.of(Constants.wordPool)..shuffle(_random);
    var next = 0;
    for (int i = 0; i < 3; i++) {
      final length = 12 + _random.nextInt(4);
      _sentences.add(words.sublist(next, next + length).join(' '));
      next += length;
    }
  }

  void _handleNext() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      // Shown in the dialogue, as a SnackBar would appear behind it
      setState(() => _errorMessage = 'Type the words before continuing.');
      return;
    }

    _userInputs.add(input);

    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _inputController.clear();
        _errorMessage = null;
      });
    } else {
      _validateAll();
    }
  }

  void _validateAll() {
    bool allCorrect = true;
    for (int i = 0; i < 3; i++) {
      if (i >= _userInputs.length || _userInputs[i] != _sentences[i]) {
        allCorrect = false;
        break;
      }
    }

    if (allCorrect) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage =
            'One or more sentences were incorrect! Starting over with '
            'new sentences.';
        _generateSentences();
        _inputController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step ${_currentStep + 1} of 3',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'I give up',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Turn off blocking',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Type the following words exactly as shown below '
                'to proceed:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Error banner if previously failed
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Target Sentence Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                // Plain text, so the sentence cannot be copied and pasted
                child: Text(
                  _sentences[_currentStep],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Input TextField
              TextField(
                controller: _inputController,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                // No pasting and no autocorrect changing the typed words
                enableInteractiveSelection: false,
                autocorrect: false,
                enableSuggestions: false,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Type here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    child: const Text('I give up'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _handleNext,
                    child: Text(_currentStep == 2 ? 'Submit' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
