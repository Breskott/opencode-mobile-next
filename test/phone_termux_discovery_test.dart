import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_start_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RemoteStore extends ProfileStore {
  _RemoteStore({required super.prefs});
  final remote = ServerProfile(
    id: 'remote',
    name: 'Work computer',
    baseUrl: 'https://work.example',
  );
  @override
  List<ServerProfile> get profiles => [remote];
  @override
  String? get activeId => remote.id;
}

Future<ConnectionController> _state() async {
  SharedPreferences.setMockInitialValues({});
  return ConnectionController(
    _RemoteStore(prefs: await SharedPreferences.getInstance()),
  );
}

Widget _app(
  ConnectionController controller, {
  bool servers = false,
  double scale = 1,
}) => ProviderScope(
  overrides: [
    bootstrapProvider.overrideWithValue(AppBootstrap(controller.store)),
    connProvider.overrideWithValue(controller),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    routes: {'/termux-setup': (_) => const TermuxSetupScreen()},
    home: servers
        ? const ServersScreen()
        : Scaffold(
            body: SettingsScreen(controller: controller, embedded: true),
          ),
  ),
);

void main() {
  const channel = MethodChannel('oc/termux');
  setUp(() => debugPlatformCapabilities = const PlatformCapabilities.android());
  tearDown(() {
    debugPlatformCapabilities = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final scale in [1.0, 2.5]) {
    testWidgets(
      'Settings exposes phone Termux above server tools at ${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = await _state();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller, scale: scale));
        await tester.pumpAndSettle();
        final phone = find.byKey(const ValueKey('settings-on-this-phone'));
        expect(
          find.descendant(of: phone, matching: find.text('On this phone')),
          findsOneWidget,
        );
        expect(
          find.text('Run a coding agent right here. No computer needed.'),
          findsOneWidget,
        );
        // A Connection row: above everything that depends on the server.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('settings-group-connection')),
            matching: phone,
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(phone).dy,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('settings-group-agent-setup')),
                )
                .dy,
          ),
        );
        // Reachable by scrolling alone: no search, no expander to open first.
        await tester.ensureVisible(phone);
        await tester.pumpAndSettle();
        expect(phone.hitTestable(), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('library-search')),
          'local termux',
        );
        await tester.pumpAndSettle();
        expect(find.text('On this phone'), findsOneWidget);
        expect(find.text('Models & agents'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final state in [
    'not installed',
    'permission needed',
    'unsupported version',
  ]) {
    testWidgets(
      'remote-profile Termux entry opens honest $state recovery without switching profile',
      (tester) async {
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              return {
                'installed': state != 'not installed',
                'version': '0.118',
                'serviceAvailable': true,
                'protocolSupported': state != 'unsupported version',
                'permissionGranted': false,
              };
            });
        final controller = await _state();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller));
        await tester.pumpAndSettle();
        await tester.tap(find.text('On this phone'));
        await tester.pumpAndSettle();
        // The phone setup screen; Termux is one of its other ways.
        expect(find.byType(PhoneSetupStartScreen), findsOneWidget);
        // It gives reading a stopped setup a few seconds before it shows.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        final otherWays = find.byKey(
          const ValueKey('phone-setup-start-other-ways'),
        );
        await tester.ensureVisible(otherWays);
        await tester.tap(otherWays);
        await tester.pumpAndSettle();
        final useTermux = find.byKey(
          const ValueKey('phone-setup-start-use-termux'),
        );
        await tester.ensureVisible(useTermux);
        await tester.tap(useTermux);
        await tester.pumpAndSettle();
        expect(find.byType(TermuxSetupScreen), findsOneWidget);
        if (state == 'not installed') {
          expect(find.text('Get Termux'), findsOneWidget);
        }
        if (state == 'permission needed') {
          expect(find.text('Connect Termux once'), findsOneWidget);
        }
        if (state == 'unsupported version') {
          expect(
            find.textContaining('This version of Termux is too old'),
            findsOneWidget,
          );
        }
        expect(controller.store.activeId, 'remote');
        expect(
          controller.store.profiles.single.baseUrl,
          'https://work.example',
        );
        // Only reads: the setup screen and the Termux screen each look once.
        expect(calls.toSet(), {'getCapabilities'});
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Back through the setup screen to Settings. Its Termux look has
        // timeouts of its own (up to 10 s); let them run out.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 11));
        expect(find.text('On this phone'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'saved remote Servers has a direct phone setup route without expansion',
    (tester) async {
      final controller = await _state();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, servers: true));
      await tester.pumpAndSettle();
      expect(find.text('On this phone').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-add-phone-card')),
        findsOneWidget,
      );
      expect(find.text('Connect with Tailscale'), findsNothing);
    },
  );

  for (final platform in [TargetPlatform.linux, TargetPlatform.iOS]) {
    testWidgets('$platform does not offer Termux on More or Servers', (
      tester,
    ) async {
      debugPlatformCapabilities = PlatformCapabilities(platform: platform);
      final controller = await _state();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      expect(find.text('On this phone'), findsNothing);
      await tester.pumpWidget(_app(controller, servers: true));
      await tester.pumpAndSettle();
      expect(find.text('On this phone'), findsNothing);
    });
  }
}
