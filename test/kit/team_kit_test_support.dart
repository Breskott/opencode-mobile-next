import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import '../../tool/capture/fixtures.dart' show captureTheme;
import 'package:opencode_mobile/l10n/app_localizations.dart';

Future<void> pumpTeam(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: captureTheme(light: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Widget teamSample(
  String part, {
  KitTeamState state = KitTeamState.needsYou,
  VoidCallback? action,
}) {
  final items = state == KitTeamState.loading || state == KitTeamState.empty
      ? <KitTeamItem>[]
      : <KitTeamItem>[
          KitTeamItem(
            title: 'Data model',
            detail: 'Backend · Home PC',
            meta: 'App repo · 3 acceptance checks',
          ),
          KitTeamItem(
            title: 'Settings screen',
            detail: 'Frontend · after Data model',
            state: KitTeamState.running,
          ),
        ];
  final primary = KitAction(
    label: 'Approve and start',
    onPressed: action ?? () {},
  );
  const title = 'Milestone 2';
  final status = switch (state) {
    KitTeamState.empty => 'No work planned yet',
    KitTeamState.loading => 'Loading the latest plan',
    KitTeamState.running => 'Checking acceptance criteria · 4 min',
    KitTeamState.needsYou => 'Waiting for your review · 2 min',
    KitTeamState.stalled => 'No answer from Home PC yet · 3 min',
    KitTeamState.failed => 'The check could not finish. Retry the check.',
    KitTeamState.done => 'Accepted · 5 min ago',
    KitTeamState.stale => 'Last known · Home PC offline · 20 min ago',
  };
  switch (part) {
    case 'kit_plan_card':
      return KitPlanCard(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_phase_card':
      return KitPhaseCard(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_merge_queue':
      return KitMergeQueue(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_promote_card':
      return KitPromoteCard(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_digest':
      return KitDigest(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_timeline_day':
      return KitTimelineDay(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_server_lane':
      return KitServerLane(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'kit_project_row':
      return KitProjectRow(
        title: title,
        status: status,
        state: state,
        onPressed: action ?? () {},
        completed: 2,
        total: 5,
      );
    case 'kit_milestone_row':
      return KitMilestoneRow(
        title: title,
        status: status,
        state: state,
        onPressed: action ?? () {},
        completed: 2,
        total: 5,
      );
    case 'kit_findings_card':
      return KitFindingsCard(
        title: title,
        status: status,
        state: state,
        primary: primary,
        findings: state == KitTeamState.loading || state == KitTeamState.empty
            ? []
            : [
                const KitTeamFinding(
                  id: 'critical',
                  title: 'Preserve the saved draft',
                  severityLabel: 'Critical',
                  severity: KitFindingSeverity.critical,
                  detail: 'Criterion 1 · survives restart',
                ),
                KitTeamFinding(
                  id: '1',
                  title: 'Keep the saved choice after restart',
                  severityLabel: 'Major',
                  severity: KitFindingSeverity.major,
                  selected: true,
                  onChanged: (_) => action?.call(),
                ),
                const KitTeamFinding(
                  id: '2',
                  title: 'Explain the recovery action',
                  severityLabel: 'Minor',
                ),
              ],
      );
    default:
      throw ArgumentError(part);
  }
}
