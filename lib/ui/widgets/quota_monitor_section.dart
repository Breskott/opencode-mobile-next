import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/provider_quota.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_monitor.dart';
import '../app_theme.dart';
import '../kit/kit_menu.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_surface.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import 'phone_server_card.dart' show serverDisplayName;

String _sourceOrigin(String value, String fallback) {
  try {
    return Uri.parse(value).origin;
  } catch (_) {
    return fallback;
  }
}

String quotaProviderLabel(AppLocalizations l10n, QuotaProvider provider) =>
    switch (provider) {
      QuotaProvider.codex => l10n.quotaCodex,
      QuotaProvider.claude => l10n.quotaClaude,
      QuotaProvider.minimax => l10n.quotaMiniMax,
      QuotaProvider.glm => l10n.quotaGlm,
    };

/// The thresholds a source offers, plus its own when it is none of them.
const _thresholdChoices = <double>[50, 75, 90, 100];

/// Quota monitoring inside Usage → Remaining: every monitored source, on any
/// saved server, with its latest reading, its alert threshold and Stop. It
/// never connects to or switches the active server; the page's own Refresh
/// reads again.
///
/// How an alert notifies (device alerts, quiet hours, Wi-Fi only) is shared
/// with the rest of the app and lives in Notifications; [onOpenNotifications]
/// opens it from the "Quota alerts" row.
///
/// [shownAbove] is the source the page already shows with its own account
/// (its threshold and Stop live there); it is left out here so nothing is
/// shown twice (owner rule 2026-09-27).
///
/// Built from kit parts only (kit-v2 §9): a headline, the Quota alerts row,
/// then one [KitSurface.panel] per source, or an empty notice that says how
/// to add one.
class QuotaMonitorSection extends StatelessWidget {
  final ConnectionController controller;
  final VoidCallback onOpenNotifications;
  final QuotaMonitorTarget? shownAbove;
  const QuotaMonitorSection({
    super.key,
    required this.controller,
    required this.onOpenNotifications,
    this.shownAbove,
  });

  @override
  Widget build(BuildContext context) {
    final monitor = controller.quotaMonitor;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final above = shownAbove;
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final all = monitor.sources;
        final shown = [
          for (final target in all)
            if (above == null ||
                target.profileID != above.profileID ||
                target.provider != above.provider)
              target,
        ];
        return Column(
          key: const ValueKey('quota-monitor-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitText(l10n.quotaMonitorTitle, role: KitTextRole.headline),
            SizedBox(height: tokens.space3),
            KitRowGroup(
              margin: EdgeInsetsDirectional.zero,
              children: [
                KitRow(
                  key: const ValueKey('quota-monitor-notification-settings'),
                  leading: KitRow.icon(
                    context,
                    AppIconography.notificationImportant,
                  ),
                  title: l10n.quotaAlertsRowTitle,
                  supporting: TextSpan(text: l10n.quotaAlertsRowSupporting),
                  supportingMaxLines: 2,
                  trailing: const KitChevron(),
                  onTap: onOpenNotifications,
                ),
              ],
            ),
            SizedBox(height: tokens.space3),
            if (all.isEmpty)
              KitNotice(
                key: const ValueKey('quota-monitor-empty'),
                message: l10n.quotaMonitorEmpty,
                liveRegion: false,
              ),
            for (final target in shown) ...[
              _Source(
                key: ValueKey(
                  'quota-source-${target.profileID}-${target.provider.name}',
                ),
                controller: controller,
                target: target,
              ),
              SizedBox(height: tokens.space3),
            ],
          ],
        );
      },
    );
  }
}

/// A monitored source's own controls: the percentage used that alerts,
/// Check now and Stop monitoring, the last two named with the provider and
/// server they act on. Used in a
/// source's panel and, for the source the Remaining page shows, inside that
/// account's block ([grouped]: the rows in their own panel, with icons).
class QuotaMonitorControls extends StatefulWidget {
  final ConnectionController controller;
  final QuotaMonitorTarget target;
  final bool grouped;
  const QuotaMonitorControls({
    super.key,
    required this.controller,
    required this.target,
    this.grouped = false,
  });
  @override
  State<QuotaMonitorControls> createState() => _QuotaMonitorControlsState();
}

