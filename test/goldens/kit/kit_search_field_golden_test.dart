// Gallery (gate G4) for KitSearchField, docs/ux-system/kit-api/KitSearchField.md;
// K2 §1.5, §2.12, §8.2.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_search_field_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitSearchField.md, R15): Arabic
// is dropped — no Arabic/RTL galleries; galleries are phone 412x915 and
// one wide size 1280x800 only, light and dark, with `typing` also at text
// 2.0 at both sizes (TEST-9, G4). This
// replaces the spec's own "Galleries required" list (32 PNGs), a PROC-20
// note recorded in the unit's QA record.
//
// kit-KitScreen-v2 (the `search` slot, C06) and KitTopBar have not merged,
// so the fixture pins the field in today's KitScreen `header` under a plain
// title row standing in for the top bar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_screen.dart';
import 'package:opencode_mobile/ui/kit/kit_search_field.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

Widget _fixture(
  BuildContext context, {
  required KitSearchField field,
  Widget? body,
}) {
  final tokens = KitTokens.of(context);
  return Scaffold(
    body: SafeArea(
      child: KitScreen(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.gutter,
              tokens.space3,
              tokens.gutter,
              tokens.space3,
            ),
            child: const KitText('Settings', role: KitTextRole.title),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.gutter,
              0,
              tokens.gutter,
              tokens.space3,
            ),
            child: field,
          ),
        ],
        body:
            body ??
            ListView(
              padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
              children: [
                for (final name in const [
                  'Appearance',
                  'Notifications',
                  'Voice',
                  'Servers',
                ])
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.space3),
                    child: KitText(name, role: KitTextRole.rowTitle),
                  ),
              ],
            ),
      ),
    ),
  );
}

/// Opens [page] as a route with no transition.
Future<void> Function(BuildContext) _open(
  Widget Function(BuildContext context) page,
) =>
    (context) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (inner, _, _) => page(inner),
      ),
    );

/// A state at the phone size.
Future<void> _shot(
  WidgetTester tester, {
  required String state,
  required bool light,
  required Widget Function(BuildContext context) page,
}) => kitGalleryShot(
  tester,
  name: kitGalleryName(
    'kit_search_field_$state',
    const Size(412, 915),
    light: light,
  ),
  size: const Size(412, 915),
  light: light,
  open: _open(page),
);

TextEditingController _query(String text) => TextEditingController(text: text);

final _filters = [
  KitMenuItem(label: 'Symbols', onSelected: () {}),
  KitMenuItem(label: 'Files', onSelected: () {}),
];

final Map<String, Widget Function(BuildContext)> _states = {
  'empty': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search settings',
      onChanged: (_) {},
      filters: _filters,
    ),
  ),
  'typing': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search settings',
      controller: _query('notif'),
      onChanged: (_) {},
      filters: _filters,
    ),
  ),
  'results': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search settings',
      controller: _query('notif'),
      onChanged: (_) {},
      resultCount: 12,
    ),
  ),
  'partial': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search settings',
      controller: _query('notif'),
      onChanged: (_) {},
      resultCount: 12,
      partial: true,
    ),
  ),
  'nomatch': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search models',
      controller: _query('opus'),
      onChanged: (_) {},
      resultCount: 0,
    ),
    body: ListView(
      padding: EdgeInsets.symmetric(horizontal: KitTokens.of(c).gutter),
      children: [
        KitSearchNoMatch(
          query: 'opus',
          what: 'models',
          onClear: () {},
          action: KitAction(label: 'Search all projects', onPressed: () {}),
        ),
      ],
    ),
  ),
  'filtered': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search files',
      controller: _query('main'),
      onChanged: (_) {},
      resultCount: 3,
      filters: _filters,
      activeFilter: 'Symbols',
      onClearFilter: () {},
    ),
  ),
  'disabled': (c) => _fixture(
    c,
    field: KitSearchField(
      label: 'Search sessions',
      onChanged: (_) {},
      enabled: false,
      disabledReason: 'Connect to a server to search its sessions',
    ),
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    for (final entry in _states.entries) {
      testWidgets('KitSearchField ${entry.key} ($theme)', (tester) async {
        await _shot(tester, state: entry.key, light: light, page: entry.value);
      });
    }
    testWidgets('KitSearchField typing 1280x800 ($theme)', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_search_field_typing',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        open: _open(_states['typing']!),
      );
    });
    for (final size in kitGalleryScaledSizes) {
      testWidgets(
        'KitSearchField typing · text 2.0 · ${kitGallerySize(size)} · $theme',
        (tester) async {
          await kitGalleryShot(
            tester,
            name: kitGalleryName(
              'kit_search_field_typing',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            open: _open(_states['typing']!),
          );
        },
      );
    }
  }
}
