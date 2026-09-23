import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/server_probe.dart';
import '../l10n/app_localizations.dart';
import '../state/profiles.dart';
import 'builtin_linux.dart';

/// The bridge the whole app uses; tests override it.
final builtinLinuxProvider = Provider<BuiltinLinux>((ref) => BuiltinLinux());

/// One starter per app, so the start screen, the opening card and the
/// return-to-app hook all see the same "starting" state and share the
/// once-only automatic start.
final builtinServerStarterProvider = Provider<BuiltinServerStarter>((ref) {
  final starter = BuiltinServerStarter(linux: ref.watch(builtinLinuxProvider));
  ref.onDispose(starter.dispose);
  return starter;
});

/// Shape only: an OpenCode profile at 127.0.0.1:4097 on a runner that has
/// the built-in Linux. Cheap and synchronous, so it can decide whether to ask
/// the bridge at all; it is not the answer by itself, because a developer can
/// point 4097 at anything (adb reverse, a tunnel).
bool looksLikeInAppServer(ServerProfile? profile) =>
    profile != null &&
    profile.backend == ServerBackend.openCode &&
    BuiltinLinux.supported &&
    BuiltinLinux.managesServerUrl(profile.baseUrl);

/// The one answer to "is this the OpenCode that runs inside the app":
/// the profile's shape plus Ubuntu actually installed on this phone.
Future<bool> isInAppServer(ServerProfile? profile, BuiltinLinux linux) async {
  if (!looksLikeInAppServer(profile)) return false;
  try {
    return (await linux.status()).installed;
  } on BuiltinLinuxException {
    return false;
  }
}

/// Why a start did not end with a server answering our password.
class BuiltinServerStartFailure {
  const BuiltinServerStartFailure.detail(String this._detail)
    : _exited = false,
      _timeoutSeconds = null;
  const BuiltinServerStartFailure.exited()
    : _detail = null,
      _exited = true,
      _timeoutSeconds = null;
  const BuiltinServerStartFailure.timedOut(int seconds)
    : _detail = null,
      _exited = false,
      _timeoutSeconds = seconds;

  final String? _detail;
  final bool _exited;
  final int? _timeoutSeconds;

  /// A short reason for [AppLocalizations.builtinServerStartFailed].
  String reason(AppLocalizations l10n) {
    if (_exited) return l10n.builtinServerExited;
    final seconds = _timeoutSeconds;
    if (seconds != null) return l10n.builtinServerTimedOut(seconds);
    return _detail!;
  }
}

/// Writes the password file, starts the server (restarting one that runs)
/// and waits until it answers with [profile]'s password. Null on success.
///
/// The single start path: the setup screen and the opening card both call
/// it, so the two can never start the server differently.
Future<BuiltinServerStartFailure?> startBuiltinServer({
  required BuiltinLinux linux,
  required ServerProfile profile,
  Duration readyTimeout = const Duration(seconds: 90),
  Duration pollInterval = const Duration(seconds: 2),
  bool Function()? stillWanted,
}) async {
  if (profile.password.isEmpty) {
    return const BuiltinServerStartFailure.detail(
      'The saved server password is missing.',
    );
  }
  try {
    final written = await linux.run(
      BuiltinLinux.writePasswordScript(profile.password),
      timeout: const Duration(seconds: 60),
    );
    if (!written.ok) {
      final output = written.output.trim();
      return BuiltinServerStartFailure.detail(
        output.isEmpty ? 'exit ${written.exitCode}' : output,
      );
    }
    await linux.startServer(
      BuiltinLinux.serverScript(
        runtime: BuiltinLinux.runtimeFor(profile.flavor),
      ),
      port: BuiltinLinux.serverPort,
    );
    final deadline = DateTime.now().add(readyTimeout);
    while (stillWanted?.call() ?? true) {
      final probe = await serverProbe(
        baseUrl: BuiltinLinux.serverUrl,
        username: profile.username,
        password: profile.password,
      );
      if (probe.ok) return null;
      final status = await linux.status();
      if (!status.serverRunning) {
        return const BuiltinServerStartFailure.exited();
      }
      if (!DateTime.now().isBefore(deadline)) {
        return BuiltinServerStartFailure.timedOut(readyTimeout.inSeconds);
      }
      await Future<void>.delayed(pollInterval);
    }
    return null;
  } on BuiltinLinuxException catch (error) {
    return BuiltinServerStartFailure.detail(error.message);
  }
}

/// Starts the in-app server for the app shell: once on its own when the app
/// opens or comes back with that server selected and it is stopped, and on
/// request from the connection card.
class BuiltinServerStarter extends ChangeNotifier {
  BuiltinServerStarter({
    required this.linux,
    this.readyTimeout = const Duration(seconds: 90),
    this.pollInterval = const Duration(seconds: 2),
  });

