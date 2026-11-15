/// Énumérations métier du module Microfinance (`commerce.microfinance`).
library;

enum MethodeCalculInteret {
  pourcentageFixe('POURCENTAGE_FIXE'),
  montantFixe('MONTANT_FIXE'),
  degressif('DEGRESSIF');

  const MethodeCalculInteret(this.code);
  final String code;

  static MethodeCalculInteret parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => MethodeCalculInteret.pourcentageFixe);

  String libelle(String locale) => switch (this) {
        pourcentageFixe => locale == 'ar'
            ? 'نسبة مئوية ثابتة'
            : (locale == 'en' ? 'Fixed percentage' : 'Pourcentage fixe'),
        montantFixe => locale == 'ar'
            ? 'مبلغ فائدة ثابت'
            : (locale == 'en' ? 'Fixed interest amount' : 'Montant d\'intérêt fixe'),
        degressif => locale == 'ar'
            ? 'فائدة متناقصة على المتبقي'
            : (locale == 'en' ? 'Declining balance interest' : 'Intérêt dégressif'),
      };
}

enum FrequenceRemboursement {
  quotidienne('QUOTIDIENNE'),
  hebdomadaire('HEBDOMADAIRE'),
  mensuelle('MENSUELLE');

  const FrequenceRemboursement(this.code);
  final String code;

  static FrequenceRemboursement parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => FrequenceRemboursement.mensuelle);

  String libelle(String locale) => switch (this) {
        quotidienne => locale == 'ar' ? 'يومي' : (locale == 'en' ? 'Daily' : 'Quotidienne'),
        hebdomadaire => locale == 'ar' ? 'أسبوعي' : (locale == 'en' ? 'Weekly' : 'Hebdomadaire'),
        mensuelle => locale == 'ar' ? 'شهري' : (locale == 'en' ? 'Monthly' : 'Mensuelle'),
      };
}

enum StatutPret {
  brouillon('BROUILLON'),
  enCours('EN_COURS'),
  partiellementRembourse('PARTIELLEMENT_REMBOURSE'),
  solde('SOLDE'),
  enRetard('EN_RETARD'),
  contentieux('CONTENTIEUX'),
  annule('ANNULE');

  const StatutPret(this.code);
  final String code;

  static StatutPret parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => StatutPret.enCours);

  bool get estActifOuOuvert =>
      this == enCours || this == partiellementRembourse || this == enRetard || this == contentieux;

  String libelle(String locale) => switch (this) {
        brouillon => locale == 'ar' ? 'مسودة' : (locale == 'en' ? 'Draft' : 'Brouillon'),
        enCours => locale == 'ar' ? 'قيد السداد' : (locale == 'en' ? 'Active' : 'En cours'),
        partiellementRembourse => locale == 'ar'
            ? 'مسدد جزئياً'
            : (locale == 'en' ? 'Partially repaid' : 'Partiellement remboursé'),
        solde => locale == 'ar' ? 'مسدد بالكامل' : (locale == 'en' ? 'Settled' : 'Soldé'),
        enRetard => locale == 'ar' ? 'متأخر' : (locale == 'en' ? 'Overdue' : 'En retard'),
        contentieux => locale == 'ar' ? 'متعثر / نزاع' : (locale == 'en' ? 'Defaulted / Dispute' : 'Contentieux'),
        annule => locale == 'ar' ? 'ملغى' : (locale == 'en' ? 'Cancelled' : 'Annulé'),
      };
}

enum StatutEcheance {
  aVenir('A_VENIR'),
  aujourdHui('AUJOURD_HUI'),
  partiel('PARTIEL'),
  paye('PAYE'),
  enRetard('EN_RETARD'),
  annule('ANNULE');

  const StatutEcheance(this.code);
  final String code;

  static StatutEcheance parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => StatutEcheance.aVenir);

  String libelle(String locale) => switch (this) {
        aVenir => locale == 'ar' ? 'قادم' : (locale == 'en' ? 'Upcoming' : 'À venir'),
        aujourdHui => locale == 'ar' ? 'اليوم' : (locale == 'en' ? 'Today' : 'Aujourd\'hui'),
        partiel => locale == 'ar' ? 'جزئي' : (locale == 'en' ? 'Partial' : 'Partiel'),
        paye => locale == 'ar' ? 'مدفوع' : (locale == 'en' ? 'Paid' : 'Payé'),
        enRetard => locale == 'ar' ? 'متأخر' : (locale == 'en' ? 'Overdue' : 'En retard'),
        annule => locale == 'ar' ? 'ملغى' : (locale == 'en' ? 'Cancelled' : 'Annulé'),
      };
}

