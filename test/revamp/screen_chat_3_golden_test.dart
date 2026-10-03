// Golden renders of screen-chat-3's page (wave 2b): Export conversation
// (map page session-export) in its states: the choice, the unredacted
// warning, downloading, saved, a file the device could not write, and a
// server without the complete copy. Phone 412x915 and one wide window
// (1280x800) for the choice, dark and light (owner decision 2026-09-27: no
// Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_chat_3_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/screens/session_export_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

class _Export extends ProductRepository implements SessionExportGateway {
  _Export({this.supported = true});

  final bool supported;
  Completer<void>? wait;

  @override
  bool get sessionExportSupported => supported;

  @override
  Future<Uint8List> exportSession(
    String id, {
    bool sanitize = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    onReceiveProgress?.call(4, 10);
    await wait?.future;
    return Uint8List.fromList(utf8.encode('{"data":{"messages":[]}}'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;
}

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
const _saveJson = 'Save complete conversation';

String _name(String shot, Size size, bool light) => [
  'chat_session_export_$shot',
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<_Export> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  Size size = _phone,
  bool supported = true,
  SaveSessionExport? save,
  Future<void> Function(_Export gateway)? act,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final gateway = _Export(supported: supported);
  final controller = _Controller(
    ProfileStore(prefs: await SharedPreferences.getInstance()),
  )..repository = gateway;
  addTearDown(controller.dispose);
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
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: SessionExportScreen(
            controller: controller,
            sessionID: 'ses_preview',
            markdown: () => Uint8List.fromList(utf8.encode('# Transcript')),
            saveFile: save ?? (_, _, _) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) {
      await act(gateway);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
    gateway.wait?.complete();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
  return gateway;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final light in [false, true]) {
    final tone = light ? 'light' : 'dark';

    group('session export ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('choice ${size.width.toInt()}', (tester) async {
          await _shot(tester, 'choice', light: light, size: size);
        });
      }

      testWidgets('unredacted', (tester) async {
        await _shot(
          tester,
          'unredacted',
          light: light,
          act: (_) async {
            await tester.tap(find.byType(KitSwitchRow));
          },
        );
      });

      testWidgets('downloading', (tester) async {
        await _shot(
          tester,
          'downloading',
          light: light,
          settle: false,
          act: (gateway) async {
            gateway.wait = Completer<void>();
            await tester.tap(find.text(_saveJson));
            await tester.pump();
          },
        );
      });

      testWidgets('saved', (tester) async {
        await _shot(
          tester,
          'saved',
          light: light,
          save: (_, _, _) async => Uri.file('/backup.json'),
          act: (_) async {
            await tester.tap(find.text(_saveJson));
          },
        );
      });

      testWidgets('save failed', (tester) async {
        await _shot(
          tester,
          'save_failed',
          light: light,
          save: (_, _, _) async => throw const FileSystemException('denied'),
          act: (_) async {
            await tester.tap(find.text(_saveJson));
          },
        );
      });

      testWidgets('no complete copy', (tester) async {
        await _shot(tester, 'unsupported', light: light, supported: false);
      });
    });
  }
}
