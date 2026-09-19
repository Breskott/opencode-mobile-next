import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
import '../widgets/first_run_choice.dart';

/// The second first-run question, met only by people who said their agent
/// runs on a computer (UX plan 5.6 step 2a). The answer picks the form, so
/// nobody reads a backend selector before they know what a backend is.
class AgentChoiceScreen extends StatelessWidget {
  const AgentChoiceScreen({super.key, required this.onChoose});

  /// Opens the connect screen for the chosen agent on top of this one, so
  /// Back from there returns to the question.
  final ValueChanged<ServerBackend> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    return Scaffold(
      key: const ValueKey('agent-choice-screen'),
      appBar: AppBar(title: Text(copy.firstRunOnComputer)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      copy.firstRunWhichAgent,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FirstRunChoice(
                    key: const ValueKey('agent-choice-opencode'),
                    icon: AppIconography.server,
                    title: copy.firstRunAgentOpenCode,
                    detail: copy.oc2DiscoveryAutodetect,
                    onTap: () => onChoose(ServerBackend.openCode),
                  ),
                  FirstRunChoice(
                    key: const ValueKey('agent-choice-paseo'),
                    icon: AppIconography.server,
                    title: copy.firstRunAgentClaudeOrPi,
                    detail: copy.firstRunAgentClaudeOrPiDetail,
                    onTap: () => onChoose(ServerBackend.paseo),
                  ),
                  FirstRunChoice(
                    key: const ValueKey('agent-choice-codex'),
                    icon: AppIconography.server,
                    title: copy.firstRunAgentCodex,
                    detail: copy.firstRunAgentCodexDetail,
                    onTap: () => onChoose(ServerBackend.codex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
