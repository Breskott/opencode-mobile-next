import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'presentation.dart';

import 'audio.dart';
import 'device.dart';
import 'model_manager.dart';
import 'model_manifest.dart';
import '../ui/app_theme.dart';
import '../ui/kit/kit.dart';
import '../platform/platform_capabilities.dart';
import '../l10n/app_localizations.dart';

AppLocalizations _voiceStrings(BuildContext context) => voiceStrings(context);

bool _setupBusy(VoiceModelManager manager) =>
    manager.state == VoiceModelState.downloading ||
    manager.state == VoiceModelState.verifying;

// revamp: redesign (slice-P10.4): automatic pack choice by total RAM and a
// background download from the first mic tap wait for that slice.
/// The voice model setup sheet (voice-model-setup-sheet) in the kit's one
/// sheet frame. Completes with true when the person chose "Use Balanced"
/// with the model on the phone, false otherwise (Not now, close, swipe).
///
/// The pinned primary follows the manager: "Download Balanced (153 MB)"
/// before the model is on the phone, "Use Balanced" once it is, and nothing
/// while a download runs (the progress in the body says what is happening
/// and holds Cancel download). A download keeps running in the manager if
/// the sheet is closed; reopening shows its progress.
Future<bool> showVoiceModelSetupSheet(
  BuildContext context,
  VoiceModelManager manager,
) async {
  if (!platformCapabilities.supportsVoice) return false;
  final strings = _voiceStrings(context);
  final navigator = Navigator.of(context);
  final primary = ValueNotifier<KitAction?>(null);
  void sync() => primary.value = _setupPrimary(
    manager,
    strings,
    use: () => navigator.pop(true),
  );
  sync();
  manager.addListener(sync);
  try {
    return await showKitSheet<bool>(
          context,
          title: strings.e7VoiceUiLocalInput,
          subtitle: strings.voiceSetupSubtitle,
          icon: AppIconography.waveform,
          primaryListenable: primary,
          secondary: KitAction(
            key: const Key('voice-model-secondary-action'),
            label: strings.e7VoiceUiNotNow,
            onPressed: () => navigator.pop(false),
          ),
          body: (context) => _VoiceModelSetupBody(manager: manager),
        ) ??
        false;
  } finally {
    manager.removeListener(sync);
    primary.dispose();
  }
}

KitAction? _setupPrimary(
  VoiceModelManager manager,
  AppLocalizations strings, {
  required VoidCallback use,
}) {
  if (_setupBusy(manager)) return null;
  final pack = manager.selectedPack;
  final name = voicePackLabel(pack, strings);
  const key = Key('voice-model-primary-action');
  if (manager.isInstalled(pack)) {
    return KitAction(
      key: key,
      label: strings.voiceSetupUsePack(name),
      icon: AppIconography.mic,
      onPressed: use,
    );
  }
  final support = manager.supportFor(pack);
  return KitAction(
    key: key,
    label: strings.voiceSetupDownloadPack(
      name,
      formatModelBytes(pack.downloadBytes),
    ),
    icon: AppIconography.download,
    onPressed: support.supported
        ? () => unawaited(manager.downloadSelected())
        : null,
    disabledReason: support.supported
        ? null
        : voiceSupportReason(manager, pack, support, strings),
  );
}

class _VoiceModelSetupBody extends StatelessWidget {
  const _VoiceModelSetupBody({required this.manager});

