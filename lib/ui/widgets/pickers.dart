import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_chip.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_notice.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';
import 'package:opencode_mobile/ui/kit/kit_progress.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_search_field.dart';
import 'package:opencode_mobile/ui/kit/kit_segmented.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import '../../api/models.dart';
import '../../api/provider_presentation.dart';
import '../../api/product_repository.dart';
import '../../state/connection.dart';
import '../../state/model_library.dart';
import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../app_theme.dart' show AppStatusTone;
import '../screens/library_screen.dart'
    show IntegrationsMode, IntegrationsScreen;

AppLocalizations _pickerStrings(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

/// How applying a model/agent selection is scoped and labeled.
///
/// [classic] keeps the v1 wording ("Use model and mode") — selection is
/// client-side state attached to each prompt. On OpenCode 2 servers the
/// selection is session state instead: [session] labels the apply action
/// "Use for this conversation" (picker opened with an active session), and
/// [newSessions] labels it "Use for new conversations" (no session yet — the
/// choice becomes the default for `POST /api/session`).
enum ModelPickerApplyScope { classic, session, newSessions }

/// A reasoning-effort variant as a person reads it: "Extra high" for
/// `xhigh`, "No thinking" for `none`. Unknown ids are shown as they are.
String presentedEffort(String id, AppLocalizations strings) =>
    switch (id.trim().toLowerCase()) {
      'none' => strings.modelEffortNone,
      'minimal' => strings.modelEffortMinimal,
      'low' => strings.modelEffortLow,
      'medium' => strings.modelEffortMedium,
      'high' => strings.modelEffortHigh,
      'xhigh' => strings.modelEffortExtraHigh,
      'max' => strings.modelEffortMax,
      _ => id,
    };

/// Whether [model] was released in the last 30 days (by the server's
/// catalog date). [now] is for tests.
@visibleForTesting
bool isNewModel(CatalogModel model, {DateTime? now}) {
  final released = model.released;
  if (released == null) return false;
  final age = (now ?? DateTime.now()).difference(released);
  return !age.isNegative && age.inDays < 30;
}

String _applyLabel(AppLocalizations strings, ModelPickerApplyScope scope) =>
    switch (scope) {
      ModelPickerApplyScope.classic => strings.modelPickerUseChosenModel,
      ModelPickerApplyScope.session => strings.e7ModelUiUseSession,
      ModelPickerApplyScope.newSessions => strings.e7ModelUiUseNewSessions,
    };

/// Opens the one model sheet, from every door (the composer chip, `/model`,
/// a chat error, Settings › Model, search): every model to pick from, with
/// the thinking level and the agent pinned in its footer beside "Use for
/// this conversation" (or the scope's wording). With [sessionID] and
/// [ModelPickerApplyScope.session] the choice applies to that session only;
/// otherwise it becomes the default for new conversations (Settings).
/// [focusAgent] opens the sheet with the agent menu open.
Future<void> showModelPicker(
  BuildContext context, {
  ModelPickerApplyScope applyScope = ModelPickerApplyScope.classic,
  String? sessionID,
  bool focusAgent = false,
}) {
  final controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(connProvider);
  // Catalog membership is server-owned and can change while the app remains
  // connected. Refresh on every open so removed models are not retained until
  // a reconnect or lifecycle wake.
  unawaited(controller.refreshCatalog());
  if (sessionID != null && controller.serverOwnsSessionSelection) {
    unawaited(controller.ensureSession(sessionID));
  }
  if (applyScope == ModelPickerApplyScope.classic &&
      controller.serverOwnsSessionSelection) {
    applyScope = ModelPickerApplyScope.newSessions;
  }
  final strings = _pickerStrings(context);
  final apply = _SheetApply();
  final scope = applyScope;
  return showKitSheet<void>(
    context,
    title: strings.modelChooseTitle,
    subtitle: scope == ModelPickerApplyScope.session
        ? strings.modelSessionScopeNote
        : null,
    icon: AppIconography.model,
    height: KitSheetHeight.full,
    loading: apply.applying,
    footer: (_) => ValueListenableBuilder<int>(
      valueListenable: apply.footerTick,
      builder: (footerContext, _, _) =>
          apply.footer?.call(footerContext) ?? const SizedBox.shrink(),
    ),
    // Until the view has built: the scope's wording, or nothing to apply
    // while there is no catalog to choose from.
    primaryListenable: apply.primary
      ..value = controller.catalog?.models.isNotEmpty == true
          ? KitAction(
              key: const Key('model-picker-apply'),
              label: _applyLabel(strings, scope),
              onPressed: apply.run,
            )
          : null,
    body: (sheetContext) => ModelCatalogView._sheet(
      controller: controller,
      apply: apply,
      // Applied: the sheet closes. Not maybePop, which a search field's
      // "back clears the query first" would intercept and keep it open.
      onApplied: () {
        final route = ModalRoute.of(sheetContext);
        if (route != null && route.isCurrent) {
          Navigator.of(sheetContext).pop();
        }
      },
      applyScope: scope,
      sessionID: sessionID,
      focusAgent: focusAgent,
    ),
  ).whenComplete(apply.dispose);
}

/// The sheet's pinned primary runs the view's apply through this; the view
/// reports its in-flight save back as the sheet's loading bar, and draws
/// the pinned footer (thinking level, agent) through [footer].
class _SheetApply {
  final applying = ValueNotifier<bool>(false);

  /// The sheet's pinned primary; its label names what it applies ("Use
  /// Claude Opus 5.5 · Build"), so the view renames it as the draft changes.
  final primary = ValueNotifier<KitAction?>(null);

  /// Bumped after the view builds, so the pinned footer redraws with it.
  final footerTick = ValueNotifier<int>(0);

  /// The view's footer; null while no view is attached.
  WidgetBuilder? footer;
  Future<void> Function()? _handler;
  (String?, String?)? _offered;
  bool _footerQueued = false;

  void run() {
    final handler = _handler;
    if (handler != null) unawaited(handler());
  }

  /// Renames the primary after the frame (called from the view's build);
  /// [blockedBy] says why it cannot apply yet. A null [label] takes the
  /// primary away (no catalog: nothing to apply).
  void offerPrimary(String? label, {String? blockedBy}) {
    final offer = (label, blockedBy);
    if (offer == _offered) return;
    _offered = offer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      primary.value = label == null
          ? null
          : KitAction(
              key: const Key('model-picker-apply'),
              label: label,
              onPressed: blockedBy == null ? run : null,
              disabledReason: blockedBy,
            );
    });
  }

  /// Redraws the footer after the frame (called from the view's build).
  void footerChanged() {
    if (_footerQueued) return;
    _footerQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _footerQueued = false;
      if (_disposed) return;
      footerTick.value++;
    });
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    applying.dispose();
    primary.dispose();
    footerTick.dispose();
  }
}

