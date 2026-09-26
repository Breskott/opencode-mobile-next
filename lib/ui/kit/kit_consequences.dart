/// The visual language's consequences panel (docs/design/visual-language-
/// 2026-09-26.md §5 "Sheets"): counted facts that go with an act, on one
/// `surface1` (or, in light, `ground`) panel with hairlines inset to the
/// words. A sheet body places it where the facts belong ("3 queued prompts
/// will be deleted"); `showKitConfirm` draws its own `consequences` with
/// the private, pre-v2 `_KitConsequences` until kit-KitDetailsFold moves it
/// here.
///
/// States: none — a static list of the facts the caller gives it.
library;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// What a fact in a [KitConsequences] panel says about the thing (§5
/// Sheets).
enum KitConsequenceMark {
  /// A fact: `text2` info glyph.
  info,

  /// Goes with the act (loses data or ends work): danger glyph (LOOK-5).
  lost,

  /// Survives the act (DATA-8): `text2` check.
  kept,
}

/// One counted fact a [KitConsequences] panel shows: "3 queued prompts will
/// be deleted".
@immutable
class KitConsequence {
  const KitConsequence(
    this.text, {
    this.mark = KitConsequenceMark.info,
    this.icon,
    this.key,
  });

  final String text;
  final KitConsequenceMark mark;

  /// Overrides [mark]'s glyph ("the test run" → terminal).
  final IconData? icon;
  final Key? key;
}

/// The visual language's consequences panel (§5 Sheets): a `surface1` (or,
/// in light, `ground`) panel of one-line facts, with hairlines inset to the
/// words. A sheet body places it where the facts belong; `showKitConfirm`
/// draws its own `consequences` with the private, pre-v2 `_KitConsequences`
/// until kit-KitDetailsFold moves it here.
///
/// States: none — a static list of the facts the caller gives it.
class KitConsequences extends StatelessWidget {
  const KitConsequences({super.key, required this.items})
    : assert(items.length > 0);

  final List<KitConsequence> items;

  static IconData _iconFor(KitConsequenceMark mark) => switch (mark) {
    KitConsequenceMark.info => AppIconography.info,
    KitConsequenceMark.lost => AppIconography.warning,
    KitConsequenceMark.kept => AppIconography.check,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    return DecoratedBox(
      key: const ValueKey('kit-consequences'),
      decoration: BoxDecoration(
        color: tokens.insetSurface,
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0,
                thickness: KitTokens.hairlineWidth(context),
                indent: tokens.space4 + tokens.smallIconSize + tokens.space3,
                color: roles.hairline,
              ),
            Padding(
              key: items[i].key,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space4,
                vertical: tokens.space3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      items[i].icon ?? _iconFor(items[i].mark),
                      size: tokens.smallIconSize,
                      color: items[i].mark == KitConsequenceMark.lost
                          ? roles.danger
                          : roles.text2,
                    ),
                  ),
                  SizedBox(width: tokens.space3),
                  Expanded(
                    child: KitText(items[i].text, role: KitTextRole.rowTitle),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
