import '../api/models.dart';
import '../domain/server_gateway.dart';

/// Words that may reach the notification shade, kept safe.
///
/// The shade (not the lock screen, which gets a count-only public version)
/// shows a command or the first line of a reply so the person can decide
/// without opening the app. Nothing secret may ride along: keys, tokens and
/// passwords are masked, and raw errors never become copy.

const _mask = '•••';

typedef _Mask = String Function(Match match);

final List<(RegExp, _Mask)> _secretPatterns = [
  // Authorization headers and bearer tokens.
  (
    RegExp(r'\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{6,}', caseSensitive: false),
    (m) => '${m[1]} $_mask',
  ),
  // key=value and key: value pairs that name a secret: the name stays.
  (
    RegExp(
      r"""\b((?:api[_-]?key|access[_-]?key|secret|token|passwd|password|pwd|authorization|auth)[A-Za-z0-9_-]*)\s*[=:]\s*("[^"]*"|'[^']*'|\S+)""",
      caseSensitive: false,
    ),
    (m) => '${m[1]}=$_mask',
  ),
  // Flags that carry a secret.
  (
    RegExp(
      r'(--?(?:password|passwd|token|secret|api-key|apikey|key|auth))[ =]+("[^"]*"|\S+)',
      caseSensitive: false,
    ),
    (m) => '${m[1]} $_mask',
  ),
  // user:password@host
  (RegExp(r'(?<=://)[^/\s:@]+:[^/\s@]+(?=@)'), (_) => _mask),
  // Well-known token shapes.
  (RegExp(r'\b(?:sk|pk|rk)-[A-Za-z0-9_-]{8,}'), (_) => _mask),
  (RegExp(r'\bgh[pousr]_[A-Za-z0-9]{16,}'), (_) => _mask),
  (RegExp(r'\bxox[abprs]-[A-Za-z0-9-]{10,}'), (_) => _mask),
  (RegExp(r'\bAKIA[0-9A-Z]{16}\b'), (_) => _mask),
  (RegExp(r'\bAIza[0-9A-Za-z_-]{20,}'), (_) => _mask),
  // Any long unbroken token-looking run.
  (RegExp(r'[A-Za-z0-9+/_=-]{32,}'), (_) => _mask),
];

/// One short line of [input] with secrets masked, at most [maxLength] long.
String redactForNotification(String input, {int maxLength = 140}) {
  var text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final (pattern, replace) in _secretPatterns) {
    text = text.replaceAllMapped(pattern, replace);
  }
  if (text.length > maxLength) {
    text = '${text.substring(0, maxLength - 1).trimRight()}…';
  }
  return text;
}

/// The first line of the newest assistant reply, redacted; empty when none.
String firstReplyLine(List<MessageWithParts> messages, {int maxLength = 140}) {
  for (final message in messages.reversed) {
    if (message.info.role != 'assistant') continue;
    for (final part in message.parts) {
      if (part.type != 'text' || part.synthetic) continue;
      for (final line in part.text.split('\n')) {
        final trimmed = line.replaceFirst(RegExp(r'^[#>*\-\s`]+'), '').trim();
        if (trimmed.isNotEmpty) {
          return redactForNotification(trimmed, maxLength: maxLength);
        }
      }
    }
  }
  return '';
}

/// A plain reason token for a stopped chat; native turns it into a sentence.
/// Never the server's own text. Must match `alertReasonText` in
/// BackgroundConnectionService.kt.
String stoppedReasonToken(String? errorName) =>
    switch (MessageErrorKind.fromName(errorName)) {
      MessageErrorKind.providerAuth => 'auth',
      MessageErrorKind.contextOverflow => 'context',
      MessageErrorKind.outputLength => 'length',
      MessageErrorKind.contentFilter => 'filter',
      MessageErrorKind.modelNotFound => 'model',
      _ => 'other',
    };

/// A question's choices as notification buttons: one single-choice prompt
/// with three or fewer short choices, else none (the alert only opens the
/// app). Must agree with `AlertButtons.shortOptions` in
/// StatusNotificationModel.kt.
List<String> notificationOptionsOf(PendingQuestion question) {
  if (question.prompts.length != 1) return const [];
  final prompt = question.prompts.single;
  if (prompt.multiple) return const [];
  final labels = [for (final choice in prompt.choices) choice.label.trim()];
  if (labels.isEmpty || labels.length > 3) return const [];
  if (labels.any((label) => label.isEmpty || label.length > 24)) {
    return const [];
  }
  if (labels.toSet().length != labels.length) return const [];
  return labels;
}
