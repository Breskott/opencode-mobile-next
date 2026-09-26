// Gate G8x (docs/ux-system/revamp/STANDARDS.md §18, rule MOT-7): every
// part lib/ui/kit/kit.dart exports settles after one pump() with no ticker
// running, when it first shows AND after it changes state, and every
// drawing shows its finished frame, under the system's "remove animations"
// AND under Settings › Appearance › Animations: Off (KitEffects.motion).
//
// Manifest-driven (PROC-13): the parts come from the G4 manifest
// (test/kit/kit_manifest_test.dart), not a hand list. The parts that
// predate the gate register their samples below; a part added later
// registers its own with kitMotionStillTests(...) in its own
// test/kit/kit_<snake>_test.dart (see test/kit/kit_motion_still.dart), so
// kit units never edit this file. A part with no registration anywhere
// under test/ fails "every kit.dart part has reduced-motion samples".
//
// Which parts need samples follows G4: every drawn part (KitManifestKind
// .part), every drawing (KitManifestKind.scene) and every `showKit…`
// opener. InheritedWidget scopes (KitManifestKind.scope) draw nothing and
// need none.
//
// A stateful or animated part also registers `changes:` (a tap, a new
// configuration, a pop), because a part can be still when it mounts and
// still animate its next change.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit/kit_manifest_test.dart' show KitManifestKind, readKitManifest;
import 'kit/kit_motion_still.dart';

// ---------------------------------------------------------------------------
// Registrations: which parts have samples, found in the test sources.

final _registration = RegExp(r'''kitMotionStillTests\(\s*'(\w+)'\s*,''');

/// [source] without `//` and `/* */` comments, so a commented-out
/// registration does not count. (Strings holding `//` are rare in test
/// sources and only ever hide a registration, never invent one.)
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// Part name → the test files under [root] that register samples for it.
Map<String, Set<String>> readKitMotionRegistrations([String root = 'test']) {
  final found = <String, Set<String>>{};
  for (final f in Directory(root).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('_test.dart')) continue;
    final source = _withoutComments(f.readAsStringSync());
    for (final m in _registration.allMatches(source)) {
      (found[m[1]!] ??= {}).add(f.path);
    }
  }
  return found;
}

// ---------------------------------------------------------------------------
// The parts that predate G8x. Frozen: a part added later registers its
// samples in its own test file, never here.

const _predatesG8x = {
  'KitActionBlock',
  'KitActionStack',
  'KitAnimatedRows',
  'KitAskLine',
  'KitButton',
  'KitChevron',
  'KitConfirmSheet',
  'KitEntrance',
  'KitExpandRow',
  'KitGlass',
  'KitIconButton',
  'KitIllustration',
  'KitInset',
  'KitLoadingBar',
  'KitNotice',
  'KitPanel',
  'KitPortalScene',
  'KitProgressView',
  'KitRefresh',
  'KitRequestCard',
  'KitReveal',
  'KitRow',
  'KitRowIcon',
  'KitRowMenu',
  'KitScreen',
  'KitSecretField',
  'KitSheet',
  'KitSkeletonRows',
  'KitSkeletonTranscript',
  'KitStateView',
  'KitStatusLine',
  'KitStatusMark',
  'KitSwitchRow',
  'KitTabSwitcher',
  'KitTaskMark',
  'LoadingList',
  'ProductEmptyState',
  'ProductErrorState',
  'ProductInlineEmpty',
  'SectionLabel',
  'showKitConfirm',
  'showKitSheet',
};

/// The ratchet's ceiling: the baseline recorded when the gate was built.
/// test/kit_motion_baseline.json must stay inside it; entries leave both
/// together when the part is fixed. Never add a key.
const _frozenBaseline = <String>{
  'KitActionBlock / working / effectsOff',
  'KitActionBlock / working / system',
  'KitButton / primary working / effectsOff',
  'KitButton / primary working / system',
  'KitButton / secondary working / effectsOff',
  'KitButton / secondary working / system',
  'KitConfirmSheet / working / effectsOff',
  'KitConfirmSheet / working / system',
  'KitLoadingBar / loading / effectsOff',
  'KitLoadingBar / loading / system',
  'KitProgressView / waiting / effectsOff',
  'KitProgressView / waiting / system',
  'KitRefresh / pulled and released / effectsOff',
  'KitRefresh / pulled and released / system',
  'KitRowMenu / menu opens / effectsOff',
  'KitRowMenu / menu opens / system',
  'KitScreen / loading / effectsOff',
  'KitScreen / loading / system',
  'KitSheet / loading / effectsOff',
  'KitSheet / loading / system',
  'KitStateView / working / effectsOff',
  'KitStateView / working / system',
  'KitSwitchRow / switched on / effectsOff',
  'KitSwitchRow / switched on / system',
};

