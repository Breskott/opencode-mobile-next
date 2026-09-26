import 'package:flutter/material.dart';

/// The one icon-only button (docs/ux-system/kit-v2.md §1.10): a 48 dp
/// target, a label that is both its tooltip (hover on a PC, long-press on a
/// phone) and its semantic name, and the theme's icon colour. A disabled
/// button keeps its label so a screen reader still says what it would do.
class KitIconButton extends StatelessWidget {
  const KitIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 24,
  });

  final IconData icon;

  /// What pressing it does, in the person's words: "Remove header".
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    iconSize: size,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: Icon(icon, semanticLabel: label),
  );
}
