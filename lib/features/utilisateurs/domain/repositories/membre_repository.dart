import '../entities/membre.dart';

abstract interface class MembreRepository {
  /// Liste serveur, ou dernière liste connue hors-ligne.
  Future<List<Membre>> lister(String entrepriseId);

  Future<void> affecter({
    required String entrepriseId,
    required String membreId,
    required String perimetreId,
  });
  Future<void> retirer({required String membreId, required String perimetreId});

  Future<void> modifierRole({
    required String entrepriseId,
    required String membreId,
    required String roleCode,
  });

  Future<void> modifierStatut({
    required String entrepriseId,
    required String membreId,
    required String statut,
  });

  Future<void> supprimer({
    required String entrepriseId,
    required String membreId,
  });
}
