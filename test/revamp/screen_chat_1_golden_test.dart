// Golden renders of screen-chat-1's pages (wave 2b), rebuilt from kit parts:
// Running now (running-work-sheet), a command's output (shell-output) with
// its time limit sheet and stop question, the conversation context
// (session-context), the move sheet and its question
// (session-destination-sheet, session-destination-confirm-dialog), the
// organization sheet and its question (console-organization-*) and the
// offline demo (demo). One render per state at the phone size (412x915) and
// the loaded states at one wide window (1280x800), dark and light (owner
// decision 2026-09-27: no Arabic), real fonts at DPR 1, on a fixed clock.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_chat_1_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';
import 'package:opencode_mobile/ui/screens/demo_screen.dart';
import 'package:opencode_mobile/ui/screens/running_work_sheet.dart';
import 'package:opencode_mobile/ui/screens/session_context_screen.dart';
import 'package:opencode_mobile/ui/screens/session_destination_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/complete_message_history.dart';
import '../support/managed_shell_fakes.dart';
import 'screen_chat_1_support.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
final _now = DateTime(2026, 9, 27, 10, 30);

String _name(String state, Size size, bool light) => [
  state,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

/// Renders [home] (a page, or an opener whose button [act] taps), settles
/// and compares the whole window, all on a fixed clock.
Future<void> _shot(
  WidgetTester tester,
  String state,
  Widget home, {
  required bool light,
  Size size = _phone,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(
        chatOneApp(home, light: light, boundary: boundary),
      );
      await tester.pumpAndSettle();
      if (act != null) await act(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/${_name(state, size, light)}.png'),
      );
    });
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// --- Running now and a command's output ----------------------------------

ManagedShell _shell(
  String id,
  String command,
  ManagedShellStatus status, {
  int? exitCode,
  int minutesAgo = 3,
  int seconds = 30,
}) {
  final started = _now.subtract(Duration(minutes: minutesAgo));
  return ManagedShell(
    id: id,
    sessionID: 'ses_a',
    command: command,
    status: status,
    exitCode: exitCode,
    directory: '/work/acme',
    startedAt: started,
    completedAt: status == ManagedShellStatus.running
        ? null
        : started.add(Duration(seconds: seconds)),
  );
}

FakeManagedShellRepository _shellRepo({bool empty = false}) =>
    FakeManagedShellRepository()
      ..output =
          '00:02 +12: Checkout applies the coupon before the total settles\n'
          '00:03 +13: Checkout shows the refreshed price\n'
          '00:03 +13 -1: Checkout retries a declined card [E]\n'
          '  Expected: "Paid"\n'
          '    Actual: "Declined"\n'
          '00:05 +24 -1: Some tests failed.\n'
          'Running navigation tests…\n'
      ..shells = empty
          ? []
          : [
              _shell(
                'sh_live',
                'CI=1 /home/sam/flutter/bin/flutter test --concurrency=1',
                ManagedShellStatus.running,
                minutesAgo: 2,
              ),
              _shell(
                'sh_bad',
                'dart analyze lib',
                ManagedShellStatus.exited,
                exitCode: 1,
                minutesAgo: 9,
                seconds: 42,
              ),
              _shell(
                'sh_ok',
                './tool/build_web.sh && cp -r build/web /tmp/site',
                ManagedShellStatus.exited,
                exitCode: 0,
                minutesAgo: 14,
                seconds: 71,
              ),
            ];

Future<ConnectionController> _shellConnection(
  FakeManagedShellRepository repo,
) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'p1',
        'name': 'Laptop',
        'baseUrl': 'http://localhost',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'p1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final conn = ConnectionController(store)
    ..repository = repo
    ..status = StreamStatus.connected
    ..sessionsById = {
      'ses_a': Session(id: 'ses_a', title: 'Fix flaky checkout test'),
      'ses_review': Session(
        id: 'ses_review',
        title: 'Review the checkout diff',
        parentID: 'ses_a',
      ),
      'ses_docs': Session(
        id: 'ses_docs',
        title: 'Update the testing notes',
        parentID: 'ses_a',
      ),
    }
    ..busySessions = {'ses_review'};
  addTearDown(conn.dispose);
  return conn;
}

// --- Conversation context --------------------------------------------------

class _ContextApi extends OpenCodeApi with CompleteMessageHistory {
  _ContextApi(this.result) : super(baseUrl: 'http://localhost');
  final List<MessageWithParts> result;
  @override
  Future<List<MessageWithParts>> messages(String id) async => List.of(result);
}

