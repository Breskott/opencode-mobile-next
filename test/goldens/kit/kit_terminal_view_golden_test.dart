// Gallery (gate G4) for KitTerminalView, docs/ux-system/kit-api/
// KitTerminalView.md "Galleries required" and kit-v2.md §8.2, §8.4: the live
// terminal with its key bar and the output form, in every declared state,
// at the gallery sizes, at 2.0 text and in Arabic.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_terminal_view_golden_test.dart
// and look at every changed image before committing it.
//
// The live scenes use a fake xterm.Terminal fed a fixed ANSI sample (a
// prompt, `ls --color`, a red error line, a green pass line), with no clock
// and no process (TEST-11).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_terminal_view.dart';
import 'package:opencode_mobile/ui/kit/terminal_key_bar.dart';
import 'package:xterm/xterm.dart' as xterm;

import 'kit_gallery.dart';

const _sample =
    '\x1b[32mdev@build-server\x1b[0m:\x1b[34m~/app\x1b[0m\$ ls --color\r\n'
    '\x1b[34mlib\x1b[0m  \x1b[34mtest\x1b[0m  \x1b[34mtool\x1b[0m  '
    '\x1b[32mbuild.sh\x1b[0m  pubspec.yaml\r\n'
    '\x1b[32mdev@build-server\x1b[0m:\x1b[34m~/app\x1b[0m\$ flutter test\r\n'
    '\x1b[31merror: test/app_test.dart:12:3: Expected a value\x1b[0m\r\n'
    '\x1b[32m00:06 +42: All tests passed!\x1b[0m\r\n'
    '\x1b[32mdev@build-server\x1b[0m:\x1b[34m~/app\x1b[0m\$ ';

/// A finished test run, read from the end: the tail shows how it went.
const _testRun = [
  '00:00 +0: loading test/kit/kit_terminal_view_test.dart',
  '00:01 +1: the key bar: every key is 48 x 48',
  '00:01 +2: the key bar compact: every key is 48 x 48',
  '00:01 +3: the key bar: Ctrl latches for one key',
  '00:02 +4: the key bar: no key vibrates',
  '00:02 +5: the key bar: disabled keys ignore taps',
  '00:02 +6: the live view: Tab reaches the shell',
  '00:03 +7: the live view: read-only drops typed input',
  '00:03 +8: the palette: themeOf(dark) uses the roles',
  '00:03 +9: the palette: themeOf(light) uses the roles',
  '00:04 +10: the output form: the tail first',
  '00:04 +11: the output form: too long, Open all',
  '00:04 +12: the output form: secrets are masked',
  '00:05 +13: the output form: tints',
  '00:05 +13 ~1: the output form: on a PC (skipped)',
  'Warning: golden images were not compared',
  '00:05 +14 ~1: the output form: in Arabic',
  '00:06 +14 ~1 -1: the old TerminalView forwards [E]',
  '  Expected: <1>',
  '    Actual: <0>',
  'error: Some tests failed.',
  '\x1b[2mTest run took 6.1 s\x1b[0m',
  '\x1b[32m14 passed\x1b[0m, \x1b[33m1 skipped\x1b[0m, \x1b[31m1 failed\x1b[0m',
];

const _command =
    'flutter test --concurrency=1 test/kit/kit_terminal_view_test.dart';

/// An apt run long enough to open elsewhere (2,500 lines).
final _aptRun = [
  for (var i = 1; i <= 2500; i++) 'Setting up package-$i (2.$i-1) ...',
].join('\n');

Future<void> _push(BuildContext context, Widget body) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: body)));

/// The live terminal of a server, with its keys.
Future<void> Function(BuildContext) _live({
  bool readOnly = false,
  bool latched = false,
  bool interruptKeys = false,
  String label = 'Terminal · build-server',
}) => (context) {
  final keys = TerminalKeyBarController();
  if (latched) keys.toggle(TerminalBarKey.ctrl);
  return _push(
    context,
    KitTerminalView.live(
      terminal: xterm.Terminal()..write(_sample),
      semanticsLabel: label,
      keys: keys,
      readOnly: readOnly,
      interruptKeys: interruptKeys,
    ),
  );
};

