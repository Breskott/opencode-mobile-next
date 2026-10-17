import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/ui/screens/server_capabilities_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';

Widget _scene(ServerCapabilities capabilities, {String? focus}) =>
    FakeAppScene<FakeApp>(
      platform: FakePlatform.android,
      create: () => FakeApp.create(connected: true, capabilities: capabilities),
      builder: (context, app) => ServerCapabilitiesScreen(
        controller: app.connection,
        focusFeature: focus,
      ),
    );

CatalogComponent serverCapabilities() => catalogComponent(
  area: 'Servers',
  screen: 'ServerCapabilitiesScreen',
  name: 'What this server can do',
  useCases: [
    WidgetbookUseCase(
      name: 'Everything on',
      builder: (_) => _scene(ServerCapabilities.allV1),
    ),
    WidgetbookUseCase(
      name: 'Nothing optional',
      builder: (_) => _scene(const ServerCapabilities()),
    ),
  ],
);
