import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/state/codex_connection_probe.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/first_run_path.dart';

/// The first-run connect screen tests by itself once the required fields are
/// valid and the person pauses (UX plan 5.6 step 3).

class _Store extends ProfileStore {
  _Store({required super.prefs, this.seeded = const []});

  final List<ServerProfile> seeded;

  @override
  String? get activeId => null;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(seeded);

  @override
  Future<String?> secureStorageProblem() async => null;
}

Future<(_Store, ConnectionController)> _state({
  List<ServerProfile> seeded = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = _Store(
    prefs: await SharedPreferences.getInstance(),
    seeded: seeded,
  );
  return (store, ConnectionController(store));
}

Widget _app(ProfileStore store, ConnectionController controller) =>
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(store)),
        connProvider.overrideWithValue(controller),
      ],
      child: const MaterialApp(home: ServersScreen()),
    );

const _url = ValueKey('server-url-field');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const termux = MethodChannel('oc/termux');
  final oldProbe = serverProbe;
  final oldSocketProbe = socketAgentProbe;
  final probed = <String>[];

  setUp(() {
    probed.clear();
    messenger.setMockMethodCallHandler(
      termux,
      (call) async => {'installed': false},
    );
    serverProbe = ({required baseUrl, username, password}) async {
      probed.add(baseUrl);
      return const ServerProbeResult.success('2.0.0', flavor: ServerFlavor.v2);
    };
  });
  tearDown(() {
    serverProbe = oldProbe;
    socketAgentProbe = oldSocketProbe;
    messenger.setMockMethodCallHandler(termux, null);
  });

  testWidgets('tests once after a pause, never per keystroke', (tester) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    // Every prefix from "https://b" on is a valid address. Typing faster
    // than the pause must not probe any of them.
    const address = 'https://box.example:4096';
    for (var end = 'https://b'.length; end <= address.length; end++) {
      await tester.enterText(find.byKey(_url), address.substring(0, end));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(probed, isEmpty);
    expect(find.byKey(const ValueKey('server-probe-verdict')), findsNothing);

    // Just short of the pause: still nothing.
    await tester.pump(autoTestPause - const Duration(milliseconds: 200));
    expect(probed, isEmpty);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(probed, [address]);
    expect(find.byKey(const ValueKey('server-test-success')), findsOneWidget);

    // Once per pause: standing still does not test again.
    await tester.pump(const Duration(seconds: 5));
    expect(probed, [address]);
  });

  testWidgets('an address that is not valid yet is never probed', (
    tester,
  ) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(find.byKey(_url), 'ftp://box.example');
    await tester.pump(const Duration(seconds: 3));
    expect(probed, isEmpty);
    // The automatic test stays quiet about a half-typed value; the error
    // belongs to the explicit button and to Save.
    expect(find.byKey(const ValueKey('server-probe-verdict')), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(_url)).decoration?.errorText,
      isNull,
    );
  });

  testWidgets('a stale result is discarded when the address changed', (
    tester,
  ) async {
    final pending = <String, Completer<ServerProbeResult>>{};
    serverProbe = ({required baseUrl, username, password}) {
      probed.add(baseUrl);
      return (pending[baseUrl] = Completer<ServerProbeResult>()).future;
    };
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(find.byKey(_url), 'https://old.example');
    await tester.pump(autoTestPause + const Duration(milliseconds: 50));
    expect(probed, ['https://old.example']);

    await tester.enterText(find.byKey(_url), 'https://new.example');
    await tester.pump(autoTestPause + const Duration(milliseconds: 50));
    expect(probed, ['https://old.example', 'https://new.example']);

    // The first probe answers late, about an address no longer on screen.
    pending['https://old.example']!.complete(
      const ServerProbeResult.failure('old address refused'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('old address refused'), findsNothing);
    expect(find.byKey(const ValueKey('server-probe-verdict')), findsNothing);

    pending['https://new.example']!.complete(
      const ServerProbeResult.success('2.0.0', flavor: ServerFlavor.v2),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('server-test-success')), findsOneWidget);
  });

  testWidgets('a failure names the cause and one fix, and keeps the focus', (
    tester,
  ) async {
    serverProbe = ({required baseUrl, username, password}) async {
      probed.add(baseUrl);
      return const ServerProbeResult.failure(
        'Nothing answered at box.example:4096.',
        suggestsMissingServer: true,
      );
    };
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(find.byKey(_url), 'https://box.example:4096');
    await tester.pump(autoTestPause + const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.byKey(const ValueKey('server-test-failure')), findsOneWidget);
    expect(find.text('Nothing answered at box.example:4096.'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-test-guide')), findsOneWidget);
    // The person is still in the address field; an automatic verdict must
    // not take the keyboard somewhere else.
    expect(
      tester.widget<TextField>(find.byKey(_url)).focusNode!.hasFocus,
      isTrue,
    );

    // The button stays for a re-run after fixing the server.
    final button = find.byKey(const ValueKey('test-server-connection'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(probed, hasLength(2));
  });

  testWidgets(
    'Codex waits for every required field, then tests once',
    (tester) async {
      final calls = <(ServerBackend, String, String, String)>[];
      socketAgentProbe =
          ({
            required backend,
            required baseUrl,
            required secret,
            required directory,
          }) async {
            calls.add((backend, baseUrl, secret, directory));
            return const CodexConnectionProbeResult(
              ok: true,
              message: 'Codex connection verified.',
            );
          };
      final (store, controller) = await _state();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(store, controller));
      await openFirstRunConnect(tester, agent: 'codex');

      await tester.enterText(
        find.byKey(const ValueKey('codex-server-address-field')),
        'ws://127.0.0.1:4141',
      );
      await tester.enterText(
        find.byKey(const ValueKey('codex-project-directory-field')),
        '/work/project',
      );
      // No token yet: the address alone is not a testable connection.
      await tester.pump(const Duration(seconds: 3));
      expect(calls, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('codex-connection-token-field')),
        'synthetic-token',
      );
      await tester.pump(autoTestPause + const Duration(milliseconds: 50));
      await tester.pump();
      expect(calls, [
        (
          ServerBackend.codex,
          'ws://127.0.0.1:4141',
          'synthetic-token',
          '/work/project',
        ),
      ]);
      expect(find.byKey(const ValueKey('codex-test-success')), findsOneWidget);
      expect(probed, isEmpty);
    },
  );

  testWidgets('editing a saved server never tests by itself', (tester) async {
    final (store, controller) = await _state(
      seeded: [
        ServerProfile(
          id: 'work',
          name: 'Workstation',
          baseUrl: 'https://box.example',
        ),
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_url), 'https://moved.example');
    await tester.pump(const Duration(seconds: 5));
    expect(probed, isEmpty);
    expect(find.byKey(const ValueKey('server-probe-verdict')), findsNothing);

    // Neither does "Add server" beside saved servers: only the first-run
    // path is sequenced.
    await tester.tap(find.byTooltip('Close server editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_url), 'https://another.example');
    await tester.pump(const Duration(seconds: 5));
    expect(probed, isEmpty);
  });

  testWidgets('leaving the screen cancels the queued test', (tester) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(find.byKey(_url), 'https://box.example');
    await tester.tap(find.byTooltip('Close server editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(probed, isEmpty);
  });
}
