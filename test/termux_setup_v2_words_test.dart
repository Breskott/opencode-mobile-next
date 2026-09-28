// slice-close-servers (review board closure, 2026-09-28), phone setup v2
// with Termux as the host — the owner's "Align with v2" and "Unify all
// installation into v2":
//
//  * termux-setup-connect-termux: Termux not answering says what to do in
//    plain words (no "unlock line"), and a denied permission's button names
//    where it goes ("Allow the permission in Settings").
//  * termux-setup-failed: a too-old Termux is a failed row whose own button
//    is "Get the current Termux" (through the link opener); back from the
//    download page it checks again. A script's own error is never a row's
//    words: the row says what stopped in plain words and the raw text is
//    under Details.
//  * termux-setup-unsupported: off Android the page is "Connect a server"
//    with the command to copy, no backticks and no "requires Termux".
//
// Fakes only.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_job_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_screen.dart'
    show termuxDownloadUrl;
import 'package:opencode_mobile/ui/setup_commands.dart';
import 'package:opencode_mobile/ui/widgets/setup_progress_view.dart';

import 'support/fake_setup_engine.dart';
import 'support/termux_channel_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _pump(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pump(tester);
}

void _resumeFromElsewhere(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// The progress view alone, for what a failed row says.
Widget _view(SetupProgress progress) => _app(
  Scaffold(
    body: SingleChildScrollView(
      child: SetupProgressView(
        progress: progress,
        components: FakeSetupEngine.fakeRegistry,
        onContinue: () {},
      ),
    ),
  ),
);

void _tall(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(412, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('the Termux host job', () {
    late TermuxChannelFixture termux;
    late FakeSetupEngine engine;
    final opened = <String>[];

    setUp(() {
      termux = TermuxChannelFixture()..install();
      engine = FakeSetupEngine();
      opened.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
    });

    Future<void> mount(WidgetTester tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          PhoneSetupTermuxJobScreen(
            engine: engine,
            firstSetup: true,
            openLink: (_, url) async => opened.add(url),
            openReady: (_) async {},
          ),
        ),
      );
      await _pump(tester);
    }

    testWidgets('Termux not answering says what to do, without jargon', (
      tester,
    ) async {
      termux.bridgeUnlocked = false;
      await mount(tester);
      expect(find.textContaining(_l10n.e7SetupTermuxNoAnswer), findsOneWidget);
      expect(find.textContaining('unlock line'), findsNothing);
      expect(find.textContaining('verify again'), findsNothing);
      expect(_key('phone-setup-termux-allow'), findsOneWidget);
    });

    testWidgets('a denied permission names where its button goes', (
      tester,
    ) async {
      termux
        ..permissionGranted = false
        ..permissionResult = false;
      await mount(tester);
      await _tap(tester, _key('phone-setup-termux-allow'));
      final settings = _key('phone-setup-termux-app-settings');
      expect(settings, findsOneWidget);
      expect(
        find.descendant(
          of: settings,
          matching: find.text('Allow the permission in Settings'),
        ),
        findsOneWidget,
      );
      expect(find.text('App settings'), findsNothing);
      // The row's words do not repeat the button.
      expect(find.textContaining('app settings'), findsNothing);
      await _tap(tester, settings);
      expect(termux.methods, contains('openAppSettings'));
    });

    testWidgets('a too-old Termux offers "Get the current Termux", and back '
        'from the download page it checks again', (tester) async {
      termux.protocolSupported = false;
      await mount(tester);
      final get = _key('phone-setup-termux-get-current');
      expect(get, findsOneWidget);
      expect(
        find.descendant(of: get, matching: find.text('Get the current Termux')),
        findsOneWidget,
      );
      // Continue setup stays the way on once it is installed.
      expect(_key('setup-progress-continue'), findsOneWidget);
      // Allowing waits until Termux is current: no step offered out of turn.
      expect(_key('phone-setup-termux-allow'), findsNothing);
      await _tap(tester, get);
      expect(opened, [termuxDownloadUrl]);
      expect(engine.runs, isEmpty);

      termux.protocolSupported = true;
      _resumeFromElsewhere(tester);
      await _pump(tester);
      expect(get, findsNothing);
      expect(engine.runs, hasLength(1));
    });
  });

  group('a failed row in any setup job', () {
    testWidgets('a script error is not the row\'s words; it is under Details', (
      tester,
    ) async {
      _tall(tester);
      const raw = 'dpkg: error processing package libc6 (--configure): exit 1';
      await tester.pumpWidget(
        _view(
          const SetupProgress(
            state: SetupState.failed,
            jobId: 'job-1',
            current: 'python',
            overall: .4,
            components: [
              ComponentProgress(id: 'linux', state: ComponentState.done),
              ComponentProgress(id: 'essentials', state: ComponentState.done),
              ComponentProgress(
                id: 'python',
                state: ComponentState.failed,
                stage: 'Installing Python',
                error: raw,
              ),
            ],
            logTail: 'Reading package lists\n',
          ),
        ),
      );
      await _pump(tester);
      expect(find.textContaining('dpkg'), findsNothing);
      expect(
        find.text(_l10n.setupProgressViewFailedDuring('Installing Python')),
        findsOneWidget,
      );
      await _tap(tester, _key('setup-progress-details'));
      expect(find.textContaining('dpkg: error processing'), findsOneWidget);
    });

    testWidgets('without a stage the row still says it stopped, in words', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _view(
          const SetupProgress(
            state: SetupState.failed,
            jobId: 'job-2',
            current: 'python',
            overall: .4,
            components: [
              ComponentProgress(id: 'linux', state: ComponentState.done),
              ComponentProgress(
                id: 'python',
                state: ComponentState.failed,
                error: 'exit status 100',
              ),
            ],
          ),
        ),
      );
      await _pump(tester);
      expect(find.textContaining('exit status'), findsNothing);
      expect(find.text(_l10n.setupProgressViewFailedStep), findsOneWidget);
    });

    testWidgets('a message the app knows is said in its own words', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _view(
          const SetupProgress(
            state: SetupState.failed,
            jobId: 'job-3',
            current: 'python',
            overall: .4,
            components: [
              ComponentProgress(
                id: 'python',
                state: ComponentState.failed,
                error: 'Could not install the Termux dependencies',
              ),
            ],
          ),
        ),
      );
      await _pump(tester);
      expect(find.text(_l10n.e7SetupDependenciesFailed), findsOneWidget);
    });

    testWidgets('a job that failed between components names where it '
        'stopped; the raw text is under Details', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _view(
          const SetupProgress(
            state: SetupState.failed,
            jobId: 'job-4',
            current: 'opencode',
            overall: .95,
            components: [
              ComponentProgress(id: 'linux', state: ComponentState.done),
              ComponentProgress(id: 'opencode', state: ComponentState.done),
            ],
            error: 'StateError: Bad state: socket closed (errno 104)',
          ),
        ),
      );
      await _pump(tester);
      expect(find.textContaining('errno'), findsNothing);
      expect(
        find.text(_l10n.setupProgressViewFailedAt('OpenCode')),
        findsOneWidget,
      );
      await _tap(tester, _key('setup-progress-details'));
      expect(find.textContaining('socket closed'), findsOneWidget);
    });
  });

  group('off Android', () {
    setUp(() {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      addTearDown(() => debugPlatformCapabilities = null);
    });

    testWidgets('the Termux job is "Connect a server" with the command', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_app(const PhoneSetupTermuxJobScreen()));
      await _pump(tester, frames: 20);
      expect(_key('phone-setup-termux-unsupported'), findsOneWidget);
      expect(find.text('Connect a server'), findsOneWidget);
      expect(find.text('Setup on this phone is Android only'), findsNothing);
      expect(find.textContaining('`'), findsNothing);
      expect(find.textContaining('requires Termux'), findsNothing);
      final block = tester.widget<KitCodeBlock>(find.byType(KitCodeBlock));
      expect(block.text, SetupCommands.pair);
      expect(block.copyable, isTrue);
      expect(find.text(_l10n.e7SetupAddServer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
