// The app map, made from the code: every screen is a node, every place one
// screen opens another is an edge. Best effort and syntax-level (see
// src_model.dart); what it cannot resolve is listed, never guessed.
//
//   dart run tool/app_map.dart [--lib ../lib] [--out build/site]
//
// writes <out>/map/map.json and copies map/index.html next to it.
//
// What counts as an edge (the `via` field):
//   push         Navigator.push*/pushKitPage/replaceWithKitPage with a
//                route whose builder creates the screen
//   sheet        showModalBottomSheet / showKitSheet / showKitFramedSheet ...
//   dialog       showDialog and friends
//   route        a helper that builds and returns a route to the screen
//   helper:NAME  a call to a top-level function (or a method of the same
//                file) that itself opens the screen
//   named:/path  Navigator.pushNamed to a route in main.dart's routes table
//   embed        the screen is built inside another (home shell tabs, nested
//                pages), outside any navigation call
//   launch       built by lib/main.dart or lib/main_parts (launch routes,
//                deep links, share, the route table): from an @entry node
//
// Unresolved: a navigation call with no destination widget the parser can
// see (the builder calls a function, a variable, or pushNamed with a
// computed name), and navigation into private classes.
import 'dart:convert';
import 'dart:io';

import 'catalog_scan.dart';
import 'inventory.dart';
import 'src_model.dart';

String _arg(List<String> args, String name, String fallback) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
}

const _helperStoplist = {
  'build',
  'initState',
  'dispose',
  'didChangeDependencies',
  'call',
  'of',
  'then',
};