/// A command's output in a sheet: the frame's fill (`detailsSurface`) is
/// one step off the sheet's `surface2` in both themes.
Future<void> Function(BuildContext) _output({
  String? command = _command,
  String? output,
  int tailLines = 12,
  String title = 'Test run',
}) =>
    (context) => showKitSheet<void>(
      context,
      title: title,
      body: (_) => KitTerminalView.output(
        command: command,
        output: output ?? _testRun.join('\n'),
        tailLines: tailLines,
        onOpenFull: (_) {},
      ),
    );

Future<void> _showEarlier(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('terminal-show-earlier')));
  await tester.pump();
}

/// A PC: a fine pointer and hardware keys, so the key bar is left out.
void _desktop() {
  debugPlatformCapabilities = PlatformCapabilities(
    platform: TargetPlatform.linux,
  );
  addTearDown(() => debugPlatformCapabilities = null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    const phone = Size(412, 915);

    testWidgets('kit_terminal_view live · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_terminal_view_live', phone, light: light),
        size: phone,
        light: light,
        open: _live(),
      );
    });

    testWidgets('kit_terminal_view disabled (read-only) · $mode', (
      tester,
    ) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_terminal_view_disabled', phone, light: light),
        size: phone,
        light: light,
        open: _live(readOnly: true),
      );
    });

    testWidgets('kit_terminal_view keys latched · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_keys_latched',
          phone,
          light: light,
        ),
        size: phone,
        light: light,
        // A server terminal: Ctrl-C and Ctrl-D lead the bar.
        open: _live(latched: true, interruptKeys: true),
      );
    });

    testWidgets('kit_terminal_view keys compact · $mode', (tester) async {
      const landscape = Size(915, 412);
      // Landscape with the keyboard up: 200 dp of keyboard.
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_keys_compact',
          landscape,
          light: light,
        ),
        size: landscape,
        light: light,
        open: _live(),
      );
    });

    testWidgets('kit_terminal_view output tail · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_output_tail',
          phone,
          light: light,
        ),
        size: phone,
        light: light,
        open: _output(),
      );
    });

    testWidgets('kit_terminal_view output all · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_output_all',
          phone,
          light: light,
        ),
        size: phone,
        light: light,
        open: _output(),
        then: _showEarlier,
      );
    });

    testWidgets('kit_terminal_view output too long · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_output_too_long',
          phone,
          light: light,
        ),
        size: phone,
        light: light,
        open: _output(
          command: 'apt-get install -y build-essential',
          output: _aptRun,
          title: 'Install packages',
        ),
        then: (tester) async {
          await _showEarlier(tester);
          await tester.ensureVisible(
            find.byKey(const ValueKey('terminal-open-full')),
          );
        },
      );
    });

    testWidgets('kit_terminal_view empty · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_terminal_view_empty', phone, light: light),
        size: phone,
        light: light,
        open: _output(
          command: 'git status --short',
          output: '',
          title: 'Changes',
        ),
      );
    });

    for (final size in kitGallerySizes) {
      if (size == phone) continue;
      final at = kitGallerySize(size);
      testWidgets('kit_terminal_view live · $at · $mode', (tester) async {
        // A PC window: hardware keys, no key bar.
        if (size.width >= 1280) _desktop();
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_terminal_view_live', size, light: light),
          size: size,
          light: light,
          open: _live(),
        );
      });
    }

    testWidgets('kit_terminal_view live · 915x412 · $mode', (tester) async {
      const landscape = Size(915, 412);
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_terminal_view_live', landscape, light: light),
        size: landscape,
        light: light,
        open: _live(),
      );
    });
  }

  // 2.0 text and Arabic, dark: the live terminal (a touch tablet keeps its
  // keys at 1280) and the output's tail.
  for (final size in kitGalleryScaledSizes) {
    final at = kitGallerySize(size);
    testWidgets('kit_terminal_view live · 2.0 text · $at', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_live',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        open: _live(),
      );
    });
    testWidgets('kit_terminal_view live · ar · $at', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_live',
          size,
          light: false,
          ar: true,
        ),
        size: size,
        light: false,
        locale: const Locale('ar'),
        open: _live(label: 'الطرفية · build-server'),
      );
    });
    testWidgets('kit_terminal_view output tail · 2.0 text · $at', (
      tester,
    ) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_output_tail',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        open: _output(),
      );
    });
    testWidgets('kit_terminal_view output tail · ar · $at', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_terminal_view_output_tail',
          size,
          light: false,
          ar: true,
        ),
        size: size,
        light: false,
        locale: const Locale('ar'),
        open: _output(),
      );
    });
  }
}
