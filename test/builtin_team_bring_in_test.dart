// The team's merged work reaches the project folder (BuiltinTeam.originHook,
// installed into the phone-side origin by rigScript and on every start), checked with
// real git in temporary folders: the refinery's push to the origin
// fast-forwards a clean project, a project with changes of its own or commits
// of its own is left alone and the log says why, the push never fails, and
// rigScript installs (and re-installs) the hook for the origins it makes only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/ui/widgets/builtin_team_section.dart'
    show builtinTeamBringInText;

bool get _hasGit =>
    Process.runSync('sh', ['-c', 'command -v git']).exitCode == 0;

void main() {
  late Directory root;
  late String home; // stands in for /root/aiteam
  late String project;
  late String origin;
  late Map<String, String> env;

  ProcessResult git(String dir, List<String> args) {
    final result = Process.runSync('git', [
      '-C',
      dir,
      ...args,
    ], environment: env);
    if (result.exitCode != 0) {
      fail('git ${args.join(' ')} in $dir: ${result.stderr}');
    }
    return result;
  }

  String out(String dir, List<String> args) =>
      (git(dir, args).stdout as String).trim();

  /// The script with the phone's paths moved into [root].
  String local(String script) => script
      .replaceAll(BuiltinTeam.home, home)
      .replaceAll('export HOME=/root ', 'export HOME=${root.path} ');

  List<BuiltinTeamBringIn> log() {
    final file = File('$home/pull.log');
    if (!file.existsSync()) return const [];
    return [
      for (final line in file.readAsLinesSync())
        ?BuiltinTeamBringIn.parse(line),
    ];
  }

  /// The refinery: a clone of the origin that commits [file] and pushes
  /// master. Returns the push's exit code and the new commit.
  (int, String) teamMerges(String file, String content) {
    final clone = '${root.path}/refinery';
    if (!Directory(clone).existsSync()) {
      final result = Process.runSync('git', [
        'clone',
        '-q',
        origin,
        clone,
      ], environment: env);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    } else {
      git(clone, ['pull', '-q', '--ff-only', 'origin', 'master']);
    }
    File('$clone/$file').writeAsStringSync(content);
    git(clone, ['add', file]);
    git(clone, ['commit', '-q', '-m', 'Add $file']);
    final push = Process.runSync('git', [
      '-C',
      clone,
      'push',
      '-q',
      'origin',
      'HEAD:master',
    ], environment: env);
    return (push.exitCode, out(clone, ['rev-parse', 'HEAD']));
  }

  /// What every team start does (BuiltinTeam.hooksScript), for the
  /// project Gas City lists in its site.toml.
  void installHook() {
    Directory('$home/city/.gc').createSync(recursive: true);
    File('$home/city/.gc/site.toml').writeAsStringSync(
      'workspace_name = "phone"\n\n[[rig]]\nname = "my-app"\n'
      'path = "$project"\n',
    );
    final result = Process.runSync('sh', [
      '-c',
      'set -eu\n${local(BuiltinTeam.hooksScript)}',
    ], environment: env);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(File('$origin/hooks/post-receive').existsSync(), isTrue);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('oc-bring-in');
    home = '${root.path}/aiteam';
    project = '${root.path}/projects/my-app';
    origin = '$home/origins/my-app.git';
    env = {
      'HOME': root.path,
      'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin',
      'GIT_CONFIG_NOSYSTEM': '1',
      'GIT_AUTHOR_NAME': 'Test',
      'GIT_AUTHOR_EMAIL': 'test@example.invalid',
      'GIT_COMMITTER_NAME': 'Test',
      'GIT_COMMITTER_EMAIL': 'test@example.invalid',
    };
    File(
      '${root.path}/.gitconfig',
    ).writeAsStringSync('[init]\n\tdefaultBranch = master\n');
    Directory(project).createSync(recursive: true);
    git(project, ['init', '-q']);
    // What a project the team works on looks like: its own file, the bead
    // store's tracked bookkeeping and Gas City's .gitignore.
    File('$project/README.md').writeAsStringSync('mine\n');
    Directory('$project/.beads').createSync();
    File('$project/.beads/interactions.jsonl').writeAsStringSync('');
    File('$project/.gitignore').writeAsStringSync('*.db\n');
    git(project, ['add', '.']);
    git(project, ['commit', '-q', '-m', 'Start']);
    Directory('$home/origins').createSync(recursive: true);
    git(root.path, ['init', '-q', '--bare', origin]);
    git(project, ['remote', 'add', 'origin', origin]);
    git(project, ['push', '-q', 'origin', 'HEAD']);
  });

  tearDown(() => root.delete(recursive: true));

  group('the origin hook', () {
    test('parses in dash and bash', () async {
      for (final shell in ['dash', 'bash']) {
        if (Process.runSync('sh', ['-c', 'command -v $shell']).exitCode != 0) {
          continue;
        }
        for (final script in [
          BuiltinTeam.originHook,
          BuiltinTeam.hooksScript,
          BuiltinTeam.bringInScript("/root/projects/it's", 'its'),
        ]) {
          final result = await Process.run(shell, ['-n', '-c', script]);
          expect(result.exitCode, 0, reason: '$shell: ${result.stderr}');
        }
      }
    });

    test(
      'a merge fast-forwards a clean project, bookkeeping aside',
      () {
        installHook();
        // The team's own bookkeeping changes in the project do not count.
        File('$project/.beads/interactions.jsonl').writeAsStringSync('{}\n');
        File('$project/.gitignore').writeAsStringSync('*.db\n.beads/*\n');
        final (code, merged) = teamMerges('hello.py', 'print("hi")\n');
        expect(code, 0);
        expect(out(project, ['rev-parse', 'HEAD']), merged);
        expect(File('$project/hello.py').readAsStringSync(), 'print("hi")\n');
        // The bookkeeping is untouched.
        expect(
          File('$project/.beads/interactions.jsonl').readAsStringSync(),
          '{}\n',
        );
        final last = log().last;
        expect(last.outcome, BuiltinTeamBringInOutcome.broughtIn);
        expect(last.rig, 'my-app');
        expect(merged, startsWith(last.commit!));
        expect(last.detail, 'Add hello.py');
      },
      skip: _hasGit ? false : 'no git',
    );

    test(
      'a project with changes of its own is left alone',
      () {
        installHook();
        final before = out(project, ['rev-parse', 'HEAD']);
        File('$project/README.md').writeAsStringSync('mine, edited\n');
        final (code, _) = teamMerges('hello.py', 'print("hi")\n');
        expect(code, 0, reason: 'the push never fails');
        expect(out(project, ['rev-parse', 'HEAD']), before);
        expect(File('$project/hello.py').existsSync(), isFalse);
        expect(File('$project/README.md').readAsStringSync(), 'mine, edited\n');
        final last = log().last;
        expect(last.outcome, BuiltinTeamBringInOutcome.dirty);
        expect(last.detail, contains('README.md'));
        expect(last.leftBehind, isTrue);

        // Once the person's change is gone, the app's "Bring the team's work
        // in" does what the hook would have.
        git(project, ['checkout', '--', 'README.md']);
        final now = Process.runSync('sh', [
          '-c',
          local(BuiltinTeam.bringInScript(project, 'my-app')),
        ], environment: env);
        expect(now.exitCode, 0);
        final printed = BuiltinTeamBringIn.parse(
          (now.stdout as String).trim().split('\n').last,
        );
        expect(printed?.outcome, BuiltinTeamBringInOutcome.broughtIn);
        expect(File('$project/hello.py').existsSync(), isTrue);
      },
      skip: _hasGit ? false : 'no git',
    );

    test(
      'a project with commits of its own is never rewritten',
      () {
        installHook();
        File('$project/notes.txt').writeAsStringSync('local\n');
        git(project, ['add', 'notes.txt']);
        git(project, ['commit', '-q', '-m', 'Local work']);
        final before = out(project, ['rev-parse', 'HEAD']);
        final (code, _) = teamMerges('hello.py', 'print("hi")\n');
        expect(code, 0);
        expect(out(project, ['rev-parse', 'HEAD']), before);
        expect(log().last.outcome, BuiltinTeamBringInOutcome.diverged);
      },
      skip: _hasGit ? false : 'no git',
    );

    test('a push to another branch does nothing', () {
      installHook();
      final clone = '${root.path}/polecat';
      Process.runSync('git', ['clone', '-q', origin, clone], environment: env);
      File('$clone/wip.txt').writeAsStringSync('wip\n');
      git(clone, ['add', 'wip.txt']);
      git(clone, ['commit', '-q', '-m', 'WIP']);
      final before = log().length;
      git(clone, ['push', '-q', 'origin', 'HEAD:polecat/ma-1']);
      expect(log(), hasLength(before));
      expect(File('$project/wip.txt').existsSync(), isFalse);
    }, skip: _hasGit ? false : 'no git');
  });

  group('rigScript', () {
    /// A `gc` that accepts everything, so rigScript runs for real otherwise.
    Map<String, String> withFakeGc() {
      final bin = Directory('${root.path}/bin')..createSync();
      final gc = File('${bin.path}/gc')..writeAsStringSync('#!/bin/sh\n');
      Process.runSync('chmod', ['755', gc.path]);
      Directory('$home/city').createSync(recursive: true);
      File('$home/city/city.toml').writeAsStringSync('[workspace]\n');
      return {...env, 'PATH': '${bin.path}:${env['PATH']}'};
    }

    test(
      'makes the origin with the hook, and puts it back when re-run',
      () {
        final runEnv = withFakeGc();
        // A project with no origin yet.
        git(project, ['remote', 'remove', 'origin']);
        Directory(origin).deleteSync(recursive: true);
        ProcessResult run() => Process.runSync('sh', [
          '-c',
          local(BuiltinTeam.rigScript(project, 'my-app')),
        ], environment: runEnv);

        var result = run();
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        final hook = File('$origin/hooks/post-receive');
        expect(hook.existsSync(), isTrue);
        expect(out(origin, ['config', '--get', 'oc-mobile.project']), project);
        expect(out(origin, ['config', '--get', 'oc-mobile.rig']), 'my-app');
        // Brought up to date once when added.
        expect(log().last.outcome, BuiltinTeamBringInOutcome.upToDate);

        // A project added by an older version: no hook. Adding it again
        // installs it, and the work merged meanwhile comes in.
        hook.deleteSync();
        final (_, merged) = teamMerges('hello.py', 'print("hi")\n');
        expect(out(project, ['rev-parse', 'HEAD']), isNot(merged));
        result = run();
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(hook.existsSync(), isTrue);
        expect(out(project, ['rev-parse', 'HEAD']), merged);
        expect(log().last.outcome, BuiltinTeamBringInOutcome.broughtIn);

        // From now on a merge comes in by itself.
        final (_, next) = teamMerges('two.py', 'print(2)\n');
        expect(out(project, ['rev-parse', 'HEAD']), next);
      },
      skip: _hasGit ? false : 'no git',
    );

    test(
      'leaves an origin of the project\'s own alone',
      () {
        final runEnv = withFakeGc();
        final own = '${root.path}/elsewhere.git';
        git(root.path, ['init', '-q', '--bare', own]);
        git(project, ['remote', 'set-url', 'origin', own]);
        final result = Process.runSync('sh', [
          '-c',
          local(BuiltinTeam.rigScript(project, 'my-app')),
        ], environment: runEnv);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(File('$own/hooks/post-receive').existsSync(), isFalse);
        expect(log(), isEmpty);
      },
      skip: _hasGit ? false : 'no git',
    );
  });

  test('the status script reports the newest outcome per project', () {
    Directory(home).createSync(recursive: true);
    File('$home/pull.log').writeAsStringSync(
      '2026-09-24T10:00:00Z\tmy-app\tdirty\tabc1234\tREADME.md \n'
      '2026-09-24T10:05:00Z\tdemo\tup-to-date\tdef5678\tStart\n'
      '2026-09-24T10:10:00Z\tmy-app\tbrought-in\t0123abc\tAdd hello.py\n',
    );
    final result = Process.runSync('sh', [
      '-c',
      BuiltinTeam.statusScript
          .replaceAll(BuiltinTeam.cityDir, '${root.path}/none')
          .replaceAll(BuiltinTeam.home, home),
    ]);
    final state = BuiltinTeam.parseStatus(result.stdout as String);
    final mine = state.bringInFor('/root/projects/my-app')!;
    expect(mine.outcome, BuiltinTeamBringInOutcome.broughtIn);
    expect(mine.commit, '0123abc');
    expect(mine.detail, 'Add hello.py');
    expect(mine.time, DateTime.utc(2026, 9, 24, 10, 10));
    expect(
      state.bringInFor('/root/projects/demo')!.outcome,
      BuiltinTeamBringInOutcome.upToDate,
    );
    expect(state.bringInFor('/root/projects/other'), isNull);
  });

  test('the Plugins section says where the team\'s work is', () {
    final en = AppLocalizationsEn();
    BuiltinTeamBringIn line(String text) =>
        BuiltinTeamBringIn.parse('2026-09-24T10:00:00Z\tmy-app\t$text')!;
    expect(
      builtinTeamBringInText(
        en,
        line('brought-in\t86759b9\tAdd hello.py'),
        'my-app',
      ),
      "my-app has the team's latest work (86759b9 Add hello.py).",
    );
    final dirty = line('dirty\t86759b9\tREADME.md ');
    expect(dirty.leftBehind, isTrue);
    expect(
      builtinTeamBringInText(en, dirty, 'my-app'),
      "The team's work (86759b9) is not in my-app yet: my-app has changes "
      'of its own (README.md), so it was left as it is.',
    );
    expect(
      builtinTeamBringInText(en, line('diverged\t86759b9\tx'), 'my-app'),
      contains('has commits of its own'),
    );
    expect(BuiltinTeamBringIn.parse('not a log line'), isNull);
    expect(BuiltinTeamBringIn.parse('t\tmy-app\tsomething-else\t-\t'), isNull);
  });
}