class _ContextConnection extends ConnectionController {
  _ContextConnection(super.store, this.actionApi) {
    api = actionApi;
    status = StreamStatus.connected;
  }
  final _ContextApi actionApi;
  @override
  Future<OpenCodeApi?> prepareActionTransport() async => actionApi;
}

MessageWithParts _message(
  String id,
  String role,
  List<Part> parts, {
  Tokens? tokens,
  double cost = 0,
}) => MessageWithParts(
  info: MessageInfo(
    id: id,
    sessionID: 'ses_a',
    role: role,
    providerID: role == 'assistant' ? 'anthropic' : null,
    modelID: role == 'assistant' ? 'claude-sonnet-4' : null,
    tokens: tokens,
    cost: cost,
    time: MsgTime(created: 1, completed: 2),
  ),
  parts: parts,
);

List<MessageWithParts> _history(int input) => [
  _message('m1', 'user', [
    Part(type: 'text', text: List.filled(40000, 'u').join()),
  ]),
  _message(
    'm2',
    'assistant',
    [
      Part(type: 'text', text: List.filled(120000, 'a').join()),
      Part(
        type: 'tool',
        toolName: 'bash',
        toolState: ToolState(
          status: 'completed',
          inputJson: List.filled(40000, 'i').join(),
          output: List.filled(200000, 'o').join(),
        ),
      ),
    ],
    tokens: Tokens(
      input: input,
      output: 1840,
      reasoning: 420,
      cacheRead: 12800,
      cacheWrite: 900,
    ),
    cost: .4182,
  ),
];

