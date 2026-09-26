// Gallery (gate G4) for KitDetailsFold and showKitTechnicalDetails
// (docs/ux-system/kit-api/KitDetailsFold.md "Galleries required"): the one
// technical fold, collapsed and open with values, raw text and a richer
// child, on a `surface1` panel; the standalone raw-error sheet; and the
// declared empty state (the fold draws nothing under its host's words).
//
// Owner decision 2026-09-27: no Arabic/RTL galleries, and galleries at the
// phone (412x915) and one wide size (1280x800) only — kitGalleryScaledSizes
// is exactly that pair.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_details_fold_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_technical_value.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

const _values = [
  KitTechnicalValue(
    'Address',
    '100.64.0.3:4096',
    spoken: '100.64.0.3, port 4096',
  ),
  KitTechnicalValue(
    'Working folder',
    '/home/dev/code/opencode-mobile/.worktrees/details-fold/lib/ui/kit',
  ),
  KitTechnicalValue('Branch', 'revamp/kit-KitDetailsFold'),
  KitTechnicalValue('Interaction id', 'ses_7f3a9c21e4b0', copyable: false),
];

final _error = [
  'POST http://127.0.0.1:4096/session/ses_7f3a9c21e4b0/message',
  'HTTP 502 Bad Gateway',
  'x-request-id: 3f1c9a7e-5d2b-4c8e-9a61-0b7d2e4f8c13',
  'Authorization: Bearer FAKETOKENFAKETOKEN0123456789',
  for (var i = 1; i <= 26; i++)
    '  at Session.prompt (src/session/index.ts:${100 + i}:${i + 7})',
].join('\n');

/// Opens a plain page with a `surface1` panel that hosts [fold] last, under
/// a line of the host's own words, the way a sheet or page places it.
void _openOnPanel(BuildContext context, Widget fold) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          final tokens = KitTokens.of(context);
          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.roles.surface1,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KitText(
                          "Couldn't reach the server",
                          role: KitTextRole.rowTitle,
                        ),
                        const SizedBox(height: 4),
                        const KitText(
                          'Details below help when you report it.',
                          role: KitTextRole.secondary,
                        ),
                        const SizedBox(height: 8),
                        fold,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

final _states = <String, void Function(BuildContext)>{
  'collapsed': (context) =>
      _openOnPanel(context, const KitDetailsFold(values: _values)),
  'open_values': (context) => _openOnPanel(
    context,
    const KitDetailsFold(
      initiallyExpanded: true,
      notes: ['Check that the server is running, then try again.'],
      values: _values,
    ),
  ),
  'open_text': (context) => _openOnPanel(
    context,
    KitDetailsFold(initiallyExpanded: true, text: _error),
  ),
  'open_child': (context) => _openOnPanel(
    context,
    KitDetailsFold(
      initiallyExpanded: true,
      values: const [KitTechnicalValue('Process', 'opencode serve · pid 4127')],
      child: Builder(
        builder: (context) => DecoratedBox(
          decoration: BoxDecoration(
            color: KitTokens.of(context).roles.ground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: KitText.mono(
              '12:01:07 listening on 127.0.0.1:4096\n'
              '12:01:09 GET /session 200 4 ms\n'
              '12:01:12 SSE client connected',
            ),
          ),
        ),
      ),
    ),
  ),
  // The fold as it sits in a sheet body (surface2), last, open.
  'open_values_in_sheet': (context) => unawaited(
    showKitSheet<void>(
      context,
      title: 'Server',
      body: (context) => const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitText(
            'Connected over Tailscale.',
            role: KitTextRole.body,
            tone: KitTextTone.secondary,
          ),
          SizedBox(height: 8),
          KitDetailsFold(initiallyExpanded: true, values: _values),
        ],
      ),
    ),
  ),
  'technical_details_sheet': (context) => unawaited(
    showKitTechnicalDetails(
      context,
      title: "Couldn't send",
      text: _error,
      values: const [
        KitTechnicalValue('Address', '100.64.0.3:4096'),
        KitTechnicalValue('Status', '502'),
      ],
    ),
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // Every state at the phone size (TEST-9).
    for (final MapEntry(key: state, value: open) in _states.entries) {
      testWidgets('kit_details_fold $state · 412x915 · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_details_fold_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          open: open,
        );
      });
    }

    // The declared state (KIT-12): empty draws nothing, so only the host's
    // own words show on the panel.
    testWidgets('kit_details_fold empty · 412x915 · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_details_fold_empty',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        open: (context) => _openOnPanel(context, const KitDetailsFold()),
      );
    });

    // The default open state at the wide size (the label column) and at
    // 2.0 text at both sizes.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      if (size != const Size(412, 915)) {
        testWidgets('kit_details_fold open_values · $at · $mode', (
          tester,
        ) async {
          await kitGalleryShot(
            tester,
            name: kitGalleryName(
              'kit_details_fold_open_values',
              size,
              light: light,
            ),
            size: size,
            light: light,
            open: _states['open_values']!,
          );
        });
      }
      testWidgets('kit_details_fold open_values · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_details_fold_open_values',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _states['open_values']!,
        );
      });
    }
  }
}