enum TypeRemboursement {
  complet('COMPLET'),
  partiel('PARTIEL'),
  anticipe('ANTICIPE'),
  exceptionnel('EXCEPTIONNEL'),
  multiEcheances('MULTI_ECHEANCES');

  const TypeRemboursement(this.code);
  final String code;

  static TypeRemboursement parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => TypeRemboursement.complet);

  String libelle(String locale) => switch (this) {
        complet => locale == 'ar' ? 'سداد كامل' : (locale == 'en' ? 'Full installment' : 'Remboursement complet'),
        partiel => locale == 'ar' ? 'سداد جزئي' : (locale == 'en' ? 'Partial payment' : 'Paiement partiel'),
        anticipe => locale == 'ar' ? 'سداد مبكر' : (locale == 'en' ? 'Early payoff' : 'Remboursement anticipé'),
        exceptionnel => locale == 'ar' ? 'سداد استثنائي' : (locale == 'en' ? 'Exceptional repayment' : 'Remboursement exceptionnel'),
        multiEcheances => locale == 'ar' ? 'أقساط متعددة' : (locale == 'en' ? 'Multi-installments' : 'Multi-échéances'),
      };
}

enum TypeCompteMicrofinance {
  caissePhysique('CAISSE_PHYSIQUE'),
  banque('BANQUE'),
  orangeMoney('ORANGE_MONEY'),
  mobileMoney('MOBILE_MONEY'),
  autre('AUTRE');

  const TypeCompteMicrofinance(this.code);
  final String code;

  static TypeCompteMicrofinance parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => TypeCompteMicrofinance.caissePhysique);

  String libelle(String locale) => switch (this) {
        caissePhysique => locale == 'ar' ? 'صندوق نقدي' : (locale == 'en' ? 'Physical cashbox' : 'Caisse physique'),
        banque => locale == 'ar' ? 'حساب بنكي' : (locale == 'en' ? 'Bank account' : 'Compte bancaire'),
        orangeMoney => 'Orange Money',
        mobileMoney => 'Mobile Money',
        autre => locale == 'ar' ? 'آخر' : (locale == 'en' ? 'Other' : 'Autre compte'),
      };
}

enum SourceFondsMicrofinance {
  capitalPersonnel('CAPITAL_PERSONNEL'),
  apportAssocies('APPORT_ASSOCIES'),
  autreFinancement('AUTRE_FINANCEMENT');

  const SourceFondsMicrofinance(this.code);
  final String code;

  static SourceFondsMicrofinance parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => SourceFondsMicrofinance.capitalPersonnel);

  String libelle(String locale) => switch (this) {
        capitalPersonnel => locale == 'ar' ? 'رأس المال الشخصي' : (locale == 'en' ? 'Personal capital' : 'Capital personnel'),
        apportAssocies => locale == 'ar' ? 'مساهمات الشركاء' : (locale == 'en' ? 'Partner contributions' : 'Apports associés'),
        autreFinancement => locale == 'ar' ? 'تمويل آخر' : (locale == 'en' ? 'Other financing' : 'Autres financements'),
      };
}

enum TypeMouvementFonds {
  apportInitial('APPORT_INITIAL'),
  apportSupplementaire('APPORT_SUPPLEMENTAIRE'),
  retraitCapital('RETRAIT_CAPITAL'),
  depenseFonctionnement('DEPENSE_FONCTIONNEMENT'),
  transfertInterne('TRANSFERT_INTERNE');

  const TypeMouvementFonds(this.code);
  final String code;

  static TypeMouvementFonds parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => TypeMouvementFonds.apportSupplementaire);

  String libelle(String locale) => switch (this) {
        apportInitial => locale == 'ar' ? 'رأس المال المبدئي' : (locale == 'en' ? 'Initial capital' : 'Capital initial'),
        apportSupplementaire => locale == 'ar' ? 'إضافة رأس مال' : (locale == 'en' ? 'Additional capital' : 'Apport supplémentaire'),
        retraitCapital => locale == 'ar' ? 'سحب رأس مال' : (locale == 'en' ? 'Capital withdrawal' : 'Retrait de capital'),
        depenseFonctionnement => locale == 'ar' ? 'مصروف تشغيلي' : (locale == 'en' ? 'Operating expense' : 'Dépense de fonctionnement'),
        transfertInterne => locale == 'ar' ? 'تحويل داخلي' : (locale == 'en' ? 'Internal transfer' : 'Transfert entre comptes'),
      };
}

