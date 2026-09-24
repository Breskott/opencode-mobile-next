import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import 'package:flutter/services.dart';

import '../../api/product_repository.dart';
import '../../diagnostics/app_diagnostics.dart';
import '../../state/connection.dart';
import '../kit/kit.dart';
import '../widgets/confirm_sheet.dart';
import '../app_theme.dart';
import 'perf_trace_section.dart';

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
    final copy = _screenCopy(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(copy.e7SettingsUi88)),
      body: ListenableBuilder(
        listenable: _diagnostics,
        builder: (context, _) {
          final entries = _diagnostics.entries.reversed.toList();
          final gated = !widget.controller.capabilities.clientDiagnostics;
          return KitScreen(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          copy.e7SettingsDetailUi7,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          copy.e7SettingsDetailUi8,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedOf(theme),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // One block in the one hierarchy (§2): Send is what
                        // this screen is for, Copy the other path, Clear the
                        // destructive one, confirmed first. With nothing
                        // captured they rest; the empty state below says so.
                        KitButton.primary(
                          key: const ValueKey('send-app-diagnostics'),
                          // §7 row 24: the control stays, visibly dead,
                          // with the explainer directly beneath it.
                          onPressed: entries.isEmpty || _sending || gated
                              ? null
                              : _send,
                          working: _sending,
                          icon: AppIconography.send,
                          label: _sending
                              ? copy.queuedSending
                              : copy.e7SettingsDetailUi10,
                        ),
                        if (gated)
                          Padding(
                            key: const ValueKey('gated-client-diagnostics'),
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              copy.e7SettingsDetailUi12,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.mutedOf(theme),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        KitButton.secondary(
                          key: const ValueKey('copy-app-diagnostics'),
                          onPressed: entries.isEmpty ? null : _copy,
                          icon: AppIcons.copy,
                          label: copy.fileCopy,
                        ),
                        const SizedBox(height: 4),
                        KitInset(
                          child: KitButton.tertiary(
                            key: const ValueKey('clear-app-diagnostics'),
                            destructive: true,
                            onPressed: entries.isEmpty ? null : _clear,
                            icon: AppIconography.delete,
                            label: copy.e7SettingsDetailUi5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Not SliverFillRemaining: that would push the performance
                // section below a screen of empty space.
                if (entries.isEmpty) ...[
                  SliverToBoxAdapter(
                    child: KitStateView(
                      size: KitStateSize.inline,
                      icon: AppIconography.privacy,
                      title: copy.e7SettingsDetailUi13,
                      body: copy.e7SettingsDetailUi14,
                      liveRegion: false,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ] else ...[
                  SliverToBoxAdapter(
                    child: SectionLabel(
                      copy.e7SettingsDiagnosticTotal(entries.length),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ExpansionTile(
                        key: ValueKey('diagnostic-entry-${entry.id}'),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: KitRow.icon(
                          context,
                          AppIconography.error,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          entry.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '\u2066${entry.source} · ${_time(entry.timestamp)}\u2069'
                          '${entry.occurrences > 1 ? ' · ${copy.e7SettingsDiagnosticOccurrences(entry.occurrences)}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.mutedOf(theme),
                          ),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                const SliverToBoxAdapter(child: Divider(height: 1)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      KitScreen.endPadding(context),
                    ),
                    child: const PerfTraceSection(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

AppLocalizations _screenCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
