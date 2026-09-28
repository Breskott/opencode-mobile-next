import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/models.dart' show ToolState;
import '../../domain/run_result.dart';
import '../../l10n/app_localizations.dart';
import '../agent_error_words.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_diff_view.dart';
import '../kit/kit_layout.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_technical_value.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import 'reader_preferences.dart';
import 'tool_card.dart';

/// Pure presentation of one [RunResult], built from kit parts only
/// (STANDARDS KIT-1). Every line is either copied from a server record or an
/// explicit "unknown"; the only actions are opening the conversation,
/// opening a changed file's recorded diff (straight into the kit's diff page,
/// KitDiffView with its one "Change 1 of N" navigator across the run's
/// files) and opening a tool's own recorded output (a sheet titled with the
/// command or file, sized to that one record and already open) when there is
/// no diff to show.
///
/// The page's top bar carries the conversation's title, so the body opens
/// with the outcome row ("Completed" over "2 steps · 5 min · gpt-5"). The
/// run id, the provider's finish reason, whether this phone saw the run end
/// live, the times and where each list comes from sit in one fold at the
/// end, "How this was put together".
class RunResultView extends StatelessWidget {
  const RunResultView({
    super.key,
    required this.result,
    required this.observedLive,
    required this.onOpenConversation,
    this.sessionTitle,
  });

  final RunResult result;

