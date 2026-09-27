/// The one sheet frame and the one confirmation (docs/ux-system/kit-v2.md
/// §1.1, §1.2, §4.1, §4.2, §4.7, §8.2).
///
/// Both adapt to the window (§8.1, [KitLayout]): a bottom sheet on a phone,
/// a capped bottom sheet on a medium window, a centred panel (or an
/// end-side sheet for a full-height sheet) on a tablet in landscape, a PC
/// or the web. Esc closes the top one and obeys the same draft and unsaved
/// input rules as a swipe down.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../widgets/request_routes.dart';
import 'kit_buttons.dart';
import 'kit_icon_button.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_notice.dart';
import 'kit_progress.dart';
import 'kit_technical_value.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';
import 'motion/kit_haptics.dart';
import 'motion/kit_reveal.dart';

part 'kit_confirm_sheet.dart';
part 'kit_consequences.dart';

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// How tall a [showKitSheet] opens.
enum KitSheetHeight {
  /// As tall as its content needs, up to 90 % of the window.
  content,

  /// Half the window: a list the person scrolls.
  half,

  /// Nearly the whole window; an end-side sheet on a wide window (§8.2).
  full,
}

/// The tone of a [showKitSheet] header's icon tile (§5 Sheets). [attention]
/// is used only by `showKitRequestSheet` (LOOK-4, LOOK-24); nothing outside
/// `lib/ui/kit/` reads it (G17).
enum KitSheetTone { neutral, attention }

extension on KitSheetTone {
  _KitTileTone get _tileTone => switch (this) {
    KitSheetTone.neutral => _KitTileTone.neutral,
    KitSheetTone.attention => _KitTileTone.attention,
  };
}

/// Typed input kept across dismissal, per target and server profile
/// (§1.1 data safety, gate G10). Its key is `oc.draft.<target>.<profileId>`,
/// so `ProfileStore.profileScopedPreferenceKeys` sweeps it when the profile
/// is deleted.
///
/// A sheet opened with a draft restores the saved text into [controller]
/// (when the field is empty), saves every change, and lets swipe, back,
/// Esc and close dismiss it silently: nothing is lost, so nothing is asked.
/// The caller calls [clear] once the input is used (sent, saved).
///
/// The caller owns [controller] and disposes it after the sheet closes.
@immutable
class KitDraft {
  const KitDraft({
    required this.target,
    required this.profileId,
    required this.controller,
    this.prefs,
  });

  /// What the text is for, stable across launches: `note.<sessionId>`.
  final String target;
  final String profileId;
  final TextEditingController controller;

  /// The store; defaults to [SharedPreferences.getInstance].
  final SharedPreferences? prefs;

  static String keyFor(String target, String profileId) {
    assert(target.isNotEmpty && profileId.isNotEmpty);
    return 'oc.draft.$target.$profileId';
  }

  String get key => keyFor(target, profileId);

  Future<SharedPreferences> _store() async =>
      prefs ?? await SharedPreferences.getInstance();

  /// Puts the saved text back into an empty [controller].
  Future<void> restore() async {
    final saved = (await _store()).getString(key);
    if (saved != null && saved.isNotEmpty && controller.text.isEmpty) {
      controller.text = saved;
    }
  }

  /// Saves what [controller] holds now (an empty field removes the key).
  Future<void> save() async {
    final store = await _store();
    final text = controller.text;
    if (text.isEmpty) {
      await store.remove(key);
    } else {
      await store.setString(key, text);
    }
  }

  /// Forgets the saved text: the input was used.
  Future<void> clear() async => (await _store()).remove(key);
}

