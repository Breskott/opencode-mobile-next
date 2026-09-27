/// Settings › Plugins › AI Team › "On this phone" (TEAM-302, 02-ux §9):
/// the phone-hosted supervisor's status, Start / Stop, the "Android stopped
/// the team" line with Start again, the Keep-it-running tips (spike-phone
/// §3g), Delete from this phone, and the one-time re-offer of the optional
/// onboarding step that was skipped.
///
/// Reads and drives [TermuxTeamRuntime] only; the plugin's own controller
/// is left to the sheet around this section.
///
/// Kit only (shared-phone-1). The section and the tips sheet merge into the
/// team page and Keep running, and the re-offer card is removed (map:
/// merge-into:team-home, merge-into:keep-running, remove); until those
/// slices land they are rebuilt from kit parts with the least change.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/orchestration_store.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../../termux/team_runtime.dart';
import '../app_iconography.dart';
import '../app_theme.dart' show AppStatusTone;
import '../kit/kit_bidi.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_code_block.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_status_mark.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
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

/// The "On this phone" section of the AI Team sheet for the Termux profile:
/// one panel of rows (the state, Keep it running, Delete the team from this
/// phone, last and apart), what went wrong in a [KitNotice], and the one
/// act it needs now under it. Each act names the team ("Stop the team").
///
/// States: checking, not available (explains), not installed (offers the
/// phone setup), stopped, starting (working mark), running, stopped by
/// Android (says so, Start the team again), failed (the reason in words).
// revamp: merge-into:team-home (slice-P3.4)
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

  /// Stopping ends running work: the one stop question every team stop
  /// asks (map: team-phone-stop-sheet, "one stop tone").
  Future<void> _stop() async {
    final l10n = _copy(context);
    final confirmed = await showKitConfirm(
      context,
      title: l10n.teamUiPhoneStopTitle,
      body: l10n.teamUiPhoneStopBody,
      confirmLabel: l10n.teamPhoneStopTeam,
      kind: KitConfirmKind.stop,
      icon: AppIconography.stopCircle,
      sheetKey: const ValueKey('team-phone-stop-sheet'),
      confirmKey: const ValueKey('team-phone-stop-confirm'),
    );
    if (!confirmed || !mounted) return;
    await _run(_runtime.stop);
  }

  /// Says in plain words what goes, what stays and the space it frees (map:
  /// team-phone-remove-sheet), then deletes.
  Future<void> _remove() async {
    final l10n = _copy(context);
    TeamRuntimeManifest? manifest;
    try {
      manifest = await _runtime.manifest();
    } catch (_) {
      manifest = null;
    }
    if (!mounted) return;
    // The downloads' declared size; said only when the manifest declares it.
    final bytes = manifest?.totalBytes ?? 0;
    final confirmed = await showKitConfirm(
      context,
      title: l10n.teamUiPhoneRemoveTitle,
      body: l10n.teamPhoneRemoveBody,
      confirmLabel: l10n.teamPhoneRemoveConfirm,
      kind: KitConfirmKind.destructive,
      icon: AppIconography.delete,
      consequenceItems: [
        KitConsequence(l10n.teamPhoneRemoveLost, mark: KitConsequenceMark.lost),
        KitConsequence(l10n.teamPhoneRemoveKept, mark: KitConsequenceMark.kept),
        if (bytes > 0)
          KitConsequence(
            l10n.teamPhoneRemoveFrees((bytes / (1024 * 1024)).round()),
            key: const ValueKey('team-phone-remove-frees'),
          ),
      ],
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
      // The section itself now reads "Not installed" and the sheet closes:
      // the result is on screen, so there is no toast (KIT-34).
      setState(() => _status = status);
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
    final tokens = KitTokens.of(context);
    final supported = _supported;
    Widget gap() => SizedBox(height: tokens.space3);

    if (supported == false) {
      // phone.termux missing: explains (map whenMissing).
      return KitRowGroup(
        key: const ValueKey('team-phone-section'),
        label: l10n.teamUiPhoneSectionTitle,
        margin: EdgeInsets.zero,
        children: [
          Padding(
            padding: EdgeInsets.all(tokens.space4),
            child: KitNotice(
              key: const ValueKey('team-phone-not-available'),
              message: l10n.teamUiPhoneNotAvailable,
              icon: AppIconography.info,
              liveRegion: false,
            ),
          ),
        ],
      );
    }

    final status = _status;
    final installed = status?.installed ?? false;
    final running = status?.isReady ?? false;
    final killed = status?.killedByAndroid ?? false;
    final working = _busy || (status?.busy ?? false);
    final canStart = status != null && !running && status.hasCity;
    final failed = status?.phase == TeamRuntimePhase.failed;
    final versions = status?.versions ?? const {};
    final project = status?.project ?? '';

    final Widget mark = status == null || working
        ? const KitStatusMark(state: KitMarkState.working)
        : running
        ? const KitStatusMark(state: KitMarkState.done)
        : killed || failed
        ? const KitStatusMark(state: KitMarkState.failed)
        : const KitStatusMark(state: KitMarkState.waiting);

    final statusRow = Semantics(
      liveRegion: true,
      child: KitRow(
        leading: mark,
        title: teamPhoneStatusLine(l10n, status),
        titleKey: const ValueKey('team-phone-status'),
        titleMaxLines: 2,
        // Engine facts read left to right in any language.
        supporting: installed && versions.isNotEmpty
            ? TextSpan(
                text: KitBidi.ltr(
                  l10n.teamUiPhoneVersions(
                    versions['gc'] ?? '—',
                    versions['bd'] ?? '—',
                    versions['dolt'] ?? '—',
                  ),
                ),
              )
            : null,
        supportingKey: const ValueKey('team-phone-versions'),
        supportingMaxLines: 2,
        below: project.isEmpty
            ? null
            : KitText(
                l10n.teamUiPhoneProjectLine(KitBidi.ltr(project)),
                role: KitTextRole.secondary,
                tone: KitTextTone.secondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );

    final rows = <Widget>[
      statusRow,
      KitRow(
        key: const ValueKey('team-phone-keep-running'),
        leading: KitRow.icon(context, AppIconography.batteryWarning),
        title: l10n.teamUiPhoneKeepRunningTitle,
        supporting: TextSpan(text: l10n.teamUiPhoneKeepRunningSubtitle),
        supportingMaxLines: 2,
        trailing: const KitChevron(),
        onTap: () => showTeamPhoneTipsSheet(context),
      ),
      // Last and apart: the one row here that deletes (KitRow.destructive).
      if (installed && !working)
        KitRow(
          key: const ValueKey('team-phone-remove'),
          leading: KitRow.icon(context, AppIconography.delete),
          title: l10n.teamPhoneDeleteTeam,
          destructive: true,
          onTap: _remove,
        ),
    ];

    // While a step runs the status line says what it is doing; no
    // disabled buttons beside it (design standard §2).
    final KitAction? primary = working
        ? null
        : killed
        ? KitAction(
            key: const ValueKey('team-phone-start-again'),
            label: l10n.teamPhoneStartTeamAgain,
            icon: AppIconography.play,
            onPressed: _start,
          )
        : running
        ? null
        : canStart
        ? KitAction(
            key: const ValueKey('team-phone-start'),
            label: l10n.teamPhoneStartTeam,
            icon: AppIconography.play,
            onPressed: _start,
          )
        : status != null
        ? KitAction(
            key: const ValueKey('team-phone-open-setup'),
            label: l10n.teamUiPhoneOpenSetup,
            icon: AppIconography.tools,
            onPressed: _openSetup,
          )
        : null;
    final tertiary = [
      if (running && !working && !killed)
        KitAction(
          key: const ValueKey('team-phone-stop'),
          label: l10n.teamPhoneStopTeam,
          onPressed: _stop,
        ),
    ];
    final actions = KitActionBlock(primary: primary, tertiary: tertiary);

    return Column(
      key: const ValueKey('team-phone-section'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitRowGroup(
          label: l10n.teamUiPhoneSectionTitle,
          margin: EdgeInsets.zero,
          children: rows,
        ),
        if (killed) ...[
          gap(),
          KitNotice(
            key: const ValueKey('team-phone-killed-line'),
            message: l10n.teamUiPhoneKilled,
            icon: AppIconography.warning,
          ),
        ],
        if (_error case final error?) ...[
          gap(),
          KitNotice(
            key: const ValueKey('team-phone-error'),
            message: error,
            tone: AppStatusTone.failure,
          ),
        ],
        if (!actions.isEmpty) ...[gap(), actions],
      ],
    );
  }
}

/// The Keep-it-running sheet: wake lock, battery setting and the phantom
/// process killer's one-time ADB switch, with the commands copyable.
// revamp: merge-into:keep-running (no owning slice yet)
Future<void> showTeamPhoneTipsSheet(BuildContext context) {
  final l10n = _copy(context);
  return showKitSheet<void>(
    context,
    title: l10n.teamUiPhoneKeepRunningTitle,
    icon: AppIconography.batteryWarning,
    sheetKey: const ValueKey('team-phone-tips-sheet'),
    body: (context) {
      final tokens = KitTokens.of(context);
      Widget tip(IconData icon, String text) => Padding(
        padding: EdgeInsetsDirectional.only(bottom: tokens.space3),
        child: KitNotice(message: text, icon: icon, liveRegion: false),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitText(
            l10n.teamUiPhoneTipsIntro,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
          SizedBox(height: tokens.space4),
          tip(AppIconography.lightning, l10n.teamUiPhoneTipWakeLock),
          tip(AppIconography.batteryCharging, l10n.teamUiPhoneTipBattery),
          tip(AppIconography.blocked, l10n.teamUiPhoneTipPhantom),
          KitCodeBlock(
            text: teamPhoneAdbCommands,
            kind: KitCodeKind.command,
            copyLabel: l10n.teamUiPhoneTipsCopy,
            blockKey: const ValueKey('team-phone-tips-commands'),
            copyKey: const ValueKey('team-phone-tips-copy'),
          ),
        ],
      );
    },
  );
}

/// Settings › Plugins: the one-time re-offer of the skipped onboarding step
/// (03-onboarding §2). Present only for the Termux profile, while the
/// runtime supports a team, the plugin is off, and the offer state is
/// `skipped`; Not now writes `dismissed` and it never returns.
///
/// One [KitNotice.offer]: one sentence, Set up AI team, and Not now.
// revamp: remove (slice-P3.4)
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
    return KitNotice.offer(
      key: const ValueKey('plugins-phone-offer'),
      message: l10n.teamUiPhoneReofferTitle,
      icon: AppIconography.phone,
      action: KitAction(
        key: const ValueKey('plugins-phone-offer-set-up'),
        label: l10n.teamUiPhoneSetUp,
        onPressed: _setUp,
      ),
      onDismiss: () => unawaited(_dismiss()),
      dismissKey: const ValueKey('plugins-phone-offer-dismiss'),
      dismissLabel: l10n.teamUiPhoneReofferDismiss,
    );
  }
}
