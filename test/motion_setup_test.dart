// Slice A of the motion and illustration pass
// (docs/design/motion-and-illustration-2026-09-25.md): setup and connecting.
//
// - Setup start leads with its drawing at the top, not an empty band
//   (design regressions ledger rows 1–2).
// - Setup progress keeps its title and bar in view while the log is open;
//   the log is one box, one line per line (ledger row 16).
// - Setup ready is one step: the celebration, one name field, and the
//   folder sheet only when asked.
// - Connecting states show the drawing that fits; only a wait loops.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_phone_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_ready_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_steps_scene.dart';
import 'package:opencode_mobile/ui/kit/scenes/setup_unplugged_scene.dart';
import 'package:opencode_mobile/ui/widgets/saved_server_connection_card.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'support/phone_setup_scenes.dart';

void _mockSecureStorage(WidgetTester tester) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secure,
      null,
    ),
  );
}

Future<void> _scene(WidgetTester tester, String name) async {
  _mockSecureStorage(tester);
  await pumpSetupScene(
    tester,
    setupScenes.firstWhere((s) => s.name == name),
    boundary: GlobalKey(),
  );
}

Finder _drawing<T extends KitScene>() => find.byWidgetPredicate(
  (widget) => widget is KitIllustration && widget.scene is T,
);

Widget _card({
  String? error,
  bool starting = false,
  bool phone = true,
  bool reduce = false,
}) => MaterialApp(
  theme: AppTheme.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: child!,
  ),
  home: Scaffold(
    body: SavedServerConnectionCard(
      profileName: 'Laptop',
      baseUrl: 'http://127.0.0.1:4096',
      error: error,
      attempts: 1,
      supportsTermux: true,
      onChangeServer: () {},
      onRetry: () {},
      onStartPhoneServer: phone ? () {} : null,
      startingPhoneServer: starting,
    ),
  ),
);

