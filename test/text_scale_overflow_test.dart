// Text scale and overflow (A11Y-2, docs/ux-system/revamp/STANDARDS.md §18):
//
// 1. The critical flows at AppTheme.maxTextScale (2.5) on a 360x740 phone.
// 2. Gate G6, the kit overflow matrix (A11Y-2, LAY-4, KIT-24; absolute):
//    every part lib/ui/kit/kit.dart exports is found by reading its exports,
//    and every scene of it in test/kit/kit_overflow_scenes.dart is pumped at
//    the LAY-4 overflow sizes, at text 1.0, 1.3 and 2.0, left to right and
//    right to left, with tester.takeException() null each time. A part with
//    no scene, or a scene naming a part the kit no longer exports, fails, and
//    so does any export, part or superclass the manifest cannot read.
//    KitSegmented, once it exists, must stack full-width KitChoiceRows, with
//    no track beside them, at text 2.0 on every phone size. STANDARDS calls
//    G6 absolute; until kit-KitRow-v2 fixes KitRowValue in a KitRow it is a
//    ratchet whose ceiling (_overflowCeiling) is fixed here and whose
//    committed baseline must equal what overflows and may only shrink. Kit
//    units add scenes there, never edit this file (PROC-13).
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

/// Exported classes that extend a class outside the scanned files and are
/// not widgets. Any other exported class whose superclass chain leaves the
/// scanned files at something that is not a widget fails the manifest, so a
/// part that extends `ListTile`, `Builder` or `ValueListenableBuilder` cannot
/// quietly drop out of the matrix. A class with no `extends` is an `Object`
/// and never a widget.
const _nonWidgetClasses = {
  'KitTokens',
  'KitPageTransitionsBuilder',
  // A pushed route (kit-KitPageRoute): it lays nothing out itself; the
  // page it carries is the screen's.
  'KitPageRoute',
  // KitZoom's controller (kit-KitImage), a ChangeNotifier.
  'KitZoomController',
};

/// Every `export` and `part` directive in a scanned file; each one must match
/// the strict pattern below it, or the manifest reports it.
final _exportDirective = RegExp(r'^[ \t]*export\b[^;]*;', multiLine: true);
final _exportPattern = RegExp(
  r"^export\s+'([^']+)'(?:\s+(show|hide)\s+([\w\s,]+))?;$",
);
final _partDirective = RegExp(
  r'^[ \t]*part\b(?!\s+of\b)[^;]*;',
  multiLine: true,
);
final _partPattern = RegExp(r"^part\s+'([^']+)';$");
final _classDeclaration = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface|mixin)\s+)*class\s+([A-Z]\w*)',
  multiLine: true,
);
final _classPattern = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface|mixin)\s+)*class\s+'
  r'([A-Z]\w*)(?:<[^{]*?>)?\s+extends\s+(\w+)',
  multiLine: true,
);

/// A top-level function named `showKit…`, whatever it returns.
final _showKitPattern = RegExp(
  r'^(?![\s/@])[^\n=;{}]*?\b(showKit\w+)\s*(?:<[^>(]*>)?\s*\(',
  multiLine: true,
);

/// The kit's parts, read from `kit.dart`'s exports, and every directive or
/// class the reader could not account for.
typedef KitManifest = ({Set<String> parts, List<String> problems});

