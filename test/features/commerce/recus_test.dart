import 'package:dubagest/features/commerce/domain/entities/commerce.dart';
import 'package:dubagest/features/commerce/presentation/recus/filtre_recus.dart';
import 'package:dubagest/features/commerce/presentation/recus/recu_vente.dart';
import 'package:flutter_test/flutter_test.dart';

Vente _vente(String id, DateTime date, {String? numero, String? mode = 'ESPECES', String? vendeur,
        ReglementVente reglement = ReglementVente.immediat, int total = 1000, bool annulee = false,
        int montantPaye = 1000}) =>
    Vente(
      id: id,
      entrepriseId: 'e',
      perimetreId: 'b',
      lignes: const [],
      date: date,
      numero: numero,
      modePaiement: mode,
      auteurNom: vendeur,
      reglement: reglement,
      total: total,
      annulee: annulee,
      montantPaye: montantPaye,
    );

void main() {
  test('numéro du reçu : REC-AAAAMMJJ-POSTE + 3 chiffres', () {
    expect(numeroRecu('2026-10-07', 'A', 1), 'REC-20261007-A001');
    expect(numeroRecu('2026-10-07', 'AB', 24), 'REC-20261007-AB024');
    expect(numeroRecu('2026-10-08', 'A', 1234), 'REC-20261008-A1234');
    expect(jourCommercial(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });

  test('statut : payé, partiellement payé, à crédit, annulé', () {
    final credit = _vente('c', DateTime(2026), reglement: ReglementVente.credit, montantPaye: 0);
    expect(statutRecu(_vente('p', DateTime(2026)), 0), StatutRecu.paye);
    expect(statutRecu(credit, 1000), StatutRecu.credit);
    expect(statutRecu(credit, 400), StatutRecu.partiel);
    expect(statutRecu(_vente('a', DateTime(2026), annulee: true), 0), StatutRecu.annule);
  });

  group('filtres et recherche', () {
    final maintenant = DateTime(2026, 10, 7, 15);
    final recus = [
      IndexRecu(
        vente: _vente('1', DateTime(2026, 10, 7, 14, 36), numero: 'REC-20261007-A024', vendeur: 'Ibrahim'),
        statut: StatutRecu.paye,
        client: 'Mamadou Traoré',
        telephone: '+223 70 11 22 33',
        boutique: 'Boutique A',
        produits: const ['Carreau 40×40', 'Ciment'],
      ),
      IndexRecu(
        vente: _vente('2', DateTime(2026, 10, 7, 14, 21), numero: 'REC-20261007-A023', vendeur: 'Awa',
            mode: 'MOBILE_MONEY'),
        statut: StatutRecu.paye,
        boutique: 'Kalaban Coro',
      ),
      IndexRecu(
        vente: _vente('3', DateTime(2026, 10, 6, 10), numero: 'REC-20261006-B001', vendeur: 'Ibrahim',
            reglement: ReglementVente.credit, mode: null, montantPaye: 0),
        statut: StatutRecu.credit,
        client: 'Fatoumata Coulibaly',
        boutique: 'Boutique A',
      ),
    ];
    List<String> ids(FiltreRecus f) => [for (final r in filtrerRecus(recus, f, maintenant: maintenant)) r.vente.id];

    test('périodes : aujourd\'hui, hier, tout ; plus récent en premier', () {
      expect(ids(const FiltreRecus()), ['1', '2']);
      expect(ids(const FiltreRecus(periode: PeriodeRecus.hier)), ['3']);
      expect(ids(const FiltreRecus(periode: PeriodeRecus.tout)), ['1', '2', '3']);
      expect(
          ids(FiltreRecus(periode: PeriodeRecus.personnalisee, debut: DateTime(2026, 10, 6), fin: DateTime(2026, 10, 6))),
          ['3']);
    });

    test('recherche : numéro, client (sans accents), téléphone, produit, vendeur, boutique', () {
      const tout = FiltreRecus(periode: PeriodeRecus.tout);
      expect(ids(tout.copyWith(texte: 'REC-20261007-A024')), ['1']);
      expect(ids(tout.copyWith(texte: 'mamadou traore')), ['1']);
      expect(ids(tout.copyWith(texte: '70112233')), ['1']);
      expect(ids(tout.copyWith(texte: 'ciment')), ['1']);
      expect(ids(tout.copyWith(texte: 'ibrahim')), ['1', '3']);
      expect(ids(tout.copyWith(texte: 'kalaban')), ['2']);
      expect(ids(tout.copyWith(texte: 'inconnu')), isEmpty);
    });

    test('vendeur, paiement, crédit, statut', () {
      const tout = FiltreRecus(periode: PeriodeRecus.tout);
      expect(ids(tout.copyWith(vendeur: () => 'Awa')), ['2']);
      expect(ids(tout.copyWith(paiement: () => 'MOBILE_MONEY')), ['2']);
      expect(ids(tout.copyWith(paiement: () => FiltreRecus.credit)), ['3']);
      expect(ids(tout.copyWith(statut: () => StatutRecu.credit)), ['3']);
    });
  });
}
