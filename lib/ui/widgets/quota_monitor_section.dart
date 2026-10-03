import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/provider_quota.dart';
import '../../domain/quota_answers.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_monitor.dart';
import '../app_theme.dart';
import '../kit/kit_menu.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress_row.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_surface.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import 'phone_server_card.dart' show serverDisplayName;

/// A collector window as an answer, or null when the collector did not
/// report how much of it is used (such a window says nothing, so it is
/// not shown).
QuotaAnswerWindow? quotaAnswerWindowOf(ProviderQuotaWindow window) {
  final used = window.usedPercent;
  if (used == null) return null;
  final seconds = window.durationSeconds;
  return QuotaAnswerWindow(
    id: window.id,
    usedPercent: used,
    durationMinutes: seconds != null && seconds % 60 == 0
        ? seconds ~/ 60
        : null,
    resetsAt: window.resetsAt,
  );
}

/// "About 40% left this week · resets Tue": what is left of [window],
/// rounded, over its length when reported, and when it resets. An unknown
/// length or reset is left out, never guessed; a passed reset says so and
/// never assumes the allowance came back.
String quotaAnswerSentence(
  AppLocalizations l10n,
  String locale,
  QuotaAnswerWindow window,
  DateTime now,
) {
  final left = NumberFormat.percentPattern(
    locale,
  ).format(window.remainingPercent / 100);
  final minutes = window.durationMinutes;
  final amount = window.isWeekly
      ? l10n.quotaAnswerLeftWeek(left)
      : minutes != null && minutes > 0 && minutes % 1440 == 0
      ? l10n.quotaAnswerLeftDays(left, minutes ~/ 1440)
      : minutes != null && minutes > 0 && minutes % 60 == 0
      ? l10n.quotaAnswerLeftHours(left, minutes ~/ 60)
      : l10n.quotaAnswerLeft(left);
  final reset = window.resetsAt?.toLocal();
  if (reset == null) return amount;
  final local = now.toLocal();
  final String when;
  if (!local.isBefore(reset)) {
    when = l10n.quotaAnswerResetPassed;
  } else if (reset.year == local.year &&
      reset.month == local.month &&
      reset.day == local.day) {
    when = l10n.quotaAnswerResetsAt(DateFormat.jm(locale).format(reset));
  } else if (reset.difference(local) < const Duration(days: 6)) {
    when = l10n.quotaAnswerResetsOn(DateFormat.E(locale).format(reset));
  } else {
    when = l10n.quotaAnswerResetsOn(DateFormat.MMMd(locale).format(reset));
  }
  return '$amount · $when';
}

/// A quota window as one sentence row (KitProgressRow): the title says what
/// is left, over which window and when it resets; the bar fills with what
/// is used and its words say so, so bar and words agree. The same row on
/// every Remaining path: a Codex account, a collector reading and a
/// monitored source.
class QuotaAnswerRow extends StatelessWidget {
  const QuotaAnswerRow({
    super.key,
    required this.window,
    required this.now,
    this.asOf,
    this.barKey,
  });

  final QuotaAnswerWindow window;
  final DateTime now;
  final DateTime? asOf;
  final Key? barKey;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final percent = NumberFormat.percentPattern(locale)
      ..maximumFractionDigits = 1;
    return KitProgressRow(
      key: barKey,
      leading: KitRow.icon(context, AppIconography.usageRing),
      title: quotaAnswerSentence(l10n, locale, window, now),
      value: window.usedPercent / 100,
      valueLabel: l10n.quotaUsed(percent.format(window.usedPercent / 100)),
      asOf: asOf,
    );
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
/// then one [KitSurface.panel] per source. The page shows it only while
/// something is monitored: a reading's own row turns its alert on, so an
/// empty list has nothing to say.
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

/// A monitored source's own controls, in their own row group: the
/// percentage used that alerts, Check now and Stop monitoring, the last two
/// named with the provider and server they act on. Under a monitored
/// source's readings and, for the source the Remaining page shows, under
/// that account's rows.
class QuotaMonitorControls extends StatefulWidget {
  final ConnectionController controller;
  final QuotaMonitorTarget target;
  const QuotaMonitorControls({
    super.key,
    required this.controller,
    required this.target,
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
          leading: KitRow.icon(context, AppIconography.notificationImportant),
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
        leading: KitRow.icon(context, AppIconography.retry),
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
        leading: KitRow.icon(context, AppIconography.stopCircle),
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
        KitRowGroup(margin: EdgeInsetsDirectional.zero, children: rows),
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

/// One monitored source on any saved server: its readings as answer rows
/// under "{server} · {provider}", a line only when the checks are not
/// current (waiting, paused, stopped), then its own controls.
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
    final observation = monitor.observationFor(
      target.profileID,
      target.provider,
    );
    final snapshot = observation.snapshot;
    final current = observation.status == QuotaMonitorStatus.current;
    final server = serverDisplayName(
      profile,
      l10n,
      among: controller.store.profiles,
    );
    final provider = quotaProviderLabel(l10n, target.provider);
    // A current source says nothing: its rows are the answer. Anything
    // else is said in words beside a neutral mark (LOOK-4, LOOK-5).
    final (String, IconData)? status = switch (observation.status) {
      QuotaMonitorStatus.current => null,
      QuotaMonitorStatus.disabled => (
        l10n.quotaMonitorDisabled,
        AppIconography.info,
      ),
      QuotaMonitorStatus.waiting => (
        l10n.quotaMonitorWaiting,
        AppIconography.history,
      ),
      QuotaMonitorStatus.checking => (
        l10n.quotaMonitorChecking,
        AppIconography.retry,
      ),
      QuotaMonitorStatus.paused => (
        l10n.quotaMonitorPaused,
        AppIconography.info,
      ),
      QuotaMonitorStatus.wifiRequired => (
        l10n.quotaMonitorWifiRequired,
        AppIconography.network,
      ),
      QuotaMonitorStatus.unavailable => (
        l10n.quotaUnavailable,
        AppIconography.warning,
      ),
      QuotaMonitorStatus.sourceChanged => (
        l10n.quotaMonitorSourceChanged,
        AppIconography.warning,
      ),
    };
    final windows = [
      if (snapshot != null)
        for (final window in snapshot.windows) ?quotaAnswerWindowOf(window),
    ];
    // The monitor's own clock, so a reset reads the same as its checks.
    final now = monitor.clock();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitRowGroup(
          margin: EdgeInsetsDirectional.zero,
          label: l10n.quotaSourceTitle(server, provider),
          children: [
            if (status case (final text, final icon))
              KitRow(
                key: ValueKey(
                  'quota-source-status-${target.profileID}-'
                  '${target.provider.name}',
                ),
                leading: KitRow.icon(context, icon),
                title: text,
                titleMaxLines: 3,
              )
            else if (windows.isEmpty)
              KitRow(
                leading: KitRow.icon(context, AppIconography.info),
                title: l10n.quotaCollectorNoWindows(provider, server),
                titleMaxLines: 3,
              ),
            for (final window in windows)
              QuotaAnswerRow(
                key: ValueKey(
                  'quota-source-window-${target.profileID}-'
                  '${target.provider.name}-${window.id}',
                ),
                window: window,
                now: now,
                // A reading the checks could not renew keeps its time.
                asOf: current ? null : snapshot?.fetchedAt,
              ),
          ],
        ),
        SizedBox(height: tokens.space2),
        QuotaMonitorControls(controller: controller, target: target),
      ],
    );
  }
}
