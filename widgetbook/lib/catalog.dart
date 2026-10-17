// How a use-case says which real screen it renders.
//
// Every screen's use-cases are declared with [catalogComponent], never with a
// bare WidgetbookComponent:
//
//   catalogComponent(
//     area: 'Usage',                 // folder under the catalog root
//     screen: 'UsageHubScreen',      // the class in lib/ui it renders
//     name: 'Plans page',            // the component's name in the tree
//     useCases: [WidgetbookUseCase(name: 'Loading', builder: ...)],
//   );
//
// tool/inventory.dart and tool/coverage_check.dart read these calls straight
// from the source (the arguments must be string literals), so the catalog
// cannot claim a screen it does not render. [screen] is null for a part that
// is not a screen (a kit widget).
import 'package:widgetbook/widgetbook.dart';

/// One component of the catalog tree: area -> [folder] -> name -> use-cases.
class CatalogComponent {
  const CatalogComponent({
    required this.area,
    required this.name,
    required this.component,
    this.screen,
    this.folder,
  });

  final String area;
  final String? folder;
  final String name;
  final String? screen;
  final WidgetbookComponent component;
}

/// Declares one component. See the file comment.
CatalogComponent catalogComponent({
  required String area,
  required String name,
  required List<WidgetbookUseCase> useCases,
  String? screen,
  String? folder,
}) => CatalogComponent(
  area: area,
  folder: folder,
  name: name,
  screen: screen,
  component: WidgetbookComponent(name: name, useCases: useCases),
);

/// Groups [components] into the tree Widgetbook shows: one folder per area
/// (in first-seen order), then an optional folder, then the component.
List<WidgetbookNode> buildDirectories(List<CatalogComponent> components) {
  final areas = <String, List<WidgetbookNode>>{};
  final folders = <String, Map<String, List<WidgetbookNode>>>{};
  for (final c in components) {
    final children = areas.putIfAbsent(c.area, () => []);
    final folder = c.folder;
    if (folder == null) {
      children.add(c.component);
    } else {
      final byName = folders.putIfAbsent(c.area, () => {});
      final list = byName.putIfAbsent(folder, () {
        final created = <WidgetbookNode>[];
        children.add(WidgetbookFolder(name: folder, children: created));
        return created;
      });
      list.add(c.component);
    }
  }
  return [
    for (final entry in areas.entries)
      WidgetbookFolder(
        name: entry.key,
        isInitiallyExpanded: false,
        children: entry.value,
      ),
  ];
}
