import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/sse.dart';
import '../../builtin/builtin_server.dart' show looksLikeInAppServer;
import '../../domain/profile_monitor.dart' show ProfileAttentionSnapshot;
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/local_server_controls.dart';
import '../../state/profile_monitor.dart' show ProfileMonitor;
import '../../state/profiles.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../screens/servers_screen.dart' show ServersRouteRequest;
import 'safety_confirms.dart';
import 'local_agent_server_entry.dart';
import 'phone_server_card.dart';
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

/// A "This phone" menu action. It leaves for another screen (or removes the
/// server), so the shell runs it with [runPhoneServerAction] once the sheet
/// is gone.
class ServerSwitcherPhoneAction extends ServerSwitcherChoice {
  const ServerSwitcherPhoneAction(this.action, this.profileID, this.bytesUsed);
  final PhoneServerAction action;
  final String profileID;
  final int? bytesUsed;
}

/// The person confirmed leaving this server; [alreadyDisconnected] is true
/// when the phone card did it in place.
class ServerSwitcherLeave extends ServerSwitcherChoice {
  const ServerSwitcherLeave({this.alreadyDisconnected = false});
  final bool alreadyDisconnected;
}

/// The single door to servers while connected (UX plan 5.1): where the agent
/// runs now, the server on this phone, the saved servers, then the ways out.
///
/// Kit only (shared-servers-1): one [showKitSheet] titled "Servers" whose
/// rows are [KitRow]s on [KitRowGroup] panels (visual language §5). A
/// confirmation raised inside it (Disconnect, Restart, Stop) replaces the
/// content in place (KIT-16).
Future<ServerSwitcherChoice?> showServerSwitcher(
  BuildContext context,
  ConnectionController controller,
) => showKitSheet<ServerSwitcherChoice>(
  context,
  title: _l10n(context).serverSwitcherTitle,
  icon: AppIconography.server,
  body: (_) => ServerSwitcherSheet(controller: controller),
);

