import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import 'kit_icon_button.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// docs/ux-system/kit-api/KitImage.md: unbounded constraints (no [KitImage]
/// width/height and no bounded incoming constraint) cap decoding at this
/// many device px on the longer side, so an unconstrained huge source never
/// decodes at its full native resolution.
const int _kitImageUnboundedCap = 4096;

/// Where a [KitImage] or [KitAvatar]'s pixels come from. There is never a
/// raw URL string: a network image arrives as an [ImageProvider] built by a
/// service that authored its URL (the favicon service) or that fetches
/// through the gateway (attachments) — AGENTS.md's link rules, SEC-1.
sealed class KitImageSource {
  const factory KitImageSource.memory(Uint8List bytes) = _MemorySource;
  const factory KitImageSource.asset(String name) = _AssetSource;
  const factory KitImageSource.provider(ImageProvider provider) =
      _ProviderSource;
}

class _MemorySource implements KitImageSource {
  const _MemorySource(this.bytes);
  final Uint8List bytes;
}

class _AssetSource implements KitImageSource {
  const _AssetSource(this.name);
  final String name;
}

class _ProviderSource implements KitImageSource {
  const _ProviderSource(this.provider);
  final ImageProvider provider;
}

ImageProvider _providerOf(KitImageSource source) => switch (source) {
  _MemorySource(:final bytes) => MemoryImage(bytes),
  _AssetSource(:final name) => AssetImage(name),
  _ProviderSource(:final provider) => provider,
};

/// The decode target for a source laid out in a box of [boxWidth] by
/// [boxHeight] logical px (either may be null when that axis is
/// unbounded), at [dpr] device pixels per logical px (KitImage.md
/// "Decode size").
ImageProvider _decodeProvider(
  ImageProvider base,
  double? boxWidth,
  double? boxHeight,
  double dpr,
) {
  if (boxWidth != null) {
    return ResizeImage.resizeIfNeeded((boxWidth * dpr).round(), null, base);
  }
  if (boxHeight != null) {
    return ResizeImage.resizeIfNeeded(null, (boxHeight * dpr).round(), base);
  }
  return ResizeImage(
    base,
    width: _kitImageUnboundedCap,
    height: _kitImageUnboundedCap,
    policy: ResizeImagePolicy.fit,
  );
}

/// How a [KitImage] fills its box.
enum KitImageFit { contain, cover }

/// Draws a raster image sharply (docs/ux-system/kit-api/KitImage.md):
/// decoded at the device pixel ratio for its laid-out size, filtered at
/// [FilterQuality.high], clipped to a token [KitShape], with honest loading
/// and failure states.
///
/// States: loading, error.
class KitImage extends StatelessWidget {
  /// [semanticsLabel] is required and may be null, so every call site
  /// decides between a named image and a decorative one.
  const KitImage({
    super.key,
    required this.source,
    required this.semanticsLabel,
    this.fit = KitImageFit.contain,
    this.shape = KitShape.square,
    this.width,
    this.height,
    this.fallback,
    this.imageKey,
  });

  final KitImageSource source;
  final String? semanticsLabel;
  final KitImageFit fit;

  /// Clips the image and its states; resolved through [KitTokens.shapeOf].
  final KitShape shape;

  /// The layout size; null takes the incoming constraints.
  final double? width;
  final double? height;

  /// Shown instead of the failure state (for example, an avatar's
  /// initials); when null the failure state draws its own notice.
  final Widget? fallback;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final shapeBorder = tokens.shapeOf(shape);
    final content = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tokens.roles.surface2,
          shape: shapeBorder,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shapeBorder),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final boxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : null;
              final boxHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null;
              final provider = _decodeProvider(
                _providerOf(source),
                boxWidth,
                boxHeight,
                dpr,
              );
              final extent = boxWidth ?? double.infinity;
              return Image(
                key: imageKey,
                image: provider,
                fit: fit == KitImageFit.cover ? BoxFit.cover : BoxFit.contain,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.high,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  // Flutter's own Image state keeps the previous frame's
                  // pixels visible (gaplessPlayback) while a new source
                  // loads, so `child` already shows the old frame here —
                  // this only adds the loaded-frame cross-fade (MOT-2: no
                  // fade-scale).
                  if (frame == null ||
                      wasSynchronouslyLoaded ||
                      KitMotion.reduced(context)) {
                    return child;
                  }
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: KitMotion.quick,
                    curve: KitMotion.enter,
                    child: child,
                    builder: (context, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                  );
                },
                errorBuilder: (context, error, stack) =>
                    fallback ??
                    _KitImageFailure(tokens: tokens, wide: extent >= 120),
              );
            },
          ),
        ),
      ),
    );
    final label = semanticsLabel;
    if (label == null) return content;
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: content,
    );
  }
}