enum _ModelIntent { all, fast, reasoning, context }

enum _ModelCollection { all, favorites, recent }

/// How many model rows show before "Show more": the sheet body is not
/// virtualised, so a catalog of hundreds of models grows on request.
const _modelPage = 60;

/// The single model, thinking level and agent selector used throughout the
/// app: the body of the model sheet ([showModelPicker]); tests and
/// captures also host it on its own.
///
/// Top to bottom: notices about this catalog (only when they apply), a
/// "Reload providers" row when a signed-in provider is not loaded, then
/// search with its filter menu, All / Favorites / Recent with Refresh, and
/// the models; the chosen one is the checked row, with its details under
/// it. The footer, pinned with the apply action, holds the thinking level
/// and the agent as two chips that each open a menu (no dialog over the
/// sheet). With a bounded height the list scrolls and the footer and apply
/// action are pinned under it; inside the sheet the sheet pins them.
class ModelCatalogView extends StatefulWidget {
  const ModelCatalogView({
    super.key,
    required this.controller,
    this.scrollController,
    this.onApplied,
    this.onClose,
    this.showHeader = true,
    this.applyScope = ModelPickerApplyScope.classic,
    this.sessionID,
    this.focusAgent = false,
  }) : _apply = null;

  const ModelCatalogView._sheet({
    required this.controller,
    required _SheetApply apply,
    this.onApplied,
    this.applyScope = ModelPickerApplyScope.classic,
    this.sessionID,
    this.focusAgent = false,
  }) : _apply = apply,
       scrollController = null,
       onClose = null,
       showHeader = false;

  final ConnectionController controller;
  final ScrollController? scrollController;
  final VoidCallback? onApplied;
  final VoidCallback? onClose;
  final bool showHeader;
  final ModelPickerApplyScope applyScope;
  final String? sessionID;

  /// Opens with the agent choice unfolded.
  final bool focusAgent;

  final _SheetApply? _apply;

  @override
  State<ModelCatalogView> createState() => _ModelCatalogViewState();
}

class _ModelCatalogViewState extends State<ModelCatalogView> {
  AppLocalizations get _strings => _pickerStrings(context);

  final _search = TextEditingController();
  String _query = '';
  String _provider = '*';
  _ModelIntent _intent = _ModelIntent.all;
  _ModelCollection _collection = _ModelCollection.all;
  int _visible = _modelPage;
  ModelRef? _draftModel;
  String _draftVariant = '';
  bool _applying = false;
  String? _saveError;
  ModelRef? _observedModel;
  String _observedVariant = '';
  String _draftAgent = '';
  String _observedAgent = '';

  /// [ModelCatalogView.focusAgent]: the agent menu opens once, as soon as
  /// the catalog has agents to offer.
  late bool _agentPending = widget.focusAgent;
  String? _scopeProfile;
  int _scopeLocation = 0;

  bool get _sameScope =>
      widget.controller.profile?.id == _scopeProfile &&
      widget.controller.locationRevision == _scopeLocation;

  ScrollController? _ownedScroll;

  ScrollController get _listScroll =>
      widget.scrollController ?? (_ownedScroll ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _scopeProfile = widget.controller.profile?.id;
    _scopeLocation = widget.controller.locationRevision;
    _syncDraft();
    _observedModel = _currentModel;
    _observedVariant = _currentVariant;
    _observedAgent = _currentAgent;
    widget.controller.addListener(_selectionChanged);
    widget._apply?._handler = _applyDraft;
    widget._apply?.footer = _footer;
  }

