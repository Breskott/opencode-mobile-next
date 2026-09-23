import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../diagnostics/perf_trace.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../widgets/product_states.dart';

/// The "Performance" part of App diagnostics: where time went in this run
/// of the app, from [PerfTrace]. Steps grouped by name (slowest first), the
/// latest steps, and a plain-text report to copy.
class PerfTraceSection extends StatelessWidget {
  const PerfTraceSection({super.key, this.slowest = 12, this.recent = 50});

  /// How many grouped steps and how many recent ones to show.
  final int slowest;
  final int recent;

  Future<void> _copy(BuildContext context) async {
    final copied = _copy10n(context).perfTraceCopied;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: PerfTrace.reportText()));
    messenger?.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy10n(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const mono = TextStyle(
      fontFamily: AppTheme.monoFamily,
      fontSize: AppTheme.codeFontSize,
    );
    return ListenableBuilder(
      listenable: PerfTrace.changes,
      builder: (context, _) {
        final stats = PerfTrace.stats().take(slowest).toList();
        final latest = PerfTrace.recent(recent);
        final empty = latest.isEmpty;
        return Column(
          key: const ValueKey('perf-trace-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(copy.perfTraceTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              copy.perfTraceBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('perf-trace-copy'),
                  onPressed: empty ? null : () => _copy(context),
                  icon: const Icon(AppIcons.copy),
                  label: Text(copy.perfTraceCopy),
                ),
                TextButton.icon(
                  key: const ValueKey('perf-trace-clear'),
                  onPressed: empty ? null : PerfTrace.clear,
                  icon: const Icon(AppIconography.delete),
                  label: Text(copy.perfTraceClear),
                ),
              ],
            ),
            if (empty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  copy.perfTraceEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              )
            else ...[
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionLabel.inline(copy.perfTraceSlowest),
                for (final stat in stats)
                  _Row(
                    key: ValueKey('perf-trace-stat-${stat.name}'),
                    title: stat.name,
                    detail: [
                      copy.perfTraceStatLine(
                        stat.count,
                        formatMs(stat.p50Ms),
                        formatMs(stat.p95Ms),
                        formatMs(stat.maxMs),
                      ),
                      if (stat.errors > 0) copy.perfTraceFailed(stat.errors),
                    ].join(' · '),
                    trailing: formatMs(stat.p95Ms),
                    failed: stat.errors > 0,
                    mono: mono,
                  ),
              ],
              const SizedBox(height: 18),
              SectionLabel.inline(copy.perfTraceRecent),
              for (final span in latest)
                _Row(
                  key: ValueKey('perf-trace-span-${span.id}'),
                  title: span.name,
                  detail: [
                    for (final entry in span.attrs.entries)
                      '${entry.key}=${entry.value}',
                    if (span.parent != null) copy.perfTraceWithin(span.parent!),
                  ].join(' · '),
                  trailing: span.isMark
                      ? copy.perfTraceAt(formatMs(span.startMicros / 1000))
                      : formatMs(span.durationMs),
                  failed: span.failed,
                  mono: mono,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One line: a step's name and details, its time at the end. Names and
/// numbers are code-like, so they stay left-to-right in Arabic too.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    required this.detail,
    required this.trailing,
    required this.failed,
    required this.mono,
  });

  final String title;
  final String detail;
  final String trailing;
  final bool failed;
  final TextStyle mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = failed ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.ltr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mono.copyWith(color: color),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: mono.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

AppLocalizations _copy10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
