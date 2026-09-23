import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_progress_screen.dart';
import 'package:opencode_mobile/ui/widgets/setup_progress_view.dart';
import 'package:opencode_mobile/ui/widgets/terminal_view.dart';

import 'support/fake_setup_engine.dart';

const _ids = ['linux', 'essentials', 'python', 'node', 'opencode'];

/// A job of the fake registry's five components: those in [done] finished,
/// [current] as given, the rest pending.
SetupProgress _job({
  SetupState state = SetupState.running,
  double overall = .4,
  int? eta,
  Set<String> done = const {},
  ComponentProgress? current,
  String? error,
  String log = '',
  List<String> ids = _ids,
}) => SetupProgress(
  state: state,
  overall: overall,
  etaSeconds: eta,
  error: error,
  logTail: log,
  current: current?.id,
  components: [
    for (final id in ids)
      if (id == current?.id)
        current!
      else if (done.contains(id))
        ComponentProgress(
          id: id,
          state: ComponentState.done,
          version: id == 'linux' ? '24.04.5' : null,
        )
      else
        ComponentProgress(id: id, state: ComponentState.pending),
  ],
);

const _nodeDownloading = ComponentProgress(
  id: 'node',
  state: ComponentState.running,
  stage: 'Downloading',
  bytesDone: 18000000,
  bytesTotal: 30000000,
);

class _Harness {
  final engine = FakeSetupEngine();
  final navigatorKey = GlobalKey<NavigatorState>();
  var readyOpened = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  SetupProgress? initial,
  double textScale = 1,
  bool rtl = false,
  bool reduceMotion = false,
  Locale locale = const Locale('en'),
  bool pushReady = true,
  bool firstSetup = true,
}) async {
  final h = _Harness();
  if (initial != null) h.engine.emit(initial);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: h.navigatorKey,
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: Directionality(
          textDirection: rtl || locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: const Scaffold(body: Text('Home')),
    ),
  );
  h.navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => PhoneSetupProgressScreen(
        engine: h.engine,
        firstSetup: firstSetup,
        openReady: (context) async {
          h.readyOpened++;
          if (!pushReady) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Ready screen')),
            ),
          );
        },
      ),
    ),
  );
  await _settle(tester);
  return h;
}

/// Spinners and indeterminate lines never settle, so time is stepped
/// instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

double? _barValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(
      find.byKey(const Key('setup-progress-overall')),
    )
    .value;

