part of '../settings_screen.dart';

/// The one Notifications screen (`notifications-settings`): what notifies,
/// quiet hours, the background connection and saved-server monitoring. Quiet
/// hours and Wi-Fi only exist once, here, and both the saved-server monitor
/// and the quota monitor read them.
///
/// A row is absent when this device cannot do it, and a section with no rows
/// is absent. Kit only (screen-settings-1): each section is a [KitRowGroup]
/// of [KitSwitchRow]s and [KitRow]s whose one plain line says what the
/// setting does; how monitoring works is folded into Details at the end.
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
  bool _sendingTest = false;

  /// A refused write, said on the page until the next one succeeds.
  bool _saveFailed = false;

  /// Why Android did not turn the background connection on.
  String? _backgroundError;
  final _sectionKeys = <String, GlobalKey>{};

  /// True once Android itself is refusing this app's notifications (denied
  /// permission or muted): the honest state P0.6 asks the page to show,
  /// re-checked on resume ([didChangeAppLifecycleState]) rather than only
  /// read once at open.
  bool get _notificationsBlocked =>
      platformCapabilities.supportsBackgroundService &&
      !widget.controller.backgroundLive.notificationGranted;

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
    if (controller.backgroundLive.busy) return;
    setState(() => _backgroundError = null);
    final enabled = await controller.setKeepLiveInBackground(value);
    if (!mounted) return;
    final error = controller.backgroundLive.lastError;
    if (error != null || enabled != value) {
      setState(
        () => _backgroundError = error ?? _settingsCopy(context).e7SettingsUi22,
      );
    }
  }

  Future<void> _sendTestNotification() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      await widget.controller.backgroundLive.sendTestNotification();
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  /// One write at a time: two quick taps must not race two read-modify-write
  /// passes over the same stored rule.
  Future<void> _save(Future<void> Function() write) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await write();
      if (mounted) setState(() => _saveFailed = false);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shared(SharedNotifyRules Function(SharedNotifyRules) change) =>
      _save(() => widget.controller.updateSharedNotifyRules(change));

  Future<void> _quietTime(bool start, SharedNotifyRules rules) async {
    final copy = _settingsCopy(context);
    final current = (start ? rules.quietStart : rules.quietEnd)!;
    // The stock picker, told which end it sets and with a verb on its
    // button (notifications-settings-quiet-time-dialog).
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? copy.notifyQuietStartPicker : copy.notifyQuietEndPicker,
      confirmText: copy.notifyQuietSet,
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
    final blocked = _notificationsBlocked;
    // Blocked by Android: the switches say why they cannot change instead of
    // reading "on" while nothing can arrive.
    final blockedReason = blocked ? copy.notifyBlockedTitle : null;
    final checkIn = rules.checkInAfterMinutes;
    return [
      if (notifications)
        KitSwitchRow(
          key: const ValueKey('notify-finished-runs'),
          leading: KitRow.icon(context, AppIconography.checkCircle),
          title: copy.notifyFinishedRuns,
          supporting: copy.notifyFinishedRunsDetail,
          value: controller.notificationPreferences.finishedRuns,
          disabledReason: blockedReason,
          onChanged: blocked
              ? null
              : (value) => _save(() => controller.setNotifyFinishedRuns(value)),
        ),
      if (notifications)
        KitSwitchRow(
          key: const ValueKey('notify-requests'),
          leading: KitRow.icon(context, AppIconography.question),
          title: copy.notifyRequests,
          supporting: copy.notifyRequestsDetail,
          value: controller.notificationPreferences.requests,
          disabledReason: blockedReason,
          onChanged: blocked
              ? null
              : (value) => _save(() => controller.setNotifyRequests(value)),
        ),
      // A check-in is also a row in the attention list, so it is worth
      // setting on a device that cannot notify.
      KitSwitchRow(
        key: const ValueKey('notify-check-ins'),
        leading: KitRow.icon(context, AppIconography.clock),
        title: copy.monitorCheckIn,
        supporting: platformCapabilities.supportsBackgroundService
            ? copy.monitorCheckInDetail
            : copy.monitorCheckInDetailForeground,
        value: checkIn != null,
        onChanged: (value) => _shared(
          (rules) => value
              ? rules.copyWith(
                  checkInAfterMinutes: ProfileNotifyRules.defaultCheckInMinutes,
                )
              : rules.copyWith(clearCheckIn: true),
        ),
      ),
      if (checkIn != null)
        KitPickerRow<int>(
          rowKey: const ValueKey('notify-check-in-after'),
          leading: KitRow.icon(context, AppIconography.timer),
          title: copy.monitorCheckInAfter,
          valueLabel: copy.monitorMinutes(checkIn),
          choices: [
            for (final minutes in ProfileNotifyRules.checkInChoices)
              KitChoice(value: minutes, title: copy.monitorMinutes(minutes)),
          ],
          selected: ProfileNotifyRules.checkInChoices.contains(checkIn)
              ? checkIn
              : null,
          onSelected: (minutes) =>
              _shared((rules) => rules.copyWith(checkInAfterMinutes: minutes)),
        ),
      if (notifications)
        KitSwitchRow(
          key: const ValueKey('notify-quota-alerts'),
          leading: KitRow.icon(context, AppIconography.usage),
          title: copy.notifyQuotaAlerts,
          supporting: copy.notifyQuotaAlertsDetail,
          value: rules.quotaAlerts,
          disabledReason: blockedReason,
          onChanged: blocked
              ? null
              : (value) =>
                    _shared((rules) => rules.copyWith(quotaAlerts: value)),
        ),
      // Real proof, not just a read of the permission flag (P0.6): posts an
      // actual alert through the same channel a coding request would use.
      if (notifications)
        KitRow(
          key: const ValueKey('notify-send-test'),
          leading: KitRow.icon(context, AppIconography.notificationImportant),
          title: copy.notifySendTest,
          supporting: TextSpan(text: copy.notifySendTestDetail),
          supportingMaxLines: 2,
          enabled: !_sendingTest,
          disabledReason: _sendingTest ? copy.notifySendingTest : null,
          onTap: _sendTestNotification,
        ),
    ];
  }

  List<Widget> _quietHours(SharedNotifyRules rules) {
    // Quiet hours only silence notifications.
    if (!platformCapabilities.supportsNotifications) return const [];
    final copy = _settingsCopy(context);
    final allDay = rules.quietEnabled && rules.quietStart == rules.quietEnd;
    return [
      KitSwitchRow(
        key: const ValueKey('notify-quiet-hours'),
        leading: KitRow.icon(context, AppIconography.darkMode),
        title: copy.monitorQuiet,
        supporting: copy.notifyQuietDetail,
        value: rules.quietEnabled,
        onChanged: (value) => _shared(
          (rules) => value
              ? rules.copyWith(
                  quietStart: SharedNotifyRules.defaultQuietStart,
                  quietEnd: SharedNotifyRules.defaultQuietEnd,
                )
              : rules.copyWith(clearQuiet: true),
        ),
      ),
      if (rules.quietEnabled) ...[
        KitRow(
          key: const ValueKey('notify-quiet-start'),
          leading: KitRow.icon(context, AppIconography.clock),
          title: copy.monitorQuietStart,
          trailing: KitRowValue(_clock(rules.quietStart!)),
          onTap: () => _quietTime(true, rules),
        ),
        KitRow(
          key: const ValueKey('notify-quiet-end'),
          leading: KitRow.icon(context, AppIconography.clock),
          title: copy.monitorQuietEnd,
          // The same start and end mean quiet all day: said, not guessed.
          supporting: allDay ? TextSpan(text: copy.notifyQuietAllDay) : null,
          supportingMaxLines: 2,
          trailing: KitRowValue(_clock(rules.quietEnd!)),
          onTap: () => _quietTime(false, rules),
        ),
      ],
    ];
  }

  List<Widget> _background() {
    if (!platformCapabilities.supportsBackgroundService) return const [];
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final live = controller.backgroundLive;
    final error = _backgroundError;
    return [
      KitSwitchRow(
        key: const ValueKey('background-live-switch'),
        leading: KitRow.icon(context, AppIconography.sync),
        title: copy.e7SettingsUi25,
        supporting: copy.e7SettingsUi26,
        value: controller.keepLiveInBackground,
        onChanged: _toggleBackground,
        below: error == null
            ? null
            : KitNotice(
                key: const ValueKey('background-live-error'),
                tone: AppStatusTone.failure,
                message: error,
              ),
      ),
      if (controller.keepLiveInBackground)
        KitRow(
          key: const ValueKey('background-battery-row'),
          leading: KitRow.icon(
            context,
            live.batteryOptimizationIgnored
                ? AppIconography.batteryCharging
                : AppIconography.batteryWarning,
          ),
          title: live.batteryOptimizationIgnored
              ? copy.e7SettingsUi27
              : copy.e7SettingsUi28,
          supporting: TextSpan(
            text: live.batteryOptimizationIgnored
                ? copy.e7SettingsUi29
                : copy.e7SettingsUi30,
          ),
          supportingMaxLines: 2,
          trailing: live.batteryOptimizationIgnored ? null : const KitChevron(),
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
    final wifi = platformCapabilities.supportsBackgroundService;
    if (servers.isEmpty && !wifi) return const [];
    return [
      for (final profile in servers)
        ..._monitoredServerRows(
          profile,
          onSave: (next) => _save(() => monitor.setRules(profile.id, next)),
        ),
      // Nothing to watch yet: said, rather than an empty section.
      if (servers.isEmpty)
        KitRow(
          key: const ValueKey('notify-no-servers'),
          leading: KitRow.icon(context, AppIconography.server),
          title: copy.notifyNoServersTitle,
          supporting: TextSpan(text: copy.notifyNoServersDetail),
          supportingMaxLines: 2,
        ),
      // One Wi-Fi rule for every background check: saved servers and quota
      // sources alike. Without a background service nothing checks in the
      // background, so there is nothing to restrict.
      if (wifi)
        KitSwitchRow(
          key: const ValueKey('notify-wifi-only'),
          leading: KitRow.icon(context, AppIconography.network),
          title: copy.notifyWifiOnly,
          supporting: copy.monitorWifiDetail,
          value: rules.wifiOnly,
          onChanged: (value) =>
              _shared((rules) => rules.copyWith(wifiOnly: value)),
        ),
    ];
  }

  /// One saved server: whether it is monitored at all, and whether what the
  /// monitor finds may notify. Everything else about notifying is shared.
  List<Widget> _monitoredServerRows(
    ServerProfile profile, {
    required ValueChanged<ProfileNotifyRules> onSave,
  }) {
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final monitor = controller.profileMonitor;
    final rules = monitor.rulesFor(profile.id);
    final supported = monitor.supportsProfile(profile);
    return [
      KitSwitchRow(
        key: ValueKey('monitor-enabled-${profile.id}'),
        leading: KitRow.icon(context, AppIconography.server),
        title: serverDisplayName(
          profile,
          lookupAppLocalizations(Localizations.localeOf(context)),
          among: controller.store.profiles,
        ),
        supporting: copy.monitorOptIn,
        value: rules.enabled,
        disabledReason: supported ? null : copy.e7ProjectMonitorUnsupported,
        onChanged: !supported
            ? null
            : (value) => onSave(rules.copyWith(enabled: value)),
      ),
      if (supported &&
          rules.enabled &&
          platformCapabilities.supportsNotifications)
        KitSwitchRow(
          key: ValueKey('monitor-notify-${profile.id}'),
          leading: KitRow.icon(context, AppIconography.notificationImportant),
          title: copy.monitorNotifications,
          value: rules.notifications,
          onChanged: (value) => onSave(rules.copyWith(notifications: value)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    final controller = widget.controller;
    final tokens = KitTokens.of(context);
    final rules = controller.sharedNotifyRules;
    final sections = <(String, String, List<Widget>)>[
      ('what', copy.notifySectionWhat, _whatNotifies(rules)),
      ('quiet', copy.monitorQuiet, _quietHours(rules)),
      ('background', copy.notifySectionBackground, _background()),
      ('servers', copy.notifySectionServers, _savedServers(rules)),
    ].where((section) => section.$3.isNotEmpty).toList();
    final hasServers =
        !controller.isIsolated &&
        controller.store.profiles.any(
          (profile) => controller.isProfileReadable(profile.id),
        );
    final notices = <Widget>[
      // The honest state (P0.6): Android is refusing this app's
      // notifications, so every switch below is decoration until this is
      // fixed. Comes before everything else.
      if (_notificationsBlocked)
        KitNotice(
          key: const ValueKey('notifications-blocked-notice'),
          icon: AppIconography.notificationImportant,
          title: copy.notifyBlockedTitle,
          message: copy.notifyBlockedMessage,
          actions: [
            KitAction(
              key: const ValueKey('notifications-open-settings'),
              label: copy.notifyOpenAndroidSettings,
              onPressed: () =>
                  controller.backgroundLive.openNotificationSettings(),
            ),
          ],
        ),
      // Android 15 stops the service on its own once the daily budget is
      // spent, and the switch flips itself off when it does. It needs the
      // person, so it comes before every setting (plan 5.7).
      if (platformCapabilities.supportsBackgroundService &&
          controller.backgroundLive.stoppedByAndroidTimeout)
        KitNotice(
          key: const ValueKey('background-timeout-notice'),
          icon: AppIconography.timer,
          title: copy.e7SettingsUi23,
          message: copy.e7SettingsUi24,
        ),
      if (_saveFailed)
        KitNotice(
          key: const ValueKey('notifications-save-failed'),
          tone: AppStatusTone.failure,
          message: copy.monitorSaveFailed,
          onDismiss: () => setState(() => _saveFailed = false),
          dismissLabel: copy.notifyDismiss,
        ),
    ];
    return KitScreen(
      topBar: KitTopBar(title: copy.settingsHubGroupNotifications),
      width: KitScreenWidth.reading,
      loading: _saving,
      loadingLabel: copy.notifySaving,
      // Not a lazy list: a few dozen rows in one Column, so a link that
      // means one section can find it laid out.
      body: ListView(
        key: const ValueKey('notifications-settings'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final notice in notices)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: tokens.gutter,
                    end: tokens.gutter,
                    bottom: tokens.sectionGap,
                  ),
                  child: notice,
                ),
              for (final (index, (slug, title, rows)) in sections.indexed) ...[
                if (index > 0) SizedBox(height: tokens.sectionGap),
                KeyedSubtree(
                  key: _sectionKeys.putIfAbsent(
                    slug,
                    () => GlobalKey(debugLabel: 'notifications-$slug'),
                  ),
                  child: KitRowGroup(
                    key: ValueKey('notifications-section-$slug'),
                    label: title,
                    children: rows,
                  ),
                ),
              ],
              // How monitoring works: read once, never first (KIT-33).
              if (hasServers) ...[
                SizedBox(height: tokens.sectionGap),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
                  child: KitDetailsFold(
                    key: const ValueKey('notifications-monitor-details'),
                    label: copy.notifyMonitorDetails,
                    notes: [
                      copy.monitorOptInDetail,
                      copy.monitorScope,
                      copy.monitorDisclosure,
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
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
    final copy = _settingsCopy(context);
    final stopped = live.stoppedByAndroidTimeout;
    final running = live.enabled && live.active;
    final starting = live.enabled && !live.active;
    final title = stopped
        ? copy.e7SettingsUi31
        : running
        ? copy.e7SettingsUi32
        : starting
        ? copy.commandRunning
        : copy.quotaBudgetOff;
    final icon = stopped
        ? AppIconography.timer
        : running
        ? AppIconography.sync
        : starting
        ? AppIconography.cloud
        : AppIconography.cloudOff;
    // The state is the tinted icon and the words (§6), not a coloured
    // title; a stop is said in words, never in the danger colour (LOOK-5).
    return KitRow(
      key: const ValueKey('background-status-row'),
      leading: KitRow.icon(
        context,
        icon,
        color: running ? ThemeRoles.of(context).success : null,
      ),
      title: title,
      supporting: TextSpan(text: copy.e7SettingsUi34),
      supportingMaxLines: 2,
      trailing: stopped
          ? KitIconButton(
              key: const ValueKey('background-restart'),
              icon: AppIconography.restart,
              tooltip: copy.notifyRestartBackground,
              onPressed: onRestart,
            )
          : null,
      onTap: stopped ? onRestart : null,
    );
  }
}
