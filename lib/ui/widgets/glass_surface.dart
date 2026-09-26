import 'package:flutter/material.dart';

import '../kit/glass/kit_glass.dart';
import '../kit/kit_tokens.dart';

/// The bottom dock's glass: a [KitGlass] with the floating tab bar's 22 dp
/// corners (visual language §4).
///
/// The shell extends scrolling content beneath it. Liquid glass where the
/// phone runs the shader, the frosted blur where it cannot, solid when the
/// person turned glass off (Settings › Appearance) or under high contrast,
/// accessible navigation or remove animations. In-app Flutter glass, not
/// Android OS cross-window or Compose blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child});

  final Widget child;

  /// See [KitGlass.foregroundColor].
  static Color foregroundColor(ThemeData theme) =>
      KitGlass.foregroundColor(theme);

  /// See [KitGlass.reduceEffects].
  static bool reduceEffects(BuildContext context) =>
      KitGlass.reduceEffects(context);

  @override
  Widget build(BuildContext context) => KitGlass(
    borderRadius: BorderRadius.circular(KitTokens.of(context).navRadius),
    child: child,
  );
}
