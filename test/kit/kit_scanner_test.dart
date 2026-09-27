// Behaviour contracts for KitScanner (docs/ux-system/kit-api/KitScanner.md,
// "Tests required"), plus the pairing scanner screen that now hands its
// camera frame to the part. Arabic and RTL are out of scope (owner decision
// 2026-09-27), so tests 7 and 9 run left to right only.
import 'kit_motion_still.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/camera.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/pairing.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_scanner.dart';
import 'package:opencode_mobile/ui/screens/pairing_scanner_screen.dart';

/// A camera with no device behind it: [codes] is a synchronous stream the
/// test feeds, and the preview is a flat `surface3` box.
class FakeScannerCamera implements KitScannerCamera {
  FakeScannerCamera({this.failWith, this.hang = false});

  final KitScannerFailure? failWith;

  /// start() never completes.
  final bool hang;

  final StreamController<String> _codes = StreamController.broadcast(
    sync: true,
  );
  int starts = 0;
  int stops = 0;
  int disposes = 0;

  void emit(String raw) => _codes.add(raw);

  @override
  Future<void> start() {
    starts++;
    if (failWith case final failure?) return Future.error(failure);
    if (hang) return Completer<void>().future;
    return Future.value();
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposes++;

  @override
  Stream<String> get codes => _codes.stream;

  @override
  Widget preview(BuildContext context) =>
      ColoredBox(color: AppTheme.rolesOf(Theme.of(context)).surface3);
}

const _instruction = 'Point the camera at the code that opencode2 pair printed';
const _rejectedWords = 'That is not a pairing code.';

Widget _app(
  Widget child, {
  bool light = false,
  double textScale = 1,
  bool reduceMotion = false,
}) => RepaintBoundary(
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: light ? AppTheme.light() : AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: inner!,
    ),
    home: Scaffold(body: child),
  ),
);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

KitScanner _scanner(
  FakeScannerCamera camera, {
  bool Function(String raw)? onCode,
  ValueChanged<KitScannerFailure>? onFailed,
  String? rejected,
  List<KitAction> onSlow = const [],
}) => KitScanner(
  camera: camera,
  instruction: _instruction,
  rejected: rejected,
  onSlow: onSlow,
  onCode: onCode ?? (_) => false,
  onFailed: onFailed ?? (_) {},
  rejectedKey: const ValueKey('test-rejected'),
);

