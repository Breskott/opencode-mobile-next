// screen-servers-1: the Servers screen, its welcome, the remove sheet, the
// server editor and its discard sheet, rebuilt from kit parts
// (docs/qa/revamp-screen-servers-1/README.md).
//
// Behaviour: a stored password is never put back into a field and a save
// keeps it; Replace takes a new one; the remove sheet says what is lost,
// what is kept and what shows next; the discard guard keeps editing by
// default; a saved server's actions are on long-press (KIT-28); the loaded
// list lays out at every LAY-4 overflow width.
//
// Goldens: TEST-20 names, phone 412x915 and 1280x800, dark and light (owner
// decision 2026-09-27). Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_servers_1_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';

import '../../tool/capture/fixtures.dart';
import '../support/server_editor.dart';
import '../support/setup_capture_preferences.dart';
import 'shared_servers_1_fixtures.dart';

/// A store the editor can write to; the first saved server is active only
/// when [active] says so.
class _Store extends ProfileStore {
  _Store({required super.prefs, required List<ServerProfile> seeded})
    : _profiles = [...seeded];

  final List<ServerProfile> _profiles;
  final upserts = <ServerProfile>[];

  @override
  List<ServerProfile> get profiles => List.unmodifiable(_profiles);

  @override
  String? get activeId => null;

  @override
  Future<void> upsert(ServerProfile profile) async {
    upserts.add(profile);
    final at = _profiles.indexWhere((p) => p.id == profile.id);
    if (at < 0) {
      _profiles.add(profile);
    } else {
      _profiles[at] = profile;
    }
  }
}

const _storedPassword = 'fixture-stored-password-not-live';

/// A capture controller whose connect succeeds without a network, so Add
/// server reaches its ready step.
class _ConnectingController extends CaptureController {
  _ConnectingController(super.store);

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    api = OpenCodeApi(baseUrl: profile.baseUrl);
  }
}

List<ServerProfile> _seed() => [
  ServerProfile(
    id: 'laptop',
    name: 'Laptop',
    baseUrl: 'https://laptop.example.net',
    password: _storedPassword,
    flavor: ServerFlavor.v2,
    serverVersion: '2.0.10',
  ),
  ServerProfile(
    id: 'studio',
    name: 'Studio Mac',
    baseUrl: 'https://studio.example.net:4096',
    flavor: ServerFlavor.v1,
    serverVersion: '1.18.29',
  ),
  ServerProfile(
    id: 'codex',
    name: 'Codex box',
    baseUrl: 'ws://codex.example:4500',
    backend: ServerBackend.codex,
    codexDirectory: '/work/shopfront',
  ),
];

void _mockPlatform(WidgetTester tester) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const termux = MethodChannel('oc/termux');
  const tailscale = MethodChannel('oc/tailscale');
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    tailscale,
    (call) async => call.method == 'check' ? 'installed' : true,
  );
  messenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  messenger.setMockMethodCallHandler(termux, (call) async {
    if (call.method == 'getCapabilities') return {'installed': false};
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(secure, null);
    messenger.setMockMethodCallHandler(termux, null);
    messenger.setMockMethodCallHandler(tailscale, null);
  });
}

Future<void> _settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Mounts the Servers screen over [seeded] at [size]. Returns the store and
/// what to call when the test is done.
Future<(_Store, Future<void> Function())> _mount(
  WidgetTester tester, {
  required GlobalKey boundary,
  List<ServerProfile>? seeded,
  bool light = false,
  Size size = const Size(412, 915),
}) async {
  _mockPlatform(tester);
  debugPlatformCapabilities = const PlatformCapabilities.android();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await setupCapturePreferences();
  final store = _Store(prefs: prefs, seeded: seeded ?? _seed());
  final controller = _ConnectingController(store);
  await tester.pumpWidget(
    captureApp(
      home: const ServersScreen(),
      boundaryKey: boundary,
      controller: controller,
      store: store,
      light: light,
      routes: {
        '/home': (_) => const SizedBox.shrink(),
        '/guide': (_) => const SizedBox.shrink(),
      },
    ),
  );
  await _settle(tester);
  return (
    store,
    () async {
      debugPlatformCapabilities = null;
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump();
    },
  );
}

Future<void> _openRowMenu(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('server-row-$id'));
  await tester.ensureVisible(row);
  await _settle(tester, frames: 3);
  await tester.longPress(row);
  await _settle(tester, frames: 6);
}

