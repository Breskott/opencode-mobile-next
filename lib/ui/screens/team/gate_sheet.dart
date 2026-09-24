/// The Gate sheet (02-ux §6): what a needs-you row opens, from Activity,
/// the AI Team home, a run or a notification. Five variants — Choice,
/// Confirmation, Free text, Gate bead, Run failed — plus Review ready.
///
/// Sprint A (TEAM-112) showed every variant read-only; TEAM-203 adds the
/// actions, each present only behind its `control*` capability (absent,
/// never disabled, without it): Choice → a radio list and [Send];
/// Confirmation → [Deny] [Approve], the approve of a destructive prompt and
/// every deny two-step in the error tone; Free text → a multi-line field
/// and [Send]; Gate bead → [Mark done]; Run failed → [Retry] (re-sling the
/// stuck work), [Restart or reassign] and [View logs] (the agent screens,
/// whose controls are TEAM-204's) and [Cancel work] (two-step). Review
/// ready stays informational.
///
/// Every answer routes with the gate's own id — the interaction's
/// `request_id` — through [OrchestrationController.answerGate] and friends,
/// which persist the idempotency key before sending. The sheet then shows
/// the receipt inline: "Sent · waiting for the host to confirm" with the
/// action disabled, "Answered" (then it closes after a beat while the row
/// leaves the list), "Sent, unconfirmed — …" with [Retry], or the host's
/// refusal with [Try again]. A retry is a new record under a new key and
/// only ever follows a tap. Variants without an action keep "Answer this
/// on the host" and [How]; the Technical details expander (request id,
/// session id, raw values) closes every variant.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/markdown.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_host_form.dart';
import '../../widgets/team_receipt.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_output_screen.dart';
import 'agent_screen.dart';
import 'work_sheet.dart';

/// How long "Answered" stays on screen before the sheet closes itself.
const gateSheetAnsweredBeat = Duration(milliseconds: 900);

/// A variant's actions in the design standard's one hierarchy (§2), plus
/// the line that explains the secondary ([note]) when it needs one.
class _GateActions {
  const _GateActions({
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.note,
    this.answers = false,
  });

  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;
  final Widget? note;

  /// Whether this phone can act on the gate at all (anything besides
  /// Close); when not, the sheet says where to answer it.
  final bool answers;
}

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Opens the Gate sheet for [gateId]. The sheet reads the gate from the
/// controller's snapshot on every rebuild, so one answered on the host
/// meanwhile says so instead of showing stale options. Work chips close
/// this sheet and open the Work sheet, so [context] must outlive it.
Future<void> showGateSheet(
  BuildContext context,
  OrchestrationController controller,
  String gateId, {
  DateTime Function()? now,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => GateSheet(
    controller: controller,
    gateId: gateId,
    now: now,
    onOpenWork: (id) {
      Navigator.of(sheetContext).pop();
      showWorkSheet(context, controller, id, now: now);
    },
    onOpenAgent: (id) {
      Navigator.of(sheetContext).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AgentScreen(controller: controller, agentId: id, now: now),
        ),
      );
    },
    onOpenLogs: (id) {
      Navigator.of(sheetContext).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AgentOutputScreen(controller: controller, agentId: id),
        ),
      );
    },
  ),
);

/// The sheet body; [showGateSheet] wraps it in a modal bottom sheet.
class GateSheet extends StatelessWidget {
  const GateSheet({
    super.key,
    required this.controller,
    required this.gateId,
    required this.onOpenWork,
    this.onOpenAgent,
    this.onOpenLogs,
    this.now,
  });

  final OrchestrationController controller;
  final String gateId;
  final ValueChanged<String> onOpenWork;

  /// Opens the agent screen (Restart / Reassign live there); the failed-run
  /// buttons are absent when null.
  final ValueChanged<String>? onOpenAgent;

