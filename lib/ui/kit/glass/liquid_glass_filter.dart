import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'glass_geometry.dart';

/// Applies `shaders/kit_glass.frag` over a light blur (the frost) to the
/// backdrop under its child, as one [BackdropFilterLayer]. The shader also
/// lays the [tint] (thinner across the bending edge), so the child needs no
/// fill of its own. Put it inside a clip (a [ClipRRect] the same shape) so
/// the filter reads and writes only the glass's own rectangle.
///
/// The shader needs to know where the glass is on the backdrop, in the
/// backdrop's pixels: the render object's transform to the screen times
/// the device pixel ratio, read when it paints and checked
/// again after every frame: a page transition or a keyboard moves the glass
/// without repainting it, and the edge must follow within one frame.
///
/// With a [geometry] the lens follows the drawn shape (pressed glass swells
/// and brightens, flowing glass follows its new size) by repainting only.
class LiquidGlassFilter extends SingleChildRenderObjectWidget {
  const LiquidGlassFilter({
    super.key,
    required this.program,
    required this.radius,
    required this.devicePixelRatio,
    required this.tint,
    this.band = 18,
    this.bend = 10,
    this.frost = 5,
    this.rim = .6,
    this.geometry,
    this.backdropKey,
    super.child,
  });

  final ui.FragmentProgram program;

  /// Corner radius, logical pixels.
  final double radius;

  /// Physical pixels per logical pixel: the backdrop is physical.
  final double devicePixelRatio;

  /// The surface colour laid over the frosted backdrop, with its opacity.
  final Color tint;

  /// Width of the refracting edge, logical pixels (at most 40 % of the
  /// shorter half side, so a small chip still has a flat middle).
  final double band;

  /// How far the edge pulls the backdrop in, logical pixels.
  final double bend;

  /// The frost: the blur's sigma under the lens, logical pixels. Light, so
  /// the bent edge stays sharp (the owner: "very very sharp and crisp").
  final double frost;

  /// Strength of the rim of light, 0–1.
  final double rim;

  /// The drawn shape when it differs from the box; null is the box.
  final GlassGeometry? geometry;

  /// Shared backdrop read ([BackdropGroup]); null reads its own.
  final BackdropKey? backdropKey;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) =>
      RenderLiquidGlass(
        program: program,
        radius: radius,
        devicePixelRatio: devicePixelRatio,
        tint: tint,
        band: band,
        bend: bend,
        frost: frost,
        rim: rim,
        geometry: geometry,
        backdropKey: backdropKey,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlass renderObject,
  ) {
    renderObject
      ..program = program
      ..radius = radius
      ..devicePixelRatio = devicePixelRatio
      ..tint = tint
      ..band = band
      ..bend = bend
      ..frost = frost
      ..rim = rim
      ..geometry = geometry
      ..backdropKey = backdropKey;
  }
}

/// The glass shader's uniforms, in the order `shaders/kit_glass.frag`
/// declares them (after the engine's `u_size`). Rectangles and lengths are
/// in backdrop (physical) pixels.
@immutable
class GlassLens {
  const GlassLens({
    required this.rect,
    required this.radius,
    required this.band,
    required this.bend,
    required this.rim,
    required this.px,
    required this.tint,
    Rect? rect2,
    double? radius2,
    this.blend = 0,
    this.glow = 0,
    this.cover = 0,
  }) : rect2 = rect2 ?? rect,
       radius2 = radius2 ?? radius;

  final Rect rect;
  final double radius;
  final double band;
  final double bend;
  final double rim;
  final double px;
  final Color tint;

  /// A second rounded rectangle, joined to [rect] where they are closer
  /// than [blend]; the same rectangle for one surface.
  final Rect rect2;
  final double radius2;
  final double blend;

  /// Pressed brightness, 0–1.
  final double glow;

  /// 0: one surface, its edge drawn by a clip over a frosted backdrop.
  /// Above 0: the shader draws its own edge and frosts with this radius.
  final double cover;

