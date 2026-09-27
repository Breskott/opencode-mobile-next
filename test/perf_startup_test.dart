import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/diagnostics/app_diagnostics.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/state/connection.dart';

/// Counts actual paint completion, rather than treating pump() as a device
/// first-frame timestamp. The stalled fake keeps platform/storage out of it.
class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, required super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) => _Probe(onPaint);
}

class _Probe extends RenderProxyBox {
  _Probe(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}

void main() {
  testWidgets('startup first paint precedes bootstrap storage work', (
    tester,
  ) async {
    final diagnostics = AppDiagnosticsController();
    addTearDown(diagnostics.dispose);
    final pending = Completer<AppBootstrap>();
    var paints = 0;
    var loaderCalls = 0;
    int? paintsAtLoad;
    SchedulerPhase? phaseAtLoad;

    await tester.pumpWidget(
      _PaintProbe(
        onPaint: () => paints++,
        child: AppBootstrapGate(
          diagnostics: diagnostics,
          loader: () {
            loaderCalls++;
            paintsAtLoad = paints;
            phaseAtLoad = SchedulerBinding.instance.schedulerPhase;
            return pending.future;
          },
        ),
      ),
    );

    // This is deterministic work placement, not a benchmark of release-mode
    // GPU timing or a network connection. Keep both numbers in the QA report.
    debugPrint(
      'PERF_STARTUP loader_calls=$loaderCalls '
      'paints_before_loader=$paintsAtLoad phase=$phaseAtLoad',
    );
    expect(loaderCalls, 1);
    expect(paintsAtLoad, greaterThanOrEqualTo(1));
    expect(phaseAtLoad, SchedulerPhase.postFrameCallbacks);
    expect(find.byKey(const ValueKey('app-bootstrap-opening')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
