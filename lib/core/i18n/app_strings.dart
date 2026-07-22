import 'package:flutter/widgets.dart';

/// Lightweight in-app i18n — no ARB codegen needed.
/// Usage: `S.of(context).call` or `context.s.call`.
class S {
  final Locale locale;
  S(this.locale);

  static S of(BuildContext context) {
    final l = Localizations.localeOf(context);
    return S(l);
  }

  bool get _ar => locale.languageCode == 'ar';

  String _t(String en, String ar) => _ar ? ar : en;

  // App / shell
  String get appTitle => _t('Awfar CC', 'Awfar CC');
  String get tabRecents => _t('Recents', 'الأخيرة');
  String get tabContacts => _t('Contacts', 'جهات الاتصال');
  String get tabKeypad => _t('Keypad', 'لوحة الأرقام');
  String get tabSettings => _t('Settings', 'الإعدادات');

  // Presence
  String get online => _t('Online', 'متصل');
  String get offline => _t('Offline', 'غير متصل');
  String get dnd => _t('DND', 'عدم الإزعاج');
  String get doNotDisturb => _t('Do Not Disturb', 'عدم الإزعاج');
  String get connecting => _t('Connecting…', 'جارٍ الاتصال…');
  String get status => _t('Status', 'الحالة');
  String get presenceOnlineSub => _t('Make and receive calls', 'إجراء واستقبال المكالمات');
  String get presenceDndSub => _t('Make calls, auto-reject incoming', 'إجراء المكالمات ورفض الواردة تلقائيًا');
  String get presenceOfflineSub => _t('No calls in or out', 'لا مكالمات داخلة أو خارجة');
  String get youAreOffline => _t(
      'You are Offline. Switch to Online to make calls.',
      'أنت غير متصل. قم بالتبديل إلى "متصل" لإجراء المكالمات.');

  // Dialer
  String get sipAccount => _t('SIP Account', 'حساب SIP');
  String get notConfigured => _t('Not configured', 'غير مُعد');
  String get enterNumber => _t('Enter number', 'أدخل الرقم');
  String get call => _t('Call', 'اتصال');

  // Add contact
  String get addNewContact => _t('Add new contact', 'إضافة جهة اتصال جديدة');
  String get name => _t('Name', 'الاسم');
  String get number => _t('Number', 'الرقم');
  String get cancel => _t('Cancel', 'إلغاء');
  String get save => _t('Save', 'حفظ');
  String savedAs(String name) => _t('Saved "$name"', 'تم الحفظ "$name"');

  // Ongoing call bar
  String get tapToReturn => _t('Tap to return', 'اضغط للعودة');
  String get ringing => _t('Ringing…', 'يرن…');

  // Settings
  String get profile => _t('Profile', 'الملف الشخصي');
  String get notifications => _t('Notifications', 'الإشعارات');
  String get theme => _t('Theme', 'المظهر');
  String get themeSystem => _t('System', 'النظام');
  String get themeLight => _t('Light', 'فاتح');
  String get themeDark => _t('Dark', 'داكن');
  String get language => _t('Language', 'اللغة');
  String get languageEnglish => _t('English', 'English');
  String get languageArabic => _t('Arabic', 'العربية');
  String get languageSystem => _t('System', 'النظام');
  String get about => _t('About', 'حول');
  String get signOut => _t('Sign out', 'تسجيل الخروج');

  // Integration / backend API
  String get integrationSettings => _t('Backend & Webphone', 'الخادم والـ Webphone');
  String get integrationSettingsSub => _t(
        'Connect this app to your CRM or webphone API. The URL is saved on this device only.',
        'اربط التطبيق بـ CRM أو Webphone API. الرابط يُحفظ على هذا الجهاز فقط.',
      );
  String get integrationConfigured => _t('Backend connected', 'الخادم مُعد');
  String get integrationNotConfigured => _t('No backend URL saved', 'لم يُحفظ رابط الخادم');
  String get integrationApiUrl => _t('API base URL', 'رابط API الأساسي');
  String get integrationApiUrlRequired => _t('Enter your system API URL', 'أدخل رابط API للنظام');
  String get integrationAdvancedPaths => _t('Custom API paths', 'مسارات API مخصصة');
  String get integrationAdvancedPathsSub => _t(
        'Leave empty to use default webphone paths',
        'اتركها فارغة لاستخدام مسارات Webphone الافتراضية',
      );
  String get integrationCommandsPath => _t('Commands pull path', 'مسار جلب الأوامر');
  String get integrationSendPath => _t('Send command path', 'مسار إرسال الأوامر');
  String get integrationTestConnection => _t('Test connection', 'اختبار الاتصال');
  String get integrationSaved => _t('Integration settings saved', 'تم حفظ إعدادات الربط');
  String get integrationClear => _t('Clear saved URL', 'مسح الرابط المحفوظ');
  String integrationReachable(int code) =>
      _t('Server reachable (HTTP $code)', 'الخادم متاح (HTTP $code)');
  String integrationUnreachable(String detail) =>
      _t('Could not reach server: $detail', 'تعذّر الوصول للخادم: $detail');

