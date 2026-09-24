import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The UI ledger (`docs/design/ui-ledger/`) is the map the reorganization
/// works from. A screen added without a ledger entry is a screen nobody
/// decided where to put, which is how the navigation became ad hoc. The full
/// structural check is `tool/qa/check_ui_ledger.py`; this keeps the two rules
/// that matter day to day inside `flutter test`.
void main() {
  final ledger =
      jsonDecode(File('docs/design/ui-ledger/ledger.json').readAsStringSync())
          as Map<String, dynamic>;
  final pages = (ledger['pages'] as List).cast<Map<String, dynamic>>();

  test('every screen file has a home in the ledger', () {
    final referenced = <String>{
      for (final page in pages) ...[
        if (page['file'] is String) page['file'] as String,
        for (final element in (page['elements'] as List? ?? const []))
          if (element is Map && element['file'] is String)
            element['file'] as String,
      ],
      ...((ledger['notPages'] as List?) ?? const []).map(
        (entry) => entry is Map ? entry['file'].toString() : entry.toString(),
      ),
    };
    final missing =
        Directory('lib/ui/screens')
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.path.replaceAll(r'\', '/'))
            .where(
              (path) => path.endsWith('.dart') && !referenced.contains(path),
            )
            .toList()
          ..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'Add these screens to docs/design/ui-ledger/parts/<area>.json (or '
          'to notPages with a reason), then run '
          'python3 docs/design/ui-ledger/build_ledger.py',
    );
  });

  test('ledger ids are unique and every edge lands on a page', () {
    final ids = <String>{};
    final duplicates = <String>[];
    for (final page in pages) {
      if (!ids.add(page['id'] as String)) duplicates.add(page['id'] as String);
    }
    expect(duplicates, isEmpty, reason: 'duplicate page ids');
    final dangling = <String>[
      for (final page in pages)
        for (final element in (page['elements'] as List? ?? const []))
          if (element is Map &&
              element['target'] is String &&
              !ids.contains(element['target']))
            '${element['id']} -> ${element['target']}',
    ];
    expect(dangling, isEmpty, reason: 'element targets that are not page ids');
  });
}
