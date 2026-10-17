// A Widgetbook catalog of the app's real screens with fake data.
//
// Tree: <app area> -> screen -> state, built from lib/all_components.dart.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'all_components.dart';
import 'catalog.dart';

void main() => runApp(const CatalogApp());

const _phone = ViewportData(
  name: 'Phone 412x915',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);
const _smallPhone = ViewportData(
  name: 'Small phone 360x640',
  width: 360,
  height: 640,
  pixelRatio: 2,
  platform: TargetPlatform.android,
);
const _tablet = ViewportData(
  name: 'Tablet 800x1280',
  width: 800,
  height: 1280,
  pixelRatio: 2,
  platform: TargetPlatform.android,
);

class CatalogApp extends StatelessWidget {
  const CatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: buildDirectories(allComponents()),
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: AppTheme.light()),
            WidgetbookTheme(name: 'Dark', data: AppTheme.dark()),
          ],
        ),
        LocalizationAddon(
          locales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
          ],
        ),
        // ignore: deprecated_member_use
        TextScaleAddon(scales: const [1.0, 1.3, 2.0], initialScale: 1.0),
        ViewportAddon(const [_phone, _smallPhone, _tablet]),
      ],
    );
  }
}
