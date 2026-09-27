import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/builtin_server_recovery.dart';
import 'package:opencode_mobile/builtin/phone_server_healing.dart';
import 'package:opencode_mobile/domain/while_away.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends ProfileStore {
  _Store({
    required super.prefs,
    required this.saved,
    required this.savedActiveId,
  });

  final List<ServerProfile> saved;
  String? savedActiveId;
  final updates = ChangeNotifier();

  @override
  List<ServerProfile> get profiles => saved;

  @override
  String? get activeId => savedActiveId;

  @override
  Listenable get changes => updates;
}

class _Connection extends ConnectionController {
  _Connection(super.store) : super(isIsolated: true);

  final blocked = <String>{};
  final connections = <String>[];
  final acts = <({String profileId, AutomaticActKind kind, String eventId})>[];

  @override
  bool isProfileReadable(String id) =>
      !blocked.contains(id) &&
      store.profiles.any((profile) => profile.id == id);

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async => connections.add(profile.id);

  @override
  Future<bool> recordServerAct({
    required String profileId,
    required AutomaticActKind kind,
    required String eventId,
    required DateTime at,
  }) async {
    if (!isProfileReadable(profileId)) return false;
    if (!acts.any((act) => act.eventId == eventId)) {
      acts.add((profileId: profileId, kind: kind, eventId: eventId));
    }
    return true;
  }
}

class _Linux extends BuiltinLinux {
  bool running = false;
  bool healthy = true;
  bool wanted = true;
  int generation = 0;
  int restarts = 0;

  @override
  Future<BuiltinLinuxStatus> status() async => BuiltinLinuxStatus(
    installed: true,
    phase: BuiltinLinuxPhase.ready,
    serverRunning: running,
    serverRestartWanted: wanted,
    serverRecoveryGeneration: generation,
  );

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async => const BuiltinLinuxRunResult(exitCode: 0, output: '');

  @override
  Future<void> restartServer(
    String script, {
    int port = 4097,
    required int expectedGeneration,
  }) async {
    if (!wanted || generation != expectedGeneration) {
      throw const BuiltinLinuxException('The server cannot restart.');
    }
    restarts++;
    running = true;
  }

  @override
  Future<void> startServer(String script, {int port = 4097}) async {
    wanted = true;
    running = true;
  }

  @override
  Future<void> confirmServerRecovery({required int expectedGeneration}) async {
    if (!wanted || !running || expectedGeneration != generation) {
      throw const BuiltinLinuxException('The restart is not confirmed.');
    }
  }

  @override
  Future<void> cancelServerRecovery() async => generation++;
}

