// Frame strips for the motion adoption pass (docs/qa/motion-adopt-2026-09-25):
// the same small scene at 412x915 dp, dark, real fonts, captured through a
// pull to refresh, a refresh failure arriving and a row arriving, once as the
// screens did it before (RefreshIndicator, a banner inserted in one frame, a
// plain Column) and once with the kit parts they use now (KitRefresh,
// KitReveal, KitAnimatedRows).
//
//   flutter test --concurrency=1 tool/capture/motion_adopt_test.dart
//   python3 tool/capture/motion_strip.py docs/qa/motion-adopt-2026-09-25
//
// Output: docs/qa/motion-adopt-2026-09-25/frames/<before|after>-<scene>/NN-<ms>ms.png
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'fixtures.dart';

const _out = 'docs/qa/motion-adopt-2026-09-25/frames';
const _size = Size(412, 915);

KitRow _row(String title) => KitRow(
  key: ValueKey(title),
  title: title,
  supporting: const TextSpan(text: 'bash · running'),
  leading: const KitRowIcon(AppIconography.terminal),
  onTap: () {},
);

Widget _frame(Widget home, GlobalKey boundary) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    home: home,
  ),
);

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
  int index,
  int ms,
) async => writePng(
  '$_out/$name/${index.toString().padLeft(2, '0')}-${ms}ms.png',
  await capturePng(tester, boundary, pixelRatio: 1),
);

Future<void> _strip(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
  List<int> atMs,
) async {
  var elapsed = 0;
  for (var i = 0; i < atMs.length; i++) {
    final step = atMs[i] - elapsed;
    if (step > 0) await tester.pump(Duration(milliseconds: step));
    elapsed = atMs[i];
    await _capture(tester, boundary, name, i, atMs[i]);
  }
  await tester.pumpAndSettle();
}

class _Changing extends StatefulWidget {
  const _Changing({required this.after, required this.banner});
  final bool after;

  /// True: a refresh failure arrives. False: a row arrives.
  final bool banner;

  @override
  State<_Changing> createState() => _ChangingState();
}

class _ChangingState extends State<_Changing> {
  var changed = false;

  @override
  Widget build(BuildContext context) {
    const failure = MaterialBanner(
      content: Text("Couldn't refresh\nThe server did not answer."),
      actions: [TextButton(onPressed: null, child: Text('Try again'))],
    );
    final rows = [
      _row('Terminal 1'),
      if (changed && !widget.banner) _row('Terminal 2 (new)'),
      _row('Terminal 3'),
      _row('Terminal 4'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminals'),
        actions: [
          IconButton(
            key: const ValueKey('change'),
            onPressed: () => setState(() => changed = true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.after)
            KitReveal(child: changed && widget.banner ? failure : null)
          else if (changed && widget.banner)
            failure,
          Expanded(
            child: ListView(
              children: [
                if (widget.after) KitAnimatedRows(children: rows) else ...rows,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final after in [false, true]) {
    final when = after ? 'after' : 'before';

    Future<void> view(WidgetTester tester) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('$when pull to refresh', (tester) async {
      await view(tester);
      final boundary = GlobalKey();
      final done = Completer<void>();
      final list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [for (var i = 1; i <= 12; i++) _row('Terminal $i')],
      );
      Future<void> refresh() => done.future;
      await tester.pumpWidget(
        _frame(
          Scaffold(
            appBar: AppBar(title: const Text('Terminals')),
            body: after
                ? KitRefresh(onRefresh: refresh, child: list)
                : RefreshIndicator(onRefresh: refresh, child: list),
          ),
          boundary,
        ),
      );
      await tester.pumpAndSettle();
      final name = '$when-pull-to-refresh';
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Terminal 3')),
      );
      var frame = 0;
      // The pull, in four steps of 60 dp.
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 16));
        await _capture(tester, boundary, name, frame++, (i + 1) * 16);
      }
      await gesture.up();
      // Refreshing, then done.
      for (final ms in const [100, 400]) {
        await tester.pump(Duration(milliseconds: ms == 100 ? 100 : 300));
        await _capture(tester, boundary, name, frame++, 64 + ms);
      }
      done.complete();
      await tester.pump();
      for (final ms in const [100, 250]) {
        await tester.pump(Duration(milliseconds: ms == 100 ? 100 : 150));
        await _capture(tester, boundary, name, frame++, 464 + ms);
      }
      await tester.pumpAndSettle();
    });

    for (final banner in [true, false]) {
      final scene = banner ? 'refresh-failure' : 'row-arrives';
      testWidgets('$when $scene', (tester) async {
        await view(tester);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          _frame(_Changing(after: after, banner: banner), boundary),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('change')));
        await tester.pump();
        await _strip(tester, boundary, '$when-$scene', const [
          0,
          50,
          100,
          150,
          200,
          250,
        ]);
      });
    }
  }
}
