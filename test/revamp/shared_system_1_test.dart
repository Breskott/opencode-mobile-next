// Behaviour of shared-system-1's pages (wave 2a): the shared product states
// as kit wrappers (embedded-product-states), the run-command sheet
// (run-command-dialog). The external-link gate's own tests live in
// test/external_link_test.dart.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_notice.dart' show KitErrorKind;
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
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
  group('ProductErrorState is a KitStateView', () {
    testWidgets('an unexpected error: a title, the cause, Try again and '
        'Report a problem', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _app(
          ProductErrorState(
            message: 'The file list is not available.',
            onRetry: () async => retried++,
          ),
        ),
      );
      expect(find.byType(KitStateView), findsOneWidget);
      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('The file list is not available.'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text('Switch server'), findsNothing);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('a network error offers Switch server, not Report', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ProductErrorState(
            message: 'OpenCode is unreachable. Try again.',
            error: const SocketException('refused'),
            onRetry: () async {},
          ),
          routes: {'/servers': (_) => const Text('Server list')},
        ),
      );
      expect(find.text("Can't reach the server"), findsOneWidget);
      expect(find.text('Report a problem'), findsNothing);
      await tester.tap(find.text('Switch server'));
      await tester.pumpAndSettle();
      expect(find.text('Server list'), findsOneWidget);
    });

    testWidgets('a caller title and errorKind win; raw details fold away', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ProductErrorState(
            title: "Couldn't load files",
            message: 'The server did not answer.',
            errorKind: KitErrorKind.network,
            details: 'GET /file 504 after 30 s',
            onSwitchServer: () {},
            onRetry: () async {},
          ),
        ),
      );
      expect(find.text("Couldn't load files"), findsOneWidget);
      expect(find.text('Switch server'), findsOneWidget);
      expect(find.text('Copy details'), findsOneWidget);
      // Raw text is folded, never above the actions.
      expect(find.text('GET /file 504 after 30 s'), findsNothing);
    });
  });

  testWidgets('ProductEmptyState and ProductInlineEmpty are KitStateViews '
      'with the one action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const Expanded(
              child: ProductEmptyState(
                icon: Icons.inbox_outlined,
                title: 'No skills yet',
                message: 'Skills the server knows appear here.',
              ),
            ),
            ProductInlineEmpty(
              icon: Icons.inbox_outlined,
              title: 'No references',
              message: 'Add one from a conversation.',
              actionLabel: 'Add reference',
              onAction: () => tapped++,
            ),
          ],
        ),
      ),
    );
    expect(find.byType(KitStateView), findsNWidgets(2));
    expect(find.text('No skills yet'), findsOneWidget);
    await tester.tap(find.text('Add reference'));
    expect(tapped, 1);
  });

  testWidgets('a refresh failure is a notice over the kept content', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      _app(
        ProductRefreshBody(
          message: 'The server did not answer.',
          onRetry: () => retried++,
          child: const Text('Kept content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kept content'), findsOneWidget);
    expect(find.text('Couldn’t refresh'), findsOneWidget);
    expect(find.text('The server did not answer.'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

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

  testWidgets('GatedRow is an unavailable KitRow with its reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ListView(
          children: const [
            SectionLabel('Server'),
            GatedRow(
              feature: 'shell',
              title: 'Default shell',
              explainer: gatedOnV2Explainer,
            ),
          ],
        ),
      ),
    );
    final row = tester.widget<KitRow>(
      find.byKey(const ValueKey('gated-shell')),
    );
    expect(row.enabled, isFalse);
    expect(find.text('Default shell'), findsOneWidget);
    expect(find.text('Not available on OpenCode 2 servers'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
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
