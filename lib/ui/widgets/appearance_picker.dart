/// The light-or-dark sheet (map page `appearance-picker-sheet`) and the
/// theme preview sheet (map page `theme-pack-preview-sheet`), both on the
/// kit sheet.
///
/// Browsing never changes the stored preference: the sheet previews the
/// choice on the app's real parts ([KitThemePreview]) and only Apply saves
/// it. A save error stays in the sheet, keeping the draft to retry. A theme
/// that is applied offers Undo; one already in use says so in words, never
/// with a disabled button.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_choice_list.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_segmented.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_swatch.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/kit_undo.dart';
import '../theme_packs.dart';

AppLocalizations _copy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

String appearanceLabel(AppAppearance appearance, [BuildContext? context]) {
  final copy = context == null
      ? lookupAppLocalizations(const Locale('en'))
      : _copy(context);
  return switch (appearance) {
    AppAppearance.system =>
      platformCapabilities.isAndroid
          ? copy.e7AppearanceFollowAndroid
          : copy.e7AppearanceFollowSystem,
    AppAppearance.light => copy.e7AppearanceLight,
    AppAppearance.dark => copy.e7AppearanceDark,
  };
}

String _appearanceDescription(BuildContext context, AppAppearance appearance) {
  final copy = _copy(context);
  return switch (appearance) {
    AppAppearance.system =>
      platformCapabilities.isAndroid
          ? copy.e7AppearanceFollowPhoneDescription
          : copy.e7AppearanceFollowDeviceDescription,
    AppAppearance.light => copy.e7AppearanceLightDescription,
    AppAppearance.dark => copy.e7AppearanceDarkDescription,
  };
}

IconData _appearanceIcon(AppAppearance appearance) => switch (appearance) {
  AppAppearance.system => AppIconography.systemTheme,
  AppAppearance.light => AppIconography.lightMode,
  AppAppearance.dark => AppIconography.darkMode,
};

/// Opens the light-or-dark sheet. Browsing never mutates the stored
/// preference.
Future<void> showAppearancePicker(
  BuildContext context, {
  required ConnectionController controller,
}) => showKitSheet<void>(
  context,
  title: _copy(context).e7AppearanceTitle,
  sheetKey: const Key('appearance-picker'),
  body: (_) => _AppearancePreviewSheet(controller: controller, host: context),
);

/// Opens the preview of [pack]; Apply makes it the app's theme and offers
/// Undo.
Future<void> showThemePackPreview(
  BuildContext context, {
  required ConnectionController controller,
  required ThemePackId pack,
}) => showKitSheet<void>(
  context,
  title: themePackLabels[pack]!,
  sheetKey: const Key('appearance-picker'),
  body: (_) => _AppearancePreviewSheet(
    controller: controller,
    host: context,
    pack: pack,
  ),
);

// revamp: remove (slice-P3.1) — for the light-or-dark use ([pack] null,
// map page appearance-picker-sheet); the theme preview use is kept (fix).
class _AppearancePreviewSheet extends StatefulWidget {
  const _AppearancePreviewSheet({
    required this.controller,
    required this.host,
    this.pack,
  });

  final ConnectionController controller;

  /// The context the sheet was opened from: the Undo bar shows there once
  /// the sheet has closed.
  final BuildContext host;
  final ThemePackId? pack;

  @override
  State<_AppearancePreviewSheet> createState() =>
      _AppearancePreviewSheetState();
}

class _AppearancePreviewSheetState extends State<_AppearancePreviewSheet> {
  late AppAppearance _appearance = widget.controller.appearance.value;
  bool _saving = false;
  bool _failed = false;

