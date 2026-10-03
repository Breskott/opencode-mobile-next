// Work opens with the person's own titles (slice-speed-ui;
// docs/qa/codex-speed-2026-09-28 contract item 1): while the first page of
// conversations loads, the titles this project listed last time stand in
// for skeleton rows, read-only; on resume the live rows stay while the list
// refreshes, with no blank list or full-page spinner in between.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_inventory_cache.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart'
    show CaptureApi, CaptureController, CaptureRepository, SeededProfileStore;

const _current = '/root/projects/FinanceHub3';
final _now = DateTime.now().millisecondsSinceEpoch;
const _minute = 60 * 1000;

Session _session(String id, String title, {int ago = 5 * _minute}) => Session(
  id: id,
  title: title,
  directory: _current,
  time: SessionTime(created: _now - ago - _minute, updated: _now - ago),
);

class _Controller extends CaptureController {
  _Controller(super.store);

  @override
  Future<void> refreshSessions() async {}

  @override
  Future<void> selectInitialLocation({
    String? directory,
    String? workspace,
  }) async {}
}

final _profile = ServerProfile(
  id: 'laptop',
  name: 'Laptop',
  baseUrl: 'https://100.64.0.1:4096',
);

/// A connected controller on [_current]; with [cachedFor] set, the titles
/// Work listed last time for that folder are saved first.
Future<_Controller> _controller({
  Map<String, Session> sessions = const {},
  String? cachedFor,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SeededProfileStore(prefs: prefs, seeded: [_profile]);
  await store.setLocation('laptop', directory: _current);
  if (cachedFor != null) {
    await SessionInventoryCache(prefs).save(
      'laptop',
      SessionInventoryCache.scopeFor(_profile, cachedFor, null),
      [
        _session('old-1', 'Reconcile the ledger', ago: 60 * _minute),
        _session('old-2', 'Quarterly report draft', ago: 3 * 60 * _minute),
      ],
      isCurrent: () => true,
      fetchedAt: DateTime.now().subtract(const Duration(minutes: 7)),
    );
  }
  final controller = _Controller(store)
    ..api = CaptureApi()
    ..repository = CaptureRepository()
    ..status = StreamStatus.connected
    ..directory = _current
    ..sessionsById = Map.of(sessions)
    ..busySessions = <String>{};
  controller.adoptConnectedProfileForTesting(_profile);
  return controller;
}

Future<void> _pumpWork(WidgetTester tester, _Controller controller) async {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secure,
      null,
    ),
  );
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route ${settings.name}')),
      ),
      home: Scaffold(body: WorkspaceScreen(controller: controller)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _dispose(WidgetTester tester, _Controller controller) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  await tester.pump();
}

final _skeleton = find.byKey(const ValueKey('kit-skeleton-rows'));

void main() {
  testWidgets('before any cache: the first load shows skeleton rows', (
    tester,
  ) async {
    final controller = await _controller()
      ..sessionsLoading = true;
    await _pumpWork(tester, controller);
    expect(_skeleton, findsOneWidget);
    expect(find.byType(KitLastKnown), findsNothing);
    await _dispose(tester, controller);
  });

  testWidgets('first load shows last time\'s titles, read-only, instead of '
      'skeletons', (tester) async {
    final controller = await _controller(cachedFor: _current)
      ..sessionsLoading = true;
    await _pumpWork(tester, controller);
    expect(_skeleton, findsNothing);
    expect(find.text('Reconcile the ledger'), findsOneWidget);
    expect(find.text('Quarterly report draft'), findsOneWidget);
    expect(find.text('Updated 7 min ago · Refreshing'), findsOneWidget);
    // One loading bar still says the live list is on its way.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Nothing on them acts: no live row, and a tap opens nothing.
    expect(find.byKey(const ValueKey('session-row-old-1')), findsNothing);
    await tester.tap(find.text('Reconcile the ledger'), warnIfMissed: false);
    // The loading bar never settles; a few frames are enough for a push.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('route /chat/old-1'), findsNothing);
    await _dispose(tester, controller);
  });

  testWidgets('the live list replaces them, even when it is empty', (
    tester,
  ) async {
    final controller = await _controller(cachedFor: _current)
      ..sessionsLoading = true;
    await _pumpWork(tester, controller);
    expect(find.text('Reconcile the ledger'), findsOneWidget);
    controller
      ..sessionsLoading = false
      ..sessionsById = {'n': _session('n', 'Live conversation')};
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Reconcile the ledger'), findsNothing);
    expect(find.text('Live conversation'), findsOneWidget);
    expect(find.byType(KitLastKnown), findsNothing);

    controller.sessionsById = {};
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Reconcile the ledger'), findsNothing);
    expect(find.byType(KitLastKnown), findsNothing);
    await _dispose(tester, controller);
  });

  testWidgets('titles saved for another folder never show here', (
    tester,
  ) async {
    final controller = await _controller(cachedFor: '/root/projects/Other')
      ..sessionsLoading = true;
    await _pumpWork(tester, controller);
    expect(find.text('Reconcile the ledger'), findsNothing);
    expect(_skeleton, findsOneWidget);
    await _dispose(tester, controller);
  });

  testWidgets('a failed first read keeps last time\'s titles, no longer '
      '"Refreshing"', (tester) async {
    final controller = await _controller(cachedFor: _current)
      ..sessionsError = 'HTTP 502 upstream';
    await _pumpWork(tester, controller);
    expect(find.text('Reconcile the ledger'), findsOneWidget);
    expect(find.text('Updated 7 min ago'), findsOneWidget);
    expect(find.textContaining('Refreshing'), findsNothing);
    expect(find.textContaining('HTTP 502'), findsNothing);
    await _dispose(tester, controller);
  });

  testWidgets('resume: live rows stay while the list refreshes — no blank '
      'list, no skeleton, no full-page spinner', (tester) async {
    final controller = await _controller(
      cachedFor: _current,
      sessions: {'a': _session('a', 'Live conversation')},
    );
    await _pumpWork(tester, controller);
    expect(find.byKey(const ValueKey('session-row-a')), findsOneWidget);
    // The app comes back to the foreground and revalidates.
    controller.sessionsLoading = true;
    controller.notifyListeners();
    await tester.pump();
    expect(find.byKey(const ValueKey('session-row-a')), findsOneWidget);
    expect(_skeleton, findsNothing);
    expect(find.byType(KitLastKnown), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _dispose(tester, controller);
  });
}
