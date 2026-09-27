import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../builtin/setup/phone_setup.dart';
import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/phone_host.dart';
import '../../state/termux_host_setup.dart';
import '../../termux/bridge.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../widgets/managed_server_recovery_option.dart';
import '../widgets/phone_server_card.dart';
import '../widgets/safety_confirms.dart';
import '../widgets/team_phone_onboarding.dart';
import '../widgets/termux_phone_tools.dart';
import 'keep_running_screen.dart';
import 'local_agent_screen.dart';
import 'phone_setup/phone_setup_routes.dart';
import 'phone_setup/phone_setup_selection.dart';
import 'phone_setup/phone_setup_termux_screen.dart';

/// Which host This phone shows when nobody said: the one in use, else the
/// in-app one when it is saved, else Termux.
PhoneHostKind defaultPhoneHostKind(ConnectionController connection) {
  final active = connection.profile;
  if (active != null && TermuxBridge.managesServerUrl(active.baseUrl)) {
    return PhoneHostKind.termux;
  }
  if (looksLikeInAppServer(active)) return PhoneHostKind.inApp;
  final store = connection.store;
  if (store.profiles.any(looksLikeInAppServer)) return PhoneHostKind.inApp;
  if (store.profiles.any((p) => TermuxBridge.managesServerUrl(p.baseUrl))) {
    return PhoneHostKind.termux;
  }
  return BuiltinLinux.supported ? PhoneHostKind.inApp : PhoneHostKind.termux;
}

/// This phone's route (lib/main.dart registers it on Android). Its
/// argument is the [PhoneHostKind] to show; none means the one in use.
const thisPhoneRoute = '/this-phone';

/// Opens This phone for [kind] (the one in use when null).
Future<void> openThisPhone(BuildContext context, {PhoneHostKind? kind}) =>
    Navigator.of(context).pushNamed<void>(thisPhoneRoute, arguments: kind);

/// This phone: OpenCode on this phone, whichever host runs it (inside the
/// app or in Termux), on one page (programme P1.5).
///
/// One list ordered by what is most likely needed: the status with the one
/// act it needs now (start, connect, finish a switch), then update, switch
/// between OpenCode 1 and 2, add tools, what is installed, storage, what
/// runs, keeping it running, the log, and removing it last. Each act names
/// what it acts on ("Stop the server on this phone"). Installing, updating,
/// switching and adding tools run through phone setup's progress screen.
class ThisPhoneScreen extends ConsumerStatefulWidget {
  const ThisPhoneScreen({super.key, this.kind, this.host});

  /// Which host; null picks [defaultPhoneHostKind].
  final PhoneHostKind? kind;

  /// Tests pass their own host; the app makes one from the providers.
  final PhoneHost? host;

  @override
  ConsumerState<ThisPhoneScreen> createState() => _ThisPhoneScreenState();
}

class _ThisPhoneScreenState extends ConsumerState<ThisPhoneScreen> {
  late final PhoneHost _host;
  late final bool _ownsHost;
  Set<String>? _installedOptional;
  bool _connecting = false;
  bool _removing = false;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  ConnectionController get _connection => ref.read(connProvider);

