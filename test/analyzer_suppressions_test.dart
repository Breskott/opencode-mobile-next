// G26 — no new analyzer suppressions (STANDARDS.md PROC-3, §18.2 G26).
//
// A pure-Dart file scan, no widget pumping. It counts, per file, the
// analyzer suppression comments (an `ignore` or `ignore_for_file` comment,
// matched by `_suppression` below) in lib/, test/ and tool/, and reads the
// suppression settings in analysis_options.yaml: the `analyzer: exclude:`
// list, `analyzer: errors:` entries set to `ignore`, and `linter: rules:`
// entries set to `false`. Both are held against the committed baseline
// test/analyzer_suppressions_baseline.json, which may only shrink:
//
// - a file whose count rises, or a file the baseline does not list that
//   has any suppression comment, fails;
// - an analysis_options.yaml entry the baseline does not list fails;
// - an analysis_options.yaml file under lib/, test/ or tool/ fails (a
//   nested options file can silence a whole directory).
//
// When counts drop the test still passes but prints the smaller baseline;
// commit it so the numbers only go down (PROC-13: lower only the entries
// for files you changed; G31 checks that no entry rises or appears).
//
// Regenerate the baseline (only to lower it):
//   ANALYZER_SUPPRESSIONS_WRITE=1 flutter test test/analyzer_suppressions_test.dart
// with the pinned Flutter from AGENTS.md, then run it again without the
// variable and commit the smaller numbers.
//
// Instead of adding a suppression, fix the diagnostic. This file prints
// with stdout.writeln rather than print so it needs no suppression itself.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/analyzer_suppressions_baseline.json';
const _optionsPath = 'analysis_options.yaml';
const _scannedRoots = ['lib', 'test', 'tool'];

/// The suppression comment pattern from STANDARDS.md §18.2 G26.
final _suppression = RegExp(r'//\s*ignore(_for_file)?:');

/// Dart files under [root], repo-relative with forward slashes, sorted.
List<String> _dartFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// file -> number of suppression comments, only files with at least one.
Map<String, int> _countSuppressions() {
  final counts = <String, int>{};
  for (final root in _scannedRoots) {
    for (final path in _dartFiles(root)) {
      final n = _suppression.allMatches(File(path).readAsStringSync()).length;
      if (n > 0) counts[path] = n;
    }
  }
  return {for (final k in (counts.keys.toList()..sort())) k: counts[k]!};
}

/// Line locations of suppression comments in [path], for failure messages.
List<String> _suppressionLines(String path) {
  final lines = File(path).readAsLinesSync();
  return [
    for (var i = 0; i < lines.length; i++)
      if (_suppression.hasMatch(lines[i])) '$path:${i + 1}: ${lines[i].trim()}',
  ];
}

String _stripComment(String line) {
  final hash = line.indexOf('#');
  return (hash < 0 ? line : line.substring(0, hash)).trimRight();
}

int _indentOf(String line) => line.length - line.trimLeft().length;

/// Reads the suppression settings of an analysis_options.yaml [text]:
/// `analyzer.exclude` (list items), `analyzer.errors.ignore` (diagnostics
/// whose severity is `ignore`) and `linter.rules.disabled` (rules set to
/// `false`). A small indentation parser: the file uses block YAML, and a
/// flow list (`exclude: [a, b]`) is read too.
Map<String, List<String>> _parseOptions(String text) {
  final exclude = <String>[];
  final errorsIgnored = <String>[];
  final rulesDisabled = <String>[];
  // The path of keys leading to the current line, with their indents.
  final stack = <(int, String)>[];
  for (final raw in const LineSplitter().convert(text)) {
    final line = _stripComment(raw);
    if (line.trim().isEmpty) continue;
    final indent = _indentOf(line);
    final body = line.trim();
    final isItem = body.startsWith('-');
    // A key closes every key at its indent or deeper; a list item belongs
    // to the nearest key at its indent or shallower (`exclude:` then
    // `- item` may share an indent).
    while (stack.isNotEmpty &&
        (isItem ? stack.last.$1 > indent : stack.last.$1 >= indent)) {
      stack.removeLast();
    }
    final path = stack.map((e) => e.$2).join('.');
    if (isItem) {
      final item = _unquote(body.substring(1).trim());
      if (path == 'analyzer.exclude') exclude.add(item);
      // `rules:` as a list enables rules; it cannot disable one.
      continue;
    }
    final colon = body.indexOf(':');
    if (colon < 0) continue;
    final key = _unquote(body.substring(0, colon).trim());
    final value = body.substring(colon + 1).trim();
    final keyPath = path.isEmpty ? key : '$path.$key';
    if (value.isEmpty) {
      stack.add((indent, key));
      continue;
    }
    if (keyPath == 'analyzer.exclude' && value.startsWith('[')) {
      exclude.addAll(
        value
            .replaceAll(RegExp(r'^\[|\]$'), '')
            .split(',')
            .map((s) => _unquote(s.trim()))
            .where((s) => s.isNotEmpty),
      );
    } else if (path == 'analyzer.errors' && _unquote(value) == 'ignore') {
      errorsIgnored.add(key);
    } else if (path == 'linter.rules' && _unquote(value) == 'false') {
      rulesDisabled.add(key);
    }
  }
  return {
    'analyzer.exclude': exclude..sort(),
    'analyzer.errors.ignore': errorsIgnored..sort(),
    'linter.rules.disabled': rulesDisabled..sort(),
  };
}

