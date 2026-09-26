// Gate G23 (docs/ux-system/revamp/STANDARDS.md §18): the golden harness.
//
// A pure-Dart file scan, no widget pumping. It makes these rules mechanical:
//
// - TEST-9: the kit gallery frame (test/goldens/kit/kit_gallery.dart) renders
//   at device pixel ratio 3.0, and no kit gallery file sets another ratio.
// - ARCH-11: every golden harness (a test file that compares against a
//   golden file) sets debugDefaultTargetPlatformOverride =
//   TargetPlatform.android (or runs under
//   TargetPlatformVariant.only(TargetPlatform.android)).
// - TEST-7: every golden test file starts with the "Regenerate deliberately
//   … look at every changed image before committing it" header.
// - TEST-8: every golden test file loads the app's real fonts
//   (loadCaptureFonts or loadKitGalleryFonts); a file that renders
//   Locale('ar') also loads Noto Sans Arabic; loadCaptureFonts registers
//   every family AppTheme and pubspec.yaml declare.
// - TEST-20: golden PNG names are
//   <module>_<page>_<state>[_ar][_text2][_<W>x<H>]_<dark|light>.png (or
//   kit_<part>_<state>… for kit parts), a size only for the LAY-4 gallery
//   sizes other than 412x915, which is always left out.
// - Golden failure images (**/failures/) stay untracked (TEST-12 is G25's;
//   this gate only stops the tracked set from growing).
//
// "Golden test files" are test/goldens/**/*_golden_test.dart plus any other
// test file under test/ that compares against a golden file.
//
// The rules are absolute, but today's code breaks some of them, so each
// check is a ratchet against test/golden_harness_baseline.json: a violation
// not in the baseline fails the test; when violations disappear the test
// still passes and prints the smaller baseline to commit. The baseline only
// ever shrinks. After a fix lands, rewrite it with
//   GOLDEN_HARNESS_WRITE=1 flutter test test/golden_harness_test.dart
// (the pinned Flutter from AGENTS.md); write mode refuses to add entries.
// The AppTheme font-family check has no baseline: it is absolute.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/golden_harness_baseline.json';
const _self = 'test/golden_harness_test.dart';
const _kitGallery = 'test/goldens/kit/kit_gallery.dart';
const _captureFixtures = 'tool/capture/fixtures.dart';
const _appTheme = 'lib/ui/app_theme.dart';

// Built from parts so this file does not match its own scans.
const _goldenMatcher =
    'matchesGolden'
    'File(';

/// LAY-4 gallery sizes a golden name may carry; 412x915 is left out.
const namedGallerySizes = {
  '360x800',
  '915x412',
  '800x1280',
  '1280x800',
  '1600x1000',
};

final _token = RegExp(r'^[a-z0-9]+$');
final _size = RegExp(r'^\d+x\d+$');

/// Why [fileName] breaks TEST-20, or null when it follows it.
String? goldenNameProblem(String fileName) {
  if (!fileName.endsWith('.png')) return 'not a .png';
  final tokens = fileName.substring(0, fileName.length - 4).split('_');
  if (tokens.any((t) => !_token.hasMatch(t))) {
    return 'segments must be lower-case letters and digits joined by _';
  }
  final mode = tokens.removeLast();
  if (mode != 'dark' && mode != 'light') return 'must end in _dark or _light';
  if (tokens.isNotEmpty && _size.hasMatch(tokens.last)) {
    final size = tokens.removeLast();
    if (size == '412x915') return '412x915 is the default: leave it out';
    if (!namedGallerySizes.contains(size)) {
      return '$size is not a LAY-4 gallery size';
    }
  }
  if (tokens.isNotEmpty && tokens.last == 'text2') tokens.removeLast();
  if (tokens.isNotEmpty && tokens.last == 'ar') tokens.removeLast();
  for (final t in tokens) {
    if (t == 'ar' || t == 'text2' || t == 'dark' || t == 'light') {
      return '"$t" is out of place: [_ar][_text2][_<W>x<H>]_<mode> is the order';
    }
    if (_size.hasMatch(t)) return 'size "$t" is out of place';
  }
  if (tokens.length < 3) {
    return tokens.isNotEmpty && tokens.first == 'kit'
        ? 'needs kit_<part>_<state>'
        : 'needs <module>_<page>_<state>';
  }
  return null;
}

