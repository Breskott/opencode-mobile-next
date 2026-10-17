import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/usage_widget_snapshot.dart';
import 'package:opencode_mobile/domain/provider_usage.dart';
import 'package:opencode_mobile/platform/launch_shortcut.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_signin_destination.dart';
import 'package:shared_preferences/shared_preferences.dart';

ServerProfile _profile(
  String id, {
  ServerBackend backend = ServerBackend.openCode,
}) => ServerProfile(
  id: id,
  name: 'Home',
  baseUrl: 'https://h.example',
  backend: backend,
);

UsageSignInTarget _target(String provider, String profile) => UsageSignInTarget(
  profileId: profile,
  providerId: provider,
  action: UsageWidgetSnapshot.actionFor(provider),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mapping a widget row to a screen', () {
    test('OpenCode providers open that server\'s provider sign-in', () {
      for (final entry in {
        'codex': 'openai',
        'glm': 'zai-coding-plan',
        'minimax': 'minimax-coding-plan',
      }.entries) {
        expect(
          usageSignInDestination(
            _target(entry.key, 'p1'),
            profile: _profile('p1'),
          ),
          UsageSignInDestination(
            UsageSignInKind.openCodeProvider,
            providerId: entry.value,
          ),
        );
      }
    });

    test('Claude on this phone opens the agent sign-in', () {
      expect(
        usageSignInDestination(_target('claude', 'phone'), profile: null),
        const UsageSignInDestination(
          UsageSignInKind.agentSignIn,
          agentId: 'claude',
        ),
      );
    });

    test('a deleted server, an unknown provider or another kind of server '
        'open the Usage page', () {
      expect(
        usageSignInDestination(_target('codex', 'gone'), profile: null),
        UsageSignInDestination.usage,
      );
      expect(
        usageSignInDestination(
          _target('claude', 'p1'),
          profile: _profile('p1'),
        ),
        UsageSignInDestination.usage,
      );
      expect(
        usageSignInDestination(
          _target('codex', 'p2'),
          profile: _profile('p2', backend: ServerBackend.paseo),
        ),
        UsageSignInDestination.usage,
      );
      expect(
        usageSignInDestination(_target('nope', 'phone'), profile: null),
        UsageSignInDestination.usage,
      );
    });

    test('a set_up row opens "Read usage from" for that server only', () {
      const target = UsageSignInTarget(
        profileId: 'p1',
        providerId: 'codex',
        action: 'set_up',
      );
      expect(
        usageSignInDestination(target, profile: _profile('p1')),
        const UsageSignInDestination(
          UsageSignInKind.readUsageFrom,
          providerId: 'codex',
          profileId: 'p1',
        ),
      );
      expect(
        usageSignInDestination(target, profile: null),
        UsageSignInDestination.usage,
      );
    });

    test('GLM and MiniMax take a key, the rest sign in', () {
      expect(UsageWidgetSnapshot.actionFor('glm'), 'add_key');
      expect(UsageWidgetSnapshot.actionFor('minimax'), 'add_key');
      expect(UsageWidgetSnapshot.actionFor('codex'), 'sign_in');
      expect(UsageWidgetSnapshot.actionFor('claude'), 'sign_in');
    });
  });

  group('the tap travels as a strict wire value', () {
    test('round trips and rejects anything malformed', () {
      final target = _target('glm', '1790000000000000');
      expect(UsageSignInTarget.fromWire(target.wire), target);
      for (final bad in [
        'usage_target:sign_in:codex',
        'usage_target:launch:codex:p1',
        'usage_target:sign_in:Codex:p1',
        'usage_target:sign_in:codex:p 1',
        'usage_target:sign_in:codex:p1:extra',
        'usage',
        null,
      ]) {
        expect(UsageSignInTarget.fromWire(bad), isNull, reason: '$bad');
      }
      expect(LaunchAction.fromWire(target.wire), LaunchAction.usageSignIn);
      expect(LaunchAction.fromWire('usage_target:bad'), isNull);
      final setUp = UsageSignInTarget.fromWire('usage_target:set_up:codex:pc1');
      expect(setUp?.action, 'set_up');
      expect(setUp?.profileId, 'pc1');
      expect(LaunchAction.fromWire(setUp!.wire), LaunchAction.usageSignIn);
    });

    test('the channel hands the target over once', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('oc/shortcut');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final shortcut = LaunchShortcut(channel: channel);
      addTearDown(shortcut.dispose);
      await shortcut.start();
      final target = _target('codex', 'p1');
      var notified = 0;
      shortcut.pending.addListener(() {
        if (shortcut.pending.value != null) notified++;
      });
      for (var i = 0; i < 2; i++) {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('launched', target.wire)),
          (_) {},
        );
      }
      expect(notified, 2);
      expect(shortcut.take(), LaunchAction.usageSignIn);
      expect(shortcut.takeUsageTarget(), target);
      expect(shortcut.takeUsageTarget(), isNull);
    });
  });

  group('Claude through Paseo', () {
    final now = DateTime.utc(2026, 10, 13, 12);

    test('a signed-out provider becomes a reading with no numbers', () {
      // Paseo reports Claude with no (or refused) credentials as
      // `unavailable`, with no error.
      final readings = parseProviderUsageList({
        'providers': [
          {
            'providerId': 'claude',
            'displayName': 'Claude',
            'status': 'unavailable',
            'windows': <Object>[],
            'error': null,
          },
          // A provider the person never set up is not a sign-in prompt.
          {
            'providerId': 'kimi',
            'displayName': 'Kimi',
            'status': 'unavailable',
            'windows': <Object>[],
          },
          // A failure is not "sign in".
          {
            'providerId': 'codex',
            'displayName': 'Codex',
            'status': 'error',
            'error': 'Codex usage API returned 500',
          },
        ],
      }, now: now);
      expect(readings.single.providerId, 'claude');
      expect(readings.single.needsSignIn, isTrue);
      expect(readings.single.windows, isEmpty);
    });

    test('the widget stores it as a row and numbers replace it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final widget = UsageWidgetSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async {},
      );
      await widget.recordReadings(
        profileId: 'phone',
        profileName: '',
        thisPhone: true,
        readings: [
          ProviderUsageReading(
            providerId: 'claude',
            displayName: 'Claude',
            fetchedAt: now,
            windows: const [],
            needsSignIn: true,
          ),
        ],
      );
      String state() =>
          (((prefs.getString(
            UsageWidgetSnapshot.key('phone'),
          )!).contains('"state":"signin"')))
          ? 'signin'
          : 'other';
      expect(state(), 'signin');
      await widget.recordReadings(
        profileId: 'phone',
        profileName: '',
        thisPhone: true,
        readings: [
          ProviderUsageReading(
            providerId: 'claude',
            displayName: 'Claude',
            fetchedAt: now,
            windows: [
              ProviderUsageWindowReading(
                durationSeconds: 18000,
                label: '',
                remainingPercent: 60,
                resetsAt: null,
              ),
            ],
          ),
        ],
      );
      expect(
        prefs.getString(UsageWidgetSnapshot.key('phone')),
        contains('"ok"'),
      );
      expect(
        prefs.getString(UsageWidgetSnapshot.key('phone')),
        isNot(contains('signin')),
      );
    });
  });
}
