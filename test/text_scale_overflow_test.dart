// Text scale and overflow (A11Y-2, docs/ux-system/revamp/STANDARDS.md §18):
//
// 1. The critical flows at AppTheme.maxTextScale (2.5) on a 360x740 phone.
// 2. Gate G6, the kit overflow matrix (A11Y-2, LAY-4, KIT-24; absolute):
//    every part lib/ui/kit/kit.dart exports is found by reading its exports,
//    and every scene of it in test/kit/kit_overflow_scenes.dart is pumped at
//    the LAY-4 overflow sizes, at text 1.0, 1.3 and 2.0, left to right and
//    right to left, with tester.takeException() null each time. A part with
//    no scene, or a scene naming a part the kit no longer exports, fails.
//    KitSegmented, once it exists, must stack its KitChoiceRows when its
//    labels do not fit. Kit units add scenes there, never here (PROC-13).
import 'support/complete_message_history.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/chat/permission_sheet.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/form_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show captureTheme;
import 'goldens/kit/kit_gallery.dart' show loadKitGalleryFonts;
import 'kit/kit_overflow_scenes.dart';

/// UX-P0-05 / audit rec #5: the global clamp no longer caps accessibility at
/// 2.0x, so the critical flows have to survive the new 2.5x ceiling. Each
/// case renders a flagship surface on a small phone at 2.5x and fails on any
/// layout exception — RenderFlex overflow included.
const _textScale = AppTheme.maxTextScale;

/// A 360x740 logical phone, the narrowest shape the product supports.
const _phone = Size(360, 740);

class _Api extends OpenCodeApi with CompleteMessageHistory {
  _Api() : super(baseUrl: 'http://localhost');

  @override
  Future<List<Session>> sessions() async => [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  Future<List<MessageWithParts>> messages(String id) async => [];

  @override
  Future<Session> session(String id) async => Session(id: id);

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [];

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.23');
}

class _Repository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async => [];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => [];

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller({
  bool withProfile = true,
  bool withRepository = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (withProfile) ...{
      'oc.profiles': jsonEncode([
        {
          'id': 'profile-1',
          'name': 'Workstation on the LAN',
          'baseUrl': 'http://localhost:4096',
          'username': '',
        },
      ]),
      'oc.activeProfile': 'profile-1',
    },
  });
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  await store.load();
  final controller = ConnectionController(store)
    ..api = _Api()
    ..status = StreamStatus.connected;
  if (withRepository) controller.repository = _Repository();
  return controller;
}

/// Pumps [child] at 2.5x on a 360dp phone and returns once settled.
Future<void> _pumpScaled(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = _phone * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _phone;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: _phone,
        textScaler: TextScaler.linear(_textScale),
      ),
      child: child,
    ),
  );
  // Localization delegates resolve asynchronously and several screens load
  // through a future, so give the tree a handful of frames to reach its
  // steady state before the layout is judged.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Widget _scoped(ConnectionController conn, Widget home) => ProviderScope(
  overrides: [
    connProvider.overrideWithValue(conn),
    bootstrapProvider.overrideWithValue(AppBootstrap(conn.store)),
  ],
  child: _app(home),
);

// ---------------------------------------------------------------------------
// Gate G6: the kit overflow matrix.

/// LAY-4's overflow widths (320, 360, 412, 600, 800, 840, 1280, 1600) at a
/// plausible height for each, plus the 915x412 phone in landscape.
const _overflowSizes = <Size>[
  Size(320, 640),
  Size(360, 740),
  Size(412, 915),
  Size(600, 960),
  Size(800, 1280),
  Size(840, 1180),
  Size(1280, 800),
  Size(1600, 1000),
  Size(915, 412),
];

const _overflowScales = <double>[1.0, 1.3, 2.0];

const _kitDir = 'lib/ui/kit';

/// Superclasses that make a kit class a part, besides names ending in
/// `Widget` and other kit parts.
const _widgetBases = {'InheritedNotifier', 'InheritedModel', 'InheritedTheme'};

