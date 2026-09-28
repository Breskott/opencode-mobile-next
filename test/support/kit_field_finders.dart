import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The framework [TextField] a kit field draws.
///
/// `KitField.fieldKey` sits on a [TextFormField] (a TextField inside a
/// FormField, a1410445), so a key finder no longer matches a [TextField]
/// itself. This returns the [TextField] under [field], or [field] itself when
/// it already is one, so a test can read its controller, focus, obscuring
/// and text direction either way.
TextField editableOf(WidgetTester tester, Finder field) {
  final inner = find.descendant(of: field, matching: find.byType(TextField));
  if (inner.evaluate().isNotEmpty) {
    return tester.widget<TextField>(inner.first);
  }
  return tester.widget<TextField>(field);
}

/// Every framework [TextField] [finder] matches, looking inside kit fields.
Iterable<TextField> editablesOf(WidgetTester tester, Finder finder) sync* {
  for (final element in finder.evaluate()) {
    final widget = element.widget;
    if (widget is TextField) {
      yield widget;
      continue;
    }
    yield* tester.widgetList<TextField>(
      find.descendant(
        of: find.byElementPredicate((e) => e == element),
        matching: find.byType(TextField),
      ),
    );
  }
}
