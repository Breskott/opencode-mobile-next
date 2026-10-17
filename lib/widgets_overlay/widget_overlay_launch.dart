/// The bound launch map native hands the floating host. Routing identity is
/// read-only and never shown; only the route, the steer behaviour and the
/// saved style matter to the screens.
class WidgetOverlayLaunch {
  const WidgetOverlayLaunch({
    required this.route,
    this.steerMode = 'unknown',
    this.styleBackground = 'solid',
    this.styleAccent = 'wallpaper',
  });

  final String route;

  /// `steer`, `afterReply`, `restart` or `unknown`.
  final String steerMode;
  final String styleBackground;
  final String styleAccent;

  static const backgrounds = ['solid', 'tinted', 'transparent'];
  static const accents = ['wallpaper', 'app', 'green', 'teal', 'blue', 'amber'];

  factory WidgetOverlayLaunch.fromPlatform(Map<String, dynamic> args) {
    String text(Object? v, String fallback) => v is String ? v : fallback;
    final style = args['style'];
    final map = style is Map ? style : const <Object?, Object?>{};
    final background = text(map['background'], 'solid');
    final accent = text(map['accent'], 'wallpaper');
    final mode = text(args['steerMode'], 'unknown');
    return WidgetOverlayLaunch(
      route: text(args['route'], ''),
      steerMode: const {'steer', 'afterReply', 'restart'}.contains(mode)
          ? mode
          : 'unknown',
      styleBackground: backgrounds.contains(background) ? background : 'solid',
      styleAccent: accents.contains(accent) ? accent : 'wallpaper',
    );
  }
}
