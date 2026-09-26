// Gate G23 (docs/ux-system/revamp/STANDARDS.md §18): the golden harness.
//
// A pure-Dart file scan, no widget pumping. It makes these rules mechanical:
//
// - TEST-9: the kit gallery frame (test/goldens/kit/kit_gallery.dart) renders
//   at device pixel ratio 3.0, and no other file in test/goldens/kit/ that
//   compares goldens itself sets another ratio.
// - ARCH-11: every golden harness (a test file that compares against a
//   golden file, kit_gallery.dart included) sets
//   debugDefaultTargetPlatformOverride = TargetPlatform.android (or runs
//   under TargetPlatformVariant.only(TargetPlatform.android)).
// - TEST-7: every golden test file starts with the "Regenerate deliberately
//   … look at every changed image before committing it" header.
// - TEST-8: every golden test file loads the app's real fonts
//   (loadCaptureFonts or loadKitGalleryFonts); a file that renders
//   Locale('ar') loads the Arabic families (loadKitGalleryFonts) and renders
//   through a theme that falls back to them (AppTheme.forLocale,
//   kitGalleryShot or kitGalleryPart); the loaders register every family AppTheme and
//   pubspec.yaml name, including the literals AppTheme.forLocale uses for
//   Arabic, except the reasoned [arabicFallbackAllowlist].
// - TEST-20: golden PNG names are
//   <module>_<page>_<state>[_ar][_text2][_<W>x<H>]_<dark|light>.png (or
//   kit_<part>_<state>… for kit parts), a size only for the LAY-4 gallery
//   sizes other than 412x915, which is always left out. Kit galleries build
//   names with kitGalleryName (kit_gallery.dart).
// - Golden failure images (**/failures/) stay untracked (TEST-12 is G25's;
//   this gate only stops the tracked set from growing).
//
// "Golden test files" are test/goldens/**/*_golden_test.dart plus any other
// test file under test/ that compares against a golden file.
//
// Absolute: everything under test/goldens/kit/ (the kit gallery frame, every
// kit part gallery and its PNGs) and the font-family test. The rules are
// absolute everywhere, but today's screen goldens break some of them, so
// outside test/goldens/kit/ each check is a ratchet against
// test/golden_harness_baseline.json: a violation not in the baseline fails;
// when violations disappear the test still passes and prints the smaller
// baseline to commit. The baseline guards itself: no commit in its git
// history, and no uncommitted edit, may add an entry or a key unless the
// commit body says `ratchet-tighten: G23 <check>` for that check (KIT-44),
// and it may never hold a test/goldens/kit/ entry. After a fix lands,
// rewrite it with
//   GOLDEN_HARNESS_WRITE=1 flutter test test/golden_harness_test.dart
// (the pinned Flutter from AGENTS.md); write mode refuses to add entries.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/golden_harness_baseline.json';
const _self = 'test/golden_harness_test.dart';
const _kitDir = 'test/goldens/kit/';
const _kitGallery = 'test/goldens/kit/kit_gallery.dart';
const _captureFixtures = 'tool/capture/fixtures.dart';
const _appTheme = 'lib/ui/app_theme.dart';

/// Every check [scan] reports, by baseline key.
const checkKeys = {
  'kitGalleryDpr3',
  'androidPlatform',
  'regenerateHeader',
  'captureFonts',
  'arabicFont',
  'goldenNames',
  'trackedFailures',
};

/// Families AppTheme names that no loader registers, and why that is right.
/// An entry that AppTheme stops naming fails the font test.
const arabicFallbackAllowlist = {
  'Noto Naskh Arabic':
      'second Arabic fallback; Noto Sans Arabic (registered) covers every '
      'Arabic glyph first, as on a device that ships both',
  'Arial':
      'last fallback, not on Android; Roboto (sans-serif) and Noto Sans '
      'Arabic are reached before it',
};

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

