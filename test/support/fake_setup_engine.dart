import 'package:flutter/foundation.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';

/// A scriptable [SetupEngine] for screen tests: tests push progress states
/// with [emit] and read back what the screen asked for.
class FakeSetupEngine implements SetupEngine {
  FakeSetupEngine({List<SetupComponent>? registry})
    : registry = registry ?? fakeRegistry;

  static const fakeRegistry = [
    SetupComponent(
      id: 'linux',
      title: 'Linux base',
      shortTitle: 'Linux base',
      checkScript: 'true',
      installScript: '',
      required: true,
      native: true,
      estimatedSeconds: 20,
      downloadBytes: 30000000,
    ),
    SetupComponent(
      id: 'essentials',
      title: 'Git, SSH and certificates',
      shortTitle: 'Git and SSH',
      checkScript: 'true',
      installScript: 'true',
      dependsOn: ['linux'],
      required: true,
      estimatedSeconds: 40,
      downloadBytes: 15000000,
    ),
    SetupComponent(
      id: 'python',
      title: 'Python',
      shortTitle: 'Python',
      checkScript: 'true',
      installScript: 'true',
      dependsOn: ['essentials'],
      defaultOn: true,
      estimatedSeconds: 50,
      downloadBytes: 30000000,
    ),
    SetupComponent(
      id: 'node',
      title: 'Node.js',
      shortTitle: 'Node.js',
      checkScript: 'true',
      installScript: 'true',
      dependsOn: ['essentials'],
      required: true,
      estimatedSeconds: 40,
      downloadBytes: 30000000,
    ),
    SetupComponent(
      id: 'opencode',
      title: 'OpenCode',
      shortTitle: 'OpenCode',
      checkScript: 'true',
      installScript: 'true',
      dependsOn: ['node'],
      required: true,
      estimatedSeconds: 90,
      downloadBytes: 60000000,
    ),
  ];

  @override
  final List<SetupComponent> registry;

  final _progress = ValueNotifier<SetupProgress>(SetupProgress.idle);
  final runs = <Set<String>>[];
  final runParams = <Map<String, Map<String, String>>>[];
  var cancels = 0;
  var restores = 0;
  Set<String> optionalInstalled = {};

  /// Published when [run] is called, as the real engine publishes the new
  /// job; null leaves the progress as it was.
  SetupProgress? afterRun;

  @override
  ValueListenable<SetupProgress> get progress => _progress;

  void emit(SetupProgress value) => _progress.value = value;

  @override
  Future<void> run(
    Set<String> ids, {
    Map<String, Map<String, String>> params = const {},
  }) async {
    runs.add(ids);
    runParams.add(params);
    if (afterRun != null) emit(afterRun!);
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> restore() async => restores++;

  @override
  Future<Set<String>> installedOptional() async => optionalInstalled;
}
