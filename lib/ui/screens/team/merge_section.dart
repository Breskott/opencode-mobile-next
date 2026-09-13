/// The run Overview's Merge section (TEAM-205, 02-ux-flows-and-screens
/// §8a): present only once every work item of the run is done or
/// review-ready and the host has merge roles
/// ([OrchestrationCapabilities.mergeReadiness] with an adapter that
/// implements [OrchestrationMergeGateway]).
///
/// ```
/// READY TO MERGE · merge request gc-mr-14
/// ✓ 18/18 work items   ✓ Tests   ✓ Build   ✓ Review   ✓ No conflicts
/// ✓ Acceptance criteria
/// 14 files · +841 / −203
/// [ Review changes ]   [ Approve request ]   [ Merge ]
/// ```
///
/// The readiness lines come from the front's `/merge-readiness`; any
/// missing line disables Merge and says why. **Approve request** needs
/// one confirmation. **Merge** is two-step: the first tap arms the button
/// ("Confirm merge"), the second opens the destructive sheet "Merge into
/// main? This cannot be undone from the phone". The host's boundaries
/// ("Never merge without approval") are shown when they block, never
/// silently applied. Force-merge, branch reset and worktree deletion do
/// not exist here, on the host front, or anywhere on the phone.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/team_vocabulary.dart';
import 'work_sheet.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// How long the Merge button stays armed after the first tap.
const teamMergeArmWindow = Duration(seconds: 8);

/// Readiness line keys the section knows a label for, in the §8a order.
const teamMergeKnownLines = [
  'work',
  'tests',
  'build',
  'review',
  'conflicts',
  'acceptance',
];

/// The localized label of a readiness line; an unknown (configured) key
/// is shown as the host named it.
String teamMergeLineLabel(AppLocalizations l10n, String key) => switch (key) {
  'work' => l10n.teamUiMergeLineWork,
  'tests' => l10n.teamUiMergeLineTests,
  'build' => l10n.teamUiMergeLineBuild,
  'review' => l10n.teamUiMergeLineReview,
  'conflicts' => l10n.teamUiMergeLineConflicts,
  'acceptance' => l10n.teamUiMergeLineAcceptance,
  _ => key,
};

/// True when every work item of [run] is done or review-ready (cancelled
/// items have nothing to merge and do not hold the section back); without
/// tracked items the run's own step counts or completed state decide.
bool teamMergeWorkDone(OrchestrationRun run, List<WorkItem> work) {
  var any = false;
  for (final item in work) {
    if (item.runId != run.id) continue;
    any = true;
    switch (item.state) {
      case WorkState.completed:
      case WorkState.review:
      case WorkState.cancelled:
        break;
      case WorkState.queued:
      case WorkState.ready:
      case WorkState.working:
      case WorkState.waiting:
      case WorkState.blocked:
      case WorkState.needsInput:
      case WorkState.failed:
      case WorkState.unknown:
        return false;
    }
  }
  if (any) return true;
  if (run.state == RunState.completed) return true;
  final total = run.stepCount ?? 0;
  return total > 0 && (run.completedSteps ?? 0) >= total;
}

/// The section belongs in the Overview: the capability is on, the adapter
/// has merge roles and the run's work is done.
bool teamMergeEligible(
  OrchestrationController controller,
  OrchestrationRun run,
) {
  if (!controller.capabilities.mergeReadiness) return false;
  if (controller.gateway is! OrchestrationMergeGateway) return false;
  return teamMergeWorkDone(run, controller.snapshot.work);
}

/// The Merge section, appended at the end of the run Overview.
class TeamMergeSection extends StatefulWidget {
  const TeamMergeSection({
    super.key,
    required this.controller,
    required this.run,
    this.now,
  });

  final OrchestrationController controller;
  final OrchestrationRun run;

  /// Clock for the Work sheet's ages; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamMergeSection> createState() => _TeamMergeSectionState();
}

