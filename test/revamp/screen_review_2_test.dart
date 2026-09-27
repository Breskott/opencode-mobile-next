// Behaviour of screen-review-2's Run results page (map run-result), rebuilt
// from kit parts: the still-running notice, the pinned "Review changed
// files", and errors that say why without echoing raw text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/run_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RunRepository implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RunGateway implements ServerGateway {
  RunGateway(this.items, {this.failure});
  List<MessageWithParts> items;
  Object? failure;

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async {
    if (failure != null) throw failure!;
    return ServerPage(items: items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RunController extends ConnectionController {
  RunController(super.store);
  ServerGateway? transport;
  @override
  Future<ServerGateway?> prepareActionTransport() async => transport;
}

MessageWithParts runMessage(
  String id, {
  required String role,
  required int created,
  int? completed,
  String? finish,
  List<Part> parts = const [],
}) => MessageWithParts(
  info: MessageInfo(
    id: id,
    sessionID: 'ses_1',
    role: role,
    agent: role == 'assistant' ? 'build' : null,
    modelID: role == 'assistant' ? 'gpt-5' : null,
    time: MsgTime(created: created, completed: completed),
    finish: finish,
  ),
  parts: parts,
);

Part runTool(
  String id,
  String name,
  Map<String, dynamic> input, {
  Map<String, dynamic>? metadata,
  String output = '',
}) => Part(
  id: id,
  callID: id,
  type: 'tool',
  toolName: name,
  toolState: ToolState(
    status: 'completed',
    input: input,
    output: output,
    metadata: metadata,
  ),
);

/// A finished run that edited two files and ran the tests.
List<MessageWithParts> finishedRun() => [
  runMessage('u-prompt', role: 'user', created: 20),
  runMessage(
    'a-edit',
    role: 'assistant',
    created: 30,
    completed: 31,
    finish: 'tool-calls',
    parts: [
      runTool('e1', 'edit', {'filePath': 'lib/checkout/checkout_page.dart'}),
      runTool('e2', 'write', {'filePath': 'test/checkout_test.dart'}),
    ],
  ),
  runMessage(
    'a-final',
    role: 'assistant',
    created: 40,
    completed: 41,
    finish: 'stop',
    parts: [
      runTool(
        'c-test',
        'bash',
        {'command': 'flutter test test/checkout_test.dart'},
        metadata: {'exit': 0},
        output: '00:03 +12: All tests passed!',
      ),
    ],
  ),
];

/// The same run while its newest step is still going.
List<MessageWithParts> runningRun() => [
  ...finishedRun().take(2),
  runMessage('a-final', role: 'assistant', created: 40),
];

Future<RunController> runController(ServerGateway? transport) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = RunController(ProfileStore(prefs: preferences))
    ..repository = RunRepository()
    ..status = StreamStatus.connected
    ..transport = transport;
  controller.sessionsById = {
    'ses_1': Session(
      id: 'ses_1',
      title: 'Fix the checkout total',
      directory: '/work/shop',
      time: SessionTime(created: 1, updated: 2),
    ),
  };
  return controller;
}

Widget hostApp(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a run that changed files pins "Review changed files"', (
    tester,
  ) async {
    final controller = await runController(RunGateway(finishedRun()));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostApp(RunResultScreen(controller: controller, sessionID: 'ses_1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const Key('run-result-review-changes')), findsOneWidget);
    expect(find.text('Review changed files'), findsOneWidget);
    expect(find.byKey(const Key('run-result-running')), findsNothing);
  });

  testWidgets('a run with no file changes pins nothing', (tester) async {
    final run = finishedRun()..removeAt(1);
    final controller = await runController(RunGateway(run));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostApp(RunResultScreen(controller: controller, sessionID: 'ses_1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-result-review-changes')), findsNothing);
  });

  testWidgets('a run still going says so above what it has done so far', (
    tester,
  ) async {
    final controller = await runController(RunGateway(runningRun()));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostApp(RunResultScreen(controller: controller, sessionID: 'ses_1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-result-running')), findsOneWidget);
    expect(
      find.text(
        'Still running. This shows what it has done so far; pull down for '
        'the latest.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a raw load error says why in words and keeps the raw text '
      'behind Details', (tester) async {
    final gateway = RunGateway(
      finishedRun(),
      failure: StateError('socket closed by 10.0.0.2'),
    );
    final controller = await runController(gateway);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostApp(RunResultScreen(controller: controller, sessionID: 'ses_1')),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load run results"), findsOneWidget);
    expect(
      find.text("The server didn't send this run's history."),
      findsOneWidget,
    );
    expect(find.textContaining('10.0.0.2'), findsNothing);
    gateway.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the result and says so', (tester) async {
    final gateway = RunGateway(finishedRun());
    final controller = await runController(gateway);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostApp(RunResultScreen(controller: controller, sessionID: 'ses_1')),
    );
    await tester.pumpAndSettle();
    gateway.failure = const ProductException('OpenCode is reconnecting.');
    await tester.fling(
      find.byKey(const Key('run-result-view')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-result-refresh-error')), findsOneWidget);
    expect(
      find.text("Couldn't refresh. This is what was loaded before."),
      findsOneWidget,
    );
    expect(find.text('Completed'), findsOneWidget);
  });
}
