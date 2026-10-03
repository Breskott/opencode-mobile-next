// The v2 job on the Termux host (P1.2) with the native side stood in for on
// the `oc/termux` channel: an install an older build made in Termux passes
// every check and only the start runs, and the app-side voice component is
// installed by the app and acknowledged to the Termux job like on the
// in-app host.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/components.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/termux');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Termux native;
  final engines = <ChannelSetupEngine>[];

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    native = _Termux();
    messenger.setMockMethodCallHandler(channel, native.handle);
  });

  tearDown(() {
    for (final engine in engines) {
      engine.dispose();
    }
    engines.clear();
    messenger.setMockMethodCallHandler(channel, null);
    debugPlatformCapabilities = null;
  });

  ChannelSetupEngine termux({
    required SetupFinisher finisher,
    SetupAppComponent? voice,
  }) {
    final engine = ChannelSetupEngine.termux(
      strings: () => _l10n,
      finisher: finisher,
      pollInterval: const Duration(milliseconds: 5),
      components: voice == null
          ? null
          : (l10n, params) => [
              for (final component in setupComponents(
                l10n,
                params: params,
                host: SetupHostKind.termux,
              ))
                if (component.id != SetupComponentIds.voice) component,
              SetupComponent(
                id: SetupComponentIds.voice,
                title: 'Voice typing',
                shortTitle: 'Voice typing',
                checkScript: '',
                installScript: '',
                app: voice,
              ),
            ],
    );
    engines.add(engine);
    return engine;
  }

  test('the Termux host accepts the Node an older build installed from '
      "Ubuntu's packages; the in-app host keeps the pinned one", () {
    String nodeCheck(SetupHostKind host) => setupComponents(
      _l10n,
      host: host,
    ).singleWhere((c) => c.id == SetupComponentIds.node).checkScript;
    expect(nodeCheck(SetupHostKind.termux), SetupScripts.termuxNodeCheck);
    expect(nodeCheck(SetupHostKind.termux), isNot(contains('/usr/local')));
    expect(nodeCheck(SetupHostKind.builtin), SetupScripts.nodeCheck);
    expect(
      ChannelSetupEngine.termux(
        finisher: (_) async => null,
        strings: () => _l10n,
      ).registry.singleWhere((c) => c.id == SetupComponentIds.node).checkScript,
      SetupScripts.termuxNodeCheck,
    );
  });

  test('an existing Termux install is recognised as done: every component '
      'is skipped and only the start runs, then connects', () async {
    final requests = <SetupFinishRequest>[];
    final engine = termux(
      finisher: (request) async {
        requests.add(request);
        return null;
      },
    );
    await engine.run(
      const {},
      params: {
        ...SetupJobParams.firstSetup,
        'opencode': {'runtime': 'opencode1'},
      },
    );
    final specs = (native.starts.single['components'] as List)
        .cast<Map<Object?, Object?>>();
    for (final spec in specs.where((s) => s['id'] != 'start')) {
      expect(spec['skipped'], isTrue, reason: '${spec['id']} was redone');
    }
    // The Termux node check is what ran, inside Termux's Ubuntu.
    expect(native.checks.single, contains(SetupScripts.termuxNodeCheck.trim()));

    await _until(() => engine.progress.value.state == SetupState.done);
    expect(requests.single.host, SetupHostKind.termux);
    expect(requests.single.openCodeChanged, isFalse);
    expect(native.completed.single['id'], 'start');
  });

  test('voice typing is installed by the app and reported to the Termux '
      'job, after the start', () async {
    final voice = _Voice();
    final engine = termux(finisher: (_) async => null, voice: voice);
    await engine.run(
      {SetupComponentIds.voice},
      params: {
        'opencode': {'runtime': 'opencode1'},
      },
    );
    final ids = [
      for (final spec in (native.starts.single['components'] as List))
        (spec as Map)['id'],
    ];
    expect(ids.last, SetupComponentIds.voice);
    final step = (native.starts.single['components'] as List).last as Map;
    expect(step['step'], isTrue);

    await _until(() => engine.progress.value.state == SetupState.done);
    expect(voice.installs, 1);
    expect(native.completed.map((c) => c['id']), [
      SetupComponentIds.start,
      SetupComponentIds.voice,
    ]);
    expect(native.completed.last['ok'], isTrue);
  });
}

class _Voice implements SetupAppComponent {
  var installs = 0;

  @override
  Future<({bool ok, String? version})> check() async =>
      (ok: false, version: null);

  @override
  Future<String?> install({
    required void Function(SetupAppProgress progress) onProgress,
  }) async {
    installs++;
    return 'base';
  }

  @override
  void cancel() {}

  @override
  Future<SetupAppOffer?> offer() async => null;

  @override
  Future<void> remove() async {}
}

/// Termux with an older build's install in it: every check passes. The job
/// walks its steps as the native shell would, waiting on each app step's
/// acknowledgement.
class _Termux {
  Map<String, Object?>? job;
  final starts = <Map<Object?, Object?>>[];
  final checks = <String>[];
  final completed = <Map<Object?, Object?>>[];

  Map<String, Object?> get _components =>
      job!['components']! as Map<String, Object?>;

  /// Moves the job to its next step that is not finished, as the shell does.
  void _advance() {
    for (final id in (job!['order']! as List).cast<String>()) {
      final component = _components[id]! as Map<String, Object?>;
      final state = component['state'];
      if (state == 'skipped' || state == 'done') continue;
      if (state == 'failed') {
        job!['state'] = 'failed';
        return;
      }
      component['state'] = 'running';
      job!['current'] = id;
      return;
    }
    job!['state'] = 'done';
    job!.remove('current');
  }

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
          output
            ..writeln('::oc-check-begin $id')
            ..writeln(id == 'opencode' ? '1.18.32' : '1.0')
            ..writeln('::oc-check-end $id 0');
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
          'components': <String, Object?>{
            for (final c in specs)
              c['id'] as String: <String, Object?>{
                'state': c['skipped'] == true ? 'skipped' : 'pending',
                if (c['data'] != null) 'data': c['data'],
              },
          },
          'params': args['params'],
        };
        _advance();
        return null;
      case 'completeSetupStep':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        completed.add(args);
        final component =
            _components[args['id'] as String]! as Map<String, Object?>;
        component['state'] = args['ok'] == true ? 'done' : 'failed';
        _advance();
        return null;
      default:
        throw PlatformException(code: 'unexpected', message: call.method);
    }
  }
}

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 400 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ready(), isTrue, reason: 'Setup state did not arrive.');
}
