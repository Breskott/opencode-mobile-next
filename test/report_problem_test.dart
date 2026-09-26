import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';
import 'package:opencode_mobile/diagnostics/report_problem.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/platform/thermal.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

void main() {
  late Directory directory;
  final opened = <ReportProblem>[];
  final at = DateTime.utc(2026, 9, 27, 12);

  Future<ReportProblem> open({
    int maxEntries = 128,
    int maxBytes = 262144,
  }) async {
    final service = await ReportProblem.open(
      directory: directory,
      maxEntries: maxEntries,
      maxBytes: maxBytes,
    );
    opened.add(service);
    return service;
  }

  File snapshot() => File('${directory.path}/report_problem.json');
  File pending() => File('${directory.path}/report_problem.pending');

  setUp(() {
    KitRedact.clearKnownSecrets();
    directory = Directory.systemTemp.createTempSync('report-problem-test-');
  });

  tearDown(() {
    for (final service in opened) {
      service.dispose();
    }
    opened.clear();
    KitRedact.clearKnownSecrets();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('all event kinds survive restart without a dispose or flush', () async {
    final service = await open();
    service.recordError(
      'failed request',
      StackTrace.fromString('test frame'),
      source: 'gateway',
      at: at,
    );
    service.recordTiming(
      PerfSpan(
        id: 1,
        name: 'request',
        startMicros: 100,
        durationMicros: 12500,
        wallStart: at.add(const Duration(seconds: 1)),
      ),
    );
    service.recordAndroidExit(
      AppExitRecord(
        reason: AndroidExitReason.crash,
        timestamp: at.add(const Duration(seconds: 2)),
        description: 'native process crash',
      ),
    );
    service.recordThermal(
      const ThermalReading(status: ThermalStatus.severe, headroom: 0.9),
      at: at.add(const Duration(seconds: 3)),
    );

    expect(snapshot().existsSync(), isTrue);
    expect(pending().existsSync(), isFalse);
    final restarted = await open();
    expect(restarted.entries.map((event) => event.kind), [
      ProblemEventKind.error,
      ProblemEventKind.timing,
      ProblemEventKind.androidExit,
      ProblemEventKind.thermal,
    ]);
    expect(
      restarted.entries.map((event) => event.toJson()),
      service.entries.map((event) => event.toJson()),
    );
    expect(restarted.entries.first.timestamp, at);
    expect(restarted.entries.first.source, 'gateway');
    expect(restarted.entries.first.stack, contains('test frame'));
    expect(restarted.entries[1].message, contains('OCTRACE'));
    expect(restarted.entries[1].message, contains('13ms'));
    expect(restarted.entries[2].message, contains('crash'));
    expect(restarted.entries[3].message, contains('severe'));
    expect(restarted.storageFailed, isFalse);
  });

  test(
    'redacts at write time across diagnostics reports notifications and logs',
    () async {
      const known = 'fakeLoadedCredentialForReportTests';
      const provider = 'sk-proj-fakeReportProviderKey987654321';
      const bearer = 'fakeBearerValueForReportTests';
      const password = 'fakePasswordForReportTests';
      const text = '$known $provider\nBearer $bearer\npassword=$password';
      KitRedact.registerKnownSecret(known);
      final service = await open();
      service.recordError(
        text,
        StackTrace.fromString(text),
        source: text,
        at: at,
      );
      service.recordTiming(
        PerfSpan(
          id: 1,
          name: known,
          parent: provider,
          startMicros: 0,
          durationMicros: 1000,
          wallStart: at,
          attrs: const {'password': password, 'detail': known},
        ),
      );
      service.recordAndroidExit(
        AppExitRecord(
          reason: AndroidExitReason.crash,
          timestamp: at,
          description: text,
        ),
      );
      final outputs = [
        jsonEncode(service.entries.map((event) => event.toJson()).toList()),
        service.reportText(),
        jsonEncode(service.reportJson()),
        ReportProblem.notificationText(text),
        ReportProblem.logText(text),
        snapshot().readAsStringSync(),
      ];
      for (final output in outputs) {
        for (final secret in [known, provider, bearer, password]) {
          expect(
            output.contains(secret),
            isFalse,
            reason: 'Every output must redact fake credentials.',
          );
        }
        expect(output, contains(KitRedact.mask));
      }

      // Exact registrations are process-local. A fresh process must need none
      // to keep the already persisted data safe.
      KitRedact.clearKnownSecrets();
      final restarted = await open();
      expect(restarted.entries, hasLength(3));
      expect(restarted.reportText().contains(known), isFalse);
      expect(snapshot().readAsStringSync().contains(known), isFalse);
    },
  );

  test('redacts a complete secret before applying field caps', () async {
    const secret = 'fakeSecretCrossingTheTruncationBoundary';
    KitRedact.registerKnownSecret(secret);
    final service = await open();
    service.recordError(
      '${'x' * 2042} $secret',
      StackTrace.fromString('${'y' * 8186} $secret'),
      source: '${'z' * 122} $secret',
    );
    final event = service.entries.single;
    expect(event.source.length, lessThanOrEqualTo(128));
    expect(event.message.length, lessThanOrEqualTo(2048));
    expect(event.stack.length, lessThanOrEqualTo(8192));
    expect(snapshot().readAsStringSync().contains('fakeS'), isFalse);
  });

  test(
    'evicts oldest entries while keeping the newest within the count limit',
    () async {
      final service = await open(maxEntries: 3);
      for (var i = 0; i < 8; i++) {
        service.recordError(
          'failure $i',
          null,
          at: at.add(Duration(seconds: i)),
        );
      }
      expect(service.entries.map((event) => event.message), [
        'failure 5',
        'failure 6',
        'failure 7',
      ]);
      final restarted = await open(maxEntries: 3);
      expect(restarted.entries.map((event) => event.message), [
        'failure 5',
        'failure 6',
        'failure 7',
      ]);
    },
  );

  test('bounds actual UTF-8 bytes including multibyte content', () async {
    final service = await open(maxBytes: 1024);
    for (var i = 0; i < 12; i++) {
      service.recordError('$i ${'🔥' * 70}', null, at: at);
      expect(snapshot().lengthSync(), lessThanOrEqualTo(1024));
    }
    expect(service.entries, isNotEmpty);
    expect(service.entries.length, lessThan(12));
    expect(service.entries.last.message, startsWith('11 '));
    final restarted = await open(maxBytes: 1024);
    expect(
      restarted.entries.map((event) => event.toJson()),
      service.entries.map((event) => event.toJson()),
    );
  });

  test(
    'drops an event that cannot fit by itself without exceeding byte limit',
    () async {
      final service = await open(maxBytes: 1024);
      service.recordError('small', null);
      service.recordError('🔥' * 1000, StackTrace.fromString('frame' * 3000));
      expect(snapshot().lengthSync(), lessThanOrEqualTo(1024));
      expect(service.entries, isEmpty);
      expect((await open(maxBytes: 1024)).entries, isEmpty);
    },
  );

  test(
    'clear erases memory committed snapshot and pending write across restart',
    () async {
      final service = await open();
      service.recordError('old failure', null);
      pending().writeAsStringSync(snapshot().readAsStringSync(), flush: true);
      service.clear();
      expect(service.entries, isEmpty);
      expect(service.storageFailed, isFalse);
      expect(snapshot().existsSync(), isFalse);
      expect(pending().existsSync(), isFalse);
      expect((await open()).entries, isEmpty);
    },
  );

  test(
    'notifies consumers of committed changes and exposes immutable entries',
    () async {
      final service = await open();
      var notifications = 0;
      service.addListener(() => notifications++);
      service.recordError('first failure', null);
      expect(notifications, 1);
      final entries = service.entries;
      expect(() => entries.clear(), throwsUnsupportedError);
      expect(service.entries.single.message, 'first failure');
      service.clear();
      expect(notifications, 2);
      expect(service.entries, isEmpty);
    },
  );

  for (final malformed in [
    '{',
    '[]',
    '{"version":-1,"entries":[]}',
    '{"version":1,"entries":"invalid"}',
  ]) {
    test('discards corrupt or incompatible snapshot: $malformed', () async {
      snapshot().writeAsStringSync(malformed, flush: true);
      final service = await open();
      expect(service.entries, isEmpty);
      service.recordError('recovered', null);
      expect((await open()).entries.single.message, 'recovered');
    });
  }

  test('rejects an invalid persisted event kind', () async {
    final service = await open();
    service.recordError('failure', null);
    final raw = snapshot().readAsStringSync();
    expect(raw, contains('"kind":"error"'));
    snapshot().writeAsStringSync(
      raw.replaceFirst('"kind":"error"', '"kind":"not-a-kind"'),
      flush: true,
    );
    expect((await open()).entries, isEmpty);
  });

  test(
    'discards oversized snapshots before recovery and accepts new events',
    () async {
      snapshot().writeAsStringSync(' ' * 2048, flush: true);
      final service = await open(maxBytes: 1024);
      expect(service.entries, isEmpty);
      service.recordError('fresh', null);
      expect(snapshot().lengthSync(), lessThanOrEqualTo(1024));
      expect((await open(maxBytes: 1024)).entries.single.message, 'fresh');
    },
  );

  test(
    're-redacts recovered events using currently registered secrets',
    () async {
      const secret = 'fakePreviouslyUnknownCredential';
      final service = await open();
      service.recordError(
        secret,
        StackTrace.fromString(secret),
        source: secret,
      );
      KitRedact.registerKnownSecret(secret);
      final restarted = await open();
      expect(restarted.entries, hasLength(1));
      expect(restarted.reportText().contains(secret), isFalse);
      expect(snapshot().readAsStringSync().contains(secret), isFalse);
    },
  );

  test(
    'ignores and removes pending writes in favour of committed snapshot',
    () async {
      final service = await open();
      service.recordError('committed', null);
      final committed = snapshot().readAsStringSync();
      service.recordError('uncommitted', null);
      pending().writeAsStringSync(snapshot().readAsStringSync(), flush: true);
      snapshot().writeAsStringSync(committed, flush: true);
      final restarted = await open();
      expect(restarted.entries.single.message, 'committed');
      expect(pending().existsSync(), isFalse);
    },
  );

  test('does not resurrect an orphan pending snapshot', () async {
    final service = await open();
    service.recordError('uncommitted', null);
    snapshot().renameSync(pending().path);
    expect((await open()).entries, isEmpty);
    expect(pending().existsSync(), isFalse);
  });

  test(
    'failed write is reported without publishing the uncommitted event',
    () async {
      final service = await open();
      service.recordError('committed', null);
      final before = snapshot().readAsStringSync();
      // A nonempty directory at the staging-file path gives deterministic
      // write failure even when the test process can bypass file permissions.
      Directory(pending().path).createSync();
      File('${pending().path}/blocker').writeAsStringSync('not a diagnostic');
      Object? failure;
      try {
        service.recordError('fakeFailedWritePayload', null);
      } catch (error) {
        failure = error;
      }
      expect(failure, isA<StateError>());
      expect(failure.toString().contains('fakeFailedWritePayload'), isFalse);
      expect(failure.toString().contains(directory.path), isFalse);
      expect(service.storageFailed, isTrue);
      expect(service.entries.single.message, 'committed');
      expect(snapshot().readAsStringSync(), before);

      Directory(pending().path).deleteSync(recursive: true);
      service.recordError('retry succeeded', null);
      expect(service.storageFailed, isFalse);
      expect((await open()).entries.last.message, 'retry succeeded');
    },
  );

  test(
    'failed deletion reports failure rather than claiming successful clear',
    () async {
      final service = await open();
      service.recordError('retained until deleted', null);
      snapshot().deleteSync();
      Directory(snapshot().path).createSync();
      File('${snapshot().path}/blocker').writeAsStringSync('protected content');
      expect(service.clear, throwsStateError);
      expect(service.storageFailed, isTrue);
      expect(service.entries, isNotEmpty);
      expect(File('${snapshot().path}/blocker').existsSync(), isTrue);
      Directory(snapshot().path).deleteSync(recursive: true);
      service.clear();
      expect(service.storageFailed, isFalse);
      expect(service.entries, isEmpty);
    },
  );

  test('rejects invalid entry and byte limits', () async {
    await expectLater(
      ReportProblem.open(directory: directory, maxEntries: 0),
      throwsArgumentError,
    );
    await expectLater(
      ReportProblem.open(directory: directory, maxBytes: 1023),
      throwsArgumentError,
    );
  });
}
