/// Shared pieces of the AI Team plugin's enablement UI (TEAM-106): the
/// manual-add sheet (address + city, probe on submit), the verdict copy for
/// every [ProbeVerdict], the host guide sheet and the turn-off confirmation.
/// Used by Settings › Plugins, the discovery card and the server editor so
/// the three entry points share one form and one set of words.
///
/// Transport rule (04-plugin-architecture §7, revised): `http://` is allowed
/// to loopback and tailnet addresses and refused elsewhere; the copy never
/// mentions HTTPS or `tailscale serve`.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../orchestration/adapters/gascity/gascity_probe.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
import 'confirm_sheet.dart';

export '../../orchestration/adapters/gascity/gascity_probe.dart'
    show
        ProbeCityNotRunning,
        ProbeFound,
        ProbeNotGasCity,
        ProbePlainHttpRefused,
        ProbeUnreachable,
        ProbeVerdict,
        isOrchestrationUrlAllowed,
        isTailnetHost;

/// Probes one address; never throws.
typedef TeamHostProbe =
    Future<ProbeVerdict> Function(String url, {String? city});

/// The real probe: [GasCityProbe] over the network.
Future<ProbeVerdict> defaultTeamHostProbe(String url, {String? city}) =>
    const GasCityProbe().probe(url, city: city);

/// The probe every AI Team form uses. Tests replace it with a fake so no
/// widget opens a socket; production leaves it at [defaultTeamHostProbe].
TeamHostProbe teamHostProbe = defaultTeamHostProbe;

/// The port a Gas City supervisor listens on by default.
const teamHostDefaultPort = 8372;

/// The port the host front (tool/host/cp_front) listens on by default.
const teamHostFrontPort = 8373;

/// The address the manual-add form prefills for a server profile: the
/// profile's own host on port [teamHostDefaultPort] over plain `http`, or
/// null when that would be refused (a public host) or the server URL has
/// no host. Discovery itself tries [teamDiscoveryUrlsFor].
String? teamDiscoveryUrlFor(String baseUrl) =>
    _teamHostUrl(baseUrl, teamHostDefaultPort);

/// The addresses discovery probes for a server profile, in order: the
/// profile's own host on the front port [teamHostFrontPort] first (a
/// front gives controls), then the bare supervisor port
/// [teamHostDefaultPort]. Empty when plain `http` to that host would be
/// refused or the server URL has no host.
List<String> teamDiscoveryUrlsFor(String baseUrl) => [
  ?_teamHostUrl(baseUrl, teamHostFrontPort),
  ?_teamHostUrl(baseUrl, teamHostDefaultPort),
];

String? _teamHostUrl(String baseUrl, int port) {
  final Uri parsed;
  try {
    parsed = Uri.parse(baseUrl.trim());
  } on FormatException {
    return null;
  }
  if (!parsed.hasAuthority || parsed.host.isEmpty) return null;
  final host = parsed.host.contains(':') ? '[${parsed.host}]' : parsed.host;
  final url = Uri.parse('http://$host:$port');
  return isOrchestrationUrlAllowed(url) ? url.toString() : null;
}

/// The plugin config a found verdict turns into for [url] / [city].
/// [hostKind] is the person's choice for the disclaimer (TEAM-206); it is
/// kept only when it belongs to the mode the host reports, so a phone host
/// never carries a laptop disclaimer.
OrchestrationConfig teamConfigFromVerdict(
  ProbeFound found, {
  required String url,
  required String city,
  OrchestrationHostKind? hostKind,
  DateTime? now,
}) => OrchestrationConfig(
  provider: OrchestrationProvider.gascity,
  url: url,
  city: city.isNotEmpty ? city : (found.city ?? ''),
  hostMode: found.host.hostMode,
  hostKind: hostKind != null && hostKind.mode == found.host.hostMode
      ? hostKind
      : null,
  front: !found.readOnly,
  enabledAt: (now ?? DateTime.now()).toUtc(),
);

/// The kinds the form offers; the phone kind comes from the host, never
/// from a choice.
const teamHostKindChoices = [
  OrchestrationHostKind.pc,
  OrchestrationHostKind.laptop,
  OrchestrationHostKind.wsl,
];

