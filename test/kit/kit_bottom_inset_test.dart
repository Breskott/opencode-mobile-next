// KitBottomInset's contract (docs/ux-system/kit-api/KitBottomInset.md;
// K2 §2.12, LAY-6): the fallback to MediaQuery, publishing and add(), and
// the dependency rules. Moved out of kit_undo_test.dart so the part has its
// own unit test (TEST-15, gate G4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

void main() {
  group('KitBottomInset (KitBottomInset.md)', () {
    testWidgets('1. with no publisher, of() falls back to MediaQuery', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 24),
            viewInsets: EdgeInsets.only(bottom: 10),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final clearance = KitBottomInset.of(context);
      expect(clearance.bottom, 34);
      expect(clearance.start, 0);
    });

    testWidgets('2. KitBottomInset publishes; add() adds extraBottom', (
      tester,
    ) async {
      late BuildContext outer;
      late BuildContext inner;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: KitBottomInset(
            insets: const KitClearance(bottom: 100),
            child: Builder(
              builder: (c) {
                outer = c;
                return KitBottomInset.add(
                  extraBottom: 58,
                  child: Builder(
                    builder: (c2) {
                      inner = c2;
                      return const SizedBox.expand();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(KitBottomInset.of(outer).bottom, 100);
      expect(KitBottomInset.of(inner).bottom, 158);
    });

    testWidgets('3. add(start:) replaces start, keeps bottom', (tester) async {
      late BuildContext inner;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: KitBottomInset(
            insets: const KitClearance(bottom: 100, start: 40),
            child: KitBottomInset.add(
              extraBottom: 0,
              start: 296,
              child: Builder(
                builder: (c) {
                  inner = c;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      final clearance = KitBottomInset.of(inner);
      expect(clearance.start, 296);
      expect(clearance.bottom, 100);
    });

    testWidgets(
      '4. a descendant depending through of() rebuilds on change; read() '
      'does not depend',
      (tester) async {
        var bottom = 100.0;
        var readBuilds = 0;
        var ofBuilds = 0;
        late StateSetter setState;
        // Built once and reused: a fresh closure at every StatefulBuilder
        // rebuild would itself force a rebuild regardless of dependency
        // tracking, which is exactly what this test must not measure.
        final readChild = Builder(
          builder: (c) {
            readBuilds++;
            KitBottomInset.read(c);
            return const SizedBox(width: 10, height: 10);
          },
        );
        final ofChild = Builder(
          builder: (c) {
            ofBuilds++;
            KitBottomInset.of(c);
            return const SizedBox(width: 10, height: 10);
          },
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setter) {
                setState = setter;
                return Column(
                  children: [
                    KitBottomInset(
                      insets: KitClearance(bottom: bottom),
                      child: readChild,
                    ),
                    KitBottomInset(
                      insets: KitClearance(bottom: bottom),
                      child: ofChild,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        expect(readBuilds, 1);
        expect(ofBuilds, 1);
        setState(() => bottom = 140);
        await tester.pump();
        expect(ofBuilds, 2, reason: 'of() depends on the published value');
        expect(readBuilds, 1, reason: 'read() must not register a dependency');
      },
    );

    testWidgets(
      '5. add() keeps MediaQuery.padding.bottom equal to the published '
      'bottom (keyboard closed)',
      (tester) async {
        late BuildContext inner;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: KitBottomInset.add(
                extraBottom: 100,
                child: Builder(
                  builder: (c) {
                    inner = c;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        );
        expect(MediaQuery.paddingOf(inner).bottom, 100);
        expect(KitBottomInset.of(inner).bottom, 100);
      },
    );

    testWidgets('6. values snap to whole physical pixels at DPR 3', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            devicePixelRatio: 3,
            padding: EdgeInsets.only(bottom: 57.9),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(KitBottomInset.of(context).bottom, 58.0);
    });
  });
}
