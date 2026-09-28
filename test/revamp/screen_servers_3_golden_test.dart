// Golden renders of screen-servers-3's page (wave 2b): Connect with
// Tailscale (tailscale-setup), rebuilt from kit parts. One render per state
// at the phone size (412x915) and the loaded state at one wide window
// (1280x800), dark and light (owner decision 2026-09-27: no Arabic), with
// the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_servers_3_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/tailscale.dart';
import 'package:opencode_mobile/ui/screens/tailscale_setup_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

/// A fixed answer, or none at all ([hold]) to keep the check running.
class _Bridge extends TailscaleBridge {
  _Bridge(this.state, {this.hold = false, this.opens = true});

  final TailscaleAppState state;
  final bool hold;
  final bool opens;

  @override
  Future<TailscaleAppState> check() =>
      hold ? Completer<TailscaleAppState>().future : Future.value(state);

  @override
  Future<bool> open() async => opens;
}

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String state, Size size, bool light) => [
  'servers_tailscale_setup_$state',
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

/// Opens the screen as a page over a blank route (so its bar has Back),
/// runs [act], settles, and compares the whole window.
Future<void> _shot(
  WidgetTester tester,
  String state,
  _Bridge bridge, {
  required bool light,
  Size size = _phone,
  String address = '',
  Future<void> Function(WidgetTester tester)? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SizedBox.expand(),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<String>(
          builder: (_) =>
              TailscaleSetupScreen(bridge: bridge, initialAddress: address),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) await act(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(state, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    testWidgets('installed, $theme', (tester) async {
      await _shot(
        tester,
        'installed',
        _Bridge(TailscaleAppState.installed),
        light: light,
      );
    });

    testWidgets('installed at 1280x800, $theme', (tester) async {
      await _shot(
        tester,
        'installed',
        _Bridge(TailscaleAppState.installed),
        light: light,
        size: _wide,
        address: 'https://studio.tailnet-name.ts.net',
      );
    });

    testWidgets('checking, $theme', (tester) async {
      await _shot(
        tester,
        'checking',
        _Bridge(TailscaleAppState.installed, hold: true),
        light: light,
      );
    });

    testWidgets('missing, $theme', (tester) async {
      await _shot(
        tester,
        'missing',
        _Bridge(TailscaleAppState.missing),
        light: light,
      );
    });

    testWidgets('unsupported, $theme', (tester) async {
      await _shot(
        tester,
        'unsupported',
        _Bridge(TailscaleAppState.unsupported),
        light: light,
      );
    });

    testWidgets('check failed, $theme', (tester) async {
      await _shot(
        tester,
        'check_failed',
        _Bridge(TailscaleAppState.unavailable),
        light: light,
      );
    });

    testWidgets('open failed, $theme', (tester) async {
      await _shot(
        tester,
        'open_failed',
        _Bridge(TailscaleAppState.installed, opens: false),
        light: light,
        act: (tester) => _tapText(tester, 'Open Tailscale'),
      );
    });

    testWidgets('returned with an address error, $theme', (tester) async {
      await _shot(
        tester,
        'returned_address_error',
        _Bridge(TailscaleAppState.installed),
        light: light,
        address: 'http://100.64.0.1:4096',
        act: (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continue to sign-in'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.textContaining("won't work here"));
        },
      );
    });
  }
}
