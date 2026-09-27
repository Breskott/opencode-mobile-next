import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/tailscale.dart';
import '../../state/tailscale_address.dart';
import '../app_iconography.dart';
import '../kit/kit_action_stack.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_checklist.dart';
import '../kit/kit_details_fold.dart';
import '../kit/kit_field.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_screen.dart';
import '../kit/kit_status_mark.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/kit_top_bar.dart';
import '../widgets/external_link.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.tailscale.ipn';
const _serveGuideUrl = 'https://tailscale.com/docs/features/tailscale-serve';
const _androidGuideUrl = 'https://tailscale.com/docs/install/android';

/// User-controlled app handoff, then an address review. Returning a URL does
/// not probe, save, authenticate or assert that Tailscale is connected.
///
/// Two numbered sections: the phone's side as a [KitChecklist] (the app,
/// then the VPN the person turns on in Tailscale, which this app cannot
/// see), and the server address with the one pinned Continue, disabled with
/// its reason until an address is typed. The long guidance folds under
/// Details. Coming back from Tailscale checks the app again by itself.
class TailscaleSetupScreen extends StatefulWidget {
  const TailscaleSetupScreen({
    super.key,
    this.initialAddress = '',
    this.bridge = const TailscaleBridge(),
  });
  final String initialAddress;
  final TailscaleBridge bridge;

  @override
  State<TailscaleSetupScreen> createState() => _TailscaleSetupScreenState();
}

