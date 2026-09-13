/// The Workspace "AI Team" card (02-ux-flows-and-screens §2): one number,
/// one sentence, one action. Header with the provider named openly, the
/// working-agent count, the host mode and the one-line performance
/// disclaimer for the kind of host (03-onboarding §4); a hero percentage; a
/// state-generated sentence; a segmented progress bar (done / working /
/// blocked, blocked in amber); up to three run rows with completed runs
/// collapsed; the agent constellation; and Open plus Refresh. Under the
/// headline batch's row, while that batch is not done, the compact
/// dispatch cycle strip (TEAM-116) says which step it is on and since
/// when.
///
/// States (§2.3): loading skeleton, empty, stale (dimmed, read-only except
/// Refresh), error (honest copy from 03 §5) and normal. The card is never
/// in the tree when the profile has no plugin config: `WorkspaceScreen`
/// adds it only when `ConnectionController.orchestration` is non-null.
///
/// Motion: the working dots and the cycle strip's current dot carry one
/// very small pulse from a single [AnimationController] that is not
/// created at all under reduced motion (`MediaQuery.disableAnimationsOf`),
/// so no ticker ever runs there.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';
import 'team_cycle_strip.dart';
import 'team_discovery_card.dart' show teamHostDisclaimer, teamHostKindFor;
import 'team_vocabulary.dart';

/// Rows the card shows before collapsing the rest into "N more runs".
const _maxRunRows = 3;

class TeamCard extends StatefulWidget {
  const TeamCard({super.key, required this.controller, required this.onOpen});

  final OrchestrationController controller;

  /// Opens the AI Team home (TEAM-108). Also what a run row and "N more
  /// runs" do until the run screen lands.
  final VoidCallback onOpen;

  @override
  State<TeamCard> createState() => TeamCardState();
}

/// Public so tests can read [debugHasAnimation].
class TeamCardState extends State<TeamCard> with TickerProviderStateMixin {
  AnimationController? _pulse;
  bool _refreshing = false;

