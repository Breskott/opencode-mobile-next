import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../builtin/setup/phone_setup.dart';
import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart' show TermuxRuntime;
import '../app_theme.dart';
import '../kit/kit.dart';
import '../screens/phone_setup/phone_setup_routes.dart';
import '../screens/terminal_screen.dart' show TerminalPage, TerminalSource;
import 'confirm_sheet.dart';
import 'product_states.dart';
import 'terminal_view.dart';
import 'termux_running_server_entry.dart' show isManagedPhoneProfile;

/// Screen D of phone setup (docs/design/phone-setup-v2-2026-09-24.md): the
/// one place OpenCode running inside this app is managed, wherever servers
/// are listed (the server switcher and Settings → Servers).
///
/// It is always called "This phone". The address, the port and the name the
/// profile was saved under are how the app finds it, not what a person
/// needs to read.

/// What the ⋯ menu can ask for. Each one either leaves for the setup
/// progress screen or removes the server, so a host that is itself a sheet
/// (the switcher) closes first and runs it with [runPhoneServerAction].
enum PhoneServerAction { terminal, switchRuntime, addTools, update, remove }

/// The saved in-app profile the card stands for: the active one when it is
/// in-app, else the newest. Setup may have saved one per OpenCode version;
/// they are all the same server on this phone, so there is one card.
ServerProfile? phoneServerProfile(
  Iterable<ServerProfile> profiles,
  String? activeId,
) {
  ServerProfile? chosen;
  for (final profile in profiles) {
    if (!looksLikeInAppServer(profile)) continue;
    if (profile.id == activeId) return profile;
    chosen = profile;
  }
  return chosen;
}

/// The name to show for [profile]: "This phone" for the in-app server,
/// otherwise the name it was saved under.
///
/// Setup saves one in-app profile per OpenCode generation, and both are
/// "This phone". When [among] (the saved profiles) holds the other
/// generation too, the name says which one this is ("This phone ·
/// OpenCode 2"), so two of them never sit side by side looking the same.
/// Only the shown name changes; the stored names stay as they were saved.
String serverDisplayName(
  ServerProfile? profile,
  AppLocalizations l10n, {
  Iterable<ServerProfile> among = const [],
}) {
  if (profile == null) return 'OpenCode';
  // OpenCode in Termux is named as its row on Servers and in the switcher
  // ("This phone · Termux"), not by the name setup saved it under; the
  // app's own server is plain "This phone".
  if (isManagedPhoneProfile(profile)) return l10n.phoneServerTermuxTitle;
  if (!looksLikeInAppServer(profile)) return profile.name;
  return phoneServerDisplayName(profile, l10n, among: among);
}

/// [serverDisplayName] for a profile known to be the in-app server (the
/// "This phone" card's own title).
String phoneServerDisplayName(
  ServerProfile profile,
  AppLocalizations l10n, {
  Iterable<ServerProfile> among = const [],
}) {
  final twoGenerations = among.any(
    (other) =>
        other.id != profile.id &&
        other.backend == ServerBackend.openCode &&
        BuiltinLinux.managesServerUrl(other.baseUrl) &&
        other.flavor != profile.flavor,
  );
  if (!twoGenerations) return l10n.phoneServerCardTitle;
  return l10n.phoneSetupOpenPhoneRuntime(
    l10n.phoneServerCardTitle,
    profile.flavor == ServerFlavor.v2
        ? l10n.setupRuntimeTwo
        : l10n.setupRuntimeOne,
  );
}

/// Test seams for the routes this card calls but other screens own.
class PhoneServerCardRoutes {
  PhoneServerCardRoutes._();

  @visibleForTesting
  static Future<void> Function(BuildContext context)? openProgressOverride;

  @visibleForTesting
  static Future<Set<String>?> Function(BuildContext context)? customizeOverride;

  @visibleForTesting
  static Future<void> Function(BuildContext context)? openStartOverride;

  static Future<void> openProgress(BuildContext context) =>
      (openProgressOverride ?? openPhoneSetupProgress)(context);

  static Future<Set<String>?> addTools(BuildContext context) =>
      customizeOverride?.call(context) ??
      showPhoneSetupCustomize(context, addMode: true);

  static Future<void> openStart(BuildContext context) =>
      (openStartOverride ?? openPhoneSetupStart)(context);
}