/// The form label of a choosable host kind.
String teamHostKindLabel(AppLocalizations l10n, OrchestrationHostKind kind) =>
    switch (kind) {
      OrchestrationHostKind.pc => l10n.teamUiHostKindDesktop,
      OrchestrationHostKind.laptop => l10n.teamUiHostKindLaptop,
      OrchestrationHostKind.wsl => l10n.teamUiHostKindWsl,
      OrchestrationHostKind.phone => l10n.teamUiHostModePhone,
    };

/// The product sentence for a verdict (03-onboarding §5), null for
/// [ProbeFound].
String? teamVerdictCopy(AppLocalizations l10n, ProbeVerdict verdict) =>
    switch (verdict) {
      ProbeFound() => null,
      ProbeNotGasCity() => l10n.teamUiVerdictNotGasCity,
      ProbeCityNotRunning() => l10n.teamUiVerdictCityNotRunning,
      ProbePlainHttpRefused() => l10n.teamUiTailnetRequired,
      ProbeUnreachable() => l10n.teamUiVerdictUnreachable,
    };

/// The verdict chip for a found host: version, city and whether the phone
/// can answer.
String teamFoundCopy(AppLocalizations l10n, ProbeFound found) {
  final version = found.version ?? l10n.teamUiVersionUnknown;
  final city = found.city ?? '';
  return found.readOnly
      ? l10n.teamUiVerdictFound(version, city)
      : l10n.teamUiVerdictFoundControls(version, city);
}

/// Opens the manual-add sheet. Returns the config to save once the probe
/// found a host, null when the person left without one.
Future<OrchestrationConfig?> showTeamHostSheet(
  BuildContext context, {
  String initialUrl = '',
  String initialCity = '',
  OrchestrationHostKind? initialHostKind,
  TeamHostProbe? probe,
}) => showModalBottomSheet<OrchestrationConfig>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: TeamHostForm(
      initialUrl: initialUrl,
      initialCity: initialCity,
      initialHostKind: initialHostKind,
      probe: probe ?? teamHostProbe,
      onFound: (config) => Navigator.of(context).pop(config),
    ),
  ),
);

/// Address + city + kind of computer, one submit that probes and reports
/// the verdict.
class TeamHostForm extends StatefulWidget {
  const TeamHostForm({
    super.key,
    required this.probe,
    required this.onFound,
    this.initialUrl = '',
    this.initialCity = '',
    this.initialHostKind,
  });

  final TeamHostProbe probe;
  final ValueChanged<OrchestrationConfig> onFound;
  final String initialUrl;
  final String initialCity;

  /// The kind preselected in the form; null (or a kind the form does not
  /// offer, such as the phone) starts at [OrchestrationHostKind.pc].
  final OrchestrationHostKind? initialHostKind;

  @override
  State<TeamHostForm> createState() => _TeamHostFormState();
}

