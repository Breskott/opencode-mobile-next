// The empty, quiet and failure drawings (design standard §10; spec
// docs/design/motion-and-illustration-2026-09-25.md, slice C): each one's
// finished frame in dark and light, the entrance that settles, the
// terminal's blink that ends lit, and the chat's working mark that loops
// only when asked and allowed.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/kit_states_scenes_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/scenes/states_scenes.dart';
import 'package:opencode_mobile/ui/kit/scenes/states_working_scene.dart';

const _scenes = <String, KitScene>{
  'sheet': StatesSheetScene(),
  'folder': StatesFolderScene(),
  'tray': StatesTrayScene(),
  'search': StatesSearchScene(),
  'terminal': StatesTerminalScene(),
  'terminal_ended': StatesTerminalScene(ended: true),
  'unplugged': StatesUnpluggedScene(),
  'working': StatesWorkingScene(),
};

/// Records every draw call's paint colour, to see whether a part is drawn.
class _Recorder implements Canvas {
  final colors = <int>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      colors.add(paint.color.toARGB32());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

KitSceneFrame _frame(
  double entrance, {
  bool looping = false,
  double loop = 0,
}) => KitSceneFrame(
  entrance: entrance,
  loop: loop,
  looping: looping,
  palette: KitPalette.of(AppTheme.dark()),
);

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  tearDown(() => KitMotion.loops = false);

  group('goldens (finished frame)', () {
    for (final MapEntry(key: name, value: scene) in _scenes.entries) {
      for (final (mode, theme) in [
        ('dark', AppTheme.dark()),
        ('light', AppTheme.light()),
      ]) {
        testWidgets('$name, $mode', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: const ValueKey('scene'),
                    child: ColoredBox(
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: KitIllustration(scene: scene),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const ValueKey('scene')),
            matchesGoldenFile('goldens/states_${name}_$mode.png'),
          );
        });
      }
    }
  });

  testWidgets('a resting drawing plays its entrance once and stops, even '
      'where loops may run', (tester) async {
    KitMotion.loops = true;
    await tester.pumpWidget(
      _host(const KitIllustration(scene: StatesTrayScene())),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(KitMotion.entrance);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the working mark loops while it is shown, only when allowed', (
    tester,
  ) async {
    KitMotion.loops = true;
    await tester.pumpWidget(
      _host(
        const KitIllustration(
          scene: StatesWorkingScene(),
          width: 28,
          ambient: true,
        ),
      ),
    );
    await tester.pump(KitMotion.entrance);
    await tester.pump(KitMotion.breath ~/ 3);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      _host(
        const KitIllustration(
          scene: StatesWorkingScene(),
          width: 28,
          ambient: true,
        ),
        reduce: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('the terminal cursor blinks while it arrives and ends lit', () {
    final accent = KitPalette.of(AppTheme.dark()).accent.toARGB32();
    bool cursorLit(KitSceneFrame frame) {
      final canvas = _Recorder();
      const StatesTerminalScene().paint(canvas, frame);
      return canvas.colors.contains(accent);
    }

    expect(cursorLit(_frame(.6)), isFalse, reason: 'not arrived yet');
    expect(cursorLit(_frame(.74)), isTrue);
    expect(cursorLit(_frame(.8)), isFalse, reason: 'first blink');
    expect(cursorLit(_frame(.93)), isFalse, reason: 'second blink');
    expect(cursorLit(_frame(1)), isTrue, reason: 'the finished frame is lit');
    // An ended shell has no live cursor.
    final ended = _Recorder();
    const StatesTerminalScene(ended: true).paint(ended, _frame(1));
    expect(ended.colors, isNot(contains(accent)));
  });

  test('a scene with data repaints when it changes', () {
    expect(
      const StatesTerminalScene().differs(
        const StatesTerminalScene(ended: true),
      ),
      isTrue,
    );
    expect(
      const StatesTerminalScene().differs(const StatesTerminalScene()),
      isFalse,
    );
  });
}
