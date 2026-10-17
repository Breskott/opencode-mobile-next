// Voice typing in Settings is a page like its siblings, not a bottom sheet:
// the same model choice and download, with the download pinned under it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/voice/voice_ui.dart';

import 'revamp/screen_voice_1_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);
  final en = lookupAppLocalizations(const Locale('en'));

  testWidgets('the page names itself, holds the setup and downloads', (
    tester,
  ) async {
    tester.view.physicalSize = voicePhone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final models = await ScriptedVoiceModels.create(installed: {});
    addTearDown(models.dispose);
    await tester.pumpWidget(
      voiceHost(home: VoiceSettingsScreen(manager: models)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KitSheet), findsNothing);
    expect(find.text(en.settingsV3VoiceTyping), findsOneWidget);
    expect(find.text('Audio never leaves this phone.'), findsOneWidget);
    final download = find.textContaining('Download Balanced (');
    expect(download, findsOneWidget);
    await tester.tap(download);
    await tester.pump();
    expect(models.acts, ['download:base']);
  });
}
