// Gallery (gate G4) for KitSectionLabel and KitRowGroup's label on the one
// inset (slice-R4): a page with a labelled group first (no gap above it), a
// KitSectionLabel with an explanation and a trailing count, and a second
// labelled group one section gap below. Every label's words start on the
// same line as the rows' panel edge.
//
// Phone 412x915 and one wide size (1280x800), light and dark, plus the
// phone at text 2x (owner decision 2026-09-27: no Arabic galleries).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_section_label_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_section_label.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

void _noop() {}

KitRow _row(String title, String supporting, IconData icon) => KitRow(
  leading: KitRowIcon(icon),
  title: title,
  supporting: TextSpan(text: supporting),
  trailing: const KitChevron(),
  onTap: _noop,
);

Widget _page() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    KitRowGroup(
      label: 'Planner',
      children: [
        _row('Model', 'Opus 5.5 · plans before it edits', AppIconography.agent),
      ],
    ),
    KitSectionLabel(
      'MCP servers',
      explanation:
          'Tools the agent can call, served by programs this server runs.',
      trailing: const KitText(
        '3 connected',
        role: KitTextRole.caption,
        tone: KitTextTone.secondary,
      ),
    ),
    KitRowGroup(
      children: [
        _row('GitHub', 'Connected · 12 tools', AppIconography.link),
        _row('Browser', 'Connected · 8 tools', AppIconography.terminal),
      ],
    ),
    KitRowGroup(
      label: 'Supervision',
      children: [
        _row('Ask before', 'Edits outside the project', AppIconography.chat),
      ],
    ),
  ],
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      testWidgets('page labels · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_section_label_page', size, light: light),
          size: size,
          light: light,
          child: _page(),
        );
      });
    }
    // Text at 2x on the phone: the trailing part drops under the words,
    // nothing clips (G4, A11Y-8).
    testWidgets('page labels · text 2x · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_section_label_page',
          const Size(412, 915),
          light: light,
          text2: true,
        ),
        size: const Size(412, 915),
        light: light,
        textScale: 2,
        child: _page(),
      );
    });
  }
}
