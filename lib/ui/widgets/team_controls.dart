/// Shared pieces of the AI Team controls (TEAM-204; 02-ux §5.2, §6):
/// the receipt every control shows after a tap, the field the message and
/// objective sheets use, and the two-step confirmation the controls that
/// end work go through. Built from kit parts only (shared-team-1): the
/// receipt is a [KitReceipt], the field a [KitField], the confirmation a
/// [showKitConfirm].
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/mutation_store.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_field.dart';
import '../kit/kit_receipt.dart';
import '../kit/kit_sheet.dart';

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

/// "Nudge · Sent": the control's name and its state in words, beside the
/// state's own mark, the host's reason on a refusal, and Try again when the
/// record may be retried. Never colour-only: the state word is always in
/// the text.
///
/// Retired by shared-team-1: use [KitReceipt]. A thin forwarding wrapper
/// (STANDARDS KIT-43 forbids `@Deprecated`) that maps [MutationStatus] to
/// [KitReceiptState]. The receipt names the act in every state (KitReceipt's
/// `automatic` form: "the label names the act in every state and the
/// state's own mark stays beside it"), so a person who tapped Nudge reads
/// "Nudge · Sent", then "Nudge · Confirmed", never a bare "Sent".
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
    final control = this.control ?? teamControlWord(l10n, record.request);
    final state = switch (record.status) {
      MutationStatus.sent => KitReceiptState.sent,
      MutationStatus.confirmed => KitReceiptState.confirmed,
      MutationStatus.unconfirmed => KitReceiptState.notConfirmed,
      MutationStatus.rejected => KitReceiptState.refused,
    };
    final reason = record.status == MutationStatus.rejected
        ? record.receipt?.message?.trim()
        : null;
    final retry = onRetry;
    return KitReceipt(
      key: ValueKey('team-receipt-${record.key}'),
      state: state,
      automatic: true,
      label: l10n.teamUiControlReceiptLine(
        control,
        teamControlReceiptWord(l10n, record.status),
      ),
      reason: reason == null || reason.isEmpty ? null : reason,
      onRetry: retry != null && record.canRetry ? () => retry() : null,
      retryKey: const ValueKey('team-receipt-retry'),
    );
  }
}

/// The field an agent's message and a task's objective are typed in: a
/// multi-line [KitField] with its send action at the end. No attachments,
/// commands or history: an agent gets words only (§5.2).
///
/// Retired by shared-team-1: use [KitField] with
/// `kind: KitFieldKind.multiline` and an `action`. A thin forwarding
/// wrapper (STANDARDS KIT-43); [hint] becomes the field's visible label
/// unless [label] names it.
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
    this.label,
    this.disabledReason,
    this.draft,
  });

  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final VoidCallback onSend;

  /// Kept for the old signature; the kit field grows by itself.
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final Key? fieldKey;
  final Key? sendKey;
  final bool enabled;

  /// The visible label above the field; null uses [hint].
  final String? label;

  /// Why the field cannot take words now; shown when not [enabled].
  final String? disabledReason;

  /// Keeps the typed words across a dismissal (DATA-2).
  final KitDraft? draft;

  @override
  State<TeamComposerField> createState() => _TeamComposerFieldState();
}

class _TeamComposerFieldState extends State<TeamComposerField> {
  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final canSend = widget.enabled && widget.controller.text.trim().isNotEmpty;
    return KitField(
      label: widget.label ?? widget.hint,
      controller: widget.controller,
      kind: KitFieldKind.multiline,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      disabledReason: widget.enabled
          ? null
          : widget.disabledReason ?? l10n.teamControlsFieldUnavailable,
      draft: widget.draft,
      fieldKey: widget.fieldKey,
      actionKey: widget.sendKey,
      action: KitAction(
        label: widget.sendLabel,
        icon: AppIconography.send,
        onPressed: canSend ? widget.onSend : null,
      ),
    );
  }
}

/// The two-step gate every control that ends work goes through: the first
/// tap opened this, the second (the confirming button) returns true;
/// backing out returns false and nothing is sent. [kind] is
/// [KitConfirmKind.stop] (error tone, "Keep going") unless the caller asks
/// for a neutral question (a restart loses nothing, LOOK-5).
Future<bool> confirmTeamControl(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  KitConfirmKind kind = KitConfirmKind.stop,
  List<String> consequences = const [],
  Key? sheetKey,
  Key? confirmKey,
}) => showKitConfirm(
  context,
  title: title,
  body: message,
  confirmLabel: confirmLabel,
  cancelLabel: _copy(context).teamUiControlKeep,
  kind: kind,
  icon: kind == KitConfirmKind.neutral ? null : AppIconography.stop,
  consequences: consequences,
  sheetKey: sheetKey,
  confirmKey: confirmKey,
);
