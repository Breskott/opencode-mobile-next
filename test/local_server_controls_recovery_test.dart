import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/local_server_controls.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/managed_server_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DisconnectedConnection implements ConnectionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Profiles implements ProfileStore {
  _Profiles(this.prefs);
  @override
  final SharedPreferences prefs;
  @override
  final profiles = [
    ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: TermuxBridge.managedServerUrl,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/termux');
  late SharedPreferences prefs;
  final scripts = <String>[];
  String operation = 'original';
  String phase = 'ready';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    AutomationPolicyController.resetShared();
    debugPlatformCapabilities = const PlatformCapabilities.android();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    scripts.clear();
    operation = 'original';
    phase = 'ready';
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final script = (call.arguments as Map)['script'] as String;
      scripts.add(script);
      if (script == TermuxBridge.stopScript()) phase = 'stopped';
      if (script.contains('"\$MANAGER" restart')) {
        operation = RegExp(
          r'''restart '4096' '([^']+)' ''',
        ).firstMatch(script)!.group(1)!;
        phase = 'ready';
      }
      return {
        'exitCode': 0,
        'stdout':
            'phase=$phase\nrunner=proot\nport=4096\noperation=$operation\n',
        'stderr': '',
      };
    });
  });
  tearDown(() {
    ManagedServerRecovery.disposeForPreferences(prefs);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugPlatformCapabilities = null;
  });

  testWidgets('stop and start preserve policy and rearm manual ownership', (
    tester,
  ) async {
    final controls = LocalServerControls(
      store: _Profiles(prefs),
      connection: _DisconnectedConnection(),
    );
    final recovery = ManagedServerRecovery.forProfile(prefs, 'phone');
    await recovery.checkNow();
    await controls.stop();
    expect(recovery.enabled, isTrue);
    expect(recovery.paused, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(scripts.where((s) => s.contains('"\$MANAGER" restart')), isEmpty);
    final result = await controls.restart();
    expect(result.isReady, isTrue);
    expect(recovery.enabled, isTrue);
    expect(recovery.paused, isFalse);
    expect(recovery.phase, ManagedRecoveryPhase.monitoring);
    expect(recovery.attempts, 0);
    ManagedServerRecovery.disposeForPreferences(prefs);
  });
}
