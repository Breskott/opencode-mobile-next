import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_bidi.dart';
import 'kit_buttons.dart';
import 'kit_panel.dart';
import 'kit_row.dart';
import 'kit_status_mark.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// Choosing colours by looking (docs/ux-system/kit-api/KitSwatch.md,
/// kit-v2.md §5, §9.2): one theme, or one accent for the coming custom
/// theme, as a miniature the person picks by tapping.
///
/// [KitSwatch.new] shows a theme: a miniature of its own [roles] (its
/// ground, a `surface1` panel with a line of its `text1`, and its `accent`
/// and `success` colours) with the [label] under it. [KitSwatch.accent]
/// shows one guarded accent [color] as a circle, for the custom theme's
/// accent picker.
///
/// States: default, selected (in use), disabled with reason.
///
/// The colours drawn in the miniature are the swatch's own [roles], never
/// the current theme's — a swatch stays true to the theme it offers even
/// when the app itself is in a different theme now. The frame around it
/// (the label, the check, the border, the focus ring) always follows the
/// *current* theme.
class KitSwatch extends StatelessWidget {
  /// A theme: a miniature in [roles] with [label] under it.
  const KitSwatch({
    super.key,
    required this.roles,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.disabledReason,
    this.swatchKey,
  }) : color = null,
       assert(
         onPressed != null || disabledReason != null,
         'KitSwatch: disabledReason is required when onPressed is null.',
       );

  /// One accent for the custom theme: a circle of [color].
  const KitSwatch.accent({
    super.key,
    required Color this.color,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.disabledReason,
    this.swatchKey,
  }) : roles = null,
       assert(
         onPressed != null || disabledReason != null,
         'KitSwatch: disabledReason is required when onPressed is null.',
       );

  /// The theme this swatch offers (null for [KitSwatch.accent]).
  final ThemeRoles? roles;

  /// The accent this swatch offers (null for [KitSwatch.new]).
  final Color? color;

  /// The pack's name, or the accent's own name ("Graphite", "Blue"), shown
  /// as written.
  final String label;

  /// In use now: a check and selected semantics with the value "In use".
  final bool selected;

  /// Null disables it; [disabledReason] is then required.
  final VoidCallback? onPressed;

  /// Why it cannot be picked ("Needs Android 12 or later"). Shown as
  /// visible text for [KitSwatch.new]; only in semantics for
  /// [KitSwatch.accent] (the picker never offers an invalid accent).
  final String? disabledReason;

  /// Kept by the host (e.g. `ValueKey('theme-pack-${id.name}')`).
  final Key? swatchKey;

  bool get _isAccent => color != null;

  @override
  Widget build(BuildContext context) =>
      _SwatchBody(key: swatchKey, swatch: this);
}

/// A single-choice group of [KitSwatch]es (docs/ux-system/kit-api/KitSwatch.md
/// "Adaptive"): columns from the space it has, start-aligned, one Tab stop,
/// arrow keys move within it in reading order (KitChoiceList's group rule,
/// kit-v2.md §8.2).
class KitSwatchGrid extends StatelessWidget {
  const KitSwatchGrid({
    super.key,
    required this.label,
    required this.children,
    this.gridKey,
  });

  /// The group's name for semantics: "Theme", "Accent colour".
  final String label;

  /// All theme swatches or all accent swatches (asserted).
  final List<KitSwatch> children;

  final Key? gridKey;

  @override
  Widget build(BuildContext context) {
    assert(
      children.isEmpty ||
          children.every((c) => c._isAccent == children.first._isAccent),
      'KitSwatchGrid: children must all be KitSwatch (theme) or all '
      'KitSwatch.accent, never a mix.',
    );
    return _SwatchGridBody(key: gridKey, label: label, children: children);
  }
}

// -----------------------------------------------------------------------
// KitSwatch: focus, hover and the visual tile.
// -----------------------------------------------------------------------