/// [source] without comments: `//` to the end of the line and nested
/// `/* */` blocks, but not inside string literals (plain, raw, triple-quoted
/// and `${}`-interpolated). Line breaks are kept.
String stripComments(String source) {
  final out = StringBuffer();
  // Each frame is code (with its open `{` depth) or a string literal.
  final stack = <_Frame>[_Frame.code()];
  var i = 0;
  bool at(String s) => source.startsWith(s, i);
  while (i < source.length) {
    final frame = stack.last;
    final c = source[i];
    if (frame.quote == null) {
      if (at('//')) {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        continue;
      }
      if (at('/*')) {
        var depth = 0;
        do {
          if (at('/*')) {
            depth++;
            i += 2;
          } else if (at('*/')) {
            depth--;
            i += 2;
          } else {
            if (source[i] == '\n') out.write('\n');
            i++;
          }
        } while (depth > 0 && i < source.length);
        continue;
      }
      if (c == "'" || c == '"') {
        final triple = at(c * 3);
        final raw =
            i > 0 &&
            source[i - 1] == 'r' &&
            (i < 2 || !RegExp(r'[\w$]').hasMatch(source[i - 2]));
        final q = triple ? c * 3 : c;
        out.write(q);
        i += q.length;
        stack.add(_Frame.string(q, raw: raw));
        continue;
      }
      if (c == '{') frame.depth++;
      if (c == '}') {
        if (frame.depth == 0 && stack.length > 1) {
          // The end of a `${...}` interpolation.
          stack.removeLast();
          out.write(c);
          i++;
          continue;
        }
        frame.depth--;
      }
      out.write(c);
      i++;
      continue;
    }
    // Inside a string literal.
    if (!frame.raw && c == r'\' && i + 1 < source.length) {
      out.write(source.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (!frame.raw && at(r'${')) {
      out.write(r'${');
      i += 2;
      stack.add(_Frame.code());
      continue;
    }
    if (at(frame.quote!)) {
      out.write(frame.quote);
      i += frame.quote!.length;
      stack.removeLast();
      continue;
    }
    if (c == '\n' && frame.quote!.length == 1) stack.removeLast();
    out.write(c);
    i++;
  }
  return out.toString();
}

class _Frame {
  _Frame.code() : quote = null, raw = false;
  _Frame.string(String this.quote, {required this.raw});
  final String? quote;
  final bool raw;
  int depth = 0;
}

final _arabicLocale = RegExp(
  r'''Locale\(\s*['"]ar['"]|languageCode:\s*['"]ar['"]''',
);
final _androidOverride = RegExp(
  r'debugDefaultTargetPlatformOverride\s*=\s*TargetPlatform\.android\b|'
  r'TargetPlatformVariant\.only\(\s*TargetPlatform\.android\s*\)',
);
final _captureFonts = RegExp(r'\b(loadCaptureFonts|loadKitGalleryFonts)\b');
// The loader that registers AppTheme.forLocale's Arabic families, or a file
// registering Noto Sans Arabic under that family name itself.
final _arabicFonts = RegExp(
  r'''\bloadKitGalleryFonts\b|FontLoader\(\s*['"]Noto Sans Arabic['"]''',
);
// A theme whose Arabic fallback is one of the registered families.
// kitGalleryShot and kitGalleryPart both render through kit_gallery.dart's
// theme, whose text falls back to Noto Sans Arabic.
final _arabicTheme = RegExp(
  r'\bAppTheme\.forLocale\(|\bkitGallery(?:Shot|Part)\(',
);
final _dprAssign = RegExp(r'devicePixelRatio\s*=\s*([0-9.]+)\s*;');

/// [source] with every string literal's content removed, so a check reads
/// only code.
String _blankStrings(String source) => source.replaceAll(
  RegExp(
    r'r?\x27{3}[\s\S]*?\x27{3}|r?\x22{3}[\s\S]*?\x22{3}|r?\x27(?:\\.|[^\x27\\\n])*\x27|r?\x22(?:\\.|[^\x22\\\n])*\x22',
  ),
  "''",
);

String _rel(String path) =>
    path.startsWith('./') ? path.substring(2) : path.replaceAll('\\', '/');

bool _inFailures(String path) => path.split('/').contains('failures');

/// Kit gallery entries are absolute: no baseline may hold them.
bool isAbsolute(String entry) => entry.startsWith(_kitDir);

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
  final code = {
    for (final p in dart) p: stripComments(File(p).readAsStringSync()),
  };
  // A file that names the matcher only inside a string (a gate's own
  // patterns, for example) is not a golden harness.
  final harnesses = {
    for (final p in dart)
      if (_blankStrings(code[p]!).contains(_goldenMatcher)) p,
  };
  final goldenTests = {
    for (final p in dart)
      if ((p.startsWith('test/goldens/') && p.endsWith('_golden_test.dart')) ||
          (harnesses.contains(p) && p.endsWith('_test.dart')))
        p,
  };

  final result = {for (final k in checkKeys) k: <String>{}};

  // TEST-9: the kit gallery frame at DPR 3.
  if (!code.containsKey(_kitGallery)) {
    result['kitGalleryDpr3']!.add('$_kitGallery: missing');
  } else {
    final values = _dprAssign
        .allMatches(code[_kitGallery]!)
        .map((m) => double.tryParse(m.group(1)!))
        .toList();
    if (values.isEmpty || values.any((v) => v != 3.0)) {
      result['kitGalleryDpr3']!.add(_kitGallery);
    }
  }
  // Other kit files that compare goldens themselves (a file that only
  // calls kitGalleryShot gets DPR 3 from it; a pure widget test in the
  // folder, such as G5's self-test, may pump at any ratio).
  for (final p in harnesses) {
    if (!p.startsWith(_kitDir) || p == _kitGallery) continue;
    final bad = _dprAssign
        .allMatches(code[p]!)
        .any((m) => double.tryParse(m.group(1)!) != 3.0);
    if (bad) result['kitGalleryDpr3']!.add(p);
  }

  // ARCH-11: every golden harness renders as Android.
  final platformFiles = {
    ...harnesses,
    if (code.containsKey(_kitGallery)) _kitGallery,
  };
  for (final p in platformFiles) {
    if (!_androidOverride.hasMatch(code[p]!)) {
      result['androidPlatform']!.add(p);
    }
  }

  for (final p in goldenTests) {
    // TEST-7 reads the raw leading comment block.
    if (!hasRegenerateHeader(File(p).readAsStringSync())) {
      result['regenerateHeader']!.add(p);
    }
    // TEST-8.
    if (!_captureFonts.hasMatch(code[p]!)) result['captureFonts']!.add(p);
  }
  // TEST-8: Arabic renders load the Arabic families and use a theme that
  // falls back to them.
  for (final p in {...goldenTests, ...harnesses}) {
    final c = code[p]!;
    if (_arabicLocale.hasMatch(c) &&
        (!_arabicFonts.hasMatch(c) || !_arabicTheme.hasMatch(c))) {
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
    stdout.writeln('G23: git ls-files failed, trackedFailures not checked');
  }
  return result;
}

Map<String, Set<String>> _parseBaseline(String text) {
  final json = jsonDecode(text) as Map<String, dynamic>;
  final checks = json['checks'] as Map<String, dynamic>;
  return {
    for (final e in checks.entries)
      e.key: {for (final v in e.value as List<dynamic>) v as String},
  };
}

Map<String, Set<String>> _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return {};
  return _parseBaseline(file.readAsStringSync());
}

String _baselineJson(Map<String, Set<String>> checks) =>
    '${const JsonEncoder.withIndent('  ').convert({
      '_comment': 'Gate G23 ratchet (test/golden_harness_test.dart). Entries only '
          'ever leave this file; see the test header.',
      'checks': {for (final e in (checks.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) e.key: (e.value.toList()..sort())},
    })}\n';

