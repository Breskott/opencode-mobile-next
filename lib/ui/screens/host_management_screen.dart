import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_code_block.dart';
import '../kit/kit_row.dart';
import '../kit/kit_screen.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/kit_top_bar.dart';
import '../widgets/external_link.dart';

/// Host-side management for a remote OpenCode server.
///
/// The app cannot execute commands on the host, so this surface is truthful
/// by construction: it shows the server facts the app already knows and
/// provides exact, copyable commands for the documented Ubuntu helper
/// script. It never claims the app performed a host action.
// revamp: redesign (no owner) — the map's sheet from Server settings with
// one pinned, checksummed install command, "What this does", Linux-only
// stated, daily commands folded and "Check it is running" waits for a
// programme slice; this is the kit-only rebuild of today's layout (MAP-1).
class HostManagementScreen extends StatelessWidget {
  const HostManagementScreen({super.key, required this.controller});

  final ConnectionController controller;

  static const scriptUrl =
      'https://raw.githubusercontent.com/Eslamasabry/opencode-mobile-next/'
      'master/scripts/host/ubuntu-opencode.sh';

  /// The full walkthrough the commands below are excerpted from.
  static const docsUrl =
      'https://github.com/Eslamasabry/opencode-mobile-next/blob/master/docs/'
      'ubuntu-host.md';

  int _serverPort() {
    final uri = Uri.tryParse(controller.profile?.baseUrl ?? '');
    if (uri == null || uri.host.isEmpty) return 4096;
    return uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return KitScreen(
      topBar: KitTopBar(title: l10n.e7SetupLinuxService),
      width: KitScreenWidth.reading,
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _list(context, l10n),
      ),
    );
  }

  Widget _list(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final profile = controller.profile;
    final port = _serverPort();
    final baseUrl = profile?.baseUrl;
    return ListView(
      padding: EdgeInsets.only(
        top: tokens.space3,
        bottom: KitScreen.endPadding(context),
      ),
      children: [
        KitRowGroup(
          label: l10n.e7SetupThisServer,
          children: [
            KitRow(
              leading: KitRow.icon(context, AppIconography.server),
              title: profile?.name ?? l10n.e7SetupDefaultServer,
              supporting: baseUrl == null
                  ? TextSpan(text: l10n.e7SetupNotConnected)
                  : null,
              below: baseUrl == null
                  ? null
                  : KitText.mono(baseUrl, cut: KitMonoCut.middle),
            ),
            KitRow(
              leading: KitRow.icon(context, AppIconography.info),
              title: l10n.e7SetupServerVersion(
                controller.version ?? l10n.e7SetupUnknownVersion,
              ),
              titleMaxLines: 2,
              supporting: TextSpan(text: l10n.e7SetupHostInstructions),
              supportingMaxLines: 4,
            ),
          ],
        ),
        SizedBox(height: tokens.sectionGap),
        KitRowGroup(
          label: l10n.e7SetupHostFirstSetup,
          leadingIcons: false,
          children: [
            _HostCommand(
              label: l10n.e7SetupInstallService,
              detail: l10n.e7SetupInstallServiceDetail,
              command:
                  'curl -fsSL $scriptUrl -o ubuntu-opencode.sh && '
                  'OPENCODE_PORT=$port bash ubuntu-opencode.sh install',
            ),
            _HostCommand(
              label: l10n.e7SetupKeepAfterLogout,
              command: 'loginctl enable-linger "\$USER"',
            ),
            _HostCommand(
              label: l10n.e7SetupReadPassword,
              command: 'bash ubuntu-opencode.sh password',
            ),
            // `adb reverse` forwards a port to an attached *Android* device.
            // On desktop the app and the server share a machine, so the tile
            // described a cable that is not there.
            if (platformCapabilities.supportsUsbHostBridge)
              _HostCommand(
                key: const Key('host-command-adb-reverse'),
                label: l10n.e7SetupUsbAccess,
                command: 'adb reverse tcp:$port tcp:$port',
              ),
          ],
        ),
        SizedBox(height: tokens.sectionGap),
        KitRowGroup(
          label: l10n.e7SetupHostDaily,
          leadingIcons: false,
          children: [
            _HostCommand(
              label: l10n.e7SetupServiceStatus,
              command: 'bash ubuntu-opencode.sh status',
            ),
            _HostCommand(
              label: l10n.e7SetupRestartServer,
              command: 'bash ubuntu-opencode.sh restart',
            ),
            _HostCommand(
              label: l10n.e7SetupFollowLog,
              command: 'bash ubuntu-opencode.sh logs',
            ),
            _HostCommand(
              label: l10n.e7SetupUpdateHost,
              detail: l10n.e7SetupUpdateHostDetail,
              command: 'bash ubuntu-opencode.sh update',
            ),
          ],
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.gutter,
            end: tokens.gutter,
            top: tokens.space3,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: KitButton.tertiary(
              key: const ValueKey('host-docs-link'),
              label: l10n.e7SetupFullWalkthrough,
              icon: AppIconography.externalLink,
              onPressed: () => openExternalLink(context, docsUrl),
            ),
          ),
        ),
      ],
    );
  }
}

/// One host command: what it does, why (optional), and the command itself
/// in the kit's code block with its own copy button.
class _HostCommand extends StatelessWidget {
  const _HostCommand({
    super.key,
    required this.label,
    required this.command,
    this.detail,
  });

  final String label;
  final String? detail;
  final String command;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final detail = this.detail;
    return KitRow(
      title: label,
      titleMaxLines: 2,
      supporting: detail == null ? null : TextSpan(text: detail),
      supportingMaxLines: 4,
      below: Padding(
        padding: EdgeInsets.only(top: tokens.space2, bottom: tokens.space2),
        child: KitCodeBlock(
          text: command,
          kind: KitCodeKind.command,
          copyLabel: l10n.e7SetupCopyCommandLabel(label),
          copyKey: ValueKey('copy-host-command-$label'),
        ),
      ),
    );
  }
}
