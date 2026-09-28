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
