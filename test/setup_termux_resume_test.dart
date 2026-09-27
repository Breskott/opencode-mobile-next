import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/termux/bridge.dart' show TermuxRuntime;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/termux');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _TermuxSetupChannel native;
  final engines = <ChannelSetupEngine>[];

  ChannelSetupEngine engine({SetupFinisher? finisher}) {
    final value = ChannelSetupEngine.termux(
      strings: () => lookupAppLocalizations(const Locale('en')),
      finisher: finisher ?? (_) async => null,
      pollInterval: const Duration(milliseconds: 5),
    );
    engines.add(value);
    return value;
  }

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    native = _TermuxSetupChannel();
    messenger.setMockMethodCallHandler(channel, native.handle);
  });

  tearDown(() {
    for (final value in engines) {
      value.dispose();
    }
    engines.clear();
    messenger.setMockMethodCallHandler(channel, null);
    debugPlatformCapabilities = null;
  });

  test(
    'a fresh engine restores the live Termux job without restarting it',
    () async {
      native.job = _record(state: 'running', current: 'node');
      final restored = engine();
      await restored.restore();
      await restored.resume();

      expect(restored.progress.value.jobId, 'durable-termux-job');
      expect(restored.host, SetupHostKind.termux);
      expect(restored.progress.value.state, SetupState.running);
      expect(restored.progress.value.firstSetup, isTrue);
      expect(restored.progress.value.current, 'node');
      expect(
        restored.progress.value.components
            .singleWhere((c) => c.id == 'node')
            .bytesDone,
        5,
      );
      expect(native.starts, isEmpty);
      expect(native.checks, isEmpty);
    },
  );

  test(
    'resume retains selected tools and runtime and skips healthy components',
    () async {
      native.job = _record(state: 'interrupted', current: 'node');
      final restored = engine();
      await restored.restore();
      expect(restored.progress.value.canContinue, isTrue);
      await restored.resume();

      final sent = native.starts.single;
      final specs = (sent['components'] as List).cast<Map<Object?, Object?>>();
      expect(specs.map((c) => c['id']), [
        'linux',
        'essentials',
        'python',
        'node',
        'opencode',
        'start',
      ]);
      for (final id in ['linux', 'essentials', 'python']) {
        expect(specs.singleWhere((c) => c['id'] == id)['skipped'], isTrue);
      }
      expect(specs.singleWhere((c) => c['id'] == 'node')['script'], isNotEmpty);
      expect(sent['params'], {
        'opencode': {'runtime': 'opencode2'},
        ...SetupJobParams.firstSetup,
      });
      expect(native.checks.single, contains('opencode2 --version'));
      expect(restored.progress.value.firstSetup, isTrue);
    },
  );

  test('restored start stays running until connection succeeds', () async {
    native.job = _record(state: 'running', current: 'start');
    final connected = Completer<String?>();
    final requests = <SetupFinishRequest>[];
    final restored = engine(
      finisher: (request) {
        requests.add(request);
        return connected.future;
      },
    );
    await restored.restore();
    await _until(() => requests.isNotEmpty);

    expect(requests.single.runtime, TermuxRuntime.openCode2);
    expect(requests.single.host, SetupHostKind.termux);
    expect(restored.progress.value.state, SetupState.running);
    expect(native.completed, isEmpty);
    connected.complete(null);
    await _until(() => restored.progress.value.state == SetupState.done);

    expect(requests, hasLength(1));
    expect(native.completed.single['ok'], isTrue);
    expect(native.completed.single['jobId'], 'durable-termux-job');
    expect(native.completed.single['id'], 'start');
  });

  test('a failed connection leaves a resumable failed Termux job', () async {
    native.job = _record(state: 'running', current: 'start');
    final restored = engine(finisher: (_) async => 'Server did not answer.');
    await restored.restore();
    await _until(() => restored.progress.value.state == SetupState.failed);

    expect(native.completed.single['ok'], isFalse);
    expect(restored.progress.value.canContinue, isTrue);
    expect(restored.progress.value.error, isNotEmpty);
  });

  test(
    'cancel records stopped progress without completing the start step',
    () async {
      native.job = _record(state: 'running', current: 'node');
      final restored = engine();
      await restored.restore();
      await restored.cancel();

      expect(native.cancels, 1);
      expect(restored.progress.value.state, SetupState.cancelled);
      expect(restored.progress.value.canContinue, isTrue);
      expect(native.completed, isEmpty);
      expect(
        restored.progress.value.components
            .singleWhere((c) => c.id == 'python')
            .state,
        ComponentState.done,
      );
    },
  );
}

