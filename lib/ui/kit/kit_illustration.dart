import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_motion.dart';

/// The app's drawings (design standard §10): line art in the brand's
/// stroke — rounded caps and joins, the "open portal" mark's weight — drawn
/// in code, so it follows the theme (dark and light), scales without
/// assets, and can move.
///
/// A drawing is a [KitScene]: it paints one frame from a [KitSceneFrame]
/// (how far its entrance is, where its ambient loop is, the palette).
/// [KitIllustration] owns the time: it plays the entrance once, then, when
/// asked ([KitIllustration.ambient]) and allowed ([KitMotion.loopsIn]),
/// repeats the loop. With reduced motion it shows the finished drawing.
///
/// Scenes draw in their own design box ([KitScene.box], 120 × 120 by
/// default); the widget scales it uniformly to its width and centres it.
abstract class KitScene {
  const KitScene();

  /// The design box the scene draws in, in scene units.
  Size get box => const Size(120, 120);

  /// Paints one frame into [box]-sized scene units.
  void paint(Canvas canvas, KitSceneFrame frame);

  /// Whether this scene draws differently from [old] at the same frame
  /// (a scene with data, such as a progress, compares its fields).
  bool differs(covariant KitScene old) => old.runtimeType != runtimeType;
}

/// The colours a scene draws with: always from the theme, never literals.
@immutable
class KitPalette {
  const KitPalette({
    required this.accent,
    required this.accentSoft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.surface,
    required this.success,
    required this.warning,
    required this.failure,
    required this.progress,
  });

  factory KitPalette.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    return KitPalette(
      accent: scheme.primary,
      accentSoft: scheme.primary.withValues(alpha: .16),
      ink: scheme.onSurface,
      muted: AppTheme.mutedOf(theme),
      line: scheme.outlineVariant,
      surface: scheme.surfaceContainerHigh,
      success: AppTheme.statusColor(theme, AppStatusTone.ok),
      warning: AppTheme.statusColor(theme, AppStatusTone.attention),
      failure: AppTheme.statusColor(theme, AppStatusTone.failure),
      progress: AppTheme.statusColor(theme, AppStatusTone.progress),
    );
  }

  /// The brand colour: the one thing in a scene that matters most.
  final Color accent;

  /// The brand colour as a wash behind shapes.
  final Color accentSoft;

  /// Text colour, for the few strong outlines.
  final Color ink;

  /// Secondary outlines.
  final Color muted;

  /// Hairlines and the quietest detail.
  final Color line;

  /// Filled shapes (a phone's screen, a card).
  final Color surface;

  final Color success;
  final Color warning;
  final Color failure;
  final Color progress;

  @override
  bool operator ==(Object other) =>
      other is KitPalette &&
      other.accent == accent &&
      other.accentSoft == accentSoft &&
      other.ink == ink &&
      other.muted == muted &&
      other.line == line &&
      other.surface == surface &&
      other.success == success &&
      other.warning == warning &&
      other.failure == failure &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(
    accent,
    accentSoft,
    ink,
    muted,
    line,
    surface,
    success,
    warning,
    failure,
    progress,
  );
}

/// One frame of a scene.
@immutable
class KitSceneFrame {
  const KitSceneFrame({
    required this.entrance,
    required this.loop,
    required this.looping,
    required this.palette,
  });

  /// 0 → 1 over [KitMotion.entrance], linear; 1 when finished or reduced.
  /// Scenes stage their parts with [KitDraw.interval].
  final double entrance;

  /// 0 → 1, repeating once per loop period while [looping]; 0 otherwise.
  final double loop;

  /// Whether the ambient loop runs. A scene drawn with `looping: false` must
  /// look complete and still at `loop: 0`.
  final bool looping;

  final KitPalette palette;
}

/// Drawing helpers every scene shares, so the line weight and the way
/// things draw themselves in are the same everywhere.
abstract final class KitDraw {
  /// The standard stroke in scene units (a 120-unit box).
  static const stroke = 5.0;

  /// A thin stroke for detail.
  static const hairline = 2.5;

