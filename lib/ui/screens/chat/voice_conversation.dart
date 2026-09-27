part of '../chat_screen.dart';

/// One turn sent from a voice conversation with "Speak replies" on. The
/// watch is bound to the app-authored ID carried on dispatch, the speech scope and the voice
/// epoch, so a reconnect, a scope switch, or Exit can never re-attach it to
/// some other text.
class _VoiceReplyWatch {
  _VoiceReplyWatch({
    required this.pending,
    required this.scope,
    required this.epoch,
    required this.existingMessageIDs,
  });
  final _PendingSend pending;
  final Object scope;
  final int epoch;
  final Set<String> existingMessageIDs;
  final Set<String> liveUserIDs = {};

  /// Set once the session has been seen busy after the send; only then can
  /// an idle session mean "the turn ran and finished" rather than "the
  /// status event has not arrived yet".
  bool sawBusy = false;
  bool sawIdle = false;
}

/// What the conversation strip reports about automatic reading.
enum _VoiceReplyState {
  idle,

  /// The turn was accepted; its reply has not completed yet.
  waiting,

  /// The reply completed but could not be tied to the sent turn with
  /// certainty; reading stays a tap away instead of a guess.
  reviewNeeded,

  /// A request, question or form interrupted the turn; automatic reading
  /// was cancelled for it.
  interrupted,

  /// The reply completed with nothing speakable (code, tools, or empty).
  noProse,

  /// The engine refused or failed; the reply can be read again by hand.
  failed,
}

extension _ChatVoiceConversation on _ChatScreenState {
  void _observeVoiceReplyStatus(EventEnvelope event) {
    final watch = _voiceReplyWatch;
    if (watch == null || event.properties['sessionID'] != widget.sessionID) {
      return;
    }
    if (event.type == 'session.status') {
      final raw = event.properties['status'];
      final status = raw is Map ? raw['type'] : raw;
      if (status == 'busy' || status == 'retry') {
        watch.sawBusy = true;
        watch.sawIdle = false;
      } else if (status == 'idle' && watch.sawBusy) {
        watch.sawIdle = true;
      }
    } else if (event.type == 'session.idle' && watch.sawBusy) {
      watch.sawIdle = true;
    }
  }

  bool get _conversationCanSend =>
      _conn.status == StreamStatus.connected &&
      !_conn.busySessions.contains(widget.sessionID) &&
      _conn.permissionsForSession(widget.sessionID).isEmpty &&
      _conn.questionForSession(widget.sessionID) == null &&
      _conn.formForSession(widget.sessionID) == null &&
      _conn.isProfileReadable(_conn.promptShelfProfileID);

  bool get _conversationBlockedByRequest =>
      _conn.permissionsForSession(widget.sessionID).isNotEmpty ||
      _conn.questionForSession(widget.sessionID) != null ||
      _conn.formForSession(widget.sessionID) != null;

  String get _conversationPauseCopy =>
      _chatL10n(context).voiceConversationPausedDetail;

  Future<void> _startVoiceConversation() async {
    if (_conn.isIsolated) return;
    if (!platformCapabilities.supportsVoiceConversation ||
        _sending ||
        _voiceOpening ||
        _promptShelfBusy) {
      return;
    }
    if (!_voiceConversation) {
      if (_composer.text.isNotEmpty ||
          _attachments.isNotEmpty ||
          _handoff.references.isNotEmpty) {
        _showComposerNote(_chatL10n(context).voiceConversationDraftFirst);
        return;
      }
      if (!_conversationCanSend) {
        _showComposerNote(_conversationPauseCopy);
        return;
      }
      _voiceOwnerScope = _speechScopeNow;
      _updateSpeech(() => _voiceConversation = true);
    }
    await _openVoice();
  }

  void _interruptVoiceConversation() {
    _voiceEpoch.value++;
    _voiceOwnerScope = null;
    unawaited(_voice?.cancel());
    unawaited(_stopReading());
    if (_voiceConversation) {
      // Clear while the persistence guard is still active.
      _composer.clear();
      _draftSaveTimer?.cancel();
      _updateSpeech(() {
        _voiceConversation = false;
        _voiceSpeakReplies = false;
        _voiceReplyWatch = null;
        _voiceReplyState = _VoiceReplyState.idle;
      });
    }
  }

  /// Drops the opt-in and anything owed under it, without leaving the
  /// conversation. Used when consent lapses with a scope change.
  void _revokeVoiceSpeakReplies() {
    if (!_voiceSpeakReplies && _voiceReplyWatch == null) return;
    _voiceSpeakReplies = false;
    _voiceReplyWatch = null;
    _voiceReplyState = _VoiceReplyState.idle;
    if (mounted) _updateSpeech(() {});
  }