class _TeamMergeSectionState extends State<TeamMergeSection> {
  bool _armed = false;
  Timer? _disarm;
  bool _requested = false;

  OrchestrationController get _controller => widget.controller;
  OrchestrationRun get _run => widget.run;

  @override
  void didUpdateWidget(TeamMergeSection old) {
    super.didUpdateWidget(old);
    if (old.run.id != widget.run.id || old.controller != widget.controller) {
      _requested = false;
    }
  }

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  /// Asks the controller for the readiness once the frame is built (the
  /// controller notifies, and a notify during build is an error). Called
  /// from build only while the section is eligible, so a run with open
  /// work never costs the host a readiness computation.
  void _request() {
    if (_requested) return;
    _requested = true;
    final controller = _controller;
    final runId = _run.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(controller.mergeReadiness(runId));
    });
  }

  void _arm() {
    _disarm?.cancel();
    setState(() => _armed = true);
    _disarm = Timer(teamMergeArmWindow, () {
      if (mounted) setState(() => _armed = false);
    });
  }

  void _disarmNow() {
    _disarm?.cancel();
    _disarm = null;
    if (_armed && mounted) setState(() => _armed = false);
  }

  Future<void> _onMergeTap(MergeReadiness readiness) async {
    if (!_armed) {
      _arm();
      return;
    }
    _disarmNow();
    final l10n = _copy(context);
    final branch = readiness.targetBranch ?? 'main';
    final confirmed = await showConfirmSheet(
      context,
      icon: AppIconography.branch,
      title: l10n.teamUiMergeConfirmTitle(branch),
      message: l10n.teamUiMergeConfirmMessage,
      confirmLabel: l10n.teamUiMergeConfirmAction(branch),
      destructive: true,
      sheetKey: const ValueKey('team-merge-confirm-sheet'),
      confirmKey: const ValueKey('team-merge-confirm'),
    );
    if (!confirmed || !mounted) return;
    await _controller.mergeRun(_run.id);
  }

  Future<void> _onApproveTap(MergeRequestInfo request) async {
    final l10n = _copy(context);
    final confirmed = await showConfirmSheet(
      context,
      icon: AppIconography.check,
      title: l10n.teamUiMergeApproveTitle,
      message: l10n.teamUiMergeApproveMessage,
      confirmLabel: l10n.teamUiMergeApprove,
      sheetKey: const ValueKey('team-merge-approve-sheet'),
      confirmKey: const ValueKey('team-merge-approve-confirm'),
    );
    if (!confirmed || !mounted) return;
    await _controller.approveMergeRequest(request.id, runId: _run.id);
  }

  void _openChanges(MergeReadiness? readiness) {
    final controller = _controller;
    final runId = _run.id;
    final now = widget.now;
    final parent = context;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => _ChangesSheet(
          controller: controller,
          runId: runId,
          readiness: readiness,
          onOpenWork: (id) {
            Navigator.of(sheetContext).pop();
            unawaited(showWorkSheet(parent, controller, id, now: now));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (!teamMergeEligible(_controller, _run)) {
        return const SizedBox.shrink();
      }
      _request();
      final l10n = _copy(context);
      final theme = Theme.of(context);
      final muted = AppTheme.mutedOf(theme);
      final readiness = _controller.mergeReadinessFor(_run.id);
      final error = _controller.mergeReadinessError(_run.id);
      final loading = _controller.mergeReadinessLoading(_run.id);
      final mergeRecord = _controller.latestMutation(
        kind: MutationKind.merge,
        targetId: _run.id,
      );
      final request = readiness?.mergeRequest;
      final approveRecord = request == null
          ? null
          : _controller.latestMutation(
              kind: MutationKind.approveMerge,
              targetId: request.id,
            );
      final merged =
          readiness?.alreadyMerged == true ||
          mergeRecord?.status == MutationStatus.confirmed;
      final tone = merged || readiness?.ready == true
          ? AppStatusTone.ok
          : readiness == null
          ? AppStatusTone.neutral
          : AppStatusTone.attention;
      final color = AppTheme.statusColor(theme, tone);
      final stale = _controller.isStale;
      final mergeBusy = mergeRecord != null && mergeRecord.isSent;
      final approveBusy = approveRecord != null && approveRecord.isSent;
      final approved =
          request?.isApproved == true ||
          approveRecord?.status == MutationStatus.confirmed;
      final canMerge =
          readiness != null &&
          readiness.canMerge &&
          !merged &&
          !mergeBusy &&
          !stale;
      final canApprove =
          request != null && !approved && !approveBusy && !stale && !merged;
      final title = merged
          ? l10n.teamUiMergeTitleMerged
          : readiness?.ready == true
          ? l10n.teamUiMergeTitleReady
          : l10n.teamUiMergeTitleNotReady;

      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Container(
          key: const ValueKey('team-merge-section'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: .06),
            border: Border.all(color: color.withValues(alpha: .45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(title: title, requestId: request?.id, color: color),
              const SizedBox(height: 8),
              if (readiness != null) ...[
                _Lines(readiness: readiness),
                const SizedBox(height: 8),
                Text(
                  merged && readiness.alreadyMerged
                      ? l10n.teamUiMergeAlready(readiness.targetBranch ?? '')
                      : l10n.teamUiMergeFiles(
                          readiness.files,
                          readiness.additions,
                          readiness.deletions,
                        ),
                  key: const ValueKey('team-merge-files'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ] else if (loading) ...[
                Text(
                  l10n.teamUiMergeLoading,
                  key: const ValueKey('team-merge-loading'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ] else ...[
                Text(
                  error == null
                      ? l10n.teamUiMergeNoRoles
                      : l10n.teamUiMergeUnavailable('$error'),
                  key: const ValueKey('team-merge-unavailable'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('team-merge-review'),
                    onPressed: () => _openChanges(readiness),
                    child: Text(l10n.teamUiMergeReviewChanges),
                  ),
                  OutlinedButton(
                    key: const ValueKey('team-merge-approve'),
                    onPressed: canApprove
                        ? () => unawaited(_onApproveTap(request))
                        : null,
                    child: Text(l10n.teamUiMergeApprove),
                  ),
                  FilledButton(
                    key: const ValueKey('team-merge-merge'),
                    onPressed: canMerge
                        ? () => unawaited(_onMergeTap(readiness))
                        : null,
                    child: Text(
                      _armed
                          ? l10n.teamUiMergeConfirmStep
                          : l10n.teamUiMergeMerge,
                    ),
                  ),
                ],
              ),
              ..._notes(
                l10n,
                theme,
                readiness: readiness,
                request: request,
                approved: approved,
                merged: merged,
                canMerge: canMerge,
                mergeRecord: mergeRecord,
                approveRecord: approveRecord,
              ),
            ],
          ),
        ),
      );
    },
  );

  /// The helper lines under the buttons: why Merge is off, the boundary
  /// that blocks, the armed hint, the approval, and the receipts.
  List<Widget> _notes(
    AppLocalizations l10n,
    ThemeData theme, {
    required MergeReadiness? readiness,
    required MergeRequestInfo? request,
    required bool approved,
    required bool merged,
    required bool canMerge,
    required MutationRecord? mergeRecord,
    required MutationRecord? approveRecord,
  }) {
    final muted = AppTheme.mutedOf(theme);
    final attention = AppTheme.statusColor(theme, AppStatusTone.attention);
    final failure = AppTheme.statusColor(theme, AppStatusTone.failure);
    final ok = AppTheme.statusColor(theme, AppStatusTone.ok);
    final notes = <Widget>[];
    void note(String text, {Key? key, Color? color}) {
      notes.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            text,
            key: key,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color ?? muted,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    if (readiness != null && !merged) {
      final missing = readiness.firstMissing;
      final blocking = readiness.firstBlocking;
      if (missing != null) {
        note(
          l10n.teamUiMergeDisabledReason(
            teamMergeLineLabel(l10n, missing.key),
            missing.pending ? l10n.teamUiMergePending : (missing.detail ?? ''),
          ),
          key: const ValueKey('team-merge-disabled-reason'),
          color: attention,
        );
      } else if (blocking != null) {
        note(
          l10n.teamUiMergeBoundary(blocking.text),
          key: const ValueKey('team-merge-boundary'),
          color: attention,
        );
      }
    }
    if (_armed && canMerge) {
      note(
        l10n.teamUiMergeArmedHint,
        key: const ValueKey('team-merge-armed-hint'),
        color: attention,
      );
    }
    final approvedBy = request?.approvedBy;
    if (approvedBy != null && approvedBy.isNotEmpty) {
      note(
        l10n.teamUiMergeApprovedBy(approvedBy),
        key: const ValueKey('team-merge-approved-by'),
        color: ok,
      );
    }
    if (approveRecord != null) {
      final text = switch (approveRecord.status) {
        MutationStatus.sent => l10n.teamUiMergeSent,
        MutationStatus.confirmed => l10n.teamUiMergeApproveConfirmed,
        MutationStatus.rejected => l10n.teamUiMergeRefused(
          approveRecord.receipt?.message ?? '',
        ),
        MutationStatus.unconfirmed => l10n.teamUiReceiptUnconfirmed,
      };
      note(
        text,
        key: const ValueKey('team-merge-approve-receipt'),
        color: approveRecord.status == MutationStatus.rejected
            ? failure
            : approveRecord.status == MutationStatus.confirmed
            ? ok
            : muted,
      );
    }
    if (mergeRecord != null) {
      final boundary = _boundaryOf(mergeRecord);
      final text = switch (mergeRecord.status) {
        MutationStatus.sent => l10n.teamUiMergeSent,
        MutationStatus.confirmed => l10n.teamUiMergeMerged(
          _branchOf(mergeRecord) ?? readiness?.targetBranch ?? '',
          _shortCommit(_commitOf(mergeRecord) ?? readiness?.mergeCommit),
        ),
        MutationStatus.rejected =>
          boundary != null
              ? l10n.teamUiMergeBoundary(boundary)
              : l10n.teamUiMergeRefused(mergeRecord.receipt?.message ?? ''),
        MutationStatus.unconfirmed => l10n.teamUiReceiptUnconfirmed,
      };
      note(
        text,
        key: const ValueKey('team-merge-receipt'),
        color: mergeRecord.status == MutationStatus.rejected
            ? failure
            : mergeRecord.status == MutationStatus.confirmed
            ? ok
            : muted,
      );
    } else if (merged && readiness?.mergeCommit != null) {
      note(
        l10n.teamUiMergeMerged(
          readiness?.targetBranch ?? '',
          _shortCommit(readiness?.mergeCommit),
        ),
        key: const ValueKey('team-merge-receipt'),
        color: ok,
      );
    }
    return notes;
  }
}

/// The receipt body the front stored for a merge or approval: the
/// `body` inside a front receipt, else the raw answer itself.
Map<String, Object?> _bodyOf(MutationRecord record) {
  final raw = record.receipt?.raw ?? const {};
  final body = raw['body'];
  if (body is Map) {
    return {for (final entry in body.entries) '${entry.key}': entry.value};
  }
  return raw;
}

String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The boundary text when the host refused on a boundary (the front's
/// `code: boundary` problem), else null.
String? _boundaryOf(MutationRecord record) {
  final body = _bodyOf(record);
  if (_string(body['code']) != 'boundary' &&
      _string(body['boundary']) == null) {
    return null;
  }
  return _string(body['detail']) ??
      _string(body['boundary']) ??
      record.receipt?.message;
}

String? _commitOf(MutationRecord record) =>
    _string(_bodyOf(record)['mergeCommit']);

String? _branchOf(MutationRecord record) => _string(_bodyOf(record)['branch']);

String _shortCommit(String? sha) {
  if (sha == null) return '';
  return sha.length > 7 ? sha.substring(0, 7) : sha;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.requestId,
    required this.color,
  });

  final String title;
  final String? requestId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final id = requestId;
    final request = id == null ? null : l10n.teamUiMergeRequest(id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(AppIconography.branch, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                title.toUpperCase(),
                key: const ValueKey('team-merge-title'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  letterSpacing: .4,
                ),
              ),
              if (request != null)
                Text(
                  '· $request',
                  key: const ValueKey('team-merge-request'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The readiness lines as ✓ / ✗ chips; a failing line carries its detail.
class _Lines extends StatelessWidget {
  const _Lines({required this.readiness});

  final MergeReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Wrap(
      key: const ValueKey('team-merge-lines'),
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final line in readiness.lines)
          Builder(
            builder: (context) {
              final tone = line.ok
                  ? AppStatusTone.ok
                  : line.pending
                  ? AppStatusTone.progress
                  : AppStatusTone.failure;
              final color = AppTheme.statusColor(theme, tone);
              final label = teamMergeLineLabel(l10n, line.key);
              final detail = line.pending
                  ? l10n.teamUiMergePending
                  : line.detail;
              final showDetail =
                  detail != null &&
                  detail.isNotEmpty &&
                  (!line.ok || line.key == 'work');
              return Row(
                key: ValueKey('team-merge-line-${line.key}'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      line.ok
                          ? AppIconography.check
                          : line.pending
                          ? AppIconography.sync
                          : AppIconography.close,
                      size: 16,
                      color: color,
                      semanticLabel: line.ok ? '✓' : '✗',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: line.ok ? null : color,
                        ),
                        children: [
                          if (showDetail)
                            TextSpan(
                              text: ' · $detail',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: line.ok ? muted : color,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Review changes: the changed files with their +/− counts (no full
/// diff on the phone) and the run's work items, each opening its sheet.
class _ChangesSheet extends StatelessWidget {
  const _ChangesSheet({
    required this.controller,
    required this.runId,
    required this.readiness,
    required this.onOpenWork,
  });

  final OrchestrationController controller;
  final String runId;
  final MergeReadiness? readiness;
  final ValueChanged<String> onOpenWork;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final ok = AppTheme.statusColor(theme, AppStatusTone.ok);
    final failure = AppTheme.statusColor(theme, AppStatusTone.failure);
    final changes = readiness?.changes ?? const <MergeChange>[];
    final work = [
      for (final item in controller.snapshot.work)
        if (item.runId == runId) item,
    ]..sort((a, b) => teamWorkStateRank(a.state) - teamWorkStateRank(b.state));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      minChildSize: .3,
      maxChildSize: .95,
      builder: (context, scroll) => ListView(
        key: const ValueKey('team-merge-changes'),
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(l10n.teamUiMergeChangesTitle, style: theme.textTheme.titleLarge),
          if (readiness != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.teamUiMergeFiles(
                readiness!.files,
                readiness!.additions,
                readiness!.deletions,
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          const SizedBox(height: 12),
          if (changes.isEmpty)
            Text(
              l10n.teamUiMergeChangesEmpty,
              key: const ValueKey('team-merge-changes-empty'),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            )
          else
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIconography.file, size: 16, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        change.path,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '+${change.additions}',
                            style: TextStyle(color: ok),
                          ),
                          const TextSpan(text: ' / '),
                          TextSpan(
                            text: '−${change.deletions}',
                            style: TextStyle(color: failure),
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          if (work.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.teamUiMergeChangesWork,
              style: theme.textTheme.labelLarge?.copyWith(color: muted),
            ),
            const SizedBox(height: 4),
            for (final item in work)
              ListTile(
                key: ValueKey('team-merge-work-${item.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item.title),
                subtitle: Text(teamWorkStateWord(l10n, item.state)),
                trailing: const Icon(AppIconography.chevronRight, size: 18),
                onTap: () => onOpenWork(item.id),
              ),
          ],
        ],
      ),
    );
  }
}
