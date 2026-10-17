import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'kit_effects.dart';
import 'kit_motion.dart';
import 'kit_tokens.dart';
import 'live_background/kit_live_styles.dart';

export 'live_background/kit_live_styles.dart';

/// The ground of a page with a calm, slowly moving look on it (the person's
/// chosen [KitLiveStyle]; Settings › Appearance › Live background), the same
/// family as the composer's running glow: it brightens while a reply runs.
///
/// Not glass: nothing is blurred and nothing is see-through; a card, row or
/// sheet laid on top keeps its own solid surface. A look never exceeds
/// [KitLivePalette.ceiling] so text keeps its contrast
/// (test/kit_live_background_test.dart checks every look).
///
/// Cost: one [Ticker] per visible page, painting every display frame
/// into a [RepaintBoundary]. It stops (a still frame) when the person
/// turned Live background off, when motion is reduced, calm or off
/// ([KitMotion.loopsIn]), when the app is not resumed, and under
/// `flutter test` (where [KitMotion.loops] is false and only the flat ground
/// is painted unless [paintWithoutLoops] is set).
///
/// States: none — it draws a ground; every look is always ready.
class KitLiveBackground extends StatefulWidget {
  const KitLiveBackground({
    super.key,
    required this.child,
    this.style,
    this.strength,
    this.ignoreSetting = false,
    this.replyRunning,
  });

  /// Null: the person's chosen look ([KitEffects.liveStyle]).
  final KitLiveStyle? style;

  /// Null follows the person's Intensity choice; 1 is the shipping strength.
  final double? strength;

  /// A picker tile or the full-screen preview shows its look whatever the
  /// Live background switch says.
  final bool ignoreSetting;

  /// A reply is running (a preview's own switch); null follows the app's
  /// composers ([KitLiveBackground.running]).
  final ValueListenable<bool>? replyRunning;

  /// How long the fields take to brighten or settle.
  static const Duration brighten = Duration(milliseconds: 600);

  /// Tests only: paint the (still) look although [KitMotion.loops] is off,
  /// for evidence images. Goldens leave it false and show the flat ground.
  static bool paintWithoutLoops = false;

  /// Tests only: hold the clock at this second (evidence frames).
  static double? frozenSeconds;

  /// Replies running anywhere visible. The composer's glowing border adds
  /// one while it is active; the look brightens while this is above zero.
  static final ValueNotifier<int> running = ValueNotifier<int>(0);

  /// The colours a look may use under [tokens].
  static KitLivePalette paletteOf(KitTokens tokens) {
    final r = tokens.roles;
    final dark = r.brightness == Brightness.dark;
    return KitLivePalette(
      ground: r.ground,
      ink: r.text1,
      green: r.accent,
      teal: Color.lerp(r.accent, r.codeKeyword, .35)!,
      blue: r.codeKeyword,
      glow: r.accent,
      dark: dark,
    );
  }

  final Widget child;

  @override
  State<KitLiveBackground> createState() => _KitLiveBackgroundState();
}

final Stopwatch _clock = Stopwatch()..start();

