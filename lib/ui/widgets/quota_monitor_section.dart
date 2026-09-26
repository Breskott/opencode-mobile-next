import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/provider_quota.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_monitor.dart';
import '../app_theme.dart';
import '../kit/kit_action_stack.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_menu.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
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
/// saved server, with its latest reading, its alert threshold, Refresh and
/// Disable. It never connects to or switches the active server.
///
/// How an alert notifies (device alerts, quiet hours, Wi-Fi only) is shared
/// with the rest of the app and lives in Notifications; [onOpenNotifications]
/// is the link to it.
///
/// Built from kit parts only (kit-v2 §9): a headline and its note, the
/// Notifications link as a tertiary action, then one [KitSurface.panel] per
/// source, or an empty notice that says how to add one.
class QuotaMonitorSection extends StatelessWidget {
  final ConnectionController controller;
  final VoidCallback onOpenNotifications;
  const QuotaMonitorSection({
    super.key,
    required this.controller,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final monitor = controller.quotaMonitor;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) => Column(
        key: const ValueKey('quota-monitor-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitText(l10n.quotaMonitorTitle, role: KitTextRole.headline),
          SizedBox(height: tokens.space2),
          KitText(
            l10n.quotaMonitorRuntime,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
          SizedBox(height: tokens.space1),
          KitActionStack(
            tertiary: [
              KitAction(
                key: const ValueKey('quota-monitor-notification-settings'),
                label: l10n.monitorNotificationSettings,
                onPressed: onOpenNotifications,
              ),
            ],
          ),
          SizedBox(height: tokens.space3),
          if (monitor.sources.isEmpty)
            KitNotice(
              key: const ValueKey('quota-monitor-empty'),
              message: l10n.quotaMonitorEmpty,
              liveRegion: false,
            ),
          for (final target in monitor.sources) ...[
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
      ),
    );
  }
}

class _Source extends StatefulWidget {
  final ConnectionController controller;
  final QuotaMonitorTarget target;
  const _Source({super.key, required this.controller, required this.target});
  @override
  State<_Source> createState() => _SourceState();
}

class _SourceState extends State<_Source> {
  bool saving = false;

  /// The last change failed to save: shown in place, under the source,
  /// until the next change succeeds (never a passing toast, G1).
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    String when(DateTime time) =>
        DateFormat.yMMMd(locale).add_jm().format(time.toLocal());
    final observation = monitor.observationFor(
      target.profileID,
      target.provider,
    );
    final snapshot = observation.snapshot;
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
    final refreshReason = monitor.refreshing
        ? l10n.quotaMonitorChecking
        : !monitor.runningAllowed
        ? l10n.quotaMonitorPaused
        : null;
    return KitSurface.panel(
      title: l10n.quotaSourceTitle(
        serverDisplayName(
          profile,
          l10n,
          among: widget.controller.store.profiles,
        ),
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
          Builder(
            builder: (rowContext) => KitRow(
              key: ValueKey(
                'quota-threshold-${target.profileID}-${target.provider.name}',
              ),
              padding: EdgeInsetsDirectional.zero,
              title: l10n.quotaMonitorThreshold,
              supporting: saving
                  ? TextSpan(text: l10n.quotaMonitorSaving)
                  : null,
              enabled: !saving,
              trailing: KitRowValue(percent(rules.threshold)),
              onTap: saving
                  ? null
                  : () => showKitMenu(
                      rowContext,
                      semanticsLabel: l10n.quotaMonitorThreshold,
                      items: [
                        for (final value in {
                          ..._thresholdChoices,
                          rules.threshold,
                        })
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
          if (saveFailed) ...[
            SizedBox(height: tokens.space2),
            KitNotice(
              key: const ValueKey('quota-monitor-save-failed'),
              message: l10n.quotaMonitorSaveFailed,
              tone: AppStatusTone.failure,
            ),
          ],
          SizedBox(height: tokens.space2),
          KitActionStack(
            tertiary: [
              KitAction(
                label: l10n.quotaRefresh,
                icon: AppIconography.retry,
                onPressed: refreshReason != null
                    ? null
                    : () => monitor.refreshSource(target),
                disabledReason: refreshReason,
              ),
              KitAction(
                label: l10n.quotaMonitorDisable,
                onPressed: saving
                    ? null
                    : () => _change(
                        () =>
                            monitor.disable(target.profileID, target.provider),
                      ),
                disabledReason: saving ? l10n.quotaMonitorSaving : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
