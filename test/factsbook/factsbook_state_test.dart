// The hidden developer flag and the controller the screens share.
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_controller.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_flag.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'factsbook_test_support.dart';

void main() {
  group('the developer flag', () {
    test('is off by default and app-wide, not per profile', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(FactsBookFlag.read(prefs), isFalse);
      expect(FactsBookFlag.preferenceKey, 'oc.dev.factsbook');
    });

    test('turns on from the preference and off again', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await FactsBookFlag.write(prefs, true);
      expect(FactsBookFlag.read(prefs), isTrue);
      await FactsBookFlag.write(prefs, false);
      expect(FactsBookFlag.read(prefs), isFalse);
    });

    test('a provider scope with no connection reads as off', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(factsBookEnabledProvider), isFalse);
      expect(container.read(factsBookSessionProvider).paired, isFalse);
    });
  });

  group('FactsBookController', () {
    late FakeFactsBookGateway node;
    late FactsBookController controller;
    setUp(() {
      node = withClock(Clock.fixed(factsNow), FakeFactsBookGateway.sample);
      controller = FactsBookController(FactsBookSession.fixed(node));
    });
    tearDown(() => controller.dispose());

    test(
      'refresh reads status, review, the node queue and the newest things',
      () async {
        expect(controller.load, FactsBookLoad.idle);
        await withClock(Clock.fixed(factsNow), controller.refresh);
        expect(controller.load, FactsBookLoad.ready);
        expect(controller.review, hasLength(3));
        expect(controller.pending, hasLength(1));
        expect(controller.recent, hasLength(3));
        expect(controller.recent.first.title, 'Dentist');
        expect(controller.status?.module('storage').state, ModuleState.ok);
      },
    );

    test('needs you is derived: review and not saved, counted once', () async {
      await withClock(Clock.fixed(factsNow), controller.refresh);
      final items = controller.needsYou;
      expect(items.map((i) => i.kind), [
        NeedsYouKind.review,
        NeedsYouKind.notSaved,
      ]);
      expect(items.map((i) => i.count), [3, 1]);
      expect(items.last.since, isNotNull);
      expect(controller.needsYouCount, 4);
    });

    test('the 30-day list holds only the items that are due', () async {
      final old = FakeFactsBookGateway(
        pending: [
          CouldNotSaveEntry(
            id: 'cqs_A',
            reason: CouldNotSaveReason.nodeUnreachable,
            createdAt: factsNow.subtract(const Duration(days: 40)),
            promptDue: true,
          ),
          CouldNotSaveEntry(
            id: 'cqs_B',
            reason: CouldNotSaveReason.nodeUnreachable,
            createdAt: factsNow.subtract(const Duration(days: 2)),
          ),
        ],
      );
      final c = FactsBookController(FactsBookSession.fixed(old));
      addTearDown(c.dispose);
      await withClock(Clock.fixed(factsNow), c.refresh);
      expect(
        withClock(Clock.fixed(factsNow), () => c.dueForPrompt.map((e) => e.id)),
        ['cqs_A'],
      );
    });

    test(
      'a decision refetches; a stale one says so and shows the fresh list',
      () async {
        await withClock(Clock.fixed(factsNow), controller.refresh);
        final item = controller.review.first;
        await withClock(
          Clock.fixed(factsNow),
          () => controller.decide(item, ReviewDecision.approve),
        );
        expect(controller.review, hasLength(2));
        final next = controller.review.first;
        node.makeStale(next.id);
        await expectLater(
          withClock(
            Clock.fixed(factsNow),
            () => controller.decide(next, ReviewDecision.approve),
          ),
          throwsA(
            isA<FactsBookException>().having((e) => e.stale, 'stale', isTrue),
          ),
        );
        expect(controller.review.any((i) => i.id == next.id), isFalse);
      },
    );

    test(
      'a read that fails keeps the last copy and notes the failure',
      () async {
        await withClock(Clock.fixed(factsNow), controller.refresh);
        node.readsFail = true;
        await withClock(Clock.fixed(factsNow), controller.refresh);
        expect(controller.load, FactsBookLoad.ready);
        expect(controller.error?.code, 'node_unreachable');
        expect(controller.review, isNotEmpty);
      },
    );

    test('a first read that fails is a failed page', () async {
      node.readsFail = true;
      await withClock(Clock.fixed(factsNow), controller.refresh);
      expect(controller.load, FactsBookLoad.failed);
    });

    test('an unpaired session answers every call with unauthorized', () async {
      final c = FactsBookController(FactsBookSession.unpaired());
      addTearDown(c.dispose);
      expect(c.paired, isFalse);
      await c.refresh();
      expect(c.load, FactsBookLoad.failed);
      expect(c.error?.code, 'unauthorized');
    });

    test('notifies its listeners when it refreshes', () async {
      var heard = 0;
      controller.addListener(() => heard++);
      await withClock(Clock.fixed(factsNow), controller.refresh);
      expect(heard, greaterThanOrEqualTo(2));
    });
  });
}
