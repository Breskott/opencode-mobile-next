// slice-close-servers: the review board's profile-editor findings and the
// Servers row leftover (docs/qa/review-board-closure-2026-09-28, gap 7 and
// the "servers" low).
//
// - A refused connection is said in plain words that fit every kind of
//   server, not "Is opencode serve running…" beside an opencode2 pair
//   command.
// - A check's raw error is kept under Details, never shown as the verdict.
// - The verdict sits under the address field it is about, in view.
// - The Codex start command is one scrollable line, and the ws:// rule is
//   the field's own check instead of a standing helper.
// - A saved server's row says what it is and its state; the address moves to
//   the row menu's Details.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/setup_commands.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/server_editor.dart';

class _Store extends ProfileStore {
  _Store({required super.prefs, List<ServerProfile> seeded = const []})
    : saved = [...seeded];

  final List<ServerProfile> saved;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => null;

  @override
  Future<String?> secureStorageProblem() async => null;

  @override
  Future<void> upsert(ServerProfile profile) async {
    saved
      ..removeWhere((p) => p.id == profile.id)
      ..add(profile);
  }
}

class _Connection extends ConnectionController {
  _Connection(super.store);

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    api = OpenCodeApi(baseUrl: profile.baseUrl);
  }
}

final _laptop = ServerProfile(
  id: 'laptop',
  name: 'Laptop',
  baseUrl: 'https://laptop.example.net:4096',
);

final _codexBox = ServerProfile(
  id: 'codexbox',
  name: 'Build box',
  baseUrl: 'wss://codex.example.net',
  backend: ServerBackend.codex,
  codexDirectory: '/work/app',
);