class _KitImageFailure extends StatelessWidget {
  const _KitImageFailure({required this.tokens, required this.wide});

  final KitTokens tokens;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return ColoredBox(
      color: tokens.roles.surface2,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIconography.imageBroken,
              size: 20,
              color: tokens.roles.text2,
            ),
            if (wide) ...[
              SizedBox(height: tokens.space1),
              Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.space2,
                ),
                child: KitText(
                  l10n.kitImageUnavailable,
                  role: KitTextRole.secondary,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// [KitAvatar]'s fixed sizes (KitImage.md): [tile] is
/// [KitTokens.iconTileSize] (30), [mark] is [KitTokens.markSize] (44).
enum KitAvatarSize { tile, mark }

/// The one identity mark (docs/ux-system/kit-api/KitImage.md): an image or
/// icon when given, otherwise the initials of [name] on `surface3`, always
/// named, never coloured by identity (STATE-9).
///
/// States: loading, error.
///
/// Both fall back to the initials, so the slot is never empty.
class KitAvatar extends StatelessWidget {
  const KitAvatar({
    super.key,
    required this.name,
    this.image,
    this.icon,
    this.size = KitAvatarSize.tile,
    this.decorative = false,
  });

  /// Always the semantic label, whatever is drawn.
  final String name;

  /// Falls back to the initials while loading and on failure.
  final KitImageSource? image;

  /// An [AppIconography] glyph instead of initials (a server, the phone).
  final IconData? icon;
  final KitAvatarSize size;

  /// True when the row beside it already says [name].
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final diameter = size == KitAvatarSize.tile
        ? tokens.iconTileSize
        : tokens.markSize;
    final role = size == KitAvatarSize.tile
        ? KitTextRole.label
        : KitTextRole.headline;
    final source = image;
    final identity = icon != null
        ? Icon(icon, size: 20, color: tokens.roles.text1)
        : MediaQuery.withClampedTextScaling(
            maxScaleFactor: KitTokens.monogramMaxTextScale,
            child: KitText(
              _avatarInitials(name),
              role: role,
              tone: KitTextTone.primary,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          );
    final content = ClipOval(
      child: ColoredBox(
        color: tokens.roles.surface3,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              identity,
              if (source != null)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      final boxWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : diameter;
                      final provider = _decodeProvider(
                        _providerOf(source),
                        boxWidth,
                        null,
                        dpr,
                      );
                      return Image(
                        image: provider,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        filterQuality: FilterQuality.high,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                              if (frame == null) {
                                // Loading: transparent, so the identity mark
                                // beneath keeps the slot from ever reading
                                // empty.
                                return const SizedBox.shrink();
                              }
                              if (wasSynchronouslyLoaded ||
                                  KitMotion.reduced(context)) {
                                return child;
                              }
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: KitMotion.quick,
                                curve: KitMotion.enter,
                                child: child,
                                builder: (context, opacity, child) =>
                                    Opacity(opacity: opacity, child: child),
                              );
                            },
                        errorBuilder: (context, error, stack) =>
                            const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (decorative) return ExcludeSemantics(child: content);
    return Semantics(
      image: true,
      label: name,
      excludeSemantics: true,
      child: content,
    );
  }
}

/// The first grapheme of [name]'s first two words, folded to upper case —
/// a no-op for a script without case (Arabic, CJK), so this one rule gives
/// both KitImage.md behaviours: "upper-cased where the script has case"
/// and "Arabic initials use the first grapheme of each word, without
/// case".
String _avatarInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2);
  final buffer = StringBuffer();
  for (final word in words) {
    final chars = word.characters;
    if (chars.isEmpty) continue;
    buffer.write(chars.first.toUpperCase());
  }
  return buffer.toString();
}

/// What [KitZoom] does with a child smaller, or larger, than its viewport.
enum KitZoomMode {
  /// The child fits the view at 1×; zoom in to [KitZoom.maxScale]; pan only
  /// while zoomed (images, pages).
  fit,

