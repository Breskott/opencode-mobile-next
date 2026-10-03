// P6.1 What runs by itself (`automation-settings`): the page shows only what
// the current server really has, stores the team's level per server under
// `oc.automation.<profileId>`, says a refused save instead of pretending, and
// the Settings hub reaches it (Always allowed actions now sits inside it).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/automation_settings_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

final _en = lookupAppLocalizations(const Locale('en'));

class _Storage extends InMemorySharedPreferencesStore {
  _Storage(super.data) : super.withData();
  bool refuse = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      refuse && key.contains('oc.automation.')
      ? false
      : super.setValue(valueType, key, value);
}

late _Storage _storage;

Map<String, Object> _profiles() => {
  'oc.profiles': jsonEncode([
    {
      'id': 'profile-1',
      'name': 'Workstation',
      'baseUrl': 'http://192.168.1.20:4096',
      'username': '',
    },
    {
      'id': 'profile-2',
      'name': 'Studio',
      'baseUrl': 'http://192.168.1.30:4096',
      'username': '',
    },
  ]),
  'oc.activeProfile': 'profile-1',
};

Future<ConnectionController> _controller({
  Map<String, Object> values = const {},
}) async {
  _storage = _Storage({
    for (final e in {..._profiles(), ...values}.entries)
      'flutter.${e.key}': e.value,
  });
  SharedPreferencesStorePlatform.instance = _storage;
  SharedPreferences.resetStatic();
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return ConnectionController(store)..status = StreamStatus.connected;
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Widget _section(
  ConnectionController controller, {
  required bool teamAvailable,
}) => Scaffold(
  body: SingleChildScrollView(
    child: AutomationSettingsSection(
      controller: controller,
      teamAvailable: teamAvailable,
    ),
  ),
);

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AutomationPolicyController.resetShared();
    debugPlatformCapabilities = const PlatformCapabilities.android();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    AutomationPolicyController.resetShared();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  testWidgets('a fresh server starts at High and stores nothing until chosen', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(_section(controller, teamAvailable: true)));
    await tester.pumpAndSettle();

    expect(find.text(_en.automationTeamLabel), findsOneWidget);
    // The rest lives where it already works; the page opens it there.
    expect(_key('automation-saved-permissions'), findsOneWidget);
    expect(
      AutomationPolicyController.forProfile(
        controller.store.prefs,
        'profile-1',
      ).value.supervision,
      AutomationSupervision.high,
    );
    expect(controller.store.prefs.getString('oc.automation.profile-1'), isNull);
  });

  testWidgets('choosing a level is stored for this server only', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(_section(controller, teamAvailable: true)));
    await tester.pumpAndSettle();

    await tester.tap(_key('automation-supervision-autonomous'));
    await tester.pumpAndSettle();

    final raw = controller.store.prefs.getString('oc.automation.profile-1');
    expect(jsonDecode(raw!)['supervision'], 'autonomous');
    expect(controller.store.prefs.getString('oc.automation.profile-2'), isNull);
    expect(_key('automation-save-failed'), findsNothing);
    // The start sheet of this server's team starts at the stored level.
    expect(
      AutomationPolicyController.forProfile(
        controller.store.prefs,
        'profile-1',
      ).value.supervision.team.name,
      'autonomous',
    );
    // Survives a restart: a fresh controller reads the same record.
    AutomationPolicyController.resetShared();
    expect(
      AutomationPolicyController.forProfile(
        controller.store.prefs,
        'profile-1',
      ).value.supervision,
      AutomationSupervision.autonomous,
    );
  });

  testWidgets('a refused save is said and the level stays as it was', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(_section(controller, teamAvailable: true)));
    await tester.pumpAndSettle();
    _storage.refuse = true;

    await tester.tap(_key('automation-supervision-balanced'));
    await tester.pumpAndSettle();

    expect(_key('automation-save-failed'), findsOneWidget);
    expect(find.text(_en.automationSaveFailed), findsOneWidget);
    expect(
      AutomationPolicyController.forProfile(
        controller.store.prefs,
        'profile-1',
      ).value.supervision,
      AutomationSupervision.high,
    );
  });

  testWidgets('without a team there is no level to choose', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(_section(controller, teamAvailable: false)));
    await tester.pumpAndSettle();

    expect(_key('automation-team'), findsNothing);
    expect(_key('automation-saved-permissions'), findsOneWidget);
  });

  testWidgets(
    'Always allowed actions is a section of Notifications and background',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(NotificationsSettingsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // The watching switch is on this same page, not a door.
      expect(_key('monitor-enabled-profile-1'), findsOneWidget);
      expect(_key('automation-watch'), findsNothing);
      // No hub row of its own: What runs by itself is the page's last section.
      expect(_key('settings-automation'), findsNothing);
      expect(_key('saved-permissions-entry'), findsNothing);
      await tester.ensureVisible(_key('automation-saved-permissions'));
      await tester.pumpAndSettle();
      await tester.tap(_key('automation-saved-permissions'));
      await tester.pumpAndSettle();
      expect(find.text(_en.e7LibraryAlwaysAllowedActions), findsWidgets);
    },
  );

  test('deleting a server closes its policy and sweeps the record', () async {
    final controller = await _controller(
      values: {
        'oc.automation.profile-2': jsonEncode(
          AutomationPolicy()
              .withSupervision(AutomationSupervision.balanced)
              .toJson(),
        ),
      },
    );
    addTearDown(controller.dispose);
    final policy = AutomationPolicyController.forProfile(
      controller.store.prefs,
      'profile-2',
    );
    expect(policy.value.supervision, AutomationSupervision.balanced);

    await controller.deleteProfileAndLocalData('profile-2');

    expect(controller.store.prefs.getString('oc.automation.profile-2'), isNull);
    await expectLater(
      policy.setSupervision(AutomationSupervision.autonomous),
      throwsStateError,
    );
    // A later lookup starts clean instead of reusing the closed one.
    final fresh = AutomationPolicyController.forProfile(
      controller.store.prefs,
      'profile-2',
    );
    expect(identical(fresh, policy), isFalse);
    expect(fresh.value.supervision, AutomationSupervision.high);
  });
}
