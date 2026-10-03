import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/agent_account.dart';
import '../../domain/provider_quota.dart';
import '../../domain/quota_answers.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/quota_answer_preferences.dart';
import '../../state/quota_answers_controller.dart';
import '../../state/provider_quota_monitor.dart' show QuotaMonitorTarget;
import '../../state/provider_quota_overview.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../widgets/phone_server_card.dart' show serverDisplayName;
import '../widgets/external_link.dart' show openExternalLink;
import '../widgets/quota_monitor_section.dart';
import 'agent_account_screen.dart';
import 'settings_screen.dart' show NotificationsSettingsScreen;
import 'usage_refresh_slot.dart';

/// Remaining: what a provider account has left, as sentences ("About 40%
/// left this week · resets Tue", slice-P5.4).
///
/// On a server that hosts a Codex account the answer comes from that
/// account ([QuotaAnswersController.codex]): no collector, no consent step,
/// and "Alert me at 80% used" is on by default. Elsewhere it comes from the
/// server's quota collector after the person trusts it; a missing collector
/// says so, naming the server, with how to get it.
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

class _ProviderQuotaScreenState extends State<ProviderQuotaScreen>
    with WidgetsBindingObserver {
  late ProviderQuotaOverview _overview;

  /// The Codex account answer, on a server that hosts one and is connected.
  QuotaAnswersController? _answers;

  /// The scope the answer belongs to: profile, location and gateway.
  (String, int, Object)? _answerScope;

  /// The connection dropped since the account session was opened; the next
  /// connect opens a fresh one (reconcile by refetch, never replay).
  bool _answerDropped = false;

  /// The server or project changed under the answer: it is gone.
  bool _answerScopeLost = false;

  /// Saving the alert switch failed; said under it.
  bool _alertSaveFailed = false;
  bool _alertSaving = false;
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
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncAnswers);
    _bindAnswers();
  }

  /// True when this server hosts a Codex account: Remaining reads it there.
  bool get _accountHost =>
      widget.controller.capabilities.agentAccount &&
      widget.controller.api is AgentAccountGateway;

  /// Opens a dedicated account session for the answer (never the sign-in
  /// page's) when the server hosts a Codex account and is connected.
  void _bindAnswers() {
    final connection = widget.controller;
    final profile = connection.profile;
    final gateway = connection.api;
    if (profile == null ||
        !connection.isConnected ||
        !connection.capabilities.agentAccount ||
        gateway is! AgentAccountGateway) {
      return;
    }
    final id = profile.id;
    final origin = profile.baseUrl;
    final username = profile.username;
    final location = connection.locationRevision;
    final scope = (id, location, gateway as Object);
    if (_answerScope != null && _answerScope != scope) return;
    _answerScope = scope;
    bool current() =>
        connection.profile?.id == id &&
        connection.profile?.baseUrl == origin &&
        connection.profile?.username == username &&
        connection.locationRevision == location &&
        identical(connection.api, gateway) &&
        connection.isProfileReadable(id);
    final answers = QuotaAnswersController.codex(
      session: (gateway as AgentAccountGateway).openAccountSession(),
      preferences: QuotaAnswerPreferences(
        preferences: connection.store.prefs,
        profileId: id,
        isCurrent: current,
        isProfilePresent: () => connection.isProfileReadable(id),
      ),
      isCurrent: current,
      // One clock for the page: ages and resets agree with the collector's.
      clock: _overview.clock,
    );
    _answers = answers;
    _answerDropped = false;
    unawaited(answers.refresh());
  }

  /// Follows the connection: a changed server forgets the answer, a drop
  /// keeps it with its age, a reconnect reads again on a fresh session.
  void _syncAnswers() {
    if (!mounted || _answerScopeLost) return;
    final connection = widget.controller;
    final scope = _answerScope;
    if (scope != null &&
        (connection.profile?.id != scope.$1 ||
            connection.locationRevision != scope.$2 ||
            !identical(connection.api, scope.$3) ||
            !connection.isProfileReadable(scope.$1))) {
      final answers = _answers;
      _answers = null;
      // Forget first, then release: nothing of the old server survives.
      answers?.invalidate(forget: true);
      answers?.dispose();
      setState(() => _answerScopeLost = true);
      return;
    }
    final answers = _answers;
    if (!connection.isConnected) {
      if (answers != null && !_answerDropped) {
        _answerDropped = true;
        answers.invalidate();
      }
      return;
    }
    if (answers == null) {
      if (_accountHost) setState(_bindAnswers);
    } else if (_answerDropped) {
      _answerDropped = false;
      answers.replaceAccountSession(
        (connection.api as AgentAccountGateway).openAccountSession(),
      );
      unawaited(answers.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final answers = _answers;
    if (state != AppLifecycleState.resumed || answers == null) return;
    if (_answerDropped) {
      // Still offline: the last known answer's age is said again.
      setState(() {});
    } else {
      unawaited(answers.refresh());
    }
  }

  void _releaseAnswers() {
    _answers?.dispose();
    _answers = null;
    _answerScope = null;
    _answerDropped = false;
    _answerScopeLost = false;
    _alertSaveFailed = false;
  }

  Future<void> _setAlert(bool enabled) async {
    final answers = _answers;
    if (answers == null || _alertSaving) return;
    setState(() {
      _alertSaving = true;
      _alertSaveFailed = false;
    });
    final saved = await answers.setAlert80Enabled(enabled);
    if (!mounted) return;
    setState(() {
      _alertSaving = false;
      _alertSaveFailed = !saved || answers.preferences.failed;
    });
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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncAnswers);
      widget.controller.addListener(_syncAnswers);
      _releaseAnswers();
      _bindAnswers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncAnswers);
    _answers?.dispose();
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
        QuotaFailureKind.unsupported => l10n.quotaNeedsCollector(
          _serverName(l10n),
        ),
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

  /// The threshold a newly monitored source alerts at, the same 80% the
  /// answer alerts at; its row changes it once monitoring is on.
  static const _defaultThreshold = 80.0;

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

  /// Stops reading through the collector: the reading goes, and the page
  /// asks for consent again before the next read.
  void _stopUsingCollector() {
    setState(() {
      _trusted = false;
      _monitorSaveFailed = false;
    });
    _overview.disable();
  }

  /// What the collector says about whose account it read, when it cannot
  /// tell the account apart: a technical caveat, said in Details.
  static String? _sourceBoundNote(
    ProviderQuotaSnapshot snapshot,
    AppLocalizations l10n,
  ) => snapshot.account.status != QuotaAccountStatus.sourceBound
      ? null
      : snapshot.provider == QuotaProvider.minimax
      ? l10n.quotaMiniMaxSourceBound
      : l10n.quotaSourceBound;

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
    listenable: Listenable.merge([
      _overview,
      widget.controller.quotaMonitor,
      ?_answers,
    ]),
    builder: (context, _) =>
        _accountHost || _answers != null || _answerScopeLost
        ? _buildAccount(context)
        : _buildCollector(context),
  );

  /// Remaining on a server that hosts a Codex account: the account's answer,
  /// the alert switch, then any sources monitored elsewhere.
  Widget _buildAccount(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final answers = _answers;
    final canRefresh = answers != null && !answers.loading && !_answerDropped;
    final refreshAction = KitAction(
      key: const ValueKey('quota-refresh'),
      label: l10n.quotaRefresh,
      icon: AppIconography.retry,
      onPressed: canRefresh ? () => unawaited(answers.refresh()) : null,
      disabledReason: canRefresh ? null : l10n.quotaLoading,
    );
    widget.refreshSlot?.offer(
      visible: answers != null,
      onRefresh: refreshAction.onPressed,
      disabledReason: refreshAction.disabledReason,
    );
    final monitored = widget.controller.quotaMonitor.sources.isNotEmpty;
    final children = <Widget>[
      SizedBox(height: tokens.space3),
      if (_answerScopeLost)
        KitNotice(
          key: const ValueKey('quota-detached'),
          icon: AppIconography.swap,
          message: l10n.quotaSourceChanged,
        )
      else if (answers == null)
        KitNotice(
          key: const ValueKey('quota-answer-not-connected'),
          icon: AppIconography.cloudOff,
          message: l10n.quotaAnswerNotConnected(_serverName(l10n)),
        )
      else
        _AccountAnswer(
          answers: answers,
          serverName: _serverName(l10n),
          alertSaving: _alertSaving,
          alertSaveFailed: _alertSaveFailed,
          onAlertChanged: _setAlert,
          onRetry: canRefresh ? () => unawaited(answers.refresh()) : null,
          onSignIn: () => unawaited(
            pushKitPage<void>(
              context,
              (_) => AgentAccountScreen(connection: widget.controller),
            ),
          ),
        ),
      // Sources monitored on other servers stay reachable here.
      if (monitored) ...[
        SizedBox(height: tokens.sectionGap),
        QuotaMonitorSection(
          controller: widget.controller,
          onOpenNotifications: _openNotifications,
        ),
      ],
      SizedBox(height: tokens.sectionGap),
      KitDetailsFold(
        key: const ValueKey('quota-details'),
        notes: [
          l10n.quotaAnswerCodexNote,
          if (monitored) l10n.quotaMonitorRuntime,
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
    return KitScreen(
      topBar: widget.embedded
          ? null
          : KitTopBar(
              title: l10n.quotaTitle,
              actions: [if (answers != null) refreshAction],
            ),
      width: KitScreenWidth.reading,
      loading: answers?.loading ?? false,
      loadingLabel: l10n.quotaLoading,
      body: answers != null && canRefresh
          ? KitRefresh(onRefresh: answers.refresh, child: list)
          : list,
    );
  }

  /// Remaining through the server's quota collector.
  Widget _buildCollector(BuildContext context) {
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
    final monitored = widget.controller.quotaMonitor.sources.isNotEmpty;
    // A reading the collector gave, whose account facts belong in Details.
    final reported = snapshot != null && snapshot.canShowWindows
        ? snapshot
        : null;

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
                label: quotaProviderLabel(l10n, provider),
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
        // Stopping acts on a collector that answers; a missing one has
        // nothing to stop (slice-close-misc).
        if (consented &&
            _overview.providerSupported &&
            _overview.failure?.kind != QuotaFailureKind.unsupported) ...[
          gap(tokens.sectionGap),
          KitRowGroup(
            margin: EdgeInsetsDirectional.zero,
            children: [
              KitRow(
                key: const ValueKey('quota-stop'),
                leading: KitRow.icon(context, AppIconography.unlink),
                title: l10n.quotaStopCollector(_serverName(l10n)),
                titleMaxLines: 2,
                supporting: TextSpan(text: l10n.quotaStopCollectorDetail),
                supportingMaxLines: 2,
                onTap: _stopUsingCollector,
              ),
            ],
          ),
        ],
      ],
      // Monitored sources belong to any saved server, so they stay listed
      // when this server's reading is unavailable; with none there is
      // nothing to list (the reading's own row turns its alert on).
      if (monitored) ...[
        gap(tokens.sectionGap),
        QuotaMonitorSection(
          controller: widget.controller,
          onOpenNotifications: _openNotifications,
          shownAbove: shownSource,
        ),
      ],
      gap(tokens.sectionGap),
      // Every technical value on the page, once, last and folded
      // (KIT-33): where the collector is, what it reported about the
      // account and when, and how it reads.
      KitDetailsFold(
        key: const ValueKey('quota-details'),
        values: [
          if (!detached)
            KitTechnicalValue(
              l10n.quotaCollectorAddressLabel,
              origin ?? l10n.quotaUnknownSource,
            ),
          if (!detached && _overview.providerSupported)
            KitTechnicalValue(
              l10n.providerQuotaRouteLabel,
              quotaPathFor(_overview.provider),
            ),
          if (consented && reported != null) ...[
            if (reported.account.plan case final plan?)
              KitTechnicalValue(l10n.quotaPlanLabel, plan),
            KitTechnicalValue(
              l10n.quotaReadAtLabel,
              DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).add_jm().format(reported.fetchedAt.toLocal()),
            ),
          ],
        ],
        notes: [
          if (!_overview.consented) l10n.quotaSetupTrustNote,
          if (consented && reported != null) ?_sourceBoundNote(reported, l10n),
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
  }

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
        l10n.quotaNeedsCollector(_serverName(l10n)),
        key: const ValueKey('quota-setup-title'),
        role: KitTextRole.headline,
      ),
      SizedBox(height: tokens.space2),
      KitText(l10n.quotaSetupDescription, role: KitTextRole.secondary),
      SizedBox(height: tokens.space3),
      _CollectorHowTo(serverName: _serverName(l10n)),
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
      // No collector on this server: what it needs and how to get it. A
      // retry cannot install it, so no second Refresh beside the top bar's
      // and no controls for a collector that is not there.
      if (_overview.failure case final failure?
          when failure.kind == QuotaFailureKind.unsupported) ...[
        KitNotice(
          key: const ValueKey('quota-failure'),
          icon: AppIconography.info,
          message: _failure(failure, l10n),
        ),
        SizedBox(height: tokens.space3),
        _CollectorHowTo(serverName: _serverName(l10n)),
        SizedBox(height: tokens.space4),
      ] else if (_overview.failure case final failure?) ...[
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
            serverName: _serverName(l10n),
            monitorSaveFailed: _monitorSaveFailed,
            monitorOffer: l10n.quotaMonitorOffer(
              quotaProviderLabel(l10n, snapshot.provider),
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

/// The collector's reading for one provider account, as answers: one
/// sentence row per reported window under the provider and server it came
/// from ("About 75% left in this 5-hour window · resets at 12:05 PM"), then
/// the alert for it. Windows the collector did not report are left out;
/// the plan, the reading time and the account caveats are technical and
/// live in the page's Details (slice-close-misc).
class _QuotaReport extends StatelessWidget {
  final ProviderQuotaSnapshot snapshot;
  final bool stale;
  final DateTime now;
  final bool monitorSaveFailed;

  /// This account's monitored source, or null when it is not monitored.
  final QuotaMonitorTarget? monitored;
  final ConnectionController controller;
  final String serverName;

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
    required this.serverName,
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
    final provider = quotaProviderLabel(l10n, snapshot.provider);
    final reported = [
      for (final window in snapshot.windows) ?quotaAnswerWindowOf(window),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stale) ...[
          KitNotice(
            key: const ValueKey('quota-stale'),
            icon: AppIconography.history,
            message: l10n.quotaStale,
          ),
          SizedBox(height: tokens.space3),
        ],
        if (snapshot.ordinaryUsageAllowed == false) ...[
          KitNotice(
            key: const ValueKey('quota-use-blocked'),
            icon: AppIconography.blocked,
            message: l10n.quotaUseBlocked,
          ),
          SizedBox(height: tokens.space3),
        ],
        if (reported.isEmpty)
          KitNotice(
            key: const ValueKey('quota-no-windows'),
            icon: AppIconography.info,
            message: l10n.quotaCollectorNoWindows(provider, serverName),
          )
        else
          // One row per reported window, each an answer sentence.
          KitRowGroup(
            key: const ValueKey('quota-windows'),
            margin: EdgeInsetsDirectional.zero,
            label: l10n.quotaCollectorFrom(provider, serverName),
            children: [
              for (final window in reported)
                QuotaAnswerRow(
                  key: ValueKey('quota-window-${window.id}'),
                  barKey: ValueKey('quota-window-bar-${window.id}'),
                  window: window,
                  now: now,
                  asOf: stale ? snapshot.fetchedAt : null,
                ),
            ],
          ),
        // The alert acts on this account, so it follows its rows. Once it
        // is on, its threshold and Stop live here, not twice.
        SizedBox(height: tokens.sectionGap),
        if (monitored case final target?)
          QuotaMonitorControls(
            key: const ValueKey('quota-account-monitoring'),
            controller: controller,
            target: target,
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
      ],
    );
  }
}

/// The Codex account's answer: whose limits these are, one sentence row
/// per window (with the reading's age when it is the last known one), the
/// alert switch, or why there is no answer and what to do.
class _AccountAnswer extends StatelessWidget {
  const _AccountAnswer({
    required this.answers,
    required this.serverName,
    required this.alertSaving,
    required this.alertSaveFailed,
    required this.onAlertChanged,
    required this.onRetry,
    required this.onSignIn,
  });

  final QuotaAnswersController answers;
  final String serverName;
  final bool alertSaving;
  final bool alertSaveFailed;
  final ValueChanged<bool> onAlertChanged;
  final VoidCallback? onRetry;
  final VoidCallback onSignIn;

  static const _alertAt = 0.8;

  String _age(AppLocalizations l10n, Duration age) => age.inDays >= 1
      ? l10n.quotaAnswerAgeDays(age.inDays)
      : age.inHours >= 1
      ? l10n.quotaAnswerAgeHours(age.inHours)
      : age.inMinutes >= 1
      ? l10n.quotaAnswerAgeMinutes(age.inMinutes)
      : l10n.quotaAnswerAgeNow;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final alertAt = NumberFormat.percentPattern(locale).format(_alertAt);
    final snapshot = answers.snapshot;
    final windows = snapshot?.windows ?? const <QuotaAnswerWindow>[];
    final stale = answers.stale;
    final age = answers.age;
    final now = answers.clock();
    final retry = KitAction(
      key: const ValueKey('quota-retry'),
      label: l10n.quotaRefresh,
      icon: AppIconography.retry,
      onPressed: onRetry,
      disabledReason: onRetry == null ? l10n.quotaLoading : null,
    );
    // Why there is no fresh answer; a retained one stays shown with its age.
    final Widget? status = switch (answers.status) {
      QuotaAnswerStatus.ready => null,
      _ when answers.loading => null,
      QuotaAnswerStatus.needsSignIn => KitRowGroup(
        margin: EdgeInsetsDirectional.zero,
        children: [
          KitRow(
            key: const ValueKey('quota-answer-sign-in'),
            leading: KitRow.icon(context, AppIconography.login),
            title: l10n.quotaAnswerSignIn(serverName),
            titleMaxLines: 2,
            supporting: TextSpan(text: l10n.quotaAnswerSignInDetail),
            supportingMaxLines: 2,
            trailing: const KitChevron(),
            onTap: onSignIn,
          ),
        ],
      ),
      QuotaAnswerStatus.unsupported => KitNotice(
        key: const ValueKey('quota-answer-unsupported'),
        icon: AppIconography.info,
        message: l10n.quotaAnswerUnsupported,
      ),
      QuotaAnswerStatus.invalidResponse => KitNotice.error(
        key: const ValueKey('quota-answer-invalid'),
        message: l10n.quotaAnswerInvalid,
        retry: retry,
      ),
      _ when snapshot != null && windows.isEmpty => KitNotice(
        key: const ValueKey('quota-answer-empty'),
        icon: AppIconography.info,
        message: l10n.quotaAnswerNoWindows,
      ),
      _ when snapshot == null => KitNotice.error(
        key: const ValueKey('quota-answer-unavailable'),
        message: l10n.quotaAnswerUnavailable,
        retry: retry,
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (snapshot == null && status == null)
          KitText(l10n.quotaLoading, role: KitTextRole.secondary),
        ?status,
        if (windows.isNotEmpty) ...[
          if (status != null) SizedBox(height: tokens.space4),
          if (stale && age != null) ...[
            KitNotice(
              key: const ValueKey('quota-answer-age'),
              icon: AppIconography.history,
              message: _age(l10n, age),
            ),
            SizedBox(height: tokens.space3),
          ],
          if (answers.attentionRequired) ...[
            // A limit nearly used is a warning, not a request: the warning
            // glyph in the neutral tone (LOOK-4: amber means needs you).
            KitNotice(
              key: const ValueKey('quota-answer-attention'),
              icon: AppIconography.warning,
              message: l10n.quotaAnswerAttention(alertAt),
            ),
            SizedBox(height: tokens.space3),
          ],
          KitRowGroup(
            key: const ValueKey('quota-answer'),
            margin: EdgeInsetsDirectional.zero,
            label: l10n.quotaAnswerFromCodex(serverName),
            children: [
              for (final window in windows)
                QuotaAnswerRow(
                  key: ValueKey('quota-answer-${window.id}'),
                  window: window,
                  now: now,
                  asOf: stale ? snapshot!.observedAt : null,
                ),
            ],
          ),
          SizedBox(height: tokens.sectionGap),
          KitRowGroup(
            margin: EdgeInsetsDirectional.zero,
            children: [
              KitSwitchRow(
                switchKey: const ValueKey('quota-answer-alert'),
                leading: KitRow.icon(
                  context,
                  AppIconography.notificationImportant,
                ),
                title: l10n.quotaAnswerAlert(alertAt),
                supporting: l10n.quotaAnswerAlertDetail,
                value: answers.alert80Enabled,
                onChanged: alertSaving ? null : onAlertChanged,
                disabledReason: alertSaving ? l10n.quotaMonitorSaving : null,
                below: alertSaveFailed
                    ? KitNotice.error(
                        key: const ValueKey('quota-answer-alert-failed'),
                        message: l10n.quotaAnswerAlertSaveFailed,
                      )
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// How to get the quota collector: the operator's steps, unfolded in place
/// (the page's one Details fold holds the technical values), and the full
/// guide on the web. The app installs nothing; this is a request to whoever
/// runs the server.
class _CollectorHowTo extends StatelessWidget {
  const _CollectorHowTo({required this.serverName});

  final String serverName;

  /// The collector's full guide, opened through [openExternalLink].
  static const guideUrl =
      'https://github.com/Eslamasabry/opencode-mobile-next/blob/master/'
      'tool/quota/README.md';

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final steps = [
      l10n.quotaCollectorStepInstall(serverName),
      l10n.quotaCollectorStepRoute,
      l10n.quotaCollectorStepRetry,
    ];
    return KitRowGroup(
      margin: EdgeInsetsDirectional.zero,
      children: [
        KitExpandRow(
          headerKey: const ValueKey('quota-collector-how-to'),
          leading: KitRow.icon(context, AppIconography.info),
          title: l10n.quotaCollectorHowTo,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                tokens.gutter,
                tokens.space1,
                tokens.gutter,
                tokens.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) SizedBox(height: tokens.space2),
                    KitText(steps[i], role: KitTextRole.secondary),
                  ],
                  SizedBox(height: tokens.space2),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: KitButton.tertiary(
                      key: const ValueKey('quota-collector-guide'),
                      label: l10n.quotaCollectorGuide,
                      icon: AppIconography.externalLink,
                      onPressed: () =>
                          unawaited(openExternalLink(context, guideUrl)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
