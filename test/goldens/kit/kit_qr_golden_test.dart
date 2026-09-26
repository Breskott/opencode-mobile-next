// Gallery (gate G4) for KitQr (docs/ux-system/kit-api/KitQr.md "Galleries
// required"): the code on a surface2 sheet body with a caption row that
// stands in for the host's link and Copy, so the paper's edge is seen
// against a sheet in both themes. DPR 3, Android (kitGalleryPart).
//
// Reduced from the frozen spec's 22-shot matrix by the owner decision in
// docs/ux-system/revamp/STANDARDS.md (2026-09-27, R15: later owner
// decisions win): Arabic/RTL and 2.0-text galleries are dropped, and every
// part's gallery is phone (412x915) and one wide size (1280x800), light
// and dark, only. See docs/qa/revamp-kit-KitQr-2026-09-27/README.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_qr_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

/// A fixture link: never a real server address or token (SEC-5).
const _link = 'opencode://s/shopfront/9c2f';

/// Longer than a version-40 code holds at error correction M: the
/// "too long" state.
final _tooLongData = 'x' * 4000;

const _semanticsLabel = 'QR code to open this conversation on your phone';
const _copyLabel = 'Copy link';

/// The two declared states (KIT-12): the code, or the too-long message.
enum _State { default_, tooLong }

Widget _qr(_State state) => switch (state) {
  _State.default_ => const KitQr(data: _link, semanticsLabel: _semanticsLabel),
  _State.tooLong => KitQr(data: _tooLongData, semanticsLabel: _semanticsLabel),
};

/// The code on a `surface2` sheet body, with a caption row standing in for
/// the host's link and Copy action, so the paper's hairline edge is seen
/// against a sheet in both themes.
Widget _scene(_State state) => Builder(
  builder: (context) {
    final roles = KitTokens.of(context).roles;
    return DecoratedBox(
      decoration: BoxDecoration(color: roles.surface2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: _qr(state)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: KitText(
                    _link,
                    role: KitTextRole.mono,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                KitIconButton(
                  icon: AppIconography.copy,
                  label: _copyLabel,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

String _stateName(_State state) =>
    state == _State.default_ ? 'default' : 'too_long';

void main() {
  setUpAll(loadKitGalleryFonts);

  // Both declared states x phone (412x915) and one wide size (1280x800) x
  // dark and light (8 PNGs; owner decision 2026-09-27).
  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    for (final light in [false, true]) {
      for (final state in _State.values) {
        testWidgets('${_stateName(state)} · ${kitGallerySize(size)} · '
            '${light ? 'light' : 'dark'}', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_qr_${_stateName(state)}',
              size,
              light: light,
            ),
            size: size,
            light: light,
            child: _scene(state),
          );
        });
      }
    }
  }
}
