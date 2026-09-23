import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart' show TermuxRuntime;
import '../app_theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/setup_terminal.dart';

/// "Run OpenCode inside the app — no Termux" (experimental, GitHub issue #87).
///
/// Four steps, each driven by one call on [BuiltinLinux]: download Ubuntu,
/// install OpenCode inside it, start the server on 127.0.0.1:4097, connect.
/// Nothing here touches Termux: the server is a child of this app's process,
/// and its profile's port keeps every Termux-only code path away from it.
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
Future<void> openBuiltinServerScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const BuiltinServerScreen()));

/// Which OpenCode the built-in Ubuntu runs, kept across visits.
const builtinRuntimePrefKey = 'builtin_linux_runtime';

enum _Step { idle, running, done, error }

class _BuiltinServerScreenState extends ConsumerState<BuiltinServerScreen> {
  late final BuiltinLinux _linux =
      widget.linux ?? ref.read(builtinLinuxProvider);
  final _outputScroll = ScrollController();

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
    _outputScroll.dispose();
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

  ServerProfile? _existingProfile() {
    for (final profile in ref.read(bootstrapProvider).store.profiles) {
      if (profile.backend == ServerBackend.openCode &&
          BuiltinLinux.managesServerUrl(profile.baseUrl) &&
          profile.flavor == _flavor) {
        return profile;
      }
    }
    return null;
  }

