part of '../chat_screen.dart';

class _TodosSheet extends StatefulWidget {
  final ConnectionController conn;
  final String sessionID;
  const _TodosSheet({required this.conn, required this.sessionID});

  @override
  State<_TodosSheet> createState() => _TodosSheetState();
}

class _TodosSheetState extends State<_TodosSheet> {
  List<Todo>? _todos;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    // Runs from initState, so inherited lookups are not yet allowed.
    final strings = earlyAppLocalizations(context);
    if (_error != null) setState(() => _error = null);
    try {
      final api = await widget.conn.prepareActionTransport();
      if (api == null) {
        throw ProductException(strings.chatUiOpenCodeIsReconnectingTryAgain);
      }
      final t = await api.todos(widget.sessionID);
      if (mounted) setState(() => _todos = t);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _error != null
            ? SizedBox(
                height: 260,
                child: ProductErrorState(
                  message: productErrorText(_error!),
                  onRetry: _fetch,
                ),
              )
            : _todos == null
            ? const SizedBox(height: 240, child: LoadingList(rows: 4))
            : _todos!.isEmpty
            ? ProductInlineEmpty(
                icon: AppIconography.checklist,
                title: _chatL10n(context).chatUiNoTodosInThisSession,
                message: _chatL10n(context).chatUiWhenTheAssistantPlansWorkAsA,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel.inline(_chatL10n(context).chatUiTodoList),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final t in _todos!)
                          CheckboxListTile(
                            dense: true,
                            value: t.done,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              t.content,
                              style: TextStyle(
                                decoration: t.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: t.done ? AppTheme.mutedOf(theme) : null,
                              ),
                            ),
                            subtitle:
                                t.status == 'pending' && t.priority == null
                                ? null
                                : Text(
                                    [
                                      if (t.status != 'pending')
                                        t.status.replaceAll('_', ' '),
                                      if (t.priority != null)
                                        _chatL10n(
                                          context,
                                        ).chatUiPriorityLabel(t.priority ?? ''),
                                    ].join(' · '),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.mutedOf(theme),
                                    ),
                                  ),
                            onChanged: null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
