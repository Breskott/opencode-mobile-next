part of '../settings_screen.dart';

/// "This server": connection identity, health, host management, and the
/// server update flow. Saved servers are a sibling row in the hub, not a row
/// here, so each has one home.
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
    final copy = _settingsCopy(context);
    final theme = Theme.of(context);
    final healthy = _health?.healthy == true;
    return Scaffold(
      appBar: AppBar(title: Text(copy.e7SettingsUi1)),
      body: KitScreen(
        // The health check and an update in flight are the screen's one
        // loading bar (design standard §4); the rows say what is happening.
        loading: _checking || _upgradingServer,
        loadingLabel: _upgradingServer
            ? serverUpdateTitle
            : copy.e7SettingsUi11,
        body: ListView(
          padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
          children: [
            KitRow(
              leading: KitRow.icon(context, AppIconography.server),
              title: profile?.name ?? copy.e7SettingsUi9,
              supporting: TextSpan(
                text: profile?.baseUrl ?? copy.e7SettingsUi56,
                style: profile?.baseUrl == null
                    ? null
                    : const TextStyle(fontFamily: AppTheme.monoFamily),
              ),
              trailing: IconButton(
                tooltip: copy.e7SettingsUi57,
                // The bar and the "Checking…" row below are the reason it
                // rests while a check runs.
                onPressed: _checking ? null : _checkHealth,
                icon: const Icon(AppIconography.retry),
              ),
            ),
            // Neutral until the first probe answers: a red "unavailable" row
            // that flashes for the half-second before the result lands reads
            // as a real outage.
            if (_health == null && _healthError == null)
              KitRow(
                key: const Key('server-health-checking'),
                leading: KitRow.icon(context, AppIconography.activity),
                title: copy.e7SettingsUi11,
                supporting: TextSpan(text: copy.e7SettingsUi58),
              )
            else
              KitRow(
                key: const Key('server-health-result'),
                leading: KitRow.icon(
                  context,
                  healthy ? AppIconography.checkCircle : AppIconography.error,
                  color: healthy
                      ? AppTheme.successOf(theme)
                      : theme.colorScheme.error,
                ),
                title: healthy ? copy.e7SettingsUi59 : copy.e7SettingsUi60,
                supporting: TextSpan(
                  text:
                      _healthError ??
                      copy.e7SettingsVersion(
                        _health?.version ??
                            controller.version ??
                            copy.e7SettingsUi17,
                      ),
                ),
                supportingMaxLines: 2,
              ),
            KitRow(
              leading: KitRow.icon(context, AppIconography.person),
              title: copy.e7SettingsUi61,
              supporting: TextSpan(
                text: profile?.password.isNotEmpty == true
                    ? copy.e7SettingsAuthenticationUser(
                        profile?.username.isNotEmpty == true
                            ? profile!.username
                            : 'opencode',
                      )
                    : copy.e7SettingsUi62,
              ),
            ),
            if (!managedLocally)
              KitRow(
                key: const Key('host-management-entry'),
                leading: KitRow.icon(context, AppIconography.terminal),
                title: copy.e7SettingsUi65,
                supporting: TextSpan(text: copy.e7SettingsUi66),
                supportingMaxLines: 2,
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        HostManagementScreen(controller: controller),
                  ),
                ),
              ),
            // §7 row 23. A Termux-managed server is upgraded by this device, so
            // that path is never gated — only the remote-host one is.
            if (!managedLocally && !controller.capabilities.remoteUpgrade)
              GatedRowTile(
                feature: 'remote-upgrade',
                title: copy.e7SettingsUi67,
                explainer: copy.e7SettingsUi68,
                leading: KitRow.icon(context, AppIconography.systemDownload),
              )
            else
              KitRow(
                key: const Key('server-updates-tile'),
                leading: KitRow.icon(context, AppIconography.systemDownload),
                title: serverUpdateTitle,
                supporting: TextSpan(text: serverUpdateSubtitle),
                supportingMaxLines: 2,
                trailing: SizedBox.square(
                  dimension: 48,
                  child: Icon(serverUpdateIcon, size: 20),
                ),
                // Rests while its own update runs; the bar says so.
                enabled: !_upgradingServer,
                onTap: serverUpdateAction,
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
