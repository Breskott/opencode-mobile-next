import 'dart:async';

import 'package:flutter/material.dart';

import '../../../builtin/setup/setup_contract.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_theme.dart';
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
}) => showModalBottomSheet<Set<String>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => SetupCustomizeSheet(
    registry: installableComponents(engine.registry),
    addMode: addMode,
    selected: selected,
    installedOptional: addMode ? engine.installedOptional() : null,
  ),
);

class SetupCustomizeSheet extends StatefulWidget {
  const SetupCustomizeSheet({
    super.key,
    required this.registry,
    this.addMode = false,
    this.selected,
    this.installedOptional,
  });

  final List<SetupComponent> registry;
  final bool addMode;

  /// The current selection to start from; the registry defaults when null.
  final Set<String>? selected;

  /// Add mode only: which optional components are already installed. The
  /// check can take a moment (it asks inside Linux), so the sheet opens at
  /// once and locks its switches until the answer is in.
  final Future<Set<String>>? installedOptional;

  @override
  State<SetupCustomizeSheet> createState() => _SetupCustomizeSheetState();
}

class _SetupCustomizeSheetState extends State<SetupCustomizeSheet> {
  late Set<String> _chosen;
  Set<String>? _installed;

  List<SetupComponent> get _optional => [
    for (final component in widget.registry)
      if (!component.required) component,
  ];

  @override
  void initState() {
    super.initState();
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
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final rows = widget.addMode ? _optional : widget.registry;
    final checking = widget.addMode && _installed == null;
    final install = _willInstall;
    final totals = setupTotals(install);
    final String totalsText;
    if (checking) {
      totalsText = l10n.phoneSetupStartChecking;
    } else if (install.isEmpty) {
      totalsText = l10n.phoneSetupStartNothingChosen;
    } else {
      totalsText = l10n.phoneSetupStartTotals(
        setupDurationText(l10n, totals.seconds),
        setupSizeText(l10n, totals.bytes),
      );
    }
    // One scroll for the whole sheet: at large text a pinned footer would
    // leave no room for the rows it totals.
    return ListView(
      key: const ValueKey('phone-setup-customize-sheet'),
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Semantics(
            header: true,
            child: Text(
              widget.addMode
                  ? l10n.phoneSetupStartAddTitle
                  : l10n.phoneSetupStartCustomizeTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        for (final component in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _row(context, l10n, component, checking: checking),
          ),
        Divider(height: 1, color: AppTheme.hairline(theme)),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  totalsText,
                  key: const ValueKey('phone-setup-customize-totals'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('phone-setup-customize-done'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: checking || (widget.addMode && install.isEmpty)
                    ? null
                    : () => Navigator.of(context).pop(_result),
                child: Text(
                  widget.addMode
                      ? l10n.phoneSetupStartAdd
                      : l10n.phoneSetupStartDone,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    SetupComponent component, {
    required bool checking,
  }) {
    final theme = Theme.of(context);
    final key = ValueKey('phone-setup-customize-${component.id}');
    if (component.required) {
      // Shown so nothing is installed behind the person's back, but locked:
      // switching it off would leave no working agent.
      return SwitchListTile(
        key: key,
        value: true,
        onChanged: null,
        title: Text(component.title),
        subtitle: Text(component.why ?? l10n.phoneSetupStartRequiredWhy),
      );
    }
    if (widget.addMode && _isInstalled(component.id)) {
      return ListTile(
        key: key,
        title: Text(component.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIconography.check,
              size: AppIconography.inlineSize,
              color: AppTheme.successOf(theme),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.phoneSetupStartInstalled,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ],
        ),
      );
    }
    final bytes = component.downloadBytes;
    return SwitchListTile(
      key: key,
      value: _chosen.contains(component.id),
      onChanged: checking ? null : (on) => _toggle(component, on),
      title: Text(component.title),
      subtitle: bytes == null || bytes <= 0
          ? null
          : Text(
              l10n.phoneSetupStartApproxSize(setupSizeText(l10n, bytes)),
              style: TextStyle(color: AppTheme.mutedOf(theme)),
            ),
    );
  }
}
