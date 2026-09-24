import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/product_repository.dart' show ProductException;
import '../../api/server_probe.dart';
import '../../builtin/builtin_server.dart' show looksLikeInAppServer;
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
import '../../state/local_agent_server.dart';
import '../../state/first_run.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../setup_commands.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/first_run_choice.dart';
import '../widgets/product_states.dart';
import '../widgets/team_host_form.dart';
import '../widgets/local_agent_server_entry.dart';
import '../widgets/phone_server_card.dart';
import '../widgets/termux_running_server_entry.dart';
import '../widgets/safety_confirms.dart';
import '../../state/local_server_controls.dart';
import 'agent_choice_screen.dart';
import 'phone_setup/phone_setup_routes.dart';
import 'phone_setup/phone_setup_welcome_entry.dart';
import 'demo_screen.dart';
import 'guide_screen.dart' show Cmd;
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

/// Checks a Paseo daemon or a Codex app-server, the two socket backends.
typedef SocketAgentProbe =
    Future<CodexConnectionProbeResult> Function({
      required ServerBackend backend,
      required String baseUrl,
      required String secret,
      required String directory,
    });

Future<CodexConnectionProbeResult> _probeSocketAgent({
  required ServerBackend backend,
  required String baseUrl,
  required String secret,
  required String directory,
}) => backend == ServerBackend.paseo
    ? probePaseoConnection(
        baseUrl: baseUrl,
        password: secret,
        directory: directory,
      )
    : probeCodexConnection(
        baseUrl: baseUrl,
        token: secret,
        directory: directory,
      );

/// The socket-backend counterpart of [serverProbe]: replaceable so a widget
/// test can answer the connect screen's test without opening a socket.
@visibleForTesting
SocketAgentProbe socketAgentProbe = _probeSocketAgent;

/// How long the person must stop typing before the first-run connect screen
/// tests by itself. Long enough that an address is not probed half-typed,
/// short enough that the verdict is there when they look up.
@visibleForTesting
const autoTestPause = Duration(milliseconds: 800);

AppLocalizations _connectionL10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// What another surface asks the Servers screen to do as it opens, passed as
/// the `/servers` route argument.
///
/// The server switcher in the shell lists the same servers, but connecting,
/// credentials, adding and forgetting each have one implementation, here:
/// the runtime-choice detour, the editor that stays open until a connect
/// succeeds, and the inline failure card. The switcher hands the choice over
/// instead of keeping a second, thinner copy of that flow.
class ServersRouteRequest {
  /// Connect [profileID] through the list's connect flow. [detectedRunning]
  /// is the phone card's promise that this runtime is the live one.
  const ServersRouteRequest.connect(
    String this.profileID, {
    this.detectedRunning = false,
  }) : kind = ServersRouteRequestKind.connect,
       openCode2 = false;

  /// Open the editor for a new server.
  const ServersRouteRequest.add()
    : kind = ServersRouteRequestKind.add,
      profileID = null,
      detectedRunning = false,
      openCode2 = false;

  /// Ask for the phone server's sign-in, saved as [profileID] when it exists.
  const ServersRouteRequest.enterPhoneCredentials({
    this.profileID,
    required this.openCode2,
  }) : kind = ServersRouteRequestKind.enterPhoneCredentials,
       detectedRunning = true;

  /// Confirm and forget the saved server [profileID].
  const ServersRouteRequest.forget(String this.profileID)
    : kind = ServersRouteRequestKind.forget,
      detectedRunning = false,
      openCode2 = false;

  final ServersRouteRequestKind kind;
  final String? profileID;
  final bool detectedRunning;
  final bool openCode2;
}