KitAction _action(String label) => KitAction(label: label, onPressed: () {});

/// A drawing sampled through the probe, so its frame is checked.
KitIllustration _drawing({bool ambient = false}) => KitIllustration(
  scene: KitSceneProbe(const KitPortalScene()),
  ambient: ambient,
);

const _confirmTitle = 'Delete fox?';

Future<bool> _openConfirm(BuildContext context) => showKitConfirm(
  context,
  title: _confirmTitle,
  body: 'The conversation is removed from the server.',
  confirmLabel: 'Delete conversation',
  kind: KitConfirmKind.destructive,
);

Future<void> _openSheet(BuildContext context) => showKitSheet<void>(
  context,
  title: 'Language',
  body: (_) => const Text('English'),
);

void _predatingParts() {
  kitMotionStillTests(
    'KitActionBlock',
    builds: {
      'default': () => KitActionBlock(
        primary: _action('Connect'),
        secondary: _action('Scan a code'),
        tertiary: [_action('Help')],
      ),
      'working': () => KitActionBlock(
        primary: KitAction(label: 'Connect', onPressed: () {}, working: true),
      ),
    },
  );
  kitMotionStillTests(
    'KitActionStack',
    builds: {
      'default': () => KitActionStack(
        primary: _action('Connect'),
        secondary: _action('Scan a code'),
        tertiary: [_action('Help')],
      ),
    },
  );
  const alpha = Text('Alpha', key: ValueKey('a'));
  const beta = Text('Beta', key: ValueKey('b'));
  const gamma = Text('Gamma', key: ValueKey('c'));
  kitMotionStillTests(
    'KitAnimatedRows',
    builds: {
      'default': () => const KitAnimatedRows(children: [alpha, beta, gamma]),
    },
    changes: {
      'row inserted': KitMotionChange(
        build: () => const KitAnimatedRows(children: [alpha, gamma]),
        act: (tester, stage) => stage.rebuild(
          const KitAnimatedRows(children: [alpha, beta, gamma]),
        ),
        shows: 'Beta',
      ),
      'row removed': KitMotionChange(
        build: () => const KitAnimatedRows(children: [alpha, beta, gamma]),
        act: (tester, stage) =>
            stage.rebuild(const KitAnimatedRows(children: [alpha, gamma])),
        hides: 'Beta',
      ),
    },
  );
  kitMotionStillTests(
    'KitAskLine',
    builds: {
      'default': () => KitAskLine(
        icon: AppIconography.info,
        question: 'Keep this server?',
        accept: _action('Keep'),
        decline: _action('Remove'),
      ),
    },
  );
  Widget button({required bool working, IconData? icon}) => KitButton.primary(
    label: 'Send',
    icon: icon,
    onPressed: () {},
    working: working,
  );
  kitMotionStillTests(
    'KitButton',
    builds: {
      'primary working': () =>
          KitButton.primary(label: 'Send', onPressed: () {}, working: true),
      'secondary working': () =>
          KitButton.secondary(label: 'Retry', onPressed: () {}, working: true),
      'tertiary': () => KitButton.tertiary(label: 'Help', onPressed: () {}),
      'disabled': () => const KitButton.primary(label: 'Send', onPressed: null),
    },
    changes: {
      // The spinner slot and its AnimatedSwitcher/AnimatedSize. (Work
      // starting ends on the spinner, which is baselined as a build.)
      'working ends': KitMotionChange(
        build: () => button(working: true),
        act: (tester, stage) => stage.rebuild(button(working: false)),
        shows: 'Send',
      ),
      'working ends with an icon': KitMotionChange(
        build: () => button(working: true, icon: AppIconography.check),
        act: (tester, stage) =>
            stage.rebuild(button(working: false, icon: AppIconography.check)),
        shows: 'Send',
      ),
    },
  );
  kitMotionStillTests('KitChevron', builds: {'default': KitChevron.new});
  kitMotionStillTests(
    'KitConfirmSheet',
    builds: {
      'default': () => KitConfirmSheet(
        title: _confirmTitle,
        body: 'The conversation is removed from the server.',
        confirmLabel: 'Delete conversation',
        kind: KitConfirmKind.destructive,
        onConfirm: () {},
        onCancel: () {},
      ),
      'working': () => KitConfirmSheet(
        title: _confirmTitle,
        body: 'The conversation is removed from the server.',
        confirmLabel: 'Delete conversation',
        onConfirm: () {},
        onCancel: () {},
        working: true,
      ),
    },
    changes: {
      'details open': KitMotionChange(
        build: () => KitConfirmSheet(
          title: _confirmTitle,
          body: 'The conversation is removed from the server.',
          confirmLabel: 'Delete conversation',
          details: const [KitTechnicalValue('Address', '10.0.0.2:4096')],
          onConfirm: () {},
          onCancel: () {},
        ),
        act: (tester, stage) =>
            stage.press(find.byKey(const ValueKey('kit-details-toggle'))),
        shows: '10.0.0.2:4096',
      ),
    },
  );
  kitMotionStillTests(
    'KitEntrance',
    builds: {'default': () => const KitEntrance(child: Text('Arrives'))},
    changes: {
      'trigger changes': KitMotionChange(
        build: () => const KitEntrance(trigger: 1, child: Text('Arrives')),
        act: (tester, stage) => stage.rebuild(
          const KitEntrance(trigger: 2, child: Text('Arrives')),
        ),
        shows: 'Arrives',
      ),
    },
  );
  kitMotionStillTests(
    'KitExpandRow',
    builds: {
      'closed': () =>
          const KitExpandRow(title: 'Advanced', children: [Text('Port')]),
      'open': () => const KitExpandRow(
        title: 'Advanced',
        initiallyExpanded: true,
        children: [Text('Port')],
      ),
    },
    changes: {
      'opens on press': KitMotionChange(
        build: () =>
            const KitExpandRow(title: 'Advanced', children: [Text('Port')]),
        act: (tester, stage) => stage.press(find.byType(KitRow)),
        shows: 'Port',
      ),
      'closes on press': KitMotionChange(
        build: () => const KitExpandRow(
          title: 'Advanced',
          initiallyExpanded: true,
          children: [Text('Port')],
        ),
        act: (tester, stage) => stage.press(find.byType(KitRow)),
        hides: 'Port',
      ),
    },
  );
  kitMotionStillTests(
    'KitGlass',
    builds: {'default': () => const KitGlass(child: Text('Floating'))},
  );
  kitMotionStillTests(
    'KitIconButton',
    builds: {
      'default': () => KitIconButton(
        icon: AppIconography.info,
        label: 'About',
        onPressed: () {},
      ),
    },
  );
  kitMotionStillTests(
    'KitIllustration',
    builds: {'entrance': _drawing, 'ambient': () => _drawing(ambient: true)},
    changes: {
      'ambient turns on': KitMotionChange(
        build: _drawing,
        act: (tester, stage) => stage.rebuild(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [_drawing(ambient: true), const Text('Waiting')],
          ),
        ),
        shows: 'Waiting',
      ),
    },
  );
  kitMotionStillTests(
    'KitInset',
    builds: {'default': () => const KitInset(child: Text('Inset'))},
  );
  kitMotionStillTests(
    'KitLoadingBar',
    builds: {
      'loading': () => const KitLoadingBar(loading: true, label: 'Loading'),
      'idle': () => const KitLoadingBar(loading: false, label: 'Loading'),
    },
    changes: {
      'loading ends': KitMotionChange(
        build: () => const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitLoadingBar(loading: true, label: 'Loading'),
            Text('Loaded'),
          ],
        ),
        act: (tester, stage) => stage.rebuild(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KitLoadingBar(loading: false, label: 'Loading'),
              Text('Loaded'),
            ],
          ),
        ),
        shows: 'Loaded',
      ),
    },
  );
  kitMotionStillTests(
    'KitNotice',
    builds: {
      'default': () => KitNotice(
        title: 'Offline',
        message: 'Your message is kept and sent when you reconnect.',
        tone: AppStatusTone.attention,
        actions: [_action('Retry')],
      ),
    },
  );
  kitMotionStillTests(
    'KitPanel',
    builds: {
      'default': () =>
          const KitPanel(title: 'Server', child: Text('Connected over Wi-Fi')),
    },
  );
  kitMotionStillTests(
    'KitPortalScene',
    builds: {'ambient': () => _drawing(ambient: true)},
  );
  kitMotionStillTests(
    'KitProgressView',
    builds: {
      'waiting': () => const KitProgressView(
        progress: KitProgress.waiting(caption: 'Starting'),
      ),
      'known': () => const KitProgressView(
        progress: KitProgress.known(0.4, caption: '40%'),
      ),
    },
    changes: {
      'progress moves': KitMotionChange(
        build: () => const KitProgressView(
          progress: KitProgress.known(0.4, caption: '40%'),
        ),
        act: (tester, stage) => stage.rebuild(
          const KitProgressView(
            progress: KitProgress.known(0.8, caption: '80%'),
          ),
        ),
        shows: '80%',
      ),
    },
  );
  Widget refresh() => KitRefresh(
    onRefresh: () async {},
    child: ListView(children: const [Text('Row')]),
  );
  kitMotionStillTests(
    'KitRefresh',
    builds: {'default': refresh},
    changes: {
      'pulled and released': KitMotionChange(
        build: refresh,
        act: (tester, stage) async {
          await tester.drag(find.text('Row'), const Offset(0, 400));
          // Let the (immediate) refresh run to its end; only the part's
          // leaving is under test.
          await tester.pump();
          await tester.pump();
        },
        shows: 'Row',
      ),
    },
  );
  kitMotionStillTests(
    'KitRequestCard',
    builds: {
      'default': () => KitRequestCard(
        icon: AppIconography.info,
        title: 'Run a command?',
        announcement: 'The agent asks to run a command',
        primary: _action('Allow once'),
        secondary: _action('Deny'),
      ),
    },
  );
  kitMotionStillTests(
    'KitReveal',
    builds: {'default': () => const KitReveal(child: Text('Revealed'))},
    changes: {
      'child arrives': KitMotionChange(
        build: () => const KitReveal(child: null),
        act: (tester, stage) =>
            stage.rebuild(const KitReveal(child: Text('Revealed'))),
        shows: 'Revealed',
      ),
      'child leaves': KitMotionChange(
        build: () => const KitReveal(child: Text('Revealed')),
        act: (tester, stage) => stage.rebuild(const KitReveal(child: null)),
        hides: 'Revealed',
      ),
    },
  );
  kitMotionStillTests(
    'KitRow',
    builds: {
      'default': () => KitRow(
        title: 'Language',
        leading: const KitRowIcon(AppIconography.info),
        supporting: const TextSpan(text: 'English'),
        trailing: const KitChevron(),
        onTap: () {},
      ),
      'disabled': () => const KitRow(title: 'Language', enabled: false),
    },
  );
  kitMotionStillTests(
    'KitRowIcon',
    builds: {
      'current': () => const KitRowIcon(AppIconography.check, current: true),
    },
  );
  Widget menu() => KitRowMenu(
    items: [KitMenuItem(label: 'Rename', onSelected: () {})],
  );
  kitMotionStillTests(
    'KitRowMenu',
    builds: {'default': menu},
    changes: {
      'menu opens': KitMotionChange(
        build: menu,
        act: (tester, stage) async => tester
            .state<PopupMenuButtonState<int>>(find.byType(PopupMenuButton<int>))
            .showButtonMenu(),
        shows: 'Rename',
      ),
    },
  );
  kitMotionStillTests(
    'KitScreen',
    builds: {
      'loading': () => const KitScreen(
        loading: true,
        loadingLabel: 'Loading',
        body: Text('Body'),
      ),
    },
    changes: {
      'loading ends': KitMotionChange(
        build: () => const KitScreen(
          loading: true,
          loadingLabel: 'Loading',
          body: Text('Body'),
        ),
        act: (tester, stage) => stage.rebuild(
          const KitScreen(
            loading: false,
            loadingLabel: 'Loading',
            body: Text('Body'),
          ),
        ),
        shows: 'Body',
      ),
    },
  );
  Widget secret() => KitSecretField(
    controller: TextEditingController(text: 'hunter2'),
    label: 'Password',
    showLabel: 'Show password',
    hideLabel: 'Hide password',
  );
  kitMotionStillTests(
    'KitSecretField',
    builds: {'default': secret},
    changes: {
      'revealed': KitMotionChange(
        build: secret,
        act: (tester, stage) => stage.press(find.byType(KitIconButton)),
        shows: 'hunter2',
      ),
    },
  );
  kitMotionStillTests(
    'KitSheet',
    builds: {
      'loading': () => KitSheet(
        title: 'Language',
        loading: true,
        primary: _action('Use English'),
        child: const Text('English'),
      ),
    },
  );
  kitMotionStillTests(
    'KitSkeletonRows',
    builds: {'default': () => const KitSkeletonRows()},
  );
  kitMotionStillTests(
    'KitSkeletonTranscript',
    builds: {'default': () => const KitSkeletonTranscript()},
  );
  kitMotionStillTests(
    'KitStateView',
    builds: {
      'working': () => const KitStateView(
        icon: AppIconography.info,
        title: 'Connecting',
        progress: KitProgress.waiting(caption: 'Reaching the server'),
      ),
      'illustrated': () => KitStateView(
        icon: AppIconography.info,
        title: 'Waiting for the server',
        illustration: KitSceneProbe(const KitPortalScene()),
        illustrationAmbient: true,
      ),
    },
    changes: {
      'details open': KitMotionChange(
        build: () => const KitStateView(
          icon: AppIconography.info,
          title: 'Could not connect',
          details: 'connection refused at 10.0.0.2:4096',
        ),
        act: (tester, stage) =>
            stage.press(find.byKey(const ValueKey('kit-state-details'))),
        shows: 'connection refused at 10.0.0.2:4096',
      ),
    },
  );
  kitMotionStillTests(
    'KitStatusLine',
    builds: {
      'default': () => KitStatusLine(
        icon: AppIconography.info,
        message: 'Reconnecting',
        tone: AppStatusTone.progress,
        action: _action('Retry'),
      ),
    },
  );
  kitMotionStillTests(
    'KitStatusMark',
    builds: {
      for (final state in KitMarkState.values)
        state.name: () => KitStatusMark(state: state),
    },
    changes: {
      'working to done': KitMotionChange(
        build: () => const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitStatusMark(state: KitMarkState.working),
            Text('Step'),
          ],
        ),
        act: (tester, stage) => stage.rebuild(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KitStatusMark(state: KitMarkState.done),
              Text('Step'),
            ],
          ),
        ),
        shows: 'Step',
      ),
    },
  );
  Widget switchRow(bool value) =>
      KitSwitchRow(title: 'Vibration', value: value, onChanged: (_) {});
  kitMotionStillTests(
    'KitSwitchRow',
    builds: {'default': () => switchRow(true)},
    changes: {
      'switched on': KitMotionChange(
        build: () => switchRow(false),
        act: (tester, stage) => stage.rebuild(switchRow(true)),
        shows: 'Vibration',
      ),
    },
  );
  Widget tabs(int index) => SizedBox(
    height: 200,
    child: KitTabSwitcher(
      index: index,
      children: const [Text('One'), Text('Two')],
    ),
  );
  kitMotionStillTests(
    'KitTabSwitcher',
    builds: {'default': () => tabs(1)},
    changes: {
      'index changes': KitMotionChange(
        build: () => tabs(1),
        act: (tester, stage) => stage.rebuild(tabs(0)),
        shows: 'One',
      ),
    },
  );
  kitMotionStillTests(
    'KitTaskMark',
    builds: {
      for (final state in KitTaskState.values)
        state.name: () => KitTaskMark(state: state),
    },
  );
  kitMotionStillTests(
    'LoadingList',
    builds: {'default': () => const LoadingList()},
  );
  kitMotionStillTests(
    'ProductEmptyState',
    builds: {
      'default': () => const ProductEmptyState(
        icon: AppIconography.info,
        title: 'No servers',
        message: 'Add one to start.',
      ),
    },
  );
  kitMotionStillTests(
    'ProductErrorState',
    builds: {
      'default': () =>
          ProductErrorState(message: 'Could not load', onRetry: () async {}),
    },
  );
  kitMotionStillTests(
    'ProductInlineEmpty',
    builds: {
      'default': () => const ProductInlineEmpty(
        icon: AppIconography.info,
        title: 'Nothing here',
        message: 'Items appear here.',
      ),
    },
  );
  kitMotionStillTests(
    'SectionLabel',
    builds: {'default': () => const SectionLabel('Servers')},
  );
  kitMotionStillTests(
    'showKitConfirm',
    opens: {
      'destructive': const KitMotionOpen(_openConfirm, shows: _confirmTitle),
    },
    changes: {'dismissed': kitModalDismiss(_openConfirm, shows: _confirmTitle)},
  );
  kitMotionStillTests(
    'showKitSheet',
    opens: {
      'content': const KitMotionOpen(_openSheet, shows: 'English'),
      'full': KitMotionOpen(
        (context) => showKitSheet<void>(
          context,
          title: 'Language',
          height: KitSheetHeight.full,
          body: (_) => const Text('English'),
        ),
        shows: 'English',
      ),
    },
    changes: {'dismissed': kitModalDismiss(_openSheet, shows: 'English')},
  );
}

