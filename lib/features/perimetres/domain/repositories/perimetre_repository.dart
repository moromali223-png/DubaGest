import '../../../activites/domain/entities/activite.dart';
import '../entities/perimetre.dart';

/// Les écritures sont locales d'abord, puis synchronisées : elles réussissent
/// hors-ligne et passent en PENDING_SYNC.
abstract interface class PerimetreRepository {
  Stream<List<Perimetre>> watch(String entrepriseId);
  Future<int> compter(String entrepriseId, ActiviteCode activite);

  Future<Perimetre> creer({
    required String entrepriseId,
    required ActiviteCode activite,
    required PerimetreType type,
    required String nom,
    String? code,
  });

  Future<void> modifier(
    Perimetre perimetre, {
    required String nom,
    required String? code,
    required PerimetreType type,
    required bool estActif,
  });

  Future<void> supprimer(Perimetre perimetre);
}
