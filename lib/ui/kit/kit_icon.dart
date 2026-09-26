// KitIcon (docs/ux-system/kit-api/KitIcon.md, wave 1, tier 1a): the one way
// to draw a glyph. It replaces every `Icon(` and `AppGlyph(` outside the
// kit, so there is one icon vocabulary (AppIconography, AppIcons) and one
// size scale (VL §7: 20/22/24, s/m/l).
//
// `AppGlyph` and `AppBrandMark` moved here unchanged (R12: moved, not
// duplicated; KIT-43) from `lib/ui/app_iconography.dart`, which now
// re-exports them so every existing import keeps compiling.
//
// Contract problem (PROC-20, docs/qa/revamp-kit-KitIcon/README.md): KitIcon.md
// names a shared `KitTokens.toneFor` / `toneColor(AppStatusTone)` as an
// already-available pre-wave seam ("Open questions: None"). It is not one:
// `docs/ux-system/kit-api/_new-tokens.md`'s own "Not added here" section
// says the D12 table it needs was never written, and
// `docs/ux-system/revamp/STANDARDS.md` §0.5 step 2 does not list it among
// the seams the coordinator adds before wave 1. Wave-1 units may not edit
// `kit_tokens.dart` (§0.5 step 3), so this unit cannot add the shared token
// either. [KitIcon.status] implements the D12 mapping the spec's prose
// describes (`_statusTone`, below) directly, through the existing
// `KitText.toneColor`, instead of inventing a fourth behaviour or blocking
// on a token nothing else has built yet. `blocks: false`: every acceptance
// criterion and required test for this unit still passes. Once the
// coordinator adds `KitTokens.toneFor`, `_statusTone` should be deleted in
// its favour.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_theme.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// The three designed sizes (VL §7, LOOK-33; s/m/l per cut review C02).
enum KitIconSize {
  /// 20: inline beside secondary text, a row's tile, a fold chevron.
  small,

  /// 22: a confirmation's mark, a card header.
  medium,

  /// 24: an icon-only control, navigation ([AppIconography.actionSize]).
  large;

  /// The size in logical pixels: 20, 22 or 24. No other value exists
  /// (LOOK-33; "No sizes other than 20, 22 and 24").
  double get logical => switch (this) {
    KitIconSize.small => 20,
    KitIconSize.medium => 22,
    KitIconSize.large => 24,
  };
}

/// The duotone navigation glyphs' quiet background layer, keyed by the
/// selected glyph's code point. Moved unchanged from `app_iconography.dart`
/// (KIT-43); [AppGlyph] below still reads it directly, and [KitIcon] reads
/// it through [_backgroundOf].
const _duotoneBackgrounds = <int, IconData>{
  0xe17f: IconData(
    0xe17e,
    fontFamily: 'AppPhosphorDuotone',
    matchTextDirection: false,
  ),
  0xe25b: IconData(
    0xe25a,
    fontFamily: 'AppPhosphorDuotone',
    matchTextDirection: false,
  ),
  0xe0d1: IconData(
    0xe0d0,
    fontFamily: 'AppPhosphorDuotone',
    matchTextDirection: false,
  ),
};

IconData? _backgroundOf(IconData icon) =>
    icon.fontFamily == 'AppPhosphorDuotone'
    ? _duotoneBackgrounds[icon.codePoint]
    : null;

/// The kit's one [AppStatusTone] tone map (README.md decision D12), pending
/// the shared `KitTokens.toneFor` (see the file header's contract problem):
/// neutral → secondary, progress → accent, ok → success, attention →
/// primary, failure → primary. Attention's amber belongs only to the
/// needs-you parts (LOOK-4, LOOK-24); a failure is said in words and a
/// neutral error glyph, not in red (LOOK-5, B2 interim).
KitTextTone _statusTone(AppStatusTone status) => switch (status) {
  AppStatusTone.neutral => KitTextTone.secondary,
  AppStatusTone.progress => KitTextTone.accent,
  AppStatusTone.ok => KitTextTone.success,
  AppStatusTone.attention => KitTextTone.primary,
  AppStatusTone.failure => KitTextTone.primary,
};

/// KitIcon is the one way to draw a glyph (kit-v2.md §9, KitIcon.md).
///
/// It takes a glyph from the app's named Phosphor set ([AppIconography],
/// with verbs in [AppIcons]) and draws it at one of three designed sizes
/// ([KitIconSize]), in an opaque colour role, aligned to whole physical
/// pixels, decorative by default.
///
/// States: KitIcon has no loading, empty, error or working state (those
/// belong to the host); a disabled icon is the host passing
/// `tone: KitTextTone.tertiary` (no opacity, LOOK-14); [KitIcon.status]
/// covers neutral, progress, ok, attention and failure; a duotone glyph
/// (the navigation `…Selected` glyphs) is selected, drawn automatically
/// when [icon] has a registered background layer.
///
/// Motion and haptics: none (LOOK-33, R23; a rotating chevron is
/// `KitSpin.chevron`, a glyph swap is `KitSwap`).
class KitIcon extends StatelessWidget {
  /// [icon] must come from the app's set: an [AppIconography] glyph or an
  /// [AppIcons] verb. A debug assert rejects any other font family, for
  /// example Material's `Icons.*`.
  const KitIcon(
    this.icon, {
    super.key,
    this.size = KitIconSize.large,
    this.tone,
    this.growsWithText = false,
    this.semanticsLabel,
  }) : _status = null;

