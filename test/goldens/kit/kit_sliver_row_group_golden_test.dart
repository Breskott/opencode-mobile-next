// Gallery (gate G4) for KitSliverRowGroup (slice-R4): Work's head rows and
// its recent conversations on one surface1 panel, text-inset hairlines
// between rows, the label on the one inset every section label shares.
//
// Phone 412x915 and one wide size (1280x800), light and dark, plus the
// phone at text 2x (owner decision 2026-09-27: no Arabic galleries).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_sliver_row_group_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_sliver_row_group.dart';

import 'kit_gallery.dart';

void _noop() {}

const _recent = [
  ('Fix the login redirect loop', 'Needs you · asked 2 min ago'),
  ('Add dark mode to settings', 'Working · 6 steps so far'),
  ('Explain the release script', 'Done · 1 h ago'),
  ('Rename the sync service', 'Done · yesterday'),
];

KitRow _row(String title, String supporting, IconData icon) => KitRow(
  leading: KitRowIcon(icon),
  title: title,
  supporting: TextSpan(text: supporting),
  trailing: const KitChevron(),
  onTap: _noop,
);

Widget _list() => CustomScrollView(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  slivers: [
    KitSliverRowGroup(
      label: 'Recent conversations',
      itemCount: _recent.length,
      itemBuilder: (_, i) =>
          _row(_recent[i].$1, _recent[i].$2, AppIconography.agent),
      children: [
        _row(
          'New conversation',
          'In oc_app on the workstation',
          AppIconography.chat,
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      testWidgets('head and recent rows · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_sliver_row_group_default',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _list(),
        );
      });
    }
    // Text at 2x on the phone: the trailing part drops under the words,
    // nothing clips (G4, A11Y-8).
    testWidgets('head and recent rows · text 2x · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_sliver_row_group_default',
          const Size(412, 915),
          light: light,
          text2: true,
        ),
        size: const Size(412, 915),
        light: light,
        textScale: 2,
        child: _list(),
      );
    });
  }
}
