import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../theme_roles.dart';
import '../kit_effects.dart';
import '../kit_motion.dart';
import '../kit_tokens.dart';
import 'glass_geometry.dart';
import 'glass_safety.dart';
import 'liquid_glass_filter.dart';

part 'kit_glass_pair.dart';

/// How a [KitGlass] draws, decided per frame from the phone and the person.
enum KitGlassLook {
  /// The liquid glass shader (`shaders/kit_glass.frag`): the backdrop bends
  /// at the rounded edge, a thin rim catches the light, a light frost.
  /// Only where Impeller runs the shader ([KitGlassShader.supported]).
  liquid,

  /// The frosted blur the app had before liquid glass: phones whose
  /// renderer cannot run a backdrop shader (Skia) or before it loaded.
  frosted,

  /// A solid surface: glass turned off in Settings › Appearance, or the
  /// system's high contrast, accessible navigation or remove animations.
  solid,
}

/// Loads the liquid glass shader once for the whole app and says whether
/// this phone can use it ([KitGlassSafety] guards weak renderers).
abstract final class KitGlassShader {
  /// The shader, once loaded; null before, and forever where unsupported
  /// or when loading failed (glass then stays frosted).
  static final ValueNotifier<ui.FragmentProgram?> program = ValueNotifier(null);

  /// Tests and captures only: pretend the renderer can (true) or cannot
  /// (false) run a backdrop shader. Null asks the engine.
  static bool? debugSupportedOverride;

  /// Whether the renderer can run a shader as a backdrop filter: Impeller
  /// (Vulkan, or its OpenGL ES fallback). False under Skia, and under
  /// `flutter test` unless it runs with `--enable-impeller`.
  static bool get supported =>
      debugSupportedOverride ?? ui.ImageFilter.isShaderFilterSupported;

  static Future<void>? _loading;

  static const asset = 'shaders/kit_glass.frag';

  /// Starts loading the shader (once). Cheap to call from every build.
  /// Where [KitGlassSafety] says the device's renderer cannot take it (an
  /// emulator, a software renderer, or the last sessions died with liquid
  /// glass on screen) it is never loaded and the glass stays frosted.
  static void ensureLoaded() {
    if (_loading != null || !supported) return;
    _loading = _load().then(
      (loaded) {
        if (loaded == null) return;
        program.value = loaded;
        KitGlassSafety.watch();
      },
      onError: (Object error, StackTrace stack) {
        // A missing or rejected shader is not worth a crash: stay frosted.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'kit glass',
            context: ErrorDescription('loading $asset'),
            silent: true,
          ),
        );
      },
    );
  }

  /// The person turned liquid glass back on after crashes: clear the
  /// strikes and load the shader now.
  static Future<void> turnLiquidBackOn() async {
    await KitGlassSafety.turnBackOn();
    _loading = null;
    ensureLoaded();
  }

  static Future<ui.FragmentProgram?> _load() async {
    if (!await KitGlassSafety.allowed()) return null;
    return ui.FragmentProgram.fromAsset(asset);
  }

  /// Tests and captures only: forget the shader and any override.
  static void debugReset() {
    _loading = null;
    program.value = null;
    debugSupportedOverride = null;
    KitGlassSafety.debugReset();
  }
}

