import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/app_exit.dart';
import '../../platform/keep_alive_advice.dart';
import '../../state/consent_owners.dart';
import '../../state/connection.dart';
import '../../state/in_flow_consent.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';

/// The question for one phone-server consent, the same words wherever it is
/// asked: at the server's first start and again from its Settings row.
({String title, String body, String allow, IconData icon}) phoneConsentWords(
  AppLocalizations l10n,
  InFlowConsentKind kind, {
  String maker = '',
}) => switch (kind) {
  InFlowConsentKind.batteryExemption => (
    title: l10n.consentBatteryTitle,
    body: l10n.consentBatteryBody,
    allow: l10n.consentBatteryAllow,
    icon: AppIconography.batteryWarning,
  ),
  InFlowConsentKind.makerAutoStart => (
    title: l10n.consentMakerTitle,
    body: maker.trim().isEmpty
        ? l10n.consentMakerBodyUnnamed
        : l10n.consentMakerBody(KitBidi.auto(maker.trim())),
    allow: l10n.consentMakerAllow,
    icon: AppIconography.sync,
  ),
  InFlowConsentKind.needsYouNotifications => (
    title: l10n.firstRunNotifyTitle,
    body: l10n.firstRunNotifyBody,
    allow: l10n.firstRunNotifyAccept,
    icon: AppIconography.inbox,
  ),
};

/// Runs the platform step an accepted phone consent stands for: Android's
/// battery exemption prompt, or the maker's auto-start screen. Opening a
/// screen is not proof of a grant; the Settings row says to check there.
Future<void> runPhoneConsent(
  InFlowConsentKind kind, {
  required ConnectionController connection,
  required AppLifecycleBridge bridge,
}) async {
  switch (kind) {
    case InFlowConsentKind.batteryExemption:
      await connection.backgroundLive.requestBatteryOptimizationExemption();
    case InFlowConsentKind.makerAutoStart:
      await bridge.openKeepAliveSetting(KeepAliveSetting.autostart);
    case InFlowConsentKind.needsYouNotifications:
      break;
  }
}

/// Asks, once per server and at the moment it matters (P6.7), what keeps
/// the server on this phone alive: Android's battery exemption first, then
/// the maker's auto-start where the phone has one. Call it right after the
/// phone server [profileId] started for the person (never on connect or app
/// start); on every later start it asks nothing.
///
/// The questions are claimed in storage before the first one shows, so a
/// second start (another screen, a restart of the app) never asks again; one
/// left unanswered stays "Not answered" on What runs by itself, where it can
/// be answered later. Each answer is saved before its platform step runs,
/// and a refused save stops the questions: nothing runs without a saved yes.
Future<void> askPhoneServerConsents(
  BuildContext context, {
  required ConnectionController connection,
  required AppLifecycleBridge bridge,
  required String profileId,
}) async {
  final InFlowConsent consent;
  try {
    consent = await ConsentOwners.inFlow(connection.store.prefs, profileId);
  } catch (_) {
    return;
  }
  if (!consent.storageAvailable) return;
  final info = await bridge.keepAliveInfo();
  final List<InFlowConsentKind> kinds;
  try {
    kinds = await consent.phoneServerFirstStart(
      batteryAlreadyExempt: info.batteryOptimizationIgnored,
      maker: PhoneMaker.of(info.manufacturer, info.brand),
    );
  } catch (_) {
    return;
  }
  for (final kind in kinds) {
    if (!context.mounted) return;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final words = phoneConsentWords(l10n, kind, maker: info.manufacturer);
    final allow = await showKitConfirm(
      context,
      title: words.title,
      body: words.body,
      confirmLabel: words.allow,
      cancelLabel: l10n.consentNotNow,
      icon: words.icon,
      sheetKey: ValueKey('phone-consent-${kind.name}'),
      confirmKey: ValueKey('phone-consent-${kind.name}-allow'),
    );
    try {
      await consent.answer(kind, allow: allow);
    } catch (_) {
      return;
    }
    if (allow) {
      await runPhoneConsent(kind, connection: connection, bridge: bridge);
    }
  }
}
