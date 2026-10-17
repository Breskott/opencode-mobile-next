// Lists every screen in lib/ui: a public widget class named *Screen or *Page,
// or a public widget that the code pushes as a route or sheet. Writes
// inventory.json next to the tool when run directly.
//
//   dart run tool/inventory.dart [--lib ../lib] [--out inventory.json]
//
// Private classes cannot be rendered from another package, so they are left
// out (the map lists navigation into them as unresolved).
import 'dart:convert';
import 'dart:io';

import 'src_model.dart';

class Screen {
  Screen(this.cls, this.file, this.area, this.kind, this.line);
  final String cls;
  final String file;
  final String area;

  /// `screen` (named *Screen/*Page) or `route` (pushed as a route or sheet).
  final String kind;
  final int line;

  Map<String, Object?> toJson() => {
    'class': cls,
    'file': file,
    'area': area,
    'kind': kind,
    'line': line,
  };
}

/// The area of a file: the first folder under lib/ui/screens/, or for a loose
/// file its stem, folded into a screens folder when it starts with that
/// folder's name (usage_hub_screen -> usage).
String areaOf(String file, Set<String> screenFolders) {
  const screens = 'lib/ui/screens/';
  if (file.startsWith(screens)) {
    final rest = file.substring(screens.length);
    final slash = rest.indexOf('/');
    if (slash > 0) return rest.substring(0, slash);
    final stem = rest
        .replaceAll('.dart', '')
        .replaceAll(RegExp(r'_(screen|page|sheet|section)$'), '');
    final first = stem.split('_').first;
    if (screenFolders.contains(first)) return first;
    if (screenFolders.contains(stem)) return stem;
    return stem;
  }
  final rest = file.replaceFirst('lib/ui/', '').replaceAll('.dart', '');
  final slash = rest.indexOf('/');
  return slash > 0 ? 'ui-${rest.substring(0, slash)}' : 'ui-$rest';
}

List<Screen> buildInventory(SourceModel model) {
  final folders = <String>{
    for (final d in Directory('${model.libDir}/ui/screens').listSync())
      if (d is Directory) d.path.split('/').last,
  };
  final targets = <String>{
    for (final c in model.navCalls) ...c.targets,
    for (final list in model.functions.values)
      for (final f in list) ...f.targets.keys,
  };
  final out = <Screen>[];
  for (final info in model.classes.values) {
    if (!info.file.startsWith('lib/ui/') ||
        info.file.startsWith('lib/ui/kit/')) {
      continue;
    }
    if (info.name.startsWith('_') || !model.isWidgetClass(info.name)) continue;
    final named = info.name.endsWith('Screen') || info.name.endsWith('Page');
    if (!named && !targets.contains(info.name)) continue;
    out.add(
      Screen(
        info.name,
        info.file,
        areaOf(info.file, folders),
        named ? 'screen' : 'route',
        info.line,
      ),
    );
  }
  out.sort(
    (a, b) =>
        a.file != b.file ? a.file.compareTo(b.file) : a.cls.compareTo(b.cls),
  );
  return out;
}

String _arg(List<String> args, String name, String fallback) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
}

void main(List<String> args) {
  final lib = _arg(args, '--lib', '../lib');
  final out = _arg(args, '--out', 'inventory.json');
  final model = SourceModel(lib)..load();
  final screens = buildInventory(model);
  File(out).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert([for (final s in screens) s.toJson()])}\n',
  );
  final byArea = <String, int>{};
  for (final s in screens) {
    byArea[s.area] = (byArea[s.area] ?? 0) + 1;
  }
  stdout.writeln('${screens.length} screens in ${byArea.length} areas -> $out');
}
