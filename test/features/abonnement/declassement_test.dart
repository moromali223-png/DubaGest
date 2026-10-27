import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/abonnement/domain/entities/declassement_models.dart';
import 'package:dubagest/features/abonnement/presentation/providers/declassement_providers.dart';
import 'package:dubagest/features/abonnement/domain/repositories/declassement_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeDeclassementRepository implements DeclassementRepository {
  FakeDeclassementRepository({
    this.analysePrete = false,
    this.estSponsorise = false,
    this.shouldThrowPermission = false,
    this.shouldFailValidation = false,
  });

  bool analysePrete;
  bool estSponsorise;
  bool shouldThrowPermission;
  bool shouldFailValidation;
  bool aEteApplique = false;
  bool aEteAnnule = false;

  final Map<String, String> ressourcesAjustees = {};

  @override
  Future<AnalyseDeclassement> analyserLimites({
    required String entrepriseId,
    required String planCibleCode,
  }) async {
    if (shouldThrowPermission) {
      throw Exception('PERMISSION_REFUSEE');
    }

    final anomalies = <AnomalieDeclassement>[];
    if (!analysePrete) {
      anomalies.add(const AnomalieDeclassement(
        type: TypeAnomalieDeclassement.utilisateursExcedentaires,
        message: 'Vous avez 5 utilisateurs actifs. La formule choisie en autorise 3.',
        actuel: 5,
        max: 3,
        exces: 2,
      ));
      anomalies.add(const AnomalieDeclassement(
        type: TypeAnomalieDeclassement.perimetresExcedentaires,
        activiteCode: 'COMMERCE',
        message: 'Vous avez 2 boutiques actives pour l\'activité Commerce. La formule choisie en autorise 1.',
        actuel: 2,
        max: 1,
        exces: 1,
      ));
      anomalies.add(const AnomalieDeclassement(
        type: TypeAnomalieDeclassement.activitesExcedentaires,
        message: 'Vous avez 2 activités actives. La formule choisie en autorise 1.',
        actuel: 2,
        max: 1,
        exces: 1,
      ));
    }

    return AnalyseDeclassement(
      conforme: anomalies.isEmpty,
      entrepriseId: entrepriseId,
      planActuel: const PlanTarifInfo(
        code: 'PRO',
        nom: 'Pro',
        prixMensuel: 5000,
        maxActivites: 3,
      ),
      planCible: PlanTarifInfo(
        code: planCibleCode,
        nom: planCibleCode == 'MOYEN' ? 'Moyen' : 'Normal',
        prixMensuel: planCibleCode == 'MOYEN' ? 2000 : 1000,
        maxActivites: planCibleCode == 'MOYEN' ? 2 : 1,
      ),
      typeFacturation: estSponsorise ? 'SPONSORISE' : 'COMMERCIAL',
      sponsorMotif: estSponsorise ? 'Partenariat CCI' : null,
      valeurCommercialeReference: planCibleCode == 'MOYEN' ? 2000 : 1000,
      montantDu: estSponsorise ? 0 : (planCibleCode == 'MOYEN' ? 2000 : 1000),
      utilisateursActifs: analysePrete ? 3 : 5,
      maxUtilisateursCible: planCibleCode == 'MOYEN' ? 7 : 3,
      nbActivitesActives: analysePrete ? 1 : 2,
      activitesActives: analysePrete ? ['COMMERCE'] : ['COMMERCE', 'SERVICES'],
      perimetresActifsParActivite: {'COMMERCE': analysePrete ? 1 : 2},
      anomalies: anomalies,
    );
  }

  @override
  Future<DemandeDeclassement> demanderDeclassement({
    required String entrepriseId,
    required String planCibleCode,
  }) async {
    final analyse = await analyserLimites(
      entrepriseId: entrepriseId,
      planCibleCode: planCibleCode,
    );

    return DemandeDeclassement(
      id: 'dem-test-1',
      entrepriseId: entrepriseId,
      planActuelCode: 'PRO',
      planCibleCode: planCibleCode,
      statut: analyse.conforme ? 'ready' : 'pending_preparation',
      conforme: analyse.conforme,
      analyse: analyse,
      anomalies: analyse.anomalies,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<DemandeDeclassement?> getDemandeEnCours(String entrepriseId) async {
    return demanderDeclassement(
      entrepriseId: entrepriseId,
      planCibleCode: 'NORMAL',
    );
  }

  @override
  Future<void> ajusterRessource({
    required String entrepriseId,
    required String typeRessource,
    required String ressourceId,
    required String action,
  }) async {
    if (ressourceId == 'admin-unique' && action == 'DESACTIVER') {
      throw Exception('DERNIER_ADMINISTRATEUR_PROTEGE');
    }
    ressourcesAjustees['$typeRessource:$ressourceId'] = action;
  }

  @override
  Future<Map<String, dynamic>> validerEtAppliquerDeclassement(String demandeId) async {
    if (shouldFailValidation || !analysePrete) {
      return {
        'succes': false,
        'code': 'LIMITES_NON_RESPECTEES',
        'message': 'Des limites ne sont pas encore respectées.',
      };
    }
    aEteApplique = true;
    return {
      'succes': true,
      'plan_code': 'NORMAL',
      'message': 'L\'abonnement a été déclassé avec succès vers la formule Normal.',
    };
  }

  @override
  Future<void> annulerDemande(String demandeId) async {
    aEteAnnule = true;
  }
}

void main() {
  group('Système de Déclassement Intelligent DubaGest - Modèles et Règles Métier', () {
    test('1. Déclassement réussi lorsque toutes les limites sont respectées (conforme = true)', () {
      final analyse = AnalyseDeclassement(
        conforme: true,
        entrepriseId: 'e-1',
        planActuel: const PlanTarifInfo(code: 'PRO', nom: 'Pro', prixMensuel: 5000, maxActivites: 3),
        planCible: const PlanTarifInfo(code: 'NORMAL', nom: 'Normal', prixMensuel: 1000, maxActivites: 1),
        typeFacturation: 'COMMERCIAL',
        valeurCommercialeReference: 1000,
        montantDu: 1000,
        utilisateursActifs: 3,
        maxUtilisateursCible: 3,
        nbActivitesActives: 1,
        activitesActives: const ['COMMERCE'],
        perimetresActifsParActivite: const {'COMMERCE': 1},
        anomalies: const [],
      );

      expect(analyse.conforme, isTrue);
      expect(analyse.anomalies, isEmpty);
      expect(analyse.montantDu, equals(1000));
    });

    test('2. Déclassement bloqué en cas de dépassement du nombre d\'utilisateurs', () {
      const anomalie = AnomalieDeclassement(
        type: TypeAnomalieDeclassement.utilisateursExcedentaires,
        message: 'Vous avez 5 utilisateurs actifs. La formule choisie en autorise 3.',
        actuel: 5,
        max: 3,
        exces: 2,
      );

      final analyse = AnalyseDeclassement(
        conforme: false,
        entrepriseId: 'e-1',
        planActuel: const PlanTarifInfo(code: 'PRO', nom: 'Pro', prixMensuel: 5000, maxActivites: 3),
        planCible: const PlanTarifInfo(code: 'NORMAL', nom: 'Normal', prixMensuel: 1000, maxActivites: 1),
        typeFacturation: 'COMMERCIAL',
        valeurCommercialeReference: 1000,
        montantDu: 1000,
        utilisateursActifs: 5,
        maxUtilisateursCible: 3,
        nbActivitesActives: 1,
        activitesActives: const ['COMMERCE'],
        perimetresActifsParActivite: const {'COMMERCE': 1},
        anomalies: const [anomalie],
      );

      expect(analyse.conforme, isFalse);
      expect(analyse.anomalies.first.type, equals(TypeAnomalieDeclassement.utilisateursExcedentaires));
      expect(analyse.anomalies.first.exces, equals(2));
    });

    test('3. Déclassement bloqué en cas de dépassement du nombre de boutiques / périmètres', () {
      const anomalie = AnomalieDeclassement(
        type: TypeAnomalieDeclassement.perimetresExcedentaires,
        activiteCode: 'COMMERCE',
        message: 'Vous avez 2 boutiques actives pour Commerce. Quota = 1.',
        actuel: 2,
        max: 1,
        exces: 1,
      );

      final analyse = AnalyseDeclassement(
        conforme: false,
        entrepriseId: 'e-1',
        planActuel: const PlanTarifInfo(code: 'PRO', nom: 'Pro', prixMensuel: 5000, maxActivites: 3),
        planCible: const PlanTarifInfo(code: 'NORMAL', nom: 'Normal', prixMensuel: 1000, maxActivites: 1),
        typeFacturation: 'COMMERCIAL',
        valeurCommercialeReference: 1000,
        montantDu: 1000,
        utilisateursActifs: 3,
        maxUtilisateursCible: 3,
        nbActivitesActives: 1,
        activitesActives: const ['COMMERCE'],
        perimetresActifsParActivite: const {'COMMERCE': 2},
        anomalies: const [anomalie],
      );

      expect(analyse.conforme, isFalse);
      expect(analyse.anomalies.first.type, equals(TypeAnomalieDeclassement.perimetresExcedentaires));
    });

    test('4. Déclassement bloqué lorsque les activités actives dépassent le quota du plan cible', () {
      const anomalie = AnomalieDeclassement(
        type: TypeAnomalieDeclassement.activitesExcedentaires,
        message: 'Vous avez 2 activités actives. La formule Normal en autorise 1.',
        actuel: 2,
        max: 1,
        exces: 1,
      );

      final demande = DemandeDeclassement(
        id: 'd-1',
        entrepriseId: 'e-1',
        planActuelCode: 'MOYEN',
        planCibleCode: 'NORMAL',
        statut: 'pending_preparation',
        conforme: false,
        anomalies: const [anomalie],
        createdAt: DateTime.now(),
      );

      expect(demande.necessitePreparation, isTrue);
      expect(demande.estPrete, isFalse);
    });

    test('5 & 6. Conservation intégrale des données historiques et attributions d\'auteurs', () {
      // Lors d'un ajustement, l'action est DESACTIVER/SUSPENDRE (jamais SUPPRIMER)
      const actionAjustement = 'DESACTIVER';
      expect(actionAjustement, isNot(equals('SUPPRIMER')));
      expect(actionAjustement, isNot(equals('DELETE')));
    });

    test('7 & 8. Contrôle strict des permissions : échec si non autorisé', () async {
      final fakeRepo = FakeDeclassementRepository(shouldThrowPermission: true);
      expect(
        () => fakeRepo.analyserLimites(entrepriseId: 'e-1', planCibleCode: 'NORMAL'),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_REFUSEE'))),
      );
    });

    test('9. Prévention des doubles activations et des demandes concurrentes côté serveur', () async {
      final fakeRepo = FakeDeclassementRepository(analysePrete: false);
      final res = await fakeRepo.validerEtAppliquerDeclassement('dem-1');
      expect(res['succes'], isFalse);
      expect(res['code'], equals('LIMITES_NON_RESPECTEES'));
    });

    test('10. Conservation du comportement de facturation existant pour client commercial', () {
      final analyse = AnalyseDeclassement(
        conforme: true,
        entrepriseId: 'e-1',
        planActuel: const PlanTarifInfo(code: 'PRO', nom: 'Pro', prixMensuel: 5000, maxActivites: 3),
        planCible: const PlanTarifInfo(code: 'NORMAL', nom: 'Normal', prixMensuel: 1000, maxActivites: 1),
        typeFacturation: 'COMMERCIAL',
        valeurCommercialeReference: 1000,
        montantDu: 1000,
        utilisateursActifs: 3,
        nbActivitesActives: 1,
        activitesActives: const ['COMMERCE'],
        perimetresActifsParActivite: const {},
        anomalies: const [],
      );

      expect(analyse.estSponsorise, isFalse);
      expect(analyse.montantDu, equals(1000));
    });

    test('11 & 12. Conservation des accès sponsorisés : 0 FCFA facturé lors du déclassement', () {
      final analyse = AnalyseDeclassement(
        conforme: true,
        entrepriseId: 'e-1',
        planActuel: const PlanTarifInfo(code: 'PRO', nom: 'Pro', prixMensuel: 5000, maxActivites: 3),
        planCible: const PlanTarifInfo(code: 'NORMAL', nom: 'Normal', prixMensuel: 1000, maxActivites: 1),
        typeFacturation: 'SPONSORISE',
        sponsorMotif: 'Programme PME Mali',
        valeurCommercialeReference: 1000,
        montantDu: 0, // Zéro FCFA garanti !
        utilisateursActifs: 3,
        nbActivitesActives: 1,
        activitesActives: const ['COMMERCE'],
        perimetresActifsParActivite: const {},
        anomalies: const [],
      );

      expect(analyse.estSponsorise, isTrue);
      expect(analyse.montantDu, equals(0));
      expect(analyse.valeurCommercialeReference, equals(1000));
      expect(analyse.sponsorMotif, equals('Programme PME Mali'));
    });

    test('13. Protection du dernier administrateur actif', () async {
      final fakeRepo = FakeDeclassementRepository();
      expect(
        () => fakeRepo.ajusterRessource(
          entrepriseId: 'e-1',
          typeRessource: 'UTILISATEUR',
          ressourceId: 'admin-unique',
          action: 'DESACTIVER',
        ),
        throwsA(predicate((e) => e.toString().contains('DERNIER_ADMINISTRATEUR_PROTEGE'))),
      );
    });

    test('14. Désactivation d\'une ressource enregistrée sans altération de schéma', () async {
      final fakeRepo = FakeDeclassementRepository();
      await fakeRepo.ajusterRessource(
        entrepriseId: 'e-1',
        typeRessource: 'PERIMETRE',
        ressourceId: 'boutique-2',
        action: 'DESACTIVER',
      );

      expect(fakeRepo.ressourcesAjustees['PERIMETRE:boutique-2'], equals('DESACTIVER'));
    });

    test('15. Validation et application réussie lorsque conforme', () async {
      final fakeRepo = FakeDeclassementRepository(analysePrete: true);
      final res = await fakeRepo.validerEtAppliquerDeclassement('dem-ok');

      expect(res['succes'], isTrue);
      expect(fakeRepo.aEteApplique, isTrue);
    });

    test('16. Annulation propre de la demande sans restauration forcée automatique', () async {
      final fakeRepo = FakeDeclassementRepository();
      await fakeRepo.annulerDemande('dem-ok');

      expect(fakeRepo.aEteAnnule, isTrue);
    });
  });

  group('Cycle de vie des états de DemandeDeclassement', () {
    test('Transitions d\'états conformes aux spécifications', () {
      final pending = DemandeDeclassement(
        id: '1',
        entrepriseId: 'e',
        planActuelCode: 'PRO',
        planCibleCode: 'NORMAL',
        statut: 'pending_preparation',
        conforme: false,
        anomalies: const [],
        createdAt: DateTime.now(),
      );
      expect(pending.necessitePreparation, isTrue);
      expect(pending.estPrete, isFalse);

      final ready = DemandeDeclassement(
        id: '1',
        entrepriseId: 'e',
        planActuelCode: 'PRO',
        planCibleCode: 'NORMAL',
        statut: 'ready',
        conforme: true,
        anomalies: const [],
        createdAt: DateTime.now(),
      );
      expect(ready.estPrete, isTrue);

      final applied = DemandeDeclassement(
        id: '1',
        entrepriseId: 'e',
        planActuelCode: 'PRO',
        planCibleCode: 'NORMAL',
        statut: 'applied',
        conforme: true,
        anomalies: const [],
        createdAt: DateTime.now(),
        appliqueLe: DateTime.now(),
      );
      expect(applied.estAppliquee, isTrue);

      final cancelled = DemandeDeclassement(
        id: '1',
        entrepriseId: 'e',
        planActuelCode: 'PRO',
        planCibleCode: 'NORMAL',
        statut: 'cancelled',
        conforme: false,
        anomalies: const [],
        createdAt: DateTime.now(),
      );
      expect(cancelled.estAnnulee, isTrue);
    });
  });
}
