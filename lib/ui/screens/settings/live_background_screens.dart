import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../kit/kit.dart';

/// Settings › Appearance › Live background › Look: the grid of live looks.
/// Tapping one previews it full screen; "Use this" keeps it for this device.
class LiveStylePickerScreen extends StatelessWidget {
  const LiveStylePickerScreen({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<KitEffects>(
      valueListenable: controller.effects,
      builder: (context, effects, _) => KitScreen(
        topBar: KitTopBar(title: l10n.liveStylePickerTitle),
        body: KitLiveStylePicker(
          selectedId: effects.liveStyle,
          onOpen: (style) => pushKitPage<void>(
            context,
            (_) => LiveStylePreviewScreen(controller: controller, style: style),
          ),
        ),
      ),
    );
  }
}

/// One look full screen behind a mock chat.
class LiveStylePreviewScreen extends StatelessWidget {
  const LiveStylePreviewScreen({
    super.key,
    required this.controller,
    required this.style,
  });

  final ConnectionController controller;
  final KitLiveStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<KitEffects>(
      valueListenable: controller.effects,
      builder: (context, effects, _) => KitScreen(
        topBar: KitTopBar(title: style.label(l10n)),
        body: KitLiveStylePreview(
          style: style,
          isCurrent: effects.liveStyle == style.id,
          onUse: () async {
            await controller.setEffects(effects.copyWith(liveStyle: style.id));
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
