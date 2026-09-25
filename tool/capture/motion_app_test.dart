// Frame strips for the motion pass (docs/qa/motion-app-2026-09-25): the same
// small scene at 412x915 dp, dark, real fonts, captured every few frames
// through a tab switch, a page push and a notice arriving, once with the old
// motion (RetainedTabView's crossfade, FadeForwards, an instant notice) and
// once with the new (KitTabSwitcher, KitPageTransitionsBuilder, KitReveal).
//
//   flutter test --concurrency=1 tool/capture/motion_app_test.dart
//   python3 tool/capture/motion_strip.py docs/qa/motion-app-2026-09-25
//
// Output: docs/qa/motion-app-2026-09-25/frames/<before|after>-<scene>/NN-<ms>ms.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/retained_tab_view.dart';

import 'fixtures.dart';

const _out = 'docs/qa/motion-app-2026-09-25/frames';
const _size = Size(412, 915);

Widget _list(String title, int seed) => ListView(
  children: [
    SectionLabel(title),
    for (var i = 0; i < 12; i++)
      KitRow(
        title: '$title row ${i + seed}',
        supporting: const TextSpan(text: 'Updated a minute ago'),
        leading: const KitRowIcon(AppIconography.workspace),
        onTap: () {},
      ),
  ],
);

Widget _frame(Widget home, GlobalKey boundary, PageTransitionsBuilder page) =>
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark().copyWith(
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {TargetPlatform.android: page},
          ),
        ),
        home: home,
      ),
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
    await writePng(
      '$_out/$name/${i.toString().padLeft(2, '0')}-${atMs[i]}ms.png',
      await capturePng(tester, boundary, pixelRatio: 1),
    );
  }
  await tester.pumpAndSettle();
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.after});
  final bool after;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  var index = 0;

  @override
  Widget build(BuildContext context) {
    final children = [_list('Work', 1), _list('Inbox', 40)];
    return Scaffold(
      appBar: AppBar(title: const Text('Tabs')),
      body: widget.after
          ? KitTabSwitcher(index: index, children: children)
          : RetainedTabView(index: index, children: children),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work), label: 'Work'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
        ],
      ),
    );
  }
}

class _Notice extends StatefulWidget {
  const _Notice({required this.after});
  final bool after;

  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> {
  var shown = false;

  @override
  Widget build(BuildContext context) {
    const notice = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: KitNotice(
        title: 'Connected',
        message: 'OpenCode answered in 120 ms.',
        tone: AppStatusTone.ok,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Add server')),
      body: ListView(
        children: [
          if (widget.after)
            KitReveal(child: shown ? notice : null)
          else if (shown)
            notice,
          for (var i = 0; i < 8; i++)
            KitRow(title: 'Field ${i + 1}', onTap: () {}),
          KitButton.primary(
            key: const ValueKey('show'),
            label: 'Test',
            onPressed: () => setState(() => shown = true),
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
    final page = after
        ? const KitPageTransitionsBuilder()
        : const FadeForwardsPageTransitionsBuilder();

    Future<void> view(WidgetTester tester) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('$when tab switch', (tester) async {
      await view(tester);
      final boundary = GlobalKey();
      await tester.pumpWidget(_frame(_Tabs(after: after), boundary, page));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox').last);
      await tester.pump();
      await _strip(tester, boundary, '$when-tab-switch', const [
        0,
        32,
        64,
        96,
        128,
        160,
        192,
        250,
      ]);
    });

    testWidgets('$when page push', (tester) async {
      await view(tester);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _frame(
          Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Work')),
              body: ListView(
                children: [
                  for (var i = 0; i < 12; i++)
                    KitRow(
                      title: 'Conversation ${i + 1}',
                      trailing: const KitChevron(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: Text('Conversation ${i + 1}'),
                            ),
                            body: _list('Turn', 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          boundary,
          page,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation 1'));
      await tester.pump();
      await _strip(tester, boundary, '$when-page-push', const [
        0,
        48,
        96,
        144,
        192,
        250,
        320,
        450,
      ]);
    });

    testWidgets('$when notice', (tester) async {
      await view(tester);
      final boundary = GlobalKey();
      await tester.pumpWidget(_frame(_Notice(after: after), boundary, page));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show')));
      await tester.pump();
      await _strip(tester, boundary, '$when-notice', const [
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
