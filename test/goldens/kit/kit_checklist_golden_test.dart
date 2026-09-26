// Gallery (gate G4) for KitChecklist
// (docs/ux-system/kit-api/KitChecklist.md "Galleries required"): the
// declared states inside a KitStateView host with the setup-steps scene at
// its finished frame, DPR 3, Android.
//
// Owner decision 2026-09-27 drops Arabic and RTL review for this wave, and
// narrows the sizes to the phone (412x915) and one wide size (1280x800), in
// light and dark. C26/P1.1's 200 % text shots of waiting, failed and done
// stay, at 412x915 (see docs/qa/revamp-kit-KitChecklist/README.md).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_checklist_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_checklist.dart';
import 'package:opencode_mobile/ui/kit/kit_log_panel.dart';
import 'package:opencode_mobile/ui/kit/kit_progress.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:opencode_mobile/ui/kit/kit_status_mark.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_steps_scene.dart';

import 'kit_gallery.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

final _log = KitLogBuffer()
  ..appendText(
    'Get:1 http://ports.ubuntu.com noble InRelease [256 kB]\n'
    'Fetched 256 kB in 1s (212 kB/s)\n',
  );

KitAction _action(String label, {bool destructive = false}) =>
    KitAction(label: label, destructive: destructive, onPressed: () {});

KitStep _s(
  String title,
  KitMarkState state, {
  String? supporting,
  bool paused = false,
  KitAction? personAction,
  KitAction? retry,
  double? value,
}) => KitStep(
  title: title,
  state: state,
  supporting: supporting,
  paused: paused,
  personAction: personAction,
  retry: retry,
  value: value,
);

/// The host: a KitStateView whose content is the checklist.
Widget _host({
  required String title,
  required KitChecklist checklist,
  String? body,
  int done = 1,
  SetupSceneHalt? halted,
  KitProgress? progress,
}) => KitStateView(
  icon: AppIconography.download,
  illustration: SetupStepsScene(
    stage: done >= 4 ? SetupSceneStage.start : SetupSceneStage.download,
    done: done,
    total: 4,
    halted: halted,
  ),
  size: KitStateSize.inline,
  title: title,
  body: body,
  progress: progress,
  content: checklist,
);

final Map<String, Widget Function()> _states = {
  'before_start': () => _host(
    title: 'Set up OpenCode on this phone',
    done: 0,
    checklist: KitChecklist(
      estimate: 'About 8 minutes the first time',
      cost: const ['About 208 MB', 'uses battery while it installs'],
      steps: [
        _s('Linux base', KitMarkState.waiting),
        _s('Git and SSH', KitMarkState.waiting),
        _s('Node.js', KitMarkState.waiting),
        _s('OpenCode', KitMarkState.waiting),
      ],
    ),
  ),
  'working': () => _host(
    title: 'Setting up OpenCode on this phone',
    progress: const KitProgress.known(.42, caption: '~4 min left'),
    checklist: KitChecklist(
      stop: _action('Cancel', destructive: true),
      log: KitLogPanel(lines: _log, live: true),
      steps: [
        _s('Linux base', KitMarkState.done, supporting: '24.04.5'),
        _s(
          'Git and SSH',
          KitMarkState.working,
          supporting: 'Downloading · 18 of 30 MB',
          value: .6,
        ),
        _s('Node.js', KitMarkState.waiting),
        _s('OpenCode', KitMarkState.waiting),
      ],
    ),
  ),
  'person_step': () => _host(
    title: 'Setting up Termux',
    checklist: KitChecklist(
      steps: [
        _s('Termux', KitMarkState.done, supporting: 'Already installed'),
        _s(
          'Allow Termux to run commands',
          KitMarkState.waiting,
          supporting: 'Opens Termux settings',
          personAction: _action('Allow'),
        ),
        _s('Install OpenCode', KitMarkState.waiting),
      ],
    ),
  ),
  'slow': () => _host(
    title: 'Setting up OpenCode on this phone',
    checklist: KitChecklist(
      since: clock.now().subtract(const Duration(seconds: 20)),
      onSlow: [_action('Run in background')],
      stop: _action('Cancel', destructive: true),
      steps: [
        _s('Linux base', KitMarkState.done, supporting: '24.04.5'),
        _s('Git and SSH', KitMarkState.working, supporting: 'Installing'),
        _s('Node.js', KitMarkState.waiting),
      ],
    ),
  ),
  'failed': () => _host(
    title: "Setup didn't finish",
    halted: SetupSceneHalt.failed,
    done: 2,
    checklist: KitChecklist(
      resume: _action('Continue setup'),
      log: KitLogPanel(lines: _log),
      steps: [
        _s('Linux base', KitMarkState.done, supporting: '24.04.5'),
        _s('Git and SSH', KitMarkState.done),
        _s(
          'Node.js',
          KitMarkState.failed,
          supporting: 'Checking the download: The file was damaged',
          retry: _action('Try again'),
        ),
        _s('OpenCode', KitMarkState.waiting),
      ],
    ),
  ),
  'paused': () => _host(
    title: 'Setup paused',
    body: 'Resumes when the phone cools.',
    halted: SetupSceneHalt.paused,
    checklist: KitChecklist(
      resume: _action('Continue setup'),
      steps: [
        _s('Linux base', KitMarkState.done, supporting: '24.04.5'),
        _s(
          'Git and SSH',
          KitMarkState.working,
          paused: true,
          supporting: 'Resumes when the phone cools',
        ),
        _s('Node.js', KitMarkState.waiting),
      ],
    ),
  ),
  'done': () => _host(
    title: 'OpenCode is ready',
    done: 4,
    checklist: KitChecklist(
      steps: [
        _s('Linux base', KitMarkState.done, supporting: '24.04.5'),
        _s('Git and SSH', KitMarkState.done),
        _s('Node.js', KitMarkState.done, supporting: 'Already installed'),
        _s('OpenCode', KitMarkState.done, supporting: '1.4.2'),
      ],
    ),
  ),
  'compact': () => _host(
    title: 'Fix the login redirect',
    checklist: KitChecklist(
      compact: true,
      next: 'merge',
      steps: [
        _s('Plan', KitMarkState.done),
        _s('Build', KitMarkState.done),
        _s('Reviewing', KitMarkState.working),
        _s('Merge', KitMarkState.waiting),
        _s('Check', KitMarkState.waiting),
        _s('Deploy', KitMarkState.waiting),
        _s('Report', KitMarkState.waiting),
      ],
    ),
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: build) in _states.entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_checklist_$state', _phone, light: light),
          size: _phone,
          light: light,
          child: build(),
        );
      });
    }

    testWidgets('working · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_checklist_working', _wide, light: light),
        size: _wide,
        light: light,
        child: _states['working']!(),
      );
    });

    for (final state in const ['before_start', 'failed', 'done']) {
      testWidgets('$state · text 2.0 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_checklist_$state',
            _phone,
            light: light,
            text2: true,
          ),
          size: _phone,
          light: light,
          textScale: 2,
          child: _states[state]!(),
        );
      });
    }
  }
}
