part of '../settings_screen.dart';

/// Coding defaults category: the server-backed default shell, the selected
/// model and agent, and experimental notes.
class CodingSettingsScreen extends StatefulWidget {
  final ConnectionController controller;
  const CodingSettingsScreen({super.key, required this.controller});

  @override
  State<CodingSettingsScreen> createState() => _CodingSettingsScreenState();
}

class _CodingSettingsScreenState extends State<CodingSettingsScreen>
    with WidgetsBindingObserver {
  TerminalShellSettings? _shellSettings;
  String? _shellError;
  bool _loadingShell = false;
  bool _savingShell = false;
  int _shellLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_connectionChanged);
    _loadShellSettings();
  }

  void _connectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadShellSettings());
    }
  }

  Future<void> _loadShellSettings() async {
    // Runs from initState, so inherited lookups are not yet allowed.
    final copy = earlyAppLocalizations(context);
    // The row is gated (§7 row 22) rather than removed, so it must not spend a
    // request that can only come back as an "unavailable" error.
    if (!widget.controller.capabilities.shellSettings) return;
    final generation = ++_shellLoadGeneration;
    setState(() {
      _loadingShell = true;
      _shellError = null;
    });
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (repository == null) {
        throw ProductException(copy.e7SettingsUi19);
      }
      final settings = await repository.loadTerminalShellSettings();
      if (mounted && generation == _shellLoadGeneration) {
        setState(() => _shellSettings = settings);
      }
    } catch (error) {
      if (mounted && generation == _shellLoadGeneration) {
        setState(() => _shellError = productErrorText(error));
      }
    } finally {
      if (mounted && generation == _shellLoadGeneration) {
        setState(() => _loadingShell = false);
      }
    }
  }

  Future<void> _chooseShell() async {
    final copy = _settingsCopy(context);
    final settings = _shellSettings;
    if (_savingShell) return;
    if (settings == null) {
      await _loadShellSettings();
      return;
    }
    final choices = _shellChoices(settings);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Icon(AppIconography.terminal),
                title: Text(copy.e7SettingsUi35),
                subtitle: Text(copy.e7SettingsUi36),
              ),
              for (final choice in choices)
                ListTile(
                  key: ValueKey('server-shell-${choice.id}'),
                  leading: Icon(
                    choice.value == settings.selected
                        ? AppIconography.radioSelected
                        : AppIconography.radioEmpty,
                  ),
                  title: Text(
                    choice.label,
                    textDirection: choice.value.isEmpty
                        ? null
                        : TextDirection.ltr,
                  ),
                  subtitle: choice.terminalOnly
                      ? Text(copy.e7SettingsUi37)
                      : null,
                  onTap: () => Navigator.pop(context, choice.value),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == settings.selected || !mounted) return;

    setState(() => _savingShell = true);
    final locationRevision = widget.controller.locationRevision;
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (repository == null) {
        throw ProductException(copy.e7SettingsUi19);
      }
      await repository.selectTerminalShell(selected);
      if (!mounted) return;
      if (locationRevision == widget.controller.locationRevision) {
        setState(
          () => _shellSettings = TerminalShellSettings(
            selected: selected,
            options: settings.options,
          ),
        );
      }
      await _loadShellSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.e7SettingsUi38)));
    } catch (error) {
      if (mounted) showProductError(context, error);
    } finally {
      if (mounted) setState(() => _savingShell = false);
    }
  }

  List<_ShellChoice> _shellChoices(TerminalShellSettings settings) {
    final nameCounts = <String, int>{};
    for (final option in settings.options) {
      nameCounts.update(option.name, (count) => count + 1, ifAbsent: () => 1);
    }
    final choices = <_ShellChoice>[
      _ShellChoice(
        id: 'automatic',
        value: '',
        label: _settingsCopy(context).e7SettingsUi39,
        terminalOnly: false,
      ),
    ];
    final values = <String>{''};
    for (final option in settings.options) {
      final ambiguous = nameCounts[option.name] != 1;
      final value = ambiguous ? option.path : option.name;
      if (!values.add(value)) continue;
      choices.add(
        _ShellChoice(
          id: option.path,
          value: value,
          label: ambiguous ? option.path : option.name,
          terminalOnly: !option.acceptable,
        ),
      );
    }
    if (settings.selected.isNotEmpty && values.add(settings.selected)) {
      choices.add(
        _ShellChoice(
          id: settings.selected,
          value: settings.selected,
          label: settings.selected,
          terminalOnly: false,
        ),
      );
    }
    return choices;
  }

  String _selectedShellLabel(TerminalShellSettings settings) {
    if (settings.selected.isEmpty) return _settingsCopy(context).e7SettingsUi39;
    final choices = _shellChoices(settings);
    for (final choice in choices) {
      if (choice.value == settings.selected) return choice.label;
    }
    return settings.selected;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7SettingsUi2)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!controller.capabilities.shellSettings)
            GatedRowTile(
              feature: 'shell-settings',
              title: _settingsCopy(context).e7SettingsUi35,
              explainer: _settingsCopy(context).e7SettingsUi40,
              leading: Icon(AppIconography.terminal),
            )
          else
            ListTile(
              key: const ValueKey('default-shell-settings-entry'),
              leading: const Icon(AppIconography.terminal),
              title: Text(_settingsCopy(context).e7SettingsUi35),
              subtitle: Text(
                _shellError != null
                    ? _settingsCopy(context).e7SettingsRetryError(_shellError!)
                    : _shellSettings == null
                    ? _settingsCopy(context).e7SettingsUi41
                    : _selectedShellLabel(_shellSettings!),
              ),
              trailing: _loadingShell || _savingShell
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIconography.chevronRight),
              onTap: _loadingShell || _savingShell
                  ? null
                  : _shellError != null
                  ? _loadShellSettings
                  : _chooseShell,
            ),
          ListTile(
            leading: const Icon(AppIconography.model),
            title: Text(_settingsCopy(context).e7SettingsUi42),
            subtitle: Text(
              controller.selectedModel == null
                  ? _settingsCopy(context).modelServerDefault
                  : [
                      controller.catalog?.models
                              .where(
                                (model) =>
                                    model.providerID ==
                                        controller.selectedModel!.providerID &&
                                    model.id ==
                                        controller.selectedModel!.modelID,
                              )
                              .firstOrNull
                              ?.name ??
                          presentedModelLabel(
                            controller.selectedModel!.providerID,
                            controller.selectedModel!.modelID,
                          ),
                      if (controller.selectedVariant.isNotEmpty)
                        controller.selectedVariant,
                    ].join(' · '),
            ),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => showModelPicker(context),
          ),
          ListTile(
            leading: const Icon(AppIconography.support),
            title: Text(_settingsCopy(context).e7SettingsUi44),
            subtitle: Text(
              controller.selectedAgent.isEmpty
                  ? _settingsCopy(context).modelServerDefault
                  : controller.selectedAgent,
            ),
            trailing: const Icon(AppIconography.chevronRight),
            onTap: () => showModelPicker(context, focusAgent: true),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _shellLoadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_connectionChanged);
    super.dispose();
  }
}