/// Opens [body] in the one sheet frame (§1.1): a handle, a header (title,
/// optional subtitle, close), a scrolling body and pinned actions.
///
/// It adapts to the window (§8.2): a bottom sheet on a compact window, a
/// bottom sheet capped at 640 dp on a medium one, a centred panel of up to
/// 560 dp on an expanded or large one, where [KitSheetHeight.full] becomes
/// an end-side sheet of 400–480 dp. A short window (a phone in landscape)
/// keeps the bottom sheet.
///
/// An action closes the sheet with `Navigator.pop(context, result)` from
/// the caller's context (the sheet is the top route of that navigator) or
/// with [KitSheet.close] from inside [body].
///
/// Data safety: with a [draft], swipe down, back, Esc and close keep the
/// text silently. With only [dirty], the frame owns the swipe (on its
/// handle and header) and catches back and Esc, and asks the discard
/// question inside the sheet (§4.7: never a sheet on a sheet). A
/// [showKitConfirm] raised from inside [body] also replaces the content in
/// place and adds no route. [dismissible] is false only while an
/// irreversible step runs, and the body says so.
///
/// With [routes], the sheet closes itself when its request is answered
/// elsewhere.
///
/// A pinned primary that changes while the sheet is open (Send enabling
/// once something is typed, Submit once an answer is chosen) comes from
/// [primaryListenable]: the frame redraws its pinned block whenever the
/// listenable changes, and the block stays pinned (KIT-17). While the
/// listenable holds null, [primary] is shown (null: no primary).
Future<T?> showKitSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder body,
  String? subtitle,
  IconData? icon,
  KitSheetTone tone = KitSheetTone.neutral,
  KitSheetHeight height = KitSheetHeight.content,
  KitAction? primary,
  ValueListenable<KitAction?>? primaryListenable,
  KitAction? secondary,
  List<KitAction> tertiary = const [],
  ValueListenable<bool>? dirty,
  KitDraft? draft,
  ValueListenable<bool>? loading,
  RequestRoutes? routes,
  bool dismissible = true,
  Key? sheetKey,
}) async {
  if (routes?.isPending == false) return null;
  final window = KitLayout.modalWindowOf(context);
  final shape = !window.isWide
      ? _KitModalShape.bottom
      : height == KitSheetHeight.full
      ? _KitModalShape.side
      : _KitModalShape.panel;
  // A sheet guarding unsaved input owns its swipe (the route's own drag
  // would dismiss it without asking).
  final ownsDrag = dirty != null && draft == null;
  return _presentKitModal<T>(
    context,
    shape: shape,
    maxWidth: shape == _KitModalShape.bottom
        ? KitLayout.sheetMaxWidth
        : KitLayout.dialogPanelWidth,
    dismissible: dismissible,
    enableDrag: !ownsDrag,
    builder: (sheetContext) {
      routes?.own(ModalRoute.of(sheetContext));
      return _KitSheetHost(
        title: title,
        subtitle: subtitle,
        icon: icon,
        tone: tone,
        body: body,
        height: height,
        shape: shape,
        primary: primary,
        primaryListenable: primaryListenable,
        secondary: secondary,
        tertiary: tertiary,
        dirty: dirty,
        draft: draft,
        loading: loading,
        dismissible: dismissible,
        sheetKey: sheetKey,
      );
    },
  );
}

