import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import 'kit_icon.dart';
import 'kit_live_background.dart';
import 'kit_motion.dart';
import 'kit_tappable.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';
import 'live_background/live_mock_chat.dart';

/// One look, live, behind a tiny mock chat; the chosen one is marked.
class _LiveStyleTile extends StatelessWidget {
  const _LiveStyleTile({
    super.key,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final KitLiveStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final name = style.label(l10n);
    final reduced = KitMotion.reduced(context);
    final Duration d = reduced ? Duration.zero : KitMotion.standard;
    return KitTappable(
      onTap: onTap,
      label: selected ? l10n.liveStyleSelected(name) : name,
      selected: selected,
      role: KitTappableRole.button,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: d,
              curve: KitMotion.enter,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                border: Border.all(
                  color: selected ? roles.accent : roles.hairline,
                  width: selected
                      ? KitTokens.focusRingWidth(context)
                      : KitTokens.hairlineWidth(context),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(
                      child: KitLiveBackground(
                        style: style,
                        ignoreSetting: true,
                        child: liveMockChat(context, scale: .8),
                      ),
                    ),
                    // The mock's top-end holds its message pill and its bottom
                    // the composer: the empty middle is the badge's place.
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(end: tokens.space2),
                        child: AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: d,
                          curve: KitMotion.land,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: roles.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(tokens.space1),
                              child: IconTheme.merge(
                                data: IconThemeData(color: roles.onAccent),
                                child: const KitIcon(
                                  AppIconography.check,
                                  size: KitIconSize.small,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.space2),
          KitText(
            name,
            role: KitTextRole.secondary,
            tone: selected ? KitTextTone.primary : KitTextTone.secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The grid of looks. Built lazily, so only the tiles on screen run.
///
/// States: none — a fixed list of looks with no loading.
class KitLiveStylePicker extends StatelessWidget {
  const KitLiveStylePicker({
    super.key,
    required this.selectedId,
    required this.onOpen,
  });

  final String selectedId;
  final ValueChanged<KitLiveStyle> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final chosen = kitLiveStyleById(selectedId).id;
    return GridView.builder(
      padding: EdgeInsets.all(tokens.gutter),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: tokens.space4,
        crossAxisSpacing: tokens.space3,
        childAspectRatio: .5,
      ),
      itemCount: kitLiveStyles.length,
      itemBuilder: (context, i) {
        final style = kitLiveStyles[i];
        return _LiveStyleTile(
          key: ValueKey('live-style-${style.id}'),
          style: style,
          selected: style.id == chosen,
          onTap: () => onOpen(style),
        );
      },
    );
  }
}
