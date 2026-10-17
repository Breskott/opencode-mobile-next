// Gallery (gate G4) for KitProjectFileList (the body of the project file sheet): the top level with
// a folder, the empty project, and a failed read. At 412x915 and 1280x800,
// dark and light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_project_file_list_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Future<List<String>> _top(String folder) async => [
  'lib/',
  'test/',
  'README.md',
  'pubspec.yaml',
];

Widget _list(Future<List<String>> Function(String folder) initial) => Padding(
  padding: const EdgeInsets.all(16),
  child: KitProjectFileList(
    search: (_) async => const [],
    initial: initial,
    onPick: (_) {},
  ),
);

final _scenes = <String, Widget Function()>{'default': () => _list(_top)};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: scene, value: build) in _scenes.entries) {
      for (final size
          in scene == 'default'
              ? kitGalleryScaledSizes
              : const [Size(412, 915)]) {
        testWidgets('$scene · ${kitGallerySize(size)} · $mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_project_file_list_$scene',
              size,
              light: light,
            ),
            size: size,
            light: light,
            child: build(),
          );
        });
      }
    }
  }

  // The declared states, at the phone size, in both themes.
  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    testWidgets('empty · 412x915 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_project_file_list_empty',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _list((_) async => const []),
      );
    });
    testWidgets('error · 412x915 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_project_file_list_error',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _list((_) async => throw StateError('offline')),
      );
    });
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('default · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_project_file_list_default',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _scenes['default']!(),
      );
    });
  }
}
