import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';
import 'package:opencode_mobile/builtin/setup/setup_finish.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'built-in finisher refuses Termux before accessing profiles or native',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final starter = BuiltinServerStarter(linux: BuiltinLinux());
      addTearDown(starter.dispose);
      final calls = <String>[];
      const secure = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, (call) async {
            calls.add(call.method);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secure, null);
      });
      final strings = lookupAppLocalizations(const Locale('en'));
      final finisher = BuiltinSetupFinisher(
        store: ProfileStore(prefs: prefs),
        starter: starter,
        connect: (_) async {
          calls.add('connect');
          return null;
        },
        isConnectedTo: (_) {
          calls.add('isConnected');
          return false;
        },
        strings: () => strings,
      );

      expect(
        await finisher.call(
          const SetupFinishRequest(
            host: SetupHostKind.termux,
            runtime: TermuxRuntime.openCode2,
            openCodeChanged: true,
          ),
        ),
        strings.phoneSetupErrorCannotStart,
      );
      expect(calls, isEmpty);
      expect(prefs.getKeys(), isEmpty);
    },
  );
}