/// Reads the parts from [kitFile]'s exports (following `part` files and
/// re-exports, honouring `show`): every public widget class and every
/// `showKit…` function. It never drops a file or a class silently: an export
/// or part it cannot parse, an export it does not follow, and an exported
/// class whose superclass it cannot classify all land in `problems`.
KitManifest readKitManifest({String kitFile = '$_kitDir/kit.dart'}) {
  final supers = <String, String>{};
  final declared = <String>{};
  final functions = <String>{};
  final problems = <String>[];

  String shown(File file) {
    final path = file.absolute.path;
    final root = Directory.current.absolute.path;
    return path.startsWith('$root/') ? path.substring(root.length + 1) : path;
  }

  File resolve(File from, String uri) {
    const self = 'package:opencode_mobile/';
    if (uri.startsWith(self)) return File('lib/${uri.substring(self.length)}');
    return File.fromUri(from.absolute.uri.resolve(uri));
  }

  // Returns the public names [file] contributes, filtered by [show].
  Set<String> scan(File file, Set<String>? show, Set<String> seen) {
    final path = file.absolute.uri.normalizePath().toFilePath();
    // Keyed by the `show` too: `export 'kit_menu.dart' show KitMenuItem;`
    // in one file must not hide a full `export 'kit_menu.dart';` elsewhere.
    if (!seen.add('$path|${(show?.toList()?..sort())?.join(',')}')) return {};
    final source = file.readAsStringSync();
    final texts = [source];
    for (final directive in _partDirective.allMatches(source)) {
      final text = directive[0]!.trim();
      final m = _partPattern.firstMatch(text);
      if (m == null) {
        problems.add(
          '${shown(file)}: the manifest cannot read `$text` '
          "(write part '<file>';)",
        );
        continue;
      }
      texts.add(resolve(file, m[1]!).readAsStringSync());
    }
    final names = <String>{};
    for (final text in texts) {
      for (final m in _classDeclaration.allMatches(text)) {
        declared.add(m[1]!);
        names.add(m[1]!);
      }
      for (final m in _classPattern.allMatches(text)) {
        supers[m[1]!] = m[2]!;
      }
      for (final m in _showKitPattern.allMatches(text)) {
        functions.add(m[1]!);
        names.add(m[1]!);
      }
    }
    for (final directive in _exportDirective.allMatches(source)) {
      final text = directive[0]!.trim();
      final m = _exportPattern.firstMatch(text);
      if (m == null) {
        problems.add(
          '${shown(file)}: the manifest cannot read `$text` '
          "(write export '<file>'; or export '<file>' show|hide A, B;)",
        );
        continue;
      }
      final uri = m[1]!;
      if (uri.startsWith('dart:') ||
          (uri.startsWith('package:') &&
              !uri.startsWith('package:opencode_mobile/'))) {
        problems.add(
          '${shown(file)}: exports $uri, which the manifest does not follow',
        );
        continue;
      }
      final listed = m[3]?.split(',').map((n) => n.trim()).toSet();
      final hidden = m[2] == 'hide' ? listed! : const <String>{};
      names.addAll(
        scan(
          resolve(file, uri),
          m[2] == 'show' ? listed : null,
          seen,
        ).difference(hidden),
      );
    }
    return show == null ? names : names.intersection(show);
  }

  final exported = scan(File(kitFile), null, {});

  // The superclass chain of [name] inside the scanned files, then the first
  // superclass outside them (null when the chain ends at Object).
  (List<String>, String?) chain(String name) {
    final seen = <String>[name];
    var base = supers[name];
    while (base != null && declared.contains(base) && !seen.contains(base)) {
      seen.add(base);
      base = supers[base];
    }
    return (seen, base);
  }

  bool isWidgetBase(String base) =>
      base.endsWith('Widget') || _widgetBases.contains(base);

  final parts = <String>{};
  for (final name in exported) {
    if (functions.contains(name)) {
      parts.add(name);
      continue;
    }
    final (classes, outside) = chain(name);
    if (outside == null) continue;
    if (isWidgetBase(outside)) {
      parts.add(name);
      continue;
    }
    if (classes.any(_nonWidgetClasses.contains)) continue;
    problems.add(
      '$name extends ${classes.length > 1 ? '${classes.skip(1).join(' → ')} → ' : ''}'
      '$outside, which is neither a widget, a kit class nor a known '
      'non-widget: the manifest cannot tell whether it is a part',
    );
  }
  return (parts: parts, problems: problems);
}

// ---------------------------------------------------------------------------
// The overflow ratchet.

/// The ceiling of the ratchet: every combination that overflowed when the
/// gate was built (code head 4cc835fd), with its first error line. The
/// committed baseline may hold only these combinations, each with the same
/// error and an overflow no larger. Nothing is ever added here (kit units
/// never edit this file, PROC-13); a new scene or combination that overflows
/// fails.
///
/// The KitActionBlock and KitSheet entries the gate was built with left
/// when the visual language merge (ddcb6bc7) made them fit, so they are
/// gone from here too. The one addition is that merge's own code, added
/// once by the integrator when the merge met the gate
/// (docs/qa/integrate-vl-gates-2026-09-26/README.md): KitRowValue as a
/// KitRow's trailing value takes its full width at text 2.0 on a narrow
/// phone. kit-KitRow-v2 removes it (docs/ux-system/kit-api/KitRow.md,
/// test 11: no overflow at 2.0 and 320 dp).
const _overflowCeiling = <String, Map<String, String>>{
  'KitRowGroup/default': {
    '320x640 text 2.0 ltr':
        'A RenderFlex overflowed by 55 pixels on the right.',
    '320x640 text 2.0 rtl':
        'A RenderFlex overflowed by 55 pixels on the right.',
    '360x740 text 2.0 ltr':
        'A RenderFlex overflowed by 15 pixels on the right.',
    '360x740 text 2.0 rtl':
        'A RenderFlex overflowed by 15 pixels on the right.',
  },
};

