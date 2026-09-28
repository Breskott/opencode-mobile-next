// A real TermuxMigrationController over fakes (no Termux, no files), for the
// migration UI's behaviour tests and goldens: Termux's inventory, packing
// and copying, the app's archive store and journal are stood in for, with
// hooks to hold a stage open, fail it with a fixed code, or throw raw text.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:opencode_mobile/builtin/migration/migration_archive_store.dart';
import 'package:opencode_mobile/builtin/migration/termux_migration_controller.dart';
import 'package:opencode_mobile/builtin/migration/termux_migration_transport.dart';
import 'package:opencode_mobile/domain/termux_migration.dart';
import 'package:opencode_mobile/state/termux_migration_owner.dart';

const migrationJob = '0123456789abcdef0123456789abcdef';
const migrationSource = 'termux';
const _sha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const ampleSpace = 64 * 1024 * 1024 * 1024;

/// A Termux inventory: projects, the private copies, and one refused item.
const sampleInventory = [
  TermuxMigrationSize(TermuxMigrationItem.projects, 431227699, 3412),
  TermuxMigrationSize(TermuxMigrationItem.config, 48128, 23),
  TermuxMigrationSize(TermuxMigrationItem.sessions, 210763776, 5),
  TermuxMigrationSize(TermuxMigrationItem.gitConfig, 812, 1),
  TermuxMigrationSize(TermuxMigrationItem.shellFiles, 5120, 3),
  TermuxMigrationSize(
    TermuxMigrationItem.aiTeam,
    0,
    0,
    problem: TermuxMigrationFailure.unsupportedEntry,
  ),
];

class FakeMigrationTransport implements TermuxMigrationTransport {
  int inspectCalls = 0;
  int packCalls = 0;
  int sourceFreeBytes = ampleSpace;
  List<TermuxMigrationSize> items = sampleInventory;
  Object? inspectError;

  /// Thrown by the next pack (then cleared).
  Object? packError;

  /// Held open while set: the stage stays on screen until completed.
  Completer<void>? packGate;
  Completer<void>? copyGate;
  final cancelled = <String>[];

  @override
  Future<TermuxMigrationSource> inspect() async {
    inspectCalls++;
    if (inspectError case final Object error) throw error;
    return TermuxMigrationSource(items: items, freeBytes: sourceFreeBytes);
  }

  @override
  Future<TermuxMigrationArchive> pack(
    String jobId,
    TermuxMigrationItem item, {
    required int maxBytes,
  }) async {
    packCalls++;
    if (packGate case final Completer<void> gate) await gate.future;
    if (packError case final Object error) {
      packError = null;
      throw error;
    }
    return TermuxMigrationArchive(bytes: 10240 + item.index, sha256: _sha);
  }

  @override
  Future<void> copy(
    String jobId,
    TermuxMigrationItem item,
    TermuxMigrationArchive archive,
    File destination, {
    required bool Function() cancelled,
  }) async {
    if (copyGate case final Completer<void> gate) await gate.future;
  }

  @override
  Future<void> cancel(String jobId) async {
    cancelled.add(jobId);
    // Termux stops: the held stage ends.
    if (packGate case final gate? when !gate.isCompleted) gate.complete();
    if (copyGate case final gate? when !gate.isCompleted) gate.complete();
  }
}

class FakeMigrationArchives extends TermuxMigrationArchiveStore {
  FakeMigrationArchives() : super(support: Directory('/fake-app-private'));
  bool installed = true;
  final receipts = <TermuxMigrationItem, TermuxMigrationArchive>{};

  @override
  Future<bool> builtinInstalled() async => installed;

  @override
  Directory jobDirectory(String jobId) => Directory('/fake-app-private/$jobId');

  @override
  Future<void> verify(File archive, TermuxMigrationArchive expected) async {}

  @override
  Future<void> importItem(
    String jobId,
    TermuxMigrationItem item,
    File archive,
    TermuxMigrationArchive expected, {
    required bool Function() cancelled,
  }) async => receipts[item] = expected;

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
  Future<void> cleanupPartial(String jobId) async {}
}

class MemoryMigrationJournal implements TermuxMigrationJournal {
  final records = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String sourceProfileId) async {
    final value = records[sourceProfileId];
    return value == null
        ? null
        : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String sourceProfileId, Map<String, dynamic> value) async {
    records[sourceProfileId] =
        jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  /// A copy saved before the app was closed, for [items].
  void saveUnfinished(List<TermuxMigrationItem> items, {bool done = false}) {
    records[migrationSource] = {
      'schema': 1,
      'job': migrationJob,
      'selected': [for (final item in items) item.name]..sort(),
      'archives': <String, dynamic>{},
      if (done) 'done': true,
      if (done) 'destination': 'builtin',
    };
  }
}

/// One migration: the fakes, the real controller over them, and the owner
/// the UI reads.
class MigrationFixture {
  final transport = FakeMigrationTransport();
  final archives = FakeMigrationArchives();
  final journal = MemoryMigrationJournal();
  int? freeBytes = ampleSpace;
  int switches = 0;
  Object? switchError;
  TermuxMigrationController? controller;

  late final owner = TermuxMigrationOwner(
    create: (_, _) async => controller = TermuxMigrationController(
      transport: transport,
      archives: archives,
      journal: journal,
      availableBytes: () async => freeBytes,
      sourceProfileExists: (id) => id == migrationSource,
      newJobId: () => migrationJob,
      switchProfile:
          ({
            required sourceProfileId,
            required stillWanted,
            required verifiedProjectPaths,
          }) async {
            if (switchError case final Object error) throw error;
            switches++;
            return 'builtin';
          },
    ),
  );

  /// Ends every held stage and settles the owner.
  Future<void> close() async {
    for (final gate in [transport.packGate, transport.copyGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    await owner.cancel();
    await owner.settled();
    owner.dispose();
  }
}
