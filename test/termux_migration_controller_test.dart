import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/builtin/migration/migration_archive_store.dart';
import 'package:opencode_mobile/builtin/migration/termux_migration_controller.dart';
import 'package:opencode_mobile/builtin/migration/termux_migration_transport.dart';
import 'package:opencode_mobile/domain/termux_migration.dart';

const _job = '0123456789abcdef0123456789abcdef';
const _selected = {TermuxMigrationItem.projects};
const _archive = TermuxMigrationArchive(
  bytes: 10240,
  sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
);
const _ampleSpace = 1024 * 1024 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'profile deletion during a journal write cannot recreate scoped state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var checks = 0;
      final journal = PreferencesTermuxMigrationJournal(
        prefs,
        mayWrite: (_) => ++checks == 1,
      );
      await expectLater(
        journal.write('termux', {'job': _job}),
        throwsA(
          isA<TermuxMigrationException>().having(
            (e) => e.code,
            'code',
            TermuxMigrationFailure.cancelled,
          ),
        ),
      );
      expect(prefs.containsKey('oc.termuxMigration.termux'), isFalse);
    },
  );

  test(
    'verified import switches profile once and completed retry is local',
    () async {
      final fixture = _Fixture();
      final controller = fixture.controller();
      final phases = <TermuxMigrationPhase>[];
      controller.addListener(() => phases.add(controller.snapshot.phase));
      await controller.start(sourceProfileId: 'termux', selected: _selected);

      expect(controller.snapshot.phase, TermuxMigrationPhase.done);
      expect(controller.snapshot.destinationProfileId, 'builtin');
      expect(fixture.switches, 1);
      expect(fixture.paths, {'/root/projects': '/root/projects/termux-$_job'});
      expect(
        phases,
        containsAllInOrder([
          TermuxMigrationPhase.checking,
          TermuxMigrationPhase.ready,
          TermuxMigrationPhase.packing,
          TermuxMigrationPhase.copying,
          TermuxMigrationPhase.verifying,
          TermuxMigrationPhase.unpacking,
          TermuxMigrationPhase.verifying,
          TermuxMigrationPhase.switching,
          TermuxMigrationPhase.done,
        ]),
      );
      expect(fixture.archives.importCalls, 1);
      expect(fixture.archives.cleanupCalls, 1);

      fixture.transport.inspectError = const TermuxMigrationException(
        TermuxMigrationFailure.unavailable,
      );
      await controller.start(sourceProfileId: 'termux', selected: _selected);
      expect(controller.snapshot.phase, TermuxMigrationPhase.done);
      expect(fixture.transport.inspectCalls, 1);
      expect(fixture.transport.packCalls, 1);
      expect(fixture.archives.importCalls, 1);
      expect(fixture.switches, 1);
      controller.dispose();
    },
  );

  test(
    'missing built-in and low or unknown space stop before packing',
    () async {
      final missing = _Fixture()..archives.installed = false;
      final missingController = missing.controller();
      await missingController.start(
        sourceProfileId: 'termux',
        selected: _selected,
      );
      expect(
        missingController.snapshot.phase,
        TermuxMigrationPhase.needsBuiltin,
      );
      expect(missing.transport.inspectCalls, 0);
      expect(missing.transport.packCalls, 0);
      expect(missing.journal.records, isEmpty);
      missingController.dispose();

      for (final space in [0, null, _ampleSpace]) {
        final fixture = _Fixture()..freeBytes = space;
        if (space == _ampleSpace) fixture.transport.sourceFreeBytes = 0;
        final controller = fixture.controller();
        await controller.start(sourceProfileId: 'termux', selected: _selected);
        expect(controller.snapshot.phase, TermuxMigrationPhase.needsSpace);
        expect(
          controller.snapshot.requiredBytes,
          greaterThan(TermuxMigrationController.reserveBytes),
        );
        expect(fixture.transport.packCalls, 0);
        expect(fixture.archives.importCalls, 0);
        expect(fixture.journal.records, isEmpty);
        expect(fixture.switches, 0);
        controller.dispose();
      }
    },
  );

  test(
    'Termux loss during copy retains resumable metadata without switching',
    () async {
      final fixture = _Fixture();
      fixture.transport.onCopy = (_) async {
        throw const TermuxMigrationException(
          TermuxMigrationFailure.unavailable,
        );
      };
      final controller = fixture.controller();
      await controller.start(sourceProfileId: 'termux', selected: _selected);
      expect(controller.snapshot.phase, TermuxMigrationPhase.termuxUnreachable);
      expect(
        fixture.journal.records['termux']!['archives'],
        contains('projects'),
      );
      expect(fixture.archives.importCalls, 0);
      expect(fixture.switches, 0);
      controller.dispose();
    },
  );

  test(
    'new controller resumes committed import after lost completion',
    () async {
      final fixture = _Fixture();
      fixture.archives.afterCommit = () =>
          throw StateError('simulated process exit');
      final first = fixture.controller();
      await first.start(sourceProfileId: 'termux', selected: _selected);
      expect(first.snapshot.phase, TermuxMigrationPhase.failed);
      expect(fixture.archives.receipts, contains(TermuxMigrationItem.projects));
      expect(fixture.journal.records['termux']!['done'], isNull);
      first.dispose();

      fixture.archives.afterCommit = null;
      final resumed = fixture.controller();
      await resumed.start(sourceProfileId: 'termux', selected: _selected);
      expect(resumed.snapshot.phase, TermuxMigrationPhase.done);
      expect(resumed.snapshot.jobId, _job);
      expect(fixture.archives.importCalls, 1);
      expect(fixture.transport.packCalls, 1);
      expect(fixture.transport.copyCalls, 1);
      expect(fixture.switches, 1);
      resumed.dispose();
    },
  );

  test('checksum mismatch never imports or switches', () async {
    final fixture = _Fixture();
    fixture.archives.verifyError = const TermuxMigrationException(
      TermuxMigrationFailure.checksumMismatch,
    );
    final controller = fixture.controller();
    await controller.start(sourceProfileId: 'termux', selected: _selected);
    expect(controller.snapshot.phase, TermuxMigrationPhase.failed);
    expect(
      controller.snapshot.failure,
      TermuxMigrationFailure.checksumMismatch,
    );
    expect(fixture.archives.importCalls, 0);
    expect(fixture.switches, 0);
    controller.dispose();
  });

  test(
    'cancel interrupts admission after current copy and preserves source',
    () async {
      final fixture = _Fixture();
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.transport.onCopy = (cancelled) async {
        entered.complete();
        await release.future;
        expect(cancelled(), isTrue);
      };
      final controller = fixture.controller();
      final running = controller.start(
        sourceProfileId: 'termux',
        selected: _selected,
      );
      await entered.future;
      await controller.cancel();
      expect(controller.snapshot.phase, TermuxMigrationPhase.cancelled);
      expect(fixture.transport.cancelledJobs, [_job]);
      release.complete();
      await running;
      expect(controller.snapshot.phase, TermuxMigrationPhase.cancelled);
      expect(fixture.archives.importCalls, 0);
      expect(fixture.switches, 0);
      expect(fixture.journal.records['termux']!['done'], isNull);
      controller.dispose();
    },
  );

  test(
    'raw credential-bearing exceptions never enter output, state or journal',
    () async {
      const secret = 'test-only-provider-secret-DO-NOT-RENDER';
      final fixture = _Fixture();
      fixture.transport.onCopy = (_) async => throw StateError(secret);
      final controller = fixture.controller();
      final output = <String>[];
      final snapshots = <String>[];
      controller.addListener(() {
        final state = controller.snapshot;
        snapshots.add(
          jsonEncode({
            'phase': state.phase.name,
            'failure': state.failure?.name,
            'job': state.jobId,
            'item': state.item?.name,
            'destination': state.destinationProfileId,
            'required': state.requiredBytes,
            'available': state.availableBytes,
            'source': state.source == null
                ? null
                : {
                    'oc1': state.source!.oc1Version,
                    'oc2': state.source!.oc2Version,
                    'items': state.source!.items
                        .map((item) => [item.item.name, item.bytes, item.files])
                        .toList(),
                  },
          }),
        );
      });
      await runZoned(
        () => controller.start(sourceProfileId: 'termux', selected: _selected),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, text) => output.add(text),
        ),
      );
      expect(controller.snapshot.failure, TermuxMigrationFailure.storage);
      final publicException = TermuxMigrationException(
        controller.snapshot.failure!,
      );
      expect(publicException.toString(), isNot(contains(secret)));
      expect(output.join(), isNot(contains(secret)));
      expect(snapshots.join(), isNot(contains(secret)));
      expect(jsonEncode(fixture.journal.records), isNot(contains(secret)));
      expect(fixture.switches, 0);
      controller.dispose();
    },
  );

  test(
    'resume refuses changed source archive instead of replacing prior bytes',
    () async {
      final fixture = _Fixture();
      fixture.transport.onCopy = (_) async {
        throw const TermuxMigrationException(
          TermuxMigrationFailure.unavailable,
        );
      };
      final first = fixture.controller();
      await first.start(sourceProfileId: 'termux', selected: _selected);
      first.dispose();
      fixture.transport.onCopy = null;
      fixture.transport.archive = const TermuxMigrationArchive(
        bytes: 20480,
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      final resumed = fixture.controller();
      await resumed.start(sourceProfileId: 'termux', selected: _selected);
      expect(resumed.snapshot.failure, TermuxMigrationFailure.sourceChanged);
      expect(fixture.transport.copyCalls, 1);
      expect(fixture.archives.importCalls, 0);
      expect(fixture.switches, 0);
      resumed.dispose();
    },
  );
}

