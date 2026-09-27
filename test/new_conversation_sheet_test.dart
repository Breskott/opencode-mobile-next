// New conversation's chooser (revamp unit slice-P4.5): the Work tab's one
// New conversation button asks Solo · Team · In a separate copy · On a
// cloud machine where the server supports each, remembers the answer per
// server, and every start ends in a conversation (or, for a team that is
// off, the team's off state). The separate copy is reached only from here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/screens/new_conversation_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_intro_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show CaptureApi, SeededProfileStore;
import 'support/work_tab_fixture.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Finder _key(String key) => find.byKey(ValueKey(key));

const _cloud = WorkspaceInfo(
  id: 'ws-1',
  projectID: 'p-fh3',
  name: 'cloud-1',
  type: 'remote',
  branch: 'feature-login',
  directory: '/cloud/FinanceHub3',
  status: 'Ready',
);

class _Repository extends WorkRepository {
  _Repository({this.workspaces = const []});

  final List<WorkspaceInfo> workspaces;

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => workspaces;
}

/// The Work tab's controller with a chosen capability set, and a location
/// switch that lands in the workspace it was asked for.
class _Work extends WorkController {
  _Work(super.store, this.caps);

  final ServerCapabilities caps;

  @override
  ServerCapabilities get capabilities => caps;

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    this.workspace = workspace;
    await super.selectLocation(directory: directory, workspace: workspace);
  }
}

Future<_Work> _controller({
  ServerCapabilities caps = const ServerCapabilities(),
  List<WorkspaceInfo> workspaces = const [],
  String baseUrl = 'http://100.100.1.2:4096',
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = SeededProfileStore(
    prefs: await SharedPreferences.getInstance(),
    seeded: [ServerProfile(id: 'phone', name: 'pop-os', baseUrl: baseUrl)],
  );
  await store.setLocation('phone', directory: workCurrent);
  final controller = _Work(store, caps)
    ..api = CaptureApi()
    ..repository = _Repository(workspaces: workspaces)
    ..directory = workCurrent
    ..sessionsById = {}
    ..busySessions = {};
  addTearDown(controller.dispose);
  return controller;
}

int _created(_Work controller) =>
    (controller.api! as CaptureApi).createdSessions;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpWork(WidgetTester tester, _Work controller) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('opened ${settings.name}')),
      ),
      home: Scaffold(body: WorkspaceScreen(controller: controller)),
    ),
  );
  await _settle(tester);
}

