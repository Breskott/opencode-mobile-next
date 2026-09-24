// The rules of docs/design/design-standard.md that code can check (§8).
//
// A migrated screen draws its buttons, states, progress and status lines
// with the kit in lib/ui/kit/, never with raw Material parts: no
// LinearProgressIndicator or CircularProgressIndicator, no Card(, no raw
// FilledButton. The list of migrated files only grows. An exception needs
// an entry in [_allowed] with its reason.
//
// Each migrated screen also has golden renders at 412x915, dark and light,
// in test/goldens/ (made by the *_golden_test.dart files there).
//
// A file too mixed to list whole (the chat's transcript file, where only the
// error card is a state) lists its migrated classes in [_migratedClasses]:
// the scan then covers each class's source. A file that gave up a raw part
// for a kit one lists it in [_retired] so it cannot come back.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screen files built on the kit, with the golden renders that show them.
/// Only grows (§9 migration order: connection states, the Work tab, phone
/// setup, the AI Team, the chat's states).
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
  'lib/ui/widgets/team_card.dart': [
    'work_team',
    'team_card',
    'team_card_phone',
    'team_card_idle',
  ],
  'lib/ui/widgets/nudge_card.dart': ['work_nudge'],
  'lib/ui/widgets/other_servers_panel.dart': ['work_other_servers'],
  'lib/ui/widgets/connection_status_banner.dart': ['shell_reconnecting'],
  // §9 step 3: phone setup (start, customize, progress, ready, the welcome's
  // setup line) and the "This phone" card.
  'lib/ui/screens/phone_setup/phone_setup_start_screen.dart': [
    'setup_start',
    'setup_start_progress',
    'setup_start_stopped',
    'setup_start_ready',
    'setup_start_termux',
  ],
  'lib/ui/screens/phone_setup/phone_setup_customize_sheet.dart': [
    'setup_customize',
  ],
  'lib/ui/screens/phone_setup/phone_setup_progress_screen.dart': [
    'setup_progress_running',
    'setup_progress_failed',
    'setup_progress_log',
  ],
  'lib/ui/widgets/setup_progress_view.dart': [
    'setup_progress_running',
    'setup_progress_failed',
    'setup_progress_log',
  ],
  // Motion and illustration, slice A (docs/design/motion-and-illustration-
  // 2026-09-25.md): the setup hero page (start and ready).
  'lib/ui/screens/phone_setup/phone_setup_hero.dart': [
    'setup_start',
    'setup_ready',
  ],
  'lib/ui/screens/phone_setup/phone_setup_ready_screen.dart': ['setup_ready'],
  'lib/ui/screens/phone_setup/phone_setup_welcome_entry.dart': [
    'setup_welcome_entry',
  ],
  'lib/ui/widgets/phone_server_card.dart': [
    'phone_card_running',
    'phone_card_stopped',
    'phone_card_setting_up',
  ],
  // §9 step 4: AI Team home and run (test/goldens/team_golden_test.dart,
  // team_agent_golden_test.dart, team_sheets_golden_test.dart).
  'lib/ui/screens/team/team_home_screen.dart': [
    'team_home_loaded',
    'team_home_loaded_phone',
    'team_home_empty',
    'team_home_error',
    'team_home_not_answering',
    'team_home_starting',
  ],
  'lib/ui/screens/team/team_states.dart': [
    'team_home_error',
    'team_home_not_answering',
    'team_home_starting',
  ],
  'lib/ui/screens/team/run_screen.dart': [
    'team_run_overview',
    'team_run_work',
    'team_run_merged',
  ],
  'lib/ui/screens/team/start_run_sheet.dart': ['team_start_run'],
  'lib/ui/screens/team/agent_screen.dart': [
    'team_agent',
    'team_agent_controls',
  ],
  'lib/ui/screens/team/agent_output_screen.dart': ['team_agent_output'],
  'lib/ui/screens/team/gate_sheet.dart': ['team_gate_sheet'],
  'lib/ui/screens/team/work_sheet.dart': ['team_work_sheet'],
  'lib/ui/screens/team/merge_section.dart': ['team_merge'],
  // The AI Team redesign (docs/design/aiteam-redesign-2026-09-24.md): the
  // agents list, the shared needs-you block, the plain agent row.
  'lib/ui/screens/team/team_agents_screen.dart': ['team_agents'],
  'lib/ui/screens/team/team_needs_you.dart': [
    'team_home_loaded',
    'team_run_overview',
  ],
  'lib/ui/widgets/team_agent_row.dart': ['team_agents'],
  // Motion slice D (docs/design/motion-and-illustration-2026-09-25.md):
  // the merged celebration and the Needs-you nudge.
  'lib/ui/widgets/team_moments.dart': [
    'team_run_merged',
    'team_home_loaded',
    'team_run_overview',
  ],
  // §9 step 5: the chat's states and banners (not the transcript's
  // messages). Loading, could not load, the one status line (connection,
  // a message not sent, a prompt error, staged revert, subagent, sharing).
  'lib/ui/screens/chat/chat_states.dart': [
    'chat_loading',
    'chat_load_error',
    'chat_send_error',
    'chat_disconnected',
  ],
  // The request cards above the composer: permission, question, form, retry.
  'lib/ui/screens/chat/attention_card.dart': ['chat_permission'],
  'lib/ui/screens/chat/permission_sheet.dart': ['chat_permission_sheet'],
  'lib/ui/screens/chat/empty_chat.dart': ['chat_empty'],
  'lib/ui/widgets/first_reply_notify_card.dart': ['chat_notify'],
  // §9 step 6: Settings (goldens: test/goldens/settings_golden_test.dart).
  'lib/ui/screens/settings_screen.dart': ['settings_hub'],
  'lib/ui/screens/settings/default_shell_row.dart': ['settings_hub'],
  'lib/ui/screens/settings/server_settings_screen.dart': [
    'settings_this_server',
  ],
  'lib/ui/screens/settings/notifications_settings_screen.dart': [
    'settings_notifications',
  ],
  'lib/ui/screens/settings/personal_settings_screens.dart': [
    'settings_appearance',
    'settings_privacy',
  ],
  'lib/ui/screens/app_diagnostics_screen.dart': [
    'settings_diagnostics',
    'settings_diagnostics_empty',
  ],
  'lib/ui/screens/perf_trace_section.dart': ['settings_diagnostics'],
  'lib/ui/screens/about_screen.dart': ['settings_about'],
  'lib/ui/screens/servers_screen.dart': [
    'servers_list',
    'servers_add',
    'servers_add_failed',
    'servers_phone',
  ],
  'lib/ui/screens/termux_setup_screen.dart': [
    'termux_setup',
    'phone_running',
    'phone_stopped',
  ],
  // The Servers, On this phone and Plugins cleanup
  // (docs/design/phone-server-screens-cleanup-2026-09-24.md; goldens:
  // test/goldens/phone_server_screens_golden_test.dart): the phone's server
  // as one row, its options on On this phone, the server's plugins.
  'lib/ui/widgets/local_server_row.dart': ['servers_phone'],
  'lib/ui/widgets/termux_running_server_entry.dart': ['servers_phone'],
  'lib/ui/widgets/managed_server_recovery_option.dart': ['phone_running'],
  'lib/ui/widgets/termux_phone_tools.dart': ['phone_running'],
  'lib/ui/screens/settings/server_plugins_section.dart': ['plugins_server'],
  // Open a project for OpenCode inside the app: the folder browser
  // (test/goldens/folder_browser_golden_test.dart).
  'lib/ui/widgets/folder_browser.dart': [
    'folder_browser_projects',
    'folder_browser_inside',
    'folder_browser_loading',
    'folder_browser_empty',
    'folder_browser_error',
  ],
  // §10 slice C: the empty, quiet and failure drawings, one per kind of
  // state (test/kit_states_scenes_test.dart holds their goldens).
  'lib/ui/kit/scenes/states_scenes.dart': [
    'states_sheet',
    'states_folder',
    'states_tray',
    'states_search',
    'states_terminal',
    'states_terminal_ended',
    'states_unplugged',
  ],
  'lib/ui/kit/scenes/states_working_scene.dart': ['states_working'],
};