/// The committed baseline: the entries of [_overflowCeiling] that still
/// overflow. It must exist, must equal what the matrix observes, and may
/// only shrink.
const _baselinePath = 'test/text_scale_overflow_baseline.json';

typedef _Overflows = Map<String, Map<String, String>>;

/// The baseline, or null when the file is missing (which fails the gate;
/// it is never recreated from observations).
_Overflows? _loadOverflowBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return null;
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: {
        for (final MapEntry(:key, :value)
            in (value as Map<String, dynamic>).entries)
          key: value as String,
      },
  };
}

String _encodeOverflowBaseline(_Overflows baseline) {
  final ids = baseline.keys.where((id) => baseline[id]!.isNotEmpty).toList()
    ..sort();
  return '${const JsonEncoder.withIndent('  ').convert({
    for (final id in ids) id: {for (final combo in baseline[id]!.keys.toList()..sort()) combo: baseline[id]![combo]},
  })}\n';
}

final _pixels = RegExp(r'([\d.]+) pixels');

/// The error with its pixel amount taken out, and the amount.
(String, double?) _errorShape(String line) {
  final m = _pixels.firstMatch(line);
  return (
    line.replaceAll(_pixels, '# pixels'),
    m == null ? null : double.tryParse(m[1]!),
  );
}

/// Compares [observed] failures with the [allowed] ones for one scene:
/// `worse` is every failure not allowed (a new combination, a different
/// error, a larger overflow); `better` is every allowed failure that is gone
/// or smaller, which the same change must remove from the baseline.
({List<String> worse, List<String> better}) _compareOverflows(
  Map<String, String> observed,
  Map<String, String> allowed,
) {
  final worse = <String>[];
  final better = <String>[];
  for (final MapEntry(:key, :value) in observed.entries) {
    final known = allowed[key];
    if (known == null) {
      worse.add('$key: $value');
      continue;
    }
    final (shape, amount) = _errorShape(value);
    final (knownShape, knownAmount) = _errorShape(known);
    if (shape != knownShape || (amount ?? 0) > (knownAmount ?? 0)) {
      worse.add('$key: $value (baselined: $known)');
    } else if ((amount ?? 0) < (knownAmount ?? 0)) {
      better.add('$key: now $value (baselined: $known)');
    }
  }
  for (final MapEntry(:key, :value) in allowed.entries) {
    if (!observed.containsKey(key)) {
      better.add('$key: fixed (baselined: $value)');
    }
  }
  return (worse: worse, better: better);
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

// ---------------------------------------------------------------------------
// KIT-24.

bool _isKitSegmented(Widget widget) =>
    widget.runtimeType.toString() == 'KitSegmented';

bool _isKitChoiceRow(Widget widget) =>
    widget.runtimeType.toString() == 'KitChoiceRow';

/// KIT-24 on the pumped tree, for a scene whose labels do not fit: every
/// KitSegmented is full width and is a vertical stack of at least two
/// full-width KitChoiceRows, and draws no text outside them (the horizontal
/// segmented track is gone). Returns why it fails, or null.
String? kit24Problem({
  bool Function(Widget) isSegmented = _isKitSegmented,
  bool Function(Widget) isChoiceRow = _isKitChoiceRow,
}) {
  final segmented = find.byWidgetPredicate(isSegmented).evaluate().toList();
  if (segmented.isEmpty) {
    return 'labels do not fit, but no KitSegmented is shown (KIT-24)';
  }
  for (final part in segmented) {
    final partBox = part.renderObject! as RenderBox;
    final available = partBox.constraints.maxWidth;
    if (available.isFinite && partBox.size.width < available - 0.5) {
      return 'KitSegmented is ${partBox.size.width} of $available dp '
          '(KIT-24: full width)';
    }
    final of = find.byElementPredicate((e) => identical(e, part));
    final rows =
        find
            .descendant(of: of, matching: find.byWidgetPredicate(isChoiceRow))
            .evaluate()
            .map((e) => e.renderObject! as RenderBox)
            .map((b) => b.localToGlobal(Offset.zero) & b.size)
            .toList()
          ..sort((a, b) => a.top.compareTo(b.top));
    if (rows.length < 2) {
      return 'labels do not fit, but KitSegmented shows ${rows.length} '
          'KitChoiceRow(s), not a stack (KIT-24)';
    }
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].width < partBox.size.width - 0.5) {
        return 'a KitChoiceRow is ${rows[i].width} of the part\'s '
            '${partBox.size.width} dp (KIT-24: full-width rows)';
      }
      if (i > 0 && rows[i].top < rows[i - 1].bottom - 0.5) {
        return 'KitChoiceRows overlap or sit side by side, not stacked '
            '(KIT-24)';
      }
    }
    final texts = find
        .descendant(of: of, matching: find.byType(RichText))
        .evaluate();
    for (final text in texts) {
      var inRow = false;
      text.visitAncestorElements((ancestor) {
        if (isChoiceRow(ancestor.widget)) {
          inRow = true;
          return false;
        }
        return !identical(ancestor, part);
      });
      if (!inRow) {
        return 'KitSegmented still draws '
            '"${(text.widget as RichText).text.toPlainText()}" outside its '
            'KitChoiceRows (KIT-24: the track gives way to the stack)';
      }
    }
  }
  return null;
}

