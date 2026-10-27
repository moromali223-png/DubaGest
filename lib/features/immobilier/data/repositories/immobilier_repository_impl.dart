import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../../domain/repositories/immobilier_repository.dart';
import '../datasources/immobilier_local_data_source.dart';
import '../datasources/immobilier_remote_data_source.dart';
import '../models/bien_mappers.dart';

class ImmobilierRepositoryImpl implements ImmobilierRepository {
  ImmobilierRepositoryImpl({
    required ImmobilierRemoteDataSource remote,
    ImmobilierLocalDataSource? local,
  })  : _remote = remote,
        _local = local;

  final ImmobilierRemoteDataSource _remote;
  final ImmobilierLocalDataSource? _local;

  final _biensControllers = <String, StreamController<List<BienImmobilier>>>{};
  final _biensCache = <String, List<BienImmobilier>>{};

  final _profilsControllers = <String, StreamController<List<ProfilLocataire>>>{};
  final _profilsCache = <String, List<ProfilLocataire>>{};

  final _locationsControllers = <String, StreamController<List<LocationImmobilier>>>{};
  final _locationsCache = <String, List<LocationImmobilier>>{};

  final _contratsControllers = <String, StreamController<List<ContratBail>>>{};
  final _contratsCache = <String, List<ContratBail>>{};

  final _echeancesControllers = <String, StreamController<List<EcheanceLoyer>>>{};
  final _echeancesCache = <String, List<EcheanceLoyer>>{};

