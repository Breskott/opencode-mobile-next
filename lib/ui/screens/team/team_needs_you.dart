/// What the team needs from the person, drawn the same wherever it shows
/// (docs/design/aiteam-redesign-2026-09-24.md): on the AI Team home, first,
/// and on a task's Overview.
///
/// One question is a request block ([KitRequestCard]) with its answers, as
/// in chat: a choice is answered in place — pick an option, then Send —
/// through the same [OrchestrationController.answerGate] the Gate sheet
/// uses, and the block then carries the receipt until the host confirms.
/// Every other kind (an approval, a free-text answer, a failed task) opens
/// the Gate sheet with Answer, where the two-step confirmations live.
/// Several questions are a short list of rows, each opening the sheet.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../domain/server_gateway.dart' show QuestionChoice;
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/question_options.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_receipt.dart';
import '../../widgets/team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Most urgent first (BRD §47: a decision, a failed task, review ready, a
/// gate), then the newest.
int teamCompareGates(OrchestrationGate a, OrchestrationGate b) {
  final rank = teamGateRank(a.kind).compareTo(teamGateRank(b.kind));
  if (rank != 0) return rank;
  final at = a.createdAt, bt = b.createdAt;
  if (at == null || bt == null) return 0;
  return bt.compareTo(at);
}

/// The gates to show, in [teamCompareGates] order, without those whose
/// answer the host confirmed (02-ux §6). With [runId], only that task's,
/// and review-ready (informational) left out.
List<OrchestrationGate> teamOpenGates(
  OrchestrationController controller, {
  String? runId,
}) {
  final snapshot = controller.snapshot;
  return [
    for (final gate in snapshot.gates)
      if (!teamGateAnswered(controller, gate) &&
          (runId == null ||
              (gate.kind != GateKind.reviewReady &&
                  teamGateRunId(snapshot, gate) == runId)))
        gate,
  ]..sort(teamCompareGates);
}

/// The task [gate] belongs to, when the snapshot lists it.
OrchestrationRun? teamGateRun(
  OrchestrationSnapshot snapshot,
  OrchestrationGate gate,
) {
  final id = teamGateRunId(snapshot, gate);
  if (id == null) return null;
  for (final run in snapshot.runs) {
    if (run.id == id) return run;
  }
  return null;
}

/// One question as a request block: [title] names what it is about (the
/// task on the home, the kind of question on the task's own Overview), the
/// question and its note follow, then the answers.
///
/// Keys: `<keyPrefix>` on the block, `-question`, `-send`, `-answer`,
/// `-more`, `-receipt`, `-watch-only`.
class TeamNeedsYouCard extends StatefulWidget {
  const TeamNeedsYouCard({
    super.key,
    required this.controller,
    required this.gate,
    required this.title,
    required this.onOpen,
    required this.keyPrefix,
  });

  final OrchestrationController controller;
  final OrchestrationGate gate;
  final String title;

  /// Opens the Gate sheet: the full question, other kinds' answers, the
  /// retry of an unconfirmed answer, Technical details.
  final VoidCallback onOpen;
  final String keyPrefix;

  @override
  State<TeamNeedsYouCard> createState() => _TeamNeedsYouCardState();
}

class _TeamNeedsYouCardState extends State<TeamNeedsYouCard> {
  int? _selected;
  bool _sending = false;

