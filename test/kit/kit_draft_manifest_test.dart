// Gate G10 manifest (docs/ux-system/kit-v2.md §7, STANDARDS.md §18 G10,
// DATA-1–DATA-4): what `test/kit/kit_draft_test.dart` proves for one sheet,
// held for every sheet and every draft in lib/.
//
// A pure source scan plus one behavioural sweep; it complements the G48 row
// of `test/kit_ratchet_test.dart`, which counts per file (a file with any
// `draft:` passes, and a field built in another file is not seen):
//
// 1. Sheets: every `showKitSheet(`, `showModalBottomSheet(` and
//    `showConfirmSheet(` call whose content — the call itself and the widget
//    classes it builds, followed through lib/ three levels deep — has a
//    multiline field keeps a draft: the call passes `draft:`, the class with
//    the field makes its own `KitDraft(`, or a class that forwards
//    `widget.draft` is built with `draft:`. Sites that predate this gate sit
//    in `kit_draft_manifest_baseline.json` (file -> count, with the owning
//    slice); a count may only go down, and a file may not be added.
// 2. Draft targets: every `KitDraft(` in lib/ names its target as a string
//    whose first segment is a fixed lowercase namespace (`note.$sessionId`,
//    `team-gate.$gateId`), traced through the helper, variable or parameter
//    that builds it, and its `profileId:` is not a bare literal. A target
//    made only of runtime text, or a draft shared by every profile, could not
//    be swept with the profile.
// 3. Sweep: for every traced target, the key `KitDraft.keyFor` makes
//    (`oc.draft.<target>.<profileId>`) is found and removed by
//    `ProfileStore.profileScopedPreferenceKeys`/`removeScopedPreferences`
//    for its profile, and another profile's draft for the same target stays.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baselinePath = 'test/kit/kit_draft_manifest_baseline.json';

/// Drafts that belong to the app, not a server (`profileId:
/// KitDraft.appWide`): target -> why. No profile sweep removes them, so each
/// one is named here with its reason, and nothing else may use the app id.
const _appWideDrafts = <String, String>{
  'report-problem':
      'Report a problem describes the app and also opens with no server '
      '(a failure\'s details); one draft for every entry point, cleared when '
      'the report is sent (app_diagnostics_screen.dart)',
};

/// The baseline when the gate was made (2026-09-27): file -> count. The
/// committed baseline may only shrink from it (KIT-5).
const _creationCeiling = <String, int>{'lib/voice/voice_ui.dart': 1};

const _sheetOpeners = [
  'showKitSheet',
  'showModalBottomSheet',
  'showConfirmSheet',
];

final _multiline = RegExp(
  r'KitFieldKind\.multiline|\bmaxLines:\s*null\b|\bminLines:',
);
final _construct = RegExp(r'\b(_?[A-Z]\w*)(?:\.\w+)?\s*(?:<[^()]*?>)?\s*\(');
final _namespace = RegExp(r'^[a-z][A-Za-z0-9-]*(?:\.|\$|$)');
const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

// --- source model -------------------------------------------------------

/// One Dart file: [code] has comments blanked, [masked] also blanks string
/// contents (quotes kept), both the same length as the source.
class DraftSource {
  DraftSource(this.path, String source)
    : code = _blank(source, strings: false),
      masked = _blank(source, strings: true);

  final String path;
  final String code;
  final String masked;

