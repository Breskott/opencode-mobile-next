// A step's node on a timeline's rail (docs/ux-system/kit-api/KitStepTimeline.md
// "Nodes"). Part of kit_step_timeline.dart so it reads the rail's measures.
// Every node is the same size (the glyph's 20 dp, grown with text) and
// centred on the one rail; the running step's node is the kit's small
// spinner, nothing moves around a tile.
part of 'kit_step_timeline.dart';

/// Draws a node in the free column at the start of its slot, beside the
/// first line of [child]. The node sits outside [child]'s own box (it is
/// decoration: no semantics, no taps), so [child] keeps its full width.
class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.child,
    required this.lineHeight,
    required this.top,
    required this.scope,
    this.icon,
    this.mark,
    this.dim = false,
    this.boxHeight,
  });

  final Widget child;

  /// The first line's height at 1.0 text scale.
  final double lineHeight;

  /// The first line's height as it is, when the host measured it.
  final double? boxHeight;
  final double top;
  final IconData? icon;
  final Widget? mark;

  /// A step not started yet: its glyph in the quietest text role.
  final bool dim;
  final _RailScope scope;

  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final rail = _Rail(context);
    final roles = rail.tokens.roles;
    final box = boxHeight ?? rail.line(lineHeight);
    final Widget node;
    if (icon != null) {
      node = _StepTile(
        icon: icon!,
        size: rail.glyph,
        glyph: dim ? roles.text3 : roles.text2,
      );
    } else if (mark != null) {
      node = mark!;
    } else {
      node = SizedBox.square(
        dimension: _dot,
        child: DecoratedBox(
          decoration: BoxDecoration(color: roles.text3, shape: BoxShape.circle),
        ),
      );
    }
    // Where this node's centre is, so the last slot's rail can end on it.
    scope.registry.centres[scope.index] = top + box / 2;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        PositionedDirectional(
          start: -rail.column,
          top: top,
          width: rail.glyph,
          height: box,
          child: ExcludeSemantics(child: Center(child: node)),
        ),
      ],
    );
  }
}

/// The step's glyph in a small tile: [size] square, `surface3`, the glyph at
/// 60 % of it.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.icon,
    required this.size,
    required this.glyph,
  });

  final IconData icon;
  final double size;
  final Color glyph;

  @override
  Widget build(BuildContext context) {
    final roles = KitTokens.of(context).roles;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: roles.surface3,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Center(
          child: Icon(icon, size: size * .6, color: glyph),
        ),
      ),
    );
  }
}