/// A bounded surface of glass floating over scrolling content: the bottom
/// dock, the chat composer, a small bar (design standard §10, glass).
///
/// Never full screen, never behind body text: it is for a control or a
/// short row of controls that content passes beneath. Its look is
/// [KitGlassLook]: liquid glass where the phone runs the shader, the old
/// frosted blur where it cannot, and solid when the person turned glass off
/// or asked for high contrast, accessible navigation or no animations.
///
/// Fluid glass (the owner's approved sample, visual language §6): with
/// [respond] the glass gives under a finger (it swells a few dp past its box
/// and brightens, then springs back); with [flow] it follows its content's
/// new size instead of jumping; [KitGlass.pair] brings two pieces together.
/// Only the drawn shape moves, on [KitMotion] springs: content is never
/// scaled and never relaid out, so labels stay crisp. Under reduced motion
/// ([KitMotion.reduced]) every state is instant; solid glass never moves.
///
/// Several glass surfaces on one screen should share one read of the
/// backdrop: put a [BackdropGroup] around the screen (its `Scaffold`) and
/// each [KitGlass] under it joins the group.
///
/// States: none — a surface around its child, it holds no data.
class KitGlass extends StatefulWidget {
  const KitGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.shadow = true,
    this.dim = true,
    this.respond = false,
    this.flow = false,
  }) : trailing = null,
       joined = false;

  /// Two pieces of glass in one row, drawn as one liquid surface: [leading]
  /// at the start at its own width, [trailing] at the end. When [joined]
  /// the trailing piece slides up to a small gap from the leading one
  /// (never melted into it); apart again, it slides back to the end. The
  /// shell's server pill and search join while the page is scrolled
  /// ([scrolledOf]).
  ///
  /// Each piece gives under a finger ([respond]). Only the drawn glass
  /// moves: the pieces keep their layout, sizes and semantics order.
  const KitGlass.pair({
    super.key,
    required Widget leading,
    required Widget this.trailing,
    this.joined = false,
    this.borderRadius,
    this.shadow = true,
    this.dim = true,
    this.respond = true,
  }) : child = leading,
       flow = false;

  /// The content; for [KitGlass.pair], the leading piece.
  final Widget child;

  /// [KitGlass.pair] only: the piece at the end.
  final Widget? trailing;

  /// [KitGlass.pair] only: the trailing piece sits next to the leading one,
  /// joined.
  final bool joined;

  /// The glass's corners. The shader bends with the largest corner radius;
  /// the clip follows each corner exactly. Null takes the floating tab
  /// bar's corners ([KitTokens.navRadius], 22).
  final BorderRadius? borderRadius;

  /// The one tight shadow of floating glass ([KitTokens.glassShadows]:
  /// y 6, blur 16, the `glassShadow` role; LOOK-20), never when solid.
  final bool shadow;

  /// Glass that holds words (labels, a text field) dims what passes behind
  /// it further, so content reads as colour, never as letters (§6).
  final bool dim;

  /// The glass gives under a finger: it swells up to
  /// [GlassGeometry.swellMax] dp past its box, brightens, and springs back
  /// on release ([KitMotion.glassPress]). For glass that is itself a
  /// control or a bar of controls (the dock, the top controls).
  final bool respond;

  /// The glass follows a change of its box's size from the old size,
  /// growing from its bottom edge ([KitMotion.glassFlow]), instead of
  /// jumping: a composer growing a line as the person types. The content
  /// takes its new size at once and the glass reveals it as it flows; taps
  /// land on the content where it now is from the first frame (only the
  /// paint is clipped to the flowing shape, never hit testing).
  final bool flow;

  /// Neutral ink stays readable even when contrasting content crosses behind
  /// the translucent material; muted palette roles are not sufficient here.
  static Color foregroundColor(ThemeData theme) =>
      ThemeRoles.resolve(theme).glassInk;

  /// The system settings under which glass is solid: high contrast,
  /// accessible navigation (a screen reader) and remove animations. Android
  /// has no "reduce transparency" setting that reaches Flutter.
  static bool reduceEffects(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.highContrast ||
        media.accessibleNavigation ||
        media.disableAnimations;
  }

  /// The look a [KitGlass] has here, now.
  static KitGlassLook lookOf(BuildContext context) {
    if (reduceEffects(context) || !KitEffects.of(context).glass) {
      return KitGlassLook.solid;
    }
    if (!KitGlassShader.supported) return KitGlassLook.frosted;
    KitGlassShader.ensureLoaded();
    return KitGlassShader.program.value == null
        ? KitGlassLook.frosted
        : KitGlassLook.liquid;
  }

  /// Watches the vertical scrolling under [child] and tells the glass above
  /// it whether the page is scrolled ([scrolledOf]): past one
  /// [KitTokens.minTarget] from the top. A new [resetOn] (the selected
  /// destination) starts again at the top. The shell (KitNav) puts it
  /// around the destination's page.
  static Widget trackScroll({required Widget child, Object? resetOn}) =>
      _KitGlassScrollTracker(resetOn: resetOn, child: child);

  /// Whether the page under the nearest [trackScroll] is scrolled; false
  /// with none. The caller rebuilds when it changes.
  static bool scrolledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_KitGlassScrollScope>()
          ?.notifier
          ?.value ??
      false;

  @override
  State<KitGlass> createState() => _KitGlassState();
}