  int lineOf(int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;
}

/// Blanks comments (and, with [strings], string contents) to spaces,
/// keeping newlines and length.
String _blank(String s, {required bool strings}) {
  final out = StringBuffer();
  var i = 0;
  void keep(int n) {
    out.write(s.substring(i, i + n));
    i += n;
  }

  void blank(int n, {bool keepNewlines = true}) {
    for (var k = 0; k < n; k++) {
      final c = s[i + k];
      out.write(c == '\n' && keepNewlines ? '\n' : ' ');
    }
    i += n;
  }

  while (i < s.length) {
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      blank((end < 0 ? s.length : end) - i);
    } else if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      blank((end < 0 ? s.length : end + 2) - i);
    } else if (s[i] == "'" || s[i] == '"') {
      final raw = i > 0 && s[i - 1] == 'r';
      final triple = s.startsWith(s[i] * 3, i);
      final quote = triple ? s[i] * 3 : s[i];
      keep(quote.length);
      var j = i;
      var depth = 0;
      while (j < s.length) {
        if (depth == 0 && s.startsWith(quote, j)) break;
        if (!raw && s[j] == r'\') {
          j += 2;
          continue;
        }
        if (!raw && s.startsWith(r'${', j)) {
          depth++;
          j += 2;
          continue;
        }
        if (depth > 0 && s[j] == '}') depth--;
        if (!triple && depth == 0 && s[j] == '\n') break;
        j++;
      }
      if (strings) {
        blank(j - i);
      } else {
        keep(j - i);
      }
      if (i < s.length && s.startsWith(quote, i)) keep(quote.length);
    } else {
      keep(1);
    }
  }
  return out.toString();
}

/// Index of the bracket closing the one at [open] in [masked].
int _close(String masked, int open) {
  final opening = masked[open];
  final closing = switch (opening) {
    '(' => ')',
    '{' => '}',
    '[' => ']',
    _ => throw ArgumentError(opening),
  };
  var depth = 0;
  for (var i = open; i < masked.length; i++) {
    final c = masked[i];
    if (c == opening) depth++;
    if (c == closing && --depth == 0) return i;
  }
  return masked.length - 1;
}

