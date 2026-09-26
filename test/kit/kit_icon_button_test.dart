// Gate G9 (docs/ux-system/kit-api/KitIconButton.md; STANDARDS.md §18) for
// KitIconButton v2: the tooltip/semantic-label parity and its shortcut span
// (G14x), the KIT-22 empty-tooltip assert, the 48 dp target (G37), the
// retired `label:` forwarding (KIT-43), the disabled and working states,
// selected toggling, the destructive tint, the copy contract (G9, G12),
// reduced motion (G8x) and keyboard activation (G14).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  bool disableAnimations = false,
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.dark(),
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: disableAnimations,
      textScaler: TextScaler.linear(textScale),
    ),
    child: widget!,
  ),
  home: Scaffold(body: Center(child: child)),
);

final _button = find.byType(KitIconButton);

/// Whether keyboard focus is on [target] itself or something inside it, as
/// test/kit/kit_keyboard_test.dart's helper does for the modal parts.
bool _focusIn(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final element = tester.element(target);
  if (focused == element) return true;
  var found = false;
  (focused as Element).visitAncestorElements((ancestor) {
    if (ancestor == element) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Color? _glyphColor(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: _button, matching: find.byType(Icon)))
    .color;

bool _focusRingPainted(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: _button, matching: find.byType(DecoratedBox)),
    )
    .any((box) => (box.decoration as BoxDecoration).border != null);

void main() {
  late List<MethodCall> platform;
  late List<Map<Object?, Object?>> announcements;

  setUp(() {
    platform = [];
    announcements = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call);
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<Object?, Object?>;
        if (map['type'] == 'announce') announcements.add(map);
        return null;
      },
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

  String? copied() {
    final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
    return (call.arguments as Map)['text'] as String?;
  }

  testWidgets(
    'the semantic label equals the tooltip; a fine pointer adds the shortcut',
    (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      await tester.pumpWidget(
        _host(
          KitIconButton(
            icon: AppIconography.retry,
            tooltip: 'Retry connection',
            shortcut: 'Ctrl+R',
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(_button);
      expect(semantics.label, 'Retry connection');
      expect(
        semantics,
        matchesSemantics(
          label: 'Retry connection',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      final rich = tooltip.richMessage! as TextSpan;
      final spans = rich.children!;
      expect((spans.first as TextSpan).text, 'Retry connection');
      expect((spans.first as TextSpan).text, semantics.label);
      expect((spans.last as TextSpan).text, contains('Ctrl+R'));

      // Hovering with a mouse (a fine pointer) actually shows the overlay.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_button));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.textContaining('Retry connection'), findsWidgets);
    },
  );

  testWidgets('with no touch device, the tooltip has no shortcut span', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        KitIconButton(
          icon: AppIconography.retry,
          tooltip: 'Retry connection',
          shortcut: 'Ctrl+R',
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    final rich = tooltip.richMessage! as TextSpan;
    expect(rich.children, hasLength(1));
  });

  test('an empty tooltip and no label asserts (KIT-22)', () {
    expect(
      () => KitIconButton(
        icon: AppIconography.close,
        tooltip: '',
        onPressed: () {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('the target is 48x48 at text 1.0 and 2.0, compact and large', (
    tester,
  ) async {
    for (final size in [const Size(360, 800), const Size(1600, 1000)]) {
      for (final textScale in [1.0, 2.0]) {
        tester.view
          ..physicalSize = size * tester.view.devicePixelRatio
          ..devicePixelRatio = tester.view.devicePixelRatio;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(
            KitIconButton(
              icon: AppIconography.close,
              tooltip: 'Close',
              onPressed: () {},
            ),
            textScale: textScale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(_button), const Size(48, 48));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      }
    }
  });

  testWidgets('label: alone still renders, and the semantic label equals it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        KitIconButton(
          icon: AppIconography.close,
          label: 'Close',
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(_button).label, 'Close');
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets(
    'onPressed: null disables the button: no tap, enabled: false, the hint '
    'is the reason, the glyph is text3 at full alpha',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          KitIconButton(
            icon: AppIconography.delete,
            tooltip: 'Remove header',
            onPressed: null,
            disabledReason: 'Read-only connection',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_button, warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);

      expect(
        tester.getSemantics(_button),
        matchesSemantics(
          label: 'Remove header',
          hint: 'Read-only connection',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      final roles = ThemeRoles.resolve(AppTheme.dark());
      final color = _glyphColor(tester)!;
      expect(color, roles.text3);
      expect(color.a, 1.0);
    },
  );

  testWidgets(
    'working: true shows the spinner, ignores taps and settles after one '
    'pump under reduced motion',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          KitIconButton(
            icon: AppIconography.send,
            tooltip: 'Send',
            working: true,
            onPressed: () => taps++,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('kit-icon-button-working')),
        findsOneWidget,
      );
      await tester.tap(_button, warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      expect(tester.getSemantics(_button).hint, 'Working');
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets(
    'selected true/false exposes toggled semantics; null exposes none',
    (tester) async {
      Future<void> pump(bool? selected) => tester.pumpWidget(
        _host(
          KitIconButton(
            icon: AppIconography.wrapText,
            tooltip: 'Wrap lines',
            selected: selected,
            onPressed: () {},
          ),
        ),
      );

      await pump(true);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_button),
        matchesSemantics(
          label: 'Wrap lines',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: true,
        ),
      );

      await pump(false);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_button),
        matchesSemantics(
          label: 'Wrap lines',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );

      await pump(null);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_button),
        matchesSemantics(
          label: 'Wrap lines',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    },
  );

  testWidgets('destructive paints the glyph danger, never dangerFill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        KitIconButton(
          icon: AppIconography.delete,
          tooltip: 'Delete',
          destructive: true,
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final roles = ThemeRoles.resolve(AppTheme.dark());
    expect(_glyphColor(tester), roles.danger);
    expect(_glyphColor(tester), isNot(roles.dangerFill));
  });

  group('the copy contract (G9)', () {
    testWidgets(
      'copies at tap time, announces Copied once, shows no SnackBar, and '
      'the check reverts after the hold',
      (tester) async {
        var value = 'first render';
        await tester.pumpWidget(_host(KitIconButton.copy(text: () => value)));
        await tester.pumpAndSettle();
        expect(tester.getSemantics(_button).label, 'Copy');

        // The text is read at tap time, not at build time.
        value = 'second render';
        await tester.tap(_button);
        await tester.pump();

        expect(copied(), 'second render');
        expect(announcements, hasLength(1));
        expect((announcements.single['data'] as Map)['message'], 'Copied');
        expect(find.byType(SnackBar), findsNothing);
        expect(
          find.byKey(const ValueKey('kit-icon-button-copied')),
          findsOneWidget,
        );

        await tester.pump(
          KitMotion.copiedHold - const Duration(milliseconds: 1),
        );
        expect(
          find.byKey(const ValueKey('kit-icon-button-copied')),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('kit-icon-button-copied')),
          findsNothing,
        );

        // A repeat tap copies again and restarts the hold.
        await tester.tap(_button);
        await tester.pump();
        expect(announcements, hasLength(2));
        expect(
          find.byKey(const ValueKey('kit-icon-button-copied')),
          findsOneWidget,
        );
        await tester.pump(KitMotion.copiedHold);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('kit-icon-button-copied')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a fake provider key is redacted before it reaches the clipboard',
      (tester) async {
        const raw = 'export KEY=sk-ant-api03-AbCdEfGhIjKlMnOp';
        await tester.pumpWidget(_host(KitIconButton.copy(text: () => raw)));
        await tester.pumpAndSettle();
        await tester.tap(_button);
        await tester.pump();
        expect(copied(), 'export KEY=sk-ant-${KitRedact.mask}');
        expect(copied(), isNot(contains('AbCdEfGhIjKlMnOp')));
      },
    );
  });

  group('reduced motion settles after one pump (G8x)', () {
    final cases = <String, Widget>{
      'default': KitIconButton(
        icon: AppIconography.close,
        tooltip: 'Close',
        onPressed: () {},
      ),
      'disabled': const KitIconButton(
        icon: AppIconography.close,
        tooltip: 'Close',
        onPressed: null,
        disabledReason: 'Not available',
      ),
      'working': KitIconButton(
        icon: AppIconography.send,
        tooltip: 'Send',
        working: true,
        onPressed: () {},
      ),
      'selected': KitIconButton(
        icon: AppIconography.wrapText,
        tooltip: 'Wrap lines',
        selected: true,
        onPressed: () {},
      ),
      'destructive': KitIconButton(
        icon: AppIconography.delete,
        tooltip: 'Delete',
        destructive: true,
        onPressed: () {},
      ),
      'copy': KitIconButton.copy(text: () => 'x'),
    };

    for (final MapEntry(key: name, value: widget) in cases.entries) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(_host(widget, disableAnimations: true));
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse, reason: name);
      });
    }

    testWidgets('copied, under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(KitIconButton.copy(text: () => 'x'), disableAnimations: true),
      );
      await tester.pump();
      await tester.tap(_button);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('kit-icon-button-copied')),
        findsOneWidget,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets(
    'Tab reaches it, the focus ring shows, Enter and Space activate it',
    (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          KitIconButton(
            icon: AppIconography.check,
            tooltip: 'Approve',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      var tabs = 0;
      while (!_focusIn(tester, _button) && tabs < 5) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        tabs++;
      }
      expect(_focusIn(tester, _button), isTrue);
      expect(_focusRingPainted(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 2);
    },
  );
}