class _KitGlassState extends State<KitGlass> with TickerProviderStateMixin {
  final GlassGeometry _geometry = GlassGeometry();
  AnimationController? _press;
  AnimationController? _flow;
  Size? _laidOut;
  bool _still = true;

  @override
  void dispose() {
    _press?.dispose();
    _flow?.dispose();
    _geometry.dispose();
    super.dispose();
  }

  void _pressTo(double target) {
    // A finger lifted after the glass left the screen still reaches its
    // listener: nothing to spring then.
    if (!mounted) return;
    final press = _press ??= AnimationController.unbounded(vsync: this)
      ..addListener(() => _geometry.press = _press!.value);
    press
        .animateWith(
          SpringSimulation(
            KitMotion.glassPress,
            press.value,
            target,
            press.velocity,
          ),
        )
        .then((_) {
          // Exactly at rest: the drawn shape is the box again.
          if (mounted) press.value = target;
        });
  }

  void _down(PointerDownEvent _) {
    if (!_still) _pressTo(1);
  }

  void _up(PointerEvent _) {
    if (_press != null) _pressTo(0);
  }

  /// Called from layout with the box's new size: starts a flow from the old
  /// size, anchored at the bottom edge.
  void _laid(Size size) {
    final old = _laidOut;
    _laidOut = size;
    if (!widget.flow || _still || old == null || old == size) return;
    // Where the glass is drawn now, moved into the new box's coordinates:
    // a flow already running continues from where it is.
    final from = _geometry.flowFrom;
    final now = from == null
        ? Offset.zero & old
        : Rect.lerp(from, Offset.zero & old, _geometry.flow)!;
    final shift = Offset(
      (size.width - old.width) / 2,
      size.height - old.height,
    );
    _geometry.startFlow(now.shift(shift));
    final flow = _flow ??= AnimationController.unbounded(vsync: this)
      ..addListener(() => _geometry.flow = _flow!.value);
    flow.value = 0;
    flow.animateWith(SpringSimulation(KitMotion.glassFlow, 0, 1, 0)).then((_) {
      if (mounted) _geometry.settleFlow();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds once, when the shader finishes loading.
    return ValueListenableBuilder<ui.FragmentProgram?>(
      valueListenable: KitGlassShader.program,
      builder: (context, program, _) => _build(context, program),
    );
  }

  Widget _build(BuildContext context, ui.FragmentProgram? program) {
    final look = KitGlass.lookOf(context);
    final still = look == KitGlassLook.solid || KitMotion.reduced(context);
    if (still && !_still) {
      // Reduced motion or solid glass: every state is instant.
      _press?.stop();
      _flow?.stop();
      _geometry.settle();
    }
    _still = still;

    final trailing = widget.trailing;
    if (trailing != null) {
      return _GlassPixelSnap(
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        child: _KitGlassPair(
          look: look,
          program: program,
          still: still,
          joined: widget.joined,
          radius: widget.borderRadius,
          shadow: widget.shadow,
          dim: widget.dim,
          respond: widget.respond,
          leading: widget.child,
          trailing: trailing,
        ),
      );
    }

    final paint = _GlassPaint.of(context, look, widget.dim, widget.shadow);
    _geometry.pixelRatio = paint.dpr;
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(paint.tokens.navRadius);
    final solid = look == KitGlassLook.solid;
    final material = DecoratedBox(
      decoration: _GlassDecoration(
        geometry: _geometry,
        color: switch (look) {
          KitGlassLook.solid => paint.solidFill,
          KitGlassLook.frosted => paint.fill,
          KitGlassLook.liquid => null,
        },
        borderRadius: borderRadius,
        border: solid
            ? Border.all(
                color: paint.hairline,
                width: KitTokens.hairlineWidth(context),
              )
            : null,
      ),
      // The rim (§7, LOOK-21): one physical pixel on the pixel grid, light
      // along the top edge and darker along the bottom, never a soft glow.
      child: solid
          ? widget.child
          : CustomPaint(
              foregroundPainter: _GlassRimPainter(
                geometry: _geometry,
                radius: borderRadius,
                paint: paint,
              ),
              child: widget.child,
            ),
    );

    final backdropKey = BackdropGroup.of(context)?.backdropKey;
    final Widget glass = switch (look) {
      KitGlassLook.solid => material,
      KitGlassLook.frosted => BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _GlassPaint.frostedSigma,
          sigmaY: _GlassPaint.frostedSigma,
        ),
        backdropGroupKey: backdropKey,
        child: material,
      ),
      KitGlassLook.liquid => LiquidGlassFilter(
        program: program!,
        radius: _largestRadius(borderRadius),
        devicePixelRatio: paint.dpr,
        tint: paint.fill,
        rim: paint.rimStrength,
        geometry: _geometry,
        backdropKey: backdropKey,
        child: material,
      ),
    };

    // The one shadow is painted after the glass and only outside its
    // shape: the glass never reads its own shadow from the backdrop (the
    // grey ledge inside its bottom edge on light grounds), and nothing of it
    // shows through the thinner edge of the lens.
    Widget result = CustomPaint(
      foregroundPainter: solid || paint.shadows.isEmpty
          ? null
          : _GlassShadowPainter(
              geometry: _geometry,
              radius: borderRadius,
              paint: paint,
            ),
      child: _GlassClip(
        borderRadius: borderRadius,
        clipper: _GlassClipper(_geometry, borderRadius),
        child: glass,
      ),
    );
    if (widget.respond && !still) {
      result = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: result,
      );
    }
    if (widget.flow) result = _FlowProbe(onLaidOut: _laid, child: result);
    return _GlassPixelSnap(devicePixelRatio: paint.dpr, child: result);
  }

  static double _largestRadius(BorderRadius borderRadius) => [
    borderRadius.topLeft.x,
    borderRadius.topRight.x,
    borderRadius.bottomLeft.x,
    borderRadius.bottomRight.x,
  ].reduce((a, b) => a > b ? a : b);
}