  /// True while the pulse controller exists (never under reduced motion).
  bool get debugHasAnimation => _pulse != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncPulse);
  }

  @override
  void didUpdateWidget(TeamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncPulse);
      widget.controller.addListener(_syncPulse);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPulse);
    _pulse?.dispose();
    super.dispose();
  }

  /// Creates the pulse only while there is something to pulse and motion is
  /// allowed; drops it (ticker and all) the moment either stops holding.
  void _syncPulse() {
    if (!mounted) return;
    final controller = widget.controller;
    final cycleWork = _headlineCycleWork(controller);
    final wanted =
        !MediaQuery.disableAnimationsOf(context) &&
        controller.phase == OrchestrationPhase.ready &&
        controller.snapshot.hasData &&
        !controller.isStale &&
        (controller.snapshot.agents.any((a) => a.state == AgentState.working) ||
            (cycleWork != null && !controller.cycleFor(cycleWork).isTerminal));
    if (wanted == (_pulse != null)) return;
    if (wanted) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
    setState(() {});
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final controller = widget.controller;
      if (controller.phase == OrchestrationPhase.failed) {
        await controller.retry();
      } else {
        await controller.refresh();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    // Each body carries its state key (`team-card-loading`, `-empty`,
    // `-error`, `-data`); stale adds `team-card-stale` inside the data.
    final Widget body;
    switch (controller.phase) {
      case OrchestrationPhase.failed:
        body = _ErrorBody(
          error: controller.lastError,
          onRetry: _refreshing ? null : _refresh,
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
                  onRetry: _refreshing ? null : _refresh,
                )
              : const _LoadingBody();
        } else if (teamVisibleRuns(snapshot.runs).isEmpty) {
          body = _EmptyBody(
            onOpen: widget.onOpen,
            onRefresh: _refreshing ? null : _refresh,
          );
        } else {
          body = _DataBody(
            controller: controller,
            stale: controller.isStale,
            pulse: _pulse,
            onOpen: widget.onOpen,
            onRefresh: _refreshing ? null : _refresh,
          );
        }
    }
    return Card(
      key: const ValueKey('team-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(controller: controller, l10n: l10n),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

/// The least-advanced item of the headline batch while that batch still
/// moves (TEAM-116), for the compact strip under its row and the pulse;
/// null when the headline is a formula run, is done, or tracks no work.
String? _headlineCycleWork(OrchestrationController controller) {
  final snapshot = controller.snapshot;
  if (controller.phase != OrchestrationPhase.ready || !snapshot.hasData) {
    return null;
  }
  final visible = teamVisibleRuns(snapshot.runs);
  if (visible.isEmpty) return null;
  final gated = teamGatedRuns(snapshot);
  visible.sort((a, b) => teamCompareRuns(a, b, gated));
  final headline = visible.first;
  if (headline.kind != RunKind.batch ||
      headline.state == RunState.completed ||
      headline.state == RunState.cancelled) {
    return null;
  }
  return controller.cycleWorkForRun(headline.id);
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.l10n});

  final OrchestrationController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final snapshot = controller.snapshot;
    // Live agents only: a suspended or stopped entry is nobody working.
    final working = teamLiveAgents(
      snapshot.agents,
    ).where((a) => a.state == AgentState.working).length;
    final attention = controller.phase == OrchestrationPhase.ready
        ? controller.attentionCount
        : 0;
    final host = controller.host;
    final hostMode = host?.hostMode ?? controller.config.hostMode;
    final hostKind = teamHostKindFor(controller.config, hostMode);
    final hostName = teamHostNameOf(controller);
    final city = host?.city ?? controller.config.city;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final dot = Text(' · ', style: small);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap, not a Row: at large text the pill drops under the name
        // instead of squeezing it.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIconography.agent, size: 20, color: muted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.teamUiCardTitle,
                    key: const ValueKey('team-card-title'),
                    style: theme.textTheme.titleSmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            if (attention > 0)
              _NeedsYouPill(
                key: const ValueKey('team-card-needs-you'),
                text: l10n.teamUiCardNeedsYou(attention),
              ),
          ],
        ),
        if (controller.phase == OrchestrationPhase.ready && snapshot.hasData)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.teamUiCardAgentsWorking(working),
                  key: const ValueKey('team-card-agents-working'),
                  style: small,
                ),
                dot,
                Text(
                  switch (hostMode) {
                    OrchestrationHostMode.computer =>
                      l10n.teamUiCardHostComputer,
                    OrchestrationHostMode.phone => l10n.teamUiCardHostPhone,
                  },
                  key: const ValueKey('team-card-host-mode'),
                  style: small,
                ),
                dot,
                // The host's name is an identifier: LTR in every locale.
                Text(
                  hostName,
                  key: const ValueKey('team-card-host-name'),
                  style: small,
                  textDirection: TextDirection.ltr,
                ),
                if (city.isNotEmpty) ...[
                  dot,
                  // The Gas City term is an identifier: LTR in every locale.
                  Text(
                    l10n.teamUiCardCity(city),
                    key: const ValueKey('team-card-city'),
                    style: small,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ],
            ),
          ),
        // The disclaimer follows the config, so it is there in every state:
        // a sleeping laptop is exactly when the card is stale or failing.
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            teamHostDisclaimer(l10n, hostKind),
            key: const ValueKey('team-card-disclaimer'),
            style: small?.copyWith(height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _NeedsYouPill extends StatelessWidget {
  const _NeedsYouPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amber = AppTheme.statusColor(theme, AppStatusTone.attention);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIconography.warning, size: 14, color: amber),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading, empty, error
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final bone = theme.colorScheme.outlineVariant.withValues(alpha: .5);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bone,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    // A still skeleton: the header is real, the rest is shape only.
    return Semantics(
      key: const ValueKey('team-card-loading'),
      label: l10n.teamUiCardLoading,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(120, 28),
            const SizedBox(height: 12),
            bar(220, 14),
            const SizedBox(height: 14),
            bar(double.infinity, 6),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onOpen, required this.onRefresh});

  final VoidCallback onOpen;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('team-card-empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.teamUiCardEmptyTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.teamUiCardEmptyHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.mutedOf(theme),
          ),
        ),
        const SizedBox(height: 14),
        _Actions(onOpen: onOpen, onRefresh: onRefresh),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final OrchestrationError? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final copy = teamErrorCopy(l10n, error?.kind);
    return Column(
      key: const ValueKey('team-card-error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AppIconography.warning,
              size: 20,
              color: AppTheme.statusColor(theme, AppStatusTone.attention),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                copy,
                key: const ValueKey('team-card-error-copy'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const ValueKey('team-card-retry'),
            onPressed: onRetry,
            icon: const Icon(AppIcons.retry, size: 18),
            label: Text(l10n.teamUiCardRetry),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Data: hero, sentence, bar, rows, constellation, actions
// ---------------------------------------------------------------------------

class _DataBody extends StatelessWidget {
  const _DataBody({
    required this.controller,
    required this.stale,
    required this.pulse,
    required this.onOpen,
    required this.onRefresh,
  });

  final OrchestrationController controller;
  final bool stale;
  final AnimationController? pulse;
  final VoidCallback onOpen;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final snapshot = controller.snapshot;
    final gated = teamGatedRuns(snapshot);
    // The host's upkeep (patrols, chores) is not the person's work: it
    // neither heads the card nor counts in the collapsed lines.
    final ordered = teamVisibleRuns(snapshot.runs)
      ..sort((a, b) => teamCompareRuns(a, b, gated));
    final headline = ordered.first;
    final progress = TeamRunProgress.of(headline, snapshot.work);
    final open = [
      for (final run in ordered)
        if (run.state != RunState.completed) run,
    ];
    final completed = ordered.length - open.length;
    final rows = open.take(_maxRunRows).toList();
    final more = open.length - rows.length;
    final tapsAllowed = !stale;
    // The headline batch's dispatch cycle (TEAM-116): its least-advanced
    // item, while the batch is still moving.
    final cycleWork = _headlineCycleWork(controller);
    final refreshedAt = controller.lastRefreshedAt;
    final time = refreshedAt == null
        ? ''
        : teamClockLabel(context, refreshedAt);

    final percent = progress.percent;
    // Waiting for merge (TEAM-117): every open item is in the merge
    // agent's hands, so the word and the sentence name the merge.
    final awaitsMerge = teamRunAwaitsMerge(
      headline,
      snapshot.work,
      cycleOf: controller.cycleFor,
    );
    final hero = percent == null
        ? teamRunStateWordFor(
            l10n,
            headline,
            snapshot.work,
            cycleOf: controller.cycleFor,
          )
        : l10n.teamUiCardPercentDone(percent);
    final sentence = gated.contains(headline.id)
        ? l10n.teamUiCardSentenceNeedsYou(headline.title)
        : awaitsMerge
        ? l10n.teamUiCardSentenceWaitingMerge(headline.title)
        : switch (headline.state) {
            RunState.planning => l10n.teamUiCardSentencePlanning(
              headline.title,
            ),
            RunState.working => l10n.teamUiCardSentenceWorking(headline.title),
            RunState.waiting => l10n.teamUiCardSentenceWaiting(headline.title),
            RunState.blocked => l10n.teamUiCardSentenceBlocked(headline.title),
            RunState.failed => l10n.teamUiCardSentenceFailed(headline.title),
            RunState.completed => l10n.teamUiCardSentenceCompleted(
              headline.title,
            ),
            RunState.cancelled => l10n.teamUiCardSentenceCancelled(
              headline.title,
            ),
            RunState.unknown => l10n.teamUiCardSentenceUnknown(headline.title),
          };

    final numbers = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hero,
          key: const ValueKey('team-card-hero'),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sentence,
          key: const ValueKey('team-card-sentence'),
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        _SegmentedBar(progress: progress),
        const SizedBox(height: 8),
        for (final run in rows) ...[
          _RunRow(
            key: ValueKey('team-card-run-${run.id}'),
            run: run,
            stateWord: teamRunStateWordFor(
              l10n,
              run,
              snapshot.work,
              cycleOf: controller.cycleFor,
            ),
            needsYou: gated.contains(run.id),
            onTap: tapsAllowed ? onOpen : null,
          ),
          if (run.id == headline.id && cycleWork != null)
            Padding(
              key: const ValueKey('team-card-cycle'),
              padding: const EdgeInsetsDirectional.fromSTEB(28, 0, 0, 8),
              child: TeamCycleStrip(
                controller: controller,
                workId: cycleWork,
                compact: true,
                pulse: pulse,
                ownPulse: false,
              ),
            ),
        ],
        if (completed > 0)
          _CollapsedRow(
            key: const ValueKey('team-card-completed-runs'),
            icon: AppIconography.check,
            color: AppTheme.statusColor(theme, AppStatusTone.ok),
            text: l10n.teamUiCardCompletedRuns(completed),
            onTap: tapsAllowed ? onOpen : null,
          ),
        if (more > 0)
          _CollapsedRow(
            key: const ValueKey('team-card-more-runs'),
            icon: AppIconography.chevronRight,
            color: muted,
            text: l10n.teamUiCardMoreRuns(more),
            onTap: tapsAllowed ? onOpen : null,
          ),
        const SizedBox(height: 8),
        _Constellation(agents: teamLiveAgents(snapshot.agents), pulse: pulse),
      ],
    );

    return Column(
      key: const ValueKey('team-card-data'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Notice(
              key: const ValueKey('team-card-stale'),
              icon: AppIconography.cloudOff,
              text: l10n.teamUiCardStale(time),
            ),
          )
        else if (controller.lastError?.kind ==
            OrchestrationErrorKind.readFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Notice(
              key: const ValueKey('team-card-refresh-failed'),
              icon: AppIconography.warning,
              text: l10n.teamUiCardRefreshFailed(time),
            ),
          ),
        // Stale numbers dim; they stay readable (never colour-only).
        stale ? Opacity(opacity: .6, child: numbers) : numbers,
        const SizedBox(height: 14),
        _Actions(onOpen: tapsAllowed ? onOpen : null, onRefresh: onRefresh),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// One bar, three segments: done in the accent, working in a lighter
/// accent, blocked in amber. Widths are proportional to the counts.
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.progress});

  final TeamRunProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = progress.total;
    final track = colors.outlineVariant.withValues(alpha: .5);
    int flex(int n) => total <= 0 ? 0 : n;
    final rest = total <= 0
        ? 1
        : total - progress.done - progress.working - progress.blocked;
    return Semantics(
      key: const ValueKey('team-card-bar'),
      label: l10n.teamUiCardProgressSummary(
        progress.done,
        progress.working,
        progress.blocked,
        total,
      ),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              // Stretch: a childless ColoredBox has no height of its own.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (flex(progress.done) > 0)
                  Expanded(
                    flex: progress.done,
                    child: ColoredBox(
                      key: const ValueKey('team-card-bar-done'),
                      color: colors.primary,
                    ),
                  ),
                if (flex(progress.working) > 0)
                  Expanded(
                    flex: progress.working,
                    child: ColoredBox(
                      key: const ValueKey('team-card-bar-working'),
                      color: colors.primary.withValues(alpha: .45),
                    ),
                  ),
                if (flex(progress.blocked) > 0)
                  Expanded(
                    flex: progress.blocked,
                    child: ColoredBox(
                      key: const ValueKey('team-card-bar-blocked'),
                      color: AppTheme.statusColor(
                        theme,
                        AppStatusTone.attention,
                      ),
                    ),
                  ),
                if (rest > 0)
                  Expanded(
                    flex: rest,
                    child: ColoredBox(color: track),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({
    super.key,
    required this.run,
    required this.stateWord,
    required this.needsYou,
    required this.onTap,
  });

  final OrchestrationRun run;

  /// The run's state word, with the merge wait named (TEAM-117).
  final String stateWord;
  final bool needsYou;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = needsYou
        ? (AppIconography.warning, AppStatusTone.attention)
        : teamRunGlyph(run.state);
    final color = AppTheme.statusColor(theme, tone);
    final term = switch (run.kind) {
      RunKind.batch => l10n.teamUiCardRunTermBatch,
      RunKind.formula => l10n.teamUiCardRunTermFormula,
      RunKind.unknown => null,
    };
    final title = Text.rich(
      TextSpan(
        text: run.title,
        children: [
          if (term != null)
            TextSpan(
              text: '  $term',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final word = Text(
      stateWord,
      style: theme.textTheme.bodySmall?.copyWith(color: color),
    );
    // At large text the state word drops under the title rather than
    // squeezing it to a sliver.
    final stacked = AppTheme.stackedActions(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, word],
                      )
                    : title,
              ),
              if (!stacked) ...[const SizedBox(width: 10), word],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedRow extends StatelessWidget {
  const _CollapsedRow({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dot per live agent, coloured by state: red only for a crashed one;
/// stopped and suspended agents are never dots. Working dots carry the
/// pulse when [pulse] exists; the strip is one semantics node with the
/// counts.
class _Constellation extends StatelessWidget {
  const _Constellation({required this.agents, required this.pulse});

  final List<OrchestrationAgent> agents;
  final AnimationController? pulse;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    var working = 0, waiting = 0, idle = 0, stopped = 0;
    for (final agent in agents) {
      switch (agent.state) {
        case AgentState.working:
          working += 1;
        case AgentState.waiting:
        case AgentState.blocked:
          waiting += 1;
        case AgentState.idle:
          idle += 1;
        case AgentState.stopped:
        case AgentState.crashed:
        case AgentState.unknown:
          stopped += 1;
      }
    }
    Color colorOf(AgentState state) => switch (state) {
      AgentState.working => colors.primary,
      AgentState.idle => AppTheme.mutedOf(theme),
      AgentState.waiting || AgentState.blocked => AppTheme.statusColor(
        theme,
        AppStatusTone.attention,
      ),
      AgentState.crashed => colors.error,
      AgentState.stopped || AgentState.unknown => colors.outlineVariant,
    };
    final dots = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final agent in agents)
          _AgentDot(
            key: ValueKey('team-card-agent-${agent.id}'),
            color: colorOf(agent.state),
            pulse: agent.state == AgentState.working ? pulse : null,
          ),
      ],
    );
    return Semantics(
      key: const ValueKey('team-card-constellation'),
      label: l10n.teamUiCardAgentsSummary(
        agents.length,
        working,
        waiting,
        idle,
        stopped,
      ),
      child: ExcludeSemantics(child: dots),
    );
  }
}

class _AgentDot extends StatelessWidget {
  const _AgentDot({super.key, required this.color, required this.pulse});

  final Color color;
  final AnimationController? pulse;

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: const SizedBox.square(dimension: 8),
    );
    final animation = pulse;
    if (animation == null) return dot;
    // A very small breath: 8dp to 10dp and back, nothing else moves.
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1,
        end: 1.25,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onOpen, required this.onRefresh});

  final VoidCallback? onOpen;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          key: const ValueKey('team-card-open'),
          onPressed: onOpen,
          icon: const Icon(AppIconography.chevronRight, size: 18),
          label: Text(l10n.teamUiCardOpen),
        ),
        TextButton.icon(
          key: const ValueKey('team-card-refresh'),
          onPressed: onRefresh,
          icon: const Icon(AppIconography.sync, size: 18),
          label: Text(l10n.teamUiCardRefresh),
        ),
      ],
    );
  }
}
