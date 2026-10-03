import 'package:flutter/material.dart';

import '../../theme_roles.dart';
import '../kit_motion.dart';

/// The app's one page transition (design standard §10): Material 3's shared
/// axis along x, timed by [KitMotion].
///
/// Opening a page: the page underneath fades out in the first 30 % of
/// [KitMotion.standard] while it drifts [travel] dp back, then the new page
/// fades in while it slides the same distance into place, on
/// [KitMotion.emphasized]. Going back plays the same in reverse. The travel
/// follows the reading direction.
///
/// Short travel and a fade-through instead of a full-width slide: the two
/// pages never overlap half-visible, and only opacity and a translation
/// animate, over each route's own repaint boundary, so nothing is laid out
/// or repainted during the transition. With the system's "remove
/// animations" a new page shows at once and a closing page only fades; the
/// widget structure stays the same either way, so switching the setting
/// while a page is open never rebuilds it (a draft survives).
class KitPageTransitionsBuilder extends PageTransitionsBuilder {
  const KitPageTransitionsBuilder();

  /// How far a page travels, in dp.
  static const travel = 30.0;

  /// The share of the transition the leaving page takes to fade out.
  static const fadeOutShare = .3;

  @override
  Duration get transitionDuration => KitMotion.standard;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _covered;

  static Widget? _covered(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _KitCoveredPage(secondaryAnimation: secondaryAnimation, child: child);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _KitSharedAxisPage(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  );
}

double _share(double t, double begin, double end, Curve curve) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return curve.transform((t - begin) / (end - begin));
}

double _direction(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? -1 : 1;

/// Moves [child] by [dx] × [KitPageTransitionsBuilder.travel] and fades it,
/// both read from [animation] each frame without rebuilding [child].
class _Axis extends StatelessWidget {
  const _Axis({
    required this.animation,
    required this.opacity,
    required this.offset,
    required this.child,
  });

  final Animation<double> animation;
  final double Function(double t) opacity;
  final double Function(double t) offset;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final direction = _direction(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: opacity(t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              direction * KitPageTransitionsBuilder.travel * offset(t),
              0,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _KitSharedAxisPage extends StatelessWidget {
  const _KitSharedAxisPage({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = KitMotion.reduced(context);
    const share = KitPageTransitionsBuilder.fadeOutShare;
    return DualTransitionBuilder(
      animation: animation,
      // Arriving: waits for the page underneath to clear, then fades in
      // while it slides in from the end side.
      forwardBuilder: (context, animation, child) => _Axis(
        animation: animation,
        opacity: (t) => still ? 1 : _share(t, share, 1, KitMotion.enter),
        offset: (t) => still ? 0 : 1 - KitMotion.emphasized.transform(t),
        child: child,
      ),
      // Leaving (back): fades out first while it slides towards the end.
      reverseBuilder: (context, animation, child) => IgnorePointer(
        // Only while it is on its way out.
        ignoring: animation.status == AnimationStatus.forward,
        child: _Axis(
          animation: animation,
          opacity: (t) =>
              still ? 1 - t : 1 - _share(t, 0, share, KitMotion.exit),
          offset: (t) => still ? 0 : KitMotion.emphasized.transform(t),
          child: child,
        ),
      ),
      child: _KitCoveredPage(
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
    );
  }
}

/// The page underneath a page being opened (or closed): it fades out while
/// drifting back towards the start side, and returns the same way. While it
/// moves, the screen behind it is the page background, so the fade-through
/// never shows the window behind the app.
class _KitCoveredPage extends StatefulWidget {
  const _KitCoveredPage({required this.secondaryAnimation, this.child});

  final Animation<double> secondaryAnimation;
  final Widget? child;

  @override
  State<_KitCoveredPage> createState() => _KitCoveredPageState();
}

class _KitCoveredPageState extends State<_KitCoveredPage> {
  late Animation<double> _reversed = ReverseAnimation(
    widget.secondaryAnimation,
  );

  @override
  void initState() {
    super.initState();
    widget.secondaryAnimation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_KitCoveredPage old) {
    super.didUpdateWidget(old);
    if (old.secondaryAnimation != widget.secondaryAnimation) {
      old.secondaryAnimation.removeStatusListener(_onStatus);
      widget.secondaryAnimation.addStatusListener(_onStatus);
      _reversed = ReverseAnimation(widget.secondaryAnimation);
    }
  }

  @override
  void dispose() {
    widget.secondaryAnimation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // With reduced motion the page underneath simply stays: the page
    // above is opaque and appears (or fades) over it.
    final still = KitMotion.reduced(context);
    const share = KitPageTransitionsBuilder.fadeOutShare;
    final moving = DualTransitionBuilder(
      animation: _reversed,
      // Uncovered again (the page above closes): fades back in.
      forwardBuilder: (context, animation, child) => _Axis(
        animation: animation,
        opacity: (t) => still ? 1 : _share(t, share, 1, KitMotion.enter),
        offset: (t) => still ? 0 : -(1 - KitMotion.emphasized.transform(t)),
        child: child,
      ),
      // Covered (a page opens above): fades out first, drifting back.
      reverseBuilder: (context, animation, child) => _Axis(
        animation: animation,
        opacity: (t) => still ? 1 : 1 - _share(t, 0, share, KitMotion.exit),
        offset: (t) => still ? 0 : -KitMotion.emphasized.transform(t),
        child: child,
      ),
      child: widget.child,
    );
    final opaque = ModalRoute.opaqueOf(context) ?? true;
    if (!opaque) return moving;
    return ColoredBox(
      color: widget.secondaryAnimation.isAnimating
          ? ThemeRoles.of(context).ground
          : Colors.transparent,
      child: moving,
    );
  }
}
