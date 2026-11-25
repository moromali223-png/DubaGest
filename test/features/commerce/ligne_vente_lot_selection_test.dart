import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/commerce/domain/entities/commerce.dart';

void main() {
  group('Sélection de lot et prix de vente', () {
    test('LigneOperation conserve le lotId choisi', () {
      final ligne = LigneOperation(
        id: 'l1',
        produitId: 'p1',
        unite: 'Kg',
        facteur: Qte.un,
        quantite: Qte.depuis(5),
        prixUnitaire: 500,
        lotId: 'lot-abc-123',
      );

      expect(ligne.lotId, equals('lot-abc-123'));
      expect(ligne.prixUnitaire, equals(500));
      expect(ligne.quantite.valeur, equals(5.0));

      final json = ligne.toJson();
      expect(json['lot_id'], equals('lot-abc-123'));

      final reconstruit = LigneOperation.fromJson(json);
      expect(reconstruit.lotId, equals('lot-abc-123'));
    });
  });
}
