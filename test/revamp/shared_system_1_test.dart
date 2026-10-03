// Behaviour of shared-system-1's pages (wave 2a): the failed-act alert
// (embedded-product-states; its wrapper widgets were retired by
// kit-hygiene) and the run-command sheet (run-command-dialog). The
// external-link gate's own tests live in test/external_link_test.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/widgets/product_states.dart';
import 'package:opencode_mobile/ui/widgets/run_command_dialog.dart';

import 'shared_system_1_fixtures.dart';

Widget _app(Widget child, {Map<String, WidgetBuilder> routes = const {}}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: routes,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('showProductError is an alert, never a snackbar', (tester) async {
    await tester.pumpWidget(
      _app(
        SystemHost(
          open: (context) =>
              showProductError(context, const ProductException('Disk full')),
        ),
      ),
    );
    await tester.tap(find.text('Open it'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text("Couldn't finish that"), findsOneWidget);
    expect(find.text('Disk full'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Disk full'), findsNothing);
  });

  group('run-command sheet', () {
    Future<(SystemCommandsApi, Completer<String?>)> open(
      WidgetTester tester, {
      String? description,
      List<Session> sessions = const [],
    }) async {
      final api = SystemCommandsApi()..seeded = sessions;
      final controller = await systemController(api);
      addTearDown(controller.dispose);
      final result = Completer<String?>();
      await tester.pumpWidget(
        _app(
          SystemHost(
            open: (context) async => result.complete(
              await showRunCommandDialog(
                context,
                controller: controller,
                command: CommandInfo(
                  name: 'review',
                  description: description,
                  subtask: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open it'));
      await tester.pumpAndSettle();
      return (api, result);
    }

    testWidgets('says what the command does and what the field takes', (
      tester,
    ) async {
      await open(tester, description: 'Review the working tree');
      expect(find.text('Run /review'), findsNWidgets(2)); // title + primary
      expect(find.text('Review the working tree'), findsOneWidget);
      expect(
        find.text(
          'Text passed to /review. Leave it empty if the command takes none.',
        ),
        findsOneWidget,
      );
      expect(find.text('Runs in'), findsOneWidget);
      expect(find.text('New conversation'), findsOneWidget);
    });

    testWidgets('defaults to the most recent conversation and can change it', (
      tester,
    ) async {
      final (api, result) = await open(
        tester,
        sessions: [
          Session(id: 'recent', title: 'Recent chat'),
          Session(id: 'old', title: 'Older chat'),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('command-destination')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New conversation').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('command-arguments')),
        '  staged only  ',
      );
      await tester.tap(find.byKey(const ValueKey('command-submit')));
      await tester.pumpAndSettle();
      expect(api.creates, 1);
      expect(api.calls.single, (
        session: 'new-chat',
        command: 'review',
        args: 'staged only',
      ));
      expect(await result.future, 'new-chat');
    });

    testWidgets('a failed run stays in the sheet with the arguments kept', (
      tester,
    ) async {
      final (api, result) = await open(tester);
      api.failure = const ProductException('The command is not installed.');
      await tester.enterText(
        find.byKey(const ValueKey('command-arguments')),
        'keep me',
      );
      await tester.tap(find.byKey(const ValueKey('command-submit')));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't run /review"), findsOneWidget);
      expect(find.text('The command is not installed.'), findsOneWidget);
      expect(find.text('keep me'), findsOneWidget);
      expect(result.isCompleted, isFalse);

      api.failure = null;
      await tester.tap(find.byKey(const ValueKey('command-submit')));
      await tester.pumpAndSettle();
      // The conversation made by the first try is reused.
      expect(api.creates, 1);
      expect(await result.future, 'new-chat');
    });

    testWidgets('a run in flight cannot be sent twice', (tester) async {
      final (api, result) = await open(tester);
      api.submission = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('command-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('command-submit')));
      await tester.pump();
      expect(api.calls, hasLength(1));
      api.submission!.complete();
      await tester.pumpAndSettle();
      expect(await result.future, 'new-chat');
    });
  });
}
