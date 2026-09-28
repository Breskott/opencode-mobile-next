import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/migration/migration_space.dart';
import 'package:opencode_mobile/domain/termux_migration.dart';

void main() {
  const projects = TermuxMigrationItem.projects;
  const config = TermuxMigrationItem.config;
  const largeFree = 2 * 1024 * 1024 * 1024;

  TermuxMigrationSource source(
    List<TermuxMigrationSize> sizes, {
    int free = largeFree,
  }) => TermuxMigrationSource(items: sizes, freeBytes: free);

  Matcher failure(TermuxMigrationFailure code) =>
      isA<TermuxMigrationException>().having((e) => e.code, 'code', code);

  test('selected subset uses the conservative retained-copy budget', () {
    final inventory = source(const [
      TermuxMigrationSize(projects, 100, 2),
      TermuxMigrationSize(config, 200, 3),
    ]);
    final subset = migrationSpaceFor(inventory, {projects}, largeFree);
    expect(
      subset.requiredBytes,
      3 * (100 + 2 * 4096 + 10240) + 64 * 1024 * 1024,
    );
    final both = migrationSpaceFor(inventory, {projects, config}, largeFree);
    expect(
      both.requiredBytes,
      3 * (100 + 2 * 4096 + 10240 + 200 + 3 * 4096 + 10240) +
          migrationReserveBytes,
    );
    expect(both.sufficient, isTrue);
  });

  test('capacity is the smaller reading and equality fits', () {
    final inventory = source(const [TermuxMigrationSize(projects, 10, 1)]);
    final required = migrationSpaceFor(inventory, {
      projects,
    }, largeFree).requiredBytes!;
    final appLimited = migrationSpaceFor(inventory, {projects}, required - 1);
    expect(appLimited.availableBytes, required - 1);
    expect(appLimited.sufficient, isFalse);
    final sourceLimited = migrationSpaceFor(
      source(inventory.items, free: required - 1),
      {projects},
      largeFree,
    );
    expect(sourceLimited.availableBytes, required - 1);
    expect(sourceLimited.sufficient, isFalse);
    expect(
      migrationSpaceFor(source(inventory.items, free: required), {
        projects,
      }, required).sufficient,
      isTrue,
    );
  });

  test('unknown readings remain unknown and retain the measured side', () {
    final inventory = source(const [TermuxMigrationSize(projects, 10, 1)]);
    for (final appFree in [null, -1]) {
      final budget = migrationSpaceFor(inventory, {projects}, appFree);
      expect(budget.requiredBytes, isPositive);
      expect(budget.appAvailableBytes, isNull);
      expect(budget.sourceAvailableBytes, largeFree);
      expect(budget.availableBytes, isNull);
      expect(budget.sufficient, isNull);
    }
    final unknownSource = migrationSpaceFor(source(inventory.items, free: -1), {
      projects,
    }, largeFree);
    expect(unknownSource.appAvailableBytes, largeFree);
    expect(unknownSource.sourceAvailableBytes, isNull);
    expect(unknownSource.availableBytes, isNull);
    expect(unknownSource.sufficient, isNull);
  });

  test('empty selection requires zero and does not count refused items', () {
    final inventory = source(const [
      TermuxMigrationSize(
        config,
        0,
        0,
        problem: TermuxMigrationFailure.unsupportedEntry,
      ),
    ]);
    expect(migrationSpaceFor(inventory, {}, 0).requiredBytes, 0);
    expect(migrationSpaceFor(inventory, {}, 0).sufficient, isTrue);
    expect(migrationSpaceFor(inventory, {}, null).sufficient, isNull);
  });

  test(
    'refused selection fails with its fixed code, unselected refusal is ignored',
    () {
      final inventory = source(const [
        TermuxMigrationSize(projects, 5, 1),
        TermuxMigrationSize(
          config,
          0,
          0,
          problem: TermuxMigrationFailure.unsupportedEntry,
        ),
      ]);
      expect(
        () => migrationSpaceFor(inventory, {config}, largeFree),
        throwsA(failure(TermuxMigrationFailure.unsupportedEntry)),
      );
      expect(
        migrationSpaceFor(inventory, {projects}, largeFree).sufficient,
        isTrue,
      );
    },
  );

  test('missing or malformed measurements cannot produce a budget', () {
    for (final inventory in [
      source(const []),
      source(const [TermuxMigrationSize(projects, -1, 0)]),
      source(const [TermuxMigrationSize(projects, 0, -1)]),
      source(const [
        TermuxMigrationSize(projects, 0, 0),
        TermuxMigrationSize(projects, 0, 0),
      ]),
    ]) {
      expect(
        () => migrationSpaceFor(inventory, {projects}, largeFree),
        throwsA(failure(TermuxMigrationFailure.invalidSelection)),
      );
    }
  });

  test(
    'archive and entry limits include boundaries and apply per selected item',
    () {
      final exactArchive = source(const [
        TermuxMigrationSize(
          projects,
          migrationMaxArchiveBytes - 1024 - 10240,
          1,
        ),
      ]);
      expect(
        migrationSpaceFor(exactArchive, {projects}, largeFree).sufficient,
        isTrue,
      );
      final exactEntries = source(const [
        TermuxMigrationSize(projects, 0, migrationMaxEntries),
      ]);
      expect(
        migrationSpaceFor(exactEntries, {projects}, largeFree).sufficient,
        isTrue,
      );
      for (final size in [
        const TermuxMigrationSize(
          projects,
          migrationMaxArchiveBytes - 1024 - 10240 + 1,
          1,
        ),
        const TermuxMigrationSize(projects, 0, migrationMaxEntries + 1),
      ]) {
        expect(
          () => migrationSpaceFor(source([size]), {projects}, largeFree),
          throwsA(failure(TermuxMigrationFailure.tooLarge)),
        );
        expect(
          migrationSpaceFor(source([size]), {}, largeFree).requiredBytes,
          0,
        );
      }
    },
  );
}
