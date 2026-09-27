import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../platform/platform_capabilities.dart';
import '../ui/app_iconography.dart';
import '../ui/kit/kit_buttons.dart';
import '../ui/kit/kit_copy.dart';
import '../ui/kit/kit_notice.dart';
import '../ui/kit/kit_sheet.dart';

/// One first-party destination for "something is broken": the GitHub bug
/// report form, prefilled with the environment the report needs and nothing
/// else.
///
/// Privacy: the prefill carries the app version/build and a coarse platform
/// label only. No server URLs, directories, session identifiers, provider
/// names, model names, or transcripts are attached — the issue template
/// itself tells the filer to redact everything else before submitting.
const String bugReportRepoUrl =
    'https://github.com/Eslamasabry/opencode-mobile-next';

/// Coarse, user-facing label for the platform a report is coming from. The
/// desktop rows carry the alpha/contributor framing so a Windows report
/// arrives already contexted: that target builds but is not hardware-tested.
String bugReportPlatformLabel() {
  final capabilities = platformCapabilities;
  if (capabilities.isWeb) return 'Web (unsupported)';
  switch (capabilities.platform) {
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.windows:
      return 'Windows desktop (experimental — contributor-tested)';
    case TargetPlatform.linux:
      return 'Linux desktop (alpha)';
    case TargetPlatform.macOS:
      return 'macOS (untested)';
    case TargetPlatform.iOS:
      return 'iOS (untested)';
    case TargetPlatform.fuchsia:
      return 'Fuchsia (untested)';
  }
}

/// The issue-form URL with the fields the app can fill truthfully prefilled.
/// Field ids match `.github/ISSUE_TEMPLATE/bug_report.yml`; GitHub applies
/// query-parameter prefill to issue forms by id.
Future<Uri> buildBugReportUrl({PackageInfo? info}) async {
  PackageInfo packageInfo;
  try {
    // The plugin channel can fail or simply never answer (bare desktop
    // shells, plugin regressions). A bug report must never hang on it, so
    // after two seconds the report files with an unknown version instead.
    packageInfo =
        info ??
        await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2));
  } on Object {
    packageInfo = PackageInfo(
      appName: 'OpenCode Mobile',
      packageName: 'io.github.eslamasabry.opencode_mobile',
      version: 'unknown',
      buildNumber: '0',
    );
  }
  final version = '${packageInfo.version}+${packageInfo.buildNumber}';
  final platform = bugReportPlatformLabel();
  return Uri.parse('$bugReportRepoUrl/issues/new').replace(
    queryParameters: <String, String>{
      'template': 'bug_report.yml',
      'app-version': version,
      'what-happened':
          'What happened?\n\n\n'
          'Environment (prefilled by the app):\n'
          '- App: $version\n'
          '- Platform: $platform\n',
    },
  );
}

/// Opens the bug form in the system browser. When no handler exists (bare
/// desktop sessions without a browser default, plugin failures, tests), the
/// link is copied instead so the tap is never a dead end, and a sheet says
/// so ("Your browser didn't open, so the link to the bug form is copied…")
/// with a way to copy it again. Every external dependency is bounded or
/// guarded: a stuck plugin must not freeze the flow. Safe to call from
/// anywhere: the Navigator is captured before the first await, so the sheet
/// still shows when the calling page went away meanwhile.
///
/// States: opened (the browser shows the form; nothing in the app), not
/// opened (the copied-link sheet).
Future<void> openBugReport(
  BuildContext context, {
  Future<Uri> Function()? urlBuilder,
  Future<bool> Function(Uri url)? launcher,
}) async {
  final navigator = Navigator.maybeOf(context);
  final url = await (urlBuilder ?? buildBugReportUrl)();
  var opened = false;
  try {
    final launch =
        launcher ??
        (url) => launchUrl(url, mode: LaunchMode.externalApplication);
    opened = await launch(url).timeout(const Duration(seconds: 2));
  } catch (_) {
    opened = false;
  }
  if (opened) return;
  if (context.mounted) {
    _showCopiedLink(context, url.toString());
  } else if (navigator != null && navigator.mounted) {
    _showCopiedLink(navigator.context, url.toString());
  }
}

/// The not-opened state: copies [link] and says so in a sheet.
void _showCopiedLink(BuildContext context, String link) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  // Best-effort copy, never awaited: a dead clipboard channel must not hold
  // the fallback hostage. The sheet below is the guarantee, and it offers
  // the copy again.
  unawaited(
    KitCopy.copy(
      context,
      link,
      announcement: l10n.bugReportLinkCopied,
    ).catchError((Object _) {}),
  );
  unawaited(
    showKitSheet<void>(
      context,
      title: l10n.e7LibraryReportABug,
      icon: AppIconography.bug,
      body: (_) => KitNotice(
        icon: AppIconography.copy,
        message: l10n.bugReportBrowserDidNotOpen,
      ),
      primary: KitAction.copy(
        label: l10n.bugReportCopyLinkAgain,
        text: () => link,
      ),
    ),
  );
}