  final VoiceModelManager manager;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: manager,
    builder: (context, _) {
      final strings = _voiceStrings(context);
      final tokens = KitTokens.of(context);
      final busy = _setupBusy(manager);
      final selected = manager.selectedPack;
      final selectedName = voicePackLabel(selected, strings);
      final gap = SizedBox(height: tokens.space3);
      final error = manager.error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // What is happening comes first: the download the pinned
          // Download just started, or why setup failed, is never below the
          // fold (STATE-1).
          if (busy) ...[
            _VoiceDownloadProgress(manager: manager),
            SizedBox(height: tokens.space4),
          ],
          if (error != null) ...[
            KitNotice(
              tone: AppStatusTone.failure,
              message: strings.e7VoiceUiSetupFailed(
                voiceErrorText(error, strings, manager: manager),
              ),
            ),
            KitDetailsFold(
              label: strings.e7VoiceUiTechnicalDetails,
              text: error.toString(),
            ),
            gap,
          ],
          KitNotice(
            icon: AppIconography.locked,
            message: strings.e7VoiceUiPrivacyDownload,
            liveRegion: false,
          ),
          if (!manager.deviceInfo.hasMicrophone) ...[
            gap,
            KitNotice(message: strings.e7VoiceUiNoBuiltInMic),
          ],
          SizedBox(height: tokens.space4),
          KitText(strings.voiceSetupModelLabel, role: KitTextRole.label),
          SizedBox(height: tokens.space1),
          KitChoiceList<String>.single(
            semanticsLabel: strings.voiceSetupModelLabel,
            selected: selected.id,
            onSelected: (id) =>
                unawaited(manager.selectPack(voiceModelPack(id))),
            choices: [
              for (final pack in voiceModelPacks)
                _packChoice(context, manager, pack, busy: busy),
            ],
          ),
          if (manager.isInstalled(selected) && !busy) ...[
            SizedBox(height: tokens.space1),
            KitActionStack(
              tertiary: [
                KitAction(
                  key: Key('voice-redownload-${selected.id}'),
                  label: strings.voiceSetupRedownloadPack(selectedName),
                  icon: AppIconography.retry,
                  onPressed: () => unawaited(manager.redownloadPack(selected)),
                ),
                KitAction(
                  key: Key('voice-delete-${selected.id}'),
                  label: strings.voiceSetupDeletePack(selectedName),
                  icon: AppIconography.delete,
                  destructive: true,
                  onPressed: () => unawaited(_confirmDelete(context, selected)),
                ),
              ],
            ),
          ],
          SizedBox(height: tokens.space4),
          KitText(strings.e7VoiceUiLanguage, role: KitTextRole.label),
          SizedBox(height: tokens.space2),
          KitSegmented<VoiceLanguage>(
            key: const Key('voice-model-language'),
            semanticsLabel: strings.e7VoiceUiLanguage,
            selected: manager.language,
            onChanged: busy
                ? null
                : (language) => unawaited(manager.setLanguage(language)),
            disabledReason: busy ? strings.voiceSetupBusyReason : null,
            segments: [
              for (final language in VoiceLanguage.values)
                KitSegment(
                  value: language,
                  label: voiceLanguageLabel(language, strings),
                ),
            ],
          ),
        ],
      );
    },
  );

  KitChoice<String> _packChoice(
    BuildContext context,
    VoiceModelManager manager,
    VoiceModelPack pack, {
    required bool busy,
  }) {
    final strings = _voiceStrings(context);
    final support = manager.supportFor(pack);
    return KitChoice<String>(
      key: Key('voice-model-${pack.id}'),
      value: pack.id,
      title: voicePackLabel(pack, strings),
      // On the phone: say so; otherwise what it costs to download. The
      // description already says which one is recommended.
      supporting: [
        manager.isInstalled(pack)
            ? strings.e7VoiceUiInstalled
            : strings.e7VoiceUiDownloadSize(
                formatModelBytes(pack.downloadBytes),
              ),
        voicePackDescription(pack, strings),
      ].join(' · '),
      enabled: !busy && support.supported,
      disabledReason: !support.supported
          ? voiceSupportReason(manager, pack, support, strings)
          : busy
          ? strings.voiceSetupBusyReason
          : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context, VoiceModelPack pack) async {
    final strings = _voiceStrings(context);
    final name = voicePackLabel(pack, strings);
    final confirmed = await showKitConfirm(
      context,
      title: strings.e7VoiceUiDeletePack(name),
      body: strings.e7VoiceUiDeleteDetail(formatModelBytes(pack.downloadBytes)),
      confirmLabel: strings.voiceSetupDeletePack(name),
      cancelLabel: strings.voiceSetupKeepPack(name),
      icon: AppIconography.delete,
      kind: KitConfirmKind.destructive,
      confirmKey: const Key('voice-delete-confirm'),
    );
    if (confirmed) await manager.deletePack(pack);
  }
}

/// The running download: what is downloading, how far, and the one way to
/// stop it, next to the progress it stops.
class _VoiceDownloadProgress extends StatelessWidget {
  const _VoiceDownloadProgress({required this.manager});

