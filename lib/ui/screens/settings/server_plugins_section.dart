import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/plugin_inventory.dart';
import '../../../domain/server_gateway.dart' show StreamStatus, CommandInfo;
import '../../../state/plugin_command_mappings.dart';
import '../../widgets/run_command_dialog.dart';
import '../../widgets/confirm_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';

/// What the "On the server" section offers the Plugins page's top bar:
/// "Refresh plugins" and, in its menu, "Clear personal command links". The
/// section fills it in; the page listens and builds its top bar from it, so
/// the section's actions live on the page they act on, not on a label.
class ServerPluginsActions extends ChangeNotifier {
  VoidCallback? _refresh;
  VoidCallback? _clearLinks;

  /// Reloads the server's plugins; null while it cannot run.
  VoidCallback? get refresh => _refresh;

  /// Asks, then clears the personal command links; null when there are
  /// none to keep for this server.
  VoidCallback? get clearLinks => _clearLinks;

  void _set(VoidCallback? refresh, VoidCallback? clearLinks) {
    if ((refresh == null) == (_refresh == null) &&
        (clearLinks == null) == (_clearLinks == null)) {
      _refresh = refresh;
      _clearLinks = clearLinks;
      return;
    }
    _refresh = refresh;
    _clearLinks = clearLinks;
    notifyListeners();
  }
}

/// The "On the server" section of the one Plugins screen
/// (settings/plugins_screen.dart): the server's plugin inventory and the
/// personal command links, carded in one row group like "In this app". It
/// is a section, not a page, so Plugins has one home; the host only builds
/// it when the server has a plugin inventory. Its refresh and "Clear
/// personal command links" go to the page's top bar through [actions].
class ServerPluginsSection extends StatefulWidget {
  const ServerPluginsSection({
    super.key,
    required this.controller,
    this.actions,
  });
  final ConnectionController controller;
  final ServerPluginsActions? actions;
  @override
  State<ServerPluginsSection> createState() => _ServerPluginsSectionState();
}

class _ServerPluginsSectionState extends State<ServerPluginsSection> {
  StreamSubscription<dynamic>? _events;
  Object? _source;
  List<PluginInfo>? _plugins;
  bool _loading = false;
  bool _failed = false;
  bool _reloadQueued = false;
  int _request = 0;
  bool _editingMapping = false;
  bool _mappingLoading = false;
  Map<String, List<String>> _mappings = {};

  /// Whether the server has commands a plugin could be linked to; null
  /// until known (or when the list could not be read), which keeps
  /// "Link commands" offered.
  bool? _hasCommands;
  PluginCommandMappings? get _mappingStore {
    final id = _controller.profile?.id;
    return id == null
        ? null
        : PluginCommandMappings(
            _controller.store.prefs,
            id,
            () => _controller.isProfileReadable(id),
          );
  }

  String get _mappingScope => PluginCommandMappings.scope(
    baseUrl: _controller.profile?.baseUrl ?? '',
    username: _controller.profile?.username,
    directory: _controller.directory,
    workspace: _controller.workspace,
  );
  ConnectionController get _controller => widget.controller;
  bool get _connected =>
      _controller.status == StreamStatus.connected &&
      _controller.isProfileReadable(_controller.profile?.id ?? '');
  bool get _supported =>
      _controller.capabilities.pluginInventory &&
      _controller.repository is PluginGateway;
  Object get _scope => (
    _controller.profile?.id,
    _controller.profile?.baseUrl,
    _controller.profile?.username,
    _controller.directory,
    _controller.workspace,
    _controller.locationRevision,
    _controller.connectionRevision,
    _controller.repository,
    _connected,
    _supported,
  );

  @override
  void initState() {
    super.initState();
    _attach();
    unawaited(_load());
  }

  void _attach() {
    _source = _scope;
    _controller.addListener(_changed);
    _controller.profileDataChanges.addListener(_changed);
    _events = _controller.events.listen((event) {
      if (event.type == 'plugin.added' || event.type == 'plugin.updated') {
        unawaited(_load());
      }
    });
  }

  void _detach(ConnectionController controller) {
    controller.removeListener(_changed);
    controller.profileDataChanges.removeListener(_changed);
    unawaited(_events?.cancel());
  }

