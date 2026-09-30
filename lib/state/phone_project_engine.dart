import 'dart:async';

import '../builtin/builtin_linux.dart';
import '../domain/phone_project_engine.dart';
import '../domain/orchestration_gateway.dart';
import '../orchestration/adapters/inapp/phone_engine_gateway.dart';
import '../orchestration/adapters/gascity/gascity_probe.dart';
import '../ui/kit/kit_redact.dart';
import 'profiles.dart';

/// Small native seam: callers cannot start shell scripts or inject credentials.
abstract interface class PhoneProjectEngineBridge {
  Future<void> start(String profileId, {int port = 4098, String? notice});
  Future<({String baseUrl, String bearerToken})> credentials(String profileId);
  Future<void> delete(String profileId);
}

class BuiltinPhoneProjectEngineBridge implements PhoneProjectEngineBridge {
  BuiltinPhoneProjectEngineBridge([BuiltinLinux? builtin])
    : _builtin = builtin ?? BuiltinLinux();
  final BuiltinLinux _builtin;
  @override
  Future<void> start(
    String profileId, {
    int port = 4098,
    String? notice,
  }) async {
    await _builtin.startPhoneEngine(
      profileId: profileId,
      port: port,
      notice: notice,
    );
  }

  @override
  Future<({String baseUrl, String bearerToken})> credentials(
    String profileId,
  ) async {
    final value = await _builtin.phoneEngineCredentials(profileId);
    return (baseUrl: value.baseUrl, bearerToken: value.bearerToken);
  }

  @override
  Future<void> delete(String profileId) =>
      _builtin.deletePhoneEngine(profileId);
}

typedef PhoneEngineGatewayBuilder = PhoneEngineGateway Function({
  required String baseUrl,
  required String profileId,
  required String bearerToken,
});

