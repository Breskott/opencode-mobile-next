/// Settings › Plugins › AI Team › "On this phone" (TEAM-302, 02-ux §9):
/// the phone-hosted supervisor's status, Start / Stop, the "Android stopped
/// the team" line with Start again, the Keep-it-running tips (spike-phone
/// §3g), Remove from this phone, and the one-time re-offer of the optional
/// onboarding step that was skipped.
///
/// Reads and drives [TermuxTeamRuntime] only; the plugin's own controller
/// is left to the sheet around this section.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/orchestration_store.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../../termux/team_runtime.dart';
import '../app_theme.dart';
import 'confirm_sheet.dart';
import 'team_phone_onboarding.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The one-time ADB mitigation of Android's phantom process killer, exactly
/// as docs/qa/ai-team/spike-phone-2026-09.md §3g records it.
const teamPhoneAdbCommands = '''
pkg install android-tools
adb pair <ip:port from the pairing dialog>        # 6-digit code
adb connect <ip:port from the Wireless debugging screen>
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell device_config set_sync_disabled_for_tests persistent
adb shell device_config put activity_manager max_phantom_processes 2147483647''';

/// The status line of the section for [status] (null while it is read).
String teamPhoneStatusLine(AppLocalizations l10n, TeamRuntimeStatus? status) {
  if (status == null) return l10n.teamUiPhoneStatusChecking;
  if (status.busy) {
    return switch (status.phase) {
      TeamRuntimePhase.starting => l10n.teamUiPhoneStatusStarting,
      TeamRuntimePhase.stopping => l10n.teamUiPhoneStatusStopping,
      _ => l10n.teamUiPhoneStatusWorking(status.verb),
    };
  }
  switch (status.phase) {
    case TeamRuntimePhase.ready:
      if (status.killedByAndroid) return l10n.teamUiPhoneStatusStopped;
      if (!status.isReady) return l10n.teamUiPhoneStatusUnreachable(status.url);
      return l10n.teamUiPhoneStatusRunning(status.agents ?? 0);
    case TeamRuntimePhase.failed:
      return l10n.teamUiPhoneStatusFailed;
    case TeamRuntimePhase.unknown:
      return l10n.teamUiPhoneStatusUnknown;
    case TeamRuntimePhase.idle:
      return status.installed
          ? l10n.teamUiPhoneStatusInstalled
          : l10n.teamUiPhoneStatusNotInstalled;
    case TeamRuntimePhase.installed:
      return l10n.teamUiPhoneStatusInstalled;
    case TeamRuntimePhase.cityReady:
    case TeamRuntimePhase.stopped:
      return l10n.teamUiPhoneStatusStopped;
    case TeamRuntimePhase.removing:
    case TeamRuntimePhase.stopping:
    case TeamRuntimePhase.starting:
    case TeamRuntimePhase.queued:
    case TeamRuntimePhase.downloading:
    case TeamRuntimePhase.verifying:
    case TeamRuntimePhase.installingPackages:
    case TeamRuntimePhase.creatingCity:
      return l10n.teamUiPhoneStatusWorking(status.verb);
  }
}

/// The "On this phone" section of the AI Team sheet for the Termux profile.
class TeamPhoneSection extends StatefulWidget {
  const TeamPhoneSection({
    super.key,
    required this.connection,
    required this.profile,
    this.runtime,
    this.onOpenSetup,
    this.onRemoved,
  });

  final ConnectionController connection;
  final ServerProfile profile;
  final TermuxTeamRuntime? runtime;

  /// Opens the Termux setup screen (to set up or resume); defaults to the
  /// `/termux-setup` route.
  final VoidCallback? onOpenSetup;

  /// Called after Remove finished, so the sheet can close.
  final VoidCallback? onRemoved;

  @override
  State<TeamPhoneSection> createState() => _TeamPhoneSectionState();
}

class _TeamPhoneSectionState extends State<TeamPhoneSection> {
  TermuxTeamRuntime get _runtime => widget.runtime ?? teamPhoneRuntime;

