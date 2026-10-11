// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';

class DisableConfirmationDialogue extends StatefulWidget {
  const DisableConfirmationDialogue({super.key});

  @override
  State<DisableConfirmationDialogue> createState() =>
      _DisableConfirmationDialogueState();
}

class _DisableConfirmationDialogueState
    extends State<DisableConfirmationDialogue> {
  static const List<String> _wordPool = [
    'persistence',
    'extraordinary',
    'conundrum',
    'labyrinth',
    'ephemeral',
    'melancholy',
    'serendipity',
    'quintessential',
    'eloquence',
    'nefarious',
    'obfuscate',
    'pragmatic',
    'resilient',
    'ubiquitous',
    'vivacious',
    'whimsical',
    'zealous',
    'aberration',
    'benevolent',
    'capricious',
    'deference',
    'enervate',
    'garrulous',
    'haughty',
    'impetuous',
  ];

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
    for (int i = 0; i < 3; i++) {
      final length = 12 + _random.nextInt(4);
      final sentenceWords = <String>[];
      for (int j = 0; j < length; j++) {
        sentenceWords.add(_wordPool[_random.nextInt(_wordPool.length)]);
      }
      _sentences.add(sentenceWords.join(' '));
    }
  }

  void _handleNext() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type the sentence before continuing.'),
          duration: Duration(seconds: 2),
        ),
      );
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
                'Disable Protection Confirmation',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Type the following sentence exactly as shown below '
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
                child: SelectableText(
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