  // Helper pour attraper et mapper les exceptions serveur
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, stack) {
      throw ErrorMapper.map(e, stack);
    }
  }

  @override
  Stream<List<BienImmobilier>> observerBiens(String entrepriseId) {
    _biensControllers[entrepriseId] ??= StreamController<List<BienImmobilier>>.broadcast(
      onListen: () => _rafraichirBiens(entrepriseId),
    );

    if (_biensCache.containsKey(entrepriseId)) {
      Future.microtask(() => _biensControllers[entrepriseId]?.add(_biensCache[entrepriseId]!));
    } else {
      _rafraichirBiens(entrepriseId);
    }

    return _biensControllers[entrepriseId]!.stream;
  }

  Future<void> _rafraichirBiens(String entrepriseId) async {
    // 1. Chargement immédiat depuis le cache local Drift
    if (_local != null) {
      try {
        final itemsLocaux = await _local.chargerBiens(entrepriseId);
        _biensCache[entrepriseId] = itemsLocaux;
        _biensControllers[entrepriseId]?.add(itemsLocaux);
      } catch (_) {
        _biensCache[entrepriseId] ??= [];
        _biensControllers[entrepriseId]?.add(_biensCache[entrepriseId]!);
      }
    } else {
      _biensCache[entrepriseId] ??= [];
      _biensControllers[entrepriseId]?.add(_biensCache[entrepriseId]!);
    }

    // 2. Synchronisation réseau avec Supabase
    try {
      final items = await _remote.chargerBiens(entrepriseId);
      _biensCache[entrepriseId] = items;
      _biensControllers[entrepriseId]?.add(items);
      await _local?.sauvegarderBiens(entrepriseId, items);
    } catch (_) {
      // Fallback hors-ligne : la version locale déjà émise suffit
    }
  }

  @override
  Future<BienImmobilier?> getBien(String id) async {
    for (final list in _biensCache.values) {
      final match = list.where((b) => b.id == id).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  @override
  Future<BienImmobilier> sauvegarderBien(BienImmobilier bien) => _guard(() async {
        final list = List<BienImmobilier>.from(_biensCache[bien.entrepriseId] ?? []);
        final index = list.indexWhere((b) => b.id == bien.id);
        if (index >= 0) {
          list[index] = bien;
        } else {
          list.insert(0, bien);
        }
        _biensCache[bien.entrepriseId] = list;
        _biensControllers[bien.entrepriseId]?.add(list);
        await _local?.sauvegarderBiens(bien.entrepriseId, list);

        try {
          final res = await _remote.sauvegarderBien(bien);
          return res;
        } catch (_) {
          // File d'attente hors-ligne
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_biens',
            recordId: bien.id,
            operation: 'UPSERT',
            payload: BienMappers.bienToJson(bien),
          );
          return bien;
        }
      });

  @override
  Future<void> changerStatutBien(String id, StatutBien nouveauStatut) => _guard(() async {
        for (final entry in _biensCache.entries) {
          final index = entry.value.indexWhere((b) => b.id == id);
          if (index >= 0) {
            final modifie = entry.value[index].copyWith(statut: nouveauStatut);
            entry.value[index] = modifie;
            _biensControllers[entry.key]?.add(List.from(entry.value));
            await _local?.sauvegarderBiens(entry.key, entry.value);
            break;
          }
        }

        try {
          await _remote.changerStatutBien(id, nouveauStatut);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_biens',
            recordId: id,
            operation: 'UPDATE',
            payload: {'id': id, 'statut': nouveauStatut.code},
          );
        }
      });

  @override
  Future<void> archiverBien(String id) => changerStatutBien(id, StatutBien.archive);

  @override
  Stream<List<BienImmobilier>> observerBiensParProprietaire(
    String entrepriseId,
    String proprietaireId,
  ) {
    return observerBiens(entrepriseId).map(
      (biens) => biens.where((b) => b.proprietaireId == proprietaireId).toList(),
    );
  }

  // --- LOCATAIRES (PROFILS) ---

  @override
  Stream<List<ProfilLocataire>> observerProfilsLocataires(String entrepriseId) {
    _profilsControllers[entrepriseId] ??= StreamController<List<ProfilLocataire>>.broadcast(
      onListen: () => _rafraichirProfils(entrepriseId),
    );

    if (_profilsCache.containsKey(entrepriseId)) {
      Future.microtask(() => _profilsControllers[entrepriseId]?.add(_profilsCache[entrepriseId]!));
    } else {
      _rafraichirProfils(entrepriseId);
    }

    return _profilsControllers[entrepriseId]!.stream;
  }

  Future<void> _rafraichirProfils(String entrepriseId) async {
    // 1. Local cache
    if (_local != null) {
      try {
        final itemsLocaux = await _local.chargerProfilsLocataires(entrepriseId);
        _profilsCache[entrepriseId] = itemsLocaux;
        _profilsControllers[entrepriseId]?.add(itemsLocaux);
      } catch (_) {
        _profilsCache[entrepriseId] ??= [];
        _profilsControllers[entrepriseId]?.add(_profilsCache[entrepriseId]!);
      }
    } else {
      _profilsCache[entrepriseId] ??= [];
      _profilsControllers[entrepriseId]?.add(_profilsCache[entrepriseId]!);
    }

    // 2. Sync network
    try {
      final items = await _remote.chargerProfilsLocataires(entrepriseId);
      _profilsCache[entrepriseId] = items;
      _profilsControllers[entrepriseId]?.add(items);
      await _local?.sauvegarderProfilsLocataires(entrepriseId, items);
    } catch (_) {
      // Hors-ligne
    }
  }

  @override
  Future<ProfilLocataire?> getProfilLocataire(String contactId) async {
    // Vérifier dans le cache mémoire
    for (final list in _profilsCache.values) {
      final match = list.where((p) => p.contactId == contactId).firstOrNull;
      if (match != null) return match;
    }

    // Sinon chercher dans le cache local
    if (_local != null) {
      final local = await _local.chargerProfilLocataire(contactId);
      if (local != null) return local;
    }

    // Sinon chercher à distance
    try {
      final distant = await _remote.chargerProfilLocataire(contactId);
      if (distant != null && _local != null) {
        await _local.sauvegarderProfilLocataire(distant);
      }
      return distant;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProfilLocataire> sauvegarderProfilLocataire(ProfilLocataire profil) => _guard(() async {
        final list = List<ProfilLocataire>.from(_profilsCache[profil.entrepriseId] ?? []);
        final index = list.indexWhere((p) => p.contactId == profil.contactId);
        if (index >= 0) {
          list[index] = profil;
        } else {
          list.insert(0, profil);
        }
        _profilsCache[profil.entrepriseId] = list;
        _profilsControllers[profil.entrepriseId]?.add(list);
        await _local?.sauvegarderProfilLocataire(profil);

        try {
          final res = await _remote.sauvegarderProfilLocataire(profil);
          return res;
        } catch (_) {
          // File d'attente hors-ligne
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_locataires_profils',
            recordId: profil.contactId,
            operation: 'UPSERT',
            payload: profil.toJson(),
          );
          return profil;
        }
      });

  // --- LOCATIONS ---

  @override
  Stream<List<LocationImmobilier>> observerLocations(String entrepriseId) {
    _locationsControllers[entrepriseId] ??= StreamController<List<LocationImmobilier>>.broadcast(
      onListen: () => _rafraichirLocations(entrepriseId),
    );

    if (_locationsCache.containsKey(entrepriseId)) {
      Future.microtask(() => _locationsControllers[entrepriseId]?.add(_locationsCache[entrepriseId]!));
    } else {
      _rafraichirLocations(entrepriseId);
    }

    return _locationsControllers[entrepriseId]!.stream;
  }

  Future<void> _rafraichirLocations(String entrepriseId) async {
    // 1. Local
    if (_local != null) {
      try {
        final itemsLocaux = await _local.chargerLocations(entrepriseId);
        _locationsCache[entrepriseId] = itemsLocaux;
        _locationsControllers[entrepriseId]?.add(itemsLocaux);
      } catch (_) {
        _locationsCache[entrepriseId] ??= [];
        _locationsControllers[entrepriseId]?.add(_locationsCache[entrepriseId]!);
      }
    } else {
      _locationsCache[entrepriseId] ??= [];
      _locationsControllers[entrepriseId]?.add(_locationsCache[entrepriseId]!);
    }

    // 2. Remote
    try {
      final items = await _remote.chargerLocations(entrepriseId);
      _locationsCache[entrepriseId] = items;
      _locationsControllers[entrepriseId]?.add(items);
      await _local?.sauvegarderLocations(entrepriseId, items);
    } catch (_) {
      // Hors-ligne
    }
  }

  @override
  Future<LocationImmobilier?> getLocation(String id) async {
    for (final list in _locationsCache.values) {
      final match = list.where((l) => l.id == id).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  @override
  Future<LocationImmobilier> sauvegarderLocation(LocationImmobilier location) => _guard(() async {
        // Règle métier stricte : vérification anti-chevauchement
        final locationsEntreprise = _locationsCache[location.entrepriseId] ??
            (await _local?.chargerLocations(location.entrepriseId)) ??
            [];

        final chevauchements = locationsEntreprise.where((l) {
          if (l.id == location.id) return false;
          if (l.bienId != location.bienId) return false;
          return l.chevauchePeriode(location.dateDebut, location.dateFinPrevue);
        }).toList();

        if (chevauchements.isNotEmpty) {
          final conflit = chevauchements.first;
          final finTexte = conflit.dateFinPrevue != null
              ? '${conflit.dateFinPrevue!.day.toString().padLeft(2, '0')}/${conflit.dateFinPrevue!.month.toString().padLeft(2, '0')}/${conflit.dateFinPrevue!.year}'
              : 'indéterminée';
          final debutTexte =
              '${conflit.dateDebut.day.toString().padLeft(2, '0')}/${conflit.dateDebut.month.toString().padLeft(2, '0')}/${conflit.dateDebut.year}';
          throw Exception(
            'Ce bien fait déjà l\'objet d\'une location du $debutTexte au $finTexte. Aucun chevauchement de dates n\'est autorisé sur le même bien.',
          );
        }

        // Sauvegarder dans le cache local
        final list = List<LocationImmobilier>.from(_locationsCache[location.entrepriseId] ?? []);
        final index = list.indexWhere((l) => l.id == location.id);
        if (index >= 0) {
          list[index] = location;
        } else {
          list.insert(0, location);
        }
        _locationsCache[location.entrepriseId] = list;
        _locationsControllers[location.entrepriseId]?.add(list);
        await _local?.sauvegarderLocations(location.entrepriseId, list);

        // Mettre à jour automatiquement le statut du bien
        if (location.statut == StatutLocation.active) {
          await changerStatutBien(location.bienId, StatutBien.occupe);
        } else if (location.statut == StatutLocation.enAttente) {
          final bien = await getBien(location.bienId);
          if (bien?.statut == StatutBien.disponible) {
            await changerStatutBien(location.bienId, StatutBien.reserve);
          }
        }

        try {
          final res = await _remote.sauvegarderLocation(location);
          return res;
        } catch (_) {
          // File d'attente hors-ligne
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_locations',
            recordId: location.id,
            operation: 'UPSERT',
            payload: location.toJson(),
          );
          return location;
        }
      });

  @override
  Future<void> cloturerLocation(
    String id, {
    required DateTime dateSortie,
    required String motif,
    required StatutBien futurStatutBien,
  }) =>
      _guard(() async {
        LocationImmobilier? cible;
        for (final entry in _locationsCache.entries) {
          final index = entry.value.indexWhere((l) => l.id == id);
          if (index >= 0) {
            final courante = entry.value[index];
            cible = courante.copyWith(
              statut: StatutLocation.terminee,
              dateFinReelle: dateSortie,
              motifCloture: motif,
              etatLieuxSortie: true,
            );
            entry.value[index] = cible;
            _locationsControllers[entry.key]?.add(List.from(entry.value));
            await _local?.sauvegarderLocations(entry.key, entry.value);
            break;
          }
        }

        if (cible != null) {
          await changerStatutBien(cible.bienId, futurStatutBien);
        }

        try {
          await _remote.cloturerLocation(id, dateSortie: dateSortie, motif: motif);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_locations',
            recordId: id,
            operation: 'UPDATE',
            payload: {
              'id': id,
              'statut': StatutLocation.terminee.code,
              'date_fin_reelle': dateSortie.toIso8601String().split('T').first,
              'motif_cloture': motif,
              'etat_lieux_sortie': true,
            },
          );
        }
      });

  @override
  Stream<List<LocationImmobilier>> observerLocationsParBien(String bienId) {
    for (final entry in _locationsControllers.entries) {
      return entry.value.stream.map(
        (locs) => locs.where((l) => l.bienId == bienId).toList(),
      );
    }
    return const Stream.empty();
  }

  @override
  Stream<List<LocationImmobilier>> observerLocationsParLocataire(String locataireId) {
    for (final entry in _locationsControllers.entries) {
      return entry.value.stream.map(
        (locs) => locs.where((l) => l.locataireId == locataireId).toList(),
      );
    }
    return const Stream.empty();
  }

  // --- CONTRATS DE BAIL ---

  @override
  Stream<List<ContratBail>> observerContrats(String entrepriseId) {
    _contratsControllers[entrepriseId] ??= StreamController<List<ContratBail>>.broadcast(
      onListen: () => _rafraichirContrats(entrepriseId),
    );

    if (_contratsCache.containsKey(entrepriseId)) {
      Future.microtask(() => _contratsControllers[entrepriseId]?.add(_contratsCache[entrepriseId]!));
    } else {
      _rafraichirContrats(entrepriseId);
    }

    return _contratsControllers[entrepriseId]!.stream;
  }

  Future<void> _rafraichirContrats(String entrepriseId) async {
    // 1. Cache local Drift
    if (_local != null) {
      try {
        final itemsLocaux = await _local.chargerContrats(entrepriseId);
        _contratsCache[entrepriseId] = itemsLocaux;
        _contratsControllers[entrepriseId]?.add(itemsLocaux);
      } catch (_) {
        _contratsCache[entrepriseId] ??= [];
        _contratsControllers[entrepriseId]?.add(_contratsCache[entrepriseId]!);
      }
    } else {
      _contratsCache[entrepriseId] ??= [];
      _contratsControllers[entrepriseId]?.add(_contratsCache[entrepriseId]!);
    }

    // 2. Fetch distant Supabase
    try {
      final itemsDistants = await _remote.chargerContrats(entrepriseId);
      _contratsCache[entrepriseId] = itemsDistants;
      _contratsControllers[entrepriseId]?.add(itemsDistants);
      await _local?.sauvegarderContrats(entrepriseId, itemsDistants);
    } catch (_) {
      // Conserver le cache local si hors-ligne
    }
  }

  @override
  Future<ContratBail?> getContrat(String id) async {
    for (final list in _contratsCache.values) {
      try {
        return list.firstWhere((c) => c.id == id);
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<ContratBail> sauvegarderContrat(ContratBail contrat) => _guard(() async {
        final entrepriseId = contrat.entrepriseId;
        final actuels = List<ContratBail>.from(_contratsCache[entrepriseId] ?? []);
        final index = actuels.indexWhere((c) => c.id == contrat.id);

        if (index >= 0) {
          actuels[index] = contrat;
        } else {
          actuels.insert(0, contrat);
        }

        _contratsCache[entrepriseId] = actuels;
        _contratsControllers[entrepriseId]?.add(actuels);
        await _local?.sauvegarderContrat(contrat);

        try {
          return await _remote.sauvegarderContrat(contrat);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_contrats',
            recordId: contrat.id,
            operation: index >= 0 ? 'UPDATE' : 'INSERT',
            payload: contrat.toJson(),
          );
          return contrat;
        }
      });

  @override
  Future<void> changerStatutContrat(String id, StatutContratBail nouveauStatut) => _guard(() async {
        for (final entry in _contratsCache.entries) {
          final index = entry.value.indexWhere((c) => c.id == id);
          if (index >= 0) {
            final contrat = entry.value[index];
            final maj = contrat.copyWith(
              statut: nouveauStatut,
              misAJourLe: DateTime.now(),
            );
            entry.value[index] = maj;
            _contratsControllers[entry.key]?.add(List.unmodifiable(entry.value));
            await _local?.sauvegarderContrat(maj);
            break;
          }
        }

        try {
          await _remote.changerStatutContrat(id, nouveauStatut);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_contrats',
            recordId: id,
            operation: 'UPDATE',
            payload: {
              'id': id,
              'statut': nouveauStatut.code,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
        }
      });

  @override
  Future<void> signerContrat(String id, {bool bailleur = false, bool locataire = false}) => _guard(() async {
        for (final entry in _contratsCache.entries) {
          final index = entry.value.indexWhere((c) => c.id == id);
          if (index >= 0) {
            final c = entry.value[index];
            final nBailleur = bailleur || c.signeParBailleur;
            final nLocataire = locataire || c.signeParLocataire;
            final deuxSignes = nBailleur && nLocataire;
            final nStatut = deuxSignes && c.statut == StatutContratBail.brouillon
                ? StatutContratBail.actif
                : c.statut;

            final maj = c.copyWith(
              signeParBailleur: nBailleur,
              signeParLocataire: nLocataire,
              dateSignature: DateTime.now(),
              statut: nStatut,
              misAJourLe: DateTime.now(),
            );
            entry.value[index] = maj;
            _contratsControllers[entry.key]?.add(List.unmodifiable(entry.value));
            await _local?.sauvegarderContrat(maj);
            break;
          }
        }

        try {
          await _remote.signerContrat(id, bailleur: bailleur, locataire: locataire);
        } catch (_) {
          final payload = <String, dynamic>{
            'id': id,
            'updated_at': DateTime.now().toIso8601String(),
            'date_signature': DateTime.now().toIso8601String().split('T').first,
          };
          if (bailleur) payload['signe_par_bailleur'] = true;
          if (locataire) payload['signe_par_locataire'] = true;

          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_contrats',
            recordId: id,
            operation: 'UPDATE',
            payload: payload,
          );
        }
      });

  @override
  Stream<List<ContratBail>> observerContratsParBien(String bienId) {
    for (final entry in _contratsControllers.entries) {
      return entry.value.stream.map(
        (contrats) => contrats.where((c) => c.bienId == bienId).toList(),
      );
    }
    return const Stream.empty();
  }

  @override
  Stream<List<ContratBail>> observerContratsParLocataire(String locataireId) {
    for (final entry in _contratsControllers.entries) {
      return entry.value.stream.map(
        (contrats) => contrats.where((c) => c.locataireId == locataireId).toList(),
      );
    }
    return const Stream.empty();
  }

  // --- ÉCHÉANCES DE LOYERS & ENCAISSEMENTS ---

  @override
  Stream<List<EcheanceLoyer>> observerEcheancesLoyers(String entrepriseId, {int? annee, int? mois}) {
    _echeancesControllers[entrepriseId] ??= StreamController<List<EcheanceLoyer>>.broadcast(
      onListen: () => _rafraichirEcheances(entrepriseId),
    );

    if (_echeancesCache.containsKey(entrepriseId)) {
      Future.microtask(() {
        final toutes = _echeancesCache[entrepriseId]!;
        _echeancesControllers[entrepriseId]?.add(toutes);
      });
    } else {
      _rafraichirEcheances(entrepriseId);
    }

    return _echeancesControllers[entrepriseId]!.stream.map(
      (list) => _filtrerPeriode(list, annee: annee, mois: mois),
    );
  }

  List<EcheanceLoyer> _filtrerPeriode(List<EcheanceLoyer> list, {int? annee, int? mois}) {
    return list.where((e) {
      if (annee != null && e.periodeAnnee != annee) return false;
      if (mois != null && e.periodeMois != mois) return false;
      return true;
    }).toList();
  }

  Future<void> _rafraichirEcheances(String entrepriseId) async {
    // 1. Cache local Drift
    if (_local != null) {
      try {
        final itemsLocaux = await _local.chargerEcheancesLoyers(entrepriseId);
        _echeancesCache[entrepriseId] = itemsLocaux;
        _echeancesControllers[entrepriseId]?.add(itemsLocaux);
      } catch (_) {
        _echeancesCache[entrepriseId] ??= [];
        _echeancesControllers[entrepriseId]?.add(_echeancesCache[entrepriseId]!);
      }
    } else {
      _echeancesCache[entrepriseId] ??= [];
      _echeancesControllers[entrepriseId]?.add(_echeancesCache[entrepriseId]!);
    }

    // 2. Fetch distant Supabase
    try {
      final itemsDistants = await _remote.chargerEcheancesLoyers(entrepriseId);
      _echeancesCache[entrepriseId] = itemsDistants;
      _echeancesControllers[entrepriseId]?.add(itemsDistants);
      await _local?.sauvegarderEcheancesLoyers(entrepriseId, itemsDistants);
    } catch (_) {
      // Conserver le cache local si hors-ligne
    }
  }

  @override
  Future<EcheanceLoyer?> getEcheanceLoyer(String id) async {
    for (final list in _echeancesCache.values) {
      try {
        return list.firstWhere((e) => e.id == id);
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<EcheanceLoyer> sauvegarderEcheanceLoyer(EcheanceLoyer echeance) => _guard(() async {
        final entrepriseId = echeance.entrepriseId;
        final actuels = List<EcheanceLoyer>.from(_echeancesCache[entrepriseId] ?? []);
        final index = actuels.indexWhere((e) => e.id == echeance.id);

        if (index >= 0) {
          actuels[index] = echeance;
        } else {
          actuels.insert(0, echeance);
        }

        _echeancesCache[entrepriseId] = actuels;
        _echeancesControllers[entrepriseId]?.add(actuels);
        await _local?.sauvegarderEcheanceLoyer(echeance);

        try {
          return await _remote.sauvegarderEcheanceLoyer(echeance);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'immobilier_echeances_loyers',
            recordId: echeance.id,
            operation: index >= 0 ? 'UPDATE' : 'INSERT',
            payload: echeance.toJson(),
          );
          return echeance;
        }
      });

  @override
  Future<List<EcheanceLoyer>> genererAppelsLoyersMensuels({
    required String entrepriseId,
    required int mois,
    required int annee,
  }) =>
      _guard(() async {
        // 1. Récupérer tous les contrats actifs de l'entreprise
        await _rafraichirContrats(entrepriseId);
        final contrats = (_contratsCache[entrepriseId] ?? []).where((c) {
          if (c.statut != StatutContratBail.actif) return false;
          final premierDuMois = DateTime(annee, mois, 1);
          final dernierDuMois = DateTime(annee, mois + 1, 0);
          if (c.dateDebut.isAfter(dernierDuMois)) return false;
          if (c.dateFinPrevue != null && c.dateFinPrevue!.isBefore(premierDuMois)) return false;
          return true;
        }).toList();

        // 2. Récupérer les échéances déjà existantes pour ce mois/année (idempotence stricte)
        await _rafraichirEcheances(entrepriseId);
        final echeancesExistantes = _echeancesCache[entrepriseId] ?? [];

        final nouvelles = <EcheanceLoyer>[];

        for (final contrat in contrats) {
          final existeDeja = echeancesExistantes.any(
            (e) => e.contratId == contrat.id && e.periodeAnnee == annee && e.periodeMois == mois,
          );
          if (existeDeja) continue; // Idempotence respectée

          final echeanceId = const Uuid().v4();
          final engagementId = const Uuid().v4();
          final jour = contrat.termePaiementJour.clamp(1, 28);
          final dateExigibilite = DateTime(annee, mois, jour);

          final echeance = EcheanceLoyer(
            id: echeanceId,
            entrepriseId: entrepriseId,
            reference: 'ECH-$annee${mois.toString().padLeft(2, '0')}-${echeanceId.substring(0, 4).toUpperCase()}',
            contratId: contrat.id,
            bienId: contrat.bienId,
            locataireId: contrat.locataireId,
            proprietaireId: contrat.proprietaireId,
            engagementId: engagementId,
            periodeMois: mois,
            periodeAnnee: annee,
            dateEmission: DateTime.now(),
            dateExigibilite: dateExigibilite,
            loyerNet: contrat.loyerMensuel,
            charges: contrat.chargesMensuelles,
            totalDu: contrat.totalMensuel,
            montantRegle: 0,
            statut: StatutEcheanceLoyer.aPayer,
            creeLe: DateTime.now(),
            misAJourLe: DateTime.now(),
          );

          nouvelles.add(echeance);
        }

        if (nouvelles.isEmpty) return const [];

        // 3. Mise à jour cache et persistance
        final actuelles = List<EcheanceLoyer>.from(_echeancesCache[entrepriseId] ?? []);
        actuelles.insertAll(0, nouvelles);
        _echeancesCache[entrepriseId] = actuelles;
        _echeancesControllers[entrepriseId]?.add(actuelles);
        await _local?.sauvegarderEcheancesLoyers(entrepriseId, actuelles);

        try {
          await _remote.sauvegarderEcheancesLoyers(nouvelles);
        } catch (_) {
          for (final n in nouvelles) {
            await _local?.empilerOperationSync(
              operationId: const Uuid().v4(),
              userId: 'local',
              entityTable: 'immobilier_echeances_loyers',
              recordId: n.id,
              operation: 'INSERT',
              payload: n.toJson(),
            );
          }
        }

        return nouvelles;
      });

  @override
  Future<void> enregistrerPaiementLoyer({
    required String echeanceId,
    required int montantVerse,
    required String modePaiement,
    String? referencePaiement,
    String? note,
    DateTime? datePaiement,
    String? quittanceDocumentId,
    String? recuDocumentId,
  }) =>
      _guard(() async {
        final date = datePaiement ?? DateTime.now();
        for (final entry in _echeancesCache.entries) {
          final index = entry.value.indexWhere((e) => e.id == echeanceId);
          if (index >= 0) {
            final echeance = entry.value[index];
            final nouveauRegle = echeance.montantRegle + montantVerse;
            final solde = nouveauRegle >= echeance.totalDu;
            final nouveauStatut = solde ? StatutEcheanceLoyer.solde : StatutEcheanceLoyer.partiellementPaye;

            final recus = List<String>.from(echeance.recuDocumentIds);
            if (recuDocumentId != null && !recus.contains(recuDocumentId)) {
              recus.add(recuDocumentId);
            }

            final maj = echeance.copyWith(
              montantRegle: nouveauRegle,
              statut: nouveauStatut,
              derniereDatePaiement: date,
              quittanceDocumentId: quittanceDocumentId ?? echeance.quittanceDocumentId,
              recuDocumentIds: recus,
              misAJourLe: DateTime.now(),
            );

            entry.value[index] = maj;
            _echeancesControllers[entry.key]?.add(List.unmodifiable(entry.value));
            await _local?.sauvegarderEcheanceLoyer(maj);

            try {
              await _remote.mettreAJourStatutEcheance(
                id: echeanceId,
                statut: nouveauStatut,
                montantRegle: nouveauRegle,
                datePaiement: date,
                quittanceDocumentId: maj.quittanceDocumentId,
                recuDocumentIds: maj.recuDocumentIds,
              );
            } catch (_) {
              await _local?.empilerOperationSync(
                operationId: const Uuid().v4(),
                userId: 'local',
                entityTable: 'immobilier_echeances_loyers',
                recordId: echeanceId,
                operation: 'UPDATE',
                payload: {
                  'id': echeanceId,
                  'statut': nouveauStatut.code,
                  'montant_regle': nouveauRegle,
                  'derniere_date_paiement': date.toIso8601String(),
                  'quittance_document_id': maj.quittanceDocumentId,
                  'recu_document_ids': maj.recuDocumentIds,
                  'updated_at': DateTime.now().toIso8601String(),
                },
              );
            }
            break;
          }
        }
      });

  @override
  Stream<List<EcheanceLoyer>> observerEcheancesParLocataire(String locataireId) {
    for (final entry in _echeancesControllers.entries) {
      return entry.value.stream.map(
        (list) => list.where((e) => e.locataireId == locataireId).toList(),
      );
    }
    return const Stream.empty();
  }

  @override
  Stream<List<EcheanceLoyer>> observerEcheancesParBien(String bienId) {
    for (final entry in _echeancesControllers.entries) {
      return entry.value.stream.map(
        (list) => list.where((e) => e.bienId == bienId).toList(),
      );
    }
    return const Stream.empty();
  }
}