class _TeamHostFormState extends State<TeamHostForm> {
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.initialCity,
  );
  late OrchestrationHostKind _kind =
      teamHostKindChoices.contains(widget.initialHostKind)
      ? widget.initialHostKind!
      : OrchestrationHostKind.pc;
  bool _testing = false;
  String? _failure;
  bool _failureIsUnavailable = false;

  /// The raw platform error behind an unreachable verdict, shown small
  /// under the sentence so a real cause ("Connection refused", a cleartext
  /// block, a DNS miss) is visible instead of guessed.
  String? _failureDetail;

  @override
  void dispose() {
    _url.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_testing) return;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final url = _url.text.trim();
    final city = _city.text.trim();
    if (url.isEmpty) {
      setState(() {
        _failure = l10n.teamUiAddressRequired;
        _failureIsUnavailable = false;
      });
      return;
    }
    // The transport rule is decided before any request, with the tailnet
    // wording, so a public address never waits for a timeout.
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !parsed.hasAuthority ||
        (parsed.scheme == 'http' && !isOrchestrationUrlAllowed(parsed))) {
      setState(() {
        _failure = parsed != null && parsed.scheme == 'http'
            ? l10n.teamUiTailnetRequired
            : l10n.teamUiVerdictUnreachable;
        _failureIsUnavailable = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _failure = null;
      _failureDetail = null;
    });
    final verdict = await widget.probe(url, city: city.isEmpty ? null : city);
    if (!mounted) return;
    if (verdict is ProbeFound) {
      setState(() => _testing = false);
      widget.onFound(
        teamConfigFromVerdict(verdict, url: url, city: city, hostKind: _kind),
      );
      return;
    }
    setState(() {
      _testing = false;
      _failure = teamVerdictCopy(l10n, verdict);
      _failureIsUnavailable = verdict is ProbeNotGasCity;
      _failureDetail = switch (verdict) {
        ProbeUnreachable(:final error) => _errorDetail(error),
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('team-host-form'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamUiAddTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('team-host-url'),
            controller: _url,
            enabled: !_testing,
            autofocus: widget.initialUrl.isEmpty,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.teamUiAddAddressLabel,
              hintText: l10n.teamUiAddAddressHint,
              hintTextDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('team-host-city'),
            controller: _city,
            enabled: !_testing,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: l10n.teamUiAddCityLabel),
          ),
          const SizedBox(height: 16),
          // The kind only picks the disclaimer line (03-onboarding §4);
          // chips wrap, so three labels at large text stack instead of
          // squeezing.
          Text(
            l10n.teamUiHostKindLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('team-host-kind'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in teamHostKindChoices)
                ChoiceChip(
                  key: ValueKey('team-host-kind-${kind.name}'),
                  label: Text(teamHostKindLabel(l10n, kind)),
                  selected: _kind == kind,
                  onSelected: _testing
                      ? null
                      : (selected) {
                          if (selected) setState(() => _kind = kind);
                        },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.teamUiHostKindHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
              height: 1.35,
            ),
          ),
          if (_failure != null) ...[
            const SizedBox(height: 12),
            _VerdictNote(
              key: const ValueKey('team-host-verdict'),
              text: _failure!,
              trailingAction: _failureIsUnavailable
                  ? TextButton(
                      key: const ValueKey('team-host-verdict-how'),
                      onPressed: () => showTeamHostGuideSheet(context),
                      child: Text(l10n.teamUiHow),
                    )
                  : null,
            ),
            if (_failureDetail != null) ...[
              const SizedBox(height: 6),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  _failureDetail!,
                  key: const ValueKey('team-host-verdict-detail'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('team-host-submit'),
            onPressed: _testing ? null : _submit,
            child: Text(
              _testing ? l10n.teamUiAddTesting : l10n.teamUiAddSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

/// A verdict line in the amber "blocked" tone (02a: amber for blocked, red
/// only for failed runs), never colour-only: it carries a glyph and text.
class _VerdictNote extends StatelessWidget {
  const _VerdictNote({super.key, required this.text, this.trailingAction});

  final String text;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppTheme.statusColor(theme, AppStatusTone.attention);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIconography.warning, size: 18, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
          if (trailingAction != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: trailingAction,
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// The four host steps of docs/ai-team-host.md, as a sheet; the app has no
/// bundled markdown viewer for repository docs.
Future<void> showTeamHostGuideSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final steps = [
      l10n.teamUiHostGuideStep1,
      l10n.teamUiHostGuideStep2,
      l10n.teamUiHostGuideStep3,
      l10n.teamUiHostGuideStep4,
    ];
    return SingleChildScrollView(
      key: const ValueKey('team-host-guide'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamUiHostGuideTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            l10n.teamUiHostGuideIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedOf(theme),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      _stepNumber(i),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            l10n.teamUiHostGuideDocs,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  },
);

/// "1." … for the guide steps; digits stay Western in every locale, as the
/// commands beside them do.
String _stepNumber(int index) => '${index + 1}.';

/// The turn-off confirmation of 02-ux §1.3. True when the person confirmed.
Future<bool> showTeamTurnOffSheet(BuildContext context, String serverName) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return showConfirmSheet(
    context,
    title: l10n.teamUiTurnOffTitle(serverName),
    message: l10n.teamUiTurnOffBody,
    confirmLabel: l10n.teamUiTurnOff,
    cancelLabel: l10n.teamUiKeep,
    icon: AppIconography.unlink,
    destructive: true,
    sheetKey: const ValueKey('team-turn-off-sheet'),
    confirmKey: const ValueKey('team-turn-off-confirm'),
  );
}

/// One line of the platform's own words for [error], trimmed: the Dio
/// wrapper text is dropped in favour of the underlying exception when there
/// is one, and long messages are cut at 240 characters.
String _errorDetail(Object error) {
  var text = error.toString();
  final inner = RegExp(
    r'(SocketException|HandshakeException|HttpException|TimeoutException|FormatException|OS Error)[^\n]*',
  ).firstMatch(text);
  if (inner != null) text = inner.group(0)!;
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 240 ? '${text.substring(0, 240)}…' : text;
}
