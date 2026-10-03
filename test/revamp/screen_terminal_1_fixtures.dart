// Fakes shared by screen-terminal-1's behaviour tests and goldens: a server
// with terminals (list, create, rename, remove, connect), shell settings,
// a server with no terminals, and a controller wired to them.
import 'dart:async';

import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runningShell = TerminalProcess(
  id: 'pty-1',
  title: 'build-server',
  command: '/bin/bash',
  arguments: [],
  directory: '/srv/shopfront',
  running: true,
  pid: 4821,
);

const endedTests = TerminalProcess(
  id: 'pty-2',
  title: 'tests',
  command: 'flutter',
  arguments: ['test'],
  directory: '/srv/shopfront',
  running: false,
  pid: 4790,
  exitCode: 1,
);

const endedLint = TerminalProcess(
  id: 'pty-3',
  title: 'lint',
  command: 'dart',
  arguments: ['analyze'],
  directory: '/srv/shopfront',
  running: false,
  pid: 4702,
  exitCode: 0,
);

class MemoryTerminalChannel implements TerminalChannel {
  final outputController = StreamController<String>();
  final writes = <String>[];

  @override
  Stream<String> get output => outputController.stream;

  @override
  int? get cursor => null;

  @override
  void write(String value) => writes.add(value);

  @override
  Future<void> close() async {
    if (!outputController.isClosed) await outputController.close();
  }
}

class TerminalServer implements ProductRepository {
  TerminalServer({List<TerminalProcess>? processes, this.shells})
    : processes = processes ?? [endedTests, runningShell, endedLint];

  List<TerminalProcess> processes;
  TerminalShellSettings? shells;
  final removed = <String>[];
  final renamed = <String, String>{};
  final channels = <MemoryTerminalChannel>[];
  final selectedShells = <String>[];

  /// Set to make the next remove, rename or shell change fail.
  Object? failure;

  /// Written into each new channel once it is connected.
  String greeting = '';

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<TerminalProcess>> listTerminals() async => [...processes];

  @override
  Future<void> removeTerminal(String id) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    removed.add(id);
    processes = [
      for (final process in processes)
        if (process.id != id) process,
    ];
  }

  @override
  Future<void> renameTerminal(String id, String title) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    renamed[id] = title;
  }

  @override
  Future<TerminalProcess> createTerminal({String? title}) async {
    final process = TerminalProcess(
      id: 'pty-${processes.length + 10}',
      title: title ?? 'Terminal',
      command: '/bin/bash',
      arguments: const [],
      directory: '/srv/shopfront',
      running: true,
      pid: 5000,
    );
    processes = [...processes, process];
    return process;
  }

  @override
  Future<TerminalChannel> connectTerminal(String id, {int? cursor}) async {
    final channel = MemoryTerminalChannel();
    channels.add(channel);
    if (greeting.isNotEmpty) channel.outputController.add(greeting);
    return channel;
  }

  @override
  Future<void> resizeTerminal(
    String id, {
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<TerminalShellSettings> loadTerminalShellSettings() async =>
      shells ?? const TerminalShellSettings(selected: '', options: []);

  @override
  Future<void> selectTerminalShell(String value) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    selectedShells.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A server whose gateway keeps no terminals (Codex, Paseo).
class NoTerminalApi implements ServerGateway {
  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(terminal: false, fileBrowsing: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> terminalController(
  TerminalServer server, {
  bool terminals = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final controller =
      ConnectionController(
          ProfileStore(prefs: await SharedPreferences.getInstance()),
        )
        ..repository = server
        ..status = StreamStatus.connected;
  if (!terminals) controller.api = NoTerminalApi();
  return controller;
}

/// Undoes [terminalController]'s fake gateway before disposing.
void disposeTerminalController(ConnectionController controller) {
  controller.api = null;
  controller.dispose();
}
