// shared-shell-1 (wave 2a): the shell's shared widgets rebuilt from kit parts.
// These tests pin what the person sees for the map's "fix" items:
// settings-disconnect-sheet (counts only when something waits, the phone's
// own server says it keeps running) and embedded-connection-status-banner
// (Change server in the line's menu, Restart for the phone's own server,
// no attention tone for a lost connection), plus the kit-only rebuilds that
// change what is on screen (the swipe background, the local agent sheets).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_icon.dart';
import 'package:opencode_mobile/ui/kit/kit_status_line.dart';
import 'package:opencode_mobile/ui/widgets/confirm_sheet.dart';
import 'package:opencode_mobile/ui/widgets/connection_status_banner.dart';
import 'package:opencode_mobile/ui/widgets/safety_confirms.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends ProfileStore {
  _Store({required super.prefs});

  final _profile = ServerProfile(
    id: 'studio',
    name: 'Studio box',
    baseUrl: 'http://localhost:4096',
  );

  @override
  List<ServerProfile> get profiles => [_profile];

  @override
  String? get activeId => _profile.id;
}

class _Controller extends ConnectionController {
  _Controller(super.store) : super(isIsolated: true);

  int queued = 0;
  int drafts = 0;

  @override
  int queuedPromptCountForProfile(String profileID) => queued;

  @override
  int draftCountForProfile(String profileID) => drafts;
}

Future<_Controller> _controller() async {
  SharedPreferences.setMockInitialValues({});
  return _Controller(_Store(prefs: await SharedPreferences.getInstance()));
}

/// A host that builds [home] under a Scaffold, with a /servers
/// route so leaving for the server list is visible.
Widget _app({
  required Widget Function(BuildContext context) home,
  List<String>? pushed,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  onGenerateRoute: (settings) {
    if (settings.name == '/servers') {
      pushed?.add(settings.name!);
      return MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('servers-route')),
      );
    }
    return null;
  },
  home: Scaffold(body: Builder(builder: home)),
);

Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    _app(
      home: (context) {
        captured = context;
        return const SizedBox.expand();
      },
    ),
  );
  return captured;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('settings-disconnect-sheet', () {
    testWidgets('nothing waiting: no count line, the server keeps running', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final context = await _host(tester);
      unawaited(confirmDisconnectServer(context, controller));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect from Studio box?'), findsOneWidget);
      expect(
        find.textContaining('The server keeps running and nothing on it'),
        findsOneWidget,
      );
      // The old sheet said "No queued prompts. No unsent drafts." here.
      expect(find.textContaining('queued'), findsNothing);
      expect(find.textContaining('waiting to send'), findsNothing);
    });

    testWidgets('queued prompts and drafts are one sentence with the total', (
      tester,
    ) async {
      final controller = await _controller()
        ..queued = 2
        ..drafts = 1;
      addTearDown(controller.dispose);
      final context = await _host(tester);
      final answer = confirmDisconnectServer(context, controller);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '3 messages waiting to send stay on this phone until you connect '
          'again.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-disconnect')));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets("the phone's own server says it stays running on battery", (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final context = await _host(tester);
      unawaited(
        confirmDisconnectServer(context, controller, onThisPhone: true),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('OpenCode keeps running on this phone'),
        findsOneWidget,
      );
      expect(find.textContaining('using battery'), findsOneWidget);
    });
  });

  group('local agent sheets', () {
    testWidgets('stop says what keeps running and cancels with Keep running', (
      tester,
    ) async {
      final context = await _host(tester);
      final answer = confirmStopLocalAgents(context);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('stop-local-agents-confirm-sheet')),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep running'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('restart lists the conversations it would interrupt', (
      tester,
    ) async {
      final context = await _host(tester);
      final answer = confirmRestartLocalAgents(context, busyConversations: 2);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 conversations are generating'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-restart-local-agents')),
      );
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('remove keeps "Keep it" as its way out', (tester) async {
      final context = await _host(tester);
      final answer = confirmRemoveLocalAgents(context);
      await tester.pumpAndSettle();

      expect(find.text('Remove Claude Code from this phone?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });
  });

  group('embedded-connection-status-banner', () {
    Future<_Controller> lost() async =>
        (await _controller())..status = StreamStatus.disconnected;

    testWidgets('a lost connection is a failure line, not "needs you"', (
      tester,
    ) async {
      final controller = await lost();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(home: (_) => ConnectionStatusBanner(controller: controller)),
      );

      final line = tester.widget<KitStatusLine>(find.byType(KitStatusLine));
      expect(line.tone, AppStatusTone.failure);
      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Change server is one tap away in the line\'s menu', (
      tester,
    ) async {
      final controller = await lost();
      addTearDown(controller.dispose);
      final pushed = <String>[];
      await tester.pumpWidget(
        _app(
          home: (_) => ConnectionStatusBanner(controller: controller),
          pushed: pushed,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('kit-status-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change server'));
      await tester.pumpAndSettle();
      expect(pushed, ['/servers']);
      expect(find.text('servers-route'), findsOneWidget);
    });

    testWidgets('the phone\'s own server offers Restart after asking', (
      tester,
    ) async {
      final controller = await lost();
      addTearDown(controller.dispose);
      var restarts = 0;
      await tester.pumpWidget(
        _app(
          home: (_) => ConnectionStatusBanner(
            controller: controller,
            serverOnThisPhone: true,
            onRestartServer: () async => restarts++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("OpenCode on this phone isn't answering"), findsOne);
      await tester.tap(find.byKey(const ValueKey('connection-banner-restart')));
      await tester.pumpAndSettle();
      expect(find.text('Restart OpenCode on this phone?'), findsOneWidget);
      expect(restarts, 0);
      await tester.tap(
        find.byKey(const ValueKey('work-server-restart-confirm')),
      );
      await tester.pumpAndSettle();
      expect(restarts, 1);
    });

    testWidgets('without a restart hand-over the line keeps Try again', (
      tester,
    ) async {
      final controller = await lost();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          home: (_) => ConnectionStatusBanner(
            controller: controller,
            serverOnThisPhone: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('connection-banner-restart')),
        findsNothing,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  testWidgets('the swipe background is the kit delete glyph on surface2', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 400, height: 72, child: SwipeDeleteBackground()),
      ),
    );
    final icon = tester.widget<KitIcon>(find.byType(KitIcon));
    expect(icon.icon, AppIconography.delete);
    expect(
      find.descendant(
        of: find.byType(SwipeDeleteBackground),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });
}
