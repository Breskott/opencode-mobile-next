// The rules of docs/design/design-standard.md that code can check (§8).
//
// A migrated screen draws its buttons, states, progress and status lines
// with the kit in lib/ui/kit/, never with raw Material parts: no
// LinearProgressIndicator or CircularProgressIndicator, no Card(, no raw
// FilledButton. The list of migrated files only grows. An exception needs
// an entry in [_allowed] with its reason.
//
// Each migrated screen also has golden renders at 412x915, dark and light,
// in test/goldens/ (made by test/goldens/work_tab_golden_test.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screen files built on the kit, with the golden renders that show them.
/// Only grows (§9 migration order: connection states, then the Work tab).
const _migrated = <String, List<String>>{
  // §9 step 1: connecting, starting, not answering, stopped, failed.
  'lib/ui/widgets/saved_server_connection_card.dart': [
    'connection_connecting',
    'connection_not_answering',
    'connection_stopped',
    'connection_starting',
    'connection_failed',
  ],
  // §9 step 2: the Work tab and its own parts.
  'lib/ui/screens/workspace_screen.dart': [
    'work_restoring',
    'work_loading',
    'work_empty',
    'work_loaded',
    'work_not_answering',
    'work_runaway',
    'work_chooser',
    // Step 2 leftovers: conversation rows on KitRow, the parts below.
    'work_team',
    'work_nudge',
    'work_other_servers',
  ],
  'lib/ui/widgets/other_projects_panel.dart': ['work_loaded'],
  'lib/ui/widgets/work_status_line.dart': [
    'work_not_answering',
    'work_runaway',
  ],
  // Step 2 leftovers (test/goldens/work_parts_golden_test.dart): the AI
  // Team section, the one-time tip, the other servers and the shell's
  // connection line on the other tabs.
  'lib/ui/widgets/team_card.dart': ['work_team'],
  'lib/ui/widgets/nudge_card.dart': ['work_nudge'],
  'lib/ui/widgets/other_servers_panel.dart': ['work_other_servers'],
  'lib/ui/widgets/connection_status_banner.dart': ['shell_reconnecting'],
};

/// file -> (pattern, reason) exceptions. Keep it short.
const _allowed = <String, Map<String, String>>{
  'lib/ui/screens/workspace_screen.dart': {
    // Not raw progress: the conversation row's breathing "working" dot is a
    // state mark, and the pull-to-refresh spinner is Material's own.
  },
};

final _forbidden = <String, RegExp>{
  'LinearProgressIndicator': RegExp(r'\bLinearProgressIndicator\b'),
  'CircularProgressIndicator': RegExp(r'\bCircularProgressIndicator\b'),
  'Card(': RegExp(r'\bCard\('),
  'FilledButton': RegExp(r'\bFilledButton\b'),
};

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('migrated screens use the kit, not raw progress, cards or buttons', () {
    final problems = <String>[];
    for (final path in _migrated.keys) {
      final code = _code(path);
      for (final MapEntry(key: name, value: pattern) in _forbidden.entries) {
        if (_allowed[path]?.containsKey(name) ?? false) continue;
        final count = pattern.allMatches(code).length;
        if (count > 0) problems.add('$path: $name x$count');
      }
    }
    expect(problems, isEmpty, reason: 'use lib/ui/kit/ (design standard §8)');
  });

  test('every allowlist entry names a migrated file and gives a reason', () {
    for (final MapEntry(key: path, value: entries) in _allowed.entries) {
      expect(_migrated.containsKey(path), isTrue, reason: path);
      for (final MapEntry(key: pattern, value: reason) in entries.entries) {
        expect(_forbidden.containsKey(pattern), isTrue, reason: pattern);
        expect(reason.trim().length, greaterThan(10), reason: pattern);
      }
    }
  });

  test('each migrated screen has dark and light goldens at 412x915', () {
    final missing = <String>[];
    for (final names in _migrated.values) {
      for (final name in names) {
        for (final mode in ['dark', 'light']) {
          final file = File('test/goldens/${name}_$mode.png');
          if (!file.existsSync()) missing.add(file.path);
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('the kit is the one place raw progress and filled buttons live', () {
    // The rule only means something if the kit really is where they went:
    // the kit's own files may use them, and say so.
    final kit = Directory('lib/ui/kit')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => _code(file.path))
        .join('\n');
    expect(kit, contains('LinearProgressIndicator'));
    expect(kit, contains('FilledButton'));
  });
}