class _QuotaMonitorControlsState extends State<QuotaMonitorControls> {
  bool saving = false;

  /// Check now is reading this source; the row says so until it returns.
  bool checking = false;

  Future<void> _checkNow() async {
    setState(() => checking = true);
    try {
      await widget.controller.quotaMonitor.refreshSource(widget.target);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  /// The last change failed to save: shown in place, under the rows, until
  /// the next change succeeds (never a passing toast, G1).
  bool saveFailed = false;

  Future<void> _change(Future<bool> Function() action) async {
    setState(() {
      saving = true;
      saveFailed = false;
    });
    final success = await action();
    if (!mounted) {
      return;
    }
    setState(() {
      saving = false;
      saveFailed = !success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitor = widget.controller.quotaMonitor, target = widget.target;
    final rules = monitor.rulesFor(target.profileID, target.provider);
    final profile = widget.controller.store.profiles
        .where((p) => p.id == target.profileID)
        .firstOrNull;
    if (rules == null || profile == null) {
      return const SizedBox.shrink();
    }
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final grouped = widget.grouped;
    final padding = grouped ? null : EdgeInsetsDirectional.zero;
    // Only the threshold is this source's own. Alerts, Wi-Fi only and quiet
    // hours are shared and set in Notifications; the record's copies of them
    // are carried over untouched for a build that has not migrated.
    Future<bool> policy({required double threshold}) => monitor.setPolicy(
      target.profileID,
      target.provider,
      notifications: rules.notifications,
      threshold: threshold,
      wifiOnly: rules.wifiOnly,
      quietStart: rules.quietStart,
      quietEnd: rules.quietEnd,
    );
    String percent(double value) =>
        l10n.quotaBudgetPercent(value.toInt().toString());
    final server = serverDisplayName(
      profile,
      l10n,
      among: widget.controller.store.profiles,
    );
    final id = '${target.profileID}-${target.provider.name}';
    final provider = quotaProviderLabel(l10n, target.provider);
    final rows = <Widget>[
      Builder(
        builder: (rowContext) => KitRow(
          key: ValueKey('quota-threshold-$id'),
          padding: padding,
          leading: grouped
              ? KitRow.icon(context, AppIconography.notificationImportant)
              : null,
          title: l10n.quotaMonitorThreshold,
          supporting: saving ? TextSpan(text: l10n.quotaMonitorSaving) : null,
          enabled: !saving,
          trailing: KitRowValue(percent(rules.threshold)),
          onTap: saving
              ? null
              : () => showKitMenu(
                  rowContext,
                  semanticsLabel: l10n.quotaMonitorThreshold,
                  items: [
                    for (final value in {..._thresholdChoices, rules.threshold})
                      KitMenuItem(
                        label: percent(value),
                        checked: value == rules.threshold,
                        onSelected: () {
                          if (value == rules.threshold) return;
                          _change(() => policy(threshold: value));
                        },
                      ),
                  ],
                ),
        ),
      ),
      // Reads this one source again now, instead of waiting for the next
      // cycle, which checks at most three sources at a time.
      KitRow(
        key: ValueKey('quota-check-now-$id'),
        padding: padding,
        leading: grouped ? KitRow.icon(context, AppIconography.retry) : null,
        title: l10n.quotaMonitorCheckNow(provider, server),
        titleMaxLines: 2,
        supporting: checking ? TextSpan(text: l10n.quotaMonitorChecking) : null,
        enabled: !saving && !checking,
        disabledReason: checking
            ? l10n.quotaMonitorChecking
            : saving
            ? l10n.quotaMonitorSaving
            : null,
        onTap: saving || checking ? null : _checkNow,
      ),
      KitRow(
        key: ValueKey('quota-stop-monitoring-$id'),
        padding: padding,
        leading: grouped
            ? KitRow.icon(context, AppIconography.stopCircle)
            : null,
        title: l10n.quotaMonitorDisable(provider, server),
        titleMaxLines: 2,
        enabled: !saving,
        disabledReason: saving ? l10n.quotaMonitorSaving : null,
        onTap: saving
            ? null
            : () => _change(
                () => monitor.disable(target.profileID, target.provider),
              ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (grouped)
          KitRowGroup(margin: EdgeInsetsDirectional.zero, children: rows)
        else
          ...rows,
        if (saveFailed) ...[
          SizedBox(height: tokens.space2),
          KitNotice(
            key: const ValueKey('quota-monitor-save-failed'),
            message: l10n.quotaMonitorSaveFailed,
            tone: AppStatusTone.failure,
          ),
        ],
      ],
    );
  }
}

class _Source extends StatelessWidget {
  final ConnectionController controller;
  final QuotaMonitorTarget target;
  const _Source({super.key, required this.controller, required this.target});

  @override
  Widget build(BuildContext context) {
    final monitor = controller.quotaMonitor;
    final rules = monitor.rulesFor(target.profileID, target.provider);
    final profile = controller.store.profiles
        .where((p) => p.id == target.profileID)
        .firstOrNull;
    if (rules == null || profile == null) {
      return const SizedBox.shrink();
    }
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String when(DateTime time) =>
        DateFormat.yMMMd(locale).add_jm().format(time.toLocal());
    final observation = monitor.observationFor(
      target.profileID,
      target.provider,
    );
    final snapshot = observation.snapshot;
    final (status, tone) = switch (observation.status) {
      QuotaMonitorStatus.disabled => (
        l10n.quotaMonitorDisabled,
        AppStatusTone.neutral,
      ),
      QuotaMonitorStatus.waiting => (
        l10n.quotaMonitorWaiting,
        AppStatusTone.neutral,
      ),
      QuotaMonitorStatus.checking => (
        l10n.quotaMonitorChecking,
        AppStatusTone.progress,
      ),
      QuotaMonitorStatus.current => (
        l10n.quotaMonitorCurrent,
        AppStatusTone.ok,
      ),
      QuotaMonitorStatus.paused => (
        l10n.quotaMonitorPaused,
        AppStatusTone.attention,
      ),
      QuotaMonitorStatus.wifiRequired => (
        l10n.quotaMonitorWifiRequired,
        AppStatusTone.attention,
      ),
      QuotaMonitorStatus.unavailable => (
        l10n.quotaUnavailable,
        AppStatusTone.failure,
      ),
      QuotaMonitorStatus.sourceChanged => (
        l10n.quotaMonitorSourceChanged,
        AppStatusTone.attention,
      ),
    };
    final origin = Uri.tryParse(profile.baseUrl)?.hasScheme == true
        ? _sourceOrigin(profile.baseUrl, l10n.quotaUnknownSource)
        : null;
    return KitSurface.panel(
      title: l10n.quotaSourceTitle(
        serverDisplayName(profile, l10n, among: controller.store.profiles),
        quotaProviderLabel(l10n, target.provider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (origin != null)
            KitText.mono(origin, tone: KitTextTone.secondary)
          else
            KitText(
              l10n.quotaUnknownSource,
              role: KitTextRole.secondary,
              tone: KitTextTone.secondary,
            ),
          SizedBox(height: tokens.space3),
          KitNotice(message: status, tone: tone, liveRegion: false),
          if (snapshot != null) ...[
            SizedBox(height: tokens.space2),
            KitText(
              l10n.quotaChecked(when(snapshot.fetchedAt)),
              role: KitTextRole.secondary,
              tone: KitTextTone.secondary,
            ),
            for (var i = 0; i < snapshot.windows.length; i++)
              KitRow(
                padding: EdgeInsetsDirectional.zero,
                title: l10n.quotaOtherWindow(i + 1),
                supportingMaxLines: 2,
                supporting: TextSpan(
                  text: snapshot.windows[i].resetsAt == null
                      ? l10n.quotaResetUnknown
                      : l10n.quotaResetAt(when(snapshot.windows[i].resetsAt!)),
                ),
                trailing: KitRowValue(
                  snapshot.windows[i].remainingPercent == null
                      ? l10n.quotaNotReported
                      : l10n.quotaRemaining(
                          '${snapshot.windows[i].remainingPercent!.toStringAsFixed(1)}%',
                        ),
                  chevron: false,
                ),
              ),
          ],
          QuotaMonitorControls(controller: controller, target: target),
        ],
      ),
    );
  }
}