/// A phone, portrait or landscape: where KIT-24's stack is checked at 2.0.
bool _isPhone(Size size) => size.shortestSide < 600;

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
        if (scene.labelsOverflow && scale >= 2.0 && _isPhone(size)) {
          final problem = kit24Problem();
          if (problem != null) failures[where] = problem;
        }
      }
    }
  }
  // Leave no route or ticker behind for the next scene.
  await tester.pumpWidget(const SizedBox());
  return failures;
}

// Stand-ins for the KIT-24 self-test: a segmented part that stacks its rows,
// keeps its track beside them, or stacks rows narrower than itself.
enum _FakeLayout { stack, track, narrow }

class _FakeSegmented extends StatelessWidget {
  const _FakeSegmented(this.layout);

  final _FakeLayout layout;

  static const _labels = ['Only this session', 'Every session on the server'];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (layout == _FakeLayout.track)
        Row(
          children: [
            for (final label in _labels)
              Expanded(
                child: Text(
                  label,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
          ],
        ),
      for (final label in _labels)
        if (layout == _FakeLayout.narrow)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(width: 120, child: _FakeChoiceRow(label)),
          )
        else
          _FakeChoiceRow(label),
    ],
  );
}

class _FakeChoiceRow extends StatelessWidget {
  const _FakeChoiceRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(12), child: Text(label));
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

    // The retired wrapper draws the one request card (chat-5); Details
    // opens the request sheet, which must lay out at 2.5x too.
    expect(find.byKey(const Key('permission-card-allow')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final details = find.byKey(const Key('permission-card-review'));
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
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
      final manifest = readKitManifest();
      expect(
        manifest.problems,
        isEmpty,
        reason:
            'The manifest could not read every export, part and class of '
            '$_kitDir/kit.dart, so parts may be missing from the matrix',
      );
      final parts = manifest.parts;
      final covered = {for (final s in kitOverflowScenes) ...s.parts};
      expect(parts, isNotEmpty);
      final missing = parts.difference(covered).toList()..sort();
      final stale = covered.difference(parts).toList()..sort();
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
      // KIT-24's stacked form needs kit-KitChoiceList's KitChoiceRow; the
      // check turns itself on when that part lands in the kit.
      final choiceRowLanded = Directory(_kitDir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .any(
            (f) => RegExp(
              r'^class\s+KitChoiceRow\b',
              multiLine: true,
            ).hasMatch(f.readAsStringSync()),
          );
      if (parts.contains('KitSegmented') && choiceRowLanded) {
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

    test('the manifest fails loudly on what it cannot read', () {
      final dir = Directory.systemTemp.createTempSync('g6_manifest');
      addTearDown(() => dir.deleteSync(recursive: true));
      void write(String name, String text) =>
          File('${dir.path}/$name').writeAsStringSync(text);
      write('kit.dart', '''
export 'fine.dart';
export 'hidden.dart' hide KitHidden;
export "quoted.dart";
export 'io.dart' if (dart.library.html) 'web.dart';
export 'package:flutter/widgets.dart';
''');
      write('fine.dart', '''
part "fine_part.dart";
class KitFine extends StatelessWidget {}
class KitTile extends ListTile {}
class KitListens extends ValueListenableBuilder<int> {}
class KitData {}
KitHandle showKitThing(BuildContext context) => KitHandle();
''');
      write('hidden.dart', '''
class KitHidden extends StatelessWidget {}
class KitShown extends StatelessWidget {}
''');
      final manifest = readKitManifest(kitFile: '${dir.path}/kit.dart');
      // `hide` is read (the hidden class drops out), unlike the forms below.
      expect(manifest.parts, {'KitFine', 'showKitThing', 'KitShown'});
      expect(
        manifest.problems,
        unorderedEquals([
          contains('`part "fine_part.dart";`'),
          contains('`export "quoted.dart";`'),
          contains("`export 'io.dart' if (dart.library.html) 'web.dart';`"),
          contains('exports package:flutter/widgets.dart'),
          contains('KitTile extends ListTile'),
          contains('KitListens extends ValueListenableBuilder'),
        ]),
      );
    });

    testWidgets(
      'the KIT-24 check passes a stack and fails a track, narrow rows or no '
      'part',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 740);
        addTearDown(tester.view.reset);
        Future<String?> check(Widget child) async {
          await tester.pumpWidget(
            _kitApp(
              key: UniqueKey(),
              scale: 2.0,
              rtl: false,
              home: (_) => ListView(
                padding: const EdgeInsets.all(16),
                children: [child],
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          return kit24Problem(
            isSegmented: (w) => w is _FakeSegmented,
            isChoiceRow: (w) => w is _FakeChoiceRow,
          );
        }

        expect(await check(const _FakeSegmented(_FakeLayout.stack)), isNull);
        expect(
          await check(const _FakeSegmented(_FakeLayout.track)),
          contains('outside its KitChoiceRows'),
        );
        expect(
          await check(const _FakeSegmented(_FakeLayout.narrow)),
          contains('full-width rows'),
        );
        expect(
          await check(const SizedBox()),
          contains('no KitSegmented is shown'),
        );
      },
    );

    final baseline = _loadOverflowBaseline();
    final observed = <String, Map<String, String>>{};

    test('the overflow baseline exists and stays under the ceiling', () {
      expect(
        baseline,
        isNotNull,
        reason:
            '$_baselinePath is missing. It is never recreated from what '
            'overflows today: restore it from git',
      );
      final ids = {for (final s in kitOverflowScenes) s.id};
      expect(ids.length, kitOverflowScenes.length, reason: 'duplicate ids');
      expect(baseline!.keys.toSet().difference(ids), isEmpty);
      final raised = [
        for (final MapEntry(:key, :value) in baseline.entries)
          for (final entry in _compareOverflows(
            value,
            _overflowCeiling[key] ?? const {},
          ).worse)
            '$key $entry',
      ];
      expect(
        raised,
        isEmpty,
        reason:
            '$_baselinePath may only shrink: these entries are not in the '
            'ceiling (_overflowCeiling in test/text_scale_overflow_test.dart), '
            'or are larger or different there. Fix the overflow instead',
      );
    });

    for (final scene in kitOverflowScenes) {
      testWidgets(
        '${scene.id} fits every overflow size, text scale and direction',
        (tester) async {
          final failures = await _pumpMatrix(tester, scene);
          observed[scene.id] = failures;
          final (:worse, :better) = _compareOverflows(
            failures,
            baseline?[scene.id] ?? const {},
          );
          expect(
            worse,
            isEmpty,
            reason:
                '${scene.id} overflowed or threw in ${worse.length} of '
                '${_overflowSizes.length * _overflowScales.length * 2} '
                'combinations beyond $_baselinePath:\n${worse.join('\n')}',
          );
          expect(
            better,
            isEmpty,
            reason:
                '${scene.id} improved. Tighten $_baselinePath in the same '
                'change (G6_OVERFLOW_WRITE=1 writes it), so a later '
                'regression at these combinations fails:\n${better.join('\n')}',
          );
        },
      );
    }

    // The ratchet: once every scene ran, print the tighter baseline to commit
    // (or write it with G6_OVERFLOW_WRITE=1). It keeps only baselined
    // entries that still fail no worse, so it never grows.
    tearDownAll(() {
      final current = baseline;
      if (current == null || observed.length != kitOverflowScenes.length) {
        return;
      }
      final next = <String, Map<String, String>>{
        for (final MapEntry(:key, :value) in observed.entries)
          key: {
            for (final MapEntry(key: combo, value: line) in value.entries)
              if (current[key]?[combo] != null &&
                  !_compareOverflows(
                    {combo: line},
                    {combo: current[key]![combo]!},
                  ).worse.isNotEmpty)
                combo: line,
          },
      };
      final text = _encodeOverflowBaseline(next);
      if (text == _encodeOverflowBaseline(current)) return;
      if (Platform.environment['G6_OVERFLOW_WRITE'] == '1') {
        File(_baselinePath).writeAsStringSync(text);
        stdout.writeln('G6_OVERFLOW_WRITE=1: wrote $_baselinePath');
      } else {
        stdout.writeln(
          '--- G6 overflow baseline tightened (commit as $_baselinePath) ---\n'
          '$text--- end baseline ---',
        );
      }
    });
  });
}
