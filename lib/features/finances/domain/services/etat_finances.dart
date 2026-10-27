import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';
import '../entities/finances.dart';

/// Photographie locale des données financières visibles par l'utilisateur,
/// et tous les chiffres qui en découlent. Aucun chiffre n'est stocké en
/// double : tout est recalculé à partir des engagements, paiements et
/// mouvements, en tenant compte de ce qui n'est pas encore synchronisé.
class EtatFinances {
  EtatFinances({
    this.engagements = const [],
    this.paiements = const [],
    this.caisses = const [],
    this.sessions = const [],
    this.mouvements = const [],
    this.categories = const [],
    this.depenses = const [],
    this.courantes = const [],
    this.transferts = const [],
  }) {
    for (final p in paiements) {
      _paiements[p.id] = p;
      if (p.estAnnulation && !p.refuse) _annulationsLocales.add(p.annulePaiementId!);
    }
  }

  final List<Engagement> engagements;
  final List<Paiement> paiements;
  final List<Caisse> caisses;
  final List<SessionCaisse> sessions;
  final List<MouvementCaisse> mouvements;
  final List<CategorieDepense> categories;
  final List<Depense> depenses;
  final List<DepenseCourante> courantes;
  final List<TransfertTresorerie> transferts;

  TransfertTresorerie? transfert(String id) => transferts.where((t) => t.id == id).firstOrNull;

  CategorieDepense? categorie(String id) => categories.where((c) => c.id == id).firstOrNull;
  DepenseCourante? courante(String id) => courantes.where((c) => c.id == id).firstOrNull;

  /// Données de l'espace de travail : une activité, ou un site. Les
  /// écritures sans site ni activité (niveau entreprise) ne figurent que
  /// dans la vue globale.
  EtatFinances restreint({
    ActiviteCode? activite,
    String? perimetreId,
    Map<String, ActiviteCode> activiteDesSites = const {},
  }) {
    if (activite == null && perimetreId == null) return this;
    bool garde(ActiviteCode? a, String? site) =>
        perimetreId != null ? site == perimetreId : (a ?? activiteDesSites[site]) == activite;
    final caissesGardees = [
      for (final c in caisses)
        if (garde(activiteDesSites[c.perimetreId], c.perimetreId)) c,
    ];
    final idsCaisses = {for (final c in caissesGardees) c.id};
    return EtatFinances(
      engagements: [
        for (final e in engagements)
          if (garde(e.activite, e.perimetreId)) e,
      ],
      paiements: [
        for (final p in paiements)
          if (garde(p.activite, p.perimetreId)) p,
      ],
      caisses: caissesGardees,
      sessions: [
        for (final s in sessions)
          if (idsCaisses.contains(s.caisseId)) s,
      ],
      mouvements: [
        for (final m in mouvements)
          if (idsCaisses.contains(m.caisseId)) m,
      ],
      categories: categories,
      depenses: [
        for (final d in depenses)
          if (garde(d.activite, d.perimetreId)) d,
      ],
      courantes: [
        for (final c in courantes)
          if (garde(c.activite, c.perimetreId)) c,
      ],
      // Visible depuis l'une ou l'autre boutique (comme sur le serveur).
      transferts: [
        for (final t in transferts)
          if (garde(activiteDesSites[t.perimetreSourceId], t.perimetreSourceId) ||
              garde(activiteDesSites[t.perimetreDestId], t.perimetreDestId))
            t,
      ],
    );
  }

  /// Dépense comptée : ni annulée, ni refusée.
  bool depenseComptee(Depense d) => !d.annulee && !d.refusee;

  /// Dépense comptée qui a payé cette échéance, s'il y en a une.
  Depense? paiementEcheance(String couranteId, DateTime echeance) => depenses
      .where((d) => d.couranteId == couranteId && d.echeancePrevue == echeance && depenseComptee(d))
      .firstOrNull;

  /// État de la prochaine échéance d'une dépense courante active.
  EtatEcheance etatEcheance(DepenseCourante c, DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final e = c.prochaineEcheance;
    if (paiementEcheance(c.id, e) != null) return EtatEcheance.payee;
    if (e.isBefore(jour)) return EtatEcheance.enRetard;
    return e == jour ? EtatEcheance.aujourdhui : EtatEcheance.aVenir;
  }

  /// Échéances non payées des dépenses courantes actives jusqu'au [fin]
  /// inclus (retards compris), triées par date : « À prévoir ».
  List<({DepenseCourante courante, DateTime echeance})> aPrevoir(DateTime fin) => [
    for (final c in courantes.where((c) => c.estActive && c.syncStatus != RecordSyncStatus.syncError))
      for (final e in c.echeancesJusqua(fin))
        if (paiementEcheance(c.id, e) == null) (courante: c, echeance: e),
  ]..sort((a, b) => a.echeance.compareTo(b.echeance));

  /// Montant prévu des échéances non payées jusqu'au [fin] inclus. Une
  /// prévision, jamais additionnée aux dépenses réellement payées.
  int montantAPrevoir(DateTime fin) => aPrevoir(fin).fold(0, (t, x) => t + x.courante.montantPrevu);

