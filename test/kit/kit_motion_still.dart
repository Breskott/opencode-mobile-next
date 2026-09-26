// The reduced-motion check every kit part registers (gate G8x, STANDARDS
// MOT-7): under the system's "remove animations" AND under Settings ›
// Appearance › Animations: Off (KitEffects.motion), a part settles after
// one pump() with no ticker running, both when it first shows and after it
// changes state, and every drawing shows its finished frame.
//
// A kit part added after G8x registers its own samples from its own test
// file (test/kit/kit_<snake>_test.dart, NAME-1):
//
//   kitMotionStillTests('KitFoo', builds: {
//     'working': () => const KitFoo(working: true),
//   }, changes: {
//     // Required for a part that is stateful or animates a change.
//     'opens on press': KitMotionChange(
//       build: () => const KitFoo(),
//       act: (tester, stage) => stage.press(find.byType(KitRow)),
//       shows: 'Details',
//     ),
//   });
//
//   kitMotionStillTests('showKitFoo', opens: {
//     'default': KitMotionOpen(
//       (context) => showKitFoo(context, title: 'Rename'),
//       shows: 'Rename',
//     ),
//   }, changes: {
//     'dismissed': kitModalDismiss(
//       (context) => showKitFoo(context, title: 'Rename'),
//       shows: 'Rename',
//     ),
//   });
//
// A drawing (a KitScene) is sampled inside KitIllustration through
// [KitSceneProbe], which records the frame it was painted with.
//
// test/kit_motion_test.dart reads the G4 kit.dart manifest and fails for
// any exported part with no such registration, so kit units never edit it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

/// The two ways a person asks for stillness.
enum KitStill {
  /// The system's "remove animations" (MediaQuery.disableAnimations).
  system,

  /// Settings › Appearance › Animations: Off (KitEffects.motion).
  effectsOff,
}

/// The phone window every sample is pumped at.
const kitStillSize = Size(412, 915);

const _homeKey = ValueKey('kit-still-home');

/// One theme instance for every pump: a fresh AppTheme.dark() on a rebuild
/// would not compare equal and MaterialApp's AnimatedTheme would animate
/// between the two (the harness moving, not the part).
final _theme = AppTheme.dark();

/// An app around [home] with stillness asked for the [still] way only.
Widget kitStillApp(
  Widget home,
  KitStill still, {
  List<NavigatorObserver> observers = const [],
}) => KitEffectsScope(
  effects: still == KitStill.effectsOff
      ? const KitEffects(motion: KitMotionLevel.off)
      : KitEffects.defaults,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    navigatorObservers: observers,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: still == KitStill.system),
      child: child!,
    ),
    home: Scaffold(
      body: Center(key: _homeKey, child: home),
    ),
  ),
);

/// A modal sample: how to open it and a text it must show after one pump().
class KitMotionOpen {
  const KitMotionOpen(this.open, {required this.shows});

  final FutureOr<void> Function(BuildContext context) open;

  /// A text the modal shows, found and visible after one pump().
  final String shows;
}

/// What a change sample can do between its first frame and the check.
class KitMotionStage {
  KitMotionStage._(this._tester, this._still);

  final WidgetTester _tester;
  final KitStill _still;

  /// A context inside the app's home, below the navigator.
  BuildContext get context => _tester.element(find.byKey(_homeKey));

  /// Pumps [part] in place of the sample, still the same way (the frame
  /// in which the new configuration is built).
  Future<void> rebuild(Widget part) =>
      _tester.pumpWidget(kitStillApp(part, _still));

  /// Presses the control [finder] finds by calling its callback, as a tap
  /// would. A synthetic tap would also start Material's ink splash and
  /// highlight, framework feedback that ignores reduced motion and would
  /// hide the part's own motion behind it.
  Future<void> press(Finder finder) async {
    final control = _tester.widget(finder);
    final VoidCallback? callback = switch (control) {
      KitRow(:final onTap) => onTap,
      KitIconButton(:final onPressed) => onPressed,
      ButtonStyleButton(:final onPressed) => onPressed,
      InkWell(:final onTap) => onTap,
      _ => null,
    };
    expect(
      callback,
      isNotNull,
      reason: '${control.runtimeType} is not a pressable control',
    );
    callback!();
  }
}

/// A state-change sample: [build] is pumped and settled, [act] changes its
/// state (a tap, a drag, [KitMotionStage.rebuild] with a new configuration,
/// a pop), then one pump() must leave nothing running.
class KitMotionChange {
  const KitMotionChange({
    required this.build,
    required this.act,
    this.shows,
    this.hides,
  }) : assert(shows != null || hides != null, 'say what the change does');

  final Widget Function() build;
  final Future<void> Function(WidgetTester tester, KitMotionStage stage) act;

  /// A text found and visible after the change and one pump().
  final String? shows;

  /// A text gone after the change and one pump().
  final String? hides;
}

