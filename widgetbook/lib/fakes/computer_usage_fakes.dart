// Copied from test/support/computer_usage_fakes.dart (the app never imports
// test/ from lib/): a terminal that prints the usage reader's answer lines.
import 'dart:async';
import 'dart:convert';

import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/computer_usage_source.dart';

final computerNow = DateTime.utc(2026, 10, 13, 12);
final computerRef = 'a' * 64;
final computerRef2 = 'b' * 64;

Map<String, Object?> computerWindow(
  String id,
  double used, {
  int seconds = 18000,
  int hours = 2,
}) => {
  'id': id,
  'status': 'reported',
  'usedPercent': used,
  'durationSeconds': seconds,
  'resetsAtMs': computerNow.add(Duration(hours: hours)).millisecondsSinceEpoch,
};

Map<String, Object?> computerSnapshot(
  String provider, {
  String status = 'ok',
  String? ref,
  String accountStatus = 'matched',
  List<Map<String, Object?>>? windows,
  String? plan,
}) {
  final ok = status == 'ok';
  return {
    'schemaVersion': 1,
    'provider': provider,
    'source': switch (provider) {
      'codex' => 'codex.wham',
      'glm' => 'glm.codingPlan',
      _ => 'minimax.tokenPlan',
    },
    'status': status,
    'freshness': ok ? 'fresh' : 'none',
    'fetchedAtMs': computerNow.millisecondsSinceEpoch,
    'expiresAtMs': computerNow.millisecondsSinceEpoch + (ok ? 60000 : 0),
    'account': {
      'ref': ?ref,
      'status': ok ? accountStatus : 'unverified',
      'plan': ?plan,
    },
    'ordinaryUsageAllowed': null,
    'windows': ok ? (windows ?? [computerWindow('primary', 30)]) : <Object?>[],
  };
}

String computerLine(Map<String, Object?> json) =>
    'OCMN_USAGE_V1 ${base64.encode(utf8.encode(jsonEncode(json)))}';

Map<String, Object?> computerAnswer({
  Map<String, Map<String, Object?>> providers = const {},
  Map<String, String?> auth = const {},
  String? error,
}) => {
  'v': 1,
  'error': ?error,
  'providers': providers,
  'auth': {'codex': null, 'glm': null, 'minimax': null, ...auth},
};

final computerCodexOk = computerAnswer(
  providers: {
    'codex': computerSnapshot('codex', ref: computerRef, plan: 'plus'),
  },
  auth: {'codex': 'oauth'},
);

class FakeTerminalChannel extends TerminalChannel {
  FakeTerminalChannel(this.script, {this.closeHangs = false});
  final List<String> script;

  /// A socket that never finishes closing.
  final bool closeHangs;
  final _controller = StreamController<String>();
  int closed = 0;

  @override
  Stream<String> get output => _controller.stream;
  @override
  void write(String value) {}
  @override
  Future<void> close() async {
    closed++;
    if (closeHangs) return Completer<void>().future;
    if (!_controller.isClosed) unawaited(_controller.close());
  }

  Future<void> play({bool end = true}) async {
    for (final chunk in script) {
      await Future<void>.delayed(Duration.zero);
      if (_controller.isClosed) return;
      _controller.add(chunk);
    }
    if (end && !_controller.isClosed) await _controller.close();
  }
}

/// What one start call does.
class FakeStep {
  const FakeStep({
    this.output = const [],
    this.startError,
    this.connectError = false,
    this.hang = false,
    this.closeHangs = false,
  });
  final List<String> output;
  final ComputerUsageProblem? startError;
  final bool connectError;

  /// Never ends and never prints (a reader that does not answer).
  final bool hang;

  /// Closing its socket never finishes.
  final bool closeHangs;
}

class FakeComputerPort implements ComputerTerminalPort {
  FakeComputerPort(this.steps);
  final List<FakeStep> steps;
  final started = <(String, List<String>, String)>[];
  final removed = <String>[];
  bool removeThrows = false;
  int closed = 0;
  var _next = 0;
  final _channels = <String, FakeTerminalChannel>{};
  final _plans = <String, FakeStep>{};

  @override
  Future<TerminalProcess> start(
    String command,
    List<String> arguments, {
    required String title,
  }) async {
    started.add((command, arguments, title));
    final step = steps[_next < steps.length ? _next : steps.length - 1];
    _next++;
    if (step.startError != null) throw ComputerUsageException(step.startError!);
    final id = 'pty_$_next';
    _plans[id] = step;
    return TerminalProcess(
      id: id,
      title: title,
      command: command,
      arguments: arguments,
      directory: '/',
      running: true,
      pid: 1,
    );
  }

  @override
  Future<TerminalChannel> connect(String id) async {
    final step = _plans[id]!;
    if (step.connectError) throw StateError('gone');
    final channel = FakeTerminalChannel(
      step.output,
      closeHangs: step.closeHangs,
    );
    _channels[id] = channel;
    if (!step.hang) unawaited(channel.play());
    return channel;
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    if (removeThrows) throw StateError('server went away');
  }

  @override
  void close() => closed++;
}