  @override
  void didUpdateWidget(covariant ModelCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._apply != widget._apply) {
      oldWidget._apply?._handler = null;
      oldWidget._apply?.footer = null;
      widget._apply?._handler = _applyDraft;
      widget._apply?.footer = _footer;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_selectionChanged);
      widget.controller.addListener(_selectionChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.sessionID != widget.sessionID ||
        oldWidget.applyScope != widget.applyScope) {
      _scopeProfile = widget.controller.profile?.id;
      _scopeLocation = widget.controller.locationRevision;
      _syncDraft();
      _observedModel = _currentModel;
      _observedVariant = _currentVariant;
      _observedAgent = _currentAgent;
    }
  }

  /// The session this picker edits, when the apply scope is per-session.
  String? get _scopedSessionID =>
      widget.applyScope == ModelPickerApplyScope.session
      ? widget.sessionID
      : null;

  ModelRef? get _currentModel => _scopedSessionID == null
      ? widget.controller.selectedModel
      : widget.controller.modelForSession(_scopedSessionID!);

  String get _currentVariant => _scopedSessionID == null
      ? widget.controller.selectedVariant
      : widget.controller.variantForSession(_scopedSessionID!);

  String get _currentAgent => _scopedSessionID == null
      ? widget.controller.selectedAgent
      : widget.controller.agentForSession(_scopedSessionID!);

  /// A save for this session is in flight elsewhere.
  bool get _sessionSaving =>
      _scopedSessionID != null &&
      widget.controller.sessionSelectionSaving(_scopedSessionID!);

  /// Why the choice cannot change now; null when it can.
  String? get _lockedReason => !_sameScope
      ? _strings.modelScopeChanged
      : _applying || _sessionSaving
      ? _strings.modelSelectionSaving
      : null;

  void _syncDraft() {
    _draftAgent = _currentAgent;
    final sessionID = _scopedSessionID;
    if (sessionID != null) {
      _draftModel = widget.controller.modelForSession(sessionID);
      _draftVariant = widget.controller.variantForSession(sessionID);
    } else {
      _draftModel = widget.controller.selectedModel;
      _draftVariant = widget.controller.selectedVariant;
    }
  }

  void _selectionChanged() {
    if (!mounted) return;
    final untouched =
        _draftModel?.wireName == _observedModel?.wireName &&
        _draftVariant == _observedVariant &&
        _draftAgent == _observedAgent;
    _observedModel = _currentModel;
    _observedVariant = _currentVariant;
    _observedAgent = _currentAgent;
    if (untouched && !_applying) setState(_syncDraft);
  }

  @override
  void dispose() {
    if (widget._apply?._handler == _applyDraft) {
      widget._apply?._handler = null;
      widget._apply?.footer = null;
    }
    widget.controller.removeListener(_selectionChanged);
    _ownedScroll?.dispose();
    _search.dispose();
    super.dispose();
  }

  void _setApplying(bool value) {
    _applying = value;
    // The sheet disposes its notifiers when it closes, while this body can
    // still be finishing a save during the exit transition.
    final apply = widget._apply;
    if (apply != null && !apply._disposed) apply.applying.value = value;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final tokens = KitTokens.of(context);
        final catalog = widget.controller.catalog;
        final drafted = catalog == null ? null : _draftedModel(catalog);
        final items = _items(context, catalog, drafted);
        final inSheet = widget._apply != null;
        widget._apply
          ?..offerPrimary(
            catalog == null || catalog.models.isEmpty
                ? null
                : _applyText(drafted),
            blockedBy: _applying ? null : _applyBlockedBy(drafted),
          )
          ..footerChanged();
        final apply = inSheet ? null : _applyBlock(context, drafted);
        if (!constraints.hasBoundedHeight) {
          // Inside a scrolling host (the sheet): the host scrolls.
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items) item,
              if (apply != null) ...[SizedBox(height: tokens.space3), apply],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                controller: _listScroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsetsDirectional.fromSTEB(
                  tokens.gutter,
                  tokens.space2,
                  tokens.gutter,
                  tokens.space4,
                ),
                children: items,
              ),
            ),
            if (apply != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    tokens.gutter,
                    tokens.space2,
                    tokens.gutter,
                    tokens.space3,
                  ),
                  child: apply,
                ),
              ),
          ],
        );
      },
    ),
  );

  CatalogModel? _draftedModel(CatalogSnapshot catalog) {
    final draft = _draftModel;
    if (draft == null) return null;
    for (final model in catalog.models) {
      if (ModelLibrary.sameModel(
        draft,
        ModelRef(providerID: model.providerID, modelID: model.id),
      )) {
        return model.enabled ? model : null;
      }
    }
    return null;
  }

  /// Everything above the pinned action, top to bottom.
  List<Widget> _items(
    BuildContext context,
    CatalogSnapshot? catalog,
    CatalogModel? drafted,
  ) {
    final tokens = KitTokens.of(context);
    final gap = SizedBox(height: tokens.space3);
    final controller = widget.controller;
    final current = _currentModel;
    final notices = <Widget>[
      if (!_sameScope)
        KitNotice(
          key: const Key('model-picker-scope-changed'),
          icon: AppIconography.info,
          message: _strings.modelScopeChanged,
        ),
      // Only a loaded catalog can say a model is missing from it.
      if (current != null &&
          catalog != null &&
          catalog.models.isNotEmpty &&
          !controller.modelAvailable(current))
        KitNotice(
          key: const Key('model-picker-current-unavailable'),
          icon: AppIconography.warning,
          title: current.wireName,
          message: _strings.modelUnavailableSelection,
        ),
      if (_saveError case final error?)
        KitNotice(
          key: const Key('model-picker-save-error'),
          tone: AppStatusTone.failure,
          message: error,
        ),
      if (catalog != null) ..._catalogNotices(context, catalog),
    ];
    return [
      if (widget.showHeader) ...[_header(context), gap],
      for (final notice in notices) ...[notice, gap],
      if (catalog == null)
        _catalogState()
      else if (catalog.models.isEmpty)
        _noModels(context)
      else
        ..._modelSection(context, catalog),
    ];
  }

  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: KitText(_strings.modelChooseTitle, role: KitTextRole.headline),
        ),
      ),
      if (widget.onClose case final close?)
        KitIconButton(
          icon: AppIconography.close,
          tooltip: _strings.e7ModelUiClose,
          onPressed: close,
        ),
    ],
  );

  /// Notices about the catalog itself, each only when it applies.
  List<Widget> _catalogNotices(BuildContext context, CatalogSnapshot catalog) {
    final controller = widget.controller;
    final unloaded = controller.unloadedProviderIDs;
    // A basic catalog is worth saying only when the rows really lack their
    // details; a notice over rows that show "200K context" contradicts them.
    final detailsMissing =
        !controller.catalogDetailed &&
        catalog.models.isNotEmpty &&
        catalog.models.every(
          (model) => model.contextLimit <= 0 && model.cost == null,
        );
    return [
      // A row, not a notice or a dialog: what is wrong and the one fix, in
      // the sheet itself.
      if (unloaded.isNotEmpty)
        KitRowGroup(
          key: const ValueKey('picker-unloaded-providers'),
          margin: EdgeInsets.zero,
          children: [
            KitRow(
              key: const ValueKey('picker-reload-providers'),
              leading: KitRow.icon(context, AppIconography.retry),
              title: _strings.modelChoiceReloadProviders,
              supporting: TextSpan(
                text: unloadedProvidersNotice(
                  unloaded
                      .map((id) => presentedProviderName(id, catalog.providers))
                      .toList(),
                  strings: _strings,
                  unusable: controller.unloadedProvidersUnusable,
                  waitingOnReplies: controller.providerReloadWaitingOn,
                ),
              ),
              supportingMaxLines: 4,
              enabled: !controller.catalogLoading,
              disabledReason: controller.catalogLoading
                  ? _strings.e7ModelUiLoading
                  : null,
              onTap: () => unawaited(controller.reloadProviderRuntime()),
            ),
          ],
        ),
      if (detailsMissing)
        KitNotice(
          key: const Key('model-picker-basic-catalog'),
          icon: AppIconography.info,
          message: _strings.e7ModelUiBasicCatalog,
        ),
    ];
  }

  Widget _catalogState() {
    final controller = widget.controller;
    if (controller.catalogError case final error?) {
      return KitStateView.error(
        title: _strings.e7ModelUiLoadFailed,
        details: error,
        size: KitStateSize.inline,
        retry: KitAction(
          label: _strings.e7ModelUiRetry,
          icon: AppIconography.retry,
          working: controller.catalogLoading,
          onPressed: controller.refreshCatalog,
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      label: _strings.e7ModelUiLoading,
      child: const KitSkeletonRows(count: 6),
    );
  }

  // --- Footer: thinking and agent ----------------------------------------

  /// What the chosen model can do, its output limit and prices, in words,
  /// under its checked row. The context window is already on the row's
  /// supporting line, and the id is in the row's menu (Copy model ID).
  Widget? _draftDetails(BuildContext context, CatalogModel model) {
    final cost = model.cost;
    final lines = <String>[
      if (model.outputLimit > 0)
        _strings.modelPickerDetailsOutput(_number(model.outputLimit)),
      if (model.reasoning) _strings.modelPickerCanThink,
      if (model.tools) _strings.modelPickerCanUseTools,
      if (model.attachments) _strings.modelPickerCanReadAttachments,
      if (cost != null &&
          (cost.inputPerMillion > 0 || cost.outputPerMillion > 0))
        _strings.modelPickerDetailsPrice(
          _money(cost.inputPerMillion),
          _money(cost.outputPerMillion),
        ),
    ];
    if (lines.isEmpty) return null;
    return KitText(
      lines.join(' · '),
      key: const Key('model-picker-details'),
      role: KitTextRole.secondary,
      tone: KitTextTone.secondary,
    );
  }

  /// A server agent in words: the built-in ones say what they do, others
  /// use the server's description, then their mode.
  String _agentSupporting(CatalogAgent agent) {
    final description = agent.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    return switch (agent.id) {
      'build' => _strings.modelPickerAgentBuild,
      'plan' => _strings.modelPickerAgentPlan,
      _ => [
        if (agent.mode != 'unknown') agent.mode,
        if (agent.model?.isNotEmpty == true) agent.model!,
      ].join(' · '),
    };
  }

  /// The built-in agents by name ("Build", "Plan"); any other agent by the
  /// id its server gave it.
  String _agentTitle(String id) => switch (id) {
    'build' => _strings.modelPickerAgentBuildName,
    'plan' => _strings.modelPickerAgentPlanName,
    _ => id,
  };

  /// What sits pinned with the apply action: the thinking level and the
  /// agent, each a chip that opens its menu. A chip that has nothing to
  /// choose is left out (a model with one level, a server without agents).
  Widget _footer(BuildContext context) {
    final catalog = widget.controller.catalog;
    if (catalog == null || catalog.models.isEmpty) {
      return const SizedBox.shrink();
    }
    final drafted = _draftedModel(catalog);
    final variants =
        drafted?.variants.where((variant) => !variant.disabled).toList() ??
        const <CatalogVariant>[];
    final agents = _choosableAgents(catalog);
    CatalogVariant? chosenVariant;
    for (final variant in variants) {
      if (variant.id == _draftVariant) chosenVariant = variant;
    }
    final chips = <Widget>[
      if (drafted != null && variants.isNotEmpty)
        Builder(
          builder: (chipContext) => KitChip.summary(
            key: const Key('model-picker-thinking'),
            icon: AppIconography.idea,
            label: _strings.modelPickerThinkingChip(
              chosenVariant == null
                  ? _strings.e7ModelUiDefault
                  : _variantLabel(chosenVariant),
            ),
            expanded: false,
            onPressed: () =>
                unawaited(_chooseThinking(chipContext, drafted, variants)),
          ),
        ),
      if (agents.isNotEmpty)
        Builder(
          builder: (chipContext) {
            if (_agentPending) {
              _agentPending = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && chipContext.mounted) {
                  unawaited(_chooseAgent(chipContext));
                }
              });
            }
            return KitChip.summary(
              key: const Key('model-picker-agent'),
              icon: AppIconography.agent,
              label: _strings.modelPickerAgentChip(
                _draftAgent.isEmpty
                    ? _strings.e7ModelUiServerDefault
                    : _agentTitle(_draftAgent),
              ),
              expanded: false,
              onPressed: () => unawaited(_chooseAgent(chipContext)),
            );
          },
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: KitTokens.of(context).space2),
      child: KitChipWrap(
        key: const Key('model-picker-footer'),
        children: chips,
      ),
    );
  }

  /// The agents a person picks from: primary ones the server does not hide.
  List<CatalogAgent> _choosableAgents(CatalogSnapshot catalog) => catalog.agents
      .where((agent) => !agent.hidden && agent.mode != 'subagent')
      .toList();

  Future<void> _chooseThinking(
    BuildContext anchor,
    CatalogModel model,
    List<CatalogVariant> variants,
  ) async {
    final locked = _lockedReason;
    final known = variants.any((variant) => variant.id == _draftVariant);
    await showKitMenu(
      anchor,
      semanticsLabel: _strings.modelPickerThinking,
      items: [
        KitMenuItem(
          key: ValueKey('model-variant-${model.id}-default'),
          label: _strings.e7ModelUiDefault,
          checked: !known,
          enabled: locked == null,
          disabledReason: locked,
          onSelected: () => _setVariant(model, ''),
        ),
        for (final variant in variants)
          KitMenuItem(
            key: ValueKey('model-variant-${model.id}-${variant.id}'),
            label: _variantLabel(variant),
            checked: variant.id == _draftVariant,
            enabled: locked == null,
            disabledReason: locked,
            onSelected: () => _setVariant(model, variant.id),
          ),
      ],
    );
  }

  /// A level chosen from the menu belongs to the model the menu listed:
  /// if the draft moved on while it was open (another screen chose a
  /// model), the pick brings the draft back to that model rather than
  /// giving its level to a model that may not have it.
  void _setVariant(CatalogModel model, String value) {
    if (!mounted) return;
    setState(() {
      _draftModel = ModelRef(providerID: model.providerID, modelID: model.id);
      _draftVariant = value;
      _saveError = null;
    });
  }

  Future<void> _chooseAgent(BuildContext anchor) async {
    final catalog = widget.controller.catalog;
    if (catalog == null) return;
    final agents = _choosableAgents(catalog);
    if (agents.isEmpty) return;
    final selected = _draftAgent;
    final unavailable =
        selected.isNotEmpty && !agents.any((agent) => agent.id == selected);
    final locked = _lockedReason;
    await showKitMenu(
      anchor,
      semanticsLabel: _strings.e7ModelUiAgent,
      items: [
        if (unavailable)
          KitMenuItem(
            label: _agentTitle(selected),
            checked: true,
            enabled: false,
            disabledReason: _strings.modelPickerUnavailableReason,
            onSelected: () {},
          ),
        for (final agent in agents)
          KitMenuItem(
            key: ValueKey('model-picker-agent-${agent.id}'),
            label: _agentTitle(agent.id),
            supporting: _agentSupporting(agent),
            checked: agent.id == selected,
            enabled: locked == null,
            disabledReason: locked,
            onSelected: () {
              if (!mounted) return;
              setState(() {
                _draftAgent = agent.id;
                _saveError = null;
              });
            },
          ),
      ],
    );
  }

  // --- Models --------------------------------------------------------------

  List<CatalogModel> _filteredModels(CatalogSnapshot catalog) {
    final normalized = _query.trim().toLowerCase();
    final library = widget.controller.modelLibrary;
    final saved = switch (_collection) {
      _ModelCollection.all => null,
      _ModelCollection.favorites => library.favorites,
      _ModelCollection.recent => library.recent,
    };
    final models = presentModels(catalog.models, selected: _currentModel).where(
      (model) {
        final reference = ModelRef(
          providerID: model.providerID,
          modelID: model.id,
        );
        final providerName = presentedProviderName(
          model.providerID,
          catalog.providers,
        );
        return (saved == null ||
                (model.enabled &&
                    saved.any(
                      (ref) => ModelLibrary.sameModel(ref, reference),
                    ))) &&
            (_provider == '*' ||
                presentProvider(model.providerID).groupID == _provider) &&
            (normalized.isEmpty ||
                model.name.toLowerCase().contains(normalized) ||
                model.id.toLowerCase().contains(normalized) ||
                model.providerID.toLowerCase().contains(normalized) ||
                providerName.toLowerCase().contains(normalized)) &&
            switch (_intent) {
              _ModelIntent.all || _ModelIntent.context => true,
              // OpenCode 2 lists a fast mode as a model of its own
              // ("Claude Opus 5.5 Fast", `gpt-6-sol-fast`), not as a
              // variant.
              _ModelIntent.fast =>
                model.id.toLowerCase().endsWith('-fast') ||
                    model.variants.any((v) => !v.disabled && v.isFast),
              _ModelIntent.reasoning => model.reasoning,
            };
      },
    ).toList();
    if (_intent == _ModelIntent.context) {
      models.sort((a, b) => b.contextLimit.compareTo(a.contextLimit));
    } else if (saved != null) {
      int rank(CatalogModel model) => saved.indexWhere(
        (ref) => ModelLibrary.sameModel(
          ref,
          ModelRef(providerID: model.providerID, modelID: model.id),
        ),
      );
      models.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    return models;
  }

  String _intentLabel(_ModelIntent intent) => switch (intent) {
    _ModelIntent.all => _strings.e7ModelUiAnyCapability,
    _ModelIntent.fast => _strings.e7ModelUiFastModes,
    _ModelIntent.reasoning => _strings.e7ModelUiReasoning,
    _ModelIntent.context => _strings.e7ModelUiLargestContext,
  };

  void _resetFilters() => setState(() {
    _search.clear();
    _query = '';
    _provider = '*';
    _intent = _ModelIntent.all;
    _collection = _ModelCollection.all;
    _visible = _modelPage;
  });

  List<Widget> _modelSection(BuildContext context, CatalogSnapshot catalog) {
    final tokens = KitTokens.of(context);
    final gap = SizedBox(height: tokens.space3);
    final controller = widget.controller;
    final models = _filteredModels(catalog);
    final providers = presentProviders(catalog.providers);
    final filtered =
        _query.trim().isNotEmpty ||
        _provider != '*' ||
        _intent != _ModelIntent.all;
    String? providerName;
    for (final provider in providers) {
      if (provider.id == _provider) providerName = provider.name;
    }
    final activeFilter = [
      ?providerName,
      if (_intent != _ModelIntent.all) _intentLabel(_intent),
    ].join(' · ');
    final shown = models.take(_visible).toList();
    return [
      // Search with its filter menu, and Refresh for the catalog beside it.
      Row(
        children: [
          Expanded(
            child: KitSearchField(
              label: _strings.modelSearchHint,
              controller: _search,
              fieldKey: const Key('model-picker-search'),
              clearKey: const Key('model-picker-search-clear'),
              filterKey: const Key('model-picker-filters'),
              resultCount: _query.trim().isEmpty ? null : models.length,
              onChanged: (value) => setState(() {
                _query = value;
                _visible = _modelPage;
              }),
              filters: [
                for (final intent in _ModelIntent.values)
                  KitMenuItem(
                    key: ValueKey('model-intent-${intent.name}'),
                    label: _intentLabel(intent),
                    group: 'intent',
                    checked: _intent == intent,
                    onSelected: () => setState(() {
                      _intent = intent;
                      _visible = _modelPage;
                    }),
                  ),
                KitMenuItem(
                  key: const ValueKey('model-provider-*'),
                  label: _strings.e7ModelUiAllProviders,
                  group: 'provider',
                  checked: _provider == '*',
                  onSelected: () => setState(() => _provider = '*'),
                ),
                for (final provider in providers)
                  KitMenuItem(
                    key: ValueKey('model-provider-${provider.id}'),
                    label: provider.name,
                    group: 'provider',
                    checked: _provider == provider.id,
                    onSelected: () => setState(() {
                      _provider = provider.id;
                      _visible = _modelPage;
                    }),
                  ),
              ],
              activeFilter: activeFilter.isEmpty ? null : activeFilter,
              onClearFilter: () => setState(() {
                _provider = '*';
                _intent = _ModelIntent.all;
              }),
            ),
          ),
          SizedBox(width: tokens.space2),
          KitIconButton(
            key: const Key('model-picker-refresh'),
            icon: AppIconography.retry,
            tooltip: _strings.e7ModelUiRefresh,
            working: controller.catalogLoading,
            onPressed: controller.catalogLoading
                ? null
                : controller.refreshCatalog,
          ),
        ],
      ),
      gap,
      _collections(),
      gap,
      if (models.isEmpty)
        _noMatch(filtered)
      else
        KitRowGroup(
          key: const Key('model-picker-list'),
          margin: EdgeInsets.zero,
          children: [
            for (final model in shown)
              _modelRow(
                context,
                model,
                presentedProviderName(model.providerID, catalog.providers),
              ),
            if (models.length > shown.length)
              KitRow(
                key: const Key('model-picker-more'),
                leading: KitRow.icon(context, AppIconography.unfoldMore),
                title: _strings.modelPickerShowMore(
                  models.length - shown.length,
                ),
                onTap: () => setState(() => _visible += _modelPage),
              ),
          ],
        ),
    ];
  }

  /// All / Favorites / Recent.
  Widget _collections() => KitSegmented<_ModelCollection>(
    semanticsLabel: _strings.modelPickerCollections,
    selected: _collection,
    onChanged: (value) => setState(() {
      _collection = value;
      _visible = _modelPage;
    }),
    segments: [
      KitSegment(
        key: const ValueKey('model-collection-all'),
        value: _ModelCollection.all,
        label: _strings.modelAll,
      ),
      KitSegment(
        key: const ValueKey('model-collection-favorites'),
        value: _ModelCollection.favorites,
        label: _strings.modelFavorites,
      ),
      KitSegment(
        key: const ValueKey('model-collection-recent'),
        value: _ModelCollection.recent,
        label: _strings.modelRecent,
      ),
    ],
  );

  /// The server has no model at all: the next step is signing in to a
  /// provider, which lives on the Providers screen.
  Widget _noModels(BuildContext context) {
    final controller = widget.controller;
    return KitStateView(
      key: const Key('model-picker-no-models'),
      icon: AppIconography.login,
      size: KitStateSize.inline,
      title: _strings.modelPickerSignInTitle,
      body: _strings.modelPickerSignInBody,
      primary: controller.isIsolated
          ? null
          : KitAction(
              key: const Key('model-picker-open-providers'),
              label: _strings.chatUiOpenProviders,
              onPressed: () => unawaited(
                pushKitPage<void>(
                  context,
                  (_) => IntegrationsScreen(
                    controller: controller,
                    mode: IntegrationsMode.providers,
                  ),
                ),
              ),
            ),
      secondary: KitAction(
        label: _strings.e7ModelUiRefresh,
        icon: AppIconography.retry,
        working: controller.catalogLoading,
        onPressed: controller.refreshCatalog,
      ),
    );
  }

  Widget _noMatch(bool filtered) {
    if (_query.trim().isNotEmpty) {
      return KitSearchNoMatch(
        query: _query.trim(),
        onClear: _resetFilters,
        action: filtered && (_provider != '*' || _intent != _ModelIntent.all)
            ? KitAction(
                label: _strings.e7ModelUiClearFilters,
                onPressed: _resetFilters,
              )
            : null,
      );
    }
    final favorites = !filtered && _collection == _ModelCollection.favorites;
    final recent = !filtered && _collection == _ModelCollection.recent;
    return KitStateView(
      key: const Key('model-picker-empty'),
      icon: favorites
          ? AppIconography.star
          : recent
          ? AppIconography.history
          : AppIconography.search,
      size: KitStateSize.inline,
      title: favorites
          ? _strings.e7ModelUiFavoritesEmpty
          : recent
          ? _strings.e7ModelUiRecentEmpty
          : _strings.e7ModelUiNoMatches,
      body: favorites
          ? _strings.e7ModelUiFavoritesHint
          : recent
          ? _strings.e7ModelUiRecentHint
          : _intent == _ModelIntent.fast
          ? _strings.e7ModelUiNoFastModes
          : _strings.e7ModelUiNoMatchesHint,
      primary: KitAction(
        label: filtered
            ? _strings.e7ModelUiClearFilters
            : _strings.e7ModelUiBrowseAll,
        onPressed: _resetFilters,
      ),
    );
  }

  Widget _modelRow(
    BuildContext context,
    CatalogModel model,
    String providerName,
  ) {
    final reference = ModelRef(providerID: model.providerID, modelID: model.id);
    final current = ModelLibrary.sameModel(_currentModel, reference);
    final draft = ModelLibrary.sameModel(_draftModel, reference);
    final favorite = widget.controller.modelLibrary.isFavorite(reference);
    final favoriteLabel = favorite
        ? _strings.e7ModelUiUnfavorite(model.name)
        : _strings.e7ModelUiFavorite(model.name);
    return KitRow(
      key: ValueKey('model-option-${model.providerID}-${model.id}'),
      titleKey: ValueKey('model-name-${model.providerID}-${model.id}'),
      leading: KitRowIcon(
        draft ? AppIconography.check : AppIconography.model,
        current: draft,
      ),
      title: model.name,
      titleMaxLines: 2,
      supportingMaxLines: 2,
      supporting: TextSpan(
        text: [
          // Words, not colour: the one in use, and a release from the last
          // month (Opus 5.5, GPT-6 Sol) found without knowing its name.
          if (current) _strings.modelPickerInUse,
          if (isNewModel(model)) _strings.modelNewBadge,
          providerName,
          if (model.contextLimit > 0)
            _strings.e7ModelUiContext(_compactNumber(model.contextLimit)),
          if (model.deprecated)
            _strings.e7ModelUiDeprecated
          else if (model.preview)
            _strings.e7ModelUiPreview,
        ].join(' · '),
      ),
      selected: draft,
      below: draft ? _draftDetails(context, model) : null,
      enabled: model.enabled,
      disabledReason: model.enabled
          ? null
          : _strings.modelPickerUnavailableReason,
      onTap: model.enabled ? () => _draft(reference) : null,
      trailing: model.enabled
          ? KitIconButton(
              key: ValueKey('model-favorite-${model.providerID}-${model.id}'),
              icon: favorite ? AppIconography.starFilled : AppIconography.star,
              tooltip: favoriteLabel,
              selected: favorite,
              onPressed: () => _toggleFavorite(reference),
            )
          : null,
      menu: [
        if (model.enabled)
          KitMenuItem(
            label: favoriteLabel,
            icon: favorite ? AppIconography.starFilled : AppIconography.star,
            onSelected: () => _toggleFavorite(reference),
          ),
        KitMenuItem.copy(
          label: _strings.modelPickerCopyId,
          text: () => '${model.providerID}/${model.id}',
        ),
      ],
    );
  }

  // 1,048,576 reads "1M", not "1.0M"; 1,050,000 too.
  static String _compactNumber(int value) => value >= 1000000
      ? '${(value / 1000000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}M'
      : value >= 1000
      ? '${(value / 1000).round()}K'
      : '$value';

  static String _money(double value) => value >= 1
      ? '\$${value.toStringAsFixed(2)}'
      : '\$${value.toStringAsFixed(3)}';

  void _draft(ModelRef model) => setState(() {
    _saveError = null;
    _draftModel = model;
    _draftVariant = ModelLibrary.sameModel(model, _currentModel)
        ? _currentVariant
        : '';
  });

  Future<void> _toggleFavorite(ModelRef model) async {
    try {
      await widget.controller.toggleModelFavorite(model);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = _strings.e7ModelUiFavoritesFailed);
      }
    }
  }

  /// What the apply action says: with the classic scope it names the model
  /// and agent it applies ("Use Claude Opus 5.5 · Build"); the OpenCode 2
  /// scopes name where it applies ("Use for this conversation").
  String _applyText(CatalogModel? drafted) {
    if (widget.applyScope != ModelPickerApplyScope.classic || drafted == null) {
      return _applyLabel(_strings, widget.applyScope);
    }
    final agent = _draftAgent;
    return agent.isEmpty
        ? _strings.modelPickerUseModel(drafted.name)
        : _strings.e7ModelUiUseModelMode(drafted.name, _agentTitle(agent));
  }

  /// Why the apply action cannot run yet; null when it can.
  String? _applyBlockedBy(CatalogModel? drafted) =>
      drafted == null ? _strings.modelPickerChooseFirst : _lockedReason;

  /// The footer and apply action for a view that pins its own (hosted on
  /// its own); inside the sheet the sheet pins them.
  Widget _applyBlock(BuildContext context, CatalogModel? drafted) {
    final reason = _applyBlockedBy(drafted);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _footer(context),
        KitActionBlock(
          key: const Key('model-picker-apply-bar'),
          primary: KitAction(
            key: drafted == null
                ? const Key('model-picker-apply')
                : ValueKey('use-model-${drafted.providerID}-${drafted.id}'),
            label: _applyText(drafted),
            working: _applying,
            onPressed: reason == null || _applying ? _applyDraft : null,
            disabledReason: _applying ? null : reason,
          ),
        ),
      ],
    );
  }

  Future<void> _applyDraft() async {
    final model = _draftModel;
    if (_applying || !_sameScope) return;
    final catalog = widget.controller.catalog;
    if (model == null || catalog == null || _draftedModel(catalog) == null) {
      setState(() => _saveError = _strings.modelPickerChooseFirst);
      return;
    }
    final variant = _draftVariant;
    final agent = _draftAgent;
    setState(() {
      _setApplying(true);
      _saveError = null;
    });
    var modelConfirmed = false;
    try {
      final sessionID = _scopedSessionID;
      if (sessionID != null) {
        await widget.controller.selectModelForSession(
          sessionID,
          model,
          variant: variant,
        );
      } else {
        await widget.controller.selectModel(model, variant: variant);
      }
      if (!_sameScope) return;
      if (!ModelLibrary.sameModel(_currentModel, model) ||
          _currentVariant != variant) {
        if (mounted) {
          setState(() => _saveError = _strings.e7ModelUiSelectionGone);
        }
        return;
      }
      modelConfirmed = true;
      if (agent.isNotEmpty && agent != _currentAgent) {
        if (sessionID != null) {
          await widget.controller.selectAgentForSession(sessionID, agent);
        } else {
          await widget.controller.selectAgent(agent);
        }
        if (!mounted || !_sameScope) return;
        if (_currentAgent != agent) {
          setState(() => _saveError = _strings.modelChoicePartialSaveError);
          return;
        }
      }
      if (!mounted) return;
      widget.onApplied?.call();
      if (mounted && widget.onApplied == null) setState(_syncDraft);
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = modelConfirmed
              ? _strings.modelChoicePartialSaveError
              : _strings.modelChoiceModelSaveError,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _setApplying(false));
      } else {
        _applying = false;
      }
    }
  }

  String _variantLabel(CatalogVariant variant) {
    final effort = variant.reasoningEffort;
    if (effort == null || variant.id.toLowerCase() == effort.toLowerCase()) {
      return presentedEffort(variant.id, _strings);
    }
    // Inside a phrase ("fast · low effort") the level stays lower case.
    return _strings.e7ModelUiEffort(
      presentedEffort(variant.id, _strings),
      presentedEffort(effort, _strings).toLowerCase(),
    );
  }

  String _number(int value) =>
      NumberFormat.decimalPattern(_strings.localeName).format(value);
}

