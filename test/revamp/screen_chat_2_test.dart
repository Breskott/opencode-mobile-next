// Behaviour of screen-chat-2's pages as the person meets them: deleting the
// note offers Undo that puts the words back, a failed save keeps the draft
// with Try again, the size shows only near the limit; subagents list by
// urgency and a working one can be stopped by name; active context says
// when nothing matches; web sources marks what was added on its own row
// (tap again removes it) and finishes with "Add N sources to prompt", and a
// failed search offers to search again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/active_context_screen.dart';
import 'package:opencode_mobile/ui/screens/session_note_screen.dart';
import 'package:opencode_mobile/ui/screens/session_relations_screen.dart';
import 'package:opencode_mobile/ui/screens/web_sources_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme;
import 'screen_chat_2_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: captureTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The working mark spins; tests read still frames.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('note for the agent', () {
    testWidgets('delete offers Undo, and Undo writes the words back', (
      tester,
    ) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      c.note = 'Run the checkout tests before finishing.';
      await _pump(tester, SessionNoteScreen(controller: c, sessionID: 's1'));

      await tester.tap(find.byKey(const ValueKey('remove-session-note')));
      await tester.pumpAndSettle();
      expect(c.noteWrites, [null]);
      // Delete stays on the page: the field is empty and Undo is offered.
      expect(
        find.text('Run the checkout tests before finishing.'),
        findsNothing,
      );
      expect(find.text('Note deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(c.noteWrites, [null, 'Run the checkout tests before finishing.']);
      expect(
        find.text('Run the checkout tests before finishing.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed save keeps the draft and Try again repeats it', (
      tester,
    ) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      await _pump(tester, SessionNoteScreen(controller: c, sessionID: 's1'));
      await tester.enterText(
        find.byKey(const ValueKey('session-note-editor')),
        'Keep answers short.',
      );
      await tester.pumpAndSettle();
      c.saveFailure = StateError('offline');
      await tester.tap(find.byKey(const ValueKey('save-session-note')));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't save the note"), findsOneWidget);
      expect(find.text('Keep answers short.'), findsOneWidget);
      c.saveFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(c.noteWrites, ['Keep answers short.']);
    });

    testWidgets('the size shows only near the limit, and too long says by '
        'how much', (tester) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      await _pump(tester, SessionNoteScreen(controller: c, sessionID: 's1'));
      final field = find.byKey(const ValueKey('session-note-editor'));
      await tester.enterText(field, 'short');
      await tester.pumpAndSettle();
      expect(find.textContaining('bytes'), findsNothing);
      await tester.enterText(field, 'a' * 7000);
      await tester.pumpAndSettle();
      expect(find.textContaining(' / 8192 bytes'), findsOneWidget);
      await tester.enterText(field, 'a' * 8200);
      await tester.pumpAndSettle();
      // The server counts the note's JSON string, quotes included.
      expect(
        find.text('10 bytes too long. A note can be up to 8192 bytes.'),
        findsOneWidget,
      );
    });
  });

  group('subagents', () {
    testWidgets('one list by urgency: working first, then newest first', (
      tester,
    ) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      c.repository = RelationsRepository();
      c.busySessions.add('child-audit');
      await _pump(
        tester,
        SessionRelationsScreen(controller: c, sessionID: 'parent'),
      );
      double top(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('session-relation-$id'))).dy;
      expect(find.text('3 subagents'), findsOneWidget);
      expect(top('child-audit'), lessThan(top('child-tests')));
      expect(top('child-tests'), lessThan(top('child-cache')));
      expect(find.textContaining('Working'), findsOneWidget);
    });

    testWidgets('a working subagent is stopped by name after a question', (
      tester,
    ) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      c.repository = RelationsRepository();
      c.transport = AbortTransport(c);
      c.busySessions.add('child-audit');
      await _pump(
        tester,
        SessionRelationsScreen(controller: c, sessionID: 'parent'),
      );
      await tester.longPress(
        find.byKey(const ValueKey('session-relation-child-audit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Audit the image sizes'));
      await tester.pumpAndSettle();
      expect(find.text('Stop Audit the image sizes?'), findsOneWidget);
      await tester.tap(find.text('Stop subagent'));
      await tester.pumpAndSettle();
      expect(c.aborted, ['child-audit']);
    });

    testWidgets('a subagent that is done has no stop', (tester) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      c.repository = RelationsRepository();
      await _pump(
        tester,
        SessionRelationsScreen(controller: c, sessionID: 'parent'),
      );
      await tester.longPress(
        find.byKey(const ValueKey('session-relation-child-audit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stop Audit the image sizes'), findsNothing);
      // The handoff item reads "Continue … on computer" since 00cafa13.
      expect(
        find.text('Continue Audit the image sizes on computer'),
        findsOneWidget,
      );
    });
  });

  group('active context', () {
    testWidgets('a search with no match says so and clears', (tester) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      c.repository = ContextRepository();
      await _pump(tester, ActiveContextScreen(controller: c, sessionID: 's1'));
      expect(find.textContaining('What the model reads'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('active-context-search')),
        'kotlin',
      );
      // The search settles after typing stops.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('active-context-no-match')),
        findsOneWidget,
      );
      await tester.tap(find.text('Clear search'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      // No count line since 253a6919 (R16: the search field says how many
      // match): clearing brings every message row back.
      expect(
        find.byKey(const ValueKey('active-context-no-match')),
        findsNothing,
      );
      for (final id in ['msg_01', 'msg_02', 'msg_03']) {
        expect(find.byKey(ValueKey('active-context-$id')), findsOneWidget);
      }
    });
  });

  group('web sources', () {
    Future<ChatTwoController> searchable(SearchGateway gateway) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      c.api = gateway;
      return c;
    }

    testWidgets('a result toggles Added in place, is listed once, and the '
        'primary returns it', (tester) async {
      final gateway = SearchGateway(results: searchResults);
      final c = await searchable(gateway);
      final navigator = GlobalKey<NavigatorState>();
      await _pump(tester, const SizedBox.shrink(), navigatorKey: navigator);
      final opened = navigator.currentState!.push(
        MaterialPageRoute<List<WebSourceSelection>>(
          builder: (_) => WebSourcesScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      // One provider: no picker to choose from, just its name.
      expect(find.textContaining('Exa', findRichText: true), findsWidgets);
      await tester.enterText(
        find.byKey(const ValueKey('web-search-query')),
        'flutter golden tests',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('web-search-submit')));
      await tester.pumpAndSettle();
      expect(find.text('2 results'), findsOneWidget);
      await tester.tap(find.byTooltip('Add Testing Flutter apps to prompt'));
      await tester.pumpAndSettle();
      expect(find.text('Added'), findsOneWidget);
      // Shown once: marked on its result row, not listed again below.
      expect(find.byKey(const ValueKey('web-sources-added')), findsNothing);
      expect(find.text('Add 1 source to prompt'), findsOneWidget);
      // Tapping the row again takes it out; with nothing added the page
      // offers Close.
      await tester.tap(find.text('Testing Flutter apps'));
      await tester.pumpAndSettle();
      expect(find.text('Added'), findsNothing);
      expect(find.byKey(const ValueKey('web-sources-confirm')), findsNothing);
      expect(find.byKey(const ValueKey('web-sources-close')), findsOneWidget);
      await tester.tap(find.text('Testing Flutter apps'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('web-sources-confirm')));
      await tester.pumpAndSettle();
      final returned = await opened;
      expect(returned?.single.url, 'https://docs.flutter.dev/testing/overview');
    });

    testWidgets('no results says so; a failed search offers Search again', (
      tester,
    ) async {
      final gateway = SearchGateway(results: const []);
      final c = await searchable(gateway);
      await _pump(tester, WebSourcesScreen(controller: c));
      await tester.enterText(
        find.byKey(const ValueKey('web-search-query')),
        'nothing here',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('web-search-submit')));
      await tester.pumpAndSettle();
      expect(find.text('No usable results for this query.'), findsOneWidget);

      gateway.failure = WebSearchFailureKind.failed;
      await tester.tap(find.byKey(const ValueKey('web-search-submit')));
      await tester.pumpAndSettle();
      expect(find.text("Search didn't finish"), findsOneWidget);
      gateway.failure = null;
      gateway.results = searchResults;
      await tester.tap(find.text('Search again'));
      await tester.pumpAndSettle();
      expect(gateway.searches, 3);
      expect(find.text('2 results'), findsOneWidget);
    });

    testWidgets('without search, a pasted link is added and can be removed', (
      tester,
    ) async {
      final c = await chatTwoController();
      addTearDown(c.dispose);
      await _pump(tester, WebSourcesScreen(controller: c));
      expect(find.byKey(const ValueKey('web-search-query')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('web-source-url')),
        'ftp://example.com',
      );
      await tester.tap(find.byKey(const ValueKey('web-source-add')));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP or HTTPS'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('web-source-url')),
        'https://example.com/notes',
      );
      await tester.enterText(
        find.byKey(const ValueKey('web-source-title')),
        'Release notes',
      );
      await tester.tap(find.byKey(const ValueKey('web-source-add')));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 source to prompt'), findsOneWidget);
      // A pasted link has no result row: it is listed under its own label.
      expect(find.text('Links you added'), findsOneWidget);
      await tester.ensureVisible(
        find.byTooltip('Remove Release notes from prompt'),
      );
      await tester.tap(find.byTooltip('Remove Release notes from prompt'));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 source to prompt'), findsNothing);
    });
  });
}
