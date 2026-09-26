// KitMotionParts (docs/ux-system/kit-api/KitMotionParts.md, API freeze wave
// 0): the small motion primitives a screen may use, all on KitMotion timings
// and curves. Each one shows its final state on the first build, is instant
// under KitMotion.reduced, moves only paint and transforms (MOT-5), and
// never blurs, scales or fade-scales (VL §7, MOT-2).
//
// They replace the framework's Animated* widgets, transitions, Opacity,
// Transform and TweenAnimationBuilder OUTSIDE the kit; this file itself may
// use those primitives to build the parts, the way kit_reveal.dart already
// does. Arrivals (fade plus rise) are the existing KitEntrance
// (kit_reveal.dart) and are not redefined here.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app_iconography.dart';
import '../kit_motion.dart';
import '../kit_tokens.dart';

/// The two paces a part may move at (MOT-1).
enum KitPace {
  /// [KitMotion.quick] (150 ms): a control answering a touch.
  quick,

  /// [KitMotion.standard] (250 ms): a part appearing or changing.
  standard,
}

Duration _paceLength(KitPace pace) => switch (pace) {
  KitPace.quick => KitMotion.quick,
  KitPace.standard => KitMotion.standard,
};

/// Zero under reduced motion (MOT-7), so every implicit animation below
/// jumps to its target within the frame instead of easing to it.
Duration _durationOf(BuildContext context, KitPace pace) =>
    KitMotion.reduced(context) ? Duration.zero : _paceLength(pace);

/// Cross-fades between children: [AnimatedSwitcher]'s job, without scale or
/// size animation. The [child]'s key says when the content is new (falling
/// back to its widget type, so two different widget classes still cross-fade
/// without an explicit key). The old child ignores touches and is excluded
/// from semantics while it leaves.
class KitSwap extends StatefulWidget {
  const KitSwap({
    super.key,
    required this.child,
    this.pace = KitPace.quick,
    this.alignment = AlignmentDirectional.center,
  });

  final Widget child;
  final KitPace pace;
  final AlignmentDirectional alignment;

  @override
  State<KitSwap> createState() => _KitSwapState();
}

class _KitSwapState extends State<KitSwap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _paceLength(widget.pace),
    value: 1,
  )..addStatusListener(_onStatus);
  late final Animation<double> _incoming = CurvedAnimation(
    parent: _controller,
    curve: KitMotion.enter,
  );
  late final Animation<double> _outgoingOpacity = Tween<double>(
    begin: 1,
    end: 0,
  ).chain(CurveTween(curve: KitMotion.exit)).animate(_controller);
  Widget? _outgoing;

  // Set in initState, not as a lazy `late` initializer: nothing in build()
  // reads _key, so a lazy initializer would stay unevaluated until the
  // first didUpdateWidget — where `widget` already IS the new child, making
  // the very first change compare a key against itself.
  late Key _key;

  static Key _keyOf(Widget child) => child.key ?? ValueKey(child.runtimeType);

  @override
  void initState() {
    super.initState();
    _key = _keyOf(widget.child);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(covariant KitSwap old) {
    super.didUpdateWidget(old);
    final newKey = _keyOf(widget.child);
    if (newKey != _key) {
      _key = newKey;
      _controller.duration = _paceLength(widget.pace);
      if (KitMotion.reduced(context)) {
        _outgoing = null;
        _controller.value = 1;
      } else {
        _outgoing = old.child;
        _controller.forward(from: 0);
      }
    } else if (widget.pace != old.pace) {
      _controller.duration = _paceLength(widget.pace);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = _outgoing;
    return Stack(
      alignment: widget.alignment,
      children: [
        if (outgoing != null)
          IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(opacity: _outgoingOpacity, child: outgoing),
            ),
          ),
        FadeTransition(opacity: _incoming, child: widget.child),
      ],
    );
  }
}

