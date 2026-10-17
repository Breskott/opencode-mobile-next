// Measures a pumped screen against the screen standard
// (docs/ux-system/screen-standard.md). Used by standard_check_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

const phone = Size(412, 915);

/// One measured pass of one use-case.
class PassResult {
  PassResult(this.name);
  final String name;
  final overflow = <String>[];
  final cutoff = <String>[];
  final red = <String>[];
  final amber = <String>[];
  List<double> textSizes = const [];
  int mainActions = 0;
  int firstViewItems = 0;

  /// Rows in the first view that show more than [maxRowLines] lines of text.
  final longRows = <String>[];

  /// The use-case needs Widgetbook's own knobs panel, which a plain test
  /// cannot provide: nothing is measured.
  bool skipped = false;

  Map<String, Object?> toJson() => {
    'pass': name,
    'overflow': overflow,
    'cutoff': cutoff,
    'textSizes': textSizes,
    'mainActions': mainActions,
    'firstViewItems': firstViewItems,
    'longRows': longRows,
    'red': red,
    'amber': amber,
    if (skipped) 'skipped': 'needs the Widgetbook knobs panel',
  };
}

/// What the item counter counts: the kit's row and card types.
final Set<Type> itemTypes = {
  KitRow,
  KitSwitchRow,
  KitExpandRow,
  KitAgentCard,
  KitTaskCard,
  KitFeedItem,
  KitRequestCard,
};

/// The list rows: a row shows at most [maxRowLines] lines of text.
final Set<Type> rowTypes = {KitRow, KitSwitchRow, KitExpandRow, KitFeedItem};
const maxRowLines = 2;

/// How many lines a paragraph is laid out on: its text boxes, grouped by
/// the line they sit on (a box starts a new line once it begins at or below
/// the bottom of the line before it).
int _linesOf(RenderParagraph p, int length) {
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  )..sort((a, b) => a.top.compareTo(b.top));
  if (boxes.isEmpty) return 1;
  var lines = 1;
  var bottom = boxes.first.bottom;
  for (final box in boxes.skip(1)) {
    if (box.top >= bottom - 1) {
      lines++;
      bottom = box.bottom;
    } else if (box.bottom > bottom) {
      bottom = box.bottom;
    }
  }
  return lines;
}

/// Whether a paragraph that reports "exceeded max lines" really lost text:
/// laid out again with no line limit at its width, it needs more lines than
/// it may have. (The engine reports it for a right-to-left line that fits,
/// when a bidi isolate ends the text.)
bool _reallyCut(RenderParagraph p) {
  final max = p.maxLines;
  if (max == null) return true;
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    locale: p.locale,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.size.width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines > max;
}

/// Counts the lines of visible text under [root] (icons ignored).
int textLinesUnder(RenderObject root) {
  var lines = 0;
  void visit(RenderObject o) {
    if (o is RenderOffstage && o.offstage) return;
    if (o is RenderParagraph && o.hasSize && !o.size.isEmpty) {
      final text = o.text;
      final plain = text.toPlainText(includePlaceholders: false);
      final icon = text is TextSpan && _isIconSpan(text);
      if (!icon && plain.trim().isNotEmpty) {
        lines += _linesOf(o, plain.length);
      }
    }
    o.visitChildren(visit);
  }

  visit(root);
  return lines;
}

const _iconFamilies = ['Phosphor', 'MaterialIcons', 'CupertinoIcons'];

bool _isIconSpan(TextSpan span) {
  final family = span.style?.fontFamily ?? '';
  if (_iconFamilies.any(family.contains)) return true;
  final text = span.text;
  if (text != null && text.isNotEmpty) {
    final c = text.runes.first;
    if ((c >= 0xE000 && c <= 0xF8FF) || c >= 0xF0000) return true;
  }
  return false;
}

bool _visible(RenderBox box) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return false;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return rect.overlaps(Offset.zero & phone);
}

bool _redHue(Color c) {
  if (c.a < 0.4) return false;
  final hsl = HSLColor.fromColor(c);
  final hue = hsl.hue;
  return (hue >= 345 || hue <= 15) &&
      hsl.saturation > 0.5 &&
      hsl.lightness >= 0.25 &&
      hsl.lightness <= 0.75;
}

