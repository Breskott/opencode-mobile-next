import 'dart:async';

import 'package:dio/dio.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../domain/phone_project_engine.dart';
import '../../../ui/kit/kit_redact.dart';
import '../none.dart';

/// App client only. Closing never stops the native daemon.
class PhoneEngineGateway extends NullOrchestrationGateway
    implements OrchestrationProjectGateway {
  PhoneEngineGateway({
    required String baseUrl,
    required this.profileId,
    required String bearerToken,
    PhoneEngineHealth? health,
    this.probedCapabilities,
    HttpClientAdapter? adapter,
    this.pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _health = health,
       _now = now ?? DateTime.now {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.scheme != 'http' ||
        !(uri.host == '127.0.0.1' || uri.host == '::1') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        bearerToken.isEmpty ||
        bearerToken.contains(RegExp(r'[\r\n]')) ||
        profileId.isEmpty) {
      throw const PhoneEngineException('endpointInvalid');
    }
    _baseUrl = uri.replace(path: '').toString();
    _bearerToken = bearerToken;
    KitRedact.registerKnownSecret(bearerToken);
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        responseType: ResponseType.json,
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (_) => true,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      ),
    );
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }
  final String profileId;
  final DateTime Function() _now;
  final OrchestrationCapabilities? probedCapabilities;
  late final String _bearerToken;
  final Duration pollInterval;
  late final String _baseUrl;
  late final Dio _dio;
  PhoneEngineHealth? _health;
  PhoneEngineHealth? get health => _health;
  bool _closed = false, _deleting = false;
  Future<void>? _closing, _deletion;
  final Set<Future<void>> _inflight = {};
  final _snapshots = StreamController<TeamWorkspace>.broadcast();
  Timer? _pollTimer;
  bool _polling = false;
  final Set<void Function()> _closeListeners = {};

  /// Allows profile ownership to release clients when their caller closes them.
  void addCloseListener(void Function() listener) {
    if (_closed) {
      listener();
    } else {
      _closeListeners.add(listener);
    }
  }

  @override
  bool get isClosed => _closed || _deleting;

  /// Separate from deletion admission so the owner can drain every live client.
  bool get isDisconnected => _closed;

  void beginDeletion() {
    _deleting = true;
    _pollTimer?.cancel();
  }

  @override
  OrchestrationHostIdentity get host => OrchestrationHostIdentity(
    provider: 'phoneEngine',
    url: _baseUrl,
    hostMode: OrchestrationHostMode.phone,
    version: _health?.engineVersion,
  );

  @override
  OrchestrationCapabilities get capabilities {
    final h = _health;
    if (h == null) return probedCapabilities ?? OrchestrationCapabilities.none;
    bool all(List<TeamProjectAction> actions) =>
        actions.every(h.commandActions.contains);
    return OrchestrationCapabilities(
      projects: true,
      phoneHost: true,
      projectLifecycle: all([
        TeamProjectAction.createProject,
        TeamProjectAction.createQuickTask,
        TeamProjectAction.deleteProject,
      ]),
      livingSpec: all([
        TeamProjectAction.saveSpecDraft,
        TeamProjectAction.approveSpec,
      ]),
      projectLanes:
          h.canExecute &&
          all([
            TeamProjectAction.approvePlan,
            TeamProjectAction.pauseTask,
            TeamProjectAction.stopTask,
          ]),
      projectPlacement:
          h.canExecute &&
          all([TeamProjectAction.moveTask, TeamProjectAction.updateServer]),
      projectVerification:
          h.canExecute &&
          all([TeamProjectAction.verifyTask, TeamProjectAction.recheckTask]),
      projectMergeQueue:
          h.canExecute && all([TeamProjectAction.processMergeQueue]),
      projectPromotion: h.canExecute && all([TeamProjectAction.promote]),
      projectBudgets: all([TeamProjectAction.updateSettings]),
      projectDigest: all([TeamProjectAction.acknowledgeDigest]),
    );
  }

  Future<T> _track<T>(Future<T> Function() action) {
    if (isClosed) {
      return Future.error(const PhoneEngineException('engineClosed'));
    }
    final future = Future<T>.sync(action);
    final settled = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _inflight.add(settled);
    unawaited(settled.then((_) => _inflight.remove(settled)));
    return future;
  }

  static String? _refusalCode(Object? value, {bool allowEmpty = false}) {
    if (value is! String ||
        !(allowEmpty && value.isEmpty ||
            RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$').hasMatch(value)) ||
        KitRedact.text(value) != value) {
      return null;
    }
    return value;
  }

  Future<Object?> _request(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
  }) async {
    try {
      final transport = _closed
          ? Dio(
              BaseOptions(
                baseUrl: _baseUrl,
                followRedirects: false,
                maxRedirects: 0,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                responseType: ResponseType.json,
                validateStatus: (_) => true,
                headers: {'Authorization': 'Bearer $_bearerToken'},
              ),
            )
          : _dio;
      late final Response<Object?> response;
      try {
        response = await transport.request<Object?>(
          path,
          data: data,
          queryParameters: query,
          options: Options(method: method),
        );
      } finally {
        if (!identical(transport, _dio)) transport.close(force: true);
      }
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        final body = response.data;
        // Redirect bodies are not an engine refusal and never authorize
        // another endpoint. Every other authenticated refusal retains only
        // its bounded symbolic code, never server text or credential payloads.
        if (!(status >= 300 && status < 400) && body is Map) {
          final code = _refusalCode(body['code']);
          if (code != null) {
            if (method == 'POST' &&
                path == '/v1/commands' &&
                body['accepted'] == false &&
                body['projectId'] is String &&
                body['revision'] is int &&
                body['replayed'] is bool) {
              // Some adapters use a refusal HTTP status with the complete
              // command receipt. Preserve its reviewed metadata as well.
              return body;
            }
            throw PhoneEngineException(code);
          }
        }
        throw PhoneEngineException(
          status >= 300 && status < 400
              ? 'redirectRefused'
              : status == 401 || status == 403
              ? 'authenticationRequired'
              : 'engineUnavailable',
        );
      }
      return response.data;
    } on PhoneEngineException {
      rethrow;
    } catch (_) {
      // Ambiguous writes are never resubmitted, and no exception retains auth.
      throw PhoneEngineException(
        method == 'POST' ? 'transportUncertain' : 'engineUnavailable',
      );
    }
  }

  Future<PhoneEngineHealth> probe() => _track(() async {
    final h = PhoneEngineHealth.fromJson(
      await _request('GET', '/v1/health'),
      profileId,
    );
    _health = h;
    return h;
  });

  @override
  Future<TeamWorkspace> teamWorkspace() => _track(() async {
    _health ??= PhoneEngineHealth.fromJson(
      await _request('GET', '/v1/health'),
      profileId,
    );
    final raw = await _request('GET', '/v1/workspace');
    if (raw is! Map ||
        raw['schemaVersion'] is! int ||
        raw['schemaVersion'] != 1) {
      throw const PhoneEngineException('schemaUnsupported');
    }
    if (raw['revision'] is! int ||
        raw['simulated'] != false ||
        ['projects', 'servers', 'roles'].any((k) => raw[k] is! List)) {
      throw const PhoneEngineException('payloadInvalid');
    }
    try {
      return TeamWorkspace.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      throw const PhoneEngineException('payloadInvalid');
    }
  });

  @override
  Stream<TeamWorkspace> watchTeamWorkspace() {
    if (isClosed) {
      return Stream.error(const PhoneEngineException('engineClosed'));
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(_poll()));
    // No mutation/event replay: the authoritative snapshot is refetched.
    return _snapshots.stream;
  }

  Future<void> _poll() async {
    if (_polling || isClosed) return;
    _polling = true;
    try {
      final snapshot = await teamWorkspace();
      if (!isClosed) _snapshots.add(snapshot);
    } catch (_) {
      if (!isClosed) {
        _snapshots.addError(const PhoneEngineException('engineUnavailable'));
      }
    } finally {
      _polling = false;
    }
  }

  static const _executionActions = {
    TeamProjectAction.approvePlan,
    TeamProjectAction.resumeProject,
    TeamProjectAction.resumeTask,
    TeamProjectAction.restartTask,
    TeamProjectAction.verifyTask,
    TeamProjectAction.fixFindings,
    TeamProjectAction.recheckTask,
    TeamProjectAction.processMergeQueue,
    TeamProjectAction.resolveConflict,
    TeamProjectAction.promote,
    TeamProjectAction.undoMerge,
    TeamProjectAction.moveTask,
  };
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) =>
      _track(() async {
        try {
          final h = await probe();
          if (!h.commandActions.contains(command.action)) {
            return const TeamCommandResult(
              accepted: false,
              code: 'unsupportedCommand',
            );
          }
          if (_executionActions.contains(command.action) && !h.canExecute) {
            return TeamCommandResult(
              accepted: false,
              code: !h.boundary
                  ? 'boundaryUnverified'
                  : !h.oc1Verified || h.oc2
                  ? 'protocolUnverified'
                  : 'engineUnavailable',
            );
          }
          Object? safe(Object? v) => switch (v) {
            String s => KitRedact.text(s),
            List items => items.map(safe).toList(),
            Map items => items.map((k, v) => MapEntry(k, safe(v))),
            _ => v,
          };
          final raw = await _request(
            'POST',
            '/v1/commands',
            data: safe(command.toJson()),
          );
          if (raw is! Map ||
              raw['accepted'] is! bool ||
              raw['code'] is! String ||
              raw['projectId'] is! String ||
              raw['revision'] is! int ||
              raw['replayed'] is! bool) {
            throw const PhoneEngineException('payloadInvalid');
          }
          final code = raw['code'] as String;
          if (_refusalCode(code, allowEmpty: raw['accepted'] == true) == null) {
            throw const PhoneEngineException('payloadInvalid');
          }
          return TeamCommandResult(
            accepted: raw['accepted'] as bool,
            code: code,
            projectId: raw['projectId'] as String,
            revision: raw['revision'] as int,
            replayed: raw['replayed'] as bool,
          );
        } on PhoneEngineException catch (error) {
          return TeamCommandResult(
            accepted: false,
            code: error.code,
            projectId: command.projectId,
          );
        }
      });

  /// Observation lease, separate from executable project commands. Never retried.
  Future<void> sendChatBusy({
    required int until,
    required List<String> sessionIds,
    required List<String> directories,
    required bool known,
    required String appInstance,
    required int sequence,
  }) => _track(() async {
    final now = _now().millisecondsSinceEpoch;
    if (until <= now ||
        until > now + 30000 ||
        sequence < 0 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(appInstance) ||
        sessionIds.length > 256 ||
        directories.length > 256 ||
        [
          ...sessionIds,
          ...directories,
        ].any((s) => s.isEmpty || s.length > 4096)) {
      throw const PhoneEngineException('payloadInvalid');
    }
    final result = await _request(
      'POST',
      '/v1/chatBusy',
      data: {
        'until': until,
        'sessionIds': sessionIds.map(KitRedact.text).toList(),
        'directories': directories.map(KitRedact.text).toList(),
        'known': known,
        'appInstance': appInstance,
        'sequence': sequence,
      },
    );
    if (result is! Map || result['accepted'] != true) {
      throw const PhoneEngineException('chatAdmissionUnavailable');
    }
  });

  /// Metadata only; never forwards provider payloads, text or credentials.
  @override
  Future<List<ActivityEvent>> activity({int? afterSeq, int limit = 100}) =>
      _track(() async {
        final raw = await _request(
          'GET',
          '/v1/events',
          query: {'after': afterSeq ?? 0, 'limit': limit.clamp(1, 100)},
        );
        if (raw is! List) throw const PhoneEngineException('payloadInvalid');
        final result = <ActivityEvent>[];
        for (final item in raw) {
          if (item is! Map || item['seq'] is! int || item['type'] is! String) {
            {
              throw const PhoneEngineException('payloadInvalid');
            }
          }
          result.add(
            ActivityEvent(
              seq: item['seq'] as int,
              type: KitRedact.text(item['type'] as String),
            ),
          );
        }
        return List.unmodifiable(result);
      });

  Future<void> _drain() async {
    while (_inflight.isNotEmpty) {
      await Future.wait(_inflight.toList());
    }
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _pollTimer?.cancel();
    try {
      await _drain();
      await _snapshots.close();
    } finally {
      _dio.close(force: true);
      final listeners = _closeListeners.toList();
      _closeListeners.clear();
      for (final listener in listeners) {
        listener();
      }
    }
  }

  @override
  Future<void> deleteLocalData() => _deletion ??= _delete();
  Future<void> _delete() async {
    beginDeletion();
    await _drain();
    PhoneEngineHealth.fromJson(await _request('GET', '/v1/health'), profileId);
    final result = await _request('DELETE', '/v1/profile');
    if (result is! Map || result['deleted'] != true) {
      {
        throw const PhoneEngineException('payloadInvalid');
      }
    }
    await close();
    _dio.close(force: true);
  }
}
