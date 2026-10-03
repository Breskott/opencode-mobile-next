// Gallery (gate G4) for KitQueuedMessage
// (docs/ux-system/kit-api/KitQueuedMessage.md): the bubble at the end of a
// short transcript above a composer-height inset, every declared state at
// the phone size, the default (three waiting, Send now + Edit) at the phone
// and wide sizes, and the default at 2.0 text. Sizes follow the owner
// decision of 2026-09-27: 412x915 and 1280x800, dark and light; no Arabic.
//
// Deterministic (TEST-11): no item waits on `since`, so no KitSince timer
// runs.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_queued_message_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_queued_message.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

void _noop() {}

const _menu = [
  KitMenuItem(label: 'Edit', onSelected: _noop),
  KitMenuItem(label: 'Remove', onSelected: _noop, destructive: true),
];

KitQueuedItem _item(
  int i,
  String text,
  KitQueuedState state, {
  int attachments = 0,
  String? reason,
}) => KitQueuedItem(
  id: i,
  text: text,
  state: state,
  attachmentCount: attachments,
  reason: reason,
  menu: _menu,
);

final _waiting = [
  _item(1, 'Use SQLite for the cache', KitQueuedState.waiting),
  _item(
    2,
    'Then move the settings migration behind a flag so older builds keep '
    'reading the old file',
    KitQueuedState.waiting,
    attachments: 2,
  ),
  _item(3, 'And run the tests', KitQueuedState.waiting),
];

/// A short transcript, the bubble, and the composer's height under it.
Widget _scene(KitQueuedMessage bubble) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const KitText(
        'I added the cache interface and a first in-memory version. '
        'Tell me which store you want behind it.',
      ),
      const SizedBox(height: 16),
      bubble,
      const SizedBox(height: 96),
    ],
  ),
);

final _default = _scene(
  KitQueuedMessage(
    items: _waiting,
    action: const KitAction(label: 'Send now', onPressed: _noop),
    secondaryAction: const KitAction(label: 'Edit', onPressed: _noop),
  ),
);

final _states = <String, Widget>{
  'offline': _scene(
    KitQueuedMessage(
      items: _waiting,
      action: const KitAction(
        label: 'Send now',
        onPressed: null,
        disabledReason: "You're offline",
      ),
    ),
  ),
  'sending': _scene(
    KitQueuedMessage(
      items: [
        _item(1, 'Use SQLite for the cache', KitQueuedState.sending),
        _item(2, 'And run the tests', KitQueuedState.waiting),
      ],
    ),
  ),
  'not_confirmed': _scene(
    KitQueuedMessage(
      items: [
        _item(1, 'Use SQLite for the cache', KitQueuedState.notConfirmed),
      ],
      action: const KitAction(label: 'Try again', onPressed: _noop),
    ),
  ),
  'failed': _scene(
    KitQueuedMessage(
      items: [
        _item(
          1,
          'Use SQLite for the cache',
          KitQueuedState.failed,
          reason: 'the server is out of disk space',
        ),
      ],
      action: const KitAction(label: 'Try again', onPressed: _noop),
      secondaryAction: const KitAction(label: 'Edit', onPressed: _noop),
    ),
  ),
  'after_reply': _scene(
    KitQueuedMessage(
      items: [
        _item(1, 'Use SQLite for the cache', KitQueuedState.afterThisReply),
        _item(
          2,
          'Keep the old file as a fallback',
          KitQueuedState.addToThisTurn,
        ),
      ],
      action: const KitAction(label: 'Add to this turn', onPressed: _noop),
    ),
  ),
  'mixed': _scene(
    KitQueuedMessage(
      items: [
        _item(1, 'Use SQLite for the cache', KitQueuedState.reachedServer),
        _item(2, 'And run the tests', KitQueuedState.notConfirmed),
        _item(
          3,
          'Then open a pull request',
          KitQueuedState.failed,
          reason: 'the session was closed',
        ),
        const KitQueuedItem(
          id: 4,
          text: '',
          state: KitQueuedState.contextUpdate,
        ),
      ],
      action: const KitAction(label: 'Try again', onPressed: _noop),
    ),
  ),
};

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: child) in _states.entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_queued_message_$state',
            _phone,
            light: light,
          ),
          size: _phone,
          light: light,
          child: child,
        );
      });
    }

    for (final size in [_phone, _wide]) {
      testWidgets('default · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_queued_message_default',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _default,
        );
      });

      testWidgets('default · 2.0 text · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_queued_message_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _default,
        );
      });
    }
  }
}
