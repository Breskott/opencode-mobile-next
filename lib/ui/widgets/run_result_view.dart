import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/models.dart' show ToolState;
import '../../domain/run_result.dart';
import '../../domain/session_title_text.dart';
import '../../l10n/app_localizations.dart';
import '../agent_error_words.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_layout.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import 'tool_card.dart';

/// Pure presentation of one [RunResult], built from kit parts only
/// (STANDARDS KIT-1). Every line is either copied from a server record or an
/// explicit "unknown"; the only actions are opening the conversation and
/// opening a tool's own recorded output ("What it did", sized to that one
/// record and already open).
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

  static String shortID(String id) =>
      id.length <= 10 ? id : id.substring(id.length - 8);

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final title = displaySessionTitleText(sessionTitle);
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
            onRails(_identity(context, l10n, title)),
            if (!result.boundaryKnown) ...[
              SizedBox(height: tokens.space4),
              onRails(
                KitNotice(
                  key: const Key('run-result-partial'),
                  icon: AppIconography.history,
                  message: l10n.runResultsPartialHistory,
                  liveRegion: false,
                ),
              ),
            ],
            gap,
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
              source(l10n.runResultsChangedFilesSource),
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
              source(l10n.runResultsCommandsSource),
              if (result.prunedToolCount > 0)
                source(l10n.runResultsPrunedTools(result.prunedToolCount)),
              if (result.truncated) source(l10n.runResultsTruncated),
            ],
            gap,
            onRails(
              KitText(
                l10n.runResultsSourceNote,
                role: KitTextRole.caption,
                tone: KitTextTone.tertiary,
              ),
            ),
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

  /// The run's name and facts: the conversation's title, the cut run id,
  /// then two lines of what the server recorded (steps and who; when).
  Widget _identity(BuildContext context, AppLocalizations l10n, String title) {
    final tokens = KitTokens.of(context);
    final steps = result.boundaryKnown
        ? l10n.runResultsSteps(result.stepCount)
        : l10n.runResultsStepsAtLeast(result.stepCount);
    final who = [
      result.agent,
      result.model,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    final started = result.startedAt == null
        ? l10n.runResultsStartedUnknown
        : l10n.runResultsStarted(_when(context, result.startedAt!));
    final finished = result.finishedAt == null
        ? l10n.runResultsFinishedUnknown
        : l10n.runResultsFinished(_when(context, result.finishedAt!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          KitText(title, role: KitTextRole.headline),
          SizedBox(height: tokens.space1),
        ],
        KitText(
          l10n.runResultsRunLabel(shortID(result.runID)),
          key: const Key('run-result-id'),
          role: KitTextRole.label,
        ),
        SizedBox(height: tokens.space1),
        KitText(
          [steps, if (who.isNotEmpty) who].join(' · '),
          role: KitTextRole.secondary,
        ),
        KitText('$started · $finished', role: KitTextRole.secondary),
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
    final finish = outcome.finish?.trim();
    final reason = finish == null || finish.isEmpty
        ? l10n.runResultsFinishReasonMissing
        : l10n.runResultsFinishReason(finish);
    // What went wrong leads when there is an error; the provider's finish
    // reason then follows it.
    final error = switch (outcome.errorHeadline) {
      final headline? => agentErrorWords(
        headline,
        AppLocalizations.of(context),
      ).headline,
      null => null,
    };
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
          supporting: TextSpan(text: error ?? reason),
          supportingKey: error == null ? null : const Key('run-result-error'),
          supportingMaxLines: 3,
          below: Padding(
            padding: EdgeInsetsDirectional.only(top: tokens.space1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null) KitText(reason, role: KitTextRole.secondary),
                if (result.earlierStepErrors > 0)
                  KitText(
                    l10n.runResultsEarlierErrors(result.earlierStepErrors),
                    key: const Key('run-result-earlier-errors'),
                    role: KitTextRole.secondary,
                  ),
                KitText(
                  observedLive
                      ? l10n.runResultsObservedLive
                      : l10n.runResultsFromHistory,
                  key: Key(
                    observedLive ? 'run-result-observed' : 'run-result-history',
                  ),
                  role: KitTextRole.caption,
                  tone: KitTextTone.tertiary,
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
          : () => _openOutput(
              context,
              AppIconography.editNote,
              file.toolName,
              file.state,
            ),
    );
  }

  /// One command: how it ended first (exit code or an explicit unknown),
  /// the command itself as a technical value, then what else is known.
  Widget _commandRow(
    BuildContext context,
    AppLocalizations l10n,
    RunCommand command,
  ) {
    final exit = command.exitCode == null
        ? l10n.runResultsExitUnknown
        : l10n.runResultsExit(command.exitCode!);
    final failed = command.failed || (command.exitCode ?? 0) != 0;
    final notes = [
      if (command.failed) l10n.runResultsCommandFailed,
      if (command.looksLikeTest) l10n.runResultsLooksLikeTest,
      if (command.outputPruned) l10n.runResultsOutputPruned,
    ];
    final glyph = failed ? AppIconography.error : AppIconography.terminal;
    return KitRow(
      key: Key('run-result-command-${command.partID ?? command.command}'),
      leading: KitRow.icon(context, glyph),
      title: exit,
      supporting: notes.isEmpty ? null : TextSpan(text: notes.join(' · ')),
      supportingMaxLines: 2,
      below: command.command.isEmpty
          ? KitText(l10n.runResultsCommandEmpty, role: KitTextRole.secondary)
          : KitText.mono(command.command, maxLines: 3),
      trailing: command.outputPruned ? null : const KitRowValue(''),
      onTap: command.outputPruned
          ? null
          : () => _openOutput(context, glyph, command.toolName, command.state),
    );
  }

  /// "What it did": the underlying record, rendered by the same ToolCard the
  /// transcript uses and already open, in a sheet as tall as that one
  /// record. Nothing is re-fetched or re-summarised.
  Future<void> _openOutput(
    BuildContext context,
    IconData icon,
    String toolName,
    ToolState state,
  ) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    const opened = 'run-result-output';
    return showKitSheet<void>(
      context,
      title: l10n.runResultViewOutputTitle,
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
