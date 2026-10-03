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
    'discard failed pack is repeatable and a fresh copy can start',
    () async {
      final fixture = _Fixture();
      fixture.transport.packError = const TermuxMigrationException(
        TermuxMigrationFailure.timedOut,
      );
      final controller = fixture.controller();
      await controller.start(sourceProfileId: 'termux', selected: _selected);
      expect(controller.snapshot.failure, TermuxMigrationFailure.timedOut);
      expect(await controller.savedSelection('termux'), _selected);
      expect(
        await controller.discardSavedCopy('termux'),
        TermuxMigrationDiscardResult.discarded,
      );
      expect(await controller.savedSelection('termux'), isNull);
      expect(
        await controller.discardSavedCopy('termux'),
        TermuxMigrationDiscardResult.nothingSaved,
      );
      expect(fixture.archives.cleanupCalls, 1);
      expect(fixture.transport.cancelledJobs, isEmpty);
      fixture.transport.packError = null;
      await controller.start(sourceProfileId: 'termux', selected: _selected);
      expect(controller.snapshot.phase, TermuxMigrationPhase.done);
      expect(fixture.switches, 1);
      controller.dispose();
    },
  );

  test(
    'discard preserves committed files and retains journal on cleanup failure',
    () async {
      final fixture = _Fixture();
      fixture.archives.afterCommit = () => throw StateError('simulated exit');
      final controller = fixture.controller();
      await controller.start(sourceProfileId: 'termux', selected: _selected);
      fixture.archives.cleanupError = StateError('synthetic-private-error');
      await expectLater(
        controller.discardSavedCopy('termux'),
        throwsA(
          isA<TermuxMigrationException>().having(
            (e) => e.code,
            'code',
            TermuxMigrationFailure.storage,
          ),
        ),
      );
      expect(await controller.savedSelection('termux'), _selected);
      fixture.archives.cleanupError = null;
      await controller.discardSavedCopy('termux');
      expect(
        fixture.archives.receipts.keys,
        contains(TermuxMigrationItem.projects),
      );
      expect(fixture.switches, 0);
      controller.dispose();
    },
  );

  test(
    'completion query survives restart and user edits without contacting source',
    () async {
      final fixture = _Fixture();
      final first = fixture.controller();
      expect(await first.completedJob('termux'), isNull);
      await first.start(sourceProfileId: 'termux', selected: _selected);
      first.dispose();
      fixture.archives.receipts
          .clear(); // User changed files; historical copy still finished.
      fixture.transport.inspectError = StateError('offline');
      final restarted = fixture.controller();
      final before = restarted.snapshot;
      final completed = await restarted.completedJob('termux');
      expect(completed?.jobId, _job);
      expect(completed?.destinationProfileId, 'builtin');
      expect(identical(before, restarted.snapshot), isTrue);
      expect(
        await restarted.discardSavedCopy('termux'),
        TermuxMigrationDiscardResult.alreadyCompleted,
      );
      expect(await restarted.completedJob('termux'), isNotNull);
      expect(fixture.transport.inspectCalls, 1);
      expect(fixture.archives.cleanupCalls, 1);
      expect(fixture.switches, 1);
      fixture.journal.records['termux']!['destination'] = null;
      await expectLater(
        restarted.completedJob('termux'),
        throwsA(
          isA<TermuxMigrationException>().having(
            (e) => e.code,
            'code',
            TermuxMigrationFailure.storage,
          ),
        ),
      );
      restarted.dispose();
    },
  );

  test(
    'review reports capacity before pack and uses start budget for selection',
    () async {
      final fixture = _Fixture()..freeBytes = 50;
      fixture.transport.sourceFreeBytes = 80;
      final controller = fixture.controller();
      await controller.check(selected: _selected);
      expect(controller.snapshot.phase, TermuxMigrationPhase.ready);
      expect(controller.snapshot.availableBytes, 50);
      final review = controller.reviewSpace(_selected);
      expect(review.appAvailableBytes, 50);
      expect(review.sourceAvailableBytes, 80);
      expect(review.sufficient, isFalse);
      expect(controller.reviewSpace({}).requiredBytes, 0);
      await controller.start(sourceProfileId: 'termux', selected: _selected);
      expect(controller.snapshot.phase, TermuxMigrationPhase.needsSpace);
      expect(controller.snapshot.requiredBytes, review.requiredBytes);
      expect(fixture.transport.packCalls, 0);
      fixture.freeBytes = null;
      await controller.check(selected: _selected);
      expect(controller.snapshot.availableBytes, isNull);
      expect(controller.reviewSpace(_selected).sufficient, isNull);
      controller.dispose();
    },
  );

  test(
    'stop settles only after copy and stop command, then notifies idle',
    () async {
      final fixture = _Fixture();
      final entered = Completer<void>();
      final releaseCopy = Completer<void>();
      final releaseStop = Completer<void>();
      fixture.transport.onCopy = (_) async {
        entered.complete();
        await releaseCopy.future;
      };
      fixture.transport.onCancel = () => releaseStop.future;
      final controller = fixture.controller();
      var idleNotifications = 0;
      controller.addListener(() {
        if (!controller.busy) idleNotifications++;
      });
      final running = controller.start(
        sourceProfileId: 'termux',
        selected: _selected,
      );
      await entered.future;
      final stop = controller.cancel();
      var settled = false;
      final settlement = controller.whenSettled.then((_) => settled = true);
      await expectLater(
        controller.discardSavedCopy('termux'),
        throwsA(
          isA<TermuxMigrationException>().having(
            (e) => e.code,
            'code',
            TermuxMigrationFailure.sourceBusy,
          ),
        ),
      );
      releaseCopy.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.busy, isTrue);
      expect(settled, isFalse);
      releaseStop.complete();
      await stop;
      await settlement;
      await running;
      expect(controller.busy, isFalse);
      expect(idleNotifications, 1);
      expect(fixture.archives.importCalls, 0);
      await controller.discardSavedCopy('termux');
      expect(fixture.journal.records, isEmpty);
      controller.dispose();
    },
  );

  test('resume owns settlement before its first journal read', () async {
    final fixture = _Fixture();
    fixture.transport.packError = const TermuxMigrationException(
      TermuxMigrationFailure.timedOut,
    );
    final controller = fixture.controller();
    await controller.start(sourceProfileId: 'termux', selected: _selected);
    final read = Completer<void>();
    fixture.journal.readGate = read.future;
    final resume = controller.resume('termux');
    expect(controller.busy, isTrue);
    await controller.cancel();
    var settled = false;
    final settlement = controller.whenSettled.then((_) => settled = true);
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);
    read.complete();
    await resume;
    await settlement;
    expect(controller.snapshot.phase, TermuxMigrationPhase.cancelled);
    expect(fixture.transport.packCalls, 1);
    controller.dispose();
  });

  test(
    'provider query is offline and ignores unexported or failed config',
    () async {
      final fixture = _Fixture();
      final controller = fixture.controller();
      expect(await controller.providerNames('termux'), isEmpty);
      fixture.journal.records['termux'] = {
        'schema': 1,
        'job': _job,
        'selected': ['config'],
        'archives': {
          'config': {'bytes': _archive.bytes, 'sha256': _archive.sha256},
        },
      };
      fixture.archives.names = ['Anthropic'];
      expect(await controller.providerNames('termux'), ['Anthropic']);
      fixture.archives.namesError = StateError('synthetic-private-config');
      expect(await controller.providerNames('termux'), isEmpty);
      expect(fixture.transport.inspectCalls, 0);
      expect(fixture.transport.packCalls, 0);
      expect(fixture.switches, 0);
      controller.dispose();
    },
  );

  test(
    'journal removal is scoped and idempotent even after profile deletion',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.termuxMigration.termux': '{}',
        'oc.termuxMigration.other': '{}',
      });
      final prefs = await SharedPreferences.getInstance();
      final journal = PreferencesTermuxMigrationJournal(
        prefs,
        mayWrite: (_) => false,
      );
      await journal.remove('termux');
      await journal.remove('termux');
      expect(prefs.containsKey('oc.termuxMigration.termux'), isFalse);
      expect(prefs.containsKey('oc.termuxMigration.other'), isTrue);
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
  Object? packError;
  Future<void> Function()? onCancel;
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
    if (packError case final Object error) throw error;
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
  Future<void> cancel(String jobId) async {
    cancelledJobs.add(jobId);
    await onCancel?.call();
  }
}

class _FakeArchives extends TermuxMigrationArchiveStore {
  _FakeArchives() : super(support: Directory('/fake-app-private'));
  bool installed = true;
  int importCalls = 0;
  int cleanupCalls = 0;
  Object? verifyError;
  Object? cleanupError;
  Object? namesError;
  List<String> names = [];
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
  Future<void> cleanupPartial(String jobId) async {
    cleanupCalls++;
    if (cleanupError case final Object error) throw error;
  }

  @override
  Future<List<String>> providerNames(
    String jobId,
    TermuxMigrationArchive expected,
  ) async {
    if (namesError case final Object error) throw error;
    return names;
  }
}

class _MemoryJournal implements TermuxMigrationJournal {
  Future<void>? readGate;
  final records = <String, Map<String, dynamic>>{};

  @override
  Future<void> remove(String sourceProfileId) async {
    records.remove(sourceProfileId);
  }

  @override
  Future<Map<String, dynamic>?> read(String sourceProfileId) async {
    await readGate;
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
