import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../app_theme.dart';
import '../setup_commands.dart';
import '../widgets/product_states.dart';
import 'connection_help_screen.dart';

/// Setup guide. Leads with the one story a first-time user needs — run
/// `opencode2 pair`, scan or paste, start talking — and folds every other
/// route (HTTPS proxies, SSH tunnels, older `opencode serve` servers, Termux
/// internals) behind an "Advanced" disclosure so nobody has to pick a path
/// before they know what the app does.
class GuideScreen extends StatelessWidget {
  final bool embedded;
  const GuideScreen({super.key, this.embedded = false});

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    // The on-device path is Termux, which is Android-only. A desktop reader
    // is told about the one path that exists for them rather than a second
    // one they cannot take.
    final onDevice = platformCapabilities.supportsTermux;
    final canScan = platformCapabilities.supportsQrPairing;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          _sharedCopy(context).e7SharedThreeStepsToYourFirstSession,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          _sharedCopy(context).e7SharedOpenCodeRunsOnYourComputerThisApp,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _Step(
          n: 1,
          title: _sharedCopy(context).e7SharedOnYourComputerRunOneCommand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_sharedCopy(context).e7SharedInATerminalOnTheComputerWhere),
              const Cmd(
                SetupCommands.pair,
                key: ValueKey('guide-pair-command'),
              ),
              Text(_sharedCopy(context).e7SharedItStartsTheServerAndPrintsA),
            ],
          ),
        ),
        _Step(
          n: 2,
          title: canScan
              ? _sharedCopy(context).e7SharedScanTheQROrPasteTheCode
              : _sharedCopy(context).e7SharedPasteTheCodeInThisApp,
          child: Text(
            canScan
                ? _sharedCopy(context).e7SharedOpenServersTapScanAndPointThe
                : _sharedCopy(context).e7SharedCopyThePrintedCodeOpenServersAnd,
          ),
        ),
        _Step(
          n: 3,
          title: _sharedCopy(context).e7SharedStartTalking,
          child: Text(
            _sharedCopy(context).e7SharedPickAProjectAndSendYourFirst,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIconography.question),
          title: Text(l10n.connectionHelpTitle),
          subtitle: Text(l10n.connectionHelpEntrySubtitle),
          trailing: const Icon(AppIconography.chevronRight),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const ConnectionHelpScreen()),
          ),
        ),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('guide-advanced'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: const Icon(AppIconography.settings),
            title: Text(_sharedCopy(context).e7SharedAdvanced),
            subtitle: Text(
              onDevice
                  ? _sharedCopy(
                      context,
                    ).e7SharedHTTPSSSHTunnelsOlderServersTermuxInternals
                  : _sharedCopy(context).e7SharedHTTPSSSHTunnelsOlderServers,
            ),
            children: [
              _Section(
                title: _sharedCopy(context).e7SharedReachAServerOverHTTPSOrA,
                children: [
                  Text(
                    _sharedCopy(
                      context,
                    ).e7SharedPairingWorksWhenTheAddressTheServer,
                  ),
                  _tip(context, l10n.connectionHelpGuideTip),
                ],
              ),
              _Section(
                title: _sharedCopy(context).e7SharedOlderServersWithoutPairing,
                children: [
                  Text(
                    _sharedCopy(
                      context,
                    ).e7SharedServersStartedWithOpencodeServeDoNot,
                  ),
                  const Cmd(SetupCommands.legacyServe),
                  Text(
                    _sharedCopy(
                      context,
                    ).e7SharedThenAddTheServerManuallyWithUsername,
                  ),
                ],
              ),
              if (onDevice)
                _Section(
                  key: const ValueKey('guide-termux-section'),
                  title: _sharedCopy(
                    context,
                  ).e7SharedOnDeviceViaTermuxAutomated,
                  children: [
                    Text(
                      _sharedCopy(context).e7SharedUseTheOnDeviceTermuxCardOn,
                    ),
                    _tip(
                      context,
                      _sharedCopy(
                        context,
                      ).e7SharedOnlyTwoTapsNeedYouPersonallyDownloading,
                    ),
                    Text(
                      _sharedCopy(context).e7SharedPreferManualInsideTermuxRun,
                    ),
                    const Cmd(
                      '# plain-Termux npm installs are broken upstream\n'
                      '# (npm os=android -> no opencode-android-arm64 package),\n'
                      '# so we use an Ubuntu chroot:\n'
                      'pkg install proot-distro\n'
                      'proot-distro install ubuntu\n'
                      'proot-distro login ubuntu\n'
                      '  apt update && apt install -y nodejs npm\n'
                      '  npm i -g opencode-ai\n'
                      '  opencode serve --hostname 127.0.0.1 --port 4096 &\n'
                      'exit',
                    ),
                    Text(
                      _sharedCopy(
                        context,
                      ).e7SharedTheChrootSharesTheNetworkStackSo,
                    ),
                  ],
                ),
              _Section(
                title: _sharedCopy(context).e7SharedSecurityNotes,
                children: [
                  Bullet(
                    _sharedCopy(
                      context,
                    ).e7SharedAlwaysSetOPENCODESERVERPASSWORDWhenBinding,
                  ),
                  Bullet(
                    onDevice
                        ? _sharedCopy(
                            context,
                          ).e7SharedPasswordsAreStoredInTheAndroidKeystore
                        : platformCapabilities.platform == TargetPlatform.iOS
                        ? l10n.iosKeychainGuide
                        : l10n.platformSecureStorageGuide,
                  ),
                  Bullet(
                    _sharedCopy(
                      context,
                    ).e7SharedTheServerCanExecuteCommandsOnIts,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _tip(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIconography.idea, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) return _body(context);
    return Scaffold(
      appBar: AppBar(title: Text(_sharedCopy(context).onboardingSetupGuide)),
      body: _body(context),
    );
  }
}

/// One numbered step of the three-step story. The number is decorative for
/// sighted readers and spoken as "Step 1 of 3" for everyone else.
class _Step extends StatelessWidget {
  final int n;
  final String title;
  final Widget child;
  const _Step({required this.n, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: _sharedCopy(context).e7SharedDetail307(n),
            excludeSemantics: true,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                '$n',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel.inline(title), ...children],
      ),
    );
  }
}

class Cmd extends StatelessWidget {
  final String text;
  const Cmd(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .45)
            : Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.hairline(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  text,
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: AppTheme.codeFontSize,
                  ),
                ),
              ),
            ),
          ),
          // A full-size target: the command is the thing the reader came
          // here to take away, so its copy button is not a 15px afterthought.
          IconButton(
            tooltip: _sharedCopy(context).handoffCopyCommand,
            icon: Icon(AppIcons.copy, color: AppTheme.mutedOf(theme)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_sharedCopy(context).e7SharedCopied),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class Bullet extends StatelessWidget {
  final String text;
  const Bullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

AppLocalizations _sharedCopy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));