void main(List<String> args) {
  final lib = _arg(args, '--lib', '../lib');
  final out = _arg(args, '--out', 'build/site');
  final model = SourceModel(lib)..load();
  final screens = buildInventory(model);
  final byClass = {for (final s in screens) s.cls: s};
  final catalog = scanCatalog('lib');

  // Which node a class/file belongs to.
  final screensByRoot = <String, List<String>>{};
  String absOf(String rel) => '$lib/${rel.substring('lib/'.length)}';
  for (final s in screens) {
    screensByRoot.putIfAbsent(model.rootOf(absOf(s.file)), () => []).add(s.cls);
  }

  String? ownerNode(String file, String? ownerClass) {
    if (ownerClass != null && ownerClass.startsWith('@')) return ownerClass;
    if (ownerClass != null) {
      if (byClass.containsKey(ownerClass)) return ownerClass;
      final stateOf = ownerClass.startsWith('_') && ownerClass.endsWith('State')
          ? ownerClass.substring(1, ownerClass.length - 'State'.length)
          : null;
      if (stateOf != null && byClass.containsKey(stateOf)) return stateOf;
    }
    if (file.startsWith('lib/main_parts/') ||
        file == 'lib/main.dart' ||
        file == 'lib/manage_space_main.dart') {
      return '@${file.split('/').last.replaceAll('.dart', '')}';
    }
    final inLibrary = screensByRoot[model.rootOf(absOf(file))];
    if (inLibrary != null && inLibrary.length == 1) return inLibrary.first;
    if (inLibrary != null) {
      // A library of several screens (a screen and its part files): the one
      // declared in the library's root file owns code in the other parts.
      final rootRel = 'lib/${model.rootOf(absOf(file)).split('/lib/').last}';
      final inRoot = [
        for (final c in inLibrary)
          if (byClass[c]!.file == rootRel) c,
      ];
      if (inRoot.length == 1) return inRoot.first;
    }
    if (inLibrary == null && file.startsWith('lib/ui/')) {
      // A library with no screen of its own (an editor, a form): its links
      // are attributed to whoever builds it, below.
      return 'lib:${model.rootOf(absOf(file))}';
    }
    if (inLibrary != null && ownerClass != null) {
      // A private helper widget in a file with several screens: use the
      // screen declared in the same file when there is one.
      final sameFile = [
        for (final c in inLibrary)
          if (byClass[c]!.file == file) c,
      ];
      if (sameFile.length == 1) return sameFile.first;
    }
    return null;
  }

  final edges = <String, Map<String, Object?>>{};
  final pseudo = <String>{};
  final unresolved = <Map<String, Object?>>[];
  final internal = <Map<String, Object?>>[];

  void addEdge(String from, String to, String via) {
    if (from == to) return;
    if (from.startsWith('@')) pseudo.add(from);
    final key = '$from>$to';
    final existing = edges[key];
    if (existing == null) {
      edges[key] = {
        'from': from,
        'to': to,
        'via': [via],
      };
    } else {
      final list = existing['via']! as List<String>;
      if (!list.contains(via)) list.add(via);
    }
  }

  void toTarget(String from, String target, String via, String file, int line) {
    if (byClass.containsKey(target)) {
      addEdge(from, target, via);
    } else if (target.startsWith('_')) {
      internal.add({'file': file, 'line': line, 'target': target});
    }
  }

  for (final call in model.navCalls) {
    final from = ownerNode(call.file, call.owner);
    if (from == null) {
      // A navigation helper not owned by any one screen (a shared function):
      // its callers get the edges through the helper pass below.
      continue;
    }
    if (call.kind == 'route' && call.owner == null) continue;
    final named = call.namedRoute;
    if (named != null && call.targets.isEmpty) {
      final dest = model.namedRoutes[named];
      if (dest != null) {
        toTarget(from, dest, call.via ?? 'named:$named', call.file, call.line);
      } else {
        unresolved.add({
          'file': call.file,
          'line': call.line,
          'call': call.callName,
          'reason': 'route name $named is not in the route table',
        });
      }
      continue;
    }
    if (call.targets.isEmpty &&
        call.fn != null &&
        call.fn!.created.isNotEmpty) {
      // `final page = X(...); push(... => page)`: the screens built in the
      // same function are the destinations.
      for (final t in call.fn!.created) {
        toTarget(from, t, call.via ?? call.kind, call.file, call.line);
      }
      continue;
    }
    if (call.targets.isEmpty) {
      // Viewers and plain dialogs hold content, not screens.
      if (call.kind == 'dialog' || call.callName == 'showKitViewer') continue;
      unresolved.add({
        'file': call.file,
        'line': call.line,
        'call': call.callName,
        'reason': named != null
            ? 'computed route name'
            : 'no screen is built inside the call (the builder uses a '
                  'function or a variable)',
      });
      continue;
    }
    for (final t in call.targets) {
      toTarget(from, t, call.via ?? call.kind, call.file, call.line);
    }
  }

  // Helper functions that navigate: calling one is navigating. Resolved
  // across files and a few levels deep (a helper that calls a helper), with
  // a guard against cycles. A call resolves to
  //   * a top-level function of the same file,
  //   * a public top-level function whose name is unique in the app,
  //   * a method of the same screen's library (its State class, its parts).
  String rootOfFile(String f) => model.rootOf(absOf(f));
  Iterable<FnInfo> visible(String name, String file, String? fromNode) sync* {
    final all = model.functions[name] ?? const <FnInfo>[];
    for (final f in all) {
      if (f.topLevel) {
        if (f.file == file || (!name.startsWith('_') && all.length == 1)) {
          yield f;
        }
      } else if (rootOfFile(f.file) == rootOfFile(file)) {
        final fOwner = ownerNode(f.file, f.ownerClass);
        if (fromNode != null && fOwner == fromNode) yield f;
      }
    }
  }

  final memo = <FnInfo, Map<String, String>>{};
  Map<String, String> reach(FnInfo f, int depth, Set<FnInfo> visiting) {
    final cached = memo[f];
    if (cached != null) return cached;
    if (depth > 4 || !visiting.add(f)) return const {};
    final result = <String, String>{...f.targets};
    final fromNode = ownerNode(f.file, f.ownerClass);
    for (final callee in f.calls) {
      if (_helperStoplist.contains(callee)) continue;
      for (final g in visible(callee, f.file, fromNode)) {
        result.addAll(reach(g, depth + 1, visiting));
      }
    }
    visiting.remove(f);
    if (depth == 0) memo[f] = result;
    return result;
  }

  void helperEdges(String file, String? ownerClass, String name, int line) {
    if (_helperStoplist.contains(name)) return;
    final from = ownerNode(file, ownerClass);
    if (from == null) return;
    for (final f in visible(name, file, from)) {
      for (final t in reach(f, 0, <FnInfo>{}).keys) {
        toTarget(from, t, 'helper:$name', file, line);
      }
    }
  }

  for (final call in model.fnCalls) {
    helperEdges(call.file, call.owner, call.name, call.line);
  }
  // Tear-offs: `onTap: _openUsage` is a call that happens later.
  for (final entry in model.identRefs.entries) {
    final split = entry.key.indexOf('|');
    final file = entry.key.substring(0, split);
    final owner = entry.key.substring(split + 1);
    for (final name in entry.value) {
      if (model.functions.containsKey(name)) {
        helperEdges(file, owner == 'null' ? null : owner, name, 0);
      }
    }
  }

  // Built-in (tabs, nested pages) and entry points.
  for (final c in model.creations) {
    final from = ownerNode(c.file, c.owner);
    if (from == null) continue;
    final entry = from.startsWith('@');
    toTarget(
      from,
      c.cls,
      c.via ?? (entry ? 'launch' : 'embed'),
      c.file,
      c.line,
    );
  }
  for (final route in model.namedRoutes.entries) {
    toTarget('@main', route.value, 'named:${route.key}', 'lib/main.dart', 0);
  }

  // Libraries without a screen of their own pass their links to the screens
  // that build them (two rounds, so a library built by a library resolves).
  for (var round = 0; round < 3; round++) {
    final libs = {
      for (final e in edges.values)
        if ((e['from']! as String).startsWith('lib:')) e['from']! as String,
    };
    for (final lib in libs) {
      final root = lib.substring(4);
      final inside = {
        for (final c in model.classes.values)
          if (c.file.startsWith('lib/ui/') &&
              model.rootOf(absOf(c.file)) == root)
            c.name,
      };
      final creators = <String>{};
      for (final c in model.creations) {
        if (inside.contains(c.cls)) {
          final o = ownerNode(c.file, c.owner);
          if (o != null && o != lib) creators.add(o);
        }
      }
      for (final call in model.navCalls) {
        if (call.targets.any(inside.contains)) {
          final o = ownerNode(call.file, call.owner);
          if (o != null && o != lib) creators.add(o);
        }
      }
      for (final entry in model.identRefs.entries) {
        final split = entry.key.indexOf('|');
        final refFile = entry.key.substring(0, split);
        final refOwner = entry.key.substring(split + 1);
        if (rootOfFile(refFile) == root) continue;
        if (entry.value.any(inside.contains)) {
          final o = ownerNode(refFile, refOwner == 'null' ? null : refOwner);
          if (o != null && o != lib) creators.add(o);
        }
      }
      for (final e in edges.values.toList()) {
        if (e['from'] != lib) continue;
        for (final creator in creators) {
          for (final v in (e['via']! as List<String>)) {
            addEdge(creator, e['to']! as String, v);
          }
        }
      }
    }
  }
  edges.removeWhere(
    (_, e) =>
        (e['from']! as String).startsWith('lib:') ||
        (e['to']! as String).startsWith('lib:'),
  );
  pseudo.removeWhere((p) => p.startsWith('lib:'));

  // Nodes.
  final catalogByScreen = <String, List<Map<String, String>>>{};
  for (final e in catalog) {
    if (e.screen == null) continue;
    for (final u in e.useCases) {
      catalogByScreen.putIfAbsent(e.screen!, () => []).add({
        'name': u.name,
        'path': u.path,
        'shot': u.shot,
      });
    }
  }
  final nodes = <Map<String, Object?>>[
    for (final s in screens)
      {
        'id': s.cls,
        'class': s.cls,
        'file': s.file,
        'area': s.area,
        'kind': s.kind,
        'useCases': catalogByScreen[s.cls] ?? const <Object>[],
      },
    for (final p in (pseudo.toList()..sort()))
      {
        'id': p,
        'class': p,
        'file': 'lib/main_parts',
        'area': 'app entry',
        'kind': 'entry',
        'useCases': const <Object>[],
      },
  ];

  final edgeList = edges.values.toList()
    ..sort(
      (a, b) => '${a['from']}>${a['to']}'.compareTo('${b['from']}>${b['to']}'),
    );
  // Reachability from Home: ordinary links first (screens, sheets, settings
  // rows, tabs, route names), then also search results and entry points
  // (launch routes, deep links, share, notifications).
  Set<String> bfs(Set<String> start, bool Function(Map<String, Object?>) use) {
    final seen = {...start};
    final queue = [...start];
    while (queue.isNotEmpty) {
      final at = queue.removeLast();
      for (final e in edgeList) {
        if (e['from'] == at && use(e) && seen.add(e['to']! as String)) {
          queue.add(e['to']! as String);
        }
      }
    }
    return seen;
  }

  bool plain(Map<String, Object?> e) {
    final via = (e['via']! as List<String>);
    return via.any((v) => v != 'search' && v != 'launch') &&
        !(e['from']! as String).startsWith('@');
  }

  final fromHome = bfs({'HomeScreen'}, plain);
  final entries = {
    for (final n in nodes)
      if ((n['id']! as String).startsWith('@')) n['id']! as String,
    '@search',
  };
  final fromAnywhere = bfs({...fromHome, ...entries}, (e) => true);
  for (final n in nodes) {
    final id = n['id']! as String;
    n['reach'] = id.startsWith('@')
        ? 'entry'
        : fromHome.contains(id)
        ? 'home'
        : fromAnywhere.contains(id)
        ? 'entry-only'
        : 'none';
  }

  final connected = <String>{
    for (final e in edgeList) ...[e['from']! as String, e['to']! as String],
  };
  final result = {
    'generatedFrom': 'lib/ui, lib/main_parts, lib/main.dart',
    'counts': {
      'nodes': nodes.length,
      'edges': edgeList.length,
      'unresolved': unresolved.length,
      'orphans': nodes.where((n) => !connected.contains(n['id'])).length,
      'fromHome': nodes.where((n) => n['reach'] == 'home').length,
      'entryOnly': nodes.where((n) => n['reach'] == 'entry-only').length,
      'unreachable': nodes.where((n) => n['reach'] == 'none').length,
    },
    'nodes': nodes,
    'edges': edgeList,
    'unresolved': unresolved,
    'internalPrivateTargets': internal.length,
  };

  Directory('$out/map').createSync(recursive: true);
  File(
    '$out/map/map.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(result)}\n');
  final html = File('map/index.html');
  if (html.existsSync()) html.copySync('$out/map/index.html');
  final counts = result['counts']! as Map<String, Object?>;
  stdout.writeln(
    'map: ${counts['nodes']} nodes, ${counts['edges']} edges, '
    '${counts['unresolved']} unresolved, ${counts['fromHome']} from Home, '
    '${counts['entryOnly']} entry-only, ${counts['unreachable']} unreachable '
    '-> $out/map/map.json',
  );
}
