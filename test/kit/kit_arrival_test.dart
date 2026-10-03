// KitArrival (docs/ux-system/kit-api/KitArrival.md, slice-P9.4): a search
// result that means one row opens its page arrived at that row — scrolled
// into view, focused for the screen reader and washed once — and never
// again on a rebuild or a remount.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_harness.dart';
import 'kit_motion_still.dart';

/// A long page of rows, each an arrival anchor `row-<i>`. Like the pages a
/// result opens, it is not a lazy list: every row is laid out.
class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  /// Bumped to remount row 30 (a list that reloads).
  int generation = 0;

  void remountRow30() => setState(() => generation++);

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('page'),
    children: [
      Column(
        children: [
          for (var i = 0; i < 40; i++)
            KitArrival(
              key: ValueKey('row-$i-${i == 30 ? generation : 0}'),
              id: 'row-$i',
              child: KitRow(title: 'Row $i'),
            ),
        ],
      ),
    ],
  );
}

Future<void> _open(
  WidgetTester tester,
  BuildContext context, {
  String? rowId,
}) async {
  const page = _Page();
  final Widget body = rowId == null
      ? page
      : KitArrivalScope(rowId: rowId, child: page);
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: body)));
  await tester.pumpAndSettle();
}

double _offset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('page')),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

/// The wash behind [row]'s words, or null when the row has none.
double? _wash(WidgetTester tester, String row) {
  final arrival = find.ancestor(
    of: find.text(row),
    matching: find.byType(KitArrival),
  );
  final opacity = find.descendant(
    of: arrival,
    matching: find.byType(AnimatedOpacity),
  );
  if (opacity.evaluate().isEmpty) return null;
  return tester.widget<AnimatedOpacity>(opacity).opacity;
}

void main() {
  kitMotionStillTests(
    'KitArrival',
    builds: {
      'arrived': () => KitArrivalScope(
        rowId: 'vibration',
        child: const KitArrival(
          id: 'vibration',
          child: KitRow(title: 'Vibration'),
        ),
      ),
    },
    changes: {
      'mark ends': KitMotionChange(
        build: () => KitArrivalScope(
          rowId: 'vibration',
          child: const KitArrival(
            id: 'vibration',
            child: KitRow(title: 'Vibration'),
          ),
        ),
        act: (tester, _) => tester.pump(KitArrival.hold),
        shows: 'Vibration',
      ),
    },
  );

  testWidgets('arrives at the row: in view, washed, then let go', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    await _open(tester, context, rowId: 'row-30');

    final row = tester.getRect(find.text('Row 30'));
    expect(row.top, greaterThanOrEqualTo(0));
    expect(row.bottom, lessThanOrEqualTo(915));
    expect(_offset(tester), greaterThan(0));
    expect(_wash(tester, 'Row 30'), 1);
    // Only the row it was opened for.
    expect(_wash(tester, 'Row 29'), isNull);

    await tester.pump(KitArrival.hold);
    await tester.pumpAndSettle();
    expect(_wash(tester, 'Row 30'), 0);
  });

  testWidgets('never repeats on a rebuild or a remount', (tester) async {
    final context = await pumpKitHost(tester);
    await _open(tester, context, rowId: 'row-30');
    await tester.pump(KitArrival.hold);
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('page')),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final bottom = _offset(tester);
    final page = tester.state<_PageState>(find.byType(_Page));
    // Row 30 mounts again with a new key: it must not claim the request.
    page.remountRow30();
    await tester.pumpAndSettle();
    expect(_offset(tester), bottom);
    expect(_wash(tester, 'Row 30'), isNull);
  });

  testWidgets('without a request a row is only its child', (tester) async {
    final context = await pumpKitHost(tester);
    await _open(tester, context);
    expect(_offset(tester), 0);
    expect(_wash(tester, 'Row 0'), isNull);
    // A request for a row the page does not have claims nothing.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await _open(tester, context, rowId: 'row-99');
    expect(_offset(tester), 0);
    expect(find.byType(AnimatedOpacity), findsNothing);
  });

  testWidgets('reduced motion jumps and drops the wash at once', (
    tester,
  ) async {
    final context = await pumpKitHost(
      tester,
      effects: const KitEffects(motion: KitMotionLevel.off),
    );
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        // The route itself does not move either, so only the part is judged.
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => Scaffold(
          body: KitArrivalScope(rowId: 'row-30', child: const _Page()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(_offset(tester), greaterThan(0));
    expect(_wash(tester, 'Row 30'), 1);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(KitArrival.hold);
    await tester.pump();
    expect(_wash(tester, 'Row 30'), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('moves the screen reader to the row', (tester) async {
    final semantics = tester.ensureSemantics();
    final events = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        events.add(message);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    final context = await pumpKitHost(tester);
    await _open(tester, context, rowId: 'row-30');
    expect(
      events.whereType<Map<Object?, Object?>>().where(
        (event) => event['type'] == 'focus',
      ),
      hasLength(1),
    );
    semantics.dispose();
  });
}