extension on GlassGeometry {
  /// Ends a finished flow exactly at the box.
  void settleFlow() {
    if (flowFrom != null) flow = 1;
  }
}

/// Everything the glass paints with, from the theme, the look and the
/// person's settings.
@immutable
class _GlassPaint {
  const _GlassPaint({
    required this.tokens,
    required this.look,
    required this.fill,
    required this.solidFill,
    required this.hairline,
    required this.hairlineWidth,
    required this.rimTop,
    required this.rimBottom,
    required this.rimHighlight,
    required this.rimStrength,
    required this.shadows,
    required this.dpr,
  });

  /// The frosted look's blur (before liquid glass, and on Skia).
  static const double frostedSigma = 12;

  factory _GlassPaint.of(
    BuildContext context,
    KitGlassLook look,
    bool dim,
    bool shadow,
  ) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _GlassPaint(
      tokens: tokens,
      look: look,
      // The glass is `surface2` at 82 % (visual language §4), deeper where
      // it holds words (§6). The fill is what keeps the dock's labels
      // readable over any content (test/glass_surface_test.dart checks
      // 4.5:1 over 125 backdrops). Liquid glass lays the same fill in its
      // shader, full over the middle where the labels are and thinner
      // across the bending edge.
      fill: roles.surface2.withValues(alpha: dim ? .88 : .82),
      // Glass turned off: a solid surface2 at 94 %; the system's high
      // contrast, accessible navigation or remove animations: opaque.
      solidFill: KitGlass.reduceEffects(context)
          ? roles.surface2
          : roles.surface2.withValues(alpha: .94),
      hairline: roles.hairline,
      hairlineWidth: KitTokens.hairlineWidth(context),
      // The rim (§7): the edge's physical pixel runs from a light line at
      // the top to a darker one at the bottom. On a light ground white
      // glass has no edge of its own, so the edge line is the darker line,
      // lighter at the top, and the light line is the pixel just inside.
      rimTop: dark
          ? roles.glassRimLight
          : roles.glassRimDark.withValues(alpha: roles.glassRimDark.a * .6),
      rimBottom: roles.glassRimDark,
      rimHighlight: dark ? null : roles.glassRimLight,
      rimStrength: dark ? .7 : 1,
      shadows: shadow ? tokens.glassShadows : const [],
      dpr: MediaQuery.devicePixelRatioOf(context),
    );
  }

  final KitTokens tokens;
  final KitGlassLook look;
  final Color fill;
  final Color solidFill;
  final Color hairline;
  final double hairlineWidth;
  final Color rimTop;
  final Color rimBottom;
  final Color? rimHighlight;
  final double rimStrength;
  final List<BoxShadow> shadows;
  final double dpr;

  @override
  bool operator ==(Object other) =>
      other is _GlassPaint &&
      other.look == look &&
      other.fill == fill &&
      other.solidFill == solidFill &&
      other.hairline == hairline &&
      other.hairlineWidth == hairlineWidth &&
      other.rimTop == rimTop &&
      other.rimBottom == rimBottom &&
      other.rimHighlight == rimHighlight &&
      other.rimStrength == rimStrength &&
      listEquals(other.shadows, shadows) &&
      other.dpr == dpr;

  @override
  int get hashCode => Object.hash(
    look,
    fill,
    solidFill,
    hairline,
    hairlineWidth,
    rimTop,
    rimBottom,
    rimHighlight,
    rimStrength,
    Object.hashAll(shadows),
    dpr,
  );

  /// The rim (§7, LOOK-21) inside [shape]'s edge: its outermost physical
  /// pixel runs from [rimTop] at the top to [rimBottom] at the bottom, with
  /// no gap along the sides; on light glass the next pixel in is a light
  /// line across the top ([rimHighlight]). Never a soft glow. [shape]'s
  /// straight edges lie on physical pixels ([GlassGeometry.snap]).
  void paintRim(Canvas canvas, Path shape) {
    final bounds = shape.getBounds();
    final px = 1 / dpr;
    canvas
      ..save()
      ..clipPath(shape);
    final highlight = rimHighlight;
    if (highlight != null) {
      // The two physical pixels inside the top edge, filled (the edge line
      // below covers the outer one): a gradient-shaded wide stroke here,
      // inside the liquid glass's backdrop layer, crashed the Android
      // emulator's renderer (QEMU SIGSEGV, emulator QA of build 2062, F1).
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          shape,
          shape.shift(Offset(0, px * 2)),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [highlight, highlight.withValues(alpha: 0)],
            stops: const [0, .45],
          ).createShader(bounds),
      );
    }
    canvas
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px * 2
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [rimTop, rimBottom],
            // Lit from the top left, as the shader's specular line: the
            // line darkens a few levels along a wide edge instead of being
            // one flat colour (which also keeps a label, not the rim, the
            // darkest common colour for the text-contrast check, G5).
            transform: const GradientRotation(-.04),
          ).createShader(bounds),
      )
      ..restore();
  }

  /// The one shadow (§7: y 6, blur 16, 30 %, no halo), only outside the
  /// glass's [shape]. [cast] is the shape grown by a shadow's spread
  /// (negative: pulled in). The blur is CSS's, sigma half the blur radius,
  /// so it stays as tight as the canvas's.
  void paintShadows(
    Canvas canvas,
    Path shape,
    Path Function(double spread) cast,
  ) {
    if (shadows.isEmpty) return;
    final bounds = shape.getBounds();
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(bounds.inflate(64))
          ..addPath(shape, Offset.zero),
      );
    for (final shadow in shadows) {
      canvas.drawPath(
        cast(shadow.spreadRadius).shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            shadow.blurRadius / 2,
          ),
      );
    }
    canvas.restore();
  }
}

