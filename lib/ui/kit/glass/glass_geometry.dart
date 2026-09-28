import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Where a piece of glass draws, which may differ from its layout box while
/// it moves (the owner's "Fluid glass" sample, visual language §6):
///
/// - pressed glass swells a few dp past its box and brightens ([press]);
/// - flowing glass follows its box's new size from the old one ([flow]).
///
/// Only the drawn shape moves: the content inside is laid out once and never
/// scaled, so labels stay on the pixel grid (crisp) and nothing reflows. The
/// clip, the fill, the rim and the liquid shader all read the one shape from
/// here, and repaint (never rebuild or relayout) when it changes.
class GlassGeometry extends ChangeNotifier {
  /// How far pressed glass swells past each side, as a share of its width
  /// and height, and never more than [swellMax] horizontally or half that
  /// vertically (logical pixels).
  static const double swellShare = .035;
  static const double swellMax = 4;

  double _press = 0;

  /// 0 at rest, about 1 under a finger; a spring may overshoot either way.
  double get press => _press;
  set press(double value) {
    if (value == _press) return;
    _press = value;
    notifyListeners();
  }

  /// How bright the press makes the glass, 0–1.
  double get glow => _press.clamp(0.0, 1.0);

  Rect? _flowFrom;
  double _flow = 1;

  /// Where the glass started flowing from, in its current box's
  /// coordinates; null when at rest.
  Rect? get flowFrom => _flow >= 1 ? null : _flowFrom;

  /// 0 at [flowFrom], 1 at the box.
  double get flow => _flow;
  set flow(double value) {
    if (value == _flow) return;
    _flow = value;
    notifyListeners();
  }

  /// Starts a flow from [from] (the box's coordinates) at 0.
  void startFlow(Rect from) {
    _flowFrom = from;
    _flow = 0;
    notifyListeners();
  }

  /// Ends any flow and any press at once: the drawn shape is the box.
  void settle() {
    if (_press == 0 && _flow >= 1) return;
    _press = 0;
    _flow = 1;
    _flowFrom = null;
    notifyListeners();
  }

  /// Whether the drawn shape is exactly the layout box.
  bool get atRest => _press == 0 && _flow >= 1;

  /// The drawn rectangle for a layout box of [size], in the box's
  /// coordinates.
  Rect rectFor(Size size) {
    var rect = Offset.zero & size;
    final from = _flowFrom;
    if (from != null && _flow < 1) rect = Rect.lerp(from, rect, _flow)!;
    return swell(rect, _press);
  }

  /// [rect] swollen by [press] (see [swellShare]).
  static Rect swell(Rect rect, double press) {
    if (press == 0) return rect;
    final dx = math.min(rect.width * swellShare, swellMax) * press;
    final dy = math.min(rect.height * swellShare, swellMax / 2) * press;
    return Rect.fromLTRB(
      rect.left - dx,
      rect.top - dy,
      rect.right + dx,
      rect.bottom + dy,
    );
  }

  /// [radius] on [rect], corners no larger than the rectangle allows.
  static RRect rrect(BorderRadius radius, Rect rect) =>
      radius.toRRect(rect).scaleRadii();
}