  static SetupEngine? _engine() {
    try {
      return PhoneSetup.engine;
    } on StateError {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _ownsHost = widget.host == null;
    _host = widget.host ?? _makeHost();
    _host.addListener(_changed);
    unawaited(_load());
  }

  PhoneHost _makeHost() {
    final kind = widget.kind ?? defaultPhoneHostKind(_connection);
    if (kind == PhoneHostKind.termux) {
      return TermuxPhoneHost(connection: _connection, copy: () => _l10n);
    }
    return InAppPhoneHost(
      linux: ref.read(builtinLinuxProvider),
      starter: ref.read(builtinServerStarterProvider),
      connection: _connection,
      engine: _engine(),
    );
  }

  Future<void> _load() async {
    await _host.refresh();
    if (_host.kind != PhoneHostKind.inApp) return;
    final engine = _engine();
    if (engine == null) return;
    try {
      final installed = await engine.installedOptional();
      if (mounted) setState(() => _installedOptional = installed);
    } catch (_) {
      // Unknown: the list shows what every setup installs.
    }
  }

  @override
  void dispose() {
    _host.removeListener(_changed);
    if (_ownsHost) _host.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String _runtimeName(TermuxRuntime runtime) =>
      runtime == TermuxRuntime.openCode2
      ? _l10n.setupRuntimeTwo
      : _l10n.setupRuntimeOne;

  TermuxRuntime get _otherRuntime => _host.runtime == TermuxRuntime.openCode2
      ? TermuxRuntime.openCode1
      : TermuxRuntime.openCode2;

  bool get _connectedHere {
    final profile = _host.profile;
    final connection = ref.watch(connProvider);
    return profile != null &&
        connection.hasConnectedServer &&
        connection.profile?.id == profile.id;
  }

  // --- Acts ------------------------------------------------------------------

  Future<void> _setUp() async {
    if (_host.kind == PhoneHostKind.termux) {
      await openPhoneSetupTermux(context, firstSetup: true);
    } else {
      await openPhoneSetupStart(context);
    }
    if (mounted) unawaited(_load());
  }

  Future<void> _showProgress() async {
    if (_host.kind == PhoneHostKind.termux) {
      await openPhoneSetupTermux(context, job: TermuxHostJob.update);
    } else {
      await openPhoneSetupProgress(context);
    }
    if (mounted) unawaited(_load());
  }

  Future<void> _start() async {
    await _host.start(_l10n);
    if (!mounted || _host.state != PhoneHostState.running) return;
    // Started with nothing else in use: connecting is the obvious next step.
    if (_connection.api == null) await _connect(openHome: false);
  }

  Future<void> _stop() async {
    if (!await confirmStopLocalServer(context) || !mounted) return;
    await _host.stop(_l10n);
  }

  Future<void> _connect({bool openHome = true}) async {
    final profile = _host.profile;
    if (profile == null || _connecting) return;
    setState(() => _connecting = true);
    final navigator = Navigator.of(context);
    final connection = _connection;
    await connection.connect(profile);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (connection.hasConnectedServer && openHome) {
      unawaited(navigator.pushNamedAndRemoveUntil('/home', (_) => false));
    }
  }

  /// In-app acts run as the "This phone" card runs them: through phone
  /// setup's engine and its progress screen.
  Future<void> _inApp(PhoneServerAction action) async {
    final profile = _host.profile;
    if (profile == null) return;
    final removed = await runPhoneServerAction(
      context,
      action,
      connection: _connection,
      linux: ref.read(builtinLinuxProvider),
      profile: profile,
      bytesUsed: _host.bytesUsed,
      onRemoving: () {
        if (mounted) setState(() => _removing = true);
      },
    );
    if (!mounted) return;
    setState(() => _removing = false);
    if (removed || action != PhoneServerAction.terminal) unawaited(_load());
  }

  Future<void> _update() async {
    if (_host.kind == PhoneHostKind.inApp) {
      return _inApp(PhoneServerAction.update);
    }
    final l10n = _l10n;
    if (_connection.busySessions.isNotEmpty) {
      await showKitAlert(
        context,
        title: l10n.e7SetupConfirmUpdate,
        body: l10n.e7SetupStopBeforeUpdate,
        icon: AppIconography.warning,
      );
      return;
    }
    final confirmed = await showKitConfirm(
      context,
      title: l10n.e7SetupConfirmUpdate,
      body: l10n.setupRuntimeUpdateDetail(
        _runtimeName(_host.runtime),
        _host.runtime.pinnedVersion,
      ),
      consequences: [l10n.e7SetupUpdateInterruption],
      confirmLabel: l10n.thisPhoneUpdate,
      icon: AppIconography.systemDownload,
      confirmKey: const ValueKey('this-phone-update-confirm'),
    );
    if (!confirmed || !mounted) return;
    await openPhoneSetupTermux(context, job: TermuxHostJob.update);
    if (mounted) unawaited(_load());
  }

  Future<void> _switchRuntime(TermuxRuntime target) async {
    final l10n = _l10n;
    final confirmed = await showKitConfirm(
      context,
      title: l10n.setupSwitchConfirmTitle(_runtimeName(target)),
      body: l10n.setupSwitchConfirmDetail,
      confirmLabel: l10n.setupSwitchConfirm,
      icon: AppIconography.sync,
      sheetKey: const ValueKey('this-phone-switch-sheet'),
      confirmKey: const ValueKey('this-phone-switch-confirm'),
    );
    if (!confirmed || !mounted) return;
    if (_host.kind == PhoneHostKind.inApp) {
      return _inApp(PhoneServerAction.switchRuntime);
    }
    await openPhoneSetupTermux(
      context,
      job: TermuxHostJob.switchRuntime,
      target: target,
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _addTools() async {
    if (_host.kind == PhoneHostKind.inApp) {
      return _inApp(PhoneServerAction.addTools);
    }
    // Termux's own tools: the AI Team and Claude Code, each with its own
    // cost and steps.
    final profile = _host.profile;
    final connection = _connection;
    final l10n = _l10n;
    await showKitSheet<void>(
      context,
      title: l10n.thisPhoneAddTools,
      icon: AppIconography.tools,
      height: KitSheetHeight.full,
      sheetKey: const ValueKey('this-phone-termux-tools'),
      body: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile != null && _host.state == PhoneHostState.running)
            TeamPhoneOnboardingBlock(
              key: ValueKey('team-phone-block-${profile.id}'),
              connection: connection,
              profile: profile,
              onOpenWorkspace: () {
                Navigator.of(sheetContext).pop();
                unawaited(_connect());
              },
            ),
          KitRowGroup(
            margin: EdgeInsetsDirectional.zero,
            children: [
              KitRow(
                key: const ValueKey('local-agent-row'),
                leading: KitRow.icon(sheetContext, AppIconography.agent),
                title: l10n.localAgentTitle,
                supporting: TextSpan(text: l10n.localAgentRowOptional),
                trailing: const KitChevron(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(
                    pushKitPage<void>(
                      context,
                      (_) => LocalAgentScreen(
                        onConnected: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/home', (_) => false),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The server's log in the one log view (KIT-31), re-read while the sheet
  /// is open and the server runs.
  Future<void> _showLog() async {
    final lines = KitLogBuffer();
    Future<void> read() async {
      lines.replaceText((await _host.readLog()).trimRight());
    }

    await read();
    if (!mounted) {
      lines.dispose();
      return;
    }
    final l10n = _l10n;
    final running = _host.state == PhoneHostState.running;
    await showKitSheet<void>(
      context,
      title: l10n.builtinServerLogTitle,
      icon: AppIconography.text,
      height: KitSheetHeight.full,
      sheetKey: const ValueKey('this-phone-log-sheet'),
      body: (_) => KitLogPanel(
        lines: lines,
        panelKey: const ValueKey('this-phone-log'),
        title: l10n.builtinServerLogTitle,
        emptyText: l10n.phoneServerCardLogEmpty,
        live: running,
        onRefresh: running ? read : null,
        ended: running ? null : const KitLogEnd(),
      ),
    );
    lines.dispose();
  }

  // --- The page --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final tokens = KitTokens.of(context);
    final state = _host.state;
    return KitScreen(
      topBar: KitTopBar(title: l10n.phoneServerCardTitle),
      width: KitScreenWidth.reading,
      loading: state == PhoneHostState.checking,
      loadingLabel: l10n.phoneServerCardChecking,
      body: ListView(
        key: const ValueKey('this-phone'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          _status(context, l10n),
          if (_host.installed) ...[
            SizedBox(height: tokens.sectionGap),
            _list(context, l10n),
          ],
        ],
      ),
    );
  }

  /// OpenCode's row: what it is, where it runs, how it is, and under it the
  /// one act it needs now.
  Widget _status(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final state = _host.state;
    final connected = _connectedHere;
    final working =
        _connecting ||
        _removing ||
        const {
          PhoneHostState.checking,
          PhoneHostState.starting,
          PhoneHostState.stopping,
          PhoneHostState.settingUp,
        }.contains(state);
    final word = _removing
        ? l10n.phoneServerCardRemoving
        : switch (state) {
            PhoneHostState.checking => l10n.phoneServerCardChecking,
            PhoneHostState.notSetUp => l10n.phoneServerCardNotSetUp,
            PhoneHostState.settingUp => l10n.phoneServerCardSettingUp,
            PhoneHostState.needsYou => l10n.thisPhoneNeedsAttention,
            PhoneHostState.starting => l10n.phoneServerCardStarting,
            PhoneHostState.stopping => l10n.phoneServerCardStopping,
            PhoneHostState.stopped => l10n.phoneServerCardStopped,
            PhoneHostState.running => l10n.phoneServerCardRunning,
          };
    final where = _host.kind == PhoneHostKind.termux
        ? l10n.thisPhoneHostTermux
        : l10n.thisPhoneHostInApp;
    // The generation is the title, so the line under it says the rest once.
    final title = _runtimeName(_host.runtime);
    final detail = [?_host.version, where].join(' · ');
    final failure = _removing ? null : _host.failure;
    final switchTarget = _host.switchTarget;
    final switchPrevious = _host.switchPrevious;
    final name = l10n.phoneServerCardTitle;

    KitAction? primary;
    KitAction? secondary;
    if (!working) {
      switch (state) {
        case PhoneHostState.notSetUp:
          primary = KitAction(
            key: const ValueKey('this-phone-set-up'),
            label: l10n.thisPhoneSetUp,
            onPressed: () => unawaited(_setUp()),
          );
        case PhoneHostState.needsYou when switchTarget != null:
          primary = KitAction(
            key: const ValueKey('this-phone-switch-retry'),
            label: l10n.setupSwitchRetry(_runtimeName(switchTarget)),
            onPressed: () => unawaited(
              openPhoneSetupTermux(
                context,
                job: TermuxHostJob.switchRuntime,
                target: switchTarget,
              ),
            ),
          );
          if (switchPrevious != null && switchPrevious != switchTarget) {
            secondary = KitAction(
              key: const ValueKey('this-phone-switch-return'),
              label: l10n.setupSwitchReturn(_runtimeName(switchPrevious)),
              onPressed: () => unawaited(
                openPhoneSetupTermux(
                  context,
                  job: TermuxHostJob.switchRuntime,
                  target: switchPrevious,
                ),
              ),
            );
          }
        case PhoneHostState.needsYou || PhoneHostState.stopped:
          primary = KitAction(
            key: const ValueKey('this-phone-start'),
            label: l10n.thisPhoneStart,
            onPressed: () => unawaited(_start()),
          );
        case PhoneHostState.running:
          if (!connected && _host.profile != null) {
            primary = KitAction(
              key: const ValueKey('this-phone-connect'),
              label: l10n.phoneServerCardConnect(name),
              onPressed: () => unawaited(_connect()),
            );
          }
          secondary = KitAction(
            key: const ValueKey('this-phone-stop'),
            label: l10n.thisPhoneStop,
            onPressed: () => unawaited(_stop()),
          );
        case PhoneHostState.checking ||
            PhoneHostState.settingUp ||
            PhoneHostState.starting ||
            PhoneHostState.stopping:
          break;
      }
    } else if (state == PhoneHostState.settingUp) {
      primary = KitAction(
        key: const ValueKey('this-phone-progress'),
        label: l10n.phoneServerCardShowProgress,
        onPressed: () => unawaited(_showProgress()),
      );
    }
    final actions = KitActionBlock(primary: primary, secondary: secondary);
    final running = state == PhoneHostState.running;
    return KitRowGroup(
      key: const ValueKey('this-phone-status'),
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          child: KitRow(
            leading: working
                ? const KitStatusMark(state: KitMarkState.working)
                : KitRowIcon(AppIconography.phone, current: connected),
            title: title,
            titleKey: const ValueKey('this-phone-title'),
            supporting: TextSpan(
              children: [
                if (connected) kitCurrentSpan(context, l10n.serverRowConnected),
                TextSpan(text: detail),
              ],
            ),
            supportingKey: const ValueKey('this-phone-detail'),
            supportingMaxLines: 2,
            trailing: KitText(
              word,
              key: const ValueKey('this-phone-state'),
              role: KitTextRole.secondary,
              tone: running && !working
                  ? KitTextTone.success
                  : KitTextTone.secondary,
            ),
            below: failure == null
                ? null
                : KitText(
                    failure,
                    key: const ValueKey('this-phone-failure'),
                    role: KitTextRole.secondary,
                    tone: KitTextTone.primary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
        if (!actions.isEmpty)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.space4,
              tokens.space2,
              tokens.space4,
              tokens.space3,
            ),
            child: actions,
          ),
      ],
    );
  }

  /// Everything else, in one list: the likely acts first, the facts next,
  /// the rare tools after, Remove last.
  Widget _list(BuildContext context, AppLocalizations l10n) {
    final state = _host.state;
    final inApp = _host.kind == PhoneHostKind.inApp;
    final busy =
        _connecting ||
        _removing ||
        const {
          PhoneHostState.settingUp,
          PhoneHostState.starting,
          PhoneHostState.stopping,
        }.contains(state);
    final busyReason = busy ? l10n.thisPhoneBusy : null;
    final hasEngine = !inApp || _engine() != null;
    final other = _otherRuntime;
    final switchLocked = !inApp && !_host.canSwitchRuntime;
    final halfSwitched = _host.switchTarget != null;
    final recoveryProfile = inApp
        ? null
        : _connection.store.profiles
              .where((p) => TermuxBridge.managesServerUrl(p.baseUrl))
              .firstOrNull;
    Widget icon(IconData data) => KitRow.icon(context, data);

    return KitRowGroup(
      key: const ValueKey('this-phone-list'),
      children: [
        if (hasEngine && !halfSwitched)
          KitRow(
            key: const ValueKey('this-phone-update'),
            leading: icon(AppIconography.systemDownload),
            title: l10n.thisPhoneUpdate,
            supporting: TextSpan(
              text: l10n.thisPhoneUpdateDetail(_host.runtime.pinnedVersion),
            ),
            trailing: const KitChevron(),
            enabled: !busy,
            disabledReason: busyReason,
            onTap: () => unawaited(_update()),
          ),
        if (hasEngine && !halfSwitched)
          KitRow(
            key: const ValueKey('this-phone-switch'),
            leading: icon(AppIconography.sync),
            title: l10n.phoneServerCardSwitchTo(_runtimeName(other)),
            supporting: switchLocked
                ? TextSpan(text: l10n.setupSwitchLegacyTwo)
                : null,
            supportingMaxLines: 3,
            trailing: const KitChevron(),
            enabled: !busy && !switchLocked,
            disabledReason: switchLocked
                ? l10n.setupSwitchLegacyTwo
                : busyReason,
            onTap: () => unawaited(_switchRuntime(other)),
          ),
        if (hasEngine)
          KitRow(
            key: const ValueKey('this-phone-add-tools'),
            leading: icon(AppIconography.tools),
            title: l10n.thisPhoneAddTools,
            supporting: TextSpan(
              text: inApp
                  ? l10n.thisPhoneAddToolsInApp
                  : l10n.thisPhoneAddToolsTermux,
            ),
            trailing: const KitChevron(),
            enabled: !busy,
            disabledReason: busyReason,
            onTap: () => unawaited(_addTools()),
          ),
        _installed(context, l10n),
        if (inApp)
          KitRow(
            key: const ValueKey('this-phone-storage'),
            leading: icon(AppIconography.database),
            title: l10n.termuxStorageTitle,
            trailing: _host.bytesUsed == null
                ? null
                : KitRowValue(
                    formatPhoneStorage(_host.bytesUsed!),
                    chevron: false,
                  ),
          )
        else ...[
          const TermuxPhoneToolsRows(only: TermuxPhoneTool.storage),
          const TermuxPhoneToolsRows(only: TermuxPhoneTool.processes),
        ],
        if (recoveryProfile != null)
          ManagedServerRecoveryOption(
            prefs: _connection.store.prefs,
            profileID: recoveryProfile.id,
          ),
        KitRow(
          key: const ValueKey('this-phone-keep-running'),
          leading: icon(AppIconography.batteryCharging),
          title: l10n.keepRunningTitle,
          supporting: TextSpan(text: l10n.keepRunningRowSubtitle),
          trailing: const KitChevron(),
          onTap: () => unawaited(openKeepRunningScreen(context)),
        ),
        KitRow(
          key: const ValueKey('this-phone-log'),
          leading: icon(AppIconography.article),
          title: l10n.thisPhoneShowLog,
          trailing: const KitChevron(),
          onTap: () => unawaited(_showLog()),
        ),
        if (inApp)
          KitRow(
            key: const ValueKey('this-phone-terminal'),
            leading: icon(AppIconography.terminal),
            title: l10n.thisPhoneTerminal,
            trailing: const KitChevron(),
            enabled: !_removing,
            onTap: () => unawaited(_inApp(PhoneServerAction.terminal)),
          ),
        if (inApp)
          KitRow(
            key: const ValueKey('this-phone-remove'),
            leading: icon(AppIconography.delete),
            title: l10n.thisPhoneRemove,
            destructive: true,
            enabled: !busy && state != PhoneHostState.settingUp,
            disabledReason: busyReason,
            onTap: () => unawaited(_inApp(PhoneServerAction.remove)),
          ),
      ],
    );
  }

  /// What is installed on this phone, folded: the parts setup put there.
  Widget _installed(BuildContext context, AppLocalizations l10n) {
    final names = <String>[];
    if (_host.kind == PhoneHostKind.inApp) {
      final engine = _engine();
      final optional = _installedOptional ?? const <String>{};
      for (final component
          in engine == null
              ? const <SetupComponent>[]
              : installableComponents(engine.registry)) {
        if (component.required || optional.contains(component.id)) {
          names.add(component.shortTitle);
        }
      }
      if (names.isEmpty) names.add(l10n.phoneSetupLinuxTitle);
    } else {
      names.addAll([l10n.phoneSetupLinuxTitle, _runtimeName(_host.runtime)]);
    }
    return KitExpandRow(
      key: const ValueKey('this-phone-installed'),
      headerKey: const ValueKey('this-phone-installed-header'),
      leading: KitRow.icon(context, AppIconography.check),
      title: l10n.thisPhoneInstalled,
      supporting: TextSpan(text: joinSetupNames(l10n, names)),
      supportingMaxLines: 2,
      children: [
        for (final name in names)
          KitRow(
            title: name,
            leading: const KitStatusMark(state: KitMarkState.done),
          ),
      ],
    );
  }
}
