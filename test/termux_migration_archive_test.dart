import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/migration/migration_archive_store.dart';
import 'package:opencode_mobile/domain/termux_migration.dart';

void main() {
  late Directory support;
  late TermuxMigrationArchiveStore store;
  setUp(() async {
    support = await Directory.systemTemp.createTemp('migration-archive-');
    store = TermuxMigrationArchiveStore(support: support);
    await Directory(
      '${support.path}/linux/ubuntu/root',
    ).create(recursive: true);
    await File('${support.path}/linux/ubuntu.ready').writeAsString('ready');
  });
  tearDown(() async => support.delete(recursive: true));

  Future<(File, TermuxMigrationArchive)> archive(List<_Entry> entries) async {
    final bytes = _tar(entries);
    final file = await File('${support.path}/transfer.tar').writeAsBytes(bytes);
    return (
      file,
      TermuxMigrationArchive(
        bytes: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
    );
  }

  test(
    'imports projects privately, preserves executability and resumes commit',
    () async {
      final (file, expected) = await archive([
        const _Entry('./', type: 53),
        const _Entry('./repo/', type: 53),
        const _Entry('./repo/readme', content: 'content'),
        const _Entry('./repo/run', content: '#!/bin/sh\n', mode: 493),
      ]);
      await store.importItem(
        'job1',
        TermuxMigrationItem.projects,
        file,
        expected,
        cancelled: () => false,
      );
      final project = '${support.path}/projects/termux-job1';
      expect(await File('$project/repo/readme').readAsString(), 'content');
      expect((await FileStat.stat('$project/repo/readme')).mode & 511, 384);
      expect((await FileStat.stat('$project/repo/run')).mode & 511, 448);
      expect(
        await store.imported('job1', TermuxMigrationItem.projects, expected),
        isTrue,
      );
      // No external completion marker is needed after an atomic rename.
      await file.delete();
      await store.importItem(
        'job1',
        TermuxMigrationItem.projects,
        file,
        expected,
        cancelled: () => false,
      );
      expect(await File('$project/repo/readme').readAsString(), 'content');
      final incoming = await Directory(
        '${store.jobDirectory('job1').path}/incoming',
      ).create(recursive: true);
      await File('${incoming.path}/projects.tar').writeAsBytes([1, 2, 3]);
      await File('${incoming.path}/projects.offset').writeAsString('3');
      await store.cleanupPartial('job1');
      expect(await store.jobDirectory('job1').exists(), isFalse);
      expect(await File('$project/repo/readme').readAsString(), 'content');
      expect(
        await store.imported('job1', TermuxMigrationItem.projects, expected),
        isTrue,
      );
      // Completed cleanup is itself safe to repeat.
      await store.cleanupPartial('job1');
    },
  );

  test(
    'a changed imported file is preserved and fails closed on rerun',
    () async {
      final (file, expected) = await archive([
        const _Entry('repo/file', content: 'old'),
      ]);
      await store.importItem(
        'job2',
        TermuxMigrationItem.projects,
        file,
        expected,
        cancelled: () => false,
      );
      final imported = File('${support.path}/projects/termux-job2/repo/file');
      await imported.writeAsString('owner changed it');
      await expectLater(
        store.importItem(
          'job2',
          TermuxMigrationItem.projects,
          file,
          expected,
          cancelled: () => false,
        ),
        throwsA(_failure(TermuxMigrationFailure.destinationConflict)),
      );
      expect(await imported.readAsString(), 'owner changed it');
    },
  );

  test('checksum mismatch never commits', () async {
    final (file, expected) = await archive([
      const _Entry('file', content: 'private'),
    ]);
    await expectLater(
      store.importItem(
        'bad',
        TermuxMigrationItem.config,
        file,
        TermuxMigrationArchive(bytes: expected.bytes, sha256: '0' * 64),
        cancelled: () => false,
      ),
      throwsA(_failure(TermuxMigrationFailure.checksumMismatch)),
    );
    expect(
      await Directory(
        '${support.path}/linux/ubuntu/root/.oc-migration-exports',
      ).exists(),
      isFalse,
    );
  });

  test(
    'rejects traversal, links, duplicate names and invalid header checksum',
    () async {
      for (final entries in [
        [const _Entry('../escape', content: 'x')],
        [const _Entry('/absolute', content: 'x')],
        [const _Entry('link', type: 50)],
        [const _Entry('hardlink', type: 49)],
        [const _Entry('same'), const _Entry('same')],
        [const _Entry('parent'), const _Entry('parent/child')],
      ]) {
        final (file, expected) = await archive(entries);
        await expectLater(
          store.importItem(
            'malicious',
            TermuxMigrationItem.projects,
            file,
            expected,
            cancelled: () => false,
          ),
          throwsA(isA<TermuxMigrationException>()),
        );
      }
      final bytes = _tar([const _Entry('file')]);
      bytes[0] ^= 1;
      final file = await File(
        '${support.path}/transfer.tar',
      ).writeAsBytes(bytes);
      await expectLater(
        store.importItem(
          'malicious',
          TermuxMigrationItem.projects,
          file,
          TermuxMigrationArchive(
            bytes: bytes.length,
            sha256: sha256.convert(bytes).toString(),
          ),
          cancelled: () => false,
        ),
        throwsA(_failure(TermuxMigrationFailure.invalidArchive)),
      );
      expect(
        await Directory('${support.path}/projects/termux-malicious').exists(),
        isFalse,
      );
    },
  );

  test(
    'linked destination parent never reads or changes link target',
    () async {
      final outside = await Directory('${support.path}/outside').create();
      await File('${outside.path}/sentinel').writeAsString('untouched');
      await Link('${support.path}/projects').create(outside.path);
      final (file, expected) = await archive([
        const _Entry('file', content: 'x'),
      ]);
      await expectLater(
        store.importItem(
          'linked',
          TermuxMigrationItem.projects,
          file,
          expected,
          cancelled: () => false,
        ),
        throwsA(_failure(TermuxMigrationFailure.destinationConflict)),
      );
      expect(
        await File('${outside.path}/sentinel').readAsString(),
        'untouched',
      );
      expect(
        await Directory('${outside.path}/termux-linked').exists(),
        isFalse,
      );
    },
  );

  test(
    'stale staging is replaced; cancellation cleans only partial files',
    () async {
      final stage = await Directory(
        '${store.jobDirectory('resume').path}/staging/projects',
      ).create(recursive: true);
      await File('${stage.path}/old-partial').writeAsString('partial');
      final (file, expected) = await archive([
        _Entry('large', content: 'x' * 150000),
      ]);
      var checks = 0;
      await expectLater(
        store.importItem(
          'resume',
          TermuxMigrationItem.projects,
          file,
          expected,
          cancelled: () => ++checks > 4,
        ),
        throwsA(_failure(TermuxMigrationFailure.cancelled)),
      );
      expect(await stage.exists(), isFalse);
      await store.importItem(
        'resume',
        TermuxMigrationItem.projects,
        file,
        expected,
        cancelled: () => false,
      );
      expect(
        await store.imported('resume', TermuxMigrationItem.projects, expected),
        isTrue,
      );
      expect(
        await File(
          '${support.path}/projects/termux-resume/old-partial',
        ).exists(),
        isFalse,
      );
    },
  );

  test(
    'credentialed config remains private export with no payload in manifest/errors',
    () async {
      const secret = 'fake-test-credential-never-display';
      final (file, expected) = await archive([
        const _Entry('opencode.json', content: secret, mode: 511),
      ]);
      await store.importItem(
        'config',
        TermuxMigrationItem.config,
        file,
        expected,
        cancelled: () => false,
      );
      final export =
          '${support.path}/linux/ubuntu/root/.oc-migration-exports/config/config';
      expect((await FileStat.stat('$export/opencode.json')).mode & 511, 384);
      expect((await Directory(export).stat()).mode & 511, 448);
      final manifest = await File(
        '$export/.oc-migration-manifest.json',
      ).readAsString();
      expect(manifest.contains(secret), isFalse);
      expect(
        await File(
          '${support.path}/linux/ubuntu/root/.config/opencode/opencode.json',
        ).exists(),
        isFalse,
      );
      expect(
        const TermuxMigrationException(
          TermuxMigrationFailure.storage,
        ).toString(),
        'TermuxMigrationException(storage)',
      );
    },
  );
}

Matcher _failure(TermuxMigrationFailure code) =>
    isA<TermuxMigrationException>().having((error) => error.code, 'code', code);

class _Entry {
  const _Entry(this.path, {this.content = '', this.type = 48, this.mode = 420});
  final String path;
  final String content;
  final int type;
  final int mode;
}

Uint8List _tar(List<_Entry> entries) {
  final builder = BytesBuilder();
  for (final entry in entries) {
    final header = Uint8List(512);
    void text(int offset, String value) => header.setRange(
      offset,
      offset + utf8.encode(value).length,
      utf8.encode(value),
    );
    final payload = utf8.encode(entry.content);
    text(0, entry.path);
    text(100, '${entry.mode.toRadixString(8).padLeft(7, '0')}\u0000');
    text(108, '0000000\u0000');
    text(116, '0000000\u0000');
    text(124, '${payload.length.toRadixString(8).padLeft(11, '0')}\u0000');
    text(136, '00000000000\u0000');
    header.fillRange(148, 156, 32);
    header[156] = entry.type;
    text(257, 'ustar\u0000');
    text(263, '00');
    final checksum = header.fold<int>(0, (sum, byte) => sum + byte);
    text(148, '${checksum.toRadixString(8).padLeft(6, '0')}\u0000 ');
    builder.add(header);
    builder.add(payload);
    builder.add(Uint8List((512 - payload.length % 512) % 512));
  }
  builder.add(Uint8List(1024));
  return builder.takeBytes();
}
