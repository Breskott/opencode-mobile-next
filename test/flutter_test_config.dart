import 'dart:async';

import 'package:opencode_mobile/diagnostics/perf_trace.dart';

/// Runs before every test file. The performance tracer writes one device-log
/// line per span in the app; in the suite those lines would only bury real
/// failures, so the buffer stays on and the log goes quiet.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PerfTrace.logSink = null;
  await testMain();
}
