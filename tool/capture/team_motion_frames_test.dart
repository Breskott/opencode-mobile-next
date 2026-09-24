// Frame strips of the AI Team's drawings (motion spec slice D,
// docs/design/motion-and-illustration-2026-09-25.md): each scene's
// entrance at 0, 20, 40, 60, 80 and 100 %, then, for the scenes that wait
// (planning, the team starting), three moments of the ambient loop. A
// still picture of the movement, dark and light, for review.
//
//   flutter test --concurrency=1 tool/capture/team_motion_frames_test.dart
//
// Output: docs/qa/motion-team-2026-09-25/frames-<scene>-<dark|light>.png
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_illustration.dart';
import 'package:opencode_mobile/ui/kit/scenes/team_scenes.dart';

import 'fixtures.dart';

const _out = 'docs/qa/motion-team-2026-09-25';

const _entrances = [0.0, .2, .4, .6, .8, 1.0];
const _loops = [.25, .5, .75];

final _scenes = <(String, KitScene, bool)>[
  ('board', const TeamBoardScene(), false),
  ('planning', const TeamPlanningScene(), true),
  ('waking', const TeamWakingScene(), true),
  ('merged', const TeamMergedScene(), false),
  ('nudge', const TeamNudgeScene(), false),
  ('rest', const TeamRestScene(), false),
  ('idle', const TeamIdleScene(), false),
];

class _Frame extends CustomPainter {
  _Frame(this.scene, this.frame);

  final KitScene scene;
  final KitSceneFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    final box = scene.box;
    final scale = math.min(size.width / box.width, size.height / box.height);
    canvas.save();
    canvas.translate(
      (size.width - box.width * scale) / 2,
      (size.height - box.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.clipRect(Offset.zero & box);
    scene.paint(canvas, frame);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Frame old) => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final (name, scene, ambient) in _scenes) {
      testWidgets('frames $name $mode', (tester) async {
        addTearDown(tester.view.reset);
        const cell = 150.0;
        final frames = [
          for (final e in _entrances) (e, 0.0, false),
          if (ambient)
            for (final l in _loops) (1.0, l, true),
        ];
        final height = cell * scene.box.height / scene.box.width;
        tester.view.physicalSize = Size(cell * frames.length + 16, height + 40);
        tester.view.devicePixelRatio = 1;
        final theme = captureTheme(light: light);
        final palette = KitPalette.of(theme);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      for (final (e, l, looping) in frames)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomPaint(
                              size: Size(cell, height),
                              painter: _Frame(
                                scene,
                                KitSceneFrame(
                                  entrance: e,
                                  loop: l,
                                  looping: looping,
                                  palette: palette,
                                ),
                              ),
                            ),
                            Text(
                              looping
                                  ? 'loop ${(l * 100).round()}%'
                                  : 'in ${(e * 100).round()}%',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await writePng(
          '$_out/frames-$name-$mode.png',
          await capturePng(tester, boundary, pixelRatio: 1.5),
        );
      });
    }
  }
}