  /// Opens the agent's output page (View logs).
  final ValueChanged<String>? onOpenLogs;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final snapshot = controller.snapshot;
      OrchestrationGate? gate;
      for (final candidate in snapshot.gates) {
        if (candidate.id == gateId) {
          gate = candidate;
          break;
        }
      }
      if (gate == null) {
        // Answered or closed on the host meanwhile: a state, not a form.
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: KitStateView(
            key: const ValueKey('team-gate-sheet-missing'),
            size: KitStateSize.inline,
            icon: AppIconography.checkCircle,
            title: l10n.teamUiGateGone,
            tertiary: [
              KitAction(
                key: const ValueKey('team-gate-close'),
                label: l10n.teamUiHomeGateClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      return _Body(
        key: ValueKey('team-gate-sheet-${gate.id}'),
        controller: controller,
        gate: gate,
        snapshot: snapshot,
        hostMode: controller.host?.hostMode ?? controller.config.hostMode,
        now: (now ?? DateTime.now)(),
        onOpenWork: onOpenWork,
        onOpenAgent: onOpenAgent,
        onOpenLogs: onOpenLogs,
      );
    },
  );
}

class _Body extends StatefulWidget {
  const _Body({
    super.key,
    required this.controller,
    required this.gate,
    required this.snapshot,
    required this.hostMode,
    required this.now,
    required this.onOpenWork,
    required this.onOpenAgent,
    required this.onOpenLogs,
  });

  final OrchestrationController controller;
  final OrchestrationGate gate;
  final OrchestrationSnapshot snapshot;
  final OrchestrationHostMode hostMode;
  final DateTime now;
  final ValueChanged<String> onOpenWork;
  final ValueChanged<String>? onOpenAgent;
  final ValueChanged<String>? onOpenLogs;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int? _selected;
  final _text = TextEditingController();
  bool _sending = false;

  /// The record this sheet sent or retried; the receipt follows it (and
  /// any retry that superseded it).
  String? _activeKey;
  Timer? _closeTimer;

  OrchestrationGate get gate => widget.gate;
  OrchestrationSnapshot get snapshot => widget.snapshot;
  OrchestrationController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// The record the receipt shows: the one this sheet sent, followed
  /// through retries, else the newest one answering the gate.
  MutationRecord? _record() {
    var record = _activeKey == null ? null : controller.mutation(_activeKey!);
    for (var hops = 0; record?.retriedBy != null && hops < 32; hops++) {
      final next = controller.mutation(record!.retriedBy!);
      if (next == null) break;
      record = next;
    }
    return record ?? teamGateMutation(controller, gate);
  }

  Future<void> _send(Future<MutationRecord> Function() action) async {
    if (_sending) return;
    setState(() => _sending = true);
    final record = await action();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _activeKey = record.key;
    });
  }

