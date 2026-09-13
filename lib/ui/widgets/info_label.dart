import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Plain-language explanations for the handful of terms a first-time user
/// meets in the first ten minutes. Screens attach these to the word itself
/// via [InfoLabel] instead of assuming the reader already knows.
abstract final class Glossary {
  static const mcp = (
    term: 'MCP',
    explanation:
        'Model Context Protocol. Small add-on servers that give the agent '
        'extra tools, like a browser, a database, or a design tool. You '
        'connect them once and every session can use them.',
  );
  static const worktree = (
    term: 'Worktree',
    explanation:
        'A separate checkout of the same repository. Use one when you want '
        'the agent to try something on its own branch without touching the '
        'code you are working in.',
  );
  static const provider = (
    term: 'Provider',
    explanation:
        'The company that hosts a model, such as Anthropic, OpenAI or a '
        'local runtime. Each one needs its own API key or login.',
  );
  static const context = (
    term: 'Context',
    explanation:
        'Everything the model can see right now: your messages, files it '
        'read, and tool results. It has a size limit. When it fills up, '
        'older parts are summarised so the session can continue.',
  );
  static const agent = (
    term: 'Agent',
    explanation:
        'A named set of instructions and permissions the model works under. '
        'The default one can read and edit code. Others might only plan, '
        'or only review.',
  );
  static const reasoning = (
    term: 'Reasoning',
    explanation:
        'The model’s working notes before it answers. Useful for seeing why '
        'it made a choice. Hidden by default to keep the conversation short.',
  );
  static const permission = (
    term: 'Permission',
    explanation:
        'Before the agent runs a command or edits a file outside what it is '
        'already allowed, it asks you. Allow once, or always for that '
        'pattern.',
  );
  static const variant = (
    term: 'Variant',
    explanation:
        'A speed-versus-depth setting for the model, such as how long it '
        'may think before answering.',
  );

  /// Resolve only known app-authored glossary entries; arbitrary caller prose
  /// and server content stay untouched. The full pair is the stable identity.
  static ({String term, String explanation}) localized(
    AppLocalizations l10n, {
    required String term,
    required String explanation,
  }) => switch ((term: term, explanation: explanation)) {
    mcp => (
      term: l10n.libraryMcpTitle,
      explanation: l10n.e7GlossaryMcpExplanation,
    ),
    worktree => (
      term: l10n.e7GlossaryWorktreeTerm,
      explanation: l10n.e7GlossaryWorktreeExplanation,
    ),
    provider => (
      term: l10n.usageProviderFilter,
      explanation: l10n.e7GlossaryProviderExplanation,
    ),
    context => (
      term: l10n.e7GlossaryContextTerm,
      explanation: l10n.e7GlossaryContextExplanation,
    ),
    agent => (
      term: l10n.e7GlossaryAgentTerm,
      explanation: l10n.e7GlossaryAgentExplanation,
    ),
    reasoning => (
      term: l10n.transcriptFindReasoning,
      explanation: l10n.e7GlossaryReasoningExplanation,
    ),
    permission => (
      term: l10n.e7GlossaryPermissionTerm,
      explanation: l10n.e7GlossaryPermissionExplanation,
    ),
    variant => (
      term: l10n.e7GlossaryVariantTerm,
      explanation: l10n.e7GlossaryVariantExplanation,
    ),
    _ => (term: term, explanation: explanation),
  };
}

/// A term with an inline "what is this?" affordance. Renders the word in the
/// surrounding text style followed by a small info glyph; tapping either opens
/// a short explanation sheet. Keep the explanation to two sentences.
class InfoLabel extends StatelessWidget {
  const InfoLabel(
    this.term, {
    super.key,
    required this.explanation,
    this.style,
    this.iconSize = 16,
  });

  /// Convenience for the shared [Glossary] entries.
  InfoLabel.glossary(
    ({String term, String explanation}) entry, {
    Key? key,
    TextStyle? style,
    double iconSize = 16,
  }) : this(
         entry.term,
         key: key,
         explanation: entry.explanation,
         style: style,
         iconSize: iconSize,
       );

  final String term;
  final String explanation;
  final TextStyle? style;
  final double iconSize;

  static Future<void> show(
    BuildContext context, {
    required String term,
    required String explanation,
  }) {
    final localized = Glossary.localized(
      lookupAppLocalizations(Localizations.localeOf(context)),
      term: term,
      explanation: explanation,
    );
    term = localized.term;
    explanation = localized.explanation;
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term, style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(
                  explanation,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7GlossaryGotIt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final localized = Glossary.localized(
      l10n,
      term: term,
      explanation: explanation,
    );
    final shownTerm = localized.term;
    final textStyle = style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      button: true,
      label: l10n.e7GlossaryExplain(shownTerm),
      excludeSemantics: true,
      onTap: () => show(context, term: term, explanation: explanation),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => show(context, term: term, explanation: explanation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flexible, not bare: a long localized term at 2.5x text
              // wraps inside the label instead of pushing the icon out of
              // its row.
              Flexible(child: Text(shownTerm, style: textStyle)),
              const SizedBox(width: 3),
              Icon(
                AppIconography.info,
                size: iconSize,
                color: AppTheme.mutedOf(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
