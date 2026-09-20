part of '../chat_screen.dart';

/// Opens the per-session approval settings: ask each time (default) or let
/// this phone answer permission requests with "once" while connected, plus
/// whether subagent sessions inherit that choice.
Future<void> showSessionApprovalsSheet(
  BuildContext context, {
  required ConnectionController controller,
  required String sessionID,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => LayoutBuilder(
    builder: (context, constraints) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: constraints.maxHeight * .9),
      child: SessionApprovalsSheet(
        controller: controller,
        sessionID: sessionID,
      ),
    ),
  ),
);

/// The approvals sheet body. Every control writes through the controller and
/// re-reads the effective setting, so an inheriting child session shows its
/// parent's choice until it takes one of its own.
class SessionApprovalsSheet extends StatelessWidget {
  const SessionApprovalsSheet({
    super.key,
    required this.controller,
    required this.sessionID,
  });

  final ConnectionController controller;
  final String sessionID;

  Future<void> _write(
    BuildContext context,
    SessionAutoApproval? setting,
  ) async {
    final strings = _chatL10n(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await controller.setSessionAutoApproval(sessionID, setting);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(strings.approvalsUiSaveFailed(productErrorText(error))),
        ),
      );
    }
  }

  /// Turning it on is confirmed first: it changes every conversation on the
  /// server, including ones that do not exist yet. Turning it off is not.
  Future<void> _setEverything(BuildContext context, bool value) async {
    final strings = _chatL10n(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (value) {
      final confirmed = await showConfirmSheet(
        context,
        title: strings.approvalsUiEverythingConfirmTitle,
        message: strings.approvalsUiEverythingConfirmBody,
        confirmLabel: strings.approvalsUiEverythingConfirmAction,
        icon: AppIconography.warning,
        destructive: true,
        sheetKey: const Key('approvals-everything-confirm'),
        confirmKey: const Key('approvals-everything-confirm-action'),
      );
      if (!confirmed) return;
    }
    try {
      await controller.setApprovesEverything(value);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(strings.approvalsUiSaveFailed(productErrorText(error))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _chatL10n(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final effective = controller.autoApprovalFor(sessionID);
        final setting = effective.setting;
        final hasParent = controller.sessionsById[sessionID]?.parentID != null;
        return SingleChildScrollView(
          key: const Key('session-approvals-sheet'),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.approvalsUiTitle,
                style: theme.textTheme.titleMedium,
              ),
              if (effective.serverWide) ...[
                const SizedBox(height: 8),
                Text(
                  strings.approvalsUiEverythingActive,
                  key: const Key('approvals-everything-active'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (effective.inherited) ...[
                const SizedBox(height: 12),
                _ApprovalsInheritedNote(
                  onOverride: () => unawaited(_write(context, setting)),
                ),
              ],
              const SizedBox(height: 8),
              RadioGroup<AutoApprovalMode>(
                groupValue: setting.mode,
                onChanged: (mode) {
                  if (mode == null || mode == setting.mode) return;
                  unawaited(
                    _write(
                      context,
                      SessionAutoApproval(
                        mode: mode,
                        // Inheritance is meaningless while asking; drop it so
                        // switching back on starts from the safe default.
                        inheritToChildren:
                            mode == AutoApprovalMode.autoOnce &&
                            setting.inheritToChildren,
                      ),
                    ),
                  );
                },
                child: Column(
                  children: [
                    RadioListTile<AutoApprovalMode>(
                      key: const Key('approvals-mode-ask'),
                      value: AutoApprovalMode.ask,
                      title: Text(strings.approvalsUiAskTitle),
                      subtitle: Text(strings.approvalsUiAskDetail),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<AutoApprovalMode>(
                      key: const Key('approvals-mode-auto'),
                      value: AutoApprovalMode.autoOnce,
                      title: Text(strings.approvalsUiAutoTitle),
                      subtitle: Text(strings.approvalsUiAutoDetail),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                key: const Key('approvals-inherit-switch'),
                value: setting.automatic && setting.inheritToChildren,
                onChanged: setting.automatic
                    ? (value) => unawaited(
                        _write(
                          context,
                          SessionAutoApproval(
                            mode: AutoApprovalMode.autoOnce,
                            inheritToChildren: value,
                          ),
                        ),
                      )
                    : null,
                title: Text(strings.approvalsUiInheritTitle),
                subtitle: Text(
                  setting.automatic
                      ? strings.approvalsUiInheritDetail
                      : strings.approvalsUiInheritUnavailable,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              if (effective.explicit && hasParent)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('approvals-follow-parent'),
                    onPressed: () => unawaited(_write(context, null)),
                    icon: const Icon(AppIconography.nested, size: 18),
                    label: Text(strings.approvalsUiFollowParent),
                  ),
                ),
              const Divider(height: 24),
              // The saved, server-wide choice. Error-coloured because it is
              // the one setting here that reaches conversations you are not
              // looking at.
              SwitchListTile(
                key: const Key('approvals-everything-switch'),
                value: controller.approvesEverything,
                activeThumbColor: theme.colorScheme.error,
                onChanged: (value) => unawaited(_setEverything(context, value)),
                title: Text(strings.approvalsUiEverythingTitle),
                subtitle: Text(strings.approvalsUiEverythingDetail),
                contentPadding: EdgeInsets.zero,
              ),
              if (setting.automatic) ...[
                const SizedBox(height: 8),
                _AutoApprovalRecord(
                  approved: controller.autoApprovedFor(sessionID),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIconography.info,
                    size: 18,
                    color: AppTheme.mutedOf(theme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.approvesEverything
                          ? strings.approvalsUiServerRulesNoteEverything
                          : strings.approvalsUiServerRulesNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedOf(theme),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                  key: const Key('approvals-done'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    MaterialLocalizations.of(context).closeButtonLabel,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What this phone approved automatically in the session since connecting:
/// the transparency half of a setting that removes prompts.
class _AutoApprovalRecord extends StatelessWidget {
  const _AutoApprovalRecord({required this.approved});

  final List<AutoApprovedPermission> approved;
  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _chatL10n(context);
    final recent = approved.reversed.take(_shown).toList();
    return Column(
      key: const Key('approvals-record'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.approvalsUiRecordTitle(approved.length),
          style: theme.textTheme.labelLarge,
        ),
        for (final entry in recent)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    permissionActionIcon(entry.permission),
                    size: 16,
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.approvalsUiAutoApproved(
                          permissionRequestTitle(
                            entry.permission,
                            l10n: strings,
                          ),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (entry.patterns.isNotEmpty)
                        Text(
                          entry.patterns.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: AppTheme.monoFamily,
                            fontSize: AppTheme.captionFontSize,
                            color: AppTheme.mutedOf(theme),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ApprovalsInheritedNote extends StatelessWidget {
  const _ApprovalsInheritedNote({required this.onOverride});

  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _chatL10n(context);
    return Container(
      key: const Key('approvals-inherited-note'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(AppIconography.nested, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.approvalsUiInheritedFrom,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.approvalsUiInheritedDetail,
            style: theme.textTheme.bodySmall,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('approvals-override'),
              onPressed: onOverride,
              child: Text(strings.approvalsUiOverride),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet, persistent strip above the composer while automatic approval is
/// on for this session. Never hidden while the setting is on: it names the
/// state, the last request answered (or that the session inherits), and —
/// when the app is disconnected — that approvals are paused. Two lines at
/// most so it never crowds the composer at large text scales; the full
/// record lives in the sheet it opens.
class _AutoApprovalIndicator extends StatelessWidget {
  const _AutoApprovalIndicator({
    super.key,
    required this.effective,
    required this.connected,
    required this.approved,
    required this.onOpen,
  });

  final EffectiveAutoApproval effective;
  final bool connected;
  final List<AutoApprovedPermission> approved;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _chatL10n(context);
    final last = approved.lastOrNull;
    final String label;
    final String? detail;
    if (!connected) {
      label = strings.approvalsUiIndicatorPaused;
      detail = strings.approvalsUiIndicatorPausedDetail;
    } else {
      label = strings.approvalsUiIndicatorOn;
      detail = last != null
          ? strings.approvalsUiAutoApproved(
              permissionRequestTitle(last.permission, l10n: strings),
            )
          : effective.inherited
          ? strings.approvalsUiInheritedFrom
          : null;
    }
    // A chip, not a bar: it sits in the strip above the composer on every
    // running turn, so it says its state in a few words and keeps the rest
    // (what was approved, inheritance, the switches) one tap away. The count
    // is what changes, which is what makes a glance worth it.
    // Never silent: once something has been approved, the chip names the
    // latest and counts them; before that it states the mode.
    // Short on the chip; the full wording (what was approved last, where
    // the setting comes from) is the accessibility label and the sheet.
    final text = !connected
        ? strings.chatStripAutoApprovePaused
        : approved.isEmpty
        ? strings.chatStripAutoApprove
        : '${strings.chatStripAutoApprove} · ${approved.length}';
    return Semantics(
      button: true,
      label: [label, ?detail, strings.approvalsUiOpenSettings].join('. '),
      excludeSemantics: true,
      child: Tooltip(
        // Long-press says the rest: what was approved last, or where the
        // setting comes from.
        message: [label, ?detail].join(' · '),
        child: ActionChip(
          key: const Key('auto-approval-indicator'),
          onPressed: onOpen,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          side: BorderSide.none,
          backgroundColor: connected
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          avatar: Icon(
            !connected
                ? AppIconography.permissions
                : effective.inherited
                ? AppIconography.nested
                : AppIconography.shield,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          label: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .62,
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
      ),
    );
  }
}
