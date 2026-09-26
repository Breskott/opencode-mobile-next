// KitScenes v2 gallery (docs/ux-system/kit-api/KitScenes.md): contact sheets
// of the 24 scenes' finished frames, grouped as the spec's §"Galleries
// required" lists them, plus the default page state (KitPortalScene above a
// title and a primary button) at every LAY-4 gallery size, in Arabic (the
// mirrored scenes' sheet and the default page) and at 2.0 text. The default
// page is built from kit parts (KitText, KitButton) on KitTokens spacing, and
// its Arabic shots carry Arabic copy, so they show the page right to left.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_scenes_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_illustration.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/scenes/folders_open_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/portal_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/servers_link_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/servers_welcome_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_phone_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_ready_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_steps_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_unplugged_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/states_scenes.dart';
import 'package:opencode_mobile/ui/kit/scenes/states_working_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/team_discover_scenes.dart';
import 'package:opencode_mobile/ui/kit/scenes/team_scenes.dart';

import 'kit_gallery.dart';

/// The seven contact-sheet groups (KitScenes.md's "Galleries required").
final _sheetGroups = <String, List<(KitScene, double)>>{
  'portal_folders': const [
    (KitPortalScene(), 100),
    (KitFoldersOpenScene(), 100),
  ],
  'states': const [
    (StatesSheetScene(), 88),
    (StatesFolderScene(), 88),
    (StatesTrayScene(), 88),
    (StatesSearchScene(), 88),
    (StatesTerminalScene(), 88),
    (StatesUnpluggedScene(), 88),
  ],
  'working': const [(StatesWorkingScene(), 64)],
  'setup': const [
    (SetupPhoneScene(), 130),
    (SetupReadyScene(), 130),
    (SetupUnpluggedScene(), 130),
    (
      SetupStepsScene(
        stage: SetupSceneStage.download,
        done: 3,
        total: 5,
        fraction: .6,
      ),
      170,
    ),
    (
      SetupStepsScene(
        stage: SetupSceneStage.download,
        done: 3,
        total: 5,
        fraction: .6,
        halted: SetupSceneHalt.failed,
      ),
      170,
    ),
  ],
  'servers': const [
    (ServersLinkScene(ServersLinkState.linking), 170),
    (ServersWelcomeScene(), 130),
  ],
  'team': const [
    (TeamBoardScene(), 110),
    (TeamPlanningScene(), 110),
    (TeamWakingScene(), 110),
    (TeamMergedScene(), 110),
    (TeamNudgeScene(), 110),
    (TeamRestScene(), 110),
    (TeamIdleScene(), 110),
  ],
  'team_discover': const [
    (TeamDiscoverTeaserScene(), 130),
    (TeamDiscoverRelayScene(), 170),
  ],
};

/// The three `mirrorsInRtl` scenes, shown together under RTL (the Arabic
/// "mirrored scenes' sheet").
const _mirrored = <(KitScene, double)>[
  (SetupStepsScene(stage: SetupSceneStage.start, done: 5, total: 6), 190),
  (ServersLinkScene(ServersLinkState.idle), 170),
  (TeamDiscoverRelayScene(), 170),
];

Widget _contactSheet(List<(KitScene, double)> scenes) => Builder(
  builder: (context) {
    final gap = KitTokens.of(context).space4;
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final (scene, width) in scenes)
          KitIllustration(scene: scene, width: width),
      ],
    );
  },
);

/// The default page's words, in English and in Arabic (test-only dressing:
/// scenes have no words of their own).
class _Copy {
  const _Copy({required this.title, required this.body, required this.action});

  final String title;
  final String body;
  final String action;
}

const _en = _Copy(
  title: 'No projects yet',
  body: 'Open a folder on studio-pc to start working with an agent.',
  action: 'Open a project',
);

const _ar = _Copy(
  title: 'لا توجد مشاريع بعد',
  body: 'افتح مجلدًا على studio-pc لتبدأ العمل مع وكيل.',
  action: 'افتح مشروعًا',
);

/// The default page state: `KitPortalScene` at `illustrationPage` above a
/// title and the one primary action, laid out from the start edge as a
/// page state is (so the Arabic shots mirror it).
Widget _defaultPage(_Copy copy) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: KitIllustration(
              scene: KitPortalScene(),
              width: KitTokens.illustrationPage,
              ambient: true,
            ),
          ),
          SizedBox(height: tokens.space5),
          KitText(copy.title, role: KitTextRole.title),
          SizedBox(height: tokens.space2),
          KitText(copy.body, tone: KitTextTone.secondary),
          SizedBox(height: tokens.space6),
          KitButton.primary(label: copy.action, onPressed: () {}),
        ],
      ),
    );
  },
);

void main() {
  setUpAll(loadKitGalleryFonts);

  group('contact sheets (412x915)', () {
    for (final MapEntry(key: group, value: scenes) in _sheetGroups.entries) {
      for (final light in [false, true]) {
        final name = kitGalleryName(
          'kit_scenes_$group',
          const Size(412, 915),
          light: light,
        );
        testWidgets(name, (tester) async {
          await kitGalleryPart(
            tester,
            name: name,
            size: const Size(412, 915),
            light: light,
            child: _contactSheet(scenes),
          );
        });
      }
    }
  });

  group('mirrored scenes, Arabic (LAY-8)', () {
    for (final size in kitGalleryScaledSizes) {
      final name = kitGalleryName(
        'kit_scenes_mirrored',
        size,
        light: false,
        ar: true,
      );
      testWidgets(name, (tester) async {
        await kitGalleryPart(
          tester,
          name: name,
          size: size,
          light: false,
          locale: const Locale('ar'),
          child: _contactSheet(_mirrored),
        );
      });
    }
  });

  group('default page state', () {
    for (final size in kitGallerySizes) {
      for (final light in [false, true]) {
        final name = kitGalleryName('kit_scenes_default', size, light: light);
        testWidgets(name, (tester) async {
          await kitGalleryPart(
            tester,
            name: name,
            size: size,
            light: light,
            child: _defaultPage(_en),
          );
        });
      }
    }

    group('Arabic', () {
      for (final size in kitGalleryScaledSizes) {
        final name = kitGalleryName(
          'kit_scenes_default',
          size,
          light: false,
          ar: true,
        );
        testWidgets(name, (tester) async {
          await kitGalleryPart(
            tester,
            name: name,
            size: size,
            light: false,
            locale: const Locale('ar'),
            child: _defaultPage(_ar),
          );
        });
      }
    });

    group('2.0 text', () {
      for (final size in kitGalleryScaledSizes) {
        final name = kitGalleryName(
          'kit_scenes_default',
          size,
          light: false,
          text2: true,
        );
        testWidgets(name, (tester) async {
          await kitGalleryPart(
            tester,
            name: name,
            size: size,
            light: false,
            textScale: 2,
            child: _defaultPage(_en),
          );
        });
      }
    });
  });
}
