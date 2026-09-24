// The Servers drawings (design standard §10, motion slice B): the phone and
// the computer linking up while Add server checks the connection, the spark
// when they are paired, and the Servers welcome's hero. Each scene's finished
// frame is a golden in dark and light; the link loops only while linking.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/scenes/servers_link_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/servers_welcome_scene.dart';

Widget _frame(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: const ValueKey('scene'),
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  ),
);

void main() {
  tearDown(() => KitMotion.loops = false);

  group('goldens', () {
    for (final (name, theme) in [
      ('dark', AppTheme.dark()),
      ('light', AppTheme.light()),
    ]) {
      for (final state in ServersLinkState.values) {
        testWidgets('link ${state.name}, $name', (tester) async {
          await tester.pumpWidget(
            _frame(
              theme,
              KitIllustration(scene: ServersLinkScene(state), width: 280),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const ValueKey('scene')),
            matchesGoldenFile(
              'goldens/servers_scene_link_${state.name}_$name.png',
            ),
          );
        });
      }
      testWidgets('welcome, $name', (tester) async {
        await tester.pumpWidget(
          _frame(
            theme,
            const KitIllustration(scene: ServersWelcomeScene(), width: 240),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('scene')),
          matchesGoldenFile('goldens/servers_scene_welcome_$name.png'),
        );
      });
    }
  });

  testWidgets('the link moves only while linking, and only when allowed', (
    tester,
  ) async {
    KitMotion.loops = true;
    Future<bool> moves(ServersLinkState state, {bool reduce = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: KitIllustration(
              key: ValueKey('$state $reduce'),
              scene: ServersLinkScene(state),
              ambient: state == ServersLinkState.linking,
            ),
          ),
        ),
      );
      await tester.pump(KitMotion.entrance);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      final running = tester.hasRunningAnimations;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      return running;
    }

    expect(await moves(ServersLinkState.linking), isTrue);
    expect(await moves(ServersLinkState.linking, reduce: true), isFalse);
    for (final resting in [
      ServersLinkState.idle,
      ServersLinkState.linked,
      ServersLinkState.failed,
    ]) {
      expect(await moves(resting), isFalse, reason: resting.name);
    }
  });

  test('a changed state repaints the link', () {
    const idle = ServersLinkScene(ServersLinkState.idle);
    expect(idle.differs(const ServersLinkScene(ServersLinkState.idle)), false);
    expect(idle.differs(const ServersLinkScene(ServersLinkState.linked)), true);
  });
}