/// True when the file's leading comment block carries the TEST-7 header.
bool hasRegenerateHeader(String source) {
  final lead = <String>[];
  for (final line in const LineSplitter().convert(source)) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (!t.startsWith('//')) break;
    lead.add(t.replaceFirst(RegExp(r'^/+'), ''));
  }
  final text = lead.join(' ').replaceAll(RegExp(r'\s+'), ' ');
  return text.contains('Regenerate deliberately') &&
      text.contains('look at every changed image before committing it');
}

/// [source] without `//` comments (strings holding `//` are rare enough in
/// these harnesses to ignore; a URL in a string only loses its tail).
String _code(String source) => const LineSplitter()
    .convert(source)
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

final _arabicLocale = RegExp(
  r'''Locale\(\s*['"]ar['"]|languageCode:\s*['"]ar['"]''',
);
final _androidOverride = RegExp(
  r'debugDefaultTargetPlatformOverride\s*=\s*TargetPlatform\.android\b|'
  r'TargetPlatformVariant\.only\(\s*TargetPlatform\.android\s*\)',
);
final _captureFonts = RegExp(r'\b(loadCaptureFonts|loadKitGalleryFonts)\b');
final _arabicFonts = RegExp(r'\bloadKitGalleryFonts\b|NotoSansArabic');
final _dprAssign = RegExp(r'devicePixelRatio\s*=\s*([0-9.]+)\s*;');

String _rel(String path) =>
    path.startsWith('./') ? path.substring(2) : path.replaceAll('\\', '/');

bool _inFailures(String path) => path.split('/').contains('failures');

List<String> _files(String root, bool Function(String) keep) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return [
    for (final e in dir.listSync(recursive: true, followLinks: false))
      if (e is File && keep(_rel(e.path))) _rel(e.path),
  ]..sort();
}