bool _amberHue(Color c) {
  if (c.a < 0.4) return false;
  final hsl = HSLColor.fromColor(c);
  return hsl.hue >= 30 &&
      hsl.hue <= 55 &&
      hsl.saturation > 0.5 &&
      hsl.lightness >= 0.25 &&
      hsl.lightness <= 0.8;
}

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

void _colour(PassResult r, Color c, String where) {
  if (_redHue(c)) r.red.add('$where ${_hex(c)}');
  if (_amberHue(c)) r.amber.add('$where ${_hex(c)}');
}

/// Walks the render tree: text (cut off, sizes, colour) and fills (colour).
void _walkRender(RenderObject root, PassResult r, Set<double> sizes) {
  void visit(RenderObject o) {
    if (o is RenderOffstage && o.offstage) return;
    if (o is RenderParagraph && _visible(o)) {
      final plain = o.text.toPlainText(includePlaceholders: false);
      if (o.didExceedMaxLines && _reallyCut(o)) {
        r.cutoff.add('"${plain.length > 40 ? plain.substring(0, 40) : plain}"');
      }
      o.text.visitChildren((span) {
        if (span is TextSpan) {
          final color = span.style?.color;
          if (color != null) {
            _colour(
              r,
              color,
              'text "${plain.length > 20 ? plain.substring(0, 20) : plain}"',
            );
          }
        }
        return true;
      });
      final root = o.text;
      // Each piece of text counts at the size it is painted at: its own, else
      // the one it inherits (a wrapper span's size does not count when all its
      // text sits in children that set their own).
      void sizeOf(InlineSpan span, double? inherited, bool icon) {
        if (span is! TextSpan) return;
        final size = span.style?.fontSize ?? inherited;
        final isIcon = icon || _isIconSpan(span);
        if (!isIcon && size != null && (span.text ?? '').trim().isNotEmpty) {
          sizes.add(size);
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          sizeOf(child, size, isIcon);
        }
      }

      sizeOf(root, null, false);
    }
    o.visitChildren(visit);
  }

  visit(root);
}

