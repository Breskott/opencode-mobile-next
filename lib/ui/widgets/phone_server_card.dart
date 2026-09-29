import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/app_exit_recovery.dart' show appLifecycleBridgeProvider;
import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../builtin/setup/phone_setup.dart';
import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/phone_host.dart' show PhoneHostKind;
import '../../state/profiles.dart';
import '../../state/queued_prompt_removal.dart'
    show QueuedPromptRemovalException, QueuedPromptRemovalPlan;
import '../../termux/bridge.dart' show TermuxRuntime;
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../screens/phone_setup/phone_setup_routes.dart';
import '../screens/terminal_screen.dart' show TerminalPage, TerminalSource;
import '../screens/this_phone_screen.dart' show openThisPhone;
import 'phone_server_consents.dart';
import 'product_states.dart';
import 'queued_prompt_move_sheet.dart' show showQueuedPromptMoveSheet;
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
enum PhoneServerAction {
  /// This phone: the page where everything about it is managed.
  manage,
  terminal,
  switchRuntime,
  addTools,
  update,

  /// Moves the prompts waiting for this phone's server into a conversation
  /// on the connected server (slice-queue-move), as the Servers rows do.
  moveQueued,
  remove,
}

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
  if (!looksLikeInAppServer(profile)) return plainServerName(profile.name);
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
///
/// A failure is one blocking alert that says what went wrong (KIT-15); a
/// removal that worked says so by the card leaving the list, so there is no
/// toast (KIT-34: a snack bar is only for Undo).
Future<bool> runPhoneServerAction(
  BuildContext context,
  PhoneServerAction action, {
  required ConnectionController connection,
  required BuiltinLinux linux,
  required ServerProfile profile,
  int? bytesUsed,
  VoidCallback? onRemoving,
  // True while a confirmed removal attempt runs, false once it ended (a
  // failed one leaves the question open with Try again).
  ValueChanged<bool>? onRemovingChanged,
}) async {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  Future<void> fail(List<String> messages) async {
    if (messages.isEmpty || !context.mounted) return;
    await showKitAlert(
      context,
      title: l10n.phoneServerCardFailedTitle,
      body: messages.join('\n'),
      icon: AppIconography.warning,
      alertKey: const ValueKey('phone-server-action-failed'),
    );
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
      await fail([l10n.phoneServerCardActionFailed(productErrorText(error))]);
      return;
    }
    if (context.mounted) await PhoneServerCardRoutes.openProgress(context);
  }

  switch (action) {
    case PhoneServerAction.manage:
      await openThisPhone(context, kind: PhoneHostKind.inApp);
      return false;
    case PhoneServerAction.terminal:
      // A shell in this phone's Linux: it needs no running server, so it is
      // the way in when the server is stopped or not answering.
      await pushKitPage<void>(
        context,
        (_) => TerminalPage(
          controller: connection,
          initialSource: TerminalSource.phone,
        ),
        settings: const RouteSettings(name: 'local-terminal'),
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
    case PhoneServerAction.moveQueued:
      await showQueuedPromptMoveSheet(
        context,
        connection: connection,
        source: profile,
        // An Undo that could not put every prompt back, in words; the
        // technical text only under Details.
        onProblem: (message, {details}) {
          if (!context.mounted) return;
          unawaited(
            showKitAlert(
              context,
              title: l10n.phoneServerCardFailedTitle,
              body: message,
              details: [
                if (details != null)
                  KitTechnicalValue(l10n.phoneServerCardErrorDetail, details),
              ],
              icon: AppIconography.warning,
              alertKey: const ValueKey('phone-server-action-failed'),
            ),
          );
        },
      );
      return false;
    case PhoneServerAction.remove:
      return _removePhoneServer(
        context,
        l10n: l10n,
        fail: fail,
        connection: connection,
        linux: linux,
        onRemoving: onRemoving,
        onRemovingChanged: onRemovingChanged,
      );
  }
}

