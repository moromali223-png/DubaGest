import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/domain/entities/espace_courant.dart';
import '../entities/perimetre.dart';

/// Service de nommage séquentiel et de gestion conceptuelle des Boutiques / Périmètres.
/// Règle d'or DUBAGEST :
/// - Une boutique = un point physique réel (Boutique A, Boutique B, etc.).
/// - « Toutes les boutiques » = une VUE CONSOLIDÉE, jamais une vraie boutique en base de données.
abstract final class BoutiquesNamingService {
  static const List<String> _lettres = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  /// Génère le nom par défaut selon l'index de la boutique :
  /// Index 0 -> "Boutique A", Index 1 -> "Boutique B", Index 2 -> "Boutique C", etc.
  static String nomParDefaut(int index, {PerimetreType type = PerimetreType.boutique}) {
    final prefixe = switch (type) {
      PerimetreType.boutique => 'Boutique',
      PerimetreType.agence => 'Agence',
      PerimetreType.site => 'Site',
      PerimetreType.unite => 'Unité',
    };

    final lettre = lettreBoutique(index);
    return '$prefixe $lettre';
  }

  /// Génère la lettre associée à l'index (0 -> A, 1 -> B, ..., 26 -> AA).
  static String lettreBoutique(int index) {
    if (index < 0) return 'A';
    if (index < _lettres.length) {
      return _lettres[index];
    }
    final premier = _lettres[(index ~/ _lettres.length) - 1];
    final second = _lettres[index % _lettres.length];
    return '$premier$second';
  }

  /// Génère un code technique interne stable par défaut (ex: SHOP-001, SHOP-002).
  static String codeParDefaut(int index, {PerimetreType type = PerimetreType.boutique}) {
    final prefixe = switch (type) {
      PerimetreType.boutique => 'SHOP',
      PerimetreType.agence => 'AGC',
      PerimetreType.site => 'SITE',
      PerimetreType.unite => 'UNT',
    };
    final numero = (index + 1).toString().padLeft(3, '0');
    return '$prefixe-$numero';
  }

  /// Suggère le prochain nom et code par défaut en fonction de la liste des périmètres existants.
  static ({String nom, String code}) suggestionSuivante(
    List<Perimetre> existants, {
    ActiviteCode? activite,
    PerimetreType type = PerimetreType.boutique,
  }) {
    final memeActivite = existants.where((p) => activite == null || p.activite == activite).toList();
    final index = memeActivite.length;
    return (
      nom: nomParDefaut(index, type: type),
      code: codeParDefaut(index, type: type),
    );
  }

  /// Indique si un espace correspond à la Vue Consolidée (« Toutes les boutiques »).
  static bool estVueConsolidee(EspaceCourant espace) => espace.perimetreId == null;

  /// Libellé d'affichage propre du périmètre ou de la vue consolidée.
  static String libelleBoutique({
    required ContexteSession? ctx,
    required String? perimetreId,
  }) {
    if (perimetreId == null) {
      return 'Toutes les boutiques';
    }
    final perimetre = ctx?.perimetres.where((p) => p.id == perimetreId).firstOrNull;
    return perimetre?.nom ?? 'Boutique';
  }

  /// Sous-titre informatif (ex: "Vue consolidée", "SHOP-001").
  static String sousTitreBoutique({
    required ContexteSession? ctx,
    required String? perimetreId,
  }) {
    if (perimetreId == null) {
      final nbActives = ctx?.perimetres.where((p) => p.estActif).length ?? 0;
      return 'Vue consolidée · $nbActives boutique${nbActives > 1 ? 's' : ''}';
    }
    final perimetre = ctx?.perimetres.where((p) => p.id == perimetreId).firstOrNull;
    if (perimetre == null) return '';
    final code = perimetre.code;
    return code != null ? 'Code : $code' : 'Boutique active';
  }
}
