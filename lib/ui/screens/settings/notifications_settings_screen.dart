part of '../settings_screen.dart';

/// The one Notifications screen (`notifications-settings`): what notifies,
/// quiet hours, the background connection and saved-server monitoring. Quiet
/// hours and Wi-Fi only exist once, here, and both the saved-server monitor
/// and the quota monitor read them.
///
/// A row is absent when this device cannot do it, and a section with no rows
/// is absent.
class NotificationsSettingsScreen extends StatefulWidget {
  final ConnectionController controller;

  /// A section slug (`what`, `quiet`, `background`, `servers`) a search
  /// result means: the screen opens scrolled to it.
  final String? initialSection;

  const NotificationsSettingsScreen({
    super.key,
    required this.controller,
    this.initialSection,
  });

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen>
    with WidgetsBindingObserver {
  bool _saving = false;
  final _sectionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialSection case final slug?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _sectionKeys[slug]?.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    }
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
    widget.controller.backgroundLive.addListener(_changed);
    // After the frame, not during it: refreshStatus marks itself busy and
    // notifies synchronously, and a notification mid-build is a setState
    // during build for every listener above this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && platformCapabilities.supportsBackgroundService) {
        widget.controller.backgroundLive.refreshStatus();
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleBackground(bool value) async {
    final controller = widget.controller;
    final enabled = await controller.setKeepLiveInBackground(value);
    if (!mounted) return;
    final error = controller.backgroundLive.lastError;
    if (error != null || enabled != value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? _settingsCopy(context).e7SettingsUi22)),
      );
    }
  }

  /// One write at a time: two quick taps must not race two read-modify-write
  /// passes over the same stored rule.
  Future<void> _save(Future<void> Function() write) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await write();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_settingsCopy(context).monitorSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shared(SharedNotifyRules Function(SharedNotifyRules) change) =>
      _save(() => widget.controller.updateSharedNotifyRules(change));

  Future<void> _quietTime(bool start, SharedNotifyRules rules) async {
    final current = (start ? rules.quietStart : rules.quietEnd)!;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected == null || !mounted) return;
    final minutes = selected.hour * 60 + selected.minute;
    await _shared(
      (rules) => start
          ? rules.copyWith(quietStart: minutes)
          : rules.copyWith(quietEnd: minutes),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        platformCapabilities.supportsBackgroundService) {
      widget.controller.backgroundLive.refreshStatus();
    }
  }

  String _clock(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  List<Widget> _whatNotifies(SharedNotifyRules rules) {
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final notifications = platformCapabilities.supportsNotifications;
    return [
      if (notifications)
        SwitchListTile(
          key: const ValueKey('notify-finished-runs'),
          title: Text(copy.notifyFinishedRuns),
          subtitle: Text(copy.notifyFinishedRunsDetail),
          value: controller.notificationPreferences.finishedRuns,
          onChanged: _saving
              ? null
              : (value) => _save(() => controller.setNotifyFinishedRuns(value)),
        ),
      if (notifications)
        SwitchListTile(
          key: const ValueKey('notify-requests'),
          title: Text(copy.notifyRequests),
          subtitle: Text(copy.notifyRequestsDetail),
          value: controller.notificationPreferences.requests,
          onChanged: _saving
              ? null
              : (value) => _save(() => controller.setNotifyRequests(value)),
        ),
      // A check-in is also a row in the attention list, so it is worth
      // setting on a device that cannot notify.
      SwitchListTile(
        key: const ValueKey('notify-check-ins'),
        title: Text(copy.monitorCheckIn),
        value: rules.checkInAfterMinutes != null,
        onChanged: _saving
            ? null
            : (value) => _shared(
                (rules) => value
                    ? rules.copyWith(
                        checkInAfterMinutes:
                            ProfileNotifyRules.defaultCheckInMinutes,
                      )
                    : rules.copyWith(clearCheckIn: true),
              ),
      ),
      _RowDetail(
        platformCapabilities.supportsBackgroundService
            ? copy.monitorCheckInDetail
            : copy.monitorCheckInDetailForeground,
      ),
      if (rules.checkInAfterMinutes != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.monitorCheckInAfter),
              DropdownButton<int>(
                key: const ValueKey('notify-check-in-after'),
                isExpanded: true,
                itemHeight: null,
                value:
                    ProfileNotifyRules.checkInChoices.contains(
                      rules.checkInAfterMinutes,
                    )
                    ? rules.checkInAfterMinutes
                    : null,
                hint: Text(copy.monitorMinutes(rules.checkInAfterMinutes!)),
                items: [
                  for (final minutes in ProfileNotifyRules.checkInChoices)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(copy.monitorMinutes(minutes)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (minutes) {
                        if (minutes == null) return;
                        _shared(
                          (rules) =>
                              rules.copyWith(checkInAfterMinutes: minutes),
                        );
                      },
              ),
            ],
          ),
        ),
      if (notifications)
        SwitchListTile(
          key: const ValueKey('notify-quota-alerts'),
          title: Text(copy.notifyQuotaAlerts),
          value: rules.quotaAlerts,
          onChanged: _saving
              ? null
              : (value) =>
                    _shared((rules) => rules.copyWith(quotaAlerts: value)),
        ),
      if (notifications) _RowDetail(copy.notifyQuotaAlertsDetail),
    ];
  }

  List<Widget> _quietHours(SharedNotifyRules rules) {
    // Quiet hours only silence notifications.
    if (!platformCapabilities.supportsNotifications) return const [];
    final copy = _settingsCopy(context);
    return [
      SwitchListTile(
        key: const ValueKey('notify-quiet-hours'),
        title: Text(copy.monitorQuiet),
        value: rules.quietEnabled,
        onChanged: _saving
            ? null
            : (value) => _shared(
                (rules) => value
                    ? rules.copyWith(
                        quietStart: SharedNotifyRules.defaultQuietStart,
                        quietEnd: SharedNotifyRules.defaultQuietEnd,
                      )
                    : rules.copyWith(clearQuiet: true),
              ),
      ),
      _RowDetail(copy.notifyQuietDetail),
      if (rules.quietEnabled) ...[
        ListTile(
          key: const ValueKey('notify-quiet-start'),
          title: Text(copy.monitorQuietStart),
          subtitle: Text(_clock(rules.quietStart!)),
          onTap: _saving ? null : () => _quietTime(true, rules),
        ),
        ListTile(
          key: const ValueKey('notify-quiet-end'),
          title: Text(copy.monitorQuietEnd),
          subtitle: Text(_clock(rules.quietEnd!)),
          onTap: _saving ? null : () => _quietTime(false, rules),
        ),
      ],
    ];
  }

  List<Widget> _background() {
    if (!platformCapabilities.supportsBackgroundService) return const [];
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final live = controller.backgroundLive;
    return [
      SwitchListTile(
        key: const ValueKey('background-live-switch'),
        secondary: const Icon(Icons.sync_lock_rounded),
        title: Text(copy.e7SettingsUi25),
        value: controller.keepLiveInBackground,
        onChanged: live.busy ? null : _toggleBackground,
      ),
      _RowDetail(copy.e7SettingsUi26),
      if (controller.keepLiveInBackground)
        ListTile(
          key: const ValueKey('background-battery-row'),
          leading: Icon(
            live.batteryOptimizationIgnored
                ? AppIconography.batteryCharging
                : AppIconography.batteryWarning,
          ),
          title: Text(
            live.batteryOptimizationIgnored
                ? copy.e7SettingsUi27
                : copy.e7SettingsUi28,
          ),
          subtitle: Text(
            live.batteryOptimizationIgnored
                ? copy.e7SettingsUi29
                : copy.e7SettingsUi30,
          ),
          trailing: live.batteryOptimizationIgnored
              ? const Icon(AppIconography.check)
              : const Icon(AppIconography.externalLink),
          onTap: live.batteryOptimizationIgnored
              ? null
              : () async {
                  await live.requestBatteryOptimizationExemption();
                },
        ),
      _BackgroundStatusRow(
        live: live,
        onRestart: live.busy ? null : () => _toggleBackground(true),
      ),
    ];
  }

  List<Widget> _savedServers(SharedNotifyRules rules) {
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final monitor = controller.profileMonitor;
    final servers = controller.isIsolated
        ? const <ServerProfile>[]
        : [
            for (final profile in controller.store.profiles)
              if (controller.isProfileReadable(profile.id)) profile,
          ];
    return [
      for (final profile in servers)
        _MonitoredServerRows(
          controller: controller,
          profile: profile,
          saving: _saving,
          onSave: (next) => _save(() => monitor.setRules(profile.id, next)),
        ),
      // One Wi-Fi rule for every background check: saved servers and quota
      // sources alike. Without a background service nothing checks in the
      // background, so there is nothing to restrict.
      if (platformCapabilities.supportsBackgroundService)
        SwitchListTile(
          key: const ValueKey('notify-wifi-only'),
          secondary: const Icon(AppIconography.network),
          title: Text(copy.notifyWifiOnly),
          value: rules.wifiOnly,
          onChanged: _saving
              ? null
              : (value) => _shared((rules) => rules.copyWith(wifiOnly: value)),
        ),
      if (platformCapabilities.supportsBackgroundService)
        _RowDetail(copy.monitorWifiDetail),
      if (servers.isNotEmpty)
        _RowDetail(
          '${copy.monitorOptInDetail}\n\n${copy.monitorScope}\n\n'
          '${copy.monitorDisclosure}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final rules = controller.sharedNotifyRules;
    final sections = <(String, String, List<Widget>)>[
      ('what', copy.notifySectionWhat, _whatNotifies(rules)),
      ('quiet', copy.monitorQuiet, _quietHours(rules)),
      ('background', copy.notifySectionBackground, _background()),
      ('servers', copy.notifySectionServers, _savedServers(rules)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(copy.settingsHubGroupNotifications)),
      // Not a lazy list: a few dozen plain rows, and a link that means one
      // section must be able to find it.
      body: SingleChildScrollView(
        key: const ValueKey('notifications-settings'),
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Android 15 stops the service on its own once the daily budget is
            // spent, and the switch flips itself off when it does. It needs the
            // person, so it comes before every setting (plan 5.7).
            if (platformCapabilities.supportsBackgroundService &&
                controller.backgroundLive.stoppedByAndroidTimeout)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  key: const ValueKey('background-timeout-notice'),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.timer_off_outlined),
                    title: Text(copy.e7SettingsUi23),
                    subtitle: Text(copy.e7SettingsUi24),
                  ),
                ),
              ),
            for (final (slug, title, rows) in sections)
              if (rows.isNotEmpty)
                KeyedSubtree(
                  key: _sectionKeys.putIfAbsent(
                    slug,
                    () => GlobalKey(debugLabel: 'notifications-$slug'),
                  ),
                  child: Column(
                    key: ValueKey('notifications-section-$slug'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [SectionLabel(title), ...rows],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    widget.controller.backgroundLive.removeListener(_changed);
    super.dispose();
  }
}

/// What a row means, under the row at the full width of the screen. As a
/// switch's subtitle the same sentence is squeezed beside the icon and the
/// switch, and at the largest text size it runs to dozens of lines.
class _RowDetail extends StatelessWidget {
  const _RowDetail(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.mutedOf(theme),
        ),
      ),
    );
  }
}