/// Carried by [KitSwatchGrid] down to each [KitSwatch] so the grid's own
/// [FocusNode] is the one the swatch uses (roving tabindex: only the active
/// swatch is a Tab stop) and arrow keys reach the grid's navigation. Purely
/// an implementation seam between the two widgets in this file — invisible
/// outside it, so it changes nothing in the frozen public API.
class _SwatchFocusHost extends InheritedWidget {
  const _SwatchFocusHost({
    required this.node,
    required this.skipTraversal,
    required this.onOtherKey,
    required super.child,
  });

  final FocusNode node;
  final bool skipTraversal;
  final KeyEventResult Function(KeyEvent event) onOtherKey;

  static _SwatchFocusHost? maybe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwatchFocusHost>();

  @override
  bool updateShouldNotify(_SwatchFocusHost oldWidget) =>
      oldWidget.node != node ||
      oldWidget.skipTraversal != skipTraversal ||
      oldWidget.onOtherKey != onOtherKey;
}

/// The interactive shell of a [KitSwatch]: semantics, focus (its own node
/// standalone, or the grid's when hosted), hover and the tap target. The
/// visual tile itself is [_SwatchTile].
class _SwatchBody extends StatefulWidget {
  const _SwatchBody({super.key, required this.swatch});

  final KitSwatch swatch;

  @override
  State<_SwatchBody> createState() => _SwatchBodyState();
}

class _SwatchBodyState extends State<_SwatchBody> {
  FocusNode? _ownNode;
  bool _hovered = false;

