// KitScenes v2 (docs/ux-system/kit-api/KitScenes.md): every colour a scene
// paints comes from ThemeRoles, no scene reaches for red or the attention
// amber, fills stay flat and light, RTL mirrors only where progress runs
// along a line, and a scene still settles under reduced motion. This file
// tests the mapping and the 24 scenes directly (no widget pumping except
// for the RTL and reduced-motion groups); kit_illustration_test.dart,
// kit_states_scenes_test.dart, servers_scenes_test.dart, setup_scenes_test.dart,
// motion_setup_test.dart, motion_states_test.dart and team_motion_test.dart
// keep covering the rest (TEST-19 (1)).
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/scenes/folders_open_scene.dart';
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
import 'package:opencode_mobile/ui/theme_packs.dart';

/// The 24 public scenes (KitScenes.md's "UNCHANGED public scenes" list),
/// one representative instance each.
const _scenes = <String, KitScene>{
  'KitPortalScene': KitPortalScene(),
  'KitFoldersOpenScene': KitFoldersOpenScene(),
  'ServersLinkScene': ServersLinkScene(ServersLinkState.idle),
  'ServersWelcomeScene': ServersWelcomeScene(),
  'SetupPhoneScene': SetupPhoneScene(),
  'SetupReadyScene': SetupReadyScene(),
  'SetupStepsScene': SetupStepsScene(
    stage: SetupSceneStage.download,
    done: 3,
    total: 5,
    fraction: .6,
  ),
  'SetupUnpluggedScene': SetupUnpluggedScene(),
  'StatesSheetScene': StatesSheetScene(),
  'StatesFolderScene': StatesFolderScene(),
  'StatesTrayScene': StatesTrayScene(),
  'StatesSearchScene': StatesSearchScene(),
  'StatesTerminalScene': StatesTerminalScene(),
  'StatesUnpluggedScene': StatesUnpluggedScene(),
  'StatesWorkingScene': StatesWorkingScene(),
  'TeamDiscoverTeaserScene': TeamDiscoverTeaserScene(),
  'TeamDiscoverRelayScene': TeamDiscoverRelayScene(),
  'TeamBoardScene': TeamBoardScene(),
  'TeamPlanningScene': TeamPlanningScene(),
  'TeamWakingScene': TeamWakingScene(),
  'TeamMergedScene': TeamMergedScene(),
  'TeamNudgeScene': TeamNudgeScene(),
  'TeamRestScene': TeamRestScene(),
  'TeamIdleScene': TeamIdleScene(),
};

/// The failed/halted variants KitScenes.md's test 2 also scans.
const _failureVariants = <String, KitScene>{
  'ServersLinkScene(failed)': ServersLinkScene(ServersLinkState.failed),
  'SetupStepsScene(halted: failed)': SetupStepsScene(
    stage: SetupSceneStage.download,
    done: 3,
    total: 5,
    fraction: .6,
    halted: SetupSceneHalt.failed,
  ),
  'SetupStepsScene(halted: paused)': SetupStepsScene(
    stage: SetupSceneStage.download,
    done: 3,
    total: 5,
    fraction: .6,
    halted: SetupSceneHalt.paused,
  ),
};

/// Scenes allowed to paint the attention amber ("needs you", LOOK-4). Empty:
/// no scene does after v2.
const _attentionAllowlist = <String, String>{};

/// graphiteDark, graphiteLight and one derived pack (Catppuccin), by name.
Map<String, ThemeRoles> get _packs => {
  'graphiteDark': graphiteDark,
  'graphiteLight': graphiteLight,
  'catppuccinDark': themePack(ThemePackId.catppuccin).dark.themeRoles,
};

KitSceneFrame _finished(ThemeRoles roles) => KitSceneFrame(
  entrance: 1,
  loop: 0,
  looping: false,
  palette: KitPalette.fromRoles(roles),
);

/// Records every paint colour a scene draws with (and every fill-style
/// paint, for the alpha check), without needing real canvas geometry.
class _PaintRecorder implements Canvas {
  final colors = <Color>[];
  final fills = <Paint>[];
  final flags = <String>[];

  void _capture(Paint paint) {
    colors.add(paint.color);
    if (paint.style == PaintingStyle.fill) fills.add(paint);
    if (paint.shader != null) flags.add('shader');
    if (paint.maskFilter != null) flags.add('maskFilter');
    if (paint.imageFilter != null) flags.add('imageFilter');
  }

