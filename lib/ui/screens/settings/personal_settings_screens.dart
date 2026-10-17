part of '../settings_screen.dart';

/// The parts of Appearance a search result can mean.
enum AppearanceSection { mode, effects, theme }

/// Appearance category (`appearance-settings`): light or dark in one tap,
/// the effects the person controls (animations,
/// celebrations, vibration; design standard §10) and the theme packs as
/// swatches. Kit only (screen-settings-1): KitRowGroup panels of KitRow,
/// KitSegmented, KitPickerRow and KitSwitchRow, and a KitSwatchGrid.
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

  /// A display choice (light or dark, language) the device refused to save.
  bool _displayFailed = false;

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

  Future<void> _saveDisplay(Future<void> Function() write) async {
    setState(() => _displayFailed = false);
    try {
      await write();
    } catch (_) {
      if (mounted) setState(() => _displayFailed = true);
    }
  }

  Widget _display(BuildContext context) {
    final controller = widget.controller;
    final copy = _settingsCopy(context);
    final tokens = KitTokens.of(context);
    return ListenableBuilder(
      listenable: controller.appearance,
      builder: (context, _) {
        final appearance = controller.appearance.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_displayFailed)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tokens.gutter,
                  end: tokens.gutter,
                  bottom: tokens.space3,
                ),
                child: KitNotice(
                  key: const ValueKey('appearance-display-failed'),
                  tone: AppStatusTone.failure,
                  message: copy.effectsSaveFailed,
                ),
              ),
            KitRowGroup(
              label: copy.appearanceDisplaySection,
              children: [
                // Light or dark in one tap (map actionsMissing).
                KeyedSubtree(
                  key: _sectionKeys[AppearanceSection.mode],
                  child: KitRow(
                    key: const ValueKey('appearance-settings-entry'),
                    leading: KitRow.icon(context, AppIconography.contrast),
                    title: copy.e7SettingsUi69,
                    below: Padding(
                      padding: EdgeInsetsDirectional.only(
                        top: tokens.space2,
                        bottom: tokens.space1,
                      ),
                      child: KitSegmented<AppAppearance>(
                        semanticsLabel: copy.e7SettingsUi69,
                        selected: appearance,
                        segments: [
                          for (final value in AppAppearance.values)
                            KitSegment(
                              key: ValueKey('appearance-mode-${value.name}'),
                              value: value,
                              label: switch (value) {
                                AppAppearance.system =>
                                  copy.appearanceModeSystem,
                                _ => appearanceLabel(value, context),
                              },
                            ),
                        ],
                        onChanged: (value) =>
                            _saveDisplay(() => controller.setAppearance(value)),
                      ),
                    ),
                  ),
                ),
                // The app's own text size, on top of the phone's (the
                // change eases in at the app root).
                ValueListenableBuilder<KitTextSize>(
                  valueListenable: controller.textSize,
                  builder: (context, size, _) => KitRow(
                    key: const ValueKey('text-size-row'),
                    leading: KitRow.icon(context, AppIconography.textSize),
                    title: copy.textSizeTitle,
                    below: Padding(
                      padding: EdgeInsetsDirectional.only(
                        top: tokens.space2,
                        bottom: tokens.space1,
                      ),
                      child: KitSegmented<KitTextSize>(
                        semanticsLabel: copy.textSizeTitle,
                        selected: size,
                        segments: [
                          for (final (value, label) in [
                            (KitTextSize.smallest, copy.textSizeSmallest),
                            (KitTextSize.small, copy.textSizeSmall),
                            (KitTextSize.normal, copy.textSizeDefault),
                            (KitTextSize.large, copy.textSizeLarge),
                          ])
                            KitSegment(
                              key: ValueKey('text-size-${value.name}'),
                              value: value,
                              label: label,
                            ),
                        ],
                        onChanged: (value) =>
                            _saveDisplay(() => controller.setTextSize(value)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _themes(BuildContext context) {
    final controller = widget.controller;
    final copy = _settingsCopy(context);
    final tokens = KitTokens.of(context);
    final brightness = Theme.of(context).brightness;
    final current = ThemeRoles.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.themePack,
        harvestedDynamicPack,
      ]),
      builder: (context, _) {
        final selected = controller.themePack.value;
        // Thirty themes as list rows is a very long page. They are a grid of
        // swatches instead: each is a miniature of the theme, so choosing is
        // looking, not reading.
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tokens.space1,
                  end: tokens.space1,
                  bottom: tokens.labelGap,
                ),
                child: Semantics(
                  header: true,
                  child: KitText(copy.e7SettingsUi70, role: KitTextRole.label),
                ),
              ),
              KitSwatchGrid(
                label: copy.e7SettingsUi70,
                children: [
                  for (final id in ThemePackId.values)
                    _swatch(context, id, selected, brightness, current),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  KitSwatch _swatch(
    BuildContext context,
    ThemePackId id,
    ThemePackId selected,
    Brightness brightness,
    ThemeRoles current,
  ) {
    final pack = id == ThemePackId.dynamic
        ? harvestedDynamicPack.value
        : themePack(id);
    final available = pack != null;
    return KitSwatch(
      swatchKey: ValueKey('theme-pack-${id.name}'),
      // An unharvested Material You pack has no colours of its own yet: it
      // shows the current theme, disabled with the reason in words.
      roles: pack?.palette(brightness).themeRoles ?? current,
      label: themePackLabels[id]!,
      selected: selected == id,
      disabledReason: available
          ? null
          : _settingsCopy(context).e7AppearanceDynamicUnavailable,
      onPressed: available
          ? () => showThemePackPreview(
              context,
              controller: widget.controller,
              pack: id,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final tokens = KitTokens.of(context);
    return KitScreen(
      topBar: KitTopBar(title: _settingsCopy(context).e7AppearanceTitle),
      width: KitScreenWidth.reading,
      // Not a lazy list: a dozen rows in one Column, and a search result
      // that means one part must find it laid out.
      body: ListView(
        key: const ValueKey('appearance-settings'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _display(context),
              SizedBox(height: tokens.sectionGap),
              KeyedSubtree(
                key: _sectionKeys[AppearanceSection.effects],
                child: _EffectsSection(controller: controller),
              ),
              SizedBox(height: tokens.sectionGap),
              KeyedSubtree(
                key: _sectionKeys[AppearanceSection.theme],
                child: _themes(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings › Appearance › Motion (design standard §10): how much the app
/// moves and whether finished moments celebrate, as one choice. Vibration is
/// a fixed part of the design. A choice shows at once and
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

  /// One glowing-border choice: a row with its options as a segmented bar.
  Widget _glowChoice<T extends Enum>(
    KitTokens tokens, {
    required String id,
    required IconData icon,
    required String title,
    String keyPrefix = 'effects-glow',
    required T selected,
    required List<(T, String)> options,
    required ValueChanged<T> onChanged,
  }) {
    return KitRow(
      key: ValueKey('$keyPrefix-$id'),
      leading: KitRow.icon(context, icon),
      title: title,
      below: Padding(
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: tokens.space1,
        ),
        child: KitSegmented<T>(
          semanticsLabel: title,
          selected: selected,
          segments: [
            for (final (value, label) in options)
              KitSegment(
                key: ValueKey('$keyPrefix-$id-${value.name}'),
                value: value,
                label: label,
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _openLooks() => pushKitPage<void>(
    context,
    (_) => LiveStylePickerScreen(controller: widget.controller),
  );

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
              final tokens = KitTokens.of(context);
              // Reduced with Animations not Off: the system setting wins.
              final systemStill =
                  KitMotion.reduced(context) &&
                  effects.motion != KitMotionLevel.off;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KitReveal(
                    child: _failed
                        ? Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: tokens.gutter,
                              end: tokens.gutter,
                              bottom: tokens.space3,
                            ),
                            child: KitNotice(
                              tone: AppStatusTone.failure,
                              message: copy.effectsSaveFailed,
                            ),
                          )
                        : null,
                  ),
                  KitRowGroup(
                    label: copy.effectsSection,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(tokens.panelInset),
                        child: KitLiveLookPreview(
                          key: const ValueKey('effects-look-preview'),
                          style: kitLiveStyleById(effects.liveStyle),
                          intensity: effects.liveIntensity,
                          enabled: effects.liveBackground,
                          onTap: _openLooks,
                        ),
                      ),
                      KitArrival(
                        id: 'effects-motion',
                        child: KitRow(
                          key: const ValueKey('effects-motion'),
                          leading: KitRow.icon(
                            context,
                            AppIconography.playCircle,
                          ),
                          title: copy.effectsAnimations,
                          supporting: TextSpan(
                            text: switch (effects.motion) {
                              KitMotionLevel.full => copy.effectsMotionFullHint,
                              KitMotionLevel.calm => copy.effectsMotionCalmHint,
                              KitMotionLevel.off => copy.effectsMotionOffHint,
                            },
                          ),
                          supportingMaxLines: 2,
                          below: Padding(
                            padding: EdgeInsetsDirectional.only(
                              top: tokens.space2,
                              bottom: tokens.space1,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                KitSegmented<KitMotionLevel>(
                                  semanticsLabel: copy.effectsAnimations,
                                  selected: effects.motion,
                                  segments: [
                                    for (final (level, label) in [
                                      (
                                        KitMotionLevel.full,
                                        copy.effectsMotionFull,
                                      ),
                                      (
                                        KitMotionLevel.calm,
                                        copy.effectsMotionCalm,
                                      ),
                                      (
                                        KitMotionLevel.off,
                                        copy.effectsMotionOff,
                                      ),
                                    ])
                                      KitSegment(
                                        key: ValueKey(
                                          'effects-motion-${level.name}',
                                        ),
                                        value: level,
                                        label: label,
                                      ),
                                  ],
                                  onChanged: (level) => _choose(
                                    effects.copyWith(
                                      motion: level,
                                      celebrations:
                                          level == KitMotionLevel.full,
                                    ),
                                  ),
                                ),
                                if (systemStill)
                                  Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      top: tokens.space2,
                                    ),
                                    child: KitText(
                                      copy.effectsMotionSystemOff,
                                      role: KitTextRole.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      KitArrival(
                        id: 'effects-live-background',
                        child: KitSwitchRow(
                          key: const ValueKey('effects-live-background'),
                          switchKey: const ValueKey(
                            'effects-live-background-switch',
                          ),
                          leading: KitRow.icon(context, AppIconography.sparkle),
                          title: copy.effectsLiveBackground,
                          supporting: copy.effectsLiveBackgroundHint,
                          value: effects.liveBackground,
                          onChanged: (on) =>
                              _choose(effects.copyWith(liveBackground: on)),
                        ),
                      ),
                      if (effects.liveBackground)
                        KitArrival(
                          id: 'effects-live-style',
                          child: KitRow(
                            key: const ValueKey('effects-live-style'),
                            leading: KitRow.icon(
                              context,
                              AppIconography.sparkle,
                            ),
                            title: copy.liveStylePickerTitle,
                            supporting: TextSpan(
                              text: kitLiveStyleById(
                                effects.liveStyle,
                              ).label(copy),
                            ),
                            onTap: _openLooks,
                          ),
                        ),
                      if (effects.liveBackground)
                        _glowChoice<KitLiveIntensity>(
                          tokens,
                          id: 'intensity',
                          keyPrefix: 'effects-live',
                          icon: AppIconography.sparkle,
                          title: copy.liveIntensityTitle,
                          selected: effects.liveIntensity,
                          options: [
                            (KitLiveIntensity.subtle, copy.liveIntensitySubtle),
                            (KitLiveIntensity.normal, copy.liveIntensityNormal),
                            (KitLiveIntensity.bold, copy.liveIntensityBold),
                          ],
                          onChanged: (v) =>
                              _choose(effects.copyWith(liveIntensity: v)),
                        ),
                      KitArrival(
                        id: 'effects-glow',
                        child: KitSwitchRow(
                          key: const ValueKey('effects-glow'),
                          switchKey: const ValueKey('effects-glow-switch'),
                          leading: KitRow.icon(context, AppIconography.sparkle),
                          title: copy.effectsActivityGlow,
                          supporting: copy.effectsActivityGlowHint,
                          value: effects.activityGlow,
                          onChanged: (on) =>
                              _choose(effects.copyWith(activityGlow: on)),
                        ),
                      ),
                      // The three options show only while
                      // the border is on.
                      if (effects.activityGlow) ...[
                        _glowChoice<KitGlowStyle>(
                          tokens,
                          id: 'style',
                          icon: AppIconography.sparkle,
                          title: copy.effectsGlowStyle,
                          selected: effects.glowStyle,
                          options: [
                            (
                              KitGlowStyle.classic,
                              copy.effectsGlowStyleClassic,
                            ),
                            (KitGlowStyle.softRing, copy.effectsGlowStyleSoft),
                          ],
                          onChanged: (v) =>
                              _choose(effects.copyWith(glowStyle: v)),
                        ),
                        _glowChoice<KitGlowColours>(
                          tokens,
                          id: 'colours',
                          icon: AppIconography.contrast,
                          title: copy.effectsGlowColours,
                          selected: effects.glowColours,
                          options: [
                            (KitGlowColours.one, copy.effectsGlowColoursOne),
                            (KitGlowColours.two, copy.effectsGlowColoursTwo),
                          ],
                          onChanged: (v) =>
                              _choose(effects.copyWith(glowColours: v)),
                        ),
                        _glowChoice<KitGlowSpeed>(
                          tokens,
                          id: 'speed',
                          icon: AppIconography.speed,
                          title: copy.effectsGlowSpeed,
                          selected: effects.glowSpeed,
                          options: [
                            (KitGlowSpeed.slow, copy.effectsGlowSpeedSlow),
                            (KitGlowSpeed.normal, copy.effectsGlowSpeedNormal),
                            (KitGlowSpeed.fast, copy.effectsGlowSpeedFast),
                          ],
                          onChanged: (v) =>
                              _choose(effects.copyWith(glowSpeed: v)),
                        ),
                      ],
                    ],
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

/// Privacy and local data (`privacy-settings`): read-state sync, the unsent
/// work this device holds on the person's behalf with its size and a way
/// to delete it, and the privacy policy. Durable grants ("Always allowed
/// actions") live under Conversation defaults in the hub: they are about
/// how the agent works, not about privacy.
class PrivacySettingsScreen extends StatefulWidget {
  final ConnectionController controller;
  const PrivacySettingsScreen({super.key, required this.controller});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _busy = false;

  /// What the last delete did, said on the page (KIT-34: no snackbar for a
  /// delete that cannot be undone).
  ({String message, bool ok})? _result;

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

  /// Asks, then clears; true when the person confirmed and it cleared.
  Future<bool> _confirmAndClear({
    required String title,
    required String body,
    required String confirmLabel,
    required String confirmKey,
    required Future<bool> Function() clear,
    required String cleared,
    required String failed,
  }) async {
    final ok = await showKitConfirm(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      icon: AppIconography.delete,
      kind: KitConfirmKind.destructive,
      confirmKey: ValueKey(confirmKey),
    );
    if (!ok || !mounted) return false;
    setState(() {
      _busy = true;
      _result = null;
    });
    final succeeded = await clear();
    if (!mounted) return succeeded;
    setState(() {
      _busy = false;
      _result = (message: succeeded ? cleared : failed, ok: succeeded);
    });
    return succeeded;
  }

  /// Read-state sharing is each server's own consent, kept on this phone: it
  /// is switched on that server's page, not here (G4). This row says where
  /// and how many servers share, and opens the one server or the list.
  Widget _readState(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      _controller,
      _controller.store.appPreferences.readStateConsent,
    ]),
    builder: (context, _) {
      final servers = settingsServers(_controller);
      if (servers.isEmpty) return const SizedBox.shrink();
      final l10n =
          Localizations.of<AppLocalizations>(context, AppLocalizations) ??
          lookupAppLocalizations(const Locale('en'));
      final tokens = KitTokens.of(context);
      final consent = _controller.store.appPreferences.readStateConsent;
      final sharing = servers.where((p) => consent.enabled(p.id)).length;
      final value = servers.length == 1
          ? (sharing == 1 ? l10n.settingsV3On : l10n.settingsV3Off)
          : l10n.settingsV3SharingCount(sharing, servers.length);
      return Padding(
        padding: EdgeInsetsDirectional.only(bottom: tokens.sectionGap),
        child: KitRowGroup(
          label: l10n.privacySharedSection,
          children: [
            KitRow(
              key: const ValueKey('share-session-views'),
              leading: KitRow.icon(context, AppIconography.visible),
              title: l10n.shareSessionViewsTitle,
              trailing: KitRowValue(value),
              onTap: () => servers.length == 1
                  ? unawaited(
                      openServerPage(
                        context,
                        _controller,
                        servers.single.id,
                        arrive: 'server-row-share-read',
                      ),
                    )
                  : unawaited(
                      pushKitPage<void>(
                        context,
                        (_) => ByServerScreen(
                          controller: _controller,
                          kind: ByServerKind.readState,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    final tokens = KitTokens.of(context);
    final scope = SearchScope.of(context, _controller);
    final policy = searchIndex(
      copy,
      scope,
    ).where((entry) => entry.id == 'settings-privacy-data-use').firstOrNull;
    final result = _result;
    return KitScreen(
      topBar: KitTopBar(title: copy.settingsHubPrivacyRow),
      width: KitScreenWidth.reading,
      loading: _busy,
      loadingLabel: copy.privacyDeleting,
      body: ListView(
        key: const ValueKey('privacy-settings'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          if (result != null)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.gutter,
                end: tokens.gutter,
                bottom: tokens.sectionGap,
              ),
              child: KitNotice(
                key: const ValueKey('privacy-clear-result'),
                tone: result.ok ? AppStatusTone.ok : AppStatusTone.failure,
                message: result.message,
                onDismiss: () => setState(() => _result = null),
                dismissLabel: copy.notifyDismiss,
              ),
            ),
          _readState(context),
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
              return KitRowGroup(
                label: copy.e7SettingsUi76,
                children: [
                  KitRow(
                    key: const ValueKey('local-storage-usage'),
                    leading: KitRow.icon(context, AppIconography.database),
                    title: copy.e7SettingsUi77,
                    supporting: TextSpan(
                      text: !queueReadable
                          ? l10n.queueStorageCountUnknown
                          : copy.e7SettingsStorageSummary(
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
                  // Destructive (§2): confirmed first, never primary. With
                  // nothing to delete the row rests, and its own line says
                  // so.
                  _DestructiveRow(
                    rowKey: 'clear-queued-prompts',
                    icon: AppIconography.outbox,
                    title: copy.e7SettingsUi78,
                    subtitle: !queueReadable
                        ? l10n.queueStorageUnreadable
                        : queued == 0
                        ? copy.e7SettingsUi79
                        : copy.e7SettingsQueueDeleteSummary(queued),
                    enabled: (queued > 0 || !queueReadable) && !_busy,
                    onTap: () => _confirmAndClear(
                      title: copy.e7SettingsUi80,
                      body: !queueReadable
                          ? l10n.queueStorageDiscardUnreadable
                          : copy.e7SettingsQueueDeleteBody(queued),
                      // The counted verb (privacy-settings-clear-queued-sheet).
                      confirmLabel: copy.privacyDeleteQueuedCount(
                        queueReadable ? queued : 0,
                      ),
                      confirmKey: 'privacy-clear-queued-confirm',
                      clear: _controller.clearAllQueuedPrompts,
                      cleared: copy.e7SettingsUi81,
                      failed: copy.e7SettingsUi82,
                    ),
                  ),
                  _DestructiveRow(
                    rowKey: 'clear-session-drafts',
                    icon: AppIconography.editNote,
                    title: copy.e7SettingsUi83,
                    subtitle: drafts == 0
                        ? copy.e7SettingsUi84
                        : copy.e7SettingsDraftDeleteSummary(drafts),
                    enabled: drafts > 0 && !_busy,
                    onTap: () => _confirmAndClear(
                      title: copy.e7SettingsUi85,
                      body: copy.e7SettingsDraftDeleteBody(drafts),
                      confirmLabel: copy.privacyDeleteDraftsCount(drafts),
                      confirmKey: 'privacy-clear-drafts-confirm',
                      clear: _controller.clearAllSessionDrafts,
                      cleared: copy.e7SettingsUi86,
                      failed: copy.e7SettingsUi87,
                    ),
                  ),
                ],
              );
            },
          ),
          // The policy itself: About's old Privacy tab lives here now
          // (P3.10), so what the app keeps and what it sends sit together.
          if (policy != null) ...[
            SizedBox(height: tokens.sectionGap),
            KitRowGroup(
              children: [
                KitRow(
                  key: const ValueKey('privacy-policy'),
                  leading: KitRow.icon(context, policy.icon),
                  title: policy.title,
                  supporting: TextSpan(text: copy.e7SettingsUi93),
                  supportingMaxLines: 2,
                  trailing: const KitChevron(),
                  onTap: () => policy.open(context, scope),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A row that deletes something this device holds (design standard §2):
/// the kit's destructive row, always confirmed by its action, never a
/// primary button.
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
    leading: KitRow.icon(context, icon),
    title: title,
    supporting: TextSpan(text: subtitle),
    supportingMaxLines: 2,
    destructive: true,
    enabled: enabled,
    onTap: onTap,
  );
}
