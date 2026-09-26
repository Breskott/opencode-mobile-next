/// The receipt a needs-you row and the Gate sheet share (TEAM-203, 02-ux
/// §6): which [MutationRecord] answers a gate, the copy per status and the
/// trailing chip. A row leaves the list only once the host confirmed;
/// nothing here sends.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';
import '../kit/kit_receipt.dart';

/// The newest record answering [gate] from this device that no retry
/// superseded: the `respond` on the gate's own id, or — for a failed run —
/// the `cancelRun` on its run or the `assign` that re-slung one of its
/// work items. Null when the gate was never answered from here.
MutationRecord? teamGateMutation(
  OrchestrationController controller,
  OrchestrationGate gate,
) {
  if (gate.kind != GateKind.runFailed) return controller.mutationFor(gate.id);
  final runId = gate.runId;
  if (runId == null) return null;
  final workOfRun = {
    for (final item in controller.snapshot.work)
      if (item.runId == runId) item.id,
  };
  MutationRecord? best;
  for (final record in controller.mutations) {
    if (record.retriedBy != null) continue;
    final matches = switch (record.kind) {
      MutationKind.cancelRun || MutationKind.merge => record.targetId == runId,
      MutationKind.assign => workOfRun.contains(record.targetId),
      MutationKind.approveMerge => workOfRun.contains(record.targetId),
      MutationKind.respond ||
      MutationKind.message ||
      MutationKind.controlAgent ||
      MutationKind.createWork => false,
    };
    if (!matches) continue;
    if (best == null || record.createdAt.isAfter(best.createdAt)) {
      best = record;
    }
  }
  return best;
}

/// True when [gate]'s answer is confirmed and newer than the gate itself:
/// the row leaves the list (02-ux §6). A gate raised again after the
/// answer — a run that failed once more — shows again.
bool teamGateAnswered(
  OrchestrationController controller,
  OrchestrationGate gate,
) {
  final record = teamGateMutation(controller, gate);
  if (record == null || record.status != MutationStatus.confirmed) return false;
  final raised = gate.createdAt;
  return raised == null || !record.createdAt.isBefore(raised);
}

/// The receipt line per status: "Sent · waiting for the host to confirm",
/// "Answered", the unconfirmed copy, or the host's refusal.
String teamReceiptLine(AppLocalizations l10n, MutationRecord record) =>
    switch (record.status) {
      MutationStatus.sent => l10n.teamUiReceiptSent,
      MutationStatus.confirmed => l10n.teamUiReceiptAnswered,
      MutationStatus.unconfirmed => l10n.teamUiReceiptUnconfirmed,
      MutationStatus.rejected => switch (record.receipt?.message?.trim()) {
        final message? when message.isNotEmpty => l10n.teamUiGateAnswerRejected(
          message,
        ),
        _ => l10n.teamUiGateAnswerRejectedNoMessage,
      },
    };

/// The chip word per status; null for confirmed (the row is gone).
String? teamReceiptChipLabel(AppLocalizations l10n, MutationRecord record) =>
    switch (record.status) {
      MutationStatus.sent => l10n.teamUiGateAnswerChipSent,
      MutationStatus.unconfirmed => l10n.teamUiGateAnswerChipUnconfirmed,
      MutationStatus.rejected => l10n.teamUiGateAnswerChipRejected,
      MutationStatus.confirmed => null,
    };

/// Glyph and tone per status, never colour-only (02-ux §11).
(IconData, AppStatusTone) teamReceiptGlyph(MutationStatus status) =>
    switch (status) {
      MutationStatus.sent => (AppIconography.clock, AppStatusTone.neutral),
      MutationStatus.confirmed => (AppIconography.check, AppStatusTone.ok),
      MutationStatus.unconfirmed => (
        AppIconography.retry,
        AppStatusTone.attention,
      ),
      MutationStatus.rejected => (AppIconography.error, AppStatusTone.failure),
    };

/// The trailing receipt of a needs-you row: "Sent", "Not confirmed yet"
/// (tap to open the sheet and retry) or "Not accepted". Absent for
/// confirmed and for a gate never answered from here, so screens do not
/// grow "Done" words before their own units adopt [KitReceipt].
///
/// Retired by kit-KitReceipt: use [KitReceipt]. A thin forwarding wrapper
/// (KitReceipt.md, C24; STANDARDS KIT-43 forbids `@Deprecated`, which would
/// put infos into every caller's analyze); slice-P4.1c deletes it.
class TeamReceiptChip extends StatelessWidget {
  const TeamReceiptChip({
    super.key,
    required this.record,
    required this.onOpen,
  });

  final MutationRecord record;

  /// Opens the Gate sheet, where the retry lives.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final state = switch (record.status) {
      MutationStatus.sent => KitReceiptState.sent,
      MutationStatus.unconfirmed => KitReceiptState.notConfirmed,
      MutationStatus.rejected => KitReceiptState.refused,
      MutationStatus.confirmed => null,
    };
    if (state == null) return const SizedBox.shrink();
    final retry = state == KitReceiptState.notConfirmed;
    final receipt = KitReceipt(
      state: state,
      onRetry: retry ? onOpen : null,
      onTap: onOpen,
    );
    if (!retry) return receipt;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    // The chip's retry label is kept (KitReceipt.md, "The wrapper keeps
    // meaning"): one button that opens the sheet where the retry lives.
    return Semantics(
      label: l10n.teamUiGateAnswerChipUnconfirmedSemantics,
      button: true,
      onTap: onOpen,
      excludeSemantics: true,
      child: receipt,
    );
  }
}
