import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/domain/opencode_history_copy.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revamp/screen_phone_1_fixtures.dart';
import 'support/termux_channel_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryProfileStore store;
  late FakePhoneConnection connection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemoryProfileStore(prefs: await SharedPreferences.getInstance());
    connection = FakePhoneConnection(store);
    addTearDown(connection.dispose);
  });

  test(
    'history admission refuses every failure and identifies separate history',
    () {
      expect(
        OpenCodeHistorySwitchAdmission.fromResult(0, ''),
        OpenCodeHistorySwitchAdmission.allowed,
      );
      expect(
        OpenCodeHistorySwitchAdmission.fromResult(
          74,
          openCode1HistorySwitchBlockedMessage,
        ),
        OpenCodeHistorySwitchAdmission.separateHistory,
      );
      for (final code in [1, 74, 127, 137]) {
        expect(
          OpenCodeHistorySwitchAdmission.fromResult(code, 'unknown failure'),
          OpenCodeHistorySwitchAdmission.unavailable,
        );
      }
      expect(
        OpenCodeHistorySwitchAdmission.fromResult(
          127,
          openCode1HistorySwitchBlockedMessage,
        ),
        OpenCodeHistorySwitchAdmission.unavailable,
      );
    },
  );

  for (final installed in [false, true]) {
    test('in-app host preserves legacy installation: $installed', () async {
      final linux = PhoneLinux(installed: installed);
      final starter = BuiltinServerStarter(linux: linux);
      final host = InAppPhoneHost(
        linux: linux,
        starter: starter,
        connection: connection,
        pollInterval: null,
      );
      addTearDown(starter.dispose);
      addTearDown(host.dispose);
      await host.refresh();
      expect(
        host.runtime,
        installed ? TermuxRuntime.openCode1 : TermuxRuntime.openCode2,
      );
    });

    test('Termux host preserves legacy installation: $installed', () async {
      final channel = TermuxChannelFixture()
        ..inventoryOutput =
            'ubuntu=${installed ? 'installed' : 'absent'}\nversion=\n';
      channel.install();
      final host = TermuxPhoneHost(
        connection: connection,
        copy: AppLocalizationsEn.new,
      );
      addTearDown(host.dispose);
      await host.refresh();
      expect(
        host.runtime,
        installed ? TermuxRuntime.openCode1 : TermuxRuntime.openCode2,
      );
    });
  }

  test('saved Termux runtime wins over a fresh-install default', () async {
    store.saved.add(
      ServerProfile(
        id: 'older',
        name: 'My phone',
        baseUrl: TermuxBridge.managedServerUrl,
        flavor: ServerFlavor.v1,
      ),
    );
    final host = TermuxPhoneHost(
      connection: connection,
      copy: AppLocalizationsEn.new,
    );
    addTearDown(host.dispose);
    expect(host.runtime, TermuxRuntime.openCode1);
    expect(store.saved.single.name, 'My phone');
  });
}