  @override
  void didUpdateWidget(covariant ServerPluginsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _detach(oldWidget.controller);
      _request++;
      _plugins = null;
      _mappings = {};
      _hasCommands = null;
      _loading = false;
      _failed = false;
      _reloadQueued = false;
      _attach();
      unawaited(_load());
    }
  }

  void _changed() {
    if (!mounted || _source == _scope) return;
    setState(() {
      _source = _scope;
      _request++;
      _plugins = null;
      _mappings = {};
      _hasCommands = null;
      _loading = false;
      _failed = false;
      _reloadQueued = false;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted || !_connected || !_supported) return;
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    final scope = _scope;
    final request = ++_request;
    final gateway = _controller.repository as PluginGateway;
    setState(() {
      _loading = true;
      _failed = false;
    });
    bool current() => mounted && request == _request && scope == _scope;
    try {
      final result = await gateway.listPlugins();
      if (current()) {
        setState(() {
          _plugins = result;
          _mappings = _mappingStore?.load(_mappingScope) ?? {};
        });
      }
      // "Link commands" only where there is something to link. A failure
      // here leaves it offered; the link sheet then says what went wrong.
      if (current() && _mappingStore != null && result.isNotEmpty) {
        try {
          final commands = await _controller.repository!.listCommands();
          if (current()) {
            setState(
              () => _hasCommands = commands.any(
                (command) => PluginCommandMappings.validName(command.name),
              ),
            );
          }
        } catch (_) {
          if (current()) setState(() => _hasCommands = null);
        }
      }
    } catch (_) {
      if (current()) setState(() => _failed = true);
    } finally {
      if (current()) {
        setState(() => _loading = false);
        if (_reloadQueued) {
          _reloadQueued = false;
          unawaited(_load());
        }
      }
    }
  }

  @override
  void dispose() {
    _request++;
    _detach(_controller);
    // The page may be going too: drop the callbacks without notifying.
    widget.actions
      ?.._refresh = null
      .._clearLinks = null;
    super.dispose();
  }

  /// Publishes what the top bar can offer after this frame (never during a
  /// build).
  void _publishActions() {
    final actions = widget.actions;
    if (actions == null) return;
    final live = _connected && _supported;
    final refresh = live && !_loading
        ? () {
            if (mounted) unawaited(_load());
          }
        : null;
    final clear = live && _mappingStore != null && !_editingMapping
        ? () {
            if (mounted) unawaited(_clearMappings());
          }
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) actions._set(refresh, clear);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final plugins = _plugins ?? const <PluginInfo>[];
    final builtIn = [
      for (final plugin in plugins)
        if (plugin.source == PluginSourceKind.builtin) plugin,
    ];
    final added = [
      for (final plugin in plugins)
        if (plugin.source != PluginSourceKind.builtin) plugin,
    ];
    final builtInActive = builtIn
        .where((plugin) => plugin.status == PluginStatus.active)
        .length;
    final builtInFailed = builtIn
        .where((plugin) => plugin.status == PluginStatus.failed)
        .length;
    _publishActions();
    final tokens = KitTokens.of(context);
    Widget group(List<Widget> children) => KitRowGroup(
      key: const ValueKey('plugins-section-server-group'),
      label: l10n.pluginsSectionOnServer,
      children: children,
    );
    return Column(
      key: const ValueKey('plugins-section-server'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitLoadingBar(
          loading: _connected && _supported && (_loading || _mappingLoading),
          label: l10n.pluginsLoading,
        ),
        if (!_supported)
          group([_message(l10n.pluginsUnsupported)])
        else if (!_connected)
          group([_message(l10n.pluginsDisconnected)])
        else ...[
          if (_failed)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.gutter,
                end: tokens.gutter,
                bottom: tokens.space3,
              ),
              child: KitNotice(
                tone: AppStatusTone.failure,
                message: l10n.pluginsLoadFailed,
                actions: [
                  KitAction(
                    label: l10n.pluginsRetry,
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
          if (_plugins == null && _loading && !_failed)
            const KitSkeletonRows(count: 3)
          else if (_plugins?.isEmpty == true && !_loading && !_failed)
            group([_message(l10n.pluginsEmpty)])
          else if (plugins.isNotEmpty)
            // What the person added is listed openly; the server's own
            // plugins fold into one row, open when one of them failed.
            group([
              for (final plugin in added) _row(plugin, l10n),
              if (builtIn.isNotEmpty)
                KitExpandRow(
                  key: ValueKey('plugins-builtin-${builtInFailed > 0}'),
                  headerKey: const ValueKey('plugins-builtin-group'),
                  initiallyExpanded: builtInFailed > 0,
                  leading: KitRow.icon(context, AppIconography.extensions),
                  title: l10n.pluginsBuiltinGroup,
                  supporting: TextSpan(
                    children: [
                      TextSpan(text: l10n.pluginsBuiltinActive(builtInActive)),
                      if (builtInFailed > 0)
                        TextSpan(
                          text:
                              ' · ${l10n.pluginsBuiltinFailed(builtInFailed)}',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                    ],
                  ),
                  children: [for (final plugin in builtIn) _row(plugin, l10n)],
                ),
            ]),
        ],
      ],
    );
  }

  /// A state of the section as its one row: unsupported, disconnected or
  /// empty, in words.
  Widget _message(String text) => KitRow(
    key: const ValueKey('plugins-section-message'),
    title: text,
    titleMaxLines: 3,
  );

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  void _mappingError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clearMappings() async {
    if (_editingMapping) return;
    final store = _mappingStore;
    final scope = _scope;
    if (store == null) return;
    setState(() => _editingMapping = true);
    try {
      final confirmed = await showConfirmSheet(
        context,
        title: _l10n.pluginMappingClearTitle,
        message: _l10n.pluginMappingClearDescription,
        confirmLabel: _l10n.pluginMappingClearConfirm,
        cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
        icon: AppIconography.unlink,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      if (scope != _scope) {
        throw StateError(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryLocationChanged,
        );
      }
      setState(() => _mappingLoading = true);
      await store.clear();
      if (mounted && scope == _scope) setState(() => _mappings = {});
    } catch (_) {
      if (mounted && scope == _scope) {
        _mappingError(_l10n.pluginMappingClearFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _editingMapping = false;
          _mappingLoading = false;
        });
      }
    }
  }

  Future<void> _editMapping(PluginInfo plugin) async {
    if (_editingMapping || plugin.id == null) return;
    final scope = _scope;
    final mappingScope = _mappingScope;
    final store = _mappingStore;
    if (store == null) return;
    setState(() {
      _editingMapping = true;
      _mappingLoading = true;
    });
    try {
      final commands = await _controller.repository!.listCommands();
      if (!mounted || scope != _scope) return;
      final available = {
        for (final command in commands.take(512))
          if (PluginCommandMappings.validName(command.name)) command.name,
      };
      final selected = {...?_mappings[plugin.id]};
      final names = {...selected, ...available}.toList()..sort();
      bool saving = false;
      String? error;
      setState(() => _mappingLoading = false);
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              scrollable: true,
              title: Text(_l10n.pluginMappingManage),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_l10n.pluginMappingDescription),
                    const SizedBox(height: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (names.isEmpty) Text(_l10n.pluginMappingEmpty),
                        for (final name in names)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('/$name'),
                            subtitle: available.contains(name)
                                ? null
                                : Text(_l10n.pluginMappingUnavailable),
                            value: selected.contains(name),
                            onChanged: saving
                                ? null
                                : (value) => update(() {
                                    if (value == true) {
                                      if (selected.length >=
                                          PluginCommandMappings.maxCommands) {
                                        error = _l10n.pluginMappingLimit;
                                      } else {
                                        selected.add(name);
                                        error = null;
                                      }
                                    } else {
                                      selected.remove(name);
                                      error = null;
                                    }
                                  }),
                          ),
                      ],
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                KitButton.primary(
                  expand: false,
                  label: _l10n.pluginMappingSave,
                  onPressed: saving
                      ? null
                      : () async {
                          update(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            if (!mounted || scope != _scope) {
                              throw StateError(
                                lookupAppLocalizations(
                                  Localizations.localeOf(context),
                                ).e7LibraryLocationChanged,
                              );
                            }
                            await store.set(mappingScope, plugin.id!, selected);
                            if (!dialogContext.mounted) return;
                            if (!mounted || scope != _scope) {
                              Navigator.pop(dialogContext);
                              return;
                            }
                            Navigator.pop(dialogContext, true);
                          } catch (_) {
                            if (dialogContext.mounted) {
                              if (!mounted || scope != _scope) {
                                Navigator.pop(dialogContext);
                                return;
                              }
                              update(() {
                                saving = false;
                                error = _l10n.pluginMappingSaveFailed;
                              });
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted && scope == _scope && saved == true) {
        setState(() => _mappings = store.load(mappingScope));
      }
    } catch (_) {
      if (mounted && scope == _scope) {
        _mappingError(_l10n.pluginMappingLoadFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _editingMapping = false;
          _mappingLoading = false;
        });
      }
    }
  }

  Future<void> _reviewCommand(PluginInfo plugin, String name) async {
    if (_editingMapping) return;
    final scope = _scope;
    final store = _mappingStore;
    final mappingScope = _mappingScope;
    final repository = _controller.repository;
    if (store == null || repository == null) return;
    setState(() {
      _editingMapping = true;
      _mappingLoading = true;
    });
    Future<bool> valid() async {
      if (!mounted || scope != _scope || !_supported || !_connected) {
        return false;
      }
      final plugins = await (repository as PluginGateway).listPlugins();
      if (!mounted || scope != _scope || !_supported || !_connected) {
        return false;
      }
      final commands = await repository.listCommands();
      return mounted &&
          scope == _scope &&
          store.load(mappingScope)[plugin.id]?.contains(name) == true &&
          plugins.any(
            (p) => p.id == plugin.id && p.status == PluginStatus.active,
          ) &&
          commands.any((c) => c.name == name);
    }

    try {
      if (!await valid()) {
        if (mounted && scope == _scope) {
          _mappingError(_l10n.pluginMappingUnavailable);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _mappingLoading = false);
      final sessionID = await showRunCommandDialog(
        context,
        controller: _controller,
        command: CommandInfo(name: name, subtask: false),
        validateCommand: valid,
      );
      if (mounted && sessionID != null && scope == _scope) {
        Navigator.of(context).pushNamed('/chat/$sessionID');
      }
    } catch (_) {
      if (mounted && scope == _scope) {
        _mappingError(_l10n.pluginMappingUnavailable);
      }
    } finally {
      if (mounted) {
        setState(() {
          _editingMapping = false;
          _mappingLoading = false;
        });
      }
    }
  }

  /// One plugin as a kit row (§6): its state as the leading mark, a plain
  /// name, and one line that says where it stands. Its personal command
  /// links, "Link commands" (when the server has commands to link) and
  /// Details are in the row's menu; tapping the row opens Details, where the
  /// raw id is.
  Widget _row(PluginInfo plugin, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final id = plugin.id;
    final links = id == null ? const <String>[] : _mappings[id] ?? const [];
    final failed = plugin.status == PluginStatus.failed;
    final canLink =
        id != null &&
        PluginCommandMappings.validName(id) &&
        (links.isNotEmpty || _hasCommands != false);
    return KitRow(
      key: ValueKey('plugin-row-${id ?? plugins.indexOf(plugin)}'),
      leading: KitStatusMark(
        state: switch (plugin.status) {
          PluginStatus.active => KitMarkState.done,
          PluginStatus.failed => KitMarkState.failed,
          PluginStatus.unknown => KitMarkState.waiting,
        },
      ),
      title: pluginDisplayName(plugin, l10n),
      titleKey: ValueKey('plugin-title-${id ?? ''}'),
      supporting: TextSpan(
        text: _statusWord(plugin, l10n),
        style: failed ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      onTap: () => unawaited(_details(plugin)),
      trailing: KitRowMenu(
        key: ValueKey('plugin-menu-${id ?? ''}'),
        tooltip: l10n.pluginsRowMore,
        items: [
          for (final name in links)
            KitMenuItem(
              label: l10n.pluginMappingReview(name),
              enabled:
                  _connected &&
                  !_editingMapping &&
                  plugin.status == PluginStatus.active,
              onSelected: () => unawaited(_reviewCommand(plugin, name)),
            ),
          if (canLink)
            KitMenuItem(
              key: ValueKey('plugin-link-$id'),
              label: l10n.pluginMappingManage,
              enabled: _connected && !_editingMapping,
              onSelected: () => unawaited(_editMapping(plugin)),
            ),
          KitMenuItem(
            key: ValueKey('plugin-details-${id ?? ''}'),
            label: l10n.phoneServerRowDetails,
            onSelected: () => unawaited(_details(plugin)),
          ),
        ],
      ),
    );
  }

  List<PluginInfo> get plugins => _plugins ?? const [];

  String _statusWord(PluginInfo plugin, AppLocalizations l10n) =>
      switch (plugin.status) {
        PluginStatus.active => l10n.pluginsStatusActive,
        PluginStatus.failed => l10n.pluginsStatusFailedToLoad,
        PluginStatus.unknown => l10n.pluginsStatusUnknown,
      };

  /// What a person may want to know about one plugin and rarely does: where
  /// it comes from, its personal links, and the id the server knows it by,
  /// in mono.
  Future<void> _details(PluginInfo plugin) {
    final l10n = _l10n;
    final source = switch (plugin.source) {
      PluginSourceKind.builtin => l10n.pluginsSourceBuiltin,
      PluginSourceKind.package => l10n.pluginsSourcePackage,
      PluginSourceKind.local => l10n.pluginsSourceLocal,
      PluginSourceKind.sdk => l10n.pluginsSourceSdk,
      PluginSourceKind.unknown => l10n.pluginsSourceUnknown,
    };
    final id = plugin.id;
    final links = id == null ? const <String>[] : _mappings[id] ?? const [];
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final muted = theme.textTheme.bodyMedium?.copyWith(
          color: AppTheme.mutedOf(theme),
        );
        return SingleChildScrollView(
          key: const ValueKey('plugin-details-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pluginDisplayName(plugin, l10n),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _statusWord(plugin, l10n),
                style: plugin.status == PluginStatus.failed
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      )
                    : muted,
              ),
              const SizedBox(height: 16),
              Text(
                plugin.packageName == null
                    ? source
                    : '$source · ${plugin.packageName}',
              ),
              if (plugin.terminalUi) Text(l10n.pluginsTerminalUi),
              if (plugin.status == PluginStatus.failed) ...[
                const SizedBox(height: 8),
                Text(l10n.pluginsFailureDetail, style: muted),
              ],
              if (links.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.pluginMappingPersonal, style: muted),
                for (final name in links)
                  Text(
                    '/$name',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: AppTheme.monoFamily),
                  ),
              ],
              const SizedBox(height: 16),
              SectionLabel.inline(l10n.pluginsDetailsId),
              SelectableText(
                id ?? l10n.pluginsUnnamed,
                key: const ValueKey('plugin-details-id'),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppTheme.monoFamily,
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A plugin's name for people (docs/design/phone-server-screens-cleanup-
/// 2026-09-24.md §3). The server reports only an id, so the name is a
/// readable form of the id's last part: the namespace (`opencode.`) and
/// category words (`tool`, `config`) go, the rest is in sentence case with
/// the known acronyms in capitals. `opencode.tool.input.repair` is "Input
/// repair", `opencode.config.mcp` is "MCP", `@example/opencode-wakatime` is
/// "Wakatime". The raw id stays under the plugin's Details.
String pluginDisplayName(PluginInfo plugin, AppLocalizations l10n) {
  final id = plugin.id;
  if (id == null) return l10n.pluginsUnnamed;
  return readablePluginName(id);
}

/// [pluginDisplayName] for a known id.
String readablePluginName(String id) {
  var name = id.trim();
  if (name.startsWith('@')) {
    final slash = name.indexOf('/');
    if (slash > 0) name = name.substring(slash + 1);
  }
  final version = name.indexOf('@');
  if (version > 0) name = name.substring(0, version);
  if (name.contains('/')) name = name.split('/').last;
  var parts = name.split('.').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1) parts = parts.sublist(1);
  const categories = {
    'tool',
    'tools',
    'config',
    'plugin',
    'plugins',
    'provider',
    'providers',
    'builtin',
    'core',
  };
  while (parts.length > 1 && categories.contains(parts.first.toLowerCase())) {
    parts.removeAt(0);
  }
  final words = [
    for (final part in parts)
      ...part
          .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'),
            (match) => '${match[1]} ${match[2]}',
          )
          .split(RegExp(r'[-_\s]+'))
          .where((word) => word.isNotEmpty),
  ];
  while (words.length > 1 &&
      const {'opencode', 'plugin'}.contains(words.first.toLowerCase())) {
    words.removeAt(0);
  }
  if (words.isEmpty) return id;
  const acronyms = {
    'ai',
    'api',
    'cli',
    'git',
    'http',
    'https',
    'id',
    'json',
    'llm',
    'lsp',
    'mcp',
    'pr',
    'sdk',
    'ssh',
    'tui',
    'ui',
    'url',
  };
  final shown = <String>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i].toLowerCase();
    if (acronyms.contains(word)) {
      shown.add(word.toUpperCase());
    } else if (i == 0) {
      shown.add(word[0].toUpperCase() + word.substring(1));
    } else {
      shown.add(word);
    }
  }
  return shown.join(' ');
}
