import 'dart:async';

import 'package:flutter/material.dart';

import '../../builtin/builtin_server.dart' show looksLikeInAppServer;
import '../../domain/connection_status.dart' show ConnectionStatusPhase;
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
    ProfileAttentionSnapshot? snapshotOf(ServerProfile profile) =>
        monitor != null && controller.isProfileReadable(profile.id)
        ? monitor.snapshotFor(profile.id)
        : null;
    // Most urgent first (R1): waiting on the person, then working, then
    // the rest in the order they were saved.
    int rank(ServerProfile profile) {
      final snapshot = snapshotOf(profile);
      if (snapshot == null || !snapshot.isCurrent) return 2;
      if (snapshot.requests.isNotEmpty) return 0;
      if ((snapshot.runningCount ?? 0) > 0) return 1;
      return 2;
    }

    final others = [
      for (final profile in profiles)
        if (profile.id != current?.id &&
            !looksLikeInAppServer(profile) &&
            !shownAsPhoneRow(profile))
          profile,
    ];
    final order = {for (final (i, p) in others.indexed) p.id: i};
    others.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : order[a.id]!.compareTo(order[b.id]!);
    });

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
      // "Disconnect from This phone" lives in the card's own menu, so the
      // sheet needs no separate Disconnect row for the phone server.
      onDisconnect: profile.id == current?.id ? () => unawaited(leave()) : null,
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
    ];

    // Every saved server in one panel, no label (R1): the one in use first
    // with its current mark and state word, then the rest by urgency.
    final showCurrent =
        current != null && !currentIsPhone && !currentIsPhoneRow;
    final serverRows = [
      if (showCurrent)
        _CurrentServerRow(
          profile: current,
          status: controller.connectionStatus.phase,
          onDisconnect: () => unawaited(leave()),
        ),
      for (final profile in others)
        _SavedServerRow(
          key: ValueKey('server-switcher-profile-${profile.id}'),
          profile: profile,
          snapshot: snapshotOf(profile),
          onTap: () => navigator.pop(
            ServerSwitcherOpenServers(ServersRouteRequest.connect(profile.id)),
          ),
        ),
    ];

    return Column(
      key: const ValueKey('server-switcher-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentIsPhone) ...[phoneCard(current), gap],
        if (serverRows.isNotEmpty) ...[
          KitRowGroup(
            key: const ValueKey('server-switcher-saved'),
            margin: EdgeInsets.zero,
            children: serverRows,
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

  /// The shared connection status (one grace period app-wide), so the
  /// word here always matches the shell's server pill.
  final ConnectionStatusPhase status;
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
        // The name identifies the server; the address is technical and
        // lives in its editor, so it is not cut off here.
        supporting: status == ConnectionStatusPhase.connected
            ? _withoutSeparator(kitCurrentSpan(context, word))
            : TextSpan(
                text: word,
                style: KitText.styleOf(context, KitTextRole.label),
              ),
        supportingKey: const ValueKey('server-switcher-current-status'),
        menuLabel: l10n.serverSwitcherCurrentMenu,
        menu: [
          KitMenuItem(
            key: const ValueKey('server-switcher-disconnect'),
            label: l10n.serverDisconnectFrom(profile.name),
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
    // What it needs or does, in words; the name identifies it (the
    // address is technical and lives in its editor).
    final words = [
      if (running > 0) l10n.otherServerWorking(running),
      ?reentry,
    ].join(' · ');
    return KitRow(
      leading: waiting > 0
          ? KitNeedsYou.mark()
          : KitRow.icon(context, _serverIcon(profile)),
      title: profile.name,
      supporting: waiting == 0 && words.isEmpty
          ? null
          : TextSpan(
              children: [
                if (waiting > 0)
                  words.isEmpty
                      ? _withoutSeparator(
                          KitNeedsYou.span(context, count: waiting),
                        )
                      : KitNeedsYou.span(context, count: waiting),
                if (words.isNotEmpty) TextSpan(text: words, style: wordStyle),
              ],
            ),
      supportingKey: ValueKey('server-switcher-profile-${profile.id}-status'),
      onTap: onTap,
    );
  }
}

IconData _serverIcon(ServerProfile profile) =>
    isPhoneOwnServer(profile) ? AppIconography.phone : AppIconography.server;

/// A needs-you span with no trailing " · ", for a line with nothing after.
TextSpan _withoutSeparator(TextSpan span) => TextSpan(
  text: span.text?.replaceFirst(RegExp(r'\s*·\s*$'), ''),
  style: span.style,
);

/// The same words as the shell's server pill for the same phase.
String _statusLabel(AppLocalizations l10n, ConnectionStatusPhase status) =>
    switch (status) {
      ConnectionStatusPhase.connected => l10n.e7WorkspaceConnected,
      ConnectionStatusPhase.connecting => l10n.e7WorkspaceConnecting,
      ConnectionStatusPhase.reconnecting => l10n.mcpReconnecting,
      _ => l10n.e7WorkspaceOffline,
    };

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
