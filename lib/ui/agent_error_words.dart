import '../api/models.dart';
import '../domain/agent_error_text.dart';
import '../l10n/app_localizations.dart';

/// What to show for an agent error: a sentence a person can use, and, when
/// the cause is recognised, what happens next or what to do. [humanized] is
/// true when the sentence is the app's and not the server's, in which case
/// the server's own text belongs behind a Details view.
typedef AgentErrorWords = ({String headline, String? hint, bool humanized});

AgentErrorWords agentErrorWords(String raw, AppLocalizations l10n) {
  final words = switch (classifyAgentError(raw)) {
    AgentErrorCause.connectionDropped => (
      l10n.agentErrorConnectionDropped,
      l10n.agentErrorConnectionDroppedHint,
    ),
    AgentErrorCause.timedOut => (
      l10n.agentErrorTimedOut,
      l10n.agentErrorTimedOutHint,
    ),
    AgentErrorCause.providerUnreachable => (
      l10n.agentErrorProviderUnreachable,
      l10n.agentErrorProviderUnreachableHint,
    ),
    AgentErrorCause.requestTooLarge => (
      l10n.agentErrorRequestTooLarge,
      l10n.agentErrorRequestTooLargeHint,
    ),
    AgentErrorCause.rateLimited => (
      l10n.agentErrorRateLimited,
      l10n.agentErrorRateLimitedHint,
    ),
    AgentErrorCause.providerBusy => (
      l10n.agentErrorProviderBusy,
      l10n.agentErrorProviderBusyHint,
    ),
    AgentErrorCause.outOfCredit => (
      l10n.agentErrorOutOfCredit,
      l10n.agentErrorOutOfCreditHint,
    ),
    AgentErrorCause.serverDiskFull => (
      l10n.agentErrorServerDiskFull,
      l10n.agentErrorServerDiskFullHint,
    ),
    null => null,
  };
  if (words != null) {
    return (headline: words.$1, hint: words.$2, humanized: true);
  }
  // Not a cause the app knows: the server's own sentence, minus the parts
  // only its author could use.
  return (
    headline: cleanAgentErrorText(errorHeadline(raw)),
    hint: null,
    humanized: false,
  );
}
