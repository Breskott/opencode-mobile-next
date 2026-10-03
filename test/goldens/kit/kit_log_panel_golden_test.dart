// Gallery (gate G4) for KitLogPanel, docs/ux-system/kit-api/KitLogPanel.md;
// K2 §1.11, §8.2.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_log_panel_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitLogPanel.md, R15): Arabic
// is dropped — no Arabic/RTL galleries; galleries are phone 412x915 and
// one wide size 1280x800 only, light and dark. This replaces
// KitLogPanel.md's own 34-shot list (a PROC-20 note in the unit's QA
// record): each state at 412x915, `live` at 1280x800 (size fill), and `live`
// at text 2.0 at both sizes (TEST-9, G4).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_log_panel.dart';

import 'kit_gallery.dart';

/// Deterministic setup output with one warning and one error line.
KitLogBuffer _setupLines({int extra = 0}) {
  // Short lines, so a folded panel shows them whole (no line is left
  // clipped to a sliver at the panel's top edge).
  final buffer = KitLogBuffer()
    ..appendText(
      '[oc] Checking the Linux environment\n'
      '[oc] Ubuntu 24.04 found\n'
      '[oc] Installing opencode 2.0.10\n',
    )
    ..add(
      const KitLogLine(
        'npm warn deprecated inflight@1.0.6',
        level: KitLogLevel.warning,
      ),
    )
    ..appendText(
      'added 212 packages in 14s\n'
      '[oc] Starting the server on :4097\n',
    )
    ..add(
      const KitLogLine(
        'listen EADDRINUSE: address in use',
        level: KitLogLevel.error,
      ),
    )
    ..appendText('[oc] Retrying on :4098\n[oc] Server is ready\n');
  for (var i = 0; i < extra; i++) {
    buffer.add(KitLogLine('[oc] step ${i + 1} of $extra done'));
  }
  return buffer;
}

/// One scenario: builds a fresh panel for each theme pass, then [then]
/// drives it (time, a drag, a failed read).
class _Scene {
  const _Scene(this.build, {this.then, this.fill = false});
  final Widget Function() build;
  final Future<void> Function(WidgetTester tester)? then;
  final bool fill;
}

Future<void> _shot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required _Scene scene,
  double textScale = 1,
}) async {
  final own = light ? 'light' : 'dark';
  final stem = name.substring(0, name.length - own.length - 1);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    for (final pass in [!light, light]) {
      late BuildContext context;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: pass ? AppTheme.light() : AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Builder(
                  builder: (inner) {
                    context = inner;
                    final panel = scene.build();
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: scene.fill
                          ? panel
                          : Align(
                              alignment: AlignmentDirectional.topCenter,
                              child: panel,
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      if (scene.then != null) await scene.then!(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(context),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

final _scenes = <String, _Scene>{
  'empty': _Scene(() => KitLogPanel(lines: KitLogBuffer(), live: true)),
  'live': _Scene(() => KitLogPanel(lines: _setupLines(), live: true)),
  'quiet': _Scene(
    () => KitLogPanel(lines: _setupLines(), live: true),
    then: (tester) => tester.pump(const Duration(seconds: 8)),
  ),
  'ended_failed': _Scene(
    () => KitLogPanel(
      lines: _setupLines(),
      ended: const KitLogEnd(
        exitCode: 1,
        failed: true,
        reason: 'The server could not start.',
      ),
    ),
  ),
  'read_failed': _Scene(
    () => KitLogPanel(
      lines: _setupLines(),
      live: true,
      onRefresh: () async => throw StateError('gone'),
    ),
    then: (tester) async {
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    },
  ),
  'scrolled_up': _Scene(
    () => KitLogPanel(
      lines: _scrolled = _setupLines(extra: 30),
      live: true,
      wrap: false,
    ),
    then: (tester) async {
      // Up by whole lines (8 × 20 dp), so no line is cut at the top edge.
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position.jumpTo(position.pixels - 160);
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        _scrolled.add(KitLogLine('[oc] new step ${i + 1}'));
      }
      await tester.pump();
      await tester.pump();
    },
  ),
  // R3: the host's "Copy failure report" sits in the header beside Copy
  // all, and the Wrap toggle keeps its inset from the panel's edge.
  'failed_report': _Scene(
    () => KitLogPanel(
      lines: _setupLines(),
      ended: const KitLogEnd(exitCode: 1, failed: true),
      headerAction: KitAction.copy(
        label: 'Copy failure report',
        text: () => 'report',
      ),
    ),
  ),
  'dropped': _Scene(() {
    final buffer = KitLogBuffer(capacity: 10);
    for (var i = 0; i < 1250; i++) {
      buffer.add(KitLogLine('[oc] indexed file ${i + 1}'));
    }
    return KitLogPanel(lines: buffer, ended: const KitLogEnd(exitCode: 0));
  }),
  'fold_open': _Scene(
    () => SingleChildScrollView(
      child: KitLogPanel.fold(lines: _setupLines(), live: true),
    ),
    then: (tester) async {
      await tester.tap(find.text('Show output'));
      await tester.pumpAndSettle();
    },
  ),
};

late KitLogBuffer _scrolled;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final entry in _scenes.entries) {
      testWidgets('kit_log_panel ${entry.key} · $mode', (tester) async {
        await _shot(
          tester,
          name: kitGalleryName(
            'kit_log_panel_${entry.key}',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          scene: entry.value,
        );
      });
    }
    testWidgets('kit_log_panel live · 1280x800 · $mode', (tester) async {
      const size = Size(1280, 800);
      await _shot(
        tester,
        name: kitGalleryName('kit_log_panel_live', size, light: light),
        size: size,
        light: light,
        scene: _Scene(
          () => KitLogPanel(
            lines: _setupLines(extra: 10),
            live: true,
            size: KitLogSize.fill,
          ),
          fill: true,
        ),
      );
    });
    // R3: on a wide window the host's action shares the header row.
    testWidgets('kit_log_panel failed_report · 1280x800 · $mode', (
      tester,
    ) async {
      const size = Size(1280, 800);
      await _shot(
        tester,
        name: kitGalleryName('kit_log_panel_failed_report', size, light: light),
        size: size,
        light: light,
        scene: _scenes['failed_report']!,
      );
    });
    for (final size in kitGalleryScaledSizes) {
      testWidgets(
        'kit_log_panel live · text 2.0 · ${kitGallerySize(size)} · $mode',
        (tester) async {
          await _shot(
            tester,
            name: kitGalleryName(
              'kit_log_panel_live',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            scene: _scenes['live']!,
          );
        },
      );
    }
  }
}
