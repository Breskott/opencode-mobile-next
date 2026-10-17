import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/codex/gateway.dart';
import 'package:opencode_mobile/codex/transport.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

class _Socket implements CodexSocket {
  final input = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, dynamic>>[];
  late void Function(Map<String, dynamic>) handler;
  bool closed = false;

  @override
  Stream<Object?> get messages => input.stream;

  @override
  void send(String message) {
    if (closed) throw StateError('closed');
    final request = jsonDecode(message) as Map<String, dynamic>;
    sent.add(request);
    handler(request);
  }

  void result(Object id, Map<String, dynamic> value) =>
      input.add(jsonEncode({'id': id, 'result': value}));

  void event(String method, Map<String, dynamic> params) =>
      input.add(jsonEncode({'method': method, 'params': params}));

  void reject(Object id) => input.add(
    jsonEncode({
      'id': id,
      'error': {
        'code': -32600,
        'message': 'Synthetic private remote detail sk-fixture-secret',
      },
    }),
  );

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await input.close();
  }
}

Map<String, dynamic> _turn({
  String id = 'turn-active',
  String status = 'inProgress',
}) => {'id': id, 'status': status, 'items': <Object>[]};

Map<String, dynamic> _thread({
  String cwd = '/project',
  bool busy = true,
  List<Object?>? turns,
}) => {
  'id': 'thread-1',
  'cwd': cwd,
  'name': 'Synthetic conversation',
  'createdAt': 100,
  'updatedAt': 101,
  'status': {'type': busy ? 'active' : 'idle'},
  'turns': turns ?? [_turn()],
};

class _Fixture {
  final socket = _Socket();
  var connectionAttempts = 0;
  late final transport = CodexTransport(
    endpoint: 'ws://127.0.0.1:4099',
    token: 'fixture-token',
    socketFactory: (_, _) async {
      connectionAttempts++;
      return socket;
    },
  );
  late final gateway = CodexGateway(
    transport: transport,
    directory: '/project',
  );
  Map<String, dynamic> thread = _thread();
  Map<String, dynamic> steerResult = {'turnId': 'turn-active'};
  bool rejectSteer = false;
  String? gatedMethod;
  final reachedGate = Completer<void>();
  void Function()? releaseGate;

  _Fixture() {
    socket.handler = (request) {
      final id = request['id'];
      if (id == null) return;
      final method = request['method'];
      final result = switch (method) {
        'initialize' => <String, dynamic>{'userAgent': 'codex/0.153.4'},
        'thread/read' ||
        'thread/resume' ||
        'thread/start' => <String, dynamic>{'thread': thread},
        'turn/start' => <String, dynamic>{'turn': _turn(id: 'turn-new')},
        'turn/steer' => steerResult,
        _ => <String, dynamic>{},
      };
      void respond() {
        if (method == 'turn/steer' && rejectSteer) {
          socket.reject(id);
        } else {
          socket.result(id, result);
        }
      }

      if (method == gatedMethod) {
        gatedMethod = null;
        releaseGate = respond;
        reachedGate.complete();
      } else {
        respond();
      }
    };
  }

  List<Map<String, dynamic>> requests(String method) =>
      socket.sent.where((r) => r['method'] == method).toList();

  void expectNoFallback() {
    expect(requests('turn/start'), isEmpty);
    expect(requests('turn/interrupt'), isEmpty);
  }
}

Matcher _failure(CodexFailureKind kind) =>
    throwsA(isA<CodexFailure>().having((error) => error.kind, 'kind', kind));

