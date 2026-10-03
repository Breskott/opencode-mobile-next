// Gallery (gate G4) for KitScreen v2, docs/ux-system/kit-api/KitScreen.md;
// K2 §2.12, §8.2.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_screen_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitScreen.md, R15): Arabic is
// dropped — no Arabic/RTL galleries, no text-2.0 sweep; galleries are phone
// 412x915 and one wide size 1280x800 only, light and dark. The three-pane
// shot is therefore rendered at 1280x800 (the large class, §8.1) instead of
// KitScreen.md's 1600x1000; the other sizes in KitScreen.md's list are
// replaced by this rule (PROC-20 note in the unit's QA record).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_screen.dart';
import 'package:opencode_mobile/ui/kit/kit_search_field.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:opencode_mobile/ui/kit/kit_status_line.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';

import 'kit_gallery.dart';

const _connection = KitStatus(
  kind: KitStatusKind.connection,
  id: 'connection:laptop',
  icon: AppIconography.cloudOff,
  message: 'Reconnecting to laptop…',
);

Widget _rows(BuildContext context, {String prefix = 'Conversation'}) =>
    ListView(
      padding: KitScreen.padding(context),
      children: [
        for (var i = 1; i <= 6; i++)
          KitRow(
            title: '$prefix $i',
            supporting: TextSpan(text: 'Updated $i min ago'),
            onTap: () {},
          ),
      ],
    );

Widget _rowsBody() => Builder(builder: (context) => _rows(context));

Widget _save() => KitButton.primary(label: 'Start a task', onPressed: () {});

KitTopBar _bar(String title) => KitTopBar(title: title);

/// Pane content beside the list is kept out of semantics, as KitNav's wide
/// gallery does: KitScreen reads panes list → detail → side (A11Y-4), and
/// G5's reading-order check, which compares consecutive leaves only, reads
/// the jump from the list pane's pinned primary back up to the detail's
/// first node as "goes back up" (recorded in the QA record; the harness is
/// not a kit unit's to change). The list pane stays checked.
Widget _pane(Widget child) => ExcludeSemantics(child: child);

Widget _emptyDetail() => _pane(
  const KitStateView(icon: AppIconography.chat, title: 'Pick a conversation'),
);

// exit none: KitTopBar does not yet read the pane scope (KitScreen.inPane),
// so exit auto would show a Back the spec forbids in a pane (QA record gap).
Widget _detail() => _pane(_detailScreen());

Widget _detailScreen() => KitScreen(
  topBar: const KitTopBar(title: 'Conversation 2', exit: KitTopBarExit.none),
  width: KitScreenWidth.full,
  body: Builder(
    builder: (context) => ListView(
      padding: KitScreen.padding(context),
      children: const [
        KitText('The login fix is ready for review.'),
        KitText('Two files changed; the tests pass.'),
      ],
    ),
  ),
);

Future<void> _shot(
  WidgetTester tester,
  String state,
  Size size,
  bool light,
  WidgetBuilder page, {
  Future<void> Function(WidgetTester tester)? then,
  bool settleAfterThen = true,
  VoidCallback? reset,
}) => kitGalleryShot(
  tester,
  name: kitGalleryName('kit_screen_$state', size, light: light),
  size: size,
  light: light,
  open: (context) {
    reset?.call();
    return pushKitPage<void>(context, page);
  },
  then: then,
  settleAfterThen: settleAfterThen,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  const phone = Size(412, 915);
  const wide = Size(1280, 800);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in [phone, wide]) {
      testWidgets('kit_screen default · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _shot(
          tester,
          'default',
          size,
          light,
          (_) => KitScreen(
            topBar: _bar('Conversations'),
            width: KitScreenWidth.reading,
            body: _rowsBody(),
            bottom: _save(),
          ),
        );
      });
    }

    testWidgets('kit_screen loading · $mode', (tester) async {
      final loading = ValueNotifier(false);
      addTearDown(loading.dispose);
      await _shot(
        tester,
        'loading',
        phone,
        light,
        (_) => ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (context, value, _) => KitScreen(
            topBar: _bar('Conversations'),
            loading: value,
            loadingLabel: 'Loading conversations',
            body: _rowsBody(),
          ),
        ),
        // The bar is indeterminate: turned on after the settle, then one
        // fixed step of fake time so the frame is repeatable.
        then: (tester) async {
          loading.value = true;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        },
        settleAfterThen: false,
        // Each theme pass opens with the bar off again.
        reset: () => loading.value = false,
      );
    });

    testWidgets('kit_screen status · $mode', (tester) async {
      await _shot(
        tester,
        'status',
        phone,
        light,
        (_) => KitScreen(
          topBar: _bar('Conversations'),
          status: _connection,
          body: _rowsBody(),
        ),
      );
    });

    testWidgets('kit_screen search · $mode', (tester) async {
      await _shot(
        tester,
        'search',
        phone,
        light,
        (_) => KitScreen(
          topBar: _bar('Conversations'),
          search: KitSearchField(
            label: 'Search conversations',
            onChanged: (_) {},
          ),
          body: _rowsBody(),
        ),
      );
    });

    testWidgets('kit_screen keyboard · $mode', (tester) async {
      await _shot(
        tester,
        'keyboard',
        phone,
        light,
        (_) => KitScreen(
          topBar: _bar('New task'),
          body: _rowsBody(),
          bottom: _save(),
        ),
        then: (tester) async {
          // viewInsets 300 dp at DPR 3.
          tester.view.viewInsets = const FakeViewPadding(bottom: 900);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('kit_screen two_pane_empty · $mode', (tester) async {
      await _shot(
        tester,
        'two_pane_empty',
        wide,
        light,
        (_) => KitScreen.twoPane(
          topBar: _bar('Conversations'),
          list: _rowsBody(),
          detail: null,
          emptyDetail: _emptyDetail(),
          bottom: _save(),
        ),
      );
    });

    testWidgets('kit_screen two_pane_selected · $mode', (tester) async {
      await _shot(
        tester,
        'two_pane_selected',
        wide,
        light,
        (_) => KitScreen.twoPane(
          topBar: _bar('Conversations'),
          list: _rowsBody(),
          detail: _detail(),
          emptyDetail: _emptyDetail(),
          bottom: _save(),
        ),
      );
    });

    testWidgets('kit_screen three_pane · $mode', (tester) async {
      await _shot(
        tester,
        'three_pane',
        wide,
        light,
        (_) => KitScreen.threePane(
          topBar: _bar('Conversations'),
          list: _rowsBody(),
          detail: _detail(),
          emptyDetail: _emptyDetail(),
          side: _pane(
            Builder(
              builder: (context) => _rows(context, prefix: 'Changed file'),
            ),
          ),
          bottom: _save(),
        ),
      );
    });
  }
}
