// Behaviour tests for the AI Team turn-on findings of the 2026-09-30 E2E
// run: a reply that just started is still a reply (B-6), a phone team that
// never proved itself is not "On" (B-18), this phone is never "Computer at
// 127.0.0.1" (B-20).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart'
    show teamRowSubtitle;
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

EventEnvelope _userMessage(String id) => EventEnvelope(
  type: 'message.updated',
  properties: {
    'info': {
      'id': id,
      'sessionID': 's1',
      'role': 'user',
      'time': {'created': 1},
    },
  },
);

EventEnvelope _idle() => EventEnvelope(
  type: 'session.status',
  properties: const {
    'sessionID': 's1',
    'status': {'type': 'idle'},
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('B-6: a prompt just sent counts as a reply before any busy status, '
      'and stops counting when the session goes idle', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ConnectionController(ProfileStore(prefs: prefs));
    addTearDown(controller.dispose);
    expect(controller.replyInFlight, isFalse);

    // The chat put a prompt on the wire; no status has arrived yet.
    controller.noteLocalTurn('s1');
    expect(controller.busySessions, isEmpty);
    expect(controller.replyInFlight, isTrue);
    controller.handleEventForTesting(_idle());
    expect(controller.replyInFlight, isFalse);

    // Or the user message shows up on the live stream first.
    controller.handleEventForTesting(_userMessage('u1'));
    expect(controller.busySessions, isEmpty);
    expect(controller.replyInFlight, isTrue);
    controller.handleEventForTesting(_idle());
    expect(controller.replyInFlight, isFalse);
  });

  test('B-18: a phone team that never proved itself reads Off, not On', () {
    final profile = ServerProfile(
      id: 'p',
      name: 'This phone',
      baseUrl: 'http://127.0.0.1:4097',
      orchestration: const OrchestrationConfig(
        provider: OrchestrationProvider.phoneEngine,
        url: 'phone://engine',
      ),
    );
    expect(
      teamRowSubtitle(
        _en,
        profile: profile,
        orchestration: null,
        discovery: null,
        now: DateTime.utc(2026, 9, 30),
      ),
      _en.teamUiRowOff,
    );
  });

  test('B-20: this phone by its loopback address is never a computer', () {
    expect(plainServerName('127.0.0.1'), 'This phone');
    expect(plainServerName('localhost'), 'This phone');
    expect(plainServerName('192.168.1.5'), 'Computer at 192.168.1.5');
    expect(plainServerName('My PC'), 'My PC');
  });
}
