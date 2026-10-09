// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'DubaGest';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCreate => 'إنشاء';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get commonActive => 'نشط';

  @override
  String get commonInactive => 'غير نشط';

  @override
  String get commonOptional => 'اختياري';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get authLoginTitle => 'تسجيل الدخول';

  @override
  String get authLoginSubtitle => 'ادخل إلى مساحة مؤسستك';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authSignIn => 'دخول';

  @override
  String get authSignOut => 'تسجيل الخروج';

  @override
  String get authSignOutPendingTitle => 'تعديلات غير متزامنة';

  @override
  String authSignOutPendingMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيتم إرسال $count تعديلًا',
      few: 'سيتم إرسال $count تعديلات',
      two: 'سيتم إرسال تعديلين',
      one: 'سيتم إرسال تعديل واحد',
    );
    return '$_temp0 عند تسجيل دخولك القادم على هذا الجهاز. هل تريد تسجيل الخروج رغم ذلك؟';
  }

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authForgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get authForgotPasswordHelp =>
      'أدخل بريدك الإلكتروني. ستتلقى رابطًا لاختيار كلمة مرور جديدة.';

  @override
  String get authSendResetLink => 'إرسال الرابط';

  @override
  String get authResetLinkSent =>
      'إذا كان هناك حساب بهذا العنوان، فقد تم إرسال بريد إلكتروني.';

  @override
  String get authBackToLogin => 'العودة إلى تسجيل الدخول';

  @override
  String get authChangePassword => 'تغيير كلمة المرور';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authPasswordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get authSessionExpired =>
      'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجددًا.';

  @override
  String get validationRequired => 'حقل إلزامي';

  @override
  String get validationEmail => 'بريد إلكتروني غير صالح';

  @override
  String validationPasswordLength(int min) {
    return '$min أحرف على الأقل';
  }

  @override
  String get validationPasswordsMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get errorNetwork => 'تعذر الاتصال. تحقق من الشبكة.';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorEmailNotConfirmed => 'البريد الإلكتروني غير مؤكد.';

  @override
  String get errorRateLimited => 'محاولات كثيرة. أعد المحاولة بعد بضع دقائق.';

  @override
  String get errorSessionExpired => 'انتهت صلاحية الجلسة.';

  @override
  String get errorForbidden => 'ليست لديك صلاحية تنفيذ هذا الإجراء.';

  @override
  String get errorNotFound => 'العنصر غير موجود.';

  @override
  String get errorConflict => 'قام شخص آخر بتعديل هذا العنصر.';

  @override
  String get errorDuplicate => 'يوجد عنصر بهذا الاسم مسبقًا.';

  @override
  String get errorServer => 'الخدمة غير متاحة مؤقتًا.';

  @override
  String get errorLocalStorage => 'خطأ في التخزين على الجهاز.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع.';

  @override
  String get ruleSubscriptionInactive => 'اشتراك مؤسستك غير نشط.';

  @override
  String ruleActivityNotAllowed(String plan) {
    return 'باقة $plan لا تشمل هذا النشاط.';
  }

  @override
  String get ruleActivityInactive => 'هذا النشاط غير مفعّل لمؤسستك.';

  @override
  String ruleActivitiesLimit(String plan, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max نشاطًا',
      few: '$max أنشطة',
      two: 'نشاطين',
      one: 'نشاط واحد',
    );
    return 'تسمح باقة $plan بحد أقصى $_temp0.';
  }

  @override
  String ruleUsersLimit(String plan, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max مستخدمًا',
      few: '$max مستخدمين',
      two: 'مستخدمين اثنين',
      one: 'مستخدم واحد',
    );
    return 'تسمح باقة $plan بحد أقصى $_temp0.';
  }

  @override
  String ruleRoleLimit(String plan, int max, String role) {
    return 'تسمح باقة $plan بحد أقصى $max «$role».';
  }

  @override
  String rulePerimetresLimit(String plan, int max, String activity) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max موقعًا',
      few: '$max مواقع',
      two: 'موقعين',
      one: 'موقع واحد',
    );
    return 'تسمح باقة $plan بحد أقصى $_temp0 لنشاط $activity.';
  }

  @override
  String ruleRoleNotAllowed(String plan) {
    return 'هذا الدور غير متاح في باقة $plan.';
  }

  @override
  String get ruleRoleActivityInactive => 'يتطلب هذا الدور نشاطًا غير مفعّل.';

  @override
  String get ruleModuleNotInPlan => 'هذه الوحدة غير مشمولة في اشتراكك.';

  @override
  String get rulePermissionDenied => 'دورك لا يسمح بهذا الإجراء.';

  @override
  String get rulePerimetreDenied => 'أنت غير مُعيَّن لهذا الموقع.';

  @override
  String get ruleLastAdmin => 'يجب أن تحتفظ المؤسسة بمسؤول واحد على الأقل.';

  @override
  String get ruleAssignmentNotNeeded =>
      'هذا الدور يصل بالفعل إلى جميع المواقع.';

  @override
  String get ruleAssignmentActivityMismatch =>
      'هذا الموقع لا ينتمي إلى نشاط الدور.';

  @override
  String get ruleImmutable => 'لم يعد من الممكن تعديل هذه المعلومة.';

  @override
  String get contextLoading => 'جارٍ تجهيز مساحتك…';

  @override
  String get contextLoadError => 'تعذر تحميل مساحة العمل.';

  @override
  String get contextOfflineCache =>
      'غير متصل — عرض البيانات المحفوظة على الجهاز.';

  @override
  String get contextNoEntrepriseTitle => 'لا توجد مؤسسة';

  @override
  String get contextNoEntrepriseMessage =>
      'حسابك غير مرتبط بأي مؤسسة. تواصل مع المسؤول.';

  @override
  String get contextMemberSuspendedTitle => 'الوصول معلّق';

  @override
  String contextMemberSuspendedMessage(String entreprise) {
    return 'وصولك إلى $entreprise معلّق. تواصل مع المسؤول.';
  }

  @override
  String get contextEntrepriseSuspendedTitle => 'المؤسسة معلّقة';

  @override
  String contextEntrepriseSuspendedMessage(String entreprise) {
    return 'الوصول إلى $entreprise معلّق مؤقتًا.';
  }

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navAdministration => 'الإدارة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String homeGreeting(String name) {
    return 'مرحبًا $name';
  }

  @override
  String get homeGreetingAnonymous => 'مرحبًا';

  @override
  String get homeNoModules => 'لا توجد وحدة متاحة لدورك.';

  @override
  String get homeSubscriptionInactive =>
      'الوحدات غير متاحة ما دام الاشتراك غير نشط.';

  @override
  String get moduleComingSoonTitle => 'قريبًا';

  @override
  String get moduleComingSoonMessage => 'ستتوفر هذه الوحدة في إصدار قادم.';

  @override
  String get accessDeniedTitle => 'الوصول مرفوض';

  @override
  String get accessDeniedBackHome => 'العودة إلى الرئيسية';

  @override
  String get activityCommerce => 'التجارة';

  @override
  String get activityServices => 'الخدمات';

  @override
  String get activityImmobilier => 'العقارات';

  @override
  String get roleAdministrateur => 'المسؤول';

  @override
  String get roleSuperviseur => 'المشرف';

  @override
  String get roleGestionnaireStock => 'مسؤول المخزون';

  @override
  String get roleVendeur => 'البائع';

  @override
  String get planNormal => 'العادية';

  @override
  String get planMoyen => 'المتوسطة';

  @override
  String get planPro => 'الاحترافية';

  @override
  String get moduleAdminEntreprise => 'المؤسسة';

  @override
  String get moduleAdminUtilisateurs => 'المستخدمون';

  @override
  String get moduleAdminPerimetres => 'المحلات والمواقع';

  @override
  String get moduleAdminAbonnement => 'الاشتراك';

  @override
  String get moduleCommerceProduits => 'المنتجات';

  @override
  String get moduleCommerceStock => 'المخزون';

  @override
  String get moduleCommerceVentes => 'المبيعات';

  @override
  String get moduleCommerceAchats => 'المشتريات';

  @override
  String get moduleCommunContacts => 'جهات الاتصال';

  @override
  String get moduleCommerceFournisseurs => 'الموردون';

  @override
  String get moduleFinancesCreances => 'المستحقات / الديون';

  @override
  String get moduleFinancesCreancesCourt => 'الديون';

  @override
  String get moduleCommunContactsClients => 'العملاء';

  @override
  String get moduleFinancesPaiements => 'المدفوعات';

  @override
  String get moduleFinancesCaisse => 'الصندوق';

  @override
  String get moduleFinancesDepenses => 'المصاريف';

  @override
  String get moduleServicesServices => 'دليل الخدمات';

  @override
  String get moduleServicesPrestations => 'الخدمات';

  @override
  String get moduleServicesPlanning => 'الجدول';

  @override
  String get moduleServicesDevis => 'عروض الأسعار';

  @override
  String get moduleServicesFacturation => 'الفواتير والإيصالات';

  @override
  String get moduleServicesRapports => 'التقارير';

  @override
  String get moduleImmobilierBiens => 'العقارات';

  @override
  String get moduleImmobilierProprietaires => 'الملاك';

  @override
  String get moduleImmobilierLocataires => 'المستأجرون';

  @override
  String get moduleImmobilierLocations => 'الإيجارات';

  @override
  String get moduleImmobilierContrats => 'العقود';

  @override
  String get moduleImmobilierLoyers => 'بدلات الإيجار';

  @override
  String get perimetreTypeBoutique => 'محل';

  @override
  String get perimetreTypeAgence => 'وكالة';

  @override
  String get perimetreTypeSite => 'موقع';

  @override
  String get perimetreTypeUnite => 'وحدة';

  @override
  String get perimetresEmpty => 'لا توجد مواقع حاليًا.';

  @override
  String get perimetreAdd => 'إضافة';

  @override
  String get perimetreNew => 'موقع جديد';

  @override
  String get perimetreEdit => 'تعديل الموقع';

  @override
  String get perimetreName => 'الاسم';

  @override
  String get perimetreCode => 'الرمز';

  @override
  String get perimetreActivity => 'النشاط';

  @override
  String get perimetreType => 'النوع';

  @override
  String get perimetreDeleteTitle => 'حذف هذا الموقع؟';

  @override
  String perimetreDeleteMessage(String name) {
    return 'لن يعود «$name» متاحًا.';
  }

  @override
  String get usersEmpty => 'لا يوجد مستخدمون.';

  @override
  String get usersInvite => 'إضافة مستخدم';

  @override
  String get usersInviteComingSoon => 'ستتوفر دعوة المستخدمين في إصدار قادم.';

  @override
  String get usersYou => 'أنت';

  @override
  String get usersAssignments => 'المواقع المعيّنة';

  @override
  String get usersAllPerimetres => 'جميع المواقع';

  @override
  String get usersNoPerimetre => 'لا يوجد موقع معيّن';

  @override
  String get usersOnlineOnly => 'يتطلب هذا الإجراء اتصالًا بالإنترنت.';

  @override
  String get subscriptionPlan => 'الباقة';

  @override
  String get subscriptionStatus => 'الحالة';

  @override
  String get subscriptionStatusEssai => 'تجريبي';

  @override
  String get subscriptionStatusActif => 'نشط';

  @override
  String get subscriptionStatusSuspendu => 'معلّق';

  @override
  String get subscriptionStatusExpire => 'منتهي';

  @override
  String get subscriptionStatusAnnule => 'ملغى';

  @override
  String subscriptionSince(String date) {
    return 'منذ $date';
  }

  @override
  String subscriptionUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get subscriptionNone => 'لا يوجد اشتراك.';

  @override
  String get subscriptionActivities => 'الأنشطة';

  @override
  String get subscriptionUsage => 'الاستهلاك';

  @override
  String get subscriptionUsers => 'المستخدمون';

  @override
  String subscriptionUsageValue(int used, int max) {
    return '$used / $max';
  }

  @override
  String get entrepriseInfo => 'المعلومات';

  @override
  String get entrepriseName => 'الاسم';

  @override
  String get entrepriseCountry => 'البلد';

  @override
  String get entrepriseCurrency => 'العملة';

  @override
  String get entrepriseRole => 'دورك';

  @override
  String get syncUpToDate => 'البيانات محدّثة';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعديلًا قيد الانتظار',
      few: '$count تعديلات قيد الانتظار',
      two: 'تعديلان قيد الانتظار',
      one: 'تعديل واحد قيد الانتظار',
    );
    return '$_temp0';
  }

  @override
  String get syncSyncing => 'جارٍ المزامنة…';

  @override
  String get syncError => 'فشلت المزامنة';

  @override
  String get syncOffline => 'غير متصل';

  @override
  String get syncOfflineBanner =>
      'وضع عدم الاتصال: سيتم إرسال تعديلاتك عند عودة الاتصال.';

  @override
  String syncLastSynced(String time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get syncRecordPending => 'في انتظار الإرسال';

  @override
  String get syncRecordError => 'غير متزامن';

  @override
  String get syncRecordConflict =>
      'عُدّل في مكان آخر — تم الاحتفاظ بنسخة الخادم';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsEntreprise => 'المؤسسة';

  @override
  String get settingsSync => 'المزامنة';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get authRegisterTitle => 'أنشئ حسابك';

  @override
  String get authRegisterSubtitle => 'مجانًا، في أقل من دقيقة.';

  @override
  String get authFirstName => 'الاسم';

  @override
  String get authLastName => 'اللقب';

  @override
  String get authCreateAccount => 'إنشاء حسابي';

  @override
  String get authNoAccount => 'ليس لديك حساب بعد؟';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get authSignInLink => 'تسجيل الدخول';

  @override
  String get authRegisterLink => 'إنشاء حساب';

  @override
  String get authContinueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get authOr => 'أو';

  @override
  String get authCheckEmailTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String authCheckEmailMessage(String email) {
    return 'تم إرسال رابط تأكيد إلى $email. افتحه ثم سجّل الدخول.';
  }

  @override
  String get authResetPasswordTitle => 'كلمة مرور جديدة';

  @override
  String get errorAccountExists => 'هذا الحساب موجود بالفعل. سجّل الدخول.';

  @override
  String get errorWeakPassword => 'كلمة المرور ضعيفة جدًا.';

  @override
  String get errorOauthUnavailable =>
      'تسجيل الدخول عبر Google غير متاح حاليًا.';

  @override
  String onboardingWelcome(String name) {
    return 'مرحبًا $name';
  }

  @override
  String get onboardingWelcomeAnonymous => 'مرحبًا';

  @override
  String get onboardingQuestion => 'ماذا تريد أن تفعل؟';

  @override
  String get onboardingCreateTitle => 'إنشاء مؤسستي';

  @override
  String get onboardingCreateSubtitle => 'ستكون مسؤولها.';

  @override
  String get onboardingJoinTitle => 'الانضمام إلى مؤسسة';

  @override
  String get onboardingJoinSubtitle => 'باستخدام الدعوة التي أرسلها مسؤولك.';

  @override
  String get companyName => 'اسم المؤسسة';

  @override
  String get companyPlan => 'الباقة';

  @override
  String get companyActivities => 'الأنشطة';

  @override
  String companyActivitiesHint(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'حتى $max نشاطًا',
      few: 'حتى $max أنشطة',
      two: 'حتى نشاطين',
      one: 'اختر نشاطًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String get companyTrialInfo =>
      'تجربة مجانية لمدة 14 يومًا. ستكون مسؤول المؤسسة.';

  @override
  String get companyCreateButton => 'إنشاء المؤسسة';

  @override
  String get joinCodeLabel => 'رمز الدعوة';

  @override
  String get joinCodeHelp => 'الصق الرمز أو افتح الرابط الذي تلقيته.';

  @override
  String get joinCheck => 'تحقق';

  @override
  String joinInvitedTo(String entreprise) {
    return 'دعوة للانضمام إلى $entreprise';
  }

  @override
  String joinRole(String role) {
    return 'الدور: $role';
  }

  @override
  String joinForEmail(String email) {
    return 'موجّهة إلى $email';
  }

  @override
  String joinExpires(String date) {
    return 'صالحة حتى $date';
  }

  @override
  String get joinAccept => 'قبول الدعوة';

  @override
  String get joinIgnore => 'تجاهل';

  @override
  String get joinSignInToAccept =>
      'سجّل الدخول أو أنشئ حسابًا بالعنوان المدعو لقبول الدعوة.';

  @override
  String get ruleInvitationInvalid => 'هذه الدعوة غير صالحة.';

  @override
  String get ruleInvitationExpired => 'انتهت صلاحية هذه الدعوة.';

  @override
  String get ruleInvitationUsed => 'تم استخدام هذه الدعوة من قبل.';

  @override
  String get ruleInvitationCancelled => 'تم إلغاء هذه الدعوة.';

  @override
  String get ruleInvitationOtherEmail =>
      'هذه الدعوة موجّهة إلى بريد إلكتروني آخر.';

  @override
  String get ruleInvitationNotCancellable =>
      'لم يعد من الممكن إلغاء هذه الدعوة.';

  @override
  String get ruleEmailNotConfirmed => 'يرجى تأكيد بريدك الإلكتروني أولًا.';

  @override
  String get ruleAlreadyMember => 'هذا الشخص عضو في المؤسسة بالفعل.';

  @override
  String get ruleCompanyAlreadyCreated => 'لقد أنشأت مؤسسة بالفعل.';

  @override
  String get rulePlanInvalid => 'هذه الباقة غير متاحة.';

  @override
  String get ruleActivityRequired => 'اختر نشاطًا واحدًا على الأقل.';

  @override
  String get ruleNameInvalid => 'الاسم قصير جدًا.';

  @override
  String get rulePerimetreRequired =>
      'اختر موقعًا واحدًا على الأقل لهذا الدور.';

  @override
  String get inviteTitle => 'دعوة مستخدم';

  @override
  String get inviteRole => 'الدور';

  @override
  String get invitePerimetres => 'المواقع المسموح بها';

  @override
  String get inviteSend => 'إنشاء الدعوة';

  @override
  String get inviteNoRole => 'لا يوجد دور متاح في اشتراكك.';

  @override
  String get inviteCreatedTitle => 'تم إنشاء الدعوة';

  @override
  String inviteCreatedMessage(String email, String date) {
    return 'شارك هذا الرابط مع $email. صالح حتى $date ويُستخدم مرة واحدة.';
  }

  @override
  String get inviteCopyLink => 'نسخ الرابط';

  @override
  String get inviteCopyCode => 'نسخ الرمز';

  @override
  String get inviteCopied => 'تم النسخ';

  @override
  String get inviteCancel => 'إلغاء الدعوة';

  @override
  String get invitationsTitle => 'الدعوات';

  @override
  String get invitationStatusPending => 'قيد الانتظار';

  @override
  String get invitationStatusAccepted => 'مقبولة';

  @override
  String get invitationStatusExpired => 'منتهية';

  @override
  String get invitationStatusCancelled => 'ملغاة';

  @override
  String get navSell => 'بيع';

  @override
  String get navStock => 'المخزون';

  @override
  String get navFinances => 'المالية';

  @override
  String get navAccount => 'الحساب';

  @override
  String get financesComingSoon =>
      'لوحة المالية (رقم الأعمال، التحصيلات، المصاريف، الديون) تأتي مع وحدتي المبيعات والصندوق.';

  @override
  String get menuActivities => 'أنشطتي';

  @override
  String get menuPreferences => 'التفضيلات';

  @override
  String get menuSeeSubscription => 'عرض الاشتراك';

  @override
  String get activityStatusActive => 'نشط';

  @override
  String get activityActivate => 'تفعيل';

  @override
  String activityActivateTitle(String activity) {
    return 'تفعيل $activity؟';
  }

  @override
  String get activityActivateMessage =>
      'ستُضاف وحدات هذا النشاط إلى مؤسستك. أنشئ بعد ذلك أول موقع له.';

  @override
  String get activityActivated => 'تم تفعيل النشاط.';

  @override
  String get homeToday => 'اليوم';

  @override
  String get homeWatch => 'للمتابعة';

  @override
  String get homeKpiPending => 'ستظهر الأرقام فور تسجيل أولى المبيعات.';

  @override
  String get kpiRevenue => 'رقم الأعمال';

  @override
  String get kpiCollected => 'المحصَّل';

  @override
  String get kpiExpenses => 'المصاريف';

  @override
  String get kpiUnpaid => 'ديون العملاء';

  @override
  String homeTrialDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'التجربة: $days يومًا متبقيًا',
      few: 'التجربة: $days أيام متبقية',
      two: 'التجربة: يومان متبقيان',
      one: 'التجربة: يوم واحد متبقٍ',
      zero: 'تنتهي تجربتك اليوم',
    );
    return '$_temp0';
  }

  @override
  String get homeTrialHint => 'اختر باقتك للمتابعة دون انقطاع.';

  @override
  String get roleCaissier => 'أمين الصندوق';

  @override
  String get roleGestionnaireImmobilier => 'مدير العقارات';

  @override
  String subscriptionUsageUnlimited(int used) {
    return '$used · غير محدود';
  }

  @override
  String companyPlanPrice(String price) {
    return '$price / شهريًا';
  }

  @override
  String get entrepriseIdentity => 'الهوية';

  @override
  String get entrepriseContact => 'بيانات الاتصال';

  @override
  String get entrepriseLegal => 'المعلومات القانونية';

  @override
  String get entreprisePreferences => 'التفضيلات';

  @override
  String get entreprisePhone => 'الهاتف';

  @override
  String get entrepriseAddress => 'العنوان';

  @override
  String get entrepriseCity => 'المدينة';

  @override
  String get entrepriseTaxId => 'الرقم الضريبي';

  @override
  String get entrepriseTradeRegister => 'رقم السجل التجاري';

  @override
  String get entrepriseDocLanguage => 'لغة المستندات';

  @override
  String get entrepriseSaved => 'تم حفظ المعلومات.';

  @override
  String get entrepriseLogoLater =>
      'يمكن إضافة الشعار مع المرفقات (المرحلة القادمة).';

  @override
  String get moduleAdminAudit => 'سجل النشاط';

  @override
  String get auditEmpty => 'لا يوجد نشاط مسجل حاليًا.';

  @override
  String get auditSystem => 'النظام';

  @override
  String get auditActionCreation => 'إنشاء';

  @override
  String get auditActionModification => 'تعديل';

  @override
  String get auditActionArchivage => 'أرشفة';

  @override
  String get auditActionRestauration => 'استعادة';

  @override
  String get auditActionSuppression => 'حذف';

  @override
  String get auditEntityEntreprise => 'المؤسسة';

  @override
  String get auditEntityActivite => 'النشاط';

  @override
  String get auditEntityAbonnement => 'الاشتراك';

  @override
  String get auditEntityMembre => 'عضو';

  @override
  String get auditEntityAffectation => 'تعيين في موقع';

  @override
  String get auditEntitySite => 'موقع';

  @override
  String get auditEntityInvitation => 'دعوة';

  @override
  String auditOtherFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معلومة أخرى',
      few: '$count معلومات أخرى',
      two: 'معلومتان أخريان',
      one: 'معلومة أخرى',
    );
    return '$_temp0';
  }

  @override
  String get espaceTitle => 'مساحة العمل';

  @override
  String get espaceGlobal => 'نظرة شاملة';

  @override
  String get espaceActivity => 'النشاط';

  @override
  String get espaceSite => 'المحل / الموقع';

  @override
  String get commonClear => 'مسح';

  @override
  String ruleTextTooLong(int max) {
    return 'النص طويل جدًا ($max حرف كحد أقصى).';
  }

  @override
  String get homeCommonTools => 'أدوات مشتركة';

  @override
  String get contactRelationClient => 'عميل';

  @override
  String get contactRelationFournisseur => 'مورّد';

  @override
  String get contactRelationLocataire => 'مستأجر';

  @override
  String get contactRelationProprietaire => 'مالك';

  @override
  String get contactRelationPrestataire => 'مقدّم خدمة';

  @override
  String get contactTypePersonne => 'شخص';

  @override
  String get contactTypeOrganisation => 'مؤسسة';

  @override
  String get contactsSearchHint => 'الاسم، الهاتف، البريد، المدينة…';

  @override
  String get contactsFilterAll => 'الكل';

  @override
  String get contactsShowArchived => 'المؤرشفة';

  @override
  String get contactsEmpty =>
      'لا توجد جهات اتصال بعد. أضف عملاءك ومورّديك ومستأجريك…';

  @override
  String get contactsNoResult => 'لا توجد جهة اتصال مطابقة للبحث.';

  @override
  String get contactAdd => 'جهة اتصال جديدة';

  @override
  String get contactNew => 'جهة اتصال جديدة';

  @override
  String get contactEdit => 'تعديل جهة الاتصال';

  @override
  String get contactDetailTitle => 'بطاقة جهة الاتصال';

  @override
  String get contactNotFound => 'جهة الاتصال هذه غير موجودة أو لم تعد متاحة.';

  @override
  String get contactSaved => 'تم حفظ جهة الاتصال.';

  @override
  String get contactArchived => 'مؤرشفة';

  @override
  String get contactArchive => 'أرشفة';

  @override
  String get contactRestore => 'إعادة التفعيل';

  @override
  String get contactArchiveTitle => 'أرشفة جهة الاتصال هذه؟';

  @override
  String contactArchiveMessage(String name) {
    return 'لن تظهر «$name» في القوائم بعد الآن. يُحتفظ بسجلها ويمكنك إعادة تفعيلها.';
  }

  @override
  String get contactRelationsNone => 'لم تُحدَّد أي علاقة';

  @override
  String get contactFieldNom => 'اللقب';

  @override
  String get contactFieldRaisonSociale => 'الاسم التجاري';

  @override
  String get contactFieldPrenom => 'الاسم';

  @override
  String get contactFieldTelephone => 'الهاتف';

  @override
  String get contactFieldWhatsapp => 'واتساب';

  @override
  String get contactWhatsappHint => 'فقط إذا كان مختلفًا عن رقم الهاتف';

  @override
  String get contactFieldEmail => 'البريد الإلكتروني';

  @override
  String get contactFieldAdresse => 'العنوان';

  @override
  String get contactFieldVille => 'المدينة';

  @override
  String get contactFieldRemarque => 'ملاحظة';

  @override
  String get contactFieldRelations => 'العلاقة مع المؤسسة';

  @override
  String get contactCall => 'اتصال';

  @override
  String get contactWhatsapp => 'واتساب';

  @override
  String get contactEmailAction => 'بريد';

  @override
  String get contactActionUnavailable => 'هذا الإجراء غير متاح على هذا الجهاز.';

  @override
  String get contactHistoryTitle => 'السجل';

  @override
  String get contactHistoryEmpty =>
      'ستظهر هنا مبيعات جهة الاتصال ومدفوعاتها وإيجاراتها عند توفر هذه الوحدات.';

  @override
  String get contactDuplicateTitle => 'قد تكون جهة الاتصال هذه موجودة مسبقًا';

  @override
  String contactDuplicateMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'توجد $count بطاقات بنفس الاسم أو الهاتف.',
      one: 'توجد بطاقة بنفس الاسم أو الهاتف.',
    );
    return '$_temp0 استخدم البطاقة الموجودة للاحتفاظ بسجل واحد.';
  }

  @override
  String get contactDuplicateOpen => 'فتح البطاقة';

  @override
  String get contactDuplicateAddRelation => 'إضافة العلاقة';

  @override
  String get contactDuplicateCreateAnyway => 'إنشاء على أي حال';

  @override
  String get contactHistoryNone =>
      'لا توجد مبالغ مستحقة ولا مدفوعات لجهة الاتصال هذه.';

  @override
  String get contactOwesUs => 'مدين لنا';

  @override
  String get contactWeOwe => 'ندين له';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get homeSeeFinances => 'عرض المالية';

  @override
  String get validationAmount => 'أدخل مبلغًا أكبر من الصفر';

  @override
  String validationAmountMax(String max) {
    return '$max كحد أقصى';
  }

  @override
  String get paymentModeCash => 'نقدًا';

  @override
  String get paymentModeMobileMoney => 'الدفع عبر الهاتف';

  @override
  String get paymentModeCard => 'بطاقة';

  @override
  String get paymentModeTransfer => 'تحويل بنكي';

  @override
  String get paymentModeCheque => 'شيك';

  @override
  String get paymentModeOther => 'أخرى';

  @override
  String get debtStateUnpaid => 'للتحصيل';

  @override
  String get debtStateToPay => 'للدفع';

  @override
  String get debtStatePartial => 'جزئي';

  @override
  String get debtStateOverdue => 'متأخر';

  @override
  String get debtStatePaid => 'مسدَّد';

  @override
  String get debtStateCancelled => 'ملغى';

  @override
  String get cashMoveCollection => 'تحصيل';

  @override
  String get cashMoveDisbursement => 'صرف';

  @override
  String get cashMoveDeposit => 'إيداع';

  @override
  String get cashMoveWithdrawal => 'سحب';

  @override
  String get financeRejectedTitle => 'رفضه الخادم';

  @override
  String get financeRejectedMessage =>
      'لم تُسجَّل هذه العملية (صلاحيات، أو صندوق مغلق، أو تجاوز المبلغ). لا تُحتسب في أي مجموع.';

  @override
  String get financeRejectedRemove => 'إزالة';

  @override
  String get financeRejectedShort => 'مرفوض';

  @override
  String get financeNoContact => 'بدون جهة اتصال';

  @override
  String get financeContact => 'جهة الاتصال';

  @override
  String get financeInCash => 'في الصندوق';

  @override
  String get financeToReceive => 'للتحصيل';

  @override
  String get financeToPay => 'للدفع';

  @override
  String financeOverdueAmount(String amount) {
    return '$amount متأخرة';
  }

  @override
  String get financeNotFound => 'العنصر غير موجود أو غير متاح.';

  @override
  String get financeSite => 'المحل / الوكالة';

  @override
  String get financeAllSites => 'المؤسسة بأكملها';

  @override
  String get financePendingSync => 'محفوظ على الجهاز، في انتظار الإرسال';

  @override
  String get debtNewReceivable => 'مبلغ جديد للتحصيل';

  @override
  String get debtNewPayable => 'مبلغ جديد للدفع';

  @override
  String get debtShowSettled => 'عرض المسدَّدة';

  @override
  String get debtEmptyReceivable => 'لا أحد مدين لك بالمال.';

  @override
  String get debtEmptyPayable => 'لا تدين بشيء حاليًا.';

  @override
  String debtDueOn(String date) {
    return 'الاستحقاق $date';
  }

  @override
  String get debtDetailTitle => 'مبلغ مستحق';

  @override
  String get debtRemaining => 'المتبقي';

  @override
  String get debtPaid => 'المسدَّد';

  @override
  String get debtTotal => 'المبلغ الإجمالي';

  @override
  String get debtDate => 'التاريخ';

  @override
  String get debtDueDate => 'تاريخ الاستحقاق';

  @override
  String get debtNoDueDate => 'بدون تاريخ استحقاق';

  @override
  String get debtCancelReason => 'سبب الإلغاء';

  @override
  String get debtCollect => 'تحصيل';

  @override
  String get debtPay => 'دفع';

  @override
  String get debtCancel => 'إلغاء';

  @override
  String get debtPayments => 'المدفوعات';

  @override
  String get debtNoPayment => 'لا توجد مدفوعات بعد.';

  @override
  String get debtCancelTitle => 'إلغاء هذا المبلغ المستحق؟';

  @override
  String get debtCancelMessage => 'لن يُحتسب بعد الآن، ويبقى ظاهرًا في السجل.';

  @override
  String get debtEdit => 'تعديل المبلغ المستحق';

  @override
  String get debtWhoOwes => 'من عليه الدفع؟';

  @override
  String get debtOwedTo => 'لمن تدين؟';

  @override
  String get debtLabel => 'الموضوع';

  @override
  String get debtLabelHint => 'مثال: بضائع مسلَّمة بالدَّين';

  @override
  String debtAlreadyPaid(String amount) {
    return 'المسدَّد: $amount. لا يمكن أن يكون الإجمالي أقل.';
  }

  @override
  String get paymentNew => 'تحصيل';

  @override
  String get paymentsEmpty => 'لا توجد مدفوعات مسجلة.';

  @override
  String get paymentCancellation => 'إلغاء دفعة';

  @override
  String get paymentIn => 'مبلغ وارد';

  @override
  String get paymentOut => 'مبلغ صادر';

  @override
  String get paymentCancelled => 'ملغاة';

  @override
  String get paymentSaved => 'تم تسجيل الدفعة.';

  @override
  String get paymentNewIn => 'تحصيل';

  @override
  String get paymentNewOut => 'دفع';

  @override
  String get paymentFrom => 'دفعها';

  @override
  String get paymentTo => 'دُفعت إلى';

  @override
  String get paymentAmount => 'المبلغ';

  @override
  String get paymentMode => 'طريقة الدفع';

  @override
  String get paymentCashRegister => 'الصندوق';

  @override
  String get paymentNoCashRegister => 'خارج الصندوق';

  @override
  String get paymentNoOpenRegister =>
      'لا يوجد صندوق مفتوح: ستُسجَّل الدفعة خارج الصندوق.';

  @override
  String get paymentSettlesReceivables => 'تسدِّد المبالغ المستحقة';

  @override
  String get paymentSettlesPayables => 'تسدِّد الديون';

  @override
  String paymentRemainingOf(String amount) {
    return 'المتبقي $amount';
  }

  @override
  String paymentUnallocated(String amount) {
    return '$amount غير مخصَّص (دفعة مقدَّمة)';
  }

  @override
  String get paymentReference => 'المرجع';

  @override
  String get paymentReferenceHint => 'رقم المعاملة أو الشيك…';

  @override
  String get paymentNote => 'ملاحظة';

  @override
  String paymentConfirmIn(String amount) {
    return 'تحصيل $amount';
  }

  @override
  String paymentConfirmOut(String amount) {
    return 'دفع $amount';
  }

  @override
  String get paymentDetailTitle => 'دفعة';

  @override
  String get paymentDate => 'التاريخ';

  @override
  String get paymentCancelsPayment => 'تلغي الدفعة';

  @override
  String get paymentOpenOriginal => 'عرض الدفعة الأصلية';

  @override
  String get paymentCancelledBy => 'أُلغيت في';

  @override
  String get paymentCancel => 'إلغاء هذه الدفعة';

  @override
  String get paymentCancelHint =>
      'لا تُحذف الدفعة أبدًا: يُسجَّل إلغاؤها وتعود المبالغ مستحقة.';

  @override
  String get paymentCancelTitle => 'إلغاء هذه الدفعة؟';

  @override
  String paymentCancelMessage(String amount) {
    return 'ستُسجَّل دفعة عكسية بقيمة $amount، ويُعدَّل الصندوق إن كانت نقدًا.';
  }

  @override
  String get cashNew => 'صندوق جديد';

  @override
  String get cashEmptyAdmin =>
      'لا يوجد صندوق. أنشئ صندوقًا لكل محل أو وكالة تتعامل بالنقد.';

  @override
  String get cashEmpty => 'لا يوجد صندوق متاح.';

  @override
  String get cashOpenState => 'مفتوح';

  @override
  String get cashClosedState => 'مغلق';

  @override
  String cashOpenSince(String date) {
    return 'مفتوح منذ $date';
  }

  @override
  String get cashBalance => 'رصيد الصندوق';

  @override
  String cashOpeningBalance(String amount) {
    return 'رصيد الافتتاح: $amount';
  }

  @override
  String get cashOpen => 'فتح الصندوق';

  @override
  String get cashClose => 'إقفال الصندوق';

  @override
  String get cashMovements => 'الحركات';

  @override
  String get cashNoMovement => 'لا توجد حركات منذ الفتح.';

  @override
  String get cashHistory => 'الإقفالات السابقة';

  @override
  String get cashClosingPending => 'إقفال في انتظار الإرسال';

  @override
  String cashClosingSummary(String expected, String counted) {
    return 'المتوقع $expected · المعدود $counted';
  }

  @override
  String get cashNoGap => 'لا فرق';

  @override
  String get cashOpeningAmount => 'رصيد الافتتاح';

  @override
  String get cashMoveReason => 'السبب';

  @override
  String cashExpected(String amount) {
    return 'المبلغ المتوقع: $amount';
  }

  @override
  String get cashCounted => 'المبلغ المعدود';

  @override
  String cashGap(String amount) {
    return 'الفرق: $amount';
  }

  @override
  String get cashClosingNote => 'تعليق (اختياري)';

  @override
  String get cashName => 'اسم الصندوق';

  @override
  String cashDefaultName(String site) {
    return 'صندوق $site';
  }

  @override
  String get ruleLabelInvalid => 'أدخل الموضوع (200 حرف كحد أقصى).';

  @override
  String get ruleCommitmentCancelled => 'تم إلغاء هذا المبلغ المستحق.';

  @override
  String get ruleCommitmentPaid => 'توجد مدفوعات مسجلة: ألغِها أولًا.';

  @override
  String ruleTotalBelowPaid(String amount) {
    return 'لا يمكن أن يكون الإجمالي أقل من المسدَّد ($amount).';
  }

  @override
  String ruleAmountAboveRemaining(String amount) {
    return 'المبلغ يتجاوز المتبقي ($amount).';
  }

  @override
  String get ruleAllocationAbovePayment => 'التوزيع يتجاوز مبلغ الدفعة.';

  @override
  String get ruleAllocationWrongDirection =>
      'المبلغ الوارد يسدِّد مبلغًا للتحصيل فقط، والصادر مبلغًا للدفع فقط.';

  @override
  String get ruleAllocationOtherContact =>
      'هذا المبلغ المستحق يخص جهة اتصال أخرى.';

  @override
  String get rulePaymentAlreadyCancelled => 'هذه الدفعة ملغاة بالفعل.';

  @override
  String get ruleModeWithoutCash => 'النقد وحده يمر عبر الصندوق.';

  @override
  String get ruleDateInvalid => 'تاريخ الدفع غير صالح.';

  @override
  String get ruleCashClosed => 'الصندوق مغلق: افتحه أولًا.';

  @override
  String get ruleCashOpenSession => 'أقفل الصندوق أولًا.';

  @override
  String get ruleCashAlreadyOpen => 'هذا الصندوق مفتوح بالفعل.';

  @override
  String get ruleCashInactive => 'هذا الصندوق معطَّل.';

  @override
  String ruleCashInsufficient(String amount) {
    return 'النقد غير كافٍ في الصندوق (الرصيد: $amount).';
  }

  @override
  String get ruleFinanceInconsistent =>
      'العملية غير ممكنة: بيانات غير متسقة. حدِّث ثم أعد المحاولة.';

  @override
  String get financeExpensesMonth => 'مصاريف الشهر';

  @override
  String get debtOpenExpense => 'عرض المصروف';

  @override
  String get expenseCatRent => 'الإيجار';

  @override
  String get expenseCatEnergy => 'الكهرباء';

  @override
  String get expenseCatTransport => 'النقل';

  @override
  String get expenseCatSalaries => 'الرواتب';

  @override
  String get expenseCatSupplies => 'اللوازم';

  @override
  String get expenseCatCommunication => 'الاتصال والإعلان';

  @override
  String get expenseCatMaintenance => 'الصيانة';

  @override
  String get expenseCatTaxes => 'الضرائب والرسوم';

  @override
  String get expenseCatOther => 'أخرى';

  @override
  String get expenseNew => 'مصروف جديد';

  @override
  String get expenseSaved => 'تم تسجيل المصروف.';

  @override
  String get expenseCategories => 'الفئات';

  @override
  String get expensesEmpty => 'لا توجد مصاريف مسجلة.';

  @override
  String get expenseCancelled => 'ملغى';

  @override
  String get expenseToPay => 'للدفع';

  @override
  String get expenseDetailTitle => 'مصروف';

  @override
  String get expenseDate => 'تاريخ المصروف';

  @override
  String get expenseSettlement => 'التسديد';

  @override
  String expensePaidWith(String mode) {
    return 'مدفوع · $mode';
  }

  @override
  String expenseToPayRemaining(String amount) {
    return 'للدفع: $amount';
  }

  @override
  String get expenseSupplier => 'المورّد (اختياري)';

  @override
  String get expenseCancel => 'إلغاء المصروف';

  @override
  String get expenseEdit => 'تعديل المصروف';

  @override
  String get expenseLabel => 'الوصف';

  @override
  String get expenseLabelHint => 'مثال: سيارة أجرة للتوصيل';

  @override
  String get expenseCategory => 'الفئة';

  @override
  String get expenseAmountLocked =>
      'لا يمكن تعديل المبلغ: ألغِ المصروف ثم أعد إدخاله.';

  @override
  String get expenseCancelTitle => 'إلغاء هذا المصروف؟';

  @override
  String get expenseCancelMessagePaid =>
      'ستُلغى الدفعة (ويُعدَّل الصندوق إن كانت نقدًا)، ثم المصروف. لا يُحذف شيء من السجل.';

  @override
  String get expenseCancelMessage =>
      'سيُلغى المبلغ المستحق المرتبط. لا يُحذف شيء من السجل.';

  @override
  String get expenseCategoryNew => 'فئة جديدة';

  @override
  String get expenseCategoryName => 'اسم الفئة';

  @override
  String get expenseCategoriesHint =>
      'الفئة المعطَّلة لا تُقترح بعد الآن، وتحتفظ بها المصاريف المسجلة سابقًا.';

  @override
  String get expensePaidNow => 'مدفوع الآن';

  @override
  String get expensePayLater => 'للدفع لاحقًا';

  @override
  String get expenseReferenceHint => 'رقم الفاتورة أو الإيصال…';

  @override
  String get ruleCommitmentLinked =>
      'هذا المبلغ مرتبط بمصروف: عدِّل المصروف أو ألغِه.';

  @override
  String get ruleCategoryInvalid => 'اختر فئة مفعَّلة.';

  @override
  String get ruleExpensePaid => 'هذا المصروف مدفوع: ألغِ دفعته أولًا.';

  @override
  String get ruleExpenseCancelled => 'هذا المصروف ملغى.';

  @override
  String get moduleCommunDocuments => 'المستندات';

  @override
  String get docTypeReceipt => 'إيصال';

  @override
  String get docTypeInvoice => 'فاتورة';

  @override
  String get docTypeQuote => 'عرض سعر';

  @override
  String get docTypeCreditNote => 'إشعار دائن';

  @override
  String get docSearchHint => 'رقم المستند أو الاسم…';

  @override
  String get docEmpty =>
      'لا توجد مستندات صادرة. تُصدر الإيصالات من بطاقة الدفعة.';

  @override
  String get docIssueReceipt => 'إصدار الإيصال';

  @override
  String docOpenReceipt(String numero) {
    return 'عرض الإيصال $numero';
  }

  @override
  String get docReceiptTitle => 'إيصال';

  @override
  String get docDate => 'التاريخ';

  @override
  String get docReceivedFrom => 'استُلم من';

  @override
  String get docPaymentMode => 'طريقة الدفع';

  @override
  String get docReference => 'المرجع';

  @override
  String get docAmountReceived => 'المبلغ المستلم';

  @override
  String get docSettles => 'تسديد';

  @override
  String get docColumnLabel => 'الموضوع';

  @override
  String get docColumnAmount => 'المدفوع';

  @override
  String get docColumnRemaining => 'المتبقي';

  @override
  String docIssuedBy(String name) {
    return 'أصدره $name';
  }

  @override
  String get docGeneratedBy => 'مستند أُنشئ بواسطة DubaGest';

  @override
  String get docCancelledStamp => 'ملغى';

  @override
  String docPhone(String value) {
    return 'الهاتف: $value';
  }

  @override
  String docTaxId(String value) {
    return 'الرقم الضريبي: $value';
  }

  @override
  String docTradeRegister(String value) {
    return 'السجل التجاري: $value';
  }

  @override
  String get ruleDocumentExists => 'تم إصدار إيصال لهذه الدفعة مسبقًا.';

  @override
  String get ruleDocumentOriginInvalid =>
      'لا يُصدر الإيصال إلا لمبلغ وارد صالح.';

  @override
  String get ruleDocumentNumbersExhausted =>
      'لم يعد هناك رقم إيصال متاح على هذا الجهاز. اتصل بالإنترنت لحظة لحجز أرقام جديدة.';

  @override
  String get ruleDocumentNumberInvalid =>
      'رقم المستند غير صالح. حدِّث ثم أعد المحاولة.';

  @override
  String get moduleCommunAgenda => 'الأجندة';

  @override
  String get agendaTypeReminder => 'تذكير';

  @override
  String get agendaTypeMeeting => 'موعد';

  @override
  String get agendaTypeTask => 'مهمة';

  @override
  String get agendaTypeFollowUp => 'متابعة';

  @override
  String get agendaNew => 'عنصر جديد';

  @override
  String get agendaEdit => 'تعديل العنصر';

  @override
  String get agendaMine => 'مهامي';

  @override
  String get agendaEmpty => 'لا شيء مخطط. أضف تذكيرًا أو مهمة أو متابعة.';

  @override
  String get agendaOverdue => 'متأخر';

  @override
  String get agendaToday => 'اليوم';

  @override
  String get agendaNextDays => 'الأيام السبعة القادمة';

  @override
  String get agendaLater => 'لاحقًا';

  @override
  String agendaAssignedTo(String name) {
    return 'مُسند إلى $name';
  }

  @override
  String get agendaMarkDone => 'تحديد كمنجز';

  @override
  String get agendaReopen => 'إعادة إلى قيد التنفيذ';

  @override
  String get agendaCancel => 'إلغاء العنصر';

  @override
  String get agendaDueToReceive => 'استحقاق تحصيل';

  @override
  String get agendaDueToPay => 'استحقاق دفع';

  @override
  String agendaReminderBefore(String delay) {
    return 'تذكير قبل $delay';
  }

  @override
  String get agendaOpenDebt => 'عرض المبلغ المستحق';

  @override
  String get agendaStatusTodo => 'قيد التنفيذ';

  @override
  String get agendaStatusDone => 'منجز';

  @override
  String get agendaStatusCancelled => 'ملغى';

  @override
  String get agendaTitle => 'العنوان';

  @override
  String get agendaTitleHint => 'مثال: الاتصال بأمادو بشأن الرصيد';

  @override
  String get agendaWhen => 'التاريخ والوقت';

  @override
  String get agendaReminder => 'التذكير';

  @override
  String get agendaNoReminder => 'بدون تذكير';

  @override
  String get agendaAssignee => 'إسناد إلى';

  @override
  String get agendaNobody => 'لا أحد بعينه';

  @override
  String get agendaMe => 'أنا';

  @override
  String get agendaPlanFollowUp => 'تخطيط متابعة';

  @override
  String agendaFollowUpTitle(String name) {
    return 'متابعة $name';
  }

  @override
  String agendaDelayMinutes(int n) {
    return '$n دقيقة';
  }

  @override
  String agendaDelayHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ساعات',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String agendaDelayDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n أيام',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsMarkAllRead => 'تحديد الكل كمقروء';

  @override
  String get notificationsEmpty => 'لا شيء للإبلاغ عنه.';

  @override
  String get notificationsToHandle => 'للمعالجة';

  @override
  String get notificationsReceived => 'الرسائل';

  @override
  String get notifOverdue => 'متأخر';

  @override
  String get notifDueSoon => 'قريبًا';

  @override
  String notifDebtsOverdue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n مبالغ للتحصيل متأخرة',
      one: 'مبلغ واحد للتحصيل متأخر',
    );
    return '$_temp0';
  }

  @override
  String notifCashOpenLong(String name) {
    return '$name مفتوح منذ أكثر من 24 ساعة';
  }

  @override
  String notifRejected(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عمليات رفضها الخادم',
      one: 'عملية واحدة رفضها الخادم',
    );
    return '$_temp0';
  }

  @override
  String get notifRejectedHint => 'افتحها لقراءة السبب وإزالتها.';

  @override
  String notifAssigned(String name) {
    return 'أسند إليك $name مهمة';
  }

  @override
  String notifDone(String name) {
    return 'أنجز $name مهمة';
  }

  @override
  String get ruleAssigneeInvalid => 'هذا الشخص ليس عضوًا نشطًا في المؤسسة.';

  @override
  String get ruleTargetInvalid => 'البطاقة المرتبطة لم تعد موجودة.';

  @override
  String get dashboardTitle => 'لوحة القيادة';

  @override
  String get dashboard7Days => '7 أيام';

  @override
  String get dashboard30Days => '30 يومًا';

  @override
  String get dashboardMonth => 'هذا الشهر';

  @override
  String get dashboardEmpty => 'لا توجد عمليات في هذه الفترة لمساحة العمل هذه.';

  @override
  String get dashboardFlows => 'الوارد والصادر يوميًا';

  @override
  String get dashboardExpensesByCategory => 'المصاريف حسب الفئة';

  @override
  String get dashboardTopDebtors => 'الأكثر مديونية لكم';

  @override
  String get dashboardCollected => 'المحصَّل';

  @override
  String get dashboardPaidOut => 'المدفوع';

  @override
  String get dashboardNet => 'صافي الفترة';

  @override
  String get dashboardExpenses => 'المصاريف';

  @override
  String get dashboardOtherCategories => 'فئات أخرى';

  @override
  String get dashboardSeeAll => 'عرض الكل';

  @override
  String get searchHint => 'ابحث عن جهة اتصال أو إيصال أو دفعة…';

  @override
  String get searchIntro =>
      'الاسم، الهاتف، المبلغ، رقم الإيصال… يعمل البحث أيضًا دون اتصال.';

  @override
  String get searchNoResult => 'لا توجد نتائج.';

  @override
  String get searchDebts => 'المبالغ المستحقة';

  @override
  String get moduleCommunRapports => 'التقارير';

  @override
  String get reportCashJournal => 'دفتر الخزينة';

  @override
  String get reportCashJournalHint =>
      'جميع المبالغ الواردة والصادرة خلال الفترة.';

  @override
  String get reportExpenses => 'المصاريف حسب الفئة';

  @override
  String get reportExpensesHint => 'عدد مصاريف الفترة ومجموعها حسب الفئة.';

  @override
  String get reportAgedReceivables => 'أعمار الديون المستحقة';

  @override
  String get reportAgedReceivablesHint =>
      'ما زال كل عميل مدينًا به حسب مدة التأخر.';

  @override
  String get reportCashClosings => 'إقفالات الصندوق';

  @override
  String get reportCashClosingsHint =>
      'الرصيد المتوقع والمبلغ المعدود والفرق لكل إقفال.';

  @override
  String reportPeriod(String start, String end) {
    return 'من $start إلى $end';
  }

  @override
  String reportAtDate(String date) {
    return 'الوضع في $date';
  }

  @override
  String get reportTotal => 'المجموع';

  @override
  String reportNet(String amount) {
    return 'الصافي: $amount';
  }

  @override
  String get reportCount => 'العدد';

  @override
  String get reportNotDue => 'غير مستحق';

  @override
  String reportDaysRange(int a, int b) {
    return '$a–$b يومًا';
  }

  @override
  String reportDaysOver(int n) {
    return 'أكثر من $n يومًا';
  }

  @override
  String get reportClosedOn => 'أُقفل في';

  @override
  String get reportExpected => 'المتوقع';

  @override
  String get reportGap => 'الفرق';

  @override
  String get reportNone => 'لا يوجد تقرير متاح بصلاحياتك.';

  @override
  String get reportEmpty => 'لا توجد بيانات لهذه الفترة.';

  @override
  String get reportExportPdf => 'تصدير بصيغة PDF';

  @override
  String reportGeneratedOn(String date) {
    return 'صدر في $date — DubaGest';
  }

  @override
  String get notesTitle => 'الملاحظات والمرفقات';

  @override
  String get notesAddHint => 'أضف ملاحظة…';

  @override
  String get notesAdd => 'إضافة الملاحظة';

  @override
  String get attachmentsTitle => 'المرفقات';

  @override
  String get attachTakePhoto => 'التقاط صورة';

  @override
  String get attachChooseFile => 'إرفاق ملف';

  @override
  String get attachOnlineHint =>
      'صورة أو PDF، بحد أقصى 10 ميغابايت. يتطلب إرسال الملف اتصالًا.';

  @override
  String get attachFileTypes => 'صور وملفات PDF';

  @override
  String attachSizeKb(int n) {
    return '$n ك.ب';
  }

  @override
  String attachSizeMb(String value) {
    return '$value م.ب';
  }

  @override
  String get entrepriseLogoHint =>
      'يظهر الشعار في أعلى الإيصالات (PNG أو JPEG أو WEBP، بحد أقصى 2 ميغابايت).';

  @override
  String get entrepriseLogoChange => 'تغيير الشعار';

  @override
  String get entrepriseLogoSaved => 'تم حفظ الشعار.';

  @override
  String get entrepriseLogoTypes => 'الصور';

  @override
  String get ruleFileTypeInvalid =>
      'صيغة غير مقبولة: صورة (JPEG أو PNG أو WEBP) أو PDF فقط.';

  @override
  String ruleFileTooLarge(int max) {
    return 'الملف كبير جدًا ($max ميغابايت كحد أقصى).';
  }

  @override
  String get settingsCompanyProfile => 'بطاقة المؤسسة';

  @override
  String get settingsPayments => 'المدفوعات والإيصالات';

  @override
  String get settingsPaymentsHint => 'طرق الدفع المتاحة، ملاحظة الإيصالات';

  @override
  String get settingsExpenseCategories => 'فئات المصروفات';

  @override
  String get settingsPaymentModes => 'طرق الدفع المتاحة';

  @override
  String get settingsPaymentModesHint =>
      'تُعرض الطرق المفعّلة فقط عند التسجيل. لا تتغير المدفوعات المسجلة سابقًا.';

  @override
  String get settingsPaymentModeCash => 'يمر عبر الصندوق';

  @override
  String get settingsReceiptFooter => 'ملاحظة أسفل الإيصالات';

  @override
  String get settingsReceiptFooterHint => 'مثال: شكرًا لثقتكم.';

  @override
  String get settingsReceiptFooterNote =>
      'تُطبع على الإيصالات القادمة؛ لا تتغير الإيصالات الصادرة سابقًا.';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات.';

  @override
  String get rulePaymentModesInvalid =>
      'اختر طريقة دفع واحدة على الأقل من القائمة.';

  @override
  String get rulePaymentModeDisabled =>
      'لم تعد المؤسسة تقبل طريقة الدفع هذه. اختر طريقة أخرى.';

  @override
  String get comStatusInStock => 'متوفر';

  @override
  String get comStatusLow => 'مخزون منخفض';

  @override
  String get comStatusOut => 'نفد المخزون';

  @override
  String get comAllShops => 'كل المحلات';

  @override
  String get comChooseShop => 'اختر المحل';

  @override
  String get comShop => 'المحل';

  @override
  String get comShopRequired => 'اختر محلاً';

  @override
  String get comBefore => 'قبل';

  @override
  String get comAfter => 'بعد';

  @override
  String get comQuantity => 'الكمية';

  @override
  String get comQuantityInvalid => 'أدخل كمية صحيحة';

  @override
  String comFractionNotAllowed(String unite) {
    return 'هذا المنتج يُحسب بوحدات $unite كاملة';
  }

  @override
  String comFractionStep(String pas, String unite) {
    return 'بخطوات $pas $unite';
  }

  @override
  String get comScan => 'مسح رمز شريطي';

  @override
  String get comScanTitle => 'مسح';

  @override
  String get comTorch => 'المصباح';

  @override
  String get comScanUnavailable => 'الكاميرا غير متاحة. أدخل الرمز يدوياً.';

  @override
  String get comScanHint => 'ضع الرمز الشريطي داخل الإطار';

  @override
  String get comBarcodeUnknown => 'هذا الرمز غير مرتبط بأي منتج';

  @override
  String get comChooseProduct => 'اختر منتجاً';

  @override
  String get comSearchHint => 'الاسم أو المرجع أو الرمز…';

  @override
  String get comAllCategories => 'الكل';

  @override
  String get comNoProductFound => 'لم يُعثر على أي منتج';

  @override
  String get comNoProductFoundHint => 'جرّب كلمة أخرى أو أضف هذا المنتج.';

  @override
  String get comAddProduct => 'إضافة منتج';

  @override
  String get comUsualProducts => 'المنتجات المعتادة';

  @override
  String get comAllProducts => 'كل المنتجات';

  @override
  String get comProduct => 'المنتج';

  @override
  String get comFrom => 'من';

  @override
  String get comTo => 'إلى';

  @override
  String get comNewEntry => 'إدخال جديد';

  @override
  String get comSaveEntry => 'حفظ الإدخال';

  @override
  String get comNewExit => 'إخراج جديد';

  @override
  String get comConfirmExit => 'تأكيد الإخراج';

  @override
  String get comTransferStock => 'نقل المخزون';

  @override
  String get comConfirmTransfer => 'تأكيد النقل';

  @override
  String get comInventory => 'الجرد';

  @override
  String get comValidateInventory => 'اعتماد الجرد';

  @override
  String get comConfirmExitTitle => 'تأكيد الإخراج؟';

  @override
  String get comConfirmTransferTitle => 'تأكيد النقل؟';

  @override
  String get comConfirmInventoryTitle => 'اعتماد الجرد؟';

  @override
  String comCurrentStock(String quantite) {
    return 'المخزون الحالي: $quantite';
  }

  @override
  String get comHowMany => 'كم؟';

  @override
  String get comCountedQuantity => 'كم عددتَ؟';

  @override
  String get comWhy => 'لماذا هذا الفرق؟';

  @override
  String get comReason => 'السبب';

  @override
  String get comNoteOptional => 'ملاحظة (اختياري)';

  @override
  String get comAddNote => 'إضافة ملاحظة';

  @override
  String get comStockPreview => 'مخزونك';

  @override
  String comStockInsufficientInline(String disponible) {
    return 'المخزون غير كافٍ · المتوفر: $disponible';
  }

  @override
  String get comInventoryNoGap => 'لا فرق: المخزون صحيح';

  @override
  String comInventoryGap(String ecart) {
    return 'الفرق: $ecart';
  }

  @override
  String get comStockUpdated => 'تم تحديث المخزون';

  @override
  String comTransferDone(String quantite, String boutique) {
    return 'تم نقل $quantite إلى $boutique';
  }

  @override
  String get comReasonPurchase => 'شراء';

  @override
  String get comReasonReturn => 'إرجاع';

  @override
  String get comReasonAdjustment => 'تسوية';

  @override
  String get comReasonSale => 'بيع';

  @override
  String get comReasonLoss => 'فقدان';

  @override
  String get comReasonBreakage => 'كسر';

  @override
  String get comReasonTransfer => 'نقل';

  @override
  String get comReasonCountError => 'خطأ في العد';

  @override
  String get comReasonMissing => 'منتج مفقود';

  @override
  String get comReasonOther => 'أخرى';

  @override
  String ruleStockInsufficient(String disponible) {
    return 'المخزون غير كافٍ: المتبقي $disponible.';
  }

  @override
  String get ruleQuantityInvalid => 'يجب أن تكون الكمية أكبر من صفر.';

  @override
  String ruleFractionInvalid(String pas, String unite) {
    return 'كمية غير صالحة: يُباع هذا المنتج بـ $pas $unite.';
  }

  @override
  String get ruleUnitInvalid =>
      'تحقق من الوحدات: لكل وحدة اسم مختلف وتحتوي على وحدة أساسية واحدة على الأقل.';

  @override
  String get ruleBarcodeExists => 'هذا الرمز الشريطي مستخدم لمنتج آخر.';

  @override
  String get ruleTransferSameShop => 'اختر محلين مختلفين.';

  @override
  String get ruleShopRequired => 'اختر المحل.';

  @override
  String get ruleLinesInvalid => 'أضف منتجاً واحداً على الأقل مع كمية.';

  @override
  String ruleReceptionAbove(String reste) {
    return 'لا يمكن استلام أكثر مما طُلب (المتبقي: $reste).';
  }

  @override
  String get rulePurchaseReceived =>
      'تم استلام هذا الشراء: لا يمكن تعديله أو إلغاؤه.';

  @override
  String get rulePurchasePaid => 'تم دفع هذا الشراء: ألغِ الدفع أولاً.';

  @override
  String get rulePurchaseCancelled => 'هذا الشراء ملغى.';

  @override
  String get ruleSaleCancelled => 'هذا البيع ملغى مسبقاً.';

  @override
  String get ruleSalePaid => 'تم تحصيل هذا البيع: ألغِ الدفع في المالية أولاً.';

  @override
  String get ruleCustomerRequired => 'للبيع بالآجل، اختر الزبون.';

  @override
  String get comProductsTitle => 'المنتجات';

  @override
  String get comCategories => 'الفئات';

  @override
  String get comManageCategories => 'إدارة الفئات';

  @override
  String get comGridView => 'عرض شبكي';

  @override
  String get comListView => 'عرض قائمة';

  @override
  String get comEmptyProductsTitle => 'لا توجد منتجات';

  @override
  String get comEmptyProductsMessage =>
      'أضف منتجاتك لتبدأ إدارة مخزونك ومبيعاتك.';

  @override
  String comProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجاً',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا منتجات',
    );
    return '$_temp0';
  }

  @override
  String comNoProductInCategory(String categorie) {
    return 'لا منتجات في $categorie';
  }

  @override
  String get comAddProductHere => 'إضافة منتج هنا';

  @override
  String get comSeeProduct => 'عرض';

  @override
  String get comAddToStock => '+ مخزون';

  @override
  String get comSell => 'بيع';

  @override
  String get comCreateProduct => 'إنشاء المنتج';

  @override
  String get comBarcodeUnknownHint => 'هل تريد إنشاء منتج بهذا الرمز؟';

  @override
  String get comArchived => 'مؤرشف';

  @override
  String get comShowArchived => 'المنتجات المؤرشفة';

  @override
  String get comSortBy => 'ترتيب';

  @override
  String get comSortName => 'الاسم';

  @override
  String get comSortStock => 'أقل مخزون';

  @override
  String get comSortPrice => 'السعر';

  @override
  String get comSortBestSellers => 'الأكثر مبيعاً';

  @override
  String get comNewProduct => 'منتج جديد';

  @override
  String get comEditProduct => 'تعديل المنتج';

  @override
  String get comStepIdentity => 'المنتج';

  @override
  String get comStepUnits => 'الوحدات والأسعار';

  @override
  String get comStepStock => 'المخزون';

  @override
  String get comStepOptions => 'خيارات أخرى';

  @override
  String comStepOf(int etape, int total) {
    return 'الخطوة $etape من $total';
  }

  @override
  String get comNext => 'التالي';

  @override
  String get comPrevious => 'السابق';

  @override
  String get comSaveProduct => 'حفظ المنتج';

  @override
  String get comProductSaved => 'تم حفظ المنتج';

  @override
  String get comAddPhoto => 'إضافة صورة';

  @override
  String get comTakePhoto => 'التقاط صورة';

  @override
  String get comChooseFromGallery => 'اختيار من المعرض';

  @override
  String get comPhotoHint => 'تساعد الصورة البائعين على التعرف على المنتج.';

  @override
  String get comMainPhoto => 'الصورة الرئيسية';

  @override
  String get comSetMainPhoto => 'جعلها الرئيسية';

  @override
  String get comRemovePhoto => 'إزالة الصورة';

  @override
  String get comProductName => 'اسم المنتج';

  @override
  String get comProductNameHint => 'مثال: بلاط 40×40';

  @override
  String get comNameRequired => 'أعطِ المنتج اسماً';

  @override
  String get comCategory => 'الفئة';

  @override
  String get comSubCategory => 'فئة فرعية';

  @override
  String get comNoCategory => 'بدون فئة';

  @override
  String get comNewCategory => 'فئة جديدة';

  @override
  String get comNewSubCategory => 'فئة فرعية جديدة';

  @override
  String get comCategoryName => 'اسم الفئة';

  @override
  String get comReference => 'المرجع (اختياري)';

  @override
  String get comBarcode => 'الرمز الشريطي (اختياري)';

  @override
  String get comCountedIn => 'أحسب هذا المنتج بـ…';

  @override
  String get comOtherUnit => 'أخرى…';

  @override
  String get comUnitName => 'اسم الوحدة';

  @override
  String get comUnitNameHint => 'مثال: حزمة، دلو، برميل';

  @override
  String get comSalePrice => 'سعر البيع';

  @override
  String comSalePricePer(String unite) {
    return 'سعر البيع لكل $unite';
  }

  @override
  String comWholesalePricePer(String unite) {
    return 'سعر الجملة لكل $unite';
  }

  @override
  String comPurchasePricePer(String unite) {
    return 'سعر الشراء لكل $unite (اختياري)';
  }

  @override
  String get comSellWholesale => 'أبيع أيضاً بالجملة';

  @override
  String get comRetail => 'تجزئة';

  @override
  String get comWholesale => 'جملة';

  @override
  String get comPurchase => 'شراء';

  @override
  String get comPackagings => 'العبوات';

  @override
  String get comPackagingsHint =>
      'هل تشتري أو تبيع بالكرتونة أو العلبة أو الكيس؟ أضفها وسيقوم التطبيق بالحساب.';

  @override
  String get comAddPackaging => 'إضافة عبوة';

  @override
  String get comCopyUnits => 'نسخ من منتج آخر';

  @override
  String comOneUnitContains(String unite) {
    return '1 $unite يحتوي على';
  }

  @override
  String get comContains => 'يحتوي على';

  @override
  String comFactorRequired(String unite) {
    return 'كم $unite؟';
  }

  @override
  String get comCalculated => 'محسوب';

  @override
  String get comPriceSetByYou => 'سعر حددته أنت';

  @override
  String comDiscountOf(String pourcent) {
    return 'خصم $pourcent٪';
  }

  @override
  String comMarkupOf(String pourcent) {
    return 'أغلى من التجزئة بـ $pourcent٪';
  }

  @override
  String get comPriceHigherWarning =>
      'انتبه: هذه العبوة أغلى من بيع الوحدات منفردة.';

  @override
  String get comBackToCalculated => 'العودة إلى السعر المحسوب';

  @override
  String comProfitPer(String montant, String unite) {
    return 'الربح: $montant لكل $unite';
  }

  @override
  String get comUnitsSummary => 'ملخص';

  @override
  String get comInitialStock => 'المخزون الابتدائي';

  @override
  String get comInitialStockHint => 'كم لديك اليوم؟ (اختياري)';

  @override
  String get comInitialStockNote => 'المخزون الابتدائي';

  @override
  String get comAlertThreshold => 'نبّهني عندما يتبقى أقل من…';

  @override
  String get comAlertThresholdHint => 'سيظهر المنتج كـ «مخزون منخفض».';

  @override
  String get comSellFractions => 'البيع بالتجزئة إلى أجزاء';

  @override
  String get comSellFractionsHint => 'مثال: ½ علبة، 2.5 متر، 0.25 كغ';

  @override
  String get comMinimumStep => 'أصغر كمية تُباع';

  @override
  String get comCharacteristics => 'الخصائص';

  @override
  String get comAddCharacteristic => 'إضافة خاصية';

  @override
  String get comCharacteristicName => 'الاسم (مثال: الضمان)';

  @override
  String get comMainSupplier => 'المورد الرئيسي';

  @override
  String get comChooseSupplier => 'اختر مورداً';

  @override
  String get comDescription => 'الوصف (اختياري)';

  @override
  String get comNone => 'لا شيء';

  @override
  String get comAttrMarque => 'العلامة';

  @override
  String get comAttrModele => 'الطراز';

  @override
  String get comAttrCouleur => 'اللون';

  @override
  String get comAttrDimensions => 'الأبعاد';

  @override
  String get comAttrFinition => 'التشطيب';

  @override
  String get comAttrVolume => 'الحجم';

  @override
  String get comAttrType => 'النوع';

  @override
  String get comAttrSection => 'المقطع';

  @override
  String get comAttrLongueur => 'الطول';

  @override
  String get comAttrTaille => 'المقاس';

  @override
  String get comAttrPoids => 'الوزن';

  @override
  String get comAttrEmplacement => 'مكان التخزين';

  @override
  String get comUnitPiece => 'قطعة';

  @override
  String get comUnitCarton => 'كرتونة';

  @override
  String get comUnitPaquet => 'علبة';

  @override
  String get comUnitSac => 'كيس';

  @override
  String get comUnitBidon => 'جالون';

  @override
  String get comUnitBouteille => 'قارورة';

  @override
  String get comUnitSachet => 'ظرف';

  @override
  String get comUnitBoite => 'صندوق';

  @override
  String get comUnitRouleau => 'لفة';

  @override
  String get comUnitMetre => 'متر';

  @override
  String get comUnitKg => 'كغ';

  @override
  String get comUnitLitre => 'لتر';

  @override
  String get comUnitDouzaine => 'دزينة';

  @override
  String get comUnitLot => 'مجموعة';

  @override
  String get comUnitPalette => 'منصة';

  @override
  String get comUnitTonne => 'طن';

  @override
  String get comProductNotFound => 'هذا المنتج لم يعد موجوداً.';

  @override
  String get comChooseCustomer => 'اختر زبوناً';

  @override
  String get comNewSupplier => 'مورد جديد';

  @override
  String get comNewCustomer => 'زبون جديد';

  @override
  String get comSearchContact => 'الاسم أو الهاتف…';

  @override
  String get comNoContact => 'لم يُعثر على أي جهة اتصال';

  @override
  String get comStockCard => 'المخزون';

  @override
  String get comDistribution => 'التوزيع';

  @override
  String get comEntry => 'إدخال';

  @override
  String get comExit => 'إخراج';

  @override
  String get comTransfer => 'نقل';

  @override
  String get comBuy => 'شراء';

  @override
  String get comPricesAndUnits => 'الأسعار والوحدات';

  @override
  String get comUnit => 'الوحدة';

  @override
  String get comProfit => 'الربح';

  @override
  String get comLastMovements => 'آخر الحركات';

  @override
  String get comSeeAll => 'عرض الكل';

  @override
  String get comNoMovement => 'لا توجد حركات بعد';

  @override
  String get comSuppliers => 'الموردون';

  @override
  String get comArchive => 'أرشفة';

  @override
  String get comRestore => 'إعادة التفعيل';

  @override
  String get comArchiveConfirm =>
      'أرشفة هذا المنتج؟ لن يُعرض للبيع أو الشراء. يُحفظ سجله.';

  @override
  String get comBarcodeShort => 'الرمز الشريطي';

  @override
  String get comReferenceShort => 'المرجع';

  @override
  String comMinimumAlert(String quantite) {
    return 'تنبيه تحت $quantite';
  }

  @override
  String get comToCheck => 'مخزون يجب التحقق منه';

  @override
  String get comPendingSend => 'في انتظار الإرسال';

  @override
  String get comCategoriesTitle => 'الفئات';

  @override
  String get comCategoriesEmptyTitle => 'نظّم منتجاتك';

  @override
  String get comCategoriesEmptyMessage =>
      'اختر نموذجاً يناسب تجارتك أو أنشئ فئاتك الخاصة.';

  @override
  String get comUseTemplate => 'استخدام نموذج';

  @override
  String get comChooseSector => 'ما نوع تجارتك؟';

  @override
  String get comTemplateApplied => 'تم إنشاء الفئات';

  @override
  String get comAddSubCategory => 'إضافة فئة فرعية';

  @override
  String get comDisable => 'إخفاء';

  @override
  String get comEnable => 'إظهار';

  @override
  String get comSectorHardware => 'محل أدوات';

  @override
  String get comSectorGrocery => 'دكان / مواد غذائية';

  @override
  String get comSectorSupermarket => 'سوبرماركت';

  @override
  String get comSectorTextile => 'ملابس وأحذية';

  @override
  String get comSectorCosmetics => 'مستحضرات التجميل';

  @override
  String get comSectorElectronics => 'هواتف وإلكترونيات';

  @override
  String get comCatOutils => 'أدوات';

  @override
  String get comCatMateriaux => 'مواد البناء';

  @override
  String get comCatPeinture => 'دهانات';

  @override
  String get comCatPeintureInterieur => 'داخلي';

  @override
  String get comCatPeintureExterieur => 'خارجي';

  @override
  String get comCatPeinturePrimaire => 'أساس';

  @override
  String get comCatPeintureVernis => 'ورنيش';

  @override
  String get comCatPlomberie => 'سباكة';

  @override
  String get comCatElectricite => 'كهرباء';

  @override
  String get comCatVisserie => 'براغي ومسامير';

  @override
  String get comCatMenuiserie => 'نجارة';

  @override
  String get comCatAccessoires => 'إكسسوارات';

  @override
  String get comCatCarrelage => 'بلاط';

  @override
  String get comCatBoissons => 'مشروبات';

  @override
  String get comCatEpicerie => 'بقالة';

  @override
  String get comCatFrais => 'منتجات طازجة';

  @override
  String get comCatBoulangerie => 'مخبوزات';

  @override
  String get comCatHygiene => 'النظافة الشخصية';

  @override
  String get comCatMenage => 'تنظيف المنزل';

  @override
  String get comCatCosmetique => 'تجميل';

  @override
  String get comCatVetements => 'ملابس';

  @override
  String get comCatChaussures => 'أحذية';

  @override
  String get comCatTelephonie => 'هواتف';

  @override
  String get comCatElectronique => 'إلكترونيات';

  @override
  String get comCatPapeterie => 'قرطاسية';

  @override
  String get comMovementsTitle => 'الحركات';

  @override
  String get comFamilyAll => 'الكل';

  @override
  String get comFamilyEntries => 'الإدخالات';

  @override
  String get comFamilyExits => 'الإخراجات';

  @override
  String get comFamilyTransfers => 'التحويلات';

  @override
  String get comFamilyAdjustments => 'التسويات';

  @override
  String get comFamilyLosses => 'الخسائر';

  @override
  String get comToday => 'اليوم';

  @override
  String get comYesterday => 'أمس';

  @override
  String comBy(String nom) {
    return 'بواسطة $nom';
  }

  @override
  String get comTypeEntry => 'إدخال';

  @override
  String get comTypeExit => 'إخراج';

  @override
  String get comTypeTransferOut => 'نقل صادر';

  @override
  String get comTypeTransferIn => 'نقل وارد';

  @override
  String get comTypeInventory => 'جرد';

  @override
  String get comMovementRejected => 'رفضه الخادم';

  @override
  String get comEmptyMovementsTitle => 'لا توجد حركات';

  @override
  String get comEmptyMovementsMessage =>
      'ستظهر هنا الإدخالات والإخراجات والتحويلات.';

  @override
  String get comRemoveRejected => 'إزالة';

  @override
  String get comPeriodAll => 'كل التواريخ';

  @override
  String get comPeriodToday => 'اليوم';

  @override
  String get comPeriodWeek => 'آخر 7 أيام';

  @override
  String get comPeriodMonth => 'آخر 30 يوماً';

  @override
  String get comStockTitle => 'المخزون';

  @override
  String get comStockSubtitle => 'تابع منتجاتك وكمياتها وحركاتها.';

  @override
  String get comKpiProducts => 'المنتجات';

  @override
  String get comKpiLow => 'مخزون منخفض';

  @override
  String get comKpiOut => 'نفاد';

  @override
  String get comKpiMovesToday => 'حركات اليوم';

  @override
  String get comOrder => 'اطلب';

  @override
  String get comStockEmptyTitle => 'مخزونك لا يزال فارغاً';

  @override
  String get comStockEmptyMessage => 'ابدأ بإضافة منتجك الأول.';

  @override
  String get comNothingToReport => 'لا شيء يستدعي الانتباه: كل شيء متوفر.';

  @override
  String get comToWatch => 'للمتابعة';

  @override
  String get comSeeMovements => 'عرض الحركات';

  @override
  String get comStockActions => 'ماذا تريد أن تفعل؟';

  @override
  String comWatchLow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج مخزونها منخفض',
      many: '$count منتجاً مخزونها منخفض',
      few: '$count منتجات مخزونها منخفض',
      two: 'منتجان مخزونهما منخفض',
      one: 'منتج واحد مخزونه منخفض',
    );
    return '$_temp0';
  }

  @override
  String comWatchOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج نفد',
      many: '$count منتجاً نفد',
      few: '$count منتجات نفدت',
      two: 'منتجان نفدا',
      one: 'منتج واحد نفد',
    );
    return '$_temp0';
  }

  @override
  String get comPurchasesTitle => 'المشتريات';

  @override
  String get comNewPurchase => 'شراء جديد';

  @override
  String get comEditPurchase => 'تعديل الشراء';

  @override
  String get comPurchaseEmptyTitle => 'لا توجد مشتريات';

  @override
  String get comPurchaseEmptyMessage =>
      'سجّل مشترياتك من الموردين: يزيد المخزون عند الاستلام.';

  @override
  String get comFilterToReceive => 'للاستلام';

  @override
  String get comFilterReceived => 'مستلمة';

  @override
  String get comFilterCancelled => 'ملغاة';

  @override
  String get comStatusOrdered => 'مطلوب';

  @override
  String get comStatusPartlyReceived => 'مستلم جزئياً';

  @override
  String get comStatusReceived => 'مستلم';

  @override
  String get comStatusCancelled => 'ملغى';

  @override
  String get comSupplier => 'المورد';

  @override
  String get comNoSupplierChosen => 'اختر المورد (اختياري)';

  @override
  String get comPurchaseDate => 'التاريخ';

  @override
  String get comSupplierReference => 'رقم الفاتورة / الوصل (اختياري)';

  @override
  String get comProducts => 'المنتجات';

  @override
  String get comAddLine => 'إضافة منتج';

  @override
  String comUnitPrice(String unite) {
    return 'السعر لكل $unite';
  }

  @override
  String comLastPrice(String montant) {
    return 'آخر سعر: $montant';
  }

  @override
  String get comTotal => 'المجموع';

  @override
  String get comSave => 'حفظ';

  @override
  String get comSaveAndReceive => 'حفظ واستلام';

  @override
  String get comPurchaseSaved => 'تم حفظ الشراء';

  @override
  String get comReceive => 'استلام';

  @override
  String get comReceiveTitle => 'استلام البضاعة';

  @override
  String get comReceivedToday => 'المستلم اليوم';

  @override
  String get comOrdered => 'المطلوب';

  @override
  String get comAlreadyReceived => 'المستلم سابقاً';

  @override
  String get comRemaining => 'المتبقي';

  @override
  String get comReceiveAll => 'تم استلام الكل';

  @override
  String get comNothingReceived => 'لا شيء';

  @override
  String get comConfirmReception => 'تأكيد الاستلام';

  @override
  String get comReceptionDone => 'تم استلام البضاعة: تحديث المخزون';

  @override
  String get comStockImpact => 'الأثر على المخزون';

  @override
  String get comReceptions => 'الاستلامات';

  @override
  String get comCancelPurchase => 'إلغاء الشراء';

  @override
  String get comCancelPurchaseConfirm =>
      'إلغاء هذا الشراء؟ سيُلغى الدين للمورد.';

  @override
  String get comDebt => 'المتبقي للدفع';

  @override
  String get comPaid => 'مدفوع';

  @override
  String get comPaySupplier => 'الدفع للمورد';

  @override
  String get comFullyPaid => 'مدفوع بالكامل';

  @override
  String comLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجاً',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
    );
    return '$_temp0';
  }

  @override
  String comPurchaseOf(String date) {
    return 'شراء بتاريخ $date';
  }

  @override
  String get comNoSupplier => 'بدون مورد';

  @override
  String get comEditLine => 'تعديل السطر';

  @override
  String get comRemoveLine => 'إزالة';

  @override
  String get comApply => 'تأكيد';

  @override
  String get comSuppliersTitle => 'الموردون';

  @override
  String get comSuppliersEmptyTitle => 'لا يوجد موردون';

  @override
  String get comSuppliersEmptyMessage =>
      'أضف الأشخاص أو الشركات التي تشتري منها.';

  @override
  String get comAddSupplier => 'إضافة مورد';

  @override
  String get comTotalBought => 'مجموع المشتريات';

  @override
  String get comLastPurchase => 'آخر شراء';

  @override
  String get comSuppliedProducts => 'المنتجات المورَّدة';

  @override
  String get comPurchaseHistory => 'سجل المشتريات';

  @override
  String get comCall => 'اتصال';

  @override
  String get comOpenContact => 'بطاقة الاتصال';

  @override
  String get comNeverBought => 'لا مشتريات بعد';

  @override
  String comPurchasesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شراء',
      many: '$count شراءً',
      few: '$count مشتريات',
      two: 'شراءان',
      one: 'شراء واحد',
      zero: 'لا مشتريات',
    );
    return '$_temp0';
  }

  @override
  String get comSalesTitle => 'بيع';

  @override
  String get comSalesHistory => 'المبيعات';

  @override
  String get comCart => 'السلة';

  @override
  String get comCartEmpty => 'المس منتجاً لإضافته إلى السلة.';

  @override
  String comCartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفاً',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
    );
    return '$_temp0';
  }

  @override
  String get comCheckout => 'تحصيل';

  @override
  String get comBestSellers => 'الأكثر مبيعاً';

  @override
  String get comPayment => 'الدفع';

  @override
  String get comPayNow => 'مدفوع الآن';

  @override
  String get comOnCredit => 'بالآجل';

  @override
  String get comCustomer => 'الزبون';

  @override
  String get comCustomerOptional => 'الزبون (اختياري)';

  @override
  String get comDiscount => 'خصم';

  @override
  String get comToPay => 'للدفع';

  @override
  String comSaleDone(String montant) {
    return 'تم تسجيل البيع: $montant';
  }

  @override
  String get comConfirmSale => 'تأكيد البيع';

  @override
  String get comCashOpen => 'يدخل المال إلى الصندوق المفتوح.';

  @override
  String get comNoCashOpen => 'لا يوجد صندوق مفتوح: يُسجَّل الدفع دون صندوق.';

  @override
  String comAvailable(String quantite) {
    return 'المتوفر: $quantite';
  }

  @override
  String get comSalesEmptyTitle => 'لا توجد مبيعات';

  @override
  String get comSalesEmptyMessage => 'ستظهر مبيعاتك هنا.';

  @override
  String comSaleOf(String date) {
    return 'بيع بتاريخ $date';
  }

  @override
  String get comCancelSale => 'إلغاء البيع';

  @override
  String get comCancelSaleConfirm =>
      'إلغاء هذا البيع؟ تعود المنتجات إلى المخزون.';

  @override
  String get comCancelReason => 'السبب (اختياري)';

  @override
  String get comSaleCancelledDone => 'تم إلغاء البيع';

  @override
  String get comCancelled => 'ملغاة';

  @override
  String get comSalesToday => 'مبيعات اليوم';

  @override
  String get comNoShopAllowed => 'ليس لديك محل للبيع.';

  @override
  String get comClearCart => 'إفراغ السلة';

  @override
  String get comChangeUnit => 'الكمية والوحدة';

  @override
  String get comPrice => 'السعر';

  @override
  String get comSeller => 'البائع';

  @override
  String get comNewSale => 'بيع جديد';

  @override
  String get comStepProductUnits => 'المنتج والوحدات';

  @override
  String get comStepPricesStock => 'الأسعار والمخزون';

  @override
  String get comProductInfo => 'المنتج';

  @override
  String get comProductInfoHint =>
      'تساعد الصورة والاسم الواضح البائعين على التعرف عليه.';

  @override
  String get comPhotoShort => 'صورة';

  @override
  String get comHowCounted => 'كيف تحسب هذا المنتج؟';

  @override
  String get comHowCountedHint => 'اختر أصغر كمية تبيعها: قطعة، كيس، لتر…';

  @override
  String get comPackagingTitle => 'هل تبيع أيضاً بالكرتونة أو العلبة أو الكيس؟';

  @override
  String get comPackagingHint2 =>
      'أضف العبوة وما تحتويه: تُحسب الأسعار والمخزون تلقائياً.';

  @override
  String get comPackagingName => 'اسم العبوة';

  @override
  String comPackagingContains(String unite) {
    return 'عدد $unite في عبوة واحدة';
  }

  @override
  String get comRetailPrice => 'سعر البيع بالتجزئة';

  @override
  String get comRetailPriceHint => 'السعر المعتاد للزبون. اختر وحدة هذا السعر.';

  @override
  String get comWholesalePrice => 'سعر البيع بالجملة';

  @override
  String get comWholesalePriceHint => 'السعر لمشتري الجملة، غالباً بالكرتونة.';

  @override
  String get comPurchasePrice => 'سعر الشراء (اختياري)';

  @override
  String get comPurchasePriceHint => 'ما تدفعه للمورد: لمعرفة ربحك.';

  @override
  String get comPricePer => 'السعر لـ 1:';

  @override
  String comEquivalentPrice(String montant, String unite) {
    return 'أي $montant لكل $unite';
  }

  @override
  String get comPriceSummary => 'أسعارك محسوبة لكل وحدة';

  @override
  String get comAmountHint => 'المبلغ';

  @override
  String get comSaveChanges => 'حفظ التعديلات';

  @override
  String get comStockAndAlert => 'المخزون والتنبيه';

  @override
  String get comSupplierNone => 'لم يتم اختيار مورد';

  @override
  String get comReferenceHint => 'مثال: CAR-0012';

  @override
  String get comGenerateReference => 'اقتراح مرجع';

  @override
  String get comChooseCategory => 'اختر فئة';

  @override
  String get comBarcodeLabel => 'الرمز الشريطي';

  @override
  String get comBarcodeHint => 'امسح الرمز أو اكتبه (اختياري)';

  @override
  String get comUnitPieceHelp => 'مثال: بلاطة، مصباح';

  @override
  String get rcpTitle => 'الإيصالات';

  @override
  String get rcpSaleReceipt => 'إيصال بيع';

  @override
  String get rcpNumberPending => 'يُمنح الرقم عند المزامنة';

  @override
  String get rcpSaleSaved => 'تم تسجيل البيع';

  @override
  String get rcpView => 'عرض الإيصال';

  @override
  String get rcpShare => 'مشاركة';

  @override
  String get rcpPrint => 'طباعة';

  @override
  String get rcpPdf => 'PDF';

  @override
  String get rcpNewSale => 'بيع جديد';

  @override
  String get rcpCounterCustomer => 'زبون عابر';

  @override
  String get rcpSelectCustomer => 'اختيار';

  @override
  String get rcpAddName => 'إضافة اسم';

  @override
  String get rcpCustomerName => 'اسم الزبون';

  @override
  String get rcpPhoneOptional => 'الهاتف (اختياري)';

  @override
  String get rcpCreditNeedsCustomer => 'بيع بالدين: اختر الزبون أو أضفه.';

  @override
  String get rcpDeposit => 'المدفوع الآن (اختياري)';

  @override
  String get rcpDepositHint => 'اتركه فارغًا إذا لم يدفع الزبون شيئًا اليوم.';

  @override
  String get rcpSubtotal => 'المجموع الفرعي';

  @override
  String get rcpPaid => 'المبلغ المدفوع';

  @override
  String get rcpRemaining => 'المتبقي';

  @override
  String get rcpRemainingToPay => 'المتبقي للدفع';

  @override
  String get rcpShop => 'المتجر';

  @override
  String get rcpDate => 'التاريخ';

  @override
  String get rcpTime => 'الساعة';

  @override
  String get rcpThanks => 'شكرًا لثقتكم.';

  @override
  String get rcpTagline => 'إدارة بسيطة لنشاطك';

  @override
  String get rcpProduct => 'المنتج';

  @override
  String get rcpQty => 'الكمية';

  @override
  String get rcpPrice => 'السعر';

  @override
  String get rcpLineTotal => 'المجموع';

  @override
  String get rcpStatus => 'الحالة';

  @override
  String get rcpStatusValid => 'صالح';

  @override
  String get rcpStatusCancelled => 'ملغى';

  @override
  String get rcpStatusCredit => 'بالدين';

  @override
  String get rcpStatusPartial => 'مدفوع جزئيًا';

  @override
  String get rcpCancelledStamp => 'ملغى';

  @override
  String rcpCancelledInfo(String date, String nom) {
    return 'أُلغي في $date بواسطة $nom';
  }

  @override
  String get rcpEmptyTitle => 'لا توجد إيصالات بعد';

  @override
  String get rcpEmptyMessage => 'ستظهر إيصالاتك هنا بعد أول مبيعاتك.';

  @override
  String get rcpCreateSale => 'إنشاء بيع';

  @override
  String get rcpNoResultTitle => 'لم يتم العثور على إيصال';

  @override
  String get rcpNoResultMessage => 'جرّب رقمًا أو زبونًا أو تاريخًا آخر.';

  @override
  String get rcpSearchHint => 'رقم الإيصال، الزبون، الهاتف، المنتج…';

  @override
  String get rcpPeriodToday => 'اليوم';

  @override
  String get rcpPeriodYesterday => 'أمس';

  @override
  String get rcpPeriodWeek => 'هذا الأسبوع';

  @override
  String get rcpPeriodMonth => 'هذا الشهر';

  @override
  String get rcpPeriodCustom => 'فترة…';

  @override
  String get rcpPeriodAll => 'الكل';

  @override
  String get rcpAllSellers => 'كل البائعين';

  @override
  String get rcpAllPayments => 'كل طرق الدفع';

  @override
  String get rcpAllStatuses => 'كل الحالات';

  @override
  String get rcpCredit => 'دين';

  @override
  String get rcpSales => 'المبيعات';

  @override
  String get rcpShops => 'المتاجر';

  @override
  String get rcpLatest => 'آخر المبيعات';

  @override
  String get rcpSeeAll => 'عرض كل الإيصالات';

  @override
  String get rcpFilters => 'عوامل التصفية';

  @override
  String get rcpReset => 'مسح عوامل التصفية';

  @override
  String get rcpTraceability => 'السجل';

  @override
  String rcpCreatedBy(String nom) {
    return 'سجّل البيع $nom';
  }

  @override
  String get rcpOnDevice => 'محفوظ على الجهاز، في انتظار الإرسال';

  @override
  String rcpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إيصالات',
      one: 'إيصال واحد',
      zero: 'لا إيصالات',
    );
    return '$_temp0';
  }

  @override
  String get expenseCatFuel => 'الوقود';

  @override
  String get expenseCatWater => 'الماء';

  @override
  String get expenseCatInternet => 'الهاتف والإنترنت';

  @override
  String get expenseCatRepair => 'الإصلاحات';

  @override
  String get expenseCatCleaning => 'التنظيف';

  @override
  String get expenseCatSecurity => 'الحراسة';

  @override
  String get expenseCatDelivery => 'التوصيل';

  @override
  String get expenseCatBankFees => 'الرسوم البنكية';

  @override
  String get expenseCatInsurance => 'التأمين';

  @override
  String get cashNatureContribution => 'مساهمة المالك';

  @override
  String get cashNatureWithdrawal => 'سحب';

  @override
  String get cashNatureTransfer => 'تحويل';

  @override
  String get cashNatureRefund => 'استرداد';

  @override
  String get cashNatureAdjustment => 'تسوية';

  @override
  String get cashNatureOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get cashNatureOther => 'أخرى';

  @override
  String get cashGapReasonChange => 'خطأ في رد الباقي';

  @override
  String get cashGapReasonUnrecorded => 'مصروف غير مسجل';

  @override
  String get cashGapReasonCounting => 'خطأ في العد';

  @override
  String get cashGapReasonOther => 'أخرى';

  @override
  String cashGapJustify(String amount) {
    return 'تم تسجيل فرق قدره $amount. يرجى توضيح السبب.';
  }

  @override
  String get cashGapNoteRequired => 'التبرير (إلزامي)';

  @override
  String get cashOperationReason => 'السبب';

  @override
  String get cashTransferTitle => 'تحويل';

  @override
  String get cashTransferFrom => 'من';

  @override
  String get cashTransferTo => 'إلى';

  @override
  String get cashTransferSame => 'يجب أن يختلف المصدر عن الوجهة.';

  @override
  String get cashTransferDone => 'تم تسجيل التحويل';

  @override
  String get cashTransferCancel => 'إلغاء التحويل';

  @override
  String get cashCompanyLevel => 'المؤسسة (بدون متجر)';

  @override
  String get cashIn => 'دخول أموال';

  @override
  String get cashOut => 'خروج أموال';

  @override
  String get cashSite => 'المتجر / الموقع';

  @override
  String get cashScreenSubtitle => 'تابع مداخيلك ومصاريفك ورصيدك.';

  @override
  String get cashAllShops => 'كل المتاجر';

  @override
  String get cashAvailable => 'الرصيد المتاح';

  @override
  String get cashShowAmounts => 'إظهار المبالغ';

  @override
  String get cashHideAmounts => 'إخفاء المبالغ';

  @override
  String get cashCashOnHand => 'النقد في الصندوق';

  @override
  String get cashIncoming => 'المداخيل';

  @override
  String get cashOutgoing => 'المخارج';

  @override
  String get cashNet => 'التغير';

  @override
  String cashOperationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملية',
      many: '$count عملية',
      few: '$count عمليات',
      two: 'عمليتان',
      one: 'عملية واحدة',
      zero: 'لا توجد عمليات',
    );
    return '$_temp0';
  }

  @override
  String get cashAddOperation => 'إضافة عملية';

  @override
  String get cashBalanceTrend => 'تطور الرصيد';

  @override
  String get cashInBreakdown => 'من أين يأتي المال';

  @override
  String get cashOutBreakdown => 'إلى أين يذهب المال';

  @override
  String get cashByMode => 'وسائل الدفع';

  @override
  String get cashComparison => 'مقارنة';

  @override
  String get cashPreviousPeriod => 'الفترة السابقة';

  @override
  String get cashByShop => 'حسب المتجر';

  @override
  String get cashOperationsHistory => 'العمليات';

  @override
  String get cashSearchHint => 'ابحث عن عملية…';

  @override
  String get cashFilterAll => 'الكل';

  @override
  String get cashReadyTitle => 'صندوقك جاهز';

  @override
  String get cashReadyMessage =>
      'ستظهر المبيعات والمدفوعات والمصاريف هنا تلقائيًا.';

  @override
  String get cashNoDataPeriod => 'لا توجد بيانات لهذه الفترة.';

  @override
  String get cashBalanced => 'متوازن';

  @override
  String get cashGapLarge => 'فرق كبير';

  @override
  String get periodToday => 'اليوم';

  @override
  String get periodYesterday => 'أمس';

  @override
  String get periodThisWeek => 'هذا الأسبوع';

  @override
  String get periodThisMonth => 'هذا الشهر';

  @override
  String get periodThisYear => 'هذه السنة';

  @override
  String get periodAll => 'الكل';

  @override
  String get periodCustom => 'مخصص';

  @override
  String get period7Days => '7 أيام';

  @override
  String get period30Days => '30 يومًا';

  @override
  String get period3Months => '3 أشهر';

  @override
  String get cashSrcSale => 'بيع';

  @override
  String get cashSrcCustomerPayment => 'دفعة عميل';

  @override
  String get cashSrcService => 'خدمة';

  @override
  String get cashSrcRent => 'إيجار';

  @override
  String get cashSrcPurchase => 'شراء';

  @override
  String get cashSrcSupplierPayment => 'دفعة مورد';

  @override
  String get cashSrcExpense => 'مصروف';

  @override
  String cashAlertGap(String amount, String register) {
    return 'فرق قدره $amount في آخر إغلاق لـ $register.';
  }

  @override
  String cashAlertOutflowsUp(int percent) {
    return 'ارتفعت المخارج بنسبة $percent٪ مقارنة بالأسبوع الماضي.';
  }

  @override
  String get cashDetailDate => 'التاريخ والوقت';

  @override
  String get cashDetailSource => 'المصدر';

  @override
  String get cashDetailReference => 'المرجع';

  @override
  String get cashDetailContact => 'العميل / المورد';

  @override
  String get cashDetailOpen => 'عرض التفاصيل';

  @override
  String get cashCancelOperation => 'إلغاء العملية';

  @override
  String get cashCancelReason => 'سبب الإلغاء';

  @override
  String get cashPending => 'في انتظار الإرسال';

  @override
  String get financeManage => 'إدارة أموالك';

  @override
  String get periodDay => 'يوم';

  @override
  String get periodMonth => 'شهر';

  @override
  String get periodYear => 'سنة';

  @override
  String get periodDates => 'تواريخ';

  @override
  String get periodPrevious => 'السابق';

  @override
  String get periodNext => 'التالي';

  @override
  String get periodChooseDates => 'اختر التواريخ';

  @override
  String get expenseTotalPeriod => 'مجموع الفترة';

  @override
  String expensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مصروف',
      many: '$count مصروفًا',
      few: '$count مصاريف',
      two: 'مصروفان',
      one: 'مصروف واحد',
      zero: 'لا توجد مصاريف',
    );
    return '$_temp0';
  }

  @override
  String get servicesTitle => 'الخدمات والتدخلات';

  @override
  String get servicesSubtitle => 'إدارة بسيطة لخدماتك وعروض الأسعار';

  @override
  String get prestationsTitle => 'الخدمات';

  @override
  String get planningServicesTitle => 'جدول التدخلات';

  @override
  String get catalogueServicesTitle => 'دليل الخدمات';

  @override
  String get devisServicesTitle => 'عروض أسعار الخدمات';

  @override
  String get statutAFaire => 'قيد الانتظار';

  @override
  String get statutPlanifiee => 'مجدولة';

  @override
  String get statutEnCours => 'قيد التنفيذ';

  @override
  String get statutTerminee => 'مكتملة';

  @override
  String get statutLivree => 'تم التسليم';

  @override
  String get statutAnnulee => 'ملغاة';

  @override
  String get prioriteFaible => 'منخفضة / قادمة';

  @override
  String get prioriteAttentionJ2 => 'تنبيه (يومان)';

  @override
  String get prioriteUrgentJ1 => 'عاجل (يوم واحد)';

  @override
  String get prioriteAujourdhui => 'مستحقة اليوم';

  @override
  String get prioriteEnRetard => 'متأخرة';

  @override
  String get nouvellePrestation => 'خدمة جديدة';

  @override
  String get nouveauDevisService => 'عرض سعر جديد';

  @override
  String get nouveauServiceCatalogue => 'خدمة جديدة في الدليل';

  @override
  String get convertirDevisEnPrestation => 'تحويل إلى خدمة';

  @override
  String get demarrerTravail => 'بدء العمل';

  @override
  String get terminerTravail => 'إتمام العمل';

  @override
  String get livrerPrestation => 'تسليم للعميل';

  @override
  String get reporterEcheance => 'تأجيل الموعد';

  @override
  String get motifReport => 'سبب التأجيل';

  @override
  String get uniteForfait => 'جزافي';

  @override
  String get uniteHeure => 'بالساعة';

  @override
  String get uniteJour => 'باليوم';

  @override
  String get uniteM2 => 'بالمتر المربع';

  @override
  String get uniteKm => 'بالكيلومتر';

  @override
  String get unitePiece => 'بالقطعة';

  @override
  String get statutDevisBrouillon => 'مسودة';

  @override
  String get statutDevisEmis => 'صادر';

  @override
  String get statutDevisAccepte => 'مقبول';

  @override
  String get statutDevisRefuse => 'مرفوض';

  @override
  String get statutDevisConverti => 'تم التحويل إلى خدمة';

  @override
  String get rapportsServicesTitle => 'تقارير وربحية الخدمات';

  @override
  String get performanceFinanciere => 'الأداء المالي';

  @override
  String get totalFacture => 'إجمالي الفواتير';

  @override
  String get totalEncaisse => 'إجمالي المحصل';

  @override
  String get aRecouvrer => 'المتبقي للتحصيل';

  @override
  String get tauxRecouvrement => 'نسبة التحصيل';

  @override
  String get ventilationMainOeuvrePieces => 'توزيع القيمة المفوترة';

  @override
  String get mainOeuvre => 'اليد العاملة / الخدمات';

  @override
  String get piecesStock => 'قطع المخزون';

  @override
  String get transformationDevis => 'تحويل عروض الأسعار';

  @override
  String get bonPriseEnCharge => 'إيصال الاستلام';

  @override
  String get rappelClient => 'تذكير العميل';

  @override
  String get envoyerWhatsApp => 'إرسال عبر واتساب';
}
