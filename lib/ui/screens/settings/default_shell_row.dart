part of '../settings_screen.dart';

/// The server-backed default shell, as one hub row that opens the shell
/// sheet. It owns its own load/save state so the hub does not spend a request
/// for a row a search has filtered out.
class DefaultShellRow extends StatefulWidget {
  final ConnectionController controller;
  const DefaultShellRow({super.key, required this.controller});

  @override
  State<DefaultShellRow> createState() => _DefaultShellRowState();
}

class _DefaultShellRowState extends State<DefaultShellRow>
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
    // The hub only builds this row when the server has shell settings; the
    // guard keeps a capability change mid-life from spending a request that
    // can only come back as an "unavailable" error.
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
    final copy = _settingsCopy(context);
    final busy = _loadingShell || _savingShell;
    return ListTile(
      key: const ValueKey('default-shell-settings-entry'),
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 32,
      horizontalTitleGap: 12,
      leading: const _CategoryIcon(icon: AppIconography.terminal),
      title: Text(copy.e7SettingsUi35),
      subtitle: Text(
        _shellError != null
            ? copy.e7SettingsRetryError(_shellError!)
            : _shellSettings == null
            ? copy.e7SettingsUi41
            : _selectedShellLabel(_shellSettings!),
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(AppIconography.chevronRight, size: 20),
      onTap: busy
          ? null
          : _shellError != null
          ? _loadShellSettings
          : _chooseShell,
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