enum ServersRouteRequestKind { connect, add, enterPhoneCredentials, forget }

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
  void initState() {
    super.initState();
    // The welcome as the first thing a device shows is what makes it new
    // (see [FirstRun]); the shell reads this after the first connect.
    final store = ref.read(bootstrapProvider).store;
    unawaited(
      FirstRun(
        store.prefs,
      ).observeServers(hasServers: store.profiles.isNotEmpty),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledRouteArgument) return;
    _handledRouteArgument = true;
    // The connection banner's "Update password" action routes here with this
    // argument: open the active profile's editor with the password focused so
    // a rotated serve password is one paste away (never a modal).
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is ServersRouteRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_handleRouteRequest(argument));
      });
      return;
    }
    if (argument == 'edit-active') {
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

  Future<void> _handleRouteRequest(ServersRouteRequest request) async {
    ServerProfile? target;
    for (final p in ref.read(bootstrapProvider).store.profiles) {
      if (p.id == request.profileID) target = p;
    }
    switch (request.kind) {
      case ServersRouteRequestKind.add:
        await _edit();
      case ServersRouteRequestKind.connect:
        if (target != null) {
          await _connect(target, detectedRunning: request.detectedRunning);
        }
      case ServersRouteRequestKind.enterPhoneCredentials:
        await _enterPhoneCredentials(
          existing: target,
          openCode2: request.openCode2,
        );
      case ServersRouteRequestKind.forget:
        if (target != null) await _delete(target);
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

  /// The one door to running an agent on this phone (phone setup v2,
  /// screen A). Termux and the in-app setup both live behind it, so the
  /// welcome and the list never offer two competing phone paths.
  Future<void> _openPhoneSetup() async {
    await openPhoneSetupStart(context);
    // Termux may have been set up from its "Other ways" row meanwhile.
    if (mounted) setState(() => _termuxRevision++);
  }

  /// The detected running-server entry for [profiles]: it decides on its own
  /// whether anything is shown, so both the welcome and the list embed it
  /// unconditionally and stay platform-gated through it.
  Widget _runningServerEntry(
    List<ServerProfile> profiles,
    ConnectionController connection,
  ) {
    // Both servers this app can run on the phone lead the list and are
    // controlled in place: OpenCode first, then the Claude Code daemon. Each
    // entry decides on its own whether it has anything to show.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _openCodeServerEntry(profiles, connection),
        LocalAgentServerEntry(
          profiles: profiles,
          busy: _busy,
          revision: _termuxRevision,
          connectedProfileID: connection.api == null
              ? null
              : connection.profile?.id,
          busyConversations: connection.busySessions.length,
          onDisconnect: () async {
            if (!await confirmDisconnectServer(context, connection)) return;
            await connection.disconnect(keepActive: true);
          },
          onForget: _delete,
          onManage: _openTermuxSetup,
          onConnect: (profile) => _connect(profile, detectedRunning: true),
          onOpenSaved: _connect,
        ),
      ],
    );
  }

  Widget _openCodeServerEntry(
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
      onOpenSaved: _connect,
      onEnterCredentials: (server, existing) => _enterPhoneCredentials(
        existing: existing,
        openCode2: server.flavor == ServerFlavor.v2,
      ),
    );
  }

  /// The phone's own server is running but the app has no usable password for
  /// it. The app wrote that password, so it first restores it from the phone;
  /// only when that is impossible (or the restored one was already refused)
  /// does it ask the person to type one.
  Future<void> _enterPhoneCredentials({
    required ServerProfile? existing,
    required bool openCode2,
  }) async {
    if (_busy) return;
    final recovered = await TermuxBridge.managedServerPassword();
    if (!mounted) return;
    final alreadyRefused =
        existing != null &&
        !existing.requiresPasswordReentry &&
        existing.password == recovered;
    if (recovered != null && !alreadyRefused) {
      final store = ref.read(bootstrapProvider).store;
      final profile =
          existing ??
          ServerProfile(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupThisDevice,
            baseUrl: TermuxBridge.managedServerUrl,
            flavor: openCode2 ? ServerFlavor.v2 : ServerFlavor.v1,
          );
      profile
        ..username = 'opencode'
        ..password = recovered
        ..requiresPasswordReentry = false;
      await store.upsert(profile);
      if (!mounted) return;
      setState(() {});
      await _connect(profile, detectedRunning: true);
      return;
    }
    await _edit(
      existing: existing,
      connectOnSave: true,
      initialUrl: TermuxBridge.managedServerUrl,
      focusPassword: true,
      openCode2Intent: openCode2,
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

  /// Completes with whether the editor saved a server.
  Future<bool> _edit({
    ServerProfile? existing,
    bool focusPassword = false,
    bool tailscale = false,
    String? initialUrl,
    bool openCode2Intent = false,
    bool connectOnSave = false,
    ServerBackend? presetBackend,
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
          presetBackend: presetBackend,
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
    if (result == null) return false;
    if (!mounted) return true;
    if (isNew || connectOnSave || result.backend == ServerBackend.codex) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
    return true;
  }

  /// First run, computer path: ask which agent, then open the connect screen
  /// already set to it. The connect screen is pushed on top of the question,
  /// so Back returns to the question rather than to the welcome.
  Future<void> _computerPath() {
    final navigator = Navigator.of(context);
    late final MaterialPageRoute<void> question;
    question = MaterialPageRoute<void>(
      builder: (_) => AgentChoiceScreen(
        onChoose: (backend) async {
          final saved = await _edit(presetBackend: backend);
          // A first connection turns the root into the shell in place, so
          // this screen is no longer mounted to clear the stack itself. The
          // question has been answered; left alone it would sit on top of
          // the conversation the person is about to land in.
          if (saved && question.isActive) navigator.removeRoute(question);
        },
      ),
    );
    return navigator.push<void>(question);
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
          // First run asks one question; the guide is reference material and
          // lives in Settings → Help (UX plan 5.4). It stays here once there
          // are servers to manage.
          if (bootstrap.store.profiles.isNotEmpty)
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
              phoneSetup: PhoneSetupWelcomeEntry(revision: _termuxRevision),
              onComputer: _computerPath,
              onPhone: _openPhoneSetup,
              onDemo: _demo,
            );
          }
          final activeId = store.activeId;
          final phoneServer = phoneServerProfile(store.profiles, activeId);
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
          final copy = lookupAppLocalizations(Localizations.localeOf(context));
          return KitScreen(
            // One bar for a connect, save or removal in flight (standard §4).
            loading: _busy,
            loadingLabel: copy.e7SetupServerOperation,
            // Adding a server is what this screen offers beyond its rows:
            // the one primary, pinned below the list (§1, §2).
            bottom: KitActionBlock(
              primary: KitAction(
                key: const ValueKey('servers-add'),
                label: copy.e7SetupAddServer,
                icon: AppIconography.add,
                onPressed: _busy ? null : () => _edit(),
              ),
              tertiary: [
                KitAction(
                  key: const ValueKey('servers-try-demo'),
                  label: DemoCopy.tryDemo,
                  icon: AppIconography.playCircle,
                  onPressed: _busy ? null : _demo,
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                SectionLabel(copy.e7SetupServers),
                if (needsCredential)
                  _Rails(
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      excludeSemantics: true,
                      label: needsToken
                          ? copy.e7SetupTokenBanner
                          : copy.e7SetupPasswordBanner,
                      child: KitNotice(
                        key: const Key('password-reentry-banner'),
                        tone: AppStatusTone.attention,
                        icon: Icons.lock_reset_rounded,
                        message: _connectionL10n(
                          context,
                        ).connectionCredentialUnavailable,
                        liveRegion: false,
                      ),
                    ),
                  ),
                if (_listFailure case final failure?)
                  _Rails(
                    child: KitNotice(
                      key: const ValueKey('server-connect-failure'),
                      tone: AppStatusTone.failure,
                      message: failure,
                      onDismiss: () => setState(() => _listFailure = null),
                    ),
                  ),
                // The phone's own servers lead the list, one row each; the
                // saved sign-ins they stand for are not listed again below.
                _runningServerEntry(store.profiles, accountConnection),
                // OpenCode inside this app is "This phone", managed in place;
                // its saved entries are how the app reaches it, so they are
                // not listed again below.
                if (phoneServer != null) ...[
                  _Rails(
                    child: PhoneServerCard(
                      key: ValueKey('phone-server-card-${phoneServer.id}'),
                      connection: accountConnection,
                      profile: phoneServer,
                      connected:
                          accountConnection.api != null &&
                          accountConnection.profile?.id == phoneServer.id,
                      onOpen: _busy ? null : () => _connect(phoneServer),
                      onRemoved: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  const Divider(height: 17),
                ],
                for (final p in store.profiles)
                  if (!looksLikeInAppServer(p) && !_shownAsPhoneRow(p))
                    _ServerRow(
                      profile: p,
                      connected:
                          accountConnection.api != null &&
                          accountConnection.profile?.id == p.id,
                      busy: _busy,
                      showAccount:
                          p.id == activeId &&
                          accountConnection.isConnected &&
                          accountConnection.capabilities.agentAccount,
                      onConnect: () => _connect(p),
                      onEdit: () => _edit(existing: p),
                      onRemove: () => _delete(p),
                      onAccount: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              AgentAccountScreen(connection: accountConnection),
                        ),
                      ),
                    ),
                // Other ways in, as rows (§6): the OpenCode 2 shortcut, this
                // phone, and the rarer setups folded under one row. A
                // hairline keeps them from reading as more servers.
                const Divider(height: 17, indent: 16, endIndent: 16),
                _OpenCode2Entry(
                  onTap: _busy ? null : () => _edit(openCode2Intent: true),
                ),
                if (platformCapabilities.supportsTermux)
                  _PhoneSetupEntry(
                    key: const ValueKey('quick-add-phone-card'),
                    onTap: _busy ? null : _openPhoneSetup,
                  ),
                _SetupOptions(
                  busy: _busy,
                  onTailscale: _tailscale,
                  onGuide: () => Navigator.pushNamed(context, '/guide'),
                  onExternalAgents: _externalAgents,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A saved server the phone's own row stands for (the OpenCode server this
/// app runs in Termux, or Claude Code on this phone): on a phone that can
/// run them the list shows that row, not a second one named after the
/// address it was saved with (docs/design/phone-server-screens-cleanup-
/// 2026-09-24.md §1: one row per server).
bool _shownAsPhoneRow(ServerProfile profile) =>
    platformCapabilities.supportsTermux &&
    (isManagedPhoneProfile(profile) || isLocalAgentProfile(profile));

/// The page's 16 dp side rails for a part that does not pad itself (the
/// kit's rows and section labels do).
class _Rails extends StatelessWidget {
  const _Rails({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: child,
  );
}

/// One saved server as a kit row (design standard §6): its kind as the
/// icon, the name, then what it runs and its address, with a credential that
/// must be re-entered said first, in the error colour. The server the app is
/// connected to carries the current mark: a filled accent circle and
/// "Connected" leading its line. Tapping connects; the rest is in the menu.
class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.profile,
    required this.connected,
    required this.busy,
    required this.showAccount,
    required this.onConnect,
    required this.onEdit,
    required this.onRemove,
    required this.onAccount,
  });

  final ServerProfile profile;
  final bool connected;
  final bool busy;
  final bool showAccount;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    final p = profile;
    final error = theme.colorScheme.error;
    final kind = p.usesAgentSocket
        ? '${p.backend == ServerBackend.paseo ? 'Paseo' : 'Codex'}${p.codexDirectory.isEmpty ? '' : ' · ${p.codexDirectory}'}'
        : p.backend == ServerBackend.openCode
        ? _knownOpenCodeGeneration(p)
        : null;
    final reentry = p.requiresPasswordReentry
        ? copy.e7SetupPasswordRequired
        : p.requiresCodexTokenReentry
        ? copy.e7SetupTokenRequired
        : null;
    return Semantics(
      selected: connected,
      child: KitRow(
        key: ValueKey('server-row-${p.id}'),
        leading: KitRowIcon(
          isLoopbackHost(Uri.tryParse(p.baseUrl)?.host ?? '')
              ? AppIconography.phone
              : AppIconography.server,
          current: connected,
        ),
        title: p.name,
        supporting: TextSpan(
          children: [
            if (reentry != null)
              TextSpan(
                text: '$reentry · ',
                style: TextStyle(color: error, fontWeight: FontWeight.w600),
              ),
            if (connected) kitCurrentSpan(context, copy.serverRowConnected),
            if (kind != null) TextSpan(text: '$kind · '),
            TextSpan(text: _shortAddress(p.baseUrl)),
          ],
        ),
        supportingMaxLines: 2,
        enabled: !busy,
        onTap: onConnect,
        trailing: KitRowMenu(
          key: ValueKey('server-menu-${p.id}'),
          enabled: !busy,
          items: [
            if (showAccount)
              KitMenuItem(
                label: _connectionL10n(context).agentAccountTitle,
                onSelected: onAccount,
              ),
            KitMenuItem(label: copy.e7SetupConnect, onSelected: onConnect),
            KitMenuItem(label: copy.e7SetupEdit, onSelected: onEdit),
            // Destructive: error-coloured, confirmed by the sheet it opens.
            KitMenuItem(
              label: copy.capsuleRemove,
              destructive: true,
              onSelected: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a saved server is, as a row shows it: the host and an explicit
/// port, without the scheme, so the line reads as a place and does not
/// break at "https://". The full address is in the server's editor.
String _shortAddress(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || uri.host.isEmpty) return baseUrl;
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return uri.hasPort ? '$host:${uri.port}' : host;
}

/// First run asks the only real fork, one question with plain answers (UX
/// plan 5.6 step 1). Product names, private networks and the guide are met
/// later, at the step where each one matters.
class _WelcomeView extends StatelessWidget {
  final bool busy;

  /// The detected on-device server, above the question. It renders nothing
  /// unless a running server was actually observed: a live thing the app
  /// found outranks every generic choice.
  final Widget runningServer;

  /// A phone setup that was started and not finished (or finished with
  /// nothing saved). Like [runningServer] it renders nothing when there is
  /// no such job, and it outranks the generic question when there is.
  final Widget phoneSetup;
  final VoidCallback onComputer;
  final VoidCallback onPhone;
  final VoidCallback onDemo;

  const _WelcomeView({
    required this.busy,
    required this.runningServer,
    required this.phoneSetup,
    required this.onComputer,
    required this.onPhone,
    required this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _connectionL10n(context);
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
                        copy.onboardingValueTitle,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        copy.onboardingValueBody,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (platformCapabilities.supportsTermux) phoneSetup,
                      runningServer,
                      Semantics(
                        header: true,
                        child: Text(
                          copy.firstRunWhereQuestion,
                          key: const ValueKey('welcome-question'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FirstRunChoice(
                        key: const ValueKey('welcome-choice-computer'),
                        icon: AppIconography.server,
                        title: copy.firstRunOnComputer,
                        detail: copy.firstRunOnComputerDetail,
                        onTap: busy ? null : onComputer,
                      ),
                      if (platformCapabilities.supportsTermux)
                        FirstRunChoice(
                          key: const ValueKey('welcome-choice-phone'),
                          icon: AppIconography.phone,
                          title: copy.onboardingTermuxSetup,
                          detail: copy.firstRunOnPhoneDetail,
                          onTap: busy ? null : onPhone,
                        ),
                      FirstRunChoice(
                        key: const ValueKey('welcome-choice-demo'),
                        icon: AppIconography.playCircle,
                        title: copy.firstRunJustShowMe,
                        detail: copy.onboardingDemoNote,
                        onTap: busy ? null : onDemo,
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

/// The trailing mark of a row that opens another screen.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Icon(
      AppIconography.chevronRight,
      size: 20,
      color: AppTheme.mutedOf(Theme.of(context)),
    ),
  );
}

/// A discovery shortcut into the same autodetecting editor, not a flavor override.
class _OpenCode2Entry extends StatelessWidget {
  const _OpenCode2Entry({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KitRow(
    key: const ValueKey('connect-existing-opencode2'),
    leading: KitRow.icon(context, AppIconography.server),
    title: _connectionL10n(context).oc2DiscoveryConnect,
    supporting: TextSpan(text: _connectionL10n(context).oc2DiscoveryExisting),
    supportingMaxLines: 2,
    trailing: const _Chevron(),
    onTap: onTap,
  );
}

/// A phone feature must stay discoverable when the current server is remote.
/// One entry for every way of running an agent on this phone: it opens phone
/// setup (screen A), where the in-app setup leads and Termux is one of the
/// "Other ways".
class _PhoneSetupEntry extends StatelessWidget {
  const _PhoneSetupEntry({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KitRow(
    leading: KitRow.icon(context, AppIconography.phone),
    title: _connectionL10n(context).onboardingTermuxSetup,
    supporting: TextSpan(
      text: _connectionL10n(context).phoneSetupStartEntryDetail,
    ),
    supportingMaxLines: 2,
    trailing: const _Chevron(),
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
  Widget build(BuildContext context) => ListTileTheme(
    // The kit row's geometry: a 32 dp icon, 12 dp to the title.
    data: const ListTileThemeData(horizontalTitleGap: 12, minLeadingWidth: 32),
    child: _setupOptions(context),
  );

  Widget _setupOptions(BuildContext context) => ExpansionTile(
    leading: KitRow.icon(context, AppIconography.tools),
    title: Text(
      _connectionL10n(context).onboardingMoreSetup,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    tilePadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
    childrenPadding: EdgeInsets.zero,
    shape: const Border(),
    collapsedShape: const Border(),
    children: [
      if (platformCapabilities.supportsTailscaleHandoff)
        KitRow(
          key: const ValueKey('welcome-tailscale-card'),
          leading: KitRow.icon(context, AppIconography.secureNetwork),
          title: _connectionL10n(context).tailscaleTitle,
          supporting: TextSpan(
            text: _connectionL10n(context).onboardingPrivateNetwork,
          ),
          supportingMaxLines: 2,
          onTap: busy ? null : onTailscale,
        ),
      KitRow(
        key: const ValueKey('welcome-guide-card'),
        leading: KitRow.icon(context, AppIconography.guide),
        title: _connectionL10n(context).onboardingSetupGuide,
        onTap: busy ? null : onGuide,
      ),
      KitRow(
        leading: KitRow.icon(context, AppIconography.network),
        title: _connectionL10n(context).a2aTitle,
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

  /// The agent the person chose on the first-run computer path. The editor
  /// becomes that agent's connect screen: the backend selector is hidden
  /// (they already answered), the command to run leads, and the private
  /// network link sits under the address. Null everywhere else.
  final ServerBackend? presetBackend;

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
    this.presetBackend,
    this.focusPassword = false,
    required this.onSubmit,
    this.secureStorageProbe,
  });

  @override
  State<_ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<_ProfileEditorScreen> {
  /// "More options" starts open only when something in it was already set:
  /// a username other than the default, or an AI Team host.
  late bool _moreOptionsOpen =
      (widget.existing?.username.isNotEmpty == true &&
          widget.existing?.username != 'opencode') ||
      widget.existing?.orchestration != null;

  late ServerBackend _backend =
      widget.existing?.backend ??
      widget.presetBackend ??
      ServerBackend.openCode;
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

  /// The pause before the first-run test runs by itself; see [_autoTests].
  Timer? _autoTestTimer;

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
    _applyUrlChange(value);
    _scheduleAutoTest();
  }

  void _applyUrlChange(String value) {
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

  /// Every field's change handler: what was tested is no longer what is
  /// typed, so the verdict goes and, on the first-run path, a new test is
  /// queued behind a pause.
  void _fieldChanged() {
    setState(_invalidateProbe);
    _scheduleAutoTest();
  }

  /// True on the first-run connect screen only (UX plan 5.6 step 3). Editing
  /// a saved server never tests by itself: that person came to change one
  /// value, and a probe of the half-edited profile is noise.
  bool get _autoTests =>
      widget.presetBackend != null && widget.existing == null;

  /// The required fields as [_testConnection] would accept them, checked
  /// without its side effects (no error text, no focus move).
  bool get _readyForAutoTest {
    if (_url.text.trim().isEmpty) return false;
    if (_isCodex) {
      final url = _isPaseo
          ? normalizePaseoServerUrl(_url.text)
          : normalizeCodexServerUrl(_url.text);
      return _validateSocketFields(url) == null;
    }
    return validateServerProfileUrl(
          normalizeServerProfileUrl(_url.text),
          username: _user.text,
          password: _pass.text,
        ) ==
        null;
  }

  /// One test after the person pauses, never one per keystroke: each change
  /// restarts the wait, and [_invalidateProbe] has already retired whatever
  /// probe was in flight.
  void _scheduleAutoTest() {
    _autoTestTimer?.cancel();
    _autoTestTimer = null;
    if (!_autoTests || !_readyForAutoTest) return;
    _autoTestTimer = Timer(autoTestPause, () {
      _autoTestTimer = null;
      if (!mounted || _submitting || _pairing || _testing || _closing) return;
      if (!_readyForAutoTest) return;
      unawaited(_testConnection(auto: true));
    });
  }

  void _invalidateProbe() {
    _autoTestTimer?.cancel();
    _autoTestTimer = null;
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

  /// [auto] is the first-run test that runs by itself. It reports the same
  /// verdict but never moves focus: the person is still typing somewhere.
  Future<void> _testConnection({bool auto = false}) async {
    if (_testing) return;
    _autoTestTimer?.cancel();
    _autoTestTimer = null;
    if (_isCodex) {
      await _testCodexConnection(auto: auto);
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
    if (!auto && result.flavor == ServerFlavor.v2 && result.needsPassword) {
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

  Future<void> _testCodexConnection({bool auto = false}) async {
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
      final result = await socketAgentProbe(
        backend: _backend,
        baseUrl: url,
        secret: _codexToken.text,
        directory: _codexDirectory.text.trim(),
      );
      if (!mounted || generation != _probeGeneration) return;
      setState(() {
        _testing = false;
        _submitFailure = null;
        _codexTestResult = result;
      });
      if (!result.ok && !auto) _codexTokenFocus.requestFocus();
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
    _scheduleAutoTest();
    _passFocus.requestFocus();
  }

  bool get _dirty {
    final baseline = _savedProfile ?? widget.existing;
    return _backend !=
            (baseline?.backend ??
                widget.presetBackend ??
                ServerBackend.openCode) ||
        _name.text != (baseline?.name ?? '') ||
        _url.text != (baseline?.baseUrl ?? '') ||
        _user.text != (baseline?.username ?? '') ||
        _pass.text != (baseline?.password ?? '') ||
        _codexDirectory.text != (baseline?.codexDirectory ?? '') ||
        _codexToken.text != (baseline?.codexToken ?? '');
  }

  @override
  void dispose() {
    _autoTestTimer?.cancel();
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
    _scheduleAutoTest();
  }

  /// "Not on the same network?" on the first-run connect screen. For an
  /// OpenCode server the reviewed private address comes back into the field.
  /// Paseo and Codex listen on `ws://`, which the Tailscale screen does not
  /// produce, so there it is opened for its guidance and the field is left
  /// to the person.
  Future<void> _notSameNetwork() async {
    if (!_isCodex) return _tailscaleHelp();
    if (_submitting) return;
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TailscaleSetupScreen()),
    );
  }

  /// Null where the link must not exist: off the first-run path, and on a
  /// platform with no Tailscale handoff (hide, don't disable).
  Widget? _notSameNetworkLink() {
    if (widget.presetBackend == null ||
        !platformCapabilities.supportsTailscaleHandoff) {
      return null;
    }
    return KitInset(
      child: KitButton.tertiary(
        key: const ValueKey('connect-not-same-network'),
        onPressed: _submitting ? null : () => unawaited(_notSameNetwork()),
        label: _connectionL10n(context).firstRunNotSameNetwork,
      ),
    );
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
    _scheduleAutoTest();
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
      onChanged: (_) => _fieldChanged(),
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
    ?_notSameNetworkLink(),
    const SizedBox(height: 20),
    TextField(
      enabled: !_submitting,
      key: const ValueKey('codex-project-directory-field'),
      textDirection: TextDirection.ltr,
      controller: _codexDirectory,
      focusNode: _codexDirectoryFocus,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _codexTokenFocus.requestFocus(),
      onChanged: (_) => _fieldChanged(),
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
      onChanged: (_) => _fieldChanged(),
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
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    // A verdict is a notice on the form's rails, not a filled block (§3).
    return KeyedSubtree(
      key: const ValueKey('codex-probe-verdict'),
      child: KitNotice(
        key: ValueKey(result.ok ? 'codex-test-success' : 'codex-test-failure'),
        tone: result.ok ? AppStatusTone.ok : AppStatusTone.failure,
        message: result.ok
            ? copy.codexConnectionVerified
            : setupUiMessage(copy, result.message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.presetBackend != null
        ? switch (widget.presetBackend!) {
            ServerBackend.openCode => _connectionL10n(
              context,
            ).firstRunAgentOpenCode,
            ServerBackend.paseo => _connectionL10n(context).firstRunPaseoTitle,
            ServerBackend.codex => _connectionL10n(context).firstRunAgentCodex,
          }
        : widget.existing == null
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
            // The one primary (§2), pinned under the form. Its tap runs the
            // save and the connect; the spinner is that tap in flight.
            child: KitButton.primary(
              key: const ValueKey('save-server-profile'),
              onPressed: _submitting ? null : _save,
              working: _submitting,
              label: _submitting
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
                    KitInset(
                      child: KitButton.tertiary(
                        onPressed: _tailscaleHelp,
                        icon: AppIconography.secureNetwork,
                        label: _connectionL10n(context).tailscaleHelp,
                      ),
                    ),
                    if (_testResult?.ok == false || _submitFailure != null)
                      Text(_connectionL10n(context).tailscaleRecovery),
                    const SizedBox(height: 12),
                  ],
                  if (widget.presetBackend case final preset?) ...[
                    _ComputerCommand(backend: preset),
                    const SizedBox(height: 12),
                  ],
                  // The person who came through "Which agent?" already chose;
                  // asking again would be a second, harder copy of the same
                  // question.
                  if (widget.existing == null &&
                      !widget.tailscale &&
                      widget.presetBackend == null) ...[
                    SectionLabel.inline(
                      _connectionL10n(context).connectionTypeLabel,
                    ),
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
                  // No "detects OpenCode 1 or 2" line: the check after the
                  // address says which one it found, when it matters.
                  // A save or connect that failed is shown first, where it is
                  // seen without scrolling, in the same verdict style as Test
                  // connection.
                  if (_submitFailure case final failure?) ...[
                    KitNotice(
                      key: const ValueKey('server-save-failure'),
                      tone: AppStatusTone.failure,
                      message: failure,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_secureStorageNotice case final notice?) ...[
                    KitNotice(
                      key: const ValueKey('server-secure-storage-notice'),
                      tone: AppStatusTone.attention,
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
                      child: KitNotice(
                        tone: AppStatusTone.attention,
                        icon: Icons.lock_reset_rounded,
                        liveRegion: false,
                        message: lookupAppLocalizations(
                          Localizations.localeOf(context),
                        ).e7SetupMissingPasswordShort,
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
                        // The command is already on screen above, with its
                        // copy button; only the next move is left to say.
                        instructions: widget.presetBackend == null
                            ? null
                            : platformCapabilities.supportsQrPairing
                            ? _connectionL10n(context).firstRunPairingNextScan
                            : _connectionL10n(context).firstRunPairingNextPaste,
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
                      // Straight to the password: the name and username
                      // are under More options and rarely needed.
                      onSubmitted: (_) => _passFocus.requestFocus(),
                      onChanged: _urlChanged,
                      scrollPadding: const EdgeInsets.only(bottom: 160),
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
                    ?_notSameNetworkLink(),
                    const SizedBox(height: 16),
                    TextField(
                      enabled: !_submitting,
                      key: const ValueKey('server-password-field'),
                      textDirection: TextDirection.ltr,
                      controller: _pass,
                      focusNode: _passFocus,
                      autofocus: _needsPassword || widget.focusPassword,
                      onChanged: (_) => _fieldChanged(),
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      // Room for the Save button above the keyboard, so the
                      // field being typed in is never hidden behind it.
                      scrollPadding: const EdgeInsets.only(bottom: 160),
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
                  // The form's one secondary (§2); its spinner is only the
                  // test in flight, the verdict below says what it found.
                  KitButton.secondary(
                    key: const ValueKey('test-server-connection'),
                    onPressed: _testing ? null : _testConnection,
                    working: _testing,
                    icon: AppIconography.networkCheck,
                    label: _testing
                        ? lookupAppLocalizations(
                            Localizations.localeOf(context),
                          ).e7SetupTesting
                        : lookupAppLocalizations(
                            Localizations.localeOf(context),
                          ).e7SetupTestConnection,
                  ),
                  if (_isCodex && _codexTestResult != null) ...[
                    const SizedBox(height: 12),
                    _buildCodexProbeVerdict(theme),
                  ],
                  if (_testResult case final result?) ...[
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: const ValueKey('server-probe-verdict'),
                      child: _ProbeVerdict(result: result),
                    ),
                  ],
                  if (!_isCodex) ...[
                    const SizedBox(height: 8),
                    // What most people never change, out of the way: the name
                    // comes from the address and the username is "opencode"
                    // unless the server was started with another.
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const ValueKey('server-editor-more-options'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        initiallyExpanded: _moreOptionsOpen,
                        onExpansionChanged: (open) => _moreOptionsOpen = open,
                        title: Text(
                          _connectionL10n(context).serverEditorMoreOptions,
                        ),
                        children: [
                          TextField(
                            enabled: !_submitting,
                            key: const ValueKey('server-name-field'),
                            controller: _name,
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _userFocus.requestFocus(),
                            onChanged: (_) => _fieldChanged(),
                            decoration: InputDecoration(
                              labelText: _connectionL10n(
                                context,
                              ).connectionDisplayName,
                              hintText: _connectionL10n(
                                context,
                              ).connectionDisplayNameHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            enabled: !_submitting,
                            key: const ValueKey('server-username-field'),
                            textDirection: TextDirection.ltr,
                            controller: _user,
                            focusNode: _userFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _passFocus.requestFocus(),
                            onChanged: (_) => _fieldChanged(),
                            decoration: InputDecoration(
                              labelText: lookupAppLocalizations(
                                Localizations.localeOf(context),
                              ).e7SetupUsername,
                              hintText: 'opencode',
                            ),
                          ),
                          const SizedBox(height: 20),
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
                          KitInset(
                            child: Wrap(
                              spacing: 4,
                              children: [
                                KitButton.tertiary(
                                  key: const ValueKey(
                                    'server-editor-team-learn',
                                  ),
                                  onPressed: _submitting
                                      ? null
                                      : () => showTeamHostGuideSheet(context),
                                  label: _connectionL10n(
                                    context,
                                  ).teamUiLearnHow,
                                ),
                                KitButton.tertiary(
                                  key: const ValueKey('server-editor-team-add'),
                                  onPressed: _submitting ? null : _addTeamHost,
                                  label: _orchestration == null
                                      ? _connectionL10n(
                                          context,
                                        ).teamUiAddManually
                                      : _connectionL10n(context).teamUiChange,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

/// The one command that starts the chosen agent, with a copy button, and the
/// rest of the setup guide's commands behind "Show the commands" (UX plan
/// 5.9). First run is the moment the person is at their computer with a
/// terminal open; the guide screen stays in Settings → Help for later.
class _ComputerCommand extends StatelessWidget {
  const _ComputerCommand({required this.backend});

  final ServerBackend backend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _connectionL10n(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Column(
      key: const ValueKey('connect-computer-command'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.firstRunRunOnComputer, style: theme.textTheme.titleSmall),
        Cmd(
          SetupCommands.startFor(backend),
          key: const ValueKey('connect-command'),
        ),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('connect-show-commands'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(copy.firstRunShowCommands),
            children: switch (backend) {
              ServerBackend.openCode => [
                Text(
                  copy.e7SharedServersStartedWithOpencodeServeDoNot,
                  style: caption,
                ),
                const Cmd(SetupCommands.legacyServe),
                Text(
                  copy.e7SharedThenAddTheServerManuallyWithUsername,
                  style: caption,
                ),
              ],
              ServerBackend.paseo => [
                Text(copy.firstRunCommandsPaseoNetwork, style: caption),
                const Cmd(SetupCommands.paseoStartPrivateNetwork),
              ],
              ServerBackend.codex => [
                Text(copy.firstRunCommandsCodexToken, style: caption),
                const Cmd(SetupCommands.codexToken),
                Text(copy.firstRunCommandsCodexUsb, style: caption),
                const Cmd(SetupCommands.codexUsb),
              ],
            },
          ),
        ),
      ],
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
    this.instructions,
    required this.busy,
    required this.notice,
    required this.failure,
    required this.onPaste,
    required this.onScan,
  });

  /// Replaces the line that names the command, where the command is already
  /// shown above with a copy button.
  final String? instructions;
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
          instructions ??
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupPairingInstructions,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        // Two text buttons (§2 tertiary): pairing is a shortcut into the
        // fields below, not the form's action. The spinner is only the paste
        // being checked; the notice under them says what was found.
        KitInset(
          child: Wrap(
            spacing: 4,
            children: [
              KitButton(
                key: const ValueKey('server-pairing-paste'),
                role: KitButtonRole.tertiary,
                expand: false,
                onPressed: onPaste,
                working: busy,
                icon: AppIconography.paste,
                label: busy
                    ? lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupPairing
                    : lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupPastePairing,
              ),
              if (onScan case final scan?)
                KitButton.tertiary(
                  key: const ValueKey('server-pairing-scan'),
                  onPressed: busy ? null : scan,
                  icon: AppIconography.qrCode,
                  label: lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).e7SetupScan,
                ),
            ],
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: 4),
          KitNotice(
            key: const ValueKey('server-pairing-notice'),
            tone: AppStatusTone.ok,
            message: notice,
          ),
        ],
        if (failure != null) ...[
          const SizedBox(height: 4),
          KitNotice(
            key: const ValueKey('server-pairing-failure'),
            tone: AppStatusTone.failure,
            message: setupUiMessage(
              lookupAppLocalizations(Localizations.localeOf(context)),
              failure,
            ),
          ),
        ],
      ],
    );
  }
}

/// What Test connection found (design standard §3, a notice on the form's
/// rails, never a filled block): which OpenCode answered and what to do next,
/// or why it did not, with the setup guide when nothing seems to be there.
class _ProbeVerdict extends StatelessWidget {
  const _ProbeVerdict({required this.result});

  final ServerProbeResult result;

  @override
  Widget build(BuildContext context) {
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    if (result.ok) {
      final version = result.version ?? copy.e7SetupUnknownVersion;
      return KitNotice(
        key: const ValueKey('server-test-success'),
        tone: AppStatusTone.ok,
        title: result.flavor == ServerFlavor.v2
            ? copy.e7SetupProbeV2(version)
            : copy.e7SetupProbeV1(version),
        message: copy.e7SetupSaveToFinish,
        notes: [if (result.flavor == ServerFlavor.v1) copy.e7SetupV1Limited],
      );
    }
    return KitNotice(
      key: const ValueKey('server-test-failure'),
      tone: AppStatusTone.failure,
      // A missing password answers 401 on OpenCode 1 and 2 alike; which one
      // it is shows once the password is in.
      title: result.flavor == ServerFlavor.v2 && !result.needsPassword
          ? copy.e7SetupIsV2
          : null,
      message: setupUiMessage(copy, result.message!),
      notes: [if (result.suggestsMissingServer) copy.e7SetupNoServerGuide],
      actions: [
        if (result.suggestsMissingServer)
          KitAction(
            key: const ValueKey('server-test-guide'),
            label: copy.e7SetupOpenSetupGuide,
            onPressed: () => Navigator.pushNamed(context, '/guide'),
          ),
      ],
    );
  }
}