class _KitLiveBackgroundState extends State<KitLiveBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final KitLiveMemory _memory = KitLiveMemory();
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: KitLiveBackground.brighten,
  );
  AppLifecycleState? _lifecycle = WidgetsBinding.instance.lifecycleState;
  bool _animate = false;
  bool _ready = false;
  KitLiveStyle? _warmed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KitLiveBackground.running.addListener(_runningChanged);
    widget.replyRunning?.addListener(_runningChanged);
    _lift.value = _isRunning ? 1 : 0;
    _time.value = _seconds;
  }

  bool get _isRunning =>
      widget.replyRunning?.value ?? KitLiveBackground.running.value > 0;

  double get _seconds =>
      KitLiveBackground.frozenSeconds ?? _clock.elapsedMicroseconds / 1e6;

  void _runningChanged() {
    if (!_animate) {
      _lift.value = _isRunning ? 1 : 0;
      return;
    }
    unawaited(_isRunning ? _lift.forward() : _lift.reverse());
  }

  void _tick(Duration elapsed) {
    // Every vsync: the display's own refresh rate (60, 90, 120 Hz). Styles
    // keep a frame cheap (cached geometry, a coarse field upscaled by the GPU).
    _time.value = _seconds;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KitLiveBackground old) {
    super.didUpdateWidget(old);
    if (old.replyRunning != widget.replyRunning) {
      old.replyRunning?.removeListener(_runningChanged);
      widget.replyRunning?.addListener(_runningChanged);
      _runningChanged();
    }
    _sync();
  }

  KitLiveStyle get _style =>
      widget.style ?? kitLiveStyleById(KitEffects.read(context).liveStyle);

  /// Starts or stops the ticker to match the setting, motion, lifecycle, and
  /// loads the look.
  void _sync() {
    final effects = KitEffects.of(context);
    final should =
        (effects.liveBackground || widget.ignoreSetting) &&
        KitMotion.loopsIn(context) &&
        (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);
    _animate = should;
    if (should && !_ticker.isActive) {
      _ticker.start();
    } else if (!should && _ticker.isActive) {
      _ticker.stop();
    }
    if (!should) _lift.value = _isRunning ? 1 : 0;
    final style = _style;
    if (!identical(style, _warmed)) {
      _warmed = style;
      _ready = false;
      _memory.clear();
      unawaited(
        style.warmUp().then((_) {
          if (mounted && identical(_warmed, style)) {
            setState(() => _ready = true);
          }
        }),
      );
    }
  }

  /// How far the look is lifted towards the running look (tests).
  @visibleForTesting
  double get lift => _lift.value;

  /// Whether a ticker is running (tests).
  @visibleForTesting
  bool get ticking => _ticker.isActive;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KitLiveBackground.running.removeListener(_runningChanged);
    widget.replyRunning?.removeListener(_runningChanged);
    _ticker.dispose();
    _lift.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final effects = KitEffects.of(context);
    final paint =
        (effects.liveBackground || widget.ignoreSetting) &&
        _ready &&
        (KitMotion.loops || KitLiveBackground.paintWithoutLoops);
    final ground = tokens.roles.ground;
    // One shape whether or not the look is painted yet: the page above must
    // keep its state (a typed draft, a scroll position) when the look finishes
    // loading, so its place in the tree never changes.
    return ColoredBox(
      color: ground,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: !paint
                ? const SizedBox.shrink()
                : ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _StylePainter(
                          style: _style,
                          time: _time,
                          lift: _lift,
                          palette: KitLiveBackground.paletteOf(tokens),
                          memory: _memory,
                          strength:
                              widget.strength ?? effects.liveIntensity.strength,
                          still:
                              !_animate &&
                              KitLiveBackground.frozenSeconds == null,
                        ),
                      ),
                    ),
                  ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _StylePainter extends CustomPainter {
  _StylePainter({
    required this.style,
    required this.time,
    required this.lift,
    required this.palette,
    required this.memory,
    required this.strength,
    required this.still,
  }) : super(repaint: Listenable.merge([time, lift]));

  final KitLiveStyle style;
  final ValueListenable<double> time;
  final Animation<double> lift;
  final KitLivePalette palette;
  final KitLiveMemory memory;
  final double strength;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    style.paint(
      canvas,
      size,
      KitLiveFrame(
        t: still ? 0 : time.value,
        running: KitMotion.pulse.transform(lift.value),
        strength: strength,
        palette: palette,
        memory: memory,
      ),
    );
  }

  @override
  bool shouldRepaint(_StylePainter old) =>
      old.style != style ||
      old.palette.ground != palette.ground ||
      old.palette.green != palette.green ||
      old.strength != strength ||
      old.still != still;
}
