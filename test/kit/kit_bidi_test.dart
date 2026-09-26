// KitBidi: technical values are wrapped in Unicode isolates so they keep
// their order inside Arabic copy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';

void main() {
  test('ltr wraps in LRI … PDI', () {
    expect(KitBidi.ltr('lib/main.dart'), '\u2066lib/main.dart\u2069');
  });

  test('auto wraps in FSI … PDI', () {
    expect(KitBidi.auto('مشروع'), '\u2068مشروع\u2069');
  });

  test('never wraps twice and leaves empty text alone', () {
    final once = KitBidi.ltr('a/b');
    expect(KitBidi.ltr(once), once);
    expect(KitBidi.auto(once), once);
    expect(KitBidi.ltr(''), '');
    expect(KitBidi.auto(''), '');
  });

  test('a path inside an Arabic sentence stays one isolated run', () {
    final sentence = 'تم حفظ ${KitBidi.ltr('/home/me/app.dart')} بنجاح';
    final start = sentence.indexOf('\u2066');
    final end = sentence.indexOf('\u2069');
    expect(sentence.substring(start + 1, end), '/home/me/app.dart');
  });

  testWidgets('ltrText shows the isolated value in the ambient direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: KitBidi.ltrText('src/a.dart', maxLines: 1),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, '\u2066src/a.dart\u2069');
    expect(text.textDirection, isNull);
    expect(text.maxLines, 1);
  });
}
