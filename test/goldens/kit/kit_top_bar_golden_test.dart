// Gallery (gate G4) for KitTopBar, docs/ux-system/kit-api/KitTopBar.md;
// K2 §1.18, §8.2; VL §6 (glass top controls and PC toolbar).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_top_bar_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitTopBar.md, R15): Arabic is
// dropped and galleries are phone 412x915 and one wide size 1280x800 only,
// light and dark. This replaces KitTopBar.md's own list (360x800, 915x412,
// 800x1280, 1600x1000, text 2.0 and Arabic RTL); the 200 % text behaviour
// is covered by test/kit/kit_top_bar_test.dart instead.
//
// kitGalleryPart centres its child at most 720 dp wide, so the 1280x800
// shots show the bar at that width; the window class (large) still decides
// its labelled actions and glass toolbar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';

import 'kit_gallery.dart';

void _noop() {}

final _actions = [
  KitAction(
    label: 'Stop task',
    icon: AppIcons.stop,
    onPressed: _noop,
    shortcut: 'Ctrl+.',
  ),
  KitAction(label: 'Copy link', icon: AppIcons.copy, onPressed: _noop),
];

final _menu = [KitMenuItem(label: 'Rename', onSelected: _noop)];

/// The bar over a few body rows, as it sits at the top of a screen.
Widget _screen(Widget bar) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    bar,
    const KitRow(
      title: 'Fix the login redirect',
      supporting: TextSpan(text: 'Working · 2 min'),
    ),
    const KitRow(
      title: 'Update the docs',
      supporting: TextSpan(text: 'Done · yesterday'),
    ),
  ],
);

KitShellControls _controls({
  String status = 'Connected',
  AppStatusTone tone = AppStatusTone.ok,
  int needsYou = 0,
  KitShellControlsLayout layout = KitShellControlsLayout.bar,
}) => KitShellControls(
  server: 'Laptop',
  serverStatus: status,
  serverTone: tone,
  onServer: _noop,
  needsYou: needsYou,
  project: layout == KitShellControlsLayout.sidebar ? 'shopfront' : null,
  onProject: layout == KitShellControlsLayout.sidebar ? _noop : null,
  onSearch: _noop,
  layout: layout,
);

final Map<String, Widget Function()> _phoneStates = {
  'kit_top_bar_default': () => KitTopBar(
    title: 'Fix login',
    exit: KitTopBarExit.back,
    actions: _actions.take(1).toList(),
    menu: _menu,
  ),
  'kit_top_bar_subtitle_working': () => KitTopBar(
    title: 'Fix login',
    subtitle: 'Working · 2 min',
    subtitleTone: AppStatusTone.progress,
    exit: KitTopBarExit.back,
    actions: _actions,
  ),
  'kit_top_bar_needs_you': () => KitTopBar(
    title: 'Fix login',
    subtitle: 'Laptop',
    needsYou: 1,
    exit: KitTopBarExit.back,
    actions: _actions,
  ),
  'kit_top_bar_switcher': () => KitTopBar(
    title: 'shopfront',
    onTitleTap: _noop,
    titleTapLabel: 'Switch project',
    needsYou: 2,
    exit: KitTopBarExit.none,
    menu: _menu,
  ),
  'kit_top_bar_brand': () => const KitTopBar(
    title: 'Open Portal',
    brand: true,
    exit: KitTopBarExit.none,
  ),
  'kit_top_bar_close': () =>
      const KitTopBar(title: 'New server', exit: KitTopBarExit.close),
  'kit_top_bar_shell_connected': () => KitTopBar.shell(controls: _controls()),
  'kit_top_bar_shell_reconnecting': () => KitTopBar.shell(
    controls: _controls(status: 'Reconnecting', tone: AppStatusTone.progress),
  ),
  'kit_top_bar_shell_needs_you': () =>
      KitTopBar.shell(controls: _controls(needsYou: 1), menu: _menu),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    for (final entry in _phoneStates.entries) {
      testWidgets('${entry.key} ${light ? 'light' : 'dark'}', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(entry.key, const Size(412, 915), light: light),
          size: const Size(412, 915),
          light: light,
          child: _screen(entry.value()),
        );
      });
    }

    testWidgets('kit_top_bar_default 1280x800 ${light ? 'light' : 'dark'}', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_top_bar_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _screen(
          KitTopBar(
            title: 'Fix login',
            subtitle: 'Working · 2 min',
            exit: KitTopBarExit.back,
            actions: _actions,
            menu: _menu,
          ),
        ),
      );
    });

    testWidgets('kit_top_bar_shell_sidebar 1280x800 '
        '${light ? 'light' : 'dark'}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_top_bar_shell_sidebar',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _controls(
                layout: KitShellControlsLayout.sidebar,
                needsYou: 1,
              ),
            ),
          ),
        ),
      );
    });
  }
}