/// Pumps [home] under the app's theme at [locale], [dark] and [scale], lets it
/// settle (bounded), measures it and unmounts it.
Future<PassResult> measurePass(
  WidgetTester tester, {
  required String name,
  required Widget Function(BuildContext) home,
  required ThemeData theme,
  required Locale locale,
  required double scale,
  required List<LocalizationsDelegate<dynamic>> delegates,
  required List<Locale> locales,
  bool firstViewRules = true,
}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  final result = PassResult(name);
  final errors = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    errors.add(text.split('\n').first);
  };
  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: locale,
        localizationsDelegates: delegates,
        supportedLocales: locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(builder: home),
      ),
    );
    // Bounded settle: 3 s of fake time in 100 ms steps, never pumpAndSettle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (
      var e = tester.takeException();
      e != null;
      e = tester.takeException()
    ) {
      errors.add(e.toString().split('\n').first);
    }
    result.overflow.addAll(
      errors.where((e) => e.contains('overflowed') || e.contains('RenderFlex')),
    );
    final other = errors.where(
      (e) => !(e.contains('overflowed') || e.contains('RenderFlex')),
    );
    result.overflow.addAll(other.map((e) => 'error: $e'));

    if (errors.any((e) => e.contains('No Widgetbook found'))) {
      result.skipped = true;
      result.overflow.clear();
      return result;
    }
    final sizes = <double>{};
    _walkRender(tester.binding.rootElement!.renderObject!, result, sizes);
    result.textSizes = (sizes.map((s) => (s * 10).round() / 10).toSet().toList()
      ..sort());

    // Fills and icon colours, from the widgets (their render objects keep the
    // colour private).
    for (final element in tester.allElements) {
      final box = element.renderObject;
      if (box is! RenderBox || !_visible(box)) continue;
      final w = element.widget;
      if (w is ColoredBox) {
        _colour(result, w.color, 'fill');
      } else if (w is DecoratedBox) {
        final d = w.decoration;
        if (d is BoxDecoration && d.color != null) {
          _colour(result, d.color!, 'fill');
        }
      } else if (w is PhysicalModel) {
        _colour(result, w.color, 'fill');
      } else if (w is PhysicalShape) {
        _colour(result, w.color, 'fill');
      } else if (w is Icon && w.color != null) {
        _colour(result, w.color!, 'icon');
      }
    }

    if (firstViewRules) {
      // Main actions: primary kit buttons whose top is inside the first view.
      for (final element in find.byType(KitButton).evaluate()) {
        final w = element.widget as KitButton;
        final box = element.renderObject;
        if (w.role == KitButtonRole.primary &&
            box is RenderBox &&
            box.attached &&
            box.hasSize &&
            box.localToGlobal(Offset.zero).dy < phone.height) {
          result.mainActions++;
        }
      }
      // First-view items: kit rows and cards, not nested in another counted
      // one, whose top is inside the first view.
      final counted = <Element>[];
      for (final element in tester.allElements) {
        if (!itemTypes.contains(element.widget.runtimeType)) continue;
        final box = element.renderObject;
        if (box is! RenderBox ||
            !box.attached ||
            !box.hasSize ||
            box.localToGlobal(Offset.zero).dy >= phone.height ||
            box.localToGlobal(Offset.zero).dy + box.size.height <= 0) {
          continue;
        }
        var nested = false;
        element.visitAncestorElements((a) {
          if (itemTypes.contains(a.widget.runtimeType)) {
            nested = true;
            return false;
          }
          return true;
        });
        if (!nested) counted.add(element);
      }
      result.firstViewItems = counted.length;

      // Rows: at most two lines of text each (a title and one supporting line).
      for (final element in tester.allElements) {
        if (!rowTypes.contains(element.widget.runtimeType)) continue;
        final box = element.renderObject;
        if (box is! RenderBox ||
            !box.attached ||
            !box.hasSize ||
            box.localToGlobal(Offset.zero).dy >= phone.height ||
            box.localToGlobal(Offset.zero).dy + box.size.height <= 0) {
          continue;
        }
        final lines = textLinesUnder(box);
        if (lines > maxRowLines) {
          result.longRows.add(
            '$lines lines in ${element.widget.runtimeType} at y=${box.localToGlobal(Offset.zero).dy.round()}',
          );
        }
      }
    }
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    // Let timeouts that a screen's controller started (a 25 s read timeout,
    // say) expire in fake time, so no timer is left pending.
    await tester.pump(const Duration(seconds: 40));
    FlutterError.onError = original;
  }
  return result;
}

/// A rule that is broken in [pass], with a short why.
class Finding {
  Finding(this.rule, this.pass, this.detail);
  final String rule;
  final String pass;
  final String detail;
  Map<String, String> toJson() => {
    'rule': rule,
    'pass': pass,
    'detail': detail,
  };
}

const rules = [
  'overflow',
  'cutoff',
  'text-sizes',
  'main-actions',
  'first-view-items',
  'red',
  'row-lines',
];

/// The standard's limits applied to one pass.
List<Finding> findings(PassResult p, {required bool firstViewRules}) {
  String cap(List<String> l) =>
      l.take(3).join('; ') + (l.length > 3 ? ' (+${l.length - 3})' : '');
  if (p.skipped) return [];
  return [
    if (p.overflow.isNotEmpty) Finding('overflow', p.name, cap(p.overflow)),
    if (p.cutoff.isNotEmpty) Finding('cutoff', p.name, cap(p.cutoff)),
    if (p.red.isNotEmpty) Finding('red', p.name, cap(p.red.toSet().toList())),
    if (firstViewRules && p.textSizes.length > 3)
      Finding(
        'text-sizes',
        p.name,
        '${p.textSizes.length} sizes: ${p.textSizes.join(', ')}',
      ),
    if (firstViewRules && p.longRows.isNotEmpty)
      Finding('row-lines', p.name, cap(p.longRows)),
    if (firstViewRules && p.mainActions > 1)
      Finding(
        'main-actions',
        p.name,
        '${p.mainActions} filled primary buttons',
      ),
    if (firstViewRules && p.firstViewItems > 7)
      Finding(
        'first-view-items',
        p.name,
        '${p.firstViewItems} rows/cards in the first view',
      ),
  ];
}