  static Paint pen(Color color, [double width = stroke]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = width
    ..color = color
    ..isAntiAlias = true;

  static Paint fill(Color color) => Paint()
    ..style = PaintingStyle.fill
    ..color = color
    ..isAntiAlias = true;

  /// [t] of [begin]..[end], clamped and eased: stages a part of an entrance
  /// ("the second bracket draws from 25 % to 85 %").
  static double interval(
    double t,
    double begin,
    double end, [
    Curve curve = KitMotion.enter,
  ]) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }

  /// A smooth 0 → 1 → 0 wave over one loop, shifted by [phase] (0..1).
  static double wave(double loop, [double phase = 0]) =>
      (1 - math.cos((loop + phase) * 2 * math.pi)) / 2;

  /// Draws the first [t] (0..1) of [path]'s length: a line drawing itself.
  static void partialPath(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * t;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final length = math.min(remaining, metric.length);
      canvas.drawPath(metric.extractPath(0, length), paint);
      remaining -= length;
    }
  }

  /// [color] at [opacity] of its own alpha.
  static Color fade(Color color, double opacity) =>
      color.withValues(alpha: color.a * opacity.clamp(0, 1));
}

/// Shows a [KitScene] at [width], playing its entrance once and, when
/// [ambient] and allowed, its loop (design standard §10).
///
/// Decorative by default (screen readers skip it); give [semanticLabel]
/// only when the drawing says something the text around it does not.
class KitIllustration extends StatefulWidget {
  const KitIllustration({
    super.key,
    required this.scene,
    this.width = 160,
    this.ambient = false,
    this.loopPeriod = KitMotion.breath,
    this.animateEntrance = true,
    this.semanticLabel,
  });

  final KitScene scene;
  final double width;

  /// Keep moving after the entrance: only on a screen where the person
  /// waits (connecting, installing, a team at work), never on a resting
  /// screen.
  final bool ambient;

  final Duration loopPeriod;

  /// False draws the finished drawing at once (a list rebuilt often).
  final bool animateEntrance;

  final String? semanticLabel;

  @override
  State<KitIllustration> createState() => _KitIllustrationState();
}

class _KitIllustrationState extends State<KitIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: KitMotion.entrance,
  )..addStatusListener(_entranceStatus);
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: widget.loopPeriod,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduced(context)) {
      _entrance.value = 1;
      _loop
        ..stop()
        ..value = 0;
      _started = true;
      return;
    }
    if (!_started) {
      _started = true;
      if (widget.animateEntrance) {
        _entrance.forward();
      } else {
        _entrance.value = 1;
        _syncLoop();
      }
    } else {
      _syncLoop();
    }
  }

  @override
  void didUpdateWidget(KitIllustration old) {
    super.didUpdateWidget(old);
    if (old.loopPeriod != widget.loopPeriod) {
      _loop.duration = widget.loopPeriod;
    }
    if (old.ambient != widget.ambient) _syncLoop();
  }

  void _entranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _syncLoop();
  }

  void _syncLoop() {
    final run =
        widget.ambient &&
        _entrance.isCompleted &&
        mounted &&
        KitMotion.loopsIn(context);
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run && _loop.isAnimating) {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.scene.box;
    final height = widget.width * box.height / box.width;
    final painter = CustomPaint(
      size: Size(widget.width, height),
      painter: _ScenePainter(
        scene: widget.scene,
        entrance: _entrance,
        loop: _loop,
        palette: KitPalette.of(Theme.of(context)),
      ),
    );
    final drawing = RepaintBoundary(child: painter);
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: drawing)
        : Semantics(label: label, image: true, child: drawing);
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.entrance,
    required this.loop,
    required this.palette,
  }) : super(repaint: Listenable.merge([entrance, loop]));

  final KitScene scene;
  final Animation<double> entrance;
  final AnimationController loop;
  final KitPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final box = scene.box;
    final scale = math.min(size.width / box.width, size.height / box.height);
    canvas.save();
    canvas.translate(
      (size.width - box.width * scale) / 2,
      (size.height - box.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.clipRect(ui.Offset.zero & box);
    scene.paint(
      canvas,
      KitSceneFrame(
        entrance: entrance.value,
        loop: loop.isAnimating ? loop.value : 0,
        looping: loop.isAnimating,
        palette: palette,
      ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      scene.differs(old.scene) || palette != old.palette;
}
