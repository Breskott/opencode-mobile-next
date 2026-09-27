import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme_roles.dart';
import '../kit_effects.dart';
import '../kit_tokens.dart';
import 'liquid_glass_filter.dart';

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
/// this phone can use it.
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
  static void ensureLoaded() {
    if (_loading != null || !supported) return;
    _loading = ui.FragmentProgram.fromAsset(asset).then(
      (loaded) => program.value = loaded,
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

  /// Tests and captures only: forget the shader and any override.
  static void debugReset() {
    _loading = null;
    program.value = null;
    debugSupportedOverride = null;
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
/// Several glass surfaces on one screen should share one read of the
/// backdrop: put a [BackdropGroup] around the screen (its `Scaffold`) and
/// each [KitGlass] under it joins the group.
class KitGlass extends StatelessWidget {
  const KitGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.shadow = true,
    this.dim = true,
  });

  final Widget child;

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

  @override
  Widget build(BuildContext context) {
    // Rebuilds once, when the shader finishes loading.
    return ValueListenableBuilder<ui.FragmentProgram?>(
      valueListenable: KitGlassShader.program,
      builder: (context, program, _) => _build(context, program),
    );
  }

  Widget _build(BuildContext context, ui.FragmentProgram? program) {
    final theme = Theme.of(context);
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final borderRadius =
        this.borderRadius ?? BorderRadius.circular(tokens.navRadius);
    final look = lookOf(context);
    final solid = look == KitGlassLook.solid;
    final dark = theme.brightness == Brightness.dark;
    // The glass is `surface2` at 82 % (visual language §4), deeper where it
    // holds words (§6). The fill is what keeps the dock's labels readable
    // over any content (test/glass_surface_test.dart checks 4.5:1 over 125
    // backdrops). Liquid glass lays the same fill in its shader, full over
    // the middle where the labels are and thinner across the bending edge.
    final fill = roles.surface2.withValues(alpha: dim ? .88 : .82);
    // Glass turned off: a solid surface2 at 94 %; the system's high
    // contrast, accessible navigation or remove animations: opaque.
    final solidFill = reduceEffects(context)
        ? roles.surface2
        : roles.surface2.withValues(alpha: .94);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final material = DecoratedBox(
      decoration: BoxDecoration(
        color: switch (look) {
          KitGlassLook.solid => solidFill,
          KitGlassLook.frosted => fill,
          KitGlassLook.liquid => null,
        },
        borderRadius: borderRadius,
        border: solid
            ? Border.all(
                color: roles.hairline,
                width: KitTokens.hairlineWidth(context),
              )
            : null,
      ),
      // The rim (§7, LOOK-21): one physical pixel, the `glassRimLight` role
      // along the top edge and `glassRimDark` along the bottom, never a
      // soft glow.
      child: solid
          ? child
          : CustomPaint(
              foregroundPainter: _GlassRimPainter(
                radius: borderRadius,
                devicePixelRatio: dpr,
                light: roles.glassRimLight,
                dark: roles.glassRimDark,
              ),
              child: child,
            ),
    );

    final backdropKey = BackdropGroup.of(context)?.backdropKey;
    final Widget glass = switch (look) {
      KitGlassLook.solid => material,
      KitGlassLook.frosted => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        backdropGroupKey: backdropKey,
        child: material,
      ),
      KitGlassLook.liquid => LiquidGlassFilter(
        program: program!,
        radius: _largestRadius(borderRadius),
        devicePixelRatio: dpr,
        tint: fill,
        rim: dark ? .7 : 1,
        backdropKey: backdropKey,
        child: material,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: solid || !shadow ? const [] : tokens.glassShadows,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: glass),
    );
  }

  static double _largestRadius(BorderRadius borderRadius) => [
    borderRadius.topLeft.x,
    borderRadius.topRight.x,
    borderRadius.bottomLeft.x,
    borderRadius.bottomRight.x,
  ].reduce((a, b) => a > b ? a : b);
}

/// The glass's rim: a stroke of exactly one physical pixel on the rounded
/// edge, snapped to the pixel grid, light at the top fading out by the
/// middle and darker at the bottom.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({
    required this.radius,
    required this.devicePixelRatio,
    required this.light,
    required this.dark,
  });

  final BorderRadius radius;
  final double devicePixelRatio;
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final px = 1 / devicePixelRatio;
    final rect = (Offset.zero & size).deflate(px / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          light,
          light.withValues(alpha: 0),
          dark.withValues(alpha: 0),
          dark,
        ],
        stops: const [0, .35, .65, 1],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect), paint);
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) =>
      old.radius != radius ||
      old.devicePixelRatio != devicePixelRatio ||
      old.light != light ||
      old.dark != dark;
}