ServerProfile _phone(String id) => ServerProfile(
  id: id,
  name: 'This phone',
  baseUrl: BuiltinLinux.serverUrl,
  username: BuiltinLinux.serverUsername,
)..password = 'synthetic-password';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _Store store;
  late _Connection connection;
  late _Linux linux;
  late BuiltinServerStarter starter;
  PhoneServerHealing? healing;
  late ServerProfile phone;

  setUp(() async {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    AutomationPolicyController.resetShared();
    phone = _phone('phone');
    store = _Store(prefs: prefs, saved: [phone], savedActiveId: phone.id);
    connection = _Connection(store);
    linux = _Linux();
    starter = BuiltinServerStarter(
      linux: linux,
      readyTimeout: Duration.zero,
      pollInterval: Duration.zero,
    );
    serverProbe = ({required baseUrl, username, password}) async =>
        linux.running && linux.healthy
        ? const ServerProbeResult.success('1')
        : const ServerProbeResult.failure('Unavailable');
  });

  tearDown(() {
    healing?.dispose();
    healing = null;
    starter.dispose();
    connection.dispose();
    store.updates.dispose();
    AutomationPolicyController.resetShared();
    debugPlatformCapabilities = null;
    serverProbe = probeServerConnection;
  });

  PhoneServerHealing bind() => healing = PhoneServerHealing(
    connection: connection,
    starter: starter,
    createRecovery: (record) => BuiltinServerRecovery(
      store: store,
      linux: linux,
      starter: starter,
      onRestart: record,
    ),
  );

  test(
    'app-lifetime owner heals only in foreground and reconnects once',
    () async {
      final owner = bind();
      await owner.check(phone);
      expect(linux.restarts, 0);
      expect(connection.acts, isEmpty);

      owner.setForeground(true);
      await owner.check(phone);
      expect(linux.restarts, 1);
      expect(connection.acts, hasLength(1));
      expect(connection.acts.single.kind, AutomaticActKind.restart);
      expect(connection.connections, [phone.id]);
      await owner.check(phone);
      await owner.connectIfNeeded(phone);
      expect(connection.acts, hasLength(1));
      expect(connection.connections, [phone.id]);

      owner.setForeground(false);
      linux.running = false;
      await owner.check(phone);
      expect(linux.restarts, 1);
    },
  );

  test(
    'persisted runtime owner wins over another selected local profile',
    () async {
      final other = _phone('other');
      store.saved.add(other);
      store.savedActiveId = other.id;
      await prefs.setString(PhoneServerHealing.ownerKey, phone.id);
      final owner = bind()..setForeground(true);
      await owner.check(phone);
      await owner.check(other);
      expect(linux.restarts, 1);
      expect(connection.acts.single.profileId, phone.id);
      expect(connection.connections, isEmpty);
      expect(
        prefs.containsKey(BuiltinServerRecovery.keyFor(other.id)),
        isFalse,
      );
    },
  );

  test(
    'a restart confirmed after its initial timeout still reconnects',
    () async {
      linux.healthy = false;
      final owner = bind()..setForeground(true);
      await owner.check(phone);
      expect(linux.restarts, 1);
      expect(starter.failureFor(phone), isNotNull);
      expect(connection.acts, isEmpty);
      expect(connection.connections, isEmpty);

      linux.healthy = true;
      await owner.check(phone);
      expect(linux.restarts, 1);
      expect(starter.failureFor(phone), isNull);
      expect(connection.acts, hasLength(1));
      expect(connection.connections, [phone.id]);
    },
  );

  test(
    'ambiguous legacy profiles wait for an explicit Start to claim ownership',
    () async {
      final other = _phone('other');
      store.saved.add(other);
      final owner = bind()..setForeground(true);
      await owner.check(phone);
      await owner.check(other);
      expect(linux.restarts, 0);
      expect(connection.acts, isEmpty);

      expect(await starter.start(other), isNull);
      expect(prefs.getString(PhoneServerHealing.ownerKey), other.id);
      await owner.check(other);
      expect(connection.acts, isEmpty);
      linux.running = false;
      await owner.check(other);
      expect(linux.restarts, 1);
      expect(connection.acts.single.profileId, other.id);
    },
  );

  test(
    'the shared restart policy and explicit Stop each prevent healing',
    () async {
      final policy = AutomationPolicyController.forProfile(prefs, phone.id);
      await policy.setBehavior(AutomationBehavior.restartPhoneServer, false);
      final owner = bind()..setForeground(true);
      await owner.check(phone);
      expect(linux.restarts, 0);

      linux.wanted = false;
      await policy.setBehavior(AutomationBehavior.restartPhoneServer, true);
      await owner.check(phone);
      expect(linux.restarts, 0);
      expect(connection.acts, isEmpty);
    },
  );

  test(
    'explicit connect works with automatic reconnect off and shares deduplication',
    () async {
      final policy = AutomationPolicyController.forProfile(prefs, phone.id);
      await policy.setBehavior(AutomationBehavior.reconnect, false);
      linux.wanted = false;
      final owner = bind()..setForeground(true);
      await owner.check(phone);

      await owner.connectIfNeeded(phone);
      expect(connection.connections, isEmpty);
      await owner.connectIfNeeded(phone, automatic: false);
      expect(connection.connections, [phone.id]);

      await policy.setBehavior(AutomationBehavior.reconnect, true);
      await owner.connectIfNeeded(phone);
      await owner.connectIfNeeded(phone, automatic: false);
      expect(connection.connections, [phone.id]);
      expect(linux.restarts, 0);
    },
  );

  test(
    'profile deletion admission cannot be reopened by a store notification',
    () async {
      connection.blocked.add(phone.id);
      final owner = bind()..setForeground(true);
      store.updates.notifyListeners();
      await owner.check(phone);
      expect(linux.restarts, 0);
      expect(connection.acts, isEmpty);
      expect(
        prefs.containsKey(BuiltinServerRecovery.keyFor(phone.id)),
        isFalse,
      );

      connection.blocked.clear();
      connection.notifyListeners();
      await owner.check(phone);
      expect(linux.restarts, 1);
      expect(connection.acts, hasLength(1));
    },
  );
}