/// The one sheet frame (§1.1), drawn by [showKitSheet]; also used on its
/// own for goldens and for a full-screen variant on tablets.
///
/// A handle (bottom sheets only), a header with the title, an optional
/// muted subtitle and the close button at the end, the one loading bar,
/// the scrolling [child], and the pinned action block. At 200 % text the
/// title and subtitle wrap (never truncated) and the actions stay pinned
/// while the body scrolls; when the header and the pinned block leave the
/// body too little room (200 % text with the keyboard open, a short
/// window), the header scrolls away with the body. The frame never
/// overflows.
class KitSheet extends StatelessWidget {
  const KitSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.tone = KitSheetTone.neutral,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.onClose,
    this.loading = false,
    this.handle = true,
    this.fill = false,
    this.onPullDown,
    this.dismissKeyboardOnDrag = false,
  });

  /// The place in the person's words, at most four words.
  final String title;
  final String? subtitle;

  /// The header's icon tile; null draws no tile.
  final IconData? icon;
  final KitSheetTone tone;

  /// The body; it scrolls inside the frame, so it is never its own
  /// scroll view or Scaffold.
  final Widget child;
  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;

  /// Null hides the close button (while an irreversible step runs).
  final VoidCallback? onClose;
  final bool loading;

  /// The drag handle on top (bottom sheets).
  final bool handle;

  /// Fill the height the frame is given ([KitSheetHeight.half], `full`)
  /// instead of shrinking to the content.
  final bool fill;

  /// A swipe down on the handle or header, where the frame owns the drag
  /// (a sheet guarding unsaved input).
  final VoidCallback? onPullDown;

  /// A drag on the body closes the keyboard (a searchable sheet: the
  /// search field above, results below).
  final bool dismissKeyboardOnDrag;

  /// Closes the sheet [context] is inside with [result]: the person chose
  /// an action, so nothing is asked.
  static void close<T>(BuildContext context, [T? result]) =>
      Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = _l10n(context);
    final subtitle = this.subtitle;
    final hasActions =
        primary != null || secondary != null || tertiary.isNotEmpty;
    Widget top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (handle) _KitHandle(onDismiss: onClose),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            tokens.rail,
            handle ? 0 : tokens.space3,
            tokens.space2,
            tokens.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final icon?) ...[
                KeyedSubtree(
                  key: const ValueKey('kit-sheet-icon'),
                  child: _KitIconTile(icon: icon, tone: tone._tileTone),
                ),
                SizedBox(height: tokens.space3),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        top: tokens.space3,
                        end: tokens.space2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            header: true,
                            namesRoute: true,
                            child: KitText(title, role: KitTextRole.title),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: tokens.space1 / 2),
                            KitText(subtitle, role: KitTextRole.secondary),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (onClose case final close?)
                    KitIconButton(
                      key: const ValueKey('kit-sheet-close'),
                      icon: AppIconography.close,
                      label: l10n.kitSheetClose,
                      onPressed: close,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    if (onPullDown case final pull?) {
      top = _PullDown(onPullDown: pull, child: top);
    }
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        KitLoadingBar(loading: loading, label: l10n.kitSheetLoading),
      ],
    );
    // The body scrolls inside the frame. Its first sliver is the header's
    // place when a short window (or 200 % text with the keyboard open)
    // leaves no room to keep the header fixed: the header then scrolls away
    // with the body ("a short window lets the header scroll with the body").
    final scroll = CustomScrollView(
      shrinkWrap: !fill,
      keyboardDismissBehavior: dismissKeyboardOnDrag
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : null,
      slivers: [
        const _KitHeaderSpacer(),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.rail,
              tokens.space2,
              tokens.rail,
              hasActions ? tokens.space2 : tokens.rail,
            ),
            child: child,
          ),
        ),
      ],
    );
    return _KitSheetFrame(
      fill: fill,
      // What the body keeps at least before the header gives up its fixed
      // place and before the pinned block is cut: two touch targets.
      reserve: tokens.minTarget * 2,
      children: [
        header,
        scroll,
        if (hasActions)
          Padding(
            key: const ValueKey('kit-sheet-actions'),
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.rail,
              tokens.space2,
              tokens.rail,
              tokens.space4,
            ),
            child: KitActionBlock(
              primary: primary,
              secondary: secondary,
              tertiary: tertiary,
            ),
          ),
      ],
    );
  }
}

/// Lays out the frame's header, scrolling body and pinned action block
/// (KIT-17) so that it never overflows, whatever the text size and the
/// keyboard leave:
///
/// - the pinned block keeps its natural height, up to the frame's height
///   less [reserve] (past that it is cut at the bottom, never overflowed:
///   its primary comes first);
/// - the header stays fixed on top while it leaves the body at least
///   [reserve]; otherwise it takes its place inside the body's scroll view
///   (through [_KitHeaderSpacer]) and scrolls away with it;
/// - the body takes the rest and scrolls.
///
/// Children, in reading order: header, body scroll view, optional actions.
/// The header stays outside the scroll view in both modes, so a swipe on
/// the grabber or the header still drags the bottom sheet.
class _KitSheetFrame extends MultiChildRenderObjectWidget {
  const _KitSheetFrame({
    required this.fill,
    required this.reserve,
    required super.children,
  }) : assert(children.length == 2 || children.length == 3);

  final bool fill;
  final double reserve;

  @override
  _RenderKitSheetFrame createRenderObject(BuildContext context) =>
      _RenderKitSheetFrame(fill: fill, reserve: reserve);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderKitSheetFrame renderObject,
  ) {
    renderObject
      ..fill = fill
      ..reserve = reserve;
  }
}

