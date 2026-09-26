// G24 — architecture boundaries (docs/ux-system/revamp/STANDARDS.md §18,
// rules ARCH-1, ARCH-2 and ARCH-10).
//
// A pure-Dart source scan — no widget pumping.
//
// ARCH-1 (ratchet): no file under lib/ui/ imports or exports lib/api/,
//   lib/api2/ or the generated package:opencode_sdk; the UI talks only to
//   lib/domain. Every import/export directive is resolved (relative and
//   package:opencode_mobile/ URIs) and counted per file against
//   test/architecture_boundaries_baseline.json. New files start at zero.
// ARCH-2 (ratchet with a reasoned allowlist): lib/ui/ gates features on
//   ServerCapabilities flags and host kind, never on ServerFlavor. Counts per
//   file: `ServerFlavor.` and a `.flavor ==` comparison (either operator,
//   either side, any identifier ending in `flavor`/`Flavor`). Only
//   profile-editor code that sets or labels the flavour may be allowlisted
//   in `_flavorAllowlist`, each with a reason; allowlisted files are not
//   counted.
// ARCH-10 (absolute): notification posting has one path.
//   - `MethodChannel('oc/background')` is constructed only in the two
//     existing background files, and the wire methods that post or update
//     a notification ('showCodingAlert', 'updateLiveStatus') are named only
//     in lib/background/live_background.dart.
//   - Until slice-P6.7 lands `class NotificationRouter`, the Dart callers of
//     `.showCodingAlert(` / `.sendTestNotification(` stay within today's
//     set of files (which may only shrink): no unit adds another path.
//   - From slice-P6.7 (detected by `class NotificationRouter` existing in
//     lib/), those calls are allowed only from the NotificationRouter file.
//
// Comments are stripped before scanning, so prose that mentions a pattern is
// never counted; string contents are kept (import URIs and channel names
// live in strings).
//
// The ratchet: the test fails when a file/pattern count rises above its
// baseline, or a file/pattern not in the baseline appears at all. When
// counts drop it still passes, but prints the smaller baseline to commit so
// the numbers only ever go down. Regenerate after a migration lands:
//   ARCH_BOUNDARIES_WRITE=1 flutter test test/architecture_boundaries_test.dart
// (the pinned Flutter from AGENTS.md), rerun without the env var, and commit
// the smaller numbers. Never raise an entry or add one for a new file
// (PROC-13; G31 checks this).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'test/architecture_boundaries_baseline.json';
const _packageName = 'opencode_mobile';

/// ARCH-2 exceptions: profile-editor code that sets or labels the flavour.
/// file -> reason. Only this kind of code may be listed here; anything that
/// branches behaviour on the flavour belongs in the baseline and must move
/// to a `ServerCapabilities` flag.
const _flavorAllowlist = <String, String>{
  'lib/ui/screens/servers_screen.dart':
      'The server profile editor: detects the flavour from a probe, stores '
      'it on the profile and labels it (OpenCode 1 / OpenCode 2).',
  'lib/ui/screens/termux_setup_screen.dart':
      'Termux setup writes the saved profile for the runtime the person '
      'installed, so it sets and matches the profile flavour.',
  'lib/ui/screens/builtin_server_screen.dart':
      'Built-in server setup writes the saved profile for the chosen '
      'runtime, so it sets and matches the profile flavour.',
};

/// ARCH-10: the only files that may construct the `oc/background` channel.
const _backgroundChannelFiles = {
  'lib/background/live_background.dart',
  'lib/background/widget_snapshot.dart',
};

/// ARCH-10: the only file that may name the notification wire methods.
const _notificationWireFile = 'lib/background/live_background.dart';
const _notificationWireMethods = ['showCodingAlert', 'updateLiveStatus'];

/// ARCH-10 before slice-P6.7: today's Dart callers of the notification
/// methods. This set may only shrink; a new file here is a new path.
const _notificationCallersBeforeRouter = {
  'lib/state/connection.dart',
  'lib/ui/screens/settings/notifications_settings_screen.dart',
};

// ---------------------------------------------------------------------------
// Scanner (pure functions, self-tested below).

/// Returns [source] with `//` and `/* */` comments replaced by spaces
/// (newlines kept), leaving string literals intact.
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
};

/// ARCH-2 counts for one lib/ui file: pattern -> count (zeros omitted).
Map<String, int> flavorCounts(String code) => {
  for (final e in _flavorPatterns.entries)
    if (e.value.allMatches(code).isNotEmpty)
      e.key: e.value.allMatches(code).length,
};

final _notificationCall = RegExp(
  r'\.\s*(?:showCodingAlert|sendTestNotification)\s*\(',
);
final _backgroundChannel = RegExp(
  r'''MethodChannel\s*\(\s*(['"])oc/background\1''',
);
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

