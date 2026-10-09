import '../../../../core/utils/recherche.dart';
import '../../domain/entities/commerce.dart';
import 'recu_vente.dart';

enum PeriodeRecus { aujourdhui, hier, semaine, mois, personnalisee, tout }

/// Filtres de l'écran Reçus. La boutique vient du sélecteur commun.
class FiltreRecus {
  const FiltreRecus({
    this.periode = PeriodeRecus.aujourdhui,
    this.debut,
    this.fin,
    this.texte = '',
    this.vendeur,
    this.paiement,
    this.statut,
  });

  final PeriodeRecus periode;

  /// Période personnalisée (jours inclus).
  final DateTime? debut;
  final DateTime? fin;
  final String texte;
  final String? vendeur;

  /// Code du mode de paiement, ou [credit].
  final String? paiement;
  final StatutRecu? statut;

  static const credit = 'CREDIT';

  bool get actif => vendeur != null || paiement != null || statut != null;

  FiltreRecus copyWith({
    PeriodeRecus? periode,
    DateTime? Function()? debut,
    DateTime? Function()? fin,
    String? texte,
    String? Function()? vendeur,
    String? Function()? paiement,
    StatutRecu? Function()? statut,
  }) =>
      FiltreRecus(
        periode: periode ?? this.periode,
        debut: debut == null ? this.debut : debut(),
        fin: fin == null ? this.fin : fin(),
        texte: texte ?? this.texte,
        vendeur: vendeur == null ? this.vendeur : vendeur(),
        paiement: paiement == null ? this.paiement : paiement(),
        statut: statut == null ? this.statut : statut(),
      );

  /// Bornes [début, fin[ de la période, en heure locale ; `null` = sans borne.
  (DateTime?, DateTime?) bornes(DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    return switch (periode) {
      PeriodeRecus.aujourdhui => (jour, jour.add(const Duration(days: 1))),
      PeriodeRecus.hier => (jour.subtract(const Duration(days: 1)), jour),
      PeriodeRecus.semaine => (jour.subtract(Duration(days: jour.weekday - 1)), jour.add(const Duration(days: 1))),
      PeriodeRecus.mois => (DateTime(jour.year, jour.month), jour.add(const Duration(days: 1))),
      PeriodeRecus.personnalisee => (
          debut == null ? null : DateTime(debut!.year, debut!.month, debut!.day),
          fin == null ? null : DateTime(fin!.year, fin!.month, fin!.day).add(const Duration(days: 1)),
        ),
      PeriodeRecus.tout => (null, null),
    };
  }
}

/// Ce que la recherche sait d'une vente (noms déjà résolus).
class IndexRecu {
  const IndexRecu({required this.vente, required this.statut, this.client, this.telephone, this.boutique = '',
      this.produits = const []});
  final Vente vente;
  final StatutRecu statut;
  final String? client;
  final String? telephone;
  final String boutique;
  final List<String> produits;
}

/// Reçus correspondant aux filtres, du plus récent au plus ancien. La
/// recherche porte sur le numéro, le client, son téléphone, les produits, le
/// vendeur et la boutique.
List<IndexRecu> filtrerRecus(List<IndexRecu> recus, FiltreRecus f, {DateTime? maintenant}) {
  final (debut, fin) = f.bornes(maintenant ?? DateTime.now());
  final mots = normaliserRecherche(f.texte).split(' ').where((m) => m.isNotEmpty).toList();
  final chiffres = chiffresSeuls(f.texte);
  return [
    for (final r in recus)
      if (_dansPeriode(r.vente.date.toLocal(), debut, fin) &&
          (f.vendeur == null || r.vente.auteurNom == f.vendeur) &&
          (f.statut == null || r.statut == f.statut) &&
          (f.paiement == null ||
              (f.paiement == FiltreRecus.credit
                  ? r.vente.reglement == ReglementVente.credit
                  : r.vente.modePaiement == f.paiement)) &&
          (mots.isEmpty || _correspond(r, mots, chiffres)))
        r,
  ]..sort((a, b) => b.vente.date.compareTo(a.vente.date));
}

bool _dansPeriode(DateTime d, DateTime? debut, DateTime? fin) =>
    (debut == null || !d.isBefore(debut)) && (fin == null || d.isBefore(fin));

bool _correspond(IndexRecu r, List<String> mots, String chiffres) {
  // Téléphone tapé avec ou sans espaces.
  if (chiffres.length >= 6 && chiffresSeuls(r.telephone).contains(chiffres)) return true;
  final texte = normaliserRecherche([
    r.vente.numero ?? '',
    r.client ?? '',
    r.telephone ?? '',
    r.vente.auteurNom ?? '',
    r.boutique,
    ...r.produits,
  ].join(' '));
  return mots.every(texte.contains);
}