/// The switcher's body (map: server-switcher-sheet, proposal fix):
///
/// - one current mark: the server in use leads with the filled accent tile
///   and its state word ("Connected · ", STATE-9); its Disconnect is in its
///   row's menu, which a tap on the row opens (KIT-28);
/// - the phone's own servers, each controlled where it is shown;
/// - the saved servers, each saying first when it needs the person ("Needs
///   you", through [KitNeedsYou]), how many conversations run there, or that
///   its password must be entered again, then its address;
/// - Add server and Manage servers.
///
/// The in-app phone card has no Disconnect of its own, so when it is the
/// server in use Disconnect is the last row instead.
///
/// States: one server; phone card; phone rows; other saved servers, each
/// plain, needs you, working or needing its password again (map states and
/// statesMissing).
class ServerSwitcherSheet extends StatelessWidget {
  const ServerSwitcherSheet({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    // The other servers' words come from the one attention source, which an
    // isolated profile never reads.
    final monitor = controller.isIsolated ? null : controller.profileMonitor;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?monitor]),
      builder: (context, _) => _build(context, monitor),
    );
  }

  Widget _build(BuildContext context, ProfileMonitor? monitor) {
    final l10n = _l10n(context);
    final tokens = KitTokens.of(context);
    final navigator = Navigator.of(context);
    final current = controller.profile;
    final profiles = controller.store.profiles;
    // OpenCode inside this app is one "This phone" card, never rows named
    // after its address or the runtime it was saved with.
    final phone = phoneServerProfile(profiles, current?.id);
    final currentIsPhone = current != null && current.id == phone?.id;
    // The phone's own servers in Termux are the rows below, "Connected" when
    // in use: their saved sign-ins are never listed again (owner's phone,
    // 2026-09-25: "This device (Termux)" above "This phone", one server).
    final currentIsPhoneRow = current != null && shownAsPhoneRow(current);
    final others = [
      for (final profile in profiles)
        if (profile.id != current?.id &&
            !looksLikeInAppServer(profile) &&
            !shownAsPhoneRow(profile))
          profile,
    ];

    // A phone row leaves in place and keeps its server running.
    Future<void> disconnectInPlace() async {
      if (!await confirmDisconnectServer(context, controller)) return;
      await controller.disconnect(keepActive: true);
      if (navigator.mounted) {
        navigator.pop(const ServerSwitcherLeave(alreadyDisconnected: true));
      }
    }

    // Any other server: the shell leaves once the sheet has closed.
    Future<void> leave() async {
      if (!await confirmDisconnectServer(context, controller)) return;
      if (navigator.mounted) navigator.pop(const ServerSwitcherLeave());
    }

    // "Open" on the server already behind this shell has nowhere to go but
    // back to it; reconnecting would drop live state.
    void openPhoneRow(ServerProfile profile) => navigator.pop(
      controller.api != null && profile.id == current?.id
          ? null
          : ServerSwitcherOpenServers(
              ServersRouteRequest.connect(profile.id, detectedRunning: true),
            ),
    );

    Widget phoneCard(ServerProfile profile) => PhoneServerCard(
      key: ValueKey('server-switcher-phone-${profile.id}'),
      connection: controller,
      profile: profile,
      connected: controller.api != null && profile.id == current?.id,
      onOpen: () => navigator.pop(
        ServerSwitcherOpenServers(ServersRouteRequest.connect(profile.id)),
      ),
      onAction: (action, bytesUsed) => navigator.pop(
        ServerSwitcherPhoneAction(action, profile.id, bytesUsed),
      ),
    );

    final connectedID = controller.api == null ? null : current?.id;
    final phoneRows = <Widget>[
      // A live server the app found on this phone outranks the saved ones
      // and is controlled where it is shown (plan 5.7).
      TermuxRunningServerEntry(
        profiles: profiles,
        busy: false,
        revision: 0,
        connectedProfileID: connectedID,
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
        onDisconnect: disconnectInPlace,
        onForget: (profile) => navigator.pop(
          ServerSwitcherOpenServers(ServersRouteRequest.forget(profile.id)),
        ),
        onManage: () => navigator.pop(const ServerSwitcherOpenPhoneSetup()),
        onConnect: openPhoneRow,
        onEnterCredentials: (server, existing) => navigator.pop(
          ServerSwitcherOpenServers(
            ServersRouteRequest.enterPhoneCredentials(
              profileID: existing?.id,
              openCode2: server.flavor == ServerFlavor.v2,
            ),
          ),
        ),
      ),
      // The Claude Code daemon on this phone, under the same rule.
      LocalAgentServerEntry(
        profiles: profiles,
        busy: false,
        revision: 0,
        connectedProfileID: connectedID,
        busyConversations: controller.busySessions.length,
        onDisconnect: disconnectInPlace,
        onForget: (profile) => navigator.pop(
          ServerSwitcherOpenServers(ServersRouteRequest.forget(profile.id)),
        ),
        onManage: () => navigator.pop(const ServerSwitcherOpenPhoneSetup()),
        onConnect: openPhoneRow,
      ),
    ];

    final gap = SizedBox(height: tokens.space3);
    final ways = <Widget>[
      KitRow(
        key: const ValueKey('server-switcher-add'),
        leading: KitRow.icon(context, AppIconography.add),
        title: l10n.e7SetupAddServer,
        onTap: () => navigator.pop(
          const ServerSwitcherOpenServers(ServersRouteRequest.add()),
        ),
      ),
      KitRow(
        key: const ValueKey('server-switcher-manage'),
        leading: KitRow.icon(context, AppIconography.server),
        title: l10n.serverSwitcherManage,
        trailing: const KitChevron(),
        onTap: () => navigator.pop(const ServerSwitcherOpenServers()),
      ),
      // Last and apart: the one row here that interrupts work.
      if (currentIsPhone)
        KitRow(
          key: const ValueKey('server-switcher-disconnect'),
          leading: KitRow.icon(context, AppIconography.unlink),
          title: l10n.e7SettingsUi8,
          onTap: () => unawaited(leave()),
        ),
    ];

    return Column(
      key: const ValueKey('server-switcher-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentIsPhone) ...[
          phoneCard(current),
          gap,
        ] else if (current != null && !currentIsPhoneRow) ...[
          KitRowGroup(
            margin: EdgeInsets.zero,
            children: [
              _CurrentServerRow(
                profile: current,
                status: controller.status,
                onDisconnect: () => unawaited(leave()),
              ),
            ],
          ),
          gap,
        ],
        if (phone != null && !currentIsPhone) ...[phoneCard(phone), gap],
        // Each phone row decides on its own whether there is anything to
        // show, so each has its own panel: an empty one draws nothing.
        for (final row in phoneRows)
          KitRowGroup(
            margin: EdgeInsetsDirectional.only(bottom: tokens.space1),
            children: [row],
          ),
        if (others.isNotEmpty) ...[
          SizedBox(height: tokens.space2),
          KitRowGroup(
            key: const ValueKey('server-switcher-saved'),
            margin: EdgeInsets.zero,
            label: l10n.activitySavedServers,
            children: [
              for (final profile in others)
                _SavedServerRow(
                  key: ValueKey('server-switcher-profile-${profile.id}'),
                  profile: profile,
                  snapshot:
                      monitor != null &&
                          controller.isProfileReadable(profile.id)
                      ? monitor.snapshotFor(profile.id)
                      : null,
                  onTap: () => navigator.pop(
                    ServerSwitcherOpenServers(
                      ServersRouteRequest.connect(profile.id),
                    ),
                  ),
                ),
            ],
          ),
        ],
        gap,
        KitRowGroup(margin: EdgeInsets.zero, children: ways),
      ],
    );
  }
}

