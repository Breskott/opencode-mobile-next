import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import 'package:flutter/services.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../state/connection.dart';
import '../widgets/pickers.dart';
import '../widgets/product_states.dart';
import '../app_theme.dart';

class ToolsScreen extends StatefulWidget {
  final ConnectionController controller;
  final ModelRef? initialModel;

  /// Embedded mode renders the body only, for the Commands & tools tabs.
  final bool embedded;

  const ToolsScreen({
    super.key,
    required this.controller,
    this.initialModel,
    this.embedded = false,
  });

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final _search = TextEditingController();
  ModelRef? _model;
  List<CodingToolInfo>? _tools;
  List<String>? _registeredIDs;
  ExperimentalServerCapabilities? _capabilities;
  Object? _toolsError;
  Object? _registeredError;
  Object? _capabilitiesError;
  String _query = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _model = widget.initialModel ?? widget.controller.selectedModel;
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final model = _model;
    // Keep stale rows during refresh; the skeleton is for first load only.
    setState(() {
      _toolsError = null;
      _registeredError = null;
      _capabilitiesError = null;
    });
    if (model == null) return;

    final repository = await widget.controller.prepareActionRepository();
    if (!mounted || generation != _generation) return;
    if (repository == null) {
      setState(() {
        _toolsError = ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryOpenCodeIsReconnectingTryAgain,
        );
      });
      return;
    }

    final toolsFuture = _capture(
      repository.listCodingTools(
        providerID: model.providerID,
        modelID: model.modelID,
      ),
    );
    final registeredFuture = _capture(repository.listCodingToolIDs());
    final capabilitiesFuture = _capture(
      repository.loadExperimentalCapabilities(),
    );
    final toolsResult = await toolsFuture;
    final registeredResult = await registeredFuture;
    final capabilitiesResult = await capabilitiesFuture;
    if (!mounted || generation != _generation || _model != model) return;

    setState(() {
      _tools = toolsResult.value;
      _toolsError = toolsResult.error;
      _registeredIDs = registeredResult.value;
      _registeredError = registeredResult.error;
      _capabilities = capabilitiesResult.value;
      _capabilitiesError = capabilitiesResult.error;
    });
  }

  Future<void> _chooseModel() async {
    await showModelPicker(context);
    if (!mounted) return;
    final selected = widget.controller.selectedModel;
    if (selected == null || selected == _model) return;
    // A different model's inventory would be misleading while the new one
    // loads, so clear the data (unlike a same-model refresh, which keeps it).
    setState(() {
      _model = selected;
      _tools = null;
      _registeredIDs = null;
      _capabilities = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _model == null ? _noModel() : _body();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryToolsAndCapabilities,
        ),
        actions: [
          IconButton(
            tooltip: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryRefreshTools,
            onPressed: _model == null ? null : _load,
            icon: const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _noModel() => ProductEmptyState(
    icon: AppIconography.tools,
    title: lookupAppLocalizations(
      Localizations.localeOf(context),
    ).modelChooseTitle,
    message: lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryOpenCodeToolsDependOnTheProviderAnd,
    actionLabel: lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7LibraryChooseModel,
    onAction: _chooseModel,
  );

  Widget _body() {
    final model = _model!;
    final tools = _tools;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _modelHeader(model),
        const Divider(height: 1),
        _capabilitySummary(),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          child: TextField(
            key: const Key('tools-search'),
            controller: _search,
            decoration: InputDecoration(
              hintText: tools == null
                  ? lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibrarySearchTools
                  : lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibrarySearchTools2((tools.length).toString()),
              prefixIcon: const Icon(AppIconography.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).commonClearSearch,
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(AppIconography.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(child: _toolList()),
      ],
    );
  }

  Widget _modelHeader(ModelRef model) => InkWell(
    key: const Key('tools-model-summary'),
    onTap: _chooseModel,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final l10n = lookupAppLocalizations(Localizations.localeOf(context));
          final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
          final summary = Row(
            children: [
              const Icon(AppIconography.model),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modelName(model),
                      maxLines: stacked ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${model.providerID}/${model.modelID}',
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppTheme.monoFamily),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.embedded)
                IconButton(
                  tooltip: l10n.e7LibraryRefreshTools,
                  onPressed: _load,
                  icon: const Icon(AppIconography.retry),
                ),
              TextButton(
                onPressed: _chooseModel,
                child: Text(l10n.e7LibraryChange),
              ),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    ),
  );

  Widget _capabilitySummary() {
    final theme = Theme.of(context);
    final tools = _tools;
    final registered = _registeredIDs;
    final capabilities = _capabilities;
    final values = <String>[
      if (tools != null)
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryUsable((tools.length).toString()),
      if (registered != null)
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryRegistered((registered.length).toString()),
      if (capabilities != null)
        capabilities.backgroundSubagents
            ? lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryBackgroundSubagentsEnabled
            : lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryBackgroundSubagentsUnavailable,
    ];
    final errors = [
      if (_registeredError != null)
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryRegisteredInventoryUnavailable,
      if (_capabilitiesError != null)
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7LibraryServerCapabilityUnavailable,
    ];
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [...values, ...errors].join(', '),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final value in values)
              Text(value, style: theme.textTheme.labelMedium),
            for (final error in errors)
              Text(
                error,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolList() {
    if (_tools == null && _toolsError == null) {
      return const LoadingList(rows: 7);
    }
    if (_toolsError != null && _tools == null) {
      return ProductErrorState(
        message: productErrorText(_toolsError!),
        onRetry: _load,
      );
    }
    final query = _query.trim().toLowerCase();
    final callable = _tools!.where((tool) {
      return query.isEmpty ||
          tool.id.toLowerCase().contains(query) ||
          tool.description.toLowerCase().contains(query);
    }).toList();
    final callableIDs = {for (final tool in _tools!) tool.id};
    final registeredOnly = [
      for (final id in _registeredIDs ?? const <String>[])
        if (!callableIDs.contains(id) &&
            (query.isEmpty || id.toLowerCase().contains(query)))
          id,
    ];
    if (callable.isEmpty && registeredOnly.isEmpty) {
      return ProductEmptyState(
        icon: _query.isEmpty ? AppIconography.tools : Icons.search_off_rounded,
        title: _query.isEmpty
            ? lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryNoToolsForThisModel
            : lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryNoMatchingTools,
        message: _query.isEmpty
            ? lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryOpenCodeReturnedNoCallableToolsForThis
            : lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryTryAToolIDOrAWord,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('coding-tools-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (callable.isNotEmpty) ...[
            SectionLabel(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryCallableByThisModel,
            ),
            for (var index = 0; index < callable.length; index++) ...[
              _callableToolRow(callable[index]),
              if (index < callable.length - 1)
                const Divider(height: 1, indent: 16),
            ],
          ],
          if (registeredOnly.isNotEmpty) ...[
            SectionLabel(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryRegisteredNotCallable,
            ),
            for (var index = 0; index < registeredOnly.length; index++) ...[
              _registeredToolRow(registeredOnly[index]),
              if (index < registeredOnly.length - 1)
                const Divider(height: 1, indent: 16),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _callableToolRow(CodingToolInfo tool) => InkWell(
    key: Key('coding-tool-${tool.id}'),
    onTap: () => _showTool(tool),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.id,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: AppTheme.monoFamily),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.description.isEmpty
                      ? lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7LibraryNoDescriptionReturnedByOpenCode
                      : tool.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(AppIconography.chevronRight),
        ],
      ),
    ),
  );

  Widget _registeredToolRow(String id) => Padding(
    key: Key('registered-tool-$id'),
    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(id, style: const TextStyle(fontFamily: AppTheme.monoFamily)),
        const SizedBox(height: 4),
        Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryRegisteredOnThisProjectButNotReturned(
            (_model!.providerID).toString(),
            (_model!.modelID).toString(),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  void _showTool(CodingToolInfo tool) {
    final schema = _prettyJson(tool.parameters);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tool.id,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: AppTheme.monoFamily,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7LibraryCopyParameterSchema,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: schema));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7LibrarySchemaCopied((tool.id).toString()),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(AppIcons.copy),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('tool-detail-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tool.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          0,
                          20,
                          16,
                        ),
                        child: SelectableText(tool.description),
                      ),
                    const Divider(height: 1),
                    SectionLabel(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryParameterSchema,
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        4,
                        20,
                        24,
                      ),
                      child: SelectableText(
                        schema,
                        textDirection: TextDirection.ltr,
                        key: const Key('tool-parameter-schema'),
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFamily,
                          fontSize: AppTheme.codeFontSize,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modelName(ModelRef model) {
    final catalog = widget.controller.catalog;
    for (final candidate in catalog?.models ?? const <CatalogModel>[]) {
      if (candidate.providerID == model.providerID &&
          candidate.id == model.modelID) {
        return candidate.name;
      }
    }
    return model.modelID;
  }
}

class _Captured<T> {
  final T? value;
  final Object? error;

  const _Captured.value(this.value) : error = null;
  const _Captured.error(this.error) : value = null;
}

Future<_Captured<T>> _capture<T>(Future<T> future) async {
  try {
    return _Captured.value(await future);
  } catch (error) {
    return _Captured.error(error);
  }
}

String _prettyJson(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value?.toString() ?? 'null';
  }
}
