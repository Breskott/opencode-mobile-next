import 'package:flutter/material.dart';

import 'kit_tokens.dart';

/// The filter chips under a screen's title (Chats home: "All projects",
/// "Needs you", "Running"). The chips are [KitChip]s the caller builds; this
/// part only lays them on one line, on the screen gutter. The line scrolls
/// sideways when the chips do not fit (large text, a long name, Arabic): it
/// never wraps onto a second line, and no chip is cut or hidden.
///
/// States: none - a layout line; each chip carries its own selected look.
class KitFilterChips extends StatelessWidget {
  const KitFilterChips({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: tokens.space2),
            chips[i],
          ],
        ],
      ),
    );
  }
}
