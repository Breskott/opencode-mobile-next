// Gate G4 (docs/ux-system/revamp/STANDARDS.md §18): the kit manifest.
//
// A pure-Dart source scan, no widget pumping. It reads the exports of
// `lib/ui/kit/kit.dart` (following `show`/`hide` combinators, re-exports
// and `part` files) and collects every public widget class and every
// `showKit…` opener. Each part must then have what the rulebook asks for:
//
// - name (NAME-1): class `Kit<Name>` in `lib/ui/kit/kit_<snake>.dart`
//   (chat parts in `lib/ui/kit/chat/`, scenes in `lib/ui/kit/scenes/`).
// - states (KIT-12): a `States: …` line in its doc comment naming the states
//   it has from {loading, empty, error, disabled, working, answered}, or
//   `States: none.` Example: `/// States: loading, empty, error.`
// - stateScenes (KIT-12, TEST-9): one gallery scene per declared state, a
//   golden named `<snake>_<state>…` in its gallery file.
// - gallery (TEST-9, TEST-14, LAY-4, KIT-32): `test/goldens/kit/
//   <snake>_golden_test.dart` using `kitGallerySizes` and
//   `kitGalleryScaledSizes`, with `text2` and `_ar_` variants.
// - test (TEST-15, NAME-1): `test/kit/<snake>_test.dart`.
// - docRow (KIT-14): a row in the `kit.dart` doc table naming `[<Name>]`.
// - motion (TEST-15, G8): named in `test/kit_motion_test.dart` (by class or
//   by its `showKit…` opener), or that file reads this manifest.
// - keyboard (TEST-15, G14): modal parts and rows, named in
//   `test/kit/kit_keyboard_test.dart`, or that file reads this manifest.
// - overflow (TEST-15, G6): named in `test/text_scale_overflow_test.dart`,
//   or that file reads this manifest.
// - openerReturn (KIT-11): a `showKit…` returns `Future<…>` (`showKitSheet`
//   `Future<T?>`, `showKitConfirm` `Future<bool>`, `showKitInputDialog`
//   `Future<String?>`); only `showKitUndo` returns `void`.
// - openerKey (KIT-10): a `showKit…` declares at least one optional
//   `Key? …Key` parameter.
// - harness (LAY-4, TEST-9): `kitGallerySizes` in the gallery harness holds
//   every LAY-4 gallery size and `kitGalleryScaledSizes` both TEST-9 ones.
//
// InheritedWidget scopes (KitEffectsScope and the like) draw nothing, so
// they need only the name, test and docRow checks. An exported KitScene
// (drawn by KitIllustration, TEST-14) needs the name check (in
// `lib/ui/kit/scenes/`), a docRow and a gallery with dark and light shots.
//
// Parts that predate the gate sit in `kit_manifest_allowlist.json`
// (check -> part names). The allowlist may only shrink: a violation not on
// it fails the test; an entry that no longer fails is printed as the
// smaller allowlist to commit. Shrink it in place with
//   KIT_MANIFEST_WRITE=1 flutter test test/kit/kit_manifest_test.dart
// (the pinned Flutter from AGENTS.md). Writing never adds an entry.
//
// The motion, keyboard, overflow and gallery-guideline gates (G8x, G14x,
// G6, G5) read the same manifest instead of hand lists:
//   import 'kit_manifest_test.dart' show readKitManifest, KitManifestPart;
// A consumer that imports this file counts as covering every part for its
// check.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The states a kit part may declare (KIT-12).
const kitManifestStates = <String>{
  'loading',
  'empty',
  'error',
  'disabled',
  'working',
  'answered',
};

/// The checks this gate runs; the allowlist's keys.
const kitManifestChecks = <String>[
  'name',
  'states',
  'stateScenes',
  'gallery',
  'test',
  'docRow',
  'motion',
  'keyboard',
  'overflow',
  'openerReturn',
  'openerKey',
  'harness',
];

const _kitLibrary = 'lib/ui/kit/kit.dart';
const _allowlistPath = 'test/kit/kit_manifest_allowlist.json';
const _galleryHarness = 'test/goldens/kit/kit_gallery.dart';
const _motionTest = 'test/kit_motion_test.dart';
const _keyboardTest = 'test/kit/kit_keyboard_test.dart';
const _overflowTest = 'test/text_scale_overflow_test.dart';
const _manifestImport = 'kit_manifest_test.dart';

