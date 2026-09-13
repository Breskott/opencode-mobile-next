import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../api/product_repository.dart';
import '../widgets/product_states.dart';
import '../app_iconography.dart';

class ProjectHealthScreen extends StatefulWidget {
  final ServerOperationsGateway repository;
  final Future<ServerOperationsGateway?> Function()? repositoryResolver;

  /// What the connected server can actually report. Defaults to the v1
  /// superset so the screen keeps its full shape unless a caller narrows it
  /// (`docs/opencode2-ui-design.md` §7, rows 17–19).
  final ServerCapabilities capabilities;

  const ProjectHealthScreen({
    super.key,
    required this.repository,
    this.repositoryResolver,
    this.capabilities = ServerCapabilities.allV1,
  });

  @override
  State<ProjectHealthScreen> createState() => _ProjectHealthScreenState();
}

class _ProjectHealthScreenState extends State<ProjectHealthScreen> {
  VersionControlHealth? _versionControl;
  List<LanguageServiceHealth>? _languageServices;
  List<FormatterHealth>? _formatters;
  String? _versionControlError;
  String? _languageServicesError;
  String? _formattersError;
  String? _gitInitializationError;
  bool _refreshing = false;
  bool _initializingGit = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _refreshing = true;
      _versionControlError = null;
      _languageServicesError = null;
      _formattersError = null;
      _gitInitializationError = null;
    });
    final repository = await _resolveRepository();
    if (!mounted || generation != _generation) return;
    if (repository == null) {
      final message = lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryOpenCodeIsReconnectingTryAgainShortly;
      setState(() {
        _versionControlError = message;
        _languageServicesError = message;
        _formattersError = message;
        _refreshing = false;
      });
      return;
    }
    await Future.wait([
      _loadVersionControl(repository, generation),
      // Hidden sections are not fetched: a gated section must not spend a
      // request only to throw an "unavailable" error into a dropped state.
      if (widget.capabilities.languageServiceStatus)
        _loadLanguageServices(repository, generation),
      if (widget.capabilities.formatterStatus)
        _loadFormatters(repository, generation),
    ]);
    if (mounted && generation == _generation) {
      setState(() => _refreshing = false);
    }
  }

  Future<ServerOperationsGateway?> _resolveRepository() async =>
      widget.repositoryResolver?.call() ?? widget.repository;

  Future<void> _initializeGit() async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (_initializingGit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionL10n.e7LibraryInitializeGitRepository),
        content: Text(actionL10n.e7LibraryOpenCodeWillRunGitInitInThe),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(actionL10n.projectFolderCancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-git-initialization'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionL10n.e7LibraryInitializeGit),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _initializingGit = true;
      _gitInitializationError = null;
    });
    try {
      final repository = await _resolveRepository();
      if (repository == null) {
        throw ProductException(
          actionL10n.e7LibraryOpenCodeIsReconnectingTryAgain,
        );
      }
      await repository.initializeGitRepository();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionL10n.e7LibraryGitRepositoryInitialized)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _gitInitializationError = productErrorText(error));
      }
    } finally {
      if (mounted) setState(() => _initializingGit = false);
    }
  }

  Future<void> _loadVersionControl(
    ServerOperationsGateway repository,
    int generation,
  ) async {
    try {
      final value = await repository.loadVersionControlHealth();
      if (mounted && generation == _generation) {
        setState(() => _versionControl = value);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _versionControlError = productErrorText(error));
      }
    }
  }

  Future<void> _loadLanguageServices(
    ServerOperationsGateway repository,
    int generation,
  ) async {
    try {
      final value = await repository.listLanguageServices();
      if (mounted && generation == _generation) {
        setState(() => _languageServices = value);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _languageServicesError = productErrorText(error));
      }
    }
  }

  Future<void> _loadFormatters(
    ServerOperationsGateway repository,
    int generation,
  ) async {
    try {
      final value = await repository.listFormatters();
      if (mounted && generation == _generation) {
        setState(() => _formatters = value);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _formattersError = productErrorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryProjectHealth,
        ),
        actions: [
          IconButton(
            tooltip: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryRefreshProjectHealth,
            onPressed: _refreshing || _initializingGit ? null : _load,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey('project-health-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionLabel(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryVersionControl,
              trailing: _versionControl == null
                  ? null
                  : Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryChanged(
                        (_versionControl!.changes.length).toString(),
                      ),
                    ),
            ),
            ..._versionControlRows(),
            if (widget.capabilities.languageServiceStatus) ...[
              SectionLabel(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryLanguageServices,
                trailing: _languageServices == null
                    ? null
                    : Text(
                        '${_languageServices!.where((item) => item.connected).length}/${_languageServices!.length}',
                      ),
              ),
              ..._languageServiceRows(),
            ],
            if (widget.capabilities.formatterStatus) ...[
              SectionLabel(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryFormatters,
                trailing: _formatters == null
                    ? null
                    : Text(
                        '${_formatters!.where((item) => item.enabled).length}/${_formatters!.length}',
                      ),
              ),
              ..._formatterRows(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _versionControlRows() {
    if (_versionControlError != null) {
      return [
        _HealthErrorTile(
          message: _versionControlError!,
          onRetry: _refreshing ? null : _load,
        ),
      ];
    }
    final vcs = _versionControl;
    if (vcs == null) {
      return [
        _HealthLoadingTile(
          label: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryVersionControl2,
        ),
      ];
    }
    if (vcs.setupState == VersionControlSetupState.absent) {
      return [
        ListTile(
          key: ValueKey('git-not-initialized'),
          leading: Icon(AppIconography.branch),
          title: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryGitIsNotInitialized,
          ),
          subtitle: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryInitializeThisProjectToEnableBranchesWorking,
          ),
        ),
        // §7 row 19: health screens explain rather than vanish, so the action
        // stays visible and says where to run it instead.
        if (!widget.capabilities.gitInit)
          GatedRowTile(
            feature: 'git-init',
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryInitializeGit,
            explainer: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryRunGitInitFromATerminal,
            leading: Icon(AppIconography.terminal),
          )
        else
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: FilledButton(
              key: const ValueKey('initialize-git-repository'),
              onPressed: _initializingGit ? null : _initializeGit,
              child: _initializingGit
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryInitializeGit,
                    ),
            ),
          ),
        if (_gitInitializationError != null)
          ListTile(
            leading: const Icon(AppIconography.error),
            title: Text(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryGitInitializationFailed,
            ),
            subtitle: Text(
              _gitInitializationError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: _initializingGit ? null : _initializeGit,
              child: Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).isolatedTaskRetryOpen,
              ),
            ),
          ),
      ];
    }
    final branch = vcs.branch?.trim();
    final defaultBranch = vcs.defaultBranch?.trim();
    return [
      ListTile(
        leading: const Icon(AppIconography.branch),
        title: Text(
          branch?.isNotEmpty == true
              ? branch!
              : lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryNoActiveBranch,
          textDirection: branch?.isNotEmpty == true ? TextDirection.ltr : null,
        ),
        subtitle: Text(
          defaultBranch?.isNotEmpty == true
              ? lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryDefaultBranch((defaultBranch).toString())
              : vcs.changes.isEmpty
              ? lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryWorkingTreeIsClean
              : lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryChangedFiles((vcs.changes.length).toString()),
        ),
        trailing: vcs.changes.isEmpty
            ? const Icon(AppIconography.checkCircle)
            : _ChangeCounts(additions: vcs.additions, deletions: vcs.deletions),
      ),
      if (vcs.changes.isEmpty)
        ListTile(
          leading: Icon(AppIconography.checks),
          title: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryNoUncommittedChanges,
          ),
        )
      else
        for (final file in vcs.changes) _VersionControlFileTile(file: file),
    ];
  }

  List<Widget> _languageServiceRows() {
    if (_languageServicesError != null) {
      return [
        _HealthErrorTile(
          message: _languageServicesError!,
          onRetry: _refreshing ? null : _load,
        ),
      ];
    }
    final services = _languageServices;
    if (services == null) {
      return [
        _HealthLoadingTile(
          label: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryLanguageServices2,
        ),
      ];
    }
    if (services.isEmpty) {
      return [
        ListTile(
          leading: Icon(Icons.code_off_rounded),
          title: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryNoActiveLanguageServices,
          ),
          subtitle: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryOpenCodeActivatesThemWhileItInspectsSupported,
          ),
        ),
      ];
    }
    return [
      for (final service in services)
        ListTile(
          leading: Icon(
            service.connected
                ? AppIconography.checkCircle
                : AppIconography.error,
          ),
          title: Text(service.name, textDirection: TextDirection.ltr),
          subtitle: Text(
            service.root.isEmpty
                ? service.status
                : '${service.status} · ${service.root}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  List<Widget> _formatterRows() {
    if (_formattersError != null) {
      return [
        _HealthErrorTile(
          message: _formattersError!,
          onRetry: _refreshing ? null : _load,
        ),
      ];
    }
    final formatters = _formatters;
    if (formatters == null) {
      return const [_HealthLoadingTile(label: 'formatters')];
    }
    if (formatters.isEmpty) {
      return [
        ListTile(
          leading: Icon(AppIconography.alignLeft),
          title: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryNoFormattersConfigured,
          ),
        ),
      ];
    }
    return [
      for (final formatter in formatters)
        ListTile(
          leading: Icon(
            formatter.enabled
                ? AppIconography.checkCircle
                : AppIconography.removeCircle,
          ),
          title: Text(formatter.name, textDirection: TextDirection.ltr),
          subtitle: Text(
            formatter.extensions.isEmpty
                ? formatter.enabled
                      ? lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7LibraryEnabled
                      : lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7LibraryDisabled
                : '${formatter.enabled ? lookupAppLocalizations(Localizations.localeOf(context)).e7LibraryEnabled : lookupAppLocalizations(Localizations.localeOf(context)).e7LibraryDisabled} · ${formatter.extensions.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

class _VersionControlFileTile extends StatelessWidget {
  final VersionControlFile file;

  const _VersionControlFileTile({required this.file});

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 54,
    leading: Icon(_statusIcon(file.status), size: 20),
    title: Text(
      file.path,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(file.status),
    trailing: _ChangeCounts(
      additions: file.additions,
      deletions: file.deletions,
    ),
  );

  static IconData _statusIcon(String status) => switch (status) {
    'added' => AppIconography.addCircle,
    'deleted' => AppIconography.removeCircle,
    _ => AppIconography.edit,
  };
}

class _ChangeCounts extends StatelessWidget {
  final int additions;
  final int deletions;

  const _ChangeCounts({required this.additions, required this.deletions});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '+$additions',
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 8),
      Text(
        '-$deletions',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  );
}

class _HealthLoadingTile extends StatelessWidget {
  final String label;

  const _HealthLoadingTile({required this.label});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    title: Text(
      lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7LibraryLoading((label).toString()),
    ),
  );
}

class _HealthErrorTile extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _HealthErrorTile({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(AppIconography.error),
    title: Text(
      lookupAppLocalizations(Localizations.localeOf(context)).workUnknown,
    ),
    subtitle: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
    trailing: TextButton(
      onPressed: onRetry,
      child: Text(
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).isolatedTaskRetryOpen,
      ),
    ),
  );
}
