part of '../library_screen.dart';

/// Which of the two integration domains this screen shows: LLM provider
/// connections, MCP servers and their resources, or the legacy combined
/// surface.
enum IntegrationsMode { providers, mcp, all }

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

  // Used only for equality checks; never render or log this sign-in snapshot.
  Object get _mcpSource {
    return _integrationSourceFor(widget.controller);
  }

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

  Future<void> _load() async {
    await widget.controller.prunePendingIntegrationAuth();
    if (!mounted) return;
    final repository = await widget.controller.prepareActionRepository();
    if (!mounted) return;
    if (repository == null) {
      final message = lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryOpenCodeIsReconnectingTryAgainShortly;
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
        setState(
          () => _serverError = lookupAppLocalizations(
            Localizations.localeOf(context),
          ).mcpLoadFailed,
        );
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
        setState(
          () => _resourceError = lookupAppLocalizations(
            Localizations.localeOf(context),
          ).mcpLoadFailed,
        );
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
      if (mounted) showProductError(context, error);
    } finally {
      if (mounted) setState(() => _busy.remove(server.name));
    }
  }

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
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    void changed() {
      if (!currentScope()) invalidated = true;
    }

    controller.addListener(changed);
    controller.profileDataChanges.addListener(changed);
    setState(() => _removingMcp.add(server.name));
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final confirmed = await showConfirmSheet(
        context,
        icon: AppIconography.delete,
        title: l10n.mcpRemoveTitle(server.name),
        message: l10n.mcpRemoveRuntimeDetail,
        confirmLabel: l10n.mcpRemove,
        cancelLabel: l10n.workCancel,
        destructive: true,
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
      widget.controller.capabilities.mcpRuntimeRemovals &&
      widget.controller.repository is McpRemovalGateway &&
      _serversLocationRevision == widget.controller.locationRevision &&
      identical(_serversRepository, widget.controller.repository);

  Future<void> _startMcpAuthentication(
    McpServerInfo server,
    ServerOperationsGateway repository,
  ) async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
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
        // a manual code/URL path in the pending row below.
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
    final code = await showDialog<String>(
      context: context,
      builder: (context) =>
          _McpOAuthCodeDialog(expectedState: pending.launch.oauthState),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryAuthenticated((pending.server.name).toString())
                : lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryCouldNotConfirmMCPAuthentication,
          ),
        ),
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
      MaterialPageRoute<bool>(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          runtime
              ? lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).mcpRuntimeAdded
              : lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryMCPServerSavedInOpenCode,
        ),
      ),
    );
  }

  Future<ServerOperationsGateway> _requireActionRepository() async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
    final repository = await widget.controller.prepareActionRepository();
    if (repository != null) return repository;
    throw ProductException(
      actionL10n.e7LibraryOpenCodeIsReconnectingTryAgainShortly,
    );
  }

  Future<void> _retryServers() async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.mode) {
          IntegrationsMode.providers => lookupAppLocalizations(
            Localizations.localeOf(context),
          ).usageProviders,
          IntegrationsMode.mcp => 'MCP',
          IntegrationsMode.all => lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryMCPAndIntegrations,
        }),
        actions: [
          if (_showMcp)
            IconButton(
              key: const ValueKey('add-mcp-server'),
              tooltip: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).mcpAdd,
              onPressed: _openMcpSetup,
              icon: const Icon(AppIconography.add),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Providers lead: a new user needs a model before anything else.
            if (_showProviders) ..._providerSection(),
            if (_showMcp) ...[..._mcpSection(), ..._resourceSection()],
          ],
        ),
      ),
    );
  }

  List<Widget> _providerSection() {
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
    return [
      _SectionHeader(
        text: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).usageProviders,
        description: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryTheModelProvidersThisOpenCodeServerCan,
      ),
      if (widget.controller.pendingAuthPersistenceUncertain)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).pendingAuthSaveUncertain,
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await widget.controller.retryPendingAuthPersistence();
                  } catch (_) {
                    if (mounted) {
                      _showError(
                        ProductException(
                          lookupAppLocalizations(
                            Localizations.localeOf(context),
                          ).e7LibraryCouldNotSaveSignInRecovery,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).pendingAuthRetrySave,
                ),
              ),
            ],
          ),
        ),
      if (widget.controller.hasPendingAuthAtOtherSource)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).pendingAuthOtherSource,
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
      if (!widget.controller.integrationAuthRecoverySupported)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).pendingAuthUnsupported,
          ),
        ),
      if (_pendingOAuth case final pending?)
        _PendingOAuthTile(
          pending: pending,
          checking: _checkingOAuth,
          onContinue: pending.status?.state == IntegrationAuthState.complete
              ? () => _finishOAuth(pending)
              : pending.launch.mode == IntegrationAuthMode.code
              ? _enterOAuthCode
              : _checkOAuth,
          onCancel: _cancelOAuth,
        ),
      if (_pendingOAuth != null && _pendingOAuth!.source != _mcpSource)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).pendingAuthUnsupported,
          ),
        ),
      if (staleSource)
        _SectionLoadError(
          message: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).credentialScopeChanged,
          onRetry: _retryIntegrations,
        )
      else if (_integrationError != null)
        _SectionLoadError(
          message: _integrationError!,
          onRetry: _retryIntegrations,
        )
      else if (integrations == null)
        _SectionLoading(
          label: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryLoadingProviders,
        )
      else if (integrations.isEmpty)
        ProductInlineEmpty(
          icon: AppIconography.unlink,
          title: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryNoProviderConnectionsAvailable,
          message: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryThisServerDidNotReturnAnyProvider,
          actionLabel: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).globalSessionsRefresh,
          onAction: _retryIntegrations,
        )
      else ...[
        _providerSearchField(),
        _ProviderSummaryRow(
          connected: integrations
              .where((integration) => integration.connectionCount > 0)
              .length,
          total: integrations.length,
        ),
        if (matching.isEmpty)
          ProductInlineEmpty(
            key: const ValueKey('providers-search-empty'),
            icon: Icons.search_off_rounded,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryNoProvidersMatch((_providerQuery.trim()).toString()),
            message: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryTryAProviderNameItsIdOr,
            actionLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).commonClearSearch,
            onAction: _clearProviderSearch,
          )
        else
          for (final presented in matching) ...[
            _ProviderIntegrationTile(
              commandAuthSupported:
                  widget.controller.capabilities.integrationCommandAuth &&
                  widget.controller.repository is IntegrationCommandGateway,
              presented: presented,
              subtitle: _integrationSubtitle(presented.integration),
              modelCount: _modelCount(presented.integration.id),
              busy: _busy.contains(presented.integration.id),
              onConnect: () => _connectIntegration(presented.integration),
              onDisconnect: () => _disconnectIntegration(presented),
            ),
            if (widget.controller.capabilities.integrationCommandAuth &&
                widget.controller.repository is IntegrationCommandGateway &&
                presented.integration.methods.any(
                  (method) => method.type == 'command' && method.id != null,
                ))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy.contains(presented.integration.id)
                        ? null
                        : () => _connectIntegration(presented.integration),
                    icon: const Icon(AppIconography.terminal),
                    label: Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).commandAuthManage,
                    ),
                  ),
                ),
              ),
            if (widget.controller.capabilities.integrationCredentials &&
                widget.controller.repository is IntegrationCredentialGateway)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy.contains(presented.integration.id)
                        ? null
                        : () => _openCredentials(
                            presented.integration,
                            presented.name,
                          ),
                    icon: const Icon(AppIconography.manageAccount),
                    label: Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).credentialManage,
                    ),
                  ),
                ),
              ),
          ],
      ],
    ];
  }

  Future<void> _openCredentials(
    IntegrationInfo integration,
    String name,
  ) async {
    if (_integrationsSource != _mcpSource) return;
    final source = _mcpSource;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CredentialManagementSheet(
        controller: widget.controller,
        integrationID: integration.id,
        integrationName: name,
      ),
    );
    if (mounted && source == _mcpSource) await _retryIntegrations();
  }

  /// Mirrors the model picker's search field: a dense filled field with a
  /// leading search glyph and a clear button once there is text to clear.
  Widget _providerSearchField() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
      child: TextField(
        key: const ValueKey('providers-search'),
        controller: _providerSearch,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _providerQuery = value),
        decoration: InputDecoration(
          hintText: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibrarySearchProvidersOrModels,
          prefixIcon: const Icon(AppIconography.search),
          isDense: true,
          suffixIcon: _providerQuery.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('providers-search-clear'),
                  tooltip: lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryClearProviderSearch,
                  onPressed: _clearProviderSearch,
                  icon: const Icon(AppIconography.close),
                ),
        ),
      ),
    );
  }

  void _clearProviderSearch() {
    _providerSearch.clear();
    setState(() => _providerQuery = '');
  }

  List<Widget> _mcpSection() {
    final servers = _servers;
    return [
      _SectionHeader(
        label: Builder(
          builder: (context) {
            final style = _SectionHeader.labelStyle(Theme.of(context));
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InfoLabel.glossary(Glossary.mcp, style: style, iconSize: 13),
                Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibrarySERVERS,
                  style: style,
                ),
              ],
            );
          },
        ),
        description: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryAddOnServersThatGiveTheAgent,
      ),
      if (_serverError != null)
        _SectionLoadError(message: _serverError!, onRetry: _retryServers),
      if (_removalError != null)
        _SectionLoadError(message: _removalError!, onRetry: _retryServers),
      if (_serversSource != null && _serversSource != _mcpSource)
        _SectionLoadError(
          message: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).mcpScopeChanged,
          onRetry: _retryServers,
        ),
      if (servers == null && _serverError == null)
        _SectionLoading(
          label: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryLoadingMCPServers,
        )
      else if (servers != null && servers.isEmpty)
        ProductInlineEmpty(
          icon: AppIconography.network,
          title: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryNoMCPServersConfigured,
          message: widget.controller.capabilities.mcpConfigWrites
              ? lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibrarySaveOneForThisProjectOrEvery
              : lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).mcpRuntimeEmpty,
          actionLabel: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryAddAnMCPServer,
          onAction: _openMcpSetup,
        )
      else if (servers != null)
        for (final server in servers) ...[
          _McpServerTile(
            server: server,
            subtitle: _statusLabel(server.status),
            actionLabel: _pendingMcpOAuth?.server.name == server.name
                ? lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryAuthorizing
                : _actionLabel(server.status),
            busy:
                _busy.contains(server.name) ||
                _removingMcp.contains(server.name) ||
                (_pendingMcpOAuth?.server.name == server.name &&
                    _finishingMcpOAuth),
            authGated: _mcpAuthGated(server.status),
            onAction:
                _serversSource != _mcpSource ||
                    _pendingMcpOAuth?.server.name == server.name ||
                    _mcpAuthGated(server.status)
                ? null
                : () => _action(server),
          ),
          if (_canRemoveMcp)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed:
                      _busy.contains(server.name) ||
                          _removingMcp.contains(server.name) ||
                          _pendingMcpOAuth?.server.name == server.name
                      ? null
                      : () => _removeMcp(server),
                  icon: const Icon(AppIconography.delete),
                  label: Text(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).mcpRemove,
                  ),
                ),
              ),
            ),
          if (_pendingMcpOAuth case final pending?
              when pending.server.name == server.name)
            _PendingMcpOAuthTile(
              pending: pending,
              busy: _finishingMcpOAuth,
              onEnterCode: _enterMcpAuthorizationCode,
              onCancel: _cancelMcpAuthentication,
            ),
        ],
    ];
  }

  List<Widget> _resourceSection() {
    final resources = _resources;
    return [
      _SectionHeader(
        text: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryResources,
        description: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryFilesAndDataThatConnectedMCPServers,
      ),
      if (_resourceError != null)
        _SectionLoadError(message: _resourceError!, onRetry: _retryResources),
      if (resources == null && _resourceError == null)
        _SectionLoading(
          label: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryLoadingAvailableResources,
        )
      else if (resources != null && resources.isEmpty)
        ProductInlineEmpty(
          icon: AppIconography.fileText,
          title: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryNoResourcesAvailable,
          message: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryConnectedMCPServersHaveNotExposedAny,
          actionLabel: _servers?.isEmpty == true
              ? lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryAddAnMCPServer
              : null,
          onAction: _servers?.isEmpty == true ? _openMcpSetup : null,
        )
      else if (resources != null)
        for (final resource in resources)
          ListTile(
            leading: const BrandTile(
              size: 28,
              child: Icon(AppIconography.fileText, size: 16),
            ),
            title: Text(resource.name),
            subtitle: Text(
              '${resource.server} - ${resource.uri}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
          configuredProviderIntegration(
            provider,
            lookupAppLocalizations(Localizations.localeOf(context)),
          ),
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

  Future<bool> _confirmAuthorizationLaunch(
    Uri destination, {
    String instructions = '',
  }) async {
    final host = destination.hasPort
        ? '${destination.host}:${destination.port}'
        : destination.host;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryOpenAuthorizationPage,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryYouAreLeavingThisAppToAuthenticate,
                ),
                const SizedBox(height: 12),
                Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryDestinationHost,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(host, textDirection: TextDirection.ltr),
                if (instructions.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibraryOpenCodeInstructions,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  // Auth instructions may contain a one-time device code.
                  // Display only for this explicit launch; never persist/log.
                  SelectableText(instructions.trim()),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).projectFolderCancel,
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(AppIconography.browser),
                label: Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryOpenBrowser,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// True when the server needs interactive MCP authorization that this
  /// connection has no endpoints to run (§7 row 9).
  bool _mcpAuthGated(String status) =>
      !widget.controller.capabilities.mcpOAuth &&
      (status == 'needs_auth' || status == 'needs_client_registration');

  String _statusLabel(String status) => switch (status) {
    'connected' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryConnectedAndToolsAreAvailable,
    'disabled' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryDisconnected,
    'failed' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryConnectionFailed,
    'needs_auth' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryAuthenticationRequired,
    'needs_client_registration' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryClientRegistrationRequired,
    _ => status.replaceAll('_', ' '),
  };

  String _actionLabel(String status) => switch (status) {
    'connected' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryDisconnect,
    'needs_auth' || 'needs_client_registration' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryAuthenticate,
    'failed' => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).isolatedTaskRetryOpen,
    _ => lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryConnect,
  };

  String _integrationSubtitle(IntegrationInfo integration) {
    if (integration.connections.isNotEmpty) {
      return integration.connections
          .map((connection) {
            return switch (connection.type) {
              'credential' => lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryStoredCredential((connection.label).toString()),
              'env' => lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryServerEnvironment2((connection.label).toString()),
              _ => connection.label,
            };
          })
          .join(' - ');
    }
    if (integration.methods.isEmpty) {
      return lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryNoConnectionMethodsAvailable;
    }
    return integration.methods
        .map((method) {
          if (method.type == 'env') {
            final names = method.environmentNames.join(', ');
            return names.isEmpty
                ? lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryConfiguredOnTheServer
                : lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryServerEnvironment2((names).toString());
          }
          return method.label;
        })
        .join(' - ');
  }

  Future<void> _disconnectIntegration(PresentedIntegration presented) async {
    final integration = presented.integration;
    final environmentRemains = integration.hasEnvironmentConnection;
    final confirmed = await showConfirmSheet(
      context,
      icon: AppIconography.unlink,
      title: lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryDisconnect2((presented.name).toString()),
      message: lookupAppLocalizations(Localizations.localeOf(context))
          .e7LibraryTheStoredCredentialWillBeRemovedFrom(
            (environmentRemains
                    ? '\n\n${lookupAppLocalizations(Localizations.localeOf(context)).e7LibraryEnvironmentRemainsAfterDisconnect}'
                    : '')
                .toString(),
          ),
      confirmLabel: lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryDisconnectProvider,
      confirmKey: const ValueKey('confirm-provider-disconnect'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _runIntegrationAction(integration.id, () async {
      final repository = await _requireActionRepository();
      await repository.disconnectIntegration(integration);
      await Future.wait([
        _loadIntegrations(repository),
        widget.controller.refreshCatalog(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            environmentRemains
                ? lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryCredentialRemovedServerEnvironmentRemainsActive(
                    (presented.name).toString(),
                  )
                : lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7LibraryDisconnected2((presented.name).toString()),
          ),
        ),
      );
    });
  }

  Future<void> _connectIntegration(IntegrationInfo integration) async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
    final source = _mcpSource;
    final commandSupported =
        widget.controller.capabilities.integrationCommandAuth &&
        widget.controller.repository is IntegrationCommandGateway;
    final methods = orderConnectMethods(
      integration.methods
          .where(
            (method) =>
                method.type == 'key' ||
                method.type == 'oauth' ||
                (commandSupported &&
                    method.type == 'command' &&
                    method.id != null),
          )
          .toList(),
    );
    if (methods.isEmpty) return;
    final method = methods.length == 1
        ? methods.single
        : await showModalBottomSheet<IntegrationMethodInfo>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final method in methods)
                    ListTile(
                      minTileHeight: 56,
                      leading: Icon(
                        method.type == 'key'
                            ? AppIconography.permissions
                            : method.type == 'command'
                            ? AppIconography.terminal
                            : AppIconography.browser,
                      ),
                      title: Text(method.label),
                      subtitle: Text(
                        method.type == 'command'
                            ? actionL10n.commandAuthMethodHint
                            : connectMethodHint(method, actionL10n),
                      ),
                      isThreeLine:
                          connectMethodHint(method, actionL10n).length > 40,
                      onTap: () => Navigator.pop(context, method),
                    ),
                ],
              ),
            ),
          );
    if (method == null || !mounted || source != _mcpSource) return;
    if (method.type == 'command') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _CommandAuthSheet(
          controller: widget.controller,
          integration: integration,
          method: method,
        ),
      );
      if (mounted && source == _mcpSource) await _retryIntegrations();
    } else if (method.type == 'key') {
      await _connectWithKey(integration, method);
    } else {
      await _connectWithOAuth(integration, method);
    }
  }

  Future<void> _connectWithKey(
    IntegrationInfo integration,
    IntegrationMethodInfo method,
  ) async {
    final key = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryConnect2((integration.name).toString()),
        ),
        content: TextField(
          controller: key,
          textDirection: TextDirection.ltr,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: method.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).projectFolderCancel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, key.text.trim()),
            child: Text(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryConnect,
            ),
          ),
        ],
      ),
    );
    key.dispose();
    if (value?.isNotEmpty != true) return;
    await _runIntegrationAction(integration.id, () async {
      final repository = await _requireActionRepository();
      await repository.connectIntegrationKey(integration.id, value!);
      await Future.wait([_load(), widget.controller.refreshCatalog()]);
    });
  }

  Future<void> _connectWithOAuth(
    IntegrationInfo integration,
    IntegrationMethodInfo method,
  ) async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (method.id == null) return;
    final source = _authSourceFor(widget.controller);
    final location = widget.controller.locationRevision;
    final inputs = await _oauthInputs(method);
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
          _showError(
            ProductException(
              actionL10n.e7LibraryAuthorizationWasNotOpenedThePendingAttempt,
            ),
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
          integrationName: integration.name,
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
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _OAuthCodeDialog(
        integrationName: pending.integrationName,
        instructions: pending.launch.instructions,
      ),
    );
    if (code == null || !mounted || _pendingOAuth != pending) return;
    setState(() => _checkingOAuth = true);
    try {
      final repository = await _requireOAuthRepository(pending);
      await repository.completeIntegrationOAuth(
        pending.launch.attemptID,
        code: providerOAuthCompletionCode(code),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryIsConnected((pending.integrationName).toString()),
        ),
      ),
    );
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
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
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
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
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
      l10n: lookupAppLocalizations(Localizations.localeOf(context)),
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

  void _showError(Object error) => showProductError(
    context,
    ProductException(
      lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryCouldNotConfirmAuthenticationReturnToThe,
    ),
  );

  Future<Map<String, String>?> _oauthInputs(
    IntegrationMethodInfo method,
  ) async {
    if (method.prompts.isEmpty) return const {};
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _OAuthInputsDialog(method: method),
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