  /// The "Speak replies" switch. Turning it on runs the same consent and
  /// voice-choice sheets as a manual Read aloud, right now, so no automatic
  /// playback can ever be the first time the engine is touched.
  Future<void> _setVoiceSpeakReplies(bool enabled) async {
    if (!enabled) {
      final wasSpeakingReply = _readAloud?.activeID?.startsWith(
        _voiceReplyUtterancePrefix,
      );
      _updateSpeech(() {
        _voiceSpeakReplies = false;
        _voiceReplyWatch = null;
        _voiceReplyState = _VoiceReplyState.idle;
      });
      if (wasSpeakingReply == true) unawaited(_stopReading());
      return;
    }
    if (!_voiceConversation ||
        _voiceSpeakReplies ||
        !platformCapabilities.supportsReadAloud ||
        _readAloudRequestBusy) {
      return;
    }
    final source = _speechScopeNow;
    final epoch = _voiceEpoch.value;
    final route = ModalRoute.of(context);
    final request = ++_readAloudRequest;
    bool current() =>
        mounted &&
        _voiceConversation &&
        request == _readAloudRequest &&
        epoch == _voiceEpoch.value &&
        source == _speechScopeNow &&
        (route?.isCurrent ?? true);
    _speechOwnerScope = source;
    _updateSpeech(() => _readAloudRequestBusy = true);
    try {
      if (!await _ensureSpeechReady(current: current)) return;
      _updateSpeech(() {
        _voiceSpeakReplies = true;
        _voiceReplyState = _VoiceReplyState.idle;
      });
    } on ReadAloudException catch (error) {
      if (current() && _readAloud?.failure != error.failure) {
        _showComposerNote(_speechFailure(error.failure));
      }
    } catch (_) {
      if (mounted && current()) {
        _showComposerNote(_chatL10n(context).readAloudUnavailable);
      }
    } finally {
      if (mounted && request == _readAloudRequest) {
        _updateSpeech(() => _readAloudRequestBusy = false);
      }
    }
  }

  String get _voiceReplyUtterancePrefix => '${widget.sessionID}/voice-reply/';

  /// Armed immediately before dispatch so fast echoes, requests and busy
  /// events are observed. Playback still waits for requestComplete.
  void _watchVoiceReply(_PendingSend pending) {
    if (!_voiceSpeakReplies) return;
    if (pending.dispatchedMessageID == null) {
      _voiceReplyWatch = null;
      _voiceReplyState = _VoiceReplyState.reviewNeeded;
      return;
    }
    _voiceReplyWatch = _VoiceReplyWatch(
      pending: pending,
      scope: _speechScopeNow,
      epoch: _voiceEpoch.value,
      existingMessageIDs: _messages.map((m) => m.info.id).toSet(),
    );
    _voiceReplyState = _VoiceReplyState.waiting;
  }

  /// The assistant messages that answer [canonicalID]: everything after that
  /// user message up to the next user message, with an explicit parent id.
  /// Order alone cannot distinguish another client's reply.
  List<MessageWithParts> _voiceReplyCandidates(String canonicalID) {
    final start = _messages.indexWhere((m) => m.info.id == canonicalID);
    if (start < 0) return const [];
    final byParent = <MessageWithParts>[];
    for (final message in _messages.skip(start + 1)) {
      final info = message.info;
      if (info.role == 'user') break;
      if (info.role != 'assistant') continue;
      final parent = info.parentID;
      // A mixed or parentless response is not safe to read partially.
      if (parent != canonicalID) return const [];
      byParent.add(message);
    }
    return byParent;
  }

