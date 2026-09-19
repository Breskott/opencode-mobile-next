import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../api/product_repository.dart';
import '../../state/connection.dart';
import '../permission_presentation.dart';
import '../widgets/product_states.dart';
import '../app_theme.dart';

typedef SavedPermissionRepositoryResolver =
    Future<ServerOperationsGateway?> Function();

class SavedPermissionsScreen extends StatefulWidget {
  const SavedPermissionsScreen({
    super.key,
    required this.controller,
    this.repositoryResolver,
  });

  final ConnectionController controller;
  final SavedPermissionRepositoryResolver? repositoryResolver;

  @override
  State<SavedPermissionsScreen> createState() => _SavedPermissionsScreenState();
}

class _SavedPermissionsScreenState extends State<SavedPermissionsScreen> {
  List<SavedPermission>? _permissions;
  final Set<String> _removing = {};
  bool _loading = false;
  String? _error;
  int _generation = 0;
  Object? _scope;

  Object get _currentScope {
    final profile = widget.controller.profile;
    return (
      widget.controller,
      profile?.id,
      profile?.baseUrl,
      profile?.username,
      widget.controller.directory,
      widget.controller.workspace,
      widget.controller.locationRevision,
      widget.controller.connectionRevision,
      widget.controller.repository,
    );
  }

  @override
  void initState() {
    super.initState();
    _scope = _currentScope;
    widget.controller.addListener(_scopeChanged);
    widget.controller.profileDataChanges.addListener(_scopeChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scopeChanged);
    widget.controller.profileDataChanges.removeListener(_scopeChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SavedPermissionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_scopeChanged);
    oldWidget.controller.profileDataChanges.removeListener(_scopeChanged);
    widget.controller.addListener(_scopeChanged);
    widget.controller.profileDataChanges.addListener(_scopeChanged);
    _generation++;
    _scope = _currentScope;
    setState(() {
      _permissions = null;
      _loading = false;
      _error = null;
      _removing.clear();
    });
    unawaited(_load());
  }

  void _scopeChanged() {
    if (!mounted) return;
    final scope = _currentScope;
    if (scope == _scope) return;
    _scope = scope;
    _generation++;
    setState(() {
      _permissions = null;
      _loading = false;
      _error = null;
      _removing.clear();
    });
    unawaited(_load());
  }

  Future<ServerOperationsGateway?> _resolveRepository() =>
      widget.repositoryResolver?.call() ??
      widget.controller.prepareActionRepository();

  Future<void> _load() async {
    if (_loading || _removing.isNotEmpty) return;
    if (!mounted) return;
    final generation = ++_generation;
    final scope = _scope;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = await _resolveRepository();
      if (!mounted) return;
      if (repository == null) {
        throw ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryOpenCodeIsReconnectingTryAgain,
        );
      }
      if (!mounted || generation != _generation || scope != _currentScope) {
        return;
      }
      final permissions = List<SavedPermission>.of(
        await repository.listSavedPermissions(),
      );
      if (!mounted || generation != _generation || scope != _currentScope) {
        return;
      }
      permissions.sort((a, b) {
        final action = a.action.compareTo(b.action);
        return action == 0 ? a.resource.compareTo(b.resource) : action;
      });
      setState(() => _permissions = permissions);
    } catch (error) {
      if (mounted && generation == _generation && scope == _currentScope) {
        setState(() => _error = productErrorText(error));
      }
    } finally {
      if (mounted && generation == _generation && scope == _currentScope) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _revoke(SavedPermission permission) async {
    final actionL10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (_removing.contains(permission.id)) return;
    final scope = _scope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(AppIconography.privacyWarning),
        title: Text(actionL10n.e7LibraryRevokeAlwaysAllowedAction),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(actionL10n.e7LibraryOpenCodeWillAskAgainBeforeAFuture),
            const SizedBox(height: 16),
            Text(
              actionL10n.e7LibraryAction,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(permissionRequestTitle(permission.action)),
            const SizedBox(height: 12),
            Text(
              actionL10n.e7LibraryResource,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            SelectableText(
              permission.resource.trim().isEmpty
                  ? actionL10n.e7LibraryAllMatchingResources
                  : permission.resource,
              textDirection: permission.resource.trim().isEmpty
                  ? null
                  : TextDirection.ltr,
              style: const TextStyle(fontFamily: AppTheme.monoFamily),
            ),
            const SizedBox(height: 12),
            Text(actionL10n.e7LibraryThisDoesNotStopAnActionThat),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(actionL10n.e7LibraryKeepAccess),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionL10n.e7LibraryRevokeAccess),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || scope != _currentScope) return;

    setState(() {
      _removing.add(permission.id);
      _error = null;
    });
    try {
      final repository = await _resolveRepository();
      if (!mounted) return;
      if (repository == null) {
        throw ProductException(
          actionL10n.e7LibraryOpenCodeIsReconnectingTryAgain,
        );
      }
      if (!mounted || scope != _currentScope) return;
      await repository.removeSavedPermission(permission.id);
      if (!mounted || scope != _currentScope) return;
      setState(() {
        _permissions = (_permissions ?? const [])
            .where((item) => item.id != permission.id)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionL10n.e7LibraryAlwaysAllowedActionRevoked)),
      );
    } catch (error) {
      if (!mounted || scope != _currentScope) return;
      setState(() => _error = productErrorText(error));
      showProductError(context, error);
    } finally {
      if (mounted && scope == _currentScope) {
        setState(() => _removing.remove(permission.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryAlwaysAllowedActions,
        ),
        actions: [
          IconButton(
            tooltip: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryRefreshAlwaysAllowedActions,
            onPressed: _loading || _removing.isNotEmpty ? null : _load,
            icon: _loading
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
        child: permissions == null && _error == null
            ? const LoadingList(rows: 4)
            : permissions?.isEmpty == true && _error == null
            ? ProductEmptyState(
                icon: AppIconography.privacy,
                title: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7LibraryNoAlwaysAllowedActions,
                message: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).emptyTeachAllowedMessage,
              )
            : permissions?.isEmpty != false && _error != null
            ? ProductErrorState(message: _error!, onRetry: _load)
            : ListView(
                key: const ValueKey('saved-permissions-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  SectionLabel(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).usageCurrentProject,
                    trailing: Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7LibraryGrantCount(permissions!.length),
                    ),
                  ),
                  if (_error != null)
                    ListTile(
                      leading: Icon(
                        AppIconography.error,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7LibraryTheLastActionFailed,
                      ),
                      subtitle: Text(_error!),
                    ),
                  for (final permission in permissions)
                    ListTile(
                      key: ValueKey('saved-permission-${permission.id}'),
                      leading: const Icon(AppIconography.privacy),
                      title: Text(permissionRequestTitle(permission.action)),
                      subtitle: SelectableText(
                        permission.resource.trim().isEmpty
                            ? lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7LibraryAllMatchingResources
                            : permission.resource,
                        maxLines: 3,
                        textDirection: permission.resource.trim().isEmpty
                            ? null
                            : TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFamily,
                          fontSize: AppTheme.codeFontSize,
                        ),
                      ),
                      trailing: _removing.contains(permission.id)
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              key: ValueKey(
                                'revoke-saved-permission-${permission.id}',
                              ),
                              tooltip:
                                  lookupAppLocalizations(
                                    Localizations.localeOf(context),
                                  ).e7LibraryRevokeAccess2(
                                    (permission.action).toString(),
                                  ),
                              onPressed: () => _revoke(permission),
                              icon: const Icon(AppIconography.delete),
                            ),
                    ),
                ],
              ),
      ),
    );
  }
}