  @override
  void drawPath(Path path, Paint paint) => _capture(paint);
  @override
  void drawCircle(Offset c, double radius, Paint paint) => _capture(paint);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _capture(paint);
  @override
  void drawRRect(RRect rrect, Paint paint) => _capture(paint);
  @override
  void drawRect(Rect rect, Paint paint) => _capture(paint);
  @override
  void drawOval(Rect rect, Paint paint) => _capture(paint);
  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => _capture(paint);
  @override
  void drawShadow(
    Path path,
    Color color,
    double elevation,
    bool transparentOccluder,
  ) => flags.add('shadow');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// True when [a] and [b] share the same hue (their RGB channels match,
/// whatever their alpha): a wash or a fade of a colour still counts.
bool _sameHue(Color a, Color b) => a.r == b.r && a.g == b.g && a.b == b.b;

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

typedef _Rgba = ({int width, int height, Uint8List bytes});

Future<_Rgba> _capture(
  WidgetTester tester,
  KitScene scene,
  TextDirection direction,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Directionality(
        textDirection: direction,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: KitIllustration(
              scene: scene,
              animateEntrance: false,
              width: 120,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final render = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(() => render.toImage(pixelRatio: 1)))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final out = (
    width: image.width,
    height: image.height,
    bytes: bytes.buffer.asUint8List(),
  );
  image.dispose();
  return out;
}

Uint8List _mirrorHorizontally(Uint8List src, int width, int height) {
  final out = Uint8List(src.length);
  for (var y = 0; y < height; y++) {
    final row = y * width * 4;
    for (var x = 0; x < width; x++) {
      final s = row + x * 4;
      final d = row + (width - 1 - x) * 4;
      out[d] = src[s];
      out[d + 1] = src[s + 1];
      out[d + 2] = src[s + 2];
      out[d + 3] = src[s + 3];
    }
  }
  return out;
}

/// The fraction of pixels that differ by more than a small per-channel
/// tolerance (anti-aliasing at a flipped edge need not be bit-identical).
double _diffFraction(Uint8List a, Uint8List b) {
  var diff = 0;
  final pixels = a.length ~/ 4;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > 12 ||
        (a[i + 1] - b[i + 1]).abs() > 12 ||
        (a[i + 2] - b[i + 2]).abs() > 12 ||
        (a[i + 3] - b[i + 3]).abs() > 12) {
      diff++;
    }
  }
  return pixels == 0 ? 0 : diff / pixels;
}