/// The engine, or null on a build where it is not wired (it is Android
/// only): the menu then offers nothing that needs it.
SetupEngine? _engine() {
  try {
    return PhoneSetup.engine;
  } on StateError {
    return null;
  }
}

TermuxRuntime _runtimeOf(ServerProfile profile) =>
    BuiltinLinux.runtimeFor(profile.flavor);

/// Runs one ⋯ menu [action] for the in-app [profile] from [context], which
/// must outlive it (a screen, not a closing sheet). Returns true when the
/// server was removed from this phone.
Future<bool> runPhoneServerAction(
  BuildContext context,
  PhoneServerAction action, {
  required ConnectionController connection,
  required BuiltinLinux linux,
  required ServerProfile profile,
  int? bytesUsed,
  VoidCallback? onRemoving,
}) async {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final messenger = ScaffoldMessenger.maybeOf(context);
  void notify(String message) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> install(
    Set<String> ids, {
    Map<String, Map<String, String>> params = const {},
  }) async {
    final engine = _engine();
    if (engine == null) return;
    try {
      await engine.run(ids, params: params);
    } catch (error) {
      notify(l10n.phoneServerCardActionFailed(productErrorText(error)));
      return;
    }
    if (context.mounted) await PhoneServerCardRoutes.openProgress(context);
  }

  switch (action) {
    case PhoneServerAction.terminal:
      // A shell in this phone's Linux: it needs no running server, so it is
      // the way in when the server is stopped or not answering.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'local-terminal'),
          builder: (_) => TerminalPage(
            controller: connection,
            initialSource: TerminalSource.phone,
          ),
        ),
      );
      return false;
    case PhoneServerAction.switchRuntime:
      // Re-running the one component with the other runtime; the engine
      // starts and connects the server it installed.
      final target = _runtimeOf(profile) == TermuxRuntime.openCode2
          ? TermuxRuntime.openCode1
          : TermuxRuntime.openCode2;
      await install(
        {'opencode'},
        params: {
          'opencode': {'runtime': target.wireName},
        },
      );
      return false;
    case PhoneServerAction.update:
      // OpenCode 1 is the engine's default runtime; OpenCode 2 must be named
      // or "update" would install the other one.
      final runtime = _runtimeOf(profile);
      await install(
        {'opencode'},
        params: runtime == TermuxRuntime.openCode2
            ? {
                'opencode': {'runtime': runtime.wireName},
              }
            : const {},
      );
      return false;
    case PhoneServerAction.addTools:
      final ids = await PhoneServerCardRoutes.addTools(context);
      if (ids == null || ids.isEmpty || !context.mounted) return false;
      await install(ids, params: SetupJobParams.adding(ids));
      return false;
    case PhoneServerAction.remove:
      return _removePhoneServer(
        context,
        l10n: l10n,
        notify: notify,
        connection: connection,
        linux: linux,
        bytesUsed: bytesUsed,
        onRemoving: onRemoving,
      );
  }
}

/// Confirms with the space that comes back, stops and deletes OpenCode and
/// everything inside it, then forgets the saved entries: a "This phone"
/// entry left behind would point at nothing and could only fail.
Future<bool> _removePhoneServer(
  BuildContext context, {
  required AppLocalizations l10n,
  required void Function(String) notify,
  required ConnectionController connection,
  required BuiltinLinux linux,
  int? bytesUsed,
  VoidCallback? onRemoving,
}) async {
  final size = bytesUsed;
  final confirmed = await showConfirmSheet(
    context,
    title: l10n.phoneServerCardRemoveTitle,
    message: size != null && size > 0
        ? l10n.phoneServerCardRemoveBody(formatPhoneStorage(size))
        : l10n.phoneServerCardRemoveBodyUnmeasured,
    confirmLabel: l10n.phoneServerCardRemoveConfirm,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    icon: AppIconography.delete,
    destructive: true,
    sheetKey: const ValueKey('phone-server-remove-sheet'),
    confirmKey: const ValueKey('phone-server-remove-confirm'),
  );
  if (!confirmed) return false;
  onRemoving?.call();
  // Leave the server before it disappears, so the app does not spend the
  // next minute reconnecting to something that is gone.
  if (connection.api != null && looksLikeInAppServer(connection.profile)) {
    await connection.disconnect(keepActive: true);
  }
  try {
    await linux.uninstall();
  } on BuiltinLinuxException catch (error) {
    notify(l10n.phoneServerCardActionFailed(error.message));
    return false;
  }
  final saved = [
    for (final profile in connection.store.profiles)
      if (looksLikeInAppServer(profile)) profile,
  ];
  for (final profile in saved) {
    try {
      final result = await connection.deleteProfileAndLocalData(profile.id);
      final partial = result.partialDeletionMessage;
      if (partial != null) notify(partial);
    } catch (error) {
      notify(l10n.phoneServerCardActionFailed(productErrorText(error)));
    }
  }
  notify(l10n.phoneServerCardRemoved);
  return true;
}