/// LAY-4 gallery sizes and the TEST-9 scaled (text 2.0, Arabic) sizes.
const _lay4GallerySizes = [
  '360x800',
  '412x915',
  '915x412',
  '800x1280',
  '1280x800',
  '1600x1000',
];
const _test9ScaledSizes = ['412x915', '1280x800'];

/// Widgets whose subclasses draw nothing: plumbing, not drawn parts.
const _scopeBases = <String>{
  'InheritedWidget',
  'InheritedNotifier',
  'InheritedModel',
  'InheritedTheme',
  'ParentDataWidget',
};

/// Framework widget bases that may not be in the widget catalogue.
const _widgetBases = <String>{
  'Widget',
  'StatelessWidget',
  'StatefulWidget',
  'ProxyWidget',
  'RenderObjectWidget',
  'SingleChildRenderObjectWidget',
  'MultiChildRenderObjectWidget',
  'LeafRenderObjectWidget',
  'SlottedMultiChildRenderObjectWidget',
  'ImplicitlyAnimatedWidget',
  'AnimatedWidget',
  ..._scopeBases,
};

/// A drawn widget part, a scope widget that draws nothing, or a drawn
/// [KitScene] (painted by KitIllustration; TEST-14).
enum KitManifestKind { part, scope, scene }

/// One public widget class exported by `kit.dart`.
class KitManifestPart {
  const KitManifestPart({
    required this.name,
    required this.file,
    required this.kind,
    required this.states,
    required this.statesProblem,
    required this.openers,
  });

  final String name;

  /// The file (relative to the package root) that declares the class.
  final String file;
  final KitManifestKind kind;

  /// The states its doc comment declares (KIT-12); null when it declares
  /// none or the line is malformed ([statesProblem] says which).
  final List<String>? states;
  final String? statesProblem;

  /// The `showKit…` functions declared in the same file: the part is modal.
  final List<String> openers;

  String get snake => kitSnake(name);
  bool get isModal => openers.isNotEmpty;
  bool get isRow => name.endsWith('Row');

  /// The names a hand-listed consumer test may use for this part.
  List<String> get aliases => [name, ...openers];

  @override
  String toString() => '$name ($file)';
}

/// One `showKit…` function exported by `kit.dart`.
class KitManifestOpener {
  const KitManifestOpener({
    required this.name,
    required this.file,
    required this.returnType,
    required this.parameters,
  });

  final String name;
  final String file;
  final String returnType;

  /// The source between the parameter list's parentheses.
  final String parameters;

  /// Whether it declares an optional `Key? …Key` parameter (KIT-10).
  bool get hasOptionalKey => RegExp(
    r'\bKey\?\s+\w*Key\b',
  ).hasMatch(parameters.replaceAll(RegExp(r'required\s+Key\?\s+\w+'), ''));
}

class KitManifest {
  const KitManifest({
    required this.parts,
    required this.openers,
    required this.unresolved,
  });

  final List<KitManifestPart> parts;
  final List<KitManifestOpener> openers;

  /// Names in a `show` combinator that no declaration matched.
  final List<String> unresolved;

  Iterable<KitManifestPart> get drawn =>
      parts.where((p) => p.kind == KitManifestKind.part);
}

/// `KitConfirmSheet` -> `kit_confirm_sheet`.
String kitSnake(String name) => name
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .replaceAllMapped(RegExp(r'([A-Z])([A-Z][a-z])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase();

String _read(String path) => File(path).readAsStringSync();

String _normalize(String path) {
  final out = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '..') {
      out.removeLast();
    } else if (segment != '.' && segment.isNotEmpty) {
      out.add(segment);
    }
  }
  return out.join('/');
}

String _resolve(String from, String uri) {
  if (uri.startsWith('package:opencode_mobile/')) {
    return 'lib/${uri.substring('package:opencode_mobile/'.length)}';
  }
  final dir = from.substring(0, from.lastIndexOf('/'));
  return _normalize('$dir/$uri');
}

