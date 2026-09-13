import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/product_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../widgets/product_states.dart';
import '../widgets/info_label.dart';
import '../app_iconography.dart';

class McpSetupScreen extends StatefulWidget {
  final ConnectionController controller;

  const McpSetupScreen({super.key, required this.controller});

  @override
  State<McpSetupScreen> createState() => _McpSetupScreenState();
}

class _McpSetupScreenState extends State<McpSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _command = TextEditingController();
  final _cwd = TextEditingController();
  final _headers = TextEditingController();
  final _environment = TextEditingController();
  final _timeout = TextEditingController();

  late McpConfigScope _scope;
  late final String? _profileId;
  late final int _location;
  late final String? _directory, _workspace;
  late final bool _runtime;
  bool _detached = false;
  McpServerKind _kind = McpServerKind.remote;
  bool _detectOAuth = true;
  bool _saving = false;
  bool _configurationSaved = false;
  String? _saveError;

  bool get _hasProject => _directory?.trim().isNotEmpty == true;
  bool get _editable => !_saving && !_configurationSaved && !_detached;
  bool get _scopeMatches =>
      widget.controller.profile?.id == _profileId &&
      widget.controller.locationRevision == _location &&
      widget.controller.directory == _directory &&
      widget.controller.workspace == _workspace;
  bool get _locationMatches =>
      _scopeMatches &&
      (_runtime
          ? widget.controller.capabilities.mcpRuntimeAdds
          : widget.controller.capabilities.mcpConfigWrites);

  @override
  void initState() {
    super.initState();
    _profileId = widget.controller.profile?.id;
    _location = widget.controller.locationRevision;
    _directory = widget.controller.directory;
    _workspace = widget.controller.workspace;
    _runtime =
        !widget.controller.capabilities.mcpConfigWrites &&
        widget.controller.capabilities.mcpRuntimeAdds;
    _scope = _runtime
        ? McpConfigScope.runtimeLocation
        : _hasProject
        ? McpConfigScope.project
        : McpConfigScope.global;
    _detached = !_locationMatches;
    widget.controller.addListener(_connectionChanged);
  }

  void _connectionChanged() {
    final matches = _configurationSaved ? _scopeMatches : _locationMatches;
    if (!_detached && !matches && mounted) {
      setState(() => _detached = true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_connectionChanged);
    _name.dispose();
    _url.dispose();
    _command.dispose();
    _cwd.dispose();
    _headers.dispose();
    _environment.dispose();
    _timeout.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_editable || !_formKey.currentState!.validate()) {
      return;
    }
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final timeoutText = _timeout.text.trim();
      final draft = McpServerDraft(
        name: _name.text,
        kind: _kind,
        url: _kind == McpServerKind.remote ? _url.text : null,
        command: _kind == McpServerKind.local
            ? _lines(_command.text)
            : const [],
        cwd: _kind == McpServerKind.local ? _cwd.text : null,
        headers: _kind == McpServerKind.remote
            ? _pairs(
                _headers.text,
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryHTTPHeader,
              )
            : const {},
        environment: _kind == McpServerKind.local
            ? _pairs(
                _environment.text,
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryEnvironmentVariable,
              )
            : const {},
        detectOAuth: _detectOAuth,
        timeoutMs: timeoutText.isEmpty ? null : int.parse(timeoutText),
      );
      // Keep repository validation authoritative even if a field validator is
      // changed later.
      draft.toConfigJson();
      final repository = await widget.controller.prepareActionRepository();
      if (!mounted || !_routeIsCurrent(route)) return;
      if (_detached || !_locationMatches) {
        _detached = true;
        throw ProductException(l10n.mcpLocationChanged);
      }
      if (repository == null) {
        throw ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryOpenCodeIsReconnectingTryAgainShortly,
        );
      }
      await repository.addMcpServer(draft, scope: _scope);
      _configurationSaved = true;
      if (!_scopeMatches) {
        _detached = true;
        throw ProductException(l10n.mcpLocationChanged);
      }
      // Runtime adds are already applied. Reconnecting the app is only needed
      // after the persistent v1 configuration write, and only in its location.
      if (!_runtime && _routeIsCurrent(route) && _scopeMatches) {
        await widget.controller.reloadAfterConfigurationChange();
        if (!_scopeMatches) {
          _detached = true;
          throw ProductException(l10n.mcpLocationChanged);
        }
        _throwIfReconnectFailed(l10n);
      }
      if (_routeIsActive(route)) {
        if (route!.isCurrent) {
          navigator.pop(true);
        } else {
          navigator.removeRoute(route, true);
        }
      }
    } catch (error) {
      if (mounted && _routeIsCurrent(route)) {
        if (!(_configurationSaved ? _scopeMatches : _locationMatches)) {
          setState(() => _detached = true);
          return;
        }
        setState(() {
          _saveError = _configurationSaved
              ? lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryButTheAppCouldNotReconnect(
                  (l10n.mcpSavedStatus).toString(),
                  (productErrorText(error)).toString(),
                )
              : productErrorText(error);
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryReconnect() async {
    if (!_configurationSaved || _saving || _detached) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (!_routeIsCurrent(route) || !_scopeMatches) {
      if (mounted && !_scopeMatches) setState(() => _detached = true);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.controller.reloadAfterConfigurationChange();
      if (!mounted || !_routeIsActive(route)) return;
      if (!_scopeMatches) {
        if (route!.isCurrent) setState(() => _detached = true);
        return;
      }
      _throwIfReconnectFailed(l10n);
      if (route!.isCurrent) {
        navigator.pop(true);
      } else {
        navigator.removeRoute(route, true);
      }
    } catch (error) {
      if (mounted && _routeIsCurrent(route)) {
        if (!_scopeMatches) {
          setState(() => _detached = true);
          return;
        }
        setState(() {
          _saveError = lookupAppLocalizations(Localizations.localeOf(context))
              .e7LibraryButTheAppCouldNotReconnect(
                (l10n.mcpSavedStatus).toString(),
                (productErrorText(error)).toString(),
              );
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _routeIsCurrent(ModalRoute<dynamic>? route) =>
      _routeIsActive(route) && route!.isCurrent;

  bool _routeIsActive(ModalRoute<dynamic>? route) =>
      mounted &&
      route != null &&
      identical(ModalRoute.of(context), route) &&
      route.isActive;

  void _throwIfReconnectFailed(AppLocalizations l10n) {
    if (widget.controller.connectionError != null) {
      throw ProductException(l10n.mcpStillDisconnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(Localizations.localeOf(context)).mcpAdd,
        ),
        actions: [
          // A full-size info target instead of an inline label: the form is
          // a lazy list and a header row would push its fields below the
          // fold on a narrow large-text phone.
          IconButton(
            key: const ValueKey('mcp-glossary'),
            tooltip: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryWhatIsMCP,
            icon: const Icon(AppIconography.info),
            onPressed: () => InfoLabel.show(
              context,
              term: Glossary.mcp.term,
              explanation: Glossary.mcp.explanation,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_detached && !_configurationSaved && _saveError == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.mcpLocationChanged),
              ),
            if (_configurationSaved) ...[
              Text(l10n.mcpSavedStatus, key: ValueKey('mcp-saved-status')),
              if (_saveError != null)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.mcpConnectionUnconfirmed,
                    key: ValueKey('mcp-connection-status'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (_saveError case final error?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const ValueKey('mcp-save-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_configurationSaved && _saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  key: const ValueKey('mcp-retry-reconnect'),
                  onPressed: _saving || _detached || !_scopeMatches
                      ? null
                      : _retryReconnect,
                  icon: const Icon(AppIconography.retry),
                  label: Text(l10n.mcpRetryReconnect),
                ),
              ),
            FilledButton.icon(
              key: const ValueKey('mcp-save'),
              onPressed: _saving || (_detached && !_configurationSaved)
                  ? null
                  : _configurationSaved
                  ? () => Navigator.pop(context, true)
                  : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _configurationSaved
                          ? AppIconography.check
                          : AppIconography.save,
                    ),
              label: Text(
                _saving
                    ? (_configurationSaved
                          ? l10n.mcpReconnecting
                          : (_runtime
                                ? l10n.mcpAdding
                                : lookupAppLocalizations(
                                    Localizations.localeOf(context),
                                  ).e7LibrarySavingConfiguration))
                    : _configurationSaved
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).isolatedTaskClose
                    : (_runtime
                          ? l10n.mcpAdd
                          : lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7LibrarySaveMCPServer),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          key: const ValueKey('mcp-setup-form'),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
          children: [
            Text(
              _runtime
                  ? l10n.mcpRuntimeTitle
                  : lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibraryPersistedConfiguration,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _runtime
                  ? l10n.mcpRuntimeDescription
                  : lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibrarySavedByOpenCodeOnTheServerIt,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_runtime) ...[
              Text(l10n.mcpCurrentLocation, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                [
                  if (_hasProject) _directory!,
                  if (_workspace?.isNotEmpty == true)
                    l10n.mcpWorkspaceLocation(_workspace!),
                  if (!_hasProject && _workspace?.isNotEmpty != true)
                    l10n.mcpDefaultLocation,
                ].join('\n'),
                key: const ValueKey('mcp-location'),
              ),
            ] else ...[
              SegmentedButton<McpConfigScope>(
                direction: MediaQuery.textScalerOf(context).scale(14) > 20
                    ? Axis.vertical
                    : Axis.horizontal,
                key: const ValueKey('mcp-scope'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: McpConfigScope.project,
                    enabled: _hasProject,
                    icon: const Icon(AppIconography.files),
                    label: Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryThisProject,
                    ),
                  ),
                  ButtonSegment(
                    value: McpConfigScope.global,
                    icon: Icon(AppIconography.globe),
                    label: Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).usageAllProjects,
                    ),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: !_editable
                    ? null
                    : (value) => setState(() => _scope = value.single),
              ),
              const SizedBox(height: 8),
              Text(
                _scope == McpConfigScope.project
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryWritesOnlyTo((_directory).toString())
                    : lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryWritesToThisOpenCodeServerSGlobal,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('mcp-name'),
              controller: _name,
              textDirection: TextDirection.ltr,
              enabled: _editable,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryServerName,
                hintText: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryDocsOrBrowserTools,
                helperText: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryUniqueWithinTheSelectedConfiguration,
              ),
              validator: (value) => value?.trim().isEmpty == true
                  ? lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibraryEnterAServerName
                  : null,
            ),
            const SizedBox(height: 20),
            SegmentedButton<McpServerKind>(
              direction: MediaQuery.textScalerOf(context).scale(14) > 20
                  ? Axis.vertical
                  : Axis.horizontal,
              key: const ValueKey('mcp-kind'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: McpServerKind.remote,
                  icon: Icon(AppIconography.cloud),
                  label: Text(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibraryRemoteURL,
                  ),
                ),
                ButtonSegment(
                  value: McpServerKind.local,
                  icon: Icon(AppIconography.terminal),
                  label: Text(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibraryLocalCommand,
                  ),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: !_editable
                  ? null
                  : (value) => setState(() {
                      _kind = value.single;
                      _saveError = null;
                    }),
            ),
            const SizedBox(height: 16),
            if (_kind == McpServerKind.remote) ..._remoteFields(),
            if (_kind == McpServerKind.local) ..._localFields(),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('mcp-timeout'),
              controller: _timeout,
              textDirection: TextDirection.ltr,
              enabled: _editable,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryTimeoutInMilliseconds,
                hintText: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryOptional,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final timeout = int.tryParse(text);
                return timeout == null || timeout <= 0
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryEnterAValueGreaterThanZero
                    : null;
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _remoteFields() => [
    TextFormField(
      key: const ValueKey('mcp-url'),
      controller: _url,
      textDirection: TextDirection.ltr,
      enabled: _editable,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryMCPEndpointURL,
        hintText: 'https://server.example/mcp',
        helperText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryHTTPIsAcceptedForLocalDevelopmentServers,
      ),
      validator: (value) {
        final uri = Uri.tryParse(value?.trim() ?? '');
        if (uri == null ||
            !uri.hasAuthority ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.userInfo.isNotEmpty) {
          return lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryEnterAValidHTTPOrHTTPSURL;
        }
        return null;
      },
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const ValueKey('mcp-headers'),
      controller: _headers,
      textDirection: TextDirection.ltr,
      enabled: _editable,
      minLines: 2,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryHTTPHeaders,
        hintText: 'Authorization=Bearer token',
        helperText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryOptionalEnterOneKEYVALUEPairPer,
        alignLabelWithHint: true,
      ),
      validator: (value) => _pairError(
        value ?? '',
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryHTTPHeader,
      ),
    ),
    const SizedBox(height: 8),
    SwitchListTile.adaptive(
      key: const ValueKey('mcp-oauth-detection'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryDetectOAuthAutomatically,
      ),
      subtitle: Text(
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryTurnThisOffWhenTheServerUses,
      ),
      value: _detectOAuth,
      onChanged: !_editable
          ? null
          : (value) => setState(() => _detectOAuth = value),
    ),
  ];

  List<Widget> _localFields() => [
    TextFormField(
      key: const ValueKey('mcp-command'),
      controller: _command,
      textDirection: TextDirection.ltr,
      enabled: _editable,
      minLines: 4,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryCommandAndArguments,
        hintText: 'npx\n-y\n@package/mcp-server',
        helperText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryRunsOnTheOpenCodeServerNotThis,
        alignLabelWithHint: true,
      ),
      validator: (value) => _lines(value ?? '').isEmpty
          ? lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryEnterACommand
          : null,
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const ValueKey('mcp-cwd'),
      controller: _cwd,
      textDirection: TextDirection.ltr,
      enabled: _editable,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryWorkingDirectory,
        hintText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryOptionalServerPath,
      ),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const ValueKey('mcp-environment'),
      controller: _environment,
      textDirection: TextDirection.ltr,
      enabled: _editable,
      minLines: 2,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryEnvironmentVariables,
        hintText: 'LOG_LEVEL=warn',
        helperText: lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryOptionalEnterOneKEYVALUEPairPer,
        alignLabelWithHint: true,
      ),
      validator: (value) => _pairError(
        value ?? '',
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryEnvironmentVariable,
      ),
    ),
  ];

  static List<String> _lines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Map<String, String> _pairs(String value, String label) {
    final result = <String, String>{};
    final lines = value.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator < 1) {
        throw ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryInvalidOnLineUseKEYVALUE(
            (label).toString(),
            (index + 1).toString(),
          ),
        );
      }
      final key = line.substring(0, separator).trim();
      final content = line.substring(separator + 1).trim();
      if (key.isEmpty || key.contains(RegExp(r'[\r\n=]'))) {
        throw ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryInvalidNameOnLine(
            (label).toString(),
            (index + 1).toString(),
          ),
        );
      }
      if (result.containsKey(key)) {
        throw ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryDuplicateName((label).toString(), (key).toString()),
        );
      }
      result[key] = content;
    }
    return result;
  }

  String? _pairError(String value, String label) {
    try {
      _pairs(value, label);
      return null;
    } on ProductException catch (error) {
      return error.message;
    }
  }
}
