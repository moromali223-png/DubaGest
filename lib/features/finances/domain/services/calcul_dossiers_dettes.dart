import '../../../contacts/domain/entities/contact.dart';
import '../entities/dossier_dette.dart';
import '../entities/finances.dart';
import 'etat_finances.dart';

/// Moteur de consolidation des dettes et créances par personne.
/// « Une personne = un dossier financier complet ».
abstract final class CalculDossiersDettes {
  /// Consolide tous les engagements d'un sens donné en une liste de dossiers uniques par personne.
  static List<DossierDette> consolider({
    required EtatFinances etat,
    required Map<String, Contact> contacts,
    required SensEngagement sens,
    required DateTime maintenant,
  }) {
    final jourCourant = DateTime(maintenant.year, maintenant.month, maintenant.day);

    // 1. Regrouper les engagements par clé de dossier (contactId prioritaire)
    final mapGroupes = <String, List<EngagementSuivi>>{};

    for (final suivi in etat.suivis) {
      final e = suivi.engagement;
      if (e.refuse || e.sens != sens) continue;

      final key = e.contactId != null ? 'contact_${e.contactId}' : 'libelle_${e.libelle.trim().toLowerCase()}';
      mapGroupes.putIfAbsent(key, () => []).add(suivi);
    }

    // 2. Construire chaque dossier financier
    final dossiers = <DossierDette>[];

    for (final entry in mapGroupes.entries) {
      final key = entry.key;
      final engagementsDuDossier = entry.value;

      final contactId = engagementsDuDossier.first.engagement.contactId;
      final contact = contactId != null ? contacts[contactId] : null;

      final nomAffiche = contact?.nomAffiche ??
          (contactId != null
              ? 'Contact #$contactId'
              : engagementsDuDossier.first.engagement.libelle);

      final telephone = contact?.telephone ?? contact?.whatsapp;

      // Retrouver tous les paiements liés à ce dossier
      final idsEngagements = {for (final s in engagementsDuDossier) s.engagement.id};
      final paiementsDuDossier = <PaiementSuivi>[];

      for (final pSuivi in etat.paiementsSuivis) {
        final p = pSuivi.paiement;
        if (p.refuse) continue;

        final estLieParContact = contactId != null && p.contactId == contactId;
        final estLieParAffectation = p.affectations.any((a) => idsEngagements.contains(a.engagementId));

        if (estLieParContact || estLieParAffectation) {
          paiementsDuDossier.add(pSuivi);
        }
      }

      // Totaux financiers
      var totalDu = 0;
      var totalPaye = 0;
      var totalEnRetard = 0;
      var nbDettesActives = 0;
      var nbEcheancesEnRetard = 0;
      DateTime? prochaineEcheance;

      final echeances = <EcheanceDette>[];

      for (final s in engagementsDuDossier) {
        final e = s.engagement;
        if (e.annule) continue;

        totalDu += e.montantTotal;
        totalPaye += s.regle;

        if (s.reste > 0) {
          nbDettesActives++;
        }

        if (e.echeance != null) {
          final dateEch = DateTime(e.echeance!.year, e.echeance!.month, e.echeance!.day);
          final estEnRetard = s.reste > 0 && dateEch.isBefore(jourCourant);

          StatutEcheanceItem statutEch;
          int retardJours = 0;

          if (s.reste == 0) {
            statutEch = StatutEcheanceItem.reglee;
          } else if (estEnRetard) {
            statutEch = StatutEcheanceItem.enRetard;
            retardJours = jourCourant.difference(dateEch).inDays;
            totalEnRetard += s.reste;
            nbEcheancesEnRetard++;
          } else if (dateEch == jourCourant) {
            statutEch = StatutEcheanceItem.aujourdhui;
          } else if (dateEch.difference(jourCourant).inDays <= 7) {
            statutEch = StatutEcheanceItem.cetteSemaine;
          } else if (dateEch.difference(jourCourant).inDays <= 14) {
            statutEch = StatutEcheanceItem.semaineProchaine;
          } else {
            statutEch = StatutEcheanceItem.plusTard;
          }

          if (s.reste > 0 && (prochaineEcheance == null || e.echeance!.isBefore(prochaineEcheance))) {
            prochaineEcheance = e.echeance;
          }

          echeances.add(
            EcheanceDette(
              engagementId: e.id,
              libelle: e.libelle,
              dateEcheance: e.echeance!,
              montantInitial: e.montantTotal,
              montantRegle: s.regle,
              montantReste: s.reste,
              statut: statutEch,
              retardJours: retardJours,
              origineType: e.origineType,
              contactId: contactId,
              nomContact: nomAffiche,
            ),
          );
        }
      }

      // Trier les échéances par date chronologique
      echeances.sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));

      final resteNet = (totalDu - totalPaye).clamp(0, totalDu);

      // Statut global du dossier
      StatutDossierDette statutGlobal;
      if (resteNet == 0) {
        statutGlobal = StatutDossierDette.regle;
      } else if (totalEnRetard > 0 || nbEcheancesEnRetard > 0) {
        statutGlobal = StatutDossierDette.enRetard;
      } else if (prochaineEcheance != null &&
          DateTime(prochaineEcheance.year, prochaineEcheance.month, prochaineEcheance.day)
                  .difference(jourCourant)
                  .inDays <=
              7) {
        statutGlobal = StatutDossierDette.bientot;
      } else {
        statutGlobal = StatutDossierDette.aJour;
      }

