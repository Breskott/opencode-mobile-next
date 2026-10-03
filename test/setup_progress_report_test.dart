// P8.4 on phone setup v2 (wired in slice-P1.7): a failed setup row offers
// "Report this failure", which opens Report a problem with the job's log;
// a job that failed between components has no failed row, so the whole
// job's report sits on its log panel instead. Fakes only.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/app_diagnostics_screen.dart';
import 'package:opencode_mobile/ui/widgets/setup_progress_view.dart';

import 'support/fake_setup_engine.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Widget _app(SetupProgress progress) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: SetupProgressView(
        progress: progress,
        components: FakeSetupEngine.fakeRegistry,
        onContinue: () {},
      ),
    ),
  ),
);

/// Every line the report page's job log panel holds.
List<String> _panelLines(WidgetTester tester) => [
  for (final line
      in tester
          .widget<KitLogPanel>(
            find.ancestor(
              of: _key('report-problem-job-log'),
              matching: find.byType(KitLogPanel),
            ),
          )
          .lines
          .value)
    line.text,
];

void main() {
  setUp(() {
    // Report a problem reads the app's version and the device; nothing here
    // may wait on a channel.
    for (final channel in [
      'oc/voice',
      'dev.fluttercommunity.plus/package_info',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a failed row offers Report with the job\'s log', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(
        const SetupProgress(
          state: SetupState.failed,
          components: [
            ComponentProgress(id: 'linux', state: ComponentState.done),
            ComponentProgress(id: 'essentials', state: ComponentState.done),
            ComponentProgress(
              id: 'python',
              state: ComponentState.failed,
              error: 'apt exited 100',
            ),
          ],
          overall: 0.4,
          current: 'python',
          jobId: 'job-1',
          logTail: 'Reading package lists\nE: Unable to locate python3-venv',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('setup-progress-report-python'), findsOneWidget);
    // Only the failed row carries it, and the job-wide one is not repeated.
    expect(_key('setup-progress-report-linux'), findsNothing);
    expect(_key('setup-progress-report-job'), findsNothing);
    await tester.ensureVisible(_key('setup-progress-report-python'));
    await tester.tap(_key('setup-progress-report-python'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDiagnosticsScreen), findsOneWidget);
    expect(_panelLines(tester).last, 'E: Unable to locate python3-venv');
  });

  testWidgets('a job that failed between components reports the whole job '
      'from its log', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(
        const SetupProgress(
          state: SetupState.failed,
          components: [
            ComponentProgress(id: 'linux', state: ComponentState.done),
            ComponentProgress(id: 'opencode', state: ComponentState.done),
          ],
          overall: 0.95,
          jobId: 'job-2',
          error: 'OpenCode did not start',
          logTail: 'starting opencode\nserver exited 1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The log is folded under Details; the report is its header action.
    await tester.ensureVisible(_key('setup-progress-details'));
    await tester.tap(_key('setup-progress-details'));
    await tester.pumpAndSettle();
    expect(_key('setup-progress-report-job'), findsOneWidget);
    await tester.ensureVisible(_key('setup-progress-report-job'));
    await tester.tap(_key('setup-progress-report-job'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDiagnosticsScreen), findsOneWidget);
    expect(_panelLines(tester).last, 'server exited 1');
  });

  testWidgets('a running job offers no report', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      _app(
        const SetupProgress(
          state: SetupState.running,
          components: [
            ComponentProgress(id: 'linux', state: ComponentState.running),
          ],
          overall: 0.1,
          current: 'linux',
          jobId: 'job-3',
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('failed-job-report')), findsNothing);
    expect(_key('setup-progress-report-job'), findsNothing);
    expect(_key('setup-progress-report-linux'), findsNothing);
  });
}
