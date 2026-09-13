import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/widgets/tool_card.dart';
import '../../test/support/v2_subagent_fixture.dart';
import 'fixtures.dart'
    show loadCaptureFonts, captureTheme, capturePng, writePng;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final light in [false, true]) {
    for (final completed in [false, true]) {
      testWidgets(
        'native subagent ${light ? 'light' : 'dark'} ${completed ? 'completed' : 'launched'}',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: captureTheme(light: light),
                home: Scaffold(
                  appBar: AppBar(
                    title: const Text('Inspect checkout validation'),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ToolCard(
                      toolName: 'subagent',
                      state: v2SubagentState(
                        childStatus: completed ? 'completed' : 'running',
                        background: !completed,
                      ),
                      onOpenSession: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('explore'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          await writePng(
            'docs/qa/v2-subagent-contract/${light ? 'light' : 'dark'}-${completed ? 'completed' : 'launched'}.png',
            await capturePng(tester, boundary, pixelRatio: 1),
          );
        },
      );
    }
  }
}