class _Fixture {
  final transport = _FakeTransport();
  final archives = _FakeArchives();
  final journal = _MemoryJournal();
  int? freeBytes = _ampleSpace;
  int switches = 0;
  Map<String, String>? paths;

  TermuxMigrationController controller() => TermuxMigrationController(
    transport: transport,
    archives: archives,
    journal: journal,
    availableBytes: () async => freeBytes,
    sourceProfileExists: (id) => id == 'termux',
    newJobId: () => _job,
    switchProfile:
        ({
          required sourceProfileId,
          required stillWanted,
          required verifiedProjectPaths,
        }) async {
          expect(sourceProfileId, 'termux');
          expect(stillWanted(), isTrue);
          expect(archives.receipts, contains(TermuxMigrationItem.projects));
          switches++;
          paths = verifiedProjectPaths;
          return 'builtin';
        },
  );
}

class _FakeTransport implements TermuxMigrationTransport {
  int inspectCalls = 0;
  int packCalls = 0;
  int copyCalls = 0;
  int sourceFreeBytes = _ampleSpace;
  Object? inspectError;
  TermuxMigrationArchive archive = _archive;
  Future<void> Function(bool Function() cancelled)? onCopy;
  final cancelledJobs = <String>[];

  @override
  Future<TermuxMigrationSource> inspect() async {
    inspectCalls++;
    if (inspectError case final Object error) throw error;
    return TermuxMigrationSource(
      items: const [TermuxMigrationSize(TermuxMigrationItem.projects, 12, 2)],
      freeBytes: sourceFreeBytes,
      oc1Version: '1.18.32',
    );
  }

