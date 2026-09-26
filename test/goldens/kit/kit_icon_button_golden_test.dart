// Gallery (gate G4) for KitIconButton v2, docs/ux-system/kit-api/KitIconButton.md:
// the app's one icon-only control, every declared state at 412×915, the
// default state at the other LAY-4 sizes, and at 2.0 text and in Arabic.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_icon_button_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _groundKey = ValueKey('kit-icon-button-scene-ground');
const _panelKey = ValueKey('kit-icon-button-scene-panel');

/// A row of the button on `ground` and on a `surface1` panel (KitIconButton.md
/// "The scene"), so a hover, selected or focused fill reads on both.
/// Interaction in a gallery shot's `then` always targets the ground copy.
Widget _scene({
  IconData icon = AppIconography.retry,
  String tooltip = 'Retry connection',
  String? shortcut,
  bool destructive = false,
  bool working = false,
  bool? selected,
  bool disabled = false,
}) => Builder(
  builder: (context) {
    final roles = KitTokens.of(context).roles;
    Widget button(Key key) => KitIconButton(
      key: key,
      icon: icon,
      tooltip: tooltip,
      shortcut: shortcut,
      destructive: destructive,
      working: working,
      selected: selected,
      disabledReason: disabled ? 'Read-only connection' : null,
      onPressed: disabled ? null : () {},
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(_groundKey),
          const SizedBox(width: 56),
          DecoratedBox(
            decoration: BoxDecoration(
              color: roles.surface1,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: button(_panelKey),
            ),
          ),
        ],
      ),
    );
  },
);

Widget _copyScene() => Builder(
  builder: (context) {
    final roles = KitTokens.of(context).roles;
    Widget button(Key key) => KitIconButton.copy(
      key: key,
      text: () => 'flutter test test/checkout_test.dart',
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(_groundKey),
          const SizedBox(width: 56),
          DecoratedBox(
            decoration: BoxDecoration(
              color: roles.surface1,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: button(_panelKey),
            ),
          ),
        ],
      ),
    );
  },
);

Future<void> Function(BuildContext) _push(Widget scene) =>
    (context) => Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => Scaffold(body: scene),
      ),
    );

/// `kitGalleryShot` calls `then` once per theme pass (the other theme is
/// checked, then discarded; only the second, own-theme pass is captured).
/// A fresh mouse pointer is added and removed each time except the last, so
/// the second `addPointer` is never called while the first is still
/// connected (the mouse tracker asserts Added/Removed alternate) and the
/// hover fill is still live when the golden is taken.
Future<void> Function(WidgetTester) _hoverThen() {
  var call = 0;
  return (tester) async {
    call++;
    final last = call == 2;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    if (last) {
      addTearDown(gesture.removePointer);
    }
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(_groundKey)));
    await tester.pump();
    if (!last) await gesture.removePointer();
  };
}

/// A touch long-press on the ground copy, held so the tooltip stays up for
/// the shot (the compact-window path: no hover, the tooltip shows on
/// long-press). Like [_hoverThen], each theme pass holds its own pointer;
/// the previous pass's pointer is lifted first. [release] lifts the last one
/// after the golden, and lets the tooltip's dismiss delay run out.
({
  Future<void> Function(WidgetTester) then,
  Future<void> Function(WidgetTester) release,
})
_longPressThen() {
  TestGesture? held;
  return (
    then: (tester) async {
      await held?.up();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_groundKey)),
      );
      held = gesture;
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    },
    release: (tester) async {
      await held?.up();
      held = null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );
}

/// One Tab from the freshly pushed route lands on the ground copy, the
/// first control in reading order, and focus stays there (LAY-10).
Future<void> _focusGround(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  final focused = FocusManager.instance.primaryFocus?.context;
  final ground = tester.element(find.byKey(_groundKey));
  var inGround = focused == ground;
  (focused as Element?)?.visitAncestorElements((ancestor) {
    if (ancestor == ground) inGround = true;
    return !inGround;
  });
  expect(inGround, isTrue, reason: 'one Tab focuses the ground copy');
}

