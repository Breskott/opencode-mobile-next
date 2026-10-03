import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/session_pins.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _DelayedPinStore extends InMemorySharedPreferencesStore {
  _DelayedPinStore() : super.withData({});

  Completer<bool>? pending;
  Completer<void>? entered;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    entered?.complete();
    final allowed = await (pending?.future ?? Future.value(true));
    if (!allowed) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scope memo preserves JSON encoding and separates every location', () {
    for (final pair in [
      (null, null),
      ('', null),
      (null, ''),
      ('/project', 'workspace'),
      ('/project/quoted"', 'workspace\\nested'),
      ('/other', 'workspace'),
    ]) {
      final key = SessionPinStore.scope(pair.$1, pair.$2);
      expect(jsonDecode(key), [pair.$1, pair.$2]);
      expect(identical(key, SessionPinStore.scope(pair.$1, pair.$2)), isTrue);
    }
    expect(SessionPinStore.scope('/project', null), '["/project",null]');
  });

  test(
    'cached pin sets are immutable snapshots across writes and forget',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final pins = SessionPinStore(preferences);
      final scope = SessionPinStore.scope('/project', null);
      final other = SessionPinStore.scope('/other', null);
      final empty = pins.ids('a', scope);
      expect(() => empty.add('forbidden'), throwsUnsupportedError);
      await pins.setPinned('a', scope, 'first', true);
      final first = pins.ids('a', scope);
      expect(identical(first, pins.ids('a', scope)), isTrue);
      expect(() => first.add('forbidden'), throwsUnsupportedError);
      await pins.setPinned('a', scope, 'second', true);
      expect(empty, isEmpty);
      expect(first, {'first'});
      expect(pins.ids('a', scope), {'first', 'second'});
      expect(pins.ids('b', scope), isEmpty);
      expect(pins.ids('a', other), isEmpty);
      await pins.setPinned('a', scope, 'first', false);
      expect(first, {'first'});
      expect(pins.ids('a', scope), {'second'});
      await preferences.remove('oc.sessionPins.a');
      final lastScope = SessionPinStore.scope('/project', null);
      pins.forget('a');
      final freshScope = SessionPinStore.scope('/project', null);
      expect(freshScope, lastScope);
      expect(identical(freshScope, lastScope), isFalse);
      expect(pins.ids('a', scope), isEmpty);
      expect(first, {'first'});
      await pins.setPinned('b', other, 'different', true);
      final reloaded = SessionPinStore(preferences);
      final restored = reloaded.ids('b', other);
      expect(restored, {'different'});
      expect(identical(restored, reloaded.ids('b', other)), isTrue);
      expect(() => restored.clear(), throwsUnsupportedError);
    },
  );

  test('pending and refused writes retain old visible pin snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = _DelayedPinStore();
    SharedPreferencesStorePlatform.instance = backend;
    final pins = SessionPinStore(await SharedPreferences.getInstance());
    await pins.setPinned('a', 'scope', 'saved', true);
    final before = pins.ids('a', 'scope');
    backend.pending = Completer<bool>();
    backend.entered = Completer<void>();
    final writing = pins.setPinned('a', 'scope', 'pending', true);
    await backend.entered!.future;
    expect(identical(pins.ids('a', 'scope'), before), isTrue);
    backend.pending!.complete(true);
    await writing;
    final saved = pins.ids('a', 'scope');
    expect(saved, {'saved', 'pending'});
    expect(before, {'saved'});
    backend.pending = Completer<bool>();
    backend.entered = Completer<void>();
    final refused = pins.setPinned('a', 'scope', 'refused', true);
    final failure = expectLater(refused, throwsStateError);
    await backend.entered!.future;
    backend.pending!.complete(false);
    await failure;
    expect(identical(pins.ids('a', 'scope'), saved), isTrue);
    backend.pending = null;
    backend.entered = null;
    await pins.setPinned('a', 'scope', 'recovered', true);
    expect(pins.ids('a', 'scope'), {'saved', 'pending', 'recovered'});
  });

  for (final count in [1000, 5000]) {
    testWidgets('Work pin allocation probe $count rows', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final pins = SessionPinStore(preferences);
      final tick = ValueNotifier(0);
      addTearDown(tick.dispose);
      String? previousKey;
      Set<String>? previousView;
      var keys = 0;
      var views = 0;
      var hits = 0;
      var builds = 0;
      var elapsed = 0;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: tick,
          builder: (context, child) {
            builds++;
            final clock = Stopwatch()..start();
            for (var i = 0; i < count; i++) {
              final key = SessionPinStore.scope('/project', 'workspace');
              final view = pins.ids('profile', key);
              if (!identical(key, previousKey)) keys++;
              if (!identical(view, previousView)) views++;
              previousKey = key;
              previousView = view;
              if (view.contains('session-$i')) hits++;
            }
            elapsed += clock.elapsedMicroseconds;
            return const SizedBox.shrink();
          },
        ),
      );
      for (var i = 0; i < 19; i++) {
        tick.value++;
        await tester.pump();
      }
      expect(builds, 20);
      expect(hits, 0);
      expect(keys, 1);
      expect(views, 1);
      // Allocation/rebuild counts are deterministic; elapsed time is a debug
      // widget-test workload measurement, not a release/device frame time.
      debugPrint(
        'PERF_WORK rows=$count builds=$builds scopeKeys=$keys '
        'pinViews=$views elapsedUs=$elapsed',
      );
    });

    testWidgets('Team board derivation probe $count items', (tester) async {
      final now = DateTime.utc(2026, 9, 28);
      final snapshot = OrchestrationSnapshot(
        work: List.generate(
          count,
          (i) => WorkItem(
            id: 'work-$i',
            title: 'Task $i',
            state: WorkState.queued,
            updatedAt: now.subtract(Duration(seconds: i)),
            raw: {'priority': i % 5, 'issue_type': 'task'},
          ),
        ),
        refreshedAt: now,
      );
      final tick = ValueNotifier(0);
      addTearDown(tick.dispose);
      final projections = HashSet<TeamBoard>.identity();
      var elapsed = 0;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: tick,
          builder: (context, child) {
            final clock = Stopwatch()..start();
            final board = buildTeamBoard(snapshot, now: now);
            elapsed += clock.elapsedMicroseconds;
            projections.add(board);
            expect(board.total, count);
            return const SizedBox.shrink();
          },
        ),
      );
      for (var i = 0; i < 19; i++) {
        tick.value++;
        await tester.pump();
      }
      debugPrint(
        'PERF_BOARD items=$count builds=20 projections=${projections.length} '
        'elapsedUs=$elapsed',
      );
    });
  }
}
