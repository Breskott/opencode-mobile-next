// Shared syntax-level model of the app's lib/ui, built with package:analyzer's
// parser (no type resolution, so it is fast and needs no build). Used by
// inventory.dart, app_map.dart and coverage_check.dart.
//
// Limits, stated once: matching is by class and function NAME. Two classes
// with the same name in lib/ui would be merged (there are none today), and a
// call whose target is decided at run time is reported as unresolved rather
// than guessed.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A class declared in lib/ui (or main_parts).
class ClassInfo {
  ClassInfo(this.name, this.file, this.superName, this.line);
  final String name;
  final String file;
  final String? superName;
  final int line;

  /// True when it is a widget (extends something named *Widget).
  bool get isWidget => superName != null && superName!.endsWith('Widget');
}

/// A navigation call found in a class or function body.
class NavCall {
  NavCall({
    required this.file,
    required this.line,
    required this.kind,
    required this.callName,
    required this.owner,
    required this.targets,
    required this.namedRoute,
    this.via,
    this.fn,
  });

  /// The function the call sits in, for variable builders (`final page = X();
  /// push(... => page)`).
  final FnInfo? fn;
  final String? via;
  final String file;
  final int line;

  /// push, sheet, dialog or route (a route object that is built here).
  final String kind;
  final String callName;

  /// Name of the enclosing top-level class, or null in a top-level function.
  final String? owner;

  /// Widget classes of lib/ui created inside the call's arguments.
  final Set<String> targets;

  /// For pushNamed: the route name literal.
  final String? namedRoute;
}

/// A call to a function by name, recorded to resolve helper functions.
class FnCall {
  FnCall(this.file, this.owner, this.name, this.line);
  final String file;
  final String? owner;
  final String name;
  final int line;
}

/// A function or method whose body holds navigation calls.
class FnInfo {
  FnInfo(
    this.name,
    this.file,
    this.line, {
    required this.topLevel,
    required this.ownerClass,
  });
  final bool topLevel;
  final String? ownerClass;
  final String name;
  final String file;
  final int line;
  final Map<String, String> targets = {}; // target class -> kind
  final Set<String> calls = {}; // other function names it calls
  final Set<String> created = {}; // widgets built outside a nav call
}

class SourceModel {
  SourceModel(this.libDir);
  final String libDir;
  final classes = <String, ClassInfo>{};
  final navCalls = <NavCall>[];
  final fnCalls = <FnCall>[];
  final functions = <String, List<FnInfo>>{};

  /// Widget creations: (file, owner class, created class, line).
  final creations =
      <({String file, String? owner, String cls, int line, String? via})>[];

  /// Identifier names referenced per `file|owner` (tear-offs such as
  /// `onTap: _openUsage` count as calls to that function).
  final identRefs = <String, Set<String>>{};

  /// `part of` relations: part file -> library root file.
  final partRoot = <String, String>{};

  /// Named routes in main.dart: '/servers' -> class.
  final namedRoutes = <String, String>{};

  final _units = <String, CompilationUnit>{};
  final _lineInfo = <String, int Function(int)>{};

  String rel(String path) => path.startsWith('$libDir/')
      ? 'lib/${path.substring(libDir.length + 1)}'
      : path;