/// file -> classes migrated inside a file too mixed to list whole, with the
/// golden renders that show them. Only grows.
const _migratedClasses = <String, Map<String, List<String>>>{
  // The transcript file: only the error a reply carries is a state; the
  // messages themselves are not part of the standard's step 5.
  'lib/ui/screens/chat/message_view.dart': {
    '_AssistantErrorRow': ['chat_model_error'],
    '_ErrorActionCard': ['chat_model_error'],
  },
  // Settings › Plugins: the page and its AI Team row. The AI Team sheet in
  // the same file (TeamPluginSheet) belongs to the AI Team redesign.
  'lib/ui/screens/settings/plugins_screen.dart': {
    'PluginsSettingsScreen': ['plugins_server'],
    '_PluginsSettingsScreenState': ['plugins_server'],
  },
};

/// file -> (pattern, reason) of raw parts a migrated screen gave up. They
/// must not come back.
const _retired = <String, Map<String, String>>{
  'lib/ui/screens/chat_screen.dart': {
    'LoadingList(': 'first load is KitSkeletonTranscript + the loading bar',
    'ProductErrorState(': 'a conversation that could not load is KitStateView',
    'ConnectionStatusBanner(': 'the connection is the one KitStatusLine',
  },
  // §10 slice C: these screens' empty and failure states are KitStateView
  // with the state drawings.
  'lib/ui/screens/global_sessions_screen.dart': {
    'ProductErrorState(':
        'could not load is KitStateView + the unplugged cable',
    'ProductEmptyState(': 'none yet / no match are KitStateView + a drawing',
  },
  'lib/ui/screens/terminal_screen.dart': {
    'ProductErrorState(':
        'could not list is KitStateView + the unplugged cable',
    'ProductEmptyState(': 'no terminal is KitStateView + the terminal window',
  },
  'lib/ui/screens/chat/message_view.dart': {
    '_PromptErrorBanner': 'a prompt error is the one KitStatusLine',
    '_SubagentContextBanner': 'the subagent context is the one KitStatusLine',
    '_SharedSessionBanner': 'sharing is the one KitStatusLine',
  },
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

/// The source of top-level class [name] in [code]: from its declaration to
/// the next top-level declaration (a line starting with a letter or `@`).
String _classCode(String code, String name) {
  final lines = code.split('\n');
  final start = lines.indexWhere(
    (line) => RegExp(
      '^(abstract |final )?class ${RegExp.escape(name)}\\b',
    ).hasMatch(line),
  );
  if (start < 0) return '';
  var end = start + 1;
  while (end < lines.length && !RegExp(r'^[A-Za-z@]').hasMatch(lines[end])) {
    end++;
  }
  return lines.sublist(start, end).join('\n');
}

List<String> _problems(String label, String code, Map<String, String>? allow) {
  final problems = <String>[];
  for (final MapEntry(key: name, value: pattern) in _forbidden.entries) {
    if (allow?.containsKey(name) ?? false) continue;
    final count = pattern.allMatches(code).length;
    if (count > 0) problems.add('$label: $name x$count');
  }
  return problems;
}

void main() {
  test('migrated screens use the kit, not raw progress, cards or buttons', () {
    final problems = <String>[];
    for (final path in _migrated.keys) {
      problems.addAll(_problems(path, _code(path), _allowed[path]));
    }
    expect(problems, isEmpty, reason: 'use lib/ui/kit/ (design standard §8)');
  });

  test('migrated classes in mixed files use the kit', () {
    final problems = <String>[];
    for (final MapEntry(key: path, value: classes)
        in _migratedClasses.entries) {
      final code = _code(path);
      for (final name in classes.keys) {
        final source = _classCode(code, name);
        expect(source, isNotEmpty, reason: '$path has no class $name');
        problems.addAll(_problems('$path#$name', source, null));
      }
    }
    expect(problems, isEmpty, reason: 'use lib/ui/kit/ (design standard §8)');
  });

  test('raw parts a migrated screen gave up do not come back', () {
    final problems = <String>[];
    for (final MapEntry(key: path, value: patterns) in _retired.entries) {
      final code = _code(path);
      for (final MapEntry(key: pattern, value: reason) in patterns.entries) {
        expect(reason.trim().length, greaterThan(10), reason: pattern);
        if (code.contains(pattern)) problems.add('$path: $pattern ($reason)');
      }
    }
    expect(problems, isEmpty);
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
    final goldens = [
      ..._migrated.values,
      for (final classes in _migratedClasses.values) ...classes.values,
    ];
    for (final names in goldens) {
      for (final name in names) {
        for (final mode in ['dark', 'light']) {
          final file = File('test/goldens/${name}_$mode.png');
          if (!file.existsSync()) missing.add(file.path);
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('scenes take their time only from KitIllustration (§10)', () {
    // A drawing paints one frame from the frame it is given; the widget
    // owns the clock, so reduced motion and the test switch reach every
    // scene. A scene with its own ticker or timer would escape both.
    final problems = <String>[];
    for (final file in Directory('lib/ui/kit/scenes').listSync()) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final code = _code(file.path);
      for (final pattern in [
        'AnimationController',
        'Ticker',
        'Timer',
        'flutter_animate',
      ]) {
        if (code.contains(pattern)) problems.add('${file.path}: $pattern');
      }
    }
    expect(problems, isEmpty);
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
