import 'package:flutter/material.dart';

import '../../api/sse.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/local_server_controls.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
import '../screens/servers_screen.dart' show ServersRouteRequest;
import 'product_states.dart';
import 'safety_confirms.dart';
import 'termux_running_server_entry.dart';

/// What the person chose in the server switcher. The sheet only chooses; the
/// shell acts after it has closed, so navigation never runs from a context
/// that is being torn down.
sealed class ServerSwitcherChoice {
  const ServerSwitcherChoice();
}

/// Hand [request] to the Servers screen, which owns connecting, credentials,
/// adding and forgetting.
class ServerSwitcherOpenServers extends ServerSwitcherChoice {
  const ServerSwitcherOpenServers([this.request]);
  final ServersRouteRequest? request;
}

class ServerSwitcherOpenPhoneSetup extends ServerSwitcherChoice {
  const ServerSwitcherOpenPhoneSetup();
}

/// The person confirmed leaving this server; [alreadyDisconnected] is true
/// when the phone card did it in place.
class ServerSwitcherLeave extends ServerSwitcherChoice {
  const ServerSwitcherLeave({this.alreadyDisconnected = false});
  final bool alreadyDisconnected;
}

/// The single door to servers while connected (UX plan 5.1): where the agent
/// runs now, the server on this phone, the saved servers, then the ways out.
Future<ServerSwitcherChoice?> showServerSwitcher(
  BuildContext context,
  ConnectionController controller,
) => showModalBottomSheet<ServerSwitcherChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => ServerSwitcherSheet(controller: controller),
);

class ServerSwitcherSheet extends StatelessWidget {
  const ServerSwitcherSheet({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = _l10n(context);
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    final current = controller.profile;
    final profiles = controller.store.profiles;
    final others = [
      for (final profile in profiles)
        if (profile.id != current?.id) profile,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('server-switcher-sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current != null)
              ListTile(
                key: const ValueKey('server-switcher-current'),
                leading: _ServerAvatar(profile: current, active: true),
                title: Text(
                  current.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_statusLabel(l10n, controller.status)),
                trailing: const Icon(AppIconography.check),
              ),
            // A live server the app found on this phone outranks the saved
            // ones and is controlled where it is shown (plan 5.7). The entry
            // decides on its own whether there is anything to show.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TermuxRunningServerEntry(
                profiles: profiles,
                busy: false,
                revision: 0,
                connectedProfileID: controller.api == null ? null : current?.id,
                busyConversations: controller.busySessions.length,
                actions: () {
                  final controls = LocalServerControls(
                    store: controller.store,
                    connection: controller,
                  );
                  return LocalServerCardActions(
                    restart: () async => controls.restart(),
                    stop: controls.stop,
                  );
                }(),
                onDisconnect: () async {
                  if (!await confirmDisconnectServer(context, controller)) {
                    return;
                  }
                  await controller.disconnect(keepActive: true);
                  if (navigator.mounted) {
                    navigator.pop(
                      const ServerSwitcherLeave(alreadyDisconnected: true),
                    );
                  }
                },
                onForget: (profile) => navigator.pop(
                  ServerSwitcherOpenServers(
                    ServersRouteRequest.forget(profile.id),
                  ),
                ),
                onManage: () =>
                    navigator.pop(const ServerSwitcherOpenPhoneSetup()),
                // "Open" on the server already behind this shell has nowhere
                // to go but back to it; reconnecting would drop live state.
                onConnect: (profile) => navigator.pop(
                  controller.api != null && profile.id == current?.id
                      ? null
                      : ServerSwitcherOpenServers(
                          ServersRouteRequest.connect(
                            profile.id,
                            detectedRunning: true,
                          ),
                        ),
                ),
                onEnterCredentials: (server, existing) => navigator.pop(
                  ServerSwitcherOpenServers(
                    ServersRouteRequest.enterPhoneCredentials(
                      profileID: existing?.id,
                      openCode2: server.flavor == ServerFlavor.v2,
                    ),
                  ),
                ),
              ),
            ),
            if (others.isNotEmpty)
              SectionLabel(
                l10n.activitySavedServers,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              ),
            for (final profile in others)
              ListTile(
                key: ValueKey('server-switcher-profile-${profile.id}'),
                leading: _ServerAvatar(profile: profile, active: false),
                title: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  profile.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: AppTheme.captionFontSize,
                  ),
                ),
                onTap: () => navigator.pop(
                  ServerSwitcherOpenServers(
                    ServersRouteRequest.connect(profile.id),
                  ),
                ),
              ),
            const Divider(height: 17),
            ListTile(
              key: const ValueKey('server-switcher-add'),
              leading: const Icon(AppIconography.add),
              title: Text(l10n.e7SetupAddServer),
              onTap: () => navigator.pop(
                const ServerSwitcherOpenServers(ServersRouteRequest.add()),
              ),
            ),
            ListTile(
              key: const ValueKey('server-switcher-manage'),
              leading: const Icon(AppIconography.server),
              title: Text(l10n.e7SettingsUi63),
              trailing: const Icon(AppIconography.chevronRight),
              onTap: () => navigator.pop(const ServerSwitcherOpenServers()),
            ),
            if (current != null) ...[
              // Last and apart: the one row here that interrupts work.
              const Divider(height: 17),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: OutlinedButton.icon(
                  key: const ValueKey('server-switcher-disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () async {
                    if (!await confirmDisconnectServer(context, controller)) {
                      return;
                    }
                    if (navigator.mounted) {
                      navigator.pop(const ServerSwitcherLeave());
                    }
                  },
                  icon: const Icon(AppIconography.unlink),
                  label: Text(l10n.e7SettingsUi8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({required this.profile, required this.active});

  final ServerProfile profile;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: active ? scheme.primary : scheme.surfaceContainerHighest,
      child: Icon(
        isLoopbackHost(Uri.tryParse(profile.baseUrl)?.host ?? '')
            ? AppIconography.phone
            : AppIconography.server,
        size: 18,
        color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, StreamStatus status) =>
    switch (status) {
      StreamStatus.connected => l10n.e7WorkspaceConnected,
      StreamStatus.connecting => l10n.e7WorkspaceConnecting,
      StreamStatus.reconnecting => l10n.mcpReconnecting,
      StreamStatus.disconnected => l10n.e7WorkspaceOffline,
    };

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