/// A dismissal sample for a `showKit…` opener: [open] it, let it settle,
/// pop it, then one pump() must leave it gone with nothing running.
KitMotionChange kitModalDismiss(
  FutureOr<void> Function(BuildContext context) open, {
  required String shows,
}) => KitMotionChange(
  build: () => const SizedBox.expand(),
  act: (tester, stage) async {
    unawaited(Future.sync(() => open(stage.context)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(shows), findsWidgets, reason: 'the modal never opened');
    Navigator.of(stage.context).pop();
  },
  hides: shows,
);

/// A [KitScene] that draws [scene] and records the frame it was painted
/// with, so a sample can assert the drawing shows its finished frame.
class KitSceneProbe extends KitScene {
  KitSceneProbe(this.scene);

  final KitScene scene;

  /// The frame of the last paint; null until painted.
  KitSceneFrame? painted;

  @override
  Size get box => scene.box;

  @override
  void paint(Canvas canvas, KitSceneFrame frame) {
    painted = frame;
    scene.paint(canvas, frame);
  }

  @override
  bool differs(covariant KitSceneProbe old) =>
      old.scene.runtimeType != scene.runtimeType || scene.differs(old.scene);
}

class _Pushes extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The home route is pushed when the app starts; count only later ones.
    if (previousRoute != null) count++;
  }
}

/// The ratchet (G8x): samples of parts that predate the gate and still move
/// under stillness today, as `<part> / <sample> / <still>`. It may only
/// shrink; test/kit_motion_test.dart holds the frozen set it must stay
/// inside, and a part added after the gate is never listed.
const kitMotionBaselinePath = 'test/kit_motion_baseline.json';

List<String>? _baselineCache;

/// The baselined samples, read once.
List<String> readKitMotionBaseline() => _baselineCache ??= [
  for (final e
      in (jsonDecode(File(kitMotionBaselinePath).readAsStringSync())
              as Map<String, dynamic>)['stillMoving']
          as List<dynamic>)
    e as String,
];

/// The baseline key of one sample.
String kitMotionKey(String part, String sample, KitStill still) =>
    '$part / $sample / ${still.name}';

/// Part → the sample names it registered in this isolate (filled as
/// [kitMotionStillTests] declares its tests), so the ratchet can check that
/// every baseline key names a real sample of that very part.
final kitMotionSamples = <String, Set<String>>{};

/// Checks what one pump() left: [problems] (text not shown, text not gone)
/// plus a running ticker. A sample not in the baseline must have none. A
/// baselined sample must still have one: when it has none it has been
/// fixed, and the test fails until its entry is removed (the ratchet only
/// shrinks, never keeps a stale entry).
void _expectStill(
  WidgetTester tester,
  KitStill still,
  String label,
  String key, [
  List<String> problems = const [],
]) {
  final all = [
    ...problems,
    if (tester.hasRunningAnimations)
      '${tester.binding.transientCallbackCount} frame callback(s) still '
          'scheduled: a ticker or animation is running after one pump()',
  ];
  final baseline = readKitMotionBaseline();
  if (baseline.contains(key)) {
    if (all.isEmpty) {
      fail(
        'G8x ratchet: "$key" now settles. Remove it from '
        '$kitMotionBaselinePath and from _frozenBaseline in '
        'test/kit_motion_test.dart; the lowered list is:\n'
        '${const JsonEncoder.withIndent('  ').convert({
          'stillMoving': [...baseline]..remove(key),
        })}',
      );
    }
    return;
  }
  expect(all, isEmpty, reason: '$label under ${still.name}');
}

String _typeName(Object o) => o.runtimeType.toString().split('<').first;

/// Expects the widget named [part] (or, for a drawing, a KitIllustration
/// painting it through a [KitSceneProbe]) in the tree, and every probed
/// drawing painted at its finished frame (MOT-7).
void _expectPartShown(WidgetTester tester, String part, String label) {
  if (part.startsWith('show')) return;
  final illustrations = tester
      .widgetList<KitIllustration>(find.byType(KitIllustration))
      .toList();
  final named = find.byWidgetPredicate((w) => _typeName(w) == part);
  final drawn = illustrations.any(
    (i) => i.scene is KitSceneProbe
        ? _typeName((i.scene as KitSceneProbe).scene) == part
        : false,
  );
  expect(
    named.evaluate().isNotEmpty || drawn,
    isTrue,
    reason:
        '$label renders no $part (a sample must pump the part it names; a '
        'drawing is sampled as KitIllustration(scene: KitSceneProbe(...)))',
  );
  for (final i in illustrations) {
    if (i.scene case final KitSceneProbe probe) {
      final frame = probe.painted;
      expect(frame, isNotNull, reason: '$label: the drawing never painted');
      expect(
        frame!.entrance,
        1,
        reason: '$label: the drawing is not at its finished frame',
      );
      expect(frame.looping, isFalse, reason: '$label: the drawing still loops');
    }
  }
}

