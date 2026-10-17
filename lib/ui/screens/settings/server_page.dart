part of '../settings_screen.dart';

/// One saved server's own page (Settings Standard SC2): three sections that
/// say who a change affects before it is made.
///
/// - **Connection**: reaching the server (status, sign-in, name and address,
///   what it supports);
/// - **In this app**: choices kept on this phone about the server (the model
///   for new chats, notifications, watching, read state);
/// - **On the server**: things saved on the server itself, shared with every
///   other app that uses it, under the line that says so (SC6).
///
/// The page is pinned to the profile it opened for (SC11): switching server
/// in the app never redirects an edit. Rows that need a live connection are
/// offered only while the app is connected to that server; otherwise the page
/// says so and offers to connect.
class ServerPageScreen extends StatefulWidget {
  const ServerPageScreen({
    super.key,
    required this.controller,
    required this.profileId,
  });

  final ConnectionController controller;

  /// The saved server this page is about.
  final String profileId;

  @override
  State<ServerPageScreen> createState() => _ServerPageScreenState();
}

class _ServerPageScreenState extends State<ServerPageScreen> {
  bool _saveFailed = false;

  /// What Use my default just put back, said once at the top of the page.
  String? _resetNote;

  ConnectionController get _controller => widget.controller;

  /// Edits go through the target-pinned facade: the profile id is captured
  /// here, so a server switch elsewhere can never redirect a save (SC11).
  late final ProfileSettingsAccess _access = ProfileSettingsAccess(
    _controller.store,
  );
  late final SettingsTarget _target = SettingsTarget.connection(
    widget.profileId,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _controller.profileMonitor.addListener(_changed);
    _controller.store.appPreferences.readStateConsent.addListener(_changed);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.profileMonitor.removeListener(_changed);
    _controller.store.appPreferences.readStateConsent.removeListener(_changed);
    _access.dispose();
    super.dispose();
  }