  List<double> get uniforms => [
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    radius,
    band,
    bend,
    rim,
    px,
    tint.r,
    tint.g,
    tint.b,
    tint.a,
    rect2.left,
    rect2.top,
    rect2.right,
    rect2.bottom,
    radius2,
    blend,
    glow,
    cover,
  ];

  @override
  bool operator ==(Object other) =>
      other is GlassLens &&
      other.rect == rect &&
      other.radius == radius &&
      other.band == band &&
      other.bend == bend &&
      other.rim == rim &&
      other.px == px &&
      other.tint == tint &&
      other.rect2 == rect2 &&
      other.radius2 == radius2 &&
      other.blend == blend &&
      other.glow == glow &&
      other.cover == cover;

  @override
  int get hashCode => Object.hash(
    rect,
    radius,
    band,
    bend,
    rim,
    px,
    tint,
    rect2,
    radius2,
    blend,
    glow,
    cover,
  );
}

/// Two shaders from the one loaded program, used in turn, and the filter
/// made from the current lens. Creating a filter only sets uniforms: the
/// program is compiled once, when it loads (no per-frame shader compiles).
class GlassShaders {
  GlassShaders(ui.FragmentProgram program)
    : _shaders = [program.fragmentShader(), program.fragmentShader()];

  // The engine copies a shader's uniforms when a filter made from it is
  // first added to a scene, and filters made from the same shader compare
  // equal (so a layer would keep the old one); a new filter from the other
  // shader is always a real change.
  final List<ui.FragmentShader> _shaders;
  int _turn = 0;
  GlassLens? _lens;
  double? _frost;
  ui.ImageFilter? _filter;

  /// The filter for [lens], composed over a blur of sigma [frost] (logical
  /// pixels) for one surface; the same filter while nothing changed.
  ui.ImageFilter filter(GlassLens lens, {double frost = 0}) {
    final cached = _filter;
    if (cached != null && lens == _lens && frost == _frost) return cached;
    _turn = 1 - _turn;
    final shader = _shaders[_turn];
    var i = 2; // 0 and 1: the texture size, set by the engine.
    for (final value in lens.uniforms) {
      shader.setFloat(i++, value);
    }
    _lens = lens;
    _frost = frost;
    final shaded = ui.ImageFilter.shader(shader);
    return _filter = frost <= 0 || lens.cover > 0
        ? shaded
        : ui.ImageFilter.compose(
            outer: shaded,
            inner: ui.ImageFilter.blur(
              sigmaX: frost,
              sigmaY: frost,
              tileMode: TileMode.clamp,
            ),
          );
  }

  /// Forget the cached filter: the next [filter] builds a new one.
  void invalidate() => _filter = null;

  void dispose() {
    for (final shader in _shaders) {
      shader.dispose();
    }
  }
}

/// Where a render object's glass sits on the backdrop, and a watch after
/// every frame that repaints it when it moved without repainting (a page
/// transition, the keyboard). An idle screen stays idle: the watch never
/// asks for a frame of its own.
mixin GlassBackdropTracking on RenderBox {
  /// Physical pixels per logical pixel.
  double get backdropPixelRatio;

  Rect? _trackedBox;

  /// [local] (this box's coordinates) in backdrop pixels. Also remembers
  /// where the whole box was, for the watch.
  Rect backdropRect(Rect local) {
    // getTransformTo(null) stops below the root view's device pixel ratio.
    final transform = getTransformTo(null);
    _trackedBox = _scaled(
      MatrixUtils.transformRect(transform, Offset.zero & size),
    );
    return _scaled(MatrixUtils.transformRect(transform, local));
  }

  Rect _scaled(Rect logical) {
    final dpr = backdropPixelRatio;
    return Rect.fromLTRB(
      logical.left * dpr,
      logical.top * dpr,
      logical.right * dpr,
      logical.bottom * dpr,
    );
  }

  bool _watching = false;

  void _watch() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback(_check);
  }

  void _check(Duration _) {
    _watching = false;
    if (!attached) return;
    if (!hasSize) {
      _watch();
      return;
    }
    final tracked = _trackedBox;
    if (tracked != null) {
      final now = _scaled(
        MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size),
      );
      if (now != tracked) markNeedsPaint();
    }
    // Registering again does not ask for a frame: an idle screen stays idle.
    _watch();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _watch();
  }
}