/// One saved server: whether it is monitored at all, and whether what the
/// monitor finds may notify. Everything else about notifying is shared.
class _MonitoredServerRows extends StatelessWidget {
  const _MonitoredServerRows({
    required this.controller,
    required this.profile,
    required this.saving,
    required this.onSave,
  });
  final ConnectionController controller;
  final ServerProfile profile;
  final bool saving;
  final ValueChanged<ProfileNotifyRules> onSave;

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    final monitor = controller.profileMonitor;
    final rules = monitor.rulesFor(profile.id);
    final supported = monitor.supportsProfile(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: ValueKey('monitor-enabled-${profile.id}'),
          secondary: const Icon(AppIconography.server),
          title: Text(profile.name),
          subtitle: Text(
            supported ? copy.monitorOptIn : copy.e7ProjectMonitorUnsupported,
          ),
          value: rules.enabled,
          onChanged: !supported || saving
              ? null
              : (value) => onSave(rules.copyWith(enabled: value)),
        ),
        if (supported &&
            rules.enabled &&
            platformCapabilities.supportsNotifications)
          SwitchListTile(
            key: ValueKey('monitor-notify-${profile.id}'),
            // Aligns under the server name rather than under its icon.
            contentPadding: const EdgeInsetsDirectional.fromSTEB(72, 0, 24, 0),
            title: Text(copy.monitorNotifications),
            value: rules.notifications,
            onChanged: saving
                ? null
                : (value) => onSave(rules.copyWith(notifications: value)),
          ),
      ],
    );
  }
}

