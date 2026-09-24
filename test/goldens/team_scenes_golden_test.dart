// The AI Team's drawings (design standard §10, motion spec slice D): each
// scene's finished frame, dark and light, at 200 dp so the line work can be
// reviewed. In place they are smaller; the screen goldens
// (team_golden_test.dart) show them at their real size.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/team_scenes_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_illustration.dart';
import 'package:opencode_mobile/ui/kit/scenes/team_scenes.dart';

const _scenes = <String, KitScene>{
  'board': TeamBoardScene(),
  'planning': TeamPlanningScene(),
  'waking': TeamWakingScene(),
  'merged': TeamMergedScene(),
  'nudge': TeamNudgeScene(),
  'rest': TeamRestScene(),
  'idle': TeamIdleScene(),
};

void main() {
  for (final (mode, theme) in [
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final MapEntry(key: name, value: scene) in _scenes.entries) {
      testWidgets('team scene $name, finished, $mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('scene'),
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: KitIllustration(scene: scene, width: 200),
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
          matchesGoldenFile('team_scene_${name}_$mode.png'),
        );
      });
    }
  }
}