  final VoiceModelManager manager;

  @override
  Widget build(BuildContext context) {
    final strings = _voiceStrings(context);
    final tokens = KitTokens.of(context);
    final verifying = manager.state == VoiceModelState.verifying;
    final fraction = manager.progress?.fraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: verifying
              ? strings.e7VoiceUiVerifying
              : strings.e7VoiceUiDownloadPercent(
                  ((fraction ?? 0) * 10).floor() * 10,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              KitText(
                verifying
                    ? strings.e7VoiceUiVerifying
                    : strings.voiceSetupDownloadingPack(
                        voicePackLabel(manager.selectedPack, strings),
                      ),
                role: KitTextRole.rowTitle,
              ),
              SizedBox(height: tokens.space2),
              KitProgressView(
                progress: verifying || fraction == null
                    ? KitProgress.waiting(
                        caption: verifying
                            ? strings.e7VoiceUiVerifyChecksum
                            : null,
                      )
                    : KitProgress.known(
                        fraction.clamp(0.0, 1.0),
                        caption: strings.e7VoiceUiDownloadProgress(
                          formatModelBytes(manager.progress?.received ?? 0),
                          formatModelBytes(manager.selectedPack.downloadBytes),
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (!verifying) ...[
          SizedBox(height: tokens.space2),
          KitActionStack(
            secondary: KitAction(
              key: const Key('voice-model-cancel-download'),
              label: strings.e7VoiceUiCancelDownload,
              onPressed: manager.cancelDownload,
            ),
          ),
        ],
      ],
    );
  }
}

/// What the voice sheet hands back: the reviewed transcript and whether the
/// user asked for it to be sent right away ("Insert & send") rather than
/// only inserted into the composer.
class VoiceComposerResult {
  const VoiceComposerResult({required this.text, this.send = false});

  final String text;
  final bool send;
}

/// The recording cap the controller enforces; stated up front so the user
/// knows how long they have before pressing the microphone.
const voiceRecordingCap = Duration(seconds: 30);

Future<String?> showVoiceComposerSheet(
  BuildContext context,
  VoiceComposerController controller,
) async => (await showVoiceComposerResultSheet(context, controller))?.text;

// revamp: redesign (slice-P10.3): recording moves inline into the composer
// there and this sheet is deleted; this is a kit-only restyle.
/// The voice sheet (voice-composer-sheet) with its full result, in the
/// kit's sheet frame. Dragging it down, tapping outside or closing it
/// dismisses it; each path cancels any recording in flight first.
Future<VoiceComposerResult?> showVoiceComposerResultSheet(
  BuildContext context,
  VoiceComposerController controller, {
  bool conversation = false,
  ValueListenable<int>? validity,
  bool Function()? isCurrent,
}) {
  if (!platformCapabilities.supportsVoice) return Future.value(null);
  final strings = _voiceStrings(context);
  return showKitSheet<VoiceComposerResult>(
    context,
    title: strings.voiceComposerTitle,
    subtitle: strings.e7VoiceUiPrivacy,
    icon: AppIconography.mic,
    body: (context) => _VoiceComposerSheet(
      controller: controller,
      conversation: conversation,
      validity: validity,
      isCurrent: isCurrent,
    ),
  );
}

class _VoiceComposerSheet extends StatefulWidget {
  const _VoiceComposerSheet({
    required this.controller,
    this.conversation = false,
    this.validity,
    this.isCurrent,
  });

  final VoiceComposerController controller;
  final bool conversation;
  final ValueListenable<int>? validity;
  final bool Function()? isCurrent;

  @override
  State<_VoiceComposerSheet> createState() => _VoiceComposerSheetState();
}

class _VoiceComposerSheetState extends State<_VoiceComposerSheet>
    with WidgetsBindingObserver {
  final TextEditingController _draft = TextEditingController();
  String _syncedDraft = '';
  bool _interrupted = false;
  bool get _current => !_interrupted && (widget.isCurrent?.call() ?? true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.validity?.addListener(_scopeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _current && !widget.conversation) {
        unawaited(widget.controller.startListening());
      }
    });
  }

  void _scopeChanged() {
    if (!_current && mounted) _interrupt();
  }