enum TypeTransactionMicrofinance {
  apportCapital('APPORT_CAPITAL'),
  decaissementPret('DECAISSEMENT_PRET'),
  remboursementCapital('REMBOURSEMENT_CAPITAL'),
  encaissementInteret('ENCAISSEMENT_INTERET'),
  depenseFonctionnement('DEPENSE_FONCTIONNEMENT'),
  retraitCapital('RETRAIT_CAPITAL'),
  transfertSortant('TRANSFERT_SORTANT'),
  transfertEntrant('TRANSFERT_ENTRANT'),
  remboursementExceptionnel('REMBOURSEMENT_EXCEPTIONNEL'),
  annulationCorrection('ANNULATION_CORRECTION');

  const TypeTransactionMicrofinance(this.code);
  final String code;

  static TypeTransactionMicrofinance parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => TypeTransactionMicrofinance.apportCapital);

  String libelle(String locale) => switch (this) {
        apportCapital => locale == 'ar' ? 'إيداع رأس مال' : (locale == 'en' ? 'Capital contribution' : 'Apport de capital'),
        decaissementPret => locale == 'ar' ? 'صرف قرض' : (locale == 'en' ? 'Loan disbursement' : 'Décaissement de prêt'),
        remboursementCapital => locale == 'ar' ? 'استرداد رأس المال' : (locale == 'en' ? 'Principal repayment' : 'Remboursement capital'),
        encaissementInteret => locale == 'ar' ? 'تحصيل الفوائد' : (locale == 'en' ? 'Interest collected' : 'Encaissement intérêts'),
        depenseFonctionnement => locale == 'ar' ? 'مصروفات تشغيلية' : (locale == 'en' ? 'Operating expense' : 'Dépense fonctionnement'),
        retraitCapital => locale == 'ar' ? 'سحب رأس المال' : (locale == 'en' ? 'Capital withdrawal' : 'Retrait de capital'),
        transfertSortant => locale == 'ar' ? 'تحويل صادر' : (locale == 'en' ? 'Outgoing transfer' : 'Transfert sortant'),
        transfertEntrant => locale == 'ar' ? 'تحويل وارد' : (locale == 'en' ? 'Incoming transfer' : 'Transfert entrant'),
        remboursementExceptionnel => locale == 'ar' ? 'سداد استثنائي' : (locale == 'en' ? 'Exceptional repayment' : 'Remboursement exceptionnel'),
        annulationCorrection => locale == 'ar' ? 'إلغاء وتصحيح' : (locale == 'en' ? 'Reversal / Correction' : 'Annulation / Correction'),
      };
}

enum ModePaiementMicrofinance {
  especes('ESPECES'),
  mobileMoney('MOBILE_MONEY'),
  orangeMoney('ORANGE_MONEY'),
  virement('VIREMENT'),
  cheque('CHEQUE'),
  carte('CARTE'),
  autre('AUTRE');

  const ModePaiementMicrofinance(this.code);
  final String code;

  static ModePaiementMicrofinance parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => ModePaiementMicrofinance.especes);

  String libelle(String locale) => switch (this) {
        especes => locale == 'ar' ? 'نقداً' : (locale == 'en' ? 'Cash' : 'Espèces'),
        mobileMoney => 'Mobile Money',
        orangeMoney => 'Orange Money',
        virement => locale == 'ar' ? 'تحويل بنكي' : (locale == 'en' ? 'Bank transfer' : 'Virement bancaire'),
        cheque => locale == 'ar' ? 'شيك' : (locale == 'en' ? 'Cheque' : 'Chèque'),
        carte => locale == 'ar' ? 'بطاقة بنكية' : (locale == 'en' ? 'Card' : 'Carte bancaire'),
        autre => locale == 'ar' ? 'آخر' : (locale == 'en' ? 'Other' : 'Autre'),
      };
}

enum SensTransactionMicrofinance {
  entree('ENTREE'),
  sortie('SORTIE'),
  neutre('NEUTRE');

  const SensTransactionMicrofinance(this.code);
  final String code;

  static SensTransactionMicrofinance parse(String? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => SensTransactionMicrofinance.neutre);
}

enum PeriodeMicrofinance {
  tout,
  jour,
  semaine,
  mois,
  annee,
  personnalise;

  String libelle(String locale) => switch (this) {
        tout => locale == 'ar' ? 'الكل' : (locale == 'en' ? 'All time' : 'Tout'),
        jour => locale == 'ar' ? 'اليوم' : (locale == 'en' ? 'Today' : 'Jour'),
        semaine => locale == 'ar' ? 'الأسبوع' : (locale == 'en' ? 'Week' : 'Semaine'),
        mois => locale == 'ar' ? 'الشهر' : (locale == 'en' ? 'Month' : 'Mois'),
        annee => locale == 'ar' ? 'السنة' : (locale == 'en' ? 'Year' : 'Année'),
        personnalise => locale == 'ar' ? 'مخصص' : (locale == 'en' ? 'Custom' : 'Personnalisé'),
      };
}

