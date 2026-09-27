import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/setup_assistant.dart';
import '../ui/kit/kit_redact.dart';

/// Profile-and-location-bound review coordinator. Recreate on location change;
/// dispose before deleting a profile. Nothing queues writes while offline.
class SetupController {
  SetupController({
    required this.gateway,
    required this.prefs,
    required this.profileId,
    required this.locationId,
  }) {
    if (profileId.isEmpty || locationId.isEmpty) {
      throw ArgumentError('Setup requires a profile and location.');
    }
  }
  final SetupConfigGateway gateway;
  final SharedPreferences prefs;
  final String profileId;
  final String locationId;
  String get auditKey => 'oc.setupAudit.$profileId';
  final _events = StreamController<SetupSnapshot>.broadcast();
  Stream<SetupSnapshot> get changes => _events.stream;
  SetupSnapshot get snapshot => _snapshot;
  SetupSupport get support => gateway.support;
  SetupSnapshot _snapshot = const SetupSnapshot();
  Map<String, Object?>? _base;
  Map<String, Object?>? _expected;
  List<SetupEdit> _edits = const [];
  List<SetupEdit> _inverse = const [];
  bool _online = true, _busy = false, _disposed = false;
  int _sequence = 0;
  Completer<void>? _finished;

  void setOnline(bool online) {
    _online = online;
    if (!online) {
      _emit(
        SetupSnapshot(
          phase: SetupPhase.offline,
          config: _snapshot.config,
          servers: _snapshot.servers,
          reason: 'Reconnect to your server to refresh or apply changes.',
        ),
      );
    }
  }

  Future<void> refresh() => _run(() async {
    _requireOnline();
    if (!support.readConfig) {
      throw SetupFailure(SetupFailureCode.unsupported, support.reason);
    }
    _emit(const SetupSnapshot(phase: SetupPhase.loading));
    final config = await gateway.readConfig();
    final servers = support.mcpInventory
        ? await gateway.listMcpServers()
        : <SetupMcpStatus>[];
    _requireOnline();
    _base = _clone(config);
    _edits = const [];
    _emit(
      SetupSnapshot(
        phase: config.isEmpty && servers.isEmpty
            ? SetupPhase.empty
            : SetupPhase.ready,
        config: setupRedact(config) as Map<String, Object?>,
        servers: List.unmodifiable(
          servers.map(
            (s) => SetupMcpStatus(
              name: KitRedact.text(s.name),
              status: _status(s.status),
            ),
          ),
        ),
        canUndo: _inverse.isNotEmpty,
      ),
    );
  });