_Counts _readBaseline(String gate) {
  final file = File(_baselinePath);
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final section = (json[gate] as Map<String, dynamic>?) ?? const {};
  return {
    for (final e in section.entries)
      e.key: {
        for (final p in (e.value as Map<String, dynamic>).entries)
          p.key: p.value as int,
      },
  };
}

String _encode(Map<String, _Counts> sections) {
  Map<String, dynamic> sorted(Map<String, dynamic> m) => {
    for (final k in m.keys.toList()..sort())
      k: m[k] is Map ? sorted((m[k] as Map).cast<String, dynamic>()) : m[k],
  };
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
  'ARCH-1':
      'Talk to lib/domain (ServerGateway, ServerOperationsGateway, '
      'ServerCapabilities) instead of lib/api or lib/api2.',
  'ARCH-2':
      'Gate the feature on a ServerCapabilities flag or host kind, not on '
      'ServerFlavor.',
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
  });

  group('G24 architecture boundaries', () {
    final ui = _dartSources('lib/ui');
    final lib = _dartSources('lib');
    final write = Platform.environment['ARCH_BOUNDARIES_WRITE'] == '1';

    final arch1 = _scan(ui, apiImportCounts);
    final arch2 = _scan({
      for (final e in ui.entries)
        if (!_flavorAllowlist.containsKey(e.key)) e.key: e.value,
    }, (_, code) => flavorCounts(code));

    if (write) {
      File(
        _baselinePath,
      ).writeAsStringSync(_encode({'ARCH-1': arch1, 'ARCH-2': arch2}));
    }

    void check(String gate, _Counts actual) {
      final result = _compare(gate, actual, _readBaseline(gate));
      if (result.shrank && result.failures.isEmpty) {
        stdout.writeln(
          '$gate counts dropped. Commit the smaller baseline '
          '(ARCH_BOUNDARIES_WRITE=1 regenerates $_baselinePath):\n'
          '${_encode({'ARCH-1': arch1, 'ARCH-2': arch2})}',
        );
      }
      expect(
        result.failures,
        isEmpty,
        reason:
            '$gate: a lib/ui file gained a forbidden use (new files '
            'start at zero). ${_advice[gate]}',
      );
    }

    test('ARCH-1: lib/ui never imports lib/api/ or lib/api2/', () {
      expect(ui, isNotEmpty, reason: 'run from the package root');
      check('ARCH-1', arch1);
    });

    test('ARCH-2: lib/ui never gates on ServerFlavor', () {
      check('ARCH-2', arch2);
    });

    test('ARCH-2: every flavour allowlist entry exists and gives a reason', () {
      for (final e in _flavorAllowlist.entries) {
        expect(File(e.key).existsSync(), isTrue, reason: '${e.key} is gone');
        expect(e.key, startsWith('lib/ui/'));
        expect(e.value.trim().length, greaterThan(20), reason: e.key);
      }
    });

    test('ARCH-10: notifications have one posting path', () {
      final failures = <String>[];
      for (final e in lib.entries) {
        if (_backgroundChannel.hasMatch(e.value) &&
            !_backgroundChannelFiles.contains(e.key)) {
          failures.add(
            '${e.key}: constructs the oc/background channel; only '
            '${_backgroundChannelFiles.join(', ')} may',
          );
        }
        if (e.key != _notificationWireFile) {
          for (final method in _notificationWireMethods) {
            if (RegExp('([\'"])$method\\1').hasMatch(e.value)) {
              failures.add(
                "${e.key}: names the notification method '$method'; only "
                '$_notificationWireFile may',
              );
            }
          }
        }
      }

      final routerFiles = [
        for (final e in lib.entries)
          if (_routerClass.hasMatch(e.value)) e.key,
      ];
      expect(
        routerFiles.length,
        lessThanOrEqualTo(1),
        reason: 'more than one NotificationRouter: $routerFiles',
      );
      final allowedCallers = routerFiles.isEmpty
          ? _notificationCallersBeforeRouter
          : {routerFiles.single};
      for (final e in lib.entries) {
        if (e.key == _notificationWireFile) continue;
        if (_notificationCall.hasMatch(e.value) &&
            !allowedCallers.contains(e.key)) {
          failures.add(
            routerFiles.isEmpty
                ? '${e.key}: posts a notification directly; no unit adds a '
                      'notification path before slice-P6.7 (allowed: '
                      '${allowedCallers.join(', ')})'
                : '${e.key}: posts a notification directly; only '
                      '${routerFiles.single} (NotificationRouter) may',
          );
        }
      }
      expect(failures, isEmpty, reason: 'ARCH-10 (G24)');
    });
  });
}