/// Why [text] is not seen after one pump(): not found, off screen, or
/// under an opacity of 0 or an Offstage; null when it is visible.
String? _unseen(String text) {
  final found = find.text(text).evaluate();
  if (found.isEmpty) return '"$text" is not shown after one pump()';
  final screen = Offset.zero & kitStillSize;
  bool visible(Element element) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.overlaps(screen)) return false;
    for (RenderObject? r = box; r != null; r = r.parent) {
      if (r is RenderOpacity && r.opacity == 0) return false;
      if (r is RenderAnimatedOpacity && r.opacity.value == 0) return false;
      if (r is RenderOffstage && r.offstage) return false;
      if (r is RenderSliverOpacity && r.opacity == 0) return false;
    }
    return true;
  }

  return found.any(visible)
      ? null
      : '"$text" is off screen or at opacity 0 after one pump()';
}

void _sizeView(WidgetTester tester) {
  tester.view.physicalSize = kitStillSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps [build] still the [still] way and expects it shown and settled
/// after one pump(): no exception, the part in the tree, no running ticker.
Future<void> expectKitPartStill(
  WidgetTester tester,
  String part,
  Widget Function() build,
  KitStill still, {
  required String label,
  required String baselineKey,
}) async {
  _sizeView(tester);
  await tester.pumpWidget(kitStillApp(build(), still));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '$label threw');
  _expectPartShown(tester, part, label);
  _expectStill(tester, still, label, baselineKey);
  // Unmount so a part's own timers end with the test.
  await tester.pumpWidget(const SizedBox());
}

/// Opens a modal with [open] still the [still] way and expects it pushed,
/// showing its text visibly and settled after one pump().
Future<void> expectKitModalStill(
  WidgetTester tester,
  KitMotionOpen open,
  KitStill still, {
  required String label,
  required String baselineKey,
}) async {
  _sizeView(tester);
  final pushes = _Pushes();
  await tester.pumpWidget(
    kitStillApp(const SizedBox.expand(), still, observers: [pushes]),
  );
  final context = tester.element(find.byKey(_homeKey));
  unawaited(Future.sync(() => open.open(context)));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '$label threw');
  expect(
    pushes.count,
    greaterThan(0),
    reason: '$label pushed no route after one pump()',
  );
  _expectStill(tester, still, label, baselineKey, [?_unseen(open.shows)]);
  await tester.pumpWidget(const SizedBox());
}

/// Pumps [change]'s part, lets it settle, applies its act, and expects the
/// change shown and settled after one pump().
Future<void> expectKitChangeStill(
  WidgetTester tester,
  String part,
  KitMotionChange change,
  KitStill still, {
  required String label,
  required String baselineKey,
}) async {
  _sizeView(tester);
  await tester.pumpWidget(kitStillApp(change.build(), still));
  // The starting state may settle however it likes: only the change is
  // under test here (the mount is its own sample).
  await tester.pump(const Duration(seconds: 1));
  await change.act(tester, KitMotionStage._(tester, still));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '$label threw');
  _expectPartShown(tester, part, label);
  _expectStill(tester, still, label, baselineKey, [
    if (change.shows case final shows?) ?_unseen(shows),
    if (change.hides case final hides?
        when find.text(hides).evaluate().isNotEmpty)
      '"$hides" is still there after one pump()',
  ]);
  await tester.pumpWidget(const SizedBox());
}

/// Registers, for kit part [part] (its class or `showKit…` name, exactly as
/// kit.dart exports it), one test per sample and per [KitStill]:
/// [builds] are widgets pumped as they are, [opens] open a modal, and
/// [changes] change a part's state. Every stateful or animated part
/// registers at least one change.
void kitMotionStillTests(
  String part, {
  Map<String, Widget Function()> builds = const {},
  Map<String, KitMotionOpen> opens = const {},
  Map<String, KitMotionChange> changes = const {},
}) {
  assert(
    builds.isNotEmpty || opens.isNotEmpty,
    'kitMotionStillTests($part) needs at least one build or open sample',
  );
  final names = [...builds.keys, ...opens.keys, ...changes.keys];
  assert(
    names.toSet().length == names.length,
    'kitMotionStillTests($part) repeats a sample name',
  );
  (kitMotionSamples[part] ??= {}).addAll(names);
  group('$part (MOT-7)', () {
    for (final still in KitStill.values) {
      for (final MapEntry(key: name, value: build) in builds.entries) {
        testWidgets('$name settles at once under ${still.name}', (
          tester,
        ) async {
          await expectKitPartStill(
            tester,
            part,
            build,
            still,
            label: '$part $name',
            baselineKey: kitMotionKey(part, name, still),
          );
        });
      }
      for (final MapEntry(key: name, value: open) in opens.entries) {
        testWidgets('$name opens and settles at once under ${still.name}', (
          tester,
        ) async {
          await expectKitModalStill(
            tester,
            open,
            still,
            label: '$part $name',
            baselineKey: kitMotionKey(part, name, still),
          );
        });
      }
      for (final MapEntry(key: name, value: change) in changes.entries) {
        testWidgets('$name changes and settles at once under ${still.name}', (
          tester,
        ) async {
          await expectKitChangeStill(
            tester,
            part,
            change,
            still,
            label: '$part $name',
            baselineKey: kitMotionKey(part, name, still),
          );
        });
      }
    }
  });
}