void main() {
  group('rows show only real numbers', () {
    testWidgets('bytes as "18 of 30 MB" with the stage', (tester) async {
      await _pump(
        tester,
        initial: _job(done: {'linux', 'essentials'}, current: _nodeDownloading),
      );
      expect(find.text('Downloading · 18 of 30 MB'), findsOneWidget);
      // A measured row has no indeterminate line.
      expect(find.byKey(const Key('setup-progress-stage-line')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('percent as "62%"', (tester) async {
      await _pump(
        tester,
        initial: _job(
          done: {'linux'},
          current: const ComponentProgress(
            id: 'essentials',
            state: ComponentState.running,
            stage: 'Installing packages',
            percent: 62.7,
          ),
        ),
      );
      // Rounded down: never more than the tool reported.
      expect(find.text('Installing packages · 62%'), findsOneWidget);
    });

    testWidgets('a stage alone shows its label and an indeterminate line', (
      tester,
    ) async {
      await _pump(
        tester,
        initial: _job(
          done: {'linux', 'essentials', 'python', 'node'},
          current: const ComponentProgress(
            id: 'opencode',
            state: ComponentState.running,
            stage: 'Installing OpenCode',
          ),
        ),
      );
      expect(find.text('Installing OpenCode'), findsOneWidget);
      final line = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('setup-progress-stage-line')),
      );
      expect(line.value, isNull);
      // No invented figure anywhere in the rows.
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining(' MB'), findsNothing);
    });

    testWidgets('a done row shows its version muted with a check', (
      tester,
    ) async {
      await _pump(
        tester,
        initial: _job(done: {'linux'}, current: _nodeDownloading),
      );
      final version = tester.widget<Text>(find.text('24.04.5'));
      final theme = Theme.of(tester.element(find.text('24.04.5')));
      expect(version.style?.color, AppTheme.mutedOf(theme));
      expect(find.text('Linux base'), findsOneWidget);
      expect(find.text('Git and SSH'), findsOneWidget);
    });

    testWidgets('byte formatting rounds done down and keeps the unit', (
      tester,
    ) async {
      expect(SetupProgressView.formatBytePair(18999999, 30000000), (
        '18',
        '30 MB',
      ));
      expect(SetupProgressView.formatBytePair(950000, 2500000), (
        '0.9',
        '2.5 MB',
      ));
      expect(SetupProgressView.formatBytePair(500, 800), ('500', '800 B'));
      expect(SetupProgressView.formatBytePair(40, 20), ('20', '20 B'));
    });
  });

  group('failure', () {
    testWidgets('says the stage and the reason, red bar, Continue setup', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        initial: _job(
          state: SetupState.failed,
          done: {'linux', 'essentials', 'python'},
          current: const ComponentProgress(
            id: 'node',
            state: ComponentState.failed,
            stage: 'Checking the download',
            error: 'The file was damaged',
          ),
        ),
      );
      expect(
        find.text('Checking the download: The file was damaged'),
        findsOneWidget,
      );
      expect(find.text("Setup didn't finish"), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('setup-progress-overall')),
      );
      final theme = Theme.of(tester.element(find.text('Node.js')));
      expect(bar.color, theme.colorScheme.error.withValues(alpha: .75));
      expect(find.byKey(const Key('setup-progress-cancel')), findsNothing);
      expect(find.text('Show details'), findsOneWidget);

      await tester.tap(find.text('Continue setup'));
      await tester.pump();
      expect(h.engine.runs, [_ids.toSet()]);
    });

    testWidgets('network errors ask to reconnect', (tester) async {
      await _pump(
        tester,
        initial: _job(
          state: SetupState.failed,
          done: {'linux', 'essentials', 'python'},
          current: const ComponentProgress(
            id: 'node',
            state: ComponentState.failed,
            stage: 'Downloading Node.js 24',
            error: 'Exit code 6',
          ),
          log: 'curl: (6) Could not resolve host: nodejs.org\n',
        ),
      );
      expect(
        find.text("No internet connection — Continue when you're back online"),
        findsOneWidget,
      );
      expect(find.textContaining('Exit code 6'), findsNothing);
    });

    testWidgets('a failure between components still says why', (tester) async {
      await _pump(
        tester,
        initial: _job(
          state: SetupState.failed,
          overall: 1,
          done: _ids.toSet(),
          error: 'OpenCode did not start',
        ),
      );
      expect(find.text('OpenCode did not start'), findsOneWidget);
      expect(find.text('Continue setup'), findsOneWidget);
    });

    testWidgets('interrupted and cancelled jobs offer Continue setup', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        initial: _job(state: SetupState.interrupted, done: {'linux'}),
      );
      expect(
        find.text("Setup was interrupted. What's finished is kept."),
        findsOneWidget,
      );
      h.engine.emit(_job(state: SetupState.cancelled, done: {'linux'}));
      await _settle(tester);
      expect(
        find.text("Setup stopped. What's finished stays installed."),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue setup'));
      await tester.pump();
      expect(h.engine.runs.single, _ids.toSet());
    });
  });

  group('overall bar', () {
    testWidgets('eases and never goes backwards within a job', (tester) async {
      final h = await _pump(
        tester,
        initial: _job(overall: .5, current: _nodeDownloading),
      );
      expect(_barValue(tester), closeTo(.5, 1e-9));

      h.engine.emit(_job(overall: .8, current: _nodeDownloading));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-ease: moving, not jumped.
      expect(_barValue(tester), inExclusiveRange(.5, .8));
      await _settle(tester);
      expect(_barValue(tester), closeTo(.8, 1e-9));

      h.engine.emit(_job(overall: .6, current: _nodeDownloading));
      await _settle(tester);
      expect(_barValue(tester), closeTo(.8, 1e-9));

      // A different job (only Python, from "Add tools") starts over.
      h.engine.emit(
        _job(
          overall: .1,
          ids: const ['python'],
          current: const ComponentProgress(
            id: 'python',
            state: ComponentState.running,
            stage: 'Installing packages',
          ),
        ),
      );
      await tester.pump();
      expect(_barValue(tester), closeTo(.1, 1e-9));
    });

    testWidgets('a re-run after done starts over', (tester) async {
      final h = await _pump(
        tester,
        initial: _job(overall: .9, current: _nodeDownloading),
        pushReady: false,
      );
      h.engine.emit(
        _job(state: SetupState.done, overall: 1, done: _ids.toSet()),
      );
      await _settle(tester);
      expect(_barValue(tester), closeTo(1, 1e-9));
      h.engine.emit(_job(overall: .2, current: _nodeDownloading));
      await tester.pump();
      expect(_barValue(tester), closeTo(.2, 1e-9));
    });
  });

  group('time left', () {
    testWidgets('only when the engine gives one', (tester) async {
      final h = await _pump(tester, initial: _job(current: _nodeDownloading));
      expect(find.text('Getting started…'), findsOneWidget);
      expect(find.textContaining('min left'), findsNothing);

      h.engine.emit(_job(eta: 130, current: _nodeDownloading));
      await tester.pump();
      expect(find.text('~2 min left'), findsOneWidget);

      h.engine.emit(_job(eta: 40, current: _nodeDownloading));
      await tester.pump();
      expect(find.text('Less than a minute'), findsOneWidget);
    });
  });

  group('screen', () {
    testWidgets('restores on open and shows the title and note', (
      tester,
    ) async {
      final h = await _pump(tester, initial: _job(current: _nodeDownloading));
      expect(h.engine.restores, 1);
      expect(find.text('Setting up OpenCode on this phone'), findsOneWidget);
      expect(
        find.text("You can leave the app. We'll notify you when it's ready."),
        findsOneWidget,
      );
    });

    testWidgets('Cancel confirms before stopping', (tester) async {
      final h = await _pump(tester, initial: _job(current: _nodeDownloading));
      await tester.tap(find.byKey(const Key('setup-progress-cancel')));
      await _settle(tester);
      expect(find.text('Stop setup?'), findsOneWidget);
      expect(find.text("What's finished stays installed."), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await _settle(tester);
      expect(h.engine.cancels, 0);

      await tester.tap(find.byKey(const Key('setup-progress-cancel')));
      await _settle(tester);
      await tester.tap(
        find.byKey(const Key('phone-setup-progress-stop-confirm')),
      );
      await _settle(tester);
      expect(h.engine.cancels, 1);
    });

    testWidgets('done hands over to screen C, replacing this screen', (
      tester,
    ) async {
      final h = await _pump(tester, initial: _job(current: _nodeDownloading));
      expect(h.readyOpened, 0);
      h.engine.emit(
        _job(state: SetupState.done, overall: 1, done: _ids.toSet()),
      );
      await _settle(tester);
      expect(h.readyOpened, 1);
      expect(find.text('Ready screen'), findsOneWidget);

      // Back from C skips the finished progress screen.
      h.navigatorKey.currentState!.pop();
      await _settle(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(PhoneSetupProgressScreen), findsNothing);

      // Later emits do not open C again.
      h.engine.emit(
        _job(state: SetupState.done, overall: 1, done: _ids.toSet()),
      );
      await _settle(tester);
      expect(h.readyOpened, 1);
    });

    testWidgets('an update or added tools end here, then close', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        initial: _job(current: _nodeDownloading),
        firstSetup: false,
      );
      h.engine.emit(
        _job(state: SetupState.done, overall: 1, done: _ids.toSet()),
      );
      await _settle(tester);
      // The finished list stays for a moment, never screen C.
      expect(h.readyOpened, 0);
      expect(find.byType(PhoneSetupProgressScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1300));
      await _settle(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(PhoneSetupProgressScreen), findsNothing);
    });

    testWidgets('Back while running just leaves; setup is not cancelled', (
      tester,
    ) async {
      final h = await _pump(tester, initial: _job(current: _nodeDownloading));
      await tester.pageBack();
      await _settle(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(h.engine.cancels, 0);
    });
  });

  testWidgets('Show details opens the log and follows it', (tester) async {
    final h = await _pump(
      tester,
      initial: _job(
        current: _nodeDownloading,
        log: 'Get:1 http://ports.ubuntu.com noble InRelease\n',
      ),
    );
    expect(find.byType(TerminalView), findsNothing);
    await tester.tap(find.text('Show details'));
    await _settle(tester);
    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.textContaining('noble InRelease'), findsOneWidget);

    final lines = [for (var i = 0; i < 80; i++) 'line $i'].join('\n');
    h.engine.emit(_job(current: _nodeDownloading, log: lines));
    await _settle(tester);
    // Tail-first: the newest line is on screen, the oldest folded away.
    expect(find.textContaining('line 79'), findsOneWidget);
    expect(find.textContaining('line 0\n'), findsNothing);

    await tester.tap(find.text('Hide details'));
    await _settle(tester);
    expect(find.byType(TerminalView), findsNothing);
  });

  group('layout', () {
    for (final rtl in [false, true]) {
      testWidgets('320dp at 2.5x text fits (${rtl ? 'RTL' : 'LTR'})', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = await _pump(
          tester,
          textScale: 2.5,
          rtl: rtl,
          initial: _job(
            done: {'linux', 'essentials'},
            current: _nodeDownloading,
          ),
        );
        expect(tester.takeException(), isNull);
        final cancel = find.byKey(const Key('setup-progress-cancel'));
        await tester.ensureVisible(cancel);
        await _settle(tester);
        expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
        expect(
          tester
              .getSize(find.byKey(const Key('setup-progress-details')))
              .height,
          greaterThanOrEqualTo(48),
        );

        h.engine.emit(
          _job(
            state: SetupState.failed,
            done: {'linux', 'essentials', 'python'},
            current: const ComponentProgress(
              id: 'node',
              state: ComponentState.failed,
              stage: 'Downloading Node.js 24',
              error: 'The download stopped halfway through',
            ),
            log: 'curl: (56) Recv failure\n',
          ),
        );
        await _settle(tester);
        await tester.tap(find.text('Show details'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        final cont = find.text('Continue setup');
        await tester.ensureVisible(cont);
        expect(
          tester
              .getSize(find.byKey(const Key('setup-progress-continue')))
              .height,
          greaterThanOrEqualTo(48),
        );
      });
    }

    testWidgets('RTL puts the detail on the leading-left side', (tester) async {
      await _pump(tester, rtl: true, initial: _job(current: _nodeDownloading));
      final title = tester.getRect(find.text('Node.js'));
      final detail = tester.getRect(find.text('Downloading · 18 of 30 MB'));
      expect(detail.right, lessThan(title.left));
    });

    testWidgets('LTR puts the detail on the right', (tester) async {
      await _pump(tester, initial: _job(current: _nodeDownloading));
      final title = tester.getRect(find.text('Node.js'));
      final detail = tester.getRect(find.text('Downloading · 18 of 30 MB'));
      expect(detail.left, greaterThan(title.right));
    });

    testWidgets('Arabic at 2.5x on 320dp', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        textScale: 2.5,
        locale: const Locale('ar'),
        initial: _job(eta: 200, done: {'linux'}, current: _nodeDownloading),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('جارٍ إعداد OpenCode على هذا الهاتف'), findsOneWidget);
      expect(find.text('Downloading · 18 من 30 MB'), findsOneWidget);
    });
  });

  testWidgets('reduce motion changes instantly and draws no spinners', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      reduceMotion: true,
      initial: _job(overall: .3, current: _nodeDownloading),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    h.engine.emit(_job(overall: .7, current: _nodeDownloading));
    await tester.pump();
    expect(_barValue(tester), closeTo(.7, 1e-9));

    h.engine.emit(
      _job(
        overall: .8,
        done: {'linux', 'essentials', 'python', 'node'},
        current: const ComponentProgress(
          id: 'opencode',
          state: ComponentState.running,
          stage: 'Installing OpenCode',
        ),
      ),
    );
    // Everything settles: no looping animation is left running.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setup-progress-stage-line')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('the running row is a live region labelled by its stage', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, initial: _job(current: _nodeDownloading));
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('setup-progress-row-node')),
      ),
      isSemantics(
        label: 'Node.js, in progress, Downloading',
        value: '18 of 30 MB',
        isLiveRegion: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('setup-progress-row-linux')),
      ),
      isSemantics(label: 'Linux base, waiting'),
    );
    semantics.dispose();
  });
}
