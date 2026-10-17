// Evidence shots for docs/qa/chat-header-declutter-2026-10-14: the chat
// header as the owner saw it, and after. Writes PNGs into $SHOT_OUT (skips
// when unset):
//   SHOT_OUT=/some/dir flutter test test/chat_header_declutter_shots_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import '../tool/capture/fixtures.dart';

const _title = 'Find latest finance hub project in /project';

Widget _header(
  GlobalKey key, {
  required double used,
  required bool after,
  bool collapse = true,
  bool dark = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RepaintBoundary(
    key: key,
    child: Builder(
      builder: (context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Align(
          alignment: Alignment.topCenter,
          child: KitTopBar(
            title: _title,
            exit: KitTopBarExit.back,
            subtitle: after ? null : 'In-app Ubuntu',
            actions: [
              KitAction(
                key: const Key('chat-collapse-all'),
                icon: AppIconography.unfoldLess,
                label: 'Collapse all steps',
                visible: collapse,
                onPressed: () {},
              ),
            ],
            accessory: KitContextRing(used: used, openDetails: () {}),
            accessoryShown: used >= 0.5,
            menu: [KitMenuItem(label: 'Rename', onSelected: () {})],
            scope: KitTopBarScope(
              label: 'FinanceHub3',
              semanticsLabel: 'Project FinanceHub3',
              icon: AppIconography.folderOpen,
              menuLabel: 'Project menu',
              items: [KitMenuItem(label: 'Files', onSelected: () {})],
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final out = Platform.environment['SHOT_OUT'];
  final bytes = await capturePng(tester, key, pixelRatio: 3);
  File('$out/$name.png').writeAsBytesSync(bytes);
}

void main() {
  final out = Platform.environment['SHOT_OUT'];
  setUpAll(loadCaptureFonts);

  testWidgets('shots', skip: out == null, (tester) async {
    tester.view.physicalSize = const Size(412, 150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Directory(out!).createSync(recursive: true);
    final after = Platform.environment['SHOT_AFTER'] == '1';
    final tag = after ? 'after' : 'before';
    final key = GlobalKey();
    await tester.pumpWidget(_header(key, used: 0.04, after: after));
    await tester.pumpAndSettle();
    await _shot(tester, key, '$tag-4-percent');
    if (!after) return;
    await tester.pumpWidget(
      _header(key, used: 0.04, after: after, collapse: false),
    );
    await tester.pumpAndSettle();
    await _shot(tester, key, '$tag-4-percent-no-open-steps');
    await tester.pumpWidget(
      _header(key, used: 0.62, after: after, collapse: false),
    );
    await tester.pumpAndSettle();
    await _shot(tester, key, '$tag-62-percent');
    // The ring arriving: frames of the cross-over.
    await tester.pumpWidget(
      _header(key, used: 0.04, after: after, collapse: false),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _header(key, used: 0.62, after: after, collapse: false),
    );
    await tester.pump();
    var at = 0;
    for (final ms in [40, 50, 60, 100]) {
      await tester.pump(Duration(milliseconds: ms));
      at += ms;
      await _shot(tester, key, '$tag-ring-frame-${at}ms');
    }
  });
}
