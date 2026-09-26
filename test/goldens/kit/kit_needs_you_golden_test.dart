// Gallery (gate G4) for KitNeedsYou
// (docs/ux-system/kit-api/KitNeedsYou.md): the mark and span in a list of
// KitRows, the badge on a dock-tab stub, a top-bar pill stub and a server
// row (0, 3, 99+), the pointing row (single and 2-line at a long title),
// and the three reason words.
//
// Owner decision 2026-09-27 drops Arabic and RTL review for this wave, and
// narrows the required sizes to the phone (412x915) and one wide size
// (1280x800): this gallery renders only those two sizes, in light and dark,
// with no Arabic or 2.0-text variant (the frozen spec's larger grid does not
// apply here — see docs/qa/revamp-kit-KitNeedsYou/README.md).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_needs_you_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_divider.dart';
import 'package:opencode_mobile/ui/kit/kit_icon.dart';
import 'package:opencode_mobile/ui/kit/kit_needs_you.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

const _sizes = [Size(412, 915), Size(1280, 800)];

/// The mark and the span together, in a short list of [KitRow]s (the two
/// builders a transcript or a list would actually combine).
Widget _marksAndSpans() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, count) in const [
          ('Run a shell command', 1),
          ('Approve the migration', 2),
          ('Rotate the API key', 5),
        ])
          KitRow(
            leading: KitNeedsYou.mark(),
            title: title,
            supporting: KitNeedsYou.span(context, count: count),
          ),
      ],
    ),
  ),
);

/// A small square standing in for a dock tab's icon.
Widget _dockTabStub() => const SizedBox.square(
  dimension: 32,
  child: Center(child: KitIcon(AppIconography.activity)),
);

/// A small pill standing in for the top bar's server switcher.
Widget _topBarPillStub(BuildContext context) {
  final tokens = KitTokens.of(context);
  return DecoratedBox(
    decoration: ShapeDecoration(
      color: tokens.roles.surface2,
      shape: tokens.shapeOf(KitShape.pill),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: KitText('laptop', role: KitTextRole.label),
    ),
  );
}

/// The badge at 0, 3 and 99+ on a dock-tab stub, a top-bar pill stub and a
/// server row, each labelled by what it sits on.
Widget _badges() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final count in const [0, 3, 120])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                KitNeedsYou.badge(count: count, child: _dockTabStub()),
                const SizedBox(width: 32),
                KitNeedsYou.badge(
                  count: count,
                  child: _topBarPillStub(context),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: KitRow(
                    leading: KitNeedsYou.badge(
                      count: count,
                      child: const KitRowIcon(AppIconography.server),
                    ),
                    title: 'laptop',
                    supporting: const TextSpan(text: 'Connected'),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  ),
);

/// The pointing row, once at a short title and once at a title long enough
/// to wrap to 2 lines under the default text scale.
Widget _rows() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KitNeedsYou.row(
        title: 'Run a shell command',
        reason: KitNeedsYouReason.decision,
        ifIgnored: 'The team waits; nothing is lost.',
        onOpen: () {},
        who: 'fox',
        server: 'laptop',
      ),
      const KitDivider(),
      KitNeedsYou.row(
        title:
            'Approve the migration that renames every profile-scoped '
            'storage key across the offline queue',
        reason: KitNeedsYouReason.blocked,
        ifIgnored: 'Drafts stay queued until this is answered.',
        onOpen: () {},
        server: 'laptop',
      ),
      const KitDivider(),
      KitNeedsYou.row(
        title: 'Allow microphone access',
        reason: KitNeedsYouReason.consent,
        ifIgnored: 'Voice input stays off.',
        onOpen: () {},
        // Four and a half minutes before the real clock: the test's fake
        // clock starts a moment earlier, so the words always read
        // "waiting 4 min" whatever the wall clock says (TEST-11).
        since: DateTime.now().subtract(const Duration(minutes: 4, seconds: 30)),
      ),
    ],
  ),
);

/// The three reason words (KitNeedsYou.reasonWord), each beside the title
/// it belongs to.
Widget _reasons() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in KitNeedsYouReason.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: KitText(reason.name, role: KitTextRole.rowTitle),
                  ),
                  const SizedBox(width: 12),
                  KitText(
                    KitNeedsYou.reasonWord(context, reason),
                    role: KitTextRole.label,
                    tone: KitTextTone.attention,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in _sizes) {
      testWidgets('marks and spans · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_needs_you_marks', size, light: light),
          size: size,
          light: light,
          child: _marksAndSpans(),
        );
      });

      testWidgets('badges · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_needs_you_badges', size, light: light),
          size: size,
          light: light,
          child: _badges(),
        );
      });

      testWidgets('pointing row · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_needs_you_row', size, light: light),
          size: size,
          light: light,
          child: _rows(),
        );
      });

      testWidgets('reason words · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_needs_you_reasons', size, light: light),
          size: size,
          light: light,
          child: _reasons(),
        );
      });
    }
  }
}
