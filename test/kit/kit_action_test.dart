// kit-KitAction-v2 (docs/ux-system/kit-api/KitAction.md): KitAction,
// KitButton, KitActionBlock and KitActionStack in one file, as the frozen
// spec's own "Tests" section names it.
//
// Covers: a disabled action's reason renders as visible text and as the
// button's semantic hint (STATE-8); a destructive tertiary forces the
// block to stack on every window, with clearance around it (LAY-9,
// LAY-14); the block is one end-aligned row from medium up otherwise;
// overflow into "More", with a destructive item last after a divider;
// KitAction.copy; `working` ignores taps; the shortcut hint; and KIT-43
// compatibility (old call shapes, old keys).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

const _compact = Size(412, 915);
const _medium = Size(700, 900);
const _large = Size(1280, 800);
const _shortWide = Size(915, 412); // wide but under KitLayout.shortHeight.

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  Size size = _compact,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Connects a mouse for the test (a fine pointer, [KitLayout.finePointer]).
Future<void> _connectMouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
}

void main() {
  group('KitAction', () {
    test(
      'enabled is true for a callback or a copy action, false otherwise',
      () {
        expect(KitAction(label: 'Save', onPressed: () {}).enabled, isTrue);
        expect(KitAction(label: 'Save', onPressed: null).enabled, isFalse);
        expect(KitAction.copy(label: 'Copy', text: () => 'x').enabled, isTrue);
      },
    );
  });

  group('disabledReason (STATE-8, P7.6)', () {
    testWidgets(
      'KitActionBlock shows a disabled primary\'s reason under it, as text '
      'and as the semantic hint',
      (tester) async {
        await _pumpAt(
          tester,
          KitActionBlock(
            primary: const KitAction(
              label: 'Save',
              onPressed: null,
              disabledReason: 'Fill in the server address first.',
            ),
          ),
        );

        expect(find.text('Fill in the server address first.'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Save')),
          matchesSemantics(
            label: 'Save',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hint: 'Fill in the server address first.',
          ),
        );
      },
    );

    testWidgets('KitActionStack shows a disabled tertiary\'s reason under it', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        KitActionStack(
          tertiary: [
            const KitAction(
              label: 'Stop',
              onPressed: null,
              disabledReason: 'Nothing is running.',
            ),
          ],
        ),
      );

      expect(find.text('Nothing is running.'), findsOneWidget);
      final reason = tester.getTopLeft(find.text('Nothing is running.'));
      final button = tester.getTopLeft(find.text('Stop'));
      expect(reason.dy, greaterThan(button.dy));
    });

    testWidgets('a disabled action with no reason renders with no reason line '
        '(KIT-43: unchanged for callers that pass none)', (tester) async {
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: const KitAction(label: 'Save', onPressed: null),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('kit-action-reason-primary')),
        findsNothing,
      );
    });

    testWidgets('a row (medium+) collects reasons under it, end-aligned', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        Align(
          alignment: Alignment.topRight,
          child: KitActionBlock(
            primary: const KitAction(
              label: 'Save',
              onPressed: null,
              disabledReason: 'Fill in the server address first.',
            ),
            secondary: const KitAction(label: 'Cancel', onPressed: null),
          ),
        ),
        size: _medium,
      );

      expect(find.text('Fill in the server address first.'), findsOneWidget);
      final reason = tester.getTopLeft(
        find.text('Fill in the server address first.'),
      );
      final save = tester.getTopLeft(find.text('Save'));
      expect(reason.dy, greaterThan(save.dy));
    });
  });

  group('destructive stacking (§2.7, LAY-14)', () {
    Widget block() => KitActionBlock(
      primary: const KitAction(label: 'Save', onPressed: null),
      secondary: const KitAction(label: 'Cancel', onPressed: null),
      tertiary: [
        KitAction(label: 'Duplicate', onPressed: () {}),
        KitAction(label: 'Delete', onPressed: () {}, destructive: true),
      ],
    );

    for (final MapEntry(key: name, value: size) in {
      'compact': _compact,
      'medium': _medium,
      'large': _large,
    }.entries) {
      testWidgets('a destructive tertiary forces the stack on $name', (
        tester,
      ) async {
        await _pumpAt(tester, block(), size: size);

        // Stacked: Save above Cancel above the tertiary actions, each its
        // own line (never the end-aligned row, whatever the window).
        final save = tester.getTopLeft(find.text('Save'));
        final cancel = tester.getTopLeft(find.text('Cancel'));
        final duplicate = tester.getTopLeft(find.text('Duplicate'));
        final delete = tester.getTopLeft(find.text('Delete'));
        expect(cancel.dy, greaterThan(save.dy));
        expect(duplicate.dy, greaterThan(cancel.dy));
        expect(delete.dy, greaterThan(duplicate.dy));

        // LAY-9: the destructive target keeps its clearance from the one
        // above it.
        final duplicateBottom = tester.getBottomLeft(find.text('Duplicate')).dy;
        final deleteTop = tester.getTopLeft(find.text('Delete')).dy;
        expect(deleteTop - duplicateBottom, greaterThanOrEqualTo(8));
      });
    }

    testWidgets('a short window keeps the stack even when wide (LAY-3)', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: const KitAction(label: 'Save', onPressed: null),
          secondary: const KitAction(label: 'Cancel', onPressed: null),
        ),
        size: _shortWide,
      );
      final save = tester.getTopLeft(find.text('Save'));
      final cancel = tester.getTopLeft(find.text('Cancel'));
      expect(cancel.dy, greaterThan(save.dy));
    });

    testWidgets(
      'with no destructive tertiary, medium and up is one row with the '
      'primary at the end',
      (tester) async {
        await _pumpAt(
          tester,
          KitActionBlock(
            primary: const KitAction(label: 'Save', onPressed: null),
            secondary: const KitAction(label: 'Cancel', onPressed: null),
          ),
          size: _medium,
        );
        final save = tester.getTopLeft(find.text('Save'));
        final cancel = tester.getTopLeft(find.text('Cancel'));
        // A row: both on the same line, Save (primary) to the right of
        // Cancel (secondary) in LTR (LAY-13: primary at the end).
        expect(save.dy, cancel.dy);
        expect(save.dx, greaterThan(cancel.dx));
      },
    );
  });

  group('overflow ("More", §2.7)', () {
    testWidgets('a third tertiary action moves into More', (tester) async {
      await _pumpAt(
        tester,
        KitActionBlock(
          tertiary: [
            KitAction(label: 'One', onPressed: () {}),
            KitAction(label: 'Two', onPressed: () {}),
            KitAction(label: 'Three', onPressed: () {}),
          ],
        ),
      );
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsNothing);
      expect(find.byKey(const ValueKey('kit-actions-more')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kit-actions-more')));
      await tester.pumpAndSettle();
      expect(find.text('Three'), findsOneWidget);
    });

    testWidgets('a destructive overflow action renders last, after a divider', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        KitActionBlock(
          tertiary: [
            KitAction(label: 'One', onPressed: () {}),
            KitAction(label: 'Two', onPressed: () {}),
            KitAction(label: 'Three', onPressed: () {}),
            KitAction(label: 'Delete', onPressed: () {}, destructive: true),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('kit-actions-more')));
      await tester.pumpAndSettle();

      final divider = tester.getTopLeft(find.byType(PopupMenuDivider));
      final three = tester.getTopLeft(find.text('Three'));
      final delete = tester.getTopLeft(find.text('Delete'));
      expect(delete.dy, greaterThan(divider.dy));
      expect(divider.dy, greaterThan(three.dy));
    });

    testWidgets('tapping an overflow item calls its onPressed', (tester) async {
      var tapped = 0;
      await _pumpAt(
        tester,
        KitActionBlock(
          tertiary: [
            KitAction(label: 'One', onPressed: () {}),
            KitAction(label: 'Two', onPressed: () {}),
            KitAction(label: 'Three', onPressed: () => tapped++),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('kit-actions-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Three'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });

  group('KitAction.copy (KIT-23)', () {
    late List<MethodCall> platform;
    late List<Map<Object?, Object?>> announcements;

    setUp(() {
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
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      );
    });

    String? copiedText() {
      final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
      return (call.arguments as Map)['text'] as String?;
    }

    testWidgets(
      'copies the text read at tap time, announces once, shows the check '
      'then reverts, with no SnackBar',
      (tester) async {
        var reads = 0;
        await _pumpAt(
          tester,
          KitActionBlock(
            primary: KitAction.copy(
              label: 'Copy details',
              text: () {
                reads++;
                return 'details-$reads';
              },
            ),
          ),
        );

        await tester.tap(find.text('Copy details'));
        await tester.pump();

        expect(reads, 1);
        expect(copiedText(), 'details-1');
        expect(announcements, hasLength(1));
        expect((announcements.single['data'] as Map)['message'], 'Copied');
        expect(find.text('Copied'), findsOneWidget);
        expect(find.text('Copy details'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byKey(const ValueKey('kit-action-copied')), findsOneWidget);

        await tester.pump(KitMotion.copiedHold);
        expect(find.text('Copy details'), findsOneWidget);
        expect(find.text('Copied'), findsNothing);
      },
    );
  });

  group('working (STATE-7, C21 f)', () {
    testWidgets('shows the spinner and ignores taps', (tester) async {
      var tapped = 0;
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: KitAction(
            label: 'Send',
            onPressed: () => tapped++,
            working: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('kit-button-working')), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapped, 0);
    });
  });

  group('shortcut (visual language §5)', () {
    testWidgets('shown on a fine pointer, absent on touch', (tester) async {
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: const KitAction(
            label: 'Send',
            onPressed: null,
            shortcut: 'Ctrl+Enter',
          ),
        ),
        size: _large,
      );
      expect(find.textContaining('Ctrl+Enter'), findsNothing);

      await _connectMouse(tester);
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: const KitAction(
            label: 'Send',
            onPressed: null,
            shortcut: 'Ctrl+Enter',
          ),
        ),
        size: _large,
      );
      expect(find.textContaining('Ctrl+Enter'), findsOneWidget);
    });

    testWidgets('isolated left to right in Arabic', (tester) async {
      await _connectMouse(tester);
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: const KitAction(
            label: 'إرسال',
            onPressed: null,
            shortcut: 'Ctrl+Enter',
          ),
        ),
        size: _large,
        locale: const Locale('ar'),
      );
      final shown = tester
          .widgetList<Text>(find.textContaining('Ctrl+Enter'))
          .single;
      expect(shown.data, KitBidi.ltr('Ctrl+Enter'));
    });
  });

  group('KIT-43 compatibility', () {
    testWidgets('the old menu: slot keeps working', (tester) async {
      await _pumpAt(
        tester,
        KitActionBlock(
          primary: const KitAction(label: 'Save', onPressed: null),
          menu: TextButton(onPressed: () {}, child: const Text('Legacy menu')),
        ),
      );
      expect(find.text('Legacy menu'), findsOneWidget);
    });

    testWidgets('KitButton.fromAction keeps the caller\'s key', (tester) async {
      await _pumpAt(
        tester,
        KitButton.fromAction(
          KitAction(
            key: const ValueKey('my-save-button'),
            label: 'Save',
            onPressed: () {},
          ),
          role: KitButtonRole.primary,
        ),
      );
      expect(find.byKey(const ValueKey('my-save-button')), findsOneWidget);
    });

    testWidgets('every existing KitButton constructor shape still compiles', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        Column(
          children: [
            KitButton.primary(label: 'A', onPressed: () {}),
            KitButton.secondary(label: 'B', onPressed: () {}),
            KitButton.tertiary(label: 'C', onPressed: () {}),
            KitButton(
              role: KitButtonRole.primary,
              label: 'D',
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      for (final label in ['A', 'B', 'C', 'D']) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
