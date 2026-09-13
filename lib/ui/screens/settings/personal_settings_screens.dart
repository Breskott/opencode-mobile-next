part of '../settings_screen.dart';

/// Appearance category: light/dark mode plus the theme-pack picker with
/// live swatch previews.
class AppearanceSettingsScreen extends StatelessWidget {
  final ConnectionController controller;
  const AppearanceSettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7AppearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ValueListenableBuilder<AppAppearance>(
            valueListenable: controller.appearance,
            builder: (context, appearance, _) => ListTile(
              key: const ValueKey('appearance-settings-entry'),
              leading: const Icon(AppIconography.contrast),
              title: Text(_settingsCopy(context).e7SettingsUi69),
              subtitle: Text(appearanceLabel(appearance, context)),
              trailing: const Icon(AppIconography.chevronRight),
              onTap: () =>
                  showAppearancePicker(context, controller: controller),
            ),
          ),
          LanguageSettingsTile(controller: controller),
          SectionLabel(_settingsCopy(context).e7SettingsUi70),
          ListenableBuilder(
            listenable: Listenable.merge([
              controller.themePack,
              harvestedDynamicPack,
            ]),
            builder: (context, _) {
              final selected = controller.themePack.value;
              final brightness = Theme.of(context).brightness;
              return Column(
                children: [
                  for (final id in ThemePackId.values)
                    _ThemePackTile(
                      id: id,
                      selected: selected == id,
                      brightness: brightness,
                      available:
                          id != ThemePackId.dynamic ||
                          harvestedDynamicPack.value != null,
                      onSelect: () => showThemePackPreview(
                        context,
                        controller: controller,
                        pack: id,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemePackTile extends StatelessWidget {
  final ThemePackId id;
  final bool selected;
  final bool available;
  final Brightness brightness;
  final VoidCallback onSelect;

  const _ThemePackTile({
    required this.id,
    required this.selected,
    required this.available,
    required this.brightness,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final pack = id == ThemePackId.dynamic
        ? harvestedDynamicPack.value
        : themePack(id);
    final palette = pack?.palette(brightness);
    final swatches = palette == null
        ? const <Color>[]
        : [
            palette.background,
            palette.scheme.surfaceContainerHigh,
            palette.scheme.primary,
            palette.success,
          ];
    return ListTile(
      key: ValueKey('theme-pack-${id.name}'),
      enabled: available,
      leading: SizedBox(
        width: 56,
        child: palette == null
            ? const Icon(AppIconography.sparkle)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in swatches)
                    Container(
                      width: 12,
                      height: 24,
                      margin: const EdgeInsetsDirectional.only(end: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      title: Text(themePackLabels[id]!),
      subtitle: Text(
        !available
            ? _settingsCopy(context).e7AppearanceDynamicUnavailable
            : _themeDescription(context, id),
      ),
      trailing: selected ? const Icon(AppIconography.check) : null,
      onTap: available ? onSelect : null,
    );
  }
}

/// Privacy & permissions category: durable OpenCode grants, and the unsent
/// work this device is holding on the user's behalf.
class PrivacySettingsScreen extends StatefulWidget {
  final ConnectionController controller;
  const PrivacySettingsScreen({super.key, required this.controller});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _busy = false;
  bool _readPreferenceFailed = false;

  ConnectionController get _controller => widget.controller;

  /// Rounded the way a phone's storage screens round: one decimal past a
  /// kilobyte, and never "0 B" for something that exists.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmAndClear({
    required String title,
    required String body,
    required Future<bool> Function() clear,
    required String cleared,
    required String failed,
  }) async {
    final ok = await showConfirmSheet(
      context,
      title: title,
      message: body,
      confirmLabel: _settingsCopy(context).promptStashDelete,
      icon: AppIconography.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final succeeded = await clear();
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(succeeded ? cleared : failed),
        backgroundColor: succeeded ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7SettingsUi5)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (!_controller.supportsSessionReadState) {
                return const SizedBox.shrink();
              }
              final l10n =
                  Localizations.of<AppLocalizations>(
                    context,
                    AppLocalizations,
                  ) ??
                  lookupAppLocalizations(const Locale('en'));
              return Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('share-session-views'),
                    title: Text(l10n.shareSessionViewsTitle),
                    subtitle: Text(
                      _controller.shareSessionViews
                          ? l10n.shareSessionViewsOn
                          : l10n.shareSessionViewsOff,
                    ),
                    value: _controller.shareSessionViews,
                    onChanged: _controller.savingReadPrivacy
                        ? null
                        : (value) async {
                            setState(() => _readPreferenceFailed = false);
                            try {
                              await _controller.setShareSessionViews(value);
                            } catch (_) {
                              if (mounted) {
                                setState(() => _readPreferenceFailed = true);
                              }
                            }
                          },
                  ),
                  if (_readPreferenceFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.shareSessionViewsSaveError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          ListTile(
            key: const ValueKey('saved-permissions-entry'),
            leading: const Icon(AppIconography.privacy),
            title: Text(_settingsCopy(context).e7SettingsUi74),
            subtitle: Text(_settingsCopy(context).e7SettingsUi75),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SavedPermissionsScreen(controller: _controller),
              ),
            ),
          ),
          SectionLabel(_settingsCopy(context).e7SettingsUi76),
          // Queued prompts carry attachment data URLs and drafts carry
          // whatever was typed but never sent. Both are the user's content,
          // held indefinitely until a server answers, so both get a size and
          // a way out that does not require deleting the server.
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final queued = _controller.totalQueuedPromptCount;
              final drafts = _controller.totalSessionDraftCount;
              final queuedBytes = _controller.queuedPromptBytes;
              final queueReadable = _controller.queuedPromptStorageReadable;
              final l10n = lookupAppLocalizations(
                Localizations.localeOf(context),
              );
              final draftBytes = _controller.sessionDraftBytes;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    key: const ValueKey('local-storage-usage'),
                    leading: const Icon(Icons.sd_storage_outlined),
                    title: Text(_settingsCopy(context).e7SettingsUi77),
                    subtitle: Text(
                      !queueReadable
                          ? l10n.queueStorageCountUnknown
                          : _settingsCopy(context).e7SettingsStorageSummary(
                              formatBytes(queuedBytes + draftBytes),
                              queued,
                              formatBytes(queuedBytes),
                              drafts,
                              formatBytes(draftBytes),
                              OfflineQueueStore.maxAge.inDays,
                            ),
                    ),
                  ),
                  ListTile(
                    key: const ValueKey('clear-queued-prompts'),
                    leading: const Icon(AppIconography.outbox),
                    title: Text(_settingsCopy(context).e7SettingsUi78),
                    subtitle: Text(
                      !queueReadable
                          ? l10n.queueStorageUnreadable
                          : queued == 0
                          ? _settingsCopy(context).e7SettingsUi79
                          : _settingsCopy(
                              context,
                            ).e7SettingsQueueDeleteSummary(queued),
                    ),
                    enabled: (queued > 0 || !queueReadable) && !_busy,
                    onTap: () => _confirmAndClear(
                      title: _settingsCopy(context).e7SettingsUi80,
                      body: !queueReadable
                          ? l10n.queueStorageDiscardUnreadable
                          : _settingsCopy(
                              context,
                            ).e7SettingsQueueDeleteBody(queued),
                      clear: _controller.clearAllQueuedPrompts,
                      cleared: _settingsCopy(context).e7SettingsUi81,
                      failed: _settingsCopy(context).e7SettingsUi82,
                    ),
                  ),
                  ListTile(
                    key: const ValueKey('clear-session-drafts'),
                    leading: const Icon(AppIconography.editNote),
                    title: Text(_settingsCopy(context).e7SettingsUi83),
                    subtitle: Text(
                      drafts == 0
                          ? _settingsCopy(context).e7SettingsUi84
                          : _settingsCopy(
                              context,
                            ).e7SettingsDraftDeleteSummary(drafts),
                    ),
                    enabled: drafts > 0 && !_busy,
                    onTap: () => _confirmAndClear(
                      title: _settingsCopy(context).e7SettingsUi85,
                      body: _settingsCopy(
                        context,
                      ).e7SettingsDraftDeleteBody(drafts),
                      clear: _controller.clearAllSessionDrafts,
                      cleared: _settingsCopy(context).e7SettingsUi86,
                      failed: _settingsCopy(context).e7SettingsUi87,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Diagnostics category: the process-local error ring.
class DiagnosticsSettingsScreen extends StatelessWidget {
  final ConnectionController controller;
  const DiagnosticsSettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7SettingsUi6)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListenableBuilder(
            listenable: controller.diagnostics,
            builder: (context, _) {
              final count = controller.diagnostics.count;
              return ListTile(
                key: const ValueKey('app-diagnostics-entry'),
                leading: const Icon(AppIconography.privacy),
                title: Text(_settingsCopy(context).e7SettingsUi88),
                subtitle: Text(
                  count == 0
                      ? _settingsCopy(context).e7SettingsUi89
                      : _settingsCopy(context).e7SettingsDiagnosticCount(count),
                ),
                trailing: const Icon(AppIconography.chevronRight),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AppDiagnosticsScreen(controller: controller),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// About category: guide, privacy, licenses, and app details.
class AboutSettingsScreen extends StatelessWidget {
  final ConnectionController controller;
  const AboutSettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7SettingsUi7)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            key: const ValueKey('settings-setup-guide'),
            leading: const Icon(AppIconography.guide),
            title: Text(_settingsCopy(context).onboardingSetupGuide),
            subtitle: Text(_settingsCopy(context).e7SettingsUi91),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuideScreen(embedded: false),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(_settingsCopy(context).e7SettingsUi92),
            subtitle: Text(_settingsCopy(context).e7SettingsUi93),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
          // The voice notices cover models this build can neither download
          // nor run off Android; the general notices below still list every
          // component that ships here.
          if (platformCapabilities.supportsVoice)
            ListTile(
              key: const Key('settings-voice-notices'),
              leading: const Icon(AppIconography.policy),
              title: Text(_settingsCopy(context).e7SettingsUi94),
              subtitle: Text(_settingsCopy(context).e7SettingsUi95),
              trailing: const Icon(AppIconography.chevronRight),
              onTap: () => showVoiceNotices(context),
            ),
          ListTile(
            leading: const Icon(AppIconography.info),
            title: Text(_settingsCopy(context).e7SettingsUi96),
            subtitle: Text(_settingsCopy(context).e7SettingsUi97),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AboutScreen(initialTab: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _themeDescription(BuildContext context, ThemePackId id) => switch (id) {
  ThemePackId.opencode => _settingsCopy(context).e7AppearancePackOpencode,
  ThemePackId.catppuccin => _settingsCopy(context).e7AppearancePackCatppuccin,
  ThemePackId.gruvbox => _settingsCopy(context).e7AppearancePackGruvbox,
  ThemePackId.solarized => _settingsCopy(context).e7AppearancePackSolarized,
  ThemePackId.dynamic => _settingsCopy(context).e7AppearancePackDynamic,
};
