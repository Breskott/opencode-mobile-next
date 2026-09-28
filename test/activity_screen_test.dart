import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/navigation/chat_route.dart';
import 'package:opencode_mobile/ui/screens/activity_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  int unknownProfiles = 0;
  @override
  int get unknownAttentionProfileCount => unknownProfiles;
  @override
  bool get isConnected => status == StreamStatus.connected;

  int prepareCalls = 0;
  int refreshCalls = 0;
  final preparedRepositories = <ServerOperationsGateway?>[];
  String? answeredPermissionID;
  String? permissionReply;

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async {
    prepareCalls += 1;
    preparedRepositories.add(repository);
    return repository;
  }

  @override
  Future<void> refreshSessions() async {
    refreshCalls += 1;
  }

  @override
  Future<void> refreshPendingPermissions() async {}

  @override
  Future<void> refreshPendingQuestions() async {}

  @override
  Future<void> refreshPendingForms() async {}

  @override
  Future<void> answerPermission(
    String id,
    String reply, {
    String? message,
    PendingRequestIdentity? expectedRequest,
  }) async {
    answeredPermissionID = id;
    permissionReply = reply;
  }
}

Session _session(
  String id, {
  String? title,
  String? parentID,
  int updated = 0,
  int? idle,
}) => Session(
  id: id,
  title: title,
  parentID: parentID,
  directory: '/work/oc_app',
  time: SessionTime(created: updated - 10, updated: updated, idle: idle),
);

Future<_Controller> _controller({bool seed = true}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = _Controller(ProfileStore(prefs: preferences))
    ..repository = _Repository()
    ..status = StreamStatus.connected;
  if (seed) {
    final now = DateTime.now().millisecondsSinceEpoch;
    controller.sessionsById = {
      'ses_run': _session('ses_run', title: 'Build feature', updated: now),
      'ses_child': _session('ses_child', parentID: 'ses_run', updated: now),
      'ses_idle': _session(
        'ses_idle',
        title: 'Yesterday cleanup',
        updated: now - 60000,
      ),
    };
    controller.busySessions = {'ses_run'};
    controller.permissions = {
      'perm-1': PermissionRequest(
        id: 'perm-1',
        sessionID: 'ses_run',
        permission: 'edit',
        patterns: const ['lib/main.dart'],
      ),
    };
    controller.questions = {
      'q-1': const PendingQuestion(
        id: 'q-1',
        sessionID: 'ses_idle',
        prompts: [
          QuestionPrompt(
            title: 'Direction',
            question: 'Proceed?',
            multiple: false,
            custom: true,
            choices: [],
          ),
        ],
      ),
    };
  }
  return controller;
}

Widget _app(Widget home, {Map<String, WidgetBuilder> routes = const {}}) =>
    MaterialApp(home: home, routes: routes);