/// Top-level named arguments of the call whose `(` is at [open]:
/// name -> argument text (from `code`, strings intact).
Map<String, String> _namedArgs(DraftSource f, int open) {
  final end = _close(f.masked, open);
  final args = <String, String>{};
  final positional = <String>[];
  var depth = 0;
  var start = open + 1;
  void flush(int stop) {
    final raw = f.code.substring(start, stop).trim();
    if (raw.isEmpty) return;
    final m = RegExp(r'^(\w+)\s*:(?!:)\s*([\s\S]*)$').firstMatch(raw);
    if (m != null && !raw.startsWith(RegExp(r'''['"]'''))) {
      args[m[1]!] = m[2]!.trim();
    } else {
      positional.add(raw);
    }
  }

  for (var i = open; i <= end; i++) {
    final c = f.masked[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if ((c == ',' && depth == 1) || i == end) {
      flush(i);
      start = i + 1;
    }
  }
  for (var k = 0; k < positional.length; k++) {
    args['#$k'] = positional[k];
  }
  return args;
}

/// A class in lib/ with its State's body merged in.
class _Class {
  _Class(this.name, this.file, this.body);
  final String name;
  final DraftSource file;
  String body; // masked
}

/// The kit field itself: whether it is multiline is its caller's argument.
const _fieldParts = {'KitField', 'TextField', 'TextFormField'};

/// The G10 manifest over [files].
class DraftManifest {
  DraftManifest(this.files) {
    final states = <String, String>{};
    for (final f in files) {
      for (final m in RegExp(
        r'\bclass\s+(_?\w+)\b([^{]*)\{',
      ).allMatches(f.masked)) {
        final open = m.end - 1;
        final body = f.masked.substring(open, _close(f.masked, open) + 1);
        final owner = RegExp(r'extends\s+State<(\w+)>').firstMatch(m[2]!)?[1];
        if (owner != null) {
          states['${f.path}#$owner'] = body;
          continue;
        }
        _byName.putIfAbsent(m[1]!, () => []).add(_Class(m[1]!, f, body));
      }
    }
    for (final entry in states.entries) {
      final [path, owner] = entry.key.split('#');
      for (final c in _byName[owner] ?? const <_Class>[]) {
        if (c.file.path == path) c.body += entry.value;
      }
    }
  }

  final List<DraftSource> files;
  final _byName = <String, List<_Class>>{};

  List<_Class> _resolveClass(String name, DraftSource from) {
    if (_fieldParts.contains(name)) return const [];
    final all = _byName[name] ?? const <_Class>[];
    return [
      for (final c in all)
        if (!name.startsWith('_') || c.file.path == from.path) c,
    ];
  }

  /// Multiline fields inside a sheet with no draft, one line each.
  List<String> sheetViolations() {
    final found = <String>[];
    for (final f in files) {
      for (final opener in _sheetOpeners) {
        for (final m in RegExp(
          '\\b$opener\\s*(?:<[^()]*?>)?\\s*\\(',
        ).allMatches(f.masked)) {
          if (RegExp(
            r'(?:Future|void|\w>)\s+$',
          ).hasMatch(f.masked.substring(0, m.start).split('\n').last)) {
            continue; // the opener's own declaration
          }
          final open = m.end - 1;
          final span = f.masked.substring(open, _close(f.masked, open) + 1);
          // A draft on the sheet keeps everything typed inside it.
          if (_namedArgs(f, open).containsKey('draft')) continue;
          final problem = _problem(span, f, f.path, 0, false, <String>{});
          if (problem != null) {
            found.add('${f.path}:${f.lineOf(m.start)} $opener: $problem');
          }
        }
      }
    }
    return found;
  }

  /// Why [text] (a sheet call, or the body of a class it builds, whose
  /// construction passed a draft when [callerDraft]) has a multiline field
  /// without a draft, or null.
  String? _problem(
    String text,
    DraftSource f,
    String where,
    int depth,
    bool callerDraft,
    Set<String> seen,
  ) {
    final constructs = _construct.allMatches(text).toList();
    for (final marker in _multiline.allMatches(text)) {
      // The field: the innermost construction around the marker.
      String? field;
      for (final c in constructs) {
        final open = c.end - 1;
        final close = _close(text, open);
        if (open < marker.start && marker.start < close) {
          field = text.substring(open, close + 1);
        }
      }
      field ??= text;
      final forwards = RegExp(r'\bdraft:\s*widget\.draft\b').hasMatch(field);
      final own = RegExp(
        r'\bdraft:(?!\s*(?:widget\.draft|null)\b)',
      ).hasMatch(field);
      final draftController = RegExp(
        r'controller:\s*[\w.!?]*[dD]raft\w*[!?]?\.controller',
      ).hasMatch(field);
      final kept =
          own ||
          (forwards && callerDraft) ||
          draftController ||
          text.contains('KitDraft(');
      if (!kept) {
        return depth == 0
            ? 'a multiline field with no draft'
            : '$where has a multiline field with no draft';
      }
    }
    if (depth >= 3) return null;
    for (final m in constructs) {
      for (final c in _resolveClass(m[1]!, f)) {
        if (!seen.add('${c.file.path}#${c.name}')) continue;
        final open = m.end - 1;
        final passes = RegExp(
          r'\bdraft:(?!\s*null\b)',
        ).hasMatch(text.substring(open, _close(text, open) + 1));
        final deeper = _problem(
          c.body,
          c.file,
          '${c.name} (${c.file.path})',
          depth + 1,
          passes,
          seen,
        );
        if (deeper != null) return deeper;
      }
    }
    return null;
  }

  /// Every `KitDraft(` site: where, its traced target literals and any
  /// problem with its target or profile.
  List<DraftSite> draftSites() => [
    for (final f in files)
      for (final m in RegExp(r'\bKitDraft\s*\(').allMatches(f.masked))
        if (!RegExp(
          r'const\s+$|class\s+$',
        ).hasMatch(f.masked.substring(0, m.start)))
          _site(f, m.start, m.end - 1),
  ];

  DraftSite _site(DraftSource f, int at, int open) {
    final args = _namedArgs(f, open);
    final where = '${f.path}:${f.lineOf(at)}';
    final target = args['target'];
    final profile = args['profileId'];
    final problems = <String>[];
    final literals = target == null ? <String>{} : _trace(target, f, 0);
    if (target == null) problems.add('no target');
    if (target != null && literals.isEmpty) {
      problems.add('target "$target" is not traced to a string literal');
    }
    for (final l in literals) {
      if (!_namespace.hasMatch(l)) {
        problems.add('target "$l" does not start with a fixed namespace');
      }
    }
    if (profile == null) {
      problems.add('no profileId');
    } else if (RegExp(r'''^r?['"]''').hasMatch(profile)) {
      problems.add('profileId is the literal $profile, not the profile');
    } else if (RegExp(r'''\?\?\s*r?['"]''').hasMatch(profile)) {
      // `profile?.id ?? 'app'`: a draft saved with no profile is keyed to
      // no profile, so no deletion sweep ever finds it.
      problems.add(
        'profileId falls back to a literal ($profile): a draft saved '
        'without a profile is never swept — use the profile, or '
        'KitDraft.appWide listed in _appWideDrafts',
      );
    } else if (profile.trim() == 'KitDraft.appWide') {
      for (final l in literals) {
        if (!_appWideDrafts.containsKey(l)) {
          problems.add(
            'target "$l" uses KitDraft.appWide but is not in _appWideDrafts '
            '(an app-wide draft names its reason there)',
          );
        }
      }
    }
    return DraftSite(where, literals, problems);
  }

  /// The string literals [expr] is built from, or empty when untraceable.
  Set<String> _trace(String expr, DraftSource f, int depth) {
    // Adjacent literals ('a.' 'b') are one string.
    expr = expr.trim().replaceAll(RegExp('\'\\s+\'|"\\s+"'), '');
    final literal = RegExp(r'''^r?(['"])([\s\S]*)\1$''').firstMatch(expr);
    if (literal != null) return {literal[2]!};
    if (depth > 4) return {};
    final name = RegExp(
      r'^([\w.]+?)\s*(?:\(|$)',
    ).firstMatch(expr)?[1]?.split('.').last;
    if (name == null) return {};
    final e = RegExp.escape(name);
    final defs = [
      RegExp('\\b$e\\s*\\([^()]*\\)\\s*=>\\s*([^;]+);'),
      RegExp(
        '\\b(?:final|const|var|String\\??)\\s+(?:String\\??\\s+)?$e\\s*=\\s*([^;]+);',
      ),
    ];
    for (final source in [f, ...files.where((o) => o != f)]) {
      for (final def in defs) {
        for (final m in def.allMatches(source.masked)) {
          // Group 1 runs up to the closing `;` (same offsets in both views).
          final end = m.end - 1;
          final text = source.code.substring(end - m[1]!.length, end);
          final traced = _trace(text, source, depth + 1);
          if (traced.isNotEmpty) return traced;
        }
      }
      if (source != f) continue;
      // A parameter: trace what the enclosing helper's callers pass.
      for (final m in RegExp(
        '\\b(\\w+)\\s*\\(([^()]*\\bString\\??\\s+$e\\b[^()]*)\\)\\s*(?:async\\s*)?[{=]',
      ).allMatches(f.masked)) {
        final helper = m[1]!;
        final params = m[2]!.replaceAll(RegExp(r'[{}\[\]]'), '').split(',');
        final index = params.indexWhere(
          (p) => RegExp('\\b$e\\s*\$').hasMatch(p.trim()),
        );
        final named = m[2]!.contains('{');
        final found = <String>{};
        for (final call in RegExp('\\b$helper\\s*\\(').allMatches(f.masked)) {
          if (call.start == m.start) continue;
          final args = _namedArgs(f, call.end - 1);
          final arg = named ? args[name] : args['#$index'];
          if (arg != null) found.addAll(_trace(arg, f, depth + 1));
        }
        if (found.isNotEmpty) return found;
      }
    }
    return {};
  }
}

class DraftSite {
  DraftSite(this.where, this.targets, this.problems);
  final String where;
  final Set<String> targets;
  final List<String> problems;
}

List<DraftSource> _libFiles() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      DraftSource(f.path.replaceAll(r'\', '/'), f.readAsStringSync()),
  ];
}

Map<String, int> _counts(List<String> violations) {
  final counts = <String, int>{};
  for (final v in violations) {
    final path = v.substring(0, v.indexOf(':'));
    counts[path] = (counts[path] ?? 0) + 1;
  }
  return counts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = DraftManifest(_libFiles());

  group('G10 manifest on lib/', () {
    test('every sheet with a multiline field keeps a draft '
        '(baseline only shrinks)', () {
      final violations = manifest.sheetViolations();
      final counts = _counts(violations);
      final baseline =
          (jsonDecode(File(_baselinePath).readAsStringSync())
                  as Map<String, dynamic>)['sheets']
              as Map<String, dynamic>;
      final failures = <String>[];
      for (final MapEntry(key: path, value: entry) in baseline.entries) {
        final allowed = (entry as Map<String, dynamic>)['count'] as int;
        final owner = entry['owner'] as String? ?? '';
        if (owner.length < 3) failures.add('$path: baseline names no owner');
        if (allowed > (_creationCeiling[path] ?? 0)) {
          failures.add('$path: baseline $allowed is above the ceiling');
        }
        final now = counts[path] ?? 0;
        if (now < allowed) {
          failures.add(
            '$path: $now now, baseline $allowed — shrink the baseline',
          );
        }
      }
      for (final MapEntry(key: path, value: now) in counts.entries) {
        final allowed =
            (baseline[path] as Map<String, dynamic>?)?['count'] as int? ?? 0;
        if (now > allowed) {
          failures.add(
            '$path: $now multiline sheet field(s) without a draft '
            '(baseline $allowed) — pass draft: KitDraft (DATA-2, G10):\n  '
            '${violations.where((v) => v.startsWith('$path:')).join('\n  ')}',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    final sites = manifest.draftSites();

    test('the scan finds the drafts lib/ makes', () {
      expect(sites.length, greaterThanOrEqualTo(10));
    });

    test('every draft target starts with a fixed namespace and its '
        'profileId is the profile (DATA-4)', () {
      final problems = [
        for (final s in sites)
          for (final p in s.problems) '${s.where}: $p',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('every app-wide draft is built with KitDraft.appWide, and no '
        'profile sweep takes it', () async {
      final appWide = {
        for (final s in sites)
          for (final t in s.targets)
            if (_appWideDrafts.containsKey(t)) t: s.where,
      };
      expect(appWide.keys.toSet(), _appWideDrafts.keys.toSet());
      for (final MapEntry(key: target, value: where) in appWide.entries) {
        final source = File(where.split(':').first).readAsStringSync();
        expect(
          source,
          contains('KitDraft.appWide'),
          reason: '$where: "$target" is app-wide',
        );
      }
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final target in _appWideDrafts.keys) {
        final key = KitDraft.keyFor(target, KitDraft.appWide);
        expect(key, 'oc.draft.$target.app');
        await prefs.setString(key, 'about the app');
        final store = ProfileStore(prefs: prefs);
        expect(
          store.profileScopedPreferenceKeys('prof-a'),
          isNot(contains(key)),
        );
      }
    });

    group('the profile deletion sweep removes every draft target', () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              _secure,
              (call) async =>
                  call.method == 'readAll' ? <String, String>{} : null,
            );
      });
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_secure, null);
      });

      final targets = {
        for (final s in sites)
          for (final t in s.targets)
            t
                    .replaceAll(RegExp(r'\$\{[^}]*\}'), 'id1')
                    .replaceAll(RegExp(r'\$\w+'), 'id1'):
                s.where,
      };
      for (final MapEntry(key: target, value: where) in targets.entries) {
        test('$target ($where)', () async {
          final prefs = await SharedPreferences.getInstance();
          final mine = KitDraft.keyFor(target, 'prof-a');
          final theirs = KitDraft.keyFor(target, 'prof-b');
          expect(mine, 'oc.draft.$target.prof-a');
          await prefs.setString(mine, 'half a thought');
          await prefs.setString(theirs, 'other server');
          final store = ProfileStore(prefs: prefs);
          expect(store.profileScopedPreferenceKeys('prof-a'), contains(mine));
          expect(
            store.profileScopedPreferenceKeys('prof-a'),
            isNot(contains(theirs)),
          );
          expect(await store.removeScopedPreferences('prof-a'), isEmpty);
          expect(prefs.getString(mine), isNull);
          expect(prefs.getString(theirs), 'other server');
        });
      }
    });
  });

  group('G10 manifest on fixtures (proves the checks)', () {
    DraftManifest of(Map<String, String> files) => DraftManifest([
      for (final MapEntry(:key, :value) in files.entries)
        DraftSource(key, value),
    ]);

    test('a sheet with a multiline field and no draft fails', () {
      final m = of({
        'lib/a.dart': '''
void open(BuildContext context) {
  // showKitSheet(context, draft: d) in a comment does not count
  showKitSheet<void>(context, title: 'Note', body: (_) =>
      const KitField(label: 'Note', kind: KitFieldKind.multiline));
}
''',
      });
      expect(m.sheetViolations(), [
        'lib/a.dart:3 showKitSheet: a multiline field with no draft',
      ]);
    });

    test('the same sheet with draft: passes; a one-line field passes', () {
      final m = of({
        'lib/a.dart': '''
void open(BuildContext context, KitDraft d) {
  showKitSheet<void>(context, title: 'Note', draft: d, body: (_) =>
      KitField(label: 'Note', controller: d.controller, kind: KitFieldKind.multiline));
  showKitSheet<void>(context, title: 'Name', body: (_) => const KitField(label: 'Name'));
}
''',
      });
      expect(m.sheetViolations(), isEmpty);
    });

    test('one file, two sheets: the draft of one does not keep the other '
        '(what the per-file G48 row cannot see)', () {
      final m = of({
        'lib/a.dart': '''
void open(BuildContext context, KitDraft d) {
  showKitSheet<void>(context, title: 'Kept', draft: d, body: (_) =>
      KitField(label: 'A', kind: KitFieldKind.multiline));
  showKitSheet<void>(context, title: 'Lost', body: (_) =>
      KitField(label: 'B', maxLines: null));
}
''',
      });
      expect(m.sheetViolations(), hasLength(1));
      expect(m.sheetViolations().single, startsWith('lib/a.dart:4 '));
    });

    test('a field built in another file is followed', () {
      final m = of({
        'lib/a.dart': '''
import 'b.dart';
void open(BuildContext context) {
  showKitSheet<void>(context, title: 'Reply', body: (_) => const ReplyForm());
}
''',
        'lib/b.dart': '''
class ReplyForm extends StatefulWidget {
  const ReplyForm({super.key});
  @override
  State<ReplyForm> createState() => _ReplyFormState();
}
class _ReplyFormState extends State<ReplyForm> {
  final _text = TextEditingController();
  @override
  Widget build(BuildContext context) => _Inner(controller: _text);
}
class _Inner extends StatelessWidget {
  const _Inner({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) =>
      KitField(label: 'Reply', controller: controller, minLines: 3);
}
''',
      });
      expect(m.sheetViolations(), [
        'lib/a.dart:3 showKitSheet: _Inner (lib/b.dart) has a multiline '
            'field with no draft',
      ]);
    });

    test('a class that makes its own KitDraft keeps the sheet', () {
      final m = of({
        'lib/a.dart': '''
void open(BuildContext context) {
  showKitSheet<void>(context, title: 'Reply', body: (_) => const _Form());
}
class _Form extends StatefulWidget {
  const _Form();
  @override
  State<_Form> createState() => _FormState();
}
class _FormState extends State<_Form> {
  late final _draft = KitDraft(target: 'reply', profileId: widget.id, controller: c);
  @override
  Widget build(BuildContext context) =>
      KitField(label: 'Reply', draft: _draft, kind: KitFieldKind.multiline);
}
''',
      });
      expect(m.sheetViolations(), isEmpty);
    });

    test('a field that forwards widget.draft needs the caller to pass one', () {
      const field = '''
class MessageField extends StatelessWidget {
  const MessageField({super.key, this.draft});
  final KitDraft? draft;
  @override
  Widget build(BuildContext context) => KitField(
    label: 'Message', kind: KitFieldKind.multiline, draft: widget.draft);
}
''';
      final lost = of({
        'lib/f.dart': field,
        'lib/a.dart': '''
void open(BuildContext context) {
  showKitSheet<void>(context, title: 'Send', body: (_) => const MessageField());
}
''',
      });
      expect(lost.sheetViolations(), hasLength(1));
      final kept = of({
        'lib/f.dart': field,
        'lib/a.dart': '''
void open(BuildContext context, KitDraft d) {
  showKitSheet<void>(context, title: 'Send', body: (_) => MessageField(draft: d));
}
''',
      });
      expect(kept.sheetViolations(), isEmpty);
    });

    test('draft targets are traced through helpers, variables and '
        'parameters', () {
      final m = of({
        'lib/a.dart': r'''
String gateTarget(String id) => 'team-gate.$id';
const objectiveTarget = 'team-run.objective';
class _S {
  late final a = KitDraft(target: gateTarget(g.id), profileId: p.id, controller: c);
  late final b = KitDraft(target: 'note.${s.id}.'
      '${path}', profileId: p.id, controller: c);
  late final c1 = _draft(objectiveTarget, c);
  KitDraft _draft(String target, TextEditingController c) =>
      KitDraft(target: target, profileId: p.id, controller: c);
  void d() {
    final t = gateTarget(x);
    KitDraft(target: t, profileId: p.id, controller: c);
  }
}
''',
      });
      final sites = m.draftSites();
      expect(sites.map((s) => s.problems), everyElement(isEmpty));
      expect(sites.map((s) => s.targets).toList(), [
        {r'team-gate.$id'},
        {r'note.${s.id}.${path}'},
        {'team-run.objective'},
        {r'team-gate.$id'},
      ]);
    });

    test('a target of runtime text only, or a literal profile, fails', () {
      final m = of({
        'lib/a.dart': r'''
final a = KitDraft(target: server.title, profileId: p.id, controller: c);
final b = KitDraft(target: '${gate.id}.reply', profileId: p.id, controller: c);
final c2 = KitDraft(target: 'reply', profileId: 'default', controller: c);
''',
      });
      final problems = m.draftSites().map((s) => s.problems.join()).toList();
      expect(problems[0], contains('not traced to a string literal'));
      expect(problems[1], contains('does not start with a fixed namespace'));
      expect(problems[2], contains('profileId is the literal'));
    });

    test('a profile that falls back to a literal fails; KitDraft.appWide '
        'passes only for a listed target', () {
      final m = of({
        'lib/a.dart': r'''
final a = KitDraft(target: 'report-problem', profileId: widget.controller?.profile?.id ?? 'app', controller: c);
final b = KitDraft(target: 'note.$id', profileId: KitDraft.appWide, controller: c);
final c2 = KitDraft(target: 'report-problem', profileId: KitDraft.appWide, controller: c);
''',
      });
      final problems = m.draftSites().map((s) => s.problems.join()).toList();
      expect(problems[0], contains('falls back to a literal'));
      expect(problems[1], contains('not in _appWideDrafts'));
      expect(problems[2], isEmpty);
    });

    test(
      'a key without the profile id is not swept with the profile',
      () async {
        SharedPreferences.setMockInitialValues({
          'oc.draft.note.ses_1': 'nobody deletes me',
          KitDraft.keyFor('note.ses_1', 'prof-a'): 'swept',
        });
        final prefs = await SharedPreferences.getInstance();
        final scoped = ProfileStore(
          prefs: prefs,
        ).profileScopedPreferenceKeys('prof-a');
        expect(scoped, {'oc.draft.note.ses_1.prof-a'});
      },
    );
  });
}
