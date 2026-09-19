/// Shared pieces of the AI Team controls (TEAM-204; 02-ux §5.2, §6):
/// the receipt chip every control shows after a tap, the composer-style
/// field the message and objective sheets use (the chat composer's
/// surface without its attachments, commands or history), and the
/// two-step confirmation the destructive controls go through.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/mutation_store.dart';
import '../app_theme.dart';
import 'confirm_sheet.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The receipt word for a record's status (02-ux §6, short form).
String teamControlReceiptWord(AppLocalizations l10n, MutationStatus status) =>
    switch (status) {
      MutationStatus.sent => l10n.teamUiControlReceiptSent,
      MutationStatus.confirmed => l10n.teamUiControlReceiptConfirmed,
      MutationStatus.unconfirmed => l10n.teamUiControlReceiptUnconfirmed,
      MutationStatus.rejected => l10n.teamUiControlReceiptRefused,
    };

/// The control's name for a receipt line: the button label the person
/// tapped, so the chip reads "Nudge · Sent".
String teamControlWord(AppLocalizations l10n, MutationRequest request) =>
    switch (request.kind) {
      MutationKind.message => l10n.teamUiControlMessage,
      MutationKind.controlAgent => switch (request.action) {
        AgentControlAction.nudge || null => l10n.teamUiControlNudge,
        AgentControlAction.pause => l10n.teamUiControlPause,
        AgentControlAction.resume ||
        AgentControlAction.start => l10n.teamUiControlResume,
        AgentControlAction.stop => l10n.teamUiControlStop,
        AgentControlAction.restart => l10n.teamUiControlRestart,
      },
      MutationKind.cancelRun => l10n.teamUiControlCancelRun,
      MutationKind.assign => l10n.teamUiControlReassign,
      MutationKind.respond => l10n.teamUiReceiptAnswered,
      MutationKind.approveMerge => l10n.teamUiMergeApprove,
      MutationKind.merge => l10n.teamUiMergeMerge,
      MutationKind.createWork => l10n.teamUiControlCreateWork,
    };

/// "Nudge · Sent": glyph + words in the receipt's tone, the host's reason
/// under a refusal, and Retry when the record may be retried. Never
/// colour-only: the state word is always in the text.
class TeamReceiptChip extends StatelessWidget {
  const TeamReceiptChip({
    super.key,
    required this.record,
    this.control,
    this.onRetry,
  });

  final MutationRecord record;

  /// The control's name; defaults to [teamControlWord].
  final String? control;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final (icon, tone) = switch (record.status) {
      MutationStatus.sent => (AppIconography.waiting, AppStatusTone.progress),
      MutationStatus.confirmed => (
        AppIconography.checkCircle,
        AppStatusTone.ok,
      ),
      MutationStatus.unconfirmed => (
        AppIconography.warning,
        AppStatusTone.attention,
      ),
      MutationStatus.rejected => (AppIconography.error, AppStatusTone.failure),
    };
    final color = AppTheme.statusColor(theme, tone);
    final line = l10n.teamUiControlReceiptLine(
      control ?? teamControlWord(l10n, record.request),
      teamControlReceiptWord(l10n, record.status),
    );
    final reason = record.status == MutationStatus.rejected
        ? record.receipt?.message
        : null;
    final retry = onRetry;
    return Semantics(
      liveRegion: true,
      child: Column(
        key: ValueKey('team-receipt-${record.key}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: .5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        line,
                        key: const ValueKey('team-receipt-line'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (retry != null && record.canRetry)
                TextButton(
                  key: const ValueKey('team-receipt-retry'),
                  onPressed: retry,
                  child: Text(l10n.teamUiControlReceiptRetry),
                ),
            ],
          ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                reason,
                key: const ValueKey('team-receipt-reason'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The chat composer's surface — rounded, low container, primary border
/// on focus — holding one multi-line field and a filled send button. No
/// attachments, commands or history: an agent gets words only (§5.2).
class TeamComposerField extends StatefulWidget {
  const TeamComposerField({
    super.key,
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.onSend,
    this.minLines = 1,
    this.maxLines = 6,
    this.autofocus = true,
    this.fieldKey,
    this.sendKey,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final VoidCallback onSend;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final Key? fieldKey;
  final Key? sendKey;
  final bool enabled;

  @override
  State<TeamComposerField> createState() => _TeamComposerFieldState();
}

class _TeamComposerFieldState extends State<TeamComposerField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TeamComposerField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = _focus.hasFocus;
    final canSend = widget.enabled && widget.controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused
              ? scheme.primary.withValues(alpha: .8)
              : scheme.outlineVariant.withValues(alpha: .65),
          width: focused ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: widget.fieldKey,
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hint,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton.filled(
              key: widget.sendKey,
              tooltip: widget.sendLabel,
              onPressed: canSend ? widget.onSend : null,
              icon: const Icon(AppIconography.send),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two-step gate every destructive control goes through: the first
/// tap opened this, the second (the confirming button) returns true;
/// backing out returns false and nothing is sent. Error tone.
Future<bool> confirmTeamControl(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Key? sheetKey,
  Key? confirmKey,
}) => showConfirmSheet(
  context,
  title: title,
  message: message,
  confirmLabel: confirmLabel,
  cancelLabel: _copy(context).teamUiControlKeep,
  icon: AppIconography.warning,
  destructive: true,
  sheetKey: sheetKey,
  confirmKey: confirmKey,
);