void main() {
  setUpAll(loadCaptureFonts);
  tearDown(() => KitMotion.loops = false);

  group('setup start', () {
    testWidgets('leads with the phone drawing at the top of the page', (
      tester,
    ) async {
      await _scene(tester, 'setup_start');
      final drawing = find.byKey(const ValueKey('phone-setup-hero-drawing'));
      expect(drawing, findsOneWidget);
      expect(_drawing<SetupPhoneScene>(), findsOneWidget);
      // No empty band above it: it starts right under the app bar.
      final appBar = tester.getRect(find.byType(AppBar));
      expect(tester.getRect(drawing).top - appBar.bottom, lessThan(24));
      // The title follows it, in the upper half of the screen.
      final title = tester.getRect(
        find.byKey(const ValueKey('phone-setup-start-headline')),
      );
      expect(title.top, greaterThan(tester.getRect(drawing).bottom));
      expect(title.top, lessThan(915 / 2));
    });

    testWidgets('a running setup draws its journey', (tester) async {
      await _scene(tester, 'setup_start_progress');
      expect(_drawing<SetupStepsScene>(), findsOneWidget);
    });
  });

  group('setup progress', () {
    testWidgets('the log opens in view, under a title and bar that stay', (
      tester,
    ) async {
      await _scene(tester, 'setup_progress_log');
      const screen = Rect.fromLTWH(0, 0, 412, 915);
      final title = tester.getRect(
        find.byKey(const Key('setup-progress-title')),
      );
      final bar = tester.getRect(
        find.byKey(const Key('setup-progress-overall')),
      );
      expect(screen.contains(title.topLeft), isTrue);
      expect(screen.contains(bar.bottomRight), isTrue);
      // The newest log line is on screen, not below the fold.
      final log = tester.getRect(find.byKey(const Key('setup-progress-log')));
      expect(log.bottom, lessThanOrEqualTo(915));
      expect(log.bottom, greaterThan(bar.bottom));
    });

    testWidgets('each log line takes one line, in one box', (tester) async {
      await _scene(tester, 'setup_progress_log');
      final log = find.byKey(const Key('setup-progress-log'));
      final text = find.descendant(
        of: log,
        matching: find.byType(SelectableText),
      );
      final context = tester.element(text);
      final style = Theme.of(context).textTheme.bodySmall!;
      final lineHeight = style.fontSize! * 1.45;
      // The tail: 40 lines. Wrapped apt lines would make it far taller.
      expect(tester.getSize(text).height / lineHeight, closeTo(40, 2));
      // One tinted box around the log: nothing inside it draws another.
      final boxes = find.descendant(
        of: find.ancestor(of: log, matching: find.byType(Container)).first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color != null,
        ),
      );
      expect(boxes, findsNothing);
    });

    testWidgets('Cancel sits with the steps, before the folded Details', (
      tester,
    ) async {
      await _scene(tester, 'setup_progress_running');
      final cancel = tester.getRect(
        find.byKey(const Key('setup-progress-cancel')),
      );
      final details = tester.getRect(
        find.byKey(const Key('setup-progress-details')),
      );
      final lastRow = tester.getRect(
        find.byKey(const ValueKey('setup-progress-row-opencode')),
      );
      expect(cancel.top, greaterThan(lastRow.bottom));
      expect(cancel.top - lastRow.bottom, lessThan(32));
      expect(details.top, greaterThan(cancel.bottom));
    });
  });

  group('setup ready', () {
    testWidgets('one step: the celebration, one name, no sheet on top', (
      tester,
    ) async {
      await _scene(tester, 'setup_ready');
      expect(_drawing<SetupReadyScene>(), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Create and open'), findsOneWidget);
      expect(find.text('Open a folder instead'), findsOneWidget);
      final appBar = tester.getRect(find.byType(AppBar));
      final drawing = find.byKey(const ValueKey('phone-setup-hero-drawing'));
      expect(tester.getRect(drawing).top - appBar.bottom, lessThan(24));
    });

    testWidgets('the celebration plays once and then rests', (tester) async {
      KitMotion.loops = true;
      await _scene(tester, 'setup_ready');
      await tester.pump(KitMotion.celebration);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('connecting', () {
    testWidgets('starting the phone server draws the phone, breathing', (
      tester,
    ) async {
      KitMotion.loops = true;
      await tester.pumpWidget(_card(starting: true));
      await tester.pump(KitMotion.entrance);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_drawing<SetupPhoneScene>(), findsOneWidget);
      final illustration = tester.widget<KitIllustration>(
        _drawing<SetupPhoneScene>(),
      );
      expect(
        (illustration.scene as SetupPhoneScene).mood,
        SetupPhoneMood.starting,
      );
      expect(illustration.ambient, isTrue);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('not answering draws the plug short of the portal', (
      tester,
    ) async {
      await tester.pumpWidget(_card());
      expect(_drawing<KitPortalScene>(), findsOneWidget);
      // The waiting bar never settles; step past the 8 s grace instead.
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(KitMotion.entrance);
      expect(
        find.byKey(const ValueKey('saved-server-not-answering')),
        findsOne,
      );
      expect(_drawing<SetupUnpluggedScene>(), findsOneWidget);
    });

    testWidgets('a stopped phone server rests: drawn, and still', (
      tester,
    ) async {
      KitMotion.loops = true;
      await tester.pumpWidget(_card(error: 'Connection refused'));
      await tester.pump(KitMotion.entrance);
      await tester.pump(const Duration(milliseconds: 16));
      final stopped = _drawing<SetupPhoneScene>();
      expect(stopped, findsOneWidget);
      expect(
        (tester.widget<KitIllustration>(stopped).scene as SetupPhoneScene).mood,
        SetupPhoneMood.stopped,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('another server that failed keeps its icon', (tester) async {
      await tester.pumpWidget(_card(error: 'Connection refused', phone: false));
      await tester.pumpAndSettle();
      expect(find.byType(KitIllustration), findsNothing);
      expect(find.byKey(const ValueKey('kit-state-icon')), findsOneWidget);
    });

    testWidgets('reduced motion shows the drawing finished and still', (
      tester,
    ) async {
      KitMotion.loops = true;
      // Stopped: no waiting bar, so anything moving would be the drawing.
      await tester.pumpWidget(_card(error: 'Connection refused', reduce: true));
      expect(_drawing<SetupPhoneScene>(), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      // Without reduced motion the same drawing plays its entrance.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_card(error: 'Connection refused'));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