  @override
  Future<TermuxMigrationArchive> pack(
    String jobId,
    TermuxMigrationItem item, {
    required int maxBytes,
  }) async {
    packCalls++;
    return archive;
  }

  @override
  Future<void> copy(
    String jobId,
    TermuxMigrationItem item,
    TermuxMigrationArchive archive,
    File destination, {
    required bool Function() cancelled,
  }) async {
    copyCalls++;
    await onCopy?.call(cancelled);
  }

  @override
  Future<void> cancel(String jobId) async => cancelledJobs.add(jobId);
}

class _FakeArchives extends TermuxMigrationArchiveStore {
  _FakeArchives() : super(support: Directory('/fake-app-private'));
  bool installed = true;
  int importCalls = 0;
  int cleanupCalls = 0;
  Object? verifyError;
  void Function()? afterCommit;
  final receipts = <TermuxMigrationItem, TermuxMigrationArchive>{};

  @override
  Future<bool> builtinInstalled() async => installed;

  @override
  Directory jobDirectory(String jobId) => Directory('/fake-app-private/$jobId');

  @override
  Future<void> verify(File archive, TermuxMigrationArchive expected) async {
    if (verifyError case final Object error) throw error;
  }

  @override
  Future<void> importItem(
    String jobId,
    TermuxMigrationItem item,
    File archive,
    TermuxMigrationArchive expected, {
    required bool Function() cancelled,
  }) async {
    expect(cancelled(), isFalse);
    importCalls++;
    receipts[item] = expected;
    afterCommit?.call();
  }

  @override
  Future<bool> imported(
    String jobId,
    TermuxMigrationItem item,
    TermuxMigrationArchive expected,
  ) async {
    final receipt = receipts[item];
    return receipt?.bytes == expected.bytes &&
        receipt?.sha256 == expected.sha256;
  }

  @override
  Future<void> cleanupPartial(String jobId) async => cleanupCalls++;
}

class _MemoryJournal implements TermuxMigrationJournal {
  final records = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String sourceProfileId) async {
    final value = records[sourceProfileId];
    return value == null ? null : _clone(value);
  }

  @override
  Future<void> write(String sourceProfileId, Map<String, dynamic> value) async {
    records[sourceProfileId] = _clone(value);
  }

  static Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}
