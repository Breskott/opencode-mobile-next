// Gallery (gate G4) for KitComposerChips
// (docs/ux-system/kit-api/KitComposerChips.md "Galleries required"): every
// declared state on a `surface2` backdrop like the composer's, at DPR 3.
// Owner decision 2026-09-27: galleries at the phone size (412x915) and one
// wide size (1280x800) only, light and dark, English only (no Arabic or RTL
// shots).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_composer_chips_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_composer_chips.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// A valid 1x1 opaque PNG, deterministic and network-free (TEST-11); the
/// same fixture kit_image_golden_test.dart uses.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00,
  0x90, 0x77, 0x53, 0xDE,
  0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, //
  0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00,
  0x18, 0xDD, 0x8D, 0xB0,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

void _noop() {}

final _menu = [
  const KitMenuItem(label: 'Next model', onSelected: _noop),
  const KitMenuItem(label: 'Previous model', onSelected: _noop),
];

Widget _model({
  String label = 'explore · Sonnet 4.5 · High',
  KitModelChipState state = KitModelChipState.chosen,
  double? contextUsed,
}) => KitComposerChips.model(
  label: label,
  onPressed: _noop,
  state: state,
  contextUsed: contextUsed,
  menu: _menu,
);

List<KitAttachment> _items() => [
  KitAttachment(
    id: 'photo',
    label: 'screenshot-2026-09-27.png',
    kind: KitAttachmentKind.image,
    thumbnail: KitImageSource.memory(_png),
    detail: 'Recovered',
    onOpen: _noop,
  ),
  const KitAttachment(
    id: 'file',
    label: 'build-log.txt',
    kind: KitAttachmentKind.file,
    detail: '2.1 MB',
    onOpen: _noop,
  ),
  const KitAttachment(
    id: 'ref',
    label: 'lib/ui/screens/chat/composer.dart:1054–1288',
    kind: KitAttachmentKind.reference,
    onOpen: _noop,
  ),
  const KitAttachment(
    id: 'folder',
    label: '@src/app',
    kind: KitAttachmentKind.folder,
  ),
];

Widget _attachments({bool readOnly = false}) => KitComposerChips.attachments(
  items: _items(),
  onRemove: readOnly ? null : (_) {},
);

Widget _suggestions() => KitComposerChips.suggestions(
  suggestions: const [
    KitSuggestion(
      id: 'compact',
      label: '/compact',
      kind: KitSuggestionKind.command,
      description:
          'Summarise the conversation so far into a shorter history that '
          'keeps the decisions, the open questions and every changed file, '
          'so the model has room to keep working',
    ),
    KitSuggestion(
      id: 'review',
      label: '/review',
      kind: KitSuggestionKind.command,
      description: 'Review the changes on this branch',
    ),
    KitSuggestion(
      id: 'init',
      label: '/init',
      kind: KitSuggestionKind.command,
      description: 'Write an AGENTS.md for this project',
    ),
    KitSuggestion(
      id: 'undo',
      label: '/undo',
      kind: KitSuggestionKind.command,
      description: 'Undo the last message and its changes',
    ),
    KitSuggestion(
      id: 'share',
      label: '/share',
      kind: KitSuggestionKind.command,
      description: 'Share this conversation',
    ),
    KitSuggestion(
      id: 'models',
      label: '/models',
      kind: KitSuggestionKind.command,
    ),
    KitSuggestion(id: 'help', label: '/help', kind: KitSuggestionKind.command),
  ],
  onSelected: (_) {},
  onShowAll: _noop,
);

/// The composer's backdrop: [children] on `surface2`, as inside the
/// composer's glass.
Widget _scene(List<Widget> children) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tokens.roles.surface2,
          shape: tokens.shapeOf(KitShape.panel),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.space3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: tokens.space2,
            children: children,
          ),
        ),
      ),
    );
  },
);

/// Every declared state (KIT-12), 412x915.
final _states = <String, Widget Function()>{
  'model': () => _scene([_model()]),
  'model_default': () => _scene([
    _model(label: 'Sonnet 4.5', state: KitModelChipState.serverDefault),
    _model(label: '', state: KitModelChipState.serverDefault),
  ]),
  'model_sign_in': () => _scene([
    _model(state: KitModelChipState.signInNeeded),
    _model(state: KitModelChipState.chooseNeeded),
  ]),
  'model_context': () =>
      _scene([_model(contextUsed: 0.85), _model(contextUsed: 0.97)]),
  'model_narrow': () => _scene([
    SizedBox(
      width: 120,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _model(contextUsed: 0.85),
      ),
    ),
  ]),
  'attachments': () => _scene([_attachments()]),
  'attachments_read_only': () => _scene([_attachments(readOnly: true)]),
  'suggestions': () => _scene([_suggestions()]),
  // Empty attachments and empty suggestions render nothing: the backdrop
  // alone, with no gap or frame left behind.
  'empty': () => _scene([
    const KitComposerChips.attachments(items: []),
    KitComposerChips.suggestions(suggestions: const [], onSelected: (_) {}),
  ]),
};

Widget _default() => _scene([_attachments(), _model(contextUsed: 0.85)]);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: build) in _states.entries) {
      testWidgets('kit_composer_chips $state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_composer_chips_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: build(),
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      testWidgets('kit_composer_chips default · '
          '${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_composer_chips_default',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _default(),
        );
      });

      testWidgets('kit_composer_chips default · text2 · '
          '${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_composer_chips_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _default(),
        );
      });
    }
  }
}