void main() {
  setUpAll(loadKitGalleryFonts);

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
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
    debugPlatformCapabilities = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  const phone = Size(412, 915);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // Nine declared states at 412x915 (18 PNGs).
    for (final MapEntry(key: state, value: scene) in <String, Widget>{
      'default': _scene(),
      'selected_on': _scene(
        icon: AppIconography.wrapText,
        tooltip: 'Wrap lines',
        selected: true,
      ),
      'selected_off': _scene(
        icon: AppIconography.wrapText,
        tooltip: 'Wrap lines',
        selected: false,
      ),
      'destructive': _scene(
        icon: AppIconography.delete,
        tooltip: 'Delete',
        destructive: true,
      ),
    }.entries) {
      testWidgets('kit_icon_button $state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_icon_button_$state', phone, light: light),
          size: phone,
          light: light,
          child: scene,
        );
      });
    }

    // disabled and working are KitIconButton's two KIT-12 declared states
    // (its `/// States:` doc line): gate G4 (stateScenes) looks for their
    // 412x915 goldens through a literal `kitGalleryShot`/`kitGalleryName`
    // call, so these two use kitGalleryShot rather than kitGalleryPart.
    testWidgets('kit_icon_button disabled · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_icon_button_disabled', phone, light: light),
        size: phone,
        light: light,
        open: _push(_scene(disabled: true)),
      );
    });

    testWidgets('kit_icon_button working · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_icon_button_working', phone, light: light),
        size: phone,
        light: light,
        // The spinner is drawn as a still dot under disableAnimations
        // (KitMotion.reduced), which every gallery shot sets, so this never
        // ticks.
        open: _push(_scene(working: true)),
      );
    });

    testWidgets('kit_icon_button hover · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_icon_button_hover', phone, light: light),
        size: phone,
        light: light,
        open: _push(_scene()),
        then: _hoverThen(),
      );
    });

    testWidgets('kit_icon_button focused · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_icon_button_focused', phone, light: light),
        size: phone,
        light: light,
        open: _push(_scene()),
        then: _focusGround,
      );
    });

    testWidgets('kit_icon_button copied · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_icon_button_copied', phone, light: light),
        size: phone,
        light: light,
        open: _push(_copyScene()),
        then: (tester) async {
          await tester.tap(find.byKey(_groundKey));
          await tester.pump();
        },
      );
      // The copied check reverts after KitMotion.copiedHold; flush that
      // Timer now so it is not still pending when the test ends.
      await tester.pump(KitMotion.copiedHold);
    });

    // The default state at the other LAY-4 gallery sizes (kit_gallery.dart's
    // kitGallerySizes; the phone entry above coincides with one of these).
    // The shared harness lacks LAY-4's 915x412 landscape phone, so this
    // gallery adds it itself (TEST-9, LAY-4).
    for (final size in [...kitGallerySizes, const Size(915, 412)]) {
      final at = kitGallerySize(size);
      testWidgets('kit_icon_button default · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_icon_button_default', size, light: light),
          size: size,
          light: light,
          child: _scene(),
        );
      });
    }

    // Default at text 2.0 and in Arabic, at the two scaled sizes. The wider
    // (1280x800) shots also show the hover tooltip with its shortcut.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      final wide = size == const Size(1280, 800);

      testWidgets('kit_icon_button default · 2.0 text · $at · $mode', (
        tester,
      ) async {
        if (!wide) {
          // The compact-window path: a touch long-press shows the tooltip,
          // whose label wraps to two lines at 2.0 text and is not cut.
          debugPlatformCapabilities = null;
          final press = _longPressThen();
          await kitGalleryShot(
            tester,
            name: kitGalleryName(
              'kit_icon_button_default',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            open: _push(
              _scene(
                tooltip: 'Retry the connection to this server',
                shortcut: 'Ctrl+R',
              ),
            ),
            then: press.then,
          );
          await press.release(tester);
          return;
        }
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_icon_button_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _push(_scene(shortcut: 'Ctrl+R')),
          then: _hoverThen(),
        );
      });

      testWidgets('kit_icon_button default · ar · $at · $mode', (tester) async {
        if (!wide) {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_icon_button_default',
              size,
              light: light,
              ar: true,
            ),
            size: size,
            light: light,
            locale: const Locale('ar'),
            child: _scene(shortcut: 'Ctrl+R'),
          );
          return;
        }
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_icon_button_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          open: _push(_scene(shortcut: 'Ctrl+R')),
          then: _hoverThen(),
        );
      });
    }
  }
}