/// Entries in [next] that [previous] lacks, as `check: entry`, less the
/// checks [tightened] names.
List<String> baselineGrowth(
  Map<String, Set<String>> previous,
  Map<String, Set<String>> next, {
  Set<String> tightened = const {},
}) => [
  for (final e in next.entries)
    if (!tightened.contains(e.key))
      for (final v in e.value.difference(previous[e.key] ?? const {}))
        '${e.key}: $v',
]..sort();

/// The checks a commit body lets grow (`ratchet-tighten: G23 <check>`).
Set<String> tightenedChecks(String body) => {
  for (final m in RegExp(
    r'^ratchet-tighten:\s*G23\s+(\w+)\s*$',
    multiLine: true,
  ).allMatches(body))
    m.group(1)!,
};

String? _git(List<String> args) {
  final r = Process.runSync('git', args);
  return r.exitCode == 0 ? r.stdout as String : null;
}

/// Every way the baseline grew in its git history or in the working tree:
/// each commit that touched it against each parent that had it, and the
/// file on disk against HEAD. Null when git cannot answer.
List<String>? baselineHistoryGrowth() {
  final commits = _git(['rev-list', 'HEAD', '--', _baselinePath]);
  if (commits == null) return null;
  final problems = <String>[];
  Map<String, Set<String>>? at(String rev) {
    final text = _git(['show', '$rev:$_baselinePath']);
    return text == null ? null : _parseBaseline(text);
  }

  var introductions = 0;
  for (final commit in const LineSplitter().convert(commits.trim())) {
    if (commit.isEmpty) continue;
    final parents = (_git(['rev-list', '--parents', '-n', '1', commit]) ?? '')
        .trim()
        .split(' ')
        .skip(1);
    final mine = at(commit);
    if (mine == null) continue; // The commit deleted the file.
    final body = _git(['show', '-s', '--format=%B', commit]) ?? '';
    var hadParent = false;
    for (final parent in parents) {
      final theirs = at(parent);
      if (theirs == null) continue;
      hadParent = true;
      for (final g in baselineGrowth(
        theirs,
        mine,
        tightened: tightenedChecks(body),
      )) {
        problems.add('${commit.substring(0, 8)} added $g');
      }
    }
    if (!hadParent) introductions++;
  }
  if (introductions > 1) {
    problems.add(
      '$_baselinePath was added $introductions times; re-adding it '
      'resets the ratchet',
    );
  }
  final head = at('HEAD');
  if (head != null && File(_baselinePath).existsSync()) {
    for (final g in baselineGrowth(head, _readBaseline())) {
      problems.add('uncommitted edit added $g');
    }
  }
  return problems;
}