/// The one shadow of a [KitGlass], outside its drawn shape.
class _GlassShadowPainter extends CustomPainter {
  _GlassShadowPainter({
    required this.geometry,
    required this.radius,
    required _GlassPaint paint,
  }) : _paint = paint,
       super(repaint: geometry);

  final GlassGeometry geometry;
  final BorderRadius radius;
  final _GlassPaint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = geometry.rectFor(size);
    _paint.paintShadows(
      canvas,
      Path()..addRRect(GlassGeometry.rrect(radius, rect)),
      (spread) => Path()
        ..addRRect(
          GlassGeometry.rrect(radius, rect).inflate(spread).scaleRadii(),
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      old.geometry != geometry || old.radius != radius || old._paint != _paint;
}

/// Puts the glass's origin on a physical pixel, so its clip and its
/// one-physical-pixel rim land on the pixel grid (§7: "a golden that shows
/// soft edges ... or a half-pixel offset is a bug"). Moves the glass by less
/// than half a physical pixel; the shader reads the moved place.
class _GlassPixelSnap extends SingleChildRenderObjectWidget {
  const _GlassPixelSnap({required this.devicePixelRatio, super.child});

  final double devicePixelRatio;

  @override
  _RenderGlassPixelSnap createRenderObject(BuildContext context) =>
      _RenderGlassPixelSnap(devicePixelRatio);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassPixelSnap renderObject,
  ) {
    renderObject.devicePixelRatio = devicePixelRatio;
  }
}

class _RenderGlassPixelSnap extends RenderProxyBox {
  _RenderGlassPixelSnap(this._devicePixelRatio);

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  Offset _nudge = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final dpr = _devicePixelRatio;
    if (dpr > 0) {
      // getTransformTo(null) stops below the view's device pixel ratio:
      // logical pixels.
      final origin = MatrixUtils.transformPoint(
        getTransformTo(null),
        Offset.zero,
      );
      double on(double v) => (v * dpr).roundToDouble() / dpr - v;
      _nudge = Offset(on(origin.dx), on(origin.dy));
    }
    context.paintChild(child, offset + _nudge);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_nudge.dx, _nudge.dy, 0, 1);
  }
}

