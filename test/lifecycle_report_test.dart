import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/state/lifecycle_report.dart';
import 'package:opencode_mobile/state/profiles.dart';

class _Linux extends BuiltinLinux {
  bool installed = true;
  bool running = true;
  bool teamRunning = false;
  int reads = 0;
  Object? error;

  @override
  Future<BuiltinLinuxStatus> status() async {
    reads++;
    if (error != null) throw error!;
    return BuiltinLinuxStatus(
      installed: installed,
      phase: BuiltinLinuxPhase.ready,
      serverRunning: running,
      services: [if (teamRunning) BuiltinTeam.serviceName],
    );
  }
}

class _Bridge extends AppLifecycleBridge {
  int reads = 0;
  Object? error;
  AppLaunchReport report = AppLaunchReport(
    exit: AppExitRecord(
      reason: AndroidExitReason.userRequested,
      timestamp: DateTime(2026, 9, 27, 14, 2),
      description: 'password=fake-native-secret',
    ),
    previousServices: const ['server'],
  );

  @override
  Future<AppLaunchReport> launchReport() async {
    reads++;
    if (error != null) throw error!;
    return report;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Linux linux;
  late _Bridge bridge;
  late LifecycleReportController controller;
  late ServerProfile profile;
  late Future<ServerProbeResult> Function() health;
  late List<Uri> teamRequests;
  late bool supervisorHealthy;
  late bool cityHealthy;
  late int probes;

  setUp(() {
    linux = _Linux();
    bridge = _Bridge();
    teamRequests = [];
    supervisorHealthy = true;
    cityHealthy = true;
    probes = 0;
    profile = ServerProfile(
      id: 'phone',
      name: 'Phone',
      baseUrl: BuiltinLinux.serverUrl,
    )..password = 'fake-serve-password';
    health = () async => const ServerProbeResult.success('fixture');
    controller = LifecycleReportController(
      linux: linux,
      bridge: bridge,
      team: BuiltinTeam(
        linux: linux,
        httpGet: (uri) async {
          teamRequests.add(uri);
          final healthy = uri.path == '/health'
              ? supervisorHealthy
              : cityHealthy;
          return healthy ? '{"status":"ok"}' : null;
        },
      ),
      probe: ({required baseUrl, username, password}) {
        probes++;
        expect(baseUrl, BuiltinLinux.serverUrl);
        // Compare a boolean so even a failed assertion cannot print credentials.
        expect(password == profile.password, isTrue);
        return health();
      },
    );
  });

  tearDown(() => controller.dispose());

  test(
    'exit time is available but recovery waits for authenticated health',
    () async {
      final pending = Completer<ServerProbeResult>();
      health = () => pending.future;
      final refresh = controller.refresh(profile);
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.readiness, LifecycleReadiness.checking);
      expect(controller.value.everythingBack, isFalse);
      pending.complete(const ServerProbeResult.success('fixture'));
      await refresh;
      expect(controller.value.exitKind, AppExitKind.forceStop);
      expect(controller.value.stoppedAt, DateTime(2026, 9, 27, 14, 2));
      expect(controller.value.showNotice, isTrue);
      expect(controller.value.everythingBack, isTrue);
    },
  );

  test(
    'a process without an answering server never counts as recovered',
    () async {
      health = () async => const ServerProbeResult.failure('unreachable');
      await controller.refresh(profile);
      expect(controller.value.readiness, LifecycleReadiness.unreachable);
      expect(controller.value.everythingBack, isFalse);
    },
  );

  test('missing credentials do not probe or claim recovery', () async {
    profile.password = '';
    await controller.refresh(profile);
    expect(probes, 0);
    expect(controller.value.readiness, LifecycleReadiness.unreachable);
    expect(controller.value.everythingBack, isFalse);
    profile.password = 'fake-serve-password';
    profile.requiresPasswordReentry = true;
    await controller.refresh(profile);
    expect(probes, 0);
    expect(controller.value.everythingBack, isFalse);
  });

  test(
    'a crash is attributed to the app rather than a phone setting',
    () async {
      bridge.report = AppLaunchReport(
        exit: AppExitRecord(
          reason: AndroidExitReason.crash,
          timestamp: DateTime(2026, 9, 27, 14, 2),
        ),
        previousServices: const ['server'],
      );
      await controller.refresh(profile);
      expect(controller.value.exitKind, AppExitKind.crash);
      expect(controller.value.everythingBack, isTrue);
    },
  );

  test(
    'stopped and uninstalled servers are distinct and never probed',
    () async {
      linux.running = false;
      await controller.refresh(profile);
      expect(controller.value.readiness, LifecycleReadiness.stopped);
      linux.installed = false;
      await controller.refresh(profile);
      expect(controller.value.readiness, LifecycleReadiness.unavailable);
      expect(probes, 0);
    },
  );

  test(
    'remote, deleted and Termux profiles do not reach native or HTTP',
    () async {
      for (final candidate in [
        null,
        ServerProfile(
          id: 'remote',
          name: 'Remote',
          baseUrl: 'https://example.test',
        ),
        ServerProfile(
          id: 'termux',
          name: 'Termux',
          baseUrl: 'http://127.0.0.1:4096',
        ),
      ]) {
        await controller.refresh(candidate);
        expect(controller.value.readiness, LifecycleReadiness.unavailable);
      }
      expect(probes, 0);
      expect(linux.reads, 0);
      expect(bridge.reads, 0);
    },
  );