class _KitSheetFrameParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderKitSheetFrame extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _KitSheetFrameParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _KitSheetFrameParentData> {
  _RenderKitSheetFrame({required bool fill, required double reserve})
    : _fill = fill,
      _reserve = reserve;

  bool _fill;
  set fill(bool value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsLayout();
  }

  double _reserve;
  set reserve(double value) {
    if (value == _reserve) return;
    _reserve = value;
    markNeedsLayout();
  }

  /// The header's place inside the scroll view, and how far it scrolled.
  _RenderKitHeaderSpacer? _spacer;
  double _spacerExtent = 0;
  double _scrolled = 0;

  /// The header scrolls with the body (no room to keep it fixed).
  bool _scrollsHeader = false;

  /// The pinned block is taller than the room it has, and is cut.
  bool _actionsCut = false;

  final _clip = LayerHandle<ClipRectLayer>();
  final _headerClip = LayerHandle<ClipRectLayer>();

  RenderBox get _header => firstChild!;
  RenderBox get _scroll => childAfter(_header)!;
  RenderBox? get _actions => childAfter(_scroll);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _KitSheetFrameParentData) {
      child.parentData = _KitSheetFrameParentData();
    }
  }

  void _placeHeader() {
    final data = _header.parentData! as _KitSheetFrameParentData;
    data.offset = Offset(
      0,
      _scrollsHeader ? -math.min(_scrolled, _spacerExtent) : 0,
    );
  }

  /// The spacer reports the body's scroll offset on every layout.
  void _scrolledTo(double scrolled) {
    if (scrolled == _scrolled) return;
    _scrolled = scrolled;
    if (!_scrollsHeader) return;
    _placeHeader();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final width = constraints.maxWidth;
    final widthOnly = BoxConstraints.tightFor(width: width);
    final maxHeight = constraints.maxHeight;
    final targetHeight = _fill && maxHeight.isFinite
        ? maxHeight
        : constraints.minHeight;

    var actionsHeight = 0.0;
    final actions = _actions;
    if (actions != null) {
      actions.layout(widthOnly, parentUsesSize: true);
      actionsHeight = actions.size.height;
      if (maxHeight.isFinite) {
        actionsHeight = math.min(
          actionsHeight,
          math.max(0.0, maxHeight - _reserve),
        );
      }
      _actionsCut = actionsHeight < actions.size.height;
    } else {
      _actionsCut = false;
    }

    final header = _header..layout(widthOnly, parentUsesSize: true);
    final headerHeight = header.size.height;
    final room = maxHeight - actionsHeight;
    _scrollsHeader = headerHeight + _reserve > room;
    final spacerExtent = _scrollsHeader ? headerHeight : 0.0;
    if (spacerExtent != _spacerExtent) {
      invokeLayoutCallback<BoxConstraints>((_) {
        _spacerExtent = spacerExtent;
        _spacer?.markNeedsLayout();
      });
    }

    final fixedHeader = _scrollsHeader ? 0.0 : headerHeight;
    final scrollRoom = math.max(0.0, room - fixedHeader);
    final scrollMin = math.min(
      scrollRoom,
      math.max(0.0, targetHeight - actionsHeight - fixedHeader),
    );
    final scroll = _scroll
      ..layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: scrollMin,
          maxHeight: scrollRoom,
        ),
        parentUsesSize: true,
      );
    size = constraints.constrain(
      Size(width, fixedHeader + scroll.size.height + actionsHeight),
    );
    (scroll.parentData! as _KitSheetFrameParentData).offset = Offset(
      0,
      fixedHeader,
    );
    if (actions != null) {
      (actions.parentData! as _KitSheetFrameParentData).offset = Offset(
        0,
        size.height - actionsHeight,
      );
    }
    _placeHeader();
  }

  /// Where the scroll view sits; a header that scrolls with the body is
  /// drawn (and hit) only inside it, never over the pinned block.
  Rect get _scrollRect {
    final data = _scroll.parentData! as _KitSheetFrameParentData;
    return data.offset & _scroll.size;
  }

  Offset _offsetOf(RenderBox child) =>
      (child.parentData! as _KitSheetFrameParentData).offset;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_actionsCut) {
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChildren,
        oldLayer: _clip.layer,
      );
    } else {
      _clip.layer = null;
      _paintChildren(context, offset);
    }
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    context.paintChild(_scroll, offset + _offsetOf(_scroll));
    if (_scrollsHeader) {
      _headerClip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        _scrollRect,
        (context, offset) =>
            context.paintChild(_header, offset + _offsetOf(_header)),
        oldLayer: _headerClip.layer,
      );
    } else {
      _headerClip.layer = null;
      context.paintChild(_header, offset + _offsetOf(_header));
    }
    if (_actions case final actions?) {
      context.paintChild(actions, offset + _offsetOf(actions));
    }
  }

  bool _hitChild(BoxHitTestResult result, RenderBox child, Offset position) =>
      result.addWithPaintOffset(
        offset: _offsetOf(child),
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_actions case final actions?) {
      if (_hitChild(result, actions, position)) return true;
    }
    if (!_scrollsHeader) {
      return _hitChild(result, _header, position) ||
          _hitChild(result, _scroll, position);
    }
    // A header that scrolls with the body lies over the scroll view: its
    // own controls take taps first, and the scroll view still gets the
    // pointer, so a drag on the header scrolls (it may fill the view).
    if (!_scrollRect.contains(position)) return false;
    final header = _hitChild(result, _header, position);
    final scroll = _hitChild(result, _scroll, position);
    return header || scroll;
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    if (child == _header && _scrollsHeader) return _scrollRect;
    if (_actionsCut) return Offset.zero & size;
    return null;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void dispose() {
    _clip.layer = null;
    _headerClip.layer = null;
    super.dispose();
  }
}

