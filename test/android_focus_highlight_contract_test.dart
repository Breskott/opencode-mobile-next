import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Emulator QA B5: after a cold relaunch a thin lime outline framed the
/// whole app. It was Android's own default focus highlight on the focused
/// Flutter view (Theme.Black draws it in the old lime colour) whenever the
/// window leaves touch mode — a key press, a D-pad or `adb shell input`.
/// Flutter paints its own focus rings, only for keyboard navigation
/// (`FocusHighlightMode.traditional`), so the platform one stays off in
/// every theme the activity runs under.
void main() {
  const res = 'android/app/src/main/res';

  for (final file in ['values/styles.xml', 'values-night/styles.xml']) {
    test('$file turns the platform focus highlight off', () {
      final styles = File('$res/$file').readAsStringSync();
      for (final theme in ['LaunchTheme', 'NormalTheme']) {
        final start = styles.indexOf('<style name="$theme"');
        expect(start, greaterThanOrEqualTo(0), reason: theme);
        final body = styles.substring(start, styles.indexOf('</style>', start));
        expect(
          body,
          matches(
            RegExp(
              r'<item name="android:defaultFocusHighlightEnabled"[^>]*>'
              r'false</item>',
            ),
          ),
          reason: '$theme in $file',
        );
      }
    });
  }
}
