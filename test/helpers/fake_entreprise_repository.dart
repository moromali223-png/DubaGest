import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/entreprise/domain/entities/offre_plan.dart';
import 'package:dubagest/features/entreprise/domain/entities/profil_entreprise.dart';
import 'package:dubagest/features/entreprise/domain/repositories/entreprise_repository.dart';

/// Repository entreprise en mémoire, partagé par les tests.
class FakeEntrepriseRepository implements EntrepriseRepository {
  List<ActiviteCode>? activitesCreees;
  ({ActiviteCode activite, bool dejaRattachee})? activation;
  ProfilEntreprise? profilEnregistre;
  ProfilEntreprise profilCourant =
      const ProfilEntreprise(id: 'e-1', nom: 'Alpha', devise: 'XOF', langueDocuments: 'fr');

  @override
  Future<List<OffrePlan>> offres() async => const [];

  @override
  Future<String> creer({
    required String nom,
    required String planCode,
    required List<ActiviteCode> activites,
  }) async {
    activitesCreees = activites;
    return 'e-1';
  }

  @override
  Future<void> activerActivite({
    required String entrepriseId,
    required ActiviteCode activite,
    required bool dejaRattachee,
  }) async =>
      activation = (activite: activite, dejaRattachee: dejaRattachee);

  @override
  Future<ProfilEntreprise> profil(String entrepriseId) async => profilCourant;

  @override
  Future<void> enregistrerProfil(ProfilEntreprise profil) async => profilEnregistre = profil;

  ({List<String> modes, String? pied})? parametresEnregistres;

  @override
  Future<void> enregistrerParametres(String entrepriseId, {required List<String> modesPaiement, String? piedRecu}) async =>
      parametresEnregistres = (modes: modesPaiement, pied: piedRecu);
}
