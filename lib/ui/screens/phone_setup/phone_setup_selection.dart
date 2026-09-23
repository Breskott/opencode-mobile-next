import 'dart:math' as math;

import '../../../builtin/setup/setup_contract.dart';
import '../../../l10n/app_localizations.dart';

/// Screen-side arithmetic over the component registry: what a selection
/// really installs and how long and how big that is. Every number screen A
/// and the Customize sheet show comes from here, so a component added to the
/// registry changes the promise without touching a screen.

/// What "Set up" installs when the person changes nothing: every required
/// component plus the optional ones that are on by default.
Set<String> defaultSetupSelection(List<SetupComponent> registry) => {
  for (final component in registry)
    if (component.required || component.defaultOn) component.id,
};

/// [chosen] plus every required component and everything they depend on, in
/// registry (dependency) order. This mirrors what the engine will run, so the
/// totals never promise less than what actually gets installed.
List<SetupComponent> expandSetupSelection(
  List<SetupComponent> registry,
  Set<String> chosen, {
  bool includeRequired = true,
}) {
  final byId = {for (final component in registry) component.id: component};
  final wanted = <String>{};
  void add(String id) {
    if (!wanted.add(id)) return;
    for (final dependency in byId[id]?.dependsOn ?? const <String>[]) {
      add(dependency);
    }
  }

  for (final component in registry) {
    if ((includeRequired && component.required) ||
        chosen.contains(component.id)) {
      add(component.id);
    }
  }
  return [
    for (final component in registry)
      if (wanted.contains(component.id)) component,
  ];
}

/// Seconds and bytes of [components]. Unknown sizes count as zero rather
/// than being guessed.
({int seconds, int bytes}) setupTotals(Iterable<SetupComponent> components) {
  var seconds = 0;
  var bytes = 0;
  for (final component in components) {
    seconds += component.estimatedSeconds;
    bytes += component.downloadBytes ?? 0;
  }
  return (seconds: seconds, bytes: bytes);
}

/// "About 4 minutes": rounded, never below one minute, because a promise of
/// "about 0 minutes" is not a promise.
String setupDurationText(AppLocalizations l10n, int seconds) =>
    l10n.phoneSetupStartAboutMinutes(math.max(1, (seconds / 60).round()));

/// "165 MB" or "1.2 GB", in decimal units like the store listing and the
/// download managers people compare against.
String setupSizeText(AppLocalizations l10n, int bytes) {
  final megabytes = bytes / 1000000;
  if (megabytes >= 1000) {
    final gigabytes = megabytes / 1000;
    return l10n.phoneSetupStartGigabytes(gigabytes.toStringAsFixed(1));
  }
  return l10n.phoneSetupStartMegabytes(
    math.max(1, megabytes.round()).toString(),
  );
}

/// "Git, Python and Node.js" with the locale's own separator and "and".
String joinSetupNames(AppLocalizations l10n, List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.single;
  final head = names
      .sublist(0, names.length - 1)
      .join(l10n.phoneSetupStartListSeparator);
  return l10n.phoneSetupStartListPair(head, names.last);
}

/// The tools a selection brings along, for "Includes …". The Linux base is
/// plumbing the person never meets, and OpenCode is the agent the whole
/// screen is about, so neither is listed as something "included".
List<String> includedToolNames(Iterable<SetupComponent> components) => [
  for (final component in components)
    if (!component.native && component.id != 'opencode') component.shortTitle,
];