Future<void> _pumpServers(
  WidgetTester tester, {
  List<ServerProfile> seeded = const [],
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = _Store(
    prefs: await SharedPreferences.getInstance(),
    seeded: seeded,
  );
  final connection = _Connection(store);
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(store)),
        connProvider.overrideWithValue(connection),
      ],
      child: MaterialApp(
        routes: {
          '/home': (_) => const Scaffold(body: Text('home-route')),
          '/guide': (_) => const Scaffold(body: Text('guide-route')),
        },
        home: const ServersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAddServer(
  WidgetTester tester, {
  String kind = 'opencode',
}) async {
  await _pumpServers(tester, seeded: [_laptop]);
  await tester.tap(find.byKey(const ValueKey('servers-add')));
  await tester.pumpAndSettle();
  await chooseServerKind(tester, kind: kind);
}

/// Types an address and taps Save & connect, the way most people check.
Future<void> _saveWithAddress(WidgetTester tester) async {
  await openServerManualAddress(tester);
  await tester.enterText(
    find.byKey(const ValueKey('server-url-field')),
    'https://build.example.net',
  );
  await tester.pump();
  tester.testTextInput.hide();
  await tester.tap(find.byKey(const ValueKey('save-server-profile')));
  await tester.pumpAndSettle();
}

/// The part of the screen the form scrolls in: above the pinned Save &
/// connect.
Rect _visibleForm(WidgetTester tester) {
  final save = tester.getRect(
    find.byKey(const ValueKey('save-server-profile')),
  );
  return Rect.fromLTRB(0, 0, 412, save.top);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const termux = MethodChannel('oc/termux');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          termux,
          (call) async => call.method == 'getCapabilities'
              ? <String, Object>{'installed': false}
              : null,
        );
    debugPlatformCapabilities = const PlatformCapabilities.android();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(termux, null);
    serverProbe = probeServerConnection;
    debugPlatformCapabilities = null;
  });

  testWidgets('a refused connection is said plainly, under the address '
      'field, in view', (tester) async {
    await _openAddServer(tester);
    // The probe's own words for a refused socket.
    serverProbe = ({required baseUrl, username, password}) async =>
        const ServerProbeResult.failure(
          'The connection was refused. Is opencode serve running on that '
          'host and port?',
          suggestsMissingServer: true,
        );
    await _saveWithAddress(tester);

    final verdict = find.byKey(const ValueKey('server-test-failure'));
    expect(verdict, findsOneWidget);
    // Plain words that fit an OpenCode 2 pair as well as an old serve.
    expect(find.textContaining('opencode serve'), findsNothing);
    expect(
      find.text(
        'The computer refused the connection. Check that the server is '
        'running there and that the address and port are right.',
      ),
      findsOneWidget,
    );
    // Under the field it is about, not at the head of the form.
    final field = find.byKey(const ValueKey('server-url-field'));
    expect(
      tester.getRect(verdict).top,
      greaterThanOrEqualTo(tester.getRect(field).bottom),
    );
    // And scrolled into view with its field, above the pinned button.
    final visible = _visibleForm(tester);
    expect(visible.contains(tester.getRect(verdict).topCenter), isTrue);
    expect(visible.contains(tester.getRect(field).center), isTrue);
  });

  testWidgets('a raw check error stays under Details', (tester) async {
    await _openAddServer(tester);
    serverProbe = ({required baseUrl, username, password}) async =>
        const ServerProbeResult.failure(
          'Connection test failed: HandshakeException: WRONG_VERSION_NUMBER',
        );
    await _saveWithAddress(tester);

    final verdict = find.byKey(const ValueKey('server-test-failure'));
    expect(verdict, findsOneWidget);
    expect(find.textContaining('HandshakeException'), findsNothing);
    expect(find.textContaining('Connection test failed'), findsNothing);
    expect(
      find.text(
        'The server could not be checked. Check the address and this '
        'phone’s connection, then try again.',
      ),
      findsOneWidget,
    );

    final details = find.byKey(const ValueKey('server-test-failure-details'));
    expect(details, findsOneWidget);
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: details,
        matching: find.byKey(const ValueKey('kit-details-toggle')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('HandshakeException: WRONG_VERSION_NUMBER'),
      findsOneWidget,
    );
  });

  test('the Codex start command is one line', () {
    expect(SetupCommands.codexStart, isNot(contains('\n')));
    expect(SetupCommands.codexStart, startsWith('codex app-server --listen'));
  });

  testWidgets('Codex: no standing ws/wss helper; the field checks the '
      'address when the person moves on', (tester) async {
    await _openAddServer(tester, kind: 'codex');
    expect(find.textContaining('Use wss:// for remote servers'), findsNothing);

    // The command reads as one line, not four "$" lines cut at the edge.
    final command = find.byKey(const ValueKey('connect-command'));
    expect(command, findsOneWidget);
    expect(
      find.descendant(of: command, matching: find.textContaining('\\')),
      findsNothing,
    );

    final address = find.byKey(const ValueKey('codex-server-address-field'));
    await tester.ensureVisible(address);
    await tester.enterText(address, 'ws://build.example.net:4141');
    await tester.pump();
    // Nothing is said while typing.
    expect(find.textContaining('ws:// works only'), findsNothing);
    // Moving on to the folder checks the address.
    final folder = find.byKey(const ValueKey('codex-project-directory-field'));
    await tester.ensureVisible(folder);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'ws:// works only for a server on this phone. Use a wss:// address '
        'for another computer.',
      ),
      findsOneWidget,
    );

    // A local address passes, and the error goes.
    await tester.enterText(address, 'ws://127.0.0.1:4141');
    await tester.pump();
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(find.textContaining('ws:// works only'), findsNothing);
  });

  testWidgets('a saved server row says what it is and its state; the '
      'address is in the menu under Details', (tester) async {
    await _pumpServers(tester, seeded: [_laptop, _codexBox]);

    String supporting(String id) => tester
        .widget<KitRow>(find.byKey(ValueKey('server-row-$id')))
        .supporting!
        .toPlainText();
    expect(supporting('laptop'), isNot(contains('laptop.example.net')));
    expect(supporting('laptop'), contains('OpenCode'));
    expect(supporting('codexbox'), isNot(contains('codex.example.net')));
    expect(supporting('codexbox'), isNot(contains('/work/app')));
    expect(supporting('codexbox'), contains('Codex'));

    final row = find.byKey(const ValueKey('server-row-codexbox'));
    await tester.longPress(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details').last);
    await tester.pumpAndSettle();
    expect(find.text('Build box details'), findsOneWidget);
    expect(find.textContaining('wss://codex.example.net'), findsOneWidget);
    expect(find.textContaining('/work/app'), findsOneWidget);
  });
}