/// Every label, value and hint in the semantics tree.
List<String> _semanticsText(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    out
      ..add(node.label)
      ..add(node.value)
      ..add(node.hint);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

/// The colours painted in the window, as packed ARGB.
Future<Set<int>> _paintedColours(WidgetTester tester) async {
  final element = tester.element(find.byType(KitScanner));
  final image = await captureImage(element);
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final pixels = Uint8List.sublistView(bytes);
  final colours = <int>{};
  for (var i = 0; i < pixels.length; i += 4) {
    colours.add(
      (pixels[i + 3] << 24) |
          (pixels[i] << 16) |
          (pixels[i + 1] << 8) |
          pixels[i + 2],
    );
  }
  image.dispose();
  return colours;
}

int _argb(Color c) => c.toARGB32();

void main() {
  Widget motionScanner({String? rejected, bool loading = false}) => KitScanner(
    camera: FakeScannerCamera(hang: loading),
    instruction: _instruction,
    rejected: rejected,
    onCode: (_) => false,
    onFailed: (_) {},
  );
  kitMotionStillTests(
    'KitScanner',
    builds: {
      'starting camera': () => motionScanner(loading: true),
      'preview': () => motionScanner(),
      'rejected code': () => motionScanner(rejected: _rejectedWords),
    },
    changes: {
      'code rejected': KitMotionChange(
        build: () => motionScanner(),
        act: (tester, stage) =>
            stage.rebuild(motionScanner(rejected: _rejectedWords)),
        shows: _rejectedWords,
      ),
    },
  );

  tearDown(() {
    debugPlatformCapabilities = null;
  });

  testWidgets('1. accepts once: one onCode, and the camera stops at once', (
    tester,
  ) async {
    final camera = FakeScannerCamera();
    final seen = <String>[];
    await tester.pumpWidget(
      _app(
        _scanner(
          camera,
          onCode: (raw) {
            seen.add(raw);
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    expect(camera.starts, 1);

    // Two values in the same frame, delivered before any pump.
    camera
      ..emit('first')
      ..emit('second');
    expect(seen, ['first']);
    expect(camera.stops, 1);

    await tester.pump();
    camera.emit('third');
    expect(seen, ['first']);
  });

  testWidgets('2. rejects, keeps scanning, and announces a message once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final camera = FakeScannerCamera();
    final seen = <String>[];
    String? rejected;
    late StateSetter setHost;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            setHost = setState;
            return _scanner(
              camera,
              rejected: rejected,
              onCode: (raw) {
                seen.add(raw);
                if (raw == 'good') return true;
                setState(() => rejected = _rejectedWords);
                return false;
              },
            );
          },
        ),
      ),
    );
    await tester.pump();

    camera.emit('not a pairing code');
    await tester.pumpAndSettle();
    final notice = find.byKey(const ValueKey('test-rejected'));
    expect(notice, findsOneWidget);
    expect(find.text(_rejectedWords), findsOneWidget);
    expect(camera.stops, 0, reason: 'a refused code keeps the camera on');

    // One live region carries the words.
    final node = tester.getSemantics(find.text(_rejectedWords));
    SemanticsNode? live = node;
    while (live != null &&
        !live.getSemanticsData().flagsCollection.isLiveRegion) {
      live = live.parent;
    }
    expect(live, isNotNull, reason: 'the rejected line is a live region');
    final liveId = live!.id;

    // The same words set again: the same node, so nothing new is read out.
    setHost(() => rejected = _rejectedWords);
    await tester.pumpAndSettle();
    var again = tester.getSemantics(find.text(_rejectedWords));
    SemanticsNode? liveAgain = again;
    while (liveAgain != null &&
        !liveAgain.getSemanticsData().flagsCollection.isLiveRegion) {
      liveAgain = liveAgain.parent;
    }
    expect(liveAgain?.id, liveId);
    again = tester.getSemantics(find.text(_rejectedWords));
    expect(again.label, contains(_rejectedWords));

    camera.emit('good');
    expect(seen, ['not a pairing code', 'good']);
    expect(camera.stops, 1);
    semantics.dispose();
  });

  testWidgets('3. never keeps the value: not drawn, not in semantics or logs', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final logged = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add('$message');

    final camera = FakeScannerCamera();
    String? rejected;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => _scanner(
            camera,
            rejected: rejected,
            onCode: (raw) {
              setState(() => rejected = _rejectedWords);
              return false;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    camera.emit('oc2://pair?password=fake-secret');
    await tester.pumpAndSettle();

    expect(find.textContaining('fake-secret'), findsNothing);
    expect(
      _semanticsText(tester).where((s) => s.contains('fake-secret')),
      isEmpty,
    );
    debugDumpApp();
    debugPrint = previousPrint;
    expect(logged, isNotEmpty, reason: 'the tree dump was captured');
    expect(logged.where((s) => s.contains('fake-secret')), isEmpty);
    semantics.dispose();
  });

  testWidgets('4. a camera that fails is reported once and draws nothing', (
    tester,
  ) async {
    final camera = FakeScannerCamera(failWith: const KitScannerFailure('busy'));
    final failures = <KitScannerFailure>[];
    await tester.pumpWidget(_app(_scanner(camera, onFailed: failures.add)));
    await tester.pumpAndSettle();
    expect(failures, hasLength(1));
    expect(failures.single.deviceMessage, 'busy');
    expect(find.text(_instruction), findsNothing);
    expect(find.byKey(const ValueKey('kit-scanner-preview')), findsNothing);
    expect(find.text('Opening the camera…'), findsNothing);
  });

  testWidgets('5. slow: says so at 8 s with the way out, not at 7 s', (
    tester,
  ) async {
    final camera = FakeScannerCamera(hang: true);
    var pasted = 0;
    await tester.pumpWidget(
      _app(
        _scanner(
          camera,
          onSlow: [
            KitAction(
              label: 'Paste the code instead',
              onPressed: () => pasted++,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Opening the camera…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Still opening the camera'), findsNothing);
    expect(find.text('Paste the code instead'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Still opening the camera'), findsOneWidget);
    expect(find.text('Opening the camera…'), findsNothing);
    await tester.tap(find.text('Paste the code instead'));
    expect(pasted, 1);

    // Announced once: the words sit in one live region.
    final semantics = tester.ensureSemantics();
    SemanticsNode? live = tester.getSemantics(
      find.byKey(const ValueKey('kit-scanner-progress')),
    );
    while (live != null &&
        !live.getSemanticsData().flagsCollection.isLiveRegion) {
      live = live.parent;
    }
    expect(live, isNotNull);
    semantics.dispose();

    void noop() {}
    expect(
      () => KitScanner(
        instruction: _instruction,
        onCode: (_) => false,
        onFailed: (_) {},
        onSlow: [
          KitAction(label: 'a', onPressed: noop),
          KitAction(label: 'b', onPressed: noop),
          KitAction(label: 'c', onPressed: noop),
        ],
      ),
      throwsAssertionError,
    );
  });

  testWidgets('6. pauses in the background, resumes on return; a passed '
      'camera is stopped but not disposed', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final camera = FakeScannerCamera();
    await tester.pumpWidget(_app(_scanner(camera)));
    await tester.pump();
    expect(camera.starts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(camera.stops, 1);
    expect(find.text('Camera paused'), findsOneWidget);

    // A code decoded after the pause is not delivered.
    var delivered = 0;
    await tester.pumpWidget(
      _app(
        _scanner(
          camera,
          onCode: (_) {
            delivered++;
            return false;
          },
        ),
      ),
    );
    camera.emit('late');
    expect(delivered, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(camera.starts, 2);
    expect(find.text('Camera paused'), findsNothing);
    camera.emit('now');
    expect(delivered, 1);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(camera.stops, 2);
    expect(camera.disposes, 0, reason: 'its owner disposes a passed camera');
  });

  testWidgets('7. a short window puts the preview at the start, text at the '
      'end', (tester) async {
    await _size(tester, const Size(915, 412));
    await tester.pumpWidget(_app(_scanner(FakeScannerCamera())));
    await tester.pump();
    final preview = tester.getRect(
      find.byKey(const ValueKey('kit-scanner-preview')),
    );
    final text = tester.getRect(find.text(_instruction));
    expect(preview.left, 0);
    expect(preview.right, lessThanOrEqualTo(text.left));
    expect(preview.height, 412, reason: 'the window keeps the full height');
  });

  testWidgets('8. colours: accent corners while scanning, never danger or '
      'attention in any state', (tester) async {
    await _size(tester, const Size(412, 915));
    for (final light in [false, true]) {
      final roles = AppTheme.rolesOf(
        light ? AppTheme.light() : AppTheme.dark(),
      );
      final forbidden = {
        _argb(roles.danger),
        _argb(roles.dangerFill),
        _argb(roles.attention),
        _argb(roles.attentionFill),
      };
      Future<Set<int>> shot(
        Widget scanner, {
        Duration wait = Duration.zero,
      }) async {
        // A fresh tree: the app's theme would otherwise animate between
        // light and dark.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_app(scanner, light: light));
        await tester.pump();
        if (wait > Duration.zero) await tester.pump(wait);
        await tester.pump();
        return _paintedColours(tester);
      }

      final scanning = await shot(_scanner(FakeScannerCamera()));
      expect(scanning, contains(_argb(roles.accent)));
      expect(scanning.intersection(forbidden), isEmpty);

      final rejected = await shot(
        _scanner(FakeScannerCamera(), rejected: _rejectedWords),
      );
      expect(rejected.intersection(forbidden), isEmpty);

      final starting = await shot(_scanner(FakeScannerCamera(hang: true)));
      expect(starting, isNot(contains(_argb(roles.accent))));
      expect(starting.intersection(forbidden), isEmpty);

      final slow = await shot(
        _scanner(
          FakeScannerCamera(hang: true),
          onSlow: [
            KitAction(label: 'Paste the code instead', onPressed: () {}),
          ],
        ),
        wait: const Duration(seconds: 9),
      );
      expect(slow.intersection(forbidden), isEmpty);
      await tester.pumpWidget(_app(const SizedBox.shrink(), light: light));
    }
  });

  testWidgets('9. no overflow at 320, 412 and 915x412 up to 2.0 text; settles '
      'after one pump under reduced motion', (tester) async {
    for (final size in const [Size(320, 640), Size(412, 915), Size(915, 412)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        await _size(tester, size);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _app(
            _scanner(FakeScannerCamera(), rejected: _rejectedWords),
            textScale: scale,
            reduceMotion: true,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size at $scale');
        expect(
          tester.binding.hasScheduledFrame,
          isFalse,
          reason: 'still after one pump: $size at $scale',
        );
      }
    }
  });

  group('pairing scanner screen', () {
    String pairJson(String password) =>
        '{"urls":["http://127.0.0.1:49374"],"username":"opencode",'
        '"password":"$password"}';

    Future<(FakeScannerCamera, List<Object?>)> open(WidgetTester tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      final previous = cameraPlatform;
      cameraPlatform = _GrantedCamera();
      addTearDown(() => cameraPlatform = previous);
      final camera = FakeScannerCamera();
      final popped = <Object?>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => popped.add(
                  await Navigator.of(context).push<PairingPayload>(
                    MaterialPageRoute(
                      builder: (_) =>
                          PairingScannerScreen(scannerCamera: camera),
                    ),
                  ),
                ),
                child: const Text('Scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      return (camera, popped);
    }

    testWidgets('scanning is KitScanner under the kept keys; a wrong QR '
        'says why and a pairing QR pops with the payload', (tester) async {
      final (camera, popped) = await open(tester);
      expect(find.byType(KitScanner), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pairing-scanner-preview')),
        findsOneWidget,
      );

      camera.emit('hello');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pairing-scanner-rejected')),
        findsOneWidget,
      );
      expect(find.textContaining('hello'), findsNothing);
      expect(camera.stops, 0);

      camera.emit(pairJson('fake-secret'));
      await tester.pumpAndSettle();
      expect(find.byType(PairingScannerScreen), findsNothing);
      expect(popped, hasLength(1));
      expect((popped.single! as PairingPayload).password, 'fake-secret');
      expect(camera.stops, greaterThanOrEqualTo(1));
      expect(camera.disposes, 0);
    });

    testWidgets('a camera that will not open shows the failed state with '
        'the device words', (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      final previous = cameraPlatform;
      cameraPlatform = _GrantedCamera();
      addTearDown(() => cameraPlatform = previous);
      await tester.pumpWidget(
        _app(
          PairingScannerScreen(
            scannerCamera: FakeScannerCamera(
              failWith: const KitScannerFailure('camera in use'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pairing-scanner-failed')),
        findsOneWidget,
      );
      expect(find.byType(KitScanner), findsNothing);
    });
  });
}

class _GrantedCamera implements CameraPlatform {
  @override
  Future<bool> hasCamera() async => true;

  @override
  Future<CameraPermission> requestCameraPermission() async =>
      CameraPermission.granted;

  @override
  Future<void> openAppSettings() async {}
}
