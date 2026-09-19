import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/api2/gateway_mappers.dart';
import 'package:opencode_mobile/domain/background_agent_result.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

import '../tool/capture/fixtures.dart' show capturePng, loadCaptureFonts;

Part _result({
  String state = 'completed',
  String description = 'Check the checkout validation',
  String body = 'Validation now reports missing fields clearly.',
  String child = 'ses_child',
  String? text,
  Map<String, dynamic>? metadata,
}) => mapApi2Message(
  'ses_parent',
  Api2Message.fromJson({
    'id': 'msg_completion',
    'type': 'synthetic',
    'time': {'created': 123},
    'description': description,
    'text':
        text ??
        '<subagent sessionID="$child" state="$state" description="$description">\n$body\n</subagent>',
    'metadata':
        metadata ??
        {
          'source': 'subagent',
          'childID': child,
          'agent': 'explore',
          'state': state,
          'ignored-private-field': 'never copied',
        },
  })!,
).parts.single;

Widget _host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, body) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: body!),
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('canonical mapper preserves only result identity/status metadata', () {
    final part = _result();
    expect(
      part.noticeMetadata.keys,
      unorderedEquals(['source', 'childID', 'agent', 'state']),
    );
    final result = BackgroundAgentResult.fromPart(part)!;
    expect(result.body, 'Validation now reports missing fields clearly.');
    expect(result.childID, 'ses_child');
    expect(result.state, 'completed');
    expect(part.messageID, 'msg_completion');
  });

  test('quoted and multiline task names preserve exact result boundaries', () {
    const body = 'Keep <subagent>inside user output</subagent> unchanged.';
    final result = BackgroundAgentResult.fromPart(
      _result(description: 'Inspect "quotes"\nand paths', body: body),
    );
    expect(result?.description, 'Inspect "quotes"\nand paths');
    expect(result?.body, body);
  });

  test('unknown/mismatched/malformed envelopes never become a result', () {
    for (final part in [
      _result(state: 'running'),
      _result(text: 'Prefix\n${_result().text}'),
      _result(text: _result().text.replaceFirst('ses_child', 'ses_other')),
      _result(text: _result().text.replaceFirst('completed', 'error')),
      _result(text: _result().text.replaceFirst('</subagent>', '')),
      _result(metadata: {'source': 'not-subagent'}),
      _result(child: '../not-a-session'),
      Part(type: 'text', text: _result().text),
    ]) {
      expect(BackgroundAgentResult.fromPart(part), isNull);
    }
  });

  testWidgets('completed result shows actual body with source details opt-in', (
    tester,
  ) async {
    final part = _result();
    final opened = <String>[];
    await tester.pumpWidget(
      _host(
        V2TranscriptRow(
          part: part,
          messageId: 'msg_completion',
          parentSessionID: 'ses_parent',
          knownSessions: {
            'ses_child': Session(id: 'ses_child', parentID: 'ses_parent'),
          },
          onOpenChild: opened.add,
        ),
      ),
    );
    expect(find.text('Background result'), findsOneWidget);
    expect(find.text('explore · Completed'), findsOneWidget);
    expect(find.textContaining('Validation now reports'), findsOneWidget);
    expect(find.text(part.text), findsNothing);
    await tester.tap(find.text('Open subagent conversation'));
    expect(opened, ['ses_child']);
    await tester.tap(find.text('Server message details'));
    await tester.pumpAndSettle();
    expect(find.text(part.text), findsOneWidget);
  });

  testWidgets('missing or unrelated child never offers navigation', (
    tester,
  ) async {
    for (final sessions in [
      <String, Session>{},
      {'ses_child': Session(id: 'ses_child', parentID: 'ses_someone_else')},
    ]) {
      await tester.pumpWidget(
        _host(
          V2TranscriptRow(
            part: _result(),
            messageId: 'msg_completion',
            parentSessionID: 'ses_parent',
            knownSessions: sessions,
            onOpenChild: (_) => fail('Unsafe navigation'),
          ),
        ),
      );
      expect(find.text('Open subagent conversation'), findsNothing);
      expect(find.textContaining('Validation now reports'), findsOneWidget);
    }
  });

  testWidgets('failure/cancelled remain honest distinct states', (
    tester,
  ) async {
    for (final state in ['error', 'cancelled']) {
      await tester.pumpWidget(
        _host(
          V2TranscriptRow(
            part: _result(state: state, body: 'The server stopped this task.'),
            messageId: 'msg_$state',
          ),
        ),
      );
      expect(
        find.text(
          state == 'error' ? 'explore · Failed' : 'explore · Cancelled',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('The server stopped'), findsOneWidget);
      expect(find.text('explore · Completed'), findsNothing);
    }
  });

  testWidgets('unknown notice retains readable raw fallback', (tester) async {
    const raw =
        '<subagent unexpected="future">Never lose this result.</subagent>';
    await tester.pumpWidget(
      _host(
        V2TranscriptRow(
          part: _result(text: raw),
          messageId: 'msg_unknown',
        ),
      ),
    );
    expect(find.byType(BackgroundAgentResultCard), findsNothing);
    await tester.tap(find.text('Check the checkout validation'));
    await tester.pumpAndSettle();
    expect(find.textContaining(raw), findsOneWidget);
  });

  testWidgets('result and long identity remain readable at 320dp/2.5x/RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        V2TranscriptRow(
          part: _result(
            description: 'مراجعة تدفق الدفع ومعالجة الأخطاء دون فقدان الرسائل',
            body:
                'تمت مراجعة التحقق.\n\n`lib/checkout.dart`\n\nKeep authored English intact.',
          ),
          messageId: 'msg_rtl',
          parentSessionID: 'ses_parent',
          knownSessions: {
            'ses_child': Session(id: 'ses_child', parentID: 'ses_parent'),
          },
          onOpenChild: (_) {},
        ),
        direction: TextDirection.rtl,
        scale: 2.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Open subagent conversation'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('capture canonical result at normal, narrow and large RTL scales', (
    tester,
  ) async {
    final captureDir = Platform.environment['E7_CHAT_CAPTURE_DIR']!;
    await loadCaptureFonts();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final variant in [
      (390.0, 1.0, false),
      (320.0, 1.0, false),
      (320.0, 2.5, true),
    ]) {
      tester.view.physicalSize = Size(variant.$1, 900);
      await tester.pumpWidget(const SizedBox.shrink());
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: _host(
            V2TranscriptRow(
              part: _result(
                description: variant.$3
                    ? 'مراجعة تدفق الدفع ومعالجة الأخطاء'
                    : 'Review checkout validation',
                body: variant.$3
                    ? 'تمت مراجعة التحقق.\n\n`lib/checkout.dart`\n\nKeep authored English intact.'
                    : 'Validation now reports missing fields clearly.\n\nUpdated `lib/checkout.dart`. Existing checkout drafts remain intact.',
              ),
              messageId: 'capture-result',
              parentSessionID: 'ses_parent',
              knownSessions: {
                'ses_child': Session(id: 'ses_child', parentID: 'ses_parent'),
              },
              onOpenChild: (_) {},
            ),
            direction: variant.$3 ? TextDirection.rtl : TextDirection.ltr,
            scale: variant.$2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bytes = await capturePng(tester, boundary);
      File(
        '$captureDir/result-${variant.$1.toInt()}-${variant.$2}x-${variant.$3 ? 'rtl' : 'ltr'}.png',
      ).writeAsBytesSync(bytes);
    }
  }, skip: Platform.environment['E7_CHAT_CAPTURE_DIR'] == null);
}
