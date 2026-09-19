// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get setupCancelConnection => 'إلغاء الاتصال';

  @override
  String get servicesTitle => 'خدمات التطوير';

  @override
  String get servicesCopy => 'نسخ الأمر';

  @override
  String get servicesSubtitle => 'أوامر المشروع والسجلات وروابط المعاينة';

  @override
  String get servicesIntro =>
      'اجمع أوامر تطوير مشروعك وروابط معاينته في مكان واحد. حفظ الخدمة لا يشغّلها.';

  @override
  String get servicesAdd => 'إضافة خدمة';

  @override
  String get servicesName => 'اسم الخدمة';

  @override
  String get servicesCommand => 'أمر التطوير';

  @override
  String get servicesCommandHint =>
      'استخدم أمرًا يعمل في المقدمة، مثل npm run dev. لا يمكن تتبّع الأوامر التي تعمل في الخلفية أو منفصلة عن الجلسة.';

  @override
  String get servicesUrl => 'رابط المعاينة (اختياري)';

  @override
  String get servicesUrlHint =>
      'استخدم عنوانًا يمكن لهذا الهاتف الوصول إليه. يشير localhost إلى هذا الهاتف. لا يُفتح أي منفذ ولا يُعاد توجيهه تلقائيًا.';

  @override
  String get servicesSave => 'حفظ الخدمة';

  @override
  String get servicesInvalid =>
      'أدخل اسمًا وأمرًا يعمل في المقدمة، ويمكنك إضافة رابط HTTP أو HTTPS خالٍ من بيانات الاعتماد.';

  @override
  String get servicesUnavailable =>
      'لا يتيح هذا الاتصال تشغيل أوامر التطوير وتتبّعها. يمكنك حفظ الأوامر ومراجعة روابط معاينتها هنا.';

  @override
  String get servicesScopeChanged =>
      'تغيّر الخادم أو المشروع. افتح خدمات التطوير مجددًا من المشروع المطلوب.';

  @override
  String get servicesNotStarted => 'لم يبدأ التشغيل';

  @override
  String get servicesRunning => 'الأمر قيد التشغيل';

  @override
  String get servicesStopped => 'متوقفة';

  @override
  String get servicesUnknown => 'الحالة غير معروفة';

  @override
  String get servicesStatusHint =>
      'حالة الأمر لا تؤكد أن تطبيقك جاهز أو يمكن الوصول إليه.';

  @override
  String get servicesStart => 'تشغيل';

  @override
  String get servicesStop => 'إيقاف';

  @override
  String get servicesRestart => 'إعادة التشغيل';

  @override
  String get servicesLogs => 'السجلات';

  @override
  String get servicesVisit => 'فتح الرابط';

  @override
  String get servicesRemove => 'إزالة الإعدادات';

  @override
  String get servicesRemoveHint =>
      'هل تريد إزالة هذه الخدمة المحفوظة وسجل ملكيتها المحلي؟ لن يتوقف أمرها على الخادم. أوقفه أولًا إذا لزم الأمر.';

  @override
  String get servicesStartHint =>
      'هل تريد تشغيل هذا الأمر المحفوظ في المشروع الموضّح أدناه؟ يستخدم الأمر بيئة الخادم. أبقه في المقدمة؛ لا يمكن لهذه اللوحة إدارة العمليات المنفصلة عن الجلسة.';

  @override
  String get servicesStopHint =>
      'هل تريد إيقاف أمر هذه الخدمة المتتبَّع؟ سيزيل الخادم سجلاته المحفوظة أيضًا. لن تتأثر الأوامر الأخرى.';

  @override
  String get servicesRestartHint =>
      'هل تريد إيقاف هذا الأمر المتتبَّع وإزالة سجله من الخادم، ثم تشغيل الأمر المحفوظ مجددًا؟';

  @override
  String get servicesForget => 'مسح سجل التشغيل الأخير';

  @override
  String get servicesForgetHint =>
      'هل تريد مسح سجل التشغيل المحلي؟ لن تتوقف أي عملية على الخادم. قد يؤدي التشغيل مجددًا إلى إنشاء نسخة مكررة إذا كان الأمر السابق لا يزال يعمل.';

  @override
  String get servicesUnknownHint =>
      'تعذّر تأكيد حالة التشغيل الأخير. حدّث الحالة للتحقق منها قبل التشغيل مجددًا.';

  @override
  String get servicesLogEmpty => 'لا توجد مخرجات مسجّلة بعد.';

  @override
  String get servicesLogTail =>
      'يُعرض جزء محدود من نهاية السجل، وقد تُحذف المخرجات الأقدم من العرض. تُحفظ السجلات على الخادم، ولا تُخزّن على هذا الهاتف.';

  @override
  String get servicesWorking => 'جارٍ تحديث الخدمة…';

  @override
  String servicesExit(int code) {
    return 'رمز الخروج المسجّل: $code';
  }

  @override
  String get servicesRefresh => 'تحديث الحالة';

  @override
  String get isolatedTaskScopeChanged =>
      'تغيّر الخادم أو المشروع. أغلق هذه اللوحة وافتح المهمة مجددًا من المشروع المطلوب.';

  @override
  String get appTitle => 'OpenCode Mobile';

  @override
  String get libraryBrowseSection => 'تصفّح';

  @override
  String get libraryManageSection => 'إدارة';

  @override
  String get libraryModelsAgentsTitle => 'النماذج والوكلاء';

  @override
  String get libraryProvidersTitle => 'مزوّدو الخدمة';

  @override
  String get libraryMcpTitle => 'MCP';

  @override
  String get libraryCommandsToolsTitle => 'الأوامر والأدوات';

  @override
  String get libraryTerminalTitle => 'الطرفية';

  @override
  String get librarySettingsTitle => 'الإعدادات';

  @override
  String aboutBuildVersion(String version, String buildNumber) {
    return 'OpenCode Mobile $version+$buildNumber';
  }

  @override
  String get aboutSigningCertificate => 'بصمة شهادة التوقيع SHA-256';

  @override
  String get modelSwitchSession => 'تغيير نموذج هذه الجلسة';

  @override
  String get modelNextRecent => 'النموذج التالي من النماذج الأخيرة · F2';

  @override
  String get modelPreviousRecent =>
      'النموذج السابق من النماذج الأخيرة · Shift+F2';

  @override
  String get modelNextFavorite => 'النموذج المفضّل التالي';

  @override
  String get modelChooseTitle => 'اختيار نموذج';

  @override
  String get modelTitleCompact => 'النماذج';

  @override
  String get modelSearchHint => 'البحث في النماذج';

  @override
  String get modelAll => 'كل النماذج';

  @override
  String get modelFavorites => 'المفضّلة';

  @override
  String get modelRecent => 'الأخيرة';

  @override
  String get modelOptions => 'الخيارات';

  @override
  String get modelThinkingMode => 'وضع التفكير';

  @override
  String get modelDefaultMode => 'الوضع الافتراضي';

  @override
  String get modelSessionScopeNote => 'يسري على الرسائل التالية في هذه الجلسة.';

  @override
  String get modelSelectionLoading => 'جارٍ تحميل اختيار الجلسة…';

  @override
  String get modelServerDefault => 'إعداد الخادم الافتراضي';

  @override
  String get modelSelectionSaving => 'جارٍ حفظ اختيار الجلسة…';

  @override
  String get modelAgentSaveFailed => 'تعذّر حفظ الوكيل. حاول مجددًا.';

  @override
  String get modelUnavailableSelection =>
      'نموذج الجلسة غير متاح في هذا الدليل. حدّث النماذج أو اختر نموذجًا آخر.';

  @override
  String get modelScopeChanged =>
      'تغيّر الاتصال. افتح قائمة اختيار النموذج مجددًا للمتابعة.';

  @override
  String get commonClearSearch => 'مسح البحث';

  @override
  String get commonUndo => 'تراجع';

  @override
  String get workTitle => 'المهام';

  @override
  String get workDescription => 'الوكلاء والأوامر المرتبطة بهذه المحادثة.';

  @override
  String get workAgents => 'الوكلاء';

  @override
  String get workCommands => 'الأوامر';

  @override
  String get workEmpty => 'لا توجد مهام بعد';

  @override
  String get workEmptyDescription =>
      'سيظهر هنا الوكلاء والأوامر المرتبطة بهذه المحادثة عند بدء تشغيلها.';

  @override
  String get workRefresh => 'تحديث';

  @override
  String get workClose => 'إغلاق';

  @override
  String get workRetry => 'المحاولة مجددًا';

  @override
  String get workCancel => 'إلغاء';

  @override
  String get workRunning => 'قيد التشغيل';

  @override
  String get workFinished => 'مكتملة';

  @override
  String get workTimedOut => 'انتهت المهلة';

  @override
  String get workStopped => 'متوقفة';

  @override
  String get workUnknown => 'الحالة غير متاحة';

  @override
  String get workOutput => 'مخرجات الأمر';

  @override
  String get workViewOutput => 'عرض المخرجات';

  @override
  String get workNoOutput => 'بانتظار المخرجات…';

  @override
  String get workNoFinalOutput => 'لم يُنتج هذا الأمر أي مخرجات.';

  @override
  String get workCopyOutput => 'نسخ المخرجات';

  @override
  String get workCopied => 'نُسخت المخرجات';

  @override
  String get workFollow => 'متابعة المخرجات';

  @override
  String get workMoreOutput => 'تحميل المزيد من المخرجات';

  @override
  String get workTrimmed => 'تُعرض أحدث المخرجات. اقتُطع النص الأقدم.';

  @override
  String get workStop => 'إيقاف الأمر';

  @override
  String get workStopTitle => 'هل تريد إيقاف هذا الأمر؟';

  @override
  String get workStopDescription =>
      'سيتوقف الأمر وتُحذف مخرجاته المحفوظة من الخادم. سيبقى النص المحمّل هنا ظاهرًا حتى تغلقه.';

  @override
  String get workTimeout => 'تغيير المهلة';

  @override
  String get workTimeoutTitle => 'الوقت المتبقي';

  @override
  String get workTimeoutDescription => 'تبدأ المهلة الجديدة الآن.';

  @override
  String get workTimeoutOneMinute => 'دقيقة واحدة';

  @override
  String get workTimeoutFiveMinutes => '5 دقائق';

  @override
  String get workTimeoutFifteenMinutes => '15 دقيقة';

  @override
  String get workTimeoutOneHour => 'ساعة واحدة';

  @override
  String get workTimeoutNone => 'بلا مهلة';

  @override
  String get workTimeoutSaved => 'حُدّثت المهلة';

  @override
  String get workUnavailable =>
      'لم يعد هذا الأمر متاحًا. ربما أُزيل أو أُلغي عند إعادة تشغيل الخادم.';

  @override
  String get workRestarted =>
      'أُعيد تشغيل الخادم ولم يعد هذا الأمر متاحًا. تظهر مخرجاته المحمّلة أدناه.';

  @override
  String get workDisconnected =>
      'جارٍ إعادة الاتصال. ستُحدّث المخرجات عندما يتاح الخادم.';

  @override
  String get workContextChanged =>
      'تغيّر الخادم أو مساحة العمل. أغلق هذا العرض وافتح المهام الجارية مجددًا.';

  @override
  String workCount(int count) {
    return 'المهام · قيد التشغيل: $count';
  }

  @override
  String workExitCode(int code) {
    return 'رمز الخروج $code';
  }

  @override
  String workStatusElapsed(String status, String elapsed) {
    return '$status · $elapsed';
  }

  @override
  String get composerClearTextTitle => 'مسح نص المسودة';

  @override
  String get composerClearTextSubtitle => 'تبقى المرفقات · يمكن التراجع';

  @override
  String get composerDraftCleared => 'مُسح نص المسودة';

  @override
  String get composerReuseTitle => 'إعادة استخدام طلب';

  @override
  String get queueSaveFailed =>
      'تعذّر حفظ المسودة المنتظرة على هذا الجهاز. لا يزال النص هنا. تحقّق من مساحة التخزين المتاحة وحاول مجددًا.';

  @override
  String get fileCopy => 'نسخ';

  @override
  String get fileReference => 'إضافة مرجع';

  @override
  String get fileAttach => 'إرفاق';

  @override
  String get fileSave => 'حفظ';

  @override
  String get fileReload => 'إعادة التحميل';

  @override
  String get queueRemoveFailed =>
      'تعذّرت إزالة هذه المسودة من مساحة تخزين الجهاز. لا تزال في قائمة الانتظار. تحقّق من مساحة التخزين المتاحة وحاول مجددًا.';

  @override
  String get composerReuseSubtitle =>
      'إعادة استخدام نص من هذه المحادثة والطلبات المرسلة مؤخرًا';

  @override
  String get composerReuseDescription =>
      'نصوص الطلبات المحمّلة في هذه المحادثة والمرسلة مؤخرًا على هذا الخادم. يضيف اختيار أحدها نصّه إلى مسودتك، دون نسخ المرفقات. باستخدام لوحة المفاتيح، اضغط السهم لأعلى في بداية النص أو السهم لأسفل في نهايته لتصفّح الطلبات واستعادة مسودتك.';

  @override
  String get composerReuseSearch => 'البحث في الطلبات الأخيرة';

  @override
  String get composerReuseEmpty => 'لا توجد طلبات مطابقة';

  @override
  String get backgroundSubagentsTitle => 'الوكلاء الفرعيون في الخلفية';

  @override
  String get backgroundWorkTitle => 'نقل العمل الجاري إلى الخلفية';

  @override
  String get backgroundWorkShortcut =>
      'متابعة هذا العمل أثناء استخدام المحادثة · Ctrl+B';

  @override
  String get backgroundWorkNoop =>
      'لا يوجد وكلاء فرعيون في المقدمة لنقلهم إلى الخلفية.';

  @override
  String get backgroundWorkPromoted =>
      'يواصل الوكلاء الفرعيون العمل في الخلفية.';

  @override
  String get librarySearchHint => 'البحث عن الإعدادات والأدوات والمساعدة';

  @override
  String get libraryDefaultModel => 'الافتراضي للمحادثات الجديدة';

  @override
  String get libraryNoModel => 'لم يُحدّد نموذج';

  @override
  String librarySearchResults(int count, String query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة لـ «$query».',
      many: '$count نتيجة لـ «$query».',
      few: '$count نتائج لـ «$query».',
      two: 'نتيجتان لـ «$query».',
      one: 'نتيجة واحدة لـ «$query».',
      zero: 'لا توجد أدوات مطابقة لـ «$query».',
    );
    return '$_temp0';
  }

  @override
  String get chatAttachmentUnsupported =>
      'يمكن إرفاق ملفات PNG وJPEG وGIF وWebP وPDF والملفات النصية فقط.';

  @override
  String get termuxRestartServer => 'إعادة تشغيل الخادم المحلي';

  @override
  String get termuxRestartTitle => 'هل تريد إعادة تشغيل الخادم المحلي؟';

  @override
  String get termuxRestartMessage =>
      'سيتعذّر استخدام OpenCode لفترة قصيرة. سيحتفظ التطبيق بمساحة عملك الحالية ويعيد الاتصال تلقائيًا.';

  @override
  String termuxRestartBusyMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تولّد $count جلسة ردودًا. ستقاطعها إعادة التشغيل.',
      many: 'تولّد $count جلسة ردودًا. ستقاطعها إعادة التشغيل.',
      few: 'تولّد $count جلسات ردودًا. ستقاطعها إعادة التشغيل.',
      two: 'تولّد جلستان ردودًا. ستقاطعهما إعادة التشغيل.',
      one: 'تولّد جلسة واحدة ردًا. ستقاطعها إعادة التشغيل.',
      zero: 'لا توجد جلسات تولّد ردودًا.',
    );
    return '$_temp0';
  }

  @override
  String get termuxRestartConfirm => 'إعادة التشغيل';

  @override
  String get termuxRestarting => 'جارٍ إعادة تشغيل الخادم المحلي…';

  @override
  String get termuxRestartProgress =>
      'لن يتغيّر إصدار OpenCode المثبّت ولا بيانات الاعتماد المحفوظة. سيعيد التطبيق الاتصال عندما يصبح الخادم جاهزًا.';

  @override
  String get termuxRestartSucceeded =>
      'أُعيد تشغيل الخادم المحلي واستُعيد الاتصال.';

  @override
  String get termuxRestartNotPerformed =>
      'لم تُنفَّذ إعادة التشغيل. لا يزال الخادم المحلي الحالي يعمل.';

  @override
  String get chatCopyCompleteReply => 'نسخ الرد كاملًا';

  @override
  String get chatCopyReplySoFar => 'نسخ الرد حتى الآن';

  @override
  String commandRunTitle(String command) {
    return 'تشغيل /$command';
  }

  @override
  String get commandDestination => 'المحادثة';

  @override
  String get commandNewChat => 'محادثة جديدة';

  @override
  String get commandUntitledChat => 'محادثة بلا عنوان';

  @override
  String get commandArguments => 'المعاملات (اختياري)';

  @override
  String get commandRun => 'تشغيل';

  @override
  String get commandRunning => 'جارٍ البدء…';

  @override
  String get commandLocationChanged =>
      'تغيّر الخادم أو مساحة العمل. أغلق هذا الحوار وافتح الأمر مجددًا.';

  @override
  String get refreshFailed => 'تعذّر التحديث';

  @override
  String get refreshRetry => 'إعادة المحاولة';

  @override
  String get filesProjectRoot => 'المجلد الجذر للمشروع';

  @override
  String filesOpenFolder(String folder) {
    return 'فتح المجلد $folder';
  }

  @override
  String filesCurrentFolder(String folder) {
    return 'المجلد الحالي: $folder';
  }

  @override
  String get globalSessionsLoadMore => 'تحميل المزيد من الجلسات';

  @override
  String get globalSessionsRefreshFailed => 'تعذّر تحديث الجلسات.';

  @override
  String get workspaceSearchAllSessions => 'البحث في كل الجلسات';

  @override
  String get workspaceProjectListUnavailable => 'قائمة المشاريع غير متاحة';

  @override
  String get workspaceProjectListFallback =>
      'قد تبقى محادثاتك متاحة. ابحث في كل الجلسات للعثور على أعمالك السابقة.';

  @override
  String get workspaceRetryProjects => 'إعادة تحميل المشاريع';

  @override
  String get historyLoadOlder => 'تحميل الرسائل الأقدم';

  @override
  String get historyReload => 'إعادة تحميل السجل الحديث';

  @override
  String get historyCursorExpired =>
      'تغيّر السجل الأقدم أو انتهت صلاحيته. أعد تحميل السجل الحديث للمتابعة.';

  @override
  String get historyRefreshed =>
      'حُدّث السجل. لا تزال الرسائل الأقدم متاحة أعلاه.';

  @override
  String get historyLoadedOnly =>
      'تُضمّن الرسائل المحمّلة فقط. حمّل السجل الأقدم لتضمين المزيد.';

  @override
  String get historyLoadedTotals => 'الاستخدام والسجل المحمّل';

  @override
  String get historyCopyLoadedReply => 'نسخ الرد المحمّل';

  @override
  String get historyLoadedMessages => 'الرسائل المحمّلة';

  @override
  String get historyLoadedCost => 'تكلفة الرسائل المحمّلة';

  @override
  String get historyServerTotalsNote =>
      'تشمل الصفوف الموسومة «أبلغ عنها الخادم» الجلسة كاملة. أما أعداد الرسائل والتقديرات الأخرى فتشمل السجل المحمّل.';

  @override
  String get sessionsLoadedOnly =>
      'تُعرض الجلسات المحمّلة. حمّل المزيد لتضمين المحادثات الأقدم.';

  @override
  String get sessionsDetailsUnavailable =>
      'تعذّر تحميل تفاصيل الجلسة. حاول مجددًا.';

  @override
  String get sessionsLoadMore => 'تحميل المزيد من الجلسات';

  @override
  String get sessionsReload => 'إعادة تحميل الجلسات الأخيرة';

  @override
  String get sessionsNoLoadedRecent =>
      'لا توجد جلسات حديثة في النتائج المحمّلة';

  @override
  String get sessionsNoLoadedArchived =>
      'لا توجد جلسات مؤرشفة في النتائج المحمّلة';

  @override
  String sessionsLoadedCount(int count) {
    return 'المحمّل: $count';
  }

  @override
  String get revertStageTitle =>
      'هل تريد تطبيق تراجع مبدئي بدءًا من هذا الطلب؟';

  @override
  String get revertStageDescription =>
      'سيُخفى هذا الطلب وما يليه من المحادثة أثناء التراجع المبدئي. راجع النتيجة قبل تثبيت التراجع نهائيًا.';

  @override
  String get revertApplyFiles => 'التراجع عن تغييرات الملفات أيضًا';

  @override
  String get revertApplyFilesHint =>
      'تُطبّق تغييرات الملفات فور بدء التراجع المبدئي. يمكن إلغاء التراجع لاستعادة الملفات المشمولة من اللقطة المحفوظة.';

  @override
  String get revertStageAction => 'تطبيق مبدئي ومراجعة';

  @override
  String get revertReviewTitle => 'مراجعة التراجع المبدئي';

  @override
  String get revertReviewChanged =>
      'تغيّرت هذه الجلسة أو التراجع المبدئي فيها. راجع أحدث حالة قبل المتابعة.';

  @override
  String get revertReviewLatest => 'مراجعة أحدث حالة';

  @override
  String get revertBusy => 'انتظر حتى ينتهي الإجراء الحالي في الجلسة.';

  @override
  String get revertCancel => 'إلغاء';

  @override
  String get revertCommitTitle => 'هل تريد تثبيت هذا التراجع نهائيًا؟';

  @override
  String get revertCommitDescription =>
      'سيُحذف سجل المحادثة المشمول بالتراجع المبدئي نهائيًا. ستبقى تغييرات الملفات التي طُبّقت بالفعل. لن تتمكن من إلغاء هذا التراجع لاحقًا.';

  @override
  String get revertCommitAction => 'تثبيت التراجع نهائيًا';

  @override
  String get revertClearTitle => 'هل تريد إلغاء هذا التراجع المبدئي؟';

  @override
  String get revertClearDescription =>
      'ستُستعاد المحادثة المخفية والملفات المشمولة بالتراجع المبدئي من اللقطة المحفوظة. قد تُستبدل التغييرات التي أُجريت على هذه الملفات منذ بدء التراجع. وقد تُستأنف المهام في قائمة الانتظار.';

  @override
  String get revertClearAction => 'إلغاء التراجع المبدئي';

  @override
  String get revertNoStage => 'لا يوجد تراجع مبدئي لمراجعته.';

  @override
  String get revertBoundaryLabel => 'بداية التراجع من الطلب';

  @override
  String get revertPreviewDescription =>
      'هذه هي تغييرات الملفات المُبلّغ عنها لهذا التراجع المبدئي. قد تكون طُبّقت بالفعل عند بدئه.';

  @override
  String get revertPreviewUnavailable =>
      'لم يقدّم الخادم معاينة للملفات. لا يثبت ذلك ما إذا كانت الملفات قد تغيّرت.';

  @override
  String get revertPreviewEmpty =>
      'لم يُبلّغ عن تغييرات ملفات لهذا التراجع المبدئي.';

  @override
  String get revertStaged => 'طُبّق التراجع مبدئيًا';

  @override
  String get revertReview => 'مراجعة';

  @override
  String get revertFromHere => 'التراجع بدءًا من هذا الطلب';

  @override
  String get revertUndoDescription =>
      'تطبيق تراجع مبدئي ومراجعة الملفات المتأثرة';

  @override
  String get revertClearShortDescription => 'مراجعة التراجع المبدئي وإلغاؤه';

  @override
  String get revertPromptUnavailable =>
      'تعذّر تحميل الطلب الذي يبدأ منه التراجع.';

  @override
  String get revertPromptLoading => 'جارٍ تحميل الطلب الذي يبدأ منه التراجع…';

  @override
  String get revertAttachmentPrompt => 'طلب يتضمّن مرفقات فقط';

  @override
  String get revertResolveBeforeSending =>
      'راجع التراجع المبدئي، ثم ألغِه أو ثبّته نهائيًا قبل الإرسال. ستبقى مسودتك محفوظة.';

  @override
  String get sessionNoteTitle => 'ملاحظة للوكيل';

  @override
  String get sessionNoteDescription =>
      'احفظ توجيهًا قصيرًا لهذه الجلسة. يسري حفظه أو حذفه في خطوة الوكيل التالية ويظهر عندها في سجل المحادثة. لا يؤدي ذلك إلى بدء التشغيل.';

  @override
  String get sessionNoteHint =>
      'مثلًا: اختصر الشرح ونفّذ الفحوص ذات الصلة قبل الانتهاء.';

  @override
  String get sessionNoteSave => 'حفظ الملاحظة';

  @override
  String get sessionNoteRemove => 'إزالة الملاحظة المحفوظة';

  @override
  String get sessionNoteSaved => 'حُفظت الملاحظة';

  @override
  String get sessionNoteRemoved => 'أُزيلت الملاحظة';

  @override
  String get sessionNotePending => 'تسري في خطوة الوكيل التالية.';

  @override
  String get sessionInstructionsUpdated => 'حُدّثت التعليمات';

  @override
  String get sessionInstructionsApplied =>
      'حُدّثت تعليمات الوكيل الخاصة بالجلسة لهذه الخطوة.';

  @override
  String get sessionNoteUnsupported => 'لا يدعم هذا الخادم ملاحظات الجلسة.';

  @override
  String get sessionNoteAuthorization =>
      'تحقّق من كلمة مرور هذا الخادم وأذوناته، ثم حاول مجددًا. ستبقى مسودتك محفوظة.';

  @override
  String get sessionNoteChanged =>
      'تغيّرت الجلسة أو تعليماتها. حدّث الملاحظة المحفوظة قبل الحفظ مجددًا. ستبقى مسودتك محفوظة.';

  @override
  String get sessionNoteInvalid =>
      'صيغة الملاحظة المحفوظة لا تتيح لهذا المحرّر تعديلها بأمان.';

  @override
  String get sessionNoteTooLarge =>
      'اختصر الملاحظة لتناسب حد الحجم المسموح به على الخادم.';

  @override
  String get sessionNoteBusy =>
      'جارٍ حفظ تغيير في الملاحظة بالفعل. حاول مجددًا بعد انتهائه.';

  @override
  String get sessionNoteRefresh => 'تحديث الملاحظة المحفوظة';

  @override
  String get sessionNoteSavedVersion =>
      'الملاحظة المحفوظة حاليًا — راجعها قبل استبدالها';

  @override
  String get sessionNoteNone => 'لا توجد ملاحظة محفوظة';

  @override
  String get sessionNoteDiscard => 'هل تريد تجاهل تغييرات الملاحظة؟';

  @override
  String get sessionNoteKeepEditing => 'متابعة التحرير';

  @override
  String get sessionNoteDiscardAction => 'تجاهل التغييرات';

  @override
  String sessionNoteBytes(int used, int limit) {
    return '$used / $limit بايت';
  }

  @override
  String get usageTitle => 'الاستخدام والتكلفة';

  @override
  String get usageDescription =>
      'النشاط الذي سجّله خادم OpenCode هذا عبر جلساتك.';

  @override
  String get usageRefresh => 'تحديث الاستخدام';

  @override
  String get usageToday => 'اليوم';

  @override
  String get usageThirtyDays => '30 يومًا';

  @override
  String get usageYear => 'هذا العام';

  @override
  String get usageAllTime => 'كل الفترات';

  @override
  String get usageScope => 'نطاق المشاريع';

  @override
  String get usageAllProjects => 'كل المشاريع';

  @override
  String get usageCurrentProject => 'المشروع الحالي';

  @override
  String get usageLoading => 'جارٍ تحميل الاستخدام';

  @override
  String get usageUnsupported =>
      'لا يدعم هذا الخادم إحصاءات الاستخدام المجمّعة.';

  @override
  String get usageProjectUnavailable =>
      'تعذّر تحديد المشروع الحالي. اختر «كل المشاريع» أو افتح مشروعًا أولًا.';

  @override
  String get usageTimezoneUnavailable =>
      'تعذّرت قراءة المنطقة الزمنية لهذا الجهاز. أعد المحاولة لتحميل الاستخدام بتواريخ صحيحة.';

  @override
  String get usageRefreshInterrupted =>
      'تغيّر الاتصال أثناء تحميل الاستخدام. حدّث لإعادة المحاولة.';

  @override
  String get usageInvalidResponse =>
      'أعاد الخادم بيانات استخدام غير مكتملة. حدّث لإعادة المحاولة.';

  @override
  String get usageAuthorization =>
      'تحقّق من كلمة مرور هذا الخادم وأذوناته، ثم حدّث.';

  @override
  String get usagePreviousResult => 'تُعرض النتيجة السابقة لهذه المرشّحات.';

  @override
  String get usageLocationChanged =>
      'تغيّر الخادم النشط أو الموقع. افتح الاستخدام مجددًا من الإعدادات.';

  @override
  String get usageTinyCost => 'أقل من \$0.000001';

  @override
  String get usageReportedCost => 'التكلفة المُبلّغ عنها · USD';

  @override
  String get usageSessions => 'الجلسات';

  @override
  String get usageSubagents => 'جلسات الوكلاء الفرعيين';

  @override
  String get usagePrompts => 'الطلبات';

  @override
  String get usageSteps => 'خطوات الوكيل';

  @override
  String get usageActiveDays => 'أيام النشاط';

  @override
  String get usageStreak => 'أطول فترة متواصلة · أيام';

  @override
  String get usageEmpty =>
      'لا يوجد نشاط في هذه الفترة. جرّب فترة أوسع أو «كل المشاريع».';

  @override
  String get usageTokens => 'الرموز';

  @override
  String get usageTotalTokens => 'الإجمالي';

  @override
  String get usageInput => 'الإدخال';

  @override
  String get usageOutput => 'الإخراج';

  @override
  String get usageReasoning => 'الاستدلال';

  @override
  String get usageCacheRead => 'قراءة ذاكرة التخزين المؤقت';

  @override
  String get usageCacheWrite => 'الكتابة في ذاكرة التخزين المؤقت';

  @override
  String get usageModels => 'استخدام النماذج';

  @override
  String get usageNoModels => 'لم يُسجّل استخدام للنماذج في هذه الفترة.';

  @override
  String get usageCostShare => 'النسبة من التكلفة المُبلّغ عنها';

  @override
  String get usageToolReliability => 'موثوقية الأدوات';

  @override
  String get usageToolsUnavailable =>
      'لا يتضمّن هذا الرد بيانات موثوقية الأدوات.';

  @override
  String get usageNoTools => 'لم تُسجّل استدعاءات للأدوات في هذه الفترة.';

  @override
  String get usageNoFinishedTools => 'لا توجد استدعاءات أدوات منتهية بعد.';

  @override
  String get usageToolCalls => 'الاستدعاءات';

  @override
  String get usageSucceeded => 'ناجحة';

  @override
  String get usageFailed => 'فاشلة';

  @override
  String get usageUnfinished => 'غير منتهية';

  @override
  String get usageCostDisclosure =>
      'التكاليف تقديرات يُبلّغ عنها OpenCode وليست فاتورة من مزوّد الخدمة. تُستبعد استدعاءات الأدوات غير المنتهية من نسبة النجاح.';

  @override
  String usagePeriod(String from, String to) {
    return '$from – $to';
  }

  @override
  String usageTimezone(String timezone) {
    return 'المنطقة الزمنية: $timezone';
  }

  @override
  String usageModelSteps(String steps) {
    return 'الخطوات: $steps';
  }

  @override
  String usageModelTokens(String tokens) {
    return 'الرموز: $tokens';
  }

  @override
  String usageSuccessRate(String rate) {
    return 'نجحت نسبة $rate من الاستدعاءات المنتهية';
  }

  @override
  String usageUpdated(String time) {
    return 'آخر تحديث في $time';
  }

  @override
  String get mcpRuntimeTitle => 'حتى إعادة تشغيل الخادم';

  @override
  String get mcpRuntimeDescription =>
      'يُضاف خادم MCP هذا إلى الموقع المحدّد وتُجرى محاولة الاتصال به الآن. ستتم إزالته عند إعادة تشغيل OpenCode. للإعداد الدائم، عدّل إعدادات الخادم.';

  @override
  String get mcpCurrentLocation => 'الموقع الحالي';

  @override
  String get mcpDefaultLocation => 'الموقع الافتراضي لخادم OpenCode';

  @override
  String mcpWorkspaceLocation(String workspace) {
    return 'مساحة العمل: $workspace';
  }

  @override
  String get mcpLocationChanged =>
      'تغيّر الاتصال أو الموقع. لا تزال مسودتك هنا؛ افتح الإعداد مجددًا في الموقع المطلوب قبل الإضافة.';

  @override
  String get mcpAdding => 'جارٍ إضافة خادم MCP';

  @override
  String get mcpAdd => 'إضافة خادم MCP';

  @override
  String get mcpRuntimeEmpty =>
      'أضف أدوات للموقع الحالي حتى إعادة تشغيل OpenCode.';

  @override
  String get mcpRuntimeAdded => 'أُضيف خادم MCP لهذا الموقع';

  @override
  String get sessionUnread => 'نتيجة غير مقروءة';

  @override
  String get shareSessionViewsTitle => 'مزامنة حالة القراءة';

  @override
  String get shareSessionViewsOn =>
      'إعلام تطبيقات OpenCode الأخرى لديك بالنتائج المكتملة التي اطّلعت عليها.';

  @override
  String get shareSessionViewsOff =>
      'تبقى حالة القراءة خاصة بهذا الجهاز. تُحدّد النتائج غير المقروءة من سجل القراءة المحلي.';

  @override
  String get shareSessionViewsSaveError =>
      'تعذّر حفظ هذا التفضيل. مشاركة حالة القراءة معطّلة على هذا الجهاز حاليًا.';

  @override
  String get exportTitle => 'تصدير المحادثة';

  @override
  String get exportDescription => 'اختر صيغة لحفظ هذه المحادثة على جهازك.';

  @override
  String get exportJson => 'المحادثة كاملة · JSON';

  @override
  String get exportJsonDescription =>
      'تنزيل الجلسة كاملة من الخادم، بما فيها الرسائل الأقدم.';

  @override
  String get exportMarkdown => 'سجل سهل القراءة · Markdown';

  @override
  String get exportMarkdownDescription =>
      'حفظ الرسائل المحمّلة حاليًا في هذه المحادثة. حمّل الرسائل الأقدم أولًا إن أردت تضمينها.';

  @override
  String get exportRedact => 'حجب البيانات الحساسة';

  @override
  String get exportRedactDescription =>
      'استبدال نص المحادثة والحقول الحساسة بنصوص بديلة. عطّل هذا الخيار لنسخ النص الأصلي احتياطيًا. راجع أي ملف مصدّر قبل مشاركته.';

  @override
  String get exportUnredacted =>
      'قد يحتوي الملف غير المحجوب على أسرار ومسارات محلية ومخرجات أدوات خاصة.';

  @override
  String get exportSave => 'حفظ الملف';

  @override
  String get exportCancel => 'إلغاء التنزيل';

  @override
  String get exportDownloading => 'جارٍ تنزيل المحادثة كاملة…';

  @override
  String get exportSaving => 'جارٍ حفظ الملف…';

  @override
  String get exportSaved => 'حُفظت المحادثة';

  @override
  String get exportChanged =>
      'تغيّر الاتصال أو الموقع. افتح التصدير مجددًا من المحادثة المطلوبة.';

  @override
  String get exportUnsupported =>
      'لا يدعم هذا الخادم التصدير بصيغة JSON. لا يزال بإمكانك حفظ السجل المحمّل بصيغة Markdown.';

  @override
  String get exportAuthorization =>
      'رفض الخادم الوصول. تحقّق من بيانات اعتماد الاتصال وحاول مجددًا.';

  @override
  String get exportMissing =>
      'لم تعد هذه المحادثة موجودة على الخادم. لا يزال بإمكانك حفظ السجل المحمّل بصيغة Markdown.';

  @override
  String get exportFailed =>
      'تعذّر تصدير المحادثة. تحقّق من الاتصال ومساحة التخزين، ثم حاول مجددًا.';

  @override
  String get importTitle => 'استيراد محادثة';

  @override
  String get importDescription =>
      'استعد ملفًا مصدّرًا بصيغة JSON إلى خادم OpenCode هذا. اختر ملفًا، ثم راجع وجهة استيراده.';

  @override
  String get importChoose => 'اختيار ملف JSON';

  @override
  String get importChooseAnother => 'اختيار ملف آخر';

  @override
  String get importAction => 'استيراد المحادثة';

  @override
  String get importUntitled => 'محادثة بلا عنوان';

  @override
  String importMessageCount(int count) {
    return 'سجلات الرسائل: $count';
  }

  @override
  String get importRedacted =>
      'يحتوي هذا الملف على نصوص بديلة لبيانات محجوبة. لا يمكن للاستيراد استعادة النص الأصلي؛ استخدم ملفًا مصدّرًا دون حجب إذا كنت تحتاجه.';

  @override
  String importParent(String id) {
    return 'يجب أن تكون المحادثة الأم $id موجودة على هذا الخادم. استورد المحادثة الأم أولًا.';
  }

  @override
  String get importArchived =>
      'هذه المحادثة مؤرشفة. ستبقى مؤرشفة بعد الاستيراد.';

  @override
  String get importDestination => 'الاستيراد إلى';

  @override
  String get importChooseDestination => 'اختيار مجلد على هذا الخادم';

  @override
  String get importChangeDestination => 'تغيير الوجهة';

  @override
  String get importNoDestinations =>
      'لا تتوفر مجلدات مشاريع. افتح مشروعًا على هذا الخادم، ثم حاول مجددًا.';

  @override
  String get importDestinationFailed =>
      'تعذّر تحميل مشاريع الوجهة أو مساحات عملها. حاول مجددًا؛ لا يزال ملفك محدّدًا.';

  @override
  String get importPreserves =>
      'لن يتغيّر الملف المصدر. لن تُستبدل أي محادثة موجودة، ولن يبدأ تشغيل وكيل بسبب الاستيراد.';

  @override
  String get importReading => 'جارٍ تجهيز الاستيراد…';

  @override
  String get importSending => 'جارٍ استيراد المحادثة…';

  @override
  String get importSucceeded => 'استُوردت المحادثة';

  @override
  String get importOpen => 'فتح المحادثة';

  @override
  String get importOpenFailed =>
      'استُوردت المحادثة، لكن تعذّر فتحها. ابحث عنها في «كل الجلسات» على خادم الوجهة.';

  @override
  String get importChanged =>
      'تغيّر الاتصال أو الموقع. لا يزال ملفك هنا. افتح الاستيراد مجددًا على الخادم المطلوب قبل المتابعة.';

  @override
  String get importUnsupported => 'لا يدعم هذا الخادم الاستيراد بصيغة JSON.';

  @override
  String get importInvalidFile =>
      'اختر ملف OpenCode صالحًا مصدّرًا بصيغة JSON ويحتوي على معلومات الجلسة وسجلات الرسائل. لا يمكن استيراد سجلات Markdown.';

  @override
  String get importTooLarge =>
      'يتجاوز هذا الملف حد الاستيراد على الهاتف البالغ 128 MiB. لم يُرفع الملف ولم يُقتطع منه شيء. انقله باستخدام حاسوب أو خادم.';

  @override
  String get importConflict =>
      'توجد محادثة بهذا المعرّف على هذا الخادم بالفعل. لم يُستبدل شيء. ابحث عنها في «كل الجلسات»، أو استورد هذا الملف على خادم آخر.';

  @override
  String get importAuthorization =>
      'رفض الخادم الوصول. تحقّق من بيانات اعتماد الاتصال. لا يزال ملفك محدّدًا.';

  @override
  String get importParentMissing =>
      'المحادثة الأم غير موجودة على هذا الخادم. استورد المحادثة الأم أولًا، ثم أعد محاولة استيراد هذا الملف.';

  @override
  String get importRejected =>
      'رفض الخادم صيغة هذا الملف المصدّر. لا يزال ملفك محدّدًا؛ تحقّق من أنه صادر عن خادم OpenCode متوافق.';

  @override
  String get importUnconfirmed =>
      'تعذّر تأكيد الاستيراد. تحقّق من «كل الجلسات» قبل إعادة المحاولة؛ فقد يكون الخادم قد استلمه. لم يتغيّر الملف المصدر.';

  @override
  String get sessionsNoOtherRecent => 'لا توجد محادثات حديثة أخرى';

  @override
  String get sessionPin => 'تثبيت على هذا الجهاز';

  @override
  String get sessionUnpin => 'إلغاء التثبيت';

  @override
  String get sessionPinned => 'مثبّتة';

  @override
  String get sessionPinFailed =>
      'تعذّر حفظ التثبيت. تحقّق من مساحة تخزين الجهاز ومن أن موقع الجلسة لم يتغيّر، ثم حاول مجددًا.';

  @override
  String get sessionPinsLoadFailed =>
      'تعذّر تحميل بعض المحادثات المثبّتة. حدّث لإعادة المحاولة.';

  @override
  String get promptStashSaveFailed =>
      'تعذّر حفظ هذا الطلب. لم يتغيّر محتوى محرّر الرسالة. تحقّق من مساحة تخزين الجهاز وحاول مجددًا.';

  @override
  String get promptOriginalDraft => 'استعادة المسودة الأصلية';

  @override
  String get promptStashTitle => 'الطلبات المحفوظة';

  @override
  String get promptStashSearch => 'البحث في الطلبات المحفوظة';

  @override
  String get promptStashNoMatches =>
      'لا توجد طلبات محفوظة تطابق بحثك. امسح البحث أو غيّره لعرض المزيد.';

  @override
  String get promptStashDeleteFailed =>
      'تعذّر حذف هذا الطلب المحفوظ. حاول مجددًا.';

  @override
  String get promptRestoreTitle => 'هل تريد استعادة الطلب المحفوظ؟';

  @override
  String get promptRestorePreserve =>
      'سيُحفظ طلبك الحالي أولًا ضمن الطلبات المحفوظة، بما فيه من مرفقات ومراجع.';

  @override
  String get promptStashDelete => 'حذف';

  @override
  String get promptStashFull =>
      'لديك 50 طلبًا محفوظًا. احذف طلبًا محفوظًا لتوفير مساحة؛ لم يتغيّر طلبك الحالي.';

  @override
  String get promptStashListDescription =>
      'محفوظة على هذا الجهاز لهذا الخادم. عند استعادة طلب، يُحفظ أي طلب حالي أيضًا لاستخدامه لاحقًا.';

  @override
  String get promptStashDeleteTitle => 'هل تريد حذف الطلب المحفوظ؟';

  @override
  String promptStashAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرفق',
      many: '$count مرفقًا',
      few: '$count مرفقات',
      two: 'مرفقان',
      one: 'مرفق واحد',
      zero: 'لا توجد مرفقات',
    );
    return '$_temp0';
  }

  @override
  String promptStashReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرجع',
      many: '$count مرجعًا',
      few: '$count مراجع',
      two: 'مرجعان',
      one: 'مرجع واحد',
      zero: 'لا توجد مراجع',
    );
    return '$_temp0';
  }

  @override
  String get promptRestoredCopyKept =>
      'استُعيد المحتوى المتاح. تبقى نسخة ضمن الطلبات المحفوظة. راجع المرفقات والمراجع قبل الإرسال.';

  @override
  String get promptAttachmentsUnavailable => 'يتعذّر استعادة بعض المرفقات';

  @override
  String get promptRestore => 'استعادة';

  @override
  String get promptHistorySaveFailed =>
      'أُرسل الطلب، لكن تعذّر حفظه في السجل على هذا الجهاز.';

  @override
  String promptAttachmentsUnavailableDetail(String names) {
    return 'مرفقات مفقودة أو تالفة أو مؤقتة: $names. استعد المحتوى المتاح وأعد إرفاق هذه الملفات قبل الإرسال. ستبقى النسخة ضمن الطلبات المحفوظة.';
  }

  @override
  String get promptStashMigrationPending =>
      'تعذّر نقل بعض المرفقات المحفوظة إلى تخزين المرفقات المحلي حتى الآن. احتُفظ بمحتواك المحفوظ. وفّر مساحة على الجهاز وأعد المحاولة.';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get shareWaitingForServer =>
      'اتصل بخادم لفتح النص المشترك في جلسة جديدة.';

  @override
  String get shareSessionFailed =>
      'احتُفظ بالنص المشترك. تعذّر فتح جلسة. أعد المحاولة عندما يكون الاتصال جاهزًا.';

  @override
  String get webSourcesDisclosure =>
      'لا يتاح البحث في الويب عبر بوابة التطبيق لهذا الاتصال. الصق رابطًا عامًا، ويمكنك إضافة مقتطف تريد تضمينه. لن تُجلب أي صفحة، ولن يُرسل شيء إلى النموذج هنا.';

  @override
  String get webSourcesScopeChanged =>
      'تغيّر الاتصال. أغلق «إضافة مصدر ويب» وافتحه مجددًا.';

  @override
  String get webSourcesUrl => 'رابط عام';

  @override
  String get webSourcesLabel => 'العنوان (اختياري)';

  @override
  String get webSourcesExcerpt => 'مقتطف ملصق (اختياري)';

  @override
  String get webSourcesExcerptHint =>
      'نص يقدّمه المستخدم، وليس محتوى صفحة جرى التحقق منه.';

  @override
  String get webSourcesAdd => 'إضافة للمراجعة';

  @override
  String webSourcesReviewCount(int count) {
    return 'مراجعة المصادر ($count/10)';
  }

  @override
  String get webSourcesReviewHint => 'ستُعاد المصادر المحدّدة فقط إلى مسودتك.';

  @override
  String get webSourcesEmpty => 'لم تُضف مصادر بعد.';

  @override
  String get webSourcesOpen => 'فتح في المتصفّح';

  @override
  String webSourcesUseCount(int count) {
    return 'استخدام المصادر المحدّدة ($count)';
  }

  @override
  String get digestTitle => 'ملخّصات انتهاء التشغيل';

  @override
  String get digestSubtitle =>
      'عند الطلب · بيانات وصفية مخزّنة مؤقتًا، وليست ملخّصات ذكاء اصطناعي';

  @override
  String get digestEmpty =>
      'لا تتوفر بيانات وصفية لعمليات تشغيل منتهية في هذا الموقع. حالة الخمول وحدها لا تثبت نجاح التشغيل.';

  @override
  String get digestIdle => 'سُجّل خمول الخادم · لم يُتحقَّق من النتيجة';

  @override
  String get digestStatusUnverified =>
      'أبلغ الخادم عن حالة خمول. لم يُتحقَّق من النجاح أو الفشل.';

  @override
  String get digestChangedFilesUnknown => 'الملفات المتغيّرة: غير معروفة.';

  @override
  String digestChangedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ملف متغيّر في إجمالي الجلسة؛ أما هذا التشغيل فحالته غير معروفة.',
      many:
          '$count ملفًا متغيّرًا في إجمالي الجلسة؛ أما هذا التشغيل فحالته غير معروفة.',
      few:
          '$count ملفات متغيّرة في إجمالي الجلسة؛ أما هذا التشغيل فحالته غير معروفة.',
      two:
          'ملفان متغيّران في إجمالي الجلسة؛ أما هذا التشغيل فحالته غير معروفة.',
      one:
          'ملف واحد متغيّر في إجمالي الجلسة؛ أما هذا التشغيل فحالته غير معروفة.',
      zero:
          'لا توجد ملفات متغيّرة في إجمالي الجلسة؛ أما هذا التشغيل فحالته غير معروفة.',
    );
    return '$_temp0';
  }

  @override
  String get digestPendingDecisionsUnknown => 'القرارات المنتظرة: غير معروفة.';

  @override
  String digestPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قرار منتظر في البيانات المخزّنة مؤقتًا حاليًا.',
      many: '$count قرارًا منتظرًا في البيانات المخزّنة مؤقتًا حاليًا.',
      few: '$count قرارات منتظرة في البيانات المخزّنة مؤقتًا حاليًا.',
      two: 'قراران منتظران في البيانات المخزّنة مؤقتًا حاليًا.',
      one: 'قرار واحد منتظر في البيانات المخزّنة مؤقتًا حاليًا.',
      zero: 'لا توجد قرارات منتظرة في البيانات المخزّنة مؤقتًا حاليًا.',
    );
    return '$_temp0';
  }

  @override
  String get digestOutcomesUnknown =>
      'نتائج الأدوات والمهام المتبقية: غير معروفة.';

  @override
  String get digestProvenance =>
      'بيانات وصفية مخزّنة مؤقتًا من الخادم فقط. لا يوجد ملخّص ذكاء اصطناعي أو استدعاء للنموذج. افتح المحادثة للتحقق من النتائج ومراجعة التغييرات أو المهام.';

  @override
  String get digestOpenConversation => 'فتح المحادثة';

  @override
  String get digestReview => 'مراجعة الخطوات التالية';

  @override
  String get digestCopy => 'نسخ الملخّص';

  @override
  String get digestCopySucceeded => 'نُسخ الملخّص';

  @override
  String get digestCopyFailed => 'تعذّر نسخ الملخّص';

  @override
  String get digestDismiss => 'إخفاء';

  @override
  String get digestRunResults => 'نتائج التشغيل';

  @override
  String get runResultsScopeChanged =>
      'تغيّر الاتصال أو المشروع. أغلق هذا العرض وافتح نتائج التشغيل مجددًا من المشروع المطلوب.';

  @override
  String get runResultsTitle => 'نتائج التشغيل';

  @override
  String get runResultsEmpty =>
      'لم تبدأ أي خطوة للمساعد في التبادل الأخير بعد، لذلك لا يوجد ما يُعرض.';

  @override
  String runResultsRunLabel(String id) {
    return 'التشغيل …$id';
  }

  @override
  String runResultsSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خطوة للمساعد',
      many: '$count خطوة للمساعد',
      few: '$count خطوات للمساعد',
      two: 'خطوتان للمساعد',
      one: 'خطوة واحدة للمساعد',
      zero: 'لا توجد خطوات للمساعد',
    );
    return '$_temp0';
  }

  @override
  String runResultsStepsAtLeast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُمّلت $count خطوة للمساعد على الأقل',
      many: 'حُمّلت $count خطوة للمساعد على الأقل',
      few: 'حُمّلت $count خطوات للمساعد على الأقل',
      two: 'حُمّلت خطوتان للمساعد على الأقل',
      one: 'حُمّلت خطوة واحدة للمساعد على الأقل',
      zero: 'لم تُحمّل خطوات للمساعد',
    );
    return '$_temp0';
  }

  @override
  String runResultsStarted(String time) {
    return 'بدأ في $time';
  }

  @override
  String get runResultsStartedUnknown => 'لم يُسجّل وقت البدء';

  @override
  String runResultsFinished(String time) {
    return 'انتهى في $time';
  }

  @override
  String get runResultsFinishedUnknown => 'لم يُسجّل وقت الانتهاء';

  @override
  String get runResultsPartialHistory =>
      'لم يُعثر في السجل المحمّل على الرسالة التي بدأت هذا التشغيل. الأعداد هنا حدود دنيا، ومعرّف التشغيل يمثّل أقدم خطوة محمّلة فقط.';

  @override
  String get runResultsOutcomeCompleted => 'مكتمل';

  @override
  String get runResultsOutcomeCutOff => 'قطعه مزوّد الخدمة';

  @override
  String get runResultsOutcomeFailed => 'فشل';

  @override
  String get runResultsOutcomeAborted => 'أُلغي';

  @override
  String get runResultsOutcomeRunning => 'لا يزال يعمل';

  @override
  String get runResultsOutcomeNotReported => 'لم يُبلّغ عن النتيجة';

  @override
  String runResultsFinishReason(String finish) {
    return 'سبب الانتهاء لدى مزوّد الخدمة: $finish';
  }

  @override
  String get runResultsFinishReasonMissing =>
      'لم يقدّم مزوّد الخدمة سببًا للانتهاء.';

  @override
  String runResultsEarlierErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أبلغت $count خطوة سابقة عن أخطاء؛ تحدّد أحدث خطوة النتيجة.',
      many: 'أبلغت $count خطوة سابقة عن أخطاء؛ تحدّد أحدث خطوة النتيجة.',
      few: 'أبلغت $count خطوات سابقة عن أخطاء؛ تحدّد أحدث خطوة النتيجة.',
      two: 'أبلغت خطوتان سابقتان عن أخطاء؛ تحدّد أحدث خطوة النتيجة.',
      one: 'أبلغت خطوة سابقة عن خطأ؛ تحدّد أحدث خطوة النتيجة.',
      zero: 'لم تُبلّغ الخطوات السابقة عن أخطاء؛ تحدّد أحدث خطوة النتيجة.',
    );
    return '$_temp0';
  }

  @override
  String get runResultsObservedLive =>
      'تلقّى هذا الهاتف إشعار اكتمال أحدث خطوة مباشرة.';

  @override
  String get runResultsFromHistory =>
      'استُعيدت البيانات من سجل الخادم. لم يرصد هذا الهاتف اكتمال أحدث خطوة مباشرة.';

  @override
  String get runResultsNoToolEvidence =>
      'لم يُسجّل هذا التشغيل استدعاءات أدوات، لذلك لا يوجد دليل من الملفات أو الأوامر. لا يعني ذلك عدم وجود تغييرات.';

  @override
  String get runResultsChangedFilesTitle => 'الملفات المتغيّرة';

  @override
  String get runResultsChangedFilesSource =>
      'من أدوات التحرير والكتابة والترقيع المكتملة في هذا التشغيل. لا يمثّل ذلك مقارنة موثّقة لتغييرات شجرة العمل.';

  @override
  String get runResultsNoChangedFiles =>
      'لا توجد أداة مكتملة غيّرت ملفات في هذا التشغيل.';

  @override
  String get runResultsChangeEdited => 'عُدّل';

  @override
  String get runResultsChangeWritten => 'كُتب';

  @override
  String get runResultsChangePatched => 'طُبّقت رقعة';

  @override
  String get runResultsCommandsTitle => 'الأوامر';

  @override
  String get runResultsCommandsSource =>
      'من أدوات bash والصدفة في هذا التشغيل. تظهر رموز الخروج فقط إذا سجّلها الخادم.';

  @override
  String get runResultsNoCommands => 'لم تُنفّذ أوامر في هذا التشغيل.';

  @override
  String get runResultsCommandEmpty => '(لم يُسجّل نص الأمر)';

  @override
  String runResultsExit(int code) {
    return 'رمز الخروج $code';
  }

  @override
  String get runResultsExitUnknown => 'لم يُسجّل رمز الخروج';

  @override
  String get runResultsCommandFailed => 'أبلغت الأداة عن فشل';

  @override
  String get runResultsLooksLikeTest =>
      'يبدو أمر اختبار (استنادًا إلى نص الأمر فقط)';

  @override
  String get runResultsOutputPruned => 'حذف الخادم المخرجات';

  @override
  String runResultsPrunedTools(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف الخادم مخرجات $count أداة ولا يمكن فتحها.',
      many: 'حذف الخادم مخرجات $count أداة ولا يمكن فتحها.',
      few: 'حذف الخادم مخرجات $count أدوات ولا يمكن فتحها.',
      two: 'حذف الخادم مخرجات أداتين ولا يمكن فتحها.',
      one: 'حذف الخادم مخرجات أداة واحدة ولا يمكن فتحها.',
      zero: 'لم يحذف الخادم أي مخرجات أدوات.',
    );
    return '$_temp0';
  }

  @override
  String get runResultsTruncated =>
      'تُعرض 50 خانة بحد أقصى في كل قائمة. افتح المحادثة للاطّلاع على الباقي.';

  @override
  String get runResultsSourceNote =>
      'كل ما يظهر هنا منقول من سجلات الرسائل والأدوات على الخادم. لم يلخّص النموذج أيًا منه.';

  @override
  String get runResultsOutputTitle => 'مخرجات الأداة المسجّلة';

  @override
  String get runResultsOpenConversation => 'فتح المحادثة';

  @override
  String get attentionDisclosure =>
      'نظرة عامة محلية، وليست مراقبة مباشرة عبر الخوادم. قد تكون الإشارات المخزّنة مؤقتًا غير مكتملة أو قديمة. افتح خادمًا للتحقق من نشاطه الحالي.';

  @override
  String get attentionNavigationUnavailable =>
      'لا يمكن فتح الخوادم هنا. ارجع إلى الرئيسية لاختيار خادم وعرض النشاط.';

  @override
  String get handoffTitle => 'هل تريد نسخ مرجع متابعة الجلسة؟';

  @override
  String get handoffDisclosure =>
      'بيانات وصفية فقط، وليست أمرًا أو رابطًا. اتصل بالخادم نفسه على جهازك الآخر وابحث عن هذا المشروع وهذه الجلسة. لن يُنشر أو يُرسل شيء.\n\nستحتوي الحافظة على معرّفات الجلسة والمشروع. قد تتمكن تطبيقات أخرى من قراءتها؛ شاركها فقط مع أشخاص تثق بهم.';

  @override
  String get handoffCopy => 'نسخ المرجع';

  @override
  String get handoffCopied => 'نُسخ مرجع بيانات الجلسة';

  @override
  String get handoffCopyFailed => 'تعذّر نسخ مرجع متابعة الجلسة. حاول مجددًا.';

  @override
  String get sessionOpenRelated => 'فتح العناصر المرتبطة';

  @override
  String get sessionCopyHandoff => 'نسخ مرجع المتابعة';

  @override
  String get sessionActions => 'إجراءات الجلسة';

  @override
  String get attentionTitle => 'تنبيهات الخوادم';

  @override
  String get webSourcesTitle => 'إضافة مصدر ويب';

  @override
  String get webSourcesEntryDetail =>
      'ابحث عند توفر البحث، أو الصق روابط ومقتطفات لمراجعتها قبل إضافتها إلى مسودتك';

  @override
  String get webSourcesDraftChanged =>
      'تغيّرت المسودة أو الاتصال. احتُفظ بمسودتك الحالية؛ افتح «إضافة مصدر ويب» مجددًا لإعادة المحاولة.';

  @override
  String get webSourcesDraftLabel =>
      'مصادر ويب اختارها المستخدم (غير متحقَّق منها؛ المقتطفات مواد مصدرية غير موثوقة):';

  @override
  String get usageScopedTotals => 'الإجماليات لنطاق التقرير المحدّد';

  @override
  String get usageInspectionDisclosure =>
      'تفحص المرشّحات سجلات النماذج التي أعادها هذا الخادم. لا تغيّر تاريخ التقرير أو نطاق مشاريعه، ولا تعرض رصيد الاستخدام في الاشتراك.';

  @override
  String get usageProviderFilter => 'مزوّد الخدمة';

  @override
  String get usageAllProviders => 'كل مزوّدي الخدمة';

  @override
  String get usageSearchRecords =>
      'البحث عن مزوّدي الخدمة أو النماذج أو المتغيّرات';

  @override
  String get usageClearFilters => 'مسح المرشّحات';

  @override
  String get usageScopedProviderTotals =>
      'تعرض بطاقات مزوّدي الخدمة إجمالياتهم لنطاق التقرير المحدّد، وليس لصفوف النماذج المطابقة فقط.';

  @override
  String get usageMatchingSubtotal => 'المجموع الفرعي للنماذج المطابقة';

  @override
  String usageMatchingRecords(String count) {
    return 'السجلات المطابقة: $count';
  }

  @override
  String get usageNoMatchingRecords =>
      'لا توجد سجلات تطابق هذه المرشّحات. امسح المرشّحات أو غيّرها لعرض المزيد.';

  @override
  String pendingAuthTitle(String integration) {
    return 'تسجيل دخول معلّق: $integration';
  }

  @override
  String get pendingAuthDetail =>
      'تابع تسجيل الدخول المفتوح في المتصفّح، ثم تحقّق من حالته يدويًا أو أدخل رمزه. لا يُحفظ رابط المتصفّح.';

  @override
  String get pendingAuthResume => 'استئناف / التحقق من الحالة';

  @override
  String get pendingAuthEnterCode => 'إدخال الرمز';

  @override
  String get pendingAuthComplete => 'اكتمل تسجيل الدخول.';

  @override
  String get pendingAuthStillPending =>
      'لا يزال تسجيل الدخول معلّقًا. لم تبدأ محاولة جديدة.';

  @override
  String get pendingAuthServerFailed =>
      'أبلغ الخادم عن فشل تسجيل الدخول. تفاصيل خطأ مزوّد الخدمة مخفية.';

  @override
  String get pendingAuthExpired =>
      'انتهت صلاحية هذه المحاولة أو تجاوزت مدة الاسترداد على الجهاز. إلغاء المحاولة إجراء منفصل على الخادم.';

  @override
  String get pendingAuthFailed =>
      'تعذّر تأكيد الإجراء. تحقّق من عمليات تسجيل الدخول المعلّقة قبل المحاولة مجددًا. لم يبدأ تسجيل دخول جديد.';

  @override
  String get pendingAuthSaveUncertain =>
      'تعذّر حفظ بيانات الاسترداد بشكل موثوق. أبقِ هذا التطبيق مفتوحًا وأعد محاولة الحفظ؛ فقد تضيع هذه المحاولة عند إعادة التشغيل. إذا لم تُفتح صفحة في المتصفّح، فألغِ المحاولة قبل البدء مجددًا.';

  @override
  String get pendingAuthRetrySave => 'إعادة حفظ بيانات الاسترداد';

  @override
  String get pendingAuthForget => 'إزالة السجل من هذا الجهاز';

  @override
  String get pendingAuthForgetDetail =>
      'هل تريد إزالة سجل الاسترداد من هذا الجهاز فقط؟ لن يؤدي ذلك إلى إلغاء أمر على الخادم أو إبطال بيانات الاعتماد أو إتمام التفويض. قد تستمر المحاولة على الخادم حتى تنتهي صلاحيتها.';

  @override
  String get pendingAuthUnsupported =>
      'لا يتيح هذا الاتصال استرداد عمليات تسجيل الدخول السابقة. تعمل عمليات تسجيل الدخول القديمة فقط ما دامت الشاشة والاتصال الأصليان متاحين.';

  @override
  String get pendingAuthOtherSource =>
      'تتبع عمليات تسجيل الدخول المعلّقة الأخرى عنوان خادم أو موقعًا آخر. ارجع إلى مصدرها الأصلي لإدارتها.';

  @override
  String get connectionHelpTitle => 'مساعدة الاتصال';

  @override
  String get connectionHelpEntrySubtitle => 'شرح العنوان محليًا دون اتصال';

  @override
  String get connectionHelpGuideTip =>
      'أبقِ الخادم بعيدًا عن الإنترنت العام. استخدم HTTPS خاصًا أو نفقًا مشفّرًا ينتهي على الجهاز الذي يشغّل هذا التطبيق. يشير localhost على حاسوبك إلى غير ما يشير إليه على هاتفك. افتح مساعدة الاتصال أعلاه للاطّلاع على الخطوات والأمثلة.';

  @override
  String get connectionHelpPrivacy =>
      'يُفحص تنسيق العنوان فقط، دون اختبار الاتصال. لن يُرسل أو يُحفظ شيء. يُخفى الإدخال ويُمسح بعد الفحص. الصق عنوانًا فقط، دون كلمة مرور أو رمز اقتران.';

  @override
  String get connectionHelpAddress => 'عنوان الخادم';

  @override
  String get connectionHelpCheck => 'شرح العنوان';

  @override
  String get connectionHelpEmpty => 'أدخل عنوان خادم لشرحه.';

  @override
  String get connectionHelpMalformed =>
      'تعذّر فهم هذا العنوان. استخدم عنوان أصل كاملًا مثل https://server.example، دون مسار أو بيانات اعتماد أو استعلام.';

  @override
  String get connectionHelpCredentials =>
      'لا تضع بيانات الاعتماد في الرابط. أزلها وأدخل اسم مستخدم الخادم وكلمة مروره في حقليهما المنفصلين ضمن الخوادم. مُسحت القيمة الملصقة.';

  @override
  String get connectionHelpQuery =>
      'أزل معاملات الاستعلام والأجزاء اللاحقة لعلامة #؛ فقد تحتوي على أسرار. أدخل عنوان أصل الخادم فقط. مُسحت القيمة الملصقة.';

  @override
  String get connectionHelpPath =>
      'أزل المسار. يحتاج هذا التطبيق إلى عنوان أصل الخادم، وليس عنوان صفحة أو مسار API.';

  @override
  String get connectionHelpScheme =>
      'استخدم HTTPS للخادم البعيد، أو HTTP فقط لعناوين الاسترجاع المحلي المدعومة لهذا الجهاز.';

  @override
  String get connectionHelpRemoteHttp =>
      'اتصالات HTTP البعيدة محظورة، بما فيها عناوين الشبكة المحلية و100.64.0.0/10. لا يغيّر استخدام VPN هذه القاعدة. أعدّ HTTPS خاصًا أو نفقًا مشفّرًا ينتهي على هذا الجهاز.';

  @override
  String get connectionHelpHttps =>
      'يستوفي هذا العنوان قواعد عناوين HTTPS. لا يؤكد ذلك صحة شهادته أو إمكانية الوصول إليه أو تسجيل الدخول أو الخصوصية. يُفسَّر العنوان البعيد دون بروتوكول على أنه HTTPS.';

  @override
  String get connectionHelpLoopback =>
      'يستوفي هذا العنوان قواعد الاسترجاع المحلي. يشير localhost إلى هذا الجهاز، وليس حاسوبًا آخر. يجب أن يكون خادم أو نفق بانتظار الاتصال هنا؛ لا يتحقّق هذا الفحص من ذلك.';

  @override
  String get connectionHelpPrivateTitle => 'HTTPS خاص أو وكيل عكسي';

  @override
  String get connectionHelpPrivateSteps =>
      '1. أبقِ الخادم على عنوان الاسترجاع المحلي لجهازه مع تفعيل المصادقة.\n2. صِل الجهازين بشبكتك الخاصة واقصر الوصول على المستخدمين المقصودين.\n3. أعدّ HTTPS خاصًا، مثل Tailscale Serve، أو وكيلًا عكسيًا بشهادة موثوقة يوجّه الاتصالات إلى الخادم. فعّل دعم البث وWebSockets.\n4. أضف عنوان أصل HTTPS ضمن الخوادم وأدخل بيانات تسجيل الدخول في حقول منفصلة.\nتجعل Tailscale Funnel الخدمة متاحة للعامة؛ وليست حلًا لشبكة خاصة. لا يستطيع هذا التطبيق استنتاج وجود VPN. المثال أدناه توضيحي فقط.';

  @override
  String get connectionHelpTunnelTitle =>
      'هل تستخدم localhost على الجهاز الخطأ؟';

  @override
  String get connectionHelpTunnelSteps =>
      'تشير localhost و127.0.0.1 و[::1] إلى الجهاز الذي يشغّل هذا التطبيق. للوصول إلى خادم على حاسوب آخر، استخدم HTTPS خاصًا أو نفقًا مشفّرًا ينتهي هنا. إذا توفر عميل SSH على هذا الجهاز، فعدّل المثال أدناه بما يناسبك، وتحقّق من مفتاح المضيف وأبقِه قيد التشغيل. استبدل user@host بوجهة SSH لديك. تشغيله على حاسوب آخر لا يعيد توجيه منفذ هذا الجهاز. أبقِ مصادقة الخادم مفعّلة.';

  @override
  String get connectionHelpVerifyTitle => 'التحقق من الاتصال بشكل منفصل';

  @override
  String get connectionHelpVerifySteps =>
      'على هذا الجهاز، تحقّق من الانضمام إلى الشبكة الخاصة وDNS وسماح جدار الحماية وموثوقية الشهادة باستخدام أدوات الشبكة لديك. تحقّق من إعدادات الخادم والوكيل على المضيف، ثم اتصل من قسم الخوادم. لا تعطّل التحقق من TLS ولا تشارك كلمات المرور أو رموز الاقتران أو السجلات غير المحجوبة. يمنح الوصول إلى هذا الخادم إمكانية استخدام الصدفة.';

  @override
  String get connectionHelpCopyExample => 'نسخ المثال';

  @override
  String get connectionHelpCopied => 'نُسخ المثال';

  @override
  String get connectionHelpCopyFailed =>
      'تعذّر نسخ المثال. حدّد نص المثال لنسخه يدويًا.';

  @override
  String get voiceConversationTitle => 'محادثة صوتية';

  @override
  String get voiceConversationDescription =>
      'استمع وراجع، ثم أرسل. لا يبدأ الاستماع تلقائيًا؛ تُقرأ الردود بصوت عالٍ فقط إذا فعّلت ذلك.';

  @override
  String get voiceConversationSpeakReplies => 'قراءة الردود بصوت عالٍ';

  @override
  String get voiceConversationSpeakRepliesDetail =>
      'قراءة الرد المرتبط برسالتك مرة واحدة بعد الإرسال. اضغط «استماع» لاستخدام الميكروفون.';

  @override
  String get voiceConversationWaitingReply => 'بانتظار الرد…';

  @override
  String get voiceConversationSpeakingReply => 'جارٍ قراءة الرد بصوت عالٍ';

  @override
  String get voiceConversationStopReply => 'إيقاف';

  @override
  String get voiceConversationReadReply => 'قراءة الرد';

  @override
  String get voiceConversationReplyReviewNeeded =>
      'اكتمل الرد، لكن تعذّر التأكد من ارتباطه برسالتك. يمكنك قراءته إن أردت.';

  @override
  String get voiceConversationReplyInterrupted =>
      'احتاج الرد إلى قرار على الشاشة، لذلك لم يُقرأ تلقائيًا.';

  @override
  String get voiceConversationReplyNoProse =>
      'لا يتضمّن الرد نصًا لقراءته. لا تُقرأ الشيفرة ولا تفاصيل الأدوات بصوت عالٍ.';

  @override
  String get voiceConversationReplyFailed => 'تعذّرت قراءة الرد بصوت عالٍ.';

  @override
  String get voiceConversationPausedTitle => 'المحادثة الصوتية متوقفة مؤقتًا';

  @override
  String get voiceConversationPausedDetail =>
      'المحادثة الصوتية متوقفة مؤقتًا. أعد الاتصال أو انتظر الرد أو راجع القرارات المنتظرة على الشاشة.';

  @override
  String get voiceConversationDraftFirst =>
      'أرسل مسودتك الحالية أو احفظها أو امسحها قبل بدء المحادثة الصوتية.';

  @override
  String get voiceConversationListen => 'استماع';

  @override
  String get voiceConversationExit => 'الخروج من الوضع الصوتي';

  @override
  String get voiceConversationCommandsOnly =>
      'استخدم محرّر الرسالة النصي للأوامر التي تبدأ بشرطة مائلة.';

  @override
  String get voiceConversationInterrupted =>
      'انقطعت المحادثة الصوتية. راجع المحتوى قبل الإرسال مجددًا.';

  @override
  String get voiceReviewExplicitAction =>
      'عدّل النص قبل إدراجه. يتطلب الإرسال دائمًا إجراءً صريحًا منك.';

  @override
  String get voiceInputInterrupted =>
      'انقطع الإدخال الصوتي. أغلقه وابدأ مجددًا عندما تكون جاهزًا.';

  @override
  String get voiceInputClose => 'إغلاق الإدخال الصوتي';

  @override
  String get voiceInputUnavailable =>
      'الإدخال الصوتي غير متاح. تحقّق من إعدادات النموذج المحلي والميكروفون.';

  @override
  String get voiceConversationInstructions =>
      'راجع النص المنسوخ من صوتك وأدرجه، ثم اضغط «إرسال» في محرّر الرسالة. تُقرأ الردود بصوت عالٍ فقط عند تفعيل خيار القراءة، ويُقرأ الرد على ما أرسلته للتو فقط. يُحذف النص غير المرسل عند مغادرة الوضع الصوتي أو المحادثة أو التطبيق.';

  @override
  String get desktopDropFailedTitle => 'تعذّر إرفاق الملفات المُسقطة';

  @override
  String get desktopDropFailedRecovery =>
      'تحقّق من المرفقات المضافة بالفعل قبل المحاولة مجددًا. يمكنك أيضًا استخدام لوحة المفاتيح لفتح «إضافة» ثم «إرفاق ملف».';

  @override
  String get desktopContextMenuShortcutKeys =>
      'نقر بزر الفأرة الأيمن / Shift + F10 / مفتاح القائمة';

  @override
  String get commandAuthManage => 'تسجيل الدخول على الخادم';

  @override
  String get commandAuthMethodHint =>
      'تشغيل طريقة تسجيل الدخول الخاصة بمزوّد الخدمة على الخادم المحدّد، وليس على هذا الهاتف. قد تحتاج إلى إتمام خطوات تفاعلية على الخادم.';

  @override
  String get commandAuthConfirmTitle => 'هل تريد بدء تسجيل الدخول على الخادم؟';

  @override
  String get commandAuthConfirmDetail =>
      'سينفّذ OpenCode طريقة تسجيل الدخول المعلنة لهذا المزوّد على الخادم المحدّد. تابع فقط إذا كنت تثق بالخادم ومزوّد الخدمة. لا يشغّل التطبيق أمر صدفة على هاتفك ولا ينسخه إليه.';

  @override
  String get commandAuthStart => 'بدء تسجيل الدخول على الخادم';

  @override
  String get commandAuthPending =>
      'تسجيل الدخول معلّق على الخادم. أكمل أي تفاعل مطلوب على الخادم، ثم تحقّق من حالته. إغلاق هذه اللوحة لا يلغيه.';

  @override
  String get commandAuthCheck => 'التحقق من الحالة';

  @override
  String get commandAuthCancel => 'إلغاء تسجيل الدخول';

  @override
  String get commandAuthFailed =>
      'تعذّر إتمام تسجيل الدخول على الخادم أو تأكيده. تحقّق من المحاولة الحالية قبل بدء أخرى.';

  @override
  String get commandAuthComplete =>
      'أبلغ الخادم عن اكتمال تسجيل الدخول. حدّث مزوّدي الخدمة للاطّلاع على الاتصالات الحالية.';

  @override
  String get commandAuthExpired =>
      'انتهت صلاحية محاولة تسجيل الدخول هذه. يمكنك بدء محاولة جديدة.';

  @override
  String get commandAuthScopeChanged =>
      'تغيّر الخادم أو المشروع. ارجع إلى الموقع الأصلي وافتح تسجيل الدخول مجددًا لإدارة محاولته.';

  @override
  String get commandAuthUncertainStart =>
      'ربما بدأ الخادم تسجيل الدخول، لكن تعذّر على التطبيق استرداد محاولته بأمان. تحقّق على الخادم قبل إعادة المحاولة؛ مُنع البدء التلقائي مجددًا لتجنّب تكرار العمليات.';

  @override
  String get readAloudAction => 'قراءة نص الرد بصوت عالٍ';

  @override
  String get readAloudStop => 'إيقاف القراءة بصوت عالٍ';

  @override
  String get readAloudOtherVoice => 'القراءة بصوت آخر';

  @override
  String get readAloudChooseVoice => 'اختيار صوت للقراءة';

  @override
  String get readAloudConsentTitle => 'هل تريد استخدام محرّك النطق في النظام؟';

  @override
  String get readAloudConsentDetail =>
      'سيُرسل نص الرد المحمّل إلى محرّك النطق في نظامك. تُعرض فقط الأصوات الموسومة بأنها تعمل دون اتصال، لكن المحرّك برنامج مستقل وتسري ممارسات الخصوصية الخاصة به. تُستبعد كتل الشيفرة وتفاصيل الأدوات. قد يسمع الآخرون الصوت. تتوقف القراءة عند فتح شاشة تغطي هذه المحادثة أو انتقال التطبيق إلى الخلفية.';

  @override
  String get readAloudContinue => 'اختيار صوت';

  @override
  String get readAloudUnsupported =>
      'القراءة بصوت عالٍ غير متاحة على هذه المنصة.';

  @override
  String get readAloudNoVoice =>
      'لا يتوفر صوت مثبّت موسوم بأنه يعمل دون اتصال. أعدّ صوتًا يعمل دون اتصال في إعدادات النطق بالنظام وحاول مجددًا.';

  @override
  String get readAloudUnavailable =>
      'تعذّر على محرّك النطق قراءة هذا الرد. حاول مجددًا أو اختر صوتًا آخر.';

  @override
  String get readAloudTooLong =>
      'هذا الرد أطول من أن يُقرأ بصوت عالٍ. اختر ردًا أقصر.';

  @override
  String get readAloudBusy =>
      'لا تتاح القراءة الصوتية أثناء التقاط الصوت أو مقاطعة صوتية أخرى.';

  @override
  String get readAloudNoProse =>
      'لا يوجد نص رد لقراءته. لا تُقرأ الشيفرة ولا تفاصيل الأدوات بصوت عالٍ.';

  @override
  String get credentialManage => 'إدارة الحسابات';

  @override
  String get credentialMetadataOnly =>
      'تُعرض تسميات الحسابات المحفوظة فقط. تبقى مفاتيح API ورموز تسجيل الدخول على خادمك.';

  @override
  String get credentialActiveUnknown =>
      'الحساب النشط غير معروف. لا تبيّن قائمة الحسابات المحفوظة أي حساب نشط.';

  @override
  String get credentialNoneActive => 'أبلغ الخادم عن عدم وجود حساب محفوظ نشط.';

  @override
  String get credentialActiveObserved => 'تعكس شارة «نشط» أحدث حدث من الخادم.';

  @override
  String get credentialActiveUpdated => 'حُدّث الحساب النشط من الخادم.';

  @override
  String get credentialSwitchRequested =>
      'طُلب تبديل الحساب. لم يؤكَّد هذا الطلب بحدث من الخادم بعد.';

  @override
  String get credentialActive => 'نشط';

  @override
  String get credentialSetActive => 'تعيين كنشط';

  @override
  String get credentialRename => 'إعادة تسمية الحساب';

  @override
  String get credentialLabel => 'تسمية الحساب';

  @override
  String get credentialSave => 'حفظ التسمية';

  @override
  String credentialRemoveTitle(String label) {
    return 'هل تريد إزالة $label؟';
  }

  @override
  String get credentialRemoveDetail =>
      'إزالة تسجيل الدخول المحفوظ هذا من الخادم. قد تتأثر المشاريع الأخرى التي تستخدمه. لا يعدّل ذلك إعدادات البيئة؛ يحدّد الخادم الحساب الذي يصبح نشطًا بعد ذلك، إن وُجد.';

  @override
  String get credentialScopeChanged =>
      'تغيّر الخادم أو المشروع. أغلق إدارة الحسابات وافتحها مجددًا قبل إجراء تغييرات.';

  @override
  String get credentialProviderMissing =>
      'لم يعد مزوّد الخدمة هذا في قائمة تكاملات الخادم.';

  @override
  String get credentialLoadFailed =>
      'تعذّر تحديث الحسابات المحفوظة. حاول مجددًا.';

  @override
  String get credentialMutationFailed =>
      'تعذّر تأكيد تغيير الحساب. حدّث قبل إعادة المحاولة؛ فقد يكون الخادم قد طبّقه بالفعل.';

  @override
  String get credentialRefresh => 'تحديث الحسابات';

  @override
  String get credentialEmpty => 'لم يُبلّغ عن حسابات محفوظة لمزوّد الخدمة هذا.';

  @override
  String get credentialEnvironment => 'تديره بيئة الخادم. لا يمكن إزالته هنا.';

  @override
  String credentialUnnamed(int index) {
    return 'حساب محفوظ $index';
  }

  @override
  String get mcpRemove => 'إزالة';

  @override
  String mcpRemoveTitle(String name) {
    return 'هل تريد إزالة $name؟';
  }

  @override
  String get mcpRemoveRuntimeDetail =>
      'إزالة خادم MCP هذا من الموقع الحالي في بيئة التشغيل. لن تتاح أدواته هناك بعد ذلك. لا يمحو ذلك إعدادات الخادم الدائمة؛ وقد يعود بعد إعادة تشغيل الخادم.';

  @override
  String get mcpRemoveFailed =>
      'تعذّر تأكيد إزالة MCP. حدّث القائمة قبل المحاولة مجددًا؛ فقد يكون الخادم قد طبّق التغيير بالفعل.';

  @override
  String get mcpLoadFailed => 'تعذّر تحديث بيانات MCP. حاول مجددًا.';

  @override
  String get mcpSavedStatus => 'محفوظ في OpenCode';

  @override
  String get mcpConnectionUnconfirmed => 'لم يُؤكَّد اتصال التطبيق';

  @override
  String get mcpRetryReconnect => 'إعادة محاولة الاتصال';

  @override
  String get mcpReconnecting => 'جارٍ إعادة الاتصال';

  @override
  String get mcpStillDisconnected => 'لا يزال OpenCode غير متصل. حاول مجددًا.';

  @override
  String get mcpScopeChanged =>
      'تغيّر الخادم أو المشروع. حدّث لتحميل خوادم MCP الخاصة به قبل إجراء تغييرات.';

  @override
  String get promptStashRestoreFailed =>
      'تعذّر إتمام استعادة الطلب. لا تزال النسخ المحفوظة متاحة؛ تحقّق من محرّر الرسالة قبل المحاولة مجددًا.';

  @override
  String get promptStashEmpty =>
      'لا توجد طلبات محفوظة بعد. استخدم «حفظ الطلب الحالي» في أدوات الطلب للاحتفاظ بطلب لاستخدامه لاحقًا.';

  @override
  String get promptStashContextOnly => 'المرفقات والمراجع';

  @override
  String get promptRestoredReferences =>
      'استُعيد الطلب. المراجع المحفوظة لقطات سابقة؛ وقد تكون ملفاتها على الخادم قد تغيّرت.';

  @override
  String get promptDefaultLocation => 'المجلد الافتراضي للخادم';

  @override
  String get promptStashed => 'أُضيف الطلب إلى طلباتك المحفوظة.';

  @override
  String get promptStashedDraftPending =>
      'أُضيف الطلب إلى طلباتك المحفوظة. لا تزال مسودة محرّر الرسالة بحاجة إلى الحفظ؛ اضغط «إعادة المحاولة» في تنبيه المسودة.';

  @override
  String get promptStashReadFailed =>
      'تعذّرت قراءة الطلبات المحفوظة. احتُفظ ببياناتها المخزّنة.';

  @override
  String get promptStashDeleteDetail =>
      'سيُحذف النص المحفوظ ومرفقاته ومراجعه من هذا الجهاز.';

  @override
  String get promptStashDescription =>
      'حفظ النص والمرفقات والمراجع لاستخدامها لاحقًا';

  @override
  String get promptRestoreAvailable => 'استعادة المحتوى المتاح';

  @override
  String get promptRestored => 'استُعيد الطلب. راجعه قبل الإرسال.';

  @override
  String get promptStashAction => 'حفظ الطلب الحالي';

  @override
  String promptStashLocation(String directory) {
    return 'يشير هذا الطلب إلى ملفات في $directory. انتقل إلى مشروعه ومساحة عمله الأصليين قبل استعادته.';
  }

  @override
  String get promptStashScopeChanged =>
      'تغيّر الخادم أو الموقع. أغلق الطلبات المحفوظة وافتحها مجددًا.';

  @override
  String get transcriptFindTitle => 'البحث في المحادثة';

  @override
  String get transcriptFindHint => 'البحث في المحادثة';

  @override
  String get transcriptFindScope => 'الرسائل والاستدلال وبيانات الأدوات';

  @override
  String get transcriptFindClose => 'إغلاق البحث';

  @override
  String get transcriptFindPrevious => 'التطابق السابق';

  @override
  String get transcriptFindNext => 'التطابق التالي';

  @override
  String get transcriptFindNone => 'لا توجد تطابقات';

  @override
  String transcriptFindCount(int current, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'التطابق $current من $total',
      many: 'التطابق $current من $total',
      few: 'التطابق $current من $total',
      two: 'التطابق $current من $total',
      one: 'تطابق واحد',
      zero: 'لا توجد تطابقات',
    );
    return '$_temp0';
  }

  @override
  String transcriptFindTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطابق في نص الرسالة',
      many: '$count تطابقًا في نص الرسالة',
      few: '$count تطابقات في نص الرسالة',
      two: 'تطابقان في نص الرسالة',
      one: 'تطابق واحد في نص الرسالة',
      zero: 'لا توجد تطابقات في نص الرسالة',
    );
    return '$_temp0';
  }

  @override
  String get transcriptFindPartial =>
      'الرسائل المحمّلة فقط. حمّل الرسائل الأقدم لتوسيع البحث.';

  @override
  String get transcriptFindComplete => 'بُحث في كل محتوى الرسائل المتاح.';

  @override
  String get transcriptFindReasoning => 'الاستدلال';

  @override
  String get transcriptFindTool => 'بيانات الأدوات';

  @override
  String get transcriptFindFile => 'اسم الملف';

  @override
  String get transcriptFindAll => 'البحث في السجل كاملًا';

  @override
  String get skillMenu => 'استخدام مهارة';

  @override
  String get skillUse => 'إضافة إلى المحادثة';

  @override
  String get skillActivationHelp =>
      'تُضاف تعليمات هذه المهارة إلى المحادثة. تبقى مسودتك غير المرسلة في محرّر الرسالة.';

  @override
  String get skillRunNow => 'تشغيل الوكيل الآن';

  @override
  String get skillRunHelp => 'عطّل هذا الخيار لإضافة المهارة دون بدء رد آخر.';

  @override
  String get skillLocationChanged =>
      'تغيّر الاتصال أو المشروع. افتح المهارات مجددًا من المحادثة.';

  @override
  String get skillUnsupported =>
      'تفعيل المهارات غير متاح على هذا الخادم. لا يزال بإمكانك معاينتها.';

  @override
  String get skillStaged => 'احسم التراجع المبدئي في المحادثة قبل إضافة مهارة.';

  @override
  String get skillBusy => 'جارٍ إضافة مهارة إلى هذه المحادثة بالفعل.';

  @override
  String get skillUncertain =>
      'لم يؤكّد الخادم النتيجة. قد تكون المهارة قد أُضيفت. أغلق هذه اللوحة وتحقّق من المحادثة قبل المحاولة مجددًا.';

  @override
  String get skillApplied => 'أُضيفت المهارة إلى هذه المحادثة.';

  @override
  String get skillAppliedOriginal =>
      'أُضيفت المهارة إلى المحادثة الأصلية. أغلق هذه اللوحة للعودة.';

  @override
  String get activeContextTitle => 'السياق النشط';

  @override
  String get activeContextSubtitle => 'فحص الرسائل بعد اختصار السياق';

  @override
  String get activeContextHelp =>
      'الرسائل النشطة التي أعادها الخادم بعد آخر اختصار للسياق. أعداد الرسائل ليست أعداد الرموز.';

  @override
  String get activeContextRefresh => 'تحديث السياق النشط';

  @override
  String get activeContextSearch => 'البحث في الرسائل النشطة';

  @override
  String get activeContextAll => 'الكل';

  @override
  String activeContextCount(int shown, int total) {
    return 'الرسائل: $shown من $total';
  }

  @override
  String get activeContextEmpty => 'لم يُعد الخادم أي رسائل سياق نشط.';

  @override
  String get activeContextNoMatches =>
      'لا توجد رسائل نشطة تطابق هذه المرشّحات.';

  @override
  String get activeContextNoText => 'لا يوجد محتوى نصي مدعوم في هذا العنصر.';

  @override
  String get activeContextUnsupported =>
      'فحص السياق النشط غير متاح على هذا الخادم.';

  @override
  String get activeContextChanged =>
      'تغيّر الاتصال أو المشروع أو المحادثة. افتح أداة الفحص هذه مجددًا من المحادثة.';

  @override
  String get activeContextInvalid =>
      'أعاد الخادم لقطة سياق غير صالحة. حدّث لإعادة المحاولة.';

  @override
  String activeContextRefreshFailed(String error) {
    return 'تُعرض اللقطة السابقة. تعذّر التحديث: $error';
  }

  @override
  String get activeContextContentHelp =>
      'لقطة لمحتوى الرسائل المتاح. لا تُعرض محتويات المرفقات الثنائية أو الروابط أو البيانات الوصفية الداخلية. لا يمثّل ذلك الطلب الكامل المرسل إلى مزوّد الخدمة.';

  @override
  String get activeContextUser => 'طلب المستخدم';

  @override
  String get activeContextAssistant => 'المساعد';

  @override
  String get activeContextSystem => 'تعليمات النظام';

  @override
  String get activeContextSynthetic => 'رسالة مُنشأة آليًا';

  @override
  String get activeContextSkill => 'مهارة';

  @override
  String get activeContextShell => 'الصدفة';

  @override
  String get activeContextCompaction => 'اختصار السياق';

  @override
  String get activeContextChange => 'تغيير الجلسة';

  @override
  String get activeContextText => 'نص';

  @override
  String get activeContextToolInput => 'مدخلات الأداة';

  @override
  String get activeContextToolOutput => 'مخرجات الأداة';

  @override
  String get activeContextFile => 'ملف مرفق';

  @override
  String get activeContextNotice => 'إشعار من الخادم';

  @override
  String get activeContextPruned => 'حذف الخادم المحتوى';

  @override
  String get activeContextTruncated => 'اقتطع الخادم المخرجات';

  @override
  String get draftSaveFailed => 'لم تُحفظ المسودة. انسخ نصك أو أعد المحاولة.';

  @override
  String get draftStorageFull =>
      'مساحة تخزين المسودات ممتلئة. انسخ نصك قبل المغادرة.';

  @override
  String get draftProfileRemoved =>
      'أُزيل الخادم الأصلي. انسخ مسودتك للاحتفاظ بها.';

  @override
  String get draftRetrySave => 'إعادة حفظ المسودة';

  @override
  String get draftClearFailed =>
      'تعذّر مسح المسودة المحفوظة. أعد المحاولة قبل المغادرة.';

  @override
  String activeContextTypeCount(String type, int count) {
    return '$type · $count';
  }

  @override
  String activeContextPartHeading(String kind, String name) {
    return '$kind · $name';
  }

  @override
  String get draftLeaveTitle => 'تعذّر حفظ المسودة';

  @override
  String get draftLeaveMessage =>
      'تابع التحرير لنسخ نصك أو إعادة محاولة الحفظ. قد تؤدي المغادرة الآن إلى فقدان تغييراتك غير المحفوظة.';

  @override
  String get draftLeaveAction => 'مغادرة دون حفظ';

  @override
  String get draftKeepEditing => 'متابعة التحرير';

  @override
  String get draftUnsaved => 'غير محفوظة';

  @override
  String get draftAttachmentsLocal =>
      'تُحفظ المرفقات مع هذه المسودة على هذا الجهاز.';

  @override
  String get draftAttachmentsFailed =>
      'تحتاج المرفقات إلى استرداد أو تعذّر حفظها. أعد المحاولة قبل الإرسال.';

  @override
  String get draftAttachmentRecoveryTitle => 'بعض المرفقات بحاجة إلى مراجعة';

  @override
  String draftAttachmentRecoveryDetail(String names) {
    return 'هذه المرفقات المحفوظة مفقودة أو غير قابلة للقراءة أو تتبع مشروعًا آخر: $names. استخدم المرفقات المتاحة وأزل هذه من المسودة، أو احتفظ بالمسودة المحفوظة وحاول مجددًا لاحقًا.';
  }

  @override
  String get draftUseAvailableAttachments => 'استخدام المرفقات المتاحة';

  @override
  String get draftKeepSavedAttachments => 'الاحتفاظ بالمسودة المحفوظة';

  @override
  String get photoLibraryAction => 'مكتبة الصور';

  @override
  String get photoLibraryDescription => 'اختيار صورة أو لقطة شاشة';

  @override
  String get photoCameraAction => 'التقاط صورة';

  @override
  String get photoTooLarge => 'اختر صورة أصغر من 10 MB.';

  @override
  String get photoStorageFailed =>
      'تعذّر حفظ الصورة على هذا الجهاز. وفّر بعض المساحة وأعد المحاولة.';

  @override
  String get photoPendingOther =>
      'توجد صورة منتظرة في محادثتها الأصلية. احتفظ بها هناك أو تجاهلها قبل اختيار صورة أخرى.';

  @override
  String get photoUnavailable =>
      'تعذّر فتح الصورة. حاول إضافتها مجددًا من مكتبة الصور أو عبر التقاط صورة.';

  @override
  String get photoPermissionDenied =>
      'رُفض الوصول إلى الصور. اسمح بالوصول إلى الكاميرا أو الصور في إعدادات تطبيق Android، ثم حاول مجددًا.';

  @override
  String get photoPendingTitle => 'صورة منتظرة';

  @override
  String get photoDiscard => 'تجاهل الصورة المنتظرة';

  @override
  String get photoAddToDraft => 'إضافة الصورة المستردّة إلى المسودة';

  @override
  String get photoOtherLocation =>
      'ارجع إلى الخادم والمشروع الأصليين للصورة قبل إضافتها.';

  @override
  String get photoDraftFull =>
      'أزل مرفقًا أولًا. تتسع المسودة لما يصل إلى 5 ملفات بإجمالي 20 MB.';

  @override
  String get legacyDraftsTitle => 'المسودات القديمة';

  @override
  String get legacyDraftsDescription =>
      'مراجعة المسودات المحفوظة قبل تتبّع الخادم';

  @override
  String get legacyDraftsExplanation =>
      'لا يوجد خادم مسجّل لهذه المسودات. راجع نصوصها قبل استخدامها في هذه المحادثة.';

  @override
  String get legacyDraftInsertExplanation =>
      'يضيف الإدراج هذا النص بعد مسودتك الحالية. تبقى النسخة المحفوظة الأصلية هنا حتى تحذفها.';

  @override
  String get legacyDraftTextOnly =>
      'يمكن إدراج النص فقط هنا. تبقى أي مرفقات محفوظة مع المسودة القديمة.';

  @override
  String get legacyDraftDelete => 'حذف النسخة المحفوظة';

  @override
  String get legacyDraftDeleteExplanation =>
      'هل تريد حذف هذه المسودة القديمة ومرفقاتها المحفوظة نهائيًا من هذا الجهاز؟';

  @override
  String get legacyDraftDeleteFailed =>
      'تغيّرت المسودة أو تعذّرت إزالتها. افتحها مجددًا وأعد المحاولة.';

  @override
  String get legacyDraftInsert => 'إدراج في المسودة';

  @override
  String get legacyDraftSearch => 'البحث في المسودات القديمة';

  @override
  String get legacyDraftsEmpty => 'لم يُعثر على مسودات قديمة';

  @override
  String get legacyDraftLocationChanged =>
      'تغيّر المشروع. افتح المسودات القديمة مجددًا لاختيار وجهة إدراج النص.';

  @override
  String get quotaTitle => 'رصيد الاستخدام المتبقي';

  @override
  String get quotaSettingsSummary =>
      'جامع بيانات Codex اختياري · يتطلب إعدادًا';

  @override
  String get quotaDescription =>
      'اختر مزوّد خدمة لعرض فترات استخدام الحساب التي يُبلّغ عنها. وهي منفصلة عن استخدام الرموز والتكلفة في OpenCode.';

  @override
  String get quotaSource => 'خادم جمع البيانات';

  @override
  String quotaSourceTitle(String profile, String provider) {
    return '$profile · $provider';
  }

  @override
  String get quotaUnknownSource => 'لا يوجد خادم محفوظ';

  @override
  String get quotaSourceChanged =>
      'تغيّر الخادم أو المشروع، أو تجري إزالة بياناته المحلية. افتح رصيد الاستخدام المتبقي مجددًا لمراجعة المصدر.';

  @override
  String get quotaSetupTitle => 'يلزم جامع بيانات اختياري';

  @override
  String get quotaSetupDescription =>
      'يجب على مسؤول الخادم تثبيت هذا المسار وحمايته على عنوان أصل OpenCode نفسه. تستخدم قراءته بيانات دخول الخادم لهذا الملف الشخصي. أكّد فقط إذا ثبّتّ هذه الخدمة أو كنت تثق بها. تبقى رموز مزوّد الخدمة على الخادم.';

  @override
  String get quotaSetupGuide =>
      'تعليمات الإعداد في tool/quota/README.md داخل مستودع التطبيق. لا تثبّت هذه الشاشة أي خدمات، ولا تحتفظ بالإذن بعد مغادرتها.';

  @override
  String get quotaSetupNeeded =>
      'استخدم خادمًا محفوظًا بكلمة مرور وHTTPS، أو عنوان الاسترجاع المحلي للهاتف. حدّث إعدادات اتصاله قبل فحص جامع البيانات.';

  @override
  String get quotaConsent => 'ثبّتُّ جامع البيانات هذا على هذا الخادم وأثق به.';

  @override
  String get quotaRead => 'قراءة الاستخدام المتبقي';

  @override
  String get quotaRefresh => 'تحديث الاستخدام المتبقي';

  @override
  String get quotaLoading => 'جارٍ قراءة الاستخدام المتبقي';

  @override
  String get quotaForgetConsent => 'التوقف عن استخدام جامع البيانات';

  @override
  String get quotaCollectorAuth =>
      'لم يقبل مسار جامع البيانات بيانات دخول هذا الخادم. اطلب من مسؤول الخادم التحقق من إعدادات المصادقة.';

  @override
  String get quotaCollectorMissing =>
      'مسار جامع البيانات الاختياري غير متاح على هذا الخادم. تحقّق من تثبيته وتوجيه الوكيل.';

  @override
  String get quotaUnavailable =>
      'تعذّر تحديث الاستخدام المتبقي. تحقّق من الاتصال وجامع البيانات، ثم أعد المحاولة.';

  @override
  String get quotaInvalidResponse =>
      'أعاد جامع البيانات قراءة غير صالحة أو غير مدعومة. لا يُعرض رصيد استخدام جديد.';

  @override
  String get quotaUnconfigured =>
      'لم يُضبط مصدر حساب مصرّح به لجامع البيانات. اطلب من مسؤوله إكمال الإعداد.';

  @override
  String get quotaProviderUnsupported =>
      'لا يدعم جامع البيانات هذا تسجيل دخول OAuth المحدد أو مسار استخدام مزوّد الخدمة.';

  @override
  String get quotaProviderAuth =>
      'سجّل الدخول مجددًا بأداة تسجيل الدخول الحالية لمزوّد الخدمة على الخادم. لا يقرأ هذا التطبيق بيانات ذلك الدخول ولا يجدّدها.';

  @override
  String get quotaRateLimited =>
      'قيّد مزوّد الخدمة فحوص الحصة. انتظر قبل التحديث؛ فهذا لا يؤكد نفاد رصيد البرمجة لديك.';

  @override
  String get quotaAccountUnverified =>
      'لم يتمكن جامع البيانات من التحقق من الحساب المحدد. لا يُعرض رصيد استخدام. تحقّق من مصدر تسجيل الدخول على الخادم.';

  @override
  String get quotaCodexAccount => 'فترات حساب Codex';

  @override
  String quotaPlan(String plan) {
    return 'الخطة المبلّغ عنها: $plan';
  }

  @override
  String quotaChecked(String time) {
    return 'تم التحقق من القراءة $time';
  }

  @override
  String get quotaStale => 'قراءة سابقة — حدّث للتحقق من أحدث رصيد استخدام.';

  @override
  String get quotaUseBlocked =>
      'يفيد مزوّد الخدمة بأن استخدام Codex المعتاد محظور حاليًا. نسب الفترات وحدها لا تحدد إمكانية الاستخدام.';

  @override
  String get quotaNotReported => 'غير مبلّغ عنه';

  @override
  String get quotaPrimaryWindow => 'الفترة الأساسية';

  @override
  String get quotaSecondaryWindow => 'الفترة الثانوية';

  @override
  String quotaOtherWindow(int number) {
    return 'فترة الاستخدام $number';
  }

  @override
  String quotaRemaining(String percent) {
    return 'المتبقي $percent';
  }

  @override
  String quotaWindowRemainingLabel(String window) {
    return '$window: النسبة المتبقية';
  }

  @override
  String quotaUsed(String percent) {
    return 'المستخدم $percent';
  }

  @override
  String quotaResetAt(String time) {
    return 'موعد التجديد المبلّغ عنه: $time';
  }

  @override
  String get quotaResetUnknown => 'لم يُبلّغ عن موعد التجديد';

  @override
  String get quotaResetPassed =>
      'مرّ موعد التجديد — حدّث للتحقق. لم يُجدَّد الرصيد المعروض محليًا.';

  @override
  String quotaDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فترة مدتها $count يوم',
      many: 'فترة مدتها $count يومًا',
      few: 'فترة مدتها $count أيام',
      two: 'فترة مدتها يومان',
      one: 'فترة مدتها يوم واحد',
      zero: 'فترة مدتها $count يوم',
    );
    return '$_temp0';
  }

  @override
  String quotaHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فترة مدتها $count ساعة',
      many: 'فترة مدتها $count ساعة',
      few: 'فترة مدتها $count ساعات',
      two: 'فترة مدتها ساعتان',
      one: 'فترة مدتها ساعة واحدة',
      zero: 'فترة مدتها $count ساعة',
    );
    return '$_temp0';
  }

  @override
  String quotaSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فترة مدتها $count ثانية',
      many: 'فترة مدتها $count ثانية',
      few: 'فترة مدتها $count ثوانٍ',
      two: 'فترة مدتها ثانيتان',
      one: 'فترة مدتها ثانية واحدة',
      zero: 'فترة مدتها $count ثانية',
    );
    return '$_temp0';
  }

  @override
  String get quotaSourceDisclosure =>
      'قراءة فقط من جامع البيانات الاختياري عبر نقطة نهاية داخلية لمزوّد الخدمة. لا تشمل أرصدة المنتجات الأخرى أو حدود النماذج أو الاعتمادات أو أهلية الاستخدام. البيانات المفقودة مجهولة، وليست بلا حدود.';

  @override
  String get quotaCodex => 'Codex';

  @override
  String get quotaClaude => 'Claude';

  @override
  String get quotaClaudeUnavailable =>
      'استخدام اشتراك Claude غير متاح هنا إلى حين توفر تكامل مدعوم ومسموح به. لا يتضمن OpenCode الحالي تسجيل دخول Claude Pro/Max. لن يقرأ التطبيق بيانات دخول هذا الاشتراك أو يعيد استخدامها.';

  @override
  String get iosAppTitle => 'OpenCode لنظام iOS';

  @override
  String get iosRemoteSummary =>
      'عميل اتصال بخادم OpenCode الذي تختاره. استضافة الخادم على الجهاز والمراقبة في الخلفية غير متاحتين في إصدار iOS هذا.';

  @override
  String get iosKeychainGuide =>
      'تُحفظ كلمات مرور الخوادم في Keychain على هذا الجهاز، ولا تُخزَّن في تفضيلات الملفات الشخصية العادية.';

  @override
  String get platformSecureStorageGuide =>
      'تُحفظ كلمات مرور الخوادم في مخزن بيانات الاعتماد الآمن لهذه المنصة، ولا تُخزَّن في تفضيلات الملفات الشخصية العادية.';

  @override
  String get quotaClaudeAccount => 'فترات تسجيل دخول Claude';

  @override
  String get quotaSourceBound =>
      'مرتبط بتسجيل دخول Claude المضبوط في جامع البيانات. استجابة الاستخدام لا تحدد الحساب بشكل مستقل.';

  @override
  String get usageProviders => 'مزوّدو الخدمة';

  @override
  String get usageProviderScope =>
      'إجماليات سجلات النماذج التي أعادها هذا الخادم للنطاق المحدد. لا تمثل فوترة مزوّد الخدمة أو أرصدة الاشتراكات.';

  @override
  String usageProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نموذج',
      many: '$count نموذجًا',
      few: '$count نماذج',
      two: 'نموذجان',
      one: 'نموذج واحد',
      zero: 'لا نماذج',
    );
    return '$_temp0';
  }

  @override
  String get usageProviderCostUnavailable => 'الإجمالي الفرعي للتكلفة غير متاح';

  @override
  String usageProviderCostShare(String percent) {
    return '$percent من التكلفة المبلّغ عنها';
  }

  @override
  String get setupOutputWaiting => 'بانتظار مخرجات Termux…';

  @override
  String get setupOutputWaitingDetail =>
      'ستظهر رسائل الإعداد هنا عند استجابة Termux.';

  @override
  String get setupStartInstalled => 'تشغيل OpenCode المثبّت';

  @override
  String get setupMissingCredential =>
      'لا يملك التطبيق بيانات اعتماد محفوظة لهذا التثبيت. اتصل بعنوان خادمه، أو شغّل الإعداد لضبطه.';

  @override
  String get setupUbuntuOption => 'تثبيت Ubuntu يديره التطبيق';

  @override
  String get setupOwnOption => 'استخدام إعدادك الخاص';

  @override
  String get setupOwnDescription =>
      'اتصل بخادم OpenCode 1 أو OpenCode 2 موجود باستخدام عنوانه. يحتاج تثبيت musl الأصلي إلى بيئة Linux متوافقة، ولا يديره هذا التطبيق.';

  @override
  String get setupConnectExisting => 'الاتصال بخادم موجود';

  @override
  String get setupScreenTitle => 'الإعداد على الجهاز';

  @override
  String get setupInstallStart => 'تثبيت وتشغيل';

  @override
  String get setupCheckAgain => 'التحقق مجددًا';

  @override
  String uncertainAuthTitle(String integrationID) {
    return 'تسجيل دخول غير مؤكّد: $integrationID';
  }

  @override
  String get uncertainAuthDetail =>
      'ربما بدأ الخادم تسجيل الدخول، لكن لم يصل معرّف المحاولة. تحقّق على الخادم قبل البدء مجددًا.';

  @override
  String get uncertainAuthForgetTitle => 'نسيان محاولة البدء غير المؤكدة؟';

  @override
  String get uncertainAuthForgetDetail =>
      'يمحو هذا منع إعادة المحاولة المحلي فقط، ولا يلغي تسجيل الدخول على الخادم. تحقّق من الخادم أولًا لتجنب بدء تسجيل دخول ثانٍ. لن يبدأ تسجيل دخول جديد.';

  @override
  String get uncertainAuthForget => 'نسيان محاولة البدء غير المؤكدة';

  @override
  String get uncertainAuthCloseHint =>
      'أغلق هذه اللوحة واستخدم صف تسجيل الدخول غير المؤكد لإزالة منع إعادة المحاولة المحلي بعد التحقق من الخادم.';

  @override
  String get pluginsTitle => 'الإضافات';

  @override
  String get pluginsDescription =>
      'الإضافات التي أُبلغ عنها لهذا الموقع على الخادم. افحص الحالة والمصدر هنا؛ وأدِر الإضافات على الخادم.';

  @override
  String get pluginsUnsupported => 'لا يدعم هذا الخادم فحص الإضافات.';

  @override
  String get pluginsDisconnected => 'اتصل بخادم لفحص إضافاته.';

  @override
  String get pluginsEmpty => 'لم يُبلّغ عن إضافات لهذا الموقع.';

  @override
  String get pluginsLoadFailed => 'تعذّر تحميل الإضافات. أعد المحاولة.';

  @override
  String get pluginsRefresh => 'تحديث الإضافات';

  @override
  String get pluginsRetry => 'إعادة المحاولة';

  @override
  String get pluginsUnnamed => 'إضافة بلا معرّف';

  @override
  String get pluginsStatusActive => 'نشطة';

  @override
  String get pluginsStatusFailed => 'فشلت';

  @override
  String get pluginsStatusUnknown => 'حالة غير معروفة';

  @override
  String get pluginsSourceBuiltin => 'مدمجة';

  @override
  String get pluginsSourcePackage => 'حزمة';

  @override
  String get pluginsSourceLocal => 'ملف محلي (المسار مخفي)';

  @override
  String get pluginsSourceSdk => 'SDK';

  @override
  String get pluginsSourceUnknown => 'مصدر غير معروف';

  @override
  String get pluginsTerminalUi => 'تعلن عن واجهة طرفية';

  @override
  String get pluginsFailureDetail =>
      'تفاصيل الفشل مخفية لأنها قد تتضمن بيانات اعتماد.';

  @override
  String get demoReviewChanges => 'مراجعة التغييرات';

  @override
  String get demoSetUpServer => 'إعداد خادمك الخاص';

  @override
  String get handoffCommandTitle => 'المتابعة على الكمبيوتر';

  @override
  String get handoffCommandDisclosure =>
      'شغّل هذا الأمر في طرفية متوافقة مع POSIX على كمبيوتر مثبّت عليه OpenCode ويمكنه الوصول إلى هذا الخادم. اضبط OPENCODE_SERVER_PASSWORD بشكل خاص على ذلك الكمبيوتر إذا تطلّبه الخادم. ستتضمن الحافظة عنوان الخادم واسم المستخدم ومجلد المشروع ومعرّف الجلسة، دون كلمة المرور.';

  @override
  String get handoffCopyCommand => 'نسخ الأمر';

  @override
  String get handoffCommandCopied => 'تم نسخ أمر الاستئناف';

  @override
  String get handoffCommandUnavailable =>
      'أمر الاستئناف غير متاح لهذا الاتصال أو مساحة العمل. تحتاج المتابعة على كمبيوتر آخر إلى أمر OpenCode مدعوم وخادم HTTPS يمكن الوصول إليه؛ يشير عنوان localhost إلى الجهاز نفسه على كل جهاز. لا يزال بإمكانك نسخ بيانات الجلسة الوصفية أدناه.';

  @override
  String get quotaMiniMax => 'MiniMax';

  @override
  String get quotaMiniMaxAccount => 'فترات اشتراك MiniMax';

  @override
  String get quotaMiniMaxSourceBound =>
      'مرتبط بمفتاح MiniMax Subscription Key المضبوط في جامع البيانات. استجابة الحصة لا تحدد الحساب بشكل مستقل. تُعرض فقط نسب الرصيد العام المبلّغ عنها؛ وقد تنطبق حدود أخرى.';

  @override
  String get managedHealthTitle => 'الخادم على الجهاز';

  @override
  String get managedHealthUnchecked =>
      'افحص الخادم الذي يديره هذا التطبيق في Termux.';

  @override
  String get managedHealthCheck => 'التحقق من الحالة';

  @override
  String get managedHealthChecking => 'جارٍ فحص Termux…';

  @override
  String get managedHealthFailed =>
      'تعذّر فحص Termux. افتح الإعداد للتحقق من الأذونات أو أعد المحاولة.';

  @override
  String get managedHealthReady => 'عملية الخادم قيد التشغيل';

  @override
  String get managedHealthWorking => 'الإعداد جارٍ';

  @override
  String get managedHealthStopped => 'الخادم متوقف';

  @override
  String get managedHealthNeedsSetup => 'الإعداد يحتاج إلى انتباه';

  @override
  String get managedHealthAbsent => 'لم يُعثر على إعداد يديره التطبيق';

  @override
  String get managedHealthUnknown => 'حالة الخادم غير متاحة';

  @override
  String get managedHealthManage => 'فتح أدوات الإعداد';

  @override
  String managedHealthObserved(String time) {
    return 'آخر تحقق في $time. تحقّق مجددًا لمعرفة الحالة الحالية.';
  }

  @override
  String managedHealthVersion(String version) {
    return 'OpenCode $version';
  }

  @override
  String get managedHealthUbuntu => 'بيئة التشغيل: Ubuntu';

  @override
  String get managedHealthLifetime =>
      'قد يوقف Android أيًا من التطبيقين. إبقاء اتصال تطبيق الهاتف نشطًا لا يضمن استمرار خادم Termux طوال الليل.';

  @override
  String get quotaBudgetTitle => 'حد التنبيه الشخصي';

  @override
  String get quotaBudgetDescription =>
      'اختر نسبة استخدام لهذا المصدر والحساب والفترة. لا يغيّر هذا حدود مزوّد الخدمة.';

  @override
  String get quotaBudgetOff => 'متوقف';

  @override
  String quotaBudgetPercent(String percent) {
    return 'تم استخدام $percent%';
  }

  @override
  String get quotaBudgetOptIn => 'إظهار تنبيه بلوغ الحد';

  @override
  String get quotaBudgetAttentionScope =>
      'بعد قراءة حديثة في هذه الصفحة فقط. لا فحص في الخلفية ولا إشعارات للجهاز. تنبّه الفترة التي لا تملك موعد تجديد مرة واحدة حتى تغيّر هذه القاعدة.';

  @override
  String get quotaBudgetSaveFailed =>
      'تعذّر حفظ تغيير الميزانية. تظل آخر إعدادات محفوظة سارية.';

  @override
  String get quotaBudgetAttention =>
      'بُلغ حد شخصي في أحدث قراءة من مزوّد الخدمة. راجع الفترات المبلّغ عنها أدناه.';

  @override
  String get quotaGlm => 'GLM';

  @override
  String get quotaGlmAccount => 'مصدر GLM Coding Plan المضبوط';

  @override
  String get quotaGlmTokenWindow => 'فترة خطة الرموز المبلّغ عنها';

  @override
  String get quotaGlmMcpWindow => 'فترة MCP المبلّغ عنها';

  @override
  String get usageBudgetTitle => 'ميزانيات الاستهلاك الشخصية';

  @override
  String get usageBudgetDescription =>
      'تستخدم الميزانيات كل الاستهلاك المبلّغ عنه للخادم والمشروع والمنطقة الزمنية وبداية الفترة المحددة. لا تغيّرها مرشحات النماذج. تحتاج بداية فترة جديدة إلى ميزانية جديدة. لا تغيّر هذه الميزانيات أرصدة الاشتراك ولا توقف الطلبات.';

  @override
  String get usageBudgetUsd => 'تحديد ميزانية بالدولار الأمريكي';

  @override
  String get usageBudgetTokens => 'تحديد ميزانية الرموز';

  @override
  String get usageBudgetAmount => 'قيمة الميزانية';

  @override
  String get usageBudgetInvalid =>
      'أدخل قيمة موجبة ومحدودة. يجب أن تكون ميزانيات الرموز أعدادًا صحيحة.';

  @override
  String get usageBudgetRemove => 'إزالة الميزانية';

  @override
  String usageBudgetProgress(String used, String limit, String unit) {
    return '$used من $limit $unit';
  }

  @override
  String get usageBudgetTokenUnit => 'رمز';

  @override
  String get usageBudgetReached => 'بُلغت الميزانية الشخصية في هذه القراءة.';

  @override
  String get usageBudgetPrevious =>
      'بلغت القراءة السابقة هذه الميزانية. حدّث للتحقق من الاستهلاك الحالي.';

  @override
  String get usageBudgetClearAll => 'مسح ميزانيات الاستهلاك المحفوظة';

  @override
  String get usageBudgetClearDescription =>
      'هل تريد إزالة جميع ميزانيات الاستهلاك الحالية والسابقة لهذا الخادم المحفوظ؟ ستبقى حدود مزوّدي الخدمة.';

  @override
  String get monitorTitle => 'ما يحتاج إلى انتباه في الخوادم المحفوظة';

  @override
  String get monitorScope =>
      'تشمل الأعداد آخر موقع محدد لكل خادم، وليس جميع مشاريعه.';

  @override
  String get monitorDisclosure =>
      'المراقبة متوقفة حتى تفعّلها لخادم. تُجرى الفحوص كل دقيقة تقريبًا أثناء فتح التطبيق. لا تتكرر الفحوص في الخلفية أكثر من مرة كل خمس دقائق، وفقط عندما يكون «إبقاء الاتصال نشطًا» مفعّلًا وخدمة Android قيد التشغيل. قد يوقف Android هذه الخدمة؛ ولا توجد مدة تشغيل متبقية مضمونة.';

  @override
  String get monitorConfigure => 'إعدادات المراقبة';

  @override
  String get monitorRefresh => 'فحص الخوادم الخاضعة للمراقبة';

  @override
  String get monitorOptIn => 'مراقبة هذا الخادم';

  @override
  String get monitorOptInDetail =>
      'فحص الأذونات والأسئلة والنماذج المعلّقة في آخر موقع محدد له.';

  @override
  String get monitorNotifications => 'الإشعار عند الحاجة إلى انتباه';

  @override
  String get monitorWifi => 'Wi-Fi فقط';

  @override
  String get monitorWifiDetail =>
      'تتوقف الفحوص مؤقتًا ما لم يرصد Android شبكة Wi-Fi نشطة. قد تؤدي شبكة VPN أو عدم توفر معلومات الشبكة إلى إيقاف الفحوص مؤقتًا.';

  @override
  String get monitorWifiUnsupported => 'اكتشاف Wi-Fi غير متاح على هذه المنصة.';

  @override
  String get monitorQuiet => 'ساعات الهدوء';

  @override
  String get monitorQuietDetail =>
      'كتم تنبيهات الانتباه خلال هذه الأوقات المحلية. تستمر الفحوص.';

  @override
  String get monitorQuietStart => 'بداية ساعات الهدوء';

  @override
  String get monitorQuietEnd => 'نهاية ساعات الهدوء';

  @override
  String get monitorDisabled =>
      'غير خاضع للمراقبة · الحاجة إلى انتباه غير معروفة';

  @override
  String get monitorWaiting => 'بانتظار فحص · الحاجة إلى انتباه غير معروفة';

  @override
  String get monitorChecking => 'جارٍ الفحص · الحاجة إلى انتباه غير معروفة';

  @override
  String get monitorUnavailable => 'تعذّر الفحص · الحاجة إلى انتباه غير معروفة';

  @override
  String get monitorWifiRequired =>
      'بانتظار Wi-Fi · الحاجة إلى انتباه غير معروفة';

  @override
  String get monitorPaused =>
      'متوقف مؤقتًا في الخلفية · الحاجة إلى انتباه غير معروفة';

  @override
  String get monitorCurrent => 'الرصد الحالي';

  @override
  String get monitorAllClear => 'لا طلبات معلّقة في الموقع المفحوص';

  @override
  String get monitorNoServers => 'أضف خادمًا لمراقبة ما يحتاج إلى انتباه.';

  @override
  String get monitorSaveFailed => 'تعذّر حفظ إعدادات المراقبة. أعد المحاولة.';

  @override
  String get monitorOpenFailed =>
      'تغيّر هذا الطلب أو موقعه على الخادم. حدّث صندوق الوارد وأعد المحاولة.';

  @override
  String get monitorSwitchTitle => 'تبديل الخادم للمراجعة؟';

  @override
  String get monitorSwitchDetail =>
      'توجد عملية نشطة على الخادم المحدد. يغيّر التبديل الاتصال المعروض في هذا التطبيق، ولا يوقف عملية ذلك الخادم.';

  @override
  String get monitorSwitch => 'تبديل الخادم';

  @override
  String get monitorSession => 'جلسة';

  @override
  String get monitorPermission => 'يلزم إذن';

  @override
  String get monitorQuestion => 'تلزم إجابة';

  @override
  String get monitorForm => 'تلزم تعبئة النموذج';

  @override
  String get monitorUnknown => 'غير معروف';

  @override
  String get monitorLastChecked => 'آخر تحقق';

  @override
  String get monitorNextCheck => 'التحقق التالي';

  @override
  String get monitorPending => 'الطلبات المعلّقة الحالية';

  @override
  String get monitorUnknownServers => 'خوادم لا تُعرف حاجتها إلى انتباه';

  @override
  String monitorPendingSummary(int pendingCount, int unknownCount) {
    return 'الطلبات المعلّقة الحالية: $pendingCount\nخوادم لا تُعرف حاجتها إلى انتباه: $unknownCount';
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
  String get monitorSelected => 'الموقع المحدد';

  @override
  String get monitorNoNotifications =>
      'تتطلب إشعارات الخلفية أيضًا تفعيل «إبقاء الاتصال نشطًا» وإذن الإشعارات في إعدادات الخلفية.';

  @override
  String get monitorCheckIn => 'متابعة العمليات الطويلة';

  @override
  String get monitorCheckInDetail =>
      'يظهر تذكير عندما تمتد الفحوص التي ترصد انشغالًا للمدة المختارة. قد يتوقف العمل أو يُعاد تشغيله بين الفحوص. تُجرى محاولة إشعار واحدة كحد أقصى لكل فترة مرصودة، أثناء تفعيل «إبقاء الاتصال نشطًا».';

  @override
  String get monitorCheckInDetailForeground =>
      'يظهر صف تذكير عندما تمتد الفحوص التي ترصد انشغالًا للمدة المختارة. قد يتوقف العمل أو يُعاد تشغيله بين الفحوص. لا يستطيع هذا الجهاز إرسال تذكيرات في الخلفية.';

  @override
  String get monitorCheckInAfter => 'التذكير بالمتابعة بعد';

  @override
  String monitorMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
      zero: '$minutes دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get monitorCheckInDue => 'حان وقت المتابعة';

  @override
  String monitorObservedBusy(int minutes, String since) {
    return 'رُصد انشغال في فحوص امتدت $minutes دقيقة · أول فحص $since';
  }

  @override
  String get quotaBudgetClearAll => 'مسح حدود مزوّدي الخدمة المحفوظة';

  @override
  String get quotaBudgetClearDescription =>
      'هل تريد إزالة جميع حدود مزوّدي الخدمة وإعدادات الانتباه لهذا الخادم المحفوظ، بما فيها الحسابات السابقة؟ ستبقى ميزانيات الاستهلاك.';

  @override
  String managedStorageSummary(String available, String total) {
    return 'مساحة Termux: متاح $available GiB من $total GiB';
  }

  @override
  String get managedStorageFailed =>
      'تعذّر فحص مساحة Termux. أعد محاولة التحقق من الحالة.';

  @override
  String get managedRecoveryTitle => 'استعادة خادم يديره التطبيق بعد تعطّله';

  @override
  String get managedRecoveryPolicy =>
      'اسمح بثلاث محاولات إعادة تشغيل كحد أقصى، بفواصل لا تقل عن 5 و15 و45 ثانية. فقط أثناء وجود التطبيق في المقدمة. دون تثبيت أو تحديث.';

  @override
  String managedRecoveryAttempts(int attempts) {
    return 'المحاولات المستخدمة: $attempts من 3. يبقى الحد محفوظًا بعد إعادة تشغيل التطبيق.';
  }

  @override
  String get managedRecoveryExhausted =>
      'بُلغ حد الاستعادة. افحص الخادم وشغّله يدويًا قبل إعادة ضبط عدد المحاولات.';

  @override
  String get managedRecoveryBackground =>
      'تنتظر الاستعادة أثناء وجود التطبيق في الخلفية.';

  @override
  String get managedRecoveryChecking =>
      'جارٍ فحص عملية الاستعادة التي يديرها التطبيق…';

  @override
  String managedRecoveryNext(String time) {
    return 'لن تبدأ محاولة الاستعادة التالية قبل $time.';
  }

  @override
  String get managedRecoveryCheck => 'التحقق من حالة الاستعادة';

  @override
  String get managedRecoveryReset => 'إعادة ضبط عدد المحاولات';

  @override
  String get managedRecoverySaveFailed =>
      'تعذّر حفظ إعدادات الاستعادة. أعد المحاولة.';

  @override
  String get managedRecoveryRevokeFailed =>
      'تعذّر حفظ الاستعادة أو إلغاؤها. احتفظ بهذا الملف الشخصي وأعد المحاولة قبل إزالته.';

  @override
  String get managedRecoverySettingsUnreadable =>
      'تعذّرت قراءة إعدادات الاستعادة. افحص الخادم قبل تفعيل الاستعادة.';

  @override
  String get managedRecoveryEnableFailed =>
      'تعذّر تفعيل الاستعادة. شغّل الخادم الذي يديره التطبيق، ثم أعد المحاولة.';

  @override
  String get managedRecoveryOwnershipChanged =>
      'تغيّرت العملية التي يديرها التطبيق. افحص الخادم قبل تفعيل الاستعادة مجددًا.';

  @override
  String get managedRecoveryUncertain =>
      'توقفت الاستعادة مؤقتًا لأن Termux لم يؤكد النتيجة. تحقّق من الحالة للمتابعة.';

  @override
  String get managedRecoveryRetryDisable => 'إعادة محاولة تعطيل الاستعادة';

  @override
  String get managedRecoveryStoppedWithCleanupError =>
      'الخادم المحلي متوقف. تعذّر مسح إعدادات الاستعادة بالكامل؛ أعد محاولة تعطيل الاستعادة في «الخوادم» قبل إزالة الملف الشخصي.';

  @override
  String get pluginMappingPersonal =>
      'روابط أوامرك · لا تؤكد تبعية الأوامر للإضافة';

  @override
  String pluginMappingReview(String command) {
    return 'مراجعة /$command';
  }

  @override
  String get pluginMappingManage => 'ربط الأوامر';

  @override
  String get pluginMappingDescription =>
      'اختر الأوامر التي تربطها بهذه الإضافة. تنطبق هذه الروابط الشخصية على هذا الموقع في الخادم فقط. يفتح كل إجراء مراجعة للمحادثة والمعاملات قبل تشغيله.';

  @override
  String get pluginMappingEmpty => 'لا تتوفر أوامر خادم لربطها.';

  @override
  String get pluginMappingUnavailable =>
      'لم تعد هذه الإضافة أو هذا الأمر متاحًا هنا. حدّث وراجع روابطك.';

  @override
  String get pluginMappingLimit => 'اختر حتى 16 أمرًا لهذه الإضافة.';

  @override
  String get pluginMappingSave => 'حفظ الروابط';

  @override
  String get pluginMappingSaveFailed =>
      'تعذّر حفظ الروابط. تأكّد من أن هذا الموقع على الخادم ما زال محددًا وأعد المحاولة.';

  @override
  String get pluginMappingLoadFailed =>
      'تعذّر تحميل الأوامر. أعد المحاولة عند الاتصال.';

  @override
  String get mobileTasksDescription => 'مهام أبلغ عنها الخادم · عرض الهاتف';

  @override
  String get mobileTasksUnfinished => 'إظهار غير المكتملة فقط';

  @override
  String get mobileTasksNoUnfinished => 'لا مهام غير مكتملة في هذه القائمة.';

  @override
  String get mobileTaskPending => 'معلّقة';

  @override
  String get mobileTaskInProgress => 'قيد التنفيذ';

  @override
  String get mobileTaskCompleted => 'مكتملة';

  @override
  String get mobileTaskCancelled => 'ملغاة';

  @override
  String mobileTasksProgress(int done, int total) {
    return 'اكتمل $done من $total';
  }

  @override
  String get mobileTasksCopyAll => 'نسخ جميع المهام';

  @override
  String get mobileTasksCopied => 'تم نسخ جميع المهام';

  @override
  String get mobileTasksCopyFailed => 'تعذّر نسخ قائمة المهام.';

  @override
  String get mobileTaskPriorityHigh => 'أولوية عالية';

  @override
  String get mobileTaskPriorityMedium => 'أولوية متوسطة';

  @override
  String get mobileTaskPriorityLow => 'أولوية منخفضة';

  @override
  String get pluginMappingClearAll => 'مسح الروابط الشخصية';

  @override
  String get pluginMappingClearTitle => 'مسح جميع روابط الأوامر الشخصية؟';

  @override
  String get pluginMappingClearDescription =>
      'إزالة الروابط الشخصية بين الإضافات والأوامر لكل موقع في ملف هذا الخادم، بما في ذلك المواقع السابقة. تظل إضافات الخادم وأوامره مثبّتة.';

  @override
  String get pluginMappingClearConfirm => 'مسح الروابط';

  @override
  String get pluginMappingClearFailed =>
      'تعذّر مسح الروابط الشخصية. تأكّد من أن ملف هذا الخادم ما زال محددًا وأعد المحاولة.';

  @override
  String get quotaMonitorTitle => 'مراقبة الحصص';

  @override
  String get quotaMonitorConsentTitle => 'مراقبة مصدر مزوّد الخدمة هذا؟';

  @override
  String get quotaMonitorConsent =>
      'اسمح للتطبيق بمواصلة قراءة جامع البيانات الموثوق لحساب مزوّد الخدمة هذا تحديدًا بعد مغادرة الصفحة، وحتى بعد إعادة تشغيل التطبيق. تفحص الدورة ثلاثة مصادر محفوظة كحد أقصى، كل خمس دقائق في المقدمة أو خمس عشرة دقيقة أثناء عمل خدمة الخلفية الحالية. عند وجود أكثر من ثلاثة مصادر، قد ينتظر كل مصدر عدة دورات. تتطلب تنبيهات الجهاز تفعيل المفتاح المنفصل أدناه وقراءة حديثة لفترة بلغت نسبة الاستخدام المحددة أو تجاوزتها. يسجل التنبيه تلك القراءة السابقة؛ افتحه للتحقق من الاستخدام الحالي. حدود الصفحة الشخصية مستقلة. لا تبدأ أي خدمة هنا.';

  @override
  String get quotaMonitorRuntime =>
      'تُفحص المصادر بالتناوب، ثلاثة مصادر كحد أقصى في الدورة؛ وتحتاج القوائم الأطول إلى عدة دورات. تتطلب القراءات في الخلفية أن تكون خدمة الاتصال الحالية نشطة؛ وقد يوقفها Android. تنتهي صلاحية القراءات المعروضة وفقًا لجامع البيانات. تسجل تنبيهات الجهاز قراءات سابقة بلغت الحد، ولا تعرض الرصيد المتبقي الحالي. لا تبدّل هذه الصفحة خادمك النشط مطلقًا.';

  @override
  String get quotaMonitorEmpty =>
      'لا توجد مصادر مزوّدي خدمة خاضعة للمراقبة. اقرأ الاستخدام المتبقي من جامع بيانات موثوق، ثم فعّل المراقبة لذلك المصدر.';

  @override
  String get quotaMonitorEnable => 'تفعيل مراقبة الحصص';

  @override
  String get quotaMonitorNotifications =>
      'تنبيهات الجهاز لحدود الحصص المبلّغ عنها';

  @override
  String get quotaMonitorWifi => 'القراءة على شبكة Wi-Fi مؤكدة فقط';

  @override
  String get quotaMonitorQuiet => 'ساعات الهدوء: 22:00–08:00 بالتوقيت المحلي';

  @override
  String get quotaMonitorDisabled => 'المراقبة متوقفة.';

  @override
  String get quotaMonitorWaiting => 'بانتظار قراءة حديثة.';

  @override
  String get quotaMonitorChecking => 'جارٍ فحص جامع البيانات الموثوق…';

  @override
  String get quotaMonitorCurrent =>
      'قراءة حديثة من مصدر مزوّد الخدمة الذي وافقت عليه.';

  @override
  String get quotaMonitorPaused =>
      'المراقبة متوقفة مؤقتًا. افتح التطبيق أو افحص خدمة الخلفية الحالية.';

  @override
  String get quotaMonitorWifiRequired =>
      'بانتظار شبكة Wi-Fi مؤكدة. حالة الشبكة غير المعروفة لا تسمح بالقراءة.';

  @override
  String get quotaMonitorSourceChanged =>
      'تغيّر حساب مزوّد الخدمة هذا أو مصدره، أو تعذّر التحقق منه. افتح «المتبقي»، واقرأه مجددًا، وراجع الموافقة الجديدة.';

  @override
  String get quotaMonitorSaveFailed =>
      'تعذّر حفظ مراقبة الحصص. عند فشل التعطيل تبقى المراقبة متوقفة مؤقتًا في هذا التطبيق؛ أعد المحاولة قبل إغلاقه.';

  @override
  String get quotaMonitorDisable => 'تعطيل مراقبة الحصص';

  @override
  String get setupChooseServerTitle => 'اختر إعداد خادمك';

  @override
  String get setupChooseServerDescription =>
      'اتصل بخادم موجود، أو استخدم Termux لتشغيل OpenCode على هذا الهاتف.';

  @override
  String get setupUncheckedTitle => 'المتابعة دون فحص التثبيت؟';

  @override
  String get setupUncheckedDescription =>
      'تعذّر فحص التثبيت الحالي. قد تؤدي المتابعة إلى تثبيت OpenCode 1 أو تحديثه في بيئة Ubuntu التي يديرها التطبيق. ستبقى ملفات Ubuntu الحالية. يمكنك الفحص مجددًا أو الاتصال باستخدام العنوان.';

  @override
  String get setupUncheckedContinue => 'المتابعة مع Ubuntu';

  @override
  String get webSearchDisclosure =>
      'يرسل البحث استعلامك إلى مزوّد البحث المحدد على هذا الخادم. راجع النتائج قبل إضافتها إلى مسودتك القابلة للتعديل. لا يُرسل شيء إلى النموذج هنا.';

  @override
  String get webSearchManual => 'أو الصق مصدرًا';

  @override
  String get webSearchUnavailable =>
      'البحث على الويب غير متاح. اضبط مزوّد بحث على هذا الخادم، ثم حدّث مزوّدي الخدمة. لا يزال بإمكانك لصق مصدر أدناه.';

  @override
  String get webSearchAuthentication =>
      'لم يسمح الخادم بالبحث على الويب. تحقّق من بيانات اعتماد هذا الاتصال.';

  @override
  String get webSearchInvalidResponse =>
      'لم تطابق استجابة البحث هذا الاتصال أو التنسيق المدعوم. حدّث مزوّدي الخدمة أو الصق مصدرًا.';

  @override
  String get webSearchFailed =>
      'تعذّر إكمال البحث على الويب. أعد المحاولة أو الصق مصدرًا.';

  @override
  String get webSearchRefresh => 'تحديث مزوّدي الخدمة';

  @override
  String get webSearchProvider => 'مزوّد البحث';

  @override
  String get webSearchQuery => 'استعلام البحث';

  @override
  String get webSearchSubmit => 'بحث';

  @override
  String get webSearchEmpty => 'لا نتائج صالحة لهذا الاستعلام.';

  @override
  String get webSearchOmitted =>
      'أُخفيت بعض النتائج لأن روابطها أو مقتطفاتها تجاوزت حدود المراجعة.';

  @override
  String get setupReinstallStart => 'إعادة التثبيت والتشغيل';

  @override
  String setupInstallVersionStart(String version) {
    return 'تثبيت $version وتشغيله';
  }

  @override
  String get setupReplaceTitle => 'استبدال OpenCode المثبّت؟';

  @override
  String setupReplaceDescription(
    String installedVersion,
    String targetVersion,
  ) {
    return 'استبدال OpenCode $installedVersion بالإصدار $targetVersion في بيئة Ubuntu التي يديرها التطبيق، وإعادة تشغيل الخادم المحلي. ستبقى ملفات Ubuntu الحالية.';
  }

  @override
  String get setupInstallRestart => 'التثبيت وإعادة التشغيل';

  @override
  String get queueStorageUnreadable =>
      'تعذّرت قراءة الطلبات المحفوظة في قائمة الانتظار. لا يمكن إضافة طلبات جديدة إلى القائمة حتى تُمسح بيانات الجهاز هذه.';

  @override
  String get queueStorageDiscardUnreadable =>
      'يحذف هذا نهائيًا الطلبات غير المقروءة في قائمة الانتظار ومرفقاتها من هذا الجهاز. محتواها وعددها غير معروفين. لا يتأثر أي شيء على الخادم.';

  @override
  String get filesViewerScopeChanged =>
      'تغيّر الاتصال. أغلق هذا الملف وافتحه مجددًا.';

  @override
  String get filesViewerPathChanged =>
      'تغيّر سياق الملف. أغلق هذا الملف وافتحه مجددًا.';

  @override
  String get queueStorageCountUnknown =>
      'تعذّرت قراءة بيانات قائمة الانتظار المحفوظة. عدد الطلبات في القائمة غير معروف.';

  @override
  String get codexConnectionVerified =>
      'تم التحقق من الاتصال. احفظ واتصل للمتابعة.';

  @override
  String get codexApprovalRecoveryNotice =>
      'بعد إعادة الاتصال، راجع أي موافقات معلّقة على الكمبيوتر.';

  @override
  String get connectionTokenRejected =>
      'رُفض رمز الاتصال. حدّثه لإعادة الاتصال.';

  @override
  String get updateConnectionToken => 'تحديث الرمز';

  @override
  String get codexDraftReconnectNotice =>
      'تبقى مسودة المراجعة هنا؛ ولا يُرسل شيء تلقائيًا.';

  @override
  String get codexTextOnlyPrompt =>
      'يدعم هذا الاتصال النص فقط. أزل المرفقات قبل الإرسال.';

  @override
  String get codexOfflineDraftSaved =>
      'أعد الاتصال قبل الإرسال. مسودتك محفوظة على هذا الجهاز.';

  @override
  String get codexReconnectBeforeSending => 'أعد الاتصال قبل الإرسال.';

  @override
  String get connectionTypeLabel => 'نوع الاتصال';

  @override
  String get openCodeConnectionLabel => 'OpenCode';

  @override
  String get codexExperimentalLabel => 'Codex (تجريبي)';

  @override
  String get connectionDisplayName => 'الاسم المعروض (اختياري)';

  @override
  String get connectionDisplayNameHint => 'يُستخدم اسم مضيف الخادم افتراضيًا';

  @override
  String get connectionServerAddress => 'عنوان الخادم';

  @override
  String get codexAddressHint => 'wss://codex.example أو ws://127.0.0.1:4500';

  @override
  String get codexAddressHelp =>
      'استخدم wss:// للخوادم البعيدة. يقتصر ws:// على هذا الجهاز.';

  @override
  String get codexProjectFolder => 'مجلد المشروع على الخادم';

  @override
  String get codexTokenReentry => 'أعد إدخال رمز الاتصال';

  @override
  String get codexTokenLabel => 'رمز الاتصال';

  @override
  String get codexTokenStorageHelp =>
      'يُحفظ بأمان على هذا الجهاز، ويُرسل إلى خادم Codex هذا فقط.';

  @override
  String get codexShowToken => 'إظهار رمز الاتصال';

  @override
  String get codexHideToken => 'إخفاء رمز الاتصال';

  @override
  String get codexPasteToken => 'لصق رمز الاتصال';

  @override
  String get connectionCloseEditor => 'إغلاق محرّر الخادم';

  @override
  String get connectionCredentialUnavailable =>
      'لم تعد قراءة بيانات اعتماد اتصال محفوظة ممكنة. عدّل الخادم النشط وأعد إدخالها قبل الاتصال.';

  @override
  String get projectContextTitle => 'سياق المشروع';

  @override
  String get projectConfiguredFolder => 'المجلد المضبوط';

  @override
  String get termuxGuideTitle => 'ربط Termux مرة واحدة';

  @override
  String get termuxGuideIntro => 'ننسخ الأمر لك. إليك ما تفعله عند فتح Termux.';

  @override
  String get termuxGuideAutomaticCheck =>
      'عند عودتك، سنتحقق من الاتصال تلقائيًا.';

  @override
  String get termuxGuideShowCommand => 'إظهار الأمر';

  @override
  String get termuxGuideOpening => 'جارٍ فتح Termux…';

  @override
  String get termuxGuideCopyTitle => '1. انسخ وافتح';

  @override
  String get termuxGuideCopyDescription =>
      'اضغط على «نسخ وفتح Termux» أعلاه. وافق على طلب إذن Android إن ظهر.';

  @override
  String get termuxGuidePasteTitle => '2. اضغط مطولًا ثم الصق';

  @override
  String get termuxGuidePasteDescription =>
      'في Termux، اضغط مطولًا قرب المؤشر الوامض. اضغط على «لصق» في القائمة.';

  @override
  String get termuxGuideEnterTitle => '3. اضغط Enter ثم ارجع';

  @override
  String get termuxGuideEnterDescription =>
      'اضغط مفتاح Enter أو الرجوع على لوحة المفاتيح. عند ظهور bridge-unlocked في Termux، ارجع إلى هذا التطبيق.';

  @override
  String get termuxGuideCopied => 'تم نسخ الأمر';

  @override
  String get termuxGuidePaste => 'لصق';

  @override
  String get termuxGuideEnterKey => 'Enter';

  @override
  String get termuxGuideIllustrationNote =>
      'رسوم توضيحية فقط. قد تختلف لوحة مفاتيحك وقائمة اللصق لديك.';

  @override
  String get termuxGuideOpenFailed =>
      'تم نسخ الأمر، لكن تعذّر فتح Termux. افتحه بنفسك أو حاول «نسخ وفتح Termux» مجددًا.';

  @override
  String get termuxGuideCopyOpenFailed => 'تعذّر نسخ الأمر أو فتح Termux.';

  @override
  String get termuxPermissionDenied =>
      'رفض Android إذن أوامر Termux. اسمح به في إعدادات تطبيق OpenCode.';

  @override
  String get launchShortcutWaiting =>
      'جارٍ الاتصال بالخادم المحفوظ. تُفتح المهمة الجديدة عندما يصبح جاهزًا.';

  @override
  String get launchShortcutNoServer => 'اختر خادمًا، ثم ابدأ مهمة جديدة.';

  @override
  String get launchShortcutReentry =>
      'أدخل بيانات اعتماد الخادم المحفوظ، ثم ابدأ مهمة جديدة.';

  @override
  String get launchShortcutConnectionFailed =>
      'تعذّر الاتصال بالخادم المحفوظ. اختر خادمًا أو أصلح اتصاله، ثم ابدأ مهمة جديدة.';

  @override
  String launchShortcutNewTaskFailed(String error) {
    return 'تعذّر بدء مهمة جديدة. $error';
  }

  @override
  String get launchUiPinnedUntitled => 'جلسة بلا عنوان';

  @override
  String get launchUiSessionWaiting =>
      'جارٍ الاتصال بالخادم المحفوظ. ستُفتح الجلسة عندما يصبح جاهزًا.';

  @override
  String get launchUiSessionNoServer =>
      'اختر خادمًا، ثم افتح الجلسة من قائمته.';

  @override
  String get launchUiSessionReentry =>
      'أدخل بيانات اعتماد الخادم المحفوظ، ثم افتح الجلسة من قائمته.';

  @override
  String get launchUiSessionConnectionFailed =>
      'تعذّر الاتصال بالخادم المحفوظ. اختر خادمًا أو أصلحه، ثم افتح الجلسة من قائمته.';

  @override
  String get launchUiSessionOtherServer =>
      'هذا الاختصار يخص خادمًا آخر. اتصل بذلك الخادم، ثم افتح الجلسة من قائمته.';

  @override
  String get launchUiActivityNoServer =>
      'اختر خادمًا لترى ما يحتاج إلى انتباهك.';

  @override
  String get queuedSending => 'جارٍ الإرسال…';

  @override
  String get queuedDeliveryUnconfirmed =>
      'التسليم غير مؤكد — راجع قبل إعادة الإرسال';

  @override
  String queuedDeliveryUnconfirmedWithError(String error) {
    return 'التسليم غير مؤكد: $error';
  }

  @override
  String get queuedResendTooltip => 'إرسال مجددًا';

  @override
  String get queuedResendTitle => 'إرسال هذه المسودة مجددًا؟';

  @override
  String get queuedResendMessage =>
      'ربما وصلت إلى OpenCode بالفعل. قد يكررها الإرسال مجددًا.';

  @override
  String get queuedResendConfirm => 'إرسال مجددًا';

  @override
  String get queuedKeepForReview => 'الاحتفاظ للمراجعة';

  @override
  String get queuedDiscardUnconfirmedMessage =>
      'لم يُؤكَّد إرسالها السابق؛ ربما توجد في الجلسة بالفعل.';

  @override
  String get setupRuntimeTitle => 'أي إصدار من OpenCode تريد استخدامه؟';

  @override
  String get setupRuntimeOne => 'OpenCode 1';

  @override
  String get setupRuntimeOneDetail =>
      'موصى به للحصول على أوسع دعم لميزات هذا التطبيق.';

  @override
  String get setupRuntimeTwo => 'OpenCode 2 التجريبي';

  @override
  String get setupRuntimeTwoDetail =>
      'جرّب واجهة API الجديدة للخادم. بعض الميزات غير متاحة في هذا الإصدار التجريبي.';

  @override
  String setupRuntimeInstallDetail(String runtime, String version) {
    return 'تثبيت $runtime ($version) في بيئة Ubuntu يديرها التطبيق. يُعاد استخدام ملفات Ubuntu الحالية.';
  }

  @override
  String setupRuntimeUpdateDetail(String runtime, String version) {
    return 'سيثبّت التطبيق $runtime $version، ويعيد تشغيل الخادم المحلي الذي يديره فقط، ثم يعيد اتصال هذا الملف الشخصي.';
  }

  @override
  String queuedBannerReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسودة بإرسال غير مؤكد تحتاج إلى مراجعة.',
      many: '$count مسودة بإرسال غير مؤكد تحتاج إلى مراجعة.',
      few: '$count مسودات بإرسال غير مؤكد تحتاج إلى مراجعة.',
      two: 'مسودتان بإرسال غير مؤكد تحتاجان إلى مراجعة.',
      one: 'مسودة واحدة بإرسال غير مؤكد تحتاج إلى مراجعة.',
      zero: 'لا مسودات بإرسال غير مؤكد تحتاج إلى مراجعة.',
    );
    return '$_temp0';
  }

  @override
  String get isolatedTaskAction => 'بدء مهمة في شجرة عمل جديدة';

  @override
  String get isolatedTaskTitle => 'مهمة جديدة في شجرة عمل جديدة';

  @override
  String isolatedTaskIntro(String project) {
    return 'ينشئ OpenCode شجرة عمل Git وفرعًا جديدين للمشروع $project ويشغّل إعداد المشروع. تبقى شجرة العمل ضمن «إدارة المشروع» حتى تزيلها من هناك.';
  }

  @override
  String get isolatedTaskNameLabel => 'اسم شجرة العمل (اختياري)';

  @override
  String get isolatedTaskNameHelper => 'اتركه فارغًا ليختار OpenCode اسمًا.';

  @override
  String get isolatedTaskStart => 'إنشاء وبدء';

  @override
  String get isolatedTaskCreating => 'جارٍ إنشاء شجرة العمل…';

  @override
  String get isolatedTaskCreatingHint =>
      'التوقف الآن لا يلغي عملية إنشاء ربما بدأ الخادم تنفيذها بالفعل.';

  @override
  String isolatedTaskPreparing(String name) {
    return 'تم إنشاء $name. يعمل OpenCode على تجهيزها…';
  }

  @override
  String isolatedTaskReady(String name) {
    return '$name جاهزة. جارٍ فتح جلسة فارغة…';
  }

  @override
  String isolatedTaskReadyIdle(String name) {
    return '$name جاهزة.';
  }

  @override
  String isolatedTaskUnconfirmed(String name) {
    return 'تم إنشاء $name، لكن حالة إعدادها غير مؤكدة.';
  }

  @override
  String get isolatedTaskUnconfirmedHint =>
      'يمكنك مواصلة الانتظار أو فتحها الآن. ربما لا يزال الإعداد جاريًا.';

  @override
  String get isolatedTaskFailed => 'تعذّر على OpenCode تجهيز شجرة العمل.';

  @override
  String get isolatedTaskCreateFailed => 'تعذّر إنشاء شجرة العمل.';

  @override
  String isolatedTaskFailedKept(String name) {
    return 'تبقى $name ضمن «إدارة المشروع». لم يُحذف شيء.';
  }

  @override
  String get isolatedTaskCancelled => 'تم التوقف عن الانتظار.';

  @override
  String isolatedTaskCancelledKept(String name) {
    return 'تم إنشاء $name وهي باقية ضمن «إدارة المشروع».';
  }

  @override
  String get isolatedTaskCancelledUnknown =>
      'إذا أنشأ OpenCode شجرة العمل، فستظهر ضمن «إدارة المشروع».';

  @override
  String isolatedTaskOpening(String name) {
    return 'جارٍ فتح جلسة فارغة في $name…';
  }

  @override
  String isolatedTaskOpened(String name) {
    return 'الجلسة جاهزة في $name. لم يُرسل شيء.';
  }

  @override
  String isolatedTaskBranch(String branch) {
    return 'الفرع $branch';
  }

  @override
  String get isolatedTaskStopWaiting => 'التوقف عن الانتظار';

  @override
  String get isolatedTaskKeepWaiting => 'مواصلة الانتظار';

  @override
  String get isolatedTaskOpenAnyway => 'فتح على أي حال';

  @override
  String get isolatedTaskRetryOpen => 'إعادة المحاولة';

  @override
  String get isolatedTaskClose => 'إغلاق';

  @override
  String get returnBriefTitle => 'عمل لم يُراجع';

  @override
  String get returnBriefDescription =>
      'لهذا المشروع على هذا الجهاز. يبقي التجاهل المحادثات غير مقروءة والطلبات معلّقة.';

  @override
  String get returnBriefUntitled => 'جلسة بلا عنوان';

  @override
  String get returnBriefStale =>
      'آخر حالة مرصودة. أعد الاتصال أو حدّث للتحقق من العمل والطلبات الحالية.';

  @override
  String get returnBriefStatusUnknown => 'حالة المراجعة غير معروفة';

  @override
  String get returnBriefUnknown =>
      'لا يبلّغ هذا الخادم عن حالة القراءة. النتائج التي لم تُراجع غير معروفة.';

  @override
  String get returnBriefPartial =>
      'الجلسات المحمّلة فقط. قائمة الجلسات لم تكتمل بعد.';

  @override
  String get returnBriefAnswer => 'إجابة';

  @override
  String get returnBriefUnreviewed =>
      'جلسة لم تُراجع. افتح النتائج للتحقق من المحصلة.';

  @override
  String get returnBriefReview => 'مراجعة النتائج';

  @override
  String get returnBriefContinue => 'متابعة';

  @override
  String returnBriefMore(int count) {
    return 'عناصر إضافية: $count. تبقى دون إقرار؛ راجع الجلسات أدناه أو «النشاط».';
  }

  @override
  String get returnBriefSaveFailed =>
      'لم يُحفظ التجاهل. ما زالت هذه العناصر غير مراجعة. أعد المحاولة.';

  @override
  String get returnBriefSaving => 'جارٍ حفظ التجاهل…';

  @override
  String get returnBriefDismiss => 'تجاهل العناصر المعروضة';

  @override
  String get capsuleTitle => 'حزمة السياق';

  @override
  String get capsuleEntry =>
      'اجمع الملاحظات والأخطاء ولقطات الشاشة لهذه المهمة';

  @override
  String get capsuleDescription =>
      'أنشئ حزمة لهذه المهمة. تضيفها إلى مسودتك الحالية دون إرسال أي شيء. تُحفظ التعديلات غير المطبّقة ما دامت هذه الشاشة مفتوحة فقط.';

  @override
  String get capsuleNote => 'ملاحظة';

  @override
  String get capsuleError => 'خطأ';

  @override
  String get capsuleCode => 'شيفرة';

  @override
  String get capsuleLabel => 'تسمية';

  @override
  String get capsuleExcerpt => 'مقتطف';

  @override
  String get capsulePaste => 'لصق';

  @override
  String get capsuleRemove => 'إزالة';

  @override
  String get capsuleAddImage => 'إضافة لقطة شاشة أو صورة';

  @override
  String get capsulePreview => 'اضغط للمعاينة';

  @override
  String get capsuleApply => 'إضافة إلى المسودة';

  @override
  String get capsuleApplied =>
      'أُضيف السياق إلى مسودتك المحفوظة. راجعه قبل الإرسال.';

  @override
  String get capsuleScopeChanged =>
      'تغيّرت المهمة أو الاتصال أو المسودة. أغلق حزمة السياق هذه وافتحها مجددًا من المهمة المقصودة.';

  @override
  String get capsuleTextOnly =>
      'يقبل هذا الاتصال النص فقط. لا يزال بإمكانك جمع الملاحظات والأخطاء والشيفرة.';

  @override
  String get capsuleImagesOnly =>
      'اختر صورة PNG أو JPEG أو GIF أو WebP. الصق النص في مقتطف بدلًا من ذلك.';

  @override
  String get capsuleImageFailed =>
      'تعذّرت إضافة تلك الصورة. استخدم حتى 5 مرفقات، بحد أقصى 10 MB لكل منها و20 MB إجمالًا، بما فيها مسودتك الحالية.';

  @override
  String get capsulePasteFailed =>
      'نص الحافظة غير متاح. يمكنك الكتابة أو اللصق في المقتطف.';

  @override
  String get capsuleTextLimit =>
      'اجعل كل مقتطف أقل من 16,000 حرف، والحزمة أقل من 32,000 حرف.';

  @override
  String get markdownCopyCode => 'نسخ الشيفرة';

  @override
  String get markdownCopied => 'تم نسخ الشيفرة';

  @override
  String get markdownCopyFailed => 'تعذّر نسخ الشيفرة. أعد المحاولة.';

  @override
  String get markdownCopyRetry => 'إعادة المحاولة';

  @override
  String get markdownWrapCode => 'التفاف الأسطر';

  @override
  String get markdownScrollCode => 'تمرير الأسطر';

  @override
  String get markdownExpandCode => 'ملء الشاشة';

  @override
  String get markdownReaderTitle => 'قارئ الشيفرة';

  @override
  String get markdownSnapshot =>
      'نسخة من الشيفرة عند فتح القارئ. أغلق القارئ وافتحه مجددًا لقراءة التحديثات اللاحقة.';

  @override
  String get tailscaleTitle => 'الاتصال عبر Tailscale';

  @override
  String get tailscaleQuickAdd => 'استخدم شبكتك الخاصة وعنوان خادم HTTPS';

  @override
  String get tailscaleIntro =>
      'اتصل بـ OpenCode على كمبيوتر آخر عبر شبكة Tailscale الخاصة بك. تتحكم في تسجيل الدخول والوصول عبر VPN من تطبيق Tailscale الرسمي.';

  @override
  String get tailscaleAppStep => '1. افتح شبكتك الخاصة';

  @override
  String get tailscaleChecking => 'جارٍ التحقق من تطبيق Tailscale…';

  @override
  String get tailscaleInstalled => 'Tailscale مثبّت. اتصال VPN غير مؤكد.';

  @override
  String get tailscaleMissing =>
      'Tailscale غير مثبّت. ثبّت التطبيق الرسمي، ثم عد وتحقّق مجددًا.';

  @override
  String get tailscaleUnknown =>
      'تعذّر فحص التطبيق. أعد المحاولة، أو افتح Tailscale من هاتفك.';

  @override
  String get tailscaleUnsupported =>
      'لا يستطيع هذا الجهاز فتح تطبيق Android. اضبط Tailscale على هذا الجهاز بنفسك، ثم راجع عنوان HTTPS أدناه.';

  @override
  String get tailscaleVpnHandoff =>
      'في Tailscale، سجّل الدخول إلى الشبكة التي تصل إلى خادمك، ووافق على طلب VPN من Android إن ظهر، ثم فعّل الاتصال. لا يستطيع OpenCode رؤية حالة VPN أو تغييرها.';

  @override
  String get tailscaleReturned =>
      'مرحبًا بعودتك. أُعيد التحقق من وجود التطبيق؛ استخدم «اختبار الاتصال» في الشاشة التالية لفحص خادمك.';

  @override
  String get tailscaleOpenFailed =>
      'تعذّر فتح Tailscale. افتحه من مشغّل التطبيقات، ثم عد إلى هنا. يبقى عنوانك في هذا النموذج.';

  @override
  String get tailscaleOpen => 'فتح Tailscale';

  @override
  String get tailscaleInstall => 'الحصول على تطبيق Android الرسمي';

  @override
  String get tailscaleCheckAgain => 'فحص التطبيق مجددًا';

  @override
  String get tailscaleAddressStep => '2. راجع عنوان خادمك';

  @override
  String get tailscaleAddressLabel => 'عنوان خادم HTTPS الخاص';

  @override
  String get tailscaleAddressDetail =>
      'استخدم أصل HTTPS الكامل الذي يعرضه Tailscale Serve، مثل https://computer.tailnet-name.ts.net. احتفظ بأي منفذ HTTPS يعرضه. قد لا يوفّر اسم جهاز مختصر أو منفذ HTTP مباشر شهادة صالحة.';

  @override
  String get tailscaleAddressError =>
      'أدخل أصل HTTPS بمنفذ صالح (1–65535). أزل المسارات وبيانات الاعتماد ونص الاستعلام والأجزاء الملحقة. استخدم العنوان الكامل من Serve؛ ولا تستبدل https بـ http.';

  @override
  String get tailscaleReviewDetail =>
      'تابع فقط بعنوان تعرفه. تراجع الشاشة التالية بيانات اعتماد خادمك قبل أن تختبره أو تحفظه صراحةً. لا يستطيع التطبيق تأكيد خصوصية عنوان من اسمه وحده.';

  @override
  String get tailscaleContinue => 'المتابعة إلى المصادقة';

  @override
  String get tailscaleHelp => 'إعداد Tailscale واستعادة الاتصال';

  @override
  String get tailscaleServeHelp =>
      'على كمبيوتر الخادم، يستطيع Tailscale Serve توفير HTTPS خاص لمنفذ OpenCode محلي. استخدم Serve، وليس Funnel العام. تظل قواعد الوصول إلى شبكة tailnet سارية. ينشر تفعيل HTTPS اسمي الجهاز وشبكة tailnet في سجل شهادات عام، مع بقاء الوصول خاصًا. راجع الدليل الرسمي قبل تغيير خادمك.';

  @override
  String get tailscaleServeDocs => 'قراءة دليل Serve الرسمي';

  @override
  String get tailscaleAndroidDocs => 'قراءة دليل Android الرسمي';

  @override
  String get tailscaleRecovery =>
      'إذا تعذّر الوصول إلى الخادم، فتحقّق من Tailscale على الجهازين، واسم HTTPS الكامل ومنفذه، وServe على الخادم، وقواعد وصول شبكتك. قد يمنع تعارض VPN أو DNS الوصول أيضًا. أبقِ HTTPS مفعّلًا. صحّح كلمة مرور الخادم إذا رُفضت المصادقة، ثم أعد «اختبار الاتصال».';

  @override
  String get tailscaleEditorDetail =>
      'تُدار شبكة اتصالك في Tailscale. يفحص «اختبار الاتصال» خادم OpenCode هذا، لا شبكة VPN. أدخل هنا اسم مستخدم الخادم وكلمة مروره، لا بيانات دخول Tailscale. تحافظ مساعدة الإعداد على هذه الحقول.';

  @override
  String get a2aDraftSaveError =>
      'تعذّر حفظ تعديلات المسودة. أبقِ هذه الشاشة مفتوحة وأعد المحاولة قبل المغادرة.';

  @override
  String get a2aRetryDraftSave => 'إعادة محاولة حفظ المسودة';

  @override
  String get a2aSavingDraft => 'جارٍ حفظ تعديلات المسودة…';

  @override
  String a2aCardVersion(String version) {
    return 'إصدار الوكيل: $version';
  }

  @override
  String get a2aSupportedConnection => 'A2A 1.0 · JSON-RPC · مهام نصية';

  @override
  String get a2aTitle => 'الوكلاء الخارجيون';

  @override
  String get a2aIntro => 'أضف وكيلًا تثق به.';

  @override
  String get a2aBoundary =>
      'اتصل بوكيل A2A وأرسل إليه مهمة تختارها. لا يُشارك سوى النص الذي ترسله. تبقى مشاريعك وملفاتك ومحادثاتك الأخرى على هذا الهاتف.';

  @override
  String get a2aAdd => 'إضافة وكيل';

  @override
  String get a2aEmpty =>
      'لا وكلاء خارجيون بعد. ابدأ بعنوان HTTPS لوكيل أو برابط بطاقة وكيل عامة.';

  @override
  String get a2aDeleteAgent => 'حذف الوكيل';

  @override
  String get a2aDeleteAgentDetail =>
      'إزالة هذا الوكيل ومهامه المحفوظة وبيانات اعتماده من هذا الهاتف. لا يوقف هذا العمل البعيد، ولا يحذف البيانات التي يحتفظ بها الوكيل.';

  @override
  String get a2aDeleteLocal => 'حذف البيانات المحلية';

  @override
  String get a2aDeletionPending =>
      'الحذف المحلي غير مكتمل. هذا الوكيل غير متاح حتى تُزال بياناته المتبقية.';

  @override
  String get a2aRetryDelete => 'إعادة محاولة الحذف';

  @override
  String get a2aInspectIntro => 'افحص قبل الاتصال';

  @override
  String get a2aAddress => 'عنوان الوكيل';

  @override
  String get a2aInspect => 'فحص بطاقة الوكيل';

  @override
  String get a2aUnsupported =>
      'غير متاح: لا تعلن هذه البطاقة عن المجموعة المدعومة من A2A 1.0 وJSON-RPC والنص والمصادقة على الأصل نفسه، أو تتطلب امتدادًا غير مدعوم. لا يمكن إرسال أي مهمة.';

  @override
  String get a2aBearerDetail =>
      'أدخل بيانات اعتماد HTTP bearer صادرة لهذا الوكيل. تُحفظ في مخزن الهاتف الآمن، وتُرسل إلى الأصل المفحوص فقط. لا يُجرى تسجيل دخول أو مشاركة لبيانات الاعتماد مع وكلاء آخرين.';

  @override
  String get a2aNoAuthDetail =>
      'لا تطلب هذه البطاقة مصادقة. لا ترسل معلومات خاصة إلا إذا كنت تثق بهذا الوكيل.';

  @override
  String get a2aBearer => 'بيانات اعتماد bearer للوكيل';

  @override
  String get a2aSave => 'حفظ الوكيل';

  @override
  String get a2aCardClaim =>
      'بطاقة وكيل يقدّمها الوكيل نفسه. لم يتحقق هذا التطبيق من هويته أو مهاراته أو شروط فوترته.';

  @override
  String get a2aSkills => 'المهارات المعلنة';

  @override
  String get a2aNewTask => 'مهمة جديدة';

  @override
  String get a2aTaskPrompt => 'نص المهمة';

  @override
  String get a2aSendDetail =>
      'راجع النص والوجهة قبل الإرسال. قد يستخدم الوكيل موارد حوسبة أو خدمات خاصة به؛ راجع شروطه. لا يستطيع هذا التطبيق تقدير ذلك الاستخدام أو تقييده.';

  @override
  String get a2aReviewTask => 'مراجعة المهمة';

  @override
  String get a2aUpdateCredential => 'تحديث بيانات الاعتماد';

  @override
  String get a2aSavedTasks => 'المهام المحفوظة';

  @override
  String get a2aReopenDetail =>
      'عند إعادة الفتح تُفحص المهمة الحالية. ولا تُرسل مهمتك مجددًا مطلقًا.';

  @override
  String get a2aDeliveryUnconfirmed => 'التسليم غير مؤكد';

  @override
  String get a2aDraft => 'لم تُرسل';

  @override
  String get a2aBack => 'رجوع';

  @override
  String get a2aTaskTitle => 'مهمة الوكيل';

  @override
  String get a2aFresh => 'تم التحقق مع الوكيل في هذه الزيارة.';

  @override
  String get a2aSavedSnapshot =>
      'محفوظة محليًا. حدّث مهمة معروفة للتحقق من حالتها الحالية.';

  @override
  String get a2aCancelTask => 'إلغاء المهمة';

  @override
  String get a2aCancelDetail =>
      'اطلب من هذا الوكيل إلغاء هذه المهمة. ربما اكتمل العمل بالفعل؛ ويقرر الوكيل ما إذا كان الإلغاء ممكنًا.';

  @override
  String get a2aRequestCancel => 'طلب الإلغاء';

  @override
  String get a2aForgetTask => 'نسيان المهمة المحفوظة';

  @override
  String get a2aForgetDetail =>
      'إزالة هذه المهمة المحفوظة من الهاتف. قد يستمر العمل البعيد، بما فيه إرسال لم يُؤكَّد تسليمه. لا يمكن بهذا حذف نسخة الوكيل.';

  @override
  String get a2aYourReply => 'ردك';

  @override
  String get a2aSend => 'إرسال إلى الوكيل';

  @override
  String get a2aReplySameTask => 'الرد على هذه المهمة';

  @override
  String get a2aAgentOutput => 'مخرجات الوكيل';

  @override
  String get a2aBlockedLink => 'رابط غير مدعوم';

  @override
  String get a2aReviewLink => 'مراجعة الرابط الخارجي';

  @override
  String get a2aOmittedContent =>
      'حُجب بعض المخرجات. يعرض هذا المشهد نصًا وروابط ضمن حدود محددة؛ ولا تُنزَّل المخرجات الثنائية أو المنظّمة ولا تُنفَّذ.';

  @override
  String get a2aRefresh => 'تحديث المهمة';

  @override
  String get a2aSubmitted => 'تم تقديمها';

  @override
  String get a2aWorking => 'قيد التنفيذ';

  @override
  String get a2aInputRequired => 'يلزم ردك';

  @override
  String get a2aAuthRequired => 'الوكيل يتطلب المصادقة';

  @override
  String get a2aCompleted => 'مكتملة';

  @override
  String get a2aFailed => 'فشلت';

  @override
  String get a2aCanceled => 'ملغاة';

  @override
  String get a2aRejected => 'مرفوضة';

  @override
  String get a2aUnknown => 'حالة مهمة غير مدعومة';

  @override
  String get a2aAddressError =>
      'استخدم أصل HTTPS أو رابط بطاقة وكيل عامة دون بيانات اعتماد أو استعلام أو جزء ملحق. يُدعم HTTP على عنوان الاسترجاع المحلي لهذا الجهاز فقط.';

  @override
  String get a2aAuthenticationError =>
      'رفض الوكيل بيانات الاعتماد هذه أو تعذّر عليه استخدامها. ارجع إلى الوكيل لتحديثها، ثم أعد فتح المهمة المحفوظة.';

  @override
  String get a2aUnavailable =>
      'تعذّر الوصول إلى الوكيل أو رفض هذه العملية. حدّث مهمة معروفة للتحقق من حالتها.';

  @override
  String get a2aInvalidResponse =>
      'أعاد الوكيل استجابة غير مدعومة أو أكبر من الحد أو غير مطابقة. لم تُستبدل المهمة المحفوظة.';

  @override
  String get a2aUncertain =>
      'ربما استلم الوكيل هذه الرسالة. لن تُرسل مجددًا. إذا تأكد معرّف المهمة، فحدّث للتحقق من التقدم؛ وإلا فتحقّق مع الوكيل قبل بدء مهمة أخرى.';

  @override
  String get a2aStorageError =>
      'تعذّر حفظ البيانات المحلية أو إزالتها. تحقّق من مساحة الجهاز وأعد العملية المحلية. لا تُرسل رسالة دون حفظ علامة تسليم لها.';

  @override
  String get a2aScopeError =>
      'تغيّر هذا الوكيل أو بيانات اعتماده أو المهمة المحفوظة. أغلق هذا العرض وأعد فتح الوكيل للمتابعة.';

  @override
  String get a2aCancelUnconfirmed =>
      'الإلغاء غير مؤكد. لا يزال الوكيل يبلّغ عن مهمة نشطة؛ حدّث للتحقق مجددًا.';

  @override
  String get a2aAuthRequiredDetail =>
      'طلب هذا الوكيل مسار مصادقة إضافيًا لا يدعمه هذا العميل. لن يحدث تسجيل دخول أو استئناف للمهمة تلقائيًا.';

  @override
  String get a2aUnknownDetail =>
      'حالة هذه المهمة غير مدعومة. يمكنك تحديث السجل المحلي أو نسيانه؛ بينما يظل الإرسال والإلغاء غير متاحين.';

  @override
  String get fileTable => 'جدول';

  @override
  String get fileSource => 'المصدر';

  @override
  String get fileSourceExcerpt =>
      'يُعرض حتى أول 200,000 حرف. يحتفظ النسخ والحفظ بالمحتوى الأصلي.';

  @override
  String get filePreviewPartialSource =>
      'يُعرض جزء من هذا الملف فقط. يحتفظ النسخ والحفظ بالمحتوى الأصلي.';

  @override
  String fileLineOutsidePreview(int line) {
    return 'السطر $line خارج هذه المعاينة. احفظ الملف الأصلي لقراءة ذلك الموضع.';
  }

  @override
  String get fileTableMalformed =>
      'علامات الاقتباس في هذا الملف غير مكتملة أو غير متسقة. اقرأ مصدره بدلًا من ذلك.';

  @override
  String get fileTableTooLarge =>
      'تدعم معاينة الجدول ملفات حتى 256 KB. اقرأ المصدر أو احفظ الملف الأصلي.';

  @override
  String get fileTableTooWide =>
      'يحتوي هذا الملف على أكثر من 32 عمودًا. اقرأ المصدر أو احفظ الملف الأصلي.';

  @override
  String get fileTableFieldTooLong =>
      'تتجاوز إحدى الخلايا 4,096 حرفًا. اقرأ المصدر أو احفظ الملف الأصلي.';

  @override
  String get fileTableMoreRows =>
      'يُعرض أول 200 صف. توجد بيانات إضافية في الملف الأصلي.';

  @override
  String fileTableRows(int rows, int columns) {
    return 'الصفوف المعروضة: $rows · الأعمدة: $columns';
  }

  @override
  String fileTableColumn(int number) {
    return 'العمود $number';
  }

  @override
  String get fileTableEmpty => 'لا يحتوي هذا الملف على صفوف.';

  @override
  String get fileCopied => 'تم نسخ محتوى الملف';

  @override
  String get fileCopyFailed => 'تعذّر نسخ محتوى الملف. أعد المحاولة.';

  @override
  String get fileImage => 'صورة';

  @override
  String get fileSvgUnsupported =>
      'لا يمكن عرض SVG هذا كصورة محلية ثابتة. اقرأ مصدره أو احفظ الملف الأصلي. لا تُدعم الموارد الخارجية أو الحركة أو ميزات SVG المعقدة.';

  @override
  String get filePdfEncrypted =>
      'يتطلب PDF هذا كلمة مرور أو يستخدم حماية غير مدعومة. احفظ الملف الأصلي لفتحه في تطبيق PDF.';

  @override
  String get filePdfLimit =>
      'تدعم معاينة PDF ملفات حتى 10 MB وأول 200 صفحة. احفظ الملف الأصلي لقراءة المستند كاملًا.';

  @override
  String get filePdfUnavailable =>
      'عرض PDF متاح على Android 10 أو أحدث. لا يزال بإمكانك حفظ الملف الأصلي.';

  @override
  String get filePdfCancelled =>
      'أُلغي تحميل PDF. أعد المحاولة عندما تكون جاهزًا.';

  @override
  String get filePdfFailed =>
      'تعذّر عرض صفحة PDF هذه. أعد المحاولة أو احفظ الملف الأصلي.';

  @override
  String get filePdfPageLimit =>
      'يمكن معاينة أول 200 صفحة فقط. احفظ الملف الأصلي لقراءة المستند كاملًا.';

  @override
  String filePdfPage(int page, int count) {
    return 'الصفحة $page من $count';
  }

  @override
  String get filePrevious => 'السابق';

  @override
  String get fileNext => 'التالي';

  @override
  String get fileCancel => 'إلغاء';

  @override
  String get agentAccountTitle => 'حساب Codex';

  @override
  String get agentAccountScopeLost =>
      'تغيّر هذا الاتصال. ارجع إلى «الخوادم» وافتح الحساب للملف الشخصي المتصل.';

  @override
  String get agentAccountRefresh => 'تحديث الحساب';

  @override
  String get agentAccountLoading => 'جارٍ فحص حساب المضيف';

  @override
  String get agentAccountUnavailable => 'لوحة الحساب غير متاحة';

  @override
  String get agentAccountReadFailed => 'تعذّرت قراءة الحساب';

  @override
  String get agentAccountDisconnected => 'انقطع الاتصال';

  @override
  String get agentAccountConnected => 'تم تسجيل الدخول على المضيف';

  @override
  String get agentAccountSignedOut => 'جاهز لتسجيل الدخول';

  @override
  String get agentAccountInProgress => 'جارٍ تسجيل الدخول';

  @override
  String get agentAccountNeedsAttention => 'تسجيل الدخول يحتاج إلى انتباه';

  @override
  String get agentAccountNoAuth => 'المضيف لا يتطلب تسجيل دخول';

  @override
  String get agentAccountApiKey => 'مفتاح API';

  @override
  String get agentAccountHostAuth => 'مصادقة المضيف';

  @override
  String agentAccountPlan(String plan) {
    return 'الخطة: $plan';
  }

  @override
  String get agentAccountHostNote =>
      'تحتفظ بيئة Codex الرسمية ببيانات اعتماد مزوّد الخدمة. تنطبق تغييرات الحساب على هذا المضيف، بما في ذلك الملفات الشخصية الأخرى المتصلة به.';

  @override
  String get agentAccountUnsupportedDetail =>
      'تم التحقق من هذه اللوحة مع Codex 0.153.4. قد لا تدعم بيئة التشغيل المتصلة طرق الحساب هذه.';

  @override
  String get agentAccountReconnectDetail =>
      'مُسحت بيانات الحساب ورمز تسجيل الدخول. أعد الاتصال للتحديث. لن يُعاد بدء تسجيل الدخول تلقائيًا.';

  @override
  String get agentAccountSignIn => 'تسجيل الدخول باستخدام ChatGPT';

  @override
  String get agentAccountSignInNote =>
      'ابدأ تسجيل دخول رسميًا برمز جهاز على هذا المضيف. أكمله في متصفحك؛ ولا يتلقى التطبيق رموز مزوّد الخدمة مطلقًا.';

  @override
  String get agentAccountLimits => 'حدود معدل الطلبات';

  @override
  String get agentAccountLimitsUnavailable =>
      'حدود معدل الطلبات غير متاحة لهذا الحساب أو المضيف.';

  @override
  String get agentAccountUsage => 'استخدام الرموز';

  @override
  String get agentAccountUsageUnavailable =>
      'استخدام الرموز غير متاح لهذا الحساب أو المضيف.';

  @override
  String get agentAccountLifetimeTokens => 'إجمالي الرموز منذ البدء';

  @override
  String get agentAccountPeakTokens => 'أعلى استخدام يومي للرموز';

  @override
  String get agentAccountUsageNote =>
      'يبلّغ المضيف عن القيم. القيم المفقودة مجهولة، وليست صفرًا. لا تمثل أعداد الرموز فاتورة أو رصيد رسائل متبقيًا.';

  @override
  String agentAccountUpdated(String time) {
    return 'آخر تحقق $time';
  }

  @override
  String get agentAccountStarting => 'جارٍ طلب رمز تسجيل الدخول';

  @override
  String get agentAccountWaiting => 'أكمل تسجيل الدخول في متصفحك';

  @override
  String get agentAccountCancelling => 'جارٍ إلغاء تسجيل الدخول';

  @override
  String get agentAccountCancelled => 'أُلغي تسجيل الدخول';

  @override
  String get agentAccountLoginFailed =>
      'لم يكتمل تسجيل الدخول. تحقّق من المضيف وأعد المحاولة.';

  @override
  String get agentAccountLoginUncertain =>
      'تعذّر على المضيف تأكيد تسجيل الدخول أو الإلغاء. ربما لا يزال ينتظر. افحص بيئة التشغيل الرسمية على المضيف قبل البدء مجددًا.';

  @override
  String get agentAccountLoginCompleted =>
      'اكتمل تسجيل الدخول. جارٍ فحص الحساب.';

  @override
  String get agentAccountCodeHint =>
      'أدخل هذا الرمز الذي يُستخدم مرة واحدة في صفحة تسجيل الدخول الرسمية. احتفظ به سريًا.';

  @override
  String get agentAccountOpenSignIn => 'فتح تسجيل الدخول الرسمي';

  @override
  String get agentAccountCancel => 'إلغاء تسجيل الدخول';

  @override
  String get agentAccountAllowance => 'رصيد الاستخدام المبلّغ عنه';

  @override
  String agentAccountPercentUsed(int percent) {
    return 'تم استخدام $percent%';
  }

  @override
  String get agentAccountWindowUnknown => 'مدة الفترة غير متاحة';

  @override
  String agentAccountWindowMinutes(int minutes) {
    return 'مدة الفترة بالدقائق: $minutes';
  }

  @override
  String agentAccountWindowHours(int hours) {
    return 'مدة الفترة بالساعات: $hours';
  }

  @override
  String agentAccountWindowDays(int days) {
    return 'مدة الفترة بالأيام: $days';
  }

  @override
  String get agentAccountResetUnknown => 'موعد التجديد غير متاح';

  @override
  String agentAccountReset(String time) {
    return 'يُجدَّد $time';
  }

  @override
  String get projectFolderChooserTitle => 'اختر مجلد مشروع';

  @override
  String get projectFolderChooserMessage =>
      'لا يعمل OpenCode Mobile في المجلد الرئيسي للخادم. أنشئ مجلدًا جديدًا أو افتح مجلد مشروع لبدء الجلسات.';

  @override
  String get projectFolderCreate => 'إنشاء مجلد جديد';

  @override
  String get projectFolderOpen => 'فتح مجلد مشروع';

  @override
  String get projectFolderBrowse => 'الاختيار من المشاريع المفتوحة';

  @override
  String get projectFolderNoCreateHint =>
      'لا يستطيع هذا الخادم إنشاء مجلدات من التطبيق. أنشئ المجلد على ذلك الجهاز، ثم افتحه هنا باستخدام مساره.';

  @override
  String projectFolderCreateMessage(String directory) {
    return 'يُنشأ المجلد في $directory على هذا الجهاز ويُفتح كمساحة عمل.';
  }

  @override
  String get projectFolderNameLabel => 'اسم المجلد';

  @override
  String get projectFolderNameHint => 'my-app';

  @override
  String get projectFolderCreateAction => 'إنشاء';

  @override
  String get projectFolderCancel => 'إلغاء';

  @override
  String get projectFolderOpenMessage =>
      'أدخل المسار الكامل لمجلد على الخادم. لا يمكن استخدام المجلد الرئيسي نفسه؛ اختر مشروعًا داخله.';

  @override
  String get projectFolderPathLabel => 'مسار المجلد';

  @override
  String projectFolderPathHint(String directory) {
    return '$directory/my-app';
  }

  @override
  String get projectFolderOpenAction => 'فتح';

  @override
  String projectFolderCreateSubtitle(String directory) {
    return 'في $directory على هذا الجهاز';
  }

  @override
  String get projectFolderOpenSubtitle => 'أدخل المسار الكامل لمجلد على الخادم';

  @override
  String get globalSessionsTitle => 'جميع الجلسات';

  @override
  String get globalSessionsSearchLabel => 'البحث في عناوين الجلسات';

  @override
  String get globalSessionsSearchHint => 'في كل مجلدات هذا الخادم';

  @override
  String get globalSessionsIncludeArchived => 'تضمين المؤرشفة';

  @override
  String get globalSessionsArchivedShort => 'مؤرشفة';

  @override
  String get globalSessionsAllFolders => 'جميع المجلدات';

  @override
  String get globalSessionsUnknownLocation => 'موقع غير معروف';

  @override
  String globalSessionsSummary(String count, int folders) {
    return 'الجلسات: $count · المجلدات: $folders';
  }

  @override
  String globalSessionsSummaryOneFolder(String count) {
    return 'الجلسات: $count في مجلد واحد';
  }

  @override
  String globalSessionsFilteredSummary(int count, String total) {
    return 'الجلسات المعروضة: $count من $total';
  }

  @override
  String get globalSessionsEmptyTitle => 'لا جلسات بعد';

  @override
  String get globalSessionsEmptyMessage =>
      'ستظهر هنا الجلسات من كل مجلدات هذا الخادم.';

  @override
  String get globalSessionsNoMatchTitle => 'لا جلسات مطابقة';

  @override
  String get globalSessionsNoMatchMessage =>
      'جرّب البحث بعنوان أقصر أو تضمين الجلسات المؤرشفة.';

  @override
  String get globalSessionsRefresh => 'تحديث';

  @override
  String get globalSessionsLoadMoreFailed => 'تعذّر تحميل المزيد من الجلسات';

  @override
  String get globalSessionsOpen => 'فتح';

  @override
  String get globalSessionsContinueHere => 'المتابعة هنا';

  @override
  String get globalSessionsActions => 'إجراءات الجلسة';

  @override
  String get globalSessionsWorking => 'قيد التنفيذ';

  @override
  String get globalSessionsUntitled => 'جلسة بلا عنوان';

  @override
  String get workspaceNewSession => 'جلسة جديدة';

  @override
  String get workspaceIsolatedTask => 'مهمة معزولة';

  @override
  String get workspaceAllSessions => 'جميع الجلسات';

  @override
  String get workspaceDismissNotice => 'تجاهل';

  @override
  String get workspaceManageProject => 'إدارة المشروع';

  @override
  String get workspaceManageProjectHint =>
      'تبديل المشروع، وأشجار العمل، وحالة المشروع';

  @override
  String get workspaceManage => 'إدارة';

  @override
  String get reviewCopiedFile => 'تم نسخ الملف المحدّث';

  @override
  String get reviewCopiedPatch => 'تم نسخ الرقعة';

  @override
  String get reviewCopyFailed => 'تعذّر النسخ. أعد المحاولة.';

  @override
  String get reviewCopyFile => 'نسخ الملف المحدّث';

  @override
  String get reviewCopyPatch => 'نسخ الرقعة';

  @override
  String get reviewNoChanges => 'لا تغييرات';

  @override
  String get reviewEmptyDiff => 'لا محتوى للفروق';

  @override
  String get reviewHideContext => 'إخفاء السياق المكشوف';

  @override
  String get reviewAdded => 'مضاف';

  @override
  String get reviewRemoved => 'محذوف';

  @override
  String get reviewUnchanged => 'دون تغيير';

  @override
  String get reviewPatchNote => 'ملاحظة الرقعة';

  @override
  String reviewShowNext(int count) {
    return 'إظهار الأسطر التالية: $count';
  }

  @override
  String reviewShowPrevious(int count, int remaining) {
    return 'إظهار الأسطر السابقة: $count (المخفية: $remaining)';
  }

  @override
  String reviewMissingContext(int count) {
    return 'أسطر دون تغيير غير مضمّنة في الرقعة: $count';
  }

  @override
  String reviewCounts(int added, int removed) {
    return 'المضاف: $added، المحذوف: $removed';
  }

  @override
  String reviewLineDescription(String kind, int number, String text) {
    return '$kind، السطر $number: $text';
  }

  @override
  String reviewNoteDescription(String kind, String text) {
    return '$kind: $text';
  }

  @override
  String settingsDiscoveryNewChatsModel(String model) {
    return 'المحادثات الجديدة: $model';
  }

  @override
  String get onboardingValueTitle => 'واصل تقدّم عملك.';

  @override
  String get onboardingValueBody =>
      'اطلب تغييرًا من وكيل البرمجة، وراجع النتيجة، وتابع من حيث توقفت.';

  @override
  String get onboardingConnect => 'الاتصال بخادم';

  @override
  String get onboardingDemoNote => 'جلسة محاكاة. لا تحتاج إلى خادم.';

  @override
  String get onboardingMoreSetup => 'المزيد من خيارات الإعداد';

  @override
  String get onboardingPrivateNetwork => 'الوصول إلى خادم عبر شبكتك الخاصة';

  @override
  String get onboardingRunOnPhone => 'تشغيل OpenCode على هذا الهاتف';

  @override
  String get onboardingTermuxNote => 'إعداد Termux خطوة بخطوة';

  @override
  String get onboardingSetupGuide => 'دليل الإعداد';

  @override
  String get onboardingSaveConnect => 'حفظ واتصال';

  @override
  String get onboardingSaveChanges => 'حفظ التغييرات';

  @override
  String get onboardingTermuxSetup => 'إعداد Termux';

  @override
  String get activityClearHere => 'لا شيء يحتاج إلى انتباه هنا';

  @override
  String get activityStatusIncomplete => 'الحالة غير مكتملة';

  @override
  String get activityCheckedLocationsClear =>
      'لا شيء يحتاج إليك في المواقع المفحوصة.';

  @override
  String get activityUnknownStatusDetail =>
      'لم تُحمّل طلبات. لا يزال بعض نشاط الخوادم غير معروف.';

  @override
  String get activityCheckAgain => 'التحقق مجددًا';

  @override
  String get activitySavedServers => 'الخوادم المحفوظة';

  @override
  String get activitySelectedLocationsOnly => 'آخر المواقع المحددة فقط';

  @override
  String get activityBackgroundUpdates => 'تحديثات الخلفية';

  @override
  String get activityBackgroundOffDetail => 'متوقفة · اختر متى تبقى متصلًا';

  @override
  String activityPendingCount(int count) {
    return 'المعلّق: $count';
  }

  @override
  String activityUnknownCount(int count) {
    return 'غير المعروف: $count';
  }

  @override
  String get demoTaskTitle => 'جرّب تغييرًا بسيطًا';

  @override
  String get demoTaskInstruction =>
      'أرسل الطلب النموذجي أدناه، ثم راجع التعديل المقترح.';

  @override
  String get reviewTitle => 'مراجعة';

  @override
  String get modelChoiceProvidersTitle => 'مزوّدو خدمة لم يُحمّلوا';

  @override
  String modelChoiceProvidersSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم يُحمّل $count مزوّد خدمة مسجّل الدخول. عرض التفاصيل',
      many: 'لم يُحمّل $count مزوّد خدمة مسجّل الدخول. عرض التفاصيل',
      few: 'لم يُحمّل $count مزوّدي خدمة مسجّلي الدخول. عرض التفاصيل',
      two: 'لم يُحمّل مزوّدا خدمة مسجّلان الدخول. عرض التفاصيل',
      one: 'لم يُحمّل مزوّد خدمة واحد مسجّل الدخول. عرض التفاصيل',
      zero: 'لا يوجد مزوّد خدمة مسجّل الدخول بانتظار التحميل. عرض التفاصيل',
    );
    return '$_temp0';
  }

  @override
  String get modelChoiceReloadProviders => 'إعادة تحميل مزوّدي الخدمة';

  @override
  String get modelChoiceStagedAgentHint => 'يُطبّق مع اختيارك للنموذج';

  @override
  String get modelChoiceAgentTitle => 'اختيار وكيل';

  @override
  String get modelChoiceDone => 'تم';

  @override
  String get modelChoicePartialSaveError =>
      'حُفظ النموذج. لم يُؤكَّد اختيار الوكيل. أعد المحاولة.';

  @override
  String get modelChoiceModelSaveError =>
      'تعذّر تأكيد اختيار النموذج. تحقّق من اختيارك وأعد المحاولة.';

  @override
  String get workIdle => 'خامل';

  @override
  String get workStartedInBackground => 'بدأ في الخلفية';

  @override
  String get workRunInBackground => 'تشغيل في الخلفية';

  @override
  String get workBackgroundPending => 'جارٍ طلب العمل في الخلفية…';

  @override
  String get workBackgroundRequested =>
      'طُلب العمل في الخلفية. ستُحدّث الحالة عندما يبلّغ عنها الخادم.';

  @override
  String get workBackgroundUnavailable =>
      'لم يؤكد هذا الخادم دعم نقل العمل إلى الخلفية.';

  @override
  String get workBackgroundEligible =>
      'يتاح التشغيل في الخلفية عندما تمنع مهمة وكيل أو أمر مدعوم متابعة هذه المحادثة.';

  @override
  String get workBackgroundAutomatic =>
      'اطلب من وكيلك تفويض العمل في الخلفية. تعود النتائج إلى هذه المحادثة تلقائيًا.';

  @override
  String get oc2DiscoveryConnect => 'الاتصال بـ OpenCode 2';

  @override
  String get oc2DiscoveryEditorTitle => 'OpenCode 2';

  @override
  String get oc2DiscoveryExisting => 'استخدم خادمًا يعمل بالفعل.';

  @override
  String get oc2DiscoveryTypes => 'OpenCode 1 أو 2';

  @override
  String get oc2DiscoveryAutodetect => 'يكتشف OpenCode 1 أو 2 تلقائيًا.';

  @override
  String get oc2DiscoveryPhone => 'إعداد OpenCode 1 أو 2 على هذا الهاتف.';

  @override
  String setupSwitchUse(String runtime) {
    return 'تجربة $runtime';
  }

  @override
  String setupSwitchConfirmTitle(String runtime) {
    return 'التبديل إلى $runtime؟';
  }

  @override
  String get setupSwitchConfirmDetail =>
      'يوقف خادم هذا الهاتف والمهام الجارية. تبقى المحادثات وإعدادات مزوّدي الخدمة وبيانات الاعتماد منفصلة؛ بينما تُشارك ملفات المشروع وإعداداته. يمكنك العودة إلى الإصدار السابق.';

  @override
  String get setupSwitchConfirm => 'تبديل الإصدار';

  @override
  String setupSwitchInstalled(String runtime) {
    return 'على هذا الهاتف: $runtime';
  }

  @override
  String get setupSwitchPending =>
      'لم يكتمل تبديل بيئة التشغيل. أعد محاولة تشغيل البيئة المحددة أو ارجع إلى السابقة. تُحفظ بيانات بيئات التشغيل لديك.';

  @override
  String setupSwitchReturn(String runtime) {
    return 'العودة إلى $runtime';
  }

  @override
  String setupSwitchRetry(String runtime) {
    return 'إعادة محاولة $runtime';
  }

  @override
  String get setupSwitchInProgressHint =>
      'يمكنك مغادرة هذه الشاشة والعودة للتحقق من التقدم.';

  @override
  String get setupSwitchPreparing => 'جارٍ تجهيز تبديل بيئة التشغيل…';

  @override
  String get setupSwitchFailed =>
      'تعذّر إكمال تبديل بيئة التشغيل. افحص مخرجات الإعداد، ثم أعد المحاولة أو ارجع إلى بيئة التشغيل السابقة.';

  @override
  String setupSwitchConnect(String runtime) {
    return 'الاتصال بـ $runtime';
  }

  @override
  String get setupSwitchLegacyTwo =>
      'يحتفظ تثبيت OpenCode 2 هذا ببياناته الحالية. لا يتاح تبديله إلى OpenCode 1.';

  @override
  String setupSwitchProfileName(String runtime) {
    return 'هذا الهاتف · $runtime';
  }

  @override
  String get setupSwitchReady =>
      'بيئة التشغيل المحلية جاهزة. اتصالك البعيد الحالي لم يتغيّر.';

  @override
  String get setupSwitchMissingCredential =>
      'بيانات الاعتماد المحفوظة لبيئة التشغيل السابقة غير متاحة. تبقى بياناتها محفوظة؛ استعد الملف الشخصي المحفوظ قبل العودة.';

  @override
  String get setupSwitchOwnDescription =>
      'اتصل بخادم OpenCode 1 أو OpenCode 2 موجود باستخدام عنوانه.';

  @override
  String setupSwitchProgressTitle(String runtime) {
    return 'جارٍ التبديل إلى $runtime';
  }

  @override
  String get setupSwitchDataNotice =>
      'يحتفظ كل إصدار بمحادثاته وإعدادات مزوّدي الخدمة الخاصة به. تُشارك ملفات المشروع وإعدادات المشروع.';

  @override
  String get setupSwitchHelp => 'مساعدة الإعداد';

  @override
  String get setupSwitchReadyToConnect => 'جاهز للاتصال';

  @override
  String get setupSwitchStopped => 'جاهز للتشغيل';

  @override
  String get setupSwitchAttention => 'يحتاج إلى انتباه';

  @override
  String get setupSwitchLocalRuntime => 'على هذا الهاتف';

  @override
  String e7ConnectionFailure1(int attempts) {
    return 'عدد المحاولات: $attempts. لن تؤدي إعادة المحاولة إلى تشغيل خادم متوقف.';
  }

  @override
  String get e7ConnectionFailure2 => 'يلزم رمز اتصال';

  @override
  String get e7ConnectionFailure3 =>
      'يتطلب خادم Codex هذا رمز اتصال قبل أن يتمكن التطبيق من الاتصال به.';

  @override
  String get e7ConnectionFailure4 =>
      'افتح إعدادات الخادم وأدخل رمز اتصال Codex.';

  @override
  String get e7ConnectionFailure5 => 'رُفض رمز الاتصال';

  @override
  String get e7ConnectionFailure6 =>
      'استجاب خادم Codex، لكنه لم يقبل رمز الاتصال المحفوظ.';

  @override
  String get e7ConnectionFailure7 =>
      'افتح إعدادات الخادم وأدخل رمز اتصال Codex ساريًا.';

  @override
  String get e7ConnectionFailure8 => 'خدمة استقبال اتصالات Codex غير متاحة';

  @override
  String get e7ConnectionFailure9 => 'تعذّر الوصول إلى نقطة اتصال Codex';

  @override
  String e7ConnectionFailure10(String hostLabel, int port) {
    return 'يشير $hostLabel:$port إلى خدمة استقبال اتصالات Codex محلية، لكن لم تصل أي استجابة.';
  }

  @override
  String e7ConnectionFailure11(String hostLabel, int port) {
    return 'لم تصل أي استجابة من نقطة اتصال Codex البعيدة $hostLabel:$port.';
  }

  @override
  String get e7ConnectionFailure12 =>
      'شغّل خدمة استقبال اتصالات Codex على هذا الجهاز.';

  @override
  String get e7ConnectionFailure13 =>
      'إذا كان الاتصال عبر نفق، فأبقِ النفق قيد التشغيل وتحقّق من نقطة اتصاله المحلية.';

  @override
  String get e7ConnectionFailure14 =>
      'استخدم نقطة اتصال Codex عبر wss:// أو نفقًا آمنًا نشطًا.';

  @override
  String get e7ConnectionFailure15 =>
      'تأكّد من إمكانية الوصول إلى خدمة استقبال اتصالات Codex البعيدة من هذا الجهاز.';

  @override
  String get e7ConnectionFailure16 => 'رُفضت كلمة المرور';

  @override
  String get e7ConnectionFailure17 =>
      'استجاب الخادم، لكنه لم يقبل كلمة المرور المحفوظة. يحدث هذا عند إعادة تشغيل الخادم بكلمة مرور جديدة.';

  @override
  String get e7ConnectionFailure18 =>
      'شغّل opencode2 pair على الكمبيوتر والصق الرمز الجديد.';

  @override
  String get e7ConnectionFailure19 =>
      'إذا ضبطت OPENCODE_SERVER_PASSWORD يدويًا، فانسخه مجددًا.';

  @override
  String get e7ConnectionFailure20 => 'الشهادة غير موثوقة';

  @override
  String get e7ConnectionFailure21 =>
      'الخادم موجود، لكن هذا الجهاز لا يثق بشهادة HTTPS الخاصة به، لذلك رفض التطبيق إرسال كلمة المرور.';

  @override
  String get e7ConnectionFailure22 =>
      'استخدم شهادة من جهة موثوقة، أو عنوان Tailscale Serve.';

  @override
  String get e7ConnectionFailure23 =>
      'إذا كانت الشهادة موقّعة ذاتيًا، فثبّتها على هذا الجهاز أولًا.';

  @override
  String get e7ConnectionFailure24 => 'لا خدمة تستقبل الاتصالات على هذا الجهاز';

  @override
  String e7ConnectionFailure25(String hostLabel, int port) {
    return 'يعني $hostLabel:$port أن الخادم يفترض أن يعمل على هذا الجهاز، أو يُتاح عبر نفق ينتهي هنا. لم يستجب أي منهما.';
  }

  @override
  String get e7ConnectionFailure26 =>
      'هل تشغّل OpenCode في Termux؟ افتح Termux وتأكّد من أن الخادم ما زال قيد التشغيل.';

  @override
  String get e7ConnectionFailure27 =>
      'هل تستخدم adb reverse أو إعادة توجيه SSH؟ تأكّد من أن النفق ما زال متصلًا، ثم أعد المحاولة.';

  @override
  String get e7ConnectionFailure28 =>
      'هل تريد الاتصال بكمبيوتر آخر؟ غيّر عنوان الخادم إلى عنوان HTTPS الخاص به أو أعد الاقتران.';

  @override
  String get e7ConnectionFailure29 => 'لم يستجب الخادم في الوقت المحدد';

  @override
  String e7ConnectionFailure30(String hostLabel) {
    return 'توجد خدمة على $hostLabel، لكنها لم تستجب. تكون المشكلة عادةً في الشبكة بين الجهازين، لا في الخادم.';
  }

  @override
  String get e7ConnectionFailure31 =>
      'هل أنت متصل بالشبكة نفسها أو بشبكة VPN نفسها (مثل Tailscale) التي يتصل بها الكمبيوتر؟';

  @override
  String e7ConnectionFailure32(int port) {
    return 'هل يحجب جدار حماية أو بوابة تسجيل دخول الشبكة المنفذ $port؟';
  }

  @override
  String get e7ConnectionFailure33 => 'تعذّر الوصول إلى الخادم';

  @override
  String e7ConnectionFailure34(String hostLabel, int port) {
    return 'لم تصل أي استجابة من $hostLabel:$port. إما أن الخادم متوقف، أو أن هذا الجهاز لا يستطيع الوصول إلى ذلك العنوان.';
  }

  @override
  String get e7ConnectionFailure35 =>
      'هل ما زال opencode serve قيد التشغيل على الكمبيوتر؟';

  @override
  String get e7ConnectionFailure36 =>
      'هل أنت متصل بالشبكة نفسها أو بشبكة VPN نفسها التي يتصل بها الكمبيوتر؟';

  @override
  String get e7ConnectionFailure37 =>
      'هل تغيّر العنوان؟ أعد الاقتران للحصول على العنوان الجديد.';

  @override
  String get e7ConnectionFailure38 => 'استجاب الخادم بخطأ';

  @override
  String get e7ConnectionFailure39 =>
      'الخادم قيد التشغيل، لكنه أبلغ عن خلل في حالته. سيوضح سجله السبب.';

  @override
  String get e7ConnectionFailure40 => 'أعد تشغيل opencode serve وراقب مخرجاته.';

  @override
  String get e7ConnectionFailure41 =>
      'تأكّد من أن هذا التطبيق يدعم إصدار الخادم.';

  @override
  String get e7ConnectionFailure42 => 'تعذّر الاتصال';

  @override
  String e7ConnectionFailure43(String hostLabel) {
    return 'فشل الاتصال بـ $hostLabel. التفاصيل أدناه.';
  }

  @override
  String get e7ConnectionFailure44 =>
      'هل خدمة استقبال اتصالات Codex قيد التشغيل، وهل هذا هو العنوان الصحيح؟';

  @override
  String get e7ConnectionFailure45 =>
      'هل opencode serve قيد التشغيل، وهل هذا هو العنوان الصحيح؟';

  @override
  String get e7PermissionAction1 => 'تشغيل أمر في الطرفية';

  @override
  String get e7PermissionAction2 => 'تعديل ملف';

  @override
  String get e7PermissionAction3 => 'قراءة ملف';

  @override
  String get e7PermissionAction4 => 'الوصول إلى مجلد خارجي';

  @override
  String get e7PermissionAction5 => 'المتابعة بعد إخفاقات متكررة';

  @override
  String get e7PermissionAction6 => 'يلزم إذن';

  @override
  String e7PermissionAction7(String permission) {
    return 'استخدام $permission';
  }

  @override
  String get e7GlossaryMcpExplanation =>
      'بروتوكول سياق النموذج (Model Context Protocol). خوادم إضافية صغيرة تمنح الوكيل أدوات أخرى، مثل متصفح أو قاعدة بيانات أو أداة تصميم. تربطها مرة واحدة ويمكن لكل جلسة استخدامها.';

  @override
  String get e7GlossaryWorktreeTerm => 'شجرة العمل';

  @override
  String get e7GlossaryWorktreeExplanation =>
      'نسخة عمل منفصلة من المستودع نفسه. استخدمها عندما تريد أن يجرّب الوكيل شيئًا على فرع خاص به دون المساس بالشيفرة التي تعمل عليها.';

  @override
  String get e7GlossaryProviderExplanation =>
      'الجهة التي تستضيف النموذج، مثل Anthropic أو OpenAI، أو بيئة تشغيل محلية. يحتاج كل منها إلى مفتاح API أو تسجيل دخول خاص به.';

  @override
  String get e7GlossaryContextTerm => 'السياق';

  @override
  String get e7GlossaryContextExplanation =>
      'كل ما يستطيع النموذج الاطلاع عليه الآن: رسائلك، والملفات التي قرأها، ونتائج الأدوات. له حد للحجم. عند امتلائه، تُلخّص الأجزاء الأقدم كي تستمر الجلسة.';

  @override
  String get e7GlossaryAgentTerm => 'الوكيل';

  @override
  String get e7GlossaryAgentExplanation =>
      'مجموعة مسمّاة من التعليمات والأذونات يعمل النموذج وفقًا لها. يستطيع الوكيل الافتراضي قراءة الشيفرة وتعديلها. قد يقتصر غيره على التخطيط أو المراجعة.';

  @override
  String get e7GlossaryReasoningExplanation =>
      'ملاحظات عمل النموذج قبل أن يجيب. تساعدك على فهم سبب اختياره. تُخفى افتراضيًا لإبقاء المحادثة موجزة.';

  @override
  String get e7GlossaryPermissionTerm => 'الإذن';

  @override
  String get e7GlossaryPermissionExplanation =>
      'يسألك الوكيل قبل تشغيل أمر أو تعديل ملف يتجاوز الإذن الممنوح له. يمكنك السماح مرة واحدة، أو دائمًا لما يطابق ذلك النمط.';

  @override
  String get e7GlossaryVariantTerm => 'نمط النموذج';

  @override
  String get e7GlossaryVariantExplanation =>
      'إعداد يوازن بين سرعة النموذج وعمقه، مثل المدة التي يمكنه التفكير خلالها قبل الإجابة.';

  @override
  String get e7GlossaryGotIt => 'فهمت';

  @override
  String e7GlossaryExplain(String term) {
    return '$term. اضغط لعرض الشرح.';
  }

  @override
  String get e7BannerTokenRejected => 'رُفض رمز الاتصال';

  @override
  String get e7BannerPasswordChanged => 'تغيّرت كلمة مرور الخادم';

  @override
  String get e7BannerReconnectPassword =>
      'تغيّرت كلمة مرور الخادم — أعد الاتصال.';

  @override
  String get e7BannerUpdatePassword => 'تحديث كلمة المرور';

  @override
  String get e7BannerLost => 'فُقد الاتصال';

  @override
  String get e7BannerRetrying => 'جارٍ إعادة المحاولة';

  @override
  String get e7BannerDetails => 'التفاصيل';

  @override
  String get e7BannerChangeServer => 'تغيير الخادم';

  @override
  String e7BannerReconnectPasswordNote(String note) {
    return 'تغيّرت كلمة مرور الخادم — أعد الاتصال.\n$note';
  }

  @override
  String e7BannerReconnectingServer(String server) {
    return 'جارٍ إعادة الاتصال بـ $server…';
  }

  @override
  String e7BannerReconnectingServerSemantic(String server) {
    return 'جارٍ إعادة الاتصال بـ $server';
  }

  @override
  String get e7BannerCheckingExplanation =>
      'يبقى المحتوى المعروض متاحًا أثناء فحص OpenCode. تُستأنف التحديثات المباشرة تلقائيًا.';

  @override
  String get e7BannerStaleExplanation =>
      'قد يكون المحتوى المعروض قديمًا حتى يصبح OpenCode متاحًا مجددًا.';

  @override
  String get e7SharedThreeStepsToYourFirstSession => 'ثلاث خطوات لبدء أول جلسة';

  @override
  String get e7SharedOpenCodeRunsOnYourComputerThisApp =>
      'يعمل OpenCode على حاسوبك، وهذا التطبيق هو جهاز التحكم عن بُعد. الاقتران يربط بينهما بأمر واحد، دون كتابة عناوين أو كلمات مرور.';

  @override
  String get e7SharedOnYourComputerRunOneCommand =>
      'على حاسوبك، شغّل أمرًا واحدًا';

  @override
  String get e7SharedInATerminalOnTheComputerWhere =>
      'في طرفية على الحاسوب المثبَّت عليه OpenCode:';

  @override
  String get e7SharedItStartsTheServerAndPrintsA =>
      'يبدأ الخادم ويطبع رمز اقتران، بالإضافة إلى رمز QR يمكنك مسحه.';

  @override
  String get e7SharedScanTheQROrPasteTheCode =>
      'امسح رمز QR أو الصق الرمز في هذا التطبيق';

  @override
  String get e7SharedPasteTheCodeInThisApp => 'الصق الرمز في هذا التطبيق';

  @override
  String get e7SharedOpenServersTapScanAndPointThe =>
      'افتح «الخوادم»، واضغط «مسح» ووجّه الكاميرا نحو رمز QR، أو انسخ الرمز واضغط «لصق رمز الاقتران». سيُملأ العنوان واسم المستخدم وكلمة المرور معًا.';

  @override
  String get e7SharedCopyThePrintedCodeOpenServersAnd =>
      'انسخ الرمز المطبوع، وافتح «الخوادم» واضغط «لصق رمز الاقتران». سيُملأ العنوان واسم المستخدم وكلمة المرور معًا.';

  @override
  String get e7SharedStartTalking => 'ابدأ الحديث';

  @override
  String get e7SharedPickAProjectAndSendYourFirst =>
      'اختر مشروعًا وأرسل رسالتك الأولى. يجري العمل على حاسوبك، ويعرضه هذا التطبيق ويتيح لك توجيهه.';

  @override
  String get e7SharedAdvanced => 'خيارات متقدمة';

  @override
  String get e7SharedHTTPSSSHTunnelsOlderServersTermuxInternals =>
      'HTTPS وأنفاق SSH والخوادم الأقدم وتفاصيل Termux';

  @override
  String get e7SharedHTTPSSSHTunnelsOlderServers =>
      'HTTPS وأنفاق SSH والخوادم الأقدم';

  @override
  String get e7SharedReachAServerOverHTTPSOrA =>
      'الوصول إلى خادم عبر HTTPS أو نفق';

  @override
  String get e7SharedPairingWorksWhenTheAddressTheServer =>
      'يعمل الاقتران عندما يكون العنوان الذي يطبعه الخادم قابلًا للوصول من هذا الجهاز. وإن لم يكن كذلك، فاعرض الخادم عبر وكيل عكسي HTTPS أو نفق مشفّر، ثم أضف عنوان https:// الناتج يدويًا. HTTP البعيد محظور عمدًا.';

  @override
  String get e7SharedOlderServersWithoutPairing => 'الخوادم الأقدم بدون اقتران';

  @override
  String get e7SharedServersStartedWithOpencodeServeDoNot =>
      'الخوادم التي تُشغَّل بالأمر `opencode serve` لا تطبع رمز اقتران. شغّلها على loopback مع كلمة مرور:';

  @override
  String get e7SharedThenAddTheServerManuallyWithUsername =>
      'ثم أضف الخادم يدويًا باسم المستخدم opencode وكلمة المرور تلك.';

  @override
  String get e7SharedOnDeviceViaTermuxAutomated =>
      'على الجهاز عبر Termux (آلي)';

  @override
  String get e7SharedUseTheOnDeviceTermuxCardOn =>
      'استخدم بطاقة «على الجهاز (Termux)» في شاشة الخوادم. يثبّت التطبيق Termux، ويفتح الجسر، ويجهّز opencode، ويشغّل الخادم ويتصل، كل ذلك بإرشاد خطوة بخطوة.';

  @override
  String get e7SharedOnlyTwoTapsNeedYouPersonallyDownloading =>
      'خطوتان فقط تحتاجان إليك شخصيًا: تنزيل حزمة APK الخاصة بـ Termux، ولصق سطر فتح واحد داخل Termux مرة واحدة. كلاهما يفرضه نموذج أمان Android، لا هذا التطبيق.';

  @override
  String get e7SharedPreferManualInsideTermuxRun =>
      'تفضّل الطريقة اليدوية؟ داخل Termux شغّل:';

  @override
  String get e7SharedTheChrootSharesTheNetworkStackSo =>
      'يتشارك chroot مكدّس الشبكة، لذا يعمل http://127.0.0.1:4096 من هذا التطبيق. شغّل `termux-wake-lock` لإبقائه نشطًا.';

  @override
  String get e7SharedSecurityNotes => 'ملاحظات أمنية';

  @override
  String get e7SharedAlwaysSetOPENCODESERVERPASSWORDWhenBinding =>
      'اضبط OPENCODE_SERVER_PASSWORD دائمًا عند الربط خارج localhost.';

  @override
  String get e7SharedPasswordsAreStoredInTheAndroidKeystore =>
      'تُخزَّن كلمات المرور في Android Keystore على هذا الجهاز فقط.';

  @override
  String get e7SharedTheServerCanExecuteCommandsOnIts =>
      'يستطيع الخادم تنفيذ أوامر على مضيفه، فتعامل مع الوصول إليه كما تتعامل مع وصول SSH.';

  @override
  String get e7SharedCopied => 'تم النسخ';

  @override
  String get e7SharedOpenCodeIsReconnectingTryAgain =>
      'يعيد OpenCode الاتصال. حاول مرة أخرى.';

  @override
  String get e7SharedSessionContext => 'سياق الجلسة';

  @override
  String get e7SharedRefreshContext => 'تحديث السياق';

  @override
  String get e7SharedNoContextUsageYet => 'لا يوجد استخدام للسياق بعد';

  @override
  String get e7SharedSendAPromptAndWaitForAn =>
      'أرسل طلبًا وانتظر رد المساعد. سيبلّغ OpenCode بعدها عن استخدام الرموز في هذه الجلسة.';

  @override
  String get e7SharedCurrentModelRequest => 'طلب النموذج الحالي';

  @override
  String get e7SharedEstimatedInputMakeup => 'التركيب التقديري للمدخلات';

  @override
  String get e7SharedSessionTotals => 'إجماليات الجلسة';

  @override
  String get e7SharedUsageComesFromTheLatestCompletedAssistant =>
      'يُؤخذ الاستخدام من آخر رسالة مكتملة للمساعد. التركيب تقدير مبني على نص الطلب والرد والأدوات الظاهر؛ ويشمل «أخرى» تعليمات النظام وتعريفات الأدوات وحمل المزوّد الإضافي.';

  @override
  String get e7SharedModelUnavailable => 'النموذج غير متاح';

  @override
  String get e7SharedContextLimitUnavailable => 'حد السياق غير متاح';

  @override
  String get e7SharedLatestAssistantRequestIncludingCacheActivity =>
      'آخر طلب للمساعد، بما في ذلك نشاط ذاكرة التخزين المؤقت';

  @override
  String get e7SharedContextLimit => 'حد السياق';

  @override
  String get e7SharedUnavailable => 'غير متاح';

  @override
  String get e7SharedMessages => 'الرسائل';

  @override
  String get e7SharedUserAssistant => 'المستخدم / المساعد';

  @override
  String get e7SharedAccumulatedCostReportedByServer =>
      'التكلفة المتراكمة · حسب تقرير الخادم';

  @override
  String get e7SharedAccumulatedCost => 'التكلفة المتراكمة';

  @override
  String get e7SharedSessionTokensReportedByServer =>
      'رموز الجلسة · حسب تقرير الخادم';

  @override
  String get e7SharedUserPrompts => 'طلبات المستخدم';

  @override
  String get e7SharedAssistantText => 'نص المساعد';

  @override
  String get e7SharedToolCallsAndResults => 'استدعاءات الأدوات ونتائجها';

  @override
  String get e7SharedOtherContext => 'سياق آخر';

  @override
  String get e7SharedMove => 'نقل';

  @override
  String get e7SharedSessionLocationChangedCloseAndReopenThis =>
      'تغيّر موقع الجلسة. أغلق هذه الورقة وأعد فتحها.';

  @override
  String get e7SharedOpenCodeIsReconnecting => 'يعيد OpenCode الاتصال.';

  @override
  String get e7SharedTheSessionProjectIsNotAvailableOn =>
      'مشروع الجلسة غير متاح على هذا الخادم.';

  @override
  String get e7SharedLocalProject => 'مشروع محلي';

  @override
  String get e7SharedTheAppCouldNotInspectWorkingChanges =>
      'تعذّر على التطبيق فحص تغييرات العمل. للسلامة، ستتم المتابعة دون نقل التغييرات.';

  @override
  String get e7SharedMoveWithChanges => 'نقل مع التغييرات';

  @override
  String get e7SharedCopyChangesAndMove => 'نسخ التغييرات ثم النقل';

  @override
  String get e7SharedMoveSession => 'نقل الجلسة';

  @override
  String get e7SharedChooseAnotherDirectoryInThisProject =>
      'اختر مجلدًا آخر في هذا المشروع.';

  @override
  String get e7SharedChooseAConnectedWorkspaceOrReturnTo =>
      'اختر مساحة عمل متصلة، أو عُد إلى المشروع المحلي.';

  @override
  String get e7SharedFilterDestinations => 'تصفية الوجهات';

  @override
  String get e7SharedNoOtherDestinationsAreAvailable => 'لا تتوفر وجهات أخرى.';

  @override
  String get e7SharedNoDestinationsMatchThisFilter =>
      'لا توجد وجهات تطابق هذه التصفية.';

  @override
  String get e7SharedCurrent => 'الحالي';

  @override
  String get e7SharedSwitchOrganization => 'تبديل المؤسسة؟';

  @override
  String get e7SharedSwitch => 'تبديل';

  @override
  String get e7SharedSwitchOrganization462 => 'تبديل المؤسسة';

  @override
  String get e7SharedNoSwitchableOpenCodeConsoleOrganizationsWereReturned =>
      'لم تُرجَع أي مؤسسات قابلة للتبديل في OpenCode Console.';

  @override
  String get e7SharedSessionLocationChangedReturnAndReopenRelated =>
      'تغيّر موقع الجلسة. عُد وأعد فتح الجلسات المرتبطة.';

  @override
  String get e7SharedSessionIsNoLongerRelatedToThis =>
      'لم تعد الجلسة مرتبطة بهذه الجلسة.';

  @override
  String get e7SharedSessionLocationChangedReturnAndTryAgain =>
      'تغيّر موقع الجلسة. عُد وحاول مرة أخرى.';

  @override
  String get e7SharedSessionUnavailableOrLocationChangedReturnOr =>
      'الجلسة غير متاحة أو تغيّر موقعها. عُد أو حدّث للمحاولة مرة أخرى.';

  @override
  String get e7SharedCouldNotUpdateThePinReturnAnd =>
      'تعذّر تحديث التثبيت. عُد وحاول مرة أخرى.';

  @override
  String get e7SharedRefreshSubagentSessions => 'تحديث جلسات الوكلاء الفرعيين';

  @override
  String get e7SharedParentSession => 'الجلسة الأصل';

  @override
  String get e7SharedSubagents => 'الوكلاء الفرعيون';

  @override
  String get e7SharedNoSubagentSessionsYet => 'لا توجد جلسات وكلاء فرعيين بعد';

  @override
  String get e7SharedDelegatedWorkWillAppearHereWithoutMixing =>
      'سيظهر العمل المُفوَّض هنا دون خلط الجلسات الفرعية بقائمة محادثاتك الرئيسية.';

  @override
  String get e7SharedOpenCodeHasNotDelegatedWorkFromThis =>
      'لم يفوّض OpenCode أي عمل من هذه الجلسة.';

  @override
  String get e7SharedUnpinSession => 'إلغاء تثبيت الجلسة';

  @override
  String get e7SharedPinSession => 'تثبيت الجلسة';

  @override
  String get e7SharedLinkBlockedThisAppMayOpenOnly =>
      'تم حظر الرابط. لا يفتح هذا التطبيق سوى عناوين https:// أو عناوين http:// بعد التأكيد.';

  @override
  String get e7SharedOpenInsecureHTTPLink => 'فتح رابط HTTP غير آمن؟';

  @override
  String get e7SharedOpenExternalLink => 'فتح رابط خارجي؟';

  @override
  String get e7SharedHost => 'المضيف';

  @override
  String get e7SharedHTTPIsNotEncryptedOtherDevicesOn =>
      'HTTP غير مشفّر. قد تتمكن أجهزة أخرى على الشبكة من قراءة ما ترسله وتستقبله أو تغييره.';

  @override
  String get e7SharedOpenHTTPLink => 'فتح رابط HTTP';

  @override
  String get e7SharedOpenLink => 'فتح الرابط';

  @override
  String get e7SharedNoAppCouldOpenThisLink =>
      'لم يتمكن أي تطبيق من فتح هذا الرابط.';

  @override
  String get e7SharedRequired => 'مطلوب';

  @override
  String get e7SharedDoesNotMatchTheExpectedFormat =>
      'لا يطابق التنسيق المتوقع';

  @override
  String get e7SharedEnterAWholeNumber => 'أدخل عددًا صحيحًا';

  @override
  String get e7SharedEnterANumber => 'أدخل رقمًا';

  @override
  String get e7SharedDismissThisRequest => 'تجاهل هذا الطلب؟';

  @override
  String get e7SharedTheAgentContinuesWithoutYourAnswers =>
      'سيواصل الوكيل دون إجاباتك.';

  @override
  String get e7SharedAskedByAnMCPServer => 'سؤال من خادم MCP';

  @override
  String get e7SharedAskedByTheAgentInThisSession =>
      'سؤال من الوكيل في هذه الجلسة';

  @override
  String get e7SharedInputRequested => 'مطلوب إدخال';

  @override
  String get e7SharedOther => 'أخرى…';

  @override
  String get e7SharedYourAnswer => 'إجابتك';

  @override
  String get e7SharedAddYourOwn => 'أضف إجابتك';

  @override
  String get e7SharedAddAnswer => 'إضافة إجابة';

  @override
  String get e7SharedThisServerSentALinkThisApp =>
      'أرسل هذا الخادم رابطًا لن يفتحه هذا التطبيق.';

  @override
  String get e7SharedSendAnswers => 'إرسال الإجابات';

  @override
  String get e7SharedRecommended => 'موصى به';

  @override
  String e7SharedDetail307(int step) {
    return 'الخطوة $step من 3';
  }

  @override
  String e7SharedDetail381(String percent) {
    return 'استُخدم $percent بالمئة من السياق';
  }

  @override
  String e7SharedDetail385(String count, String limit) {
    return '$count من $limit رمزًا';
  }

  @override
  String e7SharedDetail386(String count) {
    return '$count رمزًا · الحد غير متاح';
  }

  @override
  String e7SharedDetail409(String error) {
    return 'تعذّر التحديث: $error';
  }

  @override
  String e7SharedDetail428(String destination) {
    return 'تم النقل إلى $destination';
  }

  @override
  String get e7SharedDetail429 => 'نقل الجلسة؟';

  @override
  String e7SharedDetail430(int count, String action) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يوجد $count ملف متغيّر.',
      many: 'يوجد $count ملفًا متغيّرًا.',
      few: 'توجد $count ملفات متغيّرة.',
      two: 'يوجد ملفان متغيّران.',
      one: 'يوجد ملف متغيّر واحد.',
      zero: 'لا توجد ملفات متغيّرة.',
    );
    String _temp1 = intl.Intl.selectLogic(action, {
      'move': 'تُنقل',
      'other': 'تُنسخ',
    });
    return '$_temp0 اختر ما إذا كانت تغييرات العمل تلك يجب أن $_temp1 مع الجلسة.';
  }

  @override
  String e7SharedDetail432(String destination) {
    return 'المتابعة إلى $destination؟';
  }

  @override
  String get e7SharedDetail435 => 'النقل فقط';

  @override
  String e7SharedDetail456(String organization) {
    return 'سيُعاد تحميل النماذج والمزوّدين باستخدام $organization.';
  }

  @override
  String e7SharedDetail460(String organization) {
    return 'تم التبديل إلى $organization';
  }

  @override
  String e7SharedDetail514(String error) {
    return 'فشل التحديث: $error';
  }

  @override
  String e7SharedDetail517(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة مفوَّضة · افتح أي نسخة محادثة مباشرة.',
      many: '$count جلسة مفوَّضة · افتح أي نسخة محادثة مباشرة.',
      few: '$count جلسات مفوَّضة · افتح أي نسخة محادثة مباشرة.',
      two: 'جلستان مفوَّضتان · افتح أي نسخة محادثة مباشرة.',
      one: 'جلسة مفوَّضة واحدة · افتح أي نسخة محادثة مباشرة.',
      zero: 'لا توجد جلسات مفوَّضة.',
    );
    return '$_temp0';
  }

  @override
  String e7SharedDetail518(int position, int total) {
    return '$position من $total';
  }

  @override
  String e7SharedDetail699(String error) {
    return 'تعذّر فتح الرابط: $error';
  }

  @override
  String e7SharedDetail714(int count) {
    return 'يجب ألا يقل عن $count حرفًا';
  }

  @override
  String e7SharedDetail715(int count) {
    return 'يجب ألا يزيد عن $count حرفًا';
  }

  @override
  String e7SharedDetail721(String minimum, String maximum) {
    return 'يجب أن يكون بين $minimum و$maximum';
  }

  @override
  String e7SharedDetail722(String minimum) {
    return 'يجب ألا يقل عن $minimum';
  }

  @override
  String e7SharedDetail723(String maximum) {
    return 'يجب ألا يزيد عن $maximum';
  }

  @override
  String e7SharedDetail725(int count) {
    return 'اختر $count على الأقل';
  }

  @override
  String e7SharedDetail726(int count) {
    return 'اختر $count على الأكثر';
  }

  @override
  String e7SharedDetail753(int minimum, int maximum) {
    return 'اختر $minimum–$maximum';
  }

  @override
  String e7SharedDetail754(int count) {
    return 'اختر $count على الأقل';
  }

  @override
  String e7SharedDetail755(int count) {
    return 'اختر حتى $count';
  }

  @override
  String e7SharedDetail756(String range, int count) {
    return '$range · تم تحديد $count';
  }

  @override
  String e7SharedDetail764(String host) {
    return 'يفتح $host في متصفحك';
  }

  @override
  String e7SharedDetail765(String field) {
    return 'أرسل هذا الخادم نوع حقل لا يفهمه هذا التطبيق (\"$field\").';
  }

  @override
  String get e7LocaleUiLanguage => 'اللغة';

  @override
  String get e7LocaleUiEnglish => 'English';

  @override
  String get e7LocaleUiArabic => 'العربية';

  @override
  String get e7LocaleUiSystem => 'استخدام لغة النظام';

  @override
  String get e7LocaleUiClose => 'إغلاق';

  @override
  String get e7LocaleUiDescription =>
      'اختر لغة التطبيق. تبقى رسائل الخادم والنصوص التي تكتبها بلغتها الأصلية.';

  @override
  String get e7LocaleUiSaving => 'جارٍ حفظ اللغة…';

  @override
  String get e7LocaleUiSaveFailed =>
      'تعذّر حفظ اللغة. لا يزال اختيارك السابق مفعّلًا. اختر لغة للمحاولة مجددًا.';

  @override
  String get e7LocaleUiStarting => 'جارٍ بدء OpenCode…';

  @override
  String get e7LocaleUiStartFailed => 'تعذّر بدء OpenCode';

  @override
  String get e7LocaleUiUnknownStartupError => 'خطأ غير معروف عند بدء التشغيل';

  @override
  String get e7LocaleUiRetry => 'حاول مجددًا';

  @override
  String get e7LocaleUiNewSession => 'جلسة جديدة';

  @override
  String get e7LocaleUiNewSessionHint => 'ابدأ محادثة في المشروع الحالي';

  @override
  String get e7LocaleUiWorkspace => 'مساحة العمل';

  @override
  String get e7LocaleUiWorkspaceHint => 'الجلسات الأخيرة والمشروع الحالي';

  @override
  String get e7LocaleUiFiles => 'الملفات';

  @override
  String get e7LocaleUiFilesHint => 'تصفّح شجرة ملفات المشروع';

  @override
  String get e7LocaleUiActivity => 'النشاط';

  @override
  String get e7LocaleUiActivityHint => 'الأذونات والأسئلة والنماذج';

  @override
  String get e7LocaleUiMore => 'المزيد';

  @override
  String get e7LocaleUiMoreHint => 'النماذج ومزوّدو الخدمة والطرفية والإعدادات';

  @override
  String get e7LocaleUiSettings => 'الإعدادات';

  @override
  String get e7LocaleUiKeyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get e7LocaleUiRefreshSessions => 'تحديث الجلسات';

  @override
  String get e7LocaleUiDiagnostics => 'التشخيص';

  @override
  String get e7LocaleUiDiagnosticsHint => 'الأخطاء الأخيرة وتفاصيل الاتصال';

  @override
  String get e7LocaleUiCommandLauncher => 'قائمة الأوامر';

  @override
  String get e7LocaleUiFindSurface => 'البحث في هذه الصفحة';

  @override
  String get e7LocaleUiDestinations => 'مساحة العمل، الملفات، النشاط، المزيد';

  @override
  String get e7LocaleUiTerminal => 'الطرفية';

  @override
  String get e7LocaleUiCloseScreen => 'إغلاق هذه الصفحة';

  @override
  String get e7LocaleUiSendPrompt => 'إرسال الطلب';

  @override
  String get e7LocaleUiCopyTranscript => 'نسخ النص المحدّد من المحادثة';

  @override
  String get e7LocaleUiRecentModel =>
      'النموذج الأخير التالي / السابق في هذه المحادثة';

  @override
  String get e7LocaleUiThisList => 'هذه القائمة';

  @override
  String get e7LocaleUiCloseOverlay => 'إغلاق لوحة أو مربع حوار أو قائمة';

  @override
  String get e7LocaleUiContextActions => 'إجراءات الرسائل والملفات والجلسات';

  @override
  String get e7LocaleUiTypeCommand => 'اكتب أمرًا…';

  @override
  String get e7LocaleUiNoCommand => 'لا يوجد أمر مطابق';

  @override
  String get e7LocaleUiContextKeys => 'نقرة بالزر الأيمن / Shift + F10 / Menu';

  @override
  String get e7LocaleUiShareScopeChanged => 'تغيّر نطاق الجلسة المشتركة';

  @override
  String get e7LocaleUiConnectionChanged => 'تغيّر الاتصال.';

  @override
  String get e7AppearanceFollowAndroid => 'اتباع إعداد Android';

  @override
  String get e7AppearanceFollowSystem => 'اتباع إعداد النظام';

  @override
  String get e7AppearanceLight => 'فاتح';

  @override
  String get e7AppearanceDark => 'داكن';

  @override
  String get e7AppearanceFollowPhoneDescription =>
      'مطابقة إعداد المظهر الفاتح أو الداكن لهذا الهاتف';

  @override
  String get e7AppearanceFollowDeviceDescription =>
      'مطابقة إعداد المظهر الفاتح أو الداكن لهذا الجهاز';

  @override
  String get e7AppearanceLightDescription => 'استخدام مساحة العمل الفاتحة';

  @override
  String get e7AppearanceDarkDescription => 'استخدام مساحة العمل الداكنة';

  @override
  String get e7AppearanceTitle => 'المظهر';

  @override
  String get e7AppearancePreviewHint =>
      'عاين المظهر أولاً. لن يتغيّر إلا عند تطبيقه.';

  @override
  String get e7AppearanceDynamicUnavailable =>
      'ألوان Material You غير متاحة على هذا الجهاز.';

  @override
  String e7AppearanceUsesMode(String mode) {
    return 'يبقى إعداد المظهر الفاتح أو الداكن كما هو: $mode.';
  }

  @override
  String get e7AppearanceSaveFailed =>
      'تعذّر حفظ المظهر. لم يتغيّر إعدادك السابق. حاول مجددًا.';

  @override
  String get e7AppearanceSaving => 'جارٍ الحفظ…';

  @override
  String get e7AppearanceApply => 'تطبيق';

  @override
  String get e7AppearanceCurrent => 'المظهر الحالي';

  @override
  String get e7AppearanceClose => 'إغلاق';

  @override
  String get e7AppearancePreviewTitle => 'النص وعناصر التحكّم';

  @override
  String get e7AppearancePreviewBody =>
      'شاهد تناسق النص والشيفرة والإجراءات المحدّدة.';

  @override
  String get e7AppearanceSelection => 'خيار محدّد';

  @override
  String get e7AppearanceTryControl => 'جرّب التحكّم';

  @override
  String get e7AppearanceSampleHint =>
      'تغيّر عناصر التحكّم التجريبية هذه المعاينة فقط.';

  @override
  String get e7SettingsUi1 => 'الخادم';

  @override
  String get e7SettingsUi2 => 'إعدادات البرمجة الافتراضية';

  @override
  String get e7SettingsUi3 => 'الإشعارات والخلفية';

  @override
  String get e7SettingsUi5 => 'الخصوصية والأذونات';

  @override
  String get e7SettingsUi6 => 'التشخيص';

  @override
  String get e7SettingsUi7 => 'حول التطبيق';

  @override
  String get e7SettingsUi8 => 'قطع الاتصال';

  @override
  String get e7SettingsUi9 => 'خادم OpenCode';

  @override
  String get e7SettingsUi11 => 'جارٍ فحص حالة الخادم…';

  @override
  String get e7SettingsUi12 => 'أوقفه Android';

  @override
  String get e7SettingsUi14 => 'مفعّل · يعمل الآن';

  @override
  String get e7SettingsUi15 => 'مفعّل · جارٍ البدء';

  @override
  String get e7SettingsUi16 => 'هذا الخادم';

  @override
  String get e7SettingsUi17 => 'غير معروف';

  @override
  String get e7SettingsUi18 => 'جارٍ إعادة الاتصال بـ OpenCode.';

  @override
  String get e7SettingsUi19 => 'جارٍ إعادة الاتصال بـ OpenCode. حاول مجددًا.';

  @override
  String get e7SettingsUi20 =>
      'تتوقف التحديثات المباشرة وتعود إلى قائمة الخوادم. يواصل الخادم العمل دون تغيير أي شيء عليه.';

  @override
  String get e7SettingsUi21 => 'لا يوجد شيء ينتظر الإرسال.';

  @override
  String get e7SettingsUi22 => 'لم يفعّل Android وضع الخلفية.';

  @override
  String get e7SettingsUi23 => 'أوقف Android الاتصال المباشر';

  @override
  String get e7SettingsUi24 =>
      'تم استنفاد الحد اليومي لمزامنة البيانات في الخلفية، فتوقف الوضع المباشر تلقائيًا. فعّله لإعادة الاتصال؛ يتجدد الحد خلال 24 ساعة.';

  @override
  String get e7SettingsUi25 => 'البقاء متصلاً في الخلفية';

  @override
  String get e7SettingsUi26 =>
      'يواصل تحديث المهام عند إغلاق التطبيق ويُشعرك عندما تتطلب إحداها تدخلك. يستهلك طاقة إضافية ويعرض إشعارًا دائمًا.';

  @override
  String get e7SettingsUi27 => 'استخدام البطارية دون قيود مسموح';

  @override
  String get e7SettingsUi28 => 'السماح باستخدام البطارية دون قيود';

  @override
  String get e7SettingsUi29 =>
      'قد يستمر Android في تطبيق الحد الزمني لخدمة المقدّمة.';

  @override
  String get e7SettingsUi30 =>
      'اختياري. يساعد على إبقاء الاتصال المباشر أثناء وضع السكون. يحدّ Android 15 والإصدارات الأحدث مزامنة البيانات في الخلفية بست ساعات لكل 24 ساعة.';

  @override
  String get e7SettingsUi31 => 'أوقفه Android — اضغط لإعادة التشغيل';

  @override
  String get e7SettingsUi32 => 'يعمل الآن';

  @override
  String get e7SettingsUi34 =>
      'يسمح Android 15 والإصدارات الأحدث بست ساعات من هذا العمل لكل 24 ساعة ثم يوقفه. يعطّل التطبيق المفتاح ويُعلمك عند حدوث ذلك.';

  @override
  String get e7SettingsUi35 => 'الصدفة الافتراضية';

  @override
  String get e7SettingsUi36 =>
      'تستخدمها الطرفيات الجديدة وأوامر الصدفة المتوافقة على خادم OpenCode هذا.';

  @override
  String get e7SettingsUi37 =>
      'للطرفية فقط؛ يستخدم OpenCode بديلاً متوافقًا لأدوات الصدفة.';

  @override
  String get e7SettingsUi38 => 'تم تحديث الصدفة الافتراضية';

  @override
  String get e7SettingsUi39 => 'تلقائي (إعداد الخادم الافتراضي)';

  @override
  String get e7SettingsUi40 => 'اختيار الصدفة غير متاح على خوادم OpenCode 2';

  @override
  String get e7SettingsUi41 => 'جارٍ تحميل الصدف من OpenCode…';

  @override
  String get e7SettingsUi42 => 'النموذج المحدّد';

  @override
  String get e7SettingsUi44 => 'الوكيل المحدّد';

  @override
  String get e7SettingsUi45 => 'تم نسخ أوامر تحديث الخادم';

  @override
  String get e7SettingsUi46 => 'أعد تشغيل OpenCode على الجهاز المضيف';

  @override
  String get e7SettingsUi48 => 'تحديث OpenCode البعيد؟';

  @override
  String get e7SettingsUi49 => 'تغيّر الخادم النشط قبل اكتمال التحديث';

  @override
  String get e7SettingsUi50 => 'تحديث OpenCode المُدار';

  @override
  String get e7SettingsUi51 =>
      'تثبيت أحدث إصدار مستقر للخادم وتحديث النماذج وإعادة التشغيل بأمان ثم إعادة الاتصال.';

  @override
  String get e7SettingsUi52 => 'الإصدار السابق';

  @override
  String get e7SettingsUi53 => 'إصدار غير معروف';

  @override
  String get e7SettingsUi54 => 'تُدار تحديثات الخادم خارجيًا';

  @override
  String get e7SettingsUi55 =>
      'انسخ أوامر الترقية وتحديث النماذج الرسمية لتشغيلها على الجهاز المضيف للخادم.';

  @override
  String get e7SettingsUi56 => 'غير متصل';

  @override
  String get e7SettingsUi57 => 'فحص حالة الخادم';

  @override
  String get e7SettingsUi58 => 'جارٍ الاستعلام عن حالة الخادم';

  @override
  String get e7SettingsUi59 => 'الخادم يعمل جيدًا';

  @override
  String get e7SettingsUi60 => 'حالة الخادم غير متاحة';

  @override
  String get e7SettingsUi61 => 'المصادقة';

  @override
  String get e7SettingsUi62 => 'لم تُحفظ كلمة مرور للخادم';

  @override
  String get e7SettingsUi63 => 'إدارة ملفات تعريف الخوادم';

  @override
  String get e7SettingsUi64 =>
      'إضافة خوادم OpenCode أو تعديلها أو التبديل بينها';

  @override
  String get e7SettingsUi65 => 'التشغيل كخدمة Linux';

  @override
  String get e7SettingsUi66 =>
      'أبقِ OpenCode قيد التشغيل على حاسوبك بعد إغلاق الطرفية؛ انسخ أوامر الإعداد والحالة وإعادة التشغيل والسجلات والتحديث';

  @override
  String get e7SettingsUi67 => 'تحديثات الخادم';

  @override
  String get e7SettingsUi68 => 'رقِّ من الجهاز الذي يشغّل الخادم';

  @override
  String get e7SettingsUi69 => 'فاتح أو داكن';

  @override
  String get e7SettingsUi70 => 'السمة';

  @override
  String get e7SettingsUi71 => 'يتطلب Android 12 أو إصدارًا أحدث';

  @override
  String get e7SettingsUi72 => 'ألوان Material You لهذا الهاتف';

  @override
  String get e7SettingsUi74 => 'الإجراءات المسموح بها دائمًا';

  @override
  String get e7SettingsUi75 =>
      'راجع أذونات OpenCode الدائمة لهذا المشروع أو ألغِها';

  @override
  String get e7SettingsUi76 => 'على هذا الجهاز';

  @override
  String get e7SettingsUi77 => 'مساحة التخزين المستخدمة';

  @override
  String get e7SettingsUi78 => 'حذف الطلبات في قائمة الانتظار';

  @override
  String get e7SettingsUi79 => 'لا يوجد شيء ينتظر الإرسال';

  @override
  String get e7SettingsUi80 => 'حذف الطلبات في قائمة الانتظار؟';

  @override
  String get e7SettingsUi81 => 'تم حذف الطلبات في قائمة الانتظار';

  @override
  String get e7SettingsUi82 =>
      'تعذّر حذف الطلبات في قائمة الانتظار. تحقّق من مساحة تخزين الجهاز وحاول مجددًا.';

  @override
  String get e7SettingsUi83 => 'حذف المسودات';

  @override
  String get e7SettingsUi84 => 'لا يوجد نص محفوظ في محرّر الرسائل';

  @override
  String get e7SettingsUi85 => 'حذف المسودات؟';

  @override
  String get e7SettingsUi86 => 'تم حذف المسودات';

  @override
  String get e7SettingsUi87 =>
      'تعذّر حذف المسودات. تحقّق من مساحة تخزين الجهاز وحاول مجددًا.';

  @override
  String get e7SettingsUi88 => 'تشخيص التطبيق';

  @override
  String get e7SettingsUi89 => 'لا توجد أخطاء مسجّلة';

  @override
  String get e7SettingsUi91 => 'اتصل بحاسوب أو شغّل OpenCode على هذا الهاتف';

  @override
  String get e7SettingsUi92 => 'الخصوصية واستخدام البيانات';

  @override
  String get e7SettingsUi93 =>
      'الخوادم والمزوّدون والصوت والملفات وTermux والتحديثات';

  @override
  String get e7SettingsUi94 => 'تراخيص الصوت ومصادره';

  @override
  String get e7SettingsUi95 =>
      'نماذج Whisper وsherpa-onnx وONNX Runtime وrecord';

  @override
  String get e7SettingsUi96 => 'حول التطبيق وإشعارات المصادر المفتوحة';

  @override
  String get e7SettingsUi97 => 'تفاصيل التطبيق ومكوّناته وإشعارات التراخيص';

  @override
  String e7SettingsDisconnectBody(int queued, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      queued,
      locale: localeName,
      other: '$queued طلب في قائمة الانتظار.',
      many: '$queued طلبًا في قائمة الانتظار.',
      few: '$queued طلبات في قائمة الانتظار.',
      two: 'طلبان في قائمة الانتظار.',
      one: 'طلب واحد في قائمة الانتظار.',
      zero: 'لا توجد طلبات في قائمة الانتظار.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts مسودة غير مرسلة.',
      many: '$drafts مسودة غير مرسلة.',
      few: '$drafts مسودات غير مرسلة.',
      two: 'مسودتان غير مرسلتين.',
      one: 'مسودة واحدة غير مرسلة.',
      zero: 'لا توجد مسودات غير مرسلة.',
    );
    return 'تتوقف التحديثات المباشرة وتعود إلى قائمة الخوادم. يواصل الخادم العمل دون تغيير أي شيء عليه.\n\n$_temp0 $_temp1 تبقى على هذا الجهاز حتى تعيد الاتصال بهذا الخادم.';
  }

  @override
  String e7SettingsDisconnectTitle(String server) {
    return 'قطع الاتصال بـ $server؟';
  }

  @override
  String e7SettingsHealthError(String error) {
    return 'حالة الخادم غير متاحة — $error';
  }

  @override
  String e7SettingsHealthVersion(String version) {
    return 'الخادم يعمل جيدًا · $version';
  }

  @override
  String e7SettingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get e7AppearancePackOpencode => 'أخضر الطرفية، السمة الافتراضية';

  @override
  String get e7AppearancePackCatppuccin =>
      'Mocha وLatte بدرجات البنفسجي الفاتح';

  @override
  String get e7AppearancePackGruvbox => 'مظهر كلاسيكي دافئ بدرجات البرتقالي';

  @override
  String get e7AppearancePackSolarized =>
      'لوحة الألوان الثنائية الكلاسيكية بدرجات الأزرق';

  @override
  String get e7AppearancePackDynamic => 'ألوان Material You لهذا الهاتف';

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
      other: '$queued طلب في قائمة الانتظار',
      many: '$queued طلبًا في قائمة الانتظار',
      few: '$queued طلبات في قائمة الانتظار',
      two: 'طلبان في قائمة الانتظار',
      one: 'طلب واحد في قائمة الانتظار',
      zero: 'لا طلبات في قائمة الانتظار',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts مسودة',
      many: '$drafts مسودة',
      few: '$drafts مسودات',
      two: 'مسودتان',
      one: 'مسودة واحدة',
      zero: 'لا مسودات',
    );
    return '$total من العمل غير المرسل — $_temp0 ($queueBytes) و$_temp1 ($draftBytes). تُحذف الطلبات في قائمة الانتظار بعد $days يومًا.';
  }

  @override
  String e7SettingsQueueDeleteSummary(int count) {
    return 'يحذف كل الطلبات غير المرسلة وعددها $count ومرفقاتها، لكل الخوادم';
  }

  @override
  String e7SettingsQueueDeleteBody(int count) {
    return 'يحذف هذا الإجراء الطلبات غير المرسلة وعددها $count ومرفقاتها، لكل الخوادم. لن تُرسل أبدًا. لا يتأثر أي شيء على الخادم.';
  }

  @override
  String e7SettingsDraftDeleteSummary(int count) {
    return 'يحذف نص محرّر الرسائل المحفوظ في $count جلسة';
  }

  @override
  String e7SettingsDraftDeleteBody(int count) {
    return 'يحذف هذا الإجراء نص محرّر الرسائل المحفوظ في $count جلسة. لا يتأثر أي شيء على الخادم.';
  }

  @override
  String e7SettingsDiagnosticCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خطأ محفوظ في الذاكرة',
      many: '$count خطأً محفوظًا في الذاكرة',
      few: '$count أخطاء محفوظة في الذاكرة',
      two: 'خطآن محفوظان في الذاكرة',
      one: 'خطأ واحد محفوظ في الذاكرة',
      zero: 'لا أخطاء محفوظة في الذاكرة',
    );
    return '$_temp0';
  }

  @override
  String e7SettingsRestartBody(String version, String current) {
    return 'تم تثبيت OpenCode $version، لكن عملية الخادم هذه ما زالت تشغّل $current. أعد تشغيل العملية على الجهاز المضيف؛ سيعيد التطبيق الاتصال ويتحقق من الإصدار الجاري تشغيله.';
  }

  @override
  String e7SettingsUpgradeBody(String target, String server, String current) {
    return 'تثبيت OpenCode $target على $server بطريقة التثبيت المكتشفة على الخادم. تشغّل العملية الحالية $current.\n\nيحافظ التثبيت على بيانات الخادم، لكن يجب إعادة تشغيل عملية OpenCode على الجهاز المضيف لتفعيل الإصدار الجديد.';
  }

  @override
  String e7SettingsInstallVersion(String version) {
    return 'تثبيت $version';
  }

  @override
  String e7SettingsInstalledVersion(String version) {
    return 'تم تثبيت OpenCode $version. أعد تشغيل عملية الخادم لاستخدامه.';
  }

  @override
  String e7SettingsRestartVersion(String version) {
    return 'أعد تشغيل OpenCode لاستخدام $version';
  }

  @override
  String e7SettingsRetryError(String error) {
    return '$error اضغط للمحاولة مجددًا.';
  }

  @override
  String e7SettingsInstalledCurrent(String version, String current) {
    return 'تم تثبيت $version. ما زالت العملية الحالية تشغّل $current.';
  }

  @override
  String e7SettingsUpdateVersion(String version) {
    return 'تحديث OpenCode إلى $version';
  }

  @override
  String e7SettingsCurrentServer(String version) {
    return 'الخادم الحالي: $version. يستخدم مثبّت OpenCode الرسمي؛ يلزم إعادة التشغيل على الجهاز المضيف.';
  }

  @override
  String e7SettingsAuthenticationUser(String user) {
    return 'المصادقة الأساسية مفعّلة باسم $user';
  }

  @override
  String get e7SettingsDetailUi0 => 'تم نسخ التشخيص';

  @override
  String get e7SettingsDetailUi2 => 'تم إرسال التشخيص إلى OpenCode';

  @override
  String get e7SettingsDetailUi3 => 'حذف التشخيص؟';

  @override
  String get e7SettingsDetailUi4 =>
      'يحذف هذا الإجراء كل الأخطاء المسجّلة من ذاكرة العملية.';

  @override
  String get e7SettingsDetailUi5 => 'حذف';

  @override
  String get e7SettingsDetailUi7 => 'خاص حتى ترسله';

  @override
  String get e7SettingsDetailUi8 =>
      'تُحجب البيانات الحساسة من أخطاء التطبيق التي تمت معالجتها وتُحفظ في الذاكرة فقط. لا تُجمع رسائل المحادثات أو محتويات الملفات. لا يُرسل شيء تلقائيًا.';

  @override
  String get e7SettingsDetailUi10 => 'إرسال';

  @override
  String get e7SettingsDetailUi12 => 'لا يقبل هذا الخادم سجلات التطبيق';

  @override
  String get e7SettingsDetailUi13 => 'لا توجد أخطاء مسجّلة للتطبيق';

  @override
  String get e7SettingsDetailUi14 =>
      'تظهر هنا أخطاء Flutter والنظام وبدء التشغيل التي تمت معالجتها أثناء تشغيل التطبيق الحالي.';

  @override
  String get e7SettingsDetailUi16 => 'الإبلاغ عن خلل';

  @override
  String get e7SettingsDetailUi17 => 'الخصوصية';

  @override
  String get e7SettingsDetailUi18 => 'المصادر المفتوحة';

  @override
  String get e7SettingsDetailUi19 => 'حول هذا الإصدار';

  @override
  String get e7SettingsDetailUi20 => 'OpenCode لنظام Android';

  @override
  String get e7SettingsDetailUi21 => 'OpenCode للحاسوب';

  @override
  String get e7SettingsDetailUi22 =>
      'تطبيق محمول للاتصال بخادم OpenCode. يعمل التعرّف على الصوت محليًا بعد تنزيل النماذج الاختيارية.';

  @override
  String get e7SettingsDetailUi23 => 'تطبيق حاسوب للاتصال بخادم OpenCode.';

  @override
  String get e7SettingsDetailUi25 => 'الأدوات';

  @override
  String get e7SettingsDetailUi26 => 'المهارات';

  @override
  String get e7SettingsDetailUi27 => 'المراجع';

  @override
  String get e7SettingsInformationFailed =>
      'تعذّر تحميل معلومات التطبيق. حاول فتح هذه الصفحة مجددًا.';

  @override
  String get e7SettingsAlphaBody =>
      'بُني هذا التطبيق المستقل بمساعدة كبيرة من الذكاء الاصطناعي. أندرويد هو المنصة الأساسية المدعومة. إصدارات الحاسوب تجريبية ولم تُختبر على أجهزة فعلية. أبلغ عن الأعطال للمساعدة في تحسين التطبيق.';

  @override
  String get e7SettingsNonAffiliation =>
      'OpenCode Mobile مشروع مجتمعي مستقل. لم يُنشئه فريق OpenCode الرسمي ولا يتولّى صيانته أو يؤيّده، وليس مرتبطًا به.';

  @override
  String get e7SettingsOriginalLicenses =>
      'تُعرض إشعارات تراخيص الأطراف الثالثة أدناه بلغتها الأصلية.';

  @override
  String e7SettingsDiagnosticSendError(String error) {
    return 'تعذّر إرسال التشخيص: $error';
  }

  @override
  String e7SettingsDiagnosticTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خطأ',
      many: '$count خطأً',
      few: '$count أخطاء',
      two: 'خطآن',
      one: 'خطأ واحد',
      zero: 'لا أخطاء',
    );
    return '$_temp0';
  }

  @override
  String e7SettingsDiagnosticOccurrences(int count) {
    return 'عدد مرات الحدوث: $count';
  }

  @override
  String get e7ProjectProjectsReconnect =>
      'جارٍ إعادة الاتصال بـ OpenCode. حاول مجددًا بعد قليل.';

  @override
  String e7ProjectProjectRenamed(String name) {
    return 'تم تغيير اسم المشروع إلى $name';
  }

  @override
  String e7ProjectProjectRenameFailed(String error) {
    return 'تعذّر تغيير اسم المشروع: $error';
  }

  @override
  String get e7ProjectProjectDefaultDirectory => 'المجلد الافتراضي للخادم';

  @override
  String get e7ProjectProjectSwitchUnavailable =>
      'التبديل بين المشاريع غير متاح';

  @override
  String get e7ProjectProjectSwitchUnavailableDetail =>
      'يستخدم هذا الاتصال المجلد المحدد للمحادثات. افتح مهمة جديدة من مساحة العمل للمتابعة.';

  @override
  String get e7ProjectProjectsTitle => 'المشاريع';

  @override
  String get e7ProjectProjectsRefresh => 'تحديث المشاريع';

  @override
  String get e7ProjectProjectsSearch => 'البحث عن مشروع أو مسار';

  @override
  String get e7ProjectProjectsClearSearch => 'مسح البحث عن المشاريع';

  @override
  String get e7ProjectProjectsOpened => 'المشاريع المفتوحة';

  @override
  String e7ProjectProjectsCount(int shown, int total) {
    return '$shown من $total';
  }

  @override
  String get e7ProjectProjectsEmpty => 'لا توجد مشاريع مفتوحة';

  @override
  String get e7ProjectProjectsEmptyDetail =>
      'تظهر هنا المشاريع المفتوحة على هذا الخادم. اختر مشروعًا للمحادثات والملفات والطرفيات وأدوات البرمجة. أنشئ مجلدًا أو افتحه بمساره من الخيارات أعلاه، أو افتح مشروعًا على خادم OpenCode هذا ثم حدّث القائمة.';

  @override
  String get e7ProjectProjectsNoMatch => 'لا توجد مشاريع مطابقة';

  @override
  String get e7ProjectProjectsNoMatchDetail =>
      'جرّب اسم مشروع أو مسار مجلد على الخادم.';

  @override
  String get e7ProjectProjectsRefreshFailed => 'تعذّر تحديث المشاريع';

  @override
  String e7ProjectProjectWorktrees(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شجرة عمل',
      many: '$count شجرة عمل',
      few: '$count أشجار عمل',
      two: 'شجرتا عمل',
      one: 'شجرة عمل واحدة',
      zero: 'لا توجد أشجار عمل',
    );
    return '$_temp0';
  }

  @override
  String e7ProjectProjectRenameAction(String name) {
    return 'تغيير اسم $name';
  }

  @override
  String get e7ProjectProjectRenameTitle => 'تغيير اسم المشروع';

  @override
  String get e7ProjectProjectNameLabel => 'اسم المشروع';

  @override
  String get e7ProjectProjectNameHint =>
      'امسح الاسم لاستخدام اسم مجلد المشروع.';

  @override
  String get e7ProjectProjectSave => 'حفظ';

  @override
  String get e7ProjectAttentionNoServers => 'لا توجد خوادم محفوظة';

  @override
  String get e7ProjectAttentionNoServersDetail =>
      'أضف خادمًا من قائمة الخوادم ليظهر هنا.';

  @override
  String get e7ProjectAttentionSavedServer => 'خادم محفوظ';

  @override
  String get e7ProjectAttentionSelected => 'الخادم المحدد';

  @override
  String get e7ProjectAttentionInactive => 'خادم غير نشط';

  @override
  String get e7ProjectAttentionCacheSource =>
      'المصدر: البيانات المحلية المخزنة للاتصال المحدد. النطاق: الموقع والمحادثات المحمّلة حاليًا. آخر تحديث: غير معروف.';

  @override
  String get e7ProjectAttentionProfileSource =>
      'المصدر: ملف الخادم المحفوظ فقط. حالة الطلبات التي تحتاج إلى انتباه: غير معروفة. آخر فحص: غير معروف.';

  @override
  String get e7ProjectAttentionPendingUnknown => 'الطلبات المعلّقة: غير معروفة';

  @override
  String e7ProjectAttentionPendingKnown(int count) {
    return 'آخر عدد معروف للطلبات المعلّقة: $count';
  }

  @override
  String get e7ProjectAttentionRunningUnknown => 'المحادثات النشطة: غير معروفة';

  @override
  String e7ProjectAttentionRunningKnown(int count) {
    return 'آخر عدد معروف للمحادثات النشطة أو التي تعيد المحاولة: $count';
  }

  @override
  String get e7ProjectAttentionUnreadUnknown =>
      'المحادثات غير المقروءة: غير معروفة';

  @override
  String e7ProjectAttentionUnreadKnown(int count) {
    return 'آخر عدد معروف للمحادثات غير المقروءة: $count';
  }

  @override
  String get e7ProjectAttentionOpen => 'فتح الخادم';

  @override
  String get e7ProjectAttentionChoose => 'اختيار خادم…';

  @override
  String get e7ProjectMonitorUnsupported =>
      'متابعة الطلبات في الخلفية غير متاحة لهذا الاتصال. افتح المحادثة لمراجعة الطلبات الحالية.';

  @override
  String get readerUiDisconnected => 'الخادم غير متصل.';

  @override
  String get readerUiReconnectingRetry =>
      'يعيد OpenCode الاتصال. حاول مجددًا بعد قليل.';

  @override
  String get readerUiIndicatorsUnavailable =>
      'مؤشرات تغييرات الملفات غير متاحة على هذا الخادم.';

  @override
  String get readerUiIndicatorsFailed => 'تعذّر تحديث مؤشرات تغييرات الملفات.';

  @override
  String get readerUiReconnecting => 'يعيد OpenCode الاتصال.';

  @override
  String get readerUiCommentAdded =>
      'أُضيف تعليق المراجعة. عُد إلى المحادثة للمتابعة.';

  @override
  String get readerUiCommentCopied => 'نُسخ تعليق المراجعة. ألصقه في محادثة.';

  @override
  String get readerUiSearchSymbols => 'البحث عن الرموز';

  @override
  String get readerUiSearchFiles => 'البحث عن الملفات';

  @override
  String get readerUiClearSymbolSearch => 'مسح البحث عن الرموز';

  @override
  String get readerUiClearFileSearch => 'مسح البحث عن الملفات';

  @override
  String get readerUiSelectFile => 'اختر ملفًا لمعاينته';

  @override
  String get readerUiEmptyFolder => 'المجلد فارغ';

  @override
  String get readerUiNoFiles => 'لم يتم العثور على ملفات';

  @override
  String get readerUiPullRefresh => 'اسحب للأسفل لتحديث هذا المجلد.';

  @override
  String get readerUiTryFileName => 'جرّب اسم ملف آخر.';

  @override
  String get readerUiOpenFolder => 'فتح المجلد';

  @override
  String get readerUiAttachPrompt => 'إرفاق بالطلب';

  @override
  String get readerUiAddReference => 'إضافة كمرجع';

  @override
  String get readerUiOpenReview => 'فتح في المراجعة';

  @override
  String get readerUiCopyPath => 'نسخ المسار';

  @override
  String get readerUiWorkspaceSymbols => 'البحث عن رموز مساحة العمل';

  @override
  String get readerUiSymbolsHint =>
      'ابحث عن الأصناف والدوال ودوال الأعضاء والمتغيرات بالاسم.';

  @override
  String get readerUiNoSymbols => 'لم يتم العثور على رموز';

  @override
  String get readerUiSymbolsUnavailable =>
      'جرّب اسمًا آخر. بعض خدمات اللغات لا تدعم البحث عن الرموز في مساحة العمل بأكملها.';

  @override
  String get readerUiReviewAll => 'مراجعة جميع التغييرات';

  @override
  String get readerUiCopied => 'تم النسخ';

  @override
  String get readerUiFiles => 'الملفات';

  @override
  String get readerUiSymbols => 'الرموز';

  @override
  String get readerUiChanges => 'التغييرات';

  @override
  String get readerUiRefreshChanges => 'تحديث التغييرات';

  @override
  String get readerUiCopiedReview => 'تم النسخ من المراجعة';

  @override
  String get readerUiEntireChange => 'تغيير الملف بالكامل';

  @override
  String get readerUiSelectedChange => 'التغيير المحدد';

  @override
  String get readerUiWorkingTree => 'شجرة العمل';

  @override
  String get readerUiSessionScopeHint =>
      'التغييرات المرتبطة بجلسة OpenCode هذه';

  @override
  String get readerUiWorkingScopeHint => 'تغييرات Git الحالية غير المثبّتة';

  @override
  String get readerUiBranchScopeHint => 'التغييرات مقارنة بالفرع الافتراضي';

  @override
  String get readerUiUnified => 'موحّد';

  @override
  String get readerUiSplit => 'جنبًا إلى جنب';

  @override
  String get readerUiPreviousHunk => 'مقطع التغيير السابق';

  @override
  String get readerUiNextHunk => 'مقطع التغيير التالي';

  @override
  String get readerUiAsk => 'اسأل';

  @override
  String get readerUiAddFile => 'إضافة ملف';

  @override
  String get readerUiAddFilePrompt => 'إضافة الملف إلى الطلب';

  @override
  String get readerUiAskFile => 'اسأل عن الملف';

  @override
  String get readerUiFileActions => 'إجراءات مراجعة الملف';

  @override
  String get readerUiStartFile => 'بداية الملف';

  @override
  String get readerUiNoGap => 'لا توجد أسطر مخفية';

  @override
  String get readerUiClearSelection => 'إلغاء التحديد';

  @override
  String get readerUiCopySelection => 'نسخ التحديد';

  @override
  String get readerUiAddHunk => 'إضافة مقطع التغيير إلى الطلب';

  @override
  String get readerUiAddSelection => 'إضافة التحديد إلى الطلب';

  @override
  String get readerUiComment => 'تعليق';

  @override
  String get readerUiCommentChange => 'التعليق على التغيير';

  @override
  String get readerUiCommentHint => 'ما الذي تريد من OpenCode فحصه أو تغييره؟';

  @override
  String get readerUiAddPrompt => 'إضافة إلى الطلب';

  @override
  String get readerUiNoChanges => 'لا توجد تغييرات للمراجعة';

  @override
  String get readerUiNoChangesHint =>
      'لم يغيّر OpenCode أي ملفات في هذه الجلسة.';

  @override
  String get readerUiDiffUnavailable => 'محتوى التغييرات غير متاح';

  @override
  String get readerUiDiffUnavailableHint =>
      'أبلغ الخادم عن هذا الملف دون إرسال التغييرات أو محتوى الملف.';

  @override
  String get readerUiCopyContents => 'نسخ محتوى الملف';

  @override
  String get readerUiSaveDevice => 'حفظ على الجهاز';

  @override
  String get readerUiClosePreview => 'إغلاق المعاينة';

  @override
  String get readerUiPreviewUnavailable => 'المعاينة غير متاحة';

  @override
  String get readerUiImageFailed => 'تعذّر عرض الصورة';

  @override
  String get readerUiImageUnsupported => 'بيانات الملف لا تمثل صورة مدعومة.';

  @override
  String get readerUiRendered => 'معاينة';

  @override
  String get readerUiRaw => 'المصدر';

  @override
  String get readerUiSaveFailed => 'تعذّر حفظ تفضيلات القراءة. حاول مجددًا.';

  @override
  String get readerUiFileOrder => 'ترتيب الملفات';

  @override
  String get readerUiSourceFirst => 'ملفات المصدر أولًا';

  @override
  String get readerUiServerOrder => 'الترتيب الافتراضي';

  @override
  String get readerUiOrderHint => 'يعيد ترتيب العناصر دون إخفاء أي ملفات.';

  @override
  String readerUiLine(int number) {
    return 'السطر $number';
  }

  @override
  String readerUiReferenceAdded(String label) {
    return 'أُضيف $label إلى الطلب';
  }

  @override
  String readerUiReferenceDuplicate(String label) {
    return '$label موجود بالفعل في الطلب';
  }

  @override
  String readerUiReferenceFull(int count) {
    return 'عدد المراجع الموجودة في الطلب: $count';
  }

  @override
  String readerUiAttached(String name) {
    return 'تم إرفاق $name.';
  }

  @override
  String readerUiCopiedPath(String path) {
    return 'تم نسخ $path';
  }

  @override
  String readerUiChangedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف متغير',
      many: '$count ملفًا متغيرًا',
      few: '$count ملفات متغيرة',
      two: 'ملفان متغيران',
      one: 'ملف واحد متغير',
      zero: 'لا توجد ملفات متغيرة',
    );
    return '$_temp0';
  }

  @override
  String readerUiChangeSummary(int count, int added, int removed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا توجد ملفات',
    );
    return '$_temp0 · +$added −$removed';
  }

  @override
  String readerUiAddPath(String path) {
    return 'إضافة $path إلى الطلب';
  }

  @override
  String readerUiAttachedReturn(String name) {
    return 'تم إرفاق $name. عُد إلى المحادثة لإضافة تعليقك.';
  }

  @override
  String readerUiSaveNamed(String name) {
    return 'حفظ $name';
  }

  @override
  String readerUiSavedDevice(String name) {
    return 'تم حفظ $name على جهازك.';
  }

  @override
  String readerUiPathLine(String path, int line) {
    return '$path · السطر $line';
  }

  @override
  String readerUiOnPrompt(int count) {
    return '$count في الطلب';
  }

  @override
  String readerUiOldNew(String oldLabel, String newLabel) {
    return 'قبل التغيير: $oldLabel · بعد التغيير: $newLabel';
  }

  @override
  String readerUiNewLines(String label) {
    return 'بعد التغيير: $label';
  }

  @override
  String readerUiOldLines(String label) {
    return 'قبل التغيير: $label';
  }

  @override
  String readerUiSelectedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر محدد',
      many: '$count سطرًا محددًا',
      few: '$count أسطر محددة',
      two: 'سطران محددان',
      one: 'سطر واحد محدد',
      zero: 'لا توجد أسطر محددة',
    );
    return '$_temp0';
  }

  @override
  String readerUiLineRange(int first, int last) {
    return 'الأسطر $first–$last';
  }

  @override
  String readerUiReviewPrompt(String path) {
    return 'راجع `$path`';
  }

  @override
  String readerUiViewedCount(int viewed, int files) {
    return 'تمت معاينة $viewed من $files';
  }

  @override
  String readerUiHunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع تغيير',
      many: '$count مقطع تغيير',
      few: '$count مقاطع تغيير',
      two: 'مقطعا تغيير',
      one: 'مقطع تغيير واحد',
      zero: 'لا توجد مقاطع تغيير',
    );
    return '$_temp0';
  }

  @override
  String readerUiReviewing(String path) {
    return 'مراجعة $path';
  }

  @override
  String readerUiHiddenLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count سطر',
      many: '+$count سطرًا',
      few: '+$count أسطر',
      two: '+سطران',
      one: '+سطر واحد',
      zero: 'لا توجد أسطر',
    );
    return '$_temp0';
  }

  @override
  String readerUiHiddenDescription(int count, String text) {
    return 'الأسطر غير المتغيرة المخفية: $count. $text';
  }

  @override
  String readerUiExpandDescription(int count) {
    return 'إظهار المزيد. الأسطر غير المتغيرة المخفية أدناه: $count';
  }

  @override
  String readerUiMoreCount(int count) {
    return 'المزيد: $count';
  }

  @override
  String readerUiHunkSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر',
      many: '$count سطرًا',
      few: '$count أسطر',
      two: 'سطران',
      one: 'سطر واحد',
      zero: 'لا توجد أسطر',
    );
    return 'تم تحديد مقطع التغيير · $_temp0';
  }

  @override
  String readerUiSaved(String name) {
    return 'تم حفظ $name.';
  }

  @override
  String readerUiBytes(int count) {
    return '$count بايت';
  }

  @override
  String get readerUiSymbolFile => 'ملف';

  @override
  String get readerUiSymbolModule => 'وحدة';

  @override
  String get readerUiSymbolNamespace => 'نطاق أسماء';

  @override
  String get readerUiSymbolPackage => 'حزمة';

  @override
  String get readerUiSymbolClass => 'صنف';

  @override
  String get readerUiSymbolMethod => 'دالة عضو';

  @override
  String get readerUiSymbolProperty => 'خاصية';

  @override
  String get readerUiSymbolField => 'حقل';

  @override
  String get readerUiSymbolConstructor => 'دالة إنشاء';

  @override
  String get readerUiSymbolEnum => 'تعداد';

  @override
  String get readerUiSymbolInterface => 'واجهة';

  @override
  String get readerUiSymbolFunction => 'دالة';

  @override
  String get readerUiSymbolVariable => 'متغير';

  @override
  String get readerUiSymbolConstant => 'ثابت';

  @override
  String get readerUiSymbolEnummember => 'عنصر تعداد';

  @override
  String get readerUiSymbolStruct => 'بنية';

  @override
  String get readerUiSymbolEvent => 'حدث';

  @override
  String get readerUiSymbolOperator => 'عامل';

  @override
  String get readerUiSymbolTypeparameter => 'معامل نوع';

  @override
  String get readerUiSymbolSymbol => 'رمز';

  @override
  String get readerUiAdded => 'مضاف';

  @override
  String get readerUiDeleted => 'محذوف';

  @override
  String get readerUiModified => 'معدّل';

  @override
  String get readerUiChanged => 'متغير';

  @override
  String get readerUiSession => 'الجلسة';

  @override
  String get readerUiBranch => 'الفرع';

  @override
  String get readerUiRemoved => 'محذوف';

  @override
  String get readerUiUnchanged => 'دون تغيير';

  @override
  String get readerUiHunk => 'مقطع تغيير';

  @override
  String get readerUiMetadata => 'بيانات وصفية';

  @override
  String readerUiFileDescription(
    String path,
    String status,
    int added,
    int removed,
  ) {
    return '$path، $status، المضاف: $added، المحذوف: $removed';
  }

  @override
  String get readerUiUnknownType => 'نوع ملف غير معروف';

  @override
  String get readerUiFormatUnsupported =>
      'لا يمكن عرض هذا التنسيق داخل التطبيق حاليًا.';

  @override
  String get readerUiAttachmentMissing =>
      'محتوى المرفق غير موجود في هذه الرسالة.';

  @override
  String get readerUiRemoteAttachment => 'معاينة المرفقات البعيدة غير متاحة.';

  @override
  String get readerUiAttachmentInvalid => 'تعذّر قراءة بيانات المرفق.';

  @override
  String get readerUiPinchZoom => 'باعد بين إصبعيك للتكبير';

  @override
  String get readerUiStatusAdded => 'مضاف';

  @override
  String get readerUiStatusDeleted => 'محذوف';

  @override
  String get readerUiStatusModified => 'معدّل';

  @override
  String readerUiSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر محدد',
      many: '$count سطرًا محددًا',
      few: '$count أسطر محددة',
      two: 'سطران محددان',
      one: 'سطر واحد محدد',
      zero: 'لا توجد أسطر محددة',
    );
    return '$_temp0';
  }

  @override
  String get e7WorkspaceDisconnected => 'الخادم غير متصل.';

  @override
  String get e7WorkspaceNoFolder => 'لم يُحدَّد مجلد للمشروع';

  @override
  String get e7WorkspaceLoadingProjects => 'جارٍ تحميل المشاريع';

  @override
  String get e7WorkspaceNoProjects => 'لا توجد مشاريع مفتوحة';

  @override
  String get e7WorkspaceServerNoProjects => 'لم يُرجع الخادم أي مشاريع.';

  @override
  String get e7WorkspaceChooseProject => 'اختر مشروعًا';

  @override
  String get e7WorkspaceNeedsYou => 'بانتظارك';

  @override
  String get e7WorkspaceActiveSessions => 'الجلسات النشطة';

  @override
  String get e7WorkspaceRecentSessions => 'الجلسات الأخيرة';

  @override
  String get e7WorkspaceNoRecent => 'لا توجد جلسات حديثة';

  @override
  String get e7WorkspaceChooseFolderToStart => 'اختر مجلد مشروع لبدء جلسة.';

  @override
  String get e7WorkspaceStartInWorkspace => 'ابدأ جلسة في مساحة العمل المحددة.';

  @override
  String get e7WorkspaceArchivedSessions => 'الجلسات المؤرشفة';

  @override
  String get e7WorkspaceNoProjectSelected => 'لم يُحدَّد مشروع';

  @override
  String get e7WorkspaceSwitchProject => 'تبديل المشروع';

  @override
  String get e7WorkspaceWorkspace => 'مساحة العمل';

  @override
  String get e7WorkspaceThisComputer => 'هذا الكمبيوتر';

  @override
  String get e7WorkspaceNoShareLink => 'لم يُرجع الخادم رابطًا للمشاركة.';

  @override
  String get e7WorkspaceShareCopied => 'نُسخ رابط المشاركة';

  @override
  String get e7WorkspaceUnshared => 'أُوقفت مشاركة الجلسة';

  @override
  String get e7WorkspaceReconnectingShortly =>
      'جارٍ إعادة الاتصال بـ OpenCode. حاول مجددًا بعد قليل.';

  @override
  String get e7WorkspaceRenameSession => 'إعادة تسمية الجلسة';

  @override
  String get e7WorkspaceTitle => 'العنوان';

  @override
  String get e7WorkspaceArchiveConfirm => 'أرشفة الجلسة؟';

  @override
  String get e7WorkspaceShareConfirm => 'مشاركة هذه الجلسة؟';

  @override
  String get e7WorkspaceDeleteConfirm => 'حذف الجلسة؟';

  @override
  String get e7WorkspaceArchive => 'أرشفة';

  @override
  String get e7WorkspaceShareSession => 'مشاركة الجلسة';

  @override
  String get e7WorkspaceArchivedActions => 'إجراءات الجلسة المؤرشفة';

  @override
  String get e7WorkspaceRename => 'إعادة تسمية';

  @override
  String get e7WorkspaceCompacting => 'جارٍ اختصار السياق…';

  @override
  String get e7WorkspaceShare => 'مشاركة';

  @override
  String get e7WorkspaceStopSharing => 'إيقاف المشاركة';

  @override
  String get e7WorkspaceFiles => 'الملفات';

  @override
  String get e7WorkspaceActivity => 'النشاط';

  @override
  String get e7WorkspaceMore => 'المزيد';

  @override
  String get e7WorkspaceModelAgent => 'النموذج / الوكيل';

  @override
  String get e7WorkspaceDisconnect => 'قطع الاتصال';

  @override
  String get e7WorkspaceBackExit => 'اضغط رجوع مرة أخرى للخروج';

  @override
  String get e7WorkspaceConnected => 'متصل';

  @override
  String get e7WorkspaceConnecting => 'جارٍ الاتصال';

  @override
  String get e7WorkspaceOffline => 'غير متصل';

  @override
  String get e7WorkspaceReconnectingAgain =>
      'جارٍ إعادة الاتصال بـ OpenCode. حاول مجددًا.';

  @override
  String get e7WorkspaceRefreshFailed => 'تعذّر التحديث';

  @override
  String get e7WorkspaceServerRequests => 'طلبات الخادم';

  @override
  String get e7WorkspacePermissionRequired => 'يلزم إذن';

  @override
  String get e7WorkspaceAssistantQuestion => 'سؤال من المساعد';

  @override
  String get e7WorkspaceInputRequested => 'مطلوب إدخال';

  @override
  String get e7WorkspaceMcpAsked => 'طلب من خادم MCP';

  @override
  String get e7WorkspaceDismissRequest => 'تجاهل هذا الطلب؟';

  @override
  String get e7WorkspaceDismissDetail =>
      'سيتابع OpenCode دون إجابات عن هذه الأسئلة.';

  @override
  String get e7WorkspaceNeedsInput => 'يحتاج OpenCode إلى إدخال';

  @override
  String get e7WorkspaceSendAnswers => 'إرسال الإجابات';

  @override
  String get e7WorkspaceReferenceRetry =>
      'مرجع الجلسة غير متاح. حدّث وحاول مجددًا.';

  @override
  String get e7WorkspaceLocationRetry =>
      'موقع الجلسة غير متاح. حدّث وحاول مجددًا.';

  @override
  String get e7WorkspaceLocationChangedReturn =>
      'تغيّر موقع الجلسة. ارجع وحاول مجددًا.';

  @override
  String get e7WorkspaceLocationChangedRetry =>
      'تغيّر موقع الجلسة. حدّث وحاول مجددًا.';

  @override
  String get e7WorkspaceReferenceUnavailable => 'مرجع الجلسة غير متاح.';

  @override
  String get e7WorkspacePaginationStuck =>
      'تعذّر تحميل الصفحة التالية من الجلسات. حدّث القائمة للمتابعة.';

  @override
  String get e7WorkspaceContinueHereConfirm => 'متابعة هذه الجلسة هنا؟';

  @override
  String e7WorkspaceCreateFailed(String error) {
    return 'تعذّر إنشاء جلسة: $error';
  }

  @override
  String get e7WorkspaceNoProjectsSearch =>
      'لم يُرجع الخادم أي مشاريع. ابحث في جميع الجلسات للعثور على المحادثات السابقة.';

  @override
  String e7WorkspaceActiveDirectory(String directory) {
    return 'مجلد الجلسة النشطة · $directory';
  }

  @override
  String e7WorkspaceArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة مؤرشفة',
      many: '$count جلسة مؤرشفة',
      few: '$count جلسات مؤرشفة',
      two: 'جلستان مؤرشفتان',
      one: 'جلسة مؤرشفة واحدة',
      zero: 'لا توجد جلسات مؤرشفة',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceOpenProjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشروع مفتوح على هذا الخادم',
      many: '$count مشروعًا مفتوحًا على هذا الخادم',
      few: '$count مشاريع مفتوحة على هذا الخادم',
      two: 'مشروعان مفتوحان على هذا الخادم',
      one: 'مشروع واحد مفتوح على هذا الخادم',
      zero: 'لا توجد مشاريع مفتوحة على هذا الخادم',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceArchivedToast(String title) {
    return 'أُرشفت «$title»';
  }

  @override
  String e7WorkspaceArchiveDetail(String title) {
    return 'ستُخفى «$title» من الجلسات الأخيرة.';
  }

  @override
  String e7WorkspaceDeleteDetail(String title) {
    return 'ستُحذف «$title» وسجلّها نهائيًا.';
  }

  @override
  String e7WorkspaceShareDetail(String title) {
    return 'يمكن لأي شخص لديه الرابط عرض «$title»، بما في ذلك المحادثة والسياق المشترك. لا تشارك أسرارًا أو بيانات اعتماد أو ملفات خاصة.';
  }

  @override
  String e7WorkspaceSharedUrl(String url) {
    return 'مُشارَكة: $url';
  }

  @override
  String e7WorkspaceAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر يحتاج إلى انتباهك',
      many: '$count عنصرًا يحتاج إلى انتباهك',
      few: '$count عناصر تحتاج إلى انتباهك',
      two: 'عنصران يحتاجان إلى انتباهك',
      one: 'عنصر واحد يحتاج إلى انتباهك',
      zero: 'لا توجد عناصر تحتاج إلى انتباهك',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceServerName(String name) {
    return 'الخادم: $name';
  }

  @override
  String e7WorkspaceServerStatus(String status) {
    return 'الخادم: $status';
  }

  @override
  String e7WorkspaceRequestFor(String title) {
    return 'لـ $title';
  }

  @override
  String e7WorkspaceQuestionCount(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سؤال · $title',
      many: '$count سؤالًا · $title',
      few: '$count أسئلة · $title',
      two: 'سؤالان · $title',
      one: 'سؤال واحد · $title',
      zero: 'لا توجد أسئلة · $title',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceSubagentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وكيل فرعي',
      many: '$count وكيلًا فرعيًا',
      few: '$count وكلاء فرعيين',
      two: 'وكيلان فرعيان',
      one: 'وكيل فرعي واحد',
      zero: 'لا يوجد وكلاء فرعيون',
    );
    return '$_temp0';
  }

  @override
  String e7WorkspaceSessionId(String id) {
    return 'الجلسة $id';
  }

  @override
  String e7WorkspaceContinueHereDetail(String title) {
    return 'ستنتمي «$title» إلى مساحة عملك الحالية عبر نظام مزامنة الخادم، ولن تنتمي بعد ذلك إلى مساحة العمل التي تعمل فيها الآن.';
  }

  @override
  String e7WorkspaceMovedHere(String title) {
    return 'أصبحت «$title» ضمن مساحة العمل هذه';
  }

  @override
  String e7WorkspaceOpenSessionSemantics(String title, String detail) {
    return 'فتح $title. $detail';
  }

  @override
  String get e7WorkspaceLoadingSessions => 'جارٍ تحميل الجلسات…';

  @override
  String get e7WorkspaceLoadedRecentEmpty => 'قد تتوفر محادثات أقدم أدناه.';

  @override
  String get e7WorkspaceSearchServer =>
      'البحث في عناوين الجلسات في جميع مشاريع هذا الخادم';

  @override
  String get e7WorkspaceUnknownProject => 'مشروع غير معروف';

  @override
  String get e7WorkspaceJustNow => 'الآن';

  @override
  String e7WorkspaceMinutesAgo(int count) {
    return 'قبل $count د';
  }

  @override
  String e7WorkspaceHoursAgo(int count) {
    return 'قبل $count س';
  }

  @override
  String e7WorkspaceDaysAgo(int count) {
    return 'قبل $count ي';
  }

  @override
  String e7WorkspaceFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا توجد ملفات',
    );
    return '$_temp0';
  }

  @override
  String get e7WorkspaceBackgroundOn => 'يبقى متصلًا في الخلفية';

  @override
  String get e7WorkspaceBackgroundOff => 'تحديثات الخلفية متوقفة';

  @override
  String e7WorkspaceFilteredLoaded(int count, int total) {
    return 'الجلسات المحمّلة: $total · الظاهرة: $count';
  }

  @override
  String e7WorkspaceLoadedSummary(int count, int folders) {
    return 'الجلسات المحمّلة: $count · المجلدات: $folders';
  }

  @override
  String get e7WorkspaceLoadedFolders => 'المجلدات المحمّلة';

  @override
  String get chatUiUnderAMessageForActions => ' أسفل الرسالة لعرض الإجراءات';

  @override
  String get chatUiAllMatchingRequests => '(كل الطلبات المطابقة)';

  @override
  String get chatUiNoOutput => '(لا توجد مخرجات)';

  @override
  String get chatUiNoResult => '(لا توجد نتيجة)';

  @override
  String get chatUiTapToExpand => '(اضغط للتوسيع)';

  @override
  String get chatUi1ReferenceIsAddedAsTextWhen =>
      'يُضاف مرجع واحد كنص عند الإرسال. لا يُحفظ مع مسودتك.';

  @override
  String get chatUiActions => 'الإجراءات';

  @override
  String get chatUiAddAnOpenCodeProjectReferenceToThis =>
      'إضافة مرجع لمشروع OpenCode إلى هذا الطلب';

  @override
  String get chatUiAddAnImageOrFileToThe => 'إضافة صورة أو ملف إلى الطلب';

  @override
  String get chatUiAddHoldToAttachAFile => 'إضافة. اضغط مطوّلًا لإرفاق ملف';

  @override
  String get chatUiAgent => 'الوكيل';

  @override
  String get chatUiAllowOnce => 'السماح مرة واحدة';

  @override
  String get chatUiAlreadyAnsweredElsewhere => 'أُجيب عنه في مكان آخر بالفعل';

  @override
  String get chatUiAlreadyDelivered => 'سُلّم بالفعل';

  @override
  String get chatUiAlwaysAllow => 'السماح دائمًا';

  @override
  String get chatUiAlwaysAllowPatterns => 'أنماط السماح الدائم:';

  @override
  String get chatUiAlwaysAllowWouldAlsoCover => 'سيشمل السماح الدائم أيضًا';

  @override
  String get chatUiAnswerWasCutOffByTheLength => 'قُطع الرد بسبب حد الطول';

  @override
  String get chatUiAnyoneWithTheLinkCanViewThis =>
      'يمكن لأي شخص لديه الرابط الاطّلاع على محادثة هذه الجلسة وسياقها المشترك. لا تشارك جلسات تتضمّن أسرارًا أو بيانات اعتماد أو ملفات خاصة.';

  @override
  String get chatUiAppDiagnostics => 'تشخيصات التطبيق';

  @override
  String get chatUiAppearance => 'المظهر';

  @override
  String get chatUiApplyPatch => 'تطبيق رقعة';

  @override
  String get chatUiAskOpenCode => 'اسأل OpenCode…';

  @override
  String get chatUiAssistantIsWorking => 'المساعد يعمل';

  @override
  String get chatUiAttachFile => 'إرفاق ملف';

  @override
  String get chatUiAttachToPrompt => 'إرفاق بالطلب';

  @override
  String get chatUiAttachment => 'مرفق';

  @override
  String get chatUiAttachmentLimitReached => 'بلغت الحد الأقصى للمرفقات';

  @override
  String get chatUiAttachmentsMustTotalNoMoreThan20 =>
      'يجب ألا يتجاوز إجمالي حجم المرفقات 20 MB.';

  @override
  String get chatUiAvailableWhenTheCurrentRunFinishes =>
      'متاح عند انتهاء التشغيل الحالي';

  @override
  String get chatUiBrowseProjectAndGlobalSkills =>
      'تصفّح مهارات المشروع والمهارات العامة';

  @override
  String get chatUiBrowsePreviewDownloadAndAttachProjectFiles =>
      'تصفّح ملفات المشروع ومعاينتها وتنزيلها وإرفاقها';

  @override
  String get chatUiCancelAndReturnToTheComposer =>
      'الإلغاء والعودة إلى محرّر الرسالة';

  @override
  String get chatUiCancelMessage => 'إلغاء الرسالة';

  @override
  String get chatUiCancelThisPendingMessage =>
      'هل تريد إلغاء هذه الرسالة المنتظرة؟';

  @override
  String get chatUiChangeTheActiveOpenCodeConsoleOrganization =>
      'تغيير المؤسسة النشطة في OpenCode Console';

  @override
  String get chatUiChangeTheTitleShownInTheSession =>
      'تغيير العنوان الظاهر في قائمة الجلسات';

  @override
  String get chatUiChangeThisSessionSExperimentalWorkspace =>
      'تغيير مساحة العمل التجريبية لهذه الجلسة';

  @override
  String get chatUiChangedFile => 'ملف متغيّر';

  @override
  String get chatUiChanges => 'التغييرات';

  @override
  String get chatUiChooseAPromptAndContinueItIn =>
      'اختيار طلب ومتابعته في جلسة جديدة';

  @override
  String get chatUiChooseAPromptToRestoreItIn =>
      'اختر طلبًا لاستعادته في جلسة جديدة.';

  @override
  String get chatUiChooseAServerModelByProviderAnd =>
      'اختيار نموذج على الخادم بحسب مزوّد الخدمة والقدرات';

  @override
  String get chatUiChooseAnotherModelInThePickerTo =>
      'اختر نموذجًا آخر من القائمة لإضافته إلى نماذجك الأخيرة.';

  @override
  String get chatUiChooseModel => 'اختيار نموذج';

  @override
  String get chatUiChooseTheActiveOpenCodeAgent => 'اختيار وكيل OpenCode النشط';

  @override
  String get chatUiChooseTheCurrentModelVariantOrReasoning =>
      'اختيار متغيّر النموذج الحالي أو مستوى الاستدلال';

  @override
  String get chatUiCloseComposerTools => 'إغلاق أدوات محرّر الرسالة';

  @override
  String get chatUiClosePromptEditor => 'إغلاق محرّر الطلب';

  @override
  String get chatUiCloseTimeline => 'إغلاق التسلسل الزمني';

  @override
  String get chatUiCollapseReasoning => 'طيّ الاستدلال';

  @override
  String get chatUiCollapseReasoningDetails => 'طيّ تفاصيل الاستدلال';

  @override
  String get chatUiCollapsedUntilYouTapIt => 'مطوي حتى تضغط عليه';

  @override
  String get chatUiCommandMap => 'دليل الأوامر';

  @override
  String get chatUiCompactContext => 'اختصار السياق';

  @override
  String get chatUiCompactSession => 'اختصار الجلسة';

  @override
  String get chatUiCompactingConversation => 'جارٍ اختصار المحادثة…';

  @override
  String get chatUiCompacting => 'جارٍ الاختصار…';

  @override
  String get chatUiCompactionFailed => 'فشل اختصار السياق';

  @override
  String get chatUiCompactionStarted => 'بدأ اختصار السياق';

  @override
  String get chatUiCompose => 'كتابة رسالة';

  @override
  String get chatUiComposerTools => 'أدوات محرّر الرسالة';

  @override
  String get chatUiConfirmAlwaysAllow => 'تأكيد السماح الدائم';

  @override
  String get chatUiConfirmBroaderAccess => 'تأكيد صلاحيات وصول أوسع';

  @override
  String get chatUiConnectProvider => 'ربط مزوّد خدمة';

  @override
  String get chatUiConnectionHealthServerVersionAndLiveMode =>
      'حالة الاتصال وإصدار الخادم والوضع المباشر';

  @override
  String get chatUiConsequenceFutureMatchingActionsCanRunWithout =>
      'النتيجة: ستتمكن الإجراءات المطابقة مستقبلًا من العمل دون طلب الإذن مجددًا طوال مدة تشغيل خادم OpenCode هذا. السماح مرة واحدة أكثر أمانًا.';

  @override
  String get chatUiContextAdded => 'أُضيف السياق';

  @override
  String get chatUiContextCompacted => 'اختُصر السياق';

  @override
  String get chatUiContextUpdatePending => 'تحديث السياق منتظر';

  @override
  String get chatUiContextUsage => 'استخدام السياق';

  @override
  String get chatUiCopiedPasteItIntoTheComposer =>
      'نُسخ النص. الصقه في محرّر الرسالة';

  @override
  String get chatUiCopyMessageText => 'نسخ نص الرسالة';

  @override
  String get chatUiCopyShareLink => 'نسخ رابط المشاركة';

  @override
  String get chatUiCopyTheRenderedConversationAsMarkdown =>
      'نسخ المحادثة المعروضة بصيغة Markdown';

  @override
  String get chatUiCopyTranscript => 'نسخ سجل المحادثة';

  @override
  String get chatUiCreateOrCopyAPublicSessionLink =>
      'إنشاء رابط عام للجلسة أو نسخه';

  @override
  String get chatUiCurrentSession => 'الجلسة الحالية';

  @override
  String get chatUiDelegate => 'تفويض';

  @override
  String get chatUiDelegateThisPrompt => 'تفويض هذا الطلب';

  @override
  String get chatUiDelegateThisPromptToAServerSubagent =>
      'تفويض هذا الطلب إلى وكيل فرعي على الخادم';

  @override
  String get chatUiDelegatedSession => 'جلسة مفوّضة';

  @override
  String get chatUiDeleteChat => 'هل تريد حذف المحادثة؟';

  @override
  String get chatUiDeleteMessage => 'حذف الرسالة';

  @override
  String get chatUiDeleteThisMessage => 'هل تريد حذف هذه الرسالة؟';

  @override
  String get chatUiDescribeAChangeAskAboutThisProject =>
      'صِف تغييرًا، أو اسأل عن هذا المشروع، أو الصق رسالة خطأ.';

  @override
  String get chatUiDetails => 'التفاصيل';

  @override
  String get chatUiDirectory => 'المجلد';

  @override
  String get chatUiDisableTheCurrentPublicSessionLink =>
      'تعطيل الرابط العام الحالي للجلسة';

  @override
  String get chatUiDiscard => 'تجاهل';

  @override
  String get chatUiDiscardDraft => 'تجاهل المسودة';

  @override
  String get chatUiDiscardPromptChanges => 'هل تريد تجاهل تغييرات الطلب؟';

  @override
  String get chatUiDiscardQueuedDraft =>
      'هل تريد تجاهل المسودة في قائمة الانتظار؟';

  @override
  String get chatUiDismissPromptError => 'إخفاء خطأ الطلب';

  @override
  String get chatUiEachAttachmentMustBe10MBOr =>
      'يجب ألا يتجاوز حجم كل مرفق 10 MB.';

  @override
  String get chatUiEdit => 'تحرير';

  @override
  String get chatUiEditDraft => 'تحرير المسودة';

  @override
  String get chatUiEditTheCurrentPromptInAFocused =>
      'تحرير الطلب الحالي في عرض مخصّص بملء الشاشة';

  @override
  String get chatUiEmptySessionWasKeptBecauseOpenCodeCould =>
      'احتُفظ بالجلسة الفارغة لأن OpenCode لم يتمكن من التحقق منها أو إزالتها.';

  @override
  String get chatUiErrorDetails => 'تفاصيل الخطأ';

  @override
  String get chatUiExpandReasoning => 'توسيع الاستدلال';

  @override
  String get chatUiExpandReasoningDetails => 'توسيع تفاصيل الاستدلال';

  @override
  String get chatUiExpandedUnderEachAnswer => 'موسّع أسفل كل رد';

  @override
  String get chatUiExplainThisProject => 'اشرح هذا المشروع';

  @override
  String get chatUiExplored => 'اكتمل الاستكشاف';

  @override
  String get chatUiExploring => 'جارٍ الاستكشاف';

  @override
  String get chatUiExportSessionTranscript => 'تصدير سجل الجلسة';

  @override
  String get chatUiExportTranscript => 'تصدير سجل المحادثة';

  @override
  String get chatUiFILE => 'ملف';

  @override
  String get chatUiFetchPage => 'جلب صفحة';

  @override
  String get chatUiFileEditsMadeInThisSessionWill =>
      'ستظهر هنا تعديلات الملفات التي أُجريت في هذه الجلسة.';

  @override
  String get chatUiFiles => 'الملفات';

  @override
  String get chatUiFilesAreUnavailableInThisPreview =>
      'الملفات غير متاحة في هذه المعاينة.';

  @override
  String get chatUiFindACommandOrAction => 'البحث عن أمر أو إجراء';

  @override
  String get chatUiFindAMessageJumpToItOr =>
      'البحث عن رسالة أو الانتقال إليها أو إنشاء فرع من طلب';

  @override
  String get chatUiFindASubagent => 'البحث عن وكيل فرعي';

  @override
  String get chatUiFindAndFixABug => 'اعثر على خطأ وأصلحه';

  @override
  String get chatUiFindFiles => 'البحث عن ملفات';

  @override
  String get chatUiFindSessionsAcrossEveryOpenCodeProject =>
      'البحث عن جلسات في كل مشاريع OpenCode';

  @override
  String get chatUiFollowAndroidOrChooseTheNativeLight =>
      'اتباع Android أو اختيار المظهر الفاتح أو الداكن للنظام';

  @override
  String get chatUiForkFromPrompt => 'إنشاء فرع من طلب';

  @override
  String get chatUiForkFromThisPrompt => 'إنشاء فرع من هذا الطلب';

  @override
  String get chatUiForkSession => 'إنشاء فرع من الجلسة';

  @override
  String get chatUiFromToolCall => 'من استدعاء أداة';

  @override
  String get chatUiGeneratedFile => 'ملف مُنشأ';

  @override
  String get chatUiHiddenToKeepTheTranscriptQuiet =>
      'مخفي لتقليل ازدحام سجل المحادثة';

  @override
  String get chatUiHideTimestamps => 'إخفاء الطوابع الزمنية';

  @override
  String get chatUiImageDataIsUnavailable => 'بيانات الصورة غير متاحة.';

  @override
  String get chatUiInputRequested => 'مطلوب إدخال';

  @override
  String get chatUiInspectGitLanguageServicesAndFormattersFor =>
      'فحص Git وخدمات اللغة وأدوات التنسيق لهذا المشروع';

  @override
  String get chatUiInspectMCPStatusAuthenticationAndResources =>
      'فحص حالة MCP والمصادقة والموارد';

  @override
  String get chatUiInspectCurrentTokensCacheCostAndContext =>
      'فحص الرموز الحالية وذاكرة التخزين المؤقت والتكلفة واستخدام السياق';

  @override
  String get chatUiInspectToolsCallableByTheActiveProvider =>
      'فحص الأدوات التي يمكن لمزوّد الخدمة والنموذج النشطين استدعاؤها';

  @override
  String get chatUiItsTextReturnsToTheComposerAs =>
      'يعود نصها إلى محرّر الرسالة كمسودة.';

  @override
  String get chatUiJumpAnywhereInThisConversation =>
      'انتقل إلى أي موضع في هذه المحادثة.';

  @override
  String get chatUiJumpAnywhereForkRestoresAPromptFor =>
      'انتقل إلى أي موضع. يستعيد إنشاء الفرع طلبًا لتحريره.';

  @override
  String get chatUiJumpToLatest => 'الانتقال إلى الأحدث';

  @override
  String get chatUiKeepAsking => 'متابعة طلب الإذن';

  @override
  String get chatUiKeepItPending => 'إبقاؤها منتظرة';

  @override
  String get chatUiKeepItQueued => 'إبقاؤها في قائمة الانتظار';

  @override
  String get chatUiLanguageServer => 'خادم اللغة';

  @override
  String get chatUiList => 'عرض قائمة';

  @override
  String get chatUiListWhatSInThisDirectory => 'اعرض محتويات هذا المجلد';

  @override
  String get chatUiLoadingSubagents => 'جارٍ تحميل الوكلاء الفرعيين…';

  @override
  String get chatUiLongReasoningCollapsedInTheTranscript =>
      'تفاصيل الاستدلال الطويلة مطوية في سجل المحادثة';

  @override
  String get chatUiMCPServers => 'خوادم MCP';

  @override
  String get chatUiManageProviderAndIntegrationAuthentication =>
      'إدارة مصادقة مزوّدي الخدمة والتكاملات';

  @override
  String get chatUiManageSavedGrantsInSettingsSavedPermissions =>
      'أدِر الأذونات المحفوظة من الإعدادات ← الأذونات المحفوظة.';

  @override
  String get chatUiMessage => 'الرسالة';

  @override
  String get chatUiMessageActions => 'إجراءات الرسالة';

  @override
  String get chatUiMessageDeleted => 'حُذفت الرسالة';

  @override
  String get chatUiMessageTextCopied => 'نُسخ نص الرسالة';

  @override
  String get chatUiMessageTimeline => 'التسلسل الزمني للرسائل';

  @override
  String get chatUiMessageTimestampsHidden => 'أُخفيت الطوابع الزمنية للرسائل';

  @override
  String get chatUiMessageTimestampsShown => 'أُظهرت الطوابع الزمنية للرسائل';

  @override
  String get chatUiMessagesAndFileChangesAfterTheMost =>
      'سيُتراجع عن الرسائل وتغييرات الملفات التي تلت أحدث طلب.';

  @override
  String get chatUiMobileActionsAndCommandsFromThisServer =>
      'إجراءات الهاتف وأوامر هذا الخادم';

  @override
  String get chatUiModel => 'النموذج';

  @override
  String get chatUiModelAndAgent => 'النموذج والوكيل';

  @override
  String get chatUiMore => 'المزيد';

  @override
  String get chatUiMoveSession => 'نقل الجلسة';

  @override
  String get chatUiMoveThisSessionToAnotherProjectDirectory =>
      'نقل هذه الجلسة إلى مجلد مشروع آخر';

  @override
  String get chatUiMoved => 'نُقلت';

  @override
  String get chatUiNavigate => 'التنقّل';

  @override
  String get chatUiNeedsYou => 'بحاجة إليك';

  @override
  String get chatUiNoAnswer => 'لا توجد إجابة';

  @override
  String get chatUiNoChatsYet => 'لا توجد محادثات بعد';

  @override
  String get chatUiNoFileChangesYet => 'لا توجد تغييرات ملفات بعد';

  @override
  String get chatUiNoMatchingCommands => 'لا توجد أوامر مطابقة';

  @override
  String get chatUiNoMatchingMessages => 'لا توجد رسائل مطابقة';

  @override
  String get chatUiNoShareLinkWasReturned => 'لم يُعد رابط مشاركة';

  @override
  String get chatUiNoSubagentsAvailableFromThisServer =>
      'لا يتوفر وكلاء فرعيون من هذا الخادم';

  @override
  String get chatUiNoTodosInThisSession => 'لا توجد مهام في هذه الجلسة';

  @override
  String get chatUiNotConnected => 'غير متصل';

  @override
  String get chatUiNotConnectedToTheServerRightNow =>
      'غير متصل بالخادم حاليًا.';

  @override
  String get chatUiNotRun => 'لم يُشغّل';

  @override
  String get chatUiOpenFullScreenPromptEditor => 'فتح محرّر الطلب بملء الشاشة';

  @override
  String get chatUiOpenParentSession => 'فتح الجلسة الأم';

  @override
  String get chatUiOpenPersistentWorkspaceTerminals =>
      'فتح جلسات الطرفية الدائمة لمساحة العمل';

  @override
  String get chatUiOpenProviders => 'فتح مزوّدي الخدمة';

  @override
  String get chatUiOpenSubagentSession => 'فتح جلسة الوكيل الفرعي';

  @override
  String get chatUiOpenCodeCommandsAreUnavailableOffline =>
      'أوامر OpenCode غير متاحة دون اتصال.';

  @override
  String get chatUiOpenCodeCouldNotCompleteThisPrompt =>
      'تعذّر على OpenCode إتمام هذا الطلب.';

  @override
  String get chatUiOpenCodeIsReconnecting => 'جارٍ إعادة اتصال OpenCode.';

  @override
  String get chatUiOpenCodeIsReconnectingTryAgainShortly =>
      'جارٍ إعادة اتصال OpenCode. حاول مجددًا بعد قليل.';

  @override
  String get chatUiOpenCodeIsReconnectingTryAgainWhenThe =>
      'جارٍ إعادة اتصال OpenCode. حاول مجددًا عندما يتصل الخادم.';

  @override
  String get chatUiOpenCodeIsReconnectingTryAgain =>
      'جارٍ إعادة اتصال OpenCode. حاول مجددًا.';

  @override
  String get chatUiOpenCodeNeedsInput => 'يحتاج OpenCode إلى إدخال';

  @override
  String get chatUiOpenCodeServerCommand => 'أمر خادم OpenCode';

  @override
  String get chatUiOutputPruned => 'حُذفت المخرجات';

  @override
  String get chatUiPendingChange => 'تغيير منتظر';

  @override
  String get chatUiPreviewAttachment => 'معاينة المرفق';

  @override
  String get chatUiProjectFiles => 'ملفات المشروع';

  @override
  String get chatUiProjectHealth => 'حالة المشروع';

  @override
  String get chatUiProjectReference => 'مرجع مشروع';

  @override
  String get chatUiProjectReferences => 'مراجع المشاريع';

  @override
  String get chatUiProjectsAndWorkspaces => 'المشاريع ومساحات العمل';

  @override
  String get chatUiPromptEditor => 'محرّر الطلب';

  @override
  String get chatUiPromptFromParentAgent => 'طلب من الوكيل الأب';

  @override
  String get chatUiPromptTools => 'أدوات الطلب';

  @override
  String get chatUiQuestion => 'سؤال';

  @override
  String get chatUiQuestions => 'الأسئلة';

  @override
  String get chatUiQueue => 'إضافة إلى قائمة الانتظار';

  @override
  String get chatUiQueueAfterThisRun => 'إضافة إلى الانتظار بعد هذا التشغيل';

  @override
  String get chatUiQueuedRunsAfterThisTurn =>
      'في قائمة الانتظار · يُشغّل بعد هذا التبادل';

  @override
  String get chatUiQueuedWillSendWhenReconnected =>
      'في قائمة الانتظار — سيُرسل عند إعادة الاتصال';

  @override
  String get chatUiRead => 'قراءة';

  @override
  String get chatUiReasoningExpandedInTheTranscript =>
      'تفاصيل الاستدلال موسّعة في سجل المحادثة';

  @override
  String get chatUiRecordsAndTranscribesOnThisDevice =>
      'التسجيل وتحويل الصوت إلى نص على هذا الجهاز';

  @override
  String get chatUiReferenceKeptForYourNextPromptCommands =>
      'احتُفظ بالمرجع لطلبك التالي — لا تتضمّنه الأوامر.';

  @override
  String get chatUiReferencesKeptForYourNextPromptCommands =>
      'احتُفظ بالمراجع لطلبك التالي — لا تتضمّنها الأوامر.';

  @override
  String get chatUiReject => 'رفض';

  @override
  String get chatUiReject1 => 'رفض…';

  @override
  String get chatUiReloadMessages => 'إعادة تحميل الرسائل';

  @override
  String get chatUiRemovesItFromTheConversationPermanently =>
      'إزالتها من المحادثة نهائيًا';

  @override
  String get chatUiRename => 'إعادة تسمية';

  @override
  String get chatUiRenameChat => 'إعادة تسمية المحادثة';

  @override
  String get chatUiRenameSession => 'إعادة تسمية الجلسة';

  @override
  String get chatUiRestoreMessages => 'استعادة الرسائل';

  @override
  String get chatUiRestoreRevertedPrompt => 'استعادة الطلب المتراجَع عنه';

  @override
  String get chatUiRestoreTheCurrentlyRevertedSessionState =>
      'استعادة حالة الجلسة المتراجَع عنها حاليًا';

  @override
  String get chatUiResult => 'النتيجة';

  @override
  String get chatUiRetryImagePreview => 'إعادة محاولة معاينة الصورة';

  @override
  String get chatUiRetryLastPrompt => 'إعادة محاولة الطلب الأخير';

  @override
  String get chatUiRetryServerCommands => 'إعادة محاولة أوامر الخادم';

  @override
  String get chatUiRetrying => 'جارٍ إعادة المحاولة';

  @override
  String get chatUiRevert => 'تراجع';

  @override
  String get chatUiRevertFromThisPrompt =>
      'هل تريد التراجع بدءًا من هذا الطلب؟';

  @override
  String get chatUiRevertLastPrompt => 'التراجع عن الطلب الأخير';

  @override
  String get chatUiReviewCommentAddedToThePrompt =>
      'أُضيف تعليق المراجعة إلى الطلب';

  @override
  String get chatUiReviewHandledAppErrorsAndSendA =>
      'مراجعة أخطاء التطبيق المعالَجة وإرسال تقرير ببيانات حساسة محجوبة';

  @override
  String get chatUiReviewTheActualDiffForThisSession =>
      'مراجعة الفروق الفعلية لهذه الجلسة';

  @override
  String get chatUiRollBackMessagesAndFileChangesAfter =>
      'التراجع عن الرسائل وتغييرات الملفات التي تلت الطلب';

  @override
  String get chatUiRunOnYourComputer => 'التشغيل على حاسوبك';

  @override
  String get chatUiRunShellCommand => 'تشغيل أمر صدفة';

  @override
  String get chatUiRunningTools => 'الأدوات قيد التشغيل';

  @override
  String get chatUiSaveTheConversationAsAMarkdownFile =>
      'حفظ المحادثة كملف Markdown';

  @override
  String get chatUiScope => 'النطاق';

  @override
  String get chatUiSearchMessages => 'البحث في الرسائل';

  @override
  String get chatUiSearchMobileActionsAndServerProvidedCommands =>
      'البحث في إجراءات الهاتف والأوامر التي يقدّمها الخادم';

  @override
  String get chatUiSearchText => 'البحث عن نص';

  @override
  String get chatUiSeeFullDiff => 'عرض الفروق كاملة';

  @override
  String get chatUiSelectAModelBeforeCompactingThisSession =>
      'اختر نموذجًا قبل اختصار هذه الجلسة.';

  @override
  String get chatUiSend => 'إرسال';

  @override
  String get chatUiSendAfterThisRun => 'الإرسال بعد هذا التشغيل';

  @override
  String get chatUiSendNowAndSteerInstead =>
      'الإرسال الآن والتوجيه بدلًا من ذلك';

  @override
  String get chatUiSendNowAndSteerTheCurrentRun =>
      'الإرسال الآن وتوجيه التشغيل الحالي';

  @override
  String get chatUiSendNowAndSteerThisRun => 'الإرسال الآن وتوجيه هذا التشغيل';

  @override
  String get chatUiSendRejection => 'إرسال الرفض';

  @override
  String get chatUiSendSteersTheCurrentRun => 'الإرسال يوجّه التشغيل الحالي';

  @override
  String get chatUiSendWaitsForThisRunToFinish =>
      'الإرسال ينتظر انتهاء هذا التشغيل';

  @override
  String get chatUiSendsAfterThisRunFinishes => 'يُرسل بعد انتهاء هذا التشغيل';

  @override
  String get chatUiServerCommands => 'أوامر الخادم';

  @override
  String get chatUiServerCommandsCouldNotBeRefreshed =>
      'تعذّر تحديث أوامر الخادم';

  @override
  String get chatUiServerMessage => 'رسالة من الخادم';

  @override
  String get chatUiServerStatus => 'حالة الخادم';

  @override
  String get chatUiSessionChanges => 'تغييرات الجلسة';

  @override
  String get chatUiSessionContext => 'سياق الجلسة';

  @override
  String get chatUiSessionIsNoLongerShared => 'لم تعد الجلسة مشتركة';

  @override
  String get chatUiSessionMenu => 'قائمة الجلسة';

  @override
  String get chatUiSessionSharedCopyTheVisibleLinkManually =>
      'شُوركت الجلسة. انسخ الرابط الظاهر يدويًا.';

  @override
  String get chatUiShareLinkCopied => 'نُسخ رابط المشاركة';

  @override
  String get chatUiShareSession => 'مشاركة الجلسة';

  @override
  String get chatUiShareThisSession => 'هل تريد مشاركة هذه الجلسة؟';

  @override
  String get chatUiSharedAnyoneWithTheLinkCanView =>
      'مشتركة: يمكن لأي شخص لديه الرابط الاطّلاع عليها';

  @override
  String get chatUiShowAllCommands => 'عرض كل الأوامر';

  @override
  String get chatUiShowAllSubagentSessions => 'عرض كل جلسات الوكلاء الفرعيين';

  @override
  String get chatUiShowAllSubagents => 'عرض كل الوكلاء الفرعيين';

  @override
  String get chatUiShowFullPrompt => 'عرض الطلب كاملًا';

  @override
  String get chatUiShowLess => 'عرض أقل';

  @override
  String get chatUiShowTimestamps => 'عرض الطوابع الزمنية';

  @override
  String get chatUiSkill => 'مهارة ·';

  @override
  String get chatUiSkills => 'المهارات';

  @override
  String get chatUiSlashCommandsAndAgents =>
      'الأوامر ذات الشرطة المائلة والوكلاء';

  @override
  String get chatUiStartACleanSessionInThisWorkspace =>
      'بدء جلسة جديدة خالية من السياق في مساحة العمل هذه';

  @override
  String get chatUiStartANewSessionWithThisPrompt =>
      'بدء جلسة جديدة بهذا الطلب في محرّر الرسالة';

  @override
  String get chatUiStartCoding => 'بدء البرمجة';

  @override
  String get chatUiStartOne => 'بدء محادثة';

  @override
  String get chatUiSteer => 'توجيه';

  @override
  String get chatUiSteeringAtTheNextStep => 'التوجيه في الخطوة التالية';

  @override
  String get chatUiStopSharing => 'إيقاف المشاركة';

  @override
  String get chatUiSubagent => 'وكيل فرعي';

  @override
  String get chatUiSubagentFailed => 'فشل الوكيل الفرعي.';

  @override
  String get chatUiSubagentWorking => 'الوكيل الفرعي يعمل…';

  @override
  String get chatUiSubagentsCouldNotBeLoaded => 'تعذّر تحميل الوكلاء الفرعيين';

  @override
  String get chatUiSummarizeTheSessionUsingTheSelectedModel =>
      'تلخيص الجلسة باستخدام النموذج المحدّد';

  @override
  String get chatUiSwitchOrganization => 'تبديل المؤسسة';

  @override
  String get chatUiSwitchProjectDirectoryOrWorktree =>
      'تبديل المشروع أو المجلد أو شجرة العمل';

  @override
  String get chatUiSystemUpdate => 'تحديث النظام';

  @override
  String get chatUiTellTheAgentWhyOrWhatTo =>
      'أخبر الوكيل بالسبب أو بما ينبغي فعله بدلًا من ذلك (اختياري)';

  @override
  String get chatUiThatMessageIsNoLongerInThis =>
      'لم تعد تلك الرسالة في هذه الجلسة.';

  @override
  String get chatUiTheFileHasNoContentToAttach =>
      'لا يحتوي الملف على محتوى لإرفاقه.';

  @override
  String get chatUiTheFileHasNoContentToSave =>
      'لا يحتوي الملف على محتوى لحفظه.';

  @override
  String get chatUiTheFormOrProjectChangedReopenThe =>
      'تغيّر النموذج أو المشروع. افتح الطلب الحالي مجددًا.';

  @override
  String get chatUiTheGeneratedFileIsNotAvailableFrom =>
      'الملف المُنشأ غير متاح من هذا الخادم.';

  @override
  String get chatUiTheMessageAndAllOfItsParts =>
      'ستُحذف الرسالة وكل أجزائها نهائيًا من المحادثة، ولن تكون متاحة للردود اللاحقة. لن يُتراجع عن تغييرات الملفات التي أجرتها.';

  @override
  String get chatUiTheServerReturnedEmptyImageData =>
      'أعاد الخادم بيانات صورة فارغة.';

  @override
  String get chatUiThisDraftHasNotBeenSentTo =>
      'لم تُرسل هذه المسودة إلى OpenCode.';

  @override
  String get chatUiThisDraftIsTooLargeToQueue =>
      'هذه المسودة أكبر من أن تُضاف إلى قائمة الانتظار، أو أن القائمة ممتلئة بمسودات أحدث. أزل مرفقًا أو امسح الطلبات في قائمة الانتظار من الإعدادات.';

  @override
  String get chatUiThisPromptCannotBeRestoredBecauseAn =>
      'لا يمكن استعادة هذا الطلب لأن أحد المرفقات غير متاح.';

  @override
  String get chatUiThisPromptCannotBeRetriedBecauseAn =>
      'لا يمكن إعادة محاولة هذا الطلب لأن أحد المرفقات غير متاح.';

  @override
  String get chatUiTimeTokensAndCostUnderEachMessage =>
      'الوقت والرموز والتكلفة أسفل كل رسالة';

  @override
  String get chatUiTimeline => 'التسلسل الزمني';

  @override
  String get chatUiTimestampsUsage => 'الطوابع الزمنية والاستخدام';

  @override
  String get chatUiTipTypeForCommandsTap => 'تلميح: اكتب / للأوامر · اضغط ';

  @override
  String get chatUiTitle => 'العنوان';

  @override
  String get chatUiTodoList => 'قائمة المهام';

  @override
  String get chatUiTodos => 'المهام';

  @override
  String get chatUiToggleCreationTimesBesideTranscriptEntries =>
      'إظهار أوقات الإنشاء أو إخفاؤها بجانب عناصر سجل المحادثة';

  @override
  String get chatUiToggleLongReasoningDetailsAcrossTheTranscript =>
      'إظهار تفاصيل الاستدلال الطويلة أو إخفاؤها في سجل المحادثة';

  @override
  String get chatUiToolFailed => 'فشلت الأداة.';

  @override
  String get chatUiTools => 'الأدوات';

  @override
  String get chatUiToolsAndCapabilities => 'الأدوات والقدرات';

  @override
  String get chatUiTranscript => 'سجل المحادثة';

  @override
  String get chatUiTranscriptCopiedAsMarkdown =>
      'نُسخ سجل المحادثة بصيغة Markdown';

  @override
  String get chatUiTranscriptDisplay => 'عرض سجل المحادثة';

  @override
  String get chatUiTranscriptSaved => 'حُفظ سجل المحادثة';

  @override
  String get chatUiViews => 'طرق العرض';

  @override
  String get chatUiVoiceConversationWasInterrupted =>
      'انقطعت المحادثة الصوتية.';

  @override
  String get chatUiVoiceInput => 'الإدخال الصوتي';

  @override
  String get chatUiVoiceInputIsUnavailable => 'الإدخال الصوتي غير متاح.';

  @override
  String get chatUiWaitForTheCurrentRunToFinish =>
      'انتظر انتهاء التشغيل الحالي، ثم أرسل';

  @override
  String get chatUiWaitForThisRunInstead => 'انتظار هذا التشغيل بدلًا من ذلك';

  @override
  String get chatUiWaitingForThisRunToFinish => 'بانتظار انتهاء هذا التشغيل';

  @override
  String get chatUiWebSearch => 'البحث في الويب';

  @override
  String get chatUiWhatChangedRecently => 'ما الذي تغيّر مؤخرًا؟';

  @override
  String get chatUiWhenTheAssistantPlansWorkAsA =>
      'عندما يخطط المساعد للعمل في صورة قائمة مهام، تظهر عناصرها هنا.';

  @override
  String get chatUiWrite => 'كتابة';

  @override
  String get chatUiWriteYourOpenCodePrompt => 'اكتب طلبك إلى OpenCode…';

  @override
  String get chatUiYou => 'أنت';

  @override
  String get chatUiYourOriginalComposerDraftAndAttachmentsWill =>
      'ستبقى مسودتك الأصلية في محرّر الرسالة ومرفقاتها دون تغيير.';

  @override
  String get chatUiInThisChat => 'في هذه المحادثة';

  @override
  String get chatUiIncludesStepsNotRun => 'يتضمّن خطوات لم تُنفّذ';

  @override
  String get chatUiNewFile => 'ملف جديد';

  @override
  String get chatUiOpencodeAssistant => 'مساعد opencode';

  @override
  String get chatUiSearchedOnce => 'بُحث مرة واحدة';

  @override
  String get chatUiYouUser => 'أنت، المستخدم';

  @override
  String chatUiQueuedWithEviction(Object detail) {
    return 'في قائمة الانتظار، سيُرسَل عند إعادة الاتصال. $detail';
  }

  @override
  String chatUiCommandUnavailable(Object command) {
    return '‎/$command غير متاح حاليًا.';
  }

  @override
  String chatUiAttachmentCountLimit(Object count) {
    return 'يمكنك إرفاق ما يصل إلى $count ملفات.';
  }

  @override
  String chatUiQueuedSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُرسل $count طلب من قائمة الانتظار',
      many: 'أُرسل $count طلبًا من قائمة الانتظار',
      few: 'أُرسلت $count طلبات من قائمة الانتظار',
      two: 'أُرسل طلبان من قائمة الانتظار',
      one: 'أُرسل طلب واحد من قائمة الانتظار',
      zero: 'لم يُرسَل أي طلب من قائمة الانتظار',
    );
    return '$_temp0';
  }

  @override
  String chatUiOtherDraftsWaitingSuffix(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسودة تنتظر خوادم أخرى',
      many: '$count مسودة تنتظر خوادم أخرى',
      few: '$count مسودات تنتظر خوادم أخرى',
      two: 'مسودتان تنتظران خوادم أخرى',
      one: 'مسودة واحدة تنتظر خوادم أخرى',
      zero: 'لا مسودات تنتظر خوادم أخرى',
    );
    return ' · $_temp0';
  }

  @override
  String chatUiNextTurnsModel(Object model) {
    return 'ستستخدم الأدوار التالية في هذه الجلسة $model.';
  }

  @override
  String chatUiReferenceAlreadyAdded(Object name) {
    return '‎@$name موجود بالفعل في الطلب';
  }

  @override
  String chatUiFileAttached(Object filename) {
    return 'تم إرفاق $filename. أضف تعليقك.';
  }

  @override
  String chatUiSaveFile(Object filename) {
    return 'حفظ $filename';
  }

  @override
  String chatUiFileSaved(Object filename) {
    return 'تم حفظ $filename على جهازك.';
  }

  @override
  String chatUiDraftsQueued(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسودة في قائمة الانتظار للإرسال عند إعادة الاتصال.',
      many: '$count مسودة في قائمة الانتظار للإرسال عند إعادة الاتصال.',
      few: '$count مسودات في قائمة الانتظار للإرسال عند إعادة الاتصال.',
      two: 'مسودتان في قائمة الانتظار للإرسال عند إعادة الاتصال.',
      one: 'مسودة واحدة في قائمة الانتظار للإرسال عند إعادة الاتصال.',
      zero: 'لا مسودات في قائمة الانتظار.',
    );
    return '$_temp0';
  }

  @override
  String chatUiOtherDraftsWaiting(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسودة تنتظر خوادم أخرى.',
      many: '$count مسودة تنتظر خوادم أخرى.',
      few: '$count مسودات تنتظر خوادم أخرى.',
      two: 'مسودتان تنتظران خوادم أخرى.',
      one: 'مسودة واحدة تنتظر خوادم أخرى.',
      zero: 'لا مسودات تنتظر خوادم أخرى.',
    );
    return '$_temp0';
  }

  @override
  String chatUiQuestionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سؤال',
      many: '$count سؤالًا',
      few: '$count أسئلة',
      two: 'سؤالان',
      one: 'سؤال واحد',
      zero: 'لا أسئلة',
    );
    return '$_temp0';
  }

  @override
  String chatUiPermissionNeeded(Object title) {
    return 'إذن مطلوب: $title';
  }

  @override
  String chatUiQuestionLabel(Object title) {
    return 'سؤال: $title';
  }

  @override
  String chatUiQuestionsSummary(Object question, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سؤال',
      many: '$count سؤالًا',
      few: '$count أسئلة',
      two: 'سؤالان',
      one: 'سؤال واحد',
      zero: 'لا أسئلة',
    );
    return '$question · $_temp0';
  }

  @override
  String chatUiRateLimitRetry(Object attempt) {
    return 'تم تجاوز حد المعدل. تجري إعادة المحاولة$attempt…';
  }

  @override
  String chatUiRateLimitCountdown(Object attempt, Object time) {
    return 'تم تجاوز حد المعدل. إعادة المحاولة$attempt بعد $time';
  }

  @override
  String chatUiReferencesAttachedNotice(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يُضاف $count مرجع كنص عند الإرسال. لا تُحفظ مع مسودتك.',
      many: 'يُضاف $count مرجعًا كنص عند الإرسال. لا تُحفظ مع مسودتك.',
      few: 'تُضاف $count مراجع كنص عند الإرسال. لا تُحفظ مع مسودتك.',
      two: 'يُضاف مرجعان كنص عند الإرسال. لا يُحفظان مع مسودتك.',
      one: 'يُضاف مرجع واحد كنص عند الإرسال. لا يُحفظ مع مسودتك.',
      zero: 'لا تُضاف مراجع عند الإرسال.',
    );
    return '$_temp0';
  }

  @override
  String chatUiAttachedCount(Object count) {
    return '$count مرفق';
  }

  @override
  String chatUiModelAndAgentHint(Object model, Object cost) {
    return 'النموذج والوكيل: $model. اضغط للتغيير.$cost';
  }

  @override
  String chatUiContextPercentFull(Object percent) {
    return 'السياق ممتلئ بنسبة $percent٪';
  }

  @override
  String chatUiRemoveReferenceName(Object name) {
    return 'إزالة المرجع ‎@$name';
  }

  @override
  String chatUiRemoveAttachmentName(Object name) {
    return 'إزالة المرفق $name';
  }

  @override
  String chatUiReferenceName(Object name) {
    return 'المرجع ‎@$name';
  }

  @override
  String chatUiPreviewAttachmentName(Object name) {
    return 'معاينة المرفق $name';
  }

  @override
  String chatUiProjectReferenceName(Object name) {
    return 'مرجع المشروع ‎@$name';
  }

  @override
  String chatUiPreviewName(Object name) {
    return 'معاينة $name';
  }

  @override
  String chatUiRemoveContextReference(Object name) {
    return 'إزالة المرجع $name';
  }

  @override
  String chatUiContextPercentUsed(Object percent) {
    return 'استُخدم $percent بالمئة من نافذة السياق';
  }

  @override
  String chatUiExplainProject(Object name) {
    return 'اشرح مشروع $name';
  }

  @override
  String chatUiEarlierMessageCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة سابقة',
      many: '$count رسالة سابقة',
      few: '$count رسائل سابقة',
      two: 'رسالتان سابقتان',
      one: 'رسالة سابقة واحدة',
      zero: 'لا رسائل سابقة',
    );
    return '$_temp0';
  }

  @override
  String chatUiPreviouslyValue(Object value) {
    return 'سابقًا $value';
  }

  @override
  String chatUiToolGroupSemantics(Object title, num count, Object status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خطوة',
      many: '$count خطوة',
      few: '$count خطوات',
      two: 'خطوتان',
      one: 'خطوة واحدة',
      zero: 'لا خطوات',
    );
    return '$title، $_temp0، $status';
  }

  @override
  String chatUiTokenCount(Object count) {
    return '$count رمز';
  }

  @override
  String chatUiAttachmentType(Object type) {
    return '$type · مرفق الطلب';
  }

  @override
  String chatUiPositionOfTotal(Object position, Object total) {
    return '$position من $total';
  }

  @override
  String chatUiSubagentCount(Object count) {
    return 'وكيل فرعي · $count';
  }

  @override
  String chatUiSharedLink(Object url) {
    return 'رابط الجلسة المشتركة $url';
  }

  @override
  String chatUiAttachmentCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرفق',
      many: '$count مرفقًا',
      few: '$count مرفقات',
      two: 'مرفقان',
      one: 'مرفق واحد',
      zero: 'لا مرفقات',
    );
    return '$_temp0';
  }

  @override
  String chatUiFailedDetail(Object error) {
    return 'فشل: $error';
  }

  @override
  String chatUiQueuedDraftLabel(Object label) {
    return 'مسودة في قائمة الانتظار. $label';
  }

  @override
  String chatUiPendingSendLabel(Object label) {
    return 'إرسال معلّق. $label';
  }

  @override
  String chatUiPermissionContext(Object permission, Object context) {
    return 'السياق: $permission $context';
  }

  @override
  String chatUiPermissionRequested(Object permission) {
    return 'يريد الوكيل استخدام $permission.';
  }

  @override
  String chatUiReplyFailed(Object error) {
    return 'فشل الرد: $error';
  }

  @override
  String chatUiCopyResource(Object resource) {
    return 'نسخ $resource';
  }

  @override
  String chatUiPriorityLabel(Object priority) {
    return 'أولوية $priority';
  }

  @override
  String chatUiDeleteChatBody(Object title) {
    return 'ستُحذف «$title» وسجلها نهائيًا.';
  }

  @override
  String chatUiChangedFilesSuffix(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا ملفات',
    );
    return ' · $_temp0';
  }

  @override
  String chatUiToolsSummary(Object tools) {
    return 'الأدوات: $tools';
  }

  @override
  String chatUiFromLine(Object line) {
    return 'من السطر $line';
  }

  @override
  String chatUiLineCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر',
      many: '$count سطرًا',
      few: '$count أسطر',
      two: 'سطران',
      one: 'سطر واحد',
      zero: 'لا أسطر',
    );
    return '$_temp0';
  }

  @override
  String chatUiLineRange(Object start, Object end) {
    return '‎L$start–$end';
  }

  @override
  String chatUiEntryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String chatUiFoundCount(Object count) {
    return 'عُثر على $count';
  }

  @override
  String chatUiMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطابق',
      many: '$count تطابقًا',
      few: '$count تطابقات',
      two: 'تطابقان',
      one: 'تطابق واحد',
      zero: 'لا تطابقات',
    );
    return '$_temp0';
  }

  @override
  String chatUiExitCode(Object code) {
    return 'رمز الخروج $code';
  }

  @override
  String chatUiFileCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا ملفات',
    );
    return '$_temp0';
  }

  @override
  String chatUiProviderSearch(Object provider) {
    return 'بحث $provider';
  }

  @override
  String chatUiResultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      many: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String chatUiCompletedCount(Object done, Object total) {
    return 'اكتمل $done/$total';
  }

  @override
  String chatUiAnsweredCount(Object count) {
    return 'تمت الإجابة عن $count';
  }

  @override
  String chatUiAskedCount(Object count) {
    return 'طُرح $count';
  }

  @override
  String chatUiDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes د $seconds ث';
  }

  @override
  String chatUiDurationSeconds(Object seconds) {
    return '$seconds ث';
  }

  @override
  String chatUiFileLoadFailed(Object error) {
    return 'تعذّر تحميل هذا الملف من خادم OpenCode: $error';
  }

  @override
  String chatUiMoreEntries(Object total) {
    return '$total إجمالًا · المزيد متاح';
  }

  @override
  String chatUiEntryTotal(Object total) {
    return '$total عنصر';
  }

  @override
  String chatUiSeeAllLines(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر',
      many: '$count سطرًا',
      few: '$count أسطر',
      two: 'سطران',
      one: 'سطر واحد',
      zero: 'لا أسطر',
    );
    return 'عرض الكل · $_temp0';
  }

  @override
  String chatUiAnsweredDetail(Object answer) {
    return 'الإجابة: $answer';
  }

  @override
  String chatUiLoadingFile(Object filename) {
    return 'جارٍ تحميل $filename';
  }

  @override
  String chatUiPreviewGeneratedImage(Object filename) {
    return 'معاينة الصورة المُنشأة $filename';
  }

  @override
  String chatUiOpenGeneratedFile(Object filename) {
    return 'فتح الملف المُنشأ $filename';
  }

  @override
  String chatUiParentSession(Object title) {
    return 'الجلسة الأصل · $title';
  }

  @override
  String chatUiRunningAgentCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وكيل يعملون',
      many: '$count وكيلًا يعملون',
      few: '$count وكلاء يعملون',
      two: 'وكيلان يعملان',
      one: 'وكيل واحد يعمل',
      zero: 'لا وكلاء يعملون',
    );
    return '$_temp0';
  }

  @override
  String chatUiChooseOption(Object option) {
    return 'اختيار: $option';
  }

  @override
  String get chatUiConversation => 'المحادثة';

  @override
  String get chatUiDisplayAndContext => 'العرض والسياق';

  @override
  String get chatUiSessionActions => 'إجراءات الجلسة';

  @override
  String get chatUiResults => 'النتائج';

  @override
  String get chatUiPermissionFallback => 'إذن';

  @override
  String get chatUiUntitledChat => 'محادثة بلا عنوان';

  @override
  String get chatUiMainSession => 'الجلسة الرئيسية';

  @override
  String get chatUiTodo => 'المهام';

  @override
  String get chatUiBackgroundResult => 'نتيجة العمل في الخلفية';

  @override
  String get chatUiBackgroundComplete => 'اكتمل';

  @override
  String get chatUiBackgroundError => 'فشل';

  @override
  String get chatUiBackgroundCancelled => 'أُلغي';

  @override
  String get chatUiResultDetails => 'تفاصيل النتيجة';

  @override
  String get chatUiResultSourceDetails => 'تفاصيل رسالة الخادم';

  @override
  String get chatUiResultOpenChild => 'فتح جلسة الوكيل الفرعي';

  @override
  String get chatUiNoResultText => 'لم يُرجع الخادم أي نص للنتيجة.';

  @override
  String get chatUiBackground => 'في الخلفية';

  @override
  String get chatUiTimedOut => 'انتهت المهلة';

  @override
  String get chatUiKilled => 'أُوقف';

  @override
  String get chatUiTruncated => 'مقتطع';

  @override
  String get chatUiUpdated => 'محدَّث';

  @override
  String get chatUiPending => 'قيد الانتظار';

  @override
  String get chatUiRunning => 'قيد التشغيل';

  @override
  String get chatUiCompleted => 'اكتمل';

  @override
  String get chatUiError => 'خطأ';

  @override
  String get chatUiUnknownStatus => 'حالة غير معروفة';

  @override
  String get chatUiAssistant => 'المساعد';

  @override
  String get chatUiUser => 'المستخدم';

  @override
  String get chatUiOpenCodeSession => 'جلسة OpenCode';

  @override
  String get chatUiTool => 'أداة';

  @override
  String get chatUiFile => 'ملف';

  @override
  String get chatUiSeparator => '، ';

  @override
  String chatUiReadFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قرأ $count ملف',
      many: 'قرأ $count ملفًا',
      few: 'قرأ $count ملفات',
      two: 'قرأ ملفين',
      one: 'قرأ ملفًا واحدًا',
      zero: 'لم يقرأ أي ملف',
    );
    return '$_temp0';
  }

  @override
  String chatUiSearched(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بحث $count مرة',
      many: 'بحث $count مرة',
      few: 'بحث $count مرات',
      two: 'بحث مرتين',
      one: 'بحث مرة واحدة',
      zero: 'لم يبحث',
    );
    return '$_temp0';
  }

  @override
  String chatUiListedFolders(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استعرض $count مجلد',
      many: 'استعرض $count مجلدًا',
      few: 'استعرض $count مجلدات',
      two: 'استعرض مجلدين',
      one: 'استعرض مجلدًا واحدًا',
      zero: 'لم يستعرض أي مجلد',
    );
    return '$_temp0';
  }

  @override
  String chatUiEditedFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عدّل $count ملف',
      many: 'عدّل $count ملفًا',
      few: 'عدّل $count ملفات',
      two: 'عدّل ملفين',
      one: 'عدّل ملفًا واحدًا',
      zero: 'لم يعدّل أي ملف',
    );
    return '$_temp0';
  }

  @override
  String chatUiRanCommands(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'شغّل $count أمر',
      many: 'شغّل $count أمرًا',
      few: 'شغّل $count أوامر',
      two: 'شغّل أمرين',
      one: 'شغّل أمرًا واحدًا',
      zero: 'لم يشغّل أي أمر',
    );
    return '$_temp0';
  }

  @override
  String chatUiFetchedPages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'جلب $count صفحة',
      many: 'جلب $count صفحة',
      few: 'جلب $count صفحات',
      two: 'جلب صفحتين',
      one: 'جلب صفحة واحدة',
      zero: 'لم يجلب أي صفحة',
    );
    return '$_temp0';
  }

  @override
  String chatUiDelegatedTasks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فوّض $count مهمة',
      many: 'فوّض $count مهمة',
      few: 'فوّض $count مهام',
      two: 'فوّض مهمتين',
      one: 'فوّض مهمة واحدة',
      zero: 'لم يفوّض أي مهمة',
    );
    return '$_temp0';
  }

  @override
  String chatUiOtherCalls(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أجرى $count استدعاء آخر',
      many: 'أجرى $count استدعاءً آخر',
      few: 'أجرى $count استدعاءات أخرى',
      two: 'أجرى استدعاءين آخرين',
      one: 'أجرى استدعاءً آخر واحدًا',
      zero: 'لم يُجرِ استدعاءات أخرى',
    );
    return '$_temp0';
  }

  @override
  String chatUiStepsNotRun(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم تُنفَّذ $count خطوة',
      many: 'لم تُنفَّذ $count خطوة',
      few: 'لم تُنفَّذ $count خطوات',
      two: 'لم تُنفَّذ خطوتان',
      one: 'لم تُنفَّذ خطوة واحدة',
      zero: 'نُفّذت كل الخطوات',
    );
    return '$_temp0';
  }

  @override
  String get e7LibraryReportABug => 'الإبلاغ عن مشكلة';

  @override
  String get e7LibraryKeyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get e7LibraryHTTPHeader => 'ترويسة HTTP';

  @override
  String get e7LibraryEnvironmentVariable => 'متغير بيئة';

  @override
  String get e7LibraryOpenCodeIsReconnectingTryAgainShortly =>
      'يعيد OpenCode الاتصال. حاول مجددًا بعد قليل.';

  @override
  String e7LibraryButTheAppCouldNotReconnect(String detail1, String detail2) {
    return '$detail1، لكن تعذّر على التطبيق إعادة الاتصال. $detail2';
  }

  @override
  String get e7LibraryWhatIsMCP => 'ما هو MCP؟';

  @override
  String get e7LibrarySavingConfiguration => 'جارٍ حفظ الإعدادات';

  @override
  String get e7LibrarySaveMCPServer => 'حفظ خادم MCP';

  @override
  String get e7LibraryPersistedConfiguration => 'إعدادات محفوظة';

  @override
  String get e7LibrarySavedByOpenCodeOnTheServerIt =>
      'يحفظها OpenCode على الخادم، وتبقى متاحة بعد إعادة تشغيل التطبيق أو الخادم.';

  @override
  String get e7LibraryThisProject => 'هذا المشروع';

  @override
  String e7LibraryWritesOnlyTo(String detail1) {
    return 'يكتب في $detail1 فقط.';
  }

  @override
  String get e7LibraryWritesToThisOpenCodeServerSGlobal =>
      'يكتب في الإعدادات العامة لخادم OpenCode هذا.';

  @override
  String get e7LibraryServerName => 'اسم الخادم';

  @override
  String get e7LibraryDocsOrBrowserTools => 'مثل docs أو browser-tools';

  @override
  String get e7LibraryUniqueWithinTheSelectedConfiguration =>
      'اسم فريد ضمن الإعدادات المحددة.';

  @override
  String get e7LibraryEnterAServerName => 'أدخل اسمًا للخادم';

  @override
  String get e7LibraryRemoteURL => 'رابط بعيد';

  @override
  String get e7LibraryLocalCommand => 'أمر محلي';

  @override
  String get e7LibraryTimeoutInMilliseconds => 'المهلة بالمللي ثانية';

  @override
  String get e7LibraryOptional => 'اختياري';

  @override
  String get e7LibraryEnterAValueGreaterThanZero => 'أدخل قيمة أكبر من صفر';

  @override
  String get e7LibraryMCPEndpointURL => 'رابط نقطة اتصال MCP';

  @override
  String get e7LibraryHTTPIsAcceptedForLocalDevelopmentServers =>
      'يمكن استخدام HTTP مع خوادم التطوير المحلية.';

  @override
  String get e7LibraryEnterAValidHTTPOrHTTPSURL =>
      'أدخل رابط HTTP أو HTTPS صالحًا لا يحتوي على بيانات اعتماد';

  @override
  String get e7LibraryHTTPHeaders => 'ترويسات HTTP';

  @override
  String get e7LibraryOptionalEnterOneKEYVALUEPairPer =>
      'اختياري. أدخل زوجًا واحدًا بصيغة KEY=VALUE في كل سطر.';

  @override
  String get e7LibraryDetectOAuthAutomatically => 'اكتشاف OAuth تلقائيًا';

  @override
  String get e7LibraryTurnThisOffWhenTheServerUses =>
      'أوقف هذا الخيار إذا كان الخادم يستخدم الترويسات ولا ينبغي له بدء OAuth مطلقًا.';

  @override
  String get e7LibraryCommandAndArguments => 'الأمر والوسائط';

  @override
  String get e7LibraryRunsOnTheOpenCodeServerNotThis =>
      'يُنفَّذ على خادم OpenCode وليس على هذا الهاتف. أدخل وسيطة واحدة في كل سطر.';

  @override
  String get e7LibraryEnterACommand => 'أدخل أمرًا';

  @override
  String get e7LibraryWorkingDirectory => 'مجلد العمل';

  @override
  String get e7LibraryOptionalServerPath => 'مسار اختياري على الخادم';

  @override
  String get e7LibraryEnvironmentVariables => 'متغيرات البيئة';

  @override
  String e7LibraryInvalidOnLineUseKEYVALUE(String detail1, String detail2) {
    return 'قيمة $detail1 غير صالحة في السطر $detail2. استخدم KEY=VALUE.';
  }

  @override
  String e7LibraryInvalidNameOnLine(String detail1, String detail2) {
    return 'اسم $detail1 غير صالح في السطر $detail2.';
  }

  @override
  String e7LibraryDuplicateName(String detail1, String detail2) {
    return 'اسم $detail1 مكرر: «$detail2».';
  }

  @override
  String get e7LibraryOpenCodeIsReconnectingTryAgain =>
      'يعيد OpenCode الاتصال. حاول مجددًا.';

  @override
  String get e7LibraryRevokeAlwaysAllowedAction => 'إلغاء الإذن؟';

  @override
  String get e7LibraryOpenCodeWillAskAgainBeforeAFuture =>
      'سيطلب OpenCode إذنك مجددًا قبل تنفيذ أي إجراء لاحق يطابق هذا الإذن.';

  @override
  String get e7LibraryAction => 'الإجراء';

  @override
  String get e7LibraryResource => 'المورد';

  @override
  String get e7LibraryAllMatchingResources => '(جميع الموارد المطابقة)';

  @override
  String get e7LibraryThisDoesNotStopAnActionThat =>
      'لن يوقف هذا إجراءً قيد التنفيذ.';

  @override
  String get e7LibraryKeepAccess => 'الإبقاء على الإذن';

  @override
  String get e7LibraryRevokeAccess => 'إلغاء الإذن';

  @override
  String get e7LibraryAlwaysAllowedActionRevoked =>
      'أُلغي السماح الدائم للإجراء';

  @override
  String get e7LibraryAlwaysAllowedActions => 'الإجراءات المسموح بها دائمًا';

  @override
  String get e7LibraryRefreshAlwaysAllowedActions =>
      'تحديث الإجراءات المسموح بها دائمًا';

  @override
  String get e7LibraryNoAlwaysAllowedActions =>
      'لا توجد إجراءات مسموح بها دائمًا';

  @override
  String get e7LibraryGrantsCreatedWithAlwaysAllowForThis =>
      'تظهر هنا الأذونات التي منحتها عبر «السماح دائمًا» لهذا المشروع.';

  @override
  String get e7LibraryTheLastActionFailed => 'فشل الإجراء الأخير';

  @override
  String e7LibraryRevokeAccess2(String detail1) {
    return 'إلغاء الإذن لإجراء $detail1';
  }

  @override
  String get e7LibraryToolsAndCapabilities => 'الأدوات والإمكانات';

  @override
  String get e7LibraryRefreshTools => 'تحديث الأدوات';

  @override
  String get e7LibraryOpenCodeToolsDependOnTheProviderAnd =>
      'تعتمد أدوات OpenCode على مزوّد الخدمة والنموذج المستخدمَين في المحادثة النشطة.';

  @override
  String get e7LibraryChooseModel => 'اختيار النموذج';

  @override
  String get e7LibraryChange => 'تغيير';

  @override
  String get e7LibrarySearchTools => 'البحث في الأدوات';

  @override
  String e7LibrarySearchTools2(String detail1) {
    return 'البحث في الأدوات ($detail1)';
  }

  @override
  String e7LibraryUsable(String detail1) {
    return 'متاح للاستخدام: $detail1';
  }

  @override
  String e7LibraryRegistered(String detail1) {
    return 'مسجّل: $detail1';
  }

  @override
  String get e7LibraryBackgroundSubagentsEnabled =>
      'الوكلاء الفرعيون في الخلفية مفعّلون';

  @override
  String get e7LibraryBackgroundSubagentsUnavailable =>
      'الوكلاء الفرعيون في الخلفية غير متاحين';

  @override
  String get e7LibraryRegisteredInventoryUnavailable =>
      'قائمة الأدوات المسجّلة غير متاحة';

  @override
  String get e7LibraryServerCapabilityUnavailable => 'إمكانات الخادم غير متاحة';

  @override
  String get e7LibraryNoToolsForThisModel => 'لا توجد أدوات لهذا النموذج';

  @override
  String get e7LibraryNoMatchingTools => 'لا توجد أدوات مطابقة';

  @override
  String get e7LibraryOpenCodeReturnedNoCallableToolsForThis =>
      'لم يُرجع OpenCode أدوات يمكن استدعاؤها لمزوّد الخدمة هذا والنموذج المحدد.';

  @override
  String get e7LibraryTryAToolIDOrAWord => 'جرّب معرّف أداة أو كلمة من وصفها.';

  @override
  String get e7LibraryCallableByThisModel => 'يمكن لهذا النموذج استدعاؤها';

  @override
  String get e7LibraryRegisteredNotCallable => 'مسجّلة ولا يمكن استدعاؤها';

  @override
  String get e7LibraryNoDescriptionReturnedByOpenCode =>
      'لم يُرجع OpenCode وصفًا';

  @override
  String e7LibraryRegisteredOnThisProjectButNotReturned(
    String detail1,
    String detail2,
  ) {
    return 'مسجّلة في هذا المشروع، لكن لم تُرجع للنموذج $detail1/$detail2.';
  }

  @override
  String get e7LibraryCopyParameterSchema => 'نسخ مخطط المعلمات';

  @override
  String e7LibrarySchemaCopied(String detail1) {
    return 'نُسخ مخطط $detail1';
  }

  @override
  String get e7LibraryParameterSchema => 'مخطط المعلمات';

  @override
  String get e7LibraryNoProjectSelected => 'لم يُحدَّد مشروع';

  @override
  String get e7LibraryNoProjectFolderIsOpenChooseOne =>
      'لا يوجد مجلد مشروع مفتوح. اختر مجلدًا من مساحة العمل.';

  @override
  String get e7LibraryProject => 'المشروع';

  @override
  String get e7LibrarySwitchProject => 'تبديل المشروع';

  @override
  String get e7LibraryChooseAnotherProjectOpenedByThisServer =>
      'اختيار مشروع آخر مفتوح على هذا الخادم';

  @override
  String get e7LibraryCoding => 'البرمجة';

  @override
  String get e7LibraryWorktrees => 'أشجار العمل';

  @override
  String get e7LibraryChooseAProjectFirst => 'اختر مشروعًا أولًا';

  @override
  String get e7LibraryCreateAndManageIsolatedGitBranches =>
      'إنشاء فروع Git معزولة وإدارتها';

  @override
  String get e7LibraryManagedWorkspaces => 'مساحات العمل المُدارة';

  @override
  String get e7LibraryCreateDiscoverOpenAndRemoveAdapterBacked =>
      'إنشاء بيئات عبر المهايئات واكتشافها وفتحها وإزالتها';

  @override
  String get e7LibraryProjectHealth => 'حالة المشروع';

  @override
  String get e7LibraryBranchChangedFilesLanguageServicesAndFormatters =>
      'الفرع والملفات المتغيرة وخدمات اللغات وأدوات التنسيق';

  @override
  String get e7LibraryOpenCodeIsReconnecting => 'يعيد OpenCode الاتصال.';

  @override
  String get e7LibraryWorkspaceDiscoveryFinished => 'اكتمل اكتشاف مساحات العمل';

  @override
  String e7LibraryCouldNotDiscoverWorkspaces(String detail1) {
    return 'تعذّر اكتشاف مساحات العمل: $detail1';
  }

  @override
  String e7LibraryCouldNotCreateWorkspace(String detail1) {
    return 'تعذّر إنشاء مساحة العمل: $detail1';
  }

  @override
  String e7LibraryWasRemoved(String detail1) {
    return 'أُزيل $detail1';
  }

  @override
  String e7LibraryCouldNotRemoveWorkspace(String detail1) {
    return 'تعذّرت إزالة مساحة العمل: $detail1';
  }

  @override
  String get e7LibraryCloudEnvironments => 'البيئات السحابية';

  @override
  String get e7LibraryDiscoverExistingEnvironments => 'اكتشاف البيئات الموجودة';

  @override
  String get e7LibraryRefreshCloudEnvironments => 'تحديث البيئات السحابية';

  @override
  String get e7LibraryNewEnvironment => 'بيئة جديدة';

  @override
  String get e7LibraryEnvironments => 'البيئات';

  @override
  String get e7LibraryNoCloudEnvironments => 'لا توجد بيئات سحابية';

  @override
  String e7LibraryAdapterBackedEnvironmentsForAppearHereCreate(String detail1) {
    return 'تظهر هنا البيئات المتاحة عبر المهايئات للمشروع $detail1. أنشئ بيئة من مهايئ الخادم، أو استخدم الاكتشاف لتسجيل البيئات التي يعرفها المهايئ بالفعل.';
  }

  @override
  String get e7LibraryEnvironmentRefreshFailed => 'فشل تحديث البيئات';

  @override
  String get e7LibraryRetryCloudEnvironments =>
      'إعادة محاولة تحميل البيئات السحابية';

  @override
  String get e7LibraryAdapters => 'المهايئات';

  @override
  String get e7LibraryAdaptersUnavailable => 'المهايئات غير متاحة';

  @override
  String get e7LibraryRetryWorkspaceAdapters =>
      'إعادة محاولة تحميل مهايئات مساحات العمل';

  @override
  String get e7LibraryNoWorkspaceAdapters => 'لا توجد مهايئات لمساحات العمل';

  @override
  String get e7LibraryThisOpenCodeProjectDoesNotExposeManaged =>
      'لا يتيح مشروع OpenCode هذا إنشاء مساحات عمل مُدارة.';

  @override
  String get e7LibraryAdapterRefreshFailed => 'فشل تحديث المهايئات';

  @override
  String get e7LibraryConnected => 'متصل';

  @override
  String get e7LibraryConnecting => 'جارٍ الاتصال';

  @override
  String get e7LibraryDisconnected => 'غير متصل';

  @override
  String get e7LibraryEnvironmentActions => 'إجراءات البيئة';

  @override
  String get e7LibraryOpenAgain => 'فتح مجددًا';

  @override
  String get e7LibraryNewManagedWorkspace => 'مساحة عمل مُدارة جديدة';

  @override
  String get e7LibraryAdapter => 'المهايئ';

  @override
  String get e7LibraryBranchOptional => 'الفرع (اختياري)';

  @override
  String get e7LibraryUseTheAdapterDefault =>
      'استخدام القيمة الافتراضية للمهايئ';

  @override
  String get e7LibraryOpenCodeConfiguresAdapterSpecificDetailsOnThe =>
      'يضبط OpenCode التفاصيل الخاصة بالمهايئ على الخادم. تُفتح مساحة العمل الجديدة هنا عندما تصبح جاهزة.';

  @override
  String get e7LibraryCreateAndOpen => 'إنشاء وفتح';

  @override
  String e7LibraryRemove(String detail1) {
    return 'إزالة $detail1؟';
  }

  @override
  String get e7LibraryTheServerAdapterMayPermanentlyDeleteThe =>
      'قد يحذف مهايئ الخادم البيئة البعيدة أو شجرة العمل نهائيًا. تبقى المحادثات السابقة، لكن قد لا تعود مساحة العمل قابلة للوصول.';

  @override
  String e7LibraryTypeToConfirm(String detail1) {
    return 'اكتب $detail1 للتأكيد';
  }

  @override
  String get e7LibraryRemovePermanently => 'إزالة نهائية';

  @override
  String e7LibraryIsReady(String detail1) {
    return 'أصبح $detail1 جاهزًا';
  }

  @override
  String get e7LibraryOpenCodeCouldNotPrepareThisWorktree =>
      'تعذّر على OpenCode تجهيز شجرة العمل هذه.';

  @override
  String e7LibraryWasCreatedItsSetupStatusIsNot(String detail1) {
    return 'أُنشئ $detail1. لم تُؤكّد حالة إعداده بعد.';
  }

  @override
  String e7LibraryCreatedOpenCodeIsPreparingIt(String detail1) {
    return 'أُنشئ $detail1. يجهّزه OpenCode الآن.';
  }

  @override
  String get e7LibraryWaitForOpenCodeToFinishPreparingThis =>
      'انتظر حتى ينتهي OpenCode من تجهيز شجرة العمل هذه.';

  @override
  String get e7LibraryOpenCodeDidNotSwitchLocations =>
      'لم يغيّر OpenCode الموقع.';

  @override
  String e7LibraryCouldNotVerifyBeforeThisDestructiveAction(
    String detail1,
    String detail2,
  ) {
    return 'تعذّر التحقق من $detail1 قبل هذا الإجراء الذي يحذف البيانات: $detail2';
  }

  @override
  String e7LibraryResetToTheDefaultBranch(String detail1) {
    return 'أُعيد $detail1 إلى الفرع الافتراضي';
  }

  @override
  String e7LibraryAndItsBranchWereRemoved(String detail1) {
    return 'أُزيل $detail1 وفرعه';
  }

  @override
  String e7LibraryReset(String detail1) {
    return 'إعادة ضبط $detail1؟';
  }

  @override
  String get e7LibraryThisPermanentlyDiscardsTrackedChangesAndDeletes =>
      'سيؤدي هذا إلى تجاهل التغييرات المتتبَّعة نهائيًا وحذف جميع الملفات غير المتتبَّعة والمتجاهَلة. تُعاد الوحدات الفرعية أيضًا إلى حالتها الأصلية وتُنظَّف. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get e7LibraryResetWorktree => 'إعادة ضبط شجرة العمل';

  @override
  String get e7LibraryRefreshWorktrees => 'تحديث أشجار العمل';

  @override
  String get e7LibraryNewWorktree => 'شجرة عمل جديدة';

  @override
  String get e7LibraryPrimary => 'الرئيسية';

  @override
  String get e7LibraryNoIsolatedWorktreesYet => 'لا توجد أشجار عمل معزولة بعد';

  @override
  String get e7LibraryUseIsolatedBranchesForParallelCodingWithout =>
      'استخدم فروعًا معزولة للبرمجة بالتوازي دون خلط التغييرات. أنشئ شجرة عمل عندما تريد من OpenCode العمل على فرع منفصل.';

  @override
  String e7LibraryDefaultProject(String detail1) {
    return 'المشروع الافتراضي · $detail1';
  }

  @override
  String e7LibrarySetupFailed(String detail1) {
    return 'فشل الإعداد · $detail1';
  }

  @override
  String get e7LibraryPreparingFilesAndProjectTasks =>
      'جارٍ تجهيز الملفات ومهام المشروع…';

  @override
  String get e7LibraryWorktreeActions => 'إجراءات شجرة العمل';

  @override
  String get e7LibraryReset2 => 'إعادة ضبط';

  @override
  String get e7LibraryNoChangedFilesWereDetected => 'لم تُكتشف ملفات متغيرة.';

  @override
  String get e7LibraryOpenCodeWillCreateAnIsolatedGitBranch =>
      'سينشئ OpenCode فرع Git ومجلد عمل معزولين. تُنفَّذ مهام بدء المشروع تلقائيًا.';

  @override
  String get e7LibraryNameOptional => 'الاسم (اختياري)';

  @override
  String get e7LibraryOpenCodeMakesTheNameURLSafeAnd =>
      'يجعل OpenCode الاسم فريدًا وصالحًا للاستخدام في الروابط.';

  @override
  String get e7LibraryTheWorktreeDirectoryAndItsGitBranch =>
      'سيُحذف مجلد شجرة العمل وفرع Git الخاص به نهائيًا. تبقى المحادثات السابقة في السجل، لكن مجلد عملها لن يعود موجودًا.';

  @override
  String get e7LibraryInitializeGitRepository => 'تهيئة مستودع Git؟';

  @override
  String get e7LibraryOpenCodeWillRunGitInitInThe =>
      'سينفّذ OpenCode الأمر git init في المشروع الحالي. لن تتغير الملفات الموجودة ولن تُثبَّت في Git. يتيح هذا استخدام الفروع وتغييرات شجرة العمل وميزات المراجعة.';

  @override
  String get e7LibraryInitializeGit => 'تهيئة Git';

  @override
  String get e7LibraryGitRepositoryInitialized => 'تمت تهيئة مستودع Git';

  @override
  String get e7LibraryRefreshProjectHealth => 'تحديث حالة المشروع';

  @override
  String get e7LibraryVersionControl => 'التحكم بالإصدارات';

  @override
  String e7LibraryChanged(String detail1) {
    return 'متغيّر: $detail1';
  }

  @override
  String get e7LibraryLanguageServices => 'خدمات اللغات';

  @override
  String get e7LibraryFormatters => 'أدوات التنسيق';

  @override
  String get e7LibraryVersionControl2 => 'التحكم بالإصدارات';

  @override
  String get e7LibraryGitIsNotInitialized => 'لم تتم تهيئة Git';

  @override
  String get e7LibraryInitializeThisProjectToEnableBranchesWorking =>
      'هيّئ هذا المشروع لاستخدام الفروع وتغييرات شجرة العمل والمراجعة.';

  @override
  String get e7LibraryRunGitInitFromATerminal => 'نفّذ `git init` من الطرفية';

  @override
  String get e7LibraryGitInitializationFailed => 'فشلت تهيئة Git';

  @override
  String get e7LibraryNoActiveBranch => 'لا يوجد فرع نشط';

  @override
  String e7LibraryDefaultBranch(String detail1) {
    return 'الفرع الافتراضي: $detail1';
  }

  @override
  String get e7LibraryWorkingTreeIsClean => 'شجرة العمل خالية من التغييرات';

  @override
  String e7LibraryChangedFiles(String detail1) {
    return 'الملفات المتغيرة: $detail1';
  }

  @override
  String get e7LibraryNoUncommittedChanges => 'لا توجد تغييرات غير مثبَّتة';

  @override
  String get e7LibraryLanguageServices2 => 'خدمات اللغات';

  @override
  String get e7LibraryNoActiveLanguageServices => 'لا توجد خدمات لغات نشطة';

  @override
  String get e7LibraryOpenCodeActivatesThemWhileItInspectsSupported =>
      'يفعّلها OpenCode أثناء فحص ملفات المصدر المدعومة خلال البرمجة.';

  @override
  String get e7LibraryNoFormattersConfigured => 'لا توجد أدوات تنسيق مضبوطة';

  @override
  String get e7LibraryEnabled => 'مفعّل';

  @override
  String get e7LibraryDisabled => 'معطّل';

  @override
  String e7LibraryLoading(String detail1) {
    return 'جارٍ تحميل $detail1';
  }

  @override
  String get e7LibraryLocationChanged => 'تغيّر الموقع.';

  @override
  String get e7LibraryAuthenticateFromTheServerMachine =>
      'سجّل الدخول من جهاز الخادم';

  @override
  String e7LibraryMCPAuthorizationPendingFor(String detail1) {
    return 'تفويض MCP معلّق للخادم $detail1';
  }

  @override
  String get e7LibraryWaitingForBrowserAuthorization =>
      'في انتظار التفويض من المتصفح';

  @override
  String get e7LibraryAutomaticCallbackCaptureIsUnavailablePasteThe =>
      'التقاط رابط العودة تلقائيًا غير متاح. ألصق رابط العودة أو رمز التفويض.';

  @override
  String get e7LibraryThePhoneIsSecurelyListeningForThis =>
      'ينتظر الهاتف رابط العودة لهذا التفويض بأمان. يمكنك إدخاله يدويًا أيضًا.';

  @override
  String get e7LibraryCompleteMCPAuthorization => 'إكمال تفويض MCP';

  @override
  String get e7LibraryCallbackURLOrCode => 'رابط العودة أو الرمز';

  @override
  String get e7LibraryPasteTheCompleteCallbackURLWhenAvailable =>
      'ألصق رابط العودة كاملًا إن أمكن للتحقق من حالة الأمان الخاصة به.';

  @override
  String get e7LibraryComplete => 'إكمال';

  @override
  String get e7LibraryUpdating => 'جارٍ التحديث…';

  @override
  String get e7LibraryNotConnected => 'غير متصل';

  @override
  String get e7LibraryDisconnect => 'قطع الاتصال';

  @override
  String get e7LibraryServerEnvironment => 'بيئة الخادم';

  @override
  String get e7LibraryServerManaged => 'يديره الخادم';

  @override
  String get e7LibraryConnect => 'اتصال';

  @override
  String get e7LibraryAuthenticationFailed => 'فشلت المصادقة';

  @override
  String get e7LibraryAuthenticationAttemptExpired =>
      'انتهت صلاحية محاولة المصادقة';

  @override
  String get e7LibraryAuthenticationComplete => 'اكتملت المصادقة';

  @override
  String get e7LibraryReturnFromTheBrowserAndEnterThe =>
      'عُد من المتصفح وأدخل رمز التفويض.';

  @override
  String get e7LibraryFinishAuthenticationInTheBrowserThenCheck =>
      'أكمل المصادقة في المتصفح، ثم تحقّق من حالتها.';

  @override
  String get e7LibraryFinish => 'إنهاء';

  @override
  String get e7LibraryCheck => 'تحقّق';

  @override
  String e7LibraryConnecting2(String detail1) {
    return 'جارٍ توصيل $detail1';
  }

  @override
  String get e7LibraryAuthenticationOptions => 'خيارات المصادقة';

  @override
  String get e7LibraryCancelAttempt => 'إلغاء المحاولة';

  @override
  String e7LibraryFinish2(String detail1) {
    return 'إكمال $detail1';
  }

  @override
  String get e7LibraryAuthorizationCode => 'رمز التفويض';

  @override
  String get e7LibraryNotYet => 'ليس الآن';

  @override
  String get e7LibrarySelectAnOption => 'اختر خيارًا';

  @override
  String get e7LibraryEnterAValue => 'أدخل قيمة';

  @override
  String get e7LibraryTheServerReturnedAnUnsafeAuthorizationLink =>
      'أرجع الخادم رابط تفويض غير آمن. يُسمح فقط بروابط HTTPS ذات مضيف صالح والخالية من بيانات اعتماد مضمّنة.';

  @override
  String get e7LibraryCouldNotLoadThisSection => 'تعذّر تحميل هذا القسم';

  @override
  String e7LibraryConnectedAvailable(String detail1, String detail2) {
    return 'متصل: $detail1 · متاح: $detail2';
  }

  @override
  String get e7LibrarySkills => 'المهارات';

  @override
  String get e7LibraryNoSkillsAvailable => 'لا توجد مهارات متاحة';

  @override
  String get e7LibraryProjectAndGlobalOpenCodeSkillsAppearHere =>
      'تظهر هنا مهارات OpenCode الخاصة بالمشروع والمهارات العامة.';

  @override
  String get e7LibraryDeprecated => 'متقادم';

  @override
  String get e7LibraryPreview => 'تجريبي';

  @override
  String get e7LibraryModelsAndAgents => 'النماذج والوكلاء';

  @override
  String get e7LibraryNoMatchingModels => 'لا توجد نماذج مطابقة';

  @override
  String get e7LibraryTryAnotherProviderOrModelName =>
      'جرّب اسم مزوّد خدمة أو نموذج آخر.';

  @override
  String e7LibraryContextOutput(String detail1, String detail2) {
    return 'السياق: $detail1 - المخرجات: $detail2';
  }

  @override
  String get e7LibraryNoProvidersConnected => 'لا توجد اتصالات بمزوّدي الخدمة';

  @override
  String get e7LibraryConnectAProviderOnTheOpenCodeServer =>
      'اربط مزوّد خدمة على خادم OpenCode لاستخدام النماذج.';

  @override
  String e7LibraryAvailableModelsAuthenticationIsManagedUnderMCP(
    String detail1,
  ) {
    return 'النماذج المتاحة: $detail1\nتُدار المصادقة ضمن MCP وعمليات التكامل.';
  }

  @override
  String get e7LibraryNoAgentsAvailable => 'لا يوجد وكلاء متاحون';

  @override
  String get e7LibraryNoVisibleAgentsWereReturnedForThis =>
      'لم يُرجع الخادم وكلاء ظاهرين لمساحة العمل هذه.';

  @override
  String e7LibraryContext(String detail1) {
    return 'السياق: $detail1';
  }

  @override
  String e7LibraryOutput(String detail1) {
    return 'المخرجات: $detail1';
  }

  @override
  String get e7LibraryAttachments => 'المرفقات';

  @override
  String get e7LibraryTools => 'الأدوات';

  @override
  String get e7LibraryUseThisModel => 'استخدام هذا النموذج';

  @override
  String get e7LibraryUnavailable => 'غير متاح';

  @override
  String get e7LibraryFinishOrCancelTheCurrentMCPAuthorization =>
      'أكمل تفويض MCP الحالي أو ألغِه أولًا.';

  @override
  String get e7LibraryCouldNotOpenTheAuthorizationPage =>
      'تعذّر فتح صفحة التفويض';

  @override
  String e7LibraryAuthenticated(String detail1) {
    return 'تمت مصادقة $detail1';
  }

  @override
  String get e7LibraryCouldNotConfirmMCPAuthentication =>
      'تعذّر تأكيد مصادقة MCP';

  @override
  String get e7LibraryMCPServerSavedInOpenCode => 'حُفظ خادم MCP في OpenCode';

  @override
  String get e7LibraryMCPUnavailable => 'MCP غير متاح';

  @override
  String get e7LibraryMCPAndIntegrations => 'MCP وعمليات التكامل';

  @override
  String get e7LibraryTheModelProvidersThisOpenCodeServerCan =>
      'مزوّدو الخدمة الذين يمكن لخادم OpenCode هذا استخدام نماذجهم. اربط أحدهم لبدء المحادثة.';

  @override
  String get e7LibraryCouldNotSaveSignInRecovery =>
      'تعذّر حفظ معلومات استعادة تسجيل الدخول.';

  @override
  String get e7LibraryLoadingProviders => 'جارٍ تحميل مزوّدي الخدمة';

  @override
  String get e7LibraryNoProviderConnectionsAvailable =>
      'لا توجد اتصالات متاحة بمزوّدي الخدمة';

  @override
  String get e7LibraryThisServerDidNotReturnAnyProvider =>
      'لم يُرجع هذا الخادم أي تكاملات مع مزوّدي الخدمة.';

  @override
  String e7LibraryNoProvidersMatch(String detail1) {
    return 'لا يوجد مزوّد خدمة يطابق «$detail1»';
  }

  @override
  String get e7LibraryTryAProviderNameItsIdOr =>
      'جرّب اسم مزوّد الخدمة أو معرّفه أو أحد نماذجه.';

  @override
  String get e7LibrarySearchProvidersOrModels =>
      'البحث في مزوّدي الخدمة أو النماذج';

  @override
  String get e7LibraryClearProviderSearch => 'مسح البحث عن مزوّدي الخدمة';

  @override
  String get e7LibrarySERVERS => ' الخوادم';

  @override
  String get e7LibraryAddOnServersThatGiveTheAgent =>
      'خوادم إضافية تمنح الوكيل أدوات أخرى، مثل متصفح أو قاعدة بيانات.';

  @override
  String get e7LibraryLoadingMCPServers => 'جارٍ تحميل خوادم MCP';

  @override
  String get e7LibraryNoMCPServersConfigured => 'لا توجد خوادم MCP مضبوطة';

  @override
  String get e7LibrarySaveOneForThisProjectOrEvery =>
      'احفظ خادمًا لهذا المشروع أو لجميع المشاريع على الخادم.';

  @override
  String get e7LibraryAddAnMCPServer => 'إضافة خادم MCP';

  @override
  String get e7LibraryAuthorizing => 'جارٍ التفويض';

  @override
  String get e7LibraryResources => 'الموارد';

  @override
  String get e7LibraryFilesAndDataThatConnectedMCPServers =>
      'الملفات والبيانات التي تتيحها خوادم MCP المتصلة للوكيل.';

  @override
  String get e7LibraryLoadingAvailableResources => 'جارٍ تحميل الموارد المتاحة';

  @override
  String get e7LibraryNoResourcesAvailable => 'لا توجد موارد متاحة';

  @override
  String get e7LibraryConnectedMCPServersHaveNotExposedAny =>
      'لم تُتِح خوادم MCP المتصلة أي موارد.';

  @override
  String get e7LibraryOpenAuthorizationPage => 'فتح صفحة التفويض؟';

  @override
  String get e7LibraryYouAreLeavingThisAppToAuthenticate =>
      'ستغادر هذا التطبيق لإتمام المصادقة في المتصفح.';

  @override
  String get e7LibraryDestinationHost => 'المضيف الوجهة';

  @override
  String get e7LibraryOpenCodeInstructions => 'تعليمات OpenCode';

  @override
  String get e7LibraryOpenBrowser => 'فتح المتصفح';

  @override
  String get e7LibraryConnectedAndToolsAreAvailable => 'متصل والأدوات متاحة';

  @override
  String get e7LibraryConnectionFailed => 'فشل الاتصال';

  @override
  String get e7LibraryAuthenticationRequired => 'المصادقة مطلوبة';

  @override
  String get e7LibraryClientRegistrationRequired => 'تسجيل العميل مطلوب';

  @override
  String get e7LibraryAuthenticate => 'مصادقة';

  @override
  String e7LibraryStoredCredential(String detail1) {
    return 'بيانات اعتماد محفوظة: $detail1';
  }

  @override
  String e7LibraryServerEnvironment2(String detail1) {
    return 'بيئة الخادم: $detail1';
  }

  @override
  String get e7LibraryNoConnectionMethodsAvailable => 'لا توجد طرق اتصال متاحة';

  @override
  String get e7LibraryConfiguredOnTheServer => 'مُعدّ على الخادم';

  @override
  String e7LibraryDisconnect2(String detail1) {
    return 'قطع اتصال $detail1؟';
  }

  @override
  String e7LibraryTheStoredCredentialWillBeRemovedFrom(String detail1) {
    return 'ستُحذف بيانات الاعتماد المحفوظة من خادم OpenCode هذا. سيتوقف استخدامها في الطلبات الجديدة بعد تحديث بيئة تشغيل مزوّد الخدمة. لن يتوقف الرد الجاري.$detail1';
  }

  @override
  String get e7LibraryDisconnectProvider => 'قطع اتصال مزوّد الخدمة';

  @override
  String e7LibraryCredentialRemovedServerEnvironmentRemainsActive(
    String detail1,
  ) {
    return 'حُذفت بيانات اعتماد $detail1؛ وتبقى بيئة الخادم نشطة';
  }

  @override
  String e7LibraryDisconnected2(String detail1) {
    return 'قُطع اتصال $detail1';
  }

  @override
  String e7LibraryConnect2(String detail1) {
    return 'توصيل $detail1';
  }

  @override
  String get e7LibraryAuthorizationWasNotOpenedThePendingAttempt =>
      'لم تُفتح صفحة التفويض. تبقى المحاولة المعلّقة محفوظة.';

  @override
  String get e7LibraryCouldNotOpenOAuth => 'تعذّر فتح OAuth';

  @override
  String e7LibraryIsConnected(String detail1) {
    return '$detail1 متصل';
  }

  @override
  String get e7LibraryTheSignInSourceChanged => 'تغيّر مصدر تسجيل الدخول.';

  @override
  String get e7LibraryCouldNotConfirmAuthenticationReturnToThe =>
      'تعذّر تأكيد المصادقة. عُد إلى المصدر الأصلي وحاول مجددًا.';

  @override
  String get e7LibrarySearchServerCommands => 'البحث في أوامر الخادم';

  @override
  String get e7LibraryNoServerCommandsFound => 'لم يُعثر على أوامر للخادم';

  @override
  String get e7LibraryCommandsFromYourProjectAndSkillsAppear =>
      'تظهر هنا الأوامر من مشروعك ومهاراتك.';

  @override
  String get e7LibraryNoDescription => 'لا يوجد وصف';

  @override
  String get e7LibraryServerCommands => 'أوامر الخادم';

  @override
  String get e7LibraryReferences => 'المراجع';

  @override
  String get e7LibraryNoReferencesConfigured => 'لا توجد مراجع مضبوطة';

  @override
  String get e7LibraryReferencesAttachedToThisProjectAppearHere =>
      'تظهر هنا المراجع المرتبطة بهذا المشروع.';

  @override
  String e7LibraryCopied(String detail1) {
    return 'نُسخ ‎@$detail1';
  }

  @override
  String e7LibraryGrantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إذن',
      many: '$count إذنًا',
      few: '$count أذونات',
      two: 'إذنان',
      one: 'إذن واحد',
      zero: 'لا أذونات',
    );
    return '$_temp0';
  }

  @override
  String e7LibraryModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نموذج',
      many: '$count نموذجًا',
      few: '$count نماذج',
      two: 'نموذجان',
      one: 'نموذج واحد',
      zero: 'لا نماذج',
    );
    return ' · $_temp0';
  }

  @override
  String e7LibraryChangedFilesDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اكتُشف $count ملف متغيّر.',
      many: 'اكتُشف $count ملفًا متغيّرًا.',
      few: 'اكتُشفت $count ملفات متغيرة.',
      two: 'اكتُشف ملفان متغيّران.',
      one: 'اكتُشف ملف متغيّر واحد.',
      zero: 'لم تُكتشف ملفات متغيرة.',
    );
    return '$_temp0';
  }

  @override
  String get e7LibraryEnvironmentRemainsAfterDisconnect =>
      'يستخدم مزوّد الخدمة هذا أيضًا بيئة الخادم، التي لا يستطيع تطبيق الهاتف إزالتها وستبقى نشطة.';

  @override
  String get e7LibrarySearchPhoneAliases =>
      'local on device setup install server android terminal محلي هاتف جهاز إعداد تثبيت خادم أندرويد طرفية';

  @override
  String get e7LibrarySearchModelAliases =>
      'AI reasoning favorites recent ذكاء اصطناعي استدلال مفضلة حديث';

  @override
  String get e7LibrarySearchProviderAliases =>
      'API keys authentication connect مفاتيح مصادقة مزود اتصال';

  @override
  String get e7LibrarySearchMcpAliases =>
      'integrations servers تكاملات خوادم أدوات';

  @override
  String get e7LibrarySearchCommandsAliases =>
      'slash skills references capabilities أوامر مهارات مراجع إمكانات';

  @override
  String get e7LibrarySearchPluginsAliases =>
      'plugin installed source status إضافات مثبت مصدر حالة';

  @override
  String get e7LibrarySearchTerminalAliases =>
      'shell command line طرفية صدفة سطر أوامر';

  @override
  String get e7LibrarySearchImportAliases =>
      'backup restore transfer JSON conversation نسخ احتياطي استعادة نقل محادثة';

  @override
  String get e7LibrarySearchSettingsAliases =>
      'appearance theme language notifications privacy voice background server مظهر سمة لغة إشعارات خصوصية صوت خلفية خادم';

  @override
  String get e7LibrarySearchGuideAliases =>
      'help connect tutorial start مساعدة اتصال دليل بدء';

  @override
  String get e7LibrarySearchBugAliases =>
      'feedback issue support ملاحظات مشكلة دعم';

  @override
  String get e7LibrarySearchShortcutsAliases =>
      'hotkeys help desktop اختصارات مفاتيح مساعدة حاسوب';

  @override
  String get e7SetupApiKeyHint => 'لصق مفتاح API';

  @override
  String get e7SetupBrowserHint =>
      'يفتح المتصفح. إذا تعذّرت إعادة التوجيه إلى OpenCode، الصق عنوان URL للعودة هنا.';

  @override
  String get e7SetupDeviceCodeHint =>
      'يستخدم رمزًا لمرة واحدة. يعمل من الهاتف.';

  @override
  String get e7SetupAccountHint => 'تسجيل الدخول بحسابك';

  @override
  String get e7SetupNewTerminalDetail =>
      'ابدأ جلسة طرفية في مساحة العمل الحالية.';

  @override
  String get e7SetupShowPassword => 'إظهار كلمة مرور الخادم';

  @override
  String get e7SetupAuthFailed => 'بدأ تشغيل الخادم، لكن المصادقة فشلت.';

  @override
  String get e7SetupScanInstruction =>
      'وجّه الكاميرا نحو رمز QR الذي يعرضه الأمر opencode2 pair.';

  @override
  String get e7SetupRightKey => 'مفتاح السهم لليمين';

  @override
  String get e7SetupRestartReconnectFailed =>
      'أُعيد تشغيل الخادم المحلي، لكن تعذّر على التطبيق الاتصال مجددًا.';

  @override
  String get e7SetupInstallingOpenCode => 'جارٍ تثبيت OpenCode';

  @override
  String get e7SetupNoOutput => 'لا توجد مخرجات في الطرفية بعد.';

  @override
  String get e7SetupFollowLog => 'متابعة سجل الخادم';

  @override
  String get e7SetupOpenSetupGuide => 'فتح دليل الإعداد';

  @override
  String get e7SetupScan => 'مسح';

  @override
  String get e7SetupLastOutput => 'آخر مخرجات';

  @override
  String get e7SetupDownKey => 'مفتاح السهم لأسفل';

  @override
  String get e7SetupVerifyContinue => 'التحقق والمتابعة';

  @override
  String get e7SetupAccessibleTerminal => 'استخدام سجل وإدخال ميسّرين';

  @override
  String get e7SetupUpdateOpenCode => 'تحديث OpenCode';

  @override
  String get e7SetupCameraFailedDetail =>
      'قد يستخدم تطبيق آخر الكاميرا. يمكنك لصق رمز الاقتران في جميع الأحوال.';

  @override
  String get e7SetupTermuxNoAnswer =>
      'لم يستجب Termux. افتحه، ونفّذ أمر السماح بالتحكم، ثم تحقّق مجددًا.';

  @override
  String get e7SetupCopyOpenTermux => 'النسخ وفتح Termux';

  @override
  String get e7SetupStopTerminalDetail =>
      'ستتوقف العملية الجارية والعمليات التابعة لها.';

  @override
  String get e7SetupEdit => 'تعديل';

  @override
  String get e7SetupUpdate => 'تحديث';

  @override
  String get e7SetupServerPassword => 'كلمة مرور الخادم';

  @override
  String get e7SetupHttpsHint =>
      'استخدم HTTPS للأجهزة البعيدة. يُسمح بـ HTTP فقط مع localhost أو 127.0.0.1.';

  @override
  String get e7SetupObservedVersionSaveFailed =>
      'الخادم المحلي جاهز، لكن تعذّر حفظ الإصدار الذي رصده التطبيق. حدّث الإعداد للمحاولة مجددًا.';

  @override
  String get e7SetupPasteInstead => 'لصق الرمز بدلًا من مسحه';

  @override
  String get e7SetupConfirmUpdate => 'تحديث OpenCode الذي يديره التطبيق؟';

  @override
  String get e7SetupInstallServiceDetail =>
      'أداة التثبيت الرسمية مع خدمة مستخدم systemd تستمر بعد إغلاق الطرفية وإعادة التشغيل.';

  @override
  String get e7SetupUpdateHost => 'تحديث OpenCode على الكمبيوتر المضيف';

  @override
  String get e7SetupServiceStatus => 'حالة الخدمة';

  @override
  String get e7SetupKeepAfterLogout => 'متابعة التشغيل بعد تسجيل الخروج';

  @override
  String get e7SetupGetTermux => 'الحصول على Termux';

  @override
  String get e7SetupRestartServer => 'إعادة تشغيل الخادم';

  @override
  String get e7SetupResumeSetup =>
      'المحاولة مجددًا — يستأنف الإعداد من حيث توقف';

  @override
  String get e7SetupHidePassword => 'إخفاء كلمة مرور الخادم';

  @override
  String get e7SetupControlKeys =>
      'مفاتيح التحكم في الطرفية. اسحب أفقيًا لعرض المزيد.';

  @override
  String get e7SetupSetupFailed => 'فشل الإعداد.';

  @override
  String get e7SetupEndInputKey => 'نهاية الإدخال، Control D';

  @override
  String get e7SetupGuidanceSaveFailed =>
      'تعذّر حفظ إرشادات الاتصال. حاول الحفظ مجددًا.';

  @override
  String get e7SetupServerOperation => 'جارٍ تنفيذ إجراء على الخادم';

  @override
  String get e7SetupNewTerminal => 'طرفية جديدة';

  @override
  String get e7SetupUnsavedProfile => 'لم يُحفظ ملف الخادم.';

  @override
  String get e7SetupCheckingInstall => 'جارٍ التحقق من التثبيت الحالي…';

  @override
  String get e7SetupInspectTermuxFailed =>
      'تعذّر على Android التحقق من Termux.';

  @override
  String get e7SetupUsername => 'اسم المستخدم (اختياري)';

  @override
  String get e7SetupFirstSetupDuration =>
      'قد يستغرق الإعداد الأول من 10 إلى 15 دقيقة. يمكنك مغادرة هذه الشاشة والعودة إليها؛ سيستمر الإعداد.';

  @override
  String get e7SetupNoTerminals => 'لا توجد عمليات في الطرفية';

  @override
  String get e7SetupEscapeKey => 'مفتاح Escape';

  @override
  String get e7SetupLeftKey => 'مفتاح السهم لليسار';

  @override
  String get e7SetupInstallService => 'تثبيت OpenCode كخدمة في الخلفية';

  @override
  String get e7SetupPaused => 'متوقف مؤقتًا';

  @override
  String get e7SetupSaveToFinish => 'تم الاتصال — احفظ لإكمال الإعداد.';

  @override
  String get e7SetupPasswordStartupHint =>
      'يعرضها الأمر opencode2 serve عند التشغيل بجوار «server password …». اختيارية للخوادم التي لا تستخدم كلمة مرور.';

  @override
  String get e7SetupInstallTermuxDetail =>
      'ثبّت الإصدار الحالي من Termux عبر F-Droid، ثم عُد إلى هنا.';

  @override
  String get e7SetupStopBeforeUpdate =>
      'أوقف التوليد الجاري قبل تحديث OpenCode.';

  @override
  String get e7SetupRestartingLocal => 'جارٍ إعادة تشغيل الخادم المحلي';

  @override
  String get e7SetupAddServer => 'إضافة خادم';

  @override
  String get e7SetupStepTodo => 'لم تبدأ';

  @override
  String get e7SetupInteractiveTerminal => 'استخدام الطرفية التفاعلية';

  @override
  String get e7SetupInstallingUbuntu => 'جارٍ إعداد Ubuntu';

  @override
  String get e7SetupInterruptKey => 'مقاطعة، Control C';

  @override
  String get e7SetupServerUrl => 'عنوان URL للخادم';

  @override
  String get e7SetupStopTerminal => 'إيقاف الطرفية؟';

  @override
  String get e7SetupUsbAccess => 'الاتصال من هذا الهاتف عبر USB';

  @override
  String get e7SetupWaitingTermux =>
      'في انتظار استجابة Termux. قد يستغرق ذلك بعض الوقت.';

  @override
  String get e7SetupDiscardChanges => 'تجاهل تعديلات الخادم؟';

  @override
  String get e7SetupPasswordRequired => 'يلزم إدخال كلمة المرور مجددًا';

  @override
  String get e7SetupPairing => 'جارٍ الاقتران…';

  @override
  String get e7SetupCommandInput => 'إدخال أمر للطرفية';

  @override
  String get e7SetupCameraFailed => 'تعذّر فتح الكاميرا';

  @override
  String get e7SetupPastePassword => 'لصق كلمة مرور الخادم';

  @override
  String get e7SetupSavingLocal => 'جارٍ حفظ إعدادات الخادم المحلي';

  @override
  String get e7SetupCopyFailureReport => 'نسخ تقرير الخطأ';

  @override
  String get e7SetupCameraDisabled => 'الوصول إلى الكاميرا معطّل';

  @override
  String get e7SetupRename => 'إعادة تسمية';

  @override
  String get e7SetupPastePairing => 'لصق رمز الاقتران';

  @override
  String get e7SetupServers => 'الخوادم';

  @override
  String get e7SetupStartingSetup => 'جارٍ بدء الإعداد في Termux';

  @override
  String get e7SetupSetupNotStarted =>
      'فُتح Termux لكن الإعداد لم يبدأ. حاول مجددًا؛ وإذا تكررت المشكلة، انسخ تقرير الخطأ.';

  @override
  String get e7SetupConnecting => 'جارٍ الاتصال';

  @override
  String get e7SetupThisDevice => 'هذا الجهاز (Termux)';

  @override
  String get e7SetupTransportReconnecting => 'جارٍ إعادة الاتصال بالخادم.';

  @override
  String get e7SetupStepUnavailable => 'غير متاح بعد';

  @override
  String get e7SetupUpdateHostDetail =>
      'عندما يعلن الخادم عن تحديث، تتيح الإعدادات تحديثه مباشرةً. هذا الأمر ينفّذ التحديث نفسه على الكمبيوتر المضيف.';

  @override
  String get e7SetupMissingPasswordShort =>
      'كلمة المرور المحفوظة غير متاحة. أدخلها مجددًا، أو اتركها فارغة فقط إذا لم يعد الخادم يتطلبها.';

  @override
  String get e7SetupTesting => 'جارٍ الاختبار…';

  @override
  String get e7SetupScanPairing => 'مسح رمز الاقتران';

  @override
  String get e7SetupRestartUnconfirmed =>
      'تعذّر تأكيد إعادة التشغيل. حدّث حالة التقدّم قبل المحاولة مجددًا.';

  @override
  String get e7SetupExistingMissingCredential =>
      'يوجد خادم محلي، لكن بيانات دخوله المحفوظة غير متاحة. أعد الإعداد لاستبدالها بأمان.';

  @override
  String get e7SetupPreparingModels => 'جارٍ تجهيز النماذج';

  @override
  String get e7SetupHostInstructions =>
      'تُشغّل هذه الأوامر على الكمبيوتر الذي يستضيف الخادم؛ لا يستطيع التطبيق تنفيذها نيابةً عنك. انسخ كل أمر إلى الطرفية على ذلك الكمبيوتر.';

  @override
  String get e7SetupTranscript => 'سجل الطرفية';

  @override
  String get e7SetupHostFirstSetup => 'الإعداد لأول مرة — نفّذ على الكمبيوتر';

  @override
  String get e7SetupNoCameraDetail =>
      'شغّل الأمر opencode2 pair على الخادم، ثم انسخ الرمز الذي يعرضه والصقه في محرر الخادم.';

  @override
  String get e7SetupDiscard => 'تجاهل';

  @override
  String get e7SetupConnectionClosed => 'أُغلق الاتصال';

  @override
  String get e7SetupNotConnected => 'غير متصل';

  @override
  String get e7SetupTokenBanner =>
      'يلزم إدخال رمز الاتصال للخادم النشط مجددًا. عدّل الخادم واحفظ رمزه قبل الاتصال.';

  @override
  String get e7SetupUpKey => 'مفتاح السهم لأعلى';

  @override
  String get e7SetupV1Limited =>
      'صُمّم هذا التطبيق لـ OpenCode 2؛ بعض الميزات غير متاحة على خوادم الإصدار الأول.';

  @override
  String get e7SetupConnect => 'اتصال';

  @override
  String get e7SetupRemoveTerminalDetail => 'ستتم إزالة سجل هذه الطرفية.';

  @override
  String get e7SetupAuthentication => 'المصادقة';

  @override
  String get e7SetupInputDisconnected =>
      'الإدخال غير متاح أثناء انقطاع الاتصال.';

  @override
  String get e7SetupHostCopied =>
      'تم النسخ. شغّل الأمر على الكمبيوتر الذي يستضيف الخادم.';

  @override
  String get e7SetupCameraPrivacy =>
      'تُستخدم الكاميرا فقط لقراءة رمز QR الذي يعرضه الأمر opencode2 pair، أثناء فتح هذه الشاشة. يمكنك لصق الرمز بدلًا من مسحه للحصول على النتيجة نفسها.';

  @override
  String get e7SetupIsV2 => 'هذا خادم OpenCode 2.';

  @override
  String get e7SetupResumeLive => 'استئناف المتابعة المباشرة';

  @override
  String get e7SetupTabKey => 'مفتاح Tab';

  @override
  String get e7SetupCloseScanner => 'إغلاق الماسح';

  @override
  String get e7SetupChooseContinue => 'اختر طريقة المتابعة';

  @override
  String get e7SetupTermuxOutdated =>
      'إصدار Termux هذا قديم ولا يستطيع التطبيق التحكم فيه. ثبّت الإصدار الحالي من F-Droid أو GitHub، ثم تحقّق مجددًا.';

  @override
  String get e7SetupContinueApp => 'المتابعة إلى التطبيق';

  @override
  String get e7SetupCameraNeeded => 'يلزم السماح بالكاميرا لمسح الرمز';

  @override
  String get e7SetupTerminalActions => 'إجراءات الطرفية';

  @override
  String get e7SetupReadPassword => 'عرض كلمة مرور الخادم لهذا التطبيق';

  @override
  String get e7SetupStartInstalled => 'تشغيل OpenCode المثبّت؟';

  @override
  String get e7SetupTestConnection => 'اختبار الاتصال';

  @override
  String get e7SetupCheckingTermux => 'جارٍ التحقق من الاتصال بـ Termux';

  @override
  String get e7SetupCheckingTermuxShort => 'جارٍ التحقق من Termux…';

  @override
  String get e7SetupDefaultServer => 'خادم OpenCode';

  @override
  String get e7SetupSaving => 'جارٍ الحفظ…';

  @override
  String get e7SetupNotYet => 'ليس بعد';

  @override
  String get e7SetupLinuxService => 'التشغيل كخدمة في Linux';

  @override
  String get e7SetupPairingDesktopHint =>
      'تحقّق من تشغيل الخادم وإمكانية وصول هذا الجهاز إلى العنوان الذي عرضه.';

  @override
  String get e7SetupAboutNotices => 'حول التطبيق وإشعارات المصدر المفتوح';

  @override
  String get e7SetupSetupLost => 'تعذّرت متابعة الإعداد الجاري في Termux';

  @override
  String get e7SetupVerifying => 'جارٍ التحقق…';

  @override
  String get e7SetupReportCopied => 'تم نسخ تقرير الخطأ.';

  @override
  String get e7SetupPreparingSetup => 'جارٍ تحضير الإعداد';

  @override
  String get e7SetupAppSettings => 'إعدادات التطبيق';

  @override
  String get e7SetupUnavailable => 'غير متاح';

  @override
  String get e7SetupStepDone => 'مكتملة';

  @override
  String get e7SetupNoCamera => 'هذا الجهاز لا يحتوي على كاميرا';

  @override
  String get e7SetupServerDisconnected => 'الخادم غير متصل.';

  @override
  String get e7SetupTitle => 'العنوان';

  @override
  String get e7SetupEmptyPasswordHint =>
      'اتركها فارغة فقط إذا لم يعد هذا الخادم يستخدم كلمة مرور.';

  @override
  String get e7SetupAndroidOnly => 'الإعداد على الجهاز متاح على Android فقط';

  @override
  String get e7SetupEditServer => 'تعديل الخادم';

  @override
  String get e7SetupReenterPassword => 'إدخال كلمة المرور مجددًا';

  @override
  String get e7SetupMissingCredential =>
      'بيانات الدخول المحفوظة لهذا الخادم غير متاحة. أعد الإعداد لاستبدالها بأمان.';

  @override
  String get e7SetupReconnect => 'إعادة الاتصال';

  @override
  String get e7SetupSwitchNotStarted => 'لم يبدأ تبديل الإصدار.';

  @override
  String get e7SetupNoUbuntu => 'لا يوجد تثبيت Ubuntu يديره التطبيق.';

  @override
  String get e7SetupKeyUnavailable => 'غير متاح عندما تكون الطرفية غير متصلة';

  @override
  String get e7SetupCopyTerminal => 'نسخ النص المحدد أو سجل الطرفية';

  @override
  String get e7SetupCommandHint => 'اكتب أمرًا';

  @override
  String get e7SetupCheckInstallFailed => 'تعذّر التحقق من التثبيت الحالي.';

  @override
  String get e7SetupLiveOutput => 'المخرجات المباشرة';

  @override
  String get e7SetupConnectionFailed => 'فشل الاتصال.';

  @override
  String get e7SetupOpenAppSettings => 'فتح إعدادات التطبيق';

  @override
  String get e7SetupFullWalkthrough => 'الدليل الكامل (يفتح في المتصفح)';

  @override
  String get e7SetupPairingPhoneHint =>
      'لا يمكن لهذا الهاتف الوصول إلى خادم يستمع على 127.0.0.1 فقط دون توجيه الاتصال: استخدم `adb reverse tcp:PORT tcp:PORT` عبر USB أو نفق SSH. وللوصول عبر الشبكة، استخدم HTTPS.';

  @override
  String get e7SetupOutputCopied => 'تم نسخ مخرجات الإعداد.';

  @override
  String get e7SetupMissingPasswordLong =>
      'كلمة المرور المحفوظة غير متاحة. أدخلها مجددًا، أو اتركها فارغة فقط إذا لم يعد هذا الخادم يتطلب كلمة مرور.';

  @override
  String get e7SetupNoServerGuide =>
      'لا يوجد خادم بعد؟ يوضّح دليل الإعداد كيفية تشغيله.';

  @override
  String get e7SetupExited => 'انتهت العملية';

  @override
  String get e7SetupDownloadPage => 'صفحة التنزيل';

  @override
  String get e7SetupStartingLocal => 'جارٍ تشغيل الخادم المحلي';

  @override
  String get e7SetupTerminalSemantics =>
      'طرفية تفاعلية. استخدم زر تسهيل الاستخدام لعرض سجل مقروء وحقل إدخال واضح.';

  @override
  String get e7SetupRestartingLocalStage => 'جارٍ إعادة تشغيل الخادم المحلي';

  @override
  String get e7SetupPasswordBanner =>
      'يلزم إدخال كلمة مرور الخادم النشط مجددًا. عدّل الخادم واحفظ كلمة مروره قبل الاتصال.';

  @override
  String get e7SetupEmptyPairClipboard =>
      'الحافظة فارغة. شغّل `opencode2 pair` على الخادم وانسخ الرمز الذي يعرضه.';

  @override
  String get e7SetupRestartActiveChanged =>
      'أُعيد تشغيل الخادم المحلي، لكن الخادم النشط تغيّر. أعد الاتصال عندما تكون مستعدًا.';

  @override
  String get e7SetupTokenRequired => 'يلزم إدخال رمز الاتصال مجددًا';

  @override
  String get e7SetupPairingInstructions =>
      'شغّل `opencode2 pair` على الكمبيوتر، ثم الصق الرمز الذي يعرضه أو امسحه بالكاميرا.';

  @override
  String get e7SetupHostDaily => 'الاستخدام اليومي — نفّذ على الكمبيوتر';

  @override
  String get e7SetupStopLocal => 'إيقاف الخادم المحلي';

  @override
  String get e7SetupReadingProgress => 'جارٍ قراءة تقدّم الإعداد';

  @override
  String get e7SetupCameraSettingsDetail =>
      'لن يطلب Android الإذن مجددًا. فعّل الكاميرا من إعدادات التطبيق ثم عُد إلى هنا. يمكنك لصق الرمز الآن دون أي إذن.';

  @override
  String get e7SetupVerifyTermuxFailed => 'تعذّر التحقق من الاتصال بـ Termux.';

  @override
  String get e7SetupStartConnect => 'التشغيل والاتصال';

  @override
  String get e7SetupThisServer => 'هذا الخادم';

  @override
  String get e7SetupUbuntuOnly => 'Ubuntu مثبّت، لكن OpenCode لم يُثبّت بعد.';

  @override
  String get e7SetupRenameTerminal => 'إعادة تسمية الطرفية';

  @override
  String get e7SetupInputUnavailable => 'إدخال الطرفية غير متاح';

  @override
  String get e7SetupUpdateInterruption =>
      'سيتوقف الخادم لفترة قصيرة. أوقف التوليد الجاري أولًا.';

  @override
  String get e7SetupRunningOnPhone => 'يعمل OpenCode على هذا الهاتف.';

  @override
  String get e7SetupLocalStopped =>
      'الخادم المحلي متوقف. ملفاته المثبتة محفوظة.';

  @override
  String get e7SetupDidNotConnect => 'لم يتصل الخادم.';

  @override
  String get e7SetupSendCommand => 'إرسال الأمر إلى الطرفية';

  @override
  String get e7SetupStepRunning => 'قيد التنفيذ';

  @override
  String get e7SetupStopping => 'جارٍ الإيقاف…';

  @override
  String get e7SetupUnsupportedSetup =>
      'يتطلب الإعداد على الجهاز تطبيق Termux على Android. على هذا الكمبيوتر، شغّل `opencode serve` ثم أضفه كخادم.';

  @override
  String get e7SetupSendKey => 'يرسل هذا المفتاح إلى الطرفية';

  @override
  String get e7SetupRemoveTerminal => 'إزالة الطرفية؟';

  @override
  String get e7SetupStepFailed => 'فشلت';

  @override
  String e7SetupTerminalNumber(int number) {
    return 'الطرفية $number';
  }

  @override
  String e7SetupProcessRunning(String command, int pid) {
    return '$command - معرّف العملية $pid';
  }

  @override
  String e7SetupProcessExited(String command, String code) {
    return '$command - انتهت العملية $code';
  }

  @override
  String e7SetupConnectedPid(int pid) {
    return 'متصل - معرّف العملية $pid';
  }

  @override
  String e7SetupTerminalStatus(String status) {
    return 'حالة الطرفية: $status';
  }

  @override
  String e7SetupServerVersion(String version) {
    return 'إصدار الخادم $version';
  }

  @override
  String e7SetupCopyCommandLabel(String label) {
    return 'نسخ الأمر: $label';
  }

  @override
  String e7SetupConnectFailedDetail(String name, String detail) {
    return 'تعذّر الاتصال بـ $name. $detail تحقّق من عنوان الخادم وبيانات الدخول، ثم حاول مجددًا.';
  }

  @override
  String e7SetupSavedConnectFailed(String name, String detail) {
    return 'حُفظ $name، لكن تعذّر الاتصال به. تحقّق من عنوان الخادم وبيانات الدخول، ثم حاول مجددًا. ($detail)';
  }

  @override
  String e7SetupSaveFailed(String name, String detail) {
    return 'تعذّر حفظ $name. لم يتغيّر الملف الحالي. تحقّق من مساحة تخزين الجهاز وحاول مجددًا. ($detail)';
  }

  @override
  String e7SetupRemoveServer(String name) {
    return 'إزالة $name؟';
  }

  @override
  String e7SetupRemovedDisconnectFailed(String name, String detail) {
    return 'أُزيل $name، لكن تعذّر إغلاق اتصاله بالكامل. أعد تشغيل التطبيق قبل الاتصال بخادم آخر. ($detail)';
  }

  @override
  String e7SetupRemoveFailed(String name, String detail) {
    return 'تعذّرت إزالة $name. حُفظ الملف والاتصال الحالي. تحقّق من مساحة تخزين الجهاز وحاول مجددًا. ($detail)';
  }

  @override
  String e7SetupPairedChoice(String host, int count) {
    return 'تم الاقتران بـ $host — اختير من بين $count عناوين في الرمز.';
  }

  @override
  String e7SetupPaired(String host) {
    return 'تم الاقتران بـ $host.';
  }

  @override
  String e7SetupStartFailed(String detail) {
    return 'تعذّر حفظ الإعداد المحلي أو بدؤه: $detail';
  }

  @override
  String e7SetupInstalledVersion(String version) {
    return 'الإصدار المثبّت: $version.';
  }

  @override
  String e7SetupRestartFailed(String detail) {
    return 'تعذّرت إعادة تشغيل الخادم المحلي: $detail';
  }

  @override
  String e7SetupStopFailed(String detail) {
    return 'تعذّر إيقاف الخادم المحلي: $detail';
  }

  @override
  String e7SetupStopDisconnectFailed(String detail) {
    return 'توقف الخادم، لكن تعذّر على التطبيق قطع الاتصال: $detail';
  }

  @override
  String e7SetupVersionAddress(String version, String address) {
    return 'الإصدار $version · $address';
  }

  @override
  String e7SetupVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String e7SetupStartInstalledDetail(String version) {
    return 'شغّل OpenCode $version باستخدام التثبيت الحالي واتصل به. يُعاد تشغيل الخادم المحلي الذي يديره التطبيق فقط، دون تنزيل حزم أو تحديثها.';
  }

  @override
  String e7SetupFoundInstalled(String version) {
    return 'عُثر على OpenCode $version في Ubuntu';
  }

  @override
  String e7SetupElapsedSeconds(int seconds) {
    return 'انقضت $seconds ث';
  }

  @override
  String e7SetupElapsedMinutes(int minutes, int seconds) {
    return 'انقضت $minutes د و$seconds ث';
  }

  @override
  String e7SetupStepSemantics(int number, String state, String title) {
    return 'الخطوة $number من 3، $state. $title';
  }

  @override
  String e7SetupDeleteDisclosure(int queued, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      queued,
      locale: localeName,
      other: 'سيُحذف $queued طلب من قائمة الانتظار.',
      many: 'سيُحذف $queued طلبًا من قائمة الانتظار.',
      few: 'ستُحذف $queued طلبات من قائمة الانتظار.',
      two: 'سيُحذف طلبان من قائمة الانتظار.',
      one: 'سيُحذف طلب واحد من قائمة الانتظار.',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: 'ستُحذف $drafts مسودة غير مرسلة.',
      many: 'ستُحذف $drafts مسودة غير مرسلة.',
      few: 'ستُحذف $drafts مسودات غير مرسلة.',
      two: 'ستُحذف مسودتان غير مرسلتين.',
      one: 'ستُحذف مسودة واحدة غير مرسلة.',
      zero: '',
    );
    return 'يحذف هذا كل ما حفظه الجهاز لهذا الخادم: كلمة المرور، والنموذج والوكيل المحددين، ومساحة العمل المختارة، والجلسات المعروضة في أداة الشاشة الرئيسية.\n\n$_temp0 $_temp1\n\nلن يُحذف أي شيء على الخادم نفسه أو لدى مزوّدي الذكاء الاصطناعي.';
  }

  @override
  String e7SetupPairingFailed(String detail, String hint) {
    return 'لم يستجب أي عنوان في رمز الاقتران:\n$detail\n$hint';
  }

  @override
  String e7SetupProbeV2(String version) {
    return 'OpenCode 2 · $version';
  }

  @override
  String e7SetupProbeV1(String version) {
    return 'OpenCode 1 · $version — ميزات محدودة';
  }

  @override
  String get e7SetupPairNone =>
      'لا يوجد رمز اقتران هنا. شغّل `opencode2 pair` على الخادم وامسح الرمز الذي يعرضه أو انسخه.';

  @override
  String get e7SetupPairLong =>
      'هذا النص أطول من رمز اقتران. انسخ فقط السطر الذي يعرضه `opencode2 pair` أو امسح رمز QR الخاص به.';

  @override
  String get e7SetupPairInvalid =>
      'هذا ليس رمز اقتران. شغّل `opencode2 pair` على الخادم وامسح الرمز الذي يعرضه أو انسخه.';

  @override
  String get e7SetupPairShape =>
      'بنية رمز الاقتران غير صحيحة؛ يجب أن يكون كائن JSON يحتوي على `urls` و`username` و`password`.';

  @override
  String get e7SetupPairNoUrls =>
      'رمز الاقتران لا يحتوي على حقل `urls`، لذا لا يوجد عنوان للاتصال به.';

  @override
  String get e7SetupPairUrlsType =>
      'حقل `urls` في رمز الاقتران ليس قائمة عناوين.';

  @override
  String get e7SetupPairTooMany =>
      'يحتوي رمز الاقتران على عناوين أكثر مما يحاول التطبيق الاتصال به. اربط الخادم بواجهة شبكة واحدة وأعد الاقتران.';

  @override
  String get e7SetupPairAddressType => 'يحتوي رمز الاقتران على عنوان ليس نصًا.';

  @override
  String get e7SetupPairAddressLong =>
      'يحتوي رمز الاقتران على عنوان أطول من عنوان URL مقبول للخادم.';

  @override
  String get e7SetupPairAddressMissing =>
      'رمز الاقتران لا يحتوي على عنوان خادم. تحقّق من أن الخادم يستقبل الاتصالات، ثم شغّل `opencode2 pair` مجددًا.';

  @override
  String get e7SetupPairUsernameType =>
      'حقل `username` في رمز الاقتران ليس نصًا.';

  @override
  String get e7SetupPairPasswordMissing =>
      'رمز الاقتران لا يحتوي على حقل `password`. ربما لم يُنسخ كاملًا؛ امسح الرمز أو انسخه بالكامل.';

  @override
  String get e7SetupPairPasswordType =>
      'حقل `password` في رمز الاقتران ليس نصًا.';

  @override
  String get e7SetupPairTestFailed =>
      'فشل اختبار الاتصال قبل التحقق من الخادم. جرّب عنوانًا آخر.';

  @override
  String get e7SetupNotOpenCode =>
      'لم يستجب العنوان كخادم OpenCode. تحقّق من العنوان وحاول مجددًا.';

  @override
  String get e7SetupNoServerAnswer =>
      'لم يستجب الخادم. تحقّق من تشغيل opencode serve على ذلك العنوان.';

  @override
  String get e7SetupPairPasswordRejected =>
      'رُفضت كلمة المرور. تحقّق من رمز الاقتران وحاول مجددًا.';

  @override
  String get e7SetupPairAddressUnusable =>
      'يحتوي رمز الاقتران على عنوان خادم غير صالح للاستخدام.';

  @override
  String get e7SetupNoAnswer => 'لم يستجب.';

  @override
  String get e7SetupInvalidAddress => '<عنوان غير صالح>';

  @override
  String get e7SetupEnterUrl => 'أدخل عنوان URL للخادم.';

  @override
  String get e7SetupIncludeScheme =>
      'أضف https://. استخدم http:// فقط مع localhost أو 127.0.0.1 أو [::1].';

  @override
  String get e7SetupCompleteUrl =>
      'أدخل عنوان URL كاملًا للخادم، مثل https://server.example:4096.';

  @override
  String get e7SetupUrlScheme =>
      'يجب أن تستخدم عناوين الخوادم https://، أو http:// للخادم المحلي.';

  @override
  String get e7SetupTermuxUrlScheme =>
      'يجب أن تستخدم عناوين الخوادم https://، أو http:// لـ Termux المحلي.';

  @override
  String get e7SetupUrlCredentials =>
      'لا تضع بيانات الدخول في عنوان URL. استخدم الحقول أدناه.';

  @override
  String get e7SetupUrlQuery =>
      'أزل معاملات الاستعلام والجزء الذي يبدأ بـ # من عنوان URL للخادم.';

  @override
  String get e7SetupUrlPath =>
      'أزل المسار من عنوان URL للخادم. أدخل البروتوكول والمضيف والمنفذ فقط.';

  @override
  String get e7SetupRequireHttps =>
      'يلزم HTTPS خارج هذا الجهاز. يجب عدم إرسال بيانات المصادقة الأساسية عبر HTTP.';

  @override
  String get e7SetupLocalHttp =>
      'يُسمح بـ HTTP فقط مع localhost أو 127.0.0.1 أو [::1]. استخدم HTTPS لخوادم الشبكة المحلية والخوادم البعيدة.';

  @override
  String get e7SetupRefused =>
      'رُفض الاتصال. هل يعمل opencode serve على ذلك المضيف والمنفذ؟';

  @override
  String get e7SetupTimeout =>
      'انتهت مهلة الاتصال. تحقّق من العنوان وإمكانية الوصول إلى الخادم من هذا الهاتف.';

  @override
  String get e7SetupDns =>
      'تعذّر العثور على اسم المضيف. تحقّق من كتابة العنوان.';

  @override
  String get e7SetupCertificate =>
      'رُفضت شهادة TLS للخادم. استخدم شهادة يثق بها هذا الهاتف.';

  @override
  String get e7SetupUnhealthy =>
      'استجاب الخادم لكنه أبلغ عن مشكلة في حالته. راجع سجلاته ثم حاول مجددًا.';

  @override
  String get e7SetupServerStarting =>
      'الخادم قيد التشغيل. حاول مجددًا بعد قليل.';

  @override
  String get e7SetupPasswordNeeded => 'يتطلب هذا الخادم كلمة مرور التشغيل.';

  @override
  String get e7SetupPasswordRejected =>
      'رُفضت كلمة المرور. انسخ سطر «server password» الحالي من مخرجات الخادم؛ يتغيّر عند كل إعادة تشغيل ما لم يُضبط OPENCODE_PASSWORD.';

  @override
  String get e7SetupCredentialsRefused =>
      'رفض الخادم بيانات الدخول. تحقّق من اسم المستخدم وكلمة المرور.';

  @override
  String get e7SetupCodexUrl => 'أدخل عنوان URL لخادم Codex.';

  @override
  String get e7SetupCodexCompleteUrl => 'أدخل عنوان URL كاملًا لخادم Codex.';

  @override
  String get e7SetupCodexScheme =>
      'يجب أن تستخدم عناوين خادم Codex البروتوكول wss://، أو ws:// للخادم المحلي.';

  @override
  String get e7SetupCodexCredentials =>
      'لا تضع بيانات الدخول في عنوان URL لـ Codex.';

  @override
  String get e7SetupCodexQuery =>
      'أزل معاملات الاستعلام والجزء الذي يبدأ بـ # من عنوان URL لـ Codex.';

  @override
  String get e7SetupCodexPath => 'أزل المسار من عنوان URL لخادم Codex.';

  @override
  String get e7SetupCodexPlain =>
      'يُسمح باتصال WebSocket غير المشفّر لخادم Codex المحلي فقط.';

  @override
  String get e7SetupCodexDirectory => 'أدخل مسارًا مطلقًا لمجلد مشروع Codex.';

  @override
  String get e7SetupCodexToken => 'أدخل رمز اتصال صالحًا لـ Codex.';

  @override
  String get e7SetupRefreshPackages => 'جارٍ تحديث قائمة حزم Termux';

  @override
  String get e7SetupRepairPackages => 'جارٍ إصلاح حزم Termux';

  @override
  String get e7SetupInstallDependencies => 'جارٍ تثبيت متطلبات Termux';

  @override
  String get e7SetupPrepareTermux => 'جارٍ تجهيز Termux';

  @override
  String get e7SetupInstallUbuntu => 'جارٍ تثبيت Ubuntu';

  @override
  String get e7SetupRefreshModels => 'جارٍ تحديث قائمة نماذج OpenCode';

  @override
  String get e7SetupStartLocalServer => 'جارٍ تشغيل الخادم المحلي';

  @override
  String get e7SetupOpenCodeReady => 'OpenCode جاهز';

  @override
  String get e7SetupPrepareRuntime => 'جارٍ تجهيز إصدار OpenCode المحدد';

  @override
  String get e7SetupSwitchLocal =>
      'جارٍ تبديل الخادم المحلي الذي يديره التطبيق';

  @override
  String get e7SetupCheckRestart =>
      'جارٍ التحقق من الخادم المحلي قبل إعادة تشغيله';

  @override
  String get e7SetupStoppingLocal => 'جارٍ إيقاف الخادم المحلي';

  @override
  String get e7SetupStoppedLocal => 'توقف الخادم المحلي';

  @override
  String get e7SetupUnknownSetup => 'حالة الإعداد غير معروفة';

  @override
  String get e7SetupUnexpectedStop =>
      'توقف خادم OpenCode المحلي بشكل غير متوقع';

  @override
  String get e7SetupSetupInterrupted =>
      'توقف الإعداد بشكل غير متوقع؛ راجع المخرجات المباشرة للتفاصيل';

  @override
  String get e7SetupRecoveryDisabled => 'الاستعادة التلقائية معطّلة';

  @override
  String get e7SetupRecoveryWasDisabled => 'عُطّلت الاستعادة التلقائية';

  @override
  String get e7SetupPortBusy =>
      'منفذ الخادم المحلي ما زال مستخدمًا؛ لم يُشغّل خادم بديل';

  @override
  String get e7SetupNoReturnData =>
      'لا يحتوي تثبيت OpenCode 2 هذا على بيانات منفصلة لـ OpenCode 1 للعودة إليها';

  @override
  String get e7SetupCredentialMismatch =>
      'تختلف بيانات الدخول المحفوظة عن بيانات هذا الإصدار؛ استعد بياناته الأصلية المحفوظة قبل العودة';

  @override
  String get e7SetupUbuntuUnavailable =>
      'تثبيت Ubuntu الذي يديره التطبيق غير متاح';

  @override
  String get e7SetupRuntimeUnavailable => 'أمر OpenCode المحدد غير متاح';

  @override
  String get e7SetupIdentityMismatch =>
      'العملية المتعقبة ليست خادم OpenCode الذي يديره التطبيق';

  @override
  String get e7SetupPasswordMissing => 'كلمة مرور الخادم المحلي مفقودة';

  @override
  String get e7SetupVersionMissing => 'ثُبّت OpenCode لكنه لم يُبلغ عن إصداره';

  @override
  String get e7SetupModelsRefreshFailed =>
      'حُدّث OpenCode، لكن تعذّر تحديث قائمة نماذجه';

  @override
  String get e7SetupStartupExited => 'توقف خادم OpenCode أثناء بدء التشغيل';

  @override
  String get e7SetupReadinessTimeout =>
      'لم يصبح خادم OpenCode جاهزًا مع مصادقة ناجحة خلال 30 ثانية';

  @override
  String get e7SetupUnreadableData => 'تعذّرت قراءة سجل موقع بيانات OpenCode 2';

  @override
  String get e7SetupUnreadablePrevious => 'تعذّرت قراءة سجل الإصدار السابق';

  @override
  String get e7SetupReadManagerFailed => 'تعذّرت قراءة حالة مدير الإعداد';

  @override
  String get e7SetupMissingManager => 'مدير الإعداد غير موجود';

  @override
  String get e7SetupRemoveInterruptedFailed =>
      'تعذّرت إزالة تثبيت Ubuntu غير المكتمل الذي يملكه التطبيق';

  @override
  String get e7SetupCheckStorageFailed =>
      'تعذّر التحقق من مساحة التخزين المتاحة قبل الإعداد';

  @override
  String get e7SetupReadStorageFailed =>
      'تعذّرت قراءة مساحة التخزين المتاحة قبل الإعداد';

  @override
  String get e7SetupRepositoryFailed => 'تعذّر اختيار مستودع حزم Termux الرسمي';

  @override
  String get e7SetupRepositoryRefreshFailed =>
      'تعذّر تحديث packages.termux.dev؛ تحقّق من الشبكة وحاول مجددًا';

  @override
  String get e7SetupRepairFailed => 'تعذّر إصلاح عملية حزم Termux غير المكتملة';

  @override
  String get e7SetupUpgradeFailed => 'تعذّر إكمال الترقية الآمنة لحزم Termux';

  @override
  String get e7SetupDependenciesFailed => 'تعذّر تثبيت متطلبات Termux';

  @override
  String get e7SetupDependenciesUnusable =>
      'متطلبات Termux ما زالت غير صالحة للاستخدام بعد إصلاح الحزم';

  @override
  String get e7SetupUbuntuUnusable =>
      'تثبيت Ubuntu الحالي غير صالح للاستخدام؛ لن يحذفه الإعداد';

  @override
  String get e7SetupExtractionFailed =>
      'لم ينتج عن فك ضغط Ubuntu Base تثبيت صالح للاستخدام';

  @override
  String get e7SetupLockFailed => 'تعذّر على مدير الإعداد حجز عملية تشغيله';

  @override
  String get e7SetupSetupGroupFailed =>
      'لم يبدأ مدير الإعداد ضمن مجموعة عمليات مستقلة';

  @override
  String get e7SetupSwitchGroupFailed =>
      'لم يبدأ مدير التبديل ضمن مجموعة عمليات مستقلة';

  @override
  String get e7SetupServerGroupFailed =>
      'لم يبدأ الخادم المُدار ضمن مجموعة عمليات مستقلة';

  @override
  String get e7SetupRecordIdentityFailed =>
      'تعذّر تسجيل هوية عملية الخادم المُدار';

  @override
  String e7SetupConnectingProfile(String name) {
    return 'جارٍ الاتصال بـ $name';
  }

  @override
  String e7SetupConnectingAttempt(int attempt) {
    return 'جارٍ الاتصال مجددًا (المحاولة $attempt)';
  }

  @override
  String get e7SetupOpeningWorkspace => 'جارٍ فتح مساحة العمل المحفوظة.';

  @override
  String get e7SetupWhatToCheck => 'ما يجب التحقق منه';

  @override
  String get e7SetupHideDetails => 'إخفاء التفاصيل';

  @override
  String get e7SetupDetails => 'التفاصيل';

  @override
  String get e7SetupChangeServer => 'تغيير الخادم';

  @override
  String get e7SetupUpdatePassword => 'تحديث كلمة المرور';

  @override
  String e7SetupLastSetupDetail(String detail) {
    return 'آخر مخرجات الإعداد: $detail';
  }

  @override
  String e7SetupBridgeDetail(String detail) {
    return 'تفاصيل الاتصال بـ Termux: $detail';
  }

  @override
  String e7SetupDiagnosticsUnavailable(String detail) {
    return 'التشخيص غير متاح: $detail';
  }

  @override
  String e7SetupProbeHttp(String status) {
    return 'استجاب العنوان، لكن ليس كخادم OpenCode (HTTP $status). تحقّق من أن عنوان URL يشير إلى opencode serve.';
  }

  @override
  String e7SetupProbeError(String detail) {
    return 'فشل اختبار الاتصال: $detail';
  }

  @override
  String e7SetupServerExit(String code) {
    return 'توقف خادم OpenCode (الرمز $code)';
  }

  @override
  String get e7SetupCheckTermux => 'التحقق من Termux';

  @override
  String get e7SetupCommandFailed => 'فشل تنفيذ الأمر في Termux.';

  @override
  String get e7SetupUnexpectedBridge =>
      'أعاد Termux استجابة غير متوقعة للتحقق من الاتصال.';

  @override
  String get e7SetupSetupQueued => 'الإعداد في قائمة الانتظار';

  @override
  String get e7SetupNoSetup => 'لم يبدأ أي إعداد بعد';

  @override
  String get e7SetupManagerMissingAfterLaunch =>
      'مدير الإعداد غير موجود بعد التشغيل';

  @override
  String get e7SetupBootstrapCleared => 'مُسحت حالة الإعداد الأولي';

  @override
  String get e7SetupInstallingBeta => 'جارٍ تثبيت OpenCode 2 التجريبي';

  @override
  String get e7SetupAuthenticationFailed => 'فشلت المصادقة';

  @override
  String e7SetupRuntimeInstallDetail(String runtime, String version) {
    return 'ثبّت $runtime ($version) على هذا الهاتف باستخدام Ubuntu. يدير التطبيق هذا التثبيت ويعيد استخدام ملفات Ubuntu الموجودة.';
  }

  @override
  String e7SetupReplaceDetail(String installedVersion, String targetVersion) {
    return 'استبدل OpenCode $installedVersion بالإصدار $targetVersion وأعد تشغيل الخادم المحلي الذي يديره التطبيق. ستبقى ملفات Ubuntu الموجودة محفوظة.';
  }

  @override
  String get e7SetupUncheckedDetail =>
      'تعذّر التحقق من التثبيت الحالي. قد تؤدي المتابعة إلى تثبيت OpenCode 1 على هذا الهاتف أو تحديثه. ستبقى ملفات Ubuntu الموجودة محفوظة. يمكنك التحقق مجددًا أو الاتصال باستخدام العنوان بدلًا من ذلك.';

  @override
  String get e7SetupUnknownVersion => 'إصدار غير معروف';

  @override
  String get e7ModelUiClose => 'إغلاق اختيار النموذج';

  @override
  String get e7ModelUiClearSearch => 'مسح البحث عن النماذج';

  @override
  String get e7ModelUiLoadFailed => 'تعذّر تحميل النماذج';

  @override
  String get e7ModelUiRetry => 'حاول مجددًا';

  @override
  String get e7ModelUiBasicCatalog =>
      'أرسل هذا الخادم قائمة أساسية بالنماذج. تفاصيل الإمكانات وسعة السياق غير متاحة.';

  @override
  String get e7ModelUiEditFilters => 'تعديل مرشّحات النماذج';

  @override
  String get e7ModelUiFilterModels => 'تصفية النماذج';

  @override
  String get e7ModelUiFiltered => 'تمت التصفية';

  @override
  String get e7ModelUiFilters => 'المرشّحات';

  @override
  String get e7ModelUiRefresh => 'تحديث النماذج';

  @override
  String get e7ModelUiAnyCapability => 'كل الإمكانات';

  @override
  String get e7ModelUiFastModes => 'الأوضاع السريعة';

  @override
  String get e7ModelUiReasoning => 'الاستدلال';

  @override
  String get e7ModelUiLargestContext => 'أكبر سعة سياق';

  @override
  String get e7ModelUiNoneAvailable => 'لا توجد نماذج متاحة';

  @override
  String get e7ModelUiFavoritesEmpty => 'احتفظ بنماذجك المفضّلة هنا';

  @override
  String get e7ModelUiRecentEmpty => 'اختيارك التالي يبدأ هنا';

  @override
  String get e7ModelUiNoMatches => 'لا توجد نماذج مطابقة';

  @override
  String get e7ModelUiConfigureProvider =>
      'أعِدّ مزوّد خدمة على خادم OpenCode، ثم حدّث القائمة.';

  @override
  String get e7ModelUiFavoritesHint =>
      'اضغط على النجمة بجانب أي نموذج لتجده هنا.';

  @override
  String get e7ModelUiRecentHint =>
      'ستظهر النماذج التي تستخدمها هنا، بدءًا بالأحدث.';

  @override
  String get e7ModelUiNoFastModes =>
      'لا يعلن أي نموذج عن وضع سريع أو وضع ذي جهد استدلال منخفض.';

  @override
  String get e7ModelUiNoMatchesHint =>
      'جرّب بحثًا آخر أو مزوّدًا أو مرشّح إمكانات مختلفًا.';

  @override
  String get e7ModelUiClearFilters => 'مسح المرشّحات';

  @override
  String get e7ModelUiBrowseAll => 'تصفّح كل النماذج';

  @override
  String get e7ModelUiAgent => 'الوكيل';

  @override
  String get e7ModelUiNoAgents => 'لا توجد وكلاء متاحة';

  @override
  String get e7ModelUiServerDefault => 'إعداد الخادم الافتراضي';

  @override
  String get e7ModelUiProvider => 'مزوّد الخدمة';

  @override
  String get e7ModelUiAllProviders => 'كل مزوّدي الخدمة';

  @override
  String get e7ModelUiCurrent => 'النموذج الحالي';

  @override
  String get e7ModelUiUnavailable => 'غير متاح';

  @override
  String get e7ModelUiDeprecated => 'متقادم';

  @override
  String get e7ModelUiPreview => 'تجريبي';

  @override
  String get e7ModelUiFavoritesFailed => 'تعذّر حفظ المفضّلة. حاول مجددًا.';

  @override
  String get e7ModelUiUseModelMode => 'استخدام النموذج والوضع';

  @override
  String get e7ModelUiUseSession => 'استخدام في هذه الجلسة';

  @override
  String get e7ModelUiUseNewSessions => 'استخدام في الجلسات الجديدة';

  @override
  String get e7ModelUiTools => 'الأدوات';

  @override
  String get e7ModelUiAttachments => 'المرفقات';

  @override
  String get e7ModelUiDefault => 'الافتراضي';

  @override
  String get e7ModelUiSelectionGone =>
      'لم يعد هذا الخيار متاحًا. حدّث النماذج وحاول مجددًا.';

  @override
  String get e7VoiceUiLocalInput => 'إدخال صوتي محلي';

  @override
  String get e7VoiceUiChooseModel => 'اختر نموذج Whisper INT8 متعدد اللغات';

  @override
  String get e7VoiceUiPrivacyDownload =>
      'يبقى الصوت على هذا الجهاز. يُحوَّل الكلام إلى نص محليًا ويُحذف الصوت بعد الاستخدام. يتطلب تنزيل النموذج مرة واحدة اتصالًا بالإنترنت.';

  @override
  String get e7VoiceUiNoBuiltInMic =>
      'يشير Android إلى عدم وجود ميكروفون مدمج. قد يعمل الإدخال الصوتي باستخدام ميكروفون سلكي أو USB.';

  @override
  String get e7VoiceUiLanguage => 'لغة تحويل الكلام إلى نص';

  @override
  String get e7VoiceUiVerifying => 'جارٍ التحقّق من النموذج المنزّل';

  @override
  String get e7VoiceUiVerifyChecksum => 'جارٍ التحقّق من الحجم وبصمة SHA-256…';

  @override
  String get e7VoiceUiCancelDownload => 'إلغاء التنزيل';

  @override
  String get e7VoiceUiNotNow => 'ليس الآن';

  @override
  String get e7VoiceUiUseModel => 'استخدام النموذج';

  @override
  String get e7VoiceUiDownload => 'تنزيل';

  @override
  String get e7VoiceUiKeep => 'احتفاظ';

  @override
  String get e7VoiceUiDelete => 'حذف';

  @override
  String get e7VoiceUiDefaultBadge => 'افتراضي';

  @override
  String get e7VoiceUiOptionalBadge => 'اختياري';

  @override
  String get e7VoiceUiInstalledBadge => 'مثبّت';

  @override
  String get e7VoiceUiNotInstalledBadge => 'غير مثبّت';

  @override
  String get e7VoiceUiSetupBusy => 'غير متاح أثناء إعداد النموذج';

  @override
  String get e7VoiceUiSelected => 'محدّد';

  @override
  String get e7VoiceUiSelectHint => 'اضغط مرتين للاختيار';

  @override
  String get e7VoiceUiDefault => 'الافتراضي';

  @override
  String get e7VoiceUiOptional => 'اختياري';

  @override
  String get e7VoiceUiInstalled => 'مثبّت';

  @override
  String get e7VoiceUiRedownload => 'إعادة التنزيل';

  @override
  String get e7VoiceUiReviewTranscript => 'مراجعة النص';

  @override
  String get e7VoiceUiOpenSettings => 'فتح إعدادات التطبيق';

  @override
  String get e7VoiceUiRetry => 'حاول مجددًا';

  @override
  String get e7VoiceUiStartListening => 'بدء الاستماع';

  @override
  String get e7VoiceUiCancel => 'إلغاء';

  @override
  String get e7VoiceUiInsert => 'إدراج';

  @override
  String get e7VoiceUiInsertSend => 'إدراج وإرسال';

  @override
  String get e7VoiceUiStartingMic => 'جارٍ تشغيل الميكروفون…';

  @override
  String get e7VoiceUiLoadingModel => 'جارٍ تحميل النموذج المحلي…';

  @override
  String get e7VoiceUiTranscribing =>
      'جارٍ تحويل الكلام إلى نص على هذا الجهاز…';

  @override
  String get e7VoiceUiFinishingCancel => 'جارٍ إنهاء عملية التحويل الملغاة…';

  @override
  String get e7VoiceUiDraftReady => 'النص جاهز للمراجعة';

  @override
  String get e7VoiceUiNeedsAttention => 'الإدخال الصوتي يحتاج إلى انتباهك';

  @override
  String get e7VoiceUiReady => 'جاهز للإدخال الصوتي المحلي';

  @override
  String get e7VoiceUiModelRequired => 'يلزم نموذج محلي';

  @override
  String get e7VoiceUiDownloading => 'جارٍ تنزيل النموذج الصوتي…';

  @override
  String get e7VoiceUiVerifyingModel => 'جارٍ التحقّق من النموذج الصوتي…';

  @override
  String get e7VoiceUiListeningHint =>
      'جارٍ الاستماع. اضغط مرتين على إيقاف التسجيل عند الانتهاء.';

  @override
  String get e7VoiceUiPrivacy => 'يبقى الصوت على هذا الجهاز';

  @override
  String get e7VoiceUiStopRecording => 'إيقاف التسجيل';

  @override
  String e7ModelUiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نموذج',
      many: '$count نموذجًا',
      few: '$count نماذج',
      two: 'نموذجان',
      one: 'نموذج واحد',
      zero: 'لا توجد نماذج',
    );
    return '$_temp0';
  }

  @override
  String e7ModelUiContext(String count) {
    return 'سعة سياق $count';
  }

  @override
  String e7ModelUiOutput(String count) {
    return 'حد إخراج $count';
  }

  @override
  String e7ModelUiFavorite(String model) {
    return 'إضافة $model إلى المفضّلة';
  }

  @override
  String e7ModelUiUnfavorite(String model) {
    return 'إزالة $model من المفضّلة';
  }

  @override
  String e7ModelUiEffort(String variant, String effort) {
    return '$variant · جهد الاستدلال: $effort';
  }

  @override
  String get e7ModelUiLoading => 'جارٍ تحميل قائمة النماذج';

  @override
  String e7ModelUiCost(String input, String output) {
    return '$input إدخال · $output إخراج / مليون';
  }

  @override
  String e7VoiceUiDownloadPercent(int percent) {
    return 'جارٍ تنزيل النموذج الصوتي: $percent بالمئة';
  }

  @override
  String e7VoiceUiDownloadProgress(String received, String total) {
    return '$received من $total';
  }

  @override
  String e7VoiceUiSetupFailed(String error) {
    return 'تعذّر إعداد النموذج: $error';
  }

  @override
  String e7VoiceUiDeletePack(String model) {
    return 'هل تريد حذف $model؟';
  }

  @override
  String e7VoiceUiDeleteDetail(String size) {
    return 'سيؤدي ذلك إلى إزالة $size من مساحة تخزين التطبيق الخاصة. يمكنك تنزيله مجددًا لاحقًا.';
  }

  @override
  String e7VoiceUiDownloadSize(String size) {
    return 'حجم التنزيل: $size';
  }

  @override
  String e7VoiceUiPackSemantics(
    String model,
    String size,
    String badges,
    String description,
  ) {
    return '$model، $size، $badges. $description';
  }

  @override
  String e7VoiceUiListeningTime(String elapsed, String maximum) {
    return 'جارٍ الاستماع: $elapsed من $maximum';
  }

  @override
  String e7VoiceUiRecordingCap(int seconds) {
    return 'حتى $seconds ثانية لكل تسجيل';
  }

  @override
  String get e7VoiceUiLicenses => 'تراخيص الصوت ومصادره';

  @override
  String get e7VoiceUiNoticesFailed => 'تعذّر تحميل تراخيص الصوت. حاول مجددًا.';

  @override
  String get e7VoiceUiAuto => 'اكتشاف تلقائي';

  @override
  String get e7VoiceUiEnglish => 'الإنجليزية';

  @override
  String get e7VoiceUiArabic => 'العربية';

  @override
  String get e7VoiceUiBalanced => 'متوازن';

  @override
  String get e7VoiceUiBalancedDetail =>
      'توازن موصى به بين الجودة ومساحة التخزين والسرعة.';

  @override
  String get e7VoiceUiAccurate => 'دقة عالية';

  @override
  String get e7VoiceUiAccurateDetail =>
      'جودة أعلى اختيارية؛ تتطلب ذاكرة أكبر بكثير.';

  @override
  String get e7VoiceUiCompact => 'بديل صغير الحجم';

  @override
  String get e7VoiceUiCompactDetail =>
      'الأسرع والأصغر حجمًا؛ تقل دقته مع الصوت غير الواضح.';

  @override
  String get e7VoiceUiUnsupportedAbi =>
      'لا يدعم أي محرّك صوتي مضمّن البنية الثنائية لهذا الجهاز.';

  @override
  String get e7VoiceUiPermissionBlocked =>
      'الوصول إلى الميكروفون محظور. اسمح به في إعدادات تطبيق Android.';

  @override
  String get e7VoiceUiPermissionRequired =>
      'يلزم إذن الميكروفون للإدخال الصوتي المحلي.';

  @override
  String get e7VoiceUiDeviceUnavailable =>
      'الإدخال الصوتي المحلي غير متاح. أوقف التشغيل، وتحقّق من إعدادات الميكروفون، ثم حاول مجددًا.';

  @override
  String get e7VoiceUiInputUnavailable =>
      'الإدخال الصوتي المحلي غير متاح على هذه المنصّة.';

  @override
  String get e7VoiceUiNoAudio => 'لم يُلتقط أي صوت.';

  @override
  String get e7VoiceUiInterrupted => 'انقطع التسجيل.';

  @override
  String get e7VoiceUiMicrophoneError =>
      'أبلغ الميكروفون عن خطأ. تحقّق من إعداداته وحاول مجددًا.';

  @override
  String get e7VoiceUiInputFailed => 'تعذّر إكمال الإدخال الصوتي. حاول مجددًا.';

  @override
  String get e7VoiceUiTechnicalDetails => 'التفاصيل التقنية';

  @override
  String get e7VoiceUiHttpsRequired =>
      'لا يمكن تنزيل النماذج الصوتية إلا عبر HTTPS.';

  @override
  String get e7VoiceUiTransportClosed => 'أُغلق اتصال تنزيل النموذج الصوتي.';

  @override
  String get e7VoiceUiInvalidRedirect =>
      'أعاد تنزيل النموذج الصوتي توجيهًا غير صالح.';

  @override
  String get e7VoiceUiUnsafeRedirect =>
      'أُعيد توجيه تنزيل النموذج الصوتي إلى عنوان لا يستخدم HTTPS.';

  @override
  String get e7VoiceUiNoResponse => 'لم يستجب خادم النماذج.';

  @override
  String get e7VoiceUiDownloadTimeout =>
      'انتهت مهلة تنزيل النموذج. تحقّق من الاتصال وحاول مجددًا.';

  @override
  String get e7VoiceUiChecksumFailed =>
      'لم يجتز النموذج المنزّل فحص البصمة. أعد تنزيله.';

  @override
  String get e7VoiceUiVerificationFailed =>
      'لم يجتز النموذج التحقّق النهائي. أعد تنزيله.';

  @override
  String get e7VoiceUiHttpFailed => 'رفض خادم النماذج التنزيل. حاول مجددًا.';

  @override
  String get e7VoiceUiLengthFailed =>
      'حجم النموذج المنزّل غير متوقّع. أعد تنزيله.';

  @override
  String get e7VoiceUiIncomplete => 'تنزيل النموذج غير مكتمل. حاول مجددًا.';

  @override
  String get e7VoiceUiDownloadFailed =>
      'تعذّر تنزيل النموذج الصوتي. حاول مجددًا.';

  @override
  String e7VoiceUiMemory(String model, int required, int available) {
    return 'يتطلب $model ذاكرة تطبيق لا تقل عن $required ميغابايت؛ والمتاح وفقًا لهذا الجهاز $available ميغابايت.';
  }

  @override
  String e7VoiceUiStorage(String model, String size) {
    return 'يتطلب $model مساحة خالية قدرها $size، تشمل هامشًا احتياطيًا.';
  }

  @override
  String get e7ModelUiProviderFallback => 'مزوّد خدمة';

  @override
  String e7ModelUiProviderPair(String first, String last) {
    return '$first و$last';
  }

  @override
  String e7ModelUiProviderMany(String first, String last) {
    return '$first، و$last';
  }

  @override
  String get e7ModelUiListSeparator => '، ';

  @override
  String e7ModelUiUnloadedProviders(int count, String providers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'سجّل OpenCode الدخول إلى $providers، لكنه لم يحمّل بيانات الخدمة بعد. لذلك يتعذّر استخدام النماذج وتظهر رسالة «Model not found». أعد التحميل لتفعيل تسجيل الدخول.',
      one:
          'سجّل OpenCode الدخول إلى $providers، لكنه لم يحمّل بيانات الخدمة بعد. لذلك يتعذّر استخدام النماذج وتظهر رسالة «Model not found». أعد التحميل لتفعيل تسجيل الدخول.',
    );
    return '$_temp0';
  }

  @override
  String e7SharedDeviceReportedError(String code) {
    return 'أبلغ هذا الجهاز عن خطأ ($code).';
  }

  @override
  String get e7SharedOpenCodeUnreachableTryAgain =>
      'تعذّر الوصول إلى OpenCode. حاول مرة أخرى.';

  @override
  String get chatUiQueueOnlySteeringNeedsOpenCode2 =>
      'يُرسَل بعد انتهاء هذا التشغيل. التوجيه أثناء التشغيل يتطلب OpenCode 2.';

  @override
  String get approvalsUiMenu => 'الموافقات';

  @override
  String get approvalsUiTitle => 'موافقات هذه الجلسة';

  @override
  String get approvalsUiAskTitle => 'اسأل في كل مرة';

  @override
  String get approvalsUiAskDetail => 'ينتظرك كل طلب إذن.';

  @override
  String get approvalsUiAutoTitle => 'الموافقة تلقائيًا أثناء الاتصال';

  @override
  String get approvalsUiAutoDetail =>
      'يرد هذا الهاتف على كل طلب إذن بخيار «السماح مرة واحدة» فور وصوله. لا يُحفظ أي شيء كمسموح دائمًا.';

  @override
  String get approvalsUiInheritTitle => 'الوكلاء الفرعيون يرثون هذا الخيار';

  @override
  String get approvalsUiInheritDetail =>
      'تتبع الجلسات الفرعية التي تبدأها هذه الجلسة الخيار نفسه ما لم يكن لها خيار خاص بها.';

  @override
  String get approvalsUiInheritUnavailable =>
      'يتاح عند تفعيل الموافقة التلقائية.';

  @override
  String get approvalsUiInheritedFrom => 'موروث من الجلسة الأصل';

  @override
  String get approvalsUiInheritedDetail =>
      'تتبع هذه الجلسة موافقات الجلسة الأصل. تجاوز ذلك لتختار لهذه الجلسة فقط.';

  @override
  String get approvalsUiOverride => 'تجاوز لهذه الجلسة';

  @override
  String get approvalsUiFollowParent => 'اتبع الجلسة الأصل مجددًا';

  @override
  String get approvalsUiServerRulesNote =>
      'تبقى قواعد الرفض الخاصة بالخادم سارية، وتتوقف الموافقة التلقائية كلما انقطع اتصال هذا التطبيق. تسأل الجلسات الجديدة دائمًا.';

  @override
  String get approvalsUiIndicatorOn => 'الموافقة تلقائيًا';

  @override
  String approvalsUiAutoApproved(String action) {
    return 'تمت الموافقة تلقائيًا · $action';
  }

  @override
  String get approvalsUiFailedDetail =>
      'فشلت الموافقة التلقائية. راجع هذا الطلب.';

  @override
  String approvalsUiSaveFailed(String error) {
    return 'تعذّر حفظ إعداد الموافقة: $error';
  }

  @override
  String get approvalsUiOpenSettings => 'فتح إعدادات الموافقة';

  @override
  String get approvalsUiIndicatorPaused => 'الموافقة التلقائية متوقفة مؤقتًا';

  @override
  String get approvalsUiIndicatorPausedDetail => 'غير متصل';

  @override
  String approvalsUiRecordTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت الموافقة تلقائيًا على $count طلبًا في هذا الاتصال',
      few: 'تمت الموافقة تلقائيًا على $count طلبات في هذا الاتصال',
      two: 'تمت الموافقة تلقائيًا على طلبين في هذا الاتصال',
      one: 'تمت الموافقة تلقائيًا على طلب واحد في هذا الاتصال',
      zero: 'لم تتم الموافقة تلقائيًا على أي طلب في هذا الاتصال بعد',
    );
    return '$_temp0';
  }

  @override
  String get handoffUiComputerTitle => 'المتابعة على الحاسوب';

  @override
  String handoffUiComputerIntro(String binary) {
    return 'شغّل هذا الأمر في طرفية على الحاسوب الذي يعمل عليه هذا الخادم. سيفتح الجلسة نفسها في واجهة $binary. لن يُرسل أي شيء حتى تكتب بنفسك.';
  }

  @override
  String get handoffUiComputerDirectoryNote =>
      'تنتمي الجلسات إلى مجلد مشروع، لذلك ينتقل الأمر أولًا إلى مجلد هذه الجلسة.';

  @override
  String handoffUiComputerVerify(String verified, String binary) {
    return 'تم التحقق من الصيغة مع $verified. إذا كان الإصدار المثبّت لديك مختلفًا، فراجع $binary --help للتأكد من خيار --session.';
  }

  @override
  String get handoffUiUnavailableDirectory =>
      'لم يُبلغ الخادم عن مجلد مشروع لهذه الجلسة، لذلك لا يوجد مجلد لفتحها فيه. أعد تحميل الجلسة وحاول مرة أخرى.';

  @override
  String get handoffUiUnavailableWorkspace =>
      'تعمل هذه الجلسة داخل مساحة عمل مُدارة. مجلدها يخص مضيف مساحة العمل، لذلك لا يمكن لأمر طرفية عادي فتحها. صدّر الجلسة ثم استوردها بدلًا من ذلك.';

  @override
  String get handoffUiUnavailableReference =>
      'لا يمكن وضع مرجع هذه الجلسة في أمر بشكل آمن.';

  @override
  String get handoffUiExportHint =>
      'هل تنتقل إلى خادم مختلف؟ صدّر هذه الجلسة كملف ثم استوردها هناك. هذا ينقل المحادثة نفسها، لا مجرد إشارة إليها.';

  @override
  String get handoffUiExportAction => 'تصدير الجلسة';

  @override
  String get handoffUiPhoneTitle => 'الفتح على هاتف آخر';

  @override
  String get handoffUiPhoneIntro =>
      'امسح هذا الرمز بتطبيق OpenCode Mobile على الهاتف الآخر. لا يحمل الرمز سوى معرّف هذا الخادم المحفوظ ومعرّف الجلسة: لا رسائل ولا عنوان ولا كلمة مرور. يجب أن يكون هذا الخادم محفوظًا مسبقًا على الهاتف الآخر.';

  @override
  String get handoffUiPhoneQrLabel => 'رمز QR يفتح هذه الجلسة على هاتف آخر';

  @override
  String get handoffUiPhoneLinkLabel => 'الرابط';

  @override
  String get handoffUiPhoneCopyLink => 'نسخ الرابط';

  @override
  String get handoffUiPhoneLinkCopied => 'تم نسخ الرابط';

  @override
  String get handoffUiPhoneUnavailable =>
      'تعذّر إنشاء رابط لهذه الجلسة. أعد تحميل الجلسة وحاول مرة أخرى.';

  @override
  String get handoffUiLinkServerMissing =>
      'هذا الخادم غير محفوظ على هذا الهاتف. أضفه من قسم الخوادم، ثم امسح الرمز مرة أخرى.';

  @override
  String get handoffUiLinkOpenServers => 'فتح الخوادم';

  @override
  String get handoffUiLinkDismiss => 'تجاهل';

  @override
  String get handoffUiLinkWaiting => 'سيتم فتح الجلسة بمجرد اتصال الخادم…';

  @override
  String get handoffUiLinkReentry =>
      'أدخل كلمة مرور هذا الخادم مرة أخرى، ثم امسح الرمز مجددًا.';

  @override
  String get handoffUiLinkConnectionFailed =>
      'تعذّر الاتصال بالخادم المحفوظ. تحقق منه في قسم الخوادم، ثم امسح الرمز مرة أخرى.';

  @override
  String get teamUiAccessControls => 'القرارات والتحكم';

  @override
  String get teamUiAccessReadOnly => 'للقراءة فقط';

  @override
  String get teamUiAddAddressHint => 'http://100.x.x.x:8372';

  @override
  String get teamUiAddAddressLabel => 'العنوان';

  @override
  String get teamUiAddCityLabel => 'المدينة (اختياري)';

  @override
  String get teamUiAddManually => 'إضافة يدويًا';

  @override
  String get teamUiAddSubmit => 'اختبار وتشغيل';

  @override
  String get teamUiAddTesting => 'جارٍ فحص العنوان…';

  @override
  String get teamUiAddTitle => 'إضافة مضيف فريق الذكاء الاصطناعي';

  @override
  String get teamUiAddressRequired => 'أدخل عنوان المضيف.';

  @override
  String get teamUiChange => 'تغيير';

  @override
  String get teamUiCopied => 'تم النسخ';

  @override
  String get teamUiCopy => 'نسخ';

  @override
  String get teamUiDisclaimerComputer => 'يعمل بسرعة حاسوبك؛ أبقِه مستيقظًا';

  @override
  String get teamUiDisclaimerPhone =>
      'قد يوقفه أندرويد عند انطفاء الشاشة؛ وهو أبطأ من الحاسوب';

  @override
  String get teamUiDiscoveryNotNow => 'ليس الآن';

  @override
  String teamUiDiscoveryTitle(String server) {
    return 'يشغّل $server أيضًا فريق ذكاء اصطناعي. هل تريد تشغيله؟';
  }

  @override
  String get teamUiDiscoveryTurnOn => 'تشغيل';

  @override
  String get teamUiEditorBody =>
      'إذا كان هذا الحاسوب يشغّل Gas City، فسيعثر عليه التطبيق تلقائيًا.';

  @override
  String teamUiEditorConfigured(String url) {
    return 'مضيف فريق الذكاء الاصطناعي: $url';
  }

  @override
  String get teamUiEditorTitle => 'فريق الذكاء الاصطناعي (اختياري)';

  @override
  String get teamUiEventStreamClosed => 'أُغلق تدفق الأحداث';

  @override
  String get teamUiEventStreamConnecting => 'جارٍ الاتصال بتدفق الأحداث…';

  @override
  String teamUiEventStreamLive(String seq) {
    return 'تدفق الأحداث متصل · التسلسل $seq';
  }

  @override
  String get teamUiEventStreamLiveNoSeq => 'تدفق الأحداث متصل';

  @override
  String get teamUiEventStreamReconnecting =>
      'جارٍ إعادة الاتصال بتدفق الأحداث…';

  @override
  String get teamUiFrontLine =>
      'الواجهة الأمامية أداة صغيرة على الحاسوب تتيح للهاتف الإجابة والتوجيه.';

  @override
  String get teamUiHostGuideDocs =>
      'الدليل الكامل بجميع الأوامر موجود في docs/ai-team-host.md داخل مستودع التطبيق.';

  @override
  String get teamUiHostGuideIntro =>
      'كل شيء يبقى داخل شبكة Tailscale الخاصة بك؛ ولا يُنشر أي شيء على الإنترنت.';

  @override
  String get teamUiHostGuideStep1 =>
      'ثبّت Gas City على الحاسوب: gc وbd وdolt ضمن PATH.';

  @override
  String get teamUiHostGuideStep2 =>
      'أنشئ مدينة بجوار مشروعك وأضف المشروع إليها: gc init ثم gc rig add.';

  @override
  String get teamUiHostGuideStep3 =>
      'شغّله بالأمر gc start وتأكد أن http://127.0.0.1:8372/v0/city/<name>/health يستجيب.';

  @override
  String get teamUiHostGuideStep4 =>
      'افتح المنفذ 8372 على عنوان Tailscale الخاص بالحاسوب، ثم أضفه هنا بصيغة http://100.x.x.x:8372 مع اسم المدينة.';

  @override
  String get teamUiHostGuideTitle => 'شغّل فريق ذكاء اصطناعي على حاسوبك';

  @override
  String get teamUiHostModeComputer => 'حاسوب';

  @override
  String get teamUiHostModePhone => 'هذا الهاتف';

  @override
  String get teamUiHow => 'كيف';

  @override
  String get teamUiKeep => 'إبقاء';

  @override
  String get teamUiLabelAccess => 'الصلاحية';

  @override
  String get teamUiLabelAddress => 'العنوان';

  @override
  String get teamUiLabelCity => 'المدينة';

  @override
  String get teamUiLabelHost => 'المضيف';

  @override
  String get teamUiLabelProvider => 'المزوّد';

  @override
  String get teamUiLabelVersion => 'الإصدار';

  @override
  String get teamUiLearnHow => 'تعرّف على الطريقة';

  @override
  String get teamUiNoServer => 'اتصل بخادم لاستخدام الإضافات.';

  @override
  String get teamUiPluginsHubSubtitle => 'فريق الذكاء الاصطناعي · Gas City';

  @override
  String get teamUiPluginsTitle => 'الإضافات';

  @override
  String get teamUiReadOnlyBody =>
      'يمكنك متابعة هذا الفريق من الهاتف. أما الإجابة والتوجيه فيحتاجان إلى الواجهة الأمامية على الحاسوب.';

  @override
  String get teamUiReasonCityNotRunning => 'مضيف الفريق قيد البدء';

  @override
  String get teamUiReasonNotGasCity => 'لم يُعثر على فريق ذكاء اصطناعي';

  @override
  String get teamUiReasonPlainHttp => 'العنوان ليس على شبكة Tailscale';

  @override
  String get teamUiReasonReadFailed => 'فشلت آخر قراءة';

  @override
  String get teamUiReasonUnreachable => 'تعذّر الوصول إلى المضيف';

  @override
  String get teamUiRefresh => 'تحديث';

  @override
  String get teamUiRowConnecting => 'مفعّل · جارٍ الاتصال…';

  @override
  String teamUiRowFound(String server, String version) {
    return 'عُثر عليه على $server · Gas City $version';
  }

  @override
  String get teamUiRowNotAvailable => 'غير متاح على هذا الخادم';

  @override
  String teamUiRowNotAvailableReason(String reason) {
    return 'غير متاح على هذا الخادم · $reason';
  }

  @override
  String get teamUiRowOff => 'متوقف';

  @override
  String get teamUiRowOffAddManually => 'متوقف · أضفه يدويًا';

  @override
  String teamUiRowOn(String server) {
    return 'مفعّل · $server';
  }

  @override
  String teamUiRowOnReadOnly(String server) {
    return 'مفعّل · $server · للقراءة فقط';
  }

  @override
  String get teamUiRowReconnecting => 'مفعّل · جارٍ إعادة الاتصال…';

  @override
  String get teamUiRowTitle => 'فريق الذكاء الاصطناعي · Gas City';

  @override
  String teamUiRowUnreachable(String minutes) {
    return 'مفعّل · تعذّر الوصول إلى المضيف منذ $minutes دقيقة';
  }

  @override
  String teamUiSavedOn(String server) {
    return 'فريق الذكاء الاصطناعي مفعّل لخادم $server.';
  }

  @override
  String get teamUiStatusConnected => 'متصل';

  @override
  String get teamUiStatusNotAvailable => 'غير متاح';

  @override
  String get teamUiStatusOff => 'متوقف';

  @override
  String get teamUiStatusOn => 'مفعّل';

  @override
  String get teamUiStatusProbing => 'جارٍ فحص المضيف…';

  @override
  String get teamUiStatusReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get teamUiStatusUnreachable => 'تعذّر الوصول إلى المضيف';

  @override
  String get teamUiTailnetRequired =>
      'يعمل فريق الذكاء الاصطناعي عبر شبكة Tailscale الخاصة بك أو على هذا الجهاز. استخدم عنوان Tailscale الخاص بالحاسوب (100.x.x.x أو name.ts.net).';

  @override
  String get teamUiTechnicalDetails => 'التفاصيل التقنية';

  @override
  String get teamUiTechnicalLastAnswer => 'آخر استجابة من المضيف';

  @override
  String get teamUiTermAgent => 'وكيل · polecat';

  @override
  String get teamUiTermProject => 'مشروع · rig';

  @override
  String get teamUiTermRun => 'تشغيل · convoy';

  @override
  String get teamUiTermTeam => 'فريق · city';

  @override
  String get teamUiTermWork => 'عمل · bead';

  @override
  String get teamUiTermsHeading => 'المصطلحات';

  @override
  String get teamUiTurnOff => 'إيقاف';

  @override
  String get teamUiTurnOffBody =>
      'يزيل بطاقته وعناصر الانتباه وبيانات الفريق المخزّنة مؤقتًا من هذا الهاتف. لا يتغير شيء على المضيف.';

  @override
  String get teamUiTurnOffFailed =>
      'تم الإيقاف، لكن تعذّرت إزالة بعض البيانات المخزّنة مؤقتًا من هذا الهاتف.';

  @override
  String teamUiTurnOffTitle(String server) {
    return 'هل تريد إيقاف فريق الذكاء الاصطناعي لخادم $server؟';
  }

  @override
  String get teamUiVerdictCityNotRunning =>
      'مضيف الفريق قيد البدء. حاول مجددًا بعد قليل.';

  @override
  String teamUiVerdictFound(String version, String city) {
    return 'Gas City $version · المدينة $city · للقراءة فقط';
  }

  @override
  String teamUiVerdictFoundControls(String version, String city) {
    return 'Gas City $version · المدينة $city · القرارات والتحكم';
  }

  @override
  String get teamUiVerdictNotGasCity =>
      'لا يشغّل هذا الخادم فريق ذكاء اصطناعي بعد. جهّز واحدًا على الحاسوب — يستغرق ذلك بضع دقائق.';

  @override
  String get teamUiVerdictUnreachable =>
      'لا استجابة من هذا العنوان. تحقق منه، ومن أن الحاسوب مستيقظ ومتصل بشبكة Tailscale الخاصة بك.';

  @override
  String get teamUiVersionUnknown => 'غير معروف';

  @override
  String get teamUiWatchingAndAnswering => 'المتابعة والإجابة من هذا الهاتف';

  @override
  String get teamUiWatchingOnly => 'المتابعة من هذا الهاتف';

  @override
  String teamUiCardAgentsSummary(
    int total,
    int working,
    int waiting,
    int idle,
    int stopped,
  ) {
    return '$total وكلاء: $working يعملون، $waiting ينتظرون، $idle خاملون، $stopped متوقفون';
  }

  @override
  String teamUiCardAgentsWorking(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وكيل يعملون',
      many: '$count وكيلًا يعملون',
      few: '$count وكلاء يعملون',
      two: 'وكيلان يعملان',
      one: 'وكيل واحد يعمل',
      zero: 'لا يعمل أي وكيل',
    );
    return '$_temp0';
  }

  @override
  String teamUiCardCity(String city) {
    return 'المدينة $city';
  }

  @override
  String teamUiCardCompletedRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تشغيل مكتمل',
      many: '$count تشغيلًا مكتملًا',
      few: '$count تشغيلات مكتملة',
      two: 'تشغيلان مكتملان',
      one: 'تشغيل واحد مكتمل',
      zero: 'لا توجد تشغيلات مكتملة',
    );
    return '$_temp0';
  }

  @override
  String get teamUiCardEmptyHint => 'ابدأ التشغيلات من المضيف في الوقت الحالي.';

  @override
  String get teamUiCardEmptyTitle => 'لا توجد تشغيلات بعد.';

  @override
  String get teamUiCardErrorCityNotRunning =>
      'مضيف الفريق قيد البدء. حاول مرة أخرى بعد لحظات.';

  @override
  String get teamUiCardErrorNotGasCity =>
      'هذا الخادم لا يشغّل فريق ذكاء اصطناعي بعد. جهّز واحدًا على الحاسوب، فالأمر يستغرق بضع دقائق.';

  @override
  String get teamUiCardErrorPlainHttp =>
      'يعمل فريق الذكاء الاصطناعي عبر شبكة Tailscale لديك أو على هذا الجهاز. استخدم tailscale serve على الحاسوب ثم حاول مرة أخرى.';

  @override
  String get teamUiCardErrorUnreachable =>
      'تعذّر الوصول إلى مضيف الفريق. يعمل فريق الذكاء الاصطناعي عبر شبكة Tailscale لديك أو على هذا الجهاز.';

  @override
  String get teamUiCardHostComputer => 'على الحاسوب';

  @override
  String get teamUiCardHostPhone => 'على هذا الهاتف';

  @override
  String get teamUiCardLoading => 'جارٍ الاتصال بمضيف الفريق…';

  @override
  String teamUiCardMoreRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تشغيل آخر',
      many: '$count تشغيلًا آخر',
      few: '$count تشغيلات أخرى',
      two: 'تشغيلان آخران',
      one: 'تشغيل واحد آخر',
      zero: 'لا توجد تشغيلات أخرى',
    );
    return '$_temp0';
  }

  @override
  String teamUiCardNeedsYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر يحتاجك',
      many: '$count عنصرًا يحتاجك',
      few: '$count عناصر تحتاجك',
      two: 'عنصران يحتاجانك',
      one: 'عنصر واحد يحتاجك',
      zero: 'لا شيء يحتاجك',
    );
    return '$_temp0';
  }

  @override
  String get teamUiCardOpen => 'فتح';

  @override
  String teamUiCardPercentDone(int percent) {
    return 'اكتمل $percent٪.';
  }

  @override
  String teamUiCardProgressSummary(
    int done,
    int working,
    int blocked,
    int total,
  ) {
    return '$done مكتمل، $working قيد العمل، $blocked معطّل من أصل $total';
  }

  @override
  String get teamUiCardRefresh => 'تحديث';

  @override
  String teamUiCardRefreshFailed(String time) {
    return 'فشل آخر تحديث · تُعرض بيانات من $time';
  }

  @override
  String get teamUiCardRetry => 'إعادة المحاولة';

  @override
  String get teamUiCardRunStateBlocked => 'معطّل';

  @override
  String get teamUiCardRunStateCancelled => 'أُلغي';

  @override
  String get teamUiCardRunStateCompleted => 'مكتمل';

  @override
  String get teamUiCardRunStateFailed => 'فشل';

  @override
  String get teamUiCardRunStatePlanning => 'قيد التخطيط';

  @override
  String get teamUiCardRunStateUnknown => 'غير معروف';

  @override
  String get teamUiCardRunStateWaiting => 'بانتظار وكيل';

  @override
  String get teamUiCardRunStateWorking => 'قيد العمل';

  @override
  String get teamUiCardRunStateWaitingMerge => 'بانتظار الدمج';

  @override
  String get teamUiCardRunTermBatch => 'convoy';

  @override
  String get teamUiCardRunTermFormula => 'formula';

  @override
  String teamUiCardSentenceBlocked(String title) {
    return '$title معطّل.';
  }

  @override
  String teamUiCardSentenceCancelled(String title) {
    return 'أُلغي $title.';
  }

  @override
  String teamUiCardSentenceCompleted(String title) {
    return 'اكتمل $title.';
  }

  @override
  String teamUiCardSentenceFailed(String title) {
    return 'فشل $title.';
  }

  @override
  String teamUiCardSentenceNeedsYou(String title) {
    return '$title ينتظر قرارك.';
  }

  @override
  String teamUiCardSentencePlanning(String title) {
    return '$title قيد التخطيط.';
  }

  @override
  String teamUiCardSentenceUnknown(String title) {
    return 'لم يُبلَّغ عن حالة $title.';
  }

  @override
  String teamUiCardSentenceWaiting(String title) {
    return '$title بانتظار وكيل.';
  }

  @override
  String teamUiCardSentenceWaitingMerge(String title) {
    return '$title بانتظار وكيل الدمج.';
  }

  @override
  String teamUiCardSentenceWorking(String title) {
    return '$title قيد العمل.';
  }

  @override
  String teamUiCardStale(String time) {
    return 'تُعرض بيانات من $time · تعذّر الوصول إلى المضيف';
  }

  @override
  String get teamUiCardTitle => 'فريق الذكاء الاصطناعي · Gas City';

  @override
  String get teamUiHomeAgentNoWork => 'لا عمل حالي';

  @override
  String get teamUiHomeAgentStateBlocked => 'معطّل';

  @override
  String get teamUiHomeAgentStateCrashed => 'تعطّل';

  @override
  String get teamUiHomeAgentStateIdle => 'خامل';

  @override
  String get teamUiHomeAgentStateStopped => 'متوقف';

  @override
  String get teamUiHomeAgentStateUnknown => 'غير معروف';

  @override
  String get teamUiHomeAgentStateWaiting => 'في الانتظار (يحتاج إدخالًا)';

  @override
  String get teamUiHomeAgentStateWorking => 'قيد العمل';

  @override
  String get teamUiHomeAgentsEmpty => 'لا وكلاء على هذا المضيف.';

  @override
  String get teamUiHomeAgentsEmptyHint =>
      'يظهر الوكلاء هنا عندما يشغّلهم المضيف.';

  @override
  String get teamUiHomeChipControls => 'تحكّم';

  @override
  String get teamUiHomeChipReadOnly => 'للقراءة فقط';

  @override
  String teamUiHomeCompletedGroup(int count) {
    return 'المكتملة ($count)';
  }

  @override
  String teamUiHomeCompletedToday(int count) {
    return 'اكتملت اليوم ($count)';
  }

  @override
  String get teamUiHomeFilterActive => 'النشطة';

  @override
  String get teamUiHomeFilterAll => 'الكل';

  @override
  String get teamUiHomeFilterBlocked => 'المعطّلة';

  @override
  String get teamUiHomeFilterCompleted => 'المكتملة';

  @override
  String get teamUiHomeGateAnswerOnComputer =>
      'أجب عن هذا على الحاسوب. يمكن للهاتف المتابعة فقط في الوقت الحالي.';

  @override
  String get teamUiHomeGateAnswerOnPhone =>
      'أجب عن هذا في المضيف على هذا الهاتف. يمكن للتطبيق المتابعة فقط في الوقت الحالي.';

  @override
  String get teamUiHomeGateClose => 'إغلاق';

  @override
  String get teamUiHomeGateKindChoice => 'قرار';

  @override
  String get teamUiHomeGateKindConfirmation => 'موافقة';

  @override
  String get teamUiHomeGateKindFreeText => 'سؤال';

  @override
  String get teamUiHomeGateKindGateBead => 'بوابة';

  @override
  String get teamUiHomeGateKindReviewReady => 'جاهز للمراجعة';

  @override
  String get teamUiHomeGateKindRunFailed => 'فشل التشغيل';

  @override
  String get teamUiHomeGateKindUnknown => 'يحتاجك';

  @override
  String teamUiHomeGateLinkAgent(String name) {
    return 'الوكيل $name';
  }

  @override
  String teamUiHomeGateLinkRun(String title) {
    return 'التشغيل $title';
  }

  @override
  String teamUiHomeGateLinkWork(String title) {
    return 'العمل $title';
  }

  @override
  String get teamUiHomeGateOptions => 'الخيارات';

  @override
  String teamUiHomeHostChip(
    String host,
    String version,
    String city,
    String access,
  ) {
    return '$host · Gas City $version · المدينة $city · $access';
  }

  @override
  String teamUiHomeHostChipNoCity(String host, String version, String access) {
    return '$host · Gas City $version · $access';
  }

  @override
  String get teamUiHomeHostRawHeading => 'القيم الخام';

  @override
  String get teamUiHomeNeedsYouEmpty => 'لا شيء يحتاجك الآن.';

  @override
  String get teamUiHomeNeedsYouEmptyHint =>
      'تظهر هنا القرارات والتشغيلات الفاشلة والوكلاء المعطّلون.';

  @override
  String get teamUiHomeRunKindBatch => 'دفعة · convoy';

  @override
  String get teamUiHomeRunKindFormula => 'تشغيل · formula';

  @override
  String teamUiHomeRunKindFormulaNamed(String formula) {
    return 'تشغيل · formula $formula';
  }

  @override
  String get teamUiHomeRunNeedsYou => 'يحتاجك';

  @override
  String teamUiHomeRunProgress(int done, int total) {
    return 'اكتمل $done من $total';
  }

  @override
  String get teamUiHomeRunsEmptyFiltered => 'لا توجد تشغيلات مطابقة.';

  @override
  String get teamUiHomeRunsEmptyHint => 'جرّب عامل تصفية آخر أو امسح البحث.';

  @override
  String get teamUiHomeSearchClear => 'مسح البحث';

  @override
  String get teamUiHomeSearchHint => 'ابحث في التشغيلات بالعنوان';

  @override
  String teamUiHomeSegmentAgents(int count) {
    return 'الوكلاء ($count)';
  }

  @override
  String teamUiHomeSegmentNeedsYou(int count) {
    return 'يحتاجك ($count)';
  }

  @override
  String teamUiHomeSegmentRuns(int count) {
    return 'التشغيلات ($count)';
  }

  @override
  String get teamUiHomeTitle => 'فريق الذكاء الاصطناعي';

  @override
  String get teamUiRunBack => 'رجوع';

  @override
  String teamUiRunBatchOf(int total, int done) {
    return 'دفعة من $total · اكتمل $done';
  }

  @override
  String teamUiRunBlockedByDeps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ينتظر $count عنصر آخر',
      many: 'ينتظر $count عنصرًا آخر',
      few: 'ينتظر $count عناصر أخرى',
      two: 'ينتظر عنصرين آخرين',
      one: 'ينتظر عنصرًا آخر',
      zero: 'لا ينتظر شيئًا',
    );
    return '$_temp0';
  }

  @override
  String teamUiRunBlockedCause(String title, String cause) {
    return '$title: $cause';
  }

  @override
  String teamUiRunChipBlocked(int count) {
    return 'معطّل $count';
  }

  @override
  String teamUiRunChipWorking(int count) {
    return 'قيد العمل $count';
  }

  @override
  String get teamUiRunDetails => 'التفاصيل';

  @override
  String teamUiRunElapsedDays(int count) {
    return '$count ي';
  }

  @override
  String teamUiRunElapsedHours(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String teamUiRunElapsedMinutes(int count) {
    return '$count د';
  }

  @override
  String teamUiRunSinceHandoff(String elapsed) {
    return '$elapsed منذ التسليم';
  }

  @override
  String get teamUiRunLabelFormula => 'الصيغة';

  @override
  String get teamUiRunLabelId => 'معرّف التشغيل';

  @override
  String get teamUiRunLabelKind => 'النوع';

  @override
  String get teamUiRunLabelLastError => 'آخر خطأ';

  @override
  String get teamUiRunLabelProject => 'المشروع';

  @override
  String get teamUiRunLabelRawState => 'حالة المزوّد';

  @override
  String get teamUiRunLabelStarted => 'بدأ';

  @override
  String get teamUiRunLabelState => 'الحالة';

  @override
  String get teamUiRunLabelTrackedWork => 'العمل المتتبَّع';

  @override
  String get teamUiRunLabelUpdated => 'حُدّث';

  @override
  String get teamUiRunMissingHint =>
      'ربما أُغلق أو أُزيل. حدّث للتحقق مرة أخرى.';

  @override
  String get teamUiRunMissingTitle => 'لم يعد هذا التشغيل موجودًا على المضيف';

  @override
  String get teamUiRunNeedsYou => 'يحتاجك';

  @override
  String teamUiRunNeedsYouFrom(String name) {
    return '$name يحتاجك';
  }

  @override
  String get teamUiRunProgressNone => 'لم يُحصَ شيء بعد';

  @override
  String teamUiRunProgressSemantics(
    int done,
    int working,
    int blocked,
    int total,
  ) {
    return 'اكتمل $done، قيد العمل $working، معطّل $blocked، من $total';
  }

  @override
  String get teamUiRunStagesHeading => 'المراحل';

  @override
  String get teamUiRunTabAgents => 'الوكلاء';

  @override
  String get teamUiRunTabComingSoon => 'يأتي مع التحديث التالي';

  @override
  String get teamUiRunTabOverview => 'نظرة عامة';

  @override
  String get teamUiRunTabTimeline => 'الخط الزمني';

  @override
  String get teamUiRunTabWork => 'العمل';

  @override
  String get teamUiRunTermBatch => 'تشغيل · convoy';

  @override
  String get teamUiRunTermFormula => 'تشغيل · formula';

  @override
  String get teamUiRunTermUnknown => 'تشغيل';

  @override
  String teamUiRunTimelineAgentStopped(String name) {
    return 'توقف $name';
  }

  @override
  String teamUiRunTimelineAgentWoke(String name) {
    return 'بدأ $name';
  }

  @override
  String get teamUiRunTimelineEmpty => 'لم يحدث شيء بعد';

  @override
  String get teamUiRunTimelineEmptyFiltered => 'لا أحداث من هذا النوع بعد';

  @override
  String get teamUiRunTimelineEmptyFilteredHint => 'جرّب عامل تصفية آخر.';

  @override
  String get teamUiRunTimelineEmptyHint =>
      'تظهر الأحداث هنا بينما يعمل الفريق على هذا التشغيل.';

  @override
  String get teamUiRunTimelineFilterAgents => 'الوكلاء';

  @override
  String get teamUiRunTimelineFilterAll => 'الكل';

  @override
  String get teamUiRunTimelineFilterDecisions => 'القرارات';

  @override
  String get teamUiRunTimelineFilterWork => 'العمل';

  @override
  String teamUiRunTimelineGateOpened(String title) {
    return 'يحتاجك: $title';
  }

  @override
  String teamUiRunTimelineGateResolved(String title) {
    return 'أُجيب: $title';
  }

  @override
  String teamUiRunTimelineJump(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حدث جديد · الانتقال إلى الأحدث',
      many: '$count حدثًا جديدًا · الانتقال إلى الأحدث',
      few: '$count أحداث جديدة · الانتقال إلى الأحدث',
      two: 'حدثان جديدان · الانتقال إلى الأحدث',
      one: 'حدث جديد · الانتقال إلى الأحدث',
      zero: 'الانتقال إلى الأحدث',
    );
    return '$_temp0';
  }

  @override
  String teamUiRunTimelineRunChanged(String state) {
    return 'التشغيل الآن $state';
  }

  @override
  String teamUiRunTimelineWorkClosed(String title) {
    return 'أُغلق $title';
  }

  @override
  String teamUiRunTimelineWorkCreated(String title) {
    return 'أُضيف $title';
  }

  @override
  String teamUiRunTimelineWorkUpdated(String title) {
    return 'حُدّث $title';
  }

  @override
  String get teamUiAgentActivityEmpty => 'لم يُسجَّل أي نشاط بعد';

  @override
  String get teamUiAgentActivityEmptyHint =>
      'تظهر استدعاءات الأدوات والأوامر هنا مع وصول مخرجات الجلسة.';

  @override
  String teamUiAgentContextSemantics(int percent) {
    return 'استُخدم $percent% من السياق';
  }

  @override
  String teamUiAgentContextShort(int percent) {
    return 'السياق $percent%';
  }

  @override
  String get teamUiAgentLabelBranch => 'الفرع';

  @override
  String get teamUiAgentLabelContext => 'استخدام السياق';

  @override
  String get teamUiAgentLabelHarness => 'البيئة';

  @override
  String get teamUiAgentLabelModel => 'النموذج';

  @override
  String get teamUiAgentLabelName => 'الاسم';

  @override
  String get teamUiAgentLabelPack => 'الحزمة';

  @override
  String get teamUiAgentLabelPool => 'المجمّع';

  @override
  String get teamUiAgentLabelRole => 'الدور';

  @override
  String get teamUiAgentLabelSessionAge => 'عمر الجلسة';

  @override
  String get teamUiAgentLabelSessionId => 'الجلسة';

  @override
  String get teamUiAgentLabelSessionName => 'اسم الجلسة';

  @override
  String get teamUiAgentLabelWorkDir => 'مجلد العمل';

  @override
  String get teamUiAgentMissingHint => 'ربما أُعيد تدويره. حدّث للتحقق.';

  @override
  String get teamUiAgentMissingTitle => 'هذا الوكيل لم يعد على المضيف';

  @override
  String get teamUiAgentNeedsYou => 'بحاجة إليك';

  @override
  String get teamUiAgentOutputConnecting => 'جارٍ الاتصال بالجلسة…';

  @override
  String get teamUiAgentOutputCopy => 'نسخ المخرجات';

  @override
  String get teamUiAgentOutputEmpty => 'لا شيء بعد';

  @override
  String get teamUiAgentOutputEnded =>
      'انتهت الجلسة · المخرجات لم تعد على المضيف';

  @override
  String get teamUiAgentOutputFollow => 'متابعة';

  @override
  String get teamUiAgentOutputJump => 'الانتقال إلى الأحدث';

  @override
  String get teamUiAgentOutputLive => 'مباشر';

  @override
  String get teamUiAgentOutputTitle => 'المخرجات المباشرة';

  @override
  String get teamUiAgentOutputUnavailable =>
      'المخرجات المباشرة غير متاحة لهذا الوكيل';

  @override
  String get teamUiAgentRecyclingSoon =>
      'إعادة التدوير قريبًا · السياق شبه ممتلئ';

  @override
  String get teamUiAgentRunEmpty => 'لا وكلاء في هذا التشغيل';

  @override
  String get teamUiAgentRunEmptyHint =>
      'يظهر الوكلاء هنا أثناء عملهم على عناصر هذا التشغيل.';

  @override
  String get teamUiAgentSectionActivity => 'النشاط';

  @override
  String get teamUiAgentSectionCurrentWork => 'العمل الحالي';

  @override
  String get teamUiAgentSectionIdentity => 'الهوية';

  @override
  String get teamUiAgentSectionOutput => 'المخرجات';

  @override
  String get teamUiAgentSectionRuntime => 'التشغيل';

  @override
  String teamUiAgentSessionAge(String age) {
    return 'الجلسة منذ $age';
  }

  @override
  String teamUiAgentStepMoreLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر إضافي',
      many: '$count سطرًا إضافيًا',
      few: '$count أسطر إضافية',
      two: 'سطران إضافيان',
      one: 'سطر إضافي واحد',
      zero: 'لا أسطر أخرى',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsCommands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'شغّل $count أمر',
      many: 'شغّل $count أمرًا',
      few: 'شغّل $count أوامر',
      two: 'شغّل أمرين',
      one: 'شغّل أمرًا واحدًا',
      zero: 'لم يشغّل أوامر',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsEdits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عدّل $count ملف',
      many: 'عدّل $count ملفًا',
      few: 'عدّل $count ملفات',
      two: 'عدّل ملفين',
      one: 'عدّل ملفًا واحدًا',
      zero: 'لم يعدّل ملفات',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsOther(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count استدعاء أداة آخر',
      many: '$count استدعاء أداة آخر',
      few: '$count استدعاءات أدوات أخرى',
      two: 'استدعاءا أداة آخران',
      one: 'استدعاء أداة آخر',
      zero: 'لا استدعاءات أخرى',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsReads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قرأ $count ملف',
      many: 'قرأ $count ملفًا',
      few: 'قرأ $count ملفات',
      two: 'قرأ ملفين',
      one: 'قرأ ملفًا واحدًا',
      zero: 'لم يقرأ ملفات',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsSearches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بحث $count مرة',
      many: 'بحث $count مرة',
      few: 'بحث $count مرات',
      two: 'بحث مرتين',
      one: 'بحث مرة واحدة',
      zero: 'لم يبحث',
    );
    return '$_temp0';
  }

  @override
  String teamUiAgentStepsSemantics(String summary, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خطوة',
      many: '$count خطوة',
      few: '$count خطوات',
      two: 'خطوتان',
      one: 'خطوة واحدة',
      zero: 'لا خطوات',
    );
    return '$summary، $_temp0';
  }

  @override
  String teamUiAgentStepsTests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'شغّل الاختبارات $count مرة',
      many: 'شغّل الاختبارات $count مرة',
      few: 'شغّل الاختبارات $count مرات',
      two: 'شغّل الاختبارات مرتين',
      one: 'شغّل الاختبارات مرة واحدة',
      zero: 'لم يشغّل اختبارات',
    );
    return '$_temp0';
  }

  @override
  String get teamUiAgentStepsTitle => 'الأدوات';

  @override
  String get teamUiAgentTermNoSession => 'وكيل';

  @override
  String teamUiAgentTermSession(String id) {
    return 'وكيل · جلسة $id';
  }

  @override
  String get teamUiAgentValueUnknown => 'غير مُبلَّغ عنه';

  @override
  String get teamUiAgentWorkBlocked => 'معطّل';

  @override
  String get teamUiAgentWorkUnblocked => 'لا شيء يعطّله';

  @override
  String get teamUiWorkEmpty => 'لا توجد عناصر عمل بعد';

  @override
  String get teamUiWorkEmptyHint => 'يظهر العمل هنا حين يكون للتشغيل عناصر.';

  @override
  String get teamUiWorkGraphFit => 'ملاءمة';

  @override
  String teamUiWorkGraphNodeSemantics(String title, String state) {
    return '$title، $state';
  }

  @override
  String teamUiWorkGraphSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'رسم الاعتماديات لـ $count عنصر عمل',
      many: 'رسم الاعتماديات لـ $count عنصر عمل',
      few: 'رسم الاعتماديات لـ $count عناصر عمل',
      two: 'رسم الاعتماديات لعنصري عمل',
      one: 'رسم الاعتماديات لعنصر عمل واحد',
      zero: 'رسم الاعتماديات بلا عناصر',
    );
    return '$_temp0';
  }

  @override
  String teamUiWorkGroupHeader(String state, int count) {
    return '$state · $count';
  }

  @override
  String get teamUiWorkLabelAssignee => 'المكلَّف';

  @override
  String get teamUiWorkLabelClosedReason => 'سبب الإغلاق';

  @override
  String get teamUiWorkLabelDependsOn => 'يعتمد على (معرّفات)';

  @override
  String get teamUiWorkLabelId => 'معرّف العمل';

  @override
  String get teamUiWorkLabelLabels => 'الوسوم';

  @override
  String get teamUiWorkLabelParent => 'الأصل';

  @override
  String get teamUiWorkLabelProject => 'المشروع';

  @override
  String get teamUiWorkLabelRawState => 'حالة المزوّد';

  @override
  String get teamUiWorkLabelRun => 'معرّف التشغيل';

  @override
  String get teamUiWorkLabelSession => 'معرّف الجلسة';

  @override
  String get teamUiWorkLabelSessionName => 'اسم الجلسة';

  @override
  String get teamUiWorkLabelType => 'النوع';

  @override
  String get teamUiWorkOwnerNone => 'غير مُسنَد';

  @override
  String teamUiWorkOwnerSemantics(String name) {
    return 'المالك: $name';
  }

  @override
  String get teamUiWorkSheetBlocking => 'يعطّل';

  @override
  String get teamUiWorkSheetBranch => 'الفرع';

  @override
  String get teamUiWorkSheetClosed => 'أُغلق';

  @override
  String get teamUiWorkSheetCode => 'الكود';

  @override
  String get teamUiWorkSheetCreated => 'أُنشئ';

  @override
  String get teamUiWorkSheetDependencies => 'يعتمد على';

  @override
  String get teamUiWorkSheetDescription => 'الوصف';

  @override
  String get teamUiWorkSheetMissing => 'عنصر العمل هذا لم يعد على المضيف.';

  @override
  String get teamUiWorkSheetNoTimestamps => 'لم يرسل المضيف طوابع زمنية.';

  @override
  String get teamUiWorkSheetOpenSession => 'فتح الجلسة';

  @override
  String get teamUiWorkSheetOutput => 'المخرجات';

  @override
  String teamUiWorkSheetStamp(String date, String clock, String age) {
    return '$date · $clock ($age)';
  }

  @override
  String get teamUiWorkSheetTarget => 'هدف الدمج';

  @override
  String get teamUiWorkSheetTimestamps => 'الطوابع الزمنية';

  @override
  String get teamUiWorkSheetUpdated => 'حُدّث';

  @override
  String get teamUiWorkSheetValidation => 'التحقق';

  @override
  String get teamUiWorkSheetValidationFailed => 'فشل';

  @override
  String get teamUiWorkSheetValidationPassed => 'نجح';

  @override
  String get teamUiWorkSheetValidationUnknown => 'سُجّلت نتيجة';

  @override
  String get teamUiWorkSheetWorktree => 'شجرة العمل';

  @override
  String get teamUiWorkStateBlocked => 'معطّل';

  @override
  String get teamUiWorkStateCancelled => 'أُلغي';

  @override
  String get teamUiWorkStateCompleted => 'مكتمل';

  @override
  String get teamUiWorkStateFailed => 'فشل';

  @override
  String get teamUiWorkStateNeedsInput => 'يحتاج مدخلات';

  @override
  String get teamUiWorkStateQueued => 'في الانتظار';

  @override
  String get teamUiWorkStateReady => 'جاهز';

  @override
  String get teamUiWorkStateReview => 'مراجعة';

  @override
  String get teamUiWorkStateUnknown => 'غير معروف';

  @override
  String get teamUiWorkStateWaiting => 'منتظر';

  @override
  String get teamUiWorkStateWorking => 'قيد العمل';

  @override
  String teamUiWorkTerm(String id) {
    return 'عمل · bead $id';
  }

  @override
  String get teamUiWorkViewGraph => 'رسم';

  @override
  String get teamUiWorkViewList => 'قائمة';

  @override
  String teamUiWorkWaitsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ينتظر $count عنصر',
      many: 'ينتظر $count عنصرًا',
      few: 'ينتظر $count عناصر',
      two: 'ينتظر عنصرين',
      one: 'ينتظر عنصرًا واحدًا',
      zero: 'لا ينتظر شيئًا',
    );
    return '$_temp0';
  }

  @override
  String teamUiUsageChip(String usage) {
    return 'الفريق اليوم · $usage';
  }

  @override
  String teamUiUsageCostEstimated(String cost) {
    return '$cost تقديريًا';
  }

  @override
  String get teamUiUsageRuntimeHint =>
      'الرموز والتكلفة لكامل الفريق اليوم، تقديرية.';

  @override
  String get teamUiUsageRuntimeLabel => 'الرموز / السياق / التكلفة';

  @override
  String teamUiUsageTokens(String count) {
    return '$count رمز';
  }

  @override
  String get teamUiGateAnswerOnHost =>
      'أجب عن هذا على المضيف. الهاتف يكتفي بالمشاهدة حاليًا.';

  @override
  String get teamUiGateAnswerOnHostPhone =>
      'أجب عن هذا داخل المضيف على هذا الهاتف. التطبيق يكتفي بالمشاهدة حاليًا.';

  @override
  String get teamUiGateCloseOnHost =>
      'أغلق هذا على المضيف. الهاتف يكتفي بالمشاهدة حاليًا.';

  @override
  String get teamUiGateCloseOnHostPhone =>
      'أغلق هذا داخل المضيف على هذا الهاتف. التطبيق يكتفي بالمشاهدة حاليًا.';

  @override
  String get teamUiGateDescription => 'الوصف';

  @override
  String get teamUiGateDestructive => 'إجراء مدمّر';

  @override
  String get teamUiGateFailureAction => 'الإجراء الموصى به';

  @override
  String get teamUiGateFailureActionAgent =>
      'أعد تشغيل الوكيل على المضيف؛ سيستأنف عنصر العمل من جديد.';

  @override
  String get teamUiGateFailureActionAuthentication =>
      'سجّل الدخول مجددًا على المضيف (مفتاح المزوّد أو الرمز)، ثم أعد محاولة التشغيل.';

  @override
  String get teamUiGateFailureActionContext =>
      'أعد تشغيل الوكيل بسياق جديد على المضيف؛ سيستأنف من عنصر العمل.';

  @override
  String get teamUiGateFailureActionDependency =>
      'ثبّت الاعتمادية الناقصة أو حدّثها على المضيف، ثم أعد محاولة التشغيل.';

  @override
  String get teamUiGateFailureActionExecution =>
      'اقرأ سجل الخطوة على المضيف، وأصلح الأمر، ثم أعد محاولة التشغيل.';

  @override
  String get teamUiGateFailureActionInfrastructure =>
      'تحقق من المضيف وخدماته، ثم أعد محاولة التشغيل.';

  @override
  String get teamUiGateFailureActionMergeConflict =>
      'حُل التعارض في شجرة العمل على المضيف، ثم أعد محاولة التشغيل.';

  @override
  String get teamUiGateFailureActionTest =>
      'أصلح الاختبارات الفاشلة على المضيف، ثم أعد محاولة التشغيل.';

  @override
  String get teamUiGateFailureActionUnknown =>
      'اقرأ الخطأ على المضيف وقرر هناك؛ لا يستطيع الهاتف التصرف فيه بعد.';

  @override
  String get teamUiGateFailureAffectedNone =>
      'لا عنصر عمل مفتوحًا في هذا التشغيل.';

  @override
  String get teamUiGateFailureAffectedWork => 'العمل المتأثر';

  @override
  String get teamUiGateFailureClassAgent => 'الوكيل';

  @override
  String get teamUiGateFailureClassAuthentication => 'المصادقة';

  @override
  String get teamUiGateFailureClassContext => 'السياق';

  @override
  String get teamUiGateFailureClassDependency => 'الاعتماديات';

  @override
  String get teamUiGateFailureClassExecution => 'التنفيذ';

  @override
  String get teamUiGateFailureClassInfrastructure => 'البنية التحتية';

  @override
  String get teamUiGateFailureClassMergeConflict => 'تعارض دمج';

  @override
  String get teamUiGateFailureClassTest => 'الاختبارات';

  @override
  String get teamUiGateFailureClassUnknown => 'غير معروف';

  @override
  String get teamUiGateFailureClassification => 'التصنيف';

  @override
  String get teamUiGateFailureError => 'الخطأ';

  @override
  String get teamUiGateFailureErrorNone => 'لم يرسل المضيف نص خطأ.';

  @override
  String get teamUiGateFailureRecoverable => 'قابل للاستعادة';

  @override
  String get teamUiGateFailureRecoverableNo => 'لا — يلزم تغيير شيء أولًا';

  @override
  String get teamUiGateFailureRecoverableUnknown => 'غير معروف';

  @override
  String get teamUiGateFailureRecoverableYes =>
      'نعم — تكفي إعادة المحاولة من المضيف';

  @override
  String get teamUiGateGone =>
      'لم يعد هذا بانتظارك؛ أُجيب عنه أو أُغلق على المضيف.';

  @override
  String get teamUiGateKindAgentBlocked => 'وكيل معطَّل';

  @override
  String get teamUiGateLabelKind => 'نوع المزوّد';

  @override
  String get teamUiGateLabelRequestId => 'معرّف الطلب';

  @override
  String get teamUiGateLabelRunId => 'معرّف التشغيل';

  @override
  String get teamUiGateLabelSessionId => 'معرّف الجلسة';

  @override
  String get teamUiGateLabelWorkId => 'معرّف العمل';

  @override
  String get teamUiGateNoDescription => 'لم يرسل المضيف وصفًا.';

  @override
  String get teamUiGateReviewOnHost =>
      'راجع هذا على المضيف. الهاتف يكتفي بالمشاهدة حاليًا.';

  @override
  String get teamUiGateReviewOnHostPhone =>
      'راجع هذا داخل المضيف على هذا الهاتف. التطبيق يكتفي بالمشاهدة حاليًا.';

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
  String get teamUiGateUnblocks => 'يفتح الطريق أمام';

  @override
  String get teamUiGateUnblocksNone => 'لا شيء ينتظر هذا بعد.';

  @override
  String get teamUiHostKindDesktop => 'حاسوب مكتبي';

  @override
  String get teamUiHostKindDisclaimerLaptop =>
      'النوم وإغلاق الغطاء يوقفان الفريق مؤقتًا؛ وتستأنف التشغيلات عند الاستيقاظ';

  @override
  String get teamUiHostKindDisclaimerWsl =>
      'النوم وإغلاق الغطاء يوقفان الفريق مؤقتًا؛ وتستأنف التشغيلات عند الاستيقاظ. كما يتوقف WSL عند إغلاق آخر نافذة طرفية له.';

  @override
  String get teamUiHostKindHint => 'لا يغيّر سوى التنبيه المعروض مع الفريق.';

  @override
  String get teamUiHostKindLabel => 'نوع الحاسوب';

  @override
  String get teamUiHostKindLaptop => 'حاسوب محمول';

  @override
  String get teamUiHostKindWsl => 'Windows (WSL)';

  @override
  String get teamUiReceiptSent => 'أُرسل · بانتظار تأكيد المضيف';

  @override
  String get teamUiReceiptAnswered => 'تمت الإجابة';

  @override
  String get teamUiReceiptUnconfirmed =>
      'أُرسل دون تأكيد — تحقق على المضيف قبل إعادة الإرسال';

  @override
  String get teamUiGateAnswerSend => 'إرسال';

  @override
  String get teamUiGateAnswerApprove => 'موافقة';

  @override
  String get teamUiGateAnswerDeny => 'رفض';

  @override
  String get teamUiGateAnswerMarkDone => 'تم الإنجاز';

  @override
  String get teamUiGateAnswerHint => 'اكتب إجابتك';

  @override
  String get teamUiGateAnswerOptionsHint => 'اختر خيارًا واحدًا ثم أرسل.';

  @override
  String get teamUiGateAnswerRunRetry => 'إعادة المحاولة';

  @override
  String teamUiGateAnswerRunRetryDetail(String work, String agent) {
    return 'يرسل $work إلى $agent مرة أخرى.';
  }

  @override
  String get teamUiGateAnswerRunAgent => 'إعادة التشغيل أو إعادة الإسناد';

  @override
  String get teamUiGateAnswerRunLogs => 'عرض السجلات';

  @override
  String get teamUiGateAnswerRunCancel => 'إلغاء العمل';

  @override
  String get teamUiGateAnswerRetry => 'إعادة المحاولة';

  @override
  String get teamUiGateAnswerTryAgain => 'حاول مجددًا';

  @override
  String teamUiGateAnswerRejected(String message) {
    return 'لم يُقبل: $message';
  }

  @override
  String get teamUiGateAnswerRejectedNoMessage => 'لم يقبل المضيف هذه الإجابة.';

  @override
  String get teamUiGateAnswerChipSent => 'أُرسل';

  @override
  String get teamUiGateAnswerChipUnconfirmed => 'غير مؤكد';

  @override
  String get teamUiGateAnswerChipRejected => 'لم يُقبل';

  @override
  String get teamUiGateAnswerChipUnconfirmedSemantics =>
      'غير مؤكد، افتح لإعادة المحاولة';

  @override
  String get teamUiGateAnswerConfirmDenyTitle => 'رفض هذا الطلب؟';

  @override
  String get teamUiGateAnswerConfirmDenyBody =>
      'يُبلَّغ الوكيل بالرفض ويواصل من دونه.';

  @override
  String get teamUiGateAnswerConfirmApproveTitle =>
      'الموافقة على هذا الإجراء المدمّر؟';

  @override
  String get teamUiGateAnswerConfirmApproveBody =>
      'يصنّف المضيف هذا الإجراء مدمّرًا. لا يمكن التراجع عنه من الهاتف.';

  @override
  String get teamUiGateAnswerConfirmCancelRunTitle => 'إلغاء هذا العمل؟';

  @override
  String get teamUiGateAnswerConfirmCancelRunBody =>
      'يتوقف التشغيل ويبقى عمله المفتوح كما هو.';

  @override
  String get teamUiGateAnswerConfirmKeep => 'إبقاء';

  @override
  String get teamUiGateAnswerNotificationOpening =>
      'يُفتح القرار بمجرد اتصال فريق الذكاء الاصطناعي…';

  @override
  String get teamUiGateAnswerRunGone =>
      'لم يعد هذا التشغيل موجودًا على المضيف.';

  @override
  String get teamUiControlSectionTitle => 'التحكم';

  @override
  String get teamUiControlMessage => 'رسالة';

  @override
  String get teamUiControlNudge => 'تنبيه';

  @override
  String get teamUiControlPause => 'إيقاف مؤقت';

  @override
  String get teamUiControlResume => 'استئناف';

  @override
  String get teamUiControlStop => 'إيقاف';

  @override
  String get teamUiControlRestart => 'إعادة تشغيل';

  @override
  String get teamUiControlReassign => 'إعادة إسناد العمل…';

  @override
  String get teamUiControlCreateWork => 'أُرسلت المهمة إلى وكيل';

  @override
  String teamUiControlMessageTitle(String agent) {
    return 'رسالة إلى $agent';
  }

  @override
  String get teamUiControlMessageHint => 'أخبر الوكيل بما يفعله بعد ذلك';

  @override
  String get teamUiControlMessageSend => 'إرسال';

  @override
  String teamUiControlStopConfirmTitle(String agent) {
    return 'إيقاف $agent؟';
  }

  @override
  String get teamUiControlStopConfirmBody =>
      'تنتهي جلسته الآن. يبقى عمله حيث هو؛ ويمكن للمضيف إيقاظه لاحقًا.';

  @override
  String get teamUiControlStopConfirmAction => 'إيقاف الوكيل';

  @override
  String teamUiControlRestartConfirmTitle(String agent) {
    return 'إعادة تشغيل $agent؟';
  }

  @override
  String get teamUiControlRestartConfirmBody =>
      'تتوقف جلسته ثم تبدأ من جديد. يفقد الوكيل ما كان في سياقه ويستأنف عمله من المضيف.';

  @override
  String get teamUiControlRestartConfirmAction => 'إعادة تشغيل الوكيل';

  @override
  String get teamUiControlKeep => 'متابعة';

  @override
  String teamUiControlReassignTitle(String agent) {
    return 'إعادة إسناد العمل إلى $agent';
  }

  @override
  String get teamUiControlReassignHint =>
      'العمل الجاهز على هذا المضيف. ينتقل العنصر الذي تختاره إلى هذا الوكيل.';

  @override
  String get teamUiControlReassignEmpty => 'لا شيء جاهز للإسناد.';

  @override
  String get teamUiControlReceiptSent => 'أُرسل';

  @override
  String get teamUiControlReceiptConfirmed => 'مؤكد';

  @override
  String get teamUiControlReceiptUnconfirmed => 'غير مؤكد';

  @override
  String get teamUiControlReceiptRefused => 'مرفوض';

  @override
  String teamUiControlReceiptLine(String control, String state) {
    return '$control · $state';
  }

  @override
  String get teamUiControlReceiptRetry => 'إعادة المحاولة';

  @override
  String get teamUiControlMoreActions => 'إجراءات أخرى';

  @override
  String get teamUiControlCancelRun => 'إلغاء التشغيل';

  @override
  String get teamUiControlCloseBatch => 'إغلاق الدفعة';

  @override
  String get teamUiControlCancelRunConfirmTitle => 'إلغاء هذا التشغيل؟';

  @override
  String get teamUiControlCancelRunConfirmBody =>
      'تتوقف الخطوات الجارية؛ ويبقى العمل المكتمل. لا يمكن التراجع عن هذا من الهاتف.';

  @override
  String get teamUiControlCloseBatchConfirmTitle => 'إغلاق هذه الدفعة؟';

  @override
  String get teamUiControlCloseBatchConfirmBody =>
      'تُغلق الدفعة على المضيف. تبقى عناصر عملها المفتوحة مفتوحة لدفعة أخرى.';

  @override
  String get teamUiStartRunFab => 'بدء تشغيل';

  @override
  String get teamUiStartRunTitle => 'بدء تشغيل';

  @override
  String get teamUiStartRunObjectiveLabel => 'الهدف';

  @override
  String get teamUiStartRunObjectiveHint =>
      'ما الذي ينبغي أن يحققه الفريق؟ نتيجة واحدة، بكلماتك.';

  @override
  String get teamUiStartRunObjectiveEmpty => 'اكتب هدفًا أولًا.';

  @override
  String get teamUiStartRunProjectLabel => 'المشروع';

  @override
  String get teamUiStartRunProjectAny => 'دع المخطِّط يختار';

  @override
  String get teamUiStartRunSupervisionLabel => 'الإشراف';

  @override
  String get teamUiStartRunSupervisionHigh => 'عالٍ';

  @override
  String get teamUiStartRunSupervisionHighHint =>
      'يسأل الفريق قبل كل قرار، وقبل الاختبارات التي تغيّر الحالة، وقبل أي دمج.';

  @override
  String get teamUiStartRunSupervisionBalanced => 'متوازن';

  @override
  String get teamUiStartRunSupervisionBalancedHint =>
      'يقرر الفريق الأمور الروتينية بنفسه ويسأل قبل الدمج وعند الإخفاقات وفي خيارات التصميم.';

  @override
  String get teamUiStartRunSupervisionAutonomous => 'مستقل';

  @override
  String get teamUiStartRunSupervisionAutonomousHint =>
      'يعمل الفريق حتى الإنجاز ضمن حدود المضيف ولا يسأل إلا عندما يتعذر عليه المتابعة.';

  @override
  String get teamUiStartRunPlannerLabel => 'المخطِّط';

  @override
  String get teamUiStartRunPlannerMayor => 'العمدة (Mayor)';

  @override
  String get teamUiStartRunPlannerHint =>
      'يُضبط على المضيف؛ يعرضه الهاتف ولا يختاره.';

  @override
  String get teamUiStartRunSend => 'إرسال إلى المخطِّط';

  @override
  String get teamUiStartRunPlannerOffTitle =>
      'المخطِّط (Mayor) متوقف على هذا المضيف';

  @override
  String get teamUiStartRunPlannerOffBody =>
      'أيقظه على المضيف أو بدّله إلى الملف الكامل، ثم عد.';

  @override
  String get teamUiStartRunPlannerMissingTitle => 'لا مخطِّط على هذا المضيف';

  @override
  String get teamUiStartRunPlannerMissingBody =>
      'حزمة Gas Town مع عمدتها لا تعمل هنا. يوضح دليل المضيف كيفية تفعيلها.';

  @override
  String get teamUiStartRunHostGuide => 'دليل المضيف';

  @override
  String get teamUiStartRunWaking => 'جارٍ إيقاظ المخطِّط…';

  @override
  String get teamUiStartRunDirectIntro =>
      'المخطِّط متوقف على هذا المضيف. أعطِ مهمة واحدة مباشرةً إلى وكيل المشروع.';

  @override
  String get teamUiStartRunDirectTitle => 'المهمة';

  @override
  String get teamUiStartRunDirectTitleHint =>
      'سطر واحد: ماذا ينبغي أن يفعل الوكيل؟';

  @override
  String get teamUiStartRunDirectTitleRequired => 'اكتب مهمة أولًا.';

  @override
  String get teamUiStartRunDirectDetails => 'التفاصيل (اختياري)';

  @override
  String get teamUiStartRunDirectSend => 'إرسال إلى وكيل';

  @override
  String teamUiStartRunDirectRefused(String reason) {
    return 'رفض المضيف المهمة: $reason';
  }

  @override
  String get teamUiStartRunPlanning => 'جارٍ التخطيط… (Mayor)';

  @override
  String get teamUiStartRunPlanningHint =>
      'يحوّل المخطِّط الهدف إلى عمل. يظهر التشغيل في هذه القائمة بمجرد أن يفعل.';

  @override
  String get teamUiStartRunStillPlanning =>
      'ما زال التخطيط جاريًا — راجع مخرجات المخطِّط';

  @override
  String get teamUiStartRunUnconfirmed =>
      'أُرسل دون تأكيد — راجع مخرجات المخطِّط قبل الإرسال مجددًا';

  @override
  String teamUiStartRunRefused(String reason) {
    return 'رفض المضيف الهدف: $reason';
  }

  @override
  String get teamUiStartRunPlannerOutput => 'مخرجات المخطِّط';

  @override
  String get teamUiStartRunDismiss => 'تجاهل';

  @override
  String teamUiStartRunSentAt(String time) {
    return 'أُرسل $time';
  }

  @override
  String get teamUiMergeTitleReady => 'جاهز للدمج';

  @override
  String get teamUiMergeTitleNotReady => 'غير جاهز للدمج';

  @override
  String get teamUiMergeTitleMerged => 'تم الدمج';

  @override
  String teamUiMergeRequest(String id) {
    return 'طلب الدمج $id';
  }

  @override
  String get teamUiMergeLineWork => 'بنود العمل';

  @override
  String get teamUiMergeLineTests => 'الاختبارات';

  @override
  String get teamUiMergeLineBuild => 'البناء';

  @override
  String get teamUiMergeLineReview => 'المراجعة';

  @override
  String get teamUiMergeLineConflicts => 'لا تعارضات';

  @override
  String get teamUiMergeLineAcceptance => 'معايير القبول';

  @override
  String teamUiMergeFiles(int files, int additions, int deletions) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files ملف · +$additions / −$deletions',
      many: '$files ملفًا · +$additions / −$deletions',
      few: '$files ملفات · +$additions / −$deletions',
      two: 'ملفان · +$additions / −$deletions',
      one: 'ملف واحد · +$additions / −$deletions',
      zero: 'لا تغييرات في الملفات',
    );
    return '$_temp0';
  }

  @override
  String get teamUiMergeReviewChanges => 'مراجعة التغييرات';

  @override
  String get teamUiMergeApprove => 'اعتماد الطلب';

  @override
  String get teamUiMergeApproveTitle => 'اعتماد طلب الدمج هذا؟';

  @override
  String get teamUiMergeApproveMessage =>
      'يُسجَّل اعتمادك على المضيف. الدمج خطوة منفصلة.';

  @override
  String teamUiMergeApprovedBy(String login) {
    return 'اعتمده $login';
  }

  @override
  String get teamUiMergeMerge => 'دمج';

  @override
  String get teamUiMergeConfirmStep => 'تأكيد الدمج';

  @override
  String get teamUiMergeArmedHint => 'انقر مرة أخرى للمتابعة';

  @override
  String teamUiMergeConfirmTitle(String branch) {
    return 'الدمج في $branch؟';
  }

  @override
  String get teamUiMergeConfirmMessage => 'لا يمكن التراجع عن هذا من الهاتف';

  @override
  String teamUiMergeConfirmAction(String branch) {
    return 'دمج في $branch';
  }

  @override
  String teamUiMergeDisabledReason(String line, String detail) {
    return 'الدمج متوقف: $line — $detail';
  }

  @override
  String teamUiMergeBoundary(String text) {
    return 'حدود المضيف: $text';
  }

  @override
  String teamUiMergeRefused(String text) {
    return 'رفض المضيف: $text';
  }

  @override
  String teamUiMergeMerged(String branch, String commit) {
    return 'تم الدمج في $branch · $commit';
  }

  @override
  String teamUiMergeAlready(String branch) {
    return 'موجود بالفعل على $branch';
  }

  @override
  String teamUiMergeUnavailable(String reason) {
    return 'جاهزية الدمج غير متاحة: $reason';
  }

  @override
  String get teamUiMergeNoRoles => 'لا يملك المضيف أدوار دمج لهذا التشغيل';

  @override
  String get teamUiMergeLoading => 'جارٍ التحقق من جاهزية الدمج…';

  @override
  String get teamUiMergePending => 'يعمل على المضيف';

  @override
  String get teamUiMergeChangesTitle => 'التغييرات';

  @override
  String get teamUiMergeChangesEmpty => 'لم يُبلغ المضيف عن تغييرات في الملفات';

  @override
  String get teamUiMergeChangesWork => 'بنود العمل';

  @override
  String teamUiMergeChangeCounts(int additions, int deletions) {
    return '+$additions / −$deletions';
  }

  @override
  String get teamUiMergeSent => 'أُرسل · بانتظار تأكيد المضيف';

  @override
  String get teamUiMergeApproveConfirmed => 'تم تسجيل الاعتماد';

  @override
  String teamUiPolicySupervision(String level) {
    return 'الإشراف · $level';
  }

  @override
  String get teamUiPolicyBoundariesLabel => 'الحدود';

  @override
  String get teamUiPolicyBoundariesNone => 'لا حدود مضبوطة على المضيف';

  @override
  String get teamUiPolicyFromHost => 'مضبوطة على المضيف · للقراءة فقط هنا';

  @override
  String teamUiPolicyRig(String rig) {
    return 'لـ $rig';
  }

  @override
  String teamUiPolicySemantics(String level, String boundaries) {
    return 'الإشراف $level. الحدود: $boundaries';
  }

  @override
  String teamUiHomeUpkeepToggle(int count) {
    return 'إظهار صيانة الفريق ($count)';
  }

  @override
  String get teamUiHomeUpkeepHint => 'دوريات ومهام يشغّلها المضيف لنفسه';

  @override
  String teamUiHomeSuspendedGroup(int count) {
    return 'موقوفون على المضيف ($count)';
  }

  @override
  String teamUiHomeSegmentAgentsOff(int count, int off) {
    return 'الوكلاء ($count · $off متوقفون)';
  }

  @override
  String teamUiHomeHostChipHost(String host, String kind) {
    return '$host · $kind';
  }

  @override
  String get teamUiRunLabelRawTitle => 'عنوان المزوّد';

  @override
  String get teamUiCycleStepRouted => 'وُجِّه';

  @override
  String get teamUiCycleStepAgentStarting => 'الوكيل يبدأ';

  @override
  String get teamUiCycleStepClaimed => 'استُلم';

  @override
  String get teamUiCycleStepWorking => 'قيد العمل';

  @override
  String get teamUiCycleStepPushed => 'دُفع';

  @override
  String get teamUiCycleStepHandedToMerge => 'سُلّم للدمج';

  @override
  String get teamUiCycleStepMerged => 'دُمج';

  @override
  String get teamUiCycleWaitingForAgent =>
      'في انتظار وكيل · عادةً من دقيقة إلى 5 دقائق';

  @override
  String teamUiCycleCurrent(String step, String time) {
    return '$step · منذ $time';
  }

  @override
  String teamUiCycleSince(String time) {
    return 'منذ $time';
  }

  @override
  String teamUiCycleSemantics(
    int position,
    int total,
    String step,
    String time,
  ) {
    return 'الخطوة $position من $total، $step، منذ $time';
  }

  @override
  String teamUiCycleSemanticsNoTime(int position, int total, String step) {
    return 'الخطوة $position من $total، $step';
  }

  @override
  String teamUiCycleSemanticsMerged(int total, String time) {
    return 'اكتملت الخطوات الـ$total كلها، دُمج في $time';
  }

  @override
  String get teamUiCycleStallHostNotStarted => 'لم يبدأ المضيف وكيلًا بعد';

  @override
  String get teamUiCycleStallAgentCannotStart =>
      'تعذّر على الوكيل البدء على المضيف';

  @override
  String get teamUiCycleStallProviderLimit => 'بلغ مزوّد النموذج حدّ الاستخدام';

  @override
  String get teamUiCycleStallWorkingLong => 'ما زال يعمل — راجع مخرجات الوكيل';

  @override
  String get teamUiCycleStallMergeWaiting => 'في انتظار وكيل الدمج';

  @override
  String get teamUiCycleActionHow => 'كيف يوزّع المضيف العمل';

  @override
  String get teamUiCycleActionOpenOutput => 'فتح مخرجات الوكيل';

  @override
  String get teamUiCycleActionNudgeRefinery => 'تنبيه الـrefinery';

  @override
  String get teamUiCycleHowLine1 =>
      'يتحقق المضيف من العمل الجديد مرة كل دقيقة تقريبًا ويوجّهه إلى مجموعة وكلاء.';

  @override
  String get teamUiCycleHowLine2 =>
      'دورية كل 30 ثانية توقظ وكيلًا ضمن ميزانية الإيقاظ؛ ويستغرق تشغيل بيئة الوكيل من 5 إلى 10 ثوانٍ.';

  @override
  String get teamUiCycleHowLine3 =>
      'تستغرق أول جولة للنموذج من 10 إلى 60 ثانية قبل أن يستلم الوكيل العمل، لذا فإن من دقيقتين إلى 6 دقائق من التوجيه إلى الاستلام أمر طبيعي.';

  @override
  String get teamUiCycleHowClose => 'فهمت';

  @override
  String get termuxStorageTitle => 'التخزين على هذا الهاتف';

  @override
  String termuxStorageRowUsed(String size) {
    return '$size مستخدمة';
  }

  @override
  String get termuxStorageRowNotScanned => 'لم يُفحص بعد';

  @override
  String get termuxStorageRowScanning => 'جارٍ القياس…';

  @override
  String get termuxStorageScanAction => 'فحص التخزين';

  @override
  String get termuxStorageRescanAction => 'إعادة الفحص';

  @override
  String get termuxStorageIntro =>
      'اعرض مساحة التخزين التي يستخدمها Termux، بما فيها الخادم المحلي والأدوات الأخرى. وسّع أي فئة للاطلاع على تفاصيلها. يمكن تنظيف ملفات تخزين مؤقت محددة قابلة لإعادة الإنشاء فقط؛ وتبقى المشاريع وبيانات الفريق وتسجيلات الدخول وسجل الجلسات محفوظة.';

  @override
  String get termuxStorageScanning => 'جارٍ قياس التخزين';

  @override
  String get termuxStorageScanningDetail =>
      'قد تستغرق الذاكرات المؤقتة الكبيرة دقيقة أو دقيقتين. يمكنك مغادرة هذه الشاشة؛ سيستمر الفحص.';

  @override
  String get termuxStorageCancel => 'إلغاء الفحص';

  @override
  String get termuxStorageCancelled => 'أُلغي الفحص';

  @override
  String get termuxStorageFailed => 'لم يكتمل الفحص. حاول مرة أخرى.';

  @override
  String termuxStorageTotal(String size) {
    return 'تم قياس $size في Termux';
  }

  @override
  String termuxStorageDeletableTotal(String size) {
    return 'يمكن تنظيف $size';
  }

  @override
  String get termuxStorageScannedJustNow => 'فُحص للتو';

  @override
  String termuxStorageScannedMinutesAgo(int minutes) {
    return 'فُحص قبل $minutes دقيقة';
  }

  @override
  String termuxStorageScannedHoursAgo(int hours) {
    return 'فُحص قبل $hours ساعة';
  }

  @override
  String get termuxStorageCatBuildCaches => 'ذاكرات البناء المؤقتة';

  @override
  String get termuxStorageNoteBuildCaches =>
      'ملفات Gradle المؤقتة وذاكرة المحتوى المنزّل لـ npm فقط. قد يلزم تنزيل الملفات مجددًا، مما قد يؤثر في البناء دون اتصال. أوقف عمليات البناء وتثبيت الحزم قبل التنظيف.';

  @override
  String get termuxStorageCatAgentScratch => 'مجلدات عمل الوكلاء المؤقتة';

  @override
  String get termuxStorageNoteAgentScratch =>
      'قد تحتوي المجلدات المؤقتة على عمل غير مكتمل أو ملفات تستخدمها أدوات أخرى. تُعرض أحجامها للاطلاع فقط ولا يمكن حذفها من هنا.';

  @override
  String get termuxStorageCatProjectBuildOutputs =>
      'مجلدات بأسماء مرتبطة بالبناء';

  @override
  String get termuxStorageNoteProjectBuildOutputs =>
      'قد تحتوي المجلدات المسماة build أو .dart_tool أو node_modules أو target على ملفاتك أيضًا. لا يكفي الاسم لإثبات إمكانية حذفها، لذلك لا يمكن حذفها من هنا.';

  @override
  String get termuxStorageCatToolchains => 'أدوات البناء';

  @override
  String get termuxStorageNoteToolchains =>
      'تثبيتات Android SDK وJava وFlutter. قد تستخدمها مشاريع أخرى ولا يمكن حذفها من هنا.';

  @override
  String get termuxStorageCatAiTeam => 'فريق الذكاء الاصطناعي';

  @override
  String get termuxStorageNoteAiTeam =>
      'قد تحتوي مجلدات الفريق وقواعد البيانات والأدوات على عمل تحتاج إلى الاحتفاظ به. لا يمكن حذفها من هنا، حتى عند إيقاف الفريق.';

  @override
  String get termuxStorageCatOpenCode => 'OpenCode نفسه';

  @override
  String get termuxStorageNoteOpenCode =>
      'الخادم وتسجيلات دخوله وسجل الجلسات. لا تُحذف من هنا؛ فللجلسات شاشتها الخاصة.';

  @override
  String get termuxStorageCatProjects => 'المشاريع (ملفاتك)';

  @override
  String get termuxStorageNoteProjects =>
      'مُدرجة لترى حجمها. لا تُحذف من هنا أبدًا.';

  @override
  String get termuxStorageWillRemove => 'ما الذي يحذفه التنظيف';

  @override
  String get termuxStorageNothingHere => 'لا شيء هنا';

  @override
  String get termuxStorageNotDeletable => 'لا يُحذف من هنا';

  @override
  String get termuxStorageClean => 'تنظيف';

  @override
  String termuxStorageCleanSemantics(String category, String size) {
    return 'تنظيف $category، $size';
  }

  @override
  String termuxStorageCleanConfirmTitle(String size, String category) {
    return 'هل تريد حذف $size من $category؟';
  }

  @override
  String get termuxStorageCleanConfirmBody =>
      'هل تريد حذف ملفات Gradle المؤقتة وذاكرة محتوى npm المعروضة فقط؟ قد يلزم تنزيل الملفات مجددًا وقد يتأثر البناء دون اتصال. أوقف عمليات البناء وتثبيت الحزم أولًا، ثم أعد الفحص لتحديث الأحجام المقاسة.';

  @override
  String termuxStorageCleanConfirm(String size) {
    return 'حذف $size';
  }

  @override
  String get termuxStorageKeep => 'إبقاء';

  @override
  String get termuxStorageCleaning => 'جارٍ الحذف…';

  @override
  String termuxStorageFreed(String size) {
    return 'تم حذف $size';
  }

  @override
  String get termuxStorageFreedNothing => 'لم يُحذف شيء';

  @override
  String termuxStorageInUse(String process) {
    return 'قيد الاستخدام بواسطة $process. أوقفه أولًا من «يعمل الآن».';
  }

  @override
  String termuxStorageRefusedCount(int count) {
    return 'تُركت $count مسارات في مكانها';
  }

  @override
  String termuxStorageProjectBuild(String size, String build) {
    return '$size · $build في مجلدات مرتبطة بالبناء';
  }

  @override
  String get termuxStorageOpenRunning => 'فتح «يعمل الآن»';

  @override
  String termuxStorageBytesGb(String value) {
    return '$value غ.ب';
  }

  @override
  String termuxStorageBytesMb(String value) {
    return '$value م.ب';
  }

  @override
  String termuxStorageBytesKb(String value) {
    return '$value ك.ب';
  }

  @override
  String termuxStorageBytesB(String value) {
    return '$value بايت';
  }

  @override
  String get termuxStorageOnThisPhone => 'على هذا الهاتف';

  @override
  String get termuxStorageReadFailed => 'تعذّر قراءة فحص التخزين.';

  @override
  String get termuxProcsTitle => 'يعمل الآن';

  @override
  String termuxProcsRowSubtitle(int count, String cpu) {
    return '$count عمليات · المعالج $cpu٪';
  }

  @override
  String get termuxProcsRowLoading => 'جارٍ التحقق…';

  @override
  String get termuxProcsRowUnavailable => 'غير متاح الآن';

  @override
  String get termuxProcsRefresh => 'تحديث';

  @override
  String get termuxProcsAutoRefresh => 'يتحدّث كل 10 ثوانٍ أثناء فتح الشاشة';

  @override
  String get termuxProcsGroupOpenCode => 'خادم OpenCode';

  @override
  String get termuxProcsGroupAiTeam => 'فريق الذكاء الاصطناعي';

  @override
  String get termuxProcsGroupBuild => 'خدمات البناء';

  @override
  String get termuxProcsGroupOrphans => 'عمليات يتيمة';

  @override
  String get termuxProcsGroupOther => 'أخرى';

  @override
  String get termuxProcsGroupOpenCodeHint => 'يُدار من عناصر التحكم في الخادم';

  @override
  String get termuxProcsOrphansHint =>
      'عمليات مساعدة فقدت العملية الأم، أو تستهلك المعالج دون أن ينتظرها شيء. إيقافها آمن.';

  @override
  String get termuxProcsStopGroup => 'إيقاف الكل';

  @override
  String termuxProcsStopGroupTitle(String group) {
    return 'هل تريد إيقاف كل العمليات في $group؟';
  }

  @override
  String termuxProcsStopGroupBody(int count) {
    return 'تتلقى $count عمليات إيقافًا لطيفًا، ثم إيقافًا قسريًا بعد 5 ثوانٍ.';
  }

  @override
  String termuxProcsStopConfirm(int count) {
    return 'إيقاف $count';
  }

  @override
  String get termuxProcsStop => 'إيقاف';

  @override
  String termuxProcsStopSemantics(String name) {
    return 'إيقاف $name';
  }

  @override
  String termuxProcsStopOneTitle(String name) {
    return 'هل تريد إيقاف $name؟';
  }

  @override
  String get termuxProcsStopOneBody =>
      'تتلقى إيقافًا لطيفًا، ثم إيقافًا قسريًا بعد 5 ثوانٍ.';

  @override
  String get termuxProcsKeep => 'إبقاء';

  @override
  String get termuxProcsProtected => 'محمية · افتح عناصر التحكم في الخادم';

  @override
  String termuxProcsOrphanParentGone(String elapsed) {
    return 'العملية الأم غير موجودة · تعمل منذ $elapsed';
  }

  @override
  String termuxProcsOrphanCpu(String cpu) {
    return '$cpu من وقت المعالج دون مالك';
  }

  @override
  String termuxProcsStats(String cpu, String memory, String elapsed) {
    return 'المعالج $cpu٪ · $memory · $elapsed';
  }

  @override
  String get termuxProcsStopping => 'جارٍ الإيقاف…';

  @override
  String termuxProcsStopped(int count) {
    return 'أُوقفت $count';
  }

  @override
  String termuxProcsStoppedForced(int count, int forced) {
    return 'أُوقفت $count (احتاجت $forced إلى إيقاف قسري)';
  }

  @override
  String termuxProcsRemaining(int count) {
    return '$count لم تتوقف';
  }

  @override
  String termuxProcsRefused(int count) {
    return '$count محمية، لم تُوقف';
  }

  @override
  String get termuxProcsEmpty => 'لا شيء يعمل في خادم الهاتف';

  @override
  String get termuxProcsFailed => 'تعذّر قراءة قائمة العمليات.';

  @override
  String get termuxProcsAttentionLine => 'لا يزال شيء ما يعمل على هذا الهاتف';

  @override
  String termuxProcsAttentionDetail(String name, String cpu) {
    return 'استهلك $name $cpu من وقت المعالج دون أن ينتظره شيء';
  }

  @override
  String get termuxProcsCommand => 'الأمر';

  @override
  String get termuxProcsFolder => 'المجلد';

  @override
  String termuxProcsPid(int pid, int ppid) {
    return 'المعرّف $pid · الأم $ppid';
  }

  @override
  String termuxProcsDurationSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String termuxProcsDurationMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String termuxProcsDurationHours(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String termuxProcsMemoryMb(int mb) {
    return '$mb م.ب';
  }

  @override
  String get teamUiPhoneOptionalTag => 'اختياري · تجريبي';

  @override
  String get teamUiPhoneOfferTitle =>
      'شغّل فريق ذكاء اصطناعي على هذا الهاتف أيضًا';

  @override
  String get teamUiPhoneOfferBody =>
      'يتيح لعدة وكلاء برمجة العمل على مشروعك بينما تشرف عليهم من مساحة العمل. يستخدم بيئة لينكس نفسها التي أعددتها للتو.';

  @override
  String teamUiPhoneOfferSize(int size) {
    return 'يُنزّل نحو $size م.ب (Gas City وbeads وDolt مبنية لأندرويد).';
  }

  @override
  String get teamUiPhoneOfferWarning =>
      'أبقِ Termux مفتوحًا أو فعّل قفل الاستيقاظ فيه أثناء عمل الفريق؛ فقد يوقفه أندرويد في الخلفية. لا يُفقد شيء؛ وتُستأنف التشغيلات عند بدئه من جديد.';

  @override
  String get teamUiPhoneSkip => 'تخطَّ الآن';

  @override
  String get teamUiPhoneSetUp => 'إعداد فريق الذكاء الاصطناعي';

  @override
  String get teamUiPhoneStepDownload => 'التنزيل والتحقق';

  @override
  String get teamUiPhoneStepPackages => 'تثبيت المتطلبات';

  @override
  String get teamUiPhoneStepCity => 'إنشاء مدينة بجوار المشروع';

  @override
  String get teamUiPhoneStepStart => 'بدء المشرف على هذا الهاتف';

  @override
  String get teamUiPhoneStepConnect => 'الاتصال';

  @override
  String get teamUiPhoneLeaveNote =>
      'يمكنك مغادرة هذه الشاشة والعودة لمتابعة التقدّم.';

  @override
  String teamUiPhoneProjectLine(String path) {
    return 'المشروع: $path';
  }

  @override
  String get teamUiPhoneChooseProjectTitle => 'اختر مشروعًا';

  @override
  String get teamUiPhoneChooseProjectBody =>
      'يعمل الفريق على مجلد مشروع واحد من خادم الهاتف. يُودِع الوكيل الأول تغييراته في أصل git يُنشأ بجواره.';

  @override
  String teamUiPhoneNoProjects(String directory) {
    return 'لا يوجد مجلد مشروع بعد. سمِّ واحدًا وسيُنشأ ضمن $directory.';
  }

  @override
  String get teamUiPhoneNewFolderLabel => 'اسم المجلد';

  @override
  String get teamUiPhoneCreateAndContinue => 'إنشاء ومتابعة';

  @override
  String get teamUiPhoneContinue => 'متابعة';

  @override
  String get teamUiPhoneSetupRunning => 'جارٍ إعداد فريق الذكاء الاصطناعي';

  @override
  String get teamUiPhoneSuccessTitle =>
      'فريق الذكاء الاصطناعي يعمل على هذا الهاتف';

  @override
  String teamUiPhoneAgentsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وكيل جاهز',
      many: '$count وكيلًا جاهزًا',
      few: '$count وكلاء جاهزون',
      two: 'وكيلان جاهزان',
      one: 'وكيل واحد جاهز',
      zero: 'لا وكلاء بعد',
    );
    return '$_temp0';
  }

  @override
  String get teamUiPhoneOpenWorkspace => 'فتح مساحة العمل';

  @override
  String get teamUiPhoneRetry => 'إعادة المحاولة';

  @override
  String get teamUiPhoneFailedTitle => 'تعذّر إعداد فريق الذكاء الاصطناعي.';

  @override
  String teamUiPhoneFailedChecksum(String name) {
    return 'الملف المنزَّل $name لم يطابق المجموع الاختباري المثبّت في هذا الإصدار، فلم يُثبَّت. لم يُحتفظ بشيء منه؛ تحقّق من الشبكة وحاول مجددًا.';
  }

  @override
  String get teamUiPhoneFailedUnsupportedArch =>
      'معالج هذا الهاتف ليس ARM بنظام 64 بت، وهو ما يحتاجه وقت تشغيل الفريق.';

  @override
  String get teamUiPhoneFailedDownload =>
      'لم يكتمل التنزيل. تحقّق من الاتصال وحاول مجددًا.';

  @override
  String get teamUiPhoneFailedPackages =>
      'لم يتمكن Termux من تثبيت المتطلبات (libicu وgit وjq وtmux). يوضح المخرج أدناه أيها.';

  @override
  String get teamUiPhoneFailedProject =>
      'مجلد المشروع مفقود أو ليس مستودع git.';

  @override
  String get teamUiPhoneFailedCity =>
      'لم تتمكن Gas City من إنشاء المدينة. يوضح المخرج أدناه السبب.';

  @override
  String get teamUiPhoneFailedSupervisorExited =>
      'توقف المشرف مباشرة بعد بدئه. يوضح المخرج أدناه السبب.';

  @override
  String teamUiPhoneFailedHealth(String url) {
    return 'بدأ المشرف لكنه لم يُجب قط على $url.';
  }

  @override
  String get teamUiPhoneFailedInterrupted =>
      'توقف الإعداد قبل اكتماله. ربما أوقف أندرويد Termux أثناء غياب التطبيق؛ لا يُفقد شيء.';

  @override
  String teamUiPhoneFailedReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get teamUiPhoneDispatchFailed =>
      'لم يبدأ Termux الخطوة. افتح Termux مرة واحدة ثم حاول مجددًا.';

  @override
  String get teamUiPhoneSectionTitle => 'على هذا الهاتف';

  @override
  String get teamUiPhoneStatusChecking => 'جارٍ التحقق…';

  @override
  String get teamUiPhoneStatusNotInstalled => 'غير مثبّت';

  @override
  String get teamUiPhoneStatusInstalled => 'مثبّت · لا مدينة بعد';

  @override
  String get teamUiPhoneStatusStopped => 'متوقف';

  @override
  String get teamUiPhoneStatusStarting => 'جارٍ البدء…';

  @override
  String get teamUiPhoneStatusStopping => 'جارٍ الإيقاف…';

  @override
  String teamUiPhoneStatusWorking(String verb) {
    return 'جارٍ العمل… ($verb)';
  }

  @override
  String teamUiPhoneStatusRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يعمل · $count وكيل',
      many: 'يعمل · $count وكيلًا',
      few: 'يعمل · $count وكلاء',
      two: 'يعمل · وكيلان',
      one: 'يعمل · وكيل واحد',
      zero: 'يعمل',
    );
    return '$_temp0';
  }

  @override
  String get teamUiPhoneStatusFailed => 'لا يعمل · فشلت الخطوة الأخيرة';

  @override
  String teamUiPhoneStatusUnreachable(String url) {
    return 'بدأ، لكنه لا يُجيب على $url';
  }

  @override
  String get teamUiPhoneStatusUnknown => 'تعذّرت قراءة الحالة';

  @override
  String teamUiPhoneVersions(String gc, String bd, String dolt) {
    return 'gc $gc · bd $bd · dolt $dolt';
  }

  @override
  String get teamUiPhoneStart => 'بدء';

  @override
  String get teamUiPhoneStop => 'إيقاف';

  @override
  String get teamUiPhoneStopTitle => 'إيقاف الفريق على هذا الهاتف؟';

  @override
  String get teamUiPhoneStopBody =>
      'يتوقف الوكلاء العاملون حيث هم. لا يُفقد شيء؛ وتُستأنف التشغيلات عند بدئه من جديد.';

  @override
  String get teamUiPhoneStopConfirm => 'إيقاف الفريق';

  @override
  String get teamUiPhoneKilled =>
      'أوقف أندرويد الفريق أثناء غياب التطبيق. لم يُفقد شيء.';

  @override
  String get teamUiPhoneStartAgain => 'ابدأ من جديد';

  @override
  String get teamUiPhoneKeepRunningTitle => 'أبقِه يعمل';

  @override
  String get teamUiPhoneKeepRunningSubtitle =>
      'قفل الاستيقاظ وإعداد البطارية وقاتل العمليات الشبحية';

  @override
  String get teamUiPhoneTipsIntro =>
      'يوقف أندرويد أعمال الخلفية التي يعدّها مفرطة، والفريق كذلك تمامًا: عشرات عمليات gc وbd القصيرة ووكيل يستهلك المعالج بالكامل. ثلاثة أمور تبقيه حيًّا.';

  @override
  String get teamUiPhoneTipWakeLock =>
      'أبقِ Termux في المقدمة، أو فعّل قفل الاستيقاظ فيه: شغّل termux-wake-lock داخل Termux، أو انقر Acquire wakelock في إشعاره. إطفاء الشاشة من دونه ينهي التشغيل.';

  @override
  String get teamUiPhoneTipBattery =>
      'الإعدادات › التطبيقات › Termux › البطارية › غير مقيّد، وأوقف التنظيف التلقائي الخاص بالشركة المصنّعة لهاتفك عن Termux.';

  @override
  String get teamUiPhoneTipPhantom =>
      'لا يزال أندرويد 12 وما بعده يقتل العمليات الفرعية لتطبيق في الخلفية (قاتل العمليات الشبحية). أوقف ذلك مرة واحدة من Termux نفسه عبر تصحيح الأخطاء اللاسلكي؛ لا حاجة إلى حاسوب:';

  @override
  String get teamUiPhoneTipsCopy => 'نسخ الأوامر';

  @override
  String get teamUiPhoneTipsCopied => 'نُسخت الأوامر';

  @override
  String get teamUiPhoneRemove => 'إزالة من هذا الهاتف';

  @override
  String get teamUiPhoneRemoveTitle =>
      'إزالة فريق الذكاء الاصطناعي من هذا الهاتف؟';

  @override
  String get teamUiPhoneRemoveBody =>
      'يوقف المشرف ويحذف gc والمدينة ومخزنها. تبقى ملفات مشروعك وسجل git الخاص بها. تُعطَّل الإضافة لهذا الخادم.';

  @override
  String get teamUiPhoneRemoveConfirm => 'إزالة';

  @override
  String get teamUiPhoneRemoved => 'أُزيل فريق الذكاء الاصطناعي من هذا الهاتف.';

  @override
  String teamUiPhoneActionFailed(String reason) {
    return 'لم ينجح ذلك: $reason';
  }

  @override
  String get teamUiPhoneNotAvailable =>
      'غير متاح على هذا الهاتف. يحتاج تشغيل فريق إلى بيئة لينكس 64 بت؛ ولا يستطيع هذا الجهاز أو هذا الإصدار توفيرها.';

  @override
  String get teamUiPhoneReofferTitle =>
      'إعداد فريق ذكاء اصطناعي على هذا الهاتف';

  @override
  String get teamUiPhoneReofferBody =>
      'الخطوة الاختيارية التي تخطيتها أثناء الإعداد. يعمل عدة وكلاء برمجة على مشروعك بينما تشرف عليهم من مساحة العمل؛ وقد يوقفهم أندرويد أثناء غياب التطبيق.';

  @override
  String get teamUiPhoneReofferDismiss => 'ليس الآن';

  @override
  String get teamUiPhoneReofferAction => 'إعداد';

  @override
  String get teamUiPhoneOpenSetup => 'فتح إعداد الهاتف';

  @override
  String teamUiPhoneFailedNoSpace(String detail) {
    return 'لا توجد مساحة كافية على هذا الهاتف. $detail حرّر بعض المساحة (يمكن لقسم «التخزين على هذا الهاتف» تنظيف ذاكرة البناء المؤقتة)، ثم حاول مجددًا.';
  }

  @override
  String get calmMoreToolsAndHelp => 'الأدوات والمساعدة';

  @override
  String get calmCodeOptions => 'خيارات الشفرة';

  @override
  String get termuxRunningDetected => 'تم العثور على خادم على هذا الهاتف';

  @override
  String get termuxRunningConnect => 'الاتصال بالخادم قيد التشغيل';

  @override
  String get termuxRunningDetails => 'تفاصيل الخادم';

  @override
  String get termuxRunningPermission =>
      'اسمح بالوصول إلى Termux في إعداد الهاتف للتحقق من وجود خادم.';

  @override
  String get termuxRunningUnavailable =>
      'تعذر التحقق من الخادم على هذا الهاتف.';

  @override
  String get termuxStorageCatSharedCaches => 'ملفات مؤقتة وبيانات حزم أخرى';

  @override
  String get termuxStorageNoteSharedCaches =>
      'قد تستخدم أدوات أخرى الملفات المؤقتة المشتركة والحزم المثبتة ومجلدات التنزيل، أو قد تحتوي على ملفات تحتاج إلى الاحتفاظ بها. لا يمكن حذفها من هنا.';

  @override
  String get termuxStorageRescanRequired =>
      'فحص سابق · أعد الفحص قبل تنظيف المزيد';
}