      // Construction de la Timeline et de l'évolution du solde
      final timeline = _construireTimeline(
        engagements: engagementsDuDossier,
        paiements: paiementsDuDossier,
        sens: sens,
      );

      final evolution = _construireEvolutionSolde(timeline);

      dossiers.add(
        DossierDette(
          dossierKey: key,
          contactId: contactId,
          contact: contact,
          nomAffiche: nomAffiche,
          telephone: telephone,
          sens: sens,
          engagements: engagementsDuDossier,
          paiements: paiementsDuDossier,
          totalDu: totalDu,
          totalPaye: totalPaye,
          reste: resteNet,
          totalEnRetard: totalEnRetard,
          nbDettesActives: nbDettesActives,
          nbEcheancesEnRetard: nbEcheancesEnRetard,
          prochaineEcheance: prochaineEcheance,
          statutGlobal: statutGlobal,
          echeances: echeances,
          timeline: timeline,
          evolutionSolde: evolution,
        ),
      );
    }

    // Tri par priorité :
    // 1. Les dossiers en retard en premier,
    // 2. Puis par montant restant décroissant,
    // 3. Les dossiers soldés à la fin.
    dossiers.sort((a, b) {
      if (a.estSolde != b.estSolde) {
        return a.estSolde ? 1 : -1;
      }
      if (a.estEnRetard != b.estEnRetard) {
        return a.estEnRetard ? -1 : 1;
      }
      return b.reste.compareTo(a.reste);
    });

    return dossiers;
  }

  static List<EvenementTimelineDette> _construireTimeline({
    required List<EngagementSuivi> engagements,
    required List<PaiementSuivi> paiements,
    required SensEngagement sens,
  }) {
    final brute = <EvenementTimelineDette>[];

    // Création des dettes
    for (final s in engagements) {
      final e = s.engagement;
      brute.add(
        EvenementTimelineDette(
          id: 'eng_${e.id}',
          date: e.dateEngagement,
          type: TypeEvenementDette.creationDette,
          montant: e.montantTotal,
          libelle: e.libelle,
          engagementId: e.id,
          reference: e.origineType != 'MANUEL'
              ? '${e.origineType} #${e.id.length > 8 ? e.id.substring(0, 8) : e.id}'
              : null,
        ),
      );

      if (e.annule) {
        brute.add(
          EvenementTimelineDette(
            id: 'eng_annule_${e.id}',
            date: e.dateEngagement.add(const Duration(minutes: 1)),
            type: TypeEvenementDette.annulation,
            montant: e.montantTotal,
            libelle: 'Annulation: ${e.motifAnnulation ?? e.libelle}',
            engagementId: e.id,
          ),
        );
      }
    }

    // Paiements
    for (final pSuivi in paiements) {
      final p = pSuivi.paiement;
      final type = sens == SensEngagement.aRecevoir
          ? TypeEvenementDette.paiementRecu
          : TypeEvenementDette.paiementEmis;

      brute.add(
        EvenementTimelineDette(
          id: 'pay_${p.id}',
          date: p.datePaiement,
          type: pSuivi.annule ? TypeEvenementDette.annulation : type,
          montant: p.montant,
          libelle: p.note != null && p.note!.trim().isNotEmpty
              ? p.note!.trim()
              : (sens == SensEngagement.aRecevoir ? 'Paiement reçu' : 'Paiement effectué'),
          mode: p.mode,
          paiementId: p.id,
          reference: p.reference,
          note: p.note,
        ),
      );
    }

    // Trier du plus ancien au plus récent pour calculer le solde progressif
    brute.sort((a, b) => a.date.compareTo(b.date));

    var soldeCourant = 0;
    final avecSolde = <EvenementTimelineDette>[];

    for (final ev in brute) {
      if (ev.type == TypeEvenementDette.creationDette) {
        soldeCourant += ev.montant;
      } else if (ev.type == TypeEvenementDette.paiementRecu || ev.type == TypeEvenementDette.paiementEmis) {
        soldeCourant = (soldeCourant - ev.montant).clamp(0, 999999999999);
      } else if (ev.type == TypeEvenementDette.annulation) {
        soldeCourant = (soldeCourant - ev.montant).clamp(0, 999999999999);
      }

      avecSolde.add(
        EvenementTimelineDette(
          id: ev.id,
          date: ev.date,
          type: ev.type,
          montant: ev.montant,
          libelle: ev.libelle,
          mode: ev.mode,
          soldeProgressif: soldeCourant,
          engagementId: ev.engagementId,
          paiementId: ev.paiementId,
          reference: ev.reference,
          note: ev.note,
        ),
      );
    }

    // Retourner du plus récent au plus ancien pour l'affichage de l'historique
    return avecSolde.reversed.toList();
  }

  static List<PointEvolutionSolde> _construireEvolutionSolde(List<EvenementTimelineDette> timelineRecente) {
    if (timelineRecente.isEmpty) return const [];

    final chrono = timelineRecente.reversed.toList();
    final points = <PointEvolutionSolde>[];

    for (final ev in chrono) {
      points.add(PointEvolutionSolde(date: ev.date, solde: ev.soldeProgressif));
    }

    return points;
  }
}