void main() {
  testWidgets('busy sessions without loaded metadata never show All clear', (
    tester,
  ) async {
    final controller = await _controller(seed: false)
      ..busySessions = {'outside-page'};
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('activity-running-outside-page')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('activity-all-clear')), findsNothing);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the inbox renders attention and running, never history', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pump();

    // One list, no headed state sections (owner rule R1): the rows' marks
    // and words carry the state.
    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('Running'), findsNothing);
    expect(find.byKey(const ValueKey('activity-list')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-running-ses_run')),
        matching: find.textContaining('Working', findRichText: true),
      ),
      findsOneWidget,
    );
    // Activity is a pure inbox: idle sessions belong to Workspace.
    expect(find.text('Recently completed'), findsNothing);
    // Permissions and questions are resolvable rows, not links.
    expect(find.text('Edit a file'), findsOneWidget);
    expect(find.text('Direction'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-running-ses_run')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-recent-ses_idle')),
      findsNothing,
    );
    // The running root shows its cached subagent count, in words.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-running-ses_run')),
        matching: find.textContaining('1 subagent', findRichText: true),
      ),
      findsOneWidget,
    );
    // Children never appear as their own rows.
    expect(
      find.byKey(const ValueKey('activity-recent-ses_child')),
      findsNothing,
    );
    // No duplicate finder link: Workspace already owns "Search all conversations".
    expect(find.byKey(const ValueKey('activity-all-sessions')), findsNothing);
  });

  // P4.2a: on a phone a request row lands on its card in the conversation
  // (the chat marks it), never on a sheet over this list.
  testWidgets('a permission row lands on its card in the conversation', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    Object? arguments;
    await tester.pumpWidget(
      _app(
        ActivityScreen(controller: controller),
        routes: {
          '/chat/ses_run': (context) {
            arguments = ModalRoute.of(context)!.settings.arguments;
            return const Text('run chat');
          },
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Edit a file'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('permission-sheet')), findsNothing);
    expect(find.text('run chat'), findsOneWidget);
    expect((arguments as ChatRouteArguments).landOnRequestID, 'perm-1');
    expect(controller.answeredPermissionID, isNull);
  });

  testWidgets('a question row lands on its card in the conversation', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    Object? arguments;
    await tester.pumpWidget(
      _app(
        ActivityScreen(controller: controller),
        routes: {
          '/chat/ses_idle': (context) {
            arguments = ModalRoute.of(context)!.settings.arguments;
            return const Text('idle chat');
          },
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Direction'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Send answers'), findsNothing);
    expect(find.text('idle chat'), findsOneWidget);
    expect((arguments as ChatRouteArguments).landOnRequestID, 'q-1');
  });

  testWidgets('session rows open the exact chat', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ActivityScreen(controller: controller),
        routes: {
          '/chat/ses_run': (_) =>
              Scaffold(appBar: AppBar(), body: const Text('run chat')),
          '/chat/ses_idle': (_) =>
              Scaffold(appBar: AppBar(), body: const Text('idle chat')),
        },
      ),
    );
    await tester.pump();

    // Bounded pumps throughout: the Running row's live spinner never settles.
    await tester.tap(find.byKey(const ValueKey('activity-running-ses_run')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('run chat'), findsOneWidget);
  });

  testWidgets('refresh reconciles the wake transport before querying', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pump();

    // Android wake replaced the repository; the refresh must resolve the
    // replacement before the session query runs.
    final replacement = _Repository();
    controller.repository = replacement;
    controller.notifyListeners();
    await tester.pump();

    // Bounded pumps: the Running row's live spinner never settles.
    // Pull to refresh is the page's one refresh (R4).
    expect(find.byTooltip('Refresh'), findsNothing);
    unawaited(tester.widget<KitRefresh>(find.byType(KitRefresh)).onRefresh());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.prepareCalls, 1);
    expect(controller.refreshCalls, 1);
    expect(controller.preparedRepositories.single, same(replacement));
  });

  testWidgets('an empty inbox reads as success', (tester) async {
    final controller = await _controller(seed: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-all-clear')), findsOneWidget);
    expect(find.text('All clear here'), findsOneWidget);
    expect(
      find.text(
        'Nothing needs you. Approvals and questions from running work '
        'appear here.',
      ),
      findsOneWidget,
    );
    expect(find.text('All conversations'), findsNothing);
  });

  testWidgets('running sessions omit empty attention bookkeeping', (
    tester,
  ) async {
    final controller = await _controller();
    controller.permissions = {};
    controller.questions = {};
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pump();

    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('Nothing needs attention'), findsNothing);
    expect(
      find.byKey(const ValueKey('activity-running-ses_run')),
      findsOneWidget,
    );
  });

  testWidgets('unknown saved-server status never becomes all clear', (
    tester,
  ) async {
    final controller = await _controller(seed: false)
      ..unknownProfiles = 2;
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-all-clear')), findsNothing);
    expect(find.text('Status incomplete'), findsOneWidget);
    // No saved-servers summary row with counts (R4).
    expect(find.textContaining('2 unknown'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(controller.refreshCalls, 1);
    expect(find.text('Status incomplete'), findsOneWidget);
  });

  testWidgets('disconnected empty state stays unknown', (tester) async {
    final controller = await _controller(seed: false)
      ..status = StreamStatus.disconnected;
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(
      find.text("Requests can't load while you're offline."),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('activity-all-clear')), findsNothing);
    // A pushed Inbox has no connection line above it: it keeps its retry.
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('in the shell, offline leaves Reconnect to the connection line', (
    tester,
  ) async {
    final controller = await _controller(seed: false)
      ..status = StreamStatus.disconnected;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Requests can't load while you're offline."),
      findsOneWidget,
    );
    expect(find.text('Status incomplete'), findsNothing);
    // R3: the banner holds the one "Reconnect to …"; no second Try again.
    expect(find.text('Try again'), findsNothing);
    expect(find.byKey(const ValueKey('activity-check-again')), findsNothing);
  });

  testWidgets('one list, most urgent first: needs you, working, finished', (
    tester,
  ) async {
    final controller = await _controller();
    final now = DateTime.now().millisecondsSinceEpoch;
    controller.sessionsById = {
      ...controller.sessionsById,
      'ses_old': _session(
        'ses_old',
        title: 'Older finished',
        updated: now - 7200000,
        idle: now - 7200000,
      ),
      'ses_new': _session(
        'ses_new',
        title: 'Newer finished',
        updated: now - 60000,
        idle: now - 60000,
      ),
    };
    controller.directory = '/work/oc_app';
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pump();

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final permission = find.text('Edit a file');
    final running = find.byKey(const ValueKey('activity-running-ses_run'));
    final newer = find.byKey(const ValueKey('activity-digest-ses_new'));
    final older = find.byKey(const ValueKey('activity-digest-ses_old'));
    await tester.ensureVisible(older);
    await tester.pump();
    expect(top(permission), lessThan(top(running)));
    expect(top(running), lessThan(top(newer)));
    expect(top(newer), lessThan(top(older)));
    // Every row in the one panel, each saying its state in words.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-list')),
        matching: find.textContaining('Needs you', findRichText: true),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: newer,
        matching: find.textContaining('Finished', findRichText: true),
      ),
      findsOneWidget,
    );
    // No section headers, no settings rows, no folded digest header (R1, R4).
    for (final gone in [
      'Needs attention',
      'Running',
      'Finished while you were away',
      'Saved servers',
      'Background updates',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('failed pending check never shows all clear', (tester) async {
    final controller = await _controller(seed: false)
      ..permissionsError = 'Could not check permissions';
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pump();
    expect(find.text('Could not check permissions'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-all-clear')), findsNothing);
  });

  testWidgets('unsupported stale forms do not block the current inbox', (
    tester,
  ) async {
    final controller = await _controller(seed: false)
      ..formsError = 'Old form error'
      ..formsLoading = true;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('activity-all-clear')), findsOneWidget);
    expect(find.text('Old form error'), findsNothing);
  });

  testWidgets('activity fits a 320dp phone at 2x text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ActivityScreen(controller: controller),
      ),
    );
    await tester.pump();

    final running = find.byKey(const ValueKey('activity-running-ses_run'));
    for (
      var attempt = 0;
      attempt < 20 && running.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pump();
    }
    expect(running.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
