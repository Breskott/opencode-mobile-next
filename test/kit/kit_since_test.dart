// KitSince (docs/ux-system/kit-api/KitSince.md, C12): the kit's one wait
// timer. It rebuilds its host exactly once when a wait turns slow at
// KitMotion.escalateAfter (8 s), optionally once a minute after that, reads
// time through package:clock so the fake clock testWidgets already runs
// controls it (absorbs P7.6's "tests use a fake clock"), and draws nothing
// itself.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_effects.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_since.dart';

import 'kit_harness.dart';
import 'kit_motion_still.dart';

/// A minimal host: records every [KitSinceStatus] the builder is given and
/// draws nothing (a bare [KitSince] needs no ancestor to pump).
Widget _host({
  required DateTime? since,
  required ValueChanged<KitSinceStatus> onBuild,
  KitSinceTicks ticks = KitSinceTicks.none,
  VoidCallback? onEscalated,
}) => KitSince(
  since: since,
  ticks: ticks,
  onEscalated: onEscalated,
  builder: (context, status) {
    onBuild(status);
    return const SizedBox.shrink();
  },
);

void main() {
  kitMotionStillTests(
    'KitSince',
    builds: {
      'waiting': () => KitSince(
        since: DateTime(2026),
        builder: (context, status) => Text(status.phase.name),
      ),
    },
  );

  // 1. since = now escalates to slow at exactly 8 s, one rebuild for the
  // change.
  testWidgets('escalates to slow at exactly 8 s, rebuilding once', (
    tester,
  ) async {
    final since = clock.now();
    var builds = 0;
    KitSincePhase? phase;
    await tester.pumpWidget(
      _host(
        since: since,
        onBuild: (status) {
          builds++;
          phase = status.phase;
        },
      ),
    );
    expect(phase, KitSincePhase.waiting);
    final buildsAtStart = builds;

    await tester.pump(const Duration(milliseconds: 7900));
    expect(phase, KitSincePhase.waiting, reason: 'not slow yet at 7.9 s');
    expect(builds, buildsAtStart, reason: 'no rebuild before escalation');

    await tester.pump(const Duration(milliseconds: 100));
    expect(phase, KitSincePhase.slow, reason: 'slow at exactly 8.0 s');
    expect(builds, buildsAtStart + 1, reason: 'exactly one rebuild');
  });

  // 2. Already-old and future `since` values on the very first frame.
  testWidgets('a since 20 s in the past is slow on the first frame', (
    tester,
  ) async {
    final since = clock.now().subtract(const Duration(seconds: 20));
    KitSinceStatus? status;
    await tester.pumpWidget(_host(since: since, onBuild: (s) => status = s));
    expect(status!.phase, KitSincePhase.slow);
  });

  testWidgets('a since 5 s in the future is waiting with elapsed zero', (
    tester,
  ) async {
    final since = clock.now().add(const Duration(seconds: 5));
    KitSinceStatus? status;
    await tester.pumpWidget(_host(since: since, onBuild: (s) => status = s));
    expect(status!.phase, KitSincePhase.waiting);
    expect(status!.elapsed, Duration.zero);
  });

  // 3. since: null is idle, with nothing scheduled.
  testWidgets('since: null is idle, with no pending timer or callback', (
    tester,
  ) async {
    KitSinceStatus? status;
    await tester.pumpWidget(_host(since: null, onBuild: (s) => status = s));
    expect(status!.phase, KitSincePhase.idle);
    expect(status!.elapsed, Duration.zero);
    expect(tester.binding.transientCallbackCount, 0);
    // The framework's own postTest check fails the test if a Timer is
    // still pending after the widget tree is torn down; idle scheduling
    // nothing is what keeps that check clean here.
  });

  // 4. Changing `since` restarts the wait.
  testWidgets('a new since value restarts the wait', (tester) async {
    KitSinceStatus? status;
    await tester.pumpWidget(
      _host(since: clock.now(), onBuild: (s) => status = s),
    );
    await tester.pump(const Duration(seconds: 6));
    final restart = clock.now();
    await tester.pumpWidget(_host(since: restart, onBuild: (s) => status = s));
    expect(status!.phase, KitSincePhase.waiting, reason: 'restarted at 6 s');

    await tester.pump(const Duration(seconds: 7)); // 13 s on the outer clock
    expect(
      status!.phase,
      KitSincePhase.waiting,
      reason: 'still waiting at 13 s',
    );

    await tester.pump(const Duration(seconds: 1)); // 14 s on the outer clock
    expect(status!.phase, KitSincePhase.slow, reason: 'slow at 14 s');
  });

  // A ticks change alone measures the pending wait from `since`, not from
  // the status of the last build.
  testWidgets('changing only ticks mid-wait still turns slow at exactly 8 s', (
    tester,
  ) async {
    final since = clock.now();
    KitSinceStatus? status;
    await tester.pumpWidget(_host(since: since, onBuild: (s) => status = s));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(
      _host(
        since: since,
        ticks: KitSinceTicks.minutes,
        onBuild: (s) => status = s,
      ),
    );
    expect(status!.phase, KitSincePhase.waiting);

    await tester.pump(const Duration(milliseconds: 2900)); // 7.9 s
    expect(status!.phase, KitSincePhase.waiting, reason: 'not slow at 7.9 s');

    await tester.pump(const Duration(milliseconds: 100)); // 8.0 s
    expect(status!.phase, KitSincePhase.slow, reason: 'slow at exactly 8 s');
    expect(status!.elapsed, KitMotion.escalateAfter);
  });

  // 5. onEscalated fires exactly once per since, never for idle.
  testWidgets('onEscalated fires exactly once per since value', (tester) async {
    var escalations = 0;
    await tester.pumpWidget(
      _host(
        since: clock.now(),
        onBuild: (_) {},
        onEscalated: () => escalations++,
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(escalations, 1);

    await tester.pump(const Duration(minutes: 5));
    expect(escalations, 1, reason: 'no repeat while ticks is none');

    // A new since value is a new wait, which escalates once again.
    await tester.pumpWidget(
      _host(
        since: clock.now(),
        onBuild: (_) {},
        onEscalated: () => escalations++,
      ),
    );
    expect(escalations, 1, reason: 'the new wait is not slow yet');
    await tester.pump(const Duration(seconds: 8));
    expect(escalations, 2, reason: 'once for the new since value');

    await tester.pump(const Duration(minutes: 5));
    expect(escalations, 2, reason: 'still once per since value');
  });

  testWidgets('onEscalated never fires for an idle wait', (tester) async {
    var escalations = 0;
    await tester.pumpWidget(
      _host(since: null, onBuild: (_) {}, onEscalated: () => escalations++),
    );
    await tester.pump(const Duration(minutes: 5));
    expect(escalations, 0);
  });

  // 6. ticks: minutes rebuilds at 8 s, 60 s and 120 s; waitingLabel and
  // ageLabel on whole minutes, in en and ar.
  testWidgets('ticks: minutes rebuilds at 8 s, 60 s and 120 s', (tester) async {
    final elapsedAtBuild = <Duration>[];
    await tester.pumpWidget(
      _host(
        since: clock.now(),
        ticks: KitSinceTicks.minutes,
        onBuild: (status) => elapsedAtBuild.add(status.elapsed),
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 52)); // -> 60 s
    await tester.pump(const Duration(seconds: 60)); // -> 120 s

    expect(
      elapsedAtBuild,
      containsAllInOrder(const [
        Duration(seconds: 8),
        Duration(seconds: 60),
        Duration(seconds: 120),
      ]),
    );
  });

  testWidgets('waitingLabel and ageLabel on whole minutes (en)', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    expect(
      KitSince.waitingLabel(context, const Duration(seconds: 60)),
      'Waiting 1 min',
    );
    expect(
      KitSince.waitingLabel(context, const Duration(seconds: 120)),
      'Waiting 2 min',
    );
    expect(
      KitSince.ageLabel(context, const Duration(seconds: 40)),
      'less than a minute',
    );
    expect(KitSince.ageLabel(context, const Duration(seconds: 60)), '1 min');
    expect(KitSince.ageLabel(context, const Duration(minutes: 4)), '4 min');
  });

  // The numbers come from intl's number formatting for the locale
  // (COPY-30, B17), not from plain interpolation.
  testWidgets('the labels format their numbers with intl for the locale', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    expect(
      KitSince.waitingLabel(context, const Duration(minutes: 1234)),
      'Waiting 1,234 min',
    );
    expect(
      KitSince.ageLabel(context, const Duration(minutes: 1234)),
      '1,234 min',
    );
  });

  testWidgets(
    'waitingLabel covers the Arabic zero, one, two, few and many forms',
    (tester) async {
      final context = await pumpKitHost(tester, locale: const Locale('ar'));
      expect(
        KitSince.waitingLabel(context, Duration.zero),
        'جارٍ الانتظار منذ أقل من دقيقة',
      );
      expect(
        KitSince.waitingLabel(context, const Duration(minutes: 1)),
        'جارٍ الانتظار منذ دقيقة واحدة',
      );
      expect(
        KitSince.waitingLabel(context, const Duration(minutes: 2)),
        'جارٍ الانتظار منذ دقيقتين',
      );
      expect(
        KitSince.waitingLabel(context, const Duration(minutes: 3)),
        'جارٍ الانتظار منذ 3 دقائق',
      );
      expect(
        KitSince.waitingLabel(context, const Duration(minutes: 11)),
        'جارٍ الانتظار منذ 11 دقيقة',
      );
    },
  );

  // 7. Disposing mid-wait leaves no pending timer (the framework's own
  // postTest invariant fails the test otherwise).
  testWidgets('disposing mid-wait leaves no pending timer', (tester) async {
    await tester.pumpWidget(_host(since: clock.now(), onBuild: (_) {}));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 8. Reduced motion and Animations: Off do not change the timing, and
  // there is no ticker.
  testWidgets(
    'reduced motion and Animations: Off keep the same timing, with no ticker (G8)',
    (tester) async {
      final since = clock.now();
      KitSinceStatus? status;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: KitEffectsScope(
            effects: const KitEffects(motion: KitMotionLevel.off),
            child: _host(since: since, onBuild: (s) => status = s),
          ),
        ),
      );
      expect(status!.phase, KitSincePhase.waiting);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pump(const Duration(seconds: 8));
      expect(status!.phase, KitSincePhase.slow);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  // 9. statusOf(since, now:) matches the widget's phase rule at the
  // boundary.
  testWidgets('statusOf matches the phase rule at the 8 s boundary', (
    tester,
  ) async {
    final base = DateTime(2026, 1, 1, 12);
    expect(KitSince.statusOf(base, now: base).phase, KitSincePhase.waiting);
    expect(
      KitSince.statusOf(
        base,
        now: base.add(const Duration(milliseconds: 7999)),
      ).phase,
      KitSincePhase.waiting,
    );
    expect(
      KitSince.statusOf(
        base,
        now: base.add(const Duration(milliseconds: 8000)),
      ).phase,
      KitSincePhase.slow,
    );
    final skewed = KitSince.statusOf(
      base,
      now: base.subtract(const Duration(seconds: 1)),
    );
    expect(skewed.phase, KitSincePhase.waiting);
    expect(skewed.elapsed, Duration.zero, reason: 'clock skew clamps to zero');
  });

  // 10. Returning to the app recomputes the status, even if the escalation
  // timer never got to run (a suspended isolate would not run it).
  testWidgets(
    'resuming after backgrounded time recomputes the phase even with the '
    'timer suppressed',
    (tester) async {
      final since = clock.now();
      KitSinceStatus? status;
      await tester.pumpWidget(_host(since: since, onBuild: (s) => status = s));
      expect(status!.phase, KitSincePhase.waiting);

      // 30 s pass on the wall clock while the escalation Timer (scheduled
      // against the fake-async elapsed counter that drives real firing)
      // never elapses: a nested clock override moves `clock.now()` without
      // moving that counter, so the original Timer stays pending until the
      // resumed callback below cancels and replaces it.
      withClock(Clock(() => since.add(const Duration(seconds: 30))), () {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      // setState only schedules the rebuild; flush it without elapsing the
      // fake-async clock (a bare pump() does not call elapse), so the
      // still-pending original Timer does not get a chance to fire here.
      await tester.pump();
      expect(status!.phase, KitSincePhase.slow);
      expect(status!.elapsed, const Duration(seconds: 30));
    },
  );

  // 11. slowLabel uses KitMotion.escalateAfter, in en and ar.
  testWidgets('slowLabel gives the escalation words in en and ar', (
    tester,
  ) async {
    final en = await pumpKitHost(tester);
    expect(
      KitSince.slowLabel(en),
      'Still waiting after ${KitMotion.escalateAfter.inSeconds} s',
    );

    final ar = await pumpKitHost(tester, locale: const Locale('ar'));
    expect(
      KitSince.slowLabel(ar),
      'لا يزال الانتظار مستمرًا بعد ${KitMotion.escalateAfter.inSeconds} ث',
    );
  });
}