  /// True only when the controller received the completion of
  /// [RunResult.lastStepID] itself as a live event on this connection.
  final bool observedLive;
  final VoidCallback onOpenConversation;
  final String? sessionTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    Widget onRails(Widget child) => Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.gutter),
      child: child,
    );
    // The source line under a group lines up with the group's label.
    Widget source(String text) => Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter + tokens.space1,
        top: tokens.space2,
        end: tokens.gutter + tokens.space1,
      ),
      child: KitText(
        text,
        role: KitTextRole.caption,
        tone: KitTextTone.tertiary,
      ),
    );
    final gap = SizedBox(height: tokens.sectionGap);
    return LayoutBuilder(
      builder: (context, constraints) {
        // A wide window keeps the page at a readable width, centred; the
        // list itself still scrolls from the window's edge.
        final side = math.max(
          0.0,
          (constraints.maxWidth - KitLayout.paneDetailMaxWidth) / 2,
        );
        return ListView(
          key: const Key('run-result-view'),
          padding: EdgeInsetsDirectional.fromSTEB(
            side,
            tokens.space3,
            side,
            tokens.space6,
          ),
          children: [
            if (!result.boundaryKnown) ...[
              onRails(
                KitNotice(
                  key: const Key('run-result-partial'),
                  icon: AppIconography.history,
                  message: l10n.runResultsPartialHistory,
                  liveRegion: false,
                ),
              ),
              gap,
            ],
            _outcome(context, l10n),
            gap,
            if (!result.hasToolEvidence)
              onRails(
                KitNotice(
                  key: const Key('run-result-no-tools'),
                  icon: AppIconography.question,
                  message: l10n.runResultsNoToolEvidence,
                  liveRegion: false,
                ),
              )
            else ...[
              KitRowGroup(
                label: l10n.runResultsChangedFilesTitle,
                children: [
                  if (result.changedFiles.isEmpty)
                    KitRow(
                      title: l10n.runResultsNoChangedFiles,
                      titleKey: const Key('run-result-no-files'),
                      titleMaxLines: 3,
                    )
                  else
                    for (final file in result.changedFiles)
                      _fileRow(context, l10n, file),
                ],
              ),
              gap,
              KitRowGroup(
                label: l10n.runResultsCommandsTitle,
                children: [
                  if (result.commands.isEmpty)
                    KitRow(
                      title: l10n.runResultsNoCommands,
                      titleKey: const Key('run-result-no-commands'),
                      titleMaxLines: 3,
                    )
                  else
                    for (final command in result.commands)
                      _commandRow(context, l10n, command),
                ],
              ),
              if (result.prunedToolCount > 0)
                source(l10n.runResultsPrunedTools(result.prunedToolCount)),
              if (result.truncated) source(l10n.runResultsTruncated),
            ],
            gap,
            onRails(_howMade(context, l10n)),
            SizedBox(height: tokens.space4),
            onRails(
              KitActionBlock(
                secondary: KitAction(
                  key: const Key('run-result-open-conversation'),
                  label: l10n.runResultsOpenConversation,
                  icon: AppIconography.chat,
                  onPressed: onOpenConversation,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The run in one line under the outcome: steps, how long it took and
  /// the model ("2 steps · 5 min · gpt-5"); an unknown time is left out.
  String _facts(AppLocalizations l10n) {
    final steps = result.boundaryKnown
        ? l10n.runResultsStepsShort(result.stepCount)
        : l10n.runResultsStepsShortAtLeast(result.stepCount);
    final model = result.model?.trim();
    final duration = switch ((result.startedAt, result.finishedAt)) {
      (final start?, final end?) when !end.isBefore(start) => _duration(
        l10n,
        end.difference(start),
      ),
      _ => null,
    };
    return [
      steps,
      ?duration,
      if (model != null && model.isNotEmpty) model,
    ].join(' · ');
  }

  static String _duration(AppLocalizations l10n, Duration elapsed) {
    final minutes = elapsed.inMinutes;
    if (minutes < 1) return l10n.runResultsUnderAMinute;
    if (minutes < 60) return l10n.runResultsMinutes(minutes);
    return l10n.runResultsHoursMinutes(minutes ~/ 60, minutes % 60);
  }

  /// Where this page's words come from, folded at the end: the run id, the
  /// agent, the times, the provider's finish reason, whether this phone saw
  /// the newest step complete, and the source of each list.
  Widget _howMade(BuildContext context, AppLocalizations l10n) {
    final finish = result.outcome.finish?.trim();
    final agent = result.agent?.trim();
    return KitDetailsFold(
      foldKey: const Key('run-result-how-made'),
      label: l10n.runResultsHowMade,
      values: [
        KitTechnicalValue(
          l10n.runResultsRunIdLabel,
          result.runID,
          key: const Key('run-result-id'),
        ),
        if (agent != null && agent.isNotEmpty)
          KitTechnicalValue(l10n.runResultsAgentLabel, agent, copyable: false),
      ],
      notes: [
        result.startedAt == null
            ? l10n.runResultsStartedUnknown
            : l10n.runResultsStarted(_when(context, result.startedAt!)),
        result.finishedAt == null
            ? l10n.runResultsFinishedUnknown
            : l10n.runResultsFinished(_when(context, result.finishedAt!)),
        finish == null || finish.isEmpty
            ? l10n.runResultsFinishReasonMissing
            : l10n.runResultsFinishReason(finish),
        observedLive ? l10n.runResultsObservedLive : l10n.runResultsFromHistory,
        if (result.hasToolEvidence) ...[
          l10n.runResultsChangedFilesSource,
          l10n.runResultsCommandsSource,
        ],
        l10n.runResultsSourceNote,
      ],
    );
  }

  /// How the run ended, as one row: the outcome in words with its own glyph
  /// (never colour alone, STATE-9), the provider's finish reason, and under
  /// it the error, earlier errors and where this came from.
  Widget _outcome(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final roles = ThemeRoles.of(context);
    final outcome = result.outcome;
    final (label, icon, tone) = switch (outcome.kind) {
      RunOutcomeKind.completed => (
        l10n.runResultsOutcomeCompleted,
        AppIconography.checkCircle,
        AppStatusTone.ok,
      ),
      RunOutcomeKind.cutOff => (
        l10n.runResultsOutcomeCutOff,
        AppIconography.cut,
        AppStatusTone.neutral,
      ),
      RunOutcomeKind.failed => (
        l10n.runResultsOutcomeFailed,
        AppIconography.error,
        AppStatusTone.failure,
      ),
      RunOutcomeKind.aborted => (
        l10n.runResultsOutcomeAborted,
        AppIconography.blocked,
        AppStatusTone.failure,
      ),
      RunOutcomeKind.running => (
        l10n.runResultsOutcomeRunning,
        AppIconography.waitingStart,
        AppStatusTone.progress,
      ),
      RunOutcomeKind.notReported => (
        l10n.runResultsOutcomeNotReported,
        AppIconography.question,
        AppStatusTone.neutral,
      ),
    };
    // What went wrong leads the second line when there is an error; the
    // run's facts then follow it.
    final error = switch (outcome.errorHeadline) {
      final headline? => agentErrorWords(
        headline,
        AppLocalizations.of(context),
      ).headline,
      null => null,
    };
    final facts = _facts(l10n);
    return KitRowGroup(
      children: [
        KitRow(
          leading: KitRow.icon(
            context,
            icon,
            color: KitTokens.toneColor(roles, tone),
          ),
          title: label,
          titleKey: const Key('run-result-outcome'),
          titleMaxLines: 2,
          supporting: TextSpan(text: error ?? facts),
          supportingKey: error == null
              ? const Key('run-result-facts')
              : const Key('run-result-error'),
          supportingMaxLines: 3,
          below: error == null && result.earlierStepErrors == 0
              ? null
              : Padding(
                  padding: EdgeInsetsDirectional.only(top: tokens.space1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        KitText(
                          facts,
                          key: const Key('run-result-facts'),
                          role: KitTextRole.secondary,
                        ),
                      if (result.earlierStepErrors > 0)
                        KitText(
                          l10n.runResultsEarlierErrors(
                            result.earlierStepErrors,
                          ),
                          key: const Key('run-result-earlier-errors'),
                          role: KitTextRole.secondary,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// One changed file: its name first, what the tool did, and the folder it
  /// lives in as a technical value (KIT-32). Opens the tool's own record.
  Widget _fileRow(
    BuildContext context,
    AppLocalizations l10n,
    RunChangedFile file,
  ) {
    final change = switch (file.change) {
      RunFileChange.edited => l10n.runResultsChangeEdited,
      RunFileChange.written => l10n.runResultsChangeWritten,
      RunFileChange.patched => l10n.runResultsChangePatched,
    };
    final cut = file.path.lastIndexOf('/');
    final name = cut < 0 ? file.path : file.path.substring(cut + 1);
    final folder = cut <= 0 ? '' : file.path.substring(0, cut);
    final pruned = file.state.pruned;
    return KitRow(
      key: Key('run-result-file-${file.path}'),
      leading: KitRow.icon(context, AppIconography.editNote),
      title: name.isEmpty ? file.path : name,
      supporting: TextSpan(
        text: pruned ? '$change · ${l10n.runResultsOutputPruned}' : change,
      ),
      below: folder.isEmpty
          ? null
          : KitText.mono(
              folder,
              cut: KitMonoCut.middle,
              tone: KitTextTone.tertiary,
            ),
      trailing: pruned ? null : const KitRowValue(''),
      onTap: pruned
          ? null
          : () => _diffOf(file) == null
                ? _openOutput(
                    context,
                    AppIconography.editNote,
                    name.isEmpty ? file.path : name,
                    file.toolName,
                    file.state,
                  )
                : _openDiff(context, l10n, file),
    );
  }

  /// The run's recorded diffs on the kit's diff page, opened at [file]: one
  /// navigator walks every change of the run, file by file.
  Future<void> _openDiff(
    BuildContext context,
    AppLocalizations l10n,
    RunChangedFile file,
  ) {
    final files = <KitDiffFile>[];
    var at = 0;
    for (final changed in result.changedFiles) {
      final diff = changed.state.pruned ? null : _diffOf(changed);
      if (diff == null) continue;
      if (identical(changed, file)) at = files.length;
      files.add(diff);
    }
    final store = ReaderPreferencesScope.maybeOf(context);
    return showKitDiff(
      context,
      title: l10n.runResultsChangedFilesTitle,
      files: files,
      initialFile: at,
      pageKey: const Key('run-result-diff'),
      wrap: store?.value.wrapCode,
      onWrapChanged: store == null
          ? null
          : (wrap) => saveReaderPreferences(context, wrapCode: wrap),
    );
  }

  static final _diffs = Expando<Object>('run result diffs');
  static const _none = Object();

  /// [file]'s change as the tool recorded it (edit: the patch, or the old
  /// and new text; patch: that file's own patch), or null when the record
  /// has no diff (a write records only the new content).
  static KitDiffFile? _diffOf(RunChangedFile file) {
    final cached = _diffs[file] ??= _readDiff(file) ?? _none;
    return cached is KitDiffFile ? cached : null;
  }

  static KitDiffFile? _readDiff(RunChangedFile file) {
    final state = file.state;
    final metadata = state.metadata ?? const <String, dynamic>{};
    String? text(Object? raw) =>
        raw is String && raw.trim().isNotEmpty ? raw : null;
    switch (file.change) {
      case RunFileChange.written:
        return null;
      case RunFileChange.edited:
        final filediff = metadata['filediff'];
        final patch =
            (filediff is Map ? text(filediff['patch']) : null) ??
            text(metadata['diff']);
        if (patch != null) return KitDiffFile.fromPatch(file.path, patch);
        final before = state.input['oldString'];
        final after = state.input['newString'];
        if (before is! String && after is! String) return null;
        return KitDiffFile.fromTexts(
          file.path,
          before: before is String ? before : '',
          after: after is String ? after : '',
          status: KitDiffFileStatus.modified,
        );
      case RunFileChange.patched:
        final files = metadata['files'];
        if (files is List) {
          for (final entry in files.whereType<Map>()) {
            final names = [
              entry['relativePath'],
              entry['path'],
              entry['filePath'],
              entry['movePath'],
              entry['file'],
            ];
            if (!names.contains(file.path)) continue;
            final patch = text(entry['patch']);
            return patch == null
                ? null
                : KitDiffFile.fromPatch(file.path, patch);
          }
          return null;
        }
        final patch = text(metadata['diff']);
        return patch == null ? null : KitDiffFile.fromPatch(file.path, patch);
    }
  }

  /// One command: the command itself as the title, then how it ended,
  /// state word first ("Failed · exit 1", "Passed · exit 0", "Exit not
  /// recorded"). A failed command's mark takes the failure tone.
  Widget _commandRow(
    BuildContext context,
    AppLocalizations l10n,
    RunCommand command,
  ) {
    final code = command.exitCode;
    final failed = command.failed || (code ?? 0) != 0;
    final state = switch (code) {
      final code? when failed => l10n.runResultsCommandFailedExit(code),
      final code? => l10n.runResultsCommandPassedExit(code),
      null when failed => l10n.runResultsCommandFailedNoExit,
      null => l10n.runResultsExitNotRecorded,
    };
    final text = command.command.trim();
    final title = text.isEmpty ? l10n.runResultsCommandEmpty : text;
    final glyph = failed ? AppIconography.error : AppIconography.terminal;
    final roles = ThemeRoles.of(context);
    return KitRow(
      key: Key('run-result-command-${command.partID ?? command.command}'),
      leading: KitRow.icon(
        context,
        glyph,
        color: failed
            ? KitTokens.toneColor(roles, AppStatusTone.failure)
            : null,
      ),
      title: title,
      titleMaxLines: 3,
      supporting: TextSpan(
        text: command.outputPruned
            ? '$state · ${l10n.runResultsOutputPruned}'
            : state,
      ),
      supportingMaxLines: 2,
      trailing: command.outputPruned ? null : const KitRowValue(''),
      onTap: command.outputPruned
          ? null
          : () => _openOutput(
              context,
              glyph,
              title,
              command.toolName,
              command.state,
            ),
    );
  }

  /// The underlying record, rendered by the same ToolCard the transcript
  /// uses and already open, in a sheet titled with what it is (the command,
  /// or the file's name) and as tall as that one record. Nothing is
  /// re-fetched or re-summarised.
  Future<void> _openOutput(
    BuildContext context,
    IconData icon,
    String title,
    String toolName,
    ToolState state,
  ) {
    const opened = 'run-result-output';
    return showKitSheet<void>(
      context,
      title: title,
      icon: icon,
      sheetKey: const Key('run-result-output-sheet'),
      body: (_) => ToolCard(
        toolName: toolName,
        state: state,
        expansionStore: {opened: true},
        expansionKey: opened,
      ),
    );
  }

  static String _when(BuildContext context, DateTime time) {
    final local = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final sameDay =
        time.year == now.year && time.month == now.month && time.day == now.day;
    final clock = local.formatTimeOfDay(TimeOfDay.fromDateTime(time));
    return sameDay ? clock : '${local.formatMediumDate(time)} $clock';
  }
}