/// The render object of [LiquidGlassFilter].
class RenderLiquidGlass extends RenderProxyBox with GlassBackdropTracking {
  RenderLiquidGlass({
    required ui.FragmentProgram program,
    required double radius,
    required double devicePixelRatio,
    required Color tint,
    required double band,
    required double bend,
    required double frost,
    required double rim,
    GlassGeometry? geometry,
    BackdropKey? backdropKey,
  }) : _program = program,
       _radius = radius,
       _devicePixelRatio = devicePixelRatio,
       _tint = tint,
       _band = band,
       _bend = bend,
       _frost = frost,
       _rim = rim,
       _geometry = geometry,
       _backdropKey = backdropKey,
       _shaders = GlassShaders(program);

  ui.FragmentProgram _program;
  set program(ui.FragmentProgram value) {
    if (identical(value, _program)) return;
    _program = value;
    _shaders.dispose();
    _shaders = GlassShaders(value);
    markNeedsPaint();
  }

  GlassShaders _shaders;

  double _radius;
  set radius(double value) => _set(_radius, value, () => _radius = value);
  double _devicePixelRatio;
  set devicePixelRatio(double value) =>
      _set(_devicePixelRatio, value, () => _devicePixelRatio = value);

  @override
  double get backdropPixelRatio => _devicePixelRatio;

  Color _tint;
  set tint(Color value) {
    if (value == _tint) return;
    _tint = value;
    markNeedsPaint();
  }

  double _band;
  set band(double value) => _set(_band, value, () => _band = value);
  double _bend;
  set bend(double value) => _set(_bend, value, () => _bend = value);
  double _frost;
  set frost(double value) => _set(_frost, value, () => _frost = value);
  double _rim;
  set rim(double value) => _set(_rim, value, () => _rim = value);

  GlassGeometry? _geometry;
  set geometry(GlassGeometry? value) {
    if (identical(value, _geometry)) return;
    if (attached) _geometry?.removeListener(markNeedsPaint);
    _geometry = value;
    if (attached) _geometry?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  BackdropKey? _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  void _set(double old, double value, VoidCallback assign) {
    if (old == value) return;
    assign();
    markNeedsPaint();
  }

  Rect? _filterRect;

  /// The rectangle last painted, in backdrop pixels (tests read it).
  @visibleForTesting
  Rect? get debugBackdropRect => _filterRect;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  ui.ImageFilter _filter() {
    final geometry = _geometry;
    final local = geometry?.rectFor(size) ?? Offset.zero & size;
    final rect = backdropRect(local);
    // One logical pixel in backdrop pixels: the device pixel ratio times
    // any scale an ancestor applies (a page or tab transition).
    final px = local.width > 0 ? rect.width / local.width : 1.0;
    final shortHalf = local.shortestSide / 2;
    _filterRect = rect;
    return _shaders.filter(
      GlassLens(
        rect: rect,
        radius: _radius.clamp(0, shortHalf) * px,
        band: _band.clamp(1, shortHalf * .8) * px,
        bend: _bend * px,
        rim: _rim,
        px: px,
        tint: _tint,
        glow: geometry?.glow ?? 0,
      ),
      frost: _frost,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final backdrop = layer ??= BackdropFilterLayer();
    backdrop
      ..filter = _filter()
      ..backdropKey = _backdropKey;
    context.pushLayer(backdrop, super.paint, offset);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _geometry?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _geometry?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _shaders.dispose();
    super.dispose();
  }
}
