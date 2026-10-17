import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/ui/screens/guide_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';

Widget _scene(FakePlatform platform) => FakeAppScene<FakeApp>(
  platform: platform,
  create: () => FakeApp.create(profiles: const []),
  builder: (context, app) => const GuideScreen(),
);

CatalogComponent guideScreen() => catalogComponent(
  area: 'Guide',
  screen: 'GuideScreen',
  name: 'Getting started guide',
  useCases: [
    WidgetbookUseCase(
      name: 'On an Android phone',
      builder: (_) => _scene(FakePlatform.android),
    ),
    WidgetbookUseCase(
      name: 'In a browser',
      builder: (_) => _scene(FakePlatform.web),
    ),
  ],
);