  /// Re-evaluated on every event and controller change while a turn is
  /// owed. Speaks exactly once, only when the turn has verifiably finished,
  /// and otherwise resolves to an explicit state instead of guessing.
  void _checkVoiceReply() {
    final watch = _voiceReplyWatch;
    if (watch == null || !mounted) return;
    void settle(_VoiceReplyState state) {
      _voiceReplyWatch = null;
      _updateSpeech(() => _voiceReplyState = state);
    }

    if (!_voiceConversation ||
        !_voiceSpeakReplies ||
        watch.epoch != _voiceEpoch.value ||
        watch.scope != _speechScopeNow) {
      settle(_VoiceReplyState.idle);
      return;
    }
    if (_conversationBlockedByRequest) {
      // The turn now needs the user on screen; whatever it says afterwards
      // is read only on request.
      settle(_VoiceReplyState.interrupted);
      return;
    }
    if (_conn.status != StreamStatus.connected) {
      settle(_VoiceReplyState.reviewNeeded);
      return;
    }
    if (_conn.busySessions.contains(widget.sessionID)) {
      watch.sawBusy = true;
      return;
    }
    if (!watch.pending.requestComplete || !watch.sawBusy || !watch.sawIdle) {
      return;
    }
    // canonicalID is text/time reconciliation for optimistic rendering, not
    // evidence that this client dispatched a message. Never trust it here.
    final canonicalID = watch.pending.dispatchedMessageID;
    if (canonicalID == null ||
        watch.existingMessageIDs.contains(canonicalID) ||
        watch.liveUserIDs.length != 1 ||
        !watch.liveUserIDs.contains(canonicalID)) {
      // The session ran and went idle, or errored, but the server's copy of
      // the sent message never matched: the reply cannot be pinned to it.
      if (watch.sawBusy || _promptError != null) {
        settle(_VoiceReplyState.reviewNeeded);
      }
      return;
    }
    final replies = _voiceReplyCandidates(canonicalID);
    if (replies.isEmpty) {
      settle(_VoiceReplyState.reviewNeeded);
      return;
    }
    final settled = replies.every(
      (m) => (m.info.time?.isDone ?? false) || m.info.errorText != null,
    );
    if (!settled) return;
    final prose = [
      for (final reply in replies)
        markdownProseForSpeech(_ChatScreenState._messageText(reply)),
    ].where((text) => text.isNotEmpty).join('\n\n');
    if (prose.isEmpty) {
      settle(_VoiceReplyState.noProse);
      return;
    }
    _voiceReplyWatch = null;
    unawaited(_speakVoiceReply(canonicalID, prose));
  }

  Future<void> _speakVoiceReply(String canonicalID, String prose) async {
    // Consent and the voice were granted when the switch went on; a scope
    // change since then revoked both, and the switch with them.
    if (!_voiceSpeakReplies ||
        !_readAloudConsented ||
        _readAloudVoiceID == null ||
        _readAloud == null) {
      _updateSpeech(() => _voiceReplyState = _VoiceReplyState.reviewNeeded);
      return;
    }
    final source = _speechScopeNow;
    final epoch = _voiceEpoch.value;
    final route = ModalRoute.of(context);
    final request = ++_readAloudRequest;
    bool current() =>
        mounted &&
        _voiceConversation &&
        _voiceSpeakReplies &&
        request == _readAloudRequest &&
        epoch == _voiceEpoch.value &&
        source == _speechScopeNow &&
        (route?.isCurrent ?? true);
    _speechOwnerScope = source;
    _updateSpeech(() {
      _readAloudRequestBusy = true;
      _voiceReplyState = _VoiceReplyState.idle;
      _voiceReplyPlayback = true;
    });
    try {
      if (!current()) return;
      final speech = _readAloud!;
      await speech.speak(
        '$_voiceReplyUtterancePrefix$canonicalID',
        prose,
        voiceID: _readAloudVoiceID,
      );
      if (!current()) await speech.stop();
    } on FormatException {
      if (mounted && current()) {
        _updateSpeech(() => _voiceReplyState = _VoiceReplyState.failed);
        _showComposerNote(_chatL10n(context).readAloudTooLong);
      }
    } on ReadAloudException catch (error) {
      if (current()) {
        _updateSpeech(() => _voiceReplyState = _VoiceReplyState.failed);
        if (_readAloud?.failure != error.failure) {
          _showComposerNote(_speechFailure(error.failure));
        }
      }
    } catch (_) {
      if (mounted && current()) {
        _updateSpeech(() => _voiceReplyState = _VoiceReplyState.failed);
        _showComposerNote(_chatL10n(context).readAloudUnavailable);
      }
    } finally {
      if (mounted && request == _readAloudRequest) {
        _updateSpeech(() => _readAloudRequestBusy = false);
      }
    }
  }

  /// The latest assistant message of this session, for the explicit
  /// "Read reply" fallback; null when there is none loaded.
  MessageWithParts? get _latestAssistantMessage {
    for (final message in _messages.reversed) {
      if (message.info.role == 'assistant') return message;
    }
    return null;
  }

  bool get _speakingVoiceReply =>
      _readAloud?.speaking == true &&
      (_readAloud?.activeID?.startsWith(_voiceReplyUtterancePrefix) ?? false);

  // revamp: redesign (slice-P10.3) — voice as a composer mode (the mic in
  // the send slot, a listen → send → speak loop without the sheet) is that
  // slice's work; this is today's controls rebuilt from kit parts.

