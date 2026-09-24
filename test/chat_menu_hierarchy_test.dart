import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

import '../tool/capture/fixtures.dart'
    show capturePng, captureTheme, loadCaptureFonts;

const _menu = SessionMenuSheet(
  reasoningExpanded: false,
  timestampsVisible: false,
  todosAvailable: true,
  changesAvailable: true,
  forkAvailable: true,
  revertAvailable: true,
  compactAvailable: true,
  terminalAvailable: true,
  subagentsAvailable: true,
  reverted: false,
  shared: false,
  sharingAvailable: true,
  resultsAvailable: true,
  notesAvailable: true,
  skillsAvailable: true,
  continueOnComputerAvailable: true,
  continueOnPhoneAvailable: true,
);

void main() {
  testWidgets(
    'ordinary destinations precede secondary groups and actions remain reachable',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: _menu)));
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Find in conversation'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Retry last prompt'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.tap(find.text('Display and context'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('session-view-thinking')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('session-view-thinking')),
            )
            .value,
        isTrue,
      );
      // Toggling a view preference keeps the menu open.
      expect(find.byType(SessionMenuSheet), findsOneWidget);
      await tester.tap(find.text('Display and context'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation actions'));
      await tester.pumpAndSettle();
      for (final title in [
        'Retry last prompt',
        'Revert last prompt',
        'Fork conversation',
        'Compact context',
        'Share conversation',
        'Run shell command',
        'Commands',
        'Refresh messages',
        'Continue on computer',
        'Open on another phone',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text(title).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320dp and 2.5x LTR/RTL menu groups remain reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureDir = Platform.environment['E7_CHAT_CAPTURE_DIR'];
    if (captureDir != null) await loadCaptureFonts();
    for (final rtl in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.5)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
            ),
            home: const Scaffold(body: _menu),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (captureDir != null) {
        final bytes = await capturePng(tester, boundary);
        File(
          '$captureDir/menu-${rtl ? 'rtl' : 'ltr'}-320-2.5x.png',
        ).writeAsBytesSync(bytes);
      }
      await tester.ensureVisible(find.text('Conversation actions'));
      await tester.tap(find.text('Conversation actions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Refresh messages'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh messages').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Open on another phone'));
      await tester.pumpAndSettle();
      expect(find.text('Open on another phone').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
