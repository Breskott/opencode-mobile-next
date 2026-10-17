import 'package:flutter/material.dart';

import '../kit_tokens.dart';

/// A tiny mock chat (a message, some lines, the box) used by the picker's
/// tiles and the full-screen preview, so a look is judged under real-looking
/// content. Solid surfaces only; the look shows between and behind them.
/// [scale] is 1 for the preview and smaller in a tile.
Widget liveMockChat(BuildContext context, {double scale = 1}) {
  final tokens = KitTokens.of(context);
  final roles = tokens.roles;
  final gap = tokens.space2 * scale;
  Widget bar(double w, double h, Color c) => Container(
    width: w * scale,
    height: h * scale,
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(h * scale / 2),
    ),
  );
  return Padding(
    padding: EdgeInsets.all(tokens.space3 * scale),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(
            padding: EdgeInsets.all(tokens.space2 * scale),
            decoration: BoxDecoration(
              color: roles.surface2,
              borderRadius: BorderRadius.circular(tokens.buttonRadius * scale),
            ),
            child: bar(70, 6, roles.text2),
          ),
        ),
        SizedBox(height: gap * 1.5),
        bar(90, 5, roles.text3),
        SizedBox(height: gap),
        bar(130, 6, roles.text2),
        SizedBox(height: gap),
        bar(110, 6, roles.text2),
        SizedBox(height: gap),
        bar(80, 6, roles.text2),
        const Spacer(),
        Container(
          height: tokens.space6 * scale,
          padding: EdgeInsets.symmetric(horizontal: tokens.space3 * scale),
          decoration: BoxDecoration(
            color: roles.surface2,
            borderRadius: BorderRadius.circular(tokens.composerRadius * scale),
          ),
          alignment: AlignmentDirectional.centerStart,
          child: bar(60, 5, roles.text3),
        ),
      ],
    ),
  );
}
