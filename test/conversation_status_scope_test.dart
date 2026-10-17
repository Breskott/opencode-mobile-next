import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/conversation_status_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<KitStatus>>(
    valueListenable: KitStatusScope.of(context),
    builder: (_, list, _) =>
        Text(list.map((s) => '${s.kind.name}:${s.message}').join('|')),
  );
}

void main() {
  testWidgets('a conversation on its own connection hides the main '
      "connection's trouble and keeps the other app lines", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = ConnectionController(ProfileStore(prefs: prefs))
      ..status = StreamStatus.connected;
    addTearDown(backend.dispose);
    final outer = ValueNotifier<List<KitStatus>>([
      const KitStatus(
        kind: KitStatusKind.connection,
        id: 'connection:main',
        icon: Icons.cloud_off,
        tone: AppStatusTone.failure,
        message: "OpenCode on this phone isn't answering",
      ),
      const KitStatus(
        kind: KitStatusKind.heat,
        id: 'heat',
        icon: Icons.thermostat,
        tone: AppStatusTone.neutral,
        message: 'The phone is warm',
      ),
    ]);
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: KitStatusScope(
          conditions: outer,
          child: ConversationStatusScope(
            connection: backend,
            child: const _Probe(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('heat:The phone is warm'), findsOneWidget);
    expect(find.textContaining('OpenCode on this phone'), findsNothing);
  });
}
