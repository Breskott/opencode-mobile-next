// Impeller renders of the floating glass for docs/qa/slice-glass-crisp-2026-09-28:
// a Work-like page (the owner's build 2057 screenshot: a KitScreen under
// KitNav with the shell top bar, a title, rows with icon tiles, the green
// "New conversation" action above the dock), light and dark, at rest and scrolled so a colourful list passes
// under the dock and the top controls.
//
// Uses only KitNav, KitScreen, KitTopBar.shell and KitShellControls, so the
// same script renders the base commit too (before):
//
//   flutter test --enable-impeller --concurrency=1 tool/capture/glass_crisp_test.dart
//   GLASS_CRISP_OUT=<abs path>/before flutter test --enable-impeller ...   (base)
//
// Liquid needs Impeller (--enable-impeller); without it the frosted look is
// rendered and the files are named frosted-*.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';

import 'fixtures.dart';

final _out =
    Platform.environment['GLASS_CRISP_OUT'] ??
    'docs/qa/slice-glass-crisp-2026-09-28/renders/after';
const _size = Size(412, 915);

List<KitNavDestination> _destinations() => const [
  KitNavDestination(
    label: 'Work',
    icon: AppIconography.workspace,
    selectedIcon: AppIconography.workspaceSelected,
    key: ValueKey('nav-work'),
  ),
  KitNavDestination(
    label: 'Inbox',
    icon: AppIconography.activity,
    selectedIcon: AppIconography.activitySelected,
    key: ValueKey('nav-inbox'),
  ),
  KitNavDestination(
    label: 'Project',
    icon: AppIconography.files,
    selectedIcon: AppIconography.filesSelected,
    key: ValueKey('nav-project'),
  ),
  KitNavDestination(
    label: 'Settings',
    icon: AppIconography.settings,
    key: ValueKey('nav-settings'),
  ),
];

const _marks = [
  Color(0xFF3DDC8A),
  Color(0xFF7FB0FF),
  Color(0xFFFFB88A),
  Color(0xFFC7A6FF),
];

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    Widget row(String title, String meta, {Color? mark}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mark ?? roles.surface3,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KitText(title, role: KitTextRole.rowTitle),
                KitText(meta, tone: KitTextTone.secondary),
              ],
            ),
          ),
        ],
      ),
    );
    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
      children: [
        const KitText('gastown.furiosa', role: KitTextRole.title),
        const SizedBox(height: 16),
        row('Accessing iptv project on phone', '13h ago'),
        row('Carpool organizer web page for wife', '1d ago'),
        row(
          'Search all conversations',
          'Every project on this server, archived ones too',
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < 24; i++)
          row(
            'Conversation ${i + 1}: fix the reconnect loop',
            '${i + 2} files changed · ${i + 1} h ago',
            mark: _marks[i % _marks.length],
          ),
      ],
    );
  }
}

/// [pinned]: the Work page's pinned "New conversation" block; without it
/// the list scrolls on under the dock (the dimming check: letters behind the
/// glass must read as colour, never as letters).
class _Shell extends StatefulWidget {
  const _Shell({required this.pinned});

  final bool pinned;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: KitNav(
        destinations: _destinations(),
        selected: _selected,
        onSelected: (i) => setState(() => _selected = i),
        child: KitScreen(
          topBar: KitTopBar.shell(
            controls: KitShellControls(
              server: 'This phone',
              serverStatus: 'Connected',
              serverTone: AppStatusTone.ok,
              onServer: () {},
              onSearch: () {},
            ),
          ),
          body: const _Page(),
          bottom: widget.pinned
              ? KitButton(
                  role: KitButtonRole.primary,
                  label: 'New conversation',
                  icon: AppIconography.add,
                  onPressed: () {},
                )
              : null,
        ),
      ),
    );
  }
}

typedef _Then = Future<void> Function(WidgetTester tester);

final Map<String, _Then> _states = {
  'rest': (tester) async {},
  'scrolled': (tester) async {
    await tester.drag(
      find.byKey(const ValueKey('content')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
  },
};

void main() {
  setUpAll(loadCaptureFonts);
  tearDown(KitGlassShader.debugReset);
  final liquid = ui.ImageFilter.isShaderFilterSupported;
  final look = liquid ? 'liquid' : 'frosted';

  // Graphite (the default) and one other theme pack, which keeps its own
  // accent in its fields.
  for (final pack in [null, ThemePackId.catppuccin]) {
    for (final light in [true, false]) {
      for (final MapEntry(key: state, value: then) in _states.entries) {
        final name =
            '$look-$state-${light ? 'light' : 'dark'}'
            '${pack == null ? '' : '-${pack.name}'}';
        testWidgets(name, (tester) async {
          tester.view
            ..physicalSize = _size * captureDevicePixelRatio
            ..devicePixelRatio = captureDevicePixelRatio;
          addTearDown(tester.view.reset);
          if (liquid) {
            KitGlassShader.program.value = await tester.runAsync(
              () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
            );
          } else {
            KitGlassShader.debugSupportedOverride = false;
          }
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: switch ((pack, light)) {
                  (null, true) => AppTheme.light(),
                  (null, false) => AppTheme.dark(),
                  (final id?, true) => AppTheme.light(themePack(id)),
                  (final id?, false) => AppTheme.dark(themePack(id)),
                },
                home: KitEffectsScope(
                  effects: KitEffects.defaults,
                  child: _Shell(pinned: state == 'rest'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await then(tester);
          await writePng('$_out/$name.png', await capturePng(tester, boundary));
        });
      }
    }
  }
}
