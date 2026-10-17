// KitImageSource.vectorLogo (docs/ux-system/kit-api/KitImage.md).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

const String _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path fill="currentColor" d="M2 2h20v20H2z"/></svg>';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

KitAvatar _avatar(Future<String?> Function() load, {String id = 'acme'}) =>
    KitAvatar(
      name: 'Acme Lab',
      image: KitImageSource.vectorLogo(id: id, load: load),
      decorative: true,
      optionalImage: true,
    );

void main() {
  testWidgets('loading shows initials, loaded shows the logo tinted text1', (
    tester,
  ) async {
    final completer = Completer<String?>();
    await tester.pumpWidget(_app(_avatar(() => completer.future)));
    expect(find.text('AL'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);

    completer.complete(_svg);
    await tester.pump();
    await tester.pump();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final roles = KitTokens.of(tester.element(find.byType(SvgPicture))).roles;
    expect(picture.colorFilter, ColorFilter.mode(roles.text1, BlendMode.srcIn));
  });

  testWidgets('tint follows the theme in dark mode', (tester) async {
    await tester.pumpWidget(
      _app(_avatar(() async => _svg), brightness: Brightness.dark),
    );
    await tester.pump();
    await tester.pump();
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final roles = KitTokens.of(tester.element(find.byType(SvgPicture))).roles;
    expect(picture.colorFilter, ColorFilter.mode(roles.text1, BlendMode.srcIn));
  });

  testWidgets('null (no logo or default sparkle) keeps the initials', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_avatar(() async => null)));
    await tester.pumpAndSettle();
    expect(find.text('AL'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('a throwing loader keeps the initials, no error badge', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        KitAvatar(
          name: 'Acme Lab',
          image: KitImageSource.vectorLogo(
            id: 'acme',
            load: () async => throw StateError('offline'),
          ),
          optionalImage: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AL'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('image')), findsNothing);
    handle.dispose();
  });

  testWidgets('malformed SVG draws nothing and keeps the initials', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_avatar(() async => '<svg><oops')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('a new id reloads', (tester) async {
    final loaded = <String>[];
    Widget build(String id) => _app(
      _avatar(() async {
        loaded.add(id);
        return _svg;
      }, id: id),
    );
    await tester.pumpWidget(build('a'));
    await tester.pump();
    await tester.pumpWidget(build('b'));
    await tester.pump();
    expect(loaded, ['a', 'b']);
  });
}