void main() {
  group('manifest', () {
    final manifest = readKitManifest();
    final registered = readKitMotionRegistrations();
    // G4's definition: drawn parts, drawings and openers need samples;
    // scopes draw nothing and need none.
    final needSamples = <String>{
      for (final p in manifest.parts)
        if (p.kind != KitManifestKind.scope) p.name,
      for (final o in manifest.openers) o.name,
    };
    final exported = <String>{
      for (final p in manifest.parts) p.name,
      for (final o in manifest.openers) o.name,
    };

    test('the G4 manifest is read (the parser still works)', () {
      // A parser regression must fail loudly, not pass an empty manifest.
      expect(
        needSamples,
        containsAll([
          'KitSheet',
          'showKitSheet',
          'showKitConfirm',
          'KitConfirmSheet',
          'KitStatusMark',
          'KitPortalScene',
          'SectionLabel',
        ]),
      );
      // Not parts: data, tokens, controllers, builders, unexported widgets,
      // and scopes.
      for (final notAPart in [
        'KitAction',
        'KitTokens',
        'KitDraft',
        'KitEffects',
        'KitPageTransitionsBuilder',
        'GatedRow',
        'TerminalKeyBar',
        'KitEffectsScope',
      ]) {
        expect(needSamples, isNot(contains(notAPart)), reason: notAPart);
      }
    });

    test('every kit.dart part has reduced-motion samples (G8x)', () {
      final files = {
        for (final p in manifest.parts) p.name: p.file,
        for (final o in manifest.openers) o.name: o.file,
      };
      final missing = [
        for (final name in needSamples.toList()..sort())
          if (!registered.containsKey(name)) '$name (${files[name]})',
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'Each part kit.dart exports needs kitMotionStillTests(\'<Name>\', '
            '...) in its own test/kit/kit_<snake>_test.dart '
            '(test/kit/kit_motion_still.dart shows how; a stateful part also '
            'registers changes:).',
      );
    });

    test('this file registers only the parts that predate G8x', () {
      final here = _withoutComments(
        File('test/kit_motion_test.dart').readAsStringSync(),
      );
      final own = {for (final m in _registration.allMatches(here)) m[1]!};
      expect(
        own.difference(_predatesG8x),
        isEmpty,
        reason:
            'A new part registers its samples in its own test file, not in '
            'kit_motion_test.dart (PROC-13).',
      );
    });

    test('the ratchet only shrinks and names real samples', () {
      final baseline = readKitMotionBaseline();
      expect(
        baseline.toSet().difference(_frozenBaseline),
        isEmpty,
        reason:
            '$kitMotionBaselinePath gained keys beyond the frozen G8x '
            'baseline: fix the part instead; the ratchet only shrinks '
            '(PROC-13)',
      );
      expect(baseline.toSet(), hasLength(baseline.length), reason: 'dupes');
      final stills = KitStill.values.map((s) => s.name).toSet();
      for (final key in baseline) {
        final fields = key.split(' / ');
        expect(fields, hasLength(3), reason: 'malformed baseline key "$key"');
        final [part, sample, still] = fields;
        expect(_predatesG8x, contains(part), reason: key);
        expect(stills, contains(still), reason: key);
        expect(
          kitMotionSamples[part] ?? const <String>{},
          contains(sample),
          reason: '"$key": $part registers no sample "$sample" here',
        );
      }
    });

    test('registrations name parts kit.dart exports', () {
      expect(
        registered.keys.toSet().difference(exported),
        isEmpty,
        reason: 'kitMotionStillTests names a part kit.dart does not export',
      );
    });
  });

  _predatingParts();

  // The samples exercise motion: with motion on, the same parts move.
  testWidgets('with motion on, KitStatusMark working spins', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: KitStatusMark(state: KitMarkState.working)),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('with motion on, KitExpandRow animates its opening', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KitExpandRow(title: 'Advanced', children: [Text('Port')]),
        ),
      ),
    );
    // The callback, not a tap: a tap's ink splash would move regardless.
    tester.widget<KitRow>(find.byType(KitRow)).onTap!();
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  for (final still in KitStill.values) {
    testWidgets('KitStatusMark working shows its still dot under '
        '${still.name}', (tester) async {
      await tester.pumpWidget(
        kitStillApp(const KitStatusMark(state: KitMarkState.working), still),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(AppIconography.statusDot), findsOneWidget);
    });
  }
}