  bool? _supported;
  TeamRuntimeStatus? _status;
  bool _busy = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final supported = await _runtime.supportsAiTeam;
    if (!mounted) return;
    setState(() => _supported = supported);
    if (!supported) return;
    await _read();
  }

  Future<void> _read() async {
    TeamRuntimeStatus status;
    try {
      status = await _runtime.status();
    } on TermuxBridgeException {
      status = TeamRuntimeStatus.unreadable;
    }
    if (!mounted) return;
    setState(() => _status = status);
    if (status.busy) {
      _poll ??= Timer.periodic(teamPhonePollInterval, (_) => _read());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _run(Future<TeamRuntimeStatus> Function() verb) async {
    final l10n = _copy(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await verb();
      if (!mounted) return;
      if (status.isReady &&
          widget.profile.orchestration?.hostMode !=
              OrchestrationHostMode.phone) {
        await teamPhoneEnable(
          widget.connection,
          widget.profile,
          _runtime,
          status,
        );
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        if (status.phase == TeamRuntimePhase.failed) {
          _error = l10n.teamUiPhoneActionFailed(
            status.lastError ?? status.reason ?? status.rawPhase,
          );
        }
      });
    } on TermuxBridgeException catch (error) {
      if (!mounted) return;
      setState(() => _error = l10n.teamUiPhoneActionFailed(error.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(_runtime.start);

  Future<void> _stop() async {
    final l10n = _copy(context);
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.teamUiPhoneStopTitle,
      message: l10n.teamUiPhoneStopBody,
      confirmLabel: l10n.teamUiPhoneStopConfirm,
      cancelLabel: l10n.teamUiKeep,
      icon: AppIconography.stopCircle,
      sheetKey: const ValueKey('team-phone-stop-sheet'),
      confirmKey: const ValueKey('team-phone-stop-confirm'),
    );
    if (!confirmed || !mounted) return;
    await _run(_runtime.stop);
  }

  Future<void> _remove() async {
    final l10n = _copy(context);
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.teamUiPhoneRemoveTitle,
      message: l10n.teamUiPhoneRemoveBody,
      confirmLabel: l10n.teamUiPhoneRemoveConfirm,
      cancelLabel: l10n.teamUiKeep,
      icon: AppIconography.delete,
      destructive: true,
      sheetKey: const ValueKey('team-phone-remove-sheet'),
      confirmKey: const ValueKey('team-phone-remove-confirm'),
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _runtime.remove();
      if (!mounted) return;
      if (status.phase == TeamRuntimePhase.failed) {
        setState(
          () => _error = l10n.teamUiPhoneActionFailed(
            status.lastError ?? status.reason ?? status.rawPhase,
          ),
        );
        return;
      }
      // Removal turns the plugin off for the profile (03 §3), the same
      // way Turn off does: the controller's cache goes with it.
      final connection = widget.connection;
      final profile = widget.profile;
      final current = connection.orchestration;
      if (current != null && current.profileId == profile.id) {
        await current.remove();
      } else {
        await connection.orchestrationStore.sweep(profile.id);
      }
      profile.orchestration = null;
      await connection.store.upsert(profile);
      await connection.orchestrationStore.setPhoneOffer(
        profile.id,
        PhoneOffer.dismissed,
      );
      connection.syncOrchestration();
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.teamUiPhoneRemoved)));
      widget.onRemoved?.call();
    } on TermuxBridgeException catch (error) {
      if (!mounted) return;
      setState(() => _error = l10n.teamUiPhoneActionFailed(error.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSetup() {
    final open = widget.onOpenSetup;
    if (open != null) return open();
    Navigator.of(context).pushNamed('/termux-setup');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final supported = _supported;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.mutedOf(theme),
      height: 1.35,
    );
    final children = <Widget>[
      Text(
        l10n.teamUiPhoneSectionTitle,
        key: const ValueKey('team-phone-section-title'),
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
    ];
    if (supported == false) {
      children.add(
        Text(
          l10n.teamUiPhoneNotAvailable,
          key: const ValueKey('team-phone-not-available'),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
      );
    } else {
      final status = _status;
      final installed = status?.installed ?? false;
      final running = status?.isReady ?? false;
      final killed = status?.killedByAndroid ?? false;
      final working = _busy || (status?.busy ?? false);
      final canStart = status != null && !working && !running && status.hasCity;
      final versions = status?.versions ?? const {};
      final tone = status == null || working
          ? AppStatusTone.progress
          : running
          ? AppStatusTone.ok
          : killed || status.phase == TeamRuntimePhase.failed
          ? AppStatusTone.attention
          : AppStatusTone.neutral;
      children.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                AppIconography.statusDot,
                size: 14,
                color: AppTheme.statusColor(theme, tone),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamPhoneStatusLine(l10n, status),
                    key: const ValueKey('team-phone-status'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (installed && versions.isNotEmpty)
                    Text(
                      l10n.teamUiPhoneVersions(
                        versions['gc'] ?? '—',
                        versions['bd'] ?? '—',
                        versions['dolt'] ?? '—',
                      ),
                      key: const ValueKey('team-phone-versions'),
                      textDirection: TextDirection.ltr,
                      style: muted,
                    ),
                  if (status?.project.isNotEmpty ?? false)
                    Text(
                      l10n.teamUiPhoneProjectLine(status!.project),
                      textDirection: TextDirection.ltr,
                      style: muted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (killed) ...[
          const SizedBox(height: 8),
          Text(
            l10n.teamUiPhoneKilled,
            key: const ValueKey('team-phone-killed-line'),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 6),
          Text(
            error,
            key: const ValueKey('team-phone-error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (killed)
              FilledButton.icon(
                key: const ValueKey('team-phone-start-again'),
                onPressed: working ? null : _start,
                icon: const Icon(AppIconography.play),
                label: Text(l10n.teamUiPhoneStartAgain),
              )
            else if (running)
              OutlinedButton.icon(
                key: const ValueKey('team-phone-stop'),
                onPressed: working ? null : _stop,
                icon: const Icon(AppIcons.stop),
                label: Text(l10n.teamUiPhoneStop),
              )
            else if (canStart)
              FilledButton.tonalIcon(
                key: const ValueKey('team-phone-start'),
                onPressed: _start,
                icon: const Icon(AppIconography.play),
                label: Text(l10n.teamUiPhoneStart),
              )
            else if (status != null && !working)
              FilledButton.tonalIcon(
                key: const ValueKey('team-phone-open-setup'),
                onPressed: _openSetup,
                icon: const Icon(AppIconography.tools),
                label: Text(l10n.teamUiPhoneOpenSetup),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ListTile(
          key: const ValueKey('team-phone-keep-running'),
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 24,
          leading: Icon(
            AppIconography.batteryWarning,
            size: 22,
            color: AppTheme.mutedOf(theme),
          ),
          title: Text(l10n.teamUiPhoneKeepRunningTitle),
          subtitle: Text(l10n.teamUiPhoneKeepRunningSubtitle),
          trailing: const Icon(AppIconography.chevronRight, size: 20),
          onTap: () => showTeamPhoneTipsSheet(context),
        ),
        if (installed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('team-phone-remove'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: working ? null : _remove,
              icon: const Icon(AppIconography.delete, size: 18),
              label: Text(l10n.teamUiPhoneRemove),
            ),
          ),
      ]);
    }
    return Column(
      key: const ValueKey('team-phone-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// The Keep-it-running sheet: wake lock, battery setting and the phantom
/// process killer's one-time ADB switch, with the commands copyable.
Future<void> showTeamPhoneTipsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final l10n = _copy(context);
        final theme = Theme.of(context);
        final body = theme.textTheme.bodyMedium?.copyWith(height: 1.4);
        Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: body)),
            ],
          ),
        );
        return SingleChildScrollView(
          key: const ValueKey('team-phone-tips-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.teamUiPhoneKeepRunningTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.teamUiPhoneTipsIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedOf(theme),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              tip(AppIconography.lightning, l10n.teamUiPhoneTipWakeLock),
              tip(AppIconography.batteryCharging, l10n.teamUiPhoneTipBattery),
              tip(AppIconography.blocked, l10n.teamUiPhoneTipPhantom),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    teamPhoneAdbCommands,
                    key: const ValueKey('team-phone-tips-commands'),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 12,
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('team-phone-tips-copy'),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: teamPhoneAdbCommands),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text(l10n.teamUiPhoneTipsCopied)),
                  );
                },
                icon: const Icon(AppIcons.copy, size: 18),
                label: Text(l10n.teamUiPhoneTipsCopy),
              ),
            ],
          ),
        );
      },
    );

