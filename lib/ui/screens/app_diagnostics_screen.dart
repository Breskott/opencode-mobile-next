import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import 'package:flutter/services.dart';

import '../../api/product_repository.dart';
import '../../diagnostics/app_diagnostics.dart';
import '../../state/connection.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/product_states.dart';
import '../app_theme.dart';

class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key, required this.controller});

  final ConnectionController controller;

  @override
  State<AppDiagnosticsScreen> createState() => _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState extends State<AppDiagnosticsScreen> {
  bool _sending = false;

  AppDiagnosticsController get _diagnostics => widget.controller.diagnostics;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _diagnostics.reportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_screenCopy(context).e7SettingsDetailUi0)),
    );
  }

  Future<void> _send() async {
    final copy = _screenCopy(context);
    if (_sending || _diagnostics.isEmpty) return;
    setState(() => _sending = true);
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (repository == null) {
        throw ProductException(copy.e7SettingsUi19);
      }
      final count = _diagnostics.count;
      await repository.writeClientLog(
        message: 'OpenCode Mobile diagnostics ($count handled errors)',
        extra: _diagnostics.reportJson(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.e7SettingsDetailUi2)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy.e7SettingsDiagnosticSendError(
              _diagnostics.sanitize(error.toString(), limit: 300),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showConfirmSheet(
      context,
      title: _screenCopy(context).e7SettingsDetailUi3,
      message: _screenCopy(context).e7SettingsDetailUi4,
      confirmLabel: _screenCopy(context).e7SettingsDetailUi5,
      icon: AppIconography.delete,
      destructive: true,
    );
    if (confirmed) _diagnostics.clear();
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_screenCopy(context).e7SettingsUi88)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _diagnostics,
          builder: (context, _) {
            final entries = _diagnostics.entries.reversed.toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _screenCopy(context).e7SettingsDetailUi7,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _screenCopy(context).e7SettingsDetailUi8,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('send-app-diagnostics'),
                              // §7 row 24: the control stays, visibly dead,
                              // with the explainer directly beneath it.
                              onPressed:
                                  entries.isEmpty ||
                                      _sending ||
                                      !widget
                                          .controller
                                          .capabilities
                                          .clientDiagnostics
                                  ? null
                                  : _send,
                              icon: _sending
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(AppIconography.send),
                              label: Text(
                                _sending
                                    ? _screenCopy(context).queuedSending
                                    : _screenCopy(context).e7SettingsDetailUi10,
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('copy-app-diagnostics'),
                              onPressed: entries.isEmpty ? null : _copy,
                              icon: const Icon(AppIcons.copy),
                              label: Text(_screenCopy(context).fileCopy),
                            ),
                            TextButton.icon(
                              key: const ValueKey('clear-app-diagnostics'),
                              onPressed: entries.isEmpty ? null : _clear,
                              icon: const Icon(AppIconography.delete),
                              label: Text(
                                _screenCopy(context).e7SettingsDetailUi5,
                              ),
                            ),
                          ],
                        ),
                        if (!widget.controller.capabilities.clientDiagnostics)
                          Padding(
                            key: const ValueKey('gated-client-diagnostics'),
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _screenCopy(context).e7SettingsDetailUi12,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIconography.privacy, size: 38),
                            SizedBox(height: 14),
                            Text(_screenCopy(context).e7SettingsDetailUi13),
                            SizedBox(height: 6),
                            Text(
                              _screenCopy(context).e7SettingsDetailUi14,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: SectionLabel(
                      _screenCopy(
                        context,
                      ).e7SettingsDiagnosticTotal(entries.length),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ExpansionTile(
                        key: ValueKey('diagnostic-entry-${entry.id}'),
                        leading: const Icon(AppIconography.error),
                        title: Text(
                          entry.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '\u2066${entry.source} · ${_time(entry.timestamp)}\u2069'
                          '${entry.occurrences > 1 ? ' · ${_screenCopy(context).e7SettingsDiagnosticOccurrences(entry.occurrences)}' : ''}',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectionArea(
                            child: Text(
                              textDirection: TextDirection.ltr,
                              [
                                entry.message,
                                if (entry.stack.isNotEmpty) entry.stack,
                              ].join('\n\n'),
                              style: const TextStyle(
                                fontFamily: AppTheme.monoFamily,
                                fontSize: AppTheme.codeFontSize,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

AppLocalizations _screenCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