  Future<void> _retry(MutationRecord record) async {
    if (_sending) return;
    setState(() => _sending = true);
    final next = await controller.retryMutation(record.key);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (next != null) _activeKey = next.key;
    });
  }

  /// The second step of a destructive action, in the error tone. Nothing
  /// is sent unless the person confirms here too.
  Future<bool> _confirm(String title, String message, String label) {
    final l10n = _copy(context);
    return showConfirmSheet(
      context,
      title: title,
      message: message,
      confirmLabel: label,
      cancelLabel: l10n.teamUiGateAnswerConfirmKeep,
      icon: AppIconography.warning,
      destructive: true,
      sheetKey: const ValueKey('team-gate-confirm'),
      confirmKey: const ValueKey('team-gate-confirm-yes'),
    );
  }

  void _scheduleClose() {
    if (_closeTimer != null) return;
    _closeTimer = Timer(gateSheetAnsweredBeat, () {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamGateGlyph(gate.kind);
    final color = AppTheme.statusColor(theme, tone);
    final link = teamGateLink(l10n, snapshot, gate);
    final record = _record();
    if (record != null && record.status == MutationStatus.confirmed) {
      _scheduleClose();
    }
    // While an answer is on its way the actions stay visible but off; an
    // unconfirmed one hides them (the same answer may have landed) and
    // offers Retry; a confirmed one hides them while the sheet closes; a
    // refused one keeps them beside Try again.
    final busy = _sending || (record?.isSent ?? false);
    final hideActions =
        record != null &&
        (record.status == MutationStatus.unconfirmed ||
            record.status == MutationStatus.confirmed);
    final age = gate.createdAt == null
        ? null
        : relativeTimeLabel(
            gate.createdAt!.millisecondsSinceEpoch,
            now: widget.now,
            l10n: l10n,
          );
    // The mapper uses the prompt as the title when the host gave no
    // other; say it once.
    final prompt = gate.prompt?.trim();
    final promptShown =
        prompt != null && prompt.isNotEmpty && prompt != gate.title;

    Widget heading(String text) =>
        SectionLabel(text, padding: const EdgeInsets.only(top: 16, bottom: 6));

    Widget workChips(String prefix, List<WorkItem> items) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ActionChip(
            key: ValueKey('team-gate-$prefix-${item.id}'),
            avatar: Icon(
              teamWorkGlyph(item.state).$1,
              size: 16,
              color: AppTheme.statusColor(theme, teamWorkGlyph(item.state).$2),
            ),
            label: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => widget.onOpenWork(item.id),
          ),
      ],
    );

    final caps = controller.capabilities;
    final body = switch (gate.kind) {
      GateKind.choice => _choice(
        context,
        promptShown ? prompt : null,
        interactive: caps.controlRespond && !hideActions,
        busy: busy,
      ),
      GateKind.confirmation => _confirmation(
        context,
        promptShown ? prompt : null,
      ),
      GateKind.freeText => [
        if (promptShown) _prompt(context, prompt),
        if (caps.controlRespond && !hideActions) _composer(context, busy),
      ],
      GateKind.unknown => [if (promptShown) _prompt(context, prompt)],
      GateKind.gateBead || GateKind.reviewReady => _bead(
        context,
        promptShown ? prompt : null,
        heading,
        workChips,
      ),
      GateKind.runFailed => _runFailed(context, heading, workChips),
    };
    final close = KitAction(
      key: const ValueKey('team-gate-close'),
      label: l10n.teamUiHomeGateClose,
      onPressed: () => Navigator.of(context).pop(),
    );
    final actions = hideActions
        ? _GateActions(tertiary: [close])
        : _actions(context, caps, busy: busy, close: close);

    return SingleChildScrollView(
      key: const ValueKey('team-gate-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [teamGateKindWord(l10n, gate.kind), ?age].join(' · '),
                  key: const ValueKey('team-gate-kind'),
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            gate.title,
            key: const ValueKey('team-gate-title'),
            style: theme.textTheme.titleLarge?.copyWith(height: 1.2),
          ),
          const SizedBox(height: 2),
          TeamTermRow(_term(l10n)),
          if (link != null)
            Text(
              link,
              key: const ValueKey('team-gate-link'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ...body,
          if (record != null) ...[
            const SizedBox(height: 16),
            _Receipt(
              record: record,
              busy: _sending,
              onRetry: () => _retry(record),
            ),
          ],
          if (!actions.answers && !hideActions && record == null) ...[
            const SizedBox(height: 16),
            _HostLine(
              key: const ValueKey('team-gate-answer-on-host'),
              text: _hostLine(l10n),
            ),
          ],
          if (actions.note case final note?) ...[
            const SizedBox(height: 16),
            note,
          ],
          // One block in the §2 order; Close is its last way out.
          const SizedBox(height: 16),
          KitActionBlock(
            primary: actions.primary,
            secondary: actions.secondary,
            tertiary: actions.tertiary,
          ),
          // Details close the sheet, never above the actions (§3).
          const SizedBox(height: 8),
          _TechnicalDetails(gate: gate),
        ],
      ),
    );
  }

  /// "Decision · interaction req-…": the product word with its Gas City
  /// term and id (02-ux §8).
  String _term(AppLocalizations l10n) {
    final kind = teamGateKindWord(l10n, gate.kind);
    return switch (gate.kind) {
      GateKind.gateBead || GateKind.reviewReady => l10n.teamUiGateTermBead(
        kind,
        gate.workId ?? gate.id,
      ),
      GateKind.runFailed => l10n.teamUiGateTermRun(kind, gate.runId ?? gate.id),
      GateKind.choice ||
      GateKind.confirmation ||
      GateKind.freeText ||
      GateKind.unknown => l10n.teamUiGateTermInteraction(kind, gate.id),
    };
  }

  /// Where to act, per kind and host mode: answer, close or review.
  String _hostLine(AppLocalizations l10n) {
    final phone = widget.hostMode == OrchestrationHostMode.phone;
    return switch (gate.kind) {
      GateKind.gateBead =>
        phone ? l10n.teamUiGateCloseOnHostPhone : l10n.teamUiGateCloseOnHost,
      GateKind.reviewReady =>
        phone ? l10n.teamUiGateReviewOnHostPhone : l10n.teamUiGateReviewOnHost,
      GateKind.choice ||
      GateKind.confirmation ||
      GateKind.freeText ||
      GateKind.unknown ||
      GateKind.runFailed =>
        phone ? l10n.teamUiGateAnswerOnHostPhone : l10n.teamUiGateAnswerOnHost,
    };
  }

  Widget _prompt(BuildContext context, String text, {Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        key: const ValueKey('team-gate-prompt'),
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.35, color: color),
      ),
    );
  }

  List<Widget> _choice(
    BuildContext context,
    String? prompt, {
    required bool interactive,
    required bool busy,
  }) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final accent = theme.colorScheme.primary;
    return [
      if (prompt != null) _prompt(context, prompt),
      if (gate.choices.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          l10n.teamUiHomeGateOptions,
          style: theme.textTheme.labelLarge?.copyWith(color: muted),
        ),
        for (final (index, choice) in gate.choices.indexed)
          _Option(
            key: ValueKey('team-gate-option-$index'),
            label: choice,
            selected: interactive && _selected == index,
            interactive: interactive,
            color: interactive && _selected == index ? accent : muted,
            onTap: interactive && !busy
                ? () => setState(() => _selected = index)
                : null,
          ),
        if (interactive && _selected == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.teamUiGateAnswerOptionsHint,
              key: const ValueKey('team-gate-options-hint'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    ];
  }

  /// The free-text answer field: multi-line, the app's field styling,
  /// nothing attached (02-ux §6).
  Widget _composer(BuildContext context, bool busy) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        key: const ValueKey('team-gate-composer'),
        controller: _text,
        readOnly: busy,
        minLines: 2,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: l10n.teamUiGateAnswerHint,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: .5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Actions (TEAM-203)
  // -------------------------------------------------------------------------

  /// The variant's actions in the one hierarchy (design standard §2), each
  /// only behind its capability, with [close] as the last way out. When
  /// nothing but [close] is left the sheet keeps its "Answer this on the
  /// host" line.
  _GateActions _actions(
    BuildContext context,
    OrchestrationCapabilities caps, {
    required bool busy,
    required KitAction close,
  }) {
    final l10n = _copy(context);
    switch (gate.kind) {
      case GateKind.choice:
        if (!caps.controlRespond) return _GateActions(tertiary: [close]);
        final index = _selected;
        return _GateActions(
          answers: true,
          // Off until an option is picked; the options hint above says so.
          primary: KitAction(
            key: const ValueKey('team-gate-send'),
            label: l10n.teamUiGateAnswerSend,
            onPressed: busy || index == null || index >= gate.choices.length
                ? null
                : () => _send(
                    () => controller.answerGate(
                      gate.id,
                      GateResponse.choice(gate.choices[index]),
                    ),
                  ),
          ),
          tertiary: [close],
        );
      case GateKind.freeText:
        if (!caps.controlRespond) return _GateActions(tertiary: [close]);
        final text = _text.text.trim();
        return _GateActions(
          answers: true,
          primary: KitAction(
            key: const ValueKey('team-gate-send'),
            label: l10n.teamUiGateAnswerSend,
            onPressed: busy || text.isEmpty
                ? null
                : () => _send(
                    () =>
                        controller.answerGate(gate.id, GateResponse.text(text)),
                  ),
          ),
          tertiary: [close],
        );
      case GateKind.confirmation:
        if (!caps.controlRespond) return _GateActions(tertiary: [close]);
        final destructive = teamGateIsDestructive(gate);
        Future<void> answer(bool confirmed) => _send(
          () => controller.answerGate(
            gate.id,
            GateResponse.confirmation(confirmed: confirmed),
          ),
        );
        return _GateActions(
          answers: true,
          // The whole sheet is this one answer, so a destructive approve
          // may be the (error-toned, two-step) primary.
          primary: KitAction(
            key: const ValueKey('team-gate-approve'),
            label: l10n.teamUiGateAnswerApprove,
            destructive: destructive,
            onPressed: busy
                ? null
                : destructive
                ? () async {
                    final ok = await _confirm(
                      l10n.teamUiGateAnswerConfirmApproveTitle,
                      l10n.teamUiGateAnswerConfirmApproveBody,
                      l10n.teamUiGateAnswerApprove,
                    );
                    if (ok && mounted) await answer(true);
                  }
                : () => answer(true),
          ),
          secondary: KitAction(
            key: const ValueKey('team-gate-deny'),
            label: l10n.teamUiGateAnswerDeny,
            destructive: true,
            onPressed: busy
                ? null
                : () async {
                    final ok = await _confirm(
                      l10n.teamUiGateAnswerConfirmDenyTitle,
                      l10n.teamUiGateAnswerConfirmDenyBody,
                      l10n.teamUiGateAnswerDeny,
                    );
                    if (ok && mounted) await answer(false);
                  },
          ),
          tertiary: [close],
        );
      case GateKind.gateBead:
        if (!caps.controlRespond) return _GateActions(tertiary: [close]);
        return _GateActions(
          answers: true,
          primary: KitAction(
            key: const ValueKey('team-gate-mark-done'),
            label: l10n.teamUiGateAnswerMarkDone,
            onPressed: busy
                ? null
                : () => _send(
                    () => controller.answerGate(
                      gate.id,
                      const GateResponse.confirmation(confirmed: true),
                    ),
                  ),
          ),
          tertiary: [close],
        );
      case GateKind.runFailed:
        return _runActions(context, caps, busy: busy, close: close);
      case GateKind.reviewReady:
      case GateKind.unknown:
        return _GateActions(tertiary: [close]);
    }
  }

  /// Retry (re-sling the stuck work to its agent) as the secondary, with
  /// the line saying what it sends; then Restart or reassign and Close,
  /// and in More: View logs and Cancel work (two-step, error tone).
  _GateActions _runActions(
    BuildContext context,
    OrchestrationCapabilities caps, {
    required bool busy,
    required KitAction close,
  }) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final runId = gate.runId;
    final open = _affectedWork();
    WorkItem? stuck;
    for (final item in open) {
      if (teamWorkIsStuck(item.state)) {
        stuck = item;
        break;
      }
    }
    stuck ??= open.isEmpty ? null : open.first;
    String? agentId = stuck?.assignee ?? gate.agentId;
    if (agentId == null) {
      for (final item in open) {
        if (item.assignee != null) {
          agentId = item.assignee;
          break;
        }
      }
    }
    final target = agentId ?? _runTarget();
    final agentName = agentId == null ? null : _agentName(agentId);
    KitAction? retry;
    Widget? note;
    if (caps.controlAssign && stuck != null && target != null) {
      final item = stuck;
      retry = KitAction(
        key: const ValueKey('team-gate-run-retry'),
        label: l10n.teamUiGateAnswerRunRetry,
        onPressed: busy
            ? null
            : () =>
                  _send(() => controller.assignWork(item.id, agentId: target)),
      );
      note = Text(
        l10n.teamUiGateAnswerRunRetryDetail(item.title, agentName ?? target),
        key: const ValueKey('team-gate-run-retry-detail'),
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      );
    }
    KitAction? agent;
    final onOpenAgent = widget.onOpenAgent;
    if (onOpenAgent != null && agentId != null && caps.agents) {
      final id = agentId;
      agent = KitAction(
        key: const ValueKey('team-gate-run-agent'),
        label: l10n.teamUiGateAnswerRunAgent,
        onPressed: () => onOpenAgent(id),
      );
    }
    KitAction? logs;
    final onOpenLogs = widget.onOpenLogs;
    if (onOpenLogs != null && agentId != null && caps.agentOutput) {
      final id = agentId;
      logs = KitAction(
        key: const ValueKey('team-gate-run-logs'),
        label: l10n.teamUiGateAnswerRunLogs,
        onPressed: () => onOpenLogs(id),
      );
    }
    KitAction? cancel;
    if (caps.controlCancelRun && runId != null) {
      cancel = KitAction(
        key: const ValueKey('team-gate-run-cancel'),
        label: l10n.teamUiGateAnswerRunCancel,
        destructive: true,
        onPressed: busy
            ? null
            : () async {
                final ok = await _confirm(
                  l10n.teamUiGateAnswerConfirmCancelRunTitle,
                  l10n.teamUiGateAnswerConfirmCancelRunBody,
                  l10n.teamUiGateAnswerRunCancel,
                );
                if (ok && mounted) {
                  await _send(() => controller.cancelRun(runId));
                }
              },
      );
    }
    return _GateActions(
      answers: retry != null || agent != null || logs != null || cancel != null,
      secondary: retry,
      note: note,
      // Two tertiary actions show; the rest go under More (§2). Close
      // stays visible so the sheet always has its way out.
      tertiary: [?agent, close, ?logs, ?cancel],
    );
  }

  /// The failed run's open work, stuck items first (as the sheet lists
  /// them).
  List<WorkItem> _affectedWork() =>
      [
        for (final item in snapshot.work)
          if (gate.runId != null &&
              item.runId == gate.runId &&
              teamWorkIsOpen(item.state))
            item,
      ]..sort((a, b) {
        final stuck =
            (teamWorkIsStuck(b.state) ? 1 : 0) -
            (teamWorkIsStuck(a.state) ? 1 : 0);
        if (stuck != 0) return stuck;
        return teamWorkStateRank(a.state).compareTo(teamWorkStateRank(b.state));
      });

  /// The run's sling target as the host recorded it (`ocproof/polecats`),
  /// the fallback when no work item names an agent.
  String? _runTarget() {
    if (gate.raw['target'] case final String target when target.isNotEmpty) {
      return target;
    }
    return null;
  }

  String? _agentName(String id) {
    for (final agent in snapshot.agents) {
      if (agent.id == id || agent.sessionId == id) return agent.name;
    }
    return null;
  }

  List<Widget> _confirmation(BuildContext context, String? prompt) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final destructive = teamGateIsDestructive(gate);
    final error = theme.colorScheme.error;
    return [
      if (destructive)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            key: const ValueKey('team-gate-destructive'),
            children: [
              Icon(AppIconography.warning, size: 18, color: error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.teamUiGateDestructive,
                  style: theme.textTheme.labelLarge?.copyWith(color: error),
                ),
              ),
            ],
          ),
        ),
      if (prompt != null)
        _prompt(context, prompt, color: destructive ? error : null),
    ];
  }

  List<Widget> _bead(
    BuildContext context,
    String? prompt,
    Widget Function(String) heading,
    Widget Function(String, List<WorkItem>) chips,
  ) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final unblocks = [
      for (final item in snapshot.work)
        if (gate.workId != null &&
            item.id != gate.workId &&
            item.dependsOn.contains(gate.workId))
          item,
    ];
    return [
      heading(l10n.teamUiGateDescription),
      if (prompt != null)
        MarkdownText(
          prompt,
          key: const ValueKey('team-gate-description'),
          selectable: false,
        )
      else
        Text(
          l10n.teamUiGateNoDescription,
          key: const ValueKey('team-gate-description-none'),
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      if (gate.kind == GateKind.gateBead) ...[
        heading(l10n.teamUiGateUnblocks),
        if (unblocks.isEmpty)
          Text(
            l10n.teamUiGateUnblocksNone,
            key: const ValueKey('team-gate-unblocks-none'),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          )
        else
          chips('unblocks', unblocks),
      ],
    ];
  }

  List<Widget> _runFailed(
    BuildContext context,
    Widget Function(String) heading,
    Widget Function(String, List<WorkItem>) chips,
  ) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final error = gate.prompt?.trim();
    final cls = teamClassifyFailure(_errorText());
    final recoverable = teamFailureRecoverable(cls);
    final affected =
        [
          for (final item in snapshot.work)
            if (gate.runId != null &&
                item.runId == gate.runId &&
                teamWorkIsOpen(item.state))
              item,
        ]..sort((a, b) {
          // Stuck items first, then the Work tab's order.
          final stuck =
              (teamWorkIsStuck(b.state) ? 1 : 0) -
              (teamWorkIsStuck(a.state) ? 1 : 0);
          if (stuck != 0) return stuck;
          return teamWorkStateRank(
            a.state,
          ).compareTo(teamWorkStateRank(b.state));
        });
    return [
      heading(l10n.teamUiGateFailureError),
      if (error != null && error.isNotEmpty)
        Text(
          error,
          key: const ValueKey('team-gate-error'),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: AppTheme.monoFamily,
            fontSize: AppTheme.codeFontSize,
          ),
        )
      else
        Text(
          l10n.teamUiGateFailureErrorNone,
          key: const ValueKey('team-gate-error-none'),
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      heading(l10n.teamUiGateFailureClassification),
      Text(
        teamFailureClassWord(l10n, cls),
        key: const ValueKey('team-gate-classification'),
        style: theme.textTheme.bodyMedium,
      ),
      heading(l10n.teamUiGateFailureAffectedWork),
      if (affected.isEmpty)
        Text(
          l10n.teamUiGateFailureAffectedNone,
          key: const ValueKey('team-gate-affected-none'),
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        )
      else
        chips('affected', affected),
      heading(l10n.teamUiGateFailureRecoverable),
      Text(
        switch (recoverable) {
          true => l10n.teamUiGateFailureRecoverableYes,
          false => l10n.teamUiGateFailureRecoverableNo,
          null => l10n.teamUiGateFailureRecoverableUnknown,
        },
        key: const ValueKey('team-gate-recoverable'),
        style: theme.textTheme.bodyMedium,
      ),
      heading(l10n.teamUiGateFailureAction),
      Text(
        teamFailureAction(l10n, cls),
        key: const ValueKey('team-gate-action'),
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
    ];
  }

  /// The error's message and code together, so a host that only sends a
  /// code (`timeout`) still classifies.
  String _errorText() {
    final parts = <String>[?gate.prompt];
    if (gate.raw['last_error'] case final Map<Object?, Object?> last) {
      for (final key in ['code', 'message', 'error']) {
        if (last[key] case final String value) parts.add(value);
      }
    } else if (gate.raw['last_error'] case final String last) {
      parts.add(last);
    }
    return parts.join(' ');
  }
}

