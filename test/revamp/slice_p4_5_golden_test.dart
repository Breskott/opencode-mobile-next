// Golden renders of slice-P4.5's page: New conversation's chooser
// (new-conversation-sheet) with every way a server can support (Solo, Team
// while the team is off, a separate copy, a cloud machine), the last used
// way marked. Phone 412x915 and one wide window (1280x800), dark and light
// (owner decision 2026-09-27: no Arabic), with the app's real fonts at
// DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p4_5_golden_test.dart
// and look at every changed image before committing it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/new_conversation_sheet.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

const _options = NewConversationOptions(
  project: 'shopfront',
  team: true,
  separateCopy: true,
  clouds: [
    NewConversationCloud(id: 'ws-1', name: 'feature-login', status: 'Ready'),
  ],
);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    for (final size in [_phone, _wide]) {
      testWidgets('new conversation chooser (${light ? 'light' : 'dark'}, '
          '$size)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final boundary = GlobalKey();
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: captureTheme(light: light),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: const Scaffold(body: SizedBox.expand()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          unawaited(
            showNewConversationSheet(
              tester.element(find.byType(Scaffold)),
              options: _options,
              remembered: const NewConversationChoice.solo(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile(
              'goldens/${_name('work_new_conversation_sheet_all', size, light)}.png',
            ),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
