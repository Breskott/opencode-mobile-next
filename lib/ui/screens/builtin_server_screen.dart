import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart' show TermuxRuntime;
import '../app_theme.dart';
import '../kit/kit.dart';
import 'keep_running_screen.dart';

/// "Run OpenCode inside the app — no Termux" (experimental, GitHub issue #87).
///
/// Four steps, each driven by one call on [BuiltinLinux]: download Ubuntu,
/// install OpenCode inside it, start the server on 127.0.0.1:4097, connect.
/// Nothing here touches Termux: the server is a child of this app's process,
/// and its profile's port keeps every Termux-only code path away from it.
///
/// Made kit-only with the least change (screen-phone-1): a [KitScreen] page,
/// the steps on one [KitSurface] panel with a [KitStatusMark] each, the log
/// in a [KitSheet] with a [KitLogPanel], and Remove through
/// [showKitConfirm]. The page itself goes away into phone setup's screen A.
// revamp: merge-into:phone-setup-start (slice-P1.3)
class BuiltinServerScreen extends ConsumerStatefulWidget {
  const BuiltinServerScreen({
    super.key,
    this.linux,
    this.pollInterval = const Duration(seconds: 2),
    this.readyTimeout = const Duration(seconds: 90),
  });

  /// Tests pass a fake; the app uses the real channel.
  final BuiltinLinux? linux;

  /// How often status is re-read while Ubuntu installs or the server starts.
  final Duration pollInterval;

  /// How long a started server has to answer before the start counts as
  /// failed. The first start of OpenCode 1 under proot on a slow phone takes
  /// tens of seconds.
  final Duration readyTimeout;

  @override
  ConsumerState<BuiltinServerScreen> createState() =>
      _BuiltinServerScreenState();
}

/// Opens the built-in server setup. Every entry point goes through here and
/// hides itself when [BuiltinLinux.supported] is false.
///
/// Superseded by phone setup v2: first setup is screens A–C and management
/// is the "This phone" card (`phone_server_card.dart`). It stays only as the
/// fallback the opening card offers when the in-app server will not start
/// before the app is connected, where no card is shown; delete it once screen
/// B's "Continue setup" covers that repair.
Future<void> openBuiltinServerScreen(BuildContext context) =>
    pushKitPage<void>(context, (_) => const BuiltinServerScreen());

/// Which OpenCode the built-in Ubuntu runs, kept across visits.
const builtinRuntimePrefKey = 'builtin_linux_runtime';

enum _Step { idle, running, done, error }

class _BuiltinServerScreenState extends ConsumerState<BuiltinServerScreen> {
  late final BuiltinLinux _linux =
      widget.linux ?? ref.read(builtinLinuxProvider);

  /// The failed OpenCode install's output, for its log panel.
  final _openCodeLog = KitLogBuffer();

  BuiltinLinuxStatus? _status;
  String? _statusError;
  Timer? _poll;

  TermuxRuntime _runtime = TermuxRuntime.openCode1;
  String? _installedVersion;
  bool _checkingVersion = false;
  bool _installingOpenCode = false;
  String? _openCodeError;
  String _openCodeOutput = '';

  bool _starting = false;
  String? _startError;
  bool _stopping = false;
  bool _connecting = false;
  String? _connectError;
  bool _removing = false;

