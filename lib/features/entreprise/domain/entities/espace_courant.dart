import '../../../activites/domain/entities/activite.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import 'contexte_session.dart';

/// Contexte de travail choisi : activité (ou vue globale) et site (ou tous).
/// Il filtre l'affichage ; la sécurité reste assurée par la RLS.
class EspaceCourant {
  const EspaceCourant({this.activite, this.perimetreId});

  /// `null` = vue globale (plusieurs activités).
  final ActiviteCode? activite;

  /// `null` = tous les sites autorisés.
  final String? perimetreId;

  static const global = EspaceCourant();

  /// Rend un choix valide pour ce contexte (activité encore active, site
  /// encore autorisé) et applique les choix par défaut :
  /// - une seule activité → elle ; sinon vue globale ;
  /// - un seul site autorisé pour l'activité → lui ; sinon tous.
  static EspaceCourant resoudre(ContexteSession ctx, EspaceCourant? souhaite) {
    final actives = [for (final a in ctx.activites) if (a.estActive) a.activite];
    ActiviteCode? activite = souhaite?.activite;
    if (activite != null && !actives.contains(activite)) activite = null;
    if (actives.length == 1) activite = actives.single;

    final sites = sitesPour(ctx, activite);
    String? site = souhaite?.perimetreId;
    if (site != null && !sites.any((p) => p.id == site)) site = null;
    if (sites.length == 1) site = sites.single.id;
    return EspaceCourant(activite: activite, perimetreId: site);
  }

  /// Sites autorisés (actifs) pour une activité, ou pour toutes.
  static List<Perimetre> sitesPour(ContexteSession ctx, ActiviteCode? activite) => [
        for (final p in ctx.perimetres)
          if (p.estActif && (activite == null || p.activite == activite)) p,
      ];

  String encoder() => '${activite?.code ?? ''}|${perimetreId ?? ''}';

  static EspaceCourant? decoder(String? brut) {
    if (brut == null || !brut.contains('|')) return null;
    final [a, p] = brut.split('|');
    return EspaceCourant(
      activite: ActiviteCode.tryParse(a.isEmpty ? null : a),
      perimetreId: p.isEmpty ? null : p,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EspaceCourant && other.activite == activite && other.perimetreId == perimetreId;

  @override
  int get hashCode => Object.hash(activite, perimetreId);
}
