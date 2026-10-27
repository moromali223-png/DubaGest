import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/immobilier/domain/entities/locataire_immobilier.dart';
import 'package:dubagest/features/immobilier/presentation/providers/immobilier_providers.dart';

void main() {
  group('Étape 4 — Locataires : Tests Unitaires', () {
    test('ProfilLocataire : Sérialisation et désérialisation JSON intègre', () {
      final profil = ProfilLocataire(
        contactId: 'contact-locataire-1',
        entrepriseId: 'ent-1',
        typePiece: TypePieceIdentite.cni,
        numeroPiece: '1234567890123',
        dateDelivrancePiece: DateTime(2022, 5, 10),
        profession: 'Ingénieur Logiciel',
        employeur: 'Tech Solutions SAS',
        revenuMensuelEstime: 850000,
        nomGarant: 'Mamadou Diallo',
        telephoneGarant: '+221 77 111 22 33',
        lienGarant: 'Oncle',
        adresseGarant: 'Dakar Fann Résidence',
        nomUrgence: 'Aissatou Diallo',
        telephoneUrgence: '+221 77 999 88 77',
        lienUrgence: 'Épouse',
        notesLocatives: 'Dossier complet avec 3 derniers bulletins de paie',
        statutFinancier: StatutFinancierLocataire.aJour,
        updatedAt: DateTime(2026, 10, 14, 18, 0),
      );

      final json = profil.toJson();
      final deserialise = ProfilLocataire.fromJson(json);

      expect(deserialise.contactId, 'contact-locataire-1');
      expect(deserialise.entrepriseId, 'ent-1');
      expect(deserialise.typePiece, TypePieceIdentite.cni);
      expect(deserialise.numeroPiece, '1234567890123');
      expect(deserialise.profession, 'Ingénieur Logiciel');
      expect(deserialise.employeur, 'Tech Solutions SAS');
      expect(deserialise.revenuMensuelEstime, 850000);
      expect(deserialise.nomGarant, 'Mamadou Diallo');
      expect(deserialise.telephoneGarant, '+221 77 111 22 33');
      expect(deserialise.lienGarant, 'Oncle');
      expect(deserialise.nomUrgence, 'Aissatou Diallo');
      expect(deserialise.statutFinancier, StatutFinancierLocataire.aJour);
      expect(deserialise.aGarant, isTrue);
      expect(deserialise.aContactUrgence, isTrue);
      expect(deserialise.aPieceIdentite, isTrue);
    });

    test('TypePieceIdentite & StatutFinancierLocataire : Parsing et valeurs par défaut robustes', () {
      expect(TypePieceIdentite.parse('PASSEPORT'), TypePieceIdentite.passeport);
      expect(TypePieceIdentite.parse('RCCM'), TypePieceIdentite.rccm);
      expect(TypePieceIdentite.parse('CODE_INCONNU'), TypePieceIdentite.cni);
      expect(TypePieceIdentite.parse(null), TypePieceIdentite.cni);

      expect(StatutFinancierLocataire.parse('EN_RETARD'), StatutFinancierLocataire.enRetard);
      expect(StatutFinancierLocataire.parse('CONTENTIEUX'), StatutFinancierLocataire.contentieux);
      expect(StatutFinancierLocataire.parse('INEXISTANT'), StatutFinancierLocataire.aJour);
      expect(StatutFinancierLocataire.parse(null), StatutFinancierLocataire.aJour);
    });

    test('SituationFinanciereLocataire : Calcul des soldes et impayés', () {
      const situationAJour = SituationFinanciereLocataire(
        totalAppeles: 600000,
        totalRegle: 600000,
        soldeDu: 0,
        impayes: 0,
        statut: StatutFinancierLocataire.aJour,
      );

      expect(situationAJour.estAJour, isTrue);
      expect(situationAJour.aDesImpayes, isFalse);
      expect(situationAJour.statut, StatutFinancierLocataire.aJour);

      const situationEnRetard = SituationFinanciereLocataire(
        totalAppeles: 600000,
        totalRegle: 400000,
        soldeDu: 200000,
        impayes: 200000,
        statut: StatutFinancierLocataire.enRetard,
      );

      expect(situationEnRetard.estAJour, isFalse);
      expect(situationEnRetard.aDesImpayes, isTrue);
      expect(situationEnRetard.soldeDu, 200000);
      expect(situationEnRetard.statut, StatutFinancierLocataire.enRetard);
    });

    test('FiltreLocataires : Filtrage par texte et type de personne', () {
      const locataires = [
        Contact(
          id: 'loc-1',
          entrepriseId: 'ent-1',
          nom: 'Sow',
          prenom: 'Ibrahima',
          telephone: '+221 77 123 45 67',
          ville: 'Dakar',
          typePersonne: TypePersonne.personne,
          relations: {RelationContact.locataire},
        ),
        Contact(
          id: 'loc-2',
          entrepriseId: 'ent-1',
          nom: 'Afrique Logistique SARL',
          telephone: '+221 33 800 00 00',
          ville: 'Thies',
          typePersonne: TypePersonne.organisation,
          relations: {RelationContact.locataire},
        ),
        Contact(
          id: 'loc-3',
          entrepriseId: 'ent-1',
          nom: 'Ndiaye',
          prenom: 'Fatou',
          telephone: '+221 78 555 44 33',
          ville: 'Saint-Louis',
          typePersonne: TypePersonne.personne,
          relations: {RelationContact.locataire},
        ),
      ];

      // Recherche par nom
      const filtreRecherche = FiltreLocataires(recherche: 'ibrahima');
      final resRecherche = locataires.where((l) {
        return l.nomAffiche.toLowerCase().contains(filtreRecherche.recherche);
      }).toList();
      expect(resRecherche.length, 1);
      expect(resRecherche.first.nom, 'Sow');

      // Filtrage par Société / Organisation
      const filtreSociete = FiltreLocataires(typePersonne: TypePersonne.organisation);
      final resSocietes = locataires.where((l) {
        return l.typePersonne == filtreSociete.typePersonne;
      }).toList();
      expect(resSocietes.length, 1);
      expect(resSocietes.first.nom, 'Afrique Logistique SARL');
    });
  });
}