/// One line of truth under the switch: is the service actually running?
/// The preference and the service can disagree — Android 15+ stops the
/// service on its own after six hours per day — and this row is where the
/// disagreement shows, with the restart one tap away.
class _BackgroundStatusRow extends StatelessWidget {
  final BackgroundLiveController live;
  final VoidCallback? onRestart;

  const _BackgroundStatusRow({required this.live, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stopped = live.stoppedByAndroidTimeout;
    final running = live.enabled && live.active;
    final starting = live.enabled && !live.active;
    final title = stopped
        ? _settingsCopy(context).e7SettingsUi31
        : running
        ? _settingsCopy(context).e7SettingsUi32
        : starting
        ? _settingsCopy(context).commandRunning
        : _settingsCopy(context).quotaBudgetOff;
    final icon = stopped
        ? Icons.timer_off_outlined
        : running
        ? AppIconography.sync
        : starting
        ? AppIconography.cloud
        : AppIconography.cloudOff;
    final color = stopped
        ? theme.colorScheme.error
        : running
        ? AppTheme.successOf(theme)
        : AppTheme.mutedOf(theme);
    return ListTile(
      key: const ValueKey('background-status-row'),
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(_settingsCopy(context).e7SettingsUi34),
      trailing: stopped ? const Icon(AppIconography.retry) : null,
      onTap: stopped ? onRestart : null,
    );
  }
}
