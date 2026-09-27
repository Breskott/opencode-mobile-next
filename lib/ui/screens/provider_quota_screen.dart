import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/provider_quota.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_monitor.dart' show QuotaMonitorTarget;
import '../../state/provider_quota_overview.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../widgets/phone_server_card.dart' show serverDisplayName;
import '../widgets/quota_monitor_section.dart';
import 'settings_screen.dart' show NotificationsSettingsScreen;
import 'usage_refresh_slot.dart';

// revamp: redesign (slice-P5.4). Rebuilt from kit parts in today's layout;
// the per-provider answer rows, the agent-driven collector setup and the
// one-alert-per-provider switch arrive with slice-P5.4.
class ProviderQuotaScreen extends StatefulWidget {
  final ConnectionController controller;
  final ProviderQuotaOverview? overview;

  /// True as the "Remaining" section of the Usage screen, which already
  /// supplies the top bar.
  final bool embedded;

  /// Inside Usage, where this section's Refresh goes: the Usage top bar
  /// holds one Refresh for the active tab.
  final UsageRefreshSlot? refreshSlot;

  const ProviderQuotaScreen({
    super.key,
    required this.controller,
    this.overview,
    this.embedded = false,
    this.refreshSlot,
  });

  @override
  State<ProviderQuotaScreen> createState() => _ProviderQuotaScreenState();
}

class _ProviderQuotaScreenState extends State<ProviderQuotaScreen> {
  late ProviderQuotaOverview _overview;
  final _scroll = ScrollController();
  bool _trusted = false;

  /// Saving a monitored source failed; said on the page beside the action
  /// that failed (a notice, not a toast: G1).
  bool _monitorSaveFailed = false;

