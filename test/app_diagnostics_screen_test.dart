import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/app_diagnostics_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DiagnosticsRepository implements ProductRepository {
  int sends = 0;
  String? message;
  Map<String, Object?>? extra;

  @override
  Future<void> writeClientLog({
    required String message,
    Map<String, Object?> extra = const {},
  }) async {
    sends++;
    this.message = message;
    this.extra = extra;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller(ProductRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  return ConnectionController(store)..repository = repository;
}

void main() {
  testWidgets('diagnostics are readable at narrow width and sent explicitly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _DiagnosticsRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    controller.diagnostics.record(
      StateError('render failed safely'),
      StackTrace.fromString('at build (lib/chat.dart:42:3)'),
      source: 'flutter',
    );

    await tester.pumpWidget(
      MaterialApp(home: AppDiagnosticsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private until you send it'), findsOneWidget);
    expect(
      find.textContaining('Nothing is sent automatically'),
      findsOneWidget,
    );
    expect(find.textContaining('render failed safely'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('send-app-diagnostics')));
    await tester.pumpAndSettle();

    expect(repository.sends, 1);
    expect(repository.message, contains('1 handled errors'));
    expect(repository.extra?['entryCount'], 1);
    // The result stays on the page and names where it went (no snackbar).
    expect(find.text("Sent to OpenCode server's log"), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Send names the server it goes to and says what happens', (
    tester,
  ) async {
    final controller = await _controller(_DiagnosticsRepository());
    addTearDown(controller.dispose);
    controller.diagnostics.record(StateError('boom'), null, source: 'sse');

    await tester.pumpWidget(
      MaterialApp(home: AppDiagnosticsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text("Send to OpenCode server's log"), findsOneWidget);
    expect(find.byKey(const Key('app-diagnostics-send-where')), findsOneWidget);
    expect(find.textContaining("makers don't receive them"), findsOneWidget);
  });

  testWidgets('Clear asks first with the count, then empties the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _controller(_DiagnosticsRepository());
    addTearDown(controller.dispose);
    controller.diagnostics
      ..record(StateError('first'), null, source: 'flutter')
      ..record(StateError('second'), null, source: 'sse');

    await tester.pumpWidget(
      MaterialApp(home: AppDiagnosticsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    // Copy and Clear sit in the menu on the errors list's header, named
    // with the count they act on.
    await tester.tap(find.byKey(const Key('app-diagnostics-actions')));
    await tester.pumpAndSettle();
    expect(find.text('Copy 2 errors'), findsOneWidget);
    expect(find.text('Clear 2 errors'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-app-diagnostics')));
    await tester.pumpAndSettle();
    expect(find.text('Clear 2 errors?'), findsOneWidget);
    expect(find.textContaining('The 2 errors recorded since'), findsOneWidget);
    // Cancel keeps them.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.diagnostics.count, 2);

    await tester.tap(find.byKey(const Key('app-diagnostics-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear-app-diagnostics')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear-app-diagnostics-confirm')));
    await tester.pumpAndSettle();
    expect(controller.diagnostics.count, 0);
    expect(find.text('No captured app errors'), findsOneWidget);
  });

  testWidgets('diagnostics screen explains an empty process-local report', (
    tester,
  ) async {
    final controller = await _controller(_DiagnosticsRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: AppDiagnosticsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No captured app errors'), findsOneWidget);
    expect(
      tester
          .widget<KitButton>(find.byKey(const Key('send-app-diagnostics')))
          .onPressed,
      isNull,
    );
  });
}
