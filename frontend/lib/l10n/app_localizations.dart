import 'package:flutter/material.dart';

/// Lightweight, codegen-free localizations for Rased (English + Arabic).
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isRtl => locale.languageCode == 'ar';

  String t(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Rased Dashboard',
      'agentOnline': 'Agent Online',
      'agentOffline': 'Agent Offline',
      'checking': 'Checking…',
      'refresh': 'Refresh',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'askAi': 'Ask AI',
      'history': 'History',
      'waitingMetrics': 'Waiting for metrics…',
      'noContainers': 'No Docker containers found',
      // container card
      'cpu': 'CPU',
      'ram': 'RAM',
      'restarts': 'Restarts',
      'liveUsage': 'Live Usage',
      'collectingData': 'Collecting data…',
      'analyzeLogs': 'Analyze Logs',
      'restart': 'Restart',
      'stop': 'Stop',
      'start': 'Start',
      'actions': 'Actions',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'confirmActionTitle': 'Confirm action',
      'confirmActionBody': 'Are you sure you want to {action} "{name}"?',
      'actionSuccess': 'Action completed',
      'actionFailed': 'Action failed',
      // UPS
      'upsStatus': 'UPS Status',
      'upsDisconnected': 'NUT disconnected',
      'onBattery': 'Running on battery',
      'onMains': 'Connected to mains',
      'battery': 'Battery',
      // host
      'hostTitle': 'Host',
      'hostCpu': 'CPU',
      'hostMemory': 'Memory',
      'load': 'Load',
      'cores': 'cores',
      'disk': 'Disk',
      'hostUnavailable': 'Host metrics unavailable',
      // uptime
      'uptimeTitle': 'Service Uptime',
      'up': 'UP',
      'down': 'DOWN',
      'latency': 'Latency',
      'certExpires': 'Cert expires in {days}d',
      // alerts
      'alertsTitle': 'Active Alerts',
      'noAlerts': 'No active alerts',
      // settings
      'settingsTitle': 'Settings',
      'aiProviderSettings': 'AI Provider',
      'configureProvider':
          'Configure your AI provider. Supports any OpenAI-compatible API (Ollama, LM Studio, cloud).',
      'providerType': 'Provider Type',
      'baseUrl': 'Base URL',
      'modelName': 'Model Name',
      'apiKey': 'API Key',
      'saveSettings': 'Save Settings',
      'settingsSaved': 'Settings saved successfully',
      'settingsSaveFailed': 'Failed to save',
      'apiKeyEncrypted': 'API keys are encrypted at rest in Supabase.',
      'apiKeyOptional': 'Optional for local providers',
      'apiKeyRequired': 'Required for cloud providers',
      'apiKeyRequiredError': 'API key required for cloud providers',
      'required': 'Required',
      'providerOllama': 'Ollama',
      'providerLmStudio': 'LM Studio',
      'providerAnthropic': 'Anthropic (Claude)',
      'providerCloud': 'Cloud API',
      'providerCustom': 'Custom',
      'appearance': 'Appearance',
      'languageEnglish': 'English',
      'languageArabic': 'العربية',
      'themeDark': 'Dark',
      'themeLight': 'Light',
      'themeSystem': 'System',
      // analyze dialog
      'aiLogAnalysis': 'AI Log Analysis',
      'analyzing': 'Fetching & analyzing logs…',
      'redactNote': 'Sensitive data is redacted before sending to AI',
      'modelLabel': 'Model',
      'sanitizedNote': 'Logs sanitized before analysis',
      'retry': 'Retry',
      'startAnalysis': 'Start analysis',
      'configureFirst': 'Configure AI settings first (Settings page).',
      'analyzeIntro':
          'Fetch the latest logs and analyze them with your configured AI provider. Sensitive data is redacted first.',
      // logs viewer
      'viewLogs': 'View logs',
      'logsTitle': 'Logs',
      'noLogs': 'No logs',
      'logsLoadFailed': 'Could not load logs',
      // ask dialog
      'askTitle': 'Ask AI about your server',
      'askHint': 'e.g. Why did nginx restart? Is anything unhealthy?',
      'askSend': 'Ask',
      'askThinking': 'Thinking…',
      'askEmpty': 'Ask a question about your containers, host, or uptime.',
      'askConfigureFirst': 'Configure AI settings first (Settings page).',
      // history
      'historyTitle': 'Metrics History',
      'noHistory': 'No history yet. The agent stores snapshots over time.',
      'hostCpuMem': 'Host CPU / Memory (%)',
      'rangeDay': 'Day',
      'rangeWeek': 'Week',
      'rangeMonth': 'Month',
      'historyError': 'Could not load history',
      // auth & roles
      'loginTitle': 'Rased — Sign in',
      'email': 'Email',
      'password': 'Password',
      'signIn': 'Sign in',
      'signUp': 'Create account',
      'noAccountSignUp': 'No account? Create one',
      'haveAccountSignIn': 'Have an account? Sign in',
      'authFailed': 'Authentication failed',
      'firstUserAdmin': 'The first account created becomes the admin.',
      'signOut': 'Sign out',
      'users': 'Users',
      'usersTitle': 'User Management',
      'usersError': 'Could not load users',
      'role': 'Role',
      'roleAdmin': 'Admin',
      'roleViewer': 'Viewer',
      'adminsOnly': 'Admins only',
      'viewerReadOnly': 'View only — container actions require an admin.',
      // chat & devices
      'chatTitle': 'AI Chat',
      'newChat': 'New chat',
      'conversations': 'Conversations',
      'noChats': 'No saved conversations yet',
      'chatHint': 'Ask about this server…',
      'send': 'Send',
      'you': 'You',
      'aiName': 'AI',
      'deleteChat': 'Delete conversation',
      'analysisSaved': 'Saved to conversations',
      'device': 'Device',
    },
    'ar': {
      'appTitle': 'لوحة راصد',
      'agentOnline': 'الوكيل متصل',
      'agentOffline': 'الوكيل غير متصل',
      'checking': 'جارٍ الفحص…',
      'refresh': 'تحديث',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'askAi': 'اسأل الذكاء',
      'history': 'السجل التاريخي',
      'waitingMetrics': 'بانتظار البيانات…',
      'noContainers': 'لا توجد حاويات Docker',
      'cpu': 'المعالج',
      'ram': 'الذاكرة',
      'restarts': 'إعادة التشغيل',
      'liveUsage': 'الاستخدام الحيّ',
      'collectingData': 'جارٍ جمع البيانات…',
      'analyzeLogs': 'تحليل السجلات',
      'restart': 'إعادة تشغيل',
      'stop': 'إيقاف',
      'start': 'تشغيل',
      'actions': 'إجراءات',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'confirmActionTitle': 'تأكيد الإجراء',
      'confirmActionBody': 'هل أنت متأكد من «{action}» للحاوية «{name}»؟',
      'actionSuccess': 'تم تنفيذ الإجراء',
      'actionFailed': 'فشل الإجراء',
      'upsStatus': 'حالة الـ UPS',
      'upsDisconnected': 'NUT غير متصل',
      'onBattery': 'يعمل على البطارية',
      'onMains': 'متصل بالكهرباء',
      'battery': 'البطارية',
      'hostTitle': 'الخادم المضيف',
      'hostCpu': 'المعالج',
      'hostMemory': 'الذاكرة',
      'load': 'الحِمل',
      'cores': 'نواة',
      'disk': 'القرص',
      'hostUnavailable': 'مقاييس المضيف غير متاحة',
      'uptimeTitle': 'توفّر الخدمات',
      'up': 'يعمل',
      'down': 'متوقف',
      'latency': 'زمن الاستجابة',
      'certExpires': 'تنتهي الشهادة خلال {days} يوم',
      'alertsTitle': 'تنبيهات نشطة',
      'noAlerts': 'لا توجد تنبيهات',
      'settingsTitle': 'الإعدادات',
      'aiProviderSettings': 'مزوّد الذكاء الاصطناعي',
      'configureProvider':
          'اضبط مزوّد الذكاء الاصطناعي. يدعم أي واجهة متوافقة مع OpenAI (Ollama، LM Studio، السحابة).',
      'providerType': 'نوع المزوّد',
      'baseUrl': 'عنوان الـ URL',
      'modelName': 'اسم النموذج',
      'apiKey': 'مفتاح الـ API',
      'saveSettings': 'حفظ الإعدادات',
      'settingsSaved': 'تم حفظ الإعدادات بنجاح',
      'settingsSaveFailed': 'فشل الحفظ',
      'apiKeyEncrypted': 'مفاتيح الـ API مشفّرة في Supabase.',
      'apiKeyOptional': 'اختياري للمزوّدات المحلية',
      'apiKeyRequired': 'مطلوب للمزوّدات السحابية',
      'apiKeyRequiredError': 'مفتاح الـ API مطلوب للمزوّدات السحابية',
      'required': 'مطلوب',
      'providerOllama': 'Ollama',
      'providerLmStudio': 'LM Studio',
      'providerAnthropic': 'Anthropic (Claude)',
      'providerCloud': 'سحابي',
      'providerCustom': 'مخصّص',
      'appearance': 'المظهر واللغة',
      'languageEnglish': 'English',
      'languageArabic': 'العربية',
      'themeDark': 'داكن',
      'themeLight': 'فاتح',
      'themeSystem': 'النظام',
      'aiLogAnalysis': 'تحليل السجلات بالذكاء',
      'analyzing': 'جارٍ جلب السجلات وتحليلها…',
      'redactNote': 'تُحجب البيانات الحساسة قبل الإرسال للذكاء',
      'modelLabel': 'النموذج',
      'sanitizedNote': 'السجلات مُنقّاة قبل التحليل',
      'retry': 'إعادة المحاولة',
      'startAnalysis': 'ابدأ التحليل',
      'configureFirst': 'اضبط إعدادات الذكاء أولاً (صفحة الإعدادات).',
      'analyzeIntro':
          'اجلب أحدث السجلات وحلّلها بمزوّد الذكاء المُعَد. تُحجب البيانات الحساسة أولاً.',
      'viewLogs': 'عرض السجلات',
      'logsTitle': 'السجلات',
      'noLogs': 'لا توجد سجلات',
      'logsLoadFailed': 'تعذّر تحميل السجلات',
      'askTitle': 'اسأل الذكاء عن خادمك',
      'askHint': 'مثال: لماذا أُعيد تشغيل nginx؟ هل هناك خلل؟',
      'askSend': 'اسأل',
      'askThinking': 'جارٍ التفكير…',
      'askEmpty': 'اطرح سؤالاً عن حاوياتك أو المضيف أو التوفّر.',
      'askConfigureFirst': 'اضبط إعدادات الذكاء أولاً (صفحة الإعدادات).',
      'historyTitle': 'السجل التاريخي للمقاييس',
      'noHistory': 'لا يوجد سجل بعد. يخزّن الوكيل لقطات عبر الزمن.',
      'hostCpuMem': 'معالج/ذاكرة المضيف (%)',
      'rangeDay': 'يوم',
      'rangeWeek': 'أسبوع',
      'rangeMonth': 'شهر',
      'historyError': 'تعذّر تحميل السجل',
      // auth & roles
      'loginTitle': 'راصد — تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'signIn': 'تسجيل الدخول',
      'signUp': 'إنشاء حساب',
      'noAccountSignUp': 'ليس لديك حساب؟ أنشئ واحداً',
      'haveAccountSignIn': 'لديك حساب؟ سجّل الدخول',
      'authFailed': 'فشل تسجيل الدخول',
      'firstUserAdmin': 'أوّل حساب يُنشأ يصبح المدير.',
      'signOut': 'تسجيل الخروج',
      'users': 'المستخدمون',
      'usersTitle': 'إدارة المستخدمين',
      'usersError': 'تعذّر تحميل المستخدمين',
      'role': 'الدور',
      'roleAdmin': 'مدير',
      'roleViewer': 'مشاهد',
      'adminsOnly': 'للمدراء فقط',
      'viewerReadOnly': 'عرض فقط — أوامر الحاويات تتطلّب مديراً.',
      // chat & devices
      'chatTitle': 'محادثة الذكاء',
      'newChat': 'محادثة جديدة',
      'conversations': 'المحادثات',
      'noChats': 'لا توجد محادثات محفوظة بعد',
      'chatHint': 'اسأل عن هذا الخادم…',
      'send': 'إرسال',
      'you': 'أنت',
      'aiName': 'الذكاء',
      'deleteChat': 'حذف المحادثة',
      'analysisSaved': 'حُفظت في المحادثات',
      'device': 'الجهاز',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).t(key);
}
