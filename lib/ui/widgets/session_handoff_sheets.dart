import 'package:flutter/material.dart';

import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_details_fold.dart';
import 'package:opencode_mobile/ui/kit/kit_notice.dart';
import 'package:opencode_mobile/ui/kit/kit_qr.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import '../../domain/session_handoff.dart';
import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The CLI versions the resume syntax was verified against, for the sheet's
/// Details fold. Recorded in docs/qa/f4-session-handoff/README.md with the
/// exact `--help` output.
const sessionResumeVerifiedVersions = 'opencode 1.18.25, opencode2 beta-19242';

/// What they pop with when the person picks "Reload conversation" on the
/// unavailable state (only offered when the host passes `offerReload`).
const continueOnComputerReload = 'reload';

/// F4-S1 in the kit sheet frame: the terminal command that resumes this
/// session on the computer running the server, wrapped so all of it shows.
/// Resolves to [continueOnComputerReload] when the person asks to reload a
/// conversation whose folder the server did not report, and null when they
/// close it. The sheet itself never connects or sends anything; copying
/// only writes the clipboard. Export lives in the conversation menu.
Future<String?> showContinueOnComputerSheet(
  BuildContext context, {
  required SessionResumeCommand command,
  bool offerReload = false,
}) {
  final l10n = _l10n(context);
  return showKitSheet<String>(
    context,
    title: l10n.handoffUiComputerTitle,
    icon: AppIconography.computer,
    body: (context) =>
        _ContinueOnComputerBody(command: command, offerReload: offerReload),
  );
}

/// F4-S2 in the kit sheet frame: see [ContinueOnPhoneSheet].
Future<void> showContinueOnPhoneSheet(
  BuildContext context, {
  required SessionLink? link,
}) {
  final l10n = _l10n(context);
  return showKitSheet<void>(
    context,
    title: l10n.handoffUiPhoneTitle,
    icon: AppIconography.qrCode,
    body: (context) => _ContinueOnPhoneBody(link: link),
  );
}

/// F4-S1 as a whole sheet (header and body) for a host that opens its own
/// modal route; [showContinueOnComputerSheet] is the kit way to open it.
/// Pops with [continueOnComputerReload]; otherwise closes with null.
class ContinueOnComputerSheet extends StatelessWidget {
  const ContinueOnComputerSheet({
    super.key,
    required this.command,
    this.offerReload = false,
  });

  final SessionResumeCommand command;

  /// Offer "Reload conversation" when the server did not report a folder;
  /// the host reloads the conversation and opens the sheet again.
  final bool offerReload;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return KitSheet(
      title: l10n.handoffUiComputerTitle,
      icon: AppIconography.computer,
      // The host's modal route draws its own drag handle.
      handle: false,
      onClose: () => Navigator.maybePop(context),
      child: _ContinueOnComputerBody(
        command: command,
        offerReload: offerReload,
      ),
    );
  }
}

class _ContinueOnComputerBody extends StatelessWidget {
  const _ContinueOnComputerBody({
    required this.command,
    required this.offerReload,
  });

