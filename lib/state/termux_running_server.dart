import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/server_probe.dart';
import '../platform/platform_capabilities.dart';
import '../termux/bridge.dart';
import 'profiles.dart';

/// Test seam for this scoped, non-redirecting loopback health check.
@visibleForTesting
TermuxRunningServerProbe termuxRunningServerProbe = _probeLoopback;

typedef TermuxRunningServerProbe =
    Future<ServerProbeResult> Function({
      required String baseUrl,
      String? username,
      String? password,
      TermuxDiscoveryCancellation? cancellation,
    });

/// Owns this screen observation's deadlines and in-flight HTTP request.
/// Native method-channel calls cannot be recalled, but late replies are ignored
/// and never initiate the next discovery stage after cancellation.
class TermuxDiscoveryCancellation {
  bool _cancelled = false;
  final _callbacks = <VoidCallback>{};

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final callbacks = _callbacks.toList();
    _callbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void _add(VoidCallback callback) {
    if (_cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  Future<T> wait<T>(Future<T> Function() start, Duration timeout) async {
    if (_cancelled) throw const _DiscoveryCancelled();
    final completer = Completer<T>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Termux discovery timed out'));
      }
    });
    void abort() {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(const _DiscoveryCancelled());
      }
    }

    _add(abort);
    try {
      // Start through Future.sync so a synchronous plugin/probe failure follows
      // the same cleanup path as an asynchronous failure.
      unawaited(
        Future<T>.sync(start).then<void>(
          (value) {
            if (!completer.isCompleted) completer.complete(value);
          },
          onError: (Object error, StackTrace stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          },
        ),
      );
      return await completer.future;
    } finally {
      timer.cancel();
      _callbacks.remove(abort);
    }
  }
}

class _DiscoveryCancelled implements Exception {
  const _DiscoveryCancelled();
}

Future<ServerProbeResult> _probeLoopback({
  required String baseUrl,
  String? username,
  String? password,
  TermuxDiscoveryCancellation? cancellation,
}) async {
  final dio = Dio(
    BaseOptions(
      // Deliberately ignore supplied addresses: discovery cannot become a scan.
      baseUrl: TermuxBridge.managedServerUrl,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      validateStatus: (status) => status != null,
      headers: {
        if (password != null && password.isNotEmpty)
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${username == null || username.isEmpty ? 'opencode' : username}:$password'))}',
      },
    ),
  );
  final cancelToken = CancelToken();
  void cancelRequest() {
    cancelToken.cancel('Discovery disposed');
    dio.close(force: true);
  }

  cancellation?._add(cancelRequest);
  try {
    // /api/info is where OpenCode 2.0.4 and later report themselves.
    for (final path in ['/api/health', '/api/info', '/global/health']) {
      final response = await dio.get<Object?>(path, cancelToken: cancelToken);
      if (response.statusCode == 401) {
        return const ServerProbeResult.failure(
          'Authentication required',
          needsPassword: true,
        );
      }
      final body = response.data;
      if (response.statusCode == 200 &&
          body is Map &&
          (body['healthy'] == true ||
              (path == '/api/info' &&
                  body['version'] is String &&
                  (body['pid'] is num || body['urls'] is List)))) {
        return ServerProbeResult.success(body['version']?.toString());
      }
    }
    return const ServerProbeResult.failure('No healthy OpenCode response');
  } finally {
    cancellation?._callbacks.remove(cancelRequest);
    dio.close(force: true);
  }
}

/// What one read-only look at the phone's Termux found.
///
/// This is an observation, not a fact the app keeps: it is held in widget
/// state for the screen that asked, re-read on resume or on request, and
/// never written to preferences or a profile.
enum TermuxRunningServerState {
  /// This build has no Termux bridge; nothing was asked of the platform.
  unsupported,

  /// Termux is not installed, or the app-managed server is not ready
  /// (idle, stopped, still installing, failed, or mid-switch).
  absent,

  /// Termux is installed but this app cannot run commands in it: the
  /// run-command permission is missing, or the installed Termux predates the
  /// command-result protocol. Nothing is known about a server.
  denied,

  /// The bridge answered with an error or timed out. Nothing is known.
  unavailable,

  /// The app-managed server is set up on this phone and was stopped. It can
  /// be started again in place.
  stopped,

  /// A live OpenCode response confirms the ready managed process.
  running,
}

/// One observation of the app-managed Termux server.
class TermuxRunningServer {
  const TermuxRunningServer._({
    required this.state,
    this.runtime,
    this.version = '',
    this.phase = '',
    this.observedAt,
    this.needsCredentials = false,
  });

  const TermuxRunningServer.unsupported()
    : this._(state: TermuxRunningServerState.unsupported);

  const TermuxRunningServer.absent({String phase = ''})
    : this._(state: TermuxRunningServerState.absent, phase: phase);

  const TermuxRunningServer.denied()
    : this._(state: TermuxRunningServerState.denied);

  const TermuxRunningServer.unavailable()
    : this._(state: TermuxRunningServerState.unavailable);

  const TermuxRunningServer.stopped({required TermuxRuntime runtime})
    : this._(
        state: TermuxRunningServerState.stopped,
        runtime: runtime,
        phase: 'stopped',
      );

