import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @setupCancelConnection.
  ///
  /// In en, this message translates to:
  /// **'Cancel connection'**
  String get setupCancelConnection;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Development services'**
  String get servicesTitle;

  /// No description provided for @servicesCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get servicesCopy;

  /// No description provided for @servicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Project commands, logs, and preview links'**
  String get servicesSubtitle;

  /// No description provided for @servicesIntro.
  ///
  /// In en, this message translates to:
  /// **'Keep your project\'s development commands and preview links together. Saving a service does not start it.'**
  String get servicesIntro;

  /// No description provided for @servicesAdd.
  ///
  /// In en, this message translates to:
  /// **'Register service'**
  String get servicesAdd;

  /// No description provided for @servicesName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get servicesName;

  /// No description provided for @servicesCommand.
  ///
  /// In en, this message translates to:
  /// **'Development command'**
  String get servicesCommand;

  /// No description provided for @servicesCommandHint.
  ///
  /// In en, this message translates to:
  /// **'Use a foreground command, such as npm run dev. Background or detached commands cannot be tracked.'**
  String get servicesCommandHint;

  /// No description provided for @servicesUrl.
  ///
  /// In en, this message translates to:
  /// **'Preview URL (optional)'**
  String get servicesUrl;

  /// No description provided for @servicesUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Use an address this phone can reach. localhost points to this phone. No ports are exposed or forwarded for you.'**
  String get servicesUrlHint;

  /// No description provided for @servicesSave.
  ///
  /// In en, this message translates to:
  /// **'Save service'**
  String get servicesSave;

  /// No description provided for @servicesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name, a foreground command, and an optional HTTP or HTTPS URL without credentials.'**
  String get servicesInvalid;

  /// No description provided for @servicesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This server cannot start and track development commands. You can save commands and review their preview links here.'**
  String get servicesUnavailable;

  /// No description provided for @servicesScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Reopen Development services from the intended project.'**
  String get servicesScopeChanged;

  /// No description provided for @servicesNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get servicesNotStarted;

  /// No description provided for @servicesRunning.
  ///
  /// In en, this message translates to:
  /// **'Running command'**
  String get servicesRunning;

  /// No description provided for @servicesStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get servicesStopped;

  /// No description provided for @servicesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unknown'**
  String get servicesUnknown;

  /// No description provided for @servicesStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Command status does not confirm that your app is ready or reachable.'**
  String get servicesStatusHint;

  /// No description provided for @servicesStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get servicesStart;

  /// No description provided for @servicesStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get servicesStop;

  /// No description provided for @servicesRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get servicesRestart;

  /// No description provided for @servicesLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get servicesLogs;

  /// No description provided for @servicesVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get servicesVisit;

  /// No description provided for @servicesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove configuration'**
  String get servicesRemove;

  /// No description provided for @servicesRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Remove this saved service and its local ownership record? This does not stop its command on the server. Stop it first if needed.'**
  String get servicesRemoveHint;

  /// No description provided for @servicesStartHint.
  ///
  /// In en, this message translates to:
  /// **'Run this saved command in the project shown below? It uses the server\'s environment. Keep it in the foreground; this panel cannot manage detached processes.'**
  String get servicesStartHint;

  /// No description provided for @servicesStopHint.
  ///
  /// In en, this message translates to:
  /// **'Stop this service\'s tracked command? The server also removes its retained logs. Other commands are not affected.'**
  String get servicesStopHint;

  /// No description provided for @servicesRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Stop this tracked command, remove its server log, then start the saved command again?'**
  String get servicesRestartHint;

  /// No description provided for @servicesForget.
  ///
  /// In en, this message translates to:
  /// **'Forget last run'**
  String get servicesForget;

  /// No description provided for @servicesForgetHint.
  ///
  /// In en, this message translates to:
  /// **'Clear the local run record? This does not stop any server process. Starting again may create a duplicate if the previous command is still running.'**
  String get servicesForgetHint;

  /// No description provided for @servicesUnknownHint.
  ///
  /// In en, this message translates to:
  /// **'The last run could not be confirmed. Refresh to reconcile it before starting again.'**
  String get servicesUnknownHint;

  /// No description provided for @servicesLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No captured output is available yet.'**
  String get servicesLogEmpty;

  /// No description provided for @servicesLogTail.
  ///
  /// In en, this message translates to:
  /// **'Bounded log tail. Earlier output may be omitted. Logs are kept on the server, not saved on this phone.'**
  String get servicesLogTail;

  /// No description provided for @servicesWorking.
  ///
  /// In en, this message translates to:
  /// **'Updating service…'**
  String get servicesWorking;

  /// No description provided for @servicesExit.
  ///
  /// In en, this message translates to:
  /// **'Recorded exit code: {code}'**
  String servicesExit(int code);

  /// No description provided for @servicesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get servicesRefresh;

  /// No description provided for @isolatedTaskScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Close this sheet and reopen the task from the intended project.'**
  String get isolatedTaskScopeChanged;

  /// Application title shown in the task switcher / window title
  ///
  /// In en, this message translates to:
  /// **'OpenCode Mobile'**
  String get appTitle;

  /// Section label above the More hub's manage destination grid
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get libraryManageSection;

  /// More hub card: model and agent catalog
  ///
  /// In en, this message translates to:
  /// **'Models & agents'**
  String get libraryModelsAgentsTitle;

  /// More hub card: provider integrations
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get libraryProvidersTitle;

  /// More hub card: Model Context Protocol server integrations
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get libraryMcpTitle;

  /// More hub card: commands, skills, and native tools
  ///
  /// In en, this message translates to:
  /// **'Commands & tools'**
  String get libraryCommandsToolsTitle;

  /// More hub card: server terminal sessions
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get libraryTerminalTitle;

  /// More hub card: app settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get librarySettingsTitle;

  /// Installed app version and build shown in About
  ///
  /// In en, this message translates to:
  /// **'OpenCode Mobile {version}+{buildNumber}'**
  String aboutBuildVersion(String version, String buildNumber);

  /// Label for the installed Android APK signer fingerprint
  ///
  /// In en, this message translates to:
  /// **'Signing certificate SHA-256'**
  String get aboutSigningCertificate;

  /// Tooltip for the chat model cycling menu
  ///
  /// In en, this message translates to:
  /// **'Switch model for this conversation'**
  String get modelSwitchSession;

  /// Cycle forward through recent models
  ///
  /// In en, this message translates to:
  /// **'Next recent model · F2'**
  String get modelNextRecent;

  /// Cycle backward through recent models
  ///
  /// In en, this message translates to:
  /// **'Previous recent model · Shift+F2'**
  String get modelPreviousRecent;

  /// Cycle through the server profile's favorite models
  ///
  /// In en, this message translates to:
  /// **'Next favorite model'**
  String get modelNextFavorite;

  /// No description provided for @modelChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get modelChooseTitle;

  /// No description provided for @modelTitleCompact.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get modelTitleCompact;

  /// No description provided for @modelSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get modelSearchHint;

  /// No description provided for @modelAll.
  ///
  /// In en, this message translates to:
  /// **'All models'**
  String get modelAll;

  /// No description provided for @modelFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get modelFavorites;

  /// No description provided for @modelRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get modelRecent;

  /// No description provided for @modelOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get modelOptions;

  /// No description provided for @modelThinkingMode.
  ///
  /// In en, this message translates to:
  /// **'Thinking mode'**
  String get modelThinkingMode;

  /// No description provided for @modelDefaultMode.
  ///
  /// In en, this message translates to:
  /// **'Default mode'**
  String get modelDefaultMode;

  /// No description provided for @modelSessionScopeNote.
  ///
  /// In en, this message translates to:
  /// **'Applies to this conversation\'s next turns.'**
  String get modelSessionScopeNote;

  /// No description provided for @modelSelectionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading conversation selection…'**
  String get modelSelectionLoading;

  /// No description provided for @modelServerDefault.
  ///
  /// In en, this message translates to:
  /// **'Server default'**
  String get modelServerDefault;

  /// No description provided for @modelSelectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving conversation selection…'**
  String get modelSelectionSaving;

  /// No description provided for @modelAgentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the agent. Try again.'**
  String get modelAgentSaveFailed;

  /// No description provided for @modelUnavailableSelection.
  ///
  /// In en, this message translates to:
  /// **'The conversation\'s model is unavailable in this catalog. Refresh models or choose another.'**
  String get modelUnavailableSelection;

  /// No description provided for @modelScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'The server changed. Reopen the model selector to continue.'**
  String get modelScopeChanged;

  /// No description provided for @commonClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commonClearSearch;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @workTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get workTitle;

  /// No description provided for @workDescription.
  ///
  /// In en, this message translates to:
  /// **'Agents and commands related to this conversation.'**
  String get workDescription;

  /// No description provided for @workAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get workAgents;

  /// No description provided for @workCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get workCommands;

  /// No description provided for @workEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get workEmpty;

  /// No description provided for @workEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Related agents and commands will appear here when this conversation starts them.'**
  String get workEmptyDescription;

  /// No description provided for @workRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get workRefresh;

  /// No description provided for @workClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get workClose;

  /// No description provided for @workRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get workRetry;

  /// No description provided for @workCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workCancel;

  /// No description provided for @workRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get workRunning;

  /// No description provided for @workFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get workFinished;

  /// No description provided for @workTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get workTimedOut;

  /// No description provided for @workStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get workStopped;

  /// No description provided for @workUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get workUnknown;

  /// No description provided for @workOutput.
  ///
  /// In en, this message translates to:
  /// **'Command output'**
  String get workOutput;

  /// No description provided for @workViewOutput.
  ///
  /// In en, this message translates to:
  /// **'View output'**
  String get workViewOutput;

  /// No description provided for @workNoOutput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for output…'**
  String get workNoOutput;

  /// No description provided for @workNoFinalOutput.
  ///
  /// In en, this message translates to:
  /// **'This command produced no output.'**
  String get workNoFinalOutput;

  /// No description provided for @workCopyOutput.
  ///
  /// In en, this message translates to:
  /// **'Copy output'**
  String get workCopyOutput;

  /// No description provided for @workCopied.
  ///
  /// In en, this message translates to:
  /// **'Output copied'**
  String get workCopied;

  /// No description provided for @workFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow output'**
  String get workFollow;

  /// No description provided for @workMoreOutput.
  ///
  /// In en, this message translates to:
  /// **'Load more output'**
  String get workMoreOutput;

  /// No description provided for @workTrimmed.
  ///
  /// In en, this message translates to:
  /// **'Showing the most recent output. Earlier text was trimmed.'**
  String get workTrimmed;

  /// No description provided for @workStop.
  ///
  /// In en, this message translates to:
  /// **'Stop command'**
  String get workStop;

  /// No description provided for @workStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this command?'**
  String get workStopTitle;

  /// No description provided for @workStopDescription.
  ///
  /// In en, this message translates to:
  /// **'This stops the command and removes its saved output from the server. Text already loaded here stays visible until you close it.'**
  String get workStopDescription;

  /// No description provided for @workTimeout.
  ///
  /// In en, this message translates to:
  /// **'Change timeout'**
  String get workTimeout;

  /// No description provided for @workTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get workTimeoutTitle;

  /// No description provided for @workTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'The new timeout starts now.'**
  String get workTimeoutDescription;

  /// No description provided for @workTimeoutOneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get workTimeoutOneMinute;

  /// No description provided for @workTimeoutFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get workTimeoutFiveMinutes;

  /// No description provided for @workTimeoutFifteenMinutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes'**
  String get workTimeoutFifteenMinutes;

  /// No description provided for @workTimeoutOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get workTimeoutOneHour;

  /// No description provided for @workTimeoutNone.
  ///
  /// In en, this message translates to:
  /// **'No timeout'**
  String get workTimeoutNone;

  /// No description provided for @workTimeoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Timeout updated'**
  String get workTimeoutSaved;

  /// No description provided for @workUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This command is no longer available. It may have been removed or cancelled when the server restarted.'**
  String get workUnavailable;

  /// No description provided for @workRestarted.
  ///
  /// In en, this message translates to:
  /// **'The server restarted and this command is no longer available. Its loaded output is shown below.'**
  String get workRestarted;

  /// No description provided for @workDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting. Output will refresh when the server is available.'**
  String get workDisconnected;

  /// No description provided for @workContextChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Close this view and reopen Running work.'**
  String get workContextChanged;

  /// No description provided for @workCount.
  ///
  /// In en, this message translates to:
  /// **'Tasks · {count} running'**
  String workCount(int count);

  /// No description provided for @workExitCode.
  ///
  /// In en, this message translates to:
  /// **'Exit code {code}'**
  String workExitCode(int code);

  /// No description provided for @workStatusElapsed.
  ///
  /// In en, this message translates to:
  /// **'{status} · {elapsed}'**
  String workStatusElapsed(String status, String elapsed);

  /// No description provided for @composerClearTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear draft text'**
  String get composerClearTextTitle;

  /// No description provided for @composerClearTextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps attachments · Undo available'**
  String get composerClearTextSubtitle;

  /// No description provided for @composerDraftCleared.
  ///
  /// In en, this message translates to:
  /// **'Draft text cleared'**
  String get composerDraftCleared;

  /// No description provided for @composerReuseTitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse a prompt'**
  String get composerReuseTitle;

  /// No description provided for @queueSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the queued draft on this device. Your text is still here. Check available storage and try again.'**
  String get queueSaveFailed;

  /// No description provided for @fileCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fileCopy;

  /// No description provided for @fileReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get fileReference;

  /// No description provided for @fileAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get fileAttach;

  /// No description provided for @fileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get fileSave;

  /// No description provided for @fileReload.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get fileReload;

  /// No description provided for @queueRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this draft from device storage. It is still queued. Check available storage and try again.'**
  String get queueRemoveFailed;

  /// No description provided for @composerReuseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse text from this conversation and recent sends'**
  String get composerReuseSubtitle;

  /// No description provided for @composerReuseDescription.
  ///
  /// In en, this message translates to:
  /// **'Text from loaded prompts in this conversation and recent sends on this server. Selecting one appends it to your draft. Attachments are not copied. With a keyboard, use Up at the start or Down at the end to browse and restore your draft.'**
  String get composerReuseDescription;

  /// No description provided for @composerReuseSearch.
  ///
  /// In en, this message translates to:
  /// **'Search recent prompts'**
  String get composerReuseSearch;

  /// No description provided for @composerReuseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching prompts'**
  String get composerReuseEmpty;

  /// No description provided for @backgroundSubagentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Background subagents'**
  String get backgroundSubagentsTitle;

  /// No description provided for @backgroundWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'Move running work to background'**
  String get backgroundWorkTitle;

  /// No description provided for @backgroundWorkShortcut.
  ///
  /// In en, this message translates to:
  /// **'Continue this work while you use the conversation · Ctrl+B'**
  String get backgroundWorkShortcut;

  /// No description provided for @backgroundWorkNoop.
  ///
  /// In en, this message translates to:
  /// **'No foreground subagents to background.'**
  String get backgroundWorkNoop;

  /// No description provided for @backgroundWorkPromoted.
  ///
  /// In en, this message translates to:
  /// **'Subagents are continuing in the background.'**
  String get backgroundWorkPromoted;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find settings, tools, and help'**
  String get librarySearchHint;

  /// No description provided for @libraryDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default for new conversations'**
  String get libraryDefaultModel;

  /// No description provided for @libraryNoModel.
  ///
  /// In en, this message translates to:
  /// **'No model selected'**
  String get libraryNoModel;

  /// Number of matching destinations in More
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No matching tools for “{query}”.} one {1 result for “{query}”.} other {{count} results for “{query}”.}}'**
  String librarySearchResults(int count, String query);

  /// No description provided for @chatAttachmentUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only PNG, JPEG, GIF, WebP, PDF, and text files can be attached.'**
  String get chatAttachmentUnsupported;

  /// Action that restarts the app-managed OpenCode server running in Termux
  ///
  /// In en, this message translates to:
  /// **'Restart local server'**
  String get termuxRestartServer;

  /// Confirmation title before restarting the managed Termux server
  ///
  /// In en, this message translates to:
  /// **'Restart the local server?'**
  String get termuxRestartTitle;

  /// Confirmation explanation before restarting the managed Termux server
  ///
  /// In en, this message translates to:
  /// **'OpenCode will be briefly unavailable. The app will keep your current project and reconnect automatically.'**
  String get termuxRestartMessage;

  /// Additional restart warning when one or more sessions are generating
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 conversation is generating. Restarting will interrupt it.} other{{count} conversations are generating. Restarting will interrupt them.}}'**
  String termuxRestartBusyMessage(int count);

  /// Confirmation button that starts a managed Termux server restart
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get termuxRestartConfirm;

  /// Progress label while the managed Termux server restarts
  ///
  /// In en, this message translates to:
  /// **'Restarting local server...'**
  String get termuxRestarting;

  /// Progress explanation while the managed Termux server restarts
  ///
  /// In en, this message translates to:
  /// **'The installed OpenCode version and saved credential are unchanged. The app will reconnect when the server is ready.'**
  String get termuxRestartProgress;

  /// Success message after a managed Termux server restart
  ///
  /// In en, this message translates to:
  /// **'Local server restarted and reconnected.'**
  String get termuxRestartSucceeded;

  /// Message after restart preflight fails while the existing managed server remains healthy
  ///
  /// In en, this message translates to:
  /// **'Restart was not performed. The existing local server is still running.'**
  String get termuxRestartNotPerformed;

  /// No description provided for @chatCopyCompleteReply.
  ///
  /// In en, this message translates to:
  /// **'Copy complete reply'**
  String get chatCopyCompleteReply;

  /// No description provided for @chatCopyReplySoFar.
  ///
  /// In en, this message translates to:
  /// **'Copy reply so far'**
  String get chatCopyReplySoFar;

  /// No description provided for @commandRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Run /{command}'**
  String commandRunTitle(String command);

  /// No description provided for @commandDestination.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get commandDestination;

  /// No description provided for @commandNewChat.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get commandNewChat;

  /// No description provided for @commandUntitledChat.
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get commandUntitledChat;

  /// No description provided for @commandArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments (optional)'**
  String get commandArguments;

  /// No description provided for @commandRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get commandRun;

  /// No description provided for @commandRunning.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get commandRunning;

  /// No description provided for @commandLocationChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Close this dialog and open the command again.'**
  String get commandLocationChanged;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t refresh'**
  String get refreshFailed;

  /// No description provided for @refreshRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get refreshRetry;

  /// No description provided for @filesProjectRoot.
  ///
  /// In en, this message translates to:
  /// **'Project root'**
  String get filesProjectRoot;

  /// No description provided for @filesOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder {folder}'**
  String filesOpenFolder(String folder);

  /// No description provided for @filesCurrentFolder.
  ///
  /// In en, this message translates to:
  /// **'Current folder: {folder}'**
  String filesCurrentFolder(String folder);

  /// No description provided for @globalSessionsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more conversations'**
  String get globalSessionsLoadMore;

  /// Generic failure when refreshing the global session inventory
  ///
  /// In en, this message translates to:
  /// **'Could not refresh conversations.'**
  String get globalSessionsRefreshFailed;

  /// No description provided for @workspaceSearchAllSessions.
  ///
  /// In en, this message translates to:
  /// **'Search all conversations'**
  String get workspaceSearchAllSessions;

  /// No description provided for @workspaceProjectListUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Project list unavailable'**
  String get workspaceProjectListUnavailable;

  /// No description provided for @workspaceProjectListFallback.
  ///
  /// In en, this message translates to:
  /// **'Your conversations can still be available. Search all conversations to find previous work.'**
  String get workspaceProjectListFallback;

  /// No description provided for @workspaceRetryProjects.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get workspaceRetryProjects;

  /// No description provided for @historyLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load older messages'**
  String get historyLoadOlder;

  /// No description provided for @historyReload.
  ///
  /// In en, this message translates to:
  /// **'Refresh recent history'**
  String get historyReload;

  /// No description provided for @historyCursorExpired.
  ///
  /// In en, this message translates to:
  /// **'Older history changed or expired. Refresh recent history to continue.'**
  String get historyCursorExpired;

  /// No description provided for @historyRefreshed.
  ///
  /// In en, this message translates to:
  /// **'History refreshed. Older messages remain available above.'**
  String get historyRefreshed;

  /// No description provided for @historyLoadedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only loaded messages are included. Load older history to include more.'**
  String get historyLoadedOnly;

  /// No description provided for @historyLoadedTotals.
  ///
  /// In en, this message translates to:
  /// **'Usage and loaded history'**
  String get historyLoadedTotals;

  /// No description provided for @historyCopyLoadedReply.
  ///
  /// In en, this message translates to:
  /// **'Copy loaded reply'**
  String get historyCopyLoadedReply;

  /// No description provided for @historyLoadedMessages.
  ///
  /// In en, this message translates to:
  /// **'Loaded messages'**
  String get historyLoadedMessages;

  /// No description provided for @historyLoadedCost.
  ///
  /// In en, this message translates to:
  /// **'Cost of loaded messages'**
  String get historyLoadedCost;

  /// No description provided for @historyServerTotalsNote.
  ///
  /// In en, this message translates to:
  /// **'Rows marked reported by server cover the conversation. Message counts and other estimates cover loaded history.'**
  String get historyServerTotalsNote;

  /// No description provided for @sessionsLoadedOnly.
  ///
  /// In en, this message translates to:
  /// **'Showing loaded conversations. Load more to include older ones.'**
  String get sessionsLoadedOnly;

  /// No description provided for @sessionsDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Conversation details could not be loaded. Try again.'**
  String get sessionsDetailsUnavailable;

  /// No description provided for @sessionsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more conversations'**
  String get sessionsLoadMore;

  /// No description provided for @sessionsReload.
  ///
  /// In en, this message translates to:
  /// **'Refresh recent conversations'**
  String get sessionsReload;

  /// No description provided for @sessionsNoLoadedRecent.
  ///
  /// In en, this message translates to:
  /// **'No recent conversations in loaded results'**
  String get sessionsNoLoadedRecent;

  /// No description provided for @sessionsNoLoadedArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived conversations in loaded results'**
  String get sessionsNoLoadedArchived;

  /// No description provided for @sessionsLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} loaded'**
  String sessionsLoadedCount(int count);

  /// No description provided for @revertStageTitle.
  ///
  /// In en, this message translates to:
  /// **'Stage a revert from this prompt?'**
  String get revertStageTitle;

  /// No description provided for @revertStageDescription.
  ///
  /// In en, this message translates to:
  /// **'This prompt and the conversation after it will be hidden while the revert is staged. Review the result before making it permanent.'**
  String get revertStageDescription;

  /// No description provided for @revertApplyFiles.
  ///
  /// In en, this message translates to:
  /// **'Revert file changes too'**
  String get revertApplyFiles;

  /// No description provided for @revertApplyFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Applies file changes immediately when staging. Clear can restore the staged files from the saved snapshot.'**
  String get revertApplyFilesHint;

  /// No description provided for @revertStageAction.
  ///
  /// In en, this message translates to:
  /// **'Stage and review'**
  String get revertStageAction;

  /// No description provided for @revertReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review staged revert'**
  String get revertReviewTitle;

  /// No description provided for @revertReviewChanged.
  ///
  /// In en, this message translates to:
  /// **'This conversation or its staged revert changed. Review the latest state before continuing.'**
  String get revertReviewChanged;

  /// No description provided for @revertReviewLatest.
  ///
  /// In en, this message translates to:
  /// **'Review latest state'**
  String get revertReviewLatest;

  /// No description provided for @revertBusy.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current conversation action to finish.'**
  String get revertBusy;

  /// No description provided for @revertCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get revertCancel;

  /// No description provided for @revertCommitTitle.
  ///
  /// In en, this message translates to:
  /// **'Make this revert permanent?'**
  String get revertCommitTitle;

  /// No description provided for @revertCommitDescription.
  ///
  /// In en, this message translates to:
  /// **'Removes the staged conversation history permanently. File changes already applied during staging will remain. You cannot clear this revert afterward.'**
  String get revertCommitDescription;

  /// No description provided for @revertCommitAction.
  ///
  /// In en, this message translates to:
  /// **'Make revert permanent'**
  String get revertCommitAction;

  /// No description provided for @revertClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this staged revert?'**
  String get revertClearTitle;

  /// No description provided for @revertClearDescription.
  ///
  /// In en, this message translates to:
  /// **'Restores the hidden conversation and the files included in this stage from the saved snapshot. Changes made to those files since staging may be replaced. Queued work may resume.'**
  String get revertClearDescription;

  /// No description provided for @revertClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear staged revert'**
  String get revertClearAction;

  /// No description provided for @revertNoStage.
  ///
  /// In en, this message translates to:
  /// **'There is no staged revert to review.'**
  String get revertNoStage;

  /// No description provided for @revertBoundaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Staged from prompt'**
  String get revertBoundaryLabel;

  /// No description provided for @revertPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'These are the file changes reported for this stage. Staging may already have applied them.'**
  String get revertPreviewDescription;

  /// No description provided for @revertPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server did not provide a file preview. This does not establish whether files changed.'**
  String get revertPreviewUnavailable;

  /// No description provided for @revertPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No file changes were reported for this stage.'**
  String get revertPreviewEmpty;

  /// No description provided for @revertStaged.
  ///
  /// In en, this message translates to:
  /// **'Revert staged'**
  String get revertStaged;

  /// No description provided for @revertReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get revertReview;

  /// No description provided for @revertFromHere.
  ///
  /// In en, this message translates to:
  /// **'Revert from this prompt'**
  String get revertFromHere;

  /// No description provided for @revertUndoDescription.
  ///
  /// In en, this message translates to:
  /// **'Stage a revert and review the affected files'**
  String get revertUndoDescription;

  /// No description provided for @revertClearShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Review and clear the staged revert'**
  String get revertClearShortDescription;

  /// No description provided for @revertPromptUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The boundary prompt could not be loaded.'**
  String get revertPromptUnavailable;

  /// No description provided for @revertPromptLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the boundary prompt…'**
  String get revertPromptLoading;

  /// No description provided for @revertAttachmentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Attachment-only prompt'**
  String get revertAttachmentPrompt;

  /// No description provided for @revertResolveBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Review the staged revert, then clear it or make it permanent before sending. Your draft is kept.'**
  String get revertResolveBeforeSending;

  /// No description provided for @sessionNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note for the agent'**
  String get sessionNoteTitle;

  /// No description provided for @sessionNoteDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep a short instruction for this conversation. Saving or deleting it takes effect at the next agent step and appears in the transcript then. It does not start a run.'**
  String get sessionNoteDescription;

  /// No description provided for @sessionNoteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Keep explanations brief and run the relevant checks before finishing.'**
  String get sessionNoteHint;

  /// No description provided for @sessionNoteSave.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get sessionNoteSave;

  /// No description provided for @sessionNoteRemove.
  ///
  /// In en, this message translates to:
  /// **'Delete saved note'**
  String get sessionNoteRemove;

  /// No description provided for @sessionNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get sessionNoteSaved;

  /// No description provided for @sessionNoteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get sessionNoteRemoved;

  /// No description provided for @sessionNotePending.
  ///
  /// In en, this message translates to:
  /// **'Applies at the next agent step.'**
  String get sessionNotePending;

  /// No description provided for @sessionInstructionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Instructions updated'**
  String get sessionInstructionsUpdated;

  /// No description provided for @sessionInstructionsApplied.
  ///
  /// In en, this message translates to:
  /// **'The agent\'s conversation instructions have been updated for this step.'**
  String get sessionInstructionsApplied;

  /// No description provided for @sessionNoteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support conversation notes.'**
  String get sessionNoteUnsupported;

  /// No description provided for @sessionNoteAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Check this server\'s password and permissions, then try again. Your draft is kept.'**
  String get sessionNoteAuthorization;

  /// No description provided for @sessionNoteChanged.
  ///
  /// In en, this message translates to:
  /// **'The conversation or its instructions changed. Refresh the saved note before saving again. Your draft is kept.'**
  String get sessionNoteChanged;

  /// No description provided for @sessionNoteInvalid.
  ///
  /// In en, this message translates to:
  /// **'The saved note has a format this editor cannot safely change.'**
  String get sessionNoteInvalid;

  /// No description provided for @sessionNoteTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Shorten the note to fit the server\'s size limit.'**
  String get sessionNoteTooLarge;

  /// No description provided for @sessionNoteBusy.
  ///
  /// In en, this message translates to:
  /// **'A note change is already being saved. Try again when it finishes.'**
  String get sessionNoteBusy;

  /// No description provided for @sessionNoteRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh saved note'**
  String get sessionNoteRefresh;

  /// No description provided for @sessionNoteSavedVersion.
  ///
  /// In en, this message translates to:
  /// **'Current saved note — review before replacing'**
  String get sessionNoteSavedVersion;

  /// No description provided for @sessionNoteNone.
  ///
  /// In en, this message translates to:
  /// **'No saved note'**
  String get sessionNoteNone;

  /// No description provided for @sessionNoteDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard your note changes?'**
  String get sessionNoteDiscard;

  /// No description provided for @sessionNoteKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get sessionNoteKeepEditing;

  /// No description provided for @sessionNoteDiscardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get sessionNoteDiscardAction;

  /// No description provided for @sessionNoteBytes.
  ///
  /// In en, this message translates to:
  /// **'{used} / {limit} bytes'**
  String sessionNoteBytes(int used, int limit);

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage and cost'**
  String get usageTitle;

  /// No description provided for @usageDescription.
  ///
  /// In en, this message translates to:
  /// **'Activity recorded by this OpenCode server across your conversations.'**
  String get usageDescription;

  /// No description provided for @usageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh usage'**
  String get usageRefresh;

  /// No description provided for @usageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get usageToday;

  /// No description provided for @usageThirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get usageThirtyDays;

  /// No description provided for @usageYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get usageYear;

  /// No description provided for @usageAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get usageAllTime;

  /// No description provided for @usageScope.
  ///
  /// In en, this message translates to:
  /// **'Project scope'**
  String get usageScope;

  /// No description provided for @usageAllProjects.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get usageAllProjects;

  /// No description provided for @usageCurrentProject.
  ///
  /// In en, this message translates to:
  /// **'Current project'**
  String get usageCurrentProject;

  /// No description provided for @usageLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading usage'**
  String get usageLoading;

  /// No description provided for @usageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support aggregate usage.'**
  String get usageUnsupported;

  /// No description provided for @usageProjectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No current project could be identified. Choose All projects or open a project first.'**
  String get usageProjectUnavailable;

  /// No description provided for @usageTimezoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not read this device\'s timezone. Retry to load correctly dated usage.'**
  String get usageTimezoneUnavailable;

  /// No description provided for @usageRefreshInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The server changed while loading usage. Refresh to try again.'**
  String get usageRefreshInterrupted;

  /// No description provided for @usageInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned incomplete usage data. Refresh to try again.'**
  String get usageInvalidResponse;

  /// No description provided for @usageAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Check this server\'s password and permissions, then refresh.'**
  String get usageAuthorization;

  /// No description provided for @usagePreviousResult.
  ///
  /// In en, this message translates to:
  /// **'Showing the previous result for these filters.'**
  String get usagePreviousResult;

  /// No description provided for @usageLocationChanged.
  ///
  /// In en, this message translates to:
  /// **'The active server or project changed. Reopen Usage from Settings.'**
  String get usageLocationChanged;

  /// No description provided for @usageTinyCost.
  ///
  /// In en, this message translates to:
  /// **'Less than \$0.000001'**
  String get usageTinyCost;

  /// No description provided for @usageReportedCost.
  ///
  /// In en, this message translates to:
  /// **'Reported cost · USD'**
  String get usageReportedCost;

  /// No description provided for @usageSessions.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get usageSessions;

  /// No description provided for @usageSubagents.
  ///
  /// In en, this message translates to:
  /// **'Subagent conversations'**
  String get usageSubagents;

  /// No description provided for @usagePrompts.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get usagePrompts;

  /// No description provided for @usageSteps.
  ///
  /// In en, this message translates to:
  /// **'Agent steps'**
  String get usageSteps;

  /// No description provided for @usageActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get usageActiveDays;

  /// No description provided for @usageStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak · days'**
  String get usageStreak;

  /// No description provided for @usageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity in this range. Try a wider range or All projects.'**
  String get usageEmpty;

  /// No description provided for @usageTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get usageTokens;

  /// No description provided for @usageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get usageTotalTokens;

  /// No description provided for @usageInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get usageInput;

  /// No description provided for @usageOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get usageOutput;

  /// No description provided for @usageReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get usageReasoning;

  /// No description provided for @usageCacheRead.
  ///
  /// In en, this message translates to:
  /// **'Cache read'**
  String get usageCacheRead;

  /// No description provided for @usageCacheWrite.
  ///
  /// In en, this message translates to:
  /// **'Cache write'**
  String get usageCacheWrite;

  /// No description provided for @usageModels.
  ///
  /// In en, this message translates to:
  /// **'Model usage'**
  String get usageModels;

  /// No description provided for @usageNoModels.
  ///
  /// In en, this message translates to:
  /// **'No model usage was recorded in this range.'**
  String get usageNoModels;

  /// No description provided for @usageCostShare.
  ///
  /// In en, this message translates to:
  /// **'Share of reported cost'**
  String get usageCostShare;

  /// No description provided for @usageToolReliability.
  ///
  /// In en, this message translates to:
  /// **'Tool reliability'**
  String get usageToolReliability;

  /// No description provided for @usageToolsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This response does not include tool reliability.'**
  String get usageToolsUnavailable;

  /// No description provided for @usageNoTools.
  ///
  /// In en, this message translates to:
  /// **'No tool calls were recorded in this range.'**
  String get usageNoTools;

  /// No description provided for @usageNoFinishedTools.
  ///
  /// In en, this message translates to:
  /// **'No finished tool calls yet.'**
  String get usageNoFinishedTools;

  /// No description provided for @usageToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get usageToolCalls;

  /// No description provided for @usageSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get usageSucceeded;

  /// No description provided for @usageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get usageFailed;

  /// No description provided for @usageUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Unfinished'**
  String get usageUnfinished;

  /// No description provided for @usageCostDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Costs are estimates reported by OpenCode, not a provider invoice. Unfinished tool calls are excluded from the success rate.'**
  String get usageCostDisclosure;

  /// No description provided for @usagePeriod.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String usagePeriod(String from, String to);

  /// No description provided for @usageTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone: {timezone}'**
  String usageTimezone(String timezone);

  /// No description provided for @usageModelSteps.
  ///
  /// In en, this message translates to:
  /// **'{steps} steps'**
  String usageModelSteps(String steps);

  /// No description provided for @usageModelTokens.
  ///
  /// In en, this message translates to:
  /// **'{tokens} tokens'**
  String usageModelTokens(String tokens);

  /// No description provided for @usageSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'{rate} of finished calls succeeded'**
  String usageSuccessRate(String rate);

  /// No description provided for @usageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated at {time}'**
  String usageUpdated(String time);

  /// No description provided for @mcpRuntimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Until server restart'**
  String get mcpRuntimeTitle;

  /// No description provided for @mcpRuntimeDescription.
  ///
  /// In en, this message translates to:
  /// **'Adds this MCP server to the selected project and tries to connect it now. It is removed when OpenCode restarts. For permanent setup, edit the server configuration.'**
  String get mcpRuntimeDescription;

  /// No description provided for @mcpCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current project'**
  String get mcpCurrentLocation;

  /// No description provided for @mcpDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'OpenCode server’s default directory'**
  String get mcpDefaultLocation;

  /// No description provided for @mcpWorkspaceLocation.
  ///
  /// In en, this message translates to:
  /// **'Cloud environment: {workspace}'**
  String mcpWorkspaceLocation(String workspace);

  /// No description provided for @mcpLocationChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Your draft is still here; reopen setup in the intended project before adding it.'**
  String get mcpLocationChanged;

  /// No description provided for @mcpAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding MCP server'**
  String get mcpAdding;

  /// No description provided for @mcpAdd.
  ///
  /// In en, this message translates to:
  /// **'Add MCP server'**
  String get mcpAdd;

  /// No description provided for @mcpRuntimeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add tools for the current project until OpenCode restarts.'**
  String get mcpRuntimeEmpty;

  /// No description provided for @mcpRuntimeAdded.
  ///
  /// In en, this message translates to:
  /// **'MCP server added for this project'**
  String get mcpRuntimeAdded;

  /// No description provided for @sessionUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread result'**
  String get sessionUnread;

  /// No description provided for @shareSessionViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync read state'**
  String get shareSessionViewsTitle;

  /// No description provided for @shareSessionViewsOn.
  ///
  /// In en, this message translates to:
  /// **'Let your other OpenCode clients know which completed results you have viewed.'**
  String get shareSessionViewsOn;

  /// No description provided for @shareSessionViewsOff.
  ///
  /// In en, this message translates to:
  /// **'Reading stays private to this device. Unread results use local read history.'**
  String get shareSessionViewsOff;

  /// No description provided for @shareSessionViewsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this preference. Read-state sharing is off on this device for now.'**
  String get shareSessionViewsSaveError;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export conversation'**
  String get exportTitle;

  /// No description provided for @exportDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a format to save this conversation on your device.'**
  String get exportDescription;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Complete conversation · JSON'**
  String get exportJson;

  /// No description provided for @exportJsonDescription.
  ///
  /// In en, this message translates to:
  /// **'Downloads the full conversation from the server, including older messages.'**
  String get exportJsonDescription;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Readable transcript · Markdown'**
  String get exportMarkdown;

  /// No description provided for @exportMarkdownDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves the messages currently loaded in this conversation. Load older messages first if you need them included.'**
  String get exportMarkdownDescription;

  /// No description provided for @exportRedact.
  ///
  /// In en, this message translates to:
  /// **'Redact sensitive data'**
  String get exportRedact;

  /// No description provided for @exportRedactDescription.
  ///
  /// In en, this message translates to:
  /// **'Replaces conversation text and sensitive fields with placeholders. Turn this off to back up the original text. Review any export before sharing.'**
  String get exportRedactDescription;

  /// No description provided for @exportUnredacted.
  ///
  /// In en, this message translates to:
  /// **'The unredacted file may contain secrets, local paths, and private tool output.'**
  String get exportUnredacted;

  /// No description provided for @exportSave.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get exportSave;

  /// No description provided for @exportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get exportCancel;

  /// No description provided for @exportDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading complete conversation…'**
  String get exportDownloading;

  /// No description provided for @exportSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving file…'**
  String get exportSaving;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Conversation saved'**
  String get exportSaved;

  /// No description provided for @exportChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Reopen export from the intended conversation.'**
  String get exportChanged;

  /// No description provided for @exportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support JSON export. You can still save the loaded Markdown transcript.'**
  String get exportUnsupported;

  /// No description provided for @exportAuthorization.
  ///
  /// In en, this message translates to:
  /// **'The server denied access. Check your server credentials and try again.'**
  String get exportAuthorization;

  /// No description provided for @exportMissing.
  ///
  /// In en, this message translates to:
  /// **'This conversation no longer exists on the server. You can still save the loaded Markdown transcript.'**
  String get exportMissing;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the conversation. Check your connection and storage, then try again.'**
  String get exportFailed;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import conversation'**
  String get importTitle;

  /// No description provided for @importDescription.
  ///
  /// In en, this message translates to:
  /// **'Restore a JSON export to this OpenCode server. Choose a file, then review where it will be imported.'**
  String get importDescription;

  /// No description provided for @importChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose JSON file'**
  String get importChoose;

  /// No description provided for @importChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get importChooseAnother;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import conversation'**
  String get importAction;

  /// No description provided for @importUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get importUntitled;

  /// No description provided for @importMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} message records'**
  String importMessageCount(int count);

  /// No description provided for @importRedacted.
  ///
  /// In en, this message translates to:
  /// **'This file contains redacted placeholders. Import cannot recover the original text; use an unredacted export if you need it.'**
  String get importRedacted;

  /// No description provided for @importParent.
  ///
  /// In en, this message translates to:
  /// **'Parent conversation {id} must already exist on this server. Import the parent first.'**
  String importParent(String id);

  /// No description provided for @importArchived.
  ///
  /// In en, this message translates to:
  /// **'This conversation is archived. Import will keep its archived status.'**
  String get importArchived;

  /// No description provided for @importDestination.
  ///
  /// In en, this message translates to:
  /// **'Import into'**
  String get importDestination;

  /// No description provided for @importChooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose a project on this server'**
  String get importChooseDestination;

  /// No description provided for @importChangeDestination.
  ///
  /// In en, this message translates to:
  /// **'Change destination'**
  String get importChangeDestination;

  /// No description provided for @importNoDestinations.
  ///
  /// In en, this message translates to:
  /// **'No projects are available. Open a project on this server, then try again.'**
  String get importNoDestinations;

  /// No description provided for @importDestinationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load destination projects or cloud environments. Try again; your file is still selected.'**
  String get importDestinationFailed;

  /// No description provided for @importPreserves.
  ///
  /// In en, this message translates to:
  /// **'Your source file stays unchanged. Existing conversations are never replaced, and importing does not start an agent run.'**
  String get importPreserves;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Preparing import…'**
  String get importReading;

  /// No description provided for @importSending.
  ///
  /// In en, this message translates to:
  /// **'Importing conversation…'**
  String get importSending;

  /// No description provided for @importSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Conversation imported'**
  String get importSucceeded;

  /// No description provided for @importOpen.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get importOpen;

  /// No description provided for @importOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The conversation was imported, but could not be opened. Find it in All conversations on the destination server.'**
  String get importOpenFailed;

  /// No description provided for @importChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Your file is still here. Reopen import on the intended server before continuing.'**
  String get importChanged;

  /// No description provided for @importUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support JSON import.'**
  String get importUnsupported;

  /// No description provided for @importInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid OpenCode JSON export with conversation information and message records. Markdown transcripts cannot be imported.'**
  String get importInvalidFile;

  /// No description provided for @importTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file exceeds the mobile import limit of 128 MiB. It has not been uploaded or truncated. Use a desktop or server transfer for this file.'**
  String get importTooLarge;

  /// No description provided for @importConflict.
  ///
  /// In en, this message translates to:
  /// **'A conversation with this ID already exists on this server. Nothing was replaced. Find it in All conversations, or import this file on another server.'**
  String get importConflict;

  /// No description provided for @importAuthorization.
  ///
  /// In en, this message translates to:
  /// **'The server denied access. Check your server credentials. Your file is still selected.'**
  String get importAuthorization;

  /// No description provided for @importParentMissing.
  ///
  /// In en, this message translates to:
  /// **'The parent conversation is missing from this server. Import the parent first, then retry this file.'**
  String get importParentMissing;

  /// No description provided for @importRejected.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this export format. Your file is still selected; check that it came from a compatible OpenCode server.'**
  String get importRejected;

  /// No description provided for @importUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Import could not be confirmed. Check All conversations before retrying: the server may have received it. Your source file is unchanged.'**
  String get importUnconfirmed;

  /// No description provided for @sessionsNoOtherRecent.
  ///
  /// In en, this message translates to:
  /// **'No other recent conversations'**
  String get sessionsNoOtherRecent;

  /// No description provided for @sessionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin on this device'**
  String get sessionPin;

  /// No description provided for @sessionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sessionUnpin;

  /// No description provided for @sessionPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get sessionPinned;

  /// No description provided for @sessionPinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this pin. Check device storage and that the conversation’s project has not changed, then try again.'**
  String get sessionPinFailed;

  /// No description provided for @sessionPinsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Some pinned conversations could not be loaded. Refresh to try again.'**
  String get sessionPinsLoadFailed;

  /// No description provided for @promptStashSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this prompt. Your composer is unchanged. Check device storage and try again.'**
  String get promptStashSaveFailed;

  /// No description provided for @promptOriginalDraft.
  ///
  /// In en, this message translates to:
  /// **'Restore original draft'**
  String get promptOriginalDraft;

  /// No description provided for @promptStashTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved prompts'**
  String get promptStashTitle;

  /// Search local saved prompt text, attachment names, references and locations without loading attachment payloads
  ///
  /// In en, this message translates to:
  /// **'Search saved prompts'**
  String get promptStashSearch;

  /// Filtered saved-prompts empty state, distinct from an empty stash
  ///
  /// In en, this message translates to:
  /// **'No saved prompts match your search. Clear or change the search to see more.'**
  String get promptStashNoMatches;

  /// No description provided for @promptStashDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this saved prompt. Try again.'**
  String get promptStashDeleteFailed;

  /// No description provided for @promptRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore saved prompt?'**
  String get promptRestoreTitle;

  /// No description provided for @promptRestorePreserve.
  ///
  /// In en, this message translates to:
  /// **'Your current prompt will be saved to the stash first, including its attachments and references.'**
  String get promptRestorePreserve;

  /// No description provided for @promptStashDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get promptStashDelete;

  /// No description provided for @promptStashFull.
  ///
  /// In en, this message translates to:
  /// **'Your stash has 50 prompts. Delete a saved prompt to make room; your current prompt is unchanged.'**
  String get promptStashFull;

  /// No description provided for @promptStashListDescription.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device for this server. Restoring a prompt also saves any current prompt for later.'**
  String get promptStashListDescription;

  /// No description provided for @promptStashDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete saved prompt?'**
  String get promptStashDeleteTitle;

  /// No description provided for @promptStashAttachments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment} other{{count} attachments}}'**
  String promptStashAttachments(int count);

  /// No description provided for @promptStashReferences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reference} other{{count} references}}'**
  String promptStashReferences(int count);

  /// No description provided for @promptRestoredCopyKept.
  ///
  /// In en, this message translates to:
  /// **'Available content restored. A saved copy remains in your stash. Review attachments and references before sending.'**
  String get promptRestoredCopyKept;

  /// No description provided for @promptAttachmentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some attachments cannot be restored'**
  String get promptAttachmentsUnavailable;

  /// No description provided for @promptRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get promptRestore;

  /// No description provided for @promptHistorySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Prompt sent, but its history could not be saved on this device.'**
  String get promptHistorySaveFailed;

  /// No description provided for @promptAttachmentsUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Missing, damaged or temporary attachments: {names}. Restore the available content and reattach these files before sending. The saved copy will stay in your stash.'**
  String promptAttachmentsUnavailableDetail(String names);

  /// No description provided for @promptStashMigrationPending.
  ///
  /// In en, this message translates to:
  /// **'Some saved attachments could not be moved to local attachment storage yet. Your saved content has been kept. Free device storage and retry.'**
  String get promptStashMigrationPending;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @shareWaitingForServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server and the shared text opens in a new conversation.'**
  String get shareWaitingForServer;

  /// No description provided for @shareSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Shared text kept. Could not open a conversation. Retry when the connection is ready.'**
  String get shareSessionFailed;

  /// No description provided for @webSourcesDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Web search is not available through this server’s app gateway. Paste a public URL and optionally an excerpt you want to include. No page is fetched. Nothing is sent to the model here.'**
  String get webSourcesDisclosure;

  /// No description provided for @webSourcesScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'Server changed. Close and reopen Add web source.'**
  String get webSourcesScopeChanged;

  /// No description provided for @webSourcesUrl.
  ///
  /// In en, this message translates to:
  /// **'Public URL'**
  String get webSourcesUrl;

  /// No description provided for @webSourcesLabel.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get webSourcesLabel;

  /// No description provided for @webSourcesExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Pasted excerpt (optional)'**
  String get webSourcesExcerpt;

  /// No description provided for @webSourcesExcerptHint.
  ///
  /// In en, this message translates to:
  /// **'User-provided text, not verified page content.'**
  String get webSourcesExcerptHint;

  /// No description provided for @webSourcesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to review'**
  String get webSourcesAdd;

  /// No description provided for @webSourcesReviewCount.
  ///
  /// In en, this message translates to:
  /// **'Review sources ({count}/10)'**
  String webSourcesReviewCount(int count);

  /// No description provided for @webSourcesReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Only checked sources will be returned to your draft.'**
  String get webSourcesReviewHint;

  /// No description provided for @webSourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sources added yet.'**
  String get webSourcesEmpty;

  /// No description provided for @webSourcesOpen.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get webSourcesOpen;

  /// No description provided for @webSourcesUseCount.
  ///
  /// In en, this message translates to:
  /// **'Use selected sources ({count})'**
  String webSourcesUseCount(int count);

  /// No description provided for @digestTitle.
  ///
  /// In en, this message translates to:
  /// **'Completion digests'**
  String get digestTitle;

  /// No description provided for @digestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On demand · cached metadata, not AI summaries'**
  String get digestSubtitle;

  /// No description provided for @digestEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ended-run metadata available in this project. Idle alone does not establish successful completion.'**
  String get digestEmpty;

  /// No description provided for @digestIdle.
  ///
  /// In en, this message translates to:
  /// **'Server idle recorded · outcome unverified'**
  String get digestIdle;

  /// Completion digest status; idle does not prove a successful run
  ///
  /// In en, this message translates to:
  /// **'Server reported idle. Success or failure is not verified.'**
  String get digestStatusUnverified;

  /// The server did not provide a session-wide changed-file total
  ///
  /// In en, this message translates to:
  /// **'Changed files: unknown.'**
  String get digestChangedFilesUnknown;

  /// Session-wide changed-file total; it is not evidence for this run
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No changed files in the conversation total; this run is unknown.} one {1 changed file in the conversation total; this run is unknown.} other {{count} changed files in the conversation total; this run is unknown.}}'**
  String digestChangedFiles(int count);

  /// The pending-request snapshot is unavailable
  ///
  /// In en, this message translates to:
  /// **'Pending decisions: unknown.'**
  String get digestPendingDecisionsUnknown;

  /// Known pending-request count from the current cache
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No pending decisions in the current cache.} one {1 pending decision in the current cache.} other {{count} pending decisions in the current cache.}}'**
  String digestPendingDecisions(int count);

  /// The metadata-only digest does not report tool outcomes or remaining tasks
  ///
  /// In en, this message translates to:
  /// **'Tool outcomes and remaining tasks: unknown.'**
  String get digestOutcomesUnknown;

  /// Provenance disclosure for a metadata-only completion digest
  ///
  /// In en, this message translates to:
  /// **'Cached server metadata only. No AI summary or model call. Open the conversation to verify results and review changes or tasks.'**
  String get digestProvenance;

  /// No description provided for @digestOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get digestOpenConversation;

  /// No description provided for @digestReview.
  ///
  /// In en, this message translates to:
  /// **'Review next actions'**
  String get digestReview;

  /// No description provided for @digestCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy digest'**
  String get digestCopy;

  /// Accessible confirmation after a completion digest is copied
  ///
  /// In en, this message translates to:
  /// **'Digest copied'**
  String get digestCopySucceeded;

  /// No description provided for @digestCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy digest'**
  String get digestCopyFailed;

  /// No description provided for @digestDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get digestDismiss;

  /// Completion digest action opening the latest run's server-recorded outcome and tool evidence
  ///
  /// In en, this message translates to:
  /// **'Run results'**
  String get digestRunResults;

  /// No description provided for @runResultsScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Close this view and reopen Run results from the intended project.'**
  String get runResultsScopeChanged;

  /// No description provided for @runResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Run results'**
  String get runResultsTitle;

  /// Run results empty state: the newest user message has no assistant reply after it
  ///
  /// In en, this message translates to:
  /// **'The latest turn has no assistant step yet, so there is nothing to show.'**
  String get runResultsEmpty;

  /// Run identity header; the id is the tail of the first assistant message id
  ///
  /// In en, this message translates to:
  /// **'Run …{id}'**
  String runResultsRunLabel(String id);

  /// No description provided for @runResultsSteps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 assistant step} other {{count} assistant steps}}'**
  String runResultsSteps(int count);

  /// Step count when the run's start was not found in the loaded history
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {At least 1 assistant step loaded} other {At least {count} assistant steps loaded}}'**
  String runResultsStepsAtLeast(int count);

  /// No description provided for @runResultsStarted.
  ///
  /// In en, this message translates to:
  /// **'Started {time}'**
  String runResultsStarted(String time);

  /// No description provided for @runResultsStartedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Start time not recorded'**
  String get runResultsStartedUnknown;

  /// No description provided for @runResultsFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished {time}'**
  String runResultsFinished(String time);

  /// No description provided for @runResultsFinishedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Finish time not recorded'**
  String get runResultsFinishedUnknown;

  /// Shown when the bounded page walk never reached the latest user message
  ///
  /// In en, this message translates to:
  /// **'The message that started this run was not found in the loaded history. Counts here are lower bounds and the run id is only the oldest loaded step.'**
  String get runResultsPartialHistory;

  /// No description provided for @runResultsOutcomeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get runResultsOutcomeCompleted;

  /// No description provided for @runResultsOutcomeCutOff.
  ///
  /// In en, this message translates to:
  /// **'Cut off by the provider'**
  String get runResultsOutcomeCutOff;

  /// No description provided for @runResultsOutcomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get runResultsOutcomeFailed;

  /// No description provided for @runResultsOutcomeAborted.
  ///
  /// In en, this message translates to:
  /// **'Aborted'**
  String get runResultsOutcomeAborted;

  /// No description provided for @runResultsOutcomeRunning.
  ///
  /// In en, this message translates to:
  /// **'Still running'**
  String get runResultsOutcomeRunning;

  /// The newest step completed but the provider gave no recognised finish reason
  ///
  /// In en, this message translates to:
  /// **'Outcome not reported'**
  String get runResultsOutcomeNotReported;

  /// Raw finish reason copied from the assistant message
  ///
  /// In en, this message translates to:
  /// **'Provider finish reason: {finish}'**
  String runResultsFinishReason(String finish);

  /// No description provided for @runResultsFinishReasonMissing.
  ///
  /// In en, this message translates to:
  /// **'The provider gave no finish reason.'**
  String get runResultsFinishReasonMissing;

  /// No description provided for @runResultsEarlierErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {An earlier step reported an error; the newest step decides the outcome.} other {{count} earlier steps reported errors; the newest step decides the outcome.}}'**
  String runResultsEarlierErrors(int count);

  /// The controller saw the message.updated completion event for exactly this step
  ///
  /// In en, this message translates to:
  /// **'This phone received the completion of the newest step live.'**
  String get runResultsObservedLive;

  /// No live completion event for this exact step was received on this connection
  ///
  /// In en, this message translates to:
  /// **'Recovered from server history. This phone did not observe the newest step complete.'**
  String get runResultsFromHistory;

  /// No description provided for @runResultsNoToolEvidence.
  ///
  /// In en, this message translates to:
  /// **'This run recorded no tool calls, so there is no file or command evidence. That is not the same as no changes.'**
  String get runResultsNoToolEvidence;

  /// No description provided for @runResultsChangedFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Changed files'**
  String get runResultsChangedFilesTitle;

  /// No description provided for @runResultsChangedFilesSource.
  ///
  /// In en, this message translates to:
  /// **'From completed edit, write and patch tools in this run. Not a verified diff of the working tree.'**
  String get runResultsChangedFilesSource;

  /// No description provided for @runResultsNoChangedFiles.
  ///
  /// In en, this message translates to:
  /// **'No completed file-changing tool in this run.'**
  String get runResultsNoChangedFiles;

  /// No description provided for @runResultsChangeEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get runResultsChangeEdited;

  /// No description provided for @runResultsChangeWritten.
  ///
  /// In en, this message translates to:
  /// **'Written'**
  String get runResultsChangeWritten;

  /// No description provided for @runResultsChangePatched.
  ///
  /// In en, this message translates to:
  /// **'Patched'**
  String get runResultsChangePatched;

  /// No description provided for @runResultsCommandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get runResultsCommandsTitle;

  /// No description provided for @runResultsCommandsSource.
  ///
  /// In en, this message translates to:
  /// **'From bash and shell tools in this run. Exit codes appear only when the server recorded them.'**
  String get runResultsCommandsSource;

  /// No description provided for @runResultsNoCommands.
  ///
  /// In en, this message translates to:
  /// **'No commands were run in this run.'**
  String get runResultsNoCommands;

  /// No description provided for @runResultsCommandEmpty.
  ///
  /// In en, this message translates to:
  /// **'(command text not recorded)'**
  String get runResultsCommandEmpty;

  /// No description provided for @runResultsExit.
  ///
  /// In en, this message translates to:
  /// **'Exit code {code}'**
  String runResultsExit(int code);

  /// No description provided for @runResultsExitUnknown.
  ///
  /// In en, this message translates to:
  /// **'Exit code not recorded'**
  String get runResultsExitUnknown;

  /// No description provided for @runResultsCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Tool reported failure'**
  String get runResultsCommandFailed;

  /// Source-derived label; says nothing about whether tests ran or passed
  ///
  /// In en, this message translates to:
  /// **'Looks like a test command (from the command text only)'**
  String get runResultsLooksLikeTest;

  /// No description provided for @runResultsOutputPruned.
  ///
  /// In en, this message translates to:
  /// **'Output pruned by the server'**
  String get runResultsOutputPruned;

  /// No description provided for @runResultsPrunedTools.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 tool output was pruned by the server and cannot be opened.} other {{count} tool outputs were pruned by the server and cannot be opened.}}'**
  String runResultsPrunedTools(int count);

  /// No description provided for @runResultsTruncated.
  ///
  /// In en, this message translates to:
  /// **'Lists are capped at 50 entries. Open the conversation for the rest.'**
  String get runResultsTruncated;

  /// No description provided for @runResultsSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Everything here is copied from the server\'s message and tool records. Nothing is summarised by a model.'**
  String get runResultsSourceNote;

  /// No description provided for @runResultsOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Recorded tool output'**
  String get runResultsOutputTitle;

  /// No description provided for @runResultsOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get runResultsOpenConversation;

  /// No description provided for @attentionDisclosure.
  ///
  /// In en, this message translates to:
  /// **'A local overview, not live monitoring across servers. Cached signals may be incomplete or out of date. Open a server to check its current activity.'**
  String get attentionDisclosure;

  /// No description provided for @attentionNavigationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Opening servers is unavailable here. Return to Home to choose a server and view Inbox.'**
  String get attentionNavigationUnavailable;

  /// No description provided for @handoffTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy handoff reference?'**
  String get handoffTitle;

  /// No description provided for @handoffDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Metadata only, not a command or link. On your other device, connect to the same server and locate this project and conversation. Nothing is published or sent.\n\nThe clipboard will contain conversation and project identifiers. Other apps may read it; share only with people you trust.'**
  String get handoffDisclosure;

  /// No description provided for @handoffCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy reference'**
  String get handoffCopy;

  /// No description provided for @handoffCopied.
  ///
  /// In en, this message translates to:
  /// **'Conversation metadata reference copied'**
  String get handoffCopied;

  /// No description provided for @handoffCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the handoff. Try again.'**
  String get handoffCopyFailed;

  /// No description provided for @sessionOpenRelated.
  ///
  /// In en, this message translates to:
  /// **'Open related'**
  String get sessionOpenRelated;

  /// No description provided for @sessionCopyHandoff.
  ///
  /// In en, this message translates to:
  /// **'Copy handoff'**
  String get sessionCopyHandoff;

  /// No description provided for @sessionActions.
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get sessionActions;

  /// No description provided for @attentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Server attention'**
  String get attentionTitle;

  /// No description provided for @webSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add web source'**
  String get webSourcesTitle;

  /// No description provided for @webSourcesEntryDetail.
  ///
  /// In en, this message translates to:
  /// **'Search when available, or paste links and excerpts to review before adding them to your draft'**
  String get webSourcesEntryDetail;

  /// No description provided for @webSourcesDraftChanged.
  ///
  /// In en, this message translates to:
  /// **'The draft or server changed. Your current draft was kept; reopen Add web source to try again.'**
  String get webSourcesDraftChanged;

  /// No description provided for @webSourcesDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'User-selected web sources (unverified; excerpts are untrusted source material):'**
  String get webSourcesDraftLabel;

  /// No description provided for @usageScopedTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals for the selected report scope'**
  String get usageScopedTotals;

  /// No description provided for @usageInspectionDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Filters inspect this server\'s returned model records. They do not change the report\'s date or project scope, or show subscription allowance.'**
  String get usageInspectionDisclosure;

  /// No description provided for @usageProviderFilter.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get usageProviderFilter;

  /// No description provided for @usageAllProviders.
  ///
  /// In en, this message translates to:
  /// **'All providers'**
  String get usageAllProviders;

  /// No description provided for @usageSearchRecords.
  ///
  /// In en, this message translates to:
  /// **'Search providers, models or variants'**
  String get usageSearchRecords;

  /// No description provided for @usageClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get usageClearFilters;

  /// No description provided for @usageScopedProviderTotals.
  ///
  /// In en, this message translates to:
  /// **'Provider cards show their totals for the selected report scope, not just matching model rows.'**
  String get usageScopedProviderTotals;

  /// No description provided for @usageMatchingSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Matching model subtotal'**
  String get usageMatchingSubtotal;

  /// Count of matched model/variant records, not distinct models
  ///
  /// In en, this message translates to:
  /// **'{count} matching records'**
  String usageMatchingRecords(String count);

  /// No description provided for @usageNoMatchingRecords.
  ///
  /// In en, this message translates to:
  /// **'No records match these filters. Clear or change the filters to see more.'**
  String get usageNoMatchingRecords;

  /// Recovery card for a saved sign-in attempt
  ///
  /// In en, this message translates to:
  /// **'Pending sign-in: {integration}'**
  String pendingAuthTitle(String integration);

  /// No description provided for @pendingAuthDetail.
  ///
  /// In en, this message translates to:
  /// **'Continue the existing browser sign-in, then explicitly check its status or enter its code. The browser link is not saved.'**
  String get pendingAuthDetail;

  /// No description provided for @pendingAuthResume.
  ///
  /// In en, this message translates to:
  /// **'Resume / check sign-in'**
  String get pendingAuthResume;

  /// No description provided for @pendingAuthEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get pendingAuthEnterCode;

  /// No description provided for @pendingAuthComplete.
  ///
  /// In en, this message translates to:
  /// **'Sign-in complete.'**
  String get pendingAuthComplete;

  /// No description provided for @pendingAuthStillPending.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is still pending. No new attempt was started.'**
  String get pendingAuthStillPending;

  /// No description provided for @pendingAuthServerFailed.
  ///
  /// In en, this message translates to:
  /// **'The server reported that sign-in failed. Provider error details are hidden.'**
  String get pendingAuthServerFailed;

  /// No description provided for @pendingAuthExpired.
  ///
  /// In en, this message translates to:
  /// **'This attempt is expired or outside the device’s recovery window. Cancellation is a separate server action.'**
  String get pendingAuthExpired;

  /// No description provided for @pendingAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the action. Check pending sign-ins before trying again. No new sign-in was started.'**
  String get pendingAuthFailed;

  /// No description provided for @pendingAuthSaveUncertain.
  ///
  /// In en, this message translates to:
  /// **'Recovery could not be saved reliably. Keep this app open and retry saving; restarting may lose this attempt. If no browser page opened, cancel the attempt before starting again.'**
  String get pendingAuthSaveUncertain;

  /// No description provided for @pendingAuthRetrySave.
  ///
  /// In en, this message translates to:
  /// **'Try saving recovery again'**
  String get pendingAuthRetrySave;

  /// No description provided for @pendingAuthForget.
  ///
  /// In en, this message translates to:
  /// **'Forget on this device'**
  String get pendingAuthForget;

  /// No description provided for @pendingAuthForgetDetail.
  ///
  /// In en, this message translates to:
  /// **'Remove only this device’s recovery record? This does not cancel a server command, revoke credentials, or finish authorization. The server attempt may keep running until it expires.'**
  String get pendingAuthForgetDetail;

  /// No description provided for @pendingAuthUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server cannot recover earlier sign-ins. Legacy sign-ins work only while their original screen and connection remain available.'**
  String get pendingAuthUnsupported;

  /// No description provided for @pendingAuthOtherSource.
  ///
  /// In en, this message translates to:
  /// **'Other pending sign-ins belong to another server or project. Return to their original source to manage them.'**
  String get pendingAuthOtherSource;

  /// No description provided for @connectionHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection help'**
  String get connectionHelpTitle;

  /// No description provided for @connectionHelpEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explain an address locally, without connecting'**
  String get connectionHelpEntrySubtitle;

  /// No description provided for @connectionHelpGuideTip.
  ///
  /// In en, this message translates to:
  /// **'Keep the server off the public internet. Use private HTTPS or an encrypted tunnel ending on the device running this app. Localhost on your computer is not localhost on your phone. Open Connection help above for steps and examples.'**
  String get connectionHelpGuideTip;

  /// No description provided for @connectionHelpPrivacy.
  ///
  /// In en, this message translates to:
  /// **'This checks address rules only, not connectivity. Nothing is sent or saved. Input is hidden and cleared after checking. Paste only an address, not a password or pairing code.'**
  String get connectionHelpPrivacy;

  /// No description provided for @connectionHelpAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectionHelpAddress;

  /// No description provided for @connectionHelpCheck.
  ///
  /// In en, this message translates to:
  /// **'Explain address'**
  String get connectionHelpCheck;

  /// No description provided for @connectionHelpEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a server address to explain.'**
  String get connectionHelpEmpty;

  /// No description provided for @connectionHelpMalformed.
  ///
  /// In en, this message translates to:
  /// **'This address could not be understood. Use a complete origin such as https://server.example, with no path, credentials or query.'**
  String get connectionHelpMalformed;

  /// No description provided for @connectionHelpCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials do not belong in a URL. Remove them and enter the server username and password separately in Servers. The pasted value has been cleared.'**
  String get connectionHelpCredentials;

  /// No description provided for @connectionHelpQuery.
  ///
  /// In en, this message translates to:
  /// **'Remove query parameters and fragments. They can contain secrets; enter only the server origin. The pasted value has been cleared.'**
  String get connectionHelpQuery;

  /// No description provided for @connectionHelpPath.
  ///
  /// In en, this message translates to:
  /// **'Remove the path. This app needs the server origin, not a page or API route.'**
  String get connectionHelpPath;

  /// No description provided for @connectionHelpScheme.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS for a remote server, or HTTP only for this device\'s supported loopback addresses.'**
  String get connectionHelpScheme;

  /// No description provided for @connectionHelpRemoteHttp.
  ///
  /// In en, this message translates to:
  /// **'Remote HTTP is blocked, including LAN and 100.64.0.0/10 addresses. A VPN does not change this rule. Set up private HTTPS or an encrypted tunnel ending on this device.'**
  String get connectionHelpRemoteHttp;

  /// No description provided for @connectionHelpHttps.
  ///
  /// In en, this message translates to:
  /// **'This address passes the HTTPS address rules. That does not verify its certificate, reachability, sign-in or privacy. A bare remote address is interpreted as HTTPS.'**
  String get connectionHelpHttps;

  /// No description provided for @connectionHelpLoopback.
  ///
  /// In en, this message translates to:
  /// **'This address passes the loopback address rules. Localhost means this device, not another computer. A server or tunnel must be listening here; this check does not verify that.'**
  String get connectionHelpLoopback;

  /// No description provided for @connectionHelpPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private HTTPS or reverse proxy'**
  String get connectionHelpPrivateTitle;

  /// No description provided for @connectionHelpPrivateSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Keep the server on its host\'s loopback with authentication enabled.\n2. Connect both devices to your private network and restrict access to intended users.\n3. Configure private HTTPS, such as Tailscale Serve, or a reverse proxy with a trusted certificate forwarding to the server. Support streaming and WebSockets.\n4. Add the HTTPS origin in Servers with sign-in in separate fields.\nTailscale Funnel exposes the service publicly; it is not a private-network fix. This app cannot infer VPN presence. The example below is a placeholder.'**
  String get connectionHelpPrivateSteps;

  /// No description provided for @connectionHelpTunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Localhost on the wrong device?'**
  String get connectionHelpTunnelTitle;

  /// No description provided for @connectionHelpTunnelSteps.
  ///
  /// In en, this message translates to:
  /// **'Localhost, 127.0.0.1 and [::1] refer to the device running this app. For a server on another computer, use private HTTPS or an encrypted tunnel ending here. If an SSH client is available on this device, adapt the example below, verify the host key and keep it running. Replace user@host with your SSH destination. Running it on another computer does not forward this device\'s port. Keep server authentication enabled.'**
  String get connectionHelpTunnelSteps;

  /// No description provided for @connectionHelpVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify connectivity separately'**
  String get connectionHelpVerifyTitle;

  /// No description provided for @connectionHelpVerifySteps.
  ///
  /// In en, this message translates to:
  /// **'On this device, check private-network membership, DNS, firewall access and certificate trust using your network tools. Check server and proxy configuration on the host, then use Servers to connect. Never disable TLS verification or share passwords, pairing codes or unredacted logs. Access to this server is shell access.'**
  String get connectionHelpVerifySteps;

  /// No description provided for @connectionHelpCopyExample.
  ///
  /// In en, this message translates to:
  /// **'Copy example'**
  String get connectionHelpCopyExample;

  /// No description provided for @connectionHelpCopied.
  ///
  /// In en, this message translates to:
  /// **'Example copied'**
  String get connectionHelpCopied;

  /// No description provided for @connectionHelpCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the example. Select the example text to copy it manually.'**
  String get connectionHelpCopyFailed;

  /// No description provided for @voiceConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice conversation'**
  String get voiceConversationTitle;

  /// No description provided for @voiceConversationDescription.
  ///
  /// In en, this message translates to:
  /// **'Listen, review, then Send. No automatic listening; replies are read aloud only if you turn that on.'**
  String get voiceConversationDescription;

  /// No description provided for @voiceConversationSpeakReplies.
  ///
  /// In en, this message translates to:
  /// **'Speak replies'**
  String get voiceConversationSpeakReplies;

  /// No description provided for @voiceConversationSpeakRepliesDetail.
  ///
  /// In en, this message translates to:
  /// **'Read a matched reply once after Send. Tap Listen to use the microphone.'**
  String get voiceConversationSpeakRepliesDetail;

  /// No description provided for @voiceConversationWaitingReply.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the reply…'**
  String get voiceConversationWaitingReply;

  /// No description provided for @voiceConversationSpeakingReply.
  ///
  /// In en, this message translates to:
  /// **'Speaking the reply'**
  String get voiceConversationSpeakingReply;

  /// No description provided for @voiceConversationStopReply.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get voiceConversationStopReply;

  /// No description provided for @voiceConversationReadReply.
  ///
  /// In en, this message translates to:
  /// **'Read reply'**
  String get voiceConversationReadReply;

  /// No description provided for @voiceConversationReplyReviewNeeded.
  ///
  /// In en, this message translates to:
  /// **'The reply finished, but it could not be matched to your message for certain. Read it if you want.'**
  String get voiceConversationReplyReviewNeeded;

  /// No description provided for @voiceConversationReplyInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The reply needed a decision on screen, so it was not read automatically.'**
  String get voiceConversationReplyInterrupted;

  /// No description provided for @voiceConversationReplyNoProse.
  ///
  /// In en, this message translates to:
  /// **'The reply has no prose to read. Code and tool details are not spoken.'**
  String get voiceConversationReplyNoProse;

  /// No description provided for @voiceConversationReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'The reply could not be read aloud.'**
  String get voiceConversationReplyFailed;

  /// No description provided for @voiceConversationPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice conversation paused'**
  String get voiceConversationPausedTitle;

  /// No description provided for @voiceConversationPausedDetail.
  ///
  /// In en, this message translates to:
  /// **'Voice conversation is paused. Reconnect, wait for the reply, or review pending decisions on screen.'**
  String get voiceConversationPausedDetail;

  /// No description provided for @voiceConversationDraftFirst.
  ///
  /// In en, this message translates to:
  /// **'Send, save, or clear your current draft before starting voice conversation.'**
  String get voiceConversationDraftFirst;

  /// No description provided for @voiceConversationListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get voiceConversationListen;

  /// No description provided for @voiceConversationExit.
  ///
  /// In en, this message translates to:
  /// **'Exit voice mode'**
  String get voiceConversationExit;

  /// No description provided for @voiceConversationCommandsOnly.
  ///
  /// In en, this message translates to:
  /// **'Use the typed composer for slash commands.'**
  String get voiceConversationCommandsOnly;

  /// No description provided for @voiceConversationInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Voice conversation was interrupted. Review before sending again.'**
  String get voiceConversationInterrupted;

  /// No description provided for @voiceReviewExplicitAction.
  ///
  /// In en, this message translates to:
  /// **'Edit before inserting. Sending always requires an explicit action.'**
  String get voiceReviewExplicitAction;

  /// No description provided for @voiceInputInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Voice input was interrupted. Close and start again when ready.'**
  String get voiceInputInterrupted;

  /// No description provided for @voiceInputClose.
  ///
  /// In en, this message translates to:
  /// **'Close voice input'**
  String get voiceInputClose;

  /// No description provided for @voiceInputUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input is unavailable. Check the local model and microphone settings.'**
  String get voiceInputUnavailable;

  /// No description provided for @voiceConversationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Review and insert your transcript, then tap Send in the composer. Replies are read aloud only while Speak replies is on, and only the reply to what you just sent. Unsent text is discarded when you leave voice mode, the conversation, or the app.'**
  String get voiceConversationInstructions;

  /// No description provided for @desktopDropFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not attach dropped files'**
  String get desktopDropFailedTitle;

  /// No description provided for @desktopDropFailedRecovery.
  ///
  /// In en, this message translates to:
  /// **'Check the attachments already added before trying again. You can also use the keyboard to open Add, then Attach file.'**
  String get desktopDropFailedRecovery;

  /// No description provided for @desktopContextMenuShortcutKeys.
  ///
  /// In en, this message translates to:
  /// **'Right click / Shift + F10 / Menu'**
  String get desktopContextMenuShortcutKeys;

  /// Open or resume server-side command sign-in even when the provider already has a connection
  ///
  /// In en, this message translates to:
  /// **'Server sign-in'**
  String get commandAuthManage;

  /// Command authentication runs server-side; do not imply an app shell or browser flow
  ///
  /// In en, this message translates to:
  /// **'Runs the provider\'s sign-in method on your selected server, not on this phone. You may need to finish interactive steps on the server.'**
  String get commandAuthMethodHint;

  /// Explicit consent before executing a server-side authentication method
  ///
  /// In en, this message translates to:
  /// **'Start sign-in on the server?'**
  String get commandAuthConfirmTitle;

  /// Trust boundary of executable provider authentication
  ///
  /// In en, this message translates to:
  /// **'OpenCode will execute this provider\'s declared sign-in method on the selected server. Continue only if you trust that server and provider. The app does not run or copy a shell command on your phone.'**
  String get commandAuthConfirmDetail;

  /// Launch a command authentication attempt after confirmation
  ///
  /// In en, this message translates to:
  /// **'Start server sign-in'**
  String get commandAuthStart;

  /// Pending status without fabricated instructions or automatic cancellation
  ///
  /// In en, this message translates to:
  /// **'Sign-in is pending on the server. Finish any server-side interaction, then check its status. Closing this sheet does not cancel it.'**
  String get commandAuthPending;

  /// Read the pinned command-auth attempt status
  ///
  /// In en, this message translates to:
  /// **'Check sign-in'**
  String get commandAuthCheck;

  /// Cancel the selected command-auth attempt, not all credentials
  ///
  /// In en, this message translates to:
  /// **'Cancel sign-in'**
  String get commandAuthCancel;

  /// Safe failure without raw provider logs or tokens
  ///
  /// In en, this message translates to:
  /// **'Could not complete or confirm server sign-in. Check the existing attempt before starting another.'**
  String get commandAuthFailed;

  /// Terminal status reported by the server, not proof of a particular active credential
  ///
  /// In en, this message translates to:
  /// **'The server reported that sign-in completed. Refresh Providers to see its current connections.'**
  String get commandAuthComplete;

  /// Server-reported terminal expiry
  ///
  /// In en, this message translates to:
  /// **'This sign-in attempt expired. You can start a new attempt.'**
  String get commandAuthExpired;

  /// Reject actions against the wrong provider authentication scope
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Return to the original project and reopen sign-in to manage its attempt.'**
  String get commandAuthScopeChanged;

  /// Unknown dispatch outcome blocks duplicate executable auth attempts
  ///
  /// In en, this message translates to:
  /// **'The server may have started sign-in, but the app could not safely recover its attempt. Check on the server before retrying; automatic restart is blocked to avoid duplicate processes.'**
  String get commandAuthUncertainStart;

  /// Explicitly read the loaded assistant reply, excluding code and tool details
  ///
  /// In en, this message translates to:
  /// **'Read reply prose'**
  String get readAloudAction;

  /// Visible control that stops speech or cancels pending speech setup
  ///
  /// In en, this message translates to:
  /// **'Stop reading aloud'**
  String get readAloudStop;

  /// Choose another installed voice and read the selected reply
  ///
  /// In en, this message translates to:
  /// **'Read with another voice'**
  String get readAloudOtherVoice;

  /// Picker of installed system voices marked offline
  ///
  /// In en, this message translates to:
  /// **'Choose a reading voice'**
  String get readAloudChooseVoice;

  /// Consent before any system speech engine access
  ///
  /// In en, this message translates to:
  /// **'Use the system speech engine?'**
  String get readAloudConsentTitle;

  /// Discloses external engine access and audible output without promising network isolation
  ///
  /// In en, this message translates to:
  /// **'The loaded reply prose will be sent to your system speech engine. Only voices marked offline are offered, but the engine is separate software and its privacy practices apply. Code blocks and tool details are omitted. Others may hear the audio. Playback stops when this conversation is covered or the app goes into the background.'**
  String get readAloudConsentDetail;

  /// Accept speech disclosure and request installed voice metadata
  ///
  /// In en, this message translates to:
  /// **'Choose voice'**
  String get readAloudContinue;

  /// Unsupported platform, without native calls
  ///
  /// In en, this message translates to:
  /// **'Read-aloud is not available on this platform.'**
  String get readAloudUnsupported;

  /// No automatic engine or model installation is performed
  ///
  /// In en, this message translates to:
  /// **'No installed voice marked offline is available. Configure an offline voice in your system speech settings and try again.'**
  String get readAloudNoVoice;

  /// Safe system speech failure without spoken text or raw engine errors
  ///
  /// In en, this message translates to:
  /// **'The speech engine could not read this reply. Try again or choose another voice.'**
  String get readAloudUnavailable;

  /// Bounded speech input is rejected rather than silently truncated
  ///
  /// In en, this message translates to:
  /// **'This reply is too long to read aloud. Choose a shorter reply.'**
  String get readAloudTooLong;

  /// Audio focus or microphone conflict prevents playback
  ///
  /// In en, this message translates to:
  /// **'Speech playback is unavailable while audio capture or another audio interruption is active.'**
  String get readAloudBusy;

  /// Explicit empty prose result without invoking a speech engine
  ///
  /// In en, this message translates to:
  /// **'There is no reply prose to read. Code and tool details are not spoken.'**
  String get readAloudNoProse;

  /// Open individual saved provider credential management
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get credentialManage;

  /// Describes the metadata-only credential list
  ///
  /// In en, this message translates to:
  /// **'Only saved account labels are shown. API keys and login tokens stay on your server.'**
  String get credentialMetadataOnly;

  /// Cold start or stream gap cannot establish an active credential
  ///
  /// In en, this message translates to:
  /// **'Active account unknown. The saved-account list does not report which account is active.'**
  String get credentialActiveUnknown;

  /// An explicit nullable credential-switched event reported no active credential
  ///
  /// In en, this message translates to:
  /// **'The server reported no active saved account.'**
  String get credentialNoneActive;

  /// Distinguishes event-confirmed activation from a successful command response
  ///
  /// In en, this message translates to:
  /// **'The Active badge reflects the latest server event.'**
  String get credentialActiveObserved;

  /// Live-region feedback after a valid credential-switched event
  ///
  /// In en, this message translates to:
  /// **'Active account updated from the server.'**
  String get credentialActiveUpdated;

  /// Accepted but unconfirmed activation, without an indefinite spinner or invented badge
  ///
  /// In en, this message translates to:
  /// **'Switch requested. This request has not yet been confirmed by a server event.'**
  String get credentialSwitchRequested;

  /// Server-event-confirmed active saved credential badge
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get credentialActive;

  /// Request activation of one saved provider credential
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get credentialSetActive;

  /// Edit a saved credential label, not its secret
  ///
  /// In en, this message translates to:
  /// **'Rename account'**
  String get credentialRename;

  /// Single-line saved credential label input
  ///
  /// In en, this message translates to:
  /// **'Account label'**
  String get credentialLabel;

  /// Submit only the edited credential label
  ///
  /// In en, this message translates to:
  /// **'Save label'**
  String get credentialSave;

  /// Destructive confirmation naming the saved provider credential
  ///
  /// In en, this message translates to:
  /// **'Remove {label}?'**
  String credentialRemoveTitle(String label);

  /// Discloses server-wide credential removal and avoids promising successor activation
  ///
  /// In en, this message translates to:
  /// **'Remove this saved sign-in from the server. Other projects using it may be affected. This does not edit environment configuration; the server determines which account, if any, becomes active afterward.'**
  String get credentialRemoveDetail;

  /// Blocks operations from a previous credential-management scope
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Close and reopen account management before making changes.'**
  String get credentialScopeChanged;

  /// Fresh integration read no longer contains the selected provider
  ///
  /// In en, this message translates to:
  /// **'This provider is no longer in the server\'s integration list.'**
  String get credentialProviderMissing;

  /// Safe credential metadata refresh failure
  ///
  /// In en, this message translates to:
  /// **'Could not refresh saved accounts. Try again.'**
  String get credentialLoadFailed;

  /// Uncertain credential mutation result without raw server or secret data
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the account change. Refresh before retrying; the server may already have applied it.'**
  String get credentialMutationFailed;

  /// Refetch safe credential metadata, not a guarantee of active-state confirmation
  ///
  /// In en, this message translates to:
  /// **'Refresh accounts'**
  String get credentialRefresh;

  /// Empty credential list without claiming provider disconnection
  ///
  /// In en, this message translates to:
  /// **'No saved accounts were reported for this provider.'**
  String get credentialEmpty;

  /// Environment-backed integration connection is not an editable credential
  ///
  /// In en, this message translates to:
  /// **'Managed by the server environment. It cannot be removed here.'**
  String get credentialEnvironment;

  /// Display-only ordinal for a credential with no label; not a server-reported identity
  ///
  /// In en, this message translates to:
  /// **'Saved account {index}'**
  String credentialUnnamed(int index);

  /// Remove an MCP server from the current runtime location
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get mcpRemove;

  /// Confirmation title naming the selected MCP server
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String mcpRemoveTitle(String name);

  /// Distinguishes runtime MCP removal from persistent configuration changes
  ///
  /// In en, this message translates to:
  /// **'Remove this MCP server from the current project’s runtime. Its tools will no longer be available there. This does not erase persistent server configuration; it may return after a server restart.'**
  String get mcpRemoveRuntimeDetail;

  /// Safe feedback for an uncertain removal outcome without raw configuration or server errors
  ///
  /// In en, this message translates to:
  /// **'Could not confirm MCP removal. Refresh the list before trying again; the server may already have applied the change.'**
  String get mcpRemoveFailed;

  /// Generic MCP inventory or resource refresh failure
  ///
  /// In en, this message translates to:
  /// **'Could not refresh MCP data. Try again.'**
  String get mcpLoadFailed;

  /// No description provided for @mcpSavedStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved in OpenCode'**
  String get mcpSavedStatus;

  /// No description provided for @mcpConnectionUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'App connection not confirmed'**
  String get mcpConnectionUnconfirmed;

  /// No description provided for @mcpRetryReconnect.
  ///
  /// In en, this message translates to:
  /// **'Try reconnecting again'**
  String get mcpRetryReconnect;

  /// No description provided for @mcpReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get mcpReconnecting;

  /// No description provided for @mcpStillDisconnected.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is still disconnected. Try again.'**
  String get mcpStillDisconnected;

  /// Warns against acting on MCP data from a previous profile or location
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Refresh to load its MCP servers before making changes.'**
  String get mcpScopeChanged;

  /// No description provided for @promptStashRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish restoring the prompt. Saved copies remain available; check the composer before trying again.'**
  String get promptStashRestoreFailed;

  /// No description provided for @promptStashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. Use Stash current prompt in Prompt tools to keep a prompt for later.'**
  String get promptStashEmpty;

  /// No description provided for @promptStashContextOnly.
  ///
  /// In en, this message translates to:
  /// **'Attachments and references'**
  String get promptStashContextOnly;

  /// No description provided for @promptRestoredReferences.
  ///
  /// In en, this message translates to:
  /// **'Prompt restored. Saved references are snapshots; their server files may have changed.'**
  String get promptRestoredReferences;

  /// No description provided for @promptDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'the server default directory'**
  String get promptDefaultLocation;

  /// No description provided for @promptStashed.
  ///
  /// In en, this message translates to:
  /// **'Prompt saved to your stash.'**
  String get promptStashed;

  /// Stash save succeeded but persisting the cleared or restored composer draft failed; the saved stash remains available
  ///
  /// In en, this message translates to:
  /// **'Prompt saved to your stash. The composer draft still needs to be saved; try again from the draft warning.'**
  String get promptStashedDraftPending;

  /// No description provided for @promptStashReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read saved prompts. Their stored data has been kept.'**
  String get promptStashReadFailed;

  /// No description provided for @promptStashDeleteDetail.
  ///
  /// In en, this message translates to:
  /// **'This removes the saved text, attachments and references from this device.'**
  String get promptStashDeleteDetail;

  /// No description provided for @promptStashDescription.
  ///
  /// In en, this message translates to:
  /// **'Save text, attachments and references for later'**
  String get promptStashDescription;

  /// No description provided for @promptRestoreAvailable.
  ///
  /// In en, this message translates to:
  /// **'Restore available content'**
  String get promptRestoreAvailable;

  /// No description provided for @promptRestored.
  ///
  /// In en, this message translates to:
  /// **'Prompt restored. Review it before sending.'**
  String get promptRestored;

  /// No description provided for @promptStashAction.
  ///
  /// In en, this message translates to:
  /// **'Stash current prompt'**
  String get promptStashAction;

  /// No description provided for @promptStashLocation.
  ///
  /// In en, this message translates to:
  /// **'This prompt refers to files in {directory}. Switch to its original project before restoring it.'**
  String promptStashLocation(String directory);

  /// No description provided for @promptStashScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Close and reopen Saved prompts.'**
  String get promptStashScopeChanged;

  /// No description provided for @transcriptFindTitle.
  ///
  /// In en, this message translates to:
  /// **'Find in conversation'**
  String get transcriptFindTitle;

  /// No description provided for @transcriptFindHint.
  ///
  /// In en, this message translates to:
  /// **'Search conversation'**
  String get transcriptFindHint;

  /// No description provided for @transcriptFindScope.
  ///
  /// In en, this message translates to:
  /// **'Messages, reasoning and tool data'**
  String get transcriptFindScope;

  /// No description provided for @transcriptFindClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get transcriptFindClose;

  /// No description provided for @transcriptFindPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get transcriptFindPrevious;

  /// No description provided for @transcriptFindNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get transcriptFindNext;

  /// No description provided for @transcriptFindNone.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get transcriptFindNone;

  /// No description provided for @transcriptFindCount.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{1 match} other{{current} of {total} matches}}'**
  String transcriptFindCount(int current, int total);

  /// No description provided for @transcriptFindTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match in message text} other{{count} matches in message text}}'**
  String transcriptFindTotal(int count);

  /// No description provided for @transcriptFindPartial.
  ///
  /// In en, this message translates to:
  /// **'Loaded messages only. Load older messages to search further.'**
  String get transcriptFindPartial;

  /// No description provided for @transcriptFindComplete.
  ///
  /// In en, this message translates to:
  /// **'All available message content searched.'**
  String get transcriptFindComplete;

  /// No description provided for @transcriptFindReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get transcriptFindReasoning;

  /// No description provided for @transcriptFindTool.
  ///
  /// In en, this message translates to:
  /// **'Tool data'**
  String get transcriptFindTool;

  /// No description provided for @transcriptFindFile.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get transcriptFindFile;

  /// No description provided for @transcriptFindAll.
  ///
  /// In en, this message translates to:
  /// **'Search all history'**
  String get transcriptFindAll;

  /// No description provided for @skillMenu.
  ///
  /// In en, this message translates to:
  /// **'Use a skill'**
  String get skillMenu;

  /// No description provided for @skillUse.
  ///
  /// In en, this message translates to:
  /// **'Add to conversation'**
  String get skillUse;

  /// No description provided for @skillActivationHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds these skill instructions to this conversation. Your unsent draft stays in the composer.'**
  String get skillActivationHelp;

  /// No description provided for @skillRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run agent now'**
  String get skillRunNow;

  /// No description provided for @skillRunHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off to add the skill without starting another response.'**
  String get skillRunHelp;

  /// No description provided for @skillLocationChanged.
  ///
  /// In en, this message translates to:
  /// **'The server or project changed. Reopen Skills from the conversation.'**
  String get skillLocationChanged;

  /// No description provided for @skillUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Skill activation is unavailable on this server. You can still preview skills.'**
  String get skillUnsupported;

  /// No description provided for @skillStaged.
  ///
  /// In en, this message translates to:
  /// **'Resolve the staged revert in the conversation before adding a skill.'**
  String get skillStaged;

  /// No description provided for @skillBusy.
  ///
  /// In en, this message translates to:
  /// **'A skill is already being added to this conversation.'**
  String get skillBusy;

  /// No description provided for @skillUncertain.
  ///
  /// In en, this message translates to:
  /// **'The server did not confirm the result. The skill may have been added. Close this sheet and check the conversation before trying again.'**
  String get skillUncertain;

  /// No description provided for @skillApplied.
  ///
  /// In en, this message translates to:
  /// **'Skill added to this conversation.'**
  String get skillApplied;

  /// No description provided for @skillAppliedOriginal.
  ///
  /// In en, this message translates to:
  /// **'Skill added to the original conversation. Close this sheet to return.'**
  String get skillAppliedOriginal;

  /// No description provided for @activeContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Active context'**
  String get activeContextTitle;

  /// No description provided for @activeContextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect messages after compaction'**
  String get activeContextSubtitle;

  /// No description provided for @activeContextHelp.
  ///
  /// In en, this message translates to:
  /// **'Active messages returned by the server after its latest compaction. Message counts are not token counts.'**
  String get activeContextHelp;

  /// No description provided for @activeContextRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh active context'**
  String get activeContextRefresh;

  /// No description provided for @activeContextSearch.
  ///
  /// In en, this message translates to:
  /// **'Search active messages'**
  String get activeContextSearch;

  /// No description provided for @activeContextAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activeContextAll;

  /// No description provided for @activeContextCount.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} messages'**
  String activeContextCount(int shown, int total);

  /// No description provided for @activeContextEmpty.
  ///
  /// In en, this message translates to:
  /// **'The server returned no active context messages.'**
  String get activeContextEmpty;

  /// No description provided for @activeContextNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No active messages match these filters.'**
  String get activeContextNoMatches;

  /// No description provided for @activeContextNoText.
  ///
  /// In en, this message translates to:
  /// **'No supported text content in this entry.'**
  String get activeContextNoText;

  /// No description provided for @activeContextUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Active context inspection is unavailable on this server.'**
  String get activeContextUnsupported;

  /// No description provided for @activeContextChanged.
  ///
  /// In en, this message translates to:
  /// **'The server, project or conversation changed. Reopen this inspector from the conversation.'**
  String get activeContextChanged;

  /// No description provided for @activeContextInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid context snapshot. Refresh to try again.'**
  String get activeContextInvalid;

  /// No description provided for @activeContextRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Showing the previous snapshot. Could not refresh: {error}'**
  String activeContextRefreshFailed(String error);

  /// No description provided for @activeContextContentHelp.
  ///
  /// In en, this message translates to:
  /// **'Snapshot of available message content. Binary attachment bodies, URLs and internal metadata are not displayed. This is not the complete provider request.'**
  String get activeContextContentHelp;

  /// No description provided for @activeContextUser.
  ///
  /// In en, this message translates to:
  /// **'User prompt'**
  String get activeContextUser;

  /// No description provided for @activeContextAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get activeContextAssistant;

  /// No description provided for @activeContextSystem.
  ///
  /// In en, this message translates to:
  /// **'System instructions'**
  String get activeContextSystem;

  /// No description provided for @activeContextSynthetic.
  ///
  /// In en, this message translates to:
  /// **'Synthetic message'**
  String get activeContextSynthetic;

  /// No description provided for @activeContextSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get activeContextSkill;

  /// No description provided for @activeContextShell.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get activeContextShell;

  /// No description provided for @activeContextCompaction.
  ///
  /// In en, this message translates to:
  /// **'Compaction'**
  String get activeContextCompaction;

  /// No description provided for @activeContextChange.
  ///
  /// In en, this message translates to:
  /// **'Conversation change'**
  String get activeContextChange;

  /// No description provided for @activeContextText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get activeContextText;

  /// No description provided for @activeContextToolInput.
  ///
  /// In en, this message translates to:
  /// **'Tool input'**
  String get activeContextToolInput;

  /// No description provided for @activeContextToolOutput.
  ///
  /// In en, this message translates to:
  /// **'Tool output'**
  String get activeContextToolOutput;

  /// No description provided for @activeContextFile.
  ///
  /// In en, this message translates to:
  /// **'File attachment'**
  String get activeContextFile;

  /// No description provided for @activeContextNotice.
  ///
  /// In en, this message translates to:
  /// **'Server notice'**
  String get activeContextNotice;

  /// No description provided for @activeContextPruned.
  ///
  /// In en, this message translates to:
  /// **'Content pruned by the server'**
  String get activeContextPruned;

  /// No description provided for @activeContextTruncated.
  ///
  /// In en, this message translates to:
  /// **'Output truncated by the server'**
  String get activeContextTruncated;

  /// No description provided for @draftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Draft not saved. Copy your text or retry.'**
  String get draftSaveFailed;

  /// No description provided for @draftStorageFull.
  ///
  /// In en, this message translates to:
  /// **'Draft storage is full. Copy your text before leaving.'**
  String get draftStorageFull;

  /// No description provided for @draftProfileRemoved.
  ///
  /// In en, this message translates to:
  /// **'The original server was removed. Copy your draft to keep it.'**
  String get draftProfileRemoved;

  /// No description provided for @draftRetrySave.
  ///
  /// In en, this message translates to:
  /// **'Try saving draft again'**
  String get draftRetrySave;

  /// No description provided for @draftClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the saved draft. Retry before leaving.'**
  String get draftClearFailed;

  /// No description provided for @activeContextTypeCount.
  ///
  /// In en, this message translates to:
  /// **'{type} · {count}'**
  String activeContextTypeCount(String type, int count);

  /// No description provided for @activeContextPartHeading.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {name}'**
  String activeContextPartHeading(String kind, String name);

  /// No description provided for @draftLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft could not be saved'**
  String get draftLeaveTitle;

  /// No description provided for @draftLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep editing to copy your text or retry saving. Leaving now may lose your unsaved changes.'**
  String get draftLeaveMessage;

  /// No description provided for @draftLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get draftLeaveAction;

  /// No description provided for @draftKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get draftKeepEditing;

  /// No description provided for @draftUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get draftUnsaved;

  /// No description provided for @draftAttachmentsLocal.
  ///
  /// In en, this message translates to:
  /// **'Attachments save with this draft on this device.'**
  String get draftAttachmentsLocal;

  /// No description provided for @draftAttachmentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachments need recovery or could not be saved. Retry before sending.'**
  String get draftAttachmentsFailed;

  /// No description provided for @draftAttachmentRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Some attachments need attention'**
  String get draftAttachmentRecoveryTitle;

  /// No description provided for @draftAttachmentRecoveryDetail.
  ///
  /// In en, this message translates to:
  /// **'These saved attachments are missing, unreadable, or belong to another project: {names}. Use the available attachments and remove these from the draft, or keep the saved draft and retry later.'**
  String draftAttachmentRecoveryDetail(String names);

  /// No description provided for @draftUseAvailableAttachments.
  ///
  /// In en, this message translates to:
  /// **'Use available attachments'**
  String get draftUseAvailableAttachments;

  /// No description provided for @draftKeepSavedAttachments.
  ///
  /// In en, this message translates to:
  /// **'Keep saved draft'**
  String get draftKeepSavedAttachments;

  /// No description provided for @photoLibraryAction.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get photoLibraryAction;

  /// No description provided for @photoLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo or screenshot'**
  String get photoLibraryDescription;

  /// No description provided for @photoCameraAction.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoCameraAction;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo smaller than 10 MB.'**
  String get photoTooLarge;

  /// No description provided for @photoStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be saved on this device. Free some space and retry.'**
  String get photoStorageFailed;

  /// No description provided for @photoPendingOther.
  ///
  /// In en, this message translates to:
  /// **'A photo is waiting in its original conversation. Keep it there, or discard it before choosing another photo.'**
  String get photoPendingOther;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be opened. Try adding it again from Photo library or Take photo.'**
  String get photoUnavailable;

  /// No description provided for @photoPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo access was denied. Allow camera or photo access in Android app settings, then try again.'**
  String get photoPermissionDenied;

  /// No description provided for @photoPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending photo'**
  String get photoPendingTitle;

  /// No description provided for @photoDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard pending photo'**
  String get photoDiscard;

  /// No description provided for @photoAddToDraft.
  ///
  /// In en, this message translates to:
  /// **'Add recovered photo to draft'**
  String get photoAddToDraft;

  /// No description provided for @photoOtherLocation.
  ///
  /// In en, this message translates to:
  /// **'Return to the photo\'s original server and project before adding it.'**
  String get photoOtherLocation;

  /// No description provided for @photoDraftFull.
  ///
  /// In en, this message translates to:
  /// **'Remove an attachment first. A draft holds up to 5 files and 20 MB in total.'**
  String get photoDraftFull;

  /// No description provided for @legacyDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Older drafts'**
  String get legacyDraftsTitle;

  /// No description provided for @legacyDraftsDescription.
  ///
  /// In en, this message translates to:
  /// **'Review drafts saved before server tracking'**
  String get legacyDraftsDescription;

  /// No description provided for @legacyDraftsExplanation.
  ///
  /// In en, this message translates to:
  /// **'These drafts have no recorded server. Review their text before using it in this conversation.'**
  String get legacyDraftsExplanation;

  /// No description provided for @legacyDraftInsertExplanation.
  ///
  /// In en, this message translates to:
  /// **'Insert adds this text after your current draft. The original saved copy stays here until you delete it.'**
  String get legacyDraftInsertExplanation;

  /// No description provided for @legacyDraftTextOnly.
  ///
  /// In en, this message translates to:
  /// **'Only text can be inserted here. Any saved attachments remain with the older draft.'**
  String get legacyDraftTextOnly;

  /// No description provided for @legacyDraftDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete saved copy'**
  String get legacyDraftDelete;

  /// No description provided for @legacyDraftDeleteExplanation.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this older draft and its saved attachments from this device?'**
  String get legacyDraftDeleteExplanation;

  /// No description provided for @legacyDraftDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The draft changed or could not be removed. Reopen it and retry.'**
  String get legacyDraftDeleteFailed;

  /// No description provided for @legacyDraftInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert into draft'**
  String get legacyDraftInsert;

  /// No description provided for @legacyDraftSearch.
  ///
  /// In en, this message translates to:
  /// **'Search older drafts'**
  String get legacyDraftSearch;

  /// No description provided for @legacyDraftsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No older drafts found'**
  String get legacyDraftsEmpty;

  /// No description provided for @legacyDraftLocationChanged.
  ///
  /// In en, this message translates to:
  /// **'The project changed. Reopen Older drafts to choose where to insert the text.'**
  String get legacyDraftLocationChanged;

  /// Read-only subscription quota screen title
  ///
  /// In en, this message translates to:
  /// **'Remaining usage'**
  String get quotaTitle;

  /// Distinguishes account-wide rate-limit windows from project consumption
  ///
  /// In en, this message translates to:
  /// **'Choose a provider to view its reported account windows. These are separate from OpenCode token usage and cost.'**
  String get quotaDescription;

  /// Label above the explicitly selected server origin
  ///
  /// In en, this message translates to:
  /// **'Collector server'**
  String get quotaSource;

  /// Selected quota source profile and provider heading
  ///
  /// In en, this message translates to:
  /// **'{profile} · {provider}'**
  String quotaSourceTitle(String profile, String provider);

  /// Safe fallback when a quota source origin is unavailable
  ///
  /// In en, this message translates to:
  /// **'No saved server'**
  String get quotaUnknownSource;

  /// A retained quota screen lost its original scope or profile
  ///
  /// In en, this message translates to:
  /// **'The server or project changed, or its local data is being removed. Reopen Remaining usage to review the source again.'**
  String get quotaSourceChanged;

  /// First-visit quota setup heading; no claim of built-in OpenCode support
  ///
  /// In en, this message translates to:
  /// **'An optional collector is required'**
  String get quotaSetupTitle;

  /// Informed consent before sending existing server authentication to an optional same-origin route
  ///
  /// In en, this message translates to:
  /// **'Your server operator must install and protect this route at the same origin as OpenCode. Reading it uses this saved server\'s sign-in. Confirm only if you installed or trust that deployment. Provider tokens stay on the server.'**
  String get quotaSetupDescription;

  /// Explains operator configuration and visit-only consent
  ///
  /// In en, this message translates to:
  /// **'Setup instructions are in tool/quota/README.md in the app repository. This screen does not install services or remember permission after you leave.'**
  String get quotaSetupGuide;

  /// Quota reads are unavailable for missing credentials or an unsafe source
  ///
  /// In en, this message translates to:
  /// **'Use a saved server with a password and HTTPS, or phone loopback. Update its connection settings before checking the collector.'**
  String get quotaSetupNeeded;

  /// Explicit opt-in checkbox; does not install or configure a collector
  ///
  /// In en, this message translates to:
  /// **'I installed and trust this collector on this server.'**
  String get quotaConsent;

  /// Explicit first quota read after informed consent
  ///
  /// In en, this message translates to:
  /// **'Read remaining usage'**
  String get quotaRead;

  /// Manual refresh or retry of the same trusted quota source
  ///
  /// In en, this message translates to:
  /// **'Refresh remaining usage'**
  String get quotaRefresh;

  /// Progress semantics for a quota read
  ///
  /// In en, this message translates to:
  /// **'Reading remaining usage'**
  String get quotaLoading;

  /// Clear this visit's consent and in-memory quota snapshot; no remote mutation
  ///
  /// In en, this message translates to:
  /// **'Stop using this collector'**
  String get quotaForgetConsent;

  /// Collector or proxy authentication failure, distinct from provider reauthentication
  ///
  /// In en, this message translates to:
  /// **'The collector route did not accept this server sign-in. Ask the server operator to check its authentication setup.'**
  String get quotaCollectorAuth;

  /// Optional collector returned a missing route or unsupported method
  ///
  /// In en, this message translates to:
  /// **'The optional collector route is not available on this server. Check its installation and proxy routing.'**
  String get quotaCollectorMissing;

  /// Safe quota network/service failure without raw errors
  ///
  /// In en, this message translates to:
  /// **'Remaining usage could not be refreshed. Check the connection and collector, then retry.'**
  String get quotaUnavailable;

  /// Malformed or incompatible quota response
  ///
  /// In en, this message translates to:
  /// **'The collector returned an unsupported or invalid snapshot. No new allowance is shown.'**
  String get quotaInvalidResponse;

  /// The collector is reachable but lacks an explicitly configured credential source
  ///
  /// In en, this message translates to:
  /// **'The collector has no authorized account source configured. Ask its operator to finish setup.'**
  String get quotaUnconfigured;

  /// Honest first-provider/auth-method limitation
  ///
  /// In en, this message translates to:
  /// **'The selected OAuth login or provider usage route is not supported by this collector.'**
  String get quotaProviderUnsupported;

  /// Provider login expired or was unreadable; not collector Basic authentication failure
  ///
  /// In en, this message translates to:
  /// **'Sign in again using the provider\'s existing login tool on the server. This app does not read or refresh that login.'**
  String get quotaProviderAuth;

  /// A polling rate limit is distinct from an exhausted subscription window
  ///
  /// In en, this message translates to:
  /// **'The provider limited quota checks. Wait before refreshing; this does not prove your coding allowance is exhausted.'**
  String get quotaRateLimited;

  /// Missing or mismatched account identity must not display measurements
  ///
  /// In en, this message translates to:
  /// **'The collector could not verify the selected account. No allowance is shown. Check the login source on the server.'**
  String get quotaAccountUnverified;

  /// Heading for Codex entitlements, not all ChatGPT product allowances
  ///
  /// In en, this message translates to:
  /// **'Codex account windows'**
  String get quotaCodexAccount;

  /// Provider-reported plan label, from a safe allowlist
  ///
  /// In en, this message translates to:
  /// **'Reported plan: {plan}'**
  String quotaPlan(String plan);

  /// Collector snapshot time, formatted in the device locale
  ///
  /// In en, this message translates to:
  /// **'Snapshot checked {time}'**
  String quotaChecked(String time);

  /// An expired, interrupted or failed-refresh snapshot is not live provider truth
  ///
  /// In en, this message translates to:
  /// **'Previous snapshot — refresh to check the latest allowance.'**
  String get quotaStale;

  /// Explicit provider eligibility signal, independent of quota arithmetic
  ///
  /// In en, this message translates to:
  /// **'The provider reports that ordinary Codex use is currently blocked. Window percentages alone do not determine access.'**
  String get quotaUseBlocked;

  /// Unknown allowance; never means zero or unlimited
  ///
  /// In en, this message translates to:
  /// **'Not reported'**
  String get quotaNotReported;

  /// First provider rate-limit window without assuming a five-hour duration
  ///
  /// In en, this message translates to:
  /// **'Primary window'**
  String get quotaPrimaryWindow;

  /// Second provider rate-limit window without assuming a weekly duration
  ///
  /// In en, this message translates to:
  /// **'Secondary window'**
  String get quotaSecondaryWindow;

  /// Safe display name for an additional bounded window
  ///
  /// In en, this message translates to:
  /// **'Usage window {number}'**
  String quotaOtherWindow(int number);

  /// Percentage remaining within one reported provider window
  ///
  /// In en, this message translates to:
  /// **'{percent} remaining'**
  String quotaRemaining(String percent);

  /// Progress-bar semantics label; its numeric value is expressed separately
  ///
  /// In en, this message translates to:
  /// **'{window}: remaining percentage'**
  String quotaWindowRemainingLabel(String window);

  /// Provider-reported percentage used within one window
  ///
  /// In en, this message translates to:
  /// **'{percent} used'**
  String quotaUsed(String percent);

  /// Absolute provider reset time in device locale
  ///
  /// In en, this message translates to:
  /// **'Reported reset: {time}'**
  String quotaResetAt(String time);

  /// Missing provider reset time is not fabricated
  ///
  /// In en, this message translates to:
  /// **'Reset time not reported'**
  String get quotaResetUnknown;

  /// Passing a reset deadline does not invent a new allowance
  ///
  /// In en, this message translates to:
  /// **'Reset time passed — refresh to check. The displayed allowance has not been replenished locally.'**
  String get quotaResetPassed;

  /// Exact whole-day provider window duration
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1-day window} other{{count}-day window}}'**
  String quotaDays(int count);

  /// Exact whole-hour provider window duration
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1-hour window} other{{count}-hour window}}'**
  String quotaHours(int count);

  /// Exact duration when a provider window is not whole hours or days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1-second window} other{{count}-second window}}'**
  String quotaSeconds(int count);

  /// Honest limits and provenance of optional provider quota collectors
  ///
  /// In en, this message translates to:
  /// **'Read-only snapshot from the optional collector using an internal provider endpoint. Other product allowances, model-specific limits, credits and eligibility are not included. Missing data is unknown, not unlimited.'**
  String get quotaSourceDisclosure;

  /// Codex provider selector
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get quotaCodex;

  /// Claude provider selector
  ///
  /// In en, this message translates to:
  /// **'Claude'**
  String get quotaClaude;

  /// Explains the disabled Claude subscription collection path without suggesting an OAuth workaround
  ///
  /// In en, this message translates to:
  /// **'Claude subscription usage is unavailable here pending a supported, permitted integration. Current OpenCode does not include Claude Pro/Max sign-in. This app will not read or reuse that subscription login.'**
  String get quotaClaudeUnavailable;

  /// iOS app identity without describing it as an Android or desktop build
  ///
  /// In en, this message translates to:
  /// **'OpenCode for iOS'**
  String get iosAppTitle;

  /// Truthful initial iOS remote-control scope
  ///
  /// In en, this message translates to:
  /// **'A remote client for the OpenCode server you choose. On-device server hosting and background monitoring are not available in this iOS build.'**
  String get iosRemoteSummary;

  /// iOS credential storage guidance
  ///
  /// In en, this message translates to:
  /// **'Server passwords use this device\'s Keychain. They are not stored in plain app preferences.'**
  String get iosKeychainGuide;

  /// Platform-neutral storage copy rather than incorrectly promising Linux libsecret everywhere
  ///
  /// In en, this message translates to:
  /// **'Server passwords use this platform\'s secure credential storage. They are not stored in plain app preferences.'**
  String get platformSecureStorageGuide;

  /// Claude allowances for the operator-selected OAuth login
  ///
  /// In en, this message translates to:
  /// **'Claude login windows'**
  String get quotaClaudeAccount;

  /// Distinguishes credential-bound Claude usage from provider-confirmed account identity
  ///
  /// In en, this message translates to:
  /// **'Tied to the collector\'s configured Claude login. The usage response does not independently identify the account.'**
  String get quotaSourceBound;

  /// Provider grouping within server consumption statistics
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get usageProviders;

  /// Limits the meaning of provider-grouped consumption
  ///
  /// In en, this message translates to:
  /// **'Totals from this server\'s returned model records for the selected scope. Not provider billing or subscription allowances.'**
  String get usageProviderScope;

  /// Distinct model IDs within a provider; variants are not counted as new models
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 model} other{{count} models}}'**
  String usageProviderModelCount(int count);

  /// Invalid numeric aggregate is not rendered as a plausible cost
  ///
  /// In en, this message translates to:
  /// **'Cost subtotal unavailable'**
  String get usageProviderCostUnavailable;

  /// Provider subtotal divided by the selected server consumption total, when consistent
  ///
  /// In en, this message translates to:
  /// **'{percent} of reported cost'**
  String usageProviderCostShare(String percent);

  /// No description provided for @setupOutputWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Termux output…'**
  String get setupOutputWaiting;

  /// No description provided for @setupOutputWaitingDetail.
  ///
  /// In en, this message translates to:
  /// **'Setup messages will appear here when Termux responds.'**
  String get setupOutputWaitingDetail;

  /// No description provided for @setupStartInstalled.
  ///
  /// In en, this message translates to:
  /// **'Start installed OpenCode'**
  String get setupStartInstalled;

  /// No description provided for @setupMissingCredential.
  ///
  /// In en, this message translates to:
  /// **'This app has no saved credential for that installation. Connect with its server address, or run setup to configure it.'**
  String get setupMissingCredential;

  /// No description provided for @setupUbuntuOption.
  ///
  /// In en, this message translates to:
  /// **'Managed Ubuntu installation'**
  String get setupUbuntuOption;

  /// No description provided for @setupOwnOption.
  ///
  /// In en, this message translates to:
  /// **'Use your own setup'**
  String get setupOwnOption;

  /// No description provided for @setupOwnDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect an existing OpenCode 1 or OpenCode 2 server by address. A native musl installation needs a compatible Linux environment and is not managed by this app.'**
  String get setupOwnDescription;

  /// No description provided for @setupConnectExisting.
  ///
  /// In en, this message translates to:
  /// **'Connect existing server'**
  String get setupConnectExisting;

  /// No description provided for @setupScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get setupScreenTitle;

  /// No description provided for @setupInstallStart.
  ///
  /// In en, this message translates to:
  /// **'Install & start'**
  String get setupInstallStart;

  /// No description provided for @setupCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get setupCheckAgain;

  /// No description provided for @uncertainAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed sign-in: {integrationID}'**
  String uncertainAuthTitle(String integrationID);

  /// No description provided for @uncertainAuthDetail.
  ///
  /// In en, this message translates to:
  /// **'The server may have started sign-in, but no attempt ID was received. Check on the server before starting again.'**
  String get uncertainAuthDetail;

  /// No description provided for @uncertainAuthForgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget uncertain start?'**
  String get uncertainAuthForgetTitle;

  /// No description provided for @uncertainAuthForgetDetail.
  ///
  /// In en, this message translates to:
  /// **'This clears only the local retry block. It does not cancel sign-in on the server. Check the server first to avoid running a second sign-in. No new sign-in will start.'**
  String get uncertainAuthForgetDetail;

  /// No description provided for @uncertainAuthForget.
  ///
  /// In en, this message translates to:
  /// **'Forget uncertain start'**
  String get uncertainAuthForget;

  /// No description provided for @uncertainAuthCloseHint.
  ///
  /// In en, this message translates to:
  /// **'Close this sheet and use the unconfirmed sign-in row to clear its local retry block after checking the server.'**
  String get uncertainAuthCloseHint;

  /// No description provided for @pluginsDescription.
  ///
  /// In en, this message translates to:
  /// **'Plugins reported for this project on the server. Inspect status and source here; manage plugins on the server.'**
  String get pluginsDescription;

  /// No description provided for @pluginsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support plugin inspection.'**
  String get pluginsUnsupported;

  /// No description provided for @pluginsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server to inspect its plugins.'**
  String get pluginsDisconnected;

  /// No description provided for @pluginsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plugins reported for this project.'**
  String get pluginsEmpty;

  /// No description provided for @pluginsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load plugins. Try again.'**
  String get pluginsLoadFailed;

  /// No description provided for @pluginsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh plugins'**
  String get pluginsRefresh;

  /// No description provided for @pluginsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get pluginsRetry;

  /// No description provided for @pluginsUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Plugin without an ID'**
  String get pluginsUnnamed;

  /// No description provided for @pluginsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get pluginsStatusActive;

  /// No description provided for @pluginsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get pluginsStatusFailed;

  /// No description provided for @pluginsStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get pluginsStatusUnknown;

  /// No description provided for @pluginsSourceBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get pluginsSourceBuiltin;

  /// No description provided for @pluginsSourcePackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get pluginsSourcePackage;

  /// No description provided for @pluginsSourceLocal.
  ///
  /// In en, this message translates to:
  /// **'Local file (path hidden)'**
  String get pluginsSourceLocal;

  /// No description provided for @pluginsSourceSdk.
  ///
  /// In en, this message translates to:
  /// **'SDK'**
  String get pluginsSourceSdk;

  /// No description provided for @pluginsSourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get pluginsSourceUnknown;

  /// No description provided for @pluginsTerminalUi.
  ///
  /// In en, this message translates to:
  /// **'Terminal UI declared'**
  String get pluginsTerminalUi;

  /// No description provided for @pluginsFailureDetail.
  ///
  /// In en, this message translates to:
  /// **'Failure details are hidden because they may contain credentials.'**
  String get pluginsFailureDetail;

  /// No description provided for @demoReviewChanges.
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get demoReviewChanges;

  /// No description provided for @demoSetUpServer.
  ///
  /// In en, this message translates to:
  /// **'Set up your own server'**
  String get demoSetUpServer;

  /// No description provided for @handoffCommandTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue on computer'**
  String get handoffCommandTitle;

  /// No description provided for @handoffCommandDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Run this command in a POSIX shell on a computer with OpenCode installed and access to this server. Set OPENCODE_SERVER_PASSWORD privately on that computer if the server requires it. The clipboard will contain the server address, username, project directory and conversation ID, but no password.'**
  String get handoffCommandDisclosure;

  /// No description provided for @handoffCopyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get handoffCopyCommand;

  /// No description provided for @handoffCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'Resume command copied'**
  String get handoffCommandCopied;

  /// No description provided for @handoffCommandUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A resume command is unavailable for this server or cloud environment. Continuing on another computer needs a supported OpenCode command and a reachable HTTPS server; a localhost address points to each device itself. You can still copy the conversation metadata below.'**
  String get handoffCommandUnavailable;

  /// No description provided for @quotaMiniMax.
  ///
  /// In en, this message translates to:
  /// **'MiniMax'**
  String get quotaMiniMax;

  /// No description provided for @quotaMiniMaxAccount.
  ///
  /// In en, this message translates to:
  /// **'MiniMax subscription windows'**
  String get quotaMiniMaxAccount;

  /// No description provided for @quotaMiniMaxSourceBound.
  ///
  /// In en, this message translates to:
  /// **'Tied to the collector\'s configured MiniMax Subscription Key. The quota response does not independently identify the account. Only reported general-pool percentages are shown; other limits may apply.'**
  String get quotaMiniMaxSourceBound;

  /// No description provided for @managedHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'On-device server'**
  String get managedHealthTitle;

  /// No description provided for @managedHealthUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Check the server managed by this app in Termux.'**
  String get managedHealthUnchecked;

  /// No description provided for @managedHealthCheck.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get managedHealthCheck;

  /// No description provided for @managedHealthChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking Termux…'**
  String get managedHealthChecking;

  /// No description provided for @managedHealthFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check Termux. Open setup to check permissions or try again.'**
  String get managedHealthFailed;

  /// No description provided for @managedHealthReady.
  ///
  /// In en, this message translates to:
  /// **'Server process running'**
  String get managedHealthReady;

  /// No description provided for @managedHealthWorking.
  ///
  /// In en, this message translates to:
  /// **'Setup is in progress'**
  String get managedHealthWorking;

  /// No description provided for @managedHealthStopped.
  ///
  /// In en, this message translates to:
  /// **'Server stopped'**
  String get managedHealthStopped;

  /// No description provided for @managedHealthNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup needs attention'**
  String get managedHealthNeedsSetup;

  /// No description provided for @managedHealthAbsent.
  ///
  /// In en, this message translates to:
  /// **'No managed setup found'**
  String get managedHealthAbsent;

  /// No description provided for @managedHealthUnknown.
  ///
  /// In en, this message translates to:
  /// **'Server state unavailable'**
  String get managedHealthUnknown;

  /// No description provided for @managedHealthManage.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get managedHealthManage;

  /// No description provided for @managedHealthObserved.
  ///
  /// In en, this message translates to:
  /// **'Last checked at {time}. Check again for the current state.'**
  String managedHealthObserved(String time);

  /// No description provided for @managedHealthVersion.
  ///
  /// In en, this message translates to:
  /// **'OpenCode {version}'**
  String managedHealthVersion(String version);

  /// No description provided for @managedHealthUbuntu.
  ///
  /// In en, this message translates to:
  /// **'Runner: Ubuntu'**
  String get managedHealthUbuntu;

  /// No description provided for @managedHealthLifetime.
  ///
  /// In en, this message translates to:
  /// **'Android may stop either app. Keeping the mobile connection alive does not guarantee the Termux server will keep running overnight.'**
  String get managedHealthLifetime;

  /// No description provided for @quotaBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal alert threshold'**
  String get quotaBudgetTitle;

  /// No description provided for @quotaBudgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a percentage used for this source, account and window. This does not change provider limits.'**
  String get quotaBudgetDescription;

  /// No description provided for @quotaBudgetOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get quotaBudgetOff;

  /// No description provided for @quotaBudgetPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String quotaBudgetPercent(String percent);

  /// No description provided for @quotaBudgetOptIn.
  ///
  /// In en, this message translates to:
  /// **'Show threshold attention'**
  String get quotaBudgetOptIn;

  /// No description provided for @quotaBudgetAttentionScope.
  ///
  /// In en, this message translates to:
  /// **'Only after a fresh read on this page. No background polling or device notifications. A window without a reset time alerts once until you change this rule.'**
  String get quotaBudgetAttentionScope;

  /// No description provided for @quotaBudgetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this budget change. Your last saved settings remain in effect.'**
  String get quotaBudgetSaveFailed;

  /// No description provided for @quotaBudgetAttention.
  ///
  /// In en, this message translates to:
  /// **'A personal threshold was reached in the latest provider reading. Review the reported windows below.'**
  String get quotaBudgetAttention;

  /// No description provided for @quotaGlm.
  ///
  /// In en, this message translates to:
  /// **'GLM'**
  String get quotaGlm;

  /// No description provided for @quotaGlmAccount.
  ///
  /// In en, this message translates to:
  /// **'Configured GLM Coding Plan source'**
  String get quotaGlmAccount;

  /// No description provided for @quotaGlmTokenWindow.
  ///
  /// In en, this message translates to:
  /// **'Reported token-plan window'**
  String get quotaGlmTokenWindow;

  /// No description provided for @quotaGlmMcpWindow.
  ///
  /// In en, this message translates to:
  /// **'Reported MCP window'**
  String get quotaGlmMcpWindow;

  /// No description provided for @usageBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal consumption budgets'**
  String get usageBudgetTitle;

  /// No description provided for @usageBudgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Budgets use all reported consumption for the selected server, project, timezone and date-window start. Model filters do not change them. A new window start needs a new budget. These do not change subscription allowances or stop requests.'**
  String get usageBudgetDescription;

  /// No description provided for @usageBudgetUsd.
  ///
  /// In en, this message translates to:
  /// **'Set USD budget'**
  String get usageBudgetUsd;

  /// No description provided for @usageBudgetTokens.
  ///
  /// In en, this message translates to:
  /// **'Set token budget'**
  String get usageBudgetTokens;

  /// No description provided for @usageBudgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get usageBudgetAmount;

  /// No description provided for @usageBudgetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive finite amount. Token budgets must use whole numbers.'**
  String get usageBudgetInvalid;

  /// No description provided for @usageBudgetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get usageBudgetRemove;

  /// No description provided for @usageBudgetProgress.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} {unit}'**
  String usageBudgetProgress(String used, String limit, String unit);

  /// No description provided for @usageBudgetTokenUnit.
  ///
  /// In en, this message translates to:
  /// **'tokens'**
  String get usageBudgetTokenUnit;

  /// No description provided for @usageBudgetReached.
  ///
  /// In en, this message translates to:
  /// **'Personal budget reached in this reading.'**
  String get usageBudgetReached;

  /// No description provided for @usageBudgetPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous reading reached this budget. Refresh to check current consumption.'**
  String get usageBudgetPrevious;

  /// No description provided for @usageBudgetClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear saved consumption budgets'**
  String get usageBudgetClearAll;

  /// No description provided for @usageBudgetClearDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove all current and past consumption budgets for this saved server? Provider thresholds are kept.'**
  String get usageBudgetClearDescription;

  /// No description provided for @monitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved-server attention'**
  String get monitorTitle;

  /// No description provided for @monitorScope.
  ///
  /// In en, this message translates to:
  /// **'Counts cover each server’s last selected project, not every project on that server.'**
  String get monitorScope;

  /// No description provided for @monitorDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Monitoring is off until you enable it for a server. Checks run about once a minute while this app is open. Background checks run no more often than every five minutes, only while Keep live is already on and Android’s service is running. Android can stop that service; no remaining runtime is promised.'**
  String get monitorDisclosure;

  /// No description provided for @monitorConfigure.
  ///
  /// In en, this message translates to:
  /// **'Monitoring settings'**
  String get monitorConfigure;

  /// No description provided for @monitorRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check monitored servers'**
  String get monitorRefresh;

  /// No description provided for @monitorOptIn.
  ///
  /// In en, this message translates to:
  /// **'Monitor this server'**
  String get monitorOptIn;

  /// No description provided for @monitorOptInDetail.
  ///
  /// In en, this message translates to:
  /// **'Check pending permissions, questions and forms in its last selected project.'**
  String get monitorOptInDetail;

  /// No description provided for @monitorNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notify when attention is needed'**
  String get monitorNotifications;

  /// No description provided for @monitorWifiDetail.
  ///
  /// In en, this message translates to:
  /// **'Checks pause unless Android reports an active Wi-Fi network. VPN or unavailable network information may pause checks.'**
  String get monitorWifiDetail;

  /// No description provided for @monitorQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get monitorQuiet;

  /// No description provided for @monitorQuietStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get monitorQuietStart;

  /// No description provided for @monitorQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get monitorQuietEnd;

  /// No description provided for @monitorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not monitored · attention unknown'**
  String get monitorDisabled;

  /// No description provided for @monitorWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a check · attention unknown'**
  String get monitorWaiting;

  /// No description provided for @monitorChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking · attention unknown'**
  String get monitorChecking;

  /// No description provided for @monitorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not check · attention unknown'**
  String get monitorUnavailable;

  /// No description provided for @monitorWifiRequired.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi · attention unknown'**
  String get monitorWifiRequired;

  /// No description provided for @monitorPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused in background · attention unknown'**
  String get monitorPaused;

  /// No description provided for @monitorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current observation'**
  String get monitorCurrent;

  /// No description provided for @monitorAllClear.
  ///
  /// In en, this message translates to:
  /// **'No pending requests in the checked project'**
  String get monitorAllClear;

  /// No description provided for @monitorNoServers.
  ///
  /// In en, this message translates to:
  /// **'Add a server to monitor attention.'**
  String get monitorNoServers;

  /// No description provided for @monitorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save monitoring settings. Try again.'**
  String get monitorSaveFailed;

  /// No description provided for @monitorOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'This request or its project changed. Refresh the inbox and try again.'**
  String get monitorOpenFailed;

  /// No description provided for @monitorSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch server to review?'**
  String get monitorSwitchTitle;

  /// No description provided for @monitorSwitchDetail.
  ///
  /// In en, this message translates to:
  /// **'A run is active on the selected server. Switching changes the server shown in this app; it does not stop that server’s run.'**
  String get monitorSwitchDetail;

  /// No description provided for @monitorSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get monitorSwitch;

  /// No description provided for @monitorSession.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get monitorSession;

  /// No description provided for @monitorPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get monitorPermission;

  /// No description provided for @monitorQuestion.
  ///
  /// In en, this message translates to:
  /// **'Answer needed'**
  String get monitorQuestion;

  /// No description provided for @monitorForm.
  ///
  /// In en, this message translates to:
  /// **'Form response needed'**
  String get monitorForm;

  /// No description provided for @monitorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get monitorUnknown;

  /// No description provided for @monitorLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get monitorLastChecked;

  /// No description provided for @monitorNextCheck.
  ///
  /// In en, this message translates to:
  /// **'Next check'**
  String get monitorNextCheck;

  /// No description provided for @monitorPending.
  ///
  /// In en, this message translates to:
  /// **'Current pending requests'**
  String get monitorPending;

  /// No description provided for @monitorUnknownServers.
  ///
  /// In en, this message translates to:
  /// **'Servers with unknown attention'**
  String get monitorUnknownServers;

  /// Saved-server attention counts in the current inbox
  ///
  /// In en, this message translates to:
  /// **'Current pending requests: {pendingCount}\nServers with unknown attention: {unknownCount}'**
  String monitorPendingSummary(int pendingCount, int unknownCount);

  /// Saved-server request row summary
  ///
  /// In en, this message translates to:
  /// **'{profile} · {kind}\n{lastChecked}: {time}'**
  String monitorRequestSummary(
    String profile,
    String kind,
    String lastChecked,
    String time,
  );

  /// A localized monitor timestamp with its label
  ///
  /// In en, this message translates to:
  /// **'{label}: {time}'**
  String monitorLabeledTime(String label, String time);

  /// No description provided for @monitorSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected project'**
  String get monitorSelected;

  /// No description provided for @monitorCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in on long runs'**
  String get monitorCheckIn;

  /// No description provided for @monitorCheckInDetail.
  ///
  /// In en, this message translates to:
  /// **'Shows when busy checks span the chosen time. Work may pause or restart between checks. At most one notification is attempted per observed interval, while Keep live is on.'**
  String get monitorCheckInDetail;

  /// No description provided for @monitorCheckInDetailForeground.
  ///
  /// In en, this message translates to:
  /// **'Shows a check-in row when busy checks span the chosen time. Work may pause or restart between checks. This device cannot deliver reminders in the background.'**
  String get monitorCheckInDetailForeground;

  /// No description provided for @monitorCheckInAfter.
  ///
  /// In en, this message translates to:
  /// **'Check in after'**
  String get monitorCheckInAfter;

  /// A duration choice for the check-in rule
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String monitorMinutes(int minutes);

  /// No description provided for @monitorCheckInDue.
  ///
  /// In en, this message translates to:
  /// **'Time to check in'**
  String get monitorCheckInDue;

  /// Span between busy samples, not a continuous duration or a lower bound on run length
  ///
  /// In en, this message translates to:
  /// **'Busy at checks spanning {minutes} min · first check {since}'**
  String monitorObservedBusy(int minutes, String since);

  /// No description provided for @quotaBudgetClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear saved provider thresholds'**
  String get quotaBudgetClearAll;

  /// No description provided for @quotaBudgetClearDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove all provider thresholds and attention settings for this saved server, including previous accounts? Consumption budgets are kept.'**
  String get quotaBudgetClearDescription;

  /// No description provided for @managedStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'Termux storage: {available} GiB free of {total} GiB'**
  String managedStorageSummary(String available, String total);

  /// No description provided for @managedStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Termux storage could not be checked. Refresh to try again.'**
  String get managedStorageFailed;

  /// No description provided for @managedRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover a crashed managed server'**
  String get managedRecoveryTitle;

  /// No description provided for @managedRecoveryPolicy.
  ///
  /// In en, this message translates to:
  /// **'Opt in to at most 3 restart attempts, with delays of at least 5, 15 and 45 seconds. Only while this app is in the foreground. No install or update.'**
  String get managedRecoveryPolicy;

  /// No description provided for @managedRecoveryAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts used: {attempts} of 3. The limit survives app restarts.'**
  String managedRecoveryAttempts(int attempts);

  /// No description provided for @managedRecoveryExhausted.
  ///
  /// In en, this message translates to:
  /// **'Recovery limit reached. Check the server and start it manually before resetting the retry budget.'**
  String get managedRecoveryExhausted;

  /// No description provided for @managedRecoveryBackground.
  ///
  /// In en, this message translates to:
  /// **'Recovery waits while the app is in the background.'**
  String get managedRecoveryBackground;

  /// No description provided for @managedRecoveryChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the managed recovery operation…'**
  String get managedRecoveryChecking;

  /// No description provided for @managedRecoveryNext.
  ///
  /// In en, this message translates to:
  /// **'Next recovery attempt no earlier than {time}.'**
  String managedRecoveryNext(String time);

  /// No description provided for @managedRecoveryCheck.
  ///
  /// In en, this message translates to:
  /// **'Check recovery status'**
  String get managedRecoveryCheck;

  /// No description provided for @managedRecoveryReset.
  ///
  /// In en, this message translates to:
  /// **'Reset retry budget'**
  String get managedRecoveryReset;

  /// No description provided for @managedRecoverySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Recovery settings could not be saved. Retry.'**
  String get managedRecoverySaveFailed;

  /// No description provided for @managedRecoveryRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save or revoke recovery. Keep this server and retry before removing it.'**
  String get managedRecoveryRevokeFailed;

  /// No description provided for @managedRecoverySettingsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Recovery settings could not be read. Check the server before enabling recovery.'**
  String get managedRecoverySettingsUnreadable;

  /// No description provided for @managedRecoveryEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enable recovery. Start the managed server, then try again.'**
  String get managedRecoveryEnableFailed;

  /// No description provided for @managedRecoveryOwnershipChanged.
  ///
  /// In en, this message translates to:
  /// **'The managed operation changed. Check the server before enabling recovery again.'**
  String get managedRecoveryOwnershipChanged;

  /// No description provided for @managedRecoveryUncertain.
  ///
  /// In en, this message translates to:
  /// **'Recovery paused because Termux did not confirm the result. Refresh to continue.'**
  String get managedRecoveryUncertain;

  /// No description provided for @managedRecoveryRetryDisable.
  ///
  /// In en, this message translates to:
  /// **'Try disabling recovery again'**
  String get managedRecoveryRetryDisable;

  /// No description provided for @managedRecoveryStoppedWithCleanupError.
  ///
  /// In en, this message translates to:
  /// **'The local server is stopped. Recovery settings could not be fully cleared; retry disabling recovery in Servers before removing the server.'**
  String get managedRecoveryStoppedWithCleanupError;

  /// No description provided for @pluginMappingPersonal.
  ///
  /// In en, this message translates to:
  /// **'Your command links · not verified plugin ownership'**
  String get pluginMappingPersonal;

  /// No description provided for @pluginMappingReview.
  ///
  /// In en, this message translates to:
  /// **'Review /{command}'**
  String pluginMappingReview(String command);

  /// No description provided for @pluginMappingManage.
  ///
  /// In en, this message translates to:
  /// **'Link commands'**
  String get pluginMappingManage;

  /// No description provided for @pluginMappingDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose commands you associate with this plugin. These personal links apply only to this project on this server. Each action opens a review of the conversation and arguments before you run it.'**
  String get pluginMappingDescription;

  /// No description provided for @pluginMappingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No server commands are available to link.'**
  String get pluginMappingEmpty;

  /// No description provided for @pluginMappingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This plugin or command is no longer available here. Refresh and review your links.'**
  String get pluginMappingUnavailable;

  /// No description provided for @pluginMappingLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 16 commands for this plugin.'**
  String get pluginMappingLimit;

  /// No description provided for @pluginMappingSave.
  ///
  /// In en, this message translates to:
  /// **'Save links'**
  String get pluginMappingSave;

  /// No description provided for @pluginMappingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Links could not be saved. Check that this project is still selected and try again.'**
  String get pluginMappingSaveFailed;

  /// No description provided for @pluginMappingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Commands could not be loaded. Try again when connected.'**
  String get pluginMappingLoadFailed;

  /// No description provided for @mobileTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Server-reported tasks · mobile view'**
  String get mobileTasksDescription;

  /// No description provided for @mobileTasksUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Show unfinished only'**
  String get mobileTasksUnfinished;

  /// No description provided for @mobileTasksNoUnfinished.
  ///
  /// In en, this message translates to:
  /// **'No unfinished tasks in this list.'**
  String get mobileTasksNoUnfinished;

  /// No description provided for @mobileTaskPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get mobileTaskPending;

  /// No description provided for @mobileTaskInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get mobileTaskInProgress;

  /// No description provided for @mobileTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get mobileTaskCompleted;

  /// No description provided for @mobileTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get mobileTaskCancelled;

  /// Task card progress caption and progress-bar semantics label: completed tasks out of tracked (non-cancelled) tasks
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String mobileTasksProgress(int done, int total);

  /// Task card button: copies the full server-reported task list as plain text, ignoring the local unfinished-only filter
  ///
  /// In en, this message translates to:
  /// **'Copy all tasks'**
  String get mobileTasksCopyAll;

  /// Snackbar after the task list was placed on the clipboard
  ///
  /// In en, this message translates to:
  /// **'All tasks copied'**
  String get mobileTasksCopied;

  /// Snackbar when the clipboard write fails
  ///
  /// In en, this message translates to:
  /// **'Could not copy the task list.'**
  String get mobileTasksCopyFailed;

  /// No description provided for @mobileTaskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get mobileTaskPriorityHigh;

  /// No description provided for @mobileTaskPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium priority'**
  String get mobileTaskPriorityMedium;

  /// No description provided for @mobileTaskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low priority'**
  String get mobileTaskPriorityLow;

  /// No description provided for @pluginMappingClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear personal links'**
  String get pluginMappingClearAll;

  /// No description provided for @pluginMappingClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all personal command links?'**
  String get pluginMappingClearTitle;

  /// No description provided for @pluginMappingClearDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove personal plugin-command links for every project on this saved server, including previous projects. Server plugins and commands stay installed.'**
  String get pluginMappingClearDescription;

  /// No description provided for @pluginMappingClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear links'**
  String get pluginMappingClearConfirm;

  /// No description provided for @pluginMappingClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Personal links could not be cleared. Check that this server is still selected and try again.'**
  String get pluginMappingClearFailed;

  /// No description provided for @quotaMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Quota monitoring'**
  String get quotaMonitorTitle;

  /// No description provided for @quotaMonitorConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor this provider source?'**
  String get quotaMonitorConsentTitle;

  /// No description provided for @quotaMonitorConsent.
  ///
  /// In en, this message translates to:
  /// **'Allow this app to keep reading the trusted collector for this exact provider account after you leave this page, including after app restart. A cycle checks at most three saved sources, every five minutes in the foreground or fifteen minutes while your existing background service is active. With more than three sources, each source may wait several cycles. Device alerts require “Quota thresholds” in Notification settings and a freshly reported window at or above the selected percentage used. An alert records that past reading; open it to check current usage. Personal page thresholds are separate. No service is started here.'**
  String get quotaMonitorConsent;

  /// No description provided for @quotaMonitorRuntime.
  ///
  /// In en, this message translates to:
  /// **'Sources are checked in rotation, at most three per cycle; larger lists take several cycles. Background reads require the existing live service to be active; Android may stop it. Displayed readings expire when the collector says they do. Device alerts record past threshold readings, not current remaining allowance. This page never switches your active server.'**
  String get quotaMonitorRuntime;

  /// No description provided for @quotaMonitorEmpty.
  ///
  /// In en, this message translates to:
  /// **'No provider sources are monitored. Read Remaining for a trusted collector, then enable monitoring for that source.'**
  String get quotaMonitorEmpty;

  /// No description provided for @quotaMonitorEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable quota monitoring'**
  String get quotaMonitorEnable;

  /// No description provided for @quotaMonitorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Monitoring is off.'**
  String get quotaMonitorDisabled;

  /// No description provided for @quotaMonitorWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a fresh reading.'**
  String get quotaMonitorWaiting;

  /// No description provided for @quotaMonitorChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the trusted collector…'**
  String get quotaMonitorChecking;

  /// No description provided for @quotaMonitorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Fresh reading from the consented provider source.'**
  String get quotaMonitorCurrent;

  /// No description provided for @quotaMonitorPaused.
  ///
  /// In en, this message translates to:
  /// **'Monitoring is paused. Open the app or check the existing background service.'**
  String get quotaMonitorPaused;

  /// No description provided for @quotaMonitorWifiRequired.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmed Wi-Fi. Unknown network status does not permit a read.'**
  String get quotaMonitorWifiRequired;

  /// No description provided for @quotaMonitorSourceChanged.
  ///
  /// In en, this message translates to:
  /// **'This provider account or source changed, or could not be verified. Open Remaining, read it again and review new consent.'**
  String get quotaMonitorSourceChanged;

  /// No description provided for @quotaMonitorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save quota monitoring. A failed disable stays paused in this app; retry before closing the app.'**
  String get quotaMonitorSaveFailed;

  /// No description provided for @quotaMonitorDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable quota monitoring'**
  String get quotaMonitorDisable;

  /// No description provided for @setupChooseServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your server setup'**
  String get setupChooseServerTitle;

  /// No description provided for @setupChooseServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect an existing server, or use Termux to run OpenCode on this phone.'**
  String get setupChooseServerDescription;

  /// No description provided for @setupUncheckedTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue without an installation check?'**
  String get setupUncheckedTitle;

  /// No description provided for @setupUncheckedDescription.
  ///
  /// In en, this message translates to:
  /// **'The current installation could not be checked. Continuing may install or update OpenCode 1 in the app-managed Ubuntu environment. Existing Ubuntu files are kept. You can check again or connect by address instead.'**
  String get setupUncheckedDescription;

  /// No description provided for @setupUncheckedContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with Ubuntu'**
  String get setupUncheckedContinue;

  /// No description provided for @webSearchDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Search sends your query to this server’s selected search provider. Review results before adding them to your editable draft. Nothing is sent to the model here.'**
  String get webSearchDisclosure;

  /// No description provided for @webSearchManual.
  ///
  /// In en, this message translates to:
  /// **'Or paste a source'**
  String get webSearchManual;

  /// No description provided for @webSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Web search is unavailable. Configure a search provider on this server, then refresh providers. You can still paste a source below.'**
  String get webSearchUnavailable;

  /// No description provided for @webSearchAuthentication.
  ///
  /// In en, this message translates to:
  /// **'The server did not authorize web search. Check this server’s credentials.'**
  String get webSearchAuthentication;

  /// No description provided for @webSearchInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The search response did not match this server or the supported format. Refresh providers or paste a source.'**
  String get webSearchInvalidResponse;

  /// No description provided for @webSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Web search could not finish. Try again or paste a source.'**
  String get webSearchFailed;

  /// No description provided for @webSearchRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh providers'**
  String get webSearchRefresh;

  /// No description provided for @webSearchProvider.
  ///
  /// In en, this message translates to:
  /// **'Search provider'**
  String get webSearchProvider;

  /// No description provided for @webSearchQuery.
  ///
  /// In en, this message translates to:
  /// **'Search query'**
  String get webSearchQuery;

  /// No description provided for @webSearchSubmit.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get webSearchSubmit;

  /// No description provided for @webSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No usable results for this query.'**
  String get webSearchEmpty;

  /// No description provided for @webSearchOmitted.
  ///
  /// In en, this message translates to:
  /// **'Some results were omitted because their links or excerpts exceeded the review limits.'**
  String get webSearchOmitted;

  /// No description provided for @setupReinstallStart.
  ///
  /// In en, this message translates to:
  /// **'Reinstall & start'**
  String get setupReinstallStart;

  /// No description provided for @setupInstallVersionStart.
  ///
  /// In en, this message translates to:
  /// **'Install {version} & start'**
  String setupInstallVersionStart(String version);

  /// No description provided for @setupReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace installed OpenCode?'**
  String get setupReplaceTitle;

  /// No description provided for @setupReplaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Replace OpenCode {installedVersion} with {targetVersion} in the managed Ubuntu environment and restart the local server. Existing Ubuntu files are kept.'**
  String setupReplaceDescription(String installedVersion, String targetVersion);

  /// No description provided for @setupInstallRestart.
  ///
  /// In en, this message translates to:
  /// **'Install & restart'**
  String get setupInstallRestart;

  /// No description provided for @queueStorageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Saved queued prompts could not be read. New prompts cannot be queued until this device data is cleared.'**
  String get queueStorageUnreadable;

  /// No description provided for @queueStorageDiscardUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the unreadable queued prompts and their attachments from this device. Their contents and count are unknown. Nothing on the server is affected.'**
  String get queueStorageDiscardUnreadable;

  /// No description provided for @filesViewerScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'Server changed. Close and reopen this file.'**
  String get filesViewerScopeChanged;

  /// No description provided for @filesViewerPathChanged.
  ///
  /// In en, this message translates to:
  /// **'File context changed. Close and reopen this file.'**
  String get filesViewerPathChanged;

  /// No description provided for @queueStorageCountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Saved queued data could not be read. The number of queued prompts is unknown.'**
  String get queueStorageCountUnknown;

  /// No description provided for @codexConnectionVerified.
  ///
  /// In en, this message translates to:
  /// **'Connection verified. Save and connect to continue.'**
  String get codexConnectionVerified;

  /// No description provided for @codexApprovalRecoveryNotice.
  ///
  /// In en, this message translates to:
  /// **'After reconnecting, review any pending approvals on your computer.'**
  String get codexApprovalRecoveryNotice;

  /// No description provided for @connectionTokenRejected.
  ///
  /// In en, this message translates to:
  /// **'The connection token was rejected. Update it to reconnect.'**
  String get connectionTokenRejected;

  /// No description provided for @updateConnectionToken.
  ///
  /// In en, this message translates to:
  /// **'Update token'**
  String get updateConnectionToken;

  /// No description provided for @codexDraftReconnectNotice.
  ///
  /// In en, this message translates to:
  /// **'Review draft stays here; nothing is sent automatically.'**
  String get codexDraftReconnectNotice;

  /// No description provided for @codexTextOnlyPrompt.
  ///
  /// In en, this message translates to:
  /// **'This server supports text only. Remove attachments before sending.'**
  String get codexTextOnlyPrompt;

  /// No description provided for @codexOfflineDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before sending. Your draft is kept on this device.'**
  String get codexOfflineDraftSaved;

  /// No description provided for @codexReconnectBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Reconnect before sending.'**
  String get codexReconnectBeforeSending;

  /// No description provided for @connectionTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION TYPE'**
  String get connectionTypeLabel;

  /// No description provided for @openCodeConnectionLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get openCodeConnectionLabel;

  /// No description provided for @paseoExperimentalLabel.
  ///
  /// In en, this message translates to:
  /// **'Paseo: Claude Code, Pi (experimental)'**
  String get paseoExperimentalLabel;

  /// No description provided for @paseoAddressHint.
  ///
  /// In en, this message translates to:
  /// **'ws://100.64.0.1:6767 or wss://paseo.example'**
  String get paseoAddressHint;

  /// No description provided for @paseoAddressHelp.
  ///
  /// In en, this message translates to:
  /// **'The Paseo daemon on your computer. ws:// works on this device and on Tailscale addresses; use wss:// elsewhere.'**
  String get paseoAddressHelp;

  /// No description provided for @paseoPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Daemon password (optional)'**
  String get paseoPasswordLabel;

  /// No description provided for @paseoPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Set one with \"paseo daemon set-password\". Stored in this device\'s secure storage.'**
  String get paseoPasswordHelp;

  /// No description provided for @paseoSetupNotice.
  ///
  /// In en, this message translates to:
  /// **'Run \"paseo start --no-relay\" on the computer that has Claude Code or Pi installed. This app never uses the Paseo relay: connect on this device or over your own private network.'**
  String get paseoSetupNotice;

  /// No description provided for @codexExperimentalLabel.
  ///
  /// In en, this message translates to:
  /// **'Codex (experimental)'**
  String get codexExperimentalLabel;

  /// No description provided for @connectionDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get connectionDisplayName;

  /// No description provided for @connectionDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the server host'**
  String get connectionDisplayNameHint;

  /// No description provided for @connectionServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectionServerAddress;

  /// No description provided for @codexAddressHint.
  ///
  /// In en, this message translates to:
  /// **'wss://codex.example or ws://127.0.0.1:4500'**
  String get codexAddressHint;

  /// No description provided for @codexAddressHelp.
  ///
  /// In en, this message translates to:
  /// **'Use wss:// for remote servers. ws:// is limited to this device.'**
  String get codexAddressHelp;

  /// No description provided for @codexProjectFolder.
  ///
  /// In en, this message translates to:
  /// **'Project folder on server'**
  String get codexProjectFolder;

  /// No description provided for @codexTokenReentry.
  ///
  /// In en, this message translates to:
  /// **'Re-enter connection token'**
  String get codexTokenReentry;

  /// No description provided for @codexTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection token'**
  String get codexTokenLabel;

  /// No description provided for @codexTokenStorageHelp.
  ///
  /// In en, this message translates to:
  /// **'Stored securely on this device and sent only to this Codex server.'**
  String get codexTokenStorageHelp;

  /// No description provided for @codexShowToken.
  ///
  /// In en, this message translates to:
  /// **'Show connection token'**
  String get codexShowToken;

  /// No description provided for @codexHideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide connection token'**
  String get codexHideToken;

  /// No description provided for @codexPasteToken.
  ///
  /// In en, this message translates to:
  /// **'Paste connection token'**
  String get codexPasteToken;

  /// No description provided for @connectionCloseEditor.
  ///
  /// In en, this message translates to:
  /// **'Close server editor'**
  String get connectionCloseEditor;

  /// No description provided for @connectionCredentialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A saved server credential can no longer be read. Edit the active server and re-enter it before connecting.'**
  String get connectionCredentialUnavailable;

  /// No description provided for @projectContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Project context'**
  String get projectContextTitle;

  /// No description provided for @projectConfiguredFolder.
  ///
  /// In en, this message translates to:
  /// **'Configured folder'**
  String get projectConfiguredFolder;

  /// No description provided for @termuxGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Termux once'**
  String get termuxGuideTitle;

  /// No description provided for @termuxGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'We copy the command for you. Here is what to do when Termux opens.'**
  String get termuxGuideIntro;

  /// No description provided for @termuxGuideAutomaticCheck.
  ///
  /// In en, this message translates to:
  /// **'When you return, we will check the connection automatically.'**
  String get termuxGuideAutomaticCheck;

  /// No description provided for @termuxGuideShowCommand.
  ///
  /// In en, this message translates to:
  /// **'Show command'**
  String get termuxGuideShowCommand;

  /// No description provided for @termuxGuideOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening Termux...'**
  String get termuxGuideOpening;

  /// No description provided for @termuxGuideCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Copy & open'**
  String get termuxGuideCopyTitle;

  /// No description provided for @termuxGuideCopyDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap Copy & open Termux above. Allow Android\'s permission request if shown.'**
  String get termuxGuideCopyDescription;

  /// No description provided for @termuxGuidePasteTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Press and hold, then Paste'**
  String get termuxGuidePasteTitle;

  /// No description provided for @termuxGuidePasteDescription.
  ///
  /// In en, this message translates to:
  /// **'In Termux, press and hold near the blinking cursor. Tap Paste in the menu.'**
  String get termuxGuidePasteDescription;

  /// No description provided for @termuxGuideEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Enter, then return'**
  String get termuxGuideEnterTitle;

  /// Keep bridge-unlocked unchanged: it is the literal terminal command output.
  ///
  /// In en, this message translates to:
  /// **'Press the keyboard Enter or return key. When Termux shows bridge-unlocked, switch back to this app.'**
  String get termuxGuideEnterDescription;

  /// No description provided for @termuxGuideCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get termuxGuideCopied;

  /// No description provided for @termuxGuidePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get termuxGuidePaste;

  /// No description provided for @termuxGuideEnterKey.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get termuxGuideEnterKey;

  /// No description provided for @termuxGuideIllustrationNote.
  ///
  /// In en, this message translates to:
  /// **'Illustrations only. Your keyboard and Paste menu may look different.'**
  String get termuxGuideIllustrationNote;

  /// No description provided for @termuxGuideOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The command was copied, but Termux could not open. Open Termux yourself or try Copy & open Termux again.'**
  String get termuxGuideOpenFailed;

  /// No description provided for @termuxGuideCopyOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the command or open Termux.'**
  String get termuxGuideCopyOpenFailed;

  /// No description provided for @termuxPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Android denied the Termux command permission. Allow it in OpenCode app settings.'**
  String get termuxPermissionDenied;

  /// Snackbar shown once when the New task home-screen shortcut arrives while the saved server is still connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting to the saved server. The new conversation opens when it is ready.'**
  String get launchShortcutWaiting;

  /// Snackbar shown on the servers screen when the New task shortcut arrives with no saved server selected
  ///
  /// In en, this message translates to:
  /// **'Choose a server, then start a new conversation.'**
  String get launchShortcutNoServer;

  /// Snackbar shown on the servers screen when the New task shortcut arrives while the saved server needs its password or token entered again
  ///
  /// In en, this message translates to:
  /// **'Enter the credentials for the saved server, then start a new conversation.'**
  String get launchShortcutReentry;

  /// Snackbar shown on the servers screen when the New task shortcut arrives after the saved server connection failed
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the saved server. Choose or fix a server, then start a new conversation.'**
  String get launchShortcutConnectionFailed;

  /// Snackbar shown when the New task shortcut reached a connected server but creating the session failed
  ///
  /// In en, this message translates to:
  /// **'Could not start a new conversation. {error}'**
  String launchShortcutNewTaskFailed(String error);

  /// Launcher shortcut label for a pinned session that has no title yet
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get launchUiPinnedUntitled;

  /// Snackbar shown once when a pinned-session launcher shortcut arrives while the saved server is still connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting to the saved server. The conversation opens when it is ready.'**
  String get launchUiSessionWaiting;

  /// Snackbar shown on the servers screen when a pinned-session launcher shortcut arrives with no saved server selected
  ///
  /// In en, this message translates to:
  /// **'Choose a server, then open the conversation from its list.'**
  String get launchUiSessionNoServer;

  /// Snackbar shown on the servers screen when a pinned-session launcher shortcut arrives while the saved server needs its password or token entered again
  ///
  /// In en, this message translates to:
  /// **'Enter the credentials for the saved server, then open the conversation from its list.'**
  String get launchUiSessionReentry;

  /// Snackbar shown on the servers screen when a pinned-session launcher shortcut arrives after the saved server connection failed
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the saved server. Choose or fix a server, then open the conversation from its list.'**
  String get launchUiSessionConnectionFailed;

  /// Snackbar shown when a pinned-session launcher shortcut names a server profile other than the active one; the app never switches servers on its own
  ///
  /// In en, this message translates to:
  /// **'That shortcut belongs to another server. Connect to that server, then open the conversation from its list.'**
  String get launchUiSessionOtherServer;

  /// Snackbar shown on the servers screen when the Quick Settings tile is tapped with no saved server selected
  ///
  /// In en, this message translates to:
  /// **'Choose a server to see what needs your attention.'**
  String get launchUiActivityNoServer;

  /// Queued draft bubble label while the offline flush is dispatching it
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get queuedSending;

  /// Queued draft bubble label for a send that left the device without a confirmed outcome; never resent automatically
  ///
  /// In en, this message translates to:
  /// **'Delivery unconfirmed — review before resending'**
  String get queuedDeliveryUnconfirmed;

  /// Queued draft bubble label for an unconfirmed send that also recorded a transport error
  ///
  /// In en, this message translates to:
  /// **'Delivery unconfirmed: {error}'**
  String queuedDeliveryUnconfirmedWithError(String error);

  /// Tooltip on the queued draft bubble's explicit resend action
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get queuedResendTooltip;

  /// Confirmation dialog title before resending an unconfirmed queued draft
  ///
  /// In en, this message translates to:
  /// **'Send this draft again?'**
  String get queuedResendTitle;

  /// Confirmation dialog body before resending an unconfirmed queued draft
  ///
  /// In en, this message translates to:
  /// **'It may already have reached OpenCode. Sending again can duplicate it.'**
  String get queuedResendMessage;

  /// Confirmation dialog affirmative button for resending an unconfirmed queued draft
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get queuedResendConfirm;

  /// Cancel label on the resend and discard dialogs for an unconfirmed queued draft; the draft stays queued for review
  ///
  /// In en, this message translates to:
  /// **'Keep for review'**
  String get queuedKeepForReview;

  /// Discard sheet body for a queued draft whose send was never confirmed
  ///
  /// In en, this message translates to:
  /// **'Its earlier send was never confirmed; it may already be in the conversation.'**
  String get queuedDiscardUnconfirmedMessage;

  /// First-time on-device server runtime selection
  ///
  /// In en, this message translates to:
  /// **'Which OpenCode would you like to use?'**
  String get setupRuntimeTitle;

  /// Existing OpenCode server generation
  ///
  /// In en, this message translates to:
  /// **'OpenCode 1'**
  String get setupRuntimeOne;

  /// Description of the default first-run runtime
  ///
  /// In en, this message translates to:
  /// **'Recommended for the widest feature support in this app.'**
  String get setupRuntimeOneDetail;

  /// Experimental new OpenCode server generation
  ///
  /// In en, this message translates to:
  /// **'OpenCode 2 beta'**
  String get setupRuntimeTwo;

  /// Honest support note for the optional beta runtime
  ///
  /// In en, this message translates to:
  /// **'Try the new server API. Some features are unavailable in this beta.'**
  String get setupRuntimeTwoDetail;

  /// Names the exact runtime and pinned version before installation
  ///
  /// In en, this message translates to:
  /// **'Install {runtime} ({version}) in an app-managed Ubuntu environment. Existing Ubuntu files are reused.'**
  String setupRuntimeInstallDetail(String runtime, String version);

  /// Names the selected runtime and pinned version in the update confirmation
  ///
  /// In en, this message translates to:
  /// **'The app will install {runtime} {version}, restart only the managed local server, and reconnect this server.'**
  String setupRuntimeUpdateDetail(String runtime, String version);

  /// Connection banner line counting queued drafts whose send was never confirmed
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 draft with an unconfirmed send to review.} other{{count} drafts with an unconfirmed send to review.}}'**
  String queuedBannerReview(int count);

  /// Tooltip and accessibility label of the workspace action that opens the fresh-worktree task sheet
  ///
  /// In en, this message translates to:
  /// **'Start a task in a fresh worktree'**
  String get isolatedTaskAction;

  /// Title of the fresh-worktree task sheet
  ///
  /// In en, this message translates to:
  /// **'New task in a fresh worktree'**
  String get isolatedTaskTitle;

  /// Explanation shown before the user starts a fresh-worktree task
  ///
  /// In en, this message translates to:
  /// **'OpenCode creates a new Git worktree and branch for {project} and runs the project\'s setup. The worktree stays listed under Manage project until you remove it there.'**
  String isolatedTaskIntro(String project);

  /// Label of the optional worktree name field
  ///
  /// In en, this message translates to:
  /// **'Worktree name (optional)'**
  String get isolatedTaskNameLabel;

  /// Helper text under the optional worktree name field
  ///
  /// In en, this message translates to:
  /// **'Leave empty to let OpenCode choose a name.'**
  String get isolatedTaskNameHelper;

  /// Primary button that creates the worktree and waits for it
  ///
  /// In en, this message translates to:
  /// **'Create and start'**
  String get isolatedTaskStart;

  /// Status while the create request is in flight
  ///
  /// In en, this message translates to:
  /// **'Creating the worktree…'**
  String get isolatedTaskCreating;

  /// Caution under the creating status: cancelling does not imply server rollback
  ///
  /// In en, this message translates to:
  /// **'Stopping now cannot undo a create the server may already be running.'**
  String get isolatedTaskCreatingHint;

  /// Status after the server returned the worktree, before its readiness event
  ///
  /// In en, this message translates to:
  /// **'{name} was created. OpenCode is preparing it…'**
  String isolatedTaskPreparing(String name);

  /// Status once the worktree reported ready and the session is being opened
  ///
  /// In en, this message translates to:
  /// **'{name} is ready. Opening a blank conversation…'**
  String isolatedTaskReady(String name);

  /// Status when the worktree is ready but the last open attempt failed and nothing is in flight
  ///
  /// In en, this message translates to:
  /// **'{name} is ready.'**
  String isolatedTaskReadyIdle(String name);

  /// Status when no readiness event arrived within the wait
  ///
  /// In en, this message translates to:
  /// **'{name} was created, but its setup status is not confirmed.'**
  String isolatedTaskUnconfirmed(String name);

  /// Explanation under the unconfirmed status
  ///
  /// In en, this message translates to:
  /// **'You can keep waiting or open it now. Setup may still be running.'**
  String get isolatedTaskUnconfirmedHint;

  /// Status when the server reported worktree.failed
  ///
  /// In en, this message translates to:
  /// **'OpenCode could not prepare the worktree.'**
  String get isolatedTaskFailed;

  /// Status when the create request itself failed
  ///
  /// In en, this message translates to:
  /// **'The worktree could not be created.'**
  String get isolatedTaskCreateFailed;

  /// Note under a failed preparation: the created worktree is kept
  ///
  /// In en, this message translates to:
  /// **'{name} stays listed under Manage project. Nothing was deleted.'**
  String isolatedTaskFailedKept(String name);

  /// Status after the user stopped waiting for readiness
  ///
  /// In en, this message translates to:
  /// **'Stopped waiting.'**
  String get isolatedTaskCancelled;

  /// Note after stopping when the server had already returned the worktree
  ///
  /// In en, this message translates to:
  /// **'{name} was created and stays listed under Manage project.'**
  String isolatedTaskCancelledKept(String name);

  /// Note after stopping before the create request answered
  ///
  /// In en, this message translates to:
  /// **'If OpenCode created the worktree, it appears under Manage project.'**
  String get isolatedTaskCancelledUnknown;

  /// Status while switching scope and creating the session
  ///
  /// In en, this message translates to:
  /// **'Opening a blank conversation in {name}…'**
  String isolatedTaskOpening(String name);

  /// Status once the blank session exists in the worktree
  ///
  /// In en, this message translates to:
  /// **'Conversation ready in {name}. Nothing has been sent.'**
  String isolatedTaskOpened(String name);

  /// Branch line under the worktree status
  ///
  /// In en, this message translates to:
  /// **'Branch {branch}'**
  String isolatedTaskBranch(String branch);

  /// Button that stops waiting for readiness without deleting anything
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get isolatedTaskStopWaiting;

  /// Button that waits another period for the readiness event
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get isolatedTaskKeepWaiting;

  /// Button that opens a session in a worktree whose setup is unconfirmed
  ///
  /// In en, this message translates to:
  /// **'Open anyway'**
  String get isolatedTaskOpenAnyway;

  /// Button that retries opening the session after an open error
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get isolatedTaskRetryOpen;

  /// Close action on the fresh-worktree task sheet
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get isolatedTaskClose;

  /// No description provided for @returnBriefTitle.
  ///
  /// In en, this message translates to:
  /// **'Unreviewed work'**
  String get returnBriefTitle;

  /// No description provided for @returnBriefDescription.
  ///
  /// In en, this message translates to:
  /// **'For this project on this device. Dismissing keeps conversations unread and requests pending.'**
  String get returnBriefDescription;

  /// No description provided for @returnBriefUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get returnBriefUntitled;

  /// No description provided for @returnBriefStale.
  ///
  /// In en, this message translates to:
  /// **'Last observed state. Reconnect or refresh to check current work and requests.'**
  String get returnBriefStale;

  /// No description provided for @returnBriefStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Review status unknown'**
  String get returnBriefStatusUnknown;

  /// No description provided for @returnBriefUnknown.
  ///
  /// In en, this message translates to:
  /// **'This server does not report read state. Unreviewed results are unknown.'**
  String get returnBriefUnknown;

  /// No description provided for @returnBriefPartial.
  ///
  /// In en, this message translates to:
  /// **'Loaded conversations only. The conversation list is still incomplete.'**
  String get returnBriefPartial;

  /// No description provided for @returnBriefAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get returnBriefAnswer;

  /// No description provided for @returnBriefUnreviewed.
  ///
  /// In en, this message translates to:
  /// **'Unreviewed conversation. Open results to check the outcome.'**
  String get returnBriefUnreviewed;

  /// No description provided for @returnBriefReview.
  ///
  /// In en, this message translates to:
  /// **'Review results'**
  String get returnBriefReview;

  /// No description provided for @returnBriefContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get returnBriefContinue;

  /// No description provided for @returnBriefMore.
  ///
  /// In en, this message translates to:
  /// **'Additional items: {count}. They remain unacknowledged; see the conversations below or Inbox.'**
  String returnBriefMore(int count);

  /// No description provided for @returnBriefSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Dismissal was not saved. These items are still unreviewed. Try again.'**
  String get returnBriefSaveFailed;

  /// No description provided for @returnBriefSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving dismissal...'**
  String get returnBriefSaving;

  /// No description provided for @returnBriefDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss shown items'**
  String get returnBriefDismiss;

  /// No description provided for @capsuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Context capsule'**
  String get capsuleTitle;

  /// No description provided for @capsuleEntry.
  ///
  /// In en, this message translates to:
  /// **'Collect notes, errors and screenshots for this conversation'**
  String get capsuleEntry;

  /// No description provided for @capsuleDescription.
  ///
  /// In en, this message translates to:
  /// **'Build a bundle for this conversation. Applying adds it to your existing draft; nothing is sent. Unapplied edits are kept only while this screen is open.'**
  String get capsuleDescription;

  /// No description provided for @capsuleNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get capsuleNote;

  /// No description provided for @capsuleError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get capsuleError;

  /// No description provided for @capsuleCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get capsuleCode;

  /// No description provided for @capsuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get capsuleLabel;

  /// No description provided for @capsuleExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Excerpt'**
  String get capsuleExcerpt;

  /// No description provided for @capsulePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get capsulePaste;

  /// No description provided for @capsuleRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get capsuleRemove;

  /// No description provided for @capsuleAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add screenshot or image'**
  String get capsuleAddImage;

  /// No description provided for @capsulePreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to preview'**
  String get capsulePreview;

  /// No description provided for @capsuleApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to draft'**
  String get capsuleApply;

  /// No description provided for @capsuleApplied.
  ///
  /// In en, this message translates to:
  /// **'Context added to your saved draft. Review it before sending.'**
  String get capsuleApplied;

  /// No description provided for @capsuleScopeChanged.
  ///
  /// In en, this message translates to:
  /// **'The conversation, server or draft changed. Close this capsule and reopen it from the intended conversation.'**
  String get capsuleScopeChanged;

  /// No description provided for @capsuleTextOnly.
  ///
  /// In en, this message translates to:
  /// **'This server accepts text only. You can still collect notes, errors and code.'**
  String get capsuleTextOnly;

  /// No description provided for @capsuleImagesOnly.
  ///
  /// In en, this message translates to:
  /// **'Choose a PNG, JPEG, GIF or WebP image. Paste text into an excerpt instead.'**
  String get capsuleImagesOnly;

  /// No description provided for @capsuleImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add that image. Use up to 5 attachments, 10 MB each and 20 MB total, including your existing draft.'**
  String get capsuleImageFailed;

  /// No description provided for @capsulePasteFailed.
  ///
  /// In en, this message translates to:
  /// **'Clipboard text is unavailable. You can type or paste into the excerpt.'**
  String get capsulePasteFailed;

  /// No description provided for @capsuleTextLimit.
  ///
  /// In en, this message translates to:
  /// **'Keep each excerpt under 16,000 characters and the bundle under 32,000.'**
  String get capsuleTextLimit;

  /// No description provided for @markdownCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get markdownCopyCode;

  /// No description provided for @markdownCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get markdownCopied;

  /// No description provided for @markdownCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy code. Try again.'**
  String get markdownCopyFailed;

  /// No description provided for @markdownCopyRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get markdownCopyRetry;

  /// No description provided for @markdownWrapCode.
  ///
  /// In en, this message translates to:
  /// **'Wrap lines'**
  String get markdownWrapCode;

  /// No description provided for @markdownScrollCode.
  ///
  /// In en, this message translates to:
  /// **'Scroll lines'**
  String get markdownScrollCode;

  /// No description provided for @markdownExpandCode.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get markdownExpandCode;

  /// No description provided for @markdownReaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Code reader'**
  String get markdownReaderTitle;

  /// No description provided for @markdownSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot of the code when opened. Close and reopen to read later updates.'**
  String get markdownSnapshot;

  /// No description provided for @tailscaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with Tailscale'**
  String get tailscaleTitle;

  /// No description provided for @tailscaleQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Use your private network and an HTTPS server address'**
  String get tailscaleQuickAdd;

  /// No description provided for @tailscaleIntro.
  ///
  /// In en, this message translates to:
  /// **'Reach OpenCode on another computer through your own Tailscale network. You control sign-in and VPN access in the official Tailscale app.'**
  String get tailscaleIntro;

  /// No description provided for @tailscaleAppStep.
  ///
  /// In en, this message translates to:
  /// **'1. Open your private network'**
  String get tailscaleAppStep;

  /// No description provided for @tailscaleChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for the Tailscale app…'**
  String get tailscaleChecking;

  /// No description provided for @tailscaleInstalled.
  ///
  /// In en, this message translates to:
  /// **'Tailscale is installed. VPN connection is unverified.'**
  String get tailscaleInstalled;

  /// No description provided for @tailscaleMissing.
  ///
  /// In en, this message translates to:
  /// **'Tailscale is not installed. Install the official app, then return and check again.'**
  String get tailscaleMissing;

  /// No description provided for @tailscaleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Could not check the app. Try again, or open Tailscale from your phone.'**
  String get tailscaleUnknown;

  /// No description provided for @tailscaleUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device cannot open the Android app. Set up Tailscale on this device yourself, then review your HTTPS address below.'**
  String get tailscaleUnsupported;

  /// No description provided for @tailscaleVpnHandoff.
  ///
  /// In en, this message translates to:
  /// **'In Tailscale, sign in to the network that can reach your server, approve Android’s VPN prompt if asked, and turn the connection on. OpenCode cannot see or change that VPN state.'**
  String get tailscaleVpnHandoff;

  /// No description provided for @tailscaleReturned.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. App presence was checked again; use Test connection on the next screen to check your server.'**
  String get tailscaleReturned;

  /// No description provided for @tailscaleOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Tailscale could not open. Open it from your launcher, then return here. Your address stays in this form.'**
  String get tailscaleOpenFailed;

  /// No description provided for @tailscaleOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Tailscale'**
  String get tailscaleOpen;

  /// No description provided for @tailscaleInstall.
  ///
  /// In en, this message translates to:
  /// **'Get official Android app'**
  String get tailscaleInstall;

  /// No description provided for @tailscaleCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check app again'**
  String get tailscaleCheckAgain;

  /// No description provided for @tailscaleAddressStep.
  ///
  /// In en, this message translates to:
  /// **'2. Review your server address'**
  String get tailscaleAddressStep;

  /// No description provided for @tailscaleAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Private HTTPS server address'**
  String get tailscaleAddressLabel;

  /// No description provided for @tailscaleAddressDetail.
  ///
  /// In en, this message translates to:
  /// **'Use the full HTTPS origin printed by Tailscale Serve, such as https://computer.tailnet-name.ts.net. Keep any HTTPS port it prints. A short device name or a raw HTTP port may not provide a valid certificate.'**
  String get tailscaleAddressDetail;

  /// No description provided for @tailscaleAddressError.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS origin with a valid port (1–65535). Remove paths, credentials, query text and fragments. Use the full address from Serve; do not replace https with http.'**
  String get tailscaleAddressError;

  /// No description provided for @tailscaleReviewDetail.
  ///
  /// In en, this message translates to:
  /// **'Continue only with an address you recognize. The next screen reviews your server credentials before you explicitly test or save. This app cannot confirm that an address is private from its name alone.'**
  String get tailscaleReviewDetail;

  /// No description provided for @tailscaleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to authentication'**
  String get tailscaleContinue;

  /// No description provided for @tailscaleHelp.
  ///
  /// In en, this message translates to:
  /// **'Tailscale setup and recovery'**
  String get tailscaleHelp;

  /// No description provided for @tailscaleServeHelp.
  ///
  /// In en, this message translates to:
  /// **'On the server computer, Tailscale Serve can provide private HTTPS for a local OpenCode port. Use Serve, not public Funnel. Your tailnet access rules still apply. Enabling HTTPS publishes the certificate’s device and tailnet names in a public certificate log, although access stays private. Review the official guide before changing your server.'**
  String get tailscaleServeHelp;

  /// No description provided for @tailscaleServeDocs.
  ///
  /// In en, this message translates to:
  /// **'Read the official Serve guide'**
  String get tailscaleServeDocs;

  /// No description provided for @tailscaleAndroidDocs.
  ///
  /// In en, this message translates to:
  /// **'Read the official Android guide'**
  String get tailscaleAndroidDocs;

  /// No description provided for @tailscaleRecovery.
  ///
  /// In en, this message translates to:
  /// **'If the server is unreachable, check Tailscale on both devices, the full HTTPS name and port, Serve on the server, and your network’s access rules. A VPN or DNS conflict may also prevent access. Keep HTTPS enabled. Correct the server password if authentication is rejected, then retry Test connection.'**
  String get tailscaleRecovery;

  /// No description provided for @tailscaleEditorDetail.
  ///
  /// In en, this message translates to:
  /// **'Your network connection is managed in Tailscale. Test connection checks this OpenCode server, not the VPN. Enter the server’s own username and password here, not your Tailscale login. Setup help keeps these fields intact.'**
  String get tailscaleEditorDetail;

  /// No description provided for @a2aDraftSaveError.
  ///
  /// In en, this message translates to:
  /// **'Draft changes could not be saved. Keep this screen open and retry before leaving.'**
  String get a2aDraftSaveError;

  /// No description provided for @a2aRetryDraftSave.
  ///
  /// In en, this message translates to:
  /// **'Try saving draft again'**
  String get a2aRetryDraftSave;

  /// No description provided for @a2aSavingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving draft changes…'**
  String get a2aSavingDraft;

  /// No description provided for @a2aCardVersion.
  ///
  /// In en, this message translates to:
  /// **'Agent version: {version}'**
  String a2aCardVersion(String version);

  /// No description provided for @a2aSupportedConnection.
  ///
  /// In en, this message translates to:
  /// **'A2A 1.0 · JSON-RPC · Text tasks'**
  String get a2aSupportedConnection;

  /// No description provided for @a2aTitle.
  ///
  /// In en, this message translates to:
  /// **'External agents'**
  String get a2aTitle;

  /// No description provided for @a2aIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring an agent you trust.'**
  String get a2aIntro;

  /// No description provided for @a2aBoundary.
  ///
  /// In en, this message translates to:
  /// **'Connect to an A2A agent and send a task you choose. Only the text you submit is shared. Your projects, files and other conversations stay on this phone.'**
  String get a2aBoundary;

  /// No description provided for @a2aAdd.
  ///
  /// In en, this message translates to:
  /// **'Add agent'**
  String get a2aAdd;

  /// No description provided for @a2aEmpty.
  ///
  /// In en, this message translates to:
  /// **'No external agents yet. Start with an agent\'s HTTPS address or public Agent Card URL.'**
  String get a2aEmpty;

  /// No description provided for @a2aDeleteAgent.
  ///
  /// In en, this message translates to:
  /// **'Remove agent'**
  String get a2aDeleteAgent;

  /// No description provided for @a2aDeleteAgentDetail.
  ///
  /// In en, this message translates to:
  /// **'Remove this agent, its saved tasks and its credential from this phone. This does not stop remote work or delete data held by the agent.'**
  String get a2aDeleteAgentDetail;

  /// No description provided for @a2aDeleteLocal.
  ///
  /// In en, this message translates to:
  /// **'Remove from this phone'**
  String get a2aDeleteLocal;

  /// No description provided for @a2aDeletionPending.
  ///
  /// In en, this message translates to:
  /// **'Removal from this phone is incomplete. This agent is unavailable until its remaining data is removed.'**
  String get a2aDeletionPending;

  /// No description provided for @a2aRetryDelete.
  ///
  /// In en, this message translates to:
  /// **'Try removing again'**
  String get a2aRetryDelete;

  /// No description provided for @a2aInspectIntro.
  ///
  /// In en, this message translates to:
  /// **'Inspect before you connect'**
  String get a2aInspectIntro;

  /// No description provided for @a2aAddress.
  ///
  /// In en, this message translates to:
  /// **'Agent address'**
  String get a2aAddress;

  /// No description provided for @a2aInspect.
  ///
  /// In en, this message translates to:
  /// **'Inspect Agent Card'**
  String get a2aInspect;

  /// No description provided for @a2aUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: this card does not advertise the supported A2A 1.0 JSON-RPC, text and authentication combination on the same origin, or requires an unsupported extension. No task can be sent.'**
  String get a2aUnsupported;

  /// No description provided for @a2aBearerDetail.
  ///
  /// In en, this message translates to:
  /// **'Supply an HTTP bearer credential issued for this agent. It is stored in the phone\'s secure storage and sent only to the inspected origin. No sign-in or credential sharing with other agents is performed.'**
  String get a2aBearerDetail;

  /// No description provided for @a2aNoAuthDetail.
  ///
  /// In en, this message translates to:
  /// **'This card requests no authentication. Do not send private information unless you trust this agent.'**
  String get a2aNoAuthDetail;

  /// No description provided for @a2aBearer.
  ///
  /// In en, this message translates to:
  /// **'Agent bearer credential'**
  String get a2aBearer;

  /// No description provided for @a2aSave.
  ///
  /// In en, this message translates to:
  /// **'Save agent'**
  String get a2aSave;

  /// No description provided for @a2aCardClaim.
  ///
  /// In en, this message translates to:
  /// **'Self-reported Agent Card. This app has not verified the agent\'s identity, skills or billing terms.'**
  String get a2aCardClaim;

  /// No description provided for @a2aSkills.
  ///
  /// In en, this message translates to:
  /// **'Advertised skills'**
  String get a2aSkills;

  /// No description provided for @a2aNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get a2aNewTask;

  /// No description provided for @a2aTaskPrompt.
  ///
  /// In en, this message translates to:
  /// **'Task text'**
  String get a2aTaskPrompt;

  /// No description provided for @a2aSendDetail.
  ///
  /// In en, this message translates to:
  /// **'Review the text and destination before sending. The agent may use its own compute or services; check its terms. This app cannot estimate or limit that usage.'**
  String get a2aSendDetail;

  /// No description provided for @a2aReviewTask.
  ///
  /// In en, this message translates to:
  /// **'Review task'**
  String get a2aReviewTask;

  /// No description provided for @a2aUpdateCredential.
  ///
  /// In en, this message translates to:
  /// **'Update credential'**
  String get a2aUpdateCredential;

  /// No description provided for @a2aSavedTasks.
  ///
  /// In en, this message translates to:
  /// **'Saved tasks'**
  String get a2aSavedTasks;

  /// No description provided for @a2aReopenDetail.
  ///
  /// In en, this message translates to:
  /// **'Reopening checks the existing task. It never sends your task again.'**
  String get a2aReopenDetail;

  /// No description provided for @a2aDeliveryUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Delivery unconfirmed'**
  String get a2aDeliveryUnconfirmed;

  /// No description provided for @a2aDraft.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get a2aDraft;

  /// No description provided for @a2aBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a2aBack;

  /// No description provided for @a2aTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent task'**
  String get a2aTaskTitle;

  /// No description provided for @a2aFresh.
  ///
  /// In en, this message translates to:
  /// **'Checked with the agent this visit.'**
  String get a2aFresh;

  /// No description provided for @a2aSavedSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Saved locally. Refresh a known task to check its current state.'**
  String get a2aSavedSnapshot;

  /// No description provided for @a2aCancelTask.
  ///
  /// In en, this message translates to:
  /// **'Stop task'**
  String get a2aCancelTask;

  /// No description provided for @a2aCancelDetail.
  ///
  /// In en, this message translates to:
  /// **'Ask this agent to stop this task. Work may already have finished, and the agent decides whether stopping is possible.'**
  String get a2aCancelDetail;

  /// No description provided for @a2aRequestCancel.
  ///
  /// In en, this message translates to:
  /// **'Ask to stop'**
  String get a2aRequestCancel;

  /// No description provided for @a2aForgetTask.
  ///
  /// In en, this message translates to:
  /// **'Forget saved task'**
  String get a2aForgetTask;

  /// No description provided for @a2aForgetDetail.
  ///
  /// In en, this message translates to:
  /// **'Remove this saved task from the phone. Remote work may continue, including a send whose delivery is unconfirmed. This cannot delete the agent\'s copy.'**
  String get a2aForgetDetail;

  /// No description provided for @a2aYourReply.
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get a2aYourReply;

  /// No description provided for @a2aSend.
  ///
  /// In en, this message translates to:
  /// **'Send to agent'**
  String get a2aSend;

  /// No description provided for @a2aReplySameTask.
  ///
  /// In en, this message translates to:
  /// **'Reply to this task'**
  String get a2aReplySameTask;

  /// No description provided for @a2aAgentOutput.
  ///
  /// In en, this message translates to:
  /// **'Agent output'**
  String get a2aAgentOutput;

  /// No description provided for @a2aBlockedLink.
  ///
  /// In en, this message translates to:
  /// **'Unsupported link'**
  String get a2aBlockedLink;

  /// No description provided for @a2aReviewLink.
  ///
  /// In en, this message translates to:
  /// **'Review external link'**
  String get a2aReviewLink;

  /// No description provided for @a2aOmittedContent.
  ///
  /// In en, this message translates to:
  /// **'Some output is omitted. This view shows bounded text and links; binary or structured artifacts are not downloaded or executed.'**
  String get a2aOmittedContent;

  /// No description provided for @a2aRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh task'**
  String get a2aRefresh;

  /// No description provided for @a2aSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get a2aSubmitted;

  /// No description provided for @a2aWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get a2aWorking;

  /// No description provided for @a2aInputRequired.
  ///
  /// In en, this message translates to:
  /// **'Your input is needed'**
  String get a2aInputRequired;

  /// No description provided for @a2aAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Agent requires authentication'**
  String get a2aAuthRequired;

  /// No description provided for @a2aCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get a2aCompleted;

  /// No description provided for @a2aFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get a2aFailed;

  /// No description provided for @a2aCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get a2aCanceled;

  /// No description provided for @a2aRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get a2aRejected;

  /// No description provided for @a2aUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unsupported task state'**
  String get a2aUnknown;

  /// No description provided for @a2aAddressError.
  ///
  /// In en, this message translates to:
  /// **'Use an HTTPS origin or public Agent Card URL without credentials, query or fragment. HTTP is supported only on this device\'s loopback address.'**
  String get a2aAddressError;

  /// No description provided for @a2aAuthenticationError.
  ///
  /// In en, this message translates to:
  /// **'The agent rejected or could not use this credential. Return to the agent to update it, then reopen the saved task.'**
  String get a2aAuthenticationError;

  /// No description provided for @a2aUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The agent could not be reached or rejected this operation. Refresh a known task to check its state.'**
  String get a2aUnavailable;

  /// No description provided for @a2aInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The agent returned an unsupported, oversized or mismatched response. The saved task has not been replaced.'**
  String get a2aInvalidResponse;

  /// No description provided for @a2aUncertain.
  ///
  /// In en, this message translates to:
  /// **'The agent may have received this message. It will not be resent. If a task ID was confirmed, refresh to check progress; otherwise check with the agent before starting another task.'**
  String get a2aUncertain;

  /// No description provided for @a2aStorageError.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be saved or removed. Check device storage and retry the local operation. A message without a saved delivery marker is not sent.'**
  String get a2aStorageError;

  /// No description provided for @a2aScopeError.
  ///
  /// In en, this message translates to:
  /// **'This agent, credential or saved task changed. Close this view and reopen the agent to continue.'**
  String get a2aScopeError;

  /// No description provided for @a2aCancelUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Cancellation is not confirmed. The agent still reports an active task; refresh to check again.'**
  String get a2aCancelUnconfirmed;

  /// No description provided for @a2aAuthRequiredDetail.
  ///
  /// In en, this message translates to:
  /// **'This agent requested an additional authentication flow, which this client does not support. No automatic login or task continuation will occur.'**
  String get a2aAuthRequiredDetail;

  /// No description provided for @a2aUnknownDetail.
  ///
  /// In en, this message translates to:
  /// **'This task state is not supported. You can refresh or forget the local record; sending and cancellation remain unavailable.'**
  String get a2aUnknownDetail;

  /// No description provided for @fileTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get fileTable;

  /// No description provided for @fileSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get fileSource;

  /// No description provided for @fileSourceExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Up to the first 200,000 characters are displayed. Copy and Save keep the original content.'**
  String get fileSourceExcerpt;

  /// No description provided for @filePreviewPartialSource.
  ///
  /// In en, this message translates to:
  /// **'Only part of this file is shown. Copy and Save keep the original content.'**
  String get filePreviewPartialSource;

  /// No description provided for @fileLineOutsidePreview.
  ///
  /// In en, this message translates to:
  /// **'Line {line} is outside this preview. Save the original to read that location.'**
  String fileLineOutsidePreview(int line);

  /// No description provided for @fileTableMalformed.
  ///
  /// In en, this message translates to:
  /// **'This file has incomplete or inconsistent quoting. Read its source instead.'**
  String get fileTableMalformed;

  /// No description provided for @fileTableTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Table preview supports files up to 256 KB. Read the source or save the original file.'**
  String get fileTableTooLarge;

  /// No description provided for @fileTableTooWide.
  ///
  /// In en, this message translates to:
  /// **'This file has more than 32 columns. Read the source or save the original file.'**
  String get fileTableTooWide;

  /// No description provided for @fileTableFieldTooLong.
  ///
  /// In en, this message translates to:
  /// **'A cell exceeds 4,096 characters. Read the source or save the original file.'**
  String get fileTableFieldTooLong;

  /// No description provided for @fileTableMoreRows.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 200 rows. More data remains in the original file.'**
  String get fileTableMoreRows;

  /// No description provided for @fileTableRows.
  ///
  /// In en, this message translates to:
  /// **'{rows} rows shown · {columns} columns'**
  String fileTableRows(int rows, int columns);

  /// No description provided for @fileTableColumn.
  ///
  /// In en, this message translates to:
  /// **'Column {number}'**
  String fileTableColumn(int number);

  /// No description provided for @fileTableEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file has no rows.'**
  String get fileTableEmpty;

  /// No description provided for @fileCopied.
  ///
  /// In en, this message translates to:
  /// **'File contents copied'**
  String get fileCopied;

  /// No description provided for @fileCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy file contents. Try again.'**
  String get fileCopyFailed;

  /// No description provided for @fileImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get fileImage;

  /// No description provided for @fileSvgUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This SVG cannot be shown as a local static image. Read its source or save the original file. External resources, animation and complex SVG features are not supported.'**
  String get fileSvgUnsupported;

  /// No description provided for @filePdfEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This PDF requires a password or uses unsupported protection. Save the original to open it in a PDF app.'**
  String get filePdfEncrypted;

  /// No description provided for @filePdfLimit.
  ///
  /// In en, this message translates to:
  /// **'PDF preview supports files up to 10 MB and the first 200 pages. Save the original to read the full document.'**
  String get filePdfLimit;

  /// No description provided for @filePdfUnavailable.
  ///
  /// In en, this message translates to:
  /// **'PDF viewing is available on Android 10 or newer. You can still save the original file.'**
  String get filePdfUnavailable;

  /// No description provided for @filePdfCancelled.
  ///
  /// In en, this message translates to:
  /// **'PDF loading cancelled. Retry when you are ready.'**
  String get filePdfCancelled;

  /// No description provided for @filePdfFailed.
  ///
  /// In en, this message translates to:
  /// **'This PDF page could not be displayed. Retry or save the original file.'**
  String get filePdfFailed;

  /// No description provided for @filePdfPageLimit.
  ///
  /// In en, this message translates to:
  /// **'Only the first 200 pages can be previewed. Save the original to read the full document.'**
  String get filePdfPageLimit;

  /// No description provided for @filePdfPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String filePdfPage(int page, int count);

  /// No description provided for @filePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get filePrevious;

  /// No description provided for @fileNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get fileNext;

  /// No description provided for @fileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get fileCancel;

  /// No description provided for @agentAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Codex account'**
  String get agentAccountTitle;

  /// No description provided for @agentAccountScopeLost.
  ///
  /// In en, this message translates to:
  /// **'This server changed. Return to Servers and open the account for the connected server.'**
  String get agentAccountScopeLost;

  /// No description provided for @agentAccountRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh account'**
  String get agentAccountRefresh;

  /// No description provided for @agentAccountLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking the host account'**
  String get agentAccountLoading;

  /// No description provided for @agentAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account panel unavailable'**
  String get agentAccountUnavailable;

  /// No description provided for @agentAccountReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the account'**
  String get agentAccountReadFailed;

  /// No description provided for @agentAccountDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted'**
  String get agentAccountDisconnected;

  /// No description provided for @agentAccountConnected.
  ///
  /// In en, this message translates to:
  /// **'Signed in on the host'**
  String get agentAccountConnected;

  /// No description provided for @agentAccountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Ready to sign in'**
  String get agentAccountSignedOut;

  /// No description provided for @agentAccountInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sign-in in progress'**
  String get agentAccountInProgress;

  /// No description provided for @agentAccountNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Sign-in needs attention'**
  String get agentAccountNeedsAttention;

  /// No description provided for @agentAccountNoAuth.
  ///
  /// In en, this message translates to:
  /// **'Host does not require sign-in'**
  String get agentAccountNoAuth;

  /// No description provided for @agentAccountApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get agentAccountApiKey;

  /// No description provided for @agentAccountHostAuth.
  ///
  /// In en, this message translates to:
  /// **'Host authentication'**
  String get agentAccountHostAuth;

  /// No description provided for @agentAccountPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan: {plan}'**
  String agentAccountPlan(String plan);

  /// No description provided for @agentAccountHostNote.
  ///
  /// In en, this message translates to:
  /// **'The official Codex runtime keeps your provider credentials. Account changes apply to this host, including other saved servers connected to it.'**
  String get agentAccountHostNote;

  /// No description provided for @agentAccountUnsupportedDetail.
  ///
  /// In en, this message translates to:
  /// **'This panel is verified with Codex 0.153.4. The connected runtime may not support these account methods.'**
  String get agentAccountUnsupportedDetail;

  /// No description provided for @agentAccountReconnectDetail.
  ///
  /// In en, this message translates to:
  /// **'Account data and the sign-in code were cleared. Reconnect to refresh. Sign-in will not restart automatically.'**
  String get agentAccountReconnectDetail;

  /// No description provided for @agentAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with ChatGPT'**
  String get agentAccountSignIn;

  /// No description provided for @agentAccountSignInNote.
  ///
  /// In en, this message translates to:
  /// **'Start an official device-code sign-in on this host. Complete it in your browser; the app never receives your provider tokens.'**
  String get agentAccountSignInNote;

  /// No description provided for @agentAccountLimits.
  ///
  /// In en, this message translates to:
  /// **'Rate limits'**
  String get agentAccountLimits;

  /// No description provided for @agentAccountLimitsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rate limits are unavailable for this account or host.'**
  String get agentAccountLimitsUnavailable;

  /// No description provided for @agentAccountUsage.
  ///
  /// In en, this message translates to:
  /// **'Token usage'**
  String get agentAccountUsage;

  /// No description provided for @agentAccountUsageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Token usage is unavailable for this account or host.'**
  String get agentAccountUsageUnavailable;

  /// No description provided for @agentAccountLifetimeTokens.
  ///
  /// In en, this message translates to:
  /// **'Lifetime tokens'**
  String get agentAccountLifetimeTokens;

  /// No description provided for @agentAccountPeakTokens.
  ///
  /// In en, this message translates to:
  /// **'Peak daily tokens'**
  String get agentAccountPeakTokens;

  /// No description provided for @agentAccountUsageNote.
  ///
  /// In en, this message translates to:
  /// **'Values are reported by the host. Missing values are unknown, not zero. Token counts are not a bill or remaining message allowance.'**
  String get agentAccountUsageNote;

  /// No description provided for @agentAccountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last checked {time}'**
  String agentAccountUpdated(String time);

  /// No description provided for @agentAccountStarting.
  ///
  /// In en, this message translates to:
  /// **'Requesting a sign-in code'**
  String get agentAccountStarting;

  /// No description provided for @agentAccountWaiting.
  ///
  /// In en, this message translates to:
  /// **'Finish sign-in in your browser'**
  String get agentAccountWaiting;

  /// No description provided for @agentAccountCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling sign-in'**
  String get agentAccountCancelling;

  /// No description provided for @agentAccountCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled'**
  String get agentAccountCancelled;

  /// No description provided for @agentAccountLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not complete. Check the host and try again.'**
  String get agentAccountLoginFailed;

  /// No description provided for @agentAccountLoginUncertain.
  ///
  /// In en, this message translates to:
  /// **'The host could not confirm sign-in or cancellation. It may still be waiting. Check the official host runtime before starting again.'**
  String get agentAccountLoginUncertain;

  /// No description provided for @agentAccountLoginCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sign-in completed. Checking the account.'**
  String get agentAccountLoginCompleted;

  /// No description provided for @agentAccountCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter this one-time code on the official sign-in page. Keep it private.'**
  String get agentAccountCodeHint;

  /// No description provided for @agentAccountOpenSignIn.
  ///
  /// In en, this message translates to:
  /// **'Open official sign-in'**
  String get agentAccountOpenSignIn;

  /// No description provided for @agentAccountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel sign-in'**
  String get agentAccountCancel;

  /// No description provided for @agentAccountAllowance.
  ///
  /// In en, this message translates to:
  /// **'Reported allowance'**
  String get agentAccountAllowance;

  /// No description provided for @agentAccountPercentUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String agentAccountPercentUsed(int percent);

  /// No description provided for @agentAccountWindowUnknown.
  ///
  /// In en, this message translates to:
  /// **'Window duration unavailable'**
  String get agentAccountWindowUnknown;

  /// No description provided for @agentAccountWindowMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}-minute window'**
  String agentAccountWindowMinutes(int minutes);

  /// No description provided for @agentAccountWindowHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}-hour window'**
  String agentAccountWindowHours(int hours);

  /// No description provided for @agentAccountWindowDays.
  ///
  /// In en, this message translates to:
  /// **'{days}-day window'**
  String agentAccountWindowDays(int days);

  /// No description provided for @agentAccountResetUnknown.
  ///
  /// In en, this message translates to:
  /// **'Reset time unavailable'**
  String get agentAccountResetUnknown;

  /// No description provided for @agentAccountReset.
  ///
  /// In en, this message translates to:
  /// **'Resets {time}'**
  String agentAccountReset(String time);

  /// No description provided for @projectFolderChooserTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a project folder'**
  String get projectFolderChooserTitle;

  /// No description provided for @projectFolderChooserMessage.
  ///
  /// In en, this message translates to:
  /// **'OpenCode Mobile does not work in the server’s home folder. Create a new folder or open a project folder to start conversations.'**
  String get projectFolderChooserMessage;

  /// No description provided for @projectFolderCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a new folder'**
  String get projectFolderCreate;

  /// No description provided for @projectFolderOpen.
  ///
  /// In en, this message translates to:
  /// **'Open a project folder'**
  String get projectFolderOpen;

  /// No description provided for @projectFolderBrowse.
  ///
  /// In en, this message translates to:
  /// **'Choose from opened projects'**
  String get projectFolderBrowse;

  /// No description provided for @projectFolderNoCreateHint.
  ///
  /// In en, this message translates to:
  /// **'This server cannot create folders from the app. Create the folder on that machine, then open it here by its path.'**
  String get projectFolderNoCreateHint;

  /// No description provided for @projectFolderCreateMessage.
  ///
  /// In en, this message translates to:
  /// **'The folder is created in {directory} on this device and opened as the project.'**
  String projectFolderCreateMessage(String directory);

  /// No description provided for @projectFolderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get projectFolderNameLabel;

  /// No description provided for @projectFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'my-app'**
  String get projectFolderNameHint;

  /// No description provided for @projectFolderCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get projectFolderCreateAction;

  /// No description provided for @projectFolderCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get projectFolderCancel;

  /// No description provided for @projectFolderOpenMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the full path of a folder on the server. The home folder itself cannot be used; choose a project inside it.'**
  String get projectFolderOpenMessage;

  /// No description provided for @projectFolderPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder path'**
  String get projectFolderPathLabel;

  /// No description provided for @projectFolderPathHint.
  ///
  /// In en, this message translates to:
  /// **'{directory}/my-app'**
  String projectFolderPathHint(String directory);

  /// No description provided for @projectFolderOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get projectFolderOpenAction;

  /// No description provided for @projectFolderCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In {directory} on this device'**
  String projectFolderCreateSubtitle(String directory);

  /// No description provided for @projectFolderOpenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the full path of a folder on the server'**
  String get projectFolderOpenSubtitle;

  /// No description provided for @globalSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'All conversations'**
  String get globalSessionsTitle;

  /// No description provided for @globalSessionsSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search conversation titles'**
  String get globalSessionsSearchLabel;

  /// No description provided for @globalSessionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Across every project on this server'**
  String get globalSessionsSearchHint;

  /// No description provided for @globalSessionsIncludeArchived.
  ///
  /// In en, this message translates to:
  /// **'Include archived'**
  String get globalSessionsIncludeArchived;

  /// No description provided for @globalSessionsArchivedShort.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get globalSessionsArchivedShort;

  /// No description provided for @globalSessionsAllFolders.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get globalSessionsAllFolders;

  /// No description provided for @globalSessionsUnknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown project'**
  String get globalSessionsUnknownLocation;

  /// No description provided for @globalSessionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} conversations in {folders} projects'**
  String globalSessionsSummary(String count, int folders);

  /// No description provided for @globalSessionsSummaryOneFolder.
  ///
  /// In en, this message translates to:
  /// **'{count} conversations in one project'**
  String globalSessionsSummaryOneFolder(String count);

  /// No description provided for @globalSessionsFilteredSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} conversations shown'**
  String globalSessionsFilteredSummary(int count, String total);

  /// No description provided for @globalSessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get globalSessionsEmptyTitle;

  /// No description provided for @globalSessionsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Conversations from every project on this server will appear here.'**
  String get globalSessionsEmptyMessage;

  /// No description provided for @globalSessionsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations'**
  String get globalSessionsNoMatchTitle;

  /// No description provided for @globalSessionsNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter title search or include archived conversations.'**
  String get globalSessionsNoMatchMessage;

  /// No description provided for @globalSessionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get globalSessionsRefresh;

  /// No description provided for @globalSessionsLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more conversations'**
  String get globalSessionsLoadMoreFailed;

  /// No description provided for @globalSessionsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get globalSessionsOpen;

  /// No description provided for @globalSessionsContinueHere.
  ///
  /// In en, this message translates to:
  /// **'Continue here'**
  String get globalSessionsContinueHere;

  /// No description provided for @globalSessionsActions.
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get globalSessionsActions;

  /// No description provided for @globalSessionsWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get globalSessionsWorking;

  /// No description provided for @globalSessionsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get globalSessionsUntitled;

  /// No description provided for @workspaceNewSession.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get workspaceNewSession;

  /// No description provided for @workspaceIsolatedTask.
  ///
  /// In en, this message translates to:
  /// **'Isolated task'**
  String get workspaceIsolatedTask;

  /// No description provided for @workspaceAllSessions.
  ///
  /// In en, this message translates to:
  /// **'All conversations'**
  String get workspaceAllSessions;

  /// No description provided for @workspaceDismissNotice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get workspaceDismissNotice;

  /// No description provided for @workspaceManageProject.
  ///
  /// In en, this message translates to:
  /// **'Manage project'**
  String get workspaceManageProject;

  /// No description provided for @workspaceManageProjectHint.
  ///
  /// In en, this message translates to:
  /// **'Switch project, worktrees, and project health'**
  String get workspaceManageProjectHint;

  /// No description provided for @workspaceManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get workspaceManage;

  /// No description provided for @reviewCopiedFile.
  ///
  /// In en, this message translates to:
  /// **'Updated file copied'**
  String get reviewCopiedFile;

  /// No description provided for @reviewCopiedPatch.
  ///
  /// In en, this message translates to:
  /// **'Patch copied'**
  String get reviewCopiedPatch;

  /// No description provided for @reviewCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy. Try again.'**
  String get reviewCopyFailed;

  /// No description provided for @reviewCopyFile.
  ///
  /// In en, this message translates to:
  /// **'Copy updated file'**
  String get reviewCopyFile;

  /// No description provided for @reviewCopyPatch.
  ///
  /// In en, this message translates to:
  /// **'Copy patch'**
  String get reviewCopyPatch;

  /// No description provided for @reviewNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get reviewNoChanges;

  /// No description provided for @reviewEmptyDiff.
  ///
  /// In en, this message translates to:
  /// **'No diff content'**
  String get reviewEmptyDiff;

  /// No description provided for @reviewHideContext.
  ///
  /// In en, this message translates to:
  /// **'Hide revealed context'**
  String get reviewHideContext;

  /// No description provided for @reviewAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get reviewAdded;

  /// No description provided for @reviewRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get reviewRemoved;

  /// No description provided for @reviewUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get reviewUnchanged;

  /// No description provided for @reviewPatchNote.
  ///
  /// In en, this message translates to:
  /// **'Patch note'**
  String get reviewPatchNote;

  /// No description provided for @reviewShowNext.
  ///
  /// In en, this message translates to:
  /// **'Show next {count} lines'**
  String reviewShowNext(int count);

  /// No description provided for @reviewShowPrevious.
  ///
  /// In en, this message translates to:
  /// **'Show {count} previous lines ({remaining} hidden)'**
  String reviewShowPrevious(int count, int remaining);

  /// No description provided for @reviewMissingContext.
  ///
  /// In en, this message translates to:
  /// **'{count} unchanged lines not included in patch'**
  String reviewMissingContext(int count);

  /// No description provided for @reviewCounts.
  ///
  /// In en, this message translates to:
  /// **'{added} added, {removed} removed'**
  String reviewCounts(int added, int removed);

  /// No description provided for @reviewLineDescription.
  ///
  /// In en, this message translates to:
  /// **'{kind}, line {number}: {text}'**
  String reviewLineDescription(String kind, int number, String text);

  /// No description provided for @reviewNoteDescription.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {text}'**
  String reviewNoteDescription(String kind, String text);

  /// More destination summary showing the model used by new chats, not an existing session.
  ///
  /// In en, this message translates to:
  /// **'New conversations: {model}'**
  String settingsDiscoveryNewChatsModel(String model);

  /// No description provided for @onboardingValueTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your work moving.'**
  String get onboardingValueTitle;

  /// No description provided for @onboardingValueBody.
  ///
  /// In en, this message translates to:
  /// **'Ask your coding agent for a change, review the result, and pick up where you left off.'**
  String get onboardingValueBody;

  /// No description provided for @onboardingConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server'**
  String get onboardingConnect;

  /// No description provided for @onboardingDemoNote.
  ///
  /// In en, this message translates to:
  /// **'A simulated conversation. No server needed.'**
  String get onboardingDemoNote;

  /// No description provided for @onboardingMoreSetup.
  ///
  /// In en, this message translates to:
  /// **'More setup options'**
  String get onboardingMoreSetup;

  /// No description provided for @onboardingPrivateNetwork.
  ///
  /// In en, this message translates to:
  /// **'Reach a server over your private network'**
  String get onboardingPrivateNetwork;

  /// No description provided for @onboardingRunOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Run OpenCode here with Termux'**
  String get onboardingRunOnPhone;

  /// No description provided for @onboardingTermuxNote.
  ///
  /// In en, this message translates to:
  /// **'Guided Termux setup'**
  String get onboardingTermuxNote;

  /// No description provided for @onboardingSetupGuide.
  ///
  /// In en, this message translates to:
  /// **'Setup guide'**
  String get onboardingSetupGuide;

  /// No description provided for @onboardingSaveConnect.
  ///
  /// In en, this message translates to:
  /// **'Save & connect'**
  String get onboardingSaveConnect;

  /// No description provided for @onboardingSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get onboardingSaveChanges;

  /// No description provided for @onboardingTermuxSetup.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get onboardingTermuxSetup;

  /// No description provided for @activityClearHere.
  ///
  /// In en, this message translates to:
  /// **'All clear here'**
  String get activityClearHere;

  /// No description provided for @activityStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Status incomplete'**
  String get activityStatusIncomplete;

  /// No description provided for @activityCheckedLocationsClear.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you in the checked projects.'**
  String get activityCheckedLocationsClear;

  /// No description provided for @activityUnknownStatusDetail.
  ///
  /// In en, this message translates to:
  /// **'No requests loaded. Some server activity is still unknown.'**
  String get activityUnknownStatusDetail;

  /// No description provided for @activityCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get activityCheckAgain;

  /// No description provided for @activitySavedServers.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get activitySavedServers;

  /// No description provided for @activitySelectedLocationsOnly.
  ///
  /// In en, this message translates to:
  /// **'Last selected projects only'**
  String get activitySelectedLocationsOnly;

  /// No description provided for @activityBackgroundUpdates.
  ///
  /// In en, this message translates to:
  /// **'Background updates'**
  String get activityBackgroundUpdates;

  /// No description provided for @activityBackgroundOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Off · choose when to stay connected'**
  String get activityBackgroundOffDetail;

  /// No description provided for @activityPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String activityPendingCount(int count);

  /// No description provided for @activityUnknownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unknown'**
  String activityUnknownCount(int count);

  /// No description provided for @demoTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Try a small change'**
  String get demoTaskTitle;

  /// No description provided for @demoTaskInstruction.
  ///
  /// In en, this message translates to:
  /// **'Send the sample prompt below, then review the proposed edit.'**
  String get demoTaskInstruction;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewTitle;

  /// No description provided for @modelChoiceProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers not loaded'**
  String get modelChoiceProvidersTitle;

  /// No description provided for @modelChoiceProvidersSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 signed-in provider not loaded. View details} other{{count} signed-in providers not loaded. View details}}'**
  String modelChoiceProvidersSummary(int count);

  /// No description provided for @modelChoiceReloadProviders.
  ///
  /// In en, this message translates to:
  /// **'Reload providers'**
  String get modelChoiceReloadProviders;

  /// No description provided for @modelChoiceStagedAgentHint.
  ///
  /// In en, this message translates to:
  /// **'Applied with your model choice'**
  String get modelChoiceStagedAgentHint;

  /// No description provided for @modelChoiceAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an agent'**
  String get modelChoiceAgentTitle;

  /// No description provided for @modelChoiceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get modelChoiceDone;

  /// No description provided for @modelChoicePartialSaveError.
  ///
  /// In en, this message translates to:
  /// **'Model saved. Agent choice was not confirmed. Try again.'**
  String get modelChoicePartialSaveError;

  /// No description provided for @modelChoiceModelSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the model choice. Check your selection and try again.'**
  String get modelChoiceModelSaveError;

  /// No description provided for @workIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get workIdle;

  /// No description provided for @workStartedInBackground.
  ///
  /// In en, this message translates to:
  /// **'Started in background'**
  String get workStartedInBackground;

  /// No description provided for @workRunInBackground.
  ///
  /// In en, this message translates to:
  /// **'Run in background'**
  String get workRunInBackground;

  /// No description provided for @workBackgroundPending.
  ///
  /// In en, this message translates to:
  /// **'Requesting background work…'**
  String get workBackgroundPending;

  /// No description provided for @workBackgroundRequested.
  ///
  /// In en, this message translates to:
  /// **'Background work requested. Status will update when the server reports it.'**
  String get workBackgroundRequested;

  /// No description provided for @workBackgroundUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This server has not confirmed support for moving work to the background.'**
  String get workBackgroundUnavailable;

  /// No description provided for @workBackgroundEligible.
  ///
  /// In en, this message translates to:
  /// **'Run in background is available while a supported agent task or command is blocking this conversation.'**
  String get workBackgroundEligible;

  /// No description provided for @workBackgroundAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Ask your agent to delegate work in the background. Results return to this conversation automatically.'**
  String get workBackgroundAutomatic;

  /// Opens the existing-server editor for someone looking for OpenCode 2; does not force the protocol.
  ///
  /// In en, this message translates to:
  /// **'Connect OpenCode 2'**
  String get oc2DiscoveryConnect;

  /// No description provided for @oc2DiscoveryEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenCode 2'**
  String get oc2DiscoveryEditorTitle;

  /// No description provided for @oc2DiscoveryExisting.
  ///
  /// In en, this message translates to:
  /// **'Use a server that is already running.'**
  String get oc2DiscoveryExisting;

  /// No description provided for @oc2DiscoveryTypes.
  ///
  /// In en, this message translates to:
  /// **'OpenCode 1 or 2'**
  String get oc2DiscoveryTypes;

  /// No description provided for @oc2DiscoveryAutodetect.
  ///
  /// In en, this message translates to:
  /// **'Detects OpenCode 1 or 2 automatically.'**
  String get oc2DiscoveryAutodetect;

  /// No description provided for @oc2DiscoveryPhone.
  ///
  /// In en, this message translates to:
  /// **'Set up OpenCode 1 or 2 here with Termux.'**
  String get oc2DiscoveryPhone;

  /// No description provided for @setupSwitchUse.
  ///
  /// In en, this message translates to:
  /// **'Try {runtime}'**
  String setupSwitchUse(String runtime);

  /// No description provided for @setupSwitchConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to {runtime}?'**
  String setupSwitchConfirmTitle(String runtime);

  /// No description provided for @setupSwitchConfirmDetail.
  ///
  /// In en, this message translates to:
  /// **'Stops this phone’s server and running tasks. Conversations, provider settings and credentials stay separate; project files and configuration are shared. You can switch back.'**
  String get setupSwitchConfirmDetail;

  /// No description provided for @setupSwitchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch version'**
  String get setupSwitchConfirm;

  /// No description provided for @setupSwitchInstalled.
  ///
  /// In en, this message translates to:
  /// **'On this phone: {runtime}'**
  String setupSwitchInstalled(String runtime);

  /// No description provided for @setupSwitchPending.
  ///
  /// In en, this message translates to:
  /// **'The runtime switch has not finished. Retry the selected runtime or return to the previous one. Your saved runtime data is retained.'**
  String get setupSwitchPending;

  /// No description provided for @setupSwitchReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to {runtime}'**
  String setupSwitchReturn(String runtime);

  /// No description provided for @setupSwitchRetry.
  ///
  /// In en, this message translates to:
  /// **'Try {runtime} again'**
  String setupSwitchRetry(String runtime);

  /// No description provided for @setupSwitchInProgressHint.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen and return to check progress.'**
  String get setupSwitchInProgressHint;

  /// No description provided for @setupSwitchPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the runtime switch…'**
  String get setupSwitchPreparing;

  /// No description provided for @setupSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish switching runtimes. Check the setup output, then retry or return to the previous runtime.'**
  String get setupSwitchFailed;

  /// No description provided for @setupSwitchConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to {runtime}'**
  String setupSwitchConnect(String runtime);

  /// No description provided for @setupSwitchLegacyTwo.
  ///
  /// In en, this message translates to:
  /// **'This OpenCode 2 installation keeps its existing data. Switching it to OpenCode 1 is not available.'**
  String get setupSwitchLegacyTwo;

  /// No description provided for @setupSwitchProfileName.
  ///
  /// In en, this message translates to:
  /// **'This phone · {runtime}'**
  String setupSwitchProfileName(String runtime);

  /// No description provided for @setupSwitchReady.
  ///
  /// In en, this message translates to:
  /// **'The local runtime is ready. Your current remote connection is unchanged.'**
  String get setupSwitchReady;

  /// No description provided for @setupSwitchMissingCredential.
  ///
  /// In en, this message translates to:
  /// **'The saved credential for the previous runtime is unavailable. Its data is retained; restore the saved server before returning.'**
  String get setupSwitchMissingCredential;

  /// No description provided for @setupSwitchOwnDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect an existing OpenCode 1 or OpenCode 2 server by address.'**
  String get setupSwitchOwnDescription;

  /// No description provided for @setupSwitchProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Switching to {runtime}'**
  String setupSwitchProgressTitle(String runtime);

  /// No description provided for @setupSwitchDataNotice.
  ///
  /// In en, this message translates to:
  /// **'Each version keeps its own conversations and provider settings. Project files and project configuration are shared.'**
  String get setupSwitchDataNotice;

  /// No description provided for @setupSwitchHelp.
  ///
  /// In en, this message translates to:
  /// **'Setup help'**
  String get setupSwitchHelp;

  /// No description provided for @setupSwitchReadyToConnect.
  ///
  /// In en, this message translates to:
  /// **'Ready to connect'**
  String get setupSwitchReadyToConnect;

  /// No description provided for @setupSwitchStopped.
  ///
  /// In en, this message translates to:
  /// **'Ready to start'**
  String get setupSwitchStopped;

  /// No description provided for @setupSwitchAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get setupSwitchAttention;

  /// No description provided for @setupSwitchLocalRuntime.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get setupSwitchLocalRuntime;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Tried {attempts} times. Retrying will not start a server that is not running.'**
  String e7ConnectionFailure1(int attempts);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Connection token required'**
  String get e7ConnectionFailure2;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'This Codex server needs a connection token before the app can connect.'**
  String get e7ConnectionFailure3;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Open server settings and enter the Codex connection token.'**
  String get e7ConnectionFailure4;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Connection token rejected'**
  String get e7ConnectionFailure5;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The Codex server answered, but it did not accept the saved connection token.'**
  String get e7ConnectionFailure6;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Open server settings and enter a current Codex connection token.'**
  String get e7ConnectionFailure7;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Codex listener unavailable'**
  String get e7ConnectionFailure8;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Codex endpoint unreachable'**
  String get e7ConnectionFailure9;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'{hostLabel}:{port} is a local Codex listener, but nothing answered.'**
  String e7ConnectionFailure10(String hostLabel, int port);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing answered at the remote Codex endpoint {hostLabel}:{port}.'**
  String e7ConnectionFailure11(String hostLabel, int port);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Start the Codex listener on this device.'**
  String get e7ConnectionFailure12;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'If it is behind a tunnel, keep the tunnel running and verify its local endpoint.'**
  String get e7ConnectionFailure13;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Use the Codex wss:// endpoint or an active secure tunnel.'**
  String get e7ConnectionFailure14;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Check that the remote Codex listener is reachable from this device.'**
  String get e7ConnectionFailure15;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Password rejected'**
  String get e7ConnectionFailure16;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The server answered, but it did not accept the saved password. This happens when the server was restarted with a new password.'**
  String get e7ConnectionFailure17;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Run opencode2 pair on the computer and paste the new code.'**
  String get e7ConnectionFailure18;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'If you set OPENCODE_SERVER_PASSWORD by hand, copy it again.'**
  String get e7ConnectionFailure19;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Certificate not trusted'**
  String get e7ConnectionFailure20;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The server is there, but this device does not trust its HTTPS certificate, so the app refused to send the password.'**
  String get e7ConnectionFailure21;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Use a certificate from a trusted authority, or a Tailscale Serve address.'**
  String get e7ConnectionFailure22;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'For a self-signed certificate, install it on this device first.'**
  String get e7ConnectionFailure23;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing is listening on this device'**
  String get e7ConnectionFailure24;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'{hostLabel}:{port} means the server should be running on this device, or reached through a tunnel that ends here. Neither answered.'**
  String e7ConnectionFailure25(String hostLabel, int port);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Running OpenCode in Termux? Open Termux and check that the server is still running.'**
  String get e7ConnectionFailure26;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Using adb reverse or an SSH forward? Check that the tunnel is still connected, then try again.'**
  String get e7ConnectionFailure27;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Connecting to another computer instead? Change the server to its HTTPS address or pair again.'**
  String get e7ConnectionFailure28;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The server did not answer in time'**
  String get e7ConnectionFailure29;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Something is at {hostLabel}, but it did not reply. Usually the network in between, not the server.'**
  String e7ConnectionFailure30(String hostLabel);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Are you on the same network or VPN (for example Tailscale) as the computer?'**
  String get e7ConnectionFailure31;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Is a firewall or captive portal blocking port {port}?'**
  String e7ConnectionFailure32(int port);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Server not reachable'**
  String get e7ConnectionFailure33;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing answered at {hostLabel}:{port}. Either the server is not running or this device cannot reach that address.'**
  String e7ConnectionFailure34(String hostLabel, int port);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Is opencode serve still running on the computer?'**
  String get e7ConnectionFailure35;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Are you on the same network or VPN as the computer?'**
  String get e7ConnectionFailure36;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Did the address change? Pair again to pick up the new one.'**
  String get e7ConnectionFailure37;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The server answered with an error'**
  String get e7ConnectionFailure38;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The server is running but reported itself unhealthy. Its own log will say why.'**
  String get e7ConnectionFailure39;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Restart opencode serve and watch its output.'**
  String get e7ConnectionFailure40;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Check that the server version is supported by this app.'**
  String get e7ConnectionFailure41;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Could not connect'**
  String get e7ConnectionFailure42;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'The connection to {hostLabel} failed. Details below.'**
  String e7ConnectionFailure43(String hostLabel);

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Is the agent server running, and is this the right address?'**
  String get e7ConnectionFailure44;

  /// Connection recovery guidance shown in lib/ui/widgets/connection_failure.dart
  ///
  /// In en, this message translates to:
  /// **'Is opencode serve running, and is this the right address?'**
  String get e7ConnectionFailure45;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Run a shell command'**
  String get e7PermissionAction1;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Edit a file'**
  String get e7PermissionAction2;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Read a file'**
  String get e7PermissionAction3;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Access an external directory'**
  String get e7PermissionAction4;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Continue after repeated failures'**
  String get e7PermissionAction5;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get e7PermissionAction6;

  /// Human-readable title for a permission request
  ///
  /// In en, this message translates to:
  /// **'Use {permission}'**
  String e7PermissionAction7(String permission);

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Model Context Protocol. Small add-on servers that give the agent extra tools, like a browser, a database, or a design tool. You connect them once and every conversation can use them.'**
  String get e7GlossaryMcpExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Worktree'**
  String get e7GlossaryWorktreeTerm;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'A separate checkout of the same repository. Use one when you want the agent to try something on its own branch without touching the code you are working in.'**
  String get e7GlossaryWorktreeExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'The company that hosts a model, such as Anthropic, OpenAI or a local runtime. Each one needs its own API key or login.'**
  String get e7GlossaryProviderExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get e7GlossaryContextTerm;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Everything the model can see right now: your messages, files it read, and tool results. It has a size limit. When it fills up, older parts are summarised so the conversation can continue.'**
  String get e7GlossaryContextExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get e7GlossaryAgentTerm;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'A named set of instructions and permissions the model works under. The default one can read and edit code. Others might only plan, or only review.'**
  String get e7GlossaryAgentExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'The model’s working notes before it answers. Useful for seeing why it made a choice. Hidden by default to keep the conversation short.'**
  String get e7GlossaryReasoningExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get e7GlossaryPermissionTerm;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Before the agent runs a command or edits a file outside what it is already allowed, it asks you. Allow once, or always for that pattern.'**
  String get e7GlossaryPermissionExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get e7GlossaryVariantTerm;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'A speed-versus-depth setting for the model, such as how long it may think before answering.'**
  String get e7GlossaryVariantExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get e7GlossaryGotIt;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'{term}. Tap for an explanation.'**
  String e7GlossaryExplain(String term);

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'The connection token was rejected'**
  String get e7BannerTokenRejected;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'The server password changed'**
  String get e7BannerPasswordChanged;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Server password changed — reconnect.'**
  String get e7BannerReconnectPassword;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get e7BannerUpdatePassword;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get e7BannerLost;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get e7BannerRetrying;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get e7BannerDetails;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get e7BannerChangeServer;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Server password changed — reconnect.\n{note}'**
  String e7BannerReconnectPasswordNote(String note);

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to {server}…'**
  String e7BannerReconnectingServer(String server);

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to {server}'**
  String e7BannerReconnectingServerSemantic(String server);

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'What you see stays available while OpenCode is checked. Live updates resume on their own.'**
  String get e7BannerCheckingExplanation;

  /// Localized shared connection or glossary interface
  ///
  /// In en, this message translates to:
  /// **'What you see may be stale until OpenCode is reachable again.'**
  String get e7BannerStaleExplanation;

  /// Shared app interface: Three steps to your first session
  ///
  /// In en, this message translates to:
  /// **'Three steps to your first conversation'**
  String get e7SharedThreeStepsToYourFirstSession;

  /// Shared app interface: OpenCode runs on your computer. This app is the remote. Pairing connects the two with one command — no addresses or passwords to type.
  ///
  /// In en, this message translates to:
  /// **'OpenCode runs on your computer. This app is the remote. Pairing connects the two with one command — no addresses or passwords to type.'**
  String get e7SharedOpenCodeRunsOnYourComputerThisApp;

  /// Shared app interface: On your computer, run one command
  ///
  /// In en, this message translates to:
  /// **'On your computer, run one command'**
  String get e7SharedOnYourComputerRunOneCommand;

  /// Shared app interface: In a terminal on the computer where OpenCode is installed:
  ///
  /// In en, this message translates to:
  /// **'In a terminal on the computer where OpenCode is installed:'**
  String get e7SharedInATerminalOnTheComputerWhere;

  /// Shared app interface: It starts the server and prints a pairing code — and a QR code you can scan.
  ///
  /// In en, this message translates to:
  /// **'It starts the server and prints a pairing code — and a QR code you can scan.'**
  String get e7SharedItStartsTheServerAndPrintsA;

  /// Shared app interface: Scan the QR or paste the code in this app
  ///
  /// In en, this message translates to:
  /// **'Scan the QR or paste the code in this app'**
  String get e7SharedScanTheQROrPasteTheCode;

  /// Shared app interface: Paste the code in this app
  ///
  /// In en, this message translates to:
  /// **'Paste the code in this app'**
  String get e7SharedPasteTheCodeInThisApp;

  /// Shared app interface: Open Servers, tap Scan and point the camera at the QR — or copy the code and tap Paste pairing code. The address, username and password fill in together.
  ///
  /// In en, this message translates to:
  /// **'Open Servers, tap Scan and point the camera at the QR — or copy the code and tap Paste pairing code. The address, username and password fill in together.'**
  String get e7SharedOpenServersTapScanAndPointThe;

  /// Shared app interface: Copy the printed code, open Servers and tap Paste pairing code. The address, username and password fill in together.
  ///
  /// In en, this message translates to:
  /// **'Copy the printed code, open Servers and tap Paste pairing code. The address, username and password fill in together.'**
  String get e7SharedCopyThePrintedCodeOpenServersAnd;

  /// Shared app interface: Start talking
  ///
  /// In en, this message translates to:
  /// **'Start talking'**
  String get e7SharedStartTalking;

  /// Shared app interface: Pick a project and send your first message. The work happens on your computer; this app shows it and lets you steer.
  ///
  /// In en, this message translates to:
  /// **'Pick a project and send your first message. The work happens on your computer; this app shows it and lets you steer.'**
  String get e7SharedPickAProjectAndSendYourFirst;

  /// Shared app interface: Advanced
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get e7SharedAdvanced;

  /// Shared app interface: HTTPS, SSH tunnels, older servers, Termux internals
  ///
  /// In en, this message translates to:
  /// **'HTTPS, SSH tunnels, older servers, Termux internals'**
  String get e7SharedHTTPSSSHTunnelsOlderServersTermuxInternals;

  /// Shared app interface: HTTPS, SSH tunnels, older servers
  ///
  /// In en, this message translates to:
  /// **'HTTPS, SSH tunnels, older servers'**
  String get e7SharedHTTPSSSHTunnelsOlderServers;

  /// Shared app interface: Reach a server over HTTPS or a tunnel
  ///
  /// In en, this message translates to:
  /// **'Reach a server over HTTPS or a tunnel'**
  String get e7SharedReachAServerOverHTTPSOrA;

  /// Shared app interface: Pairing works when the address the server prints is one this device can reach. If it is not, expose the server through an HTTPS reverse proxy or an encrypted tunnel and add the resulting https:// URL by hand. Remote HTTP is intentionally blocked.
  ///
  /// In en, this message translates to:
  /// **'Pairing works when the address the server prints is one this device can reach. If it is not, expose the server through an HTTPS reverse proxy or an encrypted tunnel and add the resulting https:// URL by hand. Remote HTTP is intentionally blocked.'**
  String get e7SharedPairingWorksWhenTheAddressTheServer;

  /// Shared app interface: Older servers without pairing
  ///
  /// In en, this message translates to:
  /// **'Older servers without pairing'**
  String get e7SharedOlderServersWithoutPairing;

  /// Shared app interface: Servers started with `opencode serve` do not print a pairing code. Start them on loopback with a password:
  ///
  /// In en, this message translates to:
  /// **'Servers started with `opencode serve` do not print a pairing code. Start them on loopback with a password:'**
  String get e7SharedServersStartedWithOpencodeServeDoNot;

  /// Shared app interface: Then add the server manually with username opencode and that password.
  ///
  /// In en, this message translates to:
  /// **'Then add the server manually with username opencode and that password.'**
  String get e7SharedThenAddTheServerManuallyWithUsername;

  /// Shared app interface: On-device via Termux (automated)
  ///
  /// In en, this message translates to:
  /// **'On-device via Termux (automated)'**
  String get e7SharedOnDeviceViaTermuxAutomated;

  /// Shared app interface: Use the “On-device (Termux)” card on the Servers screen. The app installs Termux, unlocks the bridge, sets up opencode, starts the server and connects — all guided.
  ///
  /// In en, this message translates to:
  /// **'Use the “On-device (Termux)” card on the Servers screen. The app installs Termux, unlocks the bridge, sets up opencode, starts the server and connects — all guided.'**
  String get e7SharedUseTheOnDeviceTermuxCardOn;

  /// Shared app interface: Only two taps need you personally: downloading the Termux APK and pasting one unlock line inside Termux once — both required by Android’s security model, not by this app.
  ///
  /// In en, this message translates to:
  /// **'Only two taps need you personally: downloading the Termux APK and pasting one unlock line inside Termux once — both required by Android’s security model, not by this app.'**
  String get e7SharedOnlyTwoTapsNeedYouPersonallyDownloading;

  /// Shared app interface: Prefer manual? Inside Termux run:
  ///
  /// In en, this message translates to:
  /// **'Prefer manual? Inside Termux run:'**
  String get e7SharedPreferManualInsideTermuxRun;

  /// Shared app interface: The chroot shares the network stack, so http://127.0.0.1:4096 works from this app. Run `termux-wake-lock` to keep it alive.
  ///
  /// In en, this message translates to:
  /// **'The chroot shares the network stack, so http://127.0.0.1:4096 works from this app. Run `termux-wake-lock` to keep it alive.'**
  String get e7SharedTheChrootSharesTheNetworkStackSo;

  /// Shared app interface: Security notes
  ///
  /// In en, this message translates to:
  /// **'Security notes'**
  String get e7SharedSecurityNotes;

  /// Shared app interface: Always set OPENCODE_SERVER_PASSWORD when binding beyond localhost.
  ///
  /// In en, this message translates to:
  /// **'Always set OPENCODE_SERVER_PASSWORD when binding beyond localhost.'**
  String get e7SharedAlwaysSetOPENCODESERVERPASSWORDWhenBinding;

  /// Shared app interface: Passwords are stored in the Android Keystore on this device only.
  ///
  /// In en, this message translates to:
  /// **'Passwords are stored in the Android Keystore on this device only.'**
  String get e7SharedPasswordsAreStoredInTheAndroidKeystore;

  /// Shared app interface: The server can execute commands on its host — treat access like SSH access.
  ///
  /// In en, this message translates to:
  /// **'The server can execute commands on its host — treat access like SSH access.'**
  String get e7SharedTheServerCanExecuteCommandsOnIts;

  /// Shared app interface: Copied
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get e7SharedCopied;

  /// Shared app interface: OpenCode is reconnecting. Try again.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again.'**
  String get e7SharedOpenCodeIsReconnectingTryAgain;

  /// Shared app interface: Session context
  ///
  /// In en, this message translates to:
  /// **'Conversation context'**
  String get e7SharedSessionContext;

  /// Shared app interface: Refresh context
  ///
  /// In en, this message translates to:
  /// **'Refresh context'**
  String get e7SharedRefreshContext;

  /// Shared app interface: No context usage yet
  ///
  /// In en, this message translates to:
  /// **'No context usage yet'**
  String get e7SharedNoContextUsageYet;

  /// Shared app interface: Send a prompt and wait for an assistant response. OpenCode will then report token usage for this session.
  ///
  /// In en, this message translates to:
  /// **'Send a prompt and wait for an assistant response. OpenCode will then report token usage for this conversation.'**
  String get e7SharedSendAPromptAndWaitForAn;

  /// Shared app interface: Current model request
  ///
  /// In en, this message translates to:
  /// **'Current model request'**
  String get e7SharedCurrentModelRequest;

  /// Shared app interface: Estimated input makeup
  ///
  /// In en, this message translates to:
  /// **'Estimated input makeup'**
  String get e7SharedEstimatedInputMakeup;

  /// Shared app interface: Session totals
  ///
  /// In en, this message translates to:
  /// **'Conversation totals'**
  String get e7SharedSessionTotals;

  /// Shared app interface: Usage comes from the latest completed assistant message. The makeup is an estimate from visible prompt, response, and tool text; Other includes system instructions, tool definitions, and provider overhead.
  ///
  /// In en, this message translates to:
  /// **'Usage comes from the latest completed assistant message. The makeup is an estimate from visible prompt, response, and tool text; Other includes system instructions, tool definitions, and provider overhead.'**
  String get e7SharedUsageComesFromTheLatestCompletedAssistant;

  /// Shared app interface: Model unavailable
  ///
  /// In en, this message translates to:
  /// **'Model unavailable'**
  String get e7SharedModelUnavailable;

  /// Shared app interface: Context limit unavailable
  ///
  /// In en, this message translates to:
  /// **'Context limit unavailable'**
  String get e7SharedContextLimitUnavailable;

  /// Shared app interface: Latest assistant request, including cache activity
  ///
  /// In en, this message translates to:
  /// **'Latest assistant request, including cache activity'**
  String get e7SharedLatestAssistantRequestIncludingCacheActivity;

  /// Shared app interface: Context limit
  ///
  /// In en, this message translates to:
  /// **'Context limit'**
  String get e7SharedContextLimit;

  /// Shared app interface: Unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get e7SharedUnavailable;

  /// Shared app interface: Messages
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get e7SharedMessages;

  /// Shared app interface: User / assistant
  ///
  /// In en, this message translates to:
  /// **'User / assistant'**
  String get e7SharedUserAssistant;

  /// Shared app interface: Accumulated cost · reported by server
  ///
  /// In en, this message translates to:
  /// **'Accumulated cost · reported by server'**
  String get e7SharedAccumulatedCostReportedByServer;

  /// Shared app interface: Accumulated cost
  ///
  /// In en, this message translates to:
  /// **'Accumulated cost'**
  String get e7SharedAccumulatedCost;

  /// Shared app interface: Session tokens · reported by server
  ///
  /// In en, this message translates to:
  /// **'Conversation tokens · reported by server'**
  String get e7SharedSessionTokensReportedByServer;

  /// Shared app interface: User prompts
  ///
  /// In en, this message translates to:
  /// **'User prompts'**
  String get e7SharedUserPrompts;

  /// Shared app interface: Assistant text
  ///
  /// In en, this message translates to:
  /// **'Assistant text'**
  String get e7SharedAssistantText;

  /// Shared app interface: Tool calls and results
  ///
  /// In en, this message translates to:
  /// **'Tool calls and results'**
  String get e7SharedToolCallsAndResults;

  /// Shared app interface: Other context
  ///
  /// In en, this message translates to:
  /// **'Other context'**
  String get e7SharedOtherContext;

  /// Shared app interface: Move
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get e7SharedMove;

  /// Shared app interface: Session location changed. Close and reopen this sheet.
  ///
  /// In en, this message translates to:
  /// **'The conversation’s project changed. Close and reopen this sheet.'**
  String get e7SharedSessionLocationChangedCloseAndReopenThis;

  /// Shared app interface: OpenCode is reconnecting.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting.'**
  String get e7SharedOpenCodeIsReconnecting;

  /// Shared app interface: The session project is not available on this server.
  ///
  /// In en, this message translates to:
  /// **'The conversation project is not available on this server.'**
  String get e7SharedTheSessionProjectIsNotAvailableOn;

  /// Shared app interface: Local project
  ///
  /// In en, this message translates to:
  /// **'Local project'**
  String get e7SharedLocalProject;

  /// Shared app interface: The app could not inspect working changes. For safety, this continues without transferring changes.
  ///
  /// In en, this message translates to:
  /// **'The app could not inspect working changes. For safety, this continues without transferring changes.'**
  String get e7SharedTheAppCouldNotInspectWorkingChanges;

  /// Shared app interface: Move with changes
  ///
  /// In en, this message translates to:
  /// **'Move with changes'**
  String get e7SharedMoveWithChanges;

  /// Shared app interface: Copy changes and move
  ///
  /// In en, this message translates to:
  /// **'Copy changes and move'**
  String get e7SharedCopyChangesAndMove;

  /// Shared app interface: Move session
  ///
  /// In en, this message translates to:
  /// **'Move conversation'**
  String get e7SharedMoveSession;

  /// Shared app interface: Choose another directory in this project.
  ///
  /// In en, this message translates to:
  /// **'Choose another directory in this project.'**
  String get e7SharedChooseAnotherDirectoryInThisProject;

  /// Shared app interface: Choose a connected workspace, or return to the local project.
  ///
  /// In en, this message translates to:
  /// **'Choose a connected cloud environment, or return to the local project.'**
  String get e7SharedChooseAConnectedWorkspaceOrReturnTo;

  /// Shared app interface: Filter destinations
  ///
  /// In en, this message translates to:
  /// **'Filter destinations'**
  String get e7SharedFilterDestinations;

  /// Shared app interface: No other destinations are available.
  ///
  /// In en, this message translates to:
  /// **'No other destinations are available.'**
  String get e7SharedNoOtherDestinationsAreAvailable;

  /// Shared app interface: No destinations match this filter.
  ///
  /// In en, this message translates to:
  /// **'No destinations match this filter.'**
  String get e7SharedNoDestinationsMatchThisFilter;

  /// Shared app interface: Current
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get e7SharedCurrent;

  /// Shared app interface: Switch organization?
  ///
  /// In en, this message translates to:
  /// **'Switch organization?'**
  String get e7SharedSwitchOrganization;

  /// Shared app interface: Switch
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get e7SharedSwitch;

  /// Shared app interface: Switch organization
  ///
  /// In en, this message translates to:
  /// **'Switch organization'**
  String get e7SharedSwitchOrganization462;

  /// Shared app interface: No switchable OpenCode Console organizations were returned.
  ///
  /// In en, this message translates to:
  /// **'No switchable OpenCode Console organizations were returned.'**
  String get e7SharedNoSwitchableOpenCodeConsoleOrganizationsWereReturned;

  /// Shared app interface: Session location changed. Return and reopen related sessions.
  ///
  /// In en, this message translates to:
  /// **'The conversation’s project changed. Return and reopen related conversations.'**
  String get e7SharedSessionLocationChangedReturnAndReopenRelated;

  /// Shared app interface: Session is no longer related to this session.
  ///
  /// In en, this message translates to:
  /// **'That conversation is no longer related to this one.'**
  String get e7SharedSessionIsNoLongerRelatedToThis;

  /// Shared app interface: Session location changed. Return and try again.
  ///
  /// In en, this message translates to:
  /// **'The conversation’s project changed. Return and try again.'**
  String get e7SharedSessionLocationChangedReturnAndTryAgain;

  /// Shared app interface: Session unavailable or location changed. Return or refresh to try again.
  ///
  /// In en, this message translates to:
  /// **'Conversation unavailable or its project changed. Return or refresh to try again.'**
  String get e7SharedSessionUnavailableOrLocationChangedReturnOr;

  /// Shared app interface: Could not update the pin. Return and try again.
  ///
  /// In en, this message translates to:
  /// **'Could not update the pin. Return and try again.'**
  String get e7SharedCouldNotUpdateThePinReturnAnd;

  /// Shared app interface: Refresh subagent sessions
  ///
  /// In en, this message translates to:
  /// **'Refresh subagent conversations'**
  String get e7SharedRefreshSubagentSessions;

  /// Shared app interface: Parent session
  ///
  /// In en, this message translates to:
  /// **'Parent conversation'**
  String get e7SharedParentSession;

  /// Shared app interface: Subagents
  ///
  /// In en, this message translates to:
  /// **'Subagents'**
  String get e7SharedSubagents;

  /// Shared app interface: No subagent sessions yet
  ///
  /// In en, this message translates to:
  /// **'No subagent conversations yet'**
  String get e7SharedNoSubagentSessionsYet;

  /// Shared app interface: Delegated work will appear here without mixing child sessions into your main chat list.
  ///
  /// In en, this message translates to:
  /// **'Delegated work will appear here without mixing subagent conversations into your main list.'**
  String get e7SharedDelegatedWorkWillAppearHereWithoutMixing;

  /// Shared app interface: OpenCode has not delegated work from this session.
  ///
  /// In en, this message translates to:
  /// **'OpenCode has not delegated work from this conversation.'**
  String get e7SharedOpenCodeHasNotDelegatedWorkFromThis;

  /// Shared app interface: Unpin session
  ///
  /// In en, this message translates to:
  /// **'Unpin conversation'**
  String get e7SharedUnpinSession;

  /// Shared app interface: Pin session
  ///
  /// In en, this message translates to:
  /// **'Pin conversation'**
  String get e7SharedPinSession;

  /// Shared app interface: Link blocked. This app may open only https:// URLs, or confirmed http:// URLs.
  ///
  /// In en, this message translates to:
  /// **'Link blocked. This app may open only https:// URLs, or confirmed http:// URLs.'**
  String get e7SharedLinkBlockedThisAppMayOpenOnly;

  /// Shared app interface: Open insecure HTTP link?
  ///
  /// In en, this message translates to:
  /// **'Open insecure HTTP link?'**
  String get e7SharedOpenInsecureHTTPLink;

  /// Shared app interface: Open external link?
  ///
  /// In en, this message translates to:
  /// **'Open external link?'**
  String get e7SharedOpenExternalLink;

  /// Shared app interface: Host
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get e7SharedHost;

  /// Shared app interface: HTTP is not encrypted. Other devices on the network may read or change what you send and receive.
  ///
  /// In en, this message translates to:
  /// **'HTTP is not encrypted. Other devices on the network may read or change what you send and receive.'**
  String get e7SharedHTTPIsNotEncryptedOtherDevicesOn;

  /// Shared app interface: Open HTTP link
  ///
  /// In en, this message translates to:
  /// **'Open HTTP link'**
  String get e7SharedOpenHTTPLink;

  /// Shared app interface: Open link
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get e7SharedOpenLink;

  /// Shared app interface: No app could open this link.
  ///
  /// In en, this message translates to:
  /// **'No app could open this link.'**
  String get e7SharedNoAppCouldOpenThisLink;

  /// Shared app interface: Required
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get e7SharedRequired;

  /// Shared app interface: Does not match the expected format
  ///
  /// In en, this message translates to:
  /// **'Does not match the expected format'**
  String get e7SharedDoesNotMatchTheExpectedFormat;

  /// Shared app interface: Enter a whole number
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get e7SharedEnterAWholeNumber;

  /// Shared app interface: Enter a number
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get e7SharedEnterANumber;

  /// Shared app interface: Dismiss this request?
  ///
  /// In en, this message translates to:
  /// **'Dismiss this request?'**
  String get e7SharedDismissThisRequest;

  /// Shared app interface: The agent continues without your answers.
  ///
  /// In en, this message translates to:
  /// **'The agent continues without your answers.'**
  String get e7SharedTheAgentContinuesWithoutYourAnswers;

  /// Shared app interface: Asked by an MCP server
  ///
  /// In en, this message translates to:
  /// **'Asked by an MCP server'**
  String get e7SharedAskedByAnMCPServer;

  /// Shared app interface: Asked by the agent in this session
  ///
  /// In en, this message translates to:
  /// **'Asked by the agent in this conversation'**
  String get e7SharedAskedByTheAgentInThisSession;

  /// Shared app interface: Input requested
  ///
  /// In en, this message translates to:
  /// **'Input requested'**
  String get e7SharedInputRequested;

  /// Shared app interface: Other…
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get e7SharedOther;

  /// Shared app interface: Your answer
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get e7SharedYourAnswer;

  /// Shared app interface: Add your own
  ///
  /// In en, this message translates to:
  /// **'Add your own'**
  String get e7SharedAddYourOwn;

  /// Shared app interface: Add answer
  ///
  /// In en, this message translates to:
  /// **'Add answer'**
  String get e7SharedAddAnswer;

  /// Shared app interface: This server sent a link this app will not open.
  ///
  /// In en, this message translates to:
  /// **'This server sent a link this app will not open.'**
  String get e7SharedThisServerSentALinkThisApp;

  /// Shared app interface: Send answers
  ///
  /// In en, this message translates to:
  /// **'Send answers'**
  String get e7SharedSendAnswers;

  /// Shared app interface: Recommended
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get e7SharedRecommended;

  /// Shared journey: lib/ui/screens/guide_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 3'**
  String e7SharedDetail307(int step);

  /// Shared journey: lib/ui/screens/session_context_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{percent} percent context used'**
  String e7SharedDetail381(String percent);

  /// Shared journey: lib/ui/screens/session_context_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} tokens'**
  String e7SharedDetail385(String count, String limit);

  /// Shared journey: lib/ui/screens/session_context_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{count} tokens · limit unavailable'**
  String e7SharedDetail386(String count);

  /// Shared journey: lib/ui/screens/session_context_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not refresh: {error}'**
  String e7SharedDetail409(String error);

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Moved to {destination}'**
  String e7SharedDetail428(String destination);

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Move conversation?'**
  String get e7SharedDetail429;

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 changed file is present.} other {{count} changed files are present.}} Choose whether those working changes should {action, select, move {move} other {be copied}} with the conversation.'**
  String e7SharedDetail430(int count, String action);

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Continue to {destination}?'**
  String e7SharedDetail432(String destination);

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Move only'**
  String get e7SharedDetail435;

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Models and providers will reload using {organization}.'**
  String e7SharedDetail456(String organization);

  /// Shared journey: lib/ui/screens/session_destination_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Switched to {organization}'**
  String e7SharedDetail460(String organization);

  /// Shared journey: lib/ui/screens/session_relations_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String e7SharedDetail514(String error);

  /// Shared journey: lib/ui/screens/session_relations_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 delegated conversation · open any transcript directly.} other {{count} delegated conversations · open any transcript directly.}}'**
  String e7SharedDetail517(int count);

  /// Shared journey: lib/ui/screens/session_relations_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String e7SharedDetail518(int position, int total);

  /// Shared journey: lib/ui/widgets/external_link.dart
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {error}'**
  String e7SharedDetail699(String error);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Must be at least {count} characters'**
  String e7SharedDetail714(int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Must be at most {count} characters'**
  String e7SharedDetail715(int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Must be between {minimum} and {maximum}'**
  String e7SharedDetail721(String minimum, String maximum);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Must be at least {minimum}'**
  String e7SharedDetail722(String minimum);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Must be at most {maximum}'**
  String e7SharedDetail723(String maximum);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Pick at least {count}'**
  String e7SharedDetail725(int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Pick at most {count}'**
  String e7SharedDetail726(int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Pick {minimum}–{maximum}'**
  String e7SharedDetail753(int minimum, int maximum);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Pick at least {count}'**
  String e7SharedDetail754(int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Pick up to {count}'**
  String e7SharedDetail755(int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'{range} · {count} selected'**
  String e7SharedDetail756(String range, int count);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'Opens {host} in your browser'**
  String e7SharedDetail764(String host);

  /// Shared journey: lib/ui/widgets/form_renderer.dart
  ///
  /// In en, this message translates to:
  /// **'This server sent a field type this app does not understand (\"{field}\").'**
  String e7SharedDetail765(String field);

  /// Locale selection or app shell: Language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get e7LocaleUiLanguage;

  /// Locale selection or app shell: English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get e7LocaleUiEnglish;

  /// Locale selection or app shell: Arabic
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get e7LocaleUiArabic;

  /// Locale selection or app shell: System
  ///
  /// In en, this message translates to:
  /// **'Use system language'**
  String get e7LocaleUiSystem;

  /// Locale selection or app shell: Close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get e7LocaleUiClose;

  /// Locale selection or app shell: Description
  ///
  /// In en, this message translates to:
  /// **'Choose the language used throughout the app. Server messages and your text stay as written.'**
  String get e7LocaleUiDescription;

  /// Locale selection or app shell: Saving
  ///
  /// In en, this message translates to:
  /// **'Saving language…'**
  String get e7LocaleUiSaving;

  /// Locale selection or app shell: SaveFailed
  ///
  /// In en, this message translates to:
  /// **'Language could not be saved. Your previous choice is still active. Select a language to try again.'**
  String get e7LocaleUiSaveFailed;

  /// Locale selection or app shell: Starting
  ///
  /// In en, this message translates to:
  /// **'Starting OpenCode…'**
  String get e7LocaleUiStarting;

  /// Locale selection or app shell: StartFailed
  ///
  /// In en, this message translates to:
  /// **'OpenCode could not start'**
  String get e7LocaleUiStartFailed;

  /// Locale selection or app shell: UnknownStartupError
  ///
  /// In en, this message translates to:
  /// **'Unknown startup error'**
  String get e7LocaleUiUnknownStartupError;

  /// Locale selection or app shell: Retry
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get e7LocaleUiRetry;

  /// Locale selection or app shell: NewSession
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get e7LocaleUiNewSession;

  /// Locale selection or app shell: NewSessionHint
  ///
  /// In en, this message translates to:
  /// **'Start a conversation in the active project'**
  String get e7LocaleUiNewSessionHint;

  /// Locale selection or app shell: Workspace
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get e7LocaleUiWorkspace;

  /// Locale selection or app shell: WorkspaceHint
  ///
  /// In en, this message translates to:
  /// **'Recent conversations and the active project'**
  String get e7LocaleUiWorkspaceHint;

  /// Locale selection or app shell: Files
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get e7LocaleUiFiles;

  /// Locale selection or app shell: FilesHint
  ///
  /// In en, this message translates to:
  /// **'Files, changes, terminal and other project tools'**
  String get e7LocaleUiFilesHint;

  /// Locale selection or app shell: Activity
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get e7LocaleUiActivity;

  /// Locale selection or app shell: ActivityHint
  ///
  /// In en, this message translates to:
  /// **'Permissions, questions, and forms'**
  String get e7LocaleUiActivityHint;

  /// Locale selection or app shell: MoreHint
  ///
  /// In en, this message translates to:
  /// **'Models, providers, notifications, settings'**
  String get e7LocaleUiMoreHint;

  /// Locale selection or app shell: Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get e7LocaleUiSettings;

  /// Locale selection or app shell: KeyboardShortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get e7LocaleUiKeyboardShortcuts;

  /// Locale selection or app shell: RefreshSessions
  ///
  /// In en, this message translates to:
  /// **'Refresh conversations'**
  String get e7LocaleUiRefreshSessions;

  /// Locale selection or app shell: Diagnostics
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get e7LocaleUiDiagnostics;

  /// Locale selection or app shell: DiagnosticsHint
  ///
  /// In en, this message translates to:
  /// **'Recent errors and connection detail'**
  String get e7LocaleUiDiagnosticsHint;

  /// App shell command menu or routing: CommandLauncher
  ///
  /// In en, this message translates to:
  /// **'Command launcher'**
  String get e7LocaleUiCommandLauncher;

  /// App shell command menu or routing: FindSurface
  ///
  /// In en, this message translates to:
  /// **'Find in this surface'**
  String get e7LocaleUiFindSurface;

  /// App shell command menu or routing: Destinations
  ///
  /// In en, this message translates to:
  /// **'Work, Inbox, Project, Settings'**
  String get e7LocaleUiDestinations;

  /// App shell command menu or routing: Terminal
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get e7LocaleUiTerminal;

  /// App shell command menu or routing: CloseScreen
  ///
  /// In en, this message translates to:
  /// **'Close this screen'**
  String get e7LocaleUiCloseScreen;

  /// App shell command menu or routing: SendPrompt
  ///
  /// In en, this message translates to:
  /// **'Send the prompt'**
  String get e7LocaleUiSendPrompt;

  /// App shell command menu or routing: CopyTranscript
  ///
  /// In en, this message translates to:
  /// **'Copy the selected transcript text'**
  String get e7LocaleUiCopyTranscript;

  /// App shell command menu or routing: RecentModel
  ///
  /// In en, this message translates to:
  /// **'Next / previous recent model in this conversation'**
  String get e7LocaleUiRecentModel;

  /// App shell command menu or routing: ThisList
  ///
  /// In en, this message translates to:
  /// **'This list'**
  String get e7LocaleUiThisList;

  /// App shell command menu or routing: CloseOverlay
  ///
  /// In en, this message translates to:
  /// **'Close a sheet, dialog, or menu'**
  String get e7LocaleUiCloseOverlay;

  /// App shell command menu or routing: ContextActions
  ///
  /// In en, this message translates to:
  /// **'Message, file, and conversation actions'**
  String get e7LocaleUiContextActions;

  /// App shell command menu or routing: TypeCommand
  ///
  /// In en, this message translates to:
  /// **'Type a command…'**
  String get e7LocaleUiTypeCommand;

  /// App shell command menu or routing: NoCommand
  ///
  /// In en, this message translates to:
  /// **'No matching command'**
  String get e7LocaleUiNoCommand;

  /// App shell command menu or routing: ContextKeys
  ///
  /// In en, this message translates to:
  /// **'Right click / Shift + F10 / Menu'**
  String get e7LocaleUiContextKeys;

  /// App shell command menu or routing: ShareScopeChanged
  ///
  /// In en, this message translates to:
  /// **'Shared conversation scope changed'**
  String get e7LocaleUiShareScopeChanged;

  /// App shell command menu or routing: ConnectionChanged
  ///
  /// In en, this message translates to:
  /// **'The server changed.'**
  String get e7LocaleUiConnectionChanged;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Follow Android'**
  String get e7AppearanceFollowAndroid;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get e7AppearanceFollowSystem;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get e7AppearanceLight;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get e7AppearanceDark;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Match this phone’s current light or dark setting'**
  String get e7AppearanceFollowPhoneDescription;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Match this device’s current light or dark setting'**
  String get e7AppearanceFollowDeviceDescription;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Use the bright editorial theme'**
  String get e7AppearanceLightDescription;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Use the focused low-light theme'**
  String get e7AppearanceDarkDescription;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get e7AppearanceTitle;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Preview first. Your appearance changes only when you apply it.'**
  String get e7AppearancePreviewHint;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Material You colors are not available on this device.'**
  String get e7AppearanceDynamicUnavailable;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Your light or dark setting stays {mode}.'**
  String e7AppearanceUsesMode(String mode);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Could not save the appearance. Your previous setting is unchanged. Try again.'**
  String get e7AppearanceSaveFailed;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get e7AppearanceSaving;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get e7AppearanceApply;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Current appearance'**
  String get e7AppearanceCurrent;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get e7AppearanceClose;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Text and controls'**
  String get e7AppearancePreviewTitle;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'See how reading, code and selected actions work together.'**
  String get e7AppearancePreviewBody;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Selected option'**
  String get e7AppearanceSelection;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Try a control'**
  String get e7AppearanceTryControl;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Sample controls only change this preview.'**
  String get e7AppearanceSampleHint;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get e7SettingsUi1;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get e7SettingsUi8;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode server'**
  String get e7SettingsUi9;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Checking server health…'**
  String get e7SettingsUi11;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Stopped by Android'**
  String get e7SettingsUi12;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'On · running now'**
  String get e7SettingsUi14;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'On · starting'**
  String get e7SettingsUi15;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'this server'**
  String get e7SettingsUi16;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get e7SettingsUi17;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting.'**
  String get e7SettingsUi18;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again.'**
  String get e7SettingsUi19;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Live updates stop and you return to the server list. The server keeps running; nothing on it is changed.'**
  String get e7SettingsUi20;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting to send.'**
  String get e7SettingsUi21;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Android did not enable background mode.'**
  String get e7SettingsUi22;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Android stopped the live connection'**
  String get e7SettingsUi23;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Its daily limit for background data-sync work is spent, so live mode turned itself off. Turn it back on to reconnect; the limit resets within 24 hours.'**
  String get e7SettingsUi24;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Stay connected in the background'**
  String get e7SettingsUi25;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Keeps runs updating when the app is closed and notifies you when one needs you. Uses more battery and shows a persistent notification.'**
  String get e7SettingsUi26;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted battery access allowed'**
  String get e7SettingsUi27;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Allow unrestricted battery access'**
  String get e7SettingsUi28;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Android may still apply its foreground-service time limit.'**
  String get e7SettingsUi29;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Optional. Helps preserve the live connection during Doze. Android 15+ limits data-sync background work to six hours per 24 hours.'**
  String get e7SettingsUi30;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Stopped by Android — tap to restart'**
  String get e7SettingsUi31;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get e7SettingsUi32;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Android 15+ allows six hours of this per 24 hours and then stops it; the app turns the switch off and says so when that happens.'**
  String get e7SettingsUi34;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Default shell'**
  String get e7SettingsUi35;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Used by new terminals and compatible shell commands on this OpenCode server.'**
  String get e7SettingsUi36;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Terminal only; OpenCode uses a compatible fallback for shell tools.'**
  String get e7SettingsUi37;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Default shell updated'**
  String get e7SettingsUi38;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Automatic (server default)'**
  String get e7SettingsUi39;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Shell selection isn\'t available on OpenCode 2 servers'**
  String get e7SettingsUi40;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Loading shells from OpenCode…'**
  String get e7SettingsUi41;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Server update commands copied'**
  String get e7SettingsUi45;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Restart OpenCode on its host'**
  String get e7SettingsUi46;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Update remote OpenCode?'**
  String get e7SettingsUi48;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'The active server changed before the upgrade completed'**
  String get e7SettingsUi49;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Update managed OpenCode'**
  String get e7SettingsUi50;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Install the latest stable server, refresh models, restart safely, and reconnect.'**
  String get e7SettingsUi51;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'the previous version'**
  String get e7SettingsUi52;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'an unknown version'**
  String get e7SettingsUi53;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Server updates are managed externally'**
  String get e7SettingsUi54;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Copy the official upgrade and model-refresh commands to run on the server host.'**
  String get e7SettingsUi55;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get e7SettingsUi56;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Check server health'**
  String get e7SettingsUi57;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Asking the server how it is doing'**
  String get e7SettingsUi58;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Server healthy'**
  String get e7SettingsUi59;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Health unavailable'**
  String get e7SettingsUi60;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get e7SettingsUi61;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'No server password saved'**
  String get e7SettingsUi62;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or switch OpenCode servers'**
  String get e7SettingsUi64;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Run as a Linux service'**
  String get e7SettingsUi65;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Keep OpenCode running on your computer after you close the terminal; copy setup, status, restart, log, and update commands'**
  String get e7SettingsUi66;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Server updates'**
  String get e7SettingsUi67;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Upgrade from the machine running the server'**
  String get e7SettingsUi68;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Light or dark'**
  String get e7SettingsUi69;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get e7SettingsUi70;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Needs Android 12 or newer'**
  String get e7SettingsUi71;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'This phone’s Material You colors'**
  String get e7SettingsUi72;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Always allowed actions'**
  String get e7SettingsUi74;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Review or revoke durable OpenCode permissions for this project'**
  String get e7SettingsUi75;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get e7SettingsUi76;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Storage used'**
  String get e7SettingsUi77;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear queued prompts'**
  String get e7SettingsUi78;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting to send'**
  String get e7SettingsUi79;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Delete queued prompts?'**
  String get e7SettingsUi80;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Queued prompts deleted'**
  String get e7SettingsUi81;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the queued prompts. Check device storage and try again.'**
  String get e7SettingsUi82;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear drafts'**
  String get e7SettingsUi83;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'No saved composer text'**
  String get e7SettingsUi84;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Delete drafts?'**
  String get e7SettingsUi85;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Drafts deleted'**
  String get e7SettingsUi86;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the drafts. Check device storage and try again.'**
  String get e7SettingsUi87;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'App diagnostics'**
  String get e7SettingsUi88;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'No captured errors'**
  String get e7SettingsUi89;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Connect a computer or run OpenCode on this phone'**
  String get e7SettingsUi91;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Privacy and data use'**
  String get e7SettingsUi92;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Servers, providers, voice, files, Termux, and updates'**
  String get e7SettingsUi93;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Voice licenses and provenance'**
  String get e7SettingsUi94;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Whisper models, sherpa-onnx, ONNX Runtime, and record'**
  String get e7SettingsUi95;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'About and open source notices'**
  String get e7SettingsUi96;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'App details, components, and license notices'**
  String get e7SettingsUi97;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Live updates stop and you return to the server list. The server keeps running; nothing on it is changed.\n\n{queued, plural, =0{No queued prompts.} =1{1 queued prompt.} other{{queued} queued prompts.}} {drafts, plural, =0{No unsent drafts.} =1{1 unsent draft.} other{{drafts} unsent drafts.}} They stay on this device until you connect to this server again.'**
  String e7SettingsDisconnectBody(int queued, int drafts);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from {server}?'**
  String e7SettingsDisconnectTitle(String server);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Health unavailable — {error}'**
  String e7SettingsHealthError(String error);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Server healthy · {version}'**
  String e7SettingsHealthVersion(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String e7SettingsVersion(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Terminal green, the default'**
  String get e7AppearancePackOpencode;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Mocha and Latte, mauve-led'**
  String get e7AppearancePackCatppuccin;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Warm retro, orange-led'**
  String get e7AppearancePackGruvbox;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'The classic dual palette, blue-led'**
  String get e7AppearancePackSolarized;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'This phone’s Material You colors'**
  String get e7AppearancePackDynamic;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'{total} of unsent work — {queued, plural, =1{1 queued prompt} other{{queued} queued prompts}} ({queueBytes}) and {drafts, plural, =1{1 draft} other{{drafts} drafts}} ({draftBytes}). Queued prompts are discarded after {days} days.'**
  String e7SettingsStorageSummary(
    String total,
    int queued,
    String queueBytes,
    int drafts,
    String draftBytes,
    int days,
  );

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Deletes all {count} unsent prompts and their attachments, for every server'**
  String e7SettingsQueueDeleteSummary(int count);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'This deletes {count} unsent prompts and their attachments, for every server. They will never be sent. Nothing on the server is affected.'**
  String e7SettingsQueueDeleteBody(int count);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Deletes composer text saved for {count} conversations'**
  String e7SettingsDraftDeleteSummary(int count);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'This deletes the composer text saved for {count} conversations. Nothing on the server is affected.'**
  String e7SettingsDraftDeleteBody(int count);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 handled error kept in memory} other{{count} handled errors kept in memory}}'**
  String e7SettingsDiagnosticCount(int count);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode {version} is installed, but this server process is still running {current}. Restart that process on the server host; mobile will reconnect and confirm the running version.'**
  String e7SettingsRestartBody(String version, String current);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Install OpenCode {target} on {server} using the server’s detected installation method. The current process is running {current}.\n\nThe install keeps server data in place, but the OpenCode process must be restarted on its host before the new version takes effect.'**
  String e7SettingsUpgradeBody(String target, String server, String current);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Install {version}'**
  String e7SettingsInstallVersion(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode {version} installed. Restart its server process to use it.'**
  String e7SettingsInstalledVersion(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Restart OpenCode to use {version}'**
  String e7SettingsRestartVersion(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'{error} Tap to retry.'**
  String e7SettingsRetryError(String error);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'{version} is installed. The current process is still {current}.'**
  String e7SettingsInstalledCurrent(String version, String current);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Update OpenCode to {version}'**
  String e7SettingsUpdateVersion(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Current server: {version}. Uses OpenCode’s official installer; host restart required.'**
  String e7SettingsCurrentServer(String version);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Basic authentication enabled as {user}'**
  String e7SettingsAuthenticationUser(String user);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied'**
  String get e7SettingsDetailUi0;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics sent to OpenCode'**
  String get e7SettingsDetailUi2;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear diagnostics?'**
  String get e7SettingsDetailUi3;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'This removes every captured error from process memory.'**
  String get e7SettingsDetailUi4;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get e7SettingsDetailUi5;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Private until you send it'**
  String get e7SettingsDetailUi7;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Handled app errors are redacted and kept only in memory. Your messages and file contents are not collected. Nothing is sent automatically.'**
  String get e7SettingsDetailUi8;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get e7SettingsDetailUi10;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t accept client logs'**
  String get e7SettingsDetailUi12;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'No captured app errors'**
  String get e7SettingsDetailUi13;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Handled Flutter, platform, and startup errors will appear here for this app run.'**
  String get e7SettingsDetailUi14;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get e7SettingsDetailUi16;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get e7SettingsDetailUi17;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get e7SettingsDetailUi18;

  /// About screen build provenance heading, independent of release channel
  ///
  /// In en, this message translates to:
  /// **'About this build'**
  String get e7SettingsDetailUi19;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode for Android'**
  String get e7SettingsDetailUi20;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode for desktop'**
  String get e7SettingsDetailUi21;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'A mobile client for an OpenCode server. Voice recognition runs locally after optional model downloads.'**
  String get e7SettingsDetailUi22;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'A desktop client for an OpenCode server.'**
  String get e7SettingsDetailUi23;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get e7SettingsDetailUi25;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get e7SettingsDetailUi26;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get e7SettingsDetailUi27;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'App information could not be loaded. Try opening this page again.'**
  String get e7SettingsInformationFailed;

  /// About screen AI assistance provenance and experimental desktop limitation
  ///
  /// In en, this message translates to:
  /// **'This independent app is built heavily with AI assistance. Android is the primary supported platform. Desktop builds are experimental and have not been hardware-tested. Report what breaks to help improve the app.'**
  String get e7SettingsAlphaBody;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode Mobile is an independent community project. It is not built, maintained, endorsed by, or affiliated with the official OpenCode team.'**
  String get e7SettingsNonAffiliation;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Third-party license notices below are reproduced in their original language.'**
  String get e7SettingsOriginalLicenses;

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'Could not send diagnostics: {error}'**
  String e7SettingsDiagnosticSendError(String error);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 handled error} other{{count} handled errors}}'**
  String e7SettingsDiagnosticTotal(int count);

  /// Settings and appearance user interface.
  ///
  /// In en, this message translates to:
  /// **'{count} occurrences'**
  String e7SettingsDiagnosticOccurrences(int count);

  /// Project browser reconnecting error
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again shortly.'**
  String get e7ProjectProjectsReconnect;

  /// Project rename confirmation
  ///
  /// In en, this message translates to:
  /// **'Project renamed to {name}'**
  String e7ProjectProjectRenamed(String name);

  /// Project rename failure preserving server error
  ///
  /// In en, this message translates to:
  /// **'Could not rename project: {error}'**
  String e7ProjectProjectRenameFailed(String error);

  /// Configured folder fallback
  ///
  /// In en, this message translates to:
  /// **'The server’s default directory'**
  String get e7ProjectProjectDefaultDirectory;

  /// Project management unavailable heading
  ///
  /// In en, this message translates to:
  /// **'Project switching is unavailable'**
  String get e7ProjectProjectSwitchUnavailable;

  /// Project management unavailable explanation
  ///
  /// In en, this message translates to:
  /// **'This server keeps the configured folder for conversations. Start a new conversation from Work to continue.'**
  String get e7ProjectProjectSwitchUnavailableDetail;

  /// Project browser title
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get e7ProjectProjectsTitle;

  /// Refresh project catalog action
  ///
  /// In en, this message translates to:
  /// **'Refresh projects'**
  String get e7ProjectProjectsRefresh;

  /// Project browser search hint
  ///
  /// In en, this message translates to:
  /// **'Search projects or paths'**
  String get e7ProjectProjectsSearch;

  /// Clear project search action
  ///
  /// In en, this message translates to:
  /// **'Clear project search'**
  String get e7ProjectProjectsClearSearch;

  /// Opened project section heading
  ///
  /// In en, this message translates to:
  /// **'Open projects'**
  String get e7ProjectProjectsOpened;

  /// Filtered project count
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String e7ProjectProjectsCount(int shown, int total);

  /// Empty project catalog heading
  ///
  /// In en, this message translates to:
  /// **'No projects opened'**
  String get e7ProjectProjectsEmpty;

  /// Empty project catalog guidance
  ///
  /// In en, this message translates to:
  /// **'Projects opened by this server appear here; choose one for conversations, files, terminals, and coding tools. Create a new folder or open one by its path above, or open a project on this OpenCode server and refresh.'**
  String get e7ProjectProjectsEmptyDetail;

  /// No project search results heading
  ///
  /// In en, this message translates to:
  /// **'No matching projects'**
  String get e7ProjectProjectsNoMatch;

  /// Project search empty guidance
  ///
  /// In en, this message translates to:
  /// **'Try a project name or a directory from the server.'**
  String get e7ProjectProjectsNoMatchDetail;

  /// Cached project catalog refresh error heading
  ///
  /// In en, this message translates to:
  /// **'Project refresh failed'**
  String get e7ProjectProjectsRefreshFailed;

  /// Git worktree count beneath project path
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 worktree} other{{count} worktrees}}'**
  String e7ProjectProjectWorktrees(int count);

  /// Rename project tooltip
  ///
  /// In en, this message translates to:
  /// **'Rename {name}'**
  String e7ProjectProjectRenameAction(String name);

  /// Rename project dialog heading
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get e7ProjectProjectRenameTitle;

  /// Project display name input label
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get e7ProjectProjectNameLabel;

  /// Project rename empty name explanation
  ///
  /// In en, this message translates to:
  /// **'Clear the name to use the project folder name.'**
  String get e7ProjectProjectNameHint;

  /// Save project display name action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get e7ProjectProjectSave;

  /// Attention overview empty heading
  ///
  /// In en, this message translates to:
  /// **'No saved servers'**
  String get e7ProjectAttentionNoServers;

  /// Attention overview empty guidance
  ///
  /// In en, this message translates to:
  /// **'Add a server from the server list to see it here.'**
  String get e7ProjectAttentionNoServersDetail;

  /// Unnamed saved server fallback
  ///
  /// In en, this message translates to:
  /// **'Saved server'**
  String get e7ProjectAttentionSavedServer;

  /// Attention selected server status
  ///
  /// In en, this message translates to:
  /// **'Selected server'**
  String get e7ProjectAttentionSelected;

  /// Attention inactive server status
  ///
  /// In en, this message translates to:
  /// **'Inactive server'**
  String get e7ProjectAttentionInactive;

  /// Attention cached observation scope and freshness disclosure
  ///
  /// In en, this message translates to:
  /// **'Source: selected server’s local cache. Scope: currently loaded project and conversations. Last refreshed: unknown.'**
  String get e7ProjectAttentionCacheSource;

  /// Attention inactive profile scope and unknown state disclosure
  ///
  /// In en, this message translates to:
  /// **'Source: saved server only. Attention status: unknown. Last checked: unknown.'**
  String get e7ProjectAttentionProfileSource;

  /// Unknown pending attention count
  ///
  /// In en, this message translates to:
  /// **'Pending requests: unknown'**
  String get e7ProjectAttentionPendingUnknown;

  /// Positive cached pending request count
  ///
  /// In en, this message translates to:
  /// **'Last-known pending requests: {count}'**
  String e7ProjectAttentionPendingKnown(int count);

  /// Unknown active session count
  ///
  /// In en, this message translates to:
  /// **'Running conversations: unknown'**
  String get e7ProjectAttentionRunningUnknown;

  /// Positive cached active or retrying session count
  ///
  /// In en, this message translates to:
  /// **'Last-known running or retrying conversations: {count}'**
  String e7ProjectAttentionRunningKnown(int count);

  /// Unknown unread count
  ///
  /// In en, this message translates to:
  /// **'Unread conversations: unknown'**
  String get e7ProjectAttentionUnreadUnknown;

  /// Positive cached unread session count
  ///
  /// In en, this message translates to:
  /// **'Last-known unread conversations: {count}'**
  String e7ProjectAttentionUnreadKnown(int count);

  /// Open selected server attention action
  ///
  /// In en, this message translates to:
  /// **'Open server'**
  String get e7ProjectAttentionOpen;

  /// Choose inactive saved server action
  ///
  /// In en, this message translates to:
  /// **'Choose server…'**
  String get e7ProjectAttentionChoose;

  /// Unsupported connection background attention explanation
  ///
  /// In en, this message translates to:
  /// **'Background attention is unavailable for this server. Open the conversation to review current requests.'**
  String get e7ProjectMonitorUnsupported;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'The server is not connected.'**
  String get readerUiDisconnected;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again shortly.'**
  String get readerUiReconnectingRetry;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'File change indicators are unavailable on this server.'**
  String get readerUiIndicatorsUnavailable;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'File change indicators could not refresh.'**
  String get readerUiIndicatorsFailed;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting.'**
  String get readerUiReconnecting;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Review comment added. Return to the conversation to continue.'**
  String get readerUiCommentAdded;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Review comment copied. Paste it into a conversation.'**
  String get readerUiCommentCopied;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Search symbols'**
  String get readerUiSearchSymbols;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get readerUiSearchFiles;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear symbol search'**
  String get readerUiClearSymbolSearch;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear file search'**
  String get readerUiClearFileSearch;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Select a file to preview'**
  String get readerUiSelectFile;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Folder is empty'**
  String get readerUiEmptyFolder;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get readerUiNoFiles;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh this folder.'**
  String get readerUiPullRefresh;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Try a different file name.'**
  String get readerUiTryFileName;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get readerUiOpenFolder;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get readerUiOpen;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get readerUiExpand;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Attach to prompt'**
  String get readerUiAttachPrompt;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Add as reference'**
  String get readerUiAddReference;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Open in Review'**
  String get readerUiOpenReview;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get readerUiCopyPath;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Search project symbols'**
  String get readerUiWorkspaceSymbols;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Find classes, functions, methods, and variables by name.'**
  String get readerUiSymbolsHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'No symbols found'**
  String get readerUiNoSymbols;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Try a different name. Some language services do not support project-wide symbol search.'**
  String get readerUiSymbolsUnavailable;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Review all changes'**
  String get readerUiReviewAll;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get readerUiCopied;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get readerUiFiles;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get readerUiSymbols;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get readerUiChanges;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Refresh changes'**
  String get readerUiRefreshChanges;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Copied from review'**
  String get readerUiCopiedReview;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Entire file change'**
  String get readerUiEntireChange;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Selected change'**
  String get readerUiSelectedChange;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Working tree'**
  String get readerUiWorkingTree;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Changes attributed to this OpenCode conversation'**
  String get readerUiSessionScopeHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Current uncommitted Git changes'**
  String get readerUiWorkingScopeHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Changes against the default branch'**
  String get readerUiBranchScopeHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Unified'**
  String get readerUiUnified;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get readerUiSplit;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Previous hunk'**
  String get readerUiPreviousHunk;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Next hunk'**
  String get readerUiNextHunk;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get readerUiAsk;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get readerUiAddFile;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Add file to prompt'**
  String get readerUiAddFilePrompt;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Ask about file'**
  String get readerUiAskFile;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'File review actions'**
  String get readerUiFileActions;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Start of file'**
  String get readerUiStartFile;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'No gap'**
  String get readerUiNoGap;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get readerUiClearSelection;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Copy selection'**
  String get readerUiCopySelection;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Add hunk to prompt'**
  String get readerUiAddHunk;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Add selection to prompt'**
  String get readerUiAddSelection;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get readerUiComment;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Comment on change'**
  String get readerUiCommentChange;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'What should OpenCode inspect or change?'**
  String get readerUiCommentHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Add to prompt'**
  String get readerUiAddPrompt;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'No changes to review'**
  String get readerUiNoChanges;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'OpenCode has not changed any files in this conversation.'**
  String get readerUiNoChangesHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Diff content unavailable'**
  String get readerUiDiffUnavailable;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'The server reported this file but did not include a patch or file contents.'**
  String get readerUiDiffUnavailableHint;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Copy file contents'**
  String get readerUiCopyContents;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get readerUiSaveDevice;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get readerUiClosePreview;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get readerUiPreviewUnavailable;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Image could not be displayed'**
  String get readerUiImageFailed;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'The file data is not a supported image.'**
  String get readerUiImageUnsupported;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Rendered'**
  String get readerUiRendered;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get readerUiRaw;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Could not save reader preferences. Try again.'**
  String get readerUiSaveFailed;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'File order'**
  String get readerUiFileOrder;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Source first'**
  String get readerUiSourceFirst;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get readerUiServerOrder;

  /// Reader, Files and review user interface.
  ///
  /// In en, this message translates to:
  /// **'Reorders entries; no files are hidden.'**
  String get readerUiOrderHint;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'line {number}'**
  String readerUiLine(int number);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Added {label} to the prompt'**
  String readerUiReferenceAdded(String label);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{label} is already on the prompt'**
  String readerUiReferenceDuplicate(String label);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'The prompt already holds {count} references'**
  String readerUiReferenceFull(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{name} attached.'**
  String readerUiAttached(String name);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Copied {path}'**
  String readerUiCopiedPath(String path);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} changed file} other{{count} changed files}}'**
  String readerUiChangedCount(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} file} other{{count} files}} · +{added} −{removed}'**
  String readerUiChangeSummary(int count, int added, int removed);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Add {path} to the prompt'**
  String readerUiAddPath(String path);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{name} attached. Return to the conversation to add your comment.'**
  String readerUiAttachedReturn(String name);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Save {name}'**
  String readerUiSaveNamed(String name);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{name} saved to your device.'**
  String readerUiSavedDevice(String name);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{path} · Line {line}'**
  String readerUiPathLine(String path, int line);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count} on prompt'**
  String readerUiOnPrompt(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'old {oldLabel} · new {newLabel}'**
  String readerUiOldNew(String oldLabel, String newLabel);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'new {label}'**
  String readerUiNewLines(String label);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'old {label}'**
  String readerUiOldLines(String label);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} selected line} other{{count} selected lines}}'**
  String readerUiSelectedLines(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'lines {first}–{last}'**
  String readerUiLineRange(int first, int last);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Review `{path}`'**
  String readerUiReviewPrompt(String path);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{viewed} of {files} viewed'**
  String readerUiViewedCount(int viewed, int files);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hunk} other{{count} hunks}}'**
  String readerUiHunkCount(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Reviewing {path}'**
  String readerUiReviewing(String path);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{+{count} line} other{+{count} lines}}'**
  String readerUiHiddenLines(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count} unchanged lines hidden. {text}'**
  String readerUiHiddenDescription(int count, String text);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Expand. {count} unchanged lines hidden below'**
  String readerUiExpandDescription(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String readerUiMoreCount(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Hunk selected · {count, plural, one{{count} line} other{{count} lines}}'**
  String readerUiHunkSelected(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String readerUiSaved(String name);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String readerUiBytes(int count);

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get readerUiSymbolFile;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get readerUiSymbolModule;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Namespace'**
  String get readerUiSymbolNamespace;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get readerUiSymbolPackage;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get readerUiSymbolClass;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get readerUiSymbolMethod;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get readerUiSymbolProperty;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get readerUiSymbolField;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Constructor'**
  String get readerUiSymbolConstructor;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Enum'**
  String get readerUiSymbolEnum;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get readerUiSymbolInterface;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Function'**
  String get readerUiSymbolFunction;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get readerUiSymbolVariable;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get readerUiSymbolConstant;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Enum member'**
  String get readerUiSymbolEnummember;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Struct'**
  String get readerUiSymbolStruct;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get readerUiSymbolEvent;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get readerUiSymbolOperator;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Type parameter'**
  String get readerUiSymbolTypeparameter;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get readerUiSymbolSymbol;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get readerUiAdded;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get readerUiDeleted;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get readerUiModified;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get readerUiChanged;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get readerUiSession;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get readerUiBranch;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get readerUiRemoved;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get readerUiUnchanged;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Hunk'**
  String get readerUiHunk;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get readerUiMetadata;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'{path}, {status}, {added} additions, {removed} deletions'**
  String readerUiFileDescription(
    String path,
    String status,
    int added,
    int removed,
  );

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Unknown file type'**
  String get readerUiUnknownType;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'This format cannot be rendered in the app yet.'**
  String get readerUiFormatUnsupported;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'The attachment content is not included in this message.'**
  String get readerUiAttachmentMissing;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'Remote attachment previews are not available.'**
  String get readerUiRemoteAttachment;

  /// Reader display, status or accessible label. Technical placeholders remain original.
  ///
  /// In en, this message translates to:
  /// **'The attachment data could not be decoded.'**
  String get readerUiAttachmentInvalid;

  /// Image preview gesture hint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom'**
  String get readerUiPinchZoom;

  /// Git file status shown next to a path.
  ///
  /// In en, this message translates to:
  /// **'added'**
  String get readerUiStatusAdded;

  /// Git file status shown next to a path.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get readerUiStatusDeleted;

  /// Git file status shown next to a path.
  ///
  /// In en, this message translates to:
  /// **'modified'**
  String get readerUiStatusModified;

  /// Review selection bar line count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} line selected} other{{count} lines selected}}'**
  String readerUiSelectionCount(int count);

  /// Workspace and activity: The server is not connected.
  ///
  /// In en, this message translates to:
  /// **'The server is not connected.'**
  String get e7WorkspaceDisconnected;

  /// Workspace and activity: No project folder chosen
  ///
  /// In en, this message translates to:
  /// **'No project folder chosen'**
  String get e7WorkspaceNoFolder;

  /// Workspace and activity: Loading projects
  ///
  /// In en, this message translates to:
  /// **'Loading projects'**
  String get e7WorkspaceLoadingProjects;

  /// Workspace and activity: No projects opened
  ///
  /// In en, this message translates to:
  /// **'No projects opened'**
  String get e7WorkspaceNoProjects;

  /// Workspace and activity: The server returned no projects.
  ///
  /// In en, this message translates to:
  /// **'The server returned no projects.'**
  String get e7WorkspaceServerNoProjects;

  /// Workspace and activity: Choose a project
  ///
  /// In en, this message translates to:
  /// **'Choose a project'**
  String get e7WorkspaceChooseProject;

  /// Workspace and activity: Needs you
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get e7WorkspaceNeedsYou;

  /// Workspace and activity: Recent sessions
  ///
  /// In en, this message translates to:
  /// **'Recent conversations'**
  String get e7WorkspaceRecentSessions;

  /// Workspace and activity: No recent sessions
  ///
  /// In en, this message translates to:
  /// **'No recent conversations'**
  String get e7WorkspaceNoRecent;

  /// Workspace and activity: Choose a project folder to start a session.
  ///
  /// In en, this message translates to:
  /// **'Choose a project folder to start a conversation.'**
  String get e7WorkspaceChooseFolderToStart;

  /// Workspace and activity: Start a session in the selected workspace.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation in the selected project.'**
  String get e7WorkspaceStartInWorkspace;

  /// Workspace and activity: Archived sessions
  ///
  /// In en, this message translates to:
  /// **'Archived conversations'**
  String get e7WorkspaceArchivedSessions;

  /// Workspace and activity: No project selected
  ///
  /// In en, this message translates to:
  /// **'No project selected'**
  String get e7WorkspaceNoProjectSelected;

  /// Workspace and activity: Switch project
  ///
  /// In en, this message translates to:
  /// **'Switch project'**
  String get e7WorkspaceSwitchProject;

  /// Workspace and activity: Workspace
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get e7WorkspaceWorkspace;

  /// Workspace and activity: This computer
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get e7WorkspaceThisComputer;

  /// Workspace and activity: No share link was returned.
  ///
  /// In en, this message translates to:
  /// **'No share link was returned.'**
  String get e7WorkspaceNoShareLink;

  /// Workspace and activity: Share link copied
  ///
  /// In en, this message translates to:
  /// **'Share link copied'**
  String get e7WorkspaceShareCopied;

  /// Workspace and activity: Session is no longer shared
  ///
  /// In en, this message translates to:
  /// **'Conversation is no longer shared'**
  String get e7WorkspaceUnshared;

  /// Workspace and activity: OpenCode is reconnecting. Try again shortly.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again shortly.'**
  String get e7WorkspaceReconnectingShortly;

  /// Workspace and activity: Rename session
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get e7WorkspaceRenameSession;

  /// Workspace and activity: Title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get e7WorkspaceTitle;

  /// Workspace and activity: Archive session?
  ///
  /// In en, this message translates to:
  /// **'Archive conversation?'**
  String get e7WorkspaceArchiveConfirm;

  /// Workspace and activity: Share this session?
  ///
  /// In en, this message translates to:
  /// **'Share this conversation?'**
  String get e7WorkspaceShareConfirm;

  /// Workspace and activity: Delete session?
  ///
  /// In en, this message translates to:
  /// **'Delete conversation?'**
  String get e7WorkspaceDeleteConfirm;

  /// Workspace and activity: Archive
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get e7WorkspaceArchive;

  /// Workspace and activity: Share session
  ///
  /// In en, this message translates to:
  /// **'Share conversation'**
  String get e7WorkspaceShareSession;

  /// Workspace and activity: Archived session actions
  ///
  /// In en, this message translates to:
  /// **'Archived conversation actions'**
  String get e7WorkspaceArchivedActions;

  /// Workspace and activity: Rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get e7WorkspaceRename;

  /// Workspace and activity: Compacting…
  ///
  /// In en, this message translates to:
  /// **'Compacting…'**
  String get e7WorkspaceCompacting;

  /// Workspace and activity: Share
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get e7WorkspaceShare;

  /// Workspace and activity: Stop sharing
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get e7WorkspaceStopSharing;

  /// Workspace and activity: Disconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get e7WorkspaceDisconnect;

  /// Workspace and activity: Press back again to exit
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get e7WorkspaceBackExit;

  /// Workspace and activity: Connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get e7WorkspaceConnected;

  /// Workspace and activity: Connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get e7WorkspaceConnecting;

  /// Workspace and activity: Offline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get e7WorkspaceOffline;

  /// Workspace and activity: OpenCode is reconnecting. Try again.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again.'**
  String get e7WorkspaceReconnectingAgain;

  /// Workspace and activity: Could not refresh
  ///
  /// In en, this message translates to:
  /// **'Could not refresh'**
  String get e7WorkspaceRefreshFailed;

  /// Workspace and activity: Server requests
  ///
  /// In en, this message translates to:
  /// **'Server requests'**
  String get e7WorkspaceServerRequests;

  /// Workspace and activity: Permission required
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get e7WorkspacePermissionRequired;

  /// Workspace and activity: Assistant question
  ///
  /// In en, this message translates to:
  /// **'Assistant question'**
  String get e7WorkspaceAssistantQuestion;

  /// Workspace and activity: Input requested
  ///
  /// In en, this message translates to:
  /// **'Input requested'**
  String get e7WorkspaceInputRequested;

  /// Workspace and activity: Asked by an MCP server
  ///
  /// In en, this message translates to:
  /// **'Asked by an MCP server'**
  String get e7WorkspaceMcpAsked;

  /// Workspace and activity: Dismiss this request?
  ///
  /// In en, this message translates to:
  /// **'Dismiss this request?'**
  String get e7WorkspaceDismissRequest;

  /// Workspace and activity: OpenCode will continue without answers to these questions.
  ///
  /// In en, this message translates to:
  /// **'OpenCode will continue without answers to these questions.'**
  String get e7WorkspaceDismissDetail;

  /// Workspace and activity: OpenCode needs input
  ///
  /// In en, this message translates to:
  /// **'OpenCode needs input'**
  String get e7WorkspaceNeedsInput;

  /// Workspace and activity: Send answers
  ///
  /// In en, this message translates to:
  /// **'Send answers'**
  String get e7WorkspaceSendAnswers;

  /// Workspace and activity: Session reference unavailable. Refresh and try again.
  ///
  /// In en, this message translates to:
  /// **'Conversation reference unavailable. Refresh and try again.'**
  String get e7WorkspaceReferenceRetry;

  /// Workspace and activity: Session location unavailable. Refresh and try again.
  ///
  /// In en, this message translates to:
  /// **'The conversation’s project is unavailable. Refresh and try again.'**
  String get e7WorkspaceLocationRetry;

  /// Workspace and activity: Session location changed. Return and try again.
  ///
  /// In en, this message translates to:
  /// **'The conversation’s project changed. Return and try again.'**
  String get e7WorkspaceLocationChangedReturn;

  /// Workspace and activity: Session location changed. Refresh and try again.
  ///
  /// In en, this message translates to:
  /// **'The conversation’s project changed. Refresh and try again.'**
  String get e7WorkspaceLocationChangedRetry;

  /// Workspace and activity: Session reference unavailable.
  ///
  /// In en, this message translates to:
  /// **'Conversation reference unavailable.'**
  String get e7WorkspaceReferenceUnavailable;

  /// Workspace and activity: Session pagination could not advance. Refresh the list to continue.
  ///
  /// In en, this message translates to:
  /// **'Conversation pagination could not advance. Refresh the list to continue.'**
  String get e7WorkspacePaginationStuck;

  /// Workspace and activity: Continue this session here?
  ///
  /// In en, this message translates to:
  /// **'Continue this conversation here?'**
  String get e7WorkspaceContinueHereConfirm;

  /// Workspace and activity: Could not create a session: {error}
  ///
  /// In en, this message translates to:
  /// **'Could not create a conversation: {error}'**
  String e7WorkspaceCreateFailed(String error);

  /// Workspace and activity: The server returned no projects. Search all sessions to find previous conversations.
  ///
  /// In en, this message translates to:
  /// **'The server returned no projects. Search all conversations to find previous work.'**
  String get e7WorkspaceNoProjectsSearch;

  /// Workspace and activity: Active session directory · {directory}
  ///
  /// In en, this message translates to:
  /// **'Active conversation’s project · {directory}'**
  String e7WorkspaceActiveDirectory(String directory);

  /// Workspace and activity: {count, plural, one {1 archived session} other {{count} archived sessions}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 archived conversation} other {{count} archived conversations}}'**
  String e7WorkspaceArchivedCount(int count);

  /// Workspace and activity: {count, plural, one {1 open on this server} other {{count} open on this server}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 open on this server} other {{count} open on this server}}'**
  String e7WorkspaceOpenProjectCount(int count);

  /// Workspace and activity: Archived “{title}”
  ///
  /// In en, this message translates to:
  /// **'Archived “{title}”'**
  String e7WorkspaceArchivedToast(String title);

  /// Workspace and activity: “{title}” will be hidden from recent sessions.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be hidden from recent conversations.'**
  String e7WorkspaceArchiveDetail(String title);

  /// Workspace and activity: “{title}” and its history will be permanently removed.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and its history will be permanently removed.'**
  String e7WorkspaceDeleteDetail(String title);

  /// Workspace and activity: Anyone with the link can view “{title}”, including its conversation and shared context. Do not share secrets, credentials, or private files.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can view “{title}”, including its conversation and shared context. Do not share secrets, credentials, or private files.'**
  String e7WorkspaceShareDetail(String title);

  /// Workspace and activity: Shared: {url}
  ///
  /// In en, this message translates to:
  /// **'Shared: {url}'**
  String e7WorkspaceSharedUrl(String url);

  /// Workspace and activity: {count, plural, one {1 item needs attention} other {{count} items need attention}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 item needs attention} other {{count} items need attention}}'**
  String e7WorkspaceAttentionCount(int count);

  /// Workspace and activity: Server: {name}
  ///
  /// In en, this message translates to:
  /// **'Server: {name}'**
  String e7WorkspaceServerName(String name);

  /// Workspace and activity: Server {status}
  ///
  /// In en, this message translates to:
  /// **'Server {status}'**
  String e7WorkspaceServerStatus(String status);

  /// Workspace and activity: for {title}
  ///
  /// In en, this message translates to:
  /// **'for {title}'**
  String e7WorkspaceRequestFor(String title);

  /// Workspace and activity: {count, plural, one {1 question · {title}} other {{count} questions · {title}}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 question · {title}} other {{count} questions · {title}}}'**
  String e7WorkspaceQuestionCount(int count, String title);

  /// Workspace and activity: {count, plural, one {1 subagent} other {{count} subagents}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 subagent} other {{count} subagents}}'**
  String e7WorkspaceSubagentCount(int count);

  /// Workspace and activity: Session {id}
  ///
  /// In en, this message translates to:
  /// **'Conversation {id}'**
  String e7WorkspaceSessionId(String id);

  /// Workspace and activity: “{title}” will belong to your current workspace through the server’s sync system. It stops belonging to the workspace it runs in now.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will belong to your current project through the server’s sync system. It stops belonging to the project it runs in now.'**
  String e7WorkspaceContinueHereDetail(String title);

  /// Workspace and activity: “{title}” now belongs to this workspace
  ///
  /// In en, this message translates to:
  /// **'“{title}” now belongs to this project'**
  String e7WorkspaceMovedHere(String title);

  /// Workspace and activity: Open {title}. {detail}
  ///
  /// In en, this message translates to:
  /// **'Open {title}. {detail}'**
  String e7WorkspaceOpenSessionSemantics(String title, String detail);

  /// Workspace and activity: Loading sessions…
  ///
  /// In en, this message translates to:
  /// **'Loading conversations…'**
  String get e7WorkspaceLoadingSessions;

  /// Workspace and activity: Older conversations may still be available below.
  ///
  /// In en, this message translates to:
  /// **'Older conversations may still be available below.'**
  String get e7WorkspaceLoadedRecentEmpty;

  /// Workspace and activity: Search session titles across every project on this server
  ///
  /// In en, this message translates to:
  /// **'Search conversation titles across every project on this server'**
  String get e7WorkspaceSearchServer;

  /// Workspace and activity: Unknown project
  ///
  /// In en, this message translates to:
  /// **'Unknown project'**
  String get e7WorkspaceUnknownProject;

  /// Workspace and activity: Just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get e7WorkspaceJustNow;

  /// Workspace and activity: {count}m ago
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String e7WorkspaceMinutesAgo(int count);

  /// Workspace and activity: {count}h ago
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String e7WorkspaceHoursAgo(int count);

  /// Workspace and activity: {count}d ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String e7WorkspaceDaysAgo(int count);

  /// Workspace and activity: {count, plural, one {1 file} other {{count} files}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 file} other {{count} files}}'**
  String e7WorkspaceFileCount(int count);

  /// Workspace background connection state
  ///
  /// In en, this message translates to:
  /// **'Stays connected in the background'**
  String get e7WorkspaceBackgroundOn;

  /// Workspace background connection state
  ///
  /// In en, this message translates to:
  /// **'Background updates off'**
  String get e7WorkspaceBackgroundOff;

  /// Distinguishes phone-side folder filtering of loaded results from server-wide title search.
  ///
  /// In en, this message translates to:
  /// **'{count} shown from {total} loaded conversations'**
  String e7WorkspaceFilteredLoaded(int count, int total);

  /// Distinguishes phone-side folder filtering of loaded results from server-wide title search.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 loaded conversation} other {{count} loaded conversations}} · {folders, plural, one {1 project} other {{folders} projects}}'**
  String e7WorkspaceLoadedSummary(int count, int folders);

  /// Distinguishes phone-side folder filtering of loaded results from server-wide title search.
  ///
  /// In en, this message translates to:
  /// **'Loaded projects'**
  String get e7WorkspaceLoadedFolders;

  /// Chat journey:  under a message for actions
  ///
  /// In en, this message translates to:
  /// **' under a message for actions'**
  String get chatUiUnderAMessageForActions;

  /// Chat journey: (all matching requests)
  ///
  /// In en, this message translates to:
  /// **'(all matching requests)'**
  String get chatUiAllMatchingRequests;

  /// Chat journey: (no output)
  ///
  /// In en, this message translates to:
  /// **'(no output)'**
  String get chatUiNoOutput;

  /// Chat journey: (no result)
  ///
  /// In en, this message translates to:
  /// **'(no result)'**
  String get chatUiNoResult;

  /// Chat journey: (tap to expand)
  ///
  /// In en, this message translates to:
  /// **'(tap to expand)'**
  String get chatUiTapToExpand;

  /// Chat journey: 1 reference is added as text when you send. Not saved with your draft.
  ///
  /// In en, this message translates to:
  /// **'1 reference is added as text when you send. Not saved with your draft.'**
  String get chatUi1ReferenceIsAddedAsTextWhen;

  /// Chat journey: Actions
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get chatUiActions;

  /// Chat journey: Add an OpenCode project reference to this prompt
  ///
  /// In en, this message translates to:
  /// **'Add an OpenCode project reference to this prompt'**
  String get chatUiAddAnOpenCodeProjectReferenceToThis;

  /// Chat journey: Add an image or file to the prompt
  ///
  /// In en, this message translates to:
  /// **'Add an image or file to the prompt'**
  String get chatUiAddAnImageOrFileToThe;

  /// Chat journey: Add. Hold to attach a file
  ///
  /// In en, this message translates to:
  /// **'Add. Hold to attach a file'**
  String get chatUiAddHoldToAttachAFile;

  /// Chat journey: Agent
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get chatUiAgent;

  /// Chat journey: Allow once
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get chatUiAllowOnce;

  /// Chat journey: Already answered elsewhere
  ///
  /// In en, this message translates to:
  /// **'Already answered elsewhere'**
  String get chatUiAlreadyAnsweredElsewhere;

  /// Chat journey: Already delivered
  ///
  /// In en, this message translates to:
  /// **'Already delivered'**
  String get chatUiAlreadyDelivered;

  /// Chat journey: Always allow
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get chatUiAlwaysAllow;

  /// Chat journey: Always allow patterns:
  ///
  /// In en, this message translates to:
  /// **'Always allow patterns:'**
  String get chatUiAlwaysAllowPatterns;

  /// Chat journey: Always allow would also cover
  ///
  /// In en, this message translates to:
  /// **'Always allow would also cover'**
  String get chatUiAlwaysAllowWouldAlsoCover;

  /// Chat journey: Answer was cut off by the length limit
  ///
  /// In en, this message translates to:
  /// **'Answer was cut off by the length limit'**
  String get chatUiAnswerWasCutOffByTheLength;

  /// Chat journey: Anyone with the link can view this session’s conversation and shared context. Do not share sessions containing secrets, credentials, or private files.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can view this conversation and its shared context. Do not share conversations containing secrets, credentials, or private files.'**
  String get chatUiAnyoneWithTheLinkCanViewThis;

  /// Chat journey: App diagnostics
  ///
  /// In en, this message translates to:
  /// **'App diagnostics'**
  String get chatUiAppDiagnostics;

  /// Chat journey: Appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get chatUiAppearance;

  /// Chat journey: Apply patch
  ///
  /// In en, this message translates to:
  /// **'Apply patch'**
  String get chatUiApplyPatch;

  /// Chat journey: Ask OpenCode…
  ///
  /// In en, this message translates to:
  /// **'Ask OpenCode…'**
  String get chatUiAskOpenCode;

  /// Chat journey: Assistant is working
  ///
  /// In en, this message translates to:
  /// **'Assistant is working'**
  String get chatUiAssistantIsWorking;

  /// Chat journey: Attach file
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get chatUiAttachFile;

  /// Chat journey: Attach to prompt
  ///
  /// In en, this message translates to:
  /// **'Attach to prompt'**
  String get chatUiAttachToPrompt;

  /// Chat journey: Attachment
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatUiAttachment;

  /// Chat journey: Attachment limit reached
  ///
  /// In en, this message translates to:
  /// **'Attachment limit reached'**
  String get chatUiAttachmentLimitReached;

  /// Chat journey: Attachments must total no more than 20 MB.
  ///
  /// In en, this message translates to:
  /// **'Attachments must total no more than 20 MB.'**
  String get chatUiAttachmentsMustTotalNoMoreThan20;

  /// Chat journey: Available when the current run finishes
  ///
  /// In en, this message translates to:
  /// **'Available when the current run finishes'**
  String get chatUiAvailableWhenTheCurrentRunFinishes;

  /// Chat journey: Browse project and global skills
  ///
  /// In en, this message translates to:
  /// **'Browse project and global skills'**
  String get chatUiBrowseProjectAndGlobalSkills;

  /// Chat journey: Browse, preview, download, and attach project files
  ///
  /// In en, this message translates to:
  /// **'Browse, preview, download, and attach project files'**
  String get chatUiBrowsePreviewDownloadAndAttachProjectFiles;

  /// Chat journey: Cancel and return to the composer
  ///
  /// In en, this message translates to:
  /// **'Cancel and return to the composer'**
  String get chatUiCancelAndReturnToTheComposer;

  /// Chat journey: Cancel message
  ///
  /// In en, this message translates to:
  /// **'Cancel message'**
  String get chatUiCancelMessage;

  /// Chat journey: Cancel this pending message?
  ///
  /// In en, this message translates to:
  /// **'Cancel this pending message?'**
  String get chatUiCancelThisPendingMessage;

  /// Chat journey: Change the active OpenCode Console organization
  ///
  /// In en, this message translates to:
  /// **'Change the active OpenCode Console organization'**
  String get chatUiChangeTheActiveOpenCodeConsoleOrganization;

  /// Chat journey: Change the title shown in the session list
  ///
  /// In en, this message translates to:
  /// **'Change the title shown in the conversation list'**
  String get chatUiChangeTheTitleShownInTheSession;

  /// Chat journey: Change this session’s experimental workspace
  ///
  /// In en, this message translates to:
  /// **'Change this conversation’s experimental cloud environment'**
  String get chatUiChangeThisSessionSExperimentalWorkspace;

  /// Chat journey: Changed file
  ///
  /// In en, this message translates to:
  /// **'Changed file'**
  String get chatUiChangedFile;

  /// Chat journey: Changes
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get chatUiChanges;

  /// Chat journey: Choose a prompt and continue it in a new session
  ///
  /// In en, this message translates to:
  /// **'Choose a prompt and continue it in a new conversation'**
  String get chatUiChooseAPromptAndContinueItIn;

  /// Chat journey: Choose a prompt to restore it in a new session.
  ///
  /// In en, this message translates to:
  /// **'Choose a prompt to restore it in a new conversation.'**
  String get chatUiChooseAPromptToRestoreItIn;

  /// Chat journey: Choose a server model by provider and capability
  ///
  /// In en, this message translates to:
  /// **'Choose a server model by provider and capability'**
  String get chatUiChooseAServerModelByProviderAnd;

  /// Chat journey: Choose another model in the picker to build your recent list.
  ///
  /// In en, this message translates to:
  /// **'Choose another model in the picker to build your recent list.'**
  String get chatUiChooseAnotherModelInThePickerTo;

  /// Chat journey: Choose model
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get chatUiChooseModel;

  /// Chat journey: Choose the active OpenCode agent
  ///
  /// In en, this message translates to:
  /// **'Choose the active OpenCode agent'**
  String get chatUiChooseTheActiveOpenCodeAgent;

  /// Chat journey: Choose the current model variant or reasoning effort
  ///
  /// In en, this message translates to:
  /// **'Choose the current model variant or reasoning effort'**
  String get chatUiChooseTheCurrentModelVariantOrReasoning;

  /// Chat journey: Close composer tools
  ///
  /// In en, this message translates to:
  /// **'Close composer tools'**
  String get chatUiCloseComposerTools;

  /// Chat journey: Close prompt editor
  ///
  /// In en, this message translates to:
  /// **'Close prompt editor'**
  String get chatUiClosePromptEditor;

  /// Chat journey: Close timeline
  ///
  /// In en, this message translates to:
  /// **'Close timeline'**
  String get chatUiCloseTimeline;

  /// Chat journey: Collapse reasoning
  ///
  /// In en, this message translates to:
  /// **'Collapse reasoning'**
  String get chatUiCollapseReasoning;

  /// Chat journey: Collapse reasoning details
  ///
  /// In en, this message translates to:
  /// **'Collapse reasoning details'**
  String get chatUiCollapseReasoningDetails;

  /// Chat journey: Collapsed until you tap it
  ///
  /// In en, this message translates to:
  /// **'Collapsed until you tap it'**
  String get chatUiCollapsedUntilYouTapIt;

  /// Chat journey: Command map
  ///
  /// In en, this message translates to:
  /// **'Command map'**
  String get chatUiCommandMap;

  /// Chat journey: Compact context
  ///
  /// In en, this message translates to:
  /// **'Compact context'**
  String get chatUiCompactContext;

  /// Chat journey: Compact session
  ///
  /// In en, this message translates to:
  /// **'Compact conversation'**
  String get chatUiCompactSession;

  /// Chat journey: Compacting conversation…
  ///
  /// In en, this message translates to:
  /// **'Compacting conversation…'**
  String get chatUiCompactingConversation;

  /// Chat journey: Compaction failed
  ///
  /// In en, this message translates to:
  /// **'Compaction failed'**
  String get chatUiCompactionFailed;

  /// Chat journey: Compaction started
  ///
  /// In en, this message translates to:
  /// **'Compaction started'**
  String get chatUiCompactionStarted;

  /// Chat journey: Compose
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get chatUiCompose;

  /// Chat journey: Composer tools
  ///
  /// In en, this message translates to:
  /// **'Composer tools'**
  String get chatUiComposerTools;

  /// Chat journey: Confirm always allow
  ///
  /// In en, this message translates to:
  /// **'Confirm always allow'**
  String get chatUiConfirmAlwaysAllow;

  /// Chat journey: Confirm broader access
  ///
  /// In en, this message translates to:
  /// **'Confirm broader access'**
  String get chatUiConfirmBroaderAccess;

  /// Chat journey: Connect provider
  ///
  /// In en, this message translates to:
  /// **'Connect provider'**
  String get chatUiConnectProvider;

  /// Chat journey: Connection health, server version, and live mode
  ///
  /// In en, this message translates to:
  /// **'Connection health, server version, and live mode'**
  String get chatUiConnectionHealthServerVersionAndLiveMode;

  /// Chat journey: Consequence: future matching actions can run without asking again for the lifetime of this OpenCode server. Allow once is safer.
  ///
  /// In en, this message translates to:
  /// **'Consequence: future matching actions can run without asking again for the lifetime of this OpenCode server. Allow once is safer.'**
  String get chatUiConsequenceFutureMatchingActionsCanRunWithout;

  /// Chat journey: Context added
  ///
  /// In en, this message translates to:
  /// **'Context added'**
  String get chatUiContextAdded;

  /// Chat journey: Context compacted
  ///
  /// In en, this message translates to:
  /// **'Context compacted'**
  String get chatUiContextCompacted;

  /// Chat journey: Context update pending
  ///
  /// In en, this message translates to:
  /// **'Context update pending'**
  String get chatUiContextUpdatePending;

  /// Chat journey: Context usage
  ///
  /// In en, this message translates to:
  /// **'Context usage'**
  String get chatUiContextUsage;

  /// Chat journey: Copied. Paste it into the composer
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it into the composer'**
  String get chatUiCopiedPasteItIntoTheComposer;

  /// Chat journey: Copy message text
  ///
  /// In en, this message translates to:
  /// **'Copy message text'**
  String get chatUiCopyMessageText;

  /// Chat journey: Copy share link
  ///
  /// In en, this message translates to:
  /// **'Copy share link'**
  String get chatUiCopyShareLink;

  /// Chat journey: Copy the rendered conversation as Markdown
  ///
  /// In en, this message translates to:
  /// **'Copy the rendered conversation as Markdown'**
  String get chatUiCopyTheRenderedConversationAsMarkdown;

  /// Chat journey: Copy transcript
  ///
  /// In en, this message translates to:
  /// **'Copy transcript'**
  String get chatUiCopyTranscript;

  /// Chat journey: Create or copy a public session link
  ///
  /// In en, this message translates to:
  /// **'Create or copy a public conversation link'**
  String get chatUiCreateOrCopyAPublicSessionLink;

  /// Chat journey: Current session
  ///
  /// In en, this message translates to:
  /// **'Current conversation'**
  String get chatUiCurrentSession;

  /// Chat journey: Delegate
  ///
  /// In en, this message translates to:
  /// **'Delegate'**
  String get chatUiDelegate;

  /// Chat journey: Delegate this prompt
  ///
  /// In en, this message translates to:
  /// **'Delegate this prompt'**
  String get chatUiDelegateThisPrompt;

  /// Chat journey: Delegate this prompt to a server subagent
  ///
  /// In en, this message translates to:
  /// **'Delegate this prompt to a server subagent'**
  String get chatUiDelegateThisPromptToAServerSubagent;

  /// Chat journey: Delegated session
  ///
  /// In en, this message translates to:
  /// **'Delegated conversation'**
  String get chatUiDelegatedSession;

  /// Chat journey: Delete message
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatUiDeleteMessage;

  /// Chat journey: Delete this message?
  ///
  /// In en, this message translates to:
  /// **'Delete this message?'**
  String get chatUiDeleteThisMessage;

  /// Chat journey: Describe a change, ask about this project, or paste an error.
  ///
  /// In en, this message translates to:
  /// **'Describe a change, ask about this project, or paste an error.'**
  String get chatUiDescribeAChangeAskAboutThisProject;

  /// Chat journey: Details
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get chatUiDetails;

  /// Chat journey: Directory
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get chatUiDirectory;

  /// Chat journey: Disable the current public session link
  ///
  /// In en, this message translates to:
  /// **'Disable the current public conversation link'**
  String get chatUiDisableTheCurrentPublicSessionLink;

  /// Chat journey: Discard
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get chatUiDiscard;

  /// Chat journey: Discard draft
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get chatUiDiscardDraft;

  /// Chat journey: Discard prompt changes?
  ///
  /// In en, this message translates to:
  /// **'Discard prompt changes?'**
  String get chatUiDiscardPromptChanges;

  /// Chat journey: Discard queued draft?
  ///
  /// In en, this message translates to:
  /// **'Discard queued draft?'**
  String get chatUiDiscardQueuedDraft;

  /// Chat journey: Dismiss prompt error
  ///
  /// In en, this message translates to:
  /// **'Dismiss prompt error'**
  String get chatUiDismissPromptError;

  /// Chat journey: Each attachment must be 10 MB or smaller.
  ///
  /// In en, this message translates to:
  /// **'Each attachment must be 10 MB or smaller.'**
  String get chatUiEachAttachmentMustBe10MBOr;

  /// Chat journey: Edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatUiEdit;

  /// Chat journey: Edit draft
  ///
  /// In en, this message translates to:
  /// **'Edit draft'**
  String get chatUiEditDraft;

  /// Chat journey: Edit the current prompt in a focused full-screen view
  ///
  /// In en, this message translates to:
  /// **'Edit the current prompt in a focused full-screen view'**
  String get chatUiEditTheCurrentPromptInAFocused;

  /// Chat journey: Empty session was kept because OpenCode could not verify or remove it.
  ///
  /// In en, this message translates to:
  /// **'Empty conversation was kept because OpenCode could not verify or remove it.'**
  String get chatUiEmptySessionWasKeptBecauseOpenCodeCould;

  /// Chat journey: Error details
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get chatUiErrorDetails;

  /// Chat journey: Expand reasoning
  ///
  /// In en, this message translates to:
  /// **'Expand reasoning'**
  String get chatUiExpandReasoning;

  /// Chat journey: Expand reasoning details
  ///
  /// In en, this message translates to:
  /// **'Expand reasoning details'**
  String get chatUiExpandReasoningDetails;

  /// Chat journey: Expanded under each answer
  ///
  /// In en, this message translates to:
  /// **'Expanded under each answer'**
  String get chatUiExpandedUnderEachAnswer;

  /// Chat journey: Explain this project
  ///
  /// In en, this message translates to:
  /// **'Explain this project'**
  String get chatUiExplainThisProject;

  /// Chat journey: Explored
  ///
  /// In en, this message translates to:
  /// **'Explored'**
  String get chatUiExplored;

  /// Chat journey: Exploring
  ///
  /// In en, this message translates to:
  /// **'Exploring'**
  String get chatUiExploring;

  /// Chat journey: Export session transcript
  ///
  /// In en, this message translates to:
  /// **'Export conversation transcript'**
  String get chatUiExportSessionTranscript;

  /// Chat journey: Export transcript
  ///
  /// In en, this message translates to:
  /// **'Export transcript'**
  String get chatUiExportTranscript;

  /// Chat journey: FILE
  ///
  /// In en, this message translates to:
  /// **'FILE'**
  String get chatUiFILE;

  /// Chat journey: Fetch page
  ///
  /// In en, this message translates to:
  /// **'Fetch page'**
  String get chatUiFetchPage;

  /// Chat journey: Files
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get chatUiFiles;

  /// Chat journey: Files are unavailable in this preview.
  ///
  /// In en, this message translates to:
  /// **'Files are unavailable in this preview.'**
  String get chatUiFilesAreUnavailableInThisPreview;

  /// Chat journey: Find a command or action
  ///
  /// In en, this message translates to:
  /// **'Find a command or action'**
  String get chatUiFindACommandOrAction;

  /// Chat journey: Find a message, jump to it, or fork from a prompt
  ///
  /// In en, this message translates to:
  /// **'Find a message, jump to it, or fork from a prompt'**
  String get chatUiFindAMessageJumpToItOr;

  /// Chat journey: Find a subagent
  ///
  /// In en, this message translates to:
  /// **'Find a subagent'**
  String get chatUiFindASubagent;

  /// Chat journey: Find and fix a bug
  ///
  /// In en, this message translates to:
  /// **'Find and fix a bug'**
  String get chatUiFindAndFixABug;

  /// Chat journey: Find files
  ///
  /// In en, this message translates to:
  /// **'Find files'**
  String get chatUiFindFiles;

  /// Chat journey: Find sessions across every OpenCode project
  ///
  /// In en, this message translates to:
  /// **'Find conversations across every OpenCode project'**
  String get chatUiFindSessionsAcrossEveryOpenCodeProject;

  /// Chat journey: Follow Android or choose the native light or dark theme
  ///
  /// In en, this message translates to:
  /// **'Follow Android or choose the native light or dark theme'**
  String get chatUiFollowAndroidOrChooseTheNativeLight;

  /// Chat journey: Fork from prompt
  ///
  /// In en, this message translates to:
  /// **'Fork from prompt'**
  String get chatUiForkFromPrompt;

  /// Chat journey: Fork from this prompt
  ///
  /// In en, this message translates to:
  /// **'Fork from this prompt'**
  String get chatUiForkFromThisPrompt;

  /// Chat journey: Fork session
  ///
  /// In en, this message translates to:
  /// **'Fork conversation'**
  String get chatUiForkSession;

  /// Chat journey: From tool call
  ///
  /// In en, this message translates to:
  /// **'From tool call'**
  String get chatUiFromToolCall;

  /// Chat journey: Generated file
  ///
  /// In en, this message translates to:
  /// **'Generated file'**
  String get chatUiGeneratedFile;

  /// Chat journey: Hidden to keep the transcript quiet
  ///
  /// In en, this message translates to:
  /// **'Hidden to keep the transcript quiet'**
  String get chatUiHiddenToKeepTheTranscriptQuiet;

  /// Chat journey: Hide timestamps
  ///
  /// In en, this message translates to:
  /// **'Hide timestamps'**
  String get chatUiHideTimestamps;

  /// Chat journey: Image data is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Image data is unavailable.'**
  String get chatUiImageDataIsUnavailable;

  /// Chat journey: Input requested
  ///
  /// In en, this message translates to:
  /// **'Input requested'**
  String get chatUiInputRequested;

  /// Chat journey: Inspect Git, language services, and formatters for this project
  ///
  /// In en, this message translates to:
  /// **'Inspect Git, language services, and formatters for this project'**
  String get chatUiInspectGitLanguageServicesAndFormattersFor;

  /// Chat journey: Inspect MCP status, authentication, and resources
  ///
  /// In en, this message translates to:
  /// **'Inspect MCP status, authentication, and resources'**
  String get chatUiInspectMCPStatusAuthenticationAndResources;

  /// Chat journey: Inspect current tokens, cache, cost, and context usage
  ///
  /// In en, this message translates to:
  /// **'Inspect current tokens, cache, cost, and context usage'**
  String get chatUiInspectCurrentTokensCacheCostAndContext;

  /// Chat journey: Inspect tools callable by the active provider and model
  ///
  /// In en, this message translates to:
  /// **'Inspect tools callable by the active provider and model'**
  String get chatUiInspectToolsCallableByTheActiveProvider;

  /// Chat journey: Its text returns to the composer as a draft.
  ///
  /// In en, this message translates to:
  /// **'Its text returns to the composer as a draft.'**
  String get chatUiItsTextReturnsToTheComposerAs;

  /// Chat journey: Jump anywhere in this conversation.
  ///
  /// In en, this message translates to:
  /// **'Jump anywhere in this conversation.'**
  String get chatUiJumpAnywhereInThisConversation;

  /// Chat journey: Jump anywhere. Fork restores a prompt for editing.
  ///
  /// In en, this message translates to:
  /// **'Jump anywhere. Fork restores a prompt for editing.'**
  String get chatUiJumpAnywhereForkRestoresAPromptFor;

  /// Chat journey: Jump to latest
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get chatUiJumpToLatest;

  /// Chat journey: Keep asking
  ///
  /// In en, this message translates to:
  /// **'Keep asking'**
  String get chatUiKeepAsking;

  /// Chat journey: Keep it pending
  ///
  /// In en, this message translates to:
  /// **'Keep it pending'**
  String get chatUiKeepItPending;

  /// Chat journey: Keep it queued
  ///
  /// In en, this message translates to:
  /// **'Keep it queued'**
  String get chatUiKeepItQueued;

  /// Chat journey: Language server
  ///
  /// In en, this message translates to:
  /// **'Language server'**
  String get chatUiLanguageServer;

  /// Chat journey: List
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get chatUiList;

  /// Chat journey: List what's in this directory
  ///
  /// In en, this message translates to:
  /// **'List what\'s in this directory'**
  String get chatUiListWhatSInThisDirectory;

  /// Chat journey: Loading subagents…
  ///
  /// In en, this message translates to:
  /// **'Loading subagents…'**
  String get chatUiLoadingSubagents;

  /// Chat journey: Long reasoning collapsed in the transcript
  ///
  /// In en, this message translates to:
  /// **'Long reasoning collapsed in the transcript'**
  String get chatUiLongReasoningCollapsedInTheTranscript;

  /// Chat journey: MCP servers
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get chatUiMCPServers;

  /// Chat journey: Manage provider and integration authentication
  ///
  /// In en, this message translates to:
  /// **'Manage provider and integration authentication'**
  String get chatUiManageProviderAndIntegrationAuthentication;

  /// Chat journey: Manage saved grants in Settings → Saved permissions.
  ///
  /// In en, this message translates to:
  /// **'Manage saved grants in Settings → Saved permissions.'**
  String get chatUiManageSavedGrantsInSettingsSavedPermissions;

  /// Chat journey: Message
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatUiMessage;

  /// Chat journey: Message actions
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get chatUiMessageActions;

  /// Chat journey: Message deleted
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get chatUiMessageDeleted;

  /// Chat journey: Message text copied
  ///
  /// In en, this message translates to:
  /// **'Message text copied'**
  String get chatUiMessageTextCopied;

  /// Chat journey: Message timeline
  ///
  /// In en, this message translates to:
  /// **'Message timeline'**
  String get chatUiMessageTimeline;

  /// Chat journey: Message timestamps hidden
  ///
  /// In en, this message translates to:
  /// **'Message timestamps hidden'**
  String get chatUiMessageTimestampsHidden;

  /// Chat journey: Message timestamps shown
  ///
  /// In en, this message translates to:
  /// **'Message timestamps shown'**
  String get chatUiMessageTimestampsShown;

  /// Chat journey: Messages and file changes after the most recent prompt will be rolled back.
  ///
  /// In en, this message translates to:
  /// **'Messages and file changes after the most recent prompt will be rolled back.'**
  String get chatUiMessagesAndFileChangesAfterTheMost;

  /// Chat journey: Mobile actions and commands from this server
  ///
  /// In en, this message translates to:
  /// **'Mobile actions and commands from this server'**
  String get chatUiMobileActionsAndCommandsFromThisServer;

  /// Chat journey: Model
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatUiModel;

  /// Chat journey: Model and agent
  ///
  /// In en, this message translates to:
  /// **'Model and agent'**
  String get chatUiModelAndAgent;

  /// Chat journey: More
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatUiMore;

  /// Chat journey: Move session
  ///
  /// In en, this message translates to:
  /// **'Move conversation'**
  String get chatUiMoveSession;

  /// Chat journey: Move this session to another project directory
  ///
  /// In en, this message translates to:
  /// **'Move this conversation to another project'**
  String get chatUiMoveThisSessionToAnotherProjectDirectory;

  /// Chat journey: Moved
  ///
  /// In en, this message translates to:
  /// **'Moved'**
  String get chatUiMoved;

  /// Chat journey: Navigate
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get chatUiNavigate;

  /// Chat journey: No answer
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get chatUiNoAnswer;

  /// Chat journey: No matching commands
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get chatUiNoMatchingCommands;

  /// Chat journey: No matching messages
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get chatUiNoMatchingMessages;

  /// Chat journey: No share link was returned
  ///
  /// In en, this message translates to:
  /// **'No share link was returned'**
  String get chatUiNoShareLinkWasReturned;

  /// Chat journey: No subagents available from this server
  ///
  /// In en, this message translates to:
  /// **'No subagents available from this server'**
  String get chatUiNoSubagentsAvailableFromThisServer;

  /// Chat journey: No todos in this session
  ///
  /// In en, this message translates to:
  /// **'No todos in this conversation'**
  String get chatUiNoTodosInThisSession;

  /// Chat journey: Not connected to the server right now.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the server right now.'**
  String get chatUiNotConnectedToTheServerRightNow;

  /// Chat journey: Not run
  ///
  /// In en, this message translates to:
  /// **'Not run'**
  String get chatUiNotRun;

  /// Chat journey: Open full-screen prompt editor
  ///
  /// In en, this message translates to:
  /// **'Open full-screen prompt editor'**
  String get chatUiOpenFullScreenPromptEditor;

  /// Chat journey: Open parent session
  ///
  /// In en, this message translates to:
  /// **'Open parent conversation'**
  String get chatUiOpenParentSession;

  /// Chat journey: Open persistent workspace terminals
  ///
  /// In en, this message translates to:
  /// **'Open persistent project terminals'**
  String get chatUiOpenPersistentWorkspaceTerminals;

  /// Chat journey: Open providers
  ///
  /// In en, this message translates to:
  /// **'Open providers'**
  String get chatUiOpenProviders;

  /// Chat journey: Open subagent session
  ///
  /// In en, this message translates to:
  /// **'Open subagent conversation'**
  String get chatUiOpenSubagentSession;

  /// Chat journey: OpenCode commands are unavailable offline.
  ///
  /// In en, this message translates to:
  /// **'OpenCode commands are unavailable offline.'**
  String get chatUiOpenCodeCommandsAreUnavailableOffline;

  /// Chat journey: OpenCode could not complete this prompt.
  ///
  /// In en, this message translates to:
  /// **'OpenCode could not complete this prompt.'**
  String get chatUiOpenCodeCouldNotCompleteThisPrompt;

  /// Chat journey: OpenCode is reconnecting.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting.'**
  String get chatUiOpenCodeIsReconnecting;

  /// Chat journey: OpenCode is reconnecting. Try again shortly.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again shortly.'**
  String get chatUiOpenCodeIsReconnectingTryAgainShortly;

  /// Chat journey: OpenCode is reconnecting. Try again when the server is online.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again when the server is online.'**
  String get chatUiOpenCodeIsReconnectingTryAgainWhenThe;

  /// Chat journey: OpenCode is reconnecting. Try again.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again.'**
  String get chatUiOpenCodeIsReconnectingTryAgain;

  /// Chat journey: OpenCode needs input
  ///
  /// In en, this message translates to:
  /// **'OpenCode needs input'**
  String get chatUiOpenCodeNeedsInput;

  /// Chat journey: OpenCode server command
  ///
  /// In en, this message translates to:
  /// **'OpenCode server command'**
  String get chatUiOpenCodeServerCommand;

  /// Chat journey: Output pruned
  ///
  /// In en, this message translates to:
  /// **'Output pruned'**
  String get chatUiOutputPruned;

  /// Chat journey: Pending change
  ///
  /// In en, this message translates to:
  /// **'Pending change'**
  String get chatUiPendingChange;

  /// Chat journey: Preview attachment
  ///
  /// In en, this message translates to:
  /// **'Preview attachment'**
  String get chatUiPreviewAttachment;

  /// Chat journey: Project files
  ///
  /// In en, this message translates to:
  /// **'Project files'**
  String get chatUiProjectFiles;

  /// Chat journey: Project health
  ///
  /// In en, this message translates to:
  /// **'Project health'**
  String get chatUiProjectHealth;

  /// Chat journey: Project reference
  ///
  /// In en, this message translates to:
  /// **'Project reference'**
  String get chatUiProjectReference;

  /// Chat journey: Project references
  ///
  /// In en, this message translates to:
  /// **'Project references'**
  String get chatUiProjectReferences;

  /// Chat journey: Projects and workspaces
  ///
  /// In en, this message translates to:
  /// **'Projects and worktrees'**
  String get chatUiProjectsAndWorkspaces;

  /// Chat journey: Prompt editor
  ///
  /// In en, this message translates to:
  /// **'Prompt editor'**
  String get chatUiPromptEditor;

  /// Chat journey: Prompt from parent agent
  ///
  /// In en, this message translates to:
  /// **'Prompt from parent agent'**
  String get chatUiPromptFromParentAgent;

  /// Chat journey: Prompt tools
  ///
  /// In en, this message translates to:
  /// **'Prompt tools'**
  String get chatUiPromptTools;

  /// Chat journey: Question
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get chatUiQuestion;

  /// Chat journey: Questions
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get chatUiQuestions;

  /// Chat journey: Queue
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get chatUiQueue;

  /// Chat journey: Queue after this run
  ///
  /// In en, this message translates to:
  /// **'Queue after this run'**
  String get chatUiQueueAfterThisRun;

  /// Chat journey: Queued · runs after this turn
  ///
  /// In en, this message translates to:
  /// **'Queued · runs after this turn'**
  String get chatUiQueuedRunsAfterThisTurn;

  /// Chat journey: Queued — will send when reconnected
  ///
  /// In en, this message translates to:
  /// **'Queued — will send when reconnected'**
  String get chatUiQueuedWillSendWhenReconnected;

  /// Chat journey: Read
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatUiRead;

  /// Chat journey: Reasoning expanded in the transcript
  ///
  /// In en, this message translates to:
  /// **'Reasoning expanded in the transcript'**
  String get chatUiReasoningExpandedInTheTranscript;

  /// Chat journey: Records and transcribes on this device
  ///
  /// In en, this message translates to:
  /// **'Records and transcribes on this device'**
  String get chatUiRecordsAndTranscribesOnThisDevice;

  /// Chat journey: Reference kept for your next prompt — commands do not carry it.
  ///
  /// In en, this message translates to:
  /// **'Reference kept for your next prompt — commands do not carry it.'**
  String get chatUiReferenceKeptForYourNextPromptCommands;

  /// Chat journey: References kept for your next prompt — commands do not carry them.
  ///
  /// In en, this message translates to:
  /// **'References kept for your next prompt — commands do not carry them.'**
  String get chatUiReferencesKeptForYourNextPromptCommands;

  /// Chat journey: Reject
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get chatUiReject;

  /// Chat journey: Reject…
  ///
  /// In en, this message translates to:
  /// **'Reject…'**
  String get chatUiReject1;

  /// Chat journey: Reload messages
  ///
  /// In en, this message translates to:
  /// **'Refresh messages'**
  String get chatUiReloadMessages;

  /// Chat journey: Removes it from the conversation permanently
  ///
  /// In en, this message translates to:
  /// **'Removes it from the conversation permanently'**
  String get chatUiRemovesItFromTheConversationPermanently;

  /// Chat journey: Rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatUiRename;

  /// Chat journey: Rename session
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get chatUiRenameSession;

  /// Chat journey: Restore messages
  ///
  /// In en, this message translates to:
  /// **'Restore messages'**
  String get chatUiRestoreMessages;

  /// Chat journey: Restore reverted prompt
  ///
  /// In en, this message translates to:
  /// **'Restore reverted prompt'**
  String get chatUiRestoreRevertedPrompt;

  /// Chat journey: Restore the currently reverted session state
  ///
  /// In en, this message translates to:
  /// **'Restore the currently reverted conversation state'**
  String get chatUiRestoreTheCurrentlyRevertedSessionState;

  /// Chat journey: Result
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get chatUiResult;

  /// Chat journey: Retry image preview
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chatUiRetryImagePreview;

  /// Chat journey: Retry last prompt
  ///
  /// In en, this message translates to:
  /// **'Retry last prompt'**
  String get chatUiRetryLastPrompt;

  /// Chat journey: Retry server commands
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chatUiRetryServerCommands;

  /// Chat journey: Revert
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get chatUiRevert;

  /// Chat journey: Revert from this prompt?
  ///
  /// In en, this message translates to:
  /// **'Revert from this prompt?'**
  String get chatUiRevertFromThisPrompt;

  /// Chat journey: Revert last prompt
  ///
  /// In en, this message translates to:
  /// **'Revert last prompt'**
  String get chatUiRevertLastPrompt;

  /// Chat journey: Review comment added to the prompt
  ///
  /// In en, this message translates to:
  /// **'Review comment added to the prompt'**
  String get chatUiReviewCommentAddedToThePrompt;

  /// Chat journey: Review handled app errors and send a redacted report
  ///
  /// In en, this message translates to:
  /// **'Review handled app errors and send a redacted report'**
  String get chatUiReviewHandledAppErrorsAndSendA;

  /// Chat journey: Review the actual diff for this session
  ///
  /// In en, this message translates to:
  /// **'Review the actual diff for this conversation'**
  String get chatUiReviewTheActualDiffForThisSession;

  /// Chat journey: Roll back messages and file changes after the prompt
  ///
  /// In en, this message translates to:
  /// **'Roll back messages and file changes after the prompt'**
  String get chatUiRollBackMessagesAndFileChangesAfter;

  /// Chat journey: Run on your computer
  ///
  /// In en, this message translates to:
  /// **'Run on your computer'**
  String get chatUiRunOnYourComputer;

  /// Chat journey: Run shell command
  ///
  /// In en, this message translates to:
  /// **'Run shell command'**
  String get chatUiRunShellCommand;

  /// Chat journey: Running tools
  ///
  /// In en, this message translates to:
  /// **'Running tools'**
  String get chatUiRunningTools;

  /// Chat journey: Save the conversation as a Markdown file
  ///
  /// In en, this message translates to:
  /// **'Save the conversation as a Markdown file'**
  String get chatUiSaveTheConversationAsAMarkdownFile;

  /// Chat journey: Scope
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get chatUiScope;

  /// Chat journey: Search messages
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatUiSearchMessages;

  /// Chat journey: Search mobile actions and server-provided commands
  ///
  /// In en, this message translates to:
  /// **'Search mobile actions and server-provided commands'**
  String get chatUiSearchMobileActionsAndServerProvidedCommands;

  /// Chat journey: Search text
  ///
  /// In en, this message translates to:
  /// **'Search text'**
  String get chatUiSearchText;

  /// Chat journey: See full diff
  ///
  /// In en, this message translates to:
  /// **'See full diff'**
  String get chatUiSeeFullDiff;

  /// Chat journey: Select a model before compacting this session.
  ///
  /// In en, this message translates to:
  /// **'Select a model before compacting this conversation.'**
  String get chatUiSelectAModelBeforeCompactingThisSession;

  /// Chat journey: Send
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatUiSend;

  /// Chat journey: Send after this run
  ///
  /// In en, this message translates to:
  /// **'Send after this run'**
  String get chatUiSendAfterThisRun;

  /// Chat journey: Send now and steer instead
  ///
  /// In en, this message translates to:
  /// **'Send now and steer instead'**
  String get chatUiSendNowAndSteerInstead;

  /// Chat journey: Send now and steer the current run
  ///
  /// In en, this message translates to:
  /// **'Send now and steer the current run'**
  String get chatUiSendNowAndSteerTheCurrentRun;

  /// Chat journey: Send now and steer this run
  ///
  /// In en, this message translates to:
  /// **'Send now and steer this run'**
  String get chatUiSendNowAndSteerThisRun;

  /// Chat journey: Send rejection
  ///
  /// In en, this message translates to:
  /// **'Send rejection'**
  String get chatUiSendRejection;

  /// Chat journey: Send steers the current run
  ///
  /// In en, this message translates to:
  /// **'Send steers the current run'**
  String get chatUiSendSteersTheCurrentRun;

  /// Chat journey: Send waits for this run to finish
  ///
  /// In en, this message translates to:
  /// **'Send waits for this run to finish'**
  String get chatUiSendWaitsForThisRunToFinish;

  /// Chat journey: Sends after this run finishes
  ///
  /// In en, this message translates to:
  /// **'Sends after this run finishes'**
  String get chatUiSendsAfterThisRunFinishes;

  /// Chat journey: Server commands
  ///
  /// In en, this message translates to:
  /// **'Server commands'**
  String get chatUiServerCommands;

  /// Chat journey: Server commands could not be refreshed
  ///
  /// In en, this message translates to:
  /// **'Server commands could not be refreshed'**
  String get chatUiServerCommandsCouldNotBeRefreshed;

  /// Chat journey: Server message
  ///
  /// In en, this message translates to:
  /// **'Server message'**
  String get chatUiServerMessage;

  /// Chat journey: Server status
  ///
  /// In en, this message translates to:
  /// **'Server status'**
  String get chatUiServerStatus;

  /// Chat journey: Session changes
  ///
  /// In en, this message translates to:
  /// **'Conversation changes'**
  String get chatUiSessionChanges;

  /// Chat journey: Session context
  ///
  /// In en, this message translates to:
  /// **'Conversation context'**
  String get chatUiSessionContext;

  /// Chat journey: Session is no longer shared
  ///
  /// In en, this message translates to:
  /// **'Conversation is no longer shared'**
  String get chatUiSessionIsNoLongerShared;

  /// Chat journey: Session menu
  ///
  /// In en, this message translates to:
  /// **'Conversation menu'**
  String get chatUiSessionMenu;

  /// Chat journey: Session shared. Copy the visible link manually.
  ///
  /// In en, this message translates to:
  /// **'Conversation shared. Copy the visible link manually.'**
  String get chatUiSessionSharedCopyTheVisibleLinkManually;

  /// Chat journey: Share link copied
  ///
  /// In en, this message translates to:
  /// **'Share link copied'**
  String get chatUiShareLinkCopied;

  /// Chat journey: Share session
  ///
  /// In en, this message translates to:
  /// **'Share conversation'**
  String get chatUiShareSession;

  /// Chat journey: Share this session?
  ///
  /// In en, this message translates to:
  /// **'Share this conversation?'**
  String get chatUiShareThisSession;

  /// Chat journey: Shared: anyone with the link can view
  ///
  /// In en, this message translates to:
  /// **'Shared: anyone with the link can view'**
  String get chatUiSharedAnyoneWithTheLinkCanView;

  /// Chat journey: Show all commands
  ///
  /// In en, this message translates to:
  /// **'Show all commands'**
  String get chatUiShowAllCommands;

  /// Chat journey: Show all subagent sessions
  ///
  /// In en, this message translates to:
  /// **'Show all subagent conversations'**
  String get chatUiShowAllSubagentSessions;

  /// Chat journey: Show all subagents
  ///
  /// In en, this message translates to:
  /// **'Show all subagents'**
  String get chatUiShowAllSubagents;

  /// Chat journey: Show full prompt
  ///
  /// In en, this message translates to:
  /// **'Show full prompt'**
  String get chatUiShowFullPrompt;

  /// Chat journey: Show less
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get chatUiShowLess;

  /// Chat journey: Show timestamps
  ///
  /// In en, this message translates to:
  /// **'Show timestamps'**
  String get chatUiShowTimestamps;

  /// Chat journey: Skill ·
  ///
  /// In en, this message translates to:
  /// **'Skill ·'**
  String get chatUiSkill;

  /// Chat journey: Skills
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get chatUiSkills;

  /// Chat journey: Slash commands and agents
  ///
  /// In en, this message translates to:
  /// **'Slash commands and agents'**
  String get chatUiSlashCommandsAndAgents;

  /// Chat journey: Start a clean session in this workspace
  ///
  /// In en, this message translates to:
  /// **'Start a clean conversation in this project'**
  String get chatUiStartACleanSessionInThisWorkspace;

  /// Chat journey: Start a new session with this prompt in the composer
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation with this prompt in the composer'**
  String get chatUiStartANewSessionWithThisPrompt;

  /// Chat journey: Start coding
  ///
  /// In en, this message translates to:
  /// **'Start coding'**
  String get chatUiStartCoding;

  /// Chat journey: Steer
  ///
  /// In en, this message translates to:
  /// **'Steer'**
  String get chatUiSteer;

  /// Chat journey: Steering at the next step
  ///
  /// In en, this message translates to:
  /// **'Steering at the next step'**
  String get chatUiSteeringAtTheNextStep;

  /// Chat journey: Stop sharing
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get chatUiStopSharing;

  /// Chat journey: Subagent
  ///
  /// In en, this message translates to:
  /// **'Subagent'**
  String get chatUiSubagent;

  /// Chat journey: Subagent failed.
  ///
  /// In en, this message translates to:
  /// **'Subagent failed.'**
  String get chatUiSubagentFailed;

  /// Chat journey: Subagent working…
  ///
  /// In en, this message translates to:
  /// **'Subagent working…'**
  String get chatUiSubagentWorking;

  /// Chat journey: Subagents could not be loaded
  ///
  /// In en, this message translates to:
  /// **'Subagents could not be loaded'**
  String get chatUiSubagentsCouldNotBeLoaded;

  /// Chat journey: Summarize the session using the selected model
  ///
  /// In en, this message translates to:
  /// **'Summarize the conversation using the selected model'**
  String get chatUiSummarizeTheSessionUsingTheSelectedModel;

  /// Chat journey: Switch organization
  ///
  /// In en, this message translates to:
  /// **'Switch organization'**
  String get chatUiSwitchOrganization;

  /// Chat journey: Switch project, directory, or worktree
  ///
  /// In en, this message translates to:
  /// **'Switch project, directory, or worktree'**
  String get chatUiSwitchProjectDirectoryOrWorktree;

  /// Chat journey: System update
  ///
  /// In en, this message translates to:
  /// **'System update'**
  String get chatUiSystemUpdate;

  /// Chat journey: Tell the agent why, or what to do instead (optional)
  ///
  /// In en, this message translates to:
  /// **'Tell the agent why, or what to do instead (optional)'**
  String get chatUiTellTheAgentWhyOrWhatTo;

  /// Chat journey: That message is no longer in this session.
  ///
  /// In en, this message translates to:
  /// **'That message is no longer in this conversation.'**
  String get chatUiThatMessageIsNoLongerInThis;

  /// Chat journey: The file has no content to attach.
  ///
  /// In en, this message translates to:
  /// **'The file has no content to attach.'**
  String get chatUiTheFileHasNoContentToAttach;

  /// Chat journey: The file has no content to save.
  ///
  /// In en, this message translates to:
  /// **'The file has no content to save.'**
  String get chatUiTheFileHasNoContentToSave;

  /// Chat journey: The form or project changed. Reopen the current request.
  ///
  /// In en, this message translates to:
  /// **'The form or project changed. Reopen the current request.'**
  String get chatUiTheFormOrProjectChangedReopenThe;

  /// Chat journey: The generated file is not available from this server.
  ///
  /// In en, this message translates to:
  /// **'The generated file is not available from this server.'**
  String get chatUiTheGeneratedFileIsNotAvailableFrom;

  /// Chat journey: The message and all of its parts are permanently removed from the conversation, so future replies no longer see them. File changes it made are not reverted.
  ///
  /// In en, this message translates to:
  /// **'The message and all of its parts are permanently removed from the conversation, so future replies no longer see them. File changes it made are not reverted.'**
  String get chatUiTheMessageAndAllOfItsParts;

  /// Chat journey: The server returned empty image data.
  ///
  /// In en, this message translates to:
  /// **'The server returned empty image data.'**
  String get chatUiTheServerReturnedEmptyImageData;

  /// Chat journey: This draft has not been sent to OpenCode.
  ///
  /// In en, this message translates to:
  /// **'This draft has not been sent to OpenCode.'**
  String get chatUiThisDraftHasNotBeenSentTo;

  /// Chat journey: This draft is too large to queue, or the queue is full of newer drafts. Remove an attachment, or clear queued prompts in Settings.
  ///
  /// In en, this message translates to:
  /// **'This draft is too large to queue, or the queue is full of newer drafts. Remove an attachment, or clear queued prompts in Settings.'**
  String get chatUiThisDraftIsTooLargeToQueue;

  /// Chat journey: This prompt cannot be restored because an attachment is unavailable.
  ///
  /// In en, this message translates to:
  /// **'This prompt cannot be restored because an attachment is unavailable.'**
  String get chatUiThisPromptCannotBeRestoredBecauseAn;

  /// Chat journey: This prompt cannot be retried because an attachment is unavailable.
  ///
  /// In en, this message translates to:
  /// **'This prompt cannot be retried because an attachment is unavailable.'**
  String get chatUiThisPromptCannotBeRetriedBecauseAn;

  /// Chat journey: Time, tokens and cost under each message
  ///
  /// In en, this message translates to:
  /// **'Time, tokens and cost under each message'**
  String get chatUiTimeTokensAndCostUnderEachMessage;

  /// Chat journey: Timeline
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get chatUiTimeline;

  /// Chat journey: Timestamps & usage
  ///
  /// In en, this message translates to:
  /// **'Timestamps & usage'**
  String get chatUiTimestampsUsage;

  /// Chat journey: Tip: type / for commands · tap
  ///
  /// In en, this message translates to:
  /// **'Tip: type / for commands · tap '**
  String get chatUiTipTypeForCommandsTap;

  /// Chat journey: Title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get chatUiTitle;

  /// Chat journey: Todo list
  ///
  /// In en, this message translates to:
  /// **'Todo list'**
  String get chatUiTodoList;

  /// Chat journey: Todos
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get chatUiTodos;

  /// Chat journey: Toggle creation times beside transcript entries
  ///
  /// In en, this message translates to:
  /// **'Toggle creation times beside transcript entries'**
  String get chatUiToggleCreationTimesBesideTranscriptEntries;

  /// Chat journey: Toggle long reasoning details across the transcript
  ///
  /// In en, this message translates to:
  /// **'Toggle long reasoning details across the transcript'**
  String get chatUiToggleLongReasoningDetailsAcrossTheTranscript;

  /// Chat journey: Tool failed.
  ///
  /// In en, this message translates to:
  /// **'Tool failed.'**
  String get chatUiToolFailed;

  /// Chat journey: Tools
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get chatUiTools;

  /// Chat journey: Tools and capabilities
  ///
  /// In en, this message translates to:
  /// **'Tools and capabilities'**
  String get chatUiToolsAndCapabilities;

  /// Chat journey: Transcript
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get chatUiTranscript;

  /// Chat journey: Transcript copied as Markdown
  ///
  /// In en, this message translates to:
  /// **'Transcript copied as Markdown'**
  String get chatUiTranscriptCopiedAsMarkdown;

  /// Chat journey: Transcript display
  ///
  /// In en, this message translates to:
  /// **'Transcript display'**
  String get chatUiTranscriptDisplay;

  /// Chat journey: Transcript saved
  ///
  /// In en, this message translates to:
  /// **'Transcript saved'**
  String get chatUiTranscriptSaved;

  /// Chat journey: Views
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get chatUiViews;

  /// Chat journey: Voice conversation was interrupted.
  ///
  /// In en, this message translates to:
  /// **'Voice conversation was interrupted.'**
  String get chatUiVoiceConversationWasInterrupted;

  /// Chat journey: Voice input
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatUiVoiceInput;

  /// Chat journey: Voice input is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input is unavailable.'**
  String get chatUiVoiceInputIsUnavailable;

  /// Chat journey: Wait for the current run to finish, then send
  ///
  /// In en, this message translates to:
  /// **'Wait for the current run to finish, then send'**
  String get chatUiWaitForTheCurrentRunToFinish;

  /// Chat journey: Wait for this run instead
  ///
  /// In en, this message translates to:
  /// **'Wait for this run instead'**
  String get chatUiWaitForThisRunInstead;

  /// Chat journey: Waiting for this run to finish
  ///
  /// In en, this message translates to:
  /// **'Waiting for this run to finish'**
  String get chatUiWaitingForThisRunToFinish;

  /// Chat journey: Web search
  ///
  /// In en, this message translates to:
  /// **'Web search'**
  String get chatUiWebSearch;

  /// Chat journey: What changed recently?
  ///
  /// In en, this message translates to:
  /// **'What changed recently?'**
  String get chatUiWhatChangedRecently;

  /// Chat journey: When the assistant plans work as a todo list, the items appear here.
  ///
  /// In en, this message translates to:
  /// **'When the assistant plans work as a todo list, the items appear here.'**
  String get chatUiWhenTheAssistantPlansWorkAsA;

  /// Chat journey: Write
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get chatUiWrite;

  /// Chat journey: Write your OpenCode prompt…
  ///
  /// In en, this message translates to:
  /// **'Write your OpenCode prompt…'**
  String get chatUiWriteYourOpenCodePrompt;

  /// Chat journey: You
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatUiYou;

  /// Chat journey: Your original composer draft and attachments will stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Your original composer draft and attachments will stay unchanged.'**
  String get chatUiYourOriginalComposerDraftAndAttachmentsWill;

  /// Chat journey: in this chat
  ///
  /// In en, this message translates to:
  /// **'in this conversation'**
  String get chatUiInThisChat;

  /// Chat journey: includes steps not run
  ///
  /// In en, this message translates to:
  /// **'includes steps not run'**
  String get chatUiIncludesStepsNotRun;

  /// Chat journey: new file
  ///
  /// In en, this message translates to:
  /// **'new file'**
  String get chatUiNewFile;

  /// Chat journey: opencode assistant
  ///
  /// In en, this message translates to:
  /// **'opencode assistant'**
  String get chatUiOpencodeAssistant;

  /// Chat journey: searched once
  ///
  /// In en, this message translates to:
  /// **'searched once'**
  String get chatUiSearchedOnce;

  /// Chat journey: you user
  ///
  /// In en, this message translates to:
  /// **'you user'**
  String get chatUiYouUser;

  /// Chat journey: Queued — will send when reconnected. {detail}
  ///
  /// In en, this message translates to:
  /// **'Queued — will send when reconnected. {detail}'**
  String chatUiQueuedWithEviction(Object detail);

  /// Chat journey: /{command} is not available right now.
  ///
  /// In en, this message translates to:
  /// **'/{command} is not available right now.'**
  String chatUiCommandUnavailable(Object command);

  /// Chat journey: You can attach up to {count} files.
  ///
  /// In en, this message translates to:
  /// **'You can attach up to {count} files.'**
  String chatUiAttachmentCountLimit(Object count);

  /// Chat journey: {count, plural, one{Sent 1 queued prompt} other{Sent {count} queued prompts}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Sent 1 queued prompt} other{Sent {count} queued prompts}}'**
  String chatUiQueuedSent(num count);

  /// Chat journey:  · {count, plural, one{1 draft waiting for other servers} other{{count} drafts waiting for other servers}}
  ///
  /// In en, this message translates to:
  /// **' · {count, plural, one{1 draft waiting for other servers} other{{count} drafts waiting for other servers}}'**
  String chatUiOtherDraftsWaitingSuffix(num count);

  /// Chat journey: Next turns in this session use {model}.
  ///
  /// In en, this message translates to:
  /// **'Next turns in this conversation use {model}.'**
  String chatUiNextTurnsModel(Object model);

  /// Chat journey: @{name} is already in the prompt
  ///
  /// In en, this message translates to:
  /// **'@{name} is already in the prompt'**
  String chatUiReferenceAlreadyAdded(Object name);

  /// Chat journey: {filename} attached. Add your comment.
  ///
  /// In en, this message translates to:
  /// **'{filename} attached. Add your comment.'**
  String chatUiFileAttached(Object filename);

  /// Chat journey: Save {filename}
  ///
  /// In en, this message translates to:
  /// **'Save {filename}'**
  String chatUiSaveFile(Object filename);

  /// Chat journey: {filename} saved to your device.
  ///
  /// In en, this message translates to:
  /// **'{filename} saved to your device.'**
  String chatUiFileSaved(Object filename);

  /// Chat journey: {count, plural, one{1 draft queued to send on reconnect.} other{{count} drafts queued to send on reconnect.}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 draft queued to send on reconnect.} other{{count} drafts queued to send on reconnect.}}'**
  String chatUiDraftsQueued(num count);

  /// Chat journey: {count, plural, one{1 draft waiting for other servers.} other{{count} drafts waiting for other servers.}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 draft waiting for other servers.} other{{count} drafts waiting for other servers.}}'**
  String chatUiOtherDraftsWaiting(num count);

  /// Chat journey: {count, plural, one{1 question} other{{count} questions}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 question} other{{count} questions}}'**
  String chatUiQuestionCount(num count);

  /// Chat journey: Permission needed: {title}
  ///
  /// In en, this message translates to:
  /// **'Permission needed: {title}'**
  String chatUiPermissionNeeded(Object title);

  /// Chat journey: Question: {title}
  ///
  /// In en, this message translates to:
  /// **'Question: {title}'**
  String chatUiQuestionLabel(Object title);

  /// Chat journey: {question} · {count, plural, one{1 question} other{{count} questions}}
  ///
  /// In en, this message translates to:
  /// **'{question} · {count, plural, one{1 question} other{{count} questions}}'**
  String chatUiQuestionsSummary(Object question, num count);

  /// Chat journey: Rate limited. Retrying{attempt}…
  ///
  /// In en, this message translates to:
  /// **'Rate limited. Retrying{attempt}…'**
  String chatUiRateLimitRetry(Object attempt);

  /// Chat journey: Rate limited. Retrying{attempt} in {time}
  ///
  /// In en, this message translates to:
  /// **'Rate limited. Retrying{attempt} in {time}'**
  String chatUiRateLimitCountdown(Object attempt, Object time);

  /// Chat journey: {count, plural, one{1 reference is added as text when you send. Not saved with your draft.} other{{count} references are added as text when you send. Not saved with your draft.}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 reference is added as text when you send. Not saved with your draft.} other{{count} references are added as text when you send. Not saved with your draft.}}'**
  String chatUiReferencesAttachedNotice(num count);

  /// Chat journey: {count} attached
  ///
  /// In en, this message translates to:
  /// **'{count} attached'**
  String chatUiAttachedCount(Object count);

  /// Chat journey: Model and agent: {model}. Tap to change.{cost}
  ///
  /// In en, this message translates to:
  /// **'Model and agent: {model}. Tap to change.{cost}'**
  String chatUiModelAndAgentHint(Object model, Object cost);

  /// Chat journey: Context {percent}% full
  ///
  /// In en, this message translates to:
  /// **'Context {percent}% full'**
  String chatUiContextPercentFull(Object percent);

  /// Chat journey: Remove reference @{name}
  ///
  /// In en, this message translates to:
  /// **'Remove reference @{name}'**
  String chatUiRemoveReferenceName(Object name);

  /// Chat journey: Remove attachment {name}
  ///
  /// In en, this message translates to:
  /// **'Remove attachment {name}'**
  String chatUiRemoveAttachmentName(Object name);

  /// Chat journey: Reference @{name}
  ///
  /// In en, this message translates to:
  /// **'Reference @{name}'**
  String chatUiReferenceName(Object name);

  /// Chat journey: Preview attachment {name}
  ///
  /// In en, this message translates to:
  /// **'Preview attachment {name}'**
  String chatUiPreviewAttachmentName(Object name);

  /// Chat journey: Project reference @{name}
  ///
  /// In en, this message translates to:
  /// **'Project reference @{name}'**
  String chatUiProjectReferenceName(Object name);

  /// Chat journey: Preview {name}
  ///
  /// In en, this message translates to:
  /// **'Preview {name}'**
  String chatUiPreviewName(Object name);

  /// Chat journey: Remove reference {name}
  ///
  /// In en, this message translates to:
  /// **'Remove reference {name}'**
  String chatUiRemoveContextReference(Object name);

  /// Chat journey: Context window {percent} percent used
  ///
  /// In en, this message translates to:
  /// **'Context window {percent} percent used'**
  String chatUiContextPercentUsed(Object percent);

  /// Chat journey: Explain the {name} project
  ///
  /// In en, this message translates to:
  /// **'Explain the {name} project'**
  String chatUiExplainProject(Object name);

  /// Chat journey: {count, plural, one{1 earlier message} other{{count} earlier messages}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 earlier message} other{{count} earlier messages}}'**
  String chatUiEarlierMessageCount(num count);

  /// Chat journey: Previously {value}
  ///
  /// In en, this message translates to:
  /// **'Previously {value}'**
  String chatUiPreviouslyValue(Object value);

  /// Chat journey: {title}, {count, plural, one{1 step} other{{count} steps}}, {status}
  ///
  /// In en, this message translates to:
  /// **'{title}, {count, plural, one{1 step} other{{count} steps}}, {status}'**
  String chatUiToolGroupSemantics(Object title, num count, Object status);

  /// Chat journey: {count} tok
  ///
  /// In en, this message translates to:
  /// **'{count} tok'**
  String chatUiTokenCount(Object count);

  /// Chat journey: {type} · prompt attachment
  ///
  /// In en, this message translates to:
  /// **'{type} · prompt attachment'**
  String chatUiAttachmentType(Object type);

  /// Chat journey: {position} of {total}
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String chatUiPositionOfTotal(Object position, Object total);

  /// Chat journey: Subagent · {count}
  ///
  /// In en, this message translates to:
  /// **'Subagent · {count}'**
  String chatUiSubagentCount(Object count);

  /// Chat journey: Shared session link {url}
  ///
  /// In en, this message translates to:
  /// **'Shared conversation link {url}'**
  String chatUiSharedLink(Object url);

  /// Chat journey: {count, plural, one{1 attachment} other{{count} attachments}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 attachment} other{{count} attachments}}'**
  String chatUiAttachmentCount(num count);

  /// Chat journey: Failed: {error}
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String chatUiFailedDetail(Object error);

  /// Chat journey: Queued draft. {label}
  ///
  /// In en, this message translates to:
  /// **'Queued draft. {label}'**
  String chatUiQueuedDraftLabel(Object label);

  /// Chat journey: Pending send. {label}
  ///
  /// In en, this message translates to:
  /// **'Pending send. {label}'**
  String chatUiPendingSendLabel(Object label);

  /// Chat journey: Context: {permission} {context}
  ///
  /// In en, this message translates to:
  /// **'Context: {permission} {context}'**
  String chatUiPermissionContext(Object permission, Object context);

  /// Chat journey: The agent wants to use {permission}.
  ///
  /// In en, this message translates to:
  /// **'The agent wants to use {permission}.'**
  String chatUiPermissionRequested(Object permission);

  /// Chat journey: Reply failed: {error}
  ///
  /// In en, this message translates to:
  /// **'Reply failed: {error}'**
  String chatUiReplyFailed(Object error);

  /// Chat journey: Copy {resource}
  ///
  /// In en, this message translates to:
  /// **'Copy {resource}'**
  String chatUiCopyResource(Object resource);

  /// Chat journey: {priority} priority
  ///
  /// In en, this message translates to:
  /// **'{priority} priority'**
  String chatUiPriorityLabel(Object priority);

  /// Chat journey: Tools: {tools}
  ///
  /// In en, this message translates to:
  /// **'Tools: {tools}'**
  String chatUiToolsSummary(Object tools);

  /// Chat journey: from {line}
  ///
  /// In en, this message translates to:
  /// **'from {line}'**
  String chatUiFromLine(Object line);

  /// Chat journey: {count, plural, one{1 line} other{{count} lines}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 line} other{{count} lines}}'**
  String chatUiLineCount(num count);

  /// Chat journey: L{start}–{end}
  ///
  /// In en, this message translates to:
  /// **'L{start}–{end}'**
  String chatUiLineRange(Object start, Object end);

  /// Chat journey: {count, plural, one{1 entry} other{{count} entries}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 entry} other{{count} entries}}'**
  String chatUiEntryCount(num count);

  /// Chat journey: {count} found
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String chatUiFoundCount(Object count);

  /// Chat journey: {count, plural, one{1 match} other{{count} matches}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 match} other{{count} matches}}'**
  String chatUiMatchCount(num count);

  /// Chat journey: exit {code}
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String chatUiExitCode(Object code);

  /// Chat journey: {count, plural, one{1 file} other{{count} files}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 file} other{{count} files}}'**
  String chatUiFileCount(num count);

  /// Chat journey: {provider} search
  ///
  /// In en, this message translates to:
  /// **'{provider} search'**
  String chatUiProviderSearch(Object provider);

  /// Chat journey: {count, plural, one{1 result} other{{count} results}}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 result} other{{count} results}}'**
  String chatUiResultCount(num count);

  /// Chat journey: {done}/{total} completed
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} completed'**
  String chatUiCompletedCount(Object done, Object total);

  /// Chat journey: {count} answered
  ///
  /// In en, this message translates to:
  /// **'{count} answered'**
  String chatUiAnsweredCount(Object count);

  /// Chat journey: {count} asked
  ///
  /// In en, this message translates to:
  /// **'{count} asked'**
  String chatUiAskedCount(Object count);

  /// Chat journey: {minutes}m {seconds}s
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String chatUiDurationMinutesSeconds(Object minutes, Object seconds);

  /// Chat journey: {seconds}s
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String chatUiDurationSeconds(Object seconds);

  /// Chat journey: Could not load this file from the OpenCode server: {error}
  ///
  /// In en, this message translates to:
  /// **'Could not load this file from the OpenCode server: {error}'**
  String chatUiFileLoadFailed(Object error);

  /// Chat journey: {total} total · more available
  ///
  /// In en, this message translates to:
  /// **'{total} total · more available'**
  String chatUiMoreEntries(Object total);

  /// Chat journey: {total} entries
  ///
  /// In en, this message translates to:
  /// **'{total} entries'**
  String chatUiEntryTotal(Object total);

  /// Chat journey: See all · {count, plural, one{1 line} other{{count} lines}}
  ///
  /// In en, this message translates to:
  /// **'See all · {count, plural, one{1 line} other{{count} lines}}'**
  String chatUiSeeAllLines(num count);

  /// Chat journey: Answered: {answer}
  ///
  /// In en, this message translates to:
  /// **'Answered: {answer}'**
  String chatUiAnsweredDetail(Object answer);

  /// Chat journey: Loading {filename}
  ///
  /// In en, this message translates to:
  /// **'Loading {filename}'**
  String chatUiLoadingFile(Object filename);

  /// Chat journey: Preview generated image {filename}
  ///
  /// In en, this message translates to:
  /// **'Preview generated image {filename}'**
  String chatUiPreviewGeneratedImage(Object filename);

  /// Chat journey: Open generated file {filename}
  ///
  /// In en, this message translates to:
  /// **'Open generated file {filename}'**
  String chatUiOpenGeneratedFile(Object filename);

  /// Chat journey: Parent · {title}
  ///
  /// In en, this message translates to:
  /// **'Parent · {title}'**
  String chatUiParentSession(Object title);

  /// Chat journey: Choose: {option}
  ///
  /// In en, this message translates to:
  /// **'Choose: {option}'**
  String chatUiChooseOption(Object option);

  /// Chat journey: Conversation
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatUiConversation;

  /// Chat journey: Display and context
  ///
  /// In en, this message translates to:
  /// **'Display and context'**
  String get chatUiDisplayAndContext;

  /// Chat journey: Session actions
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get chatUiSessionActions;

  /// Chat journey: Results
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get chatUiResults;

  /// Chat journey: a permission
  ///
  /// In en, this message translates to:
  /// **'a permission'**
  String get chatUiPermissionFallback;

  /// Chat journey: Main session
  ///
  /// In en, this message translates to:
  /// **'Main conversation'**
  String get chatUiMainSession;

  /// Chat journey: To do
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get chatUiTodo;

  /// Chat journey: Background result
  ///
  /// In en, this message translates to:
  /// **'Background result'**
  String get chatUiBackgroundResult;

  /// Chat journey: Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatUiBackgroundComplete;

  /// Chat journey: Failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get chatUiBackgroundError;

  /// Chat journey: Cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get chatUiBackgroundCancelled;

  /// Chat journey: Result details
  ///
  /// In en, this message translates to:
  /// **'Result details'**
  String get chatUiResultDetails;

  /// Chat journey: Server message details
  ///
  /// In en, this message translates to:
  /// **'Server message details'**
  String get chatUiResultSourceDetails;

  /// Chat journey: Open subagent session
  ///
  /// In en, this message translates to:
  /// **'Open subagent conversation'**
  String get chatUiResultOpenChild;

  /// Chat journey: The server returned no result text.
  ///
  /// In en, this message translates to:
  /// **'The server returned no result text.'**
  String get chatUiNoResultText;

  /// Chat journey: Background
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get chatUiBackground;

  /// Chat journey: Timed out
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get chatUiTimedOut;

  /// Chat journey: Stopped
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get chatUiKilled;

  /// Chat journey: Truncated
  ///
  /// In en, this message translates to:
  /// **'Truncated'**
  String get chatUiTruncated;

  /// Chat journey: Updated
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get chatUiUpdated;

  /// Chat journey: Pending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get chatUiPending;

  /// Chat journey: Running
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get chatUiRunning;

  /// Chat journey: Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatUiCompleted;

  /// Chat journey: Error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get chatUiError;

  /// Chat journey: Unknown status
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get chatUiUnknownStatus;

  /// Chat journey: Assistant
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get chatUiAssistant;

  /// Chat journey: User
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get chatUiUser;

  /// Chat journey: OpenCode session
  ///
  /// In en, this message translates to:
  /// **'OpenCode conversation'**
  String get chatUiOpenCodeSession;

  /// Chat journey: Tool
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get chatUiTool;

  /// Chat journey: file
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get chatUiFile;

  /// Chat journey: ,
  ///
  /// In en, this message translates to:
  /// **', '**
  String get chatUiSeparator;

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{read 1 file} other{read {count} files}}'**
  String chatUiReadFiles(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{searched once} other{searched {count} times}}'**
  String chatUiSearched(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{listed 1 folder} other{listed {count} folders}}'**
  String chatUiListedFolders(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{edited 1 file} other{edited {count} files}}'**
  String chatUiEditedFiles(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{ran 1 command} other{ran {count} commands}}'**
  String chatUiRanCommands(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{fetched 1 page} other{fetched {count} pages}}'**
  String chatUiFetchedPages(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{delegated 1 task} other{delegated {count} tasks}}'**
  String chatUiDelegatedTasks(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{made 1 other call} other{made {count} other calls}}'**
  String chatUiOtherCalls(num count);

  /// Completed tool group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 step was not run} other{{count} steps were not run}}'**
  String chatUiStepsNotRun(num count);

  /// Library and project tools UI: Report a bug
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get e7LibraryReportABug;

  /// Library and project tools UI: Keyboard shortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get e7LibraryKeyboardShortcuts;

  /// Library and project tools UI: HTTP header
  ///
  /// In en, this message translates to:
  /// **'HTTP header'**
  String get e7LibraryHTTPHeader;

  /// Library and project tools UI: environment variable
  ///
  /// In en, this message translates to:
  /// **'environment variable'**
  String get e7LibraryEnvironmentVariable;

  /// Library and project tools UI: OpenCode is reconnecting. Try again shortly.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again shortly.'**
  String get e7LibraryOpenCodeIsReconnectingTryAgainShortly;

  /// Library and project tools UI: {detail1}, but the app could not reconnect. {detail2}
  ///
  /// In en, this message translates to:
  /// **'{detail1}, but the app could not reconnect. {detail2}'**
  String e7LibraryButTheAppCouldNotReconnect(String detail1, String detail2);

  /// Library and project tools UI: What is MCP?
  ///
  /// In en, this message translates to:
  /// **'What is MCP?'**
  String get e7LibraryWhatIsMCP;

  /// Library and project tools UI: Saving configuration
  ///
  /// In en, this message translates to:
  /// **'Saving configuration'**
  String get e7LibrarySavingConfiguration;

  /// Library and project tools UI: Save MCP server
  ///
  /// In en, this message translates to:
  /// **'Save MCP server'**
  String get e7LibrarySaveMCPServer;

  /// Library and project tools UI: Persisted configuration
  ///
  /// In en, this message translates to:
  /// **'Persisted configuration'**
  String get e7LibraryPersistedConfiguration;

  /// Library and project tools UI: Saved by OpenCode on the server. It remains available after the app or server restarts.
  ///
  /// In en, this message translates to:
  /// **'Saved by OpenCode on the server. It remains available after the app or server restarts.'**
  String get e7LibrarySavedByOpenCodeOnTheServerIt;

  /// Library and project tools UI: This project
  ///
  /// In en, this message translates to:
  /// **'This project'**
  String get e7LibraryThisProject;

  /// Library and project tools UI: Writes only to {detail1}.
  ///
  /// In en, this message translates to:
  /// **'Writes only to {detail1}.'**
  String e7LibraryWritesOnlyTo(String detail1);

  /// Library and project tools UI: Writes to this OpenCode server’s global configuration.
  ///
  /// In en, this message translates to:
  /// **'Writes to this OpenCode server’s global configuration.'**
  String get e7LibraryWritesToThisOpenCodeServerSGlobal;

  /// Library and project tools UI: Server name
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get e7LibraryServerName;

  /// Library and project tools UI: docs or browser-tools
  ///
  /// In en, this message translates to:
  /// **'docs or browser-tools'**
  String get e7LibraryDocsOrBrowserTools;

  /// Library and project tools UI: Unique within the selected configuration.
  ///
  /// In en, this message translates to:
  /// **'Unique within the selected configuration.'**
  String get e7LibraryUniqueWithinTheSelectedConfiguration;

  /// Library and project tools UI: Enter a server name
  ///
  /// In en, this message translates to:
  /// **'Enter a server name'**
  String get e7LibraryEnterAServerName;

  /// Library and project tools UI: Remote URL
  ///
  /// In en, this message translates to:
  /// **'Remote URL'**
  String get e7LibraryRemoteURL;

  /// Library and project tools UI: Local command
  ///
  /// In en, this message translates to:
  /// **'Local command'**
  String get e7LibraryLocalCommand;

  /// Library and project tools UI: Timeout in milliseconds
  ///
  /// In en, this message translates to:
  /// **'Timeout in milliseconds'**
  String get e7LibraryTimeoutInMilliseconds;

  /// Library and project tools UI: Optional
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get e7LibraryOptional;

  /// Library and project tools UI: Enter a value greater than zero
  ///
  /// In en, this message translates to:
  /// **'Enter a value greater than zero'**
  String get e7LibraryEnterAValueGreaterThanZero;

  /// Library and project tools UI: MCP endpoint URL
  ///
  /// In en, this message translates to:
  /// **'MCP endpoint URL'**
  String get e7LibraryMCPEndpointURL;

  /// Library and project tools UI: HTTP is accepted for local development servers.
  ///
  /// In en, this message translates to:
  /// **'HTTP is accepted for local development servers.'**
  String get e7LibraryHTTPIsAcceptedForLocalDevelopmentServers;

  /// Library and project tools UI: Enter a valid HTTP or HTTPS URL without credentials
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS URL without credentials'**
  String get e7LibraryEnterAValidHTTPOrHTTPSURL;

  /// Library and project tools UI: HTTP headers
  ///
  /// In en, this message translates to:
  /// **'HTTP headers'**
  String get e7LibraryHTTPHeaders;

  /// Library and project tools UI: Optional. Enter one KEY=VALUE pair per line.
  ///
  /// In en, this message translates to:
  /// **'Optional. Enter one KEY=VALUE pair per line.'**
  String get e7LibraryOptionalEnterOneKEYVALUEPairPer;

  /// Library and project tools UI: Detect OAuth automatically
  ///
  /// In en, this message translates to:
  /// **'Detect OAuth automatically'**
  String get e7LibraryDetectOAuthAutomatically;

  /// Library and project tools UI: Turn this off when the server uses headers and should never start OAuth.
  ///
  /// In en, this message translates to:
  /// **'Turn this off when the server uses headers and should never start OAuth.'**
  String get e7LibraryTurnThisOffWhenTheServerUses;

  /// Library and project tools UI: Command and arguments
  ///
  /// In en, this message translates to:
  /// **'Command and arguments'**
  String get e7LibraryCommandAndArguments;

  /// Library and project tools UI: Runs on the OpenCode server, not this phone. Enter one argument per line.
  ///
  /// In en, this message translates to:
  /// **'Runs on the OpenCode server, not this phone. Enter one argument per line.'**
  String get e7LibraryRunsOnTheOpenCodeServerNotThis;

  /// Library and project tools UI: Enter a command
  ///
  /// In en, this message translates to:
  /// **'Enter a command'**
  String get e7LibraryEnterACommand;

  /// Library and project tools UI: Working directory
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get e7LibraryWorkingDirectory;

  /// Library and project tools UI: Optional server path
  ///
  /// In en, this message translates to:
  /// **'Optional server path'**
  String get e7LibraryOptionalServerPath;

  /// Library and project tools UI: Environment variables
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get e7LibraryEnvironmentVariables;

  /// Library and project tools UI: Invalid {detail1} on line {detail2}. Use KEY=VALUE.
  ///
  /// In en, this message translates to:
  /// **'Invalid {detail1} on line {detail2}. Use KEY=VALUE.'**
  String e7LibraryInvalidOnLineUseKEYVALUE(String detail1, String detail2);

  /// Library and project tools UI: Invalid {detail1} name on line {detail2}.
  ///
  /// In en, this message translates to:
  /// **'Invalid {detail1} name on line {detail2}.'**
  String e7LibraryInvalidNameOnLine(String detail1, String detail2);

  /// Library and project tools UI: Duplicate {detail1} name "{detail2}".
  ///
  /// In en, this message translates to:
  /// **'Duplicate {detail1} name \"{detail2}\".'**
  String e7LibraryDuplicateName(String detail1, String detail2);

  /// Library and project tools UI: OpenCode is reconnecting. Try again.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting. Try again.'**
  String get e7LibraryOpenCodeIsReconnectingTryAgain;

  /// Short title for a saved permission revocation confirmation.
  ///
  /// In en, this message translates to:
  /// **'Revoke access?'**
  String get e7LibraryRevokeAlwaysAllowedAction;

  /// Library and project tools UI: OpenCode will ask again before a future action matching this grant.
  ///
  /// In en, this message translates to:
  /// **'OpenCode will ask again before a future action matching this grant.'**
  String get e7LibraryOpenCodeWillAskAgainBeforeAFuture;

  /// Library and project tools UI: Action
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get e7LibraryAction;

  /// Library and project tools UI: Resource
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get e7LibraryResource;

  /// Library and project tools UI: (all matching resources)
  ///
  /// In en, this message translates to:
  /// **'(all matching resources)'**
  String get e7LibraryAllMatchingResources;

  /// Library and project tools UI: This does not stop an action that is already running.
  ///
  /// In en, this message translates to:
  /// **'This does not stop an action that is already running.'**
  String get e7LibraryThisDoesNotStopAnActionThat;

  /// Library and project tools UI: Keep access
  ///
  /// In en, this message translates to:
  /// **'Keep access'**
  String get e7LibraryKeepAccess;

  /// Library and project tools UI: Revoke access
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get e7LibraryRevokeAccess;

  /// Library and project tools UI: Always allowed action revoked
  ///
  /// In en, this message translates to:
  /// **'Always allowed action revoked'**
  String get e7LibraryAlwaysAllowedActionRevoked;

  /// Library and project tools UI: Always allowed actions
  ///
  /// In en, this message translates to:
  /// **'Always allowed actions'**
  String get e7LibraryAlwaysAllowedActions;

  /// Library and project tools UI: Refresh always allowed actions
  ///
  /// In en, this message translates to:
  /// **'Refresh always allowed actions'**
  String get e7LibraryRefreshAlwaysAllowedActions;

  /// Library and project tools UI: No always allowed actions
  ///
  /// In en, this message translates to:
  /// **'No always allowed actions'**
  String get e7LibraryNoAlwaysAllowedActions;

  /// Library and project tools UI: Grants created with Always allow for this project will appear here.
  ///
  /// In en, this message translates to:
  /// **'Grants created with Always allow for this project will appear here.'**
  String get e7LibraryGrantsCreatedWithAlwaysAllowForThis;

  /// Library and project tools UI: The last action failed
  ///
  /// In en, this message translates to:
  /// **'The last action failed'**
  String get e7LibraryTheLastActionFailed;

  /// Library and project tools UI: Revoke {detail1} access
  ///
  /// In en, this message translates to:
  /// **'Revoke {detail1} access'**
  String e7LibraryRevokeAccess2(String detail1);

  /// Library and project tools UI: Tools and capabilities
  ///
  /// In en, this message translates to:
  /// **'Tools and capabilities'**
  String get e7LibraryToolsAndCapabilities;

  /// Library and project tools UI: Refresh tools
  ///
  /// In en, this message translates to:
  /// **'Refresh tools'**
  String get e7LibraryRefreshTools;

  /// Library and project tools UI: OpenCode tools depend on the provider and model used by the active chat.
  ///
  /// In en, this message translates to:
  /// **'OpenCode tools depend on the provider and model used by the active conversation.'**
  String get e7LibraryOpenCodeToolsDependOnTheProviderAnd;

  /// Library and project tools UI: Choose model
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get e7LibraryChooseModel;

  /// Library and project tools UI: Change
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get e7LibraryChange;

  /// Library and project tools UI: Search tools
  ///
  /// In en, this message translates to:
  /// **'Search tools'**
  String get e7LibrarySearchTools;

  /// Library and project tools UI: Search {detail1} tools
  ///
  /// In en, this message translates to:
  /// **'Search {detail1} tools'**
  String e7LibrarySearchTools2(String detail1);

  /// Library and project tools UI: {detail1} usable
  ///
  /// In en, this message translates to:
  /// **'{detail1} usable'**
  String e7LibraryUsable(String detail1);

  /// Library and project tools UI: {detail1} registered
  ///
  /// In en, this message translates to:
  /// **'{detail1} registered'**
  String e7LibraryRegistered(String detail1);

  /// Library and project tools UI: Background subagents enabled
  ///
  /// In en, this message translates to:
  /// **'Background subagents enabled'**
  String get e7LibraryBackgroundSubagentsEnabled;

  /// Library and project tools UI: Background subagents unavailable
  ///
  /// In en, this message translates to:
  /// **'Background subagents unavailable'**
  String get e7LibraryBackgroundSubagentsUnavailable;

  /// Library and project tools UI: registered inventory unavailable
  ///
  /// In en, this message translates to:
  /// **'registered inventory unavailable'**
  String get e7LibraryRegisteredInventoryUnavailable;

  /// Library and project tools UI: server capability unavailable
  ///
  /// In en, this message translates to:
  /// **'server capability unavailable'**
  String get e7LibraryServerCapabilityUnavailable;

  /// Library and project tools UI: No tools for this model
  ///
  /// In en, this message translates to:
  /// **'No tools for this model'**
  String get e7LibraryNoToolsForThisModel;

  /// Library and project tools UI: No matching tools
  ///
  /// In en, this message translates to:
  /// **'No matching tools'**
  String get e7LibraryNoMatchingTools;

  /// Library and project tools UI: OpenCode returned no callable tools for this provider and model.
  ///
  /// In en, this message translates to:
  /// **'OpenCode returned no callable tools for this provider and model.'**
  String get e7LibraryOpenCodeReturnedNoCallableToolsForThis;

  /// Library and project tools UI: Try a tool ID or a word from its description.
  ///
  /// In en, this message translates to:
  /// **'Try a tool ID or a word from its description.'**
  String get e7LibraryTryAToolIDOrAWord;

  /// Library and project tools UI: Callable by this model
  ///
  /// In en, this message translates to:
  /// **'Callable by this model'**
  String get e7LibraryCallableByThisModel;

  /// Library and project tools UI: Registered, not callable
  ///
  /// In en, this message translates to:
  /// **'Registered, not callable'**
  String get e7LibraryRegisteredNotCallable;

  /// Library and project tools UI: No description returned by OpenCode
  ///
  /// In en, this message translates to:
  /// **'No description returned by OpenCode'**
  String get e7LibraryNoDescriptionReturnedByOpenCode;

  /// Library and project tools UI: Registered on this project but not returned for {detail1}/{detail2}.
  ///
  /// In en, this message translates to:
  /// **'Registered on this project but not returned for {detail1}/{detail2}.'**
  String e7LibraryRegisteredOnThisProjectButNotReturned(
    String detail1,
    String detail2,
  );

  /// Library and project tools UI: Copy parameter schema
  ///
  /// In en, this message translates to:
  /// **'Copy parameter schema'**
  String get e7LibraryCopyParameterSchema;

  /// Library and project tools UI: {detail1} schema copied
  ///
  /// In en, this message translates to:
  /// **'{detail1} schema copied'**
  String e7LibrarySchemaCopied(String detail1);

  /// Library and project tools UI: Parameter schema
  ///
  /// In en, this message translates to:
  /// **'Parameter schema'**
  String get e7LibraryParameterSchema;

  /// Library and project tools UI: No project selected
  ///
  /// In en, this message translates to:
  /// **'No project selected'**
  String get e7LibraryNoProjectSelected;

  /// Library and project tools UI: No project folder is open. Choose one from Workspace.
  ///
  /// In en, this message translates to:
  /// **'No project folder is open. Choose one from Work.'**
  String get e7LibraryNoProjectFolderIsOpenChooseOne;

  /// Library and project tools UI: Project
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get e7LibraryProject;

  /// Library and project tools UI: Switch project
  ///
  /// In en, this message translates to:
  /// **'Switch project'**
  String get e7LibrarySwitchProject;

  /// Library and project tools UI: Choose another project opened by this server
  ///
  /// In en, this message translates to:
  /// **'Choose another project opened by this server'**
  String get e7LibraryChooseAnotherProjectOpenedByThisServer;

  /// Library and project tools UI: Coding
  ///
  /// In en, this message translates to:
  /// **'Coding'**
  String get e7LibraryCoding;

  /// Library and project tools UI: Worktrees
  ///
  /// In en, this message translates to:
  /// **'Worktrees'**
  String get e7LibraryWorktrees;

  /// Library and project tools UI: Choose a project first
  ///
  /// In en, this message translates to:
  /// **'Choose a project first'**
  String get e7LibraryChooseAProjectFirst;

  /// Library and project tools UI: Create and manage isolated Git branches
  ///
  /// In en, this message translates to:
  /// **'Create and manage isolated Git branches'**
  String get e7LibraryCreateAndManageIsolatedGitBranches;

  /// Library and project tools UI: Managed workspaces
  ///
  /// In en, this message translates to:
  /// **'Cloud environments'**
  String get e7LibraryManagedWorkspaces;

  /// Library and project tools UI: Create, discover, open, and remove adapter-backed environments
  ///
  /// In en, this message translates to:
  /// **'Create, discover, open, and remove adapter-backed environments'**
  String get e7LibraryCreateDiscoverOpenAndRemoveAdapterBacked;

  /// Library and project tools UI: Project health
  ///
  /// In en, this message translates to:
  /// **'Project health'**
  String get e7LibraryProjectHealth;

  /// Library and project tools UI: Branch, changed files, language services, and formatters
  ///
  /// In en, this message translates to:
  /// **'Branch, changed files, language services, and formatters'**
  String get e7LibraryBranchChangedFilesLanguageServicesAndFormatters;

  /// Library and project tools UI: OpenCode is reconnecting.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is reconnecting.'**
  String get e7LibraryOpenCodeIsReconnecting;

  /// Library and project tools UI: Workspace discovery finished
  ///
  /// In en, this message translates to:
  /// **'Environment discovery finished'**
  String get e7LibraryWorkspaceDiscoveryFinished;

  /// Library and project tools UI: Could not discover workspaces: {detail1}
  ///
  /// In en, this message translates to:
  /// **'Could not discover environments: {detail1}'**
  String e7LibraryCouldNotDiscoverWorkspaces(String detail1);

  /// Library and project tools UI: Could not create workspace: {detail1}
  ///
  /// In en, this message translates to:
  /// **'Could not create environment: {detail1}'**
  String e7LibraryCouldNotCreateWorkspace(String detail1);

  /// Library and project tools UI: {detail1} was removed
  ///
  /// In en, this message translates to:
  /// **'{detail1} was deleted'**
  String e7LibraryWasRemoved(String detail1);

  /// Library and project tools UI: Could not remove workspace: {detail1}
  ///
  /// In en, this message translates to:
  /// **'Could not delete environment: {detail1}'**
  String e7LibraryCouldNotRemoveWorkspace(String detail1);

  /// Library and project tools UI: Cloud environments
  ///
  /// In en, this message translates to:
  /// **'Cloud environments'**
  String get e7LibraryCloudEnvironments;

  /// Library and project tools UI: Discover existing environments
  ///
  /// In en, this message translates to:
  /// **'Discover existing environments'**
  String get e7LibraryDiscoverExistingEnvironments;

  /// Library and project tools UI: Refresh cloud environments
  ///
  /// In en, this message translates to:
  /// **'Refresh cloud environments'**
  String get e7LibraryRefreshCloudEnvironments;

  /// Library and project tools UI: New environment
  ///
  /// In en, this message translates to:
  /// **'New environment'**
  String get e7LibraryNewEnvironment;

  /// Library and project tools UI: Environments
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get e7LibraryEnvironments;

  /// Library and project tools UI: No cloud environments
  ///
  /// In en, this message translates to:
  /// **'No cloud environments'**
  String get e7LibraryNoCloudEnvironments;

  /// Library and project tools UI: Adapter-backed environments for {detail1} appear here. Create one from a server adapter, or use Discover to register environments the adapter already knows.
  ///
  /// In en, this message translates to:
  /// **'Adapter-backed environments for {detail1} appear here. Create one from a server adapter, or use Discover to register environments the adapter already knows.'**
  String e7LibraryAdapterBackedEnvironmentsForAppearHereCreate(String detail1);

  /// Library and project tools UI: Environment refresh failed
  ///
  /// In en, this message translates to:
  /// **'Environment refresh failed'**
  String get e7LibraryEnvironmentRefreshFailed;

  /// Library and project tools UI: Retry cloud environments
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get e7LibraryRetryCloudEnvironments;

  /// Library and project tools UI: Adapters
  ///
  /// In en, this message translates to:
  /// **'Adapters'**
  String get e7LibraryAdapters;

  /// Library and project tools UI: Adapters unavailable
  ///
  /// In en, this message translates to:
  /// **'Adapters unavailable'**
  String get e7LibraryAdaptersUnavailable;

  /// Library and project tools UI: Retry workspace adapters
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get e7LibraryRetryWorkspaceAdapters;

  /// Library and project tools UI: No workspace adapters
  ///
  /// In en, this message translates to:
  /// **'No environment adapters'**
  String get e7LibraryNoWorkspaceAdapters;

  /// Library and project tools UI: This OpenCode project does not expose managed workspace creation.
  ///
  /// In en, this message translates to:
  /// **'This OpenCode project does not expose cloud environment creation.'**
  String get e7LibraryThisOpenCodeProjectDoesNotExposeManaged;

  /// Library and project tools UI: Adapter refresh failed
  ///
  /// In en, this message translates to:
  /// **'Adapter refresh failed'**
  String get e7LibraryAdapterRefreshFailed;

  /// Library and project tools UI: Connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get e7LibraryConnected;

  /// Library and project tools UI: Connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get e7LibraryConnecting;

  /// Library and project tools UI: Disconnected
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get e7LibraryDisconnected;

  /// Library and project tools UI: Environment actions
  ///
  /// In en, this message translates to:
  /// **'Environment actions'**
  String get e7LibraryEnvironmentActions;

  /// Library and project tools UI: Open again
  ///
  /// In en, this message translates to:
  /// **'Open again'**
  String get e7LibraryOpenAgain;

  /// Library and project tools UI: New managed workspace
  ///
  /// In en, this message translates to:
  /// **'New cloud environment'**
  String get e7LibraryNewManagedWorkspace;

  /// Library and project tools UI: Adapter
  ///
  /// In en, this message translates to:
  /// **'Adapter'**
  String get e7LibraryAdapter;

  /// Library and project tools UI: Branch (optional)
  ///
  /// In en, this message translates to:
  /// **'Branch (optional)'**
  String get e7LibraryBranchOptional;

  /// Library and project tools UI: Use the adapter default
  ///
  /// In en, this message translates to:
  /// **'Use the adapter default'**
  String get e7LibraryUseTheAdapterDefault;

  /// Library and project tools UI: OpenCode configures adapter-specific details on the server. The new workspace opens here after it is ready.
  ///
  /// In en, this message translates to:
  /// **'OpenCode configures adapter-specific details on the server. The new environment opens here after it is ready.'**
  String get e7LibraryOpenCodeConfiguresAdapterSpecificDetailsOnThe;

  /// Library and project tools UI: Create and open
  ///
  /// In en, this message translates to:
  /// **'Create and open'**
  String get e7LibraryCreateAndOpen;

  /// Library and project tools UI: Remove {detail1}?
  ///
  /// In en, this message translates to:
  /// **'Delete {detail1}?'**
  String e7LibraryRemove(String detail1);

  /// Library and project tools UI: The server adapter may permanently delete the remote environment or worktree. Existing chat history remains, but its workspace may no longer be reachable.
  ///
  /// In en, this message translates to:
  /// **'The server adapter may permanently delete the remote environment or worktree. Existing conversations remain in history, but the environment may no longer be reachable.'**
  String get e7LibraryTheServerAdapterMayPermanentlyDeleteThe;

  /// Library and project tools UI: Type {detail1} to confirm
  ///
  /// In en, this message translates to:
  /// **'Type {detail1} to confirm'**
  String e7LibraryTypeToConfirm(String detail1);

  /// Library and project tools UI: Remove permanently
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get e7LibraryRemovePermanently;

  /// Library and project tools UI: {detail1} is ready
  ///
  /// In en, this message translates to:
  /// **'{detail1} is ready'**
  String e7LibraryIsReady(String detail1);

  /// Library and project tools UI: OpenCode could not prepare this worktree.
  ///
  /// In en, this message translates to:
  /// **'OpenCode could not prepare this worktree.'**
  String get e7LibraryOpenCodeCouldNotPrepareThisWorktree;

  /// Library and project tools UI: {detail1} was created. Its setup status is not yet confirmed.
  ///
  /// In en, this message translates to:
  /// **'{detail1} was created. Its setup status is not yet confirmed.'**
  String e7LibraryWasCreatedItsSetupStatusIsNot(String detail1);

  /// Library and project tools UI: {detail1} created. OpenCode is preparing it.
  ///
  /// In en, this message translates to:
  /// **'{detail1} created. OpenCode is preparing it.'**
  String e7LibraryCreatedOpenCodeIsPreparingIt(String detail1);

  /// Library and project tools UI: Wait for OpenCode to finish preparing this worktree.
  ///
  /// In en, this message translates to:
  /// **'Wait for OpenCode to finish preparing this worktree.'**
  String get e7LibraryWaitForOpenCodeToFinishPreparingThis;

  /// Library and project tools UI: OpenCode did not switch locations.
  ///
  /// In en, this message translates to:
  /// **'OpenCode did not switch projects.'**
  String get e7LibraryOpenCodeDidNotSwitchLocations;

  /// Library and project tools UI: Could not verify {detail1} before this destructive action: {detail2}
  ///
  /// In en, this message translates to:
  /// **'Could not verify {detail1} before this destructive action: {detail2}'**
  String e7LibraryCouldNotVerifyBeforeThisDestructiveAction(
    String detail1,
    String detail2,
  );

  /// Library and project tools UI: {detail1} reset to the default branch
  ///
  /// In en, this message translates to:
  /// **'{detail1} reset to the default branch'**
  String e7LibraryResetToTheDefaultBranch(String detail1);

  /// Library and project tools UI: {detail1} and its branch were removed
  ///
  /// In en, this message translates to:
  /// **'{detail1} and its branch were deleted'**
  String e7LibraryAndItsBranchWereRemoved(String detail1);

  /// Library and project tools UI: Reset {detail1}?
  ///
  /// In en, this message translates to:
  /// **'Reset {detail1}?'**
  String e7LibraryReset(String detail1);

  /// Library and project tools UI: This permanently discards tracked changes and deletes all untracked and ignored files. Submodules are also reset and cleaned. This cannot be undone.
  ///
  /// In en, this message translates to:
  /// **'This permanently discards tracked changes and deletes all untracked and ignored files. Submodules are also reset and cleaned. This cannot be undone.'**
  String get e7LibraryThisPermanentlyDiscardsTrackedChangesAndDeletes;

  /// Library and project tools UI: Reset worktree
  ///
  /// In en, this message translates to:
  /// **'Reset worktree'**
  String get e7LibraryResetWorktree;

  /// Library and project tools UI: Refresh worktrees
  ///
  /// In en, this message translates to:
  /// **'Refresh worktrees'**
  String get e7LibraryRefreshWorktrees;

  /// Library and project tools UI: New worktree
  ///
  /// In en, this message translates to:
  /// **'New worktree'**
  String get e7LibraryNewWorktree;

  /// Library and project tools UI: Primary
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get e7LibraryPrimary;

  /// Library and project tools UI: No isolated worktrees yet
  ///
  /// In en, this message translates to:
  /// **'No isolated worktrees yet'**
  String get e7LibraryNoIsolatedWorktreesYet;

  /// Library and project tools UI: Use isolated branches for parallel coding without mixing changes. Create one when you want OpenCode to work on a separate branch.
  ///
  /// In en, this message translates to:
  /// **'Use isolated branches for parallel coding without mixing changes. Create one when you want OpenCode to work on a separate branch.'**
  String get e7LibraryUseIsolatedBranchesForParallelCodingWithout;

  /// Library and project tools UI: Default project · {detail1}
  ///
  /// In en, this message translates to:
  /// **'Default project · {detail1}'**
  String e7LibraryDefaultProject(String detail1);

  /// Library and project tools UI: Setup failed · {detail1}
  ///
  /// In en, this message translates to:
  /// **'Setup failed · {detail1}'**
  String e7LibrarySetupFailed(String detail1);

  /// Library and project tools UI: Preparing files and project tasks…
  ///
  /// In en, this message translates to:
  /// **'Preparing files and project tasks…'**
  String get e7LibraryPreparingFilesAndProjectTasks;

  /// Library and project tools UI: Worktree actions
  ///
  /// In en, this message translates to:
  /// **'Worktree actions'**
  String get e7LibraryWorktreeActions;

  /// Library and project tools UI: Reset
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get e7LibraryReset2;

  /// Library and project tools UI: No changed files were detected.
  ///
  /// In en, this message translates to:
  /// **'No changed files were detected.'**
  String get e7LibraryNoChangedFilesWereDetected;

  /// Library and project tools UI: OpenCode will create an isolated Git branch and working directory. Project startup tasks run automatically.
  ///
  /// In en, this message translates to:
  /// **'OpenCode will create an isolated Git branch and working directory. Project startup tasks run automatically.'**
  String get e7LibraryOpenCodeWillCreateAnIsolatedGitBranch;

  /// Library and project tools UI: Name (optional)
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get e7LibraryNameOptional;

  /// Library and project tools UI: OpenCode makes the name URL-safe and unique.
  ///
  /// In en, this message translates to:
  /// **'OpenCode makes the name URL-safe and unique.'**
  String get e7LibraryOpenCodeMakesTheNameURLSafeAnd;

  /// Library and project tools UI: The worktree directory and its Git branch will be permanently deleted. Existing chats remain in history, but their working directory will no longer exist.
  ///
  /// In en, this message translates to:
  /// **'The worktree directory and its Git branch will be permanently deleted. Existing conversations remain in history, but their working directory will no longer exist.'**
  String get e7LibraryTheWorktreeDirectoryAndItsGitBranch;

  /// Library and project tools UI: Initialize Git repository?
  ///
  /// In en, this message translates to:
  /// **'Initialize Git repository?'**
  String get e7LibraryInitializeGitRepository;

  /// Library and project tools UI: OpenCode will run git init in the current project. Existing files will not be changed or committed. This enables branch, working-tree, and Review features.
  ///
  /// In en, this message translates to:
  /// **'OpenCode will run git init in the current project. Existing files will not be changed or committed. This enables branch, working-tree, and Review features.'**
  String get e7LibraryOpenCodeWillRunGitInitInThe;

  /// Library and project tools UI: Initialize Git
  ///
  /// In en, this message translates to:
  /// **'Initialize Git'**
  String get e7LibraryInitializeGit;

  /// Library and project tools UI: Git repository initialized
  ///
  /// In en, this message translates to:
  /// **'Git repository initialized'**
  String get e7LibraryGitRepositoryInitialized;

  /// Library and project tools UI: Refresh project health
  ///
  /// In en, this message translates to:
  /// **'Refresh project health'**
  String get e7LibraryRefreshProjectHealth;

  /// Library and project tools UI: Version control
  ///
  /// In en, this message translates to:
  /// **'Version control'**
  String get e7LibraryVersionControl;

  /// Library and project tools UI: {detail1} changed
  ///
  /// In en, this message translates to:
  /// **'{detail1} changed'**
  String e7LibraryChanged(String detail1);

  /// Library and project tools UI: Language services
  ///
  /// In en, this message translates to:
  /// **'Language services'**
  String get e7LibraryLanguageServices;

  /// Library and project tools UI: Formatters
  ///
  /// In en, this message translates to:
  /// **'Formatters'**
  String get e7LibraryFormatters;

  /// Library and project tools UI: version control
  ///
  /// In en, this message translates to:
  /// **'version control'**
  String get e7LibraryVersionControl2;

  /// Library and project tools UI: Git is not initialized
  ///
  /// In en, this message translates to:
  /// **'Git is not initialized'**
  String get e7LibraryGitIsNotInitialized;

  /// Library and project tools UI: Initialize this project to enable branches, working-tree changes, and Review.
  ///
  /// In en, this message translates to:
  /// **'Initialize this project to enable branches, working-tree changes, and Review.'**
  String get e7LibraryInitializeThisProjectToEnableBranchesWorking;

  /// Library and project tools UI: Run `git init` from a terminal
  ///
  /// In en, this message translates to:
  /// **'Run `git init` from a terminal'**
  String get e7LibraryRunGitInitFromATerminal;

  /// Library and project tools UI: Git initialization failed
  ///
  /// In en, this message translates to:
  /// **'Git initialization failed'**
  String get e7LibraryGitInitializationFailed;

  /// Library and project tools UI: No active branch
  ///
  /// In en, this message translates to:
  /// **'No active branch'**
  String get e7LibraryNoActiveBranch;

  /// Library and project tools UI: Default branch: {detail1}
  ///
  /// In en, this message translates to:
  /// **'Default branch: {detail1}'**
  String e7LibraryDefaultBranch(String detail1);

  /// Library and project tools UI: Working tree is clean
  ///
  /// In en, this message translates to:
  /// **'Working tree is clean'**
  String get e7LibraryWorkingTreeIsClean;

  /// Library and project tools UI: {detail1} changed files
  ///
  /// In en, this message translates to:
  /// **'{detail1} changed files'**
  String e7LibraryChangedFiles(String detail1);

  /// Library and project tools UI: No uncommitted changes
  ///
  /// In en, this message translates to:
  /// **'No uncommitted changes'**
  String get e7LibraryNoUncommittedChanges;

  /// Library and project tools UI: language services
  ///
  /// In en, this message translates to:
  /// **'language services'**
  String get e7LibraryLanguageServices2;

  /// Library and project tools UI: No active language services
  ///
  /// In en, this message translates to:
  /// **'No active language services'**
  String get e7LibraryNoActiveLanguageServices;

  /// Library and project tools UI: OpenCode activates them while it inspects supported source files during coding.
  ///
  /// In en, this message translates to:
  /// **'OpenCode activates them while it inspects supported source files during coding.'**
  String get e7LibraryOpenCodeActivatesThemWhileItInspectsSupported;

  /// Library and project tools UI: No formatters configured
  ///
  /// In en, this message translates to:
  /// **'No formatters configured'**
  String get e7LibraryNoFormattersConfigured;

  /// Library and project tools UI: Enabled
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get e7LibraryEnabled;

  /// Library and project tools UI: Disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get e7LibraryDisabled;

  /// Library and project tools UI: Loading {detail1}
  ///
  /// In en, this message translates to:
  /// **'Loading {detail1}'**
  String e7LibraryLoading(String detail1);

  /// Library and project tools UI: Location changed.
  ///
  /// In en, this message translates to:
  /// **'Project changed.'**
  String get e7LibraryLocationChanged;

  /// Library and project tools UI: Authenticate from the server machine
  ///
  /// In en, this message translates to:
  /// **'Authenticate from the server machine'**
  String get e7LibraryAuthenticateFromTheServerMachine;

  /// Library and project tools UI: MCP authorization pending for {detail1}
  ///
  /// In en, this message translates to:
  /// **'MCP authorization pending for {detail1}'**
  String e7LibraryMCPAuthorizationPendingFor(String detail1);

  /// Library and project tools UI: Waiting for browser authorization
  ///
  /// In en, this message translates to:
  /// **'Waiting for browser authorization'**
  String get e7LibraryWaitingForBrowserAuthorization;

  /// Library and project tools UI: Automatic callback capture is unavailable. Paste the callback URL or authorization code.
  ///
  /// In en, this message translates to:
  /// **'Automatic callback capture is unavailable. Paste the callback URL or authorization code.'**
  String get e7LibraryAutomaticCallbackCaptureIsUnavailablePasteThe;

  /// Library and project tools UI: The phone is securely listening for this authorization callback. You can also enter it manually.
  ///
  /// In en, this message translates to:
  /// **'The phone is securely listening for this authorization callback. You can also enter it manually.'**
  String get e7LibraryThePhoneIsSecurelyListeningForThis;

  /// Library and project tools UI: Complete MCP authorization
  ///
  /// In en, this message translates to:
  /// **'Complete MCP authorization'**
  String get e7LibraryCompleteMCPAuthorization;

  /// Library and project tools UI: Callback URL or code
  ///
  /// In en, this message translates to:
  /// **'Callback URL or code'**
  String get e7LibraryCallbackURLOrCode;

  /// Library and project tools UI: Paste the complete callback URL when available so its security state can be verified.
  ///
  /// In en, this message translates to:
  /// **'Paste the complete callback URL when available so its security state can be verified.'**
  String get e7LibraryPasteTheCompleteCallbackURLWhenAvailable;

  /// Library and project tools UI: Complete
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get e7LibraryComplete;

  /// Library and project tools UI: Updating…
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get e7LibraryUpdating;

  /// Library and project tools UI: Not connected
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get e7LibraryNotConnected;

  /// Library and project tools UI: Disconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get e7LibraryDisconnect;

  /// Library and project tools UI: Server environment
  ///
  /// In en, this message translates to:
  /// **'Server environment'**
  String get e7LibraryServerEnvironment;

  /// Library and project tools UI: Server-managed
  ///
  /// In en, this message translates to:
  /// **'Server-managed'**
  String get e7LibraryServerManaged;

  /// Library and project tools UI: Connect
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get e7LibraryConnect;

  /// Library and project tools UI: Authentication failed
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get e7LibraryAuthenticationFailed;

  /// Library and project tools UI: Authentication attempt expired
  ///
  /// In en, this message translates to:
  /// **'Authentication attempt expired'**
  String get e7LibraryAuthenticationAttemptExpired;

  /// Library and project tools UI: Authentication complete
  ///
  /// In en, this message translates to:
  /// **'Authentication complete'**
  String get e7LibraryAuthenticationComplete;

  /// Library and project tools UI: Return from the browser and enter the authorization code.
  ///
  /// In en, this message translates to:
  /// **'Return from the browser and enter the authorization code.'**
  String get e7LibraryReturnFromTheBrowserAndEnterThe;

  /// Library and project tools UI: Finish authentication in the browser, then check its status.
  ///
  /// In en, this message translates to:
  /// **'Finish authentication in the browser, then check its status.'**
  String get e7LibraryFinishAuthenticationInTheBrowserThenCheck;

  /// Library and project tools UI: Finish
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get e7LibraryFinish;

  /// Library and project tools UI: Check
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get e7LibraryCheck;

  /// Library and project tools UI: Connecting {detail1}
  ///
  /// In en, this message translates to:
  /// **'Connecting {detail1}'**
  String e7LibraryConnecting2(String detail1);

  /// Library and project tools UI: Authentication options
  ///
  /// In en, this message translates to:
  /// **'Authentication options'**
  String get e7LibraryAuthenticationOptions;

  /// Library and project tools UI: Cancel attempt
  ///
  /// In en, this message translates to:
  /// **'Cancel attempt'**
  String get e7LibraryCancelAttempt;

  /// Library and project tools UI: Finish {detail1}
  ///
  /// In en, this message translates to:
  /// **'Finish {detail1}'**
  String e7LibraryFinish2(String detail1);

  /// Library and project tools UI: Authorization code
  ///
  /// In en, this message translates to:
  /// **'Authorization code'**
  String get e7LibraryAuthorizationCode;

  /// Library and project tools UI: Not yet
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get e7LibraryNotYet;

  /// Library and project tools UI: Select an option
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get e7LibrarySelectAnOption;

  /// Library and project tools UI: Enter a value
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get e7LibraryEnterAValue;

  /// Library and project tools UI: The server returned an unsafe authorization link. Only HTTPS links with a valid host and no embedded credentials are allowed.
  ///
  /// In en, this message translates to:
  /// **'The server returned an unsafe authorization link. Only HTTPS links with a valid host and no embedded credentials are allowed.'**
  String get e7LibraryTheServerReturnedAnUnsafeAuthorizationLink;

  /// Library and project tools UI: Could not load this section
  ///
  /// In en, this message translates to:
  /// **'Could not load this section'**
  String get e7LibraryCouldNotLoadThisSection;

  /// Library and project tools UI: {detail1} connected · {detail2} available
  ///
  /// In en, this message translates to:
  /// **'{detail1} connected · {detail2} available'**
  String e7LibraryConnectedAvailable(String detail1, String detail2);

  /// Library and project tools UI: Skills
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get e7LibrarySkills;

  /// Library and project tools UI: No skills available
  ///
  /// In en, this message translates to:
  /// **'No skills available'**
  String get e7LibraryNoSkillsAvailable;

  /// Library and project tools UI: Project and global OpenCode skills appear here.
  ///
  /// In en, this message translates to:
  /// **'Project and global OpenCode skills appear here.'**
  String get e7LibraryProjectAndGlobalOpenCodeSkillsAppearHere;

  /// Library and project tools UI: Deprecated
  ///
  /// In en, this message translates to:
  /// **'Deprecated'**
  String get e7LibraryDeprecated;

  /// Library and project tools UI: Preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get e7LibraryPreview;

  /// Library and project tools UI: Models and agents
  ///
  /// In en, this message translates to:
  /// **'Models and agents'**
  String get e7LibraryModelsAndAgents;

  /// Library and project tools UI: Unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get e7LibraryUnavailable;

  /// Library and project tools UI: Finish or cancel the current MCP authorization first.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the current MCP authorization first.'**
  String get e7LibraryFinishOrCancelTheCurrentMCPAuthorization;

  /// Library and project tools UI: Could not open the authorization page
  ///
  /// In en, this message translates to:
  /// **'Could not open the authorization page'**
  String get e7LibraryCouldNotOpenTheAuthorizationPage;

  /// Library and project tools UI: {detail1} authenticated
  ///
  /// In en, this message translates to:
  /// **'{detail1} authenticated'**
  String e7LibraryAuthenticated(String detail1);

  /// Library and project tools UI: Could not confirm MCP authentication
  ///
  /// In en, this message translates to:
  /// **'Could not confirm MCP authentication'**
  String get e7LibraryCouldNotConfirmMCPAuthentication;

  /// Library and project tools UI: MCP server saved in OpenCode
  ///
  /// In en, this message translates to:
  /// **'MCP server saved in OpenCode'**
  String get e7LibraryMCPServerSavedInOpenCode;

  /// Library and project tools UI: MCP unavailable
  ///
  /// In en, this message translates to:
  /// **'MCP unavailable'**
  String get e7LibraryMCPUnavailable;

  /// Library and project tools UI: MCP and integrations
  ///
  /// In en, this message translates to:
  /// **'MCP and integrations'**
  String get e7LibraryMCPAndIntegrations;

  /// Library and project tools UI: The model providers this OpenCode server can use. Connect one to start chatting.
  ///
  /// In en, this message translates to:
  /// **'The model providers this OpenCode server can use. Connect one to start chatting.'**
  String get e7LibraryTheModelProvidersThisOpenCodeServerCan;

  /// Library and project tools UI: Could not save sign-in recovery.
  ///
  /// In en, this message translates to:
  /// **'Could not save sign-in recovery.'**
  String get e7LibraryCouldNotSaveSignInRecovery;

  /// Library and project tools UI: Loading providers
  ///
  /// In en, this message translates to:
  /// **'Loading providers'**
  String get e7LibraryLoadingProviders;

  /// Library and project tools UI: No provider connections available
  ///
  /// In en, this message translates to:
  /// **'No provider connections available'**
  String get e7LibraryNoProviderConnectionsAvailable;

  /// Library and project tools UI: This server did not return any provider integrations.
  ///
  /// In en, this message translates to:
  /// **'This server did not return any provider integrations.'**
  String get e7LibraryThisServerDidNotReturnAnyProvider;

  /// Library and project tools UI: No providers match “{detail1}”
  ///
  /// In en, this message translates to:
  /// **'No providers match “{detail1}”'**
  String e7LibraryNoProvidersMatch(String detail1);

  /// Library and project tools UI: Try a provider name, its id, or one of its models.
  ///
  /// In en, this message translates to:
  /// **'Try a provider name, its id, or one of its models.'**
  String get e7LibraryTryAProviderNameItsIdOr;

  /// Library and project tools UI: Search providers or models
  ///
  /// In en, this message translates to:
  /// **'Search providers or models'**
  String get e7LibrarySearchProvidersOrModels;

  /// Library and project tools UI: Clear provider search
  ///
  /// In en, this message translates to:
  /// **'Clear provider search'**
  String get e7LibraryClearProviderSearch;

  /// Library and project tools UI:  SERVERS
  ///
  /// In en, this message translates to:
  /// **' SERVERS'**
  String get e7LibrarySERVERS;

  /// Library and project tools UI: Add-on servers that give the agent extra tools, like a browser or a database.
  ///
  /// In en, this message translates to:
  /// **'Add-on servers that give the agent extra tools, like a browser or a database.'**
  String get e7LibraryAddOnServersThatGiveTheAgent;

  /// Library and project tools UI: Loading MCP servers
  ///
  /// In en, this message translates to:
  /// **'Loading MCP servers'**
  String get e7LibraryLoadingMCPServers;

  /// Library and project tools UI: No MCP servers configured
  ///
  /// In en, this message translates to:
  /// **'No MCP servers configured'**
  String get e7LibraryNoMCPServersConfigured;

  /// Library and project tools UI: Save one for this project or every project on the server.
  ///
  /// In en, this message translates to:
  /// **'Save one for this project or every project on the server.'**
  String get e7LibrarySaveOneForThisProjectOrEvery;

  /// Library and project tools UI: Add an MCP server
  ///
  /// In en, this message translates to:
  /// **'Add an MCP server'**
  String get e7LibraryAddAnMCPServer;

  /// Library and project tools UI: Authorizing
  ///
  /// In en, this message translates to:
  /// **'Authorizing'**
  String get e7LibraryAuthorizing;

  /// Library and project tools UI: Resources
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get e7LibraryResources;

  /// Library and project tools UI: Files and data that connected MCP servers expose to the agent.
  ///
  /// In en, this message translates to:
  /// **'Files and data that connected MCP servers expose to the agent.'**
  String get e7LibraryFilesAndDataThatConnectedMCPServers;

  /// Library and project tools UI: Loading available resources
  ///
  /// In en, this message translates to:
  /// **'Loading available resources'**
  String get e7LibraryLoadingAvailableResources;

  /// Library and project tools UI: No resources available
  ///
  /// In en, this message translates to:
  /// **'No resources available'**
  String get e7LibraryNoResourcesAvailable;

  /// Library and project tools UI: Connected MCP servers have not exposed any resources.
  ///
  /// In en, this message translates to:
  /// **'Connected MCP servers have not exposed any resources.'**
  String get e7LibraryConnectedMCPServersHaveNotExposedAny;

  /// Library and project tools UI: Open authorization page?
  ///
  /// In en, this message translates to:
  /// **'Open authorization page?'**
  String get e7LibraryOpenAuthorizationPage;

  /// Library and project tools UI: You are leaving this app to authenticate in your browser.
  ///
  /// In en, this message translates to:
  /// **'You are leaving this app to authenticate in your browser.'**
  String get e7LibraryYouAreLeavingThisAppToAuthenticate;

  /// Library and project tools UI: Destination host
  ///
  /// In en, this message translates to:
  /// **'Destination host'**
  String get e7LibraryDestinationHost;

  /// Library and project tools UI: OpenCode instructions
  ///
  /// In en, this message translates to:
  /// **'OpenCode instructions'**
  String get e7LibraryOpenCodeInstructions;

  /// Library and project tools UI: Open browser
  ///
  /// In en, this message translates to:
  /// **'Open browser'**
  String get e7LibraryOpenBrowser;

  /// Library and project tools UI: Connected and tools are available
  ///
  /// In en, this message translates to:
  /// **'Connected and tools are available'**
  String get e7LibraryConnectedAndToolsAreAvailable;

  /// Library and project tools UI: Connection failed
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get e7LibraryConnectionFailed;

  /// Library and project tools UI: Authentication required
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get e7LibraryAuthenticationRequired;

  /// Library and project tools UI: Client registration required
  ///
  /// In en, this message translates to:
  /// **'Client registration required'**
  String get e7LibraryClientRegistrationRequired;

  /// Library and project tools UI: Authenticate
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get e7LibraryAuthenticate;

  /// Library and project tools UI: Stored credential: {detail1}
  ///
  /// In en, this message translates to:
  /// **'Stored credential: {detail1}'**
  String e7LibraryStoredCredential(String detail1);

  /// Library and project tools UI: Server environment: {detail1}
  ///
  /// In en, this message translates to:
  /// **'Server environment: {detail1}'**
  String e7LibraryServerEnvironment2(String detail1);

  /// Library and project tools UI: No connection methods available
  ///
  /// In en, this message translates to:
  /// **'No connection methods available'**
  String get e7LibraryNoConnectionMethodsAvailable;

  /// Library and project tools UI: Configured on the server
  ///
  /// In en, this message translates to:
  /// **'Configured on the server'**
  String get e7LibraryConfiguredOnTheServer;

  /// Library and project tools UI: Disconnect {detail1}?
  ///
  /// In en, this message translates to:
  /// **'Disconnect {detail1}?'**
  String e7LibraryDisconnect2(String detail1);

  /// Library and project tools UI: The stored credential will be removed from this OpenCode server. New prompts will stop using it after the provider runtime refreshes. An active response is not stopped.{detail1}
  ///
  /// In en, this message translates to:
  /// **'The stored credential will be removed from this OpenCode server. New prompts will stop using it after the provider runtime refreshes. An active response is not stopped.{detail1}'**
  String e7LibraryTheStoredCredentialWillBeRemovedFrom(String detail1);

  /// Library and project tools UI: Disconnect provider
  ///
  /// In en, this message translates to:
  /// **'Disconnect provider'**
  String get e7LibraryDisconnectProvider;

  /// Library and project tools UI: {detail1} credential removed; server environment remains active
  ///
  /// In en, this message translates to:
  /// **'{detail1} credential removed; server environment remains active'**
  String e7LibraryCredentialRemovedServerEnvironmentRemainsActive(
    String detail1,
  );

  /// Library and project tools UI: {detail1} disconnected
  ///
  /// In en, this message translates to:
  /// **'{detail1} disconnected'**
  String e7LibraryDisconnected2(String detail1);

  /// Library and project tools UI: Connect {detail1}
  ///
  /// In en, this message translates to:
  /// **'Connect {detail1}'**
  String e7LibraryConnect2(String detail1);

  /// Library and project tools UI: Authorization was not opened. The pending attempt is retained.
  ///
  /// In en, this message translates to:
  /// **'Authorization was not opened. The pending attempt is retained.'**
  String get e7LibraryAuthorizationWasNotOpenedThePendingAttempt;

  /// Library and project tools UI: Could not open OAuth
  ///
  /// In en, this message translates to:
  /// **'Could not open OAuth'**
  String get e7LibraryCouldNotOpenOAuth;

  /// Library and project tools UI: {detail1} is connected
  ///
  /// In en, this message translates to:
  /// **'{detail1} is connected'**
  String e7LibraryIsConnected(String detail1);

  /// Library and project tools UI: The sign-in source changed.
  ///
  /// In en, this message translates to:
  /// **'The sign-in source changed.'**
  String get e7LibraryTheSignInSourceChanged;

  /// Library and project tools UI: Could not confirm authentication. Return to the original source and try again.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm authentication. Return to the original source and try again.'**
  String get e7LibraryCouldNotConfirmAuthenticationReturnToThe;

  /// Library and project tools UI: Search server commands
  ///
  /// In en, this message translates to:
  /// **'Search server commands'**
  String get e7LibrarySearchServerCommands;

  /// Library and project tools UI: No server commands found
  ///
  /// In en, this message translates to:
  /// **'No server commands found'**
  String get e7LibraryNoServerCommandsFound;

  /// Library and project tools UI: Commands from your project and skills appear here.
  ///
  /// In en, this message translates to:
  /// **'Commands from your project and skills appear here.'**
  String get e7LibraryCommandsFromYourProjectAndSkillsAppear;

  /// Library and project tools UI: No description
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get e7LibraryNoDescription;

  /// Library and project tools UI: Server commands
  ///
  /// In en, this message translates to:
  /// **'Server commands'**
  String get e7LibraryServerCommands;

  /// Library and project tools UI: References
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get e7LibraryReferences;

  /// Library and project tools UI: No references configured
  ///
  /// In en, this message translates to:
  /// **'No references configured'**
  String get e7LibraryNoReferencesConfigured;

  /// Library and project tools UI: References attached to this project appear here.
  ///
  /// In en, this message translates to:
  /// **'References attached to this project appear here.'**
  String get e7LibraryReferencesAttachedToThisProjectAppearHere;

  /// Library and project tools UI: @{detail1} copied
  ///
  /// In en, this message translates to:
  /// **'@{detail1} copied'**
  String e7LibraryCopied(String detail1);

  /// Library and project tools confirmation or count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 grant} other{{count} grants}}'**
  String e7LibraryGrantCount(int count);

  /// Library and project tools confirmation or count.
  ///
  /// In en, this message translates to:
  /// **' · {count, plural, one{1 model} other{{count} models}}'**
  String e7LibraryModelCount(int count);

  /// Library and project tools confirmation or count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 changed file was detected.} other{{count} changed files were detected.}}'**
  String e7LibraryChangedFilesDetected(int count);

  /// Library and project tools confirmation or count.
  ///
  /// In en, this message translates to:
  /// **'This provider also uses the server environment, which mobile cannot remove and which will remain active.'**
  String get e7LibraryEnvironmentRemainsAfterDisconnect;

  /// Search aliases for the import destination; preserve English terms to allow either language.
  ///
  /// In en, this message translates to:
  /// **'backup restore transfer JSON conversation session chat'**
  String get e7LibrarySearchImportAliases;

  /// Search aliases for the shortcuts destination; preserve English terms to allow either language.
  ///
  /// In en, this message translates to:
  /// **'hotkeys help desktop'**
  String get e7LibrarySearchShortcutsAliases;

  /// Setup journey: api key hint.
  ///
  /// In en, this message translates to:
  /// **'Paste an API key'**
  String get e7SetupApiKeyHint;

  /// Setup journey: browser hint.
  ///
  /// In en, this message translates to:
  /// **'Opens a browser. If the redirect cannot reach OpenCode, paste the callback URL here.'**
  String get e7SetupBrowserHint;

  /// Setup journey: device code hint.
  ///
  /// In en, this message translates to:
  /// **'Uses a one-time code. Works from a phone.'**
  String get e7SetupDeviceCodeHint;

  /// Setup journey: account hint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your account'**
  String get e7SetupAccountHint;

  /// Setup journey: new terminal detail.
  ///
  /// In en, this message translates to:
  /// **'Start a shell in the active project.'**
  String get e7SetupNewTerminalDetail;

  /// Setup journey: show password.
  ///
  /// In en, this message translates to:
  /// **'Show server password'**
  String get e7SetupShowPassword;

  /// Setup journey: auth failed.
  ///
  /// In en, this message translates to:
  /// **'The server started but authentication failed.'**
  String get e7SetupAuthFailed;

  /// Setup journey: scan instruction.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code printed by opencode2 pair.'**
  String get e7SetupScanInstruction;

  /// Setup journey: right key.
  ///
  /// In en, this message translates to:
  /// **'Right arrow key'**
  String get e7SetupRightKey;

  /// Setup journey: restart reconnect failed.
  ///
  /// In en, this message translates to:
  /// **'The local server restarted, but the app could not reconnect.'**
  String get e7SetupRestartReconnectFailed;

  /// Setup journey: installing open code.
  ///
  /// In en, this message translates to:
  /// **'Installing OpenCode'**
  String get e7SetupInstallingOpenCode;

  /// Setup journey: no output.
  ///
  /// In en, this message translates to:
  /// **'No terminal output yet.'**
  String get e7SetupNoOutput;

  /// Setup journey: follow log.
  ///
  /// In en, this message translates to:
  /// **'Follow the server log'**
  String get e7SetupFollowLog;

  /// Setup journey: open setup guide.
  ///
  /// In en, this message translates to:
  /// **'Open the setup guide'**
  String get e7SetupOpenSetupGuide;

  /// Setup journey: scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get e7SetupScan;

  /// Setup journey: last output.
  ///
  /// In en, this message translates to:
  /// **'LAST OUTPUT'**
  String get e7SetupLastOutput;

  /// Setup journey: down key.
  ///
  /// In en, this message translates to:
  /// **'Down arrow key'**
  String get e7SetupDownKey;

  /// Setup journey: verify continue.
  ///
  /// In en, this message translates to:
  /// **'Verify & continue'**
  String get e7SetupVerifyContinue;

  /// Setup journey: accessible terminal.
  ///
  /// In en, this message translates to:
  /// **'Use accessible transcript and input'**
  String get e7SetupAccessibleTerminal;

  /// Setup journey: update open code.
  ///
  /// In en, this message translates to:
  /// **'Update OpenCode'**
  String get e7SetupUpdateOpenCode;

  /// Setup journey: camera failed detail.
  ///
  /// In en, this message translates to:
  /// **'Another app may be holding the camera. Pasting the pairing code works either way.'**
  String get e7SetupCameraFailedDetail;

  /// Setup journey: termux no answer.
  ///
  /// In en, this message translates to:
  /// **'Termux did not answer. Open Termux once, run the unlock line, then verify again.'**
  String get e7SetupTermuxNoAnswer;

  /// Setup journey: copy open termux.
  ///
  /// In en, this message translates to:
  /// **'Copy & open Termux'**
  String get e7SetupCopyOpenTermux;

  /// Setup journey: stop terminal detail.
  ///
  /// In en, this message translates to:
  /// **'The running process and its child processes will be terminated.'**
  String get e7SetupStopTerminalDetail;

  /// Setup journey: edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get e7SetupEdit;

  /// Setup journey: update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get e7SetupUpdate;

  /// Setup journey: server password.
  ///
  /// In en, this message translates to:
  /// **'Server password'**
  String get e7SetupServerPassword;

  /// Setup journey: https hint.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS for remote machines. HTTP is limited to localhost or 127.0.0.1.'**
  String get e7SetupHttpsHint;

  /// Setup journey: observed version save failed.
  ///
  /// In en, this message translates to:
  /// **'The local server is ready, but its observed version could not be saved. Refresh setup to try again.'**
  String get e7SetupObservedVersionSaveFailed;

  /// Setup journey: paste instead.
  ///
  /// In en, this message translates to:
  /// **'Paste it instead'**
  String get e7SetupPasteInstead;

  /// Setup journey: confirm update.
  ///
  /// In en, this message translates to:
  /// **'Update managed OpenCode?'**
  String get e7SetupConfirmUpdate;

  /// Setup journey: install service detail.
  ///
  /// In en, this message translates to:
  /// **'Official installer plus a systemd user service that survives closed terminals and reboots.'**
  String get e7SetupInstallServiceDetail;

  /// Setup journey: update host.
  ///
  /// In en, this message translates to:
  /// **'Update OpenCode on the host'**
  String get e7SetupUpdateHost;

  /// Setup journey: service status.
  ///
  /// In en, this message translates to:
  /// **'Service status'**
  String get e7SetupServiceStatus;

  /// Setup journey: keep after logout.
  ///
  /// In en, this message translates to:
  /// **'Keep it running after logout'**
  String get e7SetupKeepAfterLogout;

  /// Setup journey: get termux.
  ///
  /// In en, this message translates to:
  /// **'Get Termux'**
  String get e7SetupGetTermux;

  /// Setup journey: restart server.
  ///
  /// In en, this message translates to:
  /// **'Restart the server'**
  String get e7SetupRestartServer;

  /// Setup journey: resume setup.
  ///
  /// In en, this message translates to:
  /// **'Retry — resumes where setup left off'**
  String get e7SetupResumeSetup;

  /// Setup journey: hide password.
  ///
  /// In en, this message translates to:
  /// **'Hide server password'**
  String get e7SetupHidePassword;

  /// Setup journey: control keys.
  ///
  /// In en, this message translates to:
  /// **'Terminal control keys. Swipe horizontally for more.'**
  String get e7SetupControlKeys;

  /// Setup journey: setup failed.
  ///
  /// In en, this message translates to:
  /// **'Setup failed.'**
  String get e7SetupSetupFailed;

  /// Setup journey: end input key.
  ///
  /// In en, this message translates to:
  /// **'End of input, Control D'**
  String get e7SetupEndInputKey;

  /// Setup journey: guidance save failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save connection guidance. Retry saving.'**
  String get e7SetupGuidanceSaveFailed;

  /// Setup journey: server operation.
  ///
  /// In en, this message translates to:
  /// **'Server operation in progress'**
  String get e7SetupServerOperation;

  /// Setup journey: new terminal.
  ///
  /// In en, this message translates to:
  /// **'New terminal'**
  String get e7SetupNewTerminal;

  /// Setup journey: unsaved profile.
  ///
  /// In en, this message translates to:
  /// **'The server has not been saved.'**
  String get e7SetupUnsavedProfile;

  /// Setup journey: checking install.
  ///
  /// In en, this message translates to:
  /// **'Checking installed environment...'**
  String get e7SetupCheckingInstall;

  /// Setup journey: inspect termux failed.
  ///
  /// In en, this message translates to:
  /// **'Android could not inspect Termux.'**
  String get e7SetupInspectTermuxFailed;

  /// Setup journey: username.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get e7SetupUsername;

  /// Setup journey: first setup duration.
  ///
  /// In en, this message translates to:
  /// **'First-time setup can take 10–15 minutes. You can leave this screen and return; setup keeps running.'**
  String get e7SetupFirstSetupDuration;

  /// Setup journey: no terminals.
  ///
  /// In en, this message translates to:
  /// **'No terminal processes'**
  String get e7SetupNoTerminals;

  /// Setup journey: escape key.
  ///
  /// In en, this message translates to:
  /// **'Escape key'**
  String get e7SetupEscapeKey;

  /// Setup journey: left key.
  ///
  /// In en, this message translates to:
  /// **'Left arrow key'**
  String get e7SetupLeftKey;

  /// Setup journey: install service.
  ///
  /// In en, this message translates to:
  /// **'Install OpenCode as a background service'**
  String get e7SetupInstallService;

  /// Setup journey: paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get e7SetupPaused;

  /// Setup journey: save to finish.
  ///
  /// In en, this message translates to:
  /// **'Connected — save to finish.'**
  String get e7SetupSaveToFinish;

  /// Setup journey: password startup hint.
  ///
  /// In en, this message translates to:
  /// **'Printed by opencode2 serve at startup (\"server password …\"). Optional for servers without one.'**
  String get e7SetupPasswordStartupHint;

  /// Setup journey: install termux detail.
  ///
  /// In en, this message translates to:
  /// **'Install the current F-Droid build of Termux, then return here.'**
  String get e7SetupInstallTermuxDetail;

  /// Setup journey: stop before update.
  ///
  /// In en, this message translates to:
  /// **'Stop active generation before updating OpenCode.'**
  String get e7SetupStopBeforeUpdate;

  /// Setup journey: restarting local.
  ///
  /// In en, this message translates to:
  /// **'Restarting the local server'**
  String get e7SetupRestartingLocal;

  /// Setup journey: add server.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get e7SetupAddServer;

  /// Setup journey: step todo.
  ///
  /// In en, this message translates to:
  /// **'to do'**
  String get e7SetupStepTodo;

  /// Setup journey: interactive terminal.
  ///
  /// In en, this message translates to:
  /// **'Use interactive terminal'**
  String get e7SetupInteractiveTerminal;

  /// Setup journey: installing ubuntu.
  ///
  /// In en, this message translates to:
  /// **'Setting up Ubuntu'**
  String get e7SetupInstallingUbuntu;

  /// Setup journey: interrupt key.
  ///
  /// In en, this message translates to:
  /// **'Interrupt, Control C'**
  String get e7SetupInterruptKey;

  /// Setup journey: server url.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get e7SetupServerUrl;

  /// Setup journey: stop terminal.
  ///
  /// In en, this message translates to:
  /// **'Stop terminal?'**
  String get e7SetupStopTerminal;

  /// Setup journey: usb access.
  ///
  /// In en, this message translates to:
  /// **'Reach it from this phone over USB'**
  String get e7SetupUsbAccess;

  /// Setup journey: waiting termux.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Termux to respond. This can take a little while.'**
  String get e7SetupWaitingTermux;

  /// Setup journey: discard changes.
  ///
  /// In en, this message translates to:
  /// **'Discard server changes?'**
  String get e7SetupDiscardChanges;

  /// Setup journey: password required.
  ///
  /// In en, this message translates to:
  /// **'Password re-entry required'**
  String get e7SetupPasswordRequired;

  /// Setup journey: pairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing…'**
  String get e7SetupPairing;

  /// Setup journey: command input.
  ///
  /// In en, this message translates to:
  /// **'Terminal command input'**
  String get e7SetupCommandInput;

  /// Setup journey: camera failed.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be opened'**
  String get e7SetupCameraFailed;

  /// Setup journey: paste password.
  ///
  /// In en, this message translates to:
  /// **'Paste server password'**
  String get e7SetupPastePassword;

  /// Setup journey: saving local.
  ///
  /// In en, this message translates to:
  /// **'Saving local server settings'**
  String get e7SetupSavingLocal;

  /// Setup journey: copy failure report.
  ///
  /// In en, this message translates to:
  /// **'Copy failure report'**
  String get e7SetupCopyFailureReport;

  /// Setup journey: camera disabled.
  ///
  /// In en, this message translates to:
  /// **'Camera access is turned off'**
  String get e7SetupCameraDisabled;

  /// Setup journey: rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get e7SetupRename;

  /// Setup journey: paste pairing.
  ///
  /// In en, this message translates to:
  /// **'Paste pairing code'**
  String get e7SetupPastePairing;

  /// Setup journey: servers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get e7SetupServers;

  /// Setup journey: starting setup.
  ///
  /// In en, this message translates to:
  /// **'Starting setup in Termux'**
  String get e7SetupStartingSetup;

  /// Setup journey: setup not started.
  ///
  /// In en, this message translates to:
  /// **'Termux opened but the setup did not start. Retry once; if it happens again, copy the failure report.'**
  String get e7SetupSetupNotStarted;

  /// Setup journey: connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get e7SetupConnecting;

  /// Setup journey: this device.
  ///
  /// In en, this message translates to:
  /// **'This device (Termux)'**
  String get e7SetupThisDevice;

  /// Setup journey: transport reconnecting.
  ///
  /// In en, this message translates to:
  /// **'The server transport is reconnecting.'**
  String get e7SetupTransportReconnecting;

  /// Setup journey: step unavailable.
  ///
  /// In en, this message translates to:
  /// **'not yet available'**
  String get e7SetupStepUnavailable;

  /// Setup journey: update host detail.
  ///
  /// In en, this message translates to:
  /// **'When the server reports an update, Settings offers the native upgrade first; this is the host-side equivalent.'**
  String get e7SetupUpdateHostDetail;

  /// Setup journey: missing password short.
  ///
  /// In en, this message translates to:
  /// **'The saved password is unavailable. Enter it again, or leave it empty only if this server no longer requires one.'**
  String get e7SetupMissingPasswordShort;

  /// Setup journey: testing.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get e7SetupTesting;

  /// Setup journey: scan pairing.
  ///
  /// In en, this message translates to:
  /// **'Scan pairing code'**
  String get e7SetupScanPairing;

  /// Setup journey: restart unconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm this restart. Refresh its progress before retrying.'**
  String get e7SetupRestartUnconfirmed;

  /// Setup journey: existing missing credential.
  ///
  /// In en, this message translates to:
  /// **'A local server exists, but its saved credential is unavailable. Run setup again to replace it safely.'**
  String get e7SetupExistingMissingCredential;

  /// Setup journey: preparing models.
  ///
  /// In en, this message translates to:
  /// **'Getting models ready'**
  String get e7SetupPreparingModels;

  /// Setup journey: host instructions.
  ///
  /// In en, this message translates to:
  /// **'These commands run on the computer that hosts this server — the app cannot run them for you. Copy each one into a terminal on that machine.'**
  String get e7SetupHostInstructions;

  /// Setup journey: transcript.
  ///
  /// In en, this message translates to:
  /// **'Terminal transcript'**
  String get e7SetupTranscript;

  /// Setup journey: host first setup.
  ///
  /// In en, this message translates to:
  /// **'First-time setup — run on your computer'**
  String get e7SetupHostFirstSetup;

  /// Setup journey: no camera detail.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to scan with. Run opencode2 pair on the server, copy the code it prints, and paste it into the server editor.'**
  String get e7SetupNoCameraDetail;

  /// Setup journey: discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get e7SetupDiscard;

  /// Setup journey: connection closed.
  ///
  /// In en, this message translates to:
  /// **'Connection closed'**
  String get e7SetupConnectionClosed;

  /// Setup journey: not connected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get e7SetupNotConnected;

  /// Setup journey: token banner.
  ///
  /// In en, this message translates to:
  /// **'Connection token re-entry required for the active server. Edit the server and save its token before connecting.'**
  String get e7SetupTokenBanner;

  /// Setup journey: up key.
  ///
  /// In en, this message translates to:
  /// **'Up arrow key'**
  String get e7SetupUpKey;

  /// Setup journey: v1 limited.
  ///
  /// In en, this message translates to:
  /// **'This app targets OpenCode 2; some features are unavailable on v1 servers.'**
  String get e7SetupV1Limited;

  /// Setup journey: connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get e7SetupConnect;

  /// Setup journey: remove terminal detail.
  ///
  /// In en, this message translates to:
  /// **'This terminal record will be removed.'**
  String get e7SetupRemoveTerminalDetail;

  /// Setup journey: authentication.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTICATION'**
  String get e7SetupAuthentication;

  /// Setup journey: input disconnected.
  ///
  /// In en, this message translates to:
  /// **'Input is unavailable while disconnected.'**
  String get e7SetupInputDisconnected;

  /// Setup journey: host copied.
  ///
  /// In en, this message translates to:
  /// **'Copied. Run it on the server\'s computer.'**
  String get e7SetupHostCopied;

  /// Setup journey: camera privacy.
  ///
  /// In en, this message translates to:
  /// **'The camera is used only to read the QR that opencode2 pair prints, and only while this screen is open. You can paste the code instead — it does exactly the same thing.'**
  String get e7SetupCameraPrivacy;

  /// Setup journey: is v2.
  ///
  /// In en, this message translates to:
  /// **'This is an OpenCode 2 server.'**
  String get e7SetupIsV2;

  /// Setup journey: resume live.
  ///
  /// In en, this message translates to:
  /// **'Resume live view'**
  String get e7SetupResumeLive;

  /// Setup journey: tab key.
  ///
  /// In en, this message translates to:
  /// **'Tab key'**
  String get e7SetupTabKey;

  /// Setup journey: close scanner.
  ///
  /// In en, this message translates to:
  /// **'Close the scanner'**
  String get e7SetupCloseScanner;

  /// Setup journey: choose continue.
  ///
  /// In en, this message translates to:
  /// **'Choose how to continue'**
  String get e7SetupChooseContinue;

  /// Setup journey: termux outdated.
  ///
  /// In en, this message translates to:
  /// **'This version of Termux is too old for the app to control it. Install the current F-Droid or GitHub build of Termux, then check again.'**
  String get e7SetupTermuxOutdated;

  /// Setup journey: continue app.
  ///
  /// In en, this message translates to:
  /// **'Continue to app'**
  String get e7SetupContinueApp;

  /// Setup journey: camera needed.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan'**
  String get e7SetupCameraNeeded;

  /// Setup journey: terminal actions.
  ///
  /// In en, this message translates to:
  /// **'Terminal actions'**
  String get e7SetupTerminalActions;

  /// Setup journey: read password.
  ///
  /// In en, this message translates to:
  /// **'Read the server password for this app'**
  String get e7SetupReadPassword;

  /// Setup journey: start installed.
  ///
  /// In en, this message translates to:
  /// **'Start installed OpenCode?'**
  String get e7SetupStartInstalled;

  /// Setup journey: test connection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get e7SetupTestConnection;

  /// Setup journey: checking termux.
  ///
  /// In en, this message translates to:
  /// **'Checking Termux connection'**
  String get e7SetupCheckingTermux;

  /// Setup journey: checking termux short.
  ///
  /// In en, this message translates to:
  /// **'Checking Termux...'**
  String get e7SetupCheckingTermuxShort;

  /// Setup journey: default server.
  ///
  /// In en, this message translates to:
  /// **'OpenCode server'**
  String get e7SetupDefaultServer;

  /// Setup journey: saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get e7SetupSaving;

  /// Setup journey: not yet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get e7SetupNotYet;

  /// Setup journey: linux service.
  ///
  /// In en, this message translates to:
  /// **'Run as a Linux service'**
  String get e7SetupLinuxService;

  /// Setup journey: pairing desktop hint.
  ///
  /// In en, this message translates to:
  /// **'Check that the server is running, and that the address it printed is one this machine can reach.'**
  String get e7SetupPairingDesktopHint;

  /// Setup journey: about notices.
  ///
  /// In en, this message translates to:
  /// **'About and open source notices'**
  String get e7SetupAboutNotices;

  /// Setup journey: setup lost.
  ///
  /// In en, this message translates to:
  /// **'Lost track of the setup running in Termux'**
  String get e7SetupSetupLost;

  /// Setup journey: verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get e7SetupVerifying;

  /// Setup journey: report copied.
  ///
  /// In en, this message translates to:
  /// **'Failure report copied.'**
  String get e7SetupReportCopied;

  /// Setup journey: preparing setup.
  ///
  /// In en, this message translates to:
  /// **'Preparing setup'**
  String get e7SetupPreparingSetup;

  /// Setup journey: app settings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get e7SetupAppSettings;

  /// Setup journey: unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get e7SetupUnavailable;

  /// Setup journey: step done.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get e7SetupStepDone;

  /// Setup journey: no camera.
  ///
  /// In en, this message translates to:
  /// **'This device has no camera'**
  String get e7SetupNoCamera;

  /// Setup journey: server disconnected.
  ///
  /// In en, this message translates to:
  /// **'The server is not connected.'**
  String get e7SetupServerDisconnected;

  /// Setup journey: title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get e7SetupTitle;

  /// Setup journey: empty password hint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty only if this server no longer uses a password.'**
  String get e7SetupEmptyPasswordHint;

  /// Setup journey: android only.
  ///
  /// In en, this message translates to:
  /// **'Setup on this phone is Android only'**
  String get e7SetupAndroidOnly;

  /// Setup journey: edit server.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get e7SetupEditServer;

  /// Setup journey: reenter password.
  ///
  /// In en, this message translates to:
  /// **'Re-enter password'**
  String get e7SetupReenterPassword;

  /// Setup journey: missing credential.
  ///
  /// In en, this message translates to:
  /// **'The saved credential for this managed server is unavailable. Run setup again to replace it safely.'**
  String get e7SetupMissingCredential;

  /// Setup journey: reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get e7SetupReconnect;

  /// Setup journey: switch not started.
  ///
  /// In en, this message translates to:
  /// **'The runtime switch did not start.'**
  String get e7SetupSwitchNotStarted;

  /// Setup journey: no ubuntu.
  ///
  /// In en, this message translates to:
  /// **'No managed Ubuntu installation found.'**
  String get e7SetupNoUbuntu;

  /// Setup journey: key unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable while the terminal is disconnected'**
  String get e7SetupKeyUnavailable;

  /// Setup journey: copy terminal.
  ///
  /// In en, this message translates to:
  /// **'Copy terminal selection or transcript'**
  String get e7SetupCopyTerminal;

  /// Setup journey: command hint.
  ///
  /// In en, this message translates to:
  /// **'Type a command'**
  String get e7SetupCommandHint;

  /// Setup journey: check install failed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the installed environment.'**
  String get e7SetupCheckInstallFailed;

  /// Setup journey: live output.
  ///
  /// In en, this message translates to:
  /// **'LIVE OUTPUT'**
  String get e7SetupLiveOutput;

  /// Setup journey: connection failed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get e7SetupConnectionFailed;

  /// Setup journey: open app settings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get e7SetupOpenAppSettings;

  /// Setup journey: full walkthrough.
  ///
  /// In en, this message translates to:
  /// **'Full walkthrough (opens in browser)'**
  String get e7SetupFullWalkthrough;

  /// Setup journey: pairing phone hint.
  ///
  /// In en, this message translates to:
  /// **'A server bound to its own 127.0.0.1 is not reachable from this phone until you bridge it — `adb reverse tcp:PORT tcp:PORT` over USB, or an SSH forward. To reach it over the network instead, put it behind HTTPS.'**
  String get e7SetupPairingPhoneHint;

  /// Setup journey: output copied.
  ///
  /// In en, this message translates to:
  /// **'Setup output copied.'**
  String get e7SetupOutputCopied;

  /// Setup journey: missing password long.
  ///
  /// In en, this message translates to:
  /// **'The saved password is unavailable. Enter it again, or leave it empty only if this server no longer requires a password.'**
  String get e7SetupMissingPasswordLong;

  /// Setup journey: no server guide.
  ///
  /// In en, this message translates to:
  /// **'No server there yet? The setup guide shows how to start one.'**
  String get e7SetupNoServerGuide;

  /// Setup journey: exited.
  ///
  /// In en, this message translates to:
  /// **'Exited'**
  String get e7SetupExited;

  /// Setup journey: download page.
  ///
  /// In en, this message translates to:
  /// **'Download page'**
  String get e7SetupDownloadPage;

  /// Setup journey: starting local.
  ///
  /// In en, this message translates to:
  /// **'Starting local server'**
  String get e7SetupStartingLocal;

  /// Setup journey: terminal semantics.
  ///
  /// In en, this message translates to:
  /// **'Interactive terminal. Use the accessibility button for a readable transcript and labeled input.'**
  String get e7SetupTerminalSemantics;

  /// Setup journey: restarting local stage.
  ///
  /// In en, this message translates to:
  /// **'Restarting local server'**
  String get e7SetupRestartingLocalStage;

  /// Setup journey: password banner.
  ///
  /// In en, this message translates to:
  /// **'Password re-entry required for the active server. Edit the server and save its password before connecting.'**
  String get e7SetupPasswordBanner;

  /// Setup journey: empty pair clipboard.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty. Run `opencode2 pair` on the server and copy the code it prints.'**
  String get e7SetupEmptyPairClipboard;

  /// Setup journey: restart active changed.
  ///
  /// In en, this message translates to:
  /// **'The local server restarted, but the active server changed. Reconnect when you are ready.'**
  String get e7SetupRestartActiveChanged;

  /// Setup journey: token required.
  ///
  /// In en, this message translates to:
  /// **'Connection token re-entry required'**
  String get e7SetupTokenRequired;

  /// Setup journey: pairing instructions.
  ///
  /// In en, this message translates to:
  /// **'On your computer run `opencode2 pair`, then paste or scan the code it prints.'**
  String get e7SetupPairingInstructions;

  /// Setup journey: host daily.
  ///
  /// In en, this message translates to:
  /// **'Day-to-day — run on your computer'**
  String get e7SetupHostDaily;

  /// Setup journey: stop local.
  ///
  /// In en, this message translates to:
  /// **'Stop local server'**
  String get e7SetupStopLocal;

  /// Setup journey: reading progress.
  ///
  /// In en, this message translates to:
  /// **'Reading setup progress'**
  String get e7SetupReadingProgress;

  /// Setup journey: camera settings detail.
  ///
  /// In en, this message translates to:
  /// **'Android will not ask again, so this has to be changed in app settings: turn on Camera, then come back. Pasting the code needs no permission at all and works right now.'**
  String get e7SetupCameraSettingsDetail;

  /// Setup journey: verify termux failed.
  ///
  /// In en, this message translates to:
  /// **'Termux bridge verification failed.'**
  String get e7SetupVerifyTermuxFailed;

  /// Setup journey: start connect.
  ///
  /// In en, this message translates to:
  /// **'Start & connect'**
  String get e7SetupStartConnect;

  /// Setup journey: this server.
  ///
  /// In en, this message translates to:
  /// **'This server'**
  String get e7SetupThisServer;

  /// Setup journey: ubuntu only.
  ///
  /// In en, this message translates to:
  /// **'Ubuntu is installed. OpenCode is not installed yet.'**
  String get e7SetupUbuntuOnly;

  /// Setup journey: rename terminal.
  ///
  /// In en, this message translates to:
  /// **'Rename terminal'**
  String get e7SetupRenameTerminal;

  /// Setup journey: input unavailable.
  ///
  /// In en, this message translates to:
  /// **'Terminal input unavailable'**
  String get e7SetupInputUnavailable;

  /// Setup journey: update interruption.
  ///
  /// In en, this message translates to:
  /// **'The server will be briefly unavailable. Active generation should be stopped first.'**
  String get e7SetupUpdateInterruption;

  /// Setup journey: running on phone.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is running on this phone.'**
  String get e7SetupRunningOnPhone;

  /// Setup journey: local stopped.
  ///
  /// In en, this message translates to:
  /// **'The local server is stopped. Its installed files are kept.'**
  String get e7SetupLocalStopped;

  /// Setup journey: did not connect.
  ///
  /// In en, this message translates to:
  /// **'The server did not connect.'**
  String get e7SetupDidNotConnect;

  /// Setup journey: send command.
  ///
  /// In en, this message translates to:
  /// **'Send command to terminal'**
  String get e7SetupSendCommand;

  /// Setup journey: step running.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get e7SetupStepRunning;

  /// Setup journey: stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get e7SetupStopping;

  /// Setup journey: unsupported setup.
  ///
  /// In en, this message translates to:
  /// **'On-device setup requires Termux on Android. On this computer, run `opencode serve` and add its address.'**
  String get e7SetupUnsupportedSetup;

  /// Setup journey: send key.
  ///
  /// In en, this message translates to:
  /// **'Sends this key to the terminal'**
  String get e7SetupSendKey;

  /// Setup journey: remove terminal.
  ///
  /// In en, this message translates to:
  /// **'Remove terminal?'**
  String get e7SetupRemoveTerminal;

  /// Setup journey: step failed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get e7SetupStepFailed;

  /// Setup journey: terminal number.
  ///
  /// In en, this message translates to:
  /// **'Terminal {number}'**
  String e7SetupTerminalNumber(int number);

  /// Setup journey: process running.
  ///
  /// In en, this message translates to:
  /// **'{command} - PID {pid}'**
  String e7SetupProcessRunning(String command, int pid);

  /// Setup journey: process exited.
  ///
  /// In en, this message translates to:
  /// **'{command} - exited {code}'**
  String e7SetupProcessExited(String command, String code);

  /// Setup journey: connected pid.
  ///
  /// In en, this message translates to:
  /// **'Connected - PID {pid}'**
  String e7SetupConnectedPid(int pid);

  /// Setup journey: terminal status.
  ///
  /// In en, this message translates to:
  /// **'Terminal status: {status}'**
  String e7SetupTerminalStatus(String status);

  /// Setup journey: server version.
  ///
  /// In en, this message translates to:
  /// **'Server version {version}'**
  String e7SetupServerVersion(String version);

  /// Setup journey: copy command label.
  ///
  /// In en, this message translates to:
  /// **'Copy command: {label}'**
  String e7SetupCopyCommandLabel(String label);

  /// Setup journey: connect failed detail.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {name}. {detail} Check the server address and credentials, then try again.'**
  String e7SetupConnectFailedDetail(String name, String detail);

  /// Setup journey: saved connect failed.
  ///
  /// In en, this message translates to:
  /// **'{name} was saved, but it could not connect. Check the server address and credentials, then try again. ({detail})'**
  String e7SetupSavedConnectFailed(String name, String detail);

  /// Setup journey: save failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save {name}. The existing server was left unchanged. Check device storage and try again. ({detail})'**
  String e7SetupSaveFailed(String name, String detail);

  /// Setup journey: remove server.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String e7SetupRemoveServer(String name);

  /// Setup journey: removed disconnect failed.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed, but its connection could not be closed cleanly. Restart the app before connecting elsewhere. ({detail})'**
  String e7SetupRemovedDisconnectFailed(String name, String detail);

  /// Setup journey: remove failed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove {name}. The saved server and current connection were kept. Check device storage and try again. ({detail})'**
  String e7SetupRemoveFailed(String name, String detail);

  /// Setup journey: paired choice.
  ///
  /// In en, this message translates to:
  /// **'Paired with {host} — chosen from {count} addresses in the code.'**
  String e7SetupPairedChoice(String host, int count);

  /// Setup journey: paired.
  ///
  /// In en, this message translates to:
  /// **'Paired with {host}.'**
  String e7SetupPaired(String host);

  /// Setup journey: start failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save or start the local setup: {detail}'**
  String e7SetupStartFailed(String detail);

  /// Setup journey: installed version.
  ///
  /// In en, this message translates to:
  /// **'Installed version: {version}.'**
  String e7SetupInstalledVersion(String version);

  /// Setup journey: restart failed.
  ///
  /// In en, this message translates to:
  /// **'Could not restart the local server: {detail}'**
  String e7SetupRestartFailed(String detail);

  /// Setup journey: stop failed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop the local server: {detail}'**
  String e7SetupStopFailed(String detail);

  /// Setup journey: stop disconnect failed.
  ///
  /// In en, this message translates to:
  /// **'The server stopped, but the app could not disconnect: {detail}'**
  String e7SetupStopDisconnectFailed(String detail);

  /// Setup journey: version address.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {address}'**
  String e7SetupVersionAddress(String version, String address);

  /// Setup journey: version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String e7SetupVersion(String version);

  /// Setup journey: start installed detail.
  ///
  /// In en, this message translates to:
  /// **'Start OpenCode {version} using the existing installation and connect to it. Only this app’s local server restarts; no packages are downloaded or updated.'**
  String e7SetupStartInstalledDetail(String version);

  /// Setup journey: found installed.
  ///
  /// In en, this message translates to:
  /// **'Found OpenCode {version} in Ubuntu'**
  String e7SetupFoundInstalled(String version);

  /// Setup journey: elapsed seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s elapsed'**
  String e7SetupElapsedSeconds(int seconds);

  /// Setup journey: elapsed minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s elapsed'**
  String e7SetupElapsedMinutes(int minutes, int seconds);

  /// Setup journey: step semantics.
  ///
  /// In en, this message translates to:
  /// **'Step {number} of 3, {state}. {title}'**
  String e7SetupStepSemantics(int number, String state, String title);

  /// Setup journey: delete disclosure.
  ///
  /// In en, this message translates to:
  /// **'This deletes everything this device stored for the server: its password, selected model and agent, project choice, and any conversations shown in the home-screen widget.\n\n{queued, plural, =0{} =1{1 queued prompt will be deleted.} other{{queued} queued prompts will be deleted.}} {drafts, plural, =0{} =1{1 unsent draft will be deleted.} other{{drafts} unsent drafts will be deleted.}}\n\nNothing is deleted on the server itself or at your AI providers.'**
  String e7SetupDeleteDisclosure(int queued, int drafts);

  /// Setup journey: pairing failed.
  ///
  /// In en, this message translates to:
  /// **'No address in that pairing code answered:\n{detail}\n{hint}'**
  String e7SetupPairingFailed(String detail, String hint);

  /// Setup journey: probe v2.
  ///
  /// In en, this message translates to:
  /// **'OpenCode 2 · {version}'**
  String e7SetupProbeV2(String version);

  /// Setup journey: probe v1.
  ///
  /// In en, this message translates to:
  /// **'OpenCode 1 · {version} — limited feature set'**
  String e7SetupProbeV1(String version);

  /// Setup journey: pair none.
  ///
  /// In en, this message translates to:
  /// **'There is no pairing code here. Run `opencode2 pair` on the server and scan or copy what it prints.'**
  String get e7SetupPairNone;

  /// Setup journey: pair long.
  ///
  /// In en, this message translates to:
  /// **'That is far too long to be a pairing code. Copy only the line `opencode2 pair` prints, or scan its QR code.'**
  String get e7SetupPairLong;

  /// Setup journey: pair invalid.
  ///
  /// In en, this message translates to:
  /// **'That is not a pairing code. Run `opencode2 pair` on the server and scan or copy what it prints.'**
  String get e7SetupPairInvalid;

  /// Setup journey: pair shape.
  ///
  /// In en, this message translates to:
  /// **'That pairing code is the wrong shape — it should be a JSON object with `urls`, `username`, and `password`.'**
  String get e7SetupPairShape;

  /// Setup journey: pair no urls.
  ///
  /// In en, this message translates to:
  /// **'That pairing code has no `urls` field, so there is no address to connect to.'**
  String get e7SetupPairNoUrls;

  /// Setup journey: pair urls type.
  ///
  /// In en, this message translates to:
  /// **'That pairing code\'s `urls` field is not a list of addresses.'**
  String get e7SetupPairUrlsType;

  /// Setup journey: pair too many.
  ///
  /// In en, this message translates to:
  /// **'That pairing code lists more addresses than this app will try. Bind the server to one interface and pair again.'**
  String get e7SetupPairTooMany;

  /// Setup journey: pair address type.
  ///
  /// In en, this message translates to:
  /// **'That pairing code lists an address that is not text.'**
  String get e7SetupPairAddressType;

  /// Setup journey: pair address long.
  ///
  /// In en, this message translates to:
  /// **'That pairing code lists an address far too long to be a server URL.'**
  String get e7SetupPairAddressLong;

  /// Setup journey: pair address missing.
  ///
  /// In en, this message translates to:
  /// **'That pairing code carries no server address. Check that the server is actually listening, then run `opencode2 pair` again.'**
  String get e7SetupPairAddressMissing;

  /// Setup journey: pair username type.
  ///
  /// In en, this message translates to:
  /// **'That pairing code\'s `username` field is not text.'**
  String get e7SetupPairUsernameType;

  /// Setup journey: pair password missing.
  ///
  /// In en, this message translates to:
  /// **'That pairing code has no `password` field. It may have been truncated — scan or copy the whole code.'**
  String get e7SetupPairPasswordMissing;

  /// Setup journey: pair password type.
  ///
  /// In en, this message translates to:
  /// **'That pairing code\'s `password` field is not text.'**
  String get e7SetupPairPasswordType;

  /// Setup journey: pair test failed.
  ///
  /// In en, this message translates to:
  /// **'The connection test failed before the server could be checked. Try another address.'**
  String get e7SetupPairTestFailed;

  /// Setup journey: not open code.
  ///
  /// In en, this message translates to:
  /// **'The address did not answer as an OpenCode server. Check the address and try again.'**
  String get e7SetupNotOpenCode;

  /// Setup journey: no server answer.
  ///
  /// In en, this message translates to:
  /// **'The server did not answer. Check that opencode serve is running on that address.'**
  String get e7SetupNoServerAnswer;

  /// Setup journey: pair password rejected.
  ///
  /// In en, this message translates to:
  /// **'Password rejected. Check the pairing code and try again.'**
  String get e7SetupPairPasswordRejected;

  /// Setup journey: pair address unusable.
  ///
  /// In en, this message translates to:
  /// **'That pairing code contains an unusable server address.'**
  String get e7SetupPairAddressUnusable;

  /// Setup journey: no answer.
  ///
  /// In en, this message translates to:
  /// **'Did not answer.'**
  String get e7SetupNoAnswer;

  /// Setup journey: invalid address.
  ///
  /// In en, this message translates to:
  /// **'<invalid address>'**
  String get e7SetupInvalidAddress;

  /// Setup journey: enter url.
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL.'**
  String get e7SetupEnterUrl;

  /// Setup journey: include scheme.
  ///
  /// In en, this message translates to:
  /// **'Include https://. Use http:// only for localhost, 127.0.0.1, or [::1].'**
  String get e7SetupIncludeScheme;

  /// Setup journey: complete url.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete server URL, such as https://server.example:4096.'**
  String get e7SetupCompleteUrl;

  /// Setup journey: url scheme.
  ///
  /// In en, this message translates to:
  /// **'Server URLs must use https://, or http:// for a local server.'**
  String get e7SetupUrlScheme;

  /// Setup journey: termux url scheme.
  ///
  /// In en, this message translates to:
  /// **'Server URLs must use https://, or http:// for local Termux.'**
  String get e7SetupTermuxUrlScheme;

  /// Setup journey: url credentials.
  ///
  /// In en, this message translates to:
  /// **'Do not put credentials in the URL. Use the fields below.'**
  String get e7SetupUrlCredentials;

  /// Setup journey: url query.
  ///
  /// In en, this message translates to:
  /// **'Remove query parameters and fragments from the server URL.'**
  String get e7SetupUrlQuery;

  /// Setup journey: url path.
  ///
  /// In en, this message translates to:
  /// **'Remove the path from the server URL. Enter only its origin.'**
  String get e7SetupUrlPath;

  /// Setup journey: require https.
  ///
  /// In en, this message translates to:
  /// **'HTTPS is required outside this device. Basic credentials must never be sent over HTTP.'**
  String get e7SetupRequireHttps;

  /// Setup journey: local http.
  ///
  /// In en, this message translates to:
  /// **'HTTP is allowed only for localhost, 127.0.0.1, or [::1]. Use HTTPS for LAN and remote servers.'**
  String get e7SetupLocalHttp;

  /// Setup journey: refused.
  ///
  /// In en, this message translates to:
  /// **'The connection was refused. Is opencode serve running on that host and port?'**
  String get e7SetupRefused;

  /// Setup journey: timeout.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Check the address, and that the server is reachable from this phone.'**
  String get e7SetupTimeout;

  /// Setup journey: dns.
  ///
  /// In en, this message translates to:
  /// **'That host name could not be found. Check the address spelling.'**
  String get e7SetupDns;

  /// Setup journey: certificate.
  ///
  /// In en, this message translates to:
  /// **'The server’s TLS certificate was rejected. Use a certificate this phone trusts.'**
  String get e7SetupCertificate;

  /// Setup journey: unhealthy.
  ///
  /// In en, this message translates to:
  /// **'The server responded but reported itself unhealthy. Check its logs, then try again.'**
  String get e7SetupUnhealthy;

  /// Setup journey: server starting.
  ///
  /// In en, this message translates to:
  /// **'The server is starting. Try again in a moment.'**
  String get e7SetupServerStarting;

  /// Setup journey: password needed.
  ///
  /// In en, this message translates to:
  /// **'This server requires its serve password.'**
  String get e7SetupPasswordNeeded;

  /// Setup journey: password rejected.
  ///
  /// In en, this message translates to:
  /// **'Password rejected. Copy the current \"server password\" line from the server output — it changes on every restart unless OPENCODE_PASSWORD is set.'**
  String get e7SetupPasswordRejected;

  /// Setup journey: credentials refused.
  ///
  /// In en, this message translates to:
  /// **'The server refused the credentials. Check the username and password.'**
  String get e7SetupCredentialsRefused;

  /// Setup journey: codex url.
  ///
  /// In en, this message translates to:
  /// **'Enter a Codex server URL.'**
  String get e7SetupCodexUrl;

  /// Setup journey: codex complete url.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete Codex server URL.'**
  String get e7SetupCodexCompleteUrl;

  /// Setup journey: codex scheme.
  ///
  /// In en, this message translates to:
  /// **'Codex server URLs must use wss://, or ws:// for a local server.'**
  String get e7SetupCodexScheme;

  /// Setup journey: codex credentials.
  ///
  /// In en, this message translates to:
  /// **'Do not put credentials in the Codex URL.'**
  String get e7SetupCodexCredentials;

  /// Setup journey: codex query.
  ///
  /// In en, this message translates to:
  /// **'Remove query parameters and fragments from the Codex URL.'**
  String get e7SetupCodexQuery;

  /// Setup journey: codex path.
  ///
  /// In en, this message translates to:
  /// **'Remove the path from the Codex server URL.'**
  String get e7SetupCodexPath;

  /// Setup journey: codex plain.
  ///
  /// In en, this message translates to:
  /// **'Plain WebSocket is allowed only for a local Codex server.'**
  String get e7SetupCodexPlain;

  /// Setup journey: codex directory.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute Codex project directory.'**
  String get e7SetupCodexDirectory;

  /// Setup journey: codex token.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Codex connection token.'**
  String get e7SetupCodexToken;

  /// Setup journey: refresh packages.
  ///
  /// In en, this message translates to:
  /// **'Refreshing Termux packages'**
  String get e7SetupRefreshPackages;

  /// Setup journey: repair packages.
  ///
  /// In en, this message translates to:
  /// **'Repairing the Termux package set'**
  String get e7SetupRepairPackages;

  /// Setup journey: install dependencies.
  ///
  /// In en, this message translates to:
  /// **'Installing Termux dependencies'**
  String get e7SetupInstallDependencies;

  /// Setup journey: prepare termux.
  ///
  /// In en, this message translates to:
  /// **'Preparing Termux'**
  String get e7SetupPrepareTermux;

  /// Setup journey: install ubuntu.
  ///
  /// In en, this message translates to:
  /// **'Installing Ubuntu environment'**
  String get e7SetupInstallUbuntu;

  /// Setup journey: refresh models.
  ///
  /// In en, this message translates to:
  /// **'Refreshing the OpenCode model catalog'**
  String get e7SetupRefreshModels;

  /// Setup journey: start local server.
  ///
  /// In en, this message translates to:
  /// **'Starting the local server'**
  String get e7SetupStartLocalServer;

  /// Setup journey: open code ready.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is ready'**
  String get e7SetupOpenCodeReady;

  /// Setup journey: prepare runtime.
  ///
  /// In en, this message translates to:
  /// **'Preparing the selected OpenCode runtime'**
  String get e7SetupPrepareRuntime;

  /// Setup journey: switch local.
  ///
  /// In en, this message translates to:
  /// **'Switching the managed local server'**
  String get e7SetupSwitchLocal;

  /// Setup journey: check restart.
  ///
  /// In en, this message translates to:
  /// **'Checking the local server before restart'**
  String get e7SetupCheckRestart;

  /// Setup journey: stopping local.
  ///
  /// In en, this message translates to:
  /// **'Stopping the local server'**
  String get e7SetupStoppingLocal;

  /// Setup journey: stopped local.
  ///
  /// In en, this message translates to:
  /// **'Local server stopped'**
  String get e7SetupStoppedLocal;

  /// Setup journey: unknown setup.
  ///
  /// In en, this message translates to:
  /// **'Unknown setup state'**
  String get e7SetupUnknownSetup;

  /// Setup journey: unexpected stop.
  ///
  /// In en, this message translates to:
  /// **'The local OpenCode server stopped unexpectedly'**
  String get e7SetupUnexpectedStop;

  /// Setup journey: setup interrupted.
  ///
  /// In en, this message translates to:
  /// **'Setup stopped unexpectedly; see live output for details'**
  String get e7SetupSetupInterrupted;

  /// Setup journey: recovery disabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic recovery disabled'**
  String get e7SetupRecoveryDisabled;

  /// Setup journey: recovery was disabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic recovery was disabled'**
  String get e7SetupRecoveryWasDisabled;

  /// Setup journey: port busy.
  ///
  /// In en, this message translates to:
  /// **'The local server port is still in use; no replacement was started'**
  String get e7SetupPortBusy;

  /// Setup journey: no return data.
  ///
  /// In en, this message translates to:
  /// **'This OpenCode 2 installation has no separate OpenCode 1 data to return to'**
  String get e7SetupNoReturnData;

  /// Setup journey: credential mismatch.
  ///
  /// In en, this message translates to:
  /// **'The saved server credential differs from this runtime; restore its original saved credential before returning'**
  String get e7SetupCredentialMismatch;

  /// Setup journey: ubuntu unavailable.
  ///
  /// In en, this message translates to:
  /// **'The managed Ubuntu environment is unavailable'**
  String get e7SetupUbuntuUnavailable;

  /// Setup journey: runtime unavailable.
  ///
  /// In en, this message translates to:
  /// **'The selected OpenCode command is unavailable'**
  String get e7SetupRuntimeUnavailable;

  /// Setup journey: identity mismatch.
  ///
  /// In en, this message translates to:
  /// **'The tracked process is not the managed OpenCode server'**
  String get e7SetupIdentityMismatch;

  /// Setup journey: password missing.
  ///
  /// In en, this message translates to:
  /// **'The local server password is missing'**
  String get e7SetupPasswordMissing;

  /// Setup journey: version missing.
  ///
  /// In en, this message translates to:
  /// **'OpenCode installed but did not report a version'**
  String get e7SetupVersionMissing;

  /// Setup journey: models refresh failed.
  ///
  /// In en, this message translates to:
  /// **'OpenCode updated, but its model catalog could not be refreshed'**
  String get e7SetupModelsRefreshFailed;

  /// Setup journey: startup exited.
  ///
  /// In en, this message translates to:
  /// **'OpenCode server exited during startup'**
  String get e7SetupStartupExited;

  /// Setup journey: readiness timeout.
  ///
  /// In en, this message translates to:
  /// **'OpenCode server did not become authenticated and ready within 30 seconds'**
  String get e7SetupReadinessTimeout;

  /// Setup journey: unreadable data.
  ///
  /// In en, this message translates to:
  /// **'The OpenCode 2 data location record is unreadable'**
  String get e7SetupUnreadableData;

  /// Setup journey: unreadable previous.
  ///
  /// In en, this message translates to:
  /// **'The previous runtime record is unreadable'**
  String get e7SetupUnreadablePrevious;

  /// Setup journey: read manager failed.
  ///
  /// In en, this message translates to:
  /// **'Could not read setup manager status'**
  String get e7SetupReadManagerFailed;

  /// Setup journey: missing manager.
  ///
  /// In en, this message translates to:
  /// **'Setup manager is missing'**
  String get e7SetupMissingManager;

  /// Setup journey: remove interrupted failed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the interrupted app-owned Ubuntu install'**
  String get e7SetupRemoveInterruptedFailed;

  /// Setup journey: check storage failed.
  ///
  /// In en, this message translates to:
  /// **'Could not check available storage before setup'**
  String get e7SetupCheckStorageFailed;

  /// Setup journey: read storage failed.
  ///
  /// In en, this message translates to:
  /// **'Could not read available storage before setup'**
  String get e7SetupReadStorageFailed;

  /// Setup journey: repository failed.
  ///
  /// In en, this message translates to:
  /// **'Could not select the official Termux package repository'**
  String get e7SetupRepositoryFailed;

  /// Setup journey: repository refresh failed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh packages.termux.dev; check the network and retry'**
  String get e7SetupRepositoryRefreshFailed;

  /// Setup journey: repair failed.
  ///
  /// In en, this message translates to:
  /// **'Could not repair the interrupted Termux package transaction'**
  String get e7SetupRepairFailed;

  /// Setup journey: upgrade failed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the safe Termux package upgrade'**
  String get e7SetupUpgradeFailed;

  /// Setup journey: dependencies failed.
  ///
  /// In en, this message translates to:
  /// **'Could not install the Termux dependencies'**
  String get e7SetupDependenciesFailed;

  /// Setup journey: dependencies unusable.
  ///
  /// In en, this message translates to:
  /// **'Termux dependencies are still unusable after the package repair'**
  String get e7SetupDependenciesUnusable;

  /// Setup journey: ubuntu unusable.
  ///
  /// In en, this message translates to:
  /// **'An existing Ubuntu container is not usable; setup will not delete it'**
  String get e7SetupUbuntuUnusable;

  /// Setup journey: extraction failed.
  ///
  /// In en, this message translates to:
  /// **'Ubuntu Base extraction did not create a usable container'**
  String get e7SetupExtractionFailed;

  /// Setup journey: lock failed.
  ///
  /// In en, this message translates to:
  /// **'Setup manager could not claim its launch lock'**
  String get e7SetupLockFailed;

  /// Setup journey: setup group failed.
  ///
  /// In en, this message translates to:
  /// **'Setup manager did not start in an isolated process group'**
  String get e7SetupSetupGroupFailed;

  /// Setup journey: switch group failed.
  ///
  /// In en, this message translates to:
  /// **'Switch manager did not start in an isolated process group'**
  String get e7SetupSwitchGroupFailed;

  /// Setup journey: server group failed.
  ///
  /// In en, this message translates to:
  /// **'Managed server did not start in an isolated process group'**
  String get e7SetupServerGroupFailed;

  /// Setup journey: record identity failed.
  ///
  /// In en, this message translates to:
  /// **'Could not record the managed server process identity'**
  String get e7SetupRecordIdentityFailed;

  /// Setup journey: ConnectingProfile.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}'**
  String e7SetupConnectingProfile(String name);

  /// Setup journey: ConnectingAttempt.
  ///
  /// In en, this message translates to:
  /// **'Connecting again (attempt {attempt})'**
  String e7SetupConnectingAttempt(int attempt);

  /// Setup journey: OpeningWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Opening your saved project.'**
  String get e7SetupOpeningWorkspace;

  /// Setup journey: WhatToCheck.
  ///
  /// In en, this message translates to:
  /// **'What to check'**
  String get e7SetupWhatToCheck;

  /// Setup journey: HideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get e7SetupHideDetails;

  /// Setup journey: Details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get e7SetupDetails;

  /// Setup journey: ChangeServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get e7SetupChangeServer;

  /// Setup journey: UpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get e7SetupUpdatePassword;

  /// Setup journey: LastSetupDetail.
  ///
  /// In en, this message translates to:
  /// **'Last setup output: {detail}'**
  String e7SetupLastSetupDetail(String detail);

  /// Setup journey: BridgeDetail.
  ///
  /// In en, this message translates to:
  /// **'Bridge detail: {detail}'**
  String e7SetupBridgeDetail(String detail);

  /// Setup journey: DiagnosticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics unavailable: {detail}'**
  String e7SetupDiagnosticsUnavailable(String detail);

  /// Setup journey: ProbeHttp.
  ///
  /// In en, this message translates to:
  /// **'The address responded, but not like an OpenCode server (HTTP {status}). Check that the URL points at opencode serve.'**
  String e7SetupProbeHttp(String status);

  /// Setup journey: ProbeError.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed: {detail}'**
  String e7SetupProbeError(String detail);

  /// Setup journey: ServerExit.
  ///
  /// In en, this message translates to:
  /// **'OpenCode server exited (code {code})'**
  String e7SetupServerExit(String code);

  /// Connection recovery action to inspect Termux.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get e7SetupCheckTermux;

  /// Localized manager or bridge status: CommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Termux command failed.'**
  String get e7SetupCommandFailed;

  /// Localized manager or bridge status: UnexpectedBridge.
  ///
  /// In en, this message translates to:
  /// **'Termux returned an unexpected bridge response.'**
  String get e7SetupUnexpectedBridge;

  /// Localized manager or bridge status: SetupQueued.
  ///
  /// In en, this message translates to:
  /// **'Setup queued'**
  String get e7SetupSetupQueued;

  /// Localized manager or bridge status: NoSetup.
  ///
  /// In en, this message translates to:
  /// **'No setup has been started'**
  String get e7SetupNoSetup;

  /// Localized manager or bridge status: ManagerMissingAfterLaunch.
  ///
  /// In en, this message translates to:
  /// **'Setup manager is missing after launch'**
  String get e7SetupManagerMissingAfterLaunch;

  /// Localized manager or bridge status: BootstrapCleared.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap state cleared'**
  String get e7SetupBootstrapCleared;

  /// Localized manager or bridge status: InstallingBeta.
  ///
  /// In en, this message translates to:
  /// **'Installing OpenCode 2 beta'**
  String get e7SetupInstallingBeta;

  /// Localized manager or bridge status: AuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get e7SetupAuthenticationFailed;

  /// Simplified on-device setup guidance.
  ///
  /// In en, this message translates to:
  /// **'Install {runtime} ({version}) on this phone using Ubuntu. The app manages this installation and reuses existing Ubuntu files.'**
  String e7SetupRuntimeInstallDetail(String runtime, String version);

  /// Simplified on-device setup guidance.
  ///
  /// In en, this message translates to:
  /// **'Replace OpenCode {installedVersion} with {targetVersion} and restart this app’s local server. Existing Ubuntu files are kept.'**
  String e7SetupReplaceDetail(String installedVersion, String targetVersion);

  /// Simplified on-device setup guidance.
  ///
  /// In en, this message translates to:
  /// **'The current installation could not be checked. Continuing may install or update OpenCode 1 on this phone. Existing Ubuntu files are kept. You can check again or connect by address instead.'**
  String get e7SetupUncheckedDetail;

  /// Displayed when a server did not report its version.
  ///
  /// In en, this message translates to:
  /// **'unknown version'**
  String get e7SetupUnknownVersion;

  /// Shared voice or model selection UI: e7ModelUiClose
  ///
  /// In en, this message translates to:
  /// **'Close model selector'**
  String get e7ModelUiClose;

  /// Shared voice or model selection UI: e7ModelUiClearSearch
  ///
  /// In en, this message translates to:
  /// **'Clear model search'**
  String get e7ModelUiClearSearch;

  /// Shared voice or model selection UI: e7ModelUiLoadFailed
  ///
  /// In en, this message translates to:
  /// **'Could not load models'**
  String get e7ModelUiLoadFailed;

  /// Shared voice or model selection UI: e7ModelUiRetry
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get e7ModelUiRetry;

  /// Shared voice or model selection UI: e7ModelUiBasicCatalog
  ///
  /// In en, this message translates to:
  /// **'This server returned a basic catalog. Capability and context details are unavailable.'**
  String get e7ModelUiBasicCatalog;

  /// Shared voice or model selection UI: e7ModelUiEditFilters
  ///
  /// In en, this message translates to:
  /// **'Edit model filters'**
  String get e7ModelUiEditFilters;

  /// Shared voice or model selection UI: e7ModelUiFilterModels
  ///
  /// In en, this message translates to:
  /// **'Filter models'**
  String get e7ModelUiFilterModels;

  /// Shared voice or model selection UI: e7ModelUiFiltered
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get e7ModelUiFiltered;

  /// Shared voice or model selection UI: e7ModelUiFilters
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get e7ModelUiFilters;

  /// Shared voice or model selection UI: e7ModelUiRefresh
  ///
  /// In en, this message translates to:
  /// **'Refresh models'**
  String get e7ModelUiRefresh;

  /// Shared voice or model selection UI: e7ModelUiAnyCapability
  ///
  /// In en, this message translates to:
  /// **'Any capability'**
  String get e7ModelUiAnyCapability;

  /// Shared voice or model selection UI: e7ModelUiFastModes
  ///
  /// In en, this message translates to:
  /// **'Fast modes'**
  String get e7ModelUiFastModes;

  /// Shared voice or model selection UI: e7ModelUiReasoning
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get e7ModelUiReasoning;

  /// Shared voice or model selection UI: e7ModelUiLargestContext
  ///
  /// In en, this message translates to:
  /// **'Largest context'**
  String get e7ModelUiLargestContext;

  /// Shared voice or model selection UI: e7ModelUiNoneAvailable
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get e7ModelUiNoneAvailable;

  /// Shared voice or model selection UI: e7ModelUiFavoritesEmpty
  ///
  /// In en, this message translates to:
  /// **'Keep your go-to models here'**
  String get e7ModelUiFavoritesEmpty;

  /// Shared voice or model selection UI: e7ModelUiRecentEmpty
  ///
  /// In en, this message translates to:
  /// **'Your next choice starts here'**
  String get e7ModelUiRecentEmpty;

  /// Shared voice or model selection UI: e7ModelUiNoMatches
  ///
  /// In en, this message translates to:
  /// **'No matching models'**
  String get e7ModelUiNoMatches;

  /// Shared voice or model selection UI: e7ModelUiConfigureProvider
  ///
  /// In en, this message translates to:
  /// **'Configure a provider on the OpenCode server, then refresh.'**
  String get e7ModelUiConfigureProvider;

  /// Shared voice or model selection UI: e7ModelUiFavoritesHint
  ///
  /// In en, this message translates to:
  /// **'Tap the star beside any model to find it here.'**
  String get e7ModelUiFavoritesHint;

  /// Shared voice or model selection UI: e7ModelUiRecentHint
  ///
  /// In en, this message translates to:
  /// **'Models you use will appear here, most recent first.'**
  String get e7ModelUiRecentHint;

  /// Shared voice or model selection UI: e7ModelUiNoFastModes
  ///
  /// In en, this message translates to:
  /// **'No model reports an explicit fast or low-effort mode.'**
  String get e7ModelUiNoFastModes;

  /// Shared voice or model selection UI: e7ModelUiNoMatchesHint
  ///
  /// In en, this message translates to:
  /// **'Try another search, provider, or capability filter.'**
  String get e7ModelUiNoMatchesHint;

  /// Shared voice or model selection UI: e7ModelUiClearFilters
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get e7ModelUiClearFilters;

  /// Shared voice or model selection UI: e7ModelUiBrowseAll
  ///
  /// In en, this message translates to:
  /// **'Browse all models'**
  String get e7ModelUiBrowseAll;

  /// Shared voice or model selection UI: e7ModelUiAgent
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get e7ModelUiAgent;

  /// Shared voice or model selection UI: e7ModelUiNoAgents
  ///
  /// In en, this message translates to:
  /// **'No agents available'**
  String get e7ModelUiNoAgents;

  /// Shared voice or model selection UI: e7ModelUiServerDefault
  ///
  /// In en, this message translates to:
  /// **'Server default'**
  String get e7ModelUiServerDefault;

  /// Shared voice or model selection UI: e7ModelUiProvider
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get e7ModelUiProvider;

  /// Shared voice or model selection UI: e7ModelUiAllProviders
  ///
  /// In en, this message translates to:
  /// **'All providers'**
  String get e7ModelUiAllProviders;

  /// Shared voice or model selection UI: e7ModelUiCurrent
  ///
  /// In en, this message translates to:
  /// **'Current model'**
  String get e7ModelUiCurrent;

  /// Shared voice or model selection UI: e7ModelUiUnavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get e7ModelUiUnavailable;

  /// Shared voice or model selection UI: e7ModelUiDeprecated
  ///
  /// In en, this message translates to:
  /// **'Deprecated'**
  String get e7ModelUiDeprecated;

  /// Shared voice or model selection UI: e7ModelUiPreview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get e7ModelUiPreview;

  /// Shared voice or model selection UI: e7ModelUiFavoritesFailed
  ///
  /// In en, this message translates to:
  /// **'Could not save favorites. Try again.'**
  String get e7ModelUiFavoritesFailed;

  /// Shared voice or model selection UI: e7ModelUiUseModelMode
  ///
  /// In en, this message translates to:
  /// **'Use model and mode'**
  String get e7ModelUiUseModelMode;

  /// Shared voice or model selection UI: e7ModelUiUseSession
  ///
  /// In en, this message translates to:
  /// **'Use for this conversation'**
  String get e7ModelUiUseSession;

  /// Shared voice or model selection UI: e7ModelUiUseNewSessions
  ///
  /// In en, this message translates to:
  /// **'Use for new conversations'**
  String get e7ModelUiUseNewSessions;

  /// Shared voice or model selection UI: e7ModelUiTools
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get e7ModelUiTools;

  /// Shared voice or model selection UI: e7ModelUiAttachments
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get e7ModelUiAttachments;

  /// Shared voice or model selection UI: e7ModelUiDefault
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get e7ModelUiDefault;

  /// Shared voice or model selection UI: e7ModelUiSelectionGone
  ///
  /// In en, this message translates to:
  /// **'This choice is no longer available. Refresh models and try again.'**
  String get e7ModelUiSelectionGone;

  /// Shared voice or model selection UI: e7VoiceUiLocalInput
  ///
  /// In en, this message translates to:
  /// **'Local voice input'**
  String get e7VoiceUiLocalInput;

  /// Shared voice or model selection UI: e7VoiceUiChooseModel
  ///
  /// In en, this message translates to:
  /// **'Choose a multilingual Whisper INT8 model'**
  String get e7VoiceUiChooseModel;

  /// Shared voice or model selection UI: e7VoiceUiPrivacyDownload
  ///
  /// In en, this message translates to:
  /// **'Audio stays on this device. Transcription is local and audio is discarded after use. The one-time model download requires internet access.'**
  String get e7VoiceUiPrivacyDownload;

  /// Shared voice or model selection UI: e7VoiceUiNoBuiltInMic
  ///
  /// In en, this message translates to:
  /// **'Android reports no built-in microphone. Voice input may still work with a wired or USB microphone.'**
  String get e7VoiceUiNoBuiltInMic;

  /// Shared voice or model selection UI: e7VoiceUiLanguage
  ///
  /// In en, this message translates to:
  /// **'Transcription language'**
  String get e7VoiceUiLanguage;

  /// Shared voice or model selection UI: e7VoiceUiVerifying
  ///
  /// In en, this message translates to:
  /// **'Verifying downloaded model'**
  String get e7VoiceUiVerifying;

  /// Shared voice or model selection UI: e7VoiceUiVerifyChecksum
  ///
  /// In en, this message translates to:
  /// **'Verifying size and SHA-256…'**
  String get e7VoiceUiVerifyChecksum;

  /// Shared voice or model selection UI: e7VoiceUiCancelDownload
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get e7VoiceUiCancelDownload;

  /// Shared voice or model selection UI: e7VoiceUiNotNow
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get e7VoiceUiNotNow;

  /// Shared voice or model selection UI: e7VoiceUiUseModel
  ///
  /// In en, this message translates to:
  /// **'Use model'**
  String get e7VoiceUiUseModel;

  /// Shared voice or model selection UI: e7VoiceUiDownload
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get e7VoiceUiDownload;

  /// Shared voice or model selection UI: e7VoiceUiKeep
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get e7VoiceUiKeep;

  /// Shared voice or model selection UI: e7VoiceUiDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get e7VoiceUiDelete;

  /// Shared voice or model selection UI: e7VoiceUiDefaultBadge
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get e7VoiceUiDefaultBadge;

  /// Shared voice or model selection UI: e7VoiceUiOptionalBadge
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get e7VoiceUiOptionalBadge;

  /// Shared voice or model selection UI: e7VoiceUiInstalledBadge
  ///
  /// In en, this message translates to:
  /// **'installed'**
  String get e7VoiceUiInstalledBadge;

  /// Shared voice or model selection UI: e7VoiceUiNotInstalledBadge
  ///
  /// In en, this message translates to:
  /// **'not installed'**
  String get e7VoiceUiNotInstalledBadge;

  /// Shared voice or model selection UI: e7VoiceUiSetupBusy
  ///
  /// In en, this message translates to:
  /// **'Unavailable while model setup is in progress'**
  String get e7VoiceUiSetupBusy;

  /// Shared voice or model selection UI: e7VoiceUiSelected
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get e7VoiceUiSelected;

  /// Shared voice or model selection UI: e7VoiceUiSelectHint
  ///
  /// In en, this message translates to:
  /// **'Double tap to select'**
  String get e7VoiceUiSelectHint;

  /// Shared voice or model selection UI: e7VoiceUiDefault
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get e7VoiceUiDefault;

  /// Shared voice or model selection UI: e7VoiceUiOptional
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get e7VoiceUiOptional;

  /// Shared voice or model selection UI: e7VoiceUiInstalled
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get e7VoiceUiInstalled;

  /// Shared voice or model selection UI: e7VoiceUiRedownload
  ///
  /// In en, this message translates to:
  /// **'Re-download'**
  String get e7VoiceUiRedownload;

  /// Shared voice or model selection UI: e7VoiceUiReviewTranscript
  ///
  /// In en, this message translates to:
  /// **'Review transcript'**
  String get e7VoiceUiReviewTranscript;

  /// Shared voice or model selection UI: e7VoiceUiOpenSettings
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get e7VoiceUiOpenSettings;

  /// Shared voice or model selection UI: e7VoiceUiRetry
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get e7VoiceUiRetry;

  /// Shared voice or model selection UI: e7VoiceUiStartListening
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get e7VoiceUiStartListening;

  /// Shared voice or model selection UI: e7VoiceUiCancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get e7VoiceUiCancel;

  /// Shared voice or model selection UI: e7VoiceUiInsert
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get e7VoiceUiInsert;

  /// Shared voice or model selection UI: e7VoiceUiInsertSend
  ///
  /// In en, this message translates to:
  /// **'Insert & send'**
  String get e7VoiceUiInsertSend;

  /// Shared voice or model selection UI: e7VoiceUiStartingMic
  ///
  /// In en, this message translates to:
  /// **'Starting microphone…'**
  String get e7VoiceUiStartingMic;

  /// Shared voice or model selection UI: e7VoiceUiLoadingModel
  ///
  /// In en, this message translates to:
  /// **'Loading local model…'**
  String get e7VoiceUiLoadingModel;

  /// Shared voice or model selection UI: e7VoiceUiTranscribing
  ///
  /// In en, this message translates to:
  /// **'Transcribing on this device…'**
  String get e7VoiceUiTranscribing;

  /// Shared voice or model selection UI: e7VoiceUiFinishingCancel
  ///
  /// In en, this message translates to:
  /// **'Finishing canceled transcription…'**
  String get e7VoiceUiFinishingCancel;

  /// Shared voice or model selection UI: e7VoiceUiDraftReady
  ///
  /// In en, this message translates to:
  /// **'Transcript ready to review'**
  String get e7VoiceUiDraftReady;

  /// Shared voice or model selection UI: e7VoiceUiNeedsAttention
  ///
  /// In en, this message translates to:
  /// **'Voice input needs attention'**
  String get e7VoiceUiNeedsAttention;

  /// Shared voice or model selection UI: e7VoiceUiReady
  ///
  /// In en, this message translates to:
  /// **'Ready for local voice input'**
  String get e7VoiceUiReady;

  /// Shared voice or model selection UI: e7VoiceUiModelRequired
  ///
  /// In en, this message translates to:
  /// **'A local model is required'**
  String get e7VoiceUiModelRequired;

  /// Shared voice or model selection UI: e7VoiceUiDownloading
  ///
  /// In en, this message translates to:
  /// **'Downloading voice model…'**
  String get e7VoiceUiDownloading;

  /// Shared voice or model selection UI: e7VoiceUiVerifyingModel
  ///
  /// In en, this message translates to:
  /// **'Verifying voice model…'**
  String get e7VoiceUiVerifyingModel;

  /// Shared voice or model selection UI: e7VoiceUiListeningHint
  ///
  /// In en, this message translates to:
  /// **'Listening. Double tap Stop recording when done.'**
  String get e7VoiceUiListeningHint;

  /// Shared voice or model selection UI: e7VoiceUiPrivacy
  ///
  /// In en, this message translates to:
  /// **'Audio stays on this device'**
  String get e7VoiceUiPrivacy;

  /// Shared voice or model selection UI: e7VoiceUiStopRecording
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get e7VoiceUiStopRecording;

  /// Shared voice or model selection UI: e7ModelUiCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 model} other{{count} models}}'**
  String e7ModelUiCount(int count);

  /// Shared voice or model selection UI: e7ModelUiContext
  ///
  /// In en, this message translates to:
  /// **'{count} context'**
  String e7ModelUiContext(String count);

  /// Shared voice or model selection UI: e7ModelUiOutput
  ///
  /// In en, this message translates to:
  /// **'{count} output'**
  String e7ModelUiOutput(String count);

  /// Shared voice or model selection UI: e7ModelUiFavorite
  ///
  /// In en, this message translates to:
  /// **'Favorite {model}'**
  String e7ModelUiFavorite(String model);

  /// Shared voice or model selection UI: e7ModelUiUnfavorite
  ///
  /// In en, this message translates to:
  /// **'Remove {model} from favorites'**
  String e7ModelUiUnfavorite(String model);

  /// Shared voice or model selection UI: e7ModelUiEffort
  ///
  /// In en, this message translates to:
  /// **'{variant} · {effort} effort'**
  String e7ModelUiEffort(String variant, String effort);

  /// Shared voice or model selection UI: e7ModelUiLoading
  ///
  /// In en, this message translates to:
  /// **'Loading model catalog'**
  String get e7ModelUiLoading;

  /// Shared voice or model selection UI: e7ModelUiCost
  ///
  /// In en, this message translates to:
  /// **'{input} in · {output} out /1M'**
  String e7ModelUiCost(String input, String output);

  /// Shared voice or model selection UI: e7VoiceUiDownloadPercent
  ///
  /// In en, this message translates to:
  /// **'Downloading voice model {percent} percent'**
  String e7VoiceUiDownloadPercent(int percent);

  /// Shared voice or model selection UI: e7VoiceUiDownloadProgress
  ///
  /// In en, this message translates to:
  /// **'{received} of {total}'**
  String e7VoiceUiDownloadProgress(String received, String total);

  /// Shared voice or model selection UI: e7VoiceUiSetupFailed
  ///
  /// In en, this message translates to:
  /// **'Model setup failed: {error}'**
  String e7VoiceUiSetupFailed(String error);

  /// Shared voice or model selection UI: e7VoiceUiDeletePack
  ///
  /// In en, this message translates to:
  /// **'Delete {model}?'**
  String e7VoiceUiDeletePack(String model);

  /// Shared voice or model selection UI: e7VoiceUiDeleteDetail
  ///
  /// In en, this message translates to:
  /// **'This removes {size} from app-private storage. You can download it again later.'**
  String e7VoiceUiDeleteDetail(String size);

  /// Shared voice or model selection UI: e7VoiceUiDownloadSize
  ///
  /// In en, this message translates to:
  /// **'{size} download'**
  String e7VoiceUiDownloadSize(String size);

  /// Shared voice or model selection UI: e7VoiceUiPackSemantics
  ///
  /// In en, this message translates to:
  /// **'{model}, {size}, {badges}. {description}'**
  String e7VoiceUiPackSemantics(
    String model,
    String size,
    String badges,
    String description,
  );

  /// Shared voice or model selection UI: e7VoiceUiListeningTime
  ///
  /// In en, this message translates to:
  /// **'Listening {elapsed} of {maximum}'**
  String e7VoiceUiListeningTime(String elapsed, String maximum);

  /// Shared voice or model selection UI: e7VoiceUiRecordingCap
  ///
  /// In en, this message translates to:
  /// **'Up to {seconds} s per recording'**
  String e7VoiceUiRecordingCap(int seconds);

  /// Shared voice or model selection UI: e7VoiceUiLicenses
  ///
  /// In en, this message translates to:
  /// **'Voice licenses and provenance'**
  String get e7VoiceUiLicenses;

  /// Shared voice or model selection UI: e7VoiceUiNoticesFailed
  ///
  /// In en, this message translates to:
  /// **'Could not load voice licenses. Try again.'**
  String get e7VoiceUiNoticesFailed;

  /// Voice/model presentation: e7VoiceUiAuto
  ///
  /// In en, this message translates to:
  /// **'Auto detect'**
  String get e7VoiceUiAuto;

  /// Voice/model presentation: e7VoiceUiEnglish
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get e7VoiceUiEnglish;

  /// Voice/model presentation: e7VoiceUiArabic
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get e7VoiceUiArabic;

  /// Voice/model presentation: e7VoiceUiBalanced
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get e7VoiceUiBalanced;

  /// Voice/model presentation: e7VoiceUiBalancedDetail
  ///
  /// In en, this message translates to:
  /// **'Recommended quality, storage, and speed tradeoff.'**
  String get e7VoiceUiBalancedDetail;

  /// Voice/model presentation: e7VoiceUiAccurate
  ///
  /// In en, this message translates to:
  /// **'High accuracy'**
  String get e7VoiceUiAccurate;

  /// Voice/model presentation: e7VoiceUiAccurateDetail
  ///
  /// In en, this message translates to:
  /// **'Optional best quality; requires substantially more memory.'**
  String get e7VoiceUiAccurateDetail;

  /// Voice/model presentation: e7VoiceUiCompact
  ///
  /// In en, this message translates to:
  /// **'Compact fallback'**
  String get e7VoiceUiCompact;

  /// Voice/model presentation: e7VoiceUiCompactDetail
  ///
  /// In en, this message translates to:
  /// **'Fastest and smallest; reduced accuracy in difficult audio.'**
  String get e7VoiceUiCompactDetail;

  /// Voice/model presentation: e7VoiceUiUnsupportedAbi
  ///
  /// In en, this message translates to:
  /// **'No bundled voice runtime supports this device ABI.'**
  String get e7VoiceUiUnsupportedAbi;

  /// Voice/model presentation: e7VoiceUiPermissionBlocked
  ///
  /// In en, this message translates to:
  /// **'Microphone access is blocked. Allow it in Android app settings.'**
  String get e7VoiceUiPermissionBlocked;

  /// Voice/model presentation: e7VoiceUiPermissionRequired
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for local voice input.'**
  String get e7VoiceUiPermissionRequired;

  /// Voice/model presentation: e7VoiceUiDeviceUnavailable
  ///
  /// In en, this message translates to:
  /// **'Local voice input is unavailable. Stop playback, check microphone settings, and try again.'**
  String get e7VoiceUiDeviceUnavailable;

  /// Voice/model presentation: e7VoiceUiInputUnavailable
  ///
  /// In en, this message translates to:
  /// **'Local voice input is unavailable on this platform.'**
  String get e7VoiceUiInputUnavailable;

  /// Voice/model presentation: e7VoiceUiNoAudio
  ///
  /// In en, this message translates to:
  /// **'No audio was captured.'**
  String get e7VoiceUiNoAudio;

  /// Voice/model presentation: e7VoiceUiInterrupted
  ///
  /// In en, this message translates to:
  /// **'Recording was interrupted.'**
  String get e7VoiceUiInterrupted;

  /// Voice/model presentation: e7VoiceUiMicrophoneError
  ///
  /// In en, this message translates to:
  /// **'The microphone reported an error. Check its settings and try again.'**
  String get e7VoiceUiMicrophoneError;

  /// Voice/model presentation: e7VoiceUiInputFailed
  ///
  /// In en, this message translates to:
  /// **'Voice input could not finish. Try again.'**
  String get e7VoiceUiInputFailed;

  /// Voice/model presentation: e7VoiceUiTechnicalDetails
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get e7VoiceUiTechnicalDetails;

  /// Voice/model presentation: e7VoiceUiHttpsRequired
  ///
  /// In en, this message translates to:
  /// **'Voice models may only be downloaded over HTTPS.'**
  String get e7VoiceUiHttpsRequired;

  /// Voice/model presentation: e7VoiceUiTransportClosed
  ///
  /// In en, this message translates to:
  /// **'Voice download transport is closed.'**
  String get e7VoiceUiTransportClosed;

  /// Voice/model presentation: e7VoiceUiInvalidRedirect
  ///
  /// In en, this message translates to:
  /// **'Voice model download returned an invalid redirect.'**
  String get e7VoiceUiInvalidRedirect;

  /// Voice/model presentation: e7VoiceUiUnsafeRedirect
  ///
  /// In en, this message translates to:
  /// **'Voice model download redirected to a non-HTTPS URL.'**
  String get e7VoiceUiUnsafeRedirect;

  /// Voice/model presentation: e7VoiceUiNoResponse
  ///
  /// In en, this message translates to:
  /// **'Model server returned no response.'**
  String get e7VoiceUiNoResponse;

  /// Voice/model presentation: e7VoiceUiDownloadTimeout
  ///
  /// In en, this message translates to:
  /// **'The model download timed out. Check the connection and try again.'**
  String get e7VoiceUiDownloadTimeout;

  /// Voice/model presentation: e7VoiceUiChecksumFailed
  ///
  /// In en, this message translates to:
  /// **'The downloaded model failed checksum verification. Re-download it.'**
  String get e7VoiceUiChecksumFailed;

  /// Voice/model presentation: e7VoiceUiVerificationFailed
  ///
  /// In en, this message translates to:
  /// **'The model failed final verification. Re-download it.'**
  String get e7VoiceUiVerificationFailed;

  /// Voice/model presentation: e7VoiceUiHttpFailed
  ///
  /// In en, this message translates to:
  /// **'The model server rejected the download. Try again.'**
  String get e7VoiceUiHttpFailed;

  /// Voice/model presentation: e7VoiceUiLengthFailed
  ///
  /// In en, this message translates to:
  /// **'The model download has an unexpected size. Re-download it.'**
  String get e7VoiceUiLengthFailed;

  /// Voice/model presentation: e7VoiceUiIncomplete
  ///
  /// In en, this message translates to:
  /// **'The model download is incomplete. Try again.'**
  String get e7VoiceUiIncomplete;

  /// Voice/model presentation: e7VoiceUiDownloadFailed
  ///
  /// In en, this message translates to:
  /// **'The voice model could not be downloaded. Try again.'**
  String get e7VoiceUiDownloadFailed;

  /// Voice/model presentation: e7VoiceUiMemory
  ///
  /// In en, this message translates to:
  /// **'{model} needs at least {required} MB of app memory; this device reports {available} MB.'**
  String e7VoiceUiMemory(String model, int required, int available);

  /// Voice/model presentation: e7VoiceUiStorage
  ///
  /// In en, this message translates to:
  /// **'{model} needs {size} free, including a safety margin.'**
  String e7VoiceUiStorage(String model, String size);

  /// Voice/model presentation: e7ModelUiProviderFallback
  ///
  /// In en, this message translates to:
  /// **'a provider'**
  String get e7ModelUiProviderFallback;

  /// Voice/model presentation: e7ModelUiProviderPair
  ///
  /// In en, this message translates to:
  /// **'{first} and {last}'**
  String e7ModelUiProviderPair(String first, String last);

  /// Voice/model presentation: e7ModelUiProviderMany
  ///
  /// In en, this message translates to:
  /// **'{first}, and {last}'**
  String e7ModelUiProviderMany(String first, String last);

  /// Voice/model presentation: e7ModelUiListSeparator
  ///
  /// In en, this message translates to:
  /// **', '**
  String get e7ModelUiListSeparator;

  /// Voice/model presentation: e7ModelUiUnloadedProviders
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{OpenCode is signed in to {providers} but has not loaded it yet, so its models fail with “Model not found”. Reload to pick up the sign-in.} other{OpenCode is signed in to {providers} but has not loaded them yet, so their models fail with “Model not found”. Reload to pick up the sign-in.}}'**
  String e7ModelUiUnloadedProviders(int count, String providers);

  /// Fallback product error when a platform exception carries no message.
  ///
  /// In en, this message translates to:
  /// **'This device reported an error ({code}).'**
  String e7SharedDeviceReportedError(String code);

  /// Generic connectivity failure line used for unknown errors.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is unreachable. Try again.'**
  String get e7SharedOpenCodeUnreachableTryAgain;

  /// Composer hint on OpenCode 1 while a run is active and text is typed: the send queues; steering is only available on OpenCode 2.
  ///
  /// In en, this message translates to:
  /// **'Sends after this run finishes. Steering mid-run needs OpenCode 2.'**
  String get chatUiQueueOnlySteeringNeedsOpenCode2;

  /// Session actions row that opens the per-session approval settings sheet
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvalsUiMenu;

  /// Title of the per-session approval settings sheet
  ///
  /// In en, this message translates to:
  /// **'Approvals for this conversation'**
  String get approvalsUiTitle;

  /// Default approval choice: every permission request waits for the user
  ///
  /// In en, this message translates to:
  /// **'Ask each time'**
  String get approvalsUiAskTitle;

  /// Explanation under the Ask each time choice
  ///
  /// In en, this message translates to:
  /// **'Every permission request waits for you.'**
  String get approvalsUiAskDetail;

  /// Approval choice: the app answers permission requests with Allow once as they arrive
  ///
  /// In en, this message translates to:
  /// **'Approve automatically while connected'**
  String get approvalsUiAutoTitle;

  /// Explanation under the automatic approval choice; Allow once is the existing permission button label
  ///
  /// In en, this message translates to:
  /// **'This phone answers each permission request with “Allow once” as it arrives. Nothing is saved as always allowed.'**
  String get approvalsUiAutoDetail;

  /// Switch: child (subagent) sessions follow this session's approval choice
  ///
  /// In en, this message translates to:
  /// **'Subagents inherit this'**
  String get approvalsUiInheritTitle;

  /// Explanation under the Subagents inherit switch while it is enabled
  ///
  /// In en, this message translates to:
  /// **'Subagent conversations started by this one follow the same choice unless they have their own.'**
  String get approvalsUiInheritDetail;

  /// Explanation under the disabled Subagents inherit switch while Ask each time is selected
  ///
  /// In en, this message translates to:
  /// **'Available once automatic approval is on.'**
  String get approvalsUiInheritUnavailable;

  /// Banner in the approvals sheet of a child session that follows its parent's choice
  ///
  /// In en, this message translates to:
  /// **'Inherited from parent conversation'**
  String get approvalsUiInheritedFrom;

  /// Explanation under the Inherited from parent session banner
  ///
  /// In en, this message translates to:
  /// **'This conversation follows its parent’s approvals. Override it to choose for this conversation only.'**
  String get approvalsUiInheritedDetail;

  /// Button that gives a child session its own approval choice instead of the parent's
  ///
  /// In en, this message translates to:
  /// **'Override for this conversation'**
  String get approvalsUiOverride;

  /// Button that removes a child session's own approval choice so it follows its parent again
  ///
  /// In en, this message translates to:
  /// **'Follow parent again'**
  String get approvalsUiFollowParent;

  /// Footnote in the approvals sheet about server rules, disconnects, and defaults
  ///
  /// In en, this message translates to:
  /// **'The server’s own deny rules still apply, and automatic approval stops whenever this app disconnects. New conversations always ask.'**
  String get approvalsUiServerRulesNote;

  /// Quiet in-chat indicator while automatic approval is on for this session
  ///
  /// In en, this message translates to:
  /// **'Approving automatically'**
  String get approvalsUiIndicatorOn;

  /// Record line for one permission the app approved automatically; action is the permission title such as Run a shell command
  ///
  /// In en, this message translates to:
  /// **'Auto-approved · {action}'**
  String approvalsUiAutoApproved(String action);

  /// Detail on a permission card whose automatic reply failed and now needs the user
  ///
  /// In en, this message translates to:
  /// **'Automatic approval failed. Review this request.'**
  String get approvalsUiFailedDetail;

  /// Snackbar when storing the per-session approval choice fails
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save the approval setting: {error}'**
  String approvalsUiSaveFailed(String error);

  /// Tooltip and accessibility label of the in-chat automatic approval indicator
  ///
  /// In en, this message translates to:
  /// **'Open approval settings'**
  String get approvalsUiOpenSettings;

  /// Quiet in-chat indicator while automatic approval is on but the app is disconnected; the next line says why
  ///
  /// In en, this message translates to:
  /// **'Auto-approval paused'**
  String get approvalsUiIndicatorPaused;

  /// Second line of the paused indicator
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get approvalsUiIndicatorPausedDetail;

  /// Heading of the list of permissions the app approved automatically in this session since connecting
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing approved automatically on this server yet} =1{1 request approved automatically on this server} other{{count} requests approved automatically on this server}}'**
  String approvalsUiRecordTitle(int count);

  /// Session menu row and sheet title: resume this session in a terminal on the computer that runs the server
  ///
  /// In en, this message translates to:
  /// **'Continue on computer'**
  String get handoffUiComputerTitle;

  /// Sheet lead paragraph. {binary} is the CLI program name (opencode or opencode2); do not translate it.
  ///
  /// In en, this message translates to:
  /// **'Run this in a terminal on the computer that runs this server. It opens the same conversation in the {binary} interface. Nothing is sent until you type.'**
  String handoffUiComputerIntro(String binary);

  /// Sheet note explaining the cd prefix of the command
  ///
  /// In en, this message translates to:
  /// **'Conversations belong to a project folder, so the command changes into this conversation’s folder first.'**
  String get handoffUiComputerDirectoryNote;

  /// Sheet footnote naming the CLI versions the command syntax was checked against. {verified} is a version list; {binary} is the CLI program name. Keep --help and --session verbatim.
  ///
  /// In en, this message translates to:
  /// **'Verified against {verified}. If your installed version differs, check {binary} --help for the --session flag.'**
  String handoffUiComputerVerify(String verified, String binary);

  /// Sheet state when the session has no directory and no command can be built
  ///
  /// In en, this message translates to:
  /// **'The server did not report a project folder for this conversation, so there is no folder to open it in. Reload the conversation and try again.'**
  String get handoffUiUnavailableDirectory;

  /// Sheet state for OpenCode 2 managed-workspace sessions
  ///
  /// In en, this message translates to:
  /// **'This conversation runs inside a cloud environment. Its folder belongs to the environment’s host, so a plain terminal command cannot open it. Export and import the conversation instead.'**
  String get handoffUiUnavailableWorkspace;

  /// Sheet state when the session id fails validation
  ///
  /// In en, this message translates to:
  /// **'This conversation’s reference cannot be placed in a command safely.'**
  String get handoffUiUnavailableReference;

  /// Sheet paragraph pointing at the existing export/import feature for cross-server moves
  ///
  /// In en, this message translates to:
  /// **'Moving to a different server? Export this conversation as a file and import it there. That carries the transcript itself, not just a pointer to it.'**
  String get handoffUiExportHint;

  /// Button in the handoff sheet that opens the existing session export screen
  ///
  /// In en, this message translates to:
  /// **'Export conversation'**
  String get handoffUiExportAction;

  /// Session menu row and sheet title: show a QR code that opens this session in the app on another phone
  ///
  /// In en, this message translates to:
  /// **'Open on another phone'**
  String get handoffUiPhoneTitle;

  /// QR sheet lead paragraph
  ///
  /// In en, this message translates to:
  /// **'Scan this with OpenCode Mobile on the other phone. The code carries only this saved server’s ID and the conversation ID: no messages, no address, no password. The other phone must already have this server saved.'**
  String get handoffUiPhoneIntro;

  /// Accessibility label for the QR image
  ///
  /// In en, this message translates to:
  /// **'QR code that opens this conversation on another phone'**
  String get handoffUiPhoneQrLabel;

  /// Caption above the plain-text link shown under the QR code
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get handoffUiPhoneLinkLabel;

  /// Tooltip/button copying the session link text
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get handoffUiPhoneCopyLink;

  /// Snackbar after the session link was copied
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get handoffUiPhoneLinkCopied;

  /// QR sheet state when the session or server reference fails validation
  ///
  /// In en, this message translates to:
  /// **'A link cannot be built for this conversation. Reload the conversation and try again.'**
  String get handoffUiPhoneUnavailable;

  /// Banner shown when a scanned session link names a server this phone does not have
  ///
  /// In en, this message translates to:
  /// **'This server is not saved on this phone. Add it under Servers, then scan the code again.'**
  String get handoffUiLinkServerMissing;

  /// Banner action opening the servers screen
  ///
  /// In en, this message translates to:
  /// **'Open Servers'**
  String get handoffUiLinkOpenServers;

  /// Banner action closing the notice without navigating
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get handoffUiLinkDismiss;

  /// Snackbar while a scanned link waits for the saved server to finish connecting
  ///
  /// In en, this message translates to:
  /// **'Opening the conversation once the server connects…'**
  String get handoffUiLinkWaiting;

  /// Snackbar when the linked server needs a credential re-entry before it can open the session
  ///
  /// In en, this message translates to:
  /// **'Enter this server’s password again, then scan the code again.'**
  String get handoffUiLinkReentry;

  /// Snackbar when connecting to the linked server failed
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the saved server. Check it under Servers, then scan the code again.'**
  String get handoffUiLinkConnectionFailed;

  /// Access value when the host front lets the phone answer and steer
  ///
  /// In en, this message translates to:
  /// **'Decisions and controls'**
  String get teamUiAccessControls;

  /// Access value when the phone can only watch the team
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get teamUiAccessReadOnly;

  /// Hint inside the host address field of the manual add form
  ///
  /// In en, this message translates to:
  /// **'http://100.x.x.x:8372'**
  String get teamUiAddAddressHint;

  /// Label of the host address field in the manual add form
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get teamUiAddAddressLabel;

  /// Label of the Gas City city field in the manual add form
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get teamUiAddCityLabel;

  /// Action opening the manual add form for an AI Team host
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get teamUiAddManually;

  /// Submit button of the manual add form: probes the address and turns the plugin on when found
  ///
  /// In en, this message translates to:
  /// **'Test and turn on'**
  String get teamUiAddSubmit;

  /// Progress line while the manual add form probes the host
  ///
  /// In en, this message translates to:
  /// **'Checking the address…'**
  String get teamUiAddTesting;

  /// Title of the manual add sheet
  ///
  /// In en, this message translates to:
  /// **'Add AI Team host'**
  String get teamUiAddTitle;

  /// Validation line when the address field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter the host address.'**
  String get teamUiAddressRequired;

  /// Action in the server editor replacing an already configured AI Team host
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get teamUiChange;

  /// Snackbar after a technical value was copied
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get teamUiCopied;

  /// Tooltip of the copy button next to a technical value
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get teamUiCopy;

  /// Performance disclaimer for a team hosted on a computer
  ///
  /// In en, this message translates to:
  /// **'Runs as fast as your computer; keep it awake'**
  String get teamUiDisclaimerComputer;

  /// Performance disclaimer for a team hosted on this phone
  ///
  /// In en, this message translates to:
  /// **'Android may stop it when the screen is off; slower than a computer'**
  String get teamUiDisclaimerPhone;

  /// Discovery card action that dismisses the offer for this server
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get teamUiDiscoveryNotNow;

  /// Discovery card headline when the server host answers on the AI Team port
  ///
  /// In en, this message translates to:
  /// **'{server} also runs an AI team. Turn it on?'**
  String teamUiDiscoveryTitle(String server);

  /// Discovery card action that turns the plugin on
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get teamUiDiscoveryTurnOn;

  /// One-line copy of the AI Team (optional) section in the server editor
  ///
  /// In en, this message translates to:
  /// **'If this computer runs Gas City, the app can find it automatically.'**
  String get teamUiEditorBody;

  /// Server editor line naming the configured AI Team host address
  ///
  /// In en, this message translates to:
  /// **'AI Team host: {url}'**
  String teamUiEditorConfigured(String url);

  /// Title of the AI Team section in the server editor
  ///
  /// In en, this message translates to:
  /// **'AI Team (optional)'**
  String get teamUiEditorTitle;

  /// Live-updates line when the event stream is closed
  ///
  /// In en, this message translates to:
  /// **'Event stream closed'**
  String get teamUiEventStreamClosed;

  /// Live-updates line while the event stream connects
  ///
  /// In en, this message translates to:
  /// **'Event stream connecting…'**
  String get teamUiEventStreamConnecting;

  /// Live-updates line with the last event sequence number
  ///
  /// In en, this message translates to:
  /// **'Event stream connected · seq {seq}'**
  String teamUiEventStreamLive(String seq);

  /// Live-updates line before any numbered event arrived
  ///
  /// In en, this message translates to:
  /// **'Event stream connected'**
  String get teamUiEventStreamLiveNoSeq;

  /// Live-updates line while the event stream reconnects
  ///
  /// In en, this message translates to:
  /// **'Event stream reconnecting…'**
  String get teamUiEventStreamReconnecting;

  /// One-line explanation of the host front shown under a read-only verdict
  ///
  /// In en, this message translates to:
  /// **'The front is a small helper on the computer that lets the phone answer and steer.'**
  String get teamUiFrontLine;

  /// Closing line of the host guide sheet pointing at the repository guide
  ///
  /// In en, this message translates to:
  /// **'The full guide with every command is docs/ai-team-host.md in the app\'s repository.'**
  String get teamUiHostGuideDocs;

  /// Intro line of the host guide sheet
  ///
  /// In en, this message translates to:
  /// **'Everything stays on your Tailscale network; nothing is published to the internet.'**
  String get teamUiHostGuideIntro;

  /// Host guide step 1
  ///
  /// In en, this message translates to:
  /// **'Install Gas City on the computer: gc, bd and dolt on your PATH.'**
  String get teamUiHostGuideStep1;

  /// Host guide step 2
  ///
  /// In en, this message translates to:
  /// **'Create a city next to your project and add the project to it: gc init, then gc rig add.'**
  String get teamUiHostGuideStep2;

  /// Host guide step 3
  ///
  /// In en, this message translates to:
  /// **'Start it with gc start and check that http://127.0.0.1:8372/v0/city/<name>/health answers.'**
  String get teamUiHostGuideStep3;

  /// Host guide step 4
  ///
  /// In en, this message translates to:
  /// **'Expose port 8372 on the computer\'s Tailscale address, then add it here as http://100.x.x.x:8372 with the city name.'**
  String get teamUiHostGuideStep4;

  /// Title of the host guide sheet
  ///
  /// In en, this message translates to:
  /// **'Run an AI team on your computer'**
  String get teamUiHostGuideTitle;

  /// Host mode value for a team running on a computer
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get teamUiHostModeComputer;

  /// Host mode value for a team running on this phone
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get teamUiHostModePhone;

  /// Short action opening the host guide from a verdict line
  ///
  /// In en, this message translates to:
  /// **'How'**
  String get teamUiHow;

  /// Cancel action of the turn-off sheet
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get teamUiKeep;

  /// Identity label: whether the phone can answer and steer
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get teamUiLabelAccess;

  /// Identity label: host base URL
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get teamUiLabelAddress;

  /// Identity label: Gas City city name
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get teamUiLabelCity;

  /// Identity label: where the team runs
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get teamUiLabelHost;

  /// Identity label: orchestration provider
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get teamUiLabelProvider;

  /// Identity label: host version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get teamUiLabelVersion;

  /// Server editor action opening the host guide
  ///
  /// In en, this message translates to:
  /// **'Learn how'**
  String get teamUiLearnHow;

  /// Plugins screen body when no server is selected
  ///
  /// In en, this message translates to:
  /// **'Connect to a server to use plugins.'**
  String get teamUiNoServer;

  /// Subtitle of the Plugins entry in the Settings hub
  ///
  /// In en, this message translates to:
  /// **'AI Team · Gas City'**
  String get teamUiPluginsHubSubtitle;

  /// Title of the Plugins settings page and its Settings hub entry
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get teamUiPluginsTitle;

  /// Explanation shown when the host has no front
  ///
  /// In en, this message translates to:
  /// **'You can watch this team from the phone. Answering and steering need the front on the computer.'**
  String get teamUiReadOnlyBody;

  /// Row reason when the supervisor answered but the city is not running
  ///
  /// In en, this message translates to:
  /// **'team host starting'**
  String get teamUiReasonCityNotRunning;

  /// Row reason when the address answered but is not a Gas City
  ///
  /// In en, this message translates to:
  /// **'no AI team found'**
  String get teamUiReasonNotGasCity;

  /// Row reason when plain http was refused to a non-tailnet host
  ///
  /// In en, this message translates to:
  /// **'address is not on Tailscale'**
  String get teamUiReasonPlainHttp;

  /// Row reason when the host was reached but a read failed
  ///
  /// In en, this message translates to:
  /// **'last read failed'**
  String get teamUiReasonReadFailed;

  /// Row reason when the host gave no answer
  ///
  /// In en, this message translates to:
  /// **'host unreachable'**
  String get teamUiReasonUnreachable;

  /// Sheet action refetching every scope from the host
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get teamUiRefresh;

  /// AI Team row subtitle while the first connection is under way
  ///
  /// In en, this message translates to:
  /// **'On · connecting…'**
  String get teamUiRowConnecting;

  /// AI Team row subtitle when the server host advertises a team that is not turned on yet
  ///
  /// In en, this message translates to:
  /// **'Found on {server} · Gas City {version}'**
  String teamUiRowFound(String server, String version);

  /// AI Team row subtitle when the configured host cannot be used
  ///
  /// In en, this message translates to:
  /// **'Not available on this server'**
  String get teamUiRowNotAvailable;

  /// AI Team row subtitle with the reason the host cannot be used
  ///
  /// In en, this message translates to:
  /// **'Not available on this server · {reason}'**
  String teamUiRowNotAvailableReason(String reason);

  /// AI Team row subtitle when the plugin is off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get teamUiRowOff;

  /// AI Team row subtitle when the plugin is off and discovery found nothing
  ///
  /// In en, this message translates to:
  /// **'Off · Add manually'**
  String get teamUiRowOffAddManually;

  /// AI Team row subtitle when the plugin is on and healthy
  ///
  /// In en, this message translates to:
  /// **'On · {server}'**
  String teamUiRowOn(String server);

  /// AI Team row subtitle when the plugin is on but the phone can only watch
  ///
  /// In en, this message translates to:
  /// **'On · {server} · read-only'**
  String teamUiRowOnReadOnly(String server);

  /// AI Team row subtitle while the event stream reconnects
  ///
  /// In en, this message translates to:
  /// **'On · reconnecting…'**
  String get teamUiRowReconnecting;

  /// Title of the AI Team row and sheet
  ///
  /// In en, this message translates to:
  /// **'AI Team · Gas City'**
  String get teamUiRowTitle;

  /// AI Team row subtitle when the host stopped answering
  ///
  /// In en, this message translates to:
  /// **'On · host unreachable since {minutes} min'**
  String teamUiRowUnreachable(String minutes);

  /// Snackbar after the plugin was turned on for a server
  ///
  /// In en, this message translates to:
  /// **'AI Team is on for {server}.'**
  String teamUiSavedOn(String server);

  /// Sheet status line when the host answers and the stream is live
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get teamUiStatusConnected;

  /// Sheet status line when the host cannot be used
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get teamUiStatusNotAvailable;

  /// Sheet status value when the plugin is off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get teamUiStatusOff;

  /// Sheet status value when the plugin is on
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get teamUiStatusOn;

  /// Sheet status line while the host is probed
  ///
  /// In en, this message translates to:
  /// **'Checking the host…'**
  String get teamUiStatusProbing;

  /// Sheet status line while the stream reconnects
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get teamUiStatusReconnecting;

  /// Sheet status line when the host stopped answering
  ///
  /// In en, this message translates to:
  /// **'Host unreachable'**
  String get teamUiStatusUnreachable;

  /// Verdict when a plain http address is neither loopback nor a tailnet address
  ///
  /// In en, this message translates to:
  /// **'AI Team works over your Tailscale network or on this device. Use the computer\'s Tailscale address (100.x.x.x or name.ts.net).'**
  String get teamUiTailnetRequired;

  /// Expander title listing raw provider values and the side-by-side terms
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get teamUiTechnicalDetails;

  /// Technical details label for the raw probe verdict or error text
  ///
  /// In en, this message translates to:
  /// **'Last answer from the host'**
  String get teamUiTechnicalLastAnswer;

  /// Side-by-side term: product term then the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Agent · polecat'**
  String get teamUiTermAgent;

  /// Side-by-side term: product term then the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Project · rig'**
  String get teamUiTermProject;

  /// Side-by-side term: product term then the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Run · convoy'**
  String get teamUiTermRun;

  /// Side-by-side term: product term then the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Team · city'**
  String get teamUiTermTeam;

  /// Side-by-side term: product term then the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Work · bead'**
  String get teamUiTermWork;

  /// Technical details heading above the side-by-side terms
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get teamUiTermsHeading;

  /// Sheet action and confirm label turning the plugin off for this server
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get teamUiTurnOff;

  /// Body of the turn-off confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Removes its card, attention items and cached team data from this phone. Nothing changes on the host.'**
  String get teamUiTurnOffBody;

  /// Snackbar when the store refused to drop some keys during turn-off
  ///
  /// In en, this message translates to:
  /// **'Turned off, but some cached data could not be removed from this phone.'**
  String get teamUiTurnOffFailed;

  /// Title of the turn-off confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Turn off AI Team for {server}?'**
  String teamUiTurnOffTitle(String server);

  /// Verdict when the supervisor answered but the city is not running
  ///
  /// In en, this message translates to:
  /// **'The team host is starting. Try again in a moment.'**
  String get teamUiVerdictCityNotRunning;

  /// Verdict chip for a found host without a front
  ///
  /// In en, this message translates to:
  /// **'Gas City {version} · city {city} · read-only'**
  String teamUiVerdictFound(String version, String city);

  /// Verdict chip for a found host with a front
  ///
  /// In en, this message translates to:
  /// **'Gas City {version} · city {city} · decisions and controls'**
  String teamUiVerdictFoundControls(String version, String city);

  /// Verdict when the address answered but is not a Gas City
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t run an AI team yet. Set one up on the computer — it takes a few minutes.'**
  String get teamUiVerdictNotGasCity;

  /// Verdict when the address gave no answer
  ///
  /// In en, this message translates to:
  /// **'No answer from this address. Check it, and that the computer is awake and on your Tailscale network.'**
  String get teamUiVerdictUnreachable;

  /// Version value when the host did not report one
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get teamUiVersionUnknown;

  /// Sheet line under the status when the phone can answer and steer
  ///
  /// In en, this message translates to:
  /// **'Watching and answering from this phone'**
  String get teamUiWatchingAndAnswering;

  /// Sheet line under the status when the phone can only watch
  ///
  /// In en, this message translates to:
  /// **'Watching from this phone'**
  String get teamUiWatchingOnly;

  /// Accessibility label of the agent dots on the Workspace AI Team card
  ///
  /// In en, this message translates to:
  /// **'{total} agents: {working} working, {waiting} waiting, {idle} idle, {stopped} stopped'**
  String teamUiCardAgentsSummary(
    int total,
    int working,
    int waiting,
    int idle,
    int stopped,
  );

  /// Workspace AI Team card header: how many agents are working right now
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No agents working} =1{1 agent working} other{{count} agents working}}'**
  String teamUiCardAgentsWorking(int count);

  /// Small secondary Gas City term on the Workspace AI Team card header, naming the city
  ///
  /// In en, this message translates to:
  /// **'city {city}'**
  String teamUiCardCity(String city);

  /// Collapsed row on the Workspace AI Team card for runs that finished
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 completed run} other{{count} completed runs}}'**
  String teamUiCardCompletedRuns(int count);

  /// Workspace AI Team card empty state, second line (Sprint A: no start-a-run on the phone)
  ///
  /// In en, this message translates to:
  /// **'Start runs from the host for now.'**
  String get teamUiCardEmptyHint;

  /// Workspace AI Team card empty state, first line
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get teamUiCardEmptyTitle;

  /// Workspace AI Team card error: the supervisor answered but the configured city is not running
  ///
  /// In en, this message translates to:
  /// **'The team host is starting. Try again in a moment.'**
  String get teamUiCardErrorCityNotRunning;

  /// Workspace AI Team card error: the URL answered but not like a Gas City supervisor
  ///
  /// In en, this message translates to:
  /// **'This server doesn’t run an AI team yet. Set one up on the computer — it takes a few minutes.'**
  String get teamUiCardErrorNotGasCity;

  /// Workspace AI Team card error: plain HTTP to a host that is neither loopback nor on the tailnet
  ///
  /// In en, this message translates to:
  /// **'AI Team works over your Tailscale network or on this device. Use tailscale serve on the computer, then try again.'**
  String get teamUiCardErrorPlainHttp;

  /// Workspace AI Team card error: no answer from the host at all
  ///
  /// In en, this message translates to:
  /// **'The team host can’t be reached. AI Team works over your Tailscale network or on this device.'**
  String get teamUiCardErrorUnreachable;

  /// Workspace AI Team card header: the team host runs on the computer
  ///
  /// In en, this message translates to:
  /// **'On the computer'**
  String get teamUiCardHostComputer;

  /// Workspace AI Team card header: the team host runs on this phone (Termux)
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get teamUiCardHostPhone;

  /// Workspace AI Team card loading state (skeleton) label
  ///
  /// In en, this message translates to:
  /// **'Connecting to the team host…'**
  String get teamUiCardLoading;

  /// Workspace AI Team card: runs beyond the three shown, opens the AI Team home
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more run} other{{count} more runs}}'**
  String teamUiCardMoreRuns(int count);

  /// Workspace AI Team card header pill: items waiting on the person
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs you} other{{count} need you}}'**
  String teamUiCardNeedsYou(int count);

  /// Workspace AI Team card primary action: opens the AI Team home
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get teamUiCardOpen;

  /// Workspace AI Team card hero number: progress of the headline run
  ///
  /// In en, this message translates to:
  /// **'{percent}% done.'**
  String teamUiCardPercentDone(int percent);

  /// Accessibility label of the segmented progress bar on the Workspace AI Team card
  ///
  /// In en, this message translates to:
  /// **'{done} done, {working} working, {blocked} blocked of {total}'**
  String teamUiCardProgressSummary(
    int done,
    int working,
    int blocked,
    int total,
  );

  /// Workspace AI Team card secondary action: refetch every scope from the host
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get teamUiCardRefresh;

  /// Workspace AI Team card line when the host was reached but a read failed; cached data stays on show
  ///
  /// In en, this message translates to:
  /// **'Last refresh failed · showing data from {time}'**
  String teamUiCardRefreshFailed(String time);

  /// Workspace AI Team card error state action: probe the host again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teamUiCardRetry;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get teamUiCardRunStateBlocked;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get teamUiCardRunStateCancelled;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get teamUiCardRunStateCompleted;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get teamUiCardRunStateFailed;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get teamUiCardRunStatePlanning;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get teamUiCardRunStateUnknown;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Waiting for an agent'**
  String get teamUiCardRunStateWaiting;

  /// Run state word on a Workspace AI Team card run row
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get teamUiCardRunStateWorking;

  /// Run state word (card row, home row, run detail) when every open work item of the batch is in the merge agent's hands (TEAM-117)
  ///
  /// In en, this message translates to:
  /// **'Waiting for merge'**
  String get teamUiCardRunStateWaitingMerge;

  /// Small secondary Gas City term beside a batch run title
  ///
  /// In en, this message translates to:
  /// **'convoy'**
  String get teamUiCardRunTermBatch;

  /// Small secondary Gas City term beside a formula run title
  ///
  /// In en, this message translates to:
  /// **'formula'**
  String get teamUiCardRunTermFormula;

  /// Workspace AI Team card one-sentence status for a blocked headline run
  ///
  /// In en, this message translates to:
  /// **'{title} is blocked.'**
  String teamUiCardSentenceBlocked(String title);

  /// Workspace AI Team card one-sentence status for a cancelled headline run
  ///
  /// In en, this message translates to:
  /// **'{title} was cancelled.'**
  String teamUiCardSentenceCancelled(String title);

  /// Workspace AI Team card one-sentence status for a completed headline run
  ///
  /// In en, this message translates to:
  /// **'{title} is done.'**
  String teamUiCardSentenceCompleted(String title);

  /// Workspace AI Team card one-sentence status for a failed headline run
  ///
  /// In en, this message translates to:
  /// **'{title} failed.'**
  String teamUiCardSentenceFailed(String title);

  /// Workspace AI Team card one-sentence status when the headline run has an open gate
  ///
  /// In en, this message translates to:
  /// **'{title} is waiting for your decision.'**
  String teamUiCardSentenceNeedsYou(String title);

  /// Workspace AI Team card one-sentence status for a headline run still planning
  ///
  /// In en, this message translates to:
  /// **'{title} is being planned.'**
  String teamUiCardSentencePlanning(String title);

  /// Workspace AI Team card one-sentence status when the host reported an unrecognised run state
  ///
  /// In en, this message translates to:
  /// **'{title} has no reported state.'**
  String teamUiCardSentenceUnknown(String title);

  /// Workspace AI Team card one-sentence status for a waiting headline run
  ///
  /// In en, this message translates to:
  /// **'{title} is waiting for an agent.'**
  String teamUiCardSentenceWaiting(String title);

  /// Workspace AI Team card one-sentence status for a headline run whose open work is all in the merge agent's hands (TEAM-117)
  ///
  /// In en, this message translates to:
  /// **'{title} is waiting for the merge agent.'**
  String teamUiCardSentenceWaitingMerge(String title);

  /// Workspace AI Team card one-sentence status for a working headline run
  ///
  /// In en, this message translates to:
  /// **'{title} is being worked on.'**
  String teamUiCardSentenceWorking(String title);

  /// Workspace AI Team card stale banner; time is HH:MM of the last successful refresh
  ///
  /// In en, this message translates to:
  /// **'Showing data from {time} · host unreachable'**
  String teamUiCardStale(String time);

  /// Workspace AI Team card header name; the provider is named openly
  ///
  /// In en, this message translates to:
  /// **'AI Team · Gas City'**
  String get teamUiCardTitle;

  /// AI Team home fleet row when the agent has no work item
  ///
  /// In en, this message translates to:
  /// **'No current work'**
  String get teamUiHomeAgentNoWork;

  /// AI Team home fleet row agent state
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get teamUiHomeAgentStateBlocked;

  /// AI Team home fleet row agent state
  ///
  /// In en, this message translates to:
  /// **'Crashed'**
  String get teamUiHomeAgentStateCrashed;

  /// AI Team home fleet row agent state
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get teamUiHomeAgentStateIdle;

  /// AI Team home fleet row agent state
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get teamUiHomeAgentStateStopped;

  /// AI Team home fleet row agent state when the host reported none
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get teamUiHomeAgentStateUnknown;

  /// AI Team home fleet row agent state when the agent waits on the person
  ///
  /// In en, this message translates to:
  /// **'Waiting (needs input)'**
  String get teamUiHomeAgentStateWaiting;

  /// AI Team home fleet row agent state
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get teamUiHomeAgentStateWorking;

  /// AI Team home Agents segment empty title
  ///
  /// In en, this message translates to:
  /// **'No agents on this host.'**
  String get teamUiHomeAgentsEmpty;

  /// AI Team home Agents segment empty hint
  ///
  /// In en, this message translates to:
  /// **'Agents appear here once the host starts them.'**
  String get teamUiHomeAgentsEmptyHint;

  /// AI Team home host chip access word when the phone can answer gates
  ///
  /// In en, this message translates to:
  /// **'controls'**
  String get teamUiHomeChipControls;

  /// AI Team home host chip access word when the phone can only watch
  ///
  /// In en, this message translates to:
  /// **'read-only'**
  String get teamUiHomeChipReadOnly;

  /// AI Team home collapsed group of completed runs not all from today
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String teamUiHomeCompletedGroup(int count);

  /// AI Team home collapsed group of runs completed today
  ///
  /// In en, this message translates to:
  /// **'Completed today ({count})'**
  String teamUiHomeCompletedToday(int count);

  /// AI Team home Runs filter chip: planning and working runs
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get teamUiHomeFilterActive;

  /// AI Team home Runs filter chip: every run
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get teamUiHomeFilterAll;

  /// AI Team home Runs filter chip: blocked, waiting, failed or gated runs
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get teamUiHomeFilterBlocked;

  /// AI Team home Runs filter chip: completed and cancelled runs
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get teamUiHomeFilterCompleted;

  /// AI Team home read-only gate sheet line when the host runs on a computer
  ///
  /// In en, this message translates to:
  /// **'Answer this on the computer. The phone can only watch for now.'**
  String get teamUiHomeGateAnswerOnComputer;

  /// AI Team home read-only gate sheet line when the host runs on the phone
  ///
  /// In en, this message translates to:
  /// **'Answer this in the host on this phone. The app can only watch for now.'**
  String get teamUiHomeGateAnswerOnPhone;

  /// AI Team home read-only gate sheet dismiss button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get teamUiHomeGateClose;

  /// AI Team home Needs you kind label for a choice interaction
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get teamUiHomeGateKindChoice;

  /// AI Team home Needs you kind label for a confirmation interaction
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get teamUiHomeGateKindConfirmation;

  /// AI Team home Needs you kind label for a free-text interaction
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get teamUiHomeGateKindFreeText;

  /// AI Team home Needs you kind label for a gate bead
  ///
  /// In en, this message translates to:
  /// **'Gate'**
  String get teamUiHomeGateKindGateBead;

  /// AI Team home Needs you kind label for work ready for review
  ///
  /// In en, this message translates to:
  /// **'Review ready'**
  String get teamUiHomeGateKindReviewReady;

  /// AI Team home Needs you kind label for a failed run
  ///
  /// In en, this message translates to:
  /// **'Run failed'**
  String get teamUiHomeGateKindRunFailed;

  /// AI Team home Needs you kind label when the host reported an unrecognised kind
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get teamUiHomeGateKindUnknown;

  /// AI Team home Needs you row link text naming the agent; name is server content
  ///
  /// In en, this message translates to:
  /// **'Agent {name}'**
  String teamUiHomeGateLinkAgent(String name);

  /// AI Team home Needs you row link text naming the run; title is server content
  ///
  /// In en, this message translates to:
  /// **'Run {title}'**
  String teamUiHomeGateLinkRun(String title);

  /// AI Team home Needs you row link text naming the work item; title is server content
  ///
  /// In en, this message translates to:
  /// **'Work {title}'**
  String teamUiHomeGateLinkWork(String title);

  /// AI Team home read-only gate sheet heading over the choice options
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get teamUiHomeGateOptions;

  /// AI Team home host identity chip; host is the host name from the team URL with its kind word (teamUiHomeHostChipHost), city the Gas City name, access the read-only or controls word
  ///
  /// In en, this message translates to:
  /// **'{host} · Gas City {version} · city {city} · {access}'**
  String teamUiHomeHostChip(
    String host,
    String version,
    String city,
    String access,
  );

  /// AI Team home host identity chip when the host reported no city
  ///
  /// In en, this message translates to:
  /// **'{host} · Gas City {version} · {access}'**
  String teamUiHomeHostChipNoCity(String host, String version, String access);

  /// AI Team home Technical details sheet heading over the copyable provider values
  ///
  /// In en, this message translates to:
  /// **'Raw values'**
  String get teamUiHomeHostRawHeading;

  /// AI Team home Needs you segment empty title
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you right now.'**
  String get teamUiHomeNeedsYouEmpty;

  /// AI Team home Needs you segment empty hint
  ///
  /// In en, this message translates to:
  /// **'Decisions, failed runs and blocked agents show up here.'**
  String get teamUiHomeNeedsYouEmptyHint;

  /// AI Team home run row subtitle for a batch run; the Gas City term follows the product term
  ///
  /// In en, this message translates to:
  /// **'Batch · convoy'**
  String get teamUiHomeRunKindBatch;

  /// AI Team home run row subtitle for a formula run without a formula name
  ///
  /// In en, this message translates to:
  /// **'Run · formula'**
  String get teamUiHomeRunKindFormula;

  /// AI Team home run row subtitle for a formula run; formula is the server-side formula name
  ///
  /// In en, this message translates to:
  /// **'Run · formula {formula}'**
  String teamUiHomeRunKindFormulaNamed(String formula);

  /// AI Team home run row marker when a gate waits on the person for this run
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get teamUiHomeRunNeedsYou;

  /// AI Team home run row progress from steps or work items
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String teamUiHomeRunProgress(int done, int total);

  /// AI Team home Runs segment empty title when a filter or search hides every run
  ///
  /// In en, this message translates to:
  /// **'No runs match.'**
  String get teamUiHomeRunsEmptyFiltered;

  /// AI Team home Runs segment empty hint when a filter or search hides every run
  ///
  /// In en, this message translates to:
  /// **'Try another filter or clear the search.'**
  String get teamUiHomeRunsEmptyHint;

  /// AI Team home Runs search field clear button tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get teamUiHomeSearchClear;

  /// AI Team home Runs search field hint
  ///
  /// In en, this message translates to:
  /// **'Search runs by title'**
  String get teamUiHomeSearchHint;

  /// AI Team home segment label with the fleet size
  ///
  /// In en, this message translates to:
  /// **'Agents ({count})'**
  String teamUiHomeSegmentAgents(int count);

  /// AI Team home segment label with the count of items waiting on the person
  ///
  /// In en, this message translates to:
  /// **'Needs you ({count})'**
  String teamUiHomeSegmentNeedsYou(int count);

  /// AI Team home segment label with the run count
  ///
  /// In en, this message translates to:
  /// **'Runs ({count})'**
  String teamUiHomeSegmentRuns(int count);

  /// AI Team home app bar title
  ///
  /// In en, this message translates to:
  /// **'AI Team'**
  String get teamUiHomeTitle;

  /// Run detail: back action when the run is gone
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get teamUiRunBack;

  /// Run detail Overview line for a convoy run instead of stages
  ///
  /// In en, this message translates to:
  /// **'Batch of {total} · {done} done'**
  String teamUiRunBatchOf(int total, int done);

  /// Run detail blocked cause derived from open dependencies
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{waiting on one other item} other{waiting on {count} other items}}'**
  String teamUiRunBlockedByDeps(int count);

  /// Run detail blocked line; title is the work item, cause is the server text
  ///
  /// In en, this message translates to:
  /// **'{title}: {cause}'**
  String teamUiRunBlockedCause(String title, String cause);

  /// Run detail count chip of blocked work
  ///
  /// In en, this message translates to:
  /// **'Blocked {count}'**
  String teamUiRunChipBlocked(int count);

  /// Run detail count chip of work in progress
  ///
  /// In en, this message translates to:
  /// **'Working {count}'**
  String teamUiRunChipWorking(int count);

  /// Run detail app bar action opening Technical details
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get teamUiRunDetails;

  /// Run detail elapsed time in days
  ///
  /// In en, this message translates to:
  /// **'{count} d'**
  String teamUiRunElapsedDays(int count);

  /// Run detail elapsed time in hours and minutes
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String teamUiRunElapsedHours(int hours, int minutes);

  /// Run detail elapsed time in minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String teamUiRunElapsedMinutes(int count);

  /// Run detail time beside the state word when the batch waits for merge (TEAM-117): elapsed is the short span, e.g. '20 h 19 min'
  ///
  /// In en, this message translates to:
  /// **'{elapsed} since hand-off'**
  String teamUiRunSinceHandoff(String elapsed);

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get teamUiRunLabelFormula;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Run id'**
  String get teamUiRunLabelId;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get teamUiRunLabelKind;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Last error'**
  String get teamUiRunLabelLastError;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get teamUiRunLabelProject;

  /// Run Technical details label for the raw status string
  ///
  /// In en, this message translates to:
  /// **'Provider status'**
  String get teamUiRunLabelRawState;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get teamUiRunLabelStarted;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get teamUiRunLabelState;

  /// Run Technical details label for the ids of the work items in the run
  ///
  /// In en, this message translates to:
  /// **'Tracked work'**
  String get teamUiRunLabelTrackedWork;

  /// Run Technical details label
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get teamUiRunLabelUpdated;

  /// Run detail hint when the run id is not in the host’s list
  ///
  /// In en, this message translates to:
  /// **'It may have been closed or removed. Refresh to check again.'**
  String get teamUiRunMissingHint;

  /// Run detail state when the run id is not in the host’s list
  ///
  /// In en, this message translates to:
  /// **'This run is no longer on the host'**
  String get teamUiRunMissingTitle;

  /// Run detail inline card label when no agent is named
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get teamUiRunNeedsYou;

  /// Run detail inline card label; name is the agent
  ///
  /// In en, this message translates to:
  /// **'{name} needs you'**
  String teamUiRunNeedsYouFrom(String name);

  /// Run detail progress line when the host counted no work
  ///
  /// In en, this message translates to:
  /// **'Nothing counted yet'**
  String get teamUiRunProgressNone;

  /// Run detail progress bar accessibility label
  ///
  /// In en, this message translates to:
  /// **'{done} done, {working} working, {blocked} blocked, of {total}'**
  String teamUiRunProgressSemantics(
    int done,
    int working,
    int blocked,
    int total,
  );

  /// Run detail Overview heading over the stage list
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get teamUiRunStagesHeading;

  /// Run detail tab
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get teamUiRunTabAgents;

  /// Run detail placeholder for the Work and Agents tabs
  ///
  /// In en, this message translates to:
  /// **'Coming with the next update'**
  String get teamUiRunTabComingSoon;

  /// Run detail tab
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get teamUiRunTabOverview;

  /// Run detail tab
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get teamUiRunTabTimeline;

  /// Run detail tab
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get teamUiRunTabWork;

  /// Run detail app bar term for a batch run; convoy is the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Run · convoy'**
  String get teamUiRunTermBatch;

  /// Run detail app bar term for a formula run; formula is the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Run · formula'**
  String get teamUiRunTermFormula;

  /// Run detail app bar term when the kind is unknown
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get teamUiRunTermUnknown;

  /// Run timeline row for an agent session that stopped
  ///
  /// In en, this message translates to:
  /// **'{name} stopped'**
  String teamUiRunTimelineAgentStopped(String name);

  /// Run timeline row for an agent session that woke
  ///
  /// In en, this message translates to:
  /// **'{name} started'**
  String teamUiRunTimelineAgentWoke(String name);

  /// Run timeline empty state title
  ///
  /// In en, this message translates to:
  /// **'Nothing has happened yet'**
  String get teamUiRunTimelineEmpty;

  /// Run timeline empty state title when a filter hides every row
  ///
  /// In en, this message translates to:
  /// **'No events of this kind yet'**
  String get teamUiRunTimelineEmptyFiltered;

  /// Run timeline empty state hint when a filter hides every row
  ///
  /// In en, this message translates to:
  /// **'Try another filter.'**
  String get teamUiRunTimelineEmptyFilteredHint;

  /// Run timeline empty state hint
  ///
  /// In en, this message translates to:
  /// **'Events appear here as the team works on this run.'**
  String get teamUiRunTimelineEmptyHint;

  /// Run timeline filter chip
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get teamUiRunTimelineFilterAgents;

  /// Run timeline filter chip
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get teamUiRunTimelineFilterAll;

  /// Run timeline filter chip
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get teamUiRunTimelineFilterDecisions;

  /// Run timeline filter chip
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get teamUiRunTimelineFilterWork;

  /// Run timeline row for a gate that opened
  ///
  /// In en, this message translates to:
  /// **'Needs you: {title}'**
  String teamUiRunTimelineGateOpened(String title);

  /// Run timeline row for a gate that was resolved
  ///
  /// In en, this message translates to:
  /// **'Answered: {title}'**
  String teamUiRunTimelineGateResolved(String title);

  /// Run timeline pill shown when events arrived while scrolled away
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new · Jump to latest} other{{count} new · Jump to latest}}'**
  String teamUiRunTimelineJump(int count);

  /// Run timeline row for a run state change; state is the run state word
  ///
  /// In en, this message translates to:
  /// **'Run is now {state}'**
  String teamUiRunTimelineRunChanged(String state);

  /// Run timeline row for a work item that closed
  ///
  /// In en, this message translates to:
  /// **'{title} closed'**
  String teamUiRunTimelineWorkClosed(String title);

  /// Run timeline row for a work item that was created
  ///
  /// In en, this message translates to:
  /// **'{title} added'**
  String teamUiRunTimelineWorkCreated(String title);

  /// Run timeline row for a work item that changed
  ///
  /// In en, this message translates to:
  /// **'{title} updated'**
  String teamUiRunTimelineWorkUpdated(String title);

  /// Agent detail Activity section empty state title
  ///
  /// In en, this message translates to:
  /// **'No activity captured yet'**
  String get teamUiAgentActivityEmpty;

  /// Agent detail Activity section empty state hint
  ///
  /// In en, this message translates to:
  /// **'Tool calls and commands appear here as the session\'s output arrives.'**
  String get teamUiAgentActivityEmptyHint;

  /// Screen reader label of the context-use number
  ///
  /// In en, this message translates to:
  /// **'Context {percent}% used'**
  String teamUiAgentContextSemantics(int percent);

  /// Context-use number on fleet rows and the agent header; keep short
  ///
  /// In en, this message translates to:
  /// **'ctx {percent}%'**
  String teamUiAgentContextShort(int percent);

  /// Agent Runtime row label
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get teamUiAgentLabelBranch;

  /// Agent Runtime row label
  ///
  /// In en, this message translates to:
  /// **'Context use'**
  String get teamUiAgentLabelContext;

  /// Agent Identity row label: the coding harness the agent runs in (OpenCode)
  ///
  /// In en, this message translates to:
  /// **'Harness'**
  String get teamUiAgentLabelHarness;

  /// Agent Identity row label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get teamUiAgentLabelModel;

  /// Agent Identity row label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get teamUiAgentLabelName;

  /// Agent Technical details label (Gas City pack)
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get teamUiAgentLabelPack;

  /// Agent Technical details label (Gas City pool template)
  ///
  /// In en, this message translates to:
  /// **'Pool'**
  String get teamUiAgentLabelPool;

  /// Agent Identity row label
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get teamUiAgentLabelRole;

  /// Agent Runtime row label
  ///
  /// In en, this message translates to:
  /// **'Session age'**
  String get teamUiAgentLabelSessionAge;

  /// Agent Technical details label (session id)
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get teamUiAgentLabelSessionId;

  /// Agent Technical details label
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get teamUiAgentLabelSessionName;

  /// Agent Runtime row label
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get teamUiAgentLabelWorkDir;

  /// Agent detail hint when the host no longer lists the agent
  ///
  /// In en, this message translates to:
  /// **'It may have been recycled. Refresh to check.'**
  String get teamUiAgentMissingHint;

  /// Agent detail title when the host no longer lists the agent
  ///
  /// In en, this message translates to:
  /// **'This agent is no longer on the host'**
  String get teamUiAgentMissingTitle;

  /// Agent detail heading over the question waiting on the person
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get teamUiAgentNeedsYou;

  /// Live output status line before the first text arrives
  ///
  /// In en, this message translates to:
  /// **'Connecting to the session…'**
  String get teamUiAgentOutputConnecting;

  /// Live output app bar button tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy output'**
  String get teamUiAgentOutputCopy;

  /// Live output body when the session has produced no text
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get teamUiAgentOutputEmpty;

  /// Live output status line once the host stopped serving the session; cached text stays below
  ///
  /// In en, this message translates to:
  /// **'Session ended · output no longer on the host'**
  String get teamUiAgentOutputEnded;

  /// Live output switch: keep the newest output in view
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get teamUiAgentOutputFollow;

  /// Live output pill shown while not following; tapping resumes following
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get teamUiAgentOutputJump;

  /// Live output status line while the session streams
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get teamUiAgentOutputLive;

  /// Agent detail row and page title for the session output
  ///
  /// In en, this message translates to:
  /// **'Live output'**
  String get teamUiAgentOutputTitle;

  /// Live output status line when the host cannot serve output for this agent
  ///
  /// In en, this message translates to:
  /// **'Live output is not available for this agent'**
  String get teamUiAgentOutputUnavailable;

  /// Agent header line when context use reached the recycle threshold
  ///
  /// In en, this message translates to:
  /// **'Recycling soon · context nearly full'**
  String get teamUiAgentRecyclingSoon;

  /// Run Agents tab empty state title
  ///
  /// In en, this message translates to:
  /// **'No agents on this run'**
  String get teamUiAgentRunEmpty;

  /// Run Agents tab empty state hint
  ///
  /// In en, this message translates to:
  /// **'Agents appear here while they work on this run\'s items.'**
  String get teamUiAgentRunEmptyHint;

  /// Agent detail section heading
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get teamUiAgentSectionActivity;

  /// Agent detail section heading
  ///
  /// In en, this message translates to:
  /// **'Current work'**
  String get teamUiAgentSectionCurrentWork;

  /// Agent detail section heading
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get teamUiAgentSectionIdentity;

  /// Agent detail section heading
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get teamUiAgentSectionOutput;

  /// Agent detail section heading
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get teamUiAgentSectionRuntime;

  /// Agent header: how long the session has existed; age is a short span like "3 h 14 min"
  ///
  /// In en, this message translates to:
  /// **'Session {age}'**
  String teamUiAgentSessionAge(String age);

  /// Step log: lines of a tool output not shown
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more line} other{{count} more lines}}'**
  String teamUiAgentStepMoreLines(int count);

  /// Step log group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{ran 1 command} other{ran {count} commands}}'**
  String teamUiAgentStepsCommands(int count);

  /// Step log group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{edited 1 file} other{edited {count} files}}'**
  String teamUiAgentStepsEdits(int count);

  /// Step log group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other tool call} other{{count} other tool calls}}'**
  String teamUiAgentStepsOther(int count);

  /// Step log group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{read 1 file} other{read {count} files}}'**
  String teamUiAgentStepsReads(int count);

  /// Step log group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{searched once} other{searched {count} times}}'**
  String teamUiAgentStepsSearches(int count);

  /// Screen reader label of a collapsed step group
  ///
  /// In en, this message translates to:
  /// **'{summary}, {count, plural, =1{1 step} other{{count} steps}}'**
  String teamUiAgentStepsSemantics(String summary, int count);

  /// Step log group summary segment
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{ran 1 test run} other{ran {count} test runs}}'**
  String teamUiAgentStepsTests(int count);

  /// Step log group header title
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get teamUiAgentStepsTitle;

  /// Agent app bar secondary line when the agent has no session
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get teamUiAgentTermNoSession;

  /// Agent app bar secondary line carrying the Gas City term; id is the session id
  ///
  /// In en, this message translates to:
  /// **'Agent · session {id}'**
  String teamUiAgentTermSession(String id);

  /// Agent detail row value when the host did not report it
  ///
  /// In en, this message translates to:
  /// **'Not reported'**
  String get teamUiAgentValueUnknown;

  /// Agent Current work dependency line when the item is blocked
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get teamUiAgentWorkBlocked;

  /// Agent Current work dependency line when the item is free to proceed
  ///
  /// In en, this message translates to:
  /// **'Nothing blocking it'**
  String get teamUiAgentWorkUnblocked;

  /// Work tab empty state title
  ///
  /// In en, this message translates to:
  /// **'No work items yet'**
  String get teamUiWorkEmpty;

  /// Work tab empty state hint
  ///
  /// In en, this message translates to:
  /// **'Work appears here once the run has items.'**
  String get teamUiWorkEmptyHint;

  /// Tooltip of the graph button that brings the whole graph into view
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get teamUiWorkGraphFit;

  /// Screen reader label of one graph node: the work title and its state word
  ///
  /// In en, this message translates to:
  /// **'{title}, {state}'**
  String teamUiWorkGraphNodeSemantics(String title, String state);

  /// Screen reader label of the Work graph
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Dependency graph of 1 work item} other{Dependency graph of {count} work items}}'**
  String teamUiWorkGraphSemantics(int count);

  /// Work list group header: the state word and how many items are in it
  ///
  /// In en, this message translates to:
  /// **'{state} · {count}'**
  String teamUiWorkGroupHeader(String state, int count);

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get teamUiWorkLabelAssignee;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Close reason'**
  String get teamUiWorkLabelClosedReason;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Depends on (ids)'**
  String get teamUiWorkLabelDependsOn;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Work id'**
  String get teamUiWorkLabelId;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get teamUiWorkLabelLabels;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get teamUiWorkLabelParent;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get teamUiWorkLabelProject;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Provider status'**
  String get teamUiWorkLabelRawState;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Run id'**
  String get teamUiWorkLabelRun;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Session id'**
  String get teamUiWorkLabelSession;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get teamUiWorkLabelSessionName;

  /// Work technical details label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get teamUiWorkLabelType;

  /// Work owner when nobody is on the item
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get teamUiWorkOwnerNone;

  /// Screen reader label of the owner glyph on a work row
  ///
  /// In en, this message translates to:
  /// **'Owner: {name}'**
  String teamUiWorkOwnerSemantics(String name);

  /// Work sheet heading over the items that wait on this one
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get teamUiWorkSheetBlocking;

  /// Work sheet label
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get teamUiWorkSheetBranch;

  /// Work sheet timestamp label
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get teamUiWorkSheetClosed;

  /// Work sheet heading over the branch and worktree
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get teamUiWorkSheetCode;

  /// Work sheet timestamp label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get teamUiWorkSheetCreated;

  /// Work sheet heading over the items this one needs
  ///
  /// In en, this message translates to:
  /// **'Depends on'**
  String get teamUiWorkSheetDependencies;

  /// Work sheet heading
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get teamUiWorkSheetDescription;

  /// Work sheet body when the item disappeared
  ///
  /// In en, this message translates to:
  /// **'This work item is no longer on the host.'**
  String get teamUiWorkSheetMissing;

  /// Work sheet line when no timestamp is known
  ///
  /// In en, this message translates to:
  /// **'The host sent no timestamps.'**
  String get teamUiWorkSheetNoTimestamps;

  /// Work sheet button that opens the linked OpenCode session
  ///
  /// In en, this message translates to:
  /// **'Open session'**
  String get teamUiWorkSheetOpenSession;

  /// Work sheet heading over the output excerpt
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get teamUiWorkSheetOutput;

  /// Work sheet timestamp: a date, a clock time and a relative age
  ///
  /// In en, this message translates to:
  /// **'{date} · {clock} ({age})'**
  String teamUiWorkSheetStamp(String date, String clock, String age);

  /// Work sheet label
  ///
  /// In en, this message translates to:
  /// **'Merge target'**
  String get teamUiWorkSheetTarget;

  /// Work sheet heading
  ///
  /// In en, this message translates to:
  /// **'Timestamps'**
  String get teamUiWorkSheetTimestamps;

  /// Work sheet timestamp label
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get teamUiWorkSheetUpdated;

  /// Work sheet heading over the validation result
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get teamUiWorkSheetValidation;

  /// Work sheet validation result
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get teamUiWorkSheetValidationFailed;

  /// Work sheet validation result
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get teamUiWorkSheetValidationPassed;

  /// Work sheet validation result when the host gave no pass/fail
  ///
  /// In en, this message translates to:
  /// **'Result recorded'**
  String get teamUiWorkSheetValidationUnknown;

  /// Work sheet label
  ///
  /// In en, this message translates to:
  /// **'Worktree'**
  String get teamUiWorkSheetWorktree;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get teamUiWorkStateBlocked;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get teamUiWorkStateCancelled;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get teamUiWorkStateCompleted;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get teamUiWorkStateFailed;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Needs input'**
  String get teamUiWorkStateNeedsInput;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get teamUiWorkStateQueued;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get teamUiWorkStateReady;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get teamUiWorkStateReview;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get teamUiWorkStateUnknown;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get teamUiWorkStateWaiting;

  /// Work state word (BRD §14)
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get teamUiWorkStateWorking;

  /// Work sheet term row: the product word with its Gas City term and id
  ///
  /// In en, this message translates to:
  /// **'Work · bead {id}'**
  String teamUiWorkTerm(String id);

  /// Work tab view toggle
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get teamUiWorkViewGraph;

  /// Work tab view toggle
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get teamUiWorkViewList;

  /// Work row detail: how many open items this one still needs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Waits on 1 item} other{Waits on {count} items}}'**
  String teamUiWorkWaitsOn(int count);

  /// Run Overview usage chip: Gas City usage is city-level (today), never per run; {usage} is the est. cost and compact tokens
  ///
  /// In en, this message translates to:
  /// **'Team today · {usage}'**
  String teamUiUsageChip(String usage);

  /// A cost figure with the estimate suffix; every cost the plugin shows carries it (05-beads TEAM-113)
  ///
  /// In en, this message translates to:
  /// **'{cost} est.'**
  String teamUiUsageCostEstimated(String cost);

  /// Agent Runtime: under the tokens / context / cost line, says the figures are city-level estimates
  ///
  /// In en, this message translates to:
  /// **'Tokens and cost are the whole team\'s today, estimated.'**
  String get teamUiUsageRuntimeHint;

  /// Agent Runtime row label of the usage line
  ///
  /// In en, this message translates to:
  /// **'Tokens / context / cost'**
  String get teamUiUsageRuntimeLabel;

  /// Compact token count ("12.4k tokens"); {count} is already formatted
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String teamUiUsageTokens(String count);

  /// Gate sheet footer when the host runs on a computer (Sprint A, read-only)
  ///
  /// In en, this message translates to:
  /// **'Answer this on the host. The phone can only watch for now.'**
  String get teamUiGateAnswerOnHost;

  /// Gate sheet footer when the host runs on this phone (Sprint A, read-only)
  ///
  /// In en, this message translates to:
  /// **'Answer this in the host on this phone. The app can only watch for now.'**
  String get teamUiGateAnswerOnHostPhone;

  /// Gate bead sheet footer when the host runs on a computer
  ///
  /// In en, this message translates to:
  /// **'Close this on the host. The phone can only watch for now.'**
  String get teamUiGateCloseOnHost;

  /// Gate bead sheet footer when the host runs on this phone
  ///
  /// In en, this message translates to:
  /// **'Close this in the host on this phone. The app can only watch for now.'**
  String get teamUiGateCloseOnHostPhone;

  /// Gate sheet heading: the gate bead's description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get teamUiGateDescription;

  /// Gate sheet marker on a confirmation that would delete or overwrite something
  ///
  /// In en, this message translates to:
  /// **'Destructive'**
  String get teamUiGateDestructive;

  /// Failed-run sheet heading
  ///
  /// In en, this message translates to:
  /// **'Recommended action'**
  String get teamUiGateFailureAction;

  /// Failed-run sheet recommended action for an agent failure
  ///
  /// In en, this message translates to:
  /// **'Restart the agent on the host; it picks the work item up again.'**
  String get teamUiGateFailureActionAgent;

  /// Failed-run sheet recommended action for an authentication failure
  ///
  /// In en, this message translates to:
  /// **'Sign in again on the host (provider key or token), then retry the run.'**
  String get teamUiGateFailureActionAuthentication;

  /// Failed-run sheet recommended action for a context-window failure
  ///
  /// In en, this message translates to:
  /// **'Restart the agent with a fresh context on the host; it resumes from the work item.'**
  String get teamUiGateFailureActionContext;

  /// Failed-run sheet recommended action for a dependency failure
  ///
  /// In en, this message translates to:
  /// **'Install or update the missing dependency on the host, then retry the run.'**
  String get teamUiGateFailureActionDependency;

  /// Failed-run sheet recommended action for an execution failure
  ///
  /// In en, this message translates to:
  /// **'Read the step log on the host, fix the command, then retry the run.'**
  String get teamUiGateFailureActionExecution;

  /// Failed-run sheet recommended action for an infrastructure failure
  ///
  /// In en, this message translates to:
  /// **'Check the host and its services, then retry the run.'**
  String get teamUiGateFailureActionInfrastructure;

  /// Failed-run sheet recommended action for a merge conflict
  ///
  /// In en, this message translates to:
  /// **'Resolve the conflict in the worktree on the host, then retry the run.'**
  String get teamUiGateFailureActionMergeConflict;

  /// Failed-run sheet recommended action for a test failure
  ///
  /// In en, this message translates to:
  /// **'Fix the failing tests on the host, then retry the run.'**
  String get teamUiGateFailureActionTest;

  /// Failed-run sheet recommended action when the failure is unclassified
  ///
  /// In en, this message translates to:
  /// **'Read the error on the host and decide there; the phone cannot act on it yet.'**
  String get teamUiGateFailureActionUnknown;

  /// Failed-run sheet: nothing listed under Affected work
  ///
  /// In en, this message translates to:
  /// **'No open work item of this run.'**
  String get teamUiGateFailureAffectedNone;

  /// Failed-run sheet heading
  ///
  /// In en, this message translates to:
  /// **'Affected work'**
  String get teamUiGateFailureAffectedWork;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get teamUiGateFailureClassAgent;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get teamUiGateFailureClassAuthentication;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get teamUiGateFailureClassContext;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Dependency'**
  String get teamUiGateFailureClassDependency;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get teamUiGateFailureClassExecution;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Infrastructure'**
  String get teamUiGateFailureClassInfrastructure;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Merge conflict'**
  String get teamUiGateFailureClassMergeConflict;

  /// Failure class word (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get teamUiGateFailureClassTest;

  /// Failure class word when the error text matches nothing
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get teamUiGateFailureClassUnknown;

  /// Failed-run sheet heading
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get teamUiGateFailureClassification;

  /// Failed-run sheet heading: the host's error text
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get teamUiGateFailureError;

  /// Failed-run sheet when the run has no last error
  ///
  /// In en, this message translates to:
  /// **'The host sent no error text.'**
  String get teamUiGateFailureErrorNone;

  /// Failed-run sheet heading
  ///
  /// In en, this message translates to:
  /// **'Recoverable'**
  String get teamUiGateFailureRecoverable;

  /// Failed-run sheet: a retry alone will not recover it
  ///
  /// In en, this message translates to:
  /// **'No — something needs changing first'**
  String get teamUiGateFailureRecoverableNo;

  /// Failed-run sheet: cannot tell from the error text
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get teamUiGateFailureRecoverableUnknown;

  /// Failed-run sheet: a retry can recover it
  ///
  /// In en, this message translates to:
  /// **'Yes — a retry from the host can recover it'**
  String get teamUiGateFailureRecoverableYes;

  /// Gate sheet when the gate left the snapshot while the sheet was open
  ///
  /// In en, this message translates to:
  /// **'This is no longer waiting on you; it was answered or closed on the host.'**
  String get teamUiGateGone;

  /// Activity row kind word for a blocked agent (BRD §47 rank 5)
  ///
  /// In en, this message translates to:
  /// **'Agent blocked'**
  String get teamUiGateKindAgentBlocked;

  /// Gate sheet technical detail label
  ///
  /// In en, this message translates to:
  /// **'Provider kind'**
  String get teamUiGateLabelKind;

  /// Gate sheet technical detail label
  ///
  /// In en, this message translates to:
  /// **'Request id'**
  String get teamUiGateLabelRequestId;

  /// Gate sheet technical detail label
  ///
  /// In en, this message translates to:
  /// **'Run id'**
  String get teamUiGateLabelRunId;

  /// Gate sheet technical detail label
  ///
  /// In en, this message translates to:
  /// **'Session id'**
  String get teamUiGateLabelSessionId;

  /// Gate sheet technical detail label
  ///
  /// In en, this message translates to:
  /// **'Work id'**
  String get teamUiGateLabelWorkId;

  /// Gate sheet when a gate bead has no description
  ///
  /// In en, this message translates to:
  /// **'The host sent no description.'**
  String get teamUiGateNoDescription;

  /// Review-ready sheet footer when the host runs on a computer
  ///
  /// In en, this message translates to:
  /// **'Review this on the host. The phone can only watch for now.'**
  String get teamUiGateReviewOnHost;

  /// Review-ready sheet footer when the host runs on this phone
  ///
  /// In en, this message translates to:
  /// **'Review this in the host on this phone. The app can only watch for now.'**
  String get teamUiGateReviewOnHostPhone;

  /// Gate sheet term row: the product word with its Gas City term and id
  ///
  /// In en, this message translates to:
  /// **'{kind} · bead {id}'**
  String teamUiGateTermBead(String kind, String id);

  /// Gate sheet term row: the product word with its Gas City term and request id
  ///
  /// In en, this message translates to:
  /// **'{kind} · interaction {id}'**
  String teamUiGateTermInteraction(String kind, String id);

  /// Gate sheet term row: the product word with its Gas City term and run id
  ///
  /// In en, this message translates to:
  /// **'{kind} · run {id}'**
  String teamUiGateTermRun(String kind, String id);

  /// Gate sheet heading: the work items waiting on this gate bead
  ///
  /// In en, this message translates to:
  /// **'Unblocks'**
  String get teamUiGateUnblocks;

  /// Gate sheet when no work item depends on the gate bead
  ///
  /// In en, this message translates to:
  /// **'Nothing waits on this yet.'**
  String get teamUiGateUnblocksNone;

  /// Host kind choice in the manual-add form: a desktop PC (the default)
  ///
  /// In en, this message translates to:
  /// **'Desktop computer'**
  String get teamUiHostKindDesktop;

  /// Performance disclaimer for a team hosted on a laptop (03-onboarding §4)
  ///
  /// In en, this message translates to:
  /// **'Sleep and lid-close pause the team; runs resume on wake'**
  String get teamUiHostKindDisclaimerLaptop;

  /// Performance disclaimer for a team hosted on Windows via WSL (03-onboarding §4 plus the WSL clause of docs/ai-team-host.md §7)
  ///
  /// In en, this message translates to:
  /// **'Sleep and lid-close pause the team; runs resume on wake. WSL also stops when its last terminal closes.'**
  String get teamUiHostKindDisclaimerWsl;

  /// Helper text under the host kind choice: the choice affects nothing but the disclaimer line
  ///
  /// In en, this message translates to:
  /// **'Only changes the reminder shown with the team.'**
  String get teamUiHostKindHint;

  /// Label of the host kind choice in the manual-add form
  ///
  /// In en, this message translates to:
  /// **'Kind of computer'**
  String get teamUiHostKindLabel;

  /// Host kind choice in the manual-add form: a laptop
  ///
  /// In en, this message translates to:
  /// **'Laptop'**
  String get teamUiHostKindLaptop;

  /// Host kind choice in the manual-add form: Windows running the team inside WSL
  ///
  /// In en, this message translates to:
  /// **'Windows (WSL)'**
  String get teamUiHostKindWsl;

  /// Receipt state shown after a gate answer or control was sent and the host has not confirmed it yet (02-ux §6)
  ///
  /// In en, this message translates to:
  /// **'Sent · waiting for the host to confirm'**
  String get teamUiReceiptSent;

  /// Receipt state once the host confirmed the answer or control with its matching result event
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get teamUiReceiptAnswered;

  /// Receipt state when no result arrived in time or the app restarted while the answer was in flight; nothing is re-sent automatically
  ///
  /// In en, this message translates to:
  /// **'Sent, unconfirmed — check on the host before re-sending'**
  String get teamUiReceiptUnconfirmed;

  /// Gate sheet primary action for a choice or free-text decision (TEAM-203)
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get teamUiGateAnswerSend;

  /// Gate sheet action answering a confirmation with yes
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get teamUiGateAnswerApprove;

  /// Gate sheet action answering a confirmation with no; two-step in the error tone
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get teamUiGateAnswerDeny;

  /// Gate sheet action closing a gate bead from the phone
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get teamUiGateAnswerMarkDone;

  /// Hint of the free-text answer field in the gate sheet
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get teamUiGateAnswerHint;

  /// Helper under the option list of a choice decision before anything is selected
  ///
  /// In en, this message translates to:
  /// **'Choose one option, then send.'**
  String get teamUiGateAnswerOptionsHint;

  /// Failed-run sheet action sending the stuck work to its agent again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teamUiGateAnswerRunRetry;

  /// Helper under the failed-run Retry action naming the work item and agent
  ///
  /// In en, this message translates to:
  /// **'Sends {work} to {agent} again.'**
  String teamUiGateAnswerRunRetryDetail(String work, String agent);

  /// Failed-run sheet action opening the agent screen where restart and reassign live
  ///
  /// In en, this message translates to:
  /// **'Restart or reassign'**
  String get teamUiGateAnswerRunAgent;

  /// Failed-run sheet action opening the agent output page
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get teamUiGateAnswerRunLogs;

  /// Failed-run sheet action cancelling the run; two-step in the error tone
  ///
  /// In en, this message translates to:
  /// **'Stop work'**
  String get teamUiGateAnswerRunCancel;

  /// Receipt action on an unconfirmed answer: sends it again under a new key
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teamUiGateAnswerRetry;

  /// Receipt action on an answer the host refused
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teamUiGateAnswerTryAgain;

  /// Receipt line when the host refused the answer, with its reason
  ///
  /// In en, this message translates to:
  /// **'Not accepted: {message}'**
  String teamUiGateAnswerRejected(String message);

  /// Receipt line when the host refused the answer without a reason
  ///
  /// In en, this message translates to:
  /// **'The host did not accept this answer.'**
  String get teamUiGateAnswerRejectedNoMessage;

  /// Trailing chip on a needs-you row whose answer is on its way
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get teamUiGateAnswerChipSent;

  /// Trailing chip on a needs-you row whose answer got no confirmation; tapping it opens the sheet to retry
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get teamUiGateAnswerChipUnconfirmed;

  /// Trailing chip on a needs-you row whose answer the host refused
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get teamUiGateAnswerChipRejected;

  /// Accessibility label of the unconfirmed chip
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed, open to retry'**
  String get teamUiGateAnswerChipUnconfirmedSemantics;

  /// Two-step sheet title before a deny is sent
  ///
  /// In en, this message translates to:
  /// **'Deny this request?'**
  String get teamUiGateAnswerConfirmDenyTitle;

  /// Two-step sheet body before a deny is sent
  ///
  /// In en, this message translates to:
  /// **'The agent is told no and goes on without it.'**
  String get teamUiGateAnswerConfirmDenyBody;

  /// Two-step sheet title before a destructive confirmation is approved
  ///
  /// In en, this message translates to:
  /// **'Approve this destructive action?'**
  String get teamUiGateAnswerConfirmApproveTitle;

  /// Two-step sheet body before a destructive confirmation is approved
  ///
  /// In en, this message translates to:
  /// **'The host marks this as destructive. It cannot be undone from the phone.'**
  String get teamUiGateAnswerConfirmApproveBody;

  /// Two-step sheet title before a failed run is cancelled
  ///
  /// In en, this message translates to:
  /// **'Stop this work?'**
  String get teamUiGateAnswerConfirmCancelRunTitle;

  /// Two-step sheet body before a failed run is cancelled
  ///
  /// In en, this message translates to:
  /// **'The run stops and its open work stays as it is.'**
  String get teamUiGateAnswerConfirmCancelRunBody;

  /// Two-step sheet dismiss label: nothing is sent
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get teamUiGateAnswerConfirmKeep;

  /// Notice while a notification or link waits for the plugin to load before the gate sheet opens
  ///
  /// In en, this message translates to:
  /// **'Opening the decision once the AI Team connects…'**
  String get teamUiGateAnswerNotificationOpening;

  /// Notice when a run-completed notification names a run the snapshot no longer has
  ///
  /// In en, this message translates to:
  /// **'This run is no longer on the host.'**
  String get teamUiGateAnswerRunGone;

  /// Title of the controls section at the end of the Agent detail (02-ux §5.2, §5.3)
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get teamUiControlSectionTitle;

  /// Button: open the composer sheet to message the agent
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get teamUiControlMessage;

  /// Button: one-tap 'please continue' to the agent
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get teamUiControlNudge;

  /// Button: keep the host from waking the agent again
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get teamUiControlPause;

  /// Button: undo Pause
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get teamUiControlResume;

  /// Button (error tone, two-step): stop the agent's session
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get teamUiControlStop;

  /// Button (error tone, two-step): stop and wake the agent's session
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get teamUiControlRestart;

  /// Button: open the picker of ready work items to move one onto this agent
  ///
  /// In en, this message translates to:
  /// **'Reassign work…'**
  String get teamUiControlReassign;

  /// Receipt name of a direct task (TEAM-306): the work item created from the phone and handed to the project's agent pool
  ///
  /// In en, this message translates to:
  /// **'Task sent to an agent'**
  String get teamUiControlCreateWork;

  /// Title of the message sheet; {agent} is the agent name
  ///
  /// In en, this message translates to:
  /// **'Message {agent}'**
  String teamUiControlMessageTitle(String agent);

  /// Hint in the message composer
  ///
  /// In en, this message translates to:
  /// **'Tell the agent what to do next'**
  String get teamUiControlMessageHint;

  /// Send button of the message composer
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get teamUiControlMessageSend;

  /// Title of the two-step Stop confirmation; {agent} is the agent name
  ///
  /// In en, this message translates to:
  /// **'Stop {agent}?'**
  String teamUiControlStopConfirmTitle(String agent);

  /// Body of the Stop confirmation
  ///
  /// In en, this message translates to:
  /// **'Its session ends now. Its work stays where it is; the host can wake it again later.'**
  String get teamUiControlStopConfirmBody;

  /// Confirming button of the Stop confirmation
  ///
  /// In en, this message translates to:
  /// **'Stop agent'**
  String get teamUiControlStopConfirmAction;

  /// Title of the two-step Restart confirmation; {agent} is the agent name
  ///
  /// In en, this message translates to:
  /// **'Restart {agent}?'**
  String teamUiControlRestartConfirmTitle(String agent);

  /// Body of the Restart confirmation
  ///
  /// In en, this message translates to:
  /// **'Its session stops and starts again. The agent loses what it had in context and picks its work up from the host.'**
  String get teamUiControlRestartConfirmBody;

  /// Confirming button of the Restart confirmation
  ///
  /// In en, this message translates to:
  /// **'Restart agent'**
  String get teamUiControlRestartConfirmAction;

  /// Back-out button of every two-step control confirmation; nothing is sent
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get teamUiControlKeep;

  /// Title of the reassign picker; {agent} is the agent name
  ///
  /// In en, this message translates to:
  /// **'Reassign work to {agent}'**
  String teamUiControlReassignTitle(String agent);

  /// Helper line of the reassign picker
  ///
  /// In en, this message translates to:
  /// **'Ready work on this host. The item you pick moves onto this agent.'**
  String get teamUiControlReassignHint;

  /// Empty state of the reassign picker
  ///
  /// In en, this message translates to:
  /// **'Nothing is ready to assign.'**
  String get teamUiControlReassignEmpty;

  /// Receipt chip: the control was sent, the host has not confirmed yet
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get teamUiControlReceiptSent;

  /// Receipt chip: the host confirmed the control
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get teamUiControlReceiptConfirmed;

  /// Receipt chip: no result in time; check on the host before re-sending
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get teamUiControlReceiptUnconfirmed;

  /// Receipt chip: the host or the front refused the control
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get teamUiControlReceiptRefused;

  /// Receipt chip text: the control's name, then its receipt state
  ///
  /// In en, this message translates to:
  /// **'{control} · {state}'**
  String teamUiControlReceiptLine(String control, String state);

  /// Button on a refused or unconfirmed receipt chip: send again under a new key
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teamUiControlReceiptRetry;

  /// Tooltip of the run app bar's overflow menu
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get teamUiControlMoreActions;

  /// Overflow item and control name: cancel a formula run (two-step)
  ///
  /// In en, this message translates to:
  /// **'Stop run'**
  String get teamUiControlCancelRun;

  /// Overflow item and control name: close a batch (Gas City convoy), two-step
  ///
  /// In en, this message translates to:
  /// **'Close batch'**
  String get teamUiControlCloseBatch;

  /// Title of the two-step Cancel run confirmation
  ///
  /// In en, this message translates to:
  /// **'Stop this run?'**
  String get teamUiControlCancelRunConfirmTitle;

  /// Body of the Cancel run confirmation
  ///
  /// In en, this message translates to:
  /// **'Running steps stop; finished work stays. The phone cannot undo this.'**
  String get teamUiControlCancelRunConfirmBody;

  /// Title of the two-step Close batch confirmation
  ///
  /// In en, this message translates to:
  /// **'Close this batch?'**
  String get teamUiControlCloseBatchConfirmTitle;

  /// Body of the Close batch confirmation
  ///
  /// In en, this message translates to:
  /// **'The batch closes on the host. Its open work items stay open for another batch.'**
  String get teamUiControlCloseBatchConfirmBody;

  /// Label of the floating action button on the AI Team home (02-ux §3, §7)
  ///
  /// In en, this message translates to:
  /// **'Start a run'**
  String get teamUiStartRunFab;

  /// Title of the Start-a-run sheet
  ///
  /// In en, this message translates to:
  /// **'Start a run'**
  String get teamUiStartRunTitle;

  /// Label of the objective field
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get teamUiStartRunObjectiveLabel;

  /// Hint of the objective field
  ///
  /// In en, this message translates to:
  /// **'What should the team achieve? One outcome, in your words.'**
  String get teamUiStartRunObjectiveHint;

  /// Validation line when Send is tapped with an empty objective
  ///
  /// In en, this message translates to:
  /// **'Write an objective first.'**
  String get teamUiStartRunObjectiveEmpty;

  /// Label of the project (rig) picker
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get teamUiStartRunProjectLabel;

  /// Default project choice: no rig named in the request
  ///
  /// In en, this message translates to:
  /// **'Let the planner choose'**
  String get teamUiStartRunProjectAny;

  /// Label of the supervision level choice
  ///
  /// In en, this message translates to:
  /// **'Supervision'**
  String get teamUiStartRunSupervisionLabel;

  /// Supervision level: High
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get teamUiStartRunSupervisionHigh;

  /// Description of the High supervision level
  ///
  /// In en, this message translates to:
  /// **'The team asks before every decision, before tests that change state and before any merge.'**
  String get teamUiStartRunSupervisionHighHint;

  /// Supervision level: Balanced
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get teamUiStartRunSupervisionBalanced;

  /// Description of the Balanced supervision level
  ///
  /// In en, this message translates to:
  /// **'The team decides routine matters itself and asks before merges, on failures and on design choices.'**
  String get teamUiStartRunSupervisionBalancedHint;

  /// Supervision level: Autonomous
  ///
  /// In en, this message translates to:
  /// **'Autonomous'**
  String get teamUiStartRunSupervisionAutonomous;

  /// Description of the Autonomous supervision level
  ///
  /// In en, this message translates to:
  /// **'The team works to completion inside the host\'s boundaries and asks only when it cannot continue.'**
  String get teamUiStartRunSupervisionAutonomousHint;

  /// Label of the read-only planner row
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get teamUiStartRunPlannerLabel;

  /// Product name of the Gas Town planner agent shown in the planner row
  ///
  /// In en, this message translates to:
  /// **'Mayor'**
  String get teamUiStartRunPlannerMayor;

  /// Helper line under the planner row
  ///
  /// In en, this message translates to:
  /// **'Set on the host; the phone shows it and does not choose it.'**
  String get teamUiStartRunPlannerHint;

  /// Primary button of the Start-a-run sheet
  ///
  /// In en, this message translates to:
  /// **'Send to planner'**
  String get teamUiStartRunSend;

  /// Shown instead of the form when the host lists the planner as suspended or stopped; nothing is sent
  ///
  /// In en, this message translates to:
  /// **'The planner (Mayor) is off on this host'**
  String get teamUiStartRunPlannerOffTitle;

  /// Body under the planner-off title
  ///
  /// In en, this message translates to:
  /// **'Wake it on the host or switch it to the full profile, then come back.'**
  String get teamUiStartRunPlannerOffBody;

  /// Shown when the host lists no planner agent at all
  ///
  /// In en, this message translates to:
  /// **'No planner on this host'**
  String get teamUiStartRunPlannerMissingTitle;

  /// Body under the planner-missing title
  ///
  /// In en, this message translates to:
  /// **'The Gas Town pack with its Mayor is not running here. The host guide shows how to enable it.'**
  String get teamUiStartRunPlannerMissingBody;

  /// Button opening the host guide sheet from the planner-off states
  ///
  /// In en, this message translates to:
  /// **'Host guide'**
  String get teamUiStartRunHostGuide;

  /// Progress line while the sheet wakes a planner without a session before sending
  ///
  /// In en, this message translates to:
  /// **'Waking the planner…'**
  String get teamUiStartRunWaking;

  /// Intro line of the direct-task form shown instead of the Start-a-run form when the planner is off and the host can create work (TEAM-306, phone lean profile)
  ///
  /// In en, this message translates to:
  /// **'The planner is off on this host. Give one task straight to the project\'s agent.'**
  String get teamUiStartRunDirectIntro;

  /// Label of the required title field of the direct-task form
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get teamUiStartRunDirectTitle;

  /// Hint inside the title field of the direct-task form
  ///
  /// In en, this message translates to:
  /// **'One line: what should the agent do?'**
  String get teamUiStartRunDirectTitleHint;

  /// Field error when Send is tapped with an empty task title
  ///
  /// In en, this message translates to:
  /// **'Write a task first.'**
  String get teamUiStartRunDirectTitleRequired;

  /// Label of the optional multi-line description field of the direct-task form
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get teamUiStartRunDirectDetails;

  /// Primary button of the direct-task form: creates the work item and assigns it to the project's agent pool
  ///
  /// In en, this message translates to:
  /// **'Send to an agent'**
  String get teamUiStartRunDirectSend;

  /// Inline error under the direct-task form when the host rejected the create
  ///
  /// In en, this message translates to:
  /// **'The host refused the task: {reason}'**
  String teamUiStartRunDirectRefused(String reason);

  /// Title of the pending card on the AI Team home after the objective was sent, until a run appears
  ///
  /// In en, this message translates to:
  /// **'Planning… (Mayor)'**
  String get teamUiStartRunPlanning;

  /// Body of the pending Planning card
  ///
  /// In en, this message translates to:
  /// **'The planner is turning the objective into work. The run appears in this list once it has.'**
  String get teamUiStartRunPlanningHint;

  /// Title of the pending card after 30 minutes without a run
  ///
  /// In en, this message translates to:
  /// **'Still planning — check the planner\'s output'**
  String get teamUiStartRunStillPlanning;

  /// Pending card line when the host never confirmed the message
  ///
  /// In en, this message translates to:
  /// **'Sent, unconfirmed — check the planner\'s output before sending again'**
  String get teamUiStartRunUnconfirmed;

  /// Pending card line when the host or the front refused; {reason} is the host's text
  ///
  /// In en, this message translates to:
  /// **'The host refused the objective: {reason}'**
  String teamUiStartRunRefused(String reason);

  /// Button on the pending card opening the planner's live output page
  ///
  /// In en, this message translates to:
  /// **'Planner output'**
  String get teamUiStartRunPlannerOutput;

  /// Button on the pending card hiding it for good
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get teamUiStartRunDismiss;

  /// Pending card footer; {time} is a clock time
  ///
  /// In en, this message translates to:
  /// **'Sent {time}'**
  String teamUiStartRunSentAt(String time);

  /// Header of the run Overview's Merge section when every readiness line is ok (02-ux §8a)
  ///
  /// In en, this message translates to:
  /// **'Ready to merge'**
  String get teamUiMergeTitleReady;

  /// Header of the Merge section while a readiness line is missing
  ///
  /// In en, this message translates to:
  /// **'Not ready to merge'**
  String get teamUiMergeTitleNotReady;

  /// Header of the Merge section once the host reports the run's branches are on the target branch
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get teamUiMergeTitleMerged;

  /// Suffix after the Merge header naming the merge request bead
  ///
  /// In en, this message translates to:
  /// **'merge request {id}'**
  String teamUiMergeRequest(String id);

  /// Readiness line: every tracked work item is done or review-ready
  ///
  /// In en, this message translates to:
  /// **'Work items'**
  String get teamUiMergeLineWork;

  /// Readiness line: the host's test command
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get teamUiMergeLineTests;

  /// Readiness line: the host's build command
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get teamUiMergeLineBuild;

  /// Readiness line: review done or approved
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get teamUiMergeLineReview;

  /// Readiness line: the branches merge cleanly into the target
  ///
  /// In en, this message translates to:
  /// **'No conflicts'**
  String get teamUiMergeLineConflicts;

  /// Readiness line: no work item reported a failed validation
  ///
  /// In en, this message translates to:
  /// **'Acceptance criteria'**
  String get teamUiMergeLineAcceptance;

  /// Changed-file count with added and removed line totals under the readiness lines
  ///
  /// In en, this message translates to:
  /// **'{files, plural, =0{No file changes} =1{1 file · +{additions} / −{deletions}} other{{files} files · +{additions} / −{deletions}}}'**
  String teamUiMergeFiles(int files, int additions, int deletions);

  /// Button opening the list of changed files and the run's work items
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get teamUiMergeReviewChanges;

  /// Button approving the merge request (one confirmation)
  ///
  /// In en, this message translates to:
  /// **'Approve request'**
  String get teamUiMergeApprove;

  /// Title of the one-step Approve confirmation
  ///
  /// In en, this message translates to:
  /// **'Approve this merge request?'**
  String get teamUiMergeApproveTitle;

  /// Body of the Approve confirmation
  ///
  /// In en, this message translates to:
  /// **'Your approval is recorded on the host. Merging is a separate step.'**
  String get teamUiMergeApproveMessage;

  /// Line under the buttons once the host recorded an approval
  ///
  /// In en, this message translates to:
  /// **'Approved by {login}'**
  String teamUiMergeApprovedBy(String login);

  /// The Merge button (first of two steps)
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get teamUiMergeMerge;

  /// The Merge button once armed by the first tap (second step opens the confirmation)
  ///
  /// In en, this message translates to:
  /// **'Confirm merge'**
  String get teamUiMergeConfirmStep;

  /// Helper text while the Merge button is armed
  ///
  /// In en, this message translates to:
  /// **'Tap again to continue'**
  String get teamUiMergeArmedHint;

  /// Title of the Merge confirmation sheet, naming the target branch
  ///
  /// In en, this message translates to:
  /// **'Merge into {branch}?'**
  String teamUiMergeConfirmTitle(String branch);

  /// Body of the Merge confirmation sheet (02-ux §8a exact copy)
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone from the phone'**
  String get teamUiMergeConfirmMessage;

  /// Confirm button of the Merge confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Merge into {branch}'**
  String teamUiMergeConfirmAction(String branch);

  /// Helper text under a disabled Merge button naming the missing readiness line and the host's detail
  ///
  /// In en, this message translates to:
  /// **'Merge is off: {line} — {detail}'**
  String teamUiMergeDisabledReason(String line, String detail);

  /// Helper text naming the host boundary that blocks the merge, shown rather than silently applied
  ///
  /// In en, this message translates to:
  /// **'Host boundary: {text}'**
  String teamUiMergeBoundary(String text);

  /// Receipt line when the host rejected the merge or the approval
  ///
  /// In en, this message translates to:
  /// **'The host refused: {text}'**
  String teamUiMergeRefused(String text);

  /// Receipt line after a confirmed merge, with the short commit id
  ///
  /// In en, this message translates to:
  /// **'Merged into {branch} · {commit}'**
  String teamUiMergeMerged(String branch, String commit);

  /// Line when nothing is left to merge
  ///
  /// In en, this message translates to:
  /// **'Already on {branch}'**
  String teamUiMergeAlready(String branch);

  /// Line when the host's readiness could not be read
  ///
  /// In en, this message translates to:
  /// **'Merge readiness unavailable: {reason}'**
  String teamUiMergeUnavailable(String reason);

  /// Line when the host answered that it cannot merge this run (no rig, origin or default branch)
  ///
  /// In en, this message translates to:
  /// **'The host has no merge roles for this run'**
  String get teamUiMergeNoRoles;

  /// Line while the readiness document loads
  ///
  /// In en, this message translates to:
  /// **'Checking merge readiness…'**
  String get teamUiMergeLoading;

  /// Detail of a readiness line the host is still computing
  ///
  /// In en, this message translates to:
  /// **'running on the host'**
  String get teamUiMergePending;

  /// Title of the Review changes sheet
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get teamUiMergeChangesTitle;

  /// Empty state of the Review changes sheet
  ///
  /// In en, this message translates to:
  /// **'No file changes reported by the host'**
  String get teamUiMergeChangesEmpty;

  /// Section title of the run's work items in the Review changes sheet
  ///
  /// In en, this message translates to:
  /// **'Work items'**
  String get teamUiMergeChangesWork;

  /// Per-file added and removed line counts in the Review changes sheet
  ///
  /// In en, this message translates to:
  /// **'+{additions} / −{deletions}'**
  String teamUiMergeChangeCounts(int additions, int deletions);

  /// Receipt state of an approval or merge in flight
  ///
  /// In en, this message translates to:
  /// **'Sent · waiting for the host to confirm'**
  String get teamUiMergeSent;

  /// Receipt state once the host confirmed the approval
  ///
  /// In en, this message translates to:
  /// **'Approval recorded'**
  String get teamUiMergeApproveConfirmed;

  /// Read-only line on the run overview naming the host's supervision level (TEAM-207); level is the localised level name
  ///
  /// In en, this message translates to:
  /// **'Supervision · {level}'**
  String teamUiPolicySupervision(String level);

  /// Label of the read-only boundaries list (host policy) on the run overview and the Start-a-run sheet
  ///
  /// In en, this message translates to:
  /// **'Boundaries'**
  String get teamUiPolicyBoundariesLabel;

  /// Boundaries row when the host reports none
  ///
  /// In en, this message translates to:
  /// **'No boundaries set on the host'**
  String get teamUiPolicyBoundariesNone;

  /// Helper under the policy block: the level and boundaries come from the host's config and cannot be changed from the phone
  ///
  /// In en, this message translates to:
  /// **'Set on the host · read-only here'**
  String get teamUiPolicyFromHost;

  /// Suffix naming the rig (project) the policy applies to
  ///
  /// In en, this message translates to:
  /// **'for {rig}'**
  String teamUiPolicyRig(String rig);

  /// Screen-reader label of the whole policy block
  ///
  /// In en, this message translates to:
  /// **'Supervision {level}. Boundaries: {boundaries}'**
  String teamUiPolicySemantics(String level, String boundaries);

  /// AI Team home, under the Runs list: switch that reveals the host's own housekeeping runs (patrols, chores), hidden by default; count is how many there are
  ///
  /// In en, this message translates to:
  /// **'Show team upkeep ({count})'**
  String teamUiHomeUpkeepToggle(int count);

  /// One line under the Show team upkeep switch saying what upkeep runs are
  ///
  /// In en, this message translates to:
  /// **'Patrols and chores the host runs for itself'**
  String get teamUiHomeUpkeepHint;

  /// AI Team home Agents list: the collapsed group of agents switched off (suspended or stopped) on the host; count is how many
  ///
  /// In en, this message translates to:
  /// **'Suspended on the host ({count})'**
  String teamUiHomeSuspendedGroup(int count);

  /// Agents segment label when some agents are switched off on the host: count is the live agents, off the suspended or stopped ones
  ///
  /// In en, this message translates to:
  /// **'Agents ({count} · {off} off)'**
  String teamUiHomeSegmentAgentsOff(int count, int off);

  /// The host part of the AI Team home chip: the host's name or address from the team URL, then the kind of computer word (Desktop computer, Laptop, Windows (WSL), This phone)
  ///
  /// In en, this message translates to:
  /// **'{host} · {kind}'**
  String teamUiHomeHostChipHost(String host, String kind);

  /// Run Technical details: the host's own title of the run (a convoy's sling-<id> name) when the product shows the work's title instead
  ///
  /// In en, this message translates to:
  /// **'Provider title'**
  String get teamUiRunLabelRawTitle;

  /// Dispatch cycle strip (TEAM-116), step 1: the host chose an agent pool for the work item
  ///
  /// In en, this message translates to:
  /// **'Routed'**
  String get teamUiCycleStepRouted;

  /// Dispatch cycle step 2: a session of the routed pool is waking on the host
  ///
  /// In en, this message translates to:
  /// **'Agent starting'**
  String get teamUiCycleStepAgentStarting;

  /// Dispatch cycle step 3: the agent took the work item
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get teamUiCycleStepClaimed;

  /// Dispatch cycle step 4: the agent is editing in its worktree
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get teamUiCycleStepWorking;

  /// Dispatch cycle step 5: the change is on a branch
  ///
  /// In en, this message translates to:
  /// **'Pushed'**
  String get teamUiCycleStepPushed;

  /// Dispatch cycle step 6: the merge agent (Gas City refinery) owns the branch
  ///
  /// In en, this message translates to:
  /// **'Handed to merge'**
  String get teamUiCycleStepHandedToMerge;

  /// Dispatch cycle end mark: the branch merged and the item closed
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get teamUiCycleStepMerged;

  /// Dispatch cycle hint under Agent starting while it is the current step: the host polls, so a few minutes is normal
  ///
  /// In en, this message translates to:
  /// **'Waiting for an agent · usually 1–5 min'**
  String get teamUiCycleWaitingForAgent;

  /// Dispatch cycle compact line on the Workspace card: the current step word and the HH:MM the wait began
  ///
  /// In en, this message translates to:
  /// **'{step} · since {time}'**
  String teamUiCycleCurrent(String step, String time);

  /// Dispatch cycle: under the current step, the HH:MM the wait began
  ///
  /// In en, this message translates to:
  /// **'since {time}'**
  String teamUiCycleSince(String time);

  /// Screen-reader label of the dispatch cycle strip: one-based position of the current step, the number of steps (6), the step word, the HH:MM the wait began
  ///
  /// In en, this message translates to:
  /// **'Step {position} of {total}, {step}, since {time}'**
  String teamUiCycleSemantics(
    int position,
    int total,
    String step,
    String time,
  );

  /// Screen-reader label of the dispatch cycle strip when no time is known
  ///
  /// In en, this message translates to:
  /// **'Step {position} of {total}, {step}'**
  String teamUiCycleSemanticsNoTime(int position, int total, String step);

  /// Screen-reader label of the dispatch cycle strip once the item merged
  ///
  /// In en, this message translates to:
  /// **'All {total} steps done, merged at {time}'**
  String teamUiCycleSemanticsMerged(int total, String time);

  /// Dispatch cycle stall: routed for over three minutes without an agent starting
  ///
  /// In en, this message translates to:
  /// **'The host has not started an agent yet'**
  String get teamUiCycleStallHostNotStarted;

  /// Dispatch cycle stall: the agent session woke and stopped again twice or more within a minute
  ///
  /// In en, this message translates to:
  /// **'The agent could not start on the host'**
  String get teamUiCycleStallAgentCannotStart;

  /// Dispatch cycle stall: the agent transcript says the model provider hit a usage limit, quota or rate limit
  ///
  /// In en, this message translates to:
  /// **'The model provider reached its usage limit'**
  String get teamUiCycleStallProviderLimit;

  /// Dispatch cycle stall: working for over thirty minutes with nothing pushed
  ///
  /// In en, this message translates to:
  /// **'Still working — check the agent\'s output'**
  String get teamUiCycleStallWorkingLong;

  /// Dispatch cycle stall: handed to merge over fifteen minutes ago and not merged
  ///
  /// In en, this message translates to:
  /// **'Waiting for the merge agent'**
  String get teamUiCycleStallMergeWaiting;

  /// Dispatch cycle action and sheet title: opens three lines explaining the host's polling chain
  ///
  /// In en, this message translates to:
  /// **'How the host dispatches'**
  String get teamUiCycleActionHow;

  /// Dispatch cycle action: opens the agent output screen for the agent on the item
  ///
  /// In en, this message translates to:
  /// **'Open agent output'**
  String get teamUiCycleActionOpenOutput;

  /// Dispatch cycle action: nudges the rig's merge agent (Gas City refinery); refinery is the Gas City term
  ///
  /// In en, this message translates to:
  /// **'Nudge refinery'**
  String get teamUiCycleActionNudgeRefinery;

  /// How the host dispatches sheet, line 1 of 3: the beads cache pass (up to 60 s)
  ///
  /// In en, this message translates to:
  /// **'The host checks for new work about once a minute and routes it to an agent pool.'**
  String get teamUiCycleHowLine1;

  /// How the host dispatches sheet, line 2 of 3: the patrol tick and the ACP start
  ///
  /// In en, this message translates to:
  /// **'A patrol every 30 seconds wakes an agent within its wake budget; the agent\'s harness takes 5–10 seconds to start.'**
  String get teamUiCycleHowLine2;

  /// How the host dispatches sheet, line 3 of 3: the first model turn and the normal total
  ///
  /// In en, this message translates to:
  /// **'The first model turn takes 10–60 seconds before the agent claims the work, so 2–6 minutes from routed to claimed is normal.'**
  String get teamUiCycleHowLine3;

  /// How the host dispatches sheet: the button that closes it
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get teamUiCycleHowClose;

  /// Settings › Termux server › Storage: screen title
  ///
  /// In en, this message translates to:
  /// **'Storage on this phone'**
  String get termuxStorageTitle;

  /// Settings entry row subtitle: bytes the phone server uses
  ///
  /// In en, this message translates to:
  /// **'{size} used'**
  String termuxStorageRowUsed(String size);

  /// Settings entry row subtitle before the first scan
  ///
  /// In en, this message translates to:
  /// **'Not scanned yet'**
  String get termuxStorageRowNotScanned;

  /// Settings entry row subtitle while a scan runs
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get termuxStorageRowScanning;

  /// Primary button that starts the first scan
  ///
  /// In en, this message translates to:
  /// **'Scan storage'**
  String get termuxStorageScanAction;

  /// Button that starts a fresh scan when a report exists
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get termuxStorageRescanAction;

  /// Storage screen: paragraph before the first scan
  ///
  /// In en, this message translates to:
  /// **'See the storage used by Termux, including the local server and other tools. Expand a category to inspect it. Only selected regenerable caches can be cleaned here; projects, team data, sign-ins and conversation history stay in place.'**
  String get termuxStorageIntro;

  /// Storage screen: heading while a scan runs
  ///
  /// In en, this message translates to:
  /// **'Measuring storage'**
  String get termuxStorageScanning;

  /// Storage screen: line under the scanning heading
  ///
  /// In en, this message translates to:
  /// **'Large caches take a minute or two. You can leave this screen; the scan keeps going.'**
  String get termuxStorageScanningDetail;

  /// Button that cancels a running scan
  ///
  /// In en, this message translates to:
  /// **'Stop scan'**
  String get termuxStorageCancel;

  /// Status line after a cancelled scan
  ///
  /// In en, this message translates to:
  /// **'Scan stopped'**
  String get termuxStorageCancelled;

  /// Status line after a failed scan
  ///
  /// In en, this message translates to:
  /// **'The scan did not finish. Try again.'**
  String get termuxStorageFailed;

  /// Storage report headline
  ///
  /// In en, this message translates to:
  /// **'{size} measured in Termux'**
  String termuxStorageTotal(String size);

  /// Storage report: sum of the deletable categories
  ///
  /// In en, this message translates to:
  /// **'{size} can be cleaned'**
  String termuxStorageDeletableTotal(String size);

  /// Storage report: scan age under a minute
  ///
  /// In en, this message translates to:
  /// **'Scanned just now'**
  String get termuxStorageScannedJustNow;

  /// Storage report: scan age in minutes
  ///
  /// In en, this message translates to:
  /// **'Scanned {minutes} min ago'**
  String termuxStorageScannedMinutesAgo(int minutes);

  /// Storage report: scan age in hours
  ///
  /// In en, this message translates to:
  /// **'Scanned {hours} h ago'**
  String termuxStorageScannedHoursAgo(int hours);

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'Build caches'**
  String get termuxStorageCatBuildCaches;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'Gradle caches and npm’s downloaded content cache only. Downloads may be needed again, so offline builds can be affected. Stop builds and package installs before cleaning.'**
  String get termuxStorageNoteBuildCaches;

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'Agent scratch'**
  String get termuxStorageCatAgentScratch;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'Temporary folders may contain unfinished work or files used by other tools. Their sizes are shown for reference; they cannot be removed here.'**
  String get termuxStorageNoteAgentScratch;

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'Folders with build-related names'**
  String get termuxStorageCatProjectBuildOutputs;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'Folders named build, .dart_tool, node_modules or target may also contain your files. Names alone cannot prove they are disposable, so they cannot be removed here.'**
  String get termuxStorageNoteProjectBuildOutputs;

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'Toolchains'**
  String get termuxStorageCatToolchains;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'Android SDK, Java and Flutter installations. These may support other projects and cannot be removed here.'**
  String get termuxStorageNoteToolchains;

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'AI Team'**
  String get termuxStorageCatAiTeam;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'Team folders, databases and tools may contain work you need to keep. They cannot be removed here, even when the team is stopped.'**
  String get termuxStorageNoteAiTeam;

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'OpenCode itself'**
  String get termuxStorageCatOpenCode;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'The server, its sign-ins and conversation history. Not removed from here; conversations have their own screen.'**
  String get termuxStorageNoteOpenCode;

  /// Storage category
  ///
  /// In en, this message translates to:
  /// **'Projects (your files)'**
  String get termuxStorageCatProjects;

  /// Storage category note
  ///
  /// In en, this message translates to:
  /// **'Listed so you can see their size. Never removed from here.'**
  String get termuxStorageNoteProjects;

  /// Storage category: heading over the path list
  ///
  /// In en, this message translates to:
  /// **'What Clean removes'**
  String get termuxStorageWillRemove;

  /// Storage category with no paths
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get termuxStorageNothingHere;

  /// Storage category that cannot be cleaned
  ///
  /// In en, this message translates to:
  /// **'Not removed from here'**
  String get termuxStorageNotDeletable;

  /// Button that cleans one category
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get termuxStorageClean;

  /// Accessibility label of the Clean button
  ///
  /// In en, this message translates to:
  /// **'Clean {category}, {size}'**
  String termuxStorageCleanSemantics(String category, String size);

  /// Two-step confirmation title for cleaning over a gigabyte
  ///
  /// In en, this message translates to:
  /// **'Delete {size} of {category}?'**
  String termuxStorageCleanConfirmTitle(String size, String category);

  /// Two-step confirmation body for cleaning
  ///
  /// In en, this message translates to:
  /// **'Delete only the listed Gradle and npm content caches? Downloads may be needed again and offline builds can be affected. Stop builds and package installs first. Scan again afterward to update the measured sizes.'**
  String get termuxStorageCleanConfirmBody;

  /// Two-step confirmation button
  ///
  /// In en, this message translates to:
  /// **'Delete {size}'**
  String termuxStorageCleanConfirm(String size);

  /// Two-step confirmation cancel button
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get termuxStorageKeep;

  /// Status while a clean runs
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get termuxStorageCleaning;

  /// Result line after a clean
  ///
  /// In en, this message translates to:
  /// **'Removed {size}'**
  String termuxStorageFreed(String size);

  /// Result line after a clean that removed nothing
  ///
  /// In en, this message translates to:
  /// **'Nothing was removed'**
  String get termuxStorageFreedNothing;

  /// Clean refused because a process is using the category
  ///
  /// In en, this message translates to:
  /// **'In use by {process}. Stop it under Running now first.'**
  String termuxStorageInUse(String process);

  /// Clean result: paths the script refused to remove
  ///
  /// In en, this message translates to:
  /// **'{count} paths were left in place'**
  String termuxStorageRefusedCount(int count);

  /// Project row subtitle
  ///
  /// In en, this message translates to:
  /// **'{size} · {build} in build-related folders'**
  String termuxStorageProjectBuild(String size, String build);

  /// Action that opens the process screen
  ///
  /// In en, this message translates to:
  /// **'Open Running now'**
  String get termuxStorageOpenRunning;

  /// Byte formatting: gigabytes
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String termuxStorageBytesGb(String value);

  /// Byte formatting: megabytes
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String termuxStorageBytesMb(String value);

  /// Byte formatting: kilobytes
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String termuxStorageBytesKb(String value);

  /// Byte formatting: bytes
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String termuxStorageBytesB(String value);

  /// Settings section label above the Storage and Running now rows
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get termuxStorageOnThisPhone;

  /// Error when the scan status cannot be read
  ///
  /// In en, this message translates to:
  /// **'Could not read the storage scan.'**
  String get termuxStorageReadFailed;

  /// Settings › Termux server › Running now: screen title
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get termuxProcsTitle;

  /// Settings entry row subtitle and the screen headline
  ///
  /// In en, this message translates to:
  /// **'{count} processes · CPU {cpu}%'**
  String termuxProcsRowSubtitle(int count, String cpu);

  /// Settings entry row subtitle while the list loads
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get termuxProcsRowLoading;

  /// Settings entry row subtitle when the list cannot be read
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get termuxProcsRowUnavailable;

  /// Refresh action
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get termuxProcsRefresh;

  /// Line under the headline
  ///
  /// In en, this message translates to:
  /// **'Refreshes every 10 seconds while open'**
  String get termuxProcsAutoRefresh;

  /// Process group
  ///
  /// In en, this message translates to:
  /// **'OpenCode server'**
  String get termuxProcsGroupOpenCode;

  /// Process group
  ///
  /// In en, this message translates to:
  /// **'AI Team'**
  String get termuxProcsGroupAiTeam;

  /// Process group
  ///
  /// In en, this message translates to:
  /// **'Build daemons'**
  String get termuxProcsGroupBuild;

  /// Process group
  ///
  /// In en, this message translates to:
  /// **'Orphans'**
  String get termuxProcsGroupOrphans;

  /// Process group
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get termuxProcsGroupOther;

  /// Under the OpenCode server group instead of a Stop all button
  ///
  /// In en, this message translates to:
  /// **'Managed from On this phone'**
  String get termuxProcsGroupOpenCodeHint;

  /// Under the Orphans group heading
  ///
  /// In en, this message translates to:
  /// **'Helpers whose parent is gone, or that keep burning CPU with nothing waiting on them. Stopping them is safe.'**
  String get termuxProcsOrphansHint;

  /// Button that stops every process in a group
  ///
  /// In en, this message translates to:
  /// **'Stop all'**
  String get termuxProcsStopGroup;

  /// Two-step confirmation title for a group stop
  ///
  /// In en, this message translates to:
  /// **'Stop every process in {group}?'**
  String termuxProcsStopGroupTitle(String group);

  /// Two-step confirmation body for a group stop
  ///
  /// In en, this message translates to:
  /// **'{count} processes get a polite stop, then a forced one after 5 seconds.'**
  String termuxProcsStopGroupBody(int count);

  /// Two-step confirmation button for a group stop
  ///
  /// In en, this message translates to:
  /// **'Stop {count}'**
  String termuxProcsStopConfirm(int count);

  /// Button that stops one process
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get termuxProcsStop;

  /// Accessibility label of a row's Stop button
  ///
  /// In en, this message translates to:
  /// **'Stop {name}'**
  String termuxProcsStopSemantics(String name);

  /// Two-step confirmation title for one process
  ///
  /// In en, this message translates to:
  /// **'Stop {name}?'**
  String termuxProcsStopOneTitle(String name);

  /// Two-step confirmation body for one process
  ///
  /// In en, this message translates to:
  /// **'It gets a polite stop, then a forced one after 5 seconds.'**
  String get termuxProcsStopOneBody;

  /// Two-step confirmation cancel button
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get termuxProcsKeep;

  /// Row subtitle for sshd and opencode serve
  ///
  /// In en, this message translates to:
  /// **'Protected · open On this phone'**
  String get termuxProcsProtected;

  /// Orphan reason line
  ///
  /// In en, this message translates to:
  /// **'Its parent is gone · running for {elapsed}'**
  String termuxProcsOrphanParentGone(String elapsed);

  /// Orphan reason line
  ///
  /// In en, this message translates to:
  /// **'{cpu} of CPU with no owner'**
  String termuxProcsOrphanCpu(String cpu);

  /// Row subtitle: CPU, memory, elapsed
  ///
  /// In en, this message translates to:
  /// **'CPU {cpu}% · {memory} · {elapsed}'**
  String termuxProcsStats(String cpu, String memory, String elapsed);

  /// Status while a stop runs
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get termuxProcsStopping;

  /// Result line after a stop
  ///
  /// In en, this message translates to:
  /// **'Stopped {count}'**
  String termuxProcsStopped(int count);

  /// Result line after a stop with forced kills
  ///
  /// In en, this message translates to:
  /// **'Stopped {count} ({forced} needed a forced stop)'**
  String termuxProcsStoppedForced(int count, int forced);

  /// Result line: processes that survived KILL
  ///
  /// In en, this message translates to:
  /// **'{count} would not stop'**
  String termuxProcsRemaining(int count);

  /// Result line: refused protected processes
  ///
  /// In en, this message translates to:
  /// **'{count} protected, not stopped'**
  String termuxProcsRefused(int count);

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Nothing is running in the phone server'**
  String get termuxProcsEmpty;

  /// Error state
  ///
  /// In en, this message translates to:
  /// **'Could not read the process list.'**
  String get termuxProcsFailed;

  /// Workspace line when an orphan has burned over ten minutes of CPU
  ///
  /// In en, this message translates to:
  /// **'Something is still running on this phone'**
  String get termuxProcsAttentionLine;

  /// Workspace line detail
  ///
  /// In en, this message translates to:
  /// **'{name} has used {cpu} of CPU with nothing waiting on it'**
  String termuxProcsAttentionDetail(String name, String cpu);

  /// Process detail sheet: command label
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get termuxProcsCommand;

  /// Process detail sheet: working directory label
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get termuxProcsFolder;

  /// Process detail sheet: identifiers
  ///
  /// In en, this message translates to:
  /// **'PID {pid} · parent {ppid}'**
  String termuxProcsPid(int pid, int ppid);

  /// Duration: seconds
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String termuxProcsDurationSeconds(int seconds);

  /// Duration: minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String termuxProcsDurationMinutes(int minutes);

  /// Duration: hours and minutes
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String termuxProcsDurationHours(int hours, int minutes);

  /// Memory in megabytes
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String termuxProcsMemoryMb(int mb);

  /// On-device AI Team block: eyebrow label
  ///
  /// In en, this message translates to:
  /// **'Optional · experimental'**
  String get teamUiPhoneOptionalTag;

  /// On-device AI Team block: title
  ///
  /// In en, this message translates to:
  /// **'Also run an AI team on this phone'**
  String get teamUiPhoneOfferTitle;

  /// On-device AI Team block: body
  ///
  /// In en, this message translates to:
  /// **'Lets several coding agents work on your project while you supervise from Work. Uses the same Linux environment you just set up.'**
  String get teamUiPhoneOfferBody;

  /// On-device AI Team block: download size line
  ///
  /// In en, this message translates to:
  /// **'Downloads about {size} MB (Gas City, beads and Dolt, built for Android).'**
  String teamUiPhoneOfferSize(int size);

  /// On-device AI Team block: lifecycle warning
  ///
  /// In en, this message translates to:
  /// **'Keep Termux open or hold its wake lock while the team works; Android may stop it in the background. Nothing is lost; runs resume when you start it again.'**
  String get teamUiPhoneOfferWarning;

  /// On-device AI Team block: primary (skip) action
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get teamUiPhoneSkip;

  /// On-device AI Team block: set-up action
  ///
  /// In en, this message translates to:
  /// **'Set up AI team'**
  String get teamUiPhoneSetUp;

  /// On-device setup step 1
  ///
  /// In en, this message translates to:
  /// **'Download & verify'**
  String get teamUiPhoneStepDownload;

  /// On-device setup step 2
  ///
  /// In en, this message translates to:
  /// **'Install prerequisites'**
  String get teamUiPhoneStepPackages;

  /// On-device setup step 3
  ///
  /// In en, this message translates to:
  /// **'Create a city next to the project'**
  String get teamUiPhoneStepCity;

  /// On-device setup step 4
  ///
  /// In en, this message translates to:
  /// **'Start the supervisor on this phone'**
  String get teamUiPhoneStepStart;

  /// On-device setup step 5
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get teamUiPhoneStepConnect;

  /// On-device setup: the steps keep running while away
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen and return to check progress.'**
  String get teamUiPhoneLeaveNote;

  /// On-device setup: which project folder the city is created next to
  ///
  /// In en, this message translates to:
  /// **'Project: {path}'**
  String teamUiPhoneProjectLine(String path);

  /// On-device setup: project picker title
  ///
  /// In en, this message translates to:
  /// **'Choose a project'**
  String get teamUiPhoneChooseProjectTitle;

  /// On-device setup: project picker body
  ///
  /// In en, this message translates to:
  /// **'The team works on one project folder of the phone server. The first agent commits to a git origin created next to it.'**
  String get teamUiPhoneChooseProjectBody;

  /// On-device setup: project picker when the server has no folders
  ///
  /// In en, this message translates to:
  /// **'No project folder yet. Name one and it will be created under {directory}.'**
  String teamUiPhoneNoProjects(String directory);

  /// On-device setup: new project folder field label
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get teamUiPhoneNewFolderLabel;

  /// On-device setup: create the folder and start the setup
  ///
  /// In en, this message translates to:
  /// **'Create and continue'**
  String get teamUiPhoneCreateAndContinue;

  /// On-device setup: continue with the chosen project
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get teamUiPhoneContinue;

  /// On-device setup: heading while the steps run
  ///
  /// In en, this message translates to:
  /// **'Setting up the AI team'**
  String get teamUiPhoneSetupRunning;

  /// On-device setup: success card title
  ///
  /// In en, this message translates to:
  /// **'AI team is running on this phone'**
  String get teamUiPhoneSuccessTitle;

  /// On-device setup: success card agent count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no agents yet} =1{1 agent ready} other{{count} agents ready}}'**
  String teamUiPhoneAgentsReady(int count);

  /// On-device setup: success card action
  ///
  /// In en, this message translates to:
  /// **'Open Work'**
  String get teamUiPhoneOpenWorkspace;

  /// On-device setup: retry after a failure
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get teamUiPhoneRetry;

  /// On-device setup: failure heading
  ///
  /// In en, this message translates to:
  /// **'The AI team could not be set up.'**
  String get teamUiPhoneFailedTitle;

  /// On-device setup: checksum mismatch failure
  ///
  /// In en, this message translates to:
  /// **'The downloaded {name} did not match the checksum this build pins, so it was not installed. Nothing from it was kept; check the network and try again.'**
  String teamUiPhoneFailedChecksum(String name);

  /// On-device setup: unsupported architecture failure
  ///
  /// In en, this message translates to:
  /// **'This phone\'s processor is not 64-bit ARM, which the team runtime needs.'**
  String get teamUiPhoneFailedUnsupportedArch;

  /// On-device setup: download failure
  ///
  /// In en, this message translates to:
  /// **'The download did not finish. Check the connection and try again.'**
  String get teamUiPhoneFailedDownload;

  /// On-device setup: package install failure
  ///
  /// In en, this message translates to:
  /// **'Termux could not install the prerequisites (libicu, git, jq, tmux). The output below says which.'**
  String get teamUiPhoneFailedPackages;

  /// On-device setup: project failure
  ///
  /// In en, this message translates to:
  /// **'The project folder is missing or is not a git repository.'**
  String get teamUiPhoneFailedProject;

  /// On-device setup: gc init failure
  ///
  /// In en, this message translates to:
  /// **'Gas City could not create the city. The output below says why.'**
  String get teamUiPhoneFailedCity;

  /// On-device setup: supervisor exited
  ///
  /// In en, this message translates to:
  /// **'The supervisor stopped right after starting. The output below says why.'**
  String get teamUiPhoneFailedSupervisorExited;

  /// On-device setup: health timeout failure
  ///
  /// In en, this message translates to:
  /// **'The supervisor started but never answered on {url}.'**
  String teamUiPhoneFailedHealth(String url);

  /// On-device setup: interrupted failure
  ///
  /// In en, this message translates to:
  /// **'The setup stopped before it finished. Android may have stopped Termux while the app was away; nothing is lost.'**
  String get teamUiPhoneFailedInterrupted;

  /// On-device setup: raw failure reason
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String teamUiPhoneFailedReason(String reason);

  /// On-device setup: the bridge could not dispatch a verb
  ///
  /// In en, this message translates to:
  /// **'Termux did not start the step. Open Termux once, then try again.'**
  String get teamUiPhoneDispatchFailed;

  /// Settings › Plugins › AI Team: section title for the phone-hosted team
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get teamUiPhoneSectionTitle;

  /// On this phone: status while reading
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get teamUiPhoneStatusChecking;

  /// On this phone: status
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get teamUiPhoneStatusNotInstalled;

  /// On this phone: status after install, before init
  ///
  /// In en, this message translates to:
  /// **'Installed · no city yet'**
  String get teamUiPhoneStatusInstalled;

  /// On this phone: status
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get teamUiPhoneStatusStopped;

  /// On this phone: status
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get teamUiPhoneStatusStarting;

  /// On this phone: status
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get teamUiPhoneStatusStopping;

  /// On this phone: a verb is running
  ///
  /// In en, this message translates to:
  /// **'Working… ({verb})'**
  String teamUiPhoneStatusWorking(String verb);

  /// On this phone: running status with the agent count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Running} =1{Running · 1 agent} other{Running · {count} agents}}'**
  String teamUiPhoneStatusRunning(int count);

  /// On this phone: status after a failure
  ///
  /// In en, this message translates to:
  /// **'Not running · the last step failed'**
  String get teamUiPhoneStatusFailed;

  /// On this phone: the supervisor process is up but its health check fails
  ///
  /// In en, this message translates to:
  /// **'Started, but not answering on {url}'**
  String teamUiPhoneStatusUnreachable(String url);

  /// On this phone: status unreadable
  ///
  /// In en, this message translates to:
  /// **'Status could not be read'**
  String get teamUiPhoneStatusUnknown;

  /// On this phone: installed versions line
  ///
  /// In en, this message translates to:
  /// **'gc {gc} · bd {bd} · dolt {dolt}'**
  String teamUiPhoneVersions(String gc, String bd, String dolt);

  /// On this phone: start action
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get teamUiPhoneStart;

  /// On this phone: stop action
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get teamUiPhoneStop;

  /// On this phone: stop confirmation title
  ///
  /// In en, this message translates to:
  /// **'Stop the team on this phone?'**
  String get teamUiPhoneStopTitle;

  /// On this phone: stop confirmation body
  ///
  /// In en, this message translates to:
  /// **'Running agents stop where they are. Nothing is lost; runs resume when you start it again.'**
  String get teamUiPhoneStopBody;

  /// On this phone: stop confirmation action
  ///
  /// In en, this message translates to:
  /// **'Stop team'**
  String get teamUiPhoneStopConfirm;

  /// On this phone: killed by Android line (03-onboarding §5)
  ///
  /// In en, this message translates to:
  /// **'Android stopped the team while the app was away. Nothing is lost.'**
  String get teamUiPhoneKilled;

  /// On this phone: restart after Android killed the team
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get teamUiPhoneStartAgain;

  /// On this phone: tips row title
  ///
  /// In en, this message translates to:
  /// **'Keep it running'**
  String get teamUiPhoneKeepRunningTitle;

  /// On this phone: tips row subtitle
  ///
  /// In en, this message translates to:
  /// **'Wake lock, battery setting and the phantom process killer'**
  String get teamUiPhoneKeepRunningSubtitle;

  /// Keep it running sheet: intro
  ///
  /// In en, this message translates to:
  /// **'Android stops background work it considers excessive, and the team is exactly that: dozens of short gc and bd processes and an agent at full CPU. Three things keep it alive.'**
  String get teamUiPhoneTipsIntro;

  /// Keep it running sheet: wake lock tip
  ///
  /// In en, this message translates to:
  /// **'Keep Termux in front, or hold its wake lock: run termux-wake-lock in Termux, or tap Acquire wakelock in its notification. Screen off without it ends the run.'**
  String get teamUiPhoneTipWakeLock;

  /// Keep it running sheet: battery tip
  ///
  /// In en, this message translates to:
  /// **'Settings › Apps › Termux › Battery › Unrestricted, and switch off your phone maker\'s auto-clean for Termux.'**
  String get teamUiPhoneTipBattery;

  /// Keep it running sheet: phantom process killer tip
  ///
  /// In en, this message translates to:
  /// **'Android 12 and later still kill the child processes of a background app (the phantom process killer). Turn that off once, from Termux itself over Wireless debugging; no computer needed:'**
  String get teamUiPhoneTipPhantom;

  /// Keep it running sheet: copy the ADB commands
  ///
  /// In en, this message translates to:
  /// **'Copy commands'**
  String get teamUiPhoneTipsCopy;

  /// Keep it running sheet: copied confirmation
  ///
  /// In en, this message translates to:
  /// **'Commands copied'**
  String get teamUiPhoneTipsCopied;

  /// On this phone: remove action
  ///
  /// In en, this message translates to:
  /// **'Delete from this phone'**
  String get teamUiPhoneRemove;

  /// On this phone: remove confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete the AI team from this phone?'**
  String get teamUiPhoneRemoveTitle;

  /// On this phone: remove confirmation body
  ///
  /// In en, this message translates to:
  /// **'Stops the supervisor and deletes gc, the city and its store. Your project files and their git history stay. The plugin is turned off for this server.'**
  String get teamUiPhoneRemoveBody;

  /// On this phone: remove confirmation action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get teamUiPhoneRemoveConfirm;

  /// On this phone: removed confirmation
  ///
  /// In en, this message translates to:
  /// **'The AI team was deleted from this phone.'**
  String get teamUiPhoneRemoved;

  /// On this phone: a verb failed
  ///
  /// In en, this message translates to:
  /// **'That did not work: {reason}'**
  String teamUiPhoneActionFailed(String reason);

  /// On this phone: unavailable copy (03-onboarding §5)
  ///
  /// In en, this message translates to:
  /// **'Not available on this phone. Running a team needs the 64-bit Linux environment; this device or build can\'t provide it.'**
  String get teamUiPhoneNotAvailable;

  /// Settings › Plugins: re-offer row title
  ///
  /// In en, this message translates to:
  /// **'Set up AI team on this phone'**
  String get teamUiPhoneReofferTitle;

  /// Settings › Plugins: re-offer row body
  ///
  /// In en, this message translates to:
  /// **'The optional step you skipped during setup. Several coding agents work on your project while you supervise from Work; Android may stop them when the app is away.'**
  String get teamUiPhoneReofferBody;

  /// Settings › Plugins: dismiss the re-offer (shown once)
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get teamUiPhoneReofferDismiss;

  /// Settings › Plugins: open the setup screen from the re-offer
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get teamUiPhoneReofferAction;

  /// On this phone: open the Termux setup screen to set up or resume
  ///
  /// In en, this message translates to:
  /// **'Open phone setup'**
  String get teamUiPhoneOpenSetup;

  /// On-device setup: the runtime refused to install or create the city for lack of free space
  ///
  /// In en, this message translates to:
  /// **'Not enough space on this phone. {detail} Free some space (Storage on this phone can clean build caches), then try again.'**
  String teamUiPhoneFailedNoSpace(String detail);

  /// No description provided for @calmCodeOptions.
  ///
  /// In en, this message translates to:
  /// **'Code options'**
  String get calmCodeOptions;

  /// No description provided for @phoneServerConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get phoneServerConnect;

  /// No description provided for @phoneServerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get phoneServerOpen;

  /// No description provided for @phoneServerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get phoneServerStart;

  /// No description provided for @phoneServerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get phoneServerStop;

  /// No description provided for @phoneServerConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to the server on this phone'**
  String get phoneServerConnected;

  /// No description provided for @phoneServerStopped.
  ///
  /// In en, this message translates to:
  /// **'Server on this phone is stopped'**
  String get phoneServerStopped;

  /// No description provided for @phoneServerStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the server on this phone…'**
  String get phoneServerStarting;

  /// No description provided for @phoneServerRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restarting the server on this phone…'**
  String get phoneServerRestarting;

  /// No description provided for @phoneServerStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping the server on this phone…'**
  String get phoneServerStopping;

  /// No description provided for @phoneServerMore.
  ///
  /// In en, this message translates to:
  /// **'More server actions'**
  String get phoneServerMore;

  /// No description provided for @phoneServerManage.
  ///
  /// In en, this message translates to:
  /// **'Manage setup'**
  String get phoneServerManage;

  /// No description provided for @phoneServerForget.
  ///
  /// In en, this message translates to:
  /// **'Forget saved sign-in'**
  String get phoneServerForget;

  /// No description provided for @phoneServerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The server did not start. Open Manage setup to see why.'**
  String get phoneServerStartFailed;

  /// No description provided for @phoneServerRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'The server did not restart. Open Manage setup to see why.'**
  String get phoneServerRestartFailed;

  /// No description provided for @phoneServerStopFailed.
  ///
  /// In en, this message translates to:
  /// **'The server could not be stopped. Try again.'**
  String get phoneServerStopFailed;

  /// No description provided for @termuxRunningDetected.
  ///
  /// In en, this message translates to:
  /// **'Server found on this phone'**
  String get termuxRunningDetected;

  /// No description provided for @termuxRunningConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to running server'**
  String get termuxRunningConnect;

  /// No description provided for @termuxRunningDetails.
  ///
  /// In en, this message translates to:
  /// **'Server details'**
  String get termuxRunningDetails;

  /// No description provided for @termuxRunningPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Termux access in phone setup to check for a server.'**
  String get termuxRunningPermission;

  /// No description provided for @termuxRunningUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not check the server on this phone.'**
  String get termuxRunningUnavailable;

  /// No description provided for @termuxStorageCatSharedCaches.
  ///
  /// In en, this message translates to:
  /// **'Other caches and package data'**
  String get termuxStorageCatSharedCaches;

  /// No description provided for @termuxStorageNoteSharedCaches.
  ///
  /// In en, this message translates to:
  /// **'Shared caches, package installs and download folders may support other tools or contain files worth keeping. They cannot be removed here.'**
  String get termuxStorageNoteSharedCaches;

  /// No description provided for @termuxStorageRescanRequired.
  ///
  /// In en, this message translates to:
  /// **'Previous scan · Scan again before cleaning more'**
  String get termuxStorageRescanRequired;

  /// Title of the confirmation shown before a shared session link is revoked.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing this conversation?'**
  String get safetyStopSharingTitle;

  /// Body of the stop sharing confirmation.
  ///
  /// In en, this message translates to:
  /// **'The link stops working for anyone who has it. The conversation itself is not changed.'**
  String get safetyStopSharingBody;

  /// Cancel label of the stop sharing confirmation.
  ///
  /// In en, this message translates to:
  /// **'Keep sharing'**
  String get safetyStopSharingKeep;

  /// Title of the confirmation shown before the server on this phone is stopped.
  ///
  /// In en, this message translates to:
  /// **'Stop the local server?'**
  String get safetyStopLocalServerTitle;

  /// Body of the stop local server confirmation.
  ///
  /// In en, this message translates to:
  /// **'Anything the agent is running on this phone is interrupted, and this app disconnects from it. Your projects and conversations stay on the phone; start the server again to continue.'**
  String get safetyStopLocalServerBody;

  /// Cancel label of the stop local server confirmation.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get safetyStopLocalServerKeep;

  /// Title of the confirmation shown before an MCP server is disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {server}?'**
  String safetyMcpDisconnectTitle(String server);

  /// Body of the MCP server disconnect confirmation.
  ///
  /// In en, this message translates to:
  /// **'Agents lose its tools until you connect it again, and a tool call in progress may fail. Its configuration stays saved.'**
  String get safetyMcpDisconnectBody;

  /// Cancel label of the MCP server disconnect confirmation.
  ///
  /// In en, this message translates to:
  /// **'Stay connected'**
  String get safetyMcpDisconnectKeep;

  /// Body of the confirmation shown before an orphaned helper process is stopped.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting on it, but whatever it was still doing is lost. It gets a polite stop, then a forced one after 5 seconds.'**
  String get safetyStopOrphanBody;

  /// Settings hub group header: the server connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsHubGroupConnection;

  /// Settings hub group header: defaults for new conversations.
  ///
  /// In en, this message translates to:
  /// **'Conversation defaults'**
  String get settingsHubGroupConversation;

  /// Settings hub group header.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsHubGroupNotifications;

  /// Settings hub group header: models, providers, MCP, plugins.
  ///
  /// In en, this message translates to:
  /// **'Agent setup'**
  String get settingsHubGroupAgentSetup;

  /// Settings hub group header and title of the combined usage screen.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingsHubGroupUsage;

  /// Settings hub group header.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsHubGroupPrivacy;

  /// Settings hub group header.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHubGroupHelp;

  /// Settings hub row: the connected server, its status and details.
  ///
  /// In en, this message translates to:
  /// **'This server'**
  String get settingsHubThisServer;

  /// Subtitle of the This server row: server name and its health line.
  ///
  /// In en, this message translates to:
  /// **'{name} · {status}'**
  String settingsHubThisServerStatus(String name, String status);

  /// Settings hub row: the agent account on the connected server.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get settingsHubAccounts;

  /// Subtitle of the Accounts row.
  ///
  /// In en, this message translates to:
  /// **'Sign-in used by the agent on this server'**
  String get settingsHubAccountsSubtitle;

  /// Settings hub row: default model and agent mode for new conversations.
  ///
  /// In en, this message translates to:
  /// **'Model and mode'**
  String get settingsHubModelAndMode;

  /// Subtitle of the Transcript display row.
  ///
  /// In en, this message translates to:
  /// **'Reasoning, timestamps and usage'**
  String get settingsHubTranscriptSubtitle;

  /// Settings hub row: on-device voice input models.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get settingsHubVoice;

  /// Subtitle of the Voice row.
  ///
  /// In en, this message translates to:
  /// **'Speech models stored on this phone'**
  String get settingsHubVoiceSubtitle;

  /// Settings hub row and screen title: read-state sync and unsent work held on this device.
  ///
  /// In en, this message translates to:
  /// **'Privacy and local data'**
  String get settingsHubPrivacyRow;

  /// Shown when the settings search has no matching rows.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”.'**
  String settingsHubNoResults(String query);

  /// Search aliases for the This server row; preserve English terms to allow either language.
  ///
  /// In en, this message translates to:
  /// **'server host url address password profile connection health status version update service'**
  String get settingsHubSearchServerAliases;

  /// Search aliases for the Saved servers row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'servers profiles host url password switch add edit remove profile connection'**
  String get settingsHubSearchSavedServersAliases;

  /// Search aliases for the On this phone row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'phone termux local on-device on device android install setup storage services'**
  String get settingsHubSearchPhoneAliases;

  /// Search aliases for the Accounts row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'account codex sign in login logout'**
  String get settingsHubSearchAccountsAliases;

  /// Search aliases for the External agents row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'a2a external agents remote'**
  String get settingsHubSearchExternalAgentsAliases;

  /// Search aliases for the Tailscale row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'tailscale vpn network remote private'**
  String get settingsHubSearchTailscaleAliases;

  /// Search aliases for the Disconnect row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'disconnect leave server'**
  String get settingsHubSearchDisconnectAliases;

  /// Search aliases for the Model and mode row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'model mode agent variant thinking default selected session chat conversation'**
  String get settingsHubSearchModelModeAliases;

  /// Search aliases for the Default shell row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'shell terminal bash zsh command'**
  String get settingsHubSearchShellAliases;

  /// Search aliases for the Always allowed actions row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'permissions approvals always allow allowed revoke'**
  String get settingsHubSearchPermissionsAliases;

  /// Search aliases for the Transcript display row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'transcript display thinking reasoning timestamps usage'**
  String get settingsHubSearchTranscriptAliases;

  /// Search aliases for the Voice row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'voice speech microphone dictation model'**
  String get settingsHubSearchVoiceAliases;

  /// Search aliases for the Notifications row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'notifications alerts quiet hours battery background check-in check in wi-fi wifi monitor saved servers finished runs approvals questions quota thresholds'**
  String get settingsHubSearchNotificationsAliases;

  /// Search aliases for the Appearance row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'appearance theme dark light language arabic english font text size colors'**
  String get settingsHubSearchAppearanceAliases;

  /// Search aliases for the Models row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'models agents provider AI reasoning favorites recent'**
  String get settingsHubSearchModelsAliases;

  /// Search aliases for the Providers row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'provider api key keys authentication connect'**
  String get settingsHubSearchProvidersAliases;

  /// Search aliases for the MCP row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'mcp integrations servers tools'**
  String get settingsHubSearchMcpAliases;

  /// Search aliases for the Commands and tools row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'commands tools skills references slash capabilities'**
  String get settingsHubSearchCommandsAliases;

  /// Search aliases for the Plugins row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'plugins plugin installed source status AI Team Gas City'**
  String get settingsHubSearchPluginsAliases;

  /// Search aliases for the Usage rows; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'usage cost tokens budget quota limit spent remaining threshold quota monitoring provider'**
  String get settingsHubSearchUsageAliases;

  /// Search aliases for the Privacy row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'privacy drafts queue queued prompts read state storage clear delete'**
  String get settingsHubSearchPrivacyAliases;

  /// Search aliases for the Setup guide row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'help guide connect tutorial start'**
  String get settingsHubSearchGuideAliases;

  /// Search aliases for the Report a bug row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'bug feedback issue support report'**
  String get settingsHubSearchBugAliases;

  /// Search aliases for the App diagnostics row; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'diagnostics debug errors log'**
  String get settingsHubSearchDiagnosticsAliases;

  /// Search aliases for the About rows; preserve English terms.
  ///
  /// In en, this message translates to:
  /// **'about version licenses open source notices privacy data'**
  String get settingsHubSearchAboutAliases;

  /// Plugins screen section header: plugins that ship with this app (AI Team).
  ///
  /// In en, this message translates to:
  /// **'In this app'**
  String get pluginsSectionInApp;

  /// Plugins screen section header: the connected server's plugin inventory.
  ///
  /// In en, this message translates to:
  /// **'On the server'**
  String get pluginsSectionOnServer;

  /// Notifications screen section header: which events send a notification.
  ///
  /// In en, this message translates to:
  /// **'What notifies me'**
  String get notifySectionWhat;

  /// Notifications screen toggle: notify when a run finishes or fails.
  ///
  /// In en, this message translates to:
  /// **'Finished runs'**
  String get notifyFinishedRuns;

  /// Subtitle of the Finished runs toggle.
  ///
  /// In en, this message translates to:
  /// **'When a run on the connected server finishes or fails.'**
  String get notifyFinishedRunsDetail;

  /// Notifications screen toggle: notify when the agent waits for an approval, a question or a form.
  ///
  /// In en, this message translates to:
  /// **'Approvals and questions'**
  String get notifyRequests;

  /// Subtitle of the Approvals and questions toggle.
  ///
  /// In en, this message translates to:
  /// **'When the agent is waiting for your answer, on any monitored server.'**
  String get notifyRequestsDetail;

  /// Notifications screen toggle: notify when a monitored provider quota passes its threshold.
  ///
  /// In en, this message translates to:
  /// **'Quota thresholds'**
  String get notifyQuotaAlerts;

  /// Subtitle of the Quota thresholds toggle.
  ///
  /// In en, this message translates to:
  /// **'When a monitored provider passes the threshold you set in Usage. An alert records a past reading, not what remains now.'**
  String get notifyQuotaAlertsDetail;

  /// Subtitle of the single Quiet hours toggle on the Notifications screen.
  ///
  /// In en, this message translates to:
  /// **'No notifications during these local times, for every server and for quota alerts. Checks continue.'**
  String get notifyQuietDetail;

  /// Notifications screen section header: the background connection, battery access and service state.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get notifySectionBackground;

  /// Notifications screen section header: which saved servers are monitored and may notify.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get notifySectionServers;

  /// The single Wi-Fi-only toggle; applies to saved-server monitoring and quota monitoring.
  ///
  /// In en, this message translates to:
  /// **'Check in the background on Wi-Fi only'**
  String get notifyWifiOnly;

  /// Subtitle of the Notifications row in the Settings hub; state is the background connection summary.
  ///
  /// In en, this message translates to:
  /// **'Background: {state}'**
  String notifyHubBackgroundSummary(String state);

  /// Link from the saved-servers attention list and the Usage screen to the Notifications screen.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get monitorNotificationSettings;

  /// Usage screen section (tab): what the connected server reports it used.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get usageSectionSpent;

  /// Usage screen section (tab): what a provider account has left, with quota monitoring.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get usageSectionRemaining;

  /// Bottom navigation label and app bar title of the first tab: conversations in the current project.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get shellTabWork;

  /// Bottom navigation label and title of the second tab: everything waiting on the person, then running and finished work.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get shellTabInbox;

  /// Bottom navigation label and app bar title of the third tab: tools scoped to the current project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get shellTabProject;

  /// Project tab: subtitle of the Files row.
  ///
  /// In en, this message translates to:
  /// **'Browse and preview project files'**
  String get projectHubFilesSubtitle;

  /// Project tab: subtitle of the Changes row, which opens the working-tree review.
  ///
  /// In en, this message translates to:
  /// **'Review uncommitted changes'**
  String get projectHubChangesSubtitle;

  /// Project tab: subtitle of the Search files row, which opens Files with the search field focused.
  ///
  /// In en, this message translates to:
  /// **'Find a file by name'**
  String get projectHubSearchSubtitle;

  /// Server switcher row that opens the Servers screen.
  ///
  /// In en, this message translates to:
  /// **'Manage servers'**
  String get serverSwitcherManage;

  /// Shell app bar: accessibility hint on the server name and status, which open the server switcher sheet.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get serverSwitcherOpen;

  /// Header above search results that are places in the app rather than settings rows.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get discoverSearchGoTo;

  /// Header above search results that sit inside a second-level settings screen.
  ///
  /// In en, this message translates to:
  /// **'Inside settings'**
  String get discoverSearchInsideSettings;

  /// Second line of a search result: the screen that holds it.
  ///
  /// In en, this message translates to:
  /// **'In {parent}'**
  String discoverSearchIn(String parent);

  /// No description provided for @discoverWorkAliases.
  ///
  /// In en, this message translates to:
  /// **'work home conversations sessions chats recent pinned new conversation'**
  String get discoverWorkAliases;

  /// No description provided for @discoverInboxAliases.
  ///
  /// In en, this message translates to:
  /// **'inbox activity needs you approvals permissions questions forms waiting running finished'**
  String get discoverInboxAliases;

  /// No description provided for @discoverProjectAliases.
  ///
  /// In en, this message translates to:
  /// **'project tools code folder files changes terminal health worktrees'**
  String get discoverProjectAliases;

  /// No description provided for @discoverFilesAliases.
  ///
  /// In en, this message translates to:
  /// **'files browse folder tree preview code open file'**
  String get discoverFilesAliases;

  /// No description provided for @discoverChangesAliases.
  ///
  /// In en, this message translates to:
  /// **'changes review changes diff uncommitted git edits working tree'**
  String get discoverChangesAliases;

  /// No description provided for @discoverTerminalAliases.
  ///
  /// In en, this message translates to:
  /// **'terminal shell console command line pty'**
  String get discoverTerminalAliases;

  /// No description provided for @discoverHealthAliases.
  ///
  /// In en, this message translates to:
  /// **'project health branch changed files language services formatters lsp'**
  String get discoverHealthAliases;

  /// No description provided for @discoverWorktreesAliases.
  ///
  /// In en, this message translates to:
  /// **'worktrees branches isolated git branch'**
  String get discoverWorktreesAliases;

  /// No description provided for @discoverSearchFilesAliases.
  ///
  /// In en, this message translates to:
  /// **'search files find file name'**
  String get discoverSearchFilesAliases;

  /// No description provided for @discoverAllConversationsAliases.
  ///
  /// In en, this message translates to:
  /// **'all conversations sessions chats history every project search'**
  String get discoverAllConversationsAliases;

  /// No description provided for @discoverTeamAliases.
  ///
  /// In en, this message translates to:
  /// **'ai team agents runs needs you orchestration plugin'**
  String get discoverTeamAliases;

  /// Search result title for the saved-server monitoring section of Notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications from saved servers'**
  String get discoverNotifyServersTitle;

  /// No description provided for @discoverNotifyWhatAliases.
  ///
  /// In en, this message translates to:
  /// **'finished runs approvals questions check-ins check in quota alerts what notifies'**
  String get discoverNotifyWhatAliases;

  /// No description provided for @discoverNotifyQuietAliases.
  ///
  /// In en, this message translates to:
  /// **'quiet hours do not disturb night silence mute schedule'**
  String get discoverNotifyQuietAliases;

  /// No description provided for @discoverNotifyBackgroundAliases.
  ///
  /// In en, this message translates to:
  /// **'background connection stay connected battery keep alive service'**
  String get discoverNotifyBackgroundAliases;

  /// No description provided for @discoverNotifyServersAliases.
  ///
  /// In en, this message translates to:
  /// **'monitor saved servers attention wi-fi wifi check in the background'**
  String get discoverNotifyServersAliases;

  /// No description provided for @discoverAppearanceModeAliases.
  ///
  /// In en, this message translates to:
  /// **'light dark mode system appearance night'**
  String get discoverAppearanceModeAliases;

  /// No description provided for @discoverLanguageAliases.
  ///
  /// In en, this message translates to:
  /// **'language arabic english locale translation rtl'**
  String get discoverLanguageAliases;

  /// No description provided for @discoverThemeAliases.
  ///
  /// In en, this message translates to:
  /// **'theme colors palette pack accent'**
  String get discoverThemeAliases;

  /// No description provided for @discoverSpentAliases.
  ///
  /// In en, this message translates to:
  /// **'spent cost tokens usage statistics money'**
  String get discoverSpentAliases;

  /// No description provided for @discoverRemainingAliases.
  ///
  /// In en, this message translates to:
  /// **'remaining quota limit provider plan left'**
  String get discoverRemainingAliases;

  /// No description provided for @discoverBudgetAliases.
  ///
  /// In en, this message translates to:
  /// **'budget budgets usd token budget spending limit'**
  String get discoverBudgetAliases;

  /// No description provided for @discoverQuotaMonitorAliases.
  ///
  /// In en, this message translates to:
  /// **'quota monitoring threshold alert warn low'**
  String get discoverQuotaMonitorAliases;

  /// No description provided for @discoverCommandsAliases.
  ///
  /// In en, this message translates to:
  /// **'commands server commands slash run'**
  String get discoverCommandsAliases;

  /// No description provided for @discoverToolsAliases.
  ///
  /// In en, this message translates to:
  /// **'tools tools and capabilities inventory model tools'**
  String get discoverToolsAliases;

  /// No description provided for @discoverSkillsAliases.
  ///
  /// In en, this message translates to:
  /// **'skills skill instructions playbook'**
  String get discoverSkillsAliases;

  /// No description provided for @discoverReferencesAliases.
  ///
  /// In en, this message translates to:
  /// **'references reference docs sources context'**
  String get discoverReferencesAliases;

  /// No description provided for @discoverRunningNowAliases.
  ///
  /// In en, this message translates to:
  /// **'running now processes termux services stop on this phone'**
  String get discoverRunningNowAliases;

  /// No description provided for @discoverStorageAliases.
  ///
  /// In en, this message translates to:
  /// **'storage on this phone disk space clean termux'**
  String get discoverStorageAliases;

  /// No description provided for @discoverMonitorAliases.
  ///
  /// In en, this message translates to:
  /// **'saved-server attention monitor other servers waiting server attention'**
  String get discoverMonitorAliases;

  /// No description provided for @discoverConnectionHelpAliases.
  ///
  /// In en, this message translates to:
  /// **'connection help cannot connect troubleshooting network refused timeout'**
  String get discoverConnectionHelpAliases;

  /// Files list: tooltip and accessibility label of the trailing button on a file or folder row. It opens the same actions as a long press or right click on the row.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String gestureEquivFileRowActions(String name);

  /// Keyboard shortcuts help: what F3 and Shift+F3 do.
  ///
  /// In en, this message translates to:
  /// **'Next / previous match while finding in a conversation'**
  String get gestureEquivShortcutFindMatch;

  /// Keyboard shortcuts help: what Arrow Up and Arrow Down do in the message box.
  ///
  /// In en, this message translates to:
  /// **'Earlier / later prompt, with the cursor at the start or end of the message box'**
  String get gestureEquivShortcutPromptHistory;

  /// Inbox: body of the all-clear empty state; says what will appear in the list.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you. Approvals and questions from running work appear here.'**
  String get emptyTeachInboxMessage;

  /// Work tab: title of the empty state shown when the project has no conversations at all.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get emptyTeachWorkTitle;

  /// Work tab: body of the empty state. It names the docked New conversation button instead of repeating it, so the label must match workspaceNewSession.
  ///
  /// In en, this message translates to:
  /// **'Conversations you start in this project are listed here, with the ones that need you first. Start one with New conversation.'**
  String get emptyTeachWorkMessage;

  /// Project > Changes: title of the empty review.
  ///
  /// In en, this message translates to:
  /// **'No changes yet'**
  String get emptyTeachChangesTitle;

  /// Project > Changes: body of the empty review.
  ///
  /// In en, this message translates to:
  /// **'Edits the agent makes show up here to review.'**
  String get emptyTeachChangesMessage;

  /// Worktrees: body of the empty list.
  ///
  /// In en, this message translates to:
  /// **'A worktree is a separate copy of this project on its own branch, so parallel work does not mix. Worktrees of this project appear here.'**
  String get emptyTeachWorktreesMessage;

  /// Always allowed actions: body of the empty list.
  ///
  /// In en, this message translates to:
  /// **'When you choose Always allow on an approval in this project, it is listed here so you can take it back.'**
  String get emptyTeachAllowedMessage;

  /// AI Team home, Runs: body of the empty list when this phone can start a run.
  ///
  /// In en, this message translates to:
  /// **'A run is a job the team works through. Start one and its progress shows here.'**
  String get emptyTeachTeamRunsMessage;

  /// Skills: body of the empty list.
  ///
  /// In en, this message translates to:
  /// **'Skills are reusable instructions the agent can follow. Skills from this project and this server appear here.'**
  String get emptyTeachSkillsMessage;

  /// Tools: body of the empty list for the chosen model.
  ///
  /// In en, this message translates to:
  /// **'Tools the agent can call with this model appear here. This model has none.'**
  String get emptyTeachToolsMessage;

  /// Settings > Help row and screen title: what the connected server supports.
  ///
  /// In en, this message translates to:
  /// **'Available on this server'**
  String get capabilityScreenTitle;

  /// No description provided for @capabilityScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What this server can and cannot do'**
  String get capabilityScreenSubtitle;

  /// No description provided for @capabilityScreenAliases.
  ///
  /// In en, this message translates to:
  /// **'available supported not available missing feature hidden why can\'t capabilities server support shell'**
  String get capabilityScreenAliases;

  /// No description provided for @capabilityScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'{server} decides what appears in this app. Anything it cannot do is left out of the menus and tabs instead of being shown greyed out.'**
  String capabilityScreenIntro(String server);

  /// No description provided for @capabilityGroupAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available here'**
  String get capabilityGroupAvailable;

  /// No description provided for @capabilityGroupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this server'**
  String get capabilityGroupUnavailable;

  /// No description provided for @capabilityGroupDevice.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get capabilityGroupDevice;

  /// No description provided for @capabilityAllAvailable.
  ///
  /// In en, this message translates to:
  /// **'This server supports everything the app offers.'**
  String get capabilityAllAvailable;

  /// No description provided for @capabilityFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get capabilityFiles;

  /// No description provided for @capabilityFilesDetail.
  ///
  /// In en, this message translates to:
  /// **'Browse, search and preview the project\'s files'**
  String get capabilityFilesDetail;

  /// No description provided for @capabilityChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get capabilityChanges;

  /// No description provided for @capabilityChangesDetail.
  ///
  /// In en, this message translates to:
  /// **'Review what the agent edited'**
  String get capabilityChangesDetail;

  /// No description provided for @capabilityTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get capabilityTerminal;

  /// No description provided for @capabilityTerminalDetail.
  ///
  /// In en, this message translates to:
  /// **'Run commands in the project'**
  String get capabilityTerminalDetail;

  /// No description provided for @capabilityShell.
  ///
  /// In en, this message translates to:
  /// **'Default shell'**
  String get capabilityShell;

  /// No description provided for @capabilityShellDetail.
  ///
  /// In en, this message translates to:
  /// **'Choose the shell that commands and terminals use'**
  String get capabilityShellDetail;

  /// No description provided for @capabilityAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get capabilityAttachments;

  /// No description provided for @capabilityAttachmentsDetail.
  ///
  /// In en, this message translates to:
  /// **'Send files and photos with a prompt'**
  String get capabilityAttachmentsDetail;

  /// No description provided for @capabilitySubagents.
  ///
  /// In en, this message translates to:
  /// **'Delegate to a subagent'**
  String get capabilitySubagents;

  /// No description provided for @capabilitySubagentsDetail.
  ///
  /// In en, this message translates to:
  /// **'Mention an agent with @ in a prompt'**
  String get capabilitySubagentsDetail;

  /// No description provided for @capabilityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get capabilityCompact;

  /// No description provided for @capabilityCompactDetail.
  ///
  /// In en, this message translates to:
  /// **'Summarize a long conversation to free up context'**
  String get capabilityCompactDetail;

  /// No description provided for @capabilityShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get capabilityShare;

  /// No description provided for @capabilityShareDetail.
  ///
  /// In en, this message translates to:
  /// **'Publish a link to a conversation'**
  String get capabilityShareDetail;

  /// No description provided for @capabilityFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get capabilityFork;

  /// No description provided for @capabilityForkDetail.
  ///
  /// In en, this message translates to:
  /// **'Branch a conversation from an earlier message'**
  String get capabilityForkDetail;

  /// No description provided for @capabilityRevert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get capabilityRevert;

  /// No description provided for @capabilityRevertDetail.
  ///
  /// In en, this message translates to:
  /// **'Undo a prompt and the edits it made'**
  String get capabilityRevertDetail;

  /// No description provided for @capabilityArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get capabilityArchive;

  /// No description provided for @capabilityArchiveDetail.
  ///
  /// In en, this message translates to:
  /// **'Put finished conversations away without deleting them'**
  String get capabilityArchiveDetail;

  /// No description provided for @capabilityTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get capabilityTodos;

  /// No description provided for @capabilityTodosDetail.
  ///
  /// In en, this message translates to:
  /// **'See the agent\'s task list for a conversation'**
  String get capabilityTodosDetail;

  /// No description provided for @capabilityNotes.
  ///
  /// In en, this message translates to:
  /// **'Note for the agent'**
  String get capabilityNotes;

  /// No description provided for @capabilityNotesDetail.
  ///
  /// In en, this message translates to:
  /// **'Keep standing instructions with a conversation'**
  String get capabilityNotesDetail;

  /// No description provided for @capabilityImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import and export'**
  String get capabilityImportExport;

  /// No description provided for @capabilityImportExportDetail.
  ///
  /// In en, this message translates to:
  /// **'Move a conversation between servers as a file'**
  String get capabilityImportExportDetail;

  /// No description provided for @capabilitySearchAll.
  ///
  /// In en, this message translates to:
  /// **'All conversations'**
  String get capabilitySearchAll;

  /// No description provided for @capabilitySearchAllDetail.
  ///
  /// In en, this message translates to:
  /// **'Search conversations across every project'**
  String get capabilitySearchAllDetail;

  /// No description provided for @capabilityAlwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allowed actions'**
  String get capabilityAlwaysAllow;

  /// No description provided for @capabilityAlwaysAllowDetail.
  ///
  /// In en, this message translates to:
  /// **'Remember an approval so it is not asked again'**
  String get capabilityAlwaysAllowDetail;

  /// No description provided for @capabilityModels.
  ///
  /// In en, this message translates to:
  /// **'Models and providers'**
  String get capabilityModels;

  /// No description provided for @capabilityModelsDetail.
  ///
  /// In en, this message translates to:
  /// **'Browse models and sign in to providers from the app'**
  String get capabilityModelsDetail;

  /// No description provided for @capabilitySkills.
  ///
  /// In en, this message translates to:
  /// **'Skills and commands'**
  String get capabilitySkills;

  /// No description provided for @capabilitySkillsDetail.
  ///
  /// In en, this message translates to:
  /// **'List the server\'s skills, commands and references'**
  String get capabilitySkillsDetail;

  /// No description provided for @capabilityMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get capabilityMcp;

  /// No description provided for @capabilityMcpDetail.
  ///
  /// In en, this message translates to:
  /// **'See and connect MCP servers'**
  String get capabilityMcpDetail;

  /// No description provided for @capabilityPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get capabilityPlugins;

  /// No description provided for @capabilityPluginsDetail.
  ///
  /// In en, this message translates to:
  /// **'See the plugins installed on the server'**
  String get capabilityPluginsDetail;

  /// No description provided for @capabilityCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud environments'**
  String get capabilityCloud;

  /// No description provided for @capabilityCloudDetail.
  ///
  /// In en, this message translates to:
  /// **'Run a project in a managed environment'**
  String get capabilityCloudDetail;

  /// No description provided for @capabilityProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get capabilityProjects;

  /// No description provided for @capabilityProjectsDetail.
  ///
  /// In en, this message translates to:
  /// **'Switch projects and check a project\'s health'**
  String get capabilityProjectsDetail;

  /// No description provided for @capabilityWorktrees.
  ///
  /// In en, this message translates to:
  /// **'Worktrees'**
  String get capabilityWorktrees;

  /// No description provided for @capabilityWorktreesDetail.
  ///
  /// In en, this message translates to:
  /// **'Give a task its own isolated branch'**
  String get capabilityWorktreesDetail;

  /// No description provided for @capabilityUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get capabilityUsage;

  /// No description provided for @capabilityUsageDetail.
  ///
  /// In en, this message translates to:
  /// **'See what conversations have cost'**
  String get capabilityUsageDetail;

  /// No description provided for @capabilityOfflineQueue.
  ///
  /// In en, this message translates to:
  /// **'Send later'**
  String get capabilityOfflineQueue;

  /// No description provided for @capabilityOfflineQueueDetail.
  ///
  /// In en, this message translates to:
  /// **'Queue a prompt while offline and send it on reconnect'**
  String get capabilityOfflineQueueDetail;

  /// No description provided for @capabilityContinueOnComputer.
  ///
  /// In en, this message translates to:
  /// **'Continue on computer'**
  String get capabilityContinueOnComputer;

  /// No description provided for @capabilityContinueOnComputerDetail.
  ///
  /// In en, this message translates to:
  /// **'Get a command that reopens the conversation at your desk'**
  String get capabilityContinueOnComputerDetail;

  /// No description provided for @capabilityServerUpdates.
  ///
  /// In en, this message translates to:
  /// **'Server updates'**
  String get capabilityServerUpdates;

  /// No description provided for @capabilityServerUpdatesDetail.
  ///
  /// In en, this message translates to:
  /// **'Update the server from the app'**
  String get capabilityServerUpdatesDetail;

  /// No description provided for @capabilityBackgroundNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications in the background'**
  String get capabilityBackgroundNotifications;

  /// No description provided for @capabilityBackgroundNotificationsDetail.
  ///
  /// In en, this message translates to:
  /// **'Be told when work finishes or needs you while the app is closed'**
  String get capabilityBackgroundNotificationsDetail;

  /// No description provided for @capabilityOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get capabilityOnThisPhone;

  /// No description provided for @capabilityOnThisPhoneDetail.
  ///
  /// In en, this message translates to:
  /// **'Run the agent\'s server on this device'**
  String get capabilityOnThisPhoneDetail;

  /// No description provided for @capabilityVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get capabilityVoice;

  /// No description provided for @capabilityVoiceDetail.
  ///
  /// In en, this message translates to:
  /// **'Dictate prompts with on-device speech models'**
  String get capabilityVoiceDetail;

  /// Settings > Help row that resets the one-time nudges.
  ///
  /// In en, this message translates to:
  /// **'Show tips again'**
  String get discoverShowTipsAgain;

  /// No description provided for @discoverShowTipsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time tips will appear again at their moment'**
  String get discoverShowTipsSubtitle;

  /// No description provided for @discoverShowTipsAliases.
  ///
  /// In en, this message translates to:
  /// **'tips hints nudges help reset show again tutorial'**
  String get discoverShowTipsAliases;

  /// No description provided for @discoverShowTipsDone.
  ///
  /// In en, this message translates to:
  /// **'Tips will show again.'**
  String get discoverShowTipsDone;

  /// One-time tip above the composer after the third permission request of one kind in a conversation. {action} is the request's title, such as Edit a file. Its button opens Approvals.
  ///
  /// In en, this message translates to:
  /// **'Asked for “{action}” 3 times: this conversation can approve requests for you.'**
  String nudgeApprovals(String action);

  /// One-time tip above the composer when a run that edited files finishes. Its button opens Review changes.
  ///
  /// In en, this message translates to:
  /// **'This run changed files: review what changed before you continue.'**
  String get nudgeReviewChanges;

  /// One-time tip above the composer after a run has kept the person waiting for a minute while finished-run notifications are on.
  ///
  /// In en, this message translates to:
  /// **'You can leave: this phone tells you when the run is done.'**
  String get nudgeLeave;

  /// One-time tip above the composer when the conversation uses most of the model's context window. Its button compacts the conversation.
  ///
  /// In en, this message translates to:
  /// **'The context is {percent}% full: compact to keep going.'**
  String nudgeCompact(String percent);

  /// One-time tip at the top of the Work tab once a second project has been used.
  ///
  /// In en, this message translates to:
  /// **'Pin conversations you return to from their menu; they stay at the top of Work.'**
  String get nudgePin;

  /// Tooltip of the close button on a one-time tip card.
  ///
  /// In en, this message translates to:
  /// **'Hide tip'**
  String get nudgeDismiss;

  /// First-run welcome: the one question asked before any server exists.
  ///
  /// In en, this message translates to:
  /// **'Where does your coding agent run?'**
  String get firstRunWhereQuestion;

  /// First-run welcome choice and the title of the agent question screen.
  ///
  /// In en, this message translates to:
  /// **'On my computer'**
  String get firstRunOnComputer;

  /// First-run welcome: one line under 'On my computer'.
  ///
  /// In en, this message translates to:
  /// **'Connect to an agent that runs there.'**
  String get firstRunOnComputerDetail;

  /// First-run welcome: one line under 'On this phone'.
  ///
  /// In en, this message translates to:
  /// **'Set one up here. No computer needed.'**
  String get firstRunOnPhoneDetail;

  /// First-run welcome choice that opens the simulated demo.
  ///
  /// In en, this message translates to:
  /// **'Just show me'**
  String get firstRunJustShowMe;

  /// First run, computer path: the question above the three agent choices.
  ///
  /// In en, this message translates to:
  /// **'Which agent first?'**
  String get firstRunWhichAgent;

  /// Agent choice title; a product name, not translated.
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get firstRunAgentOpenCode;

  /// Agent choice title for the Paseo backend; product names are not translated.
  ///
  /// In en, this message translates to:
  /// **'Claude Code, Codex, Pi and more'**
  String get firstRunAgentClaudeOrPi;

  /// Agent choice: one line under 'Claude Code or Pi'.
  ///
  /// In en, this message translates to:
  /// **'One connection to the Paseo daemon drives every agent installed there. Experimental.'**
  String get firstRunAgentClaudeOrPiDetail;

  /// Agent choice title; a product name, not translated.
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get firstRunAgentCodex;

  /// Agent choice: one line under 'Codex'.
  ///
  /// In en, this message translates to:
  /// **'Directly, through Codex app-server. Experimental.'**
  String get firstRunAgentCodexDetail;

  /// Connect screen on the first-run computer path: caption above the one command to run.
  ///
  /// In en, this message translates to:
  /// **'On your computer, run:'**
  String get firstRunRunOnComputer;

  /// Connect screen, OpenCode: what to do after running the command, where a camera exists.
  ///
  /// In en, this message translates to:
  /// **'Then paste or scan the code it prints.'**
  String get firstRunPairingNextScan;

  /// Connect screen, OpenCode: what to do after running the command, where there is no camera path.
  ///
  /// In en, this message translates to:
  /// **'Then paste the code it prints.'**
  String get firstRunPairingNextPaste;

  /// Connect screen: plain link under the address field that opens Tailscale setup.
  ///
  /// In en, this message translates to:
  /// **'Not on the same network?'**
  String get firstRunNotSameNetwork;

  /// Connect screen: disclosure holding the other commands the setup guide lists under Advanced.
  ///
  /// In en, this message translates to:
  /// **'Show the commands'**
  String get firstRunShowCommands;

  /// Connect screen, Paseo: caption above the private-network start command.
  ///
  /// In en, this message translates to:
  /// **'To reach it from this phone over your private network, listen on that address and set a password:'**
  String get firstRunCommandsPaseoNetwork;

  /// Connect screen, Codex: caption above the token creation commands.
  ///
  /// In en, this message translates to:
  /// **'Create the connection token before you start it:'**
  String get firstRunCommandsCodexToken;

  /// Connect screen, Codex: caption above the adb reverse command.
  ///
  /// In en, this message translates to:
  /// **'A phone on a USB cable reaches it with:'**
  String get firstRunCommandsCodexUsb;

  /// Conversation, first run: title of the one card shown above the composer after the first reply completes.
  ///
  /// In en, this message translates to:
  /// **'Get told when it\'s done?'**
  String get firstRunNotifyTitle;

  /// Conversation, first run: what accepting the notification card turns on, including its visible cost.
  ///
  /// In en, this message translates to:
  /// **'Leave the app while the agent works. You get a notification when it finishes or needs you. Android shows a small ongoing notification while it stays connected.'**
  String get firstRunNotifyBody;

  /// Conversation, first run: accepts the notification card; asks Android for notification permission and keeps the connection alive in the background.
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get firstRunNotifyAccept;

  /// Conversation, first run: dismisses the notification card for good; Settings, Notifications stays the place to turn it on.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get firstRunNotifyDecline;

  /// On this phone setup: title of the block that installs and runs Claude Code in the managed Ubuntu; also the saved server's name.
  ///
  /// In en, this message translates to:
  /// **'Claude Code on this phone'**
  String get localAgentTitle;

  /// Claude Code block, offer: what setting it up does.
  ///
  /// In en, this message translates to:
  /// **'Run Claude Code here with no computer. The app installs Node.js, the Paseo daemon and Claude Code into the Ubuntu it already manages, and reaches them on this phone only.'**
  String get localAgentOfferBody;

  /// Claude Code block, offer: honest download and disk size.
  ///
  /// In en, this message translates to:
  /// **'About 60 MB to download for Node.js, plus the packages; about 1 GB once installed. Needs 2 GB free.'**
  String get localAgentOfferSize;

  /// Claude Code block, offer: the background-kill caveat.
  ///
  /// In en, this message translates to:
  /// **'Android may stop Termux in the background. The battery settings that keep the OpenCode server alive keep this alive too.'**
  String get localAgentOfferWarning;

  /// Claude Code block, offer: starts the install.
  ///
  /// In en, this message translates to:
  /// **'Set up Claude Code'**
  String get localAgentSetUp;

  /// Claude Code block, offer: hides the offer.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get localAgentNotNow;

  /// Claude Code block: shown when the managed Ubuntu is missing.
  ///
  /// In en, this message translates to:
  /// **'Claude Code runs inside the Ubuntu this app sets up. Finish the On this phone setup first, then come back here.'**
  String get localAgentNeedsUbuntuBody;

  /// Claude Code block: opens the On this phone wizard when Ubuntu is missing.
  ///
  /// In en, this message translates to:
  /// **'Open phone setup'**
  String get localAgentOpenSetup;

  /// Claude Code block, step list: installing the pinned Node.js.
  ///
  /// In en, this message translates to:
  /// **'Node.js'**
  String get localAgentStepNode;

  /// Claude Code block, step list: installing the Paseo daemon.
  ///
  /// In en, this message translates to:
  /// **'Paseo daemon'**
  String get localAgentStepPaseo;

  /// Claude Code block, step list: installing Claude Code.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get localAgentStepClaude;

  /// Claude Code block, step list and button: the person's own sign-in.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Claude'**
  String get localAgentStepSignIn;

  /// Claude Code block, step list: starting the daemon.
  ///
  /// In en, this message translates to:
  /// **'Start on this phone'**
  String get localAgentStepStart;

  /// Claude Code block: heading while install or start runs.
  ///
  /// In en, this message translates to:
  /// **'Setting up Claude Code'**
  String get localAgentInstalling;

  /// Claude Code block: reassurance under the live output.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen. The install keeps going in Termux.'**
  String get localAgentLeaveNote;

  /// Claude Code block, sign-in step: what will happen.
  ///
  /// In en, this message translates to:
  /// **'Termux opens and Claude Code shows a link. Approve it in your browser, paste the code back into Termux, then return here. This app never sees or stores your Claude sign-in.'**
  String get localAgentSignInBody;

  /// Claude Code block, sign-in step: continues when the app cannot see a sign-in the person knows exists.
  ///
  /// In en, this message translates to:
  /// **'I already signed in'**
  String get localAgentSignInAlready;

  /// Claude Code block, sign-in step: fallback when the terminal did not open.
  ///
  /// In en, this message translates to:
  /// **'Termux could not be opened. Open Termux yourself and run: {command}'**
  String localAgentSignInOpenFailed(String command);

  /// Claude Code block, sign-in step: shown after returning without a saved sign-in.
  ///
  /// In en, this message translates to:
  /// **'No Claude sign-in was found yet.'**
  String get localAgentSignInMissing;

  /// Claude Code block and card: the daemon answered its health check.
  ///
  /// In en, this message translates to:
  /// **'Claude Code is running on this phone'**
  String get localAgentReadyTitle;

  /// Claude Code block, ready: the loopback and password guarantee.
  ///
  /// In en, this message translates to:
  /// **'It listens on this phone only (127.0.0.1), behind a password this app keeps.'**
  String get localAgentReadyBody;

  /// Claude Code block and card: installed versions.
  ///
  /// In en, this message translates to:
  /// **'Claude Code {claude} · Paseo {paseo} · Node.js {node}'**
  String localAgentVersions(String claude, String paseo, String node);

  /// Claude Code block: installed, daemon not running.
  ///
  /// In en, this message translates to:
  /// **'Claude Code is installed and stopped'**
  String get localAgentInstalledTitle;

  /// Claude Code block: the daemon was killed in the background.
  ///
  /// In en, this message translates to:
  /// **'Android stopped Claude Code while the app was away. Nothing is lost.'**
  String get localAgentKilled;

  /// Claude Code block: heading of the failure view.
  ///
  /// In en, this message translates to:
  /// **'Claude Code setup stopped'**
  String get localAgentFailedTitle;

  /// Claude Code block: the free-space guard refused.
  ///
  /// In en, this message translates to:
  /// **'Not enough space on this phone. {detail} Free some space, then try again.'**
  String localAgentFailedNoSpace(String detail);

  /// Claude Code block: download failure.
  ///
  /// In en, this message translates to:
  /// **'Node.js could not be downloaded. Check the network, then try again.'**
  String get localAgentFailedDownload;

  /// Claude Code block: checksum refusal.
  ///
  /// In en, this message translates to:
  /// **'The Node.js download did not match its pinned checksum, so nothing was installed. Try again; if it happens twice, something on the network is changing the file.'**
  String get localAgentFailedChecksum;

  /// Claude Code block: npm reported a native build failure.
  ///
  /// In en, this message translates to:
  /// **'A package needs a native module with no ready-made build for this phone. Nothing was compiled; the output below names it.'**
  String get localAgentFailedNativeBuild;

  /// Claude Code block: npm failed for another reason.
  ///
  /// In en, this message translates to:
  /// **'The packages could not be installed. Check the network, then try again.'**
  String get localAgentFailedPackages;

  /// Claude Code block: the daemon port is taken by something else.
  ///
  /// In en, this message translates to:
  /// **'Port 6767 on this phone is already used by another program. Stop that program, then try again.'**
  String get localAgentFailedPortInUse;

  /// Claude Code block: health check timed out.
  ///
  /// In en, this message translates to:
  /// **'Claude Code did not answer within two minutes. The output below shows what it printed.'**
  String get localAgentFailedTimeout;

  /// Claude Code block: a verb was killed mid-way.
  ///
  /// In en, this message translates to:
  /// **'Android stopped the step before it finished. Try again; it picks up where it stopped.'**
  String get localAgentFailedInterrupted;

  /// Claude Code block: unsupported CPU.
  ///
  /// In en, this message translates to:
  /// **'Claude Code needs a 64-bit phone.'**
  String get localAgentFailedUnsupported;

  /// Claude Code block and card: the daemon exited or is unhealthy.
  ///
  /// In en, this message translates to:
  /// **'Claude Code stopped or does not answer. Start it again.'**
  String get localAgentFailedDaemon;

  /// Claude Code block: any other failure, with the script's own sentence.
  ///
  /// In en, this message translates to:
  /// **'It stopped: {detail}'**
  String localAgentFailedReason(String detail);

  /// Claude Code connect: title of the folder chooser.
  ///
  /// In en, this message translates to:
  /// **'Choose a project folder'**
  String get localAgentProjectTitle;

  /// Claude Code connect: what the folder is for.
  ///
  /// In en, this message translates to:
  /// **'Claude Code works inside one folder of the Ubuntu on this phone.'**
  String get localAgentProjectBody;

  /// Claude Code connect: free path field.
  ///
  /// In en, this message translates to:
  /// **'Or type a path inside Ubuntu'**
  String get localAgentProjectPathLabel;

  /// Claude Code connect: the typed path is not absolute.
  ///
  /// In en, this message translates to:
  /// **'Enter a full path, like /root/projects/my-app.'**
  String get localAgentProjectPathInvalid;

  /// Claude Code connect: the connection attempt failed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Claude Code on this phone. {detail}'**
  String localAgentConnectFailed(String detail);

  /// Servers card: the daemon is installed and not running.
  ///
  /// In en, this message translates to:
  /// **'Claude Code on this phone is stopped'**
  String get localAgentCardStopped;

  /// Servers card: this app is connected through the daemon.
  ///
  /// In en, this message translates to:
  /// **'Connected to Claude Code on this phone'**
  String get localAgentCardConnected;

  /// Servers card: start in progress.
  ///
  /// In en, this message translates to:
  /// **'Starting Claude Code…'**
  String get localAgentCardStarting;

  /// Servers card: restart in progress.
  ///
  /// In en, this message translates to:
  /// **'Restarting Claude Code…'**
  String get localAgentCardRestarting;

  /// Servers card: stop in progress.
  ///
  /// In en, this message translates to:
  /// **'Stopping Claude Code…'**
  String get localAgentCardStopping;

  /// Servers card: what runtime this card is.
  ///
  /// In en, this message translates to:
  /// **'Claude Code through Paseo'**
  String get localAgentCardSubtitle;

  /// Servers card: a control failed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. {detail}'**
  String localAgentCardActionFailed(String detail);

  /// Confirm sheet: restarting the daemon.
  ///
  /// In en, this message translates to:
  /// **'Restart Claude Code on this phone?'**
  String get localAgentRestartTitle;

  /// Confirm sheet: what restarting the daemon costs.
  ///
  /// In en, this message translates to:
  /// **'Claude Code is briefly unavailable and anything it is doing right now is interrupted. Your conversations stay on the phone.'**
  String get localAgentRestartBody;

  /// Confirm sheet: stopping the daemon.
  ///
  /// In en, this message translates to:
  /// **'Stop Claude Code on this phone?'**
  String get localAgentStopTitle;

  /// Confirm sheet: what stopping the daemon costs.
  ///
  /// In en, this message translates to:
  /// **'Anything Claude Code is doing on this phone is interrupted, and this app disconnects from it. Your projects, conversations and Claude sign-in stay; start it again to continue.'**
  String get localAgentStopBody;

  /// Claude Code block: menu action that uninstalls it.
  ///
  /// In en, this message translates to:
  /// **'Remove from this phone'**
  String get localAgentRemove;

  /// Confirm sheet: removing the install.
  ///
  /// In en, this message translates to:
  /// **'Remove Claude Code from this phone?'**
  String get localAgentRemoveTitle;

  /// Confirm sheet: what removing deletes and keeps.
  ///
  /// In en, this message translates to:
  /// **'Stops it and deletes Node.js, Paseo and Claude Code from Ubuntu, about 1 GB. Your projects and your Claude sign-in stay.'**
  String get localAgentRemoveBody;

  /// Confirm sheet: cancels the removal.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get localAgentRemoveKeep;

  /// Claude Code block: tooltip of the overflow menu.
  ///
  /// In en, this message translates to:
  /// **'More Claude Code actions'**
  String get localAgentMore;

  /// On this phone setup, runtime choice: what picking Claude Code does.
  ///
  /// In en, this message translates to:
  /// **'Sets up Ubuntu and the OpenCode server first, then installs Claude Code next to it.'**
  String get localAgentRuntimeChoiceDetail;

  /// No description provided for @firstRunAgentsSideBySide.
  ///
  /// In en, this message translates to:
  /// **'They run side by side on the same computer. Start with one, and add the others any time from the server name at the top.'**
  String get firstRunAgentsSideBySide;

  /// No description provided for @firstRunPaseoTitle.
  ///
  /// In en, this message translates to:
  /// **'Agents through Paseo'**
  String get firstRunPaseoTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
