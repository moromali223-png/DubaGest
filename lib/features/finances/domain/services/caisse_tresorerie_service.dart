import '../entities/caisse_tresorerie_models.dart';
import '../entities/finances.dart';
import 'etat_finances.dart';

/// Chiffres de la Caisse, calculés à partir des paiements, sessions et
/// mouvements réels (rien n'est stocké en double, rien n'est inventé).
///
/// Deux règles :
///   • un SOLDE compte tout ce qui a bougé, transferts compris (l'argent a
///     changé de boutique ou de moyen) ;
///   • les ENTRÉES / SORTIES ne comptent que l'argent réellement gagné ou
///     dépensé : un transfert n'est ni une entrée ni une sortie.
class CaisseTresorerieService {
  const CaisseTresorerieService();

  // ---------------------------------------------------------------------------
  // Origine
  // ---------------------------------------------------------------------------

  /// Origine d'un paiement, tirée des données : sa nature, ou la somme due
  /// qu'il règle (vente, achat, dépense, loyer…). Un règlement le jour même
  /// de la vente est la vente ; plus tard, c'est un paiement de dette client.
  OrigineMouvement origine(EtatFinances etat, Paiement p, {Map<String, Engagement>? engagements}) {
    if (p.estTransfert) return OrigineMouvement.transfert;
    switch (p.nature) {
      case NaturePaiement.apport:
        return OrigineMouvement.apport;
      case NaturePaiement.retrait:
        return OrigineMouvement.retrait;
      case NaturePaiement.remboursement:
        return OrigineMouvement.remboursement;
      case NaturePaiement.ajustement || NaturePaiement.soldeInitial:
        return OrigineMouvement.ajustement;
      case NaturePaiement.autre:
        return OrigineMouvement.autre;
      case NaturePaiement.transfert:
        return OrigineMouvement.transfert;
      case null:
        break;
    }
    final aff = p.affectations.firstOrNull;
    final e = aff == null
        ? null
        : (engagements?[aff.engagementId] ?? etat.engagements.where((x) => x.id == aff.engagementId).firstOrNull);
    final entree = p.sens == SensPaiement.entree;
    bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (e != null) {
      return switch (e.origineType) {
        'VENTE' =>
          memeJour(p.datePaiement.toLocal(), e.dateEngagement)
              ? OrigineMouvement.vente
              : OrigineMouvement.paiementClient,
        'ACHAT' =>
          memeJour(p.datePaiement.toLocal(), e.dateEngagement)
              ? OrigineMouvement.achat
              : OrigineMouvement.paiementFournisseur,
        'PRESTATION' || 'INTERVENTION' => OrigineMouvement.prestation,
        'LOYER' => OrigineMouvement.loyer,
        'DEPENSE' => OrigineMouvement.depense,
        _ => entree ? OrigineMouvement.paiementClient : OrigineMouvement.paiementFournisseur,
      };
    }
    if (p.contactId != null) return entree ? OrigineMouvement.paiementClient : OrigineMouvement.paiementFournisseur;
    return OrigineMouvement.autre;
  }

  // ---------------------------------------------------------------------------
  // Soldes
  // ---------------------------------------------------------------------------

  /// Espèces : caisses de l'espace (session ouverte, sinon montant compté à
  /// la dernière clôture) + espèces encaissées ou versées hors caisse.
  int soldeEspeces(EtatFinances etat, {String? perimetreId}) {
    var total = 0;
    for (final c in etat.caisses.where((c) => c.estActive && _dans(c.perimetreId, perimetreId))) {
      final ouverte = etat.sessionOuverte(c.id);
      if (ouverte != null) {
        total += etat.solde(ouverte);
      } else {
        final fermees = etat.sessions.where((s) => s.caisseId == c.id && !s.ouverte && s.soldeReel != null).toList()
          ..sort((a, b) => (b.fermeeLe ?? b.ouverteLe).compareTo(a.fermeeLe ?? a.ouverteLe));
        total += fermees.firstOrNull?.soldeReel ?? 0;
      }
    }
    for (final p in etat.paiements) {
      if (p.mode == ModePaiement.especes &&
          p.sessionId == null &&
          etat.compte(p) &&
          _dans(p.perimetreId, perimetreId)) {
        total += _signe(p);
      }
    }
    return total;
  }

