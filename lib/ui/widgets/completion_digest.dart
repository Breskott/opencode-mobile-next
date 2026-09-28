import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/completion_digest.dart';
import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import 'product_states.dart' show showProductError;

/// Deliberately formats only allowlisted counts and app-authored copy.
class CompletionDigestCard extends StatelessWidget {
  const CompletionDigestCard({
    super.key,
    required this.digest,
    required this.onOpenConversation,
    required this.onReview,
    required this.onDismiss,
    this.onRunResults,
  });

  final CompletionDigest digest;
  final VoidCallback onOpenConversation;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  /// Opens the server-recorded outcome and tool evidence of the latest run.
  /// Null hides the action.
  final VoidCallback? onRunResults;

  String _changedFilesText(AppLocalizations l10n) => digest.changedFiles == null
      ? l10n.digestChangedFilesUnknown
      : l10n.digestChangedFiles(digest.changedFiles!);

  String _pendingDecisionsText(AppLocalizations l10n) =>
      digest.pendingDecisions == null
      ? l10n.digestPendingDecisionsUnknown
      : l10n.digestPendingDecisions(digest.pendingDecisions!);

  String _sanitizedSummary(AppLocalizations l10n) => [
    l10n.digestStatusUnverified,
    _changedFilesText(l10n),
    _pendingDecisionsText(l10n),
    l10n.digestOutcomesUnknown,
    l10n.digestProvenance,
  ].join('\n');

  /// Copies the app-authored summary, announced once (KitCopy, KIT-23: no
  /// SnackBar); a clipboard that refuses says so in a kit alert.
  Future<void> _copy(BuildContext context, AppLocalizations l10n) async {
    try {
      await KitCopy.copy(
        context,
        _sanitizedSummary(l10n),
        announcement: l10n.digestCopySucceeded,
      );
    } catch (error) {
      if (!context.mounted) return;
      showProductError(context, error, title: l10n.digestCopyFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: tokens.gutter,
        vertical: tokens.space2,
      ),
      child: Column(
        key: const Key('completion-digest-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitText(l10n.digestStatusUnverified, role: KitTextRole.rowTitle),
          SizedBox(height: tokens.space2),
          KitText(_changedFilesText(l10n)),
          KitText(_pendingDecisionsText(l10n)),
          KitText(l10n.digestOutcomesUnknown),
          SizedBox(height: tokens.space2),
          KitText(l10n.digestProvenance, role: KitTextRole.secondary),
          Wrap(
            spacing: tokens.space2,
            runSpacing: tokens.space1,
            children: [
              KitButton.tertiary(
                label: l10n.digestOpenConversation,
                onPressed: onOpenConversation,
              ),
              KitButton.tertiary(label: l10n.digestReview, onPressed: onReview),
              if (onRunResults != null)
                KitButton.tertiary(
                  key: const Key('completion-digest-run-results'),
                  label: l10n.digestRunResults,
                  icon: AppIconography.checklist,
                  onPressed: onRunResults,
                ),
              KitButton.tertiary(
                key: const Key('completion-digest-copy'),
                label: l10n.digestCopy,
                icon: AppIconography.copy,
                onPressed: () => unawaited(_copy(context, l10n)),
              ),
              KitButton.tertiary(
                label: l10n.digestDismiss,
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
