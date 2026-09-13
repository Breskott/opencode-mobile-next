import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import '../../domain/session_handoff.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'agent_blocks.dart';

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The CLI versions the resume syntax was verified against, for the sheet's
/// footnote. Recorded in docs/qa/f4-session-handoff/README.md with the
/// exact `--help` output.
const sessionResumeVerifiedVersions = 'opencode 1.18.25, opencode2 beta-19242';

/// F4-S1: the terminal command that resumes this session on the computer
/// running the server. Pops with `'export'` when the user chooses the
/// cross-server export route instead; otherwise closes with null. The sheet
/// itself never copies, connects or sends anything — the copy button lives
/// in [AgentCommandBlock] and only writes the clipboard.
class ContinueOnComputerSheet extends StatelessWidget {
  const ContinueOnComputerSheet({
    super.key,
    required this.command,
    required this.exportAvailable,
  });

  final SessionResumeCommand command;

  /// Whether the connected server can export this session as a file; the
  /// hint still reads as guidance when false, but without a button that
  /// would only fail.
  final bool exportAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final binary = command.binary;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
          child: Column(
            key: const Key('continue-on-computer-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AppIconography.computer, size: 20, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.handoffUiComputerTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.handoffUiComputerIntro(binary)),
              const SizedBox(height: 12),
              if (command.command case final text?) ...[
                AgentCommandBlock(commands: [text]),
                const SizedBox(height: 8),
                Text(
                  l10n.handoffUiComputerDirectoryNote,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.handoffUiComputerVerify(
                    sessionResumeVerifiedVersions,
                    binary,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ] else
                Container(
                  key: const Key('continue-on-computer-unavailable'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(switch (command.unavailable) {
                    SessionResumeUnavailable.managedWorkspace =>
                      l10n.handoffUiUnavailableWorkspace,
                    SessionResumeUnavailable.invalidSessionID =>
                      l10n.handoffUiUnavailableReference,
                    SessionResumeUnavailable.missingDirectory ||
                    SessionResumeUnavailable.unsafeDirectory ||
                    null => l10n.handoffUiUnavailableDirectory,
                  }),
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                l10n.handoffUiExportHint,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (exportAvailable) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const Key('continue-on-computer-export'),
                    onPressed: () => Navigator.pop(context, 'export'),
                    icon: const Icon(AppIconography.download, size: 18),
                    label: Text(l10n.handoffUiExportAction),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// F4-S2: a QR code carrying the `opencode-mobile://session` link for this
/// session, plus the same link as text with a copy button. Route
/// identifiers only; the sheet cannot leak more than [SessionLink] holds.
class ContinueOnPhoneSheet extends StatelessWidget {
  const ContinueOnPhoneSheet({super.key, required this.link});

  /// Null when either identifier failed validation; the sheet then shows
  /// its unavailable state instead of guessing.
  final SessionLink? link;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_l10n(context).handoffUiPhoneLinkCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final link = this.link;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
          child: Column(
            key: const Key('continue-on-phone-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AppIconography.qrCode, size: 20, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.handoffUiPhoneTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.handoffUiPhoneIntro),
              const SizedBox(height: 16),
              if (link == null)
                Container(
                  key: const Key('continue-on-phone-unavailable'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l10n.handoffUiPhoneUnavailable),
                )
              else ...[
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SessionLinkQr(
                      data: link.toString(),
                      size: math.min(240, constraints.maxWidth),
                      semanticsLabel: l10n.handoffUiPhoneQrLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.handoffUiPhoneLinkLabel,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          link.toString(),
                          key: const Key('continue-on-phone-link'),
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: AppTheme.monoFamily,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('continue-on-phone-copy'),
                      tooltip: l10n.handoffUiPhoneCopyLink,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      iconSize: 18,
                      icon: Icon(AppIcons.copy, color: muted),
                      onPressed: () => _copy(context, link.toString()),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A QR code painted from the `qr` encoder: black modules on a white card
/// with a four-module quiet zone, regardless of theme, because scanners
/// read contrast rather than palette.
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

  static const _quietModules = 4;

  @override
  Widget build(BuildContext context) {
    final QrImage image;
    try {
      image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
    } on InputTooLongException {
      return const SizedBox.shrink();
    }
    final side = math.max(0.0, size);
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('session-link-qr'),
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: _QrPainter(image, quietModules: _quietModules),
          ),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.image, {required this.quietModules});

  final QrImage image;
  final int quietModules;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount + quietModules * 2;
    final cell = math.min(size.width, size.height) / modules;
    if (cell <= 0) return;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    final origin = Offset(
      (size.width - cell * modules) / 2 + cell * quietModules,
      (size.height - cell * modules) / 2 + cell * quietModules,
    );
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        // Overlap neighbours by a hair so scaling never leaves seams.
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cell,
            origin.dy + row * cell,
            cell + .25,
            cell + .25,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.quietModules != quietModules;
}