  /// Monitoring is being turned on: the row says so until it is saved.
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _overview = widget.overview ?? ProviderQuotaOverview(widget.controller);
  }

  @override
  void didUpdateWidget(ProviderQuotaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller &&
        oldWidget.overview == widget.overview) {
      return;
    }
    if (oldWidget.overview == null) {
      _overview.dispose();
    }
    _overview = widget.overview ?? ProviderQuotaOverview(widget.controller);
    _trusted = false;
    _monitorSaveFailed = false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.overview == null) {
      _overview.dispose();
    }
    super.dispose();
  }

  /// The collector's origin, or null when there is no usable saved server.
  String? _origin() {
    final uri = Uri.tryParse(widget.controller.profile?.baseUrl ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.origin;
  }

  String _failure(ProviderQuotaFailure failure, AppLocalizations l10n) =>
      switch (failure.kind) {
        QuotaFailureKind.collectorAuth => l10n.quotaCollectorAuth,
        QuotaFailureKind.unsupported => l10n.quotaCollectorMissing,
        QuotaFailureKind.unavailable => l10n.quotaUnavailable,
        QuotaFailureKind.invalidResponse => l10n.quotaInvalidResponse,
      };

  String _status(ProviderQuotaStatus status, AppLocalizations l10n) =>
      switch (status) {
        ProviderQuotaStatus.ok => l10n.quotaAccountUnverified,
        ProviderQuotaStatus.unconfigured => l10n.quotaUnconfigured,
        ProviderQuotaStatus.unsupported => l10n.quotaProviderUnsupported,
        ProviderQuotaStatus.authRequired => l10n.quotaProviderAuth,
        ProviderQuotaStatus.rateLimited => l10n.quotaRateLimited,
        ProviderQuotaStatus.unavailable => l10n.quotaUnavailable,
        ProviderQuotaStatus.invalidResponse => l10n.quotaInvalidResponse,
      };

  static String _providerName(QuotaProvider provider, AppLocalizations l10n) =>
      switch (provider) {
        QuotaProvider.codex => l10n.quotaCodex,
        QuotaProvider.claude => l10n.quotaClaude,
        QuotaProvider.minimax => l10n.quotaMiniMax,
        QuotaProvider.glm => l10n.quotaGlm,
      };

  /// The threshold a newly monitored source alerts at; its row changes it
  /// once monitoring is on.
  static const _defaultThreshold = 90.0;

  /// Turns monitoring on for the account shown, in place (slice-P3.11a: the
  /// enrol sheet merged into this page). The row that starts it says what
  /// it does and at what percentage; the threshold row and the named Stop
  /// that replace it change or undo it.
  Future<void> _enroll() async {
    final snapshot = _overview.snapshot;
    final profileID = widget.controller.profile?.id;
    if (snapshot == null ||
        profileID == null ||
        _overview.snapshotIsStale ||
        _overview.detached) {
      return;
    }
    if (_enrolling) return;
    const chosen = _defaultThreshold;
    setState(() => _enrolling = true);
    final shared = widget.controller.sharedNotifyRules;
    final valid =
        !_overview.detached &&
        !_overview.snapshotIsStale &&
        identical(snapshot, _overview.snapshot);
    final saved =
        valid &&
        await widget.controller.quotaMonitor.enroll(
          profileID,
          snapshot,
          // Alerts, Wi-Fi only and quiet hours are shared (Notifications).
          // The record still carries them so a build that has not migrated
          // reads the same answer.
          notifications: shared.quotaAlerts,
          threshold: chosen,
          wifiOnly: shared.wifiOnly,
          quietStart: shared.quietEnabled ? shared.quietStart : null,
          quietEnd: shared.quietEnabled ? shared.quietEnd : null,
        );
    if (!mounted) {
      return;
    }
    // The row gives way to the source's threshold and Stop, in place; a
    // failure is said beside the action that failed.
    setState(() {
      _enrolling = false;
      _monitorSaveFailed = !saved;
    });
  }

  /// This server's name as the rest of the app says it.
  String _serverName(AppLocalizations l10n) {
    final profile = widget.controller.profile;
    return profile == null
        ? l10n.quotaUnknownSource
        : serverDisplayName(
            profile,
            l10n,
            among: widget.controller.store.profiles,
          );
  }

  void _stopUsingCollector() {
    setState(() {
      _trusted = false;
      _monitorSaveFailed = false;
    });
    _overview.disable();
  }

  void _openNotifications() => unawaited(
    pushKitPage<void>(
      context,
      (_) => NotificationsSettingsScreen(controller: widget.controller),
    ),
  );

  /// The monitored source for the account this page shows, or null when
  /// that account is not on the page (no reading, other provider, detached).
  QuotaMonitorTarget? _shownSource(ProviderQuotaSnapshot? snapshot) {
    final profileID = widget.controller.profile?.id;
    if (profileID == null ||
        snapshot == null ||
        !snapshot.canShowWindows ||
        !_overview.consented ||
        _overview.detached ||
        !_overview.providerSupported ||
        snapshot.provider != _overview.provider) {
      return null;
    }
    return QuotaMonitorTarget(profileID, snapshot.provider);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_overview, widget.controller.quotaMonitor]),
    builder: (context, _) {
      final l10n = lookupAppLocalizations(Localizations.localeOf(context));
      final tokens = KitTokens.of(context);
      final snapshot = _overview.snapshot;
      final canRefresh = _overview.canRead && !_overview.loading;
      final detached = _overview.detached;
      final consented = _overview.consented && !detached;
      final origin = _origin();
      Widget gap([double? height]) => SizedBox(height: height ?? tokens.space4);
      final refreshAction = KitAction(
        key: const ValueKey('quota-refresh'),
        label: l10n.quotaRefresh,
        icon: AppIconography.retry,
        onPressed: canRefresh ? () => unawaited(_overview.refresh()) : null,
        disabledReason: canRefresh ? null : l10n.quotaLoading,
      );
      // Inside Usage the one top bar holds Refresh for the active tab.
      widget.refreshSlot?.offer(
        visible: _overview.consented,
        onRefresh: refreshAction.onPressed,
        disabledReason: refreshAction.disabledReason,
      );
      final shownSource = _shownSource(snapshot);

      final children = <Widget>[
        SizedBox(height: tokens.space3),
        if (detached)
          KitNotice(
            key: const ValueKey('quota-detached'),
            icon: AppIconography.swap,
            message: l10n.quotaSourceChanged,
          )
        else ...[
          KitSegmented<QuotaProvider>(
            key: const ValueKey('quota-provider'),
            semanticsLabel: l10n.providerQuotaProviderLabel,
            selected: _overview.provider,
            segments: [
              for (final provider in QuotaProvider.values)
                KitSegment(
                  key: ValueKey('quota-provider-${provider.name}'),
                  value: provider,
                  label: _providerName(provider, l10n),
                ),
            ],
            onChanged: (provider) {
              if (_overview.provider == provider) {
                return;
              }
              setState(() {
                _trusted = false;
                _monitorSaveFailed = false;
              });
              _overview.selectProvider(provider);
            },
          ),
          gap(tokens.sectionGap),
          if (!_overview.providerSupported)
            KitNotice(
              key: const ValueKey('quota-provider-unavailable'),
              icon: AppIconography.info,
              message: l10n.quotaClaudeUnavailable,
            )
          else if (!_overview.consented)
            ..._setup(context, l10n, tokens)
          else
            ..._reading(context, l10n, tokens, snapshot, canRefresh),
          gap(tokens.sectionGap),
          _CollectorRows(
            origin: origin,
            consented: consented,
            onStop: _stopUsingCollector,
          ),
        ],
        // Monitored sources belong to any saved server, so they stay listed
        // when this server's reading is unavailable.
        gap(tokens.sectionGap),
        QuotaMonitorSection(
          controller: widget.controller,
          onOpenNotifications: _openNotifications,
          shownAbove: shownSource,
        ),
        gap(tokens.sectionGap),
        // Every technical value on the page, once, last and folded
        // (KIT-33).
        KitDetailsFold(
          key: const ValueKey('quota-details'),
          values: [
            if (origin != null) KitTechnicalValue(l10n.quotaSource, origin),
            if (!detached && _overview.providerSupported)
              KitTechnicalValue(
                l10n.providerQuotaRouteLabel,
                quotaPathFor(_overview.provider),
              ),
          ],
          notes: [
            if (!_overview.consented) ...[
              l10n.quotaSetupTrustNote,
              l10n.quotaSetupGuide,
            ],
            l10n.quotaMonitorRuntime,
            l10n.quotaSourceDisclosure,
          ],
        ),
      ];

      final list = ListView(
        key: const ValueKey('quota-content'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: KitScreen.padding(context),
        children: children,
      );
      final body = consented && _overview.canRead
          ? KitRefresh(onRefresh: _overview.refresh, child: list)
          : list;
      return KitScreen(
        topBar: widget.embedded
            ? null
            : KitTopBar(
                title: l10n.quotaTitle,
                actions: [if (_overview.consented) refreshAction],
              ),
        width: KitScreenWidth.reading,
        loading: _overview.loading,
        loadingLabel: l10n.quotaLoading,
        body: body,
      );
    },
  );

  /// No consent yet: what the collector is, the promise, and the explicit
  /// read.
  List<Widget> _setup(
    BuildContext context,
    AppLocalizations l10n,
    KitTokens tokens,
  ) {
    final setupNeeded = _overview.setupNeeded;
    final canRead = _trusted && !setupNeeded;
    return [
      KitText(
        l10n.quotaSetupTitle,
        key: const ValueKey('quota-setup-title'),
        role: KitTextRole.headline,
      ),
      SizedBox(height: tokens.space2),
      KitText(l10n.quotaSetupDescription, role: KitTextRole.secondary),
      if (setupNeeded) ...[
        SizedBox(height: tokens.space3),
        KitNotice(
          key: const ValueKey('quota-setup-needed'),
          icon: AppIconography.warning,
          message: l10n.quotaSetupNeeded,
        ),
      ],
      SizedBox(height: tokens.space4),
      KitRowGroup(
        margin: EdgeInsetsDirectional.zero,
        children: [
          KitSwitchRow(
            switchKey: const ValueKey('quota-consent'),
            leading: KitRow.icon(context, AppIconography.shield),
            title: l10n.quotaConsent,
            value: _trusted,
            onChanged: setupNeeded
                ? null
                : (value) => setState(() => _trusted = value),
            disabledReason: setupNeeded ? l10n.quotaSetupNeeded : null,
          ),
        ],
      ),
      SizedBox(height: tokens.space4),
      KitButton.primary(
        key: const ValueKey('quota-read'),
        label: l10n.quotaRead,
        icon: AppIconography.speed,
        onPressed: canRead
            ? () {
                // The reading replaces the setup text above; the monitoring
                // section below keeps the list long, so without this the
                // person is left looking at it instead of the result.
                if (_scroll.hasClients) _scroll.jumpTo(0);
                unawaited(_overview.allowAndRefresh());
              }
            : null,
      ),
    ];
  }

  /// Consent given: the failure, the notices and the report.
  List<Widget> _reading(
    BuildContext context,
    AppLocalizations l10n,
    KitTokens tokens,
    ProviderQuotaSnapshot? snapshot,
    bool canRefresh,
  ) {
    final stale = _overview.snapshotIsStale;
    final profileID = widget.controller.profile?.id;
    return [
      if (_overview.failure case final failure?) ...[
        KitNotice.error(
          key: const ValueKey('quota-failure'),
          message: _failure(failure, l10n),
          retry: KitAction(
            key: const ValueKey('quota-retry'),
            label: l10n.quotaRefresh,
            icon: AppIconography.retry,
            onPressed: canRefresh ? () => unawaited(_overview.refresh()) : null,
            disabledReason: canRefresh ? null : l10n.quotaLoading,
          ),
        ),
        SizedBox(height: tokens.space4),
      ],
      if (snapshot == null && _overview.failure == null)
        KitText(l10n.quotaLoading, role: KitTextRole.secondary),
      if (snapshot != null) ...[
        if (!snapshot.canShowWindows)
          KitNotice(
            key: const ValueKey('quota-status'),
            icon: AppIconography.info,
            message: _status(snapshot.status, l10n),
          )
        else
          _QuotaReport(
            snapshot: snapshot,
            stale: stale,
            now: _overview.clock(),
            monitored:
                profileID != null &&
                    widget.controller.quotaMonitor.rulesFor(
                          profileID,
                          snapshot.provider,
                        ) !=
                        null
                ? QuotaMonitorTarget(profileID, snapshot.provider)
                : null,
            controller: widget.controller,
            monitorSaveFailed: _monitorSaveFailed,
            monitorOffer: l10n.quotaMonitorOffer(
              _providerName(snapshot.provider, l10n),
              _serverName(l10n),
            ),
            monitorOfferDetail: l10n.quotaMonitorOfferDetail(
              NumberFormat.percentPattern(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(_defaultThreshold / 100),
            ),
            enrolling: _enrolling,
            onEnableMonitoring: stale || _enrolling ? null : _enroll,
          ),
      ],
    ];
  }
}

