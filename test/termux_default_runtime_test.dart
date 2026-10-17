import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/termux_host_setup.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/termux_channel_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TermuxChannelFixture termux;
  late MemoryProfileStore store;
  late FakePhoneConnection connection;
  late TermuxHostSetup setup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemoryProfileStore(prefs: await SharedPreferences.getInstance());
    connection = FakePhoneConnection(store);
    termux = TermuxChannelFixture()..install();
    setup = TermuxHostSetup(
      store: store,
      connection: connection,
      copy: () => lookupAppLocalizations(const Locale('en')),
      connectWhenReady: false,
    );
    addTearDown(() {
      setup.dispose();
      connection.dispose();
    });
  });

  test(
    'fresh Termux install selects pinned OC2 and stores an OC2 profile',
    () async {
      await setup.begin(TermuxHostJob.install);
      expect(termux.launchCalls, 1);
      expect(termux.runtime, TermuxRuntime.openCode2);
      expect(termux.lastLaunchScript, contains("setup '4096' '2.0.29'"));
      expect(store.saved.single.flavor, ServerFlavor.v2);
      expect(setup.runtime, TermuxRuntime.openCode2);
    },
  );

  test('legacy installed binary without runtime record stays OC1', () async {
    termux.inventoryOutput = 'ubuntu=installed\nversion=1.19.0\n';
    await setup.begin(TermuxHostJob.install);
    expect(termux.launchCalls, 1);
    expect(termux.runtime, TermuxRuntime.openCode1);
    expect(termux.lastLaunchScript, contains("setup '4096' '1.19.0'"));
    expect(store.saved.single.flavor, ServerFlavor.v1);
  });

  test('persisted OC1 choice before download remains selected', () async {
    termux.inventoryOutput = 'ubuntu=absent\nversion=\nruntime=opencode1\n';
    await setup.begin(TermuxHostJob.install);
    expect(termux.runtime, TermuxRuntime.openCode1);
    expect(store.saved.single.flavor, ServerFlavor.v1);
  });

  test('existing saved OC1 phone is not changed by the new default', () async {
    store.saved.add(
      ServerProfile(
        id: 'existing',
        name: 'This phone',
        baseUrl: TermuxBridge.managedServerUrl,
        flavor: ServerFlavor.v1,
        password: 'synthetic-test-secret',
      ),
    );
    await setup.begin(TermuxHostJob.install);
    expect(termux.runtime, TermuxRuntime.openCode1);
    expect(store.saved.single.id, 'existing');
    expect(store.saved.single.flavor, ServerFlavor.v1);
  });

  test('unreadable inventory cannot be treated as a fresh install', () async {
    termux.failInventory = true;
    await setup.begin(TermuxHostJob.install);
    expect(setup.phase, TermuxHostPhase.failed);
    expect(termux.launchCalls, 0);
    expect(store.saved, isEmpty);
  });
}
