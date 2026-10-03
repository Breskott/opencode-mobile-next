// Gallery (gate G4) for KitChoiceList, KitChoiceRow and KitPickerRow
// (docs/ux-system/kit-api/KitChoiceList.md): every declared state at the
// phone size, and the default (the picker sheet) at the wide size, dark and
// light. Sizes follow the owner decision of 2026-09-27: the phone (412x915)
// and one wide size (1280x800); no Arabic. The default is also shot at
// text 2.0 at both sizes (TEST-9, G4).
//
// Deterministic (TEST-11): no receipt waits on `since`.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_choice_list_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_choice_list.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_gallery.dart';

const _phone = Size(412, 915);

const _deploy = [
  KitChoice(value: 'staging', title: 'Staging', supporting: 'staging.example'),
  KitChoice(value: 'production', title: 'Production', recommended: true),
  KitChoice(value: 'canary', title: 'Canary', supporting: '5% of traffic'),
];

void _noop(Object? _) {}

Widget _rails(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

Widget _single({String? selected, KitReceipt? receipt, bool sends = false}) =>
    _rails(
      KitChoiceList<String>.single(
        choices: _deploy,
        selected: selected,
        sends: sends,
        receipt: receipt,
        semanticsLabel: 'Where to deploy',
        onSelected: _noop,
      ),
    );

final _otherController = TextEditingController(text: 'Blue-green, then canary');

Map<String, Widget Function()> _states() => {
  'loading': () => _rails(
    KitChoiceList<String>.single(
      choices: const [],
      selected: null,
      loading: true,
      onSelected: _noop,
    ),
  ),
  'empty': () => _rails(
    KitChoiceList<String>.single(
      choices: const [],
      selected: null,
      onSelected: _noop,
      empty: const KitStateView(
        icon: AppIconography.mic,
        title: 'No voices downloaded yet',
        body: 'Download a voice to hear replies read aloud.',
      ),
    ),
  ),
  'choice_disabled': () => _rails(
    KitChoiceList<String>.single(
      choices: const [
        KitChoice(value: 'staging', title: 'Staging'),
        KitChoice(
          value: 'production',
          title: 'Production',
          enabled: false,
          disabledReason: 'Needs a release tag first',
        ),
        KitChoice(value: 'canary', title: 'Canary'),
      ],
      selected: 'staging',
      onSelected: _noop,
    ),
  ),
  'multi': () => _rails(
    KitChoiceList<String>.multi(
      choices: _deploy,
      selected: const {'staging', 'canary'},
      onChanged: _noop,
    ),
  ),
  'other': () => _rails(
    KitChoiceList<String>.single(
      choices: _deploy,
      selected: null,
      sends: true,
      onSelected: _noop,
      other: KitChoiceOther(
        label: 'Something else',
        fieldLabel: 'Your answer',
        onSubmitted: _noop,
        draft: KitDraft(
          target: 'question.gallery',
          profileId: 'p1',
          controller: _otherController,
        ),
      ),
    ),
  ),
  'sending': () => _single(
    selected: 'production',
    sends: true,
    receipt: const KitReceipt(state: KitReceiptState.sending),
  ),
  'answered': () => _single(
    selected: 'production',
    sends: true,
    receipt: const KitReceipt(state: KitReceiptState.sent),
  ),
  'answered_elsewhere': () => _single(
    selected: 'canary',
    sends: true,
    receipt: const KitReceipt(
      state: KitReceiptState.answeredElsewhere,
      where: 'the laptop',
    ),
  ),
  // The applied value differs from the selection (a pending change):
  // "Current" marks only the value in use now, and the installed choice
  // carries its own actions in its row menu (R6).
  'pending_change': () => _rails(
    KitChoiceList<String>.single(
      choices: [
        KitChoice(
          value: 'fast',
          title: 'Fast',
          supporting: 'On this phone',
          menu: [
            KitMenuItem(label: 'Download Fast again', onSelected: () {}),
            KitMenuItem(
              label: 'Delete Fast',
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
        const KitChoice(
          value: 'balanced',
          title: 'Balanced',
          supporting: 'Not downloaded · 153 MB download',
          recommended: true,
        ),
        const KitChoice(
          value: 'accurate',
          title: 'High accuracy',
          supporting: 'Not downloaded · 480 MB download',
        ),
      ],
      selected: 'balanced',
      current: 'fast',
      actsOnTap: false,
      semanticsLabel: 'Voice model',
      onSelected: _noop,
    ),
  ),
  'picker_row': () => const KitRowGroup(
    leadingIcons: false,
    children: [
      KitPickerRow<String>(
        title: 'Language',
        choices: [
          KitChoice(value: 'en', title: 'English'),
          KitChoice(value: 'system', title: 'Follow the system'),
        ],
        selected: 'en',
        onSelected: _noop,
      ),
      KitPickerRow<String>(
        title: 'Deploy to',
        choices: _deploy,
        selected: 'production',
        onSelected: _noop,
      ),
      KitPickerRow<String>(
        title: 'Shell',
        supporting: 'The only shell on this server',
        choices: [KitChoice(value: 'bash', title: 'bash')],
        selected: 'bash',
        onSelected: _noop,
      ),
    ],
  ),
  'picker_disabled': () => const KitRowGroup(
    leadingIcons: false,
    children: [
      KitPickerRow<String>(
        title: 'Deploy to',
        choices: _deploy,
        selected: 'staging',
        onSelected: null,
        disabledReason: 'Connect to a server to choose',
      ),
    ],
  ),
};

Future<void> _sheet(BuildContext context) => showKitChoiceSheet<String>(
  context,
  title: 'Deploy to',
  subtitle: 'Where this run publishes',
  choices: _deploy,
  selected: 'production',
);

void main() {
  setUpAll(loadKitGalleryFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // kitGalleryScaledSizes is the phone and the wide size.
    for (final size in kitGalleryScaledSizes) {
      testWidgets('default (sheet) · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_choice_list_default', size, light: light),
          size: size,
          light: light,
          open: _sheet,
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      testWidgets(
        'default (sheet) · text 2.0 · ${kitGallerySize(size)} · $mode',
        (tester) async {
          await kitGalleryShot(
            tester,
            name: kitGalleryName(
              'kit_choice_list_default',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            open: _sheet,
          );
        },
      );
    }

    for (final MapEntry(key: state, value: build) in _states().entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_choice_list_$state', _phone, light: light),
          size: _phone,
          light: light,
          child: build(),
        );
      });
    }
  }
}