String _unquote(String s) {
  if (s.length >= 2 &&
      ((s.startsWith("'") && s.endsWith("'")) ||
          (s.startsWith('"') && s.endsWith('"')))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

/// Nested analysis_options.yaml files under the scanned roots.
List<String> _nestedOptionsFiles() => [
  for (final root in _scannedRoots)
    if (Directory(root).existsSync())
      ...Directory(root)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('/analysis_options.yaml')),
]..sort();

Map<String, dynamic> _loadBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return const {};
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _encode(Map<String, int> comments, Map<String, List<String>> options) {
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({'suppressionComments': comments, 'analysisOptions': options})}\n';
}

void main() {
  final baseline = _loadBaseline();
  final writeMode = Platform.environment['ANALYZER_SUPPRESSIONS_WRITE'] == '1';
  final comments = _countSuppressions();
  final options = _parseOptions(File(_optionsPath).readAsStringSync());

  if (writeMode) {
    File(_baselinePath).writeAsStringSync(_encode(comments, options));
    stdout.writeln(
      'ANALYZER_SUPPRESSIONS_WRITE=1: wrote $_baselinePath '
      '(${comments.length} files, '
      '${comments.values.fold<int>(0, (a, b) => a + b)} comments)',
    );
  }

  final baseComments =
      (baseline['suppressionComments'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toInt()));
  final baseOptions =
      (baseline['analysisOptions'] as Map<String, dynamic>? ?? const {}).map(
        (k, v) => MapEntry(k, (v as List).cast<String>().toSet()),
      );

  var shrank = false;

  test('G26: no new analyzer suppression comments (PROC-3)', () {
    final problems = <String>[];
    for (final MapEntry(key: path, value: count) in comments.entries) {
      final base = baseComments[path] ?? 0;
      if (count > base) {
        problems.add(
          '$path has $count suppression comment(s), baseline $base:\n'
          '  ${_suppressionLines(path).join('\n  ')}',
        );
      } else if (count < base) {
        shrank = true;
      }
    }
    if (baseComments.keys.any((p) => !comments.containsKey(p))) shrank = true;
    expect(
      writeMode ? const <String>[] : problems,
      isEmpty,
      reason:
          'PROC-3: no new analyzer suppression. Fix the diagnostic instead '
          'of silencing it. The baseline ($_baselinePath) only shrinks.',
    );
  });

  test('G26: no new analysis_options.yaml suppression (PROC-3)', () {
    final problems = <String>[];
    for (final MapEntry(key: section, value: entries) in options.entries) {
      final base = baseOptions[section] ?? const <String>{};
      for (final entry in entries) {
        if (!base.contains(entry)) {
          problems.add('$_optionsPath $section gained "$entry"');
        }
      }
      if (base.any((e) => !entries.contains(e))) shrank = true;
    }
    for (final nested in _nestedOptionsFiles()) {
      problems.add(
        '$nested: a nested analysis options file can silence a directory',
      );
    }
    expect(
      writeMode ? const <String>[] : problems,
      isEmpty,
      reason:
          'PROC-3: no new exclude:, errors: ignore or disabled lint rule. '
          'The baseline ($_baselinePath) only shrinks.',
    );
  });

  tearDownAll(() {
    if (shrank && !writeMode) {
      stdout.writeln(
        '--- G26 baseline shrank: commit as $_baselinePath ---\n'
        '${_encode(comments, options)}--- end baseline ---',
      );
    }
  });
}
