import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../kit/kit_term.dart';

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

/// Retired by kit-KitTerm: use [KitTerm]. Kept as a forwarding wrapper
/// (R11, R12) so `worktrees_screen.dart`, the chat chain and the library
/// screens keep compiling until their own units move to [KitTerm]
/// directly; slice-P3.1 deletes this file and moves [Glossary] to its
/// caller. [style] and [iconSize] are accepted and ignored: the term now
/// takes the look of its [KitTerm] role.
@Deprecated('Retired by kit-KitTerm: use KitTerm')
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

  /// Forwards to [showKitTerm]: no [InfoLabel] needs to be on screen.
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
    return showKitTerm(
      context,
      term: localized.term,
      explanation: localized.explanation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final localized = Glossary.localized(
      l10n,
      term: term,
      explanation: explanation,
    );
    return KitTerm(localized.term, explanation: localized.explanation);
  }
}
