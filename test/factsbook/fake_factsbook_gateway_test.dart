// FakeFactsBookGateway: the node's behaviour the screens rely on, answering in
// the shapes of the contract with synthetic data only.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';

import 'factsbook_test_support.dart';

T _now<T>(T Function() body) => withClock(Clock.fixed(factsNow), body);

void main() {
  late FakeFactsBookGateway node;
  setUp(() => node = _now(FakeFactsBookGateway.sample));

  test(
    'search matches words; every hit has source date and provenance',
    () async {
      final result = await _now(() => node.search('dentist'));
      expect(result.hits, hasLength(2));
      for (final hit in result.hits) {
        expect(
          '${hit.title} ${hit.snippet}'.toLowerCase(),
          contains('dentist'),
        );
        expect(hit.factId, startsWith('f_'));
      }
      final dates = result.hits.map((h) => h.observedAt).toList();
      expect([...dates]..sort((a, b) => b.compareTo(a)), dates);
      expect(result.lockedNotesSkipped, isTrue);
      expect((await node.search('nothing like this')).hits, isEmpty);
      expect((await node.search('  ')).hits, isEmpty);
    },
  );

  test('every thing and fact has the fields the contract requires', () async {
    for (final thing in await node.things()) {
      expect(thing.id, matches(RegExp(r'^[a-z]{3}_[0-9A-Z]{26}$')));
      for (final fact in thing.facts) {
        expect(fact.id, matches(RegExp(r'^f_[0-9A-Z]{26}$')));
        expect(fact.thingId, thing.id);
        expect(fact.text, isNotEmpty);
      }
    }
    expect((await node.things(kind: ThingKind.card)).map((t) => t.title), [
      '[Bank A] Visa ••42',
    ]);
    await expectLater(
      node.thing('per_nope'),
      throwsA(isA<FactsBookException>()),
    );
  });

  test('every call fails like a lost connection when unreachable', () async {
    node.reachable = false;
    for (final call in <Future<Object?> Function()>[
      node.status,
      node.things,
      node.reviewItems,
      node.pendingCaptures,
      node.reminders,
      node.areas,
    ]) {
      await expectLater(
        call(),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.unreachable,
            'unreachable',
            isTrue,
          ),
        ),
      );
    }
  });

  group('capture', () {
    test('is saved once per idempotency key', () async {
      const request = CaptureRequest(
        kind: CaptureKind.note,
        text: 'Buy stamps. Today.',
      );
      final first = await node.capture(request, idempotencyKey: 'k1');
      final again = await node.capture(request, idempotencyKey: 'k1');
      expect(first.saved && again.saved, isTrue);
      expect(first.itemId, again.itemId);
      expect(
        (await node.things()).where((t) => t.title == 'Buy stamps'),
        hasLength(1),
      );
    });

    test('a locked-folder area is held by the node, with an entry', () async {
      final result = await node.capture(
        const CaptureRequest(
          kind: CaptureKind.note,
          text: 'Blood test',
          area: 'health',
        ),
        idempotencyKey: 'k2',
      );
      expect(result.saved, isFalse);
      final entry = (await node.pendingCaptures()).firstWhere(
        (e) => e.id == result.couldntSaveId,
      );
      expect(entry.reason, CouldNotSaveReason.keyLocked);
      expect(entry.itemId, result.itemId);
    });

    test(
      'retry saves what can be saved; a locked one stays and counts',
      () async {
        final result = await node.capture(
          const CaptureRequest(
            kind: CaptureKind.note,
            text: 'Blood test',
            area: 'health',
          ),
          idempotencyKey: 'k3',
        );
        final id = result.couldntSaveId!;
        final still = await node.retryCapture(id, idempotencyKey: 'r1');
        expect(still.saved, isFalse);
        expect(
          (await node.pendingCaptures()).firstWhere((e) => e.id == id).retries,
          1,
        );
        await node.discardCapture(id, idempotencyKey: 'd1');
        expect((await node.pendingCaptures()).any((e) => e.id == id), isFalse);
      },
    );

    test('an outbox batch: accepted, duplicate, refused', () async {
      final events = [
        const OutboxEvent(
          key: 'e1',
          payload: {'kind': 'note', 'text': 'one. a'},
        ),
        OutboxEvent(key: 'e2', payload: {'kind': 'note', 'text': 'x' * 200001}),
      ];
      final first = await node.sendOutbox(events);
      expect(first.map((r) => r.status), [
        OutboxReceiptStatus.accepted,
        OutboxReceiptStatus.refused,
      ]);
      final second = await node.sendOutbox([events.first]);
      expect(second.single.status, OutboxReceiptStatus.duplicate);
    });
  });

  group('review', () {
    test('lists only what waits; approve, reject and skip behave', () async {
      var items = await node.reviewItems();
      expect(items, hasLength(3));
      await node.decideReview(items[0], ReviewDecision.approve);
      await node.decideReview(items[1], ReviewDecision.reject);
      final skipped = await node.decideReview(items[2], ReviewDecision.skip);
      expect(skipped.status, 'skipped');
      items = await node.reviewItems();
      expect(items.map((i) => i.id), [items.single.id]);
    });

    test('an item that changed fails as stale and shows as stale', () async {
      final item = (await node.reviewItems()).first;
      node.makeStale(item.id);
      await expectLater(
        node.decideReview(item, ReviewDecision.approve),
        throwsA(
          isA<FactsBookException>().having((e) => e.stale, 'stale', isTrue),
        ),
      );
      expect((await node.reviewItems()).any((i) => i.id == item.id), isFalse);
    });
  });

  group('reminders', () {
    test('a preview is confirmable only with its own digest', () async {
      final preview = await node.previewReminder(
        what: 'Dentist',
        timing: ReminderTiming(
          repeat: ReminderRepeat.never,
          at: DateTime(2026, 10, 21, 10),
        ),
        zone: 'vault',
        locale: 'en',
      );
      expect(preview.confirmable, isTrue);
      expect(preview.at, DateTime(2026, 10, 21, 10));
      final tampered = ReminderPreview.fromJson({
        ...preview.raw,
        'what': 'Something else',
      });
      await expectLater(
        node.createReminder(tampered),
        throwsA(
          isA<FactsBookException>().having((e) => e.code, 'code', 'conflict'),
        ),
      );
      final made = await node.createReminder(preview);
      expect(made.revision, 1);
      expect((await node.reminders()).any((r) => r.id == made.id), isTrue);
    });

    test('pause and edit are based on the revision the person saw', () async {
      final reminder = (await node.reminders()).single;
      final paused = await node.setReminderPaused(reminder, paused: true);
      expect(paused.revision, 2);
      await expectLater(
        node.setReminderPaused(reminder, paused: false),
        throwsA(
          isA<FactsBookException>().having((e) => e.code, 'code', 'conflict'),
        ),
      );
      final current = (await node.reminders()).single;
      expect(current.paused, isTrue);
      final preview = await node.previewReminder(
        what: current.what,
        timing: ReminderTiming(
          repeat: ReminderRepeat.never,
          at: DateTime(2026, 11, 2, 8),
        ),
        zone: 'floating',
        locale: 'ar',
      );
      await node.updateReminder(current, preview);
      final edited = (await node.reminders()).single;
      expect(edited.schedule.when.once, DateTime(2026, 11, 2, 8));
      expect(edited.locale, 'ar');
      expect(edited.revision, 3);
    });
  });

  test('areas: built in, sharing can change', () async {
    final areas = await node.areas();
    expect(areas.map((a) => a.slug), ['family', 'money', 'health', 'work']);
    final money = areas.firstWhere((a) => a.slug == 'money');
    expect(
      money.sensitiveStorage && money.reviewFirst && !money.share.readByDefault,
      isTrue,
    );
    await node.setAreaShare(money, const AreaShare(readByDefault: true));
    expect(
      (await node.areas())
          .firstWhere((a) => a.slug == 'money')
          .share
          .readByDefault,
      isTrue,
    );
  });

  test(
    'status uses the canonical words and makes no claim of a backup',
    () async {
      final status = await _now(node.status);
      expect(status.module('cloud').state, ModuleState.absent);
      expect(status.safeInCloud, isFalse);
      expect(status.module('storage').state, ModuleState.ok);
    },
  );
}
