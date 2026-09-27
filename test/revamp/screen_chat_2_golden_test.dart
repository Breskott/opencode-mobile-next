// Golden renders of screen-chat-2's pages (wave 2b), rebuilt from kit parts:
// Active context and one of its messages, Note for the agent with its
// discard question, Subagents, and Add web source with a result added.
// Phone 412x915 and one wide window (1280x800), dark and light (owner
// decision 2026-09-27: no Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_chat_2_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/active_context_screen.dart';
import 'package:opencode_mobile/ui/screens/session_note_screen.dart';
import 'package:opencode_mobile/ui/screens/session_relations_screen.dart';
import 'package:opencode_mobile/ui/screens/web_sources_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import 'screen_chat_2_fixtures.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Widget Function(ChatTwoController c) home,
  void Function(ChatTwoController c)? setUp,
  Size size = _phone,
  Future<void> Function()? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final controller = await chatTwoController();
  setUp?.call(controller);
  final navigator = GlobalKey<NavigatorState>();
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    // Pushed, so each page shows its Back like it does from the chat.
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => home(controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    if (then != null) await then();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
  }
}

Widget _context(ChatTwoController c) =>
    ActiveContextScreen(controller: c, sessionID: 's1');
Widget _note(ChatTwoController c) =>
    SessionNoteScreen(controller: c, sessionID: 's1');
Widget _relations(ChatTwoController c) =>
    SessionRelationsScreen(controller: c, sessionID: 'child-tests');
Widget _web(ChatTwoController c) => WebSourcesScreen(controller: c);

void _withContext(ChatTwoController c) => c.repository = ContextRepository();
void _withNote(ChatTwoController c) => c.note =
    'Run the checkout tests before finishing, and keep the cart '
    'total exact to the cent.';
void _withRelations(ChatTwoController c) {
  c.repository = RelationsRepository();
  c.busySessions.add('child-audit');
}

void _withSearch(ChatTwoController c) =>
    c.api = SearchGateway(results: searchResults);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      final where = size == _phone ? 'phone' : 'wide';

      testWidgets('active context · $where · $mode', (tester) async {
        await _shot(
          tester,
          'chat2_active_context',
          light: light,
          size: size,
          setUp: _withContext,
          home: _context,
        );
      });

      testWidgets('note · $where · $mode', (tester) async {
        await _shot(
          tester,
          'chat2_session_note',
          light: light,
          size: size,
          setUp: _withNote,
          home: _note,
        );
      });

      testWidgets('subagents · $where · $mode', (tester) async {
        await _shot(
          tester,
          'chat2_session_relations',
          light: light,
          size: size,
          setUp: _withRelations,
          home: _relations,
        );
      });

      testWidgets('web sources · $where · $mode', (tester) async {
        await _shot(
          tester,
          'chat2_web_sources',
          light: light,
          size: size,
          setUp: _withSearch,
          home: _web,
          then: () async {
            await tester.enterText(
              find.byKey(const ValueKey('web-search-query')),
              'flutter golden tests',
            );
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('web-search-submit')));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byTooltip('Add Testing Flutter apps to prompt'),
            );
            await tester.pumpAndSettle();
            FocusManager.instance.primaryFocus?.unfocus();
          },
        );
      });
    }

    testWidgets('active context message · $mode', (tester) async {
      await _shot(
        tester,
        'chat2_active_context_message',
        light: light,
        setUp: _withContext,
        home: _context,
        then: () =>
            tester.tap(find.byKey(const ValueKey('active-context-msg_03'))),
      );
    });

    testWidgets('note discard question · $mode', (tester) async {
      await _shot(
        tester,
        'chat2_session_note_discard',
        light: light,
        setUp: _withNote,
        home: _note,
        then: () async {
          await tester.enterText(
            find.byKey(const ValueKey('session-note-editor')),
            'Keep answers short.',
          );
          await tester.pump();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.binding.handlePopRoute();
        },
      );
    });

    testWidgets('subagent row menu · $mode', (tester) async {
      await _shot(
        tester,
        'chat2_session_relations_menu',
        light: light,
        setUp: _withRelations,
        home: _relations,
        then: () => tester.longPress(
          find.byKey(const ValueKey('session-relation-child-audit')),
        ),
      );
    });
  }
}
