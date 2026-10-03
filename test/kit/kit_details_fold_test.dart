// KitDetailsFold and showKitTechnicalDetails
// (docs/ux-system/kit-api/KitDetailsFold.md "Tests required"): the one
// technical fold — collapsed by default, controlled or not, one of each
// value, copyable through KitCopy, never a secret, LTR values, a capped raw
// text, honest semantics, nothing when empty, instant under reduced motion,
// the standalone sheet, the confirm regression and no overflow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_effects.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_technical_value.dart';

import 'kit_harness.dart';
import 'kit_motion_still.dart';

const _toggle = ValueKey('kit-details-toggle');
const _copyAll = ValueKey('kit-details-copy-all');
const _address = KitTechnicalValue(
  'Address',
  '100.64.0.3:4096',
  spoken: '100.64.0.3, port 4096',
);
const _branch = KitTechnicalValue('Branch', 'feat/details-fold');
const _path = '/home/user/project/lib/some_long_file_name.dart';
const _sha = '0123456789abcdef0123456789abcdef01234567';

Future<void> _pump(
  WidgetTester tester,
  Widget fold, {
  Size size = const Size(412, 915),
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
  KitEffects effects = KitEffects.defaults,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    KitEffectsScope(
      effects: effects,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: fold,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  kitMotionStillTests(
    'KitDetailsFold',
    builds: {
      'collapsed': () => const KitDetailsFold(notes: ['Connection details']),
      'expanded': () => const KitDetailsFold(
        initiallyExpanded: true,
        notes: ['Connection details'],
      ),
    },
    changes: {
      'expand': KitMotionChange(
        build: () => const KitDetailsFold(notes: ['Connection details']),
        act: (tester, stage) =>
            stage.press(find.byKey(const ValueKey('kit-details-toggle'))),
        shows: 'Connection details',
      ),
    },
  );
  Future<void> openMotionDetails(BuildContext context) =>
      showKitTechnicalDetails(
        context,
        title: 'Connection details',
        text: 'Connection refused',
      );
  kitMotionStillTests(
    'showKitTechnicalDetails',
    opens: {
      'default': KitMotionOpen(openMotionDetails, shows: 'Connection details'),
    },
    changes: {
      'dismissed': kitModalDismiss(
        openMotionDetails,
        shows: 'Connection details',
      ),
    },
  );

  late List<MethodCall> platform;
  late List<Map<Object?, Object?>> announcements;

  setUp(() {
    KitRedact.clearKnownSecrets();
    platform = [];
    announcements = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call);
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<Object?, Object?>;
        if (map['type'] == 'announce') announcements.add(map);
        return null;
      },
    );
  });

  tearDown(() {
    KitRedact.clearKnownSecrets();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  String? copied() {
    final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
    return (call.arguments as Map)['text'] as String?;
  }

  testWidgets('1. collapsed by default; the toggle opens and closes it', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitDetailsFold(
        values: [_address],
        notes: ['Check the server is running'],
        text: 'connection refused',
      ),
    );
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('100.64.0.3:4096'), findsNothing);
    expect(find.text('Check the server is running'), findsNothing);
    expect(find.text('connection refused'), findsNothing);

    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(find.text('100.64.0.3:4096'), findsOneWidget);
    expect(find.text('Check the server is running'), findsOneWidget);
    expect(find.text('connection refused'), findsOneWidget);
    // The words stay "Details" when open.
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(find.text('100.64.0.3:4096'), findsNothing);

    await _pump(
      tester,
      const KitDetailsFold(
        key: ValueKey('second'),
        values: [_address],
        initiallyExpanded: true,
      ),
    );
    expect(find.text('100.64.0.3:4096'), findsOneWidget);
  });

  testWidgets('2. controlled: a tap asks the host and waits for it', (
    tester,
  ) async {
    final calls = <bool>[];
    await _pump(
      tester,
      KitDetailsFold(
        values: const [_address],
        expanded: false,
        onExpansionChanged: calls.add,
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    expect(find.text('100.64.0.3:4096'), findsNothing);

    await _pump(
      tester,
      KitDetailsFold(
        values: const [_address],
        expanded: true,
        onExpansionChanged: calls.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('100.64.0.3:4096'), findsOneWidget);
  });

  testWidgets('3. a value shows once, under its first label', (tester) async {
    await _pump(
      tester,
      const KitDetailsFold(
        initiallyExpanded: true,
        values: [
          KitTechnicalValue('Path', _path),
          KitTechnicalValue('Again', _path),
        ],
      ),
    );
    expect(find.text(_path), findsOneWidget);
    expect(find.text('Path'), findsOneWidget);
    expect(find.text('Again'), findsNothing);
  });

  testWidgets('4. copy: one value through KitCopy; Copy all copies lines', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitDetailsFold(
        initiallyExpanded: true,
        values: [_address, _branch],
        text: 'connection refused',
      ),
    );
    await tester.tap(find.byKey(const ValueKey('kit-details-copy-0')));
    await tester.pump();
    expect(copied(), '100.64.0.3:4096');
    expect(announcements, hasLength(1));
    expect((announcements.single['data'] as Map)['message'], 'Copied');
    expect(find.byType(SnackBar), findsNothing);

    expect(find.byKey(_copyAll), findsOneWidget);
    await tester.tap(find.byKey(_copyAll));
    await tester.pump();
    expect(
      copied(),
      'Address: 100.64.0.3:4096\nBranch: feat/details-fold\n\n'
      'connection refused',
    );
    await tester.pump(const Duration(seconds: 3));

    // One copyable value and no text: no Copy all.
    await _pump(
      tester,
      const KitDetailsFold(
        key: ValueKey('single'),
        initiallyExpanded: true,
        values: [_address],
      ),
    );
    expect(find.byKey(_copyAll), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('5. redaction: the raw text never shows or copies a secret', (
    tester,
  ) async {
    const text =
        'POST /v1/messages failed\n'
        'key sk-ant-FAKEFAKEFAKEFAKE0123456789\n'
        'Authorization: Bearer FAKETOKENFAKETOKEN0123456789';
    await _pump(
      tester,
      const KitDetailsFold(initiallyExpanded: true, text: text),
    );
    expect(find.textContaining('FAKE'), findsNothing);
    expect(find.textContaining('POST /v1/messages failed'), findsOneWidget);
    await tester.tap(find.byKey(_copyAll));
    await tester.pump();
    expect(copied(), isNot(contains('FAKE')));
    expect(copied(), contains('POST /v1/messages failed'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('5b. a value that is a key trips the debug assert', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitDetailsFold(
        initiallyExpanded: true,
        values: [KitTechnicalValue('Provider key', 'sk-ant-FAKEFAKEFAKE0123')],
      ),
    );
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('Provider key'));
  });

  testWidgets('6. paths and commit SHAs survive redaction', (tester) async {
    await _pump(
      tester,
      const KitDetailsFold(
        initiallyExpanded: true,
        values: [
          KitTechnicalValue('File', _path),
          KitTechnicalValue('Commit', _sha),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(_path), findsOneWidget);
    expect(find.text(_sha), findsOneWidget);
  });

  testWidgets('7. long text shows 12 lines, then all of it in place', (
    tester,
  ) async {
    final text = [for (var i = 1; i <= 30; i++) 'line $i'].join('\n');
    await _pump(tester, KitDetailsFold(initiallyExpanded: true, text: text));
    expect(find.textContaining('line 12'), findsOneWidget);
    expect(find.textContaining('line 13'), findsNothing);
    expect(find.text('Show all 30 lines'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kit-details-show-all')));
    await tester.pumpAndSettle();
    expect(find.textContaining('line 13'), findsOneWidget);
    expect(find.textContaining('line 30'), findsOneWidget);
    expect(find.text('Show all 30 lines'), findsNothing);
  });

  testWidgets('8. semantics: expanded state, one node per value, copy label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const KitDetailsFold(values: [_address]));
    expect(
      tester.getSemantics(find.byKey(_toggle)),
      matchesSemantics(
        label: 'Details',
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
        onTapHint: 'Details',
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(_toggle)),
      matchesSemantics(
        label: 'Details',
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
        onTapHint: 'Hide details',
      ),
    );
    expect(
      find.bySemanticsLabel('Address: ${KitBidi.ltr('100.64.0.3, port 4096')}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Copy address'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('9. RTL: the value is LTR, starting where its label starts', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitDetailsFold(
        initiallyExpanded: true,
        values: [KitTechnicalValue('Path', 'src/a.dart', key: Key('value'))],
      ),
      direction: TextDirection.rtl,
    );
    final value = find.byKey(const Key('value'));
    final direction = tester
        .element(value)
        .dependOnInheritedWidgetOfExactType<Directionality>()!
        .textDirection;
    expect(direction, TextDirection.ltr);
    expect(
      tester.getTopRight(value).dx,
      moreOrLessEquals(tester.getTopRight(find.text('Path')).dx, epsilon: 1),
    );
  });

  testWidgets('10. empty: no toggle at all', (tester) async {
    const fold = KitDetailsFold();
    expect(fold.isEmpty, isTrue);
    expect(const KitDetailsFold(text: '  ').isEmpty, isTrue);
    expect(const KitDetailsFold(notes: ['x']).isEmpty, isFalse);
    await _pump(tester, fold);
    expect(find.byKey(_toggle), findsNothing);
    expect(find.text('Details'), findsNothing);
  });

  for (final (name, disable, effects) in [
    ('system reduce motion', true, KitEffects.defaults),
    ('Effects motion Off', false, const KitEffects(motion: KitMotionLevel.off)),
  ]) {
    testWidgets('11. $name: the fold settles after one pump', (tester) async {
      await _pump(
        tester,
        const KitDetailsFold(values: [_address]),
        disableAnimations: disable,
        effects: effects,
      );
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.text('100.64.0.3:4096'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.text('100.64.0.3:4096'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('12. showKitTechnicalDetails: whole text, Copy all, closes', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    final text = [for (var i = 1; i <= 30; i++) 'frame $i'].join('\n');
    var done = false;
    unawaited(
      showKitTechnicalDetails(
        context,
        title: "Couldn't send",
        text: text,
        values: const [_address],
        sheetKey: const ValueKey('sheet'),
      ).then((_) => done = true),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    expect(find.text("Couldn't send"), findsOneWidget);
    expect(find.textContaining('frame 30'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-details-show-all')), findsNothing);
    expect(find.byKey(_copyAll), findsOneWidget);
    expect(find.text('100.64.0.3:4096'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kit-sheet-close')));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(find.byKey(const ValueKey('sheet')), findsNothing);

    // Back closes it too.
    done = false;
    unawaited(
      showKitTechnicalDetails(
        context,
        title: "Couldn't send",
        text: 'x',
      ).then((_) => done = true),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('13. showKitConfirm details still fold behind the toggle', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    unawaited(
      showKitConfirm(
        context,
        title: 'Revoke access?',
        body: 'The agent asks again next time.',
        confirmLabel: 'Revoke',
        kind: KitConfirmKind.destructive,
        details: const [KitTechnicalValue('Pattern', 'git push *')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('git push *'), findsNothing);
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(find.text('git push *'), findsOneWidget);
  });

  testWidgets('adaptive: a wide window puts the label in its column', (
    tester,
  ) async {
    const value = KitTechnicalValue('Branch', 'main', key: Key('value'));
    await _pump(
      tester,
      const KitDetailsFold(initiallyExpanded: true, values: [value]),
    );
    final label = find.text('Branch');
    final text = find.byKey(const Key('value'));
    expect(
      tester.getTopLeft(text).dy,
      greaterThan(tester.getTopLeft(label).dy),
    );
    expect(tester.getTopLeft(text).dx, tester.getTopLeft(label).dx);

    await _pump(
      tester,
      const KitDetailsFold(initiallyExpanded: true, values: [value]),
      size: const Size(1280, 800),
    );
    expect(
      tester.getTopLeft(text).dx - tester.getTopLeft(label).dx,
      greaterThanOrEqualTo(160),
    );
    expect(
      tester.getTopLeft(text).dy,
      lessThan(tester.getBottomLeft(label).dy),
    );
  });

  testWidgets('keyboard: Enter and Space toggle the focused fold', (
    tester,
  ) async {
    await _pump(tester, const KitDetailsFold(values: [_address]));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('100.64.0.3:4096'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('100.64.0.3:4096'), findsNothing);
  });

  group('14. no overflow', () {
    final long = '/home/user/${'very_long_directory_name/' * 8}file.dart';
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final direction in TextDirection.values) {
          testWidgets('${width.toInt()} · $scale · ${direction.name}', (
            tester,
          ) async {
            await _pump(
              tester,
              KitDetailsFold(
                initiallyExpanded: true,
                notes: const ['Check that the path exists on the server'],
                values: [KitTechnicalValue('Working folder', long), _branch],
                text: long,
              ),
              size: Size(width, 915),
              textScale: scale,
              direction: direction,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