void main() {
  test(
    'explicit steer targets authoritative active turn without resuming',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.gateway.close);
      expect(fixture.gateway.capabilities.promptSteering, isTrue);
      expect(
        fixture.gateway.capabilities.withGenUi(true).promptSteering,
        isTrue,
      );
      expect(ServerCapabilities.allV1.promptSteering, isFalse);
      expect(fixture.gateway.midTurnPrompt('unknown'), isNull);

      await fixture.gateway.promptAsync(
        'thread-1',
        text: 'Keep the public API unchanged.',
        model: ModelRef(providerID: 'codex', modelID: 'gpt-6.1-sol'),
        variant: 'high',
        delivery: PromptDelivery.steer,
      );

      expect(fixture.requests('thread/read').single['params'], {
        'threadId': 'thread-1',
        'includeTurns': true,
      });
      expect(fixture.requests('turn/steer').single['params'], {
        'threadId': 'thread-1',
        'expectedTurnId': 'turn-active',
        'input': [
          {
            'type': 'text',
            'text': 'Keep the public API unchanged.',
            'text_elements': <Object>[],
          },
        ],
      });
      expect(fixture.requests('thread/resume'), isEmpty);
      expect(fixture.gateway.midTurnPrompt('thread-1'), isNull);
      await fixture.gateway.session('thread-1');
      expect(
        fixture.gateway.midTurnPrompt('thread-1'),
        MidTurnPrompt.joinsTurn,
      );
      fixture.expectNoFallback();
    },
  );

  test(
    'default send while busy steers, while idle starts a new turn',
    () async {
      for (final busy in [true, false]) {
        final fixture = _Fixture()
          ..thread = _thread(
            busy: busy,
            turns: [_turn(status: busy ? 'inProgress' : 'completed')],
          );
        addTearDown(fixture.gateway.close);
        await fixture.gateway.messages('thread-1');
        await fixture.gateway.promptAsync('thread-1', text: 'Next instruction');
        expect(fixture.requests('turn/steer'), hasLength(busy ? 1 : 0));
        expect(fixture.requests('turn/start'), hasLength(busy ? 0 : 1));
        expect(fixture.requests('turn/interrupt'), isEmpty);
      }
    },
  );

  test(
    'explicit queue and unsupported attachments never dispatch input',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.gateway.close);
      await expectLater(
        fixture.gateway.promptAsync(
          'thread-1',
          text: 'Wait for later',
          delivery: PromptDelivery.queue,
        ),
        _failure(CodexFailureKind.unavailable),
      );
      await expectLater(
        fixture.gateway.promptAsync(
          'thread-1',
          text: 'Inspect attachment',
          delivery: PromptDelivery.steer,
          attachments: const [
            PromptAttachment(
              mime: 'text/plain',
              filename: 'fixture.txt',
              url: 'data:text/plain;base64,Zml4dHVyZQ==',
            ),
          ],
        ),
        _failure(CodexFailureKind.unavailable),
      );
      expect(fixture.requests('turn/steer'), isEmpty);
      fixture.expectNoFallback();
    },
  );

  test('missing or ambiguous running turn cannot become a new turn', () async {
    for (final turns in <List<Object?>>[
      [],
      [_turn(status: 'completed')],
      [_turn(), _turn(id: 'turn-another')],
    ]) {
      final fixture = _Fixture()..thread = _thread(turns: turns);
      addTearDown(fixture.gateway.close);
      await expectLater(
        fixture.gateway.promptAsync(
          'thread-1',
          text: 'Change direction',
          delivery: PromptDelivery.steer,
        ),
        _failure(CodexFailureKind.staleRequest),
      );
      expect(fixture.requests('turn/steer'), isEmpty);
      fixture.expectNoFallback();
    }
  });

  test(
    'changed running turn rejects stale input instead of steering its replacement',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.gateway.close);
      await fixture.gateway.messages('thread-1');
      fixture.thread = _thread(turns: [_turn(id: 'turn-replacement')]);
      await expectLater(
        fixture.gateway.promptAsync(
          'thread-1',
          text: 'Instruction for the old turn',
          delivery: PromptDelivery.steer,
        ),
        _failure(CodexFailureKind.staleRequest),
      );
      expect(fixture.requests('turn/steer'), isEmpty);
      fixture.expectNoFallback();
    },
  );

  test(
    'turn completed during preflight cannot receive stale steering',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.gateway.close);
      await fixture.gateway.messages('thread-1');
      fixture.gatedMethod = 'thread/read';
      final pending = fixture.gateway.promptAsync(
        'thread-1',
        text: 'Instruction for the completed turn',
        delivery: PromptDelivery.steer,
      );
      final checked = expectLater(
        pending,
        _failure(CodexFailureKind.staleRequest),
      );
      await fixture.reachedGate.future;
      fixture.socket.event('turn/completed', {
        'threadId': 'thread-1',
        'turn': _turn(status: 'completed'),
      });
      fixture.releaseGate!();
      await checked;
      expect(fixture.requests('turn/steer'), isEmpty);
      fixture.expectNoFallback();
    },
  );

  test(
    'foreign project and malformed active IDs fail before steering',
    () async {
      for (final thread in [
        _thread(cwd: '/other-project'),
        _thread(
          turns: [
            {..._turn(), 'id': ''},
          ],
        ),
        {..._thread(), 'id': 'thread-other'},
      ]) {
        final fixture = _Fixture()..thread = thread;
        addTearDown(fixture.gateway.close);
        await expectLater(
          fixture.gateway.promptAsync(
            'thread-1',
            text: 'Change direction',
            delivery: PromptDelivery.steer,
          ),
          throwsA(isA<CodexFailure>()),
        );
        expect(fixture.requests('turn/steer'), isEmpty);
        fixture.expectNoFallback();
      }
    },
  );

  test(
    'scope changes, including away and back, fence read and steer acknowledgement',
    () async {
      for (final method in ['thread/read', 'turn/steer']) {
        for (final returnToSource in [false, true]) {
          final fixture = _Fixture()..gatedMethod = method;
          addTearDown(fixture.gateway.close);
          final pending = fixture.gateway.promptAsync(
            'thread-1',
            text: 'Scoped instruction',
            delivery: PromptDelivery.steer,
          );
          final checked = expectLater(
            pending,
            _failure(
              method == 'thread/read'
                  ? CodexFailureKind.scopeMismatch
                  : CodexFailureKind.deliveryUnknown,
            ),
          );
          await fixture.reachedGate.future;
          fixture.gateway.setLocation(directory: '/other-project');
          if (returnToSource) {
            fixture.gateway.setLocation(directory: '/project');
          }
          fixture.releaseGate!();
          await checked;
          expect(
            fixture.requests('turn/steer'),
            hasLength(method == 'thread/read' ? 0 : 1),
          );
          expect(await fixture.gateway.sessionStatuses(), isEmpty);
          fixture.expectNoFallback();
        }
      }
    },
  );

  test(
    'disconnect during active-turn read cannot reconnect and mutate',
    () async {
      final fixture = _Fixture()..gatedMethod = 'thread/read';
      addTearDown(fixture.gateway.close);
      final pending = fixture.gateway.promptAsync(
        'thread-1',
        text: 'Change direction',
        delivery: PromptDelivery.steer,
      );
      final checked = expectLater(pending, throwsA(isA<CodexFailure>()));
      await fixture.reachedGate.future;
      await fixture.socket.close();
      await checked;
      expect(fixture.connectionAttempts, 1);
      expect(fixture.requests('turn/steer'), isEmpty);
      fixture.expectNoFallback();
    },
  );

  test(
    'remote rejection stays sanitized and never falls back to start',
    () async {
      final fixture = _Fixture()..rejectSteer = true;
      addTearDown(fixture.gateway.close);
      await expectLater(
        fixture.gateway.promptAsync(
          'thread-1',
          text: 'Change direction',
          delivery: PromptDelivery.steer,
        ),
        throwsA(
          isA<CodexFailure>()
              .having(
                (error) => error.kind,
                'kind',
                CodexFailureKind.unavailable,
              )
              .having(
                (error) => error.toString(),
                'safe copy',
                isNot(contains('sk-fixture-secret')),
              )
              .having(
                (error) => error.toString(),
                'safe detail',
                isNot(contains('private remote')),
              ),
        ),
      );
      expect(fixture.requests('turn/steer'), hasLength(1));
      fixture.expectNoFallback();
    },
  );

  test(
    'missing or mismatched acknowledgement blocks resend until reconciliation',
    () async {
      for (final result in <Map<String, dynamic>>[
        {},
        {'turnId': 'turn-other'},
      ]) {
        final fixture = _Fixture()..steerResult = result;
        addTearDown(fixture.gateway.close);
        for (var attempt = 0; attempt < 2; attempt++) {
          await expectLater(
            fixture.gateway.promptAsync(
              'thread-1',
              text: 'Change direction',
              delivery: PromptDelivery.steer,
            ),
            _failure(CodexFailureKind.deliveryUnknown),
          );
        }
        expect(fixture.requests('turn/steer'), hasLength(1));
        fixture.expectNoFallback();
      }
    },
  );

  test(
    'lost steer acknowledgement blocks resend without reconnecting',
    () async {
      final fixture = _Fixture()..gatedMethod = 'turn/steer';
      addTearDown(fixture.gateway.close);
      final pending = fixture.gateway.promptAsync(
        'thread-1',
        text: 'Change direction',
        delivery: PromptDelivery.steer,
      );
      final checked = expectLater(
        pending,
        _failure(CodexFailureKind.deliveryUnknown),
      );
      await fixture.reachedGate.future;
      await fixture.socket.close();
      await checked;
      await expectLater(
        fixture.gateway.promptAsync(
          'thread-1',
          text: 'Change direction',
          delivery: PromptDelivery.steer,
        ),
        _failure(CodexFailureKind.deliveryUnknown),
      );
      expect(fixture.connectionAttempts, 1);
      expect(fixture.requests('turn/steer'), hasLength(1));
      fixture.expectNoFallback();
    },
  );

  test('completion before steer acknowledgement remains idle', () async {
    final fixture = _Fixture()..gatedMethod = 'turn/steer';
    addTearDown(fixture.gateway.close);
    await fixture.gateway.messages('thread-1');
    final pending = fixture.gateway.promptAsync(
      'thread-1',
      text: 'Change direction',
      delivery: PromptDelivery.steer,
    );
    await fixture.reachedGate.future;
    fixture.socket.event('turn/completed', {
      'threadId': 'thread-1',
      'turn': _turn(status: 'completed'),
    });
    fixture.releaseGate!();
    await pending;
    expect((await fixture.gateway.sessionStatuses())['thread-1'], 'idle');
    expect(fixture.requests('turn/steer'), hasLength(1));
    fixture.expectNoFallback();
  });
}
