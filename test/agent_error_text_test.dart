import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/agent_error_text.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/agent_error_words.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  const reset =
      'ECONNRESET: The socket connection was closed unexpectedly. For more '
      'information, pass `verbose: true` in the second argument to fetch()';

  test('runtime errors are recognised by cause', () {
    final cases = {
      reset: AgentErrorCause.connectionDropped,
      'socket hang up': AgentErrorCause.connectionDropped,
      'WebSocket inbound queue overflow': AgentErrorCause.requestTooLarge,
      '413 Payload Too Large': AgentErrorCause.requestTooLarge,
      'Error: 429 Too Many Requests': AgentErrorCause.rateLimited,
      'rate_limit_exceeded: slow down': AgentErrorCause.rateLimited,
      'Overloaded': AgentErrorCause.providerBusy,
      '503 Service Unavailable': AgentErrorCause.providerBusy,
      'connect ETIMEDOUT 1.2.3.4:443': AgentErrorCause.timedOut,
      'The operation timed out.': AgentErrorCause.timedOut,
      'getaddrinfo ENOTFOUND api.openai.com':
          AgentErrorCause.providerUnreachable,
      'fetch failed': AgentErrorCause.providerUnreachable,
      'You exceeded your current quota, please check your plan':
          AgentErrorCause.outOfCredit,
      'ENOSPC: no space left on device, write': AgentErrorCause.serverDiskFull,
    };
    for (final entry in cases.entries) {
      expect(classifyAgentError(entry.key), entry.value, reason: entry.key);
    }
    // A rate limit that also mentions a dropped socket is a rate limit.
    expect(
      classifyAgentError('429 rate limit; connection closed'),
      AgentErrorCause.rateLimited,
    );
    expect(classifyAgentError('The file lib/main.dart does not exist'), isNull);
    expect(classifyAgentError(''), isNull);
  });

  test('a recognised cause is said in plain words, with what happens next', () {
    final words = agentErrorWords(reset, en);
    expect(words.headline, 'The connection to the model dropped.');
    expect(words.hint, contains('retries by itself'));
    expect(words.humanized, isTrue);
    expect(words.headline, isNot(contains('ECONNRESET')));
    expect(words.headline, isNot(contains('fetch()')));
  });

  test('an unknown error keeps its own words, minus the programmer talk', () {
    final words = agentErrorWords(
      'TypeError: Cannot read properties of undefined. For more information, '
      'pass `verbose: true` in the second argument to fetch()',
      en,
    );
    expect(words.headline, 'Cannot read properties of undefined.');
    expect(words.hint, isNull);
    expect(words.humanized, isFalse);
    expect(
      cleanAgentErrorText('EACCES: permission denied'),
      'permission denied',
    );
    // Nothing left after cleaning: keep what was there.
    expect(cleanAgentErrorText('ECONNRESET:'), 'ECONNRESET:');
  });

  test('every cause has Arabic wording too', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final words = agentErrorWords(reset, ar);
    expect(words.headline, isNot(en.agentErrorConnectionDropped));
    expect(words.hint, isNotNull);
  });
}