/// Rotates its child. The rotation is paint only and does not change layout.
class KitSpin extends StatelessWidget {
  /// Animated to [turns] (0.5 = half a turn) on [pace].
  const KitSpin({
    super.key,
    required double turns,
    required Widget child,
    this.pace = KitPace.quick,
  }) : _kind = _KitSpinKind.turns,
       _turns = turns,
       _child = child,
       _quarterTurns = null,
       _expanded = null;

  /// A fixed rotation that also rotates the layout ([RotatedBox]'s job), for
  /// example a glyph drawn sideways. Not animated.
  const KitSpin.fixed({
    super.key,
    required int quarterTurns,
    required Widget child,
  }) : _kind = _KitSpinKind.fixed,
       _quarterTurns = quarterTurns,
       _child = child,
       _turns = null,
       _expanded = null,
       pace = KitPace.quick;

  /// The one disclosure chevron of the kit (README.md decision D10):
  /// [AppIconography.chevronDown] at 20 dp in `text2`, turning on
  /// [KitMotion.standard] with [KitMotion.emphasized], pointing down when
  /// closed and up when [expanded]. It uses the vertical glyph so it never
  /// depends on the reading direction.
  const KitSpin.chevron({super.key, required bool expanded})
    : _kind = _KitSpinKind.chevron,
      _expanded = expanded,
      _child = null,
      _turns = null,
      _quarterTurns = null,
      pace = KitPace.standard;

  final _KitSpinKind _kind;
  final double? _turns;
  final int? _quarterTurns;
  final bool? _expanded;
  final Widget? _child;
  final KitPace pace;

  @override
  Widget build(BuildContext context) {
    switch (_kind) {
      case _KitSpinKind.fixed:
        return RotatedBox(quarterTurns: _quarterTurns!, child: _child!);
      case _KitSpinKind.chevron:
        final tokens = KitTokens.of(context);
        return AnimatedRotation(
          turns: _expanded! ? .5 : 0,
          duration: _durationOf(context, KitPace.standard),
          curve: KitMotion.emphasized,
          child: Icon(
            AppIconography.chevronDown,
            size: tokens.smallIconSize,
            color: tokens.roles.text2,
          ),
        );
      case _KitSpinKind.turns:
        return AnimatedRotation(
          turns: _turns!,
          duration: _durationOf(context, pace),
          curve: KitMotion.enter,
          child: _child!,
        );
    }
  }
}

enum _KitSpinKind { turns, fixed, chevron }

/// A box whose paint changes between surface steps: the fill level and the
/// hairline edge animate on [pace]. A change of size snaps; layout animation
/// is [KitReveal]'s alone (MOT-5). [level] null is no fill.
class KitAnimatedBox extends StatelessWidget {
  const KitAnimatedBox({
    super.key,
    required this.child,
    this.level,
    this.shape = KitShape.panel,
    this.outlined = false,
    this.pace = KitPace.quick,
  });

  final Widget child;
  final KitSurfaceLevel? level;
  final KitShape shape;

  /// Exactly one physical pixel (LOOK-21).
  final bool outlined;
  final KitPace pace;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final base = tokens.shapeOf(shape);
    final shapeBorder = outlined
        ? _withHairline(context, base, tokens.roles.hairline)
        : base;
    final fillLevel = level;
    return AnimatedContainer(
      duration: _durationOf(context, pace),
      curve: KitMotion.enter,
      decoration: ShapeDecoration(
        color: fillLevel == null ? null : tokens.fillOf(fillLevel),
        shape: shapeBorder,
      ),
      child: child,
    );
  }
}

/// [shape] with a hairline [BorderSide] in [color], so an outlined box's
/// border can animate in and out with the rest of its paint
/// (`ShapeBorder.lerp` interpolates the side like any other property).
ShapeBorder _withHairline(
  BuildContext context,
  ShapeBorder shape,
  Color color,
) {
  final side = BorderSide(
    color: color,
    width: KitTokens.hairlineWidth(context),
  );
  return switch (shape) {
    RoundedRectangleBorder(:final borderRadius) => RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: side,
    ),
    StadiumBorder() => StadiumBorder(side: side),
    CircleBorder() => CircleBorder(side: side),
    _ => shape,
  };
}

