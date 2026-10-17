// G6 overflow scenes for KitImageGallery and KitImageMarkup (and their
// openers), one per declared state.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
final Uint8List _notAPicture = Uint8List.fromList(const [1, 2, 3]);

List<KitGalleryPicture> _pictures(
  KitSceneCopy c,
  Future<Uint8List?> Function() load,
) => [
  for (var i = 1; i <= 3; i++)
    KitGalleryPicture(
      id: 'p$i',
      name: c.t(
        'Screenshot of the settings page $i.png',
        'لقطة صفحة الإعدادات $i.png',
      ),
      load: load,
    ),
];

KitGallerySend _send = (bytes, name, {required edited}) async => true;

final kitOverflowImageScenes = <KitOverflowScene>[
  for (final state in ['loading', 'error', 'disabled', 'working']) ...[
    KitOverflowScene(
      const ['KitImageGallery'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitImageGallery(
        initialIndex: 1,
        onSend: state == 'loading' ? null : _send,
        pictures: _pictures(c, switch (state) {
          'error' => () async => null,
          'working' => () async => _png,
          _ => () => Completer<Uint8List?>().future,
        }),
      ),
    ),
    KitOverflowScene(
      const ['showKitImageGallery'],
      state,
      host: KitOverflowHost.modal,
      open: (context, c) => showKitImageGallery(
        context,
        initialIndex: 1,
        onSend: state == 'loading' ? null : _send,
        pictures: _pictures(c, switch (state) {
          'error' => () async => null,
          'working' => () async => _png,
          _ => () => Completer<Uint8List?>().future,
        }),
      ),
    ),
  ],
  for (final state in ['loading', 'error', 'working']) ...[
    KitOverflowScene(
      const ['KitImageMarkup'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitImageMarkup(
        bytes: state == 'error' ? _notAPicture : _png,
        name: c.t(
          'Screenshot of the settings page.png',
          'لقطة صفحة الإعدادات.png',
        ),
      ),
    ),
    KitOverflowScene(
      const ['showKitImageMarkup'],
      state,
      host: KitOverflowHost.modal,
      open: (context, c) => showKitImageMarkup(
        context,
        bytes: state == 'error' ? _notAPicture : _png,
        name: c.t(
          'Screenshot of the settings page.png',
          'لقطة صفحة الإعدادات.png',
        ),
      ),
    ),
  ],
];
