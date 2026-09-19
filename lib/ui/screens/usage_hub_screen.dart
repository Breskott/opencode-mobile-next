import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_overview.dart';
import '../../state/usage_overview.dart';
import 'provider_quota_screen.dart';
import 'usage_screen.dart';

/// The two halves of Usage.
enum UsageSection { spent, remaining }

/// The one Usage screen: "Spent" (what the connected server reports it used)
/// and "Remaining" (what a provider account has left, with quota monitoring).
///
/// The sections are tabs, not one scroll. Spent is a long report (ranges,
/// charts, budgets) that would bury Remaining below several screens of
/// content, and each section loads, fails and refreshes on its own; a tab
/// keeps each one's pull-to-refresh and keeps Remaining one tap away.
///
/// A section the connection cannot serve is absent, and with only one section
/// left there is no tab bar at all.
class UsageHubScreen extends StatelessWidget {
  final ConnectionController controller;

  /// The section an entry point means (a quota alert opens Remaining).
  final UsageSection? initialSection;

  /// Test seams, handed to the sections unchanged.
  final UsageOverview? usageOverview;
  final ProviderQuotaOverview? quotaOverview;

  const UsageHubScreen({
    super.key,
    required this.controller,
    this.initialSection,
    this.usageOverview,
    this.quotaOverview,
  });

  /// The sections this connection can show, gated exactly as the two screens
  /// were: Spent needs usage statistics, Remaining needs a saved server.
  static List<UsageSection> sectionsFor(ConnectionController controller) => [
    if (controller.supportsUsageStatistics) UsageSection.spent,
    if (controller.profile != null) UsageSection.remaining,
  ];

  Widget _body(UsageSection section) => switch (section) {
    UsageSection.spent => UsageScreen(
      controller: controller,
      overview: usageOverview,
      embedded: true,
    ),
    UsageSection.remaining => ProviderQuotaScreen(
      controller: controller,
      overview: quotaOverview,
      embedded: true,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final sections = sectionsFor(controller);
    final title = Text(l10n.settingsHubGroupUsage);
    if (sections.length < 2) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: sections.isEmpty
            ? const SizedBox.shrink()
            : KeyedSubtree(
                key: ValueKey('usage-section-${sections.single.name}'),
                child: _body(sections.single),
              ),
      );
    }
    final initial = sections.indexOf(initialSection ?? sections.first);
    return DefaultTabController(
      length: sections.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          bottom: TabBar(
            tabs: [
              for (final section in sections)
                Tab(
                  key: ValueKey('usage-tab-${section.name}'),
                  // The default height clips the label at large text sizes.
                  height: MediaQuery.textScalerOf(context).scale(20) + 26,
                  text: switch (section) {
                    UsageSection.spent => l10n.usageSectionSpent,
                    UsageSection.remaining => l10n.usageSectionRemaining,
                  },
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final section in sections)
              KeyedSubtree(
                key: ValueKey('usage-section-${section.name}'),
                child: _body(section),
              ),
          ],
        ),
      ),
    );
  }
}