  // Break reasons (Offline / DND)
  String get selectReason => _t('Select a reason', 'اختر السبب');
  String get customReason => _t('Custom reason', 'سبب مخصص');
  String get confirm => _t('Confirm', 'تأكيد');
  String get goingOffline => _t('Going Offline', 'الانتقال إلى غير متصل');
  String get goingDnd => _t('Going Do Not Disturb', 'الانتقال إلى عدم الإزعاج');
  String get reasonMeeting => _t('Meeting', 'اجتماع');
  String get reasonTraining => _t('Training', 'تدريب');
  String get reasonLunch => _t('Lunch', 'غداء');
  String get reasonPersonal => _t('Personal', 'شخصي');
  String get reasonAdmin => _t('Admin', 'مهام إدارية');
  String get reasonPrayer => _t('Prayer', 'صلاة');
  String get reasonBreak => _t('Break', 'استراحة');
  String get reasonOther => _t('Other', 'أخرى');

  // Contact tags
  String get tagVip => _t('VIP', 'VIP');
  String get tagLead => _t('Lead', 'Lead');
  String get tagCustomer => _t('Customer', 'عميل');
  String get tagBlocked => _t('Blocked', 'محظور');
  String get tagComplaint => _t('Complaint', 'شكوى');
  String get tagCustom => _t('Custom', 'مخصص');
  String get contactTags => _t('Tags', 'الوسوم');

  // Smart Caller ID
  String get incomingCall => _t('Incoming call', 'مكالمة واردة');
  String get decline => _t('Decline', 'رفض');
  String get accept => _t('Accept', 'قبول');
  String get callerInfoTitle => _t('Caller info', 'معلومات المتصل');
  String get callerBlockedWarning => _t(
        'This number is blocked — incoming calls are auto-rejected',
        'هذا الرقم محظور — المكالمات الواردة تُرفض تلقائيًا');
  String callerPreviousCalls(int count) =>
      _t('Called $count time${count == 1 ? '' : 's'}', 'اتصل $count مرة');
  String callerLastContact(String relative) =>
      _t('Last contact: $relative', 'آخر تواصل: $relative');
  String callerLastDisposition(String disposition) =>
      _t('Last disposition: $disposition', 'آخر disposition: $disposition');
  String callerLastNote(String note) =>
      _t('Last note: $note', 'آخر ملاحظة: $note');
  String get relativeJustNow => _t('just now', 'الآن');
  String relativeMinutesAgo(int n) =>
      _t('$n min ago', n == 1 ? 'منذ دقيقة' : 'منذ $n دقيقة');
  String relativeHoursAgo(int n) =>
      _t('$n h ago', n == 1 ? 'منذ ساعة' : 'منذ $n ساعة');
  String relativeDaysAgo(int n) =>
      _t('$n d ago', n == 1 ? 'منذ يوم' : 'منذ $n يوم');
  String relativeWeeksAgo(int n) =>
      _t('$n w ago', n == 1 ? 'منذ أسبوع' : 'منذ $n أسابيع');
  String relativeMonthsAgo(int n) =>
      _t('$n mo ago', n == 1 ? 'منذ شهر' : 'منذ $n أشهر');
  String relativeYearsAgo(int n) =>
      _t('$n y ago', n == 1 ? 'منذ سنة' : 'منذ $n سنوات');

  // Share / productivity
  String get autoDialFromShare => _t('Auto-dial from share', 'Auto-dial من المشاركة');
  String get autoDialFromShareSub => _t(
        'Start a call immediately when sharing a number to Awfar CC',
        'بدء مكالمة فورًا عند مشاركة رقم مع Awfar CC');
  String get headsetConnected => _t('Headset connected', 'سماعة متصلة');

  // Local call park (hold + return later)
  String get park => _t('Park', 'Park');
  String get parkCallTitle => _t('Park call', 'إيقاف مؤقت');
  String parkCallBody(String name) => _t(
        'Put $name on hold while you make another call? The customer stays connected.',
        'إيقاف $name مؤقتًا أثناء إجراء مكالمة أخرى؟ العميل يظل متصلًا.');
  String heldCallSaved(String name) =>
      _t('$name is on hold — you can dial another number', '$name على hold — يمكنك الاتصال برقم آخر');
  String get heldCallOnHold => _t('On hold', 'على hold');
  String get retrievePark => _t('Return to call', 'العودة للمكالمة');
  String get dismissPark => _t('End held call', 'إنهاء المكالمة الموقوفة');
}

extension SExt on BuildContext {
  S get s => S.of(this);
}