  /// Returns a reviewable diff. Validation is local and cannot prove that a
  /// server accepts a schema or that a package can run on its host.
  Future<SetupProposal> propose(List<SetupEdit> edits) => _run(() async {
    if (_base == null) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'Read the current configuration first.',
      );
    }
    if (_base!.containsKey('sources')) {
      throw const SetupFailure(
        SetupFailureCode.unsupported,
        'This server returns layered sources. Effective-config diffs are unavailable.',
      );
    }
    final errors = validate(edits);
    if (errors.isNotEmpty) {
      throw SetupFailure(SetupFailureCode.invalid, errors.first);
    }
    _edits = edits
        .map(
          (e) => SetupEdit(
            path: List.unmodifiable(e.path),
            value: jsonDecode(jsonEncode(e.value)),
            remove: e.remove,
          ),
        )
        .toList(growable: false);
    final reversible = _edits.every(
      (e) =>
          !e.remove &&
          _has(_base!, e.path) &&
          _at(_base!, e.path) != null &&
          _at(_base!, e.path) is! Map &&
          e.value is! Map,
    );
    final proposal = SetupProposal(
      id: 'proposal-${++_sequence}',
      changes: _edits
          .map(
            (e) => SetupDiff(
              path: e.path,
              before: setupRedact(_at(_base!, e.path), e.path.last),
              after: setupRedact(e.value, e.path.last),
              remove: e.remove,
            ),
          )
          .toList(),
      canApply: support.writeConfig && reversible && _online,
      reason: !support.writeConfig
          ? support.reason
          : !reversible
          ? 'This change needs a reversible config-write endpoint before it can be applied.'
          : !_online
          ? 'Reconnect to your server before applying.'
          : null,
    );
    await _audit(proposal.id, 'proposed');
    _emit(
      SetupSnapshot(
        phase: _online ? SetupPhase.ready : SetupPhase.offline,
        config: _snapshot.config,
        servers: _snapshot.servers,
        proposal: proposal,
        canUndo: _inverse.isNotEmpty,
      ),
    );
    return proposal;
  });

  List<String> validate(List<SetupEdit> edits) {
    if (edits.isEmpty || edits.length > 32) {
      return ['Choose between one and 32 changes.'];
    }
    const roots = {
      'model',
      'small_model',
      'default_agent',
      'provider',
      'providers',
      'agent',
      'agents',
      'permission',
      'permissions',
      'command',
      'commands',
      'mcp',
    };
    for (final edit in edits) {
      if (edit.path.isEmpty ||
          !roots.contains(edit.path.first) ||
          edit.path.any(
            (s) => !RegExp(r'^[a-zA-Z0-9_./:@*-]{1,160}$').hasMatch(s),
          )) {
        return ['Choose a supported configuration field.'];
      }
      if (!edit.remove) {
        final root = edit.path.first;
        if (const {'model', 'small_model', 'default_agent'}.contains(root) &&
            (edit.path.length != 1 ||
                edit.value is! String ||
                (edit.value as String).trim().isEmpty)) {
          return ['Choose a valid model or agent identifier.'];
        }
        if (root == 'permission' &&
            (edit.path.length != 2 ||
                !const {'allow', 'ask', 'deny'}.contains(edit.value))) {
          return ['Choose an allow, ask, or deny permission rule.'];
        }
        if (root == 'mcp' && edit.path.length == 2) {
          final value = edit.value;
          if (value is! Map ||
              !const {'local', 'remote'}.contains(value['type']) ||
              value['enabled'] != false) {
            return [
              'A new MCP proposal must specify its type and start disabled.',
            ];
          }
          if (value['type'] == 'local' &&
              (value['command'] is! List ||
                  (value['command'] as List).isEmpty ||
                  (value['command'] as List).any(
                    (v) => v is! String || v.trim().isEmpty,
                  ))) {
            return ['Choose a valid command for the local MCP server.'];
          }
          if (value['type'] == 'remote') {
            final uri = value['url'] is String
                ? Uri.tryParse(value['url'] as String)
                : null;
            if (uri == null ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty ||
                uri.hasQuery ||
                uri.hasFragment ||
                !(uri.scheme == 'https' ||
                    (uri.scheme == 'http' &&
                        const {
                          'localhost',
                          '127.0.0.1',
                          '::1',
                        }.contains(uri.host)))) {
              return [
                'Choose an HTTPS or local loopback MCP URL without credentials.',
              ];
            }
          }
        }
      }
      // Raw credentials must use the existing sign-in/secret entry flows.
      final wrapped = <String, Object?>{};
      _put(wrapped, edit.path, edit.value);
      final raw = jsonEncode(wrapped);
      if (raw.length > 32768 ||
          KitRedact.containsSecret(raw) ||
          raw.contains(KitRedact.mask)) {
        return [
          'Use the existing sign-in or secret entry flow for credentials.',
        ];
      }
      if (RegExp(
            r'key|token|secret|password|credential|environment|headers|options',
            caseSensitive: false,
          ).hasMatch(edit.path.join('.')) ||
          _sensitiveMap(edit.value)) {
        return [
          'Use the existing sign-in or secret entry flow for credentials.',
        ];
      }
      if (!edit.remove && edit.value == null) {
        return ['A configuration value is required.'];
      }
    }
    for (var i = 0; i < edits.length; i++) {
      for (var j = i + 1; j < edits.length; j++) {
        final a = edits[i].path, b = edits[j].path;
        if (_prefix(a, b) || _prefix(b, a)) {
          return ['Review overlapping fields as separate proposals.'];
        }
      }
    }
    return const [];
  }

  /// Explicit confirmation of this exact, controller-owned proposal is needed.
  /// Current production adapters deliberately reject all writes.
  Future<void> apply(
    String proposalId, {
    required bool confirmed,
  }) => _run(() async {
    _requireOnline();
    if (!support.writeConfig) {
      throw SetupFailure(SetupFailureCode.unsupported, support.reason);
    }
    final proposal = _snapshot.proposal;
    if (!confirmed ||
        proposal == null ||
        proposal.id != proposalId ||
        !proposal.canApply) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'Review and confirm the current proposal first.',
      );
    }
    final current = await gateway.readConfig();
    if (!_same(current, _base)) {
      throw const SetupFailure(
        SetupFailureCode.conflict,
        'Configuration changed on the server. Refresh and review a new proposal.',
      );
    }
    final inverse = _edits
        .map((e) => SetupEdit(path: e.path, value: _at(current, e.path)))
        .toList();
    await _write(proposalId, _edits, current);
    _inverse = inverse;
    _emit(
      SetupSnapshot(
        phase: SetupPhase.ready,
        config: setupRedact(_expected) as Map<String, Object?>,
        servers: _snapshot.servers,
        canUndo: true,
      ),
    );
  });

  Future<void> undo({required bool confirmed}) => _run(() async {
    _requireOnline();
    if (!support.writeConfig) {
      throw SetupFailure(SetupFailureCode.unsupported, support.reason);
    }
    if (!confirmed || _inverse.isEmpty) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'There is no confirmed change to undo in this setup session.',
      );
    }
    final current = await gateway.readConfig();
    if (!_same(current, _expected)) {
      throw const SetupFailure(
        SetupFailureCode.conflict,
        'Configuration changed after Apply. Refresh before making another change.',
      );
    }
    final inverse = _inverse;
    await _write('undo-${++_sequence}', inverse, current);
    _inverse = const [];
    _emit(
      SetupSnapshot(
        phase: SetupPhase.ready,
        config: setupRedact(_expected) as Map<String, Object?>,
        servers: _snapshot.servers,
      ),
    );
  });

  Future<void> _write(
    String id,
    List<SetupEdit> edits,
    Map<String, Object?> current,
  ) async {
    await _audit(
      id,
      'pending',
    ); // Fail before mutation if durable audit is unavailable.
    _requireOnline();
    final patch = <String, Object?>{};
    final expected = _clone(current);
    for (final edit in edits) {
      _put(patch, edit.path, edit.value);
      _put(expected, edit.path, edit.value);
    }
    try {
      await gateway.patchConfig(patch);
      final actual = await gateway.readConfig();
      if (!_same(actual, expected)) {
        throw const SetupFailure(
          SetupFailureCode.uncertain,
          'Refresh to inspect the server configuration.',
        );
      }
      await _audit(id, 'verified');
      _base = _clone(actual);
      _expected = _clone(actual);
    } catch (_) {
      _base = null;
      _inverse = const [];
      try {
        await _audit(id, 'uncertain');
      } catch (_) {
        /* pending remains durable */
      }
      throw const SetupFailure(
        SetupFailureCode.uncertain,
        'The change outcome is unknown. Refresh before trying again.',
      );
    } finally {
      _edits = const [];
    }
  }

  /// Audit stores metadata only, never configs, prompts, diffs, or credentials.
  List<Map<String, Object?>> get audit {
    try {
      final list = jsonDecode(prefs.getString(auditKey) ?? '[]') as List;
      return List.unmodifiable(
        list.whereType<Map>().map(
          (e) => Map<String, Object?>.unmodifiable({
            'id': KitRedact.text(e['id'] is String ? e['id'] as String : ''),
            'action': KitRedact.text(
              e['action'] is String ? e['action'] as String : '',
            ),
            'at': KitRedact.text(e['at'] is String ? e['at'] as String : ''),
          }),
        ),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _audit(String id, String action) async {
    if (_disposed) {
      throw const SetupFailure(SetupFailureCode.offline, 'Setup is closed.');
    }
    final records = [
      ...audit,
      {
        'id': KitRedact.text(id),
        'action': KitRedact.text(action),
        'at': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    final bounded = records.length > 100
        ? records.sublist(records.length - 100)
        : records;
    try {
      if (!await prefs.setString(
        auditKey,
        KitRedact.text(jsonEncode(bounded)),
      )) {
        throw StateError('storage');
      }
    } catch (_) {
      throw const SetupFailure(
        SetupFailureCode.storage,
        'The setup audit could not be saved. No new change was started.',
      );
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    if (_disposed || _busy) {
      throw const SetupFailure(
        SetupFailureCode.busy,
        'Setup is busy or closed.',
      );
    }
    _busy = true;
    _finished = Completer<void>();
    try {
      return await action();
    } catch (error) {
      final failure = error is SetupFailure
          ? error
          : const SetupFailure(
              SetupFailureCode.transport,
              'Could not contact the setup service.',
            );
      final phase = switch (failure.code) {
        SetupFailureCode.offline => SetupPhase.offline,
        SetupFailureCode.unsupported => SetupPhase.unsupported,
        SetupFailureCode.needsSignIn => SetupPhase.needsSignIn,
        _ => SetupPhase.error,
      };
      _emit(
        SetupSnapshot(
          phase: phase,
          config: _snapshot.config,
          servers: _snapshot.servers,
          reason: KitRedact.text(failure.message),
        ),
      );
      throw failure;
    } finally {
      _busy = false;
      _finished?.complete();
    }
  }

  void _requireOnline() {
    if (!_online || _disposed) {
      throw const SetupFailure(
        SetupFailureCode.offline,
        'Reconnect to your server before continuing.',
      );
    }
  }

  void _emit(SetupSnapshot value) {
    if (!_disposed) {
      _snapshot = value;
      _events.add(value);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _finished?.future;
    _base = null;
    _expected = null;
    _edits = const [];
    _inverse = const [];
    _snapshot = const SetupSnapshot();
    await _events.close();
  }

  static bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          Iterable<int>.generate(a.length).every((i) => _same(a[i], b[i]));
    }
    return a == b;
  }

  static Map<String, Object?> _clone(Map<String, Object?> value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
  static String _status(String status) =>
      const {
        'connected',
        'pending',
        'disabled',
        'failed',
        'needs_auth',
        'needs_client_registration',
      }.contains(status)
      ? status
      : 'unknown';
  static bool _prefix(List<String> a, List<String> b) =>
      a.length <= b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
  static bool _sensitiveMap(Object? value) {
    if (value is Map) {
      return value.entries.any(
        (e) =>
            RegExp(
              r'key|token|secret|password|credential|environment|headers|options',
              caseSensitive: false,
            ).hasMatch(e.key.toString()) ||
            _sensitiveMap(e.value),
      );
    }
    if (value is List) return value.any(_sensitiveMap);
    return false;
  }

  static Object? _at(Map<String, Object?> map, List<String> path) {
    Object? at = map;
    for (final part in path) {
      if (at is! Map) return null;
      at = at[part];
    }
    return at;
  }

  static bool _has(Map<String, Object?> map, List<String> path) {
    Object? at = map;
    for (final part in path) {
      if (at is! Map || !at.containsKey(part)) return false;
      at = at[part];
    }
    return true;
  }

  static void _put(Map<String, Object?> map, List<String> path, Object? value) {
    var at = map;
    for (final part in path.take(path.length - 1)) {
      final child = at[part];
      at[part] = child is Map
          ? Map<String, Object?>.from(child)
          : <String, Object?>{};
      at = at[part] as Map<String, Object?>;
    }
    at[path.last] = value;
  }
}
