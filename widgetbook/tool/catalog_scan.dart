// Reads the catalog's own source for `catalogComponent(...)` calls (see
// lib/catalog.dart) and returns what each use-case renders and where it lives
// in the Widgetbook tree. The arguments must be string literals.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class CatalogUseCase {
  CatalogUseCase(this.name, this.path) : shot = shotName(path);
  final String name;

  /// The value of Widgetbook's `?path=` for this use-case.
  final String path;

  /// Where the sweep saves its screenshot, relative to shots/ (no extension).
  final String shot;
}

class CatalogEntry {
  CatalogEntry({
    required this.area,
    required this.folder,
    required this.name,
    required this.screen,
    required this.useCases,
    required this.file,
  });
  final String area;
  final String? folder;
  final String name;
  final String? screen;
  final List<CatalogUseCase> useCases;
  final String file;
}

/// Widgetbook's own path rule: node names joined with `/`, spaces become `-`,
/// lower case.
/// File-safe form of a use-case path, for screenshots.
String shotName(String path) => path.replaceAll(RegExp(r'[^a-z0-9/_.-]'), '_');

String slug(String name) => name.replaceAll(' ', '-').toLowerCase();

List<CatalogEntry> scanCatalog(String widgetbookLib) {
  final out = <CatalogEntry>[];
  for (final f in Directory(widgetbookLib).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('/fakes/') || f.path.endsWith('/catalog.dart')) {
      continue;
    }
    final unit = parseString(
      content: f.readAsStringSync(),
      path: f.path,
      throwIfDiagnostics: false,
    ).unit;
    final finder = _Finder(f.path);
    unit.accept(finder);
    out.addAll(finder.entries);
  }
  return out;
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder(this.file);
  final String file;
  final entries = <CatalogEntry>[];

  String? _literal(ArgumentList args, String name) {
    for (final a in args.arguments) {
      if (a is NamedArgument && a.name.lexeme == name) {
        final e = a.argumentExpression;
        if (e is StringLiteral) return e.stringValue;
      }
    }
    return null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'catalogComponent' && node.target == null) {
      final area = _literal(node.argumentList, 'area');
      final name = _literal(node.argumentList, 'name');
      if (area != null && name != null) {
        final folder = _literal(node.argumentList, 'folder');
        final cases = <CatalogUseCase>[];
        node.accept(
          _CaseFinder((caseName) {
            cases.add(
              CatalogUseCase(
                caseName,
                [
                  slug(area),
                  if (folder != null) slug(folder),
                  slug(name),
                  slug(caseName),
                ].join('/'),
              ),
            );
          }),
        );
        entries.add(
          CatalogEntry(
            area: area,
            folder: folder,
            name: name,
            screen: _literal(node.argumentList, 'screen'),
            useCases: cases,
            file: file,
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _CaseFinder extends RecursiveAstVisitor<void> {
  _CaseFinder(this.onCase);
  final void Function(String) onCase;

  void _check(String typeName, ArgumentList args) {
    if (typeName != 'WidgetbookUseCase') return;
    for (final a in args.arguments) {
      if (a is NamedArgument && a.name.lexeme == 'name') {
        final e = a.argumentExpression;
        if (e is StringLiteral && e.stringValue != null) {
          onCase(e.stringValue!);
        }
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) _check(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }
}

/// Writes catalog.json: every use-case, for the sweep and the map.
///
///   dart run tool/catalog_scan.dart [out.json]
void main(List<String> args) {
  final entries = scanCatalog('lib');
  final json = [
    for (final e in entries)
      {
        'area': e.area,
        'folder': e.folder,
        'component': e.name,
        'screen': e.screen,
        'useCases': [
          for (final u in e.useCases)
            {'name': u.name, 'path': u.path, 'shot': u.shot},
        ],
      },
  ];
  File(
    args.isEmpty ? 'catalog.json' : args.first,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
}
