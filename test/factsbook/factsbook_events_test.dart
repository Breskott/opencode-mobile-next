// Triggers fire from the app: a capture that reaches the node also tells its
// rules (POST /v1/events), only where the node lists the trigger capability,
// without ever changing what the person sees about their capture and without
// echoing the text back.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_capabilities.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_trigger_types.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/http_factsbook_gateway.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_controller.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/ui/screens/factsbook/capture_screen.dart';

import 'factsbook_test_support.dart';
import 'node_adapter.dart';

const _line = 'Appointment: Library visit | 2026-10-15T09:00';

void main() {
  late FakeFactsBookGateway node;
  late FactsBookController controller;
  setUp(() {
    node = withClock(Clock.fixed(factsNow), FakeFactsBookGateway.withTriggers);
    controller = FactsBookController(FactsBookSession.fixed(node));
  });
  tearDown(() => controller.dispose());

  test(
    'a note is posted as an event, not to the inbox, with no signature',
    () async {
      final outcome = await controller.capture(
        const CaptureRequest(kind: CaptureKind.note, text: 'call Sam'),
        rulesLook: true,
      );
      expect(outcome, isA<CaptureSavedAtNode>());
      expect(node.calls, isNot(contains('capture')));
      final sample = node.postedEvents.single;
      expect(sample.kind, TriggerSourceKind.note);
      expect(sample.sourceInstance, 'manual-note');
      expect(node.postedClassified.single, isFalse);
    },
  );

  test(
    'shared text is posted once, as an event, signed as ordinary text',
    () async {
      final outcome = await controller.capture(
        const CaptureRequest(kind: CaptureKind.share, text: _line),
        rulesLook: true,
      );
      expect(outcome, isA<CaptureSavedAtNode>());
      // The contract says not to post the same capture to the inbox as well.
      expect(node.calls, isNot(contains('capture')));
      final sample = node.postedEvents.single;
      expect(sample.kind, TriggerSourceKind.share);
      expect(sample.sourceInstance, 'manual-share');
      expect(sample.text, _line);
      expect(sample.locale, 'en');
      expect(sample.revision, 1);
      expect(node.postedClassified.single, isTrue);
      // Opaque ASCII keys, never the text.
      expect(
        RegExp(r'^[A-Za-z0-9_.-]{1,80}$').hasMatch(sample.messageKey),
        isTrue,
      );
      expect(sample.messageKey.contains('Library'), isFalse);
    },
  );

  test('a matching rule makes a firing the next read shows', () async {
    await controller.capture(
      const CaptureRequest(kind: CaptureKind.share, text: _line),
      rulesLook: true,
    );
    await controller.triggers.refresh(quiet: true);
    final event = controller.triggers.events.last;
    expect(event.reason, TriggerReason.matched);
    expect(controller.triggers.firingsOfEvent(event.id), hasLength(1));
  });

  test('a selected chat message is a chat event', () async {
    await controller.capture(
      const CaptureRequest(
        kind: CaptureKind.chatSelection,
        text: 'rent is due',
      ),
      rulesLook: true,
    );
    expect(node.postedEvents.single.kind, TriggerSourceKind.chatSelection);
    expect(node.postedEvents.single.sourceInstance, 'selected-chat');
    expect(node.postedClassified.single, isTrue);
  });

  test('Arabic text is posted as an Arabic event', () async {
    await controller.capture(
      const CaptureRequest(
        kind: CaptureKind.share,
        text: 'موعد: زيارة المكتبة | 2026-10-15T09:00',
      ),
      rulesLook: true,
    );
    expect(node.postedEvents.single.locale, 'ar');
  });

  test('without asking rules to look it goes to the inbox as before', () async {
    await controller.capture(
      const CaptureRequest(kind: CaptureKind.share, text: _line),
    );
    expect(node.calls, contains('capture'));
    expect(node.postedEvents, isEmpty);
  });

  test('an import is never an event', () async {
    await controller.capture(
      const CaptureRequest(kind: CaptureKind.importText, text: 'old notes'),
      rulesLook: true,
    );
    expect(node.postedEvents, isEmpty);
    expect(node.calls, contains('capture'));
  });

  test(
    'a phone that cannot sign saves shared text to the inbox instead',
    () async {
      final c = FactsBookController(
        FactsBookSession.fixed(node, canApprove: false),
      );
      addTearDown(c.dispose);
      final outcome = await c.capture(
        const CaptureRequest(kind: CaptureKind.share, text: _line),
        rulesLook: true,
      );
      expect(outcome, isA<CaptureSavedAtNode>());
      expect(node.postedEvents, isEmpty);
      expect(node.calls, contains('capture'));
    },
  );

  test('without the trigger capability nothing is posted', () async {
    final plain = FakeFactsBookGateway.withTriggers();
    const none = FactsBookCapabilities(
      milestone: 'test',
      supported: {FactsBookCapabilities.localCapture},
      disabled: {},
    );
    final c = FactsBookController(
      FactsBookSession.fixed(plain)..capabilities = none,
    );
    addTearDown(c.dispose);
    final outcome = await c.capture(
      const CaptureRequest(kind: CaptureKind.share, text: _line),
      rulesLook: true,
    );
    expect(outcome, isA<CaptureSavedAtNode>());
    expect(plain.postedEvents, isEmpty);
    expect(plain.calls, contains('capture'));
  });

  test(
    'an event the node does not take falls back to the inbox: nothing is lost',
    () async {
      node.eventFailure = const FactsBookException('bad_request', status: 400);
      final outcome = await controller.capture(
        const CaptureRequest(kind: CaptureKind.share, text: _line),
        rulesLook: true,
      );
      expect(outcome, isA<CaptureSavedAtNode>());
      expect(node.calls, contains('capture'));
      node.eventFailure = const FactsBookException('not_found', status: 404);
      expect(
        await controller.capture(
          const CaptureRequest(kind: CaptureKind.share, text: 'more'),
          rulesLook: true,
        ),
        isA<CaptureSavedAtNode>(),
      );
    },
  );

  test('a cancelled device prompt keeps the text safe in the inbox', () async {
    node.eventFailure = const FactsBookException('device_auth_cancelled');
    final outcome = await controller.capture(
      const CaptureRequest(kind: CaptureKind.share, text: _line),
      rulesLook: true,
    );
    expect(outcome, isA<CaptureSavedAtNode>());
    expect(node.calls, contains('capture'));
  });

  test(
    'a share the owner did not sign is kept encrypted and no rule fires',
    () async {
      await node.postEvent(
        const TriggerSample(
          kind: TriggerSourceKind.share,
          text: _line,
          area: 'general',
          locale: 'en',
          sourceInstance: 'manual-share',
          messageKey: 'm-unsigned',
        ),
        idempotencyKey: 'k-unsigned',
      );
      final event = (await node.events()).last;
      expect(event.reason, TriggerReason.uncertain);
      expect(event.firings, isEmpty);
    },
  );

  test('a capture kept on the phone is not posted', () async {
    node.reachable = false;
    final outcome = await controller.capture(
      const CaptureRequest(kind: CaptureKind.share, text: _line),
      rulesLook: true,
    );
    expect(outcome, isA<CaptureKeptOnPhone>());
    expect(node.postedEvents, isEmpty);
  });

  factsTest('the Add something page shows no trace of the event', (
    tester,
  ) async {
    final n = FakeFactsBookGateway.withTriggers();
    await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: n);
    await tester.tap(find.byKey(const ValueKey('factsbook-capture-paste')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('factsbook-capture-field')),
      _line,
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('factsbook-capture-save')));
    await settle(tester);
    expect(n.postedEvents.single.kind, TriggerSourceKind.share);
    expect(n.postedClassified.single, isTrue);
    expect(find.textContaining('Saved.'), findsOneWidget);
    expect(find.textContaining('Library visit'), findsNothing);
  });

  group('over HTTP', () {
    test(
      'POST /v1/events carries the key and the kind; signed only when asked',
      () async {
        final adapter = NodeAdapter();
        final gateway = HttpFactsBookGateway(
          baseUrl: Uri.parse('http://127.0.0.1:8787'),
          token: 't',
          dio: Dio(BaseOptions(responseType: ResponseType.plain))
            ..httpClientAdapter = adapter,
        );
        final event = jsonDecode(
          '{"id":"evt_00000000000000000000000006","revision":1,'
          '"source":{"client_id":"cli_00000000000000000000000001",'
          '"kind":"share","instance":"manual-share"},"message_key":"m",'
          '"claims":{},"trust":"third_party_untrusted","area":"general",'
          '"sens":"normal","captured_at":"2026-10-11T09:00:00Z",'
          '"occurred_at":"2026-10-11T09:00:00Z","content_digest":"0",'
          '"evidence_ref":"itm_00000000000000000000000006",'
          '"processing":{"state":"evaluated","reason":"matched",'
          '"policy_version":1,"at":"2026-10-11T09:00:00Z"},"firings":[]}',
        );
        adapter.reply('POST /v1/events', {
          'status': 'accepted',
          'event': event,
        });
        final result = await gateway.postEvent(
          const TriggerSample(
            kind: TriggerSourceKind.share,
            text: _line,
            area: 'general',
            locale: 'en',
            sourceInstance: 'manual-share',
            messageKey: 'msg-abc',
          ),
          idempotencyKey: 'evt-abc',
        );
        expect(result.reason, TriggerReason.matched);
        final call = adapter.calls.single;
        expect(call.headers['Idempotency-Key'], 'evt-abc');
        final body = (call.body! as Map).cast<String, Object?>();
        expect(body['kind'], 'share');
        expect(body['source_instance'], 'manual-share');
        expect(body['message_key'], 'msg-abc');
        expect(body['revision'], 1);
        expect(body.containsKey('proof'), isFalse);
      },
    );
  });
}
