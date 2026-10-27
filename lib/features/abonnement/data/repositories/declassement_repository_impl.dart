import '../../domain/entities/declassement_models.dart';
import '../../domain/repositories/declassement_repository.dart';
import '../datasources/declassement_remote_data_source.dart';

class DeclassementRepositoryImpl implements DeclassementRepository {
  DeclassementRepositoryImpl(this._remote);

  final DeclassementRemoteDataSource _remote;

  @override
  Future<AnalyseDeclassement> analyserLimites({
    required String entrepriseId,
    required String planCibleCode,
  }) {
    return _remote.analyserLimites(
      entrepriseId: entrepriseId,
      planCibleCode: planCibleCode,
    );
  }

  @override
  Future<DemandeDeclassement> demanderDeclassement({
    required String entrepriseId,
    required String planCibleCode,
  }) {
    return _remote.demanderDeclassement(
      entrepriseId: entrepriseId,
      planCibleCode: planCibleCode,
    );
  }

  @override
  Future<DemandeDeclassement?> getDemandeEnCours(String entrepriseId) {
    return _remote.getDemandeEnCours(entrepriseId);
  }

  @override
  Future<void> ajusterRessource({
    required String entrepriseId,
    required String typeRessource,
    required String ressourceId,
    required String action,
  }) {
    return _remote.ajusterRessource(
      entrepriseId: entrepriseId,
      typeRessource: typeRessource,
      ressourceId: ressourceId,
      action: action,
    );
  }

  @override
  Future<Map<String, dynamic>> validerEtAppliquerDeclassement(String demandeId) {
    return _remote.validerEtAppliquerDeclassement(demandeId);
  }

  @override
  Future<void> annulerDemande(String demandeId) {
    return _remote.annulerDemande(demandeId);
  }
}
