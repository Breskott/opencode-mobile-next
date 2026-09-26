// Gallery (gate G4) for KitConfirmSheet, docs/ux-system/kit-v2.md §1.2 and
// §8.2: a bottom sheet on phones, capped on a medium window, a centred
// dialog on tablets in landscape and PCs.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_confirm_sheet_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

/// The heaviest confirmation: a delete with its consequences, a typed name,
/// a safer path and the technical value folded away.
Future<bool> _destructive(BuildContext context, {bool arabic = false}) =>
    showKitConfirm(
      context,
      title: arabic ? 'حذف مساحة العمل fox؟' : 'Delete workspace fox?',
      body: arabic
          ? 'تُحذف ملفاتها وفرعها من الخادم. لا يمكن التراجع عن ذلك.'
          : 'Its files and branch are removed from the server. This can’t '
                'be undone.',
      confirmLabel: arabic ? 'حذف مساحة العمل' : 'Delete workspace',
      kind: KitConfirmKind.destructive,
      consequences: [
        arabic
            ? 'ستُحذف 3 رسائل في قائمة الانتظار'
            : '3 queued prompts will be deleted',
      ],
      typedName: 'fox',
      alternative: KitAction(
        label: arabic ? 'تصدير أولًا' : 'Export first',
        onPressed: () {},
      ),
      details: const [
        KitTechnicalValue('Path', '/home/dev/code/.worktrees/fox'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in kitGallerySizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_confirm destructive · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: 'kit_confirm_destructive_${at}_$mode',
          size: size,
          light: light,
          open: _destructive,
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_confirm destructive · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryShot(
          tester,
          name: 'kit_confirm_destructive_text2_${at}_$mode',
          size: size,
          light: light,
          textScale: 2,
          open: _destructive,
        );
      });
      testWidgets('kit_confirm destructive · ar · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: 'kit_confirm_destructive_ar_${at}_$mode',
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          open: (context) => _destructive(context, arabic: true),
          then: (tester) async {
            await tester.tap(find.byKey(const ValueKey('kit-details-toggle')));
          },
        );
      });
    }

    const phone = Size(412, 915);
    testWidgets('kit_confirm neutral · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: 'kit_confirm_neutral_$mode',
        size: phone,
        light: light,
        open: (context) => showKitConfirm(
          context,
          title: 'Share conversation?',
          body:
              'Anyone with the link can read it. You can stop sharing '
              'later.',
          confirmLabel: 'Share conversation',
        ),
      );
    });

    testWidgets('kit_confirm stop, working · $mode', (tester) async {
      final never = Completer<void>();
      await kitGalleryShot(
        tester,
        name: 'kit_confirm_stop_working_$mode',
        size: phone,
        light: light,
        open: (context) => showKitConfirm(
          context,
          title: 'Stop fox?',
          body: 'It stops mid-task. Its work so far is kept.',
          confirmLabel: 'Stop fox',
          kind: KitConfirmKind.stop,
          action: () => never.future,
        ),
        // The spinner never settles; one frame shows the working state.
        settleAfterThen: false,
        then: (tester) async {
          await tester.tap(find.text('Stop fox'));
          await tester.pump();
        },
      );
    });

    testWidgets('kit_confirm failed · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: 'kit_confirm_failed_$mode',
        size: phone,
        light: light,
        open: (context) => showKitConfirm(
          context,
          title: 'Revoke saved permission?',
          body: 'The agent asks again next time it edits files.',
          confirmLabel: 'Revoke permission',
          kind: KitConfirmKind.destructive,
          action: () async => throw StateError('offline'),
        ),
        then: (tester) async {
          await tester.tap(find.text('Revoke permission'));
        },
      );
    });

    testWidgets('kit_confirm discard · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: 'kit_confirm_discard_$mode',
        size: phone,
        light: light,
        open: (context) => showKitConfirm(
          context,
          title: 'Discard your changes?',
          body:
              'What you changed here isn’t saved. Discarding it can’t be '
              'undone.',
          confirmLabel: 'Discard changes',
          kind: KitConfirmKind.discard,
        ),
      );
    });

    testWidgets('kit_confirm typed name ready · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: 'kit_confirm_typed_ready_$mode',
        size: phone,
        light: light,
        open: _destructive,
        then: (tester) async {
          await tester.enterText(
            find.byKey(const ValueKey('kit-confirm-typed-name')),
            'fox',
          );
          FocusManager.instance.primaryFocus?.unfocus();
        },
      );
    });
  }
}