/// Settings › Plugins: the one-time re-offer of the skipped onboarding step
/// (03-onboarding §2). Present only for the Termux profile, while the
/// runtime supports a team, the plugin is off, and the offer state is
/// `skipped`; Not now writes `dismissed` and it never returns.
class TeamPhoneReofferCard extends StatefulWidget {
  const TeamPhoneReofferCard({
    super.key,
    required this.connection,
    required this.profile,
    this.runtime,
    this.onSetUp,
  });

  final ConnectionController connection;
  final ServerProfile profile;
  final TermuxTeamRuntime? runtime;

  /// Opens the Termux setup screen; defaults to the `/termux-setup` route.
  final VoidCallback? onSetUp;

  @override
  State<TeamPhoneReofferCard> createState() => _TeamPhoneReofferCardState();
}

class _TeamPhoneReofferCardState extends State<TeamPhoneReofferCard> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final store = widget.connection.orchestrationStore;
    if (widget.profile.orchestration != null ||
        store.phoneOffer(widget.profile.id) != PhoneOffer.skipped) {
      return;
    }
    final supported = await (widget.runtime ?? teamPhoneRuntime).supportsAiTeam;
    if (mounted && supported) setState(() => _show = true);
  }

  Future<void> _dismiss() async {
    await widget.connection.orchestrationStore.setPhoneOffer(
      widget.profile.id,
      PhoneOffer.dismissed,
    );
    if (mounted) setState(() => _show = false);
  }

  void _setUp() {
    final open = widget.onSetUp;
    if (open != null) return open();
    Navigator.of(context).pushNamed('/termux-setup');
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('plugins-phone-offer'),
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIconography.phone,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.teamUiPhoneReofferTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.teamUiPhoneReofferBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mutedOf(theme),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('plugins-phone-offer-dismiss'),
                  onPressed: _dismiss,
                  child: Text(l10n.teamUiPhoneReofferDismiss),
                ),
                FilledButton.tonal(
                  key: const ValueKey('plugins-phone-offer-set-up'),
                  onPressed: _setUp,
                  child: Text(l10n.teamUiPhoneReofferAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
