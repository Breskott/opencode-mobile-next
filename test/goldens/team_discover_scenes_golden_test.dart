// The AI Team's discovery drawings (design standard §10): each scene's
// finished frame, dark and light, at a size where the line work can be
// reviewed. In place the teaser is 64 dp wide on the Work tab and the relay
// is the intro's hero (team_discover_golden_test.dart shows them in place).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/team_discover_scenes_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_illustration.dart';
import 'package:opencode_mobile/ui/kit/scenes/team_discover_scenes.dart';

const _scenes = <String, (KitScene, double)>{
  'teaser': (TeamDiscoverTeaserScene(), 200),
  'relay': (TeamDiscoverRelayScene(), 320),
};

void main() {
  for (final (mode, theme) in [
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final MapEntry(key: name, value: (scene, width)) in _scenes.entries) {
      testWidgets('team discover scene $name, finished, $mode', (tester) async {
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
                      child: KitIllustration(scene: scene, width: width),
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
          matchesGoldenFile('team_discover_scene_${name}_$mode.png'),
        );
      });
    }
  }
}