Future<void> _openEditor(WidgetTester tester, String id) async {
  await _openRowMenu(tester, id);
  await tester.tap(find.text('Edit').last);
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  group('behaviour', () {
    testWidgets('every server is one list, most urgent first, state in words', (
      tester,
    ) async {
      _mockPlatform(tester);
      debugPlatformCapabilities = const PlatformCapabilities.android();
      addTearDown(() => debugPlatformCapabilities = null);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await setupCapturePreferences();
      final store = SwitcherStore(prefs: prefs);
      // Lab waits on the person, Laptop is working; Work and Home desk have
      // nothing going on and keep the order they were saved in.
      final controller = SwitcherController(
        store,
        snapshots: {
          'lab': snapshot('lab', waiting: 1),
          'laptop': snapshot('laptop', running: 2),
        },
      );
      await tester.pumpWidget(
        captureApp(
          home: const ServersScreen(),
          boundaryKey: GlobalKey(),
          controller: controller,
          store: store,
        ),
      );
      await _settle(tester);
      try {
        double top(String id) =>
            tester.getTopLeft(find.byKey(ValueKey('server-row-$id'))).dy;
        final order = [top('lab'), top('laptop'), top('work'), top('locked')];
        expect(order, [...order]..sort());
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('server-row-lab')),
            matching: find.textContaining('Needs you', findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('server-row-laptop')),
            matching: find.textContaining('2 working', findRichText: true),
          ),
          findsOneWidget,
        );
        // One list: no group label, no second panel of ways in, no
        // attention page or guide in the bar, no demo beside Add server.
        expect(find.byKey(const ValueKey('servers-list')), findsOneWidget);
        expect(find.text('Other ways to connect'), findsNothing);
        expect(find.byKey(const ValueKey('servers-attention')), findsNothing);
        expect(find.byKey(const ValueKey('servers-guide')), findsNothing);
        expect(find.byKey(const ValueKey('servers-try-demo')), findsNothing);
        expect(find.byKey(const ValueKey('servers-add')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await tester.pump();
      }
    });

    testWidgets('Add server offers the other ways in, after its main path', (
      tester,
    ) async {
      final (_, done) = await _mount(tester, boundary: GlobalKey());
      try {
        await tester.tap(find.byKey(const ValueKey('servers-add')));
        await _settle(tester);
        final ways = find.byKey(const ValueKey('server-editor-other-ways'));
        await tester.ensureVisible(ways);
        await _settle(tester, frames: 3);
        expect(
          find.descendant(
            of: ways,
            matching: find.byKey(const ValueKey('quick-add-phone-card')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: ways,
            matching: find.byKey(
              const ValueKey('server-editor-external-agents'),
            ),
          ),
          findsOneWidget,
        );
        // Below the kinds it chooses between.
        expect(
          tester.getTopLeft(ways).dy,
          greaterThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('server-backend-paseo')))
                .dy,
          ),
        );
      } finally {
        await done();
      }
    });

    testWidgets('a saved server\'s actions open on long-press, no ⋮ button', (
      tester,
    ) async {
      final (_, done) = await _mount(tester, boundary: GlobalKey());
      try {
        expect(find.byKey(const ValueKey('kit-row-menu-button')), findsNothing);
        await _openRowMenu(tester, 'studio');
        expect(find.text('Connect'), findsWidgets);
        expect(find.text('Edit'), findsWidgets);
        expect(find.text('Remove'), findsWidgets);
      } finally {
        await done();
      }
    });

    testWidgets('a stored password is held, never shown, and kept on save', (
      tester,
    ) async {
      final (store, done) = await _mount(tester, boundary: GlobalKey());
      try {
        await _openEditor(tester, 'laptop');
        // The field says Saved and offers Replace; no editable holds the
        // stored value and the value is nowhere on screen.
        expect(
          find.byKey(const ValueKey('server-password-replace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('server-password-field')),
          findsNothing,
        );
        expect(find.textContaining(_storedPassword), findsNothing);
        final save = find.byKey(const ValueKey('save-server-profile'));
        await tester.tap(save);
        await _settle(tester);
        expect(store.upserts, hasLength(1));
        expect(store.upserts.single.password, _storedPassword);
      } finally {
        await done();
      }
    });

    testWidgets('Replace takes a new password', (tester) async {
      final (store, done) = await _mount(tester, boundary: GlobalKey());
      try {
        await _openEditor(tester, 'laptop');
        final replace = find.byKey(const ValueKey('server-password-replace'));
        await tester.ensureVisible(replace);
        await tester.tap(replace);
        await _settle(tester, frames: 6);
        final field = find.byKey(const ValueKey('server-password-field'));
        expect(field, findsOneWidget);
        await tester.enterText(field, 'fixture-new-password');
        tester.testTextInput.hide();
        await _settle(tester, frames: 3);
        await tester.tap(find.byKey(const ValueKey('save-server-profile')));
        await _settle(tester);
        expect(store.upserts.single.password, 'fixture-new-password');
      } finally {
        await done();
      }
    });

    testWidgets('closing with unsaved changes asks; Keep editing stays', (
      tester,
    ) async {
      final (_, done) = await _mount(tester, boundary: GlobalKey());
      try {
        await _openEditor(tester, 'studio');
        await tester.enterText(
          find.byKey(const ValueKey('server-url-field')),
          'https://studio.example.net:4097',
        );
        tester.testTextInput.hide();
        await _settle(tester, frames: 3);
        await tester.tap(find.byKey(const ValueKey('server-editor-close')));
        await _settle(tester);
        expect(find.text('Discard server changes?'), findsOneWidget);
        expect(find.text('Keep editing'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('server-profile-editor')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('server-editor-close')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('server-discard-confirm')));
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('server-profile-editor')),
          findsNothing,
        );
      } finally {
        await done();
      }
    });

    testWidgets('the remove sheet says what goes and what the server keeps', (
      tester,
    ) async {
      final (_, done) = await _mount(tester, boundary: GlobalKey());
      try {
        await _openRowMenu(tester, 'studio');
        await tester.tap(find.text('Remove').last);
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('remove-server-sheet-studio')),
          findsOneWidget,
        );
        expect(find.text('Remove Studio Mac?'), findsOneWidget);
        expect(
          find.text('Nothing is deleted on the server or at your AI providers'),
          findsOneWidget,
        );
        // Not the server in use: nothing to say about what shows next.
        expect(
          find.byKey(const ValueKey('remove-server-active-next')),
          findsNothing,
        );
        await tester.tap(find.text('Cancel'));
        await _settle(tester);
        expect(find.byKey(const ValueKey('server-row-studio')), findsOneWidget);
      } finally {
        await done();
      }
    });

    for (final width in <double>[320, 360, 412, 600, 800, 840, 1280, 1600]) {
      testWidgets('the loaded list lays out at ${width.toInt()} dp', (
        tester,
      ) async {
        final (_, done) = await _mount(
          tester,
          boundary: GlobalKey(),
          size: Size(width, 900),
        );
        try {
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('servers-add')), findsOneWidget);
        } finally {
          await done();
        }
      });
    }
  });

  group('goldens', () {
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';

      Future<void> shoot(
        WidgetTester tester,
        String name, {
        List<ServerProfile>? seeded,
        Size size = const Size(412, 915),
        Future<void> Function()? then,
      }) async {
        final boundary = GlobalKey();
        final (_, done) = await _mount(
          tester,
          boundary: boundary,
          seeded: seeded,
          light: light,
          size: size,
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
        try {
          await then?.call();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('goldens/${name}_$mode.png'),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
          await done();
        }
      }

      testWidgets('servers loaded · $mode', (tester) async {
        await shoot(tester, 'servers_servers_loaded');
      });

      testWidgets('servers loaded 1280x800 · $mode', (tester) async {
        await shoot(
          tester,
          'servers_servers_loaded_1280x800',
          size: const Size(1280, 800),
        );
      });

      testWidgets('welcome · $mode', (tester) async {
        await shoot(tester, 'servers_servers_welcome_first_run', seeded: []);
      });

      testWidgets('remove sheet · $mode', (tester) async {
        await shoot(
          tester,
          'servers_servers_remove_server_sheet_confirm',
          then: () async {
            await _openRowMenu(tester, 'studio');
            await tester.tap(find.text('Remove').last);
            await _settle(tester);
          },
        );
      });

      testWidgets('editor, saved password · $mode', (tester) async {
        await shoot(
          tester,
          'servers_profile_editor_edit',
          then: () => _openEditor(tester, 'laptop'),
        );
      });

      Future<void> openAdd(WidgetTester tester) async {
        await tester.tap(find.byKey(const ValueKey('servers-add')));
        await _settle(tester);
      }

      /// Add server on its connect step for OpenCode with an address typed
      /// and Save & connect tapped; [probe] answers the check.
      Future<void> saveTyped(
        WidgetTester tester,
        Future<ServerProbeResult> Function() probe,
      ) async {
        final previous = serverProbe;
        serverProbe = ({required baseUrl, username, password}) => probe();
        addTearDown(() => serverProbe = previous);
        await openAdd(tester);
        await chooseServerKind(tester);
        await openServerManualAddress(tester);
        await tester.enterText(
          find.byKey(const ValueKey('server-url-field')),
          'https://build.example.net',
        );
        tester.testTextInput.hide();
        await _settle(tester, frames: 3);
        await tester.tap(find.byKey(const ValueKey('save-server-profile')));
      }

      testWidgets('editor, add · $mode', (tester) async {
        await shoot(
          tester,
          'servers_profile_editor_add_opencode',
          then: () async {
            await openAdd(tester);
            await chooseServerKind(tester);
          },
        );
      });

      // P3.9: Add server in steps (docs/qa/slice-P3.9-2026-09-27).
      for (final size in const [Size(412, 915), Size(1280, 800)]) {
        final suffix = size.width > 1000 ? '_1280x800' : '';
        testWidgets('add server, what runs there $suffix· $mode', (
          tester,
        ) async {
          await shoot(
            tester,
            'servers_addserver_kind$suffix',
            size: size,
            then: () => openAdd(tester),
          );
        });

        testWidgets('add server, ready $suffix· $mode', (tester) async {
          await shoot(
            tester,
            'servers_addserver_ready$suffix',
            size: size,
            then: () async {
              await saveTyped(
                tester,
                () async => const ServerProbeResult.success(
                  '2.0.10',
                  flavor: ServerFlavor.v2,
                ),
              );
              await _settle(tester, frames: 30);
            },
          );
        });
      }

      // slice-close-servers: a refused check said plainly under the
      // address field; Codex's one-line command; a row's Details.
      for (final size in const [Size(412, 915), Size(1280, 800)]) {
        final suffix = size.width > 1000 ? '_1280x800' : '';
        testWidgets('add server, refused $suffix· $mode', (tester) async {
          await shoot(
            tester,
            'servers_addserver_refused$suffix',
            size: size,
            then: () async {
              await saveTyped(
                tester,
                () async => const ServerProbeResult.failure(
                  'The connection was refused. Is opencode serve running on '
                  'that host and port?',
                  suggestsMissingServer: true,
                ),
              );
              await _settle(tester, frames: 20);
            },
          );
        });

        testWidgets('add server, Codex $suffix· $mode', (tester) async {
          await shoot(
            tester,
            'servers_addserver_codex$suffix',
            size: size,
            then: () async {
              await openAdd(tester);
              await chooseServerKind(tester, kind: 'codex');
            },
          );
        });

        testWidgets('server row details $suffix· $mode', (tester) async {
          await shoot(
            tester,
            'servers_row_details$suffix',
            size: size,
            then: () async {
              await _openRowMenu(tester, 'studio');
              await tester.tap(find.text('Details').last);
              await _settle(tester);
            },
          );
        });
      }

      testWidgets('add server, Tailscale step · $mode', (tester) async {
        await shoot(
          tester,
          'servers_addserver_tailscale',
          then: () async {
            await openAdd(tester);
            final row = find.byKey(const ValueKey('welcome-tailscale-card'));
            await tester.ensureVisible(row);
            await _settle(tester, frames: 3);
            await tester.tap(row);
            await _settle(tester);
          },
        );
      });

      testWidgets('add server, slow check · $mode', (tester) async {
        final pending = Completer<ServerProbeResult>();
        await shoot(
          tester,
          'servers_addserver_slowcheck',
          then: () async {
            await saveTyped(tester, () => pending.future);
            await tester.pump(slowCheckAfter);
            await _settle(tester, frames: 10);
          },
        );
      });

      testWidgets('discard sheet · $mode', (tester) async {
        await shoot(
          tester,
          'servers_profile_editor_discard_sheet_confirm',
          then: () async {
            await _openEditor(tester, 'studio');
            await tester.enterText(
              find.byKey(const ValueKey('server-url-field')),
              'https://studio.example.net:4097',
            );
            tester.testTextInput.hide();
            await _settle(tester, frames: 3);
            await tester.tap(find.byKey(const ValueKey('server-editor-close')));
            await _settle(tester);
          },
        );
      });
    }
  });
}
