// Gate G9/G9x contracts for KitUndo and KitBottomInset
// (docs/ux-system/kit-api/KitUndo.md, KitBottomInset.md; STANDARDS KIT-34,
// DATA-11, MOT-1, MOT-11, A11Y-3, A11Y-8, LAY-8, LAY-9, LAY-10). Fake async
// throughout `testWidgets` (the automated test binding already runs each
// test inside a fake-async zone, so `Timer` and `tester.pump(duration)`
// advance virtual time).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/kit_bottom_inset.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';

import '../goldens/kit/kit_gallery.dart' show loadKitGalleryFonts;
import 'kit_harness.dart';
import 'kit_motion_still.dart';

/// A host with an optional [KitBottomInset] ancestor, for the placement
/// tests: `pumpKitHost` (test/kit/kit_harness.dart) has no publisher above
/// its content, so these tests build their own tree.
Future<BuildContext> _pumpUndoHost(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  KitClearance? clearance,
  Locale locale = const Locale('en'),
  bool light = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  Widget body = Builder(
    builder: (inner) {
      context = inner;
      return const SizedBox.expand();
    },
  );
  if (clearance != null) {
    body = KitBottomInset(insets: clearance, child: body);
  }
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: light ? AppTheme.light() : AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: body),
    ),
  );
  return context;
}

