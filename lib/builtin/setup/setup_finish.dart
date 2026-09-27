import 'dart:ui' show Locale;

import '../../l10n/app_localizations.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart' show TermuxRuntime;
import '../builtin_linux.dart';
import '../builtin_server.dart';
import 'setup_engine.dart';

/// The last step of a setup job: start OpenCode inside the app and connect
/// to it, through the same [BuiltinServerStarter] the opening card and the
/// return-to-app hook use, so setup can never start the server differently.
///
/// A server that already runs the right OpenCode, with the app connected to
/// it, is left alone ("Add tools" must not cut a running session); anything
/// else starts (or restarts) it and connects.
class BuiltinSetupFinisher {
  BuiltinSetupFinisher({
    required this.store,
    required this.starter,
    required this.connect,
    required this.isConnectedTo,
    required this.strings,
  });

  final ProfileStore store;
  final BuiltinServerStarter starter;

  /// Connects the app to [profile]; null on success, else why not.
  final Future<String?> Function(ServerProfile profile) connect;
  final bool Function(ServerProfile profile) isConnectedTo;
  final AppLocalizations Function() strings;

  BuiltinLinux get linux => starter.linux;

  Future<String?> call(SetupFinishRequest request) async {
    final l10n = strings();
    // A Termux job must never create/start the in-app Ubuntu profile.
    if (request.host != SetupHostKind.builtin) {
      return l10n.phoneSetupErrorCannotStart;
    }
    final two = request.runtime == TermuxRuntime.openCode2;
    final profile = await ensureBuiltinProfile(
      store,
      flavor: two ? ServerFlavor.v2 : ServerFlavor.v1,
      name: l10n.phoneSetupProfileName,
      version: request.version,
      // The older setup screen's names, in either language.
      replaceNames: {
        for (final words in [
          lookupAppLocalizations(const Locale('en')),
          lookupAppLocalizations(const Locale('ar')),
        ])
          for (final runtime in [words.setupRuntimeOne, words.setupRuntimeTwo])
            words.builtinServerProfileName(runtime),
      },
    );
    var running = false;
    try {
      running = (await linux.status()).serverRunning;
    } on BuiltinLinuxException {
      running = false;
    }
    if (!request.openCodeChanged && running && isConnectedTo(profile)) {
      return null;
    }
    // Running but not ours to trust (another runtime, or the app is not
    // connected to it): restarting costs seconds and removes the doubt.
    final failure = await starter.start(profile);
    if (failure != null) return failure.reason(l10n);
    return connect(profile);
  }
}
