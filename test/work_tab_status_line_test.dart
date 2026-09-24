// The Work tab's new parts (work-tab cleanup and design standard,
// 2026-09-24): the one status line and its priorities, the leftover-process
// line's wording and dismissal, the kit's loading bar, skeletons and button
// block. Old-code comparisons are in work_tab_cleanup_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/termux/processes.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/termux_phone_tools.dart';
import 'package:opencode_mobile/ui/widgets/work_status_line.dart';

import 'support/work_tab_fixture.dart';

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

TermuxProcess _orphan({
  int pid = 4242,
  String name = '/root/projects/',
  String cwd = '/root/projects/',
  int cpuSeconds = 610,
}) => TermuxProcess(
  pid: pid,
  ppid: 1,
  group: TermuxProcessGroup.orphans,
  name: name,
  cmd: 'node $name',
  cpuPct: 12,
  cpuSeconds: cpuSeconds,
  rssKb: 1000,
  elapsedSeconds: 3600,
  cwd: cwd,
  orphanReason: TermuxOrphanReason.cpuNoOwner,
  protected: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    WorkspaceScreen.debugRunawayWatcher = null;
    TermuxRunawayWatcher.resetDismissedForTesting();
  });

  group('the leftover-process line (item 7)', () {
    test('names a project by its folder, and never shows a path', () {
      expect(runawayProjectName('/root/projects/'), isNull);
      expect(runawayProjectName('/root/projects'), isNull);
      expect(runawayProjectName('/root'), isNull);
      expect(runawayProjectName(''), isNull);
      expect(runawayProjectName('/root/projects/.cache/x'), isNull);
      expect(runawayProjectName('/root/projects/FinanceHub'), 'FinanceHub');
      expect(
        runawayProjectName('/root/projects/FinanceHub/node_modules/.bin'),
        'FinanceHub',
      );
      expect(
        runawayProjectName('/data/data/com.termux/files/home/projects/app'),
        'app',
      );
    });

    testWidgets('the phone case reads "OpenCode has been busy", with See '
        "what's running, and its dismissal lasts until the process "
        'changes', (tester) async {
      var report = TermuxProcessReport([_orphan()]);
      var scans = 0;
      await tester.pumpWidget(
        _app(
          TermuxRunawayWatcher(
            interval: const Duration(seconds: 60),
            scan: () async {
              scans++;
              return report;
            },
            builder: (context, notice) => Column(
              children: [
                if (notice != null)
                  KitStatusLine(
                    icon: Icons.memory,
                    message: notice
                        .status(lookupAppLocalizations(const Locale('en')))
                        .message,
                    onDismiss: notice.onDismiss,
                  ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.text('OpenCode has been busy for 10 min with nothing to do'),
        findsOneWidget,
      );
      expect(find.textContaining('/root'), findsNothing);
      expect(find.textContaining('CPU'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('kit-status-dismiss')));
      await _settle(tester);
      expect(find.byType(KitStatusLine), findsNothing);

      // The same process, scanned again: still dismissed.
      await tester.pump(const Duration(seconds: 61));
      await _settle(tester);
      expect(scans, greaterThan(1));
      expect(find.byType(KitStatusLine), findsNothing);

      // A different process: back, named by its project.
      report = TermuxProcessReport([
        _orphan(pid: 5151, cwd: '/root/projects/FinanceHub', cpuSeconds: 720),
      ]);
      await tester.pump(const Duration(seconds: 61));
      await _settle(tester);
      expect(
        find.text(
          'OpenCode has been busy in FinanceHub for 12 min with nothing to do',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('one status line, most urgent first', () {
    Future<WorkController> pumpWork(
      WidgetTester tester, {
      StreamStatus status = StreamStatus.connected,
      String? error,
      bool runaway = false,
      bool phone = true,
      Future<void> Function()? restart,
    }) async {
      final controller =
          await workController(
              status: status,
              sessions: workLoadedSessions(),
              name: phone ? 'This device (Termux)' : 'Laptop',
              baseUrl: phone
                  ? 'http://127.0.0.1:4096'
                  : 'http://100.64.0.7:4096',
            )
            ..lastError = error;
      if (runaway) {
        WorkspaceScreen.debugRunawayWatcher = (context, builder) => builder(
          context,
          WorkRunawayNotice(
            identity: 1,
            busyFor: '10 min',
            onOpen: () {},
            onDismiss: () {},
          ),
        );
      }
      await tester.pumpWidget(
        _app(
          WorkspaceScreen(
            controller: controller,
            serverOnThisPhone: phone,
            onRestartServer: restart,
          ),
        ),
      );
      await _settle(tester);
      return controller;
    }

    Finder line(String id) => find.byKey(ValueKey('work-status-$id'));

    testWidgets('a normal start says nothing', (tester) async {
      final controller = await pumpWork(
        tester,
        status: StreamStatus.connecting,
      );
      await tester.pump(const Duration(seconds: 7));
      expect(find.byType(KitStatusLine), findsNothing);
      controller
        ..status = StreamStatus.connected
        ..notifyListeners();
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(KitStatusLine), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('a server that stopped answering outranks a leftover '
        'process; the process shows again once it answers', (tester) async {
      final controller = await pumpWork(
        tester,
        status: StreamStatus.reconnecting,
        runaway: true,
      );
      // During the grace time the lower line still shows.
      expect(line('runaway'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await _settle(tester);
      expect(line('server'), findsOneWidget);
      expect(line('runaway'), findsNothing);
      controller
        ..status = StreamStatus.connected
        ..notifyListeners();
      await _settle(tester);
      expect(line('runaway'), findsOneWidget);
      expect(find.byType(KitStatusLine), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('a failed attempt says so at once', (tester) async {
      final controller = await pumpWork(
        tester,
        status: StreamStatus.disconnected,
        error: 'Cannot reach http://127.0.0.1:4096: timed out',
      );
      expect(line('server'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Restart asks first, and only then restarts', (tester) async {
      var restarts = 0;
      final controller = await pumpWork(
        tester,
        status: StreamStatus.reconnecting,
        restart: () async => restarts++,
      );
      await tester.pump(const Duration(seconds: 9));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('work-status-restart')));
      await _settle(tester);
      expect(find.text('Restart OpenCode on this phone?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(restarts, 0);
      await tester.tap(find.byKey(const ValueKey('work-status-restart')));
      await _settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('work-server-restart-confirm')),
      );
      await _settle(tester);
      expect(restarts, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('a remote server is named, with Try again and Details and '
        'no Restart', (tester) async {
      final controller = await pumpWork(
        tester,
        status: StreamStatus.reconnecting,
        phone: false,
      );
      await tester.pump(const Duration(seconds: 9));
      await _settle(tester);
      expect(find.text("Laptop isn't answering"), findsOneWidget);
      expect(find.byKey(const ValueKey('work-status-retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('work-status-restart')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kit-status-more')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('work-status-details')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('requests that could not be refreshed: "may be out of date" '
        'with Refresh, only while connected', (tester) async {
      final controller = await pumpWork(tester);
      expect(find.byType(KitStatusLine), findsNothing);
      controller
        ..permissionsError = 'timed out'
        ..notifyListeners();
      await _settle(tester);
      expect(line('stale'), findsOneWidget);
      expect(find.text('This may be out of date'), findsOneWidget);
      expect(find.text('Last observed state.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('the line is one live region', (tester) async {
      final controller = await pumpWork(tester, runaway: true);
      final live = find.descendant(
        of: line('runaway'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      );
      expect(live, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  group('kit', () {
    testWidgets('the loading bar is labelled; skeleton rows are not read', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              KitLoadingBar(loading: true, label: 'Loading'),
              KitSkeletonRows(),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('kit-skeleton-rows')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      semantics.dispose();
    });

    testWidgets('the loading bar keeps its 2 dp when idle', (tester) async {
      await tester.pumpWidget(
        _app(const KitLoadingBar(loading: false, label: 'Loading')),
      );
      expect(tester.getSize(find.byType(KitLoadingBar)).height, 2);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    for (final (width, stacked) in [(412.0, true), (800.0, false)]) {
      testWidgets('actions at ${width.toInt()} dp: '
          '${stacked ? 'stacked, primary first' : 'one row, primary last'}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            KitActionBlock(
              primary: KitAction(label: 'Start', onPressed: () {}),
              secondary: KitAction(label: 'Try again', onPressed: () {}),
              tertiary: [
                KitAction(label: 'Change server', onPressed: () {}),
                KitAction(label: 'Setup', onPressed: () {}),
                KitAction(label: 'Help', onPressed: () {}),
              ],
            ),
          ),
        );
        final start = tester.getRect(find.text('Start'));
        final retry = tester.getRect(find.text('Try again'));
        final change = tester.getRect(find.text('Change server'));
        // The third tertiary action goes behind More.
        expect(find.text('Help'), findsNothing);
        expect(find.byKey(const ValueKey('kit-actions-more')), findsOneWidget);
        if (stacked) {
          expect(start.top, lessThan(retry.top));
          expect(retry.top, lessThan(change.top));
          expect(
            tester.getSize(find.widgetWithText(FilledButton, 'Start')).width,
            width,
          );
        } else {
          expect(start.left, greaterThan(retry.left));
          expect(retry.left, greaterThan(change.left));
        }
      });
    }
  });
}
