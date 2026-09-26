import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../domain/server_gateway.dart' show PendingQuestion, QuestionChoice;
import '../kit/kit_choice_list.dart';
import '../kit/kit_field.dart';

/// True when [question] is too big to answer inline above the composer and
/// the chat should show a compact card whose Answer button opens the full
/// sheet: more than two prompts, or any choice description past ~140
/// characters. Mirrors `formPrefersFullScreen` so the two request surfaces
/// grow the same way.
bool questionPrefersSheet(PendingQuestion question) =>
    question.prompts.length > 2 ||
    question.prompts.any(
      (prompt) =>
          prompt.choices.any((choice) => choice.description.length > 140),
    );

/// One selectable choice of a question prompt, rendered identically by the
/// Activity sheet and the inline chat card.
///
/// Retired by kit-KitChoiceList: use KitChoiceRow / KitField. A thin
/// forwarding wrapper that builds a [KitChoiceRow]; the kit never imports
/// domain types, so this file stays here (R12).
@Deprecated('Retired by kit-KitChoiceList: use KitChoiceRow / KitField')
class QuestionOptionRow extends StatelessWidget {
  const QuestionOptionRow({
    super.key,
    required this.choice,
    required this.selected,
    required this.multiple,
    required this.onTap,
    this.recommended = false,
    this.enabled = true,
  });

  final QuestionChoice choice;
  final bool selected;

  /// Checkbox affordance for multi-select prompts, radio for single-select.
  final bool multiple;
  final VoidCallback? onTap;
  final bool recommended;
  final bool enabled;

  @override
  Widget build(BuildContext context) => KitChoiceRow<String>(
    rowKey: ValueKey('question-option-${choice.label}'),
    choice: KitChoice<String>(
      value: choice.label,
      title: choice.label,
      supporting: choice.description.isEmpty ? null : choice.description,
      recommended: recommended,
    ),
    selected: selected,
    mark: multiple ? KitChoiceMark.check : KitChoiceMark.radio,
    onTap: enabled ? onTap : null,
  );
}

/// The free-text answer field shown when a prompt accepts a custom answer;
/// shared so the sheet and the card ask in the same words.
///
/// Retired by kit-KitChoiceList: use KitChoiceRow / KitField. Forwards to
/// `KitField(kind: multiline)`.
@Deprecated('Retired by kit-KitChoiceList: use KitChoiceRow / KitField')
class QuestionCustomAnswerField extends StatelessWidget {
  const QuestionCustomAnswerField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.maxLines = 3,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => KitField(
    label: lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7SharedYourAnswer,
    kind: KitFieldKind.multiline,
    controller: controller,
    enabled: enabled,
    disabledReason: enabled ? null : '',
    maxLines: maxLines,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
  );
}