Future<void> _openChooser(WidgetTester tester) async {
  await tester.tap(_key('workspace-new'));
  await _settle(tester);
  expect(_key('new-conversation-sheet'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() => debugPlatformCapabilities = null);

  group('the remembered choice', () {
    test('round-trips every way, reads the old Solo · Team values, and is '
        'swept with the server', () async {
      for (final choice in const [
        NewConversationChoice.solo(),
        NewConversationChoice.team(),
        NewConversationChoice.separateCopy(),
        NewConversationChoice.cloud('ws-1'),
      ]) {
        expect(NewConversationChoice.parse(choice.stored), choice);
      }
      expect(NewConversationChoice.parse('cloud:'), isNull);
      expect(NewConversationChoice.parse('other'), isNull);

      SharedPreferences.setMockInitialValues({
        'oc.newConversationMode.phone': 'team',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        NewConversationMemory.read(prefs, 'phone'),
        const NewConversationChoice.team(),
      );
      await NewConversationMemory.remember(
        prefs,
        'phone',
        const NewConversationChoice.cloud('ws-1'),
      );
      expect(prefs.getString('oc.newConversationMode.phone'), 'cloud:ws-1');
      final store = SeededProfileStore(prefs: prefs, seeded: const []);
      expect(
        store.profileScopedPreferenceKeys('phone'),
        contains(NewConversationMemory.key('phone')),
      );
    });

    test('only Solo skips the chooser', () {
      expect(const NewConversationOptions(project: 'shop').onlySolo, isTrue);
      expect(
        const NewConversationOptions(separateCopy: true).onlySolo,
        isTrue,
        reason: 'no project, no copy',
      );
      expect(const NewConversationOptions(team: true).onlySolo, isFalse);
      expect(
        const NewConversationOptions(
          clouds: [NewConversationCloud(id: 'a', name: 'a')],
        ).onlySolo,
        isFalse,
      );
    });
  });

  group('on the Work tab', () {
    testWidgets('one New conversation: no Solo · Team switch beside it and '
        'no separate-copy row on the project sheet', (tester) async {
      final controller = await _controller(workspaces: const [_cloud]);
      await _pumpWork(tester, controller);
      expect(_key('workspace-new'), findsOneWidget);
      expect(find.text(_en.workspaceNewSession), findsOneWidget);
      expect(_key('workspace-new-mode'), findsNothing);
      expect(find.text(_en.teamNewTask), findsNothing);

      await tester.tap(_key('current-project-entry'));
      await _settle(tester);
      expect(_key('workspace-context-sheet'), findsOneWidget);
      expect(_key('workspace-isolated-task'), findsNothing);
      expect(find.textContaining('fresh worktree'), findsNothing);
    });

    testWidgets('the chooser names each way and where it starts, and Solo '
        'opens the new conversation and is remembered', (tester) async {
      final controller = await _controller(workspaces: const [_cloud]);
      await _pumpWork(tester, controller);
      await _openChooser(tester);

      expect(find.text(_en.teamNewModeSolo), findsOneWidget);
      expect(
        find.text(_en.newConversationSoloDetailIn(KitBidi.auto('FinanceHub3'))),
        findsOneWidget,
      );
      expect(find.text(_en.teamNewModeTeam), findsOneWidget);
      expect(find.text(_en.newConversationTeamOffDetail), findsOneWidget);
      expect(
        find.text(_en.newConversationCopyTitle(KitBidi.auto('FinanceHub3'))),
        findsOneWidget,
      );
      expect(
        find.text(_en.newConversationCloudTitle(KitBidi.auto('feature-login'))),
        findsOneWidget,
      );
      expect(find.textContaining(_en.newConversationLastUsed), findsNothing);

      await tester.tap(_key('new-conversation-solo'));
      await _settle(tester);
      expect(_created(controller), 1);
      expect(find.text('opened /chat/ses_new_1'), findsOneWidget);
      expect(
        controller.store.prefs.getString(NewConversationMemory.key('phone')),
        'solo',
      );

      // Back on Work, the chooser marks the remembered way.
      Navigator.of(tester.element(find.text('opened /chat/ses_new_1'))).pop();
      await _settle(tester);
      await _openChooser(tester);
      expect(
        find.descendant(
          of: _key('new-conversation-solo'),
          matching: find.textContaining(_en.newConversationLastUsed),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('new-conversation-team'),
          matching: find.textContaining(_en.newConversationLastUsed),
        ),
        findsNothing,
      );
    });

    testWidgets('Team with the team off opens its off state and is '
        'remembered for this server', (tester) async {
      final controller = await _controller();
      await _pumpWork(tester, controller);
      await _openChooser(tester);
      await tester.tap(_key('new-conversation-team'));
      await _settle(tester);
      expect(find.byType(TeamIntroScreen), findsOneWidget);
      expect(_created(controller), 0);
      expect(
        NewConversationMemory.read(controller.store.prefs, 'phone'),
        const NewConversationChoice.team(),
      );
    });

    testWidgets('In a separate copy opens the isolated-task sheet for the '
        'project', (tester) async {
      final controller = await _controller();
      await _pumpWork(tester, controller);
      await _openChooser(tester);
      await tester.tap(_key('new-conversation-copy'));
      await _settle(tester);
      expect(_key('new-conversation-sheet'), findsNothing);
      expect(find.text(_en.isolatedTaskTitle), findsOneWidget);
      expect(find.text('FinanceHub3'), findsWidgets);
      expect(
        NewConversationMemory.read(controller.store.prefs, 'phone'),
        const NewConversationChoice.separateCopy(),
      );
    });

    testWidgets('On a cloud machine moves there and opens the conversation '
        'there', (tester) async {
      final controller = await _controller(workspaces: const [_cloud]);
      await _pumpWork(tester, controller);
      await _openChooser(tester);
      await tester.tap(_key('new-conversation-cloud-ws-1'));
      await _settle(tester);
      expect(controller.workspace, 'ws-1');
      expect(controller.selected.last, '/cloud/FinanceHub3');
      expect(_created(controller), 1);
      expect(find.text('opened /chat/ses_new_1'), findsOneWidget);
      expect(
        controller.store.prefs.getString(NewConversationMemory.key('phone')),
        'cloud:ws-1',
      );
    });

    testWidgets('a server without worktrees or cloud machines offers only '
        'what it supports', (tester) async {
      final controller = await _controller(
        caps: const ServerCapabilities(worktreeCreate: false),
      );
      await _pumpWork(tester, controller);
      await _openChooser(tester);
      expect(_key('new-conversation-solo'), findsOneWidget);
      expect(_key('new-conversation-team'), findsOneWidget);
      expect(_key('new-conversation-copy'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'new-conversation-cloud',
              ),
        ),
        findsNothing,
      );
    });

    testWidgets('where Solo is the only way, New conversation starts it '
        'without asking', (tester) async {
      // A Termux phone that cannot run a team, and no worktrees.
      debugPlatformCapabilities = const PlatformCapabilities.android();
      final controller = await _controller(
        caps: const ServerCapabilities(worktreeCreate: false),
        baseUrl: 'http://127.0.0.1:4096',
      );
      await _pumpWork(tester, controller);
      await tester.tap(_key('workspace-new'));
      await _settle(tester);
      expect(_key('new-conversation-sheet'), findsNothing);
      expect(_created(controller), 1);
      expect(find.text('opened /chat/ses_new_1'), findsOneWidget);
    });
  });
}