  /// Remove finished: said once in place (a snackbar is only for Undo,
  /// KIT-34, and Ubuntu cannot be put back).
  bool _removed = false;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    final saved = ref
        .read(bootstrapProvider)
        .store
        .prefs
        .getString(builtinRuntimePrefKey);
    _runtime = saved == TermuxRuntime.openCode2.wireName
        ? TermuxRuntime.openCode2
        : TermuxRuntime.openCode1;
    if (BuiltinLinux.supported) unawaited(_refresh(checkVersion: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _openCodeLog.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool checkVersion = false}) async {
    try {
      final status = await _linux.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusError = null;
      });
      _schedulePoll();
      if (checkVersion && status.installed) await _checkVersion();
    } on BuiltinLinuxException catch (error) {
      if (!mounted) return;
      setState(() => _statusError = error.message);
    }
  }

  /// Polls only while Android is working on its own (the Ubuntu download);
  /// every other step awaits its own call.
  void _schedulePoll() {
    _poll?.cancel();
    if (_status?.phase != BuiltinLinuxPhase.installing) return;
    _poll = Timer(widget.pollInterval, () {
      if (mounted) unawaited(_refresh(checkVersion: true));
    });
  }

  Future<void> _checkVersion() async {
    if (_checkingVersion) return;
    setState(() => _checkingVersion = true);
    final runtime = _runtime;
    String? version;
    try {
      final result = await _linux.run(
        BuiltinLinux.versionScript(runtime),
        timeout: const Duration(seconds: 60),
      );
      if (result.ok) version = BuiltinLinux.parseVersion(result.output);
    } on BuiltinLinuxException {
      // Unknown reads as "not installed": the install step stays offered,
      // and installing again over a working copy is harmless.
    }
    if (!mounted) return;
    setState(() {
      _checkingVersion = false;
      if (runtime == _runtime) _installedVersion = version;
    });
  }

  Future<void> _installUbuntu() async {
    setState(() => _statusError = null);
    try {
      await _linux.installUbuntu();
    } on BuiltinLinuxException catch (error) {
      if (!mounted) return;
      setState(() => _statusError = error.message);
      return;
    }
    await _refresh(checkVersion: true);
  }

  Future<void> _selectRuntime(TermuxRuntime runtime) async {
    if (runtime == _runtime) return;
    setState(() {
      _runtime = runtime;
      _installedVersion = null;
      _openCodeError = null;
      _openCodeOutput = '';
    });
    await ref
        .read(bootstrapProvider)
        .store
        .prefs
        .setString(builtinRuntimePrefKey, runtime.wireName);
    await _checkVersion();
  }

  Future<void> _installOpenCode() async {
    setState(() {
      _installingOpenCode = true;
      _openCodeError = null;
      _openCodeOutput = '';
    });
    try {
      final result = await _linux.run(
        BuiltinLinux.installOpenCodeScript(runtime: _runtime),
        // apt plus npm over a phone connection; the Termux path allows as
        // long. The call blocks a background thread, not the UI.
        timeout: const Duration(minutes: 30),
      );
      if (!mounted) return;
      if (!result.ok) {
        _openCodeLog.replaceText(result.output);
        setState(() {
          _openCodeError = _l10n.builtinServerOpenCodeFailed(result.exitCode);
          _openCodeOutput = result.output;
        });
        return;
      }
      setState(() => _openCodeOutput = result.output);
    } on BuiltinLinuxException catch (error) {
      if (!mounted) return;
      setState(() => _openCodeError = error.message);
      return;
    } finally {
      if (mounted) setState(() => _installingOpenCode = false);
    }
    await _checkVersion();
  }

  ServerFlavor get _flavor =>
      _runtime == TermuxRuntime.openCode2 ? ServerFlavor.v2 : ServerFlavor.v1;

  String get _runtimeName => _runtime == TermuxRuntime.openCode2
      ? _l10n.setupRuntimeTwo
      : _l10n.setupRuntimeOne;

  ServerProfile? _existingProfile() =>
      findBuiltinProfile(ref.read(bootstrapProvider).store, _flavor);

  Future<ServerProfile> _ensureProfile() => ensureBuiltinProfile(
    ref.read(bootstrapProvider).store,
    flavor: _flavor,
    name: _l10n.builtinServerProfileName(_runtimeName),
    version: _installedVersion,
  );

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startError = null;
      _connectError = null;
    });
    final profile = await _ensureProfile();
    // The same start the opening card uses, so the two never differ.
    final failed = await startBuiltinServer(
      linux: _linux,
      profile: profile,
      readyTimeout: widget.readyTimeout,
      pollInterval: widget.pollInterval,
      stillWanted: () => mounted,
    );
    if (!mounted) return;
    final failure = failed?.reason(_l10n);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _startError = failure == null
          ? null
          : _l10n.builtinServerStartFailed(failure);
    });
    if (failure == null) await _connect(profile);
  }

  Future<void> _stop() async {
    setState(() => _stopping = true);
    try {
      await _linux.stopServer();
    } on BuiltinLinuxException catch (error) {
      if (mounted) setState(() => _startError = error.message);
    }
    if (!mounted) return;
    await _refresh();
    if (mounted) setState(() => _stopping = false);
  }

  Future<void> _connect([ServerProfile? known]) async {
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    final connection = ref.read(connProvider);
    final profile = known ?? await _ensureProfile();
    if (!mounted) return;
    await connection.connect(profile);
    if (!mounted) return;
    if (!connection.hasConnectedServer) {
      setState(() {
        _connecting = false;
        _connectError = _l10n.builtinServerConnectFailed(
          connection.lastError ?? _l10n.builtinServerStopped,
        );
      });
      return;
    }
    setState(() => _connecting = false);
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  Future<void> _showLog() async {
    String log = '';
    String? readError;
    try {
      log = await _linux.serverLog();
    } on BuiltinLinuxException catch (error) {
      readError = error.message;
    }
    if (!mounted) return;
    final l10n = _l10n;
    final running = _status?.serverRunning == true;
    final canStart = !running && _installedVersion != null && !_busy;
    await showKitSheet<void>(
      context,
      title: l10n.builtinServerLogTitle,
      icon: AppIconography.article,
      height: KitSheetHeight.half,
      // A log that ends because the server stopped offers the start right
      // there (map actionsMissing "Restart when the log ends in a crash").
      tertiary: [
        if (canStart)
          KitAction(
            key: const Key('builtin-server-log-start'),
            label: l10n.builtinServerStartAction,
            icon: AppIconography.play,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_start());
            },
          ),
      ],
      body: (_) => _ServerLogBody(
        linux: _linux,
        initial: log,
        readError: readError,
        running: running,
      ),
    );
  }

  Future<void> _remove() async {
    setState(() => _removed = false);
    var removed = false;
    // Uninstall runs inside the question: it shows it is working, and a
    // failure keeps it open with Try again (map statesMissing "remove
    // failed", DATA-14).
    final confirmed = await showKitConfirm(
      context,
      title: _l10n.builtinServerRemoveTitle,
      body: _l10n.builtinServerRemoveBody,
      confirmLabel: _l10n.builtinServerRemove,
      icon: AppIconography.delete,
      kind: KitConfirmKind.destructive,
      confirmKey: const Key('builtin-server-remove-confirm'),
      action: () async {
        if (mounted) setState(() => _removing = true);
        try {
          await _linux.uninstall();
          removed = true;
        } finally {
          if (mounted) setState(() => _removing = false);
        }
      },
    );
    if (!confirmed || !removed || !mounted) return;
    _openCodeLog.clear();
    setState(() {
      _installedVersion = null;
      _openCodeOutput = '';
      _openCodeError = null;
      _startError = null;
      _removed = true;
    });
    await _refresh();
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return unit == 0
        ? '$bytes B'
        : '${value.toStringAsFixed(1)} ${units[unit]}';
  }

  bool get _busy =>
      _installingOpenCode || _starting || _stopping || _connecting || _removing;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    if (!BuiltinLinux.supported) {
      return KitScreen(
        topBar: KitTopBar(title: l10n.builtinServerTitle),
        body: KitStateView(
          key: const Key('builtin-server-unsupported'),
          icon: AppIconography.phone,
          title: l10n.builtinServerAndroidOnly,
        ),
      );
    }
    final tokens = KitTokens.of(context);
    final status = _status;
    final ubuntuReady = status?.installed == true;
    final ubuntuInstalling = status?.phase == BuiltinLinuxPhase.installing;
    final ubuntuFailed = status?.phase == BuiltinLinuxPhase.failed;
    final openCodeReady = ubuntuReady && _installedVersion != null;
    final running = status?.serverRunning == true;
    final connection = ref.watch(connProvider);
    final connected =
        connection.hasConnectedServer &&
        BuiltinLinux.managesServerUrl(connection.profile?.baseUrl);
    final statusError = _statusError;
    final openCodeError = _openCodeError;
    final startError = _startError;
    final connectError = _connectError;

    Widget muted(String text) =>
        KitText(text, role: KitTextRole.secondary, tone: KitTextTone.secondary);
    Widget gap() => SizedBox(height: tokens.space3);
    Widget failure(String message) => KitNotice.error(message: message);

    final steps = <Widget>[
      _StepTile(
        number: 1,
        title: l10n.builtinServerStepUbuntu,
        state: ubuntuReady
            ? _Step.done
            : ubuntuInstalling
            ? _Step.running
            : ubuntuFailed
            ? _Step.error
            : _Step.idle,
        body: ubuntuReady
            ? [muted(l10n.builtinServerUbuntuDone)]
            : ubuntuInstalling
            ? [muted(status?.message ?? l10n.builtinServerUbuntuWorking)]
            : [
                muted(l10n.builtinServerUbuntuHint),
                if (ubuntuFailed) ...[
                  gap(),
                  failure(
                    l10n.builtinServerUbuntuFailed(status?.message ?? ''),
                  ),
                ],
                gap(),
                KitActionBlock(
                  primary: KitAction(
                    key: const Key('builtin-install-ubuntu'),
                    label: ubuntuFailed
                        ? l10n.builtinServerRetry
                        : l10n.builtinServerUbuntuAction,
                    icon: AppIconography.download,
                    onPressed: status == null || _busy ? null : _installUbuntu,
                  ),
                ),
              ],
      ),
      _StepTile(
        number: 2,
        title: l10n.builtinServerStepOpenCode,
        enabled: ubuntuReady,
        state: openCodeReady
            ? _Step.done
            : _installingOpenCode || _checkingVersion
            ? _Step.running
            : openCodeError != null
            ? _Step.error
            : _Step.idle,
        body: !ubuntuReady
            ? const []
            : [
                KitSegmented<TermuxRuntime>(
                  key: const Key('builtin-runtime'),
                  semanticsLabel: l10n.builtinServerChooseRuntime,
                  segments: [
                    KitSegment(
                      value: TermuxRuntime.openCode1,
                      label: l10n.setupRuntimeOne,
                    ),
                    KitSegment(
                      value: TermuxRuntime.openCode2,
                      label: l10n.setupRuntimeTwo,
                    ),
                  ],
                  selected: _runtime,
                  onChanged: _busy || running
                      ? null
                      : (value) => unawaited(_selectRuntime(value)),
                  disabledReason: _busy || running
                      ? l10n.builtinServerRuntimeLocked
                      : null,
                ),
                gap(),
                if (openCodeReady)
                  muted(l10n.builtinServerOpenCodeInstalled(_installedVersion!))
                else if (_installingOpenCode)
                  muted(l10n.builtinServerOpenCodeWorking)
                else ...[
                  muted(l10n.builtinServerOpenCodeHint(_runtime.pinnedVersion)),
                  if (openCodeError != null) ...[gap(), failure(openCodeError)],
                  gap(),
                  KitActionBlock(
                    primary: KitAction(
                      key: const Key('builtin-install-opencode'),
                      label: openCodeError != null
                          ? l10n.builtinServerRetry
                          : l10n.builtinServerOpenCodeAction,
                      icon: AppIconography.download,
                      onPressed: _busy || _checkingVersion
                          ? null
                          : _installOpenCode,
                    ),
                  ),
                ],
                if (openCodeError != null && _openCodeOutput.isNotEmpty) ...[
                  gap(),
                  KitLogPanel(
                    lines: _openCodeLog,
                    ended: const KitLogEnd(failed: true),
                  ),
                ],
              ],
      ),
      _StepTile(
        number: 3,
        title: l10n.builtinServerStepStart,
        enabled: openCodeReady,
        state: running && !_starting
            ? _Step.done
            : _starting
            ? _Step.running
            : startError != null
            ? _Step.error
            : _Step.idle,
        body: !openCodeReady
            ? const []
            : [
                muted(
                  _starting
                      ? l10n.builtinServerStarting
                      : running
                      ? l10n.builtinServerRunning(BuiltinLinux.serverPort)
                      : l10n.builtinServerStopped,
                ),
                if (startError != null) ...[gap(), failure(startError)],
                gap(),
                KitActionBlock(
                  primary: running
                      ? null
                      : KitAction(
                          key: const Key('builtin-start'),
                          label: startError != null
                              ? l10n.builtinServerRetry
                              : l10n.builtinServerStartAction,
                          icon: AppIconography.play,
                          onPressed: _busy ? null : _start,
                        ),
                  secondary: running
                      ? KitAction(
                          key: const Key('builtin-stop'),
                          label: l10n.builtinServerStopAction,
                          icon: AppIconography.stop,
                          onPressed: _busy ? null : _stop,
                        )
                      : null,
                  tertiary: [
                    KitAction(
                      key: const Key('builtin-show-log'),
                      label: l10n.builtinServerShowLog,
                      icon: AppIconography.article,
                      onPressed: _showLog,
                    ),
                  ],
                ),
              ],
      ),
      _StepTile(
        number: 4,
        title: l10n.builtinServerStepConnect,
        enabled: running && !_starting,
        state: connected
            ? _Step.done
            : _connecting
            ? _Step.running
            : connectError != null
            ? _Step.error
            : _Step.idle,
        body: !(running && !_starting)
            ? const []
            : [
                muted(
                  connected
                      ? l10n.builtinServerConnected
                      : _connecting
                      ? l10n.builtinServerConnecting
                      : l10n.builtinServerConnectHint(
                          _existingProfile()?.name ??
                              l10n.builtinServerProfileName(_runtimeName),
                        ),
                ),
                if (connectError != null) ...[gap(), failure(connectError)],
                if (!connected) ...[
                  gap(),
                  KitActionBlock(
                    primary: KitAction(
                      key: const Key('builtin-connect'),
                      label: l10n.builtinServerConnectAction,
                      icon: AppIconography.link,
                      onPressed: _busy ? null : () => _connect(),
                    ),
                  ),
                ],
              ],
      ),
    ];

    return KitScreen(
      topBar: KitTopBar(title: l10n.builtinServerTitle),
      width: KitScreenWidth.reading,
      body: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.gutter,
          tokens.space2,
          tokens.gutter,
          KitScreen.endPadding(context),
        ),
        children: [
          KitText(l10n.builtinServerEntryTitle, role: KitTextRole.headline),
          SizedBox(height: tokens.space2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: KitChip(label: l10n.builtinServerExperimental),
          ),
          SizedBox(height: tokens.space2),
          muted(l10n.builtinServerIntro),
          if (statusError != null) ...[
            gap(),
            failure(l10n.builtinServerStatusFailed(statusError)),
          ],
          if (_removed) ...[
            gap(),
            KitNotice(
              key: const Key('builtin-server-removed'),
              tone: AppStatusTone.ok,
              icon: AppIconography.check,
              message: l10n.builtinServerRemoved,
            ),
          ],
          SizedBox(height: tokens.sectionGap),
          KitSurface.panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const KitDivider(),
                  steps[i],
                ],
              ],
            ),
          ),
          if (ubuntuReady) ...[
            SizedBox(height: tokens.sectionGap),
            // The server lives in this app's process: what to allow so
            // Android leaves it running.
            KitRowGroup(
              margin: EdgeInsetsDirectional.zero,
              children: [
                KitRow(
                  key: const Key('builtin-server-keep-running'),
                  leading: KitRow.icon(context, AppIconography.batteryCharging),
                  title: l10n.keepRunningTitle,
                  titleMaxLines: 2,
                  supporting: TextSpan(text: l10n.keepRunningRowSubtitle),
                  supportingMaxLines: 2,
                  trailing: const KitChevron(),
                  onTap: () => openKeepRunningScreen(context),
                ),
              ],
            ),
            // Measured in the background: nothing until a real figure.
            if ((status?.bytesUsed ?? 0) > 0) ...[
              gap(),
              muted(
                l10n.builtinServerBytesUsed(_formatBytes(status!.bytesUsed!)),
              ),
            ],
            gap(),
            KitActionBlock(
              tertiary: [
                KitAction(
                  key: const Key('builtin-remove'),
                  label: l10n.builtinServerRemove,
                  icon: AppIconography.delete,
                  destructive: true,
                  onPressed: _busy ? null : _remove,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The server log in its sheet: the tail Android keeps, followed while the
/// server runs (map statesMissing "live"), or the read's failure as a
/// notice with Try again.
class _ServerLogBody extends StatefulWidget {
  const _ServerLogBody({
    required this.linux,
    required this.initial,
    required this.readError,
    required this.running,
  });

  final BuiltinLinux linux;
  final String initial;
  final String? readError;
  final bool running;

  @override
  State<_ServerLogBody> createState() => _ServerLogBodyState();
}

class _ServerLogBodyState extends State<_ServerLogBody> {
  late final _lines = KitLogBuffer()..replaceText(widget.initial.trimRight());
  late String? _error = widget.readError;

  @override
  void dispose() {
    _lines.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final log = await widget.linux.serverLog();
      if (!mounted) return;
      _lines.replaceText(log.trimRight());
      if (_error != null) setState(() => _error = null);
    } on BuiltinLinuxException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          KitNotice.error(
            key: const Key('builtin-server-log-error'),
            message: l10n.builtinServerLogReadFailed,
            details: error,
            retry: KitAction(
              label: l10n.builtinServerRetry,
              onPressed: _reload,
            ),
          ),
          SizedBox(height: tokens.space3),
        ],
        KitLogPanel(
          panelKey: const Key('builtin-server-log'),
          lines: _lines,
          title: l10n.builtinServerLogTitle,
          emptyText: l10n.builtinServerLogEmpty,
          live: widget.running,
          onRefresh: widget.running ? _reload : null,
          ended: widget.running ? null : const KitLogEnd(),
        ),
      ],
    );
  }
}

