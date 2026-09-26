// G24 — architecture boundaries (docs/ux-system/revamp/STANDARDS.md §18,
// rules ARCH-1, ARCH-2 and ARCH-10).
//
// A pure-Dart source scan — no widget pumping. Every exception and every
// tolerated count lives in test/architecture_boundaries_baseline.json, never
// in this file, so G31 (baseline only shrinks, never gains a key) polices
// all of them. The sections:
//
// "ARCH-1" (ratchet): per lib/ui file, imports/exports of lib/api/,
//   lib/api2/ and the generated package:opencode_sdk. The UI talks only to
//   lib/domain. Relative and package:opencode_mobile/ URIs are resolved.
// "ARCH-2" (ratchet): per lib/ui file, flavour gating: `ServerFlavor.`, a
//   `.flavor ==`/`!=` comparison, `switch (… flavor …)` (covers the
//   `case .v2:` / `.v2 =>` dot shorthand), `flavor.name`/`flavor.index`,
//   and `flavor case` patterns. The UI gates on ServerCapabilities flags and
//   host kind, never on ServerFlavor.
// "ARCH-2 allowlist" + "ARCH-2 allowlisted" (ratchet): ARCH-2 permits only
//   profile-editor code that sets or labels the flavour, each allowlisted
//   with a reason. The allowlist is per declaration, not per file:
//   "ARCH-2 allowlist" maps file -> member (`Class.member` or a top-level
//   name) -> [reason]; uses inside a listed member are counted in
//   "ARCH-2 allowlisted" under "member: pattern" and ratchet like the rest.
//   Every other use in the same file is debt in "ARCH-2". So new flavour
//   gating in an allowlisted file fails, and so does a new allowlisted
//   member (its count and reason would be new baseline keys).
// "ARCH-10 wire" (ratchet, absolute for new files): per lib file, string
//   literals 'oc/background' (the channel, in any form — constructor,
//   constant, variable) and the notification wire methods 'showCodingAlert'
//   and 'updateLiveStatus'.
// "ARCH-10 calls" (ratchet): per lib file, Dart uses (calls or tear-offs)
//   of `.showCodingAlert`, `.sendTestNotification` and `.publishLiveStatus`.
//   Until slice-P6.7 lands `class NotificationRouter`, no file adds a use.
//   From then the alert methods (showCodingAlert, sendTestNotification) are
//   allowed only in the NotificationRouter file — absolute, regardless of
//   the baseline. publishLiveStatus (the ongoing foreground-service status
//   card, `updateLiveStatus`) is not an alert the router dedupes or cancels
//   on answer (slice-P6.7's non-goal: no router rewrite beyond dedupe and
//   cancel-on-answer), so it stays on the ratchet in both modes: its callers
//   may only shrink and no file adds one.
//
// Comments are stripped before scanning, so prose that mentions a pattern is
// never counted; string contents are kept (import URIs and channel names
// live in strings).
//
// The ratchet: the test fails when a count rises above its baseline, or a
// file/key not in the baseline appears at all. When counts drop it still
// passes, but prints the smaller baseline to commit so the numbers only ever
// go down. Regenerate after a migration lands:
//   ARCH_BOUNDARIES_WRITE=1 flutter test test/architecture_boundaries_test.dart
// (the pinned Flutter from AGENTS.md), rerun without the env var, and commit
// the smaller numbers. Never raise an entry or add one (PROC-13; G31 checks
// this). ARCH_BOUNDARIES_EXPLAIN=1 prints every ARCH-2 use with its line and
// enclosing member.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/architecture_boundaries_baseline.json';
const _packageName = 'opencode_mobile';

const _arch1 = 'ARCH-1';
const _arch2 = 'ARCH-2';
const _arch2Allowlist = 'ARCH-2 allowlist';
const _arch2Allowlisted = 'ARCH-2 allowlisted';
const _arch10Wire = 'ARCH-10 wire';
const _arch10Calls = 'ARCH-10 calls';

