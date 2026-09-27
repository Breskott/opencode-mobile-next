import 'dart:async';

import 'package:flutter/material.dart';

import '../../../builtin/builtin_linux.dart';
import '../../../builtin/setup/preflight.dart';
import '../../../builtin/setup/setup_contract.dart';
import '../../../l10n/app_localizations.dart';
import '../../../voice/device.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import 'phone_setup_selection.dart';

/// The Customize sheet of screen A, and "Add tools" from the phone's card.
///
/// First setup ([addMode] false): every component, required ones on and
/// locked with their reason, optional ones as switches. It returns the whole
/// selection (required ids included) so the caller can hand it straight to
/// `SetupEngine.run`.
///
/// Add mode: only optional components. Those already on the phone are shown
/// as installed and cannot be toggled; it returns only the ids to add.
///
/// Totals update as switches change and always count what the engine will
/// really install, dependencies included.
Future<Set<String>?> showSetupCustomizeSheet(
  BuildContext context, {
  required SetupEngine engine,
  bool addMode = false,
  Set<String>? selected,
}) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return showKitSheet<Set<String>>(
    context,
    title: addMode
        ? l10n.phoneSetupStartAddTitle
        : l10n.phoneSetupStartCustomizeTitle,
    icon: AppIconography.download,
    body: (_) => SetupCustomizeSheet(
      registry: installableComponents(engine.registry),
      addMode: addMode,
      selected: selected,
      installedOptional: addMode ? engine.installedOptional() : null,
      framed: true,
    ),
  );
}

class SetupCustomizeSheet extends StatefulWidget {
  const SetupCustomizeSheet({
    super.key,
    required this.registry,
    this.addMode = false,
    this.selected,
    this.installedOptional,
    this.deviceProbe,
    this.linux,
    this.framed = false,
  });

  final List<SetupComponent> registry;

  /// Drawn inside a [KitSheet] ([showSetupCustomizeSheet]), which already
  /// shows the title and scrolls. False (the default, for a caller that
  /// hosts the sheet itself) draws the title and its own scroll view.
  final bool framed;
  final bool addMode;

  /// The current selection to start from; the registry defaults when null.
  final Set<String>? selected;

  /// Add mode only: which optional components are already installed. The
  /// check can take a moment (it asks inside Linux), so the sheet opens at
  /// once and locks its switches until the answer is in.
  final Future<Set<String>>? installedOptional;

  /// The device info the pre-flight check reads (P0.8): CPU ABI, free space
  /// and total RAM. Defaults to [voiceDevicePlatform.getDeviceInfo], already
  /// collected for voice; tests stand in for the `oc/voice` channel.
  final Future<VoiceDeviceInfo> Function()? deviceProbe;

  /// Opens Android's Storage settings for the low-space state. Defaults to
  /// a plain [BuiltinLinux] (instances are cheap and hold no state).
  final BuiltinLinux? linux;

  @override
  State<SetupCustomizeSheet> createState() => _SetupCustomizeSheetState();
}

class _SetupCustomizeSheetState extends State<SetupCustomizeSheet> {
  late Set<String> _chosen;
  Set<String>? _installed;
  VoiceDeviceInfo? _device;

