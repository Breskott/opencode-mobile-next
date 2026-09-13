import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/appearance_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show capturePng, loadCaptureFonts;

// Exact slice Arabic fragment for review before the full corpus integration.
// This is a test delegate, never a partial production Arabic catalog.
class _ArabicPreview extends AppLocalizationsEn {
  _ArabicPreview() : super('ar');
  @override
  String get e7AppearanceFollowAndroid => "اتباع إعداد Android";
  @override
  String get e7AppearanceFollowSystem => "اتباع إعداد النظام";
  @override
  String get e7AppearanceLight => "فاتح";
  @override
  String get e7AppearanceDark => "داكن";
  @override
  String get e7AppearanceFollowPhoneDescription =>
      "مطابقة إعداد المظهر الفاتح أو الداكن لهذا الهاتف";
  @override
  String get e7AppearanceFollowDeviceDescription =>
      "مطابقة إعداد المظهر الفاتح أو الداكن لهذا الجهاز";
  @override
  String get e7AppearanceLightDescription => "استخدام مساحة العمل الفاتحة";
  @override
  String get e7AppearanceDarkDescription => "استخدام مساحة العمل الداكنة";
  @override
  String get e7AppearanceTitle => "المظهر";
  @override
  String get e7AppearancePreviewHint =>
      "عاين المظهر أولاً. لن يتغيّر إلا عند تطبيقه.";
  @override
  String get e7AppearanceDynamicUnavailable =>
      "ألوان Material You غير متاحة على هذا الجهاز.";
  @override
  String get e7AppearanceSaveFailed =>
      "تعذّر حفظ المظهر. لم يتغيّر إعدادك السابق. حاول مجددًا.";
  @override
  String get e7AppearanceSaving => "جارٍ الحفظ…";
  @override
  String get e7AppearanceApply => "تطبيق";
  @override
  String get e7AppearanceCurrent => "المظهر الحالي";
  @override
  String get e7AppearanceClose => "إغلاق";
  @override
  String get e7AppearancePreviewTitle => "النص وعناصر التحكّم";
  @override
  String get e7AppearancePreviewBody =>
      "شاهد تناسق النص والشيفرة والإجراءات المحدّدة.";
  @override
  String get e7AppearanceSelection => "خيار محدّد";
  @override
  String get e7AppearanceTryControl => "جرّب التحكّم";
  @override
  String get e7AppearanceSampleHint =>
      "تغيّر عناصر التحكّم التجريبية هذه المعاينة فقط.";
  @override
  String get e7AppearancePackOpencode => "أخضر الطرفية، السمة الافتراضية";
  @override
  String get e7AppearancePackCatppuccin =>
      "Mocha وLatte بدرجات البنفسجي الفاتح";
  @override
  String get e7AppearancePackGruvbox => "مظهر كلاسيكي دافئ بدرجات البرتقالي";
  @override
  String get e7AppearancePackSolarized =>
      "لوحة الألوان الثنائية الكلاسيكية بدرجات الأزرق";
  @override
  String get e7AppearancePackDynamic => "ألوان Material You لهذا الهاتف";
  @override
  String e7AppearanceUsesMode(String mode) =>
      "يبقى إعداد المظهر الفاتح أو الداكن كما هو: $mode.";
}

class _PreviewDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _PreviewDelegate();
  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
    locale.languageCode == 'ar' ? _ArabicPreview() : AppLocalizationsEn(),
  );
  @override
  bool shouldReload(_PreviewDelegate old) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureDirectory = Platform.environment['OC_APPEARANCE_CAPTURE_DIR'];
  for (final locale in ['en', 'ar']) {
    for (final scale in [1.0, 2.5]) {
      testWidgets('captures appearance $locale ${scale}x', (tester) async {
        final output = Directory(captureDirectory!);
        expect(output.existsSync(), isTrue);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(() async {
          await loadCaptureFonts();
          final loader = FontLoader('sans-serif')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
                  ).readAsBytes(),
                ),
              ),
            );
          await loader.load();
        });
        SharedPreferences.setMockInitialValues({});
        final controller = ConnectionController(
          ProfileStore(prefs: await SharedPreferences.getInstance()),
        );
        addTearDown(controller.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(locale),
              localizationsDelegates: const [
                _PreviewDelegate(),
                ...AppLocalizations.localizationsDelegates,
              ],
              supportedLocales: const [Locale('en'), Locale('ar')],
              theme: AppTheme.forLocale(AppTheme.light(), Locale(locale)),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => showThemePackPreview(
                      context,
                      controller: controller,
                      pack: ThemePackId.solarized,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        var png = await capturePng(tester, boundary, pixelRatio: 2);
        File(
          '${output.path}/preview-$locale-${scale}x-top.png',
        ).writeAsBytesSync(png);
        final apply = find.text(locale == 'ar' ? 'تطبيق' : 'Apply');
        await tester.scrollUntilVisible(
          apply,
          160,
          scrollable: find.descendant(
            of: find.byKey(const Key('appearance-picker')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        png = await capturePng(tester, boundary, pixelRatio: 2);
        File(
          '${output.path}/preview-$locale-${scale}x-actions.png',
        ).writeAsBytesSync(png);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(controller.themePack.value, ThemePackId.solarized);
      }, skip: captureDirectory == null);
    }
  }
}
