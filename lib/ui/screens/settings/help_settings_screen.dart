part of '../settings_screen.dart';

/// Settings › Help: the rarer reference and support rows the hub used to
/// list one by one (owner rule R4, canvas Settings.png): the setup guide,
/// the offline demo, what this server offers, keyboard shortcuts, the
/// one-time tips and the voice notices (app diagnostics became Report a
/// problem, the hub's own row). Each row is its
/// search entry, so search and this page cannot disagree; a row whose entry
/// is gated out is absent.
class SettingsHelpScreen extends StatefulWidget {
  const SettingsHelpScreen({super.key, required this.controller});

  final ConnectionController controller;

  @override
  State<SettingsHelpScreen> createState() => _SettingsHelpScreenState();
}

class _SettingsHelpScreenState extends State<SettingsHelpScreen> {
  /// Show tips again ran: the row says so in place of a snackbar (KIT-34).
  bool _tipsReset = false;

  /// Puts every one-time tip back. The row itself then says so: there is
  /// no way to take the reset back, so no Undo bar (KIT-34).
  Future<void> _showTipsAgain() async {
    await widget.controller.nudges.reset();
    if (mounted) setState(() => _tipsReset = true);
  }

  Future<void> _open(SearchEntry entry, SearchScope scope) async {
    await entry.open(context, scope);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final copy = _settingsCopy(context);
    final tokens = KitTokens.of(context);
    final scope = SearchScope.of(context, controller);
    final entries = {
      for (final entry in searchIndex(copy, scope)) entry.id: entry,
    };
    Widget? row(String id, {String? subtitle}) {
      final entry = entries[id];
      if (entry == null) return null;
      return _CategoryRow(
        rowKey: entry.id,
        icon: entry.icon,
        title: entry.title,
        subtitle: subtitle,
        onTap: () => _open(entry, scope),
      );
    }

    final rows = [
      row('settings-setup-guide', subtitle: copy.e7SettingsUi91),
      // The first-run welcome's demo, still one tap away once a server is
      // saved.
      row('settings-try-demo', subtitle: copy.demoScreenSimulated),
      // The explanation for every row the connected server hides.
      row(
        'settings-server-capabilities',
        subtitle: copy.capabilityScreenSubtitle,
      ),
      row('library-keyboard-shortcuts'),
      // Each one-time tip fires once, at its moment. This puts them all
      // back, for a person who dismissed one too fast (plan 5.8).
      if (entries.containsKey('settings-show-tips-again'))
        _CategoryRow(
          rowKey: 'settings-show-tips-again',
          icon: AppIconography.idea,
          title: copy.discoverShowTipsAgain,
          subtitle: _tipsReset
              ? copy.discoverShowTipsDone
              : copy.discoverShowTipsSubtitle,
          chevron: false,
          onTap: _showTipsAgain,
        ),
      // The voice notices cover models this build can neither download
      // nor run off Android.
      row('settings-voice-notices', subtitle: copy.e7SettingsUi95),
    ].nonNulls.toList();
    return KitScreen(
      topBar: KitTopBar(title: copy.settingsHubHelpRow),
      width: KitScreenWidth.reading,
      body: ListView(
        key: const ValueKey('settings-help-list'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [KitRowGroup(children: rows)],
      ),
    );
  }
}
