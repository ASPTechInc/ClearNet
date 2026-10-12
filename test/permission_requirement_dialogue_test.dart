// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:clearnet/presentation/widgets/permission_requirement_dialogue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionRequirementDialogue Tests', () {
    testWidgets('displays initial button text and title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionRequirementDialogue(
              title: 'Test Title',
              description: 'Test Description',
              initialButtonText: 'Enable service',
              clickedButtonText: 'Confirm enabling',
              exitButtonText: 'Exit app',
              onActionPressed: () async {},
              onCheckPermission: () async => false,
              onExitPressed: () {},
              notEnabledMessage: 'Not enabled message',
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.text('Enable service'), findsOneWidget);
      expect(find.text('Exit app'), findsOneWidget);
    });

    testWidgets('changes button text to Confirm enabling after tap', (
      WidgetTester tester,
    ) async {
      bool actionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionRequirementDialogue(
              title: 'Action required',
              description: 'Enable Accessibility',
              initialButtonText: 'Enable service',
              clickedButtonText: 'Confirm enabling',
              exitButtonText: 'Exit app',
              onActionPressed: () async {
                actionPressed = true;
              },
              onCheckPermission: () async => false,
              onExitPressed: () {},
              notEnabledMessage: 'Service not enabled yet',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enable service'));
      await tester.pumpAndSettle();

      expect(actionPressed, true);
      expect(find.text('Confirm enabling'), findsOneWidget);
      expect(
        find.textContaining('Once enabled in settings, return to this app '
        'or tap "Confirm enabling"'),
        findsOneWidget,
      );
    });

    testWidgets('shows error message if permission is not granted on confirm', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionRequirementDialogue(
              title: 'Action required',
              description: 'Enable Accessibility',
              initialButtonText: 'Enable service',
              clickedButtonText: 'Confirm enabling',
              exitButtonText: 'Exit app',
              onActionPressed: () async {},
              onCheckPermission: () async => false,
              onExitPressed: () {},
              notEnabledMessage:
                  'Service is not enabled yet. Please enable it in settings.',
            ),
          ),
        ),
      );

      // First tap to switch to "Confirm enabling"
      await tester.tap(find.text('Enable service'));
      await tester.pumpAndSettle();

      // Second tap to check permission
      await tester.tap(find.text('Confirm enabling'));
      await tester.pumpAndSettle();

      expect(
        find.text('Service is not enabled yet. Please enable it in settings.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets(
      'dismisses dialogue returning true when permission is '
      'granted on confirm click',
      (WidgetTester tester) async {
        bool permissionGranted = false;
        bool? dialogueResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogueResult = await showDialog<bool>(
                      context: context,
                      builder: (context) => PermissionRequirementDialogue(
                        title: 'Action required',
                        description: 'Enable Accessibility',
                        initialButtonText: 'Enable service',
                        clickedButtonText: 'Confirm enabling',
                        exitButtonText: 'Exit app',
                        onActionPressed: () async {},
                        onCheckPermission: () async => permissionGranted,
                        onExitPressed: () => Navigator.pop(context, false),
                        notEnabledMessage: 'Service not enabled',
                      ),
                    );
                  },
                  child: const Text('Open Dialogue'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialogue'));
        await tester.pumpAndSettle();

        expect(find.text('Enable service'), findsOneWidget);

        // First tap opens settings / changes button
        await tester.tap(find.text('Enable service'));
        await tester.pumpAndSettle();

        // Grant permission and tap "Confirm enabling"
        permissionGranted = true;
        await tester.tap(find.text('Confirm enabling'));
        await tester.pumpAndSettle();

        expect(dialogueResult, true);
        expect(find.text('Action required'), findsNothing);
      },
    );

    testWidgets(
      'dismisses dialogue returning true via polling timer when permission '
      'is granted',
      (WidgetTester tester) async {
        bool permissionGranted = false;
        bool? dialogueResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogueResult = await showDialog<bool>(
                      context: context,
                      builder: (context) => PermissionRequirementDialogue(
                        title: 'Action required',
                        description: 'Enable Accessibility',
                        initialButtonText: 'Enable service',
                        clickedButtonText: 'Confirm enabling',
                        exitButtonText: 'Exit app',
                        onActionPressed: () async {},
                        onCheckPermission: () async => permissionGranted,
                        onExitPressed: () => Navigator.pop(context, false),
                        notEnabledMessage: 'Service not enabled',
                      ),
                    );
                  },
                  child: const Text('Open Dialogue'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialogue'));
        await tester.pumpAndSettle();

        // First tap starts polling timer
        await tester.tap(find.text('Enable service'));
        await tester.pumpAndSettle();

        // Grant permission and pump time for timer tick
        permissionGranted = true;
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(dialogueResult, true);
        expect(find.text('Action required'), findsNothing);
      },
    );
  });
}
