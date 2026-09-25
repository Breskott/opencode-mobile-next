import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../kit_effects.dart';
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
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.shadow = true,
  });

  final Widget child;

  /// The glass's corners. The shader bends with the largest corner radius;
  /// the clip follows each corner exactly.
  final BorderRadius borderRadius;

  /// A soft drop shadow under translucent glass (never when solid).
  final bool shadow;

  /// Neutral ink stays readable even when contrasting content crosses behind
  /// the translucent material; muted palette roles are not sufficient here.
  static Color foregroundColor(ThemeData theme) =>
      theme.brightness == Brightness.dark ? Colors.white : Colors.black;

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
    final scheme = theme.colorScheme;
    final look = lookOf(context);
    final solid = look == KitGlassLook.solid;
    final dark = theme.brightness == Brightness.dark;
    final tint = Color.alphaBlend(
      scheme.primary.withValues(alpha: dark ? .035 : .018),
      scheme.surfaceContainerLow,
    );

    // The tint is what keeps the dock's labels readable over any content
    // (test/glass_surface_test.dart checks 4.5:1 over 125 backdrops). Liquid
    // glass lays the same tint in its shader, full over the middle where the
    // labels are and thinner across the bending edge.
    final fill = tint.withValues(alpha: dark ? .78 : .72);
    final material = DecoratedBox(
      decoration: BoxDecoration(
        color: switch (look) {
          KitGlassLook.solid => scheme.surfaceContainerHigh,
          KitGlassLook.frosted => fill,
          KitGlassLook.liquid => null,
        },
        borderRadius: borderRadius,
        border: Border.all(
          color: solid
              ? scheme.outline
              : scheme.onSurface.withValues(
                  // The shader draws its own rim of light; the hairline
                  // stays only to hold the edge on a light backdrop.
                  alpha: look == KitGlassLook.liquid
                      ? (dark ? .08 : .10)
                      : (dark ? .16 : .12),
                ),
        ),
      ),
      child: child,
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
        radius: _largestRadius,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        tint: fill,
        rim: dark ? .7 : 1,
        backdropKey: backdropKey,
        child: material,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: solid || !shadow
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .18 : .06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: glass),
    );
  }

  double get _largestRadius => [
    borderRadius.topLeft.x,
    borderRadius.topRight.x,
    borderRadius.bottomLeft.x,
    borderRadius.bottomRight.x,
  ].reduce((a, b) => a > b ? a : b);
}