/// A [BoxDecoration] painted along the glass's drawn shape
/// ([GlassGeometry.rectFor]) instead of its box: the fill and the solid
/// hairline follow a press or a flow by repainting,
/// never by rebuilding. At rest it paints exactly as the plain decoration.
class _GlassDecoration extends BoxDecoration {
  const _GlassDecoration({
    required this.geometry,
    super.color,
    super.border,
    super.borderRadius,
  });

  final GlassGeometry geometry;

  BoxDecoration get _plain =>
      BoxDecoration(color: color, border: border, borderRadius: borderRadius);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GlassDecorationPainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      other is _GlassDecoration &&
      other.geometry == geometry &&
      other._plain == _plain;

  @override
  int get hashCode => Object.hash(geometry, _plain);
}

class _GlassDecorationPainter extends BoxPainter {
  _GlassDecorationPainter(this._decoration, super.onChanged)
    : _inner = _decoration._plain.createBoxPainter(onChanged) {
    _decoration.geometry.addListener(_moved);
  }

  final _GlassDecoration _decoration;
  final BoxPainter _inner;

  void _moved() => onChanged?.call();

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = _decoration.geometry.rectFor(size).shift(offset);
    _inner.paint(canvas, rect.topLeft, configuration.copyWith(size: rect.size));
  }

  @override
  void dispose() {
    _decoration.geometry.removeListener(_moved);
    _inner.dispose();
    super.dispose();
  }
}