/// The collector on this server and what acts on it: its origin and
/// stopping its use. The act lives with the thing it acts on (owner rule
/// 2026-09-27), not as a loose button at the end of the page.
class _CollectorRows extends StatelessWidget {
  const _CollectorRows({
    required this.origin,
    required this.consented,
    required this.onStop,
  });

  final String? origin;
  final bool consented;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final origin = this.origin;
    return KitRowGroup(
      key: const ValueKey('quota-collector'),
      margin: EdgeInsetsDirectional.zero,
      label: l10n.quotaSource,
      children: [
        KitRow(
          key: const ValueKey('quota-source'),
          leading: KitRow.icon(context, AppIconography.server),
          title: origin == null ? l10n.quotaUnknownSource : KitBidi.ltr(origin),
          titleMaxLines: 2,
        ),
        if (consented)
          KitRow(
            key: const ValueKey('quota-stop'),
            leading: KitRow.icon(context, AppIconography.unlink),
            title: l10n.quotaForgetConsent,
            onTap: onStop,
          ),
      ],
    );
  }
}

class _QuotaReport extends StatelessWidget {
  final ProviderQuotaSnapshot snapshot;
  final bool stale;
  final DateTime now;
  final bool monitorSaveFailed;

  /// This account's monitored source, or null when it is not monitored.
  final QuotaMonitorTarget? monitored;
  final ConnectionController controller;

