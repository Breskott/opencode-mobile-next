import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../feedback/bug_report.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../app_theme.dart';
import '../widgets/markdown.dart';
import '../widgets/product_states.dart';

/// Upstream OpenCode asks third-party projects that use the OpenCode name to
/// say plainly that they are not the official project. This is that statement,
/// and it is shown on every tab of this screen rather than buried in a
/// document the reader has to scroll.
const String nonAffiliationDisclaimer =
    'OpenCode Mobile is an independent community project. It is not built, '
    'maintained, endorsed by, or affiliated with the official OpenCode team.';

/// Build provenance is independent of the Android release channel. Desktop
/// readiness is still disclosed until those builds have hardware evidence.
const String buildProvenanceBody =
    'This independent app is built heavily with AI assistance. '
    'Android is the primary supported platform. Desktop builds are '
    'experimental and have not been hardware-tested. '
    'Report what breaks to help improve the app.';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.initialTab = 0});

  /// 0 opens Privacy, 1 opens Open source.
  final int initialTab;

  Future<List<String>> _loadDocuments(BuildContext context) => Future.wait([
    rootBundle.loadString(
      Localizations.localeOf(context).languageCode == 'ar'
          ? 'assets/l10n/PRIVACY.ar.md'
          : 'PRIVACY.md',
    ),
    rootBundle.loadString('THIRD_PARTY_NOTICES.md'),
  ]);

  @override
  Widget build(BuildContext context) {
    final largeLabels = AppTheme.stackedActions(context);
    final theme = Theme.of(context);
    final labelStyle =
        theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall;
    // Keep full-size labels and icon clearance rather than clipping text or
    // shrinking the user's accessibility setting into the stock 72dp tab.
    final tabHeight = largeLabels
        ? 48 +
              MediaQuery.textScalerOf(
                    context,
                  ).scale(labelStyle?.fontSize ?? AppTheme.bodyFontSize) *
                  (labelStyle?.height ?? 1.4)
        : null;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenCopy(context).e7SettingsUi96),
          actions: [
            IconButton(
              key: const ValueKey('about-report-bug'),
              tooltip: _screenCopy(context).e7SettingsDetailUi16,
              onPressed: () => unawaited(openBugReport(context)),
              icon: const Icon(AppIconography.bug),
            ),
          ],
          bottom: TabBar(
            isScrollable: largeLabels,
            tabAlignment: largeLabels ? TabAlignment.start : TabAlignment.fill,
            tabs: [
              Tab(
                height: tabHeight,
                icon: const Icon(Icons.privacy_tip_outlined),
                text: _screenCopy(context).e7SettingsDetailUi17,
              ),
              Tab(
                height: tabHeight,
                icon: const Icon(AppIconography.code),
                text: _screenCopy(context).e7SettingsDetailUi18,
              ),
            ],
          ),
        ),
        body: FutureBuilder<List<String>>(
          future: _loadDocuments(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingList(rows: 6);
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _screenCopy(context).e7SettingsInformationFailed,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final documents = snapshot.data!;
            return TabBarView(
              children: [
                _DocumentView(data: documents[0]),
                _DocumentView(data: documents[1], showAppSummary: true),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BuildData {
  const _BuildData({required this.package, required this.signer});

  final PackageInfo? package;
  final String? signer;
}

class _BuildProvenanceNotice extends StatelessWidget {
  const _BuildProvenanceNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIconography.experiments,
                  size: 18,
                  color: AppTheme.successOf(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _screenCopy(context).e7SettingsDetailUi19,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _screenCopy(context).e7SettingsAlphaBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const ValueKey('about-alpha-report-bug'),
                onPressed: () => unawaited(openBugReport(context)),
                icon: const Icon(AppIconography.bug, size: 18),
                label: Text(_screenCopy(context).e7SettingsDetailUi16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentView extends StatelessWidget {
  const _DocumentView({required this.data, this.showAppSummary = false});

  final String data;
  final bool showAppSummary;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _BuildIdentityCard(),
          const SizedBox(height: 16),
          const _NonAffiliationNotice(),
          const SizedBox(height: 16),
          // Scrolls with the document rather than sitting as fixed chrome:
          // at 2x text a fixed notice would squeeze (or overflow) the very
          // content the reader came for.
          const _BuildProvenanceNotice(),
          const SizedBox(height: 16),
          if (showAppSummary) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIconography.terminal, size: 34),
              // The desktop bundle is the same app, but naming it "for
              // Android" and promising local voice recognition describes a
              // build the reader is not running.
              title: Text(
                platformCapabilities.supportsVoice
                    ? _screenCopy(context).e7SettingsDetailUi20
                    : platformCapabilities.platform == TargetPlatform.iOS
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).iosAppTitle
                    : _screenCopy(context).e7SettingsDetailUi21,
              ),
              subtitle: Text(
                platformCapabilities.supportsVoice
                    ? _screenCopy(context).e7SettingsDetailUi22
                    : platformCapabilities.platform == TargetPlatform.iOS
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).iosRemoteSummary
                    : _screenCopy(context).e7SettingsDetailUi23,
              ),
            ),
            const Divider(height: 28),
          ],
          if (showAppSummary) ...[
            Text(_screenCopy(context).e7SettingsOriginalLicenses),
            const SizedBox(height: 12),
          ],
          MarkdownText(data),
        ],
      ),
    );
  }
}

class _BuildIdentityCard extends StatelessWidget {
  const _BuildIdentityCard();

  static const _platform = MethodChannel('oc/termux');

  Future<_BuildData> _load() async {
    PackageInfo? package;
    try {
      package = await PackageInfo.fromPlatform();
    } catch (_) {
      return const _BuildData(package: null, signer: null);
    }
    String? signer;
    if (platformCapabilities.supportsTermux) {
      try {
        signer = await _platform.invokeMethod<String>(
          'getSigningCertificateSha256',
        );
      } catch (_) {
        // Desktop and older Android builds do not expose a signer.
      }
    }
    return _BuildData(package: package, signer: signer);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BuildData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final package = data?.package;
        if (package == null) return const SizedBox.shrink();
        final signer = data?.signer;
        final l10n = AppLocalizations.of(context);
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutBuildVersion(package.version, package.buildNumber),
                ),
                const SizedBox(height: 4),
                Text(
                  package.packageName,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (signer != null && signer.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutSigningCertificate,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signer,
                    textDirection: TextDirection.ltr,
                    key: const ValueKey('about-signing-certificate'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NonAffiliationNotice extends StatelessWidget {
  const _NonAffiliationNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('about-non-affiliation'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIconography.info,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _screenCopy(context).e7SettingsNonAffiliation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

AppLocalizations _screenCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
