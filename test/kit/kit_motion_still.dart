// The reduced-motion check every kit part registers (gate G8x, STANDARDS
// MOT-7): under the system's "remove animations" AND under Settings ›
// Appearance › Animations: Off (KitEffects.motion), a part settles after
// one pump() with no ticker running.
//
// A kit part added after G8x registers its own samples from its own test
// file (test/kit/kit_<snake>_test.dart, NAME-1):
//
//   kitMotionStillTests('KitFoo', builds: {
//     'working': () => const KitFoo(working: true),
//   });
//
//   kitMotionStillTests('showKitFoo', opens: {
//     'default': (context) => showKitFoo(context, title: 'Rename'),
//   });
//
// test/kit_motion_test.dart reads the kit.dart manifest and fails for any
// exported part with no such registration, so kit units never edit it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
    theme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    navigatorObservers: observers,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: still == KitStill.system),
      child: child!,
    ),
    home: Scaffold(body: Center(child: home)),
  ),
);

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
/// shrink; a part added after the gate is never listed (it starts at zero).
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

String _running(WidgetTester tester) =>
    '${tester.binding.transientCallbackCount} frame callback(s) still '
    'scheduled: a ticker or animation is running after one pump()';

void _expectSettled(
  WidgetTester tester,
  KitStill still,
  String label,
  String? key,
) {
  final baseline = readKitMotionBaseline();
  if (key != null && baseline.contains(key)) {
    if (!tester.hasRunningAnimations) {
      // ignore: avoid_print
      print(
        'G8x ratchet: "$key" now settles. Lower $kitMotionBaselinePath '
        'to:\n${const JsonEncoder.withIndent('  ').convert({
          'stillMoving': [...baseline]..remove(key),
        })}',
      );
    }
    return;
  }
  expect(
    tester.hasRunningAnimations,
    isFalse,
    reason: '$label under ${still.name}: ${_running(tester)}',
  );
}

/// Pumps [part] still the [still] way and expects it settled after one
/// pump(): no exception and no running ticker.
Future<void> expectKitPartStill(
  WidgetTester tester,
  Widget part,
  KitStill still, {
  String label = 'part',
  String? baselineKey,
}) async {
  tester.view.physicalSize = kitStillSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(kitStillApp(part, still));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '$label threw');
  _expectSettled(tester, still, label, baselineKey);
  // Unmount so a part's own timers end with the test.
  await tester.pumpWidget(const SizedBox());
}

/// Opens a modal part with [open] still the [still] way and expects it
/// shown and settled after one pump().
Future<void> expectKitModalStill(
  WidgetTester tester,
  FutureOr<void> Function(BuildContext context) open,
  KitStill still, {
  String label = 'modal',
  String? baselineKey,
}) async {
  tester.view.physicalSize = kitStillSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  final pushes = _Pushes();
  await tester.pumpWidget(
    kitStillApp(
      Builder(
        builder: (inner) {
          context = inner;
          return const SizedBox.expand();
        },
      ),
      still,
      observers: [pushes],
    ),
  );
  unawaited(Future.sync(() => open(context)));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '$label threw');
  _expectSettled(tester, still, label, baselineKey);
  expect(
    pushes.count,
    greaterThan(0),
    reason: '$label pushed no route after one pump()',
  );
  await tester.pumpWidget(const SizedBox());
}

/// Registers, for kit part [part] (its class or `showKit…` name, exactly as
/// kit.dart exports it), one test per sample and per [KitStill]:
/// [builds] are widgets pumped as they are, [opens] open a modal.
void kitMotionStillTests(
  String part, {
  Map<String, Widget Function()> builds = const {},
  Map<String, FutureOr<void> Function(BuildContext context)> opens = const {},
}) {
  assert(
    builds.isNotEmpty || opens.isNotEmpty,
    'kitMotionStillTests($part) needs at least one sample',
  );
  group('$part (MOT-7)', () {
    for (final still in KitStill.values) {
      for (final MapEntry(key: name, value: build) in builds.entries) {
        testWidgets('$name settles at once under ${still.name}', (
          tester,
        ) async {
          await expectKitPartStill(
            tester,
            build(),
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
    }
  });
}