  /// "Alert me about Codex on Studio" and what it does, for the row that
  /// turns monitoring on.
  final String monitorOffer;
  final String monitorOfferDetail;
  final bool enrolling;

  /// Null while the reading is stale (monitoring needs a fresh one).
  final VoidCallback? onEnableMonitoring;

  const _QuotaReport({
    required this.snapshot,
    required this.stale,
    required this.now,
    required this.monitored,
    required this.controller,
    required this.monitorSaveFailed,
    required this.monitorOffer,
    required this.monitorOfferDetail,
    required this.enrolling,
    required this.onEnableMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).add_jm();
    final percent = NumberFormat.percentPattern(locale)
      ..maximumFractionDigits = 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitText(switch (snapshot.provider) {
          QuotaProvider.codex => l10n.quotaCodexAccount,
          QuotaProvider.claude => l10n.quotaClaudeAccount,
          QuotaProvider.minimax => l10n.quotaMiniMaxAccount,
          QuotaProvider.glm => l10n.quotaGlmAccount,
        }, role: KitTextRole.headline),
        if (snapshot.account.status == QuotaAccountStatus.sourceBound) ...[
          SizedBox(height: tokens.space2),
          KitText(
            snapshot.provider == QuotaProvider.minimax
                ? l10n.quotaMiniMaxSourceBound
                : l10n.quotaSourceBound,
            role: KitTextRole.secondary,
          ),
        ],
        if (snapshot.account.plan case final plan?) ...[
          SizedBox(height: tokens.space1),
          KitText(l10n.quotaPlan(plan), role: KitTextRole.secondary),
        ],
        SizedBox(height: tokens.space1),
        KitText(
          l10n.quotaChecked(date.format(snapshot.fetchedAt.toLocal())),
          role: KitTextRole.caption,
        ),
        if (stale) ...[
          SizedBox(height: tokens.space3),
          KitNotice(
            key: const ValueKey('quota-stale'),
            icon: AppIconography.history,
            message: l10n.quotaStale,
          ),
        ],
        if (snapshot.ordinaryUsageAllowed == false) ...[
          SizedBox(height: tokens.space3),
          KitNotice(
            key: const ValueKey('quota-use-blocked'),
            icon: AppIconography.blocked,
            message: l10n.quotaUseBlocked,
          ),
        ],
        // Monitoring acts on this account source, so it sits under the
        // account's name rather than above the whole report. Once it is
        // monitored, its threshold and Stop live here, not twice.
        SizedBox(height: tokens.space4),
        if (monitored case final target?)
          QuotaMonitorControls(
            key: const ValueKey('quota-account-monitoring'),
            controller: controller,
            target: target,
            grouped: true,
          )
        else
          // One row names what it turns on and says what that does; no
          // sheet asks again (slice-P3.11a).
          KitRowGroup(
            margin: EdgeInsetsDirectional.zero,
            children: [
              KitRow(
                key: const ValueKey('quota-enable-monitoring'),
                leading: KitRow.icon(
                  context,
                  AppIconography.notificationImportant,
                ),
                title: monitorOffer,
                titleMaxLines: 2,
                supporting: TextSpan(text: monitorOfferDetail),
                supportingMaxLines: 3,
                enabled: onEnableMonitoring != null,
                disabledReason: enrolling
                    ? l10n.quotaMonitorSaving
                    : stale
                    ? l10n.quotaStale
                    : null,
                trailing: enrolling
                    ? const KitTaskMark(state: KitTaskState.working)
                    : null,
                onTap: onEnableMonitoring,
              ),
            ],
          ),
        if (monitorSaveFailed) ...[
          SizedBox(height: tokens.space3),
          KitNotice.error(
            key: const ValueKey('quota-monitor-save-failed'),
            message: l10n.quotaMonitorSaveFailed,
          ),
        ],
        if (snapshot.windows.isEmpty) ...[
          SizedBox(height: tokens.space4),
          KitText(l10n.quotaNotReported, role: KitTextRole.secondary),
        ],
        for (var index = 0; index < snapshot.windows.length; index++) ...[
          SizedBox(height: tokens.sectionGap),
          _WindowGroup(
            snapshot: snapshot,
            window: snapshot.windows[index],
            index: index,
            stale: stale,
            now: now,
            date: date,
            percent: percent,
          ),
        ],
      ],
    );
  }
}