/// Storage as a phone shows it: one decimal, binary units. Callers show it
/// only for a real measurement, never "0 B".
String formatPhoneStorage(int bytes) {
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (bytes < 1024) return '$bytes B';
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}

enum _Status { checking, notSetUp, stopped, starting, stopping, running }

class PhoneServerCard extends ConsumerStatefulWidget {
  const PhoneServerCard({
    super.key,
    required this.connection,
    required this.profile,
    this.connected = false,
    this.onOpen,
    this.onAction,
    this.onRemoved,
    this.linux,
    this.pollInterval = const Duration(seconds: 5),
  });

  final ConnectionController connection;

  /// The saved in-app profile ([phoneServerProfile]).
  final ServerProfile profile;

  /// The app is connected to this server now: Open would lead nowhere.
  final bool connected;

  /// Connects to this server; null hides Open.
  final VoidCallback? onOpen;

  /// A host that must close before navigating (the switcher sheet) takes
  /// the menu action and runs [runPhoneServerAction] from its own screen.
  /// Null runs it here.
  final void Function(PhoneServerAction action, int? bytesUsed)? onAction;

  /// Called after an in-place Remove took the server off this phone.
  final VoidCallback? onRemoved;

  /// Tests pass a fake bridge; the app uses [builtinLinuxProvider].
  final BuiltinLinux? linux;

  /// How often the card re-reads whether the server runs, so a server
  /// Android stopped does not keep showing "Running". Null reads only on
  /// open and after an action.
  final Duration? pollInterval;

  @override
  ConsumerState<PhoneServerCard> createState() => _PhoneServerCardState();
}

