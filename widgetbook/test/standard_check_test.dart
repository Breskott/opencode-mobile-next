// The screen standard, checked on every catalog use-case
// (docs/ux-system/screen-standard.md, items marked [auto]).
//
//   flutter test test/standard_check_test.dart            # check
//   UPDATE_STANDARD_BASELINE=1 flutter test test/standard_check_test.dart
//                                           # shrink standard_baseline.json
//
// Every use-case is pumped through the builder the catalog uses, at 412 x 915,
// in four passes: en at text 1.0, en at 2.0, ar at 1.0, en dark at 1.0. The
// rules and what they count are in standard_measure.dart. The result goes to
// standard_report.json. Like the coverage ratchet, today's findings are in
// standard_baseline.json: a NEW finding fails, and a fixed one must be removed
// from the baseline (run with UPDATE_STANDARD_BASELINE=1).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_widgetbook/all_components.dart';

import 'standard_measure.dart';

final _delegates = <LocalizationsDelegate<dynamic>>[
  ...AppLocalizations.localizationsDelegates,
  GlobalMaterialLocalizations.delegate,
];

class _Pass {
  const _Pass(this.name, this.locale, this.scale, this.dark);
  final String name;
  final Locale locale;
  final double scale;
  final bool dark;
}

const _passes = [
  _Pass('en-1.0', Locale('en'), 1.0, false),
  _Pass('en-2.0', Locale('en'), 2.0, false),
  _Pass('ar-1.0', Locale('ar'), 1.0, false),
  _Pass('en-dark-1.0', Locale('en'), 1.0, true),
];

String _slug(String s) => s.replaceAll(' ', '-').toLowerCase();

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    var any = false;
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) {
        any = true;
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    if (any) await loader.load();
  }

  await family('AppSans', ['fonts/geist/Geist-Variable.ttf']);
  await family('AppMono', ['fonts/geist/GeistMono-Variable.ttf']);
  await family('AppPhosphorRegular', ['fonts/phosphor/Phosphor.ttf']);
  await family('AppPhosphorDuotone', ['fonts/phosphor/Phosphor-Duotone.ttf']);
  await family('AppPhosphorFill', ['fonts/phosphor/Phosphor-Fill.ttf']);
  // The app's Arabic fallback names (AppTheme.forLocale); the system font
  // stands in for the phone's.
  await family('Noto Sans Arabic', [
    '/usr/share/fonts/truetype/noto/NotoSansArabicUI-Regular.ttf',
  ]);
}

Future<List<PassResult>> _runAll(
  WidgetTester tester,
  Widget Function(BuildContext) build,
) async {
  final results = <PassResult>[];
  for (final p in _passes) {
    final base = p.dark ? AppTheme.dark() : AppTheme.light();
    results.add(
      await measurePass(
        tester,
        name: p.name,
        home: build,
        theme: AppTheme.forLocale(base, p.locale),
        locale: p.locale,
        scale: p.scale,
        delegates: _delegates,
        locales: AppLocalizations.supportedLocales,
        firstViewRules: p.name == 'en-1.0',
      ),
    );
  }
  return results;
}