  /// One saved profile per runtime, like the Termux server. The password is
  /// made once and lives with the profile in secure storage; the server reads
  /// its copy from a root-only file that every start rewrites, so a password
  /// the keystore lost is simply replaced.
  Future<ServerProfile> _ensureProfile() async {
    final store = ref.read(bootstrapProvider).store;
    final profile =
        _existingProfile() ??
        ServerProfile(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: _l10n.builtinServerProfileName(_runtimeName),
          baseUrl: BuiltinLinux.serverUrl,
          flavor: _flavor,
        );
    profile.username = BuiltinLinux.serverUsername;
    if (profile.password.isEmpty || profile.requiresPasswordReentry) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      profile.password = base64UrlEncode(bytes).replaceAll('=', '');
      profile.requiresPasswordReentry = false;
    }
    if (_installedVersion != null) profile.serverVersion = _installedVersion;
    await store.upsert(profile);
    return profile;
  }

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
    String log;
    try {
      log = await _linux.serverLog();
    } on BuiltinLinuxException catch (error) {
      log = error.message;
    }
    if (!mounted) return;
    final controller = ScrollController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _l10n.builtinServerLogTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(AppIconography.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SetupTerminal(
                  key: const Key('builtin-server-log'),
                  output: log.trim().isEmpty
                      ? _l10n.builtinServerLogEmpty
                      : log,
                  running: false,
                  controller: controller,
                  expand: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _remove() async {
    final confirmed = await showConfirmSheet(
      context,
      title: _l10n.builtinServerRemoveTitle,
      message: _l10n.builtinServerRemoveBody,
      confirmLabel: _l10n.builtinServerRemove,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      icon: AppIconography.delete,
      destructive: true,
      confirmKey: const Key('builtin-server-remove-confirm'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _removing = true);
    try {
      await _linux.uninstall();
      if (!mounted) return;
      setState(() {
        _installedVersion = null;
        _openCodeOutput = '';
        _openCodeError = null;
        _startError = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.builtinServerRemoved)));
    } on BuiltinLinuxException catch (error) {
      if (mounted) setState(() => _statusError = error.message);
    }
    if (!mounted) return;
    await _refresh();
    if (mounted) setState(() => _removing = false);
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
    final theme = Theme.of(context);
    final l10n = _l10n;
    if (!BuiltinLinux.supported) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.builtinServerTitle)),
        body: Center(
          child: Padding(
            key: const Key('builtin-server-unsupported'),
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.builtinServerAndroidOnly,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
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
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: AppTheme.mutedOf(theme),
    );

    Widget error(String message) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.builtinServerTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(AppIconography.phone, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.builtinServerEntryTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _ExperimentalBadge(
                  label: l10n.builtinServerExperimental,
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.builtinServerIntro, style: muted),
              if (_statusError != null)
                error(l10n.builtinServerStatusFailed(_statusError!)),
              const Divider(height: 32),
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
                    ? Text(l10n.builtinServerUbuntuDone, style: muted)
                    : ubuntuInstalling
                    ? Text(
                        status?.message ?? l10n.builtinServerUbuntuWorking,
                        style: muted,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.builtinServerUbuntuHint, style: muted),
                          if (ubuntuFailed)
                            error(
                              l10n.builtinServerUbuntuFailed(
                                status?.message ?? '',
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: const Key('builtin-install-ubuntu'),
                            onPressed: status == null || _busy
                                ? null
                                : _installUbuntu,
                            icon: const Icon(AppIconography.download),
                            label: Text(
                              ubuntuFailed
                                  ? l10n.builtinServerRetry
                                  : l10n.builtinServerUbuntuAction,
                            ),
                          ),
                        ],
                      ),
              ),
              _StepTile(
                number: 2,
                title: l10n.builtinServerStepOpenCode,
                enabled: ubuntuReady,
                state: openCodeReady
                    ? _Step.done
                    : _installingOpenCode || _checkingVersion
                    ? _Step.running
                    : _openCodeError != null
                    ? _Step.error
                    : _Step.idle,
                body: !ubuntuReady
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.builtinServerChooseRuntime, style: muted),
                          const SizedBox(height: 6),
                          SegmentedButton<TermuxRuntime>(
                            key: const Key('builtin-runtime'),
                            segments: [
                              ButtonSegment(
                                value: TermuxRuntime.openCode1,
                                label: Text(l10n.setupRuntimeOne),
                              ),
                              ButtonSegment(
                                value: TermuxRuntime.openCode2,
                                label: Text(l10n.setupRuntimeTwo),
                              ),
                            ],
                            selected: {_runtime},
                            onSelectionChanged: _busy || running
                                ? null
                                : (value) => _selectRuntime(value.first),
                          ),
                          const SizedBox(height: 8),
                          if (openCodeReady)
                            Text(
                              l10n.builtinServerOpenCodeInstalled(
                                _installedVersion!,
                              ),
                              style: muted,
                            )
                          else if (_installingOpenCode)
                            Text(
                              l10n.builtinServerOpenCodeWorking,
                              style: muted,
                            )
                          else ...[
                            Text(
                              l10n.builtinServerOpenCodeHint(
                                _runtime.pinnedVersion,
                              ),
                              style: muted,
                            ),
                            if (_openCodeError != null) error(_openCodeError!),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              key: const Key('builtin-install-opencode'),
                              onPressed: _busy || _checkingVersion
                                  ? null
                                  : _installOpenCode,
                              icon: const Icon(AppIconography.download),
                              label: Text(
                                _openCodeError != null
                                    ? l10n.builtinServerRetry
                                    : l10n.builtinServerOpenCodeAction,
                              ),
                            ),
                          ],
                          if (_openCodeError != null &&
                              _openCodeOutput.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SetupTerminal(
                              output: _openCodeOutput,
                              running: false,
                              controller: _outputScroll,
                            ),
                          ],
                        ],
                      ),
              ),
              _StepTile(
                number: 3,
                title: l10n.builtinServerStepStart,
                enabled: openCodeReady,
                state: running && !_starting
                    ? _Step.done
                    : _starting
                    ? _Step.running
                    : _startError != null
                    ? _Step.error
                    : _Step.idle,
                body: !openCodeReady
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _starting
                                ? l10n.builtinServerStarting
                                : running
                                ? l10n.builtinServerRunning(
                                    BuiltinLinux.serverPort,
                                  )
                                : l10n.builtinServerStopped,
                            style: muted,
                          ),
                          if (_startError != null) error(_startError!),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (running)
                                OutlinedButton.icon(
                                  key: const Key('builtin-stop'),
                                  onPressed: _busy ? null : _stop,
                                  icon: const Icon(AppIconography.stop),
                                  label: Text(l10n.builtinServerStopAction),
                                )
                              else
                                FilledButton.icon(
                                  key: const Key('builtin-start'),
                                  onPressed: _busy ? null : _start,
                                  icon: const Icon(AppIconography.play),
                                  label: Text(
                                    _startError != null
                                        ? l10n.builtinServerRetry
                                        : l10n.builtinServerStartAction,
                                  ),
                                ),
                              TextButton.icon(
                                key: const Key('builtin-show-log'),
                                onPressed: _showLog,
                                icon: const Icon(AppIconography.article),
                                label: Text(l10n.builtinServerShowLog),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              _StepTile(
                number: 4,
                title: l10n.builtinServerStepConnect,
                enabled: running && !_starting,
                state: connected
                    ? _Step.done
                    : _connecting
                    ? _Step.running
                    : _connectError != null
                    ? _Step.error
                    : _Step.idle,
                body: !(running && !_starting)
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connected
                                ? l10n.builtinServerConnected
                                : _connecting
                                ? l10n.builtinServerConnecting
                                : l10n.builtinServerConnectHint(
                                    _existingProfile()?.name ??
                                        l10n.builtinServerProfileName(
                                          _runtimeName,
                                        ),
                                  ),
                            style: muted,
                          ),
                          if (_connectError != null) error(_connectError!),
                          if (!connected) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              key: const Key('builtin-connect'),
                              onPressed: _busy ? null : () => _connect(),
                              icon: const Icon(AppIconography.link),
                              label: Text(l10n.builtinServerConnectAction),
                            ),
                          ],
                        ],
                      ),
              ),
              if (ubuntuReady) ...[
                const Divider(height: 32),
                if (status?.bytesUsed != null)
                  Text(
                    l10n.builtinServerBytesUsed(
                      _formatBytes(status!.bytesUsed!),
                    ),
                    style: muted,
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('builtin-remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _busy ? null : _remove,
                    icon: const Icon(AppIconography.delete),
                    label: Text(l10n.builtinServerRemove),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExperimentalBadge extends StatelessWidget {
  const _ExperimentalBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

/// One numbered step, spoken as a single phrase ("Step 2 of 4, done. Install
/// OpenCode") the way the Termux setup's steps are.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.state,
    this.body,
    this.enabled = true,
  });

  final int number;
  final String title;
  final _Step state;
  final Widget? body;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final stateLabel = !enabled
        ? l10n.e7SetupStepUnavailable
        : switch (state) {
            _Step.done => l10n.e7SetupStepDone,
            _Step.running => l10n.e7SetupStepRunning,
            _Step.error => l10n.e7SetupStepFailed,
            _Step.idle => l10n.e7SetupStepTodo,
          };
    final background = switch (state) {
      _Step.done => AppTheme.successOf(theme),
      _Step.running => theme.colorScheme.primary,
      _Step.error => theme.colorScheme.error,
      _Step.idle => theme.colorScheme.surfaceContainerHighest,
    };
    final foreground = state == _Step.idle
        ? theme.colorScheme.onSurfaceVariant
        : ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Semantics(
      container: true,
      label: l10n.builtinServerStepSemantics(number, stateLabel, title),
      child: Opacity(
        opacity: enabled ? 1 : .6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: background,
                      child: state == _Step.done
                          ? Icon(
                              AppIconography.check,
                              size: 14,
                              color: foreground,
                            )
                          : Text(
                              '$number',
                              style: TextStyle(
                                fontSize: AppTheme.codeFontSize,
                                color: foreground,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    if (state == _Step.running)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              if (body != null) ...[const SizedBox(height: 10), body!],
            ],
          ),
        ),
      ),
    );
  }
}
