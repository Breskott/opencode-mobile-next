import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
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

/// Browsing never mutates the stored preference. Save errors stay in the
/// sheet, keeping the draft available to retry or discard.
Future<void> showAppearancePicker(
  BuildContext context, {
  required ConnectionController controller,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (_) => _AppearancePreviewSheet(controller: controller),
);

Future<void> showThemePackPreview(
  BuildContext context, {
  required ConnectionController controller,
  required ThemePackId pack,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (_) => _AppearancePreviewSheet(controller: controller, pack: pack),
);

class _AppearancePreviewSheet extends StatefulWidget {
  final ConnectionController controller;
  final ThemePackId? pack;
  const _AppearancePreviewSheet({required this.controller, this.pack});

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
    try {
      if (widget.pack case final pack?) {
        await widget.controller.setThemePack(pack);
      } else {
        await widget.controller.setAppearance(_appearance);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    final packId = widget.pack ?? widget.controller.themePack.value;
    final available =
        packId != ThemePackId.dynamic || harvestedDynamicPack.value != null;
    final brightness = switch (_appearance) {
      AppAppearance.system => MediaQuery.platformBrightnessOf(context),
      AppAppearance.light => Brightness.light,
      AppAppearance.dark => Brightness.dark,
    };
    final changed = widget.pack == null
        ? _appearance != widget.controller.appearance.value
        : widget.pack != widget.controller.themePack.value;
    return PopScope(
      canPop: !_saving,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: ListView(
          key: const Key('appearance-picker'),
          shrinkWrap: true,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
          children: [
            Text(
              widget.pack == null
                  ? copy.e7AppearanceTitle
                  : themePackLabels[packId]!,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(copy.e7AppearancePreviewHint),
            const SizedBox(height: 16),
            if (available)
              ThemeComponentPreview(
                theme: AppTheme.forLocale(
                  AppTheme.fromPalette(
                    effectiveThemePack(packId).palette(brightness),
                  ),
                  Localizations.localeOf(context),
                ),
              )
            else
              Text(copy.e7AppearanceDynamicUnavailable),
            const SizedBox(height: 12),
            if (widget.pack == null)
              for (final appearance in AppAppearance.values)
                Semantics(
                  selected: _appearance == appearance,
                  child: ListTile(
                    key: ValueKey('appearance-${appearance.name}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_appearanceIcon(appearance)),
                    title: Text(appearanceLabel(appearance, context)),
                    subtitle: Text(_appearanceDescription(context, appearance)),
                    trailing: _appearance == appearance
                        ? const Icon(AppIconography.check)
                        : null,
                    onTap: _saving
                        ? null
                        : () => setState(() => _appearance = appearance),
                  ),
                )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in [AppAppearance.light, AppAppearance.dark])
                    ChoiceChip(
                      label: Text(appearanceLabel(mode, context)),
                      selected:
                          _appearance == mode ||
                          (_appearance == AppAppearance.system &&
                              (mode == AppAppearance.light) ==
                                  (brightness == Brightness.light)),
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _appearance = mode),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                copy.e7AppearanceUsesMode(
                  appearanceLabel(widget.controller.appearance.value, context),
                ),
              ),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  copy.e7AppearanceSaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: changed && available && !_saving ? _apply : null,
              child: Text(
                _saving
                    ? copy.e7AppearanceSaving
                    : changed
                    ? copy.e7AppearanceApply
                    : copy.e7AppearanceCurrent,
              ),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(copy.e7AppearanceClose),
            ),
          ],
        ),
      ),
    );
  }
}

/// Actual app theme text, code, filled control and selected surface roles.
/// Contains no server data or invented activity; interactions are local samples.
class ThemeComponentPreview extends StatefulWidget {
  final ThemeData theme;
  const ThemeComponentPreview({super.key, required this.theme});

  @override
  State<ThemeComponentPreview> createState() => _ThemeComponentPreviewState();
}

class _ThemeComponentPreviewState extends State<ThemeComponentPreview> {
  bool _selected = true;

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    return Theme(
      data: widget.theme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Material(
            key: const ValueKey('theme-component-preview'),
            color: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    copy.e7AppearancePreviewTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.e7AppearancePreviewBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'final ready = true;',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: AppTheme.monoFamily,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: Text(copy.e7AppearanceSelection),
                        selected: _selected,
                        onSelected: (value) =>
                            setState(() => _selected = value),
                      ),
                      FilledButton(
                        onPressed: () => setState(() => _selected = !_selected),
                        child: Text(copy.e7AppearanceTryControl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.e7AppearanceSampleHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
