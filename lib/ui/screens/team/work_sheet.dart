/// The Work sheet (02-ux §4.2): what a row of the Work tab or a node of
/// the graph opens. Title with its Gas City term ("Work · bead oc-loy"),
/// the dispatch cycle strip (TEAM-116: which step, since when, why it
/// waits), state and owner, the description as markdown, what it depends on and
/// what waits on it as chips that jump to the other item's sheet, the
/// branch and worktree in LTR mono, "Open session" only when the adapter
/// can link sessions and this item carries one (Gas City never does), the
/// output excerpt and validation result when the host sent them, the
/// timestamps, then the Technical details expander with every raw field.
/// Actions (Assign to…, Close, Reopen, Nudge owner) are Sprint B.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../orchestration/adapters/gascity/gascity_mappers.dart'
    show WorkItemGasCity;
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../widgets/markdown.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_cycle_strip.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Opens the Work sheet for [workId]. Dependency and blocking chips close
/// this sheet and open the other item's, so [context] must outlive the
/// sheet (the run screen's does). [onOpenSession] receives the linked
/// OpenCode session id; without it no "Open session" is offered.
Future<void> showWorkSheet(
  BuildContext context,
  OrchestrationController controller,
  String workId, {
  DateTime Function()? now,
  ValueChanged<String>? onOpenSession,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => WorkSheet(
    controller: controller,
    workId: workId,
    now: now,
    onOpenSession: onOpenSession,
    onJump: (id) {
      Navigator.of(sheetContext).pop();
      showWorkSheet(
        context,
        controller,
        id,
        now: now,
        onOpenSession: onOpenSession,
      );
    },
  ),
);

/// The OpenCode session an item links to, when the host recorded one
/// (`opencode_session_id` on the item or its metadata). Gas City agents
/// run as `opencode acp` children no server lists, so this is null there.
String? workSessionLink(WorkItem item) {
  final metadata = _map(item.raw['metadata']);
  return _text(item.raw['opencode_session_id']) ??
      _text(metadata['opencode_session_id']) ??
      _text(metadata['oc.session_id']);
}

/// Who owns an item: the agent on it (by work id, id, name or session),
/// else the assignee string as the host sent it; null when nobody.
String? workOwnerName(OrchestrationSnapshot snapshot, WorkItem item) {
  for (final agent in snapshot.agents) {
    if (agent.currentWorkId == item.id) return agent.name;
  }
  final assignee = item.assignee;
  if (assignee == null || assignee.isEmpty) return null;
  for (final agent in snapshot.agents) {
    if (agent.id == assignee ||
        agent.name == assignee ||
        agent.sessionId == assignee ||
        agent.sessionName == assignee) {
      return agent.name;
    }
  }
  return assignee;
}

/// The letter of an owner glyph: the first letter of the last segment of
/// the name ("ocproof/gastown.refinery" → "R").
String workOwnerInitial(String name) {
  final last = name.split(RegExp(r'[/.\s]+')).where((s) => s.isNotEmpty);
  final word = last.isEmpty ? name : last.last;
  return word.isEmpty ? '' : word.substring(0, 1).toUpperCase();
}

/// The output excerpt the host attached to an item, if any.
String? workOutputExcerpt(WorkItem item) {
  final metadata = _map(item.raw['metadata']);
  return _text(item.raw['output_excerpt']) ??
      _text(item.raw['output']) ??
      _text(metadata['output_excerpt']) ??
      _text(metadata['last_output']) ??
      _text(metadata['gc.last_output']);
}

/// A validation result: passed or not, with the host's summary.
class WorkValidation {
  const WorkValidation({required this.passed, this.summary});

  final bool? passed;
  final String? summary;

  static WorkValidation? of(WorkItem item) {
    final metadata = _map(item.raw['metadata']);
    final raw =
        item.raw['validation'] ??
        metadata['validation'] ??
        metadata['validation_result'] ??
        metadata['gc.validation'];
    if (raw == null) return null;
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      final lower = text.toLowerCase();
      return WorkValidation(
        passed: switch (lower) {
          'passed' || 'pass' || 'ok' || 'success' || 'true' => true,
          'failed' || 'fail' || 'error' || 'false' => false,
          _ => null,
        },
        summary: text,
      );
    }
    if (raw is bool) return WorkValidation(passed: raw);
    final map = _map(raw);
    if (map.isEmpty) return null;
    final status = (_text(map['status']) ?? _text(map['result']) ?? '')
        .toLowerCase();
    final passed = map['passed'] is bool
        ? map['passed'] as bool
        : switch (status) {
            'passed' || 'pass' || 'ok' || 'success' => true,
            'failed' || 'fail' || 'error' => false,
            _ => null,
          };
    return WorkValidation(
      passed: passed,
      summary:
          _text(map['summary']) ??
          _text(map['message']) ??
          _text(map['output']) ??
          _text(map['error']),
    );
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, Object?> _map(Object? value) => value is Map
    ? {for (final entry in value.entries) '${entry.key}': entry.value}
    : const {};

class WorkSheet extends StatelessWidget {
  const WorkSheet({
    super.key,
    required this.controller,
    required this.workId,
    required this.onJump,
    this.now,
    this.onOpenSession,
  });

  final OrchestrationController controller;
  final String workId;
  final ValueChanged<String> onJump;
  final DateTime Function()? now;
  final ValueChanged<String>? onOpenSession;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final theme = Theme.of(context);
      final snapshot = controller.snapshot;
      WorkItem? item;
      for (final candidate in snapshot.work) {
        if (candidate.id == workId) {
          item = candidate;
          break;
        }
      }
      if (item == null) {
        return Padding(
          key: const ValueKey('team-work-sheet-missing'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Text(
            l10n.teamUiWorkSheetMissing,
            style: theme.textTheme.bodyMedium,
          ),
        );
      }
      return _Body(
        key: ValueKey('team-work-sheet-${item.id}'),
        controller: controller,
        item: item,
        snapshot: snapshot,
        sessionLink: controller.capabilities.sessionLink,
        now: (now ?? DateTime.now)(),
        onJump: onJump,
        onOpenSession: onOpenSession,
      );
    },
  );
}

class _Body extends StatelessWidget {
  const _Body({
    super.key,
    required this.controller,
    required this.item,
    required this.snapshot,
    required this.sessionLink,
    required this.now,
    required this.onJump,
    required this.onOpenSession,
  });

  final OrchestrationController controller;
  final WorkItem item;
  final OrchestrationSnapshot snapshot;
  final bool sessionLink;
  final DateTime now;
  final ValueChanged<String> onJump;
  final ValueChanged<String>? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final byId = {for (final w in snapshot.work) w.id: w};
    final dependencies = [
      for (final id in {...item.dependsOn})
        if (id != item.id) (id, byId[id]),
    ];
    final blocking = [
      for (final other in snapshot.work)
        if (other.id != item.id && other.dependsOn.contains(item.id))
          (other.id, other),
    ];
    final description = _text(item.raw['description']);
    final owner = workOwnerName(snapshot, item);
    final link = workSessionLink(item);
    final output = workOutputExcerpt(item);
    final validation = WorkValidation.of(item);
    final (icon, tone) = teamWorkGlyph(item.state);
    final color = AppTheme.statusColor(theme, tone);
    final openSession = onOpenSession;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: muted),
      ),
    );

    Widget chips(String prefix, List<(String, WorkItem?)> items) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, other) in items)
          ActionChip(
            key: ValueKey('team-work-$prefix-$id'),
            avatar: other == null
                ? null
                : Icon(
                    teamWorkGlyph(other.state).$1,
                    size: 16,
                    color: AppTheme.statusColor(
                      theme,
                      teamWorkGlyph(other.state).$2,
                    ),
                  ),
            label: Text(
              other?.title ?? id,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: other == null ? null : () => onJump(id),
          ),
      ],
    );

    return SingleChildScrollView(
      key: const ValueKey('team-work-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.title,
            key: const ValueKey('team-work-sheet-title'),
            style: theme.textTheme.titleLarge?.copyWith(height: 1.2),
          ),
          const SizedBox(height: 2),
          TeamTermRow(l10n.teamUiWorkTerm(item.id)),
          const SizedBox(height: 12),
          TeamCycleStrip(
            key: const ValueKey('team-work-sheet-cycle'),
            controller: controller,
            workId: item.id,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    teamWorkStateWord(l10n, item.state),
                    key: const ValueKey('team-work-sheet-state'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIconography.person, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    owner ?? l10n.teamUiWorkOwnerNone,
                    key: const ValueKey('team-work-sheet-owner'),
                    textDirection: owner == null ? null : TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
          if (description != null) ...[
            heading(l10n.teamUiWorkSheetDescription),
            MarkdownText(
              description,
              key: const ValueKey('team-work-sheet-description'),
              selectable: false,
            ),
          ],
          if (dependencies.isNotEmpty) ...[
            heading(l10n.teamUiWorkSheetDependencies),
            chips('dependency', dependencies),
          ],
          if (blocking.isNotEmpty) ...[
            heading(l10n.teamUiWorkSheetBlocking),
            chips('blocking', blocking),
          ],
          if (item.branch != null || item.workDir != null) ...[
            heading(l10n.teamUiWorkSheetCode),
            if (item.branch case final branch?)
              TeamIdentityRow(
                key: const ValueKey('team-work-sheet-branch'),
                label: l10n.teamUiWorkSheetBranch,
                value: branch,
                mono: true,
              ),
            if (item.workDir case final dir?)
              TeamIdentityRow(
                key: const ValueKey('team-work-sheet-worktree'),
                label: l10n.teamUiWorkSheetWorktree,
                value: dir,
                mono: true,
              ),
            if (item.target case final target?)
              TeamIdentityRow(
                label: l10n.teamUiWorkSheetTarget,
                value: target,
                mono: true,
              ),
          ],
          if (sessionLink && link != null && openSession != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const ValueKey('team-work-sheet-open-session'),
                onPressed: () => openSession(link),
                icon: const Icon(AppIconography.chat),
                label: Text(l10n.teamUiWorkSheetOpenSession),
              ),
            ),
          ],
          if (output != null) ...[
            heading(l10n.teamUiWorkSheetOutput),
            Container(
              key: const ValueKey('team-work-sheet-output'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                output,
                textDirection: TextDirection.ltr,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: AppTheme.codeFontSize,
                  height: AppTheme.codeLineHeight,
                ),
              ),
            ),
          ],
          if (validation != null) ...[
            heading(l10n.teamUiWorkSheetValidation),
            _ValidationRow(validation: validation),
          ],
          heading(l10n.teamUiWorkSheetTimestamps),
          if (item.createdAt case final at?)
            TeamIdentityRow(
              key: const ValueKey('team-work-sheet-created'),
              label: l10n.teamUiWorkSheetCreated,
              value: _stamp(context, l10n, at),
            ),
          if (item.updatedAt case final at?)
            TeamIdentityRow(
              key: const ValueKey('team-work-sheet-updated'),
              label: l10n.teamUiWorkSheetUpdated,
              value: _stamp(context, l10n, at),
            ),
          if (_closedAt(item) case final at?)
            TeamIdentityRow(
              label: l10n.teamUiWorkSheetClosed,
              value: _stamp(context, l10n, at),
            ),
          if (item.createdAt == null &&
              item.updatedAt == null &&
              _closedAt(item) == null)
            Text(
              l10n.teamUiWorkSheetNoTimestamps,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          const SizedBox(height: 12),
          _TechnicalDetails(item: item, dependencies: dependencies),
        ],
      ),
    );
  }

  /// "11 Sep 2026 · 09:41 (3h ago)".
  String _stamp(BuildContext context, AppLocalizations l10n, DateTime at) {
    final local = at.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final clock = teamClockLabel(context, at);
    final age = relativeTimeLabel(
      at.millisecondsSinceEpoch,
      now: now,
      l10n: l10n,
    );
    return l10n.teamUiWorkSheetStamp(date, clock, age);
  }

  DateTime? _closedAt(WorkItem item) {
    final raw =
        item.raw['closed_at'] ?? _map(item.raw['metadata'])['closed_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({required this.validation});

  final WorkValidation validation;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final (icon, tone, word) = switch (validation.passed) {
      true => (
        AppIconography.checkCircle,
        AppStatusTone.ok,
        l10n.teamUiWorkSheetValidationPassed,
      ),
      false => (
        AppIconography.error,
        AppStatusTone.failure,
        l10n.teamUiWorkSheetValidationFailed,
      ),
      null => (
        AppIconography.info,
        AppStatusTone.neutral,
        l10n.teamUiWorkSheetValidationUnknown,
      ),
    };
    final color = AppTheme.statusColor(theme, tone);
    final summary = validation.summary;
    return Row(
      key: const ValueKey('team-work-sheet-validation'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                word,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (summary != null && summary != word)
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Technical details expander (02-ux §8): the product values, then
/// every raw scalar the provider sent, each with a copy button.
class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.item, required this.dependencies});

  final WorkItem item;
  final List<(String, WorkItem?)> dependencies;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    const shown = {'id', 'title', 'status', 'description'};
    final scalars = <(String, String)>[];
    void collect(Map<String, Object?> map, String prefix) {
      for (final entry in map.entries) {
        final value = entry.value;
        if (prefix.isEmpty && shown.contains(entry.key)) continue;
        if (value is String || value is num || value is bool) {
          scalars.add(('$prefix${entry.key}', '$value'));
        }
      }
    }

    collect(item.raw, '');
    collect(_map(item.raw['metadata']), 'metadata.');
    scalars.sort((a, b) => a.$1.compareTo(b.$1));
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('team-work-sheet-technical'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          l10n.teamUiTechnicalDetails,
          style: theme.textTheme.titleMedium,
        ),
        children: [
          Text(
            l10n.teamUiHomeHostRawHeading,
            style: theme.textTheme.labelLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          TeamTechnicalValue(label: l10n.teamUiWorkLabelId, value: item.id),
          TeamTechnicalValue(
            label: l10n.teamUiWorkLabelRawState,
            value: item.rawState ?? '',
          ),
          if (item.issueType case final type?)
            TeamTechnicalValue(label: l10n.teamUiWorkLabelType, value: type),
          if (item.runId case final run?)
            TeamTechnicalValue(label: l10n.teamUiWorkLabelRun, value: run),
          if (item.parentId case final parent?)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelParent,
              value: parent,
            ),
          if (item.projectId case final project?)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelProject,
              value: project,
            ),
          if (item.assignee case final assignee?)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelAssignee,
              value: assignee,
            ),
          if (item.sessionId case final session?)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelSession,
              value: session,
            ),
          if (item.sessionName case final name?)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelSessionName,
              value: name,
            ),
          if (item.labels.isNotEmpty)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelLabels,
              value: item.labels.join(', '),
            ),
          if (dependencies.isNotEmpty)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelDependsOn,
              value: [for (final (id, _) in dependencies) id].join(', '),
            ),
          if (item.closedReason case final reason?)
            TeamTechnicalValue(
              label: l10n.teamUiWorkLabelClosedReason,
              value: reason,
            ),
          for (final (key, value) in scalars)
            TeamTechnicalValue(label: key, value: value),
        ],
      ),
    );
  }
}