class _PhoneServerCardState extends ConsumerState<PhoneServerCard> {
  late final BuiltinLinux _linux =
      widget.linux ?? ref.read(builtinLinuxProvider);
  late final BuiltinServerStarter _starter = ref.read(
    builtinServerStarterProvider,
  );
  BuiltinLinuxStatus? _status;
  Timer? _poll;
  bool _stopping = false;
  bool _removing = false;
  String? _failure;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _starter.addListener(_starterChanged);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _starter.removeListener(_starterChanged);
    super.dispose();
  }

  void _starterChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_starter.starting) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    _poll?.cancel();
    try {
      final status = await _linux.status();
      if (!mounted) return;
      setState(() => _status = status);
    } on BuiltinLinuxException catch (error) {
      if (!mounted) return;
      setState(() => _failure = error.message);
    }
    final interval = widget.pollInterval;
    if (interval != null && mounted) {
      _poll = Timer(interval, () {
        if (mounted) unawaited(_refresh());
      });
    }
  }

  _Status get _state {
    if (_starter.starting) return _Status.starting;
    if (_stopping) return _Status.stopping;
    final status = _status;
    if (status == null) return _Status.checking;
    if (!status.installed) return _Status.notSetUp;
    return status.serverRunning ? _Status.running : _Status.stopped;
  }

  Future<void> _start() async {
    setState(() => _failure = null);
    final failure = await _starter.start(widget.profile);
    if (!mounted) return;
    if (failure != null) {
      setState(
        () => _failure = _l10n.builtinServerStartFailed(failure.reason(_l10n)),
      );
    }
    await _refresh();
  }

  Future<void> _stop() async {
    setState(() {
      _stopping = true;
      _failure = null;
    });
    try {
      await _linux.stopServer();
    } on BuiltinLinuxException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    }
    if (!mounted) return;
    await _refresh();
    if (mounted) setState(() => _stopping = false);
  }

  Future<void> _showLog() async {
    String log;
    try {
      log = await _linux.serverLog();
    } on BuiltinLinuxException catch (error) {
      log = error.message;
    }
    if (!mounted) return;
    final l10n = _l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            key: const ValueKey('phone-server-log'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                l10n.phoneServerCardLogTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (log.trim().isEmpty)
                Text(l10n.phoneServerCardLogEmpty)
              else
                // Server output reads left to right in any interface.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TerminalView(output: log.trimRight(), tailLines: 200),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(PhoneServerAction action) async {
    final bytes = _status?.bytesUsed;
    final hand = widget.onAction;
    if (hand != null) {
      hand(action, bytes);
      return;
    }
    final removed = await runPhoneServerAction(
      context,
      action,
      connection: widget.connection,
      linux: _linux,
      profile: widget.profile,
      bytesUsed: bytes,
      // Busy only once confirmed: the question itself changes nothing.
      onRemoving: () {
        if (mounted) setState(() => _removing = true);
      },
    );
    if (!mounted) return;
    setState(() => _removing = false);
    if (removed) {
      widget.onRemoved?.call();
    } else {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine();
    final progress = engine?.progress;
    if (progress == null) return _build(context, null);
    return ValueListenableBuilder<SetupProgress>(
      valueListenable: progress,
      builder: (context, value, _) => _build(context, value),
    );
  }

  Widget _build(BuildContext context, SetupProgress? job) {
    final theme = Theme.of(context);
    final l10n = _l10n;
    final state = _state;
    final settingUp = job?.state == SetupState.running;
    final canContinue = job?.canContinue == true;
    final locked = _removing || state == _Status.starting || _stopping;

    // The status word says what is going on, so no button stands in for it
    // (standard §2): while it starts, stops or goes away there is simply no
    // Start, Stop or menu to press.
    final (label, tone) = _removing
        ? (l10n.phoneServerCardRemoving, AppStatusTone.progress)
        : settingUp
        ? (l10n.phoneServerCardSettingUp, AppStatusTone.progress)
        : switch (state) {
            _Status.checking => (
              l10n.phoneServerCardChecking,
              AppStatusTone.neutral,
            ),
            _Status.notSetUp => (
              l10n.phoneServerCardNotSetUp,
              AppStatusTone.neutral,
            ),
            _Status.stopped => (
              l10n.phoneServerCardStopped,
              AppStatusTone.neutral,
            ),
            _Status.starting => (
              l10n.phoneServerCardStarting,
              AppStatusTone.progress,
            ),
            _Status.stopping => (
              l10n.phoneServerCardStopping,
              AppStatusTone.progress,
            ),
            _Status.running => (l10n.phoneServerCardRunning, AppStatusTone.ok),
          };
    final dot = tone == AppStatusTone.neutral
        ? theme.colorScheme.outline
        : tone == AppStatusTone.progress
        ? theme.colorScheme.primary
        : AppTheme.statusColor(theme, tone);

    final runtime = _runtimeOf(widget.profile);
    final version = widget.profile.serverVersion?.trim();
    final what = version != null && version.isNotEmpty
        ? l10n.phoneServerCardVersion(version)
        : runtime == TermuxRuntime.openCode2
        ? l10n.setupRuntimeTwo
        : l10n.setupRuntimeOne;
    final bytes = _status?.bytesUsed;
    // Storage is measured in the background: nothing until a real figure.
    final detail = bytes != null && bytes > 0
        ? '$what · ${formatPhoneStorage(bytes)}'
        : what;

    final running = state == _Status.running;
    final installed = state != _Status.notSetUp && state != _Status.checking;
    final canOpen = running && !widget.connected && widget.onOpen != null;
    final hasEngine = _engine() != null;

    // One filled button at most: the one thing this server needs now.
    final KitAction? primary = locked
        ? null
        : settingUp
        ? KitAction(
            key: const ValueKey('phone-server-progress'),
            label: l10n.phoneServerCardShowProgress,
            onPressed: () => PhoneServerCardRoutes.openProgress(context),
          )
        : state == _Status.notSetUp
        ? KitAction(
            key: const ValueKey('phone-server-set-up'),
            label: l10n.phoneServerCardSetUp,
            onPressed: () => PhoneServerCardRoutes.openStart(context),
          )
        : state == _Status.stopped
        ? KitAction(
            key: const ValueKey('phone-server-start'),
            label: l10n.phoneServerCardStart,
            onPressed: _start,
          )
        : canOpen
        ? KitAction(
            key: const ValueKey('phone-server-open'),
            label: l10n.phoneServerCardOpen,
            onPressed: widget.onOpen,
          )
        : null;
    // A setup that stopped part way leads when nothing else does.
    final continueSetup = canContinue && !settingUp
        ? KitAction(
            key: const ValueKey('phone-server-continue'),
            label: l10n.phoneServerCardContinueSetup,
            onPressed: () => PhoneServerCardRoutes.openProgress(context),
          )
        : null;
    final lead = primary ?? (locked ? null : continueSetup);
    final tertiary = <KitAction>[
      if (running && !locked && !settingUp)
        KitAction(
          key: const ValueKey('phone-server-stop'),
          label: l10n.phoneServerCardStop,
          onPressed: _stop,
        ),
      if (continueSetup != null && lead != continueSetup) continueSetup,
      if (installed)
        KitAction(
          key: const ValueKey('phone-server-show-log'),
          label: l10n.phoneServerCardShowLog,
          onPressed: _showLog,
        ),
    ];
    // The terminal needs Ubuntu, not the server: it stays in the menu while
    // the server starts or stops, which is when a server that does not
    // answer leaves the person with no other way in.
    final terminalOnly = locked && installed && !_removing;
    final menu = PopupMenuButton<PhoneServerAction>(
      key: const ValueKey('phone-server-menu'),
      tooltip: l10n.phoneServerCardMore,
      enabled: terminalOnly || (!locked && state != _Status.checking),
      icon: const Icon(AppIconography.more),
      onSelected: (action) => unawaited(_menu(action)),
      itemBuilder: (context) => [
        if (installed)
          PopupMenuItem(
            key: const ValueKey('phone-server-terminal'),
            value: PhoneServerAction.terminal,
            child: Text(l10n.phoneServerCardTerminal),
          ),
        // Installing while a job runs would only queue behind it.
        if (!terminalOnly && hasEngine && installed && !settingUp) ...[
          PopupMenuItem(
            key: const ValueKey('phone-server-switch'),
            value: PhoneServerAction.switchRuntime,
            child: Text(
              l10n.phoneServerCardSwitchTo(
                runtime == TermuxRuntime.openCode2
                    ? l10n.setupRuntimeOne
                    : l10n.setupRuntimeTwo,
              ),
            ),
          ),
          PopupMenuItem(
            key: const ValueKey('phone-server-add-tools'),
            value: PhoneServerAction.addTools,
            child: Text(l10n.phoneServerCardAddTools),
          ),
          PopupMenuItem(
            key: const ValueKey('phone-server-update'),
            value: PhoneServerAction.update,
            child: Text(l10n.phoneServerCardUpdate),
          ),
        ],
        if (!terminalOnly)
          PopupMenuItem(
            key: const ValueKey('phone-server-remove'),
            value: PhoneServerAction.remove,
            enabled: !settingUp,
            child: Text(
              l10n.phoneServerCardRemove,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );

    final large = AppTheme.stackedActions(context);
    final status = Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('phone-server-dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              key: const ValueKey('phone-server-status'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );

    return Padding(
      key: const ValueKey('phone-server-card'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A row like every other (standard §6): what it is, what runs, and
          // its state at the line's end.
          MergeSemantics(
            child: KitRow(
              padding: const EdgeInsets.symmetric(vertical: 4),
              leading: KitRow.icon(context, AppIconography.phone),
              title: phoneServerDisplayName(
                widget.profile,
                l10n,
                among: widget.connection.store.profiles,
              ),
              titleKey: const ValueKey('phone-server-title'),
              titleMaxLines: large ? 3 : 1,
              supporting: TextSpan(text: detail),
              supportingKey: const ValueKey('phone-server-detail'),
              supportingMaxLines: large ? 3 : 1,
              // The status never takes the name's room at large text.
              trailing: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .4,
                  ),
                  child: status,
                ),
              ),
            ),
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _failure!,
                  key: const ValueKey('phone-server-failure'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.statusColor(theme, AppStatusTone.failure),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          KitActionBlock(primary: lead, tertiary: tertiary, menu: menu),
        ],
      ),
    );
  }
}
