import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Applies `shaders/kit_glass.frag` over a light blur (the frost) to the
/// backdrop under its child, as one [BackdropFilterLayer]. The shader also
/// lays the [tint] (thinner across the bending edge), so the child needs no
/// fill of its own. Put it inside a clip (a [ClipRRect] the same size) so
/// the filter reads and writes only the glass's own rectangle.
///
/// The shader needs to know where the glass is on the backdrop, in the
/// backdrop's pixels: the render object's transform to the screen times
/// the device pixel ratio, read when it paints and checked
/// again after every frame: a page transition or a keyboard moves the glass
/// without repainting it, and the edge must follow within one frame.
class LiquidGlassFilter extends SingleChildRenderObjectWidget {
  const LiquidGlassFilter({
    super.key,
    required this.program,
    required this.radius,
    required this.devicePixelRatio,
    required this.tint,
    this.band = 18,
    this.bend = 10,
    this.frost = 8,
    this.rim = .6,
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

  /// The frost: the blur's sigma under the lens, logical pixels.
  final double frost;

  /// Strength of the rim of light, 0–1.
  final double rim;

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
      ..backdropKey = backdropKey;
  }
}

/// The render object of [LiquidGlassFilter].
class RenderLiquidGlass extends RenderProxyBox {
  RenderLiquidGlass({
    required ui.FragmentProgram program,
    required double radius,
    required double devicePixelRatio,
    required Color tint,
    required double band,
    required double bend,
    required double frost,
    required double rim,
    BackdropKey? backdropKey,
  }) : _program = program,
       _radius = radius,
       _devicePixelRatio = devicePixelRatio,
       _tint = tint,
       _band = band,
       _bend = bend,
       _frost = frost,
       _rim = rim,
       _backdropKey = backdropKey,
       _shaders = [program.fragmentShader(), program.fragmentShader()];

  ui.FragmentProgram _program;
  set program(ui.FragmentProgram value) {
    if (identical(value, _program)) return;
    _program = value;
    for (final shader in _shaders) {
      shader.dispose();
    }
    _shaders = [value.fragmentShader(), value.fragmentShader()];
    _invalidate();
  }

  // Two shaders used in turn. The engine copies a shader's uniforms when a
  // filter made from it is first added to a scene, and filters made from
  // the same shader compare equal (so a layer would keep the old one); a
  // new filter from the other shader is always a real change.
  List<ui.FragmentShader> _shaders;
  int _turn = 0;

  double _radius;
  set radius(double value) => _set(_radius, value, () => _radius = value);
  double _devicePixelRatio;
  set devicePixelRatio(double value) =>
      _set(_devicePixelRatio, value, () => _devicePixelRatio = value);
  Color _tint;
  set tint(Color value) {
    if (value == _tint) return;
    _tint = value;
    _invalidate();
  }

  double _band;
  set band(double value) => _set(_band, value, () => _band = value);
  double _bend;
  set bend(double value) => _set(_bend, value, () => _bend = value);
  double _frost;
  set frost(double value) => _set(_frost, value, () => _frost = value);
  double _rim;
  set rim(double value) => _set(_rim, value, () => _rim = value);

  BackdropKey? _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  void _set(double old, double value, VoidCallback assign) {
    if (old == value) return;
    assign();
    _invalidate();
  }

  void _invalidate() {
    _filter = null;
    markNeedsPaint();
  }

  ui.ImageFilter? _filter;
  Rect? _filterRect;

  /// The rectangle last painted, in backdrop pixels (tests read it).
  @visibleForTesting
  Rect? get debugBackdropRect => _filterRect;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  // getTransformTo(null) stops below the root view's device pixel ratio.
  Rect _backdropRect() {
    final logical = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    final dpr = _devicePixelRatio;
    return Rect.fromLTRB(
      logical.left * dpr,
      logical.top * dpr,
      logical.right * dpr,
      logical.bottom * dpr,
    );
  }

  ui.ImageFilter _filterFor(Rect rect) {
    if (_filter != null && rect == _filterRect) return _filter!;
    // One logical pixel in backdrop pixels: the device pixel ratio times
    // any scale an ancestor applies (a page or tab transition).
    final px = size.width > 0 ? rect.width / size.width : 1.0;
    final shortHalf = size.shortestSide / 2;
    _turn = 1 - _turn;
    final shader = _shaders[_turn];
    var i = 2; // 0 and 1: the texture size, set by the engine.
    for (final value in [
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      _radius.clamp(0, shortHalf) * px,
      (_band.clamp(1, shortHalf * .8)) * px,
      _bend * px,
      _rim,
      px,
      _tint.r,
      _tint.g,
      _tint.b,
      _tint.a,
    ]) {
      shader.setFloat(i++, value.toDouble());
    }
    _filterRect = rect;
    final lens = ui.ImageFilter.shader(shader);
    return _filter = _frost <= 0
        ? lens
        : ui.ImageFilter.compose(
            outer: lens,
            inner: ui.ImageFilter.blur(
              sigmaX: _frost,
              sigmaY: _frost,
              tileMode: TileMode.clamp,
            ),
          );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final filter = _filterFor(_backdropRect());
    final backdrop = layer ??= BackdropFilterLayer();
    backdrop
      ..filter = filter
      ..backdropKey = _backdropKey;
    context.pushLayer(backdrop, super.paint, offset);
  }

  // After each frame: did the glass move without repainting?
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
    if (_filterRect != null && _backdropRect() != _filterRect) {
      markNeedsPaint();
    }
    // Registering again does not ask for a frame: an idle screen stays idle.
    _watch();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _watch();
  }

  @override
  void dispose() {
    for (final shader in _shaders) {
      shader.dispose();
    }
    super.dispose();
  }
}
