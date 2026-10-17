import 'dart:async';
// KitImageGallery (docs/ux-system/kit-api/KitImageGallery.md): swipe through
// the pictures with a position label, zoomed pictures do not page, pictures
// load lazily, and Send hands the picture to the host.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

/// A 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pump(
  WidgetTester tester,
  Widget gallery, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: gallery,
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

List<KitGalleryPicture> _pictures(int count, List<int> loaded) => [
  for (var i = 0; i < count; i++)
    KitGalleryPicture(
      id: 'p$i',
      name: 'shot$i.png',
      load: () async {
        loaded.add(i);
        return _png;
      },
    ),
];

Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.fling(
    find.byKey(const ValueKey('kit-gallery-pager')),
    Offset(dx, 0),
    1500,
  );
  await tester.pumpAndSettle();
}

/// kitModalDismiss for a full-screen page: the home is hidden under the page,
/// so the context is taken before it opens.
KitMotionChange _pageDismiss(
  Future<void> Function(BuildContext context) open,
  String shows,
) => KitMotionChange(
  build: () => const SizedBox.expand(),
  act: (tester, stage) async {
    final context = stage.context;
    unawaited(open(context));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(shows), findsWidgets, reason: 'the page never opened');
    Navigator.of(context).pop();
  },
  hides: shows,
);

void main() {
  List<KitGalleryPicture> still() => _pictures(2, []);
  kitMotionStillTests(
    'KitImageGallery',
    builds: {'loaded': () => KitImageGallery(pictures: still())},
  );
  Future<void> openStill(BuildContext context) =>
      showKitImageGallery(context, pictures: still());
  kitMotionStillTests(
    'showKitImageGallery',
    opens: {'two pictures': KitMotionOpen(openStill, shows: '1 of 2')},
    changes: {'dismissed': _pageDismiss(openStill, '1 of 2')},
  );

  testWidgets('swiping moves to the next picture and the label follows', (
    tester,
  ) async {
    final loaded = <int>[];
    await _pump(
      tester,
      KitImageGallery(pictures: _pictures(5, loaded), initialIndex: 1),
    );
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.textContaining('shot1.png'), findsWidgets);
    // Lazy: the shown picture and its two neighbours only.
    expect(loaded.toSet(), {0, 1, 2});

    await _swipe(tester, -400);
    expect(find.text('3 of 5'), findsOneWidget);
    expect(loaded.toSet(), {0, 1, 2, 3});

    await _swipe(tester, 400);
    await _swipe(tester, 400);
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets('a zoomed picture pans instead of changing picture', (
    tester,
  ) async {
    await _pump(tester, KitImageGallery(pictures: _pictures(3, [])));
    final centre = tester.getCenter(
      find.byKey(const ValueKey('kit-gallery-pager')),
    );
    Future<void> doubleTap() async {
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(centre);
      await tester.pumpAndSettle();
    }

    await doubleTap();
    await _swipe(tester, -400);
    expect(find.text('1 of 3'), findsOneWidget);

    await doubleTap(); // back to fit
    await _swipe(tester, -400);
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('in right-to-left a swipe to the right shows the next picture', (
    tester,
  ) async {
    await _pump(
      tester,
      KitImageGallery(pictures: _pictures(3, [])),
      locale: const Locale('ar'),
    );
    await _swipe(tester, 400);
    expect(find.textContaining('2'), findsWidgets);
    expect(find.text('2 من 3'), findsOneWidget);
  });

  testWidgets('a picture that cannot be read says so and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      KitImageGallery(
        pictures: [
          KitGalleryPicture(
            id: 'x',
            name: 'x.png',
            load: () async => ++calls == 1 ? null : _png,
          ),
        ],
      ),
    );
    expect(find.text('This picture could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('This picture could not be loaded'), findsNothing);
    expect(calls, 2);
  });

  testWidgets('Send hands over the picture and closes; hidden without onSend', (
    tester,
  ) async {
    final sent = <String>[];
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showKitImageGallery(
              context,
              pictures: _pictures(2, []),
              onSend: (bytes, name, {required edited}) async {
                sent.add('$name ${bytes.length} $edited');
                return true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kit-gallery-send')));
    await tester.pumpAndSettle();
    expect(sent, ['shot0.png ${_png.length} false']);
    expect(find.byKey(const ValueKey('kit-gallery-pager')), findsNothing);

    await _pump(tester, KitImageGallery(pictures: _pictures(2, [])));
    expect(find.byKey(const ValueKey('kit-gallery-send')), findsNothing);
    expect(find.byKey(const ValueKey('kit-gallery-edit')), findsOneWidget);
  });
}
