import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../kit/kit.dart';
import '../widgets/local_agent_onboarding.dart';

/// Claude Code on this phone, on its own page
/// (docs/design/phone-server-screens-cleanup-2026-09-24.md §2): the phone
/// server's details show it as one optional row, and everything about it
/// (the offer, installing, signing in, the project folder, start and stop)
/// lives here.
class LocalAgentScreen extends ConsumerWidget {
  const LocalAgentScreen({super.key, required this.onConnected});

  /// Called once the app is connected through Claude Code.
  final VoidCallback onConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.localAgentPageTitle)),
      // A plain scroll view, not a lazy list: the block is empty while it
      // checks the phone, and a lazy list would drop an empty child (and
      // with it the check) before it had anything to show.
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, KitScreen.endPadding(context)),
        child: LocalAgentOnboardingBlock(
          key: const ValueKey('local-agent-block'),
          connection: ref.read(connProvider),
          onConnected: onConnected,
          // Claude Code only runs through the Termux-hosted Ubuntu today
          // (P1.6 adds the in-app Claude Code component): this is the only
          // door that actually unblocks it, whether nothing is set up yet
          // or the in-app Linux already is.
          onOpenPhoneSetup: () =>
              unawaited(Navigator.of(context).pushNamed('/termux-setup')),
        ),
      ),
    );
  }
}