  /// Solde de chaque moyen d'argent. Hors espèces : somme des mouvements
  /// (soldes initiaux et transferts compris).
  Map<ModePaiement, int> soldesParMode(EtatFinances etat, {String? perimetreId}) {
    final res = {for (final m in ModePaiement.values) m: 0};
    res[ModePaiement.especes] = soldeEspeces(etat, perimetreId: perimetreId);
    for (final p in etat.paiements) {
      if (p.mode == ModePaiement.especes || !etat.compte(p) || !_dans(p.perimetreId, perimetreId)) continue;
      res[p.mode] = res[p.mode]! + _signe(p);
    }
    return res;
  }

  // ---------------------------------------------------------------------------
  // Flux
  // ---------------------------------------------------------------------------

  /// Mouvements réels d'une période : paiements (hors transferts) et anciens
  /// dépôts / retraits d'espèces saisis directement en caisse.
  List<({DateTime date, int montant, bool entree, ModePaiement mode, OrigineMouvement origine})> flux(
    EtatFinances etat,
    Intervalle periode, {
    String? perimetreId,
  }) {
    final engagements = {for (final e in etat.engagements) e.id: e};
    final sites = {for (final s in etat.sessions) s.id: s.perimetreId};
    return [
      for (final p in etat.paiements)
        if (etat.compte(p) &&
            !p.estTransfert &&
            _dans(p.perimetreId, perimetreId) &&
            periode.contient(p.datePaiement.toLocal()))
          (
            date: p.datePaiement.toLocal(),
            montant: p.montant,
            entree: p.sens == SensPaiement.entree,
            mode: p.mode,
            origine: origine(etat, p, engagements: engagements),
          ),
      for (final m in etat.mouvements)
        if (m.paiementId == null &&
            etat.mouvementValide(m) &&
            _dans(sites[m.sessionId], perimetreId) &&
            periode.contient(m.createdAt.toLocal()))
          (
            date: m.createdAt.toLocal(),
            montant: m.montant,
            entree: m.type.estEntree,
            mode: ModePaiement.especes,
            origine: m.type.estEntree ? OrigineMouvement.apport : OrigineMouvement.retrait,
          ),
    ];
  }

  ResumeTresorerie resumePeriode(
    EtatFinances etat,
    FiltrePeriode filtre, {
    String? perimetreId,
    DateTime? maintenant,
  }) => _resume(etat, filtre.intervalle(maintenant ?? DateTime.now()), perimetreId: perimetreId);

  ResumeTresorerie _resume(EtatFinances etat, Intervalle periode, {String? perimetreId}) {
    var entrees = 0, sorties = 0;
    final f = flux(etat, periode, perimetreId: perimetreId);
    for (final x in f) {
      x.entree ? entrees += x.montant : sorties += x.montant;
    }
    final soldes = soldesParMode(etat, perimetreId: perimetreId);
    return ResumeTresorerie(
      soldeEspeces: soldes[ModePaiement.especes]!,
      soldesParMode: soldes,
      entrees: entrees,
      sorties: sorties,
      nombreOperations: f.length,
    );
  }

  /// Solde jour par jour sur [nbJours] : reconstruit depuis le solde actuel
  /// en remontant les mouvements (transferts compris pour une boutique).
  List<PointEvolutionTresorerie> evolution(
    EtatFinances etat,
    int nbJours, {
    String? perimetreId,
    DateTime? maintenant,
  }) {
    final now = maintenant ?? DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final debut = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - (nbJours - 1));
    final jours = [for (var i = 0; i < nbJours; i++) DateTime(debut.year, debut.month, debut.day + i)];
    final entrees = {for (final j in jours) j: 0};
    final sorties = {for (final j in jours) j: 0};
    var apresDebut = 0;
    final sites = {for (final s in etat.sessions) s.id: s.perimetreId};

    void ajouter(DateTime d, int montant, bool entree) {
      final local = d.toLocal();
      final j = DateTime(local.year, local.month, local.day);
      if (j.isBefore(debut)) return;
      apresDebut += entree ? montant : -montant;
      if (!entrees.containsKey(j)) return;
      entree ? entrees[j] = entrees[j]! + montant : sorties[j] = sorties[j]! + montant;
    }

    for (final p in etat.paiements) {
      // Pour une boutique, un transfert fait varier son solde ; globalement il s'annule.
      if (!etat.compte(p) || !_dans(p.perimetreId, perimetreId)) continue;
      ajouter(p.datePaiement, p.montant, p.sens == SensPaiement.entree);
    }
    for (final m in etat.mouvements) {
      if (m.paiementId != null || !etat.mouvementValide(m) || !_dans(sites[m.sessionId], perimetreId)) continue;
      ajouter(m.createdAt, m.montant, m.type.estEntree);
    }