  /// The child is larger than the view; pan freely within it, zoom out to
  /// fit (the work graph).
  canvas,
}

/// Drives a [KitZoom] from its host (the work graph's Fit on open and its
/// keyboard zoom). [value] is the current transform, for tests.
class KitZoomController extends ChangeNotifier {
  KitZoomController({TransformationController? transformation})
    : transformation = transformation ?? TransformationController(),
      _ownsTransformation = transformation == null {
    this.transformation.addListener(notifyListeners);
  }

  /// Wraps a host's controller when it has one.
  final TransformationController transformation;
  final bool _ownsTransformation;
  _KitZoomState? _state;

  Matrix4 get value => transformation.value;

  void _attach(_KitZoomState state) => _state = state;

  void _detach(_KitZoomState state) {
    if (identical(_state, state)) _state = null;
  }

  /// The start view: 1× in fit mode; the whole child fitted in canvas
  /// mode.
  void reset() {
    final state = _state;
    if (state == null) {
      transformation.value = Matrix4.identity();
    } else {
      state.resetView();
    }
  }

  void zoomIn() => _step(true);

  void zoomOut() => _step(false);

  void _step(bool inward) {
    final state = _state;
    if (state != null) {
      state.stepZoom(inward);
      return;
    }
    final current = transformation.value.getMaxScaleOnAxis();
    final target = (current * (inward ? 1.5 : 1 / 1.5)).clamp(
      0.2,
      KitZoom.maxScale,
    );
    transformation.value = Matrix4.identity()
      ..scaleByDouble(target, target, 1, 1);
  }

  @override
  void dispose() {
    transformation.removeListener(notifyListeners);
    if (_ownsTransformation) transformation.dispose();
    super.dispose();
  }
}

/// The one pinch, pan and zoom viewer (docs/ux-system/kit-api/KitImage.md),
/// with visible zoom controls and keyboard zoom. Replaces
/// [InteractiveViewer] at every call site.
///
/// States: none — a viewer shows what [child] gives it.
class KitZoom extends StatefulWidget {
  const KitZoom({
    super.key,
    required this.child,
    required this.label,
    this.mode = KitZoomMode.fit,
    this.controls = true,
    this.resetKey,
    this.controller,
    this.zoomKey,
    this.resetControlKey,
  });

  final Widget child;

  /// What is being viewed: "Screenshot.png", "Work graph".
  final String label;
  final KitZoomMode mode;

  /// The visible twin of pinch: zoom out, reset ("Fit to screen" in canvas
  /// mode), zoom in (A11Y-5).
  final bool controls;

  /// A change resets to the start view (a new page, a new file).
  final Object? resetKey;
  final KitZoomController? controller;
  final Key? zoomKey;

  /// The reset / Fit control (the work graph keeps team-work-graph-fit).
  final Key? resetControlKey;

  /// Behaviour constants, not look tokens.
  static const double maxScale = 5;
  static const double minScale = 0.2;

  @override
  State<KitZoom> createState() => _KitZoomState();
}

class _KitZoomState extends State<KitZoom> with SingleTickerProviderStateMixin {
  static const double _zoomStep = 1.5;
  static const double _doubleTapScale = 2;
  static const double _epsilon = 0.01;
  static const double _panStep = 32;

  final GlobalKey _viewportKey = GlobalKey(debugLabel: 'kit-zoom-viewport');
  final GlobalKey _childKey = GlobalKey(debugLabel: 'kit-zoom-child');
  final FocusNode _focusNode = FocusNode(debugLabel: 'kit-zoom');
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: KitMotion.standard,
  );

  KitZoomController? _owned;
  KitZoomController get _controller =>
      widget.controller ?? (_owned ??= KitZoomController());
  TransformationController get _t => _controller.transformation;