  test('team recovery needs its process, supervisor and city health', () async {
    bridge.report = AppLaunchReport(
      exit: bridge.report.exit,
      previousServices: const ['server', 'aiteam'],
    );
    profile.orchestration = BuiltinTeam.config();
    await controller.refresh(profile);
    expect(controller.value.readiness, LifecycleReadiness.partial);
    expect(teamRequests, isEmpty);
    linux.teamRunning = true;
    supervisorHealthy = false;
    await controller.refresh(profile);
    expect(controller.value.everythingBack, isFalse);
    expect(teamRequests.map((uri) => uri.path), ['/health']);
    supervisorHealthy = true;
    cityHealthy = false;
    await controller.refresh(profile);
    expect(controller.value.readiness, LifecycleReadiness.partial);
    cityHealthy = true;
    await controller.refresh(profile);
    expect(controller.value.everythingBack, isTrue);
    expect(teamRequests.last.path, '/v0/city/phone/health');
    expect(bridge.reads, 1);
  });

  test('a removed team configuration is not silently recovered', () async {
    bridge.report = AppLaunchReport(
      exit: bridge.report.exit,
      previousServices: const ['server', 'aiteam'],
    );
    linux.teamRunning = true;
    await controller.refresh(profile);
    expect(controller.value.readiness, LifecycleReadiness.partial);
    expect(teamRequests, isEmpty);
  });

  test(
    'unknown historical services prevent an everything-back claim',
    () async {
      bridge.report = AppLaunchReport(
        exit: bridge.report.exit,
        previousServices: const ['server', 'future-service'],
      );
      await controller.refresh(profile);
      expect(controller.value.readiness, LifecycleReadiness.partial);
      expect(controller.value.everythingBack, isFalse);
    },
  );

  test(
    'normal launch, update and no previously running services show no notice',
    () async {
      for (final report in [
        const AppLaunchReport(previousServices: ['server']),
        AppLaunchReport(
          exit: AppExitRecord(
            reason: AndroidExitReason.packageUpdated,
            timestamp: DateTime(2026, 9, 27),
          ),
          previousServices: const ['server'],
        ),
        AppLaunchReport(exit: bridge.report.exit),
      ]) {
        final other = LifecycleReportController(
          linux: linux,
          bridge: _Bridge()..report = report,
          probe: ({required baseUrl, username, password}) => health(),
        );
        await other.refresh(profile);
        expect(other.value.readiness, LifecycleReadiness.ready);
        expect(other.value.showNotice, isFalse);
        expect(other.value.everythingBack, isFalse);
        other.dispose();
      }
    },
  );

  test(
    'invalidation removes success and rejects an in-flight health result',
    () async {
      await controller.refresh(profile);
      expect(controller.value.everythingBack, isTrue);
      final pending = Completer<ServerProbeResult>();
      health = () => pending.future;
      final refresh = controller.refresh(profile);
      await Future<void>.delayed(Duration.zero);
      controller.invalidate();
      expect(controller.value.readiness, LifecycleReadiness.unchecked);
      pending.complete(const ServerProbeResult.success('fixture'));
      await refresh;
      expect(controller.value.everythingBack, isFalse);
      expect(controller.value.readiness, LifecycleReadiness.unchecked);
    },
  );

  test('switching profiles supersedes an older refresh', () async {
    final pending = Completer<ServerProbeResult>();
    health = () => pending.future;
    final oldRefresh = controller.refresh(profile);
    await Future<void>.delayed(Duration.zero);
    await controller.refresh(null);
    pending.complete(const ServerProbeResult.success('fixture'));
    await oldRefresh;
    expect(controller.value.readiness, LifecycleReadiness.unavailable);
    expect(controller.value.everythingBack, isFalse);
  });

  test('dismissal survives refresh without writing preferences', () async {
    await controller.refresh(profile);
    controller.dismiss();
    await controller.refresh(profile);
    expect(controller.value.readiness, LifecycleReadiness.ready);
    expect(controller.value.showNotice, isFalse);
    expect(bridge.reads, 1);
  });

  test(
    'native failures remain unknown and a later refresh can recover',
    () async {
      bridge.error = StateError('password=fake-native-secret');
      await controller.refresh(profile);
      expect(controller.value.readiness, LifecycleReadiness.unavailable);
      expect(controller.value.everythingBack, isFalse);
      bridge.error = null;
      await controller.refresh(profile);
      expect(controller.value.everythingBack, isTrue);
      expect(bridge.reads, 2);
      linux.error = StateError('password=fake-native-secret');
      await controller.refresh(profile);
      expect(controller.value.readiness, LifecycleReadiness.unavailable);
    },
  );

  test(
    'disposal prevents notification or publication from an in-flight check',
    () async {
      final pending = Completer<ServerProbeResult>();
      final other = LifecycleReportController(
        linux: linux,
        bridge: bridge,
        probe: ({required baseUrl, username, password}) => pending.future,
      );
      var notifications = 0;
      other.addListener(() => notifications++);
      final refresh = other.refresh(profile);
      await Future<void>.delayed(Duration.zero);
      other.dispose();
      final before = notifications;
      pending.complete(const ServerProbeResult.success('fixture'));
      await refresh;
      expect(notifications, before);
      expect(other.value.everythingBack, isFalse);
    },
  );
}