/// Every check's violations, keyed by check name.
Map<String, Set<String>> scan() {
  final dart = _files('test', (p) => p.endsWith('.dart') && p != _self);
  final sources = {for (final p in dart) p: File(p).readAsStringSync()};
  final harnesses = {
    for (final p in dart)
      if (_code(sources[p]!).contains(_goldenMatcher)) p,
  };
  final goldenTests = {
    for (final p in dart)
      if ((p.startsWith('test/goldens/') && p.endsWith('_golden_test.dart')) ||
          (harnesses.contains(p) && p.endsWith('_test.dart')))
        p,
  };

  final result = <String, Set<String>>{
    'kitGalleryDpr3': {},
    'androidPlatform': {},
    'regenerateHeader': {},
    'captureFonts': {},
    'arabicFont': {},
    'goldenNames': {},
    'trackedFailures': {},
  };

  // TEST-9: the kit gallery frame at DPR 3, and nothing in the kit gallery
  // folder at another ratio.
  if (!sources.containsKey(_kitGallery)) {
    result['kitGalleryDpr3']!.add('$_kitGallery: missing');
  } else {
    final values = _dprAssign
        .allMatches(_code(sources[_kitGallery]!))
        .map((m) => double.tryParse(m.group(1)!))
        .toList();
    if (values.isEmpty || values.any((v) => v != 3.0)) {
      result['kitGalleryDpr3']!.add(_kitGallery);
    }
  }
  for (final p in dart) {
    if (!p.startsWith('test/goldens/kit/') || p == _kitGallery) continue;
    final bad = _dprAssign
        .allMatches(_code(sources[p]!))
        .any((m) => double.tryParse(m.group(1)!) != 3.0);
    if (bad) result['kitGalleryDpr3']!.add(p);
  }

  // ARCH-11: every golden harness renders as Android.
  final platformFiles = {
    ...harnesses,
    if (sources.containsKey(_kitGallery)) _kitGallery,
  };
  for (final p in platformFiles) {
    if (!_androidOverride.hasMatch(_code(sources[p]!))) {
      result['androidPlatform']!.add(p);
    }
  }

  for (final p in goldenTests) {
    final source = sources[p]!;
    final code = _code(source);
    // TEST-7.
    if (!hasRegenerateHeader(source)) result['regenerateHeader']!.add(p);
    // TEST-8.
    if (!_captureFonts.hasMatch(code)) result['captureFonts']!.add(p);
  }
  // TEST-8: Arabic renders load Noto Sans Arabic.
  for (final p in {...goldenTests, ...harnesses}) {
    final code = _code(sources[p]!);
    if (_arabicLocale.hasMatch(code) && !_arabicFonts.hasMatch(code)) {
      result['arabicFont']!.add(p);
    }
  }

  // TEST-20: every golden PNG under test/.
  for (final p in _files('test', (p) => p.endsWith('.png'))) {
    if (_inFailures(p)) continue;
    final problem = goldenNameProblem(p.split('/').last);
    if (problem != null) result['goldenNames']!.add(p);
  }

  // Failure images stay untracked (TEST-12, G25; this gate ratchets).
  final git = Process.runSync('git', ['ls-files', '-z', '--', 'test']);
  if (git.exitCode == 0) {
    for (final p in (git.stdout as String).split('\x00')) {
      if (p.isNotEmpty && _inFailures(p)) result['trackedFailures']!.add(p);
    }
  } else {
    // Not a git checkout (an exported tree): nothing can be tracked.
    // ignore: avoid_print
    print('G23: git ls-files failed, trackedFailures not checked');
  }
  return result;
}

Map<String, Set<String>> _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final checks = json['checks'] as Map<String, dynamic>;
  return {
    for (final e in checks.entries)
      e.key: {for (final v in e.value as List<dynamic>) v as String},
  };
}

String _baselineJson(Map<String, Set<String>> checks) =>
    '${const JsonEncoder.withIndent('  ').convert({
      '_comment': 'Gate G23 ratchet (test/golden_harness_test.dart). Entries only '
          'ever leave this file; see the test header.',
      'checks': {for (final e in (checks.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) e.key: (e.value.toList()..sort())},
    })}\n';

/// Families a `load(...)` call in loadCaptureFonts registers, as written.
Set<String> _capturedFamilyRefs() {
  final source = _code(File(_captureFixtures).readAsStringSync());
  final start = source.indexOf('Future<void> loadCaptureFonts()');
  expect(start, isNonNegative, reason: 'loadCaptureFonts not found');
  final end = source.indexOf('\n}\n', start);
  final body = source.substring(start, end < 0 ? source.length : end);
  return {
    for (final m in RegExp(
      r'''\bload\(\s*(AppTheme\.\w+|'[^']+'|"[^"]+")''',
    ).allMatches(body))
      m.group(1)!.replaceAll(RegExp('''['"]'''), ''),
  };
}

