// Emulator QA F14: a server reached at 127.0.0.1 through `adb reverse` got
// the green phone tile, the same as This phone. Only the app's own servers
// (the in-app one, the Termux one it manages, Claude Code on this phone)
// lead with the phone; any other loopback address is a server.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/server_switcher_sheet.dart';
import 'package:opencode_mobile/ui/widgets/termux_running_server_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revamp/shared_servers_1_fixtures.dart';

ServerProfile _at(String id, String url) =>
    ServerProfile(id: id, name: id, baseUrl: url);

class _LoopbackStore extends SwitcherStore {
  _LoopbackStore({required super.prefs});

  late final _all = [
    ...super.profiles,
    _at('forwarded', 'http://127.0.0.1:4123'),
  ];

  @override
  List<ServerProfile> get profiles => _all;
}

void main() {
  tearDown(() => debugPlatformCapabilities = null);

  test('only the phone\'s own servers count as this phone', () {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    expect(isPhoneOwnServer(_at('in-app', BuiltinLinux.serverUrl)), isTrue);
    expect(
      isPhoneOwnServer(_at('termux', TermuxBridge.managedServerUrl)),
      isTrue,
    );
    expect(
      isPhoneOwnServer(_at('forwarded', 'http://127.0.0.1:4123')),
      isFalse,
    );
    expect(isPhoneOwnServer(_at('local', 'http://localhost:4096')), isFalse);
    expect(isPhoneOwnServer(_at('lan', 'https://laptop.example')), isFalse);
  });

  testWidgets('the switcher draws a forwarded loopback server as a server', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = SwitcherController(
      _LoopbackStore(prefs: await SharedPreferences.getInstance()),
    );
    controller.api = OpenCodeApi(baseUrl: controller.profile!.baseUrl);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showServerSwitcher(context, controller),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('server-switcher-profile-forwarded'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIconography.server)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIconography.phone)),
      findsNothing,
    );
  });
}
