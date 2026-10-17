// The coverage ratchet. Compares the screens in lib/ui (tool/inventory.dart)
// with the screens the catalog renders (`screen:` of every catalogComponent)
// and with coverage_baseline.json, the list of screens that still have no
// use-case. Like test/kit_ratchet_test.dart it only ever shrinks.
//
//   dart run tool/coverage_check.dart            # check (exit 1 on failure)
//   dart run tool/coverage_check.dart --write    # shrink the baseline
//   dart run tool/coverage_check.dart --init     # first-time baseline
//   [--lib ../lib] [--baseline coverage_baseline.json] [--json out.json]
//
// It fails when
//   * a screen has no use-case and is not in the baseline (a NEW screen:
//     add its use-case, see README.md),
//   * the baseline lists a screen that now has a use-case (run --write),
//   * the baseline lists a class that no longer exists (run --write),
//   * a use-case names a `screen:` that is not in the inventory (a typo).
import 'dart:convert';
import 'dart:io';

import 'catalog_scan.dart';
import 'inventory.dart';
import 'src_model.dart';

String _arg(List<String> args, String name, String fallback) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
}

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}

Future<int> run(List<String> args) async {
  final lib = _arg(args, '--lib', '../lib');
  final baselinePath = _arg(args, '--baseline', 'coverage_baseline.json');
  final model = SourceModel(lib)..load();
  final screens = buildInventory(model);
  final entries = scanCatalog('lib');
  final catalogued = <String>{
    for (final e in entries)
      if (e.screen != null) e.screen!,
  };
  final inventory = {for (final s in screens) s.cls: s};
  final missing = inventory.keys.where((c) => !catalogued.contains(c)).toSet();

  final write = args.contains('--write');
  final init = args.contains('--init');
  final baselineFile = File(baselinePath);
  final baseline = baselineFile.existsSync()
      ? ((jsonDecode(baselineFile.readAsStringSync())
                    as Map<String, Object?>)['uncatalogued']
                as Map<String, Object?>)
            .keys
            .toSet()
      : <String>{};

  final fresh = missing.difference(baseline);
  final stale = baseline.intersection(catalogued);
  final gone = baseline.difference(inventory.keys.toSet());
  final typos = catalogued.difference(inventory.keys.toSet());

  final useCaseCount = entries.fold<int>(0, (n, e) => n + e.useCases.length);
  stdout.writeln(
    'screens: ${inventory.length}  catalogued: '
    '${catalogued.intersection(inventory.keys.toSet()).length}  '
    'baseline: ${baseline.length}  use-cases: $useCaseCount',
  );

  if (write || init) {
    if (!init && fresh.isNotEmpty) {
      stderr.writeln(
        'Refusing to grow the baseline: ${fresh.length} new uncatalogued '
        'screens (${fresh.take(5).join(', ')}...). Add their use-cases.',
      );
      return 1;
    }
    final keep = init ? missing : baseline.intersection(missing);
    final sorted = keep.toList()..sort();
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'about': 'Screens in lib/ui with no catalog use-case yet. This list '
            'only shrinks: add the use-case, then run '
            '"dart run tool/coverage_check.dart --write".',
        'uncatalogued': {for (final c in sorted) c: inventory[c]!.file},
      })}\n',
    );
    stdout.writeln('baseline written: ${sorted.length} screens');
    return 0;
  }

  final json = _arg(args, '--json', '');
  if (json.isNotEmpty) {
    File(json).writeAsStringSync(
      jsonEncode({
        'screens': inventory.length,
        'catalogued': catalogued.intersection(inventory.keys.toSet()).length,
        'baseline': baseline.length,
        'useCases': useCaseCount,
        'new': fresh.toList()..sort(),
      }),
    );
  }

  var failed = false;
  void report(String title, Iterable<String> items) {
    if (items.isEmpty) return;
    failed = true;
    stderr.writeln('\n$title');
    for (final c in (items.toList()..sort())) {
      final file = inventory[c]?.file;
      stderr.writeln('  $c${file == null ? '' : '  ($file)'}');
    }
  }

  report(
    'NEW screens with no catalog use-case (add one in widgetbook/lib, see '
    'widgetbook/README.md):',
    fresh,
  );
  report(
    'In the baseline but now catalogued (run "dart run tool/coverage_check.dart '
    '--write" to shrink it):',
    stale,
  );
  report('In the baseline but no longer in lib/ui (run with --write):', gone);
  report('Use-cases name a screen that is not in lib/ui:', typos);
  if (!failed) stdout.writeln('coverage ok');
  return failed ? 1 : 0;
}
