part of '../library_screen.dart';

/// Which of the two integration domains this screen shows: LLM provider
/// connections, MCP servers and their resources, or the legacy combined
/// surface.
enum IntegrationsMode { providers, mcp, all }

/// The page's sections that can fail to load, in page order.
enum _Section { providers, servers, resources }

/// Providers and MCP servers of the current server, built from kit parts
/// (screen-library-1). MCP › Add opens the add sheet (P2.4): the MCP
/// catalogue (P2.5) or the manual form.
class IntegrationsScreen extends StatefulWidget {
  final ConnectionController controller;
  final Future<bool> Function(Uri destination)? authorizationLauncher;
  final IntegrationsMode mode;

  const IntegrationsScreen({
    super.key,
    required this.controller,
    this.authorizationLauncher,
    this.mode = IntegrationsMode.all,
  });

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

/// A message about one act that just finished or failed, shown at the top
/// of the list until dismissed (KIT-34: a toast is only done-with-undo).
class _IntegrationsNotice {
  final String message;
  final AppStatusTone tone;
  const _IntegrationsNotice(this.message, this.tone);
}

class _IntegrationsScreenState extends State<IntegrationsScreen>
    with WidgetsBindingObserver {
  List<McpServerInfo>? _servers;
  List<McpResourceInfo>? _resources;
  List<IntegrationInfo>? _integrations;
  Object? _integrationsSource;
  String? _serverError;
  String? _removalError;
  final Set<String> _removingMcp = {};
  int? _serversLocationRevision;
  ServerOperationsGateway? _serversRepository;
  Object? _serversSource;
  String? _resourceError;
  String? _integrationError;
  final Set<String> _busy = {};
  _PendingMcpOAuth? _pendingMcpOAuth;
  bool _finishingMcpOAuth = false;
  _PendingIntegrationOAuth? _pendingOAuth;
  bool _checkingOAuth = false;
  int _serverLoadGeneration = 0;
  int _resourceLoadGeneration = 0;
  int _integrationLoadGeneration = 0;

  /// Sign-ins whose explicit act is running, and what the server last said
  /// about each persisted one (keyed by [PendingAuthAttempt.key]).
  final Set<Object> _signInBusy = {};
  final Map<Object, IntegrationAuthState> _signInStatus = {};
  final TextEditingController _providerSearch = TextEditingController();
  String _providerQuery = '';
  _IntegrationsNotice? _notice;

  AppLocalizations get _l10n => _libraryCopy(context);

  // Used only for equality checks; never render or log this sign-in snapshot.
  Object get _mcpSource {
    return _integrationSourceFor(widget.controller);
  }

  /// This server shares its providers and MCP servers with the app. Codex
  /// and Paseo do not: the page explains that instead of failing to load.
  bool get _catalogAvailable => widget.controller.capabilities.serverCatalog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from a browser is not consent to poll or submit a code.
  }

  void _say(String message, {AppStatusTone tone = AppStatusTone.ok}) {
    if (!mounted) return;
    setState(() => _notice = _IntegrationsNotice(message, tone));
  }

  Future<void> _load() async {
    if (!_catalogAvailable) return;
    await widget.controller.prunePendingIntegrationAuth();
    if (!mounted) return;
    final repository = await widget.controller.prepareActionRepository();
    if (!mounted) return;
    if (repository == null) {
      final message = _l10n.e7LibraryOpenCodeIsReconnectingTryAgainShortly;
      setState(() {
        _serverError = message;
        _resourceError = message;
        _integrationError = message;
      });
      return;
    }
    await Future.wait([
      if (_showMcp) _loadServers(repository),
      if (_showMcp) _loadResources(repository),
      if (_showProviders) _loadIntegrations(repository),
    ]);
  }

  Future<void> _loadServers(ServerOperationsGateway repository) async {
    final source = _mcpSource;
    final controller = widget.controller;
    final profile = controller.profile;
    final location = controller.locationRevision;
    bool currentScope() =>
        mounted &&
        source == _mcpSource &&
        identical(widget.controller, controller) &&
        identical(controller.profile, profile) &&
        controller.locationRevision == location &&
        identical(controller.repository, repository);
    final generation = ++_serverLoadGeneration;
    setState(() => _serverError = null);
    try {
      final servers = await repository.listMcpServers();
      if (currentScope() && generation == _serverLoadGeneration) {
        setState(() {
          _servers = servers;
          _serversLocationRevision = location;
          _serversRepository = repository;
          _serversSource = source;
        });
      }
    } catch (_) {
      if (currentScope() && generation == _serverLoadGeneration) {
        setState(() => _serverError = _l10n.mcpLoadFailed);
      }
    }
  }

  Future<void> _loadResources(ServerOperationsGateway repository) async {
    final source = _mcpSource;
    final generation = ++_resourceLoadGeneration;
    setState(() => _resourceError = null);
    try {
      final resources = await repository.listMcpResources();
      if (mounted &&
          source == _mcpSource &&
          generation == _resourceLoadGeneration) {
        setState(() => _resources = resources);
      }
    } catch (_) {
      if (mounted &&
          source == _mcpSource &&
          generation == _resourceLoadGeneration) {
        setState(() => _resourceError = _l10n.mcpLoadFailed);
      }
    }
  }

  Future<void> _loadIntegrations(ServerOperationsGateway repository) async {
    if (!identical(repository, widget.controller.repository)) return;
    final source = _mcpSource;
    final generation = ++_integrationLoadGeneration;
    setState(() => _integrationError = null);
    try {
      final integrations = await repository.listIntegrations();
      if (mounted &&
          source == _mcpSource &&
          generation == _integrationLoadGeneration) {
        setState(() {
          _integrations = integrations;
          _integrationsSource = source;
        });
      }
    } catch (error) {
      if (mounted &&
          source == _mcpSource &&
          generation == _integrationLoadGeneration) {
        setState(() => _integrationError = productErrorText(error));
      }
    }
  }

  Future<void> _action(McpServerInfo server) async {
    if (_serversSource != _mcpSource ||
        _busy.contains(server.name) ||
        _removingMcp.contains(server.name)) {
      return;
    }
    // A wake-time reconnect may replace the repository while preserving the
    // user-selected profile and location. Reacquire that transport below.
    final source = _authSourceFor(widget.controller);
    if (server.status == 'connected') {
      final confirmed = await confirmDisconnectMcp(
        context,
        serverName: server.name,
      );
      // The list can reload or switch profile while the sheet is open.
      if (!confirmed ||
          !mounted ||
          source != _authSourceFor(widget.controller) ||
          _serversSource != _mcpSource ||
          _busy.contains(server.name) ||
          _removingMcp.contains(server.name)) {
        return;
      }
    }
    setState(() => _busy.add(server.name));
    try {
      final repository = await _requireActionRepository();
      if (!mounted ||
          source != _authSourceFor(widget.controller) ||
          !widget.controller.isProfileReadable(
            widget.controller.promptShelfProfileID,
          )) {
        return;
      }
      switch (server.status) {
        case 'connected':
          await repository.disconnectMcp(server.name);
          break;
        case 'needs_auth':
        case 'needs_client_registration':
          await _startMcpAuthentication(server, repository);
          return;
        default:
          await repository.connectMcp(server.name);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        _say(productErrorText(error, l10n: _l10n), tone: AppStatusTone.failure);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(server.name));
    }
  }

