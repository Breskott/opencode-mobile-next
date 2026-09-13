import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
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
        : Scaffold(body: LibraryScreen(controller: controller)),
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
    testWidgets('More exposes phone Termux above server tools at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await _state();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, scale: scale));
      await tester.pumpAndSettle();
      expect(find.text('Termux setup').hitTestable(), findsOneWidget);
      expect(find.text('Run OpenCode on this phone'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Termux setup')).dy,
        lessThan(tester.getTopLeft(find.text('Browse')).dy),
      );
      await tester.enterText(
        find.byKey(const Key('library-search')),
        'local termux',
      );
      await tester.pumpAndSettle();
      expect(find.text('Termux setup'), findsOneWidget);
      expect(find.text('Models & agents'), findsNothing);
      expect(tester.takeException(), isNull);
    });
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
        await tester.tap(find.text('Termux setup'));
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
        expect(calls, ['getCapabilities']);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Termux setup'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'saved remote Servers has a direct Termux route without expansion',
    (tester) async {
      final controller = await _state();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, servers: true));
      await tester.pumpAndSettle();
      expect(find.text('Termux setup').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-add-termux-card')),
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
      expect(find.text('Termux setup'), findsNothing);
      await tester.pumpWidget(_app(controller, servers: true));
      await tester.pumpAndSettle();
      expect(find.text('Termux setup'), findsNothing);
    });
  }
}
