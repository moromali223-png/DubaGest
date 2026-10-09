import '../../finances/domain/entities/finances.dart';
import '../../finances/domain/services/etat_finances.dart';

enum PeriodeTableau { septJours, trenteJours, moisEnCours }

/// Montants d'une journée (encaissé / versé), comptés hors annulations.
class JourFinancier {
  const JourFinancier(this.jour, {this.entrees = 0, this.sorties = 0});
  final DateTime jour;
  final int entrees;
  final int sorties;
}

class PartCategorie {
  const PartCategorie(this.categorie, this.montant);

  /// `null` : regroupement « Autres catégories ».
  final CategorieDepense? categorie;
  final int montant;
}

class Debiteur {
  const Debiteur(this.contactId, this.montant, this.enRetard);

  /// `null` : sommes dues sans contact.
  final String? contactId;
  final int montant;
  final bool enRetard;
}

/// Chiffres du tableau de bord : tout est recalculé à partir des écritures
/// réelles (aucune valeur stockée en double, aucune donnée inventée).
class TableauDeBord {
  const TableauDeBord({
    required this.debut,
    required this.fin,
    required this.jours,
    required this.encaisse,
    required this.verse,
    required this.depenses,
    required this.parCategorie,
    required this.debiteurs,
    required this.resume,
  });

  final DateTime debut;

  /// Inclus.
  final DateTime fin;
  final List<JourFinancier> jours;
  final int encaisse;
  final int verse;
  final int depenses;
  final List<PartCategorie> parCategorie;
  final List<Debiteur> debiteurs;

  /// Situation à date (à recevoir, à payer, en caisse).
  final ResumeFinances resume;

  int get net => encaisse - verse;
  bool get vide => encaisse == 0 && verse == 0 && depenses == 0 && debiteurs.isEmpty;

  static DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

  static (DateTime, DateTime) bornes(PeriodeTableau p, DateTime maintenant) {
    final fin = _jour(maintenant);
    return switch (p) {
      PeriodeTableau.septJours => (fin.subtract(const Duration(days: 6)), fin),
      PeriodeTableau.trenteJours => (fin.subtract(const Duration(days: 29)), fin),
      PeriodeTableau.moisEnCours => (DateTime(fin.year, fin.month), fin),
    };
  }

  /// [categoriesMax] : au-delà, les plus petites sont regroupées.
  static TableauDeBord calculer(
    EtatFinances etat, {
    required PeriodeTableau periode,
    required DateTime maintenant,
    int categoriesMax = 6,
    int debiteursMax = 5,
  }) {
    final (debut, fin) = bornes(periode, maintenant);
    bool dansPeriode(DateTime d) {
      final j = _jour(d.toLocal());
      return !j.isBefore(debut) && !j.isAfter(fin);
    }

    // Jours de la période (au plus 31) ; une valeur par jour, même vide.
    final parJour = <DateTime, (int, int)>{
      for (var j = debut; !j.isAfter(fin); j = DateTime(j.year, j.month, j.day + 1)) j: (0, 0),
    };
    var encaisse = 0, verse = 0;
    for (final p in etat.paiements) {
      if (!etat.compte(p) || !dansPeriode(p.datePaiement)) continue;
      final j = _jour(p.datePaiement.toLocal());
      final (e, s) = parJour[j] ?? (0, 0);
      if (p.sens == SensPaiement.entree) {
        encaisse += p.montant;
        parJour[j] = (e + p.montant, s);
      } else {
        verse += p.montant;
        parJour[j] = (e, s + p.montant);
      }
    }

    final totaux = <String, int>{};
    for (final d in etat.depenses) {
      if (!etat.depenseComptee(d) || !dansPeriode(d.dateDepense)) continue;
      totaux[d.categorieId] = (totaux[d.categorieId] ?? 0) + d.montant;
    }
    final tries = totaux.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final parCategorie = <PartCategorie>[
      for (final e in tries.take(categoriesMax)) PartCategorie(etat.categorie(e.key), e.value),
      if (tries.length > categoriesMax)
        PartCategorie(null, tries.skip(categoriesMax).fold(0, (t, e) => t + e.value)),
    ];

    final dus = <String?, (int, bool)>{};
    for (final s in etat.suivis) {
      if (s.engagement.refuse || s.engagement.sens != SensEngagement.aRecevoir || s.reste == 0) continue;
      final (m, retard) = dus[s.engagement.contactId] ?? (0, false);
      dus[s.engagement.contactId] = (m + s.reste, retard || s.etat(maintenant) == EtatReglement.enRetard);
    }
    final debiteurs = [for (final e in dus.entries) Debiteur(e.key, e.value.$1, e.value.$2)]
      ..sort((a, b) => b.montant.compareTo(a.montant));

    return TableauDeBord(
      debut: debut,
      fin: fin,
      jours: [for (final e in parJour.entries) JourFinancier(e.key, entrees: e.value.$1, sorties: e.value.$2)],
      encaisse: encaisse,
      verse: verse,
      depenses: totaux.values.fold(0, (t, v) => t + v),
      parCategorie: parCategorie,
      debiteurs: debiteurs.take(debiteursMax).toList(),
      resume: etat.resume(maintenant),
    );
  }
}