/// How far [KitDim] dims.
enum KitDimLevel {
  /// [KitTokens.staleAlpha]: last-known content while a refresh is pending.
  stale,

  /// [KitTokens.disabledAlpha]: an image or drawing for an unavailable
  /// choice.
  disabled,
}

/// Dims an image, a drawing or a mark ([Opacity]'s job) for non-text content
/// only. A debug assert fails when [child]'s render subtree contains a
/// paragraph (LOOK-14: text at rest is opaque; dim text with a
/// `KitTextTone` instead).
class KitDim extends StatelessWidget {
  const KitDim({
    super.key,
    required this.child,
    this.dimmed = true,
    this.level = KitDimLevel.disabled,
    this.pace = KitPace.quick,
  });

  final Widget child;
  final bool dimmed;
  final KitDimLevel level;
  final KitPace pace;

  double _alpha() => switch (level) {
    KitDimLevel.stale => KitTokens.staleAlpha,
    KitDimLevel.disabled => KitTokens.disabledAlpha,
  };

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: dimmed ? _alpha() : 1,
    duration: _durationOf(context, pace),
    curve: KitMotion.enter,
    child: _KitDimGuard(child: child),
  );
}

/// Fails a debug assert when its child's render subtree paints a paragraph
/// (LOOK-14): [KitDim] dims images, drawings and marks, never text.
class _KitDimGuard extends SingleChildRenderObjectWidget {
  const _KitDimGuard({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderKitDimGuard();
}

class _RenderKitDimGuard extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    assert(
      _paintsNoParagraph(this),
      'KitDim dims images, drawings and marks, never text (LOOK-14): dim '
      'text with a KitTextTone instead of wrapping it in KitDim.',
    );
    super.paint(context, offset);
  }
}

bool _paintsNoParagraph(RenderObject node) {
  var clean = true;
  void visit(RenderObject child) {
    if (child is RenderParagraph) {
      clean = false;
      return;
    }
    child.visitChildren(visit);
  }

  node.visitChildren(visit);
  return clean;
}

/// Eases a number toward [value] ([TweenAnimationBuilder]'s job). The first
/// build shows [value] at once, and later changes animate on [pace]. [jump]
/// shows the new value at once (a new job, a reset). [builder] should
/// change paint or a transform: a bar's fill, a count's position. It must
/// not change layout.
class KitAnimatedValue extends StatefulWidget {
  const KitAnimatedValue({
    super.key,
    required this.value,
    required this.builder,
    this.pace = KitPace.standard,
    this.jump = false,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final KitPace pace;
  final bool jump;

  @override
  State<KitAnimatedValue> createState() => _KitAnimatedValueState();
}

class _KitAnimatedValueState extends State<KitAnimatedValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _paceLength(widget.pace),
    value: 1,
  );
  late final Animation<double> _eased = CurvedAnimation(
    parent: _controller,
    curve: KitMotion.enter,
  );
  late Tween<double> _tween = Tween(begin: widget.value, end: widget.value);

  @override
  void didUpdateWidget(covariant KitAnimatedValue old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      if (widget.jump || KitMotion.reduced(context)) {
        _tween = Tween(begin: widget.value, end: widget.value);
        _controller.value = 1;
      } else {
        _tween = Tween(
          begin: _tween.transform(_eased.value),
          end: widget.value,
        );
        _controller.duration = _paceLength(widget.pace);
        _controller.forward(from: 0);
      }
    } else if (widget.pace != old.pace) {
      _controller.duration = _paceLength(widget.pace);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) =>
        widget.builder(context, _tween.transform(_eased.value)),
  );
}
