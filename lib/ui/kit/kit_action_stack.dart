import 'package:flutter/material.dart';

import 'kit_buttons.dart';

/// A block of actions where every rare path gets its own line (design
/// standard §2): the primary, then the secondary, full width, then each
/// tertiary text button under the other, aligned to the start. Used where
/// the tertiary actions must never sit side by side (a server's Update and
/// its destructive Stop), so a thumb aimed at one cannot land on the other.
/// At most two tertiary actions, as in [KitActionBlock].
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (primary case final primary?)
        KitButton.fromAction(primary, role: KitButtonRole.primary),
      if (primary != null && secondary != null) const SizedBox(height: 8),
      if (secondary case final secondary?)
        KitButton.fromAction(secondary, role: KitButtonRole.secondary),
      if (tertiary.isNotEmpty && (primary != null || secondary != null))
        const SizedBox(height: 4),
      for (final action in tertiary)
        KitInset(
          child: KitButton.fromAction(action, role: KitButtonRole.tertiary),
        ),
    ],
  );
}
