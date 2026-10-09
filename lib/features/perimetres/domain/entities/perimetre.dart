import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';

/// Nature du périmètre opérationnel selon l'activité.
enum PerimetreType {
  boutique('BOUTIQUE'),
  agence('AGENCE'),
  site('SITE'),
  unite('UNITE');

  const PerimetreType(this.code);
  final String code;

  static PerimetreType parse(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => PerimetreType.site);
}

/// Périmètre opérationnel : boutique (Commerce), agence/site (Services)…
class Perimetre {
  const Perimetre({
    required this.id,
    required this.entrepriseId,
    required this.activite,
    required this.type,
    required this.nom,
    this.code,
    this.estActif = true,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final ActiviteCode activite;
  final PerimetreType type;
  final String nom;
  final String? code;
  final bool estActif;

  /// Version serveur connue ; `null` tant que la création n'est pas synchronisée.
  final int? version;
  final RecordSyncStatus syncStatus;
}