  @override
  void didUpdateWidget(TeamNeedsYouCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate.id != widget.gate.id) _selected = null;
  }

  Future<void> _send(String choice) async {
    if (_sending) return;
    setState(() => _sending = true);
    await widget.controller.answerGate(
      widget.gate.id,
      GateResponse.choice(choice),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _selected = null;
    });
  }

  Key _key(String part) => ValueKey('${widget.keyPrefix}-$part');

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final controller = widget.controller;
    final gate = widget.gate;
    final canAnswer = controller.capabilities.controlRespond;
    final record = teamGateMutation(controller, gate);
    // Once an answer left this phone the block carries its receipt; a
    // refused one offers the answers again.
    final answered = record != null && record.status != MutationStatus.rejected;
    final inline =
        gate.kind == GateKind.choice && canAnswer && gate.choices.isNotEmpty;
    final choices = inline && !answered ? gate.choices : const <String>[];
    final prompt = gate.prompt?.trim();
    final promptShown =
        prompt != null && prompt.isNotEmpty && prompt != gate.title;
    final hostMode = controller.host?.hostMode ?? controller.config.hostMode;
    final (icon, tone) = teamGateGlyph(gate.kind);

    final selected = _selected;
    final KitAction? primary;
    if (inline && !answered) {
      // Send earns its place once an option is picked (§2: never a
      // disabled button without a reason beside it).
      primary = selected == null && !_sending
          ? null
          : KitAction(
              key: _key('send'),
              label: l10n.teamUiGateAnswerSend,
              working: _sending,
              onPressed: _sending || selected == null
                  ? null
                  : () => _send(gate.choices[selected]),
            );
    } else if (canAnswer && !answered && gate.kind != GateKind.reviewReady) {
      primary = KitAction(
        key: _key('answer'),
        label: l10n.teamUiHomeNeedsYouAnswer,
        onPressed: widget.onOpen,
      );
    } else {
      primary = null;
    }
    final more = KitAction(
      key: _key('more'),
      label: l10n.teamUiHomeNeedsYouMore,
      onPressed: widget.onOpen,
    );
    final answersInSheet = primary?.key == _key('answer');

    return KeyedSubtree(
      key: ValueKey(widget.keyPrefix),
      child: KitRequestCard(
        icon: icon,
        tone: tone,
        title: widget.title,
        announcement: l10n.teamUiHomeNeedsYouAnnouncement(gate.title),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gate.title,
              key: _key('question'),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.3),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (promptShown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  prompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (choices.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final (index, choice) in choices.indexed)
                QuestionOptionRow(
                  choice: QuestionChoice(label: choice, description: ''),
                  selected: selected == index,
                  multiple: false,
                  enabled: !_sending,
                  onTap: () => setState(() => _selected = index),
                ),
            ],
            if (record != null && answered)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TeamReceiptChip(
                    key: _key('receipt'),
                    record: record,
                    onOpen: widget.onOpen,
                  ),
                ),
              ),
            if (!canAnswer)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  switch (hostMode) {
                    OrchestrationHostMode.computer =>
                      l10n.teamUiHomeGateAnswerOnComputer,
                    OrchestrationHostMode.phone =>
                      l10n.teamUiHomeGateAnswerOnPhone,
                  },
                  key: _key('watch-only'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
        primary: primary,
        tertiary: [if (!answersInSheet) more],
      ),
    );
  }
}

/// One of several questions, as a row: the question (two lines), what it
/// is about and its age; the receipt once an answer left this phone. The
/// row opens the Gate sheet.
class TeamGateRow extends StatelessWidget {
  const TeamGateRow({
    super.key,
    required this.controller,
    required this.gate,
    required this.now,
    required this.onTap,
    this.receiptKey,
  });

  final OrchestrationController controller;
  final OrchestrationGate gate;
  final DateTime now;
  final VoidCallback onTap;
  final Key? receiptKey;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamGateGlyph(gate.kind);
    final color = AppTheme.statusColor(theme, tone);
    final record = teamGateMutation(controller, gate);
    final age = gate.createdAt == null
        ? null
        : relativeTimeLabel(
            gate.createdAt!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final task = teamGateRun(controller.snapshot, gate)?.title;
    final supporting = [
      teamGateKindWord(l10n, gate.kind),
      ?task,
      ?age,
    ].join(teamUsageSeparator);
    return KitRow(
      leading: KitRow.icon(context, icon, color: color),
      title: gate.title,
      titleMaxLines: 2,
      supporting: TextSpan(text: supporting),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
        child: (record != null && record.status != MutationStatus.confirmed)
            ? TeamReceiptChip(key: receiptKey, record: record, onOpen: onTap)
            : Icon(AppIconography.chevronRight, size: 20, color: muted),
      ),
      onTap: onTap,
    );
  }
}
