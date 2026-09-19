import '../../api/models.dart' show Session;
import '../../l10n/app_localizations.dart';

/// The placeholder the server assigns before it names a session, e.g.
/// `New session - 2026-09-02T14:47:06.902Z`. The timestamp is server-side
/// bookkeeping, not a title anyone chose, so the UI shows only the prefix.
final RegExp _placeholderTitle = RegExp(
  r'^New session\s*-\s*\d{4}-\d{2}-\d{2}T[\d:.]+(?:Z|[+-]\d{2}:?\d{2})?$',
);

/// The session title as the app presents it: the server's own title, with
/// the ISO-stamped placeholder collapsed to "New conversation", or [fallback] when
/// the session has no title at all. Every session list and the chat app bar
/// share this so a session reads the same wherever it appears.
String presentedSessionTitle(
  Session? session, {
  String fallback = 'New conversation',
  AppLocalizations? l10n,
}) {
  final title = session?.title?.trim() ?? '';
  if (title.isEmpty) {
    return fallback == 'New conversation'
        ? l10n?.workspaceNewSession ?? fallback
        : fallback;
  }
  if (_placeholderTitle.hasMatch(title)) {
    return l10n?.workspaceNewSession ?? 'New conversation';
  }
  return title;
}
