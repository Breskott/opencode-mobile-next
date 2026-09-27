// The `oc/termux` channel as a phone with Termux on it, for the Termux host
// of phone setup (PhoneSetupTermuxScreen) and This phone in Termux. It
// answers the manager scripts the way the old wizard's tests did: Termux's
// capabilities, the bridge probe, the installation inventory, the setup
// snapshot, and the launch, restart and switch dispatches.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';

Map<String, Object> termuxResult({String stdout = ''}) => {
  'stdout': stdout,
  'stderr': '',
  'exitCode': 0,
  'err': -1,
  'errorMessage': '',
};

/// A snapshot the manager prints: its status lines, the marker, the log.
String termuxSnapshot({
  required String phase,
  String message = 'OpenCode is ready',
  String version = '',
  TermuxRuntime runtime = TermuxRuntime.openCode1,
  String operation = '',
  String extra = '',
  String log = '',
}) =>
    'phase=$phase\nmessage=$message\nport=4096\nrunner=proot\n'
    'version=$version\nruntime=${runtime.wireName}\npid=123\n'
    '${operation.isEmpty ? '' : 'operation=$operation\noperation_result=completed\n'}'
    '$extra'
    '__OC_SETUP_OUTPUT__\n$log';

class TermuxChannelFixture {
  bool termuxInstalled = true;
  bool permissionGranted = true;
  bool protocolSupported = true;
  bool bridgeUnlocked = true;
  bool permissionResult = true;
  bool openResult = true;
  TermuxRuntime runtime = TermuxRuntime.openCode1;

  /// What `ubuntu=… version=…` inventory answers.
  String inventoryOutput = 'ubuntu=absent\nversion=\n';

  /// The snapshot answer; null answers "idle" before a launch and
  /// "installing" after one.
  String? statusOutput;

  /// Held open to keep the launch dispatch pending.
  Completer<Map<String, Object>>? pendingLaunch;

  bool launched = false;
  int launchCalls = 0;
  int restartCalls = 0;
  int switchCalls = 0;
  int bridgeChecks = 0;
  String? lastRestartOperation;
  final methods = <String>[];

  Future<Object?> handle(MethodCall call) async {
    methods.add(call.method);
    switch (call.method) {
      case 'requestRunCommandPermission':
        permissionGranted = permissionResult;
        return permissionResult;
      case 'openTermux':
        return openResult;
      case 'openAppSettings':
        return true;
      case 'getCapabilities':
        return <String, Object>{
          'installed': termuxInstalled,
          'version': '0.118',
          'serviceAvailable': true,
          'protocolSupported': protocolSupported,
          'permissionGranted': permissionGranted,
        };
    }
    if (call.method != 'runInTermux') return true;
    final script = (call.arguments as Map)['script'] as String;
    final switchMatch = RegExp(
      r"restart '4096' '([^']+)' '' '' '(opencode[12])'",
    ).firstMatch(script);
    if (switchMatch != null) {
      switchCalls++;
      final operation = switchMatch.group(1)!;
      runtime = TermuxRuntime.parse(switchMatch.group(2));
      statusOutput = termuxSnapshot(
        phase: 'ready',
        version: runtime.pinnedVersion,
        runtime: runtime,
        operation: operation,
      );
      inventoryOutput =
          'ubuntu=installed\nversion=${runtime.pinnedVersion}\n'
          'runtime=${runtime.wireName}\n';
      return termuxResult(stdout: 'manager-started:123');
    }
    if (script.contains('"\$MANAGER" restart')) {
      restartCalls++;
      lastRestartOperation = RegExp(
        r"restart '4096' '([^']+)'",
      ).firstMatch(script)!.group(1);
      statusOutput = termuxSnapshot(
        phase: 'ready',
        version: runtime.pinnedVersion,
        runtime: runtime,
        operation: lastRestartOperation!,
      );
      return termuxResult();
    }
    if (script.contains('manager_tmp=')) {
      launchCalls++;
      final result =
          await (pendingLaunch?.future ??
              Future.value(termuxResult(stdout: 'manager-started:123')));
      launched = true;
      return result;
    }
    // The manager text rides inside the launch and restart scripts and
    // mentions the words below: those scripts are matched first.
    if (script.contains('ubuntu=absent') && !script.contains('MANAGER=')) {
      return termuxResult(stdout: inventoryOutput);
    }
    if (script.contains("printf 'opencode-bridge-ok'")) {
      bridgeChecks++;
      if (!bridgeUnlocked) {
        throw PlatformException(
          code: 'command_timeout',
          message: 'Termux did not answer.',
        );
      }
      return termuxResult(stdout: 'opencode-bridge-ok');
    }
    if (script.contains('server.password')) return termuxResult();
    if (script.contains('__OC_SETUP_OUTPUT__') ||
        (script.contains('exec "') && script.contains(' status'))) {
      return termuxResult(
        stdout:
            statusOutput ??
            (launched
                ? termuxSnapshot(
                    phase: 'installing_ubuntu',
                    message: 'Setting up Ubuntu',
                    runtime: runtime,
                    log: '[oc] Installing packages\n',
                  )
                : termuxSnapshot(
                    phase: 'idle',
                    message: 'No setup has been started',
                  )),
      );
    }
    return termuxResult();
  }

  void install() {
    const channel = MethodChannel('oc/termux');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handle);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }
}

/// Saved profiles in memory: no secure storage in a widget test.
class MemoryProfileStore extends ProfileStore {
  MemoryProfileStore({required super.prefs, List<ServerProfile>? saved})
    : saved = saved ?? [];

  final List<ServerProfile> saved;
  String? selectedID;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => selectedID;

  @override
  Future<void> upsert(ServerProfile profile) async {
    final index = saved.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      saved.add(profile);
    } else {
      saved[index] = profile;
    }
  }

  @override
  Future<void> setActiveId(String? id) async => selectedID = id;
}

/// A connection that "connects" at once (or fails when [failConnect]).
class FakePhoneConnection extends ConnectionController {
  FakePhoneConnection(super.store);

  int connectCalls = 0;
  bool failConnect = false;
  ServerProfile? connectedTo;

  @override
  bool get hasConnectedServer => connectedTo != null;

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    connectCalls++;
    connectionAttemptRevision++;
    await store.setActiveId(profile.id);
    if (failConnect) {
      connectedTo = null;
      lastError = 'Could not connect to the phone server.';
    } else {
      connectedTo = profile;
    }
    notifyListeners();
  }

  @override
  Future<void> disconnect({
    bool keepActive = false,
    bool silent = false,
  }) async {
    connectedTo = null;
    if (!keepActive) await store.setActiveId(null);
    if (!silent) notifyListeners();
  }
}
