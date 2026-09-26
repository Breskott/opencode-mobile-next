// Gate G8x (docs/ux-system/revamp/STANDARDS.md §18, rule MOT-7; absolute):
// every part lib/ui/kit/kit.dart exports settles after one pump() with no
// ticker running, under the system's "remove animations" AND under
// Settings › Appearance › Animations: Off (KitEffects.motion).
//
// Manifest-driven (PROC-13): the parts are read from kit.dart's exports, not
// listed by hand. The parts that predate the gate register their samples
// below; a part added later registers its own with kitMotionStillTests(...)
// in its own test/kit/kit_<snake>_test.dart (see test/kit/kit_motion_still.dart),
// so kit units never edit this file. A part with no registration anywhere
// under test/ fails "every kit.dart part has reduced-motion samples".
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit/kit_motion_still.dart';

// ---------------------------------------------------------------------------
// The manifest: what kit.dart exports.

/// One exported kit part: a public widget class, a drawn scene or a
/// `showKit…` modal function.
class KitManifestPart {
  const KitManifestPart(this.name, this.kind, this.file);

  final String name;
  final String kind; // widget | scene | modal
  final String file;

  @override
  String toString() => '$name ($kind, $file)';
}

final _export = RegExp(
  r'''^export\s+'([^']+)'((?:\s+(?:show|hide)\s+[\w\s,]+?)*)\s*;''',
  multiLine: true,
);
final _part = RegExp(r'''^part\s+'([^']+)'\s*;''', multiLine: true);
final _class = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'class\s+(\w+)(?:<[^{]*?>)?\s+extends\s+(\w+)',
  multiLine: true,
);
final _modal = RegExp(
  r'^(?:Future<[^\n]*?>|void)\s+(showKit\w*)\s*(?:<[^>]*>)?\s*\(',
  multiLine: true,
);

/// Framework bases that make a class a widget. Any base whose name ends in
/// `Widget` counts as well.
const _widgetBases = {
  'InheritedNotifier',
  'InheritedTheme',
  'InheritedModel',
  'ScrollView',
  'BoxScrollView',
};

String _resolve(String from, String uri) {
  final parts = [...File(from).parent.uri.pathSegments.where((s) => s != '')];
  for (final segment in uri.split('/')) {
    if (segment == '..') {
      parts.removeLast();
    } else if (segment != '.') {
      parts.add(segment);
    }
  }
  final absolute = from.startsWith('/');
  return '${absolute ? '/' : ''}${parts.join('/')}';
}

/// Every name [file] (with its parts and re-exports) makes public, with the
/// base class of each class and whether it is a `showKit…` function.
Map<String, ({String? base, String file})> _declared(
  String file, [
  Set<String>? seen,
]) {
  seen ??= {};
  if (!seen.add(file)) return {};
  final source = File(file).readAsStringSync();
  final names = <String, ({String? base, String file})>{};
  for (final m in _class.allMatches(source)) {
    if (!m[1]!.startsWith('_')) names[m[1]!] = (base: m[2]!, file: file);
  }
  for (final m in _modal.allMatches(source)) {
    names[m[1]!] = (base: null, file: file);
  }
  for (final m in _part.allMatches(source)) {
    names.addAll(_declared(_resolve(file, m[1]!), seen));
  }
  for (final m in _export.allMatches(source)) {
    if (m[1]!.startsWith('package:') || m[1]!.startsWith('dart:')) continue;
    final exported = _declared(_resolve(file, m[1]!), seen);
    names.addAll(_combinators(exported, m[2] ?? ''));
  }
  return names;
}

Map<String, T> _combinators<T>(Map<String, T> names, String combinators) {
  var out = Map.of(names);
  for (final c in RegExp(
    r'(show|hide)\s+([\w\s,]+?)(?=\s+(?:show|hide)\b|$)',
  ).allMatches(combinators.trim())) {
    final listed = c[2]!.split(',').map((s) => s.trim()).toSet();
    out = {
      for (final e in out.entries)
        if ((c[1] == 'show') == listed.contains(e.key)) e.key: e.value,
    };
  }
  return out;
}

