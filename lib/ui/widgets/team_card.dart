/// The Work tab's AI Team section (02-ux-flows-and-screens §2, redesigned in
/// docs/design/aiteam-redesign-2026-09-24.md): one section of at most
/// three rows under its header, the height budget of a conversation group.
///
/// - **Header**: "AI Team" and where the team runs ("On this phone", "On
///   pop-os", plus "· Not answering" or "· Paused"), with a trailing
///   chevron. The whole header opens the AI Team home; there is no Open
///   button.
/// - **Needs you**, when something does: the most urgent question's first
///   line and "Answer"; it opens the Gate sheet.
/// - **One row per running or waiting task**, what needs the person first,
///   two at most, leaving out the task the question already names: the
///   title and one line ("Working · 3 of 5 steps done"). A row opens the
///   home.
/// - Nothing running or waiting: one muted line, "Nothing running · Give
///   the team a task".
///
/// No percentage, bar, step strip, dots, completed count or Refresh: the
/// rows say it in words, the section follows the controller, and a person
/// who wants to try again opens the home, whose status line offers it.
/// Stale data dims the rows (they stay readable) and stops their taps; the
/// header still opens the home.
///
/// States: loading is skeleton rows; a failed probe the honest inline state
/// with Try again (03-onboarding §5). The section is never in the tree when
/// the profile has no plugin config: `WorkspaceScreen` adds it only when
/// `ConnectionController.orchestration` is non-null.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../screens/team/gate_sheet.dart';
import '../screens/team/team_needs_you.dart';
import 'team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Rows under the header, at most: a question and two tasks.
const teamCardMaxRows = 3;

/// Task rows, at most.
const _maxTaskRows = 2;

class TeamCard extends StatefulWidget {
  const TeamCard({super.key, required this.controller, required this.onOpen});

  final OrchestrationController controller;

  /// Opens the AI Team home (TEAM-108): the header and every task row.
  final VoidCallback onOpen;

  @override
  State<TeamCard> createState() => TeamCardState();
}

