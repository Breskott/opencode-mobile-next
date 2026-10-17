// Micro animations on state changes (owner 2026-10-14, MOT-1/MOT-5/MOT-7):
// a status tag, a row's trailing value, its count badge and its trailing
// mark change by cross-fading over KitMotion.quick, and are instant under
// reduced motion. With MICRO_STRIP_DIR set, the test also writes a frame
// strip (0, 50, 100, 200 ms) of each change for docs/qa.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

final _shot = GlobalKey();

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, w) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: w!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 360,
        child: RepaintBoundary(key: _shot, child: child),
      ),
    ),
  ),
);

class _Change {
  const _Change(this.name, this.before, this.after, this.old, this.next);
  final String name;
  final Widget before;
  final Widget after;

  /// Text of the old state / the new state.
  final String old;
  final String next;
}

final _changes = <_Change>[
  _Change(
    'status tag',
    const KitStatusTag(label: 'Running', tone: KitStatusTagTone.running),
    const KitStatusTag(label: 'Done', tone: KitStatusTagTone.done),
    'Running',
    'Done',
  ),
  _Change(
    'row value',
    const KitRow(title: 'Model', trailing: KitRowValue('Sonnet')),
    const KitRow(title: 'Model', trailing: KitRowValue('Opus')),
    'Sonnet',
    'Opus',
  ),
  _Change(
    'row count badge',
    const KitRow(title: 'Kept', trailing: KitRowValue.count(0, 'none')),
    const KitRow(title: 'Kept', trailing: KitRowValue.count(3, '3 kept')),
    '',
    '3',
  ),
  _Change(
    'row trailing mark',
    const KitRow(title: 'Sync', trailing: Text('Waiting')),
    const KitRow(title: 'Sync', trailing: Icon(Icons.check)),
    'Waiting',
    '',
  ),
];

/// Fade layers inside the shot: one per settled swap, more while two states
/// cross.
int _fades() => find
    .descendant(of: find.byKey(_shot), matching: find.byType(FadeTransition))
    .evaluate()
    .length;

/// The fade layers of [c]'s end state, standing alone.
Future<int> _settledFades(WidgetTester tester, _Change c) async {
  await tester.pumpWidget(_app(c.after));
  await tester.pumpAndSettle();
  return _fades();
}

Future<void> _writeFrame(WidgetTester tester, String dir, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final strip = Platform.environment['MICRO_STRIP_DIR'];
  for (final c in _changes) {
    testWidgets('${c.name} cross-fades over a short time', (tester) async {
      final settled = await _settledFades(tester, c);
      await tester.pumpWidget(_app(c.before));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(c.after));
      final slug = c.name.replaceAll(' ', '_');
      if (strip != null) await _writeFrame(tester, strip, '${slug}_0ms');
      await tester.pump(const Duration(milliseconds: 50));
      // Mid-change both states are in the tree: it is moving, not popping.
      if (c.old.isNotEmpty) expect(find.text(c.old), findsOneWidget);
      if (c.next.isNotEmpty) expect(find.text(c.next), findsOneWidget);
      expect(_fades(), greaterThan(settled));
      if (strip != null) await _writeFrame(tester, strip, '${slug}_50ms');
      await tester.pump(const Duration(milliseconds: 50));
      if (strip != null) await _writeFrame(tester, strip, '${slug}_100ms');
      await tester.pump(const Duration(milliseconds: 100));
      if (strip != null) await _writeFrame(tester, strip, '${slug}_200ms');
      await tester.pumpAndSettle();
      if (c.old.isNotEmpty) expect(find.text(c.old), findsNothing);
      if (c.next.isNotEmpty) expect(find.text(c.next), findsOneWidget);
    });

    testWidgets('${c.name} is instant under reduced motion', (tester) async {
      final settled = await _settledFades(tester, c);
      await tester.pumpWidget(_app(c.before, reduced: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(c.after, reduced: true));
      await tester.pump();
      if (c.old.isNotEmpty) expect(find.text(c.old), findsNothing);
      if (c.next.isNotEmpty) expect(find.text(c.next), findsOneWidget);
      // No fade layer is left over: the new state stands alone at once.
      expect(_fades(), settled);
    });
  }
}