/// What the person chose in [confirmPhoneRuntimeRemoval].
enum PhoneRuntimeRemoval {
  /// Closed the question; nothing changed.
  cancelled,

  /// The default: OpenCode, its tools and settings are gone; every project
  /// under /root/projects stayed on the phone (it lives outside Ubuntu, at
  /// `<filesDir>/projects`), and setting OpenCode up again shows them.
  keptProjects,

  /// The typed-name path: OpenCode and every project were deleted.
  deletedEverything;

  bool get removed => this != cancelled;
}

/// Asks how to remove OpenCode from this phone and removes it (P0.7).
///
/// The question says what survives: its confirm, "Remove OpenCode, keep my
/// projects", removes the runtime and tools but keeps the project folders,
/// and names the space it frees. "Delete everything" is the heavy path, so
/// it is the question's quiet alternative and names its own larger figure;
/// it opens a second question that stays disabled until
/// [BuiltinLinux.deletionConfirmationName] is typed.
///
/// Sizes are measured afresh ([BuiltinLinux.projectStorage]); a failed or
/// slow reading (many projects) leaves them out rather than holding the
/// question back or showing a made-up figure. [queuedPrompts] waiting for
/// this phone's server are said to move to Saved prompts (P7.2) on both
/// paths. Removal runs inside the question ([showKitConfirm]'s action): a
/// failure keeps it open with Try again (DATA-14). [beforeRemove] runs
/// first on every attempt; [onWorking] is true while an attempt runs and
/// false once it ended, so a failed attempt no longer reads as removing.
Future<PhoneRuntimeRemoval> confirmPhoneRuntimeRemoval(
  BuildContext context, {
  required BuiltinLinux linux,
  int queuedPrompts = 0,
  Future<void> Function()? beforeRemove,
  ValueChanged<bool>? onWorking,
  Duration measureTimeout = const Duration(seconds: 3),
}) async {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  BuiltinProjectStorage? storage;
  try {
    storage = await linux.projectStorage().timeout(measureTimeout);
  } catch (_) {
    storage = null; // Unknown: the copy leaves the figures out.
  }
  if (!context.mounted) return PhoneRuntimeRemoval.cancelled;

  String? size(int? bytes) =>
      bytes != null && bytes > 0 ? formatPhoneStorage(bytes) : null;
  final keepFrees = size(storage?.keepProjectsFreedBytes);
  final kept = size(storage?.projectsBytes);
  final allFrees = size(storage?.deleteEverythingFreedBytes);
  final queuedKept = [
    if (queuedPrompts > 0)
      KitConsequence(
        l10n.serversRemoveQueuedKept(queuedPrompts),
        mark: KitConsequenceMark.kept,
        key: const ValueKey('phone-server-remove-queued-kept'),
      ),
  ];

  Future<void> attempt(Future<void> Function() remove) async {
    onWorking?.call(true);
    try {
      await beforeRemove?.call();
      await remove();
    } finally {
      onWorking?.call(false);
    }
  }

  var deleteEverything = false;
  final keep = await showKitConfirm(
    context,
    title: l10n.phoneServerCardRemoveTitle,
    body: keepFrees != null
        ? l10n.removeFromPhoneKeepBody(keepFrees)
        : l10n.removeFromPhoneKeepBodyUnmeasured,
    confirmLabel: l10n.removeFromPhoneKeepConfirm,
    kind: KitConfirmKind.destructive,
    icon: AppIconography.delete,
    consequenceItems: [
      KitConsequence(
        l10n.removeFromPhoneKeepLost,
        mark: KitConsequenceMark.lost,
      ),
      KitConsequence(
        kept != null
            ? l10n.removeFromPhoneKeepKeptSize(kept)
            : l10n.removeFromPhoneKeepKept,
        mark: KitConsequenceMark.kept,
        key: const ValueKey('phone-server-remove-kept'),
      ),
      ...queuedKept,
    ],
    alternative: KitAction(
      key: const ValueKey('phone-server-remove-everything'),
      label: allFrees != null
          ? l10n.removeFromPhoneDeleteAllChoiceSize(allFrees)
          : l10n.removeFromPhoneDeleteAllChoice,
      destructive: true,
      onPressed: () => deleteEverything = true,
    ),
    // The keep path: the bridge's safe default (uninstall == remove()).
    action: () => attempt(linux.uninstall),
    sheetKey: const ValueKey('phone-server-remove-sheet'),
    confirmKey: const ValueKey('phone-server-remove-confirm'),
  );
  if (keep) return PhoneRuntimeRemoval.keptProjects;
  if (!deleteEverything || !context.mounted) {
    return PhoneRuntimeRemoval.cancelled;
  }
  final deleted = await showKitConfirm(
    context,
    title: l10n.removeFromPhoneDeleteTitle,
    body: allFrees != null
        ? l10n.removeFromPhoneDeleteBody(allFrees)
        : l10n.removeFromPhoneDeleteBodyUnmeasured,
    confirmLabel: l10n.removeFromPhoneDeleteAll,
    kind: KitConfirmKind.destructive,
    icon: AppIconography.delete,
    consequenceItems: [
      KitConsequence(
        l10n.removeFromPhoneDeleteLost,
        mark: KitConsequenceMark.lost,
      ),
      ...queuedKept,
    ],
    // The kit keeps the confirm disabled until the exact name is typed;
    // native code checks it again.
    typedName: BuiltinLinux.deletionConfirmationName,
    action: () => attempt(
      () => linux.remove(
        alsoDeleteProjects: true,
        confirmationName: BuiltinLinux.deletionConfirmationName,
      ),
    ),
    sheetKey: const ValueKey('phone-server-delete-everything-sheet'),
    confirmKey: const ValueKey('phone-server-delete-everything-confirm'),
  );
  return deleted
      ? PhoneRuntimeRemoval.deletedEverything
      : PhoneRuntimeRemoval.cancelled;
}