final _directive = RegExp(
  r"^(export|part)\s+'([^']+)'\s*([^;]*);",
  multiLine: true,
);

Set<String> _names(String combinator, String keyword) {
  final m = RegExp(
    '\\b$keyword\\s+([\\w\\s,]+?)(?=\\s+(?:show|hide)\\b|\$)',
  ).firstMatch(combinator.trim());
  if (m == null) return {};
  return m[1]!
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
}

class _Decl {
  _Decl(this.name, this.file, this.line, this.kind);
  final String name;
  final String file;
  final int line;
  final String kind; // class, function, other
}

final _classHeader = RegExp(
  r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*class\s+(\w+)',
  multiLine: true,
);
final _otherHeader = RegExp(
  r'^(?:enum|mixin|typedef|extension\s+type)\s+(\w+)',
  multiLine: true,
);
final _functionHeader = RegExp(
  r'^([A-Za-z_][\w<>?, ]*?)\s+(show\w+)\s*(?:<[^(]*>)?\s*\(',
  multiLine: true,
);

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length;

/// The files of a library: the file and its `part`s.
List<String> _unitsOf(String path) {
  final source = _read(path);
  return [
    path,
    for (final m in _directive.allMatches(source))
      if (m[1] == 'part') _resolve(path, m[2]!),
  ];
}

List<_Decl> _declarationsIn(String file) {
  final source = _read(file);
  return [
    for (final m in _classHeader.allMatches(source))
      _Decl(m[1]!, file, _lineOf(source, m.start), 'class'),
    for (final m in _otherHeader.allMatches(source))
      _Decl(m[1]!, file, _lineOf(source, m.start), 'other'),
    for (final m in _functionHeader.allMatches(source))
      if (!RegExp(r'^\s*(return|await|if|else)\b').hasMatch(m[1]!))
        _Decl(m[2]!, file, _lineOf(source, m.start), 'function'),
  ];
}

/// Every public declaration [path] exports, through re-exports.
void _collectExports(
  String path,
  Set<String>? show,
  Set<String> hide,
  Map<String, _Decl> out,
  Set<String> wanted,
  Set<String> visiting,
) {
  if (!visiting.add('$path|$show|$hide')) return;
  bool visible(String name) =>
      !name.startsWith('_') &&
      (show == null || show.contains(name)) &&
      !hide.contains(name);
  for (final unit in _unitsOf(path)) {
    for (final decl in _declarationsIn(unit)) {
      if (visible(decl.name)) out.putIfAbsent(decl.name, () => decl);
    }
  }
  final source = _read(path);
  for (final m in _directive.allMatches(source)) {
    if (m[1] != 'export') continue;
    final innerShow = _names(m[3]!, 'show');
    final innerHide = _names(m[3]!, 'hide');
    Set<String>? nextShow = innerShow.isEmpty ? show : innerShow;
    if (show != null && innerShow.isNotEmpty) {
      nextShow = innerShow.intersection(show);
    }
    wanted.addAll(innerShow);
    _collectExports(
      _resolve(path, m[2]!),
      nextShow,
      {...hide, ...innerHide},
      out,
      wanted,
      visiting,
    );
  }
}

/// Superclass of every class declared under lib/.
Map<String, String> _superclasses() {
  final supers = <String, String>{};
  final header = RegExp(
    r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*class\s+(\w+)'
    r'(?:\s*<[^{]*?>)?\s+extends\s+(\w+)',
    multiLine: true,
  );
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final m in header.allMatches(entity.readAsStringSync())) {
      supers.putIfAbsent(m[1]!, () => m[2]!);
    }
  }
  return supers;
}

Set<String> _frameworkWidgets() {
  final json =
      jsonDecode(_read('test/kit_ratchet_flutter_widgets.json'))
          as Map<String, Object?>;
  return (json['widgets']! as Map<String, Object?>).keys.toSet();
}

/// The doc comment above line [line] of [file] (annotations skipped).
List<String> _docAbove(String file, int line) {
  final lines = _read(file).split('\n');
  final doc = <String>[];
  for (var i = line - 1; i >= 0; i--) {
    final text = lines[i].trim();
    if (text.startsWith('@')) continue;
    if (!text.startsWith('///')) break;
    doc.insert(0, text.substring(3).trim());
  }
  return doc;
}