  const TermuxRunningServer.running({
    required TermuxRuntime runtime,
    required String version,
    required DateTime observedAt,
    bool needsCredentials = false,
  }) : this._(
         state: TermuxRunningServerState.running,
         runtime: runtime,
         version: version,
         phase: 'ready',
         observedAt: observedAt,
         needsCredentials: needsCredentials,
       );

  final TermuxRunningServerState state;

  /// The runtime the manager reports; only meaningful when [isRunning] or
  /// [isStopped].
  final TermuxRuntime? runtime;

  /// The server version the manager reports; may be empty.
  final String version;

  /// The raw manager phase, kept for diagnostics and tests.
  final String phase;

  /// When the observation was taken; null unless [isRunning].
  final DateTime? observedAt;

  /// A live responder requested authentication; its health is not verified.
  final bool needsCredentials;

  bool get isRunning => state == TermuxRunningServerState.running;
  bool get isStopped => state == TermuxRunningServerState.stopped;

  /// The profile generation that speaks to [runtime].
  ServerFlavor get flavor =>
      runtime == TermuxRuntime.openCode2 ? ServerFlavor.v2 : ServerFlavor.v1;
}

/// Reads whether the app-managed OpenCode server is running in Termux.
///
/// Read-only by construction: it asks the Android runner for Termux
/// capabilities (no Termux command), and only when the run-command
/// permission is already granted does it run the manager's `status` verb,
/// which never starts, installs, or restarts anything (it may reconcile stale
/// manager bookkeeping). A bounded loopback health probe then confirms a live
/// responder; authentication is verified later on Connect. Off Android it asks
/// nothing. Every failure becomes an honest non-running state; nothing here
/// throws.
Future<TermuxRunningServer> detectTermuxRunningServer({
  Iterable<ServerProfile> profiles = const [],
  DateTime Function() now = DateTime.now,
  TermuxDiscoveryCancellation? cancellation,
}) async {
  final observation = cancellation ?? TermuxDiscoveryCancellation();
  try {
    if (!platformCapabilities.supportsTermux) {
      return const TermuxRunningServer.unsupported();
    }
    TermuxCapabilities capabilities;
    try {
      capabilities = await observation.wait(
        TermuxBridge.capabilities,
        const Duration(seconds: 5),
      );
    } catch (_) {
      return const TermuxRunningServer.unavailable();
    }
    if (!capabilities.platformSupported || !capabilities.installed) {
      return const TermuxRunningServer.absent();
    }
    if (!capabilities.serviceAvailable ||
        !capabilities.protocolSupported ||
        !capabilities.permissionGranted) {
      return const TermuxRunningServer.denied();
    }
    TermuxSetupStatus status;
    try {
      status = await observation.wait(
        TermuxBridge.status,
        const Duration(seconds: 8),
      );
    } catch (_) {
      return const TermuxRunningServer.unavailable();
    }
    if (status.isReady &&
        !status.switchPending &&
        status.port == TermuxBridge.managedServerPort) {
      final observed = TermuxRunningServer.running(
        runtime: status.runtime,
        version:
            RegExp(
              r'^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$',
            ).hasMatch(status.version.trim())
            ? status.version.trim()
            : '',
        observedAt: now(),
      );
      final profile = savedProfileForTermuxServer(profiles, observed);
      try {
        // Probe only the app-authored loopback address. Never trust a persisted
        // ready phase alone, scan ports, follow arbitrary profile URLs, or log
        // credentials. A password challenge confirms a live server but leaves
        // authentication to the explicit Connect flow.
        final health = await observation.wait(
          () => termuxRunningServerProbe(
            baseUrl: TermuxBridge.managedServerUrl,
            username: profile?.username,
            password: profile?.password,
            cancellation: observation,
          ),
          const Duration(seconds: 10),
        );
        if (health.ok || health.needsPassword) {
          return TermuxRunningServer.running(
            runtime: observed.runtime!,
            version: observed.version,
            observedAt: now(),
            needsCredentials: health.needsPassword,
          );
        }
      } catch (_) {
        // Transport, parse and plugin failures must not escape into the UI.
      }
      return const TermuxRunningServer.unavailable();
    }
    // A deliberate stop leaves a selected runtime behind; a phone that was
    // never set up reports `idle` with none. Only the former can be started
    // in place.
    if (status.phase == 'stopped' &&
        status.runtimeSelected &&
        !status.switchPending) {
      return TermuxRunningServer.stopped(runtime: status.runtime);
    }
    return TermuxRunningServer.absent(phase: status.phase);
  } finally {
    observation.cancel();
  }
}

/// The saved profile that already holds the running server's credential, or
/// null when the app has none for that runtime.
///
/// Matches on the managed loopback address and the profile generation the
/// running runtime speaks, never on name. Remote profiles are never
/// candidates, so they are neither chosen nor touched. A profile whose
/// password must be re-entered still matches: the connect flow owns that
/// re-entry.
ServerProfile? savedProfileForTermuxServer(
  Iterable<ServerProfile> profiles,
  TermuxRunningServer server,
) {
  if (!server.isRunning && !server.isStopped) return null;
  for (final profile in profiles) {
    if (profile.backend == ServerBackend.openCode &&
        TermuxBridge.managesServerUrl(profile.baseUrl) &&
        profile.flavor == server.flavor) {
      return profile;
    }
  }
  return null;
}
