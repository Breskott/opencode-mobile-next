// Behaviour of screen-library-3's pages (wave 2b): server sign-in, manage
// accounts (with its remove confirm and rename dialog), the unfinished
// sign-in cards, the Tools page and its detail sheet, and the Plugins page.
// Each test asserts what the person sees or what the app asks the server
// to do; none prints a credential.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/pending_auth.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/screens/tools_screen.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';

import 'screen_library_3_fixtures.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // Reduced motion: a working row's mark holds still, so pumpAndSettle
  // settles while a sheet waits on the person.
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Future<void> _providers(WidgetTester tester, Library3Controller c) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(IntegrationsScreen(controller: c, mode: IntegrationsMode.providers)),
  );
  await tester.pumpAndSettle();
}

Future<void> _manageAccounts(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('provider-anthropic')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manage Anthropic accounts'));
  await tester.pumpAndSettle();
}

Future<void> _accountMenu(WidgetTester tester, String id, String item) async {
  await tester.tap(find.byKey(ValueKey('credential-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  mockLibrary3SecureStorage();
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);

  group('server sign-in', () {
    // The separate "Start sign-in on the server?" confirm merged into the
    // sheet (slice-P3.11a): the sheet's intro says what Start does and
    // whom it trusts, and Start acts.
    testWidgets('the sheet is the question: Start starts, Cancel is at hand, '
        'and after 8 s it offers to check the named provider', (tester) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await _providers(tester, c);
      await tester.tap(find.byKey(const ValueKey('connect-provider-cloud')));
      await tester.pumpAndSettle();
      expect(find.text('Cloud CLI'), findsOneWidget);
      expect(
        find.textContaining('Start it only if you trust the server'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('command-auth-start')));
      await tester.pumpAndSettle();
      expect(find.text('Start sign-in on the server?'), findsNothing);
      expect(c.started, ['cloud/login']);
      expect(find.textContaining('Sign-in is pending on the server'), findsOne);
      expect(find.byKey(const ValueKey('command-auth-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('command-auth-start')), findsNothing);
      // The server gets time to answer before the sheet offers the check.
      expect(find.byKey(const ValueKey('command-auth-check')), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('command-auth-check')), findsOneWidget);
      expect(find.text('Check Cloud sign-in now'), findsOneWidget);
    });
  });

  group('manage accounts', () {
    testWidgets('one caption, one row per account, no mark while the active '
        'one is unknown, and the server environment row', (tester) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await _providers(tester, c);
      await _manageAccounts(tester);

      expect(find.byKey(const ValueKey('credential-cred-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('credential-cred-2')), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      // One caption; the unknown active account is no paragraph of its own.
      expect(find.text('Keys stay on your server.'), findsOneWidget);
      expect(find.textContaining('Active account unknown'), findsNothing);
      expect(find.text('ANTHROPIC_API_KEY'), findsOneWidget);
      expect(
        find.text(
          'Managed by the server environment. It cannot be removed '
          'here.',
        ),
        findsOneWidget,
      );
      // The old standalone refresh button is gone: the list loads on open
      // and after every change.
      expect(find.text('Refresh accounts'), findsNothing);
    });

    testWidgets('the menu names the account; Use sends the switch', (
      tester,
    ) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await _providers(tester, c);
      await _manageAccounts(tester);
      await tester.tap(find.byKey(const ValueKey('credential-cred-1')));
      await tester.pumpAndSettle();
      expect(find.text('Use Work'), findsOneWidget);
      expect(find.text('Rename Work…'), findsOneWidget);
      expect(find.text('Remove Work'), findsOneWidget);
      await tester.tap(find.text('Use Work'));
      await tester.pumpAndSettle();
      expect(c.activated, ['cred-1']);
      expect(find.textContaining('Switch requested'), findsOneWidget);
    });

    testWidgets('remove asks with its consequence, then removes', (
      tester,
    ) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await _providers(tester, c);
      await _manageAccounts(tester);
      await _accountMenu(tester, 'cred-1', 'Remove Work');

      expect(find.text('Remove Anthropic account “Work”?'), findsOneWidget);
      expect(find.text('Remove “Work”'), findsOneWidget);
      expect(
        find.text(
          'Removes Work from this server. Projects that use it will need '
          'another Anthropic account.',
        ),
        findsOneWidget,
      );
      expect(c.removed, isEmpty);
      await tester.tap(find.byKey(const ValueKey('credential-remove-confirm')));
      await tester.pumpAndSettle();
      expect(c.removed, ['cred-1']);
    });

    testWidgets('a failed rename keeps the dialog open with the reason', (
      tester,
    ) async {
      final c = await library3Server()
        ..renameFails = true;
      addTearDown(c.dispose);
      await _providers(tester, c);
      await _manageAccounts(tester);
      await _accountMenu(tester, 'cred-1', 'Rename Work…');

      expect(find.text('Rename account'), findsWidgets);
      await tester.enterText(
        find.byKey(const ValueKey('credential-label-field')),
        'Studio',
      );
      await tester.tap(find.text('Save label'));
      await tester.pumpAndSettle();
      expect(c.renamed, ['Studio']);
      expect(
        find.textContaining('Could not confirm the account change'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('credential-label-field')), findsOne);
    });

    testWidgets('an empty label is refused before anything is sent', (
      tester,
    ) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await _providers(tester, c);
      await _manageAccounts(tester);
      await _accountMenu(tester, 'cred-2', 'Rename Personal…');
      // Two edits: showKitInputDialog misses the first one (its `late`
      // _lastText is first read after the change; reported to the kit).
      await tester.enterText(
        find.byKey(const ValueKey('credential-label-field')),
        'P',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('credential-label-field')),
        '   ',
      );
      // Validation speaks once typing settles.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Save label'));
      await tester.pumpAndSettle();
      // DEBUG
      expect(c.renamed, isEmpty);
      expect(
        find.textContaining('Give the account a name.', findRichText: true),
        findsWidgets,
      );
    });
  });

  group('unfinished sign-ins', () {
    testWidgets('a waiting sign-in is the provider\'s own row, first and '
        'marked; its sheet finishes, and forget asks first', (tester) async {
      final c = await library3Server()
        ..pending = [library3Pending()]
        ..uncertain = const [
          (integrationID: 'openai', kind: PendingAuthKind.command),
        ];
      addTearDown(c.dispose);
      await _providers(tester, c);

      // No cards above the list: the sign-ins are rows of it, sorted first,
      // each with the needs-you mark and its state in words.
      expect(find.text('Pending sign-in: cloud'), findsNothing);
      expect(find.textContaining('attempt ID'), findsNothing);
      final cloud = find.byKey(const ValueKey('pending-auth-cloud'));
      final openai = find.byKey(const ValueKey('pending-auth-openai'));
      expect(cloud, findsOneWidget);
      expect(openai, findsOneWidget);
      expect(
        find.descendant(of: cloud, matching: find.byType(KitTaskMark)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cloud,
          matching: find.text('Sign-in waiting', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: openai,
          matching: find.text(
            'Sign-in may not have started',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      final anthropic = find.byKey(const ValueKey('provider-anthropic'));
      expect(
        tester.getTopLeft(cloud).dy,
        lessThan(tester.getTopLeft(anthropic).dy),
      );
      // The provider is listed once: no second "Cloud · Not connected" row.
      expect(
        find.byKey(const ValueKey('connect-provider-cloud')),
        findsNothing,
      );

      await tester.tap(cloud);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sign-in-sheet')), findsOneWidget);
      expect(find.text('Finish signing in to Cloud'), findsOneWidget);
      expect(find.text('Enter code for Cloud'), findsOneWidget);
      expect(find.text('Cancel Cloud sign-in'), findsOneWidget);
      expect(find.text('Resume / check sign-in'), findsNothing);
      expect(find.byKey(const ValueKey('pending-auth-resume')), findsOne);
      expect(find.byKey(const ValueKey('pending-auth-enter-code')), findsOne);
      expect(find.byKey(const ValueKey('pending-auth-cancel')), findsOne);

      // The rarest act waits in the sheet's More, named for what it does.
      await tester.tap(find.byKey(const ValueKey('kit-actions-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget this sign-in on this phone'));
      await tester.pumpAndSettle();
      expect(find.text('Forget the Cloud sign-in?'), findsOneWidget);
      expect(c.forgotten, 0);
      await tester.tap(
        find.byKey(const ValueKey('pending-auth-forget-confirm')),
      );
      await tester.pumpAndSettle();
      expect(c.forgotten, 1);
    });

    // One forget-auth sheet (slice-P3.11a): a start the server never
    // confirmed is forgotten through the same question as a saved one.
    testWidgets('an unconfirmed start is forgotten through the same '
        'question', (tester) async {
      final c = await library3Server()
        ..uncertain = const [
          (integrationID: 'openai', kind: PendingAuthKind.command),
        ];
      addTearDown(c.dispose);
      await _providers(tester, c);

      await tester.tap(find.byKey(const ValueKey('pending-auth-openai')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('uncertain-auth-forget')));
      await tester.pumpAndSettle();
      expect(find.text('Forget this sign-in on this phone?'), findsNothing);
      expect(find.textContaining('Forget the '), findsOneWidget);
      expect(
        find.text(
          'The app stops tracking it on this device. Nothing is cancelled on '
          'the server; an unfinished sign-in there expires on its own.',
        ),
        findsOneWidget,
      );
      expect(c.uncertainForgotten, 0);
      await tester.tap(
        find.byKey(const ValueKey('pending-auth-forget-confirm')),
      );
      await tester.pumpAndSettle();
      expect(c.uncertainForgotten, 1);
    });
  });

  group('tools', () {
    Future<void> tools(WidgetTester tester, Library3Controller c) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(ToolsScreen(controller: c)));
      await tester.pumpAndSettle();
    }

    testWidgets('names the model and provider, and lists callable first', (
      tester,
    ) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await tools(tester, c);
      expect(find.text('Claude Sonnet 4'), findsOneWidget);
      // The provider, with the missing subagents in the same line (no
      // counts line under the model).
      expect(find.text('Anthropic · no background subagents'), findsOneWidget);
      expect(find.byKey(const ValueKey('tools-change-model')), findsNothing);
      // Plain description as the title, the id beside it.
      expect(
        find.text('Run a shell command in the active project.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('registered-tool-task')), findsOne);
      final bash = tester.getTopLeft(
        find.byKey(const ValueKey('coding-tool-bash')),
      );
      final task = tester.getTopLeft(
        find.byKey(const ValueKey('registered-tool-task')),
      );
      expect(bash.dy, lessThan(task.dy));
      // Three tools: read at a glance, no search field.
      expect(find.byKey(const ValueKey('tools-search')), findsNothing);
    });

    testWidgets('search appears from eight tools and filters', (tester) async {
      final repository = Library3Repository()
        ..tools = [
          for (var i = 0; i < 8; i++)
            CodingToolInfo(
              id: 'tool$i',
              description: 'Tool number $i',
              parameters: const {},
            ),
        ];
      final c = await library3Server(repository: repository);
      addTearDown(c.dispose);
      await tools(tester, c);
      expect(find.byKey(const ValueKey('tools-search')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('tools-search')), '7');
      // The field waits for typing to settle before it filters.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('coding-tool-tool7')), findsOneWidget);
      expect(find.byKey(const ValueKey('coding-tool-tool1')), findsNothing);
    });

    testWidgets('the detail sheet says what the tool takes before the JSON', (
      tester,
    ) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await tools(tester, c);
      await tester.tap(find.byKey(const ValueKey('coding-tool-bash')));
      await tester.pumpAndSettle();
      expect(find.text('Takes'), findsOneWidget);
      expect(find.text('text · required · The command to run'), findsOneWidget);
      expect(find.text('number · optional'), findsOneWidget);
      expect(find.text('yes or no · optional'), findsOneWidget);
      // The raw schema waits, folded, under its name.
      expect(find.text('Parameter schema'), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-parameter-schema')), findsNothing);
      await tester.tap(find.text('Parameter schema'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-parameter-schema')), findsOne);
    });

    test('toolParameters reads a JSON schema, required first', () {
      final parameters = toolParameters({
        'type': 'object',
        'properties': {
          'a': {'type': 'string'},
          'b': {
            'type': ['integer', 'null'],
          },
        },
        'required': ['b'],
      });
      expect(parameters.map((p) => p.name), ['b', 'a']);
      expect(parameters.first.type, ToolParameterType.number);
      expect(parameters.first.required, isTrue);
      expect(toolParameters(null), isEmpty);
      expect(toolParameters({'type': 'string'}), isEmpty);
    });
  });

  group('plugins', () {
    testWidgets('the page is built from the kit: top bar, the AI Team row '
        'in "In this app", and the server section', (tester) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(library3Plugins(c)));
      await tester.pumpAndSettle();
      expect(find.text('Plugins'), findsWidgets);
      expect(find.byKey(const ValueKey('plugins-section-app')), findsOne);
      expect(find.byKey(const ValueKey('plugins-ai-team-row')), findsOne);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('the AI Team row opens the one team page, off, which says '
        '"Off" once (P3.4: no AI Team sheet)', (tester) async {
      final c = await library3Server();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(library3Plugins(c)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plugins-ai-team-row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-plugin-sheet')), findsNothing);
      expect(find.byKey(const ValueKey('team-intro')), findsOne);
      expect(find.text('Off'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-intro-address')), findsOne);
    });
  });
}