  Animation<Matrix4>? _matrixAnim;
  double _fittedScale = 1;
  Offset? _doubleTapPosition;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller._attach(this);
    _t.addListener(_onTransformChanged);
    _anim.addListener(_onAnimTick);
    if (widget.mode == KitZoomMode.canvas) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCanvas());
    }
  }

  @override
  void didUpdateWidget(KitZoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      (oldWidget.controller ?? _owned)?._detach(this);
      oldWidget.controller?.transformation.removeListener(_onTransformChanged);
      if (oldWidget.controller == null) {
        _owned?.dispose();
        _owned = null;
      }
      _controller._attach(this);
      _t.addListener(_onTransformChanged);
    }
    if (widget.resetKey != oldWidget.resetKey) {
      if (widget.mode == KitZoomMode.canvas) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitCanvas());
      } else {
        resetView();
      }
    }
  }

  @override
  void dispose() {
    _controller._detach(this);
    _t.removeListener(_onTransformChanged);
    _anim.removeListener(_onAnimTick);
    _anim.dispose();
    _owned?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (mounted) setState(() {});
  }

  void _onAnimTick() {
    final matrix = _matrixAnim?.value;
    if (matrix != null) _t.value = matrix;
  }

  double get _scale => _t.value.getMaxScaleOnAxis();
  double get _restScale =>
      widget.mode == KitZoomMode.canvas ? _fittedScale : 1.0;
  bool get _atRest => (_scale - _restScale).abs() < _epsilon;
  bool get _atMax => _scale >= KitZoom.maxScale - _epsilon;
  bool get _canZoomOut => widget.mode == KitZoomMode.canvas
      ? _scale > KitZoom.minScale + _epsilon
      : !_atRest;

  void _fitCanvas() {
    if (!mounted) return;
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final childBox = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null ||
        childBox == null ||
        !viewportBox.hasSize ||
        !childBox.hasSize) {
      return;
    }
    final matrix = _canvasFitMatrix(viewportBox.size, childBox.size);
    if (matrix != null) {
      setState(() => _t.value = matrix);
    }
  }

  Matrix4? _canvasFitMatrix(Size viewport, Size child) {
    if (child.width <= 0 || child.height <= 0) return null;
    final scale = math
        .min(viewport.width / child.width, viewport.height / child.height)
        .clamp(KitZoom.minScale, 1.0);
    _fittedScale = scale;
    final dx = (viewport.width - child.width * scale) / 2;
    final dy = (viewport.height - child.height * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Keeps the scene point under viewport point [p] fixed while applying a
  /// relative zoom of [factor] to [current] (clamped to this mode's
  /// range).
  Matrix4 _zoomedAt(Matrix4 current, Offset p, double factor) {
    final currentScale = current.getMaxScaleOnAxis();
    final floor = widget.mode == KitZoomMode.canvas ? KitZoom.minScale : 1.0;
    final targetScale = (currentScale * factor).clamp(floor, KitZoom.maxScale);
    final applied = targetScale / currentScale;
    if ((applied - 1).abs() < 1e-9) return current.clone();
    final inverse = Matrix4.identity()..copyInverse(current);
    final scene = MatrixUtils.transformPoint(inverse, p);
    return current.clone()
      ..translateByDouble(scene.dx, scene.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  void _animateTo(Matrix4 target) {
    if (KitMotion.reduced(context)) {
      setState(() => _t.value = target);
      return;
    }
    _matrixAnim = Matrix4Tween(
      begin: _t.value,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: KitMotion.enter));
    _anim.forward(from: 0);
  }

  void resetView() {
    final target = widget.mode == KitZoomMode.canvas
        ? (_canvasFitMatrix(
                _viewportKey.currentContext?.size ?? _viewportSize,
                _childKey.currentContext?.size ?? Size.zero,
              ) ??
              Matrix4.identity())
        : Matrix4.identity();
    _animateTo(target);
  }

  void stepZoom(bool inward) {
    final center = _viewportSize.isEmpty
        ? Offset.zero
        : Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    _animateTo(_zoomedAt(_t.value, center, inward ? _zoomStep : 1 / _zoomStep));
  }

  void _relativeZoomAt(Offset point, double factor) {
    setState(() => _t.value = _zoomedAt(_t.value, point, factor));
  }

  void _panBy(Offset delta) {
    if (_atRest) return;
    setState(
      () =>
          _t.value = _t.value.clone()
            ..translateByDouble(delta.dx, delta.dy, 0, 1),
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    final p = _doubleTapPosition;
    if (p == null) return;
    if (_atRest) {
      _animateTo(_zoomedAt(_t.value, p, _doubleTapScale));
    } else {
      resetView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    Widget viewer = LayoutBuilder(
      key: _viewportKey,
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return InteractiveViewer(
          key: widget.zoomKey,
          transformationController: _t,
          constrained: widget.mode == KitZoomMode.fit,
          boundaryMargin: widget.mode == KitZoomMode.canvas
              ? const EdgeInsets.all(double.infinity)
              : EdgeInsets.zero,
          minScale: widget.mode == KitZoomMode.canvas ? KitZoom.minScale : 1.0,
          maxScale: KitZoom.maxScale,
          child: KeyedSubtree(key: _childKey, child: widget.child),
        );
      },
    );
    viewer = GestureDetector(
      onTap: _focusNode.requestFocus,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: viewer,
    );
    final finePointer = KitLayout.finePointer(context);
    if (finePointer) {
      viewer = Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent &&
              (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed)) {
            final factor = event.scrollDelta.dy < 0 ? _zoomStep : 1 / _zoomStep;
            _relativeZoomAt(event.localPosition, factor);
          }
        },
        child: MouseRegion(
          cursor: _atRest ? MouseCursor.defer : SystemMouseCursors.grab,
          child: viewer,
        ),
      );
    }
    viewer = Focus(focusNode: _focusNode, child: viewer);
    if (finePointer) {
      viewer = CallbackShortcuts(
        bindings: {
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.equal,
          ): () =>
              stepZoom(true),
          LogicalKeySet(
            LogicalKeyboardKey.meta,
            LogicalKeyboardKey.equal,
          ): () =>
              stepZoom(true),
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.minus,
          ): () =>
              stepZoom(false),
          LogicalKeySet(
            LogicalKeyboardKey.meta,
            LogicalKeyboardKey.minus,
          ): () =>
              stepZoom(false),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit0):
              resetView,
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit0):
              resetView,
          LogicalKeySet(LogicalKeyboardKey.arrowUp): () =>
              _panBy(const Offset(0, -_panStep)),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): () =>
              _panBy(const Offset(0, _panStep)),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): () =>
              _panBy(const Offset(-_panStep, 0)),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): () =>
              _panBy(const Offset(_panStep, 0)),
        },
        child: viewer,
      );
    }
    final l10n = _l10n(context);
    final localeName = Localizations.localeOf(context).toString();
    final percent = NumberFormat.decimalPattern(
      localeName,
    ).format((_scale * 100).round());
    viewer = Semantics(
      label: widget.label,
      value: l10n.kitZoomLevel(percent),
      child: Semantics(
        customSemanticsActions: {
          if (!_atMax)
            CustomSemanticsAction(label: l10n.kitZoomIn): () => stepZoom(true),
          if (_canZoomOut)
            CustomSemanticsAction(label: l10n.kitZoomOut): () =>
                stepZoom(false),
          CustomSemanticsAction(label: l10n.kitZoomReset): resetView,
        },
        child: viewer,
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: viewer),
        if (widget.controls)
          PositionedDirectional(
            bottom: tokens.space4,
            start: 0,
            end: 0,
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: tokens.roles.surface2,
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: tokens.space2,
                    vertical: tokens.space1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KitIconButton(
                        icon: AppIconography.collapse,
                        label: l10n.kitZoomOut,
                        onPressed: _canZoomOut ? () => stepZoom(false) : null,
                      ),
                      SizedBox(width: tokens.space2),
                      KitIconButton(
                        key: widget.resetControlKey,
                        icon: AppIconography.retry,
                        label: widget.mode == KitZoomMode.canvas
                            ? l10n.kitZoomFit
                            : (_atRest
                                  ? l10n.kitZoomAtStart
                                  : l10n.kitZoomReset),
                        onPressed:
                            (widget.mode == KitZoomMode.canvas || !_atRest)
                            ? resetView
                            : null,
                      ),
                      SizedBox(width: tokens.space2),
                      KitIconButton(
                        icon: AppIconography.expand,
                        label: _atMax ? l10n.kitZoomAtMax : l10n.kitZoomIn,
                        onPressed: _atMax ? null : () => stepZoom(true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
