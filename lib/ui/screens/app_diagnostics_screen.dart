import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/product_repository.dart';
import '../../diagnostics/app_diagnostics.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'perf_trace_section.dart';

/// Settings › App diagnostics: the handled errors of this app run, sent to
/// the connected server's own log or copied, and the Performance timings.
///
/// Built from kit parts only (screen-system-1): a [KitScreen] page, the
/// intro and its button block on the gutters, the errors as [KitExpandRow]s
/// on one panel, then [PerfTraceSection]. The result of a send is a
/// [KitNotice] under the buttons, not a snackbar (KIT-34). Clearing asks
/// first with the count (map: app-diagnostics-clear-sheet).
// revamp: redesign (slice-P8.2)
class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key, required this.controller});

  final ConnectionController controller;

  @override
  State<AppDiagnosticsScreen> createState() => _AppDiagnosticsScreenState();
}

/// The last send's outcome, shown under the buttons until the next one.
typedef _Sent = ({bool ok, String message});

class _AppDiagnosticsScreenState extends State<AppDiagnosticsScreen> {
  bool _sending = false;
  _Sent? _sent;

  AppDiagnosticsController get _diagnostics => widget.controller.diagnostics;

  String _serverName(AppLocalizations copy) {
    final name = widget.controller.profile?.name.trim() ?? '';
    return name.isEmpty ? copy.e7SettingsUi9 : name;
  }

  Future<void> _send() async {
    final copy = _screenCopy(context);
    if (_sending || _diagnostics.isEmpty) return;
    final server = _serverName(copy);
    setState(() {
      _sending = true;
      _sent = null;
    });
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
      setState(
        () => _sent = (ok: true, message: copy.appDiagnosticsSentTo(server)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _sent = (
          ok: false,
          message: copy.e7SettingsDiagnosticSendError(
            _diagnostics.sanitize(error.toString(), limit: 300),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _clear() async {
    final copy = _screenCopy(context);
    final count = _diagnostics.count;
    final confirmed = await showKitConfirm(
      context,
      title: copy.appDiagnosticsClearTitle(count),
      body: copy.appDiagnosticsClearBody(count),
      confirmLabel: copy.appDiagnosticsClearConfirm(count),
      icon: AppIconography.delete,
      kind: KitConfirmKind.destructive,
      confirmKey: const ValueKey('clear-app-diagnostics-confirm'),
    );
    if (!confirmed || !mounted) return;
    _diagnostics.clear();
    setState(() => _sent = null);
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
    final tokens = KitTokens.of(context);
    return KitScreen(
      topBar: KitTopBar(title: copy.e7SettingsUi88),
      width: KitScreenWidth.reading,
      body: ListenableBuilder(
        listenable: _diagnostics,
        builder: (context, _) {
          final entries = _diagnostics.entries.reversed.toList();
          final gated = !widget.controller.capabilities.clientDiagnostics;
          final sent = _sent;
          return ListView(
            key: const ValueKey('app-diagnostics'),
            padding: EdgeInsetsDirectional.only(
              top: tokens.space4,
              bottom: KitScreen.endPadding(context),
            ),
            children: [
              Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: KitText(
                        copy.e7SettingsDetailUi7,
                        role: KitTextRole.headline,
                      ),
                    ),
                    SizedBox(height: tokens.space1),
                    KitText(
                      copy.e7SettingsDetailUi8,
                      role: KitTextRole.secondary,
                    ),
                    SizedBox(height: tokens.space4),
                    // One block in the one hierarchy: Send is what this
                    // screen is for and names where it goes, Copy the other
                    // path, Clear the destructive one, confirmed first.
                    // With nothing captured they rest; the state below
                    // says so.
                    KitButton.primary(
                      key: const ValueKey('send-app-diagnostics'),
                      onPressed: entries.isEmpty || _sending || gated
                          ? null
                          : _send,
                      working: _sending,
                      icon: AppIconography.send,
                      label: _sending
                          ? copy.queuedSending
                          : copy.appDiagnosticsSendTo(_serverName(copy)),
                    ),
                    SizedBox(height: tokens.space1),
                    KitText(
                      gated
                          ? copy.e7SettingsDetailUi12
                          : copy.appDiagnosticsSendWhere(_serverName(copy)),
                      key: gated
                          ? const ValueKey('gated-client-diagnostics')
                          : const ValueKey('app-diagnostics-send-where'),
                      role: KitTextRole.secondary,
                    ),
                    if (sent != null) ...[
                      SizedBox(height: tokens.space2),
                      KitNotice(
                        key: const ValueKey('app-diagnostics-sent'),
                        tone: sent.ok
                            ? AppStatusTone.ok
                            : AppStatusTone.failure,
                        icon: sent.ok
                            ? AppIconography.checkCircle
                            : AppIconography.error,
                        message: sent.message,
                      ),
                    ],
                    SizedBox(height: tokens.space2),
                    KitButton.secondary(
                      key: const ValueKey('copy-app-diagnostics'),
                      onPressed: entries.isEmpty
                          ? null
                          : () => KitCopy.copy(
                              context,
                              _diagnostics.reportText(),
                              announcement: copy.e7SettingsDetailUi0,
                            ),
                      icon: AppIconography.copy,
                      label: copy.appDiagnosticsCopyErrors,
                    ),
                    SizedBox(height: tokens.space1),
                    KitInset(
                      child: KitButton.tertiary(
                        key: const ValueKey('clear-app-diagnostics'),
                        destructive: true,
                        onPressed: entries.isEmpty
                            ? null
                            : () => unawaited(_clear()),
                        icon: AppIconography.delete,
                        label: copy.appDiagnosticsClearErrors,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space4),
              if (entries.isEmpty)
                KitStateView(
                  size: KitStateSize.inline,
                  icon: AppIconography.privacy,
                  title: copy.e7SettingsDetailUi13,
                  body: copy.appDiagnosticsEmptyBody,
                  liveRegion: false,
                )
              else
                KitRowGroup(
                  label: copy.e7SettingsDiagnosticTotal(entries.length),
                  children: [
                    for (final entry in entries)
                      KitExpandRow(
                        key: ValueKey('diagnostic-entry-${entry.id}'),
                        leading: KitRow.icon(context, AppIconography.error),
                        title: entry.message,
                        supporting: TextSpan(
                          text: [
                            KitBidi.ltr(entry.source),
                            _time(entry.timestamp),
                            if (entry.occurrences > 1)
                              copy.e7SettingsDiagnosticOccurrences(
                                entry.occurrences,
                              ),
                          ].join(' · '),
                        ),
                        supportingMaxLines: 2,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: tokens.gutter,
                              end: tokens.gutter,
                              bottom: tokens.space3,
                            ),
                            child: KitText.mono(
                              [
                                entry.message,
                                if (entry.stack.isNotEmpty) entry.stack,
                              ].join('\n\n'),
                              selectable: true,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              SizedBox(height: tokens.sectionGap),
              const PerfTraceSection(),
            ],
          );
        },
      ),
    );
  }
}

AppLocalizations _screenCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
