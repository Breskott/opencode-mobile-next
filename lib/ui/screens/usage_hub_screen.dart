import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_overview.dart';
import '../../state/usage_overview.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import 'provider_quota_screen.dart';
import 'usage_refresh_slot.dart';
import 'usage_screen.dart';

/// The two halves of Usage.
enum UsageSection { spent, remaining }

/// The one Usage screen: "Spent" (what the connected server reports it used)
/// and "Remaining" (what a provider account has left, with quota monitoring).
///
/// The sections are tabs, not one scroll. Spent is a long report (ranges,
/// charts, budgets) that would bury Remaining below several screens of
/// content, and each section loads, fails and refreshes on its own (each
/// has its own loading bar and pull to refresh); a tab keeps Remaining one
/// tap away.
///
/// A section the connection cannot serve is absent, and with only one section
/// left there is no tab strip at all.
///
/// The top bar holds one Refresh, for the active section ("Refresh spending"
/// or "Refresh remaining usage"); the sections offer it through a
/// [UsageRefreshSlot] instead of an icon of their own.
class UsageHubScreen extends StatefulWidget {
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

  @override
  State<UsageHubScreen> createState() => _UsageHubScreenState();
}

class _UsageHubScreenState extends State<UsageHubScreen> {
  /// The chosen section, by name, so a section that comes or goes keeps the
  /// person on the one they chose.
  UsageSection? _chosen;

  final _slots = {
    for (final section in UsageSection.values) section: UsageRefreshSlot(),
  };

  @override
  void initState() {
    super.initState();
    _chosen = widget.initialSection;
  }

  @override
  void dispose() {
    for (final slot in _slots.values) {
      slot.dispose();
    }
    super.dispose();
  }

  /// Refresh for the active section, when it has one now.
  List<KitAction> _refresh(AppLocalizations l10n, UsageSection section) {
    final slot = _slots[section]!;
    if (!slot.visible) return const [];
    return [
      KitAction(
        key: ValueKey(switch (section) {
          UsageSection.spent => 'refresh-usage',
          UsageSection.remaining => 'quota-refresh',
        }),
        label: switch (section) {
          UsageSection.spent => l10n.usageRefreshSpending,
          UsageSection.remaining => l10n.quotaRefresh,
        },
        icon: AppIconography.retry,
        onPressed: slot.onRefresh,
        disabledReason: slot.disabledReason,
      ),
    ];
  }

  Widget _body(UsageSection section) => KeyedSubtree(
    key: ValueKey('usage-section-${section.name}'),
    child: switch (section) {
      UsageSection.spent => UsageScreen(
        controller: widget.controller,
        overview: widget.usageOverview,
        embedded: true,
        refreshSlot: _slots[UsageSection.spent],
      ),
      UsageSection.remaining => ProviderQuotaScreen(
        controller: widget.controller,
        overview: widget.quotaOverview,
        embedded: true,
        refreshSlot: _slots[UsageSection.remaining],
      ),
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(_slots.values.toList()),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final sections = UsageHubScreen.sectionsFor(widget.controller);
    if (sections.isEmpty) {
      final topBar = KitTopBar(title: l10n.settingsHubGroupUsage);
      // The Settings row is absent in this case; a deep link or search
      // result that still lands here says why instead of a blank page.
      return KitScreen(
        topBar: topBar,
        body: KitStateView(
          key: const ValueKey('usage-hub-unavailable'),
          icon: AppIconography.usage,
          title: l10n.usageHubUnavailableTitle,
          body: l10n.usageHubUnavailableBody,
        ),
      );
    }
    if (sections.length == 1) {
      return KitScreen(
        topBar: KitTopBar(
          title: l10n.settingsHubGroupUsage,
          actions: _refresh(l10n, sections.single),
        ),
        body: _body(sections.single),
      );
    }
    final found = sections.indexOf(_chosen ?? sections.first);
    final index = found < 0 ? 0 : found;
    final topBar = KitTopBar(
      title: l10n.settingsHubGroupUsage,
      actions: _refresh(l10n, sections[index]),
    );
    return KitScreen(
      topBar: topBar,
      // The strip lines up with the sections' reading column on wide
      // windows instead of sitting at the window's edge.
      width: KitScreenWidth.reading,
      body: KitTabSwitcher.tabs(
        semanticsLabel: l10n.settingsHubGroupUsage,
        index: index,
        onSelected: (next) => setState(() => _chosen = sections[next]),
        tabs: [
          for (final section in sections)
            KitTab(
              key: ValueKey('usage-tab-${section.name}'),
              label: switch (section) {
                UsageSection.spent => l10n.usageSectionSpent,
                UsageSection.remaining => l10n.usageSectionRemaining,
              },
            ),
        ],
        children: [for (final section in sections) _body(section)],
      ),
    );
  }
}
