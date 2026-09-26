// Gallery (gate G4) for KitReceipt (docs/ux-system/kit-api/KitReceipt.md):
// every declared state under a card stub, the span in KitRow supporting
// lines, the default (confirmed) at the wide size, and 2.0 text for the two
// longest states. Sizes follow the owner decision of 2026-09-27: the phone
// (412x915) and one wide size (1280x800), dark and light; no Arabic.
//
// Deterministic (TEST-11): no receipt here waits on `since`, the confirmed
// Undo has no `at` (open while offered), and the automatic line's `at` is a
// fixed date far ahead of any clock, so its Undo window reads as just begun
// and its time is always "10:42 AM".
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_receipt_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_surface.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

final _automaticAt = DateTime(2099, 1, 1, 10, 42);

void _noop() {}

/// A card stub: what was written, and the receipt under it.
///
/// [merged] reads the card as one node, as a message card would: G5's
/// textContrast samples a lone short `text2` word ("Sending…") at 1x and
/// fails it by luck of its anti-aliased letters, although `text2` measures
/// 5:1 and more on every pack (the same finding as
/// docs/qa/revamp-kit-KitStatusMark-v2-2026-09-27).
Widget _card(String title, Widget receipt, {bool merged = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: merged
      ? MergeSemantics(child: _cardBody(title, receipt))
      : _cardBody(title, receipt),
);

Widget _cardBody(String title, Widget receipt) => SizedBox(
  width: double.infinity,
  child: KitSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitText(title, role: KitTextRole.rowTitle),
        const SizedBox(height: 8),
        receipt,
      ],
    ),
  ),
);

final _states = <String, Widget>{
  'sending': _card(
    'Use SQLite for the cache',
    const KitReceipt(state: KitReceiptState.sending),
    merged: true,
  ),
  'sent': _card(
    'Use SQLite for the cache',
    const KitReceipt(state: KitReceiptState.sent, onTap: _noop),
  ),
  'not_confirmed': _card(
    'Use SQLite for the cache',
    const KitReceipt(
      state: KitReceiptState.notConfirmed,
      onRetry: _noop,
      onTap: _noop,
    ),
  ),
  'confirmed': _card(
    'Allow the migration to run',
    const KitReceipt(
      state: KitReceiptState.confirmed,
      label: 'Allowed once',
      onUndo: _noop,
    ),
  ),
  'refused': _card(
    'Stop the run',
    const KitReceipt(
      state: KitReceiptState.refused,
      reason: 'the run already finished',
    ),
  ),
  'answered_elsewhere': _card(
    'Allow the migration to run',
    const KitReceipt(
      state: KitReceiptState.answeredElsewhere,
      where: 'the laptop',
    ),
  ),
  'automatic': _card(
    "The phone's server stopped answering",
    KitReceipt(
      state: KitReceiptState.confirmed,
      automatic: true,
      label: "Restarted the phone's server",
      at: _automaticAt,
      onUndo: _noop,
    ),
  ),
  'span_in_rows': Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (title, span) in [
            (
              'Use SQLite for the cache',
              KitReceipt.span(context, KitReceiptState.sent),
            ),
            (
              'Merge the parser refactor',
              KitReceipt.span(context, KitReceiptState.notConfirmed),
            ),
            (
              'Stop the run',
              KitReceipt.span(
                context,
                KitReceiptState.refused,
                reason: 'the run already finished',
              ),
            ),
            (
              'Allow the migration to run',
              KitReceipt.span(
                context,
                KitReceiptState.answeredElsewhere,
                where: 'the laptop',
              ),
            ),
            (
              'Approve the release notes',
              KitReceipt.span(
                context,
                KitReceiptState.confirmed,
                label: 'Approved',
              ),
            ),
          ])
            KitRow(
              title: title,
              supporting: TextSpan(
                children: [
                  span,
                  const TextSpan(text: '2 min ago'),
                ],
              ),
            ),
        ],
      ),
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
          name: kitGalleryName('kit_receipt_$state', _phone, light: light),
          size: _phone,
          light: light,
          child: child,
        );
      });
    }

    testWidgets('default (confirmed) · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_receipt_confirmed', _wide, light: light),
        size: _wide,
        light: light,
        child: _states['confirmed']!,
      );
    });

    for (final state in ['not_confirmed', 'answered_elsewhere']) {
      for (final size in kitGalleryScaledSizes) {
        testWidgets('$state · 2.0 text · ${kitGallerySize(size)} · $mode', (
          tester,
        ) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_receipt_$state',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            child: _states[state]!,
          );
        });
      }
    }
  }
}