/// The header's place at the top of the frame's scroll view: empty while
/// the header stays fixed, the header's height while it scrolls with the
/// body. It reports the scroll offset to the frame that draws the header.
class _KitHeaderSpacer extends LeafRenderObjectWidget {
  const _KitHeaderSpacer();

  @override
  _RenderKitHeaderSpacer createRenderObject(BuildContext context) =>
      _RenderKitHeaderSpacer();
}

class _RenderKitHeaderSpacer extends RenderSliver {
  _RenderKitSheetFrame? _frame;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    RenderObject? node = parent;
    while (node != null && node is! _RenderKitSheetFrame) {
      node = node.parent;
    }
    _frame = node as _RenderKitSheetFrame?;
    _frame?._spacer = this;
  }

  @override
  void detach() {
    if (_frame?._spacer == this) _frame?._spacer = null;
    _frame = null;
    super.detach();
  }

  @override
  void performLayout() {
    final extent = _frame?._spacerExtent ?? 0.0;
    final paintExtent = calculatePaintOffset(constraints, from: 0, to: extent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: paintExtent,
      maxPaintExtent: extent,
      hitTestExtent: paintExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: extent),
    );
    _frame?._scrolledTo(constraints.scrollOffset);
  }
}

/// The drag handle: a short bar with a spoken "Dismiss" action.
class _KitHandle extends StatelessWidget {
  const _KitHandle({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Semantics(
      label: onDismiss == null ? null : _l10n(context).kitSheetDismiss,
      onDismiss: onDismiss,
      child: SizedBox(
        height: tokens.handleHeight,
        child: Center(
          child: Container(
            key: const ValueKey('kit-sheet-handle'),
            width: tokens.handleSize.width,
            height: tokens.handleSize.height,
            decoration: BoxDecoration(
              color: tokens.handleColor,
              borderRadius: BorderRadius.circular(tokens.handleSize.height / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tone of the one header tile [_KitIconTile] draws (§5 Sheets).
/// [KitSheet] uses [neutral] and [attention]; the confirm part (kit_confirm_
/// sheet.dart) uses [neutral] and [danger] (LOOK-5: danger only inside a
/// confirmation).
enum _KitTileTone { neutral, attention, danger }

/// The one 44 dp header tile (§5 Sheets, new private seam): a rounded square
/// with a centred glyph, excluded from semantics — the title beside it (or,
/// for a confirmation, the title after it) carries the meaning.
class _KitIconTile extends StatelessWidget {
  const _KitIconTile({required this.icon, required this.tone});

  final IconData icon;
  final _KitTileTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    // The tile stays the one 44 dp square at every text size, so its edge
    // always lands on whole physical pixels (VL §7); only the glyph grows
    // with the person's text size, clamped at maxIconScale (22 → 33 dp at
    // most, still inside the 44 dp tile).
    final glyphSize = tokens.iconSize(context, tokens.markIconSize);
    final tileSize = tokens.markSize;
    final (Color background, Color glyph) = switch (tone) {
      _KitTileTone.neutral => (roles.surface3, roles.text1),
      _KitTileTone.attention => (
        Color.alphaBlend(
          roles.attention.withValues(alpha: tokens.markTintAlpha),
          tokens.sheetSurface,
        ),
        roles.attention,
      ),
      _KitTileTone.danger => (
        Color.alphaBlend(
          roles.danger.withValues(alpha: tokens.markTintAlpha),
          tokens.sheetSurface,
        ),
        roles.danger,
      ),
    };
    return ExcludeSemantics(
      child: Container(
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(tokens.markRadius),
        ),
        child: Icon(icon, size: glyphSize, color: glyph),
      ),
    );
  }
}

/// A swipe down the frame owns: far or fast enough, it asks to close.
class _PullDown extends StatefulWidget {
  const _PullDown({required this.onPullDown, required this.child});

  final VoidCallback onPullDown;
  final Widget child;

  @override
  State<_PullDown> createState() => _PullDownState();
}

class _PullDownState extends State<_PullDown> {
  /// How far or how fast a pull must go to count (behaviour, not look).
  static const _distance = 48.0;
  static const _velocity = 700.0;

  double _pulled = 0;

  /// A header that scrolls with the body gives its drags to the scroll
  /// view (it may fill the whole view); the pull is not offered then.
  bool _allowed() =>
      !(context
              .findAncestorRenderObjectOfType<_RenderKitSheetFrame>()
              ?._scrollsHeader ??
          false);

  void _onStart(DragStartDetails _) => _pulled = 0;

  void _onUpdate(DragUpdateDetails details) => _pulled += details.delta.dy;

  void _onEnd(DragEndDetails details) {
    if (_pulled > _distance || (details.primaryVelocity ?? 0) > _velocity) {
      widget.onPullDown();
    }
    _pulled = 0;
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.translucent,
    gestures: {
      _PullDownRecognizer:
          GestureRecognizerFactoryWithHandlers<_PullDownRecognizer>(
            () => _PullDownRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..allowed = _allowed
              ..onStart = _onStart
              ..onUpdate = _onUpdate
              ..onEnd = _onEnd,
          ),
    },
    child: widget.child,
  );
}

/// A vertical drag that joins the arena only while [allowed] says so.
class _PullDownRecognizer extends VerticalDragGestureRecognizer {
  _PullDownRecognizer({super.debugOwner});

  bool Function() allowed = _always;

  static bool _always() => true;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      allowed() && super.isPointerAllowed(event);
}

enum _KitModalShape { bottom, panel, side }

/// Pushes a kit modal in the shape the window asks for (§8.2). The route
/// always goes on the caller's own navigator, so `Navigator.pop(context)`
/// from the caller closes it.
Future<T?> _presentKitModal<T>(
  BuildContext context, {
  required _KitModalShape shape,
  required double maxWidth,
  required bool dismissible,
  required bool enableDrag,
  required WidgetBuilder builder,
}) {
  final reduced = KitMotion.reduced(context);
  final tokens = KitTokens.of(context);
  final style = reduced
      ? AnimationStyle.noAnimation
      : AnimationStyle(
          duration: KitMotion.standard,
          reverseDuration: KitMotion.standard,
          curve: KitMotion.enter,
          reverseCurve: KitMotion.exit,
        );
  switch (shape) {
    case _KitModalShape.bottom:
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: dismissible,
        enableDrag: dismissible && enableDrag,
        showDragHandle: false,
        backgroundColor: tokens.sheetSurface,
        barrierColor: tokens.scrim,
        elevation: tokens.sheetElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.sheetRadius),
          ),
        ),
        constraints: BoxConstraints(maxWidth: maxWidth),
        sheetAnimationStyle: style,
        builder: builder,
      );
    case _KitModalShape.panel:
      return showDialog<T>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: dismissible,
        barrierColor: tokens.scrim,
        animationStyle: style,
        builder: (dialogContext) => Dialog(
          insetPadding: EdgeInsets.all(tokens.panelInset),
          backgroundColor: tokens.panelSurface,
          elevation: tokens.panelElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.panelRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight:
                  MediaQuery.sizeOf(dialogContext).height *
                  KitLayout.modalMaxHeight,
            ),
            child: builder(dialogContext),
          ),
        ),
      );
    case _KitModalShape.side:
      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: dismissible,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: tokens.scrim,
        transitionDuration: reduced ? Duration.zero : KitMotion.standard,
        pageBuilder: (dialogContext, _, _) {
          final width =
              (MediaQuery.sizeOf(dialogContext).width *
                      KitLayout.sideSheetShare)
                  .clamp(
                    KitLayout.sideSheetMinWidth,
                    KitLayout.sideSheetMaxWidth,
                  );
          return Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: Material(
                color: tokens.sideSheetSurface,
                elevation: tokens.sideSheetElevation,
                child: SafeArea(child: builder(dialogContext)),
              ),
            ),
          );
        },
        transitionBuilder: (dialogContext, animation, _, child) {
          final rtl = Directionality.of(dialogContext) == TextDirection.rtl;
          return SlideTransition(
            position: Tween(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: KitMotion.enter),
                ),
            child: child,
          );
        },
      );
  }
}