/// Asks with [confirmPhoneRuntimeRemoval] and removes OpenCode, then
/// forgets the saved entries: a "This phone" entry left behind would point
/// at nothing and could only fail. The saved entries stay until removal
/// worked; setting up again saves a new one and finds the kept projects.
Future<bool> _removePhoneServer(
  BuildContext context, {
  required AppLocalizations l10n,
  required Future<void> Function(List<String>) fail,
  required ConnectionController connection,
  required BuiltinLinux linux,
  VoidCallback? onRemoving,
  ValueChanged<bool>? onRemovingChanged,
}) async {
  // Queued prompts for this phone's server are kept in Saved prompts (P7.2).
  var queued = 0;
  for (final profile in connection.store.profiles) {
    if (looksLikeInAppServer(profile)) {
      queued += connection.queuedPromptCountForProfile(profile.id);
    }
  }
  final outcome = await confirmPhoneRuntimeRemoval(
    context,
    linux: linux,
    queuedPrompts: queued,
    onWorking: (working) {
      if (working) onRemoving?.call();
      onRemovingChanged?.call(working);
    },
    // Leave the server before it disappears, so the app does not spend the
    // next minute reconnecting to something that is gone.
    beforeRemove: () async {
      if (connection.api != null && looksLikeInAppServer(connection.profile)) {
        await connection.disconnect(keepActive: true);
      }
    },
  );
  if (!outcome.removed) return false;
  final saved = [
    for (final profile in connection.store.profiles)
      if (looksLikeInAppServer(profile)) profile,
  ];
  final problems = <String>[];
  for (final profile in saved) {
    try {
      // Counted at the last moment, so every prompt still queued is kept.
      // An unreadable queue has nothing to keep; removal goes on as before.
      QueuedPromptRemovalPlan? plan;
      try {
        plan = connection.inspectQueuedPromptsForRemoval(profile.id);
      } catch (_) {
        plan = null;
      }
      final result = await connection.deleteProfileAndLocalData(
        profile.id,
        queuedPrompts: plan,
        keepQueuedPrompts: true,
      );
      final partial = result.partialDeletionMessage;
      if (partial != null) problems.add(partial);
    } on QueuedPromptRemovalException catch (error) {
      problems.add(
        error.changed
            ? l10n.serversRemoveQueuedChanged(profile.name)
            : l10n.serversRemoveQueuedNotKept(profile.name),
      );
    } catch (error) {
      problems.add(l10n.phoneServerCardActionFailed(productErrorText(error)));
    }
  }
  // OpenCode itself is gone either way; what could not be cleared is said.
  await fail(problems);
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

/// "This phone": OpenCode inside this app, as one row on its own panel
/// (visual language §5), with the one act it needs now under it.
///
/// Kit only (shared-phone-1): a [KitRow] (the phone tile, filled when it is
/// the server in use, and "Connected · " leading its line; the state word
/// at its end), and every other act in the row's menu ([KitRowMenu] and
/// long-press), the same shape as [LocalServerRow]. The row's tap connects
/// when it can, so no button repeats it; a filled button shows only for
/// what the server needs before it can be used (Set up, Start OpenCode,
/// Continue setup, Show progress), aligned with the row's words. Each act
/// names what it acts on ("Stop OpenCode on this phone", "Disconnect from
/// this phone").
///
/// States: checking, not set up, stopped, starting, stopping, running,
/// setting up, removing, failed (the failure in words under the row).
class PhoneServerCard extends ConsumerStatefulWidget {
  const PhoneServerCard({
    super.key,
    required this.connection,
    required this.profile,
    this.connected = false,
    this.onOpen,
    this.onAction,
    this.onRemoved,
    this.onDisconnect,
    this.linux,
    this.pollInterval = const Duration(seconds: 5),
  }) : asRow = false;

  /// The same server as one row of a list's [KitRowGroup] (the Servers
  /// list's one urgency-ordered group), in place of the card's own panel:
  /// the act it needs now (Set up, Start OpenCode, Continue setup, Show
  /// progress) is the row's trailing button, its state word joins the row's
  /// line, and every other act stays in the row menu. The caller puts it in
  /// its group; the row draws no panel of its own.
  const PhoneServerCard.row({
    super.key,
    required this.connection,
    required this.profile,
    this.connected = false,
    this.onOpen,
    this.onAction,
    this.onRemoved,
    this.onDisconnect,
    this.linux,
    this.pollInterval = const Duration(seconds: 5),
  }) : asRow = true;

  final ConnectionController connection;

  /// Drawn as a row for a caller's group ([PhoneServerCard.row]).
  final bool asRow;

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

  /// Leaves this server while it is the one in use ([connected]): the
  /// menu's "Disconnect from This phone". The host confirms and leaves
  /// (the switcher closes first); null leaves the item out. The server
  /// keeps running either way.
  final VoidCallback? onDisconnect;

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
    widget.connection.addListener(_connectionChanged);
    _queue = _readQueue();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(PhoneServerCard old) {
    super.didUpdateWidget(old);
    if (old.connection != widget.connection) {
      old.connection.removeListener(_connectionChanged);
      widget.connection.addListener(_connectionChanged);
    }
    _queue = _readQueue();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _starter.removeListener(_starterChanged);
    widget.connection.removeListener(_connectionChanged);
    super.dispose();
  }

  /// Prompts waiting for this server and the saved id of the server they
  /// can move to, as last read.
  late ({int count, String? destination}) _queue;

  /// The same reading as a Servers row (slice-queue-move): prompts queued
  /// for this server while it cannot send them (never while it is the one
  /// in use, never in an isolated view), and the connected server they can
  /// move to.
  ({int count, String? destination}) _readQueue() {
    final connection = widget.connection;
    if (connection.isIsolated ||
        (connection.api != null &&
            connection.profile?.id == widget.profile.id)) {
      return (count: 0, destination: null);
    }
    final count = connection.queuedPromptCountForProfile(widget.profile.id);
    final target = connection.queuedPromptMoveDestination;
    return (
      count: count,
      destination:
          count == 0 || target == null || target.id == widget.profile.id
          ? null
          : target.id,
    );
  }

  /// The server [_queue]'s prompts can move to, by name; null: none.
  String? _moveDestinationName(AppLocalizations l10n) {
    final id = _queue.destination;
    if (id == null) return null;
    final profiles = widget.connection.store.profiles;
    final target = profiles.where((p) => p.id == id).firstOrNull;
    return target == null
        ? null
        : serverDisplayName(target, l10n, among: profiles);
  }

  /// The connection speaks often (streams, status); the card redraws only
  /// when what it says about waiting prompts changed.
  void _connectionChanged() {
    if (!mounted) return;
    final next = _readQueue();
    if (next == _queue) return;
    setState(() => _queue = next);
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
      setState(() => _failure = productErrorText(error));
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
    // The first start is the moment keeping it alive matters (P6.7): asked
    // once per server, nothing on later starts.
    if (failure == null && mounted) {
      await askPhoneServerConsents(
        context,
        connection: widget.connection,
        bridge: ref.read(appLifecycleBridgeProvider),
        profileId: widget.profile.id,
      );
    }
  }

  Future<void> _stop() async {
    setState(() {
      _stopping = true;
      _failure = null;
    });
    try {
      await _linux.stopServer();
    } on BuiltinLinuxException catch (error) {
      if (mounted) setState(() => _failure = productErrorText(error));
    }
    if (!mounted) return;
    await _refresh();
    if (mounted) setState(() => _stopping = false);
  }

  /// The server's log in the one log view (KIT-31): redacted, left to
  /// right, re-read while the sheet is open and the server runs.
  Future<void> _showLog() async {
    final lines = KitLogBuffer();
    Future<void> read() async {
      String log;
      try {
        log = await _linux.serverLog();
      } on BuiltinLinuxException catch (error) {
        log = error.message;
      }
      lines.replaceText(log.trimRight());
    }

    await read();
    if (!mounted) {
      lines.dispose();
      return;
    }
    final l10n = _l10n;
    final running = _state == _Status.running;
    await showKitSheet<void>(
      context,
      title: l10n.builtinServerLogTitle,
      icon: AppIconography.text,
      height: KitSheetHeight.full,
      body: (_) => KitLogPanel(
        lines: lines,
        panelKey: const ValueKey('phone-server-log'),
        title: l10n.phoneServerCardLogTitle,
        emptyText: l10n.phoneServerCardLogEmpty,
        live: running,
        onRefresh: running ? read : null,
      ),
    );
    lines.dispose();
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
      // Busy only while a confirmed attempt runs: the question itself
      // changes nothing, and a failed attempt is no longer removing.
      onRemovingChanged: (working) {
        if (mounted) setState(() => _removing = working);
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
    final l10n = _l10n;
    final tokens = KitTokens.of(context);
    final state = _state;
    final settingUp = job?.state == SetupState.running;
    final canContinue = job?.canContinue == true;
    final locked = _removing || state == _Status.starting || _stopping;
    final name = phoneServerDisplayName(
      widget.profile,
      l10n,
      among: widget.connection.store.profiles,
    );
    // Inside a sentence the default name is lower case ("Disconnect from
    // this phone"); a name the person gave stays as it is.
    final sentenceName = name.startsWith(l10n.phoneServerCardTitle)
        ? name.replaceFirst(
            l10n.phoneServerCardTitle,
            l10n.phoneServerNameInSentence,
          )
        : name;

    // The status word says what is going on, so no button stands in for it
    // (standard §2): while it starts, stops or goes away there is simply no
    // Start, Stop or menu to press.
    final label = _removing
        ? l10n.phoneServerCardRemoving
        : settingUp
        ? l10n.phoneServerCardSettingUp
        : switch (state) {
            _Status.checking => l10n.phoneServerCardChecking,
            _Status.notSetUp => l10n.phoneServerCardNotSetUp,
            _Status.stopped => l10n.phoneServerCardStopped,
            _Status.starting => l10n.phoneServerCardStarting,
            _Status.stopping => l10n.phoneServerCardStopping,
            _Status.running => l10n.phoneServerCardRunning,
          };
    final working = _removing || settingUp || locked;

    final runtime = _runtimeOf(widget.profile);
    final version = widget.profile.serverVersion?.trim();
    final what = version != null && version.isNotEmpty
        ? l10n.phoneServerCardVersion(version)
        : runtime == TermuxRuntime.openCode2
        ? l10n.setupRuntimeTwo
        : l10n.setupRuntimeOne;
    // What it runs, never its storage: the line must fit, and the size is
    // said where it matters (removing it frees the space).
    final detail = what;

    final queue = _queue;
    final moveTo = _moveDestinationName(l10n);
    final running = state == _Status.running;
    final installed = state != _Status.notSetUp && state != _Status.checking;
    final canOpen = running && !widget.connected && widget.onOpen != null;
    final hasEngine = _engine() != null;

    // One filled button at most, and only for what the server needs before
    // it can be used: the row's own tap connects a running one.
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
            label: l10n.phoneServerCardStartOpenCode,
            onPressed: _start,
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

    // The terminal needs Ubuntu, not the server: it stays in the menu while
    // the server starts or stops, which is when a server that does not
    // answer leaves the person with no other way in.
    final terminalOnly = locked && installed && !_removing;
    final menuOpen = terminalOnly || (!locked && state != _Status.checking);
    void choose(PhoneServerAction action) => unawaited(_menu(action));
    final items = <KitMenuItem>[
      if (installed && !terminalOnly)
        KitMenuItem(
          key: const ValueKey('phone-server-manage'),
          label: l10n.thisPhoneManage,
          icon: AppIconography.phone,
          onSelected: () => choose(PhoneServerAction.manage),
        ),
      // Prompts waiting for this server go to the one in use, named (the
      // Servers row's act, slice-queue-move).
      if (!terminalOnly && !_removing && moveTo != null)
        KitMenuItem(
          key: const ValueKey('phone-server-move-queued'),
          label: l10n.serverRowMoveQueued(queue.count, moveTo),
          icon: AppIconography.forward,
          onSelected: () => choose(PhoneServerAction.moveQueued),
        ),
      // A setup that stopped part way, when a filled button leads already.
      if (!terminalOnly && continueSetup != null && lead != continueSetup)
        KitMenuItem(
          key: const ValueKey('phone-server-continue'),
          label: l10n.phoneServerCardContinueSetup,
          onSelected: () => PhoneServerCardRoutes.openProgress(context),
        ),
      if (!terminalOnly && installed)
        KitMenuItem(
          key: const ValueKey('phone-server-show-log'),
          label: l10n.phoneServerCardShowServerLog,
          icon: AppIconography.text,
          onSelected: () => unawaited(_showLog()),
        ),
      if (installed)
        KitMenuItem(
          key: const ValueKey('phone-server-terminal'),
          label: l10n.phoneServerCardOpenTerminal,
          icon: AppIconography.terminal,
          onSelected: () => choose(PhoneServerAction.terminal),
        ),
      // Installing while a job runs would only queue behind it.
      if (!terminalOnly && hasEngine && installed && !settingUp) ...[
        KitMenuItem(
          key: const ValueKey('phone-server-switch'),
          label: l10n.phoneServerCardSwitchTo(
            runtime == TermuxRuntime.openCode2
                ? l10n.setupRuntimeOne
                : l10n.setupRuntimeTwo,
          ),
          onSelected: () => choose(PhoneServerAction.switchRuntime),
        ),
        KitMenuItem(
          key: const ValueKey('phone-server-add-tools'),
          label: l10n.phoneServerCardAddTools,
          onSelected: () => choose(PhoneServerAction.addTools),
        ),
        KitMenuItem(
          key: const ValueKey('phone-server-update'),
          label: l10n.phoneServerCardUpdate,
          onSelected: () => choose(PhoneServerAction.update),
        ),
      ],
      // Leaving the server in use lives on its own row, not as a stray row
      // of the list around it (owner rule 2026-09-27).
      if (widget.connected && widget.onDisconnect != null && !_removing)
        KitMenuItem(
          key: const ValueKey('phone-server-disconnect'),
          label: l10n.phoneServerCardDisconnect(sentenceName),
          icon: AppIconography.unlink,
          onSelected: widget.onDisconnect!,
        ),
      // Stopping keeps the saved server; it leaves the menu's end to the
      // one act that deletes.
      if (running && !locked && !settingUp)
        KitMenuItem(
          key: const ValueKey('phone-server-stop'),
          label: l10n.phoneServerCardStopOpenCode,
          icon: AppIconography.stopCircle,
          onSelected: () => unawaited(_stop()),
        ),
      if (!terminalOnly)
        KitMenuItem(
          key: const ValueKey('phone-server-remove'),
          label: l10n.phoneServerCardRemove,
          destructive: true,
          enabled: !settingUp,
          onSelected: () => choose(PhoneServerAction.remove),
        ),
    ];
    final menu = menuOpen ? items : const <KitMenuItem>[];

    // At large text the state word moves under the name (KitRow's
    // `below`), so the name keeps its width.
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    final status = KitText(
      label,
      key: const ValueKey('phone-server-status'),
      role: KitTextRole.secondary,
      tone: running && !working ? KitTextTone.success : KitTextTone.secondary,
      maxLines: 2,
    );
    if (widget.asRow) {
      return _row(
        context,
        name: name,
        label: label,
        detail: detail,
        lead: lead,
        menu: menu,
        working: working,
        locked: locked,
        canOpen: canOpen,
        large: large,
      );
    }
    // The one button sits with the row's words, inside the row: no hairline
    // divides it from the server it acts on.
    final actions = KitActionBlock(primary: lead);
    final failure = _failure;
    final below = <Widget>[
      if (large) status,
      // The failure in words, in text1 (LOOK-5: the error tone marks acts
      // that lose data, never a failure state).
      if (failure != null)
        KitText(
          failure,
          key: const ValueKey('phone-server-failure'),
          role: KitTextRole.secondary,
          tone: KitTextTone.primary,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      if (!actions.isEmpty)
        Padding(
          padding: EdgeInsetsDirectional.only(top: tokens.space1),
          child: actions,
        ),
    ];
    final trailing = <Widget>[
      // The state word ends where the row's words end (the row's own end
      // inset), not against the card's edge; before the ⋮ the button's
      // own padding gives that room.
      if (!large)
        menu.isEmpty
            ? Padding(
                padding: EdgeInsetsDirectional.only(end: tokens.space3),
                child: status,
              )
            : status,
      if (menu.isNotEmpty)
        KitRowMenu(
          key: const ValueKey('phone-server-menu'),
          tooltip: l10n.phoneServerCardMore,
          menuLabel: name,
          items: menu,
        ),
    ];

    final row = Semantics(
      container: true,
      selected: widget.connected,
      liveRegion: true,
      child: KitRow(
        leading: working
            ? const KitStatusMark(state: KitMarkState.working)
            : KitRowIcon(AppIconography.phone, current: widget.connected),
        title: name,
        titleKey: const ValueKey('phone-server-title'),
        titleMaxLines: large ? 3 : 1,
        supporting: TextSpan(
          children: [
            if (widget.connected)
              kitCurrentSpan(context, l10n.serverRowConnected),
            ?_queuedSpan(context, l10n, queue.count),
            TextSpan(text: detail),
          ],
        ),
        supportingKey: const ValueKey('phone-server-detail'),
        // Waiting prompts lead the line; what it runs wraps under them.
        supportingMaxLines: large ? 3 : (queue.count > 0 ? 2 : 1),
        below: below.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, line) in below.indexed) ...[
                    if (i > 0) SizedBox(height: tokens.space1),
                    line,
                  ],
                ],
              ),
        // The row's tap does the one likely thing: connect when it can.
        onTap: canOpen && !locked ? widget.onOpen : null,
        menu: menu,
        menuLabel: name,
        trailing: trailing.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: trailing),
      ),
    );

    return KitRowGroup(
      key: const ValueKey('phone-server-card'),
      margin: EdgeInsets.zero,
      children: [row],
    );
  }

  /// "2 prompts waiting to send · " in the strong label weight, as a
  /// Servers row says it; null when none wait.
  TextSpan? _queuedSpan(BuildContext context, AppLocalizations l10n, int n) =>
      n > 0
      ? TextSpan(
          text: '${l10n.serverRowQueuedWaiting(n)} · ',
          style: KitText.styleOf(
            context,
            KitTextRole.label,
            tone: KitTextTone.primary,
          ),
        )
      : null;

  /// [PhoneServerCard.row]: the shape of a [LocalServerRow]. The line reads
  /// "Connected · OpenCode 2 · Running"; Start or Set up is a small trailing
  /// button (under the line at large text, so the name keeps its width);
  /// the ⋮ and long-press hold the rest.
  Widget _row(
    BuildContext context, {
    required String name,
    required String label,
    required String detail,
    required KitAction? lead,
    required List<KitMenuItem> menu,
    required bool working,
    required bool locked,
    required bool canOpen,
    required bool large,
  }) {
    final l10n = _l10n;
    final failure = _failure;
    // Start and Set up are short and sit at the row's end, like a
    // LocalServerRow's Start; the row itself names what they act on, so
    // Start says only "Start". The longer setup acts (Continue setup, Show
    // progress) go under the line, as does any act at large text.
    final key = lead?.key;
    final short =
        key == const ValueKey('phone-server-start') ||
        key == const ValueKey('phone-server-set-up');
    final Widget? act = lead == null
        ? null
        : KitButton.tertiary(
            key: key,
            label: key == const ValueKey('phone-server-start')
                ? l10n.phoneServerStart
                : lead.label,
            onPressed: lead.onPressed,
          );
    final atEnd = short && !large;
    final below = <Widget>[
      // The failure in words, in text1 (LOOK-5).
      if (failure != null)
        KitText(
          failure,
          key: const ValueKey('phone-server-failure'),
          role: KitTextRole.secondary,
          tone: KitTextTone.primary,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      if (act != null && !atEnd) KitInset(child: act),
    ];
    final trailing = <Widget>[
      if (act != null && atEnd) act,
      if (menu.isNotEmpty)
        KitRowMenu(
          key: const ValueKey('phone-server-menu'),
          tooltip: l10n.phoneServerCardMore,
          menuLabel: name,
          items: menu,
        ),
    ];
    return KeyedSubtree(
      key: const ValueKey('phone-server-row'),
      child: Semantics(
        container: true,
        selected: widget.connected,
        liveRegion: true,
        child: KitRow(
          leading: working
              ? const KitStatusMark(state: KitMarkState.working)
              : KitRowIcon(AppIconography.phone, current: widget.connected),
          title: name,
          titleKey: const ValueKey('phone-server-title'),
          titleMaxLines: large ? 3 : 1,
          supporting: TextSpan(
            children: [
              if (widget.connected)
                kitCurrentSpan(context, l10n.serverRowConnected),
              ?_queuedSpan(context, l10n, _queue.count),
              TextSpan(text: detail),
              TextSpan(text: ' · $label'),
            ],
          ),
          supportingKey: const ValueKey('phone-server-detail'),
          supportingMaxLines: large ? 3 : (_queue.count > 0 ? 2 : 1),
          below: below.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: below,
                ),
          onTap: canOpen && !locked ? widget.onOpen : null,
          menu: menu,
          menuLabel: name,
          trailing: trailing.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        ),
      ),
    );
  }
}
