import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/documents/domain/entities/document.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/recherche/domain/recherche_globale.dart';
import 'package:dubagest/features/tableau_de_bord/domain/tableau_de_bord.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';

void main() {
  final maintenant = DateTime(2026, 10, 5, 15);
  Paiement p(String id, int montant, DateTime date,
          {SensPaiement sens = SensPaiement.entree, ActiviteCode? activite, String? site, String? contact,
          String? annule, RecordSyncStatus s = RecordSyncStatus.synced, String? reference}) =>
      Paiement(
        id: id, entrepriseId: entrepriseId, sens: sens, montant: montant, mode: ModePaiement.especes,
        datePaiement: date, activite: activite, perimetreId: site, contactId: contact, annulePaiementId: annule,
        syncStatus: s, reference: reference,
      );
  Engagement dette(String id, int total, {String? contact, DateTime? echeance, ActiviteCode? activite}) => Engagement(
        id: id, entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit $id',
        montantTotal: total, dateEngagement: DateTime(2026, 9, 1), echeance: echeance, contactId: contact,
        activite: activite,
      );
  Depense dep(String id, String cat, int montant, DateTime date) => Depense(
        id: id, entrepriseId: entrepriseId, categorieId: cat, libelle: 'Dépense $id', montant: montant,
        dateDepense: date, payeeImmediatement: true,
      );

  group('tableau de bord', () {
    final etat = EtatFinances(
      paiements: [
        p('p1', 20000, DateTime(2026, 10, 5, 9)),
        p('p2', 5000, DateTime(2026, 10, 3, 9), sens: SensPaiement.sortie),
        p('p3', 9000, DateTime(2026, 9, 1, 9)), // hors 7 jours
        p('p4', 7000, DateTime(2026, 10, 4, 9)),
        p('x4', 7000, DateTime(2026, 10, 5, 10), sens: SensPaiement.sortie, annule: 'p4'), // annulation
        p('r', 99999, DateTime(2026, 10, 5, 9), s: RecordSyncStatus.syncError), // refusé
      ],
      categories: const [
        CategorieDepense(id: 'k-t', entrepriseId: entrepriseId, code: 'TRANSPORT'),
        CategorieDepense(id: 'k-l', entrepriseId: entrepriseId, code: 'LOYER'),
        CategorieDepense(id: 'k-a', entrepriseId: entrepriseId, code: 'AUTRE'),
      ],
      depenses: [
        dep('d1', 'k-t', 3000, DateTime(2026, 10, 2)),
        dep('d2', 'k-l', 50000, DateTime(2026, 10, 1)),
        dep('d3', 'k-a', 1000, DateTime(2026, 10, 5)),
        dep('d4', 'k-t', 2000, DateTime(2026, 10, 4)),
      ],
      engagements: [
        dette('e1', 10000, contact: 'c-1', echeance: DateTime(2026, 9, 20)),
        dette('e2', 30000, contact: 'c-2'),
        dette('e3', 5000, contact: 'c-1'),
      ],
    );

    test('7 jours : encaissé, versé, net hors annulations et refus ; un point par jour', () {
      final t = TableauDeBord.calculer(etat, periode: PeriodeTableau.septJours, maintenant: maintenant);
      expect((t.debut, t.fin), (DateTime(2026, 9, 29), DateTime(2026, 10, 5)));
      expect(t.jours, hasLength(7));
      expect((t.encaisse, t.verse, t.net), (20000, 5000, 15000));
      expect(t.jours.last.entrees, 20000);
      expect(t.jours.firstWhere((j) => j.jour == DateTime(2026, 10, 3)).sorties, 5000);
    });

    test('dépenses par catégorie : triées, regroupement au-delà du maximum', () {
      final t = TableauDeBord.calculer(etat,
          periode: PeriodeTableau.moisEnCours, maintenant: maintenant, categoriesMax: 2);
      expect(t.depenses, 56000);
      expect(t.parCategorie.map((x) => (x.categorie?.code, x.montant)),
          [('LOYER', 50000), ('TRANSPORT', 5000), (null, 1000)]);
    });

    test('débiteurs : regroupés par contact, en retard signalé, du plus gros au plus petit', () {
      final t = TableauDeBord.calculer(etat, periode: PeriodeTableau.septJours, maintenant: maintenant);
      expect(t.debiteurs.map((d) => (d.contactId, d.montant, d.enRetard)), [('c-2', 30000, false), ('c-1', 15000, true)]);
    });

    test('espace de travail : une activité, ou un site ; le niveau entreprise reste dans la vue globale', () {
      final mixte = EtatFinances(
        paiements: [
          p('c', 100, maintenant, activite: ActiviteCode.commerce, site: 'b1'),
          p('s', 200, maintenant, activite: ActiviteCode.services, site: 'a1'),
          p('e', 400, maintenant),
        ],
        caisses: const [
          Caisse(id: 'k1', entrepriseId: entrepriseId, perimetreId: 'b1', nom: 'B1'),
          Caisse(id: 'k2', entrepriseId: entrepriseId, perimetreId: 'a1', nom: 'A1'),
        ],
      );
      const sites = {'b1': ActiviteCode.commerce, 'a1': ActiviteCode.services};
      int encaisse(EtatFinances e) =>
          TableauDeBord.calculer(e, periode: PeriodeTableau.septJours, maintenant: maintenant).encaisse;
      expect(encaisse(mixte), 700);
      final commerce = mixte.restreint(activite: ActiviteCode.commerce, activiteDesSites: sites);
      expect(encaisse(commerce), 100);
      expect(commerce.caisses.map((c) => c.id), ['k1']);
      expect(encaisse(mixte.restreint(perimetreId: 'a1', activiteDesSites: sites)), 200);
    });
  });

  group('recherche globale', () {
    final contacts = [
      const Contact(id: 'c-1', entrepriseId: entrepriseId, nom: 'Traoré', prenom: 'Amadou', telephone: '+223 70 11 22 33'),
      const Contact(id: 'c-2', entrepriseId: entrepriseId, nom: 'محمد', prenom: 'أحمد'),
    ];
    final finances = EtatFinances(
      engagements: [dette('e1', 50000, contact: 'c-1')],
      paiements: [p('p1', 20000, maintenant, contact: 'c-1', reference: 'OM-778899')],
      depenses: [dep('d1', 'k', 3500, maintenant)],
    );
    final documents = [
      Document(
        id: 'doc', entrepriseId: entrepriseId, type: TypeDocument.recu, numero: 'REC-2026-00051', blocId: 'b',
        sequence: 51, langue: 'fr', date: maintenant, montant: 20000, origineType: 'PAIEMENT',
        contenu: const {'contact': {'nom': 'Amadou Traoré'}},
      ),
    ];
    final echeances = [
      Echeance(id: 'ech', entrepriseId: entrepriseId, type: TypeEcheance.relance, titre: 'Relancer Amadou',
          dateHeure: maintenant),
    ];

    ResultatsRecherche chercher(String texte, {bool toutVoir = true}) => RechercheGlobale.chercher(
          texte,
          contacts: contacts,
          finances: finances,
          sommesDues: toutVoir,
          paiements: toutVoir,
          depenses: toutVoir,
          documents: documents,
          echeances: echeances,
        );

    test('un nom trouve le contact, ses sommes dues, paiements, reçus et relances', () {
      final r = chercher('traore');
      expect(r.contacts.single.contact.id, 'c-1');
      expect(r.sommesDues.single.suivi.engagement.id, 'e1');
      expect(r.paiements.single.paiement.id, 'p1');
      expect(r.documents.single.document.numero, 'REC-2026-00051');
      expect(r.echeances, isEmpty, reason: '« traore » n\'est pas dans « Relancer Amadou »');
      expect(chercher('amadou').echeances.single.echeance.id, 'ech');
    });

    test('téléphone, montant, numéro de reçu, référence ; arabe sans variantes d\'alef', () {
      expect(chercher('70112233').contacts.single.contact.id, 'c-1');
      expect(chercher('20 000').paiements.single.paiement.id, 'p1');
      expect(chercher('00051').documents, hasLength(1));
      expect(chercher('OM-778899').paiements, hasLength(1));
      expect(chercher('3500').depenses.single.depense.id, 'd1');
      expect(chercher('احمد').contacts.single.contact.id, 'c-2');
    });

    test('sans droit financier : ni sommes dues, ni paiements, ni dépenses', () {
      final r = chercher('traore', toutVoir: false);
      expect(r.sommesDues, isEmpty);
      expect(r.paiements, isEmpty);
      expect(r.depenses, isEmpty);
      expect(r.contacts, hasLength(1));
    });

    test('texte trop court ou vide : aucun résultat', () {
      expect(chercher('  ').vide, isTrue);
    });
  });
}