  final SessionResumeCommand command;
  final bool offerReload;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final tokens = KitTokens.of(context);
    final binary = command.binary;
    final unavailable = command.unavailable;
    final gap = SizedBox(height: tokens.space3);
    return Column(
      key: const Key('continue-on-computer-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitText(l10n.handoffUiComputerIntro(binary)),
        gap,
        if (command.command case final text?) ...[
          KitCodeBlock(
            text: text,
            // The command is what this sheet exists to show: all of it,
            // wrapped under its prompt, never cut at the sheet's edge
            // (R3's hanging wrap), with the command's own copy label.
            kind: KitCodeKind.command,
            caption: l10n.handoffUiComputerCommandLabel,
            wrap: true,
            showWrapToggle: false,
            highlight: false,
            copyLabel: l10n.handoffSheetCopyCommand,
            blockKey: const Key('continue-on-computer-command'),
            copyKey: const Key('continue-on-computer-copy'),
          ),
          gap,
          KitText(
            l10n.handoffUiComputerDirectoryNote,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
          gap,
          KitDetailsFold(
            foldKey: const Key('continue-on-computer-details'),
            notes: [
              l10n.handoffUiComputerVerify(
                sessionResumeVerifiedVersions,
                binary,
              ),
            ],
          ),
        ] else
          KitNotice(
            key: const Key('continue-on-computer-unavailable'),
            icon: AppIconography.info,
            message: switch (unavailable) {
              SessionResumeUnavailable.managedWorkspace =>
                l10n.handoffUiUnavailableWorkspace,
              SessionResumeUnavailable.invalidSessionID =>
                l10n.handoffUiUnavailableReference,
              SessionResumeUnavailable.missingDirectory ||
              SessionResumeUnavailable.unsafeDirectory ||
              null => l10n.handoffUiUnavailableDirectory,
            },
            actions: [
              // Reloading helps only when the folder was not reported; a
              // cloud environment or an unsafe reference stays unavailable.
              if (offerReload &&
                  (unavailable == SessionResumeUnavailable.missingDirectory ||
                      unavailable == null))
                KitAction(
                  key: const Key('continue-on-computer-reload'),
                  label: l10n.handoffSheetReloadConversation,
                  icon: AppIconography.retry,
                  onPressed: () =>
                      Navigator.pop(context, continueOnComputerReload),
                ),
            ],
          ),
      ],
    );
  }
}

/// F4-S2: a QR code carrying the `opencode-mobile://session` link for this
/// session, plus the same link as text with a copy button, as a whole
/// sheet for a host that opens its own modal route
/// ([showContinueOnPhoneSheet] is the kit way). Route identifiers only; the
/// sheet cannot leak more than [SessionLink] holds.
class ContinueOnPhoneSheet extends StatelessWidget {
  const ContinueOnPhoneSheet({super.key, required this.link});

  /// Null when either identifier failed validation; the sheet then shows
  /// its unavailable state instead of guessing.
  final SessionLink? link;

  @override
  Widget build(BuildContext context) => KitSheet(
    title: _l10n(context).handoffUiPhoneTitle,
    icon: AppIconography.qrCode,
    handle: false,
    onClose: () => Navigator.maybePop(context),
    child: _ContinueOnPhoneBody(link: link),
  );
}

class _ContinueOnPhoneBody extends StatelessWidget {
  const _ContinueOnPhoneBody({required this.link});

  final SessionLink? link;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final tokens = KitTokens.of(context);
    final link = this.link;
    final gap = SizedBox(height: tokens.space3);
    return Column(
      key: const Key('continue-on-phone-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitText(l10n.handoffUiPhoneIntro),
        gap,
        if (link == null)
          KitNotice(
            key: const Key('continue-on-phone-unavailable'),
            icon: AppIconography.info,
            message: l10n.handoffUiPhoneUnavailable,
          )
        else ...[
          Center(
            child: KitQr(
              data: link.toString(),
              semanticsLabel: l10n.handoffUiPhoneQrLabel,
              qrKey: const Key('session-link-qr'),
            ),
          ),
          gap,
          KitCodeBlock(
            text: link.toString(),
            kind: KitCodeKind.output,
            caption: l10n.handoffUiPhoneLinkLabel,
            wrap: true,
            showWrapToggle: false,
            highlight: false,
            copyLabel: l10n.handoffUiPhoneCopyLink,
            blockKey: const Key('continue-on-phone-link'),
            copyKey: const Key('continue-on-phone-copy'),
          ),
          gap,
          // What happens on a phone that does not have this server yet: it
          // says so and offers Servers (handoffUiLinkServerMissing).
          KitNotice(
            key: const Key('continue-on-phone-server-note'),
            icon: AppIconography.server,
            message: l10n.handoffSheetPhoneServerNote,
            liveRegion: false,
          ),
        ],
      ],
    );
  }
}

/// Retired by shared-chat-1: use [KitQr]. Forwards to it, [size] capping
/// the width the code may take.
class SessionLinkQr extends StatelessWidget {
  const SessionLinkQr({
    super.key,
    required this.data,
    required this.size,
    this.semanticsLabel,
  });

  final String data;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: size < 0 ? 0 : size),
    child: KitQr(
      data: data,
      semanticsLabel: semanticsLabel ?? _l10n(context).handoffUiPhoneQrLabel,
      qrKey: const Key('session-link-qr'),
    ),
  );
}