(List<String>?, String?) _statesFrom(List<String> doc) {
  final lines = doc.where((l) => l.startsWith('States:')).toList();
  if (lines.isEmpty) return (null, 'no "States: …" line in its doc comment');
  if (lines.length > 1) return (null, 'more than one "States:" line');
  final body = lines.single
      .substring('States:'.length)
      .trim()
      .replaceAll(RegExp(r'\.$'), '');
  if (body == 'none') return (const [], null);
  final states = body.split(',').map((s) => s.trim()).toList();
  final unknown = states.where((s) => !kitManifestStates.contains(s));
  if (unknown.isNotEmpty) {
    return (null, 'unknown states ${unknown.join(', ')}');
  }
  return (states, null);
}

String _parameters(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(open + 1, i);
  }
  return source.substring(open + 1);
}

/// Reads the kit manifest from `lib/ui/kit/kit.dart`.
KitManifest readKitManifest() {
  final decls = <String, _Decl>{};
  final wanted = <String>{};
  _collectExports(_kitLibrary, null, {}, decls, wanted, {});
  final supers = _superclasses();
  final framework = _frameworkWidgets();

  List<String> chain(String name) {
    final out = <String>[name];
    final seen = <String>{name};
    var current = name;
    for (
      var next = supers[current];
      next != null && seen.add(next);
      next = supers[current]
    ) {
      out.add(next);
      current = next;
    }
    return out;
  }

  bool isWidget(List<String> chain) =>
      chain.length > 1 &&
      (chain.skip(1).any(_widgetBases.contains) ||
          framework.contains(chain.last));

  final openers = <KitManifestOpener>[];
  for (final decl in decls.values.where((d) => d.kind == 'function')) {
    if (!decl.name.startsWith('showKit')) continue;
    final source = _read(decl.file);
    final m = _functionHeader
        .allMatches(source)
        .firstWhere((m) => m[2] == decl.name);
    openers.add(
      KitManifestOpener(
        name: decl.name,
        file: decl.file,
        returnType: m[1]!.trim(),
        parameters: _parameters(source, m.end - 1),
      ),
    );
  }
  openers.sort((a, b) => a.name.compareTo(b.name));

  final parts = <KitManifestPart>[];
  for (final decl in decls.values.where((d) => d.kind == 'class')) {
    final supersOf = chain(decl.name);
    final isScene = supersOf.skip(1).contains('KitScene');
    if (!isScene && !isWidget(supersOf)) continue;
    final (states, problem) = _statesFrom(_docAbove(decl.file, decl.line));
    parts.add(
      KitManifestPart(
        name: decl.name,
        file: decl.file,
        kind: isScene
            ? KitManifestKind.scene
            : supersOf.any(_scopeBases.contains)
            ? KitManifestKind.scope
            : KitManifestKind.part,
        states: states,
        statesProblem: problem,
        openers: [
          for (final o in openers)
            if (o.file == decl.file) o.name,
        ],
      ),
    );
  }
  parts.sort((a, b) => a.name.compareTo(b.name));

  return KitManifest(
    parts: parts,
    openers: openers,
    unresolved: (wanted.difference(decls.keys.toSet()).toList()..sort()),
  );
}

