/// The receipt a gate's card, its rows and the Gate sheet share (TEAM-203,
/// 02-ux §6): which [MutationRecord] answers a gate, the copy per status
/// and the row's trailing [KitReceipt]. A row leaves the list only once the
/// host confirmed; nothing here sends.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
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

/// A gate answer's receipt at the end of a row that points to the gate
/// (the Activity list, the AI Team lists): the one [KitReceipt] —
/// "Sending…", "Not confirmed yet" or "Not accepted" — that opens the gate
/// ([onOpen]), where Try again lives. Null for a confirmed answer (the row
/// leaves the list) so the row shows its chevron instead.
///
/// A row's trailing slot gives unbounded width, so the receipt stays one
/// compact tap target at most [teamGateReceiptMaxWidthFraction] of the
/// screen wide: its words wrap instead of squeezing the row's title.
Widget? teamGateRowReceipt(
  BuildContext context,
  MutationRecord record, {
  required VoidCallback onOpen,
  Key? key,
}) {
  final state = switch (record.status) {
    MutationStatus.sent => KitReceiptState.sending,
    MutationStatus.unconfirmed => KitReceiptState.notConfirmed,
    MutationStatus.rejected => KitReceiptState.refused,
    MutationStatus.confirmed => null,
  };
  if (state == null) return null;
  final maxWidth =
      (MediaQuery.sizeOf(context).width * teamGateReceiptMaxWidthFraction)
          .floorToDouble();
  final Widget receipt = ConstrainedBox(
    key: key,
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: KitReceipt(state: state, onTap: onOpen),
  );
  if (state != KitReceiptState.notConfirmed) return receipt;
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  // One button that opens the gate, where the retry lives.
  return Semantics(
    label: l10n.teamUiGateAnswerChipUnconfirmedSemantics,
    button: true,
    onTap: onOpen,
    excludeSemantics: true,
    child: receipt,
  );
}

/// The share of the screen width a row's gate receipt may take.
const double teamGateReceiptMaxWidthFraction = .4;

/// Retired by slice-P4.1c: use [teamGateRowReceipt], which returns the one
/// [KitReceipt]. Kept only for `team_home_screen.dart`, which slice-P3.4
/// is rewriting in parallel; its merge replaces that last call and deletes
/// this class (STANDARDS KIT-43 forbids `@Deprecated`).
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
  Widget build(BuildContext context) =>
      teamGateRowReceipt(context, record, onOpen: onOpen) ??
      const SizedBox.shrink();
}
