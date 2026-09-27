part of '../chat_screen.dart';

/// "Reuse a prompt": text from this conversation and recent sends, newest
/// first. Tapping a row adds its text to the draft; nothing is resent and no
/// attachment is copied. The host opens it as a sheet and appends the
/// chosen text.
class _PromptHistorySheet extends StatefulWidget {
  const _PromptHistorySheet({required this.prompts});
  final List<String> prompts;

  @override
  State<_PromptHistorySheet> createState() => _PromptHistorySheetState();
}

class _PromptHistorySheetState extends State<_PromptHistorySheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final text in widget.prompts)
        if (text.toLowerCase().contains(query)) text,
    ];
    return KitSheet(
      key: const Key('prompt-history-sheet'),
      // The host's modal draws the handle.
      handle: false,
      title: l10n.composerReuseTitle,
      subtitle: l10n.promptHistoryIntro,
      icon: AppIconography.history,
      onClose: () => Navigator.pop(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitSearchField(
            controller: _search,
            label: l10n.composerReuseSearch,
            fieldKey: const Key('prompt-history-search'),
            resultCount: query.isEmpty ? null : matches.length,
            onChanged: (value) => setState(() => _query = value),
          ),
          if (matches.isEmpty && query.isNotEmpty)
            KitSearchNoMatch(query: _query.trim(), onClear: _clear)
          else if (matches.isEmpty)
            KitStateView(
              size: KitStateSize.inline,
              icon: AppIconography.history,
              title: l10n.composerReuseEmpty,
            )
          else
            KitRowGroup(
              leadingIcons: false,
              children: [
                for (var index = 0; index < matches.length; index++)
                  KitRow(
                    key: ValueKey('reuse-prompt-$index'),
                    title: matches[index],
                    titleMaxLines: 3,
                    trailing: const KitRowIcon(AppIconography.add),
                    onTap: () => Navigator.pop(context, matches[index]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
