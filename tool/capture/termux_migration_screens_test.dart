// Renders of the move from Termux to the in-app server (slice-migration-ui):
// every state of the page, at the phone (412x915) and a wide window
// (1280x800), dark and light, with the app's real fonts, over the real
// controller and fakes (test/support/termux_migration_fakes.dart).
//
//   flutter test --concurrency=1 tool/capture/termux_migration_screens_test.dart
//
// Output: docs/qa/slice-migration-gaps-ui-2026-09-29/after-<state>-<size>-<mode>.png
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/termux_migration.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/termux_migration_screen.dart';

import '../../test/revamp/screen_phone_1_fixtures.dart';
import '../../test/support/termux_migration_fakes.dart';
import 'fixtures.dart';

const _out = 'docs/qa/slice-migration-gaps-ui-2026-09-29';

enum _State {
  review,
  reviewShort,
  stopping,
  discardConfirm,
  progress,
  stoppedLeaving,
  needsSpace,
  needsBuiltin,
  termuxUnreachable,
  failed,
  unfinished,
  done,
}

const _wideStates = {_State.review, _State.reviewShort, _State.done};

ServerProfile _termux() => ServerProfile(
  id: migrationSource,
  name: 'This phone',
  baseUrl: TermuxBridge.managedServerUrl,
  password: 'synthetic-test-secret',
);

Future<void> _frames(WidgetTester tester, {int count = 15}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _frames(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  for (final state in _State.values) {
    for (final size in [phoneSize, wideSize]) {
      if (size == wideSize && !_wideStates.contains(state)) continue;
      for (final light in [false, true]) {
        final mode = light ? 'light' : 'dark';
        final dims = '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('after ${state.name} $dims $mode', (tester) async {
          final fixture = MigrationFixture();
          switch (state) {
            case _State.needsBuiltin:
              fixture.archives.installed = false;
            case _State.termuxUnreachable:
              fixture.transport.inspectError = const TermuxMigrationException(
                TermuxMigrationFailure.unavailable,
              );
            case _State.reviewShort:
              fixture.freeBytes = 900 * 1024 * 1024;
            case _State.unfinished || _State.discardConfirm:
              fixture.journal.saveUnfinished([
                TermuxMigrationItem.projects,
                TermuxMigrationItem.config,
                TermuxMigrationItem.gitConfig,
              ]);
            case _State.done:
              // Reopened later, offline: the backend's own record and names.
              fixture.journal.saveUnfinished(
                [
                  TermuxMigrationItem.projects,
                  TermuxMigrationItem.config,
                  TermuxMigrationItem.gitConfig,
                ],
                done: true,
                configCopied: true,
              );
              fixture.archives.providers = ['Anthropic', 'OpenAI'];
            default:
              break;
          }
          final boundary = GlobalKey();
          await pumpPhone(
            tester,
            size: size,
            light: light,
            boundary: boundary,
            profiles: [_termux()],
            home: TermuxMigrationScreen(
              source: _termux(),
              owner: fixture.owner,
              setUpBuiltin: (_, _) async {},
              openProviders: (_) async {},
              openTermux: () async {},
            ),
          );
          await _frames(tester);
          switch (state) {
            case _State.progress:
              fixture.transport.copyGate = Completer<void>();
              await _tap(tester, 'migration-switch-config');
              await _tap(tester, 'migration-start');
            case _State.stoppedLeaving:
              fixture.transport.copyGate = Completer<void>();
              await _tap(tester, 'migration-start');
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.paused,
              );
              await _frames(tester);
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
              await _frames(tester);
            case _State.needsSpace:
              fixture.freeBytes = 900 * 1024 * 1024;
              await _tap(tester, 'migration-start');
            case _State.failed:
              fixture.transport.packError = const TermuxMigrationException(
                TermuxMigrationFailure.sourceChanged,
              );
              await _tap(tester, 'migration-start');
            case _State.reviewShort:
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -5000),
              );
            case _State.stopping:
              fixture.transport
                ..packGate = Completer<void>()
                ..holdAfterCancel = true;
              await _tap(tester, 'migration-start');
              await _tap(tester, 'migration-stop');
              await _tap(tester, 'migration-stop-confirm');
            case _State.discardConfirm:
              await _tap(tester, 'migration-discard');
            default:
              break;
          }
          await _frames(tester);
          expect(tester.takeException(), isNull);
          await writePng(
            '$_out/after-${state.name}-$dims-$mode.png',
            await capturePng(tester, boundary, pixelRatio: 1),
          );
          await tester.pump(const Duration(minutes: 1));
          await fixture.close();
          await unmountPhone(tester);
        });
      }
    }
  }
}
