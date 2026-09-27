// Gallery (gate G4) for KitCodeBlock, docs/ux-system/kit-api/KitCodeBlock.md:
// the declared states (header with counts, command, capped output, wrapped,
// copied, `.fill` with find marks, empty), on `ground`, at the two sizes
// the owner's 2026-09-27 decision keeps (412x915 phone, 1280x800 wide),
// light and dark. Arabic and text-2.0 galleries are dropped by that same
// decision (no RTL review for this wave).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_code_block_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

const _copyKey = ValueKey('kit-code-copy');

/// The block on the page's own background, at the screen gutter, as it sits
/// in a transcript or a reader (KitCodeBlock.md's default placement).
Widget _onGround(Widget child) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return ColoredBox(
      color: tokens.roles.ground,
      child: Padding(
        padding: EdgeInsets.all(tokens.gutter),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  },
);

/// A `surface1` sheet body, as `KitSheet` presents a fenced code block
/// (KitCodeBlock.md "on ground and inside a sheet body").
Widget _inSheet(Widget child) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return ColoredBox(
      color: tokens.roles.ground,
      child: Padding(
        padding: EdgeInsets.all(tokens.gutter),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.roles.surface2,
            borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
          ),
          child: Padding(padding: EdgeInsets.all(tokens.space4), child: child),
        ),
      ),
    );
  },
);

const _sampleDart = '''
class ConnectionController extends ChangeNotifier {
  Future<void> connect(Profile profile) async {
    final client = await _gateway.open(profile);
    _client = client;
    notifyListeners();
  }
}''';

Widget _codeHeaderScene() => _inSheet(
  const KitCodeBlock(
    text: _sampleDart,
    language: 'dart',
    fileName: 'lib/state/connection.dart',
    added: 4,
    removed: 1,
  ),
);

Widget _commandScene() => _onGround(
  const KitCodeBlock(
    text:
        'curl -sS -u opencode:<your password> '
        'https://100.64.0.4:4097/api/session/list | jq .',
    kind: KitCodeKind.command,
  ),
);

String _outputLines(int n) =>
    [for (var i = 1; i <= n; i++) 'line $i: ok'].join('\n');

Widget _outputCappedScene() => _onGround(
  KitCodeBlock(text: _outputLines(40), kind: KitCodeKind.output, maxLines: 12),
);

Widget _wrappedScene() => _onGround(
  const KitCodeBlock(
    text:
        'final message = "This line is written long on purpose so the '
        'gallery shows word wrap instead of a sideways scroller.";',
    wrap: true,
  ),
);

Widget _copiedScene() => _onGround(
  const KitCodeBlock(text: 'flutter test -j 1 test/kit/a_test.dart'),
);

Widget _fillFindScene() => _onGround(
  SizedBox(
    height: 220,
    child: KitCodeBlock.fill(
      text: [
        'class ConnectionController extends ChangeNotifier {',
        '  Future<void> connect(Profile profile) async {',
        '    final client = await _gateway.open(profile);',
        '    _client = client;',
        '    notifyListeners();',
        '  }',
        '}',
      ].join('\n'),
      language: 'dart',
      marks: const [
        TextRange(start: 6, end: 26),
        TextRange(start: 60, end: 67),
      ],
      activeMark: 1,
    ),
  ),
);

// R3: a one-line command with no caption keeps Copy on its own line (no
// header band); several commands under a caller's label get a header that
// reads it; a host that passes wrap: true gets hanging continuation lines.
Widget _commandShortScene() => _onGround(
  const KitCodeBlock(text: 'flutter run', kind: KitCodeKind.command),
);

const _adbCommands = '''
adb shell dumpsys deviceidle whitelist +com.termux
adb shell cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow
adb shell device_config put activity_manager max_phantom_processes 2147483647''';

Widget _commandsLabelledScene() => _inSheet(
  const KitCodeBlock(
    text: _adbCommands,
    kind: KitCodeKind.command,
    copyLabel: 'Copy commands',
  ),
);

Widget _commandWrappedScene() => _inSheet(
  const KitCodeBlock(
    text: _adbCommands,
    kind: KitCodeKind.command,
    copyLabel: 'Copy commands',
    wrap: true,
  ),
);

Widget _emptyScene() => _onGround(const KitCodeBlock(text: ''));

Future<void> Function(BuildContext) _push(Widget scene) =>
    (context) => Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => Scaffold(body: scene),
      ),
    );

void main() {
  setUpAll(loadKitGalleryFonts);

  // The copied scene's tap runs the real KitCopy.copy: mock the platform
  // (Clipboard.setData) and accessibility (the "Copied" announcement)
  // channels so its awaited chain resolves within one pump() and the
  // check glyph actually swaps in before the golden is taken (pattern:
  // kit_icon_button_golden_test.dart).
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async => null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  // The owner's 2026-09-27 decision: phone and one wide size only, no
  // Arabic and no text-2.0 gallery for this wave.
  const sizes = [Size(412, 915), Size(1280, 800)];

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in sizes) {
      final at = kitGallerySize(size);

      for (final MapEntry(key: state, value: scene) in <String, Widget>{
        'code_header': _codeHeaderScene(),
        'command': _commandScene(),
        'output_capped': _outputCappedScene(),
        'wrapped': _wrappedScene(),
        'fill_find': _fillFindScene(),
        'empty': _emptyScene(),
        'command_short': _commandShortScene(),
        'commands_labelled': _commandsLabelledScene(),
        'command_wrapped': _commandWrappedScene(),
      }.entries) {
        testWidgets('kit_code_block $state · $at · $mode', (tester) async {
          await kitGalleryShot(
            tester,
            name: kitGalleryName('kit_code_block_$state', size, light: light),
            size: size,
            light: light,
            open: _push(scene),
          );
        });
      }

      testWidgets('kit_code_block copied · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_code_block_copied', size, light: light),
          size: size,
          light: light,
          open: _push(_copiedScene()),
          then: (tester) async {
            await tester.tap(find.byKey(_copyKey));
            await tester.pump();
          },
        );
        // The copied check reverts after KitMotion.copiedHold; flush that
        // Timer now so it is not still pending when the test ends.
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}
