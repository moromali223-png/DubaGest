import '../entities/finance_forecast.dart';
import '../entities/finances.dart';

/// Service de prévision de trésorerie à 7, 30 et 90 jours.
class TresorerieForecaster {
  const TresorerieForecaster();

  PrevisionTresorerie calculer({
    required int soldeActuel,
    required List<EngagementSuivi> engagements,
    required List<DepenseCourante> depensesCourantes,
    required DateTime maintenant,
  }) {
    final h7 = _calculerHorizon(
      soldeActuel: soldeActuel,
      engagements: engagements,
      depensesCourantes: depensesCourantes,
      maintenant: maintenant,
      horizonJours: 7,
      libelle: 'Dans 7 jours',
    );

    final h30 = _calculerHorizon(
      soldeActuel: soldeActuel,
      engagements: engagements,
      depensesCourantes: depensesCourantes,
      maintenant: maintenant,
      horizonJours: 30,
      libelle: 'Dans 30 jours',
    );

    final h90 = _calculerHorizon(
      soldeActuel: soldeActuel,
      engagements: engagements,
      depensesCourantes: depensesCourantes,
      maintenant: maintenant,
      horizonJours: 90,
      libelle: 'Dans 90 jours',
    );

    final attentionRequise = h7.tensionDetectee || h30.tensionDetectee || h90.tensionDetectee;

    final String synthese;
    if (soldeActuel == 0 && engagements.isEmpty && depensesCourantes.isEmpty) {
      synthese = 'Aucune échéance financière ni charge récurrente programmée sur cette période.';
    } else if (h30.tensionDetectee) {
      synthese =
          'Attention : Les paiements prévus dans les 30 prochains jours risquent de dépasser votre trésorerie et les encaissements attendus.';
    } else if (h30.soldePrevu > soldeActuel) {
      synthese =
          'Votre trésorerie devrait progresser à 30 jours si les créances clients sont encaissées à temps.';
    } else {
      synthese =
          'Votre trésorerie devrait rester positive et stable sous réserve du respect des échéances de paiement.';
    }

    return PrevisionTresorerie(
      soldeActuel: soldeActuel,
      horizon7Jours: h7,
      horizon30Jours: h30,
      horizon90Jours: h90,
      syntheseGlobale: synthese,
      attentionRequise: attentionRequise,
    );
  }

  PrevisionHorizon _calculerHorizon({
    required int soldeActuel,
    required List<EngagementSuivi> engagements,
    required List<DepenseCourante> depensesCourantes,
    required DateTime maintenant,
    required int horizonJours,
    required String libelle,
  }) {
    final finHorizon = maintenant.add(Duration(days: horizonJours));
    final jourMaintenant = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final jourFinHorizon = DateTime(finHorizon.year, finHorizon.month, finHorizon.day);

    var encaissements = 0;
    var decaissements = 0;

    // 1. Créances et dettes échues ou à échoir dans l'horizon
    for (final s in engagements) {
      if (s.engagement.annule || s.reste <= 0) continue;
      final echeance = s.engagement.echeance ?? s.engagement.dateEngagement;
      final jourEcheance = DateTime(echeance.year, echeance.month, echeance.day);

      // Si l'échéance est déjà passée (en retard) ou tombe avant la fin de l'horizon
      if (!jourEcheance.isAfter(jourFinHorizon)) {
        if (s.engagement.sens == SensEngagement.aRecevoir) {
          encaissements += s.reste;
        } else {
          decaissements += s.reste;
        }
      }
    }

    // 2. Dépenses courantes / récurrentes non encore payées dans l'horizon
    for (final c in depensesCourantes) {
      if (!c.estActive) continue;
      for (final e in c.echeancesJusqua(finHorizon)) {
        final jourEcheance = DateTime(e.year, e.month, e.day);
        if (!jourEcheance.isBefore(jourMaintenant) && !jourEcheance.isAfter(jourFinHorizon)) {
          decaissements += c.montantPrevu;
        }
      }
    }

    final soldePrevu = soldeActuel + encaissements - decaissements;
    final tensionDetectee = soldePrevu < 0;

    final String message;
    if (tensionDetectee) {
      message = 'Risque de solde négatif (manque estimé : ${(soldePrevu.abs())} FCFA)';
    } else if (soldePrevu >= soldeActuel) {
      message = 'Trésorerie attendue en hausse (+${(soldePrevu - soldeActuel)} FCFA)';
    } else {
      message = 'Trésorerie attendue en baisse (-${(soldeActuel - soldePrevu)} FCFA)';
    }

    return PrevisionHorizon(
      horizonJours: horizonJours,
      libelle: libelle,
      soldePrevu: soldePrevu,
      encaissementsAttendus: encaissements,
      decaissementsPrevus: decaissements,
      tensionDetectee: tensionDetectee,
      message: message,
    );
  }
}
