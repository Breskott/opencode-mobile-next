part of 'kit_glass.dart';

/// How far the joined pieces melt into each other, logical pixels (the
/// smooth union's reach: a neck forms once the gap is under half of it).
const double _joinBlend = 16;

/// The frost of the joined glass, logical pixels (the shader's tap radius;
/// light, so the bent edge stays sharp).
const double _pairFrost = 4;

/// [KitGlass.pair]: two pieces of glass in one row, drawn as one surface.
class _KitGlassPair extends StatefulWidget {
  const _KitGlassPair({
    required this.look,
    required this.program,
    required this.still,
    required this.joined,
    required this.radius,
    required this.shadow,
    required this.dim,
    required this.respond,
    required this.leading,
    required this.trailing,
  });

  final KitGlassLook look;
  final ui.FragmentProgram? program;

  /// Reduced motion or solid glass: every state is instant.
  final bool still;
  final bool joined;
  final BorderRadius? radius;
  final bool shadow;
  final bool dim;
  final bool respond;
  final Widget leading;
  final Widget trailing;

  @override
  State<_KitGlassPair> createState() => _KitGlassPairState();
}

class _KitGlassPairState extends State<_KitGlassPair>
    with TickerProviderStateMixin {
  late final AnimationController _join = AnimationController.unbounded(
    vsync: this,
    value: widget.joined ? 1 : 0,
  );
  late final AnimationController _pressLeading = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _pressTrailing = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void didUpdateWidget(_KitGlassPair old) {
    super.didUpdateWidget(old);
    if (widget.still) {
      _join.value = widget.joined ? 1 : 0;
      _pressLeading.value = 0;
      _pressTrailing.value = 0;
    } else if (old.joined != widget.joined) {
      _springTo(_join, widget.joined ? 1 : 0, KitMotion.glassJoin);
    }
  }

  @override
  void dispose() {
    _join.dispose();
    _pressLeading.dispose();
    _pressTrailing.dispose();
    super.dispose();
  }

  void _springTo(
    AnimationController controller,
    double target,
    SpringDescription spring,
  ) {
    // A finger lifted after the pair left the screen still reaches its
    // listener: nothing to spring then.
    if (!mounted) return;
    controller
        .animateWith(
          SpringSimulation(
            spring,
            controller.value,
            target,
            controller.velocity,
          ),
        )
        .then((_) {
          if (mounted) controller.value = target;
        });
  }

  Widget _piece(Widget child, AnimationController press) {
    if (!widget.respond || widget.still) return child;
    void release(PointerEvent _) => _springTo(press, 0, KitMotion.glassPress);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _springTo(press, 1, KitMotion.glassPress),
      onPointerUp: release,
      onPointerCancel: release,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paint = _GlassPaint.of(
      context,
      widget.look,
      widget.dim,
      widget.shadow,
    );
    return _GlassPairLayout(
      join: _join,
      pressLeading: _pressLeading,
      pressTrailing: _pressTrailing,
      program: widget.look == KitGlassLook.liquid ? widget.program : null,
      paint: paint,
      radius: widget.radius ?? BorderRadius.circular(paint.tokens.navRadius),
      gap: paint.tokens.space2,
      textDirection: Directionality.of(context),
      backdropKey: BackdropGroup.of(context)?.backdropKey,
      children: [
        _piece(widget.leading, _pressLeading),
        _piece(widget.trailing, _pressTrailing),
      ],
    );
  }
}

class _GlassPairLayout extends MultiChildRenderObjectWidget {
  const _GlassPairLayout({
    required this.join,
    required this.pressLeading,
    required this.pressTrailing,
    required this.program,
    required this.paint,
    required this.radius,
    required this.gap,
    required this.textDirection,
    required this.backdropKey,
    required super.children,
  });

  final Animation<double> join;
  final Animation<double> pressLeading;
  final Animation<double> pressTrailing;

  /// The shader, for liquid glass; null draws frosted or solid ([paint]).
  final ui.FragmentProgram? program;
  final _GlassPaint paint;
  final BorderRadius radius;
  final double gap;
  final TextDirection textDirection;
  final BackdropKey? backdropKey;

