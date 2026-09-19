import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/widgets/first_run_choice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/first_run_path.dart';

Future<(ProfileStore, ConnectionController)> _state() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  await store.load();
  return (store, ConnectionController(store));
}

/// Presents saved profiles without touching the real secure-storage channel,
/// which is unmocked in widget tests and would hang a real upsert.
class _SeededStore extends ProfileStore {
  _SeededStore({
    required super.prefs,
    required this.seeded,
    this.activeProfile,
  });

  final String? activeProfile;

  @override
  String? get activeId => activeProfile;

  final List<ServerProfile> seeded;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(seeded);
}

Widget _app(
  ProfileStore store,
  ConnectionController controller, {
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  Map<String, WidgetBuilder> routes = const {},
}) => ProviderScope(
  overrides: [
    bootstrapProvider.overrideWithValue(AppBootstrap(store)),
    connProvider.overrideWithValue(controller),
  ],
  child: MaterialApp(
    builder: (context, child) => Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    routes: routes,
    home: const ServersScreen(),
  ),
);

/// The editor's own field list.
///
/// The rows live in a `ListView`, so a row below the fold is not merely
/// off-screen — it is not built at all. `ensureVisible` cannot reach it, and
/// neither can a drag aimed at `find.byType(Scrollable).last`, which is a
/// text field's *internal* scrollable rather than the list. Both used to look
/// like they worked only because nothing yet needed scrolling.
/// `.first` because every text field carries its own internal `Scrollable`
/// under the same list; the outermost one is the list itself.
final Finder _editorList = find
    .descendant(
      of: find.byKey(const ValueKey('server-profile-fields')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bare pasted addresses gain the right scheme', () {
    expect(
      normalizeServerProfileUrl('192.0.2.7:4096'),
      'https://192.0.2.7:4096',
    );
    expect(
      normalizeServerProfileUrl('localhost:4096'),
      'http://localhost:4096',
    );
    expect(normalizeServerProfileUrl('127.0.0.1'), 'http://127.0.0.1');
    expect(
      normalizeServerProfileUrl('box.tail1234.ts.net'),
      'https://box.tail1234.ts.net',
    );
    // Already-schemed and implausible values pass through untouched.
    expect(normalizeServerProfileUrl('https://host:4096'), 'https://host:4096');
    expect(normalizeServerProfileUrl('not a url'), 'not a url');
    expect(normalizeServerProfileUrl(''), '');
  });

  testWidgets('first run asks one question with exactly three choices', (
    tester,
  ) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));

    final welcome = find.byKey(const ValueKey('first-run-welcome'));
    expect(welcome, findsOneWidget);
    expect(find.text('Keep your work moving.'), findsOneWidget);
    expect(find.text('Where does your coding agent run?'), findsOneWidget);
    expect(
      find.descendant(of: welcome, matching: find.byType(FirstRunChoice)),
      findsNWidgets(3),
    );
    expect(find.text('On my computer'), findsOneWidget);
    expect(find.text('On this phone'), findsOneWidget);
    expect(find.text('Just show me'), findsOneWidget);
    // The value sentence leads, the question follows, and the choices keep
    // the plan's order.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Keep your work moving.'), lessThan(top('On my computer')));
    expect(
      top('Where does your coding agent run?'),
      lessThan(top('On my computer')),
    );
    expect(top('On my computer'), lessThan(top('On this phone')));
    expect(top('On this phone'), lessThan(top('Just show me')));
    // No product names before the person has chosen a path.
    for (final name in ['OpenCode 2', 'Termux', 'Tailscale', 'Codex']) {
      expect(
        find.descendant(of: welcome, matching: find.textContaining(name)),
        findsNothing,
        reason: name,
      );
    }
  });

  testWidgets('a platform without the phone path offers two choices', (
    tester,
  ) async {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    addTearDown(() => debugPlatformCapabilities = null);
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));

    expect(find.byType(FirstRunChoice), findsNWidgets(2));
    expect(find.text('On my computer'), findsOneWidget);
    expect(find.text('Just show me'), findsOneWidget);
    expect(find.text('On this phone'), findsNothing);
  });

  testWidgets('the doors that left the welcome are gone from it', (
    tester,
  ) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));

    expect(find.text('More setup options'), findsNothing);
    expect(find.byKey(const ValueKey('welcome-tailscale-card')), findsNothing);
    expect(find.byKey(const ValueKey('welcome-guide-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('connect-existing-opencode2')),
      findsNothing,
    );
    expect(find.text('External agents'), findsNothing);
    expect(find.byTooltip('Setup guide'), findsNothing);
    // About stays: notices must be readable before any connection exists.
    expect(find.byTooltip('About and open source notices'), findsOneWidget);
  });

  testWidgets('the phone choice and the demo open their destinations', (
    tester,
  ) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        store,
        controller,
        routes: {
          '/termux-setup': (_) => Scaffold(
            appBar: AppBar(title: const Text('Termux')),
            body: const Text('termux-route'),
          ),
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('welcome-choice-phone')));
    await tester.pumpAndSettle();
    expect(find.text('termux-route'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('welcome-choice-demo')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-choice-demo')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Offline demo'), findsOneWidget);
  });

  testWidgets('a saved profile keeps the ordinary server list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = _SeededStore(
      prefs: prefs,
      seeded: [
        ServerProfile(
          id: 'server-1',
          name: 'Workstation',
          baseUrl: 'https://box.example:4096',
          username: '',
          password: '',
        ),
      ],
    );
    final controller = ConnectionController(store);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));

    expect(find.byKey(const ValueKey('first-run-welcome')), findsNothing);
    expect(find.text('Workstation'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
    expect(find.text('Try demo'), findsOneWidget);
    await tester.tap(find.text('Try demo'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Offline demo'), findsOneWidget);
    expect(store.profiles.single.name, 'Workstation');
    await tester.tap(find.byTooltip('Exit demo'));
    await tester.pumpAndSettle();
    expect(find.text('Workstation'), findsOneWidget);
  });

  for (final active in [false, true]) {
    testWidgets(
      'editing ${active ? 'active' : 'inactive'} server names the save consequence',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final store = _SeededStore(
          prefs: await SharedPreferences.getInstance(),
          activeProfile: active ? 'work' : null,
          seeded: [
            ServerProfile(
              id: 'work',
              name: 'Workstation',
              baseUrl: 'https://box.example',
            ),
          ],
        );
        final controller = ConnectionController(store);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(store, controller));
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(
          find.text(active ? 'Save & connect' : 'Save changes'),
          findsOneWidget,
        );
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets('welcome fits 320dp at 2.5x text, ${direction.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (store, controller) = await _state();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(store, controller, textScale: 2.5, direction: direction),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final key in ['computer', 'phone', 'demo']) {
        final choice = find.byKey(ValueKey('welcome-choice-$key'));
        await tester.scrollUntilVisible(
          choice,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        final rect = tester.getRect(choice);
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(320), reason: key);
        expect(rect.height, greaterThanOrEqualTo(48), reason: key);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pasting a bare address into the editor fills the scheme', (
    tester,
  ) async {
    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      '192.0.2.7:4096',
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server-url-field')))
          .controller
          ?.text,
      'https://192.0.2.7:4096',
    );
  });

  testWidgets('test connection reports success with the server version', (
    tester,
  ) async {
    final previous = serverProbe;
    addTearDown(() => serverProbe = previous);
    final probed = <String>[];
    serverProbe = ({required baseUrl, username, password}) async {
      probed.add(baseUrl);
      return const ServerProbeResult.success('1.18.23');
    };

    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'box.example:4096',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('test-server-connection')),
      200,
      scrollable: _editorList,
    );
    await tester.tap(find.byKey(const ValueKey('test-server-connection')));
    await tester.pumpAndSettle();

    expect(probed, ['https://box.example:4096']);
    expect(find.byKey(const ValueKey('server-test-success')), findsOneWidget);
    expect(
      find.text('OpenCode 1 · 1.18.23 — limited feature set'),
      findsOneWidget,
    );
    expect(find.text('Connected — save to finish.'), findsOneWidget);
  });

  testWidgets('test connection explains a refused connection', (tester) async {
    final previous = serverProbe;
    addTearDown(() => serverProbe = previous);
    serverProbe = ({required baseUrl, username, password}) async =>
        const ServerProbeResult.failure(
          'The connection was refused. Is opencode serve running on that '
          'host and port?',
        );

    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'https://box.example:4096',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('test-server-connection')),
      200,
      scrollable: _editorList,
    );
    await tester.tap(find.byKey(const ValueKey('test-server-connection')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('server-test-failure')), findsOneWidget);
    expect(find.textContaining('refused'), findsOneWidget);

    // Editing any field clears the stale verdict.
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'https://box.example:4097',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('server-test-failure')), findsNothing);
  });

  testWidgets('timeout and refused verdicts point at the host setup guide', (
    tester,
  ) async {
    final previous = serverProbe;
    addTearDown(() => serverProbe = previous);
    serverProbe = ({required baseUrl, username, password}) async =>
        const ServerProbeResult.failure(
          'The connection was refused. Is opencode serve running on that '
          'host and port?',
          suggestsMissingServer: true,
        );

    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        store,
        controller,
        routes: {
          '/guide': (_) => Scaffold(
            appBar: AppBar(title: const Text('Guide')),
            body: const Text('guide-route'),
          ),
        },
      ),
    );
    await openFirstRunConnect(tester);

    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'https://box.example:4096',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('test-server-connection')),
      200,
      scrollable: _editorList,
    );
    await tester.tap(find.byKey(const ValueKey('test-server-connection')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('server-test-failure')), findsOneWidget);
    expect(find.textContaining('No server there yet?'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('server-test-guide')),
      200,
      scrollable: _editorList,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('server-test-guide')));
    await tester.pumpAndSettle();
    expect(find.text('guide-route'), findsOneWidget);
  });

  testWidgets('a DNS failure verdict stays about the address, not the server', (
    tester,
  ) async {
    final previous = serverProbe;
    addTearDown(() => serverProbe = previous);
    serverProbe = ({required baseUrl, username, password}) async =>
        const ServerProbeResult.failure(
          'That host name could not be found. Check the address spelling.',
        );

    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'https://box.exampel:4096',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('test-server-connection')),
      200,
      scrollable: _editorList,
    );
    await tester.tap(find.byKey(const ValueKey('test-server-connection')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('server-test-failure')), findsOneWidget);
    expect(find.textContaining('Check the address spelling'), findsOneWidget);
    expect(find.textContaining('No server there yet?'), findsNothing);
  });

  testWidgets('an invalid url never reaches the probe', (tester) async {
    final previous = serverProbe;
    addTearDown(() => serverProbe = previous);
    var calls = 0;
    serverProbe = ({required baseUrl, username, password}) async {
      calls += 1;
      return const ServerProbeResult.success(null);
    };

    final (store, controller) = await _state();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(store, controller));
    await openFirstRunConnect(tester);

    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'ftp://box.example',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('test-server-connection')),
      200,
      scrollable: _editorList,
    );
    await tester.tap(find.byKey(const ValueKey('test-server-connection')));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(
      find.text('Server URLs must use https://, or http:// for local Termux.'),
      findsOneWidget,
    );
  });
}