/// The body of top-level function [name] in [source] (comments stripped).
String _functionBody(String source, String name) {
  final start = source.indexOf(RegExp('Future<void> $name\\(\\)'));
  expect(start, isNonNegative, reason: '$name not found');
  final end = source.indexOf('\n}\n', start);
  return source.substring(start, end < 0 ? source.length : end);
}

/// Families [function] in [path] registers through `load(...)` or
/// `FontLoader(...)`, with `AppTheme.x` and file constants resolved.
Set<String> registeredFamilies(
  String path,
  String function,
  Map<String, String> themeConstants,
) {
  final source = stripComments(File(path).readAsStringSync());
  final constants = {
    for (final m in RegExp(
      r'''const (\w+) = ['"]([^'"]+)['"];''',
    ).allMatches(source))
      m.group(1)!: m.group(2)!,
  };
  final body = _functionBody(source, function);
  return {
    for (final m in RegExp(
      r'''\b(?:load|FontLoader)\(\s*(AppTheme\.\w+|\w+|'[^']+'|"[^"]+")''',
    ).allMatches(body))
      ?switch (m.group(1)!) {
        final r when r.startsWith('AppTheme.') =>
          themeConstants[r.substring(9)] ?? r,
        final r when r.startsWith("'") || r.startsWith('"') => r.substring(
          1,
          r.length - 1,
        ),
        // A file constant; a parameter (`load(String family, …)`) is not a
        // family.
        final r => constants[r],
      },
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

  group('G23 scanner', () {
    test('strips line and block comments, not strings', () {
      const source =
          "a(); /* debugDefaultTargetPlatformOverride = x; */ b();\n"
          "/* outer /* nested */ still comment */ c();\n"
          "final s = 'lib/**'; // tail\n"
          "final t = 'http://x/*y'; d();\n"
          "final u = '\${f('/*')}'; e();\n"
          "final v = r'\\'; /* gone */ g();\n";
      final code = stripComments(source);
      expect(code, isNot(contains('debugDefaultTargetPlatformOverride')));
      expect(code, isNot(contains('nested')));
      expect(code, isNot(contains('still comment')));
      expect(code, isNot(contains('tail')));
      expect(code, isNot(contains('gone')));
      for (final kept in [
        'a();',
        'b();',
        'c();',
        "'lib/**'",
        "'http://x/*y'; d();",
        "e();",
        'g();',
      ]) {
        expect(code, contains(kept));
      }
      expect('\n'.allMatches(code).length, '\n'.allMatches(source).length);
    });
    test('baseline growth honours ratchet-tighten only for its check', () {
      final before = {
        'goldenNames': {'a'},
      };
      final after = {
        'goldenNames': {'a', 'b'},
        'androidPlatform': {'c'},
      };
      expect(baselineGrowth(before, after), [
        'androidPlatform: c',
        'goldenNames: b',
      ]);
      expect(
        baselineGrowth(
          before,
          after,
          tightened: tightenedChecks('x\n\nratchet-tighten: G23 goldenNames\n'),
        ),
        ['androidPlatform: c'],
      );
    });
  });

  test('G23 font loaders register every family AppTheme and pubspec name '
      '(TEST-8)', () {
    final theme = stripComments(File(_appTheme).readAsStringSync());
    final constants = {
      for (final m in RegExp(
        r"static const (\w+Family) = '([^']+)'",
      ).allMatches(theme))
        m.group(1)!: m.group(2)!,
    };
    expect(constants, isNotEmpty, reason: 'no *Family constants in AppTheme');
    // The literal families AppTheme uses (AppTheme.forLocale for Arabic).
    final literals = <String>{
      for (final m in RegExp(
        r'''fontFamily:\s*['"]([^'"]+)['"]''',
      ).allMatches(theme))
        m.group(1)!,
      for (final m in RegExp(
        r'fontFamilyFallback:\s*(?:const\s*)?(?:<String>)?\[([^\]]*)\]',
      ).allMatches(theme))
        for (final s in RegExp(r'''['"]([^'"]+)['"]''').allMatches(m.group(1)!))
          s.group(1)!,
    };
    expect(
      literals,
      isNotEmpty,
      reason: 'no fontFamily/fontFamilyFallback literals found in $_appTheme',
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = {
      ...constants.values,
      for (final m in RegExp(
        r'^\s*-\s*family:\s*(\S+)\s*$',
        multiLine: true,
      ).allMatches(pubspec))
        m.group(1)!,
    };
    final capture = registeredFamilies(
      _captureFixtures,
      'loadCaptureFonts',
      constants,
    );
    final kit = registeredFamilies(
      _kitGallery,
      'loadKitGalleryFonts',
      constants,
    );
    final missingLatin = declared.difference(capture).toList()..sort();
    final missingArabic =
        literals
            .difference({...capture, ...kit})
            .difference(arabicFallbackAllowlist.keys.toSet())
            .toList()
          ..sort();
    final staleAllowlist =
        arabicFallbackAllowlist.keys
            .where((f) => !literals.contains(f) || kit.contains(f))
            .toList()
          ..sort();
    expect(
      [
        if (missingLatin.isNotEmpty)
          'loadCaptureFonts ($_captureFixtures) does not register the '
              'AppTheme/pubspec families $missingLatin',
        if (missingArabic.isNotEmpty)
          'loadKitGalleryFonts ($_kitGallery) does not register the '
              'AppTheme literal families $missingArabic',
        if (staleAllowlist.isNotEmpty)
          'arabicFallbackAllowlist entries AppTheme no longer needs: '
              '$staleAllowlist',
      ],
      isEmpty,
      reason: 'TEST-8: goldens render with the families AppTheme names',
    );
  });

  test('G23 baseline only shrinks and never holds kit gallery entries', () {
    final baseline = _readBaseline();
    final growth = baselineHistoryGrowth();
    if (growth == null) {
      stdout.writeln('G23: git unavailable, baseline history not checked');
    }
    expect(
      [
        for (final e in baseline.entries)
          for (final v in e.value)
            if (isAbsolute(v)) 'absolute, never baselined: ${e.key}: $v',
        for (final k in baseline.keys.toSet().difference(checkKeys))
          'unknown check: $k',
        ...?growth,
      ],
      isEmpty,
      reason:
          '$_baselinePath may only shrink (PROC-13, KIT-4); a commit may '
          'raise one check only with `ratchet-tighten: G23 <check>` in its '
          'body (KIT-44); nothing under $_kitDir is ever baselined',
    );
  });

  test('G23 golden harness ratchet (TEST-7, TEST-8, TEST-9, TEST-20, '
      'ARCH-11)', () {
    final current = scan();
    expect(current.keys.toSet(), checkKeys, reason: 'scan lost a check');
    final baseline = _readBaseline();
    final added = <String>[];
    var shrank = false;
    for (final e in current.entries) {
      final allowed = {
        for (final v in baseline[e.key] ?? const <String>{})
          if (!isAbsolute(v)) v,
      };
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
      stdout.writeln('G23: wrote $_baselinePath');
      return;
    }
    if (shrank && added.isEmpty) {
      stdout.writeln(
        'G23: violations dropped. Commit the smaller baseline '
        '($_baselinePath):\n${_baselineJson(current)}',
      );
    }
    expect(
      added,
      isEmpty,
      reason:
          'New golden-harness violations (STANDARDS.md §18 G23). Fix them; '
          'the baseline only shrinks, and nothing under $_kitDir is ever '
          'baselined:\n  ${added.join('\n  ')}',
    );
  });
}