void main() {
  group('G23 golden-name rule (TEST-20)', () {
    test('accepts the documented shapes', () {
      for (final ok in [
        'kit_sheet_default_dark.png',
        'kit_sheet_default_ar_1280x800_light.png',
        'kit_confirm_destructive_text2_800x1280_dark.png',
        'chat_thread_loaded_ar_text2_dark.png',
        'settings_hub_loaded_1280x800_dark.png',
        'team_board_move_sheet_light.png',
      ]) {
        expect(goldenNameProblem(ok), isNull, reason: ok);
      }
    });
    test('rejects the rest', () {
      for (final bad in [
        'chat_empty_dark.png', // no page
        'kit_sheet_dark.png', // no state
        'kit_sheet_default_412x915_dark.png', // default size written out
        'kit_sheet_default_320x640_dark.png', // not a gallery size
        'kit_sheet_default_text2_ar_dark.png', // suffixes out of order
        'kit_sheet_default_1280x800_ar_dark.png', // size before _ar
        'kit_sheet_default.png', // no mode
        'Kit_sheet_default_dark.png', // upper case
        'kit-sheet_default_state_dark.png', // hyphen
      ]) {
        expect(goldenNameProblem(bad), isNotNull, reason: bad);
      }
    });
    test('reads the regenerate header only at the top of the file', () {
      const good =
          '// Goldens.\n//\n// Regenerate deliberately:\n'
          '//   flutter test --update-goldens test/goldens/x_golden_test.dart\n'
          '// and look at every changed image before committing it.\n'
          "import 'dart:io';\n";
      const afterImports =
          "import 'dart:io';\n\n/// Regenerate deliberately: and look at "
          'every changed image before committing it.\nvoid main() {}\n';
      expect(hasRegenerateHeader(good), isTrue);
      expect(hasRegenerateHeader(afterImports), isFalse);
    });
  });

  test('G23 loadCaptureFonts registers every AppTheme and pubspec family', () {
    final refs = _capturedFamilyRefs();
    final theme = File(_appTheme).readAsStringSync();
    final constants = {
      for (final m in RegExp(
        r"static const (\w+Family) = '([^']+)'",
      ).allMatches(theme))
        m.group(1)!: m.group(2)!,
    };
    expect(constants, isNotEmpty, reason: 'no *Family constants in AppTheme');
    final loaded = {
      for (final r in refs)
        r.startsWith('AppTheme.') ? constants[r.substring(9)] ?? r : r,
    };
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = {
      ...constants.values,
      for (final m in RegExp(
        r'^\s*-\s*family:\s*(\S+)\s*$',
        multiLine: true,
      ).allMatches(pubspec))
        m.group(1)!,
    };
    final missing = declared.difference(loaded).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'loadCaptureFonts ($_captureFixtures) must register every family '
          'AppTheme or pubspec.yaml declares (TEST-8); missing: $missing',
    );
  });

  test('G23 golden harness ratchet (TEST-7, TEST-8, TEST-9, TEST-20, '
      'ARCH-11)', () {
    final current = scan();
    expect(
      current.keys,
      containsAll(const ['androidPlatform', 'goldenNames']),
      reason: 'scan lost a check',
    );
    final baseline = _readBaseline();
    final added = <String>[];
    var shrank = false;
    for (final e in current.entries) {
      final allowed = baseline[e.key] ?? const <String>{};
      for (final v in e.value.difference(allowed).toList()..sort()) {
        final why = e.key == 'goldenNames'
            ? ' (${goldenNameProblem(v.split('/').last)})'
            : '';
        added.add('${e.key}: $v$why');
      }
      if (allowed.difference(e.value).isNotEmpty) shrank = true;
    }
    for (final k in baseline.keys) {
      if (!current.containsKey(k)) shrank = true;
    }

    if (Platform.environment['GOLDEN_HARNESS_WRITE'] == '1') {
      // The first write seeds the file; after that it only shrinks.
      if (File(_baselinePath).existsSync()) {
        expect(added, isEmpty, reason: 'write mode never grows the baseline');
      }
      File(_baselinePath).writeAsStringSync(_baselineJson(current));
      // ignore: avoid_print
      print('G23: wrote $_baselinePath');
      return;
    }
    if (shrank && added.isEmpty) {
      // ignore: avoid_print
      print(
        'G23: violations dropped. Commit the smaller baseline '
        '($_baselinePath):\n${_baselineJson(current)}',
      );
    }
    expect(
      added,
      isEmpty,
      reason:
          'New golden-harness violations (STANDARDS.md §18 G23). Fix them; '
          'the baseline only shrinks:\n  ${added.join('\n  ')}',
    );
  });
}