/// check -> subject -> why it fails.
Map<String, Map<String, String>> kitManifestViolations(KitManifest manifest) {
  final out = {for (final c in kitManifestChecks) c: <String, String>{}};
  final docRows = _read(
    _kitLibrary,
  ).split('\n').where((l) => l.startsWith('/// |')).join('\n');
  bool inDocTable(String name) => docRows.contains('[$name]');

  String? consumer(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  final motion = consumer(_motionTest);
  final keyboard = consumer(_keyboardTest);
  final overflow = consumer(_overflowTest);
  bool covers(String? source, KitManifestPart part) =>
      source != null &&
      (source.contains(_manifestImport) ||
          part.aliases.any(
            (a) => RegExp('\\b${RegExp.escape(a)}\\b').hasMatch(source),
          ));

  for (final part in manifest.parts) {
    final snake = part.snake;
    final allowedFiles = part.kind == KitManifestKind.scene
        ? ['lib/ui/kit/scenes/$snake.dart']
        : ['lib/ui/kit/$snake.dart', 'lib/ui/kit/chat/$snake.dart'];
    if (!part.name.startsWith('Kit')) {
      out['name']![part.name] = 'not named Kit<Name> (${part.file})';
    } else if (!allowedFiles.contains(part.file)) {
      out['name']![part.name] =
          'declared in ${part.file}, not ${allowedFiles.join(' or ')}';
    }
    if (!inDocTable(part.name)) {
      out['docRow']![part.name] = 'no [${part.name}] row in the kit.dart table';
    }
    final galleryPath = 'test/goldens/kit/${snake}_golden_test.dart';
    final gallery = consumer(galleryPath);
    if (part.kind == KitManifestKind.scene) {
      // TEST-14: dark and light goldens of the finished frame.
      if (gallery == null) {
        out['gallery']![part.name] = 'no $galleryPath';
      } else if (!gallery.contains('dark') || !gallery.contains('light')) {
        out['gallery']![part.name] = '$galleryPath lacks dark or light';
      }
      continue;
    }
    final unitTest = 'test/kit/${snake}_test.dart';
    if (!File(unitTest).existsSync()) {
      out['test']![part.name] = 'no $unitTest';
    }
    if (part.kind == KitManifestKind.scope) continue;

    if (part.statesProblem case final problem?) {
      out['states']![part.name] = problem;
    }
    if (gallery == null) {
      out['gallery']![part.name] = 'no $galleryPath';
    } else {
      final missing = [
        for (final needle in [
          'kitGallerySizes',
          'kitGalleryScaledSizes',
          'text2',
          '_ar_',
        ])
          if (!gallery.contains(needle)) needle,
      ];
      if (missing.isNotEmpty) {
        out['gallery']![part.name] = '$galleryPath lacks ${missing.join(', ')}';
      }
    }
    final missingScenes = [
      for (final state in part.states ?? const <String>[])
        if (gallery == null || !gallery.contains('${snake}_$state')) state,
    ];
    if (missingScenes.isNotEmpty) {
      out['stateScenes']![part.name] =
          'no gallery scene ${missingScenes.map((s) => '${snake}_$s').join(', ')}';
    }
    if (!covers(motion, part)) {
      out['motion']![part.name] = 'not in $_motionTest';
    }
    if ((part.isModal || part.isRow) && !covers(keyboard, part)) {
      out['keyboard']![part.name] = 'not in $_keyboardTest';
    }
    if (!covers(overflow, part)) {
      out['overflow']![part.name] = 'not in $_overflowTest';
    }
  }

  const exactReturns = {
    'showKitSheet': 'Future<T?>',
    'showKitConfirm': 'Future<bool>',
    'showKitInputDialog': 'Future<String?>',
    'showKitUndo': 'void',
  };
  for (final opener in manifest.openers) {
    final type = opener.returnType.replaceAll(RegExp(r'\s+'), '');
    final exact = exactReturns[opener.name];
    if (exact != null ? type != exact : !type.startsWith('Future<')) {
      out['openerReturn']![opener.name] =
          'returns ${opener.returnType}, expected ${exact ?? 'Future<…>'}';
    }
    if (opener.name != 'showKitUndo' && !opener.hasOptionalKey) {
      out['openerKey']![opener.name] = 'no optional Key? …Key parameter';
    }
    if (!inDocTable(opener.name)) {
      out['docRow']![opener.name] =
          'no [${opener.name}] row in the kit.dart table';
    }
  }

  final harness = _read(_galleryHarness);
  List<String> sizes(String name) {
    final m = RegExp(
      'const\\s+$name\\s*=\\s*<Size>\\[([^\\]]*)\\]',
    ).firstMatch(harness);
    if (m == null) return const [];
    return [
      for (final s in RegExp(
        r'Size\(\s*(\d+)\s*,\s*(\d+)\s*\)',
      ).allMatches(m[1]!))
        '${s[1]}x${s[2]}',
    ];
  }

  final gallerySizes = sizes('kitGallerySizes');
  for (final size in _lay4GallerySizes) {
    if (!gallerySizes.contains(size)) {
      out['harness']!['kitGallerySizes $size'] =
          '$_galleryHarness kitGallerySizes lacks the LAY-4 size $size';
    }
  }
  final scaledSizes = sizes('kitGalleryScaledSizes');
  for (final size in _test9ScaledSizes) {
    if (!scaledSizes.contains(size)) {
      out['harness']!['kitGalleryScaledSizes $size'] =
          '$_galleryHarness kitGalleryScaledSizes lacks the TEST-9 size $size';
    }
  }
  return out;
}

Map<String, List<String>> _readAllowlist() {
  final json = jsonDecode(_read(_allowlistPath)) as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      if (!key.startsWith('_'))
        key: [for (final v in value! as List<Object?>) v! as String],
  };
}