void main() {
  tearDown(() => KitMotion.loops = false);

  group('1. Mapping (KitPalette.fromRoles)', () {
    for (final MapEntry(key: name, value: roles) in _packs.entries) {
      test(name, () {
        final p = KitPalette.fromRoles(roles);
        expect(p.accent, roles.accent);
        expect(
          p.accentSoft,
          roles.accent.withValues(alpha: KitTokens.sceneWashAlpha),
        );
        expect(p.ink, roles.text1);
        expect(p.muted, roles.text2);
        expect(p.line, roles.text3);
        expect(p.surface, roles.surface3);
        expect(p.success, roles.success);
        expect(p.warning, roles.attention);
        expect(p.failure, roles.text1);
        expect(p.progress, roles.accent);
      });
    }

    test('KitPalette.of equals fromRoles(ThemeRoles.resolve(theme))', () {
      for (final theme in [
        AppTheme.dark(),
        AppTheme.light(),
        AppTheme.fromRoles(themePack(ThemePackId.catppuccin).dark.themeRoles),
      ]) {
        expect(
          KitPalette.of(theme),
          KitPalette.fromRoles(ThemeRoles.resolve(theme)),
        );
      }
    });
  });

  group('2. No red, no amber (LOOK-4, LOOK-5)', () {
    test('the allowlist starts empty', () {
      expect(_attentionAllowlist, isEmpty);
    });

    for (final MapEntry(key: packName, value: roles) in _packs.entries) {
      for (final MapEntry(key: name, value: scene) in {
        ..._scenes,
        ..._failureVariants,
      }.entries) {
        test('$name, $packName', () {
          final recorder = _PaintRecorder();
          scene.paint(recorder, _finished(roles));
          for (final c in recorder.colors) {
            if (!_attentionAllowlist.containsKey(name)) {
              expect(
                _sameHue(c, roles.attention),
                isFalse,
                reason: '$name ($packName) paints the attention amber: $c',
              );
            }
            expect(
              _sameHue(c, roles.danger),
              isFalse,
              reason: '$name ($packName) paints danger red: $c',
            );
          }
        });
      }
    }
  });

  group('3. Flat, light fills (LOOK-36)', () {
    for (final MapEntry(key: packName, value: roles) in _packs.entries) {
      for (final MapEntry(key: name, value: scene) in _scenes.entries) {
        test('$name, $packName', () {
          final recorder = _PaintRecorder();
          scene.paint(recorder, _finished(roles));
          expect(
            recorder.flags,
            isEmpty,
            reason:
                '$name ($packName): no Shader, MaskFilter, ImageFilter or '
                'shadow in a scene paint',
          );
          for (final paint in recorder.fills) {
            final c = paint.color;
            if (_sameHue(c, roles.accent) && c.a < 1.0) {
              expect(
                c.a,
                lessThanOrEqualTo(KitTokens.sceneWashAlpha + 1e-6),
                reason:
                    '$name ($packName): an accent wash must stay at or '
                    'under KitTokens.sceneWashAlpha (${KitTokens.sceneWashAlpha})',
              );
            }
          }
        });
      }
    }
  });

  test('4. Theme only: no Color(0x, no Colors., no colorScheme '
      '(LOOK-1, LOOK-2; C21 (e) exempts radius literals)', () {
    final files = [
      'lib/ui/kit/kit_illustration.dart',
      ...Directory('lib/ui/kit/scenes')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(Platform.pathSeparator, '/'))
          .where((p) => p.endsWith('.dart')),
    ]..sort();
    expect(files.length, greaterThanOrEqualTo(16));
    final forbidden = RegExp(r'Color\(0x|Colors\.|colorScheme');
    for (final path in files) {
      final code = File(path)
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        forbidden.hasMatch(code),
        isFalse,
        reason:
            '$path: every colour must come from ThemeRoles via KitPalette, '
            'never a literal or colorScheme',
      );
    }
  });

  group('5. Mirror (LAY-8)', () {
    testWidgets('a mirrorsInRtl scene under RTL equals its LTR render flipped '
        'horizontally', (tester) async {
      for (final scene in const [
        SetupStepsScene(stage: SetupSceneStage.start, done: 5, total: 6),
        ServersLinkScene(ServersLinkState.idle),
        TeamDiscoverRelayScene(),
      ]) {
        expect(scene.mirrorsInRtl, isTrue, reason: '${scene.runtimeType}');
        final ltr = await _capture(tester, scene, TextDirection.ltr);
        final rtl = await _capture(tester, scene, TextDirection.rtl);
        expect(rtl.width, ltr.width);
        expect(rtl.height, ltr.height);
        final mirrored = _mirrorHorizontally(ltr.bytes, ltr.width, ltr.height);
        final diff = _diffFraction(mirrored, rtl.bytes);
        expect(
          diff,
          lessThan(.02),
          reason:
              '${scene.runtimeType}: the RTL render should be the LTR '
              'render flipped horizontally ($diff differ)',
        );
      }
    });

    testWidgets('a scene without mirrorsInRtl renders identically under RTL', (
      tester,
    ) async {
      for (final scene in const [KitPortalScene(), TeamBoardScene()]) {
        expect(scene.mirrorsInRtl, isFalse, reason: '${scene.runtimeType}');
        final ltr = await _capture(tester, scene, TextDirection.ltr);
        final rtl = await _capture(tester, scene, TextDirection.rtl);
        final diff = _diffFraction(ltr.bytes, rtl.bytes);
        expect(
          diff,
          lessThan(.001),
          reason: '${scene.runtimeType}: RTL must match LTR ($diff differ)',
        );
      }
    });
  });

  group('6. Still (reduced motion, G8)', () {
    testWidgets('every scene settles after one pump under reduced motion', (
      tester,
    ) async {
      KitMotion.loops = true;
      for (final MapEntry(key: name, value: scene) in _scenes.entries) {
        await tester.pumpWidget(
          _host(KitIllustration(scene: scene, ambient: true), reduce: true),
        );
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse, reason: name);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
      'an ambient scene on a resting host does not loop when loops are not '
      'allowed',
      (tester) async {
        expect(KitMotion.loops, isFalse);
        for (final MapEntry(key: name, value: scene) in _scenes.entries) {
          await tester.pumpWidget(
            _host(KitIllustration(scene: scene, ambient: true)),
          );
          await tester.pumpAndSettle();
          expect(tester.hasRunningAnimations, isFalse, reason: name);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  });
}
