import '../entities/finance_alert.dart';
import '../entities/finance_health_score.dart';

/// Évaluateur intelligent de la santé financière d'une entreprise.
/// Analyse les indicateurs réels (Trésorerie, CA, Dépenses, Créances, Dettes, Marge).
class SanteFinanciereEvaluator {
  const SanteFinanciereEvaluator();

  SanteFinanciere evaluer({
    required int chiffreAffaires,
    required int depenses,
    required int margeOuResultat,
    required int tresorerieActuelle,
    required int aRecevoirTotal,
    required int creancesEnRetard,
    required int aPayerTotal,
    required int dettesEnRetard,
    required double? evolutionCA,
    required double? evolutionTresorerie,
  }) {
    if (chiffreAffaires == 0 && depenses == 0 && tresorerieActuelle == 0 && aRecevoirTotal == 0) {
      return const SanteFinanciere(
        niveau: NiveauSanteFinanciere.stable,
        score: 50,
        resumeCourt: 'Pas encore assez de données',
        explication:
            'Les statistiques et l’évaluation de la santé financière apparaîtront dès que vos premières opérations seront enregistrées.',
      );
    }

    var score = 70;
    final pointsForts = <String>[];
    final pointsVigilance = <String>[];

    // 1. Ratio Trésorerie vs Dépenses / Dettes
    if (tresorerieActuelle > 0) {
      if (aPayerTotal > 0 && tresorerieActuelle >= aPayerTotal) {
        score += 10;
        pointsForts.add('Votre trésorerie couvre la totalité de vos dettes à payer.');
      } else if (aPayerTotal > 0 && tresorerieActuelle < aPayerTotal ~/ 2) {
        score -= 15;
        pointsVigilance.add('La trésorerie actuelle est inférieure à la moitié des dettes fournisseurs.');
      }
    } else if (tresorerieActuelle < 0) {
      score -= 25;
      pointsVigilance.add('Solde de trésorerie négatif (découvert).');
    }

    // 2. Rentabilité (Résultat / Marge vs Dépenses)
    if (chiffreAffaires > 0) {
      if (margeOuResultat > 0) {
        score += 10;
        pointsForts.add('Votre activité génère un résultat positif.');
      } else if (margeOuResultat < 0) {
        score -= 15;
        pointsVigilance.add('Les dépenses et charges dépassent les revenus sur la période.');
      }
    }

    // 3. Évolution du Chiffre d'Affaires
    if (evolutionCA != null) {
      if (evolutionCA > 10) {
        score += 10;
        pointsForts.add('Chiffre d’affaires en nette progression (+${evolutionCA.toStringAsFixed(1)} %).');
      } else if (evolutionCA < -10) {
        score -= 10;
        pointsVigilance.add('Baisse du chiffre d’affaires (${evolutionCA.toStringAsFixed(1)} %).');
      }
    }

    // 4. Qualité des créances et retards
    if (creancesEnRetard > 0) {
      if (aRecevoirTotal > 0 && (creancesEnRetard / aRecevoirTotal) > 0.4) {
        score -= 15;
        pointsVigilance.add('Plus de 40 % de vos créances clients sont en retard de paiement.');
      } else {
        score -= 5;
        pointsVigilance.add('Certaines créances clients sont en retard d’échéance.');
      }
    } else if (aRecevoirTotal > 0) {
      pointsForts.add('Aucun retard de paiement constaté sur vos créances clients.');
    }

    // 5. Dettes en retard
    if (dettesEnRetard > 0) {
      score -= 15;
      pointsVigilance.add('Vous avez des dettes fournisseurs dont l’échéance est dépassée.');
    }

    score = score.clamp(0, 100);

    final NiveauSanteFinanciere niveau;
    final String resumeCourt;
    if (score >= 80) {
      niveau = NiveauSanteFinanciere.bonne;
      resumeCourt = 'Très bonne santé financière';
    } else if (score >= 60) {
      niveau = NiveauSanteFinanciere.stable;
      resumeCourt = 'Situation stable';
    } else if (score >= 40) {
      niveau = NiveauSanteFinanciere.aSurveiller;
      resumeCourt = 'Situation à surveiller';
    } else {
      niveau = NiveauSanteFinanciere.tension;
      resumeCourt = 'Tension financière détectée';
    }

    // Génération du paragraphe d'explication
    final explication = _genererExplication(
      niveau: niveau,
      chiffreAffaires: chiffreAffaires,
      tresorerieActuelle: tresorerieActuelle,
      pointsForts: pointsForts,
      pointsVigilance: pointsVigilance,
      evolutionCA: evolutionCA,
    );

    return SanteFinanciere(
      niveau: niveau,
      score: score,
      resumeCourt: resumeCourt,
      explication: explication,
      pointsForts: pointsForts,
      pointsVigilance: pointsVigilance,
    );
  }

  String _genererExplication({
    required NiveauSanteFinanciere niveau,
    required int chiffreAffaires,
    required int tresorerieActuelle,
    required List<String> pointsForts,
    required List<String> pointsVigilance,
    required double? evolutionCA,
  }) {
    final buffer = StringBuffer();
    switch (niveau) {
      case NiveauSanteFinanciere.bonne:
        buffer.write('Votre entreprise affiche une excellente solidité financière. ');
        if (evolutionCA != null && evolutionCA > 0) {
          buffer.write('Les revenus sont en croissance et la trésorerie reste confortable. ');
        }
        break;
      case NiveauSanteFinanciere.stable:
        buffer.write('La situation financière globale est équilibrée. ');
        if (tresorerieActuelle > 0) {
          buffer.write('Les liquidités disponibles permettent de couvrir les charges courantes. ');
        }
        break;
      case NiveauSanteFinanciere.aSurveiller:
        buffer.write('Quelques signaux demandent votre attention. ');
        if (pointsVigilance.isNotEmpty) {
          buffer.write(pointsVigilance.first);
          buffer.write(' ');
        }
        break;
      case NiveauSanteFinanciere.tension:
        buffer.write('Attention : votre trésorerie ou votre niveau d’impayés présente un risque à court terme. ');
        if (pointsVigilance.isNotEmpty) {
          buffer.write('Priorité recommandée : relancer les créances et échelonner les paiements dus. ');
        }
        break;
    }

    if (pointsVigilance.isNotEmpty && niveau != NiveauSanteFinanciere.tension && niveau != NiveauSanteFinanciere.aSurveiller) {
      buffer.write('Point à surveiller : ${pointsVigilance.first}');
    }

    return buffer.toString().trim();
  }
}