String _encodeAllowlist(Map<String, List<String>> allowlist, String about) {
  final ordered = <String, Object>{'_about': about};
  for (final check in kitManifestChecks) {
    final names = [...?allowlist[check]]..sort();
    if (names.isNotEmpty) ordered[check] = names;
  }
  return '${const JsonEncoder.withIndent('  ').convert(ordered)}\n';
}

void main() {
  final manifest = readKitManifest();

  test('G4: the manifest reads the kit library', () {
    final names = {for (final p in manifest.parts) p.name};
    // Loud failures if the scan silently finds nothing (a vacuous pass).
    expect(names, containsAll(['KitSheet', 'KitConfirmSheet', 'KitRow']));
    expect(
      manifest.openers.map((o) => o.name),
      containsAll(['showKitSheet', 'showKitConfirm']),
    );
    expect(
      manifest.parts.firstWhere((p) => p.name == 'KitSheet').openers,
      contains('showKitSheet'),
    );
    expect(
      manifest.unresolved,
      isEmpty,
      reason: 'kit.dart `show` names no declaration was found for',
    );
  });

  test('G4: every kit part and opener meets the manifest '
      '(allowlist only shrinks)', () {
    final raw = jsonDecode(_read(_allowlistPath)) as Map<String, Object?>;
    final unknownChecks = raw.keys
        .where((k) => !k.startsWith('_') && !kitManifestChecks.contains(k))
        .toList();
    expect(
      unknownChecks,
      isEmpty,
      reason: '$_allowlistPath names checks this gate does not run',
    );
    final allowlist = _readAllowlist();
    final violations = kitManifestViolations(manifest);

    final fresh = <String>[];
    final shrunk = <String, List<String>>{};
    final stale = <String>[];
    for (final check in kitManifestChecks) {
      final allowed = allowlist[check] ?? const <String>[];
      final failing = violations[check]!;
      for (final MapEntry(key: subject, value: why) in failing.entries) {
        if (!allowed.contains(subject)) fresh.add('$check · $subject: $why');
      }
      shrunk[check] = [
        for (final subject in allowed)
          if (failing.containsKey(subject)) subject,
      ];
      for (final subject in allowed) {
        if (!failing.containsKey(subject)) stale.add('$check · $subject');
      }
    }

    if (stale.isNotEmpty) {
      final about = raw['_about'] as String? ?? '';
      final encoded = _encodeAllowlist(shrunk, about);
      if (Platform.environment['KIT_MANIFEST_WRITE'] == '1') {
        File(_allowlistPath).writeAsStringSync(encoded);
        stdout.writeln('G4: wrote the smaller $_allowlistPath');
      } else {
        stdout.writeln(
          'G4: these allowlist entries now pass; commit the smaller '
          '$_allowlistPath (or rerun with KIT_MANIFEST_WRITE=1):\n'
          '${stale.map((s) => '  - $s').join('\n')}\n$encoded',
        );
      }
    }

    if (fresh.isNotEmpty) {
      fail(
        '${fresh.length} kit manifest violation(s) break STANDARDS.md G4 '
        '(NAME-1, KIT-10–KIT-14, TEST-9, TEST-14, TEST-15). Fix the part; '
        'the allowlist only shrinks:\n'
        '${fresh.map((f) => '  - $f').join('\n')}',
      );
    }
  });
}
