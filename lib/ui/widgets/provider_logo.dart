import 'package:flutter/widgets.dart';

import '../../api/provider_presentation.dart';
import '../app_theme.dart';
import '../kit/kit_image.dart';
import '../kit/kit_shape.dart';
import '../kit/kit_surface.dart';
import '../kit/kit_text.dart';

/// A provider's identity mark: a [KitAvatar] (KitImage.md, "Replaces").
///
/// The mark is the provider's website favicon, fetched at first use from
/// Google's favicon service (see [providerLogoUrl]; the URL is app-authored
/// and reaches the kit only as an [ImageProvider]) and cached by the image
/// pipeline like any other network image. While it loads, and whenever it
/// cannot load, the avatar shows the initials of the provider's presented
/// name instead, so a row never has an empty leading slot. OpenCode's own
/// providers show the terminal glyph rather than a fetched image.
///
/// Decorative: the row that shows the logo already names the provider, so
/// the mark is excluded from the semantics tree.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo(this.providerID, {super.key, this.size});

  final String providerID;

  /// Null: the avatar at its own tile size ([KitAvatarSize.tile], 30 dp),
  /// which lines up with every other row's leading tile. A number scales
  /// the whole mark to that square, for a logo set inline with text (the
  /// model picker's 18 and 24 dp marks).
  final double? size;

  /// Test seam. When set, every logo asks this for its [ImageProvider]
  /// instead of building a [NetworkImage]; returning null skips the image
  /// entirely and renders the initials, so widget tests never touch the
  /// network and render deterministically.
  static ImageProvider? Function(String url)? imageProviderOverride;

  /// Retired: [KitAvatar] decodes at its own laid-out size times the device
  /// pixel ratio (KitImage.md, "Decode size"). Kept for callers.
  static const int cacheWidth = 128;

  /// Retired: the loaded cross-fade is [KitImage]'s own, on
  /// `KitMotion.quick`. Kept for callers.
  static const Duration fadeIn = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    // The presented name's words ("fireworks-ai" -> "fireworks ai"), so
    // KitAvatar's initials take one letter from each of the first two.
    final words = presentProvider(providerID).name
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((word) => word.isNotEmpty)
        .join(' ');
    final name = words.isEmpty ? providerID : words;
    final Widget avatar;
    if (isOpenCodeProvider(providerID)) {
      avatar = KitAvatar(
        key: const ValueKey('provider-logo-prompt-glyph'),
        name: name,
        icon: AppIconography.terminal,
        decorative: true,
      );
    } else {
      final url = providerLogoUrl(providerID).toString();
      final override = imageProviderOverride;
      final image = override == null ? NetworkImage(url) : override(url);
      avatar = KitAvatar(
        name: name,
        image: image == null ? null : KitImageSource.provider(image),
        decorative: true,
      );
    }
    final dimension = size;
    if (dimension == null) return avatar;
    return SizedBox.square(
      dimension: dimension,
      child: FittedBox(child: avatar),
    );
  }
}

/// Retired by kit-KitImage: [KitAvatar] draws the initials itself. A thin
/// forwarding wrapper kept for callers (STANDARDS KIT-43: no `@Deprecated`,
/// which would put infos into every caller's analyze).
///
/// The two-letter stand-in for a provider's logo, in the label role.
class ProviderMonogram extends StatelessWidget {
  const ProviderMonogram(this.providerID, {super.key, required this.size});

  final String providerID;

  /// Unused: the label role sets the size. Kept for callers.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: KitText(
      providerMonogram(providerID),
      role: KitTextRole.label,
      tone: KitTextTone.secondary,
      maxLines: 1,
      softWrap: false,
    ),
  );
}

/// Retired by kit-KitImage: use [KitSurface.tile] for an icon, or
/// [KitAvatar] for an identity. A thin forwarding wrapper kept for callers
/// (STANDARDS KIT-43: no `@Deprecated`).
///
/// A [size] square of `surface3` in the kit's tile shape, with [child]
/// centred. Decorative: excluded from semantics, as before.
class BrandTile extends StatelessWidget {
  const BrandTile({
    super.key,
    required this.size,
    required this.child,
    this.color,
  });

  final double size;
  final Widget child;

  /// Unused: the fill is always `surface3` (a colour never encodes
  /// identity). Kept for callers.
  final Color? color;

  /// Retired: the kit's tile shape sets the corners. Kept for callers.
  static double radiusFor(double size) =>
      AppTheme.radiusControl * .6 * (size / 28).clamp(.6, 1.0);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: KitSurface(
      level: KitSurfaceLevel.surface3,
      shape: KitShape.tile,
      padding: KitSurfacePadding.none,
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    ),
  );
}
