import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../data/datasources/declassement_remote_data_source.dart';
import '../../data/repositories/declassement_repository_impl.dart';
import '../../domain/entities/declassement_models.dart';
import '../../domain/repositories/declassement_repository.dart';

final declassementRepositoryProvider = Provider<DeclassementRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DeclassementRepositoryImpl(DeclassementRemoteDataSource(client));
});

/// Récupère la demande en cours pour l'entreprise active.
final demandeDeclassementEnCoursProvider = FutureProvider.autoDispose<DemandeDeclassement?>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  final eid = ctx?.entreprise?.id;
  if (eid == null) return null;
  final repo = ref.watch(declassementRepositoryProvider);
  return repo.getDemandeEnCours(eid);
});

class DeclassementState {
  const DeclassementState({
    this.demande,
    this.analyse,
    this.chargement = false,
    this.erreur,
    this.messageSucces,
  });

  final DemandeDeclassement? demande;
  final AnalyseDeclassement? analyse;
  final bool chargement;
  final String? erreur;
  final String? messageSucces;

  DeclassementState copyWith({
    DemandeDeclassement? demande,
    AnalyseDeclassement? analyse,
    bool? chargement,
    String? erreur,
    String? messageSucces,
    bool clearErreur = false,
    bool clearSucces = false,
  }) {
    return DeclassementState(
      demande: demande ?? this.demande,
      analyse: analyse ?? this.analyse,
      chargement: chargement ?? this.chargement,
      erreur: clearErreur ? null : (erreur ?? this.erreur),
      messageSucces: clearSucces ? null : (messageSucces ?? this.messageSucces),
    );
  }
}

class DeclassementNotifier extends Notifier<DeclassementState> {
  @override
  DeclassementState build() => const DeclassementState();

  DeclassementRepository get _repo => ref.read(declassementRepositoryProvider);
  String? get _entrepriseId => ref.read(contexteActifProvider)?.entreprise?.id;

  /// Démarre ou recharge la demande de déclassement vers le plan cible
  Future<void> chargerOuDemander(String planCibleCode) async {
    final eid = _entrepriseId;
    if (eid == null) return;

    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      final demande = await _repo.demanderDeclassement(
        entrepriseId: eid,
        planCibleCode: planCibleCode,
      );
      state = state.copyWith(
        chargement: false,
        demande: demande,
        analyse: demande.analyse,
      );
    } catch (e) {
      state = state.copyWith(
        chargement: false,
        erreur: 'Erreur lors de l\'analyse du déclassement : $e',
      );
    }
  }

  /// Suspend ou réactive un utilisateur
  Future<bool> ajusterUtilisateur({
    required String membreId,
    required bool suspendre,
    required String planCibleCode,
  }) async {
    return _ajusterRessource(
      type: 'UTILISATEUR',
      ressourceId: membreId,
      action: suspendre ? 'DESACTIVER' : 'ACTIVER',
      planCibleCode: planCibleCode,
    );
  }

  /// Désactive ou réactive un périmètre (boutique / agence)
  Future<bool> ajusterPerimetre({
    required String perimetreId,
    required bool desactiver,
    required String planCibleCode,
  }) async {
    return _ajusterRessource(
      type: 'PERIMETRE',
      ressourceId: perimetreId,
      action: desactiver ? 'DESACTIVER' : 'ACTIVER',
      planCibleCode: planCibleCode,
    );
  }

  /// Désactive ou réactive une activité
  Future<bool> ajusterActivite({
    required String activiteCode,
    required bool desactiver,
    required String planCibleCode,
  }) async {
    return _ajusterRessource(
      type: 'ACTIVITE',
      ressourceId: activiteCode,
      action: desactiver ? 'DESACTIVER' : 'ACTIVER',
      planCibleCode: planCibleCode,
    );
  }

  Future<bool> _ajusterRessource({
    required String type,
    required String ressourceId,
    required String action,
    required String planCibleCode,
  }) async {
    final eid = _entrepriseId;
    if (eid == null) return false;

    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      await _repo.ajusterRessource(
        entrepriseId: eid,
        typeRessource: type,
        ressourceId: ressourceId,
        action: action,
      );

      // Rafraîchir les listes locales
      ref.invalidate(membresProvider);
      ref.invalidate(perimetresProvider);

      // Recharger l'analyse et la demande
      final demande = await _repo.demanderDeclassement(
        entrepriseId: eid,
        planCibleCode: planCibleCode,
      );

      state = state.copyWith(
        chargement: false,
        demande: demande,
        analyse: demande.analyse,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        chargement: false,
        erreur: 'Impossible d\'effectuer l\'ajustement : $e',
      );
      return false;
    }
  }

  /// Vérifie et applique le déclassement côté serveur de manière atomique
  Future<bool> finaliserDeclassement() async {
    final demande = state.demande;
    if (demande == null) return false;

    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      final res = await _repo.validerEtAppliquerDeclassement(demande.id);
      final succes = res['succes'] == true;

      if (succes) {
        state = state.copyWith(
          chargement: false,
          messageSucces: res['message'] as String? ?? 'Formule déclassée avec succès.',
        );
        // Actualiser immédiatement le contexte global et les listes
        await ref.read(contexteSessionProvider.notifier).rafraichir();
        ref.invalidate(membresProvider);
        ref.invalidate(perimetresProvider);
        ref.invalidate(demandeDeclassementEnCoursProvider);
        return true;
      } else {
        state = state.copyWith(
          chargement: false,
          erreur: res['message'] as String? ?? 'Le déclassement n\'a pas pu être validé.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        chargement: false,
        erreur: 'Erreur lors de la finalisation : $e',
      );
      return false;
    }
  }

  /// Annule la demande de déclassement
  Future<bool> annulerDemande() async {
    final demande = state.demande;
    if (demande == null) return false;

    state = state.copyWith(chargement: true, clearErreur: true);
    try {
      await _repo.annulerDemande(demande.id);
      ref.invalidate(demandeDeclassementEnCoursProvider);
      state = const DeclassementState();
      return true;
    } catch (e) {
      state = state.copyWith(
        chargement: false,
        erreur: 'Erreur lors de l\'annulation : $e',
      );
      return false;
    }
  }
}

final declassementNotifierProvider =
    NotifierProvider.autoDispose<DeclassementNotifier, DeclassementState>(DeclassementNotifier.new);
