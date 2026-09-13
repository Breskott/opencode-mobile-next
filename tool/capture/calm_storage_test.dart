// Synthetic Termux inventory; no device commands or cleanup run here.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/termux_storage_screen.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final light in [true, false]) {
    testWidgets('storage inventory and explicit cache confirmation $light', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = jsonEncode({
        'scanned_at': 1788800000,
        'cleanup_policy': 2,
        'stale': false,
        'total_bytes': 6442450944,
        'categories': [
          {
            'key': 'build_caches',
            'bytes': 734003200,
            'deletable': true,
            'note_key': 'termuxStorageNoteBuildCaches',
            'paths': [
              {
                'path': '/data/data/com.termux/files/home/.npm/_cacache',
                'bytes': 734003200,
              },
            ],
          },
          {
            'key': 'projects',
            'bytes': 2147483648,
            'deletable': false,
            'paths': [
              {
                'path':
                    '/data/data/com.termux/files/home/.oc/projects/shopfront',
                'bytes': 2147483648,
              },
            ],
          },
          {
            'key': 'ai_team',
            'bytes': 419430400,
            'deletable': false,
            'note_key': 'termuxStorageNoteAiTeam',
            'paths': [
              {
                'path': '/data/data/com.termux/files/home/.oc/aiteam',
                'bytes': 419430400,
              },
            ],
          },
          {
            'key': 'shared_caches',
            'bytes': 314572800,
            'deletable': false,
            'note_key': 'termuxStorageNoteSharedCaches',
            'paths': [
              {
                'path': '/data/data/com.termux/files/home/.cache',
                'bytes': 314572800,
              },
            ],
          },
        ],
        'projects': [],
      });
      const channel = MethodChannel('oc/termux');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'runInTermux');
        expect((call.arguments as Map)['script'], contains('storage-status'));
        return {
          'stdout':
              'state=done\n__OC_TOOLS_LOG__\n__OC_TOOLS_JSON__\n$report\n',
          'stderr': '',
          'exitCode': 0,
          'err': -1,
          'errorMessage': '',
        };
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: light ? AppTheme.light() : AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TermuxStorageScreen(
              now: () => DateTime.fromMillisecondsSinceEpoch(1788800120000),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mode = light ? 'light' : 'dark';
      await writePng(
        'docs/qa/calm-storage-2026-09-13/$mode-inventory.png',
        await capturePng(tester, boundary, pixelRatio: 1),
      );
      await tester.tap(
        find.byKey(const Key('termux-storage-cat-build_caches')),
      );
      await tester.pumpAndSettle();
      final clean = find.byKey(const Key('termux-storage-clean-build_caches'));
      await tester.ensureVisible(clean);
      await tester.tap(clean);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-storage-confirm')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await writePng(
        'docs/qa/calm-storage-2026-09-13/$mode-confirmation.png',
        await capturePng(tester, boundary, pixelRatio: 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
