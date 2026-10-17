// KitPhraseChips: one row of the person's own common short phrases above the
// message box ("Continue", "Run the tests"). A tap sends the phrase; a
// long-press (or the screen reader's long-press action) opens a small menu:
// Edit puts the phrase in the box without sending, Hide stops suggesting it.
//
// The host decides which phrases (the moment, what was learned) and what a
// tap does; this part only draws the row. At most a few chips, so the row is
// one line that scrolls sideways when the window is narrow or the text is
// large, starting at the reading edge in both directions. Each chip is a
// KitChip.action: a 48 dp target around a 32 dp pill, named "Send: <words>"
// for a screen reader.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_iconography.dart';
import '../kit_chip.dart';
import '../kit_menu.dart';
import '../kit_tokens.dart';

/// No phrases draws nothing.
///
/// States: empty.
class KitPhraseChips extends StatelessWidget {
  const KitPhraseChips({
    super.key,
    required this.phrases,
    required this.onChoose,
    required this.onEdit,
    required this.onHide,
  });

  /// The words of each chip, in order. Empty draws nothing.
  final List<String> phrases;

  /// A tap: the host sends these words (this part keeps no sending state;
  /// the host removes the row while a message is on its way).
  final ValueChanged<String> onChoose;

  /// Menu › Edit: put these words in the message box.
  final ValueChanged<String> onEdit;

  /// Menu › Hide: never suggest these words again.
  final ValueChanged<String> onHide;

  @override
  Widget build(BuildContext context) {
    if (phrases.isEmpty) return const SizedBox.shrink();
    final tokens = KitTokens.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Semantics(
      container: true,
      label: l10n.phraseChipsRowLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.gutter),
        child: Row(
          children: [
            for (var i = 0; i < phrases.length; i++) ...[
              if (i > 0) SizedBox(width: tokens.space2),
              Builder(
                builder: (chipContext) => KitChip.action(
                  key: ValueKey('phrase-chip-${phrases[i]}'),
                  label: phrases[i],
                  spoken: l10n.phraseChipsSend(phrases[i]),
                  onPressed: () => onChoose(phrases[i]),
                  onLongPress: () => _menu(chipContext, phrases[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext chipContext, String phrase) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(chipContext));
    return showKitMenu(
      chipContext,
      semanticsLabel: l10n.phraseChipsMenuLabel,
      items: [
        KitMenuItem(
          key: const ValueKey('phrase-chip-edit'),
          label: l10n.phraseChipsEdit,
          icon: AppIconography.edit,
          onSelected: () => onEdit(phrase),
        ),
        KitMenuItem(
          key: const ValueKey('phrase-chip-hide'),
          label: l10n.phraseChipsHide,
          icon: AppIconography.hidden,
          onSelected: () => onHide(phrase),
        ),
      ],
    );
  }
}