/// One numbered step, spoken as a single phrase ("Step 2 of 4, done. Install
/// OpenCode") the way the Termux setup's steps are: its mark, its title
/// (muted while it is not yet available), then what it holds.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.state,
    this.body = const [],
    this.enabled = true,
  });

  final int number;
  final String title;
  final _Step state;
  final List<Widget> body;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final stateLabel = !enabled
        ? l10n.e7SetupStepUnavailable
        : switch (state) {
            _Step.done => l10n.e7SetupStepDone,
            _Step.running => l10n.e7SetupStepRunning,
            _Step.error => l10n.e7SetupStepFailed,
            _Step.idle => l10n.e7SetupStepTodo,
          };
    final mark = switch (state) {
      _Step.done => KitMarkState.done,
      _Step.running => KitMarkState.working,
      _Step.error => KitMarkState.failed,
      _Step.idle => KitMarkState.waiting,
    };
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: l10n.builtinServerStepSemantics(number, stateLabel, title),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  KitStatusMark(state: mark),
                  SizedBox(width: tokens.space3),
                  Expanded(
                    child: KitText(
                      title,
                      role: KitTextRole.rowTitle,
                      tone: enabled ? null : KitTextTone.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (body.isNotEmpty) ...[SizedBox(height: tokens.space3), ...body],
        ],
      ),
    );
  }
}