  /// Share read state for this server only: acknowledged before it shows on,
  /// and switching off takes effect at once.
  Future<void> _setShareRead(bool value) async {
    setState(() => _saveFailed = false);
    try {
      final token = await _access.beginEdit('shareReadState', _target);
      await _access.writeSetting(token, value);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  void _changed() {
    if (!mounted) return;
    // The monitor can speak while another page is mid-build; redraw after.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  ServerProfile? get _profile => _controller.store.profiles
      .where((p) => p.id == widget.profileId)
      .firstOrNull;

  /// Runs the search index's door [id] for this connection, so the page and
  /// search open the same place.
  Future<void> _door(String id) async {
    final copy = _settingsCopy(context);
    final entry = allSearchEntries(
      copy,
    ).where((entry) => entry.id == id).firstOrNull;
    if (entry == null) return;
    await entry.open(context, SearchScope.of(context, _controller));
  }

  Future<void> _push(Widget screen) =>
      pushKitPage<void>(context, (_) => screen);

  Future<void> _edit() => Navigator.of(context).pushNamed<void>(
    '/servers',
    arguments: ServersRouteRequest.edit(widget.profileId),
  );

  Future<void> _connect() => Navigator.of(context).pushNamed<void>(
    '/servers',
    arguments: ServersRouteRequest.connect(widget.profileId),
  );

  Future<void> _disconnect() async {
    final confirmed = await confirmDisconnectServer(context, _controller);
    if (!confirmed || !mounted) return;
    final navigator = Navigator.of(context);
    await _controller.disconnect();
    navigator.pushNamedAndRemoveUntil('/servers', (_) => false);
  }

  /// What this page shows for [profile] that differs from the person's own
  /// choice: notifications turned off for this server, a new-chat model picked
  /// for it, read state shared with it. Read from the same stored values the
  /// facade reports as explicit (SC11).
  _ServerOverrides _overridesOf(ServerProfile profile) {
    final store = _controller.store;
    final rules = _controller.profileMonitor.rulesFor(profile.id);
    final consent = store.appPreferences.readStateConsent;
    return _ServerOverrides(
      notifications: rules.enabled && !rules.notifications,
      model:
          store.confirmedSelectionPreference('oc.model.${profile.id}') != null,
      readState: consent.enabled(profile.id) != consent.defaultFor(profile.id),
    );
  }

  /// Removes every difference this page shows for the server, not only the
  /// notification one. Each step is independent: a failure is said in place
  /// and what already went back stays back.
  Future<void> _useMyDefault(ServerProfile profile) async {
    setState(() => _saveFailed = false);
    var failed = false;
    final overrides = _overridesOf(profile);
    if (overrides.notifications) {
      try {
        final monitor = _controller.profileMonitor;
        await monitor.setRules(
          profile.id,
          monitor.rulesFor(profile.id).copyWith(notifications: true),
        );
      } catch (_) {
        failed = true;
      }
    }
    if (overrides.model) {
      try {
        await _controller.store.clearModel(profile.id);
      } catch (_) {
        failed = true;
      }
    }
    if (overrides.readState) {
      try {
        final token = await _access.beginEdit('shareReadState', _target);
        await _access.writeSetting(
          token,
          _controller.store.appPreferences.readStateConsent.defaultFor(
            profile.id,
          ),
        );
      } catch (_) {
        failed = true;
      }
    }
    if (!mounted) return;
    final copy = _settingsCopy(context);
    setState(() {
      _saveFailed = failed;
      _resetNote = failed
          ? null
          : copy.settingsV3UseMyDefaultDone(
              serverDisplayName(
                profile,
                lookupAppLocalizations(Localizations.localeOf(context)),
                among: _controller.store.profiles,
              ),
              [
                if (overrides.notifications) copy.settingsV3Notifications,
                if (overrides.model) copy.settingsV3ModelNew,
                if (overrides.readState) copy.settingsV3ShareRead,
              ].join(', '),
            );
    });
  }

  String _signInValue(AppLocalizations copy, ServerProfile profile) {
    if (profile.usesAgentSocket) {
      return profile.codexToken.isNotEmpty
          ? (profile.backend == ServerBackend.codex
                ? copy.settingsV3SignInToken
                : copy.settingsV3SignInPassword)
          : copy.settingsV3SignInNone;
    }
    return profile.password.isNotEmpty
        ? copy.settingsV3SignInPassword
        : copy.settingsV3SignInNone;
  }

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final profile = _profile;
    if (profile == null) {
      // The server was removed while its page was open.
      return KitScreen(
        topBar: KitTopBar(title: copy.settingsV3Servers),
        width: KitScreenWidth.reading,
        body: KitStateView(
          key: const ValueKey('server-page-gone'),
          icon: AppIconography.server,
          title: copy.settingsV3ServerGone,
        ),
      );
    }
    final controller = _controller;
    final name = serverDisplayName(
      profile,
      l10n,
      among: controller.store.profiles,
    );
    final live = _isConnectedServer(controller, profile);
    final monitor = controller.profileMonitor;
    final rules = monitor.rulesFor(profile.id);
    final monitorSupported = monitor.supportsProfile(profile);
    final different = rules.enabled && !rules.notifications;
    final (modelProvider, modelId) = controller.store.modelFor(profile.id);
    // The same words the hub shows, connected or not.
    final modelValue = modelProvider == null || modelId == null
        ? copy.settingsV3ServerPick
        : serverModelLabel(controller, profile, modelProvider, modelId);
    final version =
        serverHealthCache[profile.id]?.version ??
        (live ? controller.version : null) ??
        profile.serverVersion;

    Widget arrival(String id, Widget child) => KitArrival(id: id, child: child);

    final connection = KitRowGroup(
      key: const ValueKey('server-section-connection'),
      label: copy.settingsV3SectionConnection,
      children: [
        arrival(
          'server-row-status',
          KitRow(
            key: const ValueKey('server-row-status'),
            title: copy.settingsV3StatusVersion,
            // Under the title, never at the row's end: "Not connected · last
            // seen 1.0.193" is longer than the half row a value gets and
            // would be cut.
            supporting: TextSpan(
              text: live
                  ? (version == null
                        ? copy.settingsV3Connected
                        : copy.settingsV3ConnectedVersion(
                            _plainServerVersion(version),
                          ))
                  // Not connected: a bare version would read as live.
                  : (version == null
                        ? copy.settingsV3NotConnected
                        : copy.settingsV3NotConnectedVersion(
                            _plainServerVersion(version),
                          )),
            ),
            supportingMaxLines: 3,
            trailing: live ? const KitChevron() : null,
            onTap: live
                ? () => _push(ServerSettingsScreen(controller: controller))
                : null,
          ),
        ),
        KitRow(
          key: const ValueKey('server-row-sign-in'),
          title: copy.settingsV3SignIn,
          trailing: KitRowValue(_signInValue(copy, profile)),
          onTap: _edit,
        ),
        KitRow(
          key: const ValueKey('server-row-address'),
          title: copy.settingsV3NameAddress,
          trailing: const KitChevron(),
          onTap: _edit,
        ),
        if (live)
          KitRow(
            key: const ValueKey('server-row-supports'),
            title: copy.settingsV3Supports,
            trailing: const KitChevron(),
            onTap: () =>
                _push(ServerCapabilitiesScreen(controller: controller)),
          ),
      ],
    );

    final inApp = KitRowGroup(
      key: const ValueKey('server-section-in-app'),
      label: copy.settingsV3SectionInApp,
      children: [
        arrival(
          'server-row-model',
          KitRow(
            key: const ValueKey('server-row-model'),
            title: copy.settingsV3ModelNew,
            trailing: live
                ? KitRowValue(modelValue)
                : KitRowValue(modelValue, chevron: false),
            onTap: live
                ? () => unawaited(
                    showModelPicker(
                      context,
                      title: copy.settingsV3ModelNewOn(name),
                    ),
                  )
                : null,
          ),
        ),
        KitRow(
          key: const ValueKey('server-row-notifications'),
          title: copy.settingsV3Notifications,
          trailing: KitRowValue(
            different
                ? copy.settingsV3DifferentHere
                : rules.enabled
                ? copy.settingsV3On
                : copy.settingsV3Off,
          ),
          onTap: () => _push(
            NotificationsSettingsScreen(
              controller: controller,
              page: NotificationsPage.notifications,
              onlyProfileId: profile.id,
            ),
          ),
        ),
        KitSwitchRow(
          key: const ValueKey('server-row-watch'),
          title: copy.settingsV3Watch,
          value: rules.enabled,
          disabledReason: monitorSupported
              ? null
              : copy.e7ProjectMonitorUnsupported,
          onChanged: monitorSupported
              ? (value) => unawaited(
                  monitor.setRules(
                    profile.id,
                    monitor.rulesFor(profile.id).copyWith(enabled: value),
                  ),
                )
              : null,
        ),
        // Local consent for this server, kept on this phone. It does not
        // say the server supports read receipts; sending also needs that.
        KitSwitchRow(
          key: const ValueKey('server-row-share-read'),
          title: copy.settingsV3ShareRead,
          value: controller.store.appPreferences.readStateConsent.enabled(
            profile.id,
          ),
          disabledReason:
              controller.store.appPreferences.readStateConsent.saving(
                profile.id,
              )
              ? copy.privacySaving
              : null,
          onChanged:
              controller.store.appPreferences.readStateConsent.saving(
                profile.id,
              )
              ? null
              : _setShareRead,
        ),
      ],
    );

    final capabilities = controller.capabilities;
    final onServer = live
        ? [
            // The note belongs to this section: it is the section's hint for
            // a screen reader, and its words stay visible under the rows
            // without being read again as loose page content.
            Semantics(
              key: const ValueKey('server-section-on-semantics'),
              container: true,
              explicitChildNodes: true,
              hint: copy.settingsV3SavedOn(name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KitRowGroup(
                    key: const ValueKey('server-section-on'),
                    label: copy.settingsV3SectionOn(name),
                    children: [
                      if (capabilities.serverCatalog ||
                          capabilities.agentAccount)
                        arrival(
                          'server-row-providers',
                          KitRow(
                            key: const ValueKey('server-row-providers'),
                            title: copy.settingsV3Providers,
                            trailing: const KitChevron(),
                            onTap: () => _door('settings-providers'),
                          ),
                        ),
                      arrival(
                        'server-row-tools',
                        KitRow(
                          key: const ValueKey('server-row-tools'),
                          title: copy.settingsHubToolsRow,
                          trailing: const KitChevron(),
                          onTap: () => _door('settings-tools'),
                        ),
                      ),
                      if (capabilities.shellSettings)
                        arrival(
                          'server-row-shell',
                          DefaultShellRow(controller: controller, icon: false),
                        ),
                      KitRow(
                        key: const ValueKey('server-row-permissions'),
                        title: copy.settingsV3Permissions,
                        trailing: const KitChevron(),
                        onTap: () => _door('settings-automation'),
                      ),
                      if (capabilities.setupConfigRead)
                        KitRow(
                          key: const ValueKey('server-row-ai-setup'),
                          title: copy.aiSetupTitle,
                          trailing: const KitChevron(),
                          onTap: () => _push(
                            AiSetupScreen(
                              controller: controller,
                              serverName: name,
                            ),
                          ),
                        ),
                      KitRow(
                        key: const ValueKey('server-row-updates'),
                        title: copy.settingsV3Updates,
                        trailing: const KitChevron(),
                        onTap: () =>
                            _push(ServerSettingsScreen(controller: controller)),
                      ),
                    ],
                  ),
                  ExcludeSemantics(
                    child: KitGroupNote(
                      key: const ValueKey('server-saved-on-note'),
                      message: copy.settingsV3SavedOn(name),
                    ),
                  ),
                ],
              ),
            ),
          ]
        : [
            // Not the connected server: what lives on it cannot be read or
            // changed from here, and nothing is guessed (SC11).
            KitRowGroup(
              key: const ValueKey('server-section-on'),
              label: copy.settingsV3SectionOn(name),
              children: [
                KitRow(
                  key: const ValueKey('server-row-connect'),
                  title: copy.settingsV3ConnectTo(name),
                  supporting: TextSpan(text: copy.settingsV3ConnectToChange),
                  supportingMaxLines: 3,
                  trailing: const KitChevron(),
                  onTap: _connect,
                ),
              ],
            ),
          ];

    final resetsDefault = _overridesOf(profile).any;

    return KitScreen(
      topBar: KitTopBar(title: name),
      width: KitScreenWidth.reading,
      // Not a lazy list: every row must exist for a search result to arrive
      // at it, and the page is a few dozen plain rows in one Column.
      body: ListView(
        key: const ValueKey('server-page-list'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saveFailed)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: tokens.gutter,
                    end: tokens.gutter,
                    bottom: tokens.sectionGap,
                  ),
                  child: KitNotice(
                    key: const ValueKey('server-page-save-failed'),
                    tone: AppStatusTone.failure,
                    message: copy.shareSessionViewsSaveError,
                    onDismiss: () => setState(() => _saveFailed = false),
                    dismissLabel: copy.notifyDismiss,
                  ),
                ),
              if (_resetNote case final note?)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: tokens.gutter,
                    end: tokens.gutter,
                    bottom: tokens.sectionGap,
                  ),
                  child: KitNotice(
                    key: const ValueKey('server-page-reset-done'),
                    tone: AppStatusTone.ok,
                    message: note,
                    onDismiss: () => setState(() => _resetNote = null),
                    dismissLabel: copy.notifyDismiss,
                  ),
                ),
              connection,
              SizedBox(height: tokens.sectionGap),
              inApp,
              SizedBox(height: tokens.sectionGap),
              ...onServer,
              SizedBox(height: tokens.sectionGap),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
                child: KitDetailsFold(
                  key: const ValueKey('server-page-details'),
                  values: [
                    KitTechnicalValue(
                      copy.serverSettingsAddressLabel,
                      profile.baseUrl,
                    ),
                  ],
                ),
              ),
              // Every page with a difference ends by offering the way back
              // (Discord's Reset Override): it removes the difference, it does
              // not write a value.
              if (resetsDefault) ...[
                SizedBox(height: tokens.sectionGap),
                KitRowGroup(
                  key: const ValueKey('server-section-reset'),
                  children: [
                    KitRow(
                      key: const ValueKey('server-use-my-default'),
                      title: copy.settingsV3UseMyDefault,
                      supporting: TextSpan(
                        text: copy.settingsV3UseMyDefaultDetail(name),
                      ),
                      supportingMaxLines: 3,
                      trailing: const KitChevron(),
                      onTap: () => unawaited(_useMyDefault(profile)),
                    ),
                  ],
                ),
              ],
              SizedBox(height: tokens.sectionGap),
              KitRowGroup(
                key: const ValueKey('server-section-actions'),
                children: [
                  if (live)
                    KitRow(
                      key: const ValueKey('server-reconnect'),
                      title: copy.settingsV3ReconnectTo(name),
                      titleMaxLines: 2,
                      onTap: _connect,
                    ),
                  if (live)
                    arrival(
                      'server-disconnect',
                      KitRow(
                        key: const ValueKey('server-disconnect'),
                        destructive: true,
                        title: copy.serverSettingsDisconnectTitle(name),
                        titleMaxLines: 2,
                        onTap: _disconnect,
                      ),
                    ),
                  KitRow(
                    key: const ValueKey('server-remove'),
                    destructive: true,
                    title: copy.serverSettingsRemoveTitle(name),
                    titleMaxLines: 2,
                    onTap: () => Navigator.of(context).pushNamed<void>(
                      '/servers',
                      arguments: ServersRouteRequest.forget(profile.id),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The differences a server's page can remove with Use my default.
class _ServerOverrides {
  const _ServerOverrides({
    required this.notifications,
    required this.model,
    required this.readState,
  });

  final bool notifications;
  final bool model;
  final bool readState;

  bool get any => notifications || model || readState;
}
