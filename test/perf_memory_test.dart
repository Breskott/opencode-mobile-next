import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/diagnostics/app_diagnostics.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';
import 'package:opencode_mobile/diagnostics/report_problem.dart';
import 'package:opencode_mobile/diagnostics/report_problem_capture.dart';
import 'package:opencode_mobile/ui/kit/kit_log_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('historical timings attach with one durable publication', (
    tester,
  ) async {
    PerfTrace.resetForTesting();
    PerfTrace.logSink = null;
    final directory = Directory.systemTemp.createTempSync('perf-report-');
    final report = await ReportProblem.open(directory: directory);
    final diagnostics = AppDiagnosticsController();
    ReportProblemCapture? capture;
    addTearDown(() async {
      await capture?.close();
      report.dispose();
      diagnostics.dispose();
      directory.deleteSync(recursive: true);
      PerfTrace.resetForTesting();
    });
    for (var i = 0; i < 128; i++) {
      PerfTrace.mark('synthetic.history.$i');
    }
    var notifications = 0;
    var builds = 0;
    report.addListener(() => notifications++);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListenableBuilder(
          listenable: report,
          builder: (context, child) {
            builds++;
            return Text('${report.entries.length}');
          },
        ),
      ),
    );
    final watch = Stopwatch()..start();
    capture = ReportProblemCapture(report: report, diagnostics: diagnostics);
    watch.stop();
    await tester.pump();
    final bytes = File('${directory.path}/report_problem.json').lengthSync();
    // Synthetic metrics only; no event bodies, paths or credentials.
    debugPrint(
      'PERF_MEMORY history=128 notifications=$notifications '
      'widget_builds=$builds attach_us=${watch.elapsedMicroseconds} bytes=$bytes',
    );
    expect(report.entries.length, 128);
    expect(
      report.entries.first.message.contains('synthetic.history.0'),
      isTrue,
    );
    expect(
      report.entries.last.message.contains('synthetic.history.127'),
      isTrue,
    );
    expect(builds, 2);
    expect(notifications, 1);
  });

  for (final size in [1000, 100000]) {
    testWidgets('large log tail materializes only its retained lines $size', (
      tester,
    ) async {
      final source = List.generate(size, (i) => 'synthetic line $i').join('\n');
      final samples = <int>[];
      var created = 0;
      var retained = 0;
      var dropped = 0;
      final buffer = KitLogBuffer(capacity: 2000);
      addTearDown(buffer.dispose);
      var builds = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<List<KitLogLine>>(
            valueListenable: buffer,
            builder: (context, value, child) {
              builds++;
              return Text('${value.length}');
            },
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        final previousCount = buffer.debugCreatedLineCount;
        final watch = Stopwatch()..start();
        buffer.replaceText(source);
        watch.stop();
        if (i > 0) samples.add(watch.elapsedMicroseconds);
        created = buffer.debugCreatedLineCount - previousCount;
        retained = buffer.value.length;
        dropped = buffer.dropped;
        await tester.pump();
      }
      samples.sort();
      debugPrint(
        'PERF_MEMORY log_lines=$size created=$created retained=$retained '
        'dropped=$dropped widget_builds=$builds replace_median_us=${samples[2]}',
      );
      expect(buffer.value.last.text, 'synthetic line ${size - 1}');
      expect(retained + dropped, size);
      expect(builds, 7);
      expect(created, lessThanOrEqualTo(2000));
    });
  }

  test(
    'log chunk boundaries preserve CRLF, blank lines and eviction counts',
    () {
      final random = Random(17);
      for (final capacity in [1, 3, 64]) {
        final buffer = KitLogBuffer(capacity: capacity);
        addTearDown(buffer.dispose);
        var accumulated = '';
        for (var i = 0; i < 200; i++) {
          final chunk = List.generate(
            random.nextInt(40) + 1,
            (_) => ['a', 'b', '\r', '\n'][random.nextInt(4)],
          ).join();
          accumulated += chunk;
          buffer.appendText(chunk);
          final expected = accumulated.split('\n');
          if (expected.last.isEmpty) expected.removeLast();
          final tail = expected
              .skip(max(0, expected.length - capacity))
              .map(
                (line) => line.endsWith('\r')
                    ? line.substring(0, line.length - 1)
                    : line,
              );
          expect(buffer.value.map((line) => line.text), tail);
          expect(buffer.dropped, max(0, expected.length - capacity));
        }
        final old = buffer.value;
        final oldText = old.map((line) => line.text).toList();
        buffer.replaceText('new\r\npartial');
        expect(old.map((line) => line.text), oldText);
        expect(buffer.value.last.text, 'partial');
        buffer.add(const KitLogLine('explicit', level: KitLogLevel.error));
        expect(buffer.value.last.text, 'explicit');
        expect(buffer.value.last.level, KitLogLevel.error);
        buffer.clear();
        expect(buffer.value, isEmpty);
        expect(buffer.dropped, 0);
      }
    },
  );

  test(
    'historical batch preserves sequential eviction and durable redaction',
    () async {
      final directory = Directory.systemTemp.createTempSync('perf-batch-');
      final other = Directory('${directory.path}/other');
      final sequential = await ReportProblem.open(
        directory: directory,
        maxEntries: 9,
        maxBytes: 1024,
      );
      final batch = await ReportProblem.open(
        directory: other,
        maxEntries: 9,
        maxBytes: 1024,
      );
      addTearDown(() {
        sequential.dispose();
        batch.dispose();
        directory.deleteSync(recursive: true);
        PerfTrace.resetForTesting();
      });
      PerfTrace.resetForTesting();
      PerfTrace.logSink = null;
      for (var i = 0; i < 20; i++) {
        PerfTrace.mark(
          'fixture.$i',
          attrs: {'token': 'synthetic-value', 'detail': '字' * i},
        );
      }
      for (final span in PerfTrace.spans) {
        sequential.recordTiming(span);
      }
      var publications = 0;
      batch.addListener(() => publications++);
      batch.recordTimings(PerfTrace.spans);
      expect(batch.reportJson(), sequential.reportJson());
      expect(publications, 1);
      batch.recordTimings(const []);
      expect(publications, 1);
      final disk = File('${other.path}/report_problem.json');
      expect(disk.lengthSync(), lessThanOrEqualTo(1024));
      expect(disk.readAsStringSync().contains('synthetic-value'), isFalse);
      final restored = await ReportProblem.open(
        directory: other,
        maxEntries: 9,
        maxBytes: 1024,
      );
      addTearDown(restored.dispose);
      expect(restored.reportJson(), batch.reportJson());
      final before = batch.reportJson();
      final pending = Directory('${other.path}/report_problem.pending')
        ..createSync();
      File('${pending.path}/blocker').writeAsStringSync('fixture');
      expect(() => batch.recordTimings(PerfTrace.spans), throwsStateError);
      expect(batch.reportJson(), before);
      expect(batch.storageFailed, isTrue);
    },
  );
}