/// Copy for the picker notice about providers the server has signed in to
/// but not loaded; [names] are already presented for display. [unusable]
/// says a reload already ran and could not load them; [waitingOnReplies]
/// counts running replies a reload is waiting for.
String unloadedProvidersNotice(
  List<String> names, {
  AppLocalizations? strings,
  bool unusable = false,
  int waitingOnReplies = 0,
}) {
  final l10n = strings ?? lookupAppLocalizations(const Locale('en'));
  final sorted = [...names]..sort();
  final list = switch (sorted.length) {
    0 => l10n.e7ModelUiProviderFallback,
    1 => sorted.single,
    2 => l10n.e7ModelUiProviderPair(sorted[0], sorted[1]),
    _ => l10n.e7ModelUiProviderMany(
      sorted.sublist(0, sorted.length - 1).join(l10n.e7ModelUiListSeparator),
      sorted.last,
    ),
  };
  final count = sorted.length > 1 ? sorted.length : 1;
  final state = unusable
      ? l10n.e7ModelUiUnusableProviders(count, list)
      : l10n.e7ModelUiUnloadedProviders(count, list);
  if (waitingOnReplies <= 0) return state;
  return '$state ${l10n.e7ModelUiProviderReloadWaits(waitingOnReplies)}';
}

/// "\$3.00 in · \$15.00 out /1M" for a model with published pricing; null when
/// the catalog carries no cost.
String? modelCostLabel(CatalogModel model, {AppLocalizations? strings}) {
  final cost = model.cost;
  if (cost == null) return null;
  final input = cost.inputPerMillion;
  final output = cost.outputPerMillion;
  if (input <= 0 && output <= 0) return null;
  String money(double value) => value >= 1
      ? '\$${value.toStringAsFixed(2)}'
      : '\$${value.toStringAsFixed(3)}';
  return (strings ?? lookupAppLocalizations(const Locale('en'))).e7ModelUiCost(
    money(input),
    money(output),
  );
}