List<Finding> _allFindings(List<PassResult> passes) => [
  for (final p in passes) ...findings(p, firstViewRules: p.name == 'en-1.0'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  // ---- The check checks itself: one tiny screen per rule. -----------------
  group('the check catches each rule', () {
    Future<Set<String>> rulesOf(
      WidgetTester tester,
      Widget Function(BuildContext) build,
    ) async => {
      for (final f in _allFindings(
        await _runAll(tester, (c) => Material(child: build(c))),
      ))
        f.rule,
    };

    testWidgets('overflow', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => Row(children: const [SizedBox(width: 600, height: 20)]),
      );
      expect(found, contains('overflow'));
    });

    testWidgets('cut-off text', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => const SizedBox(
          width: 120,
          child: Text(
            'A very long title that cannot possibly fit on one line here',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      expect(found, contains('cutoff'));
    });

    testWidgets('more than 3 text sizes', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => Column(
          children: [
            for (final s in [11.0, 13.0, 15.0, 18.0, 24.0])
              Text('Size $s', style: TextStyle(fontSize: s)),
          ],
        ),
      );
      expect(found, contains('text-sizes'));
    });

    testWidgets('two main actions', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => Column(
          children: [
            KitButton.primary(label: 'One', onPressed: () {}),
            KitButton.primary(label: 'Two', onPressed: () {}),
          ],
        ),
      );
      expect(found, contains('main-actions'));
    });

    testWidgets('eight first-view items', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => ListView(
          children: [for (var i = 0; i < 8; i++) KitRow(title: 'Row $i')],
        ),
      );
      expect(found, contains('first-view-items'));
    });

    testWidgets('a row with three lines of text', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => ListView(
          children: [
            KitRow(
              title: 'Fix the flaky checkout test',
              supporting: const TextSpan(text: 'shopfront'),
              below: const KitText('Allow running flutter test? Network.'),
            ),
          ],
        ),
      );
      expect(found, contains('row-lines'));
    });

    testWidgets('a row with two lines of text passes', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => ListView(
          children: [
            KitRow(
              title: 'Fix the flaky checkout test',
              supporting: const TextSpan(text: 'shopfront'),
            ),
          ],
        ),
      );
      expect(found, isNot(contains('row-lines')));
    });

    testWidgets('red', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => const ColoredBox(
          color: Color(0xFFD32F2F),
          child: SizedBox(width: 100, height: 100),
        ),
      );
      expect(found, contains('red'));
    });

    testWidgets('a clean screen passes', (tester) async {
      final found = await rulesOf(
        tester,
        (_) => Column(
          children: [
            const Text('Title', style: TextStyle(fontSize: 20)),
            const Text('Body', style: TextStyle(fontSize: 15)),
            KitButton.primary(label: 'Go', onPressed: () {}),
          ],
        ),
      );
      expect(found, isEmpty);
    });
  });

  // ---- Every catalog use-case. --------------------------------------------
  final report = <String, Object?>{};
  final foundRules = <String, Set<String>>{};
  final components = allComponents();
  for (final c in components) {
    for (final useCase in c.component.useCases) {
      final path = [
        _slug(c.area),
        if (c.folder != null) _slug(c.folder!),
        _slug(c.name),
        _slug(useCase.name),
      ].join('/');
      testWidgets('standard: $path', (tester) async {
        final passes = await _runAll(
          tester,
          (context) => useCase.builder(context),
        );
        final fs = _allFindings(passes);
        foundRules[path] = {for (final f in fs) f.rule};
        report[path] = {
          'screen': c.screen,
          'passes': [for (final p in passes) p.toJson()],
          'findings': [for (final f in fs) f.toJson()],
          'amberUsed': {
            for (final p in passes)
              if (p.amber.isNotEmpty) p.name: p.amber.toSet().toList(),
          },
        };
      });
    }
  }

  // ---- The ratchet (runs last: tests run in declaration order). -----------
  testWidgets('standard ratchet: no new findings, baseline only shrinks', (
    tester,
  ) async {
    final counts = <String, int>{for (final r in rules) r: 0};
    for (final rs in foundRules.values) {
      for (final r in rs) {
        counts[r] = (counts[r] ?? 0) + 1;
      }
    }
    final out = {
      'rules': rules,
      'useCases': report.length,
      'screensWithFindings': foundRules.values
          .where((s) => s.isNotEmpty)
          .length,
      'findingsPerRule': counts,
      'results': report,
    };
    File(
      'standard_report.json',
    ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(out)}\n');

    final baselineFile = File('standard_baseline.json');
    final baseline = baselineFile.existsSync()
        ? {
            for (final e
                in ((jsonDecode(baselineFile.readAsStringSync())
                            as Map<String, Object?>)['findings']
                        as Map<String, Object?>)
                    .entries)
              e.key: {...(e.value! as List).cast<String>()},
          }
        : <String, Set<String>>{};

    final fresh = <String>[];
    final fixed = <String>[];
    for (final e in foundRules.entries) {
      final known = baseline[e.key] ?? const <String>{};
      for (final r in e.value.difference(known)) {
        fresh.add('${e.key}  $r');
      }
      for (final r in known.difference(e.value)) {
        fixed.add('${e.key}  $r');
      }
    }
    for (final k in baseline.keys.where((k) => !foundRules.containsKey(k))) {
      fixed.add('$k  (use-case no longer exists)');
    }

    if (Platform.environment['UPDATE_STANDARD_BASELINE'] == '1') {
      // Cataloguing a screen that already shipped records what it breaks
      // today (ADMIT_NEW_USE_CASES=1); a known use-case can only shrink.
      final admitNew = Platform.environment['ADMIT_NEW_USE_CASES'] == '1';
      // A rule that is new today records what it finds on screens that
      // already shipped (ADMIT_NEW_RULES=row-lines); afterwards it only shrinks.
      final admitRules = (Platform.environment['ADMIT_NEW_RULES'] ?? '')
          .split(',')
          .where((r) => r.isNotEmpty)
          .toSet();
      final shrunk = <String, List<String>>{};
      for (final e in foundRules.entries) {
        final known = baseline[e.key];
        final keep = known == null
            ? (baseline.isEmpty || admitNew ? e.value : <String>{})
            : e.value.intersection(known);
        keep.addAll(e.value.intersection(admitRules));
        if (keep.isNotEmpty) shrunk[e.key] = keep.toList()..sort();
      }
      baselineFile.writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert({'about': 'Standard findings that exist today (docs/ux-system/screen-standard.md). A new finding fails the check; fix one and remove it with UPDATE_STANDARD_BASELINE=1. Only shrinks (the first run, with no baseline, records all).', 'findings': shrunk})}\n',
      );
      return;
    }
    expect(
      fresh,
      isEmpty,
      reason:
          'NEW standard findings (fix the screen; see '
          'docs/ux-system/screen-standard.md):\n${fresh.join('\n')}',
    );
    expect(
      fixed,
      isEmpty,
      reason:
          'Findings fixed but still in standard_baseline.json (run with '
          'UPDATE_STANDARD_BASELINE=1 to remove them):\n${fixed.join('\n')}',
    );
  });
}