  final BuiltinLinux linux;
  final Duration readyTimeout;
  final Duration pollInterval;

  bool _starting = false;
  BuiltinServerStartFailure? _failure;
  String? _failedProfileID;
  bool _autoStartUsed = false;
  bool? _installed;
  bool _disposed = false;

  /// True while a start is waiting for the server to answer.
  bool get starting => _starting;

  /// Grows by one on every start that ended with the server answering, so a
  /// screen waiting on a stopped server knows to connect again.
  int get readyCount => _readyCount;
  int _readyCount = 0;

  /// The last start's failure for [profile], or null.
  BuiltinServerStartFailure? failureFor(ServerProfile? profile) =>
      profile != null && profile.id == _failedProfileID ? _failure : null;

  /// Synchronous [isInAppServer] from the last status read, for build
  /// methods. Unknown (never read, or the read failed) counts as no.
  bool recognises(ServerProfile? profile) =>
      _installed == true && looksLikeInAppServer(profile);

  /// Whether the next [autoStartIfStopped] may start the server.
  bool get autoStartAvailable => !_autoStartUsed;

  /// The app opened or came back to the foreground: one automatic start is
  /// allowed again. Never called from a failure path, so a server that dies
  /// on start is not restarted in a loop.
  void allowAutoStart() => _autoStartUsed = false;

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    _failedProfileID = null;
    _notify();
  }

  /// Starts the server when Ubuntu is installed and the server is not
  /// running, at most once until [allowAutoStart]. A server that is already
  /// running (the app was only in the background) is left alone. Returns
  /// true when it started one that now answers.
  Future<bool> autoStartIfStopped(ServerProfile? profile) async {
    if (_autoStartUsed || _starting || !looksLikeInAppServer(profile)) {
      return false;
    }
    _autoStartUsed = true;
    final BuiltinLinuxStatus status;
    try {
      status = await linux.status();
    } on BuiltinLinuxException {
      return false;
    }
    _installed = status.installed;
    if (!status.installed || status.serverRunning) {
      _notify();
      return false;
    }
    return await start(profile!) == null;
  }

  /// Starts (or restarts) the server for [profile] and waits for it.
  Future<BuiltinServerStartFailure?> start(ServerProfile profile) async {
    if (_starting) return const BuiltinServerStartFailure.detail('busy');
    _starting = true;
    _failure = null;
    _failedProfileID = null;
    _notify();
    final failure = await startBuiltinServer(
      linux: linux,
      profile: profile,
      readyTimeout: readyTimeout,
      pollInterval: pollInterval,
      stillWanted: () => !_disposed,
    );
    _starting = false;
    if (failure == null) {
      _installed = true;
      _readyCount++;
    } else {
      _failure = failure;
      _failedProfileID = profile.id;
    }
    _notify();
    return failure;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Project folders inside the in-app Ubuntu, read and made through the
/// bridge instead of through OpenCode, so OpenCode is never asked about a
/// folder that does not exist yet.
class BuiltinProjectFolders {
  const BuiltinProjectFolders(this.linux);

  final BuiltinLinux linux;

  static String pathFor(String name) =>
      '${BuiltinLinux.projectsDir}/${name.trim()}';

  Future<List<String>> list() async {
    final result = await linux.run(
      BuiltinLinux.listProjectsScript(),
      timeout: const Duration(seconds: 30),
    );
    if (!result.ok) throw BuiltinLinuxException(_describe(result));
    return BuiltinLinux.parseProjectList(result.output);
  }

  Future<bool> exists(String path) async {
    final result = await linux.run(
      BuiltinLinux.folderExistsScript(path),
      timeout: const Duration(seconds: 30),
    );
    // `test -d` answers 0 or 1; anything else is the bridge failing.
    if (result.exitCode == 0) return true;
    if (result.exitCode == 1) return false;
    throw BuiltinLinuxException(_describe(result));
  }

  /// Makes [path] a git project unless it already is a folder. `created` is
  /// false for a folder that was already there.
  Future<({String path, bool created})> create(String path) async {
    final result = await linux.run(
      BuiltinLinux.createFolderScript(path),
      timeout: const Duration(seconds: 60),
    );
    final lines = result.output.trim().split('\n');
    final last = lines.isEmpty ? '' : lines.last.trim();
    if (result.ok && last == 'created $path') {
      return (path: path, created: true);
    }
    if (result.ok && last == 'exists $path') {
      return (path: path, created: false);
    }
    throw BuiltinLinuxException(_describe(result));
  }

  static String _describe(BuiltinLinuxRunResult result) {
    final output = result.output.trim();
    return output.isEmpty ? 'exit ${result.exitCode}' : output;
  }
}