class _TailscaleSetupScreenState extends State<TailscaleSetupScreen>
    with WidgetsBindingObserver {
  late final _address = TextEditingController(text: widget.initialAddress);
  TailscaleAppState? _state;
  bool _checking = false,
      _opening = false,
      _returned = false,
      _openFailed = false;
  bool _addressError = false;
  int _generation = 0;
  AppLocalizations get l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _address.addListener(_addressChanged);
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _returned = true);
      unawaited(_check());
    }
  }

  /// Rebuilds Continue's enabled state and clears a shown error on edit.
  void _addressChanged() {
    if (!mounted) return;
    setState(() => _addressError = false);
  }

  Future<void> _check() async {
    final generation = ++_generation;
    setState(() => _checking = true);
    final result = await widget.bridge.check();
    if (!mounted || generation != _generation) return;
    setState(() {
      _state = result;
      _checking = false;
    });
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final opened = await widget.bridge.open();
    if (!mounted) return;
    setState(() {
      _opening = false;
      _openFailed = !opened;
    });
    if (!opened) await _check();
  }

  void _continue() {
    if (!isValidTailscaleAddress(_address.text)) {
      setState(() => _addressError = true);
      return;
    }
    Navigator.of(context).pop(normalizeTailscaleAddress(_address.text));
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _address.removeListener(_addressChanged);
    _address.dispose();
    super.dispose();
  }

  /// Step 1: whether the official app is on this phone. Missing offers the
  /// Play Store page through the external-link review; a failed check
  /// offers Check app again on its row.
  KitStep _appStep(AppLocalizations strings) {
    final title = strings.tailscaleSetupAppTitle;
    if (_checking || _state == null) {
      return KitStep(
        title: title,
        state: KitMarkState.working,
        supporting: strings.tailscaleChecking,
      );
    }
    return switch (_state!) {
      TailscaleAppState.installed => KitStep(
        title: title,
        state: KitMarkState.done,
        supporting: strings.tailscaleInstalled,
      ),
      TailscaleAppState.missing => KitStep(
        title: title,
        state: KitMarkState.waiting,
        supporting: strings.tailscaleMissing,
        personAction: KitAction(
          label: strings.tailscaleSetupGetApp,
          icon: AppIconography.download,
          onPressed: () => openExternalLink(context, _playStoreUrl),
        ),
      ),
      TailscaleAppState.unsupported => KitStep(
        title: title,
        state: KitMarkState.waiting,
        supporting: strings.tailscaleUnsupported,
      ),
      TailscaleAppState.unavailable => KitStep(
        title: title,
        state: KitMarkState.failed,
        supporting: strings.tailscaleUnknown,
        retry: KitAction(label: strings.tailscaleCheckAgain, onPressed: _check),
      ),
    };
  }

  /// Step 2: the person signs in and turns the VPN on in Tailscale. This
  /// app cannot see that, so the step is never drawn done.
  KitStep _vpnStep(AppLocalizations strings) {
    final title = strings.tailscaleSetupVpnTitle;
    final open = KitAction(
      label: strings.tailscaleOpen,
      icon: AppIconography.externalLink,
      working: _opening,
      onPressed: _open,
    );
    if (_openFailed) {
      return KitStep(
        title: title,
        state: KitMarkState.failed,
        supporting: strings.tailscaleSetupOpenFailed,
        retry: _state == TailscaleAppState.installed ? open : null,
      );
    }
    return KitStep(
      title: title,
      state: KitMarkState.waiting,
      supporting: strings.tailscaleSetupVpnSupporting,
      personAction: _state == TailscaleAppState.installed && !_checking
          ? open
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n;
    final tokens = KitTokens.of(context);
    final hasAddress = _address.text.trim().isNotEmpty;
    // Check app again sits under the steps unless the failed row already
    // offers it, or the device cannot run the Android app at all.
    final recheck =
        _state != TailscaleAppState.unavailable &&
        _state != TailscaleAppState.unsupported;
    return KitScreen(
      topBar: KitTopBar(title: strings.tailscaleTitle),
      width: KitScreenWidth.reading,
      bottom: KitActionBlock(
        primary: KitAction(
          label: strings.tailscaleContinue,
          icon: AppIconography.forward,
          onPressed: hasAddress ? _continue : null,
          disabledReason: hasAddress
              ? null
              : strings.tailscaleSetupContinueReason,
        ),
      ),
      body: ListView(
        padding: KitScreen.padding(context),
        children: [
          SizedBox(height: tokens.space2),
          KitText(strings.tailscaleIntro, tone: KitTextTone.secondary),
          SizedBox(height: tokens.sectionGap),
          _SectionLabel(strings.tailscaleAppStep),
          KitChecklist(steps: [_appStep(strings), _vpnStep(strings)]),
          if (recheck)
            Padding(
              // Under the steps' words, past the mark column.
              padding: EdgeInsetsDirectional.only(
                start: KitTokens.markSlotSize + tokens.space3,
              ),
              child: KitActionStack(
                tertiary: [
                  // Stays enabled while a check runs: a new check
                  // supersedes the old one (_generation).
                  KitAction(
                    label: strings.tailscaleCheckAgain,
                    onPressed: _check,
                  ),
                ],
              ),
            ),
          // Under the steps, where the person is when they come back from
          // Tailscale, not scrolled away above them.
          if (_returned) ...[
            SizedBox(height: tokens.space4),
            KitNotice(
              icon: AppIconography.info,
              message: strings.tailscaleReturned,
            ),
          ],
          SizedBox(height: tokens.sectionGap),
          _SectionLabel(strings.tailscaleAddressStep),
          KitField(
            label: strings.tailscaleAddressLabel,
            controller: _address,
            kind: KitFieldKind.url,
            hint: 'https://computer.tailnet-name.ts.net',
            helper: strings.tailscaleSetupAddressHelper,
            error: _addressError ? strings.tailscaleAddressError : null,
            maxLength: 2048,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _continue(),
          ),
          SizedBox(height: tokens.space3),
          KitText(
            strings.tailscaleReviewDetail,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
          SizedBox(height: tokens.sectionGap),
          KitDetailsFold(
            label: strings.tailscaleHelp,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                KitText(strings.tailscaleVpnHandoff),
                SizedBox(height: tokens.space3),
                KitText(strings.tailscaleAddressDetail),
                SizedBox(height: tokens.space3),
                KitText(strings.tailscaleServeHelp),
                KitButton.tertiary(
                  label: strings.tailscaleServeDocs,
                  icon: AppIconography.externalLink,
                  onPressed: () => openExternalLink(context, _serveGuideUrl),
                ),
                SizedBox(height: tokens.space2),
                KitText(strings.tailscaleRecovery),
                KitButton.tertiary(
                  label: strings.tailscaleAndroidDocs,
                  icon: AppIconography.externalLink,
                  onPressed: () => openExternalLink(context, _androidGuideUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered section's name above its content, in the section-label role
/// (KitRowGroup's label, without a panel: the steps and the field sit on
/// the ground so their buttons keep the full width).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: tokens.labelGap),
      child: Semantics(
        header: true,
        child: KitText(
          text,
          role: KitTextRole.label,
          tone: KitTextTone.secondary,
        ),
      ),
    );
  }
}
