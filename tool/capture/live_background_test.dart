// Evidence frames for docs/qa/live-background-2026-10-14: a phone-size page
// on the live ground, dark and light, idle and with a reply running, and six
// frames across the loop. Synthetic page built from kit parts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'fixtures.dart';

Widget _page(bool light, GlobalKey boundary, String style) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: light ? AppTheme.light() : AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => KitEffectsScope(
      effects: KitEffects(liveStyle: style),
      child: child!,
    ),
    home: KitScreen(
      topBar: const KitTopBar(title: 'Chats'),
      body: ListView(
        children: [
          const KitSectionLabel('Today'),
          for (final t in [
            'Fix the login redirect',
            'Release notes for 1.2',
            'Why is the build slow?',
            'Tidy the settings pages',
          ])
            KitRow(
              title: t,
              supporting: const TextSpan(text: 'shopfront · 2 min ago'),
            ),
          const KitSectionLabel('Earlier'),
          for (final t in ['Sketch the onboarding', 'Rename the project'])
            KitRow(
              title: t,
              supporting: const TextSpan(text: 'notes · yesterday'),
            ),
        ],
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    KitLiveBackground.paintWithoutLoops = true;
    KitMotion.loops = false;
  });
  tearDown(() {
    KitLiveBackground.paintWithoutLoops = false;
    KitLiveBackground.frozenSeconds = null;
    KitLiveBackground.running.value = 0;
  });

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required bool light,
    String style = 'aurora',
    double second = 8,
    bool running = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    KitLiveBackground.running.value = running ? 1 : 0;
    KitLiveBackground.frozenSeconds = second;
    final boundary = GlobalKey();
    await tester.pumpWidget(_page(light, boundary, style));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    await writePng(
      'docs/qa/live-background-2026-10-14/$name.png',
      await capturePng(tester, boundary, pixelRatio: 2),
    );
  }

  for (final s in kitLiveStyles) {
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';
      testWidgets('${s.id} $mode', (tester) async {
        await shot(tester, '${s.id}-$mode', light: light, style: s.id);
      });
    }
    testWidgets('${s.id} running', (tester) async {
      await shot(
        tester,
        '${s.id}-dark-running',
        light: false,
        style: s.id,
        running: true,
      );
    });
  }

  for (var i = 0; i < 6; i++) {
    testWidgets('loop frame $i', (tester) async {
      await shot(
        tester,
        'strip-aurora-${i * 8}s',
        light: false,
        style: 'aurora',
        second: i * 8.0,
      );
    });
  }
}