  /// "Remove {name} until restart": a runtime removal the server undoes on
  /// restart when the server is in its configuration, so it is a neutral
  /// confirmation, not a destructive one (map: integrations-remove-mcp-sheet).
  Future<void> _removeMcp(McpServerInfo server) async {
    final controller = widget.controller;
    final profile = controller.profile;
    final location = controller.locationRevision;
    final repository = controller.repository;
    final source = _mcpSource;
    final route = ModalRoute.of(context);
    var invalidated = false;
    bool currentScope() =>
        mounted &&
        !invalidated &&
        source == _mcpSource &&
        controller.isProfileReadable(controller.promptShelfProfileID) &&
        identical(widget.controller, controller) &&
        identical(controller.profile, profile) &&
        controller.locationRevision == location &&
        identical(controller.repository, repository);
    if (!_canRemoveMcp ||
        _busy.contains(server.name) ||
        _removingMcp.contains(server.name) ||
        _pendingMcpOAuth?.server.name == server.name) {
      return;
    }
    final l10n = _l10n;
    void changed() {
      if (!currentScope()) invalidated = true;
    }

    controller.addListener(changed);
    controller.profileDataChanges.addListener(changed);
    setState(() => _removingMcp.add(server.name));
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final confirmed = await showKitConfirm(
        context,
        icon: AppIconography.delete,
        title: l10n.integrationsMcpRemoveTitle(server.name),
        body: l10n.integrationsMcpRemoveBody,
        confirmLabel: l10n.integrationsMcpRemoveConfirm,
        cancelLabel: l10n.workCancel,
        sheetKey: const ValueKey('mcp-remove-confirm-sheet'),
        confirmKey: const ValueKey('confirm-mcp-remove'),
      );
      if (!confirmed ||
          !currentScope() ||
          !_canRemoveMcp ||
          !(route?.isCurrent ?? true)) {
        return;
      }
      setState(() => _removalError = null);
      try {
        await controller.removeMcpServer(
          server.name,
          locationRevision: location,
        );
      } catch (_) {
        if (!currentScope()) return;
        setState(() => _removalError = l10n.mcpRemoveFailed);
      }
      // DELETE may have reached the server even when its response was lost.
      // Keep the existing inventory until an authoritative refetch succeeds.
      if (!currentScope() ||
          !(route?.isCurrent ?? true) ||
          repository == null) {
        return;
      }
      await Future.wait([_loadServers(repository), _loadResources(repository)]);
    } catch (_) {
      if (currentScope()) setState(() => _removalError = l10n.mcpRemoveFailed);
    } finally {
      controller.removeListener(changed);
      controller.profileDataChanges.removeListener(changed);
      if (mounted) setState(() => _removingMcp.remove(server.name));
    }
  }

  bool get _canRemoveMcp =>
      _serversSource == _mcpSource &&
      widget.controller.isProfileReadable(
        widget.controller.promptShelfProfileID,
      ) &&
      _removalSupported &&
      _serversLocationRevision == widget.controller.locationRevision &&
      identical(_serversRepository, widget.controller.repository);

  bool get _removalSupported =>
      widget.controller.capabilities.mcpRuntimeRemovals &&
      widget.controller.repository is McpRemovalGateway;

  Future<void> _startMcpAuthentication(
    McpServerInfo server,
    ServerOperationsGateway repository,
  ) async {
    final actionL10n = _l10n;
    final source = _mcpSource;
    if (_pendingMcpOAuth != null) {
      throw ProductException(
        actionL10n.e7LibraryFinishOrCancelTheCurrentMCPAuthorization,
      );
    }
    final launch = await repository.startMcpAuthentication(server.name);
    if (!mounted || source != _mcpSource) return;
    final destination = parseAuthorizationUrl(
      launch.authorizationUrl.toString(),
      l10n: actionL10n,
    );
    if (!mounted || !await _confirmAuthorizationLaunch(destination)) {
      if (mounted && source == _mcpSource) {
        await repository.cancelMcpAuthentication(server.name);
      }
      return;
    }
    if (!mounted || source != _mcpSource) return;

    McpOAuthLoopbackListener? listener;
    final redirect = mcpLoopbackRedirect(destination);
    if (redirect != null) {
      try {
        listener = await McpOAuthLoopbackListener.bind(
          redirect: redirect,
          expectedState: launch.oauthState,
        );
      } catch (_) {
        // A custom callback, occupied port, or Android network policy still has
        // a manual code/URL path in the pending notice.
      }
    }
    if (!mounted || source != _mcpSource) {
      await listener?.close();
      return;
    }

    final pending = _PendingMcpOAuth(
      source: source,
      server: server,
      launch: launch,
      listener: listener,
    );
    setState(() => _pendingMcpOAuth = pending);
    if (listener != null) unawaited(_watchMcpCallback(pending));
    try {
      final opened = await _openAuthorization(destination);
      if (!opened) {
        throw ProductException(
          actionL10n.e7LibraryCouldNotOpenTheAuthorizationPage,
        );
      }
    } catch (_) {
      if (mounted && _pendingMcpOAuth == pending) {
        setState(() => _pendingMcpOAuth = null);
      }
      await listener?.close();
      if (mounted && source == _mcpSource) {
        await repository.cancelMcpAuthentication(server.name);
      }
      rethrow;
    }
  }

  Future<void> _watchMcpCallback(_PendingMcpOAuth pending) async {
    try {
      final code = await pending.listener!.code;
      if (!mounted || _pendingMcpOAuth != pending) return;
      await _completeMcpAuthentication(pending, code);
    } catch (error) {
      if (!mounted || _pendingMcpOAuth != pending || _finishingMcpOAuth) {
        return;
      }
      _showError(error);
    }
  }

  Future<void> _enterMcpAuthorizationCode() async {
    final pending = _pendingMcpOAuth;
    if (pending == null || _finishingMcpOAuth) return;
    final l10n = _l10n;
    final code = await _showFinishSignInDialog(
      context,
      label: l10n.e7LibraryCallbackURLOrCode,
      helper: l10n.integrationsFinishSignInMcpHelper,
      fieldKey: const ValueKey('mcp-oauth-code-input'),
      confirmKey: const ValueKey('complete-mcp-oauth'),
      parse: (raw) => parseMcpAuthorizationCode(
        raw,
        expectedState: pending.launch.oauthState,
      ),
    );
    if (code == null || !mounted || _pendingMcpOAuth != pending) return;
    await _completeMcpAuthentication(pending, code);
  }

  Future<void> _completeMcpAuthentication(
    _PendingMcpOAuth pending,
    String code,
  ) async {
    if (_finishingMcpOAuth || _pendingMcpOAuth != pending) return;
    setState(() => _finishingMcpOAuth = true);
    try {
      final repository = await _requireMcpOAuthRepository(pending);
      final status = await repository.completeMcpAuthentication(
        pending.server.name,
        code,
      );
      await pending.listener?.close();
      if (!mounted ||
          _pendingMcpOAuth != pending ||
          pending.source != _mcpSource) {
        return;
      }
      setState(() {
        _pendingMcpOAuth = null;
        _servers = [
          for (final server in _servers ?? const <McpServerInfo>[])
            if (server.name == status.name) status else server,
        ];
      });
      await Future.wait([_loadServers(repository), _loadResources(repository)]);
      if (!mounted) return;
      final connected = status.status == 'connected';
      _say(
        connected
            ? _l10n.e7LibraryAuthenticated(pending.server.name)
            : _l10n.e7LibraryCouldNotConfirmMCPAuthentication,
        tone: connected ? AppStatusTone.ok : AppStatusTone.failure,
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _finishingMcpOAuth = false);
    }
  }

  Future<void> _cancelMcpAuthentication() async {
    final pending = _pendingMcpOAuth;
    if (pending == null || _finishingMcpOAuth) return;
    setState(() => _finishingMcpOAuth = true);
    await pending.listener?.close();
    try {
      final repository = await _requireMcpOAuthRepository(pending);
      await repository.cancelMcpAuthentication(pending.server.name);
      if (!mounted || _pendingMcpOAuth != pending) return;
      setState(() => _pendingMcpOAuth = null);
      await _loadServers(repository);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _finishingMcpOAuth = false);
    }
  }

  /// MCP › Add (P2.4): the add sheet, then the catalogue or the form.
  Future<void> _openMcpAdd() async {
    final path = await showMcpAddSheet(
      context,
      capabilities: widget.controller.capabilities,
    );
    if (!mounted || path == null) return;
    switch (path) {
      case McpAddPath.manual:
        await _openMcpSetup();
      case McpAddPath.catalog:
        final location = widget.controller.locationRevision;
        await Navigator.of(context).push<void>(
          KitPageRoute<void>(
            builder: (_) => McpCatalogScreen(controller: widget.controller),
          ),
        );
        // Whatever the catalogue turned on or off: read the list again.
        if (mounted && widget.controller.locationRevision == location) {
          await _load();
        }
    }
  }

  Future<void> _openMcpSetup() async {
    final location = widget.controller.locationRevision;
    final runtime =
        widget.controller.capabilities.mcpRuntimeAdds &&
        !widget.controller.capabilities.mcpConfigWrites;
    final saved = await Navigator.of(context).push<bool>(
      KitPageRoute<bool>(
        builder: (_) => McpSetupScreen(controller: widget.controller),
      ),
    );
    if (!mounted ||
        saved != true ||
        widget.controller.locationRevision != location) {
      return;
    }
    await _load();
    if (!mounted || widget.controller.locationRevision != location) return;
    _say(
      runtime ? _l10n.mcpRuntimeAdded : _l10n.e7LibraryMCPServerSavedInOpenCode,
    );
  }

  Future<ServerOperationsGateway> _requireActionRepository() async {
    final actionL10n = _l10n;
    final repository = await widget.controller.prepareActionRepository();
    if (repository != null) return repository;
    throw ProductException(
      actionL10n.e7LibraryOpenCodeIsReconnectingTryAgainShortly,
    );
  }

  Future<void> _retryServers() async {
    final actionL10n = _l10n;
    final controller = widget.controller;
    final profile = controller.profile;
    final location = controller.locationRevision;
    bool currentScope() =>
        mounted &&
        identical(widget.controller, controller) &&
        identical(controller.profile, profile) &&
        controller.locationRevision == location;
    try {
      setState(() => _removalError = null);
      final repository = await controller.prepareActionRepository();
      if (!currentScope()) return;
      if (repository == null) {
        throw StateError(actionL10n.e7LibraryMCPUnavailable);
      }
      await _loadServers(repository);
    } catch (_) {
      if (currentScope()) {
        setState(() => _serverError = actionL10n.mcpLoadFailed);
      }
    }
  }

  Future<void> _retryIntegrations() async {
    try {
      await _loadIntegrations(await _requireActionRepository());
    } catch (error) {
      if (mounted) setState(() => _integrationError = productErrorText(error));
    }
  }

  Future<void> _retryResources() async {
    try {
      await _loadResources(await _requireActionRepository());
    } catch (error) {
      if (mounted) setState(() => _resourceError = productErrorText(error));
    }
  }

  bool get _providersFailed =>
      _showProviders &&
      (_integrationError != null ||
          (_integrations != null && _integrationsSource != _mcpSource));
  bool get _serversFailed =>
      _showMcp &&
      (_serverError != null ||
          (_serversSource != null && _serversSource != _mcpSource));
  bool get _resourcesFailed => _showMcp && _resourceError != null;

  /// One Try again for the page (one primary per screen, LAY-12): the
  /// first section that failed carries it, and it reloads every section
  /// that failed, so a server that could not answer at all does not ask
  /// for three separate retries.
  Future<void> _retryFailed() => Future.wait([
    if (_providersFailed) _retryIntegrations(),
    if (_serversFailed) _retryServers(),
    if (_resourcesFailed) _retryResources(),
  ]);

  /// The first section that failed, in page order; null when none did.
  _Section? get _firstFailed => _providersFailed
      ? _Section.providers
      : _serversFailed
      ? _Section.servers
      : _resourcesFailed
      ? _Section.resources
      : null;

  /// The one load error for [section]'s failure, or nothing: when several
  /// sections failed (a server that could not answer at all) the page says
  /// so once, at the first of them, with the one Try again that reloads
  /// every failed section (one primary per screen, LAY-12; nothing shown
  /// twice).
  Widget? _loadError(_Section section, {required Key key, String? body}) {
    if (_firstFailed != section) return null;
    final l10n = _l10n;
    final failed = [
      _providersFailed,
      _serversFailed,
      _resourcesFailed,
    ].where((failed) => failed).length;
    return _railed(
      KitStateView.error(
        key: key,
        title: failed > 1
            ? l10n.integrationsPageLoadFailed
            : l10n.e7LibraryCouldNotLoadThisSection,
        body: body,
        size: KitStateSize.inline,
        retry: KitAction(label: l10n.commonRetry, onPressed: _retryFailed),
      ),
    );
  }

  bool get _showMcp => widget.mode != IntegrationsMode.providers;
  bool get _showProviders => widget.mode != IntegrationsMode.mcp;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.controller.profileDataChanges,
    ]),
    builder: (context, _) => _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    final l10n = _l10n;
    final tokens = KitTokens.of(context);
    final rails = EdgeInsets.symmetric(horizontal: tokens.gutter);
    final notice = _notice;
    return KitScreen(
      width: KitScreenWidth.list,
      topBar: KitTopBar(
        title: switch (widget.mode) {
          IntegrationsMode.providers => l10n.usageProviders,
          IntegrationsMode.mcp => l10n.integrationsMcpTitle,
          IntegrationsMode.all => l10n.e7LibraryMCPAndIntegrations,
        },
        actions: [
          if (_showMcp && _catalogAvailable)
            KitAction(
              key: const ValueKey('add-mcp-server'),
              label: l10n.mcpAdd,
              icon: AppIconography.add,
              onPressed: _openMcpAdd,
            ),
        ],
      ),
      body: KitRefresh(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            bottom: KitScreen.endPadding(context),
          ),
          children: [
            if (!_catalogAvailable)
              Padding(
                padding: rails,
                // Codex and Paseo keep their providers and tools to
                // themselves: say so, and which servers can, instead of a
                // load error (P7.4, explain instead of vanish).
                child: KitCapabilityExplainer.state(
                  key: const ValueKey('integrations-unavailable'),
                  capability: 'flag:serverCatalog',
                  serverName: widget.controller.profile?.name,
                  source: 'integrations',
                ),
              )
            else ...[
              if (notice != null)
                Padding(
                  padding: rails.add(
                    EdgeInsetsDirectional.only(bottom: tokens.space3),
                  ),
                  child: KitNotice(
                    key: const ValueKey('integrations-notice'),
                    message: notice.message,
                    tone: notice.tone,
                    icon: notice.tone == AppStatusTone.failure
                        ? AppIconography.warning
                        : AppIconography.checkCircle,
                    onDismiss: () => setState(() => _notice = null),
                    dismissLabel: l10n.workspaceDismissNotice,
                  ),
                ),
              // Providers lead: a new user needs a model before anything else.
              if (_showProviders) ..._providerSection(context),
              if (_showMcp) ...[
                ..._mcpSection(context),
                ..._resourceSection(context),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// A block on the list's rails with the gap below it.
  Widget _railed(Widget child) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: tokens.space3,
      ),
      child: child,
    );
  }

  List<Widget> _providerSection(BuildContext context) {
    final l10n = _l10n;
    final loaded = _integrations;
    final staleSource = loaded != null && _integrationsSource != _mcpSource;
    final integrations = loaded == null
        ? null
        : _withConfiguredProviders(loaded);
    final models = widget.controller.catalog?.models ?? const <CatalogModel>[];
    final matching = integrations == null
        ? const <PresentedIntegration>[]
        : _sortedIntegrations(integrations)
              .where(
                (presented) => _providerMatchesSearch(
                  presented,
                  _providerQuery,
                  models: models.where(
                    (model) => model.providerID == presented.integration.id,
                  ),
                ),
              )
              .toList();
    final commandAuthSupported =
        widget.controller.capabilities.integrationCommandAuth &&
        widget.controller.repository is IntegrationCommandGateway;
    final credentialsSupported =
        widget.controller.capabilities.integrationCredentials &&
        widget.controller.repository is IntegrationCredentialGateway;
    // Sign-ins waiting on the person are rows of the one provider list,
    // sorted first (owner rule 2026-09-27: no state sections), never cards
    // above it.
    final signIns = _signInRows(integrations);
    final signInIDs = {for (final row in signIns) row.integrationID};
    final others = [
      for (final presented in matching)
        if (!signInIDs.contains(presented.integration.id)) presented,
    ];
    final label = widget.mode == IntegrationsMode.all
        ? l10n.usageProviders
        : null;
    final labelTerm = label == null
        ? null
        : l10n.integrationsProvidersExplanation;
    return [
      SizedBox(
        height: widget.mode == IntegrationsMode.all
            ? KitTokens.of(context).space2
            : KitTokens.of(context).space3,
      ),
      if (widget.controller.pendingAuthPersistenceUncertain)
        _railed(
          KitNotice(
            key: const ValueKey('pending-auth-save-uncertain'),
            tone: AppStatusTone.failure,
            icon: AppIconography.warning,
            message: l10n.pendingAuthSaveUncertain,
            actions: [
              KitAction(
                label: l10n.pendingAuthRetrySave,
                onPressed: () async {
                  try {
                    await widget.controller.retryPendingAuthPersistence();
                  } catch (_) {
                    if (mounted) {
                      _say(
                        _l10n.e7LibraryCouldNotSaveSignInRecovery,
                        tone: AppStatusTone.failure,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      if (_pendingOAuth != null && _pendingOAuth!.source != _mcpSource)
        _railed(
          KitNotice(
            icon: AppIconography.info,
            message: l10n.e7LibraryTheSignInSourceChanged,
          ),
        ),
      if (widget.controller.hasPendingAuthAtOtherSource)
        _railed(
          KitNotice(
            key: const ValueKey('pending-auth-other-source'),
            icon: AppIconography.info,
            message: l10n.pendingAuthOtherSource,
          ),
        ),
      // Until the list itself shows, the sign-ins still lead on their own.
      if (signIns.isNotEmpty &&
          (staleSource ||
              _integrationError != null ||
              integrations == null ||
              integrations.isEmpty)) ...[
        KitRowGroup(label: label, labelTerm: labelTerm, children: signIns),
        SizedBox(height: KitTokens.of(context).space3),
      ],
      if (staleSource || _integrationError != null) ...[
        ?_loadError(
          _Section.providers,
          key: const ValueKey('providers-load-failed'),
          body: staleSource ? l10n.credentialScopeChanged : _integrationError,
        ),
      ] else if (integrations == null)
        const KitSkeletonRows(key: ValueKey('providers-loading'), count: 3)
      else if (integrations.isEmpty)
        _railed(
          KitStateView(
            key: const ValueKey('providers-empty'),
            size: KitStateSize.inline,
            icon: AppIconography.unlink,
            title: l10n.e7LibraryNoProviderConnectionsAvailable,
            body: l10n.e7LibraryThisServerDidNotReturnAnyProvider,
            tertiary: [
              KitAction(
                label: l10n.globalSessionsRefresh,
                onPressed: _retryIntegrations,
              ),
            ],
          ),
        )
      else ...[
        _railed(
          KitSearchField(
            label: l10n.e7LibrarySearchProvidersOrModels,
            controller: _providerSearch,
            fieldKey: const ValueKey('providers-search'),
            clearKey: const ValueKey('providers-search-clear'),
            resultCount: _providerQuery.trim().isEmpty ? null : matching.length,
            onChanged: (value) => setState(() => _providerQuery = value),
          ),
        ),
        if (others.isEmpty && signIns.isEmpty)
          _railed(
            KitSearchNoMatch(
              key: const ValueKey('providers-search-empty'),
              query: _providerQuery.trim(),
              what: l10n.usageProviders,
              onClear: _clearProviderSearch,
            ),
          )
        else
          KitRowGroup(
            label: label,
            labelTerm: labelTerm,
            children: [
              ...signIns,
              for (final presented in others)
                _ProviderRow(
                  commandAuthSupported: commandAuthSupported,
                  credentialsSupported: credentialsSupported,
                  presented: presented,
                  subtitle: _integrationSubtitle(presented.integration),
                  modelCount: _modelCount(presented.integration.id),
                  busy: _busy.contains(presented.integration.id),
                  onConnect: () => _connectIntegration(presented.integration),
                  onDisconnect: () => _disconnectIntegration(presented),
                  onManageAccounts: () =>
                      _openCredentials(presented.integration, presented.name),
                  onServerSignIn: () => _connectIntegration(
                    presented.integration,
                    onlyCommand: true,
                  ),
                ),
            ],
          ),
      ],
    ];
  }

  /// The provider's name for a sign-in row: the listed one when the
  /// provider is in the list, otherwise its presented name.
  String _providerName(String id, List<IntegrationInfo>? integrations) {
    final listed = integrations?.where((i) => i.id == id).firstOrNull;
    if (listed != null) {
      return presentIntegrations([listed]).firstOrNull?.name ?? listed.name;
    }
    return presentedProviderName(
      id,
      widget.controller.catalog?.providers ?? const <CatalogProvider>[],
    );
  }

  /// Every sign-in waiting on the person, one row each (one per provider),
  /// in urgency order: this screen's live one, then the saved ones, then
  /// the uncertain starts.
  List<_SignInRow> _signInRows(List<IntegrationInfo>? integrations) {
    final l10n = _l10n;
    final controller = widget.controller;
    final rows = <_SignInRow>[];
    final seen = <String>{};
    if (_pendingOAuth case final pending?) {
      seen.add(pending.integrationID);
      final state = pending.status?.state ?? IntegrationAuthState.pending;
      final name = pending.integrationName;
      rows.add(
        _SignInRow(
          rowKey: const ValueKey('pending-provider-oauth'),
          integrationID: pending.integrationID,
          name: name,
          word: _signInWord(state),
          mark: _signInMark(state),
          busy: _checkingOAuth,
          onOpen: () => unawaited(_openLiveSignIn(pending)),
          menu: _signInMenu(
            _liveSignInActions(pending),
            (choice) => _runLiveSignIn(pending, choice),
          ),
        ),
      );
    }
    for (final entry in controller.pendingIntegrationAuth) {
      if (!seen.add(entry.integrationID)) continue;
      final name = _providerName(entry.integrationID, integrations);
      final status = entry.expired
          ? IntegrationAuthState.expired
          : _signInStatus[entry.key];
      rows.add(
        _SignInRow(
          integrationID: entry.integrationID,
          name: name,
          word: _signInWord(status ?? IntegrationAuthState.pending),
          mark: _signInMark(status ?? IntegrationAuthState.pending),
          busy: _signInBusy.contains(entry.key),
          onOpen: () => unawaited(_openSavedSignIn(entry, name)),
          menu: _signInMenu(
            _savedSignInActions(entry, name),
            (choice) => _runSavedSignIn(entry, name, choice),
          ),
        ),
      );
    }
    for (final entry in controller.uncertainIntegrationAuth) {
      if (!seen.add(entry.integrationID)) continue;
      final name = _providerName(entry.integrationID, integrations);
      rows.add(
        _SignInRow(
          integrationID: entry.integrationID,
          name: name,
          word: l10n.integrationsSignInMayNotHaveStarted,
          // Neutral: nothing waits on the person in the browser; the way
          // forward is on the row.
          mark: null,
          next: l10n.integrationsSignInUncertainNext,
          busy: false,
          onOpen: () => unawaited(_openUncertainSignIn(entry, name)),
          menu: _signInMenu(
            _uncertainSignInActions(),
            (_) => _forgetUncertain(entry, name),
          ),
        ),
      );
    }
    return rows;
  }

  String _signInWord(IntegrationAuthState state) => switch (state) {
    IntegrationAuthState.pending => _l10n.integrationsSignInWaiting,
    IntegrationAuthState.complete => _l10n.integrationsSignInComplete,
    IntegrationAuthState.failed => _l10n.integrationsSignInFailed,
    IntegrationAuthState.expired => _l10n.integrationsSignInExpired,
  };

  /// Amber only where the person must act: finishing in the browser.
  static KitTaskState _signInMark(IntegrationAuthState state) =>
      switch (state) {
        IntegrationAuthState.pending => KitTaskState.needsYou,
        IntegrationAuthState.complete => KitTaskState.done,
        IntegrationAuthState.failed ||
        IntegrationAuthState.expired => KitTaskState.failed,
      };

  List<KitMenuItem> _signInMenu(
    List<(_SignInChoice, KitAction)> actions,
    Future<void> Function(_SignInChoice choice) run,
  ) => [
    for (final (choice, action) in actions)
      KitMenuItem(
        label: action.label,
        icon: switch (choice) {
          _SignInChoice.finish => AppIconography.login,
          _SignInChoice.enterCode => AppIconography.permissions,
          _SignInChoice.cancel => AppIconography.close,
          _SignInChoice.forget => AppIconography.delete,
        },
        destructive: choice == _SignInChoice.forget,
        onSelected: () => unawaited(run(choice)),
      ),
  ];

  /// This screen's own sign-in (the server cannot resume it later).
  List<(_SignInChoice, KitAction)> _liveSignInActions(
    _PendingIntegrationOAuth pending,
  ) {
    final l10n = _l10n;
    final state = pending.status?.state ?? IntegrationAuthState.pending;
    final name = pending.integrationName;
    final terminal =
        state == IntegrationAuthState.failed ||
        state == IntegrationAuthState.expired;
    return [
      if (!terminal)
        (
          _SignInChoice.finish,
          KitAction(
            key: const ValueKey('continue-provider-oauth'),
            label: l10n.integrationsFinishSigningIn(name),
            onPressed: () {},
          ),
        ),
      (
        _SignInChoice.cancel,
        KitAction(
          key: const ValueKey('cancel-provider-oauth'),
          label: l10n.integrationsCancelSignInFor(name),
          onPressed: () {},
        ),
      ),
    ];
  }

  Future<void> _openLiveSignIn(_PendingIntegrationOAuth pending) async {
    final l10n = _l10n;
    final state = pending.status?.state ?? IntegrationAuthState.pending;
    final terminal =
        state == IntegrationAuthState.failed ||
        state == IntegrationAuthState.expired;
    final choice = await _showSignInSheet(
      context,
      name: pending.integrationName,
      word: _signInWord(state),
      message: switch (state) {
        IntegrationAuthState.failed => l10n.e7LibraryAuthenticationFailed,
        IntegrationAuthState.expired =>
          l10n.e7LibraryAuthenticationAttemptExpired,
        IntegrationAuthState.complete => l10n.e7LibraryAuthenticationComplete,
        IntegrationAuthState.pending =>
          pending.launch.mode == IntegrationAuthMode.code
              ? l10n.e7LibraryReturnFromTheBrowserAndEnterThe
              : l10n.e7LibraryFinishAuthenticationInTheBrowserThenCheck,
      },
      notes: [
        if (!widget.controller.integrationAuthRecoverySupported && !terminal)
          l10n.integrationsPendingNotRecoverable,
      ],
      actions: _liveSignInActions(pending),
      primary: terminal ? null : _SignInChoice.finish,
    );
    if (choice == null || !mounted || _pendingOAuth != pending) return;
    await _runLiveSignIn(pending, choice);
  }

  Future<void> _runLiveSignIn(
    _PendingIntegrationOAuth pending,
    _SignInChoice choice,
  ) async {
    if (_pendingOAuth != pending || _checkingOAuth) return;
    if (choice == _SignInChoice.cancel) return _cancelOAuth();
    if (pending.status?.state == IntegrationAuthState.complete) {
      setState(() => _checkingOAuth = true);
      try {
        await _finishOAuth(pending);
      } catch (error) {
        if (mounted) _showError(error);
      } finally {
        if (mounted) setState(() => _checkingOAuth = false);
      }
      return;
    }
    if (pending.launch.mode == IntegrationAuthMode.code) {
      return _enterOAuthCode();
    }
    return _checkOAuth();
  }

  /// A sign-in this device saved and can pick up again.
  List<(_SignInChoice, KitAction)> _savedSignInActions(
    PendingAuthAttempt entry,
    String name,
  ) {
    final l10n = _l10n;
    final supported = widget.controller.integrationAuthRecoverySupported;
    final expired =
        entry.expired ||
        _signInStatus[entry.key] == IntegrationAuthState.expired;
    final canResume = supported && !expired;
    final codeEntry =
        entry.kind == PendingAuthKind.oauth &&
        entry.mode == IntegrationAuthMode.code;
    return [
      if (canResume)
        (
          _SignInChoice.finish,
          KitAction(
            key: const ValueKey('pending-auth-resume'),
            label: l10n.integrationsFinishSigningIn(name),
            onPressed: () {},
          ),
        ),
      if (canResume && codeEntry)
        (
          _SignInChoice.enterCode,
          KitAction(
            key: const ValueKey('pending-auth-enter-code'),
            label: l10n.integrationsEnterCodeFor(name),
            onPressed: () {},
          ),
        ),
      if (supported)
        (
          _SignInChoice.cancel,
          KitAction(
            key: const ValueKey('pending-auth-cancel'),
            label: l10n.integrationsCancelSignInFor(name),
            onPressed: () {},
          ),
        ),
      (
        _SignInChoice.forget,
        KitAction(
          key: const ValueKey('pending-auth-forget'),
          label: l10n.integrationsForgetSignInOnPhone,
          onPressed: () {},
        ),
      ),
    ];
  }

  Future<void> _openSavedSignIn(PendingAuthAttempt entry, String name) async {
    final l10n = _l10n;
    final status = entry.expired
        ? IntegrationAuthState.expired
        : _signInStatus[entry.key] ?? IntegrationAuthState.pending;
    final actions = _savedSignInActions(entry, name);
    final choice = await _showSignInSheet(
      context,
      name: name,
      word: _signInWord(status),
      message: entry.kind == PendingAuthKind.command
          ? l10n.commandAuthPending
          : l10n.pendingAuthDetail,
      notes: [
        if (!widget.controller.integrationAuthRecoverySupported)
          l10n.pendingAuthUnsupported,
        if (status == IntegrationAuthState.expired) l10n.pendingAuthExpired,
        if (status == IntegrationAuthState.failed) l10n.pendingAuthServerFailed,
      ],
      actions: actions,
      primary: actions.any((a) => a.$1 == _SignInChoice.finish)
          ? _SignInChoice.finish
          : null,
    );
    if (choice == null || !mounted) return;
    await _runSavedSignIn(entry, name, choice);
  }

  Future<void> _runSavedSignIn(
    PendingAuthAttempt entry,
    String name,
    _SignInChoice choice,
  ) async {
    if (_signInBusy.contains(entry.key)) return;
    final l10n = _l10n;
    final controller = widget.controller;
    final source = _authSourceFor(controller);
    final location = controller.locationRevision;
    final route = ModalRoute.of(context);
    bool current() =>
        mounted &&
        source == _authSourceFor(controller) &&
        controller.isProfileReadable(entry.profileID) &&
        (route?.isCurrent ?? true);
    if (choice == _SignInChoice.forget) {
      final confirmed = await _confirmForgetSignIn(name);
      if (!confirmed || !current()) return;
      try {
        await controller.forgetIntegrationAuth(
          entry,
          locationRevision: location,
        );
      } catch (_) {
        if (current()) {
          _say(l10n.pendingAuthFailed, tone: AppStatusTone.failure);
        }
      }
      return;
    }
    String? code;
    if (choice == _SignInChoice.enterCode) {
      // The one finish-sign-in dialog: the code is parsed in place, entered
      // as a secret and never echoed.
      code = await _showFinishSignInDialog(
        context,
        label: l10n.e7LibraryAuthorizationCode,
        helper: l10n.integrationsFinishSignInProviderHelper,
        parse: providerOAuthCompletionCode,
        fieldKey: const ValueKey('oauth-completion-code'),
      );
      if (code == null || !current()) return;
    }
    setState(() => _signInBusy.add(entry.key));
    try {
      final result = await controller.recoverIntegrationAuth(
        entry,
        cancel: choice == _SignInChoice.cancel,
        code: code,
        locationRevision: location,
      );
      if (!current()) return;
      setState(() => _signInStatus[entry.key] = result.state);
      switch (result.state) {
        case IntegrationAuthState.complete:
          await Future.wait([_load(), controller.refreshCatalog()]);
          if (mounted) _say(l10n.e7LibraryIsConnected(name));
        case IntegrationAuthState.pending:
          _say(l10n.pendingAuthStillPending);
        case IntegrationAuthState.failed:
          _say(l10n.pendingAuthServerFailed, tone: AppStatusTone.failure);
        case IntegrationAuthState.expired:
          _say(l10n.pendingAuthExpired, tone: AppStatusTone.failure);
      }
    } catch (_) {
      if (current()) _say(l10n.pendingAuthFailed, tone: AppStatusTone.failure);
    } finally {
      if (mounted) setState(() => _signInBusy.remove(entry.key));
    }
  }

  /// A start the server may have taken without confirming it: the app
  /// blocks a second start until the person clears it here.
  List<(_SignInChoice, KitAction)> _uncertainSignInActions() => [
    (
      _SignInChoice.forget,
      KitAction(
        key: const ValueKey('uncertain-auth-forget'),
        label: _l10n.integrationsForgetSignInOnPhone,
        onPressed: () {},
      ),
    ),
  ];

  Future<void> _openUncertainSignIn(
    ({String integrationID, PendingAuthKind kind}) entry,
    String name,
  ) async {
    final l10n = _l10n;
    final choice = await _showSignInSheet(
      context,
      name: name,
      word: l10n.integrationsSignInMayNotHaveStarted,
      message: l10n.uncertainAuthDetail,
      actions: _uncertainSignInActions(),
    );
    if (choice == null || !mounted) return;
    await _forgetUncertain(entry, name);
  }

  /// The one "forget this sign-in" question (slice-P3.11a: the uncertain
  /// start's own sheet merged into it), for a saved sign-in and for a
  /// start the server never confirmed alike: forgetting only stops this
  /// device tracking it.
  Future<bool> _confirmForgetSignIn(String name) {
    final l10n = _l10n;
    return showKitConfirm(
      context,
      icon: AppIconography.delete,
      title: l10n.pendingAuthRecoveryForgetTitle(name),
      body: l10n.pendingAuthRecoveryForgetBody,
      confirmLabel: l10n.pendingAuthForget,
      confirmKey: const ValueKey('pending-auth-forget-confirm'),
    );
  }

  Future<void> _forgetUncertain(
    ({String integrationID, PendingAuthKind kind}) entry,
    String name,
  ) async {
    final controller = widget.controller;
    final l10n = _l10n;
    final source = _authSourceFor(controller);
    final location = controller.locationRevision;
    final confirmed = await _confirmForgetSignIn(name);
    if (!confirmed || !mounted || source != _authSourceFor(controller)) {
      return;
    }
    try {
      controller.forgetUncertainIntegrationAuth(
        entry.integrationID,
        entry.kind,
        locationRevision: location,
      );
    } catch (_) {
      if (mounted) {
        _say(l10n.e7LibraryTheSignInSourceChanged, tone: AppStatusTone.failure);
      }
    }
  }

  Future<void> _openCredentials(
    IntegrationInfo integration,
    String name,
  ) async {
    if (_integrationsSource != _mcpSource) return;
    final source = _mcpSource;
    await showKitSheet<void>(
      context,
      title: _l10n.integrationsManageAccounts(name),
      icon: AppIconography.manageAccount,
      height: KitSheetHeight.full,
      body: (_) => _CredentialManagementSheet(
        controller: widget.controller,
        integrationID: integration.id,
        integrationName: name,
      ),
    );
    if (mounted && source == _mcpSource) await _retryIntegrations();
  }

  void _clearProviderSearch() {
    _providerSearch.clear();
    setState(() => _providerQuery = '');
  }

  List<Widget> _mcpSection(BuildContext context) {
    final l10n = _l10n;
    final servers = _servers == null
        ? null
        : ([..._servers!]..sort((a, b) {
            final urgency = _mcpUrgency(
              a.status,
            ).compareTo(_mcpUrgency(b.status));
            if (urgency != 0) return urgency;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }));
    final pending = _pendingMcpOAuth;
    final scopeChanged = _serversSource != null && _serversSource != _mcpSource;
    final all = widget.mode == IntegrationsMode.all;
    // The explained "MCP servers" label keeps the section gap itself; a
    // spacer before it would push the section apart by the label's target.
    final labelLeads =
        all &&
        pending == null &&
        _removalError == null &&
        _serverError == null &&
        !scopeChanged &&
        servers != null &&
        servers.isNotEmpty;
    return [
      if (!labelLeads)
        SizedBox(
          height: all
              ? KitTokens.of(context).sectionGap
              : KitTokens.of(context).space3,
        ),
      if (pending != null)
        _railed(
          _PendingMcpOAuthNotice(
            pending: pending,
            busy: _finishingMcpOAuth,
            onEnterCode: _enterMcpAuthorizationCode,
            onCancel: _cancelMcpAuthentication,
          ),
        ),
      if (_removalError != null)
        _railed(
          KitNotice.error(
            key: const ValueKey('mcp-remove-failed'),
            message: _removalError!,
            retry: KitAction(label: l10n.commonRetry, onPressed: _retryServers),
          ),
        ),
      if (_serverError != null || scopeChanged)
        ?_loadError(
          _Section.servers,
          key: const ValueKey('mcp-load-failed'),
          body: _serverError ?? l10n.mcpScopeChanged,
        ),
      if (servers == null && _serverError == null)
        const KitSkeletonRows(key: ValueKey('mcp-loading'), count: 2)
      else if (servers != null && servers.isEmpty)
        _railed(
          KitStateView(
            key: const ValueKey('mcp-empty'),
            size: KitStateSize.inline,
            icon: AppIconography.network,
            title: l10n.e7LibraryNoMCPServersConfigured,
            body: widget.controller.capabilities.mcpConfigWrites
                ? l10n.e7LibrarySaveOneForThisProjectOrEvery
                : l10n.mcpRuntimeEmpty,
            secondary: KitAction(
              key: const ValueKey('mcp-empty-add'),
              label: l10n.e7LibraryAddAnMCPServer,
              icon: AppIconography.add,
              onPressed: _openMcpAdd,
            ),
          ),
        )
      else if (servers != null)
        KitRowGroup(
          label: widget.mode == IntegrationsMode.all
              ? l10n.integrationsMcpServersLabel
              : null,
          labelTerm: widget.mode == IntegrationsMode.all
              ? l10n.e7GlossaryMcpExplanation
              : null,
          children: [
            for (final server in servers)
              _McpServerRow(
                server: server,
                statusLabel: _statusLabel(server.status),
                busy:
                    _busy.contains(server.name) ||
                    _removingMcp.contains(server.name) ||
                    (pending?.server.name == server.name && _finishingMcpOAuth),
                authorizing: pending?.server.name == server.name,
                authGated: _mcpAuthGated(server.status),
                actionsAllowed: !scopeChanged,
                canRemove: _canRemoveMcp,
                onAct: () => _action(server),
                onRemove: () => _removeMcp(server),
              ),
          ],
        ),
    ];
  }

  List<Widget> _resourceSection(BuildContext context) {
    final l10n = _l10n;
    final resources = _resources;
    // As for MCP servers: the explained label keeps its own section gap.
    final labelLeads =
        _resourceError == null && resources != null && resources.isNotEmpty;
    return [
      if (!labelLeads) SizedBox(height: KitTokens.of(context).sectionGap),
      if (_resourceError != null)
        ?_loadError(
          _Section.resources,
          key: const ValueKey('resources-load-failed'),
          body: _resourceError,
        ),
      if (resources == null && _resourceError == null)
        const KitSkeletonRows(key: ValueKey('resources-loading'), count: 2)
      else if (resources != null && resources.isEmpty)
        _railed(
          KitStateView(
            key: const ValueKey('resources-empty'),
            size: KitStateSize.inline,
            icon: AppIconography.fileText,
            title: l10n.e7LibraryNoResourcesAvailable,
            body: l10n.e7LibraryConnectedMCPServersHaveNotExposedAny,
          ),
        )
      else if (resources != null)
        KitRowGroup(
          label: l10n.e7LibraryResources,
          labelTerm: l10n.integrationsResourcesExplanation,
          children: [
            for (final resource in resources)
              KitRow(
                leading: KitRow.icon(context, AppIconography.fileText),
                title: resource.name,
                supporting: TextSpan(
                  children: [
                    TextSpan(text: '${resource.server} · '),
                    TextSpan(
                      text: resource.uri,
                      style: KitText.styleOf(context, KitTextRole.mono),
                    ),
                  ],
                ),
                supportingMaxLines: 2,
                menuLabel: resource.name,
                menu: [
                  KitMenuItem.copy(
                    label: l10n.integrationsCopyResourceAddress,
                    text: () => resource.uri,
                  ),
                ],
              ),
          ],
        ),
    ];
  }

  /// The integrations list only knows providers with a connection method;
  /// a custom provider declared in `opencode.json` (catalog source
  /// "config") never appears there, yet it is enabled and serves models.
  /// Surface every enabled catalog provider the list omits as a
  /// server-configured entry, so the Providers section matches what the
  /// model picker offers.
  List<IntegrationInfo> _withConfiguredProviders(
    List<IntegrationInfo> integrations,
  ) {
    final catalog = widget.controller.catalog;
    if (catalog == null) return integrations;
    final known = {
      for (final integration in integrations) integration.id,
      for (final integration in integrations)
        for (final connection in integration.connections) ?connection.id,
    };
    return [
      ...integrations,
      for (final provider in catalog.providers)
        if (provider.enabled &&
            provider.id.isNotEmpty &&
            !known.contains(provider.id) &&
            !known.contains(provider.integrationID))
          configuredProviderIntegration(provider, _l10n),
    ];
  }

  /// Connected providers first, then alphabetical, so the ones a user can
  /// already use sit at the top of the list.
  static List<PresentedIntegration> _sortedIntegrations(
    List<IntegrationInfo> integrations,
  ) {
    final presented = presentIntegrations(integrations);
    presented.sort((a, b) {
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return presented;
  }

  /// Models the catalog lists for this provider, or null until the catalog
  /// has loaded.
  int? _modelCount(String providerID) {
    final catalog = widget.controller.catalog;
    if (catalog == null) return null;
    return catalog.models
        .where((model) => model.providerID == providerID)
        .length;
  }

  /// Host first (the reference pattern): the sheet names where the person
  /// is going before anything opens, says what to do there, and shows any
  /// one-time device code the server sent (displayed for this launch only;
  /// never persisted or logged).
  Future<bool> _confirmAuthorizationLaunch(
    Uri destination, {
    String instructions = '',
  }) async {
    final l10n = _l10n;
    final host = destination.hasPort
        ? '${destination.host}:${destination.port}'
        : destination.host;
    return showKitConfirm(
      context,
      icon: AppIconography.browser,
      title: l10n.integrationsSignInAtHost(host),
      body: l10n.integrationsSignInBody,
      consequences: [
        if (instructions.trim().isNotEmpty)
          l10n.integrationsSignInInstructions(instructions.trim()),
      ],
      confirmLabel: l10n.e7LibraryOpenBrowser,
      cancelLabel: l10n.workCancel,
      sheetKey: const ValueKey('authorization-launch-sheet'),
      confirmKey: const ValueKey('confirm-authorization-launch'),
    );
  }

  /// True when the server needs interactive MCP authorization that this
  /// connection has no endpoints to run (§7 row 9).
  bool _mcpAuthGated(String status) =>
      !widget.controller.capabilities.mcpOAuth &&
      (status == 'needs_auth' || status == 'needs_client_registration');

  String _statusLabel(String status) => switch (status) {
    'connected' => _l10n.e7LibraryConnectedAndToolsAreAvailable,
    'disabled' => _l10n.e7LibraryDisconnected,
    'failed' => _l10n.e7LibraryConnectionFailed,
    'needs_auth' => _l10n.e7LibraryAuthenticationRequired,
    'needs_client_registration' => _l10n.e7LibraryClientRegistrationRequired,
    _ => status.replaceAll('_', ' '),
  };

  String _integrationSubtitle(IntegrationInfo integration) {
    final l10n = _l10n;
    final credentials = integration.connections
        .where((connection) => connection.type == 'credential')
        .length;
    if (credentials > 1) {
      // "2 accounts · Server environment": the accounts are counted, their
      // names live in Manage accounts.
      return <String>{
        l10n.integrationsAccountCount(credentials),
        for (final connection in integration.connections)
          if (connection.type == 'env')
            l10n.e7LibraryServerEnvironment
          else if (connection.type != 'credential')
            connection.label,
      }.join(' · ');
    }
    // Variable names (ANTHROPIC_API_KEY) are technical: they live in the
    // row's Details, never on its line (emulator QA B10).
    if (integration.connections.isNotEmpty) {
      return <String>{
        for (final connection in integration.connections)
          switch (connection.type) {
            'credential' => l10n.e7LibraryStoredCredential(connection.label),
            'env' => l10n.e7LibraryServerEnvironment,
            _ => connection.label,
          },
      }.join(' · ');
    }
    if (integration.methods.isEmpty) {
      return l10n.e7LibraryNoConnectionMethodsAvailable;
    }
    // How to connect, in the person's words: add a key, or the server's
    // own sign-in names ("Claude Pro/Max"); a key the server reads from
    // its environment is set up there.
    final ways = <String>{
      for (final method in keyLedConnectMethods(
        integration.id,
        integration.methods,
      ))
        if (method.type == 'key')
          l10n.integrationsConnectWithKey
        else if (method.type != 'env')
          method.label,
    };
    if (ways.isEmpty) return l10n.integrationsConnectOnServer;
    return ways.join(' · ');
  }

  Future<void> _disconnectIntegration(PresentedIntegration presented) async {
    final l10n = _l10n;
    final integration = presented.integration;
    final environmentRemains = integration.hasEnvironmentConnection;
    if (_busy.contains(integration.id)) return;
    Object? failure;
    final confirmed = await showKitConfirm(
      context,
      icon: AppIconography.unlink,
      title: l10n.e7LibraryDisconnect2(presented.name),
      body: l10n.integrationsDisconnectBody(presented.name),
      consequences: [
        if (environmentRemains) l10n.e7LibraryEnvironmentRemainsAfterDisconnect,
      ],
      confirmLabel: l10n.integrationsDisconnectNamed(presented.name),
      kind: KitConfirmKind.destructive,
      confirmKey: const ValueKey('confirm-provider-disconnect'),
      action: () async {
        try {
          final repository = await _requireActionRepository();
          await repository.disconnectIntegration(integration);
        } catch (error) {
          failure = error;
        }
      },
    );
    if (!confirmed || !mounted) return;
    if (failure != null) {
      _showError(failure!);
      return;
    }
    await _runIntegrationAction(integration.id, () async {
      final repository = await _requireActionRepository();
      await Future.wait([
        _loadIntegrations(repository),
        widget.controller.refreshCatalog(),
      ]);
      if (!mounted) return;
      _say(
        environmentRemains
            ? _l10n.e7LibraryCredentialRemovedServerEnvironmentRemainsActive(
                presented.name,
              )
            : _l10n.e7LibraryDisconnected2(presented.name),
      );
    });
  }

  /// "Connect {name}": one method goes straight to it; several open a
  /// titled sheet whose rows say where each one goes. [onlyCommand] runs
  /// the server sign-in command from the row menu.
  Future<void> _connectIntegration(
    IntegrationInfo integration, {
    bool onlyCommand = false,
  }) async {
    final actionL10n = _l10n;
    final source = _mcpSource;
    final commandSupported =
        widget.controller.capabilities.integrationCommandAuth &&
        widget.controller.repository is IntegrationCommandGateway;
    final name =
        presentIntegrations([integration]).firstOrNull?.name ??
        integration.name;
    final methods = orderConnectMethods(
      keyLedConnectMethods(
        integration.id,
        integration.methods
            .where(
              (method) =>
                  (!onlyCommand &&
                      (method.type == 'key' || method.type == 'oauth')) ||
                  (commandSupported &&
                      method.type == 'command' &&
                      method.id != null),
            )
            .toList(),
      ),
    );
    if (methods.isEmpty) return;
    final method = methods.length == 1
        ? methods.single
        : await showKitChoiceSheet<IntegrationMethodInfo>(
            context,
            title: actionL10n.e7LibraryConnect2(name),
            subtitle: actionL10n.integrationsConnectMethodSubtitle,
            sheetKey: const ValueKey('connect-method-sheet'),
            choices: [
              for (final method in methods)
                KitChoice<IntegrationMethodInfo>(
                  value: method,
                  title: method.label,
                  leading: KitRow.icon(
                    context,
                    method.type == 'key'
                        ? AppIconography.permissions
                        : method.type == 'command'
                        ? AppIconography.terminal
                        : AppIconography.browser,
                  ),
                  supporting: method.type == 'command'
                      ? actionL10n.commandAuthMethodHint
                      : connectMethodHint(method, actionL10n),
                ),
            ],
          );
    if (method == null || !mounted || source != _mcpSource) return;
    if (method.type == 'command') {
      await showKitSheet<void>(
        context,
        title: actionL10n.integrationsServerSignIn(name),
        icon: AppIconography.terminal,
        height: KitSheetHeight.full,
        body: (_) => _CommandAuthSheet(
          controller: widget.controller,
          integration: integration,
          method: method,
          name: name,
        ),
      );
      if (mounted && source == _mcpSource) await _retryIntegrations();
    } else if (method.type == 'key') {
      await _connectWithKey(integration, method, name);
    } else {
      await _connectWithOAuth(integration, method, name);
    }
  }

  /// The key goes straight to the server inside the dialog: it shows it is
  /// working, a rejected key keeps the dialog open with the reason under
  /// the field, and the key is never shown, logged or kept (SEC-3).
  Future<void> _connectWithKey(
    IntegrationInfo integration,
    IntegrationMethodInfo method,
    String name,
  ) async {
    final l10n = _l10n;
    if (_busy.contains(integration.id)) return;
    final source = _mcpSource;
    final keyPage = providerKeyPageUrl(integration.id);
    // The dialog closes for the key page's confirmation and comes back
    // after it, so the person returns to where they were.
    var wantsKeyPage = false;
    final value = await showKitInputDialog(
      context,
      title: l10n.e7LibraryConnect2(name),
      label: method.label,
      helper: keyPage == null
          ? l10n.integrationsKeyHelper
          : l10n.integrationsKeyOnlyHelper(name),
      alternative: keyPage == null
          ? null
          : KitAction(
              key: const ValueKey('provider-get-key'),
              label: l10n.integrationsGetKey(name),
              icon: AppIconography.browser,
              onPressed: () => wantsKeyPage = true,
            ),
      kind: KitFieldKind.secret,
      confirmLabel: l10n.e7LibraryConnect,
      cancelLabel: l10n.workCancel,
      fieldKey: const ValueKey('provider-key-field'),
      confirmKey: const ValueKey('confirm-provider-key'),
      validate: (value) =>
          value.trim().isEmpty ? l10n.integrationsKeyEmpty : null,
      onSubmit: (value) async {
        try {
          final repository = await _requireActionRepository();
          await repository.connectIntegrationKey(integration.id, value.trim());
          return null;
        } catch (_) {
          // The server's reply is not echoed: it could quote the key.
          return l10n.integrationsKeyRejected;
        }
      },
    );
    if (!mounted || source != _mcpSource) return;
    if (value == null && wantsKeyPage && keyPage != null) {
      await openExternalLink(context, keyPage);
      if (!mounted || source != _mcpSource) return;
      await _connectWithKey(integration, method, name);
      return;
    }
    if (value == null) return;
    await _runIntegrationAction(integration.id, () async {
      await Future.wait([_load(), widget.controller.refreshCatalog()]);
      if (!mounted || source != _mcpSource) return;
      _sayKeySaved(integration.id, name);
    });
  }

  /// What the person can rely on after a key was saved: only a provider the
  /// server reports as loaded, with a model in the catalog, is called ready.
  void _sayKeySaved(String id, String name) {
    final controller = widget.controller;
    final l10n = _l10n;
    if (controller.unloadedProviderIDs.contains(id)) {
      if (controller.providerReloadWaitingOn > 0) {
        _say(l10n.integrationsKeySavedWaiting(name));
      } else if (controller.unloadedProvidersUnusable) {
        _say(
          l10n.integrationsKeySavedUnusable(name),
          tone: AppStatusTone.failure,
        );
      } else {
        _say(l10n.integrationsKeySavedPending(name));
      }
      return;
    }
    final hasModel =
        controller.catalog?.models.any((m) => m.providerID == id) ?? false;
    _say(
      hasModel
          ? l10n.integrationsKeySavedReady(name)
          : l10n.integrationsKeySavedPending(name),
    );
  }

  Future<void> _connectWithOAuth(
    IntegrationInfo integration,
    IntegrationMethodInfo method,
    String name,
  ) async {
    final actionL10n = _l10n;
    if (method.id == null) return;
    final source = _authSourceFor(widget.controller);
    final location = widget.controller.locationRevision;
    final inputs = await _oauthInputs(method, name);
    if (inputs == null ||
        !mounted ||
        source != _authSourceFor(widget.controller)) {
      return;
    }
    if (widget.controller.integrationAuthRecoverySupported) {
      await _runIntegrationAction(integration.id, () async {
        final launch = await widget.controller.startRecoverableIntegrationOAuth(
          integration.id,
          method.id!,
          inputs: inputs,
          locationRevision: location,
        );
        if (!mounted || source != _authSourceFor(widget.controller)) return;
        // Persisted before handing off to the browser. Declining/open failure
        // retains the row: only an explicit Cancel contacts the server again.
        final destination = parseAuthorizationUrl(launch.url, l10n: actionL10n);
        final confirmed = await _confirmAuthorizationLaunch(
          destination,
          instructions: launch.instructions,
        );
        if (!confirmed ||
            !mounted ||
            source != _authSourceFor(widget.controller)) {
          return;
        }
        final opened = await _openAuthorization(destination);
        if (!opened && mounted && source == _authSourceFor(widget.controller)) {
          _say(
            actionL10n.e7LibraryAuthorizationWasNotOpenedThePendingAttempt,
            tone: AppStatusTone.failure,
          );
        }
      });
      return;
    }
    await _runIntegrationAction(integration.id, () async {
      final legacySource = _mcpSource;
      final repository = await _requireActionRepository();
      if (!mounted || legacySource != _mcpSource) return;
      final launch = await repository.startIntegrationOAuth(
        integration.id,
        method.id!,
        inputs: inputs,
      );
      if (!mounted || legacySource != _mcpSource) return;
      setState(() {
        _pendingOAuth = _PendingIntegrationOAuth(
          integrationID: integration.id,
          integrationName: name,
          launch: launch,
          source: legacySource,
        );
      });
      try {
        final destination = parseAuthorizationUrl(launch.url, l10n: actionL10n);
        if (!await _confirmAuthorizationLaunch(
          destination,
          instructions: launch.instructions,
        )) {
          await _cancelOAuth();
          return;
        }
        if (!mounted || legacySource != _mcpSource) return;
        final opened = await _openAuthorization(destination);
        if (!opened) {
          throw ProductException(actionL10n.e7LibraryCouldNotOpenOAuth);
        }
      } catch (_) {
        await _cancelOAuth(showError: false);
        rethrow;
      }
    });
  }

  Future<void> _checkOAuth() async {
    final pending = _pendingOAuth;
    if (pending == null || _checkingOAuth) return;
    setState(() => _checkingOAuth = true);
    try {
      final repository = await _requireOAuthRepository(pending);
      final status = await repository.integrationOAuthStatus(
        pending.launch.attemptID,
      );
      if (!mounted ||
          _pendingOAuth != pending ||
          pending.source != _mcpSource) {
        return;
      }
      if (status.state == IntegrationAuthState.complete) {
        final completed = pending.copyWith(status: status);
        setState(() => _pendingOAuth = completed);
        await _finishOAuth(completed);
        return;
      }
      setState(() => _pendingOAuth = pending.copyWith(status: status));
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _checkingOAuth = false);
    }
  }

  Future<void> _enterOAuthCode() async {
    final pending = _pendingOAuth;
    if (pending == null || pending.launch.mode != IntegrationAuthMode.code) {
      return;
    }
    final l10n = _l10n;
    final instructions = pending.launch.instructions.trim();
    final code = await _showFinishSignInDialog(
      context,
      label: l10n.e7LibraryAuthorizationCode,
      helper: instructions.isNotEmpty
          ? instructions
          : l10n.integrationsFinishSignInProviderHelper,
      fieldKey: const ValueKey('oauth-completion-code'),
      confirmKey: const ValueKey('complete-provider-oauth'),
      parse: providerOAuthCompletionCode,
    );
    if (code == null || !mounted || _pendingOAuth != pending) return;
    setState(() => _checkingOAuth = true);
    try {
      final repository = await _requireOAuthRepository(pending);
      await repository.completeIntegrationOAuth(
        pending.launch.attemptID,
        code: code,
      );
      if (!mounted || pending.source != _mcpSource) return;
      final status = await repository.integrationOAuthStatus(
        pending.launch.attemptID,
      );
      if (!mounted ||
          _pendingOAuth != pending ||
          pending.source != _mcpSource) {
        return;
      }
      if (status.state == IntegrationAuthState.complete) {
        final completed = pending.copyWith(status: status);
        setState(() => _pendingOAuth = completed);
        await _finishOAuth(completed);
      } else {
        setState(() => _pendingOAuth = pending.copyWith(status: status));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _checkingOAuth = false);
    }
  }

  Future<void> _finishOAuth(_PendingIntegrationOAuth pending) async {
    final repository = await _requireOAuthRepository(pending);
    // §7 row 25: v2 hot-reloads its provider config, so the explicit runtime
    // refresh is skipped rather than failing a connect that already worked.
    if (widget.controller.capabilities.providerRuntimeRefresh) {
      try {
        await repository.refreshProviderRuntime();
      } on ProviderRuntimeBusyException {
        // Replies are running and a refresh would stop them; the model
        // picker loads the new provider once they finish.
      }
    }
    if (!mounted || pending.source != _mcpSource) return;
    await Future.wait([_load(), widget.controller.refreshCatalog()]);
    if (!mounted || _pendingOAuth != pending) return;
    setState(() => _pendingOAuth = null);
    if (widget.controller.unloadedProviderIDs.contains(pending.integrationID)) {
      // Saved is not loaded: say which, never "connected".
      _sayKeySaved(pending.integrationID, pending.integrationName);
    } else {
      _say(_l10n.e7LibraryIsConnected(pending.integrationName));
    }
  }

  Future<void> _cancelOAuth({bool showError = true}) async {
    final pending = _pendingOAuth;
    if (pending == null) return;
    try {
      final repository = await _requireOAuthRepository(pending);
      await repository.cancelIntegrationOAuth(pending.launch.attemptID);
      if (mounted && _pendingOAuth == pending) {
        setState(() {
          _pendingOAuth = null;
        });
      }
    } catch (error) {
      if (showError && mounted) _showError(error);
    }
  }

  Future<ServerOperationsGateway> _requireOAuthRepository(
    _PendingIntegrationOAuth pending,
  ) async {
    final actionL10n = _l10n;
    if (pending.source != _mcpSource) {
      throw ProductException(actionL10n.e7LibraryTheSignInSourceChanged);
    }
    final repository = await _requireActionRepository();
    if (!mounted || pending.source != _mcpSource) {
      throw ProductException(actionL10n.e7LibraryTheSignInSourceChanged);
    }
    return repository;
  }

  Future<ServerOperationsGateway> _requireMcpOAuthRepository(
    _PendingMcpOAuth pending,
  ) async {
    final actionL10n = _l10n;
    if (pending.source != _mcpSource) {
      throw ProductException(actionL10n.e7LibraryTheSignInSourceChanged);
    }
    final repository = await _requireActionRepository();
    if (!mounted || pending.source != _mcpSource) {
      throw ProductException(actionL10n.e7LibraryTheSignInSourceChanged);
    }
    return repository;
  }

  Future<bool> _openAuthorization(Uri destination) async {
    final source = _authSourceFor(widget.controller);
    final route = ModalRoute.of(context);
    final validated = parseAuthorizationUrl(
      destination.toString(),
      l10n: _l10n,
    );
    final result = await openExternalLink(
      context,
      validated.toString(),
      launcher: (uri) async {
        if (!mounted ||
            source != _authSourceFor(widget.controller) ||
            !(route?.isCurrent ?? true)) {
          return false;
        }
        try {
          return await (widget.authorizationLauncher?.call(uri) ??
              launchExternalUri(uri));
        } catch (_) {
          // The shared policy's generic launcher error could include a URL.
          // Auth URLs are sensitive: never forward platform exception text.
          return false;
        }
      },
    );
    return result == ExternalLinkOutcome.opened;
  }

  /// A sign-in failure in words that never quote the server's reply (it
  /// can carry a code or an address with a token).
  void _showError(Object error) => _say(
    _l10n.e7LibraryCouldNotConfirmAuthenticationReturnToThe,
    tone: AppStatusTone.failure,
  );

  Future<Map<String, String>?> _oauthInputs(
    IntegrationMethodInfo method,
    String providerName,
  ) async {
    if (method.prompts.isEmpty) return const {};
    return _showOAuthInputsSheet(
      context,
      method: method,
      providerName: providerName,
    );
  }

  Future<void> _runIntegrationAction(
    String id,
    Future<void> Function() action,
  ) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  void dispose() {
    _serverLoadGeneration++;
    _resourceLoadGeneration++;
    _integrationLoadGeneration++;
    _providerSearch.dispose();
    if (_pendingMcpOAuth case final pending?) {
      unawaited(_disposePendingMcpAuthentication(pending));
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _disposePendingMcpAuthentication(
    _PendingMcpOAuth pending,
  ) async {
    await pending.listener?.close();
    // No network action on navigation, particularly not through a new source.
    // This legacy protocol has no persisted attempt-recovery contract.
  }
}

/// A provider the server configured itself (an `opencode.json` entry) shown
/// as an integration: connected through the server, nothing to connect from
/// here, and no credential mobile could remove.
IntegrationInfo configuredProviderIntegration(
  CatalogProvider provider,
  AppLocalizations l10n,
) => IntegrationInfo(
  id: provider.id,
  name: provider.name.isEmpty ? provider.id : provider.name,
  methods: const [],
  connections: [
    IntegrationConnectionInfo(
      type: 'config',
      label: l10n.e7LibraryConfiguredOnTheServer,
    ),
  ],
  connectionCount: 1,
);

/// Case-insensitive match of a provider row against a search query: the
/// presented name, the wire id and its consolidated aliases (so "zhipu" finds
/// the Z.AI routes), the logo domain minus its TLD (so "aws" finds Bedrock),
/// and the ids and names of the catalog [models] the provider serves. An
/// empty query matches everything.
bool _providerMatchesSearch(
  PresentedIntegration presented,
  String query, {
  Iterable<CatalogModel> models = const [],
}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  final integration = presented.integration;
  final terms = <String>{
    presented.name,
    integration.id,
    integration.name,
    ..._providerSearchAliases(integration.id),
    for (final model in models) ...[model.id, model.name],
  };
  return terms.any((term) => term.toLowerCase().contains(normalized));
}

/// Wire ids OpenCode consolidates into one product family; every id in the
/// same presentation group is a search alias for the others.
const _consolidatedProviderIDs = [
  'zai',
  'zhipuai',
  'zai-coding-plan',
  'zhipuai-coding-plan',
];

Set<String> _providerSearchAliases(String providerID) {
  final presentation = presentProvider(providerID);
  final domainLabels = providerLogoDomain(providerID).split('.');
  return {
    presentation.groupID,
    presentation.name,
    ?presentation.route,
    for (final alias in _consolidatedProviderIDs)
      if (presentProvider(alias).groupID == presentation.groupID) alias,
    // Drop the TLD so the "<id>.com" fallback never matches "com" for all.
    if (domainLabels.length > 1)
      domainLabels.sublist(0, domainLabels.length - 1).join('.'),
  };
}
