import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/codex/gateway.dart';
import 'package:opencode_mobile/codex/transport.dart';
import 'package:opencode_mobile/domain/agent_handoff.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/agent_handoff_controller.dart';
import 'package:opencode_mobile/state/agent_handoff_links.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Socket implements CodexSocket {
  final input = StreamController<Object?>.broadcast(sync: true);
  final sent = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic>)? handler;
  bool closed = false;

  @override
  Stream<Object?> get messages => input.stream;

  @override
  void send(String message) {
    if (closed) throw StateError('closed');
    final request = jsonDecode(message) as Map<String, dynamic>;
    sent.add(request);
    handler?.call(request);
  }

  void result(Object id, Map<String, dynamic> value) =>
      input.add(jsonEncode({'id': id, 'result': value}));

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await input.close();
  }
}

Map<String, dynamic> _turn(int index, {String? userText}) => {
  'id': 'turn-$index',
  'status': 'completed',
  'itemsView': 'full',
  'startedAt': 100 + index * 2,
  'completedAt': 101 + index * 2,
  'items': [
    {
      'id': 'user-$index',
      'type': 'userMessage',
      'content': [
        {'type': 'text', 'text': userText ?? 'Prompt $index'},
      ],
    },
    {
      'id': 'tool-$index',
      'type': 'commandExecution',
      'command': 'dart analyze lib/parser.dart',
      'cwd': '/project',
      'status': 'completed',
      'exitCode': 0,
      'aggregatedOutput': 'Analysis passed $index',
    },
    {
      'id': 'agent-$index',
      'type': 'agentMessage',
      'phase': 'final_answer',
      'text': 'Answer $index',
    },
  ],
};

Map<String, dynamic> _thread(List<Object?> turns) => {
  'id': 'thread-source',
  'cwd': '/project',
  'name': 'Repair parser',
  'createdAt': 100,
  'updatedAt': 999,
  'historyMode': 'legacy',
  'model': 'gpt-6.1-sol',
  'status': {'type': 'idle'},
  'turns': turns,
};

class _Fixture {
  final socket = _Socket();
  late final transport = CodexTransport(
    endpoint: 'ws://127.0.0.1:4099',
    token: 'synthetic-transport-credential',
    socketFactory: (_, _) async => socket,
  );
  late final gateway = CodexGateway(
    transport: transport,
    directory: '/project',
  );
  Map<String, dynamic> thread = _thread([_turn(0)]);
  final readStarted = Completer<void>();
  Completer<void>? readGate;

  _Fixture() {
    socket.handler = (request) {
      final id = request['id'];
      if (id == null) return;
      if (request['method'] == 'initialize') {
        socket.result(id, {'userAgent': 'codex/0.153.4'});
      } else if (request['method'] == 'thread/read') {
        if (!readStarted.isCompleted) readStarted.complete();
        final result = <String, dynamic>{'thread': thread};
        if (readGate case final gate?) {
          unawaited(
            gate.future.then((_) {
              if (!socket.closed) socket.result(id, result);
            }),
          );
        } else {
          socket.result(id, result);
        }
      } else {
        socket.result(id, {});
      }
    };
  }

  Future<List<MessageWithParts>> read({bool Function()? isCurrent}) =>
      readAgentHandoffHistory(
        gateway,
        'thread-source',
        isCurrent: isCurrent ?? () => true,
      );

  List<Map<String, dynamic>> get reads => socket.sent
      .where((request) => request['method'] == 'thread/read')
      .toList();

  void expectReadOnly() {
    expect(
      socket.sent.map((request) => request['method']),
      everyElement(isIn(['initialize', 'initialized', 'thread/read'])),
    );
  }
}

// A domain-level Claude Code destination: real Paseo writer/dispatch coverage
// lives in paseo_agent_handoff_test.dart. Preparation must not mutate it.
class _ClaudeTarget implements ServerGateway, AgentHandoffTargetGateway {
  final mutations = <String>[];

  @override
  String get directory => '/project';
  @override
  String? get workspace => null;
  @override
  bool get isClosed => false;
  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(agentHandoffFiles: true);

  @override
  Future<ProvidersResponse> providers() async => ProvidersResponse(
    providers: [
      ProviderInfo(id: 'claude', name: 'Claude Code', modelIDs: ['opus']),
    ],
  );

  @override
  Future<String> writeAgentHandoff({
    required String directory,
    required String recordId,
    required String markdown,
  }) async {
    mutations.add('write');
    return '.handoff/$recordId/record.md';
  }

  @override
  Future<Session> createSession() async {
    mutations.add('create');
    return Session(id: 'target', directory: directory);
  }

  @override
  Future<void> promptAgentHandoff(
    String sessionID, {
    required String text,
    required ModelRef model,
    String? agent,
    String? variant,
    required void Function() beforeSend,
  }) async {
    beforeSend();
    mutations.add('prompt');
  }