/// The server the app is connected through: the one current mark (a filled
/// accent tile) and its state word first, then its address. A tap opens its
/// menu, where Disconnect is (map: server-switcher-sheet).
class _CurrentServerRow extends StatelessWidget {
  const _CurrentServerRow({
    required this.profile,
    required this.status,
    required this.onDisconnect,
  });

  final ServerProfile profile;
  final StreamStatus status;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final word = _statusLabel(l10n, status);
    return Semantics(
      selected: true,
      child: KitRow(
        key: const ValueKey('server-switcher-current'),
        leading: KitRowIcon(_serverIcon(profile), current: true),
        title: profile.name,
        supporting: TextSpan(
          children: [
            if (status == StreamStatus.connected)
              kitCurrentSpan(context, word)
            else
              TextSpan(
                text: '$word · ',
                style: KitText.styleOf(context, KitTextRole.label),
              ),
            _addressSpan(context, profile),
          ],
        ),
        supportingKey: const ValueKey('server-switcher-current-status'),
        menuLabel: l10n.serverSwitcherCurrentMenu,
        menu: [
          KitMenuItem(
            key: const ValueKey('server-switcher-disconnect'),
            label: l10n.e7SettingsUi8,
            icon: AppIconography.unlink,
            onSelected: onDisconnect,
          ),
        ],
      ),
    );
  }
}

/// A saved server: what it needs or does first (Needs you, running
/// conversations, a password to enter again), then its address. The words
/// come from the monitor's current snapshot only, so a stale or unreadable
/// one says nothing rather than something old.
class _SavedServerRow extends StatelessWidget {
  const _SavedServerRow({
    super.key,
    required this.profile,
    required this.snapshot,
    required this.onTap,
  });

  final ServerProfile profile;
  final ProfileAttentionSnapshot? snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final snapshot = this.snapshot;
    final live = snapshot != null && snapshot.isCurrent;
    final waiting = live ? snapshot.requests.length : 0;
    final running = live ? (snapshot.runningCount ?? 0) : 0;
    final reentry = profile.requiresPasswordReentry
        ? l10n.e7SetupPasswordRequired
        : profile.requiresCodexTokenReentry
        ? l10n.e7SetupTokenRequired
        : null;
    final wordStyle = KitText.styleOf(
      context,
      KitTextRole.label,
      tone: KitTextTone.primary,
    );
    return KitRow(
      leading: waiting > 0
          ? KitNeedsYou.mark()
          : KitRow.icon(context, _serverIcon(profile)),
      title: profile.name,
      supporting: TextSpan(
        children: [
          if (waiting > 0) KitNeedsYou.span(context, count: waiting),
          if (running > 0)
            TextSpan(
              text: '${l10n.otherServerWorking(running)} · ',
              style: wordStyle,
            ),
          if (reentry != null) TextSpan(text: '$reentry · ', style: wordStyle),
          _addressSpan(context, profile),
        ],
      ),
      supportingKey: ValueKey('server-switcher-profile-${profile.id}-status'),
      onTap: onTap,
    );
  }
}

IconData _serverIcon(ServerProfile profile) =>
    isLoopbackHost(Uri.tryParse(profile.baseUrl)?.host ?? '')
    ? AppIconography.phone
    : AppIconography.server;

/// The address as the app did not write it (KIT-32): isolated left to
/// right, in mono.
TextSpan _addressSpan(BuildContext context, ServerProfile profile) => TextSpan(
  text: KitBidi.ltr(profile.baseUrl),
  semanticsLabel: profile.baseUrl,
  style: KitText.styleOf(
    context,
    KitTextRole.mono,
    tone: KitTextTone.secondary,
  ),
);

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
