// Gallery (gate G4) for KitMarkdown, docs/ux-system/kit-api/KitMarkdown.md:
// a reply (heading, list, inline code, link, quote, short fence), a wide
// table scrolling in its box, a streaming (unclosed) fence, the secondary
// role, a validated path link and the empty state, on `ground`, at the two
// sizes the owner's 2026-09-27 decision keeps (412x915 phone, 1280x800 wide
// in the 700 dp conversation pane), light and dark, plus the default at
// text 2.0. Arabic galleries are dropped by that same decision.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_markdown_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_markdown.dart';
import 'package:opencode_mobile/ui/kit/kit_layout.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// The reply on the page's own background at the screen gutter, capped at
/// the conversation pane width as the chat host lays it out.
Widget _onGround(Widget child) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return ColoredBox(
      color: tokens.roles.ground,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.gutter),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: KitLayout.paneDetailMaxWidth,
            ),
            child: child,
          ),
        ),
      ),
    );
  },
);

const _reply = '''
## Reconnect after the phone sleeps

The controller now **refetches** the session instead of replaying events.
See [the protocol notes](https://opencode.ai/docs) for why.

- `ConnectionController.resume()` reopens the stream
- Missed deltas are *never* replayed
- The session list refreshes once

> Deltas and tool progress never replay after a reconnect.

```dart
await controller.resume();
final sessions = await gateway.listSessions();
```
''';

const _table = '''
| Server | Address | Protocol | Status | Last seen | Sessions |
| --- | --- | --- | :---: | --- | ---: |
| Phone | `127.0.0.1:4096` | OpenCode 1 | online | just now | 12 |
| Workstation | `100.64.0.4:4097` | OpenCode 2 | online | 2 min ago | 48 |
| Build box | `100.64.0.9:4097` | OpenCode 2 | offline | yesterday | 3 |
''';

const _streaming = '''
Here is the fix, still arriving:

```kotlin
class ShareReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)''';

const _secondary = '''
Checked the **three** call sites; only `chat_screen.dart` reads the old flag.
The others take it from the gateway.''';

const _pathLink =
    'The screenshot is saved at `/tmp/opencode/shots/home.png` and the '
    'test lives in `test/kit/kit_markdown_test.dart:42`.';

Future<bool> _readable(String path) async => true;

final _scenes = <String, Widget>{
  'default': const KitMarkdown(_reply),
  'table': const KitMarkdown(_table),
  'streaming': const KitMarkdown(_streaming),
  'secondary': const KitMarkdown(_secondary, role: KitTextRole.secondary),
  'path_link': KitMarkdown(
    _pathLink,
    fileLinks: KitMarkdownFileLinks(validate: _readable, open: (_) {}),
  ),
  'empty': const KitMarkdown(''),
};

Future<void> Function(BuildContext) _push(Widget scene) =>
    (context) => Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => Scaffold(body: _onGround(scene)),
      ),
    );

void main() {
  setUpAll(loadKitGalleryFonts);

  const sizes = [Size(412, 915), Size(1280, 800)];

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in sizes) {
      final at = kitGallerySize(size);
      for (final MapEntry(key: state, value: scene) in _scenes.entries) {
        testWidgets('kit_markdown $state · $at · $mode', (tester) async {
          await kitGalleryShot(
            tester,
            name: kitGalleryName('kit_markdown_$state', size, light: light),
            size: size,
            light: light,
            open: _push(scene),
          );
        });
      }
    }

    testWidgets('kit_markdown default · text 2.0 · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_markdown_default',
          const Size(412, 915),
          light: light,
          text2: true,
        ),
        size: const Size(412, 915),
        light: light,
        textScale: 2,
        open: _push(_scenes['default']!),
      );
    });
  }
}