  /// An icon that says a status, in the tone for [status]: the kit's tone
  /// map, [_statusTone] (README.md decision D12; see the file header for
  /// why this is not yet `KitTokens.toneFor`).
  const KitIcon.status(
    this.icon,
    AppStatusTone status, {
    super.key,
    this.size = KitIconSize.small,
    this.growsWithText = true,
    this.semanticsLabel,
  }) : tone = null,
       _status = status;

  /// Must come from [AppIconography] or [AppIcons] (a debug assert checks
  /// the font family).
  final IconData icon;

  final KitIconSize size;

  /// Null: the ambient icon colour the enclosing kit part set
  /// ([IconTheme.of]), else `text1`. Always null on [KitIcon.status], which
  /// sets its own tone from the status.
  final KitTextTone? tone;

  final AppStatusTone? _status;

  /// Leading and state icons only (LOOK-33, B16 interim): with this true,
  /// the icon grows with the person's text size up to `KitTokens.maxIconScale`
  /// (1.5), rounded to a whole physical pixel. Without it, the size is
  /// exactly 20, 22 or 24 whatever the text scale.
  final bool growsWithText;

  /// Null: decorative, excluded from semantics (A11Y-1: the control or row
  /// beside it carries the words). Use this only for a standalone
  /// informative glyph.
  final String? semanticsLabel;

  Color _resolveColor(BuildContext context, ThemeRoles roles) {
    final status = _status;
    if (status != null) return KitText.toneColor(roles, _statusTone(status));
    final explicit = tone;
    if (explicit != null) return KitText.toneColor(roles, explicit);
    return IconTheme.of(context).color ??
        KitText.toneColor(roles, KitTextTone.primary);
  }

  double _resolveDimension(BuildContext context) {
    final logical = size.logical;
    if (!growsWithText) return logical;
    final grown = KitTokens.of(context).iconSize(context, logical);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return dpr > 0 ? (grown * dpr).round() / dpr : grown;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      icon.fontFamily != null && icon.fontFamily!.startsWith('AppPhosphor'),
      'KitIcon: "$icon" is not from AppIconography/AppIcons (font family '
      '${icon.fontFamily}). Material glyphs (Icons.*) never reach KitIcon '
      '(KitIcon.md "Replaces"): map the glyph to an AppIconography verb.',
    );
    final roles = ThemeRoles.resolve(Theme.of(context));
    final color = _resolveColor(context, roles);
    final dimension = _resolveDimension(context);
    final background = _backgroundOf(icon);
    final glyph = ExcludeSemantics(
      child: background == null || MediaQuery.highContrastOf(context)
          ? Icon(icon, size: dimension, color: color)
          : Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: KitTokens.duotoneWash,
                  child: Icon(background, size: dimension, color: color),
                ),
                Icon(icon, size: dimension, color: color),
              ],
            ),
    );
    final label = semanticsLabel;
    return label == null
        ? glyph
        : Semantics(label: label, image: true, child: glyph);
  }
}

/// The two sizes of [KitBrandMark] (KitIcon.md): the row leading tile, and
/// a standalone mark.
enum KitBrandMarkSize { tile, mark }

/// The open-portal mark (the retired [AppBrandMark]'s job). Decorative
/// unless labelled. It is drawn from `assets/branding/open-portal/mark.svg`
/// in the accent.
class KitBrandMark extends StatelessWidget {
  const KitBrandMark({
    super.key,
    this.size = KitBrandMarkSize.tile,
    this.semanticsLabel,
  });

  final KitBrandMarkSize size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final dimension = size == KitBrandMarkSize.tile
        ? tokens.iconTileSize
        : tokens.markSize;
    final mark = SvgPicture.asset(
      'assets/branding/open-portal/mark.svg',
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(tokens.roles.accent, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    final label = semanticsLabel;
    return label == null
        ? mark
        : Semantics(label: label, image: true, child: mark);
  }
}

/// Retired by kit-KitIcon: use [KitIcon].
///
/// Renders regular and duotone glyphs with one optional accessibility label.
///
/// This is decoration, not a tap target: place it inside an IconButton or other
/// accessible control. Let that control's tooltip or visible text name the
/// action; use [semanticLabel] only for a standalone informative glyph.
class AppGlyph extends StatelessWidget {
  const AppGlyph(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// Pass an explicit direction for technical marks that must not mirror.
  /// Navigation arrows follow the surrounding direction by default; technical
  /// glyph data preserves its orientation.
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final foreground = Icon(
      icon,
      size: size,
      color: color,
      textDirection: textDirection,
    );
    final secondary = _backgroundOf(icon);
    final glyph = ExcludeSemantics(
      child: secondary == null || MediaQuery.highContrastOf(context)
          ? foreground
          : Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: .2,
                  child: Icon(
                    secondary,
                    size: size,
                    color: color,
                    textDirection: textDirection,
                  ),
                ),
                foreground,
              ],
            ),
    );
    final label = semanticLabel;
    return label == null
        ? glyph
        : Semantics(label: label, image: true, child: glyph);
  }
}

/// Retired by kit-KitIcon: use [KitBrandMark].
///
/// The open portal identity without a launcher background or shadow.
///
/// Decorative by default. A standalone mark may supply [semanticLabel]; a
/// neighboring app title already communicates the identity and needs no label.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 32, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      'assets/branding/open-portal/mark.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
    final label = semanticLabel;
    return label == null
        ? mark
        : Semantics(label: label, image: true, child: mark);
  }
}