  /// The voice conversation's controls, in place of the attention slot:
  /// what the mode is doing now, "Speak replies", the reply's state in
  /// words, Listen as the one primary, and the ways out.
  Widget _voiceConversationControls() {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final waiting = _voiceReplyWatch != null;
    final speaking = _speakingVoiceReply;
    final latest = _latestAssistantMessage;
    final String? replyLine = speaking
        ? l10n.voiceConversationSpeakingReply
        : waiting
        ? l10n.voiceConversationWaitingReply
        : switch (_voiceReplyState) {
            _VoiceReplyState.idle => null,
            _VoiceReplyState.waiting => l10n.voiceConversationWaitingReply,
            _VoiceReplyState.reviewNeeded =>
              l10n.voiceConversationReplyReviewNeeded,
            _VoiceReplyState.interrupted =>
              l10n.voiceConversationReplyInterrupted,
            _VoiceReplyState.noProse => l10n.voiceConversationReplyNoProse,
            _VoiceReplyState.failed => l10n.voiceConversationReplyFailed,
          };
    final offerRead =
        !speaking &&
        !waiting &&
        latest != null &&
        (_voiceReplyState == _VoiceReplyState.reviewNeeded ||
            _voiceReplyState == _VoiceReplyState.interrupted ||
            _voiceReplyState == _VoiceReplyState.failed);
    final canSend = _conversationCanSend;
    final paused = !canSend && !waiting && !speaking;
    final listenReady = !_voiceOpening && !_sending && canSend;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.space3,
        tokens.space1,
        tokens.space3,
        tokens.space2,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .36,
        ),
        child: KitSurface(
          outlined: true,
          padding: KitSurfacePadding.none,
          child: KitScrollbar(
            controller: _voiceControlsScroll,
            child: ListView(
              controller: _voiceControlsScroll,
              shrinkWrap: true,
              padding: EdgeInsets.all(tokens.space4),
              children: [
                Semantics(
                  liveRegion: true,
                  label: canSend
                      ? l10n.voiceConversationTitle
                      : _conversationPauseCopy,
                  excludeSemantics: true,
                  child: KitText(
                    paused
                        ? l10n.voiceConversationPausedTitle
                        : l10n.voiceConversationTitle,
                    role: KitTextRole.headline,
                  ),
                ),
                if (paused) ...[
                  SizedBox(height: tokens.space1),
                  KitText(
                    _conversationPauseCopy,
                    role: KitTextRole.secondary,
                    tone: KitTextTone.secondary,
                  ),
                ],
                if (platformCapabilities.supportsReadAloud) ...[
                  SizedBox(height: tokens.space2),
                  KitSwitchRow(
                    switchKey: const Key('voice-speak-replies'),
                    title: l10n.voiceConversationSpeakReplies,
                    supporting: l10n.voiceConversationSpeakRepliesDetail,
                    value: _voiceSpeakReplies,
                    onChanged: _readAloudRequestBusy && !_voiceSpeakReplies
                        ? null
                        : (value) => unawaited(_setVoiceSpeakReplies(value)),
                    disabledReason: l10n.voiceConversationSpeakRepliesBusy,
                  ),
                ],
                if (replyLine != null) ...[
                  SizedBox(height: tokens.space2),
                  KitNotice(
                    key: const Key('voice-reply-status'),
                    message: replyLine,
                    tone: waiting || speaking
                        ? AppStatusTone.progress
                        : _voiceReplyState == _VoiceReplyState.failed
                        ? AppStatusTone.failure
                        : AppStatusTone.neutral,
                  ),
                ],
                SizedBox(height: tokens.space3),
                KitActionBlock(
                  primary: KitAction(
                    key: const Key('voice-listen'),
                    icon: AppIconography.mic,
                    label: l10n.voiceConversationListen,
                    onPressed: listenReady ? _openVoice : null,
                    disabledReason: listenReady ? null : _conversationPauseCopy,
                  ),
                  tertiary: [
                    if (speaking || waiting)
                      KitAction(
                        key: const Key('voice-reply-stop'),
                        icon: AppIconography.stop,
                        label: l10n.voiceConversationStopReading,
                        onPressed: () => unawaited(_stopReading()),
                      ),
                    if (offerRead)
                      KitAction(
                        key: const Key('voice-reply-read'),
                        icon: AppIconography.volume,
                        label: l10n.voiceConversationReadReply,
                        onPressed: _readAloudRequestBusy
                            ? null
                            : () {
                                _updateSpeech(
                                  () =>
                                      _voiceReplyState = _VoiceReplyState.idle,
                                );
                                unawaited(_readReply(latest));
                              },
                      ),
                    KitAction(
                      key: const Key('voice-exit'),
                      icon: AppIconography.close,
                      label: l10n.voiceConversationExit,
                      onPressed: _interruptVoiceConversation,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