  @override
  _RenderGlassPair createRenderObject(BuildContext context) => _RenderGlassPair(
    join: join,
    pressLeading: pressLeading,
    pressTrailing: pressTrailing,
    program: program,
    paint: paint,
    radius: radius,
    gap: gap,
    textDirection: textDirection,
    backdropKey: backdropKey,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderGlassPair render) {
    render
      ..join = join
      ..pressLeading = pressLeading
      ..pressTrailing = pressTrailing
      ..program = program
      ..glassPaint = paint
      ..radius = radius
      ..gap = gap
      ..textDirection = textDirection
      ..backdropKey = backdropKey;
  }
}

class _PairParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGlassPair extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PairParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PairParentData>,
        GlassBackdropTracking {
  _RenderGlassPair({
    required Animation<double> join,
    required Animation<double> pressLeading,
    required Animation<double> pressTrailing,
    required ui.FragmentProgram? program,
    required _GlassPaint paint,
    required BorderRadius radius,
    required double gap,
    required TextDirection textDirection,
    required BackdropKey? backdropKey,
  }) : _join = join,
       _pressLeading = pressLeading,
       _pressTrailing = pressTrailing,
       _program = program,
       _shaders = program == null ? null : GlassShaders(program),
       _paint = paint,
       _radius = radius,
       _gap = gap,
       _textDirection = textDirection,
       _backdropKey = backdropKey;

  Animation<double> _join;
  set join(Animation<double> value) {
    if (identical(value, _join)) return;
    if (attached) _join.removeListener(_moved);
    _join = value;
    if (attached) _join.addListener(_moved);
    _moved();
  }

  /// The trailing piece moved: repaint, and tell a screen reader where it
  /// is now.
  void _moved() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Animation<double> _pressLeading;
  set pressLeading(Animation<double> value) =>
      _swap(_pressLeading, value, (v) => _pressLeading = v);
  Animation<double> _pressTrailing;
  set pressTrailing(Animation<double> value) =>
      _swap(_pressTrailing, value, (v) => _pressTrailing = v);

  void _swap(
    Animation<double> old,
    Animation<double> value,
    ValueChanged<Animation<double>> assign,
  ) {
    if (identical(old, value)) return;
    if (attached) old.removeListener(markNeedsPaint);
    assign(value);
    if (attached) value.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  ui.FragmentProgram? _program;
  GlassShaders? _shaders;
  set program(ui.FragmentProgram? value) {
    if (identical(value, _program)) return;
    _program = value;
    _shaders?.dispose();
    _shaders = value == null ? null : GlassShaders(value);
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  _GlassPaint _paint;
  set glassPaint(_GlassPaint value) {
    if (value == _paint) return;
    final composited = _composited;
    _paint = value;
    if (_composited != composited) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  BorderRadius _radius;
  set radius(BorderRadius value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  BackdropKey? _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  @override
  double get backdropPixelRatio => _paint.dpr;

  bool get _composited => _paint.look != KitGlassLook.solid;

  @override
  bool get alwaysNeedsCompositing => _composited;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PairParentData) {
      child.parentData = _PairParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _join.addListener(_moved);
    _pressLeading.addListener(markNeedsPaint);
    _pressTrailing.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _join.removeListener(_moved);
    _pressLeading.removeListener(markNeedsPaint);
    _pressTrailing.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _shaders?.dispose();
    _clipPath.layer = null;
    _clipRect.layer = null;
    _backdrop.layer = null;
    super.dispose();
  }

  RenderBox get _leading => firstChild!;
  RenderBox get _trailing => lastChild!;

  // ── Layout ──

  Size _sizes(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layout,
  ) {
    final loose = constraints.loosen();
    final trailing = layout(_trailing, loose);
    final leading = layout(
      _leading,
      loose.copyWith(
        maxWidth: math.max(0.0, loose.maxWidth - trailing.width - _gap),
      ),
    );
    final natural = leading.width + _gap + trailing.width;
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : natural,
        math.max(leading.height, trailing.height),
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _sizes(constraints, (child, c) => child.getDryLayout(c));

  @override
  void performLayout() {
    size = _sizes(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    _place();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _leading.getMinIntrinsicWidth(height) +
      _gap +
      _trailing.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _leading.getMaxIntrinsicWidth(height) +
      _gap +
      _trailing.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    _leading.getMinIntrinsicHeight(width),
    _trailing.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    _leading.getMaxIntrinsicHeight(width),
    _trailing.getMaxIntrinsicHeight(width),
  );

  /// The shrink of the trailing piece once joined, each side: it becomes
  /// the smaller drop.
  double get _shrink => GlassGeometry.swellMax / 2;

  double get _t => _join.value;

  /// Where the pieces are now: the leading one at the start, the trailing
  /// one moving from the end to just after the leading one.
  void _place() {
    final leading = _leading.size;
    final trailing = _trailing.size;
    final rtl = _textDirection == TextDirection.rtl;
    double top(Size child) => (size.height - child.height) / 2;
    final leadingX = rtl ? size.width - leading.width : 0.0;
    final restX = rtl ? 0.0 : size.width - trailing.width;
    // Joined, the smaller drop's edge touches the leading piece.
    final joinedX = rtl
        ? size.width - leading.width - trailing.width + _shrink
        : leading.width - _shrink;
    final t = _t;
    (_leading.parentData! as _PairParentData).offset = Offset(
      leadingX,
      top(leading),
    );
    (_trailing.parentData! as _PairParentData).offset = Offset(
      restX + (joinedX - restX) * t,
      top(trailing),
    );
  }

  Rect _box(RenderBox child) =>
      (child.parentData! as _PairParentData).offset & child.size;

  /// The drawn rounded rectangles, this box's coordinates.
  (RRect, RRect) _shapes() {
    final t = _t.clamp(0.0, 1.0);
    final leading = GlassGeometry.swell(_box(_leading), _pressLeading.value);
    final trailing = GlassGeometry.swell(
      _box(_trailing).deflate(_shrink * t),
      _pressTrailing.value,
    );
    return (
      GlassGeometry.rrect(_radius, leading),
      GlassGeometry.rrect(_radius, trailing),
    );
  }

  double get _blend => _joinBlend * _t.clamp(0.0, 1.0);

  // ── Paint ──

  final LayerHandle<ClipPathLayer> _clipPath = LayerHandle();
  final LayerHandle<ClipRectLayer> _clipRect = LayerHandle();
  final LayerHandle<BackdropFilterLayer> _backdrop = LayerHandle();

  @override
  void paint(PaintingContext context, Offset offset) {
    _place();
    final (a, b) = _shapes();
    final outline = _outline(a, b, _blend);
    final shaders = _shaders;
    final paint = _paint;
    if (paint.look != KitGlassLook.solid) {
      paint.paintShadows(context.canvas, outline.shift(offset));
    }
    if (paint.look == KitGlassLook.solid) {
      _clipPath.layer = null;
      _clipRect.layer = null;
      _backdrop.layer = null;
      final canvas = context.canvas;
      final shape = outline.shift(offset);
      canvas.drawPath(shape, Paint()..color = paint.solidFill);
      _strokeInside(
        canvas,
        shape,
        Paint()..color = paint.hairline,
        paint.hairlineWidth,
      );
    } else if (shaders != null) {
      // Liquid: the shader draws the joined edge itself, inside a plain
      // rectangle around both pieces.
      _clipPath.layer = null;
      final bounds = a.outerRect.expandToInclude(b.outerRect).inflate(1);
      _clipRect.layer = context.pushClipRect(
        needsCompositing,
        offset,
        bounds,
        (context, offset) =>
            _pushBackdrop(context, offset, _lens(a, b, shaders), (_) {}),
        oldLayer: _clipRect.layer,
      );
    } else {
      // Frosted: the outline clips a blur; the fill and rim follow it.
      _clipRect.layer = null;
      _clipPath.layer = context.pushClipPath(
        needsCompositing,
        offset,
        outline.getBounds(),
        outline,
        (context, offset) => _pushBackdrop(
          context,
          offset,
          ui.ImageFilter.blur(
            sigmaX: _GlassPaint.frostedSigma,
            sigmaY: _GlassPaint.frostedSigma,
          ),
          (canvas) {
            final shape = outline.shift(offset);
            canvas.drawPath(shape, Paint()..color = paint.fill);
            final px = 1 / paint.dpr;
            _strokeInside(canvas, shape, paint.rimPaint(shape.getBounds()), px);
          },
        ),
        oldLayer: _clipPath.layer,
      );
    }
    // The pieces sit on the glass, outside its clip (a badge may overhang).
    context.paintChild(_leading, offset + _offsetOf(_leading));
    context.paintChild(_trailing, offset + _offsetOf(_trailing));
  }

  Offset _offsetOf(RenderBox child) =>
      (child.parentData! as _PairParentData).offset;

  void _pushBackdrop(
    PaintingContext context,
    Offset offset,
    ui.ImageFilter filter,
    void Function(Canvas canvas) material,
  ) {
    final layer = _backdrop.layer ??= BackdropFilterLayer();
    layer
      ..filter = filter
      ..backdropKey = _backdropKey;
    context.pushLayer(
      layer,
      (context, offset) => material(context.canvas),
      offset,
    );
  }

  ui.ImageFilter _lens(RRect a, RRect b, GlassShaders shaders) {
    final rectA = backdropRect(a.outerRect);
    final rectB = backdropRect(b.outerRect);
    final px = a.width > 0 ? rectA.width / a.width : _paint.dpr;
    double corner(RRect shape) => math.min(
      [
        shape.tlRadiusX,
        shape.trRadiusX,
        shape.blRadiusX,
        shape.brRadiusX,
      ].reduce(math.max),
      shape.shortestSide / 2,
    );
    final shortHalf = math.min(a.shortestSide, b.shortestSide) / 2;
    return shaders.filter(
      GlassLens(
        rect: rectA,
        radius: corner(a) * px,
        rect2: rectB,
        radius2: corner(b) * px,
        blend: _blend * px,
        band: math.min(18, shortHalf * .8) * px,
        bend: math.min(10, shortHalf * .4) * px,
        rim: _paint.rimStrength,
        px: px,
        tint: _paint.fill,
        glow: math.max(_pressLeading.value, _pressTrailing.value).clamp(0, 1),
        cover: _pairFrost * px,
      ),
    );
  }

  /// A stroke of [width] inside [shape]'s edge only: crisp, never half a
  /// pixel outside.
  static void _strokeInside(
    Canvas canvas,
    Path shape,
    Paint paint,
    double width,
  ) {
    canvas
      ..save()
      ..clipPath(shape)
      ..drawPath(
        shape,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2,
      )
      ..restore();
  }

  /// The two rounded rectangles and, once they are closer than half the
  /// [blend], the neck between them: the zero line of the shader's smooth
  /// union, for the frosted and solid looks.
  static Path _outline(RRect a, RRect b, double blend) {
    final path = Path()
      ..addRRect(a)
      ..addRRect(b);
    if (blend <= 0) return path;
    final left = a.center.dx <= b.center.dx ? a : b;
    final right = identical(left, a) ? b : a;
    final rl = math.min(left.trRadiusX, left.height / 2);
    final rr = math.min(right.tlRadiusX, right.height / 2);
    final r = (rl + rr) / 2;
    final c1 = Offset(left.right - rl, left.center.dy);
    final c2 = Offset(right.left + rr, right.center.dy);
    final half = (c2.dx - c1.dx) / 2;
    final reach = r + blend / 4;
    if (half >= reach || rl <= 0 || rr <= 0) return path;
    // Where two circles' smooth union crosses the middle.
    final neck = math.sqrt(reach * reach - half * half);
    final mid = (c1 + c2) / 2;
    final lift = math.min(r * .95, neck * 1.5);
    final ax = c1.dx + math.sqrt(math.max(0.0, rl * rl - lift * lift));
    final bx = c2.dx - math.sqrt(math.max(0.0, rr * rr - lift * lift));
    Offset control(double sign) {
      final through = Offset(mid.dx, mid.dy + sign * neck);
      final ends = Offset((ax + bx) / 2, mid.dy + sign * lift);
      return through * 2 - ends;
    }

    final top = control(-1);
    final bottom = control(1);
    final bridge = Path()
      ..moveTo(ax, c1.dy - lift)
      ..quadraticBezierTo(top.dx, top.dy, bx, c2.dy - lift)
      ..lineTo(bx, c2.dy + lift)
      ..quadraticBezierTo(bottom.dx, bottom.dy, ax, c1.dy + lift)
      ..close();
    return Path.combine(PathOperation.union, path, bridge);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = _offsetOf(child);
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
