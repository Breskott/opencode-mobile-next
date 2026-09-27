// Gallery (gate G4) for unit slice-R2 (docs/ux-system/revamp/
// leftover-units.json): the sheet at 250 % text (the header scrolls with
// the body, the body keeps half the sheet), one close control, the
// confirm's alternative between the act and Cancel with neutral facts, and
// the input dialog in the confirm's frame. Phone 412x915 and 1280x800,
// light and dark (owner decision 2026-09-27).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_sheet_r2_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _phone = Size(412, 915);
const _sizes = [_phone, Size(1280, 800)];

Widget _folders(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final name in const ['oc_app', 'notes', 'site', 'scripts'])
      KitRow(
        leading: const KitRowIcon(AppIconography.folderOpen),
        title: name,
        onTap: () {},
      ),
  ],
);

Future<void> _folder(BuildContext context) => showKitSheet<void>(
  context,
  title: 'Project folder',
  subtitle: 'Where the agent works',
  icon: AppIconography.folderOpen,
  body: _folders,
  primary: KitAction(label: 'Use oc_app', onPressed: () {}),
  secondary: KitAction(label: 'Cancel', onPressed: () {}),
  secondaryDismisses: true,
);

Future<void> _confirm(BuildContext context) => showKitConfirm(
  context,
  title: 'Move fox?',
  body: 'The conversation moves to the notes project.',
  confirmLabel: 'Move fox',
  consequenceItems: const [
    KitConsequence(
      'Its 3 changed files move with it',
      mark: KitConsequenceMark.neutral,
    ),
    KitConsequence(
      'Its agent keeps its model',
      mark: KitConsequenceMark.neutral,
    ),
  ],
  alternative: KitAction(label: 'Copy fox instead', onPressed: () {}),
);

Future<void> _rename(BuildContext context) => showKitInputDialog(
  context,
  title: 'Rename server',
  label: 'Name',
  confirmLabel: 'Rename server',
  initial: 'Laptop',
  helper: 'Shown on Work and in notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in _sizes) {
      final at = kitGallerySize(size);

      testWidgets('kit_sheet text 2.5 · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_sheet_text250', size, light: light),
          size: size,
          light: light,
          textScale: 2.5,
          open: _folder,
        );
      });

      testWidgets('kit_sheet one close · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_sheet_oneclose', size, light: light),
          size: size,
          light: light,
          open: _folder,
        );
      });

      testWidgets('kit_confirm_sheet alternative · $at · $mode', (
        tester,
      ) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_confirm_sheet_alternative',
            size,
            light: light,
          ),
          size: size,
          light: light,
          open: _confirm,
        );
      });

      testWidgets('kit_dialog input frame · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_dialog_inputframe', size, light: light),
          size: size,
          light: light,
          open: _rename,
        );
      });
    }
  }
}
