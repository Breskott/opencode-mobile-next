import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/platform/tailscale.dart';
import 'package:opencode_mobile/state/tailscale_address.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/tailscale_setup_screen.dart';

class _Bridge extends TailscaleBridge {
  TailscaleAppState state = TailscaleAppState.installed;
  int checks = 0, opens = 0;
  bool opensSuccessfully = true;
  Completer<TailscaleAppState>? pending;
  @override
  Future<TailscaleAppState> check() async {
    checks++;
    return pending?.future ?? state;
  }

  @override
  Future<bool> open() async {
    opens++;
    return opensSuccessfully;
  }
}

Future<void> _show(
  WidgetTester tester,
  _Bridge bridge, {
  ValueChanged<String?>? result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final value = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => TailscaleSetupScreen(bridge: bridge),
                ),
              );
              result?.call(value);
            },
            child: const Text('Start'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'review accepts HTTPS origins and bare MagicDNS without loosening policy',
    () {
      expect(
        normalizeTailscaleAddress(' computer.example.ts.net '),
        'https://computer.example.ts.net',
      );
      for (final value in [
        'computer.example.ts.net',
        'https://computer.example.ts.net:8443',
        'https://private.example',
      ]) {
        expect(isValidTailscaleAddress(value), isTrue, reason: value);
      }
      for (final value in [
        'http://100.64.0.1:4096',
        'http://localhost:4096',
        'https://a:0',
        'https://a:65536',
        'https://a:bad',
        'https://a/path',
        'https://user:secret@a',
        'https://a?token=secret',
        'https://a#token',
        'javascript:alert(1)',
        '',
      ]) {
        expect(isValidTailscaleAddress(value), isFalse, reason: value);
      }
    },
  );

  test(
    'native bridge maps only explicit package evidence and fails closed',
    () async {
      const channel = MethodChannel('oc/tailscale');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final methods = <String>[];
      Object? result = 'installed';
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return result;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const bridge = TailscaleBridge();
      expect(await bridge.check(), TailscaleAppState.installed);
      result = 'connected';
      expect(await bridge.check(), TailscaleAppState.unavailable);
      result = 'missing';
      expect(await bridge.check(), TailscaleAppState.missing);
      result = true;
      expect(await bridge.open(), isTrue);
      result = false;
      expect(await bridge.open(), isFalse);
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      addTearDown(() => debugPlatformCapabilities = null);
      expect(await bridge.check(), TailscaleAppState.unsupported);
      expect(await bridge.open(), isFalse);
      expect(methods, ['check', 'check', 'check', 'open', 'open']);
    },
  );

  testWidgets(
    'installed says only that; open and resume preserve the typed address',
    (tester) async {
      final bridge = _Bridge();
      await _show(tester, bridge);
      expect(find.text('Tailscale is installed.'), findsOneWidget);
      // The app cannot see the VPN; the row does not guess about it.
      expect(find.textContaining('unverified'), findsNothing);
      expect(bridge.opens, 0);
      await tester.enterText(find.byType(TextField), 'work.example.ts.net');
      await _tap(tester, 'Open Tailscale');
      expect(bridge.opens, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(bridge.checks, greaterThan(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'work.example.ts.net',
      );
      expect(
        find.textContaining('Welcome back.', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'missing app offers official install with external host review and recheck',
    (tester) async {
      final bridge = _Bridge()..state = TailscaleAppState.missing;
      await _show(tester, bridge);
      expect(find.textContaining('not installed'), findsOneWidget);
      await _tap(tester, 'Get Tailscale');
      expect(find.text('Open external link?'), findsOneWidget);
      expect(
        find.text('Opens play.google.com outside this app.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      bridge.state = TailscaleAppState.installed;
      await _tap(tester, 'Check Tailscale again');
      expect(find.text('Open Tailscale'), findsOneWidget);
      expect(bridge.opens, 0);
    },
  );

  testWidgets('failed launch gives recovery and review never probes or saves', (
    tester,
  ) async {
    final bridge = _Bridge()..opensSuccessfully = false;
    String? result;
    await _show(tester, bridge, result: (value) => result = value);
    await _tap(tester, 'Open Tailscale');
    expect(find.textContaining('didn’t open'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'http://100.64.0.1:4096');
    await _tap(tester, 'Continue to sign-in');
    expect(result, isNull);
    expect(find.textContaining("won't work here"), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'work.example.ts.net');
    await _tap(tester, 'Continue to sign-in');
    expect(result, 'https://work.example.ts.net');
  });

  testWidgets('late package check after dismissal is ignored', (tester) async {
    final bridge = _Bridge();
    await _show(tester, bridge);
    bridge.pending = Completer<TailscaleAppState>();
    await tester.ensureVisible(find.text('Check Tailscale again'));
    await tester.tap(find.text('Check Tailscale again'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    bridge.pending!.complete(TailscaleAppState.installed);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Continue waits for an address and says why; the counter stays hidden',
    (tester) async {
      final bridge = _Bridge();
      String? result;
      await _show(tester, bridge, result: (value) => result = value);
      expect(find.text('Enter your server’s address first.'), findsOneWidget);
      await tester.tap(find.text('Continue to sign-in'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.textContaining("won't work here"), findsNothing);
      await tester.enterText(find.byType(TextField), 'work.example.ts.net');
      await tester.pump();
      expect(find.text('Enter your server’s address first.'), findsNothing);
      expect(find.textContaining('/2048'), findsNothing);
      // The one caveat line; the rest waits in the fold.
      expect(
        find.text('Paste the HTTPS address Tailscale Serve printed.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('can’t list the devices on your tailnet'),
        findsNothing,
      );
      expect(find.textContaining('Continue only with'), findsNothing);
    },
  );

  testWidgets('a failed app check offers Check Tailscale again on its row', (
    tester,
  ) async {
    final bridge = _Bridge()..state = TailscaleAppState.unavailable;
    await _show(tester, bridge);
    expect(find.textContaining('Could not check the app'), findsOneWidget);
    expect(find.text('Open Tailscale'), findsNothing);
    bridge.state = TailscaleAppState.installed;
    await _tap(tester, 'Check Tailscale again');
    expect(find.text('Open Tailscale'), findsOneWidget);
    expect(find.text('Tailscale is installed.'), findsOneWidget);
  });

  testWidgets(
    'R15: the steps are one panel of rows; a step the person has '
    'to do says To do, never Needs you, and its button sits under its words',
    (tester) async {
      final bridge = _Bridge()..state = TailscaleAppState.missing;
      await _show(tester, bridge);
      final panel = find.byKey(const ValueKey('tailscale-steps'));
      expect(
        find.descendant(of: panel, matching: find.byType(KitRow)),
        findsNWidgets(3),
      );
      expect(find.textContaining('Needs you'), findsNothing);
      expect(
        find.textContaining('To do · Tailscale is not installed'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tailscale-step-app')),
          matching: find.byType(KitStatusMark),
        ),
        findsOneWidget,
      );
      final words = find.textContaining('To do · Tailscale is not installed');
      final button = find.text('Get Tailscale');
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getBottomLeft(words).dy),
      );
      // Check Tailscale again is the panel's own last row.
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(const ValueKey('tailscale-check-again')),
        ),
        findsOneWidget,
      );
      expect(find.text('Check Tailscale again'), findsOneWidget);
      // The section captions are the kit's.
      expect(find.byType(KitSectionLabel), findsNWidgets(2));
    },
  );

  testWidgets('R15: one caveat line on the page; the rest is in the fold', (
    tester,
  ) async {
    await _show(tester, _Bridge());
    expect(
      find.text('Paste the HTTPS address Tailscale Serve printed.'),
      findsOneWidget,
    );
    expect(find.textContaining('Continue only with'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Tailscale setup and recovery'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await _tap(tester, 'Tailscale setup and recovery');
    expect(find.textContaining('Continue only with'), findsOneWidget);
    expect(
      find.text('OpenCode can’t list the devices on your tailnet.'),
      findsOneWidget,
    );
  });

  testWidgets('unsupported device explains and offers no app actions', (
    tester,
  ) async {
    final bridge = _Bridge()..state = TailscaleAppState.unsupported;
    await _show(tester, bridge);
    expect(find.textContaining('cannot open the Android app'), findsOneWidget);
    expect(find.text('Open Tailscale'), findsNothing);
    expect(find.text('Get Tailscale'), findsNothing);
    expect(find.text('Check Tailscale again'), findsNothing);
  });

  testWidgets('official guides fold under Details and open for review', (
    tester,
  ) async {
    await _show(tester, _Bridge());
    await tester.dragUntilVisible(
      find.text('Tailscale setup and recovery'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Read the official Serve guide'), findsNothing);
    await _tap(tester, 'Tailscale setup and recovery');
    await _tap(tester, 'Read the official Serve guide');
    expect(find.text('Open external link?'), findsOneWidget);
    expect(find.text('Opens tailscale.com outside this app.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  for (final size in const [
    Size(360, 800),
    Size(412, 915),
    Size(915, 412),
    Size(800, 1280),
    Size(1280, 800),
  ]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('lays out without overflow at $size, text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final bridge = _Bridge()..state = TailscaleAppState.missing;
        await _show(tester, bridge);
        expect(tester.takeException(), isNull);
        bridge.state = TailscaleAppState.installed;
        await tester.dragUntilVisible(
          find.text('Check Tailscale again'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await _tap(tester, 'Check Tailscale again');
        // Short windows may have scrolled the steps away: bring the row
        // back into view, then check its button laid out cleanly.
        await tester.dragUntilVisible(
          find.text('Open Tailscale'),
          find.byType(ListView),
          const Offset(0, 200),
        );
        expect(find.text('Open Tailscale'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.dragUntilVisible(
          find.byType(TextField),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.enterText(find.byType(TextField), 'http://bad');
        await _tap(tester, 'Continue to sign-in');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
