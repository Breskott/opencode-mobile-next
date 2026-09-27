import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/provider_quota.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_budgets.dart';
import '../../state/provider_quota_overview.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../widgets/quota_monitor_section.dart';
import 'settings_screen.dart' show NotificationsSettingsScreen;

// revamp: redesign (slice-P5.4). Rebuilt from kit parts in today's layout;
// the per-provider answer rows, the agent-driven collector setup and the
// one-alert-per-provider switch arrive with slice-P5.4.
class ProviderQuotaScreen extends StatefulWidget {
  final ConnectionController controller;
  final ProviderQuotaOverview? overview;

  /// True as the "Remaining" section of the Usage screen, which already
  /// supplies the top bar.
  final bool embedded;

  const ProviderQuotaScreen({
    super.key,
    required this.controller,
    this.overview,
    this.embedded = false,
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

  Future<void> _enroll() async {
    final snapshot = _overview.snapshot;
    final profileID = widget.controller.profile?.id;
    if (snapshot == null ||
        profileID == null ||
        _overview.snapshotIsStale ||
        _overview.detached) {
      return;
    }
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final threshold = ValueNotifier<double>(100);
    final origin = _origin();
    final accepted = await showKitSheet<bool>(
      context,
      sheetKey: const ValueKey('quota-enroll-sheet'),
      title: l10n.quotaMonitorConsentTitle,
      icon: AppIconography.notificationImportant,
      body: (_) => _EnrollSheetBody(threshold: threshold, origin: origin),
      primary: KitAction(
        key: const ValueKey('quota-enroll-confirm'),
        label: l10n.quotaMonitorEnable,
        icon: AppIconography.check,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    );
    final chosen = threshold.value;
    threshold.dispose();
    if (!mounted || accepted != true) {
      return;
    }
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
    // The new source appears in the monitoring section below, in place; a
    // failure is said beside the action that failed.
    setState(() => _monitorSaveFailed = !saved);
  }

  Future<void> _clearThresholds() async {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final clear = await showKitConfirm(
      context,
      sheetKey: const ValueKey('quota-clear-sheet'),
      confirmKey: const ValueKey('quota-clear-confirm'),
      title: l10n.quotaBudgetClearTitle,
      body: l10n.quotaBudgetClearDescription,
      confirmLabel: l10n.quotaBudgetClearAll,
      icon: AppIconography.delete,
      kind: KitConfirmKind.destructive,
    );
    if (clear && mounted) {
      await _overview.budgets.clearAll();
    }
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _overview,
    builder: (context, _) {
      final l10n = lookupAppLocalizations(Localizations.localeOf(context));
      final tokens = KitTokens.of(context);
      final snapshot = _overview.snapshot;
      final canRefresh = _overview.canRead && !_overview.loading;
      final detached = _overview.detached;
      final consented = _overview.consented && !detached;
      final origin = _origin();
      Widget gap([double? height]) => SizedBox(height: height ?? tokens.space4);
      final description = KitText(
        l10n.quotaDescription,
        role: KitTextRole.secondary,
      );
      final refreshAction = KitAction(
        key: const ValueKey('quota-refresh'),
        label: l10n.quotaRefresh,
        icon: AppIconography.retry,
        onPressed: canRefresh ? () => unawaited(_overview.refresh()) : null,
        disabledReason: canRefresh ? null : l10n.quotaLoading,
      );

      final children = <Widget>[
        SizedBox(height: tokens.space3),
        // Inside Usage there is no bar of its own to hold Refresh, so it
        // sits beside the description.
        if (widget.embedded && _overview.consented)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: description),
              KitIconButton(
                key: const ValueKey('quota-refresh'),
                icon: AppIconography.retry,
                tooltip: l10n.quotaRefresh,
                onPressed: refreshAction.onPressed,
                disabledReason: refreshAction.disabledReason,
              ),
            ],
          )
        else
          description,
        gap(),
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
            saving: _overview.budgets.saving,
            onStop: _stopUsingCollector,
            onClear: _clearThresholds,
          ),
        ],
        // Monitored sources belong to any saved server, so they stay listed
        // when this server's reading is unavailable.
        gap(tokens.sectionGap),
        QuotaMonitorSection(
          controller: widget.controller,
          onOpenNotifications: _openNotifications,
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
          notes: [l10n.quotaSourceDisclosure],
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
      SizedBox(height: tokens.space3),
      KitText(l10n.quotaSetupGuide, role: KitTextRole.secondary),
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
    final budgets = _overview.budgets;
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
        if (budgets.failed) ...[
          KitNotice.error(message: l10n.quotaBudgetSaveFailed),
          SizedBox(height: tokens.space3),
        ],
        if (budgets.attentionVisible && !stale) ...[
          KitNotice(
            key: const ValueKey('quota-threshold-reached'),
            icon: AppIconography.warning,
            message: l10n.quotaBudgetAttention,
          ),
          SizedBox(height: tokens.space3),
        ],
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
            budgets: budgets,
            monitorSaveFailed: _monitorSaveFailed,
            onEnableMonitoring: stale ? null : _enroll,
          ),
      ],
    ];
  }
}

/// The collector on this server and what acts on it: its origin, stopping
/// its use, and clearing the thresholds saved for it. The acts live with
/// the thing they act on (owner rule 2026-09-27), not as loose buttons at
/// the end of the page.
class _CollectorRows extends StatelessWidget {
  const _CollectorRows({
    required this.origin,
    required this.consented,
    required this.saving,
    required this.onStop,
    required this.onClear,
  });

