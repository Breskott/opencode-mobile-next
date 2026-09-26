// KitPageRoute — the one way to push a page (docs/ux-system/kit-api/
// KitPageRoute.md; kit-v2 §9.1 "Routes" row, §9.2; design standard §10).
import 'package:flutter/widgets.dart';

import 'kit_motion.dart';
import 'motion/kit_page_transitions.dart';

/// A pushed page with the kit's one transition (design standard §10): the
/// shared-axis fade-through of [KitPageTransitionsBuilder], whatever the
/// ambient theme's platform or `pageTransitionsTheme` says. Screens never
/// choose a transition — construct this (or, from inside a widget, call
/// [pushKitPage] / [replaceWithKitPage]) instead of `MaterialPageRoute` or
/// `PageRouteBuilder` (KIT-7 retires both from the kit-only allowlist).
///
/// Everything about the transition is fixed by the kit: [transitionDuration]
/// and [reverseTransitionDuration] are [KitMotion.standard], the route is
/// always [opaque], has no [barrierColor] or [barrierLabel] and is never
/// [barrierDismissible]. Only [maintainState], [fullscreenDialog] and
/// [allowSnapshotting] are a call site's to choose.
class KitPageRoute<T> extends PageRoute<T> {
  /// Pushes [builder] as a page. [fullscreenDialog] gives the page a Close
  /// action instead of Back (see `KitTopBar`), for a page that ends a flow
  /// rather than continuing it.
  KitPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
  });

  /// Builds the page's contents.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  static const _transitions = KitPageTransitionsBuilder();

  @override
  Duration get transitionDuration => KitMotion.standard;

  @override
  Duration get reverseTransitionDuration => KitMotion.standard;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _transitions.delegatedTransition;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _transitions.buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Pushes [builder] as a [KitPageRoute] on the nearest [Navigator] (the
/// root one, with [rootNavigator]).
Future<T?> pushKitPage<T>(
  BuildContext context,
  WidgetBuilder builder, {
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool rootNavigator = false,
}) {
  return Navigator.of(context, rootNavigator: rootNavigator).push<T>(
    KitPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    ),
  );
}

/// Replaces the current route with [builder] as a [KitPageRoute] — the
/// one-way hand-offs (setup finished → Work) that never come back with Back.
Future<T?> replaceWithKitPage<T, TO>(
  BuildContext context,
  WidgetBuilder builder, {
  RouteSettings? settings,
  TO? result,
}) {
  return Navigator.of(context).pushReplacement<T, TO>(
    KitPageRoute<T>(builder: builder, settings: settings),
    result: result,
  );
}
