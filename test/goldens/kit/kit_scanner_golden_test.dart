// Gallery (gate G4) for KitScanner (docs/ux-system/kit-api/KitScanner.md):
// its states — starting and slow (kit_scanner_loading*), scanning, rejected
// (kit_scanner_error*) and paused — in
// dark and light at 412x915, the default (scanning) at 1280x800, and the
// rejected line at 2.0 text. Arabic galleries and the other sizes are out
// of scope (owner decision 2026-09-27: 412x915 and one wide size only).
//
// The part is shown in the host a screen gives it (KitScreen with a top
// bar), since it paints only its frame. The camera is a fake with a flat `surface3` preview, so nothing here
// depends on a device, the network or the wall clock (TEST-11); the slow
// state is reached by pumping the test's fake clock past 8 s.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_scanner_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';
import 'package:opencode_mobile/ui/kit/kit_scanner.dart';
import 'package:opencode_mobile/ui/kit/kit_screen.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';

import 'kit_gallery.dart';

class _FakeCamera implements KitScannerCamera {
  _FakeCamera({this.hang = false});

  final bool hang;

  @override
  Future<void> start() =>
      hang ? Completer<void>().future : Future<void>.value();

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<String> get codes => const Stream.empty();

  @override
  Widget preview(BuildContext context) =>
      ColoredBox(color: AppTheme.rolesOf(Theme.of(context)).surface3);
}

enum _State { starting, slow, scanning, rejected, paused }

void _open(BuildContext context, _State state) {
  unawaited(
    Navigator.of(context).push<void>(
      KitPageRoute(
        // The host a real screen gives it: KitScreen paints the ground.
        builder: (_) => KitScreen(
          topBar: const KitTopBar(
            title: 'Scan pairing code',
            exit: KitTopBarExit.close,
          ),
          body: KitScanner(
            camera: _FakeCamera(
              hang: state == _State.starting || state == _State.slow,
            ),
            instruction:
                'Point the camera at the QR code printed by opencode2 pair.',
            rejected: state == _State.rejected
                ? 'That is not a pairing code. Scan the QR code that '
                      'opencode2 pair prints.'
                : null,
            onSlow: [KitAction(label: 'Paste it instead', onPressed: () {})],
            onCode: (_) => false,
            onFailed: (_) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> Function(WidgetTester tester)? _then(_State state) =>
    switch (state) {
      _State.slow => (tester) => tester.pump(const Duration(seconds: 9)),
      _State.paused => (tester) async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed)
          // Inactive rather than paused: the part pauses on both, and a
          // paused binding stops drawing frames, so the next pass of the
          // shot would never build.
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
      },
      _ => null,
    };

Future<void> _shot(
  WidgetTester tester,
  _State state, {
  required bool light,
  required String name,
}) async {
  addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );
  await kitGalleryShot(
    tester,
    name: name,
    size: const Size(412, 915),
    light: light,
    open: (context) => _open(context, state),
    then: _then(state),
  );
}

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // The kit manifest (G4) reads each name from its kitGalleryName call:
    // a declared KIT-12 state leads it (loading for starting and slow,
    // error for the rejected line).
    testWidgets('starting · 412x915 · $mode', (tester) async {
      await _shot(
        tester,
        _State.starting,
        light: light,
        name: kitGalleryName(
          'kit_scanner_loading',
          const Size(412, 915),
          light: light,
        ),
      );
    });

    testWidgets('slow · 412x915 · $mode', (tester) async {
      await _shot(
        tester,
        _State.slow,
        light: light,
        name: kitGalleryName(
          'kit_scanner_loading_slow',
          const Size(412, 915),
          light: light,
        ),
      );
    });

    testWidgets('scanning · 412x915 · $mode', (tester) async {
      await _shot(
        tester,
        _State.scanning,
        light: light,
        name: kitGalleryName(
          'kit_scanner_scanning',
          const Size(412, 915),
          light: light,
        ),
      );
    });

    testWidgets('rejected · 412x915 · $mode', (tester) async {
      await _shot(
        tester,
        _State.rejected,
        light: light,
        name: kitGalleryName(
          'kit_scanner_error',
          const Size(412, 915),
          light: light,
        ),
      );
    });

    testWidgets('paused · 412x915 · $mode', (tester) async {
      await _shot(
        tester,
        _State.paused,
        light: light,
        name: kitGalleryName(
          'kit_scanner_paused',
          const Size(412, 915),
          light: light,
        ),
      );
    });

    testWidgets('scanning · 1280x800 · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_scanner_scanning',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        open: (context) => _open(context, _State.scanning),
      );
    });
  }

  testWidgets('rejected · 2.0 text · 412x915 · dark', (tester) async {
    await kitGalleryShot(
      tester,
      name: kitGalleryName(
        'kit_scanner_error',
        const Size(412, 915),
        light: false,
        text2: true,
      ),
      size: const Size(412, 915),
      light: false,
      textScale: 2,
      open: (context) => _open(context, _State.rejected),
    );
  });
}
