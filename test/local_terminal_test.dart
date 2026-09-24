
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/local_terminal.dart';
import 'package:opencode_mobile/ui/kit/terminal_key_bar.dart';

import 'support/fake_local_terminal.dart';

// The Dart side of the local terminal (docs/design/local-terminal-2026-09-24.md
// §1): shells that Android runs on a PTY, drawn by xterm here.

String screenText(LocalShell shell) {
  final buffer = shell.terminal.buffer;
  return [
    for (var i = 0; i < buffer.lines.length; i++)
      buffer.lines[i].getText().trimRight(),
  ].where((line) => line.isNotEmpty).join('\n');
}

void main() {
  late FakeLocalTerminalBackend backend;
  late LocalTerminalSessions sessions;

  setUp(() {
    backend = FakeLocalTerminalBackend();
    sessions = LocalTerminalSessions(backend: backend);
  });

  tearDown(() async {
    sessions.dispose();
    await backend.close();
  });

  group('a new shell', () {
    test('starts at the terminal size, then runs', () async {
      final shell = sessions.startShell(rows: 30, cols: 100);
      expect(shell.state, LocalShellState.starting);
      expect(shell.number, 1);
      await pumpEventQueue();
      expect(backend.calls, contains('start 30 x 100'));
      expect(shell.state, LocalShellState.running);
      expect(shell.id, 1);
      expect(shell.pid, 1001);
    });

    test('a failed start says why', () async {
      backend.startFailure = 'Ubuntu is not installed in the app yet';
      final shell = sessions.startShell();
      await pumpEventQueue();
      expect(shell.state, LocalShellState.failed);
      expect(shell.failure, contains('Ubuntu is not installed'));
    });

    test('shells are numbered in the order they were opened', () async {
      final first = sessions.startShell();
      final second = sessions.startShell();
      await pumpEventQueue();
      expect([first.number, second.number], [1, 2]);
      expect(sessions.shells, [first, second]);
    });
  });

  group('output', () {
    test('is drawn and every chunk is answered', () async {
      final shell = sessions.startShell();
      await pumpEventQueue();
      backend.output(1, 'root@localhost:~# ');
      await pumpEventQueue();
      expect(screenText(shell), 'root@localhost:~#');
      expect(backend.acks, 1);
    });

    test('a character split across two chunks arrives whole', () async {
      final shell = sessions.startShell();
      await pumpEventQueue();
      // "日本" in UTF-8, cut inside the second character.
      backend.outputBytes(1, [0xE6, 0x97, 0xA5, 0xE6]);
      backend.outputBytes(1, [0x9C, 0xAC]);
      await pumpEventQueue();
      expect(screenText(shell), contains('日本'));
      expect(screenText(shell), isNot(contains('�')));
    });

    test(
      'output for a shell this side does not know is still answered',
      () async {
        sessions.startShell();
        await pumpEventQueue();
        backend.output(42, 'stray');
        await pumpEventQueue();
        expect(backend.acks, 1);
      },
    );

    test('an exit ends the shell with its code', () async {
      final shell = sessions.startShell();
      await pumpEventQueue();
      backend.exit(1, 130);
      await pumpEventQueue();
      expect(shell.state, LocalShellState.exited);
      expect(shell.exitCode, 130);
      expect(shell.running, isFalse);
    });
  });

  group('input', () {
    test('typed text reaches the shell as UTF-8', () async {
      final shell = sessions.startShell();
      await pumpEventQueue();
      shell.terminal.textInput('ls é\r');
      await pumpEventQueue();
      expect(backend.writtenText(1), 'ls é\r');
    });

    test(
      'a sticky Ctrl turns the next typed letter into its control byte',
      () async {
        final shell = sessions.startShell();
        await pumpEventQueue();
        final keys = TerminalKeyBarController();
        shell.inputFilter = keys.apply;
        keys.toggle(TerminalBarKey.ctrl);
        // What the phone's keyboard delivers after the Ctrl tap.
        shell.terminal.textInput('c');
        shell.terminal.textInput('c');
        await pumpEventQueue();
        expect(backend.written[1], [0x03, 0x63]);
        expect(keys.ctrl, isFalse);
      },
    );

    test('nothing is sent before the shell runs or after it ended', () async {
      final shell = sessions.startShell();
      shell.terminal.textInput('early');
      await pumpEventQueue();
      backend.exit(1, 0);
      await pumpEventQueue();
      shell.terminal.textInput('late');
      await pumpEventQueue();
      expect(backend.written, isEmpty);
    });
  });

  group('size', () {
    test('a resize reaches the shell once the view settles', () async {
      final shell = sessions.startShell(rows: 24, cols: 80);
      await pumpEventQueue();
      shell.terminal.resize(60, 20);
      shell.terminal.resize(61, 21);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(backend.calls.where((call) => call.startsWith('resize')), [
        'resize 1 21 x 61',
      ]);
    });
  });

  group('shells outlive the screen', () {
    test('load adopts shells Android runs, with their recent output', () async {
      backend.existing.addAll(const [
        LocalShellInfo(id: 7, pid: 4242),
        LocalShellInfo(id: 8, pid: 4243, running: false, exitCode: 2),
      ]);
      backend.recent[7] = Uint8List.fromList('earlier output\r\n'.codeUnits);
      await sessions.load();
      expect(sessions.shells, hasLength(2));
      final adopted = sessions.shells.first;
      expect(adopted.id, 7);
      expect(adopted.running, isTrue);
      expect(screenText(adopted), 'earlier output');
      expect(sessions.shells.last.state, LocalShellState.exited);
      expect(sessions.processes, 5);
    });

    test('load runs once', () async {
      await sessions.load();
      await sessions.load();
      expect(backend.calls.where((call) => call == 'list'), hasLength(1));
    });

    test('restart replaces an ended shell', () async {
      final shell = sessions.startShell();
      await pumpEventQueue();
      backend.exit(1, 0);
      await pumpEventQueue();
      final next = sessions.restart(shell);
      await pumpEventQueue();
      expect(sessions.shells, [next]);
      expect(backend.calls, contains('remove 1'));
      expect(next.state, LocalShellState.running);
    });

    test('stop leaves the shell listed as ended', () async {
      final shell = sessions.startShell();
      await pumpEventQueue();
      await sessions.stop(shell);
      await pumpEventQueue();
      expect(backend.calls, contains('stop 1'));
      expect(shell.state, LocalShellState.exited);
      expect(sessions.shells, [shell]);
    });
  });

  group('channel', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('events are parsed from the Android shapes', () async {
      const events = EventChannel('test/local_terminal/events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({
              'type': 'output',
              'id': 3,
              'data': Uint8List.fromList([104, 105]),
            });
            sink.success({'type': 'exit', 'id': 3, 'code': 0});
            sink.success({'type': 'unknown'});
          },
        ),
      );
      final backend = ChannelLocalTerminalBackend(events: events);
      final received = await backend.events.take(2).toList();
      expect(received.first, isA<LocalTerminalOutput>());
      expect((received.first as LocalTerminalOutput).data, [104, 105]);
      expect(received.last, isA<LocalTerminalExit>());
      expect((received.last as LocalTerminalExit).code, 0);
    });
  });
}
