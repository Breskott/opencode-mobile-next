// Folders of OpenCode inside the app, read straight from Ubuntu's files on
// the phone (lib/builtin/builtin_folders.dart): no server, no Ubuntu run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_folders.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';

/// A stopped Ubuntu: running anything in it, or asking about its server,
/// fails the test.
class _StoppedLinux extends BuiltinLinux {
  final calls = <String>[];
  var projects = <String>[];

  @override
  Future<BuiltinLinuxStatus> status() async {
    calls.add('status');
    return const BuiltinLinuxStatus(
      installed: true,
      phase: BuiltinLinuxPhase.ready,
    );
  }

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    calls.add(script);
    if (script == BuiltinLinux.listProjectsScript()) {
      return BuiltinLinuxRunResult(
        exitCode: 0,
        output: projects.map((name) => '$name\n').join(),
      );
    }
    return const BuiltinLinuxRunResult(exitCode: 127, output: 'unexpected');
  }
}

void main() {
  late Directory temp;
  late Directory rootfs;

  void folder(String path) =>
      Directory('${rootfs.path}$path').createSync(recursive: true);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('rootfs');
    rootfs = Directory('${temp.path}/ubuntu')..createSync();
    folder('/root/projects/demo/.git');
    folder('/root/projects/demo/src');
    folder('/root/projects/Notes');
    folder('/root/projects/.cache');
    File('${rootfs.path}/root/projects/README.md').createSync();
    Link('${rootfs.path}/root/projects/alias').createSync('/etc');
    // A worktree's .git is a file, not a folder.
    folder('/root/projects/wt');
    File('${rootfs.path}/root/projects/wt/.git').writeAsStringSync('gitdir:');
    for (final name in ['dev', 'proc', 'sys', 'usr', 'opt']) {
      folder('/$name');
    }
  });

  tearDown(() => temp.deleteSync(recursive: true));

  BuiltinRootfsFolders lister() =>
      BuiltinRootfsFolders(locate: () async => rootfs);

  test('lists folders with their git mark, sorted, without hidden, files '
      'or links', () async {
    final entries = await lister().list('/root/projects');
    expect(
      [for (final e in entries) (e.name, e.path, e.isGit)],
      [
        ('demo', '/root/projects/demo', true),
        ('Notes', '/root/projects/Notes', false),
        ('wt', '/root/projects/wt', true),
      ],
    );
  });

  test('goes into a folder and back up to /', () async {
    final folders = lister();
    final inside = await folders.list('/root/projects/demo');
    expect([for (final e in inside) e.path], ['/root/projects/demo/src']);
    expect(
      BuiltinRootfsFolders.parentOf('/root/projects/demo'),
      '/root/projects',
    );
    expect(BuiltinRootfsFolders.parentOf('/root'), '/');
    expect(BuiltinRootfsFolders.parentOf('/'), isNull);
    final top = await folders.list('/');
    // /dev, /proc and /sys are Android's at run time: empty here, not shown.
    expect([for (final e in top) e.name], ['opt', 'root', 'usr']);
  });

  test('a fresh install without the projects folder lists nothing', () async {
    Directory('${rootfs.path}/root/projects').deleteSync(recursive: true);
    expect(await lister().list('/root/projects'), isEmpty);
    await expectLater(
      lister().list('/root/elsewhere'),
      throwsA(
        isA<FolderListException>().having(
          (e) => e.problem,
          'problem',
          FolderListProblem.missing,
        ),
      ),
    );
  });

  test('never follows a link or climbs out with ..', () async {
    await expectLater(
      lister().list('/root/projects/alias'),
      throwsA(
        isA<FolderListException>().having(
          (e) => e.problem,
          'problem',
          FolderListProblem.linked,
        ),
      ),
    );
    await expectLater(
      lister().list('/root/../../..'),
      throwsA(
        isA<FolderListException>().having(
          (e) => e.problem,
          'problem',
          FolderListProblem.invalid,
        ),
      ),
    );
    expect(
      BuiltinRootfsFolders.normalize('/root//projects/./demo/'),
      '/root/projects/demo',
    );
    expect(BuiltinRootfsFolders.normalize('root/projects'), isNull);
  });

  test('lists with the server stopped and never runs Ubuntu', () async {
    final linux = _StoppedLinux();
    final folders = BuiltinFolders(linux, rootfs: lister());
    final entries = await folders.list('/root/projects');
    expect([for (final e in entries) e.name], ['demo', 'Notes', 'wt']);
    expect(linux.calls, isEmpty);
  });

  test('without Ubuntu\'s files, only the projects folder is listed, through '
      'Ubuntu', () async {
    final linux = _StoppedLinux()..projects = ['hello'];
    final folders = BuiltinFolders.throughUbuntu(linux);
    final entries = await folders.list('/root/projects');
    expect([for (final e in entries) e.path], ['/root/projects/hello']);
    expect(entries.single.isGit, isFalse, reason: 'not claimed unchecked');
    await expectLater(
      folders.list('/root'),
      throwsA(
        isA<FolderListException>().having(
          (e) => e.problem,
          'problem',
          FolderListProblem.failed,
        ),
      ),
    );
  });

  test('Ubuntu\'s place on the phone matches the Android side', () {
    // BuiltinRootfsFolders.locateRootfs mirrors these three lines.
    final kotlin = File(
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/'
      'BuiltinLinux.kt',
    ).readAsStringSync();
    expect(kotlin, contains('val home = File(context.filesDir, "linux")'));
    expect(kotlin, contains('val rootfs = File(home, "ubuntu")'));
    expect(kotlin, contains('File(home, "ubuntu.ready")'));
  });
}
