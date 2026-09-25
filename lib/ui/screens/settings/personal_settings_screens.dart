part of '../settings_screen.dart';

/// The parts of Appearance a search result can mean.
enum AppearanceSection { mode, language, effects, theme }

/// Appearance category: light/dark mode and language, the effects the
/// person controls (glass, animations, celebrations, vibration; design
/// standard §10) and the theme-pack picker with live swatch previews.
class AppearanceSettingsScreen extends StatefulWidget {
  final ConnectionController controller;

  /// The part a search result means: the screen opens scrolled to it.
  final AppearanceSection? initialSection;

  const AppearanceSettingsScreen({
    super.key,
    required this.controller,
    this.initialSection,
  });

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  final _sectionKeys = {
    for (final section in AppearanceSection.values)
      section: GlobalKey(debugLabel: 'appearance-${section.name}'),
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSection case final section?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _sectionKeys[section]?.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).e7AppearanceTitle)),
      // Not a lazy list: a dozen rows, and a search result that means one
      // part must find it laid out.
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(_settingsCopy(context).appearanceDisplaySection),
            ValueListenableBuilder<AppAppearance>(
              key: _sectionKeys[AppearanceSection.mode],
              valueListenable: controller.appearance,
              builder: (context, appearance, _) => _CategoryRow(
                rowKey: 'appearance-settings-entry',
                icon: AppIconography.contrast,
                title: _settingsCopy(context).e7SettingsUi69,
                subtitle: appearanceLabel(appearance, context),
                onTap: () =>
                    showAppearancePicker(context, controller: controller),
              ),
            ),
            KeyedSubtree(
              key: _sectionKeys[AppearanceSection.language],
              // The kit row's geometry: a 32 dp icon, 12 dp to the title.
              child: ListTileTheme.merge(
                horizontalTitleGap: 12,
                minLeadingWidth: 32,
                child: LanguageSettingsTile(controller: controller),
              ),
            ),
            KeyedSubtree(
              key: _sectionKeys[AppearanceSection.effects],
              child: _EffectsSection(controller: controller),
            ),
            KeyedSubtree(
              key: _sectionKeys[AppearanceSection.theme],
              child: SectionLabel(_settingsCopy(context).e7SettingsUi70),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                controller.themePack,
                harvestedDynamicPack,
              ]),
              builder: (context, _) {
                final selected = controller.themePack.value;
                final brightness = Theme.of(context).brightness;
                // Thirty themes as list rows is a very long page. They are a
                // grid of swatches instead: each card is a miniature of the
                // theme, so choosing is looking, not reading.
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final id in ThemePackId.values)
                        _ThemePackTile(
                          id: id,
                          selected: selected == id,
                          brightness: brightness,
                          available:
                              id != ThemePackId.dynamic ||
                              harvestedDynamicPack.value != null,
                          onSelect: () => showThemePackPreview(
                            context,
                            controller: controller,
                            pack: id,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings › Appearance › Effects (design standard §10): what moves, what
/// is glass, what celebrates and what vibrates. A choice shows at once and
/// is saved; a refused save puts it back and says so. The system's
/// accessibility settings always win, and the rows say when they do.
class _EffectsSection extends StatefulWidget {
  const _EffectsSection({required this.controller});

  final ConnectionController controller;

  @override
  State<_EffectsSection> createState() => _EffectsSectionState();
}

class _EffectsSectionState extends State<_EffectsSection> {
  bool _failed = false;

  Future<void> _choose(KitEffects next) async {
    setState(() => _failed = false);
    try {
      await widget.controller.setEffects(next);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    return ValueListenableBuilder<KitEffects>(
      valueListenable: widget.controller.effects,
      builder: (context, effects, _) {
        // The page shows the choices in force as the person makes them,
        // even where it sits above the app's own scope (tests, previews).
        return KitEffectsScope(
          effects: effects,
          child: Builder(
            builder: (context) {
              final systemStill = MediaQuery.disableAnimationsOf(context);
              final glassSupporting = KitGlass.reduceEffects(context)
                  ? copy.effectsGlassSystem
                  : KitGlassShader.supported
                  ? copy.effectsGlassOn
                  : copy.effectsGlassFrosted;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(copy.effectsSection),
                  _EffectsPreview(effects: effects),
                  KitReveal(
                    child: _failed
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: KitNotice(
                              tone: AppStatusTone.failure,
                              message: copy.effectsSaveFailed,
                            ),
                          )
                        : null,
                  ),
                  KitSwitchRow(
                    key: const ValueKey('effects-glass'),
                    leading: KitRow.icon(context, AppIconography.layers),
                    title: copy.effectsGlass,
                    supporting: glassSupporting,
                    value: effects.glass,
                    onChanged: (value) =>
                        _choose(effects.copyWith(glass: value)),
                  ),
                  KitRow(
                    key: const ValueKey('effects-motion'),
                    leading: KitRow.icon(context, AppIconography.playCircle),
                    title: copy.effectsAnimations,
                    supporting: TextSpan(
                      text: switch (effects.motion) {
                        KitMotionLevel.full => copy.effectsMotionFullHint,
                        KitMotionLevel.calm => copy.effectsMotionCalmHint,
                        KitMotionLevel.off => copy.effectsMotionOffHint,
                      },
                    ),
                    supportingMaxLines: 2,
                    below: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        SegmentedButton<KitMotionLevel>(
                          showSelectedIcon: false,
                          segments: [
                            for (final (level, label) in [
                              (KitMotionLevel.full, copy.effectsMotionFull),
                              (KitMotionLevel.calm, copy.effectsMotionCalm),
                              (KitMotionLevel.off, copy.effectsMotionOff),
                            ])
                              ButtonSegment(
                                value: level,
                                label: Text(
                                  label,
                                  key: ValueKey('effects-motion-${level.name}'),
                                ),
                              ),
                          ],
                          selected: {effects.motion},
                          onSelectionChanged: (choice) =>
                              _choose(effects.copyWith(motion: choice.single)),
                        ),
                        if (systemStill)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              copy.effectsMotionSystemOff,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.mutedOf(Theme.of(context)),
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  KitSwitchRow(
                    key: const ValueKey('effects-celebrations'),
                    leading: KitRow.icon(context, AppIconography.sparkle),
                    title: copy.effectsCelebrations,
                    supporting: copy.effectsCelebrationsHint,
                    value: effects.celebrations,
                    onChanged: (value) =>
                        _choose(effects.copyWith(celebrations: value)),
                  ),
                  KitSwitchRow(
                    key: const ValueKey('effects-vibration'),
                    leading: KitRow.icon(context, AppIconography.touch),
                    title: copy.effectsVibration,
                    supporting: copy.effectsVibrationHint,
                    value: effects.haptics,
                    onChanged: (value) =>
                        _choose(effects.copyWith(haptics: value)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// A small live sample of the effects: the brand's portal drawing itself in
/// (again on each Animations change; finished at once under Off) beside a
/// chip of the app's glass floating over colour. Decorative: the rows say
/// everything in words. No loop, so the page rests.
class _EffectsPreview extends StatelessWidget {
  const _EffectsPreview({required this.effects});

  final KitEffects effects;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              KitIllustration(
                key: ValueKey('effects-preview-${effects.motion.name}'),
                scene: const KitPortalScene(),
                width: 96,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primaryContainer,
                              scheme.tertiaryContainer,
                              scheme.secondaryContainer,
                            ],
                          ),
                        ),
                      ),
                      // Stripes for the glass to bend at its edge.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < 9; i++)
                            Expanded(
                              child: ColoredBox(
                                color: i.isEven
                                    ? Colors.transparent
                                    : scheme.surface.withValues(alpha: .4),
                              ),
                            ),
                        ],
                      ),
                      Center(
                        child: SizedBox(
                          width: 112,
                          height: 44,
                          child: KitGlass(
                            key: const ValueKey('effects-preview-glass'),
                            borderRadius: BorderRadius.circular(22),
                            shadow: false,
                            child: Center(
                              child: Icon(
                                AppIconography.layers,
                                size: 20,
                                color: KitGlass.foregroundColor(
                                  Theme.of(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePackTile extends StatelessWidget {
  final ThemePackId id;
  final bool selected;
  final bool available;
  final Brightness brightness;
  final VoidCallback onSelect;

  const _ThemePackTile({
    required this.id,
    required this.selected,
    required this.available,
    required this.brightness,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final pack = id == ThemePackId.dynamic
        ? harvestedDynamicPack.value
        : themePack(id);
    final palette = pack?.palette(brightness);
    final theme = Theme.of(context);
    final label = themePackLabels[id]!;
    final description = !available
        ? _settingsCopy(context).e7AppearanceDynamicUnavailable
        : _themeDescription(context, id);
    // Three to a row on a phone, more on a wide window.
    final width = MediaQuery.sizeOf(context).width;
    final columns = (width / 130).floor().clamp(2, 6);
    // A hair under the exact share so rounding never drops a card to the
    // next row.
    final cardWidth =
        (width.clamp(0, 900) - 32 - 10 * (columns - 1)) / columns - .5;
    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: description == null ? label : '$label. $description',
      excludeSemantics: true,
      child: Opacity(
        opacity: available ? 1 : .5,
        child: InkWell(
          key: ValueKey('theme-pack-${id.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: available ? onSelect : null,
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The miniature: the theme's page, a surface on it, a line
                // of its text, and its accent and success colours.
                Container(
                  height: 56,
                  color: palette?.background ?? theme.colorScheme.surface,
                  padding: const EdgeInsets.all(8),
                  child: palette == null
                      ? const Center(child: Icon(AppIconography.sparkle))
                      : Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: AlignmentDirectional.centerStart,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Container(
                                  height: 4,
                                  width: 28,
                                  decoration: BoxDecoration(
                                    color: palette.scheme.onSurface,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            for (final color in [
                              palette.scheme.primary,
                              palette.scheme.secondary,
                              palette.success,
                            ])
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsetsDirectional.only(
                                  start: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 6, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      if (selected)
                        Icon(
                          AppIconography.check,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                // Disabled with the truth: a card that cannot be chosen says
                // why, in words, not only by looking faded.
                if (!available && description != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
                    child: Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Privacy category: read-state sync and the unsent work this device is
/// holding on the user's behalf. Durable grants ("Always allowed actions")
/// live under Conversation defaults in the hub: they are about how the agent
/// works, not about privacy.
class PrivacySettingsScreen extends StatefulWidget {
  final ConnectionController controller;
  const PrivacySettingsScreen({super.key, required this.controller});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _busy = false;
  bool _readPreferenceFailed = false;

  ConnectionController get _controller => widget.controller;

  /// Rounded the way a phone's storage screens round: one decimal past a
  /// kilobyte, and never "0 B" for something that exists.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmAndClear({
    required String title,
    required String body,
    required Future<bool> Function() clear,
    required String cleared,
    required String failed,
  }) async {
    final ok = await showConfirmSheet(
      context,
      title: title,
      message: body,
      confirmLabel: _settingsCopy(context).promptStashDelete,
      icon: AppIconography.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final succeeded = await clear();
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(succeeded ? cleared : failed),
        backgroundColor: succeeded ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_settingsCopy(context).settingsHubPrivacyRow)),
      body: ListView(
        padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (!_controller.supportsSessionReadState) {
                return const SizedBox.shrink();
              }
              final l10n =
                  Localizations.of<AppLocalizations>(
                    context,
                    AppLocalizations,
                  ) ??
                  lookupAppLocalizations(const Locale('en'));
              return Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('share-session-views'),
                    title: Text(l10n.shareSessionViewsTitle),
                    subtitle: Text(
                      _controller.shareSessionViews
                          ? l10n.shareSessionViewsOn
                          : l10n.shareSessionViewsOff,
                    ),
                    value: _controller.shareSessionViews,
                    onChanged: _controller.savingReadPrivacy
                        ? null
                        : (value) async {
                            setState(() => _readPreferenceFailed = false);
                            try {
                              await _controller.setShareSessionViews(value);
                            } catch (_) {
                              if (mounted) {
                                setState(() => _readPreferenceFailed = true);
                              }
                            }
                          },
                  ),
                  if (_readPreferenceFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: KitNotice(
                        tone: AppStatusTone.failure,
                        message: l10n.shareSessionViewsSaveError,
                      ),
                    ),
                ],
              );
            },
          ),
          SectionLabel(_settingsCopy(context).e7SettingsUi76),
          // Queued prompts carry attachment data URLs and drafts carry
          // whatever was typed but never sent. Both are the user's content,
          // held indefinitely until a server answers, so both get a size and
          // a way out that does not require deleting the server.
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final queued = _controller.totalQueuedPromptCount;
              final drafts = _controller.totalSessionDraftCount;
              final queuedBytes = _controller.queuedPromptBytes;
              final queueReadable = _controller.queuedPromptStorageReadable;
              final l10n = lookupAppLocalizations(
                Localizations.localeOf(context),
              );
              final draftBytes = _controller.sessionDraftBytes;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KitRow(
                    key: const ValueKey('local-storage-usage'),
                    leading: KitRow.icon(context, Icons.sd_storage_outlined),
                    title: _settingsCopy(context).e7SettingsUi77,
                    supporting: TextSpan(
                      text: !queueReadable
                          ? l10n.queueStorageCountUnknown
                          : _settingsCopy(context).e7SettingsStorageSummary(
                              formatBytes(queuedBytes + draftBytes),
                              queued,
                              formatBytes(queuedBytes),
                              drafts,
                              formatBytes(draftBytes),
                              OfflineQueueStore.maxAge.inDays,
                            ),
                    ),
                    // A readout, not a door: the whole sentence stays.
                    supportingMaxLines: 4,
                  ),
                  // Destructive (§2): error-coloured, confirmed first, never
                  // primary. With nothing to clear the row rests, and its
                  // own line says so.
                  _DestructiveRow(
                    rowKey: 'clear-queued-prompts',
                    icon: AppIconography.outbox,
                    title: _settingsCopy(context).e7SettingsUi78,
                    subtitle: !queueReadable
                        ? l10n.queueStorageUnreadable
                        : queued == 0
                        ? _settingsCopy(context).e7SettingsUi79
                        : _settingsCopy(
                            context,
                          ).e7SettingsQueueDeleteSummary(queued),
                    enabled: (queued > 0 || !queueReadable) && !_busy,
                    onTap: () => _confirmAndClear(
                      title: _settingsCopy(context).e7SettingsUi80,
                      body: !queueReadable
                          ? l10n.queueStorageDiscardUnreadable
                          : _settingsCopy(
                              context,
                            ).e7SettingsQueueDeleteBody(queued),
                      clear: _controller.clearAllQueuedPrompts,
                      cleared: _settingsCopy(context).e7SettingsUi81,
                      failed: _settingsCopy(context).e7SettingsUi82,
                    ),
                  ),
                  _DestructiveRow(
                    rowKey: 'clear-session-drafts',
                    icon: AppIconography.editNote,
                    title: _settingsCopy(context).e7SettingsUi83,
                    subtitle: drafts == 0
                        ? _settingsCopy(context).e7SettingsUi84
                        : _settingsCopy(
                            context,
                          ).e7SettingsDraftDeleteSummary(drafts),
                    enabled: drafts > 0 && !_busy,
                    onTap: () => _confirmAndClear(
                      title: _settingsCopy(context).e7SettingsUi85,
                      body: _settingsCopy(
                        context,
                      ).e7SettingsDraftDeleteBody(drafts),
                      clear: _controller.clearAllSessionDrafts,
                      cleared: _settingsCopy(context).e7SettingsUi86,
                      failed: _settingsCopy(context).e7SettingsUi87,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A row that deletes something this device holds (design standard §2):
/// error-coloured, always confirmed by its action, never a primary button.
class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final String rowKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KitRow(
    key: ValueKey(rowKey),
    leading: KitRow.icon(
      context,
      icon,
      color: Theme.of(context).colorScheme.error,
    ),
    title: title,
    supporting: TextSpan(text: subtitle),
    supportingMaxLines: 2,
    destructive: true,
    enabled: enabled,
    onTap: onTap,
  );
}

String? _themeDescription(BuildContext context, ThemePackId id) => switch (id) {
  ThemePackId.opencode => _settingsCopy(context).e7AppearancePackOpencode,
  ThemePackId.catppuccin => _settingsCopy(context).e7AppearancePackCatppuccin,
  ThemePackId.gruvbox => _settingsCopy(context).e7AppearancePackGruvbox,
  ThemePackId.solarized => _settingsCopy(context).e7AppearancePackSolarized,
  ThemePackId.dynamic => _settingsCopy(context).e7AppearancePackDynamic,
  // A generated theme is its name and its colours.
  _ => null,
};