/// A question asked in place of a sheet's content (§4.7).
class _KitAsk {
  _KitAsk(this.spec);

  final _KitConfirmSpec spec;
  final done = Completer<bool>();
}

/// Lets a [showKitConfirm] raised from inside a sheet find that sheet.
class _KitSheetScope extends InheritedWidget {
  const _KitSheetScope({required this.host, required super.child});

  final _KitSheetHostState host;

  /// The sheet [context] is inside; or, for a context outside it (a
  /// pinned action's callback uses the caller's context), the kit sheet
  /// that is the top route of [context]'s navigator.
  static _KitSheetHostState? maybeOf(BuildContext context) {
    final inside = context.getInheritedWidgetOfExactType<_KitSheetScope>();
    if (inside != null) return inside.host;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return null;
    for (final host in _KitSheetHostState._live.reversed) {
      final route = host._route;
      if (route != null && route.isCurrent && route.navigator == navigator) {
        return host;
      }
    }
    return null;
  }

  @override
  bool updateShouldNotify(_KitSheetScope old) => old.host != host;
}

/// The live sheet: its draft, its unsaved-input guard, Esc, and the
/// question asked in place.
class _KitSheetHost extends StatefulWidget {
  const _KitSheetHost({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.body,
    required this.height,
    required this.shape,
    required this.primary,
    required this.primaryListenable,
    required this.secondary,
    required this.tertiary,
    required this.dirty,
    required this.draft,
    required this.loading,
    required this.dismissible,
    required this.sheetKey,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final KitSheetTone tone;
  final WidgetBuilder body;
  final KitSheetHeight height;
  final _KitModalShape shape;
  final KitAction? primary;
  final ValueListenable<KitAction?>? primaryListenable;
  final KitAction? secondary;
  final List<KitAction> tertiary;
  final ValueListenable<bool>? dirty;
  final KitDraft? draft;
  final ValueListenable<bool>? loading;
  final bool dismissible;
  final Key? sheetKey;

  @override
  State<_KitSheetHost> createState() => _KitSheetHostState();
}

class _KitSheetHostState extends State<_KitSheetHost> {
  /// Open kit sheets, newest last.
  static final _live = <_KitSheetHostState>[];

  final _focus = FocusNode(debugLabel: 'kit-sheet');
  _KitAsk? _ask;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      unawaited(draft.restore());
      draft.controller.addListener(_saveDraft);
    }
    widget.dirty?.addListener(_rebuild);
    widget.loading?.addListener(_rebuild);
    widget.primaryListenable?.addListener(_rebuild);
    _live.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _live.remove(this);
    widget.draft?.controller.removeListener(_saveDraft);
    widget.dirty?.removeListener(_rebuild);
    widget.loading?.removeListener(_rebuild);
    widget.primaryListenable?.removeListener(_rebuild);
    final ask = _ask;
    if (ask != null && !ask.done.isCompleted) ask.done.complete(false);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _saveDraft() => unawaited(widget.draft?.save());

  /// Unsaved input that no draft keeps.
  bool get _unsaved => widget.draft == null && (widget.dirty?.value ?? false);

  /// Replaces the content with [spec]'s question until it is answered.
  Future<bool> ask(_KitConfirmSpec spec) {
    final previous = _ask;
    if (previous != null && !previous.done.isCompleted) {
      previous.done.complete(false);
    }
    final ask = _KitAsk(spec);
    setState(() => _ask = ask);
    return ask.done.future;
  }

  void _answer(bool confirmed) {
    final ask = _ask;
    if (ask == null) return;
    setState(() => _ask = null);
    if (!ask.done.isCompleted) ask.done.complete(confirmed);
    _focus.requestFocus();
  }

  /// Back, Esc, the close button, a swipe or a tap outside, when the route
  /// may not simply pop.
  Future<void> _blockedPop() async {
    if (!widget.dismissible) return;
    if (_ask != null) {
      _answer(false);
      return;
    }
    if (!_unsaved) return;
    final l10n = _l10n(context);
    final discard = await ask(
      _KitConfirmSpec(
        title: l10n.kitDiscardTitle,
        body: l10n.kitDiscardBody,
        confirmLabel: l10n.kitDiscardConfirm,
        kind: KitConfirmKind.discard,
      ),
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  void _close() => unawaited(Navigator.of(context).maybePop());

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.shape;
    final ask = _ask;
    final size = MediaQuery.sizeOf(context);
    final fill = widget.height != KitSheetHeight.content;
    final bottom = shape == _KitModalShape.bottom;
    Widget content = KitSheet(
      key: widget.sheetKey,
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      tone: widget.tone,
      primary: widget.primaryListenable?.value ?? widget.primary,
      secondary: widget.secondary,
      tertiary: widget.tertiary,
      loading: widget.loading?.value ?? false,
      handle: bottom,
      fill: fill || shape == _KitModalShape.side,
      onClose: widget.dismissible ? _close : null,
      onPullDown: bottom && widget.dismissible && widget.dirty != null
          ? _close
          : null,
      child: Builder(builder: widget.body),
    );
    // The question takes the content's place; the content keeps its state
    // (typed text) underneath, out of sight and out of focus. The content
    // keeps its place in the tree, so nothing in it is rebuilt from scratch.
    content = Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ask != null) ...[
          if (bottom) _KitHandle(onDismiss: () => _answer(false)),
          Flexible(
            fit: fill ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              child: KitEntrance(
                child: _KitConfirmBody(
                  spec: ask.spec,
                  onConfirm: () => _answer(true),
                  onCancel: () => _answer(false),
                ),
              ),
            ),
          ),
        ],
        Flexible(
          key: const ValueKey('kit-sheet-content'),
          fit: fill && ask == null ? FlexFit.tight : FlexFit.loose,
          child: ExcludeFocus(
            excluding: ask != null,
            child: Visibility(
              visible: ask == null,
              maintainState: true,
              child: content,
            ),
          ),
        ),
      ],
    );
    final maxHeight = size.height;
    final double? fixed = switch ((shape, widget.height)) {
      (_KitModalShape.side, _) => null,
      (_, KitSheetHeight.half) => maxHeight * KitLayout.sheetHalfHeight,
      (_KitModalShape.bottom, KitSheetHeight.full) =>
        maxHeight * KitLayout.sheetFullHeight,
      (_, KitSheetHeight.full) => maxHeight * KitLayout.modalMaxHeight,
      _ => null,
    };
    content = fixed != null
        ? SizedBox(height: fixed, child: content)
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight * KitLayout.modalMaxHeight,
            ),
            child: content,
          );
    if (bottom) {
      // The pinned actions ride above the keyboard.
      content = Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(top: false, child: content),
      );
    }
    return _KitSheetScope(
      host: this,
      child: PopScope<Object?>(
        canPop: widget.dismissible && ask == null && !_unsaved,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_blockedPop());
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: content,
        ),
      ),
    );
  }
}