/// The parts `lib/ui/kit/kit.dart` exports (the G4 manifest).
List<KitManifestPart> readKitManifest([
  String kitDart = 'lib/ui/kit/kit.dart',
]) {
  final public = _declared(kitDart);
  // Every class under lib/ui/kit, exported or not, so that a part extending
  // another kit widget or scene resolves.
  final bases = <String, String>{
    for (final f in Directory('lib/ui/kit').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart'))
        for (final m in _class.allMatches(f.readAsStringSync())) m[1]!: m[2]!,
    for (final e in public.entries)
      if (e.value.base != null) e.key: e.value.base!,
  };
  bool reaches(String name, bool Function(String) target) {
    final seen = <String>{};
    String? at = name;
    while (at != null && seen.add(at)) {
      if (target(at)) return true;
      at = bases[at];
    }
    return false;
  }

  bool isWidget(String base) =>
      base.endsWith('Widget') || _widgetBases.contains(base);
  final parts = <KitManifestPart>[];
  for (final MapEntry(key: name, value: d) in public.entries) {
    final file = d.file.replaceFirst(RegExp(r'^.*?lib/'), 'lib/');
    if (d.base == null) {
      parts.add(KitManifestPart(name, 'modal', file));
    } else if (reaches(d.base!, (b) => b == 'KitScene')) {
      parts.add(KitManifestPart(name, 'scene', file));
    } else if (reaches(d.base!, isWidget)) {
      parts.add(KitManifestPart(name, 'widget', file));
    }
  }
  parts.sort((a, b) => a.name.compareTo(b.name));
  return parts;
}

final _registration = RegExp(r'''kitMotionStillTests\(\s*'(\w+)'\s*,''');

/// Part name → the test files under [root] that register samples for it.
Map<String, Set<String>> readKitMotionRegistrations([String root = 'test']) {
  final found = <String, Set<String>>{};
  for (final f in Directory(root).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('_test.dart')) continue;
    for (final m in _registration.allMatches(f.readAsStringSync())) {
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
  'KitEffectsScope',
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

KitAction _action(String label) => KitAction(label: label, onPressed: () {});

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
  kitMotionStillTests(
    'KitAnimatedRows',
    builds: {
      'default': () => const KitAnimatedRows(
        children: [
          Text('Alpha', key: ValueKey('a')),
          Text('Beta', key: ValueKey('b')),
          Text('Gamma', key: ValueKey('c')),
        ],
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
  );
  kitMotionStillTests('KitChevron', builds: {'default': KitChevron.new});
  kitMotionStillTests(
    'KitConfirmSheet',
    builds: {
      'default': () => KitConfirmSheet(
        title: 'Delete fox?',
        body: 'The conversation is removed from the server.',
        confirmLabel: 'Delete conversation',
        kind: KitConfirmKind.destructive,
        onConfirm: () {},
        onCancel: () {},
      ),
      'working': () => KitConfirmSheet(
        title: 'Delete fox?',
        body: 'The conversation is removed from the server.',
        confirmLabel: 'Delete conversation',
        onConfirm: () {},
        onCancel: () {},
        working: true,
      ),
    },
  );
  kitMotionStillTests(
    'KitEffectsScope',
    builds: {
      'default': () => const KitEffectsScope(
        effects: KitEffects.defaults,
        child: Text('Inside'),
      ),
    },
  );
  kitMotionStillTests(
    'KitEntrance',
    builds: {'default': () => const KitEntrance(child: Text('Arrives'))},
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
    builds: {
      'entrance': () => const KitIllustration(scene: KitPortalScene()),
      'ambient': () =>
          const KitIllustration(scene: KitPortalScene(), ambient: true),
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
    builds: {
      'ambient': () =>
          const KitIllustration(scene: KitPortalScene(), ambient: true),
    },
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
  );
  kitMotionStillTests(
    'KitRefresh',
    builds: {
      'default': () => KitRefresh(
        onRefresh: () async {},
        child: ListView(children: const [Text('Row')]),
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
  kitMotionStillTests(
    'KitRowMenu',
    builds: {
      'default': () => KitRowMenu(
        items: [KitMenuItem(label: 'Rename', onSelected: () {})],
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
  );
  kitMotionStillTests(
    'KitSecretField',
    builds: {
      'default': () => KitSecretField(
        controller: TextEditingController(text: 'hunter2'),
        label: 'Password',
        showLabel: 'Show password',
        hideLabel: 'Hide password',
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
      'illustrated': () => const KitStateView(
        icon: AppIconography.info,
        title: 'Waiting for the server',
        illustration: KitPortalScene(),
        illustrationAmbient: true,
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
  );
  kitMotionStillTests(
    'KitSwitchRow',
    builds: {
      'default': () =>
          KitSwitchRow(title: 'Vibration', value: true, onChanged: (_) {}),
    },
  );
  kitMotionStillTests(
    'KitTabSwitcher',
    builds: {
      'default': () =>
          KitTabSwitcher(index: 1, children: const [Text('One'), Text('Two')]),
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
      'destructive': (context) => showKitConfirm(
        context,
        title: 'Delete fox?',
        body: 'The conversation is removed from the server.',
        confirmLabel: 'Delete conversation',
        kind: KitConfirmKind.destructive,
      ),
    },
  );
  kitMotionStillTests(
    'showKitSheet',
    opens: {
      'content': (context) => showKitSheet<void>(
        context,
        title: 'Language',
        body: (_) => const Text('English'),
      ),
      'full': (context) => showKitSheet<void>(
        context,
        title: 'Language',
        height: KitSheetHeight.full,
        body: (_) => const Text('English'),
      ),
    },
  );
}

void main() {
  group('manifest', () {
    final manifest = readKitManifest();
    final registered = readKitMotionRegistrations();

    test('kit.dart exports are read (the parser still works)', () {
      final names = manifest.map((p) => p.name).toSet();
      // A parser regression must fail loudly, not pass an empty manifest.
      expect(
        names,
        containsAll([
          'KitSheet',
          'showKitSheet',
          'showKitConfirm',
          'KitConfirmSheet',
          'KitStatusMark',
          'KitPortalScene',
          'KitEffectsScope',
          'SectionLabel',
        ]),
      );
      // Not parts: data, tokens, controllers, builders, unexported widgets.
      for (final notAPart in [
        'KitAction',
        'KitTokens',
        'KitDraft',
        'KitEffects',
        'KitPageTransitionsBuilder',
        'GatedRow',
        'TerminalKeyBar',
      ]) {
        expect(names, isNot(contains(notAPart)), reason: notAPart);
      }
    });

    test('every kit.dart part has reduced-motion samples (G8x)', () {
      final missing = [
        for (final part in manifest)
          if (!registered.containsKey(part.name)) part,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'Each part kit.dart exports needs kitMotionStillTests(\'<Name>\', '
            '...) in its own test/kit/kit_<snake>_test.dart '
            '(test/kit/kit_motion_still.dart shows how).',
      );
    });

    test('this file registers only the parts that predate G8x', () {
      final here = File('test/kit_motion_test.dart').readAsStringSync();
      final own = {for (final m in _registration.allMatches(here)) m[1]!};
      expect(
        own.difference(_predatesG8x),
        isEmpty,
        reason:
            'A new part registers its samples in its own test file, not in '
            'kit_motion_test.dart (PROC-13).',
      );
    });

    test('the ratchet lists only parts that predate G8x', () {
      final stills = KitStill.values.map((s) => s.name).toSet();
      for (final key in readKitMotionBaseline()) {
        final fields = key.split(' / ');
        expect(fields, hasLength(3), reason: 'malformed baseline key "$key"');
        expect(
          _predatesG8x,
          contains(fields.first),
          reason:
              '"$key": a part added after G8x starts at zero and is never '
              'baselined (PROC-13)',
        );
        expect(stills, contains(fields.last), reason: key);
        expect(
          File('test/kit_motion_test.dart').readAsStringSync(),
          contains("'${fields[1]}':"),
          reason: '"$key" names no sample here: remove the stale entry',
        );
      }
    });

    test('registrations name parts kit.dart exports', () {
      final names = manifest.map((p) => p.name).toSet();
      expect(
        registered.keys.toSet().difference(names),
        isEmpty,
        reason: 'kitMotionStillTests names a part kit.dart does not export',
      );
    });
  });

  _predatingParts();

  // The samples exercise motion: with motion on, the same part moves.
  testWidgets('with motion on, KitStatusMark working spins', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: KitStatusMark(state: KitMarkState.working)),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
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
