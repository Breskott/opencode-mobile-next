import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'kit_buttons.dart';
import 'kit_live_background.dart';
import 'kit_row_parts.dart';
import 'kit_tokens.dart';
import 'live_background/live_mock_chat.dart';

/// A look full screen behind the mock chat, with a "Reply running" switch to
/// see how it answers a working agent, and "Use this".
///
/// States: none — the switch is local and the look is always ready.
class KitLiveStylePreview extends StatefulWidget {
  const KitLiveStylePreview({
    super.key,
    required this.style,
    required this.isCurrent,
    required this.onUse,
  });

  final KitLiveStyle style;
  final bool isCurrent;
  final VoidCallback onUse;

  @override
  State<KitLiveStylePreview> createState() => _KitLiveStylePreviewState();
}

class _KitLiveStylePreviewState extends State<KitLiveStylePreview> {
  final ValueNotifier<bool> _running = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _running.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    return KitLiveBackground(
      style: widget.style,
      ignoreSetting: true,
      replyRunning: _running,
      child: Column(
        children: [
          Expanded(child: liveMockChat(context)),
          Padding(
            padding: EdgeInsets.all(tokens.gutter),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: roles.surface1,
                borderRadius: BorderRadius.circular(tokens.cardRadius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _running,
                    builder: (context, on, _) => KitSwitchRow(
                      key: const ValueKey('live-style-running'),
                      title: l10n.liveStyleReplyRunning,
                      value: on,
                      onChanged: (v) => _running.value = v,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: tokens.gutter,
                      end: tokens.gutter,
                      bottom: tokens.space3,
                    ),
                    child: KitButton.primary(
                      key: const ValueKey('live-style-use'),
                      label: l10n.liveStyleUse,
                      onPressed: widget.isCurrent ? null : widget.onUse,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
