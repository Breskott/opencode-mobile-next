// Synthetic debug/test CPU timings; these are not device frame timings.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/complete_message_history.dart';

class _TranscriptApi extends OpenCodeApi with CompleteMessageHistory {
  _TranscriptApi(this.history) : super(baseUrl: 'http://localhost');
  final List<MessageWithParts> history;

  @override
  Future<List<MessageWithParts>> messages(String id) async => history;
  @override
  Future<Session> session(String id) async => Session(id: id);
  @override
  Future<List<Session>> sessions() async => const [];
  @override
  Future<Map<String, String>> sessionStatuses() async => const {};
  @override
  Future<List<Todo>> todos(String id) async => const [];
  @override
  Future<List<FileNode>> listFiles([String path = '']) async => const [];
}

List<MessageWithParts> _history(int count, {required bool fragmented}) {
  if (fragmented) {
    return [
      MessageWithParts(
        info: MessageInfo(id: 'tail', sessionID: 'perf', role: 'assistant'),
        parts: [
          for (var i = 0; i < count; i++)
            Part(id: 'p$i', messageID: 'tail', type: 'text', text: 'Part $i.'),
        ],
      ),
    ];
  }
  return [
    for (var i = 0; i < count; i++)
      MessageWithParts(
        info: MessageInfo(
          id: i == count - 1 ? 'tail' : 'm$i',
          sessionID: 'perf',
          role: i.isEven ? 'user' : 'assistant',
          time: MsgTime(created: i + 1, completed: i + 2),
        ),
        parts: [
          Part(
            id: 'p$i',
            messageID: i == count - 1 ? 'tail' : 'm$i',
            type: 'text',
            text: 'Part $i.',
          ),
        ],
      ),
  ];
}

void main() {
  testWidgets('PERF settled markdown and code survive ten tail updates', (
    tester,
  ) async {
    const prefix =
        '## Plan\n\nRead **this**.\n\n```dart\nfinal n = 1;\n```\n\n';
    Widget host(String tail) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: KitMarkdown('$prefix$tail')),
      ),
    );
    await tester.pumpWidget(host('Tail'));
    final counts = <String, int>{};
    final oldHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      counts[name] = (counts[name] ?? 0) + 1;
    };
    final before = KitMarkdown.debugParseCount;
    try {
      for (var i = 0; i < 10; i++) {
        await tester.pumpWidget(host('Tail${'x' * (i + 1)}'));
      }
    } finally {
      debugOnRebuildDirtyWidget = oldHook;
    }
    expect(KitMarkdown.debugParseCount - before, 10);
    expect(counts['KitCodeBlock'] ?? 0, 0);
    expect(counts['_KitMdHeading'] ?? 0, 0);
    debugPrint(
      'PERF_CHAT_CACHE ${jsonEncode({'tokens': 10, 'markdown_parses': KitMarkdown.debugParseCount - before, 'code_rebuilds': counts['KitCodeBlock'] ?? 0, 'heading_rebuilds': counts['_KitMdHeading'] ?? 0})}',
    );
  });
  for (final fragmented in [false, true]) {
    for (final count in [1000, 5000]) {
      testWidgets('PERF chat $count parts fragmented=$fragmented', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final api = _TranscriptApi(_history(count, fragmented: fragmented));
        final conn =
            ConnectionController(
                ProfileStore(prefs: await SharedPreferences.getInstance()),
              )
              ..api = api
              ..status = StreamStatus.connected;
        addTearDown(conn.dispose);
        final oldRebuildHook = debugOnRebuildDirtyWidget;
        addTearDown(() => debugOnRebuildDirtyWidget = oldRebuildHook);
        final initial = Stopwatch()..start();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [connProvider.overrideWithValue(conn)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const ChatScreen(sessionID: 'perf'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        initial.stop();
        expect(tester.takeException(), isNull);
        final mountedTurns = find.byType(KitTurn).evaluate().length;
        expect(mountedTurns, greaterThan(0));
        if (!fragmented) expect(mountedTurns, lessThan(100));

        void token() => conn.handleEventForTesting(
          EventEnvelope(
            type: 'message.part.delta',
            properties: {
              'sessionID': 'perf',
              'messageID': 'tail',
              'partID': 'p${count - 1}',
              'field': 'text',
              'delta': 'x',
            },
          ),
        );

        Future<void> measure(String mode, int tokens) async {
          final rebuilds = <String, int>{};
          var controllerNotifications = 0;
          void notified() => controllerNotifications++;
          conn.addListener(notified);
          debugOnRebuildDirtyWidget = (element, _) {
            final name = element.widget.runtimeType.toString();
            rebuilds[name] = (rebuilds[name] ?? 0) + 1;
          };
          final parses = KitMarkdown.debugParseCount;
          final flushes = debugChatStreamFlushes;
          final watch = Stopwatch()..start();
          if (mode == 'burst') {
            for (var i = 0; i < tokens; i++) {
              token();
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));
          } else {
            for (var i = 0; i < tokens; i++) {
              token();
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 60));
            }
          }
          watch.stop();
          conn.removeListener(notified);
          debugOnRebuildDirtyWidget = oldRebuildHook;
          expect(tester.takeException(), isNull);
          expect(debugChatStreamFlushes - flushes, lessThanOrEqualTo(tokens));
          expect(controllerNotifications, 0);
          // Only synthetic sizes/counts/timings, never transcript content.
          final metrics = {
            'parts': count,
            'fragmented': fragmented,
            'mode': mode,
            'tokens': tokens,
            'load_us': initial.elapsedMicroseconds,
            'mounted_turns': mountedTurns,
            'pump_cpu_us': watch.elapsedMicroseconds,
            'stream_flushes': debugChatStreamFlushes - flushes,
            'controller_notifications': controllerNotifications,
            'markdown_parses': KitMarkdown.debugParseCount - parses,
            'chat_rebuilds': rebuilds['ChatScreen'] ?? 0,
            'turn_rebuilds': rebuilds['KitTurn'] ?? 0,
            'markdown_rebuilds': rebuilds['KitMarkdown'] ?? 0,
            'code_rebuilds': rebuilds['KitCodeBlock'] ?? 0,
          };
          debugPrint('PERF_CHAT ${jsonEncode(metrics)}');
        }

        await measure('spaced', 10);
        await measure('burst', 100);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