  final _paiements = <String, Paiement>{};
  final _annulationsLocales = <String>{};

  Paiement? paiement(String id) => _paiements[id];

  /// Annulé côté serveur, ou par une annulation de l'appareil non refusée.
  bool estAnnule(Paiement p) => p.annuleServeur || _annulationsLocales.contains(p.id);

  /// Paiement compté dans les totaux : ni refusé, ni annulé, ni annulation.
  bool compte(Paiement p) => !p.refuse && !p.estAnnulation && !estAnnule(p);

  /// Réglé effectif = réglé serveur
  ///   + affectations des paiements de l'appareil pas encore envoyés
  ///   − affectations des paiements déjà comptés par le serveur mais annulés
  ///     depuis l'appareil (annulation pas encore envoyée).
  int regle(Engagement e) {
    var total = e.montantRegle;
    for (final p in paiements) {
      if (p.refuse || p.estAnnulation) continue;
      final part = p.affectations.where((a) => a.engagementId == e.id).fold(0, (s, a) => s + a.montant);
      if (part == 0) continue;
      final annuleLocalement = _annulationsLocales.contains(p.id) && !p.annuleServeur;
      if (p.enAttente && !annuleLocalement) total += part;
      if (!p.enAttente && annuleLocalement) total -= part;
    }
    return total.clamp(0, e.montantTotal);
  }

  EngagementSuivi suivi(Engagement e) => EngagementSuivi(e, regle: regle(e));

  List<EngagementSuivi> get suivis => [for (final e in engagements) suivi(e)];

  List<PaiementSuivi> get paiementsSuivis => [for (final p in paiements) PaiementSuivi(p, annule: estAnnule(p))];

  /// Mouvement compté : manuel non refusé, ou issu d'un paiement non refusé.
  bool mouvementValide(MouvementCaisse m) {
    if (m.syncStatus == RecordSyncStatus.syncError) return false;
    final p = m.paiementId == null ? null : _paiements[m.paiementId];
    return p == null || !p.refuse;
  }

  SessionCaisse? sessionOuverte(String caisseId) => sessions
      .where((s) => s.caisseId == caisseId && s.ouverte && s.syncStatus != RecordSyncStatus.syncError)
      .firstOrNull;

  int solde(SessionCaisse s) =>
      s.soldeInitial +
      mouvements.where((m) => m.sessionId == s.id && mouvementValide(m)).fold(0, (t, m) => t + m.signe);

  CaisseSuivi caisseSuivi(Caisse c) {
    final ouverte = sessionOuverte(c.id);
    final derniere =
        ouverte ??
        (sessions.where((s) => s.caisseId == c.id).toList()..sort((a, b) => b.ouverteLe.compareTo(a.ouverteLe)))
            .firstOrNull;
    final soldeEffectif = ouverte != null
        ? solde(ouverte)
        : (derniere != null ? (derniere.soldeReel ?? solde(derniere)) : 0);
    return CaisseSuivi(
      caisse: c,
      session: derniere,
      solde: soldeEffectif,
      mouvements: derniere == null
          ? const []
          : (mouvements.where((m) => m.sessionId == derniere.id).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
    );
  }

  List<CaisseSuivi> get caissesSuivies => [for (final c in caisses) caisseSuivi(c)];

  ResumeFinances resume(DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    var aRecevoir = 0, aPayer = 0, enRetard = 0, encaisse = 0, decaisse = 0;
    for (final s in suivis) {
      if (s.engagement.refuse) continue;
      if (s.engagement.sens == SensEngagement.aRecevoir) {
        aRecevoir += s.reste;
        if (s.etat(maintenant) == EtatReglement.enRetard) enRetard += s.reste;
      } else {
        aPayer += s.reste;
      }
    }
    for (final p in paiements) {
      if (!compte(p)) continue;
      final d = p.datePaiement.toLocal();
      if (DateTime(d.year, d.month, d.day) != jour) continue;
      p.sens == SensPaiement.entree ? encaisse += p.montant : decaisse += p.montant;
    }
    final enCaisse = caisses.fold<int>(0, (total, c) {
      final ouverte = sessionOuverte(c.id);
      if (ouverte != null) return total + solde(ouverte);
      final derniere = (sessions.where((s) => s.caisseId == c.id).toList()
        ..sort((a, b) => b.ouverteLe.compareTo(a.ouverteLe))).firstOrNull;
      if (derniere != null) return total + (derniere.soldeReel ?? solde(derniere));
      return total;
    });
    final depensesDuMois = depenses
        .where((d) => depenseComptee(d) && d.dateDepense.toLocal().year == jour.year && d.dateDepense.toLocal().month == jour.month)
        .fold(0, (t, d) => t + d.montant);
    return ResumeFinances(
      depensesDuMois: depensesDuMois,
      aRecevoir: aRecevoir,
      aPayer: aPayer,
      enRetard: enRetard,
      encaisseAujourdhui: encaisse,
      decaisseAujourdhui: decaisse,
      enCaisse: enCaisse,
    );
  }
}