  @override
  String handoffSessionId(String sessionID) => sessionID;
  @override
  String handoffNavigationSessionId(String sessionID) => sessionID;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'full persisted Codex thread is read once without resuming it',
    () async {
      final fixture = _Fixture()..thread = _thread(List.generate(30, _turn));
      addTearDown(fixture.gateway.close);
      final messages = await fixture.read();

      // Ninety persisted items exceed the generic paginated history page size.
      expect(messages, hasLength(90));
      expect(messages.first.info.id, 'user-0');
      expect(messages.last.info.id, 'agent-29');
      for (var index = 0; index < 30; index++) {
        expect(messages[index * 3].parts.single.text, 'Prompt $index');
        expect(messages[index * 3 + 1].parts.single.toolName, 'shell');
        expect(
          messages[index * 3 + 1].parts.single.toolState.output,
          'Analysis passed $index',
        );
        expect(messages[index * 3 + 2].parts.single.text, 'Answer $index');
      }
      expect(fixture.reads, hasLength(1));
      expect(fixture.reads.single['params'], {
        'threadId': 'thread-source',
        'includeTurns': true,
      });
      fixture.expectReadOnly();
    },
  );

  test('fully hydrated paginated Codex threads are accepted', () async {
    final fixture = _Fixture()
      ..thread = {
        ..._thread([_turn(0)]),
        'historyMode': 'paginated',
      };
    addTearDown(fixture.gateway.close);
    final messages = await fixture.read();
    expect(messages.map((message) => message.info.id), [
      'user-0',
      'tool-0',
      'agent-0',
    ]);
    fixture.expectReadOnly();
  });

  test('full snapshot still obeys the common history message budget', () async {
    final fixture = _Fixture()..thread = _thread(List.generate(30, _turn));
    addTearDown(fixture.gateway.close);
    await expectLater(
      readAgentHandoffHistory(
        fixture.gateway,
        'thread-source',
        isCurrent: () => true,
        maxPages: 1,
      ),
      throwsA(
        isA<AgentHandoffHistoryFailure>().having(
          (error) => error.kind,
          'kind',
          AgentHandoffHistoryFailureKind.pageLimit,
        ),
      ),
    );
    fixture.expectReadOnly();
  });

  test(
    'Codex record uses shared redaction and leaves server data intact',
    () async {
      const prompt = '  Fix this\n```dart\nparse("");\n```\nالعربية';
      const secret = 'synthetic-private-access-token';
      final turn = _turn(0, userText: prompt);
      final items = turn['items'] as List;
      (items[1] as Map)['aggregatedOutput'] =
          'api_key=$secret\nAnalysis passed';
      final fixture = _Fixture()..thread = _thread([turn]);
      addTearDown(fixture.gateway.close);
      final before = jsonEncode(fixture.thread);
      final messages = await fixture.read();
      final record = buildAgentHandoffRecord(
        session: Session(id: 'thread-source', directory: '/project'),
        messages: messages,
        lastState: 'Waiting for you',
      );
      expect(record.markdown, contains(prompt));
      expect(record.markdown, contains('Answer 0'));
      expect(record.markdown, contains('dart analyze lib/parser.dart'));
      expect(record.markdown, contains('Analysis passed'));
      expect(record.markdown, isNot(contains(secret)));
      expect(
        record.markdown,
        isNot(contains('synthetic-transport-credential')),
      );
      expect(record.redacted, isTrue);
      expect(jsonEncode(fixture.thread), before);
      expect(messages[1].parts.single.toolState.output, contains(secret));
      fixture.expectReadOnly();
    },
  );

  test(
    'Codex record drops oldest whole turns and preserves newest turn',
    () async {
      final fixture = _Fixture()
        ..thread = _thread([
          _turn(0, userText: List.filled(5000, 'old ').join()),
          _turn(1, userText: 'Newest exact prompt\nالعربية'),
        ]);
      addTearDown(fixture.gateway.close);
      final record = buildAgentHandoffRecord(
        session: Session(id: 'thread-source', directory: '/project'),
        messages: await fixture.read(),
        lastState: 'Waiting for you',
        maxBytes: 3000,
      );
      expect(record.omittedMessages, 3);
      expect(record.markdown, isNot(contains('Answer 0')));
      expect(record.markdown, contains('Newest exact prompt\nالعربية'));
      expect(record.markdown, contains('Answer 1'));
      expect(record.markdown, contains('Analysis passed 1'));
      expect(record.byteLength, lessThanOrEqualTo(3000));
    },
  );

  for (final malformed in <String, Map<String, dynamic> Function()>{
    'another thread': () => {
      ..._thread([_turn(0)]),
      'id': 'other-thread',
    },
    'another project': () => {
      ..._thread([_turn(0)]),
      'cwd': '/elsewhere',
    },
    'missing turns': () => _thread([_turn(0)])..remove('turns'),
    'malformed turns': () => {..._thread([]), 'turns': 'not-a-list'},
    'summary-only turns': () => _thread([
      {..._turn(0), 'itemsView': 'summary'},
    ]),
    'unloaded turns': () => _thread([
      {..._turn(0), 'itemsView': 'notLoaded'},
    ]),
    'missing item view': () => _thread([_turn(0)..remove('itemsView')]),
    'malformed item': () => _thread([
      {
        ..._turn(0),
        'items': ['not-an-item'],
      },
    ]),
    'repeated item ID': () => _thread([_turn(0), _turn(0)]),
  }.entries) {
    test('Codex handoff fails closed for ${malformed.key}', () async {
      final fixture = _Fixture()..thread = malformed.value();
      addTearDown(fixture.gateway.close);
      await expectLater(
        fixture.read(),
        throwsA(isA<AgentHandoffHistoryFailure>()),
      );
      fixture.expectReadOnly();
    });
  }

  test('project changes away and back invalidate an in-flight read', () async {
    final fixture = _Fixture()..readGate = Completer<void>();
    addTearDown(fixture.gateway.close);
    final pending = fixture.read();
    final assertion = expectLater(
      pending,
      throwsA(isA<AgentHandoffHistoryFailure>()),
    );
    await fixture.readStarted.future;
    fixture.gateway.setLocation(directory: '/elsewhere');
    fixture.gateway.setLocation(directory: '/project');
    fixture.readGate!.complete();
    await assertion;
    fixture.expectReadOnly();
  });

  test('caller selection changes invalidate an in-flight read', () async {
    final fixture = _Fixture()..readGate = Completer<void>();
    addTearDown(fixture.gateway.close);
    var current = true;
    final pending = fixture.read(isCurrent: () => current);
    final assertion = expectLater(
      pending,
      throwsA(
        isA<AgentHandoffHistoryFailure>().having(
          (error) => error.kind,
          'kind',
          AgentHandoffHistoryFailureKind.staleScope,
        ),
      ),
    );
    await fixture.readStarted.future;
    current = false;
    fixture.readGate!.complete();
    await assertion;
  });

  test(
    'disconnect invalidates an in-flight snapshot without resuming',
    () async {
      final fixture = _Fixture()..readGate = Completer<void>();
      addTearDown(fixture.gateway.close);
      final pending = fixture.read();
      final assertion = expectLater(
        pending,
        throwsA(isA<AgentHandoffHistoryFailure>()),
      );
      await fixture.readStarted.future;
      await fixture.socket.close();
      fixture.readGate!.complete();
      await assertion;
      fixture.expectReadOnly();
    },
  );

  test(
    'Codex source prepares a reviewable Claude draft without mutations',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles': jsonEncode([
          {'id': 'phone'},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final fixture = _Fixture()..thread = _thread(List.generate(30, _turn));
      addTearDown(fixture.gateway.close);
      final target = _ClaudeTarget();
      const scope = HandoffScope(
        profileId: 'phone',
        origin: HandoffOrigin.phoneAgent,
        directory: '/project',
        filesystemId: 'managed-linux',
      );
      final controller = AgentHandoffController(
        source: fixture.gateway,
        sourceScope: scope,
        sourceSessionId: 'thread-source',
        target: HandoffTarget(
          gateway: target,
          scope: scope,
          model: ModelRef(providerID: 'claude', modelID: 'opus'),
          label: 'Claude Code',
          agent: 'claude',
        ),
        links: AgentHandoffLinks.forPreferences(prefs),
        isCurrent: () => true,
        recordIdFactory: () => 'codex-review',
      );
      expect(controller.route(null), HandoffRoute.newConversation);
      final draft = await controller.prepare(lastState: 'Waiting for you');
      expect(controller.phase, AgentHandoffPhase.ready);
      expect(draft.record.markdown, contains('Prompt 0'));
      expect(draft.record.markdown, contains('Answer 29'));
      expect(draft.prompt, contains(draft.relativePath));
      expect(target.mutations, isEmpty);
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
      fixture.expectReadOnly();
    },
  );

  test(
    'Codex destination stays unavailable without a qualified file writer',
    () {
      final fixture = _Fixture();
      addTearDown(fixture.gateway.close);
      const scope = HandoffScope(
        profileId: 'phone',
        directory: '/project',
        filesystemId: 'managed-linux',
      );
      expect(fixture.gateway.capabilities.agentHandoffFiles, isFalse);
      expect(
        agentHandoffRoute(
          source: _ClaudeTarget(),
          sourceScope: scope,
          sourceModel: null,
          target: HandoffTarget(
            gateway: fixture.gateway,
            scope: scope,
            model: ModelRef(providerID: 'codex', modelID: 'gpt-6.1-sol'),
            label: 'Codex',
          ),
        ),
        HandoffRoute.unavailable,
      );
      expect(
        agentHandoffUnavailableReason(
          source: _ClaudeTarget(),
          sourceScope: scope,
          sourceModel: null,
          target: HandoffTarget(
            gateway: fixture.gateway,
            scope: scope,
            model: ModelRef(providerID: 'codex', modelID: 'gpt-6.1-sol'),
            label: 'Codex',
          ),
        ),
        HandoffUnavailableReason.safeFileWriterUnavailable,
      );
      expect(fixture.socket.sent, isEmpty);
    },
  );
}
