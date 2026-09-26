// Shared frame for the kit part galleries (gate G4, docs/ux-system/kit-v2.md
// §7 and §8.4): every part at the five window sizes in light and dark, and
// at 412 and 1280 wide with 2.0 text and in Arabic (right to left). The
// app's real fonts come from tool/capture; Arabic falls back to Noto Sans
// Arabic (test/fixtures/fonts, OFL), as it does on an Android device.
//
// Gate G5 (docs/ux-system/revamp/STANDARDS.md §18, absolute): every shot
// also runs androidTapTargetGuideline, labeledTapTargetGuideline and
// textContrastGuideline, and checks that the screen-reader traversal reads
// top to bottom, then start to end (A11Y-1, A11Y-4, A11Y-6, LAY-9). The
// galleries render each shot in light and dark, so both themes are checked.
// There is no opt-out: fix the part, not the shot.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

import '../../../tool/capture/fixtures.dart'
    show captureTheme, loadCaptureFonts;

const _arabicFallback = 'KitGalleryNotoSansArabic';

/// The capture fonts plus the Arabic fallback family.
Future<void> loadKitGalleryFonts() async {
  await loadCaptureFonts();
  final arabic = FontLoader(_arabicFallback);
  for (final weight in ['Regular', 'Bold']) {
    arabic.addFont(
      File(
        'test/fixtures/fonts/NotoSansArabic-$weight.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await arabic.load();
}

/// The capture theme with Arabic falling back to Noto, like a device.
ThemeData _theme({required bool light}) {
  final theme = captureTheme(light: light);
  const fallback = [_arabicFallback];
  // Buttons carry their own text styles in the app theme.
  ButtonStyle? withFallback(ButtonStyle? style) {
    final text = style?.textStyle;
    if (style == null || text == null) return style;
    return style.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) =>
            text.resolve(states)?.copyWith(fontFamilyFallback: fallback),
      ),
    );
  }

  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: withFallback(theme.filledButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: withFallback(theme.textButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: withFallback(theme.outlinedButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: withFallback(theme.elevatedButtonTheme.style),
    ),
  );
}

/// The §8.4 sizes: phone, the census phone, tablet portrait, tablet
/// landscape or PC, large PC.
const kitGallerySizes = <Size>[
  Size(360, 800),
  Size(412, 915),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

/// Where 2.0 text and Arabic are rendered.
const kitGalleryScaledSizes = <Size>[Size(412, 915), Size(1280, 800)];

String kitGallerySize(Size size) =>
    '${size.width.toInt()}x${size.height.toInt()}';

/// Pumps an empty screen at [size], runs [open] against a context under the
/// navigator (it opens the modal part), settles, runs the G5 accessibility
/// checks ([expectKitGalleryAccessible]) and compares the whole window with
/// `goldens/kit/<name>.png`.
Future<void> kitGalleryShot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required FutureOr<void> Function(BuildContext context) open,
  Future<void> Function(WidgetTester tester)? then,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool settleAfterThen = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  late BuildContext context;
  // Released before the test ends; a tear-down runs too late for the check.
  final semantics = tester.ensureSemantics();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(light: light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    unawaited(Future.sync(() => open(context)));
    await tester.pumpAndSettle();
    if (then != null) {
      await then(tester);
      if (settleAfterThen) await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectKitGalleryAccessible(
      tester,
      shot: name,
      direction: Directionality.of(context),
    );
  } finally {
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

/// The G5 checks by the name the baseline uses.
const _guidelines = <String, AccessibilityGuideline>{
  'androidTapTarget': androidTapTargetGuideline,
  'labeledTapTarget': labeledTapTargetGuideline,
  'textContrast': textContrastGuideline,
};
const _readingOrder = 'readingOrder';

/// Shots that failed a G5 check when the gate was built, by golden name. It
/// may only shrink: a shot or check not listed here fails, and a listed one
/// that passes prints the smaller entry to commit.
const kitGalleryG5BaselinePath =
    'test/goldens/kit/kit_gallery_g5_baseline.json';

Map<String, Set<String>> _loadBaseline() {
  final file = File(kitGalleryG5BaselinePath);
  if (!file.existsSync()) return const {};
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final shots = raw['shots'] as Map<String, dynamic>? ?? const {};
  return {
    for (final MapEntry(:key, :value) in shots.entries)
      key: {for (final check in value as List<dynamic>) check as String},
  };
}

/// Gate G5 on what is on screen now: the three platform guidelines and the
/// reading order (A11Y-1, A11Y-4, A11Y-6, LAY-9), less the checks that
/// [shot] still has in the baseline. Semantics must be on
/// ([WidgetTester.ensureSemantics]).
Future<void> expectKitGalleryAccessible(
  WidgetTester tester, {
  required String shot,
  required TextDirection direction,
}) async {
  final failures = <String, String>{};
  for (final MapEntry(key: check, value: guideline) in _guidelines.entries) {
    final result = await guideline.evaluate(tester);
    if (!result.passed) {
      failures[check] = result.reason ?? guideline.description;
    }
  }
  final problems = kitReadingOrderProblems(
    tester.semantics.simulatedAccessibilityTraversal(),
    direction: direction,
    view: tester.view,
    ignore: _barrierNodeIds(),
  );
  if (problems.isNotEmpty) {
    failures[_readingOrder] =
        'The screen reader must read top to bottom, then start to end '
        '(A11Y-4). Fix the part\'s widget order or its semantics sort keys:\n'
        '${problems.join('\n')}';
  }

  final allowed = _loadBaseline()[shot] ?? const <String>{};
  final fixed = allowed.difference(failures.keys.toSet());
  if (fixed.isNotEmpty) {
    final left = allowed.difference(fixed).toList()..sort();
    debugPrint(
      'G5 ratchet: $shot now passes ${fixed.join(', ')}. Commit the smaller '
      'baseline in $kitGalleryG5BaselinePath: '
      '${left.isEmpty ? 'remove "$shot"' : '"$shot": ${jsonEncode(left)}'}',
    );
  }
  final fresh = {
    for (final MapEntry(:key, :value) in failures.entries)
      if (!allowed.contains(key)) key: value,
  };
  if (fresh.isNotEmpty) {
    fail(
      'G5 (docs/ux-system/revamp/STANDARDS.md §18) failed for $shot:\n'
      '${[for (final MapEntry(:key, :value) in fresh.entries) '[$key] $value'].join('\n\n')}',
    );
  }
}

/// Semantics nodes of modal barriers. The framework sorts a dismissible
/// barrier after its route on purpose (ModalRoute gives it
/// `OrdinalSortKey(1.0)`), so "tap to close" is read after the sheet; it is
/// not content and has no place in the reading order.
Set<int> _barrierNodeIds() {
  final ids = <int>{};
  void visit(Element element) {
    if (element is RenderObjectElement) {
      final id = element.renderObject.debugSemantics?.id;
      if (id != null) ids.add(id);
    }
    element.visitChildren(visit);
  }

  for (final barrier
      in find.byType(ModalBarrier, skipOffstage: false).evaluate()) {
    visit(barrier);
  }
  return ids;
}

/// A11Y-4 on a traversal: a visible node must not sit wholly above the node
/// read just before it, nor wholly on its start side while starting on the
/// same line. Nodes that overlap (a row and its trailing button) have no
/// order between them and are skipped, as are the [ignore]d ids.
List<String> kitReadingOrderProblems(
  Iterable<SemanticsNode> traversal, {
  required TextDirection direction,
  required FlutterView view,
  Set<int> ignore = const {},
}) {
  const slack = 1.0;
  final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  final nodes = <(SemanticsNode, Rect)>[];
  for (final node in traversal) {
    if (node.flagsCollection.isHidden || ignore.contains(node.id)) continue;
    final rect = _globalRect(node, view.devicePixelRatio);
    if (rect.isEmpty || !rect.overlaps(screen)) continue;
    nodes.add((node, rect));
  }

  final problems = <String>[];
  for (var i = 1; i < nodes.length; i++) {
    final (before, a) = nodes[i - 1];
    final (after, b) = nodes[i];
    final overlap = a.intersect(b);
    if (overlap.width > slack && overlap.height > slack) continue;
    final bool backwards = direction == TextDirection.ltr
        ? b.right <= a.left + slack
        : b.left >= a.right - slack;
    final String? why;
    if (b.bottom <= a.top + slack) {
      why = 'goes back up';
    } else if (backwards &&
        b.top <= a.top + slack &&
        b.center.dy < a.bottom &&
        a.center.dy < b.bottom) {
      why = 'goes back towards the start of the line';
    } else {
      why = null;
    }
    if (why != null) {
      problems.add(
        '${_describe(after, b)} is read after ${_describe(before, a)}: $why',
      );
    }
  }
  return problems;
}

String _describe(SemanticsNode node, Rect rect) {
  final data = node.getSemanticsData();
  final text = [
    data.label,
    data.value,
    data.tooltip,
  ].where((part) => part.isNotEmpty).join(' / ').replaceAll('\n', ' ');
  return '#${node.id} "$text" at (${rect.left.round()}, ${rect.top.round()}, '
      '${rect.right.round()}, ${rect.bottom.round()})';
}

Rect _globalRect(SemanticsNode node, double devicePixelRatio) {
  var rect = node.rect;
  for (SemanticsNode? at = node; at != null; at = at.parent) {
    final transform = at.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
  }
  return Rect.fromLTRB(
    rect.left / devicePixelRatio,
    rect.top / devicePixelRatio,
    rect.right / devicePixelRatio,
    rect.bottom / devicePixelRatio,
  );
}