  Future<void> _apply() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final controller = widget.controller;
    final previous = controller.themePack.value;
    try {
      if (widget.pack case final pack?) {
        await controller.setThemePack(pack);
      } else {
        await controller.setAppearance(_appearance);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    final copy = _copy(context);
    KitSheet.close<void>(context);
    if (widget.pack case final pack? when widget.host.mounted) {
      showKitUndo(
        widget.host,
        key: const Key('appearance-theme-undo'),
        message: copy.appearancePickerThemeApplied(themePackLabels[pack]!),
        onUndo: () => controller.setThemePack(previous),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    final tokens = KitTokens.of(context);
    final pack = widget.pack;
    final packId = pack ?? widget.controller.themePack.value;
    final available =
        packId != ThemePackId.dynamic || harvestedDynamicPack.value != null;
    final brightness = switch (_appearance) {
      AppAppearance.system => MediaQuery.platformBrightnessOf(context),
      AppAppearance.light => Brightness.light,
      AppAppearance.dark => Brightness.dark,
    };
    final changed = pack == null
        ? _appearance != widget.controller.appearance.value
        : pack != widget.controller.themePack.value;
    final previewed = pack == null
        ? appearanceLabel(_appearance, context)
        : themePackLabels[packId]!;
    return PopScope(
      canPop: !_saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KitText(copy.e7AppearancePreviewHint, role: KitTextRole.secondary),
          SizedBox(height: tokens.space3),
          if (available)
            KitThemePreview(
              previewKey: const ValueKey('theme-component-preview'),
              roles: effectiveThemePack(packId).palette(brightness).themeRoles,
              label: copy.appearancePickerPreviewLabel(previewed),
            )
          else
            KitNotice(
              key: const ValueKey('appearance-dynamic-unavailable'),
              message: copy.e7AppearanceDynamicUnavailable,
              icon: AppIconography.info,
              liveRegion: false,
            ),
          SizedBox(height: tokens.space4),
          if (pack == null)
            KitChoiceList<AppAppearance>.single(
              semanticsLabel: copy.e7AppearanceTitle,
              actsOnTap: false,
              choices: [
                for (final appearance in AppAppearance.values)
                  KitChoice(
                    value: appearance,
                    key: ValueKey('appearance-${appearance.name}'),
                    title: appearanceLabel(appearance, context),
                    supporting: _appearanceDescription(context, appearance),
                    leading: KitRow.icon(context, _appearanceIcon(appearance)),
                  ),
              ],
              selected: _appearance,
              onSelected: (appearance) {
                if (_saving) return;
                setState(() => _appearance = appearance);
              },
            )
          else if (available) ...[
            KitSegmented<AppAppearance>(
              semanticsLabel: copy.appearancePickerPreviewIn,
              segments: [
                for (final mode in const [
                  AppAppearance.light,
                  AppAppearance.dark,
                ])
                  KitSegment(
                    value: mode,
                    key: ValueKey('appearance-preview-${mode.name}'),
                    label: appearanceLabel(mode, context),
                    icon: _appearanceIcon(mode),
                  ),
              ],
              selected: brightness == Brightness.light
                  ? AppAppearance.light
                  : AppAppearance.dark,
              onChanged: _saving
                  ? null
                  : (mode) => setState(() => _appearance = mode),
              disabledReason: _saving ? copy.e7AppearanceSaving : null,
            ),
            SizedBox(height: tokens.space2),
            KitText(
              copy.e7AppearanceUsesMode(
                appearanceLabel(widget.controller.appearance.value, context),
              ),
              role: KitTextRole.secondary,
            ),
          ],
          if (_failed) ...[
            SizedBox(height: tokens.space3),
            KitNotice(
              key: const ValueKey('appearance-save-failed'),
              message: copy.e7AppearanceSaveFailed,
              tone: AppStatusTone.failure,
            ),
          ],
          SizedBox(height: tokens.space4),
          // An unavailable theme has nothing to apply; the notice above
          // says why.
          if (!available)
            const SizedBox.shrink()
          else if (changed)
            KitActionBlock(
              primary: KitAction(
                key: const ValueKey('appearance-apply'),
                label: copy.e7AppearanceApply,
                working: _saving,
                onPressed: _apply,
              ),
            )
          else
            KitNotice(
              key: const ValueKey('appearance-in-use'),
              message: copy.appearancePickerInUse,
              tone: AppStatusTone.ok,
              icon: AppIconography.check,
              liveRegion: false,
            ),
        ],
      ),
    );
  }
}
