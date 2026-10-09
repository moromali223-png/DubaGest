import '../entities/metier_template.dart';
import '../entities/prestation.dart';

/// Résumé des indicateurs du tableau de bord Services.
class SyntheseServices {
  const SyntheseServices({
    required this.prestationsAujourdhui,
    required this.prestationsEnCours,
    required this.prestationsEnRetard,
    required this.prestationsUrgentes,
    required this.prestationsATraiter,
    required this.devisEnAttente,
    required this.devisARelancer,
    required this.totalARecevoir,
    required this.totalEncaisseAujourdhui,
  });

  final int prestationsAujourdhui;
  final int prestationsEnCours;
  final int prestationsEnRetard;
  final int prestationsUrgentes;
  final int prestationsATraiter;
  final int devisEnAttente;
  final int devisARelancer;
  final int totalARecevoir;
  final int totalEncaisseAujourdhui;
}

/// Moteur centralisé de calcul d'échéances, de priorités et d'alertes temporelles.
class MoteurEcheances {
  const MoteurEcheances();

  /// Calcule la date d'échéance prévisionnelle à partir d'une date de début, d'une durée et d'une unité.
  DateTime calculerEcheancePrevue(DateTime debut, int duree, UniteDuree unite) {
    if (duree <= 0) return debut;
    return switch (unite) {
      UniteDuree.heures => debut.add(Duration(hours: duree)),
      UniteDuree.jours => debut.add(Duration(days: duree)),
      UniteDuree.semaines => debut.add(Duration(days: duree * 7)),
      UniteDuree.mois => DateTime(debut.year, debut.month + duree, debut.day, debut.hour, debut.minute),
    };
  }

  /// Calcule le niveau de priorité temporel d'une prestation à un instant [now].
  PrioriteEcheance calculerPriorite(Prestation prestation, [DateTime? now]) {
    final instant = now ?? DateTime.now();
    if (prestation.statut == StatutPrestation.annulee ||
        prestation.statut == StatutPrestation.terminee ||
        prestation.statut == StatutPrestation.livree) {
      return PrioriteEcheance.faible;
    }

    final echeance = prestation.dateEcheanceComplete;
    if (echeance == null) return PrioriteEcheance.faible;

    final debutJourNow = DateTime(instant.year, instant.month, instant.day);
    final debutJourEcheance = DateTime(echeance.year, echeance.month, echeance.day);

    // 1. Échéance dépassée
    if (echeance.isBefore(instant)) {
      return PrioriteEcheance.enRetard;
    }

    // 2. Échéance aujourd'hui
    if (debutJourEcheance.isAtSameMomentAs(debutJourNow)) {
      return PrioriteEcheance.aujourdhui;
    }

    // 3. Différence temporelle exacte
    final difference = echeance.difference(instant);
    if (difference.inHours <= 24) {
      return PrioriteEcheance.urgent; // J-1
    } else if (difference.inHours <= 48) {
      return PrioriteEcheance.attention; // J-2
    }

    return PrioriteEcheance.faible;
  }

  /// Indique si la prestation nécessite une attention immédiate (Aujourd'hui, J-1, J-2 ou Retard).
  bool estAlerteActive(Prestation prestation, [DateTime? now]) {
    final p = calculerPriorite(prestation, now);
    return p != PrioriteEcheance.faible;
  }

  /// Texte lisible du retard (ex. « 2 jours de retard », « 4 heures de retard »).
  String texteRetard(Prestation prestation, [DateTime? now]) {
    final echeance = prestation.dateEcheanceComplete;
    if (echeance == null) return '';
    final instant = now ?? DateTime.now();
    final diff = instant.difference(echeance);
    if (diff.isNegative) return '';

    if (diff.inDays >= 1) {
      return '${diff.inDays} jour${diff.inDays > 1 ? 's' : ''} de retard';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} heure${diff.inHours > 1 ? 's' : ''} de retard';
    } else {
      return '${diff.inMinutes.clamp(1, 59)} min de retard';
    }
  }

  /// Texte lisible du délai avant échéance (ex. « Dans 2 jours », « Aujourd'hui »).
  String texteDelai(Prestation prestation, [DateTime? now]) {
    final echeance = prestation.dateEcheanceComplete;
    if (echeance == null) return 'Sans date limite';
    final instant = now ?? DateTime.now();

    final p = calculerPriorite(prestation, instant);
    return switch (p) {
      PrioriteEcheance.enRetard => texteRetard(prestation, instant),
      PrioriteEcheance.aujourdhui => prestation.echeanceHeure != null && prestation.echeanceHeure!.isNotEmpty
          ? 'Aujourd\'hui à ${prestation.echeanceHeure}'
          : 'Aujourd\'hui',
      PrioriteEcheance.urgent => 'Demain (J-1)',
      PrioriteEcheance.attention => 'Dans 2 jours (J-2)',
      PrioriteEcheance.faible =>
        'Le ${echeance.day.toString().padLeft(2, '0')}/${echeance.month.toString().padLeft(2, '0')}/${echeance.year}',
    };
  }

  /// Calcule la synthèse globale des KPIs.
  SyntheseServices synthese({
    required List<Prestation> prestations,
    required List<DevisPrestation> devis,
    int totalEncaisseAujourdhui = 0,
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final debutJourNow = DateTime(instant.year, instant.month, instant.day);
    final finJourNow = debutJourNow.add(const Duration(days: 1));

    int aujourdhuiCount = 0;
    int enCoursCount = 0;
    int enRetardCount = 0;
    int urgentesCount = 0;
    int aTraiterCount = 0;
    int aRecevoir = 0;

    for (final p in prestations) {
      if (p.statut == StatutPrestation.annulee) continue;

      if (p.soldeRestant > 0) {
        aRecevoir += p.soldeRestant;
      }

      if (p.statut.estActive) {
        aTraiterCount++;
      }

      if (p.statut == StatutPrestation.enCours) {
        enCoursCount++;
      }

      final priorite = calculerPriorite(p, instant);
      if (priorite == PrioriteEcheance.enRetard) {
        enRetardCount++;
      } else if (priorite == PrioriteEcheance.urgent || priorite == PrioriteEcheance.attention) {
        urgentesCount++;
      }

      if (p.echeanceJour != null) {
        if (p.echeanceJour!.isAfter(debutJourNow.subtract(const Duration(seconds: 1))) &&
            p.echeanceJour!.isBefore(finJourNow)) {
          aujourdhuiCount++;
        }
      }
    }

    int devisAttente = 0;
    int devisRelance = 0;
    for (final d in devis) {
      if (d.statut == StatutDevis.envoye || d.statut == StatutDevis.brouillon) {
        devisAttente++;
        if (d.dateValidite != null && d.dateValidite!.difference(instant).inDays <= 3) {
          devisRelance++;
        }
      }
    }

    return SyntheseServices(
      prestationsAujourdhui: aujourdhuiCount,
      prestationsEnCours: enCoursCount,
      prestationsEnRetard: enRetardCount,
      prestationsUrgentes: urgentesCount,
      prestationsATraiter: aTraiterCount,
      devisEnAttente: devisAttente,
      devisARelancer: devisRelance,
      totalARecevoir: aRecevoir,
      totalEncaisseAujourdhui: totalEncaisseAujourdhui,
    );
  }
}
