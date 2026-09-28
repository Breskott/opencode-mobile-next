import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _offline = KitStatus(
  kind: KitStatusKind.connection,
  icon: AppIconography.info,
  message: 'Connection lost',
);

void main() {
  testWidgets(
    'large status keeps its action and page reachable in a short room',
    (tester) async {
      var resets = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.5),
                disableAnimations: true,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 360,
                  height: 302,
                  child: KitStatusLineSlot(
                    status: KitStatus(
                      kind: KitStatusKind.info,
                      icon: AppIconography.info,
                      message: 'Simulated · nothing is saved',
                      action: KitAction(
                        key: const ValueKey('reset-demo'),
                        label: 'Reset demo',
                        onPressed: () => resets++,
                      ),
                    ),
                    child: const SizedBox(key: ValueKey('page-room')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('page-room'))).height,
        greaterThanOrEqualTo(181),
      );
      final reset = find.byKey(const ValueKey('reset-demo'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      expect(resets, 1);
      expect(tester.takeException(), isNull);
    },
  );

  // slice-P4.4: a page that is itself a condition (root-connecting's card
  // is the connection) omits it; the next condition down shows instead.
  testWidgets('omit drops app-wide conditions the page already says', (
    tester,
  ) async {
    const share = KitStatus(
      kind: KitStatusKind.work,
      icon: AppIconography.info,
      message: 'Share waits',
    );
    Widget host(Set<KitStatusKind> omit) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: KitStatusScope(
          conditions: ValueNotifier(const [_offline, share]),
          child: KitScreen(bodySays: omit, body: const SizedBox()),
        ),
      ),
    );
    await tester.pumpWidget(host(const {}));
    await tester.pumpAndSettle();
    expect(find.text('Connection lost'), findsOneWidget);
    expect(find.text('Share waits'), findsNothing);
    await tester.pumpWidget(host(const {KitStatusKind.connection}));
    await tester.pumpAndSettle();
    expect(find.text('Connection lost'), findsNothing);
    expect(find.text('Share waits'), findsOneWidget);
    expect(find.byType(KitStatusLine), findsOneWidget);
  });

  // B6 (emulator QA 2026-09-28): a page about something else (the phone's
  // own setup) keeps another server's connection line, but as one line:
  // the words and More, its action folded into More.
  testWidgets('bodyQuiets shows the condition as one line, action in More', (
    tester,
  ) async {
    var reconnects = 0;
    var details = 0;
    final notAnswering = KitStatus(
      kind: KitStatusKind.connection,
      icon: AppIconography.cloudOff,
      tone: AppStatusTone.failure,
      message: "Laptop isn't answering",
      supporting: 'Drafts wait here',
      action: KitAction(
        key: const ValueKey('reconnect'),
        label: 'Reconnect to Laptop',
        onPressed: () => reconnects++,
      ),
      more: [
        KitAction(
          key: const ValueKey('details'),
          label: 'Details',
          onPressed: () => details++,
        ),
      ],
    );
    Widget host({
      Set<KitStatusKind> says = const {},
      Set<KitStatusKind> quiets = const {},
    }) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: KitStatusScope(
          conditions: ValueNotifier([notAnswering]),
          child: KitScreen(
            bodySays: says,
            bodyQuiets: quiets,
            body: const SizedBox(),
          ),
        ),
      ),
    );

    // Any other page: the full line, its action in view.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reconnect')), findsOneWidget);
    expect(find.text('Drafts wait here'), findsOneWidget);

    // A page about something else: one line, the same truth.
    await tester.pumpWidget(host(quiets: const {KitStatusKind.connection}));
    await tester.pumpAndSettle();
    expect(find.text("Laptop isn't answering"), findsOneWidget);
    expect(find.byKey(const ValueKey('reconnect')), findsNothing);
    expect(find.text('Drafts wait here'), findsNothing);
    expect(find.byType(KitStatusLine), findsOneWidget);
    // The ways out are one tap away, the action first.
    await tester.tap(find.byKey(const ValueKey('kit-status-more')));
    await tester.pumpAndSettle();
    expect(find.text('Reconnect to Laptop'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Reconnect to Laptop')).dy,
      lessThan(tester.getTopLeft(find.text('Details')).dy),
    );
    await tester.tap(find.text('Reconnect to Laptop'));
    await tester.pumpAndSettle();
    expect(reconnects, 1);
    expect(details, 0);

    // bodySays wins over bodyQuiets: the page says it, so nothing repeats.
    await tester.pumpWidget(
      host(
        says: const {KitStatusKind.connection},
        quiets: const {KitStatusKind.connection},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Laptop isn't answering"), findsNothing);
  });

  test('KitStatus.compact keeps identity and folds the action first', () {
    final action = KitAction(label: 'Reconnect', onPressed: () {});
    final more = KitAction(label: 'Details', onPressed: () {});
    final status = KitStatus(
      kind: KitStatusKind.connection,
      id: 'connection:laptop',
      key: const ValueKey('line'),
      icon: AppIconography.cloudOff,
      tone: AppStatusTone.failure,
      message: 'Not answering',
      supporting: 'More words',
      next: 'Next words',
      since: DateTime(2026, 9, 28),
      action: action,
      more: [more],
    );
    final compact = status.compact();
    expect(compact.kind, status.kind);
    expect(compact.id, status.id);
    expect(compact.key, status.key);
    expect(compact.message, status.message);
    expect(compact.tone, status.tone);
    expect(compact.action, isNull);
    expect(compact.supporting, isNull);
    expect(compact.next, isNull);
    expect(compact.since, isNull);
    expect(compact.more, [action, more]);
  });

  kitMotionStillTests(
    'KitStatusLineSlot',
    builds: {
      'empty': () => const KitStatusLineSlot(),
      'connection lost': () => const KitStatusLineSlot(status: _offline),
    },
    changes: {
      'connection lost appears': KitMotionChange(
        build: () => const KitStatusLineSlot(),
        act: (tester, stage) =>
            stage.rebuild(const KitStatusLineSlot(status: _offline)),
        shows: 'Connection lost',
      ),
      'connection recovers': KitMotionChange(
        build: () => const KitStatusLineSlot(status: _offline),
        act: (tester, stage) => stage.rebuild(const KitStatusLineSlot()),
        hides: 'Connection lost',
      ),
    },
  );
  Widget contribution(KitStatus? status) => KitStatusLineSlot(
    child: KitStatusContribution(
      status: status,
      child: const Text('Screen content'),
    ),
  );
  kitMotionStillTests(
    'KitStatusContribution',
    builds: {
      'empty contribution': () => contribution(null),
      'connection lost contribution': () => contribution(_offline),
    },
    changes: {
      'contributed condition changes': KitMotionChange(
        build: () => contribution(null),
        act: (tester, stage) => stage.rebuild(contribution(_offline)),
        shows: 'Connection lost',
      ),
      'contributed condition clears': KitMotionChange(
        build: () => contribution(_offline),
        act: (tester, stage) => stage.rebuild(contribution(null)),
        hides: 'Connection lost',
      ),
    },
  );
}
