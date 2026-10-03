// Shared fixtures for shared-settings-1's behaviour and golden tests: an
// in-memory secure store (ProfileStore.upsert needs one, AGENTS.md testing
// traps), a scripted team probe and a connection controller on a tailnet
// server with no AI team yet.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySecureStorage extends FlutterSecureStorage {
  MemorySecureStorage();
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.of(values);
}

/// A profile store whose saves can be made to fail after boot.
class FlakyProfileStore extends ProfileStore {
  FlakyProfileStore({required super.prefs, required super.secure});
  bool fail = false;

  @override
  Future<void> upsert(ServerProfile profile) async {
    if (fail) throw StateError('Storage unavailable');
    await super.upsert(profile);
  }
}

/// What the probe finds on the workstation's front-less supervisor.
ProbeFound foundTeam() => ProbeFound(
  host: const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://100.100.1.2:8372',
    hostMode: OrchestrationHostMode.computer,
    version: '1.4.1',
    city: 'bright-lights',
  ),
  version: '1.4.1',
  city: 'bright-lights',
  readOnly: true,
);

/// Answers only the supervisor port with [foundTeam].
Future<ProbeVerdict> teamProbe(String url, {String? city}) async =>
    url == 'http://100.100.1.2:8372'
    ? foundTeam()
    : const ProbeUnreachable(error: 'no answer');

/// A controller connected to "Workstation" (no AI team configured) on a
/// [FlakyProfileStore].
Future<(ConnectionController, FlakyProfileStore)> bootWorkstation() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = FlakyProfileStore(prefs: prefs, secure: MemorySecureStorage());
  final profile = ServerProfile(
    id: 'workstation',
    name: 'Workstation',
    baseUrl: 'http://100.100.1.2:4096',
  );
  await store.upsert(profile);
  await store.setActiveId(profile.id);
  final controller = ConnectionController(store);
  controller.adoptConnectedProfileForTesting(profile);
  controller.syncOrchestration();
  return (controller, store);
}
