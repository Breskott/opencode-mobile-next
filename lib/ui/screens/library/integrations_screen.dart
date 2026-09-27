part of '../library_screen.dart';

/// Which of the two integration domains this screen shows: LLM provider
/// connections, MCP servers and their resources, or the legacy combined
/// surface.
enum IntegrationsMode { providers, mcp, all }

/// Providers and MCP servers of the current server, built from kit parts
/// (screen-library-1). The map proposal for this page is `redesign`: the
/// split into agent-driven and catalog MCP setup waits for its wave-3
/// slice; this rebuild keeps today's structure in the visual language.
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
        // On the Providers page the count moves up here instead of
        // repeating the page's name as a section label.
        subtitle: widget.mode == IntegrationsMode.providers
            ? _providerSummary()
            : null,
        actions: [
          if (_showMcp && _catalogAvailable)
            KitAction(
              key: const ValueKey('add-mcp-server'),
              label: l10n.mcpAdd,
              icon: AppIconography.add,
              onPressed: _openMcpSetup,
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

  /// "2 of 14 connected", once the list has loaded.
  String? _providerSummary() {
    final loaded = _integrations;
    if (loaded == null) return null;
    final integrations = _withConfiguredProviders(loaded);
    if (integrations.isEmpty) return null;
    return _l10n.integrationsProvidersSummary(
      integrations
          .where((integration) => integration.connectionCount > 0)
          .length,
      integrations.length,
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
    final connected = integrations
        ?.where((integration) => integration.connectionCount > 0)
        .length;
    return [
      if (widget.mode == IntegrationsMode.all)
        _SectionLabel(
          l10n.usageProviders,
          explanation: l10n.e7LibraryTheModelProvidersThisOpenCodeServerCan,
          trailing: integrations == null || integrations.isEmpty
              ? null
              : l10n.integrationsProvidersSummary(
                  connected ?? 0,
                  integrations.length,
                ),
          trailingKey: const ValueKey('provider-summary'),
        )
      else
        SizedBox(height: KitTokens.of(context).space3),
      // Sign-ins waiting on the person lead the section (urgency first).
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
      for (final entry in widget.controller.uncertainIntegrationAuth)
        _UncertainAuthRecoveryTile(
          controller: widget.controller,
          integrationID: entry.integrationID,
          kind: entry.kind,
        ),
      for (final entry in widget.controller.pendingIntegrationAuth)
        _PendingAuthRecoveryTile(
          key: ValueKey(entry.key),
          controller: widget.controller,
          entry: entry,
          onComplete: () async {
            await Future.wait([_load(), widget.controller.refreshCatalog()]);
          },
        ),
      if (_pendingOAuth case final pending?)
        _railed(
          _PendingOAuthNotice(
            pending: pending,
            checking: _checkingOAuth,
            recoverable: widget.controller.integrationAuthRecoverySupported,
            onContinue: pending.status?.state == IntegrationAuthState.complete
                ? () => _finishOAuth(pending)
                : pending.launch.mode == IntegrationAuthMode.code
                ? _enterOAuthCode
                : _checkOAuth,
            onCancel: _cancelOAuth,
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
      if (staleSource)
        _railed(
          KitStateView.error(
            key: const ValueKey('providers-load-failed'),
            title: l10n.e7LibraryCouldNotLoadThisSection,
            body: l10n.credentialScopeChanged,
            size: KitStateSize.inline,
            retry: KitAction(
              label: l10n.commonRetry,
              onPressed: _retryIntegrations,
            ),
          ),
        )
      else if (_integrationError != null)
        _railed(
          KitStateView.error(
            key: const ValueKey('providers-load-failed'),
            title: l10n.e7LibraryCouldNotLoadThisSection,
            body: _integrationError,
            size: KitStateSize.inline,
            retry: KitAction(
              label: l10n.commonRetry,
              onPressed: _retryIntegrations,
            ),
          ),
        )
      else if (integrations == null)
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
        if (matching.isEmpty)
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
            children: [
              for (final presented in matching)
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
    return [
      if (widget.mode == IntegrationsMode.all)
        _SectionLabel(
          l10n.integrationsMcpServersLabel,
          explanation: Glossary.mcp.explanation,
          trailing: servers == null || servers.isEmpty
              ? null
              : '${servers.length}',
        )
      else
        SizedBox(height: KitTokens.of(context).space3),
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
        _railed(
          KitStateView.error(
            key: const ValueKey('mcp-load-failed'),
            title: l10n.e7LibraryCouldNotLoadThisSection,
            body: _serverError ?? l10n.mcpScopeChanged,
            size: KitStateSize.inline,
            retry: KitAction(label: l10n.commonRetry, onPressed: _retryServers),
          ),
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
              onPressed: _openMcpSetup,
            ),
          ),
        )
      else if (servers != null)
        KitRowGroup(
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
                removalSupported: _removalSupported,
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
    return [
      _SectionLabel(
        l10n.e7LibraryResources,
        explanation: l10n.e7LibraryFilesAndDataThatConnectedMCPServers,
        trailing: resources == null || resources.isEmpty
            ? null
            : '${resources.length}',
      ),
      if (_resourceError != null)
        _railed(
          KitStateView.error(
            key: const ValueKey('resources-load-failed'),
            title: l10n.e7LibraryCouldNotLoadThisSection,
            body: _resourceError,
            size: KitStateSize.inline,
            retry: KitAction(
              label: l10n.commonRetry,
              onPressed: _retryResources,
            ),
          ),
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
    if (integration.connections.isNotEmpty) {
      return integration.connections
          .map((connection) {
            return switch (connection.type) {
              'credential' => l10n.e7LibraryStoredCredential(connection.label),
              'env' => l10n.e7LibraryServerEnvironment2(connection.label),
              _ => connection.label,
            };
          })
          .join(' · ');
    }
    if (integration.methods.isEmpty) {
      return l10n.e7LibraryNoConnectionMethodsAvailable;
    }
    return integration.methods
        .map((method) {
          if (method.type == 'env') {
            final names = method.environmentNames.join(', ');
            return names.isEmpty
                ? l10n.e7LibraryConfiguredOnTheServer
                : l10n.e7LibraryServerEnvironment2(names);
          }
          return method.label;
        })
        .join(' · ');
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
    final value = await showKitInputDialog(
      context,
      title: l10n.e7LibraryConnect2(name),
      label: method.label,
      helper: l10n.integrationsKeyHelper,
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
    if (value == null || !mounted || source != _mcpSource) return;
    await _runIntegrationAction(integration.id, () async {
      await Future.wait([_load(), widget.controller.refreshCatalog()]);
      if (mounted) _say(_l10n.e7LibraryIsConnected(name));
    });
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
      await repository.refreshProviderRuntime();
    }
    if (!mounted || pending.source != _mcpSource) return;
    await Future.wait([_load(), widget.controller.refreshCatalog()]);
    if (!mounted || _pendingOAuth != pending) return;
    setState(() => _pendingOAuth = null);
    _say(_l10n.e7LibraryIsConnected(pending.integrationName));
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
              launchUrl(uri, mode: LaunchMode.externalApplication));
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