  void _interrupt() {
    _interrupted = true;
    _draft.clear();
    _syncedDraft = '';
    unawaited(widget.controller.cancel());
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _interrupt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!(route?.isCurrent ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !(route?.isCurrent ?? true)) _interrupt();
      });
    }
  }

  Future<void> _close() async {
    await widget.controller.cancel();
    if (mounted) KitSheet.close<VoiceComposerResult>(context);
  }

  Future<void> _insert({required bool send}) async {
    final text = _draft.text.trim();
    if (text.isEmpty || !_current) return;
    await widget.controller.cancel();
    if (mounted && _current) {
      KitSheet.close(context, VoiceComposerResult(text: text, send: send));
    }
  }

  Future<void> _openModelSetup() async {
    final ready = await showVoiceModelSetupSheet(
      context,
      widget.controller.models,
    );
    if (ready && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      // A drag-down, tap-outside or back gesture pops first; the recorder is
      // stopped right behind it so no capture outlives the sheet. Cancel is
      // idempotent, so the explicit Cancel/Insert paths are unaffected.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(widget.controller.cancel());
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final strings = _voiceStrings(context);
          final tokens = KitTokens.of(context);
          final controller = widget.controller;
          if (!_current) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                KitNotice(message: strings.voiceInputInterrupted),
                SizedBox(height: tokens.space3),
                KitActionBlock(
                  secondary: KitAction(
                    label: strings.voiceInputClose,
                    onPressed: () => unawaited(_close()),
                  ),
                ),
              ],
            );
          }
          if (controller.state == VoiceComposerState.draft &&
              controller.draft != _syncedDraft) {
            _syncedDraft = controller.draft;
            _draft.value = TextEditingValue(
              text: controller.draft,
              selection: TextSelection.collapsed(
                offset: controller.draft.length,
              ),
            );
          }
          final state = controller.state;
          final error = controller.error;
          final working =
              state == VoiceComposerState.listening ||
              state == VoiceComposerState.initializing ||
              state == VoiceComposerState.loading ||
              state == VoiceComposerState.finishingCancellation ||
              state == VoiceComposerState.transcribing;
          final cancel = KitAction(
            key: const Key('voice-composer-cancel'),
            label: strings.e7VoiceUiCancel,
            onPressed: () => unawaited(_close()),
          );
          final modelLine = KitAction(
            key: const Key('voice-composer-model'),
            label: strings.voiceComposerModelLine(
              voicePackLabel(controller.models.selectedPack, strings),
              voiceLanguageLabel(controller.models.language, strings),
            ),
            icon: AppIconography.settingsAdvanced,
            onPressed: () => unawaited(_openModelSetup()),
          );
          final KitAction? primary = switch (state) {
            VoiceComposerState.listening => KitAction(
              key: const Key('stop-voice-recording'),
              label: strings.e7VoiceUiStopRecording,
              icon: AppIcons.stop,
              onPressed: () => unawaited(controller.stopListening()),
            ),
            VoiceComposerState.draft => KitAction(
              key: const Key('insert-voice-draft'),
              label: strings.e7VoiceUiInsert,
              icon: AppIconography.add,
              onPressed: () => unawaited(_insert(send: false)),
            ),
            VoiceComposerState.error => KitAction(
              label: strings.e7VoiceUiRetry,
              icon: AppIconography.retry,
              onPressed: () => unawaited(controller.startListening()),
            ),
            VoiceComposerState.idle => KitAction(
              label: strings.e7VoiceUiStartListening,
              icon: AppIconography.mic,
              onPressed: () => unawaited(controller.startListening()),
            ),
            _ => null,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoiceStatus(controller: controller),
              if (widget.conversation) ...[
                SizedBox(height: tokens.space3),
                KitText(
                  strings.voiceConversationInstructions,
                  role: KitTextRole.secondary,
                  tone: KitTextTone.secondary,
                ),
              ],
              if (state == VoiceComposerState.draft) ...[
                SizedBox(height: tokens.space4),
                KitField(
                  fieldKey: const Key('voice-draft-field'),
                  label: strings.e7VoiceUiReviewTranscript,
                  helper: strings.voiceReviewExplicitAction,
                  controller: _draft,
                  kind: KitFieldKind.multiline,
                  maxLines: 8,
                  autofocus: true,
                ),
              ],
              if (state == VoiceComposerState.error) ...[
                SizedBox(height: tokens.space4),
                KitNotice(
                  tone: AppStatusTone.failure,
                  message: voiceErrorText(
                    error,
                    strings,
                    manager: controller.models,
                  ),
                  actions: [
                    if (error is VoicePermissionDenied && error.permanent)
                      KitAction(
                        label: strings.e7VoiceUiOpenSettings,
                        icon: AppIconography.settings,
                        onPressed: () =>
                            unawaited(voiceDevicePlatform.openAppSettings()),
                      ),
                  ],
                ),
                if (error != null)
                  KitDetailsFold(
                    label: strings.e7VoiceUiTechnicalDetails,
                    text: error.toString(),
                  ),
              ],
              SizedBox(height: tokens.space4),
              KitActionBlock(
                primary: primary,
                secondary: cancel,
                tertiary: [
                  if (state == VoiceComposerState.draft && !widget.conversation)
                    KitAction(
                      key: const Key('insert-voice-draft-send'),
                      label: strings.e7VoiceUiInsertSend,
                      icon: AppIconography.send,
                      onPressed: () => unawaited(_insert(send: true)),
                    ),
                  if (!working) modelLine,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.validity?.removeListener(_scopeChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.cancel());
    _draft.dispose();
    super.dispose();
  }
}

class _VoiceStatus extends StatelessWidget {
  const _VoiceStatus({required this.controller});

  final VoiceComposerController controller;

  @override
  Widget build(BuildContext context) {
    final strings = _voiceStrings(context);
    final tokens = KitTokens.of(context);
    final listening = controller.state == VoiceComposerState.listening;
    final capSeconds = voiceRecordingCap.inSeconds;
    // While listening the status line already says "of 0:30"; before that
    // the cap gets its own line so it is known before the mic starts.
    final showCap =
        controller.state == VoiceComposerState.idle ||
        controller.state == VoiceComposerState.initializing ||
        controller.state == VoiceComposerState.loading;
    final waiting =
        controller.state == VoiceComposerState.initializing ||
        controller.state == VoiceComposerState.loading ||
        controller.state == VoiceComposerState.finishingCancellation ||
        controller.state == VoiceComposerState.transcribing;
    final status = switch (controller.state) {
      VoiceComposerState.listening => strings.e7VoiceUiListeningTime(
        _formatElapsed(controller.elapsed),
        _formatElapsed(voiceRecordingCap),
      ),
      VoiceComposerState.initializing => strings.e7VoiceUiStartingMic,
      VoiceComposerState.loading => strings.e7VoiceUiLoadingModel,
      VoiceComposerState.transcribing => strings.e7VoiceUiTranscribing,
      VoiceComposerState.finishingCancellation =>
        strings.e7VoiceUiFinishingCancel,
      VoiceComposerState.draft => strings.e7VoiceUiDraftReady,
      VoiceComposerState.error => strings.e7VoiceUiNeedsAttention,
      VoiceComposerState.idle => strings.e7VoiceUiReady,
      VoiceComposerState.modelRequired => strings.e7VoiceUiModelRequired,
      VoiceComposerState.downloading => strings.e7VoiceUiDownloading,
      VoiceComposerState.verifying => strings.e7VoiceUiVerifyingModel,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: listening ? strings.e7VoiceUiListeningHint : status,
          excludeSemantics: true,
          child: KitText(
            status,
            role: KitTextRole.headline,
            textAlign: TextAlign.center,
            tabular: listening,
          ),
        ),
        if (showCap) ...[
          SizedBox(height: tokens.space1),
          KitText(
            strings.e7VoiceUiRecordingCap(capSeconds),
            key: const Key('voice-recording-cap'),
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
            textAlign: TextAlign.center,
          ),
        ],
        if (listening) ...[
          SizedBox(height: tokens.space4),
          KitLevelMeter(level: controller.level),
        ],
        if (waiting) ...[
          SizedBox(height: tokens.space4),
          const KitProgressView(progress: KitProgress.waiting()),
        ],
      ],
    );
  }
}

String _formatElapsed(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, voiceRecordingCap.inSeconds);
  return '0:${seconds.toString().padLeft(2, '0')}';
}
