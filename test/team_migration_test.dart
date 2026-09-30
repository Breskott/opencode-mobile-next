// B-2 (E2E 2026-09-30): an old team that stays On after the update gets one
// screen that says AI Team changed, with the switch, keeping the old team,
// and a way into the project screens. Fakes only.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/phone_team_setup.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

class _Phone extends ChangeNotifier implements PhoneTeamSetupPorts {
  _Phone({this.server = true});
  final bool server;
  @override
  bool get hasServer => server;
  @override
  bool get wasOn => false;
  @override
  bool get replyRunning => true;
  @override
  Listenable get replyChanges => this;
  @override
  Future<PhoneTeamHostState> inspect() async => const PhoneTeamHostState();
  @override
  Future<void> stopServer() async {}
  @override
  Future<void> closeTerminals() async {}
  @override
  Future<PhoneEngineHealth> startEngine() => throw UnimplementedError();
  @override
  Future<PhoneEngineHealth> probeEngine() => throw UnimplementedError();
  @override
  Future<String?> startServer() async => null;
  @override
  Future<void> attach() async {}
  @override
  dynamic noSuchMethod(Invocation i) => Future<bool>.value(true);
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 15; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<ConnectionController> _connect() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: 'http://127.0.0.1:8472',
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.phone,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final profile = ServerProfile(
    id: 'phone',
    name: 'This phone',
    baseUrl: 'http://127.0.0.1:4097',
    orchestration: config,
  );
  await store.upsert(profile);
  await store.setActiveId(profile.id);
  final connection = ConnectionController(store);
  addTearDown(connection.dispose);
  connection.adoptConnectedProfileForTesting(profile);
  connection.syncOrchestration();
  return connection;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => PhoneTeamSetup.debugPorts = null);

  void mock() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final c in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'oc/background',
      'oc/shortcut',
    ]) {
      m.setMockMethodCallHandler(
        MethodChannel(c),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
      addTearDown(() => m.setMockMethodCallHandler(MethodChannel(c), null));
    }
  }

  Widget app(ConnectionController c) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: TeamPage(connection: c),
  );

  testWidgets('old team on a phone that can run the new one: migration '
      'screen, keep shows the old team and remembers it', (tester) async {
    tester.view.physicalSize = const Size(412, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    mock();
    PhoneTeamSetup.debugPorts = (_) => _Phone();
    final connection = await _connect();
    await tester.pumpWidget(app(connection));
    await _settle(tester);
    expect(find.text(_en.teamMigrationTitle), findsOneWidget);
    expect(find.text(_en.teamMigrationSwitch), findsOneWidget);
    expect(find.byType(TeamHomeScreen), findsNothing);
    // The demo keeps project screens reachable.
    expect(_key('team-migration-demo'), findsOneWidget);

    await tester.tap(_key('team-migration-keep'));
    await _settle(tester);
    expect(find.byType(TeamHomeScreen), findsOneWidget);
    expect(
      connection.store.prefs.getBool('oc.teamMigrationKept.phone'),
      isTrue,
    );
    // The old team's menu still leads back to the choice.
    await tester.tap(_key('team-home-more'));
    await _settle(tester);
    expect(_key('team-home-migration'), findsOneWidget);
  });

  testWidgets('switch opens the phone setup flow', (tester) async {
    tester.view.physicalSize = const Size(412, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    mock();
    PhoneTeamSetup.debugPorts = (_) => _Phone();
    final connection = await _connect();
    await tester.pumpWidget(app(connection));
    await _settle(tester);
    await tester.tap(_key('team-migration-switch'));
    await _settle(tester);
    expect(_key('phone-team-steps'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no in-app server to switch on: the old team shows as before', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    mock();
    PhoneTeamSetup.debugPorts = (_) => _Phone(server: false);
    final connection = await _connect();
    await tester.pumpWidget(app(connection));
    await _settle(tester);
    expect(find.text(_en.teamMigrationTitle), findsNothing);
    expect(find.byType(TeamHomeScreen), findsOneWidget);
  });
}