final _exportPattern = RegExp(r"export\s+'([^']+)'(?:\s+show\s+([^;]+))?;");
final _partPattern = RegExp(r"^part\s+'([^']+)';", multiLine: true);
final _classPattern = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface|mixin)\s+)*class\s+'
  r'([A-Z]\w*)(?:<[^{]*?>)?\s+extends\s+(\w+)',
  multiLine: true,
);
final _showKitPattern = RegExp(
  r'^(?:Future<[^\n]*?>|void)\s+(showKit\w+)\s*(?:<[^>(]*>)?\s*\(',
  multiLine: true,
);

/// The kit's parts, read from `kit.dart`'s exports (following `part` files
/// and re-exports, honouring `show`): every public widget class and every
/// `showKit…` function.
Set<String> kitManifest({String kitFile = '$_kitDir/kit.dart'}) {
  final supers = <String, String>{};
  final functions = <String>{};

  // Returns the public names [file] contributes, filtered by [show].
  Set<String> scan(File file, Set<String>? show, Set<String> seen) {
    final path = file.absolute.uri.normalizePath().toFilePath();
    if (!seen.add(path)) return {};
    final source = file.readAsStringSync();
    final texts = [
      source,
      for (final m in _partPattern.allMatches(source))
        File.fromUri(file.absolute.uri.resolve(m[1]!)).readAsStringSync(),
    ];
    final names = <String>{};
    for (final text in texts) {
      for (final m in _classPattern.allMatches(text)) {
        supers[m[1]!] = m[2]!;
        names.add(m[1]!);
      }
      for (final m in _showKitPattern.allMatches(text)) {
        functions.add(m[1]!);
        names.add(m[1]!);
      }
    }
    for (final m in _exportPattern.allMatches(source)) {
      if (m[1]!.startsWith('package:') || m[1]!.startsWith('dart:')) continue;
      final shown = m[2]?.split(',').map((n) => n.trim()).toSet();
      names.addAll(
        scan(File.fromUri(file.absolute.uri.resolve(m[1]!)), shown, seen),
      );
    }
    return show == null ? names : names.intersection(show);
  }

  final exported = scan(File(kitFile), null, {});
  bool isWidget(String name, [int depth = 0]) {
    final base = supers[name];
    if (base == null || depth > 8) return false;
    return base.endsWith('Widget') ||
        _widgetBases.contains(base) ||
        isWidget(base, depth + 1);
  }

  return {
    for (final name in exported)
      if (functions.contains(name) || isWidget(name)) name,
  };
}

/// Where the ratchet lives: scene id to the combinations that overflowed
/// when the gate was built. It may only shrink; kit units fix, never add.
const _baselinePath = 'test/text_scale_overflow_baseline.json';

Map<String, Set<String>> _loadOverflowBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: {for (final combo in value as List) combo as String},
  };
}

String _encodeOverflowBaseline(Map<String, Set<String>> baseline) {
  final ids = baseline.keys.where((id) => baseline[id]!.isNotEmpty).toList()
    ..sort();
  return '${const JsonEncoder.withIndent('  ').convert({for (final id in ids) id: (baseline[id]!.toList()..sort())})}\n';
}

