// Add tools on a phone that already finished a setup (build 2064, emulator
// 2026-09-29): a status read of the OLD job landed while the new job's
// checks ran, replaced the rows the engine was about to publish, and the
// start died on a null check, shown as "OpenCode is unreachable". Fakes only.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';

import '../setup_engine_test.dart' show FakeLinux, en;

class _BrokenStart extends FakeLinux {
  @override
  Future<void> startSetup({
    required String jobId,
    required List<Map<String, Object?>> components,
    required Map<String, Map<String, String>> params,
    required Map<String, String> texts,
  }) async => throw StateError('the runner exploded');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> addWhileOldJobIsRead(String id, String before) async {
    final linux = FakeLinux();
    final engine = ChannelSetupEngine(
      linux: linux,
      strings: () => en,
      pollInterval: const Duration(milliseconds: 5),
      finisher: (request) async => null,
    );
    addTearDown(engine.dispose);

    // The phone's first setup finished earlier: its record is what the
    // runner still holds.
    // It had a tool the new job does not (already installed by now).
    await engine.run({before}, params: SetupJobParams.firstSetup);
    linux.job!['state'] = 'done';
    final oldJob = linux.job!['jobId'];

    // The person adds a tool; its checks are slow, and meanwhile the app
    // re-reads the runner's record (the This phone screen and the poll do).
    linux.holdChecks = Completer<void>();
    final adding = engine.run({id}, params: SetupJobParams.adding({id}));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await engine.restore();
    linux.holdChecks!.complete();
    await adding;

    expect(linux.started.last['jobId'], isNot(oldJob));
    final progress = engine.progress.value;
    expect(progress.jobId, linux.started.last['jobId']);
    expect(progress.adding, [id]);
    expect(progress.state, SetupState.running);
    expect(progress.components.map((c) => c.id), contains(id));
  }

  for (final (id, before) in [
    ('aiteam', 'voice'),
    ('voice', 'python'),
    ('python', 'voice'),
  ]) {
    test(
      'Add tools $id starts even when the previous job ($before) is read '
      'while its checks run',
      () => addWhileOldJobIsRead(id, before),
    );
  }

  test('a start that breaks is a failed job with its text kept, not a throw '
      'no entry point shows', () async {
    final engine = ChannelSetupEngine(
      linux: _BrokenStart(),
      strings: () => en,
      pollInterval: const Duration(milliseconds: 5),
      finisher: (request) async => null,
    );
    addTearDown(engine.dispose);
    await engine.run({'aiteam'}, params: SetupJobParams.adding({'aiteam'}));
    final progress = engine.progress.value;
    expect(progress.state, SetupState.failed);
    expect(progress.error, contains('StateError'));
    expect(progress.adding, ['aiteam']);
    expect(progress.components.map((c) => c.id), contains('aiteam'));
  });
}
