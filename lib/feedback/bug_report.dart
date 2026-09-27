import 'package:flutter/widgets.dart';

import '../ui/kit/kit_notice.dart' show KitReport;
import '../ui/screens/app_diagnostics_screen.dart' show openReportProblem;

export 'problem_report.dart' show bugReportPlatformLabel, bugReportRepoUrl;

/// "Report a problem" from anywhere: opens the one Report a problem page
/// (P8.2), which previews exactly what is sent and then opens the prefilled
/// GitHub form through `openExternalLink`, or copies or shares the report.
/// [error] attaches the failure that brought the person there.
///
/// Kept under this name for the failure states that already call it.
Future<void> openBugReport(BuildContext context, {KitReport? error}) =>
    openReportProblem(context, error: error);