/// One reported window as a panel of rows: how much is left and when it
/// resets. The alert threshold is the monitored source's, one per source.
class _WindowGroup extends StatelessWidget {
  const _WindowGroup({
    required this.snapshot,
    required this.window,
    required this.index,
    required this.stale,
    required this.now,
    required this.date,
    required this.percent,
  });

  final ProviderQuotaSnapshot snapshot;
  final ProviderQuotaWindow window;
  final int index;
  final bool stale;
  final DateTime now;
  final DateFormat date;
  final NumberFormat percent;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final title = switch (window.id) {
      'tokens' when snapshot.provider == QuotaProvider.glm =>
        l10n.quotaGlmTokenWindow,
      'mcp' when snapshot.provider == QuotaProvider.glm =>
        l10n.quotaGlmMcpWindow,
      'primary' => l10n.quotaPrimaryWindow,
      'secondary' => l10n.quotaSecondaryWindow,
      _ => l10n.quotaOtherWindow(index + 1),
    };
    final duration = window.durationSeconds;
    final length = duration == null
        ? title
        : duration % 86400 == 0
        ? l10n.quotaDays(duration ~/ 86400)
        : duration % 3600 == 0
        ? l10n.quotaHours(duration ~/ 3600)
        : l10n.quotaSeconds(duration);
    final remaining = window.remainingPercent;
    final used = window.usedPercent;
    final reset = window.resetsAt;
    final passed = reset != null && !now.isBefore(reset);
    return KitRowGroup(
      key: ValueKey('quota-window-${window.id}'),
      margin: EdgeInsetsDirectional.zero,
      label: title,
      children: [
        if (remaining == null || used == null)
          KitRow(
            leading: KitRow.icon(context, AppIconography.usageRing),
            title: length,
            trailing: KitRowValue(l10n.quotaNotReported, chevron: false),
          )
        else
          // The bar fills with what is used, so the part's near-limit and
          // at-limit words follow consumption; the words say what is left.
          KitProgressRow(
            key: ValueKey('quota-window-bar-${window.id}'),
            leading: KitRow.icon(context, AppIconography.usageRing),
            title: length,
            value: used / 100,
            valueLabel: l10n.quotaRemaining(percent.format(remaining / 100)),
            asOf: stale ? snapshot.fetchedAt.toLocal() : null,
          ),
        KitRow(
          key: ValueKey('quota-window-reset-${window.id}'),
          leading: KitRow.icon(context, AppIconography.timer),
          title: reset == null
              ? l10n.quotaResetUnknown
              : l10n.quotaResetAt(date.format(reset.toLocal())),
          titleMaxLines: 2,
          supporting: passed ? TextSpan(text: l10n.quotaResetPassed) : null,
          supportingMaxLines: 3,
        ),
      ],
    );
  }
}