  List<SetupComponent> get _optional => [
    for (final component in widget.registry)
      if (!component.required) component,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_probeDevice());
    if (widget.addMode) {
      _chosen = {...?widget.selected};
      final pending = widget.installedOptional;
      if (pending == null) {
        _installed = const {};
      } else {
        unawaited(
          pending.then(
            (installed) {
              if (mounted) setState(() => _installed = installed);
            },
            // Unknown is treated as "nothing installed": the engine's check
            // scripts skip whatever turns out to be there anyway.
            onError: (Object _) {
              if (mounted) setState(() => _installed = const {});
            },
          ),
        );
      }
    } else {
      _chosen = {
        for (final component in widget.registry)
          if (!component.required &&
              (widget.selected?.contains(component.id) ?? component.defaultOn))
            component.id,
      };
    }
  }

  bool _isInstalled(String id) => _installed?.contains(id) ?? false;

  /// P0.8: the CPU ABI, free space and total RAM the pre-flight check reads,
  /// before "Done"/"Add" starts a download.
  Future<void> _probeDevice() async {
    VoiceDeviceInfo device;
    try {
      device =
          await (widget.deviceProbe ?? voiceDevicePlatform.getDeviceInfo)();
    } catch (_) {
      device = const VoiceDeviceInfo.unknown();
    }
    if (mounted) setState(() => _device = device);
  }

  /// Null while the device has not answered yet, or nothing is wrong.
  SetupPreflightResult? _preflightFor(List<SetupComponent> install) {
    final device = _device;
    if (device == null || install.isEmpty) return null;
    final result = checkSetupPreflight(
      device,
      downloadBytes: setupTotals(install).bytes,
    );
    return result.supported ? null : result;
  }

  Future<void> _openStorageSettings() async {
    try {
      await (widget.linux ?? BuiltinLinux()).openStorageSettings();
    } catch (_) {
      // No native answer (an old build, a test): nothing else to try.
    }
    if (mounted) unawaited(_probeDevice());
  }

  /// Turning a tool on turns on the optional tools it needs; turning one off
  /// turns off the optional tools that need it. The switches never show a
  /// state the engine would silently override.
  void _toggle(SetupComponent component, bool on) {
    final byId = {for (final c in widget.registry) c.id: c};
    final next = {..._chosen};
    void enable(String id) {
      final target = byId[id];
      if (target == null || target.required || _isInstalled(id)) return;
      if (!next.add(id)) return;
      target.dependsOn.forEach(enable);
    }

    void disable(String id) {
      if (!next.remove(id)) return;
      for (final other in widget.registry) {
        if (other.dependsOn.contains(id)) disable(other.id);
      }
    }

    if (on) {
      enable(component.id);
    } else {
      disable(component.id);
    }
    setState(() => _chosen = next);
  }

  /// What the engine will actually run for the current switches.
  List<SetupComponent> get _willInstall {
    if (!widget.addMode) {
      return expandSetupSelection(widget.registry, _chosen);
    }
    // Adding tools to a phone that is already set up: the required base is
    // there, and so is every optional tool the check found.
    return [
      for (final component in expandSetupSelection(
        widget.registry,
        _chosen,
        includeRequired: false,
      ))
        if (!component.required && !_isInstalled(component.id)) component,
    ];
  }

  Set<String> get _result => {
    for (final component in _willInstall) component.id,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final rows = widget.addMode ? _optional : widget.registry;
    final checking = widget.addMode && _installed == null;
    final install = _willInstall;
    final totals = setupTotals(install);
    // P0.8: told why before "Done"/"Add" starts a download, never after a
    // failed one.
    final preflight = checking ? null : _preflightFor(install);
    // Add mode with every optional tool already on the phone (map
    // statesMissing "everything optional installed"): nothing to choose.
    final everythingInstalled =
        widget.addMode &&
        !checking &&
        rows.isNotEmpty &&
        rows.every((component) => _isInstalled(component.id));
    final String totalsText;
    if (checking) {
      totalsText = l10n.phoneSetupStartChecking;
    } else if (everythingInstalled) {
      totalsText = l10n.phoneSetupCustomizeAllInstalled;
    } else if (install.isEmpty) {
      totalsText = l10n.phoneSetupStartNothingChosen;
    } else if (preflight != null) {
      totalsText = setupPreflightBody(l10n, preflight);
    } else {
      totalsText = l10n.phoneSetupStartTotals(
        setupDurationText(l10n, totals.seconds),
        setupSizeText(l10n, totals.bytes),
      );
    }
    final disabled =
        checking || preflight != null || (widget.addMode && install.isEmpty);
    final children = <Widget>[
      if (!widget.framed)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.gutter,
            end: tokens.gutter,
            bottom: tokens.space2,
          ),
          child: Semantics(
            header: true,
            child: KitText(
              widget.addMode
                  ? l10n.phoneSetupStartAddTitle
                  : l10n.phoneSetupStartCustomizeTitle,
              role: KitTextRole.title,
            ),
          ),
        ),
      KitRowGroup(
        margin: EdgeInsetsDirectional.zero,
        leadingIcons: false,
        children: [
          for (final component in rows)
            _row(context, l10n, component, checking: checking),
        ],
      ),
      SizedBox(height: tokens.space4),
      // What the switches add up to, said once as they change. A problem
      // the phone has (P0.8) is a notice with its fix beside it.
      if (preflight == null)
        Semantics(
          liveRegion: true,
          child: KitText(
            totalsText,
            key: const ValueKey('phone-setup-customize-totals'),
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
        )
      else
        KitNotice(
          key: const ValueKey('phone-setup-customize-preflight'),
          messageKey: const ValueKey('phone-setup-customize-totals'),
          icon: AppIconography.warning,
          title: setupPreflightHeadline(l10n, preflight.issue!),
          message: totalsText,
          actions: [
            if (preflight.issue == SetupPreflightIssue.lowSpace)
              KitAction(
                key: const ValueKey('phone-setup-customize-open-storage'),
                label: l10n.phoneSetupPreflightOpenStorage,
                onPressed: _openStorageSettings,
              ),
          ],
        ),
      SizedBox(height: tokens.space4),
      // The line right above is the reason when it is off ("Nothing chosen
      // yet", "Checking…", everything installed, a pre-flight problem): the
      // visible reason next to the button (STATE-8), said once.
      KitActionBlock(
        primary: KitAction(
          key: const ValueKey('phone-setup-customize-done'),
          label: widget.addMode
              ? l10n.phoneSetupStartAdd
              : l10n.phoneSetupStartDone,
          onPressed: disabled ? null : () => Navigator.of(context).pop(_result),
        ),
      ),
    ];
    final column = Column(
      key: widget.framed ? const ValueKey('phone-setup-customize-sheet') : null,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (widget.framed) return column;
    // Hosted on its own: one scroll for the whole sheet, since at large
    // text a pinned footer would leave no room for the rows it totals.
    return ListView(
      key: const ValueKey('phone-setup-customize-sheet'),
      shrinkWrap: true,
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: tokens.space4,
      ),
      children: [column],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    SetupComponent component, {
    required bool checking,
  }) {
    final key = ValueKey('phone-setup-customize-${component.id}');
    if (component.required) {
      // Shown so nothing is installed behind the person's back, but locked
      // on with its reason (KIT-30: an always-on setting is locked, not a
      // disabled switch): switching it off would leave no working agent.
      return KitSwitchRow(
        key: key,
        title: component.title,
        value: true,
        onChanged: null,
        supporting: component.why ?? l10n.phoneSetupStartRequiredWhy,
        locked: l10n.phoneSetupCustomizeIncluded,
      );
    }
    if (widget.addMode && _isInstalled(component.id)) {
      return KitSwitchRow(
        key: key,
        title: component.title,
        value: true,
        onChanged: null,
        locked: l10n.phoneSetupStartInstalled,
      );
    }
    final bytes = component.downloadBytes;
    return KitSwitchRow(
      key: key,
      title: component.title,
      value: _chosen.contains(component.id),
      onChanged: checking ? null : (on) => _toggle(component, on),
      disabledReason: checking ? l10n.phoneSetupStartChecking : null,
      supporting: bytes == null || bytes <= 0
          ? null
          : l10n.phoneSetupStartApproxSize(setupSizeText(l10n, bytes)),
    );
  }
}