String _sizeName(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

Widget _kitApp({
  required Key key,
  required double scale,
  required bool rtl,
  required Widget Function(BuildContext context) home,
}) => KeyedSubtree(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: captureTheme(),
    locale: Locale(rtl ? 'ar' : 'en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: Builder(builder: home)),
  ),
);

bool _isChoiceRow(Widget widget) =>
    widget.runtimeType.toString() == 'KitChoiceRow';

/// Pumps [scene] at every size, scale and direction and returns, for each
/// combination that threw (an overflow included) or broke KIT-24, its first
/// line, keyed by the combination ("800x1280 text 2.0 ltr").
Future<Map<String, String>> _pumpMatrix(
  WidgetTester tester,
  KitOverflowScene scene,
) async {
  final failures = <String, String>{};
  addTearDown(tester.view.reset);
  for (final size in _overflowSizes) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    for (final scale in _overflowScales) {
      for (final rtl in [false, true]) {
        final where = '${_sizeName(size)} text $scale ${rtl ? 'rtl' : 'ltr'}';
        final copy = KitSceneCopy(rtl: rtl);
        BuildContext? opener;
        await tester.pumpWidget(
          _kitApp(
            key: ValueKey(where),
            scale: scale,
            rtl: rtl,
            home: (context) {
              if (scene.open != null) {
                opener = context;
                return const SizedBox.expand();
              }
              final part = scene.build!(context, copy);
              return switch (scene.host) {
                KitOverflowHost.list => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [part],
                ),
                _ => part,
              };
            },
          ),
        );
        if (scene.open != null) {
          unawaited(Future.sync(() => scene.open!(opener!, copy)));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        final error = tester.takeException();
        if (error != null) {
          failures[where] = '$error'.split('\n').first;
          continue;
        }
        if (scene.labelsOverflow && scale >= 2.0 && size.width <= 360) {
          final stacked = find.byWidgetPredicate(_isChoiceRow);
          if (stacked.evaluate().isEmpty) {
            failures[where] =
                'labels do not fit, but no KitChoiceRow '
                '(KIT-24: KitSegmented stacks full-width choice rows)';
          }
        }
      }
    }
  }
  // Leave no route or ticker behind for the next scene.
  await tester.pumpWidget(const SizedBox());
  return failures;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // ProfileStore reads passwords through flutter_secure_storage, whose
    // unmocked channel never answers inside testWidgets.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  testWidgets('chat transcript and composer lay out at 2.5x', (tester) async {
    final conn = await _controller(withRepository: false);
    addTearDown(conn.dispose);
    await _pumpScaled(
      tester,
      _scoped(conn, const ChatScreen(sessionID: 'session-1')),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-composer-field')), findsOneWidget);
  });

  testWidgets('the busy composer lays out at 2.5x', (tester) async {
    final conn = await _controller(withRepository: false);
    addTearDown(conn.dispose);
    conn.busySessions = {'session-1'};
    await _pumpScaled(
      tester,
      _scoped(conn, const ChatScreen(sessionID: 'session-1')),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-composer-field')), findsOneWidget);
  });

  testWidgets('workspace lays out at 2.5x', (tester) async {
    final conn = await _controller();
    addTearDown(conn.dispose);
    await _pumpScaled(
      tester,
      _scoped(conn, Scaffold(body: WorkspaceScreen(controller: conn))),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the home shell lays out at 2.5x', (tester) async {
    final conn = await _controller();
    addTearDown(conn.dispose);
    await _pumpScaled(tester, _scoped(conn, const HomeScreen()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the Settings tab lays out at 2.5x', (tester) async {
    final conn = await _controller();
    addTearDown(conn.dispose);
    await _pumpScaled(
      tester,
      _scoped(
        conn,
        Scaffold(body: SettingsScreen(controller: conn, embedded: true)),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('settings lays out at 2.5x', (tester) async {
    final conn = await _controller();
    addTearDown(conn.dispose);
    await _pumpScaled(tester, _scoped(conn, SettingsScreen(controller: conn)));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the servers first-run screen lays out at 2.5x', (tester) async {
    final conn = await _controller(withProfile: false);
    addTearDown(conn.dispose);
    await _pumpScaled(tester, _scoped(conn, const ServersScreen()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the permission sheet lays out at 2.5x', (tester) async {
    await _pumpScaled(
      tester,
      _app(
        Scaffold(
          body: PermissionSheet(
            permission: PermissionRequest(
              id: 'per_1',
              sessionID: 'ses_1',
              permission: 'bash',
              patterns: const [
                'git push origin main --force-with-lease --no-verify',
              ],
              always: const [],
              message: 'Pushing the release branch to the shared remote',
              tool: null,
            ),
            onReply: (reply, {String? message}) async {},
            supportsRejectMessage: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('permission-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the form renderer lays out at 2.5x', (tester) async {
    await _pumpScaled(
      tester,
      _app(
        Scaffold(
          body: FormRenderer(
            form: Api2FormInfo(
              id: 'frm_1',
              sessionID: 'ses_1',
              title: 'Connect this workspace to Sentry',
              fields: [
                Api2FormField(
                  key: 'org',
                  type: Api2FormFieldType.string,
                  title: 'Organization slug',
                  description:
                      'The slug shown in your Sentry organization settings.',
                  required: true,
                ),
                Api2FormField(
                  key: 'retention',
                  type: Api2FormFieldType.integer,
                  title: 'Retention in days',
                  required: true,
                ),
                Api2FormField(
                  key: 'env',
                  type: Api2FormFieldType.multiselect,
                  title: 'Environments to watch',
                  options: [
                    Api2FormOption(value: 'prod', label: 'Production'),
                    Api2FormOption(value: 'stage', label: 'Staging'),
                  ],
                ),
                Api2FormField(
                  key: 'notify',
                  type: Api2FormFieldType.boolean,
                  title: 'Notify this session on new issues',
                ),
              ],
            ),
            onSubmit: (_) async {},
            onCancel: () async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('form-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  group('G6 kit overflow matrix', () {
    setUpAll(loadKitGalleryFonts);

    test('every exported kit part has a scene, and every scene a part', () {
      final manifest = kitManifest();
      final covered = {for (final s in kitOverflowScenes) ...s.parts};
      expect(manifest, isNotEmpty);
      final missing = manifest.difference(covered).toList()..sort();
      final stale = covered.difference(manifest).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'Kit parts with no scene in test/kit/kit_overflow_scenes.dart '
            '(add one per declared state at the end of kitOverflowScenes)',
      );
      expect(
        stale,
        isEmpty,
        reason: 'Scenes naming parts kit.dart no longer exports',
      );
      if (manifest.contains('KitSegmented')) {
        expect(
          kitOverflowScenes.any(
            (s) => s.parts.contains('KitSegmented') && s.labelsOverflow,
          ),
          isTrue,
          reason:
              'KIT-24: KitSegmented needs a labelsOverflow scene proving it '
              'stacks KitChoiceRows when its labels do not fit',
        );
      }
    });

    final baseline = _loadOverflowBaseline();
    final observed = <String, Set<String>>{};

    test('the overflow baseline names only scenes that exist', () {
      final ids = {for (final s in kitOverflowScenes) s.id};
      expect(ids.length, kitOverflowScenes.length, reason: 'duplicate ids');
      expect(baseline.keys.toSet().difference(ids), isEmpty);
    });

    for (final scene in kitOverflowScenes) {
      testWidgets(
        '${scene.id} fits every overflow size, text scale and direction',
        (tester) async {
          final failures = await _pumpMatrix(tester, scene);
          observed[scene.id] = failures.keys.toSet();
          final known = baseline[scene.id] ?? const <String>{};
          final fresh = [
            for (final MapEntry(:key, :value) in failures.entries)
              if (!known.contains(key)) '$key: $value',
          ];
          expect(
            fresh,
            isEmpty,
            reason:
                '${scene.id} overflowed or threw in ${fresh.length} of '
                '${_overflowSizes.length * _overflowScales.length * 2} '
                'combinations beyond $_baselinePath:\n${fresh.join('\n')}',
          );
        },
      );
    }

    // The ratchet: once every scene ran, print the smaller baseline to
    // commit (or write it with G6_OVERFLOW_WRITE=1).
    tearDownAll(() {
      if (observed.length != kitOverflowScenes.length) return;
      // Only the gate's creation records failures; afterwards an entry can
      // only leave the baseline.
      final creating = !File(_baselinePath).existsSync();
      final next = {
        for (final MapEntry(:key, :value) in observed.entries)
          key: creating ? value : value.intersection(baseline[key] ?? const {}),
      };
      final text = _encodeOverflowBaseline(next);
      if (text == _encodeOverflowBaseline(baseline)) return;
      if (Platform.environment['G6_OVERFLOW_WRITE'] == '1') {
        File(_baselinePath).writeAsStringSync(text);
        stdout.writeln('G6_OVERFLOW_WRITE=1: wrote $_baselinePath');
      } else {
        stdout.writeln(
          '--- G6 overflow baseline ${creating ? 'created' : 'shrank'} '
          '(commit as $_baselinePath) ---\n'
          '$text--- end baseline ---',
        );
      }
    });
  });
}
