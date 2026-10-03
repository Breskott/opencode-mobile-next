import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/return_brief.dart';
import 'package:opencode_mobile/domain/while_away.dart';

Session _session(
  String id,
  int? idle, {
  String? parent,
  bool archived = false,
}) => Session(
  id: id,
  parentID: parent,
  time: SessionTime(idle: idle, archived: archived ? 1 : null),
);

AutomaticAct _act(
  String id,
  int timestamp, {
  AutomaticActKind kind = AutomaticActKind.reconnect,
  bool acknowledged = false,
}) => AutomaticAct(
  id: id,
  locationKey: '/project',
  kind: kind,
  summary: 'Automatic action completed',
  occurredAt: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
  sessionId: 'session',
  acknowledged: acknowledged,
);

WhileAwaySnapshot _snapshot({
  Iterable<AutomaticAct> acts = const [],
  Iterable<Session> sessions = const [],
  bool known = true,
  bool partial = false,
  Set<String> busy = const {},
  Set<String> read = const {},
  Map<String, (ReturnBriefBlocker, String)> blockers = const {},
  ReturnBriefAck? acknowledgement,
}) => WhileAwaySnapshot.build(
  automaticActs: acts,
  sessions: sessions,
  readStateKnown: known,
  inventoryPartial: partial,
  isUnread: (session) => !read.contains(session.id),
  isBusy: busy.contains,
  blockerOf: (id) => blockers[id],
  acknowledgement: acknowledgement,
);

void main() {
  test('finished work contains only unread idle unblocked root sessions', () {
    final result = _snapshot(
      sessions: [
        _session('finished', 20),
        _session('busy', 30),
        _session('read', 40),
        _session('permission', 50),
        _session('question', 60),
        _session('form', 70),
        _session('child', 80, parent: 'finished'),
        _session('archived', 90, archived: true),
        _session('no-idle', null),
        _session('zero-idle', 0),
        _session('invalid-idle', -1),
      ],
      busy: {'busy'},
      read: {'read'},
      blockers: {
        'permission': (ReturnBriefBlocker.permission, 'p'),
        'question': (ReturnBriefBlocker.question, 'q'),
        'form': (ReturnBriefBlocker.form, 'f'),
      },
    );
    expect(result.finishedWork.map((run) => run.session.id), ['finished']);
    expect(result.finishedWork.single.idleAt, 20);
    expect(result.automaticActs, isEmpty);
    expect(result.isEmpty, isFalse);
  });

  test(
    'unknown read state retains actions without consulting unread state',
    () {
      final act = _act('reconnect', 30);
      final result = WhileAwaySnapshot.build(
        automaticActs: [act],
        sessions: [_session('finished', 20)],
        readStateKnown: false,
        inventoryPartial: true,
        isUnread: (_) =>
            throw StateError('Unknown read state must not be read'),
        isBusy: (_) => false,
        blockerOf: (_) => null,
      );
      expect(result.automaticActs, [act]);
      expect(result.finishedWork, isEmpty);
      expect(result.readStateKnown, isFalse);
      expect(result.inventoryPartial, isTrue);
      expect(result.isEmpty, isFalse);
    },
  );

  test(
    'all finished work is retained with deterministic newest-first order',
    () {
      final result = _snapshot(
        sessions: [
          _session('z', 20),
          _session('b', 30),
          _session('d', 40),
          _session('a', 30),
          _session('c', 10),
        ],
      );
      expect(result.finishedWork.map((run) => run.session.id), [
        'd',
        'a',
        'b',
        'z',
        'c',
      ]);
      expect(result.readStateKnown, isTrue);
      expect(result.inventoryPartial, isFalse);
    },
  );

  test(
    'acknowledgement hides only the exact finished run and recorded act',
    () {
      const acknowledgement = ReturnBriefAck(
        runs: {('done', 20), ('new-run', 20)},
        requestIDs: {'unrelated-request'},
      );
      final result = _snapshot(
        acts: [
          _act('acknowledged', 40, acknowledged: true),
          _act('unseen', 30),
        ],
        sessions: [
          _session('done', 20),
          _session('new-run', 21),
          _session('other', 20),
        ],
        acknowledgement: acknowledgement,
      );
      expect(result.automaticActs.map((act) => act.id), ['unseen']);
      expect(result.finishedWork.map((run) => run.session.id), [
        'new-run',
        'other',
      ]);
    },
  );

  test(
    'every automatic category remains an action even for a blocked session',
    () {
      final acts = [
        for (final kind in AutomaticActKind.values)
          _act(kind.name, 20, kind: kind),
      ];
      final result = _snapshot(
        acts: acts,
        sessions: [_session('session', 10)],
        blockers: {'session': (ReturnBriefBlocker.permission, 'request')},
      );
      expect(
        result.automaticActs.map((act) => act.kind).toSet(),
        AutomaticActKind.values.toSet(),
      );
      expect(result.finishedWork, isEmpty);
    },
  );

  test('snapshots sort actions and retain immutable copies of input lists', () {
    final acts = [_act('b', 20), _act('newer', 30), _act('a', 20)];
    final sessions = [_session('finished', 10)];
    final result = _snapshot(acts: acts, sessions: sessions);
    acts.clear();
    sessions.clear();
    expect(result.automaticActs.map((act) => act.id), ['newer', 'a', 'b']);
    expect(result.finishedWork, hasLength(1));
    expect(() => result.automaticActs.clear(), throwsUnsupportedError);
    expect(() => result.finishedWork.clear(), throwsUnsupportedError);
  });

  test(
    'copyWith records undo state without changing action identity or facts',
    () {
      final original = _act('act', 20);
      final undone = original.copyWith(undoAttempted: true, undone: true);
      final acknowledged = undone.copyWith(acknowledged: true);
      expect(original.acknowledged, isFalse);
      expect(original.undoAttempted, isFalse);
      expect(original.undone, isFalse);
      expect(acknowledged.acknowledged, isTrue);
      expect(acknowledged.undoAttempted, isTrue);
      expect(acknowledged.undone, isTrue);
      expect(acknowledged.id, original.id);
      expect(acknowledged.locationKey, original.locationKey);
      expect(acknowledged.kind, original.kind);
      expect(acknowledged.summary, original.summary);
      expect(acknowledged.occurredAt, original.occurredAt);
      expect(acknowledged.sessionId, original.sessionId);
      expect(acknowledged.copyWith(acknowledged: false).acknowledged, isFalse);
    },
  );

  test(
    'empty and acknowledged-only feeds report empty without inventing work',
    () {
      expect(_snapshot().isEmpty, isTrue);
      expect(_snapshot(known: false, partial: true).isEmpty, isTrue);
      expect(
        _snapshot(acts: [_act('seen', 20, acknowledged: true)]).isEmpty,
        isTrue,
      );
      expect(
        _snapshot(
          sessions: [_session('blocked', 20)],
          blockers: {'blocked': (ReturnBriefBlocker.question, 'q')},
        ).isEmpty,
        isTrue,
      );
    },
  );
}