/// Profile-owned lifecycle, including inactive profiles. Never auto-starts daemon.
class PhoneProjectEngineController {
  PhoneProjectEngineController({
    required this.store,
    PhoneProjectEngineBridge? bridge,
    PhoneEngineGatewayBuilder? gatewayBuilder,
    this.onAttached,
  }) : bridge = bridge ?? BuiltinPhoneProjectEngineBridge(),
       _build = gatewayBuilder ?? _defaultBuild;
  final ProfileStore store;
  final void Function(String profileId)? onAttached;
  final PhoneProjectEngineBridge bridge;
  final PhoneEngineGatewayBuilder _build;
  final Map<String, Set<PhoneEngineGateway>> _gateways = {};
  final Map<String, Future<void>> _tails = {};
  final Set<String> _deleted = {};
  bool _closed = false;
  final Map<String, Future<void>> _deletions = {};
  static PhoneEngineGateway _defaultBuild({
    required String baseUrl,
    required String profileId,
    required String bearerToken,
  }) => PhoneEngineGateway(
    baseUrl: baseUrl,
    profileId: profileId,
    bearerToken: bearerToken,
  );
  String _tombstone(String id) => 'oc.teamEngineDeleted.$id';
  bool _blocked(String id) =>
      _deleted.contains(id) || store.prefs.getBool(_tombstone(id)) == true;
  ServerProfile _profile(String id) => store.profiles.firstWhere(
    (p) => p.id == id,
    orElse: () => throw const PhoneEngineException('profileMissing'),
  );
  Future<T> _serial<T>(String id, Future<T> Function() action) {
    if (_closed)
      return Future.error(const PhoneEngineException('engineClosed'));
    if (_blocked(id))
      return Future.error(const PhoneEngineException('profileDeleted'));
    final next = (_tails[id] ?? Future<void>.value()).then((_) async {
      if (_blocked(id)) throw const PhoneEngineException('profileDeleted');
      return action();
    });
    _tails[id] = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  PhoneEngineGateway gateway(ServerProfile profile) {
    if (_closed) throw const PhoneEngineException('engineClosed');
    if (_blocked(profile.id))
      throw const PhoneEngineException('profileDeleted');
    final config = profile.orchestration;
    if (config?.provider != OrchestrationProvider.phoneEngine) {
      throw const PhoneEngineException('engineUnavailable');
    }
    final client = _build(
      baseUrl: config!.url,
      profileId: profile.id,
      bearerToken: profile.teamEngineAuth,
    );
    (_gateways[profile.id] ??= {}).add(client);
    return client;
  }

  Future<PhoneEngineHealth> start(
    String profileId, {
    int port = 4098,
    String? notice,
  }) => _serial(profileId, () async {
    if (port < 1 || port > 65535)
      throw const PhoneEngineException('endpointInvalid');
    try {
      await bridge.start(profileId, port: port, notice: notice);
    } catch (_) {
      throw const PhoneEngineException('engineUnavailable');
    }
    return _attach(profileId);
  });
  Future<PhoneEngineHealth> attach(String profileId) =>
      _serial(profileId, () => _attach(profileId));
  Future<PhoneEngineHealth> _attach(String profileId) async {
    final profile = _profile(profileId);
    late final ({String baseUrl, String bearerToken}) credentials;
    try {
      credentials = await bridge.credentials(profileId);
    } catch (_) {
      throw const PhoneEngineException('engineUnavailable');
    }
    KitRedact.registerKnownSecret(credentials.bearerToken);
    final client = _build(
      baseUrl: credentials.baseUrl,
      profileId: profileId,
      bearerToken: credentials.bearerToken,
    );
    try {
      final h = await client.probe();
      if (_closed) throw const PhoneEngineException('engineClosed');
      if (_blocked(profileId))
        throw const PhoneEngineException('profileDeleted');
      final previousConfig = profile.orchestration;
      final previousAuth = profile.teamEngineAuth;
      profile.teamEngineAuth = credentials.bearerToken;
      profile.orchestration = OrchestrationConfig(
        provider: OrchestrationProvider.phoneEngine,
        url: credentials.baseUrl,
        hostMode: OrchestrationHostMode.phone,
        enabledAt: previousConfig?.enabledAt ?? DateTime.now(),
      );
      try {
        await store.upsert(profile);
      } catch (_) {
        profile.orchestration = previousConfig;
        profile.teamEngineAuth = previousAuth;
        throw const PhoneEngineException('authSaveFailed');
      }
      if (_blocked(profileId))
        throw const PhoneEngineException('profileDeleted');
      onAttached?.call(profileId);
      return h;
    } finally {
      await client.close();
    }
  }

  Future<PhoneEngineHealth> probe(String profileId) =>
      _serial(profileId, () async {
        final client = gateway(_profile(profileId));
        try {
          return await client.probe();
        } finally {
          await client.close();
        }
      });
  Future<ProbeVerdict> orchestrationProbe(ServerProfile profile) async {
    PhoneEngineGateway? client;
    try {
      client = gateway(profile);
      final h = await client.probe();
      return ProbeFound(
        host: client.host,
        version: h.engineVersion,
        readOnly: !h.canExecute,
        capabilities: client.capabilities,
      );
    } catch (_) {
      return const ProbeUnreachable(error: 'Phone engine unavailable');
    } finally {
      await client?.close();
    }
  }

  Future<OrchestrationGateway> orchestrationGateway(
    ServerProfile profile,
  ) async {
    final client = gateway(profile);
    try {
      await client.probe();
      return client;
    } catch (_) {
      await client.close();
      rethrow;
    }
  }

  /// Native deletion is authoritative even when a stopped daemon cannot answer.
  Future<void> deleteProfile(String profileId) {
    _deleted.add(profileId);
    for (final client in _gateways[profileId] ?? <PhoneEngineGateway>{}) {
      client.beginDeletion();
    }
    return _deletions[profileId] ??= _delete(profileId).whenComplete(() {
      _deletions.remove(profileId);
    });
  }

  Future<void> _delete(String profileId) async {
    if (!await store.prefs.setBool(_tombstone(profileId), true)) {
      throw const PhoneEngineException('deleteFailed');
    }
    await _tails[profileId];
    final clients = _gateways.remove(profileId) ?? <PhoneEngineGateway>{};
    final active = clients.where((client) => !client.isDisconnected).toList();
    // Deletion may precede any screen attaching after restart.
    if (active.isEmpty) {
      for (final profile in store.profiles) {
        if (profile.id == profileId &&
            profile.orchestration?.provider ==
                OrchestrationProvider.phoneEngine &&
            profile.teamEngineAuth.isNotEmpty) {
          try {
            active.add(
              _build(
                baseUrl: profile.orchestration!.url,
                profileId: profileId,
                bearerToken: profile.teamEngineAuth,
              ),
            );
          } catch (_) {
            /* Native cleanup remains authoritative. */
          }
        }
      }
    }
    for (final client in active) {
      try {
        await client.deleteLocalData();
      } catch (_) {
        await client.close();
      }
    }
    for (final client in clients) {
      await client.close();
    }
    try {
      await bridge.delete(profileId);
    } catch (_) {
      throw const PhoneEngineException('deleteFailed');
    }
    try {
      await store.secure.delete(
        key: '${ProfileStore.teamEngineAuthKey}$profileId',
      );
    } catch (_) {
      throw const PhoneEngineException('deleteFailed');
    }
    for (final profile in store.profiles) {
      if (profile.id == profileId) profile.teamEngineAuth = '';
    }
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait(_tails.values.toList());
    for (final clients in _gateways.values) {
      for (final client in clients) {
        await client.close();
      }
    }
    _gateways.clear();
  }
}