    final actuel = soldesParMode(etat, perimetreId: perimetreId).values.fold(0, (a, b) => a + b);
    var solde = actuel - apresDebut;
    return [
      for (final j in jours)
        PointEvolutionTresorerie(
          date: j,
          entrees: entrees[j]!,
          sorties: sorties[j]!,
          solde: solde += entrees[j]! - sorties[j]!,
        ),
    ];
  }

  /// D'où vient l'argent (entrées) ou où il part (sorties), par origine.
  List<LigneRepartition> repartition(
    EtatFinances etat,
    FiltrePeriode filtre, {
    required bool entrees,
    String? perimetreId,
    DateTime? maintenant,
  }) {
    final totaux = <OrigineMouvement, int>{};
    for (final x in flux(etat, filtre.intervalle(maintenant ?? DateTime.now()), perimetreId: perimetreId)) {
      if (x.entree != entrees) continue;
      totaux[x.origine] = (totaux[x.origine] ?? 0) + x.montant;
    }
    final total = totaux.values.fold(0, (a, b) => a + b);
    if (total == 0) return const [];
    return [
      for (final e in totaux.entries)
        LigneRepartition(origine: e.key, montant: e.value, pourcentage: e.value * 100 / total),
    ]..sort((a, b) => b.montant.compareTo(a.montant));
  }

  /// Entrées de la période par moyen d'argent.
  List<ProportionModePaiement> moyensPaiementEncaissement(
    EtatFinances etat,
    FiltrePeriode filtre, {
    String? perimetreId,
    DateTime? maintenant,
  }) {
    final totaux = <ModePaiement, int>{};
    for (final x in flux(etat, filtre.intervalle(maintenant ?? DateTime.now()), perimetreId: perimetreId)) {
      if (!x.entree) continue;
      totaux[x.mode] = (totaux[x.mode] ?? 0) + x.montant;
    }
    final total = totaux.values.fold(0, (a, b) => a + b);
    if (total == 0) return const [];
    return [
      for (final e in totaux.entries)
        ProportionModePaiement(mode: e.key, montant: e.value, pourcentage: e.value * 100 / total),
    ]..sort((a, b) => b.montant.compareTo(a.montant));
  }

  /// Période vs période précédente (même durée écoulée) ; `null` sans période comparable.
  ComparaisonPeriodeFinances? comparaisonPeriode(
    EtatFinances etat,
    FiltrePeriode filtre, {
    String? perimetreId,
    DateTime? maintenant,
  }) {
    final now = maintenant ?? DateTime.now();
    final precedent = filtre.precedent(now);
    if (precedent == null) return null;
    final actuel = _resume(etat, filtre.intervalle(now), perimetreId: perimetreId);
    final avant = _resume(etat, precedent, perimetreId: perimetreId);
    return ComparaisonPeriodeFinances(
      entrees: actuel.entrees,
      entreesPrecedentes: avant.entrees,
      sorties: actuel.sorties,
      sortiesPrecedentes: avant.sorties,
    );
  }

  /// Flux et soldes de chaque boutique visible (vue globale).
  List<FluxBoutiqueFinances> fluxParBoutique(EtatFinances etat, FiltrePeriode filtre, {DateTime? maintenant}) {
    final ids = <String>{
      for (final c in etat.caisses) c.perimetreId,
      for (final p in etat.paiements)
        if (p.perimetreId != null) p.perimetreId!,
    };
    final periode = filtre.intervalle(maintenant ?? DateTime.now());
    return [
      for (final id in ids)
        () {
          final r = _resume(etat, periode, perimetreId: id);
          return FluxBoutiqueFinances(
            perimetreId: id,
            entrees: r.entrees,
            sorties: r.sorties,
            soldeEspeces: r.soldeEspeces,
            tresorerieTotale: r.tresorerieTotale,
            caisseOuverte: etat.caisses.any((c) => c.perimetreId == id && etat.sessionOuverte(c.id) != null),
          );
        }(),
    ]..sort((a, b) => b.tresorerieTotale.compareTo(a.tresorerieTotale));
  }

  /// Seulement les alertes utiles : écart à une clôture récente (7 jours),
  /// sorties de la semaine en hausse de plus de 35 % (avec base comparable).
  List<AlerteTresorerie> alertes(EtatFinances etat, {String? perimetreId, DateTime? maintenant}) {
    final now = maintenant ?? DateTime.now();
    final res = <AlerteTresorerie>[];
    for (final c in etat.caisses.where((c) => _dans(c.perimetreId, perimetreId))) {
      final derniere =
          (etat.sessions.where((s) => s.caisseId == c.id && !s.ouverte && s.ecart != null).toList()
                ..sort((a, b) => (b.fermeeLe ?? b.ouverteLe).compareTo(a.fermeeLe ?? a.ouverteLe)))
              .firstOrNull;
      if (derniere != null && derniere.ecart != 0 && now.difference(derniere.fermeeLe ?? now).inDays < 7) {
        res.add(
          AlerteTresorerie(
            type: TypeAlerteTresorerie.ecartCaisse,
            montant: derniere.ecart,
            caisseId: c.id,
            perimetreId: c.perimetreId,
          ),
        );
      }
    }
    final semaine = comparaisonPeriode(etat, FiltrePeriode.cetteSemaine, perimetreId: perimetreId, maintenant: now);
    final hausse = semaine?.evolutionSorties;
    if (hausse != null && hausse > 35) {
      res.add(
        AlerteTresorerie(
          type: TypeAlerteTresorerie.sortiesEnHausse,
          pourcentage: hausse.round(),
          perimetreId: perimetreId,
        ),
      );
    }
    return res;
  }

  // ---------------------------------------------------------------------------
  // Historique
  // ---------------------------------------------------------------------------

  /// Historique chronologique (le plus récent d'abord). Les opérations
  /// annulées et refusées restent visibles, barrées : rien n'est effacé.
  List<OperationTresorerie> historique(
    EtatFinances etat, {
    FiltrePeriode filtre = FiltrePeriode.ceMois,
    String? recherche,
    SensPaiement? sens,
    ModePaiement? mode,
    OrigineMouvement? origine,
    String? perimetreId,
    Map<String, String> nomsBoutiques = const {},
    Map<String, String> nomsContacts = const {},
    DateTime? maintenant,
  }) {
    final periode = filtre.intervalle(maintenant ?? DateTime.now());
    final engagements = {for (final e in etat.engagements) e.id: e};
    final depenses = {for (final d in etat.depenses) d.id: d};
    final sites = {for (final s in etat.sessions) s.id: s.perimetreId};
    final liste = <OperationTresorerie>[];

    for (final p in etat.paiements) {
      if (!_dans(p.perimetreId, perimetreId) || !periode.contient(p.datePaiement.toLocal())) continue;
      final o = this.origine(etat, p, engagements: engagements);
      final aff = p.affectations.firstOrNull;
      final eng = aff == null ? null : engagements[aff.engagementId];
      final dep = aff == null ? null : depenses[aff.engagementId];
      liste.add(
        OperationTresorerie(
          id: p.id,
          date: p.datePaiement.toLocal(),
          sens: p.sens,
          montant: p.montant,
          mode: p.mode,
          origine: o,
          libelle: dep?.libelle ?? eng?.libelle ?? (p.nature == null ? null : p.note),
          reference: p.reference,
          perimetreId: p.perimetreId,
          contactId: p.contactId ?? eng?.contactId,
          note: p.note,
          estAnnule: etat.estAnnule(p),
          estAnnulation: p.estAnnulation,
          estRefuse: p.refuse,
          enAttente: p.enAttente,
          sessionId: p.sessionId,
          paiementId: p.id,
          transfertId: p.transfertId,
          depenseId: dep?.id,
        ),
      );
    }
    for (final m in etat.mouvements) {
      if (m.paiementId != null || !_dans(sites[m.sessionId], perimetreId) || !periode.contient(m.createdAt.toLocal())) {
        continue;
      }
      liste.add(
        OperationTresorerie(
          id: m.id,
          date: m.createdAt.toLocal(),
          sens: m.type.estEntree ? SensPaiement.entree : SensPaiement.sortie,
          montant: m.montant,
          mode: ModePaiement.especes,
          origine: m.type.estEntree ? OrigineMouvement.apport : OrigineMouvement.retrait,
          libelle: m.motif,
          perimetreId: sites[m.sessionId],
          note: m.motif,
          estRefuse: !etat.mouvementValide(m),
          sessionId: m.sessionId,
        ),
      );
    }

    final q = recherche?.trim().toLowerCase() ?? '';
    bool garde(OperationTresorerie op) {
      if (sens != null && op.sens != sens) return false;
      if (mode != null && op.mode != mode) return false;
      if (origine != null && op.origine != origine) return false;
      if (q.isEmpty) return true;
      return [
        op.libelle,
        op.reference,
        op.note,
        nomsContacts[op.contactId],
        nomsBoutiques[op.perimetreId],
        '${op.montant}',
      ].any((t) => t != null && t.toLowerCase().contains(q));
    }

    return liste.where(garde).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static bool _dans(String? site, String? perimetreId) => perimetreId == null || site == perimetreId;
  static int _signe(Paiement p) => p.sens == SensPaiement.entree ? p.montant : -p.montant;
}
