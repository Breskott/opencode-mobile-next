// Golden renders of slice-cred-status: the one connection status line and the
// Servers page when the active server's saved password can no longer be read
// from the phone's secure storage (a restore or a lock-screen change). Phone
// 412x915 dark and light and the wide window (1280x800), app fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/cred_status_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _IdleConnection extends ConnectionController {
  _IdleConnection(super.store);

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {}
}

void main() {
  setUpAll(loadCaptureFonts);

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required Size size,
    required bool light,
    bool details = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = light
        ? Brightness.light
        : Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_secureStorage, (call) async {
      if (call.method == 'read') {
        throw PlatformException(code: 'Exception', message: 'bad tag');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_secureStorage, null));
    const thermal = EventChannel('oc/thermal/events');
    messenger.setMockStreamHandler(
      thermal,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() => messenger.setMockStreamHandler(thermal, null));
    final servers = [
      ServerProfile(
        id: 'server-1',
        name: 'Workstation',
        baseUrl: 'https://server.example:4096',
        username: 'opencode',
      ),
      ServerProfile(
        id: 'server-2',
        name: 'Laptop',
        baseUrl: 'https://laptop.example:4096',
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([for (final s in servers) s.toJson()]),
      'oc.activeProfile': 'server-1',
    });
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await tester.runAsync(store.load);
    final connection = _IdleConnection(store);
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(AppBootstrap(store)),
          connProvider.overrideWithValue(connection),
        ],
        child: const OcApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (details) {
      await tester.tap(find.byKey(const ValueKey('kit-status-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details').last);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(OcApp),
      matchesGoldenFile('goldens/cred_status_$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    testWidgets('servers, unreadable password, phone $theme', (tester) async {
      await shot(tester, 'servers_$theme', size: _phone, light: light);
    });
  }
  testWidgets('details, unreadable password, phone light', (tester) async {
    await shot(
      tester,
      'details_light',
      size: _phone,
      light: true,
      details: true,
    );
  });
  testWidgets('servers, unreadable password, wide dark', (tester) async {
    await shot(tester, 'servers_1280x800_dark', size: _wide, light: false);
  });
}