/// Public so tests can find the section's state.
class TeamCardState extends State<TeamCard> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      final controller = widget.controller;
      if (controller.phase == OrchestrationPhase.failed) {
        await controller.retry();
      } else {
        await controller.refresh();
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    // Each body carries its state key (`team-card-loading`, `-error`,
    // `-data`); stale adds `team-card-stale` around the rows.
    final Widget body;
    switch (controller.phase) {
      case OrchestrationPhase.failed:
        body = _ErrorBody(
          error: controller.lastError,
          onRetry: _retrying ? null : _retry,
        );
      case OrchestrationPhase.idle:
      case OrchestrationPhase.probing:
      case OrchestrationPhase.connecting:
      case OrchestrationPhase.stopped:
        body = const _LoadingBody();
      case OrchestrationPhase.ready:
        if (!snapshot.hasData) {
          body = controller.lastError != null
              ? _ErrorBody(
                  error: controller.lastError,
                  onRetry: _retrying ? null : _retry,
                )
              : const _LoadingBody();
        } else {
          body = _DataBody(controller: controller, onOpen: widget.onOpen);
        }
    }
    // A section, not a card (design standard §3, §6): the header, then the
    // rows on the list's own rails. A transparent ink surface of its own,
    // so its rows can splash wherever the section is placed.
    return Material(
      key: const ValueKey('team-card'),
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(controller: controller, onOpen: widget.onOpen),
          body,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// "AI Team · On this phone ›": the section's label with where the team
/// runs; the whole row opens the home.
class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onOpen});

  final OrchestrationController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final label = theme.textTheme.bodySmall?.copyWith(
      color: muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );
    final phrase = teamHostPhrase(l10n, controller);
    return Semantics(
      button: true,
      hint: l10n.teamUiCardOpenHint,
      child: InkWell(
        key: const ValueKey('team-card-open'),
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            // The Work list's section spacing (SectionLabel), with the
            // chevron's own inset at the end.
            padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.teamUiHomeTitle, style: label),
                        TextSpan(
                          text: '$teamUsageSeparator$phrase',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    key: const ValueKey('team-card-title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(AppIconography.chevronRight, size: 20, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading, error
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    // The shape of the rows to come (§4); the label says what it waits on.
    return Semantics(
      key: const ValueKey('team-card-loading'),
      label: l10n.teamUiCardLoading,
      child: const KitSkeletonRows(count: 2),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final OrchestrationError? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return KitStateView(
      key: const ValueKey('team-card-error'),
      size: KitStateSize.inline,
      liveRegion: false,
      icon: AppIconography.warning,
      tone: AppStatusTone.attention,
      // The honest copy (03 §5) is the state itself.
      title: teamErrorCopy(l10n, error?.kind),
      titleKey: const ValueKey('team-card-error-copy'),
      secondary: KitAction(
        key: const ValueKey('team-card-retry'),
        label: l10n.teamUiCardRetry,
        icon: AppIcons.retry,
        onPressed: onRetry,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data: the question, the tasks
// ---------------------------------------------------------------------------

class _DataBody extends StatelessWidget {
  const _DataBody({required this.controller, required this.onOpen});

  final OrchestrationController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final snapshot = controller.snapshot;
    final stale = controller.isStale;
    final gated = teamGatedRuns(snapshot);
    // Only open tasks show here, so no age is ever drawn from the clock.
    final now = DateTime.now();
    // Review-ready is informational: only what waits on the person.
    final question = teamOpenGates(
      controller,
    ).where((gate) => gate.kind != GateKind.reviewReady).firstOrNull;
    // The task the question belongs to is named by the question already.
    final asked = question == null ? null : teamGateRunId(snapshot, question);
    // The host's upkeep (patrols, chores) is not the person's work.
    final open = [
      for (final run in teamVisibleRuns(snapshot.runs))
        if (run.state != RunState.completed &&
            run.state != RunState.cancelled &&
            run.id != asked)
          run,
    ]..sort((a, b) => teamCompareRuns(a, b, gated));
    final tasks = open.take(_maxTaskRows).toList();
    final canGive = controller.capabilities.controlMessage;

    final rows = <Widget>[
      if (question != null)
        KitRow(
          key: const ValueKey('team-card-needs-you'),
          leading: const KitTaskMark(state: KitTaskState.needsYou),
          // The question's first line, whole: two lines before it ends.
          title: question.title.split('\n').first,
          titleMaxLines: 2,
          titleKey: const ValueKey('team-card-question'),
          trailing: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
            child: Text(
              l10n.teamUiHomeNeedsYouAnswer,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          onTap: stale
              ? null
              : () => showGateSheet(context, controller, question.id),
        ),
      for (final run in tasks)
        KitRow(
          key: ValueKey('team-card-run-${run.id}'),
          leading: KitTaskMark(
            state: teamRunMark(run, needsYou: gated.contains(run.id)),
          ),
          title: run.title,
          supporting: TextSpan(
            text: teamTaskLine(
              l10n,
              run,
              snapshot.work,
              needsYou: gated.contains(run.id),
              now: now,
              cycleOf: controller.cycleFor,
            ),
          ),
          supportingKey: ValueKey('team-card-run-line-${run.id}'),
          onTap: stale ? null : onOpen,
        ),
      if (question == null && tasks.isEmpty)
        InkWell(
          key: ValueKey(
            teamVisibleRuns(snapshot.runs).isEmpty
                ? 'team-card-empty'
                : 'team-card-idle',
          ),
          onTap: stale ? null : onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  [
                    l10n.teamUiCardNothingRunning,
                    if (canGive) l10n.teamUiStartRunFab,
                  ].join(teamUsageSeparator),
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            ),
          ),
        ),
    ];
    assert(rows.length <= teamCardMaxRows);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
    return Padding(
      key: const ValueKey('team-card-data'),
      padding: const EdgeInsets.only(bottom: 8),
      // Stale rows dim; they stay readable (never colour-only), and the
      // header's "Not answering" says why.
      child: stale
          ? Opacity(
              key: const ValueKey('team-card-stale'),
              opacity: .6,
              child: column,
            )
          : column,
    );
  }
}