/// One option of a choice decision: a radio glyph and the text, ≥48dp
/// when selectable; a static row (as in Sprint A) when not.
class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.selected,
    required this.interactive,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool interactive;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: interactive ? 8 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              selected
                  ? AppIconography.radioSelected
                  : AppIconography.radioEmpty,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    if (!interactive) return row;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: row,
        ),
      ),
    );
  }
}

/// The receipt block: the status line with its glyph, then [Retry] for an
/// unconfirmed answer or [Try again] for a refused one. Both make a new
/// record under a new key; nothing here re-sends on its own.
class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.record,
    required this.busy,
    required this.onRetry,
  });

  final MutationRecord record;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final (icon, tone) = teamReceiptGlyph(record.status);
    final color = AppTheme.statusColor(theme, tone);
    final retryLabel = switch (record.status) {
      MutationStatus.unconfirmed => l10n.teamUiGateAnswerRetry,
      MutationStatus.rejected => l10n.teamUiGateAnswerTryAgain,
      MutationStatus.sent || MutationStatus.confirmed => null,
    };
    return Column(
      key: ValueKey('team-gate-receipt-${record.status.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                teamReceiptLine(l10n, record),
                key: const ValueKey('team-gate-receipt-line'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (retryLabel != null && record.canRetry) ...[
          const SizedBox(height: 8),
          KitButton.secondary(
            key: const ValueKey('team-gate-retry'),
            label: retryLabel,
            onPressed: busy ? null : onRetry,
          ),
        ],
      ],
    );
  }
}