  static List<File> dartFiles(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  /// Parses everything under [libDir]/ui, main_parts and main.dart.
  void load() {
    final files = [
      ...dartFiles('$libDir/ui'),
      ...dartFiles('$libDir/main_parts'),
      File('$libDir/main.dart'),
      File('$libDir/manage_space_main.dart'),
    ];
    for (final f in files) {
      final result = parseString(
        content: f.readAsStringSync(),
        path: f.path,
        throwIfDiagnostics: false,
      );
      _units[f.path] = result.unit;
      final lines = result.lineInfo;
      _lineInfo[f.path] = (offset) => lines.getLocation(offset).lineNumber;
    }
    for (final entry in _units.entries) {
      _collectClasses(entry.key, entry.value);
    }
    for (final entry in _units.entries) {
      _Visitor(this, entry.key).run(entry.value);
    }
    _resolveFunctionClosure();
  }

  void _collectClasses(String path, CompilationUnit unit) {
    for (final directive in unit.directives) {
      if (directive is PartOfDirective) {
        final uri = directive.uri?.stringValue;
        if (uri != null) {
          final dir = File(path).parent.path;
          partRoot[path] = _norm('$dir/$uri');
        }
      }
    }
    for (final d in unit.declarations) {
      if (d is ClassDeclaration) {
        final name = d.namePart.typeName.lexeme;
        classes[name] = ClassInfo(
          name,
          rel(path),
          d.extendsClause?.superclass.name.lexeme,
          lineOf(path, d.offset),
        );
      }
    }
  }

  int lineOf(String path, int offset) => _lineInfo[path]!(offset);

  /// Library root of [path]: itself unless it is a `part of` file.
  String rootOf(String path) {
    final abs = _norm(path);
    return (_roots ??= {
          for (final e in partRoot.entries) _norm(e.key): _norm(e.value),
        })[abs] ??
        abs;
  }

  Map<String, String>? _roots;
  static final _normCache = <String, String>{};
  static String _norm(String path) => _normCache.putIfAbsent(
    path,
    () => File(path).absolute.uri.normalizePath().toFilePath(),
  );

  /// A class counts as a widget when it extends *Widget, directly or through
  /// another class declared here.
  bool isWidgetClass(String name) {
    var current = classes[name];
    final seen = <String>{};
    while (current != null && seen.add(current.name)) {
      if (current.isWidget) return true;
      final parent = current.superName;
      current = parent == null ? null : classes[parent];
    }
    return false;
  }

  void _resolveFunctionClosure() {
    // A top-level function that calls another uniquely-named, public,
    // top-level navigation helper inherits its targets (wrappers around
    // wrappers). Method names are too common to follow across classes.
    for (var i = 0; i < 3; i++) {
      for (final list in functions.values) {
        for (final f in list) {
          if (!f.topLevel) continue;
          for (final callee in f.calls) {
            final candidates = functions[callee] ?? const <FnInfo>[];
            if (candidates.length != 1 || callee.startsWith('_')) continue;
            final g = candidates.single;
            if (!g.topLevel || identical(g, f)) continue;
            for (final t in g.targets.entries) {
              f.targets.putIfAbsent(t.key, () => t.value);
            }
          }
        }
      }
    }
  }
}

final _navNames = RegExp(
  r'^(pushKitPage|replaceWithKitPage|showModalBottomSheet|showDialog|'
  r'showKitSheet|showKitFramedSheet|showKitViewer|showKitRequestSheet|'
  r'showGeneralDialog|showCupertinoDialog)$',
);
final _routeClasses = RegExp(
  r'^(MaterialPageRoute|CupertinoPageRoute|PageRouteBuilder|KitPageRoute)$',
);

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.model, this.path);
  final SourceModel model;
  final String path;
  String? _class;
  final _fnStack = <FnInfo>[];
  int _navDepth = 0;

  /// Set while inside a `SearchEntry(...)`: the edges found there are
  /// settings rows or search results, not ordinary navigation.
  String? _via;

  void run(CompilationUnit unit) => unit.accept(this);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final before = _class;
    _class = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _class = before;
  }

  void _function(String name, int offset, AstNode body, Function() visit) {
    final info = FnInfo(
      name,
      model.rel(path),
      model.lineOf(path, offset),
      topLevel: _class == null,
      ownerClass: _class,
    );
    model.functions.putIfAbsent(name, () => []).add(info);
    _fnStack.add(info);
    visit();
    _fnStack.removeLast();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) => _function(
    node.name.lexeme,
    node.offset,
    node.body,
    () => super.visitMethodDeclaration(node),
  );

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) => _function(
    node.name.lexeme,
    node.offset,
    node.functionExpression.body,
    () => super.visitFunctionDeclaration(node),
  );

  Set<String> _targetsIn(AstNode node) {
    final finder = _CreationFinder(model);
    node.accept(finder);
    return finder.found;
  }

  void _nav(
    AstNode node,
    String callName,
    String kind,
    ArgumentList args, {
    String? namedRoute,
  }) {
    final targets = <String>{};
    for (final a in args.arguments) {
      targets.addAll(_targetsIn(a));
    }
    model.navCalls.add(
      NavCall(
        file: model.rel(path),
        line: model.lineOf(path, node.offset),
        kind: kind,
        callName: callName,
        owner: _class,
        targets: targets,
        namedRoute: namedRoute,
        via: _via,
        fn: _fnStack.isEmpty ? null : _fnStack.last,
      ),
    );
    for (final f in _fnStack) {
      for (final t in targets) {
        f.targets.putIfAbsent(t, () => kind);
      }
    }
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // A tear-off such as `onTap: _openUsage`: remember the name so it can be
    // treated as a call when a function of that name navigates.
    if (node.parent is! MethodInvocation ||
        (node.parent as MethodInvocation).methodName != node) {
      model.identRefs
          .putIfAbsent('${model.rel(path)}|$_class', () => {})
          .add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'SearchEntry' &&
        node.target == null &&
        path.contains('/search/search_index/')) {
      // Hub rows are the Settings screen's rows; every other entry is a
      // search result.
      final kind = node.argumentList.arguments
          .whereType<NamedArgument>()
          .where((a) => a.name.lexeme == 'kind')
          .map((a) => a.argumentExpression.toSource())
          .firstOrNull;
      final beforeClass = _class, beforeVia = _via;
      final row = kind != null && kind.endsWith('.hubRow');
      _class = row ? 'SettingsScreen' : '@search';
      _via = row ? 'row' : 'search';
      super.visitMethodInvocation(node);
      _class = beforeClass;
      _via = beforeVia;
      return;
    }
    final targetSrc = node.target?.toSource() ?? '';
    final isNavigator =
        targetSrc.startsWith('Navigator') &&
        (name == 'push' ||
            name == 'pushReplacement' ||
            name == 'pushAndRemoveUntil' ||
            name == 'pushNamed' ||
            name == 'pushReplacementNamed' ||
            name == 'pushNamedAndRemoveUntil');
    if (isNavigator || (node.target == null && _navNames.hasMatch(name))) {
      String? route;
      if (name.contains('Named') && node.argumentList.arguments.isNotEmpty) {
        final first = node.argumentList.arguments.first;
        route = first is StringLiteral ? first.stringValue : null;
      }
      final kind = name.contains('Sheet')
          ? 'sheet'
          : name.contains('Dialog')
          ? 'dialog'
          : 'push';
      // A Navigator.push(MaterialPageRoute(...)) is one navigation: record
      // the outer call only and skip the route class inside it.
      _navDepth++;
      _nav(node, name, kind, node.argumentList, namedRoute: route);
      super.visitMethodInvocation(node);
      _navDepth--;
      return;
    }
    // A constructor-style call `Foo(...)` is a reference to Foo.
    if (node.target == null && RegExp(r'^[A-Z]').hasMatch(name)) {
      model.identRefs
          .putIfAbsent('${model.rel(path)}|$_class', () => {})
          .add(name);
    }
    final target = node.target;
    final created = target == null
        ? name
        : (target is SimpleIdentifier ? target.name : null);
    if (created != null && _routeClasses.hasMatch(created)) {
      if (_navDepth == 0) {
        _navDepth++;
        _nav(node, created, 'route', node.argumentList);
        super.visitMethodInvocation(node);
        _navDepth--;
        return;
      }
    } else if (created != null &&
        model.classes.containsKey(created) &&
        model.isWidgetClass(created)) {
      _created(created, node);
    } else {
      // Any other call: remember it, so helpers that navigate resolve.
      for (final f in _fnStack) {
        f.calls.add(name);
      }
      model.fnCalls.add(
        FnCall(model.rel(path), _class, name, model.lineOf(path, node.offset)),
      );
    }
    super.visitMethodInvocation(node);
  }

  void _created(String cls, AstNode node) {
    if (_navDepth > 0) return;
    if (_fnStack.isNotEmpty) _fnStack.last.created.add(cls);
    model.creations.add((
      file: model.rel(path),
      owner: _class,
      cls: cls,
      line: model.lineOf(path, node.offset),
      via: _via,
    ));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name.lexeme;
    if (_routeClasses.hasMatch(name) && _navDepth == 0) {
      // A route built without being pushed here (a helper returns it).
      _navDepth++;
      _nav(node, name, 'route', node.argumentList);
      super.visitInstanceCreationExpression(node);
      _navDepth--;
      return;
    } else if (model.classes.containsKey(name) && model.isWidgetClass(name)) {
      _created(name, node);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    if (path.endsWith('/main.dart')) {
      for (final e in node.elements) {
        if (e is MapLiteralEntry && e.key is StringLiteral) {
          final key = (e.key as StringLiteral).stringValue;
          final targets = _targetsIn(e.value);
          if (key != null && key.startsWith('/') && targets.isNotEmpty) {
            model.namedRoutes[key] = targets.first;
          }
        }
      }
    }
    super.visitSetOrMapLiteral(node);
  }
}

/// Finds widget classes created anywhere under a node. Without type
/// resolution, `Foo(...)` parses as a method invocation; both forms count.
class _CreationFinder extends RecursiveAstVisitor<void> {
  _CreationFinder(this.model);
  final SourceModel model;
  final found = <String>{};

  /// True when [name] is an app widget (not a kit part): it is recorded and
  /// the walk does not descend into its arguments, so only the outermost
  /// widget of a builder counts as the destination.
  bool _see(String name) {
    final info = model.classes[name];
    if (info == null || !model.isWidgetClass(name)) return false;
    if (info.file.startsWith('lib/ui/kit/')) return false;
    found.add(name);
    return true;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_see(node.constructorName.type.name.lexeme)) return;
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final name = target == null
        ? node.methodName.name
        : (target is SimpleIdentifier ? target.name : null);
    if (name != null && _see(name)) return;
    super.visitMethodInvocation(node);
  }
}
