// G47 — permission presentation copy (STANDARDS.md COPY-15, §18.2).
//
// A permission request's title is its plain action. Each known permission id
// maps to its own plain-action getter (English; Arabic is dropped), and an empty
// id is titled "Permission needed". Those parts are absolute.
//
// An unknown id must also be titled "Permission needed" (the id belongs behind
// Details). Today's code still titles it "Use <id>", so that part is a ratchet:
// test/permission_presentation_baseline.json holds, per locale, how many of the
// unknown-id probes below still get a non-generic title. A count may only go
// down. When it drops the test still passes and prints the smaller baseline to
// commit; regenerate with:
//   PERMISSION_PRESENTATION_WRITE=1 flutter test test/permission_presentation_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/ui/permission_presentation.dart';

const _baselinePath = 'test/permission_presentation_baseline.json';
const _baselineKey = 'unknownIdNotGeneric';

/// Known permission ids and the getter that must title each one (COPY-15).
final Map<String, String Function(AppLocalizations)> _knownIds = {
  'bash': (s) => s.e7PermissionAction1,
  'edit': (s) => s.e7PermissionAction2,
  'read': (s) => s.e7PermissionAction3,
  'external_directory': (s) => s.e7PermissionAction4,
  'doom_loop': (s) => s.e7PermissionAction5,
};

/// The English words COPY-15 names for each known id.
const Map<String, String> _englishTitles = {
  'bash': 'Run a shell command',
  'edit': 'Edit a file',
  'read': 'Read a file',
  'external_directory': 'Access an external directory',
  'doom_loop': 'Continue after repeated failures',
};

/// Ids that are empty once trimmed: always "Permission needed" (absolute).
const List<String> _emptyIds = ['', ' ', '   ', '\t', '\n'];

/// Ids no server contract defines: must be "Permission needed" (ratchet).
const List<String> _unknownIds = [
  'unknown_permission',
  'future.permission',
  'mcp__some_server__tool',
  'BASH',
];

final Map<String, AppLocalizations> _locales = {'en': AppLocalizationsEn()};

Map<String, int> _loadBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final counts = json[_baselineKey] as Map<String, dynamic>? ?? {};
  return counts.map((k, v) => MapEntry(k, v as int));
}

/// Unknown-id probes whose title is not the generic "Permission needed".
List<String> _unknownIdViolations(AppLocalizations strings) => [
  for (final id in _unknownIds)
    if (permissionRequestTitle(id, l10n: strings) !=
        strings.e7PermissionAction6)
      '"$id" -> "${permissionRequestTitle(id, l10n: strings)}"',
];

void main() {
  test('COPY-15: the generic title reads "Permission needed" in English', () {
    expect(AppLocalizationsEn().e7PermissionAction6, 'Permission needed');
  });

  for (final MapEntry(key: locale, value: strings) in _locales.entries) {
    group('COPY-15 ($locale)', () {
      test('each known id is titled with its own plain-action getter', () {
        final failures = <String>[];
        for (final MapEntry(key: id, value: getter) in _knownIds.entries) {
          final title = permissionRequestTitle(id, l10n: strings);
          if (title != getter(strings)) {
            failures.add('"$id" -> "$title", expected "${getter(strings)}"');
          }
          if (title.trim().isEmpty ||
              title == strings.e7PermissionAction6 ||
              title.contains(id)) {
            failures.add('"$id" -> "$title" is not a plain action');
          }
        }
        final titles = _knownIds.keys
            .map((id) => permissionRequestTitle(id, l10n: strings))
            .toSet();
        if (titles.length != _knownIds.length) {
          failures.add('known ids share a title: $titles');
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      });

      test('an empty id is titled "Permission needed"', () {
        final failures = <String>[
          for (final id in _emptyIds)
            if (permissionRequestTitle(id, l10n: strings) !=
                strings.e7PermissionAction6)
              '${jsonEncode(id)} -> '
                  '"${permissionRequestTitle(id, l10n: strings)}"',
        ];
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    });
  }

  test('COPY-15: English titles are the plain actions the rule names', () {
    final failures = <String>[
      for (final MapEntry(key: id, value: expected) in _englishTitles.entries)
        if (permissionRequestTitle(id) != expected)
          '"$id" -> "${permissionRequestTitle(id)}", expected "$expected"',
      // Without l10n the title falls back to English.
      for (final id in _emptyIds)
        if (permissionRequestTitle(id) != 'Permission needed')
          '${jsonEncode(id)} (no l10n) -> "${permissionRequestTitle(id)}"',
    ];
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('COPY-15 ratchet: unknown ids titled "Permission needed" '
      '(baseline only shrinks)', () {
    final baseline = _loadBaseline();
    final current = <String, int>{};
    final failures = <String>[];
    for (final MapEntry(key: locale, value: strings) in _locales.entries) {
      final violations = _unknownIdViolations(strings);
      current[locale] = violations.length;
      final allowed = baseline[locale] ?? 0;
      if (violations.length > allowed) {
        failures.add(
          '$locale: ${violations.length} unknown ids not titled '
          '"${strings.e7PermissionAction6}" (baseline $allowed):\n  '
          '${violations.join('\n  ')}',
        );
      }
    }

    final sorted = Map.fromEntries(
      current.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    if (Platform.environment['PERMISSION_PRESENTATION_WRITE'] == '1') {
      final file = File(_baselinePath);
      final json = file.existsSync()
          ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
          : <String, dynamic>{};
      json[_baselineKey] = sorted;
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      );
    } else if (sorted.entries.any((e) => e.value < (baseline[e.key] ?? 0))) {
      debugPrint(
        '--- permission_presentation baseline dropped (commit as '
        '$_baselinePath "$_baselineKey") ---\n'
        '${const JsonEncoder.withIndent('  ').convert(sorted)}\n'
        '--- end baseline ---',
      );
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
