// Phone setup with Termux as the host of the v2 job (P1.2): the person
// steps as rows (checked again when the app comes back), then the same job
// the in-app setup runs, through the Termux engine. A job Termux kept
// running is followed, a stopped one waits on Continue setup (a kill mid-
// install resumes), a first setup ends on "name your first project" and
// added tools end back where they were added.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_job_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_screen.dart'
    show termuxDownloadUrl;

import 'support/fake_setup_engine.dart';
import 'support/termux_channel_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

SetupProgress _job(
  SetupState state, {
  String jobId = 'setup-1',
  String? current = 'node',
  List<String> adding = const [],
}) => SetupProgress(
  state: state,
  jobId: jobId,
  current: current,
  overall: .5,
  adding: adding,
  components: [
    for (final id in ['linux', 'essentials', 'python'])
      ComponentProgress(id: id, state: ComponentState.done),
    ComponentProgress(
      id: 'node',
      state: state == SetupState.done
          ? ComponentState.done
          : state == SetupState.running
          ? ComponentState.running
          : ComponentState.pending,
    ),
    ComponentProgress(
      id: 'opencode',
      state: state == SetupState.done
          ? ComponentState.done
          : ComponentState.pending,
    ),
  ],
);

void main() {
  late TermuxChannelFixture termux;
  late FakeSetupEngine engine;
  final opened = <String>[];
  final copied = <String>[];
  var readyOpened = 0;

  setUp(() {
    termux = TermuxChannelFixture()..install();
    engine = FakeSetupEngine();
    opened.clear();
    copied.clear();
    readyOpened = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  Future<void> pump(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    bool firstSetup = true,
    Set<String> adding = const {},
    Set<String>? selection,
  }) async {
    tester.view
      ..physicalSize = const Size(412, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PhoneSetupTermuxJobScreen(
                      engine: engine,
                      firstSetup: firstSetup,
                      adding: adding,
                      selection: selection,
                      openLink: (_, url) async => opened.add(url),
                      openReady: (_) async => readyOpened++,
                    ),
                  ),
                ),
                child: const Text('This phone'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('This phone'));
    await pump(tester);
  }

  void resumeFromElsewhere(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('without Termux the first row waits on the person; back from '
      'the download page it checks again and asks to allow Termux', (
    tester,
  ) async {
    termux
      ..termuxInstalled = false
      ..permissionGranted = false;
    await mount(tester);
    expect(find.text(_l10n.phoneSetupProgressTitle), findsOneWidget);
    expect(
      find.textContaining(_l10n.e7SetupInstallTermuxDetail),
      findsOneWidget,
    );
    final get = find.byKey(const ValueKey('phone-setup-termux-get'));
    await tester.ensureVisible(get);
    await tester.tap(get);
    await pump(tester);
    expect(opened, [termuxDownloadUrl]);
    expect(engine.runs, isEmpty);

    termux.termuxInstalled = true;
    resumeFromElsewhere(tester);
    await pump(tester);
    expect(
      find.byKey(const ValueKey('phone-setup-termux-allow')),
      findsOneWidget,
    );
    expect(find.textContaining(_l10n.phoneSetupTermuxAllowHow), findsOneWidget);
    expect(engine.runs, isEmpty);
  });

  testWidgets('Allow copies the unlock line and opens Termux; back from it, '
      'the v2 job runs the chosen tools in Termux as a first setup', (
    tester,
  ) async {
    termux.permissionGranted = false;
    await mount(tester, selection: {'python'});
    final allow = find.byKey(const ValueKey('phone-setup-termux-allow'));
    await tester.ensureVisible(allow);
    await tester.tap(allow);
    await pump(tester);
    expect(copied, [TermuxBridge.unlockCommand]);
    expect(
      termux.methods,
      containsAllInOrder(['requestRunCommandPermission', 'openTermux']),
    );
    expect(engine.runs, isEmpty, reason: 'nothing installs before return');

    resumeFromElsewhere(tester);
    await pump(tester);
    expect(termux.bridgeChecks, greaterThan(0));
    expect(engine.runs.single, {'python'});
    // A fresh Termux: the job keeps the app's default OpenCode.
    expect(engine.runParams.single, SetupJobParams.firstSetup);
    // The old manager never ran: the components are the v2 job's.
    expect(termux.launchCalls, 0);
  });

  testWidgets('an OpenCode Termux already runs stays the one the job keeps', (
    tester,
  ) async {
    termux.inventoryOutput =
        'ubuntu=installed\nversion=2.0.10\nruntime=opencode2\n';
    await mount(tester);
    expect(engine.runs, hasLength(1));
    expect(engine.runParams.single, {
      ...SetupJobParams.firstSetup,
      'opencode': {'runtime': 'opencode2'},
    });
  });

  testWidgets('a job Termux kept running while the app was gone is followed, '
      'never started again', (tester) async {
    engine.emit(_job(SetupState.running));
    await mount(tester);
    expect(engine.restores, 1);
    expect(engine.runs, isEmpty);
    expect(find.byKey(const Key('setup-progress-continue')), findsNothing);
    expect(find.text('Node.js'), findsOneWidget);
  });

  testWidgets('a job stopped part way (the app or Termux killed) waits on '
      'Continue setup, which runs the same components again', (tester) async {
    engine.emit(_job(SetupState.interrupted));
    await mount(tester);
    expect(engine.runs, isEmpty);
    final resume = find.byKey(const Key('setup-progress-continue'));
    expect(resume, findsOneWidget);
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    await pump(tester);
    expect(engine.runs.single, {
      'linux',
      'essentials',
      'python',
      'node',
      'opencode',
    });
    // The stopped job's own params (its OpenCode, first setup) carry over.
    expect(engine.runParams.single, isEmpty);
  });

  testWidgets('a first setup that finishes opens "name your first project"', (
    tester,
  ) async {
    engine.afterRun = _job(SetupState.running, jobId: 'setup-2');
    await mount(tester);
    expect(engine.runs, hasLength(1));
    engine.emit(_job(SetupState.done, jobId: 'setup-2', current: null));
    await pump(tester, frames: 2);
    expect(readyOpened, 1);
  });

  testWidgets('a job already done when the screen opened does not skip to '
      'the end: it runs again, and its checks skip what is there', (
    tester,
  ) async {
    engine.emit(_job(SetupState.done, jobId: 'old', current: null));
    await mount(tester);
    expect(readyOpened, 0);
    expect(engine.runs, hasLength(1));
  });

  testWidgets('Add tools adds only the new tools and ends back where it was '
      'opened', (tester) async {
    engine.afterRun = _job(
      SetupState.running,
      jobId: 'add-1',
      adding: const ['python'],
    );
    await mount(tester, firstSetup: false, adding: {'python'});
    expect(engine.runs.single, {'python'});
    expect(engine.runParams.single, SetupJobParams.adding(['python']));
    expect(find.text('Adding Python'), findsOneWidget);

    engine.emit(
      _job(SetupState.done, jobId: 'add-1', current: null, adding: ['python']),
    );
    await pump(tester, frames: 20);
    expect(readyOpened, 0);
    expect(find.byType(PhoneSetupTermuxJobScreen), findsNothing);
    expect(find.text('This phone'), findsOneWidget);
  });
}
