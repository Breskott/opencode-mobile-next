part of '../settings_screen.dart';

/// Server category: connection identity, health, profiles, host management,
/// and the server update flow.
class ServerSettingsScreen extends StatefulWidget {
  final ConnectionController controller;
  const ServerSettingsScreen({super.key, required this.controller});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  Health? _health;
  String? _healthError;
  bool _checking = false;
  bool _upgradingServer = false;
  String? _serverUpgradeError;

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

  Future<void> _copyRemoteUpdateCommands() async {
    await Clipboard.setData(
      const ClipboardData(text: 'opencode upgrade\nopencode models --refresh'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_settingsCopy(context).e7SettingsUi45),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showRemoteRestartNotice(String version) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_settingsCopy(context).e7SettingsUi46),
      content: Text(
        _settingsCopy(context).e7SettingsRestartBody(
          version,
          widget.controller.version ?? _settingsCopy(context).e7SettingsUi52,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_settingsCopy(context).modelChoiceDone),
        ),
      ],
    ),
  );

  Future<void> _upgradeRemoteServer(String target) async {
    final copy = _settingsCopy(context);
    if (_upgradingServer || !isExactServerVersion(target)) return;
    final profile = widget.controller.profile;
    if (profile == null) return;
    final confirmed = await showConfirmSheet(
      context,
      title: copy.e7SettingsUi48,
      message: copy.e7SettingsUpgradeBody(
        target,
        profile.name,
        widget.controller.version ?? copy.e7SettingsUi53,
      ),
      confirmLabel: copy.e7SettingsInstallVersion(target),
      icon: AppIconography.download,
      confirmKey: const Key('confirm-server-upgrade'),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _upgradingServer = true;
      _serverUpgradeError = null;
    });
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (repository == null) {
        throw ProductException(copy.e7SettingsUi19);
      }
      final installed = await repository.upgradeServer(target);
      if (!mounted) return;
      if (widget.controller.profile?.id != profile.id) {
        throw ProductException(copy.e7SettingsUi49);
      }
      widget.controller.recordServerUpgradeInstalled(installed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(copy.e7SettingsInstalledVersion(installed)),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _serverUpgradeError = productErrorText(error));
      }
    } finally {
      if (mounted) setState(() => _upgradingServer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final profile = controller.profile;
    // Termux management only exists on Android; desktop loopback servers
    // follow the ordinary remote-update path.
    final managedLocally =
        platformCapabilities.supportsTermux &&
        TermuxBridge.managesServerUrl(profile?.baseUrl);
    final availableVersion = managedLocally
        ? null
        : controller.availableServerVersion;
    final installedVersion = managedLocally
        ? null
        : controller.installedServerVersion;
    late final String serverUpdateTitle;
    late final String serverUpdateSubtitle;
    late final IconData serverUpdateIcon;
    VoidCallback? serverUpdateAction;
    if (managedLocally) {
      serverUpdateTitle = _settingsCopy(context).e7SettingsUi50;
      serverUpdateSubtitle = _settingsCopy(context).e7SettingsUi51;
      serverUpdateIcon = AppIconography.chevronRight;
      serverUpdateAction = () =>
          Navigator.of(context).pushNamed('/termux-setup');
    } else if (installedVersion != null) {
      serverUpdateTitle = _settingsCopy(
        context,
      ).e7SettingsRestartVersion(installedVersion);
      serverUpdateSubtitle = _serverUpgradeError != null
          ? _settingsCopy(context).e7SettingsRetryError(_serverUpgradeError!)
          : _settingsCopy(context).e7SettingsInstalledCurrent(
              installedVersion,
              controller.version ?? _settingsCopy(context).e7SettingsUi52,
            );
      serverUpdateIcon = AppIconography.restart;
      serverUpdateAction = () => _showRemoteRestartNotice(installedVersion);
    } else if (availableVersion != null) {
      serverUpdateTitle = _settingsCopy(
        context,
      ).e7SettingsUpdateVersion(availableVersion);
      serverUpdateSubtitle = _serverUpgradeError != null
          ? _settingsCopy(context).e7SettingsRetryError(_serverUpgradeError!)
          : _settingsCopy(context).e7SettingsCurrentServer(
              controller.version ?? _settingsCopy(context).e7SettingsUi17,
            );
      serverUpdateIcon = AppIconography.download;
      serverUpdateAction = () => _upgradeRemoteServer(availableVersion);
    } else {
      serverUpdateTitle = _settingsCopy(context).e7SettingsUi54;
      serverUpdateSubtitle = _settingsCopy(context).e7SettingsUi55;
      serverUpdateIcon = AppIcons.copy;
      serverUpdateAction = _copyRemoteUpdateCommands;
    }
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7SettingsUi1)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            leading: const Icon(AppIconography.server),
            title: Text(profile?.name ?? _settingsCopy(context).e7SettingsUi9),
            subtitle: SelectableText(
              textDirection: profile?.baseUrl == null
                  ? null
                  : TextDirection.ltr,
              profile?.baseUrl ?? _settingsCopy(context).e7SettingsUi56,
              style: const TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: AppTheme.codeFontSize,
              ),
            ),
            trailing: IconButton(
              tooltip: _settingsCopy(context).e7SettingsUi57,
              onPressed: _checking ? null : _checkHealth,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIconography.retry),
            ),
          ),
          // Neutral until the first probe answers: a red "unavailable" row
          // that flashes for the half-second before the result lands reads
          // as a real outage.
          if (_health == null && _healthError == null)
            ListTile(
              key: Key('server-health-checking'),
              leading: SizedBox.square(
                dimension: 20,
                child: Padding(
                  padding: EdgeInsets.all(1),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              title: Text(_settingsCopy(context).e7SettingsUi11),
              subtitle: Text(_settingsCopy(context).e7SettingsUi58),
            )
          else
            ListTile(
              key: const Key('server-health-result'),
              leading: Icon(
                _health?.healthy == true
                    ? AppIconography.checkCircle
                    : AppIconography.error,
                color: _health?.healthy == true
                    ? AppTheme.successOf(Theme.of(context))
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(
                _health?.healthy == true
                    ? _settingsCopy(context).e7SettingsUi59
                    : _settingsCopy(context).e7SettingsUi60,
              ),
              subtitle: Text(
                _healthError ??
                    _settingsCopy(context).e7SettingsVersion(
                      _health?.version ??
                          controller.version ??
                          _settingsCopy(context).e7SettingsUi17,
                    ),
              ),
            ),
          ListTile(
            leading: const Icon(AppIconography.person),
            title: Text(_settingsCopy(context).e7SettingsUi61),
            subtitle: Text(
              profile?.password.isNotEmpty == true
                  ? _settingsCopy(context).e7SettingsAuthenticationUser(
                      profile?.username.isNotEmpty == true
                          ? profile!.username
                          : 'opencode',
                    )
                  : _settingsCopy(context).e7SettingsUi62,
            ),
          ),
          ListTile(
            leading: const Icon(AppIconography.database),
            title: Text(_settingsCopy(context).e7SettingsUi63),
            subtitle: Text(_settingsCopy(context).e7SettingsUi64),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => Navigator.of(context).pushNamed('/servers'),
          ),
          if (!managedLocally)
            ListTile(
              key: const Key('host-management-entry'),
              leading: const Icon(AppIconography.terminal),
              title: Text(_settingsCopy(context).e7SettingsUi65),
              subtitle: Text(_settingsCopy(context).e7SettingsUi66),
              trailing: const Icon(AppIconography.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HostManagementScreen(controller: controller),
                ),
              ),
            ),
          // §7 row 23. A Termux-managed server is upgraded by this device, so
          // that path is never gated — only the remote-host one is.
          if (!managedLocally && !controller.capabilities.remoteUpgrade)
            GatedRowTile(
              feature: 'remote-upgrade',
              title: _settingsCopy(context).e7SettingsUi67,
              explainer: _settingsCopy(context).e7SettingsUi68,
              leading: Icon(AppIconography.systemDownload),
            )
          else
            ListTile(
              key: const Key('server-updates-tile'),
              leading: const Icon(AppIconography.systemDownload),
              title: Text(serverUpdateTitle),
              subtitle: Text(serverUpdateSubtitle),
              trailing: _upgradingServer
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(serverUpdateIcon),
              onTap: _upgradingServer ? null : serverUpdateAction,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_connectionChanged);
    super.dispose();
  }
}
