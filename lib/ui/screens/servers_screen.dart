import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/product_repository.dart' show ProductException;
import '../../api/server_probe.dart';
import '../../demo/demo_copy.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/setup_ui_messages.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/codex_connection_probe.dart';
import '../../state/paseo_connection_probe.dart';
import '../../state/pairing.dart';
import '../../state/profiles.dart';
import '../../state/external_agents.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/managed_server_health.dart';
import '../widgets/product_states.dart';
import '../widgets/team_host_form.dart';
import '../widgets/termux_running_server_entry.dart';
import '../widgets/safety_confirms.dart';
import '../../state/local_server_controls.dart';
import 'demo_screen.dart';
import 'attention_overview_screen.dart';
import 'agent_account_screen.dart';
import 'pairing_scanner_screen.dart';
import 'tailscale_setup_screen.dart';
import '../../state/tailscale_address.dart';
import 'external_agents_screen.dart';

/// What the servers list learns back from the editor's save: whether the
/// profile reached the store, and the product-facing failure to show inline
/// when connecting (or saving) did not work out.
typedef _SubmitOutcome = ({bool saved, String? failure});

AppLocalizations _connectionL10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Manage opencode server profiles and connect.
class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  bool _busy = false;
  bool _handledRouteArgument = false;

  /// A connect attempt from the list that failed, rendered inline above the
  /// rows in the same verdict style the editor uses — never a red snackbar
  /// carrying a raw exception.
  String? _listFailure;

  /// Bumped after Termux setup returns so the running-server entry re-reads
  /// the phone instead of trusting what it saw before the user left.
  int _termuxRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledRouteArgument) return;
    _handledRouteArgument = true;
    // The connection banner's "Update password" action routes here with this
    // argument: open the active profile's editor with the password focused so
    // a rotated serve password is one paste away (never a modal).
    if (ModalRoute.of(context)?.settings.arguments == 'edit-active') {
      final store = ref.read(bootstrapProvider).store;
      ServerProfile? active;
      for (final p in store.profiles) {
        if (p.id == store.activeId) active = p;
      }
      final target = active;
      if (target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_edit(existing: target, focusPassword: true));
        });
      }
    }
  }

  void _showFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  Future<void> _openTermuxSetup() async {
    await Navigator.pushNamed(context, '/termux-setup');
    if (mounted) setState(() => _termuxRevision++);
  }

  /// The detected running-server entry for [profiles]: it decides on its own
  /// whether anything is shown, so both the welcome and the list embed it
  /// unconditionally and stay platform-gated through it.
  Widget _runningServerEntry(
    List<ServerProfile> profiles,
    ConnectionController connection,
  ) {
    return TermuxRunningServerEntry(
      profiles: profiles,
      busy: _busy,
      revision: _termuxRevision,
      connectedProfileID: connection.api == null
          ? null
          : connection.profile?.id,
      busyConversations: connection.busySessions.length,
      actions: () {
        final controls = LocalServerControls(
          store: ref.read(bootstrapProvider).store,
          connection: connection,
        );
        return LocalServerCardActions(
          restart: () async => controls.restart(),
          stop: controls.stop,
        );
      }(),
      onDisconnect: () async {
        if (!await confirmDisconnectServer(context, connection)) return;
        await connection.disconnect(keepActive: true);
      },
      onForget: _delete,
      onManage: _openTermuxSetup,
      onConnect: (profile) => _connect(profile, detectedRunning: true),
      onEnterCredentials: (server, existing) => _edit(
        existing: existing,
        connectOnSave: true,
        initialUrl: TermuxBridge.managedServerUrl,
        focusPassword: true,
        openCode2Intent: server.flavor == ServerFlavor.v2,
      ),
    );
  }

  /// [detectedRunning] means the caller already knows which managed runtime
  /// is live and chose its profile, so the runtime-choice detour is moot.
  Future<void> _connect(ServerProfile p, {bool detectedRunning = false}) async {
    if (_busy) return;
    if (!detectedRunning &&
        _needsManagedRuntimeChoice(
          p,
          ref.read(bootstrapProvider).store.profiles,
        )) {
      await _openTermuxSetup();
      return;
    }
    if (p.requiresPasswordReentry || p.requiresCodexTokenReentry) {
      await _edit(
        existing: p,
        focusPassword: p.backend == ServerBackend.openCode,
        connectOnSave: detectedRunning,
      );
      return;
    }
    setState(() {
      _busy = true;
      _listFailure = null;
    });
    final conn = ref.read(connProvider);
    Object? failure;
    try {
      await conn.connect(p);
    } catch (error) {
      failure = error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (conn.api != null && failure == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      final detail = productErrorText(
        conn.lastError ??
            failure ??
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupConnectionFailed,
      );
      setState(() {
        _listFailure = lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7SetupConnectFailedDetail(p.name, detail);
      });
    }
  }

  Future<void> _edit({
    ServerProfile? existing,
    bool focusPassword = false,
    bool tailscale = false,
    String? initialUrl,
    bool openCode2Intent = false,
    bool connectOnSave = false,
  }) async {
    final isNew = existing == null;
    final useTailscale =
        tailscale ||
        (existing != null &&
            ref
                    .read(bootstrapProvider)
                    .store
                    .prefs
                    .getBool('oc.tailscale.${existing.id}') ==
                true);
    // The editor stays open until the save (and, for new or active profiles,
    // the connect) has succeeded, so any failure is shown where the fields
    // that fix it are — not as a snackbar over a list the user just left.
    final result = await Navigator.of(context).push<ServerProfile>(
      MaterialPageRoute<ServerProfile>(
        builder: (_) => _ProfileEditorScreen(
          existing: existing,
          reconnectOnSave:
              connectOnSave ||
              existing?.id == ref.read(bootstrapProvider).store.activeId,
          focusPassword: focusPassword,
          tailscale: useTailscale,
          initialUrl: initialUrl,
          openCode2Intent: openCode2Intent,
          onSubmit: (profile) => _saveAndConnect(
            profile,
            isNew: isNew,
            tailscale: useTailscale,
            forceConnect: connectOnSave,
          ),
          secureStorageProbe: () =>
              ref.read(bootstrapProvider).store.secureStorageProblem(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (isNew || connectOnSave || result.backend == ServerBackend.codex) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  Future<void> _tailscale() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TailscaleSetupScreen()),
    );
    if (!mounted || url == null) return;
    await _edit(tailscale: true, initialUrl: url);
  }

  /// Saves [result] and connects profiles whose submit action promises it.
  /// A brand-new profile and every Codex profile promise "Save & connect";
  /// edits of existing non-active OpenCode profiles keep saving only.
  Future<_SubmitOutcome> _saveAndConnect(
    ServerProfile result, {
    required bool isNew,
    bool tailscale = false,
    bool forceConnect = false,
  }) async {
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    final store = ref.read(bootstrapProvider).store;
    final wasActive = store.activeId == result.id;
    var saved = false;
    setState(() {
      _busy = true;
      _listFailure = null;
    });
    try {
      await store.upsert(result);
      saved = true;
      if (tailscale &&
          !await store.prefs.setBool('oc.tailscale.${result.id}', true)) {
        throw StateError(copy.e7SetupGuidanceSaveFailed);
      }
      if (wasActive ||
          isNew ||
          forceConnect ||
          result.backend == ServerBackend.codex) {
        final savedProfile = store.profiles.firstWhere(
          (profile) => profile.id == result.id,
        );
        final conn = ref.read(connProvider);
        await conn.connect(savedProfile);
        if (conn.api == null) {
          throw ProductException(conn.lastError ?? copy.e7SetupDidNotConnect);
        }
      }
      return (saved: true, failure: null);
    } catch (error) {
      final detail = productErrorText(error);
      return (
        saved: saved,
        failure: saved
            ? copy.e7SetupSavedConnectFailed(result.name, detail)
            : copy.e7SetupSaveFailed(result.name, detail),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Names what removal actually deletes. Queued prompts and drafts are the
  /// only unsent work at stake, so they are counted rather than described in
  /// the abstract; the rest is settings the user cannot inspect anyway.
  String _deletionDisclosure(ConnectionController connection, String id) {
    final queued = connection.queuedPromptCountForProfile(id);
    final drafts = connection.draftCountForProfile(id);
    return lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7SetupDeleteDisclosure(queued, drafts);
  }

  Future<void> _delete(ServerProfile p) async {
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    final connection = ref.read(connProvider);
    final disclosure = _deletionDisclosure(connection, p.id);
    final ok = await showConfirmSheet(
      context,
      title: copy.e7SetupRemoveServer(p.name),
      message: disclosure,
      confirmLabel: copy.capsuleRemove,
      icon: AppIconography.delete,
      destructive: true,
      sheetKey: ValueKey('remove-server-sheet-${p.id}'),
      confirmKey: ValueKey('confirm-remove-server-${p.id}'),
    );
    if (!ok || !mounted) return;
    final store = ref.read(bootstrapProvider).store;
    final wasActive = store.activeId == p.id;
    var removed = false;
    setState(() => _busy = true);
    try {
      // The cascade verifies every store it writes and reports what refused.
      // A partial deletion is stated, never rounded up to the silent success
      // the list rebuild would otherwise imply.
      final result = await connection.deleteProfileAndLocalData(p.id);
      final partial = result.partialDeletionMessage;
      if (partial != null) {
        _showFailure(partial);
        if (!result.removedProfile) return;
      }
      removed = true;
      if (wasActive) {
        await connection.disconnect(keepActive: true);
      }
    } catch (error) {
      if (removed) {
        _showFailure(
          copy.e7SetupRemovedDisconnectFailed(p.name, productErrorText(error)),
        );
      } else {
        _showFailure(copy.e7SetupRemoveFailed(p.name, productErrorText(error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _externalAgents() async {
    final bootstrap = ref.read(bootstrapProvider);
    final store = ExternalAgentStore(
      bootstrap.store.prefs,
      bootstrap.store.secure,
    );
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ExternalAgentsScreen(store: store)),
      );
    } finally {
      store.dispose();
    }
  }

  void _demo() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const DemoScreen()));

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final accountConnection = ref.watch(connProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBrandMark(size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _connectionL10n(context).openCodeConnectionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (bootstrap.store.profiles.isNotEmpty)
            IconButton(
              tooltip: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).attentionTitle,
              icon: const Icon(AppIconography.activity),
              onPressed: _busy
                  ? null
                  : () async {
                      final controller = ref.read(connProvider);
                      final chosen = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (sheetContext) => AttentionOverviewScreen(
                            controller: controller,
                            onOpenProfile: (id) =>
                                Navigator.of(sheetContext).pop(id),
                          ),
                        ),
                      );
                      if (!mounted ||
                          chosen == null ||
                          !controller.isProfileReadable(chosen)) {
                        return;
                      }
                      final matches = bootstrap.store.profiles
                          .where((profile) => profile.id == chosen)
                          .toList();
                      if (matches.length != 1) return;
                      await _connect(matches.single);
                    },
            ),
          IconButton(
            tooltip: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupAboutNotices,
            icon: const Icon(AppIconography.info),
            onPressed: () => Navigator.pushNamed(context, '/about'),
          ),
          IconButton(
            tooltip: _connectionL10n(context).onboardingSetupGuide,
            icon: const Icon(AppIconography.question),
            onPressed: () => Navigator.pushNamed(context, '/guide'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final store = bootstrap.store;
          if (store.profiles.isEmpty) {
            return _WelcomeView(
              busy: _busy,
              runningServer: _runningServerEntry(
                store.profiles,
                accountConnection,
              ),
              onConnect: () => _edit(),
              onConnectOpenCode2: () => _edit(openCode2Intent: true),
              onTailscale: _tailscale,
              onTermux: _openTermuxSetup,
              onGuide: () => Navigator.pushNamed(context, '/guide'),
              onDemo: _demo,
              onExternalAgents: _externalAgents,
            );
          }
          final activeId = store.activeId;
          final needsCredential = store.profiles.any(
            (profile) =>
                profile.id == activeId &&
                (profile.usesAgentSocket
                    ? profile.requiresCodexTokenReentry
                    : profile.requiresPasswordReentry),
          );
          final needsToken = store.profiles.any(
            (profile) =>
                profile.id == activeId &&
                profile.usesAgentSocket &&
                profile.requiresCodexTokenReentry,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SectionLabel.inline(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7SetupServers,
              ),
              if (needsCredential) ...[
                Semantics(
                  container: true,
                  liveRegion: true,
                  excludeSemantics: true,
                  label: needsToken
                      ? lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7SetupTokenBanner
                      : lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7SetupPasswordBanner,
                  child: Container(
                    key: const Key('password-reentry-banner'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _connectionL10n(
                              context,
                            ).connectionCredentialUnavailable,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_listFailure case final failure?) ...[
                _InlineFailureCard(
                  key: const ValueKey('server-connect-failure'),
                  message: failure,
                  onDismiss: () => setState(() => _listFailure = null),
                ),
                const SizedBox(height: 10),
              ],
              if (_busy)
                Semantics(
                  label: lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7SetupServerOperation,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(
                      key: Key('server-operation-progress'),
                    ),
                  ),
                ),
              _runningServerEntry(store.profiles, accountConnection),
              for (final p in store.profiles)
                Card.filled(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: p.id == activeId
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .35)
                      : null,
                  child: ListTile(
                    enabled: !_busy,
                    onTap: _busy ? null : () => _connect(p),
                    isThreeLine:
                        p.requiresPasswordReentry ||
                        p.requiresCodexTokenReentry,
                    leading: CircleAvatar(
                      backgroundColor: p.id == activeId
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isLoopbackHost(Uri.tryParse(p.baseUrl)?.host ?? '')
                            ? AppIconography.phone
                            : AppIconography.server,
                        size: 18,
                        color: p.id == activeId
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.baseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.monoFamily,
                            fontSize: AppTheme.captionFontSize,
                          ),
                        ),
                        if (p.backend == ServerBackend.openCode)
                          Text(
                            _knownOpenCodeGeneration(p),
                            key: ValueKey('server-generation-${p.id}'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (p.requiresPasswordReentry)
                          Text(
                            lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7SetupPasswordRequired,
                            key: ValueKey('password-reentry-${p.id}'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (p.usesAgentSocket)
                          Text(
                            '${p.backend == ServerBackend.paseo ? 'Paseo' : 'Codex'}${p.codexDirectory.isEmpty ? '' : ' · ${p.codexDirectory}'}',
                            key: ValueKey('codex-profile-${p.id}'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (p.requiresCodexTokenReentry)
                          Text(
                            lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7SetupTokenRequired,
                            key: ValueKey('codex-token-reentry-${p.id}'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !_busy,
                      onSelected: (v) {
                        if (v == 'edit') _edit(existing: p);
                        if (v == 'del') _delete(p);
                        if (v == 'conn') _connect(p);
                        if (v == 'account') {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => AgentAccountScreen(
                                connection: accountConnection,
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        if (p.id == activeId &&
                            accountConnection.isConnected &&
                            accountConnection.capabilities.agentAccount)
                          PopupMenuItem(
                            value: 'account',
                            child: Text(
                              _connectionL10n(context).agentAccountTitle,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'conn',
                          child: Text(
                            lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7SetupConnect,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(
                            lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7SetupEdit,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'del',
                          child: Text(
                            lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).capsuleRemove,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (platformCapabilities.supportsTermux &&
                  store.profiles.any(
                    (p) => TermuxBridge.managesServerUrl(p.baseUrl),
                  ))
                ManagedServerHealth(
                  prefs: store.prefs,
                  profileID: store.profiles
                      .firstWhere(
                        (p) => TermuxBridge.managesServerUrl(p.baseUrl),
                      )
                      .id,
                  onManage: _openTermuxSetup,
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(AppIconography.add),
                label: Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7SetupAddServer,
                ),
              ),
              const SizedBox(height: 8),
              _OpenCode2Entry(
                onTap: _busy ? null : () => _edit(openCode2Intent: true),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _demo,
                icon: const Icon(AppIconography.playCircle),
                label: const Text(DemoCopy.tryDemo),
              ),
              const SizedBox(height: 16),
              if (platformCapabilities.supportsTermux)
                _TermuxEntry(
                  key: const ValueKey('quick-add-termux-card'),
                  onTap: _busy ? null : _openTermuxSetup,
                ),
              _SetupOptions(
                busy: _busy,
                onTailscale: _tailscale,
                onGuide: () => Navigator.pushNamed(context, '/guide'),
                onExternalAgents: _externalAgents,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// First run has two immediate jobs: connect an existing server or try safely.
class _WelcomeView extends StatelessWidget {
  final bool busy;

  /// The detected on-device server, above every generic choice. It renders
  /// nothing unless a running server was actually observed.
  final Widget runningServer;
  final VoidCallback onConnect;
  final VoidCallback onConnectOpenCode2;
  final VoidCallback onTailscale;
  final VoidCallback onTermux;
  final VoidCallback onGuide;
  final VoidCallback onDemo;
  final VoidCallback onExternalAgents;

  const _WelcomeView({
    required this.busy,
    required this.runningServer,
    required this.onConnect,
    required this.onConnectOpenCode2,
    required this.onTailscale,
    required this.onTermux,
    required this.onGuide,
    required this.onDemo,
    required this.onExternalAgents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    key: const ValueKey('first-run-welcome'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _connectionL10n(context).onboardingValueTitle,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _connectionL10n(context).onboardingValueBody,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      runningServer,
                      FilledButton(
                        key: const ValueKey('welcome-connect-card'),
                        onPressed: busy ? null : onConnect,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          _connectionL10n(context).onboardingConnect,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : onDemo,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text(DemoCopy.tryDemo),
                      ),
                      Text(
                        _connectionL10n(context).onboardingDemoNote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _OpenCode2Entry(onTap: busy ? null : onConnectOpenCode2),
                      if (platformCapabilities.supportsTermux)
                        _TermuxEntry(
                          key: const ValueKey('welcome-termux-card'),
                          onTap: busy ? null : onTermux,
                        ),
                      _SetupOptions(
                        busy: busy,
                        onTailscale: onTailscale,
                        onGuide: onGuide,
                        onExternalAgents: onExternalAgents,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone has one managed listener. Choosing between retained generation
/// profiles is a runtime decision, not permission to redetect/rewrite either.
bool _needsManagedRuntimeChoice(
  ServerProfile profile,
  List<ServerProfile> profiles,
) {
  if (!platformCapabilities.supportsTermux ||
      profile.backend != ServerBackend.openCode ||
      !TermuxBridge.managesServerUrl(profile.baseUrl) ||
      _knownOpenCodeFlavor(profile) == null) {
    return false;
  }
  return profiles.any(
    (other) =>
        other.id != profile.id &&
        other.backend == ServerBackend.openCode &&
        TermuxBridge.managesServerUrl(other.baseUrl) &&
        _knownOpenCodeFlavor(other) != null &&
        _knownOpenCodeFlavor(other) != _knownOpenCodeFlavor(profile),
  );
}

ServerFlavor? _knownOpenCodeFlavor(ServerProfile profile) {
  if (profile.flavor == ServerFlavor.v2) return ServerFlavor.v2;
  if (profile.flavor == ServerFlavor.v1 &&
      profile.serverVersion?.trim().isNotEmpty == true) {
    return ServerFlavor.v1;
  }
  return null;
}

/// Legacy profiles default to v1 without a probe. Only the cached version
/// proves that this default was confirmed. v2 never comes from that default.
String _knownOpenCodeGeneration(ServerProfile profile) =>
    switch (_knownOpenCodeFlavor(profile)) {
      ServerFlavor.v2 => 'OpenCode 2',
      ServerFlavor.v1 => 'OpenCode 1',
      _ => 'OpenCode',
    };

/// A discovery shortcut into the same autodetecting editor, not a flavor override.
class _OpenCode2Entry extends StatelessWidget {
  const _OpenCode2Entry({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('connect-existing-opencode2'),
    contentPadding: EdgeInsets.zero,
    leading: const Icon(AppIconography.server),
    title: Text(_connectionL10n(context).oc2DiscoveryConnect),
    subtitle: Text(_connectionL10n(context).oc2DiscoveryExisting),
    trailing: const Icon(AppIconography.chevronRight),
    onTap: onTap,
  );
}

/// A phone feature must stay discoverable when the current server is remote.
class _TermuxEntry extends StatelessWidget {
  const _TermuxEntry({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(AppIconography.phone),
    title: Text(_connectionL10n(context).onboardingTermuxSetup),
    subtitle: Text(_connectionL10n(context).oc2DiscoveryPhone),
    trailing: const Icon(AppIconography.chevronRight),
    onTap: onTap,
  );
}

/// Advanced setup remains discoverable without competing with connect or demo.
class _SetupOptions extends StatelessWidget {
  const _SetupOptions({
    required this.busy,
    required this.onTailscale,
    required this.onGuide,
    required this.onExternalAgents,
  });
  final bool busy;
  final VoidCallback onTailscale;
  final VoidCallback onGuide;
  final VoidCallback onExternalAgents;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(_connectionL10n(context).onboardingMoreSetup),
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    shape: const Border(),
    collapsedShape: const Border(),
    children: [
      if (platformCapabilities.supportsTailscaleHandoff)
        ListTile(
          key: const ValueKey('welcome-tailscale-card'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIconography.secureNetwork),
          title: Text(_connectionL10n(context).tailscaleTitle),
          subtitle: Text(_connectionL10n(context).onboardingPrivateNetwork),
          onTap: busy ? null : onTailscale,
        ),
      ListTile(
        key: const ValueKey('welcome-guide-card'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIconography.guide),
        title: Text(_connectionL10n(context).onboardingSetupGuide),
        onTap: busy ? null : onGuide,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIconography.network),
        title: Text(_connectionL10n(context).a2aTitle),
        onTap: busy ? null : onExternalAgents,
      ),
    ],
  );
}

class _ProfileEditorScreen extends StatefulWidget {
  final ServerProfile? existing;
  final bool tailscale;
  final bool reconnectOnSave;
  final bool openCode2Intent;
  final String? initialUrl;

  /// Focus the password field on open — the path taken from the connection
  /// banner after a mid-session 401 (the serve password rotated).
  final bool focusPassword;

  /// Saves (and where promised, connects) the profile. The editor pops with
  /// the profile only when this reports no failure; otherwise the failure is
  /// rendered inline and the fields stay editable.
  final Future<_SubmitOutcome> Function(ServerProfile profile) onSubmit;

  /// Resolves to a sentence when the device cannot keep a password (a Linux
  /// desktop without a keyring), shown above the form before the user types
  /// one that would be lost on save. Null skips the probe.
  final Future<String?> Function()? secureStorageProbe;
  const _ProfileEditorScreen({
    this.existing,
    this.tailscale = false,
    this.reconnectOnSave = false,
    this.openCode2Intent = false,
    this.initialUrl,
    this.focusPassword = false,
    required this.onSubmit,
    this.secureStorageProbe,
  });

  @override
  State<_ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<_ProfileEditorScreen> {
  late ServerBackend _backend =
      widget.existing?.backend ?? ServerBackend.openCode;
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  // New profiles start empty: the normalizer on Test/Save adds the scheme,
  // and a pre-seeded 'https://' fought typed bare hosts.
  late final TextEditingController _url = TextEditingController(
    text: widget.existing?.baseUrl ?? widget.initialUrl ?? '',
  );
  late final TextEditingController _user = TextEditingController(
    text: widget.existing?.username ?? '',
  );
  late final TextEditingController _pass = TextEditingController(
    text: widget.existing?.password ?? '',
  );
  late final TextEditingController _codexDirectory = TextEditingController(
    text: widget.existing?.codexDirectory ?? '',
  );
  late final TextEditingController _codexToken = TextEditingController(
    text: widget.existing?.codexToken ?? '',
  );
  final _urlFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _codexDirectoryFocus = FocusNode();
  final _codexTokenFocus = FocusNode();
  String? _error;
  bool _obscurePassword = true;
  bool _closing = false;
  bool _testing = false;

  /// True while [_ProfileEditorScreen.onSubmit] runs.
  bool _submitting = false;

  /// Why the last save or connect did not finish, in product copy.
  String? _submitFailure;

  /// The keyring problem [_ProfileEditorScreen.secureStorageProbe] found.
  String? _secureStorageNotice;

  /// The profile as last written to the store from this editor, so a save
  /// that stored but could not connect no longer counts as unsaved edits.
  ServerProfile? _savedProfile;
  ServerProbeResult? _testResult;
  CodexConnectionProbeResult? _codexTestResult;
  int _urlLength = 0;
  int _probeGeneration = 0;

  /// True while a pairing payload's addresses are being probed.
  bool _pairing = false;

  /// The AI Team host chosen in this editor (TEAM-106); the existing
  /// profile's config until "Add manually" replaces it.
  late OrchestrationConfig? _orchestration = widget.existing?.orchestration;

  /// Which address pairing settled on, as a sentence. Never contains the
  /// password.
  String? _pairingNotice;

  /// Why pairing could not finish — including the per-address verdicts, which
  /// are the only thing that tells the user whether to bridge a port or to
  /// put the server behind TLS.
  String? _pairingFailure;

  /// True for both socket-style backends (Codex app-server and the Paseo
  /// daemon): they share the address, project folder and secret fields.
  bool get _isCodex => _backend != ServerBackend.openCode;
  bool get _isPaseo => _backend == ServerBackend.paseo;

  bool get _needsPassword =>
      !_isCodex && (widget.existing?.requiresPasswordReentry ?? false);

  bool get _needsCodexToken =>
      _isCodex && (widget.existing?.requiresCodexTokenReentry ?? false);

  Future<void> _probeSecureStorage() async {
    final probe = widget.secureStorageProbe;
    if (probe == null) return;
    String? notice;
    try {
      notice = await probe();
    } catch (_) {
      notice = null;
    }
    if (!mounted || notice == null || _isCodex) return;
    setState(() => _secureStorageNotice = notice);
  }

  @override
  void initState() {
    super.initState();
    if (!_isCodex) _probeSecureStorage();
    _urlLength = _url.text.length;
  }

  /// A paste is a jump of several characters at once. When it lands without a
  /// scheme, expand it in place so `192.0.2.7:4096` just works.
  ///
  /// A pasted *pairing* payload is intercepted before anything else. It is
  /// JSON carrying the serve password, and it must not be left sitting in a
  /// text field: the field renders it, a screenshot captures it, and the
  /// platform may offer it to autofill. So the field is emptied first and the
  /// payload is routed to [_applyPairing].
  void _urlChanged(String value) {
    setState(_invalidateProbe);
    if (_isCodex) {
      final pasted = value.length - _urlLength >= 4;
      _urlLength = value.length;
      if (pasted && !value.contains('://')) {
        final normalized = _isPaseo
            ? normalizePaseoServerUrl(value)
            : normalizeCodexServerUrl(value);
        if (normalized != value.trim()) {
          _urlLength = normalized.length;
          _url.value = TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
      }
      return;
    }
    if (looksLikePairingPayload(value)) {
      final parsed = parsePairingPayload(value);
      _url.value = TextEditingValue.empty;
      _urlLength = 0;
      if (!parsed.ok) {
        setState(() {
          _pairingNotice = null;
          _pairingFailure = parsed.error;
        });
        return;
      }
      unawaited(_applyPairing(parsed.payload!));
      return;
    }
    final pasted = value.length - _urlLength >= 4;
    _urlLength = value.length;
    if (pasted && !value.contains('://')) {
      final normalized = normalizeServerProfileUrl(value);
      if (normalized != value.trim()) {
        _urlLength = normalized.length;
        _url.value = TextEditingValue(
          text: normalized,
          selection: TextSelection.collapsed(offset: normalized.length),
        );
      }
    }
  }

  void _invalidateProbe() {
    _probeGeneration += 1;
    _testing = false;
    _submitFailure = null;
    _pairing = false;
    _error = null;
    _testResult = null;
    _codexTestResult = null;
    _pairingNotice = null;
    _pairingFailure = null;
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    if (_isCodex) {
      await _testCodexConnection();
      return;
    }
    final url = normalizeServerProfileUrl(_url.text);
    if (widget.tailscale && !isValidTailscaleAddress(url)) {
      setState(() {
        _error = _connectionL10n(context).tailscaleAddressError;
        _testResult = null;
      });
      return;
    }
    if (url != _url.text.trim()) {
      _urlLength = url.length;
      _url.value = TextEditingValue(
        text: url,
        selection: TextSelection.collapsed(offset: url.length),
      );
    }
    final error = validateServerProfileUrl(
      url,
      username: _user.text,
      password: _pass.text,
    );
    if (error != null) {
      setState(() {
        _error = error;
        _testResult = null;
      });
      _urlFocus.requestFocus();
      return;
    }
    final generation = ++_probeGeneration;
    setState(() {
      _testing = true;
      _testResult = null;
      _error = null;
    });
    final result = await serverProbe(
      baseUrl: url,
      username: _user.text.trim(),
      password: _pass.text,
    );
    if (!mounted || generation != _probeGeneration) return;
    setState(() {
      _testing = false;
      _submitFailure = null;
      _testResult = result;
    });
    // Per the v2 auth taxonomy: a 401 without a password sends the user to
    // the password field; a rejected password selects it for a clean repaste.
    if (result.flavor == ServerFlavor.v2 && result.needsPassword) {
      if (_pass.text.isNotEmpty) {
        _pass.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _pass.text.length,
        );
      }
      _passFocus.requestFocus();
    }
  }

  String? _validateSocketFields(String url) => _isPaseo
      ? validatePaseoServerUrl(url) ??
            validateCodexProjectDirectory(_codexDirectory.text.trim()) ??
            validatePaseoPassword(_codexToken.text)
      : validateCodexServerUrl(url) ??
            validateCodexProjectDirectory(_codexDirectory.text.trim()) ??
            validateCodexConnectionToken(_codexToken.text);

  Future<void> _testCodexConnection() async {
    var url = _isPaseo
        ? normalizePaseoServerUrl(_url.text)
        : normalizeCodexServerUrl(_url.text);
    if (url != _url.text.trim()) {
      _urlLength = url.length;
      _url.value = TextEditingValue(
        text: url,
        selection: TextSelection.collapsed(offset: url.length),
      );
    }
    final error = _validateSocketFields(url);
    if (error != null) {
      setState(() {
        _error = error;
        _codexTestResult = null;
      });
      if ((_isPaseo
              ? validatePaseoServerUrl(url)
              : validateCodexServerUrl(url)) !=
          null) {
        _urlFocus.requestFocus();
      } else if (validateCodexProjectDirectory(_codexDirectory.text.trim()) !=
          null) {
        _codexDirectoryFocus.requestFocus();
      } else {
        _codexTokenFocus.requestFocus();
      }
      return;
    }
    final generation = ++_probeGeneration;
    setState(() {
      _testing = true;
      _codexTestResult = null;
      _error = null;
    });
    try {
      final result = _isPaseo
          ? await probePaseoConnection(
              baseUrl: url,
              password: _codexToken.text,
              directory: _codexDirectory.text.trim(),
            )
          : await probeCodexConnection(
              baseUrl: url,
              token: _codexToken.text,
              directory: _codexDirectory.text.trim(),
            );
      if (!mounted || generation != _probeGeneration) return;
      setState(() {
        _testing = false;
        _submitFailure = null;
        _codexTestResult = result;
      });
      if (!result.ok) _codexTokenFocus.requestFocus();
    } catch (error) {
      if (!mounted || generation != _probeGeneration) return;
      setState(() {
        _testing = false;
        _error = productErrorText(error);
      });
    }
  }

  /// Reads a pairing payload from the clipboard and applies it.
  ///
  /// The whole point of `opencode2 pair` is that the address, the username,
  /// and a 32-byte random password arrive together, so this fills all three
  /// rather than making the user shuttle between fields.
  Future<void> _pastePairing() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    if (!mounted) return;
    if (raw.trim().isEmpty) {
      setState(() {
        _pairingNotice = null;
        _pairingFailure = lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7SetupEmptyPairClipboard;
      });
      return;
    }
    final parsed = parsePairingPayload(raw);
    if (!parsed.ok) {
      setState(() {
        _pairingNotice = null;
        _pairingFailure = parsed.error;
      });
      return;
    }
    await _applyPairing(parsed.payload!);
  }

  /// Opens the camera scanner and applies whatever pairing code it decodes.
  ///
  /// The scanner owns every camera failure — permission, hardware, a QR that
  /// is not a pairing code — and returns null for all of them, so there is
  /// nothing to explain here beyond a payload that arrived.
  Future<void> _scanPairing() async {
    if (!platformCapabilities.supportsQrPairing) return;
    final payload = await Navigator.of(context).push<PairingPayload>(
      MaterialPageRoute<PairingPayload>(
        builder: (_) => const PairingScannerScreen(),
      ),
    );
    if (payload == null || !mounted) {
      payload?.consume();
      return;
    }
    await _applyPairing(payload);
  }

  /// Probes a pairing payload's addresses and fills the editor from the one
  /// that answers.
  ///
  /// The payload is consumed on every exit path: it carries the serve
  /// password, and nothing beyond this method should still be holding it.
  /// The password reaches the password field and Keystore from there — it is
  /// never logged, never put in [_pairingNotice] or [_pairingFailure], and
  /// never in a URL.
  Future<void> _applyPairing(PairingPayload payload) async {
    if (widget.tailscale) {
      payload.consume();
      setState(
        () => _pairingFailure = _connectionL10n(context).tailscaleReviewDetail,
      );
      return;
    }
    if (_pairing) {
      payload.consume();
      return;
    }
    final username = payload.username;
    final password = payload.password;
    final firstUrl = payload.urls.first;
    final generation = ++_probeGeneration;
    setState(() {
      _testing = false;
      _pairing = true;
      _error = null;
      _testResult = null;
      _pairingNotice = null;
      _pairingFailure = null;
    });

    final PairingSelection selection;
    try {
      selection = await selectPairingUrl(payload);
    } finally {
      payload.consume();
    }
    if (!mounted || generation != _probeGeneration) return;

    // Fill the fields either way. Even when nothing answered, the user now
    // has the address and credentials in front of them and can fix the tunnel
    // rather than re-copying everything by hand.
    final chosen = selection.chosenUrl ?? normalizeServerProfileUrl(firstUrl);
    _url.value = TextEditingValue(text: chosen);
    _urlLength = chosen.length;
    _user.text = username;
    _pass.text = password;

    final host = Uri.tryParse(chosen)?.host ?? chosen;
    final tried = selection.outcomes.length;
    final result = selection.chosenResult;
    setState(() {
      _pairing = false;
      // The existing probe-verdict row already says the flavor, the version,
      // and "Connected — save to finish", and it is what `_save` reads to
      // cache the detected flavor. So pairing hands it the result and says
      // only the thing it cannot: *which* address was chosen, out of how
      // many. Repeating the verdict here would be two widgets telling the
      // user the same thing.
      _testResult = selection.ok ? result : null;
      if (selection.ok) {
        _pairingNotice = tried > 1
            ? lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupPairedChoice(host, tried)
            : lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupPaired(host);
        _pairingFailure = null;
      } else {
        _pairingNotice = null;
        _pairingFailure =
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupPairingFailed(
              setupUiMessage(
                lookupAppLocalizations(Localizations.localeOf(context)),
                selection.failureDetail,
              ),
              _pairingHint,
            );
      }
    });
    if (!selection.connected && (result?.needsPassword ?? false)) {
      _passFocus.requestFocus();
    }
  }

  /// What to do about a pairing code whose addresses all failed. A phone and
  /// a desktop have genuinely different answers, so they get different ones.
  String get _pairingHint => platformCapabilities.supportsUsbHostBridge
      ? lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7SetupPairingPhoneHint
      : lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7SetupPairingDesktopHint;

  /// Paste-first entry for the per-run serve password: nobody types a random
  /// 32-byte base64url string. Trims whitespace and a copied
  /// `server password ` line prefix.
  ///
  /// A clipboard holding a whole pairing payload is routed to [_applyPairing]
  /// instead — stuffing that JSON into the password field would be both
  /// wrong and a way to get the credential rendered on screen.
  Future<void> _pastePassword() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (looksLikePairingPayload(data?.text ?? '')) {
      final parsed = parsePairingPayload(data!.text!);
      if (!mounted) return;
      if (!parsed.ok) {
        setState(() {
          _pairingNotice = null;
          _pairingFailure = parsed.error;
        });
        return;
      }
      await _applyPairing(parsed.payload!);
      return;
    }
    var text = data?.text?.trim() ?? '';
    const prefix = 'server password';
    if (text.toLowerCase().startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
    if (text.isEmpty || !mounted || _submitting) return;
    setState(() {
      _invalidateProbe();
      _pass.text = text;
    });
    _passFocus.requestFocus();
  }

  bool get _dirty {
    final baseline = _savedProfile ?? widget.existing;
    return _backend != (baseline?.backend ?? ServerBackend.openCode) ||
        _name.text != (baseline?.name ?? '') ||
        _url.text != (baseline?.baseUrl ?? '') ||
        _user.text != (baseline?.username ?? '') ||
        _pass.text != (baseline?.password ?? '') ||
        _codexDirectory.text != (baseline?.codexDirectory ?? '') ||
        _codexToken.text != (baseline?.codexToken ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _codexDirectory.dispose();
    _codexToken.dispose();
    _urlFocus.dispose();
    _nameFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _codexDirectoryFocus.dispose();
    _codexTokenFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || _submitting) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    _closing = true;
    final discard = await showConfirmSheet(
      context,
      title: lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7SetupDiscardChanges,
      message: lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7SetupUnsavedProfile,
      confirmLabel: lookupAppLocalizations(
        Localizations.localeOf(context),
      ).e7SetupDiscard,
      cancelLabel: lookupAppLocalizations(
        Localizations.localeOf(context),
      ).draftKeepEditing,
      icon: AppIconography.editOff,
    );
    _closing = false;
    if (discard && mounted) Navigator.pop(context);
  }

  Future<void> _tailscaleHelp() async {
    if (_submitting) return;
    final before = _url.text;
    final generation = ++_probeGeneration;
    setState(() => _testing = false);
    final reviewed = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TailscaleSetupScreen(initialAddress: before),
      ),
    );
    if (!mounted ||
        reviewed == null ||
        _url.text != before ||
        generation != _probeGeneration) {
      return;
    }
    setState(() {
      _invalidateProbe();
      _url.text = reviewed;
      _urlLength = reviewed.length;
    });
  }

  /// "AI Team (optional)" › Add manually: the shared form; a found host is
  /// kept on the profile the next save writes.
  Future<void> _addTeamHost() async {
    final config = await showTeamHostSheet(
      context,
      initialUrl:
          _orchestration?.url ??
          teamDiscoveryUrlFor(normalizeServerProfileUrl(_url.text)) ??
          '',
      initialCity: _orchestration?.city ?? '',
      initialHostKind: _orchestration?.hostKind,
    );
    if (config == null || !mounted) return;
    setState(() => _orchestration = config);
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (_isCodex) {
      await _saveCodex();
      return;
    }
    var url = normalizeServerProfileUrl(_url.text);
    if (widget.tailscale && !isValidTailscaleAddress(url)) {
      setState(() => _error = _connectionL10n(context).tailscaleAddressError);
      return;
    }
    final error = validateServerProfileUrl(
      url,
      username: _user.text,
      password: _pass.text,
    );
    if (error != null) {
      setState(() => _error = error);
      _urlFocus.requestFocus();
      return;
    }
    final uri = Uri.parse(url);
    url = uri.replace(scheme: uri.scheme.toLowerCase()).toString();
    // Cache what Test connection detected; the connection layer re-verifies
    // on every cold connect and a failed connect re-probes, so a save without
    // a test (default v1) still self-corrects.
    final probed = _testResult;
    final normalizedUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
    final previousUrl = widget.existing == null
        ? null
        : normalizeServerProfileUrl(
            widget.existing!.baseUrl,
          ).replaceFirst(RegExp(r'/$'), '');
    final endpointChanged = previousUrl != null && previousUrl != normalizedUrl;
    // Cached identity belongs to an endpoint, not merely this profile name.
    // A new untested endpoint uses the same safe default as a new profile;
    // connect/probe will detect it rather than inherit the old server's v2 proof.
    final detected = probed != null && probed.flavor != ServerFlavor.unknown
        ? probed.flavor
        : endpointChanged
        ? ServerFlavor.v1
        : widget.existing?.flavor ?? ServerFlavor.v1;
    final profile = ServerProfile(
      id:
          _savedProfile?.id ??
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? uri.host : _name.text.trim(),
      baseUrl: normalizedUrl,
      username: _user.text.trim(),
      password: _pass.text,
      flavor: detected,
      serverVersion:
          probed?.version ??
          (endpointChanged ? null : widget.existing?.serverVersion),
      orchestration: _orchestration,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _invalidateProbe();
      _submitting = true;
      _submitFailure = null;
    });
    final outcome = await widget.onSubmit(profile);
    if (!mounted) return;
    if (outcome.saved) _savedProfile = profile;
    if (outcome.failure == null) {
      Navigator.pop(context, profile);
      return;
    }
    setState(() {
      _submitting = false;
      _submitFailure = outcome.failure;
    });
  }

  Future<void> _saveCodex() async {
    var url = _isPaseo
        ? normalizePaseoServerUrl(_url.text)
        : normalizeCodexServerUrl(_url.text);
    final error = _validateSocketFields(url);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final uri = Uri.parse(url);
    url = uri.toString().replaceAll(RegExp(r'/$'), '');
    final probed = _codexTestResult;
    final profile = ServerProfile(
      id:
          _savedProfile?.id ??
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? uri.host : _name.text.trim(),
      baseUrl: url,
      backend: _backend,
      codexDirectory: _codexDirectory.text.trim(),
      codexToken: _codexToken.text,
      serverVersion: probed?.version ?? widget.existing?.serverVersion,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _invalidateProbe();
      _submitting = true;
      _submitFailure = null;
    });
    final outcome = await widget.onSubmit(profile);
    if (!mounted) return;
    if (outcome.saved) _savedProfile = profile;
    if (outcome.failure == null) {
      Navigator.pop(context, profile);
      return;
    }
    setState(() {
      _submitting = false;
      _submitFailure = outcome.failure;
    });
  }

  Future<void> _pasteCodexToken() async {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (value == null || value.isEmpty || !mounted || _submitting) return;
    setState(() {
      _invalidateProbe();
      _codexToken.text = value;
    });
    _codexTokenFocus.requestFocus();
  }

  List<Widget> _buildCodexFields(ThemeData theme) => [
    const SizedBox(height: 12),
    TextField(
      enabled: !_submitting,
      key: const ValueKey('codex-server-name-field'),
      controller: _name,
      focusNode: _nameFocus,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _urlFocus.requestFocus(),
      onChanged: (_) => setState(_invalidateProbe),
      decoration: InputDecoration(
        labelText: _connectionL10n(context).connectionDisplayName,
        hintText: _connectionL10n(context).connectionDisplayNameHint,
      ),
    ),
    const SizedBox(height: 20),
    TextField(
      enabled: !_submitting,
      key: const ValueKey('codex-server-address-field'),
      textDirection: TextDirection.ltr,
      controller: _url,
      focusNode: _urlFocus,
      autofocus: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _codexDirectoryFocus.requestFocus(),
      onChanged: _urlChanged,
      decoration: InputDecoration(
        labelText: _connectionL10n(context).connectionServerAddress,
        hintText: _isPaseo
            ? _connectionL10n(context).paseoAddressHint
            : _connectionL10n(context).codexAddressHint,
        errorText: _error,
        errorMaxLines: 3,
        helperText: _isPaseo
            ? _connectionL10n(context).paseoAddressHelp
            : _connectionL10n(context).codexAddressHelp,
        helperMaxLines: 3,
      ),
    ),
    const SizedBox(height: 20),
    TextField(
      enabled: !_submitting,
      key: const ValueKey('codex-project-directory-field'),
      textDirection: TextDirection.ltr,
      controller: _codexDirectory,
      focusNode: _codexDirectoryFocus,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _codexTokenFocus.requestFocus(),
      onChanged: (_) => setState(_invalidateProbe),
      decoration: InputDecoration(
        labelText: _connectionL10n(context).codexProjectFolder,
        hintText: '/work/my-project',
      ),
    ),
    const SizedBox(height: 20),
    TextField(
      enabled: !_submitting,
      key: const ValueKey('codex-connection-token-field'),
      textDirection: TextDirection.ltr,
      controller: _codexToken,
      focusNode: _codexTokenFocus,
      autofocus: _needsCodexToken || widget.focusPassword,
      onChanged: (_) => setState(_invalidateProbe),
      obscureText: _obscurePassword,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      style: _obscurePassword
          ? null
          : const TextStyle(fontFamily: AppTheme.monoFamily),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        labelText: _needsCodexToken
            ? _connectionL10n(context).codexTokenReentry
            : _isPaseo
            ? _connectionL10n(context).paseoPasswordLabel
            : _connectionL10n(context).codexTokenLabel,
        helperText: _isPaseo
            ? _connectionL10n(context).paseoPasswordHelp
            : _connectionL10n(context).codexTokenStorageHelp,
        helperMaxLines: 2,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('codex-token-visibility'),
              tooltip: _obscurePassword
                  ? _connectionL10n(context).codexShowToken
                  : _connectionL10n(context).codexHideToken,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? AppIconography.visible
                    : AppIconography.hidden,
              ),
            ),
            IconButton(
              key: const ValueKey('codex-token-paste'),
              tooltip: _connectionL10n(context).codexPasteToken,
              onPressed: () => unawaited(_pasteCodexToken()),
              icon: const Icon(AppIconography.paste),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 24),
  ];

  Widget _buildCodexProbeVerdict(ThemeData theme) {
    final result = _codexTestResult!;
    return Semantics(
      key: const ValueKey('codex-probe-verdict'),
      container: true,
      liveRegion: true,
      child: Container(
        key: ValueKey(result.ok ? 'codex-test-success' : 'codex-test-failure'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: result.ok
              ? AppTheme.successOf(theme).withValues(alpha: .14)
              : theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              result.ok ? AppIconography.checkCircle : AppIconography.error,
              size: 20,
              color: result.ok
                  ? AppTheme.successOf(theme)
                  : theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.ok
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).codexConnectionVerified
                    : setupUiMessage(
                        lookupAppLocalizations(Localizations.localeOf(context)),
                        result.message,
                      ),
                style: TextStyle(
                  color: result.ok
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onErrorContainer,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? widget.openCode2Intent && !_isCodex
              ? _connectionL10n(context).oc2DiscoveryEditorTitle
              : lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7SetupAddServer
        : _needsCodexToken
        ? _connectionL10n(context).codexTokenReentry
        : _needsPassword
        ? lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7SetupReenterPassword
        : lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7SetupEditServer;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        key: const ValueKey('server-profile-editor'),
        appBar: AppBar(
          leading: IconButton(
            tooltip: _connectionL10n(context).connectionCloseEditor,
            onPressed: _submitting ? null : _close,
            icon: const Icon(AppIconography.close),
          ),
          title: Text(title),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FilledButton(
              key: const ValueKey('save-server-profile'),
              onPressed: _submitting ? null : _save,
              child: Text(
                _submitting
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupSaving
                    : _isCodex ||
                          widget.existing == null ||
                          widget.reconnectOnSave
                    ? _connectionL10n(context).onboardingSaveConnect
                    : _connectionL10n(context).onboardingSaveChanges,
              ),
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _submitting,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              key: const ValueKey('server-profile-fields'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.tailscale) ...[
                    Text(_connectionL10n(context).tailscaleEditorDetail),
                    TextButton.icon(
                      onPressed: _tailscaleHelp,
                      icon: const Icon(AppIconography.secureNetwork),
                      label: Text(_connectionL10n(context).tailscaleHelp),
                    ),
                    if (_testResult?.ok == false || _submitFailure != null)
                      Text(_connectionL10n(context).tailscaleRecovery),
                    const SizedBox(height: 12),
                  ],
                  if (widget.existing == null && !widget.tailscale) ...[
                    Text(
                      _connectionL10n(context).connectionTypeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      key: const ValueKey('server-backend-selector'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(
                            _connectionL10n(context).oc2DiscoveryTypes,
                          ),
                          selected: !_isCodex,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() {
                                  _backend = ServerBackend.openCode;
                                  _invalidateProbe();
                                }),
                        ),
                        ChoiceChip(
                          label: Text(
                            _connectionL10n(context).codexExperimentalLabel,
                          ),
                          selected: _isCodex && !_isPaseo,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() {
                                  _backend = ServerBackend.codex;
                                  _invalidateProbe();
                                }),
                        ),
                        ChoiceChip(
                          key: const ValueKey('server-backend-paseo'),
                          label: Text(
                            _connectionL10n(context).paseoExperimentalLabel,
                          ),
                          selected: _isPaseo,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() {
                                  _backend = ServerBackend.paseo;
                                  _invalidateProbe();
                                }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_isCodex) ...[
                    Text(
                      _connectionL10n(context).oc2DiscoveryAutodetect,
                      key: const ValueKey('opencode-autodetect-help'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // A save or connect that failed is shown first, where it is
                  // seen without scrolling, in the same verdict style as Test
                  // connection.
                  if (_submitFailure case final failure?) ...[
                    _InlineFailureCard(
                      key: const ValueKey('server-save-failure'),
                      message: failure,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_secureStorageNotice case final notice?) ...[
                    _InlineFailureCard(
                      key: const ValueKey('server-secure-storage-notice'),
                      message: notice,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_needsPassword) ...[
                    const SizedBox(height: 4),
                    Semantics(
                      container: true,
                      liveRegion: true,
                      excludeSemantics: true,
                      label: lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupMissingPasswordLong,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          lookupAppLocalizations(
                            Localizations.localeOf(context),
                          ).e7SetupMissingPasswordShort,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_isCodex) ...[
                    ..._buildCodexFields(theme),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _isPaseo
                            ? _connectionL10n(context).paseoSetupNotice
                            : lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).codexApprovalRecoveryNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (!_isCodex) ...[
                    const SizedBox(height: 12),
                    if (!widget.tailscale)
                      _PairingActions(
                        busy: _pairing,
                        notice: _pairingNotice,
                        failure: _pairingFailure,
                        onPaste: _pairing
                            ? null
                            : () => unawaited(_pastePairing()),
                        // Rendered only where a camera path exists. Desktop gets no
                        // affordance at all rather than one that opens and fails.
                        onScan: platformCapabilities.supportsQrPairing
                            ? () => unawaited(_scanPairing())
                            : null,
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      enabled: !_submitting,
                      key: const ValueKey('server-url-field'),
                      textDirection: TextDirection.ltr,
                      controller: _url,
                      focusNode: _urlFocus,
                      autofocus: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _nameFocus.requestFocus(),
                      onChanged: _urlChanged,
                      decoration: InputDecoration(
                        labelText: lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7SetupServerUrl,
                        hintText: 'https://server.example',
                        errorText: _error,
                        errorMaxLines: 3,
                        helperText: widget.tailscale
                            ? _connectionL10n(context).tailscaleAddressDetail
                            : lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupHttpsHint,
                        helperMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      enabled: !_submitting,
                      key: const ValueKey('server-name-field'),
                      controller: _name,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _userFocus.requestFocus(),
                      onChanged: (_) => setState(_invalidateProbe),
                      decoration: InputDecoration(
                        labelText: _connectionL10n(
                          context,
                        ).connectionDisplayName,
                        hintText: _connectionL10n(
                          context,
                        ).connectionDisplayNameHint,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupAuthentication,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: !_submitting,
                      key: const ValueKey('server-username-field'),
                      textDirection: TextDirection.ltr,
                      controller: _user,
                      focusNode: _userFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passFocus.requestFocus(),
                      onChanged: (_) => setState(_invalidateProbe),
                      decoration: InputDecoration(
                        labelText: lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7SetupUsername,
                        hintText: 'opencode',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      enabled: !_submitting,
                      key: const ValueKey('server-password-field'),
                      textDirection: TextDirection.ltr,
                      controller: _pass,
                      focusNode: _passFocus,
                      autofocus: _needsPassword || widget.focusPassword,
                      onChanged: (_) => setState(_invalidateProbe),
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      style: _obscurePassword
                          ? null
                          : const TextStyle(fontFamily: AppTheme.monoFamily),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        labelText: _needsPassword
                            ? lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupReenterPassword
                            : lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupServerPassword,
                        helperText: _needsPassword
                            ? lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupEmptyPasswordHint
                            : lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupPasswordStartupHint,
                        helperMaxLines: 3,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const ValueKey('server-password-visibility'),
                              tooltip: _obscurePassword
                                  ? lookupAppLocalizations(
                                      Localizations.localeOf(context),
                                    ).e7SetupShowPassword
                                  : lookupAppLocalizations(
                                      Localizations.localeOf(context),
                                    ).e7SetupHidePassword,
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? AppIconography.visible
                                    : AppIconography.hidden,
                              ),
                            ),
                            // Paste is the primary affordance for the per-run
                            // random serve password, so it sits closest to the
                            // field edge.
                            IconButton(
                              key: const ValueKey('server-password-paste'),
                              tooltip: lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupPastePassword,
                              onPressed: () => unawaited(_pastePassword()),
                              icon: const Icon(AppIconography.paste),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  FilledButton.tonalIcon(
                    key: const ValueKey('test-server-connection'),
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIconography.networkCheck),
                    label: Text(
                      _testing
                          ? lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7SetupTesting
                          : lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).e7SetupTestConnection,
                    ),
                  ),
                  if (_isCodex && _codexTestResult != null) ...[
                    const SizedBox(height: 12),
                    _buildCodexProbeVerdict(theme),
                  ],
                  if (_testResult case final result?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      key: const ValueKey('server-probe-verdict'),
                      container: true,
                      liveRegion: true,
                      child: Container(
                        key: ValueKey(
                          result.ok
                              ? 'server-test-success'
                              : 'server-test-failure',
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: result.ok
                              ? AppTheme.successOf(theme).withValues(alpha: .14)
                              : theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              result.ok
                                  ? AppIconography.checkCircle
                                  : AppIconography.error,
                              size: 20,
                              color: result.ok
                                  ? AppTheme.successOf(theme)
                                  : theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (result.ok) ...[
                                    Text(
                                      result.flavor == ServerFlavor.v2
                                          ? lookupAppLocalizations(
                                              Localizations.localeOf(context),
                                            ).e7SetupProbeV2(
                                              result.version ??
                                                  lookupAppLocalizations(
                                                    Localizations.localeOf(
                                                      context,
                                                    ),
                                                  ).e7SetupUnknownVersion,
                                            )
                                          : lookupAppLocalizations(
                                              Localizations.localeOf(context),
                                            ).e7SetupProbeV1(
                                              result.version ??
                                                  lookupAppLocalizations(
                                                    Localizations.localeOf(
                                                      context,
                                                    ),
                                                  ).e7SetupUnknownVersion,
                                            ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                    ),
                                    if (result.flavor == ServerFlavor.v1) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        lookupAppLocalizations(
                                          Localizations.localeOf(context),
                                        ).e7SetupV1Limited,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      lookupAppLocalizations(
                                        Localizations.localeOf(context),
                                      ).e7SetupSaveToFinish,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        height: 1.35,
                                      ),
                                    ),
                                  ] else ...[
                                    if (result.flavor == ServerFlavor.v2) ...[
                                      Text(
                                        lookupAppLocalizations(
                                          Localizations.localeOf(context),
                                        ).e7SetupIsV2,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      setupUiMessage(
                                        lookupAppLocalizations(
                                          Localizations.localeOf(context),
                                        ),
                                        result.message!,
                                      ),
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  if (!result.ok &&
                                      result.suggestsMissingServer) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      lookupAppLocalizations(
                                        Localizations.localeOf(context),
                                      ).e7SetupNoServerGuide,
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                        height: 1.35,
                                      ),
                                    ),
                                    TextButton(
                                      key: const ValueKey('server-test-guide'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        foregroundColor:
                                            theme.colorScheme.onErrorContainer,
                                      ),
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        '/guide',
                                      ),
                                      child: Text(
                                        lookupAppLocalizations(
                                          Localizations.localeOf(context),
                                        ).e7SetupOpenSetupGuide,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!_isCodex) ...[
                    const SizedBox(height: 24),
                    Text(
                      _connectionL10n(context).teamUiEditorTitle,
                      key: const ValueKey('server-editor-team-section'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _orchestration == null
                          ? _connectionL10n(context).teamUiEditorBody
                          : _connectionL10n(
                              context,
                            ).teamUiEditorConfigured(_orchestration!.url),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          key: const ValueKey('server-editor-team-learn'),
                          onPressed: _submitting
                              ? null
                              : () => showTeamHostGuideSheet(context),
                          child: Text(_connectionL10n(context).teamUiLearnHow),
                        ),
                        TextButton(
                          key: const ValueKey('server-editor-team-add'),
                          onPressed: _submitting ? null : _addTeamHost,
                          child: Text(
                            _orchestration == null
                                ? _connectionL10n(context).teamUiAddManually
                                : _connectionL10n(context).teamUiChange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one-step pairing affordance at the top of the server editor.
///
/// `opencode2 pair` prints the address, the username, and the per-run
/// password together, so pairing is strictly less work than copying a
/// password by hand — which is why it leads the editor rather than hiding
/// below the fields.
///
/// Deliberately lean: one helper line naming the command, then the buttons.
/// The editor is already a long form on a short screen: a titled card and a
/// paragraph of intro pushed the URL and password fields below the fold at
/// 2× text scale — the users least able to afford it. The rest of the
/// explaining is done where it costs nothing: the empty-clipboard and
/// failure messages name `opencode2 pair` outright, and the guide leads
/// with it.
class _PairingActions extends StatelessWidget {
  const _PairingActions({
    required this.busy,
    required this.notice,
    required this.failure,
    required this.onPaste,
    required this.onScan,
  });

  final bool busy;
  final String? notice;
  final String? failure;
  final VoidCallback? onPaste;

  /// Null wherever there is no camera path — desktop, and anywhere else
  /// `supportsQrPairing` says no. The button is then not built at all, so no
  /// camera code is reachable and nothing offers what it cannot do.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = this.notice;
    final failure = this.failure;
    return Column(
      key: const ValueKey('server-pairing-actions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7SetupPairingInstructions,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('server-pairing-paste'),
              onPressed: onPaste,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIconography.paste, size: 18),
              label: Text(
                busy
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupPairing
                    : lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupPastePairing,
              ),
            ),
            if (onScan case final scan?)
              OutlinedButton.icon(
                key: const ValueKey('server-pairing-scan'),
                onPressed: busy ? null : scan,
                icon: const Icon(AppIconography.qrCode, size: 18),
                label: Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7SetupScan,
                ),
              ),
          ],
        ),
        if (notice != null) ...[
          const SizedBox(height: 10),
          Semantics(
            key: const ValueKey('server-pairing-notice'),
            container: true,
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIconography.checkCircle,
                  size: 18,
                  color: AppTheme.successOf(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (failure != null) ...[
          const SizedBox(height: 10),
          Semantics(
            key: const ValueKey('server-pairing-failure'),
            container: true,
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIconography.error,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      setupUiMessage(
                        lookupAppLocalizations(Localizations.localeOf(context)),
                        failure,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The verdict-card treatment for a save or connect that failed, shared by
/// the editor and the servers list so a failure looks the same wherever it
/// lands: error container, leading glyph, live region — and product copy
/// only, never a raw exception.
class _InlineFailureCard extends StatelessWidget {
  const _InlineFailureCard({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AppIconography.error,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).workspaceDismissNotice,
                onPressed: onDismiss,
                color: theme.colorScheme.onErrorContainer,
                icon: const Icon(AppIconography.close, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
