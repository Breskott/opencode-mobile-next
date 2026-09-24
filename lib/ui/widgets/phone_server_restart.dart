import 'package:flutter/material.dart';

import '../../builtin/builtin_server.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/local_server_controls.dart';
import '../../termux/bridge.dart';

/// Whether the connected server is this phone's own, and how to restart it.
///
/// The one place that tells the phone's servers apart for the Work tab: the
/// in-app OpenCode restarts through [BuiltinServerStarter], the Termux one
/// through [LocalServerControls]; both are the existing paths, and both
/// reconnect afterwards. Any other server is remote: no restart.
({bool onThisPhone, Future<void> Function()? restart}) phoneServerRestartFor({
  required ConnectionController connection,
  required BuiltinServerStarter builtin,
  required BuildContext context,
}) {
  final profile = connection.profile;
  if (profile == null || connection.usesConnectionToken) {
    return (onThisPhone: false, restart: null);
  }
  void fail(String message) {
    if (!context.mounted) return;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          message.isEmpty ? l10n.phoneServerRestartFailed : message,
        ),
      ),
    );
  }

  if (looksLikeInAppServer(profile)) {
    return (
      onThisPhone: true,
      restart: () async {
        final failure = await builtin.start(profile);
        if (failure != null) {
          fail('');
          return;
        }
        await connection.retryConnection();
      },
    );
  }
  if (platformCapabilities.supportsTermux &&
      TermuxBridge.managesServerUrl(profile.baseUrl)) {
    return (
      onThisPhone: true,
      restart: () async {
        try {
          await LocalServerControls(
            store: connection.store,
            connection: connection,
          ).restart();
        } on LocalServerControlFailure catch (failure) {
          fail(failure.message);
          return;
        }
        await connection.retryConnection();
      },
    );
  }
  return (onThisPhone: false, restart: null);
}
