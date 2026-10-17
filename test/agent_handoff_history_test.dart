import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/agent_handoff_history.dart';
import 'package:opencode_mobile/domain/genui/gen_ui_history.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

final class _Gateway implements ServerGateway, GenUiHistoryGateway {
  @override
  String? directory = '/project';
  @override
  String? workspace = 'workspace';
  @override
  bool isClosed = false;

  final List<GenUiHistoryPage> pages;
  final List<String?> cursors = [];
  final List<int> limits = [];
  Future<void> Function()? beforeResponse;
  Object? error;
  int reads = 0;

  _Gateway(this.pages);

  @override
  Future<GenUiHistoryPage> genUiHistoryPage(
    String sessionID, {
    String? cursor,
    int limit = 50,
  }) async {
    cursors.add(cursor);
    limits.add(limit);
    final page = pages[reads++];
    await beforeResponse?.call();
    if (error case final Object failure) throw failure;
    return page;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnsupportedGateway implements ServerGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SnapshotGateway
    implements ServerGateway, AgentHandoffHistoryGateway {
  _SnapshotGateway(this.snapshot);
  final List<MessageWithParts> snapshot;
  @override
  String? directory = '/project';
  @override
  String? workspace;
  @override
  bool isClosed = false;
  @override
  Future<List<MessageWithParts>> agentHandoffHistory(String sessionID) async =>
      snapshot;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessageWithParts _message(
  String id, {
  String session = 'source',
  String? text,
}) => MessageWithParts(
  info: MessageInfo(id: id, sessionID: session, role: 'user'),
  parts: [Part(type: 'text', text: text ?? id)],
);

GenUiHistoryPage _page(
  List<MessageWithParts> items, {
  String? cursor,
  bool? more,
}) => GenUiHistoryPage(
  items: items,
  olderCursor: cursor,
  hasMore: more ?? cursor != null,
);

Matcher _failure(AgentHandoffHistoryFailureKind kind) =>
    isA<AgentHandoffHistoryFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  test(
    'complete snapshots preserve order and apply the common message budget',
    () async {
      final gateway = _SnapshotGateway(
        List.generate(51, (i) => _message('$i')),
      );
      final messages = await readAgentHandoffHistory(
        gateway,
        'source',
        isCurrent: () => true,
      );
      expect(messages.map((m) => m.info.id), List.generate(51, (i) => '$i'));
      expect(() => messages.clear(), throwsUnsupportedError);
      await expectLater(
        readAgentHandoffHistory(
          gateway,
          'source',
          isCurrent: () => true,
          maxPages: 1,
        ),
        throwsA(_failure(AgentHandoffHistoryFailureKind.pageLimit)),
      );
    },
  );

  test(
    'complete snapshots reject duplicate or foreign message identities',
    () async {
      for (final items in [
        [_message('same'), _message('same')],
        [_message('id', session: 'different')],
      ]) {
        await expectLater(
          readAgentHandoffHistory(
            _SnapshotGateway(items),
            'source',
            isCurrent: () => true,
          ),
          throwsA(_failure(AgentHandoffHistoryFailureKind.invalidMessage)),
        );
      }
    },
  );

  test(
    'prepends older pages, retaining newest copy of overlapping messages',
    () async {
      final gateway = _Gateway([
        _page([
          _message('c', text: 'new copy'),
          _message('d'),
        ], cursor: 'older'),
        _page([_message('a'), _message('b'), _message('c', text: 'old copy')]),
      ]);
      final messages = await readAgentHandoffHistory(
        gateway,
        'source',
        isCurrent: () => true,
      );
      expect(messages.map((m) => m.info.id), ['a', 'b', 'c', 'd']);
      expect(messages[2].parts.single.text, 'new copy');
      expect(gateway.cursors, [null, 'older']);
      expect(gateway.limits, [50, 50]);
      expect(() => messages.clear(), throwsUnsupportedError);
    },
  );

  test('snapshots part lists before fetching older pages', () async {
    final newest = _message('newest');
    final gateway = _Gateway([
      _page([newest], cursor: 'older'),
      _page([_message('oldest')]),
    ]);
    gateway.beforeResponse = () async {
      if (gateway.reads == 2) newest.parts.clear();
    };
    final messages = await readAgentHandoffHistory(
      gateway,
      'source',
      isCurrent: () => true,
    );
    expect(messages.last.parts.single.text, 'newest');
  });

  test('accepts complete empty history', () async {
    final gateway = _Gateway([_page([])]);
    expect(
      await readAgentHandoffHistory(gateway, 'source', isCurrent: () => true),
      isEmpty,
    );
  });

  test(
    'rejects empty session, unsupported reader and invalid budget',
    () async {
      expect(
        readAgentHandoffHistory(
          _UnsupportedGateway(),
          'source',
          isCurrent: () => true,
        ),
        throwsA(_failure(AgentHandoffHistoryFailureKind.unsupported)),
      );
      expect(
        readAgentHandoffHistory(
          _UnsupportedGateway(),
          ' ',
          isCurrent: () => true,
        ),
        throwsA(_failure(AgentHandoffHistoryFailureKind.invalidSession)),
      );
      expect(
        readAgentHandoffHistory(
          _Gateway([]),
          'source',
          isCurrent: () => true,
          maxPages: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  test('never returns partial history when the page budget expires', () async {
    final gateway = _Gateway([
      _page([_message('newest')], cursor: 'older'),
    ]);
    await expectLater(
      readAgentHandoffHistory(
        gateway,
        'source',
        isCurrent: () => true,
        maxPages: 1,
      ),
      throwsA(_failure(AgentHandoffHistoryFailureKind.pageLimit)),
    );
    expect(gateway.reads, 1);
  });

  for (final cursor in <String?>[null, '', ' ']) {
    test(
      'rejects missing/empty older cursor ${cursor == null ? 'null' : cursor.length}',
      () async {
        final gateway = _Gateway([
          _page([_message('newest')], cursor: cursor, more: true),
        ]);
        await expectLater(
          readAgentHandoffHistory(gateway, 'source', isCurrent: () => true),
          throwsA(_failure(AgentHandoffHistoryFailureKind.invalidCursor)),
        );
      },
    );
  }

  test('rejects cursor cycles', () async {
    final gateway = _Gateway([
      _page([_message('c')], cursor: 'one'),
      _page([_message('b')], cursor: 'two'),
      _page([_message('a')], cursor: 'one'),
    ]);
    await expectLater(
      readAgentHandoffHistory(gateway, 'source', isCurrent: () => true),
      throwsA(_failure(AgentHandoffHistoryFailureKind.invalidCursor)),
    );
  });

  for (final invalid in [
    _message(''),
    _message(' '),
    _message('id', session: 'foreign'),
  ]) {
    test(
      'rejects invalid message identity ${invalid.info.id}/${invalid.info.sessionID}',
      () async {
        final gateway = _Gateway([
          _page([invalid]),
        ]);
        await expectLater(
          readAgentHandoffHistory(gateway, 'source', isCurrent: () => true),
          throwsA(_failure(AgentHandoffHistoryFailureKind.invalidMessage)),
        );
      },
    );
  }

  test('rejects stale scope before reading', () async {
    final gateway = _Gateway([]);
    await expectLater(
      readAgentHandoffHistory(gateway, 'source', isCurrent: () => false),
      throwsA(_failure(AgentHandoffHistoryFailureKind.staleScope)),
    );
    expect(gateway.reads, 0);
  });

  for (final change in ['profile', 'directory', 'workspace', 'closed']) {
    test('rejects $change change while a page is in flight', () async {
      final gate = Completer<void>();
      final gateway = _Gateway([
        _page([_message('newest')]),
      ]);
      gateway.beforeResponse = () => gate.future;
      var current = true;
      final future = readAgentHandoffHistory(
        gateway,
        'source',
        isCurrent: () => current,
      );
      final assertion = expectLater(
        future,
        throwsA(_failure(AgentHandoffHistoryFailureKind.staleScope)),
      );
      switch (change) {
        case 'profile':
          current = false;
        case 'directory':
          gateway.directory = '/other';
        case 'workspace':
          gateway.workspace = 'other';
        case 'closed':
          gateway.isClosed = true;
      }
      gate.complete();
      await assertion;
    });
  }

  test('transport errors become content-free failures', () async {
    final gateway = _Gateway([_page([])])
      ..error = StateError('sensitive-token-value');
    await expectLater(
      readAgentHandoffHistory(gateway, 'source', isCurrent: () => true),
      throwsA(
        allOf(
          _failure(AgentHandoffHistoryFailureKind.readFailed),
          predicate<Object>(
            (e) => !e.toString().contains('sensitive-token-value'),
          ),
        ),
      ),
    );
  });
}