Map<String, Object?> _record({
  required String state,
  required String current,
}) => {
  'host': 'termux',
  'jobId': 'durable-termux-job',
  'state': state,
  'current': current,
  'order': ['linux', 'essentials', 'python', 'node', 'opencode', 'start'],
  'components': {
    for (final id in ['linux', 'essentials', 'python']) id: {'state': 'done'},
    'node': {
      'state': current == 'node' ? 'running' : 'done',
      'done': 5,
      'total': 10,
    },
    'opencode': {'state': current == 'start' ? 'done' : 'pending'},
    'start': {
      'state': current == 'start' ? 'running' : 'pending',
      'data': {'runtime': 'opencode2', 'openCodeChanged': 'true'},
    },
  },
  'params': {
    'opencode': {'runtime': 'opencode2'},
    ...SetupJobParams.firstSetup,
  },
};

/// Persists only the native job record between engine instances. Command
/// replies are generated from checks, independently of the old job states.
class _TermuxSetupChannel {
  Map<String, Object?>? job;
  final starts = <Map<Object?, Object?>>[];
  final checks = <String>[];
  final completed = <Map<Object?, Object?>>[];
  var cancels = 0;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'setupStatus':
        return job == null ? null : jsonEncode(job);
      case 'setupHostInstalled':
        return true;
      case 'setupRun':
        final script = (call.arguments as Map)['script'] as String;
        checks.add(script);
        final output = StringBuffer();
        for (final match in RegExp(
          r"::oc-check-begin %s\\n' '([a-z0-9]+)'",
        ).allMatches(script)) {
          final id = match.group(1)!;
          final healthy = ['linux', 'essentials', 'python'].contains(id);
          output
            ..writeln('::oc-check-begin $id')
            ..writeln(healthy ? '1.0' : 'not installed')
            ..writeln('::oc-check-end $id ${healthy ? 0 : 1}');
        }
        return {'exitCode': 0, 'stdout': output.toString(), 'err': -1};
      case 'startSetup':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        starts.add(args);
        final specs = (args['components'] as List)
            .cast<Map<Object?, Object?>>();
        job = {
          'host': 'termux',
          'jobId': args['jobId'],
          'state': 'running',
          'order': [for (final c in specs) c['id']],
          'components': {
            for (final c in specs)
              c['id'] as String: {
                'state': c['skipped'] == true ? 'skipped' : 'pending',
                'version': c['version'],
                if (c['data'] != null) 'data': c['data'],
              },
          },
          'params': args['params'],
        };
        return null;
      case 'completeSetupStep':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        completed.add(args);
        final state = args['ok'] == true ? 'done' : 'failed';
        final error = args['ok'] == true
            ? null
            : 'Could not connect to OpenCode.';
        job!['state'] = state;
        job!['error'] = error;
        final step = (job!['components'] as Map)['start'] as Map;
        step['state'] = state;
        step['error'] = error;
        return null;
      case 'cancelSetup':
        cancels++;
        job!['state'] = 'cancelled';
        return null;
      default:
        throw PlatformException(
          code: 'unexpected_method',
          message: call.method,
        );
    }
  }
}

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 400 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ready(), isTrue, reason: 'Setup state did not arrive.');
}