void main() {
  // KitUndo keeps one app-wide pending bar; a test that leaves one showing
  // (item 6, item 9) must not leak it into the next test.
  tearDown(() => KitUndo.commitPending());

  group('showKitUndo (KitUndo.md)', () {
    testWidgets('1. shows the message and Undo; no framework SnackBar', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      showKitUndo(context, message: 'Archived "Fix login"', onUndo: () {});
      await tester.pump();
      expect(find.text('Archived "Fix login"'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      KitUndo.commitPending();
    });

    testWidgets('2. the window elapsing commits once and closes the bar', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      var commits = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();
      expect(KitUndo.debugHasPending, isTrue);
      await tester.pump(KitUndo.window);
      expect(commits, 1);
      expect(KitUndo.debugHasPending, isFalse);
      // The exit fade (KitMotion.quick) still has to settle.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Archived "Fix login"'), findsNothing);
    });

    testWidgets('3. tapping Undo runs onUndo once, never onCommit', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      var undos = 0;
      var commits = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () => undos++,
        onCommit: () => commits++,
      );
      await tester.pump();
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(undos, 1);
      expect(commits, 0);
      expect(KitUndo.debugHasPending, isFalse);
      // The window running out afterwards must not also commit.
      await tester.pump(KitUndo.window);
      expect(commits, 0);
    });

    testWidgets('4. one at a time: a new bar commits the pending one first', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      var firstCommits = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () {},
        onCommit: () => firstCommits++,
      );
      await tester.pump();
      showKitUndo(context, message: 'Removed "Add tests"', onUndo: () {});
      await tester.pump();
      expect(firstCommits, 1);
      expect(find.text('Archived "Fix login"'), findsNothing);
      expect(find.text('Removed "Add tests"'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      KitUndo.commitPending();
    });

    testWidgets('5a. a route pop commits the caller\'s bar', (tester) async {
      final context = await pumpKitHost(tester);
      var commits = 0;
      late BuildContext pushed;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (inner) {
            pushed = inner;
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pumpAndSettle();
      showKitUndo(
        pushed,
        message: 'Archived "Fix login"',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();
      Navigator.of(pushed).pop();
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(KitUndo.debugHasPending, isFalse);
    });

    testWidgets('5b. AppLifecycleState.paused commits the pending bar', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      var commits = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(commits, 1);
      expect(KitUndo.debugHasPending, isFalse);
    });

    testWidgets('5c. commitPending() commits the pending bar; no-op after', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      var commits = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();
      KitUndo.commitPending();
      await tester.pump();
      expect(commits, 1);
      KitUndo.commitPending();
      await tester.pump();
      expect(commits, 1, reason: 'no-op when nothing is pending');
    });

    testWidgets('6. accessible navigation: no timeout; Dismiss commits', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final context = await pumpKitHost(tester);
      var commits = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(
        find.text('Archived "Fix login"'),
        findsOneWidget,
        reason: 'never auto-dismissed under accessible navigation',
      );
      expect(commits, 0);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(commits, 1);
    });

    testWidgets(
      '7. onUndo throws with onUndoFailed: it gets the error; tryAgain '
      're-runs onUndo',
      (tester) async {
        final context = await pumpKitHost(tester);
        final error = Exception('offline');
        Object? received;
        VoidCallback? tryAgain;
        var undoCalls = 0;
        showKitUndo(
          context,
          message: 'Archived "Fix login"',
          onUndo: () {
            undoCalls++;
            if (undoCalls == 1) throw error;
          },
          onUndoFailed: (e, retry) {
            received = e;
            tryAgain = retry;
          },
        );
        await tester.pump();
        await tester.tap(find.text('Undo'));
        await tester.pump();
        expect(received, error);
        expect(undoCalls, 1);
        // The bar hands off entirely once onUndoFailed exists.
        expect(KitUndo.debugHasPending, isFalse);
        tryAgain!();
        await tester.pump();
        expect(undoCalls, 2);
      },
    );

    testWidgets(
      '8. onUndo throws, no onUndoFailed: failure words and Try again, no '
      'timeout, Try again re-runs',
      (tester) async {
        final context = await pumpKitHost(tester);
        var undoCalls = 0;
        showKitUndo(
          context,
          message: 'Archived "Fix login"',
          onUndo: () {
            undoCalls++;
            if (undoCalls < 2) throw Exception('offline');
          },
        );
        await tester.pump();
        await tester.tap(find.text('Undo'));
        await tester.pump();
        expect(
          find.text('Couldn\'t undo. Archived "Fix login"'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Undo'), findsNothing);
        // No timeout in the failure form.
        await tester.pump(const Duration(seconds: 60));
        expect(KitUndo.debugHasPending, isTrue);
        await tester.tap(find.text('Try again'));
        await tester.pump();
        expect(undoCalls, 2);
        expect(KitUndo.debugHasPending, isFalse, reason: 'the retry succeeded');
      },
    );

    testWidgets(
      '9. async onUndo in flight shows working, ignores a second tap',
      (tester) async {
        final context = await pumpKitHost(tester);
        final completer = Completer<void>();
        var undoCalls = 0;
        showKitUndo(
          context,
          message: 'Archived "Fix login"',
          onUndo: () {
            undoCalls++;
            return completer.future;
          },
        );
        await tester.pump();
        await tester.tap(find.text('Undo'));
        await tester.pump();
        expect(undoCalls, 1);
        expect(
          find.text('Archived "Fix login"'),
          findsOneWidget,
          reason: 'message unchanged while working',
        );
        await tester.tap(find.text('Undo'));
        await tester.pump();
        expect(undoCalls, 1, reason: 'a second tap while working is ignored');
        completer.complete();
        await tester.pump();
        expect(KitUndo.debugHasPending, isFalse);
      },
    );

    group('9b. a commit trigger while an async onUndo is in flight never '
        'commits (DATA-11: Undo taken)', () {
      /// Shows a deferred-commit bar on [context], taps Undo so its async
      /// onUndo is in flight, and returns the commit counter and the undo's
      /// completer.
      Future<({int Function() commits, Completer<void> undo})> startUndo(
        WidgetTester tester,
        BuildContext context,
      ) async {
        var commits = 0;
        final undo = Completer<void>();
        showKitUndo(
          context,
          message: 'Archived "Fix login"',
          onUndo: () => undo.future,
          onCommit: () => commits++,
        );
        await tester.pump();
        await tester.tap(find.text('Undo'));
        await tester.pump();
        return (commits: () => commits, undo: undo);
      }

      Future<void> finish(
        WidgetTester tester,
        ({int Function() commits, Completer<void> undo}) run,
      ) async {
        run.undo.complete();
        await tester.pump();
        await tester.pump(KitUndo.window);
        expect(run.commits(), 0, reason: 'Undo was taken: onCommit never');
        expect(tester.takeException(), isNull);
      }

      testWidgets('the owning route pops', (tester) async {
        final context = await pumpKitHost(tester);
        late BuildContext pushed;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (inner) {
              pushed = inner;
              return const SizedBox.expand();
            },
          ),
        );
        await tester.pumpAndSettle();
        final run = await startUndo(tester, pushed);
        Navigator.of(pushed).pop();
        await tester.pumpAndSettle();
        expect(run.commits(), 0);
        expect(tester.takeException(), isNull);
        await finish(tester, run);
      });

      testWidgets('the app pauses', (tester) async {
        final context = await pumpKitHost(tester);
        final run = await startUndo(tester, context);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(run.commits(), 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await finish(tester, run);
      });

      testWidgets('a new showKitUndo takes the slot', (tester) async {
        final context = await pumpKitHost(tester);
        final run = await startUndo(tester, context);
        showKitUndo(context, message: 'Removed "Add tests"', onUndo: () {});
        await tester.pumpAndSettle();
        expect(run.commits(), 0);
        expect(find.text('Removed "Add tests"'), findsOneWidget);
        expect(find.text('Archived "Fix login"'), findsNothing);
        await finish(tester, run);
        await tester.pumpAndSettle();
        expect(
          find.text('Removed "Add tests"'),
          findsNothing,
          reason: 'the second bar\'s own window ran out meanwhile',
        );
      });

      testWidgets('commitPending()', (tester) async {
        final context = await pumpKitHost(tester);
        final run = await startUndo(tester, context);
        KitUndo.commitPending();
        await tester.pump();
        expect(run.commits(), 0);
        expect(KitUndo.debugHasPending, isFalse);
        await finish(tester, run);
      });

      testWidgets('Dismiss (accessible navigation)', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final context = await pumpKitHost(tester);
        final run = await startUndo(tester, context);
        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pump();
        expect(run.commits(), 0);
        await finish(tester, run);
      });

      testWidgets(
        'the bar closed meanwhile and the undo then fails: the failure form '
        'comes back (never silent), still without a commit',
        (tester) async {
          final context = await pumpKitHost(tester);
          final run = await startUndo(tester, context);
          KitUndo.commitPending();
          await tester.pumpAndSettle();
          expect(find.text('Archived "Fix login"'), findsNothing);
          run.undo.completeError(Exception('offline'));
          await tester.pumpAndSettle();
          expect(
            find.text('Couldn\'t undo. Archived "Fix login"'),
            findsOneWidget,
          );
          expect(find.text('Try again'), findsOneWidget);
          expect(run.commits(), 0);
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('10. placement', () {
      testWidgets('compact clears KitBottomInset plus space2', (tester) async {
        final context = await _pumpUndoHost(
          tester,
          size: const Size(412, 915),
          clearance: const KitClearance(bottom: 120),
        );
        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          message: 'Archived "Fix login"',
          onUndo: () {},
        );
        // The entrance slide (KitMotion.standard) must settle before the
        // rest position is measured.
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byKey(const Key('the-undo-bar')));
        final windowHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(windowHeight - rect.bottom, greaterThanOrEqualTo(128));
        KitUndo.commitPending();
      });

      testWidgets('medium/expanded caps width at 480 and starts at 16 dp', (
        tester,
      ) async {
        final context = await _pumpUndoHost(
          tester,
          size: const Size(1280, 800),
        );
        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          message: 'Archived "Fix login"',
          onUndo: () {},
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byKey(const Key('the-undo-bar')));
        expect(rect.width, lessThanOrEqualTo(480));
        expect(rect.left, 16);
        KitUndo.commitPending();
      });

      testWidgets('RTL hugs the end (the right edge)', (tester) async {
        final context = await _pumpUndoHost(
          tester,
          size: const Size(1280, 800),
          locale: const Locale('ar'),
        );
        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          message: 'أرشفة "إصلاح تسجيل الدخول"',
          onUndo: () {},
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byKey(const Key('the-undo-bar')));
        final windowWidth =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        expect(windowWidth - rect.right, 16);
        KitUndo.commitPending();
      });
    });

    testWidgets(
      '11. one live region; message announced once; Undo is >= 48x48 with '
      'a label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final context = await pumpKitHost(tester);
        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          undoKey: const Key('the-undo-action'),
          message: 'Archived "Fix login"',
          onUndo: () {},
        );
        await tester.pumpAndSettle();
        final bar = tester.getSemantics(find.byKey(const Key('the-undo-bar')));
        expect(bar.flagsCollection.isLiveRegion, isTrue);
        final size = tester.getSize(find.byKey(const Key('the-undo-action')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        final action = tester.getSemantics(
          find.byKey(const Key('the-undo-action')),
        );
        expect(action.label, contains('Undo'));
        expect(action.label, contains('Archived "Fix login"'));
        KitUndo.commitPending();
        semantics.dispose();
      },
    );

    testWidgets(
      '11b. the live region\'s own label is the message; it changes once, to '
      'the failure form (which is what the platforms announce)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final context = await pumpKitHost(tester);
        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          message: 'Archived "Fix login"',
          onUndo: () => throw Exception('offline'),
        );
        await tester.pumpAndSettle();
        final bar = find.byKey(const Key('the-undo-bar'));
        final labels = <String>[];
        void record() {
          final node = tester.getSemantics(bar);
          expect(node.flagsCollection.isLiveRegion, isTrue);
          if (labels.isEmpty || labels.last != node.label) {
            labels.add(node.label);
          }
        }

        record();
        expect(labels, ['Archived "Fix login"']);
        // The visible words are excluded: nothing below the live region
        // repeats the message as its own node.
        final below = <String>[];
        bool collect(SemanticsNode node) {
          below.add(node.label);
          node.visitChildren(collect);
          return true;
        }

        tester.getSemantics(bar).visitChildren(collect);
        expect(
          below,
          isNot(contains('Archived "Fix login"')),
          reason: 'the message is spoken once, from the live region',
        );
        await tester.tap(find.text('Undo'));
        await tester.pump();
        record();
        await tester.pump(const Duration(seconds: 1));
        record();
        await tester.pumpAndSettle();
        record();
        expect(labels, [
          'Archived "Fix login"',
          'Couldn\'t undo. Archived "Fix login"',
        ]);
        KitUndo.commitPending();
        semantics.dispose();
      },
    );

    testWidgets(
      '11c. while working the action is honestly busy: not enabled, no tap '
      'action, value "Undoing"',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final context = await pumpKitHost(tester);
        final undo = Completer<void>();
        showKitUndo(
          context,
          undoKey: const Key('the-undo-action'),
          message: 'Archived "Fix login"',
          onUndo: () => undo.future,
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('the-undo-action'));
        expect(
          tester.getSemantics(action),
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        await tester.tap(find.text('Undo'));
        await tester.pump();
        final busy = tester.getSemantics(action);
        expect(
          busy,
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
            value: 'Undoing',
          ),
        );
        undo.complete();
        await tester.pumpAndSettle();
        semantics.dispose();
      },
    );

    testWidgets('12a. Ctrl+Z does not take Undo while a text field has focus', (
      tester,
    ) async {
      // Defensive: a modifier state left running by an unrelated preceding
      // test must never leak into this one (flutter_test resets this
      // itself between tests; this only guards against that changing).
      HardwareKeyboard.instance.clearState();
      final controller = TextEditingController();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return TextField(
                  key: const Key('a-text-field'),
                  controller: controller,
                );
              },
            ),
          ),
        ),
      );
      var undoCalls = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () => undoCalls++,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('a-text-field')));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(undoCalls, 0, reason: 'a text field has focus');
      KitUndo.commitPending();
    });

    testWidgets('12b. Ctrl+Z takes Undo with no text field focused', (
      tester,
    ) async {
      HardwareKeyboard.instance.clearState();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      var undoCalls = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () => undoCalls++,
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(undoCalls, 1);
    });

    testWidgets('12c. Ctrl+Shift+Z (redo) and Ctrl+Alt+Z do not take Undo', (
      tester,
    ) async {
      HardwareKeyboard.instance.clearState();
      final context = await pumpKitHost(tester);
      var undoCalls = 0;
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () => undoCalls++,
      );
      await tester.pump();
      for (final extra in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(extra);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(extra);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }
      expect(undoCalls, 0);
      expect(KitUndo.debugHasPending, isTrue);
      KitUndo.commitPending();
    });

    testWidgets(
      '12d. a focused widget that handles Ctrl+Z itself (a terminal) keeps '
      'it',
      (tester) async {
        HardwareKeyboard.instance.clearState();
        var terminalGotIt = 0;
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (inner) {
                  context = inner;
                  return Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.keyZ) {
                        terminalGotIt++;
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        var undoCalls = 0;
        showKitUndo(
          context,
          message: 'Archived "Fix login"',
          onUndo: () => undoCalls++,
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(terminalGotIt, 1);
        expect(undoCalls, 0);
        KitUndo.commitPending();
      },
    );

    testWidgets(
      '13a. reduced motion (system): the entrance and exit settle in one '
      'pump()',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (inner) {
                  context = inner;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        );
        showKitUndo(context, message: 'Archived "Fix login"', onUndo: () {});
        await tester.pump();
        expect(find.text('Archived "Fix login"'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
        KitUndo.commitPending();
        await tester.pump();
        expect(find.text('Archived "Fix login"'), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets(
      '13b. reduced motion (Effects Animations Off) settles in one pump()',
      (tester) async {
        final context = await pumpKitHost(
          tester,
          effects: const KitEffects(motion: KitMotionLevel.off),
        );
        showKitUndo(context, message: 'Archived "Fix login"', onUndo: () {});
        await tester.pump();
        expect(find.text('Archived "Fix login"'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
        KitUndo.commitPending();
        await tester.pump();
        expect(find.text('Archived "Fix login"'), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets(
      '13c. motion: the entrance fades and slides on KitMotion.enter; the '
      'exit fades on KitMotion.exit with no slide',
      (tester) async {
        final context = await pumpKitHost(tester);
        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          message: 'Archived "Fix login"',
          onUndo: () {},
        );
        await tester.pumpAndSettle();
        final rest = tester.getRect(find.byKey(const Key('the-undo-bar')));
        double opacity() => tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(const Key('the-undo-bar')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;

        KitUndo.commitPending();
        await tester.pump();
        await tester.pump(
          Duration(milliseconds: KitMotion.quick.inMilliseconds ~/ 2),
        );
        // CurvedAnimation applies reverseCurve to the controller's own value
        // as it runs back from 1 to 0.
        expect(opacity(), closeTo(KitMotion.exit.transform(0.5), 0.01));
        expect(
          tester.getRect(find.byKey(const Key('the-undo-bar'))),
          rest,
          reason: 'the exit is a fade only',
        );
        await tester.pumpAndSettle();

        showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          message: 'Archived "Fix login"',
          onUndo: () {},
        );
        await tester.pump();
        await tester.pump(
          Duration(milliseconds: KitMotion.standard.inMilliseconds ~/ 2),
        );
        final t = KitMotion.enter.transform(0.5);
        expect(opacity(), closeTo(t, 0.01));
        final midway = tester.getRect(find.byKey(const Key('the-undo-bar')));
        expect(midway.top - rest.top, closeTo((1 - t) * 8, 0.01));
        await tester.pumpAndSettle();
        KitUndo.commitPending();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('14. no HapticFeedback and no KitHaptics call in any path', (
      tester,
    ) async {
      final calls = recordHaptics(tester);
      final context = await pumpKitHost(tester);
      showKitUndo(
        context,
        message: 'Archived "Fix login"',
        onUndo: () => throw Exception('offline'),
      );
      await tester.pump();
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(calls, isEmpty);
      KitUndo.commitPending();
    });
  });

  group('KitBottomInset (KitBottomInset.md)', () {
    testWidgets('1. with no publisher, of() falls back to MediaQuery', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 24),
            viewInsets: EdgeInsets.only(bottom: 10),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final clearance = KitBottomInset.of(context);
      expect(clearance.bottom, 34);
      expect(clearance.start, 0);
    });

    testWidgets('2. KitBottomInset publishes; add() adds extraBottom', (
      tester,
    ) async {
      late BuildContext outer;
      late BuildContext inner;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: KitBottomInset(
            insets: const KitClearance(bottom: 100),
            child: Builder(
              builder: (c) {
                outer = c;
                return KitBottomInset.add(
                  extraBottom: 58,
                  child: Builder(
                    builder: (c2) {
                      inner = c2;
                      return const SizedBox.expand();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(KitBottomInset.of(outer).bottom, 100);
      expect(KitBottomInset.of(inner).bottom, 158);
    });

    testWidgets('3. add(start:) replaces start, keeps bottom', (tester) async {
      late BuildContext inner;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: KitBottomInset(
            insets: const KitClearance(bottom: 100, start: 40),
            child: KitBottomInset.add(
              extraBottom: 0,
              start: 296,
              child: Builder(
                builder: (c) {
                  inner = c;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      final clearance = KitBottomInset.of(inner);
      expect(clearance.start, 296);
      expect(clearance.bottom, 100);
    });

    testWidgets(
      '4. a descendant depending through of() rebuilds on change; read() '
      'does not depend',
      (tester) async {
        var bottom = 100.0;
        var readBuilds = 0;
        var ofBuilds = 0;
        late StateSetter setState;
        // Built once and reused: a fresh closure at every StatefulBuilder
        // rebuild would itself force a rebuild regardless of dependency
        // tracking, which is exactly what this test must not measure.
        final readChild = Builder(
          builder: (c) {
            readBuilds++;
            KitBottomInset.read(c);
            return const SizedBox(width: 10, height: 10);
          },
        );
        final ofChild = Builder(
          builder: (c) {
            ofBuilds++;
            KitBottomInset.of(c);
            return const SizedBox(width: 10, height: 10);
          },
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setter) {
                setState = setter;
                return Column(
                  children: [
                    KitBottomInset(
                      insets: KitClearance(bottom: bottom),
                      child: readChild,
                    ),
                    KitBottomInset(
                      insets: KitClearance(bottom: bottom),
                      child: ofChild,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        expect(readBuilds, 1);
        expect(ofBuilds, 1);
        setState(() => bottom = 140);
        await tester.pump();
        expect(ofBuilds, 2, reason: 'of() depends on the published value');
        expect(readBuilds, 1, reason: 'read() must not register a dependency');
      },
    );

    testWidgets(
      '5. add() keeps MediaQuery.padding.bottom equal to the published '
      'bottom (keyboard closed)',
      (tester) async {
        late BuildContext inner;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: KitBottomInset.add(
                extraBottom: 100,
                child: Builder(
                  builder: (c) {
                    inner = c;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        );
        expect(MediaQuery.paddingOf(inner).bottom, 100);
        expect(KitBottomInset.of(inner).bottom, 100);
      },
    );

    testWidgets('6. values snap to whole physical pixels at DPR 3', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            devicePixelRatio: 3,
            padding: EdgeInsets.only(bottom: 57.9),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(KitBottomInset.of(context).bottom, 58.0);
    });
  });

  // G8x (gate, test/kit_motion_test.dart's manifest): showKitUndo does not
  // push a route (KIT-11, the one exception), so it registers through
  // `changes:` rather than `opens:`, which expects a pushed route.
  //
  // No "Undo tapped, working" sample here: KitButton's own working spinner
  // (`_Spinner`, `kit_buttons.dart`, not this unit's file) is a bare
  // `CircularProgressIndicator` that keeps ticking under stillness — an
  // existing, shared gap already baselined for KitButton, KitConfirmSheet,
  // KitActionBlock and KitStateView (test/kit_motion_baseline.json). G8x's
  // own rule is that a part added after the gate is never added to that
  // baseline, so this unit does not add showKitUndo to it either; the gap
  // is recorded under NOT proven in the unit's QA record (PROC-20) for the
  // coordinator to fix at the shared `_Spinner`.
  kitMotionStillTests(
    'showKitUndo',
    builds: {'nothing pending': () => const SizedBox.shrink()},
    changes: {
      'shows, then commits and closes': KitMotionChange(
        build: () => const SizedBox.expand(),
        act: (tester, stage) async {
          showKitUndo(
            stage.context,
            message: 'Archived "Fix login"',
            onUndo: () {},
          );
          await tester.pump();
          KitUndo.commitPending();
        },
        hides: 'Archived "Fix login"',
      ),
    },
  );

  // Last on purpose: it loads the gallery's real faces (process-wide), so
  // the stacking rule is measured in the font the bar actually renders
  // with; with the test font every face measures alike and the rule's
  // choice of style would go unseen.
  group('stacking (A11Y-8) in the theme\'s own face', () {
    setUpAll(loadKitGalleryFonts);

    testWidgets('a short message and Undo share one row at 412 wide', (
      tester,
    ) async {
      final context = await _pumpUndoHost(tester, size: const Size(412, 915));
      showKitUndo(
        context,
        undoKey: const Key('the-undo-action'),
        message: 'Archived "Fix login"',
        onUndo: () {},
      );
      await tester.pumpAndSettle();
      final message = tester.getRect(find.text('Archived "Fix login"'));
      final undo = tester.getRect(find.byKey(const Key('the-undo-action')));
      expect(
        undo.top,
        lessThan(message.bottom),
        reason: 'Undo sits beside the message, not under it',
      );
      expect(undo.left, greaterThan(message.right));
      KitUndo.commitPending();
    });

    testWidgets('at text 2.0 the same bar stacks, and nothing overflows', (
      tester,
    ) async {
      final context = await _pumpUndoHost(
        tester,
        size: const Size(412, 915),
        textScale: 2,
      );
      showKitUndo(
        context,
        undoKey: const Key('the-undo-action'),
        message: 'Archived "Fix login"',
        onUndo: () {},
      );
      await tester.pumpAndSettle();
      final message = tester.getRect(find.text('Archived "Fix login"'));
      final undo = tester.getRect(find.byKey(const Key('the-undo-action')));
      expect(undo.top, greaterThanOrEqualTo(message.bottom));
      expect(tester.takeException(), isNull);
      KitUndo.commitPending();
    });
  });
}