Future<_ContextConnection> _contextConnection(int input) async {
  SharedPreferences.setMockInitialValues({});
  final conn = _ContextConnection(
    ProfileStore(prefs: await SharedPreferences.getInstance()),
    _ContextApi(_history(input)),
  );
  conn.catalog = const CatalogSnapshot(
    providers: [],
    models: [
      CatalogModel(
        id: 'claude-sonnet-4',
        providerID: 'anthropic',
        name: 'Claude Sonnet 4',
        enabled: true,
        status: 'active',
        contextLimit: 200000,
        outputLimit: 64000,
        reasoning: true,
        attachments: true,
        tools: true,
        variants: [],
      ),
    ],
    agents: [],
  );
  conn.selectedModel = ModelRef(
    providerID: 'anthropic',
    modelID: 'claude-sonnet-4',
  );
  addTearDown(conn.dispose);
  return conn;
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('running now, loaded ($theme, $size)', (tester) async {
        final conn = await _shellConnection(_shellRepo());
        await _shot(
          tester,
          'chat_running_work_sheet_loaded',
          opener(
            (context) => showRunningWorkSheet(
              context,
              controller: conn,
              sessionID: 'ses_a',
              shellIDs: const {'sh_live', 'sh_bad', 'sh_ok'},
              onBackground: () async => BackgroundWorkResult.requested,
              canBackground: () => true,
            ),
          ),
          light: light,
          size: size,
          act: _open,
        );
      });

      testWidgets('command output, running ($theme, $size)', (tester) async {
        final repo = _shellRepo();
        final conn = await _shellConnection(repo);
        await _shot(
          tester,
          'terminal_shell_output_running',
          opener(
            (context) => pushKitPage<void>(
              context,
              (_) =>
                  ShellOutputScreen(controller: conn, shell: repo.shells.first),
            ),
          ),
          light: light,
          size: size,
          act: _open,
        );
      });

      testWidgets('context, loaded ($theme, $size)', (tester) async {
        final conn = await _contextConnection(38200);
        await _shot(
          tester,
          'chat_session_context_loaded',
          opener(
            (context) => pushKitPage<void>(
              context,
              (_) => SessionContextScreen(
                controller: conn,
                sessionID: 'ses_a',
                initialMessages: _history(38200),
              ),
            ),
          ),
          light: light,
          size: size,
          act: _open,
        );
      });

      testWidgets('move sheet ($theme, $size)', (tester) async {
        final conn = await chatOneConnection();
        await _shot(
          tester,
          'chat_session_destination_sheet_move',
          opener(
            (context) => showSessionDestinationSheet(
              context,
              controller: conn,
              sessionID: 'ses_a',
              mode: SessionDestinationMode.move,
            ),
          ),
          light: light,
          size: size,
          act: _open,
        );
      });
    }

    testWidgets('running now, empty ($theme)', (tester) async {
      final conn = await _shellConnection(_shellRepo(empty: true))
        ..sessionsById = {
          'ses_a': Session(id: 'ses_a', title: 'Fix flaky checkout test'),
        }
        ..busySessions = {};
      await _shot(
        tester,
        'chat_running_work_sheet_empty',
        opener(
          (context) => showRunningWorkSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            shellIDs: const {},
          ),
        ),
        light: light,
        act: _open,
      );
    });

    testWidgets('command output, time limit sheet ($theme)', (tester) async {
      final repo = _shellRepo();
      final conn = await _shellConnection(repo);
      await _shot(
        tester,
        'terminal_shell_output_timeout_sheet',
        opener(
          (context) => pushKitPage<void>(
            context,
            (_) =>
                ShellOutputScreen(controller: conn, shell: repo.shells.first),
          ),
        ),
        light: light,
        act: (tester) async {
          await _open(tester);
          await _tap(tester, find.byKey(const Key('shell-output-limit')));
          await _tap(tester, find.text('15 minutes'));
          // Reopened: the limit set here is the marked one.
          await _tap(tester, find.byKey(const Key('shell-output-limit')));
        },
      );
    });

    testWidgets('command output, stop question ($theme)', (tester) async {
      final repo = _shellRepo();
      final conn = await _shellConnection(repo);
      await _shot(
        tester,
        'terminal_shell_output_stop_dialog',
        opener(
          (context) => pushKitPage<void>(
            context,
            (_) =>
                ShellOutputScreen(controller: conn, shell: repo.shells.first),
          ),
        ),
        light: light,
        act: (tester) async {
          await _open(tester);
          await _tap(tester, find.byKey(const Key('shell-output-stop')));
        },
      );
    });

    testWidgets('context, near the limit ($theme)', (tester) async {
      final conn = await _contextConnection(158000);
      await _shot(
        tester,
        'chat_session_context_near_limit',
        opener(
          (context) => pushKitPage<void>(
            context,
            (_) => SessionContextScreen(
              controller: conn,
              sessionID: 'ses_a',
              initialMessages: _history(158000),
            ),
          ),
        ),
        light: light,
        act: _open,
      );
    });

    testWidgets('move question with changes ($theme)', (tester) async {
      final conn = await chatOneConnection();
      await _shot(
        tester,
        'chat_session_destination_confirm_dialog_with_changes',
        opener(
          (context) => showSessionDestinationSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            mode: SessionDestinationMode.move,
          ),
        ),
        light: light,
        act: (tester) async {
          await _open(tester);
          await _tap(
            tester,
            find.byKey(const Key('move-destination-/work/checkout-retry')),
          );
        },
      );
    });

    testWidgets('cloud move sheet ($theme)', (tester) async {
      final conn = await chatOneConnection();
      await _shot(
        tester,
        'chat_session_destination_sheet_warp',
        opener(
          (context) => showSessionDestinationSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            mode: SessionDestinationMode.warp,
          ),
        ),
        light: light,
        act: _open,
      );
    });

    testWidgets('organization sheet ($theme)', (tester) async {
      final conn = await chatOneConnection();
      await _shot(
        tester,
        'settings_console_organization_sheet_loaded',
        opener(
          (context) => showConsoleOrganizationSheet(context, controller: conn),
        ),
        light: light,
        act: _open,
      );
    });

    testWidgets('organization question ($theme)', (tester) async {
      final conn = await chatOneConnection();
      await _shot(
        tester,
        'settings_console_organization_switch_dialog_confirming',
        opener(
          (context) => showConsoleOrganizationSheet(context, controller: conn),
        ),
        light: light,
        act: (tester) async {
          await _open(tester);
          await _tap(
            tester,
            find.byKey(const Key('console-org-acct-1-org-side')),
          );
        },
      );
    });

    testWidgets('demo, ready ($theme)', (tester) async {
      await _shot(
        tester,
        'chat_demo_ready',
        opener(
          (context) => pushKitPage<void>(context, (_) => const DemoScreen()),
        ),
        light: light,
        act: (tester) async {
          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        },
      );
    });

    // B12 (slice-polish2): a typed "/" gets one line saying the demo has no
    // commands, in the composer's suggestion area.
    testWidgets('demo, a typed slash ($theme)', (tester) async {
      await _shot(
        tester,
        'chat_demo_slash',
        opener(
          (context) => pushKitPage<void>(context, (_) => const DemoScreen()),
        ),
        light: light,
        act: (tester) async {
          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.enterText(
            find.byKey(const Key('chat-composer-field')),
            '/',
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        },
      );
    });
  }
}
