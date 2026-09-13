import '../../l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../widgets/product_states.dart';
import '../app_theme.dart';

/// Host-side management for a remote OpenCode server.
///
/// The app cannot execute commands on the host, so this surface is truthful
/// by construction: it shows the server facts the app already knows and
/// provides exact, copyable commands for the documented Ubuntu helper
/// script. It never claims the app performed a host action.
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
    final profile = controller.profile;
    final port = _serverPort();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7SetupLinuxService,
        ),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            SectionLabel(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupThisServer,
            ),
            ListTile(
              leading: const Icon(AppIconography.server),
              title: Text(
                profile?.name ??
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7SetupDefaultServer,
              ),
              subtitle: SelectableText(
                profile?.baseUrl ??
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7SetupNotConnected,
                textDirection: profile?.baseUrl == null
                    ? Directionality.of(context)
                    : TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: AppTheme.codeFontSize,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(AppIconography.info),
              title: Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7SetupServerVersion(
                  controller.version ??
                      lookupAppLocalizations(
                        Localizations.localeOf(context),
                      ).e7SetupUnknownVersion,
                ),
              ),
              subtitle: Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7SetupHostInstructions,
              ),
            ),
            SectionLabel(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupHostFirstSetup,
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupInstallService,
              detail: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupInstallServiceDetail,
              command:
                  'curl -fsSL $scriptUrl -o ubuntu-opencode.sh && '
                  'OPENCODE_PORT=$port bash ubuntu-opencode.sh install',
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupKeepAfterLogout,
              command: 'loginctl enable-linger "\$USER"',
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupReadPassword,
              command: 'bash ubuntu-opencode.sh password',
            ),
            // `adb reverse` forwards a port to an attached *Android* device.
            // On desktop the app and the server share a machine, so the tile
            // described a cable that is not there.
            if (platformCapabilities.supportsUsbHostBridge)
              _HostCommandTile(
                key: const Key('host-command-adb-reverse'),
                label: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7SetupUsbAccess,
                command: 'adb reverse tcp:$port tcp:$port',
              ),
            SectionLabel(
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupHostDaily,
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupServiceStatus,
              command: 'bash ubuntu-opencode.sh status',
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupRestartServer,
              command: 'bash ubuntu-opencode.sh restart',
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupFollowLog,
              command: 'bash ubuntu-opencode.sh logs',
            ),
            _HostCommandTile(
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupUpdateHost,
              detail: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupUpdateHostDetail,
              command: 'bash ubuntu-opencode.sh update',
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('host-docs-link'),
                  onPressed: () => launchUrl(
                    Uri.parse(docsUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(AppIconography.externalLink, size: 18),
                  label: Text(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).e7SetupFullWalkthrough,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostCommandTile extends StatelessWidget {
  const _HostCommandTile({
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.hairline(theme)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedOf(theme),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  SelectableText(
                    command,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: AppTheme.codeFontSize,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupCopyCommandLabel(label),
              child: IconButton(
                key: ValueKey('copy-host-command-$label'),
                tooltip: lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).handoffCopyCommand,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: command));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lookupAppLocalizations(
                            Localizations.localeOf(context),
                          ).e7SetupHostCopied,
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(AppIcons.copy, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