  FocusNode _nodeFor(_SwatchFocusHost? hosted) =>
      hosted?.node ?? (_ownNode ??= FocusNode(debugLabel: 'KitSwatch'));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(
    FocusNode node,
    KeyEvent event,
    _SwatchFocusHost? hosted,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final onPressed = widget.swatch.onPressed;
    final key = event.logicalKey;
    if (onPressed != null &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      onPressed();
      return KeyEventResult.handled;
    }
    if (hosted != null) return hosted.onOtherKey(event);
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final swatch = widget.swatch;
    final hosted = _SwatchFocusHost.maybe(context);
    final node = _nodeFor(hosted);
    final enabled = swatch.onPressed != null;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Semantics(
      button: true,
      enabled: enabled,
      selected: swatch.selected,
      value: swatch.selected ? l10n.kitSwatchInUse : null,
      hint: swatch.disabledReason,
      label: swatch.label,
      inMutuallyExclusiveGroup: true,
      child: Focus(
        focusNode: node,
        canRequestFocus: enabled,
        skipTraversal: hosted?.skipTraversal ?? !enabled,
        onKeyEvent: (n, e) => _onKeyEvent(n, e, hosted),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: swatch.onPressed == null
                ? null
                : () {
                    // A tap also focuses it, like a real button: Enter or
                    // Space then repeats the same press (G14).
                    node.requestFocus();
                    swatch.onPressed!();
                  },
            child: AnimatedBuilder(
              animation: node,
              builder: (context, _) => _SwatchTile(
                swatch: swatch,
                hovered: _hovered,
                focused: node.hasFocus,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The purely visual tile: the miniature or the accent circle, the label
/// and the check, drawn from tokens only.
class _SwatchTile extends StatelessWidget {
  const _SwatchTile({
    required this.swatch,
    required this.hovered,
    required this.focused,
  });

  final KitSwatch swatch;
  final bool hovered;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final enabled = swatch.onPressed != null;
    return swatch._isAccent
        ? _accentTile(context, tokens, roles, enabled)
        : _themeTile(context, tokens, roles, enabled);
  }

  Widget _themeTile(
    BuildContext context,
    KitTokens tokens,
    ThemeRoles roles,
    bool enabled,
  ) {
    final borderColor = !enabled
        ? roles.hairline
        : (swatch.selected ? roles.accent : roles.hairline);
    final reason = swatch.disabledReason;
    return DecoratedBox(
      key: const ValueKey('kit-swatch-tile'),
      decoration: BoxDecoration(
        border: Border.all(
          color: focused ? roles.accent : borderColor,
          width: focused
              ? KitTokens.focusRingWidth(context)
              : KitTokens.hairlineWidth(context),
        ),
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: tokens.minTarget),
        padding: EdgeInsets.all(tokens.space2),
        color: hovered && enabled ? roles.surface1.withValues(alpha: .6) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.iconTileRadius),
              child: SizedBox(
                height: KitTokens.swatchPreviewHeight,
                child: switch (swatch.roles) {
                  final swatchRoles? when enabled => _Miniature(
                    roles: swatchRoles,
                  ),
                  // Disabled, or no palette to show at all (`roles: null`,
                  // e.g. Material You below Android 12): unavailable is
                  // said, not faded (STATE-8, LOOK-14).
                  _ => _UnavailableMiniature(roles: roles),
                },
              ),
            ),
            SizedBox(height: tokens.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: KitText(
                    KitBidi.auto(swatch.label),
                    key: const ValueKey('kit-swatch-label'),
                    role: KitTextRole.label,
                    tone: enabled ? null : KitTextTone.tertiary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (swatch.selected) ...[
                  SizedBox(width: tokens.space1),
                  Icon(
                    AppIconography.check,
                    key: const ValueKey('kit-swatch-check'),
                    size: tokens.smallIconSize,
                    color: roles.accent,
                  ),
                ],
              ],
            ),
            if (!enabled && reason != null) ...[
              SizedBox(height: tokens.space1),
              KitText(
                reason,
                key: const ValueKey('kit-swatch-reason'),
                role: KitTextRole.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accentTile(
    BuildContext context,
    KitTokens tokens,
    ThemeRoles roles,
    bool enabled,
  ) {
    assert(
      !enabled || _accentKeepsMeaning(swatch.color!, roles),
      'KitSwatch.accent: color must keep LOOK-39\'s distance from the '
      'current theme\'s attention and danger (hue ≥ 30°, ΔE2000 ≥ 20). '
      'theme_roles.dart has no public accentKeepsMeaning yet (pre-wave, '
      '_new-tokens.md §0.5 step 1); this is a temporary local check — see '
      'the contract note in this unit\'s QA record.',
    );
    final circleColor = enabled ? swatch.color! : roles.surface3;
    final ringColor = !enabled
        ? roles.hairline
        : (swatch.selected ? roles.text1 : roles.hairline);
    return SizedBox(
      width: tokens.minTarget,
      height: tokens.minTarget,
      child: Center(
        child: Container(
          key: const ValueKey('kit-swatch-accent-circle'),
          width: tokens.markSize,
          height: tokens.markSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleColor,
            border: Border.all(
              color: focused ? roles.accent : ringColor,
              width: focused
                  ? KitTokens.focusRingWidth(context)
                  : KitTokens.hairlineWidth(context),
            ),
          ),
          child: swatch.selected
              ? Center(
                  child: Icon(
                    AppIconography.check,
                    key: const ValueKey('kit-swatch-accent-check'),
                    size: tokens.smallIconSize,
                    color: onColor(swatch.color!),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// The theme's own miniature: its ground, a panel with a line of its text,
/// and its accent and success dots. Always the swatch's own [roles], never
/// the ambient theme.
class _Miniature extends StatelessWidget {
  const _Miniature({required this.roles});

  final ThemeRoles roles;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('kit-swatch-ground'),
      decoration: BoxDecoration(color: roles.ground),
      child: Padding(
        padding: EdgeInsets.all(tokens.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DecoratedBox(
                key: const ValueKey('kit-swatch-panel'),
                decoration: BoxDecoration(
                  color: roles.surface1,
                  borderRadius: BorderRadius.circular(tokens.iconTileRadius),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space2,
                    vertical: tokens.space3,
                  ),
                  child: DecoratedBox(
                    key: const ValueKey('kit-swatch-text-line'),
                    decoration: BoxDecoration(
                      color: roles.text1,
                      borderRadius: BorderRadius.circular(
                        KitTokens.progressBarRadius,
                      ),
                    ),
                    child: SizedBox(
                      height: KitTokens.progressBarHeight,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.space2),
            DecoratedBox(
              key: const ValueKey('kit-swatch-accent-dot'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roles.accent,
              ),
              child: const SizedBox(
                width: KitTokens.swatchDot,
                height: KitTokens.swatchDot,
              ),
            ),
            SizedBox(width: tokens.space1),
            DecoratedBox(
              key: const ValueKey('kit-swatch-success-dot'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roles.success,
              ),
              child: const SizedBox(
                width: KitTokens.swatchDot,
                height: KitTokens.swatchDot,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The disabled miniature: a plain `surface3` field with the sparkle glyph
/// in `text3` (the *current* theme's roles: unavailable is said, never a
/// theme's own colours faded).
class _UnavailableMiniature extends StatelessWidget {
  const _UnavailableMiniature({required this.roles});

  final ThemeRoles roles;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('kit-swatch-unavailable'),
    decoration: BoxDecoration(color: roles.surface3),
    child: Center(
      child: Icon(AppIconography.sparkle, size: 20, color: roles.text3),
    ),
  );
}

// -----------------------------------------------------------------------
// KitSwatchGrid body: columns from the space it has, roving-tabindex
// keyboard navigation (kit-v2.md §8.2, the KitChoiceList group rule).
// -----------------------------------------------------------------------

class _SwatchGridBody extends StatefulWidget {
  const _SwatchGridBody({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<KitSwatch> children;

  @override
  State<_SwatchGridBody> createState() => _SwatchGridBodyState();
}

class _SwatchGridBodyState extends State<_SwatchGridBody> {
  late List<FocusNode> _nodes = _buildNodes();
  late int _active = _initialActive();

  List<FocusNode> _buildNodes() => List.generate(
    widget.children.length,
    (_) => FocusNode(debugLabel: 'KitSwatchGrid item'),
  );

  int _initialActive() {
    final selected = widget.children.indexWhere((c) => c.selected);
    return selected >= 0 ? selected : 0;
  }

  @override
  void initState() {
    super.initState();
    for (final node in _nodes) {
      node.addListener(_handleFocusChange);
    }
  }

  @override
  void didUpdateWidget(covariant _SwatchGridBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      for (final node in _nodes) {
        node.removeListener(_handleFocusChange);
        node.dispose();
      }
      _nodes = _buildNodes();
      for (final node in _nodes) {
        node.addListener(_handleFocusChange);
      }
      if (_active >= _nodes.length) {
        _active = _nodes.isEmpty ? 0 : _nodes.length - 1;
      }
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.removeListener(_handleFocusChange);
      node.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    final i = _nodes.indexWhere((n) => n.hasFocus);
    if (i >= 0 && i != _active) setState(() => _active = i);
  }

  KeyEventResult _onOtherKey(int index, KeyEvent event, int columns) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final key = event.logicalKey;
    int? target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = index + columns;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = index - columns;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      target = index + (ltr ? 1 : -1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      target = index + (ltr ? -1 : 1);
    } else if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = _nodes.length - 1;
    } else {
      return KeyEventResult.ignored;
    }
    if (target >= 0 && target < _nodes.length) {
      _nodes[target].requestFocus();
    }
    return KeyEventResult.handled;
  }

  /// `KitTokens.swatchMinWidth`-based columns (`_new-tokens.md`), one fewer
  /// from 1.3× text (A11Y: the label keeps at least 8 characters per line).
  static int columnsFor(double width, double textScale) {
    var columns = (width / KitTokens.swatchMinWidth).floor().clamp(2, 6);
    if (textScale >= 1.3) columns = math.max(columns - 1, 1);
    return columns;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : KitTokens.swatchMinWidth * 3;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = columnsFor(width, textScale);
        final spacing = tokens.space3;
        // Floored, so the row's total width never rounds up past what
        // [Wrap] was given (which would push the last column onto a new
        // line). [columnsFor] already keeps `width / columns` at or above
        // [KitTokens.swatchMinWidth] except at the fixed 2-column floor on
        // a very narrow window, so no extra floor is applied here — one
        // would only make the tiles too wide to fit the columns chosen.
        final tileWidth = math.max(
          ((width - spacing * (columns - 1)) / columns).floorToDouble(),
          1.0,
        );
        return Semantics(
          label: widget.label,
          container: true,
          explicitChildNodes: true,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                SizedBox(
                  width: tileWidth,
                  child: _SwatchFocusHost(
                    node: _nodes[i],
                    skipTraversal: i != _active,
                    onOtherKey: (event) => _onOtherKey(i, event, columns),
                    child: widget.children[i],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------
// KitThemePreview
// -----------------------------------------------------------------------

/// A picture of a candidate theme (docs/ux-system/kit-api/KitSwatch.md):
/// the app's own parts — a panel with a row (icon tile, title, "Working ·
/// 2 min" with the working mark), a code line, the needs-you word, a
/// selected segment's check, a primary and a secondary button — all drawn
/// in [roles] rather than the app's current theme, so a preview sheet shows
/// what a theme looks like before it is applied.
///
/// One `Theme` override, inside the kit (kit-v2.md §9.1, KIT-5): the real
/// kit parts pick up [roles] because they are actually rendered in them,
/// not copied — when the v2 parts land, the preview follows automatically.
///
/// One state: it draws what it is given. It is a picture, not a control —
/// one semantics node labelled [label], and nothing inside it is
/// interactive or announced as a button.
class KitThemePreview extends StatelessWidget {
  const KitThemePreview({
    super.key,
    required this.roles,
    required this.label,
    this.previewKey,
  });

  final ThemeRoles roles;

  /// "Preview of Graphite": the semantic label of the whole picture.
  final String label;

  final Key? previewKey;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final theme = AppTheme.forLocale(AppTheme.fromRoles(roles), locale);
    return Semantics(
      key: previewKey,
      label: label,
      image: true,
      container: true,
      excludeSemantics: true,
      child: IgnorePointer(
        child: Theme(
          data: theme,
          child: Builder(builder: _sample),
        ),
      ),
    );
  }

  Widget _sample(BuildContext context) {
    final tokens = KitTokens.of(context);
    final r = tokens.roles;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return KitPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitRow.icon(context, AppIconography.terminal),
              SizedBox(width: tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KitText(
                      l10n.kitThemePreviewTitle,
                      role: KitTextRole.rowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.space1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KitStatusMark(state: KitMarkState.working),
                        Flexible(
                          child: KitText(
                            l10n.kitThemePreviewWorking,
                            role: KitTextRole.secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space3),
          DecoratedBox(
            decoration: BoxDecoration(
              color: r.surface2,
              borderRadius: BorderRadius.circular(tokens.codeRadius),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.space2),
              child: KitBidi.ltrText(
                l10n.kitThemePreviewCode,
                style: tokens.technicalValue,
              ),
            ),
          ),
          SizedBox(height: tokens.space3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIconography.question, size: 18, color: r.attention),
              SizedBox(width: tokens.space1),
              Flexible(
                child: KitText(
                  l10n.kitThemePreviewNeedsYou,
                  role: KitTextRole.secondary,
                  tone: KitTextTone.attention,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: r.surface3,
                shape: tokens.shapeOf(KitShape.pill),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.space3,
                  vertical: tokens.space1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIconography.check, size: 16, color: r.accent),
                    SizedBox(width: tokens.space1),
                    KitText(
                      l10n.kitThemePreviewSegment,
                      role: KitTextRole.label,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.space3),
          Row(
            children: [
              Expanded(
                child: KitButton.primary(
                  label: l10n.kitThemePreviewPrimary,
                  onPressed: () {},
                ),
              ),
              SizedBox(width: tokens.space2),
              Expanded(
                child: KitButton.secondary(
                  label: l10n.kitThemePreviewSecondary,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// LOOK-39 for KitSwatch.accent's debug assert.
//
// Contract note (PROC-20, this unit's QA record): the frozen spec asks for
// "the same check deriveRoles uses" as a public `accentKeepsMeaning` in
// theme_roles.dart, but that function does not exist yet — it is listed as
// out of scope for this unit in docs/ux-system/kit-api/_new-tokens.md
// ("§0.5 step 1 theme work, not this unit's"), and theme_roles.dart is
// outside this unit's write set. This is a self-contained duplicate of the
// exact hue-distance/CIEDE2000 check test/theme_roles_test.dart already
// uses privately for the same rule (LOOK-39), kept here only for this
// widget's own debug assert. Once theme_roles.dart exports a public
// accentKeepsMeaning, this block should be deleted in favour of it.
// -----------------------------------------------------------------------

/// Whether [accent] keeps LOOK-39's distance (hue ≥ 30°, ΔE2000 ≥ 20) from
/// both [roles.attention] and [roles.danger].
bool _accentKeepsMeaning(Color accent, ThemeRoles roles) {
  for (final other in [roles.attention, roles.danger]) {
    if (_hueDistance(accent, other) < 30) return false;
    if (_deltaE2000(accent, other) < 20) return false;
  }
  return true;
}

double _hueDistance(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

/// CIE L*a*b* (D65) of an opaque sRGB colour.
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (r * .4124564 + g * .3575761 + b * .1804375) / .95047;
  final y = r * .2126729 + g * .7151522 + b * .0721750;
  final z = (r * .0193339 + g * .1191920 + b * .9503041) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// CIEDE2000 colour difference of two opaque sRGB colours (Sharma, Wu and
/// Dalal 2005), the same formula test/theme_roles_test.dart uses for
/// LOOK-39.
double _deltaE2000(Color c1, Color c2) {
  double rad(double deg) => deg * math.pi / 180;
  double deg(double rad) => rad * 180 / math.pi;
  final [l1, a1, b1] = _lab(c1);
  final [l2, a2, b2] = _lab(c2);
  final cBar =
      (math.sqrt(a1 * a1 + b1 * b1) + math.sqrt(a2 * a2 + b2 * b2)) / 2;
  final cBar7 = math.pow(cBar, 7);
  final g = .5 * (1 - math.sqrt(cBar7 / (cBar7 + math.pow(25, 7))));
  final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  final h1p = (deg(math.atan2(b1, a1p)) + 360) % 360;
  final h2p = (deg(math.atan2(b2, a2p)) + 360) % 360;
  final dLp = l2 - l1;
  final dCp = c2p - c1p;
  var dh = h2p - h1p;
  if (c1p * c2p == 0) {
    dh = 0;
  } else if (dh > 180) {
    dh -= 360;
  } else if (dh < -180) {
    dh += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dh / 2));
  final lBarp = (l1 + l2) / 2;
  final cBarp = (c1p + c2p) / 2;
  double hBarp;
  if (c1p * c2p == 0) {
    hBarp = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarp = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarp = (h1p + h2p + 360) / 2;
  } else {
    hBarp = (h1p + h2p - 360) / 2;
  }
  final t =
      1 -
      .17 * math.cos(rad(hBarp - 30)) +
      .24 * math.cos(rad(2 * hBarp)) +
      .32 * math.cos(rad(3 * hBarp + 6)) -
      .20 * math.cos(rad(4 * hBarp - 63));
  final dTheta = 30 * math.exp(-math.pow((hBarp - 275) / 25, 2));
  final cBarp7 = math.pow(cBarp, 7);
  final rc = 2 * math.sqrt(cBarp7 / (cBarp7 + math.pow(25, 7)));
  final sl =
      1 +
      .015 * math.pow(lBarp - 50, 2) / math.sqrt(20 + math.pow(lBarp - 50, 2));
  final sc = 1 + .045 * cBarp;
  final sh = 1 + .015 * cBarp * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;
  return math.sqrt(
    math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh),
  );
}