/// The glass's rim: a stroke of exactly one physical pixel on the rounded
/// edge of the drawn shape, light at the top fading out by the middle and
/// darker at the bottom.
class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.geometry,
    required this.radius,
    required _GlassPaint paint,
  }) : _paint = paint,
       super(repaint: geometry);

  final GlassGeometry geometry;
  final BorderRadius radius;
  final _GlassPaint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.paintRim(
      canvas,
      Path()..addRRect(GlassGeometry.rrect(radius, geometry.rectFor(size))),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) =>
      old.geometry != geometry || old.radius != radius || old._paint != _paint;
}

/// The clip along the drawn shape.
class _GlassClipper extends CustomClipper<RRect> {
  _GlassClipper(this.geometry, this.radius) : super(reclip: geometry);

  final GlassGeometry geometry;
  final BorderRadius radius;

  @override
  RRect getClip(Size size) =>
      GlassGeometry.rrect(radius, geometry.rectFor(size));

  @override
  bool shouldReclip(_GlassClipper old) =>
      old.geometry != geometry || old.radius != radius;
}

/// Clips the glass's paint to its drawn shape, but takes taps anywhere in
/// its layout box: the content already has its final size and place, so a
/// control that just appeared in glass still flowing (or swelling) towards
/// it answers the first tap, not only once the shape has caught up.
class _GlassClip extends ClipRRect {
  const _GlassClip({
    required BorderRadius super.borderRadius,
    required CustomClipper<RRect> super.clipper,
    super.child,
  });

  @override
  RenderClipRRect createRenderObject(BuildContext context) => _RenderGlassClip(
    borderRadius: borderRadius,
    clipper: clipper,
    textDirection: Directionality.maybeOf(context),
  );
}

class _RenderGlassClip extends RenderClipRRect {
  _RenderGlassClip({
    required super.borderRadius,
    required super.clipper,
    super.textDirection,
  });

  /// [RenderBox.hitTest]: the layout box, never the drawn (moving) shape.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// Reports its size after every layout, for [KitGlass.flow].
class _FlowProbe extends SingleChildRenderObjectWidget {
  const _FlowProbe({required this.onLaidOut, super.child});

  final ValueChanged<Size> onLaidOut;

  @override
  _RenderFlowProbe createRenderObject(BuildContext context) =>
      _RenderFlowProbe(onLaidOut);

  @override
  void updateRenderObject(BuildContext context, _RenderFlowProbe render) {
    render.onLaidOut = onLaidOut;
  }
}

class _RenderFlowProbe extends RenderProxyBox {
  _RenderFlowProbe(this.onLaidOut);

  ValueChanged<Size> onLaidOut;

  @override
  void performLayout() {
    super.performLayout();
    // Only paint follows: the geometry repaints the glass.
    onLaidOut(size);
  }
}

// ── Scroll ──────────────────────────────────────────────────────────────

class _KitGlassScrollTracker extends StatefulWidget {
  const _KitGlassScrollTracker({required this.child, this.resetOn});

  final Widget child;
  final Object? resetOn;

  @override
  State<_KitGlassScrollTracker> createState() => _KitGlassScrollTrackerState();
}

class _KitGlassScrollTrackerState extends State<_KitGlassScrollTracker> {
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);

  @override
  void didUpdateWidget(_KitGlassScrollTracker old) {
    super.didUpdateWidget(old);
    if (old.resetOn != widget.resetOn) _scrolled.value = false;
  }

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  void _read(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final threshold = KitTokens.of(context).minTarget;
    _scrolled.value = metrics.pixels - metrics.minScrollExtent > threshold;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _read(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          _read(notification.metrics);
          return false;
        },
        child: _KitGlassScrollScope(notifier: _scrolled, child: widget.child),
      ),
    );
  }
}

class _KitGlassScrollScope extends InheritedNotifier<ValueNotifier<bool>> {
  const _KitGlassScrollScope({required super.notifier, required super.child});
}