/// "Answer this on the host" with [How], which opens the host guide.
class _HostLine extends StatelessWidget {
  const _HostLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(AppIconography.info, size: 16, color: muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.35,
                ),
              ),
              KitButton.tertiary(
                key: const ValueKey('team-gate-how'),
                label: l10n.teamUiHow,
                onPressed: () => showTeamHostGuideSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Technical details expander (02-ux §8): request id, session id,
/// provider kind, the ids it names, then every raw scalar the provider
/// sent, each with a copy button.
class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.gate});

  final OrchestrationGate gate;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final raw = gate.raw;
    final requestId = switch (raw['request_id']) {
      final String id when id.isNotEmpty => id,
      _ => gate.id,
    };
    final sessionId = switch (raw['session_id']) {
      final String id when id.isNotEmpty => id,
      _ => gate.agentId,
    };
    const shown = {
      'request_id',
      'session_id',
      'kind',
      'prompt',
      'title',
      'description',
      'options',
    };
    final scalars = <(String, String)>[];
    void collect(Map<Object?, Object?> map, String prefix) {
      for (final entry in map.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (prefix.isEmpty && shown.contains(key)) continue;
        if (value is String || value is num || value is bool) {
          scalars.add(('$prefix$key', '$value'));
        } else if (value is Map<Object?, Object?> && prefix.isEmpty) {
          collect(value, '$key.');
        }
      }
    }

    collect(raw, '');
    scalars.sort((a, b) => a.$1.compareTo(b.$1));
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('team-gate-technical'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          l10n.teamUiTechnicalDetails,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        children: [
          Text(
            l10n.teamUiHomeHostRawHeading,
            style: theme.textTheme.labelLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          TeamTechnicalValue(
            label: l10n.teamUiGateLabelRequestId,
            value: requestId,
          ),
          TeamTechnicalValue(
            label: l10n.teamUiGateLabelSessionId,
            value: sessionId ?? '',
          ),
          TeamTechnicalValue(
            label: l10n.teamUiGateLabelKind,
            value: gate.rawKind ?? '',
          ),
          if (gate.workId case final work?)
            TeamTechnicalValue(label: l10n.teamUiGateLabelWorkId, value: work),
          if (gate.runId case final run?)
            TeamTechnicalValue(label: l10n.teamUiGateLabelRunId, value: run),
          for (final (key, value) in scalars)
            TeamTechnicalValue(label: key, value: value),
        ],
      ),
    );
  }
}