/// ARCH-10: the only file that may use the notification wire and channel
/// names is fixed by the "ARCH-10 wire" baseline; these are the names.
const _wireLiterals = ['oc/background', 'showCodingAlert', 'updateLiveStatus'];

/// ARCH-10: Dart methods that post (alert) or update (status) a
/// notification through `oc/background`.
const _alertMethods = ['showCodingAlert', 'sendTestNotification'];
const _statusMethods = ['publishLiveStatus'];

// ---------------------------------------------------------------------------
// Scanner (pure functions, self-tested below).

/// Returns [source] with `//` and `/* */` comments removed (newlines kept, so
/// line numbers hold), leaving string literals intact.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          if (source[i] == '\n') out.write('\n');
          i++;
        }
      }
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < n) {
        if (!raw && source[i] == r'\') {
          out.write(source.substring(i, i + 2 > n ? n : i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(quote, i)) {
          out.write(quote);
          i += quote.length;
          break;
        }
        if (!triple && source[i] == '\n') break;
        out.write(source[i]);
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Returns [code] with every string literal's contents (interpolations
/// included) replaced by spaces, keeping quotes, newlines and length, so
/// braces inside strings never unbalance the declaration scan.
String blankStrings(String code) {
  final out = StringBuffer();
  var i = 0;
  while (i < code.length) {
    final c = code[i];
    if (c == "'" || c == '"') {
      i = _blankString(code, i, out);
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

String _spaces(String s) => s.replaceAll(RegExp(r'[^\n]'), ' ');

int _blankString(String s, int i, StringBuffer out) {
  final c = s[i];
  final raw = i > 0 && s[i - 1] == 'r';
  final triple = s.startsWith(c * 3, i);
  final quote = triple ? c * 3 : c;
  out.write(quote);
  i += quote.length;
  while (i < s.length) {
    if (s.startsWith(quote, i)) {
      out.write(quote);
      return i + quote.length;
    }
    final ch = s[i];
    if (!triple && ch == '\n') return i;
    if (!raw && ch == r'\') {
      final end = i + 2 > s.length ? s.length : i + 2;
      out.write(_spaces(s.substring(i, end)));
      i = end;
      continue;
    }
    if (!raw && ch == r'$' && i + 1 < s.length && s[i + 1] == '{') {
      out.write('  ');
      i += 2;
      var depth = 1;
      while (i < s.length && depth > 0) {
        final d = s[i];
        if (d == "'" || d == '"') {
          final j = _blankString(s, i, StringBuffer());
          out.write(_spaces(s.substring(i, j)));
          i = j;
          continue;
        }
        if (d == '{') depth++;
        if (d == '}') depth--;
        out.write(d == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    out.write(ch == '\n' ? '\n' : ' ');
    i++;
  }
  return i;
}

typedef Declaration = ({int start, int end, String name});

final _classDecl = RegExp(r'\bclass\s+(\w+)');
final _mixinDecl = RegExp(r'\bmixin\s+(\w+)');
final _enumDecl = RegExp(r'\benum\s+(\w+)');
final _extensionTypeDecl = RegExp(r'\bextension\s+type\s+(\w+)');
final _extensionDecl = RegExp(r'\bextension\b\s*(\w+)?');

String? _typeName(String header) {
  for (final re in [_classDecl, _mixinDecl, _enumDecl, _extensionTypeDecl]) {
    final m = re.firstMatch(header);
    if (m != null) return m.group(1);
  }
  final ext = _extensionDecl.firstMatch(header);
  if (ext == null) return null;
  final name = ext.group(1);
  return name == null || name == 'on' ? 'extension' : name;
}

final _annotation = RegExp(r'@[\w$.]+(?:\s*\([^)]*\))?');
final _callHead = RegExp(r'([\w$]+(?:\.[\w$]+)?)\s*(?:<[^()]*>)?\s*\(');
final _getter = RegExp(r'\bget\s+([\w$]+)');
final _lastIdentifier = RegExp(r'([\w$]+)\s*$');

/// The declared name in a member or top-level declaration [header] (the
/// text before its body, `=>` or `=`).
String _memberName(String header) {
  final h = header.replaceAll(_annotation, ' ');
  if (RegExp(r'\boperator\b').hasMatch(h)) return 'operator';
  final getter = _getter.firstMatch(h);
  if (getter != null && !h.substring(0, getter.start).contains('(')) {
    return getter.group(1)!;
  }
  for (final m in _callHead.allMatches(h)) {
    if (m.group(1) != 'Function') return m.group(1)!;
  }
  return _lastIdentifier.firstMatch(h.trimRight())?.group(1) ?? '<anonymous>';
}

/// The top-level and class-level declarations of [code] (comment-stripped),
/// each with its span and qualified name (`Class.member`, or the top-level
/// name). A brace/paren scan that relies on dart-formatted source; string
/// contents are blanked first.
List<Declaration> declarations(String code) {
  final src = blankStrings(code);
  final spans = <Declaration>[];
  // Frames: ('type', name) for class-like bodies, ('member', qualified) for
  // member bodies, ('block', '') for any other brace.
  final stack = <(String, String, int)>[];
  var headerStart = 0;
  var parens = 0;
  var assign = -1;

  String? owner() {
    for (final f in stack.reversed) {
      if (f.$1 == 'type') return f.$2;
    }
    return null;
  }

  String qualify(String name) {
    final o = owner();
    return o == null ? name : '$o.$name';
  }

  void reset(int at) {
    headerStart = at;
    parens = 0;
    assign = -1;
  }

  for (var i = 0; i < src.length; i++) {
    final c = src[i];
    final atDeclLevel = stack.isEmpty || stack.last.$1 == 'type';
    if (atDeclLevel) {
      if (c == '(' || c == '[') {
        parens++;
        continue;
      }
      if (c == ')' || c == ']') {
        if (parens > 0) parens--;
        continue;
      }
      if (parens > 0) continue;
      if (c == '=') {
        final next = i + 1 < src.length ? src[i + 1] : '';
        final prev = i > 0 ? src[i - 1] : '';
        if (next == '>') {
          if (assign < 0) assign = i;
          i++;
        } else if (next == '=') {
          i++;
        } else if (!'!<>'.contains(prev) &&
            assign < 0 &&
            !src.substring(headerStart, i).contains('(')) {
          assign = i;
        }
        continue;
      }
      if (c == ';') {
        final header = src.substring(headerStart, assign < 0 ? i : assign);
        spans.add((
          start: headerStart,
          end: i,
          name: qualify(_memberName(header)),
        ));
        reset(i + 1);
        continue;
      }
      if (c == '{') {
        if (assign >= 0) {
          stack.add(('block', '', i));
          continue;
        }
        final header = src.substring(headerStart, i);
        final type = _typeName(header);
        if (type != null) {
          stack.add(('type', type, i));
          reset(i + 1);
        } else {
          stack.add(('member', qualify(_memberName(header)), headerStart));
        }
        continue;
      }
      if (c == '}') {
        if (stack.isNotEmpty) stack.removeLast();
        reset(i + 1);
      }
      continue;
    }
    if (c == '{') {
      stack.add(('block', '', i));
    } else if (c == '}') {
      final f = stack.removeLast();
      if (f.$1 == 'member') {
        spans.add((start: f.$3, end: i, name: f.$2));
        reset(i + 1);
      }
      // A closing expression brace at declaration level (`=> switch … {}`,
      // a map field) leaves the declaration open until its `;`.
    }
  }
  return spans;
}

/// The qualified name of the declaration enclosing [offset], or `<top>`.
String enclosingMember(List<Declaration> decls, int offset) {
  for (final d in decls) {
    if (d.start <= offset && offset <= d.end) return d.name;
  }
  return '<top>';
}

final _directive = RegExp(r'''\b(?:import|export)\s+(['"])(.+?)\1''');

/// Resolves every import/export URI in [code] (already comment-stripped)
/// declared by the file at repo-relative [path] to a repo-relative path, or
/// returns the URI unchanged for other packages and `dart:` libraries.
List<String> resolvedDirectives(String path, String code) {
  final base = Uri.parse(path);
  return [
    for (final m in _directive.allMatches(code))
      _resolve(base, m.group(2)!.trim()),
  ];
}

String _resolve(Uri base, String uri) {
  final ownPackage = 'package:$_packageName/';
  if (uri.startsWith(ownPackage)) {
    return 'lib/${uri.substring(ownPackage.length)}';
  }
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return uri;
  return base.resolve(uri).path;
}

/// ARCH-1 counts for one lib/ui file: pattern -> count (zeros omitted).
Map<String, int> apiImportCounts(String path, String code) {
  final counts = <String, int>{};
  for (final target in resolvedDirectives(path, code)) {
    final String? key;
    if (target.startsWith('lib/api/')) {
      key = 'lib/api/';
    } else if (target.startsWith('lib/api2/')) {
      key = 'lib/api2/';
    } else if (target.startsWith('package:opencode_sdk/')) {
      key = 'package:opencode_sdk';
    } else {
      key = null;
    }
    if (key != null) counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

final _flavorPatterns = <String, RegExp>{
  'ServerFlavor.': RegExp(r'\bServerFlavor\s*\.'),
  '.flavor ==': RegExp(
    r'\b\w*[Ff]lavor\s*[!=]=|[!=]=\s*(?:[\w?!]+\s*\.\s*)*\w*[Ff]lavor\b(?!\s*[(\w])',
  ),
  // A switch whose subject mentions a flavour; this is how the Dart 3.10
  // dot shorthand (`case .v2:`, `.v2 =>`) branches without naming the type.
  'switch (flavor)': RegExp(r'\bswitch\s*\([^{;]*?[Ff]lavor'),
  'flavor.name/index': RegExp(r'[Ff]lavor\s*\??\.\s*(?:name|index)\b'),
  'flavor case': RegExp(r'[Ff]lavor\s+case\b'),
};

/// ARCH-2 uses in one file: (pattern, offset) in source order.
List<(String, int)> flavorUses(String code) => [
  for (final e in _flavorPatterns.entries)
    for (final m in e.value.allMatches(code)) (e.key, m.start),
];

/// ARCH-2 counts for one lib/ui file: pattern -> count (zeros omitted).
Map<String, int> flavorCounts(String code) {
  final counts = <String, int>{};
  for (final (pattern, _) in flavorUses(code)) {
    counts[pattern] = (counts[pattern] ?? 0) + 1;
  }
  return counts;
}

/// ARCH-2 counts for one file, split into debt and allowlisted members.
/// [allowlist] is that file's member -> reasons from the baseline.
({Map<String, int> debt, Map<String, int> allowed}) splitFlavorCounts(
  String code,
  Set<String> allowlist,
) {
  final debt = <String, int>{};
  final allowed = <String, int>{};
  final uses = flavorUses(code);
  if (uses.isEmpty) return (debt: debt, allowed: allowed);
  final decls = declarations(code);
  for (final (pattern, offset) in uses) {
    final member = enclosingMember(decls, offset);
    if (allowlist.contains(member)) {
      final key = '$member: $pattern';
      allowed[key] = (allowed[key] ?? 0) + 1;
    } else {
      debt[pattern] = (debt[pattern] ?? 0) + 1;
    }
  }
  return (debt: debt, allowed: allowed);
}

final _wireLiteral = RegExp(
  '([\'"])(${_wireLiterals.map(RegExp.escape).join('|')})\\b',
);

/// ARCH-10 wire counts for one lib file: literal -> count.
Map<String, int> wireCounts(String code) {
  final counts = <String, int>{};
  for (final m in _wireLiteral.allMatches(code)) {
    final key = "'${m.group(2)}'";
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

final _notificationUse = RegExp(
  '\\.\\s*(${[..._alertMethods, ..._statusMethods].join('|')})\\b',
);

/// ARCH-10 call counts for one lib file: method -> count (calls and
/// tear-offs alike).
Map<String, int> notificationUseCounts(String code) {
  final counts = <String, int>{};
  for (final m in _notificationUse.allMatches(code)) {
    counts[m.group(1)!] = (counts[m.group(1)!] ?? 0) + 1;
  }
  return counts;
}

final _routerClass = RegExp(r'\bclass\s+NotificationRouter\b');

// ---------------------------------------------------------------------------
// Repository access.

Map<String, String> _dartSources(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const {};
  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return {
    for (final f in files)
      f.path.replaceAll(r'\', '/'): stripComments(f.readAsStringSync()),
  };
}

typedef _Counts = Map<String, Map<String, int>>;

_Counts _scan(
  Map<String, String> sources,
  Map<String, int> Function(String path, String code) count,
) {
  final result = <String, Map<String, int>>{};
  for (final e in sources.entries) {
    final counts = count(e.key, e.value);
    if (counts.isNotEmpty) result[e.key] = counts;
  }
  return result;
}

Map<String, dynamic> _readBaselineJson() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return const {};
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

_Counts _countsSection(Map<String, dynamic> json, String gate) {
  final section = (json[gate] as Map<String, dynamic>?) ?? const {};
  return {
    for (final e in section.entries)
      e.key: {
        for (final p in (e.value as Map<String, dynamic>).entries)
          p.key: p.value as int,
      },
  };
}

/// "ARCH-2 allowlist": file -> member -> [reason]. A list, so that G31's
/// flattening sees every entry (and every reason) as a key that may only
/// disappear, never appear.
Map<String, Map<String, String>> _allowlistSection(Map<String, dynamic> json) {
  final section = (json[_arch2Allowlist] as Map<String, dynamic>?) ?? const {};
  return {
    for (final e in section.entries)
      e.key: {
        for (final m in (e.value as Map<String, dynamic>).entries)
          m.key: (m.value as List).cast<String>().join(' '),
      },
  };
}

String _encode(Map<String, Object> sections) {
  Object sorted(Object value) {
    if (value is Map) {
      final m = value.cast<String, Object>();
      return {for (final k in m.keys.toList()..sort()) k: sorted(m[k]!)};
    }
    return value;
  }

  return '${const JsonEncoder.withIndent('  ').convert(sorted(sections))}\n';
}

/// Compares [actual] with [baseline]; returns the failures and whether any
/// count dropped (so the smaller baseline can be printed).
({List<String> failures, bool shrank}) _compare(
  String gate,
  _Counts actual,
  _Counts baseline,
) {
  final failures = <String>[];
  var shrank = false;
  for (final file in actual.keys) {
    for (final p in actual[file]!.entries) {
      final allowed = baseline[file]?[p.key] ?? 0;
      if (p.value > allowed) {
        failures.add('$gate $file: "${p.key}" x${p.value} (baseline $allowed)');
      } else if (p.value < allowed) {
        shrank = true;
      }
    }
  }
  for (final file in baseline.keys) {
    for (final p in baseline[file]!.entries) {
      if ((actual[file]?[p.key] ?? 0) < p.value) shrank = true;
    }
  }
  return (failures: failures, shrank: shrank);
}

const _advice = {
  _arch1:
      'a lib/ui file gained a forbidden import (new files start at zero). '
      'Talk to lib/domain (ServerGateway, ServerOperationsGateway, '
      'ServerCapabilities) instead of lib/api or lib/api2.',
  _arch2:
      'a lib/ui file gained flavour gating (new files start at zero). Gate '
      'the feature on a ServerCapabilities flag or host kind, not on '
      'ServerFlavor.',
  _arch2Allowlisted:
      'an allowlisted profile-editor member gained flavour uses, or a new '
      'member was allowlisted. The allowlist only shrinks; gate the feature '
      'on a ServerCapabilities flag.',
  _arch10Wire:
      "a file gained the 'oc/background' channel name or a notification wire "
      'method name. Only lib/background/live_background.dart and '
      'lib/background/widget_snapshot.dart talk to that channel.',
  _arch10Calls:
      'a file gained a use of showCodingAlert, sendTestNotification or '
      'publishLiveStatus. No unit adds a notification path (ARCH-10); from '
      'slice-P6.7 alerts go through NotificationRouter.',
};

void main() {
  group('G24 scanner', () {
    test('strips comments but keeps strings', () {
      const src = '''
// import '../api/models.dart';
/* export "../api2/x.dart"; /* nested */ */
final url = 'http://example.com'; // ServerFlavor.v2
''';
      final code = stripComments(src);
      expect(code, isNot(contains('ServerFlavor')));
      expect(code, isNot(contains('../api')));
      expect(code, contains("'http://example.com'"));
    });

    test('resolves relative and package imports', () {
      const src = '''
import '../../api/models.dart';
import "package:opencode_mobile/api2/client.dart" show Client;
export '../../domain/server_gateway.dart';
import 'package:opencode_sdk/opencode_sdk.dart';
import 'package:flutter/widgets.dart';
''';
      expect(apiImportCounts('lib/ui/screens/x.dart', src), {
        'lib/api/': 1,
        'lib/api2/': 1,
        'package:opencode_sdk': 1,
      });
      expect(apiImportCounts('lib/ui/x.dart', "import '../api/a.dart';"), {
        'lib/api/': 1,
      });
      expect(
        apiImportCounts('lib/ui/x.dart', "import '../domain/a.dart';"),
        isEmpty,
      );
    });

    test('counts flavour gating', () {
      const src = '''
if (conn.serverFlavor == ServerFlavor.v2) {}
if (other.flavor != profile.flavor) {}
if (profile.flavor ==
    flavor) {}
final label = describeFlavor(profile.flavor);
''';
      expect(flavorCounts(src), {'ServerFlavor.': 1, '.flavor ==': 3});
      expect(flavorCounts('final x = capabilities.supportsDiffs;'), isEmpty);
    });

    test('counts Dart 3.10 flavour branches (dot shorthand, name, case)', () {
      const src = '''
final a = switch (profile.flavor) { .v2 => 'two', _ => 'one' };
switch (conn.serverFlavor) {
  case .v2:
    break;
}
final b = switch (flavorOf(profile)) { _ => 0 };
if (profile.flavor.name == 'v2') {}
if (p.flavor?.index == 1) {}
if (p.flavor case .v2) {}
''';
      expect(flavorCounts(src), {
        'switch (flavor)': 3,
        'flavor.name/index': 2,
        'flavor case': 1,
      });
      expect(
        flavorCounts("switch (kind) { case .phone: label = 'flavor'; }"),
        isEmpty,
      );
    });

    test('names the declaration that encloses each use', () {
      const src = r'''
import 'x.dart';

ServerFlavor? topLevel(Profile p) {
  if (p.flavor == ServerFlavor.v2) return ServerFlavor.v2;
  return null;
}

String label(Profile p) => switch (p.flavor) {
  ServerFlavor.v2 => 'two ${p.name} }',
  _ => '{',
};

class _EditorState extends State<Editor> {
  final _map = <String, int>{'a': 1};
  ServerFlavor get flavor => ServerFlavor.v1;

  _EditorState(this.x) : y = x;

  Future<void> save({bool force = false}) async {
    final f = () {
      return ServerFlavor.v2;
    };
  }

  @override
  Widget build(BuildContext context) {
    return Text(flavor == ServerFlavor.v2 ? 'two' : 'one');
  }
}

enum Mode { a, b; bool get isA => this == Mode.a; }

extension on Profile {
  bool get isTwo => flavor == ServerFlavor.v2;
}
''';
      final code = stripComments(src);
      final decls = declarations(code);
      List<String> membersOf(String needle) => [
        for (final m in RegExp(RegExp.escape(needle)).allMatches(code))
          enclosingMember(decls, m.start),
      ];
      expect(membersOf('ServerFlavor.'), [
        'topLevel',
        'topLevel',
        'label',
        '_EditorState.flavor',
        '_EditorState.save',
        '_EditorState.build',
        'extension.isTwo',
      ]);
      expect(membersOf('Mode.a'), ['Mode.isA']);
      final split = splitFlavorCounts(code, {'_EditorState.build'});
      expect(split.allowed, {
        '_EditorState.build: ServerFlavor.': 1,
        '_EditorState.build: .flavor ==': 1,
      });
      expect(split.debt['ServerFlavor.'], 6);
    });

    test('ARCH-10 counts every form of the channel and methods', () {
      const src = '''
const name = 'oc/background';
final channel = MethodChannel(name);
final a = MethodChannel("oc/background");
channel.invokeMethod('showCodingAlert', {});
channel.invokeMethod("updateLiveStatus");
final post = live.showCodingAlert;
live.sendTestNotification();
unawaited(live
    .publishLiveStatus(status));
void _publishLiveStatus() {}
''';
      expect(wireCounts(src), {
        "'oc/background'": 2,
        "'showCodingAlert'": 1,
        "'updateLiveStatus'": 1,
      });
      expect(notificationUseCounts(src), {
        'showCodingAlert': 1,
        'sendTestNotification': 1,
        'publishLiveStatus': 1,
      });
    });
  });

  group('G24 architecture boundaries', () {
    final ui = _dartSources('lib/ui');
    final lib = _dartSources('lib');
    final write = Platform.environment['ARCH_BOUNDARIES_WRITE'] == '1';
    final explain = Platform.environment['ARCH_BOUNDARIES_EXPLAIN'] == '1';
    final json = _readBaselineJson();
    final allowlist = _allowlistSection(json);

    final arch1 = _scan(ui, apiImportCounts);
    final arch2 = <String, Map<String, int>>{};
    final arch2Allowed = <String, Map<String, int>>{};
    for (final e in ui.entries) {
      final split = splitFlavorCounts(
        e.value,
        allowlist[e.key]?.keys.toSet() ?? const {},
      );
      if (split.debt.isNotEmpty) arch2[e.key] = split.debt;
      if (split.allowed.isNotEmpty) arch2Allowed[e.key] = split.allowed;
      if (explain) {
        final decls = declarations(e.value);
        for (final (pattern, offset) in flavorUses(e.value)) {
          final line = '\n'.allMatches(e.value.substring(0, offset)).length + 1;
          final member = enclosingMember(decls, offset);
          final kind = allowlist[e.key]?.containsKey(member) == true
              ? 'allowlisted'
              : 'debt';
          stdout.writeln('ARCH-2 ${e.key}:$line $member "$pattern" $kind');
        }
      }
    }

    final routerFiles = [
      for (final e in lib.entries)
        if (_routerClass.hasMatch(e.value)) e.key,
    ];
    final routerMode = routerFiles.isNotEmpty;
    final arch10Wire = _scan(lib, (_, code) => wireCounts(code));
    final arch10Uses = _scan(lib, (_, code) => notificationUseCounts(code));
    // In router mode the alert methods leave the ratchet: they are absolute
    // (router file only, checked below); publishLiveStatus stays ratcheted.
    final arch10Calls = <String, Map<String, int>>{
      for (final e in arch10Uses.entries)
        if (!routerMode)
          e.key: e.value
        else if (e.value.keys.any(_statusMethods.contains))
          e.key: {
            for (final m in e.value.entries)
              if (_statusMethods.contains(m.key)) m.key: m.value,
          },
    };

    // Reasons survive only while their member still has uses (a shrink).
    final keptAllowlist = <String, Map<String, List<String>>>{
      for (final e in allowlist.entries)
        if (e.value.keys.any(
          (m) =>
              arch2Allowed[e.key]?.keys.any((k) => k.startsWith('$m: ')) ==
              true,
        ))
          e.key: {
            for (final m in e.value.entries)
              if (arch2Allowed[e.key]!.keys.any(
                (k) => k.startsWith('${m.key}: '),
              ))
                m.key: [m.value],
          },
    };
    final regenerated = <String, Object>{
      _arch1: arch1,
      _arch2: arch2,
      _arch2Allowlist: keptAllowlist,
      _arch2Allowlisted: arch2Allowed,
      _arch10Wire: arch10Wire,
      _arch10Calls: arch10Calls,
    };

    if (write) {
      File(_baselinePath).writeAsStringSync(_encode(regenerated));
    }

    void check(String gate, _Counts actual) {
      final result = _compare(gate, actual, _countsSection(json, gate));
      if (result.shrank && result.failures.isEmpty) {
        stdout.writeln(
          '$gate counts dropped. Commit the smaller baseline '
          '(ARCH_BOUNDARIES_WRITE=1 regenerates $_baselinePath):\n'
          '${_encode(regenerated)}',
        );
      }
      expect(result.failures, isEmpty, reason: '$gate: ${_advice[gate]}');
    }

    test('ARCH-1: lib/ui never imports lib/api/ or lib/api2/', () {
      expect(ui, isNotEmpty, reason: 'run from the package root');
      check(_arch1, arch1);
    });

    test('ARCH-2: lib/ui never gates on ServerFlavor', () {
      check(_arch2, arch2);
    });

    test('ARCH-2: allowlisted profile-editor uses only shrink', () {
      check(_arch2Allowlisted, arch2Allowed);
    });

    test('ARCH-2: every allowlisted member exists and gives a reason', () {
      final failures = <String>[];
      for (final e in allowlist.entries) {
        if (!e.key.startsWith('lib/ui/') || !File(e.key).existsSync()) {
          failures.add('${e.key}: not an existing lib/ui file');
        }
        for (final m in e.value.entries) {
          if (m.value.trim().length < 20) {
            failures.add('${e.key} ${m.key}: no reason given');
          }
        }
      }
      for (final e in _countsSection(json, _arch2Allowlisted).entries) {
        for (final key in e.value.keys) {
          final member = key.split(': ').first;
          if (allowlist[e.key]?.containsKey(member) != true) {
            failures.add(
              '${e.key} "$key": counted as allowlisted but "$member" has '
              'no reason in "$_arch2Allowlist"',
            );
          }
        }
      }
      for (final e in allowlist.entries) {
        for (final member in e.value.keys) {
          final used =
              arch2Allowed[e.key]?.keys.any((k) => k.startsWith('$member: ')) ==
              true;
          if (!used) {
            stdout.writeln(
              '${e.key} $member: no flavour use left; '
              'ARCH_BOUNDARIES_WRITE=1 drops the allowlist entry.',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: 'ARCH-2 allowlist (G24)');
    });

    test('ARCH-10: the oc/background wire names stay with their owners', () {
      check(_arch10Wire, arch10Wire);
    });

    test('ARCH-10: notifications have one posting path', () {
      expect(
        routerFiles.length,
        lessThanOrEqualTo(1),
        reason: 'more than one NotificationRouter: $routerFiles',
      );
      if (routerMode) {
        final router = routerFiles.single;
        final failures = [
          for (final e in arch10Uses.entries)
            if (e.key != router)
              for (final m in e.value.keys)
                if (_alertMethods.contains(m))
                  '${e.key}: uses .$m directly; only $router '
                      '(NotificationRouter) may post an alert',
        ];
        expect(failures, isEmpty, reason: 'ARCH-10 (G24, from slice-P6.7)');
      }
      check(_arch10Calls, arch10Calls);
    });
  });
}
