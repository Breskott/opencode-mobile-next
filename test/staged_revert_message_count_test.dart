import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/session_slice_capabilities.dart';
import 'package:opencode_mobile/domain/staged_revert_message_count.dart';

class _Operations implements StagedRevertGateway {
  _Operations([this.prompt = '']);
  final String? prompt;

  @override
  Future<String?> sessionRevertPrompt(
    String sessionID,
    String messageID,
  ) async => prompt;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway implements ServerGateway {
  SessionRevert boundary = SessionRevert(messageID: 'prompt', snapshot: 'one');
  final pages = <String?, ServerPage<MessageWithParts>>{};
  final reads = <String?>[];
  void Function()? onPage;
  Object? failure;
  int sessionReads = 0;
  void Function()? onSession;

  @override
  ServerCapabilities capabilities = const ServerCapabilities();
  @override
  bool isClosed = false;

  @override
  Future<Session> session(String id) async {
    sessionReads++;
    onSession?.call();
    return Session(id: id, stagedRevert: boundary);
  }

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async {
    reads.add(cursor);
    onPage?.call();
    if (failure != null) throw failure!;
    return pages[cursor]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessageWithParts _row(
  String id, {
  String role = 'assistant',
  String session = 's',
}) => MessageWithParts(
  info: MessageInfo(id: id, sessionID: session, role: role),
);

Matcher _failure(StagedRevertCountFailure kind) => throwsA(
  isA<StagedRevertCountException>().having((e) => e.kind, 'kind', kind),
);

void main() {
  Future<StagedRevertMessageCount> count(
    _Gateway api, {
    bool Function()? current,
    int maxPages = 100,
    _Operations? operations,
  }) => api.countStagedRevertMessages(
    's',
    expected: api.boundary,
    operations: operations ?? _Operations(),
    isCurrent: current ?? () => true,
    maxPages: maxPages,
  );

  test(
    'counts all kinds across opaque pages and excludes the hidden prompt',
    () async {
      final api = _Gateway();
      api.pages[null] = ServerPage(
        items: [
          _row('system', role: 'system'),
          _row('answer'),
        ],
        nextCursor: 'opaque-next',
      );
      api.pages['opaque-next'] = ServerPage(
        items: [
          _row('old'),
          _row('prompt', role: 'user'),
          _row('synthetic', role: 'synthetic'),
          _row('system', role: 'system'),
        ],
      );
      final result = await count(api);
      expect(result.messagesAfterPrompt, 3);
      expect(result.totalMessages, 4);
      expect(api.reads, [null, 'opaque-next']);
      expect(api.sessionReads, 2);
    },
  );

  test(
    'a verified last prompt legitimately has zero following messages',
    () async {
      final api = _Gateway();
      api.pages[null] = ServerPage(items: [_row('prompt', role: 'user')]);
      expect((await count(api)).messagesAfterPrompt, 0);
    },
  );

  test('unknown coverage never becomes zero or a partial count', () async {
    final api = _Gateway();
    api.pages[null] = ServerPage(items: [_row('answer')]);
    await expectLater(
      count(api),
      _failure(StagedRevertCountFailure.incomplete),
    );
    api.pages[null] = ServerPage(items: [_row('prompt')]);
    await expectLater(
      count(api),
      _failure(StagedRevertCountFailure.incomplete),
    );
    api.pages[null] = ServerPage(
      items: [_row('prompt', role: 'user', session: 'other')],
    );
    await expectLater(
      count(api),
      _failure(StagedRevertCountFailure.incomplete),
    );
    api.pages[null] = ServerPage(items: [_row('answer')], nextCursor: 'loop');
    api.pages['loop'] = ServerPage(items: [_row('answer')], nextCursor: 'loop');
    await expectLater(
      count(api),
      _failure(StagedRevertCountFailure.incomplete),
    );
    await expectLater(
      count(api, maxPages: 1),
      _failure(StagedRevertCountFailure.incomplete),
    );
    api.boundary = SessionRevert(messageID: 'prompt', partID: 'part');
    await expectLater(
      count(api),
      _failure(StagedRevertCountFailure.incomplete),
    );
  });

  test(
    'synthetic rows projected as user are not accepted as the prompt',
    () async {
      final api = _Gateway();
      api.pages[null] = ServerPage(items: [_row('prompt', role: 'user')]);
      await expectLater(
        count(api, operations: _Operations(null)),
        _failure(StagedRevertCountFailure.incomplete),
      );
      expect(api.reads, isEmpty);
    },
  );

  test(
    'scope change or a changed remote boundary discards the count',
    () async {
      final api = _Gateway();
      api.pages[null] = ServerPage(items: [_row('prompt', role: 'user')]);
      var current = true;
      api.onPage = () => current = false;
      await expectLater(
        count(api, current: () => current),
        _failure(StagedRevertCountFailure.stale),
      );
      api.onPage = () =>
          api.boundary = SessionRevert(messageID: 'prompt', snapshot: 'two');
      await expectLater(count(api), _failure(StagedRevertCountFailure.stale));
      api.onPage = null;
      api.onSession = () =>
          api.boundary = SessionRevert(messageID: 'different');
      await expectLater(count(api), _failure(StagedRevertCountFailure.stale));
    },
  );

  test(
    'unsupported and closed connections do no history reads; errors are safe',
    () async {
      final api = _Gateway()
        ..capabilities = const ServerCapabilities(sessionRevert: false);
      await expectLater(
        count(api),
        _failure(StagedRevertCountFailure.unavailable),
      );
      expect(api.reads, isEmpty);
      api.capabilities = const ServerCapabilities();
      expect(api.canCountStagedRevertMessages(Object()), isFalse);
      api.isClosed = true;
      await expectLater(count(api), _failure(StagedRevertCountFailure.stale));
      expect(api.reads, isEmpty);
      api.isClosed = false;
      api.failure = StateError('private server response');
      await expectLater(count(api), _failure(StagedRevertCountFailure.failed));
    },
  );

  test(
    'infeasible session actions stay unavailable for every capability set',
    () {
      for (final caps in [
        const ServerCapabilities(),
        const ServerCapabilities(sessionRevert: false),
      ]) {
        expect(caps.sessionUnarchive, isFalse);
        expect(caps.sessionSummarySeed, isFalse);
        expect(caps.sessionCopyToDestination, isFalse);
        expect(caps.sessionMoveConflictDetails, isFalse);
      }
    },
  );
}
