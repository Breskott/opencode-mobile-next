import 'package:flutter/material.dart';

import 'kit_buttons.dart';
import 'kit_tokens.dart';

/// A disabled action's reason (STATE-8, KitAction.md), start-aligned under
/// its button. Found in tests by its text first (TEST-5); [id]
/// disambiguates the key when the stack shows more than one. A private
/// twin of `KitActionBlock`'s own `_KitActionReason`: each file is its own
/// library, so the tiny widget is kept local rather than made public.
class _KitActionReason extends StatelessWidget {
  const _KitActionReason(this.text, {required this.id});

  final String text;
  final String id;

  @override
  Widget build(BuildContext context) => Text(
    text,
    key: ValueKey('kit-action-reason-$id'),
    style: KitTokens.of(context).note,
  );
}

/// A block of actions where every rare path gets its own line (design
/// standard §2): the primary, then the secondary, full width, then each
/// tertiary text button under the other, aligned to the start. Used where
/// the tertiary actions must never sit side by side (a server's Update and
/// its destructive Stop), so a thumb aimed at one cannot land on the other.
/// At most two tertiary actions, as in [KitActionBlock]. A disabled action's
/// [KitAction.disabledReason] shows as a muted line under its button
/// (STATE-8, kit-KitAction-v2); every gap is [KitTokens.space2] (8 dp), so a
/// destructive action's 48 dp target stays clear of every other (LAY-9).
class KitActionStack extends StatelessWidget {
  const KitActionStack({
    super.key,
    this.primary,
    this.secondary,
    this.tertiary = const [],
  }) : assert(tertiary.length <= 2);

  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final gap = SizedBox(height: tokens.space2);
    final children = <Widget>[];

    final reasonGap = SizedBox(height: tokens.space1);

    if (primary case final primary?) {
      children.add(KitButton.fromAction(primary, role: KitButtonRole.primary));
      if (primary.disabledReason case final reason?) {
        children.add(reasonGap);
        children.add(_KitActionReason(reason, id: 'primary'));
      }
    }
    if (secondary case final secondary?) {
      if (children.isNotEmpty) children.add(gap);
      children.add(
        KitButton.fromAction(secondary, role: KitButtonRole.secondary),
      );
      if (secondary.disabledReason case final reason?) {
        children.add(reasonGap);
        children.add(_KitActionReason(reason, id: 'secondary'));
      }
    }
    for (final action in tertiary) {
      if (children.isNotEmpty) children.add(gap);
      children.add(
        KitInset(
          child: KitButton.fromAction(action, role: KitButtonRole.tertiary),
        ),
      );
      if (action.disabledReason case final reason?) {
        children.add(reasonGap);
        children.add(_KitActionReason(reason, id: 'tertiary-${action.label}'));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
