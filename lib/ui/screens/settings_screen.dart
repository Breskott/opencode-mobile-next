import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api/provider_presentation.dart';
import '../../background/live_background.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/offline_queue.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../theme_packs.dart';
import '../../voice/notices.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/language_picker.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/product_states.dart';
import '../widgets/pickers.dart';
import 'about_screen.dart';
import 'app_diagnostics_screen.dart';
import 'guide_screen.dart';
import 'host_management_screen.dart';
import 'saved_permissions_screen.dart';
import 'usage_screen.dart';
import 'provider_quota_screen.dart';
import 'settings/plugins_screen.dart';
import '../early_l10n.dart';

part 'settings/server_settings_screen.dart';
part 'settings/coding_settings_screen.dart';
part 'settings/background_settings_screen.dart';
part 'settings/personal_settings_screens.dart';

/// Settings hub: a connection summary plus one row per category, following
/// the hub-and-spoke pattern in docs/design-inspiration.md. Every detail
/// lives one level deeper in a focused sub-page.
AppLocalizations _settingsCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

class SettingsScreen extends StatefulWidget {
  final ConnectionController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Health? _health;
  String? _healthError;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_connectionChanged);
    _checkHealth();
  }

  void _connectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkHealth() async {
    // Runs from initState, so inherited lookups are not yet allowed.
    final copy = earlyAppLocalizations(context);
    if (_checking) return;
    setState(() {
      _checking = true;
      _healthError = null;
    });
    try {
      final api = await widget.controller.prepareActionTransport();
      if (api == null) {
        throw ProductException(copy.e7SettingsUi18);
      }
      final health = await api.health();
      if (mounted) setState(() => _health = health);
    } catch (error) {
      if (mounted) setState(() => _healthError = productErrorText(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// The background category's state at a glance, so the hub says whether
  /// runs keep updating after the app closes without opening the page.
  String _backgroundSummary(ConnectionController controller) {
    final live = controller.backgroundLive;
    if (live.stoppedByAndroidTimeout) {
      return _settingsCopy(context).e7SettingsUi12;
    }
    if (!controller.keepLiveInBackground) {
      return _settingsCopy(context).quotaBudgetOff;
    }
    return live.active
        ? _settingsCopy(context).e7SettingsUi14
        : _settingsCopy(context).e7SettingsUi15;
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  /// What disconnecting actually costs, counted rather than described in the
  /// abstract: queued prompts and unsent drafts for this server stop moving
  /// until it is connected again.
  String _disconnectDisclosure() {
    final controller = widget.controller;
    final id = controller.profile?.id;
    final queued = id == null ? 0 : controller.queuedPromptCountForProfile(id);
    final drafts = id == null ? 0 : controller.draftCountForProfile(id);
    return _settingsCopy(context).e7SettingsDisconnectBody(queued, drafts);
  }

  Future<void> _disconnect() async {
    final confirmed = await showConfirmSheet(
      context,
      title: _settingsCopy(context).e7SettingsDisconnectTitle(
        widget.controller.profile?.name ??
            _settingsCopy(context).e7SettingsUi16,
      ),
      message: _disconnectDisclosure(),
      confirmLabel: _settingsCopy(context).e7SettingsUi8,
      icon: AppIconography.unlink,
      destructive: true,
      sheetKey: const ValueKey('disconnect-confirm-sheet'),
      confirmKey: const ValueKey('confirm-disconnect'),
    );
    if (!confirmed || !mounted) return;
    await widget.controller.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/servers', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final profile = controller.profile;
    final healthy = _health?.healthy == true;
    final healthLine = _checking
        ? _settingsCopy(context).e7SettingsUi11
        : _healthError != null
        ? _settingsCopy(context).e7SettingsHealthError(_healthError!)
        : healthy
        ? _settingsCopy(context).e7SettingsHealthVersion(
            _health?.version ??
                controller.version ??
                _settingsCopy(context).e7SettingsUi17,
          )
        : _settingsCopy(context).e7SettingsVersion(
            controller.version ?? _settingsCopy(context).e7SettingsUi17,
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).librarySettingsTitle,
        ),
      ),
      body: DesktopScrollbarArea(
        builder: (scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Padding(
              key: const ValueKey('settings-connection-summary'),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ListTile(
                minTileHeight: 72,
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 32,
                horizontalTitleGap: 12,
                leading: _CategoryIcon(
                  icon: AppIconography.server,
                  color: healthy
                      ? AppTheme.successOf(theme)
                      : _healthError != null
                      ? theme.colorScheme.error
                      : null,
                ),
                title: Text(
                  profile?.name ?? _settingsCopy(context).e7SettingsUi9,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(healthLine),
                trailing: IconButton(
                  tooltip: _settingsCopy(context).workRefresh,
                  onPressed: _checking ? null : _checkHealth,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIconography.retry),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CategoryRow(
              rowKey: 'settings-category-server',
              icon: AppIconography.server,
              title: _settingsCopy(context).e7SettingsUi1,
              onTap: () => _open(ServerSettingsScreen(controller: controller)),
            ),
            _CategoryRow(
              rowKey: 'settings-category-coding',
              icon: AppIconography.terminal,
              title: _settingsCopy(context).e7SettingsUi2,
              onTap: () => _open(CodingSettingsScreen(controller: controller)),
            ),
            // The live background service and its notifications are Android
            // platform features; the category hides elsewhere.
            if (platformCapabilities.supportsBackgroundService)
              _CategoryRow(
                rowKey: 'settings-category-background',
                icon: AppIconography.notificationImportant,
                title: _settingsCopy(context).e7SettingsUi3,
                subtitle: _backgroundSummary(controller),
                onTap: () =>
                    _open(BackgroundSettingsScreen(controller: controller)),
              ),
            _CategoryRow(
              rowKey: 'settings-category-appearance',
              icon: AppIconography.appearance,
              title: _settingsCopy(context).e7AppearanceTitle,
              subtitle:
                  '${appearanceLabel(controller.appearance.value, context)} · ${themePackLabels[controller.themePack.value]}',
              onTap: () =>
                  _open(AppearanceSettingsScreen(controller: controller)),
            ),
            _CategoryRow(
              rowKey: 'settings-category-privacy',
              icon: AppIconography.privacy,
              title: _settingsCopy(context).e7SettingsUi5,
              onTap: () => _open(PrivacySettingsScreen(controller: controller)),
            ),
            if (controller.supportsUsageStatistics)
              _CategoryRow(
                rowKey: 'settings-category-usage',
                icon: AppIconography.usage,
                title: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).usageTitle,
                onTap: () => _open(UsageScreen(controller: controller)),
              ),
            if (profile != null)
              _CategoryRow(
                rowKey: 'settings-category-quota',
                icon: AppIconography.speed,
                title: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).quotaTitle,
                subtitle: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).quotaSettingsSummary,
                onTap: () => _open(ProviderQuotaScreen(controller: controller)),
              ),
            _CategoryRow(
              rowKey: 'settings-category-diagnostics',
              icon: AppIconography.privacy,
              title: _settingsCopy(context).e7SettingsUi6,
              onTap: () =>
                  _open(DiagnosticsSettingsScreen(controller: controller)),
            ),
            _CategoryRow(
              rowKey: 'settings-category-about',
              icon: AppIconography.info,
              title: _settingsCopy(context).e7SettingsUi7,
              onTap: () => _open(AboutSettingsScreen(controller: controller)),
            ),
            // Plugins (AI Team) sits last so the rows above keep their
            // positions for the lazy list's build window.
            if (profile != null)
              _CategoryRow(
                rowKey: 'settings-category-plugins',
                icon: AppIconography.extensions,
                title: _settingsCopy(context).teamUiPluginsTitle,
                subtitle: _settingsCopy(context).teamUiPluginsHubSubtitle,
                onTap: () =>
                    _open(PluginsSettingsScreen(controller: controller)),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                key: const ValueKey('settings-disconnect'),
                onPressed: _disconnect,
                icon: const Icon(AppIconography.unlink),
                label: Text(_settingsCopy(context).e7SettingsUi8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_connectionChanged);
    super.dispose();
  }
}

class _CategoryRow extends StatelessWidget {
  final String rowKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(rowKey),
      minTileHeight: subtitle == null ? 56 : 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 32,
      horizontalTitleGap: 12,
      leading: _CategoryIcon(icon: icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(AppIconography.chevronRight, size: 20),
      onTap: onTap,
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _CategoryIcon({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return SizedBox.square(
      dimension: 32,
      child: Icon(icon, size: 24, color: tint),
    );
  }
}

class _ShellChoice {
  final String id;
  final String value;
  final String label;
  final bool terminalOnly;

  const _ShellChoice({
    required this.id,
    required this.value,
    required this.label,
    required this.terminalOnly,
  });
}
