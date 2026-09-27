import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/screens/running_work_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/managed_shell_fakes.dart';

class _Conn extends ConnectionController {
  _Conn(super.store, this.transport);
  final ServerGateway? transport;
  @override
  Future<ServerGateway?> prepareActionTransport() async => transport;
}

class _AbortGateway implements ServerGateway {
  final aborted = <String>[];
  @override
  Future<void> abort(String sessionID) async => aborted.add(sessionID);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected ${invocation.memberName}');
}

class _RefusingRepository extends FakeManagedShellRepository {
  _RefusingRepository({this.refuseStop = false, this.refuseLimit = false});
  final bool refuseStop;
  final bool refuseLimit;
  @override
  Future<void> stopManagedShell(String id) async {
    if (refuseStop) throw const ProductException('The server refused.');
    return super.stopManagedShell(id);
  }

  @override
  Future<ManagedShell> setManagedShellTimeout(String id, Duration? timeout) {
    if (refuseLimit) throw const ProductException('The server refused.');
    return super.setManagedShellTimeout(id, timeout);
  }
}

Future<ConnectionController> connection(
  FakeManagedShellRepository repo, {
  ServerGateway? transport,
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'p1',
        'name': 'Test',
        'baseUrl': 'http://localhost',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'p1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return _Conn(store, transport)
    ..repository = repo
    ..status = StreamStatus.connected
    ..sessionsById = {'ses_a': Session(id: 'ses_a', title: 'Main task')};
}

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(scale),
          // A working row's mark spins otherwise, and never settles.
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

/// The sheet body as the sheet frame hosts it: scrolled by its host.
Widget sheet(RunningWorkSheet body) =>
    Scaffold(body: ListView(children: [body]));

/// A row's supporting line (a rich text span).
Finder line(String text) => find.textContaining(text, findRichText: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        ),
  );

  testWidgets('UXCHAT background eligibility updates while Tasks stays open', (
    tester,
  ) async {
    final repo = FakeManagedShellRepository()..shells = [];
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    final changed = ValueNotifier<int>(0);
    addTearDown(changed.dispose);
    var support = BackgroundWorkSupport.unavailable;
    var eligible = false;
    await pump(
      tester,
      sheet(
        RunningWorkSheet(
          controller: conn,
          sessionID: 'ses_a',
          availabilityChanges: changed,
          readBackgroundSupport: () => support,
          canBackground: () => eligible,
          onBackground: () async => BackgroundWorkResult.requested,
        ),
      ),
    );
    expect(find.text('Keep chatting while it runs'), findsNothing);
    support = BackgroundWorkSupport.subagents;
    eligible = true;
    changed.value++;
    await tester.pumpAndSettle();
    expect(find.text('Keep chatting while it runs'), findsOneWidget);
    // Only while it applies, one line says what moving the work frees
    // (map infoMissing).
    expect(
      find.textContaining('This conversation waits for the work above.'),
      findsOneWidget,
    );
    eligible = false;
    changed.value++;
    await tester.pumpAndSettle();
    expect(find.text('Keep chatting while it runs'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'UXCHAT child Tasks discovers uncached siblings and its own children',
    (tester) async {
      final repo = FakeManagedShellRepository()
        ..shells = []
        ..children = [
          Session(id: 'sibling', parentID: 'parent', title: 'Sibling task'),
          Session(id: 'grandchild', parentID: 'ses_a', title: 'Nested task'),
        ];
      final conn = await connection(repo)
        ..sessionsById = {
          'ses_a': Session(
            id: 'ses_a',
            parentID: 'parent',
            title: 'Current child',
          ),
        };
      addTearDown(conn.dispose);
      await pump(
        tester,
        sheet(RunningWorkSheet(controller: conn, sessionID: 'ses_a')),
      );
      expect(repo.childrenReads.toSet(), {'ses_a', 'parent'});
      expect(find.byKey(const Key('work-agent-sibling')), findsOneWidget);
      expect(find.byKey(const Key('work-agent-grandchild')), findsOneWidget);
      // Idle has its own word, not "Finished" (map statesMissing).
      expect(line('Agent · Idle'), findsNWidgets(2));
      expect(line('Finished'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('UXCHAT completed command remains accessible by known ID', (
    tester,
  ) async {
    final repo = FakeManagedShellRepository()
      ..shells = [sampleShell(status: ManagedShellStatus.exited)];
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    await pump(
      tester,
      sheet(
        RunningWorkSheet(
          controller: conn,
          sessionID: 'ses_a',
          shellIDs: const {'sh_a'},
        ),
      ),
    );
    expect(find.byKey(const Key('work-shell-sh_a')), findsOneWidget);
    // A clean exit reads as finished, not as a code to interpret.
    expect(line('Exit code 0'), findsNothing);
    expect(line('Command · Finished · '), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'UXCHAT Tasks opens on its list, with no preamble, at large text',
    (tester) async {
      final repo = FakeManagedShellRepository()..shells = [];
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      await pump(
        tester,
        sheet(RunningWorkSheet(controller: conn, sessionID: 'ses_a')),
        scale: 2.5,
      );
      expect(find.textContaining('has not confirmed support'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Nothing running'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nothing running'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'UXCHAT requested background promotion is not reported as confirmed',
    (tester) async {
      final repo = FakeManagedShellRepository()..shells = [];
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      var requests = 0;
      await pump(
        tester,
        sheet(
          RunningWorkSheet(
            controller: conn,
            sessionID: 'ses_a',
            backgroundSupport: BackgroundWorkSupport.subagentsAndShells,
            onBackground: () async {
              requests++;
              return BackgroundWorkResult.requested;
            },
          ),
        ),
      );
      await tester.tap(find.text('Keep chatting while it runs'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.textContaining('Background work requested.'), findsOneWidget);
      expect(
        find.text('Subagents are continuing in the background.'),
        findsNothing,
      );
      // The offer is replaced by the receipt; it cannot be asked twice.
      expect(find.text('Keep chatting while it runs'), findsNothing);
      await tester.tap(find.textContaining('Background work requested.'));
      await tester.pump();
      expect(requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a reconnect covered by a dialog reconciles when the viewer becomes visible',
    (tester) async {
      final repo = FakeManagedShellRepository();
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      await pump(
        tester,
        ShellOutputScreen(controller: conn, shell: repo.shells.first),
      );
      await tester.tap(find.byKey(const Key('shell-output-stop')));
      await tester.pumpAndSettle();
      final coveredReads = repo.outputReads;
      repo.identity = 'server-2';
      repo.shells = [];
      conn.dataRefreshRevision++;
      conn.notifyListeners();
      await tester.pump(const Duration(seconds: 2));
      expect(repo.outputReads, coveredReads);
      await tester.tap(find.text('Keep running'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('The server restarted'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'running work filters other sessions and opens a linked subagent',
    (tester) async {
      final repo = FakeManagedShellRepository()
        ..shells.add(
          sampleShell(
            id: 'sh_other',
            sessionID: 'ses_other',
            command: 'PRIVATE OTHER COMMAND',
          ),
        );
      final conn = await connection(repo)
        ..sessionsById['ses_child'] = Session(
          id: 'ses_child',
          title: 'Review navigation',
          parentID: 'ses_a',
        )
        ..busySessions = {'ses_child'};
      addTearDown(conn.dispose);
      String? selected;
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => selected = await showRunningWorkSheet(
                context,
                controller: conn,
                sessionID: 'ses_a',
                shellIDs: {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE OTHER COMMAND'), findsNothing);
      expect(find.byKey(const Key('work-shell-sh_a')), findsOneWidget);
      await tester.tap(find.byKey(const Key('work-agent-ses_child')));
      await tester.pumpAndSettle();
      expect(selected, 'ses_child');
    },
  );

  testWidgets(
    'unsupported shells disappear while subagent navigation stays available',
    (tester) async {
      final repo = FakeManagedShellRepository()..supported = false;
      final conn = await connection(repo)
        ..sessionsById['ses_child'] = Session(
          id: 'ses_child',
          title: 'Child',
          parentID: 'ses_a',
        )
        ..busySessions = {'ses_child'};
      addTearDown(conn.dispose);
      await pump(
        tester,
        sheet(RunningWorkSheet(controller: conn, sessionID: 'ses_a')),
      );
      expect(find.text('Commands'), findsNothing);
      expect(find.byKey(const Key('work-agent-ses_child')), findsOneWidget);
      final unsupportedReads = repo.listReads;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.listReads, unsupportedReads);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Stop requires confirmation and retains already loaded output', (
    tester,
  ) async {
    final repo = FakeManagedShellRepository();
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    await pump(
      tester,
      ShellOutputScreen(controller: conn, shell: repo.shells.first),
    );
    await tester.tap(find.byKey(const Key('shell-output-stop')));
    await tester.pumpAndSettle();
    expect(repo.stopCalls, 0);
    await tester.tap(find.text('Keep running'));
    await tester.pumpAndSettle();
    expect(repo.stopCalls, 0);
    await tester.tap(find.byKey(const Key('shell-output-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell-output-stop-confirm')));
    await tester.pumpAndSettle();
    expect(repo.stopCalls, 1);
    // The loaded output stays; the acts on a running command are gone.
    expect(find.textContaining('Draft restoration'), findsOneWidget);
    expect(find.byKey(const Key('shell-output-stop')), findsNothing);
    expect(find.byKey(const Key('shell-output-limit')), findsNothing);
    expect(
      tester.widget<KitText>(find.byKey(const Key('shell-output-status'))).text,
      'Stopped',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timeout replacement and clearing use the selected duration', (
    tester,
  ) async {
    final repo = FakeManagedShellRepository();
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    await pump(
      tester,
      ShellOutputScreen(controller: conn, shell: repo.shells.first),
    );
    await tester.tap(find.text('Change timeout'));
    await tester.pumpAndSettle();
    expect(find.text('Stop it after…'), findsOneWidget);
    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();
    // The limit set here is said on the page, with the time left.
    expect(find.textContaining('stops in'), findsOneWidget);
    await tester.tap(find.text('Change timeout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No timeout'));
    await tester.pumpAndSettle();
    expect(repo.timeouts, [const Duration(minutes: 5), null]);
    expect(find.textContaining('no time limit'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a command about to hit its time limit says so on its page', (
    tester,
  ) async {
    final repo = FakeManagedShellRepository();
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    await pump(
      tester,
      ShellOutputScreen(controller: conn, shell: repo.shells.first),
    );
    expect(find.byKey(const Key('shell-output-about-to-stop')), findsNothing);
    await tester.tap(find.text('Change timeout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 minute'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-output-about-to-stop')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a time limit the server refuses is said with Try again', (
    tester,
  ) async {
    final repo = _RefusingRepository(refuseLimit: true);
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    await pump(
      tester,
      ShellOutputScreen(controller: conn, shell: repo.shells.first),
    );
    await tester.tap(find.text('Change timeout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 minutes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-output-limit-failed')), findsOneWidget);
    expect(find.text("Couldn't change the time limit."), findsOneWidget);
    expect(find.textContaining('stops in'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a stop the server refuses keeps the question open', (
    tester,
  ) async {
    final repo = _RefusingRepository(refuseStop: true);
    final conn = await connection(repo);
    addTearDown(conn.dispose);
    await pump(
      tester,
      ShellOutputScreen(controller: conn, shell: repo.shells.first),
    );
    await tester.tap(find.byKey(const Key('shell-output-stop')));
    await tester.pumpAndSettle();
    // The safer path is offered before anything is removed.
    expect(find.text('Copy output first'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shell-output-stop-confirm')));
    await tester.pumpAndSettle();
    expect(repo.stopCalls, 0);
    expect(find.byKey(const Key('shell-output-stop-confirm')), findsOneWidget);
    await tester.tap(find.text('Keep running'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-output-stop')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a running agent is stopped from its row, asked first', (
    tester,
  ) async {
    final gateway = _AbortGateway();
    final repo = FakeManagedShellRepository()..shells = [];
    final conn = await connection(repo, transport: gateway)
      ..sessionsById['ses_child'] = Session(
        id: 'ses_child',
        title: 'Review navigation',
        parentID: 'ses_a',
      )
      ..busySessions = {'ses_child'};
    addTearDown(conn.dispose);
    await pump(
      tester,
      sheet(RunningWorkSheet(controller: conn, sessionID: 'ses_a')),
    );
    await tester.longPress(find.byKey(const Key('work-agent-ses_child')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop “Review navigation”'));
    await tester.pumpAndSettle();
    expect(find.text('Stop “Review navigation”?'), findsOneWidget);
    expect(gateway.aborted, isEmpty);
    await tester.tap(find.byKey(const Key('running-work-stop-agent-confirm')));
    await tester.pumpAndSettle();
    expect(gateway.aborted, ['ses_child']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'output polling pauses behind a dialog, in background and after close',
    (tester) async {
      final repo = FakeManagedShellRepository();
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      await pump(
        tester,
        ShellOutputScreen(controller: conn, shell: repo.shells.first),
      );
      final initial = repo.outputReads;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(repo.outputReads, greaterThan(initial));
      await tester.tap(find.byKey(const Key('shell-output-stop')));
      await tester.pumpAndSettle();
      final covered = repo.outputReads;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.outputReads, covered);
      await tester.tap(find.text('Keep running'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = repo.outputReads;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.outputReads, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.outputReads, greaterThan(paused));
      await tester.pumpWidget(const SizedBox.shrink());
      final closed = repo.outputReads;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.outputReads, closed);
    },
  );

  testWidgets(
    'reconnect refreshes status and scope change disables old-server controls',
    (tester) async {
      final repo = FakeManagedShellRepository();
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      await pump(
        tester,
        ShellOutputScreen(controller: conn, shell: repo.shells.first),
      );
      conn.status = StreamStatus.reconnecting;
      conn.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('Reconnecting.'), findsOneWidget);
      repo.identity = 'server-2';
      repo.shells = [];
      conn.status = StreamStatus.connected;
      conn.locationRevision++;
      conn.dataRefreshRevision++;
      conn.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('The server restarted'), findsOneWidget);
      expect(find.text('Running'), findsNothing);
      conn.directory = '/other';
      conn.locationRevision++;
      conn.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('project changed'), findsOneWidget);
      // Old-server controls are gone: no Stop, no time limit, and Refresh
      // waits in the overflow with its reason instead of in the bar.
      expect(find.byKey(const Key('shell-output-stop')), findsNothing);
      expect(find.byKey(const Key('shell-output-refresh')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'running work and output remain scrollable at 360 dp with 2.5x text',
    (tester) async {
      final repo = FakeManagedShellRepository()
        ..shells = [
          sampleShell(
            command:
                'flutter test --concurrency=1 test/a_very_long_file_name_test.dart',
          ),
        ];
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      await pump(
        tester,
        sheet(RunningWorkSheet(controller: conn, sessionID: 'ses_a')),
        scale: 2.5,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        ShellOutputScreen(controller: conn, shell: repo.shells.first),
        scale: 2.5,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('shell-output-content')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      expect(find.text('Change timeout'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Running now lists running work first, then the rest, by outcome',
    (tester) async {
      final started = DateTime.now().subtract(const Duration(minutes: 3));
      ManagedShell shell(
        String id,
        String command,
        ManagedShellStatus status, {
        int? exitCode,
      }) => ManagedShell(
        id: id,
        sessionID: 'ses_a',
        command: command,
        status: status,
        exitCode: exitCode,
        startedAt: started,
        completedAt: status == ManagedShellStatus.running
            ? null
            : started.add(const Duration(seconds: 30)),
      );
      final repo = FakeManagedShellRepository()
        ..shells = [
          shell(
            'sh_ok',
            'flutter analyze',
            ManagedShellStatus.exited,
            exitCode: 0,
          ),
          shell('sh_live', 'uvicorn main:app', ManagedShellStatus.running),
          shell(
            'sh_bad',
            'flutter test',
            ManagedShellStatus.exited,
            exitCode: 1,
          ),
          shell(
            'sh_term',
            'uvicorn old',
            ManagedShellStatus.exited,
            exitCode: 143,
          ),
        ];
      final conn = await connection(repo);
      addTearDown(conn.dispose);
      await pump(
        tester,
        sheet(
          RunningWorkSheet(
            controller: conn,
            sessionID: 'ses_a',
            shellIDs: const {'sh_ok', 'sh_live', 'sh_bad', 'sh_term'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Running first, whatever order the server listed them in.
      final live = tester.getTopLeft(
        find.byKey(const Key('work-shell-sh_live')),
      );
      for (final id in ['sh_ok', 'sh_bad', 'sh_term']) {
        expect(
          live.dy,
          lessThan(tester.getTopLeft(find.byKey(Key('work-shell-$id'))).dy),
        );
      }
      // Finished work, newest first, in one list: no state sections.
      expect(find.text('Running'), findsNothing);
      expect(find.text('Finished'), findsNothing);
      // Outcomes in words a person uses: a clean exit finished, a non-zero
      // exit failed, a terminated server was stopped rather than "failed".
      expect(line('Command · Running · '), findsOneWidget);
      expect(line('Command · Failed · 0:30'), findsOneWidget);
      expect(line('Command · Stopped · 0:30'), findsOneWidget);
      expect(line('Command · Finished · 0:30'), findsOneWidget);
      expect(line('Exit code'), findsNothing);
    },
  );

  test('a command is named by what it runs, not where it lives', () {
    expect(
      shortCommand(
        '/tmp/opencode/flutter/bin/flutter analyze && '
        '/tmp/opencode/flutter/bin/flutter test --concurrency=1',
      ),
      'flutter analyze && flutter test --concurrency=1',
    );
    expect(
      shortCommand(
        'FINANCEHUB_DB=/tmp/opencode/demo.db ./.venv/bin/uvicorn main:app '
        '--host 0.0.0.0',
      ),
      'uvicorn main:app --host 0.0.0.0',
    );
    expect(shortCommand('ls -la | grep foo'), 'ls -la | grep foo');
    // Arguments that are paths are left alone.
    expect(shortCommand('cat /etc/hosts'), 'cat /etc/hosts');
    expect(shortCommand('FOO=1'), 'FOO=1');
  });
}
