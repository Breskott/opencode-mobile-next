// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get setupCancelConnection => 'Cancel connection';

  @override
  String get servicesTitle => 'Development services';

  @override
  String get servicesCopy => 'Copy command';

  @override
  String get servicesSubtitle => 'Project commands, logs, and preview links';

  @override
  String get servicesIntro =>
      'Keep your project\'s development commands and preview links together. Saving a service does not start it.';

  @override
  String get servicesAdd => 'Register service';

  @override
  String get servicesName => 'Service name';

  @override
  String get servicesCommand => 'Development command';

  @override
  String get servicesCommandHint =>
      'Use a foreground command, such as npm run dev. Background or detached commands cannot be tracked.';

  @override
  String get servicesUrl => 'Preview URL (optional)';

  @override
  String get servicesUrlHint =>
      'Use an address this phone can reach. localhost points to this phone. No ports are exposed or forwarded for you.';

  @override
  String get servicesSave => 'Save service';

  @override
  String get servicesInvalid =>
      'Enter a name, a foreground command, and an optional HTTP or HTTPS URL without credentials.';

  @override
  String get servicesUnavailable =>
      'This server cannot start and track development commands. You can save commands and review their preview links here.';

  @override
  String get servicesScopeChanged =>
      'The server or project changed. Reopen Development services from the intended project.';

  @override
  String get servicesNotStarted => 'Not started';

  @override
  String get servicesRunning => 'Running command';

  @override
  String get servicesStopped => 'Stopped';

  @override
  String get servicesUnknown => 'Status unknown';

  @override
  String get servicesStatusHint =>
      'Command status does not confirm that your app is ready or reachable.';

  @override
  String get servicesStart => 'Start';

  @override
  String get servicesStop => 'Stop';

  @override
  String get servicesRestart => 'Restart';

  @override
  String get servicesLogs => 'Logs';

  @override
  String get servicesVisit => 'Visit';

  @override
  String get servicesRemove => 'Remove configuration';

  @override
  String get servicesRemoveHint =>
      'Remove this saved service and its local ownership record? This does not stop its command on the server. Stop it first if needed.';

  @override
  String get servicesStartHint =>
      'Run this saved command in the project shown below? It uses the server\'s environment. Keep it in the foreground; this panel cannot manage detached processes.';

  @override
  String get servicesStopHint =>
      'Stop this service\'s tracked command? The server also removes its retained logs. Other commands are not affected.';

  @override
  String get servicesRestartHint =>
      'Stop this tracked command, remove its server log, then start the saved command again?';

  @override
  String get servicesForget => 'Forget last run';

  @override
  String get servicesForgetHint =>
      'Clear the local run record? This does not stop any server process. Starting again may create a duplicate if the previous command is still running.';

  @override
  String get servicesUnknownHint =>
      'The last run could not be confirmed. Refresh to reconcile it before starting again.';

  @override
  String get servicesLogEmpty => 'No captured output is available yet.';

  @override
  String get servicesLogTail =>
      'Bounded log tail. Earlier output may be omitted. Logs are kept on the server, not saved on this phone.';

  @override
  String get servicesWorking => 'Updating service…';

  @override
  String servicesExit(int code) {
    return 'Recorded exit code: $code';
  }

  @override
  String get servicesRefresh => 'Refresh status';

  @override
  String get isolatedTaskScopeChanged =>
      'The server or project changed. Close this sheet and reopen the task from the intended project.';

  @override
  String get appTitle => 'OpenCode Mobile';

  @override
  String get libraryManageSection => 'Manage';

  @override
  String get libraryModelsAgentsTitle => 'Models & agents';

  @override
  String get libraryProvidersTitle => 'Providers';

  @override
  String get libraryMcpTitle => 'MCP';

  @override
  String get libraryCommandsToolsTitle => 'Commands & tools';

  @override
  String get libraryTerminalTitle => 'Terminal';

  @override
  String get librarySettingsTitle => 'Settings';

  @override
  String aboutBuildVersion(String version, String buildNumber) {
    return 'OpenCode Mobile $version+$buildNumber';
  }

  @override
  String get aboutSigningCertificate => 'Signing certificate SHA-256';

  @override
  String get modelSwitchSession => 'Switch model for this conversation';

  @override
  String get modelNextRecent => 'Next recent model · F2';

  @override
  String get modelPreviousRecent => 'Previous recent model · Shift+F2';

  @override
  String get modelNextFavorite => 'Next favorite model';

  @override
  String get modelChooseTitle => 'Choose a model';

  @override
  String get modelTitleCompact => 'Models';

  @override
  String get modelSearchHint => 'Search models';

  @override
  String get modelAll => 'All models';

  @override
  String get modelFavorites => 'Favorites';

  @override
  String get modelRecent => 'Recent';

  @override
  String get modelOptions => 'Options';

  @override
  String get modelThinkingMode => 'Thinking mode';

  @override
  String get modelDefaultMode => 'Default mode';

  @override
  String get modelSessionScopeNote =>
      'Applies to this conversation\'s next turns.';

  @override
  String get modelSelectionLoading => 'Loading conversation selection…';

  @override
  String get modelServerDefault => 'Server default';

  @override
  String get modelSelectionSaving => 'Saving conversation selection…';

  @override
  String get modelAgentSaveFailed => 'Could not save the agent. Try again.';

  @override
  String get modelUnavailableSelection =>
      'The conversation\'s model is unavailable in this catalog. Refresh models or choose another.';

  @override
  String get modelScopeChanged =>
      'The server changed. Reopen the model selector to continue.';

  @override
  String get commonClearSearch => 'Clear search';

  @override
  String get commonUndo => 'Undo';

  @override
  String get workTitle => 'Tasks';

  @override
  String get workDescription =>
      'Agents and commands related to this conversation.';

  @override
  String get workAgents => 'Agents';

  @override
  String get workCommands => 'Commands';

  @override
  String get workEmpty => 'No tasks yet';

  @override
  String get workEmptyDescription =>
      'Related agents and commands will appear here when this conversation starts them.';

  @override
  String get workRefresh => 'Refresh';

  @override
  String get workClose => 'Close';

  @override
  String get workRetry => 'Try again';

  @override
  String get workCancel => 'Cancel';

  @override
  String get workRunning => 'Running';

  @override
  String get workFinished => 'Finished';

  @override
  String get workTimedOut => 'Timed out';

  @override
  String get workStopped => 'Stopped';

  @override
  String get workUnknown => 'Status unavailable';

  @override
  String get workOutput => 'Command output';

  @override
  String get workViewOutput => 'View output';

  @override
  String get workNoOutput => 'Waiting for output…';

  @override
  String get workNoFinalOutput => 'This command produced no output.';

  @override
  String get workCopyOutput => 'Copy output';

  @override
  String get workCopied => 'Output copied';

  @override
  String get workFollow => 'Follow output';

  @override
  String get workMoreOutput => 'Load more output';

  @override
  String get workTrimmed =>
      'Showing the most recent output. Earlier text was trimmed.';

  @override
  String get workStop => 'Stop command';

  @override
  String get workStopTitle => 'Stop this command?';

  @override
  String get workStopDescription =>
      'This stops the command and removes its saved output from the server. Text already loaded here stays visible until you close it.';

  @override
  String get workTimeout => 'Change timeout';

  @override
  String get workTimeoutTitle => 'Time remaining';

  @override
  String get workTimeoutDescription => 'The new timeout starts now.';

  @override
  String get workTimeoutOneMinute => '1 minute';

  @override
  String get workTimeoutFiveMinutes => '5 minutes';

  @override
  String get workTimeoutFifteenMinutes => '15 minutes';

  @override
  String get workTimeoutOneHour => '1 hour';

  @override
  String get workTimeoutNone => 'No timeout';

  @override
  String get workTimeoutSaved => 'Timeout updated';

  @override
  String get workUnavailable =>
      'This command is no longer available. It may have been removed or cancelled when the server restarted.';

  @override
  String get workRestarted =>
      'The server restarted and this command is no longer available. Its loaded output is shown below.';

  @override
  String get workDisconnected =>
      'Reconnecting. Output will refresh when the server is available.';

  @override
  String get workContextChanged =>
      'The server or project changed. Close this view and reopen Running work.';

  @override
  String workCount(int count) {
    return 'Tasks · $count running';
  }

  @override
  String workExitCode(int code) {
    return 'Exit code $code';
  }

  @override
  String workStatusElapsed(String status, String elapsed) {
    return '$status · $elapsed';
  }

  @override
  String get composerClearTextTitle => 'Clear draft text';

  @override
  String get composerClearTextSubtitle => 'Keeps attachments · Undo available';

  @override
  String get composerDraftCleared => 'Draft text cleared';

  @override
  String get composerReuseTitle => 'Reuse a prompt';

  @override
  String get queueSaveFailed =>
      'Could not save the queued draft on this device. Your text is still here. Check available storage and try again.';

  @override
  String get fileCopy => 'Copy';

  @override
  String get fileReference => 'Reference';

  @override
  String get fileAttach => 'Attach';

  @override
  String get fileSave => 'Save';

  @override
  String get fileReload => 'Refresh';

  @override
  String get queueRemoveFailed =>
      'Could not remove this draft from device storage. It is still queued. Check available storage and try again.';

  @override
  String get composerReuseSubtitle =>
      'Reuse text from this conversation and recent sends';

  @override
  String get composerReuseDescription =>
      'Text from loaded prompts in this conversation and recent sends on this server. Selecting one appends it to your draft. Attachments are not copied. With a keyboard, use Up at the start or Down at the end to browse and restore your draft.';

  @override
  String get composerReuseSearch => 'Search recent prompts';

  @override
  String get composerReuseEmpty => 'No matching prompts';

  @override
  String get backgroundSubagentsTitle => 'Background subagents';

  @override
  String get backgroundWorkTitle => 'Move running work to background';

  @override
  String get backgroundWorkShortcut =>
      'Continue this work while you use the conversation · Ctrl+B';

  @override
  String get backgroundWorkNoop => 'No foreground subagents to background.';

  @override
  String get backgroundWorkPromoted =>
      'Subagents are continuing in the background.';

  @override
  String get librarySearchHint => 'Find settings, tools, and help';

  @override
  String get libraryDefaultModel => 'Default for new conversations';

  @override
  String get libraryNoModel => 'No model selected';

  @override
  String librarySearchResults(int count, String query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results for “$query”.',
      one: '1 result for “$query”.',
      zero: 'No matching tools for “$query”.',
    );
    return '$_temp0';
  }

  @override
  String get chatAttachmentUnsupported =>
      'Images, PDFs, text files, and Excel or Word files (.xlsx, .docx) can be attached.';

  @override
  String get termuxRestartServer => 'Restart local server';

  @override
  String get termuxRestartTitle => 'Restart the local server?';

  @override
  String get termuxRestartMessage =>
      'OpenCode will be briefly unavailable. The app will keep your current project and reconnect automatically.';

  @override
  String termuxRestartBusyMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count conversations are generating. Restarting will interrupt them.',
      one: '1 conversation is generating. Restarting will interrupt it.',
    );
    return '$_temp0';
  }

  @override
  String get termuxRestartConfirm => 'Restart';

  @override
  String get termuxRestarting => 'Restarting local server...';

  @override
  String get termuxRestartProgress =>
      'The installed OpenCode version and saved credential are unchanged. The app will reconnect when the server is ready.';

  @override
  String get termuxRestartSucceeded =>
      'Local server restarted and reconnected.';

  @override
  String get termuxRestartNotPerformed =>
      'Restart was not performed. The existing local server is still running.';

  @override
  String get chatCopyCompleteReply => 'Copy complete reply';

  @override
  String get chatCopyReplySoFar => 'Copy reply so far';

  @override
  String commandRunTitle(String command) {
    return 'Run /$command';
  }

  @override
  String get commandDestination => 'Conversation';

  @override
  String get commandNewChat => 'New conversation';

  @override
  String get commandUntitledChat => 'Untitled conversation';

  @override
  String get commandArguments => 'Arguments (optional)';

  @override
  String get commandRun => 'Run';

  @override
  String get commandRunning => 'Starting…';

  @override
  String get commandLocationChanged =>
      'The server or project changed. Close this dialog and open the command again.';

  @override
  String get refreshFailed => 'Couldn’t refresh';

  @override
  String get refreshRetry => 'Try again';

  @override
  String get filesProjectRoot => 'Project root';

  @override
  String filesOpenFolder(String folder) {
    return 'Open folder $folder';
  }

  @override
  String filesCurrentFolder(String folder) {
    return 'Current folder: $folder';
  }

  @override
  String get globalSessionsLoadMore => 'Load more conversations';

  @override
  String get globalSessionsRefreshFailed => 'Could not refresh conversations.';

  @override
  String get workspaceSearchAllSessions => 'Search all conversations';

  @override
  String get workspaceProjectListUnavailable => 'Project list unavailable';

  @override
  String get workspaceProjectListFallback =>
      'Your conversations can still be available. Search all conversations to find previous work.';

  @override
  String get workspaceRetryProjects => 'Try again';

  @override
  String get historyLoadOlder => 'Load older messages';

  @override
  String get historyReload => 'Refresh recent history';

  @override
  String get historyCursorExpired =>
      'Older history changed or expired. Refresh recent history to continue.';

  @override
  String get historyRefreshed =>
      'History refreshed. Older messages remain available above.';

  @override
  String get historyLoadedOnly =>
      'Only loaded messages are included. Load older history to include more.';

  @override
  String get historyLoadedTotals => 'Usage and loaded history';

  @override
  String get historyCopyLoadedReply => 'Copy loaded reply';

  @override
  String get historyLoadedMessages => 'Loaded messages';

  @override
  String get historyLoadedCost => 'Cost of loaded messages';

  @override
  String get historyServerTotalsNote =>
      'Rows marked reported by server cover the conversation. Message counts and other estimates cover loaded history.';

  @override
  String get sessionsLoadedOnly =>
      'Showing loaded conversations. Load more to include older ones.';

  @override
  String get sessionsDetailsUnavailable =>
      'Conversation details could not be loaded. Try again.';

  @override
  String get sessionsLoadMore => 'Load more conversations';

  @override
  String get sessionsReload => 'Refresh recent conversations';

  @override
  String get sessionsNoLoadedRecent =>
      'No recent conversations in loaded results';

  @override
  String get sessionsNoLoadedArchived =>
      'No archived conversations in loaded results';

  @override
  String sessionsLoadedCount(int count) {
    return '$count loaded';
  }

  @override
  String get revertStageTitle => 'Stage a revert from this prompt?';

  @override
  String get revertStageDescription =>
      'This prompt and the conversation after it will be hidden while the revert is staged. Review the result before making it permanent.';

  @override
  String get revertApplyFiles => 'Revert file changes too';

  @override
  String get revertApplyFilesHint =>
      'Applies file changes immediately when staging. Clear can restore the staged files from the saved snapshot.';

  @override
  String get revertStageAction => 'Stage and review';

  @override
  String get revertReviewTitle => 'Review staged revert';

  @override
  String get revertReviewChanged =>
      'This conversation or its staged revert changed. Review the latest state before continuing.';

  @override
  String get revertReviewLatest => 'Review latest state';

  @override
  String get revertBusy =>
      'Wait for the current conversation action to finish.';

  @override
  String get revertCancel => 'Cancel';

  @override
  String get revertCommitTitle => 'Make this revert permanent?';

  @override
  String get revertCommitDescription =>
      'Removes the staged conversation history permanently. File changes already applied during staging will remain. You cannot clear this revert afterward.';

  @override
  String get revertCommitAction => 'Make revert permanent';

  @override
  String get revertClearTitle => 'Clear this staged revert?';

  @override
  String get revertClearDescription =>
      'Restores the hidden conversation and the files included in this stage from the saved snapshot. Changes made to those files since staging may be replaced. Queued work may resume.';

  @override
  String get revertClearAction => 'Clear staged revert';

  @override
  String get revertNoStage => 'There is no staged revert to review.';

  @override
  String get revertBoundaryLabel => 'Staged from prompt';

  @override
  String get revertPreviewDescription =>
      'These are the file changes reported for this stage. Staging may already have applied them.';

  @override
  String get revertPreviewUnavailable =>
      'The server did not provide a file preview. This does not establish whether files changed.';

  @override
  String get revertPreviewEmpty =>
      'No file changes were reported for this stage.';

  @override
  String get revertStaged => 'Revert staged';

  @override
  String get revertReview => 'Review';

  @override
  String get revertFromHere => 'Revert from this prompt';

  @override
  String get revertUndoDescription =>
      'Stage a revert and review the affected files';

  @override
  String get revertClearShortDescription =>
      'Review and clear the staged revert';

  @override
  String get revertPromptUnavailable =>
      'The boundary prompt could not be loaded.';

  @override
  String get revertPromptLoading => 'Loading the boundary prompt…';

  @override
  String get revertAttachmentPrompt => 'Attachment-only prompt';

  @override
  String get revertResolveBeforeSending =>
      'Review the staged revert, then clear it or make it permanent before sending. Your draft is kept.';

  @override
  String get sessionNoteTitle => 'Note for the agent';

  @override
  String get sessionNoteDescription =>
      'Keep a short instruction for this conversation. Saving or deleting it takes effect at the next agent step and appears in the transcript then. It does not start a run.';

  @override
  String get sessionNoteHint =>
      'For example: Keep explanations brief and run the relevant checks before finishing.';

  @override
  String get sessionNoteSave => 'Save note';

  @override
  String get sessionNoteRemove => 'Delete saved note';

  @override
  String get sessionNoteSaved => 'Note saved';

  @override
  String get sessionNoteRemoved => 'Note deleted';

  @override
  String get sessionNotePending => 'Applies at the next agent step.';

  @override
  String get sessionInstructionsUpdated => 'Instructions updated';

  @override
  String get sessionInstructionsApplied =>
      'The agent\'s conversation instructions have been updated for this step.';

  @override
  String get sessionNoteUnsupported =>
      'This server does not support conversation notes.';

  @override
  String get sessionNoteAuthorization =>
      'Check this server\'s password and permissions, then try again. Your draft is kept.';

  @override
  String get sessionNoteChanged =>
      'The conversation or its instructions changed. Refresh the saved note before saving again. Your draft is kept.';

  @override
  String get sessionNoteInvalid =>
      'The saved note has a format this editor cannot safely change.';

  @override
  String get sessionNoteTooLarge =>
      'Shorten the note to fit the server\'s size limit.';

  @override
  String get sessionNoteBusy =>
      'A note change is already being saved. Try again when it finishes.';

  @override
  String get sessionNoteRefresh => 'Refresh saved note';

  @override
  String get sessionNoteSavedVersion =>
      'Current saved note — review before replacing';

  @override
  String get sessionNoteNone => 'No saved note';

  @override
  String get sessionNoteDiscard => 'Discard your note changes?';

  @override
  String get sessionNoteKeepEditing => 'Keep editing';

  @override
  String get sessionNoteDiscardAction => 'Discard changes';

  @override
  String sessionNoteBytes(int used, int limit) {
    return '$used / $limit bytes';
  }

  @override
  String get usageTitle => 'Usage and cost';

  @override
  String get usageDescription =>
      'Activity recorded by this OpenCode server across your conversations.';

  @override
  String get usageRefresh => 'Refresh usage';

  @override
  String get usageToday => 'Today';

  @override
  String get usageThirtyDays => '30 days';

  @override
  String get usageYear => 'This year';

  @override
  String get usageAllTime => 'All time';

  @override
  String get usageScope => 'Project scope';

  @override
  String get usageAllProjects => 'All projects';

  @override
  String get usageCurrentProject => 'Current project';

  @override
  String get usageLoading => 'Loading usage';

  @override
  String get usageUnsupported =>
      'This server does not support aggregate usage.';

  @override
  String get usageProjectUnavailable =>
      'No current project could be identified. Choose All projects or open a project first.';

  @override
  String get usageTimezoneUnavailable =>
      'Could not read this device\'s timezone. Retry to load correctly dated usage.';

  @override
  String get usageRefreshInterrupted =>
      'The server changed while loading usage. Refresh to try again.';

  @override
  String get usageInvalidResponse =>
      'The server returned incomplete usage data. Refresh to try again.';

  @override
  String get usageAuthorization =>
      'Check this server\'s password and permissions, then refresh.';

  @override
  String get usagePreviousResult =>
      'Showing the previous result for these filters.';

  @override
  String get usageLocationChanged =>
      'The active server or project changed. Reopen Usage from Settings.';

  @override
  String get usageTinyCost => 'Less than \$0.000001';

  @override
  String get usageReportedCost => 'Reported cost · USD';

  @override
  String get usageSessions => 'Conversations';

  @override
  String get usageSubagents => 'Subagent conversations';

  @override
  String get usagePrompts => 'Prompts';

  @override
  String get usageSteps => 'Agent steps';

  @override
  String get usageActiveDays => 'Active days';

  @override
  String get usageStreak => 'Longest streak · days';

  @override
  String get usageEmpty =>
      'No activity in this range. Try a wider range or All projects.';

  @override
  String get usageTokens => 'Tokens';

  @override
  String get usageTotalTokens => 'Total';

  @override
  String get usageInput => 'Input';

  @override
  String get usageOutput => 'Output';

  @override
  String get usageReasoning => 'Reasoning';

  @override
  String get usageCacheRead => 'Cache read';

  @override
  String get usageCacheWrite => 'Cache write';

  @override
  String get usageModels => 'Model usage';

  @override
  String get usageNoModels => 'No model usage was recorded in this range.';

  @override
  String get usageCostShare => 'Share of reported cost';

  @override
  String get usageToolReliability => 'Tool reliability';

  @override
  String get usageToolsUnavailable =>
      'This response does not include tool reliability.';

  @override
  String get usageNoTools => 'No tool calls were recorded in this range.';

  @override
  String get usageNoFinishedTools => 'No finished tool calls yet.';

  @override
  String get usageToolCalls => 'Calls';

  @override
  String get usageSucceeded => 'Succeeded';

  @override
  String get usageFailed => 'Failed';

  @override
  String get usageUnfinished => 'Unfinished';

  @override
  String get usageCostDisclosure =>
      'Costs are estimates reported by OpenCode, not a provider invoice. Unfinished tool calls are excluded from the success rate.';

  @override
  String usagePeriod(String from, String to) {
    return '$from – $to';
  }

  @override
  String usageTimezone(String timezone) {
    return 'Timezone: $timezone';
  }

  @override
  String usageModelSteps(String steps) {
    return '$steps steps';
  }

  @override
  String usageModelTokens(String tokens) {
    return '$tokens tokens';
  }

  @override
  String usageSuccessRate(String rate) {
    return '$rate of finished calls succeeded';
  }

  @override
  String usageUpdated(String time) {
    return 'Updated at $time';
  }

  @override
  String get mcpRuntimeTitle => 'Until server restart';

  @override
  String get mcpRuntimeDescription =>
      'Adds this MCP server to the selected project and tries to connect it now. It is removed when OpenCode restarts. For permanent setup, edit the server configuration.';

  @override
  String get mcpCurrentLocation => 'Current project';

  @override
  String get mcpDefaultLocation => 'OpenCode server’s default directory';

  @override
  String mcpWorkspaceLocation(String workspace) {
    return 'Cloud environment: $workspace';
  }

  @override
  String get mcpLocationChanged =>
      'The server or project changed. Your draft is still here; reopen setup in the intended project before adding it.';

  @override
  String get mcpAdding => 'Adding MCP server';

  @override
  String get mcpAdd => 'Add MCP server';

  @override
  String get mcpRuntimeEmpty =>
      'Add tools for the current project until OpenCode restarts.';

  @override
  String get mcpRuntimeAdded => 'MCP server added for this project';

  @override
  String get sessionUnread => 'Unread result';

  @override
  String get shareSessionViewsTitle => 'Sync read state';

  @override
  String get shareSessionViewsOn =>
      'Let your other OpenCode clients know which completed results you have viewed.';

  @override
  String get shareSessionViewsOff =>
      'Reading stays private to this device. Unread results use local read history.';

  @override
  String get shareSessionViewsSaveError =>
      'Could not save this preference. Read-state sharing is off on this device for now.';

  @override
  String get exportTitle => 'Export conversation';

  @override
  String get exportDescription =>
      'Choose a format to save this conversation on your device.';

  @override
  String get exportJson => 'Complete conversation · JSON';

  @override
  String get exportJsonDescription =>
      'Downloads the full conversation from the server, including older messages.';

  @override
  String get exportMarkdown => 'Readable transcript · Markdown';

  @override
  String get exportMarkdownDescription =>
      'Saves the messages currently loaded in this conversation. Load older messages first if you need them included.';

  @override
  String get exportRedact => 'Redact sensitive data';

  @override
  String get exportRedactDescription =>
      'Replaces conversation text and sensitive fields with placeholders. Turn this off to back up the original text. Review any export before sharing.';

  @override
  String get exportUnredacted =>
      'The unredacted file may contain secrets, local paths, and private tool output.';

  @override
  String get exportSave => 'Save file';

  @override
  String get exportCancel => 'Cancel download';

  @override
  String get exportDownloading => 'Downloading complete conversation…';

  @override
  String get exportSaving => 'Saving file…';

  @override
  String get exportSaved => 'Conversation saved';

  @override
  String get exportChanged =>
      'The server or project changed. Reopen export from the intended conversation.';

  @override
  String get exportUnsupported =>
      'This server does not support JSON export. You can still save the loaded Markdown transcript.';

  @override
  String get exportAuthorization =>
      'The server denied access. Check your server credentials and try again.';

  @override
  String get exportMissing =>
      'This conversation no longer exists on the server. You can still save the loaded Markdown transcript.';

  @override
  String get exportFailed =>
      'Could not export the conversation. Check your connection and storage, then try again.';

  @override
  String get importTitle => 'Import conversation';

  @override
  String get importDescription =>
      'Restore a JSON export to this OpenCode server. Choose a file, then review where it will be imported.';

  @override
  String get importChoose => 'Choose JSON file';

  @override
  String get importChooseAnother => 'Choose another file';

  @override
  String get importAction => 'Import conversation';

  @override
  String get importUntitled => 'Untitled conversation';

  @override
  String importMessageCount(int count) {
    return '$count message records';
  }

  @override
  String get importRedacted =>
      'This file contains redacted placeholders. Import cannot recover the original text; use an unredacted export if you need it.';

  @override
  String importParent(String id) {
    return 'Parent conversation $id must already exist on this server. Import the parent first.';
  }

  @override
  String get importArchived =>
      'This conversation is archived. Import will keep its archived status.';

  @override
  String get importDestination => 'Import into';

  @override
  String get importChooseDestination => 'Choose a project on this server';

  @override
  String get importChangeDestination => 'Change destination';

  @override
  String get importNoDestinations =>
      'No projects are available. Open a project on this server, then try again.';

  @override
  String get importDestinationFailed =>
      'Could not load destination projects or cloud environments. Try again; your file is still selected.';

  @override
  String get importPreserves =>
      'Your source file stays unchanged. Existing conversations are never replaced, and importing does not start an agent run.';

  @override
  String get importReading => 'Preparing import…';

  @override
  String get importSending => 'Importing conversation…';

  @override
  String get importSucceeded => 'Conversation imported';

  @override
  String get importOpen => 'Open conversation';

  @override
  String get importOpenFailed =>
      'The conversation was imported, but could not be opened. Find it in All conversations on the destination server.';

  @override
  String get importChanged =>
      'The server or project changed. Your file is still here. Reopen import on the intended server before continuing.';

  @override
  String get importUnsupported => 'This server does not support JSON import.';

  @override
  String get importInvalidFile =>
      'Choose a valid OpenCode JSON export with conversation information and message records. Markdown transcripts cannot be imported.';

  @override
  String get importTooLarge =>
      'This file exceeds the mobile import limit of 128 MiB. It has not been uploaded or truncated. Use a desktop or server transfer for this file.';

  @override
  String get importConflict =>
      'A conversation with this ID already exists on this server. Nothing was replaced. Find it in All conversations, or import this file on another server.';

  @override
  String get importAuthorization =>
      'The server denied access. Check your server credentials. Your file is still selected.';

  @override
  String get importParentMissing =>
      'The parent conversation is missing from this server. Import the parent first, then retry this file.';

  @override
  String get importRejected =>
      'The server rejected this export format. Your file is still selected; check that it came from a compatible OpenCode server.';

  @override
  String get importUnconfirmed =>
      'Import could not be confirmed. Check All conversations before retrying: the server may have received it. Your source file is unchanged.';

  @override
  String get sessionsNoOtherRecent => 'No other recent conversations';

  @override
  String get sessionPin => 'Pin on this device';

  @override
  String get sessionUnpin => 'Unpin';

  @override
  String get sessionPinned => 'Pinned';

  @override
  String get sessionPinFailed =>
      'Could not save this pin. Check device storage and that the conversation’s project has not changed, then try again.';

  @override
  String get sessionPinsLoadFailed =>
      'Some pinned conversations could not be loaded. Refresh to try again.';

  @override
  String get promptStashSaveFailed =>
      'Could not save this prompt. Your composer is unchanged. Check device storage and try again.';

  @override
  String get promptOriginalDraft => 'Restore original draft';

  @override
  String get promptStashTitle => 'Saved prompts';

  @override
  String get promptStashSearch => 'Search saved prompts';

  @override
  String get promptStashNoMatches =>
      'No saved prompts match your search. Clear or change the search to see more.';

  @override
  String get promptStashDeleteFailed =>
      'Could not delete this saved prompt. Try again.';

  @override
  String get promptRestoreTitle => 'Restore saved prompt?';

  @override
  String get promptRestorePreserve =>
      'Your current prompt will be saved to the stash first, including its attachments and references.';

  @override
  String get promptStashDelete => 'Delete';

  @override
  String get promptStashFull =>
      'Your stash has 50 prompts. Delete a saved prompt to make room; your current prompt is unchanged.';

  @override
  String get promptStashListDescription =>
      'Saved on this device for this server. Restoring a prompt also saves any current prompt for later.';

  @override
  String get promptStashDeleteTitle => 'Delete saved prompt?';

  @override
  String promptStashAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String promptStashReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count references',
      one: '1 reference',
    );
    return '$_temp0';
  }

  @override
  String get promptRestoredCopyKept =>
      'Available content restored. A saved copy remains in your stash. Review attachments and references before sending.';

  @override
  String get promptAttachmentsUnavailable =>
      'Some attachments cannot be restored';

  @override
  String get promptRestore => 'Restore';

  @override
  String get promptHistorySaveFailed =>
      'Prompt sent, but its history could not be saved on this device.';

  @override
  String promptAttachmentsUnavailableDetail(String names) {
    return 'Missing, damaged or temporary attachments: $names. Restore the available content and reattach these files before sending. The saved copy will stay in your stash.';
  }

  @override
  String get promptStashMigrationPending =>
      'Some saved attachments could not be moved to local attachment storage yet. Your saved content has been kept. Free device storage and retry.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get shareWaitingForServer =>
      'Connect to a server and the shared text opens in a new conversation.';

  @override
  String get shareSessionFailed =>
      'Shared text kept. Could not open a conversation. Retry when the connection is ready.';

  @override
  String get webSourcesDisclosure =>
      'Web search is not available through this server’s app gateway. Paste a public URL and optionally an excerpt you want to include. No page is fetched. Nothing is sent to the model here.';

  @override
  String get webSourcesScopeChanged =>
      'Server changed. Close and reopen Add web source.';

  @override
  String get webSourcesUrl => 'Public URL';

  @override
  String get webSourcesLabel => 'Title (optional)';

  @override
  String get webSourcesExcerpt => 'Pasted excerpt (optional)';

  @override
  String get webSourcesExcerptHint =>
      'User-provided text, not verified page content.';

  @override
  String get webSourcesAdd => 'Add to review';

  @override
  String webSourcesReviewCount(int count) {
    return 'Review sources ($count/10)';
  }

  @override
  String get webSourcesReviewHint =>
      'Only checked sources will be returned to your draft.';

  @override
  String get webSourcesEmpty => 'No sources added yet.';

  @override
  String get webSourcesOpen => 'Open in browser';

  @override
  String webSourcesUseCount(int count) {
    return 'Use selected sources ($count)';
  }

  @override
  String get digestTitle => 'Completion digests';

  @override
  String get digestSubtitle => 'On demand · cached metadata, not AI summaries';

  @override
  String get digestEmpty =>
      'No ended-run metadata available in this project. Idle alone does not establish successful completion.';

  @override
  String get digestIdle => 'Server idle recorded · outcome unverified';

  @override
  String get digestStatusUnverified =>
      'Server reported idle. Success or failure is not verified.';

  @override
  String get digestChangedFilesUnknown => 'Changed files: unknown.';

  @override
  String digestChangedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changed files in the conversation total; this run is unknown.',
      one: '1 changed file in the conversation total; this run is unknown.',
      zero: 'No changed files in the conversation total; this run is unknown.',
    );
    return '$_temp0';
  }

  @override
  String get digestPendingDecisionsUnknown => 'Pending decisions: unknown.';

  @override
  String digestPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending decisions in the current cache.',
      one: '1 pending decision in the current cache.',
      zero: 'No pending decisions in the current cache.',
    );
    return '$_temp0';
  }

  @override
  String get digestOutcomesUnknown =>
      'Tool outcomes and remaining tasks: unknown.';

  @override
  String get digestProvenance =>
      'Cached server metadata only. No AI summary or model call. Open the conversation to verify results and review changes or tasks.';

  @override
  String get digestOpenConversation => 'Open conversation';

  @override
  String get digestReview => 'Review next actions';

  @override
  String get digestCopy => 'Copy digest';

  @override
  String get digestCopySucceeded => 'Digest copied';

  @override
  String get digestCopyFailed => 'Could not copy digest';

  @override
  String get digestDismiss => 'Dismiss';

  @override
  String get digestRunResults => 'Run results';

  @override
  String get runResultsScopeChanged =>
      'The server or project changed. Close this view and reopen Run results from the intended project.';

  @override
  String get runResultsTitle => 'Run results';

  @override
  String get runResultsEmpty =>
      'The latest turn has no assistant step yet, so there is nothing to show.';

  @override
  String runResultsRunLabel(String id) {
    return 'Run …$id';
  }

  @override
  String runResultsSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assistant steps',
      one: '1 assistant step',
    );
    return '$_temp0';
  }

  @override
  String runResultsStepsAtLeast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'At least $count assistant steps loaded',
      one: 'At least 1 assistant step loaded',
    );
    return '$_temp0';
  }

  @override
  String runResultsStarted(String time) {
    return 'Started $time';
  }

  @override
  String get runResultsStartedUnknown => 'Start time not recorded';

  @override
  String runResultsFinished(String time) {
    return 'Finished $time';
  }

  @override
  String get runResultsFinishedUnknown => 'Finish time not recorded';

  @override
  String get runResultsPartialHistory =>
      'The message that started this run was not found in the loaded history. Counts here are lower bounds and the run id is only the oldest loaded step.';

  @override
  String get runResultsOutcomeCompleted => 'Completed';

  @override
  String get runResultsOutcomeCutOff => 'Cut off by the provider';

  @override
  String get runResultsOutcomeFailed => 'Failed';

  @override
  String get runResultsOutcomeAborted => 'Aborted';

  @override
  String get runResultsOutcomeRunning => 'Still running';

  @override
  String get runResultsOutcomeNotReported => 'Outcome not reported';

  @override
  String runResultsFinishReason(String finish) {
    return 'Provider finish reason: $finish';
  }

  @override
  String get runResultsFinishReasonMissing =>
      'The provider gave no finish reason.';

  @override
  String runResultsEarlierErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count earlier steps reported errors; the newest step decides the outcome.',
      one:
          'An earlier step reported an error; the newest step decides the outcome.',
    );
    return '$_temp0';
  }

  @override
  String get runResultsObservedLive =>
      'This phone received the completion of the newest step live.';

  @override
  String get runResultsFromHistory =>
      'Recovered from server history. This phone did not observe the newest step complete.';

  @override
  String get runResultsNoToolEvidence =>
      'This run recorded no tool calls, so there is no file or command evidence. That is not the same as no changes.';

  @override
  String get runResultsChangedFilesTitle => 'Changed files';

  @override
  String get runResultsChangedFilesSource =>
      'From completed edit, write and patch tools in this run. Not a verified diff of the working tree.';

  @override
  String get runResultsNoChangedFiles =>
      'No completed file-changing tool in this run.';

  @override
  String get runResultsChangeEdited => 'Edited';

  @override
  String get runResultsChangeWritten => 'Written';

  @override
  String get runResultsChangePatched => 'Patched';

  @override
  String get runResultsCommandsTitle => 'Commands';

  @override
  String get runResultsCommandsSource =>
      'From bash and shell tools in this run. Exit codes appear only when the server recorded them.';

  @override
  String get runResultsNoCommands => 'No commands were run in this run.';

  @override
  String get runResultsCommandEmpty => '(command text not recorded)';

  @override
  String runResultsExit(int code) {
    return 'Exit code $code';
  }

  @override
  String get runResultsExitUnknown => 'Exit code not recorded';

  @override
  String get runResultsCommandFailed => 'Tool reported failure';

  @override
  String get runResultsLooksLikeTest =>
      'Looks like a test command (from the command text only)';

  @override
  String get runResultsOutputPruned => 'Output pruned by the server';

  @override
  String runResultsPrunedTools(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tool outputs were pruned by the server and cannot be opened.',
      one: '1 tool output was pruned by the server and cannot be opened.',
    );
    return '$_temp0';
  }

  @override
  String get runResultsTruncated =>
      'Lists are capped at 50 entries. Open the conversation for the rest.';

  @override
  String get runResultsSourceNote =>
      'Everything here is copied from the server\'s message and tool records. Nothing is summarised by a model.';

  @override
  String get runResultsOutputTitle => 'Recorded tool output';

  @override
  String get runResultsOpenConversation => 'Open conversation';

  @override
  String get attentionDisclosure =>
      'A local overview, not live monitoring across servers. Cached signals may be incomplete or out of date. Open a server to check its current activity.';

  @override
  String get attentionNavigationUnavailable =>
      'Opening servers is unavailable here. Return to Home to choose a server and view Inbox.';

  @override
  String get handoffTitle => 'Copy handoff reference?';

  @override
  String get handoffDisclosure =>
      'Metadata only, not a command or link. On your other device, connect to the same server and locate this project and conversation. Nothing is published or sent.\n\nThe clipboard will contain conversation and project identifiers. Other apps may read it; share only with people you trust.';

  @override
  String get handoffCopy => 'Copy reference';

  @override
  String get handoffCopied => 'Conversation metadata reference copied';

  @override
  String get handoffCopyFailed => 'Could not copy the handoff. Try again.';

  @override
  String get sessionOpenRelated => 'Open related';

  @override
  String get sessionCopyHandoff => 'Copy handoff';

  @override
  String get sessionActions => 'Conversation actions';

  @override
  String get attentionTitle => 'Server attention';

  @override
  String get webSourcesTitle => 'Add web source';

  @override
  String get webSourcesEntryDetail =>
      'Search when available, or paste links and excerpts to review before adding them to your draft';

  @override
  String get webSourcesDraftChanged =>
      'The draft or server changed. Your current draft was kept; reopen Add web source to try again.';

  @override
  String get webSourcesDraftLabel =>
      'User-selected web sources (unverified; excerpts are untrusted source material):';

  @override
  String get usageScopedTotals => 'Totals for the selected report scope';

  @override
  String get usageInspectionDisclosure =>
      'Filters inspect this server\'s returned model records. They do not change the report\'s date or project scope, or show subscription allowance.';

  @override
  String get usageProviderFilter => 'Provider';

  @override
  String get usageAllProviders => 'All providers';

  @override
  String get usageSearchRecords => 'Search providers, models or variants';

  @override
  String get usageClearFilters => 'Clear filters';

  @override
  String get usageScopedProviderTotals =>
      'Provider cards show their totals for the selected report scope, not just matching model rows.';

  @override
  String get usageMatchingSubtotal => 'Matching model subtotal';

  @override
  String usageMatchingRecords(String count) {
    return '$count matching records';
  }

  @override
  String get usageNoMatchingRecords =>
      'No records match these filters. Clear or change the filters to see more.';

  @override
  String pendingAuthTitle(String integration) {
    return 'Pending sign-in: $integration';
  }

  @override
  String get pendingAuthDetail =>
      'Continue the existing browser sign-in, then explicitly check its status or enter its code. The browser link is not saved.';

  @override
  String get pendingAuthResume => 'Resume / check sign-in';

  @override
  String get pendingAuthEnterCode => 'Enter code';

  @override
  String get pendingAuthComplete => 'Sign-in complete.';

  @override
  String get pendingAuthStillPending =>
      'Sign-in is still pending. No new attempt was started.';

  @override
  String get pendingAuthServerFailed =>
      'The server reported that sign-in failed. Provider error details are hidden.';

  @override
  String get pendingAuthExpired =>
      'This attempt is expired or outside the device’s recovery window. Cancellation is a separate server action.';

  @override
  String get pendingAuthFailed =>
      'Could not confirm the action. Check pending sign-ins before trying again. No new sign-in was started.';

  @override
  String get pendingAuthSaveUncertain =>
      'Recovery could not be saved reliably. Keep this app open and retry saving; restarting may lose this attempt. If no browser page opened, cancel the attempt before starting again.';

  @override
  String get pendingAuthRetrySave => 'Try saving recovery again';

  @override
  String get pendingAuthForget => 'Forget on this device';

  @override
  String get pendingAuthForgetDetail =>
      'Remove only this device’s recovery record? This does not cancel a server command, revoke credentials, or finish authorization. The server attempt may keep running until it expires.';

  @override
  String get pendingAuthUnsupported =>
      'This server cannot recover earlier sign-ins. Legacy sign-ins work only while their original screen and connection remain available.';

  @override
  String get pendingAuthOtherSource =>
      'Other pending sign-ins belong to another server or project. Return to their original source to manage them.';

  @override
  String get connectionHelpTitle => 'Connection help';

  @override
  String get connectionHelpEntrySubtitle =>
      'Explain an address locally, without connecting';

  @override
  String get connectionHelpGuideTip =>
      'Keep the server off the public internet. Use private HTTPS or an encrypted tunnel ending on the device running this app. Localhost on your computer is not localhost on your phone. Open Connection help above for steps and examples.';

  @override
  String get connectionHelpPrivacy =>
      'This checks address rules only, not connectivity. Nothing is sent or saved. Input is hidden and cleared after checking. Paste only an address, not a password or pairing code.';

  @override
  String get connectionHelpAddress => 'Server address';

  @override
  String get connectionHelpCheck => 'Explain address';

  @override
  String get connectionHelpEmpty => 'Enter a server address to explain.';

  @override
  String get connectionHelpMalformed =>
      'This address could not be understood. Use a complete origin such as https://server.example, with no path, credentials or query.';

  @override
  String get connectionHelpCredentials =>
      'Credentials do not belong in a URL. Remove them and enter the server username and password separately in Servers. The pasted value has been cleared.';

  @override
  String get connectionHelpQuery =>
      'Remove query parameters and fragments. They can contain secrets; enter only the server origin. The pasted value has been cleared.';

  @override
  String get connectionHelpPath =>
      'Remove the path. This app needs the server origin, not a page or API route.';

  @override
  String get connectionHelpScheme =>
      'Use HTTPS for a remote server, or HTTP only for this device\'s supported loopback addresses.';

  @override
  String get connectionHelpRemoteHttp =>
      'Remote HTTP is blocked, including LAN and 100.64.0.0/10 addresses. A VPN does not change this rule. Set up private HTTPS or an encrypted tunnel ending on this device.';

  @override
  String get connectionHelpHttps =>
      'This address passes the HTTPS address rules. That does not verify its certificate, reachability, sign-in or privacy. A bare remote address is interpreted as HTTPS.';

  @override
  String get connectionHelpLoopback =>
      'This address passes the loopback address rules. Localhost means this device, not another computer. A server or tunnel must be listening here; this check does not verify that.';

  @override
  String get connectionHelpPrivateTitle => 'Private HTTPS or reverse proxy';

  @override
  String get connectionHelpPrivateSteps =>
      '1. Keep the server on its host\'s loopback with authentication enabled.\n2. Connect both devices to your private network and restrict access to intended users.\n3. Configure private HTTPS, such as Tailscale Serve, or a reverse proxy with a trusted certificate forwarding to the server. Support streaming and WebSockets.\n4. Add the HTTPS origin in Servers with sign-in in separate fields.\nTailscale Funnel exposes the service publicly; it is not a private-network fix. This app cannot infer VPN presence. The example below is a placeholder.';

  @override
  String get connectionHelpTunnelTitle => 'Localhost on the wrong device?';

  @override
  String get connectionHelpTunnelSteps =>
      'Localhost, 127.0.0.1 and [::1] refer to the device running this app. For a server on another computer, use private HTTPS or an encrypted tunnel ending here. If an SSH client is available on this device, adapt the example below, verify the host key and keep it running. Replace user@host with your SSH destination. Running it on another computer does not forward this device\'s port. Keep server authentication enabled.';

  @override
  String get connectionHelpVerifyTitle => 'Verify connectivity separately';

  @override
  String get connectionHelpVerifySteps =>
      'On this device, check private-network membership, DNS, firewall access and certificate trust using your network tools. Check server and proxy configuration on the host, then use Servers to connect. Never disable TLS verification or share passwords, pairing codes or unredacted logs. Access to this server is shell access.';

  @override
  String get connectionHelpCopyExample => 'Copy example';

  @override
  String get connectionHelpCopied => 'Example copied';

  @override
  String get connectionHelpCopyFailed =>
      'Could not copy the example. Select the example text to copy it manually.';

  @override
  String get voiceConversationTitle => 'Voice conversation';

  @override
  String get voiceConversationDescription =>
      'Listen, review, then Send. No automatic listening; replies are read aloud only if you turn that on.';

  @override
  String get voiceConversationSpeakReplies => 'Speak replies';

  @override
  String get voiceConversationSpeakRepliesDetail =>
      'Read a matched reply once after Send. Tap Listen to use the microphone.';

  @override
  String get voiceConversationWaitingReply => 'Waiting for the reply…';

  @override
  String get voiceConversationSpeakingReply => 'Speaking the reply';

  @override
  String get voiceConversationStopReply => 'Stop';

  @override
  String get voiceConversationReadReply => 'Read reply';

  @override
  String get voiceConversationReplyReviewNeeded =>
      'The reply finished, but it could not be matched to your message for certain. Read it if you want.';

  @override
  String get voiceConversationReplyInterrupted =>
      'The reply needed a decision on screen, so it was not read automatically.';

  @override
  String get voiceConversationReplyNoProse =>
      'The reply has no prose to read. Code and tool details are not spoken.';

  @override
  String get voiceConversationReplyFailed =>
      'The reply could not be read aloud.';

  @override
  String get voiceConversationPausedTitle => 'Voice conversation paused';

  @override
  String get voiceConversationPausedDetail =>
      'Voice conversation is paused. Reconnect, wait for the reply, or review pending decisions on screen.';

  @override
  String get voiceConversationDraftFirst =>
      'Send, save, or clear your current draft before starting voice conversation.';

  @override
  String get voiceConversationListen => 'Listen';

  @override
  String get voiceConversationExit => 'Exit voice mode';

  @override
  String get voiceConversationCommandsOnly =>
      'Use the typed composer for slash commands.';

  @override
  String get voiceConversationInterrupted =>
      'Voice conversation was interrupted. Review before sending again.';

  @override
  String get voiceReviewExplicitAction =>
      'Edit before inserting. Sending always requires an explicit action.';

  @override
  String get voiceInputInterrupted =>
      'Voice input was interrupted. Close and start again when ready.';

  @override
  String get voiceInputClose => 'Close voice input';

  @override
  String get voiceInputUnavailable =>
      'Voice input is unavailable. Check the local model and microphone settings.';

  @override
  String get voiceConversationInstructions =>
      'Review and insert your transcript, then tap Send in the composer. Replies are read aloud only while Speak replies is on, and only the reply to what you just sent. Unsent text is discarded when you leave voice mode, the conversation, or the app.';

  @override
  String get desktopDropFailedTitle => 'Could not attach dropped files';

  @override
  String get desktopDropFailedRecovery =>
      'Check the attachments already added before trying again. You can also use the keyboard to open Add, then Attach file.';

  @override
  String get desktopContextMenuShortcutKeys =>
      'Right click / Shift + F10 / Menu';

  @override
  String get commandAuthManage => 'Server sign-in';

  @override
  String get commandAuthMethodHint =>
      'Runs the provider\'s sign-in method on your selected server, not on this phone. You may need to finish interactive steps on the server.';

  @override
  String get commandAuthConfirmTitle => 'Start sign-in on the server?';

  @override
  String get commandAuthConfirmDetail =>
      'OpenCode will execute this provider\'s declared sign-in method on the selected server. Continue only if you trust that server and provider. The app does not run or copy a shell command on your phone.';

  @override
  String get commandAuthStart => 'Start server sign-in';

  @override
  String get commandAuthPending =>
      'Sign-in is pending on the server. Finish any server-side interaction, then check its status. Closing this sheet does not cancel it.';

  @override
  String get commandAuthCheck => 'Check sign-in';

  @override
  String get commandAuthCancel => 'Cancel sign-in';

  @override
  String get commandAuthFailed =>
      'Could not complete or confirm server sign-in. Check the existing attempt before starting another.';

  @override
  String get commandAuthComplete =>
      'The server reported that sign-in completed. Refresh Providers to see its current connections.';

  @override
  String get commandAuthExpired =>
      'This sign-in attempt expired. You can start a new attempt.';

  @override
  String get commandAuthScopeChanged =>
      'The server or project changed. Return to the original project and reopen sign-in to manage its attempt.';

  @override
  String get commandAuthUncertainStart =>
      'The server may have started sign-in, but the app could not safely recover its attempt. Check on the server before retrying; automatic restart is blocked to avoid duplicate processes.';

  @override
  String get readAloudAction => 'Read reply prose';

  @override
  String get readAloudStop => 'Stop reading aloud';

  @override
  String get readAloudOtherVoice => 'Read with another voice';

  @override
  String get readAloudChooseVoice => 'Choose a reading voice';

  @override
  String get readAloudConsentTitle => 'Use the system speech engine?';

  @override
  String get readAloudConsentDetail =>
      'The loaded reply prose will be sent to your system speech engine. Only voices marked offline are offered, but the engine is separate software and its privacy practices apply. Code blocks and tool details are omitted. Others may hear the audio. Playback stops when this conversation is covered or the app goes into the background.';

  @override
  String get readAloudContinue => 'Choose voice';

  @override
  String get readAloudUnsupported =>
      'Read-aloud is not available on this platform.';

  @override
  String get readAloudNoVoice =>
      'No installed voice marked offline is available. Configure an offline voice in your system speech settings and try again.';

  @override
  String get readAloudUnavailable =>
      'The speech engine could not read this reply. Try again or choose another voice.';

  @override
  String get readAloudTooLong =>
      'This reply is too long to read aloud. Choose a shorter reply.';

  @override
  String get readAloudBusy =>
      'Speech playback is unavailable while audio capture or another audio interruption is active.';

  @override
  String get readAloudNoProse =>
      'There is no reply prose to read. Code and tool details are not spoken.';

  @override
  String get credentialManage => 'Manage accounts';

  @override
  String get credentialMetadataOnly =>
      'Only saved account labels are shown. API keys and login tokens stay on your server.';

  @override
  String get credentialActiveUnknown =>
      'Active account unknown. The saved-account list does not report which account is active.';

  @override
  String get credentialNoneActive =>
      'The server reported no active saved account.';

  @override
  String get credentialActiveObserved =>
      'The Active badge reflects the latest server event.';

  @override
  String get credentialActiveUpdated =>
      'Active account updated from the server.';

  @override
  String get credentialSwitchRequested =>
      'Switch requested. This request has not yet been confirmed by a server event.';

  @override
  String get credentialActive => 'Active';

  @override
  String get credentialSetActive => 'Set active';

  @override
  String get credentialRename => 'Rename account';

  @override
  String get credentialLabel => 'Account label';

  @override
  String get credentialSave => 'Save label';

  @override
  String credentialRemoveTitle(String label) {
    return 'Remove $label?';
  }

  @override
  String get credentialRemoveDetail =>
      'Remove this saved sign-in from the server. Other projects using it may be affected. This does not edit environment configuration; the server determines which account, if any, becomes active afterward.';

  @override
  String get credentialScopeChanged =>
      'The server or project changed. Close and reopen account management before making changes.';

  @override
  String get credentialProviderMissing =>
      'This provider is no longer in the server\'s integration list.';

  @override
  String get credentialLoadFailed =>
      'Could not refresh saved accounts. Try again.';

  @override
  String get credentialMutationFailed =>
      'Could not confirm the account change. Refresh before retrying; the server may already have applied it.';

  @override
  String get credentialRefresh => 'Refresh accounts';

  @override
  String get credentialEmpty =>
      'No saved accounts were reported for this provider.';

  @override
  String get credentialEnvironment =>
      'Managed by the server environment. It cannot be removed here.';

  @override
  String credentialUnnamed(int index) {
    return 'Saved account $index';
  }

  @override
  String get mcpRemove => 'Remove';

  @override
  String mcpRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get mcpRemoveRuntimeDetail =>
      'Remove this MCP server from the current project’s runtime. Its tools will no longer be available there. This does not erase persistent server configuration; it may return after a server restart.';

  @override
  String get mcpRemoveFailed =>
      'Could not confirm MCP removal. Refresh the list before trying again; the server may already have applied the change.';

  @override
  String get mcpLoadFailed => 'Could not refresh MCP data. Try again.';

  @override
  String get mcpSavedStatus => 'Saved in OpenCode';

  @override
  String get mcpConnectionUnconfirmed => 'App connection not confirmed';

  @override
  String get mcpRetryReconnect => 'Try reconnecting again';

  @override
  String get mcpReconnecting => 'Reconnecting';

  @override
  String get mcpStillDisconnected =>
      'OpenCode is still disconnected. Try again.';

  @override
  String get mcpScopeChanged =>
      'The server or project changed. Refresh to load its MCP servers before making changes.';

  @override
  String get promptStashRestoreFailed =>
      'Could not finish restoring the prompt. Saved copies remain available; check the composer before trying again.';

  @override
  String get promptStashEmpty =>
      'Nothing saved yet. Use Stash current prompt in Prompt tools to keep a prompt for later.';

  @override
  String get promptStashContextOnly => 'Attachments and references';

  @override
  String get promptRestoredReferences =>
      'Prompt restored. Saved references are snapshots; their server files may have changed.';

  @override
  String get promptDefaultLocation => 'the server default directory';

  @override
  String get promptStashed => 'Prompt saved to your stash.';

  @override
  String get promptStashedDraftPending =>
      'Prompt saved to your stash. The composer draft still needs to be saved; try again from the draft warning.';

  @override
  String get promptStashReadFailed =>
      'Could not read saved prompts. Their stored data has been kept.';

  @override
  String get promptStashDeleteDetail =>
      'This removes the saved text, attachments and references from this device.';

  @override
  String get promptStashDescription =>
      'Save text, attachments and references for later';

  @override
  String get promptRestoreAvailable => 'Restore available content';

  @override
  String get promptRestored => 'Prompt restored. Review it before sending.';

  @override
  String get promptStashAction => 'Stash current prompt';

  @override
  String promptStashLocation(String directory) {
    return 'This prompt refers to files in $directory. Switch to its original project before restoring it.';
  }

  @override
  String get promptStashScopeChanged =>
      'The server or project changed. Close and reopen Saved prompts.';

  @override
  String get transcriptFindTitle => 'Find in conversation';

  @override
  String get transcriptFindHint => 'Search conversation';

  @override
  String get transcriptFindScope => 'Messages, reasoning and tool data';

  @override
  String get transcriptFindClose => 'Close search';

  @override
  String get transcriptFindPrevious => 'Previous match';

  @override
  String get transcriptFindNext => 'Next match';

  @override
  String get transcriptFindNone => 'No matches';

  @override
  String transcriptFindCount(int current, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$current of $total matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String transcriptFindTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches in message text',
      one: '1 match in message text',
    );
    return '$_temp0';
  }

  @override
  String get transcriptFindPartial =>
      'Loaded messages only. Load older messages to search further.';

  @override
  String get transcriptFindComplete =>
      'All available message content searched.';

  @override
  String get transcriptFindReasoning => 'Reasoning';

  @override
  String get transcriptFindTool => 'Tool data';

  @override
  String get transcriptFindFile => 'File name';

  @override
  String get transcriptFindAll => 'Search all history';

  @override
  String get skillMenu => 'Use a skill';

  @override
  String get skillUse => 'Add to conversation';

  @override
  String get skillActivationHelp =>
      'Adds these skill instructions to this conversation. Your unsent draft stays in the composer.';

  @override
  String get skillRunNow => 'Run agent now';

  @override
  String get skillRunHelp =>
      'Turn off to add the skill without starting another response.';

  @override
  String get skillLocationChanged =>
      'The server or project changed. Reopen Skills from the conversation.';

  @override
  String get skillUnsupported =>
      'Skill activation is unavailable on this server. You can still preview skills.';

  @override
  String get skillStaged =>
      'Resolve the staged revert in the conversation before adding a skill.';

  @override
  String get skillBusy =>
      'A skill is already being added to this conversation.';

  @override
  String get skillUncertain =>
      'The server did not confirm the result. The skill may have been added. Close this sheet and check the conversation before trying again.';

  @override
  String get skillApplied => 'Skill added to this conversation.';

  @override
  String get skillAppliedOriginal =>
      'Skill added to the original conversation. Close this sheet to return.';

  @override
  String get activeContextTitle => 'Active context';

  @override
  String get activeContextSubtitle => 'Inspect messages after compaction';

  @override
  String get activeContextHelp =>
      'Active messages returned by the server after its latest compaction. Message counts are not token counts.';

  @override
  String get activeContextRefresh => 'Refresh active context';

  @override
  String get activeContextSearch => 'Search active messages';

  @override
  String get activeContextAll => 'All';

  @override
  String activeContextCount(int shown, int total) {
    return '$shown of $total messages';
  }

  @override
  String get activeContextEmpty =>
      'The server returned no active context messages.';

  @override
  String get activeContextNoMatches =>
      'No active messages match these filters.';

  @override
  String get activeContextNoText => 'No supported text content in this entry.';

  @override
  String get activeContextUnsupported =>
      'Active context inspection is unavailable on this server.';

  @override
  String get activeContextChanged =>
      'The server, project or conversation changed. Reopen this inspector from the conversation.';

  @override
  String get activeContextInvalid =>
      'The server returned an invalid context snapshot. Refresh to try again.';

  @override
  String activeContextRefreshFailed(String error) {
    return 'Showing the previous snapshot. Could not refresh: $error';
  }

  @override
  String get activeContextContentHelp =>
      'Snapshot of available message content. Binary attachment bodies, URLs and internal metadata are not displayed. This is not the complete provider request.';

  @override
  String get activeContextUser => 'User prompt';

  @override
  String get activeContextAssistant => 'Assistant';

  @override
  String get activeContextSystem => 'System instructions';

  @override
  String get activeContextSynthetic => 'Synthetic message';

  @override
  String get activeContextSkill => 'Skill';

  @override
  String get activeContextShell => 'Shell';

  @override
  String get activeContextCompaction => 'Compaction';

  @override
  String get activeContextChange => 'Conversation change';

  @override
  String get activeContextText => 'Text';

  @override
  String get activeContextToolInput => 'Tool input';

  @override
  String get activeContextToolOutput => 'Tool output';

  @override
  String get activeContextFile => 'File attachment';

  @override
  String get activeContextNotice => 'Server notice';

  @override
  String get activeContextPruned => 'Content pruned by the server';

  @override
  String get activeContextTruncated => 'Output truncated by the server';

  @override
  String get draftSaveFailed => 'Draft not saved. Copy your text or retry.';

  @override
  String get draftStorageFull =>
      'Draft storage is full. Copy your text before leaving.';

  @override
  String get draftProfileRemoved =>
      'The original server was removed. Copy your draft to keep it.';

  @override
  String get draftRetrySave => 'Try saving draft again';

  @override
  String get draftClearFailed =>
      'Could not clear the saved draft. Retry before leaving.';

  @override
  String activeContextTypeCount(String type, int count) {
    return '$type · $count';
  }

  @override
  String activeContextPartHeading(String kind, String name) {
    return '$kind · $name';
  }

  @override
  String get draftLeaveTitle => 'Draft could not be saved';

  @override
  String get draftLeaveMessage =>
      'Keep editing to copy your text or retry saving. Leaving now may lose your unsaved changes.';

  @override
  String get draftLeaveAction => 'Leave without saving';

  @override
  String get draftKeepEditing => 'Keep editing';

  @override
  String get draftUnsaved => 'Unsaved';

  @override
  String get draftAttachmentsLocal =>
      'Attachments save with this draft on this device.';

  @override
  String get draftAttachmentsFailed =>
      'Attachments need recovery or could not be saved. Retry before sending.';

  @override
  String get draftAttachmentRecoveryTitle => 'Some attachments need attention';

  @override
  String draftAttachmentRecoveryDetail(String names) {
    return 'These saved attachments are missing, unreadable, or belong to another project: $names. Use the available attachments and remove these from the draft, or keep the saved draft and retry later.';
  }

  @override
  String get draftUseAvailableAttachments => 'Use available attachments';

  @override
  String get draftKeepSavedAttachments => 'Keep saved draft';

  @override
  String get photoLibraryAction => 'Photo library';

  @override
  String get photoLibraryDescription => 'Choose a photo or screenshot';

  @override
  String get photoCameraAction => 'Take photo';

  @override
  String get photoTooLarge => 'Choose a photo smaller than 10 MB.';

  @override
  String get photoStorageFailed =>
      'The photo could not be saved on this device. Free some space and retry.';

  @override
  String get photoPendingOther =>
      'A photo is waiting in its original conversation. Keep it there, or discard it before choosing another photo.';

  @override
  String get photoUnavailable =>
      'The photo could not be opened. Try adding it again from Photo library or Take photo.';

  @override
  String get photoPermissionDenied =>
      'Photo access was denied. Allow camera or photo access in Android app settings, then try again.';

  @override
  String get photoPendingTitle => 'Pending photo';

  @override
  String get photoDiscard => 'Discard pending photo';

  @override
  String get photoAddToDraft => 'Add recovered photo to draft';

  @override
  String get photoOtherLocation =>
      'Return to the photo\'s original server and project before adding it.';

  @override
  String get photoDraftFull =>
      'Remove an attachment first. A draft holds up to 5 files and 20 MB in total.';

  @override
  String get legacyDraftsTitle => 'Older drafts';

  @override
  String get legacyDraftsDescription =>
      'Review drafts saved before server tracking';

  @override
  String get legacyDraftsExplanation =>
      'These drafts have no recorded server. Review their text before using it in this conversation.';

  @override
  String get legacyDraftInsertExplanation =>
      'Insert adds this text after your current draft. The original saved copy stays here until you delete it.';

  @override
  String get legacyDraftTextOnly =>
      'Only text can be inserted here. Any saved attachments remain with the older draft.';

  @override
  String get legacyDraftDelete => 'Delete saved copy';

  @override
  String get legacyDraftDeleteExplanation =>
      'Permanently remove this older draft and its saved attachments from this device?';

  @override
  String get legacyDraftDeleteFailed =>
      'The draft changed or could not be removed. Reopen it and retry.';

  @override
  String get legacyDraftInsert => 'Insert into draft';

  @override
  String get legacyDraftSearch => 'Search older drafts';

  @override
  String get legacyDraftsEmpty => 'No older drafts found';

  @override
  String get legacyDraftLocationChanged =>
      'The project changed. Reopen Older drafts to choose where to insert the text.';

  @override
  String get quotaTitle => 'Remaining usage';

  @override
  String get quotaDescription =>
      'Choose a provider to view its reported account windows. These are separate from OpenCode token usage and cost.';

  @override
  String get quotaSource => 'Collector server';

  @override
  String quotaSourceTitle(String profile, String provider) {
    return '$profile · $provider';
  }

  @override
  String get quotaUnknownSource => 'No saved server';

  @override
  String get quotaSourceChanged =>
      'The server or project changed, or its local data is being removed. Reopen Remaining usage to review the source again.';

  @override
  String get quotaSetupTitle => 'An optional collector is required';

  @override
  String get quotaSetupDescription =>
      'Your server operator must install and protect this route at the same origin as OpenCode. Reading it uses this saved server\'s sign-in. Confirm only if you installed or trust that deployment. Provider tokens stay on the server.';

  @override
  String get quotaSetupGuide =>
      'Setup instructions are in tool/quota/README.md in the app repository. This screen does not install services or remember permission after you leave.';

  @override
  String get quotaSetupNeeded =>
      'Use a saved server with a password and HTTPS, or phone loopback. Update its connection settings before checking the collector.';

  @override
  String get quotaConsent =>
      'I installed and trust this collector on this server.';

  @override
  String get quotaRead => 'Read remaining usage';

  @override
  String get quotaRefresh => 'Refresh remaining usage';

  @override
  String get quotaLoading => 'Reading remaining usage';

  @override
  String get quotaForgetConsent => 'Stop using this collector';

  @override
  String get quotaCollectorAuth =>
      'The collector route did not accept this server sign-in. Ask the server operator to check its authentication setup.';

  @override
  String get quotaCollectorMissing =>
      'The optional collector route is not available on this server. Check its installation and proxy routing.';

  @override
  String get quotaUnavailable =>
      'Remaining usage could not be refreshed. Check the connection and collector, then retry.';

  @override
  String get quotaInvalidResponse =>
      'The collector returned an unsupported or invalid snapshot. No new allowance is shown.';

  @override
  String get quotaUnconfigured =>
      'The collector has no authorized account source configured. Ask its operator to finish setup.';

  @override
  String get quotaProviderUnsupported =>
      'The selected OAuth login or provider usage route is not supported by this collector.';

  @override
  String get quotaProviderAuth =>
      'Sign in again using the provider\'s existing login tool on the server. This app does not read or refresh that login.';

  @override
  String get quotaRateLimited =>
      'The provider limited quota checks. Wait before refreshing; this does not prove your coding allowance is exhausted.';

  @override
  String get quotaAccountUnverified =>
      'The collector could not verify the selected account. No allowance is shown. Check the login source on the server.';

  @override
  String get quotaCodexAccount => 'Codex account windows';

  @override
  String quotaPlan(String plan) {
    return 'Reported plan: $plan';
  }

  @override
  String quotaChecked(String time) {
    return 'Snapshot checked $time';
  }

  @override
  String get quotaStale =>
      'Previous snapshot — refresh to check the latest allowance.';

  @override
  String get quotaUseBlocked =>
      'The provider reports that ordinary Codex use is currently blocked. Window percentages alone do not determine access.';

  @override
  String get quotaNotReported => 'Not reported';

  @override
  String get quotaPrimaryWindow => 'Primary window';

  @override
  String get quotaSecondaryWindow => 'Secondary window';

  @override
  String quotaOtherWindow(int number) {
    return 'Usage window $number';
  }

  @override
  String quotaRemaining(String percent) {
    return '$percent remaining';
  }

  @override
  String quotaWindowRemainingLabel(String window) {
    return '$window: remaining percentage';
  }

  @override
  String quotaUsed(String percent) {
    return '$percent used';
  }

  @override
  String quotaResetAt(String time) {
    return 'Reported reset: $time';
  }

  @override
  String get quotaResetUnknown => 'Reset time not reported';

  @override
  String get quotaResetPassed =>
      'Reset time passed — refresh to check. The displayed allowance has not been replenished locally.';

  @override
  String quotaDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day window',
      one: '1-day window',
    );
    return '$_temp0';
  }

  @override
  String quotaHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-hour window',
      one: '1-hour window',
    );
    return '$_temp0';
  }

  @override
  String quotaSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-second window',
      one: '1-second window',
    );
    return '$_temp0';
  }

  @override
  String get quotaSourceDisclosure =>
      'Read-only snapshot from the optional collector using an internal provider endpoint. Other product allowances, model-specific limits, credits and eligibility are not included. Missing data is unknown, not unlimited.';

  @override
  String get quotaCodex => 'Codex';

  @override
  String get quotaClaude => 'Claude';

  @override
  String get quotaClaudeUnavailable =>
      'Claude subscription usage is unavailable here pending a supported, permitted integration. Current OpenCode does not include Claude Pro/Max sign-in. This app will not read or reuse that subscription login.';

  @override
  String get iosAppTitle => 'OpenCode for iOS';

  @override
  String get iosRemoteSummary =>
      'A remote client for the OpenCode server you choose. On-device server hosting and background monitoring are not available in this iOS build.';

  @override
  String get iosKeychainGuide =>
      'Server passwords use this device\'s Keychain. They are not stored in plain app preferences.';

  @override
  String get platformSecureStorageGuide =>
      'Server passwords use this platform\'s secure credential storage. They are not stored in plain app preferences.';

  @override
  String get quotaClaudeAccount => 'Claude login windows';

  @override
  String get quotaSourceBound =>
      'Tied to the collector\'s configured Claude login. The usage response does not independently identify the account.';

  @override
  String get usageProviders => 'Providers';

  @override
  String get usageProviderScope =>
      'Totals from this server\'s returned model records for the selected scope. Not provider billing or subscription allowances.';

  @override
  String usageProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String get usageProviderCostUnavailable => 'Cost subtotal unavailable';

  @override
  String usageProviderCostShare(String percent) {
    return '$percent of reported cost';
  }

  @override
  String get setupOutputWaiting => 'Waiting for Termux output…';

  @override
  String get setupOutputWaitingDetail =>
      'Setup messages will appear here when Termux responds.';

  @override
  String get setupStartInstalled => 'Start installed OpenCode';

  @override
  String get setupMissingCredential =>
      'This app has no saved credential for that installation. Connect with its server address, or run setup to configure it.';

  @override
  String get setupUbuntuOption => 'Managed Ubuntu installation';

  @override
  String get setupOwnOption => 'Use your own setup';

  @override
  String get setupOwnDescription =>
      'Connect an existing OpenCode 1 or OpenCode 2 server by address. A native musl installation needs a compatible Linux environment and is not managed by this app.';

  @override
  String get setupConnectExisting => 'Connect existing server';

  @override
  String get setupScreenTitle => 'On this phone';

  @override
  String get setupInstallStart => 'Install & start';

  @override
  String get setupCheckAgain => 'Try again';

  @override
  String uncertainAuthTitle(String integrationID) {
    return 'Unconfirmed sign-in: $integrationID';
  }

  @override
  String get uncertainAuthDetail =>
      'The server may have started sign-in, but no attempt ID was received. Check on the server before starting again.';

  @override
  String get uncertainAuthForgetTitle => 'Forget uncertain start?';

  @override
  String get uncertainAuthForgetDetail =>
      'This clears only the local retry block. It does not cancel sign-in on the server. Check the server first to avoid running a second sign-in. No new sign-in will start.';

  @override
  String get uncertainAuthForget => 'Forget uncertain start';

  @override
  String get uncertainAuthCloseHint =>
      'Close this sheet and use the unconfirmed sign-in row to clear its local retry block after checking the server.';

  @override
  String get pluginsDescription =>
      'Plugins reported for this project on the server. Inspect status and source here; manage plugins on the server.';

  @override
  String get pluginsUnsupported =>
      'This server does not support plugin inspection.';

  @override
  String get pluginsDisconnected =>
      'Connect to a server to inspect its plugins.';

  @override
  String get pluginsEmpty => 'No plugins reported for this project.';

  @override
  String get pluginsLoadFailed => 'Could not load plugins. Try again.';

  @override
  String get pluginsRefresh => 'Refresh plugins';

  @override
  String get pluginsRetry => 'Try again';

  @override
  String get pluginsUnnamed => 'Plugin without an ID';

  @override
  String get pluginsStatusActive => 'Active';

  @override
  String get pluginsStatusFailed => 'Failed';

  @override
  String get pluginsStatusUnknown => 'Unknown status';

  @override
  String get pluginsSourceBuiltin => 'Built in';

  @override
  String get pluginsSourcePackage => 'Package';

  @override
  String get pluginsSourceLocal => 'Local file (path hidden)';

  @override
  String get pluginsSourceSdk => 'SDK';

  @override
  String get pluginsSourceUnknown => 'Unknown source';

  @override
  String get pluginsTerminalUi => 'Terminal UI declared';

  @override
  String get pluginsFailureDetail =>
      'Failure details are hidden because they may contain credentials.';

  @override
  String get demoReviewChanges => 'Review changes';

  @override
  String get demoSetUpServer => 'Set up your own server';

  @override
  String get handoffCommandTitle => 'Continue on computer';

  @override
  String get handoffCommandDisclosure =>
      'Run this command in a POSIX shell on a computer with OpenCode installed and access to this server. Set OPENCODE_SERVER_PASSWORD privately on that computer if the server requires it. The clipboard will contain the server address, username, project directory and conversation ID, but no password.';

  @override
  String get handoffCopyCommand => 'Copy command';

  @override
  String get handoffCommandCopied => 'Resume command copied';

  @override
  String get handoffCommandUnavailable =>
      'A resume command is unavailable for this server or cloud environment. Continuing on another computer needs a supported OpenCode command and a reachable HTTPS server; a localhost address points to each device itself. You can still copy the conversation metadata below.';

  @override
  String get quotaMiniMax => 'MiniMax';

  @override
  String get quotaMiniMaxAccount => 'MiniMax subscription windows';

  @override
  String get quotaMiniMaxSourceBound =>
      'Tied to the collector\'s configured MiniMax Subscription Key. The quota response does not independently identify the account. Only reported general-pool percentages are shown; other limits may apply.';

  @override
  String get managedHealthTitle => 'On-device server';

  @override
  String get managedHealthUnchecked =>
      'Check the server managed by this app in Termux.';

  @override
  String get managedHealthCheck => 'Refresh';

  @override
  String get managedHealthChecking => 'Checking Termux…';

  @override
  String get managedHealthFailed =>
      'Could not check Termux. Open setup to check permissions or try again.';

  @override
  String get managedHealthReady => 'Server process running';

  @override
  String get managedHealthWorking => 'Setup is in progress';

  @override
  String get managedHealthStopped => 'Server stopped';

  @override
  String get managedHealthNeedsSetup => 'Setup needs attention';

  @override
  String get managedHealthAbsent => 'No managed setup found';

  @override
  String get managedHealthUnknown => 'Server state unavailable';

  @override
  String get managedHealthManage => 'On this phone';

  @override
  String managedHealthObserved(String time) {
    return 'Last checked at $time. Check again for the current state.';
  }

  @override
  String managedHealthVersion(String version) {
    return 'OpenCode $version';
  }

  @override
  String get managedHealthUbuntu => 'Runner: Ubuntu';

  @override
  String get managedHealthLifetime =>
      'Android may stop either app. Keeping the mobile connection alive does not guarantee the Termux server will keep running overnight.';

  @override
  String get quotaBudgetTitle => 'Personal alert threshold';

  @override
  String get quotaBudgetDescription =>
      'Choose a percentage used for this source, account and window. This does not change provider limits.';

  @override
  String get quotaBudgetOff => 'Off';

  @override
  String quotaBudgetPercent(String percent) {
    return '$percent% used';
  }

  @override
  String get quotaBudgetOptIn => 'Show threshold attention';

  @override
  String get quotaBudgetAttentionScope =>
      'Only after a fresh read on this page. No background polling or device notifications. A window without a reset time alerts once until you change this rule.';

  @override
  String get quotaBudgetSaveFailed =>
      'Could not save this budget change. Your last saved settings remain in effect.';

  @override
  String get quotaBudgetAttention =>
      'A personal threshold was reached in the latest provider reading. Review the reported windows below.';

  @override
  String get quotaGlm => 'GLM';

  @override
  String get quotaGlmAccount => 'Configured GLM Coding Plan source';

  @override
  String get quotaGlmTokenWindow => 'Reported token-plan window';

  @override
  String get quotaGlmMcpWindow => 'Reported MCP window';

  @override
  String get usageBudgetTitle => 'Personal consumption budgets';

  @override
  String get usageBudgetDescription =>
      'Budgets use all reported consumption for the selected server, project, timezone and date-window start. Model filters do not change them. A new window start needs a new budget. These do not change subscription allowances or stop requests.';

  @override
  String get usageBudgetUsd => 'Set USD budget';

  @override
  String get usageBudgetTokens => 'Set token budget';

  @override
  String get usageBudgetAmount => 'Budget amount';

  @override
  String get usageBudgetInvalid =>
      'Enter a positive finite amount. Token budgets must use whole numbers.';

  @override
  String get usageBudgetRemove => 'Remove budget';

  @override
  String usageBudgetProgress(String used, String limit, String unit) {
    return '$used of $limit $unit';
  }

  @override
  String get usageBudgetTokenUnit => 'tokens';

  @override
  String get usageBudgetReached => 'Personal budget reached in this reading.';

  @override
  String get usageBudgetPrevious =>
      'Previous reading reached this budget. Refresh to check current consumption.';

  @override
  String get usageBudgetClearAll => 'Clear saved consumption budgets';

  @override
  String get usageBudgetClearDescription =>
      'Remove all current and past consumption budgets for this saved server? Provider thresholds are kept.';

  @override
  String get monitorTitle => 'Saved-server attention';

  @override
  String get monitorScope =>
      'Counts cover each server’s last selected project, not every project on that server.';

  @override
  String get monitorDisclosure =>
      'Monitoring is off until you enable it for a server. Checks run about once a minute while this app is open. Background checks run no more often than every five minutes, only while Keep live is already on and Android’s service is running. Android can stop that service; no remaining runtime is promised.';

  @override
  String get monitorConfigure => 'Monitoring settings';

  @override
  String get monitorRefresh => 'Check monitored servers';

  @override
  String get monitorOptIn => 'Monitor this server';

  @override
  String get monitorOptInDetail =>
      'Check pending permissions, questions and forms in its last selected project.';

  @override
  String get monitorNotifications => 'Notify when attention is needed';

  @override
  String get monitorWifiDetail =>
      'Checks pause unless Android reports an active Wi-Fi network. VPN or unavailable network information may pause checks.';

  @override
  String get monitorQuiet => 'Quiet hours';

  @override
  String get monitorQuietStart => 'Quiet hours start';

  @override
  String get monitorQuietEnd => 'Quiet hours end';

  @override
  String get monitorDisabled => 'Not monitored · attention unknown';

  @override
  String get monitorWaiting => 'Waiting for a check · attention unknown';

  @override
  String get monitorChecking => 'Checking · attention unknown';

  @override
  String get monitorUnavailable => 'Could not check · attention unknown';

  @override
  String get monitorWifiRequired => 'Waiting for Wi-Fi · attention unknown';

  @override
  String get monitorPaused => 'Paused in background · attention unknown';

  @override
  String get monitorCurrent => 'Current observation';

  @override
  String get monitorAllClear => 'No pending requests in the checked project';

  @override
  String get monitorNoServers => 'Add a server to monitor attention.';

  @override
  String get monitorSaveFailed =>
      'Could not save monitoring settings. Try again.';

  @override
  String get monitorOpenFailed =>
      'This request or its project changed. Refresh the inbox and try again.';

  @override
  String get monitorSwitchTitle => 'Switch server to review?';

  @override
  String get monitorSwitchDetail =>
      'A run is active on the selected server. Switching changes the server shown in this app; it does not stop that server’s run.';

  @override
  String get monitorSwitch => 'Switch server';

  @override
  String get monitorSession => 'Conversation';

  @override
  String get monitorPermission => 'Permission needed';

  @override
  String get monitorQuestion => 'Answer needed';

  @override
  String get monitorForm => 'Form response needed';

  @override
  String get monitorUnknown => 'Unknown';

  @override
  String get monitorLastChecked => 'Last checked';

  @override
  String get monitorNextCheck => 'Next check';

  @override
  String get monitorPending => 'Current pending requests';

  @override
  String get monitorUnknownServers => 'Servers with unknown attention';

  @override
  String monitorPendingSummary(int pendingCount, int unknownCount) {
    return 'Current pending requests: $pendingCount\nServers with unknown attention: $unknownCount';
  }

  @override
  String monitorRequestSummary(
    String profile,
    String kind,
    String lastChecked,
    String time,
  ) {
    return '$profile · $kind\n$lastChecked: $time';
  }

  @override
  String monitorLabeledTime(String label, String time) {
    return '$label: $time';
  }

  @override
  String get monitorSelected => 'Selected project';

  @override
  String get monitorCheckIn => 'Check in on long runs';

  @override
  String get monitorCheckInDetail =>
      'Shows when busy checks span the chosen time. Work may pause or restart between checks. At most one notification is attempted per observed interval, while Keep live is on.';

  @override
  String get monitorCheckInDetailForeground =>
      'Shows a check-in row when busy checks span the chosen time. Work may pause or restart between checks. This device cannot deliver reminders in the background.';

  @override
  String get monitorCheckInAfter => 'Check in after';

  @override
  String monitorMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get monitorCheckInDue => 'Time to check in';

  @override
  String monitorObservedBusy(int minutes, String since) {
    return 'Busy at checks spanning $minutes min · first check $since';
  }

  @override
  String get quotaBudgetClearAll => 'Clear saved provider thresholds';

  @override
  String get quotaBudgetClearDescription =>
      'Remove all provider thresholds and attention settings for this saved server, including previous accounts? Consumption budgets are kept.';

  @override
  String managedStorageSummary(String available, String total) {
    return 'Termux storage: $available GiB free of $total GiB';
  }

  @override
  String get managedStorageFailed =>
      'Termux storage could not be checked. Refresh to try again.';

  @override
  String get managedRecoveryTitle => 'Recover a crashed managed server';

  @override
  String get managedRecoveryPolicy =>
      'Opt in to at most 3 restart attempts, with delays of at least 5, 15 and 45 seconds. Only while this app is in the foreground. No install or update.';

  @override
  String managedRecoveryAttempts(int attempts) {
    return 'Attempts used: $attempts of 3. The limit survives app restarts.';
  }

  @override
  String get managedRecoveryExhausted =>
      'Recovery limit reached. Check the server and start it manually before resetting the retry budget.';

  @override
  String get managedRecoveryBackground =>
      'Recovery waits while the app is in the background.';

  @override
  String get managedRecoveryChecking =>
      'Checking the managed recovery operation…';

  @override
  String managedRecoveryNext(String time) {
    return 'Next recovery attempt no earlier than $time.';
  }

  @override
  String get managedRecoveryCheck => 'Check recovery status';

  @override
  String get managedRecoveryReset => 'Reset retry budget';

  @override
  String get managedRecoverySaveFailed =>
      'Recovery settings could not be saved. Retry.';

  @override
  String get managedRecoveryRevokeFailed =>
      'Could not save or revoke recovery. Keep this server and retry before removing it.';

  @override
  String get managedRecoverySettingsUnreadable =>
      'Recovery settings could not be read. Check the server before enabling recovery.';

  @override
  String get managedRecoveryEnableFailed =>
      'Could not enable recovery. Start the managed server, then try again.';

  @override
  String get managedRecoveryOwnershipChanged =>
      'The managed operation changed. Check the server before enabling recovery again.';

  @override
  String get managedRecoveryUncertain =>
      'Recovery paused because Termux did not confirm the result. Refresh to continue.';

  @override
  String get managedRecoveryRetryDisable => 'Try disabling recovery again';

  @override
  String get managedRecoveryStoppedWithCleanupError =>
      'The local server is stopped. Recovery settings could not be fully cleared; retry disabling recovery in Servers before removing the server.';

  @override
  String get pluginMappingPersonal =>
      'Your command links · not verified plugin ownership';

  @override
  String pluginMappingReview(String command) {
    return 'Review /$command';
  }

  @override
  String get pluginMappingManage => 'Link commands';

  @override
  String get pluginMappingDescription =>
      'Choose commands you associate with this plugin. These personal links apply only to this project on this server. Each action opens a review of the conversation and arguments before you run it.';

  @override
  String get pluginMappingEmpty => 'No server commands are available to link.';

  @override
  String get pluginMappingUnavailable =>
      'This plugin or command is no longer available here. Refresh and review your links.';

  @override
  String get pluginMappingLimit => 'Choose up to 16 commands for this plugin.';

  @override
  String get pluginMappingSave => 'Save links';

  @override
  String get pluginMappingSaveFailed =>
      'Links could not be saved. Check that this project is still selected and try again.';

  @override
  String get pluginMappingLoadFailed =>
      'Commands could not be loaded. Try again when connected.';

  @override
  String get mobileTasksDescription => 'Server-reported tasks · mobile view';

  @override
  String get mobileTasksUnfinished => 'Show unfinished only';

  @override
  String get mobileTasksNoUnfinished => 'No unfinished tasks in this list.';

  @override
  String get mobileTaskPending => 'Pending';

  @override
  String get mobileTaskInProgress => 'In progress';

  @override
  String get mobileTaskCompleted => 'Completed';

  @override
  String get mobileTaskCancelled => 'Cancelled';

  @override
  String mobileTasksProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get mobileTasksCopyAll => 'Copy all tasks';

  @override
  String get mobileTasksCopied => 'All tasks copied';

  @override
  String get mobileTasksCopyFailed => 'Could not copy the task list.';

  @override
  String get mobileTaskPriorityHigh => 'High priority';

  @override
  String get mobileTaskPriorityMedium => 'Medium priority';

  @override
  String get mobileTaskPriorityLow => 'Low priority';

  @override
  String get pluginMappingClearAll => 'Clear personal links';

  @override
  String get pluginMappingClearTitle => 'Clear all personal command links?';

  @override
  String get pluginMappingClearDescription =>
      'Remove personal plugin-command links for every project on this saved server, including previous projects. Server plugins and commands stay installed.';

  @override
  String get pluginMappingClearConfirm => 'Clear links';

  @override
  String get pluginMappingClearFailed =>
      'Personal links could not be cleared. Check that this server is still selected and try again.';

  @override
  String get quotaMonitorTitle => 'Quota monitoring';

  @override
  String get quotaMonitorConsentTitle => 'Monitor this provider source?';

  @override
  String get quotaMonitorConsent =>
      'Allow this app to keep reading the trusted collector for this exact provider account after you leave this page, including after app restart. A cycle checks at most three saved sources, every five minutes in the foreground or fifteen minutes while your existing background service is active. With more than three sources, each source may wait several cycles. Device alerts require “Quota thresholds” in Notification settings and a freshly reported window at or above the selected percentage used. An alert records that past reading; open it to check current usage. Personal page thresholds are separate. No service is started here.';

  @override
  String get quotaMonitorRuntime =>
      'Sources are checked in rotation, at most three per cycle; larger lists take several cycles. Background reads require the existing live service to be active; Android may stop it. Displayed readings expire when the collector says they do. Device alerts record past threshold readings, not current remaining allowance. This page never switches your active server.';

  @override
  String get quotaMonitorEmpty =>
      'No provider sources are monitored. Read Remaining for a trusted collector, then enable monitoring for that source.';

  @override
  String get quotaMonitorEnable => 'Enable quota monitoring';

  @override
  String get quotaMonitorDisabled => 'Monitoring is off.';

  @override
  String get quotaMonitorWaiting => 'Waiting for a fresh reading.';

  @override
  String get quotaMonitorChecking => 'Checking the trusted collector…';

  @override
  String get quotaMonitorCurrent =>
      'Fresh reading from the consented provider source.';

  @override
  String get quotaMonitorPaused =>
      'Monitoring is paused. Open the app or check the existing background service.';

  @override
  String get quotaMonitorWifiRequired =>
      'Waiting for confirmed Wi-Fi. Unknown network status does not permit a read.';

  @override
  String get quotaMonitorSourceChanged =>
      'This provider account or source changed, or could not be verified. Open Remaining, read it again and review new consent.';

  @override
  String get quotaMonitorSaveFailed =>
      'Could not save quota monitoring. A failed disable stays paused in this app; retry before closing the app.';

  @override
  String get quotaMonitorDisable => 'Disable quota monitoring';

  @override
  String get setupChooseServerTitle => 'Choose your server setup';

  @override
  String get setupChooseServerDescription =>
      'Connect an existing server, or use Termux to run OpenCode on this phone.';

  @override
  String get setupUncheckedTitle => 'Continue without an installation check?';

  @override
  String get setupUncheckedDescription =>
      'The current installation could not be checked. Continuing may install or update OpenCode 1 in the app-managed Ubuntu environment. Existing Ubuntu files are kept. You can check again or connect by address instead.';

  @override
  String get setupUncheckedContinue => 'Continue with Ubuntu';

  @override
  String get webSearchDisclosure =>
      'Search sends your query to this server’s selected search provider. Review results before adding them to your editable draft. Nothing is sent to the model here.';

  @override
  String get webSearchManual => 'Or paste a source';

  @override
  String get webSearchUnavailable =>
      'Web search is unavailable. Configure a search provider on this server, then refresh providers. You can still paste a source below.';

  @override
  String get webSearchAuthentication =>
      'The server did not authorize web search. Check this server’s credentials.';

  @override
  String get webSearchInvalidResponse =>
      'The search response did not match this server or the supported format. Refresh providers or paste a source.';

  @override
  String get webSearchFailed =>
      'Web search could not finish. Try again or paste a source.';

  @override
  String get webSearchRefresh => 'Refresh providers';

  @override
  String get webSearchProvider => 'Search provider';

  @override
  String get webSearchQuery => 'Search query';

  @override
  String get webSearchSubmit => 'Search';

  @override
  String get webSearchEmpty => 'No usable results for this query.';

  @override
  String get webSearchOmitted =>
      'Some results were omitted because their links or excerpts exceeded the review limits.';

  @override
  String get setupReinstallStart => 'Reinstall & start';

  @override
  String setupInstallVersionStart(String version) {
    return 'Install $version & start';
  }

  @override
  String get setupReplaceTitle => 'Replace installed OpenCode?';

  @override
  String setupReplaceDescription(
    String installedVersion,
    String targetVersion,
  ) {
    return 'Replace OpenCode $installedVersion with $targetVersion in the managed Ubuntu environment and restart the local server. Existing Ubuntu files are kept.';
  }

  @override
  String get setupInstallRestart => 'Install & restart';

  @override
  String get queueStorageUnreadable =>
      'Saved queued prompts could not be read. New prompts cannot be queued until this device data is cleared.';

  @override
  String get queueStorageDiscardUnreadable =>
      'This permanently deletes the unreadable queued prompts and their attachments from this device. Their contents and count are unknown. Nothing on the server is affected.';

  @override
  String get filesViewerScopeChanged =>
      'Server changed. Close and reopen this file.';

  @override
  String get filesViewerPathChanged =>
      'File context changed. Close and reopen this file.';

  @override
  String get queueStorageCountUnknown =>
      'Saved queued data could not be read. The number of queued prompts is unknown.';

  @override
  String get codexConnectionVerified =>
      'Connection verified. Save and connect to continue.';

  @override
  String get codexApprovalRecoveryNotice =>
      'After reconnecting, review any pending approvals on your computer.';

  @override
  String get connectionTokenRejected =>
      'The connection token was rejected. Update it to reconnect.';

  @override
  String get updateConnectionToken => 'Update token';

  @override
  String get codexDraftReconnectNotice =>
      'Review draft stays here; nothing is sent automatically.';

  @override
  String get codexTextOnlyPrompt =>
      'This server supports text only. Remove attachments before sending.';

  @override
  String get codexOfflineDraftSaved =>
      'Reconnect before sending. Your draft is kept on this device.';

  @override
  String get codexReconnectBeforeSending => 'Reconnect before sending.';

  @override
  String get connectionTypeLabel => 'CONNECTION TYPE';

  @override
  String get openCodeConnectionLabel => 'OpenCode';

  @override
  String get paseoExperimentalLabel => 'Paseo: Claude Code, Pi (experimental)';

  @override
  String get paseoAddressHint => 'ws://100.64.0.1:6767 or wss://paseo.example';

  @override
  String get paseoAddressHelp =>
      'The Paseo daemon on your computer. ws:// works on this device and on Tailscale addresses; use wss:// elsewhere.';

  @override
  String get paseoPasswordLabel => 'Daemon password (optional)';

  @override
  String get paseoPasswordHelp =>
      'Set one with \"paseo daemon set-password\". Stored in this device\'s secure storage.';

  @override
  String get paseoSetupNotice =>
      'Run \"paseo start --no-relay\" on the computer that has Claude Code or Pi installed. This app never uses the Paseo relay: connect on this device or over your own private network.';

  @override
  String get codexExperimentalLabel => 'Codex (experimental)';

  @override
  String get connectionDisplayName => 'Display name (optional)';

  @override
  String get connectionDisplayNameHint => 'Defaults to the server host';

  @override
  String get connectionServerAddress => 'Server address';

  @override
  String get codexAddressHint => 'wss://codex.example or ws://127.0.0.1:4500';

  @override
  String get codexAddressHelp =>
      'Use wss:// for remote servers. ws:// is limited to this device.';

  @override
  String get codexProjectFolder => 'Project folder on server';

  @override
  String get codexTokenReentry => 'Re-enter connection token';

  @override
  String get codexTokenLabel => 'Connection token';

  @override
  String get codexTokenStorageHelp =>
      'Stored securely on this device and sent only to this Codex server.';

  @override
  String get codexShowToken => 'Show connection token';

  @override
  String get codexHideToken => 'Hide connection token';

  @override
  String get codexPasteToken => 'Paste connection token';

  @override
  String get connectionCloseEditor => 'Close server editor';

  @override
  String get connectionCredentialUnavailable =>
      'A saved server credential can no longer be read. Edit the active server and re-enter it before connecting.';

  @override
  String get projectContextTitle => 'Project context';

  @override
  String get projectConfiguredFolder => 'Configured folder';

  @override
  String get termuxGuideTitle => 'Connect Termux once';

  @override
  String get termuxGuideIntro =>
      'We copy the command for you. Here is what to do when Termux opens.';

  @override
  String get termuxGuideAutomaticCheck =>
      'When you return, we will check the connection automatically.';

  @override
  String get termuxGuideShowCommand => 'Show command';

  @override
  String get termuxGuideOpening => 'Opening Termux...';

  @override
  String get termuxGuideCopyTitle => '1. Copy & open';

  @override
  String get termuxGuideCopyDescription =>
      'Tap Copy & open Termux above. Allow Android\'s permission request if shown.';

  @override
  String get termuxGuidePasteTitle => '2. Press and hold, then Paste';

  @override
  String get termuxGuidePasteDescription =>
      'In Termux, press and hold near the blinking cursor. Tap Paste in the menu.';

  @override
  String get termuxGuideEnterTitle => '3. Enter, then return';

  @override
  String get termuxGuideEnterDescription =>
      'Press the keyboard Enter or return key. When Termux shows bridge-unlocked, switch back to this app.';

  @override
  String get termuxGuideCopied => 'Command copied';

  @override
  String get termuxGuidePaste => 'Paste';

  @override
  String get termuxGuideEnterKey => 'Enter';

  @override
  String get termuxGuideIllustrationNote =>
      'Illustrations only. Your keyboard and Paste menu may look different.';

  @override
  String get termuxGuideOpenFailed =>
      'The command was copied, but Termux could not open. Open Termux yourself or try Copy & open Termux again.';

  @override
  String get termuxGuideCopyOpenFailed =>
      'Could not copy the command or open Termux.';

  @override
  String get termuxPermissionDenied =>
      'Android denied the Termux command permission. Allow it in OpenCode app settings.';

  @override
  String get launchShortcutWaiting =>
      'Connecting to the saved server. The new conversation opens when it is ready.';

  @override
  String get launchShortcutNoServer =>
      'Choose a server, then start a new conversation.';

  @override
  String get launchShortcutReentry =>
      'Enter the credentials for the saved server, then start a new conversation.';

  @override
  String get launchShortcutConnectionFailed =>
      'Could not connect to the saved server. Choose or fix a server, then start a new conversation.';

  @override
  String launchShortcutNewTaskFailed(String error) {
    return 'Could not start a new conversation. $error';
  }

  @override
  String get launchUiPinnedUntitled => 'Untitled conversation';

  @override
  String get launchUiSessionWaiting =>
      'Connecting to the saved server. The conversation opens when it is ready.';

  @override
  String get launchUiSessionNoServer =>
      'Choose a server, then open the conversation from its list.';

  @override
  String get launchUiSessionReentry =>
      'Enter the credentials for the saved server, then open the conversation from its list.';

  @override
  String get launchUiSessionConnectionFailed =>
      'Could not connect to the saved server. Choose or fix a server, then open the conversation from its list.';

  @override
  String get launchUiSessionOtherServer =>
      'That shortcut belongs to another server. Connect to that server, then open the conversation from its list.';

  @override
  String get launchUiActivityNoServer =>
      'Choose a server to see what needs your attention.';

  @override
  String get queuedSending => 'Sending…';

  @override
  String get queuedDeliveryUnconfirmed =>
      'Delivery unconfirmed — review before resending';

  @override
  String queuedDeliveryUnconfirmedWithError(String error) {
    return 'Delivery unconfirmed: $error';
  }

  @override
  String get queuedResendTooltip => 'Send again';

  @override
  String get queuedResendTitle => 'Send this draft again?';

  @override
  String get queuedResendMessage =>
      'It may already have reached OpenCode. Sending again can duplicate it.';

  @override
  String get queuedResendConfirm => 'Send again';

  @override
  String get queuedKeepForReview => 'Keep for review';

  @override
  String get queuedDiscardUnconfirmedMessage =>
      'Its earlier send was never confirmed; it may already be in the conversation.';

  @override
  String get setupRuntimeTitle => 'Which OpenCode would you like to use?';

  @override
  String get setupRuntimeOne => 'OpenCode 1';

  @override
  String get setupRuntimeOneDetail =>
      'Recommended for the widest feature support in this app.';

  @override
  String get setupRuntimeTwo => 'OpenCode 2';

  @override
  String get setupRuntimeTwoDetail =>
      'The newer server. A few features from OpenCode 1 are not available on it yet.';

  @override
  String setupRuntimeInstallDetail(String runtime, String version) {
    return 'Install $runtime ($version) in an app-managed Ubuntu environment. Existing Ubuntu files are reused.';
  }

  @override
  String setupRuntimeUpdateDetail(String runtime, String version) {
    return 'The app will install $runtime $version, restart only the managed local server, and reconnect this server.';
  }

  @override
  String queuedBannerReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts with an unconfirmed send to review.',
      one: '1 draft with an unconfirmed send to review.',
    );
    return '$_temp0';
  }

  @override
  String get isolatedTaskAction => 'Start a task in a fresh worktree';

  @override
  String get isolatedTaskTitle => 'New task in a fresh worktree';

  @override
  String isolatedTaskIntro(String project) {
    return 'OpenCode creates a new Git worktree and branch for $project and runs the project\'s setup. The worktree stays listed under Manage project until you remove it there.';
  }

  @override
  String get isolatedTaskNameLabel => 'Worktree name (optional)';

  @override
  String get isolatedTaskNameHelper =>
      'Leave empty to let OpenCode choose a name.';

  @override
  String get isolatedTaskStart => 'Create and start';

  @override
  String get isolatedTaskCreating => 'Creating the worktree…';

  @override
  String get isolatedTaskCreatingHint =>
      'Stopping now cannot undo a create the server may already be running.';

  @override
  String isolatedTaskPreparing(String name) {
    return '$name was created. OpenCode is preparing it…';
  }

  @override
  String isolatedTaskReady(String name) {
    return '$name is ready. Opening a blank conversation…';
  }

  @override
  String isolatedTaskReadyIdle(String name) {
    return '$name is ready.';
  }

  @override
  String isolatedTaskUnconfirmed(String name) {
    return '$name was created, but its setup status is not confirmed.';
  }

  @override
  String get isolatedTaskUnconfirmedHint =>
      'You can keep waiting or open it now. Setup may still be running.';

  @override
  String get isolatedTaskFailed => 'OpenCode could not prepare the worktree.';

  @override
  String get isolatedTaskCreateFailed => 'The worktree could not be created.';

  @override
  String isolatedTaskFailedKept(String name) {
    return '$name stays listed under Manage project. Nothing was deleted.';
  }

  @override
  String get isolatedTaskCancelled => 'Stopped waiting.';

  @override
  String isolatedTaskCancelledKept(String name) {
    return '$name was created and stays listed under Manage project.';
  }

  @override
  String get isolatedTaskCancelledUnknown =>
      'If OpenCode created the worktree, it appears under Manage project.';

  @override
  String isolatedTaskOpening(String name) {
    return 'Opening a blank conversation in $name…';
  }

  @override
  String isolatedTaskOpened(String name) {
    return 'Conversation ready in $name. Nothing has been sent.';
  }

  @override
  String isolatedTaskBranch(String branch) {
    return 'Branch $branch';
  }

  @override
  String get isolatedTaskStopWaiting => 'Stop waiting';

  @override
  String get isolatedTaskKeepWaiting => 'Keep waiting';

  @override
  String get isolatedTaskOpenAnyway => 'Open anyway';

  @override
  String get isolatedTaskRetryOpen => 'Try again';

  @override
  String get isolatedTaskClose => 'Close';

  @override
  String get returnBriefTitle => 'Unreviewed work';

  @override
  String get returnBriefDescription =>
      'For this project on this device. Dismissing keeps conversations unread and requests pending.';

  @override
  String get returnBriefUntitled => 'Untitled conversation';

  @override
  String get returnBriefStale =>
      'Last observed state. Reconnect or refresh to check current work and requests.';

  @override
  String get returnBriefStatusUnknown => 'Review status unknown';

  @override
  String get returnBriefUnknown =>
      'This server does not report read state. Unreviewed results are unknown.';

  @override
  String get returnBriefPartial =>
      'Loaded conversations only. The conversation list is still incomplete.';

  @override
  String get returnBriefAnswer => 'Answer';

  @override
  String get returnBriefUnreviewed =>
      'Unreviewed conversation. Open results to check the outcome.';

  @override
  String get returnBriefReview => 'Review results';

  @override
  String get returnBriefContinue => 'Continue';

  @override
  String returnBriefMore(int count) {
    return 'Additional items: $count. They remain unacknowledged; see the conversations below or Inbox.';
  }

  @override
  String get returnBriefSaveFailed =>
      'Dismissal was not saved. These items are still unreviewed. Try again.';

  @override
  String get returnBriefSaving => 'Saving dismissal...';

  @override
  String get returnBriefDismiss => 'Dismiss shown items';

  @override
  String get capsuleTitle => 'Context capsule';

  @override
  String get capsuleEntry =>
      'Collect notes, errors and screenshots for this conversation';

  @override
  String get capsuleDescription =>
      'Build a bundle for this conversation. Applying adds it to your existing draft; nothing is sent. Unapplied edits are kept only while this screen is open.';

  @override
  String get capsuleNote => 'Note';

  @override
  String get capsuleError => 'Error';

  @override
  String get capsuleCode => 'Code';

  @override
  String get capsuleLabel => 'Label';

  @override
  String get capsuleExcerpt => 'Excerpt';

  @override
  String get capsulePaste => 'Paste';

  @override
  String get capsuleRemove => 'Remove';

  @override
  String get capsuleAddImage => 'Add screenshot or image';

  @override
  String get capsulePreview => 'Tap to preview';

  @override
  String get capsuleApply => 'Apply to draft';

  @override
  String get capsuleApplied =>
      'Context added to your saved draft. Review it before sending.';

  @override
  String get capsuleScopeChanged =>
      'The conversation, server or draft changed. Close this capsule and reopen it from the intended conversation.';

  @override
  String get capsuleTextOnly =>
      'This server accepts text only. You can still collect notes, errors and code.';

  @override
  String get capsuleImagesOnly =>
      'Choose a PNG, JPEG, GIF or WebP image. Paste text into an excerpt instead.';

  @override
  String get capsuleImageFailed =>
      'Could not add that image. Use up to 5 attachments, 10 MB each and 20 MB total, including your existing draft.';

  @override
  String get capsulePasteFailed =>
      'Clipboard text is unavailable. You can type or paste into the excerpt.';

  @override
  String get capsuleTextLimit =>
      'Keep each excerpt under 16,000 characters and the bundle under 32,000.';

  @override
  String get markdownCopyCode => 'Copy code';

  @override
  String get markdownCopied => 'Code copied';

  @override
  String get markdownCopyFailed => 'Could not copy code. Try again.';

  @override
  String get markdownCopyRetry => 'Try again';

  @override
  String get markdownWrapCode => 'Wrap lines';

  @override
  String get markdownScrollCode => 'Scroll lines';

  @override
  String get markdownExpandCode => 'Full screen';

  @override
  String get markdownReaderTitle => 'Code reader';

  @override
  String get markdownSnapshot =>
      'Snapshot of the code when opened. Close and reopen to read later updates.';

  @override
  String get tailscaleTitle => 'Connect with Tailscale';

  @override
  String get tailscaleQuickAdd =>
      'Use your private network and an HTTPS server address';

  @override
  String get tailscaleIntro =>
      'Reach OpenCode on another computer through your own Tailscale network. You control sign-in and VPN access in the official Tailscale app.';

  @override
  String get tailscaleAppStep => '1. Open your private network';

  @override
  String get tailscaleChecking => 'Checking for the Tailscale app…';

  @override
  String get tailscaleInstalled =>
      'Tailscale is installed. VPN connection is unverified.';

  @override
  String get tailscaleMissing =>
      'Tailscale is not installed. Install the official app, then return and check again.';

  @override
  String get tailscaleUnknown =>
      'Could not check the app. Try again, or open Tailscale from your phone.';

  @override
  String get tailscaleUnsupported =>
      'This device cannot open the Android app. Set up Tailscale on this device yourself, then review your HTTPS address below.';

  @override
  String get tailscaleVpnHandoff =>
      'In Tailscale, sign in to the network that can reach your server, approve Android’s VPN prompt if asked, and turn the connection on. OpenCode cannot see or change that VPN state.';

  @override
  String get tailscaleReturned =>
      'Welcome back. App presence was checked again; use Test connection on the next screen to check your server.';

  @override
  String get tailscaleOpenFailed =>
      'Tailscale could not open. Open it from your launcher, then return here. Your address stays in this form.';

  @override
  String get tailscaleOpen => 'Open Tailscale';

  @override
  String get tailscaleInstall => 'Get official Android app';

  @override
  String get tailscaleCheckAgain => 'Check app again';

  @override
  String get tailscaleAddressStep => '2. Review your server address';

  @override
  String get tailscaleAddressLabel => 'Private HTTPS server address';

  @override
  String get tailscaleAddressDetail =>
      'Use the full HTTPS origin printed by Tailscale Serve, such as https://computer.tailnet-name.ts.net. Keep any HTTPS port it prints. A short device name or a raw HTTP port may not provide a valid certificate.';

  @override
  String get tailscaleAddressError =>
      'Enter an HTTPS origin with a valid port (1–65535). Remove paths, credentials, query text and fragments. Use the full address from Serve; do not replace https with http.';

  @override
  String get tailscaleReviewDetail =>
      'Continue only with an address you recognize. The next screen reviews your server credentials before you explicitly test or save. This app cannot confirm that an address is private from its name alone.';

  @override
  String get tailscaleContinue => 'Continue to authentication';

  @override
  String get tailscaleHelp => 'Tailscale setup and recovery';

  @override
  String get tailscaleServeHelp =>
      'On the server computer, Tailscale Serve can provide private HTTPS for a local OpenCode port. Use Serve, not public Funnel. Your tailnet access rules still apply. Enabling HTTPS publishes the certificate’s device and tailnet names in a public certificate log, although access stays private. Review the official guide before changing your server.';

  @override
  String get tailscaleServeDocs => 'Read the official Serve guide';

  @override
  String get tailscaleAndroidDocs => 'Read the official Android guide';

  @override
  String get tailscaleRecovery =>
      'If the server is unreachable, check Tailscale on both devices, the full HTTPS name and port, Serve on the server, and your network’s access rules. A VPN or DNS conflict may also prevent access. Keep HTTPS enabled. Correct the server password if authentication is rejected, then retry Test connection.';

  @override
  String get tailscaleEditorDetail =>
      'Your network connection is managed in Tailscale. Test connection checks this OpenCode server, not the VPN. Enter the server’s own username and password here, not your Tailscale login. Setup help keeps these fields intact.';

  @override
  String get a2aDraftSaveError =>
      'Draft changes could not be saved. Keep this screen open and retry before leaving.';

  @override
  String get a2aRetryDraftSave => 'Try saving draft again';

  @override
  String get a2aSavingDraft => 'Saving draft changes…';

  @override
  String a2aCardVersion(String version) {
    return 'Agent version: $version';
  }

  @override
  String get a2aSupportedConnection => 'A2A 1.0 · JSON-RPC · Text tasks';

  @override
  String get a2aTitle => 'External agents';

  @override
  String get a2aIntro => 'Bring an agent you trust.';

  @override
  String get a2aBoundary =>
      'Connect to an A2A agent and send a task you choose. Only the text you submit is shared. Your projects, files and other conversations stay on this phone.';

  @override
  String get a2aAdd => 'Add agent';

  @override
  String get a2aEmpty =>
      'No external agents yet. Start with an agent\'s HTTPS address or public Agent Card URL.';

  @override
  String get a2aDeleteAgent => 'Remove agent';

  @override
  String get a2aDeleteAgentDetail =>
      'Remove this agent, its saved tasks and its credential from this phone. This does not stop remote work or delete data held by the agent.';

  @override
  String get a2aDeleteLocal => 'Remove from this phone';

  @override
  String get a2aDeletionPending =>
      'Removal from this phone is incomplete. This agent is unavailable until its remaining data is removed.';

  @override
  String get a2aRetryDelete => 'Try removing again';

  @override
  String get a2aInspectIntro => 'Inspect before you connect';

  @override
  String get a2aAddress => 'Agent address';

  @override
  String get a2aInspect => 'Inspect Agent Card';

  @override
  String get a2aUnsupported =>
      'Unavailable: this card does not advertise the supported A2A 1.0 JSON-RPC, text and authentication combination on the same origin, or requires an unsupported extension. No task can be sent.';

  @override
  String get a2aBearerDetail =>
      'Supply an HTTP bearer credential issued for this agent. It is stored in the phone\'s secure storage and sent only to the inspected origin. No sign-in or credential sharing with other agents is performed.';

  @override
  String get a2aNoAuthDetail =>
      'This card requests no authentication. Do not send private information unless you trust this agent.';

  @override
  String get a2aBearer => 'Agent bearer credential';

  @override
  String get a2aSave => 'Save agent';

  @override
  String get a2aCardClaim =>
      'Self-reported Agent Card. This app has not verified the agent\'s identity, skills or billing terms.';

  @override
  String get a2aSkills => 'Advertised skills';

  @override
  String get a2aNewTask => 'New task';

  @override
  String get a2aTaskPrompt => 'Task text';

  @override
  String get a2aSendDetail =>
      'Review the text and destination before sending. The agent may use its own compute or services; check its terms. This app cannot estimate or limit that usage.';

  @override
  String get a2aReviewTask => 'Review task';

  @override
  String get a2aUpdateCredential => 'Update credential';

  @override
  String get a2aSavedTasks => 'Saved tasks';

  @override
  String get a2aReopenDetail =>
      'Reopening checks the existing task. It never sends your task again.';

  @override
  String get a2aDeliveryUnconfirmed => 'Delivery unconfirmed';

  @override
  String get a2aDraft => 'Not sent';

  @override
  String get a2aBack => 'Back';

  @override
  String get a2aTaskTitle => 'Agent task';

  @override
  String get a2aFresh => 'Checked with the agent this visit.';

  @override
  String get a2aSavedSnapshot =>
      'Saved locally. Refresh a known task to check its current state.';

  @override
  String get a2aCancelTask => 'Stop task';

  @override
  String get a2aCancelDetail =>
      'Ask this agent to stop this task. Work may already have finished, and the agent decides whether stopping is possible.';

  @override
  String get a2aRequestCancel => 'Ask to stop';

  @override
  String get a2aForgetTask => 'Forget saved task';

  @override
  String get a2aForgetDetail =>
      'Remove this saved task from the phone. Remote work may continue, including a send whose delivery is unconfirmed. This cannot delete the agent\'s copy.';

  @override
  String get a2aYourReply => 'Your reply';

  @override
  String get a2aSend => 'Send to agent';

  @override
  String get a2aReplySameTask => 'Reply to this task';

  @override
  String get a2aAgentOutput => 'Agent output';

  @override
  String get a2aBlockedLink => 'Unsupported link';

  @override
  String get a2aReviewLink => 'Review external link';

  @override
  String get a2aOmittedContent =>
      'Some output is omitted. This view shows bounded text and links; binary or structured artifacts are not downloaded or executed.';

  @override
  String get a2aRefresh => 'Refresh task';

  @override
  String get a2aSubmitted => 'Submitted';

  @override
  String get a2aWorking => 'Working';

  @override
  String get a2aInputRequired => 'Your input is needed';

  @override
  String get a2aAuthRequired => 'Agent requires authentication';

  @override
  String get a2aCompleted => 'Completed';

  @override
  String get a2aFailed => 'Failed';

  @override
  String get a2aCanceled => 'Canceled';

  @override
  String get a2aRejected => 'Rejected';

  @override
  String get a2aUnknown => 'Unsupported task state';

  @override
  String get a2aAddressError =>
      'Use an HTTPS origin or public Agent Card URL without credentials, query or fragment. HTTP is supported only on this device\'s loopback address.';

  @override
  String get a2aAuthenticationError =>
      'The agent rejected or could not use this credential. Return to the agent to update it, then reopen the saved task.';

  @override
  String get a2aUnavailable =>
      'The agent could not be reached or rejected this operation. Refresh a known task to check its state.';

  @override
  String get a2aInvalidResponse =>
      'The agent returned an unsupported, oversized or mismatched response. The saved task has not been replaced.';

  @override
  String get a2aUncertain =>
      'The agent may have received this message. It will not be resent. If a task ID was confirmed, refresh to check progress; otherwise check with the agent before starting another task.';

  @override
  String get a2aStorageError =>
      'Local data could not be saved or removed. Check device storage and retry the local operation. A message without a saved delivery marker is not sent.';

  @override
  String get a2aScopeError =>
      'This agent, credential or saved task changed. Close this view and reopen the agent to continue.';

  @override
  String get a2aCancelUnconfirmed =>
      'Cancellation is not confirmed. The agent still reports an active task; refresh to check again.';

  @override
  String get a2aAuthRequiredDetail =>
      'This agent requested an additional authentication flow, which this client does not support. No automatic login or task continuation will occur.';

  @override
  String get a2aUnknownDetail =>
      'This task state is not supported. You can refresh or forget the local record; sending and cancellation remain unavailable.';

  @override
  String get fileTable => 'Table';

  @override
  String get fileSource => 'Source';

  @override
  String get fileSourceExcerpt =>
      'Up to the first 200,000 characters are displayed. Copy and Save keep the original content.';

  @override
  String get filePreviewPartialSource =>
      'Only part of this file is shown. Copy and Save keep the original content.';

  @override
  String fileLineOutsidePreview(int line) {
    return 'Line $line is outside this preview. Save the original to read that location.';
  }

  @override
  String get fileTableMalformed =>
      'This file has incomplete or inconsistent quoting. Read its source instead.';

  @override
  String get fileTableTooLarge =>
      'Table preview supports files up to 256 KB. Read the source or save the original file.';

  @override
  String get fileTableTooWide =>
      'This file has more than 32 columns. Read the source or save the original file.';

  @override
  String get fileTableFieldTooLong =>
      'A cell exceeds 4,096 characters. Read the source or save the original file.';

  @override
  String get fileTableMoreRows =>
      'Showing the first 200 rows. More data remains in the original file.';

  @override
  String fileTableRows(int rows, int columns) {
    return '$rows rows shown · $columns columns';
  }

  @override
  String fileTableColumn(int number) {
    return 'Column $number';
  }

  @override
  String get fileTableEmpty => 'This file has no rows.';

  @override
  String get fileCopied => 'File contents copied';

  @override
  String get fileCopyFailed => 'Could not copy file contents. Try again.';

  @override
  String get fileImage => 'Image';

  @override
  String get fileSvgUnsupported =>
      'This SVG cannot be shown as a local static image. Read its source or save the original file. External resources, animation and complex SVG features are not supported.';

  @override
  String get filePdfEncrypted =>
      'This PDF requires a password or uses unsupported protection. Save the original to open it in a PDF app.';

  @override
  String get filePdfLimit =>
      'PDF preview supports files up to 10 MB and the first 200 pages. Save the original to read the full document.';

  @override
  String get filePdfUnavailable =>
      'PDF viewing is available on Android 10 or newer. You can still save the original file.';

  @override
  String get filePdfCancelled =>
      'PDF loading cancelled. Retry when you are ready.';

  @override
  String get filePdfFailed =>
      'This PDF page could not be displayed. Retry or save the original file.';

  @override
  String get filePdfPageLimit =>
      'Only the first 200 pages can be previewed. Save the original to read the full document.';

  @override
  String filePdfPage(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get filePrevious => 'Previous';

  @override
  String get fileNext => 'Next';

  @override
  String get fileCancel => 'Cancel';

  @override
  String get agentAccountTitle => 'Codex account';

  @override
  String get agentAccountScopeLost =>
      'This server changed. Return to Servers and open the account for the connected server.';

  @override
  String get agentAccountRefresh => 'Refresh account';

  @override
  String get agentAccountLoading => 'Checking the host account';

  @override
  String get agentAccountUnavailable => 'Account panel unavailable';

  @override
  String get agentAccountReadFailed => 'Could not read the account';

  @override
  String get agentAccountDisconnected => 'Connection interrupted';

  @override
  String get agentAccountConnected => 'Signed in on the host';

  @override
  String get agentAccountSignedOut => 'Ready to sign in';

  @override
  String get agentAccountInProgress => 'Sign-in in progress';

  @override
  String get agentAccountNeedsAttention => 'Sign-in needs attention';

  @override
  String get agentAccountNoAuth => 'Host does not require sign-in';

  @override
  String get agentAccountApiKey => 'API key';

  @override
  String get agentAccountHostAuth => 'Host authentication';

  @override
  String agentAccountPlan(String plan) {
    return 'Plan: $plan';
  }

  @override
  String get agentAccountHostNote =>
      'The official Codex runtime keeps your provider credentials. Account changes apply to this host, including other saved servers connected to it.';

  @override
  String get agentAccountUnsupportedDetail =>
      'This panel is verified with Codex 0.153.4. The connected runtime may not support these account methods.';

  @override
  String get agentAccountReconnectDetail =>
      'Account data and the sign-in code were cleared. Reconnect to refresh. Sign-in will not restart automatically.';

  @override
  String get agentAccountSignIn => 'Sign in with ChatGPT';

  @override
  String get agentAccountSignInNote =>
      'Start an official device-code sign-in on this host. Complete it in your browser; the app never receives your provider tokens.';

  @override
  String get agentAccountLimits => 'Rate limits';

  @override
  String get agentAccountLimitsUnavailable =>
      'Rate limits are unavailable for this account or host.';

  @override
  String get agentAccountUsage => 'Token usage';

  @override
  String get agentAccountUsageUnavailable =>
      'Token usage is unavailable for this account or host.';

  @override
  String get agentAccountLifetimeTokens => 'Lifetime tokens';

  @override
  String get agentAccountPeakTokens => 'Peak daily tokens';

  @override
  String get agentAccountUsageNote =>
      'Values are reported by the host. Missing values are unknown, not zero. Token counts are not a bill or remaining message allowance.';

  @override
  String agentAccountUpdated(String time) {
    return 'Last checked $time';
  }

  @override
  String get agentAccountStarting => 'Requesting a sign-in code';

  @override
  String get agentAccountWaiting => 'Finish sign-in in your browser';

  @override
  String get agentAccountCancelling => 'Cancelling sign-in';

  @override
  String get agentAccountCancelled => 'Sign-in cancelled';

  @override
  String get agentAccountLoginFailed =>
      'Sign-in did not complete. Check the host and try again.';

  @override
  String get agentAccountLoginUncertain =>
      'The host could not confirm sign-in or cancellation. It may still be waiting. Check the official host runtime before starting again.';

  @override
  String get agentAccountLoginCompleted =>
      'Sign-in completed. Checking the account.';

  @override
  String get agentAccountCodeHint =>
      'Enter this one-time code on the official sign-in page. Keep it private.';

  @override
  String get agentAccountOpenSignIn => 'Open official sign-in';

  @override
  String get agentAccountCancel => 'Cancel sign-in';

  @override
  String get agentAccountAllowance => 'Reported allowance';

  @override
  String agentAccountPercentUsed(int percent) {
    return '$percent% used';
  }

  @override
  String get agentAccountWindowUnknown => 'Window duration unavailable';

  @override
  String agentAccountWindowMinutes(int minutes) {
    return '$minutes-minute window';
  }

  @override
  String agentAccountWindowHours(int hours) {
    return '$hours-hour window';
  }

  @override
  String agentAccountWindowDays(int days) {
    return '$days-day window';
  }

  @override
  String get agentAccountResetUnknown => 'Reset time unavailable';

  @override
  String agentAccountReset(String time) {
    return 'Resets $time';
  }

  @override
  String get projectFolderChooserTitle => 'Choose a project folder';

  @override
  String get projectFolderChooserMessage =>
      'OpenCode Mobile does not work in the server’s home folder. Create a new folder or open a project folder to start conversations.';

  @override
  String get projectFolderCreate => 'Create a new folder';

  @override
  String get projectFolderOpen => 'Open a project folder';

  @override
  String get projectFolderBrowse => 'Choose from opened projects';

  @override
  String get projectFolderNoCreateHint =>
      'This server cannot create folders from the app. Create the folder on that machine, then open it here by its path.';

  @override
  String projectFolderCreateMessage(String directory) {
    return 'The folder is created in $directory on this device and opened as the project.';
  }

  @override
  String get projectFolderNameLabel => 'Folder name';

  @override
  String get projectFolderNameHint => 'my-app';

  @override
  String get projectFolderCreateAction => 'Create';

  @override
  String get projectFolderCancel => 'Cancel';

  @override
  String get projectFolderOpenMessage =>
      'Enter the full path of a folder on the server. The home folder itself cannot be used; choose a project inside it.';

  @override
  String get projectFolderPathLabel => 'Folder path';

  @override
  String projectFolderPathHint(String directory) {
    return '$directory/my-app';
  }

  @override
  String get projectFolderOpenAction => 'Open';

  @override
  String projectFolderCreateSubtitle(String directory) {
    return 'In $directory on this device';
  }

  @override
  String get projectFolderOpenSubtitle =>
      'Enter the full path of a folder on the server';

  @override
  String get globalSessionsTitle => 'All conversations';

  @override
  String get globalSessionsSearchLabel => 'Search conversation titles';

  @override
  String get globalSessionsSearchHint => 'Across every project on this server';

  @override
  String get globalSessionsIncludeArchived => 'Include archived';

  @override
  String get globalSessionsArchivedShort => 'Archived';

  @override
  String get globalSessionsAllFolders => 'All projects';

  @override
  String get globalSessionsUnknownLocation => 'Unknown project';

  @override
  String globalSessionsSummary(String count, int folders) {
    return '$count conversations in $folders projects';
  }

  @override
  String globalSessionsSummaryOneFolder(String count) {
    return '$count conversations in one project';
  }

  @override
  String globalSessionsFilteredSummary(int count, String total) {
    return '$count of $total conversations shown';
  }

  @override
  String get globalSessionsEmptyTitle => 'No conversations yet';

  @override
  String get globalSessionsEmptyMessage =>
      'Conversations from every project on this server will appear here.';

  @override
  String get globalSessionsNoMatchTitle => 'No matching conversations';

  @override
  String get globalSessionsNoMatchMessage =>
      'Try a shorter title search or include archived conversations.';

  @override
  String get globalSessionsRefresh => 'Refresh';

  @override
  String get globalSessionsLoadMoreFailed =>
      'Could not load more conversations';

  @override
  String get globalSessionsOpen => 'Open';

  @override
  String get globalSessionsContinueHere => 'Continue here';

  @override
  String get globalSessionsActions => 'Conversation actions';

  @override
  String get globalSessionsWorking => 'Working';

  @override
  String get globalSessionsUntitled => 'Untitled conversation';

  @override
  String get workspaceNewSession => 'New conversation';

  @override
  String get workspaceIsolatedTask => 'Isolated task';

  @override
  String get workspaceAllSessions => 'All conversations';

  @override
  String get workspaceDismissNotice => 'Dismiss';

  @override
  String get workspaceManageProject => 'Manage project';

  @override
  String get workspaceManageProjectHint =>
      'Switch project, worktrees, and project health';

  @override
  String get workspaceManage => 'Manage';

  @override
  String get reviewCopiedFile => 'Updated file copied';

  @override
  String get reviewCopiedPatch => 'Patch copied';

  @override
  String get reviewCopyFailed => 'Could not copy. Try again.';

  @override
  String get reviewCopyFile => 'Copy updated file';

  @override
  String get reviewCopyPatch => 'Copy patch';

  @override
  String get reviewNoChanges => 'No changes';

  @override
  String get reviewEmptyDiff => 'No diff content';

  @override
  String get reviewHideContext => 'Hide revealed context';

  @override
  String get reviewAdded => 'Added';

  @override
  String get reviewRemoved => 'Removed';

  @override
  String get reviewUnchanged => 'Unchanged';

  @override
  String get reviewPatchNote => 'Patch note';

  @override
  String reviewShowNext(int count) {
    return 'Show next $count lines';
  }

  @override
  String reviewShowPrevious(int count, int remaining) {
    return 'Show $count previous lines ($remaining hidden)';
  }

  @override
  String reviewMissingContext(int count) {
    return '$count unchanged lines not included in patch';
  }

  @override
  String reviewCounts(int added, int removed) {
    return '$added added, $removed removed';
  }

  @override
  String reviewLineDescription(String kind, int number, String text) {
    return '$kind, line $number: $text';
  }

  @override
  String reviewNoteDescription(String kind, String text) {
    return '$kind: $text';
  }

  @override
  String settingsDiscoveryNewChatsModel(String model) {
    return 'New conversations: $model';
  }

  @override
  String get onboardingValueTitle => 'Keep your work moving.';

  @override
  String get onboardingValueBody =>
      'Ask your coding agent for a change, review the result, and pick up where you left off.';

  @override
  String get onboardingConnect => 'Connect to a server';

  @override
  String get onboardingDemoNote =>
      'A simulated conversation. No server needed.';

  @override
  String get onboardingMoreSetup => 'More setup options';

  @override
  String get onboardingPrivateNetwork =>
      'Reach a server over your private network';

  @override
  String get onboardingRunOnPhone => 'Run OpenCode here with Termux';

  @override
  String get onboardingTermuxNote => 'Guided Termux setup';

  @override
  String get onboardingSetupGuide => 'Setup guide';

  @override
  String get onboardingSaveConnect => 'Save & connect';

  @override
  String get onboardingSaveChanges => 'Save changes';

  @override
  String get onboardingTermuxSetup => 'On this phone';

  @override
  String get activityClearHere => 'All clear here';

  @override
  String get activityStatusIncomplete => 'Status incomplete';

  @override
  String get activityCheckedLocationsClear =>
      'Nothing needs you in the checked projects.';

  @override
  String get activityUnknownStatusDetail =>
      'No requests loaded. Some server activity is still unknown.';

  @override
  String get activityCheckAgain => 'Try again';

  @override
  String get activitySavedServers => 'Saved servers';

  @override
  String get activitySelectedLocationsOnly => 'Last selected projects only';

  @override
  String get activityBackgroundUpdates => 'Background updates';

  @override
  String get activityBackgroundOffDetail =>
      'Off · choose when to stay connected';

  @override
  String activityPendingCount(int count) {
    return '$count pending';
  }

  @override
  String activityUnknownCount(int count) {
    return '$count unknown';
  }

  @override
  String get demoTaskTitle => 'Try a small change';

  @override
  String get demoTaskInstruction =>
      'Send the sample prompt below, then review the proposed edit.';

  @override
  String get reviewTitle => 'Review';

  @override
  String get modelChoiceProvidersTitle => 'Providers not loaded';

  @override
  String modelChoiceProvidersSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signed-in providers not loaded. View details',
      one: '1 signed-in provider not loaded. View details',
    );
    return '$_temp0';
  }

  @override
  String get modelChoiceReloadProviders => 'Reload providers';

  @override
  String get modelChoiceStagedAgentHint => 'Applied with your model choice';

  @override
  String get modelChoiceAgentTitle => 'Choose an agent';

  @override
  String get modelChoiceDone => 'Done';

  @override
  String get modelChoicePartialSaveError =>
      'Model saved. Agent choice was not confirmed. Try again.';

  @override
  String get modelChoiceModelSaveError =>
      'Could not confirm the model choice. Check your selection and try again.';

  @override
  String get workIdle => 'Idle';

  @override
  String get workStartedInBackground => 'Started in background';

  @override
  String get workRunInBackground => 'Run in background';

  @override
  String get workBackgroundPending => 'Requesting background work…';

  @override
  String get workBackgroundRequested =>
      'Background work requested. Status will update when the server reports it.';

  @override
  String get workBackgroundUnavailable =>
      'This server has not confirmed support for moving work to the background.';

  @override
  String get workBackgroundEligible =>
      'Run in background is available while a supported agent task or command is blocking this conversation.';

  @override
  String get workBackgroundAutomatic =>
      'Ask your agent to delegate work in the background. Results return to this conversation automatically.';

  @override
  String get oc2DiscoveryConnect => 'Connect OpenCode 2';

  @override
  String get oc2DiscoveryEditorTitle => 'OpenCode 2';

  @override
  String get oc2DiscoveryExisting => 'Use a server that is already running.';

  @override
  String get oc2DiscoveryTypes => 'OpenCode 1 or 2';

  @override
  String get oc2DiscoveryAutodetect => 'Detects OpenCode 1 or 2 automatically.';

  @override
  String get oc2DiscoveryPhone => 'Set up OpenCode 1 or 2 here with Termux.';

  @override
  String setupSwitchUse(String runtime) {
    return 'Try $runtime';
  }

  @override
  String setupSwitchConfirmTitle(String runtime) {
    return 'Switch to $runtime?';
  }

  @override
  String get setupSwitchConfirmDetail =>
      'Stops this phone’s server and running tasks. Conversations, provider settings and credentials stay separate; project files and configuration are shared. You can switch back.';

  @override
  String get setupSwitchConfirm => 'Switch version';

  @override
  String setupSwitchInstalled(String runtime) {
    return 'On this phone: $runtime';
  }

  @override
  String get setupSwitchPending =>
      'The runtime switch has not finished. Retry the selected runtime or return to the previous one. Your saved runtime data is retained.';

  @override
  String setupSwitchReturn(String runtime) {
    return 'Return to $runtime';
  }

  @override
  String setupSwitchRetry(String runtime) {
    return 'Try $runtime again';
  }

  @override
  String get setupSwitchInProgressHint =>
      'You can leave this screen and return to check progress.';

  @override
  String get setupSwitchPreparing => 'Preparing the runtime switch…';

  @override
  String get setupSwitchFailed =>
      'Could not finish switching runtimes. Check the setup output, then retry or return to the previous runtime.';

  @override
  String setupSwitchConnect(String runtime) {
    return 'Connect to $runtime';
  }

  @override
  String get setupSwitchLegacyTwo =>
      'This OpenCode 2 installation keeps its existing data. Switching it to OpenCode 1 is not available.';

  @override
  String setupSwitchProfileName(String runtime) {
    return 'This phone · $runtime';
  }

  @override
  String get setupSwitchReady =>
      'The local runtime is ready. Your current remote connection is unchanged.';

  @override
  String get setupSwitchMissingCredential =>
      'The saved credential for the previous runtime is unavailable. Its data is retained; restore the saved server before returning.';

  @override
  String get setupSwitchOwnDescription =>
      'Connect an existing OpenCode 1 or OpenCode 2 server by address.';

  @override
  String setupSwitchProgressTitle(String runtime) {
    return 'Switching to $runtime';
  }

  @override
  String get setupSwitchDataNotice =>
      'Each version keeps its own conversations and provider settings. Project files and project configuration are shared.';

  @override
  String get setupSwitchHelp => 'Setup help';

  @override
  String get setupSwitchReadyToConnect => 'Ready to connect';

  @override
  String get setupSwitchStopped => 'Ready to start';

  @override
  String get setupSwitchAttention => 'Needs attention';

  @override
  String get setupSwitchLocalRuntime => 'On this phone';

  @override
  String e7ConnectionFailure1(int attempts) {
    return 'Tried $attempts times. Retrying will not start a server that is not running.';
  }

  @override
  String get e7ConnectionFailure2 => 'Connection token required';

  @override
  String get e7ConnectionFailure3 =>
      'This Codex server needs a connection token before the app can connect.';

  @override
  String get e7ConnectionFailure4 =>
      'Open server settings and enter the Codex connection token.';

  @override
  String get e7ConnectionFailure5 => 'Connection token rejected';

  @override
  String get e7ConnectionFailure6 =>
      'The Codex server answered, but it did not accept the saved connection token.';

  @override
  String get e7ConnectionFailure7 =>
      'Open server settings and enter a current Codex connection token.';

  @override
  String get e7ConnectionFailure8 => 'Codex listener unavailable';

  @override
  String get e7ConnectionFailure9 => 'Codex endpoint unreachable';

  @override
  String e7ConnectionFailure10(String hostLabel, int port) {
    return '$hostLabel:$port is a local Codex listener, but nothing answered.';
  }

  @override
  String e7ConnectionFailure11(String hostLabel, int port) {
    return 'Nothing answered at the remote Codex endpoint $hostLabel:$port.';
  }

  @override
  String get e7ConnectionFailure12 =>
      'Start the Codex listener on this device.';

  @override
  String get e7ConnectionFailure13 =>
      'If it is behind a tunnel, keep the tunnel running and verify its local endpoint.';

  @override
  String get e7ConnectionFailure14 =>
      'Use the Codex wss:// endpoint or an active secure tunnel.';

  @override
  String get e7ConnectionFailure15 =>
      'Check that the remote Codex listener is reachable from this device.';

  @override
  String get e7ConnectionFailure16 => 'Password rejected';

  @override
  String get e7ConnectionFailure17 =>
      'The server answered, but it did not accept the saved password. This happens when the server was restarted with a new password.';

  @override
  String get e7ConnectionFailure18 =>
      'Run opencode2 pair on the computer and paste the new code.';

  @override
  String get e7ConnectionFailure19 =>
      'If you set OPENCODE_SERVER_PASSWORD by hand, copy it again.';

  @override
  String get e7ConnectionFailure20 => 'Certificate not trusted';

  @override
  String get e7ConnectionFailure21 =>
      'The server is there, but this device does not trust its HTTPS certificate, so the app refused to send the password.';

  @override
  String get e7ConnectionFailure22 =>
      'Use a certificate from a trusted authority, or a Tailscale Serve address.';

  @override
  String get e7ConnectionFailure23 =>
      'For a self-signed certificate, install it on this device first.';

  @override
  String get e7ConnectionFailure24 => 'Nothing is listening on this device';

  @override
  String e7ConnectionFailure25(String hostLabel, int port) {
    return '$hostLabel:$port means the server should be running on this device, or reached through a tunnel that ends here. Neither answered.';
  }

  @override
  String get e7ConnectionFailure26 =>
      'Running OpenCode in Termux? Open Termux and check that the server is still running.';

  @override
  String get e7ConnectionFailure27 =>
      'Using adb reverse or an SSH forward? Check that the tunnel is still connected, then try again.';

  @override
  String get e7ConnectionFailure28 =>
      'Connecting to another computer instead? Change the server to its HTTPS address or pair again.';

  @override
  String get e7ConnectionFailure29 => 'The server did not answer in time';

  @override
  String e7ConnectionFailure30(String hostLabel) {
    return 'Something is at $hostLabel, but it did not reply. Usually the network in between, not the server.';
  }

  @override
  String get e7ConnectionFailure31 =>
      'Are you on the same network or VPN (for example Tailscale) as the computer?';

  @override
  String e7ConnectionFailure32(int port) {
    return 'Is a firewall or captive portal blocking port $port?';
  }

  @override
  String get e7ConnectionFailure33 => 'Server not reachable';

  @override
  String e7ConnectionFailure34(String hostLabel, int port) {
    return 'Nothing answered at $hostLabel:$port. Either the server is not running or this device cannot reach that address.';
  }

  @override
  String get e7ConnectionFailure35 =>
      'Is opencode serve still running on the computer?';

  @override
  String get e7ConnectionFailure36 =>
      'Are you on the same network or VPN as the computer?';

  @override
  String get e7ConnectionFailure37 =>
      'Did the address change? Pair again to pick up the new one.';

  @override
  String get e7ConnectionFailure38 => 'The server answered with an error';

  @override
  String get e7ConnectionFailure39 =>
      'The server is running but reported itself unhealthy. Its own log will say why.';

  @override
  String get e7ConnectionFailure40 =>
      'Restart opencode serve and watch its output.';

  @override
  String get e7ConnectionFailure41 =>
      'Check that the server version is supported by this app.';

  @override
  String get e7ConnectionFailure42 => 'Could not connect';

  @override
  String e7ConnectionFailure43(String hostLabel) {
    return 'The connection to $hostLabel failed. Details below.';
  }

  @override
  String get e7ConnectionFailure44 =>
      'Is the agent server running, and is this the right address?';

  @override
  String get e7ConnectionFailure45 =>
      'Is opencode serve running, and is this the right address?';

  @override
  String get e7PermissionAction1 => 'Run a shell command';

  @override
  String get e7PermissionAction2 => 'Edit a file';

  @override
  String get e7PermissionAction3 => 'Read a file';

  @override
  String get e7PermissionAction4 => 'Access an external directory';

  @override
  String get e7PermissionAction5 => 'Continue after repeated failures';

  @override
  String get e7PermissionAction6 => 'Permission needed';

  @override
  String e7PermissionAction7(String permission) {
    return 'Use $permission';
  }

  @override
  String get e7GlossaryMcpExplanation =>
      'Model Context Protocol. Small add-on servers that give the agent extra tools, like a browser, a database, or a design tool. You connect them once and every conversation can use them.';

  @override
  String get e7GlossaryWorktreeTerm => 'Worktree';

  @override
  String get e7GlossaryWorktreeExplanation =>
      'A separate checkout of the same repository. Use one when you want the agent to try something on its own branch without touching the code you are working in.';

  @override
  String get e7GlossaryProviderExplanation =>
      'The company that hosts a model, such as Anthropic, OpenAI or a local runtime. Each one needs its own API key or login.';

  @override
  String get e7GlossaryContextTerm => 'Context';

  @override
  String get e7GlossaryContextExplanation =>
      'Everything the model can see right now: your messages, files it read, and tool results. It has a size limit. When it fills up, older parts are summarised so the conversation can continue.';

  @override
  String get e7GlossaryAgentTerm => 'Agent';

  @override
  String get e7GlossaryAgentExplanation =>
      'A named set of instructions and permissions the model works under. The default one can read and edit code. Others might only plan, or only review.';

  @override
  String get e7GlossaryReasoningExplanation =>
      'The model’s working notes before it answers. Useful for seeing why it made a choice. Hidden by default to keep the conversation short.';

  @override
  String get e7GlossaryPermissionTerm => 'Permission';

  @override
  String get e7GlossaryPermissionExplanation =>
      'Before the agent runs a command or edits a file outside what it is already allowed, it asks you. Allow once, or always for that pattern.';

  @override
  String get e7GlossaryVariantTerm => 'Variant';

  @override
  String get e7GlossaryVariantExplanation =>
      'A speed-versus-depth setting for the model, such as how long it may think before answering.';

  @override
  String get e7GlossaryGotIt => 'Got it';

  @override
  String e7GlossaryExplain(String term) {
    return '$term. Tap for an explanation.';
  }

  @override
  String get e7BannerTokenRejected => 'The connection token was rejected';

  @override
  String get e7BannerPasswordChanged => 'The server password changed';

  @override
  String get e7BannerReconnectPassword =>
      'Server password changed — reconnect.';

  @override
  String get e7BannerUpdatePassword => 'Update password';

  @override
  String get e7BannerLost => 'Connection lost';

  @override
  String get e7BannerRetrying => 'Retrying';

  @override
  String get e7BannerDetails => 'Details';

  @override
  String get e7BannerChangeServer => 'Change server';

  @override
  String e7BannerReconnectPasswordNote(String note) {
    return 'Server password changed — reconnect.\n$note';
  }

  @override
  String e7BannerReconnectingServer(String server) {
    return 'Reconnecting to $server…';
  }

  @override
  String e7BannerReconnectingServerSemantic(String server) {
    return 'Reconnecting to $server';
  }

  @override
  String get e7BannerCheckingExplanation =>
      'What you see stays available while OpenCode is checked. Live updates resume on their own.';

  @override
  String get e7BannerStaleExplanation =>
      'What you see may be stale until OpenCode is reachable again.';

  @override
  String get e7SharedThreeStepsToYourFirstSession =>
      'Three steps to your first conversation';

  @override
  String get e7SharedOpenCodeRunsOnYourComputerThisApp =>
      'OpenCode runs on your computer. This app is the remote. Pairing connects the two with one command — no addresses or passwords to type.';

  @override
  String get e7SharedOnYourComputerRunOneCommand =>
      'On your computer, run one command';

  @override
  String get e7SharedInATerminalOnTheComputerWhere =>
      'In a terminal on the computer where OpenCode is installed:';

  @override
  String get e7SharedItStartsTheServerAndPrintsA =>
      'It starts the server and prints a pairing code — and a QR code you can scan.';

  @override
  String get e7SharedScanTheQROrPasteTheCode =>
      'Scan the QR or paste the code in this app';

  @override
  String get e7SharedPasteTheCodeInThisApp => 'Paste the code in this app';

  @override
  String get e7SharedOpenServersTapScanAndPointThe =>
      'Open Servers, tap Scan and point the camera at the QR — or copy the code and tap Paste pairing code. The address, username and password fill in together.';

  @override
  String get e7SharedCopyThePrintedCodeOpenServersAnd =>
      'Copy the printed code, open Servers and tap Paste pairing code. The address, username and password fill in together.';

  @override
  String get e7SharedStartTalking => 'Start talking';

  @override
  String get e7SharedPickAProjectAndSendYourFirst =>
      'Pick a project and send your first message. The work happens on your computer; this app shows it and lets you steer.';

  @override
  String get e7SharedAdvanced => 'Advanced';

  @override
  String get e7SharedHTTPSSSHTunnelsOlderServersTermuxInternals =>
      'HTTPS, SSH tunnels, older servers, Termux internals';

  @override
  String get e7SharedHTTPSSSHTunnelsOlderServers =>
      'HTTPS, SSH tunnels, older servers';

  @override
  String get e7SharedReachAServerOverHTTPSOrA =>
      'Reach a server over HTTPS or a tunnel';

  @override
  String get e7SharedPairingWorksWhenTheAddressTheServer =>
      'Pairing works when the address the server prints is one this device can reach. If it is not, expose the server through an HTTPS reverse proxy or an encrypted tunnel and add the resulting https:// URL by hand. Remote HTTP is intentionally blocked.';

  @override
  String get e7SharedOlderServersWithoutPairing =>
      'Older servers without pairing';

  @override
  String get e7SharedServersStartedWithOpencodeServeDoNot =>
      'Servers started with `opencode serve` do not print a pairing code. Start them on loopback with a password:';

  @override
  String get e7SharedThenAddTheServerManuallyWithUsername =>
      'Then add the server manually with username opencode and that password.';

  @override
  String get e7SharedOnDeviceViaTermuxAutomated =>
      'On-device via Termux (automated)';

  @override
  String get e7SharedUseTheOnDeviceTermuxCardOn =>
      'Use the “On-device (Termux)” card on the Servers screen. The app installs Termux, unlocks the bridge, sets up opencode, starts the server and connects — all guided.';

  @override
  String get e7SharedOnlyTwoTapsNeedYouPersonallyDownloading =>
      'Only two taps need you personally: downloading the Termux APK and pasting one unlock line inside Termux once — both required by Android’s security model, not by this app.';

  @override
  String get e7SharedPreferManualInsideTermuxRun =>
      'Prefer manual? Inside Termux run:';

  @override
  String get e7SharedTheChrootSharesTheNetworkStackSo =>
      'The chroot shares the network stack, so http://127.0.0.1:4096 works from this app. Run `termux-wake-lock` to keep it alive.';

  @override
  String get e7SharedSecurityNotes => 'Security notes';

  @override
  String get e7SharedAlwaysSetOPENCODESERVERPASSWORDWhenBinding =>
      'Always set OPENCODE_SERVER_PASSWORD when binding beyond localhost.';

  @override
  String get e7SharedPasswordsAreStoredInTheAndroidKeystore =>
      'Passwords are stored in the Android Keystore on this device only.';

  @override
  String get e7SharedTheServerCanExecuteCommandsOnIts =>
      'The server can execute commands on its host — treat access like SSH access.';

  @override
  String get e7SharedCopied => 'Copied';

  @override
  String get e7SharedOpenCodeIsReconnectingTryAgain =>
      'OpenCode is reconnecting. Try again.';

  @override
  String get e7SharedSessionContext => 'Conversation context';

  @override
  String get e7SharedRefreshContext => 'Refresh context';

  @override
  String get e7SharedNoContextUsageYet => 'No context usage yet';

  @override
  String get e7SharedSendAPromptAndWaitForAn =>
      'Send a prompt and wait for an assistant response. OpenCode will then report token usage for this conversation.';

  @override
  String get e7SharedCurrentModelRequest => 'Current model request';

  @override
  String get e7SharedEstimatedInputMakeup => 'Estimated input makeup';

  @override
  String get e7SharedSessionTotals => 'Conversation totals';

  @override
  String get e7SharedUsageComesFromTheLatestCompletedAssistant =>
      'Usage comes from the latest completed assistant message. The makeup is an estimate from visible prompt, response, and tool text; Other includes system instructions, tool definitions, and provider overhead.';

  @override
  String get e7SharedModelUnavailable => 'Model unavailable';

  @override
  String get e7SharedContextLimitUnavailable => 'Context limit unavailable';

  @override
  String get e7SharedLatestAssistantRequestIncludingCacheActivity =>
      'Latest assistant request, including cache activity';

  @override
  String get e7SharedContextLimit => 'Context limit';

  @override
  String get e7SharedUnavailable => 'Unavailable';

  @override
  String get e7SharedMessages => 'Messages';

  @override
  String get e7SharedUserAssistant => 'User / assistant';

  @override
  String get e7SharedAccumulatedCostReportedByServer =>
      'Accumulated cost · reported by server';

  @override
  String get e7SharedAccumulatedCost => 'Accumulated cost';

  @override
  String get e7SharedSessionTokensReportedByServer =>
      'Conversation tokens · reported by server';

  @override
  String get e7SharedUserPrompts => 'User prompts';

  @override
  String get e7SharedAssistantText => 'Assistant text';

  @override
  String get e7SharedToolCallsAndResults => 'Tool calls and results';

  @override
  String get e7SharedOtherContext => 'Other context';

  @override
  String get e7SharedMove => 'Move';

  @override
  String get e7SharedSessionLocationChangedCloseAndReopenThis =>
      'The conversation’s project changed. Close and reopen this sheet.';

  @override
  String get e7SharedOpenCodeIsReconnecting => 'OpenCode is reconnecting.';

  @override
  String get e7SharedTheSessionProjectIsNotAvailableOn =>
      'The conversation project is not available on this server.';

  @override
  String get e7SharedLocalProject => 'Local project';

  @override
  String get e7SharedTheAppCouldNotInspectWorkingChanges =>
      'The app could not inspect working changes. For safety, this continues without transferring changes.';

  @override
  String get e7SharedMoveWithChanges => 'Move with changes';

  @override
  String get e7SharedCopyChangesAndMove => 'Copy changes and move';

  @override
  String get e7SharedMoveSession => 'Move conversation';

  @override
  String get e7SharedChooseAnotherDirectoryInThisProject =>
      'Choose another directory in this project.';

  @override
  String get e7SharedChooseAConnectedWorkspaceOrReturnTo =>
      'Choose a connected cloud environment, or return to the local project.';

  @override
  String get e7SharedFilterDestinations => 'Filter destinations';

  @override
  String get e7SharedNoOtherDestinationsAreAvailable =>
      'No other destinations are available.';

  @override
  String get e7SharedNoDestinationsMatchThisFilter =>
      'No destinations match this filter.';

  @override
  String get e7SharedCurrent => 'Current';

  @override
  String get e7SharedSwitchOrganization => 'Switch organization?';

  @override
  String get e7SharedSwitch => 'Switch';

  @override
  String get e7SharedSwitchOrganization462 => 'Switch organization';

  @override
  String get e7SharedNoSwitchableOpenCodeConsoleOrganizationsWereReturned =>
      'No switchable OpenCode Console organizations were returned.';

  @override
  String get e7SharedSessionLocationChangedReturnAndReopenRelated =>
      'The conversation’s project changed. Return and reopen related conversations.';

  @override
  String get e7SharedSessionIsNoLongerRelatedToThis =>
      'That conversation is no longer related to this one.';

  @override
  String get e7SharedSessionLocationChangedReturnAndTryAgain =>
      'The conversation’s project changed. Return and try again.';

  @override
  String get e7SharedSessionUnavailableOrLocationChangedReturnOr =>
      'Conversation unavailable or its project changed. Return or refresh to try again.';

  @override
  String get e7SharedCouldNotUpdateThePinReturnAnd =>
      'Could not update the pin. Return and try again.';

  @override
  String get e7SharedRefreshSubagentSessions =>
      'Refresh subagent conversations';

  @override
  String get e7SharedParentSession => 'Parent conversation';

  @override
  String get e7SharedSubagents => 'Subagents';

  @override
  String get e7SharedNoSubagentSessionsYet => 'No subagent conversations yet';

  @override
  String get e7SharedDelegatedWorkWillAppearHereWithoutMixing =>
      'Delegated work will appear here without mixing subagent conversations into your main list.';

  @override
  String get e7SharedOpenCodeHasNotDelegatedWorkFromThis =>
      'OpenCode has not delegated work from this conversation.';

  @override
  String get e7SharedUnpinSession => 'Unpin conversation';

  @override
  String get e7SharedPinSession => 'Pin conversation';

  @override
  String get e7SharedLinkBlockedThisAppMayOpenOnly =>
      'Link blocked. This app may open only https:// URLs, or confirmed http:// URLs.';

  @override
  String get e7SharedOpenInsecureHTTPLink => 'Open insecure HTTP link?';

  @override
  String get e7SharedOpenExternalLink => 'Open external link?';

  @override
  String get e7SharedHost => 'Host';

  @override
  String get e7SharedHTTPIsNotEncryptedOtherDevicesOn =>
      'HTTP is not encrypted. Other devices on the network may read or change what you send and receive.';

  @override
  String get e7SharedOpenHTTPLink => 'Open HTTP link';

  @override
  String get e7SharedOpenLink => 'Open link';

  @override
  String get e7SharedNoAppCouldOpenThisLink => 'No app could open this link.';

  @override
  String get e7SharedRequired => 'Required';

  @override
  String get e7SharedDoesNotMatchTheExpectedFormat =>
      'Does not match the expected format';

  @override
  String get e7SharedEnterAWholeNumber => 'Enter a whole number';

  @override
  String get e7SharedEnterANumber => 'Enter a number';

  @override
  String get e7SharedDismissThisRequest => 'Dismiss this request?';

  @override
  String get e7SharedTheAgentContinuesWithoutYourAnswers =>
      'The agent continues without your answers.';

  @override
  String get e7SharedAskedByAnMCPServer => 'Asked by an MCP server';

  @override
  String get e7SharedAskedByTheAgentInThisSession =>
      'Asked by the agent in this conversation';

  @override
  String get e7SharedInputRequested => 'Input requested';

  @override
  String get e7SharedOther => 'Other…';

  @override
  String get e7SharedYourAnswer => 'Your answer';

  @override
  String get e7SharedAddYourOwn => 'Add your own';

  @override
  String get e7SharedAddAnswer => 'Add answer';

  @override
  String get e7SharedThisServerSentALinkThisApp =>
      'This server sent a link this app will not open.';

  @override
  String get e7SharedSendAnswers => 'Send answers';

  @override
  String get e7SharedRecommended => 'Recommended';

  @override
  String e7SharedDetail307(int step) {
    return 'Step $step of 3';
  }

  @override
  String e7SharedDetail381(String percent) {
    return '$percent percent context used';
  }

  @override
  String e7SharedDetail385(String count, String limit) {
    return '$count of $limit tokens';
  }

  @override
  String e7SharedDetail386(String count) {
    return '$count tokens · limit unavailable';
  }

  @override
  String e7SharedDetail409(String error) {
    return 'Could not refresh: $error';
  }

  @override
  String e7SharedDetail428(String destination) {
    return 'Moved to $destination';
  }

  @override
  String get e7SharedDetail429 => 'Move conversation?';

  @override
  String e7SharedDetail430(int count, String action) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changed files are present.',
      one: '1 changed file is present.',
    );
    String _temp1 = intl.Intl.selectLogic(action, {
      'move': 'move',
      'other': 'be copied',
    });
    return '$_temp0 Choose whether those working changes should $_temp1 with the conversation.';
  }

  @override
  String e7SharedDetail432(String destination) {
    return 'Continue to $destination?';
  }

  @override
  String get e7SharedDetail435 => 'Move only';

  @override
  String e7SharedDetail456(String organization) {
    return 'Models and providers will reload using $organization.';
  }

  @override
  String e7SharedDetail460(String organization) {
    return 'Switched to $organization';
  }

  @override
  String e7SharedDetail514(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String e7SharedDetail517(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count delegated conversations · open any transcript directly.',
      one: '1 delegated conversation · open any transcript directly.',
    );
    return '$_temp0';
  }

  @override
  String e7SharedDetail518(int position, int total) {
    return '$position of $total';
  }

  @override
  String e7SharedDetail699(String error) {
    return 'Could not open link: $error';
  }

  @override
  String e7SharedDetail714(int count) {
    return 'Must be at least $count characters';
  }

  @override
  String e7SharedDetail715(int count) {
    return 'Must be at most $count characters';
  }

  @override
  String e7SharedDetail721(String minimum, String maximum) {
    return 'Must be between $minimum and $maximum';
  }

  @override
  String e7SharedDetail722(String minimum) {
    return 'Must be at least $minimum';
  }

  @override
  String e7SharedDetail723(String maximum) {
    return 'Must be at most $maximum';
  }

  @override
  String e7SharedDetail725(int count) {
    return 'Pick at least $count';
  }

  @override
  String e7SharedDetail726(int count) {
    return 'Pick at most $count';
  }

  @override
  String e7SharedDetail753(int minimum, int maximum) {
    return 'Pick $minimum–$maximum';
  }

  @override
  String e7SharedDetail754(int count) {
    return 'Pick at least $count';
  }

  @override
  String e7SharedDetail755(int count) {
    return 'Pick up to $count';
  }

  @override
  String e7SharedDetail756(String range, int count) {
    return '$range · $count selected';
  }

  @override
  String e7SharedDetail764(String host) {
    return 'Opens $host in your browser';
  }

  @override
  String e7SharedDetail765(String field) {
    return 'This server sent a field type this app does not understand (\"$field\").';
  }

  @override
  String get e7LocaleUiLanguage => 'Language';

  @override
  String get e7LocaleUiEnglish => 'English';

  @override
  String get e7LocaleUiArabic => 'العربية';

  @override
  String get e7LocaleUiSystem => 'Use system language';

  @override
  String get e7LocaleUiClose => 'Close';

  @override
  String get e7LocaleUiDescription =>
      'Choose the language used throughout the app. Server messages and your text stay as written.';

  @override
  String get e7LocaleUiSaving => 'Saving language…';

  @override
  String get e7LocaleUiSaveFailed =>
      'Language could not be saved. Your previous choice is still active. Select a language to try again.';

  @override
  String get e7LocaleUiStarting => 'Starting OpenCode…';

  @override
  String get e7LocaleUiStartFailed => 'OpenCode could not start';

  @override
  String get e7LocaleUiUnknownStartupError => 'Unknown startup error';

  @override
  String get e7LocaleUiRetry => 'Try again';

  @override
  String get e7LocaleUiNewSession => 'New conversation';

  @override
  String get e7LocaleUiNewSessionHint =>
      'Start a conversation in the active project';

  @override
  String get e7LocaleUiWorkspace => 'Work';

  @override
  String get e7LocaleUiWorkspaceHint =>
      'Recent conversations and the active project';

  @override
  String get e7LocaleUiFiles => 'Project';

  @override
  String get e7LocaleUiFilesHint =>
      'Files, changes, terminal and other project tools';

  @override
  String get e7LocaleUiActivity => 'Inbox';

  @override
  String get e7LocaleUiActivityHint => 'Permissions, questions, and forms';

  @override
  String get e7LocaleUiMoreHint => 'Models, providers, notifications, settings';

  @override
  String get e7LocaleUiSettings => 'Settings';

  @override
  String get e7LocaleUiKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get e7LocaleUiRefreshSessions => 'Refresh conversations';

  @override
  String get e7LocaleUiDiagnostics => 'Diagnostics';

  @override
  String get e7LocaleUiDiagnosticsHint => 'Recent errors and connection detail';

  @override
  String get e7LocaleUiCommandLauncher => 'Command launcher';

  @override
  String get e7LocaleUiFindSurface => 'Find in this surface';

  @override
  String get e7LocaleUiDestinations => 'Work, Inbox, Project, Settings';

  @override
  String get e7LocaleUiTerminal => 'Terminal';

  @override
  String get e7LocaleUiCloseScreen => 'Close this screen';

  @override
  String get e7LocaleUiSendPrompt => 'Send the prompt';

  @override
  String get e7LocaleUiCopyTranscript => 'Copy the selected transcript text';

  @override
  String get e7LocaleUiRecentModel =>
      'Next / previous recent model in this conversation';

  @override
  String get e7LocaleUiThisList => 'This list';

  @override
  String get e7LocaleUiCloseOverlay => 'Close a sheet, dialog, or menu';

  @override
  String get e7LocaleUiContextActions =>
      'Message, file, and conversation actions';

  @override
  String get e7LocaleUiTypeCommand => 'Type a command…';

  @override
  String get e7LocaleUiNoCommand => 'No matching command';

  @override
  String get e7LocaleUiContextKeys => 'Right click / Shift + F10 / Menu';

  @override
  String get e7LocaleUiShareScopeChanged => 'Shared conversation scope changed';

  @override
  String get e7LocaleUiConnectionChanged => 'The server changed.';

  @override
  String get e7AppearanceFollowAndroid => 'Follow Android';

  @override
  String get e7AppearanceFollowSystem => 'Follow system';

  @override
  String get e7AppearanceLight => 'Light';

  @override
  String get e7AppearanceDark => 'Dark';

  @override
  String get e7AppearanceFollowPhoneDescription =>
      'Match this phone’s current light or dark setting';

  @override
  String get e7AppearanceFollowDeviceDescription =>
      'Match this device’s current light or dark setting';

  @override
  String get e7AppearanceLightDescription => 'Use the bright editorial theme';

  @override
  String get e7AppearanceDarkDescription => 'Use the focused low-light theme';

  @override
  String get e7AppearanceTitle => 'Appearance';

  @override
  String get e7AppearancePreviewHint =>
      'Preview first. Your appearance changes only when you apply it.';

  @override
  String get e7AppearanceDynamicUnavailable =>
      'Material You colors are not available on this device.';

  @override
  String e7AppearanceUsesMode(String mode) {
    return 'Your light or dark setting stays $mode.';
  }

  @override
  String get e7AppearanceSaveFailed =>
      'Could not save the appearance. Your previous setting is unchanged. Try again.';

  @override
  String get e7AppearanceSaving => 'Saving…';

  @override
  String get e7AppearanceApply => 'Apply';

  @override
  String get e7AppearanceCurrent => 'Current appearance';

  @override
  String get e7AppearanceClose => 'Close';

  @override
  String get e7AppearancePreviewTitle => 'Text and controls';

  @override
  String get e7AppearancePreviewBody =>
      'See how reading, code and selected actions work together.';

  @override
  String get e7AppearanceSelection => 'Selected option';

  @override
  String get e7AppearanceTryControl => 'Try a control';

  @override
  String get e7AppearanceSampleHint =>
      'Sample controls only change this preview.';

  @override
  String get e7SettingsUi1 => 'Server';

  @override
  String get e7SettingsUi8 => 'Disconnect';

  @override
  String get e7SettingsUi9 => 'OpenCode server';

  @override
  String get e7SettingsUi11 => 'Checking server health…';

  @override
  String get e7SettingsUi12 => 'Stopped by Android';

  @override
  String get e7SettingsUi14 => 'On · running now';

  @override
  String get e7SettingsUi15 => 'On · starting';

  @override
  String get e7SettingsUi16 => 'this server';

  @override
  String get e7SettingsUi17 => 'unknown';

  @override
  String get e7SettingsUi18 => 'OpenCode is reconnecting.';

  @override
  String get e7SettingsUi19 => 'OpenCode is reconnecting. Try again.';

  @override
  String get e7SettingsUi20 =>
      'Live updates stop and you return to the server list. The server keeps running; nothing on it is changed.';

  @override
  String get e7SettingsUi21 => 'Nothing is waiting to send.';

  @override
  String get e7SettingsUi22 => 'Android did not enable background mode.';

  @override
  String get e7SettingsUi23 => 'Android stopped the live connection';

  @override
  String get e7SettingsUi24 =>
      'Its daily limit for background data-sync work is spent, so live mode turned itself off. Turn it back on to reconnect; the limit resets within 24 hours.';

  @override
  String get e7SettingsUi25 => 'Stay connected in the background';

  @override
  String get e7SettingsUi26 =>
      'Keeps runs updating when the app is closed and notifies you when one needs you. Uses more battery and shows a persistent notification.';

  @override
  String get e7SettingsUi27 => 'Unrestricted battery access allowed';

  @override
  String get e7SettingsUi28 => 'Allow unrestricted battery access';

  @override
  String get e7SettingsUi29 =>
      'Android may still apply its foreground-service time limit.';

  @override
  String get e7SettingsUi30 =>
      'Optional. Helps preserve the live connection during Doze. Android 15+ limits data-sync background work to six hours per 24 hours.';

  @override
  String get e7SettingsUi31 => 'Stopped by Android — tap to restart';

  @override
  String get e7SettingsUi32 => 'Running now';

  @override
  String get e7SettingsUi34 =>
      'Android 15+ allows six hours of this per 24 hours and then stops it; the app turns the switch off and says so when that happens.';

  @override
  String get e7SettingsUi35 => 'Default shell';

  @override
  String get e7SettingsUi36 =>
      'Used by new terminals and compatible shell commands on this OpenCode server.';

  @override
  String get e7SettingsUi37 =>
      'Terminal only; OpenCode uses a compatible fallback for shell tools.';

  @override
  String get e7SettingsUi38 => 'Default shell updated';

  @override
  String get e7SettingsUi39 => 'Automatic (server default)';

  @override
  String get e7SettingsUi40 =>
      'Shell selection isn\'t available on OpenCode 2 servers';

  @override
  String get e7SettingsUi41 => 'Loading shells from OpenCode…';

  @override
  String get e7SettingsUi45 => 'Server update commands copied';

  @override
  String get e7SettingsUi46 => 'Restart OpenCode on its host';

  @override
  String get e7SettingsUi48 => 'Update remote OpenCode?';

  @override
  String get e7SettingsUi49 =>
      'The active server changed before the upgrade completed';

  @override
  String get e7SettingsUi50 => 'Update managed OpenCode';

  @override
  String get e7SettingsUi51 =>
      'Install the latest stable server, refresh models, restart safely, and reconnect.';

  @override
  String get e7SettingsUi52 => 'the previous version';

  @override
  String get e7SettingsUi53 => 'an unknown version';

  @override
  String get e7SettingsUi54 => 'Server updates are managed externally';

  @override
  String get e7SettingsUi55 =>
      'Copy the official upgrade and model-refresh commands to run on the server host.';

  @override
  String get e7SettingsUi56 => 'Not connected';

  @override
  String get e7SettingsUi57 => 'Check server health';

  @override
  String get e7SettingsUi58 => 'Asking the server how it is doing';

  @override
  String get e7SettingsUi59 => 'Server healthy';

  @override
  String get e7SettingsUi60 => 'Health unavailable';

  @override
  String get e7SettingsUi61 => 'Authentication';

  @override
  String get e7SettingsUi62 => 'No server password saved';

  @override
  String get e7SettingsUi64 => 'Add, edit, or switch OpenCode servers';

  @override
  String get e7SettingsUi65 => 'Run as a Linux service';

  @override
  String get e7SettingsUi66 =>
      'Keep OpenCode running on your computer after you close the terminal; copy setup, status, restart, log, and update commands';

  @override
  String get e7SettingsUi67 => 'Server updates';

  @override
  String get e7SettingsUi68 => 'Upgrade from the machine running the server';

  @override
  String get e7SettingsUi69 => 'Light or dark';

  @override
  String get e7SettingsUi70 => 'Theme';

  @override
  String get e7SettingsUi71 => 'Needs Android 12 or newer';

  @override
  String get e7SettingsUi72 => 'This phone’s Material You colors';

  @override
  String get e7SettingsUi74 => 'Always allowed actions';

  @override
  String get e7SettingsUi75 =>
      'Review or revoke durable OpenCode permissions for this project';

  @override
  String get e7SettingsUi76 => 'On this device';

  @override
  String get e7SettingsUi77 => 'Storage used';

  @override
  String get e7SettingsUi78 => 'Clear queued prompts';

  @override
  String get e7SettingsUi79 => 'Nothing is waiting to send';

  @override
  String get e7SettingsUi80 => 'Delete queued prompts?';

  @override
  String get e7SettingsUi81 => 'Queued prompts deleted';

  @override
  String get e7SettingsUi82 =>
      'Could not delete the queued prompts. Check device storage and try again.';

  @override
  String get e7SettingsUi83 => 'Clear drafts';

  @override
  String get e7SettingsUi84 => 'No saved composer text';

  @override
  String get e7SettingsUi85 => 'Delete drafts?';

  @override
  String get e7SettingsUi86 => 'Drafts deleted';

  @override
  String get e7SettingsUi87 =>
      'Could not delete the drafts. Check device storage and try again.';

  @override
  String get e7SettingsUi88 => 'App diagnostics';

  @override
  String get e7SettingsUi89 => 'No captured errors';

  @override
  String get e7SettingsUi91 =>
      'Connect a computer or run OpenCode on this phone';

  @override
  String get e7SettingsUi92 => 'Privacy and data use';

  @override
  String get e7SettingsUi93 =>
      'Servers, providers, voice, files, Termux, and updates';

  @override
  String get e7SettingsUi94 => 'Voice licenses and provenance';

  @override
  String get e7SettingsUi95 =>
      'Whisper models, sherpa-onnx, ONNX Runtime, and record';

  @override
  String get e7SettingsUi96 => 'About and open source notices';

  @override
  String get e7SettingsUi97 => 'App details, components, and license notices';

  @override
  String e7SettingsDisconnectBody(int queued, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      queued,
      locale: localeName,
      other: '$queued queued prompts.',
      one: '1 queued prompt.',
      zero: 'No queued prompts.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts unsent drafts.',
      one: '1 unsent draft.',
      zero: 'No unsent drafts.',
    );
    return 'Live updates stop and you return to the server list. The server keeps running; nothing on it is changed.\n\n$_temp0 $_temp1 They stay on this device until you connect to this server again.';
  }

  @override
  String e7SettingsDisconnectTitle(String server) {
    return 'Disconnect from $server?';
  }

  @override
  String e7SettingsHealthError(String error) {
    return 'Health unavailable — $error';
  }

  @override
  String e7SettingsHealthVersion(String version) {
    return 'Server healthy · $version';
  }

  @override
  String e7SettingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get e7AppearancePackOpencode => 'Terminal green, the default';

  @override
  String get e7AppearancePackCatppuccin => 'Mocha and Latte, mauve-led';

  @override
  String get e7AppearancePackGruvbox => 'Warm retro, orange-led';

  @override
  String get e7AppearancePackSolarized => 'The classic dual palette, blue-led';

  @override
  String get e7AppearancePackDynamic => 'This phone’s Material You colors';

  @override
  String e7SettingsStorageSummary(
    String total,
    int queued,
    String queueBytes,
    int drafts,
    String draftBytes,
    int days,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      queued,
      locale: localeName,
      other: '$queued queued prompts',
      one: '1 queued prompt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts drafts',
      one: '1 draft',
    );
    return '$total of unsent work — $_temp0 ($queueBytes) and $_temp1 ($draftBytes). Queued prompts are discarded after $days days.';
  }

  @override
  String e7SettingsQueueDeleteSummary(int count) {
    return 'Deletes all $count unsent prompts and their attachments, for every server';
  }

  @override
  String e7SettingsQueueDeleteBody(int count) {
    return 'This deletes $count unsent prompts and their attachments, for every server. They will never be sent. Nothing on the server is affected.';
  }

  @override
  String e7SettingsDraftDeleteSummary(int count) {
    return 'Deletes composer text saved for $count conversations';
  }

  @override
  String e7SettingsDraftDeleteBody(int count) {
    return 'This deletes the composer text saved for $count conversations. Nothing on the server is affected.';
  }

  @override
  String e7SettingsDiagnosticCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count handled errors kept in memory',
      one: '1 handled error kept in memory',
    );
    return '$_temp0';
  }

  @override
  String e7SettingsRestartBody(String version, String current) {
    return 'OpenCode $version is installed, but this server process is still running $current. Restart that process on the server host; mobile will reconnect and confirm the running version.';
  }

  @override
  String e7SettingsUpgradeBody(String target, String server, String current) {
    return 'Install OpenCode $target on $server using the server’s detected installation method. The current process is running $current.\n\nThe install keeps server data in place, but the OpenCode process must be restarted on its host before the new version takes effect.';
  }

  @override
  String e7SettingsInstallVersion(String version) {
    return 'Install $version';
  }

  @override
  String e7SettingsInstalledVersion(String version) {
    return 'OpenCode $version installed. Restart its server process to use it.';
  }

  @override
  String e7SettingsRestartVersion(String version) {
    return 'Restart OpenCode to use $version';
  }

  @override
  String e7SettingsRetryError(String error) {
    return '$error Tap to retry.';
  }

  @override
  String e7SettingsInstalledCurrent(String version, String current) {
    return '$version is installed. The current process is still $current.';
  }

  @override
  String e7SettingsUpdateVersion(String version) {
    return 'Update OpenCode to $version';
  }

  @override
  String e7SettingsCurrentServer(String version) {
    return 'Current server: $version. Uses OpenCode’s official installer; host restart required.';
  }

  @override
  String e7SettingsAuthenticationUser(String user) {
    return 'Basic authentication enabled as $user';
  }

  @override
  String get e7SettingsDetailUi0 => 'Diagnostics copied';

  @override
  String get e7SettingsDetailUi2 => 'Diagnostics sent to OpenCode';

  @override
  String get e7SettingsDetailUi3 => 'Clear diagnostics?';

  @override
  String get e7SettingsDetailUi4 =>
      'This removes every captured error from process memory.';

  @override
  String get e7SettingsDetailUi5 => 'Clear';

  @override
  String get e7SettingsDetailUi7 => 'Private until you send it';

  @override
  String get e7SettingsDetailUi8 =>
      'Handled app errors are redacted and kept only in memory. Your messages and file contents are not collected. Nothing is sent automatically.';

  @override
  String get e7SettingsDetailUi10 => 'Send';

  @override
  String get e7SettingsDetailUi12 => 'This server doesn\'t accept client logs';

  @override
  String get e7SettingsDetailUi13 => 'No captured app errors';

  @override
  String get e7SettingsDetailUi14 =>
      'Handled Flutter, platform, and startup errors will appear here for this app run.';

  @override
  String get e7SettingsDetailUi16 => 'Report a bug';

  @override
  String get e7SettingsDetailUi17 => 'Privacy';

  @override
  String get e7SettingsDetailUi18 => 'Open source';

  @override
  String get e7SettingsDetailUi19 => 'About this build';

  @override
  String get e7SettingsDetailUi20 => 'OpenCode for Android';

  @override
  String get e7SettingsDetailUi21 => 'OpenCode for desktop';

  @override
  String get e7SettingsDetailUi22 =>
      'A mobile client for an OpenCode server. Voice recognition runs locally after optional model downloads.';

  @override
  String get e7SettingsDetailUi23 => 'A desktop client for an OpenCode server.';

  @override
  String get e7SettingsDetailUi25 => 'Tools';

  @override
  String get e7SettingsDetailUi26 => 'Skills';

  @override
  String get e7SettingsDetailUi27 => 'References';

  @override
  String get e7SettingsInformationFailed =>
      'App information could not be loaded. Try opening this page again.';

  @override
  String get e7SettingsAlphaBody =>
      'This independent app is built heavily with AI assistance. Android is the primary supported platform. Desktop builds are experimental and have not been hardware-tested. Report what breaks to help improve the app.';

  @override
  String get e7SettingsNonAffiliation =>
      'OpenCode Mobile is an independent community project. It is not built, maintained, endorsed by, or affiliated with the official OpenCode team.';

  @override
  String get e7SettingsOriginalLicenses =>
      'Third-party license notices below are reproduced in their original language.';

  @override
  String e7SettingsDiagnosticSendError(String error) {
    return 'Could not send diagnostics: $error';
  }

  @override
  String e7SettingsDiagnosticTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count handled errors',
      one: '1 handled error',
    );
    return '$_temp0';
  }

  @override
  String e7SettingsDiagnosticOccurrences(int count) {
    return '$count occurrences';
  }

  @override
  String get e7ProjectProjectsReconnect =>
      'OpenCode is reconnecting. Try again shortly.';

  @override
  String e7ProjectProjectRenamed(String name) {
    return 'Project renamed to $name';
  }

  @override
  String e7ProjectProjectRenameFailed(String error) {
    return 'Could not rename project: $error';
  }

  @override
  String get e7ProjectProjectDefaultDirectory =>
      'The server’s default directory';

  @override
  String get e7ProjectProjectSwitchUnavailable =>
      'Project switching is unavailable';

  @override
  String get e7ProjectProjectSwitchUnavailableDetail =>
      'This server keeps the configured folder for conversations. Start a new conversation from Work to continue.';

  @override
  String get e7ProjectProjectsTitle => 'Projects';

  @override
  String get e7ProjectProjectsRefresh => 'Refresh projects';

  @override
  String get e7ProjectProjectsSearch => 'Search projects or paths';

  @override
  String get e7ProjectProjectsClearSearch => 'Clear project search';

  @override
  String get e7ProjectProjectsOpened => 'Open projects';

  @override
  String e7ProjectProjectsCount(int shown, int total) {
    return '$shown of $total';
  }

  @override
  String get e7ProjectProjectsEmpty => 'No projects opened';

  @override
  String get e7ProjectProjectsEmptyDetail =>
      'Projects opened by this server appear here; choose one for conversations, files, terminals, and coding tools. Create a new folder or open one by its path above, or open a project on this OpenCode server and refresh.';

  @override
  String get e7ProjectProjectsNoMatch => 'No matching projects';

  @override
  String get e7ProjectProjectsNoMatchDetail =>
      'Try a project name or a directory from the server.';

  @override
  String get e7ProjectProjectsRefreshFailed => 'Project refresh failed';

  @override
  String e7ProjectProjectWorktrees(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count worktrees',
      one: '1 worktree',
    );
    return '$_temp0';
  }

  @override
  String e7ProjectProjectRenameAction(String name) {
    return 'Rename $name';
  }

  @override
  String get e7ProjectProjectRenameTitle => 'Rename project';

  @override
  String get e7ProjectProjectNameLabel => 'Project name';

  @override
  String get e7ProjectProjectNameHint =>
      'Clear the name to use the project folder name.';

  @override
  String get e7ProjectProjectSave => 'Save';

  @override
  String get e7ProjectAttentionNoServers => 'No saved servers';

  @override
  String get e7ProjectAttentionNoServersDetail =>
      'Add a server from the server list to see it here.';

  @override
  String get e7ProjectAttentionSavedServer => 'Saved server';

  @override
  String get e7ProjectAttentionSelected => 'Selected server';

  @override
  String get e7ProjectAttentionInactive => 'Inactive server';

  @override
  String get e7ProjectAttentionCacheSource =>
      'Source: selected server’s local cache. Scope: currently loaded project and conversations. Last refreshed: unknown.';

  @override
  String get e7ProjectAttentionProfileSource =>
      'Source: saved server only. Attention status: unknown. Last checked: unknown.';

  @override
  String get e7ProjectAttentionPendingUnknown => 'Pending requests: unknown';

  @override
  String e7ProjectAttentionPendingKnown(int count) {
    return 'Last-known pending requests: $count';
  }

  @override
  String get e7ProjectAttentionRunningUnknown =>
      'Running conversations: unknown';

  @override
  String e7ProjectAttentionRunningKnown(int count) {
    return 'Last-known running or retrying conversations: $count';
  }

  @override
  String get e7ProjectAttentionUnreadUnknown => 'Unread conversations: unknown';

  @override
  String e7ProjectAttentionUnreadKnown(int count) {
    return 'Last-known unread conversations: $count';
  }

  @override
  String get e7ProjectAttentionOpen => 'Open server';

  @override
  String get e7ProjectAttentionChoose => 'Choose server…';

  @override
  String get e7ProjectMonitorUnsupported =>
      'Background attention is unavailable for this server. Open the conversation to review current requests.';

  @override
  String get readerUiDisconnected => 'The server is not connected.';

  @override
  String get readerUiReconnectingRetry =>
      'OpenCode is reconnecting. Try again shortly.';

  @override
  String get readerUiIndicatorsUnavailable =>
      'File change indicators are unavailable on this server.';

  @override
  String get readerUiIndicatorsFailed =>
      'File change indicators could not refresh.';

  @override
  String get readerUiReconnecting => 'OpenCode is reconnecting.';

  @override
  String get readerUiCommentAdded =>
      'Review comment added. Return to the conversation to continue.';

  @override
  String get readerUiCommentCopied =>
      'Review comment copied. Paste it into a conversation.';

  @override
  String get readerUiSearchSymbols => 'Search symbols';

  @override
  String get readerUiSearchFiles => 'Search files';

  @override
  String get readerUiClearSymbolSearch => 'Clear symbol search';

  @override
  String get readerUiClearFileSearch => 'Clear file search';

  @override
  String get readerUiSelectFile => 'Select a file to preview';

  @override
  String get readerUiEmptyFolder => 'Folder is empty';

  @override
  String get readerUiNoFiles => 'No files found';

  @override
  String get readerUiPullRefresh => 'Pull down to refresh this folder.';

  @override
  String get readerUiTryFileName => 'Try a different file name.';

  @override
  String get readerUiOpenFolder => 'Open folder';

  @override
  String get readerUiOpen => 'Open';

  @override
  String get readerUiExpand => 'Expand';

  @override
  String get readerUiAttachPrompt => 'Attach to prompt';

  @override
  String get readerUiAddReference => 'Add as reference';

  @override
  String get readerUiOpenReview => 'Open in Review';

  @override
  String get readerUiCopyPath => 'Copy path';

  @override
  String get readerUiWorkspaceSymbols => 'Search project symbols';

  @override
  String get readerUiSymbolsHint =>
      'Find classes, functions, methods, and variables by name.';

  @override
  String get readerUiNoSymbols => 'No symbols found';

  @override
  String get readerUiSymbolsUnavailable =>
      'Try a different name. Some language services do not support project-wide symbol search.';

  @override
  String get readerUiReviewAll => 'Review all changes';

  @override
  String get readerUiCopied => 'Copied';

  @override
  String get readerUiFiles => 'Files';

  @override
  String get readerUiSymbols => 'Symbols';

  @override
  String get readerUiChanges => 'Changes';

  @override
  String get readerUiRefreshChanges => 'Refresh changes';

  @override
  String get readerUiCopiedReview => 'Copied from review';

  @override
  String get readerUiEntireChange => 'Entire file change';

  @override
  String get readerUiSelectedChange => 'Selected change';

  @override
  String get readerUiWorkingTree => 'Working tree';

  @override
  String get readerUiSessionScopeHint =>
      'Changes attributed to this OpenCode conversation';

  @override
  String get readerUiWorkingScopeHint => 'Current uncommitted Git changes';

  @override
  String get readerUiBranchScopeHint => 'Changes against the default branch';

  @override
  String get readerUiUnified => 'Unified';

  @override
  String get readerUiSplit => 'Split';

  @override
  String get readerUiPreviousHunk => 'Previous hunk';

  @override
  String get readerUiNextHunk => 'Next hunk';

  @override
  String get readerUiAsk => 'Ask';

  @override
  String get readerUiAddFile => 'Add file';

  @override
  String get readerUiAddFilePrompt => 'Add file to prompt';

  @override
  String get readerUiAskFile => 'Ask about file';

  @override
  String get readerUiFileActions => 'File review actions';

  @override
  String get readerUiStartFile => 'Start of file';

  @override
  String get readerUiNoGap => 'No gap';

  @override
  String get readerUiClearSelection => 'Clear selection';

  @override
  String get readerUiCopySelection => 'Copy selection';

  @override
  String get readerUiAddHunk => 'Add hunk to prompt';

  @override
  String get readerUiAddSelection => 'Add selection to prompt';

  @override
  String get readerUiComment => 'Comment';

  @override
  String get readerUiCommentChange => 'Comment on change';

  @override
  String get readerUiCommentHint => 'What should OpenCode inspect or change?';

  @override
  String get readerUiAddPrompt => 'Add to prompt';

  @override
  String get readerUiNoChanges => 'No changes to review';

  @override
  String get readerUiNoChangesHint =>
      'OpenCode has not changed any files in this conversation.';

  @override
  String get readerUiDiffUnavailable => 'Diff content unavailable';

  @override
  String get readerUiDiffUnavailableHint =>
      'The server reported this file but did not include a patch or file contents.';

  @override
  String get readerUiCopyContents => 'Copy file contents';

  @override
  String get readerUiSaveDevice => 'Save to device';

  @override
  String get readerUiClosePreview => 'Close preview';

  @override
  String get readerUiPreviewUnavailable => 'Preview unavailable';

  @override
  String get readerUiImageFailed => 'Image could not be displayed';

  @override
  String get readerUiImageUnsupported =>
      'The file data is not a supported image.';

  @override
  String get readerUiRendered => 'Rendered';

  @override
  String get readerUiRaw => 'Raw';

  @override
  String get readerUiSaveFailed =>
      'Could not save reader preferences. Try again.';

  @override
  String get readerUiFileOrder => 'File order';

  @override
  String get readerUiSourceFirst => 'Source first';

  @override
  String get readerUiServerOrder => 'Default order';

  @override
  String get readerUiOrderHint => 'Reorders entries; no files are hidden.';

  @override
  String readerUiLine(int number) {
    return 'line $number';
  }

  @override
  String readerUiReferenceAdded(String label) {
    return 'Added $label to the prompt';
  }

  @override
  String readerUiReferenceDuplicate(String label) {
    return '$label is already on the prompt';
  }

  @override
  String readerUiReferenceFull(int count) {
    return 'The prompt already holds $count references';
  }

  @override
  String readerUiAttached(String name) {
    return '$name attached.';
  }

  @override
  String readerUiCopiedPath(String path) {
    return 'Copied $path';
  }

  @override
  String readerUiChangedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changed files',
      one: '$count changed file',
    );
    return '$_temp0';
  }

  @override
  String readerUiChangeSummary(int count, int added, int removed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0 · +$added −$removed';
  }

  @override
  String readerUiAddPath(String path) {
    return 'Add $path to the prompt';
  }

  @override
  String readerUiAttachedReturn(String name) {
    return '$name attached. Return to the conversation to add your comment.';
  }

  @override
  String readerUiSaveNamed(String name) {
    return 'Save $name';
  }

  @override
  String readerUiSavedDevice(String name) {
    return '$name saved to your device.';
  }

  @override
  String readerUiPathLine(String path, int line) {
    return '$path · Line $line';
  }

  @override
  String readerUiOnPrompt(int count) {
    return '$count on prompt';
  }

  @override
  String readerUiOldNew(String oldLabel, String newLabel) {
    return 'old $oldLabel · new $newLabel';
  }

  @override
  String readerUiNewLines(String label) {
    return 'new $label';
  }

  @override
  String readerUiOldLines(String label) {
    return 'old $label';
  }

  @override
  String readerUiSelectedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected lines',
      one: '$count selected line',
    );
    return '$_temp0';
  }

  @override
  String readerUiLineRange(int first, int last) {
    return 'lines $first–$last';
  }

  @override
  String readerUiReviewPrompt(String path) {
    return 'Review `$path`';
  }

  @override
  String readerUiViewedCount(int viewed, int files) {
    return '$viewed of $files viewed';
  }

  @override
  String readerUiHunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hunks',
      one: '$count hunk',
    );
    return '$_temp0';
  }

  @override
  String readerUiReviewing(String path) {
    return 'Reviewing $path';
  }

  @override
  String readerUiHiddenLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count lines',
      one: '+$count line',
    );
    return '$_temp0';
  }

  @override
  String readerUiHiddenDescription(int count, String text) {
    return '$count unchanged lines hidden. $text';
  }

  @override
  String readerUiExpandDescription(int count) {
    return 'Expand. $count unchanged lines hidden below';
  }

  @override
  String readerUiMoreCount(int count) {
    return '$count more';
  }

  @override
  String readerUiHunkSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return 'Hunk selected · $_temp0';
  }

  @override
  String readerUiSaved(String name) {
    return '$name saved.';
  }

  @override
  String readerUiBytes(int count) {
    return '$count bytes';
  }

  @override
  String get readerUiSymbolFile => 'File';

  @override
  String get readerUiSymbolModule => 'Module';

  @override
  String get readerUiSymbolNamespace => 'Namespace';

  @override
  String get readerUiSymbolPackage => 'Package';

  @override
  String get readerUiSymbolClass => 'Class';

  @override
  String get readerUiSymbolMethod => 'Method';

  @override
  String get readerUiSymbolProperty => 'Property';

  @override
  String get readerUiSymbolField => 'Field';

  @override
  String get readerUiSymbolConstructor => 'Constructor';

  @override
  String get readerUiSymbolEnum => 'Enum';

  @override
  String get readerUiSymbolInterface => 'Interface';

  @override
  String get readerUiSymbolFunction => 'Function';

  @override
  String get readerUiSymbolVariable => 'Variable';

  @override
  String get readerUiSymbolConstant => 'Constant';

  @override
  String get readerUiSymbolEnummember => 'Enum member';

  @override
  String get readerUiSymbolStruct => 'Struct';

  @override
  String get readerUiSymbolEvent => 'Event';

  @override
  String get readerUiSymbolOperator => 'Operator';

  @override
  String get readerUiSymbolTypeparameter => 'Type parameter';

  @override
  String get readerUiSymbolSymbol => 'Symbol';

  @override
  String get readerUiAdded => 'Added';

  @override
  String get readerUiDeleted => 'Deleted';

  @override
  String get readerUiModified => 'Modified';

  @override
  String get readerUiChanged => 'Changed';

  @override
  String get readerUiSession => 'Conversation';

  @override
  String get readerUiBranch => 'Branch';

  @override
  String get readerUiRemoved => 'Removed';

  @override
  String get readerUiUnchanged => 'Unchanged';

  @override
  String get readerUiHunk => 'Hunk';

  @override
  String get readerUiMetadata => 'Metadata';

  @override
  String readerUiFileDescription(
    String path,
    String status,
    int added,
    int removed,
  ) {
    return '$path, $status, $added additions, $removed deletions';
  }

  @override
  String get readerUiUnknownType => 'Unknown file type';

  @override
  String get readerUiFormatUnsupported =>
      'This format cannot be rendered in the app yet.';

  @override
  String get readerUiAttachmentMissing =>
      'The attachment content is not included in this message.';

  @override
  String get readerUiRemoteAttachment =>
      'Remote attachment previews are not available.';

  @override
  String get readerUiAttachmentInvalid =>
      'The attachment data could not be decoded.';

  @override
  String get readerUiPinchZoom => 'Pinch to zoom';

  @override
  String get readerUiStatusAdded => 'added';

  @override
  String get readerUiStatusDeleted => 'deleted';

  @override
  String get readerUiStatusModified => 'modified';

  @override
  String readerUiSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines selected',
      one: '$count line selected',
    );
    return '$_temp0';
  }

  @override
  String get e7WorkspaceDisconnected => 'The server is not connected.';

  @override
  String get e7WorkspaceNoFolder => 'No project folder chosen';

  @override
  String get e7WorkspaceLoadingProjects => 'Loading projects';

  @override
  String get e7WorkspaceNoProjects => 'No projects opened';

  @override
  String get e7WorkspaceServerNoProjects => 'The server returned no projects.';

  @override
  String get e7WorkspaceChooseProject => 'Choose a project';

  @override
  String get e7WorkspaceNeedsYou => 'Needs you';

  @override
  String get e7WorkspaceRecentSessions => 'Recent conversations';

  @override
  String get e7WorkspaceNoRecent => 'No recent conversations';

  @override
  String get e7WorkspaceChooseFolderToStart =>
      'Choose a project folder to start a conversation.';

  @override
  String get e7WorkspaceStartInWorkspace =>
      'Start a conversation in the selected project.';

  @override
  String get e7WorkspaceArchivedSessions => 'Archived conversations';

  @override
  String get e7WorkspaceNoProjectSelected => 'No project selected';

  @override
  String get e7WorkspaceSwitchProject => 'Switch project';

  @override
  String get e7WorkspaceWorkspace => 'Workspace';

  @override
  String get e7WorkspaceThisComputer => 'This computer';

  @override
  String get e7WorkspaceNoShareLink => 'No share link was returned.';

  @override
  String get e7WorkspaceShareCopied => 'Share link copied';

  @override
  String get e7WorkspaceUnshared => 'Conversation is no longer shared';

  @override
  String get e7WorkspaceReconnectingShortly =>
      'OpenCode is reconnecting. Try again shortly.';

  @override
  String get e7WorkspaceRenameSession => 'Rename conversation';

  @override
  String get e7WorkspaceTitle => 'Title';

  @override
  String get e7WorkspaceArchiveConfirm => 'Archive conversation?';

  @override
  String get e7WorkspaceShareConfirm => 'Share this conversation?';

  @override
  String get e7WorkspaceDeleteConfirm => 'Delete conversation?';

  @override
  String get e7WorkspaceArchive => 'Archive';

  @override
  String get e7WorkspaceShareSession => 'Share conversation';

  @override
  String get e7WorkspaceArchivedActions => 'Archived conversation actions';

  @override
  String get e7WorkspaceRename => 'Rename';

  @override
  String get e7WorkspaceCompacting => 'Compacting…';

  @override
  String get e7WorkspaceShare => 'Share';

  @override
  String get e7WorkspaceStopSharing => 'Stop sharing';

  @override
  String get e7WorkspaceDisconnect => 'Disconnect';

  @override
  String get e7WorkspaceBackExit => 'Press back again to exit';

  @override
  String get e7WorkspaceConnected => 'Connected';

  @override
  String get e7WorkspaceConnecting => 'Connecting';

  @override
  String get e7WorkspaceOffline => 'Offline';

  @override
  String get e7WorkspaceReconnectingAgain =>
      'OpenCode is reconnecting. Try again.';

  @override
  String get e7WorkspaceRefreshFailed => 'Could not refresh';

  @override
  String get e7WorkspaceServerRequests => 'Server requests';

  @override
  String get e7WorkspacePermissionRequired => 'Permission required';

  @override
  String get e7WorkspaceAssistantQuestion => 'Assistant question';

  @override
  String get e7WorkspaceInputRequested => 'Input requested';

  @override
  String get e7WorkspaceMcpAsked => 'Asked by an MCP server';

  @override
  String get e7WorkspaceDismissRequest => 'Dismiss this request?';

  @override
  String get e7WorkspaceDismissDetail =>
      'OpenCode will continue without answers to these questions.';

  @override
  String get e7WorkspaceNeedsInput => 'OpenCode needs input';

  @override
  String get e7WorkspaceSendAnswers => 'Send answers';

  @override
  String get e7WorkspaceReferenceRetry =>
      'Conversation reference unavailable. Refresh and try again.';

  @override
  String get e7WorkspaceLocationRetry =>
      'The conversation’s project is unavailable. Refresh and try again.';

  @override
  String get e7WorkspaceLocationChangedReturn =>
      'The conversation’s project changed. Return and try again.';

  @override
  String get e7WorkspaceLocationChangedRetry =>
      'The conversation’s project changed. Refresh and try again.';

  @override
  String get e7WorkspaceReferenceUnavailable =>
      'Conversation reference unavailable.';

  @override
  String get e7WorkspacePaginationStuck =>
      'Conversation pagination could not advance. Refresh the list to continue.';

  @override
  String get e7WorkspaceContinueHereConfirm =>
      'Continue this conversation here?';

  @override
  String e7WorkspaceCreateFailed(String error) {
    return 'Could not create a conversation: $error';
  }

  @override
  String get e7WorkspaceNoProjectsSearch =>
      'The server returned no projects. Search all conversations to find previous work.';

  @override
  String e7WorkspaceActiveDirectory(String directory) {
    return 'Active conversation’s project · $directory';
  }

  @override
  String e7WorkspaceArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived conversations',
      one: '1 archived conversation',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceOpenProjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open on this server',
      one: '1 open on this server',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceArchivedToast(String title) {
    return 'Archived “$title”';
  }

  @override
  String e7WorkspaceArchiveDetail(String title) {
    return '“$title” will be hidden from recent conversations.';
  }

  @override
  String e7WorkspaceDeleteDetail(String title) {
    return '“$title” and its history will be permanently removed.';
  }

  @override
  String e7WorkspaceShareDetail(String title) {
    return 'Anyone with the link can view “$title”, including its conversation and shared context. Do not share secrets, credentials, or private files.';
  }

  @override
  String e7WorkspaceSharedUrl(String url) {
    return 'Shared: $url';
  }

  @override
  String e7WorkspaceAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need attention',
      one: '1 item needs attention',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceServerName(String name) {
    return 'Server: $name';
  }

  @override
  String e7WorkspaceServerStatus(String status) {
    return 'Server $status';
  }

  @override
  String e7WorkspaceRequestFor(String title) {
    return 'for $title';
  }

  @override
  String e7WorkspaceQuestionCount(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions · $title',
      one: '1 question · $title',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceSubagentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subagents',
      one: '1 subagent',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceSessionId(String id) {
    return 'Conversation $id';
  }

  @override
  String e7WorkspaceContinueHereDetail(String title) {
    return '“$title” will belong to your current project through the server’s sync system. It stops belonging to the project it runs in now.';
  }

  @override
  String e7WorkspaceMovedHere(String title) {
    return '“$title” now belongs to this project';
  }

  @override
  String e7WorkspaceOpenSessionSemantics(String title, String detail) {
    return 'Open $title. $detail';
  }

  @override
  String get e7WorkspaceLoadingSessions => 'Loading conversations…';

  @override
  String get e7WorkspaceLoadedRecentEmpty =>
      'Older conversations may still be available below.';

  @override
  String get e7WorkspaceSearchServer =>
      'Search conversation titles across every project on this server';

  @override
  String get e7WorkspaceUnknownProject => 'Unknown project';

  @override
  String get e7WorkspaceJustNow => 'Just now';

  @override
  String e7WorkspaceMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String e7WorkspaceHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String e7WorkspaceDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String e7WorkspaceFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get e7WorkspaceBackgroundOn => 'Stays connected in the background';

  @override
  String get e7WorkspaceBackgroundOff => 'Background updates off';

  @override
  String e7WorkspaceFilteredLoaded(int count, int total) {
    return '$count shown from $total loaded conversations';
  }

  @override
  String e7WorkspaceLoadedSummary(int count, int folders) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loaded conversations',
      one: '1 loaded conversation',
    );
    String _temp1 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders projects',
      one: '1 project',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get e7WorkspaceLoadedFolders => 'Loaded projects';

  @override
  String get chatUiUnderAMessageForActions => ' under a message for actions';

  @override
  String get chatUiAllMatchingRequests => '(all matching requests)';

  @override
  String get chatUiNoOutput => '(no output)';

  @override
  String get chatUiNoResult => '(no result)';

  @override
  String get chatUiTapToExpand => '(tap to expand)';

  @override
  String get chatUi1ReferenceIsAddedAsTextWhen =>
      '1 reference is added as text when you send. Not saved with your draft.';

  @override
  String get chatUiActions => 'Actions';

  @override
  String get chatUiAddAnOpenCodeProjectReferenceToThis =>
      'Add an OpenCode project reference to this prompt';

  @override
  String get chatUiAddAnImageOrFileToThe =>
      'Add an image or file to the prompt';

  @override
  String get chatUiAddHoldToAttachAFile => 'Add. Hold to attach a file';

  @override
  String get chatUiAgent => 'Agent';

  @override
  String get chatUiAllowOnce => 'Allow once';

  @override
  String get chatUiAlreadyAnsweredElsewhere => 'Already answered elsewhere';

  @override
  String get chatUiAlreadyDelivered => 'Already delivered';

  @override
  String get chatUiAlwaysAllow => 'Always allow';

  @override
  String get chatUiAlwaysAllowPatterns => 'Always allow patterns:';

  @override
  String get chatUiAlwaysAllowWouldAlsoCover => 'Always allow would also cover';

  @override
  String get chatUiAnswerWasCutOffByTheLength =>
      'Answer was cut off by the length limit';

  @override
  String get chatUiAnyoneWithTheLinkCanViewThis =>
      'Anyone with the link can view this conversation and its shared context. Do not share conversations containing secrets, credentials, or private files.';

  @override
  String get chatUiAppDiagnostics => 'App diagnostics';

  @override
  String get chatUiAppearance => 'Appearance';

  @override
  String get chatUiApplyPatch => 'Apply patch';

  @override
  String get chatUiAskOpenCode => 'Ask OpenCode…';

  @override
  String get chatUiAssistantIsWorking => 'Assistant is working';

  @override
  String get chatUiAttachFile => 'Attach file';

  @override
  String get chatUiAttachToPrompt => 'Attach to prompt';

  @override
  String get chatUiAttachment => 'Attachment';

  @override
  String get chatUiAttachmentLimitReached => 'Attachment limit reached';

  @override
  String get chatUiAttachmentsMustTotalNoMoreThan20 =>
      'Attachments must total no more than 20 MB.';

  @override
  String get chatUiAvailableWhenTheCurrentRunFinishes =>
      'Available when the current run finishes';

  @override
  String get chatUiBrowseProjectAndGlobalSkills =>
      'Browse project and global skills';

  @override
  String get chatUiBrowsePreviewDownloadAndAttachProjectFiles =>
      'Browse, preview, download, and attach project files';

  @override
  String get chatUiCancelAndReturnToTheComposer =>
      'Cancel and return to the composer';

  @override
  String get chatUiCancelMessage => 'Cancel message';

  @override
  String get chatUiCancelThisPendingMessage => 'Cancel this pending message?';

  @override
  String get chatUiChangeTheActiveOpenCodeConsoleOrganization =>
      'Change the active OpenCode Console organization';

  @override
  String get chatUiChangeTheTitleShownInTheSession =>
      'Change the title shown in the conversation list';

  @override
  String get chatUiChangeThisSessionSExperimentalWorkspace =>
      'Change this conversation’s experimental cloud environment';

  @override
  String get chatUiChangedFile => 'Changed file';

  @override
  String get chatUiChanges => 'Changes';

  @override
  String get chatUiChooseAPromptAndContinueItIn =>
      'Choose a prompt and continue it in a new conversation';

  @override
  String get chatUiChooseAPromptToRestoreItIn =>
      'Choose a prompt to restore it in a new conversation.';

  @override
  String get chatUiChooseAServerModelByProviderAnd =>
      'Choose a server model by provider and capability';

  @override
  String get chatUiChooseAnotherModelInThePickerTo =>
      'Choose another model in the picker to build your recent list.';

  @override
  String get chatUiChooseModel => 'Choose model';

  @override
  String get chatUiChooseTheActiveOpenCodeAgent =>
      'Choose the active OpenCode agent';

  @override
  String get chatUiChooseTheCurrentModelVariantOrReasoning =>
      'Choose the current model variant or reasoning effort';

  @override
  String get chatUiCloseComposerTools => 'Close composer tools';

  @override
  String get chatUiClosePromptEditor => 'Close prompt editor';

  @override
  String get chatUiCloseTimeline => 'Close timeline';

  @override
  String get chatUiCollapseReasoning => 'Collapse reasoning';

  @override
  String get chatUiCollapseReasoningDetails => 'Collapse reasoning details';

  @override
  String get chatUiCollapsedUntilYouTapIt => 'Collapsed until you tap it';

  @override
  String get chatUiCommandMap => 'Command map';

  @override
  String get chatUiCompactContext => 'Compact context';

  @override
  String get chatUiCompactSession => 'Compact conversation';

  @override
  String get chatUiCompactingConversation => 'Compacting conversation…';

  @override
  String get chatUiCompactionFailed => 'Compaction failed';

  @override
  String get chatUiCompactionStarted => 'Compaction started';

  @override
  String get chatUiCompose => 'Compose';

  @override
  String get chatUiComposerTools => 'Composer tools';

  @override
  String get chatUiConfirmAlwaysAllow => 'Confirm always allow';

  @override
  String get chatUiConfirmBroaderAccess => 'Confirm broader access';

  @override
  String get chatUiConnectProvider => 'Connect provider';

  @override
  String get chatUiConnectionHealthServerVersionAndLiveMode =>
      'Connection health, server version, and live mode';

  @override
  String get chatUiConsequenceFutureMatchingActionsCanRunWithout =>
      'Consequence: future matching actions can run without asking again for the lifetime of this OpenCode server. Allow once is safer.';

  @override
  String get chatUiContextAdded => 'Context added';

  @override
  String get chatUiContextCompacted => 'Context compacted';

  @override
  String get chatUiContextUpdatePending => 'Context update pending';

  @override
  String get chatUiContextUsage => 'Context usage';

  @override
  String get chatUiCopiedPasteItIntoTheComposer =>
      'Copied. Paste it into the composer';

  @override
  String get chatUiCopyMessageText => 'Copy message text';

  @override
  String get chatUiCopyShareLink => 'Copy share link';

  @override
  String get chatUiCopyTheRenderedConversationAsMarkdown =>
      'Copy the rendered conversation as Markdown';

  @override
  String get chatUiCopyTranscript => 'Copy transcript';

  @override
  String get chatUiCreateOrCopyAPublicSessionLink =>
      'Create or copy a public conversation link';

  @override
  String get chatUiCurrentSession => 'Current conversation';

  @override
  String get chatUiDelegate => 'Delegate';

  @override
  String get chatUiDelegateThisPrompt => 'Delegate this prompt';

  @override
  String get chatUiDelegateThisPromptToAServerSubagent =>
      'Delegate this prompt to a server subagent';

  @override
  String get chatUiDelegatedSession => 'Delegated conversation';

  @override
  String get chatUiDeleteMessage => 'Delete message';

  @override
  String get chatUiDeleteThisMessage => 'Delete this message?';

  @override
  String get chatUiDescribeAChangeAskAboutThisProject =>
      'Describe a change, ask about this project, or paste an error.';

  @override
  String get chatUiDetails => 'Details';

  @override
  String get chatUiDirectory => 'Directory';

  @override
  String get chatUiDisableTheCurrentPublicSessionLink =>
      'Disable the current public conversation link';

  @override
  String get chatUiDiscard => 'Discard';

  @override
  String get chatUiDiscardDraft => 'Discard draft';

  @override
  String get chatUiDiscardPromptChanges => 'Discard prompt changes?';

  @override
  String get chatUiDiscardQueuedDraft => 'Discard queued draft?';

  @override
  String get chatUiDismissPromptError => 'Dismiss prompt error';

  @override
  String get chatUiEachAttachmentMustBe10MBOr =>
      'Each attachment must be 10 MB or smaller.';

  @override
  String get chatUiEdit => 'Edit';

  @override
  String get chatUiEditDraft => 'Edit draft';

  @override
  String get chatUiEditTheCurrentPromptInAFocused =>
      'Edit the current prompt in a focused full-screen view';

  @override
  String get chatUiEmptySessionWasKeptBecauseOpenCodeCould =>
      'Empty conversation was kept because OpenCode could not verify or remove it.';

  @override
  String get chatUiErrorDetails => 'Error details';

  @override
  String get chatUiExpandReasoning => 'Expand reasoning';

  @override
  String get chatUiExpandReasoningDetails => 'Expand reasoning details';

  @override
  String get chatUiExpandedUnderEachAnswer => 'Expanded under each answer';

  @override
  String get chatUiExplainThisProject => 'Explain this project';

  @override
  String get chatUiExplored => 'Explored';

  @override
  String get chatUiExploring => 'Exploring';

  @override
  String get chatUiExportSessionTranscript => 'Export conversation transcript';

  @override
  String get chatUiExportTranscript => 'Export transcript';

  @override
  String get chatUiFILE => 'FILE';

  @override
  String get chatUiFetchPage => 'Fetch page';

  @override
  String get chatUiFiles => 'Files';

  @override
  String get chatUiFilesAreUnavailableInThisPreview =>
      'Files are unavailable in this preview.';

  @override
  String get chatUiFindACommandOrAction => 'Find a command or action';

  @override
  String get chatUiFindAMessageJumpToItOr =>
      'Find a message, jump to it, or fork from a prompt';

  @override
  String get chatUiFindASubagent => 'Find a subagent';

  @override
  String get chatUiFindAndFixABug => 'Find and fix a bug';

  @override
  String get chatUiFindFiles => 'Find files';

  @override
  String get chatUiFindSessionsAcrossEveryOpenCodeProject =>
      'Find conversations across every OpenCode project';

  @override
  String get chatUiFollowAndroidOrChooseTheNativeLight =>
      'Follow Android or choose the native light or dark theme';

  @override
  String get chatUiForkFromPrompt => 'Fork from prompt';

  @override
  String get chatUiForkFromThisPrompt => 'Fork from this prompt';

  @override
  String get chatUiForkSession => 'Fork conversation';

  @override
  String get chatUiFromToolCall => 'From tool call';

  @override
  String get chatUiGeneratedFile => 'Generated file';

  @override
  String get chatUiHiddenToKeepTheTranscriptQuiet =>
      'Hidden to keep the transcript quiet';

  @override
  String get chatUiHideTimestamps => 'Hide timestamps';

  @override
  String get chatUiImageDataIsUnavailable => 'Image data is unavailable.';

  @override
  String get chatUiInputRequested => 'Input requested';

  @override
  String get chatUiInspectGitLanguageServicesAndFormattersFor =>
      'Inspect Git, language services, and formatters for this project';

  @override
  String get chatUiInspectMCPStatusAuthenticationAndResources =>
      'Inspect MCP status, authentication, and resources';

  @override
  String get chatUiInspectCurrentTokensCacheCostAndContext =>
      'Inspect current tokens, cache, cost, and context usage';

  @override
  String get chatUiInspectToolsCallableByTheActiveProvider =>
      'Inspect tools callable by the active provider and model';

  @override
  String get chatUiItsTextReturnsToTheComposerAs =>
      'Its text returns to the composer as a draft.';

  @override
  String get chatUiJumpAnywhereInThisConversation =>
      'Jump anywhere in this conversation.';

  @override
  String get chatUiJumpAnywhereForkRestoresAPromptFor =>
      'Jump anywhere. Fork restores a prompt for editing.';

  @override
  String get chatUiJumpToLatest => 'Jump to latest';

  @override
  String get chatUiKeepAsking => 'Keep asking';

  @override
  String get chatUiKeepItPending => 'Keep it pending';

  @override
  String get chatUiKeepItQueued => 'Keep it queued';

  @override
  String get chatUiLanguageServer => 'Language server';

  @override
  String get chatUiList => 'List';

  @override
  String get chatUiListWhatSInThisDirectory => 'List what\'s in this directory';

  @override
  String get chatUiLoadingSubagents => 'Loading subagents…';

  @override
  String get chatUiLongReasoningCollapsedInTheTranscript =>
      'Long reasoning collapsed in the transcript';

  @override
  String get chatUiMCPServers => 'MCP servers';

  @override
  String get chatUiManageProviderAndIntegrationAuthentication =>
      'Manage provider and integration authentication';

  @override
  String get chatUiManageSavedGrantsInSettingsSavedPermissions =>
      'Manage saved grants in Settings → Saved permissions.';

  @override
  String get chatUiMessage => 'Message';

  @override
  String get chatUiMessageActions => 'Message actions';

  @override
  String get chatUiMessageDeleted => 'Message deleted';

  @override
  String get chatUiMessageTextCopied => 'Message text copied';

  @override
  String get chatUiMessageTimeline => 'Message timeline';

  @override
  String get chatUiMessageTimestampsHidden => 'Message timestamps hidden';

  @override
  String get chatUiMessageTimestampsShown => 'Message timestamps shown';

  @override
  String get chatUiMessagesAndFileChangesAfterTheMost =>
      'Messages and file changes after the most recent prompt will be rolled back.';

  @override
  String get chatUiMobileActionsAndCommandsFromThisServer =>
      'Mobile actions and commands from this server';

  @override
  String get chatUiModel => 'Model';

  @override
  String get chatUiModelAndAgent => 'Model and agent';

  @override
  String get chatUiMore => 'More';

  @override
  String get chatUiMoveSession => 'Move conversation';

  @override
  String get chatUiMoveThisSessionToAnotherProjectDirectory =>
      'Move this conversation to another project';

  @override
  String get chatUiMoved => 'Moved';

  @override
  String get chatUiNavigate => 'Navigate';

  @override
  String get chatUiNoAnswer => 'No answer';

  @override
  String get chatUiNoMatchingCommands => 'No matching commands';

  @override
  String get chatUiNoMatchingMessages => 'No matching messages';

  @override
  String get chatUiNoShareLinkWasReturned => 'No share link was returned';

  @override
  String get chatUiNoSubagentsAvailableFromThisServer =>
      'No subagents available from this server';

  @override
  String get chatUiNoTodosInThisSession => 'No todos in this conversation';

  @override
  String get chatUiNotConnectedToTheServerRightNow =>
      'Not connected to the server right now.';

  @override
  String get chatUiNotRun => 'Not run';

  @override
  String get chatUiOpenFullScreenPromptEditor =>
      'Open full-screen prompt editor';

  @override
  String get chatUiOpenParentSession => 'Open parent conversation';

  @override
  String get chatUiOpenPersistentWorkspaceTerminals =>
      'Open persistent project terminals';

  @override
  String get chatUiOpenProviders => 'Open providers';

  @override
  String get chatUiOpenSubagentSession => 'Open subagent conversation';

  @override
  String get chatUiOpenCodeCommandsAreUnavailableOffline =>
      'OpenCode commands are unavailable offline.';

  @override
  String get chatUiOpenCodeCouldNotCompleteThisPrompt =>
      'OpenCode could not complete this prompt.';

  @override
  String get chatUiOpenCodeIsReconnecting => 'OpenCode is reconnecting.';

  @override
  String get chatUiOpenCodeIsReconnectingTryAgainShortly =>
      'OpenCode is reconnecting. Try again shortly.';

  @override
  String get chatUiOpenCodeIsReconnectingTryAgainWhenThe =>
      'OpenCode is reconnecting. Try again when the server is online.';

  @override
  String get chatUiOpenCodeIsReconnectingTryAgain =>
      'OpenCode is reconnecting. Try again.';

  @override
  String get chatUiOpenCodeNeedsInput => 'OpenCode needs input';

  @override
  String get chatUiOpenCodeServerCommand => 'OpenCode server command';

  @override
  String get chatUiOutputPruned => 'Output pruned';

  @override
  String get chatUiPendingChange => 'Pending change';

  @override
  String get chatUiPreviewAttachment => 'Preview attachment';

  @override
  String get chatUiProjectFiles => 'Project files';

  @override
  String get chatUiProjectHealth => 'Project health';

  @override
  String get chatUiProjectReference => 'Project reference';

  @override
  String get chatUiProjectReferences => 'Project references';

  @override
  String get chatUiProjectsAndWorkspaces => 'Projects and worktrees';

  @override
  String get chatUiPromptEditor => 'Prompt editor';

  @override
  String get chatUiPromptFromParentAgent => 'Prompt from parent agent';

  @override
  String get chatUiPromptTools => 'Prompt tools';

  @override
  String get chatUiQuestion => 'Question';

  @override
  String get chatUiQuestions => 'Questions';

  @override
  String get chatUiQueue => 'Queue';

  @override
  String get chatUiQueueAfterThisRun => 'Queue after this run';

  @override
  String get chatUiQueuedRunsAfterThisTurn => 'Queued · runs after this turn';

  @override
  String get chatUiQueuedWillSendWhenReconnected =>
      'Queued — will send when reconnected';

  @override
  String get chatUiRead => 'Read';

  @override
  String get chatUiReasoningExpandedInTheTranscript =>
      'Reasoning expanded in the transcript';

  @override
  String get chatUiRecordsAndTranscribesOnThisDevice =>
      'Records and transcribes on this device';

  @override
  String get chatUiReferenceKeptForYourNextPromptCommands =>
      'Reference kept for your next prompt — commands do not carry it.';

  @override
  String get chatUiReferencesKeptForYourNextPromptCommands =>
      'References kept for your next prompt — commands do not carry them.';

  @override
  String get chatUiReject => 'Reject';

  @override
  String get chatUiReject1 => 'Reject…';

  @override
  String get chatUiReloadMessages => 'Refresh messages';

  @override
  String get chatUiRemovesItFromTheConversationPermanently =>
      'Removes it from the conversation permanently';

  @override
  String get chatUiRename => 'Rename';

  @override
  String get chatUiRenameSession => 'Rename conversation';

  @override
  String get chatUiRestoreMessages => 'Restore messages';

  @override
  String get chatUiRestoreRevertedPrompt => 'Restore reverted prompt';

  @override
  String get chatUiRestoreTheCurrentlyRevertedSessionState =>
      'Restore the currently reverted conversation state';

  @override
  String get chatUiResult => 'Result';

  @override
  String get chatUiRetryImagePreview => 'Try again';

  @override
  String get chatUiRetryLastPrompt => 'Retry last prompt';

  @override
  String get chatUiRetryServerCommands => 'Try again';

  @override
  String get chatUiRevert => 'Revert';

  @override
  String get chatUiRevertFromThisPrompt => 'Revert from this prompt?';

  @override
  String get chatUiRevertLastPrompt => 'Revert last prompt';

  @override
  String get chatUiReviewCommentAddedToThePrompt =>
      'Review comment added to the prompt';

  @override
  String get chatUiReviewHandledAppErrorsAndSendA =>
      'Review handled app errors and send a redacted report';

  @override
  String get chatUiReviewTheActualDiffForThisSession =>
      'Review the actual diff for this conversation';

  @override
  String get chatUiRollBackMessagesAndFileChangesAfter =>
      'Roll back messages and file changes after the prompt';

  @override
  String get chatUiRunOnYourComputer => 'Run on your computer';

  @override
  String get chatUiRunShellCommand => 'Run shell command';

  @override
  String get chatUiRunningTools => 'Running tools';

  @override
  String get chatUiSaveTheConversationAsAMarkdownFile =>
      'Save the conversation as a Markdown file';

  @override
  String get chatUiScope => 'Scope';

  @override
  String get chatUiSearchMessages => 'Search messages';

  @override
  String get chatUiSearchMobileActionsAndServerProvidedCommands =>
      'Search mobile actions and server-provided commands';

  @override
  String get chatUiSearchText => 'Search text';

  @override
  String get chatUiSeeFullDiff => 'See full diff';

  @override
  String get chatUiSelectAModelBeforeCompactingThisSession =>
      'Select a model before compacting this conversation.';

  @override
  String get chatUiSend => 'Send';

  @override
  String get chatUiSendAfterThisRun => 'Send after this run';

  @override
  String get chatUiSendNowAndSteerInstead => 'Send now and steer instead';

  @override
  String get chatUiSendNowAndSteerTheCurrentRun =>
      'Send now and steer the current run';

  @override
  String get chatUiSendNowAndSteerThisRun => 'Send now and steer this run';

  @override
  String get chatUiSendRejection => 'Send rejection';

  @override
  String get chatUiSendSteersTheCurrentRun => 'Send steers the current run';

  @override
  String get chatUiSendWaitsForThisRunToFinish =>
      'Send waits for this run to finish';

  @override
  String get chatUiSendsAfterThisRunFinishes => 'Sends after this run finishes';

  @override
  String get chatUiServerCommands => 'Server commands';

  @override
  String get chatUiServerCommandsCouldNotBeRefreshed =>
      'Server commands could not be refreshed';

  @override
  String get chatUiServerMessage => 'Server message';

  @override
  String get chatUiServerStatus => 'Server status';

  @override
  String get chatUiSessionChanges => 'Conversation changes';

  @override
  String get chatUiSessionContext => 'Conversation context';

  @override
  String get chatUiSessionIsNoLongerShared =>
      'Conversation is no longer shared';

  @override
  String get chatUiSessionMenu => 'Conversation menu';

  @override
  String get chatUiSessionSharedCopyTheVisibleLinkManually =>
      'Conversation shared. Copy the visible link manually.';

  @override
  String get chatUiShareLinkCopied => 'Share link copied';

  @override
  String get chatUiShareSession => 'Share conversation';

  @override
  String get chatUiShareThisSession => 'Share this conversation?';

  @override
  String get chatUiSharedAnyoneWithTheLinkCanView =>
      'Shared: anyone with the link can view';

  @override
  String get chatUiShowAllCommands => 'Show all commands';

  @override
  String get chatUiShowAllSubagentSessions => 'Show all subagent conversations';

  @override
  String get chatUiShowAllSubagents => 'Show all subagents';

  @override
  String get chatUiShowFullPrompt => 'Show full prompt';

  @override
  String get chatUiShowLess => 'Show less';

  @override
  String get chatUiShowTimestamps => 'Show timestamps';

  @override
  String get chatUiSkill => 'Skill ·';

  @override
  String get chatUiSkills => 'Skills';

  @override
  String get chatUiSlashCommandsAndAgents => 'Slash commands and agents';

  @override
  String get chatUiStartACleanSessionInThisWorkspace =>
      'Start a clean conversation in this project';

  @override
  String get chatUiStartANewSessionWithThisPrompt =>
      'Start a new conversation with this prompt in the composer';

  @override
  String get chatUiStartCoding => 'Start coding';

  @override
  String get chatUiSteer => 'Steer';

  @override
  String get chatUiSteeringAtTheNextStep => 'Steering at the next step';

  @override
  String get chatUiStopSharing => 'Stop sharing';

  @override
  String get chatUiSubagent => 'Subagent';

  @override
  String get chatUiSubagentFailed => 'Subagent failed.';

  @override
  String get chatUiSubagentWorking => 'Subagent working…';

  @override
  String get chatUiSubagentsCouldNotBeLoaded => 'Subagents could not be loaded';

  @override
  String get chatUiSummarizeTheSessionUsingTheSelectedModel =>
      'Summarize the conversation using the selected model';

  @override
  String get chatUiSwitchOrganization => 'Switch organization';

  @override
  String get chatUiSwitchProjectDirectoryOrWorktree =>
      'Switch project, directory, or worktree';

  @override
  String get chatUiSystemUpdate => 'System update';

  @override
  String get chatUiTellTheAgentWhyOrWhatTo =>
      'Tell the agent why, or what to do instead (optional)';

  @override
  String get chatUiThatMessageIsNoLongerInThis =>
      'That message is no longer in this conversation.';

  @override
  String get chatUiTheFileHasNoContentToAttach =>
      'The file has no content to attach.';

  @override
  String get chatUiTheFileHasNoContentToSave =>
      'The file has no content to save.';

  @override
  String get chatUiTheFormOrProjectChangedReopenThe =>
      'The form or project changed. Reopen the current request.';

  @override
  String get chatUiTheGeneratedFileIsNotAvailableFrom =>
      'The generated file is not available from this server.';

  @override
  String get chatUiTheMessageAndAllOfItsParts =>
      'The message and all of its parts are permanently removed from the conversation, so future replies no longer see them. File changes it made are not reverted.';

  @override
  String get chatUiTheServerReturnedEmptyImageData =>
      'The server returned empty image data.';

  @override
  String get chatUiThisDraftHasNotBeenSentTo =>
      'This draft has not been sent to OpenCode.';

  @override
  String get chatUiThisDraftIsTooLargeToQueue =>
      'This draft is too large to queue, or the queue is full of newer drafts. Remove an attachment, or clear queued prompts in Settings.';

  @override
  String get chatUiThisPromptCannotBeRestoredBecauseAn =>
      'This prompt cannot be restored because an attachment is unavailable.';

  @override
  String get chatUiThisPromptCannotBeRetriedBecauseAn =>
      'This prompt cannot be retried because an attachment is unavailable.';

  @override
  String get chatUiTimeTokensAndCostUnderEachMessage =>
      'Time, tokens and cost under each message';

  @override
  String get chatUiTimeline => 'Timeline';

  @override
  String get chatUiTimestampsUsage => 'Timestamps & usage';

  @override
  String get chatUiTipTypeForCommandsTap => 'Tip: type / for commands · tap ';

  @override
  String get chatUiTitle => 'Title';

  @override
  String get chatUiTodoList => 'Todo list';

  @override
  String get chatUiTodos => 'Todos';

  @override
  String get chatUiToggleCreationTimesBesideTranscriptEntries =>
      'Toggle creation times beside transcript entries';

  @override
  String get chatUiToggleLongReasoningDetailsAcrossTheTranscript =>
      'Toggle long reasoning details across the transcript';

  @override
  String get chatUiToolFailed => 'Tool failed.';

  @override
  String get chatUiTools => 'Tools';

  @override
  String get chatUiToolsAndCapabilities => 'Tools and capabilities';

  @override
  String get chatUiTranscript => 'Transcript';

  @override
  String get chatUiTranscriptCopiedAsMarkdown =>
      'Transcript copied as Markdown';

  @override
  String get chatUiTranscriptDisplay => 'Transcript display';

  @override
  String get chatUiTranscriptSaved => 'Transcript saved';

  @override
  String get chatUiViews => 'Views';

  @override
  String get chatUiVoiceConversationWasInterrupted =>
      'Voice conversation was interrupted.';

  @override
  String get chatUiVoiceInput => 'Voice input';

  @override
  String get chatUiVoiceInputIsUnavailable => 'Voice input is unavailable.';

  @override
  String get chatUiWaitForTheCurrentRunToFinish =>
      'Wait for the current run to finish, then send';

  @override
  String get chatUiWaitForThisRunInstead => 'Wait for this run instead';

  @override
  String get chatUiWaitingForThisRunToFinish =>
      'Waiting for this run to finish';

  @override
  String get chatUiWebSearch => 'Web search';

  @override
  String get chatUiWhatChangedRecently => 'What changed recently?';

  @override
  String get chatUiWhenTheAssistantPlansWorkAsA =>
      'When the assistant plans work as a todo list, the items appear here.';

  @override
  String get chatUiWrite => 'Write';

  @override
  String get chatUiWriteYourOpenCodePrompt => 'Write your OpenCode prompt…';

  @override
  String get chatUiYou => 'You';

  @override
  String get chatUiYourOriginalComposerDraftAndAttachmentsWill =>
      'Your original composer draft and attachments will stay unchanged.';

  @override
  String get chatUiInThisChat => 'in this conversation';

  @override
  String get chatUiIncludesStepsNotRun => 'includes steps not run';

  @override
  String get chatUiNewFile => 'new file';

  @override
  String get chatUiOpencodeAssistant => 'opencode assistant';

  @override
  String get chatUiSearchedOnce => 'searched once';

  @override
  String get chatUiYouUser => 'you user';

  @override
  String chatUiQueuedWithEviction(Object detail) {
    return 'Queued — will send when reconnected. $detail';
  }

  @override
  String chatUiCommandUnavailable(Object command) {
    return '/$command is not available right now.';
  }

  @override
  String chatUiAttachmentCountLimit(Object count) {
    return 'You can attach up to $count files.';
  }

  @override
  String chatUiQueuedSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sent $count queued prompts',
      one: 'Sent 1 queued prompt',
    );
    return '$_temp0';
  }

  @override
  String chatUiOtherDraftsWaitingSuffix(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts waiting for other servers',
      one: '1 draft waiting for other servers',
    );
    return ' · $_temp0';
  }

  @override
  String chatUiNextTurnsModel(Object model) {
    return 'Next turns in this conversation use $model.';
  }

  @override
  String chatUiReferenceAlreadyAdded(Object name) {
    return '@$name is already in the prompt';
  }

  @override
  String chatUiFileAttached(Object filename) {
    return '$filename attached. Add your comment.';
  }

  @override
  String chatUiSaveFile(Object filename) {
    return 'Save $filename';
  }

  @override
  String chatUiFileSaved(Object filename) {
    return '$filename saved to your device.';
  }

  @override
  String chatUiDraftsQueued(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts queued to send on reconnect.',
      one: '1 draft queued to send on reconnect.',
    );
    return '$_temp0';
  }

  @override
  String chatUiOtherDraftsWaiting(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts waiting for other servers.',
      one: '1 draft waiting for other servers.',
    );
    return '$_temp0';
  }

  @override
  String chatUiQuestionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String chatUiPermissionNeeded(Object title) {
    return 'Permission needed: $title';
  }

  @override
  String chatUiQuestionLabel(Object title) {
    return 'Question: $title';
  }

  @override
  String chatUiQuestionsSummary(Object question, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$question · $_temp0';
  }

  @override
  String chatUiRateLimitRetry(Object attempt) {
    return 'Rate limited. Retrying$attempt…';
  }

  @override
  String chatUiRateLimitCountdown(Object attempt, Object time) {
    return 'Rate limited. Retrying$attempt in $time';
  }

  @override
  String chatUiReferencesAttachedNotice(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count references are added as text when you send. Not saved with your draft.',
      one:
          '1 reference is added as text when you send. Not saved with your draft.',
    );
    return '$_temp0';
  }

  @override
  String chatUiAttachedCount(Object count) {
    return '$count attached';
  }

  @override
  String chatUiModelAndAgentHint(Object model, Object cost) {
    return 'Model and agent: $model. Tap to change.$cost';
  }

  @override
  String chatUiContextPercentFull(Object percent) {
    return 'Context $percent% full';
  }

  @override
  String chatUiRemoveReferenceName(Object name) {
    return 'Remove reference @$name';
  }

  @override
  String chatUiRemoveAttachmentName(Object name) {
    return 'Remove attachment $name';
  }

  @override
  String chatUiReferenceName(Object name) {
    return 'Reference @$name';
  }

  @override
  String chatUiPreviewAttachmentName(Object name) {
    return 'Preview attachment $name';
  }

  @override
  String chatUiProjectReferenceName(Object name) {
    return 'Project reference @$name';
  }

  @override
  String chatUiPreviewName(Object name) {
    return 'Preview $name';
  }

  @override
  String chatUiRemoveContextReference(Object name) {
    return 'Remove reference $name';
  }

  @override
  String chatUiContextPercentUsed(Object percent) {
    return 'Context window $percent percent used';
  }

  @override
  String chatUiExplainProject(Object name) {
    return 'Explain the $name project';
  }

  @override
  String chatUiEarlierMessageCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier messages',
      one: '1 earlier message',
    );
    return '$_temp0';
  }

  @override
  String chatUiPreviouslyValue(Object value) {
    return 'Previously $value';
  }

  @override
  String chatUiToolGroupSemantics(Object title, num count, Object status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$title, $_temp0, $status';
  }

  @override
  String chatUiTokenCount(Object count) {
    return '$count tok';
  }

  @override
  String chatUiAttachmentType(Object type) {
    return '$type · prompt attachment';
  }

  @override
  String chatUiPositionOfTotal(Object position, Object total) {
    return '$position of $total';
  }

  @override
  String chatUiSubagentCount(Object count) {
    return 'Subagent · $count';
  }

  @override
  String chatUiSharedLink(Object url) {
    return 'Shared conversation link $url';
  }

  @override
  String chatUiAttachmentCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String chatUiFailedDetail(Object error) {
    return 'Failed: $error';
  }

  @override
  String chatUiQueuedDraftLabel(Object label) {
    return 'Queued draft. $label';
  }

  @override
  String chatUiPendingSendLabel(Object label) {
    return 'Pending send. $label';
  }

  @override
  String chatUiPermissionContext(Object permission, Object context) {
    return 'Context: $permission $context';
  }

  @override
  String chatUiPermissionRequested(Object permission) {
    return 'The agent wants to use $permission.';
  }

  @override
  String chatUiReplyFailed(Object error) {
    return 'Reply failed: $error';
  }

  @override
  String chatUiCopyResource(Object resource) {
    return 'Copy $resource';
  }

  @override
  String chatUiPriorityLabel(Object priority) {
    return '$priority priority';
  }

  @override
  String chatUiToolsSummary(Object tools) {
    return 'Tools: $tools';
  }

  @override
  String chatUiFromLine(Object line) {
    return 'from $line';
  }

  @override
  String chatUiLineCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String chatUiLineRange(Object start, Object end) {
    return 'L$start–$end';
  }

  @override
  String chatUiEntryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String chatUiFoundCount(Object count) {
    return '$count found';
  }

  @override
  String chatUiMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String chatUiExitCode(Object code) {
    return 'exit $code';
  }

  @override
  String chatUiFileCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String chatUiProviderSearch(Object provider) {
    return '$provider search';
  }

  @override
  String chatUiResultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String chatUiCompletedCount(Object done, Object total) {
    return '$done/$total completed';
  }

  @override
  String chatUiAnsweredCount(Object count) {
    return '$count answered';
  }

  @override
  String chatUiAskedCount(Object count) {
    return '$count asked';
  }

  @override
  String chatUiDurationMinutesSeconds(Object minutes, Object seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String chatUiDurationSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String chatUiFileLoadFailed(Object error) {
    return 'Could not load this file from the OpenCode server: $error';
  }

  @override
  String chatUiMoreEntries(Object total) {
    return '$total total · more available';
  }

  @override
  String chatUiEntryTotal(Object total) {
    return '$total entries';
  }

  @override
  String chatUiSeeAllLines(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return 'See all · $_temp0';
  }

  @override
  String chatUiAnsweredDetail(Object answer) {
    return 'Answered: $answer';
  }

  @override
  String chatUiLoadingFile(Object filename) {
    return 'Loading $filename';
  }

  @override
  String chatUiPreviewGeneratedImage(Object filename) {
    return 'Preview generated image $filename';
  }

  @override
  String chatUiOpenGeneratedFile(Object filename) {
    return 'Open generated file $filename';
  }

  @override
  String chatUiParentSession(Object title) {
    return 'Parent · $title';
  }

  @override
  String chatUiChooseOption(Object option) {
    return 'Choose: $option';
  }

  @override
  String get chatUiConversation => 'Conversation';

  @override
  String get chatUiDisplayAndContext => 'Display and context';

  @override
  String get chatUiSessionActions => 'Conversation actions';

  @override
  String get chatUiResults => 'Results';

  @override
  String get chatUiPermissionFallback => 'a permission';

  @override
  String get chatUiMainSession => 'Main conversation';

  @override
  String get chatUiTodo => 'To do';

  @override
  String get chatUiBackgroundResult => 'Background result';

  @override
  String get chatUiBackgroundComplete => 'Completed';

  @override
  String get chatUiBackgroundError => 'Failed';

  @override
  String get chatUiBackgroundCancelled => 'Cancelled';

  @override
  String get chatUiResultDetails => 'Result details';

  @override
  String get chatUiResultSourceDetails => 'Server message details';

  @override
  String get chatUiResultOpenChild => 'Open subagent conversation';

  @override
  String get chatUiNoResultText => 'The server returned no result text.';

  @override
  String get chatUiBackground => 'Background';

  @override
  String get chatUiTimedOut => 'Timed out';

  @override
  String get chatUiKilled => 'Stopped';

  @override
  String get chatUiTruncated => 'Truncated';

  @override
  String get chatUiUpdated => 'Updated';

  @override
  String get chatUiPending => 'Pending';

  @override
  String get chatUiRunning => 'Running';

  @override
  String get chatUiCompleted => 'Completed';

  @override
  String get chatUiError => 'Error';

  @override
  String get chatUiUnknownStatus => 'Unknown status';

  @override
  String get chatUiAssistant => 'Assistant';

  @override
  String get chatUiUser => 'User';

  @override
  String get chatUiOpenCodeSession => 'OpenCode conversation';

  @override
  String get chatUiTool => 'Tool';

  @override
  String get chatUiFile => 'file';

  @override
  String get chatUiSeparator => ', ';

  @override
  String chatUiReadFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'read $count files',
      one: 'read 1 file',
    );
    return '$_temp0';
  }

  @override
  String chatUiSearched(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'searched $count times',
      one: 'searched once',
    );
    return '$_temp0';
  }

  @override
  String chatUiListedFolders(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'listed $count folders',
      one: 'listed 1 folder',
    );
    return '$_temp0';
  }

  @override
  String chatUiEditedFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'edited $count files',
      one: 'edited 1 file',
    );
    return '$_temp0';
  }

  @override
  String chatUiRanCommands(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ran $count commands',
      one: 'ran 1 command',
    );
    return '$_temp0';
  }

  @override
  String chatUiFetchedPages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fetched $count pages',
      one: 'fetched 1 page',
    );
    return '$_temp0';
  }

  @override
  String chatUiDelegatedTasks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'delegated $count tasks',
      one: 'delegated 1 task',
    );
    return '$_temp0';
  }

  @override
  String chatUiOtherCalls(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'made $count other calls',
      one: 'made 1 other call',
    );
    return '$_temp0';
  }

  @override
  String chatUiStepsNotRun(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps were not run',
      one: '1 step was not run',
    );
    return '$_temp0';
  }

  @override
  String get e7LibraryReportABug => 'Report a bug';

  @override
  String get e7LibraryKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get e7LibraryHTTPHeader => 'HTTP header';

  @override
  String get e7LibraryEnvironmentVariable => 'environment variable';

  @override
  String get e7LibraryOpenCodeIsReconnectingTryAgainShortly =>
      'OpenCode is reconnecting. Try again shortly.';

  @override
  String e7LibraryButTheAppCouldNotReconnect(String detail1, String detail2) {
    return '$detail1, but the app could not reconnect. $detail2';
  }

  @override
  String get e7LibraryWhatIsMCP => 'What is MCP?';

  @override
  String get e7LibrarySavingConfiguration => 'Saving configuration';

  @override
  String get e7LibrarySaveMCPServer => 'Save MCP server';

  @override
  String get e7LibraryPersistedConfiguration => 'Persisted configuration';

  @override
  String get e7LibrarySavedByOpenCodeOnTheServerIt =>
      'Saved by OpenCode on the server. It remains available after the app or server restarts.';

  @override
  String get e7LibraryThisProject => 'This project';

  @override
  String e7LibraryWritesOnlyTo(String detail1) {
    return 'Writes only to $detail1.';
  }

  @override
  String get e7LibraryWritesToThisOpenCodeServerSGlobal =>
      'Writes to this OpenCode server’s global configuration.';

  @override
  String get e7LibraryServerName => 'Server name';

  @override
  String get e7LibraryDocsOrBrowserTools => 'docs or browser-tools';

  @override
  String get e7LibraryUniqueWithinTheSelectedConfiguration =>
      'Unique within the selected configuration.';

  @override
  String get e7LibraryEnterAServerName => 'Enter a server name';

  @override
  String get e7LibraryRemoteURL => 'Remote URL';

  @override
  String get e7LibraryLocalCommand => 'Local command';

  @override
  String get e7LibraryTimeoutInMilliseconds => 'Timeout in milliseconds';

  @override
  String get e7LibraryOptional => 'Optional';

  @override
  String get e7LibraryEnterAValueGreaterThanZero =>
      'Enter a value greater than zero';

  @override
  String get e7LibraryMCPEndpointURL => 'MCP endpoint URL';

  @override
  String get e7LibraryHTTPIsAcceptedForLocalDevelopmentServers =>
      'HTTP is accepted for local development servers.';

  @override
  String get e7LibraryEnterAValidHTTPOrHTTPSURL =>
      'Enter a valid HTTP or HTTPS URL without credentials';

  @override
  String get e7LibraryHTTPHeaders => 'HTTP headers';

  @override
  String get e7LibraryOptionalEnterOneKEYVALUEPairPer =>
      'Optional. Enter one KEY=VALUE pair per line.';

  @override
  String get e7LibraryDetectOAuthAutomatically => 'Detect OAuth automatically';

  @override
  String get e7LibraryTurnThisOffWhenTheServerUses =>
      'Turn this off when the server uses headers and should never start OAuth.';

  @override
  String get e7LibraryCommandAndArguments => 'Command and arguments';

  @override
  String get e7LibraryRunsOnTheOpenCodeServerNotThis =>
      'Runs on the OpenCode server, not this phone. Enter one argument per line.';

  @override
  String get e7LibraryEnterACommand => 'Enter a command';

  @override
  String get e7LibraryWorkingDirectory => 'Working directory';

  @override
  String get e7LibraryOptionalServerPath => 'Optional server path';

  @override
  String get e7LibraryEnvironmentVariables => 'Environment variables';

  @override
  String e7LibraryInvalidOnLineUseKEYVALUE(String detail1, String detail2) {
    return 'Invalid $detail1 on line $detail2. Use KEY=VALUE.';
  }

  @override
  String e7LibraryInvalidNameOnLine(String detail1, String detail2) {
    return 'Invalid $detail1 name on line $detail2.';
  }

  @override
  String e7LibraryDuplicateName(String detail1, String detail2) {
    return 'Duplicate $detail1 name \"$detail2\".';
  }

  @override
  String get e7LibraryOpenCodeIsReconnectingTryAgain =>
      'OpenCode is reconnecting. Try again.';

  @override
  String get e7LibraryRevokeAlwaysAllowedAction => 'Revoke access?';

  @override
  String get e7LibraryOpenCodeWillAskAgainBeforeAFuture =>
      'OpenCode will ask again before a future action matching this grant.';

  @override
  String get e7LibraryAction => 'Action';

  @override
  String get e7LibraryResource => 'Resource';

  @override
  String get e7LibraryAllMatchingResources => '(all matching resources)';

  @override
  String get e7LibraryThisDoesNotStopAnActionThat =>
      'This does not stop an action that is already running.';

  @override
  String get e7LibraryKeepAccess => 'Keep access';

  @override
  String get e7LibraryRevokeAccess => 'Revoke access';

  @override
  String get e7LibraryAlwaysAllowedActionRevoked =>
      'Always allowed action revoked';

  @override
  String get e7LibraryAlwaysAllowedActions => 'Always allowed actions';

  @override
  String get e7LibraryRefreshAlwaysAllowedActions =>
      'Refresh always allowed actions';

  @override
  String get e7LibraryNoAlwaysAllowedActions => 'No always allowed actions';

  @override
  String get e7LibraryGrantsCreatedWithAlwaysAllowForThis =>
      'Grants created with Always allow for this project will appear here.';

  @override
  String get e7LibraryTheLastActionFailed => 'The last action failed';

  @override
  String e7LibraryRevokeAccess2(String detail1) {
    return 'Revoke $detail1 access';
  }

  @override
  String get e7LibraryToolsAndCapabilities => 'Tools and capabilities';

  @override
  String get e7LibraryRefreshTools => 'Refresh tools';

  @override
  String get e7LibraryOpenCodeToolsDependOnTheProviderAnd =>
      'OpenCode tools depend on the provider and model used by the active conversation.';

  @override
  String get e7LibraryChooseModel => 'Choose model';

  @override
  String get e7LibraryChange => 'Change';

  @override
  String get e7LibrarySearchTools => 'Search tools';

  @override
  String e7LibrarySearchTools2(String detail1) {
    return 'Search $detail1 tools';
  }

  @override
  String e7LibraryUsable(String detail1) {
    return '$detail1 usable';
  }

  @override
  String e7LibraryRegistered(String detail1) {
    return '$detail1 registered';
  }

  @override
  String get e7LibraryBackgroundSubagentsEnabled =>
      'Background subagents enabled';

  @override
  String get e7LibraryBackgroundSubagentsUnavailable =>
      'Background subagents unavailable';

  @override
  String get e7LibraryRegisteredInventoryUnavailable =>
      'registered inventory unavailable';

  @override
  String get e7LibraryServerCapabilityUnavailable =>
      'server capability unavailable';

  @override
  String get e7LibraryNoToolsForThisModel => 'No tools for this model';

  @override
  String get e7LibraryNoMatchingTools => 'No matching tools';

  @override
  String get e7LibraryOpenCodeReturnedNoCallableToolsForThis =>
      'OpenCode returned no callable tools for this provider and model.';

  @override
  String get e7LibraryTryAToolIDOrAWord =>
      'Try a tool ID or a word from its description.';

  @override
  String get e7LibraryCallableByThisModel => 'Callable by this model';

  @override
  String get e7LibraryRegisteredNotCallable => 'Registered, not callable';

  @override
  String get e7LibraryNoDescriptionReturnedByOpenCode =>
      'No description returned by OpenCode';

  @override
  String e7LibraryRegisteredOnThisProjectButNotReturned(
    String detail1,
    String detail2,
  ) {
    return 'Registered on this project but not returned for $detail1/$detail2.';
  }

  @override
  String get e7LibraryCopyParameterSchema => 'Copy parameter schema';

  @override
  String e7LibrarySchemaCopied(String detail1) {
    return '$detail1 schema copied';
  }

  @override
  String get e7LibraryParameterSchema => 'Parameter schema';

  @override
  String get e7LibraryNoProjectSelected => 'No project selected';

  @override
  String get e7LibraryNoProjectFolderIsOpenChooseOne =>
      'No project folder is open. Choose one from Work.';

  @override
  String get e7LibraryProject => 'Project';

  @override
  String get e7LibrarySwitchProject => 'Switch project';

  @override
  String get e7LibraryChooseAnotherProjectOpenedByThisServer =>
      'Choose another project opened by this server';

  @override
  String get e7LibraryCoding => 'Coding';

  @override
  String get e7LibraryWorktrees => 'Worktrees';

  @override
  String get e7LibraryChooseAProjectFirst => 'Choose a project first';

  @override
  String get e7LibraryCreateAndManageIsolatedGitBranches =>
      'Create and manage isolated Git branches';

  @override
  String get e7LibraryManagedWorkspaces => 'Cloud environments';

  @override
  String get e7LibraryCreateDiscoverOpenAndRemoveAdapterBacked =>
      'Create, discover, open, and remove adapter-backed environments';

  @override
  String get e7LibraryProjectHealth => 'Project health';

  @override
  String get e7LibraryBranchChangedFilesLanguageServicesAndFormatters =>
      'Branch, changed files, language services, and formatters';

  @override
  String get e7LibraryOpenCodeIsReconnecting => 'OpenCode is reconnecting.';

  @override
  String get e7LibraryWorkspaceDiscoveryFinished =>
      'Environment discovery finished';

  @override
  String e7LibraryCouldNotDiscoverWorkspaces(String detail1) {
    return 'Could not discover environments: $detail1';
  }

  @override
  String e7LibraryCouldNotCreateWorkspace(String detail1) {
    return 'Could not create environment: $detail1';
  }

  @override
  String e7LibraryWasRemoved(String detail1) {
    return '$detail1 was deleted';
  }

  @override
  String e7LibraryCouldNotRemoveWorkspace(String detail1) {
    return 'Could not delete environment: $detail1';
  }

  @override
  String get e7LibraryCloudEnvironments => 'Cloud environments';

  @override
  String get e7LibraryDiscoverExistingEnvironments =>
      'Discover existing environments';

  @override
  String get e7LibraryRefreshCloudEnvironments => 'Refresh cloud environments';

  @override
  String get e7LibraryNewEnvironment => 'New environment';

  @override
  String get e7LibraryEnvironments => 'Environments';

  @override
  String get e7LibraryNoCloudEnvironments => 'No cloud environments';

  @override
  String e7LibraryAdapterBackedEnvironmentsForAppearHereCreate(String detail1) {
    return 'Adapter-backed environments for $detail1 appear here. Create one from a server adapter, or use Discover to register environments the adapter already knows.';
  }

  @override
  String get e7LibraryEnvironmentRefreshFailed => 'Environment refresh failed';

  @override
  String get e7LibraryRetryCloudEnvironments => 'Try again';

  @override
  String get e7LibraryAdapters => 'Adapters';

  @override
  String get e7LibraryAdaptersUnavailable => 'Adapters unavailable';

  @override
  String get e7LibraryRetryWorkspaceAdapters => 'Try again';

  @override
  String get e7LibraryNoWorkspaceAdapters => 'No environment adapters';

  @override
  String get e7LibraryThisOpenCodeProjectDoesNotExposeManaged =>
      'This OpenCode project does not expose cloud environment creation.';

  @override
  String get e7LibraryAdapterRefreshFailed => 'Adapter refresh failed';

  @override
  String get e7LibraryConnected => 'Connected';

  @override
  String get e7LibraryConnecting => 'Connecting';

  @override
  String get e7LibraryDisconnected => 'Disconnected';

  @override
  String get e7LibraryEnvironmentActions => 'Environment actions';

  @override
  String get e7LibraryOpenAgain => 'Open again';

  @override
  String get e7LibraryNewManagedWorkspace => 'New cloud environment';

  @override
  String get e7LibraryAdapter => 'Adapter';

  @override
  String get e7LibraryBranchOptional => 'Branch (optional)';

  @override
  String get e7LibraryUseTheAdapterDefault => 'Use the adapter default';

  @override
  String get e7LibraryOpenCodeConfiguresAdapterSpecificDetailsOnThe =>
      'OpenCode configures adapter-specific details on the server. The new environment opens here after it is ready.';

  @override
  String get e7LibraryCreateAndOpen => 'Create and open';

  @override
  String e7LibraryRemove(String detail1) {
    return 'Delete $detail1?';
  }

  @override
  String get e7LibraryTheServerAdapterMayPermanentlyDeleteThe =>
      'The server adapter may permanently delete the remote environment or worktree. Existing conversations remain in history, but the environment may no longer be reachable.';

  @override
  String e7LibraryTypeToConfirm(String detail1) {
    return 'Type $detail1 to confirm';
  }

  @override
  String get e7LibraryRemovePermanently => 'Delete permanently';

  @override
  String e7LibraryIsReady(String detail1) {
    return '$detail1 is ready';
  }

  @override
  String get e7LibraryOpenCodeCouldNotPrepareThisWorktree =>
      'OpenCode could not prepare this worktree.';

  @override
  String e7LibraryWasCreatedItsSetupStatusIsNot(String detail1) {
    return '$detail1 was created. Its setup status is not yet confirmed.';
  }

  @override
  String e7LibraryCreatedOpenCodeIsPreparingIt(String detail1) {
    return '$detail1 created. OpenCode is preparing it.';
  }

  @override
  String get e7LibraryWaitForOpenCodeToFinishPreparingThis =>
      'Wait for OpenCode to finish preparing this worktree.';

  @override
  String get e7LibraryOpenCodeDidNotSwitchLocations =>
      'OpenCode did not switch projects.';

  @override
  String e7LibraryCouldNotVerifyBeforeThisDestructiveAction(
    String detail1,
    String detail2,
  ) {
    return 'Could not verify $detail1 before this destructive action: $detail2';
  }

  @override
  String e7LibraryResetToTheDefaultBranch(String detail1) {
    return '$detail1 reset to the default branch';
  }

  @override
  String e7LibraryAndItsBranchWereRemoved(String detail1) {
    return '$detail1 and its branch were deleted';
  }

  @override
  String e7LibraryReset(String detail1) {
    return 'Reset $detail1?';
  }

  @override
  String get e7LibraryThisPermanentlyDiscardsTrackedChangesAndDeletes =>
      'This permanently discards tracked changes and deletes all untracked and ignored files. Submodules are also reset and cleaned. This cannot be undone.';

  @override
  String get e7LibraryResetWorktree => 'Reset worktree';

  @override
  String get e7LibraryRefreshWorktrees => 'Refresh worktrees';

  @override
  String get e7LibraryNewWorktree => 'New worktree';

  @override
  String get e7LibraryPrimary => 'Primary';

  @override
  String get e7LibraryNoIsolatedWorktreesYet => 'No isolated worktrees yet';

  @override
  String get e7LibraryUseIsolatedBranchesForParallelCodingWithout =>
      'Use isolated branches for parallel coding without mixing changes. Create one when you want OpenCode to work on a separate branch.';

  @override
  String e7LibraryDefaultProject(String detail1) {
    return 'Default project · $detail1';
  }

  @override
  String e7LibrarySetupFailed(String detail1) {
    return 'Setup failed · $detail1';
  }

  @override
  String get e7LibraryPreparingFilesAndProjectTasks =>
      'Preparing files and project tasks…';

  @override
  String get e7LibraryWorktreeActions => 'Worktree actions';

  @override
  String get e7LibraryReset2 => 'Reset';

  @override
  String get e7LibraryNoChangedFilesWereDetected =>
      'No changed files were detected.';

  @override
  String get e7LibraryOpenCodeWillCreateAnIsolatedGitBranch =>
      'OpenCode will create an isolated Git branch and working directory. Project startup tasks run automatically.';

  @override
  String get e7LibraryNameOptional => 'Name (optional)';

  @override
  String get e7LibraryOpenCodeMakesTheNameURLSafeAnd =>
      'OpenCode makes the name URL-safe and unique.';

  @override
  String get e7LibraryTheWorktreeDirectoryAndItsGitBranch =>
      'The worktree directory and its Git branch will be permanently deleted. Existing conversations remain in history, but their working directory will no longer exist.';

  @override
  String get e7LibraryInitializeGitRepository => 'Initialize Git repository?';

  @override
  String get e7LibraryOpenCodeWillRunGitInitInThe =>
      'OpenCode will run git init in the current project. Existing files will not be changed or committed. This enables branch, working-tree, and Review features.';

  @override
  String get e7LibraryInitializeGit => 'Initialize Git';

  @override
  String get e7LibraryGitRepositoryInitialized => 'Git repository initialized';

  @override
  String get e7LibraryRefreshProjectHealth => 'Refresh project health';

  @override
  String get e7LibraryVersionControl => 'Version control';

  @override
  String e7LibraryChanged(String detail1) {
    return '$detail1 changed';
  }

  @override
  String get e7LibraryLanguageServices => 'Language services';

  @override
  String get e7LibraryFormatters => 'Formatters';

  @override
  String get e7LibraryVersionControl2 => 'version control';

  @override
  String get e7LibraryGitIsNotInitialized => 'Git is not initialized';

  @override
  String get e7LibraryInitializeThisProjectToEnableBranchesWorking =>
      'Initialize this project to enable branches, working-tree changes, and Review.';

  @override
  String get e7LibraryRunGitInitFromATerminal =>
      'Run `git init` from a terminal';

  @override
  String get e7LibraryGitInitializationFailed => 'Git initialization failed';

  @override
  String get e7LibraryNoActiveBranch => 'No active branch';

  @override
  String e7LibraryDefaultBranch(String detail1) {
    return 'Default branch: $detail1';
  }

  @override
  String get e7LibraryWorkingTreeIsClean => 'Working tree is clean';

  @override
  String e7LibraryChangedFiles(String detail1) {
    return '$detail1 changed files';
  }

  @override
  String get e7LibraryNoUncommittedChanges => 'No uncommitted changes';

  @override
  String get e7LibraryLanguageServices2 => 'language services';

  @override
  String get e7LibraryNoActiveLanguageServices => 'No active language services';

  @override
  String get e7LibraryOpenCodeActivatesThemWhileItInspectsSupported =>
      'OpenCode activates them while it inspects supported source files during coding.';

  @override
  String get e7LibraryNoFormattersConfigured => 'No formatters configured';

  @override
  String get e7LibraryEnabled => 'Enabled';

  @override
  String get e7LibraryDisabled => 'Disabled';

  @override
  String e7LibraryLoading(String detail1) {
    return 'Loading $detail1';
  }

  @override
  String get e7LibraryLocationChanged => 'Project changed.';

  @override
  String get e7LibraryAuthenticateFromTheServerMachine =>
      'Authenticate from the server machine';

  @override
  String e7LibraryMCPAuthorizationPendingFor(String detail1) {
    return 'MCP authorization pending for $detail1';
  }

  @override
  String get e7LibraryWaitingForBrowserAuthorization =>
      'Waiting for browser authorization';

  @override
  String get e7LibraryAutomaticCallbackCaptureIsUnavailablePasteThe =>
      'Automatic callback capture is unavailable. Paste the callback URL or authorization code.';

  @override
  String get e7LibraryThePhoneIsSecurelyListeningForThis =>
      'The phone is securely listening for this authorization callback. You can also enter it manually.';

  @override
  String get e7LibraryCompleteMCPAuthorization => 'Complete MCP authorization';

  @override
  String get e7LibraryCallbackURLOrCode => 'Callback URL or code';

  @override
  String get e7LibraryPasteTheCompleteCallbackURLWhenAvailable =>
      'Paste the complete callback URL when available so its security state can be verified.';

  @override
  String get e7LibraryComplete => 'Complete';

  @override
  String get e7LibraryUpdating => 'Updating…';

  @override
  String get e7LibraryNotConnected => 'Not connected';

  @override
  String get e7LibraryDisconnect => 'Disconnect';

  @override
  String get e7LibraryServerEnvironment => 'Server environment';

  @override
  String get e7LibraryServerManaged => 'Server-managed';

  @override
  String get e7LibraryConnect => 'Connect';

  @override
  String get e7LibraryAuthenticationFailed => 'Authentication failed';

  @override
  String get e7LibraryAuthenticationAttemptExpired =>
      'Authentication attempt expired';

  @override
  String get e7LibraryAuthenticationComplete => 'Authentication complete';

  @override
  String get e7LibraryReturnFromTheBrowserAndEnterThe =>
      'Return from the browser and enter the authorization code.';

  @override
  String get e7LibraryFinishAuthenticationInTheBrowserThenCheck =>
      'Finish authentication in the browser, then check its status.';

  @override
  String get e7LibraryFinish => 'Finish';

  @override
  String get e7LibraryCheck => 'Check';

  @override
  String e7LibraryConnecting2(String detail1) {
    return 'Connecting $detail1';
  }

  @override
  String get e7LibraryAuthenticationOptions => 'Authentication options';

  @override
  String get e7LibraryCancelAttempt => 'Cancel attempt';

  @override
  String e7LibraryFinish2(String detail1) {
    return 'Finish $detail1';
  }

  @override
  String get e7LibraryAuthorizationCode => 'Authorization code';

  @override
  String get e7LibraryNotYet => 'Not yet';

  @override
  String get e7LibrarySelectAnOption => 'Select an option';

  @override
  String get e7LibraryEnterAValue => 'Enter a value';

  @override
  String get e7LibraryTheServerReturnedAnUnsafeAuthorizationLink =>
      'The server returned an unsafe authorization link. Only HTTPS links with a valid host and no embedded credentials are allowed.';

  @override
  String get e7LibraryCouldNotLoadThisSection => 'Could not load this section';

  @override
  String e7LibraryConnectedAvailable(String detail1, String detail2) {
    return '$detail1 connected · $detail2 available';
  }

  @override
  String get e7LibrarySkills => 'Skills';

  @override
  String get e7LibraryNoSkillsAvailable => 'No skills available';

  @override
  String get e7LibraryProjectAndGlobalOpenCodeSkillsAppearHere =>
      'Project and global OpenCode skills appear here.';

  @override
  String get e7LibraryDeprecated => 'Deprecated';

  @override
  String get e7LibraryPreview => 'Preview';

  @override
  String get e7LibraryModelsAndAgents => 'Models and agents';

  @override
  String get e7LibraryUnavailable => 'Unavailable';

  @override
  String get e7LibraryFinishOrCancelTheCurrentMCPAuthorization =>
      'Finish or cancel the current MCP authorization first.';

  @override
  String get e7LibraryCouldNotOpenTheAuthorizationPage =>
      'Could not open the authorization page';

  @override
  String e7LibraryAuthenticated(String detail1) {
    return '$detail1 authenticated';
  }

  @override
  String get e7LibraryCouldNotConfirmMCPAuthentication =>
      'Could not confirm MCP authentication';

  @override
  String get e7LibraryMCPServerSavedInOpenCode =>
      'MCP server saved in OpenCode';

  @override
  String get e7LibraryMCPUnavailable => 'MCP unavailable';

  @override
  String get e7LibraryMCPAndIntegrations => 'MCP and integrations';

  @override
  String get e7LibraryTheModelProvidersThisOpenCodeServerCan =>
      'The model providers this OpenCode server can use. Connect one to start chatting.';

  @override
  String get e7LibraryCouldNotSaveSignInRecovery =>
      'Could not save sign-in recovery.';

  @override
  String get e7LibraryLoadingProviders => 'Loading providers';

  @override
  String get e7LibraryNoProviderConnectionsAvailable =>
      'No provider connections available';

  @override
  String get e7LibraryThisServerDidNotReturnAnyProvider =>
      'This server did not return any provider integrations.';

  @override
  String e7LibraryNoProvidersMatch(String detail1) {
    return 'No providers match “$detail1”';
  }

  @override
  String get e7LibraryTryAProviderNameItsIdOr =>
      'Try a provider name, its id, or one of its models.';

  @override
  String get e7LibrarySearchProvidersOrModels => 'Search providers or models';

  @override
  String get e7LibraryClearProviderSearch => 'Clear provider search';

  @override
  String get e7LibrarySERVERS => ' SERVERS';

  @override
  String get e7LibraryAddOnServersThatGiveTheAgent =>
      'Add-on servers that give the agent extra tools, like a browser or a database.';

  @override
  String get e7LibraryLoadingMCPServers => 'Loading MCP servers';

  @override
  String get e7LibraryNoMCPServersConfigured => 'No MCP servers configured';

  @override
  String get e7LibrarySaveOneForThisProjectOrEvery =>
      'Save one for this project or every project on the server.';

  @override
  String get e7LibraryAddAnMCPServer => 'Add an MCP server';

  @override
  String get e7LibraryAuthorizing => 'Authorizing';

  @override
  String get e7LibraryResources => 'Resources';

  @override
  String get e7LibraryFilesAndDataThatConnectedMCPServers =>
      'Files and data that connected MCP servers expose to the agent.';

  @override
  String get e7LibraryLoadingAvailableResources =>
      'Loading available resources';

  @override
  String get e7LibraryNoResourcesAvailable => 'No resources available';

  @override
  String get e7LibraryConnectedMCPServersHaveNotExposedAny =>
      'Connected MCP servers have not exposed any resources.';

  @override
  String get e7LibraryOpenAuthorizationPage => 'Open authorization page?';

  @override
  String get e7LibraryYouAreLeavingThisAppToAuthenticate =>
      'You are leaving this app to authenticate in your browser.';

  @override
  String get e7LibraryDestinationHost => 'Destination host';

  @override
  String get e7LibraryOpenCodeInstructions => 'OpenCode instructions';

  @override
  String get e7LibraryOpenBrowser => 'Open browser';

  @override
  String get e7LibraryConnectedAndToolsAreAvailable =>
      'Connected and tools are available';

  @override
  String get e7LibraryConnectionFailed => 'Connection failed';

  @override
  String get e7LibraryAuthenticationRequired => 'Authentication required';

  @override
  String get e7LibraryClientRegistrationRequired =>
      'Client registration required';

  @override
  String get e7LibraryAuthenticate => 'Authenticate';

  @override
  String e7LibraryStoredCredential(String detail1) {
    return 'Stored credential: $detail1';
  }

  @override
  String e7LibraryServerEnvironment2(String detail1) {
    return 'Server environment: $detail1';
  }

  @override
  String get e7LibraryNoConnectionMethodsAvailable =>
      'No connection methods available';

  @override
  String get e7LibraryConfiguredOnTheServer => 'Configured on the server';

  @override
  String e7LibraryDisconnect2(String detail1) {
    return 'Disconnect $detail1?';
  }

  @override
  String e7LibraryTheStoredCredentialWillBeRemovedFrom(String detail1) {
    return 'The stored credential will be removed from this OpenCode server. New prompts will stop using it after the provider runtime refreshes. An active response is not stopped.$detail1';
  }

  @override
  String get e7LibraryDisconnectProvider => 'Disconnect provider';

  @override
  String e7LibraryCredentialRemovedServerEnvironmentRemainsActive(
    String detail1,
  ) {
    return '$detail1 credential removed; server environment remains active';
  }

  @override
  String e7LibraryDisconnected2(String detail1) {
    return '$detail1 disconnected';
  }

  @override
  String e7LibraryConnect2(String detail1) {
    return 'Connect $detail1';
  }

  @override
  String get e7LibraryAuthorizationWasNotOpenedThePendingAttempt =>
      'Authorization was not opened. The pending attempt is retained.';

  @override
  String get e7LibraryCouldNotOpenOAuth => 'Could not open OAuth';

  @override
  String e7LibraryIsConnected(String detail1) {
    return '$detail1 is connected';
  }

  @override
  String get e7LibraryTheSignInSourceChanged => 'The sign-in source changed.';

  @override
  String get e7LibraryCouldNotConfirmAuthenticationReturnToThe =>
      'Could not confirm authentication. Return to the original source and try again.';

  @override
  String get e7LibrarySearchServerCommands => 'Search server commands';

  @override
  String get e7LibraryNoServerCommandsFound => 'No server commands found';

  @override
  String get e7LibraryCommandsFromYourProjectAndSkillsAppear =>
      'Commands from your project and skills appear here.';

  @override
  String get e7LibraryNoDescription => 'No description';

  @override
  String get e7LibraryServerCommands => 'Server commands';

  @override
  String get e7LibraryReferences => 'References';

  @override
  String get e7LibraryNoReferencesConfigured => 'No references configured';

  @override
  String get e7LibraryReferencesAttachedToThisProjectAppearHere =>
      'References attached to this project appear here.';

  @override
  String e7LibraryCopied(String detail1) {
    return '@$detail1 copied';
  }

  @override
  String e7LibraryGrantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grants',
      one: '1 grant',
    );
    return '$_temp0';
  }

  @override
  String e7LibraryModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return ' · $_temp0';
  }

  @override
  String e7LibraryChangedFilesDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changed files were detected.',
      one: '1 changed file was detected.',
    );
    return '$_temp0';
  }

  @override
  String get e7LibraryEnvironmentRemainsAfterDisconnect =>
      'This provider also uses the server environment, which mobile cannot remove and which will remain active.';

  @override
  String get e7LibrarySearchImportAliases =>
      'backup restore transfer JSON conversation session chat';

  @override
  String get e7LibrarySearchShortcutsAliases => 'hotkeys help desktop';

  @override
  String get e7SetupApiKeyHint => 'Paste an API key';

  @override
  String get e7SetupBrowserHint =>
      'Opens a browser. If the redirect cannot reach OpenCode, paste the callback URL here.';

  @override
  String get e7SetupDeviceCodeHint =>
      'Uses a one-time code. Works from a phone.';

  @override
  String get e7SetupAccountHint => 'Sign in with your account';

  @override
  String get e7SetupNewTerminalDetail => 'Start a shell in the active project.';

  @override
  String get e7SetupShowPassword => 'Show server password';

  @override
  String get e7SetupAuthFailed =>
      'The server started but authentication failed.';

  @override
  String get e7SetupScanInstruction =>
      'Point the camera at the QR code printed by opencode2 pair.';

  @override
  String get e7SetupRightKey => 'Right arrow key';

  @override
  String get e7SetupRestartReconnectFailed =>
      'The local server restarted, but the app could not reconnect.';

  @override
  String get e7SetupInstallingOpenCode => 'Installing OpenCode';

  @override
  String get e7SetupNoOutput => 'No terminal output yet.';

  @override
  String get e7SetupFollowLog => 'Follow the server log';

  @override
  String get e7SetupOpenSetupGuide => 'Open the setup guide';

  @override
  String get e7SetupScan => 'Scan';

  @override
  String get e7SetupLastOutput => 'LAST OUTPUT';

  @override
  String get e7SetupDownKey => 'Down arrow key';

  @override
  String get e7SetupVerifyContinue => 'Verify & continue';

  @override
  String get e7SetupAccessibleTerminal => 'Use accessible transcript and input';

  @override
  String get e7SetupUpdateOpenCode => 'Update OpenCode';

  @override
  String get e7SetupCameraFailedDetail =>
      'Another app may be holding the camera. Pasting the pairing code works either way.';

  @override
  String get e7SetupTermuxNoAnswer =>
      'Termux did not answer. Open Termux once, run the unlock line, then verify again.';

  @override
  String get e7SetupCopyOpenTermux => 'Copy & open Termux';

  @override
  String get e7SetupStopTerminalDetail =>
      'The running process and its child processes will be terminated.';

  @override
  String get e7SetupEdit => 'Edit';

  @override
  String get e7SetupUpdate => 'Update';

  @override
  String get e7SetupServerPassword => 'Server password';

  @override
  String get e7SetupHttpsHint =>
      'Use HTTPS for remote machines. HTTP is limited to localhost or 127.0.0.1.';

  @override
  String get e7SetupObservedVersionSaveFailed =>
      'The local server is ready, but its observed version could not be saved. Refresh setup to try again.';

  @override
  String get e7SetupPasteInstead => 'Paste it instead';

  @override
  String get e7SetupConfirmUpdate => 'Update managed OpenCode?';

  @override
  String get e7SetupInstallServiceDetail =>
      'Official installer plus a systemd user service that survives closed terminals and reboots.';

  @override
  String get e7SetupUpdateHost => 'Update OpenCode on the host';

  @override
  String get e7SetupServiceStatus => 'Service status';

  @override
  String get e7SetupKeepAfterLogout => 'Keep it running after logout';

  @override
  String get e7SetupGetTermux => 'Get Termux';

  @override
  String get e7SetupRestartServer => 'Restart the server';

  @override
  String get e7SetupResumeSetup => 'Retry — resumes where setup left off';

  @override
  String get e7SetupHidePassword => 'Hide server password';

  @override
  String get e7SetupControlKeys =>
      'Terminal control keys. Swipe horizontally for more.';

  @override
  String get e7SetupSetupFailed => 'Setup failed.';

  @override
  String get e7SetupEndInputKey => 'End of input, Control D';

  @override
  String get e7SetupGuidanceSaveFailed =>
      'Could not save connection guidance. Retry saving.';

  @override
  String get e7SetupServerOperation => 'Server operation in progress';

  @override
  String get e7SetupNewTerminal => 'New terminal';

  @override
  String get e7SetupUnsavedProfile => 'The server has not been saved.';

  @override
  String get e7SetupCheckingInstall => 'Checking installed environment...';

  @override
  String get e7SetupInspectTermuxFailed => 'Android could not inspect Termux.';

  @override
  String get e7SetupUsername => 'Username (optional)';

  @override
  String get e7SetupFirstSetupDuration =>
      'First-time setup can take 10–15 minutes. You can leave this screen and return; setup keeps running.';

  @override
  String get e7SetupNoTerminals => 'No terminal processes';

  @override
  String get e7SetupEscapeKey => 'Escape key';

  @override
  String get e7SetupLeftKey => 'Left arrow key';

  @override
  String get e7SetupInstallService =>
      'Install OpenCode as a background service';

  @override
  String get e7SetupPaused => 'Paused';

  @override
  String get e7SetupSaveToFinish => 'Connected — save to finish.';

  @override
  String get e7SetupPasswordStartupHint =>
      'Printed by opencode2 serve at startup (\"server password …\"). Optional for servers without one.';

  @override
  String get e7SetupInstallTermuxDetail =>
      'Install the current F-Droid build of Termux, then return here.';

  @override
  String get e7SetupStopBeforeUpdate =>
      'Stop active generation before updating OpenCode.';

  @override
  String get e7SetupRestartingLocal => 'Restarting the local server';

  @override
  String get e7SetupAddServer => 'Add server';

  @override
  String get e7SetupStepTodo => 'to do';

  @override
  String get e7SetupInteractiveTerminal => 'Use interactive terminal';

  @override
  String get e7SetupInstallingUbuntu => 'Setting up Ubuntu';

  @override
  String get e7SetupInterruptKey => 'Interrupt, Control C';

  @override
  String get e7SetupServerUrl => 'Server URL';

  @override
  String get e7SetupStopTerminal => 'Stop terminal?';

  @override
  String get e7SetupUsbAccess => 'Reach it from this phone over USB';

  @override
  String get e7SetupWaitingTermux =>
      'Waiting for Termux to respond. This can take a little while.';

  @override
  String get e7SetupDiscardChanges => 'Discard server changes?';

  @override
  String get e7SetupPasswordRequired => 'Password re-entry required';

  @override
  String get e7SetupPairing => 'Pairing…';

  @override
  String get e7SetupCommandInput => 'Terminal command input';

  @override
  String get e7SetupCameraFailed => 'The camera could not be opened';

  @override
  String get e7SetupPastePassword => 'Paste server password';

  @override
  String get e7SetupSavingLocal => 'Saving local server settings';

  @override
  String get e7SetupCopyFailureReport => 'Copy failure report';

  @override
  String get e7SetupCameraDisabled => 'Camera access is turned off';

  @override
  String get e7SetupRename => 'Rename';

  @override
  String get e7SetupPastePairing => 'Paste pairing code';

  @override
  String get e7SetupServers => 'Servers';

  @override
  String get e7SetupStartingSetup => 'Starting setup in Termux';

  @override
  String get e7SetupSetupNotStarted =>
      'Termux opened but the setup did not start. Retry once; if it happens again, copy the failure report.';

  @override
  String get e7SetupConnecting => 'Connecting';

  @override
  String get e7SetupThisDevice => 'This device (Termux)';

  @override
  String get e7SetupTransportReconnecting =>
      'The server transport is reconnecting.';

  @override
  String get e7SetupStepUnavailable => 'not yet available';

  @override
  String get e7SetupUpdateHostDetail =>
      'When the server reports an update, Settings offers the native upgrade first; this is the host-side equivalent.';

  @override
  String get e7SetupMissingPasswordShort =>
      'The saved password is unavailable. Enter it again, or leave it empty only if this server no longer requires one.';

  @override
  String get e7SetupTesting => 'Testing…';

  @override
  String get e7SetupScanPairing => 'Scan pairing code';

  @override
  String get e7SetupRestartUnconfirmed =>
      'Could not confirm this restart. Refresh its progress before retrying.';

  @override
  String get e7SetupExistingMissingCredential =>
      'A local server exists, but its saved credential is unavailable. Run setup again to replace it safely.';

  @override
  String get e7SetupPreparingModels => 'Getting models ready';

  @override
  String get e7SetupHostInstructions =>
      'These commands run on the computer that hosts this server — the app cannot run them for you. Copy each one into a terminal on that machine.';

  @override
  String get e7SetupTranscript => 'Terminal transcript';

  @override
  String get e7SetupHostFirstSetup => 'First-time setup — run on your computer';

  @override
  String get e7SetupNoCameraDetail =>
      'There is nothing to scan with. Run opencode2 pair on the server, copy the code it prints, and paste it into the server editor.';

  @override
  String get e7SetupDiscard => 'Discard';

  @override
  String get e7SetupConnectionClosed => 'Connection closed';

  @override
  String get e7SetupNotConnected => 'Not connected';

  @override
  String get e7SetupTokenBanner =>
      'Connection token re-entry required for the active server. Edit the server and save its token before connecting.';

  @override
  String get e7SetupUpKey => 'Up arrow key';

  @override
  String get e7SetupV1Limited =>
      'This app targets OpenCode 2; some features are unavailable on v1 servers.';

  @override
  String get e7SetupConnect => 'Connect';

  @override
  String get e7SetupRemoveTerminalDetail =>
      'This terminal record will be removed.';

  @override
  String get e7SetupAuthentication => 'AUTHENTICATION';

  @override
  String get e7SetupInputDisconnected =>
      'Input is unavailable while disconnected.';

  @override
  String get e7SetupHostCopied => 'Copied. Run it on the server\'s computer.';

  @override
  String get e7SetupCameraPrivacy =>
      'The camera is used only to read the QR that opencode2 pair prints, and only while this screen is open. You can paste the code instead — it does exactly the same thing.';

  @override
  String get e7SetupIsV2 => 'This is an OpenCode 2 server.';

  @override
  String get e7SetupResumeLive => 'Resume live view';

  @override
  String get e7SetupTabKey => 'Tab key';

  @override
  String get e7SetupCloseScanner => 'Close the scanner';

  @override
  String get e7SetupChooseContinue => 'Choose how to continue';

  @override
  String get e7SetupTermuxOutdated =>
      'This version of Termux is too old for the app to control it. Install the current F-Droid or GitHub build of Termux, then check again.';

  @override
  String get e7SetupContinueApp => 'Continue to app';

  @override
  String get e7SetupCameraNeeded => 'Camera access is needed to scan';

  @override
  String get e7SetupTerminalActions => 'Terminal actions';

  @override
  String get e7SetupReadPassword => 'Read the server password for this app';

  @override
  String get e7SetupStartInstalled => 'Start installed OpenCode?';

  @override
  String get e7SetupTestConnection => 'Test connection';

  @override
  String get e7SetupCheckingTermux => 'Checking Termux connection';

  @override
  String get e7SetupCheckingTermuxShort => 'Checking Termux...';

  @override
  String get e7SetupDefaultServer => 'OpenCode server';

  @override
  String get e7SetupSaving => 'Saving…';

  @override
  String get e7SetupNotYet => 'Not yet';

  @override
  String get e7SetupLinuxService => 'Run as a Linux service';

  @override
  String get e7SetupPairingDesktopHint =>
      'Check that the server is running, and that the address it printed is one this machine can reach.';

  @override
  String get e7SetupAboutNotices => 'About and open source notices';

  @override
  String get e7SetupSetupLost => 'Lost track of the setup running in Termux';

  @override
  String get e7SetupVerifying => 'Verifying...';

  @override
  String get e7SetupReportCopied => 'Failure report copied.';

  @override
  String get e7SetupPreparingSetup => 'Preparing setup';

  @override
  String get e7SetupAppSettings => 'App settings';

  @override
  String get e7SetupUnavailable => 'Unavailable';

  @override
  String get e7SetupStepDone => 'done';

  @override
  String get e7SetupNoCamera => 'This device has no camera';

  @override
  String get e7SetupServerDisconnected => 'The server is not connected.';

  @override
  String get e7SetupTitle => 'Title';

  @override
  String get e7SetupEmptyPasswordHint =>
      'Leave empty only if this server no longer uses a password.';

  @override
  String get e7SetupAndroidOnly => 'Setup on this phone is Android only';

  @override
  String get e7SetupEditServer => 'Edit server';

  @override
  String get e7SetupReenterPassword => 'Re-enter password';

  @override
  String get e7SetupMissingCredential =>
      'The saved credential for this managed server is unavailable. Run setup again to replace it safely.';

  @override
  String get e7SetupReconnect => 'Reconnect';

  @override
  String get e7SetupSwitchNotStarted => 'The runtime switch did not start.';

  @override
  String get e7SetupNoUbuntu => 'No managed Ubuntu installation found.';

  @override
  String get e7SetupKeyUnavailable =>
      'Unavailable while the terminal is disconnected';

  @override
  String get e7SetupCopyTerminal => 'Copy terminal selection or transcript';

  @override
  String get e7SetupCommandHint => 'Type a command';

  @override
  String get e7SetupCheckInstallFailed =>
      'Could not check the installed environment.';

  @override
  String get e7SetupLiveOutput => 'LIVE OUTPUT';

  @override
  String get e7SetupConnectionFailed => 'Connection failed.';

  @override
  String get e7SetupOpenAppSettings => 'Open app settings';

  @override
  String get e7SetupFullWalkthrough => 'Full walkthrough (opens in browser)';

  @override
  String get e7SetupPairingPhoneHint =>
      'A server bound to its own 127.0.0.1 is not reachable from this phone until you bridge it — `adb reverse tcp:PORT tcp:PORT` over USB, or an SSH forward. To reach it over the network instead, put it behind HTTPS.';

  @override
  String get e7SetupOutputCopied => 'Setup output copied.';

  @override
  String get e7SetupMissingPasswordLong =>
      'The saved password is unavailable. Enter it again, or leave it empty only if this server no longer requires a password.';

  @override
  String get e7SetupNoServerGuide =>
      'No server there yet? The setup guide shows how to start one.';

  @override
  String get e7SetupExited => 'Exited';

  @override
  String get e7SetupDownloadPage => 'Download page';

  @override
  String get e7SetupStartingLocal => 'Starting local server';

  @override
  String get e7SetupTerminalSemantics =>
      'Interactive terminal. Use the accessibility button for a readable transcript and labeled input.';

  @override
  String get e7SetupRestartingLocalStage => 'Restarting local server';

  @override
  String get e7SetupPasswordBanner =>
      'Password re-entry required for the active server. Edit the server and save its password before connecting.';

  @override
  String get e7SetupEmptyPairClipboard =>
      'The clipboard is empty. Run `opencode2 pair` on the server and copy the code it prints.';

  @override
  String get e7SetupRestartActiveChanged =>
      'The local server restarted, but the active server changed. Reconnect when you are ready.';

  @override
  String get e7SetupTokenRequired => 'Connection token re-entry required';

  @override
  String get e7SetupPairingInstructions =>
      'On your computer run `opencode2 pair`, then paste or scan the code it prints.';

  @override
  String get e7SetupHostDaily => 'Day-to-day — run on your computer';

  @override
  String get e7SetupStopLocal => 'Stop local server';

  @override
  String get e7SetupReadingProgress => 'Reading setup progress';

  @override
  String get e7SetupCameraSettingsDetail =>
      'Android will not ask again, so this has to be changed in app settings: turn on Camera, then come back. Pasting the code needs no permission at all and works right now.';

  @override
  String get e7SetupVerifyTermuxFailed => 'Termux bridge verification failed.';

  @override
  String get e7SetupStartConnect => 'Start & connect';

  @override
  String get e7SetupThisServer => 'This server';

  @override
  String get e7SetupUbuntuOnly =>
      'Ubuntu is installed. OpenCode is not installed yet.';

  @override
  String get e7SetupRenameTerminal => 'Rename terminal';

  @override
  String get e7SetupInputUnavailable => 'Terminal input unavailable';

  @override
  String get e7SetupUpdateInterruption =>
      'The server will be briefly unavailable. Active generation should be stopped first.';

  @override
  String get e7SetupRunningOnPhone => 'OpenCode is running on this phone.';

  @override
  String get e7SetupLocalStopped =>
      'The local server is stopped. Its installed files are kept.';

  @override
  String get e7SetupDidNotConnect => 'The server did not connect.';

  @override
  String get e7SetupSendCommand => 'Send command to terminal';

  @override
  String get e7SetupStepRunning => 'in progress';

  @override
  String get e7SetupStopping => 'Stopping...';

  @override
  String get e7SetupUnsupportedSetup =>
      'On-device setup requires Termux on Android. On this computer, run `opencode serve` and add its address.';

  @override
  String get e7SetupSendKey => 'Sends this key to the terminal';

  @override
  String get e7SetupRemoveTerminal => 'Remove terminal?';

  @override
  String get e7SetupStepFailed => 'failed';

  @override
  String e7SetupTerminalNumber(int number) {
    return 'Terminal $number';
  }

  @override
  String e7SetupProcessRunning(String command, int pid) {
    return '$command - PID $pid';
  }

  @override
  String e7SetupProcessExited(String command, String code) {
    return '$command - exited $code';
  }

  @override
  String e7SetupConnectedPid(int pid) {
    return 'Connected - PID $pid';
  }

  @override
  String e7SetupTerminalStatus(String status) {
    return 'Terminal status: $status';
  }

  @override
  String e7SetupServerVersion(String version) {
    return 'Server version $version';
  }

  @override
  String e7SetupCopyCommandLabel(String label) {
    return 'Copy command: $label';
  }

  @override
  String e7SetupConnectFailedDetail(String name, String detail) {
    return 'Could not connect to $name. $detail Check the server address and credentials, then try again.';
  }

  @override
  String e7SetupSavedConnectFailed(String name, String detail) {
    return '$name was saved, but it could not connect. Check the server address and credentials, then try again. ($detail)';
  }

  @override
  String e7SetupSaveFailed(String name, String detail) {
    return 'Could not save $name. The existing server was left unchanged. Check device storage and try again. ($detail)';
  }

  @override
  String e7SetupRemoveServer(String name) {
    return 'Remove $name?';
  }

  @override
  String e7SetupRemovedDisconnectFailed(String name, String detail) {
    return '$name was removed, but its connection could not be closed cleanly. Restart the app before connecting elsewhere. ($detail)';
  }

  @override
  String e7SetupRemoveFailed(String name, String detail) {
    return 'Could not remove $name. The saved server and current connection were kept. Check device storage and try again. ($detail)';
  }

  @override
  String e7SetupPairedChoice(String host, int count) {
    return 'Paired with $host — chosen from $count addresses in the code.';
  }

  @override
  String e7SetupPaired(String host) {
    return 'Paired with $host.';
  }

  @override
  String e7SetupStartFailed(String detail) {
    return 'Could not save or start the local setup: $detail';
  }

  @override
  String e7SetupInstalledVersion(String version) {
    return 'Installed version: $version.';
  }

  @override
  String e7SetupRestartFailed(String detail) {
    return 'Could not restart the local server: $detail';
  }

  @override
  String e7SetupStopFailed(String detail) {
    return 'Could not stop the local server: $detail';
  }

  @override
  String e7SetupStopDisconnectFailed(String detail) {
    return 'The server stopped, but the app could not disconnect: $detail';
  }

  @override
  String e7SetupVersionAddress(String version, String address) {
    return 'Version $version · $address';
  }

  @override
  String e7SetupVersion(String version) {
    return 'Version $version';
  }

  @override
  String e7SetupStartInstalledDetail(String version) {
    return 'Start OpenCode $version using the existing installation and connect to it. Only this app’s local server restarts; no packages are downloaded or updated.';
  }

  @override
  String e7SetupFoundInstalled(String version) {
    return 'Found OpenCode $version in Ubuntu';
  }

  @override
  String e7SetupElapsedSeconds(int seconds) {
    return '${seconds}s elapsed';
  }

  @override
  String e7SetupElapsedMinutes(int minutes, int seconds) {
    return '${minutes}m ${seconds}s elapsed';
  }

  @override
  String e7SetupStepSemantics(int number, String state, String title) {
    return 'Step $number of 3, $state. $title';
  }

  @override
  String e7SetupDeleteDisclosure(int queued, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      queued,
      locale: localeName,
      other: '$queued queued prompts will be deleted.',
      one: '1 queued prompt will be deleted.',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts unsent drafts will be deleted.',
      one: '1 unsent draft will be deleted.',
      zero: '',
    );
    return 'This deletes everything this device stored for the server: its password, selected model and agent, project choice, and any conversations shown in the home-screen widget.\n\n$_temp0 $_temp1\n\nNothing is deleted on the server itself or at your AI providers.';
  }

  @override
  String e7SetupPairingFailed(String detail, String hint) {
    return 'No address in that pairing code answered:\n$detail\n$hint';
  }

  @override
  String e7SetupProbeV2(String version) {
    return 'OpenCode 2 · $version';
  }

  @override
  String e7SetupProbeV1(String version) {
    return 'OpenCode 1 · $version — limited feature set';
  }

  @override
  String get e7SetupPairNone =>
      'There is no pairing code here. Run `opencode2 pair` on the server and scan or copy what it prints.';

  @override
  String get e7SetupPairLong =>
      'That is far too long to be a pairing code. Copy only the line `opencode2 pair` prints, or scan its QR code.';

  @override
  String get e7SetupPairInvalid =>
      'That is not a pairing code. Run `opencode2 pair` on the server and scan or copy what it prints.';

  @override
  String get e7SetupPairShape =>
      'That pairing code is the wrong shape — it should be a JSON object with `urls`, `username`, and `password`.';

  @override
  String get e7SetupPairNoUrls =>
      'That pairing code has no `urls` field, so there is no address to connect to.';

  @override
  String get e7SetupPairUrlsType =>
      'That pairing code\'s `urls` field is not a list of addresses.';

  @override
  String get e7SetupPairTooMany =>
      'That pairing code lists more addresses than this app will try. Bind the server to one interface and pair again.';

  @override
  String get e7SetupPairAddressType =>
      'That pairing code lists an address that is not text.';

  @override
  String get e7SetupPairAddressLong =>
      'That pairing code lists an address far too long to be a server URL.';

  @override
  String get e7SetupPairAddressMissing =>
      'That pairing code carries no server address. Check that the server is actually listening, then run `opencode2 pair` again.';

  @override
  String get e7SetupPairUsernameType =>
      'That pairing code\'s `username` field is not text.';

  @override
  String get e7SetupPairPasswordMissing =>
      'That pairing code has no `password` field. It may have been truncated — scan or copy the whole code.';

  @override
  String get e7SetupPairPasswordType =>
      'That pairing code\'s `password` field is not text.';

  @override
  String get e7SetupPairTestFailed =>
      'The connection test failed before the server could be checked. Try another address.';

  @override
  String get e7SetupNotOpenCode =>
      'The address did not answer as an OpenCode server. Check the address and try again.';

  @override
  String get e7SetupNoServerAnswer =>
      'The server did not answer. Check that opencode serve is running on that address.';

  @override
  String get e7SetupPairPasswordRejected =>
      'Password rejected. Check the pairing code and try again.';

  @override
  String get e7SetupPairAddressUnusable =>
      'That pairing code contains an unusable server address.';

  @override
  String get e7SetupNoAnswer => 'Did not answer.';

  @override
  String get e7SetupInvalidAddress => '<invalid address>';

  @override
  String get e7SetupEnterUrl => 'Enter a server URL.';

  @override
  String get e7SetupIncludeScheme =>
      'Include https://. Use http:// only for localhost, 127.0.0.1, or [::1].';

  @override
  String get e7SetupCompleteUrl =>
      'Enter a complete server URL, such as https://server.example:4096.';

  @override
  String get e7SetupUrlScheme =>
      'Server URLs must use https://, or http:// for a local server.';

  @override
  String get e7SetupTermuxUrlScheme =>
      'Server URLs must use https://, or http:// for local Termux.';

  @override
  String get e7SetupUrlCredentials =>
      'Do not put credentials in the URL. Use the fields below.';

  @override
  String get e7SetupUrlQuery =>
      'Remove query parameters and fragments from the server URL.';

  @override
  String get e7SetupUrlPath =>
      'Remove the path from the server URL. Enter only its origin.';

  @override
  String get e7SetupRequireHttps =>
      'HTTPS is required outside this device. Basic credentials must never be sent over HTTP.';

  @override
  String get e7SetupLocalHttp =>
      'HTTP is allowed only for localhost, 127.0.0.1, or [::1]. Use HTTPS for LAN and remote servers.';

  @override
  String get e7SetupRefused =>
      'The connection was refused. Is opencode serve running on that host and port?';

  @override
  String get e7SetupTimeout =>
      'The connection timed out. Check the address, and that the server is reachable from this phone.';

  @override
  String get e7SetupDns =>
      'That host name could not be found. Check the address spelling.';

  @override
  String get e7SetupCertificate =>
      'The server’s TLS certificate was rejected. Use a certificate this phone trusts.';

  @override
  String get e7SetupUnhealthy =>
      'The server responded but reported itself unhealthy. Check its logs, then try again.';

  @override
  String get e7SetupServerStarting =>
      'The server is starting. Try again in a moment.';

  @override
  String get e7SetupPasswordNeeded =>
      'This server requires its serve password.';

  @override
  String get e7SetupPasswordRejected =>
      'Password rejected. Copy the current \"server password\" line from the server output — it changes on every restart unless OPENCODE_PASSWORD is set.';

  @override
  String get e7SetupCredentialsRefused =>
      'The server refused the credentials. Check the username and password.';

  @override
  String get e7SetupCodexUrl => 'Enter a Codex server URL.';

  @override
  String get e7SetupCodexCompleteUrl => 'Enter a complete Codex server URL.';

  @override
  String get e7SetupCodexScheme =>
      'Codex server URLs must use wss://, or ws:// for a local server.';

  @override
  String get e7SetupCodexCredentials =>
      'Do not put credentials in the Codex URL.';

  @override
  String get e7SetupCodexQuery =>
      'Remove query parameters and fragments from the Codex URL.';

  @override
  String get e7SetupCodexPath => 'Remove the path from the Codex server URL.';

  @override
  String get e7SetupCodexPlain =>
      'Plain WebSocket is allowed only for a local Codex server.';

  @override
  String get e7SetupCodexDirectory =>
      'Enter an absolute Codex project directory.';

  @override
  String get e7SetupCodexToken => 'Enter a valid Codex connection token.';

  @override
  String get e7SetupRefreshPackages => 'Refreshing Termux packages';

  @override
  String get e7SetupRepairPackages => 'Repairing the Termux package set';

  @override
  String get e7SetupInstallDependencies => 'Installing Termux dependencies';

  @override
  String get e7SetupPrepareTermux => 'Preparing Termux';

  @override
  String get e7SetupInstallUbuntu => 'Installing Ubuntu environment';

  @override
  String get e7SetupRefreshModels => 'Refreshing the OpenCode model catalog';

  @override
  String get e7SetupStartLocalServer => 'Starting the local server';

  @override
  String get e7SetupOpenCodeReady => 'OpenCode is ready';

  @override
  String get e7SetupPrepareRuntime => 'Preparing the selected OpenCode runtime';

  @override
  String get e7SetupSwitchLocal => 'Switching the managed local server';

  @override
  String get e7SetupCheckRestart => 'Checking the local server before restart';

  @override
  String get e7SetupStoppingLocal => 'Stopping the local server';

  @override
  String get e7SetupStoppedLocal => 'Local server stopped';

  @override
  String get e7SetupUnknownSetup => 'Unknown setup state';

  @override
  String get e7SetupUnexpectedStop =>
      'The local OpenCode server stopped unexpectedly';

  @override
  String get e7SetupSetupInterrupted =>
      'Setup stopped unexpectedly; see live output for details';

  @override
  String get e7SetupRecoveryDisabled => 'Automatic recovery disabled';

  @override
  String get e7SetupRecoveryWasDisabled => 'Automatic recovery was disabled';

  @override
  String get e7SetupPortBusy =>
      'The local server port is still in use; no replacement was started';

  @override
  String get e7SetupNoReturnData =>
      'This OpenCode 2 installation has no separate OpenCode 1 data to return to';

  @override
  String get e7SetupCredentialMismatch =>
      'The saved server credential differs from this runtime; restore its original saved credential before returning';

  @override
  String get e7SetupUbuntuUnavailable =>
      'The managed Ubuntu environment is unavailable';

  @override
  String get e7SetupRuntimeUnavailable =>
      'The selected OpenCode command is unavailable';

  @override
  String get e7SetupIdentityMismatch =>
      'The tracked process is not the managed OpenCode server';

  @override
  String get e7SetupPasswordMissing => 'The local server password is missing';

  @override
  String get e7SetupVersionMissing =>
      'OpenCode installed but did not report a version';

  @override
  String get e7SetupModelsRefreshFailed =>
      'OpenCode updated, but its model catalog could not be refreshed';

  @override
  String get e7SetupStartupExited => 'OpenCode server exited during startup';

  @override
  String get e7SetupReadinessTimeout =>
      'OpenCode server did not become authenticated and ready within 30 seconds';

  @override
  String get e7SetupUnreadableData =>
      'The OpenCode 2 data location record is unreadable';

  @override
  String get e7SetupUnreadablePrevious =>
      'The previous runtime record is unreadable';

  @override
  String get e7SetupReadManagerFailed => 'Could not read setup manager status';

  @override
  String get e7SetupMissingManager => 'Setup manager is missing';

  @override
  String get e7SetupRemoveInterruptedFailed =>
      'Could not remove the interrupted app-owned Ubuntu install';

  @override
  String get e7SetupCheckStorageFailed =>
      'Could not check available storage before setup';

  @override
  String get e7SetupReadStorageFailed =>
      'Could not read available storage before setup';

  @override
  String get e7SetupRepositoryFailed =>
      'Could not select the official Termux package repository';

  @override
  String get e7SetupRepositoryRefreshFailed =>
      'Could not refresh packages.termux.dev; check the network and retry';

  @override
  String get e7SetupRepairFailed =>
      'Could not repair the interrupted Termux package transaction';

  @override
  String get e7SetupUpgradeFailed =>
      'Could not complete the safe Termux package upgrade';

  @override
  String get e7SetupDependenciesFailed =>
      'Could not install the Termux dependencies';

  @override
  String get e7SetupDependenciesUnusable =>
      'Termux dependencies are still unusable after the package repair';

  @override
  String get e7SetupUbuntuUnusable =>
      'An existing Ubuntu container is not usable; setup will not delete it';

  @override
  String get e7SetupExtractionFailed =>
      'Ubuntu Base extraction did not create a usable container';

  @override
  String get e7SetupLockFailed =>
      'Setup manager could not claim its launch lock';

  @override
  String get e7SetupSetupGroupFailed =>
      'Setup manager did not start in an isolated process group';

  @override
  String get e7SetupSwitchGroupFailed =>
      'Switch manager did not start in an isolated process group';

  @override
  String get e7SetupServerGroupFailed =>
      'Managed server did not start in an isolated process group';

  @override
  String get e7SetupRecordIdentityFailed =>
      'Could not record the managed server process identity';

  @override
  String e7SetupConnectingProfile(String name) {
    return 'Connecting to $name';
  }

  @override
  String e7SetupConnectingAttempt(int attempt) {
    return 'Connecting again (attempt $attempt)';
  }

  @override
  String get e7SetupOpeningWorkspace => 'Opening your saved project.';

  @override
  String get e7SetupWhatToCheck => 'What to check';

  @override
  String get e7SetupHideDetails => 'Hide details';

  @override
  String get e7SetupDetails => 'Details';

  @override
  String get e7SetupChangeServer => 'Change server';

  @override
  String get e7SetupUpdatePassword => 'Update password';

  @override
  String e7SetupLastSetupDetail(String detail) {
    return 'Last setup output: $detail';
  }

  @override
  String e7SetupBridgeDetail(String detail) {
    return 'Bridge detail: $detail';
  }

  @override
  String e7SetupDiagnosticsUnavailable(String detail) {
    return 'Diagnostics unavailable: $detail';
  }

  @override
  String e7SetupProbeHttp(String status) {
    return 'The address responded, but not like an OpenCode server (HTTP $status). Check that the URL points at opencode serve.';
  }

  @override
  String e7SetupProbeError(String detail) {
    return 'Connection test failed: $detail';
  }

  @override
  String e7SetupServerExit(String code) {
    return 'OpenCode server exited (code $code)';
  }

  @override
  String get e7SetupCheckTermux => 'On this phone';

  @override
  String get e7SetupCommandFailed => 'Termux command failed.';

  @override
  String get e7SetupUnexpectedBridge =>
      'Termux returned an unexpected bridge response.';

  @override
  String get e7SetupSetupQueued => 'Setup queued';

  @override
  String get e7SetupNoSetup => 'No setup has been started';

  @override
  String get e7SetupManagerMissingAfterLaunch =>
      'Setup manager is missing after launch';

  @override
  String get e7SetupBootstrapCleared => 'Bootstrap state cleared';

  @override
  String get e7SetupInstallingBeta => 'Installing OpenCode 2';

  @override
  String get e7SetupAuthenticationFailed => 'Authentication failed';

  @override
  String e7SetupRuntimeInstallDetail(String runtime, String version) {
    return 'Install $runtime ($version) on this phone using Ubuntu. The app manages this installation and reuses existing Ubuntu files.';
  }

  @override
  String e7SetupReplaceDetail(String installedVersion, String targetVersion) {
    return 'Replace OpenCode $installedVersion with $targetVersion and restart this app’s local server. Existing Ubuntu files are kept.';
  }

  @override
  String get e7SetupUncheckedDetail =>
      'The current installation could not be checked. Continuing may install or update OpenCode 1 on this phone. Existing Ubuntu files are kept. You can check again or connect by address instead.';

  @override
  String get e7SetupUnknownVersion => 'unknown version';

  @override
  String get e7ModelUiClose => 'Close model selector';

  @override
  String get e7ModelUiClearSearch => 'Clear model search';

  @override
  String get e7ModelUiLoadFailed => 'Could not load models';

  @override
  String get e7ModelUiRetry => 'Try again';

  @override
  String get e7ModelUiBasicCatalog =>
      'This server returned a basic catalog. Capability and context details are unavailable.';

  @override
  String get e7ModelUiEditFilters => 'Edit model filters';

  @override
  String get e7ModelUiFilterModels => 'Filter models';

  @override
  String get e7ModelUiFiltered => 'Filtered';

  @override
  String get e7ModelUiFilters => 'Filters';

  @override
  String get e7ModelUiRefresh => 'Refresh models';

  @override
  String get e7ModelUiAnyCapability => 'Any capability';

  @override
  String get e7ModelUiFastModes => 'Fast modes';

  @override
  String get e7ModelUiReasoning => 'Reasoning';

  @override
  String get e7ModelUiLargestContext => 'Largest context';

  @override
  String get e7ModelUiNoneAvailable => 'No models available';

  @override
  String get e7ModelUiFavoritesEmpty => 'Keep your go-to models here';

  @override
  String get e7ModelUiRecentEmpty => 'Your next choice starts here';

  @override
  String get e7ModelUiNoMatches => 'No matching models';

  @override
  String get e7ModelUiConfigureProvider =>
      'Configure a provider on the OpenCode server, then refresh.';

  @override
  String get e7ModelUiFavoritesHint =>
      'Tap the star beside any model to find it here.';

  @override
  String get e7ModelUiRecentHint =>
      'Models you use will appear here, most recent first.';

  @override
  String get e7ModelUiNoFastModes =>
      'No model reports an explicit fast or low-effort mode.';

  @override
  String get e7ModelUiNoMatchesHint =>
      'Try another search, provider, or capability filter.';

  @override
  String get e7ModelUiClearFilters => 'Clear filters';

  @override
  String get e7ModelUiBrowseAll => 'Browse all models';

  @override
  String get e7ModelUiAgent => 'Agent';

  @override
  String get e7ModelUiNoAgents => 'No agents available';

  @override
  String get e7ModelUiServerDefault => 'Server default';

  @override
  String get e7ModelUiProvider => 'Provider';

  @override
  String get e7ModelUiAllProviders => 'All providers';

  @override
  String get e7ModelUiCurrent => 'Current model';

  @override
  String get e7ModelUiUnavailable => 'Unavailable';

  @override
  String get e7ModelUiDeprecated => 'Deprecated';

  @override
  String get e7ModelUiPreview => 'Preview';

  @override
  String get e7ModelUiFavoritesFailed => 'Could not save favorites. Try again.';

  @override
  String get e7ModelUiUseModelMode => 'Use model and mode';

  @override
  String get e7ModelUiUseSession => 'Use for this conversation';

  @override
  String get e7ModelUiUseNewSessions => 'Use for new conversations';

  @override
  String get e7ModelUiTools => 'Tools';

  @override
  String get e7ModelUiAttachments => 'Attachments';

  @override
  String get e7ModelUiDefault => 'Default';

  @override
  String get e7ModelUiSelectionGone =>
      'This choice is no longer available. Refresh models and try again.';

  @override
  String get e7VoiceUiLocalInput => 'Local voice input';

  @override
  String get e7VoiceUiChooseModel => 'Choose a multilingual Whisper INT8 model';

  @override
  String get e7VoiceUiPrivacyDownload =>
      'Audio stays on this device. Transcription is local and audio is discarded after use. The one-time model download requires internet access.';

  @override
  String get e7VoiceUiNoBuiltInMic =>
      'Android reports no built-in microphone. Voice input may still work with a wired or USB microphone.';

  @override
  String get e7VoiceUiLanguage => 'Transcription language';

  @override
  String get e7VoiceUiVerifying => 'Verifying downloaded model';

  @override
  String get e7VoiceUiVerifyChecksum => 'Verifying size and SHA-256…';

  @override
  String get e7VoiceUiCancelDownload => 'Cancel download';

  @override
  String get e7VoiceUiNotNow => 'Not now';

  @override
  String get e7VoiceUiUseModel => 'Use model';

  @override
  String get e7VoiceUiDownload => 'Download';

  @override
  String get e7VoiceUiKeep => 'Keep';

  @override
  String get e7VoiceUiDelete => 'Delete';

  @override
  String get e7VoiceUiDefaultBadge => 'default';

  @override
  String get e7VoiceUiOptionalBadge => 'optional';

  @override
  String get e7VoiceUiInstalledBadge => 'installed';

  @override
  String get e7VoiceUiNotInstalledBadge => 'not installed';

  @override
  String get e7VoiceUiSetupBusy =>
      'Unavailable while model setup is in progress';

  @override
  String get e7VoiceUiSelected => 'Selected';

  @override
  String get e7VoiceUiSelectHint => 'Double tap to select';

  @override
  String get e7VoiceUiDefault => 'Default';

  @override
  String get e7VoiceUiOptional => 'Optional';

  @override
  String get e7VoiceUiInstalled => 'Installed';

  @override
  String get e7VoiceUiRedownload => 'Re-download';

  @override
  String get e7VoiceUiReviewTranscript => 'Review transcript';

  @override
  String get e7VoiceUiOpenSettings => 'Open app settings';

  @override
  String get e7VoiceUiRetry => 'Try again';

  @override
  String get e7VoiceUiStartListening => 'Start listening';

  @override
  String get e7VoiceUiCancel => 'Cancel';

  @override
  String get e7VoiceUiInsert => 'Insert';

  @override
  String get e7VoiceUiInsertSend => 'Insert & send';

  @override
  String get e7VoiceUiStartingMic => 'Starting microphone…';

  @override
  String get e7VoiceUiLoadingModel => 'Loading local model…';

  @override
  String get e7VoiceUiTranscribing => 'Transcribing on this device…';

  @override
  String get e7VoiceUiFinishingCancel => 'Finishing canceled transcription…';

  @override
  String get e7VoiceUiDraftReady => 'Transcript ready to review';

  @override
  String get e7VoiceUiNeedsAttention => 'Voice input needs attention';

  @override
  String get e7VoiceUiReady => 'Ready for local voice input';

  @override
  String get e7VoiceUiModelRequired => 'A local model is required';

  @override
  String get e7VoiceUiDownloading => 'Downloading voice model…';

  @override
  String get e7VoiceUiVerifyingModel => 'Verifying voice model…';

  @override
  String get e7VoiceUiListeningHint =>
      'Listening. Double tap Stop recording when done.';

  @override
  String get e7VoiceUiPrivacy => 'Audio stays on this device';

  @override
  String get e7VoiceUiStopRecording => 'Stop recording';

  @override
  String e7ModelUiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String e7ModelUiContext(String count) {
    return '$count context';
  }

  @override
  String e7ModelUiOutput(String count) {
    return '$count output';
  }

  @override
  String e7ModelUiFavorite(String model) {
    return 'Favorite $model';
  }

  @override
  String e7ModelUiUnfavorite(String model) {
    return 'Remove $model from favorites';
  }

  @override
  String e7ModelUiEffort(String variant, String effort) {
    return '$variant · $effort effort';
  }

  @override
  String get e7ModelUiLoading => 'Loading model catalog';

  @override
  String e7ModelUiCost(String input, String output) {
    return '$input in · $output out /1M';
  }

  @override
  String e7VoiceUiDownloadPercent(int percent) {
    return 'Downloading voice model $percent percent';
  }

  @override
  String e7VoiceUiDownloadProgress(String received, String total) {
    return '$received of $total';
  }

  @override
  String e7VoiceUiSetupFailed(String error) {
    return 'Model setup failed: $error';
  }

  @override
  String e7VoiceUiDeletePack(String model) {
    return 'Delete $model?';
  }

  @override
  String e7VoiceUiDeleteDetail(String size) {
    return 'This removes $size from app-private storage. You can download it again later.';
  }

  @override
  String e7VoiceUiDownloadSize(String size) {
    return '$size download';
  }

  @override
  String e7VoiceUiPackSemantics(
    String model,
    String size,
    String badges,
    String description,
  ) {
    return '$model, $size, $badges. $description';
  }

  @override
  String e7VoiceUiListeningTime(String elapsed, String maximum) {
    return 'Listening $elapsed of $maximum';
  }

  @override
  String e7VoiceUiRecordingCap(int seconds) {
    return 'Up to $seconds s per recording';
  }

  @override
  String get e7VoiceUiLicenses => 'Voice licenses and provenance';

  @override
  String get e7VoiceUiNoticesFailed =>
      'Could not load voice licenses. Try again.';

  @override
  String get e7VoiceUiAuto => 'Auto detect';

  @override
  String get e7VoiceUiEnglish => 'English';

  @override
  String get e7VoiceUiArabic => 'Arabic';

  @override
  String get e7VoiceUiBalanced => 'Balanced';

  @override
  String get e7VoiceUiBalancedDetail =>
      'Recommended quality, storage, and speed tradeoff.';

  @override
  String get e7VoiceUiAccurate => 'High accuracy';

  @override
  String get e7VoiceUiAccurateDetail =>
      'Optional best quality; requires substantially more memory.';

  @override
  String get e7VoiceUiCompact => 'Compact fallback';

  @override
  String get e7VoiceUiCompactDetail =>
      'Fastest and smallest; reduced accuracy in difficult audio.';

  @override
  String get e7VoiceUiUnsupportedAbi =>
      'No bundled voice runtime supports this device ABI.';

  @override
  String get e7VoiceUiPermissionBlocked =>
      'Microphone access is blocked. Allow it in Android app settings.';

  @override
  String get e7VoiceUiPermissionRequired =>
      'Microphone permission is required for local voice input.';

  @override
  String get e7VoiceUiDeviceUnavailable =>
      'Local voice input is unavailable. Stop playback, check microphone settings, and try again.';

  @override
  String get e7VoiceUiInputUnavailable =>
      'Local voice input is unavailable on this platform.';

  @override
  String get e7VoiceUiNoAudio => 'No audio was captured.';

  @override
  String get e7VoiceUiInterrupted => 'Recording was interrupted.';

  @override
  String get e7VoiceUiMicrophoneError =>
      'The microphone reported an error. Check its settings and try again.';

  @override
  String get e7VoiceUiInputFailed => 'Voice input could not finish. Try again.';

  @override
  String get e7VoiceUiTechnicalDetails => 'Technical details';

  @override
  String get e7VoiceUiHttpsRequired =>
      'Voice models may only be downloaded over HTTPS.';

  @override
  String get e7VoiceUiTransportClosed => 'Voice download transport is closed.';

  @override
  String get e7VoiceUiInvalidRedirect =>
      'Voice model download returned an invalid redirect.';

  @override
  String get e7VoiceUiUnsafeRedirect =>
      'Voice model download redirected to a non-HTTPS URL.';

  @override
  String get e7VoiceUiNoResponse => 'Model server returned no response.';

  @override
  String get e7VoiceUiDownloadTimeout =>
      'The model download timed out. Check the connection and try again.';

  @override
  String get e7VoiceUiChecksumFailed =>
      'The downloaded model failed checksum verification. Re-download it.';

  @override
  String get e7VoiceUiVerificationFailed =>
      'The model failed final verification. Re-download it.';

  @override
  String get e7VoiceUiHttpFailed =>
      'The model server rejected the download. Try again.';

  @override
  String get e7VoiceUiLengthFailed =>
      'The model download has an unexpected size. Re-download it.';

  @override
  String get e7VoiceUiIncomplete =>
      'The model download is incomplete. Try again.';

  @override
  String get e7VoiceUiDownloadFailed =>
      'The voice model could not be downloaded. Try again.';

  @override
  String e7VoiceUiMemory(String model, int required, int available) {
    return '$model needs a phone with about $required MB of memory; this one has $available MB.';
  }

  @override
  String e7VoiceUiStorage(String model, String size) {
    return '$model needs $size free, including a safety margin.';
  }

  @override
  String get e7ModelUiProviderFallback => 'a provider';

  @override
  String e7ModelUiProviderPair(String first, String last) {
    return '$first and $last';
  }

  @override
  String e7ModelUiProviderMany(String first, String last) {
    return '$first, and $last';
  }

  @override
  String get e7ModelUiListSeparator => ', ';

  @override
  String e7ModelUiUnloadedProviders(int count, String providers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'OpenCode is signed in to $providers but has not loaded them yet, so their models fail with “Model not found”. Reload to pick up the sign-in.',
      one:
          'OpenCode is signed in to $providers but has not loaded it yet, so its models fail with “Model not found”. Reload to pick up the sign-in.',
    );
    return '$_temp0';
  }

  @override
  String e7SharedDeviceReportedError(String code) {
    return 'This device reported an error ($code).';
  }

  @override
  String get e7SharedOpenCodeUnreachableTryAgain =>
      'OpenCode is unreachable. Try again.';

  @override
  String get chatUiQueueOnlySteeringNeedsOpenCode2 =>
      'Sends after this run finishes. Steering mid-run needs OpenCode 2.';

  @override
  String get approvalsUiMenu => 'Approvals';

  @override
  String get approvalsUiTitle => 'Approvals for this conversation';

  @override
  String get approvalsUiAskTitle => 'Ask each time';

  @override
  String get approvalsUiAskDetail => 'Every permission request waits for you.';

  @override
  String get approvalsUiAutoTitle => 'Approve automatically while connected';

  @override
  String get approvalsUiAutoDetail =>
      'This phone answers each permission request with “Allow once” as it arrives. Nothing is saved as always allowed.';

  @override
  String get approvalsUiInheritTitle => 'Subagents inherit this';

  @override
  String get approvalsUiInheritDetail =>
      'Subagent conversations started by this one follow the same choice unless they have their own.';

  @override
  String get approvalsUiInheritUnavailable =>
      'Available once automatic approval is on.';

  @override
  String get approvalsUiInheritedFrom => 'Inherited from parent conversation';

  @override
  String get approvalsUiInheritedDetail =>
      'This conversation follows its parent’s approvals. Override it to choose for this conversation only.';

  @override
  String get approvalsUiOverride => 'Override for this conversation';

  @override
  String get approvalsUiFollowParent => 'Follow parent again';

  @override
  String get approvalsUiServerRulesNote =>
      'The server’s own deny rules still apply, and automatic approval stops whenever this app disconnects. New conversations always ask.';

  @override
  String get approvalsUiIndicatorOn => 'Approving automatically';

  @override
  String approvalsUiAutoApproved(String action) {
    return 'Auto-approved · $action';
  }

  @override
  String get approvalsUiFailedDetail =>
      'Automatic approval failed. Review this request.';

  @override
  String approvalsUiSaveFailed(String error) {
    return 'Couldn’t save the approval setting: $error';
  }

  @override
  String get approvalsUiOpenSettings => 'Open approval settings';

  @override
  String get approvalsUiIndicatorPaused => 'Auto-approval paused';

  @override
  String get approvalsUiIndicatorPausedDetail => 'Not connected';

  @override
  String approvalsUiRecordTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests approved automatically on this server',
      one: '1 request approved automatically on this server',
      zero: 'Nothing approved automatically on this server yet',
    );
    return '$_temp0';
  }

  @override
  String get handoffUiComputerTitle => 'Continue on computer';

  @override
  String handoffUiComputerIntro(String binary) {
    return 'Run this in a terminal on the computer that runs this server. It opens the same conversation in the $binary interface. Nothing is sent until you type.';
  }

  @override
  String get handoffUiComputerDirectoryNote =>
      'Conversations belong to a project folder, so the command changes into this conversation’s folder first.';

  @override
  String handoffUiComputerVerify(String verified, String binary) {
    return 'Verified against $verified. If your installed version differs, check $binary --help for the --session flag.';
  }

  @override
  String get handoffUiUnavailableDirectory =>
      'The server did not report a project folder for this conversation, so there is no folder to open it in. Reload the conversation and try again.';

  @override
  String get handoffUiUnavailableWorkspace =>
      'This conversation runs inside a cloud environment. Its folder belongs to the environment’s host, so a plain terminal command cannot open it. Export and import the conversation instead.';

  @override
  String get handoffUiUnavailableReference =>
      'This conversation’s reference cannot be placed in a command safely.';

  @override
  String get handoffUiExportHint =>
      'Moving to a different server? Export this conversation as a file and import it there. That carries the transcript itself, not just a pointer to it.';

  @override
  String get handoffUiExportAction => 'Export conversation';

  @override
  String get handoffUiPhoneTitle => 'Open on another phone';

  @override
  String get handoffUiPhoneIntro =>
      'Scan this with OpenCode Mobile on the other phone. The code carries only this saved server’s ID and the conversation ID: no messages, no address, no password. The other phone must already have this server saved.';

  @override
  String get handoffUiPhoneQrLabel =>
      'QR code that opens this conversation on another phone';

  @override
  String get handoffUiPhoneLinkLabel => 'Link';

  @override
  String get handoffUiPhoneCopyLink => 'Copy link';

  @override
  String get handoffUiPhoneLinkCopied => 'Link copied';

  @override
  String get handoffUiPhoneUnavailable =>
      'A link cannot be built for this conversation. Reload the conversation and try again.';

  @override
  String get handoffUiLinkServerMissing =>
      'This server is not saved on this phone. Add it under Servers, then scan the code again.';

  @override
  String get handoffUiLinkOpenServers => 'Open Servers';

  @override
  String get handoffUiLinkDismiss => 'Dismiss';

  @override
  String get handoffUiLinkWaiting =>
      'Opening the conversation once the server connects…';

  @override
  String get handoffUiLinkReentry =>
      'Enter this server’s password again, then scan the code again.';

  @override
  String get handoffUiLinkConnectionFailed =>
      'Could not connect to the saved server. Check it under Servers, then scan the code again.';

  @override
  String get teamUiAccessControls => 'Decisions and controls';

  @override
  String get teamUiAccessReadOnly => 'Read-only';

  @override
  String get teamUiAddAddressHint => 'http://100.x.x.x:8372';

  @override
  String get teamUiAddAddressLabel => 'Address';

  @override
  String get teamUiAddCityLabel => 'City (optional)';

  @override
  String get teamUiAddManually => 'Add manually';

  @override
  String get teamUiAddSubmit => 'Test and turn on';

  @override
  String get teamUiAddTesting => 'Checking the address…';

  @override
  String get teamUiAddTitle => 'Add AI Team host';

  @override
  String get teamUiAddressRequired => 'Enter the host address.';

  @override
  String get teamUiChange => 'Change';

  @override
  String get teamUiCopied => 'Copied';

  @override
  String get teamUiCopy => 'Copy';

  @override
  String get teamUiDisclaimerComputer =>
      'Runs as fast as your computer; keep it awake';

  @override
  String get teamUiDisclaimerPhone =>
      'Android may stop it when the screen is off; slower than a computer';

  @override
  String get teamUiDiscoveryNotNow => 'Not now';

  @override
  String teamUiDiscoveryTitle(String server) {
    return '$server also runs an AI team. Turn it on?';
  }

  @override
  String get teamUiDiscoveryTurnOn => 'Turn on';

  @override
  String get teamUiEditorBody =>
      'If this computer runs Gas City, the app can find it automatically.';

  @override
  String teamUiEditorConfigured(String url) {
    return 'AI Team host: $url';
  }

  @override
  String get teamUiEditorTitle => 'AI Team (optional)';

  @override
  String get teamUiEventStreamClosed => 'Event stream closed';

  @override
  String get teamUiEventStreamConnecting => 'Event stream connecting…';

  @override
  String teamUiEventStreamLive(String seq) {
    return 'Event stream connected · seq $seq';
  }

  @override
  String get teamUiEventStreamLiveNoSeq => 'Event stream connected';

  @override
  String get teamUiEventStreamReconnecting => 'Event stream reconnecting…';

  @override
  String get teamUiFrontLine =>
      'The front is a small helper on the computer that lets the phone answer and steer.';

  @override
  String get teamUiHostGuideDocs =>
      'The full guide with every command is docs/ai-team-host.md in the app\'s repository.';

  @override
  String get teamUiHostGuideIntro =>
      'Everything stays on your Tailscale network; nothing is published to the internet.';

  @override
  String get teamUiHostGuideStep1 =>
      'Install Gas City on the computer: gc, bd and dolt on your PATH.';

  @override
  String get teamUiHostGuideStep2 =>
      'Create a city next to your project and add the project to it: gc init, then gc rig add.';

  @override
  String get teamUiHostGuideStep3 =>
      'Start it with gc start and check that http://127.0.0.1:8372/v0/city/<name>/health answers.';

  @override
  String get teamUiHostGuideStep4 =>
      'Expose port 8372 on the computer\'s Tailscale address, then add it here as http://100.x.x.x:8372 with the city name.';

  @override
  String get teamUiHostGuideTitle => 'Run an AI team on your computer';

  @override
  String get teamUiHostModeComputer => 'Computer';

  @override
  String get teamUiHostModePhone => 'This phone';

  @override
  String get teamUiHow => 'How';

  @override
  String get teamUiKeep => 'Keep';

  @override
  String get teamUiLabelAccess => 'Access';

  @override
  String get teamUiLabelAddress => 'Address';

  @override
  String get teamUiLabelCity => 'City';

  @override
  String get teamUiLabelHost => 'Host';

  @override
  String get teamUiLabelProvider => 'Provider';

  @override
  String get teamUiLabelVersion => 'Version';

  @override
  String get teamUiLearnHow => 'Learn how';

  @override
  String get teamUiNoServer => 'Connect to a server to use plugins.';

  @override
  String get teamUiPluginsHubSubtitle => 'AI Team · Gas City';

  @override
  String get teamUiPluginsTitle => 'Plugins';

  @override
  String get teamUiReadOnlyBody =>
      'You can watch this team from the phone. Answering and steering need the front on the computer.';

  @override
  String get teamUiReasonCityNotRunning => 'team host starting';

  @override
  String get teamUiReasonNotGasCity => 'no AI team found';

  @override
  String get teamUiReasonPlainHttp => 'address is not on Tailscale';

  @override
  String get teamUiReasonReadFailed => 'last read failed';

  @override
  String get teamUiReasonUnreachable => 'host unreachable';

  @override
  String get teamUiRefresh => 'Refresh';

  @override
  String get teamUiRowConnecting => 'On · connecting…';

  @override
  String teamUiRowFound(String server, String version) {
    return 'Found on $server · Gas City $version';
  }

  @override
  String get teamUiRowNotAvailable => 'Not available on this server';

  @override
  String teamUiRowNotAvailableReason(String reason) {
    return 'Not available on this server · $reason';
  }

  @override
  String get teamUiRowOff => 'Off';

  @override
  String get teamUiRowOffAddManually => 'Off · Add manually';

  @override
  String teamUiRowOn(String server) {
    return 'On · $server';
  }

  @override
  String teamUiRowOnReadOnly(String server) {
    return 'On · $server · read-only';
  }

  @override
  String get teamUiRowReconnecting => 'On · reconnecting…';

  @override
  String get teamUiRowTitle => 'AI Team · Gas City';

  @override
  String teamUiRowUnreachable(String minutes) {
    return 'On · host unreachable since $minutes min';
  }

  @override
  String teamUiSavedOn(String server) {
    return 'AI Team is on for $server.';
  }

  @override
  String get teamUiStatusConnected => 'Connected';

  @override
  String get teamUiStatusNotAvailable => 'Not available';

  @override
  String get teamUiStatusOff => 'Off';

  @override
  String get teamUiStatusOn => 'On';

  @override
  String get teamUiStatusProbing => 'Checking the host…';

  @override
  String get teamUiStatusReconnecting => 'Reconnecting…';

  @override
  String get teamUiStatusUnreachable => 'Host unreachable';

  @override
  String get teamUiTailnetRequired =>
      'AI Team works over your Tailscale network or on this device. Use the computer\'s Tailscale address (100.x.x.x or name.ts.net).';

  @override
  String get teamUiTechnicalDetails => 'Technical details';

  @override
  String get teamUiTechnicalLastAnswer => 'Last answer from the host';

  @override
  String get teamUiTermAgent => 'Agent · polecat';

  @override
  String get teamUiTermProject => 'Project · rig';

  @override
  String get teamUiTermRun => 'Run · convoy';

  @override
  String get teamUiTermTeam => 'Team · city';

  @override
  String get teamUiTermWork => 'Work · bead';

  @override
  String get teamUiTermsHeading => 'Terms';

  @override
  String get teamUiTurnOff => 'Turn off';

  @override
  String get teamUiTurnOffBody =>
      'Removes its card, attention items and cached team data from this phone. Nothing changes on the host.';

  @override
  String get teamUiTurnOffFailed =>
      'Turned off, but some cached data could not be removed from this phone.';

  @override
  String teamUiTurnOffTitle(String server) {
    return 'Turn off AI Team for $server?';
  }

  @override
  String get teamUiVerdictCityNotRunning =>
      'The team host is starting. Try again in a moment.';

  @override
  String teamUiVerdictFound(String version, String city) {
    return 'Gas City $version · city $city · read-only';
  }

  @override
  String teamUiVerdictFoundControls(String version, String city) {
    return 'Gas City $version · city $city · decisions and controls';
  }

  @override
  String get teamUiVerdictNotGasCity =>
      'This server doesn\'t run an AI team yet. Set one up on the computer — it takes a few minutes.';

  @override
  String get teamUiVerdictUnreachable =>
      'No answer from this address. Check it, and that the computer is awake and on your Tailscale network.';

  @override
  String get teamUiVersionUnknown => 'unknown';

  @override
  String get teamUiWatchingAndAnswering =>
      'Watching and answering from this phone';

  @override
  String get teamUiWatchingOnly => 'Watching from this phone';

  @override
  String teamUiCardAgentsSummary(
    int total,
    int working,
    int waiting,
    int idle,
    int stopped,
  ) {
    return '$total agents: $working working, $waiting waiting, $idle idle, $stopped stopped';
  }

  @override
  String teamUiCardAgentsWorking(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents working',
      one: '1 agent working',
      zero: 'No agents working',
    );
    return '$_temp0';
  }

  @override
  String teamUiCardCity(String city) {
    return 'city $city';
  }

  @override
  String teamUiCardCompletedRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed runs',
      one: '1 completed run',
    );
    return '$_temp0';
  }

  @override
  String get teamUiCardEmptyHint => 'Start runs from the host for now.';

  @override
  String get teamUiCardEmptyTitle => 'No runs yet.';

  @override
  String get teamUiCardErrorCityNotRunning =>
      'The team host is starting. Try again in a moment.';

  @override
  String get teamUiCardErrorNotGasCity =>
      'This server doesn’t run an AI team yet. Set one up on the computer — it takes a few minutes.';

  @override
  String get teamUiCardErrorPlainHttp =>
      'AI Team works over your Tailscale network or on this device. Use tailscale serve on the computer, then try again.';

  @override
  String get teamUiCardErrorUnreachable =>
      'The team host can’t be reached. AI Team works over your Tailscale network or on this device.';

  @override
  String get teamUiCardHostComputer => 'On the computer';

  @override
  String get teamUiCardHostPhone => 'On this phone';

  @override
  String get teamUiCardLoading => 'Connecting to the team host…';

  @override
  String teamUiCardMoreRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more runs',
      one: '1 more run',
    );
    return '$_temp0';
  }

  @override
  String teamUiCardNeedsYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need you',
      one: '1 needs you',
    );
    return '$_temp0';
  }

  @override
  String get teamUiCardOpen => 'Open';

  @override
  String teamUiCardPercentDone(int percent) {
    return '$percent% done.';
  }

  @override
  String teamUiCardProgressSummary(
    int done,
    int working,
    int blocked,
    int total,
  ) {
    return '$done done, $working working, $blocked blocked of $total';
  }

  @override
  String get teamUiCardRefresh => 'Refresh';

  @override
  String teamUiCardRefreshFailed(String time) {
    return 'Last refresh failed · showing data from $time';
  }

  @override
  String get teamUiCardRetry => 'Try again';

  @override
  String get teamUiCardRunStateBlocked => 'Blocked';

  @override
  String get teamUiCardRunStateCancelled => 'Cancelled';

  @override
  String get teamUiCardRunStateCompleted => 'Done';

  @override
  String get teamUiCardRunStateFailed => 'Failed';

  @override
  String get teamUiCardRunStatePlanning => 'Planning';

  @override
  String get teamUiCardRunStateUnknown => 'Unknown';

  @override
  String get teamUiCardRunStateWaiting => 'Waiting for an agent';

  @override
  String get teamUiCardRunStateWorking => 'Working';

  @override
  String get teamUiCardRunStateWaitingMerge => 'Waiting for merge';

  @override
  String get teamUiCardRunTermBatch => 'convoy';

  @override
  String get teamUiCardRunTermFormula => 'formula';

  @override
  String teamUiCardSentenceBlocked(String title) {
    return '$title is blocked.';
  }

  @override
  String teamUiCardSentenceCancelled(String title) {
    return '$title was cancelled.';
  }

  @override
  String teamUiCardSentenceCompleted(String title) {
    return '$title is done.';
  }

  @override
  String teamUiCardSentenceFailed(String title) {
    return '$title failed.';
  }

  @override
  String teamUiCardSentenceNeedsYou(String title) {
    return '$title is waiting for your decision.';
  }

  @override
  String teamUiCardSentencePlanning(String title) {
    return '$title is being planned.';
  }

  @override
  String teamUiCardSentenceUnknown(String title) {
    return '$title has no reported state.';
  }

  @override
  String teamUiCardSentenceWaiting(String title) {
    return '$title is waiting for an agent.';
  }

  @override
  String teamUiCardSentenceWaitingMerge(String title) {
    return '$title is waiting for the merge agent.';
  }

  @override
  String teamUiCardSentenceWorking(String title) {
    return '$title is being worked on.';
  }

  @override
  String teamUiCardStale(String time) {
    return 'Showing data from $time · host unreachable';
  }

  @override
  String get teamUiCardTitle => 'AI Team · Gas City';

  @override
  String get teamUiHomeAgentNoWork => 'No current work';

  @override
  String get teamUiHomeAgentStateBlocked => 'Blocked';

  @override
  String get teamUiHomeAgentStateCrashed => 'Crashed';

  @override
  String get teamUiHomeAgentStateIdle => 'Idle';

  @override
  String get teamUiHomeAgentStateStopped => 'Stopped';

  @override
  String get teamUiHomeAgentStateUnknown => 'Unknown';

  @override
  String get teamUiHomeAgentStateWaiting => 'Waiting (needs input)';

  @override
  String get teamUiHomeAgentStateWorking => 'Working';

  @override
  String get teamUiHomeAgentsEmpty => 'No agents on this host.';

  @override
  String get teamUiHomeAgentsEmptyHint =>
      'Agents appear here once the host starts them.';

  @override
  String get teamUiHomeChipControls => 'controls';

  @override
  String get teamUiHomeChipReadOnly => 'read-only';

  @override
  String teamUiHomeCompletedGroup(int count) {
    return 'Completed ($count)';
  }

  @override
  String teamUiHomeCompletedToday(int count) {
    return 'Completed today ($count)';
  }

  @override
  String get teamUiHomeFilterActive => 'Active';

  @override
  String get teamUiHomeFilterAll => 'All';

  @override
  String get teamUiHomeFilterBlocked => 'Blocked';

  @override
  String get teamUiHomeFilterCompleted => 'Completed';

  @override
  String get teamUiHomeGateAnswerOnComputer =>
      'Answer this on the computer. The phone can only watch for now.';

  @override
  String get teamUiHomeGateAnswerOnPhone =>
      'Answer this in the host on this phone. The app can only watch for now.';

  @override
  String get teamUiHomeGateClose => 'Close';

  @override
  String get teamUiHomeGateKindChoice => 'Decision';

  @override
  String get teamUiHomeGateKindConfirmation => 'Approval';

  @override
  String get teamUiHomeGateKindFreeText => 'Question';

  @override
  String get teamUiHomeGateKindGateBead => 'Gate';

  @override
  String get teamUiHomeGateKindReviewReady => 'Review ready';

  @override
  String get teamUiHomeGateKindRunFailed => 'Run failed';

  @override
  String get teamUiHomeGateKindUnknown => 'Needs you';

  @override
  String teamUiHomeGateLinkAgent(String name) {
    return 'Agent $name';
  }

  @override
  String teamUiHomeGateLinkRun(String title) {
    return 'Run $title';
  }

  @override
  String teamUiHomeGateLinkWork(String title) {
    return 'Work $title';
  }

  @override
  String get teamUiHomeGateOptions => 'Options';

  @override
  String teamUiHomeHostChip(
    String host,
    String version,
    String city,
    String access,
  ) {
    return '$host · Gas City $version · city $city · $access';
  }

  @override
  String teamUiHomeHostChipNoCity(String host, String version, String access) {
    return '$host · Gas City $version · $access';
  }

  @override
  String get teamUiHomeHostRawHeading => 'Raw values';

  @override
  String get teamUiHomeNeedsYouEmpty => 'Nothing needs you right now.';

  @override
  String get teamUiHomeNeedsYouEmptyHint =>
      'Decisions, failed runs and blocked agents show up here.';

  @override
  String get teamUiHomeRunKindBatch => 'Batch · convoy';

  @override
  String get teamUiHomeRunKindFormula => 'Run · formula';

  @override
  String teamUiHomeRunKindFormulaNamed(String formula) {
    return 'Run · formula $formula';
  }

  @override
  String get teamUiHomeRunNeedsYou => 'Needs you';

  @override
  String teamUiHomeRunProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get teamUiHomeRunsEmptyFiltered => 'No runs match.';

  @override
  String get teamUiHomeRunsEmptyHint =>
      'Try another filter or clear the search.';

  @override
  String get teamUiHomeSearchClear => 'Clear search';

  @override
  String get teamUiHomeSearchHint => 'Search runs by title';

  @override
  String teamUiHomeSegmentAgents(int count) {
    return 'Agents ($count)';
  }

  @override
  String teamUiHomeSegmentNeedsYou(int count) {
    return 'Needs you ($count)';
  }

  @override
  String teamUiHomeSegmentRuns(int count) {
    return 'Runs ($count)';
  }

  @override
  String get teamUiHomeTitle => 'AI Team';

  @override
  String get teamUiRunBack => 'Back';

  @override
  String teamUiRunBatchOf(int total, int done) {
    return 'Batch of $total · $done done';
  }

  @override
  String teamUiRunBlockedByDeps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'waiting on $count other items',
      one: 'waiting on one other item',
    );
    return '$_temp0';
  }

  @override
  String teamUiRunBlockedCause(String title, String cause) {
    return '$title: $cause';
  }

  @override
  String teamUiRunChipBlocked(int count) {
    return 'Blocked $count';
  }

  @override
  String teamUiRunChipWorking(int count) {
    return 'Working $count';
  }

  @override
  String get teamUiRunDetails => 'Details';

  @override
  String teamUiRunElapsedDays(int count) {
    return '$count d';
  }

  @override
  String teamUiRunElapsedHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String teamUiRunElapsedMinutes(int count) {
    return '$count min';
  }

  @override
  String teamUiRunSinceHandoff(String elapsed) {
    return '$elapsed since hand-off';
  }

  @override
  String get teamUiRunLabelFormula => 'Formula';

  @override
  String get teamUiRunLabelId => 'Run id';

  @override
  String get teamUiRunLabelKind => 'Kind';

  @override
  String get teamUiRunLabelLastError => 'Last error';

  @override
  String get teamUiRunLabelProject => 'Project';

  @override
  String get teamUiRunLabelRawState => 'Provider status';

  @override
  String get teamUiRunLabelStarted => 'Started';

  @override
  String get teamUiRunLabelState => 'State';

  @override
  String get teamUiRunLabelTrackedWork => 'Tracked work';

  @override
  String get teamUiRunLabelUpdated => 'Updated';

  @override
  String get teamUiRunMissingHint =>
      'It may have been closed or removed. Refresh to check again.';

  @override
  String get teamUiRunMissingTitle => 'This run is no longer on the host';

  @override
  String get teamUiRunNeedsYou => 'Needs you';

  @override
  String teamUiRunNeedsYouFrom(String name) {
    return '$name needs you';
  }

  @override
  String get teamUiRunProgressNone => 'Nothing counted yet';

  @override
  String teamUiRunProgressSemantics(
    int done,
    int working,
    int blocked,
    int total,
  ) {
    return '$done done, $working working, $blocked blocked, of $total';
  }

  @override
  String get teamUiRunStagesHeading => 'Stages';

  @override
  String get teamUiRunTabAgents => 'Agents';

  @override
  String get teamUiRunTabComingSoon => 'Coming with the next update';

  @override
  String get teamUiRunTabOverview => 'Overview';

  @override
  String get teamUiRunTabTimeline => 'Timeline';

  @override
  String get teamUiRunTabWork => 'Work';

  @override
  String get teamUiRunTermBatch => 'Run · convoy';

  @override
  String get teamUiRunTermFormula => 'Run · formula';

  @override
  String get teamUiRunTermUnknown => 'Run';

  @override
  String teamUiRunTimelineAgentStopped(String name) {
    return '$name stopped';
  }

  @override
  String teamUiRunTimelineAgentWoke(String name) {
    return '$name started';
  }

  @override
  String get teamUiRunTimelineEmpty => 'Nothing has happened yet';

  @override
  String get teamUiRunTimelineEmptyFiltered => 'No events of this kind yet';

  @override
  String get teamUiRunTimelineEmptyFilteredHint => 'Try another filter.';

  @override
  String get teamUiRunTimelineEmptyHint =>
      'Events appear here as the team works on this run.';

  @override
  String get teamUiRunTimelineFilterAgents => 'Agents';

  @override
  String get teamUiRunTimelineFilterAll => 'All';

  @override
  String get teamUiRunTimelineFilterDecisions => 'Decisions';

  @override
  String get teamUiRunTimelineFilterWork => 'Work';

  @override
  String teamUiRunTimelineGateOpened(String title) {
    return 'Needs you: $title';
  }

  @override
  String teamUiRunTimelineGateResolved(String title) {
    return 'Answered: $title';
  }

  @override
  String teamUiRunTimelineJump(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new · Jump to latest',
      one: '1 new · Jump to latest',
    );
    return '$_temp0';
  }

  @override
  String teamUiRunTimelineRunChanged(String state) {
    return 'Run is now $state';
  }

  @override
  String teamUiRunTimelineWorkClosed(String title) {
    return '$title closed';
  }

  @override
  String teamUiRunTimelineWorkCreated(String title) {
    return '$title added';
  }

  @override
  String teamUiRunTimelineWorkUpdated(String title) {
    return '$title updated';
  }

  @override
  String get teamUiAgentActivityEmpty => 'No activity captured yet';

  @override
  String get teamUiAgentActivityEmptyHint =>
      'Tool calls and commands appear here as the session\'s output arrives.';

  @override
  String teamUiAgentContextSemantics(int percent) {
    return 'Context $percent% used';
  }

  @override
  String teamUiAgentContextShort(int percent) {
    return 'ctx $percent%';
  }

  @override
  String get teamUiAgentLabelBranch => 'Branch';

  @override
  String get teamUiAgentLabelContext => 'Context use';

  @override
  String get teamUiAgentLabelHarness => 'Harness';

  @override
  String get teamUiAgentLabelModel => 'Model';

  @override
  String get teamUiAgentLabelName => 'Name';

  @override
  String get teamUiAgentLabelPack => 'Pack';

  @override
  String get teamUiAgentLabelPool => 'Pool';

  @override
  String get teamUiAgentLabelRole => 'Role';

  @override
  String get teamUiAgentLabelSessionAge => 'Session age';

  @override
  String get teamUiAgentLabelSessionId => 'Session';

  @override
  String get teamUiAgentLabelSessionName => 'Session name';

  @override
  String get teamUiAgentLabelWorkDir => 'Working directory';

  @override
  String get teamUiAgentMissingHint =>
      'It may have been recycled. Refresh to check.';

  @override
  String get teamUiAgentMissingTitle => 'This agent is no longer on the host';

  @override
  String get teamUiAgentNeedsYou => 'Needs you';

  @override
  String get teamUiAgentOutputConnecting => 'Connecting to the session…';

  @override
  String get teamUiAgentOutputCopy => 'Copy output';

  @override
  String get teamUiAgentOutputEmpty => 'Nothing yet';

  @override
  String get teamUiAgentOutputEnded =>
      'Session ended · output no longer on the host';

  @override
  String get teamUiAgentOutputFollow => 'Follow';

  @override
  String get teamUiAgentOutputJump => 'Jump to latest';

  @override
  String get teamUiAgentOutputLive => 'Live';

  @override
  String get teamUiAgentOutputTitle => 'Live output';

  @override
  String get teamUiAgentOutputUnavailable =>
      'Live output is not available for this agent';

  @override
  String get teamUiAgentRecyclingSoon => 'Recycling soon · context nearly full';

  @override
  String get teamUiAgentRunEmpty => 'No agents on this run';

  @override
  String get teamUiAgentRunEmptyHint =>
      'Agents appear here while they work on this run\'s items.';

  @override
  String get teamUiAgentSectionActivity => 'Activity';

  @override
  String get teamUiAgentSectionCurrentWork => 'Current work';

  @override
  String get teamUiAgentSectionIdentity => 'Identity';

  @override
  String get teamUiAgentSectionOutput => 'Output';

  @override
  String get teamUiAgentSectionRuntime => 'Runtime';

  @override
  String teamUiAgentSessionAge(String age) {
    return 'Session $age';
  }

  @override
  String teamUiAgentStepMoreLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more lines',
      one: '1 more line',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsCommands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ran $count commands',
      one: 'ran 1 command',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsEdits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'edited $count files',
      one: 'edited 1 file',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsOther(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other tool calls',
      one: '1 other tool call',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsReads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'read $count files',
      one: 'read 1 file',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsSearches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'searched $count times',
      one: 'searched once',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsSemantics(String summary, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$summary, $_temp0';
  }

  @override
  String teamUiAgentStepsTests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ran $count test runs',
      one: 'ran 1 test run',
    );
    return '$_temp0';
  }

  @override
  String get teamUiAgentStepsTitle => 'Tools';

  @override
  String get teamUiAgentTermNoSession => 'Agent';

  @override
  String teamUiAgentTermSession(String id) {
    return 'Agent · session $id';
  }

  @override
  String get teamUiAgentValueUnknown => 'Not reported';

  @override
  String get teamUiAgentWorkBlocked => 'Blocked';

  @override
  String get teamUiAgentWorkUnblocked => 'Nothing blocking it';

  @override
  String get teamUiWorkEmpty => 'No work items yet';

  @override
  String get teamUiWorkEmptyHint => 'Work appears here once the run has items.';

  @override
  String get teamUiWorkGraphFit => 'Fit';

  @override
  String teamUiWorkGraphNodeSemantics(String title, String state) {
    return '$title, $state';
  }

  @override
  String teamUiWorkGraphSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dependency graph of $count work items',
      one: 'Dependency graph of 1 work item',
    );
    return '$_temp0';
  }

  @override
  String teamUiWorkGroupHeader(String state, int count) {
    return '$state · $count';
  }

  @override
  String get teamUiWorkLabelAssignee => 'Assignee';

  @override
  String get teamUiWorkLabelClosedReason => 'Close reason';

  @override
  String get teamUiWorkLabelDependsOn => 'Depends on (ids)';

  @override
  String get teamUiWorkLabelId => 'Work id';

  @override
  String get teamUiWorkLabelLabels => 'Labels';

  @override
  String get teamUiWorkLabelParent => 'Parent';

  @override
  String get teamUiWorkLabelProject => 'Project';

  @override
  String get teamUiWorkLabelRawState => 'Provider status';

  @override
  String get teamUiWorkLabelRun => 'Run id';

  @override
  String get teamUiWorkLabelSession => 'Session id';

  @override
  String get teamUiWorkLabelSessionName => 'Session name';

  @override
  String get teamUiWorkLabelType => 'Type';

  @override
  String get teamUiWorkOwnerNone => 'Unassigned';

  @override
  String teamUiWorkOwnerSemantics(String name) {
    return 'Owner: $name';
  }

  @override
  String get teamUiWorkSheetBlocking => 'Blocks';

  @override
  String get teamUiWorkSheetBranch => 'Branch';

  @override
  String get teamUiWorkSheetClosed => 'Closed';

  @override
  String get teamUiWorkSheetCode => 'Code';

  @override
  String get teamUiWorkSheetCreated => 'Created';

  @override
  String get teamUiWorkSheetDependencies => 'Depends on';

  @override
  String get teamUiWorkSheetDescription => 'Description';

  @override
  String get teamUiWorkSheetMissing =>
      'This work item is no longer on the host.';

  @override
  String get teamUiWorkSheetNoTimestamps => 'The host sent no timestamps.';

  @override
  String get teamUiWorkSheetOpenSession => 'Open session';

  @override
  String get teamUiWorkSheetOutput => 'Output';

  @override
  String teamUiWorkSheetStamp(String date, String clock, String age) {
    return '$date · $clock ($age)';
  }

  @override
  String get teamUiWorkSheetTarget => 'Merge target';

  @override
  String get teamUiWorkSheetTimestamps => 'Timestamps';

  @override
  String get teamUiWorkSheetUpdated => 'Updated';

  @override
  String get teamUiWorkSheetValidation => 'Validation';

  @override
  String get teamUiWorkSheetValidationFailed => 'Failed';

  @override
  String get teamUiWorkSheetValidationPassed => 'Passed';

  @override
  String get teamUiWorkSheetValidationUnknown => 'Result recorded';

  @override
  String get teamUiWorkSheetWorktree => 'Worktree';

  @override
  String get teamUiWorkStateBlocked => 'Blocked';

  @override
  String get teamUiWorkStateCancelled => 'Cancelled';

  @override
  String get teamUiWorkStateCompleted => 'Done';

  @override
  String get teamUiWorkStateFailed => 'Failed';

  @override
  String get teamUiWorkStateNeedsInput => 'Needs input';

  @override
  String get teamUiWorkStateQueued => 'Queued';

  @override
  String get teamUiWorkStateReady => 'Ready';

  @override
  String get teamUiWorkStateReview => 'Review';

  @override
  String get teamUiWorkStateUnknown => 'Unknown';

  @override
  String get teamUiWorkStateWaiting => 'Waiting';

  @override
  String get teamUiWorkStateWorking => 'Working';

  @override
  String teamUiWorkTerm(String id) {
    return 'Work · bead $id';
  }

  @override
  String get teamUiWorkViewGraph => 'Graph';

  @override
  String get teamUiWorkViewList => 'List';

  @override
  String teamUiWorkWaitsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Waits on $count items',
      one: 'Waits on 1 item',
    );
    return '$_temp0';
  }

  @override
  String teamUiUsageChip(String usage) {
    return 'Team today · $usage';
  }

  @override
  String teamUiUsageCostEstimated(String cost) {
    return '$cost est.';
  }

  @override
  String get teamUiUsageRuntimeHint =>
      'Tokens and cost are the whole team\'s today, estimated.';

  @override
  String get teamUiUsageRuntimeLabel => 'Tokens / context / cost';

  @override
  String teamUiUsageTokens(String count) {
    return '$count tokens';
  }

  @override
  String get teamUiGateAnswerOnHost =>
      'Answer this on the host. The phone can only watch for now.';

  @override
  String get teamUiGateAnswerOnHostPhone =>
      'Answer this in the host on this phone. The app can only watch for now.';

  @override
  String get teamUiGateCloseOnHost =>
      'Close this on the host. The phone can only watch for now.';

  @override
  String get teamUiGateCloseOnHostPhone =>
      'Close this in the host on this phone. The app can only watch for now.';

  @override
  String get teamUiGateDescription => 'Description';

  @override
  String get teamUiGateDestructive => 'Destructive';

  @override
  String get teamUiGateFailureAction => 'Recommended action';

  @override
  String get teamUiGateFailureActionAgent =>
      'Restart the agent on the host; it picks the work item up again.';

  @override
  String get teamUiGateFailureActionAuthentication =>
      'Sign in again on the host (provider key or token), then retry the run.';

  @override
  String get teamUiGateFailureActionContext =>
      'Restart the agent with a fresh context on the host; it resumes from the work item.';

  @override
  String get teamUiGateFailureActionDependency =>
      'Install or update the missing dependency on the host, then retry the run.';

  @override
  String get teamUiGateFailureActionExecution =>
      'Read the step log on the host, fix the command, then retry the run.';

  @override
  String get teamUiGateFailureActionInfrastructure =>
      'Check the host and its services, then retry the run.';

  @override
  String get teamUiGateFailureActionMergeConflict =>
      'Resolve the conflict in the worktree on the host, then retry the run.';

  @override
  String get teamUiGateFailureActionTest =>
      'Fix the failing tests on the host, then retry the run.';

  @override
  String get teamUiGateFailureActionUnknown =>
      'Read the error on the host and decide there; the phone cannot act on it yet.';

  @override
  String get teamUiGateFailureAffectedNone => 'No open work item of this run.';

  @override
  String get teamUiGateFailureAffectedWork => 'Affected work';

  @override
  String get teamUiGateFailureClassAgent => 'Agent';

  @override
  String get teamUiGateFailureClassAuthentication => 'Authentication';

  @override
  String get teamUiGateFailureClassContext => 'Context';

  @override
  String get teamUiGateFailureClassDependency => 'Dependency';

  @override
  String get teamUiGateFailureClassExecution => 'Execution';

  @override
  String get teamUiGateFailureClassInfrastructure => 'Infrastructure';

  @override
  String get teamUiGateFailureClassMergeConflict => 'Merge conflict';

  @override
  String get teamUiGateFailureClassTest => 'Test';

  @override
  String get teamUiGateFailureClassUnknown => 'Unknown';

  @override
  String get teamUiGateFailureClassification => 'Classification';

  @override
  String get teamUiGateFailureError => 'Error';

  @override
  String get teamUiGateFailureErrorNone => 'The host sent no error text.';

  @override
  String get teamUiGateFailureRecoverable => 'Recoverable';

  @override
  String get teamUiGateFailureRecoverableNo =>
      'No — something needs changing first';

  @override
  String get teamUiGateFailureRecoverableUnknown => 'Unknown';

  @override
  String get teamUiGateFailureRecoverableYes =>
      'Yes — a retry from the host can recover it';

  @override
  String get teamUiGateGone =>
      'This is no longer waiting on you; it was answered or closed on the host.';

  @override
  String get teamUiGateKindAgentBlocked => 'Agent blocked';

  @override
  String get teamUiGateLabelKind => 'Provider kind';

  @override
  String get teamUiGateLabelRequestId => 'Request id';

  @override
  String get teamUiGateLabelRunId => 'Run id';

  @override
  String get teamUiGateLabelSessionId => 'Session id';

  @override
  String get teamUiGateLabelWorkId => 'Work id';

  @override
  String get teamUiGateNoDescription => 'The host sent no description.';

  @override
  String get teamUiGateReviewOnHost =>
      'Review this on the host. The phone can only watch for now.';

  @override
  String get teamUiGateReviewOnHostPhone =>
      'Review this in the host on this phone. The app can only watch for now.';

  @override
  String teamUiGateTermBead(String kind, String id) {
    return '$kind · bead $id';
  }

  @override
  String teamUiGateTermInteraction(String kind, String id) {
    return '$kind · interaction $id';
  }

  @override
  String teamUiGateTermRun(String kind, String id) {
    return '$kind · run $id';
  }

  @override
  String get teamUiGateUnblocks => 'Unblocks';

  @override
  String get teamUiGateUnblocksNone => 'Nothing waits on this yet.';

  @override
  String get teamUiHostKindDesktop => 'Desktop computer';

  @override
  String get teamUiHostKindDisclaimerLaptop =>
      'Sleep and lid-close pause the team; runs resume on wake';

  @override
  String get teamUiHostKindDisclaimerWsl =>
      'Sleep and lid-close pause the team; runs resume on wake. WSL also stops when its last terminal closes.';

  @override
  String get teamUiHostKindHint =>
      'Only changes the reminder shown with the team.';

  @override
  String get teamUiHostKindLabel => 'Kind of computer';

  @override
  String get teamUiHostKindLaptop => 'Laptop';

  @override
  String get teamUiHostKindWsl => 'Windows (WSL)';

  @override
  String get teamUiReceiptSent => 'Sent · waiting for the host to confirm';

  @override
  String get teamUiReceiptAnswered => 'Answered';

  @override
  String get teamUiReceiptUnconfirmed =>
      'Sent, unconfirmed — check on the host before re-sending';

  @override
  String get teamUiGateAnswerSend => 'Send';

  @override
  String get teamUiGateAnswerApprove => 'Approve';

  @override
  String get teamUiGateAnswerDeny => 'Deny';

  @override
  String get teamUiGateAnswerMarkDone => 'Mark done';

  @override
  String get teamUiGateAnswerHint => 'Type your answer';

  @override
  String get teamUiGateAnswerOptionsHint => 'Choose one option, then send.';

  @override
  String get teamUiGateAnswerRunRetry => 'Try again';

  @override
  String teamUiGateAnswerRunRetryDetail(String work, String agent) {
    return 'Sends $work to $agent again.';
  }

  @override
  String get teamUiGateAnswerRunAgent => 'Restart or reassign';

  @override
  String get teamUiGateAnswerRunLogs => 'View logs';

  @override
  String get teamUiGateAnswerRunCancel => 'Stop work';

  @override
  String get teamUiGateAnswerRetry => 'Try again';

  @override
  String get teamUiGateAnswerTryAgain => 'Try again';

  @override
  String teamUiGateAnswerRejected(String message) {
    return 'Not accepted: $message';
  }

  @override
  String get teamUiGateAnswerRejectedNoMessage =>
      'The host did not accept this answer.';

  @override
  String get teamUiGateAnswerChipSent => 'Sent';

  @override
  String get teamUiGateAnswerChipUnconfirmed => 'Unconfirmed';

  @override
  String get teamUiGateAnswerChipRejected => 'Not accepted';

  @override
  String get teamUiGateAnswerChipUnconfirmedSemantics =>
      'Unconfirmed, open to retry';

  @override
  String get teamUiGateAnswerConfirmDenyTitle => 'Deny this request?';

  @override
  String get teamUiGateAnswerConfirmDenyBody =>
      'The agent is told no and goes on without it.';

  @override
  String get teamUiGateAnswerConfirmApproveTitle =>
      'Approve this destructive action?';

  @override
  String get teamUiGateAnswerConfirmApproveBody =>
      'The host marks this as destructive. It cannot be undone from the phone.';

  @override
  String get teamUiGateAnswerConfirmCancelRunTitle => 'Stop this work?';

  @override
  String get teamUiGateAnswerConfirmCancelRunBody =>
      'The run stops and its open work stays as it is.';

  @override
  String get teamUiGateAnswerConfirmKeep => 'Keep';

  @override
  String get teamUiGateAnswerNotificationOpening =>
      'Opening the decision once the AI Team connects…';

  @override
  String get teamUiGateAnswerRunGone => 'This run is no longer on the host.';

  @override
  String get teamUiControlSectionTitle => 'Controls';

  @override
  String get teamUiControlMessage => 'Message';

  @override
  String get teamUiControlNudge => 'Nudge';

  @override
  String get teamUiControlPause => 'Pause';

  @override
  String get teamUiControlResume => 'Resume';

  @override
  String get teamUiControlStop => 'Stop';

  @override
  String get teamUiControlRestart => 'Restart';

  @override
  String get teamUiControlReassign => 'Reassign work…';

  @override
  String get teamUiControlCreateWork => 'Task sent to an agent';

  @override
  String teamUiControlMessageTitle(String agent) {
    return 'Message $agent';
  }

  @override
  String get teamUiControlMessageHint => 'Tell the agent what to do next';

  @override
  String get teamUiControlMessageSend => 'Send';

  @override
  String teamUiControlStopConfirmTitle(String agent) {
    return 'Stop $agent?';
  }

  @override
  String get teamUiControlStopConfirmBody =>
      'Its session ends now. Its work stays where it is; the host can wake it again later.';

  @override
  String get teamUiControlStopConfirmAction => 'Stop agent';

  @override
  String teamUiControlRestartConfirmTitle(String agent) {
    return 'Restart $agent?';
  }

  @override
  String get teamUiControlRestartConfirmBody =>
      'Its session stops and starts again. The agent loses what it had in context and picks its work up from the host.';

  @override
  String get teamUiControlRestartConfirmAction => 'Restart agent';

  @override
  String get teamUiControlKeep => 'Keep going';

  @override
  String teamUiControlReassignTitle(String agent) {
    return 'Reassign work to $agent';
  }

  @override
  String get teamUiControlReassignHint =>
      'Ready work on this host. The item you pick moves onto this agent.';

  @override
  String get teamUiControlReassignEmpty => 'Nothing is ready to assign.';

  @override
  String get teamUiControlReceiptSent => 'Sent';

  @override
  String get teamUiControlReceiptConfirmed => 'Confirmed';

  @override
  String get teamUiControlReceiptUnconfirmed => 'Unconfirmed';

  @override
  String get teamUiControlReceiptRefused => 'Refused';

  @override
  String teamUiControlReceiptLine(String control, String state) {
    return '$control · $state';
  }

  @override
  String get teamUiControlReceiptRetry => 'Try again';

  @override
  String get teamUiControlMoreActions => 'More actions';

  @override
  String get teamUiControlCancelRun => 'Stop run';

  @override
  String get teamUiControlCloseBatch => 'Close batch';

  @override
  String get teamUiControlCancelRunConfirmTitle => 'Stop this run?';

  @override
  String get teamUiControlCancelRunConfirmBody =>
      'Running steps stop; finished work stays. The phone cannot undo this.';

  @override
  String get teamUiControlCloseBatchConfirmTitle => 'Close this batch?';

  @override
  String get teamUiControlCloseBatchConfirmBody =>
      'The batch closes on the host. Its open work items stay open for another batch.';

  @override
  String get teamUiStartRunFab => 'Start a run';

  @override
  String get teamUiStartRunTitle => 'Start a run';

  @override
  String get teamUiStartRunObjectiveLabel => 'Objective';

  @override
  String get teamUiStartRunObjectiveHint =>
      'What should the team achieve? One outcome, in your words.';

  @override
  String get teamUiStartRunObjectiveEmpty => 'Write an objective first.';

  @override
  String get teamUiStartRunProjectLabel => 'Project';

  @override
  String get teamUiStartRunProjectAny => 'Let the planner choose';

  @override
  String get teamUiStartRunSupervisionLabel => 'Supervision';

  @override
  String get teamUiStartRunSupervisionHigh => 'High';

  @override
  String get teamUiStartRunSupervisionHighHint =>
      'The team asks before every decision, before tests that change state and before any merge.';

  @override
  String get teamUiStartRunSupervisionBalanced => 'Balanced';

  @override
  String get teamUiStartRunSupervisionBalancedHint =>
      'The team decides routine matters itself and asks before merges, on failures and on design choices.';

  @override
  String get teamUiStartRunSupervisionAutonomous => 'Autonomous';

  @override
  String get teamUiStartRunSupervisionAutonomousHint =>
      'The team works to completion inside the host\'s boundaries and asks only when it cannot continue.';

  @override
  String get teamUiStartRunPlannerLabel => 'Planner';

  @override
  String get teamUiStartRunPlannerMayor => 'Mayor';

  @override
  String get teamUiStartRunPlannerHint =>
      'Set on the host; the phone shows it and does not choose it.';

  @override
  String get teamUiStartRunSend => 'Send to planner';

  @override
  String get teamUiStartRunPlannerOffTitle =>
      'The planner (Mayor) is off on this host';

  @override
  String get teamUiStartRunPlannerOffBody =>
      'Wake it on the host or switch it to the full profile, then come back.';

  @override
  String get teamUiStartRunPlannerMissingTitle => 'No planner on this host';

  @override
  String get teamUiStartRunPlannerMissingBody =>
      'The Gas Town pack with its Mayor is not running here. The host guide shows how to enable it.';

  @override
  String get teamUiStartRunHostGuide => 'Host guide';

  @override
  String get teamUiStartRunWaking => 'Waking the planner…';

  @override
  String get teamUiStartRunDirectIntro =>
      'The planner is off on this host. Give one task straight to the project\'s agent.';

  @override
  String get teamUiStartRunDirectTitle => 'Task';

  @override
  String get teamUiStartRunDirectTitleHint =>
      'One line: what should the agent do?';

  @override
  String get teamUiStartRunDirectTitleRequired => 'Write a task first.';

  @override
  String get teamUiStartRunDirectDetails => 'Details (optional)';

  @override
  String get teamUiStartRunDirectSend => 'Send to an agent';

  @override
  String teamUiStartRunDirectRefused(String reason) {
    return 'The host refused the task: $reason';
  }

  @override
  String get teamUiStartRunPlanning => 'Planning… (Mayor)';

  @override
  String get teamUiStartRunPlanningHint =>
      'The planner is turning the objective into work. The run appears in this list once it has.';

  @override
  String get teamUiStartRunStillPlanning =>
      'Still planning — check the planner\'s output';

  @override
  String get teamUiStartRunUnconfirmed =>
      'Sent, unconfirmed — check the planner\'s output before sending again';

  @override
  String teamUiStartRunRefused(String reason) {
    return 'The host refused the objective: $reason';
  }

  @override
  String get teamUiStartRunPlannerOutput => 'Planner output';

  @override
  String get teamUiStartRunDismiss => 'Dismiss';

  @override
  String teamUiStartRunSentAt(String time) {
    return 'Sent $time';
  }

  @override
  String get teamUiMergeTitleReady => 'Ready to merge';

  @override
  String get teamUiMergeTitleNotReady => 'Not ready to merge';

  @override
  String get teamUiMergeTitleMerged => 'Merged';

  @override
  String teamUiMergeRequest(String id) {
    return 'merge request $id';
  }

  @override
  String get teamUiMergeLineWork => 'Work items';

  @override
  String get teamUiMergeLineTests => 'Tests';

  @override
  String get teamUiMergeLineBuild => 'Build';

  @override
  String get teamUiMergeLineReview => 'Review';

  @override
  String get teamUiMergeLineConflicts => 'No conflicts';

  @override
  String get teamUiMergeLineAcceptance => 'Acceptance criteria';

  @override
  String teamUiMergeFiles(int files, int additions, int deletions) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files · +$additions / −$deletions',
      one: '1 file · +$additions / −$deletions',
      zero: 'No file changes',
    );
    return '$_temp0';
  }

  @override
  String get teamUiMergeReviewChanges => 'Review changes';

  @override
  String get teamUiMergeApprove => 'Approve request';

  @override
  String get teamUiMergeApproveTitle => 'Approve this merge request?';

  @override
  String get teamUiMergeApproveMessage =>
      'Your approval is recorded on the host. Merging is a separate step.';

  @override
  String teamUiMergeApprovedBy(String login) {
    return 'Approved by $login';
  }

  @override
  String get teamUiMergeMerge => 'Merge';

  @override
  String get teamUiMergeConfirmStep => 'Confirm merge';

  @override
  String get teamUiMergeArmedHint => 'Tap again to continue';

  @override
  String teamUiMergeConfirmTitle(String branch) {
    return 'Merge into $branch?';
  }

  @override
  String get teamUiMergeConfirmMessage =>
      'This cannot be undone from the phone';

  @override
  String teamUiMergeConfirmAction(String branch) {
    return 'Merge into $branch';
  }

  @override
  String teamUiMergeDisabledReason(String line, String detail) {
    return 'Merge is off: $line — $detail';
  }

  @override
  String teamUiMergeBoundary(String text) {
    return 'Host boundary: $text';
  }

  @override
  String teamUiMergeRefused(String text) {
    return 'The host refused: $text';
  }

  @override
  String teamUiMergeMerged(String branch, String commit) {
    return 'Merged into $branch · $commit';
  }

  @override
  String teamUiMergeAlready(String branch) {
    return 'Already on $branch';
  }

  @override
  String teamUiMergeUnavailable(String reason) {
    return 'Merge readiness unavailable: $reason';
  }

  @override
  String get teamUiMergeNoRoles => 'The host has no merge roles for this run';

  @override
  String get teamUiMergeLoading => 'Checking merge readiness…';

  @override
  String get teamUiMergePending => 'running on the host';

  @override
  String get teamUiMergeChangesTitle => 'Changes';

  @override
  String get teamUiMergeChangesEmpty => 'No file changes reported by the host';

  @override
  String get teamUiMergeChangesWork => 'Work items';

  @override
  String teamUiMergeChangeCounts(int additions, int deletions) {
    return '+$additions / −$deletions';
  }

  @override
  String get teamUiMergeSent => 'Sent · waiting for the host to confirm';

  @override
  String get teamUiMergeApproveConfirmed => 'Approval recorded';

  @override
  String teamUiPolicySupervision(String level) {
    return 'Supervision · $level';
  }

  @override
  String get teamUiPolicyBoundariesLabel => 'Boundaries';

  @override
  String get teamUiPolicyBoundariesNone => 'No boundaries set on the host';

  @override
  String get teamUiPolicyFromHost => 'Set on the host · read-only here';

  @override
  String teamUiPolicyRig(String rig) {
    return 'for $rig';
  }

  @override
  String teamUiPolicySemantics(String level, String boundaries) {
    return 'Supervision $level. Boundaries: $boundaries';
  }

  @override
  String teamUiHomeUpkeepToggle(int count) {
    return 'Show team upkeep ($count)';
  }

  @override
  String get teamUiHomeUpkeepHint =>
      'Patrols and chores the host runs for itself';

  @override
  String teamUiHomeSuspendedGroup(int count) {
    return 'Suspended on the host ($count)';
  }

  @override
  String teamUiHomeSegmentAgentsOff(int count, int off) {
    return 'Agents ($count · $off off)';
  }

  @override
  String teamUiHomeHostChipHost(String host, String kind) {
    return '$host · $kind';
  }

  @override
  String get teamUiRunLabelRawTitle => 'Provider title';

  @override
  String get teamUiCycleStepRouted => 'Routed';

  @override
  String get teamUiCycleStepAgentStarting => 'Agent starting';

  @override
  String get teamUiCycleStepClaimed => 'Claimed';

  @override
  String get teamUiCycleStepWorking => 'Working';

  @override
  String get teamUiCycleStepPushed => 'Pushed';

  @override
  String get teamUiCycleStepHandedToMerge => 'Handed to merge';

  @override
  String get teamUiCycleStepMerged => 'Merged';

  @override
  String get teamUiCycleWaitingForAgent =>
      'Waiting for an agent · usually 1–5 min';

  @override
  String teamUiCycleCurrent(String step, String time) {
    return '$step · since $time';
  }

  @override
  String teamUiCycleSince(String time) {
    return 'since $time';
  }

  @override
  String teamUiCycleSemantics(
    int position,
    int total,
    String step,
    String time,
  ) {
    return 'Step $position of $total, $step, since $time';
  }

  @override
  String teamUiCycleSemanticsNoTime(int position, int total, String step) {
    return 'Step $position of $total, $step';
  }

  @override
  String teamUiCycleSemanticsMerged(int total, String time) {
    return 'All $total steps done, merged at $time';
  }

  @override
  String get teamUiCycleStallHostNotStarted =>
      'The host has not started an agent yet';

  @override
  String get teamUiCycleStallAgentCannotStart =>
      'The agent could not start on the host';

  @override
  String get teamUiCycleStallProviderLimit =>
      'The model provider reached its usage limit';

  @override
  String get teamUiCycleStallWorkingLong =>
      'Still working — check the agent\'s output';

  @override
  String get teamUiCycleStallMergeWaiting => 'Waiting for the merge agent';

  @override
  String get teamUiCycleActionHow => 'How the host dispatches';

  @override
  String get teamUiCycleActionOpenOutput => 'Open agent output';

  @override
  String get teamUiCycleActionNudgeRefinery => 'Nudge refinery';

  @override
  String get teamUiCycleHowLine1 =>
      'The host checks for new work about once a minute and routes it to an agent pool.';

  @override
  String get teamUiCycleHowLine2 =>
      'A patrol every 30 seconds wakes an agent within its wake budget; the agent\'s harness takes 5–10 seconds to start.';

  @override
  String get teamUiCycleHowLine3 =>
      'The first model turn takes 10–60 seconds before the agent claims the work, so 2–6 minutes from routed to claimed is normal.';

  @override
  String get teamUiCycleHowClose => 'Got it';

  @override
  String get termuxStorageTitle => 'Storage on this phone';

  @override
  String termuxStorageRowUsed(String size) {
    return '$size used';
  }

  @override
  String get termuxStorageRowNotScanned => 'Not scanned yet';

  @override
  String get termuxStorageRowScanning => 'Measuring…';

  @override
  String get termuxStorageScanAction => 'Scan storage';

  @override
  String get termuxStorageRescanAction => 'Scan again';

  @override
  String get termuxStorageIntro =>
      'See the storage used by Termux, including the local server and other tools. Expand a category to inspect it. Only selected regenerable caches can be cleaned here; projects, team data, sign-ins and conversation history stay in place.';

  @override
  String get termuxStorageScanning => 'Measuring storage';

  @override
  String get termuxStorageScanningDetail =>
      'Large caches take a minute or two. You can leave this screen; the scan keeps going.';

  @override
  String get termuxStorageCancel => 'Stop scan';

  @override
  String get termuxStorageCancelled => 'Scan stopped';

  @override
  String get termuxStorageFailed => 'The scan did not finish. Try again.';

  @override
  String termuxStorageTotal(String size) {
    return '$size measured in Termux';
  }

  @override
  String termuxStorageDeletableTotal(String size) {
    return '$size can be cleaned';
  }

  @override
  String get termuxStorageScannedJustNow => 'Scanned just now';

  @override
  String termuxStorageScannedMinutesAgo(int minutes) {
    return 'Scanned $minutes min ago';
  }

  @override
  String termuxStorageScannedHoursAgo(int hours) {
    return 'Scanned $hours h ago';
  }

  @override
  String get termuxStorageCatBuildCaches => 'Build caches';

  @override
  String get termuxStorageNoteBuildCaches =>
      'Gradle caches and npm’s downloaded content cache only. Downloads may be needed again, so offline builds can be affected. Stop builds and package installs before cleaning.';

  @override
  String get termuxStorageCatAgentScratch => 'Agent scratch';

  @override
  String get termuxStorageNoteAgentScratch =>
      'Temporary folders may contain unfinished work or files used by other tools. Their sizes are shown for reference; they cannot be removed here.';

  @override
  String get termuxStorageCatProjectBuildOutputs =>
      'Folders with build-related names';

  @override
  String get termuxStorageNoteProjectBuildOutputs =>
      'Folders named build, .dart_tool, node_modules or target may also contain your files. Names alone cannot prove they are disposable, so they cannot be removed here.';

  @override
  String get termuxStorageCatToolchains => 'Toolchains';

  @override
  String get termuxStorageNoteToolchains =>
      'Android SDK, Java and Flutter installations. These may support other projects and cannot be removed here.';

  @override
  String get termuxStorageCatAiTeam => 'AI Team';

  @override
  String get termuxStorageNoteAiTeam =>
      'Team folders, databases and tools may contain work you need to keep. They cannot be removed here, even when the team is stopped.';

  @override
  String get termuxStorageCatOpenCode => 'OpenCode itself';

  @override
  String get termuxStorageNoteOpenCode =>
      'The server, its sign-ins and conversation history. Not removed from here; conversations have their own screen.';

  @override
  String get termuxStorageCatProjects => 'Projects (your files)';

  @override
  String get termuxStorageNoteProjects =>
      'Listed so you can see their size. Never removed from here.';

  @override
  String get termuxStorageWillRemove => 'What Clean removes';

  @override
  String get termuxStorageNothingHere => 'Nothing here';

  @override
  String get termuxStorageNotDeletable => 'Not removed from here';

  @override
  String get termuxStorageClean => 'Clean';

  @override
  String termuxStorageCleanSemantics(String category, String size) {
    return 'Clean $category, $size';
  }

  @override
  String termuxStorageCleanConfirmTitle(String size, String category) {
    return 'Delete $size of $category?';
  }

  @override
  String get termuxStorageCleanConfirmBody =>
      'Delete only the listed Gradle and npm content caches? Downloads may be needed again and offline builds can be affected. Stop builds and package installs first. Scan again afterward to update the measured sizes.';

  @override
  String termuxStorageCleanConfirm(String size) {
    return 'Delete $size';
  }

  @override
  String get termuxStorageKeep => 'Keep';

  @override
  String get termuxStorageCleaning => 'Deleting…';

  @override
  String termuxStorageFreed(String size) {
    return 'Removed $size';
  }

  @override
  String get termuxStorageFreedNothing => 'Nothing was removed';

  @override
  String termuxStorageInUse(String process) {
    return 'In use by $process. Stop it under Running now first.';
  }

  @override
  String termuxStorageRefusedCount(int count) {
    return '$count paths were left in place';
  }

  @override
  String termuxStorageProjectBuild(String size, String build) {
    return '$size · $build in build-related folders';
  }

  @override
  String get termuxStorageOpenRunning => 'Open Running now';

  @override
  String termuxStorageBytesGb(String value) {
    return '$value GB';
  }

  @override
  String termuxStorageBytesMb(String value) {
    return '$value MB';
  }

  @override
  String termuxStorageBytesKb(String value) {
    return '$value KB';
  }

  @override
  String termuxStorageBytesB(String value) {
    return '$value B';
  }

  @override
  String get termuxStorageOnThisPhone => 'On this phone';

  @override
  String get termuxStorageReadFailed => 'Could not read the storage scan.';

  @override
  String get termuxProcsTitle => 'Running now';

  @override
  String termuxProcsRowSubtitle(int count, String cpu) {
    return '$count processes · CPU $cpu%';
  }

  @override
  String get termuxProcsRowLoading => 'Checking…';

  @override
  String get termuxProcsRowUnavailable => 'Not available right now';

  @override
  String get termuxProcsRefresh => 'Refresh';

  @override
  String get termuxProcsAutoRefresh => 'Refreshes every 10 seconds while open';

  @override
  String get termuxProcsGroupOpenCode => 'OpenCode server';

  @override
  String get termuxProcsGroupAiTeam => 'AI Team';

  @override
  String get termuxProcsGroupBuild => 'Build daemons';

  @override
  String get termuxProcsGroupOrphans => 'Orphans';

  @override
  String get termuxProcsGroupOther => 'Other';

  @override
  String get termuxProcsGroupOpenCodeHint => 'Managed from On this phone';

  @override
  String get termuxProcsOrphansHint =>
      'Helpers whose parent is gone, or that keep burning CPU with nothing waiting on them. Stopping them is safe.';

  @override
  String get termuxProcsStopGroup => 'Stop all';

  @override
  String termuxProcsStopGroupTitle(String group) {
    return 'Stop every process in $group?';
  }

  @override
  String termuxProcsStopGroupBody(int count) {
    return '$count processes get a polite stop, then a forced one after 5 seconds.';
  }

  @override
  String termuxProcsStopConfirm(int count) {
    return 'Stop $count';
  }

  @override
  String get termuxProcsStop => 'Stop';

  @override
  String termuxProcsStopSemantics(String name) {
    return 'Stop $name';
  }

  @override
  String termuxProcsStopOneTitle(String name) {
    return 'Stop $name?';
  }

  @override
  String get termuxProcsStopOneBody =>
      'It gets a polite stop, then a forced one after 5 seconds.';

  @override
  String get termuxProcsKeep => 'Keep';

  @override
  String get termuxProcsProtected => 'Protected · open On this phone';

  @override
  String termuxProcsOrphanParentGone(String elapsed) {
    return 'Its parent is gone · running for $elapsed';
  }

  @override
  String termuxProcsOrphanCpu(String cpu) {
    return '$cpu of CPU with no owner';
  }

  @override
  String termuxProcsStats(String cpu, String memory, String elapsed) {
    return 'CPU $cpu% · $memory · $elapsed';
  }

  @override
  String get termuxProcsStopping => 'Stopping…';

  @override
  String termuxProcsStopped(int count) {
    return 'Stopped $count';
  }

  @override
  String termuxProcsStoppedForced(int count, int forced) {
    return 'Stopped $count ($forced needed a forced stop)';
  }

  @override
  String termuxProcsRemaining(int count) {
    return '$count would not stop';
  }

  @override
  String termuxProcsRefused(int count) {
    return '$count protected, not stopped';
  }

  @override
  String get termuxProcsEmpty => 'Nothing is running in the phone server';

  @override
  String get termuxProcsFailed => 'Could not read the process list.';

  @override
  String get termuxProcsAttentionLine =>
      'Something is still running on this phone';

  @override
  String termuxProcsAttentionDetail(String name, String cpu) {
    return '$name has used $cpu of CPU with nothing waiting on it';
  }

  @override
  String get termuxProcsCommand => 'Command';

  @override
  String get termuxProcsFolder => 'Folder';

  @override
  String termuxProcsPid(int pid, int ppid) {
    return 'PID $pid · parent $ppid';
  }

  @override
  String termuxProcsDurationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String termuxProcsDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String termuxProcsDurationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String termuxProcsMemoryMb(int mb) {
    return '$mb MB';
  }

  @override
  String get teamUiPhoneOptionalTag => 'Optional · experimental';

  @override
  String get teamUiPhoneOfferTitle => 'Also run an AI team on this phone';

  @override
  String get teamUiPhoneOfferBody =>
      'Lets several coding agents work on your project while you supervise from Work. Uses the same Linux environment you just set up.';

  @override
  String teamUiPhoneOfferSize(int size) {
    return 'Downloads about $size MB (Gas City, beads and Dolt, built for Android).';
  }

  @override
  String get teamUiPhoneOfferWarning =>
      'Keep Termux open or hold its wake lock while the team works; Android may stop it in the background. Nothing is lost; runs resume when you start it again.';

  @override
  String get teamUiPhoneSkip => 'Skip for now';

  @override
  String get teamUiPhoneSetUp => 'Set up AI team';

  @override
  String get teamUiPhoneStepDownload => 'Download & verify';

  @override
  String get teamUiPhoneStepPackages => 'Install prerequisites';

  @override
  String get teamUiPhoneStepCity => 'Create a city next to the project';

  @override
  String get teamUiPhoneStepStart => 'Start the supervisor on this phone';

  @override
  String get teamUiPhoneStepConnect => 'Connect';

  @override
  String get teamUiPhoneLeaveNote =>
      'You can leave this screen and return to check progress.';

  @override
  String teamUiPhoneProjectLine(String path) {
    return 'Project: $path';
  }

  @override
  String get teamUiPhoneChooseProjectTitle => 'Choose a project';

  @override
  String get teamUiPhoneChooseProjectBody =>
      'The team works on one project folder of the phone server. The first agent commits to a git origin created next to it.';

  @override
  String teamUiPhoneNoProjects(String directory) {
    return 'No project folder yet. Name one and it will be created under $directory.';
  }

  @override
  String get teamUiPhoneNewFolderLabel => 'Folder name';

  @override
  String get teamUiPhoneCreateAndContinue => 'Create and continue';

  @override
  String get teamUiPhoneContinue => 'Continue';

  @override
  String get teamUiPhoneSetupRunning => 'Setting up the AI team';

  @override
  String get teamUiPhoneSuccessTitle => 'AI team is running on this phone';

  @override
  String teamUiPhoneAgentsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents ready',
      one: '1 agent ready',
      zero: 'no agents yet',
    );
    return '$_temp0';
  }

  @override
  String get teamUiPhoneOpenWorkspace => 'Open Work';

  @override
  String get teamUiPhoneRetry => 'Try again';

  @override
  String get teamUiPhoneFailedTitle => 'The AI team could not be set up.';

  @override
  String teamUiPhoneFailedChecksum(String name) {
    return 'The downloaded $name did not match the checksum this build pins, so it was not installed. Nothing from it was kept; check the network and try again.';
  }

  @override
  String get teamUiPhoneFailedUnsupportedArch =>
      'This phone\'s processor is not 64-bit ARM, which the team runtime needs.';

  @override
  String get teamUiPhoneFailedDownload =>
      'The download did not finish. Check the connection and try again.';

  @override
  String get teamUiPhoneFailedPackages =>
      'Termux could not install the prerequisites (libicu, git, jq, tmux). The output below says which.';

  @override
  String get teamUiPhoneFailedProject =>
      'The project folder is missing or is not a git repository.';

  @override
  String get teamUiPhoneFailedCity =>
      'Gas City could not create the city. The output below says why.';

  @override
  String get teamUiPhoneFailedSupervisorExited =>
      'The supervisor stopped right after starting. The output below says why.';

  @override
  String teamUiPhoneFailedHealth(String url) {
    return 'The supervisor started but never answered on $url.';
  }

  @override
  String get teamUiPhoneFailedInterrupted =>
      'The setup stopped before it finished. Android may have stopped Termux while the app was away; nothing is lost.';

  @override
  String teamUiPhoneFailedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get teamUiPhoneDispatchFailed =>
      'Termux did not start the step. Open Termux once, then try again.';

  @override
  String get teamUiPhoneSectionTitle => 'On this phone';

  @override
  String get teamUiPhoneStatusChecking => 'Checking…';

  @override
  String get teamUiPhoneStatusNotInstalled => 'Not installed';

  @override
  String get teamUiPhoneStatusInstalled => 'Installed · no city yet';

  @override
  String get teamUiPhoneStatusStopped => 'Stopped';

  @override
  String get teamUiPhoneStatusStarting => 'Starting…';

  @override
  String get teamUiPhoneStatusStopping => 'Stopping…';

  @override
  String teamUiPhoneStatusWorking(String verb) {
    return 'Working… ($verb)';
  }

  @override
  String teamUiPhoneStatusRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Running · $count agents',
      one: 'Running · 1 agent',
      zero: 'Running',
    );
    return '$_temp0';
  }

  @override
  String get teamUiPhoneStatusFailed => 'Not running · the last step failed';

  @override
  String teamUiPhoneStatusUnreachable(String url) {
    return 'Started, but not answering on $url';
  }

  @override
  String get teamUiPhoneStatusUnknown => 'Status could not be read';

  @override
  String teamUiPhoneVersions(String gc, String bd, String dolt) {
    return 'gc $gc · bd $bd · dolt $dolt';
  }

  @override
  String get teamUiPhoneStart => 'Start';

  @override
  String get teamUiPhoneStop => 'Stop';

  @override
  String get teamUiPhoneStopTitle => 'Stop the team on this phone?';

  @override
  String get teamUiPhoneStopBody =>
      'Running agents stop where they are. Nothing is lost; runs resume when you start it again.';

  @override
  String get teamUiPhoneStopConfirm => 'Stop team';

  @override
  String get teamUiPhoneKilled =>
      'Android stopped the team while the app was away. Nothing is lost.';

  @override
  String get teamUiPhoneStartAgain => 'Start again';

  @override
  String get teamUiPhoneKeepRunningTitle => 'Keep it running';

  @override
  String get teamUiPhoneKeepRunningSubtitle =>
      'Wake lock, battery setting and the phantom process killer';

  @override
  String get teamUiPhoneTipsIntro =>
      'Android stops background work it considers excessive, and the team is exactly that: dozens of short gc and bd processes and an agent at full CPU. Three things keep it alive.';

  @override
  String get teamUiPhoneTipWakeLock =>
      'Keep Termux in front, or hold its wake lock: run termux-wake-lock in Termux, or tap Acquire wakelock in its notification. Screen off without it ends the run.';

  @override
  String get teamUiPhoneTipBattery =>
      'Settings › Apps › Termux › Battery › Unrestricted, and switch off your phone maker\'s auto-clean for Termux.';

  @override
  String get teamUiPhoneTipPhantom =>
      'Android 12 and later still kill the child processes of a background app (the phantom process killer). Turn that off once, from Termux itself over Wireless debugging; no computer needed:';

  @override
  String get teamUiPhoneTipsCopy => 'Copy commands';

  @override
  String get teamUiPhoneTipsCopied => 'Commands copied';

  @override
  String get teamUiPhoneRemove => 'Delete from this phone';

  @override
  String get teamUiPhoneRemoveTitle => 'Delete the AI team from this phone?';

  @override
  String get teamUiPhoneRemoveBody =>
      'Stops the supervisor and deletes gc, the city and its store. Your project files and their git history stay. The plugin is turned off for this server.';

  @override
  String get teamUiPhoneRemoveConfirm => 'Delete';

  @override
  String get teamUiPhoneRemoved => 'The AI team was deleted from this phone.';

  @override
  String teamUiPhoneActionFailed(String reason) {
    return 'That did not work: $reason';
  }

  @override
  String get teamUiPhoneNotAvailable =>
      'Not available on this phone. Running a team needs the 64-bit Linux environment; this device or build can\'t provide it.';

  @override
  String get teamUiPhoneReofferTitle => 'Set up AI team on this phone';

  @override
  String get teamUiPhoneReofferBody =>
      'The optional step you skipped during setup. Several coding agents work on your project while you supervise from Work; Android may stop them when the app is away.';

  @override
  String get teamUiPhoneReofferDismiss => 'Not now';

  @override
  String get teamUiPhoneReofferAction => 'Set up';

  @override
  String get teamUiPhoneOpenSetup => 'Open phone setup';

  @override
  String teamUiPhoneFailedNoSpace(String detail) {
    return 'Not enough space on this phone. $detail Free some space (Storage on this phone can clean build caches), then try again.';
  }

  @override
  String get calmCodeOptions => 'Code options';

  @override
  String get phoneServerConnect => 'Connect';

  @override
  String get phoneServerOpen => 'Open';

  @override
  String get phoneServerStart => 'Start';

  @override
  String get phoneServerStop => 'Stop';

  @override
  String get phoneServerConnected => 'Connected to the server on this phone';

  @override
  String get phoneServerStopped => 'Server on this phone is stopped';

  @override
  String get phoneServerStarting => 'Starting the server on this phone…';

  @override
  String get phoneServerRestarting => 'Restarting the server on this phone…';

  @override
  String get phoneServerStopping => 'Stopping the server on this phone…';

  @override
  String get phoneServerMore => 'More server actions';

  @override
  String get phoneServerManage => 'Manage setup';

  @override
  String get phoneServerForget => 'Forget saved sign-in';

  @override
  String get phoneServerStartFailed =>
      'The server did not start. Open Manage setup to see why.';

  @override
  String get phoneServerRestartFailed =>
      'The server did not restart. Open Manage setup to see why.';

  @override
  String get phoneServerStopFailed =>
      'The server could not be stopped. Try again.';

  @override
  String get termuxRunningDetected => 'Server found on this phone';

  @override
  String get termuxRunningConnect => 'Connect to running server';

  @override
  String get termuxRunningDetails => 'Server details';

  @override
  String get termuxRunningPermission =>
      'Allow Termux access in phone setup to check for a server.';

  @override
  String get termuxRunningUnavailable =>
      'Could not check the server on this phone.';

  @override
  String get termuxStorageCatSharedCaches => 'Other caches and package data';

  @override
  String get termuxStorageNoteSharedCaches =>
      'Shared caches, package installs and download folders may support other tools or contain files worth keeping. They cannot be removed here.';

  @override
  String get termuxStorageRescanRequired =>
      'Previous scan · Scan again before cleaning more';

  @override
  String get safetyStopSharingTitle => 'Stop sharing this conversation?';

  @override
  String get safetyStopSharingBody =>
      'The link stops working for anyone who has it. The conversation itself is not changed.';

  @override
  String get safetyStopSharingKeep => 'Keep sharing';

  @override
  String get safetyStopLocalServerTitle => 'Stop the local server?';

  @override
  String get safetyStopLocalServerBody =>
      'Anything the agent is running on this phone is interrupted, and this app disconnects from it. Your projects and conversations stay on the phone; start the server again to continue.';

  @override
  String get safetyStopLocalServerKeep => 'Keep running';

  @override
  String safetyMcpDisconnectTitle(String server) {
    return 'Disconnect $server?';
  }

  @override
  String get safetyMcpDisconnectBody =>
      'Agents lose its tools until you connect it again, and a tool call in progress may fail. Its configuration stays saved.';

  @override
  String get safetyMcpDisconnectKeep => 'Stay connected';

  @override
  String get safetyStopOrphanBody =>
      'Nothing is waiting on it, but whatever it was still doing is lost. It gets a polite stop, then a forced one after 5 seconds.';

  @override
  String get settingsHubGroupConnection => 'Connection';

  @override
  String get settingsHubGroupConversation => 'Conversation defaults';

  @override
  String get settingsHubGroupNotifications => 'Notifications';

  @override
  String get settingsHubGroupAgentSetup => 'Agent setup';

  @override
  String get settingsHubGroupUsage => 'Usage';

  @override
  String get settingsHubGroupPrivacy => 'Privacy';

  @override
  String get settingsHubGroupHelp => 'Help';

  @override
  String get settingsHubThisServer => 'This server';

  @override
  String settingsHubThisServerStatus(String name, String status) {
    return '$name · $status';
  }

  @override
  String get settingsHubAccounts => 'Accounts';

  @override
  String get settingsHubAccountsSubtitle =>
      'Sign-in used by the agent on this server';

  @override
  String get settingsHubModelAndMode => 'Model and mode';

  @override
  String get settingsHubTranscriptSubtitle => 'Reasoning, timestamps and usage';

  @override
  String get settingsHubVoice => 'Voice';

  @override
  String get settingsHubVoiceSubtitle => 'Speech models stored on this phone';

  @override
  String get settingsHubPrivacyRow => 'Privacy and local data';

  @override
  String settingsHubNoResults(String query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String get settingsHubSearchServerAliases =>
      'server host url address password profile connection health status version update service';

  @override
  String get settingsHubSearchSavedServersAliases =>
      'servers profiles host url password switch add edit remove profile connection';

  @override
  String get settingsHubSearchPhoneAliases =>
      'phone termux local on-device on device android install setup storage services';

  @override
  String get settingsHubSearchAccountsAliases =>
      'account codex sign in login logout';

  @override
  String get settingsHubSearchExternalAgentsAliases =>
      'a2a external agents remote';

  @override
  String get settingsHubSearchTailscaleAliases =>
      'tailscale vpn network remote private';

  @override
  String get settingsHubSearchDisconnectAliases => 'disconnect leave server';

  @override
  String get settingsHubSearchModelModeAliases =>
      'model mode agent variant thinking default selected session chat conversation';

  @override
  String get settingsHubSearchShellAliases => 'shell terminal bash zsh command';

  @override
  String get settingsHubSearchPermissionsAliases =>
      'permissions approvals always allow allowed revoke';

  @override
  String get settingsHubSearchTranscriptAliases =>
      'transcript display thinking reasoning timestamps usage';

  @override
  String get settingsHubSearchVoiceAliases =>
      'voice speech microphone dictation model';

  @override
  String get settingsHubSearchNotificationsAliases =>
      'notifications alerts quiet hours battery background check-in check in wi-fi wifi monitor saved servers finished runs approvals questions quota thresholds';

  @override
  String get settingsHubSearchAppearanceAliases =>
      'appearance theme dark light language arabic english font text size colors';

  @override
  String get settingsHubSearchModelsAliases =>
      'models agents provider AI reasoning favorites recent';

  @override
  String get settingsHubSearchProvidersAliases =>
      'provider api key keys authentication connect';

  @override
  String get settingsHubSearchMcpAliases => 'mcp integrations servers tools';

  @override
  String get settingsHubSearchCommandsAliases =>
      'commands tools skills references slash capabilities';

  @override
  String get settingsHubSearchPluginsAliases =>
      'plugins plugin installed source status AI Team Gas City';

  @override
  String get settingsHubSearchUsageAliases =>
      'usage cost tokens budget quota limit spent remaining threshold quota monitoring provider';

  @override
  String get settingsHubSearchPrivacyAliases =>
      'privacy drafts queue queued prompts read state storage clear delete';

  @override
  String get settingsHubSearchGuideAliases =>
      'help guide connect tutorial start';

  @override
  String get settingsHubSearchBugAliases => 'bug feedback issue support report';

  @override
  String get settingsHubSearchDiagnosticsAliases =>
      'diagnostics debug errors log';

  @override
  String get settingsHubSearchAboutAliases =>
      'about version licenses open source notices privacy data';

  @override
  String get pluginsSectionInApp => 'In this app';

  @override
  String get pluginsSectionOnServer => 'On the server';

  @override
  String get notifySectionWhat => 'What notifies me';

  @override
  String get notifyFinishedRuns => 'Finished runs';

  @override
  String get notifyFinishedRunsDetail =>
      'When a run on the connected server finishes or fails.';

  @override
  String get notifyRequests => 'Approvals and questions';

  @override
  String get notifyRequestsDetail =>
      'When the agent is waiting for your answer, on any monitored server.';

  @override
  String get notifyQuotaAlerts => 'Quota thresholds';

  @override
  String get notifyQuotaAlertsDetail =>
      'When a monitored provider passes the threshold you set in Usage. An alert records a past reading, not what remains now.';

  @override
  String get notifyQuietDetail =>
      'No notifications during these local times, for every server and for quota alerts. Checks continue.';

  @override
  String get notifySectionBackground => 'Background';

  @override
  String get notifySectionServers => 'Saved servers';

  @override
  String get notifyWifiOnly => 'Check in the background on Wi-Fi only';

  @override
  String notifyHubBackgroundSummary(String state) {
    return 'Background: $state';
  }

  @override
  String get monitorNotificationSettings => 'Notification settings';

  @override
  String get usageSectionSpent => 'Spent';

  @override
  String get usageSectionRemaining => 'Remaining';

  @override
  String get shellTabWork => 'Work';

  @override
  String get shellTabInbox => 'Inbox';

  @override
  String get shellTabProject => 'Project';

  @override
  String get projectHubFilesSubtitle => 'Browse and preview project files';

  @override
  String get projectHubChangesSubtitle => 'Review uncommitted changes';

  @override
  String get projectHubSearchSubtitle => 'Find a file by name';

  @override
  String get serverSwitcherManage => 'Manage servers';

  @override
  String get serverSwitcherOpen => 'Switch server';

  @override
  String get discoverSearchGoTo => 'Go to';

  @override
  String get discoverSearchInsideSettings => 'Inside settings';

  @override
  String discoverSearchIn(String parent) {
    return 'In $parent';
  }

  @override
  String get discoverWorkAliases =>
      'work home conversations sessions chats recent pinned new conversation';

  @override
  String get discoverInboxAliases =>
      'inbox activity needs you approvals permissions questions forms waiting running finished';

  @override
  String get discoverProjectAliases =>
      'project tools code folder files changes terminal health worktrees';

  @override
  String get discoverFilesAliases =>
      'files browse folder tree preview code open file';

  @override
  String get discoverChangesAliases =>
      'changes review changes diff uncommitted git edits working tree';

  @override
  String get discoverTerminalAliases =>
      'terminal shell console command line pty';

  @override
  String get discoverHealthAliases =>
      'project health branch changed files language services formatters lsp';

  @override
  String get discoverWorktreesAliases =>
      'worktrees branches isolated git branch';

  @override
  String get discoverSearchFilesAliases => 'search files find file name';

  @override
  String get discoverAllConversationsAliases =>
      'all conversations sessions chats history every project search';

  @override
  String get discoverTeamAliases =>
      'ai team agents runs needs you orchestration plugin';

  @override
  String get discoverNotifyServersTitle => 'Notifications from saved servers';

  @override
  String get discoverNotifyWhatAliases =>
      'finished runs approvals questions check-ins check in quota alerts what notifies';

  @override
  String get discoverNotifyQuietAliases =>
      'quiet hours do not disturb night silence mute schedule';

  @override
  String get discoverNotifyBackgroundAliases =>
      'background connection stay connected battery keep alive service';

  @override
  String get discoverNotifyServersAliases =>
      'monitor saved servers attention wi-fi wifi check in the background';

  @override
  String get discoverAppearanceModeAliases =>
      'light dark mode system appearance night';

  @override
  String get discoverLanguageAliases =>
      'language arabic english locale translation rtl';

  @override
  String get discoverThemeAliases => 'theme colors palette pack accent';

  @override
  String get discoverSpentAliases => 'spent cost tokens usage statistics money';

  @override
  String get discoverRemainingAliases =>
      'remaining quota limit provider plan left';

  @override
  String get discoverBudgetAliases =>
      'budget budgets usd token budget spending limit';

  @override
  String get discoverQuotaMonitorAliases =>
      'quota monitoring threshold alert warn low';

  @override
  String get discoverCommandsAliases => 'commands server commands slash run';

  @override
  String get discoverToolsAliases =>
      'tools tools and capabilities inventory model tools';

  @override
  String get discoverSkillsAliases => 'skills skill instructions playbook';

  @override
  String get discoverReferencesAliases =>
      'references reference docs sources context';

  @override
  String get discoverRunningNowAliases =>
      'running now processes termux services stop on this phone';

  @override
  String get discoverStorageAliases =>
      'storage on this phone disk space clean termux';

  @override
  String get discoverMonitorAliases =>
      'saved-server attention monitor other servers waiting server attention';

  @override
  String get discoverConnectionHelpAliases =>
      'connection help cannot connect troubleshooting network refused timeout';

  @override
  String gestureEquivFileRowActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get gestureEquivShortcutFindMatch =>
      'Next / previous match while finding in a conversation';

  @override
  String get gestureEquivShortcutPromptHistory =>
      'Earlier / later prompt, with the cursor at the start or end of the message box';

  @override
  String get emptyTeachInboxMessage =>
      'Nothing needs you. Approvals and questions from running work appear here.';

  @override
  String get emptyTeachWorkTitle => 'No conversations yet';

  @override
  String get emptyTeachWorkMessage =>
      'Conversations you start in this project are listed here, with the ones that need you first. Start one with New conversation.';

  @override
  String get emptyTeachChangesTitle => 'No changes yet';

  @override
  String get emptyTeachChangesMessage =>
      'Edits the agent makes show up here to review.';

  @override
  String get emptyTeachWorktreesMessage =>
      'A worktree is a separate copy of this project on its own branch, so parallel work does not mix. Worktrees of this project appear here.';

  @override
  String get emptyTeachAllowedMessage =>
      'When you choose Always allow on an approval in this project, it is listed here so you can take it back.';

  @override
  String get emptyTeachTeamRunsMessage =>
      'A run is a job the team works through. Start one and its progress shows here.';

  @override
  String get emptyTeachSkillsMessage =>
      'Skills are reusable instructions the agent can follow. Skills from this project and this server appear here.';

  @override
  String get emptyTeachToolsMessage =>
      'Tools the agent can call with this model appear here. This model has none.';

  @override
  String get capabilityScreenTitle => 'Available on this server';

  @override
  String get capabilityScreenSubtitle => 'What this server can and cannot do';

  @override
  String get capabilityScreenAliases =>
      'available supported not available missing feature hidden why can\'t capabilities server support shell';

  @override
  String capabilityScreenIntro(String server) {
    return '$server decides what appears in this app. Anything it cannot do is left out of the menus and tabs instead of being shown greyed out.';
  }

  @override
  String get capabilityGroupAvailable => 'Available here';

  @override
  String get capabilityGroupUnavailable => 'Not available on this server';

  @override
  String get capabilityGroupDevice => 'Not available on this device';

  @override
  String get capabilityAllAvailable =>
      'This server supports everything the app offers.';

  @override
  String get capabilityFiles => 'Files';

  @override
  String get capabilityFilesDetail =>
      'Browse, search and preview the project\'s files';

  @override
  String get capabilityChanges => 'Changes';

  @override
  String get capabilityChangesDetail => 'Review what the agent edited';

  @override
  String get capabilityTerminal => 'Terminal';

  @override
  String get capabilityTerminalDetail => 'Run commands in the project';

  @override
  String get capabilityShell => 'Default shell';

  @override
  String get capabilityShellDetail =>
      'Choose the shell that commands and terminals use';

  @override
  String get capabilityAttachments => 'Attachments';

  @override
  String get capabilityAttachmentsDetail =>
      'Send files and photos with a prompt';

  @override
  String get capabilitySubagents => 'Delegate to a subagent';

  @override
  String get capabilitySubagentsDetail => 'Mention an agent with @ in a prompt';

  @override
  String get capabilityCompact => 'Compact';

  @override
  String get capabilityCompactDetail =>
      'Summarize a long conversation to free up context';

  @override
  String get capabilityShare => 'Share';

  @override
  String get capabilityShareDetail => 'Publish a link to a conversation';

  @override
  String get capabilityFork => 'Fork';

  @override
  String get capabilityForkDetail =>
      'Branch a conversation from an earlier message';

  @override
  String get capabilityRevert => 'Revert';

  @override
  String get capabilityRevertDetail => 'Undo a prompt and the edits it made';

  @override
  String get capabilityArchive => 'Archive';

  @override
  String get capabilityArchiveDetail =>
      'Put finished conversations away without deleting them';

  @override
  String get capabilityTodos => 'Todos';

  @override
  String get capabilityTodosDetail =>
      'See the agent\'s task list for a conversation';

  @override
  String get capabilityNotes => 'Note for the agent';

  @override
  String get capabilityNotesDetail =>
      'Keep standing instructions with a conversation';

  @override
  String get capabilityImportExport => 'Import and export';

  @override
  String get capabilityImportExportDetail =>
      'Move a conversation between servers as a file';

  @override
  String get capabilitySearchAll => 'All conversations';

  @override
  String get capabilitySearchAllDetail =>
      'Search conversations across every project';

  @override
  String get capabilityAlwaysAllow => 'Always allowed actions';

  @override
  String get capabilityAlwaysAllowDetail =>
      'Remember an approval so it is not asked again';

  @override
  String get capabilityModels => 'Models and providers';

  @override
  String get capabilityModelsDetail =>
      'Browse models and sign in to providers from the app';

  @override
  String get capabilitySkills => 'Skills and commands';

  @override
  String get capabilitySkillsDetail =>
      'List the server\'s skills, commands and references';

  @override
  String get capabilityMcp => 'MCP';

  @override
  String get capabilityMcpDetail => 'See and connect MCP servers';

  @override
  String get capabilityPlugins => 'Plugins';

  @override
  String get capabilityPluginsDetail =>
      'See the plugins installed on the server';

  @override
  String get capabilityCloud => 'Cloud environments';

  @override
  String get capabilityCloudDetail => 'Run a project in a managed environment';

  @override
  String get capabilityProjects => 'Projects';

  @override
  String get capabilityProjectsDetail =>
      'Switch projects and check a project\'s health';

  @override
  String get capabilityWorktrees => 'Worktrees';

  @override
  String get capabilityWorktreesDetail => 'Give a task its own isolated branch';

  @override
  String get capabilityUsage => 'Usage';

  @override
  String get capabilityUsageDetail => 'See what conversations have cost';

  @override
  String get capabilityOfflineQueue => 'Send later';

  @override
  String get capabilityOfflineQueueDetail =>
      'Queue a prompt while offline and send it on reconnect';

  @override
  String get capabilityContinueOnComputer => 'Continue on computer';

  @override
  String get capabilityContinueOnComputerDetail =>
      'Get a command that reopens the conversation at your desk';

  @override
  String get capabilityServerUpdates => 'Server updates';

  @override
  String get capabilityServerUpdatesDetail => 'Update the server from the app';

  @override
  String get capabilityBackgroundNotifications =>
      'Notifications in the background';

  @override
  String get capabilityBackgroundNotificationsDetail =>
      'Be told when work finishes or needs you while the app is closed';

  @override
  String get capabilityOnThisPhone => 'On this phone';

  @override
  String get capabilityOnThisPhoneDetail =>
      'Run the agent\'s server on this device';

  @override
  String get capabilityVoice => 'Voice';

  @override
  String get capabilityVoiceDetail =>
      'Dictate prompts with on-device speech models';

  @override
  String get discoverShowTipsAgain => 'Show tips again';

  @override
  String get discoverShowTipsSubtitle =>
      'One-time tips will appear again at their moment';

  @override
  String get discoverShowTipsAliases =>
      'tips hints nudges help reset show again tutorial';

  @override
  String get discoverShowTipsDone => 'Tips will show again.';

  @override
  String nudgeApprovals(String action) {
    return 'Asked for “$action” 3 times: this conversation can approve requests for you.';
  }

  @override
  String get nudgeReviewChanges =>
      'This run changed files: review what changed before you continue.';

  @override
  String get nudgeLeave =>
      'You can leave: this phone tells you when the run is done.';

  @override
  String nudgeCompact(String percent) {
    return 'The context is $percent% full: compact to keep going.';
  }

  @override
  String get nudgePin =>
      'Pin conversations you return to from their menu; they stay at the top of Work.';

  @override
  String get nudgeDismiss => 'Hide tip';

  @override
  String get firstRunWhereQuestion => 'Where does your coding agent run?';

  @override
  String get firstRunOnComputer => 'On my computer';

  @override
  String get firstRunOnComputerDetail => 'Connect to an agent that runs there.';

  @override
  String get firstRunOnPhoneDetail => 'Set one up here. No computer needed.';

  @override
  String get firstRunJustShowMe => 'Just show me';

  @override
  String get firstRunWhichAgent => 'Which agent first?';

  @override
  String get firstRunAgentOpenCode => 'OpenCode';

  @override
  String get firstRunAgentClaudeOrPi => 'Claude Code, Codex, Pi and more';

  @override
  String get firstRunAgentClaudeOrPiDetail =>
      'One connection to the Paseo daemon drives every agent installed there. Experimental.';

  @override
  String get firstRunAgentCodex => 'Codex';

  @override
  String get firstRunAgentCodexDetail =>
      'Directly, through Codex app-server. Experimental.';

  @override
  String get firstRunRunOnComputer => 'On your computer, run:';

  @override
  String get firstRunPairingNextScan =>
      'Then paste or scan the code it prints.';

  @override
  String get firstRunPairingNextPaste => 'Then paste the code it prints.';

  @override
  String get firstRunNotSameNetwork => 'Not on the same network?';

  @override
  String get firstRunShowCommands => 'Show the commands';

  @override
  String get firstRunCommandsPaseoNetwork =>
      'To reach it from this phone over your private network, listen on that address and set a password:';

  @override
  String get firstRunCommandsCodexToken =>
      'Create the connection token before you start it:';

  @override
  String get firstRunCommandsCodexUsb =>
      'A phone on a USB cable reaches it with:';

  @override
  String get firstRunNotifyTitle => 'Get told when it\'s done?';

  @override
  String get firstRunNotifyBody =>
      'Leave the app while the agent works. You get a notification when it finishes or needs you. Android shows a small ongoing notification while it stays connected.';

  @override
  String get firstRunNotifyAccept => 'Notify me';

  @override
  String get firstRunNotifyDecline => 'Not now';

  @override
  String get localAgentTitle => 'Claude Code on this phone';

  @override
  String get localAgentOfferBody =>
      'Run Claude Code here with no computer. The app installs Node.js, the Paseo daemon and Claude Code into the Ubuntu it already manages, and reaches them on this phone only.';

  @override
  String get localAgentOfferSize =>
      'About 60 MB to download for Node.js, plus the packages; about 1 GB once installed. Needs 2 GB free.';

  @override
  String get localAgentOfferWarning =>
      'Android may stop Termux in the background. The battery settings that keep the OpenCode server alive keep this alive too.';

  @override
  String get localAgentSetUp => 'Set up Claude Code';

  @override
  String get localAgentNotNow => 'Not now';

  @override
  String get localAgentNeedsUbuntuBody =>
      'Claude Code runs inside the Ubuntu this app sets up. Finish the On this phone setup first, then come back here.';

  @override
  String get localAgentOpenSetup => 'Open phone setup';

  @override
  String get localAgentStepNode => 'Node.js';

  @override
  String get localAgentStepPaseo => 'Paseo daemon';

  @override
  String get localAgentStepClaude => 'Claude Code';

  @override
  String get localAgentStepSignIn => 'Sign in to Claude';

  @override
  String get localAgentStepStart => 'Start on this phone';

  @override
  String get localAgentInstalling => 'Setting up Claude Code';

  @override
  String get localAgentLeaveNote =>
      'You can leave this screen. The install keeps going in Termux.';

  @override
  String get localAgentSignInBody =>
      'Termux opens and Claude Code shows a link. Approve it in your browser, paste the code back into Termux, then return here. This app never sees or stores your Claude sign-in.';

  @override
  String get localAgentSignInAlready => 'I already signed in';

  @override
  String localAgentSignInOpenFailed(String command) {
    return 'Termux could not be opened. Open Termux yourself and run: $command';
  }

  @override
  String get localAgentSignInMissing => 'No Claude sign-in was found yet.';

  @override
  String get localAgentReadyTitle => 'Claude Code is running on this phone';

  @override
  String get localAgentReadyBody =>
      'It listens on this phone only (127.0.0.1), behind a password this app keeps.';

  @override
  String localAgentVersions(String claude, String paseo, String node) {
    return 'Claude Code $claude · Paseo $paseo · Node.js $node';
  }

  @override
  String get localAgentInstalledTitle => 'Claude Code is installed and stopped';

  @override
  String get localAgentKilled =>
      'Android stopped Claude Code while the app was away. Nothing is lost.';

  @override
  String get localAgentFailedTitle => 'Claude Code setup stopped';

  @override
  String localAgentFailedNoSpace(String detail) {
    return 'Not enough space on this phone. $detail Free some space, then try again.';
  }

  @override
  String get localAgentFailedDownload =>
      'Node.js could not be downloaded. Check the network, then try again.';

  @override
  String get localAgentFailedChecksum =>
      'The Node.js download did not match its pinned checksum, so nothing was installed. Try again; if it happens twice, something on the network is changing the file.';

  @override
  String get localAgentFailedNativeBuild =>
      'A package needs a native module with no ready-made build for this phone. Nothing was compiled; the output below names it.';

  @override
  String get localAgentFailedPackages =>
      'The packages could not be installed. Check the network, then try again.';

  @override
  String get localAgentFailedPortInUse =>
      'Port 6767 on this phone is already used by another program. Stop that program, then try again.';

  @override
  String get localAgentFailedTimeout =>
      'Claude Code did not answer within two minutes. The output below shows what it printed.';

  @override
  String get localAgentFailedInterrupted =>
      'Android stopped the step before it finished. Try again; it picks up where it stopped.';

  @override
  String get localAgentFailedUnsupported => 'Claude Code needs a 64-bit phone.';

  @override
  String get localAgentFailedDaemon =>
      'Claude Code stopped or does not answer. Start it again.';

  @override
  String localAgentFailedReason(String detail) {
    return 'It stopped: $detail';
  }

  @override
  String get localAgentProjectTitle => 'Choose a project folder';

  @override
  String get localAgentProjectBody =>
      'Claude Code works inside one folder of the Ubuntu on this phone.';

  @override
  String get localAgentProjectPathLabel => 'Or type a path inside Ubuntu';

  @override
  String get localAgentProjectPathInvalid =>
      'Enter a full path, like /root/projects/my-app.';

  @override
  String localAgentConnectFailed(String detail) {
    return 'Could not connect to Claude Code on this phone. $detail';
  }

  @override
  String get localAgentCardStopped => 'Claude Code on this phone is stopped';

  @override
  String get localAgentCardConnected =>
      'Connected to Claude Code on this phone';

  @override
  String get localAgentCardStarting => 'Starting Claude Code…';

  @override
  String get localAgentCardRestarting => 'Restarting Claude Code…';

  @override
  String get localAgentCardStopping => 'Stopping Claude Code…';

  @override
  String get localAgentCardSubtitle => 'Claude Code through Paseo';

  @override
  String localAgentCardActionFailed(String detail) {
    return 'That did not work. $detail';
  }

  @override
  String get localAgentRestartTitle => 'Restart Claude Code on this phone?';

  @override
  String get localAgentRestartBody =>
      'Claude Code is briefly unavailable and anything it is doing right now is interrupted. Your conversations stay on the phone.';

  @override
  String get localAgentStopTitle => 'Stop Claude Code on this phone?';

  @override
  String get localAgentStopBody =>
      'Anything Claude Code is doing on this phone is interrupted, and this app disconnects from it. Your projects, conversations and Claude sign-in stay; start it again to continue.';

  @override
  String get localAgentRemove => 'Remove from this phone';

  @override
  String get localAgentRemoveTitle => 'Remove Claude Code from this phone?';

  @override
  String get localAgentRemoveBody =>
      'Stops it and deletes Node.js, Paseo and Claude Code from Ubuntu, about 1 GB. Your projects and your Claude sign-in stay.';

  @override
  String get localAgentRemoveKeep => 'Keep it';

  @override
  String get localAgentMore => 'More Claude Code actions';

  @override
  String get localAgentRuntimeChoiceDetail =>
      'Sets up Ubuntu and the OpenCode server first, then installs Claude Code next to it.';

  @override
  String get firstRunAgentsSideBySide =>
      'They run side by side on the same computer. Start with one, and add the others any time from the server name at the top.';

  @override
  String get firstRunPaseoTitle => 'Agents through Paseo';

  @override
  String get approvalsUiEverythingTitle => 'Approve everything on this server';

  @override
  String get approvalsUiEverythingDetail =>
      'Dangerous. Every conversation on this server, new ones and subagents included, is approved automatically while this app is connected. A conversation set to “Ask each time” still asks.';

  @override
  String get approvalsUiEverythingConfirmTitle => 'Approve everything?';

  @override
  String get approvalsUiEverythingConfirmBody =>
      'Agents on this server will run commands and change files without asking you, in every conversation. Turn this on only for a server and projects you can afford to break.';

  @override
  String get approvalsUiEverythingConfirmAction => 'Approve everything';

  @override
  String get approvalsUiEverythingActive =>
      'Following “Approve everything on this server”';

  @override
  String get approvalsUiServerRulesNoteEverything =>
      'The server’s own deny rules still apply, and automatic approval stops whenever this app disconnects.';

  @override
  String get agentErrorConnectionDropped =>
      'The connection to the model dropped.';

  @override
  String get agentErrorConnectionDroppedHint =>
      'Usually brief, and OpenCode retries by itself. If it keeps happening, check the internet on the computer running OpenCode.';

  @override
  String get agentErrorTimedOut => 'The model took too long to answer.';

  @override
  String get agentErrorTimedOutHint =>
      'OpenCode retries by itself. A smaller request or another model may be faster.';

  @override
  String get agentErrorProviderUnreachable =>
      'The server couldn’t reach the model provider.';

  @override
  String get agentErrorProviderUnreachableHint =>
      'Check the internet connection on the computer running OpenCode, then try again.';

  @override
  String get agentErrorRequestTooLarge =>
      'This request was too large to send to the model.';

  @override
  String get agentErrorRequestTooLargeHint =>
      'Send fewer or smaller attachments, or compact the conversation, then try again.';

  @override
  String get agentErrorRateLimited =>
      'The model provider is limiting how fast you can send.';

  @override
  String get agentErrorRateLimitedHint =>
      'It retries by itself after a short wait.';

  @override
  String get agentErrorProviderBusy =>
      'The model provider is overloaded right now.';

  @override
  String get agentErrorProviderBusyHint =>
      'It retries by itself. Another model may answer sooner.';

  @override
  String get agentErrorOutOfCredit =>
      'The provider account is out of credit or quota.';

  @override
  String get agentErrorOutOfCreditHint =>
      'Top up the account, or switch to another provider or model.';

  @override
  String get agentErrorServerDiskFull =>
      'The computer running OpenCode is out of disk space.';

  @override
  String get agentErrorServerDiskFullHint =>
      'Free some space there, then try again.';

  @override
  String get agentErrorRecovered => 'The agent carried on after this.';

  @override
  String chatUiRetryingSoon(String attempt) {
    return 'Retrying$attempt…';
  }

  @override
  String chatUiRetryingCountdown(String attempt, String time) {
    return 'Retrying$attempt in $time';
  }

  @override
  String get chatUiCompactAgain => 'Compact again';

  @override
  String get chatUiCompactionFailedHint =>
      'The conversation is still too long for the model, so the next turn will try again.';

  @override
  String get chatStripContextPending => 'Context pending';

  @override
  String get chatStripAutoApprove => 'Auto-approve';

  @override
  String get chatStripAutoApprovePaused => 'Auto-approve paused';

  @override
  String get chatStripBackground => 'Background';

  @override
  String chatAttachmentOfficeHeader(String name) {
    return 'Contents of $name, read on the phone: values and text only, without formatting, charts or formulas.';
  }

  @override
  String get chatAttachmentOfficeTruncated =>
      'The file was larger than a prompt can carry, so it is cut short below.';

  @override
  String chatAttachmentOfficeUnreadable(String name) {
    return '$name could not be read. It may be password protected, damaged, or in the older Excel or Word format; save it as .xlsx, .docx or CSV and try again.';
  }

  @override
  String chatAttachmentOfficeEmpty(String name) {
    return '$name has nothing in it to attach.';
  }

  @override
  String chatAttachmentDocumentAttached(String name) {
    return '$name attached as text.';
  }

  @override
  String chatAttachmentSheetAttached(String name, int sheets, int rows) {
    String _temp0 = intl.Intl.pluralLogic(
      sheets,
      locale: localeName,
      other: '$sheets sheets',
      one: '1 sheet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: '$rows rows',
      one: '1 row',
    );
    return '$name attached as text · $_temp0, $_temp1';
  }

  @override
  String get otherProjectsTitle => 'In other projects';

  @override
  String get otherProjectsForget => 'Remove from recent projects';

  @override
  String get otherProjectsUntitled => 'Untitled conversation';
}