  final String? origin;
  final bool consented;
  final bool saving;
  final VoidCallback onStop;
  final VoidCallback onClear;

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
        if (consented) ...[
          KitRow(
            key: const ValueKey('quota-stop'),
            leading: KitRow.icon(context, AppIconography.unlink),
            title: l10n.quotaForgetConsent,
            onTap: onStop,
          ),
          KitRow(
            key: const ValueKey('quota-clear'),
            leading: KitRow.icon(context, AppIconography.delete),
            title: l10n.quotaBudgetClearAll,
            destructive: true,
            enabled: !saving,
            disabledReason: saving ? l10n.quotaMonitorSaving : null,
            onTap: saving ? null : onClear,
          ),
        ],
      ],
    );
  }
}

class _QuotaReport extends StatelessWidget {
  final ProviderQuotaSnapshot snapshot;
  final bool stale;
  final DateTime now;
  final ProviderQuotaBudgets budgets;
  final bool monitorSaveFailed;

  /// Null while the reading is stale (monitoring needs a fresh one).
  final VoidCallback? onEnableMonitoring;

  const _QuotaReport({
    required this.snapshot,
    required this.stale,
    required this.now,
    required this.budgets,
    required this.monitorSaveFailed,
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
        // account's name rather than above the whole report.
        SizedBox(height: tokens.space4),
        KitButton.secondary(
          key: const ValueKey('quota-enable-monitoring'),
          label: l10n.quotaMonitorEnable,
          icon: AppIconography.notificationImportant,
          onPressed: onEnableMonitoring,
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
            budgets: budgets,
            date: date,
            percent: percent,
          ),
        ],
      ],
    );
  }
}

/// One reported window as a panel of rows: how much is left, when it
/// resets, and the personal threshold for it.
class _WindowGroup extends StatelessWidget {
  const _WindowGroup({
    required this.snapshot,
    required this.window,
    required this.index,
    required this.stale,
    required this.now,
    required this.budgets,
    required this.date,
    required this.percent,
  });

  final ProviderQuotaSnapshot snapshot;
  final ProviderQuotaWindow window;
  final int index;
  final bool stale;
  final DateTime now;
  final ProviderQuotaBudgets budgets;
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
        if (budgets.usable(snapshot, window)) ..._threshold(context, l10n),
      ],
    );
  }

  List<Widget> _threshold(BuildContext context, AppLocalizations l10n) {
    final rule = budgets.rule(snapshot, window);
    // Read through a pattern: the field shares its name with the attention
    // colour roles, which G17 keeps out of screens (LOOK-4).
    final attentionOn = switch (rule) {
      QuotaBudget(attention: final on) => on,
      null => false,
    };
    final enabled = !stale && !budgets.saving;
    final reason = enabled
        ? null
        : stale
        ? l10n.providerQuotaThresholdStale
        : l10n.quotaMonitorSaving;
    Future<void> save(QuotaBudget? value) async {
      if (await budgets.save(snapshot, window, value)) {
        await budgets.observe(snapshot, stale: stale);
      }
    }

    return [
      KitPickerRow<double>(
        rowKey: ValueKey('quota-threshold-${window.id}'),
        leading: KitRow.icon(context, AppIconography.notificationImportant),
        title: l10n.quotaBudgetTitle,
        supporting: l10n.quotaBudgetDescription,
        selected: rule?.percent ?? 0,
        choices: [
          KitChoice(value: 0, title: l10n.quotaBudgetOff),
          for (final value in {
            50.0,
            75.0,
            90.0,
            100.0,
            if (rule != null) rule.percent,
          })
            KitChoice(
              value: value,
              title: l10n.quotaBudgetPercent(value.toStringAsFixed(0)),
            ),
        ],
        onSelected: enabled
            ? (value) => unawaited(
                save(
                  value == 0
                      ? null
                      : QuotaBudget(value, attention: attentionOn),
                ),
              )
            : null,
        disabledReason: reason,
      ),
      if (rule != null)
        KitSwitchRow(
          switchKey: ValueKey('quota-attention-${window.id}'),
          leading: KitRow.icon(context, AppIconography.warning),
          title: l10n.quotaBudgetOptIn,
          supporting: l10n.quotaBudgetAttentionScope,
          value: attentionOn,
          onChanged: enabled
              ? (value) =>
                    unawaited(save(QuotaBudget(rule.percent, attention: value)))
              : null,
          disabledReason: reason,
        ),
    ];
  }
}

// revamp: merge-into:provider-quota (slice-P3.11a)
/// What monitoring does, the percentage used that alerts, and the source
/// under Details. The threshold is a segmented choice in place: a picker
/// would open a sheet on this sheet (KIT-16).
class _EnrollSheetBody extends StatelessWidget {
  const _EnrollSheetBody({required this.threshold, required this.origin});

  final ValueNotifier<double> threshold;
  final String? origin;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final origin = this.origin;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitText(l10n.quotaMonitorConsent, role: KitTextRole.secondary),
        SizedBox(height: tokens.space4),
        KitText(l10n.quotaMonitorThreshold, role: KitTextRole.label),
        SizedBox(height: tokens.labelGap),
        ValueListenableBuilder<double>(
          valueListenable: threshold,
          builder: (context, value, _) => KitSegmented<double>(
            key: const ValueKey('quota-enroll-threshold'),
            semanticsLabel: l10n.quotaMonitorThreshold,
            selected: value,
            segments: [
              for (final option in [50.0, 75.0, 90.0, 100.0])
                KitSegment(
                  value: option,
                  // The label above says "used"; the bare percentage fits
                  // four segments on a phone without cutting.
                  label: percent.format(option / 100),
                ),
            ],
            onChanged: (option) => threshold.value = option,
          ),
        ),
        SizedBox(height: tokens.space4),
        KitDetailsFold(
          values: [
            KitTechnicalValue(
              l10n.quotaSource,
              origin ?? l10n.quotaUnknownSource,
            ),
          ],
        ),
      ],
    );
  }
}
