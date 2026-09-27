// Unit chat-8, the chat screen's second half (map pages chat,
// chat-run-shell-dialog, chat-message-actions-sheet). What the person sees:
// the shell command and the rename are kit dialogs that run from inside
// and keep a failure under the field; a display toggle offers Undo; a tool
// call a permission waits on says "Waiting for you"; and on a server that
// cannot run an app action, the command launcher says why instead of
// leaving it out (P7.4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/codex/gateway.dart'
    show codexServerCapabilities;
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/ui/widgets/tool_card.dart';

import 'chat_3_support.dart';

class _Chat8Api extends Chat3Api {
  final shells = <String>[];
  final renames = <String>[];
  Object? shellFailure;

  @override
  Future<void> shell(
    String sessionID, {
    required String command,
    required String agent,
    ModelRef? model,
    String? variant,
  }) async {
    final failure = shellFailure;
    if (failure != null) throw failure;
    shells.add(command);
  }

  @override
  Future<void> renameSession(String id, String title) async {
    renames.add(title);
  }
}

class _CodexChat8Api extends _Chat8Api {
  @override
  ServerCapabilities get capabilities => codexServerCapabilities;
}

Future<void> _openLauncher(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('composer-tools-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('composer-tool-commands')));
  await tester.pumpAndSettle();
}

Future<void> _runCommand(WidgetTester tester, String slash) async {
  await _openLauncher(tester);
  await tester.enterText(
    find.byKey(const Key('command-launcher-search')),
    slash,
  );
  await tester.pump();
  final row = find.byKey(Key('command-mobile-$slash'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

MessageWithParts _runningTool(String callID) => MessageWithParts(
  info: MessageInfo(
    id: 'assistant-1',
    sessionID: 'session-1',
    role: 'assistant',
    time: MsgTime(created: 1),
  ),
  parts: [
    Part(
      id: 'part-$callID',
      callID: callID,
      messageID: 'assistant-1',
      type: 'tool',
      toolName: 'bash',
      toolState: ToolState.fromJson({
        'status': 'running',
        'input': {'command': 'npm test'},
      }, toolName: 'bash'),
    ),
  ],
);

EventEnvelope _asked(String callID) => EventEnvelope(
  type: 'permission.asked',
  properties: {
    'id': 'request-1',
    'sessionID': 'session-1',
    'permission': 'bash',
    'patterns': ['npm test'],
    'metadata': <String, Object?>{},
    'always': <String>[],
    'tool': {'messageID': 'assistant-1', 'callID': callID},
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(chat3MockSecureStorage);

  testWidgets('Run shell command runs from the dialog and keeps a failure', (
    tester,
  ) async {
    final api = _Chat8Api()
      ..shellFailure = const ProductException('Shell is busy');
    final conn = await chat3Controller(api: api);
    addTearDown(conn.dispose);
    await pumpChat3(tester, conn);

    await tester.tap(find.byTooltip('Conversation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversation actions'));
    await tester.pumpAndSettle();
    // The session menu is a lazy list: rows below the fold are built as it
    // scrolls.
    await tester.scrollUntilVisible(
      find.text('Run shell command'),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('session-menu-sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run shell command'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('run-shell-dialog')), findsOneWidget);
    // Says what happens, and why Run waits.
    expect(
      find.text(
        'The agent runs it in this project, and its output joins the '
        'conversation.',
      ),
      findsOneWidget,
    );
    expect(find.text('Type a command to run.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('run-shell-command')),
      'npm test',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('run-shell-confirm')));
    await tester.pumpAndSettle();
    // The failure stays with the command, in the dialog.
    expect(find.byKey(const ValueKey('run-shell-dialog')), findsOneWidget);
    expect(find.textContaining('Shell is busy'), findsOneWidget);

    api.shellFailure = null;
    await tester.tap(find.byKey(const ValueKey('run-shell-confirm')));
    await tester.pumpAndSettle();
    expect(api.shells, ['npm test']);
    expect(find.byKey(const ValueKey('run-shell-dialog')), findsNothing);
  });

  testWidgets('Rename conversation is a kit dialog that says why it waits', (
    tester,
  ) async {
    final api = _Chat8Api();
    final conn = await chat3Controller(api: api);
    addTearDown(conn.dispose);
    await pumpChat3(tester, conn);

    await _runCommand(tester, 'rename');
    expect(find.byKey(const ValueKey('rename-session-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rename-session-title')),
      '',
    );
    await tester.pump();
    expect(find.text('Type a title.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rename-session-title')),
      'Checkout fix',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(api.renames, ['Checkout fix']);
    expect(find.byKey(const ValueKey('rename-session-dialog')), findsNothing);
  });

  testWidgets('a display toggle offers Undo instead of a snackbar', (
    tester,
  ) async {
    final conn = await chat3Controller(api: _Chat8Api());
    addTearDown(conn.dispose);
    await pumpChat3(tester, conn);
    final before = conn.transcriptTimestampsVisible;

    await _runCommand(tester, 'timestamps');
    expect(conn.transcriptTimestampsVisible, !before);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.text(
        before ? 'Message timestamps hidden' : 'Message timestamps shown',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(conn.transcriptTimestampsVisible, before);
  });

  testWidgets('a tool call a permission waits on says it waits for you', (
    tester,
  ) async {
    final api = _Chat8Api()
      ..transcript = [
        chat3Prompt('user-1', 'Run the tests'),
        _runningTool('c1'),
      ];
    final conn = await chat3Controller(api: api);
    addTearDown(conn.dispose);
    await pumpChat3(tester, conn);

    final card = find.byType(ToolCard);
    expect(tester.widget<ToolCard>(card).waitingForYou, isFalse);
    // A shell step can be run again, through the dialog.
    expect(tester.widget<ToolCard>(card).onRerunCommand, isNotNull);

    conn.handleEventForTesting(_asked('another-call'));
    await tester.pump();
    expect(tester.widget<ToolCard>(card).waitingForYou, isFalse);

    conn.handleEventForTesting(_asked('c1'));
    await tester.pump();
    expect(tester.widget<ToolCard>(card).waitingForYou, isTrue);
  });

  testWidgets('Codex: the launcher says why Files, Review and settings are '
      'missing', (tester) async {
    final conn = await chat3Controller(api: _CodexChat8Api());
    addTearDown(conn.dispose);
    await pumpChat3(tester, conn);
    await _openLauncher(tester);

    for (final capability in [
      'flag:fileBrowsing+terminal',
      'flag:sessionDiff',
      'flag:serverCatalog',
    ]) {
      final row = find.byKey(ValueKey('command-unavailable-$capability'));
      await tester.ensureVisible(row);
      expect(row, findsOneWidget);
    }

    // A search for one such action names it and says why.
    await tester.enterText(
      find.byKey(const Key('command-launcher-search')),
      'files',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('command-mobile-files')), findsNothing);
    expect(find.byKey(const Key('command-launcher-no-match')), findsNothing);
    final files = find.byKey(
      const ValueKey('command-unavailable-flag:fileBrowsing+terminal'),
    );
    expect(
      find.descendant(of: files, matching: find.text('Project files')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: files,
        matching: find.textContaining("doesn't share its files"),
      ),
      findsOneWidget,
    );
  });

  testWidgets('OpenCode lists every action, with nothing to explain', (
    tester,
  ) async {
    final conn = await chat3Controller(api: _Chat8Api());
    addTearDown(conn.dispose);
    await pumpChat3(tester, conn);
    await _openLauncher(tester);
    expect(find.byKey(const Key('command-launcher-unavailable')), findsNothing);
  });
}
