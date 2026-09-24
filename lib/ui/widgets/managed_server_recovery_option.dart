import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../termux/managed_server_recovery.dart';
import '../app_theme.dart';
import '../kit/kit.dart';

/// "Restart after a crash": the opt-in foreground recovery of the server
/// this app runs in Termux, as one switch row in the phone server's
/// Options (docs/design/phone-server-screens-cleanup-2026-09-24.md §1, §2).
/// It moved here from the servers list, which is for choosing a server.
///
/// Under the switch: the attempts used (the budget survives app restarts),
/// what recovery is doing, any error with its way out, and the Android
/// caveat. It reads and writes [ManagedServerRecovery] only; nothing here
/// installs, updates or starts anything by itself.
class ManagedServerRecoveryOption extends StatefulWidget {
  const ManagedServerRecoveryOption({
    super.key,
    required this.prefs,
    required this.profileID,
  });

  final SharedPreferences prefs;
  final String profileID;

  @override
  State<ManagedServerRecoveryOption> createState() =>
      _ManagedServerRecoveryOptionState();
}

class _ManagedServerRecoveryOptionState
    extends State<ManagedServerRecoveryOption> {
  ManagedServerRecovery? _recovery;

  /// Null: no error. True: saving or revoking the setting failed. False:
  /// checking recovery failed.
  bool? _policyError;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(ManagedServerRecoveryOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefs != widget.prefs ||
        oldWidget.profileID != widget.profileID) {
      _recovery?.removeListener(_changed);
      _bind();
    }
  }

  void _bind() {
    _recovery = platformCapabilities.supportsTermux
        ? ManagedServerRecovery.forProfile(widget.prefs, widget.profileID)
        : null;
    _recovery?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recovery?.removeListener(_changed);
    super.dispose();
  }

  Future<void> _set(bool enabled) async {
    setState(() => _policyError = null);
    try {
      await _recovery?.setEnabled(enabled);
    } catch (_) {
      if (mounted) setState(() => _policyError = true);
    }
  }

  Future<void> _retryCheck(ManagedServerRecovery recovery) async {
    try {
      await recovery.retryCheck();
    } catch (_) {
      if (mounted) setState(() => _policyError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = _recovery;
    if (recovery == null) return const SizedBox.shrink();
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.mutedOf(theme),
    );
    final problem = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );
    // The counter and the caveat matter once recovery is on (or has been):
    // off, the row's own line says what it would do.
    final used = recovery.enabled || recovery.attempts > 0;
    final notes = <Widget>[
      if (used)
        Text(
          l10n.managedRecoveryAttempts(recovery.attempts),
          key: const ValueKey('managed-recovery-attempts'),
          style: muted,
        ),
      if (recovery.exhausted) Text(l10n.managedRecoveryExhausted, style: muted),
      if (recovery.enabled && recovery.paused && recovery.error == null)
        Text(l10n.managedRecoveryBackground, style: muted),
      if (recovery.busy) Text(l10n.managedRecoveryChecking, style: muted),
      if (recovery.nextAttemptAt case final next?)
        if (recovery.enabled && !recovery.exhausted)
          Text(
            l10n.managedRecoveryNext(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(next)),
            ),
            style: muted,
          ),
      if (recovery.error case final error?)
        Text(switch (error) {
          ManagedRecoveryError.settingsUnreadable =>
            l10n.managedRecoverySettingsUnreadable,
          ManagedRecoveryError.enableFailed => l10n.managedRecoveryEnableFailed,
          ManagedRecoveryError.ownershipChanged =>
            l10n.managedRecoveryOwnershipChanged,
          ManagedRecoveryError.uncertainResult => l10n.managedRecoveryUncertain,
        }, style: problem),
      if (_policyError case final revoke?)
        Text(
          revoke
              ? l10n.managedRecoveryRevokeFailed
              : l10n.managedRecoverySaveFailed,
          style: problem,
        ),
    ];
    final actions = <KitAction>[
      if (_policyError == true)
        KitAction(
          label: l10n.managedRecoveryRetryDisable,
          onPressed: () => _set(false),
        ),
      if (recovery.enabled && recovery.error != null)
        KitAction(
          label: l10n.managedRecoveryCheck,
          onPressed: recovery.busy ? null : () => _retryCheck(recovery),
        ),
      if (recovery.exhausted)
        KitAction(
          label: l10n.managedRecoveryReset,
          onPressed: recovery.busy ? null : () => _set(true),
        ),
    ];
    if (recovery.enabled) {
      notes.add(
        Text(
          l10n.managedHealthLifetime,
          key: const ValueKey('managed-recovery-caveat'),
          style: muted,
        ),
      );
    }
    return Column(
      key: const ValueKey('managed-recovery-option'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitSwitchRow(
          switchKey: const ValueKey('managed-recovery-switch'),
          leading: KitRow.icon(context, AppIconography.restart),
          title: l10n.managedRecoveryRowTitle,
          supporting: l10n.managedRecoveryRowDetail,
          value: recovery.enabled,
          onChanged: recovery.busy && !recovery.enabled ? null : _set,
        ),
        if (notes.isNotEmpty || actions.isNotEmpty)
          Padding(
            // Under the row's text, past its 32 dp icon and 12 dp gap.
            padding: const EdgeInsetsDirectional.fromSTEB(60, 0, 16, 8),
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final note in notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: note,
                    ),
                  if (actions.isNotEmpty) KitActionBlock(tertiary: actions),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
