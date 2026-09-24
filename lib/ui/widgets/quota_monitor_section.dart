import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/provider_quota.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/provider_quota_monitor.dart';

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

/// Quota monitoring inside Usage → Remaining: every monitored source, on any
/// saved server, with its latest reading, its alert threshold, Refresh and
/// Disable. It never connects to or switches the active server.
///
/// How an alert notifies (device alerts, quiet hours, Wi-Fi only) is shared
/// with the rest of the app and lives in Notifications; [onOpenNotifications]
/// is the link to it.
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
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) => Column(
        key: const ValueKey('quota-monitor-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.quotaMonitorTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(l10n.quotaMonitorRuntime),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('quota-monitor-notification-settings'),
              onPressed: onOpenNotifications,
              child: Text(l10n.monitorNotificationSettings),
            ),
          ),
          if (monitor.sources.isEmpty) Text(l10n.quotaMonitorEmpty),
          for (final target in monitor.sources) ...[
            const Divider(height: 32),
            _Source(controller: controller, target: target),
          ],
        ],
      ),
    );
  }
}

class _Source extends StatefulWidget {
  final ConnectionController controller;
  final QuotaMonitorTarget target;
  const _Source({required this.controller, required this.target});
  @override
  State<_Source> createState() => _SourceState();
}

class _SourceState extends State<_Source> {
  bool saving = false;
  Future<void> _change(Future<bool> Function() action) async {
    setState(() => saving = true);
    final success = await action();
    if (!mounted) {
      return;
    }
    setState(() => saving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).quotaMonitorSaveFailed,
          ),
        ),
      );
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.quotaSourceTitle(
            profile.name,
            quotaProviderLabel(l10n, target.provider),
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          _sourceOrigin(profile.baseUrl, l10n.quotaUnknownSource),
          textDirection: Uri.tryParse(profile.baseUrl)?.hasScheme == true
              ? TextDirection.ltr
              : null,
        ),
        const SizedBox(height: 8),
        Text(switch (observation.status) {
          QuotaMonitorStatus.disabled => l10n.quotaMonitorDisabled,
          QuotaMonitorStatus.waiting => l10n.quotaMonitorWaiting,
          QuotaMonitorStatus.checking => l10n.quotaMonitorChecking,
          QuotaMonitorStatus.current => l10n.quotaMonitorCurrent,
          QuotaMonitorStatus.paused => l10n.quotaMonitorPaused,
          QuotaMonitorStatus.wifiRequired => l10n.quotaMonitorWifiRequired,
          QuotaMonitorStatus.unavailable => l10n.quotaUnavailable,
          QuotaMonitorStatus.sourceChanged => l10n.quotaMonitorSourceChanged,
        }),
        if (snapshot != null) ...[
          Text(
            l10n.quotaChecked(
              DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).add_jm().format(snapshot.fetchedAt.toLocal()),
            ),
          ),
          for (var i = 0; i < snapshot.windows.length; i++) ...[
            const SizedBox(height: 8),
            Text(
              l10n.quotaOtherWindow(i + 1),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              snapshot.windows[i].remainingPercent == null
                  ? l10n.quotaNotReported
                  : l10n.quotaRemaining(
                      '${snapshot.windows[i].remainingPercent!.toStringAsFixed(1)}%',
                    ),
            ),
            Text(
              snapshot.windows[i].resetsAt == null
                  ? l10n.quotaResetUnknown
                  : l10n.quotaResetAt(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).add_jm().format(
                        snapshot.windows[i].resetsAt!.toLocal(),
                      ),
                    ),
            ),
          ],
        ],
        DropdownButton<double>(
          key: ValueKey(
            'quota-threshold-${target.profileID}-${target.provider.name}',
          ),
          value: rules.threshold,
          isExpanded: true,
          items: [
            for (final value in {50.0, 75.0, 90.0, 100.0, rules.threshold})
              DropdownMenuItem(
                value: value,
                child: Text(l10n.quotaBudgetPercent(value.toInt().toString())),
              ),
          ],
          onChanged: saving
              ? null
              : (value) {
                  if (value != null) _change(() => policy(threshold: value));
                },
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: monitor.refreshing || !monitor.runningAllowed
                  ? null
                  : () => monitor.refreshSource(target),
              child: Text(l10n.quotaRefresh),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () => _change(
                      () => monitor.disable(target.profileID, target.provider),
                    ),
              child: Text(l10n.quotaMonitorDisable),
            ),
          ],
        ),
      ],
    );
  }
}
